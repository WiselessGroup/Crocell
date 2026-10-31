//go:build !linux && !darwin && !windows

package sysproxy

func set(string, int) (Restore, error) {
	return nil, ErrUnsupported
}
