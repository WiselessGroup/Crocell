package subscription

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"net/url"
	"strconv"
	"strings"
)

// WireGuard and AmneziaWG arrive in forms mihomo's link converter does not
// know: a wg-quick .conf, a wireguard:// or awg:// link, or the vpn:// key
// AmneziaVPN shares. All of them become a mihomo "wireguard" proxy, with
// amnezia-wg-option when the obfuscation fields are there.

// looksLikeWgConf spots a wg-quick config by its sections.
func looksLikeWgConf(body []byte) bool {
	lower := bytes.ToLower(body)
	return bytes.Contains(lower, []byte("[interface]")) && bytes.Contains(lower, []byte("[peer]"))
}

// amneziaInts are the AmneziaWG fields mihomo takes as numbers, amneziaStrings
// as text (H1-H4 may be ranges, I1-I5 and J1-J3 are packet templates).
var (
	amneziaInts    = []string{"jc", "jmin", "jmax", "s1", "s2", "s3", "s4", "itime"}
	amneziaStrings = []string{"h1", "h2", "h3", "h4", "i1", "i2", "i3", "i4", "i5", "j1", "j2", "j3"}
)

// wgFields is one config in neutral form, keys lower-case.
type wgFields map[string]string

// firstOf reads a value that different tools name differently.
func (f wgFields) firstOf(keys ...string) string {
	for _, k := range keys {
		if v := strings.TrimSpace(f[k]); v != "" {
			return v
		}
	}
	return ""
}

// proxy builds the mihomo config. name may be empty.
func (f wgFields) proxy(name string) (map[string]any, error) {
	private := f.firstOf("privatekey", "private_key", "private-key")
	public := f.firstOf("publickey", "public_key", "public-key", "peerpublickey", "peer_public_key")
	host, port, err := wgEndpoint(f.firstOf("endpoint"))
	if err != nil {
		return nil, err
	}
	if private == "" || public == "" {
		return nil, errors.New("no private or public key")
	}

	p := map[string]any{
		"type":        "wireguard",
		"server":      host,
		"port":        port,
		"private-key": private,
		"public-key":  public,
		"udp":         true,
		// DNS from the config stays out: Crocell's own resolver handles names,
		// as it does for every other kind of node.
	}
	for _, a := range strings.Split(f.firstOf("address", "ip", "localaddress", "local_address"), ",") {
		a = strings.TrimSpace(a)
		addr, err := netip.ParseAddr(strings.SplitN(a, "/", 2)[0])
		if err != nil {
			continue
		}
		if addr.Is4() {
			p["ip"] = a
		} else {
			p["ipv6"] = a
		}
	}
	if p["ip"] == nil && p["ipv6"] == nil {
		return nil, errors.New("no local address")
	}
	if psk := f.firstOf("presharedkey", "preshared_key", "pre-shared-key", "psk"); psk != "" {
		p["pre-shared-key"] = psk
	}
	if ips := f.firstOf("allowedips", "allowed_ips"); ips != "" {
		var list []string
		for _, ip := range strings.Split(ips, ",") {
			list = append(list, strings.TrimSpace(ip))
		}
		p["allowed-ips"] = list
	} else {
		p["allowed-ips"] = []string{"0.0.0.0/0", "::/0"}
	}
	if n, err := strconv.Atoi(f.firstOf("mtu")); err == nil && n > 0 {
		p["mtu"] = n
	}
	if n, err := strconv.Atoi(f.firstOf("persistentkeepalive", "keepalive")); err == nil && n > 0 {
		p["persistent-keepalive"] = n
	}
	if r := f.firstOf("reserved"); r != "" {
		var bytes []int
		for _, part := range strings.Split(r, ",") {
			if n, err := strconv.Atoi(strings.TrimSpace(part)); err == nil {
				bytes = append(bytes, n)
			}
		}
		if len(bytes) == 3 {
			p["reserved"] = bytes
		}
	}

	amnezia := map[string]any{}
	for _, k := range amneziaInts {
		if n, err := strconv.Atoi(f.firstOf(k)); err == nil && n != 0 {
			amnezia[k] = n
		}
	}
	for _, k := range amneziaStrings {
		if v := f.firstOf(k); v != "" && v != "0" {
			amnezia[k] = v
		}
	}
	if len(amnezia) > 0 {
		p["amnezia-wg-option"] = amnezia
	}

	if name == "" {
		kind := "WireGuard"
		if len(amnezia) > 0 {
			kind = "AmneziaWG"
		}
		name = kind + " " + host
	}
	p["name"] = name
	return p, nil
}

func wgEndpoint(s string) (string, int, error) {
	if s == "" {
		return "", 0, errors.New("no server address")
	}
	host, port, err := net.SplitHostPort(s)
	if err != nil {
		return "", 0, fmt.Errorf("bad server address %q", s)
	}
	n, err := strconv.Atoi(port)
	if err != nil || n <= 0 || n > 65535 {
		return "", 0, fmt.Errorf("bad server port %q", s)
	}
	return host, n, nil
}

// parseWgConf reads a wg-quick config, with AmneziaWG's fields if present.
// Only the first [Peer] counts: a client config has one in practice.
func parseWgConf(body []byte) (map[string]any, error) {
	fields := wgFields{}
	section, peers, name := "", 0, ""
	for _, raw := range strings.Split(string(body), "\n") {
		line := strings.TrimSpace(raw)
		switch {
		case line == "":
			continue
		case strings.HasPrefix(line, "#"), strings.HasPrefix(line, ";"):
			// Exports often name the tunnel in a comment: "# Name = office".
			if k, v, ok := strings.Cut(strings.TrimLeft(line, "#; "), "="); ok && strings.EqualFold(strings.TrimSpace(k), "name") {
				name = strings.TrimSpace(v)
			}
			continue
		case strings.HasPrefix(line, "["):
			section = strings.ToLower(strings.Trim(line, "[] "))
			if section == "peer" {
				peers++
			}
			continue
		}
		if section == "peer" && peers > 1 {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		// Keys and base64 values both can hold "=": only the first one splits.
		fields[strings.ToLower(strings.TrimSpace(k))] = strings.TrimSpace(v)
	}
	p, err := fields.proxy(name)
	if err != nil {
		return nil, fmt.Errorf("WireGuard config: %w", err)
	}
	return p, nil
}

// parseWgLink reads wireguard://, wg://, awg:// and amneziawg:// links:
// the private key in the user part, everything else in the query.
func parseWgLink(line string) (map[string]any, error) {
	u, err := url.Parse(line)
	if err != nil {
		return nil, errors.New("WireGuard link does not parse")
	}
	fields := wgFields{"endpoint": u.Host}
	if u.User != nil {
		fields["privatekey"] = u.User.Username()
	}
	for k, v := range u.Query() {
		// In a query a "+" of base64 arrives as a space.
		fields[strings.ToLower(k)] = strings.ReplaceAll(v[0], " ", "+")
	}
	p, err := fields.proxy(u.Fragment)
	if err != nil {
		return nil, fmt.Errorf("WireGuard link: %w", err)
	}
	return p, nil
}

// parseAmneziaKey reads the vpn:// key AmneziaVPN shares: base64url of a Qt
// qCompress (4 bytes of length, then zlib) of a JSON document, or the JSON
// itself. It lists containers; the WireGuard ones hold a ready wg-quick
// config inside last_config.
func parseAmneziaKey(line string) ([]map[string]any, error) {
	doc, err := decodeAmneziaKey(strings.TrimPrefix(line, "vpn://"))
	if err != nil {
		return nil, fmt.Errorf("AmneziaVPN key: %w", err)
	}
	var key struct {
		Description string           `json:"description"`
		HostName    string           `json:"hostName"`
		Containers  []map[string]any `json:"containers"`
		APIKey      string           `json:"api_key"`
	}
	if err := json.Unmarshal(doc, &key); err != nil {
		return nil, fmt.Errorf("AmneziaVPN key: %w", err)
	}

	var out []map[string]any
	var other []string
	for _, c := range key.Containers {
		kind, _ := c["container"].(string)
		var inner map[string]any
		for _, field := range []string{"awg", "wireguard"} {
			if m, ok := c[field].(map[string]any); ok {
				inner = m
			}
		}
		if inner == nil {
			other = append(other, kind)
			continue
		}
		p, err := amneziaContainer(inner, key.HostName, key.Description)
		if err != nil {
			return nil, fmt.Errorf("AmneziaVPN key: %w", err)
		}
		out = append(out, p)
	}
	if len(out) == 0 {
		if len(other) > 0 {
			return nil, fmt.Errorf("%w: this AmneziaVPN key has only %s, Crocell reads its WireGuard and AmneziaWG containers",
				ErrUnsupported, strings.Join(other, ", "))
		}
		return nil, fmt.Errorf("%w: this AmneziaVPN key has no ready config: it is the kind the AmneziaVPN app itself fetches from its service", ErrUnsupported)
	}
	return out, nil
}

func amneziaContainer(c map[string]any, host, description string) (map[string]any, error) {
	last, _ := c["last_config"].(string)
	var cfg map[string]any
	if err := json.Unmarshal([]byte(last), &cfg); err != nil {
		return nil, errors.New("no client config in the WireGuard container")
	}
	conf, _ := cfg["config"].(string)
	if !looksLikeWgConf([]byte(conf)) {
		return nil, errors.New("no client config in the WireGuard container")
	}
	p, err := parseWgConf([]byte(conf))
	if err != nil {
		return nil, err
	}
	if description != "" {
		p["name"] = description
	} else if host != "" {
		p["name"] = "AmneziaWG " + host
	}
	return p, nil
}

func decodeAmneziaKey(s string) ([]byte, error) {
	s = strings.TrimRight(strings.TrimSpace(s), "=")
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		raw, err = base64.RawStdEncoding.DecodeString(s)
	}
	if err != nil {
		return nil, errors.New("not base64")
	}
	if len(raw) > 0 && raw[0] == '{' {
		return raw, nil
	}
	if len(raw) < 5 {
		return nil, errors.New("too short")
	}
	size := binary.BigEndian.Uint32(raw)
	if size > maxBody {
		return nil, errors.New("too large")
	}
	z, err := zlib.NewReader(bytes.NewReader(raw[4:]))
	if err != nil {
		return nil, errors.New("not compressed the way AmneziaVPN does")
	}
	defer z.Close()
	return io.ReadAll(io.LimitReader(z, maxBody))
}
