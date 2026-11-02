package engine

import (
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"

	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

func testNodes() []subscription.Node {
	return []subscription.Node{
		{Name: "reality", Proxy: map[string]any{
			"name": "reality", "type": "vless", "server": "a.example.com", "port": 443,
			"uuid": "00000000-0000-4000-8000-000000000001", "network": "tcp", "tls": true,
			"servername": "www.example.org",
			"reality-opts": map[string]any{
				"public-key": "dGVzdC1wdWJsaWMta2V5LXRlc3QtcHVibGljLWtleS0", "short-id": "abcd",
			},
		}},
		{Name: "trojan", Proxy: map[string]any{
			"name": "trojan", "type": "trojan", "server": "b.example.com", "port": 443,
			"password": "secret", "client-fingerprint": "firefox",
		}},
		{Name: "ss", Proxy: map[string]any{
			"name": "ss", "type": "ss", "server": "c.example.com", "port": 8388,
			"cipher": "aes-128-gcm", "password": "secret",
		}},
	}
}

// mihomo must accept what we generate. Parsing builds proxies, groups, rules,
// DNS and TUN settings without opening any listener.
func parse(t *testing.T, opts Options) *config.Config {
	t.Helper()
	raw, err := buildConfig(opts)
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := config.Parse(raw)
	if err != nil {
		t.Fatalf("mihomo rejected our config: %v\n%s", err, raw)
	}
	return cfg
}

func TestProxyOnlyConfig(t *testing.T) {
	cfg := parse(t, Options{MixedPort: 7890, Nodes: testNodes()})

	if cfg.General.MixedPort != 7890 {
		t.Errorf("mixed port = %d", cfg.General.MixedPort)
	}
	if cfg.General.Tun.Enable {
		t.Error("tun must be off without TunOptions")
	}
	if _, ok := cfg.Proxies[GroupName]; !ok {
		t.Errorf("selector %q missing", GroupName)
	}
	for _, name := range []string{"reality", "trojan", "ss"} {
		if _, ok := cfg.Proxies[name]; !ok {
			t.Errorf("proxy %q missing", name)
		}
	}
}

func TestTunConfig(t *testing.T) {
	cfg := parse(t, Options{Nodes: testNodes(), Tun: &TunOptions{}})

	tun := cfg.General.Tun
	if !tun.Enable || !tun.AutoRoute || !tun.AutoDetectInterface {
		t.Errorf("tun = %+v", tun)
	}
	if tun.StrictRoute {
		t.Error("strict-route must stay off: it kills IPv6 and excluded apps")
	}
	if tun.Stack != C.TunMixed {
		t.Errorf("stack = %v, want mixed", tun.Stack)
	}
	if !cfg.DNS.Enable || cfg.DNS.EnhancedMode != C.DNSFakeIP {
		t.Errorf("dns = enable %v mode %v", cfg.DNS.Enable, cfg.DNS.EnhancedMode)
	}
}

func TestAndroidTunUsesFileDescriptor(t *testing.T) {
	cfg := parse(t, Options{Nodes: testNodes(), Tun: &TunOptions{
		FileDescriptor:  42,
		ExcludePackages: []string{"com.valvesoftware.android.steam.community"},
	}})

	tun := cfg.General.Tun
	if tun.FileDescriptor != 42 {
		t.Errorf("fd = %d", tun.FileDescriptor)
	}
	if tun.AutoRoute {
		t.Error("VpnService owns routes on Android")
	}
	if len(tun.ExcludePackage) != 1 {
		t.Errorf("exclude-package = %v", tun.ExcludePackage)
	}
}

func TestFingerprintDefaults(t *testing.T) {
	nodes := testNodes()

	if got := withFingerprint(nodes[0].Proxy)["client-fingerprint"]; got != "chrome" {
		t.Errorf("reality without fp got %v, want chrome", got)
	}
	if _, ok := nodes[0].Proxy["client-fingerprint"]; ok {
		t.Error("withFingerprint must not mutate the subscription node")
	}
	if got := withFingerprint(nodes[1].Proxy)["client-fingerprint"]; got != "firefox" {
		t.Errorf("explicit fp overwritten: %v", got)
	}
	if _, ok := withFingerprint(nodes[2].Proxy)["client-fingerprint"]; ok {
		t.Error("shadowsocks has no TLS, no fingerprint")
	}
}

func TestRulesThroughMihomo(t *testing.T) {
	cfg := parse(t, Options{Nodes: testNodes(), Final: Direct, Rules: []Rule{
		{Kind: DomainSuffix, Value: "+.wiseless.net", Action: Proxy},
		{Kind: Domain, Value: "Example.COM", Action: Block},
		{Kind: DomainWildcard, Value: "*.ya.ru", Action: Direct},
		{Kind: IPCIDR, Value: "149.154.160.0/20", Action: Proxy},
		{Kind: IPCIDR, Value: "1.1.1.1", Action: Direct},
		{Kind: ProcessName, Value: "steam", Action: Direct},
		{Kind: ProcessPath, Value: `C:\Games\Dota\dota2.exe`, Action: Direct},
	}})

	var got []string
	for _, r := range cfg.Rules[len(privateNets):] {
		got = append(got, r.RuleType().String()+","+r.Payload()+","+r.Adapter())
	}
	want := []string{
		`ProcessPath,C:\Games\Dota\dota2.exe,DIRECT`,
		"ProcessName,steam,DIRECT",
		"Domain,example.com,REJECT",
		"DomainWildcard,*.ya.ru,DIRECT",
		"DomainSuffix,wiseless.net," + GroupName,
		"IPCIDR,1.1.1.1/32,DIRECT",
		"IPCIDR,149.154.160.0/20," + GroupName,
		"Match,,DIRECT",
	}
	if len(got) != len(want) {
		t.Fatalf("rules = %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("rule %d = %q, want %q", i, got[i], want[i])
		}
	}
	if cfg.Rules[0].Adapter() != "DIRECT" {
		t.Error("LAN must come first and go direct")
	}
}

// Geo rules are checked as lines: parsing them would make mihomo fetch
// geosite.dat from the network.
func TestGeoRulesAndPrecedence(t *testing.T) {
	lines, err := buildRules([]Rule{
		{Kind: GeoSite, Value: "category-ru", Action: Direct},
		{Kind: GeoIP, Value: "RU", Action: Direct},
		{Kind: GeoSite, Value: "ru-blocked", Action: Proxy},
		{Kind: GeoSite, Value: "category-ads-all", Action: Block},
		{Kind: DomainSuffix, Value: "kinopoisk.ru", Action: Proxy},
	}, Proxy)
	if err != nil {
		t.Fatal(err)
	}
	got := lines[len(privateNets):]
	want := []string{
		"DOMAIN-SUFFIX,kinopoisk.ru," + GroupName, // one site beats the set it belongs to
		"GEOSITE,category-ads-all,REJECT",
		"GEOSITE,category-ru,DIRECT",
		"GEOSITE,ru-blocked," + GroupName,
		"GEOIP,ru,DIRECT",
		"MATCH," + GroupName,
	}
	if len(got) != len(want) {
		t.Fatalf("lines = %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("line %d = %q, want %q", i, got[i], want[i])
		}
	}

	if ip, site := UsesGeo([]Rule{{Kind: GeoIP, Value: "ru"}}); !ip || site {
		t.Errorf("UsesGeo = %v %v", ip, site)
	}
	raw, err := buildConfig(Options{Nodes: testNodes(), Rules: []Rule{{Kind: GeoSite, Value: "ru-blocked"}}, GeoSiteURL: "https://example.com/geosite.dat"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(raw), "geodata-mode: true") || !strings.Contains(string(raw), "https://example.com/geosite.dat") {
		t.Errorf("geo settings missing:\n%s", raw)
	}
}

func TestBadRulesAreRefused(t *testing.T) {
	for _, r := range []Rule{
		{Kind: ProcessName, Value: "evil,DIRECT\nMATCH"},
		{Kind: Domain, Value: "not a domain"},
		{Kind: IPCIDR, Value: "300.1.1.1/8"},
		{Kind: GeoSite, Value: "ru blocked"},
		{Kind: Domain, Value: ""},
	} {
		if _, err := buildRules([]Rule{r}, Proxy); err == nil {
			t.Errorf("%+v accepted", r)
		}
	}
}

func TestDNSOptions(t *testing.T) {
	cfg := parse(t, Options{Nodes: testNodes(), Tun: &TunOptions{}, IPv6: false, DNS: DNSOptions{
		Servers: []string{"https://dns.adguard-dns.com/dns-query", "tls://1.1.1.1#DIRECT"},
		RealIP:  true,
	}})
	if cfg.DNS.EnhancedMode != C.DNSMapping {
		t.Errorf("real IP mode = %v, want redir-host", cfg.DNS.EnhancedMode)
	}
	if cfg.DNS.IPv6 || cfg.General.IPv6 {
		t.Error("IPv6 off must reach both general and DNS")
	}
	raw, _ := buildConfig(Options{Nodes: testNodes(), Tun: &TunOptions{}, DNS: DNSOptions{
		Servers: []string{"https://dns.adguard-dns.com/dns-query", "tls://1.1.1.1#DIRECT"},
	}})
	if !strings.Contains(string(raw), "dns.adguard-dns.com/dns-query#"+GroupName) || !strings.Contains(string(raw), "tls://1.1.1.1#DIRECT") {
		t.Errorf("custom servers not routed as asked:\n%s", raw)
	}
}

// With TUN up, "system" DNS is the tunnel itself: DIRECT sites resolved to
// fake addresses and timed out (myip.com went to 198.18.0.24).
func TestDirectDNSNeverLoopsIntoTunnel(t *testing.T) {
	for _, direct := range [][]string{nil, {"system"}, {"system", "9.9.9.9"}} {
		raw, err := buildConfig(Options{Nodes: testNodes(), Tun: &TunOptions{}, DNS: DNSOptions{DirectServers: direct}})
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(raw), "system") {
			t.Errorf("direct %v: config still uses the system resolver:\n%s", direct, raw)
		}
		cfg := parse(t, Options{Nodes: testNodes(), Tun: &TunOptions{}, DNS: DNSOptions{DirectServers: direct}})
		if len(cfg.DNS.DirectNameServer) == 0 || len(cfg.DNS.ProxyServerNameserver) == 0 {
			t.Errorf("direct %v: no direct or node resolver left", direct)
		}
	}
}

func TestAndroidBypassSkipsTunnel(t *testing.T) {
	cfg := parse(t, Options{
		Nodes: testNodes(),
		Tun:   &TunOptions{FileDescriptor: 7},
		Rules: []Rule{{Kind: ProcessName, Value: "com.valvesoftware.android.steam.community", Action: Direct}},
	})
	if len(cfg.General.Tun.ExcludePackage) != 1 {
		t.Errorf("exclude-package = %v", cfg.General.Tun.ExcludePackage)
	}
}

// v2ray lists carry whole zones: domain:ru is everything under .ru. As a
// suffix that is fine; as one exact domain it is a typo.
func TestZonesAsSuffix(t *testing.T) {
	cfg := parse(t, Options{Nodes: testNodes(), Rules: []Rule{
		{Kind: DomainSuffix, Value: "ru", Action: Direct},
		{Kind: DomainSuffix, Value: "xn--p1ai", Action: Direct},
	}})
	var got []string
	for _, r := range cfg.Rules[len(privateNets):] {
		got = append(got, r.RuleType().String()+","+r.Payload())
	}
	if len(got) < 2 || got[0] != "DomainSuffix,ru" || got[1] != "DomainSuffix,xn--p1ai" {
		t.Errorf("rules = %v", got)
	}
	if _, err := buildRules([]Rule{{Kind: Domain, Value: "ru"}}, Proxy); err == nil {
		t.Error("a bare zone accepted as one exact domain")
	}
}

// A WireGuard node with AmneziaWG's options goes through mihomo's own config
// parser: its fields must be the ones mihomo reads.
func TestAmneziaWGThroughMihomo(t *testing.T) {
	cfg := parse(t, Options{Nodes: []subscription.Node{{
		Name: "awg", Type: "wireguard", Server: "127.0.0.1", Port: "51820",
		Proxy: map[string]any{
			"name": "awg", "type": "wireguard", "server": "127.0.0.1", "port": 51820,
			"private-key": "aPxGfTNyxr0JAAtbgxCpZ1eHSbnNtcn3S4cGcMzQ1lI=",
			"public-key":  "IBjD9LKCWNpMKrINpxy4CqV9rGlvWbf7cZ0GjDYpkXs=",
			"ip":          "10.8.1.2/32", "udp": true,
			"amnezia-wg-option": map[string]any{"jc": 4, "jmin": 10, "jmax": 50, "s1": 86, "s2": 130, "h1": "1", "h2": "2", "h3": "3", "h4": "4"},
		},
	}}})
	if _, ok := cfg.Proxies["awg"]; !ok {
		t.Fatalf("mihomo dropped the node: %v", cfg.Proxies)
	}
}
