#!/usr/bin/env python3
"""Precisely trim an audio file and export it as WAV, OGG, or MP3.

This tool uses the ffmpeg and ffprobe executables on PATH and does not require
Python packages outside the standard library.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid


SUPPORTED_OUTPUTS = {".wav", ".ogg", ".mp3"}
BITRATE_RE = re.compile(r"^[1-9][0-9]*[kKmM]$")
TIME_EPSILON = 0.001


def positive_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def non_negative_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed) or parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be > 0")
    return parsed


def vorbis_quality(value: str) -> int:
    parsed = int(value)
    if parsed < 0 or parsed > 10:
        raise argparse.ArgumentTypeError("must be between 0 and 10")
    return parsed


def bitrate(value: str) -> str:
    if not BITRATE_RE.fullmatch(value):
        raise argparse.ArgumentTypeError("must look like 128k, 192k, or 1M")
    return value.lower()


def timestamp(value: str) -> float:
    """Parse seconds, MM:SS, or HH:MM:SS into seconds."""
    raw = value.strip()
    try:
        if ":" not in raw:
            seconds = float(raw)
        else:
            parts = raw.split(":")
            if len(parts) == 2:
                minutes, tail = parts
                if not minutes.isdigit():
                    raise ValueError
                tail_seconds = float(tail)
                seconds = int(minutes) * 60 + tail_seconds
                if not math.isfinite(tail_seconds) or not 0 <= tail_seconds < 60:
                    raise ValueError
            elif len(parts) == 3:
                hours, minutes, tail = parts
                if not hours.isdigit() or not minutes.isdigit():
                    raise ValueError
                tail_seconds = float(tail)
                if (
                    int(minutes) >= 60
                    or not math.isfinite(tail_seconds)
                    or not 0 <= tail_seconds < 60
                ):
                    raise ValueError
                seconds = int(hours) * 3600 + int(minutes) * 60 + tail_seconds
            else:
                raise ValueError
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "must be seconds, MM:SS, or HH:MM:SS"
        ) from exc
    if not math.isfinite(seconds) or seconds < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return seconds


def codec_args(extension: str, ogg_quality: int, mp3_bitrate: str) -> list[str]:
    if extension == ".wav":
        return ["-c:a", "pcm_s16le"]
    if extension == ".ogg":
        return ["-c:a", "libvorbis", "-q:a", str(ogg_quality)]
    if extension == ".mp3":
        return ["-c:a", "libmp3lame", "-b:a", mp3_bitrate]
    raise ValueError(f"Unsupported output extension: {extension}")


def temporary_output_path(output_path: Path) -> Path:
    token = uuid.uuid4().hex
    return output_path.with_name(f".{output_path.stem}.{token}.tmp{output_path.suffix}")


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, check=True, text=True, capture_output=True)
    except FileNotFoundError as exc:
        raise SystemExit(
            f"Missing executable: {command[0]}. Install FFmpeg and ensure it is on PATH."
        ) from exc
    except subprocess.CalledProcessError as exc:
        details = exc.stderr.strip() or exc.stdout.strip() or "Unknown FFmpeg error"
        raise SystemExit(f"Command failed:\n{details}") from exc


def audio_duration(input_path: Path) -> float:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_entries",
            "format=duration",
            str(input_path),
        ]
    )
    try:
        duration = float(json.loads(result.stdout)["format"]["duration"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise SystemExit(f"Could not read audio duration: {input_path}") from exc
    if duration <= 0:
        raise SystemExit(f"Could not read audio duration: {input_path}")
    return duration


def trim_audio(
    input_path: Path,
    output_path: Path,
    start: float,
    end: float | None,
    requested_duration: float | None,
    fade_in: float,
    fade_out: float,
    sample_rate: int | None,
    channels: int | None,
    ogg_quality: int,
    mp3_bitrate: str,
    overwrite: bool,
) -> None:
    source = input_path.expanduser().resolve()
    destination = output_path.expanduser().resolve()

    if not source.is_file():
        raise SystemExit(f"Input file does not exist: {source}")
    if source == destination:
        raise SystemExit("Input and output must be different files.")

    extension = destination.suffix.lower()
    if extension not in SUPPORTED_OUTPUTS:
        supported = ", ".join(sorted(SUPPORTED_OUTPUTS))
        raise SystemExit(
            f"Unsupported output extension '{destination.suffix}'. Use one of: {supported}"
        )
    if destination.exists() and not overwrite:
        raise SystemExit(
            f"Output already exists: {destination}\nPass --overwrite to replace it."
        )
    for executable in ("ffmpeg", "ffprobe"):
        if shutil.which(executable) is None:
            raise SystemExit(
                f"Missing executable: {executable}. Install FFmpeg and ensure it is on PATH."
            )

    source_duration = audio_duration(source)
    if start >= source_duration - TIME_EPSILON:
        raise SystemExit(
            f"Start time {start:.3f}s is outside the {source_duration:.3f}s input."
        )

    if end is not None:
        if end <= start:
            raise SystemExit("End time must be greater than start time.")
        if end > source_duration + TIME_EPSILON:
            raise SystemExit(
                f"End time {end:.3f}s exceeds the {source_duration:.3f}s input."
            )
        clip_duration = min(end, source_duration) - start
    elif requested_duration is not None:
        if start + requested_duration > source_duration + TIME_EPSILON:
            raise SystemExit(
                "The requested start and duration exceed the input duration "
                f"({source_duration:.3f}s)."
            )
        clip_duration = min(requested_duration, source_duration - start)
    else:
        clip_duration = source_duration - start

    if fade_in + fade_out > clip_duration + TIME_EPSILON:
        raise SystemExit("Fade-in plus fade-out cannot exceed the trimmed duration.")

    filters = [
        f"atrim=start={start:.9f}:duration={clip_duration:.9f}",
        "asetpts=PTS-STARTPTS",
    ]
    if fade_in > 0:
        filters.append(f"afade=t=in:st=0:d={fade_in:.9f}")
    if fade_out > 0:
        fade_out_start = max(0.0, clip_duration - fade_out)
        filters.append(f"afade=t=out:st={fade_out_start:.9f}:d={fade_out:.9f}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = temporary_output_path(destination)
    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(source),
        "-map",
        "0:a:0",
        "-vn",
        "-map_metadata",
        "-1",
        "-af",
        ",".join(filters),
    ]
    if sample_rate is not None:
        command.extend(["-ar", str(sample_rate)])
    if channels is not None:
        command.extend(["-ac", str(channels)])
    command.extend(codec_args(extension, ogg_quality, mp3_bitrate))
    command.append(str(temporary))

    try:
        run(command)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)

    print(
        f"Trimmed {start:.3f}s to {start + clip_duration:.3f}s "
        f"({clip_duration:.3f}s): {source} -> {destination}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Precisely trim audio and export it as WAV, OGG, or MP3."
    )
    parser.add_argument("input", type=Path, help="Source audio file")
    parser.add_argument(
        "output",
        type=Path,
        help="Destination .wav, .ogg, or .mp3 file; its extension selects the format",
    )
    parser.add_argument(
        "--start",
        type=timestamp,
        default=0.0,
        help="Start time in seconds, MM:SS, or HH:MM:SS. Default: 0",
    )
    range_group = parser.add_mutually_exclusive_group()
    range_group.add_argument(
        "--end", type=timestamp, help="End time in seconds, MM:SS, or HH:MM:SS"
    )
    range_group.add_argument(
        "--duration", type=positive_float, help="Duration to keep, in seconds"
    )
    parser.add_argument(
        "--fade-in",
        type=non_negative_float,
        default=0.0,
        help="Optional fade-in duration in seconds",
    )
    parser.add_argument(
        "--fade-out",
        type=non_negative_float,
        default=0.0,
        help="Optional fade-out duration in seconds",
    )
    parser.add_argument(
        "--sample-rate",
        type=positive_int,
        help="Output sample rate in Hz, such as 48000; defaults to the source rate",
    )
    parser.add_argument(
        "--channels",
        type=int,
        choices=(1, 2),
        help="Output channel count; 1 is mono and 2 is stereo",
    )
    parser.add_argument(
        "--ogg-quality",
        type=vorbis_quality,
        default=5,
        help="OGG Vorbis quality from 0 to 10. Default: 5",
    )
    parser.add_argument(
        "--mp3-bitrate",
        type=bitrate,
        default="192k",
        help="MP3 bitrate. Default: 192k",
    )
    parser.add_argument(
        "--overwrite", action="store_true", help="Replace an existing output file"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    trim_audio(
        args.input,
        args.output,
        args.start,
        args.end,
        args.duration,
        args.fade_in,
        args.fade_out,
        args.sample_rate,
        args.channels,
        args.ogg_quality,
        args.mp3_bitrate,
        args.overwrite,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
