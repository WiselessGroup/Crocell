package probe

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
)

// A plain-HTTP trace URL lets a fake proxy answer it directly.
func TestViaProxyGoesThroughTheMixedPort(t *testing.T) {
	old := traceURLs
	traceURLs = []string{"http://trace.invalid/cdn-cgi/trace"}
	t.Cleanup(func() { traceURLs = old })

	hits := 0
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		if r.URL.Host != "trace.invalid" {
			t.Errorf("proxy got %s, want an absolute URL for trace.invalid", r.URL)
		}
		_, _ = w.Write([]byte("fl=1\nip=203.0.113.7\nloc=NL\ncolo=AMS\n"))
	}))
	defer proxy.Close()

	_, portStr, _ := net.SplitHostPort(proxy.Listener.Addr().String())
	port, _ := strconv.Atoi(portStr)

	r := ViaProxy(context.Background(), port)
	if r.Err != nil {
		t.Fatal(r.Err)
	}
	if hits != 1 || r.ExitIP != "203.0.113.7" || r.ExitCountry != "NL" || r.ExitColo != "AMS" {
		t.Errorf("hits %d, result %+v", hits, r)
	}
}

func TestDeadProxyIsAnError(t *testing.T) {
	l, _ := net.Listen("tcp", "127.0.0.1:0")
	port := l.Addr().(*net.TCPAddr).Port
	l.Close()

	if r := ViaProxy(context.Background(), port); r.Err == nil {
		t.Error("want an error from a closed port")
	}
}
