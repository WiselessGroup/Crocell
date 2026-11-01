//go:build tools

package mobile

// gomobile bind compiles against this package; the import keeps it in
// go.mod through go mod tidy.
import _ "golang.org/x/mobile/bind"
