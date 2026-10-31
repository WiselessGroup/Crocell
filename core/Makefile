# gVisor is needed by the default "mixed" TUN stack. Every binary that may
# run TUN (CLI, crocelld, mobile libraries) is built with these tags.
TAGS := with_gvisor
LDFLAGS := -s -w

.PHONY: build test vet setcap

build:
	go build -tags $(TAGS) -trimpath -ldflags="$(LDFLAGS)" -o bin/crocell ./cmd/crocell

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
