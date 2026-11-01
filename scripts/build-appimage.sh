#!/usr/bin/env bash
# Builds dist/Crocell-x86_64.AppImage and its .zsync.
#
#   scripts/build-appimage.sh [version]
#
# Needs Go, Flutter with the Linux desktop toolchain, and appimagetool in
# PATH or $APPIMAGETOOL. Without appimagetool it stops after assembling
# dist/AppDir, which is enough to check the layout.
set -euo pipefail

version="${1:-dev}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/dist"
appdir="$out/AppDir"
# Gear Lever and AppImageUpdate read this from the image and fetch the
# .zsync of the latest GitHub release. Asset names carry no version, so
# the address stays the same from release to release.
update_info="gh-releases-zsync|WiselessGroup|Crocell|latest|Crocell-x86_64.AppImage.zsync"

rm -rf "$appdir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/lib/crocell" \
  "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"

# Only the service: the CLI would carry a second copy of mihomo for
# what the app already does. Static, because `crocelld install` copies
# the service out of the image and the copy runs with nothing from it.
cd "$root/core"
CGO_ENABLED=0 go build -tags with_gvisor -trimpath \
  -ldflags="-s -w -X git.wiseless.net/fureunoir/crocell/core/internal/version.Version=$version" \
  -o "$appdir/usr/bin/crocelld" ./cmd/crocelld

cd "$root/app"
flutter_args=(--release --dart-define="CROCELL_VERSION=$version")
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  flutter_args+=(--build-name="$version" --build-number="${GITHUB_RUN_NUMBER:-1}")
fi
flutter build linux "${flutter_args[@]}"
cp -r build/linux/x64/release/bundle/. "$appdir/usr/lib/crocell/"

linux="$root/packaging/linux"
install -m755 "$linux/AppRun" "$appdir/AppRun"
install -m644 "$linux/crocell.png" "$appdir/crocell.png"
install -m644 "$linux/crocell.png" "$appdir/usr/share/icons/hicolor/256x256/apps/crocell.png"
install -m644 "$linux/crocell.desktop" "$appdir/usr/share/applications/crocell.desktop"
{ cat "$linux/crocell.desktop"; echo "X-AppImage-Version=$version"; } > "$appdir/crocell.desktop"

tool="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
if [[ -z $tool ]]; then
  echo "AppDir is ready at $appdir. Install appimagetool to pack it." >&2
  exit 0
fi
cd "$out"
rm -f Crocell-x86_64.AppImage Crocell-x86_64.AppImage.zsync
ARCH=x86_64 "$tool" -u "$update_info" "$appdir" Crocell-x86_64.AppImage
test -f Crocell-x86_64.AppImage.zsync || { echo "appimagetool made no .zsync (is zsyncmake installed?)" >&2; exit 1; }
