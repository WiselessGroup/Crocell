// Package engine runs mihomo with a config built from subscription nodes.
//
// mihomo keeps its state in package-level globals, so there is exactly one
// engine per process. That is fine: on desktop it lives in crocelld, on
// mobile in the VPN service process.
package engine

import (
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"

	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

// GroupName is the selector that every node sits in. Switching nodes means
// switching this selector, without restarting listeners.
const GroupName = "Crocell"

// Options describe what to run.
type Options struct {
	// HomeDir is where mihomo keeps cache.db and anything it downloads.
	HomeDir   string
	MixedPort int    // HTTP+SOCKS on 127.0.0.1, 0 disables
	LogLevel  string // silent, error, warning, info, debug
	Nodes     []subscription.Node
	Selected  string // node name, first node when empty

	// Tun captures the whole system instead of waiting for apps to use the
	// proxy. Needs root / CAP_NET_ADMIN on desktop, VpnService on Android.
	Tun *TunOptions

	// Rules route programs, sites, subnets and geo sets; Final is where
	// everything else goes (Proxy unless set to Direct). LAN is always direct.
	Rules []Rule
	Final Action

	DNS      DNSOptions
	IPv6     bool // off cuts IPv6 out of the tunnel and DNS answers
	AllowLAN bool // other devices may use the mixed port

	// GeoURLs are mihomo's fallback sources if a geo rule finds no file in
	// HomeDir. The daemon normally fetches the files before Start.
	GeoIPURL, GeoSiteURL string
}

// DNSOptions: Servers resolve everything through the node; DirectServers
// serve direct traffic and node addresses. Empty means sane defaults.
type DNSOptions struct {
	Servers       []string
	DirectServers []string
	RealIP        bool // redir-host instead of fake-ip
}

// TunOptions configure the TUN device. Zero values are sane defaults.
type TunOptions struct {
	// Stack: "mixed" (system TCP, gVisor UDP), "system" or "gvisor".
	Stack string
	MTU   uint32
	// FileDescriptor is the TUN fd handed over by Android's VpnService.
	// When set, routes are the VpnService's business, not ours.
	FileDescriptor int
	// ExcludePackages bypass the tunnel completely (Android only).
	ExcludePackages []string
}

var (
	mu      sync.Mutex
	running bool
)

// Start applies the config. Calling it again replaces the running config.
func Start(opts Options) error {
	if len(opts.Nodes) == 0 {
		return errors.New("engine: no nodes")
	}
	if opts.HomeDir == "" {
		return errors.New("engine: no home dir")
	}
	if err := os.MkdirAll(opts.HomeDir, 0o700); err != nil {
		return fmt.Errorf("engine: %w", err)
	}

	if opts.Tun != nil && opts.Tun.Stack != "system" && !withGvisor {
		return errors.New("engine: this build has no gVisor for the TUN stack, rebuild with -tags with_gvisor (make build) or use the system stack")
	}

	cfg, err := buildConfig(opts)
	if err != nil {
		return err
	}

	mu.Lock()
	defer mu.Unlock()

	C.SetHomeDir(opts.HomeDir)
	if err := hub.Parse(cfg); err != nil {
		return fmt.Errorf("engine: %w", err)
	}
	running = true

	// mihomo keeps going when TUN fails to start: it logs the reason and
	// flips Enable off. Saying "connected" then would be a lie, so check
	// both its record and, where we can, the interface itself.
	if opts.Tun != nil && (!listener.GetTunConf().Enable || !tunInterfaceUp()) {
		applyIdleLocked()
		running = false
		return errors.New("engine: TUN did not start, the reason is in the service log")
	}

	if opts.Selected != "" {
		return selectLocked(opts.Selected)
	}
	return nil
}

// Select switches the active node.
func Select(name string) error {
	mu.Lock()
	defer mu.Unlock()
	return selectLocked(name)
}

func selectLocked(name string) error {
	if !running {
		return errors.New("engine: not running")
	}
	group, ok := tunnel.Proxies()[GroupName]
	if !ok {
		return errors.New("engine: selector missing")
	}
	sel, ok := group.Adapter().(*outboundgroup.Selector)
	if !ok {
		return errors.New("engine: selector has unexpected type")
	}
	if err := sel.Set(name); err != nil {
		return fmt.Errorf("engine: select %q: %w", name, err)
	}
	return nil
}

// Selected returns the active node name.
func Selected() string {
	mu.Lock()
	defer mu.Unlock()
	if !running {
		return ""
	}
	if group, ok := tunnel.Proxies()[GroupName]; ok {
		if sel, ok := group.Adapter().(*outboundgroup.Selector); ok {
			return sel.Now()
		}
	}
	return ""
}

// Stop closes the tunnel and the mixed port but keeps mihomo alive.
//
// Not executor.Shutdown: that closes TUN without forgetting its config, and
// mihomo then skips recreating an "unchanged" TUN on the next Start, so the
// second connect in a process ran with no tunnel at all while claiming to be
// connected. Applying an idle config makes mihomo record TUN as disabled.
func Stop() {
	mu.Lock()
	defer mu.Unlock()
	if running {
		applyIdleLocked()
		running = false
	}
}

// Shutdown is Stop plus mihomo's own teardown, for when the process exits.
func Shutdown() {
	Stop()
	mu.Lock()
	defer mu.Unlock()
	executor.Shutdown()
}

func applyIdleLocked() {
	idle, err := yaml.Marshal(map[string]any{
		"mode":       "rule",
		"log-level":  "warning",
		"mixed-port": 0,
		"tun":        map[string]any{"enable": false},
		"dns":        map[string]any{"enable": false},
		"rules":      []string{"MATCH,REJECT"},
	})
	if err == nil {
		err = hub.Parse(idle)
	}
	if err != nil {
		// Should never happen with a constant config; fall back to closing
		// what we can.
		executor.Shutdown()
	}
}

func buildConfig(opts Options) ([]byte, error) {
	proxies := make([]map[string]any, 0, len(opts.Nodes))
	names := make([]string, 0, len(opts.Nodes))
	for _, n := range opts.Nodes {
		proxies = append(proxies, withFingerprint(n.Proxy))
		names = append(names, n.Name)
	}

	logLevel := opts.LogLevel
	if logLevel == "" {
		logLevel = "warning"
	}

	cfg := map[string]any{
		"mode":         "rule",
		"log-level":    logLevel,
		"allow-lan":    opts.AllowLAN,
		"bind-address": map[bool]string{true: "*", false: "127.0.0.1"}[opts.AllowLAN],
		"ipv6":         opts.IPv6,
		"profile": map[string]any{
			"store-selected": false,
		},
		"proxies": proxies,
		"proxy-groups": []map[string]any{{
			"name":    GroupName,
			"type":    "select",
			"proxies": names,
		}},
	}

	rules, err := buildRules(opts.Rules, opts.Final)
	if err != nil {
		return nil, err
	}
	cfg["rules"] = rules
	cfg["find-process-mode"] = "strict"
	if geoip, geosite := UsesGeo(opts.Rules); geoip || geosite {
		// .dat files, not MaxMind: runetfreedom ships geoip.dat, and the
		// daemon keeps both in HomeDir as GeoIP.dat / GeoSite.dat.
		cfg["geodata-mode"] = true
		cfg["geo-auto-update"] = false
		geox := map[string]any{}
		if opts.GeoIPURL != "" {
			geox["geoip"] = opts.GeoIPURL
		}
		if opts.GeoSiteURL != "" {
			geox["geosite"] = opts.GeoSiteURL
		}
		cfg["geox-url"] = geox
	}
	if opts.MixedPort > 0 {
		cfg["mixed-port"] = opts.MixedPort
	}
	if opts.Tun != nil {
		tun := tunConfig(opts.Tun)
		if opts.Tun.FileDescriptor > 0 {
			if pkgs := append(bypassPackages(opts.Rules), opts.Tun.ExcludePackages...); len(pkgs) > 0 {
				tun["exclude-package"] = pkgs
			}
		}
		cfg["tun"] = tun
		cfg["dns"] = dnsConfig(opts.DNS, opts.IPv6)
		cfg["sniffer"] = snifferConfig()
	}

	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, fmt.Errorf("engine: marshal config: %w", err)
	}
	return out, nil
}

// withFingerprint makes sure every TLS proxy has a client-fingerprint.
// Without one mihomo speaks Go's crypto/tls ClientHello, which DPI tells
// apart from a browser. mihomo used to have a global default for this, but
// v1.19.33 removed it and only logs an error, so it is per proxy now.
func withFingerprint(p map[string]any) map[string]any {
	if _, ok := p["client-fingerprint"]; ok {
		return p
	}
	tls, _ := p["tls"].(bool)
	_, reality := p["reality-opts"]
	typ, _ := p["type"].(string)
	if !tls && !reality && typ != "trojan" && typ != "anytls" {
		return p
	}

	out := make(map[string]any, len(p)+1)
	for k, v := range p {
		out[k] = v
	}
	out["client-fingerprint"] = "chrome"
	return out
}

func tunConfig(t *TunOptions) map[string]any {
	stack := t.Stack
	if stack == "" {
		stack = "mixed"
	}
	tun := map[string]any{
		"enable": true,
		"stack":  stack,
		"device": tunDevice, // empty on macOS, which insists on utunN
		"dns-hijack": []string{
			"any:53",
			"tcp://any:53",
		},
		// strict-route cuts IPv6 off entirely and drags excluded apps into the
		// tunnel anyway, which is exactly how Happ breaks games and P2P.
		"strict-route": false,
	}
	if t.MTU > 0 {
		tun["mtu"] = t.MTU
	}
	// mihomo defaults auto-route to true, so the Android case spells it out.
	auto := t.FileDescriptor == 0
	tun["auto-route"] = auto
	tun["auto-detect-interface"] = auto
	if t.FileDescriptor > 0 {
		tun["file-descriptor"] = t.FileDescriptor
	}
	if len(t.ExcludePackages) > 0 {
		tun["exclude-package"] = t.ExcludePackages
	}
	return tun
}

// dnsConfig: names resolve through the tunnel (no DNS leaks, no poisoned
// answers from the local ISP), except node addresses and DIRECT traffic,
// which use the system resolver so they never loop through the node.
func dnsConfig(o DNSOptions, ipv6 bool) map[string]any {
	servers := []string{"https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"}
	if len(o.Servers) > 0 {
		servers = o.Servers
	}
	viaNode := make([]string, 0, len(servers))
	for _, s := range servers {
		// "#Crocell" sends the query through the node; keep any routing the
		// person spelled out themselves.
		if !strings.Contains(s, "#") {
			s += "#" + GroupName
		}
		viaNode = append(viaNode, s)
	}
	// Never "system" here. With TUN up, the system resolver (systemd-resolved
	// on Linux, the VPN's DNS on Android) asks mihomo itself, gets a fake
	// address back, and every DIRECT connection and every node given by
	// name dials into nowhere. Plain servers by IP go out past the tunnel.
	var direct []string
	for _, s := range o.DirectServers {
		if !isSystemDNS(s) {
			direct = append(direct, s)
		}
	}
	if len(direct) == 0 {
		direct = defaultDirectDNS
	}
	mode := "fake-ip"
	if o.RealIP {
		mode = "redir-host"
	}

	return map[string]any{
		"enable":        true,
		"ipv6":          ipv6,
		"enhanced-mode": mode,
		"fake-ip-range": "198.18.0.1/16",
		// Things that break when they see a fake address: captive portal and
		// connectivity checks, NTP, STUN for calls and games, console networks.
		"fake-ip-filter": []string{
			"*.lan",
			"*.local",
			"*.localdomain",
			"localhost",
			"+.msftconnecttest.com",
			"+.msftncsi.com",
			"+.ntp.org",
			"time.*.com",
			"time.*.gov",
			"+.stun.*.*",
			"+.stun.*.*.*",
			"+.srv.nintendo.net",
			"+.stun.playstation.net",
			"xbox.*.microsoft.com",
			"+.xboxlive.com",
		},
		"default-nameserver":      defaultDirectDNS,
		"nameserver":              viaNode,
		"proxy-server-nameserver": append([]string{}, direct...),
		"direct-nameserver":       direct,
	}
}

// defaultDirectDNS answers for sites that go direct and for node addresses:
// Yandex for local answers in Russia, Cloudflare everywhere else. mihomo
// asks both and takes whichever replies first.
var defaultDirectDNS = []string{"77.88.8.8", "1.1.1.1"}

// isSystemDNS reports a server that means "whatever the OS uses", which
// loops back into the tunnel while it is up.
func isSystemDNS(s string) bool {
	s = strings.ToLower(strings.TrimSpace(s))
	return s == "system" || strings.HasPrefix(s, "system://")
}

// snifferConfig recovers domains from TLS SNI / HTTP Host / QUIC, so rules by
// domain work even when an app connected to a bare IP.
func snifferConfig() map[string]any {
	return map[string]any{
		"enable":               true,
		"parse-pure-ip":        true,
		"override-destination": false,
		"sniff": map[string]any{
			"TLS":  map[string]any{"ports": []int{443, 8443}},
			"HTTP": map[string]any{"ports": []int{80, 8080}},
			"QUIC": map[string]any{"ports": []int{443, 8443}},
		},
	}
}
