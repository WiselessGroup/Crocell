//go:build !windows

package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
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
//	crocelld connect       resume the last node
//	crocelld disconnect
//	crocelld watch         one JSON line per change: {"state":"connected","node":"…"}
func ctl(cmd string) error {
	conn, err := grpc.NewClient("unix://"+paths.Socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()
	c := pb.NewCoreClient(conn)

	switch cmd {
	case "connect", "disconnect":
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		if cmd == "connect" {
			_, err = c.Connect(ctx, &pb.ConnectRequest{})
		} else {
			_, err = c.Disconnect(ctx, &pb.DisconnectRequest{})
		}
		return err
	case "watch":
		return watch(c)
	}
	return fmt.Errorf("unknown command %q", cmd)
}

type watchLine struct {
	State string `json:"state"` // connected, connecting, disconnecting, failed, disconnected, unavailable
	Node  string `json:"node,omitempty"`
}

// watch prints the state whenever it changes, and keeps going across
// service restarts, reporting "unavailable" meanwhile.
func watch(c pb.CoreClient) error {
	enc := json.NewEncoder(os.Stdout)
	var last watchLine
	emit := func(l watchLine) {
		if l != last {
			last = l
			_ = enc.Encode(l)
		}
	}
	for {
		err := func() error {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			subs, err := c.ListSubscriptions(ctx, &pb.ListSubscriptionsRequest{})
			if err != nil {
				return err
			}
			names := map[string]string{}
			for _, s := range subs.Subscriptions {
				for _, n := range s.Nodes {
					names[s.Id+"/"+n.Id] = n.Name
				}
			}
			stream, err := c.WatchStatus(ctx, &pb.WatchStatusRequest{})
			if err != nil {
				return err
			}
			for {
				st, err := stream.Recv()
				if err != nil {
					return err
				}
				emit(watchLine{State: stateName(st.GetState()), Node: names[st.GetSubscriptionId()+"/"+st.GetNodeId()]})
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
