#!/usr/bin/env python3
"""Extract evenly-spaced video frames and pack them into a PNG sprite sheet.

This tool intentionally uses only Python's standard library plus ffmpeg/ffprobe,
so it can run without adding project dependencies.
"""

from __future__ import annotations

import argparse
import binascii
from collections import deque
import json
import math
import shutil
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(cmd, check=True, text=True, capture_output=True)
    except FileNotFoundError:
        raise SystemExit(f"Missing executable: {cmd[0]}. Please install ffmpeg and ensure it is on PATH.")
    except subprocess.CalledProcessError as exc:
        details = exc.stderr.strip() or exc.stdout.strip()
        raise SystemExit(f"Command failed:\n{' '.join(cmd)}\n{details}")


def ffprobe_json(path: Path, entries: str) -> dict:
    proc = run([
        "ffprobe",
        "-v",
        "error",
        "-print_format",
        "json",
        "-show_entries",
        entries,
        str(path),
    ])
    return json.loads(proc.stdout)


def video_duration(path: Path) -> float:
    data = ffprobe_json(path, "format=duration")
    duration = float(data.get("format", {}).get("duration", 0))
    if duration <= 0:
        raise SystemExit(f"Could not read video duration: {path}")
    return duration


def image_size(path: Path) -> tuple[int, int]:
    data = ffprobe_json(path, "stream=width,height")
    streams = data.get("streams", [])
    if not streams:
        raise SystemExit(f"Could not read frame size: {path}")
    return int(streams[0]["width"]), int(streams[0]["height"])


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


def parse_crop(value: str) -> tuple[int, int, int, int]:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("expected x,y,w,h")
    x, y, w, h = [int(part) for part in parts]
    if x < 0 or y < 0 or w <= 0 or h <= 0:
        raise argparse.ArgumentTypeError("crop values must be x>=0, y>=0, w>0, h>0")
    return x, y, w, h


def parse_rect(value: str) -> tuple[int, int, int, int]:
    return parse_crop(value)


def extract_frames(
    input_path: Path,
    frame_dir: Path,
    frame_count: int,
    duration: float,
    width: int | None,
    crop: tuple[int, int, int, int] | None,
) -> list[Path]:
    fps = frame_count / duration
    filters = [f"fps={fps:.8f}"]
    if crop:
        x, y, w, h = crop
        filters.append(f"crop={w}:{h}:{x}:{y}")
    if width:
        filters.append(f"scale={width}:-1:flags=lanczos")
    filters.append("format=rgba")

    pattern = frame_dir / "frame_%04d.png"
    run([
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(input_path),
        "-vf",
        ",".join(filters),
        "-frames:v",
        str(frame_count),
        str(pattern),
    ])
    frames = sorted(frame_dir.glob("frame_*.png"))
    if not frames:
        raise SystemExit("ffmpeg did not produce any frames")
    return frames


def read_rgba(path: Path, width: int, height: int) -> bytearray:
    try:
        raw = subprocess.run([
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgba",
            "pipe:1",
        ], check=True, capture_output=True).stdout
    except FileNotFoundError:
        raise SystemExit("Missing executable: ffmpeg. Please install ffmpeg and ensure it is on PATH.")
    except subprocess.CalledProcessError as exc:
        details = exc.stderr.decode("utf-8", errors="replace").strip()
        raise SystemExit(f"Command failed while reading frame:\n{details}")
    expected = width * height * 4
    if len(raw) != expected:
        raise SystemExit(f"Unexpected raw frame size for {path}: {len(raw)} bytes, expected {expected}")
    return bytearray(raw)

def background_color(pixels: bytearray, width: int, height: int) -> tuple[int, int, int]:
    samples: list[tuple[int, int, int]] = []
    for y in (0, max(0, height - 1)):
        for x in range(width):
            i = (y * width + x) * 4
            samples.append((pixels[i], pixels[i + 1], pixels[i + 2]))
    for x in (0, max(0, width - 1)):
        for y in range(height):
            i = (y * width + x) * 4
            samples.append((pixels[i], pixels[i + 1], pixels[i + 2]))
    samples.sort(key=lambda rgb: sum(rgb), reverse=True)
    top = samples[: max(1, len(samples) // 4)]
    return (
        round(sum(rgb[0] for rgb in top) / len(top)),
        round(sum(rgb[1] for rgb in top) / len(top)),
        round(sum(rgb[2] for rgb in top) / len(top)),
    )


def is_bg_pixel(pixels: bytearray, offset: int, bg: tuple[int, int, int], threshold: int) -> bool:
    return (
        abs(pixels[offset] - bg[0]) <= threshold
        and abs(pixels[offset + 1] - bg[1]) <= threshold
        and abs(pixels[offset + 2] - bg[2]) <= threshold
    )


def remove_edge_background(pixels: bytearray, width: int, height: int, threshold: int) -> None:
    bg = background_color(pixels, width, height)
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        idx = y * width + x
        if seen[idx]:
            return
        offset = idx * 4
        if not is_bg_pixel(pixels, offset, bg, threshold):
            return
        seen[idx] = 1
        queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        idx = y * width + x
        pixels[idx * 4 + 3] = 0
        if x > 0:
            push(x - 1, y)
        if x + 1 < width:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y + 1 < height:
            push(x, y + 1)


def clear_rects(
    pixels: bytearray,
    width: int,
    height: int,
    rects: list[tuple[int, int, int, int]],
) -> None:
    for x, y, w, h in rects:
        x0 = max(0, x)
        y0 = max(0, y)
        x1 = min(width, x + w)
        y1 = min(height, y + h)
        for py in range(y0, y1):
            row = py * width * 4
            for px in range(x0, x1):
                offset = row + px * 4
                pixels[offset] = 255
                pixels[offset + 1] = 255
                pixels[offset + 2] = 255
                pixels[offset + 3] = 0


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return (
        len(data).to_bytes(4, "big")
        + kind
        + data
        + binascii.crc32(kind + data).to_bytes(4, "big")
    )


def write_png_rgba(path: Path, width: int, height: int, pixels: bytes) -> None:
    if len(pixels) != width * height * 4:
        raise SystemExit("PNG buffer size does not match dimensions")
    rows = []
    stride = width * 4
    for y in range(height):
        rows.append(b"\x00" + pixels[y * stride : (y + 1) * stride])
    ihdr = (
        width.to_bytes(4, "big")
        + height.to_bytes(4, "big")
        + bytes([8, 6, 0, 0, 0])
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", zlib.compress(b"".join(rows), level=9))
        + png_chunk(b"IEND", b"")
    )


def pack_sheet_with_edge_background_removed(
    frames: list[Path],
    output_path: Path,
    frame_width: int,
    frame_height: int,
    cols: int,
    rows: int,
    threshold: int,
    clear_areas: list[tuple[int, int, int, int]],
) -> None:
    sheet_width = frame_width * cols
    sheet_height = frame_height * rows
    sheet = bytearray(sheet_width * sheet_height * 4)
    for index, frame in enumerate(frames):
        pixels = read_rgba(frame, frame_width, frame_height)
        remove_edge_background(pixels, frame_width, frame_height, threshold)
        clear_rects(pixels, frame_width, frame_height, clear_areas)
        dst_x = (index % cols) * frame_width
        dst_y = (index // cols) * frame_height
        for y in range(frame_height):
            src = y * frame_width * 4
            dst = ((dst_y + y) * sheet_width + dst_x) * 4
            sheet[dst : dst + frame_width * 4] = pixels[src : src + frame_width * 4]
    write_png_rgba(output_path, sheet_width, sheet_height, bytes(sheet))


def pack_sheet(frame_dir: Path, output_path: Path, cols: int, rows: int) -> None:
    input_pattern = frame_dir / "frame_%04d.png"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    run([
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-framerate",
        "1",
        "-i",
        str(input_pattern),
        "-filter_complex",
        f"format=rgba,tile={cols}x{rows}:padding=0:margin=0:color=black@0",
        "-frames:v",
        "1",
        str(output_path),
    ])


def write_metadata(
    meta_path: Path,
    *,
    input_path: Path,
    output_path: Path,
    frame_width: int,
    frame_height: int,
    frame_count: int,
    cols: int,
    rows: int,
    duration: float,
) -> None:
    frames = []
    for i in range(frame_count):
        frames.append({
            "index": i,
            "x": (i % cols) * frame_width,
            "y": (i // cols) * frame_height,
            "w": frame_width,
            "h": frame_height,
            "t": round((duration * i) / max(1, frame_count - 1), 4),
        })

    meta = {
        "source": str(input_path),
        "image": str(output_path),
        "frameWidth": frame_width,
        "frameHeight": frame_height,
        "frameCount": frame_count,
        "columns": cols,
        "rows": rows,
        "duration": round(duration, 4),
        "frames": frames,
    }
    meta_path.parent.mkdir(parents=True, exist_ok=True)
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract video frames and pack them into a PNG sprite sheet for UI animation.",
    )
    parser.add_argument("input", type=Path, help="Input video, e.g. start-button-hover.mp4")
    parser.add_argument("output", type=Path, help="Output sprite sheet PNG")
    parser.add_argument("--frames", type=positive_int, default=24, help="Number of frames to extract. Default: 24")
    parser.add_argument("--cols", type=positive_int, help="Sprite sheet columns. Default: all frames in one row")
    parser.add_argument("--width", type=positive_int, help="Optional output width for each frame")
    parser.add_argument("--crop", type=parse_crop, help="Crop before scaling, as x,y,w,h")
    parser.add_argument("--edge-bg-threshold", type=non_negative_int, help="Remove only edge-connected background close to the sampled edge color")
    parser.add_argument("--clear-rect", type=parse_rect, action="append", default=[], help="Make a frame area transparent after scaling, as x,y,w,h. Can be repeated")
    parser.add_argument("--meta", type=Path, help="Metadata JSON path. Default: output path with .json extension")
    parser.add_argument("--keep-frames", type=Path, help="Optional directory to keep extracted frame PNGs")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = args.input.resolve()
    output_path = args.output.resolve()
    if not input_path.exists():
        raise SystemExit(f"Input video does not exist: {input_path}")

    duration = video_duration(input_path)
    cols = args.cols or args.frames
    cols = min(cols, args.frames)
    rows = math.ceil(args.frames / cols)
    meta_path = (args.meta or output_path.with_suffix(".json")).resolve()

    with tempfile.TemporaryDirectory(prefix="spritesheet-") as tmp:
        frame_dir = Path(tmp)
        frames = extract_frames(input_path, frame_dir, args.frames, duration, args.width, args.crop)
        actual_count = len(frames)
        cols = min(cols, actual_count)
        rows = math.ceil(actual_count / cols)
        frame_width, frame_height = image_size(frames[0])
        if args.edge_bg_threshold is None:
            pack_sheet(frame_dir, output_path, cols, rows)
        else:
            pack_sheet_with_edge_background_removed(
                frames,
                output_path,
                frame_width,
                frame_height,
                cols,
                rows,
                args.edge_bg_threshold,
                args.clear_rect,
            )
        write_metadata(
            meta_path,
            input_path=input_path,
            output_path=output_path,
            frame_width=frame_width,
            frame_height=frame_height,
            frame_count=actual_count,
            cols=cols,
            rows=rows,
            duration=duration,
        )
        if args.keep_frames:
            keep_dir = args.keep_frames.resolve()
            if keep_dir.exists():
                shutil.rmtree(keep_dir)
            shutil.copytree(frame_dir, keep_dir)

    print(f"Wrote sprite sheet: {output_path}")
    print(f"Wrote metadata: {meta_path}")
    print(f"Frames: {actual_count}, frame size: {frame_width}x{frame_height}, grid: {cols}x{rows}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
