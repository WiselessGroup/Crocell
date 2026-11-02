#!/usr/bin/env bash
# Builds dist/Crocell.apk: the app around the Go core's AAR, for arm64 and
# 32-bit arm phones in one APK. The AAR is built if it is not there yet
# (CI brings it from cache; run build-android-core.sh after changing the core). Release signing comes from
# android/key.properties or ANDROID_KEYSTORE_FILE / ANDROID_KEYSTORE_PASSWORD.
#
#   scripts/build-android.sh [version]
set -euo pipefail
version="${1:-dev}"
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$root/app/android/app/libs/crocellcore.aar" ]] || "$root/scripts/build-android-core.sh"

cd "$root/app"
flutter_args=(--release --target-platform android-arm,android-arm64 --dart-define="CROCELL_VERSION=$version")
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  flutter_args+=(--build-name="$version" --build-number="${GITHUB_RUN_NUMBER:-1}")
fi
flutter build apk "${flutter_args[@]}"
mkdir -p "$root/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$root/dist/Crocell.apk"
