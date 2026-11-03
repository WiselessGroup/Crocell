package main

import "errors"

func gnomeExtension([]string) error { return errors.New("GNOME is a Linux desktop") }

func restoreProxy() error { return errors.New("the app does this on macOS") }
