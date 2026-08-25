#!/usr/bin/env python3
"""Add a solid rounded sticker border around a transparent image."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageColor, ImageOps


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Transparent source image")
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--color", default="#F3E5CE", help="Border RGB color")
    parser.add_argument("--radius", type=positive_int, default=12)
    parser.add_argument("--padding", type=positive_int, default=16)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def circular_dilate(alpha: np.ndarray, radius: int) -> np.ndarray:
    height, width = alpha.shape
    expanded = np.zeros_like(alpha)
    for offset_y in range(-radius, radius + 1):
        max_x = int((radius * radius - offset_y * offset_y) ** 0.5)
        for offset_x in range(-max_x, max_x + 1):
            source_x = max(0, -offset_x)
            source_y = max(0, -offset_y)
            target_x = max(0, offset_x)
            target_y = max(0, offset_y)
            copy_width = width - abs(offset_x)
            copy_height = height - abs(offset_y)
            if copy_width <= 0 or copy_height <= 0:
                continue
            source = alpha[
                source_y : source_y + copy_height,
                source_x : source_x + copy_width,
            ]
            target = expanded[
                target_y : target_y + copy_height,
                target_x : target_x + copy_width,
            ]
            np.maximum(target, source, out=target)
    return expanded


def main() -> int:
    args = parse_args()
    if not args.input.is_file():
        raise SystemExit(f"missing input: {args.input}")
    if args.output.exists() and not args.overwrite:
        raise SystemExit(f"output exists (pass --overwrite): {args.output}")
    if args.padding <= args.radius:
        raise SystemExit("--padding must be greater than --radius")

    source = Image.open(args.input).convert("RGBA")
    padded = ImageOps.expand(source, border=args.padding, fill=(0, 0, 0, 0))
    source_pixels = np.asarray(padded, dtype=np.uint8)
    expanded_alpha = circular_dilate(source_pixels[..., 3], args.radius)
    red, green, blue = ImageColor.getrgb(args.color)

    border_pixels = np.zeros_like(source_pixels)
    border_pixels[..., 0] = red
    border_pixels[..., 1] = green
    border_pixels[..., 2] = blue
    border_pixels[..., 3] = expanded_alpha
    bordered = Image.alpha_composite(Image.fromarray(border_pixels), padded)
    result = np.asarray(bordered).copy()
    result[..., :3][result[..., 3] == 0] = 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(result).save(args.output, optimize=True, compress_level=9)
    print(
        f"bordered {args.input} -> {args.output}; color={args.color.upper()} "
        f"radius={args.radius} padding={args.padding}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
