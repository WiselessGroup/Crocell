package engine

import (
	"testing"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type fakeConn struct {
	id     string
	chain  C.Chain
	closed bool
}

func (f *fakeConn) ID() string                    { return f.id }
func (f *fakeConn) Close() error                  { f.closed = true; return nil }
func (f *fakeConn) Info() *statistic.TrackerInfo  { return &statistic.TrackerInfo{Chain: f.chain} }
func (f *fakeConn) Chains() C.Chain               { return f.chain }
func (f *fakeConn) ProviderChains() C.Chain       { return nil }
func (f *fakeConn) AppendToChains(C.ProxyAdapter) {}
func (f *fakeConn) RemoteDestination() string     { return "" }

// After a node switch, connections through the group must close so apps
// reconnect through the new node; direct ones have no reason to.
func TestSwitchClosesOnlyTunnelledConnections(t *testing.T) {
	via := &fakeConn{id: "crocell-test-via", chain: C.Chain{"old", GroupName}}
	direct := &fakeConn{id: "crocell-test-direct", chain: C.Chain{"DIRECT"}}
	m := statistic.DefaultManager
	m.Join(via)
	m.Join(direct)
	defer m.Leave(via)
	defer m.Leave(direct)

	closeThrough(m, GroupName)

	if !via.closed {
		t.Error("connection through the node stayed open")
	}
	if direct.closed {
		t.Error("direct connection was closed")
	}
}
