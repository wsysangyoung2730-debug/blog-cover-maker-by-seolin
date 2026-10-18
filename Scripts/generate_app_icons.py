#!/usr/bin/env python3
"""Resize the approved icon master into Apple's macOS and iPadOS icon slots."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Design/Branding/blog-cover-maker-icon.png"
CATALOG = ROOT / "App/Resources/Assets.xcassets"
INFO = {"author": "xcode", "version": 1}


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def generate(name, slots):
    destination = CATALOG / (name + ".appiconset")
    destination.mkdir(parents=True, exist_ok=True)
    rendered = set()
    images = []
    for idiom, points, scale in slots:
        pixels = int(points * scale)
        filename = f"icon-{pixels}.png"
        if pixels not in rendered:
            subprocess.run(
                ["sips", "-z", str(pixels), str(pixels), str(SOURCE), "--out", str(destination / filename)],
                check=True, stdout=subprocess.DEVNULL,
            )
            rendered.add(pixels)
        images.append({"idiom": idiom, "size": f"{points:g}x{points:g}",
                       "scale": f"{scale}x", "filename": filename})
    write_json(destination / "Contents.json", {"images": images, "info": INFO})


if not SOURCE.is_file():
    raise SystemExit(f"아이콘 원본이 없습니다: {SOURCE}")
CATALOG.mkdir(parents=True, exist_ok=True)
write_json(CATALOG / "Contents.json", {"info": INFO})
generate("AppIconMac", [("mac", size, scale) for size in [16, 32, 128, 256, 512] for scale in [1, 2]])
generate("AppIconPad", [("ipad", size, scale) for size in [20, 29, 40, 76] for scale in [1, 2]]
         + [("ipad", 83.5, 2), ("ios-marketing", 1024, 1)])
print("Generated macOS and iPadOS app icons from the approved master")
