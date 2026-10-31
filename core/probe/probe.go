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
	"strings"
	"time"

	"github.com/metacubex/mihomo/adapter"
	C "github.com/metacubex/mihomo/constant"
)

// traceURL returns ip=, loc= (country) and colo= (Cloudflare PoP, an IATA
// airport code) in one plain-text response, no third-party GeoIP needed.
const traceURL = "https://www.cloudflare.com/cdn-cgi/trace"

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
		Timeout: 15 * time.Second,
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, traceURL, nil)
	if err != nil {
		res.Err = err
		return res
	}

	start := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		res.Err = fmt.Errorf("probe: %w", err)
		return res
	}
	defer resp.Body.Close()
	res.Latency = time.Since(start)

	if resp.StatusCode != http.StatusOK {
		res.Err = fmt.Errorf("probe: trace returned HTTP %d", resp.StatusCode)
		return res
	}

	trace := parseTrace(io.LimitReader(resp.Body, 4096))
	res.ExitIP = trace["ip"]
	res.ExitCountry = trace["loc"]
	res.ExitColo = trace["colo"]
	return res
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
