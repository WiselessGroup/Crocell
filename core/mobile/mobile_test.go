package mobile

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
)

type fakePlatform struct{}

func (fakePlatform) OpenTun(string) (int32, error) { return 0, nil }
func (fakePlatform) CloseTun()                     {}
func (fakePlatform) InstalledApps() (string, error) {
	return `[{"package":"org.telegram.messenger","label":"Telegram"}]`, nil
}

// The client reaches the embedded core over the socket, and the program
// picker shows installed apps by name with their package behind it.
func TestEmbeddedCoreServesTheClient(t *testing.T) {
	dir := t.TempDir()
	socket := filepath.Join(dir, "c.sock")
	if err := Start(filepath.Join(dir, "state"), socket, "net.wiseless.crocell", make([]byte, 32), fakePlatform{}); err != nil {
		t.Fatal(err)
	}
	defer Stop()

	conn, err := grpc.NewClient("unix://"+socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	resp, err := pb.NewCoreClient(conn).ListProcesses(ctx, &pb.ListProcessesRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if len(resp.Processes) != 1 || resp.Processes[0].Name != "org.telegram.messenger" || resp.Processes[0].Label != "Telegram" {
		t.Errorf("apps = %v", resp.Processes)
	}
}
