//go:build !linux && !darwin && !windows

package paths

const (
	Socket   = "/var/run/crocell/crocelld.sock"
	StateDir = "/var/db/crocell"
)
