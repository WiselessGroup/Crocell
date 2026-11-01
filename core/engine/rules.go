package engine

import (
	"fmt"
	"net/netip"
	"sort"
	"strings"

	"github.com/metacubex/mihomo/component/geodata"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

// Action is where matching traffic goes.
type Action int

const (
	Proxy  Action = iota // through the selected node
	Direct               // straight out
	Block                // nowhere
)

// Kind is what a rule matches. The order is the precedence: specific
// beats general, so one site in Proxy wins over a geosite set in Direct.
type Kind int

const (
	ProcessPath    Kind = iota // /usr/bin/steam
	ProcessName                // steam; the package name on Android
	Domain                     // wiseless.net exactly
	DomainWildcard             // *.wiseless.net: subdomains only
	DomainSuffix               // wiseless.net and its subdomains (+.wiseless.net)
	IPCIDR                     // 10.0.0.0/8, 2001:db8::/32, or a single IP
	GeoSite                    // a geosite.dat category
	GeoIP                      // a geoip.dat category
)

// Rule routes matching traffic to an action.
type Rule struct {
	Kind   Kind
	Value  string
	Action Action
}

// UsesGeo reports whether any rule needs geosite.dat / geoip.dat.
func UsesGeo(rules []Rule) (geoip, geosite bool) {
	for _, r := range rules {
		geoip = geoip || r.Kind == GeoIP
		geosite = geosite || r.Kind == GeoSite
	}
	return
}

// privateNets always go direct: the router, the printer, the NAS. Not a
// user setting, nobody wants their LAN through Amsterdam.
var privateNets = []string{
	"127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
	"169.254.0.0/16", "100.64.0.0/10", "::1/128", "fc00::/7", "fe80::/10",
}

// buildRules turns rules into mihomo rule lines: LAN first, then by kind
// (specific first), within a kind Block before Direct before Proxy, and
// the final action last.
func buildRules(rules []Rule, final Action) ([]string, error) {
	sorted := make([]Rule, 0, len(rules))
	for _, r := range rules {
		v, err := normalize(r)
		if err != nil {
			return nil, err
		}
		r.Value = v
		sorted = append(sorted, r)
	}
	rank := map[Action]int{Block: 0, Direct: 1, Proxy: 2}
	sort.SliceStable(sorted, func(i, j int) bool {
		if sorted[i].Kind != sorted[j].Kind {
			return sorted[i].Kind < sorted[j].Kind
		}
		return rank[sorted[i].Action] < rank[sorted[j].Action]
	})

	out := make([]string, 0, len(privateNets)+len(sorted)+1)
	for _, n := range privateNets {
		out = append(out, "IP-CIDR,"+n+",DIRECT,no-resolve")
	}
	for _, r := range sorted {
		target := map[Action]string{Proxy: GroupName, Direct: "DIRECT", Block: "REJECT"}[r.Action]
		switch r.Kind {
		case ProcessPath:
			out = append(out, "PROCESS-PATH,"+r.Value+","+target)
		case ProcessName:
			out = append(out, "PROCESS-NAME,"+r.Value+","+target)
		case Domain:
			out = append(out, "DOMAIN,"+r.Value+","+target)
		case DomainWildcard:
			out = append(out, "DOMAIN-WILDCARD,"+r.Value+","+target)
		case DomainSuffix:
			out = append(out, "DOMAIN-SUFFIX,"+r.Value+","+target)
		case IPCIDR:
			out = append(out, "IP-CIDR,"+r.Value+","+target)
		case GeoSite:
			out = append(out, "GEOSITE,"+r.Value+","+target)
		case GeoIP:
			out = append(out, "GEOIP,"+r.Value+","+target)
		}
	}
	finalTarget := GroupName
	if final == Direct {
		finalTarget = "DIRECT"
	}
	return append(out, "MATCH,"+finalTarget), nil
}

// normalize validates a rule value and returns it in mihomo's form. Anything
// that could split a rule line (commas, newlines) is refused outright.
func normalize(r Rule) (string, error) {
	v := strings.TrimSpace(r.Value)
	if v == "" {
		return "", fmt.Errorf("engine: empty rule")
	}
	if strings.ContainsAny(v, ",\n\r") {
		return "", fmt.Errorf("engine: %q: commas and newlines are not allowed", v)
	}
	switch r.Kind {
	case ProcessPath, ProcessName:
		return v, nil
	case Domain:
		v = strings.ToLower(v)
		if !validDomain(v) {
			return "", fmt.Errorf("engine: %q is not a domain", r.Value)
		}
		return v, nil
	case DomainSuffix:
		// A whole zone is fine here: domain:ru from v2ray lists means
		// everything under .ru.
		v = strings.ToLower(strings.TrimPrefix(v, "+."))
		if !validDomain(v) && !validLabel(v) {
			return "", fmt.Errorf("engine: %q is not a domain", r.Value)
		}
		return v, nil
	case DomainWildcard:
		v = strings.ToLower(v)
		if !validDomain(strings.NewReplacer("*", "a", "?", "a").Replace(v)) {
			return "", fmt.Errorf("engine: %q is not a domain pattern", r.Value)
		}
		return v, nil
	case IPCIDR:
		if addr, err := netip.ParseAddr(v); err == nil {
			return netip.PrefixFrom(addr, addr.BitLen()).String(), nil
		}
		p, err := netip.ParsePrefix(v)
		if err != nil {
			return "", fmt.Errorf("engine: %q is not an IP or subnet", r.Value)
		}
		return p.Masked().String(), nil
	case GeoSite, GeoIP:
		v = strings.ToLower(v)
		for _, c := range v {
			if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '_' || c == '!' || c == '@' || c == ':') {
				return "", fmt.Errorf("engine: %q is not a category name", r.Value)
			}
		}
		return v, nil
	}
	return "", fmt.Errorf("engine: unknown rule kind %d", r.Kind)
}

// validLabel: one name without dots, like a top-level domain (ru, xn--p1ai).
func validLabel(l string) bool {
	if len(l) < 2 || len(l) > 63 || strings.HasPrefix(l, "-") || strings.HasSuffix(l, "-") {
		return false
	}
	for _, c := range l {
		if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c > 127) {
			return false
		}
	}
	return true
}

func validDomain(d string) bool {
	if len(d) == 0 || len(d) > 253 || !strings.Contains(d, ".") || strings.HasPrefix(d, ".") || strings.HasSuffix(d, ".") {
		return false
	}
	for _, c := range d {
		if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '.' || c > 127) {
			return false
		}
	}
	return true
}

// bypassPackages are Android packages that should not enter the tunnel at
// all, which is stronger than a DIRECT rule inside it.
func bypassPackages(rules []Rule) []string {
	var out []string
	for _, r := range rules {
		if r.Kind == ProcessName && r.Action == Direct {
			out = append(out, r.Value)
		}
	}
	return out
}

// Traffic is a snapshot of byte counters since the engine started.
type Traffic struct {
	Up, Down         int64 // total bytes
	UpRate, DownRate int64 // bytes per second, last second
}

// CurrentTraffic reads mihomo's counters.
func CurrentTraffic() Traffic {
	up, down := statistic.DefaultManager.Total()
	upRate, downRate := statistic.DefaultManager.Now()
	return Traffic{Up: up, Down: down, UpRate: upRate, DownRate: downRate}
}

// Validate checks rules the way Start would, so settings can be refused
// before they are saved.
func Validate(rules []Rule) error {
	_, err := buildRules(rules, Proxy)
	return err
}

// ReloadGeo drops mihomo's cached geo matchers, so the next Start reads
// freshly downloaded GeoIP.dat / GeoSite.dat.
func ReloadGeo() {
	geodata.ClearGeoSiteCache()
	geodata.ClearGeoIPCache()
}
