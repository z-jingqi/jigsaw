#!/usr/bin/env python3
"""Prepare image assets by removing background, trimming, then compressing.

Pipeline:
1. Remove a solid-color background and make it transparent.
2. Trim transparent margins around the remaining content.
3. Compress the final PNG if doing so keeps geometry and alpha intact.
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, UnidentifiedImageError

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import compress_images
import remove_solid_background
import trim_transparent_image


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
    removed_pixels: int
    before_bytes: int | None
    after_bytes: int | None
    status: str
    detail: str = ""


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


def trim_image(
    image: Image.Image,
    padding: int,
    min_alpha: int,
    min_component_pixels: int,
) -> tuple[Image.Image, tuple[int, int], tuple[int, int]]:
    before_size = image.size
    bbox = trim_transparent_image.alpha_bbox(image, min_alpha, min_component_pixels)
    if bbox is None:
        raise ValueError("image is fully transparent after background removal")

    crop_box = trim_transparent_image.expand_bbox(bbox, before_size, padding)
    if crop_box == (0, 0, image.width, image.height):
        return image, before_size, before_size
    cropped = image.crop(crop_box)
    return cropped, before_size, cropped.size


def save_png(image: Image.Image, path: Path) -> None:
    image.save(path, format="PNG", optimize=True, compress_level=9)


def compressed_or_original(
    src: Path,
    temp_dir: Path,
    min_savings: int,
    png_colors: int,
    jpeg_quality: int,
    webp_quality: int,
) -> tuple[Path, compress_images.Result]:
    compressed = temp_dir / f"{src.stem}-compressed.png"
    result = compress_images.compress_one(src, compressed, min_savings, png_colors, jpeg_quality, webp_quality)
    if result.status == "wrote":
        return compressed, result
    return src, result


def process_one(
    input_file: InputFile,
    output_dir: Path | None,
    suffix: str,
    color: tuple[int, int, int] | None,
    sample_size: int,
    tolerance: int,
    edge_pixels: int,
    include_interior: bool,
    padding: int,
    min_alpha: int,
    min_component_pixels: int,
    min_savings: int,
    png_colors: int,
    jpeg_quality: int,
    webp_quality: int,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, suffix)
    dst.parent.mkdir(parents=True, exist_ok=True)

    try:
        before_bytes = src.stat().st_size
        with tempfile.TemporaryDirectory(prefix=f"{src.stem}-", dir=dst.parent) as temp_name:
            temp_dir = Path(temp_name)
            uncompressed = temp_dir / f"{src.stem}.png"

            with Image.open(src) as image:
                background = color or remove_solid_background.estimate_corner_color(image, sample_size)
                no_background, removed_pixels = remove_solid_background.remove_background(
                    image,
                    background,
                    tolerance,
                    edge_pixels,
                    include_interior,
                )
                output, before_size, after_size = trim_image(
                    no_background,
                    padding,
                    min_alpha,
                    min_component_pixels,
                )
                save_png(output, uncompressed)

            final_candidate, compression = compressed_or_original(
                uncompressed,
                temp_dir,
                min_savings,
                png_colors,
                jpeg_quality,
                webp_quality,
            )
            shutil.copyfile(final_candidate, dst)
            after_bytes = dst.stat().st_size
            detail = (
                f"background rgb={background}, tolerance={tolerance}, "
                f"compression={compression.status}"
            )
            return Result(src, dst, before_size, after_size, removed_pixels, before_bytes, after_bytes, "wrote", detail)
    except UnidentifiedImageError:
        return Result(src, dst, None, None, 0, None, None, "skipped", "not a supported image")
    except Exception as exc:
        return Result(src, dst, None, None, 0, None, None, "skipped", str(exc))


def print_result(result: Result) -> None:
    target = "" if result.src == result.dst else f" -> {result.dst}"
    if result.status == "wrote" and result.before_size and result.after_size and result.before_bytes is not None and result.after_bytes is not None:
        delta = result.after_bytes - result.before_bytes
        percent = abs(delta) / result.before_bytes * 100 if result.before_bytes else 0
        byte_change = f"{percent:.1f}% smaller" if delta < 0 else f"{percent:.1f}% larger"
        if delta == 0:
            byte_change = "same size"
        print(
            f"wrote {result.src}{target}: "
            f"{result.before_size[0]}x{result.before_size[1]} -> {result.after_size[0]}x{result.after_size[1]}, "
            f"removed {result.removed_pixels} background pixels, "
            f"{result.before_bytes} -> {result.after_bytes} bytes ({byte_change}; {result.detail})"
        )
        return
    print(f"{result.status} {result.src}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove solid background, trim transparent margins, and compress image assets.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to scan")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write processed PNG files into this directory")
    parser.add_argument(
        "--suffix",
        default="-processed",
        help="Suffix used for files written next to inputs. Default: -processed",
    )

    background = parser.add_argument_group("background removal")
    background.add_argument(
        "--color",
        type=remove_solid_background.parse_rgb,
        help="Background color as #rrggbb or r,g,b. Defaults to the average corner color",
    )
    background.add_argument(
        "--sample-size",
        type=remove_solid_background.bounded_int(1, 100),
        default=8,
        help="Corner sample size used for automatic background color detection. Default: 8",
    )
    background.add_argument(
        "--tolerance",
        type=remove_solid_background.bounded_int(0, 441),
        default=35,
        help="Maximum RGB distance from the background color. Default: 35",
    )
    background.add_argument(
        "--edge-pixels",
        type=remove_solid_background.non_negative_int,
        default=0,
        help="Also clear this many pixels around detected background edges. Default: 0",
    )
    background.add_argument(
        "--include-interior",
        action="store_true",
        help="Remove matching pixels anywhere, not only background connected to image edges",
    )

    trim = parser.add_argument_group("transparent margin trimming")
    trim.add_argument(
        "--padding",
        type=trim_transparent_image.non_negative_int,
        default=0,
        help="Transparent padding to keep after trimming. Default: 0",
    )
    trim.add_argument(
        "--min-alpha",
        type=trim_transparent_image.alpha_value,
        default=1,
        help="Minimum alpha treated as content before noise filtering. Default: 1",
    )
    trim.add_argument(
        "--min-component-pixels",
        type=trim_transparent_image.non_negative_int,
        default=8,
        help="Ignore isolated alpha components smaller than this. Default: 8",
    )

    compression = parser.add_argument_group("compression")
    compression.add_argument(
        "--min-savings",
        type=compress_images.positive_int,
        default=1,
        help="Minimum bytes saved before using compressed candidate. Default: 1",
    )
    compression.add_argument(
        "--png-colors",
        type=compress_images.bounded_int(2, 256),
        default=256,
        help="Maximum colors for PNG palette compression. Default: 256",
    )
    compression.add_argument(
        "--jpeg-quality",
        type=compress_images.bounded_int(1, 100),
        default=88,
        help="JPEG quality passed through to the compressor. Default: 88",
    )
    compression.add_argument(
        "--webp-quality",
        type=compress_images.bounded_int(1, 100),
        default=86,
        help="WebP quality passed through to the compressor. Default: 86",
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
        result = process_one(
            input_file,
            args.output_dir,
            args.suffix,
            args.color,
            args.sample_size,
            args.tolerance,
            args.edge_pixels,
            args.include_interior,
            args.padding,
            args.min_alpha,
            args.min_component_pixels,
            args.min_savings,
            args.png_colors,
            args.jpeg_quality,
            args.webp_quality,
        )
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
