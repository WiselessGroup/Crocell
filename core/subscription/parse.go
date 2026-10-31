package subscription

import (
	"bytes"
	"context"
	"fmt"
	"strings"

	"github.com/metacubex/mihomo/common/convert"
	"go.yaml.in/yaml/v3"
)

// maxProviderDepth stops a provider that points at itself.
const maxProviderDepth = 2

type parsed struct {
	format Format
	info   Info
	nodes  []Node
}

// Parse resolves a subscription body that is already downloaded. Clash
// proxy-providers are not followed, use Fetcher.Fetch for that.
func Parse(body []byte) (Format, Info, []Node, error) {
	p, err := (&Fetcher{}).parse(context.Background(), body, maxProviderDepth)
	if err != nil {
		return "", Info{}, nil, err
	}
	return p.format, p.info, p.nodes, nil
}

func (f *Fetcher) parse(ctx context.Context, body []byte, depth int) (*parsed, error) {
	body = bytes.TrimPrefix(bytes.TrimSpace(body), []byte("\xef\xbb\xbf"))
	if len(body) == 0 {
		return nil, fmt.Errorf("subscription: empty body")
	}

	if body[0] == '{' || body[0] == '[' {
		// sing-box and Xray JSON configs. Next on the list.
		return nil, fmt.Errorf("%w: JSON configs are not supported yet", ErrUnsupported)
	}

	if clash, ok := asClash(body); ok {
		return f.parseClash(ctx, clash, depth)
	}
	return parseLinks(body)
}

func parseLinks(body []byte) (*parsed, error) {
	decoded := convert.DecodeBase64(body)

	proxies, err := convert.ConvertsV2Ray(decoded)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupported, err)
	}

	return &parsed{
		format: FormatLinks,
		info:   infoFromComments(decoded),
		nodes:  toNodes(proxies),
	}, nil
}

type clashDoc struct {
	Proxies        []map[string]any          `yaml:"proxies"`
	ProxyProviders map[string]map[string]any `yaml:"proxy-providers"`
}

func asClash(body []byte) (*clashDoc, bool) {
	// A list of links is valid YAML too (one long string), so we only accept
	// documents that really have proxies or providers.
	var doc clashDoc
	if err := yaml.Unmarshal(body, &doc); err != nil {
		return nil, false
	}
	if len(doc.Proxies) == 0 && len(doc.ProxyProviders) == 0 {
		return nil, false
	}
	return &doc, true
}

func (f *Fetcher) parseClash(ctx context.Context, doc *clashDoc, depth int) (*parsed, error) {
	nodes := toNodes(doc.Proxies)

	for name, provider := range doc.ProxyProviders {
		if depth >= maxProviderDepth {
			break
		}
		url, _ := provider["url"].(string)
		if typ, _ := provider["type"].(string); typ != "http" || url == "" {
			// file and inline providers would need local files; skip.
			continue
		}

		body, _, err := f.get(ctx, url)
		if err != nil {
			return nil, fmt.Errorf("subscription: provider %q: %w", name, err)
		}
		sub, err := f.parse(ctx, body, depth+1)
		if err != nil {
			return nil, fmt.Errorf("subscription: provider %q: %w", name, err)
		}
		nodes = append(nodes, sub.nodes...)
	}

	return &parsed{format: FormatClash, nodes: uniqueNames(nodes)}, nil
}

func toNodes(proxies []map[string]any) []Node {
	nodes := make([]Node, 0, len(proxies))
	for _, p := range proxies {
		name, _ := p["name"].(string)
		typ, _ := p["type"].(string)
		server, _ := p["server"].(string)
		if name == "" || typ == "" {
			continue
		}
		nodes = append(nodes, Node{
			Name:   name,
			Type:   typ,
			Server: server,
			Port:   fmt.Sprint(p["port"]),
			Proxy:  p,
		})
	}
	return nodes
}

// uniqueNames renames duplicates the way mihomo's converter does, because a
// mihomo config refuses two proxies with one name. Providers often clash.
func uniqueNames(nodes []Node) []Node {
	seen := make(map[string]int, len(nodes))
	for i := range nodes {
		name := nodes[i].Name
		if n := seen[name]; n > 0 {
			name = fmt.Sprintf("%s-%02d", name, n)
			nodes[i].Name = name
			nodes[i].Proxy["name"] = name
		}
		seen[nodes[i].Name]++
	}
	return nodes
}

// infoFromComments reads "#key: value" lines that some panels (Remnawave,
// Marzban forks) put at the top of a link list.
func infoFromComments(body []byte) Info {
	h := make(map[string]string)
	for _, line := range strings.Split(string(body), "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "#") {
			if line != "" {
				break // comments only live in the header
			}
			continue
		}
		key, value, ok := strings.Cut(strings.TrimPrefix(line, "#"), ":")
		if !ok {
			continue
		}
		h[strings.ToLower(strings.TrimSpace(key))] = strings.TrimSpace(value)
	}
	return infoFromMap(h)
}
