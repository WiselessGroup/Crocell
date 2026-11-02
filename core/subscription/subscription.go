// Package subscription turns a subscription link into a list of nodes.
//
// A node is a mihomo proxy mapping, because mihomo is the engine that will
// run it. Share links are converted by mihomo's own converter, Clash/Mihomo
// YAML is taken as is, proxy-providers are downloaded and resolved.
package subscription

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Format is what the subscription body turned out to be.
type Format string

const (
	FormatLinks Format = "links" // share links, plain or base64
	FormatClash Format = "clash" // Clash / Mihomo YAML
	// FormatConfig is a WireGuard or AmneziaWG config, pasted or downloaded.
	FormatConfig Format = "config"
)

// Node is one proxy from a subscription.
type Node struct {
	Name   string
	Type   string // vless, hysteria2, trojan, ...
	Server string
	Port   string
	// Proxy is the mihomo proxy mapping, ready for adapter.ParseProxy or a
	// `proxies:` list in a mihomo config.
	Proxy map[string]any
}

// Info is subscription metadata. Every field is optional: providers send
// whatever they like, in headers or in comment lines of the body.
type Info struct {
	Title          string
	Upload         int64
	Download       int64
	Total          int64     // bytes, 0 means unlimited
	Expire         time.Time // zero means never
	UpdateInterval time.Duration
	WebPage        string
	Support        string
	Announce       string
}

// Subscription is a fetched and parsed subscription.
type Subscription struct {
	URL       string
	Format    Format
	Info      Info
	Nodes     []Node
	FetchedAt time.Time
}

// ErrUnsupported means the body was read fine, but its format is not one we
// understand yet.
var ErrUnsupported = errors.New("subscription: unsupported format")

// maxBody caps a single download. Real subscriptions are a few KB.
const maxBody = 8 << 20

// DefaultUserAgent is what we send unless told otherwise. Many panels decide
// the body format by User-Agent: "clash" and "mihomo" get YAML.
const DefaultUserAgent = "Crocell/0.1 (mihomo; clash.meta)"

// Fetcher downloads and resolves subscriptions.
type Fetcher struct {
	Client    *http.Client
	UserAgent string
}

func (f *Fetcher) client() *http.Client {
	if f.Client != nil {
		return f.Client
	}
	return &http.Client{Timeout: 30 * time.Second}
}

func (f *Fetcher) userAgent() string {
	if f.UserAgent != "" {
		return f.UserAgent
	}
	return DefaultUserAgent
}

// IsLink tells a subscription link from text pasted as is: a share link, a
// WireGuard config, a vpn:// key.
func IsLink(input string) bool {
	return strings.HasPrefix(input, "https://") || strings.HasPrefix(input, "http://")
}

// Fetch downloads a subscription and resolves it into nodes. Anything that is
// not an http(s) link is taken as the subscription's body itself.
func (f *Fetcher) Fetch(ctx context.Context, url string) (*Subscription, error) {
	url = strings.TrimSpace(url)
	if !IsLink(url) {
		return f.fromText(ctx, url)
	}
	body, header, err := f.get(ctx, url)
	if err != nil {
		return nil, err
	}

	parsed, err := f.parse(ctx, body, 0)
	if err != nil {
		return nil, err
	}

	info := parsed.info
	mergeInfo(&info, infoFromHeader(header))

	return &Subscription{
		URL:       url,
		Format:    parsed.format,
		Info:      info,
		Nodes:     parsed.nodes,
		FetchedAt: time.Now(),
	}, nil
}

func (f *Fetcher) fromText(ctx context.Context, text string) (*Subscription, error) {
	parsed, err := f.parse(ctx, []byte(text), 0)
	if err != nil {
		return nil, err
	}
	info := parsed.info
	// Nothing else names it: no provider, no headers.
	if info.Title == "" && len(parsed.nodes) > 0 {
		info.Title = parsed.nodes[0].Name
	}
	return &Subscription{URL: text, Format: parsed.format, Info: info, Nodes: parsed.nodes, FetchedAt: time.Now()}, nil
}

func (f *Fetcher) get(ctx context.Context, url string) ([]byte, http.Header, error) {
	if !strings.HasPrefix(url, "https://") && !strings.HasPrefix(url, "http://") {
		return nil, nil, fmt.Errorf("subscription: not an http(s) link")
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("subscription: %w", err)
	}
	req.Header.Set("User-Agent", f.userAgent())

	resp, err := f.client().Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("subscription: fetch: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, nil, fmt.Errorf("subscription: fetch: HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBody+1))
	if err != nil {
		return nil, nil, fmt.Errorf("subscription: read: %w", err)
	}
	if len(body) > maxBody {
		return nil, nil, fmt.Errorf("subscription: body larger than %d bytes", maxBody)
	}
	return body, resp.Header, nil
}
