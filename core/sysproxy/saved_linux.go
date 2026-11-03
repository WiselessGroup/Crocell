package sysproxy

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
)

// RestoreSaved puts back what the app saved in file before pointing the
// desktop at the service, and removes the file: same format and same meaning
// as restore() in app/lib/sysproxy/sysproxy.dart. No file means nothing is set.
// Only GNOME's settings: this is for the GNOME extension, which is the one
// thing still running after the app closes.
func RestoreSaved(file string) error {
	b, err := os.ReadFile(file)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	var saved struct {
		Backend string   `json:"backend"`
		Values  []string `json:"values"`
	}
	if err := json.Unmarshal(b, &saved); err != nil {
		return fmt.Errorf("sysproxy: %s: %w", file, err)
	}
	if saved.Backend != "gnome" {
		return nil
	}
	if len(saved.Values) != len(gnomeKeys) {
		return fmt.Errorf("sysproxy: %s holds %d values, expected %d", file, len(saved.Values), len(gnomeKeys))
	}
	for i, k := range gnomeKeys {
		if _, err := run("gsettings", "set", k.schema, k.key, saved.Values[i]); err != nil {
			return fmt.Errorf("sysproxy: set %s %s: %w", k.schema, k.key, err)
		}
	}
	return os.Remove(file)
}
