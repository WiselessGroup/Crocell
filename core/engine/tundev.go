package engine

import (
	"net"
	"runtime"
)

// TunDevice is the TUN interface name on Linux and Windows. A fixed name
// lets us check that the tunnel really exists and lets people find it in
// `ip link`. macOS only allows utunN, so there mihomo picks.
const TunDevice = "crocell"

var tunDevice = func() string {
	if runtime.GOOS == "darwin" {
		return ""
	}
	return TunDevice
}()

// tunInterfaceUp reports whether the TUN interface exists. On macOS (and
// Android, where the fd comes from VpnService) the name is not ours to
// check, so it trusts mihomo.
func tunInterfaceUp() bool {
	if tunDevice == "" || runtime.GOOS == "android" {
		return true
	}
	_, err := net.InterfaceByName(tunDevice)
	return err == nil
}
