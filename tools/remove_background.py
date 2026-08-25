#!/usr/bin/env python3
"""Remove image backgrounds and write transparent PNG files.

This tool is intended for product images, icons, sprites, and other assets shot
or rendered against a flat backdrop that is visible from the image border.

It does not build a binary mask and blur it. An anti-aliased source already
encodes the exact sub-pixel coverage of every edge pixel: such a pixel is a
linear blend `c = a*f + (1-a)*b` of the foreground colour `f` and the backdrop
colour `b`. So the alpha is *solved* for, by projecting each pixel onto the line
between the local foreground colour and the backdrop:

    a = dot(c - b, f - b) / |f - b|^2

That recovers the source's own anti-aliasing exactly, which is what keeps edges
smooth. Thresholding coverage into a hard mask and feathering it afterwards is
what produces stair-stepped or haloed edges, and no choice of threshold can
undo it.
"""

from __future__ import annotations

import argparse
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

# Rec.601 luma, used to split colour into a luminance axis and two chroma axes.
_LUMA = (0.299, 0.587, 0.114)


@dataclass(frozen=True)
class InputFile:
    path: Path
    relative_path: Path


@dataclass(frozen=True)
class Matte:
    alpha: np.ndarray
    background: tuple[int, int, int]
    separation: float
    projected_fraction: float


@dataclass(frozen=True)
class Result:
    src: Path
    dst: Path
    size: tuple[int, int] | None
    removed_pixels: int
    status: str
    detail: str = ""


# --------------------------------------------------------------------------
# argument parsing helpers
# --------------------------------------------------------------------------


def non_negative_float(value: str) -> float:
    parsed = float(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def percent(value: str) -> float:
    parsed = float(value)
    if not 0.0 <= parsed <= 45.0:
        raise argparse.ArgumentTypeError("must be between 0 and 45")
    return parsed


def unit_float(value: str) -> float:
    parsed = float(value)
    if not 0.0 <= parsed <= 1.0:
        raise argparse.ArgumentTypeError("must be between 0 and 1")
    return parsed


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

    destination = (output_dir.resolve() / input_file.relative_path).with_suffix(".png").resolve()
    if destination == src:
        # Writing into the source's own directory would otherwise destroy the
        # original, so fall back to the suffixed name.
        destination = destination.with_name(f"{destination.stem}{suffix}.png")
    return destination


# --------------------------------------------------------------------------
# colour spaces
# --------------------------------------------------------------------------


def srgb_to_linear(value: np.ndarray) -> np.ndarray:
    return np.where(value <= 0.04045, value / 12.92, ((value + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(value: np.ndarray) -> np.ndarray:
    clipped = value.clip(0.0, 1.0)
    return np.where(clipped <= 0.0031308, clipped * 12.92, 1.055 * clipped ** (1 / 2.4) - 0.055)


def opponent_matrix(luma_weight: float) -> np.ndarray:
    """Map RGB onto a weighted (luma, Cr, Cb) basis.

    Any invertible linear map preserves the `c = a*f + (1-a)*b` relation, so the
    alpha solve stays exact. Down-weighting luma makes the solve ignore shading
    and cast shadows on the backdrop, which otherwise read as foreground.
    """
    red, green, blue = _LUMA
    return np.array(
        [
            [luma_weight * red, luma_weight * green, luma_weight * blue],
            [1.0 - red, -green, -blue],
            [-red, -green, 1.0 - blue],
        ],
        dtype=np.float32,
    )


def project(rgb: np.ndarray, matrix: np.ndarray) -> np.ndarray:
    return rgb @ matrix.T


# --------------------------------------------------------------------------
# small morphology / filtering primitives (numpy only, no scipy)
# --------------------------------------------------------------------------


def _shift_or(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    out = mask
    for _ in range(radius):
        out = _shift_or(out)
    return out


def erode(mask: np.ndarray, radius: int) -> np.ndarray:
    return ~dilate(~mask, radius)


def box_sum(array: np.ndarray, radius: int) -> np.ndarray:
    """Sum over a (2*radius+1)^2 window, via an integral image."""
    if radius <= 0:
        return array.astype(np.float32, copy=True)

    height, width = array.shape[:2]
    integral = np.zeros((height + 1, width + 1) + array.shape[2:], dtype=np.float32)
    integral[1:, 1:] = array.astype(np.float32).cumsum(axis=0).cumsum(axis=1)

    rows = np.arange(height)
    cols = np.arange(width)
    y0 = np.clip(rows - radius, 0, height)
    y1 = np.clip(rows + radius + 1, 0, height)
    x0 = np.clip(cols - radius, 0, width)
    x1 = np.clip(cols + radius + 1, 0, width)

    return (
        integral[y1][:, x1] - integral[y0][:, x1] - integral[y1][:, x0] + integral[y0][:, x0]
    )


def border_connected(mask: np.ndarray) -> np.ndarray:
    """Pixels of `mask` reachable from the image border (4-connectivity).

    Span-based flood fill: the Python-level work is proportional to the number
    of horizontal runs, not to the pixel count, so it stays fast on large
    images where a per-pixel BFS does not.
    """
    height, width = mask.shape
    filled = np.zeros((height, width), dtype=bool)

    runs: list[tuple[np.ndarray, np.ndarray]] = []
    for y in range(height):
        edges = np.diff(np.concatenate(([0], mask[y].view(np.uint8), [0])).astype(np.int8))
        runs.append((np.flatnonzero(edges == 1), np.flatnonzero(edges == -1) - 1))

    stack: list[tuple[int, int, int]] = []

    def scan(y: int, left: int, right: int) -> None:
        if y < 0 or y >= height:
            return
        starts, ends = runs[y]
        if not starts.size:
            return
        first = int(np.searchsorted(ends, left, side="left"))
        last = int(np.searchsorted(starts, right, side="right"))
        row = filled[y]
        for index in range(first, last):
            run_start = int(starts[index])
            run_end = int(ends[index])
            if row[run_start]:
                continue
            row[run_start : run_end + 1] = True
            stack.append((y, run_start, run_end))

    scan(0, 0, width - 1)
    scan(height - 1, 0, width - 1)
    for y in range(height):
        scan(y, 0, 0)
        scan(y, width - 1, width - 1)

    while stack:
        y, left, right = stack.pop()
        scan(y - 1, left, right)
        scan(y + 1, left, right)
    return filled


def otsu_threshold(values: np.ndarray, bins: int = 512) -> float:
    """Split a bimodal distribution into background and foreground."""
    top = float(values.max())
    if top <= 0:
        return 0.0
    histogram, edges = np.histogram(values, bins=bins, range=(0.0, top))
    histogram = histogram.astype(np.float64)
    total = histogram.sum()
    if total <= 0:
        return top * 0.5

    centers = (edges[:-1] + edges[1:]) * 0.5
    weight_low = np.cumsum(histogram)
    weight_high = total - weight_low
    sum_low = np.cumsum(histogram * centers)
    sum_total = sum_low[-1]

    valid = (weight_low > 0) & (weight_high > 0)
    mean_low = np.zeros_like(weight_low)
    mean_high = np.zeros_like(weight_high)
    mean_low[valid] = sum_low[valid] / weight_low[valid]
    mean_high[valid] = (sum_total - sum_low[valid]) / weight_high[valid]
    variance = weight_low * weight_high * (mean_low - mean_high) ** 2
    variance[~valid] = -1.0
    return float(centers[int(np.argmax(variance))])


# --------------------------------------------------------------------------
# background estimation and the alpha solve
# --------------------------------------------------------------------------


def estimate_background(working: np.ndarray, border: int) -> tuple[float, float, float]:
    height, width = working.shape[:2]
    sample = max(1, min(border, width, height))
    samples = np.concatenate(
        [
            working[:sample, :, :].reshape(-1, 3),
            working[height - sample :, :, :].reshape(-1, 3),
            working[:, :sample, :].reshape(-1, 3),
            working[:, width - sample :, :].reshape(-1, 3),
        ],
        axis=0,
    )
    return tuple(float(channel) for channel in np.median(samples, axis=0))  # type: ignore[return-value]


def nearest_background(
    projected: np.ndarray, backgrounds: list[tuple[float, float, float]], matrix: np.ndarray
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """For each pixel pick the closest supplied backdrop colour."""
    stack = np.stack([project(np.array(bg, dtype=np.float32), matrix) for bg in backgrounds])
    distances = np.sqrt(((projected[:, :, None, :] - stack[None, None, :, :]) ** 2).sum(axis=3))
    nearest = np.argmin(distances, axis=2)
    distance = np.take_along_axis(distances, nearest[:, :, None], axis=2)[:, :, 0]
    return distance, stack[nearest], np.array(backgrounds, dtype=np.float32)[nearest]


def solve_alpha(
    working: np.ndarray,
    projected: np.ndarray,
    distance: np.ndarray,
    background_proj: np.ndarray,
    matrix: np.ndarray,
    background: tuple[float, float, float],
    edge_radius: int,
) -> Matte:
    """Recover per-pixel coverage by projecting onto the local foreground/background axis.

    Only the narrow band that brackets the real silhouette is solved. Pixels
    confidently inside the subject are opaque and pixels confidently on the
    backdrop are clear, so shading inside the subject and shadows cast on the
    backdrop cannot leak into the matte as stray transparency.
    """
    split = otsu_threshold(distance)
    band = max(1, edge_radius // 2)
    core_foreground = erode(distance >= split, band)
    core_background = erode(distance <= split, band)

    # Sample the foreground reference from opaque pixels only, never from
    # blended edge pixels, then spread it out across the unknown band.
    counts = box_sum(core_foreground.astype(np.float32), edge_radius)
    sums = box_sum(working * core_foreground[:, :, None], edge_radius)
    known = counts > 0.5
    local_foreground = np.where(
        known[:, :, None], sums / np.maximum(counts, 1.0)[:, :, None], working
    ).astype(np.float32)

    axis = project(local_foreground, matrix) - background_proj
    axis_length_sq = (axis**2).sum(axis=2)
    separation = (
        float(np.median(np.sqrt(axis_length_sq[core_foreground]))) if core_foreground.any() else 0.0
    )

    # Trust the projection only where the local foreground is clearly separated
    # from the backdrop; elsewhere fall back to a plain normalised distance.
    reliable = known & (axis_length_sq > (0.35 * max(separation, 1e-6)) ** 2)
    scale = separation if separation > 1e-6 else max(float(distance.max()), 1e-6)
    alpha = distance / scale
    if reliable.any():
        numerator = ((projected - background_proj) * axis).sum(axis=2)
        alpha = np.where(reliable, numerator / np.maximum(axis_length_sq, 1e-9), alpha)

    alpha = alpha.clip(0.0, 1.0).astype(np.float32)
    alpha[core_foreground] = 1.0
    alpha[core_background] = 0.0

    unknown = ~core_foreground & ~core_background
    return Matte(
        alpha=alpha,
        background=tuple(int(round(channel * 255)) for channel in background),  # type: ignore[arg-type]
        separation=separation,
        projected_fraction=float(np.mean(reliable[unknown])) if unknown.any() else 1.0,
    )


def apply_matte_shaping(
    alpha: np.ndarray, clip_black: float, clip_white: float, shrink: float
) -> np.ndarray:
    """Remap coverage. Kept in coverage units so the ramp stays a ramp."""
    low = clip_black / 100.0
    high = 1.0 - clip_white / 100.0
    if high <= low:
        high = low + 1e-3
    shaped = ((alpha - low) / (high - low)).clip(0.0, 1.0)
    if shrink:
        # Sub-pixel erosion: back off along the coverage gradient. Flat regions
        # have no gradient, so the interior stays fully opaque and only the
        # ramp slides inward -- unlike a blur, the ramp keeps its width.
        gradient_y, gradient_x = np.gradient(shaped)
        shaped = shaped - shrink * np.hypot(gradient_x, gradient_y)
    return shaped.clip(0.0, 1.0).astype(np.float32)


def close_interior_holes(alpha: np.ndarray, include_interior: bool) -> np.ndarray:
    """Keep backdrop-coloured regions that are enclosed by the subject."""
    if include_interior:
        return alpha
    transparent = alpha < 0.5
    if not transparent.any():
        return alpha
    outside = border_connected(transparent)
    enclosed = transparent & ~outside
    if not enclosed.any():
        return alpha
    result = alpha.copy()
    result[enclosed] = 1.0
    return result


def unmultiply(
    working: np.ndarray,
    alpha: np.ndarray,
    background_rgb: np.ndarray,
    edge_radius: int,
) -> np.ndarray:
    """Invert `c = a*f + (1-a)*b` to recover the true foreground colour.

    This is what removes the coloured fringe on partially transparent pixels.
    Below a low alpha the inversion amplifies noise, so those pixels fade to the
    local foreground colour instead.
    """
    safe_alpha = np.maximum(alpha, 1e-4)[:, :, None]
    recovered = (working - background_rgb * (1.0 - alpha[:, :, None])) / safe_alpha

    visible = alpha > 0.5
    counts = box_sum(visible.astype(np.float32), edge_radius)
    sums = box_sum(recovered.clip(0.0, 1.0) * visible[:, :, None], edge_radius)
    neighbourhood = np.where(
        (counts > 0.5)[:, :, None], sums / np.maximum(counts, 1.0)[:, :, None], working
    )

    blend = np.clip(alpha / 0.25, 0.0, 1.0)[:, :, None]
    return (recovered * blend + neighbourhood * (1.0 - blend)).clip(0.0, 1.0).astype(np.float32)


def limit_spill(
    rgb: np.ndarray,
    alpha: np.ndarray,
    background: tuple[float, float, float],
    radius: int,
    strength: float,
) -> np.ndarray:
    """Reduce backdrop-coloured bounce light on opaque pixels near the edge.

    The allowance is measured from the subject's own interior, so a subject that
    is legitimately the backdrop's hue is not desaturated.
    """
    if radius <= 0 or strength <= 0:
        return rgb

    background_rgb = np.array(background, dtype=np.float32)
    background_chroma = background_rgb - float(np.dot(background_rgb, _LUMA))
    norm = float(np.dot(background_chroma, background_chroma))
    if norm < 1e-6:
        return rgb

    direction = background_chroma / norm
    chroma = rgb - (rgb * np.array(_LUMA, dtype=np.float32)).sum(axis=2, keepdims=True)
    amount = (chroma * background_chroma).sum(axis=2) / norm

    interior = erode(alpha > 0.995, radius + 2)
    if not interior.any():
        return rgb
    counts = box_sum(interior.astype(np.float32), radius * 3)
    sums = box_sum(amount * interior, radius * 3)
    allowed = np.where(counts > 0.5, sums / np.maximum(counts, 1.0), amount)

    rim = (alpha > 0.0) & dilate(alpha < 0.995, radius) & ~interior
    excess = np.clip(amount - allowed, 0.0, None) * rim * strength
    return (rgb - excess[:, :, None] * direction[None, None, :]).clip(0.0, 1.0).astype(np.float32)


# --------------------------------------------------------------------------
# pipeline
# --------------------------------------------------------------------------


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
    backgrounds: list[tuple[int, int, int]] | None = None,
    sample_border: int = 16,
    luma_weight: float = 0.4,
    edge_radius: int = 6,
    clip_black: float = 2.0,
    clip_white: float = 2.0,
    shrink: float = 0.0,
    include_interior: bool = False,
    despill: bool = True,
    spill_radius: int = 0,
    spill_strength: float = 1.0,
    linear: bool = False,
    trim: bool = False,
    trim_padding: int = 0,
) -> tuple[Image.Image, np.ndarray, int, Matte]:
    rgba_image = ImageOps.exif_transpose(image).convert("RGBA")
    rgba = np.asarray(rgba_image, dtype=np.float32) / 255.0
    srgb = rgba[:, :, :3]
    original_alpha = rgba[:, :, 3]

    working = srgb_to_linear(srgb).astype(np.float32) if linear else srgb

    if backgrounds:
        selected = [
            tuple(
                float(channel)
                for channel in (
                    srgb_to_linear(np.array(bg, dtype=np.float32) / 255.0)
                    if linear
                    else np.array(bg, dtype=np.float32) / 255.0
                )
            )
            for bg in backgrounds
        ]
    else:
        selected = [estimate_background(working, sample_border)]

    matrix = opponent_matrix(luma_weight)
    projected = project(working, matrix)
    distance, background_proj, background_rgb = nearest_background(projected, selected, matrix)  # type: ignore[arg-type]

    reported = np.array(selected[0], dtype=np.float32)
    if linear:
        reported = linear_to_srgb(reported)

    matte = solve_alpha(
        working, projected, distance, background_proj, matrix, tuple(float(c) for c in reported), edge_radius  # type: ignore[arg-type]
    )
    alpha = apply_matte_shaping(matte.alpha, clip_black, clip_white, shrink)
    alpha = close_interior_holes(alpha, include_interior)
    alpha = np.minimum(alpha, original_alpha)

    recovered = unmultiply(working, alpha, background_rgb, edge_radius) if despill else working
    recovered = limit_spill(recovered, alpha, selected[0], spill_radius, spill_strength)  # type: ignore[arg-type]

    out_srgb = linear_to_srgb(recovered) if linear else recovered.clip(0.0, 1.0)
    output = np.dstack(
        [np.round(out_srgb * 255.0), np.round(alpha * 255.0)]
    ).clip(0, 255).astype(np.uint8)
    output_image = Image.fromarray(output, mode="RGBA")
    if trim:
        output_image = trim_transparent_margins(output_image, trim_padding)

    removed_pixels = int(np.count_nonzero((original_alpha > 0) & (alpha <= 0.0)))
    return output_image, alpha, removed_pixels, matte


def remove_one(input_file: InputFile, output_dir: Path | None, args: argparse.Namespace) -> Result:
    src = input_file.path
    dst = output_path_for(input_file, output_dir, args.suffix)
    if dst == src:
        return Result(src, dst, None, 0, "skipped", "refusing to overwrite the source image")
    if dst.exists() and not args.overwrite:
        return Result(src, dst, None, 0, "skipped", "destination exists; pass --overwrite to replace it")

    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=f"{src.stem}-", suffix=".png", dir=dst.parent, delete=False
    ) as handle:
        tmp = Path(handle.name)

    try:
        with Image.open(src) as image:
            output, alpha, removed_pixels, matte = remove_background(
                image,
                args.background,
                args.sample_border,
                args.luma_weight,
                args.edge_radius,
                args.clip_black,
                args.clip_white,
                args.shrink,
                args.include_interior,
                args.despill,
                args.spill_radius,
                args.spill_strength,
                args.linear,
                args.trim,
                args.trim_padding,
            )
            if removed_pixels == 0:
                return Result(src, dst, image.size, 0, "kept", "no background-coloured pixels found")

            output.save(tmp, format="PNG", optimize=True, compress_level=9)
            shutil.move(str(tmp), dst)

            if args.debug_matte:
                matte_path = dst.with_name(f"{dst.stem}-matte.png")
                Image.fromarray(np.round(alpha * 255).astype(np.uint8), mode="L").save(matte_path)

            soft = int(np.count_nonzero((alpha > 0.004) & (alpha < 0.996)))
            detail = (
                f"background rgb={matte.background}, soft edge {soft} px, "
                f"solved {matte.projected_fraction * 100:.0f}% by projection, "
                f"separation {matte.separation:.2f}"
            )
            if matte.separation < 0.08:
                detail += " (LOW: subject and backdrop are close in colour; pass --background)"
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
        percent_removed = result.removed_pixels / total_pixels * 100 if total_pixels else 0
        print(
            f"wrote {result.src}{target}: removed {result.removed_pixels} pixels "
            f"({percent_removed:.1f}%; {result.detail})"
        )
        return
    if result.size:
        print(f"{result.status} {result.src}{target}: {result.size[0]}x{result.size[1]} ({result.detail})")
        return
    print(f"{result.status} {result.src}{target}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove flat backgrounds, preserving the source's own anti-aliased edge.",
    )
    parser.add_argument("inputs", type=Path, nargs="+", help="Image files or directories to process")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan directories recursively")
    parser.add_argument("-o", "--output-dir", type=Path, help="Write transparent PNG files into this directory")
    parser.add_argument("--suffix", default="-no-bg", help="Suffix used when writing next to inputs. Default: -no-bg")
    parser.add_argument(
        "--background",
        type=parse_rgb,
        action="append",
        help="Background color as #rrggbb or r,g,b. Can be repeated. Defaults to the median border color.",
    )
    parser.add_argument(
        "--sample-border",
        type=positive_int,
        default=16,
        help="Border width used for automatic background detection. Default: 16",
    )
    parser.add_argument(
        "--luma-weight",
        type=unit_float,
        default=0.4,
        help="Weight of brightness relative to hue when separating subject from backdrop. "
        "Lower values ignore shading and cast shadows on the backdrop. Default: 0.4",
    )
    parser.add_argument(
        "--edge-radius",
        type=positive_int,
        default=6,
        help="Radius used to sample the local foreground color near the edge. Default: 6",
    )
    parser.add_argument(
        "--clip-black",
        type=percent,
        default=2.0,
        help="Coverage below this percentage becomes fully transparent. Default: 2",
    )
    parser.add_argument(
        "--clip-white",
        type=percent,
        default=2.0,
        help="Coverage above 100 minus this percentage becomes fully opaque. Default: 2",
    )
    parser.add_argument(
        "--shrink",
        type=non_negative_float,
        default=0.0,
        help="Pull the matte inward by this fraction of a pixel. Use instead of blurring. Default: 0",
    )
    parser.add_argument(
        "--include-interior",
        action="store_true",
        help="Also remove background-coloured regions enclosed by the subject.",
    )
    parser.add_argument(
        "--despill",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Recover true edge colors by inverting the compositing equation. Default: true.",
    )
    parser.add_argument(
        "--spill-radius",
        type=non_negative_int,
        default=0,
        help="Also neutralise backdrop bounce light this many pixels inside the opaque edge. Default: 0",
    )
    parser.add_argument(
        "--spill-strength",
        type=unit_float,
        default=1.0,
        help="How much of the measured spill excess to remove. Default: 1.0",
    )
    parser.add_argument(
        "--linear",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="Solve in linear light. Use for 3D renders; leave off for design-tool exports. Default: false.",
    )
    parser.add_argument("--trim", action="store_true", help="Trim transparent margins after background removal")
    parser.add_argument(
        "--trim-padding",
        type=non_negative_int,
        default=0,
        help="Transparent padding to keep when --trim is used. Default: 0",
    )
    parser.add_argument("--debug-matte", action="store_true", help="Also write the alpha channel as a grayscale PNG")
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
        result = remove_one(input_file, args.output_dir, args)
        print_result(result)
        if result.status == "wrote":
            written += 1

    print(f"Done. Wrote {written}/{len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
