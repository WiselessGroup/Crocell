package procs

import (
	"os"
	"testing"
)

func TestListSeesThisProcess(t *testing.T) {
	self, _ := os.Executable()
	list, err := List()
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range list {
		if p.Path == self {
			return
		}
	}
	t.Errorf("own executable %s not in %d processes", self, len(list))
}
