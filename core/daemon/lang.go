package daemon

import (
	"context"
	"sync/atomic"

	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

// The client says which language it shows ("ru" or "en") on every call, and
// the service answers in it, also later, in errors from reconnects nobody
// asked for. There is one client per machine, so one language at a time.
var english atomic.Bool

// LangHeader is the metadata key the client sets.
const LangHeader = "x-crocell-lang"

func noteLang(ctx context.Context) {
	if v := metadata.ValueFromIncomingContext(ctx, LangHeader); len(v) == 1 {
		english.Store(v[0] == "en")
	}
}

// say picks the text for the client's language.
func say(ru, en string) string {
	if english.Load() {
		return en
	}
	return ru
}

// LangInterceptors remember the language of each call. Pass them to
// grpc.NewServer.
func LangInterceptors() []grpc.ServerOption {
	return []grpc.ServerOption{
		grpc.ChainUnaryInterceptor(func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, h grpc.UnaryHandler) (any, error) {
			noteLang(ctx)
			return h(ctx, req)
		}),
		grpc.ChainStreamInterceptor(func(srv any, ss grpc.ServerStream, _ *grpc.StreamServerInfo, h grpc.StreamHandler) error {
			noteLang(ss.Context())
			return h(srv, ss)
		}),
	}
}
