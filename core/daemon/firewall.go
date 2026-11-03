package daemon

import (
	"context"
	"log"
	"net"
	"net/http"
	"time"

	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/killswitch"
)

// firewallWantedLocked is the whole rule of Kill Switch, see ADR-0002: on in the
// settings, in tunnel mode, connected or meant to be, and not quitting. "Quit
// completely" lifts the rules and leaves the setting and Wanted alone, so the
// next start carries on from there.
func (s *Service) firewallWantedLocked() bool {
	set := s.st.Settings
	return s.fw != nil && s.fw.Supported() &&
		set.KillSwitch && set.TunnelMode == "tun" && s.st.Wanted && !s.quitting
}

// syncFirewall makes the rules match the state. Safe to repeat. Taking them off
// is not undone by a failed save or anything else that happens around it.
func (s *Service) syncFirewall() error {
	if s.fw == nil || !s.fw.Supported() {
		return nil
	}
	s.mu.Lock()
	want := s.firewallWantedLocked()
	killSwitch := s.st.Settings.KillSwitch
	s.mu.Unlock()

	// The mark goes on before the rules and comes off after them: at no point
	// does a rule stop mihomo's own connections.
	if killSwitch {
		engine.SetRoutingMark(killswitch.Mark)
	}
	var err error
	if want {
		err = s.fw.Block(engine.TunDevice)
	} else {
		err = s.fw.Unblock()
	}
	if err == nil && !killSwitch {
		engine.SetRoutingMark(0)
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if err == nil && s.fwUp != want {
		s.fwUp = want
		log.Printf("crocelld: Kill Switch rules: %v", want)
		s.notifyLocked()
	}
	return err
}

// ownClient is for the service's own requests, which have to get out while the
// rules are up: refreshing a subscription is one of the ways out of a dead node.
func (s *Service) ownClient(timeout time.Duration) *http.Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = s.dialOwn
	return &http.Client{Timeout: timeout, Transport: transport}
}

func (s *Service) dialOwn(ctx context.Context, network, addr string) (net.Conn, error) {
	s.mu.Lock()
	up := s.fwUp
	s.mu.Unlock()
	if up {
		return killswitch.Dial(ctx, network, addr)
	}
	return (&net.Dialer{Timeout: 30 * time.Second, KeepAlive: 30 * time.Second}).DialContext(ctx, network, addr)
}
