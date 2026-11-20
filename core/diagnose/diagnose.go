// Package diagnose works out why nothing gets through a live tunnel, and says
// it as one verdict a person can act on: no internet at all, a mobile network
// in whitelist mode, a provider that blocks the node, or a node that is down.
//
// Every request here goes out past the tunnel, straight to the network, and
// only after the live check has failed twice: nothing is polled. The idea and
// the lists come from dpi-detector (github.com/Runnin4ik/dpi-detector, MIT).
package diagnose

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	_ "embed"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Verdict is the one thing a person is told.
type Verdict int

const (
	Unknown     Verdict = iota
	NoInternet          // nothing opens, the tunnel aside
	Whitelist           // Russian sites open, foreign ones do not
	NodeBlocked         // the network works, the node's server is out of reach
	NodeDown            // the network works and reaches the node, which stays silent
	Intercepted         // a foreign site answers with a certificate nobody signed
)

func (v Verdict) String() string {
	switch v {
	case NoInternet:
		return "no internet"
	case Whitelist:
		return "whitelist"
	case NodeBlocked:
		return "node blocked"
	case NodeDown:
		return "node down"
	case Intercepted:
		return "intercepted"
	}
	return "unknown"
}

// Env is what Run needs. Only Dial is required.
type Env struct {
	// Dial goes out past the tunnel.
	Dial func(ctx context.Context, network, addr string) (net.Conn, error)
	// Lookup resolves a name past the tunnel. Default: DNS at DNS through Dial.
	Lookup func(ctx context.Context, host string) ([]string, error)
	DNS    string // default 77.88.8.8:53, which whitelist networks keep open

	// Allowed are names a whitelist network still lets through. Default:
	// a few well-known ones from the embedded list.
	Allowed []string
	// Foreign is an address such a network cuts off. Default 1.1.1.1.
	Foreign string
	Port    string // for Allowed and Foreign, default 443
	Roots   *x509.CertPool

	// Node is the node's server as host:port. Empty, or NodeUDP for QUIC and
	// WireGuard nodes, skips the reachability step: a TCP connect to a UDP
	// port proves nothing.
	Node    string
	NodeUDP bool

	Step time.Duration // cap on each step, default 5s
}

// Report is the verdict and, for the log and bug reports, what each step saw.
type Report struct {
	Verdict Verdict
	Detail  string
}

// AllowedDefault are big Russian sites from the whitelist: if none of them
// opens, the network is down rather than filtered.
var AllowedDefault = []string{"vk.com", "yandex.ru", "gosuslugi.ru"}

// Run tries the three steps at once and decides.
func Run(ctx context.Context, env Env) Report {
	env.defaults()
	var (
		wg                    sync.WaitGroup
		allowed, foreign, nod error
		nodeTried             = env.Node != "" && !env.NodeUDP
	)
	wg.Add(2)
	go func() { defer wg.Done(); allowed = env.anyAllowed(ctx) }()
	go func() { defer wg.Done(); foreign = env.handshake(ctx, env.Foreign, env.Foreign, true) }()
	if nodeTried {
		wg.Add(1)
		go func() { defer wg.Done(); nod = env.reach(ctx) }()
	}
	wg.Wait()

	detail := fmt.Sprintf("direct %s: %s; %s: %s", strings.Join(env.Allowed, ","), Stage(allowed), env.Foreign, Stage(foreign))
	if nodeTried {
		detail += fmt.Sprintf("; node tcp: %s", Stage(nod))
	}
	r := Report{Detail: detail}
	var cert *tls.CertificateVerificationError
	switch {
	case ctx.Err() != nil:
		r.Verdict = Unknown // cancelled: whatever failed, it says nothing
	case errors.As(foreign, &cert):
		r.Verdict = Intercepted
	case allowed != nil && foreign != nil:
		r.Verdict = NoInternet
	case foreign != nil:
		r.Verdict = Whitelist
	case nodeTried && nod != nil:
		r.Verdict = NodeBlocked
	default:
		r.Verdict = NodeDown
	}
	return r
}

func (env *Env) defaults() {
	if env.DNS == "" {
		env.DNS = "77.88.8.8:53"
	}
	if env.Lookup == nil {
		r := &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, _ string) (net.Conn, error) {
			return env.Dial(ctx, network, env.DNS)
		}}
		env.Lookup = r.LookupHost
	}
	if len(env.Allowed) == 0 {
		env.Allowed = AllowedDefault
	}
	if env.Foreign == "" {
		env.Foreign = "1.1.1.1"
	}
	if env.Port == "" {
		env.Port = "443"
	}
	if env.Step == 0 {
		env.Step = 5 * time.Second
	}
}

// anyAllowed is nil as soon as one allowed site completes a TLS handshake.
func (env *Env) anyAllowed(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	errs := make(chan error, len(env.Allowed))
	for _, host := range env.Allowed {
		go func() {
			ips, err := env.Lookup(ctx, host)
			if err == nil && len(ips) == 0 {
				err = errors.New("no address")
			}
			if err != nil {
				errs <- fmt.Errorf("dns: %w", err)
				return
			}
			errs <- env.handshake(ctx, ips[0], host, false)
		}()
	}
	var first error
	for range env.Allowed {
		err := <-errs
		if err == nil {
			return nil
		}
		if first == nil {
			first = err
		}
	}
	return first
}

// handshake connects to ip and completes TLS as name. Only the foreign side
// checks the certificate: a substituted one there is the finding.
func (env *Env) handshake(ctx context.Context, ip, name string, verify bool) error {
	ctx, cancel := context.WithTimeout(ctx, env.Step)
	defer cancel()
	raw, err := env.Dial(ctx, "tcp", net.JoinHostPort(ip, env.Port))
	if err != nil {
		return fmt.Errorf("tcp: %w", err)
	}
	defer raw.Close()
	c := tls.Client(raw, &tls.Config{
		ServerName:         name,
		RootCAs:            env.Roots,
		InsecureSkipVerify: !verify, // whether the site opens is all we ask of it
		NextProtos:         []string{"http/1.1"},
	})
	if err := c.HandshakeContext(ctx); err != nil {
		return fmt.Errorf("tls: %w", err)
	}
	return nil
}

func (env *Env) reach(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, env.Step)
	defer cancel()
	host, port, err := net.SplitHostPort(env.Node)
	if err != nil {
		return err
	}
	if net.ParseIP(host) == nil {
		ips, err := env.Lookup(ctx, host)
		if err != nil || len(ips) == 0 {
			return fmt.Errorf("dns: %v", err)
		}
		host = ips[0]
	}
	c, err := env.Dial(ctx, "tcp", net.JoinHostPort(host, port))
	if err != nil {
		return err
	}
	return c.Close()
}

// Stage says in a word or two where a step broke off: what bug reports need
// and a person does not.
func Stage(err error) string {
	if err == nil {
		return "ok"
	}
	where := ""
	if s := err.Error(); strings.HasPrefix(s, "tcp: ") || strings.HasPrefix(s, "tls: ") || strings.HasPrefix(s, "dns: ") {
		where = s[:3] + " "
	}
	var cert *tls.CertificateVerificationError
	var ne net.Error
	switch {
	case errors.As(err, &cert):
		return where + "bad certificate"
	case errors.Is(err, syscall.ECONNRESET):
		return where + "reset"
	case errors.Is(err, syscall.ECONNREFUSED):
		return where + "refused"
	case errors.Is(err, io.EOF), errors.Is(err, io.ErrUnexpectedEOF):
		return where + "closed"
	case errors.Is(err, context.DeadlineExceeded), errors.Is(err, os.ErrDeadlineExceeded),
		errors.As(err, &ne) && ne.Timeout():
		return where + "timeout"
	}
	return where + "failed"
}

//go:embed whitelist_sni.txt
var whitelistSNI string

// WhitelistSNI lists the server names whitelist networks are known to let
// through.
func WhitelistSNI() []string {
	var out []string
	sc := bufio.NewScanner(strings.NewReader(whitelistSNI))
	for sc.Scan() {
		if line := strings.TrimSpace(sc.Text()); line != "" && !strings.HasPrefix(line, "#") {
			out = append(out, line)
		}
	}
	return out
}
