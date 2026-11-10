package subscription

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/netip"
	"regexp"
	"strings"
)

// Routing is a routing profile in the format Happ made common and INCY
// shares: happ://routing/onadd/<base64 JSON>, or the same in a
// subscription's "routing" header. https://www.happ.su/main/dev-docs/routing
//
// It is an offer. Nothing here changes a setting: the client shows it and
// applies what the person agrees to. See ADR-0004.
type Routing struct {
	Name    string `json:"name"`
	Updated string `json:"updated,omitempty"` // LastUpdated, unix seconds as sent
	// Rules use the daemon's names: geosite, geoip, domain, domain_suffix,
	// ip_cidr, process_name; actions proxy, direct, block.
	Rules []RouteRule `json:"rules,omitempty"`
	// Final is where everything else goes: "proxy", "direct", or "" when
	// the profile does not say.
	Final     string   `json:"final,omitempty"`
	DNS       []string `json:"dns,omitempty"`        // through the VPN
	DirectDNS []string `json:"direct_dns,omitempty"` // for direct traffic
	GeoIP     string   `json:"geoip,omitempty"`      // .dat sources
	GeoSite   string   `json:"geosite,omitempty"`
	// What the profile asks for that Crocell can't do, as written there.
	Unsupported []string `json:"unsupported,omitempty"`
}

type RouteRule struct {
	Kind   string `json:"kind"`
	Value  string `json:"value"`
	Action string `json:"action"`
}

// Errors of ParseRouting. They never quote the link; the daemon words them
// for the person.
var (
	ErrNotRouting     = errors.New("subscription: not a routing link")
	ErrRoutingOff     = errors.New("subscription: this routing link turns routing off")
	ErrRoutingUnknown = errors.New("subscription: unknown kind of routing link")
	ErrRoutingDamaged = errors.New("subscription: the routing link is damaged or cut short")
)

// maxRouting caps a decoded profile. Real ones are a couple of KB.
const maxRouting = 1 << 20

// routingLink: <any scheme>://routing/<add|onadd|off>[/<payload>]. INCY
// takes any scheme, so do we.
var routingLink = regexp.MustCompile(`(?i)^([a-z][a-z0-9+.-]*)://routing/([a-z]+)/?(.*)$`)

// IsRoutingLink tells a routing link from a subscription or node link.
func IsRoutingLink(s string) bool {
	return routingLink.MatchString(strings.TrimSpace(s))
}

// ParseRouting reads a routing link, or the bare base64 that INCY also
// accepts in the header. Errors never quote the input.
func ParseRouting(s string) (*Routing, error) {
	s = strings.TrimSpace(s)
	payload := s
	if m := routingLink.FindStringSubmatch(s); m != nil {
		switch strings.ToLower(m[2]) {
		case "add", "onadd":
			payload = m[3]
		case "off":
			return nil, ErrRoutingOff
		default:
			return nil, ErrRoutingUnknown
		}
	} else if strings.Contains(s, "://") {
		return nil, ErrNotRouting
	}

	raw, err := decodeBase64Any(strings.TrimRight(strings.TrimSpace(payload), "/"))
	if err != nil || len(raw) == 0 {
		return nil, ErrRoutingDamaged
	}
	if len(raw) > maxRouting {
		return nil, ErrRoutingDamaged
	}
	var p happProfile
	if err := json.Unmarshal(raw, &p); err != nil {
		return nil, ErrRoutingDamaged
	}
	return p.toRouting(), nil
}

func decodeBase64Any(s string) ([]byte, error) {
	var err error
	for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
		var b []byte
		if b, err = enc.DecodeString(s); err == nil {
			return b, nil
		}
	}
	return nil, err
}

// flag is Happ's "true"/"false", which some generators write as a bool.
type flag string

func (f *flag) UnmarshalJSON(b []byte) error {
	var v any
	if err := json.Unmarshal(b, &v); err != nil {
		return err
	}
	switch x := v.(type) {
	case bool:
		*f = flag(map[bool]string{true: "true", false: "false"}[x])
	case string:
		*f = flag(strings.ToLower(strings.TrimSpace(x)))
	}
	return nil
}

type happProfile struct {
	Name              string            `json:"Name"`
	GlobalProxy       flag              `json:"GlobalProxy"`
	RemoteDNSType     string            `json:"RemoteDNSType"`
	RemoteDNSDomain   string            `json:"RemoteDNSDomain"`
	RemoteDNSIP       string            `json:"RemoteDNSIP"`
	DomesticDNSType   string            `json:"DomesticDNSType"`
	DomesticDNSDomain string            `json:"DomesticDNSDomain"`
	DomesticDNSIP     string            `json:"DomesticDNSIP"`
	GeoIPURL          string            `json:"Geoipurl"`
	GeoSiteURL        string            `json:"Geositeurl"`
	DNSHosts          map[string]string `json:"DnsHosts"`
	DirectSites       []string          `json:"DirectSites"`
	DirectIP          []string          `json:"DirectIp"`
	ProxySites        []string          `json:"ProxySites"`
	ProxyIP           []string          `json:"ProxyIp"`
	BlockSites        []string          `json:"BlockSites"`
	BlockIP           []string          `json:"BlockIp"`
	LastUpdated       json.RawMessage   `json:"LastUpdated"`
}

func (p *happProfile) toRouting() *Routing {
	r := &Routing{Name: strings.TrimSpace(p.Name), Updated: strings.Trim(string(p.LastUpdated), `" `)}
	if r.Updated == "null" {
		r.Updated = ""
	}
	switch p.GlobalProxy {
	case "true":
		r.Final = "proxy"
	case "false":
		r.Final = "direct"
	}

	seen := map[RouteRule]bool{}
	add := func(rule RouteRule) {
		key := RouteRule{Kind: rule.Kind, Value: strings.ToLower(rule.Value)}
		if !seen[key] {
			seen[key] = true
			r.Rules = append(r.Rules, rule)
		}
	}
	// Block, then proxy, then direct: when a profile lists one thing twice,
	// the first one wins, as with Happ's own default order.
	for _, l := range []struct {
		sites, ips []string
		action     string
	}{
		{p.BlockSites, p.BlockIP, "block"},
		{p.ProxySites, p.ProxyIP, "proxy"},
		{p.DirectSites, p.DirectIP, "direct"},
	} {
		for _, v := range l.sites {
			if rule, ok := siteRule(v, l.action); ok {
				add(rule)
			} else if v = strings.TrimSpace(v); v != "" {
				r.Unsupported = append(r.Unsupported, v)
			}
		}
		for _, v := range l.ips {
			if rule, ok := ipRule(v, l.action); ok {
				add(rule)
			} else if v = strings.TrimSpace(v); v != "" {
				r.Unsupported = append(r.Unsupported, v)
			}
		}
	}

	r.DNS = dnsServer(p.RemoteDNSType, p.RemoteDNSDomain, p.RemoteDNSIP)
	r.DirectDNS = dnsServer(p.DomesticDNSType, p.DomesticDNSDomain, p.DomesticDNSIP)
	r.GeoIP = httpsOnly(p.GeoIPURL)
	r.GeoSite = httpsOnly(p.GeoSiteURL)
	if len(p.DNSHosts) > 0 {
		r.Unsupported = append(r.Unsupported, "DnsHosts")
	}
	return r
}

// siteRule maps Xray's domain syntax. A bare domain is a substring match
// in Xray; nobody means "anything containing sber.ru", so it becomes the
// domain with its subdomains.
func siteRule(v, action string) (RouteRule, bool) {
	v = strings.TrimSpace(v)
	prefix, rest, ok := strings.Cut(v, ":")
	if !ok {
		prefix, rest = "", v
	}
	rest = strings.TrimSpace(rest)
	switch strings.ToLower(prefix) {
	case "geosite":
		// geosite:x@attr and ext: files are Xray's own; mihomo has neither.
		if !validName(rest) {
			return RouteRule{}, false
		}
		return RouteRule{"geosite", strings.ToLower(rest), action}, true
	case "domain", "":
		if !looksLikeDomain(rest) {
			return RouteRule{}, false
		}
		return RouteRule{"domain_suffix", strings.ToLower(strings.TrimPrefix(rest, ".")), action}, true
	case "full":
		if !looksLikeDomain(rest) {
			return RouteRule{}, false
		}
		return RouteRule{"domain", strings.ToLower(rest), action}, true
	}
	return RouteRule{}, false // regexp:, keyword:, ext:
}

func ipRule(v, action string) (RouteRule, bool) {
	v = strings.TrimSpace(v)
	if rest, ok := strings.CutPrefix(strings.ToLower(v), "geoip:"); ok {
		if !validName(rest) { // geoip:!ru inverts; mihomo has no such thing
			return RouteRule{}, false
		}
		return RouteRule{"geoip", rest, action}, true
	}
	if p, err := netip.ParsePrefix(v); err == nil {
		return RouteRule{"ip_cidr", p.Masked().String(), action}, true
	}
	if a, err := netip.ParseAddr(v); err == nil {
		return RouteRule{"ip_cidr", a.String(), action}, true
	}
	return RouteRule{}, false
}

var nameRe = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_!.-]*$`)

func validName(s string) bool { return nameRe.MatchString(s) && !strings.HasPrefix(s, "!") }

var domainRe = regexp.MustCompile(`^\.?([a-z0-9_]([a-z0-9_-]*[a-z0-9_])?\.)*[a-z0-9-]+$`)

func looksLikeDomain(s string) bool {
	s = strings.ToLower(s)
	return strings.Contains(s, ".") && len(s) <= 253 && domainRe.MatchString(s)
}

// dnsServer turns Happ's three fields into what Crocell's DNS settings take:
// a DoH URL, or a plain address.
func dnsServer(typ, domain, ip string) []string {
	domain, ip = strings.TrimSpace(domain), strings.TrimSpace(ip)
	if strings.EqualFold(typ, "doh") && strings.HasPrefix(domain, "https://") {
		return []string{domain}
	}
	if _, err := netip.ParseAddr(ip); err == nil {
		return []string{ip}
	}
	return nil
}

func httpsOnly(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasPrefix(s, "https://") && !strings.ContainsAny(s, " \n\r") {
		return s
	}
	return ""
}

// appsRouting reads Happ's per-app headers. Only "bypass" maps onto
// Crocell: those apps go direct. "on" (only these through the VPN) would
// need a rule for every other app, so it is reported, not applied.
func appsRouting(m map[string]string) (rules []RouteRule, unsupported []string) {
	mode := strings.ToLower(strings.TrimSpace(m["per-app-proxy-mode"]))
	list := m["per-app-proxy-list"]
	if mode == "" || mode == "off" || strings.TrimSpace(list) == "" {
		return nil, nil
	}
	if mode != "bypass" {
		return nil, []string{"per-app-proxy-mode: " + mode}
	}
	for _, pkg := range strings.FieldsFunc(list, func(r rune) bool { return r == ',' || r == ';' || r == ' ' || r == '\n' }) {
		if pkgRe.MatchString(pkg) {
			rules = append(rules, RouteRule{"process_name", pkg, "direct"})
		}
	}
	return rules, nil
}

var pkgRe = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$`)

// routingFromMap reads the routing offer among a subscription's headers or
// "#key: value" body lines. A broken profile is dropped, not an error: the
// nodes still work without it.
func routingFromMap(m map[string]string) *Routing {
	var r *Routing
	if v := strings.TrimSpace(m["routing"]); v != "" {
		r, _ = ParseRouting(v)
	}
	apps, unsupported := appsRouting(m)
	if len(apps) == 0 && len(unsupported) == 0 {
		return r
	}
	if r == nil {
		r = &Routing{}
	}
	r.Rules = append(r.Rules, apps...)
	r.Unsupported = append(r.Unsupported, unsupported...)
	return r
}
