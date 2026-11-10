package subscription

import (
	"errors"
	"strings"

	incylink "github.com/INCY-DEV/incy-link-encoder/go"
)

// INCY's links hide a subscription link from bots and scanners:
// incy://crypt1/ + base64url(AES-GCM(JSON{url, n})). The key is in every INCY
// client and in the encoder's source, so this is a wrapper, not a secret.
// https://github.com/INCY-DEV/incy-link-encoder
const incyPrefix = "incy://"

func isIncy(input string) bool {
	return strings.HasPrefix(strings.ToLower(input), incyPrefix)
}

// unwrapIncy returns the subscription link inside and the name the provider
// gave it. A scheme other than crypt1 is a newer one, promised after a key
// leak; old crypt1 links keep working. Errors never quote the input.
func unwrapIncy(input string) (link, name string, err error) {
	rest := input[len(incyPrefix):]
	scheme, _, _ := strings.Cut(rest, "/")
	if _, ok := incylink.Schemes[strings.ToLower(scheme)]; !ok {
		return "", "", errors.New("subscription: this version of INCY link is not supported yet")
	}
	// The decoder wants its prefix exactly as INCY writes it.
	d, err := incylink.DecryptLink(incyPrefix + strings.ToLower(scheme) + rest[len(scheme):])
	if err != nil {
		return "", "", errors.New("subscription: this INCY link is damaged or incomplete")
	}
	link = strings.TrimSpace(d.URL)
	if !IsLink(link) {
		return "", "", errors.New("subscription: this INCY link has no subscription link inside")
	}
	return link, strings.TrimSpace(d.Name), nil
}
