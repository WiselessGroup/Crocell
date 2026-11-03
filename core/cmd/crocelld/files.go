package main

import (
	"io"
	"log"
	"os"
	"path/filepath"
	"strconv"

	"git.wiseless.net/fureunoir/crocell/core/killswitch"
)

func sudoUID() int {
	n, _ := strconv.Atoi(os.Getenv("SUDO_UID"))
	return n
}

func copyFile(src, dst string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	tmp := dst + ".new"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	// rename over a running binary is fine on Linux, writing into it is not.
	return os.Rename(tmp, dst)
}

// liftKillSwitch takes the firewall rules away with the service. Left behind
// with no service to remove them, they would cut the person off for good.
func liftKillSwitch() {
	if err := killswitch.New().Unblock(); err != nil {
		log.Printf("crocelld: Kill Switch: %v", err)
	}
}
