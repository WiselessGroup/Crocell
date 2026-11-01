package engine

import (
	"net"
	"net/netip"
	"os"
	"testing"

	"github.com/metacubex/mihomo/component/process"
	"golang.org/x/sys/unix"
)

// Guards the fix in third_party/mihomo/component/process/process_linux.go.
// Upstream fails both halves, and a rule for one program then catches
// another program's traffic.
func TestProgramLookup(t *testing.T) {
	l, err := net.Listen("tcp", "[::]:0")
	if err != nil {
		t.Skip("no dual-stack listener here:", err)
	}
	defer l.Close()
	port := l.Addr().(*net.TCPAddr).Port
	self, _ := os.Executable()
	localhost := netip.MustParseAddr("127.0.0.1")

	plain, err := net.Dial("tcp4", l.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer plain.Close()
	mapped := dialMapped(t, port)
	defer unix.Close(mapped.fd)

	for name, srcPort := range map[string]int{
		"AF_INET": plain.LocalAddr().(*net.TCPAddr).Port,
		// How Firefox talks IPv4: an AF_INET6 socket on ::ffff:127.0.0.1.
		"AF_INET6 v4-mapped": mapped.port,
	} {
		_, path, err := process.FindProcessName("tcp", localhost, srcPort)
		if err != nil || path != self {
			t.Errorf("%s socket: found %q, %v; want this test binary", name, path, err)
		}
	}

	// Nobody owns this one. Upstream answered with the last socket in the
	// kernel's list instead of "not found".
	if _, path, err := process.FindProcessName("tcp", localhost, 1); err == nil {
		t.Errorf("no socket on port 1, yet found %q", path)
	}
}

type mappedConn struct{ fd, port int }

// Go's net package turns a v4-mapped address into an AF_INET socket, so
// the dual-stack one is made by hand.
func dialMapped(t *testing.T, port int) mappedConn {
	t.Helper()
	fd, err := unix.Socket(unix.AF_INET6, unix.SOCK_STREAM, 0)
	if err != nil {
		t.Fatal(err)
	}
	to := &unix.SockaddrInet6{Port: port, Addr: netip.MustParseAddr("::ffff:127.0.0.1").As16()}
	if err := unix.Connect(fd, to); err != nil {
		unix.Close(fd)
		t.Skip("v4-mapped connect:", err)
	}
	sa, err := unix.Getsockname(fd)
	if err != nil {
		t.Fatal(err)
	}
	return mappedConn{fd: fd, port: sa.(*unix.SockaddrInet6).Port}
}
