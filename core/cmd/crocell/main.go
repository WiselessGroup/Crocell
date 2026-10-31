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
)

const usage = `usage:
  crocell nodes <subscription-url> [-probe]
  crocell up <subscription-url> [-node NAME] [-port 7890]
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
			fmt.Fprintf(w, "%s\t%s\t%s\t✗ %v\t\n", n.Name, typ, entry, shortErr(r.Err))
			continue
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s %s (%s)\t%s\n", n.Name, typ, entry,
			r.ExitCountry, r.ExitIP, r.ExitColo, r.Latency.Round(time.Millisecond))
	}
	return w.Flush()
}

func cmdUp(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("up", flag.ExitOnError)
	node := fs.String("node", "", "node name (default: first)")
	port := fs.Int("port", 7890, "mixed HTTP/SOCKS port on 127.0.0.1")
	logLevel := fs.String("log", "warning", "mihomo log level")
	url, err := parseArgs(fs, args)
	if err != nil {
		return err
	}

	sub, err := fetch(ctx, url)
	if err != nil {
		return err
	}

	home, err := os.UserCacheDir()
	if err != nil {
		return err
	}

	err = engine.Start(engine.Options{
		HomeDir:   filepath.Join(home, "crocell", "engine"),
		MixedPort: *port,
		LogLevel:  *logLevel,
		Nodes:     sub.Nodes,
		Selected:  *node,
	})
	if err != nil {
		return err
	}
	defer engine.Stop()

	fmt.Printf("%s → 127.0.0.1:%d (http+socks), Ctrl+C to stop\n", engine.Selected(), *port)
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

func shortErr(err error) string {
	s := err.Error()
	if len(s) > 60 {
		s = s[:57] + "..."
	}
	return s
}
