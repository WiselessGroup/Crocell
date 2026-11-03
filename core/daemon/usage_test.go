package daemon

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
)

// clock is a time the test moves by hand.
type clock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *clock) now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *clock) advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.t = c.t.Add(d)
}

func newClockHarness(t *testing.T) (*harness, *clock) {
	t.Helper()
	clk := &clock{t: time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)}
	return newHarness(t, func(c *Config) { c.Now = clk.now }), clk
}

// use connects to the node and stays for d with the check passing.
func (h *harness) use(t *testing.T, clk *clock, sub *pb.Subscription, node *pb.Node, d time.Duration) {
	t.Helper()
	ctx := context.Background()
	if _, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.GetId(), NodeId: node.GetId()}); err != nil {
		t.Fatal(err)
	}
	waitStatus(t, h, func(st *pb.Status) bool { return st.GetNodeId() == node.GetId() && st.GetLiveCheck() != nil })
	clk.advance(d)
	if _, err := h.client.Disconnect(ctx, &pb.DisconnectRequest{}); err != nil {
		t.Fatal(err)
	}
}

func favoriteNames(t *testing.T, h *harness) []string {
	t.Helper()
	st, err := h.client.GetStatus(context.Background(), &pb.GetStatusRequest{})
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, f := range st.GetFavorites() {
		names = append(names, f.GetName())
	}
	return names
}

func TestFavoritesByTimeNotByCount(t *testing.T) {
	h, clk := newClockHarness(t)
	sub := h.add(t)
	a, b := sub.GetNodes()[0], sub.GetNodes()[1]

	// Three short visits lose to one long stay.
	for range 3 {
		h.use(t, clk, sub, a, time.Minute)
	}
	h.use(t, clk, sub, b, time.Hour)

	if got := favoriteNames(t, h); !slices.Equal(got, []string{b.GetName(), a.GetName()}) {
		t.Errorf("favorites = %q", got)
	}
}

func TestFavoritesTieGoesToTheLatest(t *testing.T) {
	h, clk := newClockHarness(t)
	sub := h.add(t)
	a, b := sub.GetNodes()[0], sub.GetNodes()[1]
	h.use(t, clk, sub, a, time.Minute)
	h.use(t, clk, sub, b, time.Minute)
	if got := favoriteNames(t, h); !slices.Equal(got, []string{b.GetName(), a.GetName()}) {
		t.Errorf("favorites = %q", got)
	}
}

func TestFailingNodeEarnsNoTime(t *testing.T) {
	h, clk := newClockHarness(t)
	sub := h.add(t)
	h.setCheckErr(errors.New("probe: context deadline exceeded"))
	h.use(t, clk, sub, sub.GetNodes()[0], time.Hour)
	if got := favoriteNames(t, h); len(got) != 0 {
		t.Errorf("favorites = %q", got)
	}
}

func TestFavoritesAreAtMostFour(t *testing.T) {
	h, clk := newClockHarness(t)
	sub := h.add(t)
	nodes := sub.GetNodes()
	if len(nodes) < 5 {
		t.Skipf("fixture has %d nodes", len(nodes))
	}
	for i, n := range nodes[:5] {
		h.use(t, clk, sub, n, time.Duration(i+1)*time.Minute)
	}
	got := favoriteNames(t, h)
	if len(got) != favoriteCount || got[0] != nodes[4].GetName() {
		t.Errorf("favorites = %q", got)
	}
}

func TestUsageSurvivesARestart(t *testing.T) {
	h, clk := newClockHarness(t)
	sub := h.add(t)
	h.use(t, clk, sub, sub.GetNodes()[0], time.Hour)

	again, err := New(Config{StateDir: h.dir, Engine: h.eng})
	if err != nil {
		t.Fatal(err)
	}
	if got := again.favoritesLocked(); len(got) != 1 || got[0].GetNodeId() != sub.GetNodes()[0].GetId() {
		t.Errorf("favorites = %v", got)
	}
}

func TestUsageIsForgottenWithTheNode(t *testing.T) {
	h, clk := newClockHarness(t)
	sub := h.add(t)
	h.use(t, clk, sub, sub.GetNodes()[0], time.Hour)
	if len(favoriteNames(t, h)) != 1 {
		t.Fatal("no favorite to forget")
	}
	if _, err := h.client.RemoveSubscription(context.Background(), &pb.RemoveSubscriptionRequest{Id: sub.GetId()}); err != nil {
		t.Fatal(err)
	}
	h.add(t)
	if got := favoriteNames(t, h); len(got) != 0 {
		t.Errorf("favorites after removal = %q", got)
	}
}

func TestForgetUsageKeepsWhatIsStillThere(t *testing.T) {
	s := &Service{st: &state{Usage: map[string]nodeUsage{
		"s1/stays": {Connected: time.Hour},
		"s1/gone":  {Connected: time.Hour},
		"s2/gone":  {Connected: time.Hour},
	}}}
	s.forgetUsageLocked("s1", []storedNode{{ID: "stays"}})
	if len(s.st.Usage) != 2 || s.st.Usage["s1/gone"].Connected != 0 || s.st.Usage["s2/gone"].Connected == 0 {
		t.Errorf("usage = %v", s.st.Usage)
	}
}

func TestRefreshAllGoesOnAfterAFailure(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()
	h.add(t)

	var broken atomic.Bool
	flaky := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if broken.Load() {
			w.WriteHeader(http.StatusBadGateway)
			return
		}
		_, _ = w.Write([]byte("trojan://secret@tr.example.net:443#Flaky"))
	}))
	defer flaky.Close()
	if _, err := h.client.AddSubscription(ctx, &pb.AddSubscriptionRequest{Url: flaky.URL + "/token-abcdef-123456"}); err != nil {
		t.Fatal(err)
	}
	// Pasted by hand: nothing to fetch, so neither a refresh nor a failure.
	if _, err := h.client.AddSubscription(ctx, &pb.AddSubscriptionRequest{Url: "trojan://secret@pasted.example.net:443#Pasted"}); err != nil {
		t.Fatal(err)
	}

	broken.Store(true)
	resp, err := h.client.RefreshAllSubscriptions(ctx, &pb.RefreshAllSubscriptionsRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if resp.GetRefreshed() != 1 || len(resp.GetFailed()) != 1 {
		t.Fatalf("resp = %v", resp)
	}
	if msg := resp.GetFailed()[0].GetError(); strings.Contains(msg, "token-abcdef") {
		t.Errorf("the link leaked: %q", msg)
	}
}

func TestShutdownTellsTheClientsThenEnds(t *testing.T) {
	var quit atomic.Bool
	h := newHarness(t, func(c *Config) { c.Shutdown = func() { quit.Store(true) } })
	ctx := context.Background()
	if _, err := h.client.Shutdown(ctx, &pb.ShutdownRequest{}); err != nil {
		t.Fatal(err)
	}
	st, err := h.client.GetStatus(ctx, &pb.GetStatusRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if !st.GetQuitting() {
		t.Error("status does not say it is quitting")
	}
	waitFor(t, "the process to be told to end", quit.Load)
}

func TestNoShutdownInsideTheApp(t *testing.T) {
	h := newHarness(t)
	if _, err := h.client.Shutdown(context.Background(), &pb.ShutdownRequest{}); err == nil {
		t.Error("nothing to stop here, yet it agreed")
	}
}
