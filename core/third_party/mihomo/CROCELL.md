# mihomo in Crocell

This is [mihomo](https://github.com/MetaCubeX/mihomo) v1.19.33 (GPL-3.0),
with docs, tests and Docker files left out, plus the fixes below. `core/go.mod`
points at it with a `replace`. The fork, bleach, will take its place; until
then every change here is listed in this table.

| File | Change |
|---|---|
| `component/process/process_linux.go` | `resolveSocketByNetlink` no longer falls back to the last socket of the dump when nothing matches. Upstream pinned connections it could not place on a random process, so a rule for Chrome caught Firefox and Telegram traffic. It now also looks for IPv4 connections among AF_INET6 sockets (`::ffff:a.b.c.d`), which is how Firefox connects. Guarded by `core/engine/process_lookup_linux_test.go`. |
| `listener/sing_tun/server_android.go` | `buildAndroidRules` returns early when TUN comes from a VpnService fd or no package/user lists are set. Upstream always started the package manager, which reads `/data/system/packages.xml`; an ordinary app (anything but CMFA's `cmfa` build) may not, so TUN failed on every connect. |

## Moving to a newer mihomo

1. Copy the new release over this directory, leaving out the same files.
2. Redo each change from the table and keep the table current.
3. Bump the version in `core/go.mod`'s `require` and run `make test`.
