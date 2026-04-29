import type { Vec2 } from './types';

/**
 * Normalized template for a classic jigsaw knob.
 * x runs 0..1 along the cut. y is the perpendicular offset (negative = bump in -p direction).
 * Designed so straight runs flank the bump and the bump itself is symmetric.
 */
const TEMPLATE: ReadonlyArray<readonly [number, number]> = [
  [0.0, 0.0],
  [0.30, 0.0],
  [0.32, -0.02],
  [0.34, -0.07],
  [0.40, -0.16],
  [0.50, -0.20],
  [0.60, -0.16],
  [0.66, -0.07],
  [0.68, -0.02],
  [0.70, 0.0],
  [1.0, 0.0],
];

/**
 * Build a polyline from `a` to `b` with a single tab/socket bump.
 * `side = +1` bumps in the rotate-90°-CCW perpendicular direction; `-1` bumps the other way.
 *
 * The two cells that share this cut should call `knobPolyline(a, b, side)` exactly the
 * same way; one traverses the result forward, the other reversed. Same geometry, opposite
 * concave/convex roles for the two pieces.
 */
export function knobPolyline(a: Vec2, b: Vec2, side: 1 | -1): Vec2[] {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const L = Math.hypot(dx, dy);
  if (L === 0) return [[a[0], a[1]]];
  const ux = dx / L;
  const uy = dy / L;
  // Perpendicular: rotate (ux, uy) by 90°. In screen coords (y-down) this is (-uy, ux).
  const px = -uy;
  const py = ux;
  const out: Vec2[] = [];
  for (const [t, n] of TEMPLATE) {
    const ox = a[0] + L * (t * ux + n * px * side);
    const oy = a[1] + L * (t * uy + n * py * side);
    out.push([ox, oy]);
  }
  return out;
}

/** Pick a random side (+1 or -1) for a knob bump. */
export function randomSide(): 1 | -1 {
  return Math.random() < 0.5 ? 1 : -1;
}
