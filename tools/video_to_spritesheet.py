#!/usr/bin/env python3
"""Extract evenly-spaced video frames and pack them into a PNG sprite sheet.

Frame extraction and the plain (non-keyed) pack use ffmpeg/ffprobe. Background
removal delegates to remove_background.py, so sprite sheets keep the source's
own anti-aliased edges instead of a hard binary cutout.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from remove_background import remove_background  # noqa: E402


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


def clear_rects(frame: np.ndarray, rects: list[tuple[int, int, int, int]]) -> np.ndarray:
    height, width = frame.shape[:2]
    for x, y, w, h in rects:
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(width, x + w), min(height, y + h)
        if x0 < x1 and y0 < y1:
            frame[y0:y1, x0:x1] = (255, 255, 255, 0)
    return frame


def pack_sheet_with_background_removed(
    frames: list[Path],
    output_path: Path,
    frame_width: int,
    frame_height: int,
    cols: int,
    rows: int,
    clear_areas: list[tuple[int, int, int, int]],
) -> None:
    sheet = Image.new("RGBA", (frame_width * cols, frame_height * rows), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        with Image.open(frame) as image:
            keyed, _alpha, _removed, _matte = remove_background(image)
        pixels = clear_rects(np.asarray(keyed.convert("RGBA")).copy(), clear_areas)
        sheet.paste(
            Image.fromarray(pixels, "RGBA"),
            ((index % cols) * frame_width, (index // cols) * frame_height),
        )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, format="PNG", optimize=True, compress_level=9)


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
    parser.add_argument(
        "--remove-background",
        action="store_true",
        help="Key out the flat backdrop, preserving each frame's anti-aliased edge",
    )
    parser.add_argument(
        "--edge-bg-threshold",
        type=non_negative_int,
        help="Deprecated alias for --remove-background; the threshold value is ignored",
    )
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
        if args.edge_bg_threshold is not None:
            print("note: --edge-bg-threshold is deprecated; using --remove-background instead")
        if args.remove_background or args.edge_bg_threshold is not None:
            pack_sheet_with_background_removed(
                frames,
                output_path,
                frame_width,
                frame_height,
                cols,
                rows,
                args.clear_rect,
            )
        else:
            pack_sheet(frame_dir, output_path, cols, rows)
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
