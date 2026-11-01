package daemon

import (
	"context"
	"slices"
	"sync"
	"testing"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
)

type fakeTun struct {
	mu     sync.Mutex
	opened []TunRequest
	closed int
}

func (f *fakeTun) Open(r TunRequest) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.opened = append(f.opened, r)
	return 42, nil
}

func (f *fakeTun) Close() { f.mu.Lock(); f.closed++; f.mu.Unlock() }

// Android: the platform builds the interface, program rules become the
// interface's package lists, and the app itself stays outside.
func TestAndroidConnectsThroughVpnService(t *testing.T) {
	tun := &fakeTun{}
	h := newHarness(t, func(c *Config) { c.Tun, c.Package = tun, "net.wiseless.crocell" })
	sub := h.add(t)
	ctx := context.Background()

	set, _ := h.client.GetSettings(ctx, &pb.GetSettingsRequest{})
	set.Rules = append(set.Rules,
		&pb.RouteRule{Kind: pb.RuleKind_RULE_KIND_PROCESS_NAME, Value: "ru.sberbankmobile", Action: pb.RouteAction_ROUTE_ACTION_DIRECT},
		&pb.RouteRule{Kind: pb.RuleKind_RULE_KIND_DOMAIN_SUFFIX, Value: "ru", Action: pb.RouteAction_ROUTE_ACTION_DIRECT},
	)
	if _, err := h.client.UpdateSettings(ctx, set); err != nil {
		t.Fatal(err)
	}

	st, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.TunnelMode != pb.TunnelMode_TUNNEL_MODE_TUN {
		t.Errorf("mode = %v, Android has only the tunnel", st.TunnelMode)
	}
	opts := h.eng.last()
	if opts.Tun == nil || opts.Tun.FileDescriptor != 42 {
		t.Fatalf("engine TUN = %+v, want the fd from VpnService", opts.Tun)
	}
	for _, r := range opts.Rules {
		if r.Value == "ru.sberbankmobile" {
			t.Error("program rule reached the engine, where it can never match")
		}
	}
	if len(tun.opened) != 1 || !slices.Equal(tun.opened[0].Disallow, []string{"net.wiseless.crocell", "ru.sberbankmobile"}) {
		t.Errorf("interface request = %+v", tun.opened)
	}

	if _, err := h.client.Disconnect(ctx, &pb.DisconnectRequest{}); err != nil {
		t.Fatal(err)
	}
	if tun.closed == 0 {
		t.Error("disconnect left the VPN up")
	}

	set.Rules = append(set.Rules,
		&pb.RouteRule{Kind: pb.RuleKind_RULE_KIND_PROCESS_NAME, Value: "com.vk", Action: pb.RouteAction_ROUTE_ACTION_BLOCK})
	if _, err := h.client.UpdateSettings(ctx, set); err == nil {
		t.Error("a blocked app was accepted on Android")
	}
}

// Everything else direct, a few apps through the VPN: only those apps get
// the interface.
func TestAndroidOnlyChosenAppsWhenFinalIsDirect(t *testing.T) {
	rules := []engine.Rule{
		{Kind: engine.ProcessName, Value: "org.telegram.messenger", Action: engine.Proxy},
		{Kind: engine.ProcessName, Value: "ru.sberbankmobile", Action: engine.Direct},
	}
	r := tunRequest(rules, engine.Direct, false, "self")
	if !slices.Equal(r.Allow, []string{"org.telegram.messenger"}) || r.Disallow != nil || r.Address6 != "" {
		t.Errorf("request = %+v", r)
	}
	r = tunRequest(rules, engine.Proxy, true, "self")
	if r.Allow != nil || !slices.Equal(r.Disallow, []string{"self", "ru.sberbankmobile"}) || r.Address6 == "" {
		t.Errorf("request = %+v", r)
	}
}
