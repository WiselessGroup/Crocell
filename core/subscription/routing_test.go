package subscription

import (
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"net/http/httptest"
	"slices"
	"testing"
)

// A made-up profile in Happ's format, with a bit of everything.
const happJSON = `{
  "Name": "Россия напрямую",
  "GlobalProxy": "true",
  "RemoteDNSType": "DoH", "RemoteDNSDomain": "https://dns.example.invalid/dns-query", "RemoteDNSIP": "192.0.2.1",
  "DomesticDNSType": "DoU", "DomesticDNSDomain": "", "DomesticDNSIP": "192.0.2.53",
  "Geoipurl": "https://geo.example.invalid/geoip.dat",
  "Geositeurl": "http://geo.example.invalid/geosite.dat",
  "DnsHosts": {"a.example.invalid": "192.0.2.7"},
  "DirectSites": ["geosite:category-gov-ru", "domain:Bank.Example", "full:exact.example", "plain.example", "regexp:.*\\.ru$", "geosite:ru@cn", "geosite:youtube"],
  "DirectIp": ["geoip:private", "198.51.100.0/24", "203.0.113.9", "geoip:!ru", "ext:x.dat:y"],
  "ProxySites": ["geosite:youtube", "keyword:tube"],
  "ProxyIp": [],
  "BlockSites": ["geosite:category-ads"],
  "BlockIp": [],
  "DomainStrategy": "IPIfNonMatch",
  "FakeDNS": false,
  "LastUpdated": 1794320115
}`

func happLink(json string) string {
	return "happ://routing/onadd/" + base64.StdEncoding.EncodeToString([]byte(json))
}

func TestParseRouting(t *testing.T) {
	r, err := ParseRouting(happLink(happJSON))
	if err != nil {
		t.Fatal(err)
	}
	if r.Name != "Россия напрямую" || r.Updated != "1794320115" || r.Final != "proxy" {
		t.Errorf("profile = %q %q %q", r.Name, r.Updated, r.Final)
	}
	want := []RouteRule{
		{"geosite", "category-ads", "block"},
		{"geosite", "youtube", "proxy"}, // proxy wins over the same set in direct
		{"geosite", "category-gov-ru", "direct"},
		{"domain_suffix", "bank.example", "direct"},
		{"domain", "exact.example", "direct"},
		{"domain_suffix", "plain.example", "direct"},
		{"geoip", "private", "direct"},
		{"ip_cidr", "198.51.100.0/24", "direct"},
		{"ip_cidr", "203.0.113.9", "direct"},
	}
	if !slices.Equal(r.Rules, want) {
		t.Errorf("rules:\n got %v\nwant %v", r.Rules, want)
	}
	for _, u := range []string{`regexp:.*\.ru$`, "geosite:ru@cn", "geoip:!ru", "ext:x.dat:y", "keyword:tube", "DnsHosts"} {
		if !slices.Contains(r.Unsupported, u) {
			t.Errorf("unsupported misses %q: %v", u, r.Unsupported)
		}
	}
	if !slices.Equal(r.DNS, []string{"https://dns.example.invalid/dns-query"}) || !slices.Equal(r.DirectDNS, []string{"192.0.2.53"}) {
		t.Errorf("dns = %v / %v", r.DNS, r.DirectDNS)
	}
	if r.GeoIP != "https://geo.example.invalid/geoip.dat" || r.GeoSite != "" {
		t.Errorf("geo = %q %q: only https is taken", r.GeoIP, r.GeoSite)
	}
}

func TestParseRoutingForms(t *testing.T) {
	const min = `{"Name":"n","GlobalProxy":false,"DirectSites":["geosite:ru-available-only-inside"]}`
	raw := base64.RawURLEncoding.EncodeToString([]byte(min))
	for _, in := range []string{
		happLink(min),
		"happ://routing/add/" + raw,
		"INCY://routing/onadd/" + raw + "/",
		"v2raytun://routing/onadd/" + raw,
		raw, // INCY's header may carry the bare base64
	} {
		r, err := ParseRouting(in)
		if err != nil {
			t.Errorf("%.40s: %v", in, err)
			continue
		}
		if r.Final != "direct" || len(r.Rules) != 1 {
			t.Errorf("%.40s: %+v", in, r)
		}
	}

	for in, want := range map[string]error{
		"happ://routing/off":             ErrRoutingOff,
		"happ://routing/delete/abc":      ErrRoutingUnknown,
		"https://sub.example.invalid/x":  ErrNotRouting,
		"happ://routing/onadd/%%%":       ErrRoutingDamaged,
		happLink("not json"):             ErrRoutingDamaged,
		"happ://routing/onadd/":          ErrRoutingDamaged,
		"vless://00000000@h.invalid:1#n": ErrNotRouting,
	} {
		if _, err := ParseRouting(in); !errors.Is(err, want) {
			t.Errorf("%q: err = %v, want %v", in, err, want)
		}
	}
	if !IsRoutingLink("happ://routing/onadd/x") || IsRoutingLink("https://routing.example/x") {
		t.Error("IsRoutingLink")
	}
}

func TestSubscriptionOffersRouting(t *testing.T) {
	const profile = `{"Name":"Провайдер","DirectSites":["geosite:category-bank-ru"]}`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/header":
			w.Header().Set("routing", happLink(profile))
			w.Header().Set("per-app-proxy-mode", "bypass")
			w.Header().Set("per-app-proxy-list", "ru.example.bank, com.example.shop,not a package")
		case "/body":
			w.Write([]byte(happLink(profile) + "\n"))
		case "/apps":
			w.Header().Set("profile-title", "Мой VPN")
			w.Write([]byte("#per-app-proxy-mode: bypass\n#per-app-proxy-list: ru.example.bank\n"))
		case "/broken":
			w.Header().Set("routing", "happ://routing/onadd/%%%")
		}
		w.Write([]byte(vlessSample))
	}))
	defer srv.Close()
	f := &Fetcher{}

	sub, err := f.Fetch(context.Background(), srv.URL+"/header")
	if err != nil {
		t.Fatal(err)
	}
	r := sub.Info.Routing
	if r == nil || r.Name != "Провайдер" || len(r.Rules) != 3 {
		t.Fatalf("header routing = %+v", r)
	}
	if r.Rules[1] != (RouteRule{"process_name", "ru.example.bank", "direct"}) {
		t.Errorf("apps = %v", r.Rules[1:])
	}

	sub, err = f.Fetch(context.Background(), srv.URL+"/body")
	if err != nil || sub.Info.Routing == nil || len(sub.Nodes) != 1 {
		t.Fatalf("body routing: %v, %+v, %d nodes", err, sub.Info.Routing, len(sub.Nodes))
	}

	sub, err = f.Fetch(context.Background(), srv.URL+"/apps")
	if err != nil || sub.Info.Routing == nil || sub.Info.Routing.Name != "Мой VPN" || len(sub.Info.Routing.Rules) != 1 {
		t.Fatalf("apps only: %v, %+v", err, sub.Info.Routing)
	}

	// A broken profile costs the offer, not the nodes.
	sub, err = f.Fetch(context.Background(), srv.URL+"/broken")
	if err != nil || sub.Info.Routing != nil || len(sub.Nodes) != 1 {
		t.Fatalf("broken: %v, %+v", err, sub.Info.Routing)
	}
}
