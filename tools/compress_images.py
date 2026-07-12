#!/usr/bin/env python3
"""Shrink image files with visually near-lossless compression.

The tool accepts files or directories, keeps each file's original format, and
only writes a result when the candidate is smaller and preserves image geometry.
For images with transparency, alpha and fully transparent pixels are preserved.
"""

from __future__ import annotations

import argparse
import math
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageSequence, UnidentifiedImageError


JPEG_MARKER_PREFIX = "JigCat:jpeg-quality="


@dataclass(frozen=True)
class InputFile:
    path: Path
    relative_path: Path


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


def non_negative_float(value: str) -> float:
    parsed = float(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
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
    src = input_file.path
    if output_dir is None:
        return src
    return (output_dir.resolve() / input_file.relative_path).resolve()


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
                transparent_mask = left_alpha.point(lambda alpha: 255 if alpha == 0 else 0)
                difference = ImageChops.difference(left_rgba, right_rgba)
                transparent_difference = Image.new("RGBA", left_rgba.size)
                transparent_difference.paste(difference, mask=transparent_mask)
                if transparent_difference.getbbox() is not None:
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


def jpeg_quality_marker(path: Path) -> int | None:
    if path.suffix.lower() not in {".jpg", ".jpeg"}:
        return None
    try:
        with Image.open(path) as image:
            comment = image.info.get("comment", b"")
            text = comment.decode("ascii", errors="ignore") if isinstance(comment, bytes) else str(comment)
            if not text.startswith(JPEG_MARKER_PREFIX):
                return None
            return int(text.removeprefix(JPEG_MARKER_PREFIX))
    except (OSError, UnidentifiedImageError, ValueError):
        return None


def save_jpeg(
    image: Image.Image,
    candidate: Path,
    quality: int,
    metadata: dict[str, object],
) -> None:
    output = image.convert("RGB") if image.mode not in {"RGB", "L"} else image
    output.save(
        candidate,
        format="JPEG",
        optimize=True,
        progressive=True,
        quality=quality,
        subsampling=2,
        comment=f"{JPEG_MARKER_PREFIX}{quality}".encode("ascii"),
        **metadata,
    )


def save_jpeg_to_target(
    image: Image.Image,
    candidate: Path,
    quality: int,
    min_quality: int,
    target_bytes: int | None,
    metadata: dict[str, object],
) -> int:
    save_jpeg(image, candidate, quality, metadata)
    if target_bytes is None or candidate.stat().st_size <= target_bytes or quality <= min_quality:
        return quality

    chosen_quality = min_quality
    upper_quality = quality
    probe_quality = quality - 4
    while probe_quality >= min_quality:
        save_jpeg(image, candidate, probe_quality, metadata)
        if candidate.stat().st_size <= target_bytes:
            chosen_quality = probe_quality
            upper_quality = min(quality, probe_quality + 3)
            break
        probe_quality -= 4
    else:
        save_jpeg(image, candidate, min_quality, metadata)
        return min_quality

    low = chosen_quality + 1
    high = upper_quality
    while low <= high:
        probe_quality = (low + high) // 2
        save_jpeg(image, candidate, probe_quality, metadata)
        if candidate.stat().st_size <= target_bytes:
            chosen_quality = probe_quality
            low = probe_quality + 1
        else:
            high = probe_quality - 1
    save_jpeg(image, candidate, chosen_quality, metadata)
    return chosen_quality


def save_candidate(
    src: Path,
    candidate: Path,
    png_colors: int,
    jpeg_quality: int,
    jpeg_min_quality: int,
    webp_quality: int,
    target_bytes: int | None,
) -> str:
    with Image.open(src) as image:
        image_format = image.format
        if not image_format:
            raise ValueError("unknown image format")

        frames = [frame.copy() for frame in ImageSequence.Iterator(image)]
        metadata = copy_color_and_orientation_info(image)
        if image_format.upper() in {"JPEG", "MPO"} and len(frames) == 1:
            used_quality = save_jpeg_to_target(
                frames[0],
                candidate,
                jpeg_quality,
                jpeg_min_quality,
                target_bytes,
                metadata,
            )
            return f"jpeg quality={used_quality}"
        save_kwargs = {**metadata, **compression_options(image_format, jpeg_quality, webp_quality)}
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
            return image_format.upper()

        frames[0].save(candidate, format=image_format, **save_kwargs)
        return image_format.upper()


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
    min_savings_percent: float,
    png_colors: int,
    jpeg_quality: int,
    jpeg_min_quality: int,
    webp_quality: int,
    target_bytes: int | None,
) -> Result:
    before = src.stat().st_size
    dst.parent.mkdir(parents=True, exist_ok=True)

    marked_quality = jpeg_quality_marker(src)
    marker_satisfies_request = marked_quality is not None and marked_quality <= jpeg_quality
    if marker_satisfies_request and (target_bytes is None or before <= target_bytes):
        if src.resolve() != dst.resolve():
            shutil.copy2(src, dst)
            return Result(src, dst, before, before, "copied", f"already compressed at quality={marked_quality}")
        return Result(src, dst, before, before, "kept", f"already compressed at quality={marked_quality}")

    if target_bytes is not None and src.suffix.lower() in {".jpg", ".jpeg"} and before <= target_bytes:
        if src.resolve() != dst.resolve():
            shutil.copy2(src, dst)
            return Result(src, dst, before, before, "copied", "already within target size")
        return Result(src, dst, before, before, "kept", "already within target size")

    with tempfile.NamedTemporaryFile(
        prefix=f"{src.stem}-",
        suffix=src.suffix,
        dir=dst.parent,
        delete=False,
    ) as handle:
        candidate = Path(handle.name)

    try:
        encoding_detail = save_candidate(
            src,
            candidate,
            png_colors,
            jpeg_quality,
            jpeg_min_quality,
            webp_quality,
            target_bytes,
        )
        after = candidate.stat().st_size
        required_savings = max(min_savings, math.ceil(before * min_savings_percent / 100.0))
        if after + required_savings > before:
            if src.resolve() != dst.resolve():
                shutil.copy2(src, dst)
                return Result(src, dst, before, before, "copied", "candidate was not smaller enough")
            return Result(src, dst, before, after, "kept", "candidate was not smaller enough")
        if not same_geometry(src, candidate):
            if src.resolve() != dst.resolve():
                shutil.copy2(src, dst)
            return Result(src, dst, before, after, "kept", "candidate changed frame geometry")
        if not transparency_is_preserved(src, candidate):
            if src.resolve() != dst.resolve():
                shutil.copy2(src, dst)
            return Result(src, dst, before, after, "kept", "candidate changed transparency")
        shutil.move(str(candidate), dst)
        return Result(src, dst, before, after, "wrote", encoding_detail)
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
        detail = f"; {result.detail}" if result.detail else ""
        print(f"wrote {src}{target}: {result.before} -> {result.after} bytes ({percent:.1f}% smaller{detail})")
        return
    if result.status == "copied":
        print(f"copied {src}{target}: {result.before} bytes ({result.detail})")
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
        "--min-savings-percent",
        type=non_negative_float,
        default=1.0,
        help="Minimum percentage saved before replacing a file. Default: 1.0",
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
        "--jpeg-min-quality",
        type=bounded_int(1, 100),
        default=72,
        help="Lowest JPEG quality allowed while meeting --target-kb. Default: 72",
    )
    parser.add_argument(
        "--target-kb",
        type=positive_int,
        help="Optional maximum JPEG size in KiB; already-small JPEGs are copied without re-encoding",
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
    if args.jpeg_min_quality > args.jpeg_quality:
        raise SystemExit("--jpeg-min-quality must not exceed --jpeg-quality")
    files = collect_inputs(args.inputs, args.recursive)
    if not files:
        print("No files to process.")
        return 0

    written = 0
    copied = 0
    saved = 0
    target_bytes = args.target_kb * 1024 if args.target_kb else None
    for input_file in files:
        src = input_file.path
        dst = output_path_for(input_file, args.output_dir)
        result = compress_one(
            src,
            dst,
            args.min_savings,
            args.min_savings_percent,
            args.png_colors,
            args.jpeg_quality,
            args.jpeg_min_quality,
            args.webp_quality,
            target_bytes,
        )
        print_result(result)
        if result.status == "wrote" and result.after is not None:
            written += 1
            saved += result.before - result.after
        elif result.status == "copied":
            copied += 1

    print(f"Done. Wrote {written}/{len(files)} files, copied {copied}, saved {saved} bytes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
