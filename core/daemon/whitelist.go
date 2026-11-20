package daemon

import (
	"net"
	"net/netip"
	"strings"
	"sync"
	"unicode"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/diagnose"
)

// whitelistHint says how likely a node gets through a mobile network in
// whitelist mode. The provider's own label in the name is the strongest
// sign. Without it, an allowed SNI or an entry in Russia alone is a hint,
// and the two together make the node likely.
func whitelistHint(name string, proxy map[string]any, entryIPs []string, ru func(netip.Addr) bool) pb.WhitelistHint {
	if markedWhitelist(name) {
		return pb.WhitelistHint_WHITELIST_HINT_MARKED
	}
	sni := allowedSNI(proxy)
	entry := russianEntry(proxy, entryIPs, ru)
	switch {
	case sni && entry:
		return pb.WhitelistHint_WHITELIST_HINT_LIKELY
	case sni || entry:
		return pb.WhitelistHint_WHITELIST_HINT_WEAK
	}
	return pb.WhitelistHint_WHITELIST_HINT_UNSPECIFIED
}

// markedWhitelist looks for the labels providers put in node names, as
// whole words: "БС" inside "Обсерватория" is not one.
func markedWhitelist(name string) bool {
	words := strings.FieldsFunc(strings.ToLower(name), func(r rune) bool { return !unicode.IsLetter(r) })
	for i, w := range words {
		switch w {
		case "бс", "wl", "whitelist", "whitelisted":
			return true
		case "белый", "белые", "белого", "белых", "white":
			if i+1 < len(words) && (strings.HasPrefix(words[i+1], "спис") || words[i+1] == "list") {
				return true
			}
		}
	}
	return false
}

var whitelistSNI = sync.OnceValue(func() map[string]bool {
	set := map[string]bool{}
	for _, h := range diagnose.WhitelistSNI() {
		set[strings.ToLower(h)] = true
	}
	return set
})

// allowedSNI: the server name a Reality or TLS node shows the network is
// one a whitelist lets through, or a subdomain of one.
func allowedSNI(proxy map[string]any) bool {
	set := whitelistSNI()
	for _, key := range []string{"servername", "sni"} {
		name, _ := proxy[key].(string)
		name = strings.TrimSuffix(strings.ToLower(name), ".")
		for name != "" {
			if set[name] {
				return true
			}
			_, rest, ok := strings.Cut(name, ".")
			if !ok || !strings.Contains(rest, ".") {
				break
			}
			name = rest
		}
	}
	return false
}

// russianEntry: the node is entered in Russia, by its address (when the
// geoip file is there to tell) or by a Russian domain.
func russianEntry(proxy map[string]any, entryIPs []string, ru func(netip.Addr) bool) bool {
	server, _ := proxy["server"].(string)
	host := strings.TrimSuffix(strings.ToLower(server), ".")
	for _, tld := range []string{".ru", ".su", ".xn--p1ai", ".рф"} {
		if strings.HasSuffix(host, tld) {
			return true
		}
	}
	if ru == nil {
		return false
	}
	ips := entryIPs
	if net.ParseIP(server) != nil {
		ips = append([]string{server}, ips...)
	}
	for _, s := range ips {
		if a, err := netip.ParseAddr(s); err == nil && ru(a.Unmap()) {
			return true
		}
	}
	return false
}

// ruMatcher is nil when there is no geoip file to tell by.
func ruMatcher(prefixes []netip.Prefix) func(netip.Addr) bool {
	if len(prefixes) == 0 {
		return nil
	}
	return func(a netip.Addr) bool {
		for _, p := range prefixes {
			if p.Contains(a) {
				return true
			}
		}
		return false
	}
}
