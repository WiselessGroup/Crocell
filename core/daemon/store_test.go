package daemon

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/probe"
)

func quietCheck(context.Context, pb.TunnelMode, int) probe.Result { return probe.Result{} }

func TestPlainStateIsMigratedAndEncrypted(t *testing.T) {
	dir := t.TempDir()
	legacy := map[string]any{
		"subscriptions": []map[string]any{{"id": "abc", "url": "https://example.com/sub/old-token", "nodes": []any{}}},
		"settings": map[string]any{
			"tunnel_mode": "tun",
			"app_rules": []map[string]string{
				{"app": "steam", "mode": "bypass"},
				{"app": "/opt/spy/agent", "mode": "block"},
			},
		},
	}
	b, _ := json.Marshal(legacy)
	if err := os.WriteFile(filepath.Join(dir, "state.json"), b, 0o600); err != nil {
		t.Fatal(err)
	}

	svc, err := New(Config{StateDir: dir, Engine: &fakeEngine{}, Check: quietCheck})
	if err != nil {
		t.Fatal(err)
	}
	set, _ := svc.GetSettings(context.Background(), &pb.GetSettingsRequest{})
	if len(set.Rules) != 2 ||
		set.Rules[0].Kind != pb.RuleKind_RULE_KIND_PROCESS_NAME || set.Rules[0].Action != pb.RouteAction_ROUTE_ACTION_DIRECT ||
		set.Rules[1].Kind != pb.RuleKind_RULE_KIND_PROCESS_PATH || set.Rules[1].Action != pb.RouteAction_ROUTE_ACTION_BLOCK {
		t.Fatalf("migrated rules = %v", set.Rules)
	}

	// The next save seals it and the plain copy goes.
	if _, err := svc.UpdateSettings(context.Background(), set); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "state.json")); !os.IsNotExist(err) {
		t.Error("plain state.json survived the first encrypted save")
	}
	if _, err := os.Stat(filepath.Join(dir, "state.enc")); err != nil {
		t.Error(err)
	}

	again, err := New(Config{StateDir: dir, Engine: &fakeEngine{}, Check: quietCheck})
	if err != nil {
		t.Fatal(err)
	}
	subs, _ := again.ListSubscriptions(context.Background(), &pb.ListSubscriptionsRequest{})
	if len(subs.Subscriptions) != 1 {
		t.Errorf("subscription lost in migration: %v", subs.Subscriptions)
	}
}

func TestStateNeedsThisMachinesKey(t *testing.T) {
	dir := t.TempDir()
	creds := t.TempDir()
	t.Setenv("CREDENTIALS_DIRECTORY", creds)
	if err := os.WriteFile(filepath.Join(creds, keyCredential), []byte("sealed-by-systemd-creds-0123456789abcdef"), 0o600); err != nil {
		t.Fatal(err)
	}

	svc, err := New(Config{StateDir: dir, Engine: &fakeEngine{}, Check: quietCheck})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.UpdateSettings(context.Background(), &pb.Settings{}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "state.key")); !os.IsNotExist(err) {
		t.Error("with a systemd credential there must be no key file on disk")
	}

	// Same file, another machine's key: refuse, don't hand out garbage.
	if err := os.WriteFile(filepath.Join(creds, keyCredential), []byte("some-other-machine-key-0123456789abcdef"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := New(Config{StateDir: dir, Engine: &fakeEngine{}, Check: quietCheck}); err == nil {
		t.Error("state opened with the wrong key")
	}
}
