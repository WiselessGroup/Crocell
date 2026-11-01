package daemon

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// The state file holds subscription links and node credentials. On disk it
// is AES-256-GCM, so a copied file (backup, seized disk, another app with a
// file scanner) says nothing about which VPN someone uses.
//
// The key comes from, in order:
//  1. $CREDENTIALS_DIRECTORY/state-key: systemd hands it over decrypted
//     from a credential sealed with the TPM or the host key (crocelld
//     install sets this up with systemd-creds). The file alone is useless
//     on another machine.
//  2. state.key next to the state, created on first run, root-only. For
//     manual runs and systems without systemd-creds.
//
// On Android the key will come from the Keystore through the same seam.

var stateMagic = []byte("CRC1")

const keyCredential = "state-key"

type sealer struct{ aead cipher.AEAD }

func newSealer(stateDir string) (*sealer, error) {
	material, err := keyMaterial(stateDir)
	if err != nil {
		return nil, err
	}
	sum := sha256.Sum256(material) // any length in, 256 bits out
	block, err := aes.NewCipher(sum[:])
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	return &sealer{aead: aead}, nil
}

func keyMaterial(stateDir string) ([]byte, error) {
	if dir := os.Getenv("CREDENTIALS_DIRECTORY"); dir != "" {
		if b, err := os.ReadFile(filepath.Join(dir, keyCredential)); err == nil && len(b) >= 32 {
			return b, nil
		}
	}

	path := filepath.Join(stateDir, "state.key")
	b, err := os.ReadFile(path)
	if err == nil && len(b) >= 32 {
		return b, nil
	}
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, fmt.Errorf("daemon: read key: %w", err)
	}

	key := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		return nil, err
	}
	if err := os.WriteFile(path, key, 0o600); err != nil {
		return nil, fmt.Errorf("daemon: write key: %w", err)
	}
	return key, nil
}

func (s *sealer) seal(plain []byte) ([]byte, error) {
	nonce := make([]byte, s.aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	out := append([]byte{}, stateMagic...)
	out = append(out, nonce...)
	return s.aead.Seal(out, nonce, plain, stateMagic), nil
}

func (s *sealer) open(data []byte) ([]byte, error) {
	if !bytes.HasPrefix(data, stateMagic) {
		return nil, errors.New("daemon: state file is not encrypted state")
	}
	data = data[len(stateMagic):]
	n := s.aead.NonceSize()
	if len(data) < n {
		return nil, errors.New("daemon: state file truncated")
	}
	plain, err := s.aead.Open(nil, data[:n], data[n:], stateMagic)
	if err != nil {
		return nil, errors.New("daemon: state file does not decrypt with this machine's key")
	}
	return plain, nil
}
