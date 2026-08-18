#!/usr/bin/env python3
"""Trim transparent margins around image content.

The crop keeps every meaningful alpha-visible component. Tiny isolated alpha
specks are ignored by default so invisible border noise does not block trimming.

Files are written next to the input with a suffix. Pass --in-place to replace
the source instead; the tool never overwrites a source image by accident.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
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


def output_path_for(
    input_file: InputFile, output_dir: Path | None, suffix: str, in_place: bool
) -> Path:
    src = input_file.path
    if in_place and output_dir is None:
        return src
    if output_dir is None:
        return src.with_name(f"{src.stem}{suffix}{src.suffix}")

    destination = (output_dir.resolve() / input_file.relative_path).resolve()
    if destination == src and not in_place:
        destination = destination.with_name(f"{destination.stem}{suffix}{destination.suffix}")
    return destination


def row_runs(row: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Start (inclusive) and end (exclusive) of each True run in a boolean row."""
    edges = np.diff(np.concatenate(([0], row.view(np.uint8), [0])).astype(np.int8))
    return np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)


def content_bbox(mask: np.ndarray, min_component_pixels: int) -> tuple[int, int, int, int] | None:
    """Union of the bounding boxes of all components of at least the given size.

    Components are labelled by merging horizontal runs across adjacent rows, so
    the work is proportional to the number of runs rather than to the pixel
    count. Falls back to the single largest component when every component is
    below the threshold, so a small-but-real sprite is never dropped.
    """
    height = mask.shape[0]
    parent: list[int] = []
    runs: list[tuple[int, int, int]] = []

    def find(node: int) -> int:
        while parent[node] != node:
            parent[node] = parent[parent[node]]
            node = parent[node]
        return node

    def union(left: int, right: int) -> None:
        left_root, right_root = find(left), find(right)
        if left_root != right_root:
            parent[max(left_root, right_root)] = min(left_root, right_root)

    previous_ids: list[int] = []
    previous_starts = previous_ends = np.empty(0, dtype=np.int64)

    for y in range(height):
        starts, ends = row_runs(mask[y])
        current_ids = []
        for start, end in zip(starts, ends):
            parent.append(len(runs))
            current_ids.append(len(runs))
            runs.append((y, int(start), int(end)))

        # Merge with the previous row wherever the runs overlap horizontally.
        i = j = 0
        while i < len(current_ids) and j < len(previous_ids):
            if ends[i] <= previous_starts[j]:
                i += 1
            elif previous_ends[j] <= starts[i]:
                j += 1
            else:
                union(current_ids[i], previous_ids[j])
                if ends[i] < previous_ends[j]:
                    i += 1
                else:
                    j += 1
        previous_ids, previous_starts, previous_ends = current_ids, starts, ends

    if not runs:
        return None

    counts: dict[int, int] = {}
    boxes: dict[int, tuple[int, int, int, int]] = {}
    for index, (y, start, end) in enumerate(runs):
        root = find(index)
        counts[root] = counts.get(root, 0) + (end - start)
        if root in boxes:
            left, top, right, bottom = boxes[root]
            boxes[root] = (min(left, start), min(top, y), max(right, end), max(bottom, y + 1))
        else:
            boxes[root] = (start, y, end, y + 1)

    kept = [boxes[root] for root, count in counts.items() if count >= min_component_pixels]
    if not kept:
        kept = [boxes[max(counts, key=lambda root: counts[root])]]

    return (
        min(box[0] for box in kept),
        min(box[1] for box in kept),
        max(box[2] for box in kept),
        max(box[3] for box in kept),
    )


def alpha_bbox(
    image: Image.Image, min_alpha: int, min_component_pixels: int
) -> tuple[int, int, int, int] | None:
    alpha = np.asarray(image.convert("RGBA").getchannel("A"), dtype=np.uint8)
    mask = alpha >= min_alpha
    if not mask.any():
        return None
    if min_component_pixels <= 1:
        rows = np.flatnonzero(mask.any(axis=1))
        cols = np.flatnonzero(mask.any(axis=0))
        return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1
    return content_bbox(mask, min_component_pixels)


def expand_bbox(
    bbox: tuple[int, int, int, int], image_size: tuple[int, int], padding: int
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
    suffix: str,
    padding: int,
    min_alpha: int,
    min_component_pixels: int,
    in_place: bool,
    overwrite: bool,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, suffix, in_place)
    if dst == src and not in_place:
        return Result(src, dst, None, None, "skipped", "refusing to overwrite the source; pass --in-place")
    if dst != src and dst.exists() and not overwrite:
        return Result(src, dst, None, None, "skipped", "destination exists; pass --overwrite to replace it")

    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=f"{src.stem}-", suffix=src.suffix, dir=dst.parent, delete=False
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
        print(
            f"wrote {result.src}{target}: "
            f"{result.before_size[0]}x{result.before_size[1]} -> "
            f"{result.after_size[0]}x{result.after_size[1]}"
        )
        return
    if result.before_size and result.after_size:
        print(
            f"{result.status} {result.src}{target}: "
            f"{result.before_size[0]}x{result.before_size[1]} ({result.detail})"
        )
        return
    print(f"{result.status} {result.src}{target}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Trim transparent margins while keeping all alpha-visible pixels inside the crop.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to scan")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write trimmed files into this directory")
    parser.add_argument(
        "--suffix",
        default="-trimmed",
        help="Suffix used when writing next to inputs. Default: -trimmed",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Replace the source image instead of writing a new file.",
    )
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
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing destination file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    files = collect_inputs(args.inputs, args.recursive)
    if not files:
        print("No files to process.")
        return 0

    written = 0
    for input_file in files:
        result = trim_one(
            input_file,
            args.output_dir,
            args.suffix,
            args.padding,
            args.min_alpha,
            args.min_component_pixels,
            args.in_place,
            args.overwrite,
        )
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
