// Package probe answers "what does this node look like from the outside":
// where it enters, where it exits, and how long a real request takes.
//
// Probes dial through a single mihomo proxy adapter, so they work without the
// tunnel running and without touching system routes.
package probe

import (
	"bufio"
	"context"
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
const Timeout = 10 * time.Second

// Result is what one probe found. Exit fields are empty when Err is set.
type Result struct {
	EntryIPs []string // where the node's server name resolves locally

	ExitIP      string
	ExitCountry string // ISO 3166-1 alpha-2, as Cloudflare sees it
	ExitColo    string // nearest Cloudflare PoP to the exit, e.g. FRA
	Latency     time.Duration

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
func Proxy(ctx context.Context, p C.ProxyAdapter, server string) Result {
	// One budget for the whole probe, both trace URLs included: a dead node
	// must not hold a subscription of 150 nodes hostage for minutes.
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()

	var res Result
	res.EntryIPs = resolveEntry(ctx, server)

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
	return res
}

// System checks the path the whole machine uses: with TUN up, a plain
// request from this process goes through the tunnel like anyone else's.
func System(ctx context.Context) Result {
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()
	var res Result
	trace(ctx, &http.Client{Transport: &http.Transport{Proxy: nil, DisableKeepAlives: true}}, &res)
	return res
}

// ViaProxy checks the path proxy-mode apps use: the local mixed port.
func ViaProxy(ctx context.Context, port int) Result {
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()
	var res Result
	proxy := &url.URL{Scheme: "http", Host: net.JoinHostPort("127.0.0.1", strconv.Itoa(port))}
	trace(ctx, &http.Client{Transport: &http.Transport{Proxy: http.ProxyURL(proxy), DisableKeepAlives: true}}, &res)
	return res
}

// trace asks Cloudflare who we are, IPv4 first, and fills res.
func trace(ctx context.Context, client *http.Client, res *Result) {
	var resp *http.Response
	var err error
	var start time.Time
	for _, u := range traceURLs {
		var req *http.Request
		req, err = http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
		if err != nil {
			break
		}
		start = time.Now()
		resp, err = client.Do(req)
		if err == nil || ctx.Err() != nil {
			break // success, or the budget is spent: no point in the fallback
		}
	}
	if err != nil {
		res.Err = fmt.Errorf("probe: %w", err)
		return
	}
	defer resp.Body.Close()
	res.Latency = time.Since(start)

	if resp.StatusCode != http.StatusOK {
		res.Err = fmt.Errorf("probe: trace returned HTTP %d", resp.StatusCode)
		return
	}

	t := parseTrace(io.LimitReader(resp.Body, 4096))
	res.ExitIP = t["ip"]
	res.ExitCountry = t["loc"]
	res.ExitColo = t["colo"]
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
