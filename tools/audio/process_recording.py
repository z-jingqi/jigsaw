#!/usr/bin/env python3
"""Trim and level an ElevenLabs recording for immediate, gentle UI feedback."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import wave

import numpy as np


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--start", type=float)
    parser.add_argument("--speed", type=float, default=1)
    parser.add_argument("--peak-db", type=float, default=-8)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.source.resolve() == args.output.resolve():
        parser.error("Source and output must be different files")
    if args.duration <= 0:
        parser.error("Duration must be positive")
    if not 0.5 <= args.speed <= 2:
        parser.error("Speed must be between 0.5 and 2")
    raw = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(args.source), "-af",
            f"highpass=f=65,lowpass=f=7000,atempo={args.speed}", "-ar", "48000", "-ac", "1",
            "-f", "f32le", "-",
        ],
        capture_output=True, check=True,
    ).stdout
    samples = np.frombuffer(raw, np.float32).copy()
    window = 240
    padded = np.pad(samples, (0, (-len(samples)) % window))
    rms = np.sqrt(np.mean(padded.reshape(-1, window) ** 2, axis=1))
    if float(np.max(np.abs(samples))) < 0.003:
        raise ValueError("Recording is almost silent; choose or generate another variant")
    active = np.flatnonzero(rms > max(float(rms.max()) * 0.12, 0.0001))
    start = args.start if args.start is not None else max(0, int(active[0]) * 0.005 - 0.004)
    first = round(start * 48000)
    clip = samples[first:first + round(args.duration * 48000)]
    if len(clip) < 960 or not np.all(np.isfinite(clip)):
        raise ValueError("Selected region has insufficient valid audio")
    peak = float(np.max(np.abs(clip)))
    gain = 10 ** (args.peak_db / 20) / peak
    if gain > 10 ** (26 / 20):
        raise ValueError("Required gain is excessive; choose a stronger recording")
    clip *= gain
    attack = min(96, len(clip) // 8)
    release = min(1920, len(clip) // 4)
    clip[:attack] *= np.linspace(0, 1, attack)
    clip[-release:] *= np.linspace(1, 0, release) ** 1.5
    pcm = np.round(np.clip(clip, -1, 1) * 32767).astype("<i2")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(args.output), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(48000)
        stream.writeframes(pcm.tobytes())
    report = {
        "source": args.source.name, "output": args.output.name, "start": start,
        "duration": len(pcm) / 48000, "speed": args.speed, "sample_rate": 48000, "channels": 1,
        "gain_db": float(20 * np.log10(gain)),
        "peak_db": float(20 * np.log10(max(float(np.max(np.abs(clip))), 1e-9))),
        "rms_db": float(20 * np.log10(max(float(np.sqrt(np.mean(clip ** 2))), 1e-9))),
        "first_sample": int(pcm[0]), "last_sample": int(pcm[-1]),
        "bytes": args.output.stat().st_size,
    }
    print(json.dumps(report))
    if args.report:
        args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
