// Package procs lists running programs so a routing rule can be made from
// one with a click. The daemon runs privileged and sees every process.
package procs

import (
	"path/filepath"
	"slices"
	"strings"
)

// Process is one running program, deduplicated by path.
type Process struct {
	Name string // what PROCESS-NAME matches: the executable's file name
	Path string // full path, empty if unknown
	// Label is the name people know an Android app by. Empty elsewhere.
	Label string
}

// List returns running programs, one entry per executable, sorted by name.
func List() ([]Process, error) {
	raw, err := list()
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	out := make([]Process, 0, len(raw))
	for _, p := range raw {
		if p.Name == "" && p.Path != "" {
			p.Name = filepath.Base(p.Path)
		}
		key := p.Path
		if key == "" {
			key = "name:" + p.Name
		}
		if p.Name == "" || seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, p)
	}
	slices.SortFunc(out, func(a, b Process) int {
		return strings.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name))
	})
	return out, nil
}
