#!/usr/bin/env bash
# Regenerates the app icons for Windows, macOS and Android from the brand
# previews. Needs ImageMagick 7 (magick). Run after the logo changes.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
brand="$root/assets/brand/preview"
app="$root/app"
emblem="$brand/crocell-emblem-1024.png"
glyph="$brand/crocell-glyph-1024.png"
mono="$brand/crocell-glyph-mono-1024.png"
paper="#FBF8F7" # CrocellColors.lightBackground: the black wings need a light tile
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Windows: the emblem down to 48 px, the plain glyph below that, where the
# emblem turns to mush.
for s in 256 128 64 48; do magick "$emblem" -resize ${s}x${s} "$tmp/w$s.png"; done
for s in 32 24 16; do magick "$glyph" -resize ${s}x${s} "$tmp/w$s.png"; done
magick "$tmp"/w{256,128,64,48,32,24,16}.png "$app/windows/runner/resources/app_icon.ico"
cp "$app/windows/runner/resources/app_icon.ico" "$root/packaging/windows/crocell.ico"

# macOS: Big Sur style tile, 824 of 1024 with the standard corner radius.
magick -size 1024x1024 xc:none -fill "$paper" -draw "roundrectangle 100,100 923,923 185,185" "$tmp/tile.png"
magick "$tmp/tile.png" \( "$emblem" -resize 700x700 \) -gravity center -composite "$tmp/mac.png"
for s in 16 32 64 128 256 512 1024; do
  magick "$tmp/mac.png" -resize ${s}x${s} "$app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$s.png"
done

# Android: adaptive icon (paper background, emblem inside the 66/108 safe
# zone) plus square legacy icons for old launchers.
res="$app/android/app/src/main/res"
mkdir -p "$res/mipmap-anydpi-v26"
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  name=${d%%:*} k=${d##*:}
  fg=$(python3 -c "print(round(108*$k))")
  inner=$(python3 -c "print(round(66*$k*0.95))")
  legacy=$(python3 -c "print(round(48*$k))")
  mkdir -p "$res/mipmap-$name" "$res/drawable-$name"
  magick -size ${fg}x${fg} xc:none \( "$emblem" -resize ${inner}x${inner} \) -gravity center -composite \
    "$res/mipmap-$name/ic_launcher_foreground.png"
  magick -size ${legacy}x${legacy} xc:"$paper" \( "$emblem" -resize $((legacy*9/10))x$((legacy*9/10)) \) \
    -gravity center -composite "$res/mipmap-$name/ic_launcher.png"
  # Status bar icon: white on transparent, the shape only.
  small=$(python3 -c "print(round(24*$k))")
  magick "$mono" -resize ${small}x${small} -alpha extract -background white -alpha shape \
    "$res/drawable-$name/ic_notification.png"
done
cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$res/values/ic_launcher_background.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$paper</color>
</resources>
XML
echo "icons written"
