#!/usr/bin/env bash
# Regenerates the app icons from the brand files. Needs ImageMagick 7
# (magick). Run after the logo changes.
#
# Default icon: the glyph on dark, on Windows, macOS and Android. Linux keeps
# the figure (packaging/linux/crocell.png): an app cannot change its icon
# there, so it has no "Customize" either.
# Android also gets one launcher alias per picture and background.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
brand="$root/assets/brand/preview"
app="$root/app"
figure="$brand/crocell-mark-winged-1024.png"
glyph="$brand/crocell-glyph-1024.png"
mono="$brand/crocell-glyph-mono-1024.png"
dark="#0E0B0B"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Windows: dark rounded tile, down to 16 px.
magick -size 1024x1024 xc:none -fill "$dark" -draw "roundrectangle 0,0 1023,1023 190,190" "$tmp/tile.png"
magick "$tmp/tile.png" \( "$glyph" -resize 780x780 \) -gravity center -composite "$tmp/win.png"
for s in 256 128 64 48 32 24 16; do magick "$tmp/win.png" -resize ${s}x${s} "$tmp/w$s.png"; done
magick "$tmp"/w{256,128,64,48,32,24,16}.png "$app/windows/runner/resources/app_icon.ico"
cp "$app/windows/runner/resources/app_icon.ico" "$root/packaging/windows/crocell.ico"

# macOS: Big Sur style tile, 824 of 1024 with the standard corner radius.
magick -size 1024x1024 xc:none -fill "$dark" -draw "roundrectangle 100,100 923,923 185,185" "$tmp/tile.png"
magick "$tmp/tile.png" \( "$glyph" -resize 620x620 \) -gravity center -composite "$tmp/mac.png"
for s in 16 32 64 128 256 512 1024; do
  magick "$tmp/mac.png" -resize ${s}x${s} "$app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$s.png"
done

# Android: raster parts per density. Foregrounds of the figure (the glyph's
# are vectors), legacy square icon, status bar icon.
res="$app/android/app/src/main/res"
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  name=${d%%:*} k=${d##*:}
  fg=$(python3 -c "print(round(108*$k))")
  inner=$(python3 -c "print(round(66*$k))")
  legacy=$(python3 -c "print(round(48*$k))")
  small=$(python3 -c "print(round(24*$k))")
  mkdir -p "$res/mipmap-$name" "$res/drawable-$name"
  magick -size ${fg}x${fg} xc:none \( "$figure" -resize ${inner}x${inner} \) -gravity center -composite \
    "$res/mipmap-$name/fg_crocell.png"
  magick "$res/mipmap-$name/fg_crocell.png" -colorspace Gray -colorspace sRGB "$res/mipmap-$name/fg_crocell_grey.png"
  magick -size ${legacy}x${legacy} xc:"$dark" \( "$glyph" -resize $((legacy*3/4))x$((legacy*3/4)) \) \
    -gravity center -composite "$res/mipmap-$name/ic_launcher.png"
  rm -f "$res/mipmap-$name/ic_launcher_foreground.png"
  magick "$mono" -resize ${small}x${small} -alpha extract -background white -alpha shape \
    "$res/drawable-$name/ic_notification.png"
done
rm -f "$res/mipmap-anydpi-v26/ic_launcher.xml" "$res/values/ic_launcher_background.xml"

python3 "$root/scripts/android-icon-aliases.py"
echo "icons written"
