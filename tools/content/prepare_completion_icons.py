"""Encode rasterized completion glyphs as small lossless WebP with verified alpha."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Folder containing rasterized 192px PNG glyphs")
    args = parser.parse_args()
    results = []
    for mode in ("polygon", "knob", "swap"):
        source = args.source / (mode + "-complete.png")
        target = ROOT / "assets/ui/levels/mode-icons" / (mode + "-complete.webp")
        with Image.open(source) as raw:
            image = raw.convert("RGBA").resize((96, 96), Image.Resampling.LANCZOS)
            if image.getchannel("A").getextrema() != (0, 255):
                raise ValueError(f"Missing real alpha: {source}")
            image.save(target, "WEBP", lossless=True, method=6, exact=True)
        with Image.open(target) as saved:
            saved.load()
            alpha = saved.getchannel("A")
            if alpha.tobytes() != image.getchannel("A").tobytes():
                raise ValueError(f"Alpha changed: {target}")
            partial = sum(1 for pixel in alpha.tobytes() if 0 < pixel < 255)
            if saved.size != (96, 96) or not partial or saved.getpixel((0, 0))[3]:
                raise ValueError(f"Invalid transparent edges: {target}")
        results.append({"mode": mode, "path": str(target.relative_to(ROOT)), "bytes": target.stat().st_size,
                        "partial_alpha_pixels": partial, "transparent_corners": True})
    print(json.dumps({"ok": True, "icons": results}))


if __name__ == "__main__":
    main()
