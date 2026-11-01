package main

import (
	"errors"
	"net"
)

// peerUID: AF_UNIX on Windows has no peer credentials. Until the socket gets
// a proper ACL, the daemon refuses everyone rather than serving anyone.
func peerUID(net.Conn) (uint32, error) {
	return 0, errors.New("peer credentials are not implemented on Windows yet")
}
