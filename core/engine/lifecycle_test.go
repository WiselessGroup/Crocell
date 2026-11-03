package engine

import (
	"net"
	"strconv"
	"testing"
	"time"

	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

func listening(port int) bool {
	c, err := net.DialTimeout("tcp", "127.0.0.1:"+strconv.Itoa(port), 300*time.Millisecond)
	if err != nil {
		return false
	}
	c.Close()
	return true
}

// The bug this guards: after Stop, a second Start in the same process must
// bring everything back, and Stop must really close what Start opened.
// It runs real mihomo listeners on localhost; nothing dials a node.
func TestStopThenStartReopens(t *testing.T) {
	port := freePort(t)
	opts := Options{HomeDir: t.TempDir(), MixedPort: port, LogLevel: "silent", Nodes: testNodes()}

	for round := 1; round <= 3; round++ {
		if err := Start(opts); err != nil {
			t.Fatalf("round %d start: %v", round, err)
		}
		if !listening(port) {
			t.Fatalf("round %d: mixed port %d not open after Start", round, port)
		}
		if got := Selected(); got != "reality" {
			t.Errorf("round %d: selected %q", round, got)
		}

		Stop()
		if listening(port) {
			t.Fatalf("round %d: mixed port %d still open after Stop", round, port)
		}
	}
}

// Fallback nodes go to closed local ports: the group's health check runs at
// once on start, and this keeps it off the network.
func TestAutoNodeStartsWhereAskedAndCanBeMoved(t *testing.T) {
	closed := func(name string) subscription.Node {
		return subscription.Node{Name: name, Type: "socks5", Server: "127.0.0.1", Port: "1", Proxy: map[string]any{
			"name": name, "type": "socks5", "server": "127.0.0.1", "port": 1,
		}}
	}
	opts := Options{
		HomeDir: t.TempDir(), LogLevel: "silent", AutoNode: true, Selected: "second",
		Nodes: []subscription.Node{closed("first"), closed("second")},
	}
	if err := Start(opts); err != nil {
		t.Fatal(err)
	}
	defer Stop()
	if got := Current(); got != "second" && got != "first" {
		t.Errorf("current = %q", got)
	}
	if err := Select("first"); err != nil {
		t.Errorf("select: %v", err)
	}
	if err := Select("nobody"); err == nil {
		t.Error("selecting a node that is not there should fail")
	}
}
