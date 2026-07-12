#!/usr/bin/env python3
"""Convert images to JPEG.

JPEG does not support transparency, so RGBA/LA/P images with alpha are composited
onto a configurable background color before saving.
"""

from __future__ import annotations

import argparse
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError


JPEG_MARKER_PREFIX = "JigCat:jpeg-quality="


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
    before_bytes: int | None
    after_bytes: int | None
    status: str
    detail: str = ""


def bounded_int(min_value: int, max_value: int):
    def parse(value: str) -> int:
        parsed = int(value)
        if parsed < min_value or parsed > max_value:
            raise argparse.ArgumentTypeError(f"must be between {min_value} and {max_value}")
        return parsed

    return parse


def parse_rgb(value: str) -> tuple[int, int, int]:
    raw = value.strip()
    if raw.startswith("#"):
        raw = raw[1:]
        if len(raw) != 6:
            raise argparse.ArgumentTypeError("hex color must be #rrggbb")
        try:
            return int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)
        except ValueError as exc:
            raise argparse.ArgumentTypeError("hex color must be #rrggbb") from exc
    parts = raw.split(",")
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("color must be #rrggbb or r,g,b")
    try:
        rgb = tuple(int(part.strip()) for part in parts)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("color must be #rrggbb or r,g,b") from exc
    if any(channel < 0 or channel > 255 for channel in rgb):
        raise argparse.ArgumentTypeError("RGB channels must be between 0 and 255")
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
        return src.with_name(f"{src.stem}{suffix}.jpg")
    return (output_dir.resolve() / input_file.relative_path).with_suffix(".jpg").resolve()


def has_alpha(image: Image.Image) -> bool:
    if image.mode in {"RGBA", "LA"}:
        alpha = image.getchannel("A")
        return alpha.getextrema() != (255, 255)
    if image.mode == "P" and "transparency" in image.info:
        return True
    return False


def image_to_rgb(image: Image.Image, background: tuple[int, int, int]) -> tuple[Image.Image, bool]:
    image = ImageOps.exif_transpose(image)
    if not has_alpha(image):
        return image.convert("RGB"), False

    rgba = image.convert("RGBA")
    canvas = Image.new("RGBA", rgba.size, (*background, 255))
    canvas.alpha_composite(rgba)
    return canvas.convert("RGB"), True


def convert_one(
    input_file: InputFile,
    output_dir: Path | None,
    suffix: str,
    quality: int,
    background: tuple[int, int, int],
    overwrite: bool,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, suffix)
    if dst.exists() and not overwrite:
        return Result(src, dst, None, None, None, None, "skipped", "destination exists; pass --overwrite to replace it")
    if src.suffix.lower() in {".jpg", ".jpeg"}:
        before_bytes = src.stat().st_size
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.resolve() != dst.resolve():
            shutil.copy2(src, dst)
        return Result(src, dst, None, None, before_bytes, before_bytes, "kept", "already JPEG; skipped conversion")

    try:
        before_bytes = src.stat().st_size
        dst.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(src) as image:
            before_size = image.size
            output, composited = image_to_rgb(image, background)
            output.save(
                dst,
                format="JPEG",
                quality=quality,
                optimize=True,
                progressive=True,
                subsampling=2,
                comment=f"{JPEG_MARKER_PREFIX}{quality}".encode("ascii"),
            )
            after_bytes = dst.stat().st_size
            detail = f"quality={quality}"
            if composited:
                detail += f", alpha composited on #{background[0]:02x}{background[1]:02x}{background[2]:02x}"
            return Result(src, dst, before_size, output.size, before_bytes, after_bytes, "wrote", detail)
    except UnidentifiedImageError:
        return Result(src, dst, None, None, None, None, "skipped", "not a supported image")
    except Exception as exc:
        return Result(src, dst, None, None, None, None, "skipped", str(exc))


def print_result(result: Result) -> None:
    target = "" if result.src == result.dst else f" -> {result.dst}"
    if result.status == "wrote" and result.before_size and result.after_size and result.before_bytes is not None and result.after_bytes is not None:
        delta = result.before_bytes - result.after_bytes
        percent = delta / result.before_bytes * 100 if result.before_bytes else 0
        size_text = f"{percent:.1f}% smaller" if delta >= 0 else f"{abs(percent):.1f}% larger"
        print(
            f"wrote {result.src}{target}: "
            f"{result.before_size[0]}x{result.before_size[1]} -> {result.after_size[0]}x{result.after_size[1]}, "
            f"{result.before_bytes} -> {result.after_bytes} bytes ({size_text}; {result.detail})"
        )
        return
    print(f"{result.status} {result.src}{target}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert images to JPEG, compositing transparent pixels onto a background color.")
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to convert")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write converted JPG files into this directory")
    parser.add_argument("--suffix", default="-jpg", help="Suffix used when writing next to inputs. Default: -jpg")
    parser.add_argument("--quality", type=bounded_int(1, 100), default=88, help="JPEG quality. Default: 88")
    parser.add_argument("--background", type=parse_rgb, default=(246, 235, 212), help="Background for transparent pixels. Default: #F6EBD4")
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing destination file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files = collect_inputs(args.inputs, args.recursive)
    if not files:
        print("No files to convert.")
        return 0

    written = 0
    for input_file in files:
        result = convert_one(input_file, args.output_dir, args.suffix, args.quality, args.background, args.overwrite)
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
