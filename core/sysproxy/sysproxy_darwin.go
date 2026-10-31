package sysproxy

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// macOS keeps proxy settings per network service (Wi-Fi, Ethernet, ...).
// We set all enabled services, since we can't know which one is in use.

var darwinKinds = []struct{ get, set, state string }{
	{"-getwebproxy", "-setwebproxy", "-setwebproxystate"},
	{"-getsecurewebproxy", "-setsecurewebproxy", "-setsecurewebproxystate"},
	{"-getsocksfirewallproxy", "-setsocksfirewallproxy", "-setsocksfirewallproxystate"},
}

var darwinBypass = []string{
	"localhost", "127.0.0.0/8", "::1", "10.0.0.0/8", "172.16.0.0/12",
	"192.168.0.0/16", "169.254.0.0/16", "*.local",
}

type darwinProxy struct {
	enabled bool
	server  string
	port    string
}

func set(host string, port int) (Restore, error) {
	services, err := darwinServices()
	if err != nil {
		return nil, err
	}

	type savedService struct {
		name    string
		proxies []darwinProxy
		bypass  []string
	}
	saved := make([]savedService, 0, len(services))

	for _, svc := range services {
		s := savedService{name: svc}
		for _, k := range darwinKinds {
			out, _ := run("networksetup", k.get, svc)
			s.proxies = append(s.proxies, parseDarwinProxy(out))
		}
		out, _ := run("networksetup", "-getproxybypassdomains", svc)
		if !strings.Contains(out, "There aren't any") {
			s.bypass = strings.Fields(out)
		}
		saved = append(saved, s)
	}

	p := strconv.Itoa(port)
	var errs []error
	for _, svc := range services {
		for _, k := range darwinKinds {
			if _, err := run("networksetup", k.set, svc, host, p); err != nil {
				errs = append(errs, fmt.Errorf("sysproxy: %s %s: %w", k.set, svc, err))
			}
		}
		args := append([]string{"-setproxybypassdomains", svc}, darwinBypass...)
		if _, err := run("networksetup", args...); err != nil {
			errs = append(errs, err)
		}
	}

	restore := func() error {
		var errs []error
		for _, s := range saved {
			for i, k := range darwinKinds {
				prev := s.proxies[i]
				if prev.enabled && prev.server != "" {
					_, err := run("networksetup", k.set, s.name, prev.server, prev.port)
					errs = append(errs, err)
				} else {
					_, err := run("networksetup", k.state, s.name, "off")
					errs = append(errs, err)
				}
			}
			bypass := s.bypass
			if len(bypass) == 0 {
				bypass = []string{"Empty"}
			}
			_, err := run("networksetup", append([]string{"-setproxybypassdomains", s.name}, bypass...)...)
			errs = append(errs, err)
		}
		return errors.Join(errs...)
	}

	if err := errors.Join(errs...); err != nil {
		_ = restore()
		return nil, err
	}
	return restore, nil
}

func darwinServices() ([]string, error) {
	out, err := run("networksetup", "-listallnetworkservices")
	if err != nil {
		return nil, fmt.Errorf("sysproxy: networksetup: %w", err)
	}
	var services []string
	for i, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		// First line is a notice; disabled services start with '*'.
		if i == 0 || line == "" || strings.HasPrefix(line, "*") {
			continue
		}
		services = append(services, line)
	}
	if len(services) == 0 {
		return nil, ErrUnsupported
	}
	return services, nil
}

func parseDarwinProxy(out string) darwinProxy {
	var p darwinProxy
	for _, line := range strings.Split(out, "\n") {
		key, value, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		value = strings.TrimSpace(value)
		switch strings.TrimSpace(key) {
		case "Enabled":
			p.enabled = value == "Yes"
		case "Server":
			p.server = value
		case "Port":
			p.port = value
		}
	}
	return p
}
