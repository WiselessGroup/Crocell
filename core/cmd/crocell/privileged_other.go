//go:build !linux && !darwin

package main

// privileged: on Windows wintun itself reports a missing elevation, with a
// clearer message than we could guess here.
func privileged() bool { return true }
