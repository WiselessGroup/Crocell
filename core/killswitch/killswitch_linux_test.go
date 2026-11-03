//go:build linux && !android

package killswitch

import (
	"context"
	"errors"
	"net"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"testing"
	"time"
)

const inNamespace = "CROCELL_KILLSWITCH_TEST_IN_NETNS"

// The rules are only ever tried in a network namespace of their own, entered by
// running this test again under unshare. Nothing here can reach the firewall or
// the network of the machine it runs on.
func TestRulesInAnIsolatedNamespace(t *testing.T) {
	if os.Getenv(inNamespace) == "" {
		if _, err := exec.LookPath("unshare"); err != nil {
			t.Skip("no unshare")
		}
		cmd := exec.Command("unshare", "-Urn", os.Args[0], "-test.run=^TestRulesInAnIsolatedNamespace$", "-test.v")
		cmd.Env = append(os.Environ(), inNamespace+"=1")
		out, err := cmd.CombinedOutput()
		text := string(out)
		if strings.Contains(text, "unshare failed") || strings.Contains(text, "Operation not permitted") && err != nil && !strings.Contains(text, "--- FAIL") {
			t.Skipf("no user namespaces here: %s", text)
		}
		if strings.Contains(text, "--- SKIP") {
			t.Skip(text)
		}
		if err != nil {
			t.Fatalf("%v\n%s", err, text)
		}
		return
	}

	// Only the namespace unshare made has just "lo" in it. Refuse to go on
	// if that does not hold: this must never run on a real network.
	ifaces, err := net.Interfaces()
	if err != nil {
		t.Fatal(err)
	}
	if len(ifaces) != 1 || ifaces[0].Name != "lo" {
		t.Fatalf("not an empty namespace: %v", ifaces)
	}

	// Some systems (GitHub's runners among them) grant a user namespace but
	// keep its capabilities from it.
	if out, err := exec.Command("ip", "link", "set", "lo", "up").CombinedOutput(); err != nil {
		t.Skipf("no network administration in this namespace: %v\n%s", err, out)
	}
	if err := exec.Command("ip", "link", "add", "dummy0", "type", "dummy").Run(); err != nil {
		t.Skipf("no dummy interfaces: %v", err)
	}
	run(t, "ip", "addr", "add", "192.0.2.1/24", "dev", "dummy0")
	run(t, "ip", "link", "set", "dummy0", "up")
	if err := exec.Command("ip", "link", "add", "crocell", "type", "dummy").Run(); err != nil {
		t.Skipf("no dummy interfaces: %v", err)
	}
	run(t, "ip", "addr", "add", "198.51.100.1/24", "dev", "crocell")
	run(t, "ip", "link", "set", "crocell", "up")

	send := func(dst string, d *net.Dialer) error {
		c, err := d.Dial("udp", dst)
		if err != nil {
			return err
		}
		defer c.Close()
		_, err = c.Write([]byte("x"))
		return err
	}
	plain := &net.Dialer{Timeout: time.Second}
	marked := &net.Dialer{Timeout: time.Second, Control: control}

	if err := send("192.0.2.2:9", plain); err != nil {
		t.Fatalf("before the rules: %v", err)
	}

	fw := New()
	if err := fw.Unblock(); err != nil {
		t.Fatalf("unblock with nothing there: %v", err)
	}
	for range 2 { // the second time replaces the first
		if err := fw.Block("crocell"); err != nil {
			t.Fatalf("block: %v", err)
		}
	}

	// A dropped datagram comes back as "operation not permitted".
	if err := send("192.0.2.2:9", plain); !errors.Is(err, syscall.EPERM) {
		t.Errorf("past the tunnel: got %v, want it blocked", err)
	}
	if err := send("192.0.2.2:9", marked); err != nil {
		t.Errorf("the service's own socket: %v", err)
	}
	if err := send("198.51.100.2:9", plain); err != nil {
		t.Errorf("through the tunnel: %v", err)
	}
	if err := send("127.0.0.1:9", plain); err != nil && !errors.Is(err, syscall.ECONNREFUSED) {
		t.Errorf("loopback: %v", err)
	}
	if err := send("192.0.2.2:67", plain); err != nil {
		t.Errorf("DHCP: %v", err)
	}

	if err := fw.Unblock(); err != nil {
		t.Fatalf("unblock: %v", err)
	}
	if err := send("192.0.2.2:9", plain); err != nil {
		t.Errorf("after the rules: %v", err)
	}
}

func run(t *testing.T, name string, args ...string) {
	t.Helper()
	if out, err := exec.Command(name, args...).CombinedOutput(); err != nil {
		t.Fatalf("%s %v: %v\n%s", name, args, err, out)
	}
}

func TestDialCarriesTheMark(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	lis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer lis.Close()
	// Without CAP_NET_ADMIN the mark is skipped, and the dial still works.
	c, err := Dial(ctx, "tcp", lis.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
}
