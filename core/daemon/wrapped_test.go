package daemon

import (
	"context"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	incylink "github.com/INCY-DEV/incy-link-encoder/go"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/logbuf"
)

func incyLink(t *testing.T, url, name string) string {
	t.Helper()
	iv, _ := hex.DecodeString("000102030405060708090a0b")
	link, err := incylink.EncryptLinkDeterministic(url, name, iv)
	if err != nil {
		t.Fatal(err)
	}
	return link
}

func TestIncyLinkBecomesTheSameSubscription(t *testing.T) {
	h := newHarness(t)
	plain := h.add(t)
	wrapped, err := h.client.AddSubscription(context.Background(), &pb.AddSubscriptionRequest{
		Url: incyLink(t, h.subURL, "Имя из ссылки"),
	})
	if err != nil {
		t.Fatal(err)
	}
	if wrapped.GetId() != plain.GetId() {
		t.Errorf("id %s, want %s", wrapped.GetId(), plain.GetId())
	}
	if wrapped.GetTitle() != "WISELESS" {
		t.Errorf("title = %q: the provider's own title comes first", wrapped.GetTitle())
	}
}

func TestIncyNameStaysAfterRefresh(t *testing.T) {
	h := newHarness(t)
	web := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("vless://00000000-0000-4000-8000-000000000002@relay.example.com:443?type=tcp&security=tls&sni=relay.example.com#n"))
	}))
	t.Cleanup(web.Close)
	ctx := context.Background()

	sub, err := h.client.AddSubscription(ctx, &pb.AddSubscriptionRequest{Url: incyLink(t, web.URL+"/sub/x", "Провайдер")})
	if err != nil {
		t.Fatal(err)
	}
	if sub.GetTitle() != "Провайдер" {
		t.Fatalf("title = %q", sub.GetTitle())
	}
	again, err := h.client.RefreshSubscription(ctx, &pb.RefreshSubscriptionRequest{Id: sub.GetId()})
	if err != nil {
		t.Fatal(err)
	}
	if again.GetTitle() != "Провайдер" {
		t.Errorf("after refresh title = %q", again.GetTitle())
	}
}

func TestNaiveNodeIsCalledNaive(t *testing.T) {
	h := newHarness(t)
	sub, err := h.client.AddSubscription(context.Background(), &pb.AddSubscriptionRequest{
		Url: "naive+https://u0a1b2c3d:c2VjcmV0@naive.example.invalid:443#naive",
	})
	if err != nil {
		t.Fatal(err)
	}
	if n := sub.GetNodes(); len(n) != 1 || n[0].GetType() != "naive" {
		t.Fatalf("nodes = %v", n)
	}
}

func TestLogsLoseWrappedLinks(t *testing.T) {
	h := newHarness(t)
	link := incyLink(t, "https://sub.example.invalid/token", "")
	logbuf.Add("test", "pasted "+link+" and sub://aHR0cHM6Ly9zdWIuZXhhbXBsZS5pbnZhbGlk#x")
	logs, err := h.client.GetLogs(context.Background(), &pb.GetLogsRequest{})
	if err != nil {
		t.Fatal(err)
	}
	text := logs.GetText()
	if strings.Contains(text, link[len("incy://crypt1/"):][:12]) || strings.Contains(text, "aHR0cHM6") {
		t.Errorf("logs keep a wrapped link: %s", text)
	}
	if !strings.Contains(text, "incy://…") {
		t.Errorf("logs lost the scheme too: %s", text)
	}
}
