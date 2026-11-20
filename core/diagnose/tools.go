package diagnose

import (
	"slices"
	"strings"
)

// tools are VPNs and DPI bypassers by the names of their processes. Two of
// them at once often get in each other's way, so after a failure the person
// hears that one is running. From dpi-detector's bypass_detector, without the
// generic names (trojan, naive) that Crocell itself may start one day.
var tools = []struct {
	name  string
	procs []string
}{
	{"zapret", []string{"nfqws", "tpws", "zapret", "dvtws", "dbproxy", "winws"}},
	{"GoodbyeDPI", []string{"goodbyedpi", "goodbye-dpi"}},
	{"ByeDPI", []string{"byedpi", "ciadpi"}},
	{"SpoofDPI", []string{"spoofdpi"}},
	{"Green Tunnel", []string{"greentunnel", "green-tunnel"}},
	{"PowerTunnel", []string{"powertunnel"}},
	{"Hysteria", []string{"hysteria"}},
	{"Wstunnel", []string{"wstunnel"}},
	{"Xray", []string{"xray"}},
	{"V2Ray", []string{"v2ray", "v2rayn"}},
	{"FlClash", []string{"flclash", "flclashx", "flclashcore"}},
	{"Clash", []string{"mihomo", "clash", "clash-meta", "clash-verge", "clash_verge", "verge-mihomo"}},
	{"sing-box", []string{"sing-box"}},
	{"Hiddify", []string{"hiddify", "hiddifycli"}},
	{"NekoBox", []string{"nekobox", "nekoray", "throne"}},
	{"AmneziaVPN", []string{"amneziavpn", "amneziawg", "amneziawg-go"}},
	{"WireGuard", []string{"wireguard"}},
	{"OpenVPN", []string{"openvpn"}},
	{"Outline", []string{"outline", "outline-client"}},
	{"WARP", []string{"warp-svc", "cloudflarewarp", "cloudflare warp"}},
	{"Tailscale", []string{"tailscaled", "tailscale"}},
	{"ZeroTier", []string{"zerotier-one", "zerotier"}},
	{"Mullvad", []string{"mullvad-daemon", "mullvad"}},
	{"NordVPN", []string{"nordvpnd", "nordvpn"}},
}

// OtherTools names the VPNs and bypassers among running process names,
// each once, in a stable order.
func OtherTools(names []string) []string {
	running := make(map[string]bool, len(names))
	for _, n := range names {
		n = strings.ToLower(n)
		n = strings.TrimSuffix(n, ".exe")
		running[n] = true
	}
	var found []string
	for _, t := range tools {
		if slices.ContainsFunc(t.procs, func(p string) bool { return running[p] }) {
			found = append(found, t.name)
		}
	}
	return found
}
