#!/usr/bin/env python3
"""Transfer a reference UI asset's clay palette onto a transparent subject.

The subject's alpha and luminance structure are preserved while its RGB palette
is remapped to luminance-matched colors sampled from the reference asset. This
keeps generated icons aligned with an approved material instead of relying on
approximate color names in generation prompts.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("input", type=Path, help="Transparent subject image")
	parser.add_argument("reference", type=Path, help="Approved palette reference image")
	parser.add_argument("-o", "--output", type=Path, required=True)
	parser.add_argument(
		"--reference-top-ratio",
		type=float,
		default=0.78,
		help="Use this top fraction of the reference to avoid a separate lower base (default: 0.78)",
	)
	parser.add_argument(
		"--subject-min-saturation",
		type=float,
		default=0.0,
		help=(
			"Only recolor subject pixels at or above this RGB saturation, preserving "
			"cream-white details in multi-colour controls (default: 0.0)"
		),
	)
	parser.add_argument("--overwrite", action="store_true")
	return parser.parse_args()


def luminance(rgb: np.ndarray) -> np.ndarray:
	return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def main() -> int:
	args = parse_args()
	if not args.input.is_file():
		raise SystemExit(f"missing input: {args.input}")
	if not args.reference.is_file():
		raise SystemExit(f"missing reference: {args.reference}")
	if args.output.exists() and not args.overwrite:
		raise SystemExit(f"output exists (pass --overwrite): {args.output}")
	if not 0.05 <= args.reference_top_ratio <= 1.0:
		raise SystemExit("--reference-top-ratio must be between 0.05 and 1.0")
	if not 0.0 <= args.subject_min_saturation <= 1.0:
		raise SystemExit("--subject-min-saturation must be between 0.0 and 1.0")

	subject = np.asarray(Image.open(args.input).convert("RGBA"), dtype=np.uint8)
	reference = np.asarray(Image.open(args.reference).convert("RGBA"), dtype=np.uint8)

	subject_rgb = subject[..., :3].astype(np.float32)
	visible_rgb = subject_rgb / 255.0
	visible_max = visible_rgb.max(axis=2)
	visible_min = visible_rgb.min(axis=2)
	visible_saturation = np.divide(
		visible_max - visible_min,
		visible_max,
		out=np.zeros_like(visible_max),
		where=visible_max > 0.0,
	)
	subject_mask = (subject[..., 3] > 0) & (
		visible_saturation >= args.subject_min_saturation
	)
	reference_mask = reference[..., 3] >= 245
	reference_height = max(1, round(reference.shape[0] * args.reference_top_ratio))
	reference_mask[reference_height:, :] = False
	if not subject_mask.any():
		raise SystemExit("input has no visible pixels")
	if not reference_mask.any():
		raise SystemExit("reference has no opaque pixels in the selected region")

	reference_rgb = reference[..., :3].astype(np.float32)
	subject_luma = luminance(subject_rgb)[subject_mask]
	reference_pixels = reference_rgb[reference_mask]
	reference_luma = luminance(reference_pixels)

	quantiles = np.linspace(0.0, 1.0, 257, dtype=np.float32)
	source_steps = np.quantile(subject_luma, quantiles)
	ref_order = np.argsort(reference_luma)
	reference_sorted = reference_pixels[ref_order]
	reference_indices = np.rint(quantiles * (len(reference_sorted) - 1)).astype(np.int64)
	target_steps = reference_sorted[reference_indices]

	visible_luma = luminance(subject_rgb)[subject_mask]
	percentiles = np.interp(visible_luma, source_steps, quantiles)
	result_pixels = np.empty((len(visible_luma), 3), dtype=np.float32)
	for channel in range(3):
		result_pixels[:, channel] = np.interp(percentiles, quantiles, target_steps[:, channel])

	result = subject.copy()
	result[..., :3][subject_mask] = np.clip(np.rint(result_pixels), 0, 255).astype(np.uint8)
	result[..., :3][subject[..., 3] == 0] = 0
	args.output.parent.mkdir(parents=True, exist_ok=True)
	Image.fromarray(result, mode="RGBA").save(args.output, optimize=True, compress_level=9)

	mid = tuple(int(round(value)) for value in np.median(result_pixels, axis=0))
	print(
		f"recolored {args.input} -> {args.output}; "
		f"reference={args.reference}; median=#{mid[0]:02X}{mid[1]:02X}{mid[2]:02X}"
	)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
