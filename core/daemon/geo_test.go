package daemon

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/metacubex/mihomo/component/geodata/router"
	"google.golang.org/protobuf/proto"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
)

func writeGeo(t *testing.T) (ip, site string) {
	t.Helper()
	dir := t.TempDir()
	ipb, _ := proto.Marshal(&router.GeoIPList{Entry: []*router.GeoIP{{CountryCode: "RU-BLOCKED"}, {CountryCode: "TELEGRAM"}}})
	siteb, _ := proto.Marshal(&router.GeoSiteList{Entry: []*router.GeoSite{{CountryCode: "RU-BLOCKED"}, {CountryCode: "YOUTUBE"}}})
	ip, site = filepath.Join(dir, "ip.dat"), filepath.Join(dir, "site.dat")
	_ = os.WriteFile(ip, ipb, 0o600)
	_ = os.WriteFile(site, siteb, 0o600)
	return ip, site
}

func TestGeoRulesFetchFilesBeforeConnecting(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()
	ipSrc, siteSrc := writeGeo(t)

	_, err := h.client.UpdateSettings(ctx, &pb.Settings{
		Geo:   &pb.GeoSettings{GeoipSource: ipSrc, GeositeSource: siteSrc},
		Rules: []*pb.RouteRule{{Kind: pb.RuleKind_RULE_KIND_GEOSITE, Value: "ru-blocked", Action: pb.RouteAction_ROUTE_ACTION_PROXY}},
	})
	if err != nil {
		t.Fatal(err)
	}

	info, _ := h.client.GetGeoInfo(ctx, &pb.GetGeoInfoRequest{})
	if info.GeositeUpdated != nil {
		t.Fatal("nothing should be downloaded before it is needed")
	}

	st, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.State != pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		t.Fatalf("status = %v", st)
	}
	if r := h.eng.last().Rules; len(r) != 1 || r[0].Kind != engine.GeoSite {
		t.Errorf("rules = %+v", r)
	}

	info, _ = h.client.GetGeoInfo(ctx, &pb.GetGeoInfoRequest{})
	if info.GeositeUpdated == nil || len(info.GeositeCategories) != 2 || info.GeoipCategories[1] != "telegram" {
		t.Errorf("geo info = %v", info)
	}
}

func TestBrokenGeoSourceFailsConnectWithReason(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()
	_, err := h.client.UpdateSettings(ctx, &pb.Settings{
		Geo:   &pb.GeoSettings{GeoipSource: "/nonexistent/geoip.dat", GeositeSource: "/nonexistent/geosite.dat"},
		Rules: []*pb.RouteRule{{Kind: pb.RuleKind_RULE_KIND_GEOIP, Value: "telegram", Action: pb.RouteAction_ROUTE_ACTION_PROXY}},
	})
	if err != nil {
		t.Fatal(err)
	}
	st, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id})
	if err != nil {
		t.Fatal(err)
	}
	if st.State != pb.ConnectionState_CONNECTION_STATE_FAILED || st.Error == "" {
		t.Errorf("want a failed connect explaining the databases, got %v", st)
	}
	info, _ := h.client.GetGeoInfo(ctx, &pb.GetGeoInfoRequest{})
	if info.Error == "" {
		t.Error("GeoInfo should carry the update error")
	}
}

func TestListProcesses(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("linux /proc")
	}
	h := newHarness(t)
	resp, err := h.client.ListProcesses(context.Background(), &pb.ListProcessesRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if len(resp.Processes) == 0 {
		t.Error("no processes")
	}
}
