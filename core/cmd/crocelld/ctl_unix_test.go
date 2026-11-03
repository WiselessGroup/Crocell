//go:build !windows

package main

import (
	"bytes"
	"strings"
	"testing"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
)

func TestWatchWritesALineOnlyWhenItChanges(t *testing.T) {
	var out bytes.Buffer
	emit := lineEmitter(&out)
	st := &pb.Status{
		State:     pb.ConnectionState_CONNECTION_STATE_CONNECTED,
		NodeName:  "one",
		Favorites: []*pb.FavoriteNode{{SubscriptionId: "s", NodeId: "n", Name: "two"}},
	}
	// The status repeats every second while connected, traffic aside.
	emit(lineFromStatus(st))
	emit(lineFromStatus(st))
	st.Favorites[0].Name = "three"
	emit(lineFromStatus(st))

	lines := strings.Split(strings.TrimSpace(out.String()), "\n")
	if len(lines) != 2 {
		t.Fatalf("lines: %q", lines)
	}
	want := `{"state":"connected","node":"one","favorites":[{"subscription":"s","node":"n","name":"two"}]}`
	if lines[0] != want {
		t.Errorf("got  %s\nwant %s", lines[0], want)
	}
}

func TestConnectArguments(t *testing.T) {
	if req, err := connectRequest(nil); err != nil || req.GetNodeId() != "" {
		t.Errorf("no arguments: %v, %v", req, err)
	}
	if req, err := connectRequest([]string{"s", "n"}); err != nil || req.GetSubscriptionId() != "s" || req.GetNodeId() != "n" {
		t.Errorf("two arguments: %v, %v", req, err)
	}
	if _, err := connectRequest([]string{"s"}); err == nil {
		t.Error("one argument should be refused")
	}
}
