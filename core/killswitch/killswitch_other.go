//go:build !windows && !(linux && !android)

package killswitch

import "syscall"

// Mark means nothing here: there is no firewall to pass.
const Mark = 0

// New: Android blocks through the system's own always-on VPN setting, macOS
// waits for a decision, see ADR-0002.
func New() Firewall { return None{} }

var control func(network, address string, raw syscall.RawConn) error
