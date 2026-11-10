package subscription

import (
	"context"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	incylink "github.com/INCY-DEV/incy-link-encoder/go"
)

// From the encoder's own tests (go/incylink_test.go, v1.3.0). If the key
// material drifts from what INCY clients use, this stops decoding.
const incyPinned = "incy://crypt1/AAECAwQFBgcICQoLNyIQL3rDwRZqnyoD8pGKSLXP6o8NdSXQVSSALNbbUyIr__tWGFUexdIfKvvmDnuDGbmBvuppfNef6aKNZUwOm4c-Sg"

func incyFor(t *testing.T, url, name string) string {
	t.Helper()
	iv, _ := hex.DecodeString("0c0b0a090807060504030201")
	link, err := incylink.EncryptLinkDeterministic(url, name, iv)
	if err != nil {
		t.Fatal(err)
	}
	return link
}

func TestUnwrapIncy(t *testing.T) {
	link, name, err := UnwrapNamed(incyPinned)
	if err != nil || link != "https://sub.example.com/test-vector" || name != "" {
		t.Fatalf("pinned vector: %q %q %v", link, name, err)
	}

	own := incyFor(t, "https://sub.example.invalid/token?x=1&y=2", "Мой VPN")
	for _, in := range []string{own, "  " + own + "//\n", "INCY://Crypt1/" + strings.TrimPrefix(own, "incy://crypt1/")} {
		link, name, err := UnwrapNamed(in)
		if err != nil || link != "https://sub.example.invalid/token?x=1&y=2" || name != "Мой VPN" {
			t.Errorf("%q: %q %q %v", in, link, name, err)
		}
	}
}

func TestUnwrapIncyErrors(t *testing.T) {
	own := incyFor(t, "https://sub.example.invalid/token", "")
	payload := strings.TrimPrefix(own, "incy://crypt1/")
	tampered := []byte(own)
	tampered[len(tampered)-3] ^= 1 // still base64url, the GCM tag fails

	for _, tc := range []struct{ in, want string }{
		{"incy://crypt1/%%%not-base64", "damaged"},
		{string(tampered), "damaged"},
		{"incy://crypt1/", "damaged"},
		{"incy://crypt9/" + payload, "not supported yet"},
		{"incy://add/https%3A%2F%2Fsub.example.invalid", "not supported yet"},
		{incyFor(t, "ftp://sub.example.invalid/token", ""), "no subscription link inside"},
	} {
		_, _, err := UnwrapNamed(tc.in)
		if err == nil || !strings.Contains(err.Error(), tc.want) {
			t.Errorf("%.30s…: err = %v, want %q", tc.in, err, tc.want)
			continue
		}
		if strings.Contains(err.Error(), "sub.example") || strings.Contains(err.Error(), payload[:10]) {
			t.Errorf("error quotes the link: %v", err)
		}
	}
}

func TestFetchIncy(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(vlessSample)) // no title anywhere
	}))
	defer srv.Close()

	sub, err := (&Fetcher{}).Fetch(context.Background(), incyFor(t, srv.URL+"/sub/token", "Провайдер"))
	if err != nil {
		t.Fatal(err)
	}
	if sub.URL != srv.URL+"/sub/token" || sub.Info.Title != "Провайдер" || len(sub.Nodes) != 1 {
		t.Fatalf("sub = %q %q %d nodes", sub.URL, sub.Info.Title, len(sub.Nodes))
	}
}
