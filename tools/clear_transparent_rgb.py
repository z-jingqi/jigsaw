#!/usr/bin/env python3
"""Clear hidden RGB values under fully transparent pixels."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument(
        "--alpha-threshold",
        type=int,
        default=0,
        help="Make pixels at or below this alpha fully transparent (default: 0)",
    )
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.input.is_file():
        raise SystemExit(f"missing input: {args.input}")
    if args.output.exists() and not args.overwrite:
        raise SystemExit(f"output exists (pass --overwrite): {args.output}")
    if not 0 <= args.alpha_threshold <= 254:
        raise SystemExit("--alpha-threshold must be between 0 and 254")

    pixels = np.asarray(Image.open(args.input).convert("RGBA")).copy()
    transparent = pixels[..., 3] <= args.alpha_threshold
    changed = int(np.count_nonzero(np.any(pixels[..., :3][transparent] != 0, axis=1)))
    pixels[..., :3][transparent] = 0
    pixels[..., 3][transparent] = 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels).save(args.output, optimize=True, compress_level=9)
    print(
        f"cleared hidden RGB in {changed} pixels at alpha <= {args.alpha_threshold}: "
        f"{args.input} -> {args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
