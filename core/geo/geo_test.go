package geo

import (
	"context"
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
		l.Entry = append(l.Entry, &router.GeoIP{CountryCode: c})
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
		l.Entry = append(l.Entry, &router.GeoSite{CountryCode: c})
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

	if err := m.fetch(context.Background(), good, GeoSiteFile, countGeoSite); err != nil {
		t.Fatal(err)
	}
	if err := m.fetch(context.Background(), bad, GeoSiteFile, countGeoSite); err == nil {
		t.Fatal("an HTML page must not pass as geosite.dat")
	}
	if got := m.Info().GeoSite; len(got) != 1 || got[0] != "youtube" {
		t.Errorf("the good file was replaced: %v", got)
	}
}
