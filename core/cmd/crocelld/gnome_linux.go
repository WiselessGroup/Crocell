package main

import (
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

//go:embed gnome
var gnomeFiles embed.FS

const gnomeUUID = "crocell@wiseless.net"

// gnomeExtension installs or removes the GNOME quick toggle for the person
// running it (not root: extensions live in the home directory).
func gnomeExtension(args []string) error {
	if os.Geteuid() == 0 {
		return errors.New("run this as yourself, not root: the extension goes into your home directory")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	data := os.Getenv("XDG_DATA_HOME")
	if data == "" {
		data = filepath.Join(home, ".local", "share")
	}
	dir := filepath.Join(data, "gnome-shell", "extensions", gnomeUUID)

	cmd := "install"
	if len(args) > 0 {
		cmd = args[0]
	}
	switch cmd {
	case "install":
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
		err := fs.WalkDir(gnomeFiles, "gnome", func(path string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return err
			}
			b, err := gnomeFiles.ReadFile(path)
			if err != nil {
				return err
			}
			return os.WriteFile(filepath.Join(dir, filepath.Base(path)), b, 0o644)
		})
		if err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(dir, "crocelld-path"), []byte(serviceBinary()), 0o644); err != nil {
			return err
		}
		enableGnomeExtension()
		fmt.Println("Installed. Log out and back in once, then Crocell is in Quick Settings.")
		return nil
	case "uninstall":
		_ = exec.Command("gnome-extensions", "disable", gnomeUUID).Run()
		return os.RemoveAll(dir)
	}
	return fmt.Errorf("unknown command %q: install or uninstall", cmd)
}

// serviceBinary is the crocelld the toggle runs: the installed copy, since
// one inside an AppImage disappears when the image is closed.
func serviceBinary() string {
	if _, err := os.Stat(binaryPath); err == nil {
		return binaryPath
	}
	self, _ := os.Executable()
	return self
}

// enableGnomeExtension turns it on. A running Shell only knows about
// extensions it saw at login, so gnome-extensions may refuse; the setting
// is then edited directly and takes effect at the next login.
func enableGnomeExtension() {
	if exec.Command("gnome-extensions", "enable", gnomeUUID).Run() == nil {
		return
	}
	out, err := exec.Command("gsettings", "get", "org.gnome.shell", "enabled-extensions").Output()
	if err != nil {
		return
	}
	list := strings.TrimSpace(string(out))
	if strings.Contains(list, gnomeUUID) {
		return
	}
	switch {
	case strings.HasPrefix(list, "@as []"), list == "[]":
		list = "['" + gnomeUUID + "']"
	default:
		list = strings.TrimSuffix(list, "]") + ", '" + gnomeUUID + "']"
	}
	_ = exec.Command("gsettings", "set", "org.gnome.shell", "enabled-extensions", list).Run()
}
