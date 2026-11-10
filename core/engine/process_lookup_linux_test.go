package engine

import (
	"fmt"
	"io"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"testing"
	"time"

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

// Games keep UDP sockets on 0.0.0.0 and never connect them, while their
// packets reach mihomo from the TUN address. A rule for the game has to
// find such a socket by its port.
func TestProgramLookupWildcardUDP(t *testing.T) {
	tunAddr := netip.MustParseAddr("198.18.0.1")
	self, _ := os.Executable()

	v4, err := net.ListenUDP("udp4", &net.UDPAddr{})
	if err != nil {
		t.Fatal(err)
	}
	defer v4.Close()
	_, path, err := process.FindProcessName("udp", tunAddr, v4.LocalAddr().(*net.UDPAddr).Port)
	if err != nil || path != self {
		t.Errorf("0.0.0.0 socket: found %q, %v; want this test binary", path, err)
	}

	if dual, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv6unspecified}); err == nil {
		defer dual.Close()
		_, path, err := process.FindProcessName("udp", tunAddr, dual.LocalAddr().(*net.UDPAddr).Port)
		if err != nil || path != self {
			t.Errorf(":: socket: found %q, %v; want this test binary", path, err)
		}
	}

	// A wildcard address says nothing about a TCP connection's owner: a
	// listener on the same port must not claim it.
	l, err := net.Listen("tcp4", "0.0.0.0:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	if _, path, err := process.FindProcessName("tcp", tunAddr, l.Addr().(*net.TCPAddr).Port); err == nil {
		t.Errorf("TCP listener claimed a connection from another address: %q", path)
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

// Processes come and go while the lookup walks /proc. One that exits in
// between must not fail the search: upstream gave up on the first lstat
// error, so a program rule missed whenever anything else had just quit.
//
// The walk goes up by pid and stops at the owner, so the processes that
// exit have to come before it: sleepers first, then a child holding the
// socket.
func TestProgramLookupWhileProcessesExit(t *testing.T) {
	if os.Getenv("CROCELL_HOLD_SOCKET") != "" {
		return // the helper's own run, see holdSocket
	}
	var sleepers []*exec.Cmd
	reaped := make(chan struct{}, 300)
	for i := range 300 {
		cmd := exec.Command("sleep", fmt.Sprintf("0.%03d", 100+i*4)) // exits 0.1s..1.3s in
		if err := cmd.Start(); err != nil {
			t.Skip("can't start sleep:", err)
		}
		sleepers = append(sleepers, cmd)
		// Reaped at once: a zombie keeps its /proc entry.
		go func() { _ = cmd.Wait(); reaped <- struct{}{} }()
	}
	defer func() {
		for _, c := range sleepers {
			_ = c.Process.Kill()
		}
		for range sleepers {
			<-reaped
		}
	}()
	port := holdSocket(t)
	self, _ := os.Executable()

	deadline := time.Now().Add(1500 * time.Millisecond)
	for time.Now().Before(deadline) {
		_, path, err := process.FindProcessName("tcp", netip.MustParseAddr("127.0.0.1"), port)
		if err != nil || path != self {
			t.Fatalf("found %q, %v; want the helper, this test binary", path, err)
		}
	}
}

// holdSocket runs this test binary again as a child that connects to us
// and waits, and returns the child's source port.
func holdSocket(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	self, _ := os.Executable()
	cmd := exec.Command(self, "-test.run=^TestHoldSocketHelper$")
	cmd.Env = append(os.Environ(), "CROCELL_HOLD_SOCKET="+l.Addr().String())
	stdin, _ := cmd.StdinPipe()
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stdin.Close(); _ = cmd.Wait() })
	c, err := l.Accept()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	return c.RemoteAddr().(*net.TCPAddr).Port
}

func TestHoldSocketHelper(t *testing.T) {
	addr := os.Getenv("CROCELL_HOLD_SOCKET")
	if addr == "" {
		t.Skip("helper for TestProgramLookupWhileProcessesExit")
	}
	c, err := net.Dial("tcp4", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	_, _ = io.Copy(io.Discard, os.Stdin) // until the parent is done
}
