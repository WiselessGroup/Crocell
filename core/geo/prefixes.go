package geo

import (
	"fmt"
	"net/netip"
	"os"
	"path/filepath"
	"strings"

	"google.golang.org/protobuf/encoding/protowire"
)

// Prefixes lists the networks GeoIP.dat files under code ("ru"), or nil
// when the file is not there: it comes only with rules that use it. Read
// once per file version.
func (m *Manager) Prefixes(code string) []netip.Prefix {
	path := filepath.Join(m.Dir, GeoIPFile)
	st, err := os.Stat(path)
	if err != nil {
		return nil
	}
	key := fmt.Sprintf("%s@%d#%s", path, st.ModTime().UnixNano(), strings.ToLower(code))

	m.mu.Lock()
	defer m.mu.Unlock()
	if p, ok := m.prefixes[key]; ok {
		return p
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	p := countryPrefixes(data, code)
	if m.prefixes == nil {
		m.prefixes = map[string][]netip.Prefix{}
	}
	m.prefixes[key] = p
	return p
}

// countryPrefixes walks GeoIPList: entry = 1 { country_code = 1,
// cidr = 2 { ip = 1, prefix = 2 } }, decoding only the entry asked for.
func countryPrefixes(data []byte, code string) []netip.Prefix {
	for len(data) > 0 {
		num, typ, n := protowire.ConsumeTag(data)
		if n < 0 {
			return nil
		}
		data = data[n:]
		if num != 1 || typ != protowire.BytesType {
			if n = protowire.ConsumeFieldValue(num, typ, data); n < 0 {
				return nil
			}
			data = data[n:]
			continue
		}
		entry, n := protowire.ConsumeBytes(data)
		if n < 0 {
			return nil
		}
		data = data[n:]
		if c, ok := firstString(entry); ok && strings.EqualFold(c, code) {
			return cidrs(entry)
		}
	}
	return nil
}

func cidrs(entry []byte) []netip.Prefix {
	var out []netip.Prefix
	for len(entry) > 0 {
		num, typ, n := protowire.ConsumeTag(entry)
		if n < 0 {
			return out
		}
		entry = entry[n:]
		if num != 2 || typ != protowire.BytesType {
			if n = protowire.ConsumeFieldValue(num, typ, entry); n < 0 {
				return out
			}
			entry = entry[n:]
			continue
		}
		msg, n := protowire.ConsumeBytes(entry)
		if n < 0 {
			return out
		}
		entry = entry[n:]
		var ip []byte
		var bits uint64
		for len(msg) > 0 {
			f, t, k := protowire.ConsumeTag(msg)
			if k < 0 {
				break
			}
			msg = msg[k:]
			switch {
			case f == 1 && t == protowire.BytesType:
				ip, k = protowire.ConsumeBytes(msg)
			case f == 2 && t == protowire.VarintType:
				bits, k = protowire.ConsumeVarint(msg)
			default:
				k = protowire.ConsumeFieldValue(f, t, msg)
			}
			if k < 0 {
				break
			}
			msg = msg[k:]
		}
		if addr, ok := netip.AddrFromSlice(ip); ok {
			if p, err := addr.Unmap().Prefix(int(bits)); err == nil {
				out = append(out, p)
			}
		}
	}
	return out
}
