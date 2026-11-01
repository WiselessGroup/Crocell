package main

import (
	"net"
	"os"
	"path/filepath"
	"testing"
)

func TestPeerUIDIsTheCaller(t *testing.T) {
	dir, err := os.MkdirTemp("", "crl") // short: sun_path is ~100 bytes
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)

	lis, _, err := listen(filepath.Join(dir, "d.sock"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer lis.Close()

	go func() {
		c, err := net.Dial("unix", filepath.Join(dir, "d.sock"))
		if err == nil {
			defer c.Close()
			_, _ = c.Read(make([]byte, 1))
		}
	}()

	c, err := lis.(*peerListener).Listener.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	uid, err := peerUID(c)
	if err != nil {
		t.Fatal(err)
	}
	if uid != uint32(os.Getuid()) {
		t.Errorf("peer uid = %d, want %d", uid, os.Getuid())
	}
}

func TestLongSocketPathIsExplained(t *testing.T) {
	long := "/tmp/" + string(make([]byte, 120))
	if _, _, err := listen(long, nil); err == nil {
		t.Fatal("want a clear error for an over-long socket path")
	}
}
