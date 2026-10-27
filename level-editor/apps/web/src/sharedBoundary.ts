import type { Point } from "./types";

// Source-pixel tolerance only absorbs floating-point noise, not visible gaps.
export const SHARED_BOUNDARY_EPSILON = 0.02;

export function sharedBoundaryLength(a: Point[], b: Point[]): number {
  const epsilon = SHARED_BOUNDARY_EPSILON;
  let total = 0;
  for (let i = 0; i < a.length; i++) {
    const start = a[i], end = a[(i + 1) % a.length];
    const dx = end[0] - start[0], dy = end[1] - start[1];
    const length = Math.hypot(dx, dy);
    if (length <= epsilon) continue;
    const ux = dx / length, uy = dy / length;
    const intervals: Array<[number, number]> = [];
    for (let j = 0; j < b.length; j++) {
      const first = b[j], last = b[(j + 1) % b.length];
      const fx = first[0] - start[0], fy = first[1] - start[1];
      const lx = last[0] - start[0], ly = last[1] - start[1];
      if (Math.abs(ux * fy - uy * fx) > epsilon || Math.abs(ux * ly - uy * lx) > epsilon) continue;
      const t1 = ux * fx + uy * fy, t2 = ux * lx + uy * ly;
      const low = Math.max(0, Math.min(t1, t2));
      const high = Math.min(length, Math.max(t1, t2));
      if (high - low > epsilon) intervals.push([low, high]);
    }
    // Count a subdivided/duplicated boundary only once.
    intervals.sort((left, right) => left[0] - right[0]);
    let low = 0, high = 0;
    for (const interval of intervals) {
      if (interval[0] > high) { total += high - low; low = interval[0]; high = interval[1]; }
      else high = Math.max(high, interval[1]);
    }
    total += high - low;
  }
  return total;
}
