package daemon

import (
	"errors"

	"git.wiseless.net/fureunoir/crocell/core/engine"
)

// TunProvider builds the TUN interface where the operating system owns it:
// Android's VpnService. The service asks for one on every connect and
// hands the fd to the engine, which owns it from then on.
type TunProvider interface {
	Open(TunRequest) (fd int, err error)
	// Close takes the VPN down after a disconnect.
	Close()
}

// TunRequest is what the interface should look like. The addresses are
// the engine's, so its TUN stack and the interface agree.
type TunRequest struct {
	Address4, Address6 string // CIDR; Address6 empty with IPv6 off
	DNS                string // inside the tunnel, answered by the engine
	MTU                int
	// Disallow skips the tunnel for these packages, the app itself always
	// among them so its own connections to the node do not loop. Allow,
	// when set, is the opposite: only these packages use the tunnel.
	Allow, Disallow []string
}

// tunRequest turns the rules into the interface's package lists. Programs
// cannot be told apart inside the tunnel on Android, so a program rule
// becomes "outside the tunnel" (direct) or "only these inside" (proxy,
// when everything else goes direct).
func tunRequest(rules []engine.Rule, final engine.Action, ipv6 bool, self string) TunRequest {
	req := TunRequest{
		Address4: engine.AndroidTun4,
		DNS:      engine.AndroidTunDNS,
		MTU:      engine.AndroidTunMTU,
	}
	if ipv6 {
		req.Address6 = engine.AndroidTun6
	}
	var direct, proxy []string
	for _, r := range rules {
		if r.Kind != engine.ProcessName {
			continue
		}
		switch r.Action {
		case engine.Direct:
			direct = append(direct, r.Value)
		case engine.Proxy:
			proxy = append(proxy, r.Value)
		}
	}
	if final == engine.Direct && len(proxy) > 0 {
		req.Allow = proxy
		return req
	}
	req.Disallow = append([]string{self}, direct...)
	return req
}

// withoutPrograms drops program rules: on Android the interface's package
// lists do their job, and inside the tunnel every lookup would fail.
func withoutPrograms(rules []engine.Rule) []engine.Rule {
	out := rules[:0:0]
	for _, r := range rules {
		if r.Kind != engine.ProcessName && r.Kind != engine.ProcessPath {
			out = append(out, r)
		}
	}
	return out
}

// checkMobileRules refuses program rules Android cannot carry out.
func checkMobileRules(rules []rule) error {
	for _, r := range rules {
		if r.Kind == "process_path" || (r.Kind == "process_name" && r.Action == "block") {
			return errors.New(say(
				"на Android приложение можно пустить только напрямую или через VPN, блокировать и указывать путь нельзя",
				"on Android an app can go direct or through the VPN; blocking it or naming a path is not possible"))
		}
	}
	return nil
}
