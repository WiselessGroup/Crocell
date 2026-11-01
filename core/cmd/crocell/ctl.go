package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/netip"
	"os"
	"strings"
	"text/tabwriter"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/internal/paths"
)

const ctlUsage = `usage: crocell ctl [-socket PATH] <command>

  status                      connection state
  watch                       follow state and live traffic
  add <subscription-url>      add or refresh a subscription
  subs                        subscriptions and their nodes
  rm <sub>                    remove a subscription
  connect [node] [-sub SUB]   connect; node is a name or id, default: last used
  disconnect
  probe [-sub SUB]            entry, exit and latency of every node
  mode proxy|tun              how traffic gets to the core
  rules                       routing rules
  rule proxy|direct|block <what>...
                              add rules: example.com, *.example.com,
                              +.example.com, 10.0.0.0/8, geosite:ru-blocked,
                              geoip:telegram, proc:steam, /usr/bin/steam
  rule rm <what>              remove a rule
  final proxy|direct          where everything else goes
  geo [update|list]           geo databases: dates, categories
  procs                       running programs
`

// cmdCtl talks to a running crocelld, the way the GUI will.
func cmdCtl(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("ctl", flag.ExitOnError)
	socket := fs.String("socket", paths.Socket, "crocelld API socket")
	fs.Usage = func() { fmt.Fprint(os.Stderr, ctlUsage) }
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() == 0 {
		fs.Usage()
		os.Exit(2)
	}

	conn, err := grpc.NewClient("unix://"+*socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()
	c := pb.NewCoreClient(conn)

	cmd, rest := fs.Arg(0), fs.Args()[1:]
	err = runCtl(ctx, c, cmd, rest)
	if s, ok := status.FromError(err); ok && err != nil {
		return errors.New(s.Message()) // no "rpc error: code = ..." noise
	}
	return err
}

func runCtl(ctx context.Context, c pb.CoreClient, cmd string, args []string) error {
	switch cmd {
	case "status":
		st, err := c.GetStatus(ctx, &pb.GetStatusRequest{})
		if err != nil {
			return err
		}
		printStatus(ctx, c, st)
		return nil

	case "watch":
		stream, err := c.WatchStatus(ctx, &pb.WatchStatusRequest{})
		if err != nil {
			return err
		}
		for {
			st, err := stream.Recv()
			if err != nil {
				if ctx.Err() != nil || errors.Is(err, io.EOF) {
					return nil
				}
				return err
			}
			printStatus(ctx, c, st)
		}

	case "add":
		if len(args) != 1 {
			return errors.New("add <subscription-url>")
		}
		sub, err := c.AddSubscription(ctx, &pb.AddSubscriptionRequest{Url: args[0]})
		if err != nil {
			return err
		}
		fmt.Printf("%s  %s · %d nodes\n", sub.Id, sub.Title, len(sub.Nodes))
		return nil

	case "subs":
		list, err := c.ListSubscriptions(ctx, &pb.ListSubscriptionsRequest{})
		if err != nil {
			return err
		}
		for _, sub := range list.Subscriptions {
			fmt.Printf("%s  %s · %s · %d nodes\n", sub.Id, sub.Title, sub.UrlMasked, len(sub.Nodes))
			w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
			for _, n := range sub.Nodes {
				fmt.Fprintf(w, "  %s\t%s\t%s\t%s\n", n.Id, n.Name, nodeKind(n), probeSummary(n.LastProbe))
			}
			_ = w.Flush()
		}
		return nil

	case "rm":
		if len(args) != 1 {
			return errors.New("rm <sub>")
		}
		_, err := c.RemoveSubscription(ctx, &pb.RemoveSubscriptionRequest{Id: args[0]})
		return err

	case "connect":
		fs := flag.NewFlagSet("connect", flag.ExitOnError)
		subID := fs.String("sub", "", "subscription id (default: the only one, or the last used)")
		node, err := parseOptionalArg(fs, args)
		if err != nil {
			return err
		}
		req := &pb.ConnectRequest{SubscriptionId: *subID}
		if node != "" {
			sub, n, err := findNode(ctx, c, *subID, node)
			if err != nil {
				return err
			}
			req.SubscriptionId, req.NodeId = sub, n
		}
		st, err := c.Connect(ctx, req)
		if err != nil {
			return err
		}
		printStatus(ctx, c, st)
		return nil

	case "disconnect":
		st, err := c.Disconnect(ctx, &pb.DisconnectRequest{})
		if err != nil {
			return err
		}
		printStatus(ctx, c, st)
		return nil

	case "probe":
		fs := flag.NewFlagSet("probe", flag.ExitOnError)
		subID := fs.String("sub", "", "subscription id")
		if err := fs.Parse(args); err != nil {
			return err
		}
		sub, err := pickSub(ctx, c, *subID)
		if err != nil {
			return err
		}
		names := map[string]string{}
		for _, n := range sub.Nodes {
			names[n.Id] = n.Name
		}
		stream, err := c.ProbeNodes(ctx, &pb.ProbeNodesRequest{SubscriptionId: sub.Id})
		if err != nil {
			return err
		}
		for {
			r, err := stream.Recv()
			if errors.Is(err, io.EOF) {
				return nil
			}
			if err != nil {
				return err
			}
			fmt.Printf("%-28s %s\n", names[r.NodeId], probeSummary(r))
		}

	case "mode":
		if len(args) != 1 || (args[0] != "proxy" && args[0] != "tun") {
			return errors.New("mode proxy|tun")
		}
		set, err := c.GetSettings(ctx, &pb.GetSettingsRequest{})
		if err != nil {
			return err
		}
		set.TunnelMode = pb.TunnelMode_TUNNEL_MODE_SYSTEM_PROXY
		if args[0] == "tun" {
			set.TunnelMode = pb.TunnelMode_TUNNEL_MODE_TUN
		}
		_, err = c.UpdateSettings(ctx, set)
		return err

	case "rules":
		set, err := c.GetSettings(ctx, &pb.GetSettingsRequest{})
		if err != nil {
			return err
		}
		for _, r := range set.Rules {
			fmt.Printf("%-7s %-16s %s\n", actionWord(r.Action), kindWord(r.Kind), r.Value)
		}
		fmt.Printf("%-7s %s\n", actionWord(set.FinalAction), "everything else")
		return nil

	case "rule":
		if len(args) < 2 {
			return errors.New("rule proxy|direct|block <what>...  or  rule rm <what>")
		}
		set, err := c.GetSettings(ctx, &pb.GetSettingsRequest{})
		if err != nil {
			return err
		}
		if args[0] == "rm" {
			var kept []*pb.RouteRule
			for _, r := range set.Rules {
				if r.Value != strings.TrimPrefix(args[1], "proc:") && ruleInput(r) != args[1] {
					kept = append(kept, r)
				}
			}
			set.Rules = kept
		} else {
			action, ok := map[string]pb.RouteAction{
				"proxy": pb.RouteAction_ROUTE_ACTION_PROXY, "direct": pb.RouteAction_ROUTE_ACTION_DIRECT, "block": pb.RouteAction_ROUTE_ACTION_BLOCK,
			}[args[0]]
			if !ok {
				return errors.New("rule proxy|direct|block <what>...")
			}
			for _, in := range args[1:] {
				kind, value := parseRuleInput(in)
				set.Rules = append(set.Rules, &pb.RouteRule{Kind: kind, Value: value, Action: action})
			}
		}
		_, err = c.UpdateSettings(ctx, set)
		return err

	case "final":
		if len(args) != 1 || (args[0] != "proxy" && args[0] != "direct") {
			return errors.New("final proxy|direct")
		}
		set, err := c.GetSettings(ctx, &pb.GetSettingsRequest{})
		if err != nil {
			return err
		}
		set.FinalAction = pb.RouteAction_ROUTE_ACTION_PROXY
		if args[0] == "direct" {
			set.FinalAction = pb.RouteAction_ROUTE_ACTION_DIRECT
		}
		_, err = c.UpdateSettings(ctx, set)
		return err

	case "geo":
		var info *pb.GeoInfo
		var err error
		if len(args) == 1 && args[0] == "update" {
			info, err = c.UpdateGeo(ctx, &pb.UpdateGeoRequest{})
		} else {
			info, err = c.GetGeoInfo(ctx, &pb.GetGeoInfoRequest{})
		}
		if err != nil {
			return err
		}
		when := func(ts interface{ AsTime() time.Time }, ok bool) string {
			if !ok {
				return "not downloaded"
			}
			return ts.AsTime().Local().Format("2006-01-02 15:04")
		}
		fmt.Printf("geoip   %s, %d categories\n", when(info.GeoipUpdated, info.GeoipUpdated != nil), len(info.GeoipCategories))
		fmt.Printf("geosite %s, %d categories\n", when(info.GeositeUpdated, info.GeositeUpdated != nil), len(info.GeositeCategories))
		if info.Error != "" {
			fmt.Println("last update failed:", info.Error)
		}
		if len(args) == 1 && args[0] == "list" {
			fmt.Println("\ngeoip:", strings.Join(info.GeoipCategories, " "))
			fmt.Println("\ngeosite:", strings.Join(info.GeositeCategories, " "))
		}
		return nil

	case "procs":
		resp, err := c.ListProcesses(ctx, &pb.ListProcessesRequest{})
		if err != nil {
			return err
		}
		for _, p := range resp.Processes {
			fmt.Printf("%-28s %s\n", p.Name, p.Path)
		}
		return nil
	}

	fmt.Fprint(os.Stderr, ctlUsage)
	os.Exit(2)
	return nil
}

func parseOptionalArg(fs *flag.FlagSet, args []string) (string, error) {
	var arg string
	for len(args) > 0 {
		if err := fs.Parse(args); err != nil {
			return "", err
		}
		args = fs.Args()
		if len(args) > 0 {
			arg, args = args[0], args[1:]
		}
	}
	return arg, nil
}

func pickSub(ctx context.Context, c pb.CoreClient, id string) (*pb.Subscription, error) {
	list, err := c.ListSubscriptions(ctx, &pb.ListSubscriptionsRequest{})
	if err != nil {
		return nil, err
	}
	if id == "" {
		if len(list.Subscriptions) == 1 {
			return list.Subscriptions[0], nil
		}
		return nil, errors.New("several subscriptions, pick one with -sub")
	}
	for _, s := range list.Subscriptions {
		if s.Id == id {
			return s, nil
		}
	}
	return nil, fmt.Errorf("no subscription %s", id)
}

// findNode matches a node by id, exact name or a unique name substring.
func findNode(ctx context.Context, c pb.CoreClient, subID, query string) (string, string, error) {
	list, err := c.ListSubscriptions(ctx, &pb.ListSubscriptionsRequest{})
	if err != nil {
		return "", "", err
	}
	type hit struct{ sub, node string }
	var exact, partial []hit
	for _, s := range list.Subscriptions {
		if subID != "" && s.Id != subID {
			continue
		}
		for _, n := range s.Nodes {
			switch {
			case n.Id == query || n.Name == query:
				exact = append(exact, hit{s.Id, n.Id})
			case strings.Contains(strings.ToLower(n.Name), strings.ToLower(query)):
				partial = append(partial, hit{s.Id, n.Id})
			}
		}
	}
	hits := exact
	if len(hits) == 0 {
		hits = partial
	}
	switch len(hits) {
	case 0:
		return "", "", fmt.Errorf("no node matches %q", query)
	case 1:
		return hits[0].sub, hits[0].node, nil
	}
	return "", "", fmt.Errorf("%d nodes match %q, be more specific", len(hits), query)
}

func nodeKind(n *pb.Node) string {
	if n.Network != "" && n.Network != "tcp" {
		return n.Type + "/" + n.Network
	}
	return n.Type
}

func probeSummary(r *pb.ProbeResult) string {
	switch {
	case r == nil:
		return ""
	case r.Error != "":
		return "✗ " + r.Error
	}
	return fmt.Sprintf("exit %s %s (%s), %d ms", r.ExitCountry, r.ExitIp, r.ExitColo, r.LatencyMs)
}

func printStatus(ctx context.Context, c pb.CoreClient, st *pb.Status) {
	state := strings.ToLower(strings.TrimPrefix(st.State.String(), "CONNECTION_STATE_"))
	mode := map[pb.TunnelMode]string{pb.TunnelMode_TUNNEL_MODE_TUN: "TUN", pb.TunnelMode_TUNNEL_MODE_SYSTEM_PROXY: "proxy"}[st.TunnelMode]

	line := state
	if st.NodeId != "" {
		line += " · " + nodeName(ctx, c, st.SubscriptionId, st.NodeId)
	}
	if mode != "" && st.State != pb.ConnectionState_CONNECTION_STATE_DISCONNECTED {
		line += " · " + mode
	}
	if st.MixedPort > 0 {
		line += fmt.Sprintf(" · 127.0.0.1:%d", st.MixedPort)
	}
	if t := st.Traffic; t != nil {
		line += fmt.Sprintf(" · ↑ %s/s ↓ %s/s (%s / %s)", bytes(t.UpRate), bytes(t.DownRate), bytes(t.UpBytes), bytes(t.DownBytes))
	}
	if st.ConnectedSince != nil {
		line += " · " + time.Since(st.ConnectedSince.AsTime()).Round(time.Second).String()
	}
	switch c := st.LiveCheck; {
	case c != nil && c.Error != "":
		line += "\n  ✗ internet through the VPN is not working: " + c.Error
	case c != nil:
		line += fmt.Sprintf("\n  ✓ exit %s %s (%s), %d ms", c.ExitCountry, c.ExitIp, c.ExitColo, c.LatencyMs)
	case st.Checking:
		line += "\n  checking…"
	}
	if st.Error != "" {
		line += "\n  " + st.Error
	}
	fmt.Println(line)
}

func nodeName(ctx context.Context, c pb.CoreClient, subID, nodeID string) string {
	list, err := c.ListSubscriptions(ctx, &pb.ListSubscriptionsRequest{})
	if err == nil {
		for _, s := range list.Subscriptions {
			for _, n := range s.Nodes {
				if s.Id == subID && n.Id == nodeID {
					return n.Name
				}
			}
		}
	}
	return nodeID
}

func bytes(n uint64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := uint64(unit), 0
	for m := n / unit; m >= unit; m /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(n)/float64(div), "KMGTPE"[exp])
}

// parseRuleInput reads what a person types: the same forms the app takes.
func parseRuleInput(in string) (pb.RuleKind, string) {
	switch {
	case strings.HasPrefix(in, "geosite:"):
		return pb.RuleKind_RULE_KIND_GEOSITE, strings.TrimPrefix(in, "geosite:")
	case strings.HasPrefix(in, "geoip:"):
		return pb.RuleKind_RULE_KIND_GEOIP, strings.TrimPrefix(in, "geoip:")
	case strings.HasPrefix(in, "proc:"):
		return pb.RuleKind_RULE_KIND_PROCESS_NAME, strings.TrimPrefix(in, "proc:")
	case strings.HasPrefix(in, "/") || strings.Contains(in, `\`):
		return pb.RuleKind_RULE_KIND_PROCESS_PATH, in
	case strings.HasPrefix(in, "+."):
		return pb.RuleKind_RULE_KIND_DOMAIN_SUFFIX, strings.TrimPrefix(in, "+.")
	// v2ray's notation, as in lists people copy from: domain: is the domain
	// with its subdomains, full: the domain alone.
	case strings.HasPrefix(in, "domain:"):
		return pb.RuleKind_RULE_KIND_DOMAIN_SUFFIX, strings.TrimPrefix(in, "domain:")
	case strings.HasPrefix(in, "full:"):
		return pb.RuleKind_RULE_KIND_DOMAIN, strings.TrimPrefix(in, "full:")
	case strings.ContainsAny(in, "*?"):
		return pb.RuleKind_RULE_KIND_DOMAIN_WILDCARD, in
	}
	if _, err := netip.ParsePrefix(in); err == nil {
		return pb.RuleKind_RULE_KIND_IP_CIDR, in
	}
	if _, err := netip.ParseAddr(in); err == nil {
		return pb.RuleKind_RULE_KIND_IP_CIDR, in
	}
	return pb.RuleKind_RULE_KIND_DOMAIN, in
}

func ruleInput(r *pb.RouteRule) string {
	switch r.Kind {
	case pb.RuleKind_RULE_KIND_GEOSITE:
		return "geosite:" + r.Value
	case pb.RuleKind_RULE_KIND_GEOIP:
		return "geoip:" + r.Value
	case pb.RuleKind_RULE_KIND_PROCESS_NAME:
		return "proc:" + r.Value
	case pb.RuleKind_RULE_KIND_DOMAIN_SUFFIX:
		return "+." + r.Value
	}
	return r.Value
}

func actionWord(a pb.RouteAction) string {
	switch a {
	case pb.RouteAction_ROUTE_ACTION_DIRECT:
		return "direct"
	case pb.RouteAction_ROUTE_ACTION_BLOCK:
		return "block"
	}
	return "proxy"
}

func kindWord(k pb.RuleKind) string {
	return strings.ToLower(strings.TrimPrefix(k.String(), "RULE_KIND_"))
}
