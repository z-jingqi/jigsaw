import type { Vec2 } from './types';

const CIRCLE_CENTER_X = 0.5;
const CIRCLE_CENTER_Y_RATIO = -0.561;
export const KNOB_RADIUS_RATIO = 0.205;
const ARC_SEGMENTS = 56;

/**
 * A classic jigsaw knob made from a real circular arc. Imagine a circle attached
 * to the cut line, with the line trimming away the top slice of the circle.
 */
function buildTemplate(radiusRatio: number): Array<readonly [number, number]> {
  const centerY = CIRCLE_CENTER_Y_RATIO * radiusRatio;
  const chordHalfWidth = Math.sqrt(radiusRatio * radiusRatio - centerY * centerY);
  const startX = CIRCLE_CENTER_X - chordHalfWidth;
  const endX = CIRCLE_CENTER_X + chordHalfWidth;
  const startAngle = Math.atan2(-centerY, startX - CIRCLE_CENTER_X);
  const endAngle = Math.atan2(-centerY, endX - CIRCLE_CENTER_X) + Math.PI * 2;
  const pts: Array<readonly [number, number]> = [
    [0, 0],
    [startX, 0],
  ];

  for (let i = 1; i < ARC_SEGMENTS; i++) {
    const u = i / ARC_SEGMENTS;
    const angle = startAngle + (endAngle - startAngle) * u;
    pts.push([
      CIRCLE_CENTER_X + Math.cos(angle) * radiusRatio,
      centerY + Math.sin(angle) * radiusRatio,
    ]);
  }

  pts.push([endX, 0], [1, 0]);
  return pts;
}

/**
 * Build a polyline from `a` to `b` with a single tab/socket bump.
 * `side = +1` bumps in the rotate-90°-CCW perpendicular direction; `-1` bumps the other way.
 *
 * The two cells that share this cut should call `knobPolyline(a, b, side)` exactly the
 * same way; one traverses the result forward, the other reversed. Same geometry, opposite
 * concave/convex roles for the two pieces.
 */
export function knobPolyline(a: Vec2, b: Vec2, side: 1 | -1, radiusPx?: number): Vec2[] {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const L = Math.hypot(dx, dy);
  if (L === 0) return [[a[0], a[1]]];
  const radiusRatio = Math.min(0.32, Math.max(0.05, (radiusPx ?? L * KNOB_RADIUS_RATIO) / L));
  const template = buildTemplate(radiusRatio);
  const ux = dx / L;
  const uy = dy / L;
  // Perpendicular: rotate (ux, uy) by 90°. In screen coords (y-down) this is (-uy, ux).
  const px = -uy;
  const py = ux;
  const out: Vec2[] = [];
  for (const [t, n] of template) {
    const ox = a[0] + L * (t * ux + n * px * side);
    const oy = a[1] + L * (t * uy + n * py * side);
    out.push([ox, oy]);
  }
  return out;
}

/** Pick a random side (+1 or -1) for a knob bump. */
export function randomSide(rng: () => number = Math.random): 1 | -1 {
  return rng() < 0.5 ? 1 : -1;
}
