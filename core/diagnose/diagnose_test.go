package diagnose

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"errors"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"slices"
	"syscall"
	"testing"
	"time"
)

// world routes the addresses Run dials to local test servers, so nothing
// leaves the machine. A missing route behaves like a dropped packet.
type world struct {
	routes map[string]string // "ip:port" -> local address, "" = refused
}

func (w world) dial(ctx context.Context, network, addr string) (net.Conn, error) {
	to, ok := w.routes[addr]
	if !ok {
		<-ctx.Done()
		return nil, ctx.Err()
	}
	if to == "" {
		return nil, &net.OpError{Op: "dial", Net: network, Err: syscall.ECONNREFUSED}
	}
	var d net.Dialer
	return d.DialContext(ctx, "tcp", to)
}

func tlsServer(t *testing.T) *httptest.Server {
	t.Helper()
	s := httptest.NewTLSServer(http.NotFoundHandler())
	t.Cleanup(s.Close)
	return s
}

// env sets up a network where "example.com" (the allowed site, as the test
// certificate is made out to it) is at 192.0.2.10, the foreign check at
// 127.0.0.1, and the node at node.test:8443 = 192.0.2.20.
func env(routes map[string]string, roots *x509.CertPool) Env {
	w := world{routes: routes}
	return Env{
		Dial: w.dial,
		Lookup: func(ctx context.Context, host string) ([]string, error) {
			switch host {
			case "example.com":
				return []string{"192.0.2.10"}, nil
			case "node.test":
				return []string{"192.0.2.20"}, nil
			}
			return nil, errors.New("no such host")
		},
		Allowed: []string{"example.com"},
		Foreign: "127.0.0.1",
		Roots:   roots,
		Node:    "node.test:8443",
		Step:    300 * time.Millisecond,
	}
}

// substitute serves TLS with a fresh self-signed certificate for 127.0.0.1,
// what a provider's middlebox would hand out. httptest servers all share
// one certificate, so it cannot play this part.
func substitute(t *testing.T) string {
	t.Helper()
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "middlebox"},
		IPAddresses:  []net.IP{net.IPv4(127, 0, 0, 1)},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	l, err := tls.Listen("tcp", "127.0.0.1:0", &tls.Config{Certificates: []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: key}}})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			go func() { _ = c.(*tls.Conn).Handshake(); c.Close() }()
		}
	}()
	return l.Addr().String()
}

func pool(s *httptest.Server) *x509.CertPool {
	p := x509.NewCertPool()
	p.AddCert(s.Certificate())
	return p
}

func TestVerdicts(t *testing.T) {
	good := tlsServer(t)
	other := substitute(t)
	nodeUp, _ := net.Listen("tcp", "127.0.0.1:0")
	t.Cleanup(func() { nodeUp.Close() })
	g := good.Listener.Addr().String()

	cases := []struct {
		name   string
		routes map[string]string
		want   Verdict
	}{
		{"nothing answers", map[string]string{}, NoInternet},
		{"only the allowed site", map[string]string{"192.0.2.10:443": g}, Whitelist},
		{"everything but the node", map[string]string{"192.0.2.10:443": g, "127.0.0.1:443": g, "192.0.2.20:8443": ""}, NodeBlocked},
		{"node reachable, still silent", map[string]string{"192.0.2.10:443": g, "127.0.0.1:443": g, "192.0.2.20:8443": nodeUp.Addr().String()}, NodeDown},
		{"foreign certificate substituted", map[string]string{"192.0.2.10:443": g, "127.0.0.1:443": other}, Intercepted},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			r := Run(context.Background(), env(c.routes, pool(good)))
			if r.Verdict != c.want {
				t.Errorf("verdict %v, want %v (%s)", r.Verdict, c.want, r.Detail)
			}
		})
	}
}

// QUIC and WireGuard nodes listen on UDP: no TCP connect means nothing.
func TestUDPNodeSkipsReachability(t *testing.T) {
	good := tlsServer(t)
	g := good.Listener.Addr().String()
	e := env(map[string]string{"192.0.2.10:443": g, "127.0.0.1:443": g}, pool(good))
	e.NodeUDP = true
	if r := Run(context.Background(), e); r.Verdict != NodeDown {
		t.Errorf("verdict %v (%s)", r.Verdict, r.Detail)
	}
}

func TestStageWords(t *testing.T) {
	for err, want := range map[error]string{
		nil: "ok",
		errors.Join(errors.New("tcp: dial"), &net.OpError{Err: syscall.ECONNRESET}): "tcp reset",
		context.DeadlineExceeded: "timeout",
	} {
		if got := Stage(err); got != want {
			t.Errorf("Stage(%v) = %q, want %q", err, got, want)
		}
	}
}

func TestDefaultAllowedSitesAreOnTheList(t *testing.T) {
	list := WhitelistSNI()
	if len(list) < 100 {
		t.Fatalf("list has %d names", len(list))
	}
	for _, h := range AllowedDefault {
		if !slices.Contains(list, h) {
			t.Errorf("%s is not on the whitelist", h)
		}
	}
}

func TestOtherTools(t *testing.T) {
	got := OtherTools([]string{"bash", "Hiddify.exe", "sing-box", "winws.exe", "crocelld", "firefox"})
	want := []string{"zapret", "sing-box", "Hiddify"}
	if !slices.Equal(got, want) {
		t.Errorf("got %v, want %v", got, want)
	}
}
