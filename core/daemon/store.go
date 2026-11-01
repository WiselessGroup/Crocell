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
	"time"

	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

// state is everything the daemon remembers between restarts. It holds
// subscription links, which are secrets, so the file is 0600 and lives in a
// root-only directory.
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
	TunnelMode string    `json:"tunnel_mode"` // "proxy" or "tun"
	MixedPort  int       `json:"mixed_port"`
	TunStack   string    `json:"tun_stack"`
	AppRules   []appRule `json:"app_rules"`
}

type appRule struct {
	App  string `json:"app"`
	Mode string `json:"mode"` // proxy, bypass, block
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
	path string
}

func (s *store) load() (*state, error) {
	b, err := os.ReadFile(s.path)
	if errors.Is(err, fs.ErrNotExist) {
		return defaultState(), nil
	}
	if err != nil {
		return nil, fmt.Errorf("daemon: read state: %w", err)
	}
	st := defaultState()
	if err := json.Unmarshal(b, st); err != nil {
		return nil, fmt.Errorf("daemon: parse state: %w", err)
	}
	return st, nil
}

// save writes atomically: a crash mid-write must not lose subscriptions.
func (s *store) save(st *state) error {
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return fmt.Errorf("daemon: encode state: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return fmt.Errorf("daemon: %w", err)
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return fmt.Errorf("daemon: write state: %w", err)
	}
	if err := os.Rename(tmp, s.path); err != nil {
		return fmt.Errorf("daemon: write state: %w", err)
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
