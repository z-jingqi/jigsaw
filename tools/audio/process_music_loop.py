#!/usr/bin/env python3
"""Prepare a new ambient recording as a quiet, continuous Vorbis loop."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

import numpy as np


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--overlap", type=float, default=10 / 3)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.source.resolve() == args.output.resolve():
        parser.error("Source and output must be different files")
    raw = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(args.source), "-af",
            "highpass=f=45,lowpass=f=9000", "-ar", "48000", "-ac", "2",
            "-f", "f32le", "-",
        ],
        capture_output=True, check=True,
    ).stdout
    samples = np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
    overlap = round(args.overlap * 48000)
    if overlap < 4800 or overlap * 3 >= len(samples) or not np.all(np.isfinite(samples)):
        raise ValueError("Recording must be long enough for a valid overlap")
    position = np.linspace(0, 1, overlap, dtype=np.float32)
    weight = (position * position * (3 - 2 * position))[:, None]
    join = samples[-overlap:] * (1 - weight) + samples[:overlap] * weight
    loop = np.concatenate([samples[overlap:-overlap], join])
    # Put the codec boundary in the quietest gap, then soften only its 10 ms edges.
    windows = len(loop) // 480
    energy = np.mean(loop[:windows * 480].reshape(windows, 480, 2) ** 2, axis=(1, 2))
    quiet_gap = int(np.argmin(energy + np.roll(energy, 1))) * 480
    loop = np.roll(loop, -quiet_gap, axis=0)
    edge = np.sin(np.linspace(0, np.pi / 2, 480, dtype=np.float32)) ** 2
    loop[:480] *= edge[:, None]
    loop[-480:] *= edge[::-1, None]
    rms = float(np.sqrt(np.mean(loop ** 2)))
    peak = float(np.max(np.abs(loop)))
    if rms < 0.001 or peak == 0:
        raise ValueError("Background recording is almost silent")
    loop *= min(10 ** (-25 / 20) / rms, 10 ** (-8 / 20) / peak)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="jigcat-loop-") as temp_dir:
        temp = Path(temp_dir) / "loop.f32"
        temp.write_bytes(loop.astype("<f4").tobytes())
        subprocess.run(
            [
                "ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", "48000", "-ac", "2",
                "-i", str(temp), "-c:a", "libvorbis", "-q:a", "4", str(args.output),
            ],
            check=True,
        )
    decoded = np.frombuffer(subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(args.output), "-f", "f32le", "-"],
        capture_output=True, check=True,
    ).stdout, np.float32).reshape(-1, 2)
    seam = float(np.max(np.abs(decoded[0] - decoded[-1])))
    report = {
        "source": args.source.name, "output": args.output.name,
        "seconds": len(decoded) / 48000, "sample_rate": 48000, "channels": 2,
        "overlap_seconds": overlap / 48000, "codec": "vorbis", "quality": 4,
        "edge_fade_seconds": 0.01, "rotation_seconds": quiet_gap / 48000,
        "peak_db": float(20 * np.log10(np.max(np.abs(decoded)))),
        "rms_db": float(20 * np.log10(np.sqrt(np.mean(decoded ** 2)))),
        "seam_step": seam, "bytes": args.output.stat().st_size,
    }
    if seam > 0.002 or report["peak_db"] > -7:
        raise ValueError(f"Encoded loop failed seam or peak checks: {report}")
    print(json.dumps(report))
    if args.report:
        args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
