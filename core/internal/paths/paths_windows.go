package paths

const (
	// Dart has no unix sockets on Windows, so the API is on loopback TCP and
	// every call carries the token from TokenFile.
	Socket    = "127.0.0.1:41890"
	TokenFile = `C:\ProgramData\Crocell\client-token`
	// Locked to SYSTEM and Administrators; the token next to it is not.
	StateDir = `C:\ProgramData\Crocell\state`
	Log      = `C:\ProgramData\Crocell\crocelld.log`
)
