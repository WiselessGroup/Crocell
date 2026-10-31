// Package engine runs mihomo with a config built from subscription nodes.
//
// mihomo keeps its state in package-level globals, so there is exactly one
// engine per process. That is fine: on desktop it lives in crocelld, on
// mobile in the VPN service process.
package engine

import (
	"errors"
	"fmt"
	"os"
	"sync"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"

	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

// GroupName is the selector that every node sits in. Switching nodes means
// switching this selector, without restarting listeners.
const GroupName = "Crocell"

// Options describe what to run.
type Options struct {
	// HomeDir is where mihomo keeps cache.db and anything it downloads.
	HomeDir   string
	MixedPort int    // HTTP+SOCKS on 127.0.0.1, 0 disables
	LogLevel  string // silent, error, warning, info, debug
	Nodes     []subscription.Node
	Selected  string // node name, first node when empty
}

var (
	mu      sync.Mutex
	running bool
)

// Start applies the config. Calling it again replaces the running config.
func Start(opts Options) error {
	if len(opts.Nodes) == 0 {
		return errors.New("engine: no nodes")
	}
	if opts.HomeDir == "" {
		return errors.New("engine: no home dir")
	}
	if err := os.MkdirAll(opts.HomeDir, 0o700); err != nil {
		return fmt.Errorf("engine: %w", err)
	}

	cfg, err := buildConfig(opts)
	if err != nil {
		return err
	}

	mu.Lock()
	defer mu.Unlock()

	C.SetHomeDir(opts.HomeDir)
	if err := hub.Parse(cfg); err != nil {
		return fmt.Errorf("engine: %w", err)
	}
	running = true

	if opts.Selected != "" {
		return selectLocked(opts.Selected)
	}
	return nil
}

// Select switches the active node.
func Select(name string) error {
	mu.Lock()
	defer mu.Unlock()
	return selectLocked(name)
}

func selectLocked(name string) error {
	if !running {
		return errors.New("engine: not running")
	}
	group, ok := tunnel.Proxies()[GroupName]
	if !ok {
		return errors.New("engine: selector missing")
	}
	sel, ok := group.Adapter().(*outboundgroup.Selector)
	if !ok {
		return errors.New("engine: selector has unexpected type")
	}
	if err := sel.Set(name); err != nil {
		return fmt.Errorf("engine: select %q: %w", name, err)
	}
	return nil
}

// Selected returns the active node name.
func Selected() string {
	mu.Lock()
	defer mu.Unlock()
	if !running {
		return ""
	}
	if group, ok := tunnel.Proxies()[GroupName]; ok {
		if sel, ok := group.Adapter().(*outboundgroup.Selector); ok {
			return sel.Now()
		}
	}
	return ""
}

// Stop shuts listeners and connections down.
func Stop() {
	mu.Lock()
	defer mu.Unlock()
	if running {
		executor.Shutdown()
		running = false
	}
}

func buildConfig(opts Options) ([]byte, error) {
	proxies := make([]map[string]any, 0, len(opts.Nodes))
	names := make([]string, 0, len(opts.Nodes))
	for _, n := range opts.Nodes {
		proxies = append(proxies, n.Proxy)
		names = append(names, n.Name)
	}

	logLevel := opts.LogLevel
	if logLevel == "" {
		logLevel = "warning"
	}

	cfg := map[string]any{
		"mode":         "rule",
		"log-level":    logLevel,
		"allow-lan":    false,
		"bind-address": "127.0.0.1",
		"ipv6":         true,
		// Without a fingerprint mihomo speaks Go's crypto/tls ClientHello,
		// which DPI tells apart from a browser. Nodes may override it.
		"global-client-fingerprint": "chrome",
		"profile": map[string]any{
			"store-selected": false,
		},
		"proxies": proxies,
		"proxy-groups": []map[string]any{{
			"name":    GroupName,
			"type":    "select",
			"proxies": names,
		}},
		"rules": []string{"MATCH," + GroupName},
	}
	if opts.MixedPort > 0 {
		cfg["mixed-port"] = opts.MixedPort
	}

	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, fmt.Errorf("engine: marshal config: %w", err)
	}
	return out, nil
}
