package daemon

import (
	"errors"
	"fmt"
	"net/url"
	"path/filepath"
	"strings"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/geo"
)

var kindNames = map[string]pb.RuleKind{
	"process_path":    pb.RuleKind_RULE_KIND_PROCESS_PATH,
	"process_name":    pb.RuleKind_RULE_KIND_PROCESS_NAME,
	"domain":          pb.RuleKind_RULE_KIND_DOMAIN,
	"domain_wildcard": pb.RuleKind_RULE_KIND_DOMAIN_WILDCARD,
	"domain_suffix":   pb.RuleKind_RULE_KIND_DOMAIN_SUFFIX,
	"ip_cidr":         pb.RuleKind_RULE_KIND_IP_CIDR,
	"geosite":         pb.RuleKind_RULE_KIND_GEOSITE,
	"geoip":           pb.RuleKind_RULE_KIND_GEOIP,
}

var engineKinds = map[string]engine.Kind{
	"process_path":    engine.ProcessPath,
	"process_name":    engine.ProcessName,
	"domain":          engine.Domain,
	"domain_wildcard": engine.DomainWildcard,
	"domain_suffix":   engine.DomainSuffix,
	"ip_cidr":         engine.IPCIDR,
	"geosite":         engine.GeoSite,
	"geoip":           engine.GeoIP,
}

var actionNames = map[string]pb.RouteAction{
	"proxy":  pb.RouteAction_ROUTE_ACTION_PROXY,
	"direct": pb.RouteAction_ROUTE_ACTION_DIRECT,
	"block":  pb.RouteAction_ROUTE_ACTION_BLOCK,
}

var engineActions = map[string]engine.Action{"proxy": engine.Proxy, "direct": engine.Direct, "block": engine.Block}

func nameOf[V comparable](m map[string]V, v V) string {
	for k, x := range m {
		if x == v {
			return k
		}
	}
	return ""
}

func engineRules(rules []rule) ([]engine.Rule, error) {
	out := make([]engine.Rule, 0, len(rules))
	for _, r := range rules {
		kind, ok := engineKinds[r.Kind]
		if !ok {
			return nil, fmt.Errorf("unknown rule kind %q", r.Kind)
		}
		action, ok := engineActions[r.Action]
		if !ok {
			return nil, fmt.Errorf("unknown rule action %q", r.Action)
		}
		out = append(out, engine.Rule{Kind: kind, Value: r.Value, Action: action})
	}
	return out, nil
}

// checkGeoSource accepts an http(s) link or an absolute path to a file.
// Whether there is a database behind it is checked by downloading it.
func checkGeoSource(src string) error {
	switch {
	case src == "":
		return nil
	case strings.ContainsAny(src, "\n\r"):
		return errors.New(say("одна ссылка, без переносов строки", "one link, no line breaks"))
	case isURL(src):
		u, err := url.Parse(src)
		if err != nil || u.Host == "" {
			return errors.New(say("ссылка не разбирается, проверьте адрес", "the link does not parse, check the address"))
		}
		return nil
	case filepath.IsAbs(src):
		return nil
	default:
		return errors.New(say("нужна ссылка, начинающаяся с https://, или полный путь к файлу, начинающийся с /", "needs a link starting with https://, or a full file path starting with /"))
	}
}

func isURL(s string) bool { return strings.HasPrefix(s, "https://") || strings.HasPrefix(s, "http://") }

func settingsToProto(s settings) *pb.Settings {
	out := &pb.Settings{
		TunnelMode:     pb.TunnelMode_TUNNEL_MODE_SYSTEM_PROXY,
		MixedPort:      uint32(s.MixedPort),
		TunStack:       s.TunStack,
		FinalAction:    pb.RouteAction_ROUTE_ACTION_PROXY,
		DisableIpv6:    s.DisableIPv6,
		AllowLan:       s.AllowLAN,
		ConnectOnStart: s.ConnectOnStart,
		AutoNode:       s.AutoNode,
		KillSwitch:     s.KillSwitch,
		Dns: &pb.DnsSettings{
			Servers:       s.DNS.Servers,
			DirectServers: s.DNS.DirectServers,
			RealIp:        s.DNS.RealIP,
		},
		Geo: &pb.GeoSettings{
			GeoipSource:   s.Geo.GeoIPSource,
			GeositeSource: s.Geo.GeoSiteSource,
			UpdateHours:   uint32(s.Geo.UpdateHours),
		},
	}
	if s.TunnelMode == "tun" {
		out.TunnelMode = pb.TunnelMode_TUNNEL_MODE_TUN
	}
	if s.Final == "direct" {
		out.FinalAction = pb.RouteAction_ROUTE_ACTION_DIRECT
	}
	for _, r := range s.Rules {
		out.Rules = append(out.Rules, &pb.RouteRule{Kind: kindNames[r.Kind], Value: r.Value, Action: actionNames[r.Action]})
	}
	return out
}

func settingsFromProto(p *pb.Settings) (settings, error) {
	s := settings{
		TunnelMode:     "proxy",
		MixedPort:      int(p.GetMixedPort()),
		TunStack:       p.GetTunStack(),
		Final:          "proxy",
		DisableIPv6:    p.GetDisableIpv6(),
		AllowLAN:       p.GetAllowLan(),
		ConnectOnStart: p.GetConnectOnStart(),
		AutoNode:       p.GetAutoNode(),
		KillSwitch:     p.GetKillSwitch(),
		DNS: dnsSettings{
			Servers:       clean(p.GetDns().GetServers()),
			DirectServers: clean(p.GetDns().GetDirectServers()),
			RealIP:        p.GetDns().GetRealIp(),
		},
		Geo: geoSettings{
			GeoIPSource:   strings.TrimSpace(p.GetGeo().GetGeoipSource()),
			GeoSiteSource: strings.TrimSpace(p.GetGeo().GetGeositeSource()),
			UpdateHours:   int(p.GetGeo().GetUpdateHours()),
		},
	}
	if p.GetTunnelMode() == pb.TunnelMode_TUNNEL_MODE_TUN {
		s.TunnelMode = "tun"
	}
	if p.GetFinalAction() == pb.RouteAction_ROUTE_ACTION_DIRECT {
		s.Final = "direct"
	}
	if s.MixedPort == 0 {
		s.MixedPort = defaultMixedPort
	}
	if s.MixedPort < 1024 || s.MixedPort > 65535 {
		return settings{}, fmt.Errorf("mixed port %d out of range 1024-65535", s.MixedPort)
	}
	switch s.TunStack {
	case "", "mixed", "system", "gvisor":
	default:
		return settings{}, fmt.Errorf("unknown TUN stack %q", s.TunStack)
	}
	if s.Geo.UpdateHours < 0 || s.Geo.UpdateHours > 24*30 {
		return settings{}, fmt.Errorf("geo update interval %d h is out of range", s.Geo.UpdateHours)
	}
	s.Geo.GeoIPSource = geo.Normalize(s.Geo.GeoIPSource)
	s.Geo.GeoSiteSource = geo.Normalize(s.Geo.GeoSiteSource)
	for _, g := range []struct{ name, src string }{{"geoip.dat", s.Geo.GeoIPSource}, {"geosite.dat", s.Geo.GeoSiteSource}} {
		if err := checkGeoSource(g.src); err != nil {
			return settings{}, fmt.Errorf(say("Источник %s: %w", "Source of %s: %w"), g.name, err)
		}
	}
	for _, d := range append(append([]string{}, s.DNS.Servers...), s.DNS.DirectServers...) {
		if strings.ContainsAny(d, " \t,") {
			return settings{}, fmt.Errorf("DNS server %q: one address per line", d)
		}
	}
	for _, d := range s.DNS.DirectServers {
		if strings.EqualFold(d, "system") {
			return settings{}, errors.New(say("DNS для прямых соединений: «system» не подходит. В туннеле системный DNS спрашивает сам Crocell, и прямые сайты не открываются. Впишите адрес сервера, например 77.88.8.8, или оставьте поле пустым.", "DNS for direct connections: \"system\" will not do. In the tunnel the system DNS asks Crocell itself, and direct sites stop opening. Enter a server address, for example 1.1.1.1, or leave the field empty."))
		}
	}

	for _, r := range p.GetRules() {
		kind := nameOf(kindNames, r.GetKind())
		action := nameOf(actionNames, r.GetAction())
		if kind == "" || action == "" {
			return settings{}, fmt.Errorf("rule %q: kind or action not set", r.GetValue())
		}
		s.Rules = append(s.Rules, rule{Kind: kind, Value: strings.TrimSpace(r.GetValue()), Action: action})
	}
	rules, err := engineRules(s.Rules)
	if err != nil {
		return settings{}, err
	}
	if err := engine.Validate(rules); err != nil {
		return settings{}, err
	}
	return s, nil
}

func clean(list []string) []string {
	var out []string
	for _, v := range list {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	return out
}
