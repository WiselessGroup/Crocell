//go:build !linux && !windows && !darwin

package main

import (
	"errors"
	"runtime"
)

func install([]string) error {
	return errors.New("service install is not implemented on " + runtime.GOOS + " yet, run crocelld in the foreground")
}

func uninstall() error { return install(nil) }
