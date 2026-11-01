package daemon

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/component/geodata/router"
	"google.golang.org/protobuf/proto"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/geo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func writeGeo(t *testing.T) (ip, site string) {
	t.Helper()
	dir := t.TempDir()
	cidr := []*router.CIDR{{Ip: []byte{10, 0, 0, 0}, Prefix: 8}}
	domain := []*router.Domain{{Type: router.Domain_Domain, Value: "example.com"}}
	ipb, _ := proto.Marshal(&router.GeoIPList{Entry: []*router.GeoIP{{CountryCode: "RU-BLOCKED", Cidr: cidr}, {CountryCode: "TELEGRAM", Cidr: cidr}}})
	siteb, _ := proto.Marshal(&router.GeoSiteList{Entry: []*router.GeoSite{{CountryCode: "RU-BLOCKED", Domain: domain}, {CountryCode: "YOUTUBE", Domain: domain}}})
	ip, site = filepath.Join(dir, "ip.dat"), filepath.Join(dir, "site.dat")
	_ = os.WriteFile(ip, ipb, 0o600)
	_ = os.WriteFile(site, siteb, 0o600)
	return ip, site
}

// A new source is fetched on save: the person sees right away that the
// link works, and the sets from it are there to pick from.
func TestNewGeoSourceDownloadsOnSave(t *testing.T) {
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
	if info.GeositeUpdated == nil || len(info.GeositeCategories) != 2 || info.GeoipCategories[1] != "telegram" {
		t.Fatalf("geo info after save = %v", info)
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
}

// Files gone (fresh install, wiped state): a connect that needs them
// fetches them first.
func TestGeoRulesFetchMissingFilesBeforeConnecting(t *testing.T) {
	h := newHarness(t)
	sub := h.add(t)
	ctx := context.Background()
	ipSrc, siteSrc := writeGeo(t)
	if _, err := h.client.UpdateSettings(ctx, &pb.Settings{
		Geo:   &pb.GeoSettings{GeoipSource: ipSrc, GeositeSource: siteSrc},
		Rules: []*pb.RouteRule{{Kind: pb.RuleKind_RULE_KIND_GEOIP, Value: "telegram", Action: pb.RouteAction_ROUTE_ACTION_PROXY}},
	}); err != nil {
		t.Fatal(err)
	}
	_ = os.Remove(filepath.Join(h.dir, "engine", geo.GeoIPFile))

	st, err := h.client.Connect(ctx, &pb.ConnectRequest{SubscriptionId: sub.Id})
	if err != nil || st.State != pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		t.Fatalf("connect: %v, %v", st, err)
	}
	if info, _ := h.client.GetGeoInfo(ctx, &pb.GetGeoInfoRequest{}); info.GeoipUpdated == nil {
		t.Error("geoip.dat not fetched back")
	}
}

// A bad link is refused when saved, with a reason a person can act on, and
// nothing is saved.
func TestBadGeoSourceRefusedOnSave(t *testing.T) {
	ipSrc, siteSrc := writeGeo(t)
	page := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/gone" {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write([]byte("<!doctype html><title>GitHub</title>"))
	}))
	defer page.Close()

	for _, c := range []struct {
		name, ip, site, want string
	}{
		{"no such file", "/nonexistent/geoip.dat", "", "файла /nonexistent/geoip.dat нет"},
		{"web page", "", page.URL + "/blob/geosite.dat", "веб-страница"},
		{"404", page.URL + "/gone", "", "404"},
		{"swapped", siteSrc, ipSrc, "перепутаны"},
		{"relative path", "geoip.dat", "", "полный путь"},
	} {
		t.Run(c.name, func(t *testing.T) {
			h := newHarness(t)
			ctx := context.Background()
			_, err := h.client.UpdateSettings(ctx, &pb.Settings{Geo: &pb.GeoSettings{GeoipSource: c.ip, GeositeSource: c.site}})
			if status.Code(err) != codes.InvalidArgument || !strings.Contains(status.Convert(err).Message(), c.want) {
				t.Fatalf("got %v, want a refusal mentioning %q", err, c.want)
			}
			got, _ := h.client.GetSettings(ctx, &pb.GetSettingsRequest{})
			if got.Geo.GetGeoipSource() != "" || got.Geo.GetGeositeSource() != "" {
				t.Errorf("a refused source was saved: %v", got.Geo)
			}
		})
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
