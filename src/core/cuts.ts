import type { Vec2 } from './types';
import { randomSide } from './knob';

/**
 * "Variety" cut palette: straight + a few smooth curve shapes. Each shape
 * generator returns a polyline with the same signature so it can be shared
 * verbatim between two adjacent cells (one cell traverses it forward, the
 * other reversed).
 *
 * Used in the slicer when `slice.knobs` is not explicitly true.
 */

const BEZIER_DEPTH = 0.18; // perpendicular bulge as fraction of cut length
const SCURVE_DEPTH = 0.12; // each control's perpendicular offset
const ARC_DEPTH = 0.20; // quadratic-bezier apex height
const SAMPLE_POINTS = 16;

interface Frame {
  ux: number;
  uy: number;
  px: number;
  py: number;
  L: number;
}

function frame(a: Vec2, b: Vec2): Frame | null {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const L = Math.hypot(dx, dy);
  if (L === 0) return null;
  return {
    ux: dx / L,
    uy: dy / L,
    // 90° rotation of (ux, uy): in screen coords (y-down) this is (-uy, ux).
    px: -dy / L,
    py: dx / L,
    L,
  };
}

export function straightCut(a: Vec2, b: Vec2): Vec2[] {
  return [[a[0], a[1]], [b[0], b[1]]];
}

/** Single cubic bezier with both controls on the same side — one smooth bulge. */
export function bezierCut(a: Vec2, b: Vec2, side: 1 | -1): Vec2[] {
  const f = frame(a, b);
  if (!f) return [[a[0], a[1]]];
  const c1: Vec2 = [
    a[0] + f.L * (0.33 * f.ux + BEZIER_DEPTH * f.px * side),
    a[1] + f.L * (0.33 * f.uy + BEZIER_DEPTH * f.py * side),
  ];
  const c2: Vec2 = [
    a[0] + f.L * (0.67 * f.ux + BEZIER_DEPTH * f.px * side),
    a[1] + f.L * (0.67 * f.uy + BEZIER_DEPTH * f.py * side),
  ];
  return sampleCubic(a, b, c1, c2);
}

/** Cubic bezier with controls on opposite sides — gentle "S" wave. */
export function sCurveCut(a: Vec2, b: Vec2, side: 1 | -1): Vec2[] {
  const f = frame(a, b);
  if (!f) return [[a[0], a[1]]];
  const c1: Vec2 = [
    a[0] + f.L * (0.33 * f.ux + SCURVE_DEPTH * f.px * side),
    a[1] + f.L * (0.33 * f.uy + SCURVE_DEPTH * f.py * side),
  ];
  const c2: Vec2 = [
    a[0] + f.L * (0.67 * f.ux - SCURVE_DEPTH * f.px * side),
    a[1] + f.L * (0.67 * f.uy - SCURVE_DEPTH * f.py * side),
  ];
  return sampleCubic(a, b, c1, c2);
}

/** Quadratic bezier through a perpendicular apex — visually similar to a circular arc. */
export function arcCut(a: Vec2, b: Vec2, side: 1 | -1): Vec2[] {
  const f = frame(a, b);
  if (!f) return [[a[0], a[1]]];
  const mx = (a[0] + b[0]) / 2;
  const my = (a[1] + b[1]) / 2;
  // The peak of a quadratic bezier is at half the control's perpendicular offset,
  // so to land the visual apex at ARC_DEPTH * L we put the control at 2× that.
  const c: Vec2 = [
    mx + 2 * ARC_DEPTH * f.L * f.px * side,
    my + 2 * ARC_DEPTH * f.L * f.py * side,
  ];
  return sampleQuadratic(a, b, c);
}

const SHAPES: Array<(a: Vec2, b: Vec2, side: 1 | -1) => Vec2[]> = [
  (a, b) => straightCut(a, b),
  (a, b, side) => bezierCut(a, b, side),
  (a, b, side) => sCurveCut(a, b, side),
  (a, b, side) => arcCut(a, b, side),
];

/** Pick a uniformly-random shape from the palette with a random bump direction. */
export function pickRandomCut(a: Vec2, b: Vec2): Vec2[] {
  const idx = Math.floor(Math.random() * SHAPES.length);
  return SHAPES[idx](a, b, randomSide());
}

function sampleCubic(a: Vec2, b: Vec2, c1: Vec2, c2: Vec2): Vec2[] {
  const out: Vec2[] = [];
  for (let i = 0; i <= SAMPLE_POINTS; i++) {
    const t = i / SAMPLE_POINTS;
    const t1 = 1 - t;
    const x =
      t1 * t1 * t1 * a[0] + 3 * t1 * t1 * t * c1[0] + 3 * t1 * t * t * c2[0] + t * t * t * b[0];
    const y =
      t1 * t1 * t1 * a[1] + 3 * t1 * t1 * t * c1[1] + 3 * t1 * t * t * c2[1] + t * t * t * b[1];
    out.push([x, y]);
  }
  return out;
}

function sampleQuadratic(a: Vec2, b: Vec2, c: Vec2): Vec2[] {
  const out: Vec2[] = [];
  for (let i = 0; i <= SAMPLE_POINTS; i++) {
    const t = i / SAMPLE_POINTS;
    const t1 = 1 - t;
    const x = t1 * t1 * a[0] + 2 * t1 * t * c[0] + t * t * b[0];
    const y = t1 * t1 * a[1] + 2 * t1 * t * c[1] + t * t * b[1];
    out.push([x, y]);
  }
  return out;
}
