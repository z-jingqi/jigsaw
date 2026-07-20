#!/usr/bin/env python3
"""Neutralize green/magenta spill in semi-transparent image edges."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, UnidentifiedImageError


def iter_inputs(paths: list[Path], recursive: bool) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_file():
            files.append(path)
            continue
        if not path.is_dir():
            continue
        pattern = "**/*.png" if recursive else "*.png"
        files.extend(candidate for candidate in path.glob(pattern) if candidate.is_file())
    return sorted(set(files))


def output_path(source: Path, output_dir: Path | None, suffix: str) -> Path:
    if output_dir is not None:
        return output_dir / source.name
    return source.with_name(f"{source.stem}{suffix}.png")


def neutralize(source: Path, destination: Path, max_alpha: int, clear_alpha: int) -> int:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    corrected = 0
    pixels = []
    for red, green, blue, alpha in image.getdata():
        if alpha <= clear_alpha:
            pixels.append((0, 0, 0, 0))
            corrected += 1
            continue
        if alpha < max_alpha:
            neutral_green = (red + blue) // 2
            pixels.append((red, neutral_green, blue, alpha))
            corrected += 1
            continue
        pixels.append((red, green, blue, alpha))
    image.putdata(pixels)
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, format="PNG", optimize=True)
    return corrected


def bounded_byte(value: str) -> int:
    parsed = int(value)
    if not 0 <= parsed <= 255:
        raise argparse.ArgumentTypeError("must be between 0 and 255")
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("-r", "--recursive", action="store_true")
    parser.add_argument("-o", "--output-dir", type=Path)
    parser.add_argument("--suffix", default="-neutral")
    parser.add_argument("--max-alpha", type=bounded_byte, default=250)
    parser.add_argument("--clear-alpha", type=bounded_byte, default=4)
    args = parser.parse_args()
    files = iter_inputs(args.inputs, args.recursive)
    if not files:
        raise SystemExit("No PNG files found")
    for source in files:
        destination = output_path(source, args.output_dir, args.suffix)
        try:
            corrected = neutralize(source, destination, args.max_alpha, args.clear_alpha)
        except (OSError, UnidentifiedImageError) as error:
            print(f"skipped {source}: {error}")
            continue
        print(f"wrote {source} -> {destination}: corrected {corrected} edge pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
