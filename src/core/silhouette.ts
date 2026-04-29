import type { Vec2 } from './types';
import { pointSegSqDist } from './geometry';

export interface Silhouette {
  /** Closed polygon ring in source-image pixel coordinates. First vertex is NOT repeated. */
  outline: Vec2[];
  /** Tight bounding box of the silhouette. */
  bounds: { x: number; y: number; width: number; height: number };
  /** Source image dimensions. */
  imageWidth: number;
  imageHeight: number;
}

interface ExtractOptions {
  /** Alpha threshold (0..255). Pixels with alpha >= threshold are foreground. */
  alphaThreshold?: number;
  /** Color-distance threshold used when the image has no usable alpha. 0..441 (sqrt(3*255^2)). */
  colorThreshold?: number;
  /** Douglas-Peucker simplification tolerance (in pixels). */
  simplifyTolerance?: number;
}

const DEFAULT_OPTS: Required<ExtractOptions> = {
  alphaThreshold: 128,
  colorThreshold: 30,
  simplifyTolerance: 1.2,
};

export async function extractSilhouette(
  imageUrl: string,
  opts: ExtractOptions = {},
): Promise<Silhouette> {
  const o = { ...DEFAULT_OPTS, ...opts };
  const data = await loadImageData(imageUrl);
  const mask = buildMask(data, o.alphaThreshold, o.colorThreshold);
  const polys = traceContours(mask, data.width, data.height);
  if (polys.length === 0) {
    throw new Error('silhouette extraction produced no contours');
  }
  // Largest by absolute signed area.
  polys.sort((a, b) => Math.abs(signedArea(b)) - Math.abs(signedArea(a)));
  let outline = polys[0];
  outline = simplifyDP(outline, o.simplifyTolerance);
  // Ensure CCW winding in math sense; in screen coords (y-down) this is CW visually.
  if (signedArea(outline) < 0) outline.reverse();

  const bounds = polygonBounds(outline);
  return { outline, bounds, imageWidth: data.width, imageHeight: data.height };
}

async function loadImageData(url: string): Promise<ImageData> {
  const img = new Image();
  img.crossOrigin = 'anonymous';
  await new Promise<void>((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = () => reject(new Error(`failed to load ${url}`));
    img.src = url;
  });
  const canvas = document.createElement('canvas');
  canvas.width = img.naturalWidth;
  canvas.height = img.naturalHeight;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) throw new Error('2d canvas unavailable');
  ctx.drawImage(img, 0, 0);
  return ctx.getImageData(0, 0, canvas.width, canvas.height);
}

function buildMask(data: ImageData, alphaThr: number, colorThr: number): Uint8Array {
  const { width: w, height: h, data: px } = data;
  const mask = new Uint8Array(w * h);

  // Decide whether the image has meaningful alpha.
  let hasAlpha = false;
  for (let i = 3; i < px.length; i += 4) {
    if (px[i] < 250) {
      hasAlpha = true;
      break;
    }
  }

  if (hasAlpha) {
    for (let i = 0, j = 0; i < mask.length; i++, j += 4) {
      mask[i] = px[j + 3] >= alphaThr ? 1 : 0;
    }
    return mask;
  }

  // Fallback: assume background color is the median of the four corners.
  const corners: Array<[number, number, number]> = [
    rgbAt(px, 0, 0, w),
    rgbAt(px, w - 1, 0, w),
    rgbAt(px, 0, h - 1, w),
    rgbAt(px, w - 1, h - 1, w),
  ];
  const bg: [number, number, number] = [
    median(corners.map((c) => c[0])),
    median(corners.map((c) => c[1])),
    median(corners.map((c) => c[2])),
  ];
  for (let i = 0, j = 0; i < mask.length; i++, j += 4) {
    const dr = px[j] - bg[0];
    const dg = px[j + 1] - bg[1];
    const db = px[j + 2] - bg[2];
    const dist = Math.sqrt(dr * dr + dg * dg + db * db);
    mask[i] = dist > colorThr ? 1 : 0;
  }
  return mask;
}

function rgbAt(px: Uint8ClampedArray, x: number, y: number, w: number): [number, number, number] {
  const j = (y * w + x) * 4;
  return [px[j], px[j + 1], px[j + 2]];
}

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

/**
 * Marching-squares contour tracing on a binary mask.
 * Pads with 0 on all sides so silhouettes touching the image edge close cleanly along it.
 * Returns ordered, closed polygon rings in image pixel coordinates.
 */
function traceContours(mask: Uint8Array, w: number, h: number): Vec2[][] {
  // Padded grid: indices (px = 0..w+1, py = 0..h+1). mask cells go 0..(w-1, h-1).
  const m = (x: number, y: number): number => {
    if (x < 0 || y < 0 || x >= w || y >= h) return 0;
    return mask[y * w + x];
  };

  // Each MS cell is at corner (cx, cy) and uses corners m(cx-1,cy-1), m(cx,cy-1), m(cx,cy), m(cx-1,cy).
  // We sweep cx in [0..w], cy in [0..h] so cells covering the full padded grid (w+1)*(h+1).
  // Output segments connect midpoints of cell edges:
  //   T (top)   = (cx, cy)             … midpoint of top edge of cell, in vertex coords
  //   R (right) = (cx + 0.5, cy + 0.5) … sigh, easier to express in cell-relative half-units.
  // Implementation note: we'll express segment endpoints as half-integer coords (multiply by 2)
  // so we can use them as integer hash keys without floating-point fuzziness.
  //
  // Cell at corner (cx, cy):
  //   TL = m(cx-1, cy-1), TR = m(cx, cy-1), BR = m(cx, cy), BL = m(cx-1, cy)
  //   Midpoint codes (in 2x scale):
  //     T = (2*cx - 1, 2*cy - 2)   // along top edge of cell, between TL and TR
  //     R = (2*cx,     2*cy - 1)
  //     B = (2*cx - 1, 2*cy)
  //     L = (2*cx - 2, 2*cy - 1)
  //   Cell occupies pixel rectangle [cx-1, cx] x [cy-1, cy].

  const edges = new Map<string, string[]>(); // start -> list of ends (string keys "x,y" of doubled coords)
  const addEdge = (a: [number, number], b: [number, number]): void => {
    const ka = `${a[0]},${a[1]}`;
    const kb = `${b[0]},${b[1]}`;
    let list = edges.get(ka);
    if (!list) {
      list = [];
      edges.set(ka, list);
    }
    list.push(kb);
  };

  for (let cy = 0; cy <= h; cy++) {
    for (let cx = 0; cx <= w; cx++) {
      const tl = m(cx - 1, cy - 1);
      const tr = m(cx, cy - 1);
      const br = m(cx, cy);
      const bl = m(cx - 1, cy);
      const code = (tl << 3) | (tr << 2) | (br << 1) | bl;
      if (code === 0 || code === 15) continue;

      const T: [number, number] = [2 * cx - 1, 2 * cy - 2];
      const R: [number, number] = [2 * cx, 2 * cy - 1];
      const B: [number, number] = [2 * cx - 1, 2 * cy];
      const L: [number, number] = [2 * cx - 2, 2 * cy - 1];

      // Foreground-on-right convention (CW around foreground in screen coords).
      switch (code) {
        case 1:  addEdge(B, L); break;            // BL only
        case 2:  addEdge(R, B); break;            // BR only
        case 3:  addEdge(R, L); break;            // BL+BR
        case 4:  addEdge(T, R); break;            // TR only
        case 5:  addEdge(T, R); addEdge(B, L); break; // saddle TR+BL
        case 6:  addEdge(T, B); break;            // TR+BR
        case 7:  addEdge(T, L); break;            // not TL
        case 8:  addEdge(L, T); break;            // TL only
        case 9:  addEdge(B, T); break;            // TL+BL
        case 10: addEdge(L, T); addEdge(R, B); break; // saddle TL+BR
        case 11: addEdge(R, T); break;            // not TR
        case 12: addEdge(L, R); break;            // TL+TR
        case 13: addEdge(B, R); break;            // not BR
        case 14: addEdge(L, B); break;            // not BL
      }
    }
  }

  return assembleRings(edges);
}

function assembleRings(edges: Map<string, string[]>): Vec2[][] {
  const rings: Vec2[][] = [];
  while (edges.size > 0) {
    const startKey = edges.keys().next().value!;
    const ring: Vec2[] = [];
    let cur = startKey;
    while (true) {
      const ends = edges.get(cur);
      if (!ends || ends.length === 0) break;
      const next = ends.shift()!;
      if (ends.length === 0) edges.delete(cur);
      // Convert doubled-int coords back to pixel coords (divide by 2).
      const [xs, ys] = cur.split(',');
      ring.push([Number(xs) / 2, Number(ys) / 2]);
      if (next === startKey) break;
      cur = next;
    }
    if (ring.length >= 3) rings.push(ring);
  }
  return rings;
}

function signedArea(ring: Vec2[]): number {
  let a = 0;
  for (let i = 0; i < ring.length; i++) {
    const [x1, y1] = ring[i];
    const [x2, y2] = ring[(i + 1) % ring.length];
    a += x1 * y2 - x2 * y1;
  }
  return a / 2;
}

function polygonBounds(ring: Vec2[]): { x: number; y: number; width: number; height: number } {
  let xmin = Infinity, ymin = Infinity, xmax = -Infinity, ymax = -Infinity;
  for (const [x, y] of ring) {
    if (x < xmin) xmin = x;
    if (y < ymin) ymin = y;
    if (x > xmax) xmax = x;
    if (y > ymax) ymax = y;
  }
  return { x: xmin, y: ymin, width: xmax - xmin, height: ymax - ymin };
}

/** Iterative Douglas-Peucker simplification on a closed ring. */
function simplifyDP(ring: Vec2[], tolerance: number): Vec2[] {
  if (ring.length < 4) return ring.slice();
  // Find the two vertices with the largest pairwise distance to seed the split.
  let i0 = 0, i1 = 0, maxD = -1;
  for (let i = 0; i < ring.length; i++) {
    const d = sqDist(ring[0], ring[i]);
    if (d > maxD) { maxD = d; i1 = i; }
  }
  // Then re-seed: the point farthest from i1 becomes i0.
  maxD = -1;
  for (let i = 0; i < ring.length; i++) {
    const d = sqDist(ring[i1], ring[i]);
    if (d > maxD) { maxD = d; i0 = i; }
  }
  if (i0 > i1) [i0, i1] = [i1, i0];

  const halfA = ring.slice(i0, i1 + 1);
  const halfB = ring.slice(i1).concat(ring.slice(0, i0 + 1));
  const simplifiedA = dpSimplify(halfA, tolerance);
  const simplifiedB = dpSimplify(halfB, tolerance);
  // Stitch, removing duplicate joining endpoints.
  const out = simplifiedA.concat(simplifiedB.slice(1, simplifiedB.length - 1));
  return out;
}

function dpSimplify(points: Vec2[], tolerance: number): Vec2[] {
  if (points.length < 3) return points.slice();
  const tol2 = tolerance * tolerance;
  const keep = new Uint8Array(points.length);
  keep[0] = 1;
  keep[points.length - 1] = 1;
  const stack: Array<[number, number]> = [[0, points.length - 1]];
  while (stack.length) {
    const [lo, hi] = stack.pop()!;
    let maxD = -1;
    let idx = -1;
    for (let i = lo + 1; i < hi; i++) {
      const d = pointSegSqDist(points[i], points[lo], points[hi]);
      if (d > maxD) { maxD = d; idx = i; }
    }
    if (maxD > tol2 && idx > 0) {
      keep[idx] = 1;
      stack.push([lo, idx], [idx, hi]);
    }
  }
  const out: Vec2[] = [];
  for (let i = 0; i < points.length; i++) if (keep[i]) out.push(points[i]);
  return out;
}

function sqDist(a: Vec2, b: Vec2): number {
  const dx = a[0] - b[0], dy = a[1] - b[1];
  return dx * dx + dy * dy;
}
