package procs

import (
	"unsafe"

	"golang.org/x/sys/windows"
)

// Windows: a toolhelp snapshot for names, QueryFullProcessImageName for
// paths where we may open the process.
func list() ([]Process, error) {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil, err
	}
	defer windows.CloseHandle(snap)

	var out []Process
	var e windows.ProcessEntry32
	e.Size = uint32(unsafe.Sizeof(e))
	for err = windows.Process32First(snap, &e); err == nil; err = windows.Process32Next(snap, &e) {
		p := Process{Name: windows.UTF16ToString(e.ExeFile[:])}
		if h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, e.ProcessID); err == nil {
			buf := make([]uint16, windows.MAX_LONG_PATH)
			n := uint32(len(buf))
			if windows.QueryFullProcessImageName(h, 0, &buf[0], &n) == nil {
				p.Path = windows.UTF16ToString(buf[:n])
			}
			windows.CloseHandle(h)
		}
		out = append(out, p)
	}
	return out, nil
}
