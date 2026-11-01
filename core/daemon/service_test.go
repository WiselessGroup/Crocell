package daemon

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/probe"
)

// fakeEngine records what the service asked for instead of running mihomo.
type fakeEngine struct {
	mu       sync.Mutex
	started  []engine.Options
	selected []string
	stopped  int
	failWith error
}

func (f *fakeEngine) Start(o engine.Options) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.started = append(f.started, o)
	return f.failWith
}
func (f *fakeEngine) Stop() { f.mu.Lock(); f.stopped++; f.mu.Unlock() }
func (f *fakeEngine) Select(name string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.selected = append(f.selected, name)
	return nil
}
func (f *fakeEngine) Traffic() engine.Traffic { return engine.Traffic{Up: 10, Down: 20} }

func (f *fakeEngine) last() engine.Options {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.started[len(f.started)-1]
}

type harness struct {
	client pb.CoreClient
	eng    *fakeEngine
	subURL string
	dir    string

	checkMu  sync.Mutex
	checkErr error // what the live check reports next
}

func (h *harness) setCheckErr(err error) {
	h.checkMu.Lock()
	h.checkErr = err
	h.checkMu.Unlock()
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	links, err := os.ReadFile("../subscription/testdata/links.b64")
	if err != nil {
		t.Fatal(err)
	}
	web := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/sub/secret-token-123456") {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(links)
	}))
	t.Cleanup(web.Close)

	h := &harness{eng: &fakeEngine{}, subURL: web.URL + "/sub/secret-token-123456", dir: t.TempDir()}
	svc, err := New(Config{
		StateDir: h.dir,
		Engine:   h.eng,
		Probe: func(ctx context.Context, proxy map[string]any) probe.Result {
			return probe.Result{ExitIP: "203.0.113.7", ExitCountry: "NL", ExitColo: "AMS", Latency: 140 * time.Millisecond}
		},
		// Never the real check here: it would dial 127.0.0.1:7890, where
		// the developer's own VPN client may well be listening.
		Check: func(ctx context.Context, mode pb.TunnelMode, port int) probe.Result {
			h.checkMu.Lock()
			defer h.checkMu.Unlock()
			if h.checkErr != nil {
				return probe.Result{Err: h.checkErr}
			}
			return probe.Result{ExitIP: "203.0.113.8", ExitCountry: "DE", ExitColo: "FRA", Latency: 90 * time.Millisecond}
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	lis := bufconn.Listen(1 << 20)
	srv := grpc.NewServer()
	pb.RegisterCoreServer(srv, svc)
	go func() { _ = srv.Serve(lis) }()
	t.Cleanup(srv.Stop)

	conn, err := grpc.NewClient("passthrough:///bufnet",
		grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) { return lis.DialContext(ctx) }),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	h.client = pb.NewCoreClient(conn)
	return h
}

func (h *harness) add(t *testing.T) *pb.Subscription {
	t.Helper()
	sub, err := h.client.AddSubscription(context.Background(), &pb.AddSubscriptionRequest{Url: h.subURL})
	if err != nil {
		t.Fatal(err)
	}
	return sub
}

func TestAddSubscriptionHidesTheLink(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)

	if sub.Title != "WISELESS" || len(sub.Nodes) != 4 {
		t.Fatalf("sub = %s, %d nodes", sub.Title, len(sub.Nodes))
	}
	if strings.Contains(sub.UrlMasked, "secret-token") {
		t.Errorf("masked url leaks the token: %s", sub.UrlMasked)
	}

	// The state file keeps the real link, readable by its owner only.
	info, err := os.Stat(filepath.Join(h.dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("state.json mode = %v, want 0600", info.Mode().Perm())
	}
}

func TestBadLinkErrorDoesNotLeakToken(t *testing.T) {
	h := newHarness(t)
	_, err := h.client.AddSubscription(context.Background(), &pb.AddSubscriptionRequest{
		Url: "http://127.0.0.1:1/sub/very-secret-token-abcdef",
	})
	if err == nil {
		t.Fatal("want error")
	}
	if strings.Contains(err.Error(), "very-secret-token") {
		t.Errorf("error leaks the token: %v", err)
	}
}

func TestConnectSelectDisconnect(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()

	st, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id, NodeId: sub.Nodes[2].Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.State != pb.ConnectionState_CONNECTION_STATE_CONNECTED || st.MixedPort != 7890 {
		t.Fatalf("status = %v", st)
	}
	if st.TunnelMode != pb.TunnelMode_TUNNEL_MODE_SYSTEM_PROXY || h.eng.last().Tun != nil {
		t.Error("default mode must be system proxy, no TUN")
	}
	if h.eng.last().Selected != sub.Nodes[2].Name {
		t.Errorf("engine selected %q", h.eng.last().Selected)
	}
	if st.Traffic.GetDownBytes() != 20 {
		t.Errorf("traffic = %v", st.Traffic)
	}

	// Same subscription: switch in place, no restart.
	st, err = h.client.SelectNode(ctx, &pb.SelectNodeRequest{SubscriptionId: sub.Id, NodeId: sub.Nodes[0].Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.NodeId != sub.Nodes[0].Id || len(h.eng.started) != 1 || len(h.eng.selected) != 1 {
		t.Errorf("select: node %s, starts %d, selects %d", st.NodeId, len(h.eng.started), len(h.eng.selected))
	}

	st, err = h.client.Disconnect(ctx, &pb.DisconnectRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if st.State != pb.ConnectionState_CONNECTION_STATE_DISCONNECTED || h.eng.stopped != 1 {
		t.Errorf("after disconnect: %v, stopped %d", st.State, h.eng.stopped)
	}
	if st.NodeId != sub.Nodes[0].Id {
		t.Errorf("disconnected status should show the node to resume, got %q", st.NodeId)
	}

	// Connect with no ids resumes the last node.
	if _, err := h.client.Connect(ctx, &pb.ConnectRequest{}); err != nil {
		t.Fatal(err)
	}
	if h.eng.last().Selected != sub.Nodes[0].Name {
		t.Errorf("resumed %q, want last selected %q", h.eng.last().Selected, sub.Nodes[0].Name)
	}
}

func TestFailedStartIsReported(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	h.eng.failWith = errors.New("engine: TUN did not start")

	st, err := h.client.Connect(context.Background(), &pb.ConnectRequest{SubscriptionId: sub.Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.State != pb.ConnectionState_CONNECTION_STATE_FAILED || !strings.Contains(st.Error, "TUN") {
		t.Errorf("status = %v", st)
	}
}

func TestSettingsReachTheEngine(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()

	if _, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	_, err := h.client.UpdateSettings(ctx, &pb.Settings{
		TunnelMode: pb.TunnelMode_TUNNEL_MODE_TUN,
		AppRules: []*pb.AppRule{
			{App: "steam", Mode: pb.AppMode_APP_MODE_BYPASS},
			{App: "spyware", Mode: pb.AppMode_APP_MODE_BLOCK},
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	// Connected, so the new settings applied by reconnecting.
	last := h.eng.last()
	if last.Tun == nil {
		t.Error("TUN not applied")
	}
	if len(last.AppRules) != 2 || last.AppRules[0].Mode != engine.AppBypass || last.AppRules[1].Mode != engine.AppBlock {
		t.Errorf("app rules = %+v", last.AppRules)
	}

	_, err = h.client.UpdateSettings(ctx, &pb.Settings{MixedPort: 80})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("privileged port must be refused, got %v", err)
	}
}

func TestStatePersists(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)

	svc, err := New(Config{StateDir: h.dir, Engine: &fakeEngine{}, Check: func(context.Context, pb.TunnelMode, int) probe.Result {
		return probe.Result{}
	}})
	if err != nil {
		t.Fatal(err)
	}
	list, err := svc.ListSubscriptions(context.Background(), &pb.ListSubscriptionsRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if len(list.Subscriptions) != 1 || list.Subscriptions[0].Id != sub.Id {
		t.Fatalf("after restart: %v", list.Subscriptions)
	}
	if list.Subscriptions[0].Nodes[1].Id != sub.Nodes[1].Id {
		t.Error("node ids must be stable across restarts")
	}
}

func TestProbeStreamsAndRemembers(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()

	stream, err := h.client.ProbeNodes(ctx, &pb.ProbeNodesRequest{SubscriptionId: sub.Id})
	if err != nil {
		t.Fatal(err)
	}
	n := 0
	for {
		r, err := stream.Recv()
		if err != nil {
			break
		}
		if r.ExitCountry != "NL" || r.LatencyMs != 140 {
			t.Errorf("probe = %v", r)
		}
		n++
	}
	if n != 4 {
		t.Errorf("got %d results, want 4", n)
	}

	list, _ := h.client.ListSubscriptions(ctx, &pb.ListSubscriptionsRequest{})
	if list.Subscriptions[0].Nodes[0].LastProbe.GetExitIp() != "203.0.113.7" {
		t.Error("last probe not attached to the node")
	}
}

func TestWatchStatusSeesChanges(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	stream, err := h.client.WatchStatus(ctx, &pb.WatchStatusRequest{})
	if err != nil {
		t.Fatal(err)
	}
	first, err := stream.Recv()
	if err != nil || first.State != pb.ConnectionState_CONNECTION_STATE_DISCONNECTED {
		t.Fatalf("first = %v, %v", first, err)
	}

	go func() { _, _ = h.client.Connect(context.Background(), &pb.ConnectRequest{SubscriptionId: sub.Id}) }()
	for {
		st, err := stream.Recv()
		if err != nil {
			t.Fatal(err)
		}
		if st.State == pb.ConnectionState_CONNECTION_STATE_CONNECTED {
			return
		}
	}
}

// waitStatus follows WatchStatus until ok accepts a status.
func waitStatus(t *testing.T, h *harness, ok func(*pb.Status) bool) *pb.Status {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	stream, err := h.client.WatchStatus(ctx, &pb.WatchStatusRequest{})
	if err != nil {
		t.Fatal(err)
	}
	for {
		st, err := stream.Recv()
		if err != nil {
			t.Fatalf("waiting for status: %v", err)
		}
		if ok(st) {
			return st
		}
	}
}

func TestLiveCheckAfterConnect(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	if _, err := h.client.Connect(context.Background(), &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	st := waitStatus(t, h, func(s *pb.Status) bool { return s.LiveCheck != nil && !s.Checking })
	if st.LiveCheck.ExitCountry != "DE" || st.LiveCheck.Error != "" {
		t.Errorf("check = %v", st.LiveCheck)
	}
}

func TestBrokenConnectionIsReported(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	h.setCheckErr(errors.New("probe: context deadline exceeded"))
	if _, err := h.client.Connect(context.Background(), &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	st := waitStatus(t, h, func(s *pb.Status) bool { return s.LiveCheck != nil && !s.Checking })
	if st.State != pb.ConnectionState_CONNECTION_STATE_CONNECTED || st.LiveCheck.Error == "" {
		t.Errorf("want connected with a failed check, got %v / %v", st.State, st.LiveCheck)
	}

	// Disconnecting forgets the check.
	st, err := h.client.Disconnect(context.Background(), &pb.DisconnectRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if st.LiveCheck != nil {
		t.Errorf("check survived disconnect: %v", st.LiveCheck)
	}
}

func TestRecheckOnInterval(t *testing.T) {
	old := CheckInterval
	CheckInterval = 50 * time.Millisecond
	t.Cleanup(func() { CheckInterval = old })

	h := newHarness(t)
	sub := h.add(t)
	if _, err := h.client.Connect(context.Background(), &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	waitStatus(t, h, func(s *pb.Status) bool { return s.LiveCheck != nil && s.LiveCheck.Error == "" })

	// The node dies later: the next round must notice.
	h.setCheckErr(errors.New("probe: connection reset"))
	waitStatus(t, h, func(s *pb.Status) bool { return s.LiveCheck != nil && s.LiveCheck.Error != "" })
}
