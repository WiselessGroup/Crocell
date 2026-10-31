package sysproxy

import (
	"errors"
	"fmt"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

// WinINet settings: what Edge, Chrome and most Windows apps follow.
const internetSettings = `Software\Microsoft\Windows\CurrentVersion\Internet Settings`

const windowsBypass = "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;169.254.*;<local>"

func set(host string, port int) (Restore, error) {
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettings, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return nil, fmt.Errorf("sysproxy: %w", err)
	}
	defer k.Close()

	prevEnable, _, _ := k.GetIntegerValue("ProxyEnable")
	prevServer, _, errServer := k.GetStringValue("ProxyServer")
	prevOverride, _, errOverride := k.GetStringValue("ProxyOverride")

	err = errors.Join(
		k.SetDWordValue("ProxyEnable", 1),
		k.SetStringValue("ProxyServer", fmt.Sprintf("%s:%d", host, port)),
		k.SetStringValue("ProxyOverride", windowsBypass),
	)
	refresh()
	if err != nil {
		return nil, fmt.Errorf("sysproxy: %w", err)
	}

	return func() error {
		k, err := registry.OpenKey(registry.CURRENT_USER, internetSettings, registry.SET_VALUE)
		if err != nil {
			return fmt.Errorf("sysproxy: %w", err)
		}
		defer k.Close()

		errs := []error{k.SetDWordValue("ProxyEnable", uint32(prevEnable))}
		if errServer == nil {
			errs = append(errs, k.SetStringValue("ProxyServer", prevServer))
		} else {
			_ = k.DeleteValue("ProxyServer")
		}
		if errOverride == nil {
			errs = append(errs, k.SetStringValue("ProxyOverride", prevOverride))
		} else {
			_ = k.DeleteValue("ProxyOverride")
		}
		refresh()
		return errors.Join(errs...)
	}, nil
}

// refresh tells running apps the settings changed.
func refresh() {
	const (
		internetOptionSettingsChanged = 39
		internetOptionRefresh         = 37
	)
	proc := windows.NewLazySystemDLL("wininet.dll").NewProc("InternetSetOptionW")
	_, _, _ = proc.Call(0, internetOptionSettingsChanged, 0, 0)
	_, _, _ = proc.Call(0, internetOptionRefresh, 0, 0)
}
