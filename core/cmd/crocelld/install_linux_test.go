package main

import (
	"fmt"
	"strings"
	"testing"
)

func TestUnitWithAndWithoutCredential(t *testing.T) {
	with := fmt.Sprintf(unitTemplate, binaryPath, 1000, "LoadCredentialEncrypted=state-key:"+credentialPath+"\n")
	if !strings.Contains(with, "ExecStart=/usr/local/bin/crocelld --allow-uid=1000\nLoadCredentialEncrypted=state-key:/etc/credstore.encrypted/crocell-state-key\nRestart=on-failure") {
		t.Errorf("unit with credential:\n%s", with)
	}
	without := fmt.Sprintf(unitTemplate, binaryPath, 1000, "")
	if !strings.Contains(without, "--allow-uid=1000\nRestart=on-failure") || strings.Contains(without, "%!") {
		t.Errorf("unit without credential:\n%s", without)
	}
}
