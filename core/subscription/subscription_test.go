package subscription

import (
	"bytes"
	"compress/zlib"
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func readFixture(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestParseLinks(t *testing.T) {
	for _, fixture := range []string{"links.txt", "links.b64"} {
		t.Run(fixture, func(t *testing.T) {
			format, info, nodes, err := Parse(readFixture(t, fixture))
			if err != nil {
				t.Fatal(err)
			}
			if format != FormatLinks {
				t.Errorf("format = %q, want links", format)
			}
			if info.Title != "WISELESS" {
				t.Errorf("title = %q, want WISELESS", info.Title)
			}
			if info.UpdateInterval != time.Hour {
				t.Errorf("update interval = %v, want 1h", info.UpdateInterval)
			}
			if info.Total != 0 || !info.Expire.IsZero() {
				t.Errorf("total=0 expire=0 must mean unlimited, got %d %v", info.Total, info.Expire)
			}
			if len(nodes) != 4 {
				t.Fatalf("got %d nodes, want 4", len(nodes))
			}

			byName := map[string]Node{}
			for _, n := range nodes {
				byName[n.Name] = n
			}

			hy := byName["auto-2 (HYSTERIA)"]
			if hy.Type != "hysteria2" || hy.Proxy["obfs"] != "salamander" {
				t.Errorf("hysteria2 node = %+v", hy.Proxy)
			}

			xhttp := byName["🇳🇱 nl"]
			if xhttp.Proxy["network"] != "xhttp" {
				t.Errorf("nl network = %v, want xhttp", xhttp.Proxy["network"])
			}
			if xhttp.Proxy["client-fingerprint"] != "firefox" {
				t.Errorf("nl fingerprint = %v, want firefox", xhttp.Proxy["client-fingerprint"])
			}
			if _, ok := xhttp.Proxy["reality-opts"]; !ok {
				t.Error("nl lost reality-opts")
			}

			vision := byName["auto-2"]
			if vision.Proxy["flow"] != "xtls-rprx-vision" {
				t.Errorf("auto-2 flow = %v", vision.Proxy["flow"])
			}
		})
	}
}

func TestFetchClashWithProvider(t *testing.T) {
	links := readFixture(t, "links.b64")
	mux := http.NewServeMux()
	srv := httptest.NewServer(mux)
	defer srv.Close()

	clash := strings.Replace(string(readFixture(t, "clash.yaml")), "PROVIDER_URL", srv.URL+"/provider", 1)
	mux.HandleFunc("/sub", func(w http.ResponseWriter, r *http.Request) {
		if !strings.Contains(r.UserAgent(), "clash") {
			t.Errorf("user agent %q should mention clash", r.UserAgent())
		}
		w.Header().Set("Profile-Title", "base64:0KLQtdGB0YI=") // "Тест"
		w.Header().Set("Subscription-Userinfo", "upload=10; download=20; total=1073741824; expire=1893456000")
		w.Header().Set("Profile-Update-Interval", "12")
		_, _ = w.Write([]byte(clash))
	})
	mux.HandleFunc("/provider", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write(links)
	})

	sub, err := (&Fetcher{}).Fetch(context.Background(), srv.URL+"/sub")
	if err != nil {
		t.Fatal(err)
	}
	if sub.Format != FormatClash {
		t.Errorf("format = %q, want clash", sub.Format)
	}
	if got := len(sub.Nodes); got != 5 {
		t.Errorf("got %d nodes, want 1 inline + 4 from provider", got)
	}
	if sub.Info.Title != "Тест" {
		t.Errorf("title = %q", sub.Info.Title)
	}
	if sub.Info.Total != 1<<30 || sub.Info.Download != 20 || sub.Info.Expire.Unix() != 1893456000 {
		t.Errorf("userinfo = %+v", sub.Info)
	}
	if sub.Info.UpdateInterval != 12*time.Hour {
		t.Errorf("update interval = %v", sub.Info.UpdateInterval)
	}
}

func TestDuplicateNamesAreRenamed(t *testing.T) {
	nodes := uniqueNames([]Node{
		{Name: "a", Proxy: map[string]any{"name": "a"}},
		{Name: "a", Proxy: map[string]any{"name": "a"}},
		{Name: "b", Proxy: map[string]any{"name": "b"}},
	})
	if nodes[1].Name == "a" || nodes[1].Proxy["name"] != nodes[1].Name {
		t.Errorf("duplicate not renamed: %+v", nodes[1])
	}
}

func TestTitleFromContentDisposition(t *testing.T) {
	h := http.Header{}
	h.Set("Content-Disposition", `attachment; filename="WISELESS.txt"`)
	if got := infoFromHeader(h).Title; got != "WISELESS" {
		t.Errorf("title = %q", got)
	}
}

func TestJSONIsReportedAsUnsupported(t *testing.T) {
	_, _, _, err := Parse([]byte(`{"outbounds": []}`))
	if err == nil || !strings.Contains(err.Error(), "JSON") {
		t.Errorf("err = %v", err)
	}
}

const awgConf = `[Interface]
# Name = office
PrivateKey = cHJpdmF0ZQ==
Address = 10.8.1.2/32, fd00::2/128
DNS = 1.1.1.1
MTU = 1376
Jc = 4
Jmin = 10
Jmax = 50
S1 = 86
S2 = 130
H1 = 1234567
H2 = 2345678-2345700
H3 = 3456789
H4 = 4567890
I1 = <b 0xc0ff>

[Peer]
PublicKey = cHVibGlj
PresharedKey = cHNr
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = awg.example.net:51820
PersistentKeepalive = 25
`

func TestAmneziaWGConfig(t *testing.T) {
	sub, err := (&Fetcher{}).Fetch(context.Background(), awgConf)
	if err != nil {
		t.Fatal(err)
	}
	if sub.Format != FormatConfig || len(sub.Nodes) != 1 || sub.Info.Title != "office" {
		t.Fatalf("format %q, title %q, nodes %v", sub.Format, sub.Info.Title, sub.Nodes)
	}
	p := sub.Nodes[0].Proxy
	for k, want := range map[string]any{
		"type": "wireguard", "name": "office", "server": "awg.example.net", "port": 51820,
		"private-key": "cHJpdmF0ZQ==", "public-key": "cHVibGlj", "pre-shared-key": "cHNr",
		"ip": "10.8.1.2/32", "ipv6": "fd00::2/128", "mtu": 1376, "persistent-keepalive": 25, "udp": true,
	} {
		if p[k] != want {
			t.Errorf("%s = %v, want %v", k, p[k], want)
		}
	}
	awg, _ := p["amnezia-wg-option"].(map[string]any)
	for k, want := range map[string]any{"jc": 4, "jmin": 10, "jmax": 50, "s1": 86, "s2": 130, "h2": "2345678-2345700", "i1": "<b 0xc0ff>"} {
		if awg[k] != want {
			t.Errorf("amnezia %s = %v, want %v", k, awg[k], want)
		}
	}
}

func TestPlainWireGuardHasNoAmneziaOption(t *testing.T) {
	conf := "[Interface]\nPrivateKey = a\nAddress = 10.0.0.2/32\n[Peer]\nPublicKey = b\nEndpoint = wg.example.net:51820\n"
	_, _, nodes, err := Parse([]byte(conf))
	if err != nil {
		t.Fatal(err)
	}
	if _, has := nodes[0].Proxy["amnezia-wg-option"]; has || nodes[0].Name != "WireGuard wg.example.net" {
		t.Errorf("node = %+v", nodes[0])
	}
}

func TestWireGuardLinks(t *testing.T) {
	links := "awg://cHJpdg==@awg.example.net:51820?publickey=cHVi&address=10.8.1.2/32&jc=4&jmin=10&jmax=50&h1=7#Finland\n" +
		"wireguard://cHJpdg==@wg.example.net:443?public_key=cHVi&ip=10.8.1.3&reserved=1,2,3#Plain\n" +
		"trojan://secret@tr.example.net:443#Trojan\n"
	_, _, nodes, err := Parse([]byte(links))
	if err != nil {
		t.Fatal(err)
	}
	if len(nodes) != 3 {
		t.Fatalf("nodes = %d", len(nodes))
	}
	byName := map[string]Node{}
	for _, n := range nodes {
		byName[n.Name] = n
	}
	awg := byName["Finland"].Proxy
	if awg["type"] != "wireguard" || awg["server"] != "awg.example.net" || awg["amnezia-wg-option"] == nil {
		t.Errorf("awg link = %v", awg)
	}
	if plain := byName["Plain"].Proxy; plain["amnezia-wg-option"] != nil || fmt.Sprint(plain["reserved"]) != "[1 2 3]" {
		t.Errorf("wireguard link = %v", plain)
	}
	if byName["Trojan"].Type != "trojan" {
		t.Error("the converter's links must still work next to ours")
	}
}

func amneziaKey(t *testing.T, doc map[string]any) string {
	t.Helper()
	raw, err := json.Marshal(doc)
	if err != nil {
		t.Fatal(err)
	}
	var z bytes.Buffer
	w := zlib.NewWriter(&z)
	w.Write(raw)
	w.Close()
	head := binary.BigEndian.AppendUint32(nil, uint32(len(raw)))
	return "vpn://" + base64.RawURLEncoding.EncodeToString(append(head, z.Bytes()...))
}

func TestAmneziaVPNKey(t *testing.T) {
	last, _ := json.Marshal(map[string]any{"config": awgConf, "hostName": "awg.example.net"})
	key := amneziaKey(t, map[string]any{
		"description": "My server",
		"hostName":    "awg.example.net",
		"containers": []any{
			map[string]any{"container": "amnezia-awg", "awg": map[string]any{"last_config": string(last)}},
			map[string]any{"container": "amnezia-xray", "xray": map[string]any{"last_config": "{}"}},
		},
	})
	sub, err := (&Fetcher{}).Fetch(context.Background(), key)
	if err != nil {
		t.Fatal(err)
	}
	if len(sub.Nodes) != 1 || sub.Nodes[0].Name != "My server" || sub.Nodes[0].Proxy["amnezia-wg-option"] == nil {
		t.Fatalf("nodes = %+v", sub.Nodes)
	}

	xrayOnly := amneziaKey(t, map[string]any{"containers": []any{map[string]any{"container": "amnezia-xray"}}})
	if _, err := (&Fetcher{}).Fetch(context.Background(), xrayOnly); !errors.Is(err, ErrUnsupported) || !strings.Contains(err.Error(), "amnezia-xray") {
		t.Errorf("xray-only key: %v", err)
	}
	if _, err := (&Fetcher{}).Fetch(context.Background(), "vpn://%%%"); err == nil {
		t.Error("garbage key accepted")
	}
}

func TestPastedShareLinkIsASubscription(t *testing.T) {
	sub, err := (&Fetcher{}).Fetch(context.Background(), "  trojan://secret@tr.example.net:443#Solo\n")
	if err != nil {
		t.Fatal(err)
	}
	if len(sub.Nodes) != 1 || sub.Info.Title != "Solo" {
		t.Errorf("sub = %+v", sub)
	}
}
