//go:build !windows

package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"

	"google.golang.org/grpc"
)

// systemd and launchd collect stderr themselves.
const defaultLog = ""

// The state directory is created 0700 and owned by root: nothing more to do.
func secureStateDir(string) error { return nil }

func runService([]string) (bool, error) { return false, nil }

// listen opens the API socket. Anyone may connect at the file level; who
// actually gets served is decided per connection by the peer's uid.
func listen(path string, allow uidList) (net.Listener, []grpc.ServerOption, error) {
	// sun_path is 108 bytes on Linux, 104 on macOS; longer paths fail with a
	// bare "bind: invalid argument".
	if len(path) > 100 {
		return nil, nil, fmt.Errorf("socket path is %d bytes, unix sockets allow about 100: %s", len(path), path)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, nil, err
	}
	_ = os.Remove(path) // stale socket from a crash
	lis, err := net.Listen("unix", path)
	if err != nil {
		return nil, nil, err
	}
	if err := os.Chmod(path, 0o666); err != nil {
		lis.Close()
		return nil, nil, err
	}
	return &peerListener{Listener: lis, allow: allow}, nil, nil
}

// peerListener drops connections from users that are not allowed.
type peerListener struct {
	net.Listener
	allow uidList
}

func (l *peerListener) Accept() (net.Conn, error) {
	for {
		c, err := l.Listener.Accept()
		if err != nil {
			return nil, err
		}
		uid, err := peerUID(c)
		if err == nil && (uid == 0 || uid == uint32(os.Geteuid()) || contains(l.allow, uid)) {
			return c, nil
		}
		log.Printf("crocelld: refused API connection from uid %d (%v)", uid, err)
		c.Close()
	}
}

func contains(list uidList, uid uint32) bool {
	for _, u := range list {
		if u == uid {
			return true
		}
	}
	return false
}
