package subscription

import (
	"context"
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
