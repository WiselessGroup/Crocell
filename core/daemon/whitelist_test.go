package daemon

import (
	"net/netip"
	"testing"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
)

// Names are made up; real ones stay in testdata/private.
func TestWhitelistLabels(t *testing.T) {
	for name, want := range map[string]bool{
		"🇷🇺 Москва БС":        true,
		"Moscow | WL #2":      true,
		"de-whitelist-01":     true,
		"Для белых списков":   true,
		"Белый список, МТС":   true,
		"White list Beeline":  true,
		"Обсерватория":        false,
		"nlWISELESS":          false,
		"Нидерланды, быстрый": false,
		"Белый кролик":        false,
	} {
		if got := markedWhitelist(name); got != want {
			t.Errorf("%q: %v, want %v", name, got, want)
		}
	}
}

func TestWhitelistHintLevels(t *testing.T) {
	ru := ruMatcher([]netip.Prefix{netip.MustParsePrefix("203.0.113.0/24")})
	reality := func(sni, server string) map[string]any {
		return map[string]any{"type": "vless", "server": server, "port": 443, "servername": sni}
	}
	cases := []struct {
		name  string
		proxy map[string]any
		entry []string
		want  pb.WhitelistHint
	}{
		{"Франкфурт", reality("www.microsoft.com", "198.51.100.1"), nil, pb.WhitelistHint_WHITELIST_HINT_UNSPECIFIED},
		{"Москва БС", reality("www.microsoft.com", "198.51.100.1"), nil, pb.WhitelistHint_WHITELIST_HINT_MARKED},
		{"Москва", reality("vk.com", "198.51.100.1"), nil, pb.WhitelistHint_WHITELIST_HINT_WEAK},
		{"Москва", reality("api.vk.com", "203.0.113.5"), nil, pb.WhitelistHint_WHITELIST_HINT_LIKELY},
		{"Москва", reality("yandex.ru", "relay.example.com"), []string{"203.0.113.9"}, pb.WhitelistHint_WHITELIST_HINT_LIKELY},
		{"Москва", reality("www.microsoft.com", "relay.example.ru"), nil, pb.WhitelistHint_WHITELIST_HINT_WEAK},
	}
	for _, c := range cases {
		if got := whitelistHint(c.name, c.proxy, c.entry, ru); got != c.want {
			t.Errorf("%s %v: %v, want %v", c.name, c.proxy, got, c.want)
		}
	}
	// No geoip file: the address says nothing, the domain still does.
	if got := whitelistHint("x", reality("example.org", "203.0.113.5"), nil, nil); got != pb.WhitelistHint_WHITELIST_HINT_UNSPECIFIED {
		t.Errorf("without geoip: %v", got)
	}
}
