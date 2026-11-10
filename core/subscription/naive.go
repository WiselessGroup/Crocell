package subscription

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
)

// NaiveKey marks a node that came from a naive+https link. mihomo has no
// naive outbound, so the node runs as trusttunnel and this key is how the
// daemon still calls it NaiveProxy. mihomo ignores keys it does not know.
const NaiveKey = "crocell-naive"

// parseNaiveLink reads naive+https://user:pass@host:port#name, the format
// from https://gist.github.com/DuckSoft/ca03913b0a26fc77a1da4d01cc6ab2f1.
//
// A naive server (Caddy with klzgrad/forwardproxy) is an HTTPS proxy:
// CONNECT with Basic auth. mihomo's trusttunnel outbound speaks exactly that
// over HTTP/2, with uTLS and one TLS connection for many streams, so that is
// what we run it as. It is a compatible mode, not naive itself: no padding,
// and Go's HTTP/2 settings are not Chrome's. See ADR-0003.
//
// Errors never quote the link: it carries the password.
func parseNaiveLink(link string) (map[string]any, error) {
	u, err := url.Parse(link)
	if err != nil {
		return nil, errors.New("naive: the link does not parse")
	}
	switch strings.ToLower(u.Scheme) {
	case "naive+https", "naive":
	case "naive+quic":
		return nil, errors.New("naive over QUIC is not supported yet, ask for a naive+https link")
	default:
		return nil, fmt.Errorf("naive: unknown scheme %q", u.Scheme)
	}

	host := u.Hostname()
	if host == "" {
		return nil, errors.New("naive: the link has no server")
	}
	port := 443
	if p := u.Port(); p != "" {
		port, err = strconv.Atoi(p)
		if err != nil || port < 1 || port > 65535 {
			return nil, errors.New("naive: bad port")
		}
	}
	if u.User == nil {
		return nil, errors.New("naive: the link has no user and password")
	}
	user := u.User.Username() // url.Parse has already percent-decoded both
	pass, _ := u.User.Password()
	if user == "" || pass == "" {
		return nil, errors.New("naive: the link has no user and password")
	}

	name := u.Fragment
	if name == "" {
		name = net.JoinHostPort(host, strconv.Itoa(port))
	}

	return map[string]any{
		"name":     name,
		"type":     "trusttunnel",
		"server":   host,
		"port":     port,
		"username": user,
		"password": pass,
		"sni":      host,
		"alpn":     []string{"h2"},
		// What naive is about: look like Chrome. Without it the hello is Go's.
		"client-fingerprint": "chrome",
		// forwardproxy carries TCP only.
		"udp":    false,
		NaiveKey: true,
	}, nil
}
