package daemon

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

// state is everything the daemon remembers between restarts. It holds
// subscription links and node credentials: encrypted on disk (crypt.go),
// 0600, in a root-only directory.
type state struct {
	Subscriptions []*storedSub `json:"subscriptions"`
	Settings      settings     `json:"settings"`
	Last          selection    `json:"last"`
}

type storedSub struct {
	ID        string              `json:"id"`
	URL       string              `json:"url"`
	Format    subscription.Format `json:"format"`
	Info      subscription.Info   `json:"info"`
	Nodes     []storedNode        `json:"nodes"`
	FetchedAt time.Time           `json:"fetched_at"`
}

type storedNode struct {
	ID    string         `json:"id"`
	Name  string         `json:"name"`
	Proxy map[string]any `json:"proxy"`
}

type settings struct {
	TunnelMode     string      `json:"tunnel_mode"` // "proxy" or "tun"
	MixedPort      int         `json:"mixed_port"`
	TunStack       string      `json:"tun_stack"`
	Rules          []rule      `json:"rules"`
	Final          string      `json:"final"` // "proxy" (default) or "direct"
	DNS            dnsSettings `json:"dns"`
	Geo            geoSettings `json:"geo"`
	DisableIPv6    bool        `json:"disable_ipv6"`
	AllowLAN       bool        `json:"allow_lan"`
	ConnectOnStart bool        `json:"connect_on_start"`

	// Before 0.2 there were only per-program rules. Read once, migrated
	// into Rules, never written again.
	LegacyAppRules []appRule `json:"app_rules,omitempty"`
}

type rule struct {
	Kind   string `json:"kind"` // process_path, process_name, domain, domain_wildcard, domain_suffix, ip_cidr, geosite, geoip
	Value  string `json:"value"`
	Action string `json:"action"` // proxy, direct, block
}

type dnsSettings struct {
	Servers       []string `json:"servers,omitempty"`
	DirectServers []string `json:"direct_servers,omitempty"`
	RealIP        bool     `json:"real_ip"`
}

type geoSettings struct {
	GeoIPSource   string `json:"geoip_source,omitempty"`
	GeoSiteSource string `json:"geosite_source,omitempty"`
	UpdateHours   int    `json:"update_hours,omitempty"`
}

type appRule struct {
	App  string `json:"app"`
	Mode string `json:"mode"` // proxy, bypass, block
}

// migrate folds the old per-program rules into the general list.
func (s *settings) migrate() {
	for _, r := range s.LegacyAppRules {
		kind := "process_name"
		if strings.ContainsAny(r.App, `/\`) {
			kind = "process_path"
		}
		action := map[string]string{"proxy": "proxy", "bypass": "direct", "block": "block"}[r.Mode]
		if action != "" {
			s.Rules = append(s.Rules, rule{Kind: kind, Value: r.App, Action: action})
		}
	}
	s.LegacyAppRules = nil
}

type selection struct {
	SubscriptionID string `json:"subscription_id"`
	NodeID         string `json:"node_id"`
}

const defaultMixedPort = 7890

func defaultState() *state {
	return &state{Settings: settings{TunnelMode: "proxy", MixedPort: defaultMixedPort}}
}

type store struct {
	dir    string
	sealer *sealer
}

func (s *store) encPath() string    { return filepath.Join(s.dir, "state.enc") }
func (s *store) legacyPath() string { return filepath.Join(s.dir, "state.json") } // before encryption

func (s *store) load() (*state, error) {
	st := defaultState()
	b, err := os.ReadFile(s.encPath())
	switch {
	case err == nil:
		plain, err := s.sealer.open(b)
		if err != nil {
			return nil, err
		}
		b = plain
	case errors.Is(err, fs.ErrNotExist):
		// Older versions kept plain JSON; the next save encrypts it.
		b, err = os.ReadFile(s.legacyPath())
		if errors.Is(err, fs.ErrNotExist) {
			return st, nil
		}
		if err != nil {
			return nil, fmt.Errorf("daemon: read state: %w", err)
		}
	default:
		return nil, fmt.Errorf("daemon: read state: %w", err)
	}
	if err := json.Unmarshal(b, st); err != nil {
		return nil, fmt.Errorf("daemon: parse state: %w", err)
	}
	st.Settings.migrate()
	return st, nil
}

// save writes atomically: a crash mid-write must not lose subscriptions.
func (s *store) save(st *state) error {
	b, err := json.Marshal(st)
	if err != nil {
		return fmt.Errorf("daemon: encode state: %w", err)
	}
	sealed, err := s.sealer.seal(b)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(s.dir, 0o700); err != nil {
		return fmt.Errorf("daemon: %w", err)
	}
	tmp := s.encPath() + ".tmp"
	if err := os.WriteFile(tmp, sealed, 0o600); err != nil {
		return fmt.Errorf("daemon: write state: %w", err)
	}
	if err := os.Rename(tmp, s.encPath()); err != nil {
		return fmt.Errorf("daemon: write state: %w", err)
	}
	// The plain-text file from before encryption goes once we have a
	// sealed copy.
	if err := os.Remove(s.legacyPath()); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("daemon: remove plain state: %w", err)
	}
	return nil
}

func subscriptionID(url string) string {
	sum := sha256.Sum256([]byte(url))
	return hex.EncodeToString(sum[:6])
}

// nodeID survives renames and reordering in the subscription: it hashes what
// makes a node that node, not its display name.
func nodeID(proxy map[string]any) string {
	h := sha256.New()
	for _, key := range []string{"type", "server", "port", "uuid", "password", "network"} {
		fmt.Fprintf(h, "%s=%v;", key, proxy[key])
	}
	return hex.EncodeToString(h.Sum(nil)[:6])
}

func toStored(url string, sub *subscription.Subscription) *storedSub {
	s := &storedSub{
		ID:        subscriptionID(url),
		URL:       url,
		Format:    sub.Format,
		Info:      sub.Info,
		FetchedAt: sub.FetchedAt,
	}
	seen := map[string]int{}
	for _, n := range sub.Nodes {
		id := nodeID(n.Proxy)
		// Two identical nodes under different names: keep both, distinct ids.
		if k := seen[id]; k > 0 {
			id = fmt.Sprintf("%s-%d", id, k)
		}
		seen[nodeID(n.Proxy)]++
		s.Nodes = append(s.Nodes, storedNode{ID: id, Name: n.Name, Proxy: n.Proxy})
	}
	return s
}

func (s *storedSub) node(id string) (storedNode, bool) {
	for _, n := range s.Nodes {
		if n.ID == id {
			return n, true
		}
	}
	return storedNode{}, false
}

func (s *storedSub) engineNodes() []subscription.Node {
	nodes := make([]subscription.Node, 0, len(s.Nodes))
	for _, n := range s.Nodes {
		typ, _ := n.Proxy["type"].(string)
		server, _ := n.Proxy["server"].(string)
		nodes = append(nodes, subscription.Node{
			Name: n.Name, Type: typ, Server: server, Port: fmt.Sprint(n.Proxy["port"]), Proxy: n.Proxy,
		})
	}
	return nodes
}
