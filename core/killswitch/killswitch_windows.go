package killswitch

import (
	"fmt"
	"net/netip"
	"os"
	"syscall"

	"github.com/tailscale/wf"
	"golang.org/x/sys/windows"
)

// Mark means nothing here: the service is let through by its path.
const Mark = 0

var control func(network, address string, raw syscall.RawConn) error

var (
	providerID = wf.ProviderID{Data1: 0x6c1e2f1a, Data2: 0x3a07, Data3: 0x4b6e, Data4: [8]byte{0x9a, 0x51, 0x0f, 0x7d, 0x2e, 0x44, 0xc1, 0x01}}
	sublayerID = wf.SublayerID{Data1: 0x6c1e2f1a, Data2: 0x3a07, Data3: 0x4b6e, Data4: [8]byte{0x9a, 0x51, 0x0f, 0x7d, 0x2e, 0x44, 0xc1, 0x02}}
)

// The addresses mihomo gives the TUN interface when told nothing else. A rule
// on them survives the interface being recreated, which a rule on its LUID
// would not. Check on a live Windows, see ADR-0002.
var (
	tunAddr4 = netip.MustParseAddr("198.18.0.1")
	tunAddr6 = netip.MustParseAddr("fdfe:dcba:9876::1")
)

const (
	weightPermit = 10
	weightBlock  = 1
)

// New returns the Windows Filtering Platform firewall. Persistent objects: they
// stay after the process dies and across reboots, until Unblock removes them.
// That is why crocelld uninstall has to call it.
func New() Firewall { return wfp{} }

type wfp struct{}

func (wfp) Supported() bool { return true }

func session() (*wf.Session, error) {
	s, err := wf.New(&wf.Options{Name: "Crocell Kill Switch", Dynamic: false})
	if err != nil {
		return nil, fmt.Errorf("killswitch: %w", err)
	}
	return s, nil
}

func (wfp) Block(string) error {
	self, err := os.Executable()
	if err != nil {
		return fmt.Errorf("killswitch: %w", err)
	}
	appID, err := wf.AppID(self)
	if err != nil {
		return fmt.Errorf("killswitch: app id: %w", err)
	}
	s, err := session()
	if err != nil {
		return err
	}
	defer s.Close()
	if err := removeAll(s); err != nil {
		return err
	}
	if err := s.AddProvider(&wf.Provider{ID: providerID, Name: "Crocell", Persistent: true}); err != nil {
		return fmt.Errorf("killswitch: provider: %w", err)
	}
	if err := s.AddSublayer(&wf.Sublayer{
		ID: sublayerID, Name: "Crocell Kill Switch", Provider: providerID, Persistent: true, Weight: 0xffff,
	}); err != nil {
		return fmt.Errorf("killswitch: sublayer: %w", err)
	}

	for _, l := range []struct {
		layer    wf.LayerID
		tun      netip.Addr
		dhcpPort uint16
	}{
		{wf.LayerALEAuthConnectV4, tunAddr4, 67},
		{wf.LayerALEAuthConnectV6, tunAddr6, 547},
	} {
		permits := [][]*wf.Match{
			{{Field: wf.FieldALEAppID, Op: wf.MatchTypeEqual, Value: appID}},
			{{Field: wf.FieldFlags, Op: wf.MatchTypeFlagsAllSet, Value: wf.ConditionFlagIsLoopback}},
			{{Field: wf.FieldIPLocalAddress, Op: wf.MatchTypeEqual, Value: l.tun}},
			{
				{Field: wf.FieldIPProtocol, Op: wf.MatchTypeEqual, Value: wf.IPProtoUDP},
				{Field: wf.FieldIPRemotePort, Op: wf.MatchTypeEqual, Value: l.dhcpPort},
			},
		}
		// Permits first: there must be no moment when the block stands alone,
		// and if something fails halfway it is better to leave the door open
		// and report it than to cut the person off.
		for _, conditions := range permits {
			if err := addRule(s, l.layer, conditions, wf.ActionPermit, weightPermit); err != nil {
				return err
			}
		}
		if err := addRule(s, l.layer, nil, wf.ActionBlock, weightBlock); err != nil {
			return err
		}
	}
	return nil
}

func addRule(s *wf.Session, layer wf.LayerID, conditions []*wf.Match, action wf.Action, weight uint64) error {
	guid, err := windows.GenerateGUID()
	if err != nil {
		return fmt.Errorf("killswitch: %w", err)
	}
	err = s.AddRule(&wf.Rule{
		ID:         wf.RuleID(guid),
		Name:       "Crocell Kill Switch",
		Layer:      layer,
		Sublayer:   sublayerID,
		Provider:   providerID,
		Weight:     weight,
		Conditions: conditions,
		Action:     action,
		Persistent: true,
	})
	if err != nil {
		return fmt.Errorf("killswitch: rule: %w", err)
	}
	return nil
}

func (wfp) Unblock() error {
	s, err := session()
	if err != nil {
		return err
	}
	defer s.Close()
	return removeAll(s)
}

// removeAll deletes what is ours and nothing else, whichever process put it there.
func removeAll(s *wf.Session) error {
	rules, err := s.Rules()
	if err != nil {
		return fmt.Errorf("killswitch: list rules: %w", err)
	}
	for _, r := range rules {
		if r.Sublayer == sublayerID {
			if err := s.DeleteRule(r.ID); err != nil {
				return fmt.Errorf("killswitch: delete rule: %w", err)
			}
		}
	}
	sublayers, err := s.Sublayers(providerID)
	if err != nil {
		return fmt.Errorf("killswitch: list sublayers: %w", err)
	}
	for _, sl := range sublayers {
		if err := s.DeleteSublayer(sl.ID); err != nil {
			return fmt.Errorf("killswitch: delete sublayer: %w", err)
		}
	}
	providers, err := s.Providers()
	if err != nil {
		return fmt.Errorf("killswitch: list providers: %w", err)
	}
	for _, p := range providers {
		if p.ID == providerID {
			if err := s.DeleteProvider(p.ID); err != nil {
				return fmt.Errorf("killswitch: delete provider: %w", err)
			}
		}
	}
	return nil
}
