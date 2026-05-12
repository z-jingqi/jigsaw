#!/usr/bin/env python3
"""Remove a solid-color image background and write a transparent PNG.

This tool is intended for white/flat-color product images, icons, sprites, and
similar assets. It does not use a machine-learning model; it estimates a
background color from the image corners unless a color is provided explicitly.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, UnidentifiedImageError


@dataclass(frozen=True)
class InputFile:
    path: Path
    relative_path: Path


@dataclass(frozen=True)
class Result:
    src: Path
    dst: Path
    size: tuple[int, int] | None
    removed_pixels: int
    status: str
    detail: str = ""


def non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def bounded_int(min_value: int, max_value: int):
    def parse(value: str) -> int:
        parsed = int(value)
        if parsed < min_value or parsed > max_value:
            raise argparse.ArgumentTypeError(f"must be between {min_value} and {max_value}")
        return parsed

    return parse


def parse_rgb(value: str) -> tuple[int, int, int]:
    text = value.strip()
    if text.startswith("#"):
        hex_value = text[1:]
        if len(hex_value) == 3:
            hex_value = "".join(ch * 2 for ch in hex_value)
        if len(hex_value) != 6:
            raise argparse.ArgumentTypeError("hex color must be #rgb or #rrggbb")
        try:
            return tuple(int(hex_value[index : index + 2], 16) for index in (0, 2, 4))  # type: ignore[return-value]
        except ValueError as exc:
            raise argparse.ArgumentTypeError("hex color contains invalid characters") from exc

    parts = [part.strip() for part in text.split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("color must be #rrggbb or r,g,b")
    try:
        rgb = tuple(int(part) for part in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("rgb color values must be integers") from exc
    if any(channel < 0 or channel > 255 for channel in rgb):
        raise argparse.ArgumentTypeError("rgb color values must be between 0 and 255")
    return rgb  # type: ignore[return-value]


def collect_inputs(inputs: list[Path], recursive: bool) -> list[InputFile]:
    files: list[InputFile] = []
    for input_path in inputs:
        path = input_path.resolve()
        if path.is_dir():
            iterator = path.rglob("*") if recursive else path.iterdir()
            files.extend(
                InputFile(candidate, candidate.relative_to(path))
                for candidate in sorted(iterator)
                if candidate.is_file()
            )
        elif path.is_file():
            files.append(InputFile(path, Path(path.name)))
        else:
            print(f"skip missing path: {path}")
    return files


def output_path_for(input_file: InputFile, output_dir: Path | None, suffix: str) -> Path:
    src = input_file.path
    if output_dir is None:
        return src.with_name(f"{src.stem}{suffix}.png")
    return (output_dir.resolve() / input_file.relative_path).with_suffix(".png").resolve()


def estimate_corner_color(image: Image.Image, sample_size: int) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    sample = max(1, min(sample_size, width, height))
    boxes = (
        (0, 0, sample, sample),
        (width - sample, 0, width, sample),
        (0, height - sample, sample, height),
        (width - sample, height - sample, width, height),
    )

    channels = [0, 0, 0]
    count = 0
    for box in boxes:
        for pixel in rgb.crop(box).getdata():
            channels[0] += pixel[0]
            channels[1] += pixel[1]
            channels[2] += pixel[2]
            count += 1

    return (round(channels[0] / count), round(channels[1] / count), round(channels[2] / count))


def color_distance_sq(pixel: tuple[int, int, int], color: tuple[int, int, int]) -> int:
    return sum((pixel[index] - color[index]) ** 2 for index in range(3))


def connected_background_mask(
    image: Image.Image,
    background: tuple[int, int, int],
    tolerance: int,
    include_interior: bool,
) -> tuple[bytearray, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    limit = tolerance * tolerance
    mask = bytearray(width * height)

    def is_background(x: int, y: int) -> bool:
        return color_distance_sq(pixels[x, y], background) <= limit

    if include_interior:
        removed = 0
        for y in range(height):
            for x in range(width):
                if is_background(x, y):
                    mask[y * width + x] = 1
                    removed += 1
        return mask, removed

    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        for y in (0, height - 1):
            idx = y * width + x
            if mask[idx] == 0 and is_background(x, y):
                mask[idx] = 1
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            idx = y * width + x
            if mask[idx] == 0 and is_background(x, y):
                mask[idx] = 1
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            idx = ny * width + nx
            if mask[idx] or not is_background(nx, ny):
                continue
            mask[idx] = 1
            queue.append((nx, ny))

    return mask, sum(mask)


def expand_mask(mask: bytearray, width: int, height: int, pixels: int) -> bytearray:
    if pixels <= 0:
        return mask

    expanded = bytearray(mask)
    frontier = bytearray(mask)
    for _ in range(pixels):
        next_frontier = bytearray(width * height)
        for y in range(height):
            row = y * width
            for x in range(width):
                idx = row + x
                if frontier[idx] == 0:
                    continue
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    nidx = ny * width + nx
                    if expanded[nidx]:
                        continue
                    expanded[nidx] = 1
                    next_frontier[nidx] = 1
        frontier = next_frontier
    return expanded


def remove_background(
    image: Image.Image,
    background: tuple[int, int, int],
    tolerance: int,
    edge_pixels: int,
    include_interior: bool,
) -> tuple[Image.Image, int]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    mask, removed = connected_background_mask(rgba, background, tolerance, include_interior)
    mask = expand_mask(mask, width, height, edge_pixels)

    data = list(rgba.getdata())
    for index, should_remove in enumerate(mask):
        if should_remove:
            red, green, blue, _alpha = data[index]
            data[index] = (red, green, blue, 0)
    rgba.putdata(data)
    return rgba, removed


def remove_one(
    input_file: InputFile,
    output_dir: Path | None,
    suffix: str,
    color: tuple[int, int, int] | None,
    sample_size: int,
    tolerance: int,
    edge_pixels: int,
    include_interior: bool,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, suffix)
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=f"{src.stem}-",
        suffix=".png",
        dir=dst.parent,
        delete=False,
    ) as handle:
        tmp = Path(handle.name)

    try:
        with Image.open(src) as image:
            background = color or estimate_corner_color(image, sample_size)
            output, removed_pixels = remove_background(image, background, tolerance, edge_pixels, include_interior)
            if removed_pixels == 0:
                return Result(src, dst, image.size, 0, "kept", "no matching background pixels found")
            output.save(tmp, format="PNG", optimize=True, compress_level=9)
            shutil.move(str(tmp), dst)
            detail = f"background rgb={background}, tolerance={tolerance}"
            return Result(src, dst, image.size, removed_pixels, "wrote", detail)
    except UnidentifiedImageError:
        return Result(src, dst, None, 0, "skipped", "not a supported image")
    except Exception as exc:
        return Result(src, dst, None, 0, "skipped", str(exc))
    finally:
        tmp.unlink(missing_ok=True)


def print_result(result: Result) -> None:
    target = "" if result.src == result.dst else f" -> {result.dst}"
    if result.status == "wrote" and result.size:
        total_pixels = result.size[0] * result.size[1]
        percent = result.removed_pixels / total_pixels * 100 if total_pixels else 0
        print(f"wrote {result.src}{target}: removed {result.removed_pixels} pixels ({percent:.1f}%; {result.detail})")
        return
    if result.size:
        print(f"{result.status} {result.src}: {result.size[0]}x{result.size[1]} ({result.detail})")
        return
    print(f"{result.status} {result.src}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove solid-color backgrounds and write transparent PNG files.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to scan")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write transparent PNG files into this directory")
    parser.add_argument(
        "--suffix",
        default="-no-bg",
        help="Suffix used for files written next to inputs. Default: -no-bg",
    )
    parser.add_argument(
        "--color",
        type=parse_rgb,
        help="Background color as #rrggbb or r,g,b. Defaults to the average corner color",
    )
    parser.add_argument(
        "--sample-size",
        type=bounded_int(1, 100),
        default=8,
        help="Corner sample size used for automatic background color detection. Default: 8",
    )
    parser.add_argument(
        "--tolerance",
        type=bounded_int(0, 441),
        default=35,
        help="Maximum RGB distance from the background color. Default: 35",
    )
    parser.add_argument(
        "--edge-pixels",
        type=non_negative_int,
        default=0,
        help="Also clear this many pixels around detected background edges. Default: 0",
    )
    parser.add_argument(
        "--include-interior",
        action="store_true",
        help="Remove matching pixels anywhere, not only background connected to image edges",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files = collect_inputs(args.inputs, args.recursive)
    if not files:
        print("No files to process.")
        return 0

    written = 0
    for input_file in files:
        result = remove_one(
            input_file,
            args.output_dir,
            args.suffix,
            args.color,
            args.sample_size,
            args.tolerance,
            args.edge_pixels,
            args.include_interior,
        )
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
