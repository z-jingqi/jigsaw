#!/usr/bin/env python3
"""Shrink image files with visually near-lossless compression.

The tool accepts files or directories, keeps each file's original format, and
only writes a result when the candidate is smaller and preserves image geometry.
For images with transparency, alpha and fully transparent pixels are preserved.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageSequence, UnidentifiedImageError


@dataclass(frozen=True)
class Result:
    src: Path
    dst: Path
    before: int
    after: int | None
    status: str
    detail: str = ""


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def bounded_int(min_value: int, max_value: int):
    def parse(value: str) -> int:
        parsed = int(value)
        if parsed < min_value or parsed > max_value:
            raise argparse.ArgumentTypeError(f"must be between {min_value} and {max_value}")
        return parsed

    return parse


def collect_inputs(inputs: list[Path], recursive: bool) -> list[Path]:
    files: list[Path] = []
    for input_path in inputs:
        path = input_path.resolve()
        if path.is_dir():
            iterator = path.rglob("*") if recursive else path.iterdir()
            files.extend(sorted(candidate for candidate in iterator if candidate.is_file()))
        elif path.is_file():
            files.append(path)
        else:
            print(f"skip missing path: {path}")
    return files


def output_path_for(src: Path, output_dir: Path | None) -> Path:
    if output_dir is None:
        return src
    return (output_dir.resolve() / src.name).resolve()


def frame_geometry(path: Path) -> list[tuple[int, int]]:
    with Image.open(path) as image:
        frames: list[tuple[int, int]] = []
        for frame in ImageSequence.Iterator(image):
            frames.append(frame.size)
        return frames


def same_geometry(left: Path, right: Path) -> bool:
    try:
        return frame_geometry(left) == frame_geometry(right)
    except (OSError, UnidentifiedImageError):
        return False


def transparency_is_preserved(left: Path, right: Path) -> bool:
    try:
        with Image.open(left) as left_image, Image.open(right) as right_image:
            for left_frame, right_frame in zip(ImageSequence.Iterator(left_image), ImageSequence.Iterator(right_image)):
                left_rgba = left_frame.convert("RGBA")
                right_rgba = right_frame.convert("RGBA")
                if left_rgba.size != right_rgba.size:
                    return False
                left_alpha = left_rgba.getchannel("A")
                right_alpha = right_rgba.getchannel("A")
                if left_alpha.tobytes() != right_alpha.tobytes():
                    return False
                if left_alpha.getextrema() == (255, 255):
                    continue
                for left_pixel, right_pixel in zip(left_rgba.getdata(), right_rgba.getdata()):
                    if left_pixel[3] == 0 and left_pixel != right_pixel:
                        return False
        return True
    except (OSError, UnidentifiedImageError):
        return False


def copy_animation_info(image: Image.Image) -> dict[str, object]:
    info: dict[str, object] = {}
    for key in ("duration", "loop", "disposal", "transparency"):
        if key in image.info:
            info[key] = image.info[key]
    return info


def copy_color_and_orientation_info(image: Image.Image) -> dict[str, object]:
    info: dict[str, object] = {}
    for key in ("exif", "icc_profile"):
        if key in image.info:
            info[key] = image.info[key]
    return info


def save_candidate(src: Path, candidate: Path, png_colors: int, jpeg_quality: int, webp_quality: int) -> None:
    with Image.open(src) as image:
        image_format = image.format
        if not image_format:
            raise ValueError("unknown image format")

        frames = [frame.copy() for frame in ImageSequence.Iterator(image)]
        save_kwargs = {
            **copy_color_and_orientation_info(image),
            **compression_options(image_format, jpeg_quality, webp_quality),
        }
        if image_format.upper() == "PNG":
            frames = [quantize_png_frame(frame, png_colors) for frame in frames]
        if len(frames) > 1:
            frames[0].save(
                candidate,
                format=image_format,
                save_all=True,
                append_images=frames[1:],
                **copy_animation_info(image),
                **save_kwargs,
            )
            return

        frames[0].save(candidate, format=image_format, **save_kwargs)


def quantize_png_frame(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    has_transparency = alpha.getextrema() != (255, 255)
    method = Image.Quantize.FASTOCTREE if has_transparency else Image.Quantize.MEDIANCUT
    source = rgba if has_transparency else rgba.convert("RGB")
    quantized = source.quantize(colors=colors, method=method, dither=Image.Dither.FLOYDSTEINBERG)
    if not has_transparency:
        return quantized

    result = quantized.convert("RGBA")
    result.putalpha(alpha)
    transparent_mask = Image.eval(alpha, lambda value: 255 if value == 0 else 0)
    result.paste(rgba, mask=transparent_mask)
    return result


def compression_options(image_format: str, jpeg_quality: int, webp_quality: int) -> dict[str, object]:
    fmt = image_format.upper()
    if fmt == "PNG":
        return {"optimize": True, "compress_level": 9}
    if fmt in {"JPEG", "MPO"}:
        return {"optimize": True, "progressive": True, "quality": jpeg_quality}
    if fmt == "WEBP":
        return {"quality": webp_quality, "method": 6}
    if fmt == "GIF":
        return {"optimize": True}
    if fmt == "TIFF":
        return {"compression": "tiff_adobe_deflate"}
    return {"optimize": True}


def compress_one(
    src: Path,
    dst: Path,
    min_savings: int,
    png_colors: int,
    jpeg_quality: int,
    webp_quality: int,
) -> Result:
    before = src.stat().st_size
    dst.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile(
        prefix=f"{src.stem}-",
        suffix=src.suffix,
        dir=dst.parent,
        delete=False,
    ) as handle:
        candidate = Path(handle.name)

    try:
        save_candidate(src, candidate, png_colors, jpeg_quality, webp_quality)
        after = candidate.stat().st_size
        if after + min_savings > before:
            return Result(src, dst, before, after, "kept", "candidate was not smaller enough")
        if not same_geometry(src, candidate):
            return Result(src, dst, before, after, "kept", "candidate changed frame geometry")
        if not transparency_is_preserved(src, candidate):
            return Result(src, dst, before, after, "kept", "candidate changed transparency")
        shutil.move(str(candidate), dst)
        return Result(src, dst, before, after, "wrote")
    except UnidentifiedImageError:
        return Result(src, dst, before, None, "skipped", "not a supported image")
    except Exception as exc:
        return Result(src, dst, before, None, "skipped", str(exc))
    finally:
        candidate.unlink(missing_ok=True)


def print_result(result: Result) -> None:
    src = result.src
    target = "" if result.src == result.dst else f" -> {result.dst}"
    if result.status == "wrote" and result.after is not None:
        saved = result.before - result.after
        percent = saved / result.before * 100 if result.before else 0
        print(f"wrote {src}{target}: {result.before} -> {result.after} bytes ({percent:.1f}% smaller)")
        return
    if result.after is None:
        print(f"{result.status} {src}: {result.detail}")
        return
    print(f"{result.status} {src}: {result.before} bytes ({result.detail}, candidate {result.after} bytes)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compress image files with visually near-lossless settings.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to scan")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write compressed files into this directory")
    parser.add_argument(
        "--min-savings",
        type=positive_int,
        default=1,
        help="Minimum bytes saved before writing a candidate. Default: 1",
    )
    parser.add_argument(
        "--png-colors",
        type=bounded_int(2, 256),
        default=256,
        help="Maximum colors for PNG palette compression. Default: 256",
    )
    parser.add_argument(
        "--jpeg-quality",
        type=bounded_int(1, 100),
        default=88,
        help="JPEG quality for visually near-lossless output. Default: 88",
    )
    parser.add_argument(
        "--webp-quality",
        type=bounded_int(1, 100),
        default=86,
        help="WebP quality for visually near-lossless output. Default: 86",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files = collect_inputs(args.inputs, args.recursive)
    if not files:
        print("No files to process.")
        return 0

    written = 0
    saved = 0
    for src in files:
        dst = output_path_for(src, args.output_dir)
        result = compress_one(src, dst, args.min_savings, args.png_colors, args.jpeg_quality, args.webp_quality)
        print_result(result)
        if result.status == "wrote" and result.after is not None:
            written += 1
            saved += result.before - result.after

    print(f"Done. Wrote {written}/{len(files)} files, saved {saved} bytes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
