#!/usr/bin/env python3
"""Prepare and optimize PNG UI assets with Pillow.

This tool is intentionally cross-platform: create a project-local virtual
environment, install requirements.txt, then run it with that environment's
Python on Windows or macOS/Linux.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


Rgb = tuple[int, int, int]
Rect = tuple[int, int, int, int]


def open_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True, compress_level=9)


def edge_color(image: Image.Image, prefer_dark: bool) -> Rgb:
    width, height = image.size
    pixels = image.load()
    samples: list[Rgb] = []
    for y in (0, height - 1):
        for x in range(width):
            r, g, b, _a = pixels[x, y]
            samples.append((r, g, b))
    for x in (0, width - 1):
        for y in range(height):
            r, g, b, _a = pixels[x, y]
            samples.append((r, g, b))
    samples.sort(key=sum, reverse=not prefer_dark)
    chosen = samples[: max(1, len(samples) // 4)]
    return (
        round(sum(rgb[0] for rgb in chosen) / len(chosen)),
        round(sum(rgb[1] for rgb in chosen) / len(chosen)),
        round(sum(rgb[2] for rgb in chosen) / len(chosen)),
    )


def rgb_distance(a: Rgb, b: Rgb) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def remove_edge_background(image: Image.Image, threshold: float, prefer_dark: bool) -> Image.Image:
    image = image.copy()
    width, height = image.size
    pixels = image.load()
    bg = edge_color(image, prefer_dark)
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        idx = y * width + x
        if seen[idx]:
            return
        r, g, b, a = pixels[x, y]
        if a != 0 and rgb_distance((r, g, b), bg) > threshold:
            return
        seen[idx] = 1
        queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (255, 255, 255, 0)
        if x > 0:
            push(x - 1, y)
        if x + 1 < width:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y + 1 < height:
            push(x, y + 1)
    return image


def remove_near_white(image: Image.Image, threshold: int) -> Image.Image:
    image = image.copy()
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a and r >= threshold and g >= threshold and b >= threshold:
                pixels[x, y] = (255, 255, 255, 0)
    return image


def trim_transparent(image: Image.Image, padding: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def drop_small_alpha_components(image: Image.Image, min_pixels: int) -> Image.Image:
    if min_pixels <= 0:
        return image
    image = image.copy()
    width, height = image.size
    pixels = image.load()
    seen = bytearray(width * height)

    for sy in range(height):
        for sx in range(width):
            start_idx = sy * width + sx
            if seen[start_idx] or pixels[sx, sy][3] == 0:
                seen[start_idx] = 1
                continue
            queue: deque[tuple[int, int]] = deque([(sx, sy)])
            seen[start_idx] = 1
            component: list[tuple[int, int]] = []
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    idx = ny * width + nx
                    if seen[idx]:
                        continue
                    seen[idx] = 1
                    if pixels[nx, ny][3] > 0:
                        queue.append((nx, ny))
            if len(component) < min_pixels:
                for x, y in component:
                    pixels[x, y] = (255, 255, 255, 0)
    return image


def parse_size(value: str) -> tuple[int, int]:
    parts = value.lower().split("x")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError("expected WIDTHxHEIGHT")
    width, height = int(parts[0]), int(parts[1])
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("dimensions must be > 0")
    return width, height


def process(args: argparse.Namespace) -> None:
    src = args.input.resolve()
    out = args.output.resolve()
    image = open_rgba(src)
    if args.remove_edge_bg:
        image = remove_edge_background(image, args.threshold, args.dark_edge)
    if args.remove_white:
        image = remove_near_white(image, args.white_threshold)
    if args.drop_small_components:
        image = drop_small_alpha_components(image, args.drop_small_components)
    if args.trim:
        image = trim_transparent(image, args.padding)
    if args.resize:
        image = image.resize(args.resize, Image.Resampling.LANCZOS)
    save_png(image, out)
    print(f"Wrote {out} ({image.width}x{image.height}, {out.stat().st_size} bytes)")


def optimize(args: argparse.Namespace) -> None:
    for src in args.images:
        path = src.resolve()
        image = open_rgba(path)
        before = path.stat().st_size
        tmp = path.with_name(f"{path.stem}.optimize-tmp{path.suffix}")
        save_png(image, tmp)
        after = tmp.stat().st_size
        if after < before:
            tmp.replace(path)
            print(f"{path}: {before} -> {after} bytes")
        else:
            tmp.unlink(missing_ok=True)
            print(f"{path}: kept {before} bytes (optimized candidate {after} bytes)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare and losslessly optimize PNG UI assets.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("process", help="Remove simple backgrounds and write PNG")
    p.add_argument("input", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--remove-edge-bg", action="store_true")
    p.add_argument("--dark-edge", action="store_true", help="Sample darker edge colors as background")
    p.add_argument("--threshold", type=float, default=36)
    p.add_argument("--remove-white", action="store_true", help="Make near-white pixels transparent")
    p.add_argument("--white-threshold", type=int, default=248)
    p.add_argument("--drop-small-components", type=int, default=0, help="Remove alpha islands smaller than this pixel count")
    p.add_argument("--trim", action="store_true")
    p.add_argument("--padding", type=int, default=0)
    p.add_argument("--resize", type=parse_size)
    p.set_defaults(func=process)

    o = sub.add_parser("optimize", help="Losslessly re-encode PNG files")
    o.add_argument("images", type=Path, nargs="+")
    o.set_defaults(func=optimize)

    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
