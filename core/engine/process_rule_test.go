package engine

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"
)

// A program rule makes mihomo look up the owner of every connection. That
// must not stop the rest of the traffic: here a rule for a program that is
// not running sits in front, and a plain request still goes through.
// Everything stays on localhost; nothing dials a node.
func TestProgramRuleLeavesOtherTrafficAlone(t *testing.T) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	srv := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { io.WriteString(w, "ok") })}
	go srv.Serve(l)
	defer srv.Close()

	port := freePort(t)
	opts := Options{
		HomeDir: t.TempDir(), MixedPort: port, LogLevel: "silent", Nodes: testNodes(),
		Rules: []Rule{
			{Kind: ProcessPath, Value: "/opt/google/chrome/chrome", Action: Direct},
			{Kind: ProcessName, Value: "chrome", Action: Direct},
		},
		Final: Direct,
	}
	if err := Start(opts); err != nil {
		t.Fatal(err)
	}
	defer Stop()

	proxy, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port))
	client := &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: http.ProxyURL(proxy)}}
	start := time.Now()
	// By name, so the private-network rule up front cannot match by IP and
	// the program rules are really consulted.
	resp, err := client.Get(fmt.Sprintf("http://localhost:%d/", l.Addr().(*net.TCPAddr).Port))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "ok" {
		t.Fatalf("got %q", body)
	}
	t.Logf("through program rules in %v", time.Since(start))
}
