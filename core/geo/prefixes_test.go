package geo

import (
	"net/netip"
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/component/geodata/router"
	"google.golang.org/protobuf/proto"
)

func TestPrefixesOfOneCountry(t *testing.T) {
	l := router.GeoIPList{Entry: []*router.GeoIP{
		{CountryCode: "NL", Cidr: []*router.CIDR{{Ip: []byte{198, 51, 100, 0}, Prefix: 24}}},
		{CountryCode: "RU", Cidr: []*router.CIDR{
			{Ip: []byte{203, 0, 113, 0}, Prefix: 24},
			{Ip: netip.MustParseAddr("2001:db8::").AsSlice(), Prefix: 32},
		}},
	}}
	b, err := proto.Marshal(&l)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	m := &Manager{Dir: dir}
	if p := m.Prefixes("ru"); p != nil {
		t.Errorf("no file, got %v", p)
	}
	if err := os.WriteFile(filepath.Join(dir, GeoIPFile), b, 0o600); err != nil {
		t.Fatal(err)
	}
	got := m.Prefixes("ru")
	want := []netip.Prefix{netip.MustParsePrefix("203.0.113.0/24"), netip.MustParsePrefix("2001:db8::/32")}
	if len(got) != 2 || got[0] != want[0] || got[1] != want[1] {
		t.Errorf("got %v, want %v", got, want)
	}
}
