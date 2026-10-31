//go:build linux || darwin

package main

import (
	"os"
	"runtime"
	"strconv"
	"strings"
)

// privileged reports whether we may create a TUN device: root, or on Linux
// a binary with CAP_NET_ADMIN in its effective set.
func privileged() bool {
	if os.Geteuid() == 0 {
		return true
	}
	if runtime.GOOS != "linux" {
		return false
	}
	status, err := os.ReadFile("/proc/self/status")
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(status), "\n") {
		if hex, ok := strings.CutPrefix(line, "CapEff:"); ok {
			caps, err := strconv.ParseUint(strings.TrimSpace(hex), 16, 64)
			const capNetAdmin = 12
			return err == nil && caps&(1<<capNetAdmin) != 0
		}
	}
	return false
}
