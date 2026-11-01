#!/usr/bin/env bash
# Builds dist/Crocell-arm64.dmg on an Apple silicon Mac. Needs Go and
# Flutter. The app is signed ad hoc only: without an Apple Developer
# account macOS asks once, in Privacy & Security, before the first start.
#
#   scripts/build-macos.sh [version]
set -euo pipefail

version="${1:-dev}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dist="$root/dist"
mkdir -p "$dist"

cd "$root/app"
flutter_args=(--release --dart-define="CROCELL_VERSION=$version")
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  flutter_args+=(--build-name="$version" --build-number="${GITHUB_RUN_NUMBER:-1}")
fi
flutter build macos "${flutter_args[@]}"
app="build/macos/Build/Products/Release/Crocell.app"

# The service ships inside the app; "Install service" copies it out.
ldflags="-s -w -X git.wiseless.net/fureunoir/crocell/core/internal/version.Version=$version"
(cd "$root/core" && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -tags with_gvisor -trimpath \
  -ldflags="$ldflags" -o "$root/app/$app/Contents/Resources/crocelld" ./cmd/crocelld)
codesign --force --deep --sign - "$app"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
rm -f "$dist/Crocell-arm64.dmg"
hdiutil create -volname Crocell -srcfolder "$stage" -ov -format UDZO "$dist/Crocell-arm64.dmg"
