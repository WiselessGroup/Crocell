# gVisor is needed by the default "mixed" TUN stack. Every binary that may
# run TUN (CLI, crocelld, mobile libraries) is built with these tags.
TAGS := with_gvisor
LDFLAGS := -s -w

.PHONY: build test vet setcap install-daemon

build:
	go build -tags $(TAGS) -trimpath -ldflags="$(LDFLAGS)" -o bin/crocell ./cmd/crocell
	go build -tags $(TAGS) -trimpath -ldflags="$(LDFLAGS)" -o bin/crocelld ./cmd/crocelld

test:
	go test -tags $(TAGS) ./...

vet:
	go vet -tags $(TAGS) ./...
	GOOS=windows go vet -tags $(TAGS) ./...
	GOOS=darwin go vet -tags $(TAGS) ./...

# Lets the CLI create TUN without sudo. resolvectl will still ask polkit for a
# password (3 times on start, once on stop): run with sudo to avoid that.
setcap: build
	sudo setcap cap_net_admin,cap_net_bind_service+ep bin/crocell

.PHONY: proto
proto:
	go tool -modfile=tools/go.mod buf lint ../proto
	go tool -modfile=tools/go.mod buf generate
	# Dart client for the app; needs `dart pub global activate protoc_plugin`.
	PATH="$$PATH:$$HOME/.pub-cache/bin" go tool -modfile=tools/go.mod buf generate --template ../app/buf.gen.yaml -o ../app

# Installs crocelld as a systemd service controlled by the current user.
install-daemon: build
	sudo bin/crocelld install
