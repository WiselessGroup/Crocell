// Package mobile is the core as an Android library, built with gomobile
// bind. The app runs it in its own process: the same service as crocelld,
// on a unix socket in the app's private directory, with VpnService
// building the interface. The Flutter client talks to it exactly as it
// talks to crocelld on the desktop.
package mobile

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net"
	"os"
	"path/filepath"
	"sync"

	"google.golang.org/grpc"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/daemon"
	"git.wiseless.net/fureunoir/crocell/core/probe"
	"git.wiseless.net/fureunoir/crocell/core/procs"
)

// Platform is what the Android side provides. Implemented in Kotlin.
type Platform interface {
	// OpenTun establishes the VPN interface described by request (JSON of
	// daemon.TunRequest) and returns its file descriptor, detached: the
	// core owns and closes it.
	OpenTun(request string) (int32, error)
	// CloseTun stops the VPN service after a disconnect.
	CloseTun()
	// InstalledApps lists launchable apps as JSON:
	// [{"package": "org.telegram.messenger", "label": "Telegram"}].
	InstalledApps() (string, error)
}

var (
	mu     sync.Mutex
	svc    *daemon.Service
	srv    *grpc.Server
	cancel context.CancelFunc
)

// Start runs the core. dataDir holds the encrypted state, socket is where
// the client connects, pkg is the app's own package (kept out of the
// tunnel), key is the state key kept in the Android Keystore. Calling it
// again while running does nothing.
func Start(dataDir, socket, pkg string, key []byte, p Platform) error {
	mu.Lock()
	defer mu.Unlock()
	if svc != nil {
		return nil
	}
	if p == nil {
		return errors.New("mobile: no platform")
	}
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return err
	}
	s, err := daemon.New(daemon.Config{
		StateDir: dataDir,
		StateKey: key,
		Package:  pkg,
		Tun:      tun{p},
		Programs: func() ([]procs.Process, error) { return apps(p) },
		// The app is outside its own tunnel, so a plain request from here
		// would not go through the VPN. The mixed port does.
		Check: func(ctx context.Context, _ pb.TunnelMode, port int) probe.Result { return probe.ViaProxy(ctx, port) },
	})
	if err != nil {
		return err
	}

	// The private directory is the access control: no other app can
	// reach into it.
	_ = os.Remove(socket)
	if err := os.MkdirAll(filepath.Dir(socket), 0o700); err != nil {
		s.Close()
		return err
	}
	lis, err := net.Listen("unix", socket)
	if err != nil {
		s.Close()
		return err
	}
	_ = os.Chmod(socket, 0o600)

	g := grpc.NewServer()
	pb.RegisterCoreServer(g, s)
	ctx, stop := context.WithCancel(context.Background())
	go s.Run(ctx)
	go func() {
		if err := g.Serve(lis); err != nil && !errors.Is(err, grpc.ErrServerStopped) {
			log.Printf("crocell: API: %v", err)
		}
	}()
	svc, srv, cancel = s, g, stop
	log.Printf("crocell: core on %s, state in %s", socket, dataDir)
	return nil
}

// Connect resumes the last node, for the system's always-on VPN, which
// starts the service without the app.
func Connect() error {
	mu.Lock()
	s := svc
	mu.Unlock()
	if s == nil {
		return errors.New("mobile: core not started")
	}
	_, err := s.Connect(context.Background(), &pb.ConnectRequest{})
	return err
}

// Disconnect takes the VPN down, for the notification's button and for
// the system revoking the VPN.
func Disconnect() {
	mu.Lock()
	s := svc
	mu.Unlock()
	if s != nil {
		_, _ = s.Disconnect(context.Background(), &pb.DisconnectRequest{})
	}
}

// Stop shuts the core down.
func Stop() {
	mu.Lock()
	defer mu.Unlock()
	if svc == nil {
		return
	}
	cancel()
	srv.Stop()
	svc.Close()
	svc, srv, cancel = nil, nil, nil
}

type tun struct{ p Platform }

func (t tun) Open(r daemon.TunRequest) (int, error) {
	b, err := json.Marshal(r)
	if err != nil {
		return 0, err
	}
	fd, err := t.p.OpenTun(string(b))
	return int(fd), err
}

func (t tun) Close() { t.p.CloseTun() }

func apps(p Platform) ([]procs.Process, error) {
	raw, err := p.InstalledApps()
	if err != nil {
		return nil, err
	}
	var list []struct{ Package, Label string }
	if err := json.Unmarshal([]byte(raw), &list); err != nil {
		return nil, err
	}
	out := make([]procs.Process, 0, len(list))
	for _, a := range list {
		out = append(out, procs.Process{Name: a.Package, Label: a.Label})
	}
	return out, nil
}
