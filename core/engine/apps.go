package engine

import (
	"fmt"
	"strings"

	"github.com/metacubex/mihomo/tunnel/statistic"
)

// AppMode is what happens to one application's traffic while connected.
type AppMode int

const (
	AppProxy  AppMode = iota // through the selected node
	AppBypass                // straight out, never through the node
	AppBlock                 // no network at all
)

// AppRule binds an application to a mode. App is an Android package name,
// a desktop executable name ("telegram-desktop", "Steam.exe") or a full path.
type AppRule struct {
	App  string
	Mode AppMode
}

// appRules turns per-app rules into mihomo rules, placed before the final
// MATCH. A path becomes PROCESS-PATH, anything else PROCESS-NAME (on Android
// mihomo matches the package name there).
func appRules(rules []AppRule) ([]string, error) {
	out := make([]string, 0, len(rules))
	for _, r := range rules {
		app := strings.TrimSpace(r.App)
		if app == "" {
			continue
		}
		// A comma would split the rule, a newline would start a new one.
		if strings.ContainsAny(app, ",\n\r") {
			return nil, fmt.Errorf("engine: app %q: commas and newlines are not allowed", app)
		}

		kind := "PROCESS-NAME"
		if strings.ContainsAny(app, `/\`) {
			kind = "PROCESS-PATH"
		}

		var target string
		switch r.Mode {
		case AppProxy:
			target = GroupName
		case AppBypass:
			target = "DIRECT"
		case AppBlock:
			target = "REJECT"
		default:
			return nil, fmt.Errorf("engine: app %q: unknown mode %d", app, r.Mode)
		}
		out = append(out, kind+","+app+","+target)
	}
	return out, nil
}

// bypassPackages are Android packages that should not enter the tunnel at
// all, which is stronger than a DIRECT rule inside it.
func bypassPackages(rules []AppRule) []string {
	var out []string
	for _, r := range rules {
		if r.Mode == AppBypass && !strings.ContainsAny(r.App, `/\`) {
			out = append(out, r.App)
		}
	}
	return out
}

// Traffic is a snapshot of byte counters since the engine started.
type Traffic struct {
	Up, Down         int64 // total bytes
	UpRate, DownRate int64 // bytes per second, last second
}

// CurrentTraffic reads mihomo's counters.
func CurrentTraffic() Traffic {
	up, down := statistic.DefaultManager.Total()
	upRate, downRate := statistic.DefaultManager.Now()
	return Traffic{Up: up, Down: down, UpRate: upRate, DownRate: downRate}
}
