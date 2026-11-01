package geo

import (
	"os"
	"runtime"
	"testing"
)

// Runs against a real runetfreedom file when CROCELL_GEOSITE points at one.
func TestRealGeoSiteCheaply(t *testing.T) {
	path := os.Getenv("CROCELL_GEOSITE")
	if path == "" {
		t.Skip("set CROCELL_GEOSITE to a geosite.dat")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var before, after runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&before)
	cats, err := categories(data)
	runtime.ReadMemStats(&after)
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("%d categories from %d MB, allocated %d KB", len(cats), len(data)>>20, (after.TotalAlloc-before.TotalAlloc)>>10)
	if len(cats) < 100 {
		t.Errorf("only %d categories", len(cats))
	}
}
