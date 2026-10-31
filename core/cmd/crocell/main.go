// Command crocell is the developer CLI for the core: fetch a subscription,
// probe its nodes, run one of them as a local proxy. No GUI, no root.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"text/tabwriter"
	"time"

	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/probe"
	"git.wiseless.net/fureunoir/crocell/core/subscription"
	"git.wiseless.net/fureunoir/crocell/core/sysproxy"
)

const usage = `usage:
  crocell nodes <subscription-url> [-probe]
  crocell up <subscription-url> [-node NAME] [-port 7890] [-sysproxy] [-tun]

  -sysproxy  point the desktop proxy settings at us, restore them on exit
  -tun       capture the whole system (needs root or CAP_NET_ADMIN)
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var err error
	switch os.Args[1] {
	case "nodes":
		err = cmdNodes(ctx, os.Args[2:])
	case "up":
		err = cmdUp(ctx, os.Args[2:])
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "crocell:", err)
		os.Exit(1)
	}
}

// parseArgs lets flags go before or after the URL.
func parseArgs(fs *flag.FlagSet, args []string) (string, error) {
	var url string
	for len(args) > 0 {
		if err := fs.Parse(args); err != nil {
			return "", err
		}
		args = fs.Args()
		if len(args) > 0 {
			if url != "" {
				return "", errors.New("one subscription url, please")
			}
			url, args = args[0], args[1:]
		}
	}
	if url == "" {
		return "", errors.New("subscription url is missing")
	}
	return url, nil
}

func fetch(ctx context.Context, url string) (*subscription.Subscription, error) {
	sub, err := (&subscription.Fetcher{}).Fetch(ctx, url)
	if err != nil {
		return nil, err
	}
	if len(sub.Nodes) == 0 {
		return nil, errors.New("subscription has no nodes")
	}
	return sub, nil
}

func cmdNodes(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("nodes", flag.ExitOnError)
	doProbe := fs.Bool("probe", false, "probe every node: entry, exit, latency")
	url, err := parseArgs(fs, args)
	if err != nil {
		return err
	}

	sub, err := fetch(ctx, url)
	if err != nil {
		return err
	}
	printInfo(sub)

	results := make([]probe.Result, len(sub.Nodes))
	if *doProbe {
		var wg sync.WaitGroup
		sem := make(chan struct{}, 8)
		for i, n := range sub.Nodes {
			wg.Add(1)
			go func() {
				defer wg.Done()
				sem <- struct{}{}
				defer func() { <-sem }()
				results[i] = probe.Node(ctx, n.Proxy)
			}()
		}
		wg.Wait()
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if *doProbe {
		fmt.Fprintln(w, "NODE\tTYPE\tENTRY\tEXIT\tLATENCY")
	} else {
		fmt.Fprintln(w, "NODE\tTYPE\tSERVER")
	}
	for i, n := range sub.Nodes {
		typ := n.Type
		if network, _ := n.Proxy["network"].(string); network != "" && network != "tcp" {
			typ += "/" + network
		}
		if !*doProbe {
			fmt.Fprintf(w, "%s\t%s\t%s:%s\n", n.Name, typ, n.Server, n.Port)
			continue
		}
		r := results[i]
		entry := strings.Join(r.EntryIPs, ",")
		if entry == "" {
			entry = n.Server
		}
		if r.Err != nil {
			fmt.Fprintf(w, "%s\t%s\t%s\t✗ failed, see below\t\n", n.Name, typ, entry)
			continue
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s %s (%s)\t%s\n", n.Name, typ, entry,
			r.ExitCountry, r.ExitIP, r.ExitColo, r.Latency.Round(time.Millisecond))
	}
	if err := w.Flush(); err != nil {
		return err
	}

	for i, r := range results {
		if r.Err != nil {
			fmt.Printf("\n%s:\n  %v\n", sub.Nodes[i].Name, r.Err)
		}
	}
	return nil
}

func cmdUp(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("up", flag.ExitOnError)
	node := fs.String("node", "", "node name (default: first)")
	port := fs.Int("port", 7890, "mixed HTTP/SOCKS port on 127.0.0.1, 0 disables")
	logLevel := fs.String("log", "warning", "mihomo log level")
	useTun := fs.Bool("tun", false, "capture the whole system through a TUN device")
	stack := fs.String("stack", "mixed", "TUN stack: mixed, system, gvisor")
	useSysproxy := fs.Bool("sysproxy", false, "set the desktop proxy settings")
	url, err := parseArgs(fs, args)
	if err != nil {
		return err
	}

	if *useSysproxy && *port == 0 {
		return errors.New("-sysproxy needs a -port")
	}
	if *useTun && !privileged() {
		return errors.New("-tun needs root: run with sudo, or once `sudo setcap cap_net_admin,cap_net_bind_service+ep` on the binary")
	}

	sub, err := fetch(ctx, url)
	if err != nil {
		return err
	}

	home, err := os.UserCacheDir()
	if err != nil {
		return err
	}

	opts := engine.Options{
		HomeDir:   filepath.Join(home, "crocell", "engine"),
		MixedPort: *port,
		LogLevel:  *logLevel,
		Nodes:     sub.Nodes,
		Selected:  *node,
	}
	if *useTun {
		opts.Tun = &engine.TunOptions{Stack: *stack}
	}
	if err := engine.Start(opts); err != nil {
		return err
	}
	defer engine.Stop()

	var modes []string
	if *port > 0 {
		modes = append(modes, fmt.Sprintf("127.0.0.1:%d (http+socks)", *port))
	}
	if *useSysproxy {
		restore, err := sysproxy.Set("127.0.0.1", *port)
		if err != nil {
			return err
		}
		defer func() {
			if err := restore(); err != nil {
				fmt.Fprintln(os.Stderr, "crocell: restore system proxy:", err)
			}
		}()
		modes = append(modes, "system proxy")
	}
	if *useTun {
		modes = append(modes, "TUN, whole system")
	}

	fmt.Printf("%s → %s. Ctrl+C to stop\n", engine.Selected(), strings.Join(modes, ", "))
	<-ctx.Done()
	return nil
}

func printInfo(sub *subscription.Subscription) {
	title := sub.Info.Title
	if title == "" {
		title = sub.URL
	}
	fmt.Printf("%s · %s · %d nodes", title, sub.Format, len(sub.Nodes))
	if sub.Info.Total > 0 {
		used := sub.Info.Upload + sub.Info.Download
		fmt.Printf(" · %.1f / %.1f GB", gb(used), gb(sub.Info.Total))
	}
	if !sub.Info.Expire.IsZero() {
		fmt.Printf(" · until %s", sub.Info.Expire.Format("2006-01-02"))
	}
	fmt.Println()
}

func gb(n int64) float64 { return float64(n) / (1 << 30) }
