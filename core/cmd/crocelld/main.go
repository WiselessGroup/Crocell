// Command crocelld is the Crocell core service. It runs privileged (systemd,
// Windows service, launchd), holds the tunnel, and serves the crocell.v1 API
// to the unprivileged client over a local socket.
//
//	crocelld                 run in the foreground
//	crocelld install         install and start the system service
//	crocelld uninstall       stop and remove it
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"google.golang.org/grpc"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/daemon"
	"git.wiseless.net/fureunoir/crocell/core/internal/paths"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "install":
			exit(install(os.Args[2:]))
		case "uninstall":
			exit(uninstall())
		}
	}
	exit(serve(os.Args[1:]))
}

func exit(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "crocelld:", err)
		os.Exit(1)
	}
	os.Exit(0)
}

type uidList []uint32

func (u *uidList) String() string { return fmt.Sprint(*u) }
func (u *uidList) Set(s string) error {
	for _, part := range strings.Split(s, ",") {
		n, err := strconv.ParseUint(strings.TrimSpace(part), 10, 32)
		if err != nil {
			return fmt.Errorf("bad uid %q", part)
		}
		*u = append(*u, uint32(n))
	}
	return nil
}

func serve(args []string) error {
	fs := flag.NewFlagSet("crocelld", flag.ExitOnError)
	socket := fs.String("socket", paths.Socket, "API socket path")
	stateDir := fs.String("state-dir", paths.StateDir, "where subscriptions and settings live")
	var allow uidList
	fs.Var(&allow, "allow-uid", "uids allowed to use the API besides root, comma-separated (Linux, macOS)")
	if err := fs.Parse(args); err != nil {
		return err
	}

	if err := os.MkdirAll(*stateDir, 0o700); err != nil {
		return err
	}
	svc, err := daemon.New(daemon.Config{StateDir: *stateDir})
	if err != nil {
		return err
	}
	defer svc.Close()

	lis, err := listen(*socket, allow)
	if err != nil {
		return err
	}

	srv := grpc.NewServer()
	pb.RegisterCoreServer(srv, svc)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	// Connect-on-start and keeping geo databases fresh.
	go svc.Run(ctx)

	go func() {
		<-ctx.Done()
		// GracefulStop waits for every open stream, and a client watching
		// the status never closes its stream. Give unary calls a moment,
		// then cut the rest, so the deferred Close still tears TUN down
		// before systemd loses patience and kills us mid-cleanup.
		done := make(chan struct{})
		go func() { srv.GracefulStop(); close(done) }()
		select {
		case <-done:
		case <-time.After(3 * time.Second):
			srv.Stop()
		}
	}()

	log.Printf("crocelld: listening on %s, state in %s", *socket, *stateDir)
	if err := srv.Serve(lis); err != nil && !errors.Is(err, grpc.ErrServerStopped) {
		return err
	}
	return nil
}

// listen opens the API socket. Anyone may connect at the file level; who
// actually gets served is decided per connection by the peer's uid.
func listen(path string, allow uidList) (net.Listener, error) {
	// sun_path is 108 bytes on Linux, 104 on macOS; longer paths fail with a
	// bare "bind: invalid argument".
	if len(path) > 100 {
		return nil, fmt.Errorf("socket path is %d bytes, unix sockets allow about 100: %s", len(path), path)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	_ = os.Remove(path) // stale socket from a crash
	lis, err := net.Listen("unix", path)
	if err != nil {
		return nil, err
	}
	if err := os.Chmod(path, 0o666); err != nil {
		lis.Close()
		return nil, err
	}
	return &peerListener{Listener: lis, allow: allow}, nil
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
