#!/usr/bin/env python3
"""Android launcher icons, one per picture and background: the glyph as vector
drawables, an adaptive icon and a pre-Oreo fallback for each pair, and the
activity-alias block in the manifest. Names match AppIcons.kt and
lib/brand/appearance.dart."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
res = root / "app/android/app/src/main/res"
manifest = root / "app/android/app/src/main/AndroidManifest.xml"

svg = (root / "assets/brand/crocell-glyph.svg").read_text()
paths = {k: re.search(rf'id="{k}"[^>]*d="([^"]+)"', svg).group(1) for k in ("wings", "figure", "star")}

RED, ACCENT, EMBER, WHITE = "#E9524E", "#860111", "#D4572A", "#FAF8F8"
# wings, figure, star: the same colours as AppArt in appearance.dart.
GLYPHS = {
    "glyph_red": (RED, ACCENT, RED),
    "glyph_ember": (EMBER, WHITE, EMBER),
    "glyph_white": (WHITE, WHITE, WHITE),
    "glyph_inverse": (WHITE, RED, WHITE),
}
FIGURES = ("crocell", "crocell_grey")
BACKGROUNDS = {"dark": "#0E0B0B", "paper": "#FBF8F7", "crimson": "#860111", "ember": "#D4572A"}
DEFAULT = "Icon_glyph_red_dark"

# The glyph inside the 66 of 108 dp safe zone of an adaptive icon.
SCALE = 66 / 32
OFFSET = (108 - 66) / 2

def luminance(color):
    def channel(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (int(color[k:k + 2], 16) for k in (1, 3, 5))
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def ratio(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def on_background(layer, bg):
    """Same as onIconBackground in appearance.dart."""
    if ratio(layer, bg) >= 1.6:
        return layer
    return "#FAF8F8" if ratio("#FAF8F8", bg) >= ratio("#1A1212", bg) else "#1A1212"


drawable = res / "drawable"
drawable.mkdir(exist_ok=True)
for stale in drawable.glob("fg_*.xml"):
    stale.unlink()
for name, (wings, figure, star) in GLYPHS.items():
    for bg, color in BACKGROUNDS.items():
        (drawable / f"fg_{name}_{bg}.xml").write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="{OFFSET}" android:translateY="{OFFSET}"
        android:scaleX="{SCALE:.4f}" android:scaleY="{SCALE:.4f}">
        <path android:fillColor="{on_background(wings, color)}" android:pathData="{paths['wings']}"/>
        <path android:fillColor="{on_background(figure, color)}" android:pathData="{paths['figure']}"/>
        <path android:fillColor="{on_background(star, color)}" android:pathData="{paths['star']}"/>
    </group>
</vector>
""")

adaptive = res / "mipmap-anydpi-v26"
adaptive.mkdir(exist_ok=True)
aliases = []
for art in [*GLYPHS, *FIGURES]:
    for bg, color in BACKGROUNDS.items():
        fg = f"@drawable/fg_{art}_{bg}" if art in GLYPHS else f"@mipmap/fg_{art}"
        icon = f"icon_{art}_{bg}"
        (adaptive / f"{icon}.xml").write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/icon_bg_{bg}"/>
    <foreground android:drawable="{fg}"/>
</adaptive-icon>
""")
        # Android 7: no adaptive icons, a plain layer list in the same name.
        (res / "mipmap-anydpi").mkdir(exist_ok=True)
        (res / "mipmap-anydpi" / f"{icon}.xml").write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/icon_bg_{bg}"/>
    <item android:drawable="{fg}"/>
</layer-list>
""")
        alias = f"Icon_{art}_{bg}"
        aliases.append(f"""        <activity-alias
            android:name=".{alias}"
            android:targetActivity=".MainActivity"
            android:exported="true"
            android:enabled="{'true' if alias == DEFAULT else 'false'}"
            android:icon="@mipmap/{icon}">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>""")

colors = "".join(f'    <color name="icon_bg_{b}">{c}</color>\n' for b, c in BACKGROUNDS.items())
(res / "values/icon_backgrounds.xml").write_text(
    f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n{colors}</resources>\n'
)

text = manifest.read_text()
block = "<!-- icons:begin (written by scripts/make-icons.sh) -->\n" + "\n".join(aliases) + "\n        <!-- icons:end -->"
text = re.sub(r"<!-- icons:begin.*?<!-- icons:end -->", lambda _: block, text, flags=re.S)
manifest.write_text(text)
print(f"{len(aliases)} aliases")
