package logbuf

import (
	"fmt"
	"log"
	"strings"
	"testing"
)

func TestKeepsWholeLinesAndOnlyTheLastOnes(t *testing.T) {
	fmt.Fprint(Ring, "half a ")
	fmt.Fprint(Ring, "line\nsecond\n")
	if got := Text(); !strings.HasSuffix(got, "half a line\nsecond") {
		t.Errorf("text = %q", got)
	}
	l := log.New(Ring, "", 0)
	for i := 0; i < maxLines+10; i++ {
		l.Printf("n%d", i)
	}
	all := strings.Split(Text(), "\n")
	if len(all) != maxLines || all[len(all)-1] != fmt.Sprintf("n%d", maxLines+9) {
		t.Errorf("kept %d lines, last %q", len(all), all[len(all)-1])
	}
	Add("android", "VpnService: denied")
	if !strings.HasSuffix(Text(), "android: VpnService: denied") {
		t.Error("platform line missing")
	}
}
