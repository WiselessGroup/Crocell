// Package logbuf keeps the last lines the core logged, so the app can show
// them and the person can copy them into a bug report. Nothing is written
// to disk by this package: the system logs stay where they were.
package logbuf

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
)

const maxLines = 1500

var (
	mu    sync.Mutex
	lines []string
	part  []byte // a line written in pieces, until its newline
)

// Ring is an io.Writer that keeps whole lines.
var Ring io.Writer = ring{}

type ring struct{}

func (ring) Write(p []byte) (int, error) {
	mu.Lock()
	defer mu.Unlock()
	part = append(part, p...)
	for {
		i := bytes.IndexByte(part, '\n')
		if i < 0 {
			break
		}
		add(string(part[:i]))
		part = part[i+1:]
	}
	return len(p), nil
}

func add(line string) {
	if strings.TrimSpace(line) == "" {
		return
	}
	lines = append(lines, line)
	if len(lines) > maxLines {
		lines = append(lines[:0:0], lines[len(lines)-maxLines:]...)
	}
}

// Capture tees the standard logger and mihomo's (logrus) into the ring,
// keeping wherever they wrote before.
func Capture() {
	log.SetOutput(io.MultiWriter(log.Writer(), Ring))
	logrus.SetOutput(io.MultiWriter(logrus.StandardLogger().Out, Ring))
}

// Add records a line from outside Go, the Android side for one.
func Add(source, text string) {
	mu.Lock()
	defer mu.Unlock()
	for _, l := range strings.Split(strings.TrimRight(text, "\n"), "\n") {
		add(fmt.Sprintf("%s %s: %s", time.Now().Format("2006/01/02 15:04:05"), source, l))
	}
}

// Text is everything kept, oldest first.
func Text() string {
	mu.Lock()
	defer mu.Unlock()
	return strings.Join(lines, "\n")
}
