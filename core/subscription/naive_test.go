package subscription

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	C "github.com/metacubex/mihomo/constant"
)

// Made-up links: real ones carry access keys.
const (
	naiveLink   = "naive+https://u0a1b2c3d:c2VjcmV0LXBhc3M@naive.example.invalid:8443#NL%20naive"
	naiveQUIC   = "naive+quic://u0a1b2c3d:c2VjcmV0LXBhc3M@naive.example.invalid#quic"
	vlessSample = "vless://00000000-0000-4000-8000-000000000002@relay.example.com:443?type=tcp&security=reality&encryption=none&pbk=dGVzdC1wdWJsaWMta2V5LXRlc3QtcHVibGljLWtleS0&sid=abcd&sni=relay.example.com&fp=chrome#vless"
)

func TestParseNaiveLink(t *testing.T) {
	_, _, nodes, err := Parse([]byte(naiveLink))
	if err != nil {
		t.Fatal(err)
	}
	if len(nodes) != 1 {
		t.Fatalf("got %d nodes, want 1", len(nodes))
	}
	p := nodes[0].Proxy
	want := map[string]any{
		"name": "NL naive", "type": "trusttunnel", "server": "naive.example.invalid", "port": 8443,
		"username": "u0a1b2c3d", "password": "c2VjcmV0LXBhc3M", "sni": "naive.example.invalid",
		"client-fingerprint": "chrome", "udp": false, NaiveKey: true,
	}
	for k, v := range want {
		if p[k] != v {
			t.Errorf("%s = %v, want %v", k, p[k], v)
		}
	}
}

func TestParseNaiveLinkDetails(t *testing.T) {
	for _, tc := range []struct {
		link, user, pass, name string
		port                   int
	}{
		// Percent-encoded user and password, no port, no name.
		{"naive+https://us%40er:p%3Ass%2Fw@h.example.invalid", "us@er", "p:ss/w", "h.example.invalid:443", 443},
		// Bare "naive" scheme and query parameters other providers add.
		{"naive://a:b@h.example.invalid:444?padding=true&extra-headers=X-A%3A1#n", "a", "b", "n", 444},
	} {
		p, err := parseNaiveLink(tc.link)
		if err != nil {
			t.Errorf("%s: %v", tc.name, err)
			continue
		}
		if p["username"] != tc.user || p["password"] != tc.pass || p["name"] != tc.name || p["port"] != tc.port {
			t.Errorf("%s: got %v", tc.name, p)
		}
	}

	for _, bad := range []string{
		naiveQUIC,
		"naive+https://naive.example.invalid:443",       // no credentials
		"naive+https://user@naive.example.invalid:443",  // no password
		"naive+https://u:p@naive.example.invalid:70000", // bad port
		"naive+https://u:p@:443",                        // no host
	} {
		_, err := parseNaiveLink(bad)
		if err == nil {
			t.Errorf("%s: want an error", bad)
			continue
		}
		if strings.Contains(err.Error(), "c2VjcmV0") {
			t.Errorf("error quotes the password: %v", err)
		}
	}
}

func TestParseNaiveMixed(t *testing.T) {
	// A FTN-style feed: naive between other links, one naive+quic we skip.
	body := strings.Join([]string{vlessSample, naiveLink, naiveQUIC}, "\n")
	_, _, nodes, err := Parse([]byte(body))
	if err != nil {
		t.Fatal(err)
	}
	if len(nodes) != 2 {
		t.Fatalf("got %d nodes, want vless and naive", len(nodes))
	}

	// Only a link we can't run: say why.
	_, _, _, err = Parse([]byte(naiveQUIC))
	if !errors.Is(err, ErrUnsupported) || !strings.Contains(err.Error(), "QUIC") {
		t.Fatalf("err = %v, want ErrUnsupported about QUIC", err)
	}
}

// connectProxy is what a naive server is to a client that does not pad: an
// HTTP/2 proxy that takes CONNECT with Basic auth and shows a plain page to
// anyone without it.
func connectProxy(t *testing.T, user, pass string) *httptest.Server {
	t.Helper()
	wantAuth := "Basic " + basicAuth(user, pass)
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Proxy-Authorization") != wantAuth {
			// probe_resistance hands the request to the site, and a file
			// server has no CONNECT: no 407 that would give the proxy away.
			if r.Method == http.MethodConnect {
				w.WriteHeader(http.StatusMethodNotAllowed)
			}
			io.WriteString(w, "<html>nothing here</html>")
			return
		}
		if r.ProtoMajor != 2 {
			http.Error(w, "want HTTP/2", http.StatusHTTPVersionNotSupported)
			return
		}
		up, err := net.Dial("tcp", r.Host)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		defer up.Close()
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		go io.Copy(up, r.Body)
		buf := make([]byte, 4096)
		for {
			n, err := up.Read(buf)
			if n > 0 {
				w.Write(buf[:n])
				w.(http.Flusher).Flush()
			}
			if err != nil {
				return
			}
		}
	}))
	srv.EnableHTTP2 = true
	srv.StartTLS()
	t.Cleanup(srv.Close)
	return srv
}

func basicAuth(user, pass string) string {
	req, _ := http.NewRequest(http.MethodGet, "http://x", nil)
	req.SetBasicAuth(user, pass)
	return strings.TrimPrefix(req.Header.Get("Authorization"), "Basic ")
}

func echoServer(t *testing.T) netip.AddrPort {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	return netip.MustParseAddrPort(ln.Addr().String())
}

// TestNaiveThroughMihomo runs the mapping a naive link turns into through
// mihomo's own adapter, against a local server. No real node is involved.
func TestNaiveThroughMihomo(t *testing.T) {
	const user, pass = "u0a1b2c3d", "c2VjcmV0LXBhc3M"
	srv := connectProxy(t, user, pass)
	echo := echoServer(t)
	_, port, _ := net.SplitHostPort(strings.TrimPrefix(srv.URL, "https://"))

	dial := func(pass string) (net.Conn, error) {
		p, err := parseNaiveLink("naive+https://" + user + ":" + pass + "@127.0.0.1:" + port + "#local")
		if err != nil {
			t.Fatal(err)
		}
		p["skip-cert-verify"] = true // httptest's certificate; never set for real links
		// The daemon keeps nodes as JSON: run what comes back from there.
		raw, _ := json.Marshal(p)
		p = nil
		if err := json.Unmarshal(raw, &p); err != nil {
			t.Fatal(err)
		}
		proxy, err := adapter.ParseProxy(p)
		if err != nil {
			t.Fatalf("mihomo rejects the mapping: %v", err)
		}
		t.Cleanup(func() { proxy.Close() })
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return proxy.DialContext(ctx, &C.Metadata{NetWork: C.TCP, DstIP: echo.Addr(), DstPort: echo.Port()})
	}

	c, err := dial(pass)
	if err != nil {
		t.Fatalf("dial through the proxy: %v", err)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(5 * time.Second))
	for i := range 3 { // several writes: the stream stays open both ways
		msg := "hello " + strconv.Itoa(i)
		if _, err := io.WriteString(c, msg); err != nil {
			t.Fatal(err)
		}
		got := make([]byte, len(msg))
		if _, err := io.ReadFull(c, got); err != nil {
			t.Fatalf("read back: %v", err)
		}
		if string(got) != msg {
			t.Fatalf("echo = %q, want %q", got, msg)
		}
	}

	// A wrong password gets the plain page, which is not a tunnel.
	if bad, err := dial("wrong"); err == nil {
		bad.SetDeadline(time.Now().Add(2 * time.Second))
		if _, err := io.WriteString(bad, "x"); err == nil {
			if _, err := io.ReadFull(bad, make([]byte, 1)); err == nil {
				t.Fatal("a wrong password still tunnels")
			}
		}
		bad.Close()
	}
}
