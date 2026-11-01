package main

import (
	"bytes"
	"crypto/rand"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
)

const (
	unitPath = "/etc/systemd/system/crocelld.service"
	// /usr/local/bin, not /usr/local/lib: on SELinux systems (Fedora, RHEL)
	// files under lib get lib_t, systemd then runs them in its own init_t
	// domain, and init_t may not open outgoing connections. bin_t starts as
	// unconfined_service_t like any other service.
	binaryPath = "/usr/local/bin/crocelld"
	// Where 0.1 installed it; cleaned up on install and uninstall.
	legacyBinaryDir = "/usr/local/lib/crocell"

	// The state encryption key, sealed by systemd-creds with the TPM (if
	// there is one) and the host key. systemd decrypts it into the
	// service's $CREDENTIALS_DIRECTORY; on another machine it is noise.
	credentialPath = "/etc/credstore.encrypted/crocell-state-key"
	plainKeyPath   = "/var/lib/crocell/state.key"
)

// The service runs as root: TUN needs CAP_NET_ADMIN, and sing-tun configures
// DNS through resolvectl, which polkit only lets root do without a password.
// Capabilities are bounded to the network ones, the rest of the system is
// read-only.
const unitTemplate = `[Unit]
Description=Crocell VPN core
Documentation=https://git.wiseless.net/fureunoir/Crocell
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=%s --allow-uid=%d
%sRestart=on-failure
RestartSec=2
RuntimeDirectory=crocell
StateDirectory=crocell
StateDirectoryMode=0700
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_DAC_READ_SEARCH CAP_SYS_PTRACE
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
`

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
	if err := copyFile(self, binaryPath, 0o755); err != nil {
		return fmt.Errorf("copy binary: %w", err)
	}
	relabel(binaryPath)
	_ = os.RemoveAll(legacyBinaryDir)

	credLine := ""
	if err := sealStateKey(); err != nil {
		fmt.Fprintf(os.Stderr, "crocelld: no sealed key (%v); state is encrypted with a root-only key file instead\n", err)
	} else {
		credLine = "LoadCredentialEncrypted=state-key:" + credentialPath + "\n"
	}
	unit := fmt.Sprintf(unitTemplate, binaryPath, *uid, credLine)
	if err := os.WriteFile(unitPath, []byte(unit), 0o644); err != nil {
		return err
	}
	if err := systemctl("daemon-reload"); err != nil {
		return err
	}
	// restart, not just start: reinstalling must pick up the new binary.
	if err := systemctl("enable", "crocelld"); err != nil {
		return err
	}
	if err := systemctl("restart", "crocelld"); err != nil {
		return err
	}
	fmt.Printf("crocelld installed to %s and running, controlled by uid %d\n", binaryPath, *uid)
	return nil
}

func uninstall() error {
	if os.Geteuid() != 0 {
		return errors.New("uninstall needs root: sudo crocelld uninstall")
	}
	_ = systemctl("disable", "--now", "crocelld")
	for _, p := range []string{unitPath, binaryPath} {
		if err := os.Remove(p); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	_ = os.RemoveAll(legacyBinaryDir)
	_ = systemctl("daemon-reload")
	fmt.Println("crocelld removed. Subscriptions stay in /var/lib/crocell (encrypted with " + credentialPath + "); delete both to forget them.")
	return nil
}

// sealStateKey creates the systemd credential holding the state key. An
// existing plain key file (a manual run, or before this existed) is sealed
// as is, so the state written with it still opens, and then removed.
func sealStateKey() error {
	tool, err := exec.LookPath("systemd-creds")
	if err != nil {
		return err
	}
	if _, err := os.Stat(credentialPath); err == nil {
		return nil // reinstall: keep the key the state is sealed with
	}

	key, err := os.ReadFile(plainKeyPath)
	if err != nil || len(key) < 32 {
		key = make([]byte, 32)
		if _, err := io.ReadFull(rand.Reader, key); err != nil {
			return err
		}
	}
	if err := os.MkdirAll(filepath.Dir(credentialPath), 0o700); err != nil {
		return err
	}
	cmd := exec.Command(tool, "encrypt", "--name=state-key", "-", credentialPath)
	cmd.Stdin = bytes.NewReader(key)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("systemd-creds encrypt: %v: %s", err, bytes.TrimSpace(out))
	}
	if err := os.Remove(plainKeyPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

// relabel gives the binary its default SELinux label. A file renamed into
// place can keep the label of where it was created. No SELinux, no-op.
func relabel(path string) {
	if restorecon, err := exec.LookPath("restorecon"); err == nil {
		_ = exec.Command(restorecon, path).Run()
	}
}

func sudoUID() int {
	n, _ := strconv.Atoi(os.Getenv("SUDO_UID"))
	return n
}

func systemctl(args ...string) error {
	cmd := exec.Command("systemctl", args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("systemctl %v: %w", args, err)
	}
	return nil
}

func copyFile(src, dst string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	tmp := dst + ".new"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	// rename over a running binary is fine on Linux, writing into it is not.
	return os.Rename(tmp, dst)
}
