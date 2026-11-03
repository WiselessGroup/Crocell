package sysproxy

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// fakeGsettings is an in-memory gsettings store.
type fakeGsettings map[string]string

func (f fakeGsettings) install(t *testing.T) {
	t.Helper()
	oldRun, oldLook := run, lookPath
	t.Cleanup(func() { run, lookPath = oldRun, oldLook })

	lookPath = func(name string) (string, error) { return "/usr/bin/" + name, nil }
	run = func(name string, args ...string) (string, error) {
		if name != "gsettings" {
			t.Fatalf("unexpected command %s %v", name, args)
		}
		key := args[1] + " " + args[2]
		switch args[0] {
		case "get":
			return f[key], nil
		case "set":
			f[key] = args[3]
			return "", nil
		}
		t.Fatalf("unexpected gsettings %v", args)
		return "", nil
	}
}

func TestGNOMESetAndRestore(t *testing.T) {
	t.Setenv("XDG_CURRENT_DESKTOP", "GNOME")
	store := fakeGsettings{
		"org.gnome.system.proxy mode":         "'none'",
		"org.gnome.system.proxy ignore-hosts": "['localhost']",
		"org.gnome.system.proxy.http host":    "''",
		"org.gnome.system.proxy.http port":    "0",
		"org.gnome.system.proxy.https host":   "''",
		"org.gnome.system.proxy.https port":   "0",
		"org.gnome.system.proxy.socks host":   "'old.example'",
		"org.gnome.system.proxy.socks port":   "1080",
	}
	before := map[string]string{}
	for k, v := range store {
		before[k] = v
	}
	store.install(t)

	restore, err := Set("127.0.0.1", 7890)
	if err != nil {
		t.Fatal(err)
	}
	if store["org.gnome.system.proxy mode"] != "'manual'" {
		t.Errorf("mode = %s", store["org.gnome.system.proxy mode"])
	}
	if store["org.gnome.system.proxy.socks port"] != "7890" || store["org.gnome.system.proxy.https host"] != "127.0.0.1" {
		t.Errorf("proxy not set: %v", store)
	}
	if !strings.Contains(store["org.gnome.system.proxy ignore-hosts"], "192.168.0.0/16") {
		t.Errorf("LAN must bypass the proxy: %s", store["org.gnome.system.proxy ignore-hosts"])
	}

	if err := restore(); err != nil {
		t.Fatal(err)
	}
	for k, v := range before {
		if store[k] != v {
			t.Errorf("%s = %s after restore, want %s", k, store[k], v)
		}
	}
}

func TestNoDesktopIsUnsupported(t *testing.T) {
	t.Setenv("XDG_CURRENT_DESKTOP", "")
	oldLook := lookPath
	t.Cleanup(func() { lookPath = oldLook })
	lookPath = func(string) (string, error) { return "", errNotFound }

	if _, err := Set("127.0.0.1", 7890); err != ErrUnsupported {
		t.Errorf("err = %v, want ErrUnsupported", err)
	}
}

var errNotFound = &notFound{}

type notFound struct{}

func (*notFound) Error() string { return "not found" }

func TestRestoreSavedPutsBackWhatTheAppSaved(t *testing.T) {
	store := fakeGsettings{}
	store.install(t)
	file := filepath.Join(t.TempDir(), "sysproxy.json")
	saved := `{"backend":"gnome","values":["'none'","['localhost']","''","0","''","0","''","0"]}`
	if err := os.WriteFile(file, []byte(saved), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := RestoreSaved(file); err != nil {
		t.Fatal(err)
	}
	if store["org.gnome.system.proxy mode"] != "'none'" || store["org.gnome.system.proxy.socks port"] != "0" {
		t.Errorf("store = %v", store)
	}
	if _, err := os.Stat(file); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("the file should be gone: %v", err)
	}
	// Run again: nothing left to do, and that is fine.
	if err := RestoreSaved(file); err != nil {
		t.Error(err)
	}
}

func TestRestoreSavedLeavesOtherDesktopsAlone(t *testing.T) {
	fakeGsettings{}.install(t)
	file := filepath.Join(t.TempDir(), "sysproxy.json")
	if err := os.WriteFile(file, []byte(`{"backend":"kde","values":["1"]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := RestoreSaved(file); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(file); err != nil {
		t.Errorf("the file is for the app to handle: %v", err)
	}
}
