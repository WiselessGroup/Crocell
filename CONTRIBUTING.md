# Contributing to Crocell

**English** &nbsp;|&nbsp; [Русский](CONTRIBUTING.ru.md)

Issues and pull requests go on [GitHub](https://github.com/WiselessGroup/Crocell), in English or Russian.

## You don't need to write code

The most useful thing right now is a good bug report. I can't test every provider and every network, so a report that a subscription didn't parse or a node died on your OS tells me something I couldn't find out alone.

**Before you post anything, remember that a subscription link is a key to your VPN.** So is a `vless://` link or a config. Anyone who reads it can use your traffic quota. The "Logs" button in the app takes subscription links out of what it copies, but look through the text anyway. If a format doesn't parse, send its shape with the server, UUID and keys replaced.

A good report has the Crocell version, your system, proxy or tunnel mode, the node's protocol, and the logs. The [bug form](https://github.com/WiselessGroup/Crocell/issues/new?template=bug_report.yml) asks for all of that.

## Before a big change

Open an issue first if the change is more than a bug fix. Two things are unlikely to get in:

- **More on the first screen.** A short first screen is the reason Crocell exists. New options go in Settings, and only if the app can't work out the answer itself.
- **Telemetry, accounts, ads.** No exceptions.

A third language is welcome, but texts live as `tr('ru', 'en')` pairs in the code, so it needs a change to how that works. Let's talk it through first.

## Setting up

You need [Go](https://go.dev/dl/) 1.26+ and [Flutter](https://docs.flutter.dev/get-started/install) 3.47+. On Debian or Ubuntu the Linux desktop build also wants:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

Run the app against a service on your machine:

```bash
cd core && make install-daemon     # Linux: installs and starts crocelld
cd ../app && flutter run -d linux
```

`CROCELL_SOCKET=/path/to/crocelld.sock` points the client at a service you started by hand. For work on the core alone, the `crocell` CLI is quicker, see [Building from source](README.md#building-from-source).

## Where to change what

- Parsing a new link or config format: `core/subscription`, with a test next to it.
- Node checks: `core/probe`. Tunnel and rules: `core/engine`. The service: `core/daemon`.
- Anything on screen: `app/lib/ui`. All text in both languages, `tr('Русский', 'English')`. If you don't speak Russian, write the English and say so in the PR, I'll add the other half.
- The API between the two: `proto/`, then `make proto` in `core/`. Don't edit the generated code.
- mihomo: `core/third_party/mihomo`, and add a row to the table in its `CROCELL.md`, or the next update loses your fix.

## Before you open a pull request

```bash
cd core && make vet test
cd app && flutter analyze && flutter test
```

CI runs the same commands, but it has no VPN nodes to connect to. If your change touches the tunnel or the checks, say in the PR what you tried by hand, on which system, and with which protocol. Use your own node for that.

Keep a PR to one change. Screenshots help if the interface moved.

## How a pull request lands

The GitHub repository is a mirror of the one I work in, so the green merge button isn't used. I apply your commits there, your name stays on them, and they come back to GitHub's `master` through the mirror. Then I close the PR with a note.

## AI tools

They're fine, but you answer for the result: read it, run it, and be ready to explain it. Rules for coding agents are in [AGENTS.md](AGENTS.md), and most tools pick that file up on their own.

## Security problems

Don't open a public issue for these, see [SECURITY.md](SECURITY.md).

## License

Crocell is [GPL-3.0](LICENSE). By sending a contribution you agree that it's released under the same license.
