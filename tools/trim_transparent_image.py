#!/usr/bin/env python3
"""Trim transparent whitespace around image content.

The crop keeps every meaningful alpha-visible component. Tiny isolated alpha
specks are ignored by default so invisible border noise does not block trimming.
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
    before_size: tuple[int, int] | None
    after_size: tuple[int, int] | None
    status: str
    detail: str = ""


def non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def alpha_value(value: str) -> int:
    parsed = int(value)
    if parsed < 1 or parsed > 255:
        raise argparse.ArgumentTypeError("must be between 1 and 255")
    return parsed


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


def output_path_for(input_file: InputFile, output_dir: Path | None) -> Path:
    if output_dir is None:
        return input_file.path
    return (output_dir.resolve() / input_file.relative_path).resolve()


def alpha_bbox(
    image: Image.Image,
    min_alpha: int,
    min_component_pixels: int,
) -> tuple[int, int, int, int] | None:
    alpha = image.convert("RGBA").getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= min_alpha else 0)
    if min_component_pixels <= 1:
        return mask.getbbox()
    return filtered_alpha_bbox(mask, min_component_pixels)


def filtered_alpha_bbox(mask: Image.Image, min_component_pixels: int) -> tuple[int, int, int, int] | None:
    width, height = mask.size
    pixels = mask.load()
    seen = bytearray(width * height)
    kept_bbox: tuple[int, int, int, int] | None = None
    fallback_bbox: tuple[int, int, int, int] | None = None
    fallback_size = 0

    for sy in range(height):
        for sx in range(width):
            start_idx = sy * width + sx
            if seen[start_idx] or pixels[sx, sy] == 0:
                seen[start_idx] = 1
                continue

            queue: deque[tuple[int, int]] = deque([(sx, sy)])
            seen[start_idx] = 1
            count = 0
            left = right = sx
            top = bottom = sy

            while queue:
                x, y = queue.popleft()
                count += 1
                left = min(left, x)
                top = min(top, y)
                right = max(right, x)
                bottom = max(bottom, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    idx = ny * width + nx
                    if seen[idx]:
                        continue
                    seen[idx] = 1
                    if pixels[nx, ny] != 0:
                        queue.append((nx, ny))

            component_bbox = (left, top, right + 1, bottom + 1)
            if count > fallback_size:
                fallback_size = count
                fallback_bbox = component_bbox
            if count < min_component_pixels:
                continue
            kept_bbox = union_bbox(kept_bbox, component_bbox)

    return kept_bbox or fallback_bbox


def union_bbox(
    a: tuple[int, int, int, int] | None,
    b: tuple[int, int, int, int],
) -> tuple[int, int, int, int]:
    if a is None:
        return b
    return (
        min(a[0], b[0]),
        min(a[1], b[1]),
        max(a[2], b[2]),
        max(a[3], b[3]),
    )


def expand_bbox(
    bbox: tuple[int, int, int, int],
    image_size: tuple[int, int],
    padding: int,
) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    width, height = image_size
    return (
        max(0, left - padding),
        max(0, top - padding),
        min(width, right + padding),
        min(height, bottom + padding),
    )


def save_image(image: Image.Image, dst: Path, image_format: str | None) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    save_kwargs: dict[str, object] = {}
    fmt = image_format.upper() if image_format else None
    if fmt == "PNG":
        save_kwargs = {"optimize": True, "compress_level": 9}
    elif fmt == "WEBP":
        save_kwargs = {"lossless": True, "quality": 100, "method": 6}
    image.save(dst, format=image_format, **save_kwargs)


def trim_one(
    input_file: InputFile,
    output_dir: Path | None,
    padding: int,
    min_alpha: int,
    min_component_pixels: int,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir)
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=f"{src.stem}-",
        suffix=src.suffix,
        dir=dst.parent,
        delete=False,
    ) as handle:
        tmp = Path(handle.name)

    try:
        with Image.open(src) as image:
            image_format = image.format
            before_size = image.size
            bbox = alpha_bbox(image, min_alpha, min_component_pixels)
            if bbox is None:
                return Result(src, dst, before_size, None, "skipped", "image is fully transparent")
            crop_box = expand_bbox(bbox, before_size, padding)
            if crop_box == (0, 0, image.width, image.height):
                return Result(src, dst, before_size, before_size, "kept", "no transparent border to trim")
            cropped = image.crop(crop_box)
            save_image(cropped, tmp, image_format)
            shutil.move(str(tmp), dst)
            return Result(src, dst, before_size, cropped.size, "wrote")
    except UnidentifiedImageError:
        return Result(src, dst, None, None, "skipped", "not a supported image")
    except Exception as exc:
        return Result(src, dst, None, None, "skipped", str(exc))
    finally:
        tmp.unlink(missing_ok=True)


def print_result(result: Result) -> None:
    target = "" if result.src == result.dst else f" -> {result.dst}"
    if result.status == "wrote" and result.before_size and result.after_size:
        print(f"wrote {result.src}{target}: {result.before_size[0]}x{result.before_size[1]} -> {result.after_size[0]}x{result.after_size[1]}")
        return
    if result.before_size and result.after_size:
        print(f"{result.status} {result.src}: {result.before_size[0]}x{result.before_size[1]} ({result.detail})")
        return
    print(f"{result.status} {result.src}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Trim transparent whitespace while keeping all alpha-visible pixels inside the crop.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to scan")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write trimmed files into this directory")
    parser.add_argument("--padding", type=non_negative_int, default=0, help="Transparent padding to keep. Default: 0")
    parser.add_argument(
        "--min-alpha",
        type=alpha_value,
        default=1,
        help="Minimum alpha treated as content before noise filtering. Default: 1",
    )
    parser.add_argument(
        "--min-component-pixels",
        type=non_negative_int,
        default=8,
        help="Ignore isolated alpha components smaller than this. Default: 8",
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
        result = trim_one(input_file, args.output_dir, args.padding, args.min_alpha, args.min_component_pixels)
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
