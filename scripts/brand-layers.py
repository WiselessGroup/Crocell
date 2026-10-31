#!/usr/bin/env python3
"""Split assets/brand/crocell-mark-winged.svg into stackable layers for the app.

Flutter can't animate groups inside one SVG, so the connect button stacks
three files with the same viewBox: wing-left, wing-right, figure.

    python3 scripts/brand-layers.py
"""
import pathlib
import xml.etree.ElementTree as ET

NS = "http://www.w3.org/2000/svg"
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/brand/crocell-mark-winged.svg"
OUT = ROOT / "app/assets/brand"

ET.register_namespace("", NS)
src = ET.parse(SRC).getroot()
OUT.mkdir(parents=True, exist_ok=True)

for part in ("wing-left", "wing-right", "figure"):
    groups = [c for c in src if c.get("id") == part]
    if not groups:
        raise SystemExit(f"{SRC.name}: no <g id={part!r}>")
    svg = ET.Element(f"{{{NS}}}svg", {"viewBox": src.get("viewBox")})
    svg.extend(groups)
    ET.ElementTree(svg).write(OUT / f"{part}.svg", encoding="unicode")
    print(f"wrote {OUT / part}.svg")
