// Package sysproxy points the OS proxy settings at our local mixed port and
// puts the previous settings back afterwards.
//
// It changes per-user settings, so it must run as the user whose desktop it
// is, not as root. Only apps that honour system proxy settings follow it;
// for the rest there is TUN.
package sysproxy

import (
	"errors"
	"os/exec"
	"strings"
)

// ErrUnsupported means this desktop has no proxy settings we know how to set.
var ErrUnsupported = errors.New("sysproxy: unsupported desktop")

// Restore puts back what was there before Set.
type Restore func() error

// Set points the system proxy at host:port for HTTP, HTTPS and SOCKS.
func Set(host string, port int) (Restore, error) {
	return set(host, port)
}

// run is swapped out in tests.
var run = func(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return strings.TrimSpace(string(out)), err
}

var lookPath = exec.LookPath
