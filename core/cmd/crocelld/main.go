// Command crocelld is the Crocell core service. It runs privileged (systemd,
// Windows service, launchd), holds the tunnel, and serves the crocell.v1 API
// to the unprivileged client over a local socket.
//
//	crocelld                 run in the foreground
//	crocelld install         install and start the system service
//	crocelld uninstall       stop and remove it
//	crocelld connect | disconnect | watch | refresh-all | quit    control the running service
//	crocelld gnome-extension install | uninstall    the GNOME quick toggle
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
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
	"git.wiseless.net/fureunoir/crocell/core/logbuf"
)

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "install":
			exit(install(os.Args[2:]))
		case "uninstall":
			exit(uninstall())
		case "connect", "disconnect", "watch", "refresh-all", "quit":
			exit(ctl(os.Args[1], os.Args[2:]))
		case "gnome-extension":
			exit(gnomeExtension(os.Args[2:]))
		}
	}
	// Under the Windows service manager the stop comes from it, not from
	// a signal.
	if handled, err := runService(os.Args[1:]); handled {
		exit(err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	exit(serve(ctx, os.Args[1:]))
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

func serve(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("crocelld", flag.ExitOnError)
	socket := fs.String("socket", paths.Socket, "API socket path")
	stateDir := fs.String("state-dir", paths.StateDir, "where subscriptions and settings live")
	var allow uidList
	fs.Var(&allow, "allow-uid", "uids allowed to use the API besides root, comma-separated (Linux, macOS)")
	logFile := fs.String("log", defaultLog, "write the log here instead of stderr")
	if err := fs.Parse(args); err != nil {
		return err
	}

	if *logFile != "" {
		if err := logTo(*logFile); err != nil {
			return err
		}
	}
	// The app's "Logs" button reads these back.
	logbuf.Capture()
	if err := os.MkdirAll(*stateDir, 0o700); err != nil {
		return err
	}
	if err := secureStateDir(*stateDir); err != nil {
		return err
	}
	// "Quit completely" ends the service the way a stop signal would, with a
	// clean exit: restart policies only act on failures.
	ctx, quit := context.WithCancel(ctx)
	defer quit()
	svc, err := daemon.New(daemon.Config{StateDir: *stateDir, Shutdown: quit})
	if err != nil {
		return err
	}
	defer svc.Close()

	lis, opts, err := listen(*socket, allow)
	if err != nil {
		return err
	}

	srv := grpc.NewServer(append(opts, daemon.LangInterceptors()...)...)
	pb.RegisterCoreServer(srv, svc)

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

// logTo sends the log to a file, for services nobody watches the stderr of.
// A log past a few megabytes starts over rather than growing forever.
func logTo(path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if fi, err := os.Stat(path); err == nil && fi.Size() > 4<<20 {
		_ = os.Rename(path, path+".old")
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	log.SetOutput(f)
	return nil
}
