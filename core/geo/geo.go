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
// means the default). A file is replaced only by one that checks out.
func (m *Manager) Update(ctx context.Context, geoipSrc, geositeSrc string) error {
	var errs []error
	for _, f := range []struct{ file, src string }{{GeoIPFile, geoipSrc}, {GeoSiteFile, geositeSrc}} {
		d, err := m.Fetch(ctx, f.file, f.src)
		if err == nil {
			err = m.Install(d)
		}
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}

// Download is a checked database that is not on disk yet.
type Download struct {
	file string
	data []byte
}

// ErrNotDatabase: what came back is not a geo database at all, typically
// a web page (a GitHub "blob" link, a login wall, a rate-limit notice).
var ErrNotDatabase = errors.New("not a geo database")

// ErrSwapped: a geosite file where geoip was asked for, or the other way.
var ErrSwapped = errors.New("the other kind of geo database")

// HTTPError is an answer other than 200.
type HTTPError struct{ Status int }

func (e *HTTPError) Error() string { return fmt.Sprintf("HTTP %d", e.Status) }

// Fetch gets file (GeoIPFile or GeoSiteFile) from src and checks it, leaving
// the disk alone, so a new source can be tried before it is saved.
func (m *Manager) Fetch(ctx context.Context, file, src string) (Download, error) {
	if src == "" {
		src = map[string]string{GeoIPFile: DefaultGeoIP, GeoSiteFile: DefaultGeoSite}[file]
	}
	data, err := load(ctx, m.client(), Normalize(src))
	if err != nil {
		return Download{}, err
	}
	cats, kind, err := categories(data)
	if err != nil || len(cats) == 0 {
		return Download{}, ErrNotDatabase
	}
	if kind != "" && kind != file {
		return Download{}, ErrSwapped
	}
	return Download{file: file, data: data}, nil
}

// Install writes downloads in place, each atomically.
func (m *Manager) Install(ds ...Download) error {
	if err := os.MkdirAll(m.Dir, 0o700); err != nil {
		return err
	}
	for _, d := range ds {
		tmp := filepath.Join(m.Dir, d.file+".new")
		if err := os.WriteFile(tmp, d.data, 0o644); err != nil {
			return err
		}
		if err := os.Rename(tmp, filepath.Join(m.Dir, d.file)); err != nil {
			return err
		}
	}
	return nil
}

// Normalize turns a GitHub page link to a file into the file itself:
// github.com/o/r/blob/branch/geosite.dat serves HTML, /raw/ serves the file.
func Normalize(src string) string {
	src = strings.TrimSpace(src)
	rest, ok := strings.CutPrefix(src, "https://github.com/")
	if !ok {
		return src
	}
	parts := strings.SplitN(rest, "/", 4)
	if len(parts) == 4 && parts[2] == "blob" {
		return "https://github.com/" + parts[0] + "/" + parts[1] + "/raw/" + parts[3]
	}
	return src
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
	info.GeoIPUpdated, info.GeoIP = m.read(GeoIPFile)
	info.GeoSiteUpdated, info.GeoSite = m.read(GeoSiteFile)
	return info
}

func (m *Manager) read(name string) (time.Time, []string) {
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
	cats, _, _ := categories(data)
	if m.cache == nil {
		m.cache = map[string][]string{}
	}
	m.cache[key] = cats
	return st.ModTime(), cats
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
		return nil, &HTTPError{Status: resp.StatusCode}
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

// categories lists entry names without decoding the entries. GeoSite.dat
// is ~85 MB; unmarshalling it whole just for the names would cost hundreds
// of MB of RAM. Both files share the shape: repeated entry = 1, and inside
// each entry country_code = 1. kind tells them apart by the first rule in
// an entry: a CIDR starts with its address bytes, a domain does not.
func categories(data []byte) (names []string, kind string, err error) {
	for len(data) > 0 {
		num, typ, n := protowire.ConsumeTag(data)
		if n < 0 {
			return nil, "", protowire.ParseError(n)
		}
		data = data[n:]
		if num != 1 || typ != protowire.BytesType {
			if n = protowire.ConsumeFieldValue(num, typ, data); n < 0 {
				return nil, "", protowire.ParseError(n)
			}
			data = data[n:]
			continue
		}
		entry, n := protowire.ConsumeBytes(data)
		if n < 0 {
			return nil, "", protowire.ParseError(n)
		}
		data = data[n:]
		if code, ok := firstString(entry); ok && code != "" {
			names = append(names, strings.ToLower(code))
		}
		if kind == "" {
			kind = entryKind(entry)
		}
	}
	slices.Sort(names)
	return slices.Compact(names), kind, nil
}

// entryKind looks at the first rule (field 2) of an entry: GeoIP's CIDR
// begins with ip = 1 (bytes); GeoSite's Domain with type = 1 (varint) or,
// for plain domains where type is zero and omitted, value = 2.
func entryKind(entry []byte) string {
	for len(entry) > 0 {
		num, typ, n := protowire.ConsumeTag(entry)
		if n < 0 {
			return ""
		}
		entry = entry[n:]
		if num == 2 && typ == protowire.BytesType {
			rule, n := protowire.ConsumeBytes(entry)
			if n < 0 {
				return ""
			}
			num, typ, n := protowire.ConsumeTag(rule)
			switch {
			case n < 0:
				return ""
			case num == 1 && typ == protowire.BytesType:
				return GeoIPFile
			default:
				return GeoSiteFile
			}
		}
		if n = protowire.ConsumeFieldValue(num, typ, entry); n < 0 {
			return ""
		}
		entry = entry[n:]
	}
	return ""
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
