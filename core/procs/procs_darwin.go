package procs

import (
	"os/exec"
	"path/filepath"
	"strings"
)

// macOS: ps prints each process's executable path with comm=.
func list() ([]Process, error) {
	out, err := exec.Command("ps", "-axo", "comm=").Output()
	if err != nil {
		return nil, err
	}
	var procs []Process
	for _, line := range strings.Split(string(out), "\n") {
		path := strings.TrimSpace(line)
		if path == "" {
			continue
		}
		p := Process{Name: filepath.Base(path)}
		if strings.HasPrefix(path, "/") {
			p.Path = path
		}
		procs = append(procs, p)
	}
	return procs, nil
}
