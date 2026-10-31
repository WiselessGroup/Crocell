package sysproxy

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// GNOME and everything that reads its gsettings (Cinnamon, Budgie, Pantheon,
// Chrome and Firefox on those desktops). KDE has its own kioslaverc.
func set(host string, port int) (Restore, error) {
	desktop := strings.ToUpper(os.Getenv("XDG_CURRENT_DESKTOP"))
	if strings.Contains(desktop, "KDE") {
		return setKDE(host, port)
	}
	if _, err := lookPath("gsettings"); err == nil {
		return setGNOME(host, port)
	}
	return nil, ErrUnsupported
}

var gnomeKeys = []struct{ schema, key string }{
	{"org.gnome.system.proxy", "mode"},
	{"org.gnome.system.proxy", "ignore-hosts"},
	{"org.gnome.system.proxy.http", "host"},
	{"org.gnome.system.proxy.http", "port"},
	{"org.gnome.system.proxy.https", "host"},
	{"org.gnome.system.proxy.https", "port"},
	{"org.gnome.system.proxy.socks", "host"},
	{"org.gnome.system.proxy.socks", "port"},
}

const gnomeIgnore = "['localhost', '127.0.0.0/8', '::1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '169.254.0.0/16', '*.local']"

func setGNOME(host string, port int) (Restore, error) {
	saved := make([]string, len(gnomeKeys))
	for i, k := range gnomeKeys {
		v, err := run("gsettings", "get", k.schema, k.key)
		if err != nil {
			return nil, fmt.Errorf("sysproxy: gsettings get %s %s: %w", k.schema, k.key, err)
		}
		saved[i] = v
	}

	p := strconv.Itoa(port)
	values := []string{"'manual'", gnomeIgnore, host, p, host, p, host, p}
	if err := gsettingsSet(values); err != nil {
		_ = gsettingsSet(saved)
		return nil, err
	}

	return func() error { return gsettingsSet(saved) }, nil
}

func gsettingsSet(values []string) error {
	var errs []error
	for i, k := range gnomeKeys {
		if _, err := run("gsettings", "set", k.schema, k.key, values[i]); err != nil {
			errs = append(errs, fmt.Errorf("sysproxy: gsettings set %s %s: %w", k.schema, k.key, err))
		}
	}
	return errors.Join(errs...)
}

var kdeKeys = []string{"ProxyType", "httpProxy", "httpsProxy", "socksProxy", "NoProxyFor"}

func setKDE(host string, port int) (Restore, error) {
	write, read := "kwriteconfig6", "kreadconfig6"
	if _, err := lookPath(write); err != nil {
		write, read = "kwriteconfig5", "kreadconfig5"
	}
	if _, err := lookPath(write); err != nil {
		return nil, ErrUnsupported
	}

	saved := make([]string, len(kdeKeys))
	for i, key := range kdeKeys {
		saved[i], _ = run(read, "--file", "kioslaverc", "--group", "Proxy Settings", "--key", key)
	}

	// KDE wants "scheme://host port", with a space.
	addr := fmt.Sprintf("%s %d", host, port)
	values := []string{
		"1", // manual
		"http://" + addr,
		"http://" + addr,
		"socks://" + addr,
		"localhost,127.0.0.0/8,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,.local",
	}

	apply := func(values []string) error {
		var errs []error
		for i, key := range kdeKeys {
			if _, err := run(write, "--file", "kioslaverc", "--group", "Proxy Settings", "--key", key, values[i]); err != nil {
				errs = append(errs, fmt.Errorf("sysproxy: %s %s: %w", write, key, err))
			}
		}
		// Running apps reread the config on this signal.
		_, _ = run("dbus-send", "--type=signal", "/KIO/Scheduler",
			"org.kde.KIO.Scheduler.reparseSlaveConfiguration", "string:")
		return errors.Join(errs...)
	}

	if err := apply(values); err != nil {
		_ = apply(saved)
		return nil, err
	}
	return func() error { return apply(saved) }, nil
}
