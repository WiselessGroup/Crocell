// Package geo keeps geoip.dat and geosite.dat in mihomo's home directory:
// fetches them from a URL or copies them from a local file, checks they
// parse, and lists the categories inside so the UI offers only real ones.
package geo

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"google.golang.org/protobuf/encoding/protowire"
)

// Defaults: runetfreedom, rebuilt every 6 hours, with Russia-specific sets
// (ru-blocked, ru-available-only-inside) on top of v2fly's categories.
const (
	DefaultGeoIP   = "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat"
	DefaultGeoSite = "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat"
)

// File names mihomo looks for in its home directory.
const (
	GeoIPFile   = "GeoIP.dat"
	GeoSiteFile = "GeoSite.dat"
)

const maxSize = 128 << 20 // geosite with every v2fly list is ~10 MB

// Info is what the UI shows.
type Info struct {
	GeoIPUpdated, GeoSiteUpdated time.Time // zero: missing
	GeoIP, GeoSite               []string  // category names, sorted
}

// Manager owns the two files in Dir.
type Manager struct {
	Dir    string
	Client *http.Client

	mu    sync.Mutex
	cache map[string][]string // file path -> categories, keyed with mtime
}

func (m *Manager) client() *http.Client {
	if m.Client != nil {
		return m.Client
	}
	return &http.Client{Timeout: 2 * time.Minute}
}

// Update refreshes both files from their sources (URL or local path; empty
// means the default). A file is replaced only by one that parses.
func (m *Manager) Update(ctx context.Context, geoipSrc, geositeSrc string) error {
	if geoipSrc == "" {
		geoipSrc = DefaultGeoIP
	}
	if geositeSrc == "" {
		geositeSrc = DefaultGeoSite
	}
	return errors.Join(
		m.fetch(ctx, geoipSrc, GeoIPFile, countGeoIP),
		m.fetch(ctx, geositeSrc, GeoSiteFile, countGeoSite),
	)
}

// Missing reports which files are not there yet.
func (m *Manager) Missing() (geoip, geosite bool) {
	_, e1 := os.Stat(filepath.Join(m.Dir, GeoIPFile))
	_, e2 := os.Stat(filepath.Join(m.Dir, GeoSiteFile))
	return e1 != nil, e2 != nil
}

// Info reads dates and categories. Categories are cached per file version.
func (m *Manager) Info() Info {
	var info Info
	info.GeoIPUpdated, info.GeoIP = m.read(GeoIPFile, countGeoIP)
	info.GeoSiteUpdated, info.GeoSite = m.read(GeoSiteFile, countGeoSite)
	return info
}

func (m *Manager) read(name string, list func([]byte) ([]string, error)) (time.Time, []string) {
	path := filepath.Join(m.Dir, name)
	st, err := os.Stat(path)
	if err != nil {
		return time.Time{}, nil
	}
	key := fmt.Sprintf("%s@%d", path, st.ModTime().UnixNano())

	m.mu.Lock()
	defer m.mu.Unlock()
	if cats, ok := m.cache[key]; ok {
		return st.ModTime(), cats
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return st.ModTime(), nil
	}
	cats, _ := list(data)
	if m.cache == nil {
		m.cache = map[string][]string{}
	}
	m.cache[key] = cats
	return st.ModTime(), cats
}

func (m *Manager) fetch(ctx context.Context, src, name string, list func([]byte) ([]string, error)) error {
	data, err := load(ctx, m.client(), src)
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	cats, err := list(data)
	if err != nil {
		return fmt.Errorf("%s from %s is not a geo database: %w", name, src, err)
	}
	if len(cats) == 0 {
		return fmt.Errorf("%s from %s has no categories", name, src)
	}
	if err := os.MkdirAll(m.Dir, 0o700); err != nil {
		return err
	}
	tmp := filepath.Join(m.Dir, name+".new")
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, filepath.Join(m.Dir, name))
}

func load(ctx context.Context, client *http.Client, src string) ([]byte, error) {
	if !strings.HasPrefix(src, "https://") && !strings.HasPrefix(src, "http://") {
		// A local file the person pointed us at.
		f, err := os.Open(src)
		if err != nil {
			return nil, err
		}
		defer f.Close()
		return readLimited(f)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, src, nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d from %s", resp.StatusCode, src)
	}
	return readLimited(resp.Body)
}

func readLimited(r io.Reader) ([]byte, error) {
	data, err := io.ReadAll(io.LimitReader(r, maxSize+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxSize {
		return nil, fmt.Errorf("larger than %d MB", maxSize>>20)
	}
	return data, nil
}

func countGeoIP(data []byte) ([]string, error)   { return categories(data) }
func countGeoSite(data []byte) ([]string, error) { return categories(data) }

// categories lists entry names without decoding the entries. GeoSite.dat
// is ~85 MB; unmarshalling it whole just for the names would cost hundreds
// of MB of RAM. Both files share the shape: repeated entry = 1, and inside
// each entry country_code = 1.
func categories(data []byte) ([]string, error) {
	var out []string
	for len(data) > 0 {
		num, typ, n := protowire.ConsumeTag(data)
		if n < 0 {
			return nil, protowire.ParseError(n)
		}
		data = data[n:]
		if num != 1 || typ != protowire.BytesType {
			if n = protowire.ConsumeFieldValue(num, typ, data); n < 0 {
				return nil, protowire.ParseError(n)
			}
			data = data[n:]
			continue
		}
		entry, n := protowire.ConsumeBytes(data)
		if n < 0 {
			return nil, protowire.ParseError(n)
		}
		data = data[n:]
		if code, ok := firstString(entry); ok && code != "" {
			out = append(out, strings.ToLower(code))
		}
	}
	slices.Sort(out)
	return slices.Compact(out), nil
}

func firstString(msg []byte) (string, bool) {
	for len(msg) > 0 {
		num, typ, n := protowire.ConsumeTag(msg)
		if n < 0 {
			return "", false
		}
		msg = msg[n:]
		if num == 1 && typ == protowire.BytesType {
			v, n := protowire.ConsumeBytes(msg)
			if n < 0 {
				return "", false
			}
			return string(v), true
		}
		if n = protowire.ConsumeFieldValue(num, typ, msg); n < 0 {
			return "", false
		}
		msg = msg[n:]
	}
	return "", false
}
