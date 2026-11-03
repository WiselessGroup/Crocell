// Package killswitch keeps traffic that belongs in the tunnel from leaving any
// other way. The rules live in the system's firewall, not in mihomo or this
// process: they have to outlast the service, because the service dying is one of
// the things they protect against. See ADR-0002.
//
// What gets through: loopback, the tunnel itself, the service's own connections
// (to nodes, for subscriptions and databases) and DHCP. Everything else that
// goes out is dropped.
package killswitch

import (
	"context"
	"net"
	"time"
)

// Firewall holds the rules. Block and Unblock can be repeated safely. Neither
// depends on the state of the last run: rules may be left over from a crash.
type Firewall interface {
	Supported() bool
	// Block replaces whatever rules there were. tunDevice is the tunnel's
	// interface name, which does not have to exist yet.
	Block(tunDevice string) error
	Unblock() error
}

// None is for where nothing can be done: macOS for now, see ADR-0002.
type None struct{}

func (None) Supported() bool    { return false }
func (None) Block(string) error { return nil }
func (None) Unblock() error     { return nil }

// directDNS answers for the service's own connections while the rules are up:
// the system resolver is another process, and its queries are blocked. Same
// servers the engine uses for node addresses.
var directDNS = []string{"77.88.8.8:53", "1.1.1.1:53"}

// Dial connects past the rules, DNS included. For the service's own connections
// that don't go through mihomo: subscriptions and geo databases.
func Dial(ctx context.Context, network, addr string) (net.Conn, error) {
	d := &net.Dialer{Timeout: 30 * time.Second, Control: control}
	d.Resolver = &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, _ string) (net.Conn, error) {
			var last error
			for _, server := range directDNS {
				c, err := (&net.Dialer{Timeout: 5 * time.Second, Control: control}).DialContext(ctx, network, server)
				if err == nil {
					return c, nil
				}
				last = err
			}
			return nil, last
		},
	}
	return d.DialContext(ctx, network, addr)
}
