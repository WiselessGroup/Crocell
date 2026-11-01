package daemon

import (
	"net/url"
	"strings"
)

// maskURL keeps enough of a subscription link to recognise it and hides the
// token: https://ftn.example.net/sub/…d03d1c
func maskURL(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return "…"
	}
	path := u.Path
	if len(path) > 12 {
		path = path[:strings.LastIndex(path[:len(path)-6], "/")+1] + "…" + path[len(path)-6:]
	}
	return u.Scheme + "://" + u.Host + path
}

// scrub removes a secret link from an error message. Go's HTTP client puts
// the full URL into its errors, and those end up in the client's UI.
func scrub(msg string, secrets ...string) string {
	for _, s := range secrets {
		if s != "" {
			msg = strings.ReplaceAll(msg, s, maskURL(s))
		}
	}
	return msg
}
