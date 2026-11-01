package procs

import (
	"os"
	"path/filepath"
	"strings"
)

// Linux: /proc/<pid>/exe. Kernel threads have no exe and are skipped, and
// so are a few things nobody routes: our own service and shells' helpers.
func list() ([]Process, error) {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil, err
	}
	var out []Process
	for _, e := range entries {
		if !e.IsDir() || strings.Trim(e.Name(), "0123456789") != "" {
			continue
		}
		exe, err := os.Readlink(filepath.Join("/proc", e.Name(), "exe"))
		if err != nil || exe == "" {
			continue
		}
		exe = strings.TrimSuffix(exe, " (deleted)")
		out = append(out, Process{Name: filepath.Base(exe), Path: exe})
	}
	return out, nil
}
