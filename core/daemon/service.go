// Package daemon is the Core service behind crocelld: it owns subscriptions,
// settings and the running engine, and speaks the crocell.v1 API.
//
// On desktop it runs inside the privileged crocelld process and the client
// talks to it over a local socket. The same type can be embedded in a mobile
// VPN service later.
package daemon

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"slices"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/probe"
	"git.wiseless.net/fureunoir/crocell/core/subscription"
)

// Engine is the part of core/engine the service drives. Tests swap it.
type Engine interface {
	Start(engine.Options) error
	Stop()
	Select(name string) error
	Traffic() engine.Traffic
}

type realEngine struct{}

func (realEngine) Start(o engine.Options) error { return engine.Start(o) }
func (realEngine) Stop()                        { engine.Stop() }
func (realEngine) Select(name string) error     { return engine.Select(name) }
func (realEngine) Traffic() engine.Traffic      { return engine.CurrentTraffic() }

// Config sets the service up. Only StateDir is required.
type Config struct {
	StateDir string
	Engine   Engine                                                       // default: mihomo
	Fetcher  *subscription.Fetcher                                        // default: plain HTTP
	Probe    func(ctx context.Context, proxy map[string]any) probe.Result // default: probe.Node
	// Check tests the live path while connected: through TUN or the mixed
	// port. Default: probe.System / probe.ViaProxy.
	Check func(ctx context.Context, mode pb.TunnelMode, port int) probe.Result
}

// CheckInterval is how often a live connection is re-checked. One small
// HTTPS request: cheap, and it is how "it silently stopped working" turns
// into a notification.
var CheckInterval = 2 * time.Minute

func realCheck(ctx context.Context, mode pb.TunnelMode, port int) probe.Result {
	if mode == pb.TunnelMode_TUNNEL_MODE_TUN {
		return probe.System(ctx)
	}
	return probe.ViaProxy(ctx, port)
}

type Service struct {
	pb.UnimplementedCoreServer

	store   store
	homeDir string
	eng     Engine
	fetcher *subscription.Fetcher
	probe   func(context.Context, map[string]any) probe.Result
	check   func(context.Context, pb.TunnelMode, int) probe.Result

	// op serialises connect/disconnect/reconfigure, which can take seconds
	// (TUN setup). mu guards the fields below and is never held across them.
	op sync.Mutex

	mu      sync.Mutex
	st      *state
	conn    connection
	probes  map[string]*pb.ProbeResult // by node id
	changed chan struct{}              // closed and replaced on every change

	stopChecks context.CancelFunc // ends the running check loop, if any
}

type connection struct {
	state  pb.ConnectionState
	subID  string
	nodeID string
	since  time.Time
	err    string
	mode   pb.TunnelMode
	port   int

	check    *pb.ProbeResult
	checking bool
}

// New loads saved state. Nothing connects until a client asks.
func New(cfg Config) (*Service, error) {
	if cfg.StateDir == "" {
		return nil, errors.New("daemon: no state dir")
	}
	s := &Service{
		store:   store{path: filepath.Join(cfg.StateDir, "state.json")},
		homeDir: filepath.Join(cfg.StateDir, "engine"),
		eng:     cfg.Engine,
		fetcher: cfg.Fetcher,
		probe:   cfg.Probe,
		probes:  map[string]*pb.ProbeResult{},
		changed: make(chan struct{}),
		conn:    connection{state: pb.ConnectionState_CONNECTION_STATE_DISCONNECTED},
	}
	if s.eng == nil {
		s.eng = realEngine{}
	}
	if s.fetcher == nil {
		s.fetcher = &subscription.Fetcher{}
	}
	if s.probe == nil {
		s.probe = probe.Node
	}
	s.check = cfg.Check
	if s.check == nil {
		s.check = realCheck
	}

	st, err := s.store.load()
	if err != nil {
		return nil, err
	}
	s.st = st
	return s, nil
}

// Close disconnects. Called when the daemon shuts down.
func (s *Service) Close() {
	s.op.Lock()
	defer s.op.Unlock()
	s.mu.Lock()
	s.endChecksLocked()
	s.mu.Unlock()
	s.eng.Stop()
}

// notifyLocked wakes every WatchStatus stream. Caller holds mu.
func (s *Service) notifyLocked() {
	close(s.changed)
	s.changed = make(chan struct{})
}

func (s *Service) setConn(c connection) {
	s.mu.Lock()
	s.endChecksLocked()
	s.conn = c
	s.notifyLocked()
	s.mu.Unlock()
}

func (s *Service) endChecksLocked() {
	if s.stopChecks != nil {
		s.stopChecks()
		s.stopChecks = nil
	}
}

// startChecksLocked checks the live connection now and then every
// CheckInterval, until the connection changes. Caller holds mu.
func (s *Service) startChecksLocked() {
	s.endChecksLocked()
	ctx, cancel := context.WithCancel(context.Background())
	s.stopChecks = cancel
	mode, port, nodeID := s.conn.mode, s.conn.port, s.conn.nodeID

	go func() {
		ticker := time.NewTicker(CheckInterval)
		defer ticker.Stop()
		for {
			s.mu.Lock()
			if ctx.Err() != nil {
				s.mu.Unlock()
				return
			}
			s.conn.checking = true
			s.notifyLocked()
			s.mu.Unlock()

			r := toProtoProbe(nodeID, s.check(ctx, mode, port))

			s.mu.Lock()
			if ctx.Err() != nil {
				s.mu.Unlock()
				return
			}
			s.conn.check, s.conn.checking = r, false
			s.notifyLocked()
			s.mu.Unlock()

			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}

// ---------- State ----------

func (s *Service) GetStatus(context.Context, *pb.GetStatusRequest) (*pb.Status, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.statusLocked(), nil
}

func (s *Service) statusLocked() *pb.Status {
	c := s.conn
	// Disconnected: report the node that Connect would resume, so the client
	// can show what is selected before anything runs.
	if c.state == pb.ConnectionState_CONNECTION_STATE_DISCONNECTED && c.subID == "" {
		c.subID, c.nodeID = s.st.Last.SubscriptionID, s.st.Last.NodeID
	}
	st := &pb.Status{
		State:          c.state,
		SubscriptionId: c.subID,
		NodeId:         c.nodeID,
		Error:          c.err,
		TunnelMode:     c.mode,
		LiveCheck:      c.check,
		Checking:       c.checking,
	}
	if c.state == pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		st.ConnectedSince = timestamppb.New(c.since)
		st.MixedPort = uint32(c.port)
		t := s.eng.Traffic()
		st.Traffic = &pb.Traffic{
			UpBytes: uint64(t.Up), DownBytes: uint64(t.Down),
			UpRate: uint64(t.UpRate), DownRate: uint64(t.DownRate),
		}
	}
	return st
}

// WatchStatus sends the status on every change, and once a second while
// connected so the client can show live speed. Nothing ticks while nobody
// watches or nothing is connected.
func (s *Service) WatchStatus(_ *pb.WatchStatusRequest, stream grpc.ServerStreamingServer[pb.Status]) error {
	ctx := stream.Context()
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		s.mu.Lock()
		st := s.statusLocked()
		changed := s.changed
		s.mu.Unlock()

		if err := stream.Send(st); err != nil {
			return err
		}

		var tick <-chan time.Time
		if st.State == pb.ConnectionState_CONNECTION_STATE_CONNECTED {
			tick = ticker.C
		}
		select {
		case <-ctx.Done():
			return nil
		case <-changed:
		case <-tick:
		}
	}
}

// ---------- Connection ----------

func (s *Service) Connect(ctx context.Context, req *pb.ConnectRequest) (*pb.Status, error) {
	s.op.Lock()
	defer s.op.Unlock()

	s.mu.Lock()
	subID, nodeID := req.GetSubscriptionId(), req.GetNodeId()
	if subID == "" {
		subID = s.st.Last.SubscriptionID
	}
	if nodeID == "" && subID == s.st.Last.SubscriptionID {
		nodeID = s.st.Last.NodeID
	}
	sub := s.findSubLocked(subID)
	if sub == nil {
		s.mu.Unlock()
		return nil, status.Error(codes.NotFound, "no such subscription")
	}
	if nodeID == "" && len(sub.Nodes) > 0 {
		nodeID = sub.Nodes[0].ID
	}
	node, ok := sub.node(nodeID)
	if !ok {
		s.mu.Unlock()
		return nil, status.Error(codes.NotFound, "no such node")
	}
	opts, mode, err := s.engineOptionsLocked(sub, node)
	s.mu.Unlock()
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	s.setConn(connection{state: pb.ConnectionState_CONNECTION_STATE_CONNECTING, subID: sub.ID, nodeID: node.ID, mode: mode})

	if err := s.eng.Start(opts); err != nil {
		s.setConn(connection{
			state: pb.ConnectionState_CONNECTION_STATE_FAILED, subID: sub.ID, nodeID: node.ID,
			mode: mode, err: scrub(err.Error(), sub.URL),
		})
	} else {
		s.setConn(connection{
			state: pb.ConnectionState_CONNECTION_STATE_CONNECTED, subID: sub.ID, nodeID: node.ID,
			mode: mode, port: opts.MixedPort, since: time.Now(),
		})
		s.mu.Lock()
		s.startChecksLocked()
		s.mu.Unlock()
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.st.Last = selection{SubscriptionID: sub.ID, NodeID: node.ID}
	if err := s.store.save(s.st); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	return s.statusLocked(), nil
}

func (s *Service) engineOptionsLocked(sub *storedSub, node storedNode) (engine.Options, pb.TunnelMode, error) {
	set := s.st.Settings
	opts := engine.Options{
		HomeDir:   s.homeDir,
		MixedPort: set.MixedPort,
		Nodes:     sub.engineNodes(),
		Selected:  node.Name,
	}
	if opts.MixedPort == 0 {
		opts.MixedPort = defaultMixedPort
	}
	for _, r := range set.AppRules {
		mode, err := appModeFromString(r.Mode)
		if err != nil {
			return engine.Options{}, 0, err
		}
		opts.AppRules = append(opts.AppRules, engine.AppRule{App: r.App, Mode: mode})
	}

	mode := pb.TunnelMode_TUNNEL_MODE_SYSTEM_PROXY
	if set.TunnelMode == "tun" {
		mode = pb.TunnelMode_TUNNEL_MODE_TUN
		opts.Tun = &engine.TunOptions{Stack: set.TunStack}
	}
	return opts, mode, nil
}

func (s *Service) Disconnect(context.Context, *pb.DisconnectRequest) (*pb.Status, error) {
	s.op.Lock()
	defer s.op.Unlock()

	s.mu.Lock()
	prev := s.conn
	s.mu.Unlock()

	s.setConn(connection{state: pb.ConnectionState_CONNECTION_STATE_DISCONNECTING, subID: prev.subID, nodeID: prev.nodeID, mode: prev.mode})
	s.eng.Stop()
	s.setConn(connection{state: pb.ConnectionState_CONNECTION_STATE_DISCONNECTED})

	s.mu.Lock()
	defer s.mu.Unlock()
	return s.statusLocked(), nil
}

// SelectNode switches nodes. Within the connected subscription that is
// instant (mihomo's selector); another subscription means a reconnect.
func (s *Service) SelectNode(ctx context.Context, req *pb.SelectNodeRequest) (*pb.Status, error) {
	s.mu.Lock()
	connected := s.conn.state == pb.ConnectionState_CONNECTION_STATE_CONNECTED
	sameSub := s.conn.subID == req.GetSubscriptionId()
	sub := s.findSubLocked(req.GetSubscriptionId())
	s.mu.Unlock()

	if sub == nil {
		return nil, status.Error(codes.NotFound, "no such subscription")
	}
	node, ok := sub.node(req.GetNodeId())
	if !ok {
		return nil, status.Error(codes.NotFound, "no such node")
	}

	if !connected || !sameSub {
		if !connected {
			s.mu.Lock()
			defer s.mu.Unlock()
			s.st.Last = selection{SubscriptionID: sub.ID, NodeID: node.ID}
			if err := s.store.save(s.st); err != nil {
				return nil, status.Error(codes.Internal, err.Error())
			}
			s.notifyLocked() // the client shows the selection before connecting
			return s.statusLocked(), nil
		}
		return s.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.ID, NodeId: node.ID})
	}

	s.op.Lock()
	defer s.op.Unlock()
	if err := s.eng.Select(node.Name); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.conn.nodeID = node.ID
	s.conn.check = nil
	s.startChecksLocked() // a new node: check it right away
	s.st.Last = selection{SubscriptionID: sub.ID, NodeID: node.ID}
	s.notifyLocked()
	if err := s.store.save(s.st); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	return s.statusLocked(), nil
}

// ---------- Subscriptions ----------

func (s *Service) findSubLocked(id string) *storedSub {
	for _, sub := range s.st.Subscriptions {
		if sub.ID == id {
			return sub
		}
	}
	return nil
}

func (s *Service) ListSubscriptions(context.Context, *pb.ListSubscriptionsRequest) (*pb.ListSubscriptionsResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	resp := &pb.ListSubscriptionsResponse{}
	for _, sub := range s.st.Subscriptions {
		resp.Subscriptions = append(resp.Subscriptions, s.subToProtoLocked(sub))
	}
	return resp, nil
}

func (s *Service) AddSubscription(ctx context.Context, req *pb.AddSubscriptionRequest) (*pb.Subscription, error) {
	url := req.GetUrl()
	fetched, err := s.fetcher.Fetch(ctx, url)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, scrub(err.Error(), url))
	}
	stored := toStored(url, fetched)

	s.mu.Lock()
	defer s.mu.Unlock()
	if i := slices.IndexFunc(s.st.Subscriptions, func(x *storedSub) bool { return x.ID == stored.ID }); i >= 0 {
		s.st.Subscriptions[i] = stored // adding a link twice refreshes it
	} else {
		s.st.Subscriptions = append(s.st.Subscriptions, stored)
	}
	if err := s.store.save(s.st); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	s.notifyLocked()
	return s.subToProtoLocked(stored), nil
}

func (s *Service) RefreshSubscription(ctx context.Context, req *pb.RefreshSubscriptionRequest) (*pb.Subscription, error) {
	s.mu.Lock()
	sub := s.findSubLocked(req.GetId())
	s.mu.Unlock()
	if sub == nil {
		return nil, status.Error(codes.NotFound, "no such subscription")
	}
	return s.AddSubscription(ctx, &pb.AddSubscriptionRequest{Url: sub.URL})
}

func (s *Service) RemoveSubscription(ctx context.Context, req *pb.RemoveSubscriptionRequest) (*pb.RemoveSubscriptionResponse, error) {
	s.mu.Lock()
	inUse := s.conn.subID == req.GetId() && s.conn.state != pb.ConnectionState_CONNECTION_STATE_DISCONNECTED
	s.mu.Unlock()
	if inUse {
		if _, err := s.Disconnect(ctx, &pb.DisconnectRequest{}); err != nil {
			return nil, err
		}
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.st.Subscriptions = slices.DeleteFunc(s.st.Subscriptions, func(x *storedSub) bool { return x.ID == req.GetId() })
	if s.st.Last.SubscriptionID == req.GetId() {
		s.st.Last = selection{}
	}
	if err := s.store.save(s.st); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	s.notifyLocked()
	return &pb.RemoveSubscriptionResponse{}, nil
}

// ---------- Probes ----------

func (s *Service) ProbeNodes(req *pb.ProbeNodesRequest, stream grpc.ServerStreamingServer[pb.ProbeResult]) error {
	s.mu.Lock()
	sub := s.findSubLocked(req.GetSubscriptionId())
	var nodes []storedNode
	if sub != nil {
		for _, n := range sub.Nodes {
			if len(req.GetNodeIds()) == 0 || slices.Contains(req.GetNodeIds(), n.ID) {
				nodes = append(nodes, n)
			}
		}
	}
	s.mu.Unlock()
	if sub == nil {
		return status.Error(codes.NotFound, "no such subscription")
	}

	ctx := stream.Context()
	results := make(chan *pb.ProbeResult)
	// Probes mostly wait on the network; 16 at once keeps a big subscription
	// to a few rounds of probe.Timeout at worst.
	sem := make(chan struct{}, 16)
	var wg sync.WaitGroup
	for _, n := range nodes {
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			r := toProtoProbe(n.ID, s.probe(ctx, n.Proxy))
			select {
			case results <- r:
			case <-ctx.Done():
			}
		}()
	}
	go func() { wg.Wait(); close(results) }()

	for r := range results {
		s.mu.Lock()
		s.probes[r.NodeId] = r
		s.mu.Unlock()
		if err := stream.Send(r); err != nil {
			return err
		}
	}
	return nil
}

// ---------- Settings ----------

func (s *Service) GetSettings(context.Context, *pb.GetSettingsRequest) (*pb.Settings, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return settingsToProto(s.st.Settings), nil
}

// UpdateSettings replaces all settings. If connected, the new settings apply
// right away by reconnecting to the same node.
func (s *Service) UpdateSettings(ctx context.Context, req *pb.Settings) (*pb.Settings, error) {
	set, err := settingsFromProto(req)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	s.mu.Lock()
	s.st.Settings = set
	err = s.store.save(s.st)
	conn := s.conn
	s.mu.Unlock()
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	if conn.state == pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		if _, err := s.Connect(ctx, &pb.ConnectRequest{SubscriptionId: conn.subID, NodeId: conn.nodeID}); err != nil {
			return nil, err
		}
	}
	return settingsToProto(set), nil
}

// ---------- Conversions ----------

func (s *Service) subToProtoLocked(sub *storedSub) *pb.Subscription {
	out := &pb.Subscription{
		Id:                  sub.ID,
		Title:               sub.Info.Title,
		UrlMasked:           maskURL(sub.URL),
		Format:              string(sub.Format),
		UploadBytes:         uint64(sub.Info.Upload),
		DownloadBytes:       uint64(sub.Info.Download),
		TotalBytes:          uint64(sub.Info.Total),
		UpdateIntervalHours: uint32(sub.Info.UpdateInterval / time.Hour),
		WebPage:             sub.Info.WebPage,
		Support:             sub.Info.Support,
		Announce:            sub.Info.Announce,
		FetchedAt:           timestamppb.New(sub.FetchedAt),
	}
	if !sub.Info.Expire.IsZero() {
		out.Expire = timestamppb.New(sub.Info.Expire)
	}
	for _, n := range sub.Nodes {
		typ, _ := n.Proxy["type"].(string)
		network, _ := n.Proxy["network"].(string)
		server, _ := n.Proxy["server"].(string)
		var port uint32
		fmt.Sscan(fmt.Sprint(n.Proxy["port"]), &port)
		out.Nodes = append(out.Nodes, &pb.Node{
			Id: n.ID, Name: n.Name, Type: typ, Network: network, Server: server, Port: port,
			LastProbe: s.probes[n.ID],
		})
	}
	return out
}

func toProtoProbe(nodeID string, r probe.Result) *pb.ProbeResult {
	out := &pb.ProbeResult{
		NodeId:      nodeID,
		EntryIps:    r.EntryIPs,
		ExitIp:      r.ExitIP,
		ExitCountry: r.ExitCountry,
		ExitColo:    r.ExitColo,
		LatencyMs:   uint32(r.Latency / time.Millisecond),
		ProbedAt:    timestamppb.Now(),
	}
	if r.Err != nil {
		out.Error = r.Err.Error()
	}
	return out
}

func appModeFromString(s string) (engine.AppMode, error) {
	switch s {
	case "proxy":
		return engine.AppProxy, nil
	case "bypass":
		return engine.AppBypass, nil
	case "block":
		return engine.AppBlock, nil
	}
	return 0, fmt.Errorf("unknown app mode %q", s)
}

func settingsToProto(s settings) *pb.Settings {
	out := &pb.Settings{
		TunnelMode: pb.TunnelMode_TUNNEL_MODE_SYSTEM_PROXY,
		MixedPort:  uint32(s.MixedPort),
		TunStack:   s.TunStack,
	}
	if s.TunnelMode == "tun" {
		out.TunnelMode = pb.TunnelMode_TUNNEL_MODE_TUN
	}
	for _, r := range s.AppRules {
		mode := map[string]pb.AppMode{
			"proxy": pb.AppMode_APP_MODE_PROXY, "bypass": pb.AppMode_APP_MODE_BYPASS, "block": pb.AppMode_APP_MODE_BLOCK,
		}[r.Mode]
		out.AppRules = append(out.AppRules, &pb.AppRule{App: r.App, Mode: mode})
	}
	return out
}

func settingsFromProto(p *pb.Settings) (settings, error) {
	s := settings{TunnelMode: "proxy", MixedPort: int(p.GetMixedPort()), TunStack: p.GetTunStack()}
	if p.GetTunnelMode() == pb.TunnelMode_TUNNEL_MODE_TUN {
		s.TunnelMode = "tun"
	}
	if s.MixedPort == 0 {
		s.MixedPort = defaultMixedPort
	}
	if s.MixedPort < 1024 || s.MixedPort > 65535 {
		return settings{}, fmt.Errorf("mixed port %d out of range 1024-65535", s.MixedPort)
	}
	switch s.TunStack {
	case "", "mixed", "system", "gvisor":
	default:
		return settings{}, fmt.Errorf("unknown TUN stack %q", s.TunStack)
	}
	for _, r := range p.GetAppRules() {
		var mode string
		switch r.GetMode() {
		case pb.AppMode_APP_MODE_PROXY:
			mode = "proxy"
		case pb.AppMode_APP_MODE_BYPASS:
			mode = "bypass"
		case pb.AppMode_APP_MODE_BLOCK:
			mode = "block"
		default:
			return settings{}, fmt.Errorf("app %q: mode not set", r.GetApp())
		}
		s.AppRules = append(s.AppRules, appRule{App: r.GetApp(), Mode: mode})
	}
	return s, nil
}
