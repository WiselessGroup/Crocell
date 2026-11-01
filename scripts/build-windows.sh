#!/usr/bin/env bash
# Builds dist/Crocell-x86_64-Setup.exe on Windows (Git Bash on the CI
# runner). Needs Go, Flutter and Inno Setup 6 (iscc).
#
#   scripts/build-windows.sh [version]
set -euo pipefail

version="${1:-dev}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/dist/windows"
rm -rf "$out" && mkdir -p "$out"

ldflags="-s -w -X git.wiseless.net/fureunoir/crocell/core/internal/version.Version=$version"
cd "$root/core"
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -tags with_gvisor -trimpath -ldflags="$ldflags" -o "$out/crocelld.exe" ./cmd/crocelld

cd "$root/app"
flutter_args=(--release --dart-define="CROCELL_VERSION=$version")
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  flutter_args+=(--build-name="$version" --build-number="${GITHUB_RUN_NUMBER:-1}")
fi
flutter build windows "${flutter_args[@]}"
cp -r build/windows/x64/runner/Release/. "$out/"

iscc_version="$version"
[[ $iscc_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || iscc_version="0.0.0"
iscc="${ISCC:-$(command -v iscc || echo "/c/Program Files (x86)/Inno Setup 6/ISCC.exe")}"
"$iscc" //Q "//DAppVersion=$iscc_version" "//DSourceDir=$(cygpath -w "$out")" "$(cygpath -w "$root/packaging/windows/crocell.iss")"
test -f "$root/dist/Crocell-x86_64-Setup.exe"
