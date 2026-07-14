#!/usr/bin/env python3
"""Convert an audio file to a Godot-supported WAV, OGG, or MP3 file.

This tool uses the ffmpeg executable on PATH and does not require Python
packages outside the standard library.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid


SUPPORTED_OUTPUTS = {".wav", ".ogg", ".mp3"}
BITRATE_RE = re.compile(r"^[1-9][0-9]*[kKmM]$")


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


def run_ffmpeg(command: list[str]) -> None:
    try:
        subprocess.run(command, check=True, text=True, capture_output=True)
    except FileNotFoundError as exc:
        raise SystemExit(
            "Missing executable: ffmpeg. Install FFmpeg and ensure it is on PATH."
        ) from exc
    except subprocess.CalledProcessError as exc:
        details = exc.stderr.strip() or exc.stdout.strip() or "Unknown FFmpeg error"
        raise SystemExit(f"FFmpeg failed:\n{details}") from exc


def convert_audio(
    input_path: Path,
    output_path: Path,
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
    if shutil.which("ffmpeg") is None:
        raise SystemExit(
            "Missing executable: ffmpeg. Install FFmpeg and ensure it is on PATH."
        )

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
    ]
    if sample_rate is not None:
        command.extend(["-ar", str(sample_rate)])
    if channels is not None:
        command.extend(["-ac", str(channels)])
    command.extend(codec_args(extension, ogg_quality, mp3_bitrate))
    command.append(str(temporary))

    try:
        run_ffmpeg(command)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)

    print(f"Converted: {source} -> {destination}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert audio to a Godot-supported WAV, OGG, or MP3 file."
    )
    parser.add_argument("input", type=Path, help="Source audio file")
    parser.add_argument(
        "output",
        type=Path,
        help="Destination .wav, .ogg, or .mp3 file; its extension selects the format",
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
    convert_audio(
        args.input,
        args.output,
        args.sample_rate,
        args.channels,
        args.ogg_quality,
        args.mp3_bitrate,
        args.overwrite,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
