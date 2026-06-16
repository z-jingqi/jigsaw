#!/usr/bin/env python3
"""Resize image files.

The tool accepts files or directories, keeps each file's original format, and
keeps the original aspect ratio by default. Pass --no-keep-aspect-ratio to
force an exact output size.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError


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


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
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


def output_path_for(input_file: InputFile, output_dir: Path | None, suffix: str) -> Path:
    src = input_file.path
    if output_dir is None:
        return src.with_name(f"{src.stem}{suffix}{src.suffix}")
    return (output_dir.resolve() / input_file.relative_path).resolve()


def target_size_for(
    before_size: tuple[int, int],
    width: int | None,
    height: int | None,
    keep_aspect_ratio: bool,
) -> tuple[int, int]:
    before_width, before_height = before_size
    if not keep_aspect_ratio:
        return width or before_width, height or before_height

    if width is not None and height is not None:
        ratio = min(width / before_width, height / before_height)
        return max(1, round(before_width * ratio)), max(1, round(before_height * ratio))
    if width is not None:
        return width, max(1, round(before_height * width / before_width))
    if height is not None:
        return max(1, round(before_width * height / before_height)), height
    raise ValueError("width or height is required")


def save_image(image: Image.Image, dst: Path, image_format: str | None) -> None:
    save_kwargs: dict[str, object] = {}
    fmt = image_format.upper() if image_format else None
    if fmt == "PNG":
        save_kwargs = {"optimize": True, "compress_level": 9}
    elif fmt in {"JPEG", "MPO"}:
        save_kwargs = {"optimize": True, "progressive": True, "quality": 88}
        if image.mode not in {"RGB", "L"}:
            image = image.convert("RGB")
    elif fmt == "WEBP":
        save_kwargs = {"quality": 86, "method": 6}
    image.save(dst, format=image_format, **save_kwargs)


def resize_one(
    input_file: InputFile,
    output_dir: Path | None,
    suffix: str,
    width: int | None,
    height: int | None,
    keep_aspect_ratio: bool,
    overwrite: bool,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, suffix)
    if dst.exists() and not overwrite:
        return Result(src, dst, None, None, "skipped", "destination exists; pass --overwrite to replace it")

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
            image = ImageOps.exif_transpose(image)
            before_size = image.size
            after_size = target_size_for(before_size, width, height, keep_aspect_ratio)
            if after_size == before_size:
                return Result(src, dst, before_size, after_size, "kept", "already target size")

            resized = image.resize(after_size, Image.Resampling.LANCZOS)
            save_image(resized, tmp, image_format)
            shutil.move(str(tmp), dst)
            mode = "fit" if keep_aspect_ratio else "stretch"
            return Result(src, dst, before_size, after_size, "wrote", mode)
    except UnidentifiedImageError:
        return Result(src, dst, None, None, "skipped", "not a supported image")
    except Exception as exc:
        return Result(src, dst, None, None, "skipped", str(exc))
    finally:
        tmp.unlink(missing_ok=True)


def print_result(result: Result) -> None:
    target = "" if result.src == result.dst else f" -> {result.dst}"
    if result.status == "wrote" and result.before_size and result.after_size:
        print(
            f"wrote {result.src}{target}: "
            f"{result.before_size[0]}x{result.before_size[1]} -> {result.after_size[0]}x{result.after_size[1]} "
            f"({result.detail})"
        )
        return
    if result.before_size and result.after_size:
        print(f"{result.status} {result.src}{target}: {result.before_size[0]}x{result.before_size[1]} ({result.detail})")
        return
    print(f"{result.status} {result.src}{target}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resize images, keeping aspect ratio by default.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to resize")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write resized files into this directory")
    parser.add_argument("--suffix", default="-resized", help="Suffix used when writing next to inputs. Default: -resized")
    parser.add_argument("--width", type=positive_int, help="Target width in pixels")
    parser.add_argument("--height", type=positive_int, help="Target height in pixels")
    parser.add_argument(
        "--keep-aspect-ratio",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Keep the original aspect ratio. Default: true. Use --no-keep-aspect-ratio to stretch.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing destination file")
    args = parser.parse_args()
    if args.width is None and args.height is None:
        parser.error("at least one of --width or --height is required")
    return args


def main() -> int:
    args = parse_args()
    files = collect_inputs(args.inputs, args.recursive)
    if not files:
        print("No files to process.")
        return 0

    written = 0
    for input_file in files:
        result = resize_one(
            input_file,
            args.output_dir,
            args.suffix,
            args.width,
            args.height,
            args.keep_aspect_ratio,
            args.overwrite,
        )
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
