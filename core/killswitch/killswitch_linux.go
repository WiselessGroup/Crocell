//go:build linux && !android

package killswitch

import (
	"encoding/binary"
	"errors"
	"fmt"
	"syscall"

	"github.com/metacubex/nftables"
	"github.com/metacubex/nftables/expr"
	"golang.org/x/sys/unix"
)

// Mark is what the service's own sockets carry, and what the firewall lets
// through. Setting a mark takes CAP_NET_ADMIN, so an ordinary program can't
// pass itself off as the service.
const Mark = 0x2f0c

const tableName = "crocell"

// New returns the nftables firewall. Our own table: nobody else's rules are
// touched, and a drop here is not undone by an accept in someone else's table.
func New() Firewall { return nft{} }

type nft struct{}

func (nft) Supported() bool { return true }

func table() *nftables.Table {
	return &nftables.Table{Family: nftables.TableFamilyINet, Name: tableName}
}

// Block swaps the table in one transaction, so there is no moment without rules
// when they are replaced.
func (nft) Block(tunDevice string) error {
	c, err := nftables.New()
	if err != nil {
		return fmt.Errorf("killswitch: %w", err)
	}
	// Adding first means the delete can't fail on a table that isn't there.
	c.AddTable(table())
	c.DelTable(table())
	t := c.AddTable(table())
	policy := nftables.ChainPolicyDrop
	chain := c.AddChain(&nftables.Chain{
		Name:     "output",
		Table:    t,
		Type:     nftables.ChainTypeFilter,
		Hooknum:  nftables.ChainHookOutput,
		Priority: nftables.ChainPriorityFilter,
		Policy:   &policy,
	})
	for _, exprs := range allowed(tunDevice) {
		c.AddRule(&nftables.Rule{Table: t, Chain: chain, Exprs: append(exprs, &expr.Verdict{Kind: expr.VerdictAccept})})
	}
	if err := c.Flush(); err != nil {
		return fmt.Errorf("killswitch: %w", err)
	}
	return nil
}

func (nft) Unblock() error {
	c, err := nftables.New()
	if err != nil {
		return fmt.Errorf("killswitch: %w", err)
	}
	c.AddTable(table())
	c.DelTable(table())
	if err := c.Flush(); err != nil {
		return fmt.Errorf("killswitch: %w", err)
	}
	return nil
}

func allowed(tunDevice string) [][]expr.Any {
	rules := [][]expr.Any{
		outInterface("lo"),
		outInterface(tunDevice),
		{
			&expr.Meta{Key: expr.MetaKeyMARK, Register: 1},
			&expr.Cmp{Op: expr.CmpOpEq, Register: 1, Data: native32(Mark)},
		},
		// Without these the machine loses the network itself. Neither leaves
		// the local link.
		udpToPort(67),  // DHCP
		udpToPort(547), // DHCPv6
	}
	for _, kind := range []byte{133, 135, 136} { // router solicitation, neighbour discovery
		rules = append(rules, []expr.Any{
			&expr.Meta{Key: expr.MetaKeyL4PROTO, Register: 1},
			&expr.Cmp{Op: expr.CmpOpEq, Register: 1, Data: []byte{unix.IPPROTO_ICMPV6}},
			&expr.Payload{DestRegister: 1, Base: expr.PayloadBaseTransportHeader, Offset: 0, Len: 1},
			&expr.Cmp{Op: expr.CmpOpEq, Register: 1, Data: []byte{kind}},
		})
	}
	return rules
}

func outInterface(name string) []expr.Any {
	padded := make([]byte, unix.IFNAMSIZ)
	copy(padded, name)
	return []expr.Any{
		&expr.Meta{Key: expr.MetaKeyOIFNAME, Register: 1},
		&expr.Cmp{Op: expr.CmpOpEq, Register: 1, Data: padded},
	}
}

func udpToPort(port uint16) []expr.Any {
	return []expr.Any{
		&expr.Meta{Key: expr.MetaKeyL4PROTO, Register: 1},
		&expr.Cmp{Op: expr.CmpOpEq, Register: 1, Data: []byte{unix.IPPROTO_UDP}},
		&expr.Payload{DestRegister: 1, Base: expr.PayloadBaseTransportHeader, Offset: 2, Len: 2},
		&expr.Cmp{Op: expr.CmpOpEq, Register: 1, Data: binary.BigEndian.AppendUint16(nil, port)},
	}
}

func native32(v uint32) []byte { return binary.NativeEndian.AppendUint32(nil, v) }

// control marks a socket as the service's own. Failing is not fatal: without
// CAP_NET_ADMIN (the CLI in development) there is no firewall to pass either.
func control(_, _ string, raw syscall.RawConn) error {
	var opErr error
	if err := raw.Control(func(fd uintptr) {
		opErr = unix.SetsockoptInt(int(fd), unix.SOL_SOCKET, unix.SO_MARK, Mark)
	}); err != nil {
		return err
	}
	if errors.Is(opErr, unix.EPERM) {
		return nil
	}
	return opErr
}
