package engine

import (
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

func TestAppRules(t *testing.T) {
	cfg := parse(t, Options{Nodes: testNodes(), AppRules: []AppRule{
		{App: "steam", Mode: AppBypass},
		{App: `C:\Games\Dota\dota2.exe`, Mode: AppBypass},
		{App: "spyware", Mode: AppBlock},
		{App: "telegram-desktop", Mode: AppProxy},
	}})

	var got []string
	for _, r := range cfg.Rules {
		got = append(got, r.RuleType().String()+","+r.Payload()+","+r.Adapter())
	}
	want := []string{
		"ProcessName,steam,DIRECT",
		`ProcessPath,C:\Games\Dota\dota2.exe,DIRECT`,
		"ProcessName,spyware,REJECT",
		"ProcessName,telegram-desktop," + GroupName,
		"Match,," + GroupName,
	}
	if len(got) != len(want) {
		t.Fatalf("rules = %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("rule %d = %q, want %q", i, got[i], want[i])
		}
	}
}

func TestAppRuleRejectsInjection(t *testing.T) {
	_, err := buildConfig(Options{Nodes: testNodes(), AppRules: []AppRule{
		{App: "evil,DIRECT\nMATCH", Mode: AppBlock},
	}})
	if err == nil {
		t.Fatal("a comma in the app name must be refused")
	}
}

func TestAndroidBypassSkipsTunnel(t *testing.T) {
	cfg := parse(t, Options{
		Nodes:    testNodes(),
		Tun:      &TunOptions{FileDescriptor: 7},
		AppRules: []AppRule{{App: "com.valvesoftware.android.steam.community", Mode: AppBypass}},
	})
	if len(cfg.General.Tun.ExcludePackage) != 1 {
		t.Errorf("exclude-package = %v", cfg.General.Tun.ExcludePackage)
	}
}
