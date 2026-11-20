package probe

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"
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

	r := ViaProxy(context.Background(), port, false)
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

	if r := ViaProxy(context.Background(), port, false); r.Err == nil {
		t.Error("want an error from a closed port")
	}
}

// An exit that drops the first trace URL without a word must still get to
// the second one: the node works, only that address is dead behind it.
func TestHangingFirstURLLeavesTimeForTheFallback(t *testing.T) {
	oldURLs, oldAttempt := traceURLs, attemptTimeout
	traceURLs = []string{"http://hang.invalid/cdn-cgi/trace", "http://trace.invalid/cdn-cgi/trace"}
	attemptTimeout = 200 * time.Millisecond
	t.Cleanup(func() { traceURLs, attemptTimeout = oldURLs, oldAttempt })

	release := make(chan struct{})
	defer close(release)
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Host == "hang.invalid" {
			select {
			case <-release:
			case <-r.Context().Done():
			}
			return
		}
		_, _ = w.Write([]byte("ip=203.0.113.9\nloc=PL\ncolo=WAW\n"))
	}))
	defer proxy.Close()

	_, portStr, _ := net.SplitHostPort(proxy.Listener.Addr().String())
	port, _ := strconv.Atoi(portStr)

	r := ViaProxy(context.Background(), port, false)
	if r.Err != nil {
		t.Fatal(r.Err)
	}
	if r.ExitIP != "203.0.113.9" || r.ExitCountry != "PL" {
		t.Errorf("result %+v", r)
	}
}

// A page without ip= is someone else answering, not the trace.
func TestTraceWithoutIPIsAnError(t *testing.T) {
	old := traceURLs
	traceURLs = []string{"http://trace.invalid/cdn-cgi/trace"}
	t.Cleanup(func() { traceURLs = old })

	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("<html>blocked</html>"))
	}))
	defer proxy.Close()

	_, portStr, _ := net.SplitHostPort(proxy.Listener.Addr().String())
	port, _ := strconv.Atoi(portStr)

	if r := ViaProxy(context.Background(), port, false); r.Err == nil {
		t.Errorf("want an error, got %+v", r)
	}
}

// bulkProxy answers the trace and serves the bulk URL through serve.
func bulkProxy(t *testing.T, serve func(w http.ResponseWriter, r *http.Request)) int {
	t.Helper()
	oldTrace, oldBulk, oldTimeout := traceURLs, bulkURL, BulkTimeout
	traceURLs = []string{"http://trace.invalid/cdn-cgi/trace"}
	bulkURL = "http://bulk.invalid/__down"
	BulkTimeout = 300 * time.Millisecond
	t.Cleanup(func() { traceURLs, bulkURL, BulkTimeout = oldTrace, oldBulk, oldTimeout })

	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Host == "bulk.invalid" {
			serve(w, r)
			return
		}
		_, _ = w.Write([]byte("ip=203.0.113.5\nloc=FI\ncolo=HEL\n"))
	}))
	t.Cleanup(proxy.Close)
	_, portStr, _ := net.SplitHostPort(proxy.Listener.Addr().String())
	port, _ := strconv.Atoi(portStr)
	return port
}

func writeBytes(w http.ResponseWriter, n int) {
	_, _ = w.Write(make([]byte, n))
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
}

func TestWholeBulkPasses(t *testing.T) {
	port := bulkProxy(t, func(w http.ResponseWriter, r *http.Request) { writeBytes(w, bulkSize) })
	if r := ViaProxy(context.Background(), port, true); r.Err != nil || r.Cut {
		t.Errorf("result %+v", r)
	}
}

// What the providers do: the first 16 KB get through, then nothing.
func TestBulkHangingAfter16KBIsACut(t *testing.T) {
	port := bulkProxy(t, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", strconv.Itoa(bulkSize))
		writeBytes(w, 16<<10)
		<-r.Context().Done()
	})
	r := ViaProxy(context.Background(), port, true)
	if !r.Cut || !errors.Is(r.Err, ErrCut) {
		t.Fatalf("want a cut, got %+v", r)
	}
	if r.ExitIP != "203.0.113.5" {
		t.Errorf("the exit found by the trace got lost: %+v", r)
	}
}

// Some cut with a reset instead of silence.
func TestBulkBrokenAfter16KBIsACut(t *testing.T) {
	port := bulkProxy(t, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", strconv.Itoa(bulkSize))
		writeBytes(w, 16<<10)
		if c, _, err := w.(http.Hijacker).Hijack(); err == nil {
			c.Close()
		}
	})
	if r := ViaProxy(context.Background(), port, true); !r.Cut {
		t.Errorf("want a cut, got %+v", r)
	}
}

// Cloudflare refusing the download says nothing about the node.
func TestBulkRefusedIsNotACut(t *testing.T) {
	port := bulkProxy(t, func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusTooManyRequests) })
	if r := ViaProxy(context.Background(), port, true); r.Err != nil || r.Cut {
		t.Errorf("result %+v", r)
	}
}

func TestShortCheckSkipsBulk(t *testing.T) {
	asked := false
	port := bulkProxy(t, func(w http.ResponseWriter, r *http.Request) { asked = true })
	if r := ViaProxy(context.Background(), port, false); r.Err != nil || asked {
		t.Errorf("asked %v, result %+v", asked, r)
	}
}
