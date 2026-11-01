//go:build !linux && !darwin && !windows

package procs

func list() ([]Process, error) { return nil, nil }
