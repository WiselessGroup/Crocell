package daemon

import (
	"cmp"
	"log"
	"slices"
	"strings"
	"time"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
)

const (
	// favoriteCount: menus show three nodes besides the current one.
	favoriteCount = 4
	// usageSaveEvery bounds what a crash can lose. Changes of state save
	// anyway.
	usageSaveEvery = 10 * time.Minute
)

func usageKey(subID, nodeID string) string { return subID + "/" + nodeID }

// countUsageLocked credits the node with the time since the last count. Only
// while its last check passed: otherwise going through dead nodes looking for
// a live one would fill the list with them.
func (s *Service) countUsageLocked() {
	c := &s.conn
	if c.state != pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		return
	}
	now := s.now()
	if c.check != nil && c.check.GetError() == "" && now.After(c.counted) {
		if s.st.Usage == nil {
			s.st.Usage = map[string]nodeUsage{}
		}
		key := usageKey(c.subID, c.nodeID)
		u := s.st.Usage[key]
		u.Connected += now.Sub(c.counted)
		u.LastUsed = now
		s.st.Usage[key] = u
	}
	c.counted = now
}

// saveUsageSoonLocked saves if the counts have not reached the disk in a
// while, for long connections that end in a crash or a power cut.
func (s *Service) saveUsageSoonLocked() {
	now := s.now()
	if now.Sub(s.usageSaved) < usageSaveEvery {
		return
	}
	s.usageSaved = now
	if err := s.store.save(s.st); err != nil {
		log.Printf("crocelld: save node usage: %v", err)
	}
}

// favoritesLocked lists the most used nodes that still exist. Time is
// compared to the second, so that a tie goes to the one used last.
func (s *Service) favoritesLocked() []*pb.FavoriteNode {
	type entry struct {
		fav *pb.FavoriteNode
		use nodeUsage
	}
	var all []entry
	for _, sub := range s.st.Subscriptions {
		for _, n := range sub.Nodes {
			if u, ok := s.st.Usage[usageKey(sub.ID, n.ID)]; ok {
				all = append(all, entry{&pb.FavoriteNode{SubscriptionId: sub.ID, NodeId: n.ID, Name: n.Name}, u})
			}
		}
	}
	slices.SortFunc(all, func(a, b entry) int {
		return cmp.Or(
			cmp.Compare(b.use.Connected.Truncate(time.Second), a.use.Connected.Truncate(time.Second)),
			b.use.LastUsed.Compare(a.use.LastUsed),
			cmp.Compare(a.fav.GetNodeId(), b.fav.GetNodeId()),
		)
	})
	var out []*pb.FavoriteNode
	for _, e := range all[:min(len(all), favoriteCount)] {
		out = append(out, e.fav)
	}
	return out
}

// forgetUsageLocked drops the counts of a subscription's nodes that keep does
// not name: they left it, or the provider changed their keys, which makes a
// new node. A nil keep means the subscription is gone.
func (s *Service) forgetUsageLocked(subID string, keep []storedNode) {
	for key := range s.st.Usage {
		sub, node, _ := strings.Cut(key, "/")
		if sub == subID && !slices.ContainsFunc(keep, func(n storedNode) bool { return n.ID == node }) {
			delete(s.st.Usage, key)
		}
	}
}
