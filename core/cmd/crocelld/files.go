package main

import (
	"io"
	"os"
	"path/filepath"
	"strconv"
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
