import { Delaunay } from "d3-delaunay";
import type { Bounds, CutLine, CutTemplate, OutlineAnalysis, PieceCell, Point } from "./types";

export const DEFAULT_IMAGE_PATH = "res://assets/source/cat_moon.png";
export const DEFAULT_BROWSER_IMAGE = new URL("../../assets/source/cat_moon.png", import.meta.url).href;

export function makeEmptyLevel() {
  return {
    schema: "jigsaw.level.v1" as const,
    version: 1,
    id: "cat_moon_01",
    title: "月亮小睡",
    description: "小猫安静地靠在月亮上，像一段柔软的午后梦。",
    image: {
      path: DEFAULT_IMAGE_PATH,
      name: "cat_moon.png",
      width: 0,
      height: 0,
    },
    background: {
      type: "color" as const,
      color: "#ead8bd",
      path: "",
    },
    component_overrides: {},
    editor: {
      outline: [],
      cuts: [],
      shapes: [],
      pieces: [],
    },
  };
}

export function uid(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.floor(Math.random() * 10000)}`;
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function distance(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export function pointLerp(a: Point, b: Point, t: number): Point {
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
}

export function pointKey(point: Point, precision = 1): string {
  return `${Math.round(point.x / precision) * precision},${Math.round(point.y / precision) * precision}`;
}

export function pathLength(points: Point[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i += 1) total += distance(points[i - 1], points[i]);
  return total;
}

export function samplePath(points: Point[], count: number): Point[] {
  if (points.length < 2) return points;
  const total = pathLength(points);
  if (total <= 0) return points;
  const samples: Point[] = [];
  let segmentIndex = 1;
  let segmentStartLength = 0;
  for (let i = 0; i < count; i += 1) {
    const target = (total * i) / Math.max(1, count - 1);
    while (segmentIndex < points.length - 1) {
      const segLen = distance(points[segmentIndex - 1], points[segmentIndex]);
      if (segmentStartLength + segLen >= target) break;
      segmentStartLength += segLen;
      segmentIndex += 1;
    }
    const a = points[segmentIndex - 1];
    const b = points[segmentIndex];
    const segLen = Math.max(1e-4, distance(a, b));
    samples.push(pointLerp(a, b, clamp((target - segmentStartLength) / segLen, 0, 1)));
  }
  return samples;
}

export function catmullRomPath(points: Point[], tension = 1, closed = false): string {
  if (points.length < 2) return "";
  const source = closed ? [...points, points[0]] : points;
  let d = `M ${source[0].x.toFixed(2)} ${source[0].y.toFixed(2)}`;
  for (let i = 0; i < source.length - 1; i += 1) {
    const p0 = source[Math.max(0, i - 1)];
    const p1 = source[i];
    const p2 = source[i + 1];
    const p3 = source[Math.min(source.length - 1, i + 2)];
    const c1 = {
      x: p1.x + ((p2.x - p0.x) / 6) * tension,
      y: p1.y + ((p2.y - p0.y) / 6) * tension,
    };
    const c2 = {
      x: p2.x - ((p3.x - p1.x) / 6) * tension,
      y: p2.y - ((p3.y - p1.y) / 6) * tension,
    };
    d += ` C ${c1.x.toFixed(2)} ${c1.y.toFixed(2)}, ${c2.x.toFixed(2)} ${c2.y.toFixed(2)}, ${p2.x.toFixed(2)} ${p2.y.toFixed(2)}`;
  }
  if (closed) d += " Z";
  return d;
}

export function pointInPolygon(point: Point, polygon: Point[]): boolean {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    const pi = polygon[i];
    const pj = polygon[j];
    const intersect = pi.y > point.y !== pj.y > point.y && point.x < ((pj.x - pi.x) * (point.y - pi.y)) / (pj.y - pi.y + 1e-9) + pi.x;
    if (intersect) inside = !inside;
  }
  return inside;
}

export function pointToSegment(point: Point, a: Point, b: Point) {
  const vx = b.x - a.x;
  const vy = b.y - a.y;
  const wx = point.x - a.x;
  const wy = point.y - a.y;
  const len2 = vx * vx + vy * vy;
  const t = len2 === 0 ? 0 : clamp((wx * vx + wy * vy) / len2, 0, 1);
  const closest = { x: a.x + vx * t, y: a.y + vy * t };
  return { closest, distance: distance(point, closest), t };
}

export function nearestOnPolyline(point: Point, lines: CutLine[], excludeId = "") {
  let best: null | { closest: Point; distance: number; lineId: string } = null;
  for (const line of lines) {
    if (line.id === excludeId || line.points.length < 2) continue;
    for (let i = 1; i < line.points.length; i += 1) {
      const hit = pointToSegment(point, line.points[i - 1], line.points[i]);
      if (!best || hit.distance < best.distance) best = { closest: hit.closest, distance: hit.distance, lineId: line.id };
    }
  }
  return best;
}

export function nearestPoint(point: Point, points: Point[]) {
  let best: null | { point: Point; distance: number } = null;
  for (const candidate of points) {
    const d = distance(point, candidate);
    if (!best || d < best.distance) best = { point: candidate, distance: d };
  }
  return best;
}

type PixelComponent = {
  pixels: number[];
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
};

type PixelEdge = {
  from: string;
  to: string;
  point: Point;
};

export function detectImageOutline(image: HTMLImageElement, sampleSize = 900): OutlineAnalysis {
  const scale = Math.min(sampleSize / image.naturalWidth, sampleSize / image.naturalHeight, 1);
  const width = Math.max(1, Math.round(image.naturalWidth * scale));
  const height = Math.max(1, Math.round(image.naturalHeight * scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return { outline: [], bounds: null, edgePoints: [] };
  ctx.clearRect(0, 0, width, height);
  ctx.drawImage(image, 0, 0, width, height);
  const data = ctx.getImageData(0, 0, width, height).data;
  const mask = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i += 1) {
    mask[i] = data[i * 4 + 3] > 18 ? 1 : 0;
  }

  const component = largestVisibleComponent(mask, width, height);
  if (!component) return { outline: [], bounds: null, edgePoints: [] };

  const componentMask = new Uint8Array(width * height);
  for (const index of component.pixels) componentMask[index] = 1;

  const loops = traceBoundaryLoops(componentMask, width, height);
  const largestLoop = loops.sort((a, b) => Math.abs(polygonArea(b)) - Math.abs(polygonArea(a)))[0] || [];
  if (largestLoop.length < 3) return { outline: [], bounds: null, edgePoints: [] };

  const rawOutline = largestLoop.map((point) => ({ x: point.x / scale, y: point.y / scale }));
  const simplified = simplifyClosedPath(rawOutline, Math.max(1.2, 1.8 / scale));
  const outline = smoothClosedPath(samplePath([...simplified, simplified[0]], Math.min(420, Math.max(140, simplified.length))), 2);
  const edgePoints = rawOutline.filter((_, index) => index % 2 === 0);

  return {
    outline,
    bounds: {
      x: component.minX / scale,
      y: component.minY / scale,
      width: (component.maxX - component.minX + 1) / scale,
      height: (component.maxY - component.minY + 1) / scale,
    },
    edgePoints,
  };
}

function largestVisibleComponent(mask: Uint8Array, width: number, height: number): PixelComponent | null {
  const visited = new Uint8Array(mask.length);
  let largest: PixelComponent | null = null;
  const neighbors = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  for (let start = 0; start < mask.length; start += 1) {
    if (!mask[start] || visited[start]) continue;
    const pixels: number[] = [];
    const stack = [start];
    visited[start] = 1;
    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;

    while (stack.length) {
      const index = stack.pop() as number;
      pixels.push(index);
      const x = index % width;
      const y = Math.floor(index / width);
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);

      for (const [dx, dy] of neighbors) {
        const nx = x + dx;
        const ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const nextIndex = ny * width + nx;
        if (!mask[nextIndex] || visited[nextIndex]) continue;
        visited[nextIndex] = 1;
        stack.push(nextIndex);
      }
    }

    const component = { pixels, minX, minY, maxX, maxY };
    if (!largest || pixels.length > largest.pixels.length) largest = component;
  }

  return largest;
}

function traceBoundaryLoops(mask: Uint8Array, width: number, height: number): Point[][] {
  const edgeMap = new Map<string, PixelEdge[]>();
  const used = new Set<string>();
  const visible = (x: number, y: number) => x >= 0 && y >= 0 && x < width && y < height && mask[y * width + x] === 1;
  const addEdge = (a: Point, b: Point) => {
    const from = vertexKey(a);
    const edge = { from, to: vertexKey(b), point: b };
    const list = edgeMap.get(from) || [];
    list.push(edge);
    edgeMap.set(from, list);
  };

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (!visible(x, y)) continue;
      if (!visible(x, y - 1)) addEdge({ x, y }, { x: x + 1, y });
      if (!visible(x + 1, y)) addEdge({ x: x + 1, y }, { x: x + 1, y: y + 1 });
      if (!visible(x, y + 1)) addEdge({ x: x + 1, y: y + 1 }, { x, y: y + 1 });
      if (!visible(x - 1, y)) addEdge({ x, y: y + 1 }, { x, y });
    }
  }

  const loops: Point[][] = [];
  for (const edges of edgeMap.values()) {
    for (const edge of edges) {
      const firstKey = edgeKey(edge.from, edge.to);
      if (used.has(firstKey)) continue;
      const loop: Point[] = [parseVertex(edge.from), edge.point];
      used.add(firstKey);
      let current = edge.to;
      let guard = 0;

      while (current !== edge.from && guard < width * height * 4) {
        guard += 1;
        const nextEdge = (edgeMap.get(current) || []).find((candidate) => !used.has(edgeKey(candidate.from, candidate.to)));
        if (!nextEdge) break;
        used.add(edgeKey(nextEdge.from, nextEdge.to));
        loop.push(nextEdge.point);
        current = nextEdge.to;
      }

      if (loop.length > 3 && current === edge.from) loops.push(loop);
    }
  }
  return loops;
}

function vertexKey(point: Point): string {
  return `${point.x},${point.y}`;
}

function parseVertex(key: string): Point {
  const [x, y] = key.split(",").map(Number);
  return { x, y };
}

function edgeKey(from: string, to: string): string {
  return `${from}->${to}`;
}

function polygonArea(points: Point[]): number {
  let area = 0;
  for (let i = 0; i < points.length; i += 1) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area * 0.5;
}

function simplifyClosedPath(points: Point[], epsilon: number): Point[] {
  if (points.length < 4) return points;
  const open = points[0].x === points[points.length - 1].x && points[0].y === points[points.length - 1].y ? points.slice(0, -1) : points;
  const anchorIndex = open.reduce((best, point, index) => (point.x < open[best].x || (point.x === open[best].x && point.y < open[best].y) ? index : best), 0);
  const rotated = [...open.slice(anchorIndex), ...open.slice(0, anchorIndex), open[anchorIndex]];
  const simplified = ramerDouglasPeucker(rotated, epsilon);
  return simplified.slice(0, -1);
}

function ramerDouglasPeucker(points: Point[], epsilon: number): Point[] {
  if (points.length < 3) return points;
  let maxDistance = 0;
  let index = 0;
  for (let i = 1; i < points.length - 1; i += 1) {
    const d = pointToSegment(points[i], points[0], points[points.length - 1]).distance;
    if (d > maxDistance) {
      index = i;
      maxDistance = d;
    }
  }
  if (maxDistance <= epsilon) return [points[0], points[points.length - 1]];
  const left = ramerDouglasPeucker(points.slice(0, index + 1), epsilon);
  const right = ramerDouglasPeucker(points.slice(index), epsilon);
  return [...left.slice(0, -1), ...right];
}

function smoothClosedPath(points: Point[], iterations: number): Point[] {
  let result = points[0] && points[points.length - 1] && distance(points[0], points[points.length - 1]) < 0.001 ? points.slice(0, -1) : points;
  for (let pass = 0; pass < iterations; pass += 1) {
    result = result.map((point, index) => {
      const prev2 = result[(index - 2 + result.length) % result.length];
      const prev1 = result[(index - 1 + result.length) % result.length];
      const next1 = result[(index + 1) % result.length];
      const next2 = result[(index + 2) % result.length];
      return {
        x: (prev2.x + prev1.x * 2 + point.x * 4 + next1.x * 2 + next2.x) / 10,
        y: (prev2.y + prev1.y * 2 + point.y * 4 + next1.y * 2 + next2.y) / 10,
      };
    });
  }
  return result;
}

function seeded(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0xffffffff;
  };
}

function trimSegmentToOutline(a: Point, b: Point, outline: Point[]): Point[] {
  const samples: Point[] = [];
  const chunks = 18;
  let current: Point[] = [];
  let longest: Point[] = [];
  for (let i = 0; i <= chunks; i += 1) {
    const p = pointLerp(a, b, i / chunks);
    if (pointInPolygon(p, outline)) {
      current.push(p);
    } else {
      if (current.length > longest.length) longest = current;
      current = [];
    }
  }
  if (current.length > longest.length) longest = current;
  if (longest.length < 2) return [];
  return samplePath(longest, Math.min(5, longest.length));
}

export function generateFractureNetwork(outline: Point[], bounds: Bounds | null, targetPieces: number) {
  if (!outline.length || !bounds) return { cuts: [] as CutLine[], pieces: [] as PieceCell[] };
  const rand = seeded(targetPieces * 97 + Math.round(bounds.width + bounds.height));
  const sites: Point[] = [];
  const attempts = targetPieces * 80;
  for (let i = 0; i < attempts && sites.length < targetPieces; i += 1) {
    const point = {
      x: bounds.x + rand() * bounds.width,
      y: bounds.y + rand() * bounds.height,
    };
    if (pointInPolygon(point, outline)) sites.push(point);
  }
  const outlineSites = samplePath([...outline, outline[0]], Math.max(8, Math.round(targetPieces * 0.45)));
  const allSites = [...sites, ...outlineSites];
  const delaunay = Delaunay.from(allSites, (p) => p.x, (p) => p.y);
  const voronoi = delaunay.voronoi([bounds.x, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height]);
  const pieces: PieceCell[] = [];
  const cutsByKey = new Map<string, CutLine>();

  for (let i = 0; i < sites.length; i += 1) {
    const cell = voronoi.cellPolygon(i);
    if (!cell || cell.length < 3) continue;
    const polygon = cell.map(([x, y]) => ({ x, y }));
    const center = polygon.reduce((sum, p) => ({ x: sum.x + p.x, y: sum.y + p.y }), { x: 0, y: 0 });
    center.x /= polygon.length;
    center.y /= polygon.length;
    if (!pointInPolygon(center, outline)) continue;
    pieces.push({ id: uid("piece"), points: polygon });

    for (let p = 1; p < polygon.length; p += 1) {
      const a = polygon[p - 1];
      const b = polygon[p];
      const trimmed = trimSegmentToOutline(a, b, outline);
      if (trimmed.length < 2) continue;
      const midpoint = pointLerp(trimmed[0], trimmed[trimmed.length - 1], 0.5);
      const nearOutline = nearestPoint(midpoint, outline);
      if (nearOutline && nearOutline.distance < Math.min(bounds.width, bounds.height) * 0.025) continue;
      const keyA = pointKey(trimmed[0], 8);
      const keyB = pointKey(trimmed[trimmed.length - 1], 8);
      const key = keyA < keyB ? `${keyA}|${keyB}` : `${keyB}|${keyA}`;
      if (!cutsByKey.has(key)) {
        cutsByKey.set(key, {
          id: uid("cut"),
          type: "fracture",
          template: ["classic", "round", "star", "blob", "crescent"][cutsByKey.size % 5] as CutTemplate,
          points: trimmed,
        });
      }
    }
  }

  return { cuts: [...cutsByKey.values()], pieces };
}

export function presetCut(template: CutTemplate, bounds: Bounds): CutLine {
  const cx = bounds.x + bounds.width * 0.5;
  const cy = bounds.y + bounds.height * 0.5;
  const radius = Math.min(bounds.width, bounds.height) * 0.18;
  const count = template === "star" ? 11 : 24;
  const points: Point[] = [];
  for (let i = 0; i < count; i += 1) {
    const angle = (Math.PI * 2 * i) / count - Math.PI / 2;
    let r = radius;
    if (template === "star") r *= i % 2 ? 0.45 : 1;
    if (template === "blob") r *= 0.82 + Math.sin(i * 2.2) * 0.16 + Math.cos(i * 0.8) * 0.1;
    if (template === "crescent") r *= 0.62 + Math.sin(angle) * 0.24;
    if (template === "classic") r *= 0.86 + Math.sin(angle * 3) * 0.22;
    if (template === "zigzag") r *= i % 2 ? 0.72 : 1.05;
    points.push({ x: cx + Math.cos(angle) * r, y: cy + Math.sin(angle) * r });
  }
  points.push(points[0]);
  return { id: uid("shape"), type: "preset_shape", template, points };
}

export function snapPoint(point: Point, outlinePoints: Point[], cuts: CutLine[], threshold: number, excludeId = "") {
  const boundaryHit = nearestPoint(point, outlinePoints);
  const cutHit = nearestOnPolyline(point, cuts, excludeId);
  let best: null | { point: Point; distance: number; kind: string } = null;
  if (boundaryHit && boundaryHit.distance <= threshold) best = { point: boundaryHit.point, distance: boundaryHit.distance, kind: "outline" };
  if (cutHit && cutHit.distance <= threshold && (!best || cutHit.distance < best.distance)) {
    best = { point: cutHit.closest, distance: cutHit.distance, kind: "cut" };
  }
  return best;
}

export function serializePoints(points: Point[]): number[][] {
  return points.map((point) => [Math.round(point.x * 100) / 100, Math.round(point.y * 100) / 100]);
}
