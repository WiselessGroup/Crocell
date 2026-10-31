package subscription

import (
	"encoding/base64"
	"mime"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func infoFromHeader(h http.Header) Info {
	m := make(map[string]string, len(h))
	for key := range h {
		m[strings.ToLower(key)] = h.Get(key)
	}
	info := infoFromMap(m)

	if info.Title == "" {
		if _, params, err := mime.ParseMediaType(h.Get("Content-Disposition")); err == nil {
			name := params["filename"]
			info.Title = strings.TrimSuffix(name, ".txt")
		}
	}
	return info
}

func infoFromMap(m map[string]string) Info {
	var info Info

	info.Title = decodeMaybeBase64(m["profile-title"])
	info.WebPage = m["profile-web-page-url"]
	info.Support = m["support-url"]
	info.Announce = decodeMaybeBase64(m["announce"])

	// Hours, not minutes. Happ and Clash agree on this.
	if hours, err := strconv.Atoi(m["profile-update-interval"]); err == nil && hours > 0 {
		info.UpdateInterval = time.Duration(hours) * time.Hour
	}

	// upload=0; download=0; total=0; expire=0
	for _, part := range strings.Split(m["subscription-userinfo"], ";") {
		key, value, ok := strings.Cut(strings.TrimSpace(part), "=")
		if !ok {
			continue
		}
		n, err := strconv.ParseInt(strings.TrimSpace(value), 10, 64)
		if err != nil {
			continue
		}
		switch strings.TrimSpace(key) {
		case "upload":
			info.Upload = n
		case "download":
			info.Download = n
		case "total":
			info.Total = n
		case "expire":
			if n > 0 {
				info.Expire = time.Unix(n, 0)
			}
		}
	}
	return info
}

// decodeMaybeBase64 handles the "base64:V0lTRUxFU1M=" convention.
func decodeMaybeBase64(s string) string {
	rest, ok := strings.CutPrefix(s, "base64:")
	if !ok {
		return s
	}
	for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
		if b, err := enc.DecodeString(rest); err == nil {
			return string(b)
		}
	}
	return s
}

// mergeInfo fills dst with non-empty fields of src. Headers win over body
// comments, so Fetch merges headers last.
func mergeInfo(dst *Info, src Info) {
	if src.Title != "" {
		dst.Title = src.Title
	}
	if src.Upload != 0 || src.Download != 0 || src.Total != 0 || !src.Expire.IsZero() {
		dst.Upload, dst.Download, dst.Total, dst.Expire = src.Upload, src.Download, src.Total, src.Expire
	}
	if src.UpdateInterval != 0 {
		dst.UpdateInterval = src.UpdateInterval
	}
	if src.WebPage != "" {
		dst.WebPage = src.WebPage
	}
	if src.Support != "" {
		dst.Support = src.Support
	}
	if src.Announce != "" {
		dst.Announce = src.Announce
	}
}
