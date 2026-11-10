package daemon

import (
	"context"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
)

const routingProfile = `{"Name":"Россия напрямую","GlobalProxy":"false","DirectSites":["geosite:category-gov-ru","regexp:x"],"DirectIp":["geoip:private"],"Geoipurl":"https://geo.example.invalid/geoip.dat"}`

func TestReadRouting(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()
	p, err := h.client.ReadRouting(ctx, &pb.ReadRoutingRequest{
		Text: "happ://routing/onadd/" + base64.StdEncoding.EncodeToString([]byte(routingProfile)),
	})
	if err != nil {
		t.Fatal(err)
	}
	if p.GetName() != "Россия напрямую" || len(p.GetRules()) != 2 || p.GetFinalAction() != pb.RouteAction_ROUTE_ACTION_DIRECT {
		t.Fatalf("profile = %v", p)
	}
	for _, r := range p.GetRules() {
		if r.GetGroup() != "Россия напрямую" || r.GetAction() != pb.RouteAction_ROUTE_ACTION_DIRECT {
			t.Errorf("rule = %v", r)
		}
	}
	if len(p.GetUnsupported()) != 1 || p.GetGeo().GetGeoipSource() == "" {
		t.Errorf("unsupported %v, geo %v", p.GetUnsupported(), p.GetGeo())
	}

	// The rules go into Settings as they are, and keep their group.
	set, err := h.client.GetSettings(ctx, &pb.GetSettingsRequest{})
	if err != nil {
		t.Fatal(err)
	}
	set.Rules = append(set.Rules, p.GetRules()...)
	if set, err = h.client.UpdateSettings(ctx, set); err != nil {
		t.Fatal(err)
	}
	groups := 0
	for _, r := range set.GetRules() {
		if r.GetGroup() == "Россия напрямую" {
			groups++
		}
	}
	if groups != 2 {
		t.Errorf("rules with the group after saving: %d, want 2", groups)
	}

	_, err = h.client.ReadRouting(ctx, &pb.ReadRoutingRequest{Text: "happ://routing/off"})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("off link: %v", err)
	}
}

func TestSubscriptionCarriesRouting(t *testing.T) {
	h := newHarness(t)
	web := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("routing", "happ://routing/onadd/"+base64.StdEncoding.EncodeToString([]byte(routingProfile)))
		w.Write([]byte("vless://00000000-0000-4000-8000-000000000002@relay.example.com:443?type=tcp&security=tls&sni=relay.example.com#n"))
	}))
	t.Cleanup(web.Close)

	sub, err := h.client.AddSubscription(context.Background(), &pb.AddSubscriptionRequest{Url: web.URL + "/sub/x"})
	if err != nil {
		t.Fatal(err)
	}
	if r := sub.GetRouting(); r.GetName() != "Россия напрямую" || len(r.GetRules()) != 2 {
		t.Fatalf("routing = %v", r)
	}
	// Offered, not applied.
	set, _ := h.client.GetSettings(context.Background(), &pb.GetSettingsRequest{})
	for _, r := range set.GetRules() {
		if r.GetGroup() != "" {
			t.Fatalf("a rule was applied without asking: %v", r)
		}
	}
	// The list shows it too: it is kept with the subscription.
	list, err := h.client.ListSubscriptions(context.Background(), &pb.ListSubscriptionsRequest{})
	if err != nil || list.GetSubscriptions()[0].GetRouting() == nil {
		t.Fatalf("listed: %v %v", err, list)
	}
}
