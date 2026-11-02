#!/usr/bin/env bash
# Builds the Go core as app/android/app/libs/crocellcore.aar for the APK.
# Needs Go, the Android SDK with an NDK, and gomobile:
#   go install golang.org/x/mobile/cmd/gomobile@latest golang.org/x/mobile/cmd/gobind@latest
#
# The version is not built in: the app passes it at start, so the same core
# gives the same file and CI can reuse it across releases.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
if [[ -z ${ANDROID_NDK_HOME:-} ]]; then
  ANDROID_NDK_HOME="$(ls -d "$ANDROID_HOME"/ndk/* | sort -V | tail -1)"
  export ANDROID_NDK_HOME
fi
mkdir -p "$root/app/android/app/libs"
cd "$root/core"
# arm64 and armv7: phones. CROCELL_ANDROID_TARGETS=...,android/amd64 adds
# x86_64 for the emulator.
gomobile bind -target="${CROCELL_ANDROID_TARGETS:-android/arm64,android/arm}" -androidapi 24 \
  -javapkg=net.wiseless.crocell.core -tags with_gvisor -trimpath \
  -ldflags="-s -w" \
  -o "$root/app/android/app/libs/crocellcore.aar" ./mobile
rm -f "$root/app/android/app/libs/crocellcore-sources.jar"
