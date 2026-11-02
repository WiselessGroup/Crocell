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
	"google.golang.org/grpc/metadata"
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

func (f *fakeEngine) starts() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.started)
}

// waitFor polls cond for up to two seconds: for what the service does on
// its own timers (reconnecting after a settings change).
func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()
	for deadline := time.Now().Add(2 * time.Second); time.Now().Before(deadline); time.Sleep(5 * time.Millisecond) {
		if cond() {
			return
		}
	}
	t.Fatalf("timed out waiting for %s", what)
}

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

func newHarness(t *testing.T, opts ...func(*Config)) *harness {
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
	cfg := Config{
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
		ReconnectDelay: 20 * time.Millisecond,
	}
	for _, o := range opts {
		o(&cfg)
	}
	svc, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(svc.Close) // stops the check loop

	lis := bufconn.Listen(1 << 20)
	srv := grpc.NewServer(LangInterceptors()...)
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

	// The state file keeps the real link, encrypted and owner-only.
	path := filepath.Join(h.dir, "state.enc")
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("state.enc mode = %v, want 0600", info.Mode().Perm())
	}
	raw, _ := os.ReadFile(path)
	for _, secret := range []string{"secret-token", "00000000-0000-4000-8000-000000000002", "example.com", "WISELESS"} {
		if strings.Contains(string(raw), secret) {
			t.Errorf("state.enc contains %q in the clear", secret)
		}
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

// The person adds three rules in a row: the tunnel restarts once, after
// the last one, and not while they are still typing.
func TestSettingsChangesRestartOnce(t *testing.T) {
	h := newHarness(t, func(c *Config) { c.ReconnectDelay = 150 * time.Millisecond })
	sub := h.add(t)
	ctx := context.Background()
	if _, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	before := h.eng.starts()
	var rules []*pb.RouteRule
	for _, d := range []string{"a.example", "b.example", "c.example"} {
		rules = append(rules, &pb.RouteRule{Kind: pb.RuleKind_RULE_KIND_DOMAIN, Value: d, Action: pb.RouteAction_ROUTE_ACTION_DIRECT})
		if _, err := h.client.UpdateSettings(ctx, &pb.Settings{Rules: rules}); err != nil {
			t.Fatal(err)
		}
	}
	if h.eng.starts() != before {
		t.Fatal("restarted while settings were still changing")
	}
	waitFor(t, "one restart", func() bool { return h.eng.starts() == before+1 })
	time.Sleep(200 * time.Millisecond)
	if n := h.eng.starts() - before; n != 1 || len(h.eng.last().Rules) != 3 {
		t.Errorf("%d restarts, last with %d rules", n, len(h.eng.last().Rules))
	}
	if st, _ := h.client.GetStatus(ctx, &pb.GetStatusRequest{}); st.State != pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		t.Errorf("after restart: %v", st.State)
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
		TunnelMode:  pb.TunnelMode_TUNNEL_MODE_TUN,
		FinalAction: pb.RouteAction_ROUTE_ACTION_DIRECT,
		DisableIpv6: true,
		Dns:         &pb.DnsSettings{Servers: []string{"https://dns.adguard-dns.com/dns-query"}, RealIp: true},
		Rules: []*pb.RouteRule{
			{Kind: pb.RuleKind_RULE_KIND_PROCESS_NAME, Value: "steam", Action: pb.RouteAction_ROUTE_ACTION_DIRECT},
			{Kind: pb.RuleKind_RULE_KIND_DOMAIN_WILDCARD, Value: "*.wiseless.net", Action: pb.RouteAction_ROUTE_ACTION_PROXY},
			{Kind: pb.RuleKind_RULE_KIND_IP_CIDR, Value: "10.8.0.0/16", Action: pb.RouteAction_ROUTE_ACTION_BLOCK},
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	// Connected, so the new settings are applied by reconnecting, shortly.
	waitFor(t, "reconnect with new settings", func() bool { return h.eng.last().Tun != nil })
	last := h.eng.last()
	if last.Tun == nil {
		t.Error("TUN not applied")
	}
	if len(last.Rules) != 3 || last.Rules[0].Kind != engine.ProcessName || last.Rules[1].Kind != engine.DomainWildcard ||
		last.Rules[2].Action != engine.Block {
		t.Errorf("rules = %+v", last.Rules)
	}
	if last.Final != engine.Direct || last.IPv6 || !last.DNS.RealIP || len(last.DNS.Servers) != 1 {
		t.Errorf("final %v, ipv6 %v, dns %+v", last.Final, last.IPv6, last.DNS)
	}

	_, err = h.client.UpdateSettings(ctx, &pb.Settings{MixedPort: 80})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("privileged port must be refused, got %v", err)
	}
	_, err = h.client.UpdateSettings(ctx, &pb.Settings{Rules: []*pb.RouteRule{
		{Kind: pb.RuleKind_RULE_KIND_DOMAIN, Value: "evil.com,DIRECT", Action: pb.RouteAction_ROUTE_ACTION_PROXY},
	}})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("a rule that would split the mihomo line must be refused, got %v", err)
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
	h := newHarness(t, func(c *Config) { c.CheckInterval = 50 * time.Millisecond })
	sub := h.add(t)
	if _, err := h.client.Connect(context.Background(), &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	waitStatus(t, h, func(s *pb.Status) bool { return s.LiveCheck != nil && s.LiveCheck.Error == "" })

	// The node dies later: the next round must notice.
	h.setCheckErr(errors.New("probe: connection reset"))
	waitStatus(t, h, func(s *pb.Status) bool { return s.LiveCheck != nil && s.LiveCheck.Error != "" })
}

// Right after a restart the first check can land before the tunnel is
// ready. One failure followed by success must never reach the screen as
// "connected, no internet".
func TestOneFailedCheckIsLookedAtAgain(t *testing.T) {
	var mu sync.Mutex
	calls := 0
	h := newHarness(t, func(c *Config) {
		c.CheckInterval = time.Hour // only the quick second look can run
		c.Check = func(ctx context.Context, mode pb.TunnelMode, port int) probe.Result {
			mu.Lock()
			defer mu.Unlock()
			calls++
			if calls == 1 {
				return probe.Result{Err: errors.New("network is unreachable")}
			}
			return probe.Result{ExitIP: "203.0.113.8", ExitCountry: "DE"}
		}
	})
	sub := h.add(t)
	ctx := context.Background()
	stream, err := h.client.WatchStatus(ctx, &pb.WatchStatusRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id}); err != nil {
		t.Fatal(err)
	}
	for {
		st, err := stream.Recv()
		if err != nil {
			t.Fatal(err)
		}
		if lc := st.GetLiveCheck(); lc != nil {
			if lc.Error != "" {
				t.Fatalf("a single failure was shown: %v", lc.Error)
			}
			if lc.ExitIp != "" {
				return
			}
		}
	}
}

// A failed connect left the status on the failed node, so picking another
// one changed nothing on screen until the next Connect.
func TestPickingANodeAfterAFailureShowsIt(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()

	h.eng.mu.Lock()
	h.eng.failWith = errors.New("boom")
	h.eng.mu.Unlock()
	st, _ := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id, NodeId: sub.Nodes[0].Id})
	if st.GetState() != pb.ConnectionState_CONNECTION_STATE_FAILED {
		t.Fatalf("state = %v, want failed", st.GetState())
	}

	st, err := h.client.SelectNode(ctx, &pb.SelectNodeRequest{SubscriptionId: sub.Id, NodeId: sub.Nodes[2].Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.NodeId != sub.Nodes[2].Id || st.State != pb.ConnectionState_CONNECTION_STATE_DISCONNECTED || st.Error != "" {
		t.Errorf("status after picking = %v, want the new node, disconnected, no error", st)
	}
}

// The app in English gets the service's explanations in English, and the
// language sticks for errors that come later without a call.
func TestErrorsComeInTheClientsLanguage(t *testing.T) {
	h := newHarness(t)
	t.Cleanup(func() { english.Store(false) })
	ctx := metadata.AppendToOutgoingContext(context.Background(), LangHeader, "en")
	set, err := h.client.GetSettings(ctx, &pb.GetSettingsRequest{})
	if err != nil {
		t.Fatal(err)
	}
	set.Dns = &pb.DnsSettings{DirectServers: []string{"system"}}
	_, err = h.client.UpdateSettings(ctx, set)
	if err == nil || !strings.Contains(err.Error(), "will not do") {
		t.Errorf("error = %v, want it in English", err)
	}

	ru := metadata.AppendToOutgoingContext(context.Background(), LangHeader, "ru")
	_, err = h.client.UpdateSettings(ru, set)
	if err == nil || !strings.Contains(err.Error(), "не подходит") {
		t.Errorf("error = %v, want it in Russian", err)
	}
}

// A pasted config carries a private key: nothing of it may show in the list.
func TestPastedConfigIsNotShown(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()
	conf := "[Interface]\nPrivateKey = SECRETKEY\nAddress = 10.8.1.2/32\nJc = 4\n[Peer]\nPublicKey = b\nEndpoint = awg.example.net:51820\n"
	sub, err := h.client.AddSubscription(ctx, &pb.AddSubscriptionRequest{Url: conf})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(sub.UrlMasked, "SECRETKEY") || strings.Contains(sub.UrlMasked, "[Interface]") {
		t.Errorf("masked = %q", sub.UrlMasked)
	}
	if len(sub.Nodes) != 1 || sub.Nodes[0].Type != "amneziawg" {
		t.Errorf("nodes = %v", sub.Nodes)
	}
}
