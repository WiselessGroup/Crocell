package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

const (
	label = "net.wiseless.crocelld"
	// Root-owned, outside the app: replacing Crocell.app must not change
	// what runs as root until the person agrees to reinstall.
	binaryPath = "/Library/PrivilegedHelperTools/net.wiseless.crocelld"
	plistPath  = "/Library/LaunchDaemons/net.wiseless.crocelld.plist"
	logPath    = "/Library/Logs/Crocell/crocelld.log"
)

const plistTemplate = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>%s</string>
	<key>ProgramArguments</key>
	<array>
		<string>%s</string>
		<string>--allow-uid=%d</string>
		<string>--log=%s</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
</dict>
</plist>
`

// install copies crocelld out of the app and runs it with launchd as root.
// The app runs this through "do shell script … with administrator
// privileges" and passes its own uid, since root has no SUDO_UID there.
func install(args []string) error {
	fs := flag.NewFlagSet("install", flag.ExitOnError)
	uid := fs.Int("uid", sudoUID(), "user allowed to control the service")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if os.Geteuid() != 0 {
		return errors.New("install needs root: sudo crocelld install")
	}
	if *uid <= 0 {
		return errors.New("which user will control Crocell? pass -uid, or run through sudo")
	}
	self, err := os.Executable()
	if err != nil {
		return err
	}

	_ = launchctl("bootout", "system/"+label) // reinstall: stop the old one
	if err := copyFile(self, binaryPath, 0o755); err != nil {
		return fmt.Errorf("copy binary: %w", err)
	}
	plist := fmt.Sprintf(plistTemplate, label, binaryPath, *uid, logPath)
	if err := os.WriteFile(plistPath, []byte(plist), 0o644); err != nil {
		return err
	}
	// bootout returns before launchd has let go of the label, and bootstrap
	// then fails with a bare "Input/output error" for a moment.
	for try := 0; ; try++ {
		err = launchctl("bootstrap", "system", plistPath)
		if err == nil || try == 10 {
			break
		}
		time.Sleep(300 * time.Millisecond)
	}
	if err != nil {
		return err
	}
	fmt.Printf("crocelld installed to %s and running, controlled by uid %d\n", binaryPath, *uid)
	return nil
}

func uninstall() error {
	if os.Geteuid() != 0 {
		return errors.New("uninstall needs root: sudo crocelld uninstall")
	}
	_ = launchctl("bootout", "system/"+label)
	for _, p := range []string{plistPath, binaryPath} {
		if err := os.Remove(p); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	fmt.Println("crocelld removed. Subscriptions stay in /Library/Application Support/Crocell; delete it to forget them.")
	return nil
}

func launchctl(args ...string) error {
	out, err := exec.Command("launchctl", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("launchctl %s: %v: %s", strings.Join(args, " "), err, strings.TrimSpace(string(out)))
	}
	return nil
}
