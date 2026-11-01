package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/sys/windows"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"git.wiseless.net/fureunoir/crocell/core/internal/paths"
)

const defaultLog = paths.Log

// SYSTEM and Administrators only, not inherited from ProgramData, which
// lets every user read.
const stateDirACL = "D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"

// The token is for the person at this computer: any local user may read
// it. What it keeps out is everything else that can reach 127.0.0.1, web
// pages included.
const tokenACL = "D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;BU)"

func secureStateDir(dir string) error { return setACL(dir, stateDirACL) }

// listen serves the API on loopback TCP. Dart cannot open AF_UNIX sockets on
// Windows, so who may call is decided by the token instead of the peer.
func listen(addr string, _ uidList) (net.Listener, []grpc.ServerOption, error) {
	host, _, err := net.SplitHostPort(addr)
	if err != nil || !net.ParseIP(host).IsLoopback() {
		return nil, nil, fmt.Errorf("the API must listen on a loopback address, not %q", addr)
	}
	token, err := apiToken(paths.TokenFile)
	if err != nil {
		return nil, nil, fmt.Errorf("API token: %w", err)
	}
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, nil, err
	}
	want := []byte("Bearer " + token)
	check := func(ctx context.Context) error {
		got := metadata.ValueFromIncomingContext(ctx, "authorization")
		if len(got) == 1 && subtle.ConstantTimeCompare([]byte(got[0]), want) == 1 {
			return nil
		}
		return status.Error(codes.Unauthenticated, "no or wrong API token")
	}
	return lis, []grpc.ServerOption{
		grpc.UnaryInterceptor(func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, h grpc.UnaryHandler) (any, error) {
			if err := check(ctx); err != nil {
				return nil, err
			}
			return h(ctx, req)
		}),
		grpc.StreamInterceptor(func(srv any, ss grpc.ServerStream, _ *grpc.StreamServerInfo, h grpc.StreamHandler) error {
			if err := check(ss.Context()); err != nil {
				return err
			}
			return h(srv, ss)
		}),
	}, nil
}

// apiToken reads the token, or makes one on the first run. It survives
// restarts and reinstalls, so a running client keeps working.
func apiToken(path string) (string, error) {
	if b, err := os.ReadFile(path); err == nil {
		if t := strings.TrimSpace(string(b)); len(t) >= 32 {
			return t, setACL(path, tokenACL)
		}
	}
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	token := hex.EncodeToString(raw)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", err
	}
	if err := os.WriteFile(path, []byte(token), 0o644); err != nil {
		return "", err
	}
	return token, setACL(path, tokenACL)
}

func setACL(path, sddl string) error {
	sd, err := windows.SecurityDescriptorFromString(sddl)
	if err != nil {
		return err
	}
	dacl, _, err := sd.DACL()
	if err != nil {
		return err
	}
	return windows.SetNamedSecurityInfo(path, windows.SE_FILE_OBJECT,
		windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION, nil, nil, dacl, nil)
}
