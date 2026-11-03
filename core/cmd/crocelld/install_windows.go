package main

import (
	"errors"
	"fmt"
	"os"
	"time"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

// install registers crocelld, from where it is now, as an automatic
// service running as LocalSystem: TUN needs it. The Crocell installer puts
// the binary in Program Files, where only administrators can replace it,
// and runs this after copying files.
func install([]string) error {
	self, err := os.Executable()
	if err != nil {
		return err
	}
	m, err := mgr.Connect()
	if err != nil {
		return adminHint(err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(serviceName)
	if err == nil {
		// Reinstall: the binary may have moved, and must restart either way.
		if err := stopService(s); err != nil {
			s.Close()
			return err
		}
		cfg, err := s.Config()
		if err == nil {
			cfg.BinaryPathName = `"` + self + `"`
			cfg.StartType = mgr.StartAutomatic
			err = s.UpdateConfig(cfg)
		}
		if err != nil {
			s.Close()
			return fmt.Errorf("update service: %w", err)
		}
	} else {
		s, err = m.CreateService(serviceName, self, mgr.Config{
			DisplayName: "Crocell",
			Description: "Crocell VPN core: holds the tunnel for the Crocell app.",
			StartType:   mgr.StartAutomatic,
		})
		if err != nil {
			return adminHint(fmt.Errorf("create service: %w", err))
		}
	}
	defer s.Close()

	restart := mgr.RecoveryAction{Type: mgr.ServiceRestart, Delay: 2 * time.Second}
	if err := s.SetRecoveryActions([]mgr.RecoveryAction{restart, restart, restart}, 60); err != nil {
		return fmt.Errorf("recovery actions: %w", err)
	}
	if err := s.Start(); err != nil {
		return fmt.Errorf("start service: %w", err)
	}
	fmt.Printf("crocelld installed from %s and running\n", self)
	return nil
}

func uninstall() error {
	m, err := mgr.Connect()
	if err != nil {
		return adminHint(err)
	}
	defer m.Disconnect()
	s, err := m.OpenService(serviceName)
	if err != nil {
		liftKillSwitch()
		fmt.Println("crocelld is not installed")
		return nil
	}
	defer s.Close()
	if err := stopService(s); err != nil {
		return err
	}
	liftKillSwitch()
	if err := s.Delete(); err != nil {
		return fmt.Errorf("delete service: %w", err)
	}
	fmt.Println(`crocelld removed. Subscriptions stay in C:\ProgramData\Crocell; delete it to forget them.`)
	return nil
}

// stopService stops the service and waits until it has, so the installer
// can replace the binary right after.
func stopService(s *mgr.Service) error {
	st, err := s.Query()
	if err != nil {
		return err
	}
	if st.State == svc.Stopped {
		return nil
	}
	if st.State != svc.StopPending {
		if _, err := s.Control(svc.Stop); err != nil {
			return fmt.Errorf("stop service: %w", err)
		}
	}
	for deadline := time.Now().Add(30 * time.Second); time.Now().Before(deadline); time.Sleep(300 * time.Millisecond) {
		if st, err = s.Query(); err != nil || st.State == svc.Stopped {
			return err
		}
	}
	return errors.New("the service did not stop in 30 seconds")
}

func adminHint(err error) error {
	if errors.Is(err, windows.ERROR_ACCESS_DENIED) {
		return errors.New("this needs administrator rights: run it from an elevated prompt")
	}
	return err
}
