package main

import "errors"

func ctl(string) error { return errors.New("not available on Windows") }

func gnomeExtension([]string) error { return errors.New("GNOME is not on Windows") }
