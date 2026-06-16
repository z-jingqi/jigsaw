#!/usr/bin/env python3
"""Remove image backgrounds and write transparent PNG files.

This tool is intended for product images, icons, sprites, and other assets
whose background is visible from the image border. It uses a refined local
segmentation pass: estimate or accept background colors, remove only
edge-connected matching regions by default, soften the alpha edge, and reduce
background-color spill on semi-transparent pixels.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageOps, UnidentifiedImageError


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


def border_samples(rgba: np.ndarray, border: int) -> np.ndarray:
    height, width = rgba.shape[:2]
    sample = max(1, min(border, width, height))
    top = rgba[:sample, :, :]
    bottom = rgba[height - sample :, :, :]
    left = rgba[:, :sample, :]
    right = rgba[:, width - sample :, :]
    samples = np.concatenate(
        [
            top.reshape(-1, 4),
            bottom.reshape(-1, 4),
            left.reshape(-1, 4),
            right.reshape(-1, 4),
        ],
        axis=0,
    )
    visible = samples[samples[:, 3] > 0]
    return visible[:, :3] if len(visible) else samples[:, :3]


def estimate_background_color(rgba: np.ndarray, border: int) -> tuple[int, int, int]:
    samples = border_samples(rgba, border).astype(np.float32)
    median = np.median(samples, axis=0)
    return tuple(int(round(channel)) for channel in median)  # type: ignore[return-value]


def color_distance(rgb: np.ndarray, backgrounds: list[tuple[int, int, int]]) -> np.ndarray:
    distances: list[np.ndarray] = []
    source = rgb.astype(np.float32)
    for background in backgrounds:
        bg = np.array(background, dtype=np.float32)
        distances.append(np.sqrt(np.sum((source - bg) ** 2, axis=2)))
    return np.minimum.reduce(distances)


def edge_connected_mask(candidate: np.ndarray) -> np.ndarray:
    height, width = candidate.shape
    mask = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def add(x: int, y: int) -> None:
        if candidate[y, x] and not mask[y, x]:
            mask[y, x] = True
            queue.append((x, y))

    for x in range(width):
        add(x, 0)
        add(x, height - 1)
    for y in range(height):
        add(0, y)
        add(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            if candidate[ny, nx] and not mask[ny, nx]:
                mask[ny, nx] = True
                queue.append((nx, ny))
    return mask


def dilate_mask(mask: np.ndarray, pixels: int) -> np.ndarray:
    result = mask.copy()
    for _ in range(pixels):
        expanded = result.copy()
        expanded[1:, :] |= result[:-1, :]
        expanded[:-1, :] |= result[1:, :]
        expanded[:, 1:] |= result[:, :-1]
        expanded[:, :-1] |= result[:, 1:]
        result = expanded
    return result


def remove_strength_mask(
    distance: np.ndarray,
    threshold: int,
    softness: int,
    expand: int,
    feather: int,
    include_interior: bool,
) -> np.ndarray:
    candidate = distance <= threshold
    hard_mask = candidate if include_interior else edge_connected_mask(candidate)
    hard_mask = dilate_mask(hard_mask, expand)

    strength = np.zeros(distance.shape, dtype=np.float32)
    strength[hard_mask] = 255.0

    if softness > 0:
        edge_zone = dilate_mask(hard_mask, max(1, softness // 4 + feather + expand + 1))
        soft_mask = edge_zone & ~hard_mask & (distance <= threshold + softness)
        soft_strength = ((threshold + softness - distance) / softness * 255.0).clip(0, 255)
        strength[soft_mask] = np.maximum(strength[soft_mask], soft_strength[soft_mask])

    if feather > 0:
        image = Image.fromarray(strength.clip(0, 255).astype(np.uint8), mode="L")
        strength = np.asarray(image.filter(ImageFilter.GaussianBlur(feather)), dtype=np.float32)

    return strength.clip(0, 255)


def apply_despill(rgb: np.ndarray, alpha: np.ndarray, strength: np.ndarray, background: tuple[int, int, int]) -> np.ndarray:
    output = rgb.astype(np.float32).copy()
    mask = (strength > 0) & (alpha > 0) & (alpha < 255)
    if not np.any(mask):
        return rgb

    bg = np.array(background, dtype=np.float32)
    alpha_factor = np.maximum(alpha[mask].astype(np.float32) / 255.0, 0.01)[:, None]
    output[mask] = ((output[mask] - bg * (1.0 - alpha_factor)) / alpha_factor).clip(0, 255)
    return output.astype(np.uint8)


def trim_transparent_margins(image: Image.Image, padding: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 0 else 0).getbbox()
    if bbox is None:
        return image

    left, top, right, bottom = bbox
    return image.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(image.width, right + padding),
            min(image.height, bottom + padding),
        )
    )


def remove_background(
    image: Image.Image,
    backgrounds: list[tuple[int, int, int]] | None,
    sample_border: int,
    threshold: int,
    softness: int,
    expand: int,
    feather: int,
    include_interior: bool,
    despill: bool,
    trim: bool,
    trim_padding: int,
) -> tuple[Image.Image, int, tuple[int, int, int]]:
    rgba_image = ImageOps.exif_transpose(image).convert("RGBA")
    rgba = np.asarray(rgba_image, dtype=np.uint8)
    rgb = rgba[:, :, :3]
    original_alpha = rgba[:, :, 3]

    selected_backgrounds = backgrounds or [estimate_background_color(rgba, sample_border)]
    distance = color_distance(rgb, selected_backgrounds)
    strength = remove_strength_mask(distance, threshold, softness, expand, feather, include_interior)

    new_alpha = np.minimum(original_alpha, (255.0 - strength).clip(0, 255).astype(np.uint8))
    output_rgb = apply_despill(rgb, new_alpha, strength, selected_backgrounds[0]) if despill else rgb
    output = np.dstack([output_rgb, new_alpha]).astype(np.uint8)
    output_image = Image.fromarray(output, mode="RGBA")
    if trim:
        output_image = trim_transparent_margins(output_image, trim_padding)

    removed_pixels = int(np.count_nonzero((original_alpha > 0) & (new_alpha == 0)))
    return output_image, removed_pixels, selected_backgrounds[0]


def remove_one(
    input_file: InputFile,
    output_dir: Path | None,
    suffix: str,
    backgrounds: list[tuple[int, int, int]] | None,
    sample_border: int,
    threshold: int,
    softness: int,
    expand: int,
    feather: int,
    include_interior: bool,
    despill: bool,
    trim: bool,
    trim_padding: int,
    overwrite: bool,
) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, suffix)
    if dst.exists() and not overwrite:
        return Result(src, dst, None, 0, "skipped", "destination exists; pass --overwrite to replace it")

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
            output, removed_pixels, background = remove_background(
                image,
                backgrounds,
                sample_border,
                threshold,
                softness,
                expand,
                feather,
                include_interior,
                despill,
                trim,
                trim_padding,
            )
            if removed_pixels == 0:
                return Result(src, dst, image.size, 0, "kept", "no edge-connected background pixels found")
            output.save(tmp, format="PNG", optimize=True, compress_level=9)
            shutil.move(str(tmp), dst)
            detail = (
                f"background rgb={background}, threshold={threshold}, softness={softness}, "
                f"feather={feather}, despill={despill}"
            )
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
        print(f"{result.status} {result.src}{target}: {result.size[0]}x{result.size[1]} ({result.detail})")
        return
    print(f"{result.status} {result.src}{target}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove edge-connected image backgrounds with softened alpha edges.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to process")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write transparent PNG files into this directory")
    parser.add_argument("--suffix", default="-no-bg", help="Suffix used when writing next to inputs. Default: -no-bg")
    parser.add_argument(
        "--background",
        type=parse_rgb,
        action="append",
        help="Background color as #rrggbb or r,g,b. Can be repeated. Defaults to the median visible border color.",
    )
    parser.add_argument(
        "--sample-border",
        type=positive_int,
        default=16,
        help="Border width used for automatic background detection. Default: 16",
    )
    parser.add_argument(
        "--threshold",
        type=bounded_int(0, 441),
        default=34,
        help="RGB distance removed as definite background. Default: 34",
    )
    parser.add_argument(
        "--softness",
        type=bounded_int(0, 441),
        default=28,
        help="Extra RGB distance used for partial alpha edges. Default: 28",
    )
    parser.add_argument("--expand", type=non_negative_int, default=0, help="Expand the removed mask by this many pixels. Default: 0")
    parser.add_argument("--feather", type=non_negative_int, default=2, help="Blur the alpha edge by this radius. Default: 2")
    parser.add_argument(
        "--include-interior",
        action="store_true",
        help="Also remove matching interior pixels, not only background connected to the image border.",
    )
    parser.add_argument(
        "--despill",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Reduce background-color spill on semi-transparent edge pixels. Default: true.",
    )
    parser.add_argument("--trim", action="store_true", help="Trim transparent margins after background removal")
    parser.add_argument("--trim-padding", type=non_negative_int, default=0, help="Transparent padding to keep when --trim is used. Default: 0")
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
        result = remove_one(
            input_file,
            args.output_dir,
            args.suffix,
            args.background,
            args.sample_border,
            args.threshold,
            args.softness,
            args.expand,
            args.feather,
            args.include_interior,
            args.despill,
            args.trim,
            args.trim_padding,
            args.overwrite,
        )
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
