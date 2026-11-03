//go:build !windows

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/internal/paths"
)

// Small client commands for desktop shells (the GNOME quick toggle): they
// talk to the running service over its socket, as the person.
//
//	crocelld connect [subscription node]    resume the last node, or this one
//	crocelld disconnect
//	crocelld refresh-all   fetch every subscription; a failure does not stop the rest
//	crocelld quit          disconnect and stop the service
//	crocelld watch         one JSON line per change: {"state":"connected","node":"…","favorites":[…]}
func ctl(cmd string, args []string) error {
	conn, err := grpc.NewClient("unix://"+paths.Socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()
	c := pb.NewCoreClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	switch cmd {
	case "connect":
		req, err := connectRequest(args)
		if err != nil {
			return err
		}
		_, err = c.Connect(ctx, req)
		return err
	case "disconnect":
		_, err = c.Disconnect(ctx, &pb.DisconnectRequest{})
		return err
	case "refresh-all":
		resp, err := c.RefreshAllSubscriptions(ctx, &pb.RefreshAllSubscriptionsRequest{})
		if err != nil {
			return err
		}
		for _, f := range resp.GetFailed() {
			fmt.Fprintf(os.Stderr, "%s: %s\n", f.GetTitle(), f.GetError())
		}
		if len(resp.GetFailed()) > 0 {
			return fmt.Errorf("%d of %d subscriptions did not refresh", len(resp.GetFailed()), len(resp.GetFailed())+int(resp.GetRefreshed()))
		}
		return nil
	case "quit":
		_, err = c.Shutdown(ctx, &pb.ShutdownRequest{})
		return err
	case "watch":
		return watch(c)
	}
	return fmt.Errorf("unknown command %q", cmd)
}

func connectRequest(args []string) (*pb.ConnectRequest, error) {
	switch len(args) {
	case 0:
		return &pb.ConnectRequest{}, nil
	case 2:
		return &pb.ConnectRequest{SubscriptionId: args[0], NodeId: args[1]}, nil
	}
	return nil, errors.New("connect takes nothing, or a subscription id and a node id")
}

type watchLine struct {
	State     string     `json:"state"` // connected, connecting, disconnecting, failed, disconnected, unavailable
	Node      string     `json:"node,omitempty"`
	Favorites []favorite `json:"favorites,omitempty"`
}

type favorite struct {
	Subscription string `json:"subscription"`
	Node         string `json:"node"`
	Name         string `json:"name"`
}

func lineFromStatus(st *pb.Status) watchLine {
	l := watchLine{State: stateName(st.GetState()), Node: st.GetNodeName()}
	for _, f := range st.GetFavorites() {
		l.Favorites = append(l.Favorites, favorite{Subscription: f.GetSubscriptionId(), Node: f.GetNodeId(), Name: f.GetName()})
	}
	return l
}

// lineEmitter writes a line only when it differs from the last one. Lines are
// compared in their encoded form: the status comes every second while
// connected, and a line with a slice in it can't be compared with !=.
func lineEmitter(w io.Writer) func(watchLine) {
	var last []byte
	return func(l watchLine) {
		b, err := json.Marshal(l)
		if err != nil || bytes.Equal(b, last) {
			return
		}
		last = b
		_, _ = w.Write(append(b[:len(b):len(b)], '\n'))
	}
}

// watch prints the state whenever it changes, and keeps going across
// service restarts, reporting "unavailable" meanwhile.
func watch(c pb.CoreClient) error {
	emit := lineEmitter(os.Stdout)
	for {
		err := func() error {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			stream, err := c.WatchStatus(ctx, &pb.WatchStatusRequest{})
			if err != nil {
				return err
			}
			for {
				st, err := stream.Recv()
				if err != nil {
					return err
				}
				emit(lineFromStatus(st))
			}
		}()
		if err != nil && !errors.Is(err, context.Canceled) {
			emit(watchLine{State: "unavailable"})
		}
		time.Sleep(3 * time.Second)
	}
}

func stateName(s pb.ConnectionState) string {
	switch s {
	case pb.ConnectionState_CONNECTION_STATE_CONNECTED:
		return "connected"
	case pb.ConnectionState_CONNECTION_STATE_CONNECTING:
		return "connecting"
	case pb.ConnectionState_CONNECTION_STATE_DISCONNECTING:
		return "disconnecting"
	case pb.ConnectionState_CONNECTION_STATE_FAILED:
		return "failed"
	}
	return "disconnected"
}
