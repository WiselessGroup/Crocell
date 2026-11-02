# AGENTS.md

Instructions for any coding agent working in this repository. People will find the friendlier version in [CONTRIBUTING.md](CONTRIBUTING.md).

Crocell is a VPN client for Linux, Windows, macOS and Android: a Flutter app on top of a Go core, which embeds mihomo. There are no servers of ours anywhere in it.

## Where things live

| Path | What's there |
|---|---|
| `app/` | Flutter client. Interface only, no protocol code |
| `core/subscription` | Reads subscriptions, links and configs |
| `core/probe` | Node checks: where a node exits |
| `core/engine` | Starts mihomo, builds rules |
| `core/daemon`, `core/cmd/crocelld` | The desktop service that holds the tunnel |
| `core/cmd/crocell` | CLI for development |
| `core/mobile` | The core as an Android library (gomobile) |
| `core/third_party/mihomo` | mihomo with our fixes, pulled in with a `replace` |
| `proto/` | The API between the client and the core |
| `scripts/` | Package builds, icons |
| `packaging/` | Per-platform package files |

## Commands

Run these before calling a change done. CI runs the same ones.

```bash
cd core && make vet test
cd app && flutter pub get && flutter analyze && flutter test
```

`make vet` also checks the Windows and macOS code, so a Linux machine catches most of what would break there. Use `make` rather than bare `go test`: the TUN code needs the `with_gvisor` tag.

After editing `proto/`, run `make proto` in `core/` (needs `dart pub global activate protoc_plugin`).

## Rules

**Never dial real nodes.** No `crocell nodes -probe`, no `crocell up`, no curl through a proxy. The machine you're on is often behind a VPN already, so the results mean nothing and a second tunnel can break the first. Test with fixtures and `httptest`, then give a person the exact commands to run and ask what happened. Fetching a subscription's body to look at its format is fine.

**Subscription links and node configs are secrets.** They contain access keys. They don't go into commits, tests, logs or issue text. Real samples stay in `core/testdata/private/`, which git ignores.

**The client knows no protocols.** Parsing, checks and tunnel logic go in `core/`. The app talks to it through `proto/`.

**Don't edit generated code.** `core/api/crocellv1` and `app/lib/src/proto` come out of `make proto`.

**Every change to `core/third_party/mihomo` goes in its table** in `core/third_party/mihomo/CROCELL.md`. Without the table, the next mihomo update loses the fix.

**All interface text comes in both languages:** `tr('Русский', 'English')` from `app/lib/l10n.dart`. Widget tests run in Russian and look for the Russian strings.

**The first screen stays short.** A new option goes in Settings, and only if the app can't work it out on its own.

**No telemetry, analytics or accounts.** Any new network call the app makes on its own needs a reason, and the list in the README's "Questions" section has to stay true.

**Icons are generated.** `scripts/make-icons.sh` and `scripts/android-icon-aliases.py` write them. Names have to match `AppIcons.kt` and `app/lib/brand/appearance.dart`.

## Code style

Match the code around you. Comments say why, not what. Commit subjects are one plain line about what changed for the user, with a prefix only when it helps: `crocelld: bound graceful stop so TUN teardown runs`.

## Public texts

This covers the READMEs, release notes, CONTRIBUTING and anything else a stranger reads.

- Write like a person: plain and specific. No em dashes, no marketing words, no emoji headings. If you have a humanizer skill, run the text through it.
- `README.md` and `README.ru.md` say the same thing, and each has a language switch at the top. Change them together. The same goes for `CONTRIBUTING.md` and `CONTRIBUTING.ru.md`.
- READMEs are for users and contributors. Release steps and CI details stay out.

## Repository and releases

- The source of truth is `git.wiseless.net/fureunoir/Crocell`, branch `master`. It pushes to the GitHub mirror, `WiselessGroup/Crocell`, where CI builds and publishes. The Go module path stays `git.wiseless.net/fureunoir/crocell/core`.
- Don't commit, push or tag unless you were asked to. A pushed `v*` tag publishes a release to everyone.
- Release notes go in `.github/release-notes/vX.Y.Z.md`, in Russian, and end with how to update on each system.
- Package names are fixed before 1.0.0 (`Crocell.apk`). From 1.0.0 they carry the version (`Crocell-X.Y.Z.apk`). That rename also touches `scripts/build-*.sh`, `.github/workflows/build.yml`, `app/lib/update/releases.dart`, the download tables in both READMEs and the AppImage update info in `scripts/build-appimage.sh`.
