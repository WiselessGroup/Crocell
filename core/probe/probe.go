// Package probe answers "what does this node look like from the outside":
// where it enters, where it exits, and how long a real request takes.
//
// Probes dial through a single mihomo proxy adapter, so they work without the
// tunnel running and without touching system routes.
package probe

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/metacubex/mihomo/adapter"
	C "github.com/metacubex/mihomo/constant"
)

// Cloudflare trace returns ip=, loc= (country) and colo= (Cloudflare PoP, an
// IATA airport code) in one plain-text response, no third-party GeoIP needed.
//
// The IPv4 literal goes first: people know their exit by its IPv4 address, and
// a dual-stack exit would otherwise answer from IPv6. The hostname is the
// fallback for IPv6-only exits.
var traceURLs = []string{
	"https://1.1.1.1/cdn-cgi/trace",
	"https://www.cloudflare.com/cdn-cgi/trace",
}

// Timeout caps one node's probe, entry lookup and both attempts together.
// The bulk download after it has its own BulkTimeout.
const Timeout = 10 * time.Second

// bulkURL serves exactly the asked number of bytes from Cloudflare.
//
// Russian providers let the handshake with foreign hosting through and then
// cut the connection somewhere around 16-20 KB. The trace answer is under
// 1 KB, so a node cut like that passes it and still fails on the first
// picture. 64 KB is well past the cut and still cheap on mobile data.
// The idea and the threshold come from dpi-detector (its TCP 16-20 test).
var bulkURL = "https://speed.cloudflare.com/__down?bytes=65536"

const bulkSize = 65536

// BulkTimeout caps the bulk download. A cut connection usually hangs
// rather than resets, so this is mostly how long a cut takes to show.
var BulkTimeout = 6 * time.Second

// ErrCut means small requests through the node work and a bigger answer
// breaks off: the provider is cutting connections to this node.
var ErrCut = errors.New("the connection breaks off after the first kilobytes, the provider is likely cutting it")

// attemptTimeout caps one trace URL. An exit that silently drops 1.1.1.1
// would otherwise spend the whole budget on it, and a node that works
// would show as down without the hostname ever being tried.
var attemptTimeout = Timeout / 2

// Result is what one probe found. Exit fields are empty when Err is set.
type Result struct {
	EntryIPs []string // where the node's server name resolves locally

	ExitIP      string
	ExitCountry string // ISO 3166-1 alpha-2, as Cloudflare sees it
	ExitColo    string // nearest Cloudflare PoP to the exit, e.g. FRA
	Latency     time.Duration

	// Cut is set with Err = ErrCut: the node answers, but anything bigger
	// than a few kilobytes does not get through.
	Cut bool

	Err error
}

// Node parses a mihomo proxy mapping and probes it.
func Node(ctx context.Context, proxy map[string]any) Result {
	p, err := adapter.ParseProxy(proxy)
	if err != nil {
		return Result{Err: fmt.Errorf("probe: parse: %w", err)}
	}
	server, _ := proxy["server"].(string)
	return Proxy(ctx, p, server)
}

// Proxy probes an already parsed adapter. server is the node's address, used
// only for the entry side.
func Proxy(parent context.Context, p C.ProxyAdapter, server string) Result {
	// One budget for the whole probe, both trace URLs included: a dead node
	// must not hold a subscription of 150 nodes hostage for minutes.
	ctx, cancel := context.WithTimeout(parent, Timeout)
	defer cancel()

	// The entry lookup goes alongside the trace, not before it: a slow DNS
	// answer for the node's name must not eat the time the trace needs.
	entry := make(chan []string, 1)
	go func() { entry <- resolveEntry(ctx, server) }()

	var res Result
	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				md := &C.Metadata{NetWork: C.TCP}
				if err := md.SetRemoteAddress(addr); err != nil {
					return nil, err
				}
				return p.DialContext(ctx, md)
			},
			// One connection per probe: we measure the node, not a warm pool.
			DisableKeepAlives: true,
		},
	}
	trace(ctx, client, &res)
	res.EntryIPs = <-entry
	if res.Err == nil {
		bulk(parent, client, &res)
	}
	return res
}

// System checks the path the whole machine uses: with TUN up, a plain
// request from this process goes through the tunnel like anyone else's.
// full adds the bulk download.
func System(ctx context.Context, full bool) Result {
	return live(ctx, &http.Client{Transport: &http.Transport{Proxy: nil, DisableKeepAlives: true}}, full)
}

// ViaProxy checks the path proxy-mode apps use: the local mixed port.
func ViaProxy(ctx context.Context, port int, full bool) Result {
	proxy := &url.URL{Scheme: "http", Host: net.JoinHostPort("127.0.0.1", strconv.Itoa(port))}
	return live(ctx, &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxy), DisableKeepAlives: true}}, full)
}

func live(parent context.Context, client *http.Client, full bool) Result {
	ctx, cancel := context.WithTimeout(parent, Timeout)
	defer cancel()
	var res Result
	trace(ctx, client, &res)
	if full && res.Err == nil {
		bulk(parent, client, &res)
	}
	return res
}

// bulk downloads bulkSize bytes and marks res as cut when they do not all
// arrive. Called only after a trace went through, so the node itself works.
func bulk(parent context.Context, client *http.Client, res *Result) {
	if parent.Err() != nil {
		return
	}
	ctx, cancel := context.WithTimeout(parent, BulkTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, bulkURL, nil)
	if err != nil {
		return
	}
	resp, err := client.Do(req)
	if err == nil {
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			// Cloudflare limiting us is not the provider cutting the node.
			return
		}
		var n int64
		n, err = io.Copy(io.Discard, io.LimitReader(resp.Body, bulkSize+1))
		if err == nil && n >= bulkSize {
			return
		}
	}
	if parent.Err() != nil {
		return // the caller gave up, the node did nothing wrong
	}
	res.Cut = true
	res.Err = fmt.Errorf("probe: %w", ErrCut)
}

// trace asks Cloudflare who we are, IPv4 first, and fills res. Each URL
// gets its own share of the budget, so the fallback still has time when
// the first one hangs.
func trace(ctx context.Context, client *http.Client, res *Result) {
	var err error
	for _, u := range traceURLs {
		if err = traceOnce(ctx, client, u, res); err == nil || ctx.Err() != nil {
			break // success, or the budget is spent: no point in the fallback
		}
	}
	if err != nil {
		res.Err = fmt.Errorf("probe: %w", err)
	}
}

func traceOnce(ctx context.Context, client *http.Client, u string, res *Result) error {
	ctx, cancel := context.WithTimeout(ctx, attemptTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	start := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	latency := time.Since(start)

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("trace returned HTTP %d", resp.StatusCode)
	}
	t := parseTrace(io.LimitReader(resp.Body, 4096))
	if t["ip"] == "" {
		// A captive or block page answers 200 too; it is not the node.
		return errors.New("trace answer has no ip")
	}
	res.Latency = latency
	res.ExitIP = t["ip"]
	res.ExitCountry = t["loc"]
	res.ExitColo = t["colo"]
	return nil
}

func resolveEntry(ctx context.Context, server string) []string {
	if server == "" {
		return nil
	}
	if ip := net.ParseIP(server); ip != nil {
		return []string{ip.String()}
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	ips, err := net.DefaultResolver.LookupHost(ctx, server)
	if err != nil {
		return nil
	}
	return ips
}

func parseTrace(r io.Reader) map[string]string {
	out := make(map[string]string)
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		if key, value, ok := strings.Cut(sc.Text(), "="); ok {
			out[key] = value
		}
	}
	return out
}
