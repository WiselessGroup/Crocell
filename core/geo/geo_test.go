package geo

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/component/geodata/router"
	"google.golang.org/protobuf/proto"
)

func fakeGeoIP(t *testing.T, codes ...string) []byte {
	t.Helper()
	var l router.GeoIPList
	for _, c := range codes {
		l.Entry = append(l.Entry, &router.GeoIP{CountryCode: c, Cidr: []*router.CIDR{{Ip: []byte{10, 0, 0, 0}, Prefix: 8}}})
	}
	b, err := proto.Marshal(&l)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func fakeGeoSite(t *testing.T, codes ...string) []byte {
	t.Helper()
	var l router.GeoSiteList
	for _, c := range codes {
		l.Entry = append(l.Entry, &router.GeoSite{CountryCode: c, Domain: []*router.Domain{{Value: c + ".example"}}})
	}
	b, err := proto.Marshal(&l)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestUpdateFromURLAndLocalFile(t *testing.T) {
	site := fakeGeoSite(t, "RU-BLOCKED", "youtube", "category-ads-all")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write(site)
	}))
	defer srv.Close()

	local := filepath.Join(t.TempDir(), "my-geoip.dat")
	if err := os.WriteFile(local, fakeGeoIP(t, "RU-BLOCKED", "TELEGRAM"), 0o600); err != nil {
		t.Fatal(err)
	}

	m := &Manager{Dir: t.TempDir()}
	if ip, site := m.Missing(); !ip || !site {
		t.Fatal("fresh dir should miss both files")
	}
	if err := m.Update(context.Background(), local, srv.URL+"/geosite.dat"); err != nil {
		t.Fatal(err)
	}

	info := m.Info()
	if info.GeoIPUpdated.IsZero() || info.GeoSiteUpdated.IsZero() {
		t.Error("dates missing")
	}
	if got := info.GeoIP; len(got) != 2 || got[0] != "ru-blocked" || got[1] != "telegram" {
		t.Errorf("geoip categories = %v", got)
	}
	if got := info.GeoSite; len(got) != 3 || got[2] != "youtube" {
		t.Errorf("geosite categories = %v", got)
	}
}

func TestGarbageNeverReplacesAGoodFile(t *testing.T) {
	m := &Manager{Dir: t.TempDir()}
	good := filepath.Join(t.TempDir(), "good.dat")
	_ = os.WriteFile(good, fakeGeoSite(t, "youtube"), 0o600)
	bad := filepath.Join(t.TempDir(), "bad.dat")
	_ = os.WriteFile(bad, []byte("<html>rate limited</html>"), 0o600)

	if err := m.Update(context.Background(), "/nonexistent", good); err == nil {
		t.Fatal("a missing geoip source must be reported")
	}
	if err := m.Update(context.Background(), "/nonexistent", bad); err == nil {
		t.Fatal("an HTML page must not pass as geosite.dat")
	}
	if got := m.Info().GeoSite; len(got) != 1 || got[0] != "youtube" {
		t.Errorf("the good file was replaced: %v", got)
	}
}

// What a person gets wrong when pasting a source, and what they are told.
func TestFetchExplainsBadSources(t *testing.T) {
	ip, site := fakeGeoIP(t, "ru"), fakeGeoSite(t, "youtube")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/geoip.dat":
			_, _ = w.Write(ip)
		case "/geosite.dat":
			_, _ = w.Write(site)
		case "/page":
			_, _ = w.Write([]byte("<!doctype html><title>GitHub</title>"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	m := &Manager{Dir: t.TempDir()}
	ctx := context.Background()

	if _, err := m.Fetch(ctx, GeoIPFile, srv.URL+"/geoip.dat"); err != nil {
		t.Errorf("good geoip: %v", err)
	}
	if _, err := m.Fetch(ctx, GeoIPFile, srv.URL+"/geosite.dat"); !errors.Is(err, ErrSwapped) {
		t.Errorf("geosite given as geoip: %v", err)
	}
	if _, err := m.Fetch(ctx, GeoSiteFile, srv.URL+"/geoip.dat"); !errors.Is(err, ErrSwapped) {
		t.Errorf("geoip given as geosite: %v", err)
	}
	if _, err := m.Fetch(ctx, GeoSiteFile, srv.URL+"/page"); !errors.Is(err, ErrNotDatabase) {
		t.Errorf("web page: %v", err)
	}
	var he *HTTPError
	if _, err := m.Fetch(ctx, GeoSiteFile, srv.URL+"/gone"); !errors.As(err, &he) || he.Status != 404 {
		t.Errorf("missing: %v", err)
	}
	if ip, _ := m.Missing(); !ip {
		t.Error("Fetch alone must not write anything")
	}
}

func TestNormalizeGitHubPageLinks(t *testing.T) {
	for in, want := range map[string]string{
		"https://github.com/runetfreedom/russia-v2ray-rules-dat/blob/release/geosite.dat": "https://github.com/runetfreedom/russia-v2ray-rules-dat/raw/release/geosite.dat",
		" https://example.com/geosite.dat ":                                               "https://example.com/geosite.dat",
		DefaultGeoSite:                                                                    DefaultGeoSite,
		"/home/me/geosite.dat":                                                            "/home/me/geosite.dat",
	} {
		if got := Normalize(in); got != want {
			t.Errorf("Normalize(%q) = %q, want %q", in, got, want)
		}
	}
}
