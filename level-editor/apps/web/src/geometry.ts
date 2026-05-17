import { Delaunay } from "d3-delaunay";
import type { Bounds, CutLine, CutTemplate, LevelConfig, LevelPiece, OutlineAnalysis, PieceCell, Point } from "./types";

export const DEFAULT_IMAGE_PATH = "res://levels/cat/cat_moon_01/source.png";
export const DEFAULT_BROWSER_IMAGE = "/api/levels/cat/cat_moon_01/source";

export function makeEmptyLevel(): LevelConfig {
  return {
    schema: "jigsaw.level.v1" as const,
    version: 1,
    id: "cat_moon_01",
    topic_id: "cat",
    locale: "zh-Hans",
    title: "月亮小睡",
    description: "小猫安静地靠在月亮上，像一段柔软的午后梦。",
    title_i18n: {
      "zh-Hans": "月亮小睡",
      en: "Moon Nap",
    },
    description_i18n: {
      "zh-Hans": "小猫安静地靠在月亮上，像一段柔软的午后梦。",
      en: "A quiet cat rests on a crescent moon like a soft afternoon dream.",
    },
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
    grid: {
      cols: 8,
      rows: 8,
      piece_size: 190,
    },
    runtime_layout: {
      coordinate_space: "source_pixels",
      target: "mobile_portrait",
      min_viewport: [360, 640],
      board_margin_ratio: 1,
      hud_height_ratio: 0,
      side_margin_ratio: 0,
      bottom_margin_ratio: 0,
    },
    component_overrides: {},
    modes: {
      polygon: {
        source: "precomputed" as const,
        pieces: [],
      },
      knob: {
        source: "precomputed" as const,
        cols: 8,
        rows: 8,
        piece_size: 190,
        knob_size: 0.24,
        pieces: [],
      },
    },
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

export function nearestOnPath(point: Point, points: Point[], closed = false) {
  if (points.length < 2) return nearestPoint(point, points);
  let best: null | { point: Point; distance: number; segmentIndex: number } = null;
  const segmentCount = closed ? points.length : points.length - 1;
  for (let i = 0; i < segmentCount; i += 1) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    const hit = pointToSegment(point, a, b);
    if (!best || hit.distance < best.distance) best = { point: hit.closest, distance: hit.distance, segmentIndex: i };
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

export function traceBoundaryLoops(mask: Uint8Array, width: number, height: number): Point[][] {
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

export function polygonArea(points: Point[]): number {
  let area = 0;
  for (let i = 0; i < points.length; i += 1) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area * 0.5;
}

export function simplifyClosedPath(points: Point[], epsilon: number): Point[] {
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

export function smoothClosedPath(points: Point[], iterations: number): Point[] {
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
  const chunks = Math.max(24, Math.ceil(distance(a, b) / 5));
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

function normalizeVector(vector: Point): Point {
  const length = Math.hypot(vector.x, vector.y);
  if (length < 1e-6) return { x: 0, y: 0 };
  return { x: vector.x / length, y: vector.y / length };
}

function outlineCenter(bounds: Bounds): Point {
  return { x: bounds.x + bounds.width * 0.5, y: bounds.y + bounds.height * 0.5 };
}

function cutEndpointRefs(cuts: CutLine[]) {
  return cuts.flatMap((cut, cutIndex) => [
    { cutIndex, end: 0 as const, point: cut.points[0] },
    { cutIndex, end: 1 as const, point: cut.points[cut.points.length - 1] },
  ]);
}

function setCutEndpoint(cuts: CutLine[], cutIndex: number, end: 0 | 1, point: Point) {
  const points = cuts[cutIndex].points;
  if (end === 0) points[0] = point;
  else points[points.length - 1] = point;
}

function snapCloseCutEndpoints(cuts: CutLine[], threshold: number) {
  const refs = cutEndpointRefs(cuts);
  const used = new Set<number>();
  for (let i = 0; i < refs.length; i += 1) {
    if (used.has(i)) continue;
    const cluster = [i];
    used.add(i);
    for (let cursor = 0; cursor < cluster.length; cursor += 1) {
      const current = refs[cluster[cursor]].point;
      for (let j = 0; j < refs.length; j += 1) {
        if (used.has(j)) continue;
        if (distance(current, refs[j].point) > threshold) continue;
        used.add(j);
        cluster.push(j);
      }
    }
    if (cluster.length < 2) continue;
    const average = cluster.reduce(
      (sum, index) => ({ x: sum.x + refs[index].point.x / cluster.length, y: sum.y + refs[index].point.y / cluster.length }),
      { x: 0, y: 0 },
    );
    for (const index of cluster) setCutEndpoint(cuts, refs[index].cutIndex, refs[index].end, average);
  }
}

function extendEndpointPastOutline(cut: CutLine, end: 0 | 1, outline: Point[], bounds: Bounds, snapDistance: number, padding: number): Point | null {
  const point = end === 0 ? cut.points[0] : cut.points[cut.points.length - 1];
  const neighbor = end === 0 ? cut.points[1] : cut.points[cut.points.length - 2];
  if (!neighbor) return null;
  const hit = nearestOnPath(point, outline, true);
  if (!hit || hit.distance > snapDistance) return null;

  let direction = normalizeVector({ x: point.x - neighbor.x, y: point.y - neighbor.y });
  let candidate = { x: hit.point.x + direction.x * padding, y: hit.point.y + direction.y * padding };
  if (pointInPolygon(candidate, outline)) {
    const center = outlineCenter(bounds);
    direction = normalizeVector({ x: hit.point.x - center.x, y: hit.point.y - center.y });
    candidate = { x: hit.point.x + direction.x * padding, y: hit.point.y + direction.y * padding };
  }
  return candidate;
}

function prepareAutoGeneratedCuts(cuts: CutLine[], outline: Point[], bounds: Bounds): CutLine[] {
  const next = cuts.map((cut) => ({ ...cut, points: cut.points.map((point) => ({ ...point })) }));
  const minSide = Math.max(1, Math.min(bounds.width, bounds.height));
  snapCloseCutEndpoints(next, Math.max(10, minSide * 0.018));
  const outlineSnapDistance = Math.max(10, minSide * 0.035);
  const outsidePadding = Math.min(16, Math.max(10, minSide * 0.018));
  for (const cut of next) {
    if (cut.points.length < 2) continue;
    const start = extendEndpointPastOutline(cut, 0, outline, bounds, outlineSnapDistance, outsidePadding);
    if (start) cut.points[0] = start;
    const end = extendEndpointPastOutline(cut, 1, outline, bounds, outlineSnapDistance, outsidePadding);
    if (end) cut.points[cut.points.length - 1] = end;
  }
  snapCloseCutEndpoints(next, Math.max(8, minSide * 0.014));
  return next;
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
          template: ["knob", "round", "star", "blob", "crescent"][cutsByKey.size % 5] as CutTemplate,
          points: trimmed,
        });
      }
    }
  }

  return { cuts: prepareAutoGeneratedCuts([...cutsByKey.values()], outline, bounds), pieces };
}

export function presetCut(template: CutTemplate, bounds: Bounds): CutLine {
  return { id: uid("shape"), type: "preset_shape", template, points: presetShapePoints(template, bounds) };
}

export function presetShapePoints(template: CutTemplate, bounds: Bounds): Point[] {
  const cx = bounds.x + bounds.width * 0.5;
  const cy = bounds.y + bounds.height * 0.5;
  const radius = Math.min(bounds.width, bounds.height) * 0.18;

  if (template === "circle" || template === "round") {
    return sampleArc(cx, cy, radius, -Math.PI / 2, Math.PI * 1.5, 40, false);
  }

  if (template === "star") {
    return Array.from({ length: 10 }, (_, index) => {
      const angle = (Math.PI * 2 * index) / 10 - Math.PI / 2;
      const r = index % 2 === 0 ? radius : radius * 0.46;
      return { x: cx + Math.cos(angle) * r, y: cy + Math.sin(angle) * r };
    });
  }

  if (template === "blob") {
    return Array.from({ length: 36 }, (_, index) => {
      const angle = (Math.PI * 2 * index) / 36 - Math.PI / 2;
      const wave = 0.92 + Math.sin(angle * 3 + 0.5) * 0.08 + Math.cos(angle * 5 - 0.4) * 0.05;
      return { x: cx + Math.cos(angle) * radius * wave, y: cy + Math.sin(angle) * radius * wave };
    });
  }

  if (template === "crescent") {
    const outer = sampleArc(cx + radius * 0.02, cy, radius * 1.05, Math.PI * 0.64, Math.PI * 1.36, 22, true);
    const inner = sampleArc(cx + radius * 0.38, cy, radius * 0.78, Math.PI * 1.36, Math.PI * 0.64, 22, true);
    return [...outer, ...inner];
  }

  if (template === "zigzag") {
    return scaleUnitShape(
      [
        [0.2, 0.14],
        [0.62, 0.14],
        [0.49, 0.39],
        [0.78, 0.39],
        [0.3, 0.86],
        [0.43, 0.56],
        [0.18, 0.56],
      ],
      cx,
      cy,
      radius * 2.1,
    );
  }

  return knobShapePoints(cx, cy, radius);
}

function sampleArc(cx: number, cy: number, radius: number, start: number, end: number, steps: number, includeEnd = true): Point[] {
  return Array.from({ length: includeEnd ? steps + 1 : steps }, (_, index) => {
    const angle = start + ((end - start) * index) / steps;
    return { x: cx + Math.cos(angle) * radius, y: cy + Math.sin(angle) * radius };
  });
}

function scaleUnitShape(points: [number, number][], cx: number, cy: number, size: number): Point[] {
  return points.map(([x, y]) => ({
    x: cx + (x - 0.5) * size,
    y: cy + (y - 0.5) * size,
  }));
}

function knobShapePoints(cx: number, cy: number, radius: number): Point[] {
  const width = radius * 1.95;
  const height = radius * 1.72;
  const knob = radius * 0.26;
  const left = cx - width * 0.5;
  const right = cx + width * 0.5;
  const top = cy - height * 0.5;
  const bottom = cy + height * 0.5;

  return [
    { x: left, y: top },
    { x: cx - knob, y: top },
    ...sampleArc(cx, top, knob, Math.PI, Math.PI * 2, 8, true),
    { x: right, y: top },
    { x: right, y: cy - knob },
    ...sampleArc(right, cy, knob, -Math.PI / 2, Math.PI / 2, 8, true),
    { x: right, y: bottom },
    { x: cx + knob, y: bottom },
    ...sampleArc(cx, bottom, knob, 0, Math.PI, 8, true),
    { x: left, y: bottom },
    { x: left, y: cy + knob },
    ...sampleArc(left, cy, knob, Math.PI / 2, Math.PI * 1.5, 8, true),
  ];
}

type KnobPieceDraft = {
  id: string;
  cell: [number, number];
  home: Point;
  points: Point[];
  visibleBounds: Bounds;
  neighbors: string[];
  cutLines: Point[][];
};

export function generateKnobPieces(image: HTMLImageElement | null, cols: number, rows: number, knobSize: number): LevelPiece[] {
  if (!image) return [];
  const safeCols = Math.max(1, Math.round(cols));
  const safeRows = Math.max(1, Math.round(rows));
  const width = image.naturalWidth;
  const height = image.naturalHeight;
  const edgeDefs = createKnobEdgeDefs(width, height, safeCols, safeRows, knobSize);
  const alpha = readAlphaMask(image);
  const draftsByKey = new Map<string, KnobPieceDraft>();

  for (let row = 0; row < safeRows; row += 1) {
    for (let col = 0; col < safeCols; col += 1) {
      const points = buildKnobPiecePolygon(edgeDefs, col, row);
      const alphaBounds = visibleAlphaBoundsForPolygon(points, alpha);
      if (!alphaBounds) continue;
      const id = `k_${col}_${row}`;
      draftsByKey.set(`${col},${row}`, {
        id,
        cell: [col, row],
        home: { x: alphaBounds.x + alphaBounds.width * 0.5, y: alphaBounds.y + alphaBounds.height * 0.5 },
        points,
        visibleBounds: alphaBounds,
        neighbors: [],
        cutLines: [],
      });
    }
  }

  for (const draft of draftsByKey.values()) {
    const [col, row] = draft.cell;
    const neighborSpecs = [
      { key: `${col},${row - 1}`, path: edgeDefs.h[row][col], reversed: false },
      { key: `${col + 1},${row}`, path: edgeDefs.v[col + 1][row], reversed: false },
      { key: `${col},${row + 1}`, path: edgeDefs.h[row + 1][col], reversed: true },
      { key: `${col - 1},${row}`, path: edgeDefs.v[col][row], reversed: true },
    ];
    for (const spec of neighborSpecs) {
      const neighbor = draftsByKey.get(spec.key);
      if (!neighbor) continue;
      draft.neighbors.push(neighbor.id);
      draft.cutLines.push(spec.reversed ? [...spec.path].reverse() : spec.path);
    }
  }

  return [...draftsByKey.values()].map((piece) => ({
    id: piece.id,
    cell: piece.cell,
    home: serializePoint(piece.home),
    points: serializePoints(piece.points),
    neighbors: piece.neighbors,
    cut_lines: piece.cutLines.map(serializePoints),
    visible_bounds: serializeBounds(piece.visibleBounds),
    visible_bounds_list: [serializeBounds(piece.visibleBounds)],
  }));
}

function createKnobEdgeDefs(width: number, height: number, cols: number, rows: number, knobSize: number) {
  const h: Point[][][] = [];
  const v: Point[][][] = [];
  const cellSize = Math.min(width / cols, height / rows);
  for (let row = 0; row <= rows; row += 1) {
    const line: Point[][] = [];
    for (let col = 0; col < cols; col += 1) {
      const start = { x: (width * col) / cols, y: (height * row) / rows };
      const end = { x: (width * (col + 1)) / cols, y: (height * row) / rows };
      const sign = row === 0 || row === rows ? 0 : edgeSign(col, row);
      line.push(buildKnobEdge(start, end, sign, cellSize, knobSize));
    }
    h.push(line);
  }
  for (let col = 0; col <= cols; col += 1) {
    const line: Point[][] = [];
    for (let row = 0; row < rows; row += 1) {
      const start = { x: (width * col) / cols, y: (height * row) / rows };
      const end = { x: (width * col) / cols, y: (height * (row + 1)) / rows };
      const sign = col === 0 || col === cols ? 0 : edgeSign(col, row);
      line.push(buildKnobEdge(start, end, sign, cellSize, knobSize));
    }
    v.push(line);
  }
  return { h, v };
}

function edgeSign(a: number, b: number): number {
  return (a * 31 + b * 17 + 5) % 2 === 0 ? 1 : -1;
}

function buildKnobEdge(start: Point, end: Point, sign: number, cellSize: number, knobSize: number): Point[] {
  if (sign === 0) return samplePath([start, end], 9);
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const length = Math.hypot(dx, dy);
  const ux = dx / length;
  const uy = dy / length;
  const nx = uy;
  const ny = -ux;
  const radius = Math.min(length * 0.16, cellSize * clamp(knobSize, 0.12, 0.36));
  const neckHalf = radius * 0.82;
  const center = length * 0.5;
  const left = center - neckHalf;
  const right = center + neckHalf;
  const neckOffset = radius * 0.52 * sign;
  const arcCenterOffset = neckOffset;
  const arcRadius = neckHalf;
  const points: Point[] = [];
  const push = (along: number, offset: number) => {
    points.push({
      x: start.x + ux * along + nx * offset,
      y: start.y + uy * along + ny * offset,
    });
  };

  for (let i = 0; i <= 5; i += 1) push((left * i) / 5, 0);
  push(left, neckOffset);
  for (let i = 0; i <= 14; i += 1) {
    const angle = Math.PI - (Math.PI * i) / 14;
    const along = center + Math.cos(angle) * arcRadius;
    const offset = arcCenterOffset + Math.sin(angle) * radius * sign;
    push(along, offset);
  }
  push(right, 0);
  for (let i = 1; i <= 5; i += 1) push(right + ((length - right) * i) / 5, 0);
  return points;
}

function buildKnobPiecePolygon(edgeDefs: ReturnType<typeof createKnobEdgeDefs>, col: number, row: number): Point[] {
  const points: Point[] = [];
  appendPath(points, edgeDefs.h[row][col], false);
  appendPath(points, edgeDefs.v[col + 1][row], false);
  appendPath(points, edgeDefs.h[row + 1][col], true);
  appendPath(points, edgeDefs.v[col][row], true);
  return points;
}

function appendPath(target: Point[], source: Point[], reversed: boolean) {
  const points = reversed ? [...source].reverse() : source;
  for (let i = 0; i < points.length; i += 1) {
    if (target.length > 0 && i === 0) continue;
    target.push(points[i]);
  }
}

function readAlphaMask(image: HTMLImageElement) {
  const canvas = document.createElement("canvas");
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return null;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(image, 0, 0);
  return {
    width: canvas.width,
    height: canvas.height,
    data: ctx.getImageData(0, 0, canvas.width, canvas.height).data,
  };
}

function visibleAlphaBoundsForPolygon(points: Point[], alpha: ReturnType<typeof readAlphaMask>): Bounds | null {
  if (!alpha) return boundsForPoints(points);
  const bounds = boundsForPoints(points);
  let count = 0;
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  const x0 = Math.max(0, Math.floor(bounds.x));
  const y0 = Math.max(0, Math.floor(bounds.y));
  const x1 = Math.min(alpha.width - 1, Math.ceil(bounds.x + bounds.width));
  const y1 = Math.min(alpha.height - 1, Math.ceil(bounds.y + bounds.height));
  for (let y = y0; y <= y1; y += 1) {
    for (let x = x0; x <= x1; x += 1) {
      if (!pointInPolygon({ x, y }, points)) continue;
      if (alpha.data[(y * alpha.width + x) * 4 + 3] > 18) {
        count += 1;
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }
  if (count < 24 || !Number.isFinite(minX)) return null;
  return { x: minX, y: minY, width: Math.max(1, maxX - minX + 1), height: Math.max(1, maxY - minY + 1) };
}

function boundsForPoints(points: Point[]): Bounds {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const point of points) {
    minX = Math.min(minX, point.x);
    minY = Math.min(minY, point.y);
    maxX = Math.max(maxX, point.x);
    maxY = Math.max(maxY, point.y);
  }
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
}

function serializeBounds(bounds: Bounds): number[] {
  return [
    Math.round(bounds.x * 100) / 100,
    Math.round(bounds.y * 100) / 100,
    Math.round(bounds.width * 100) / 100,
    Math.round(bounds.height * 100) / 100,
  ];
}

export function snapPoint(point: Point, outlinePoints: Point[], cuts: CutLine[], threshold: number, excludeId = "") {
  const boundaryHit = nearestOnPath(point, outlinePoints, true);
  const cutHit = nearestOnPolyline(point, cuts, excludeId);
  let best: null | { point: Point; distance: number; kind: string } = null;
  if (boundaryHit && boundaryHit.distance <= threshold) best = { point: boundaryHit.point, distance: boundaryHit.distance, kind: "outline" };
  if (cutHit && cutHit.distance <= threshold && (!best || cutHit.distance < best.distance)) {
    best = { point: cutHit.closest, distance: cutHit.distance, kind: "cut" };
  }
  return best;
}

export type ActualPiecePreview = {
  count: number;
  dataUrl: string;
  width: number;
  height: number;
  pieces: PieceCell[];
  minArea: number;
  smallPieceIds: string[];
};

export type CutGap = {
  cutId: string;
  point: Point;
  nearest: Point;
  distance: number;
  kind: "outline" | "cut";
};

export function analyzeActualPieces(image: HTMLImageElement, cuts: CutLine[], maxSize = 1200): ActualPiecePreview {
  const scale = Math.min(maxSize / image.naturalWidth, maxSize / image.naturalHeight, 1);
  const width = Math.max(1, Math.round(image.naturalWidth * scale));
  const height = Math.max(1, Math.round(image.naturalHeight * scale));
  const imageCanvas = document.createElement("canvas");
  imageCanvas.width = width;
  imageCanvas.height = height;
  const imageCtx = imageCanvas.getContext("2d", { willReadFrequently: true });
  if (!imageCtx) return { count: 0, dataUrl: "", width, height, pieces: [], minArea: 0, smallPieceIds: [] };
  imageCtx.clearRect(0, 0, width, height);
  imageCtx.drawImage(image, 0, 0, width, height);
  const imageData = imageCtx.getImageData(0, 0, width, height);
  const visible = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i += 1) visible[i] = imageData.data[i * 4 + 3] > 18 ? 1 : 0;

  const barrierCanvas = document.createElement("canvas");
  barrierCanvas.width = width;
  barrierCanvas.height = height;
  const barrierCtx = barrierCanvas.getContext("2d", { willReadFrequently: true });
  if (!barrierCtx) return { count: 0, dataUrl: "", width, height, pieces: [], minArea: 0, smallPieceIds: [] };
  barrierCtx.clearRect(0, 0, width, height);
  barrierCtx.strokeStyle = "#fff";
  barrierCtx.lineCap = "butt";
  barrierCtx.lineJoin = "miter";
  barrierCtx.lineWidth = Math.max(1, Math.round(scale));
  for (const cut of cuts) {
    if (cut.points.length < 2) continue;
    barrierCtx.beginPath();
    barrierCtx.moveTo(cut.points[0].x * scale, cut.points[0].y * scale);
    for (let i = 1; i < cut.points.length; i += 1) barrierCtx.lineTo(cut.points[i].x * scale, cut.points[i].y * scale);
    if (cut.type === "preset_shape") barrierCtx.closePath();
    barrierCtx.stroke();
  }
  const barrierData = barrierCtx.getImageData(0, 0, width, height).data;
  for (let i = 0; i < width * height; i += 1) {
    if (barrierData[i * 4 + 3] > 0) visible[i] = 0;
  }

  const preview = imageCtx.createImageData(width, height);
  const visited = new Uint8Array(width * height);
  const colors = [
    [111, 157, 103],
    [217, 147, 63],
    [93, 141, 174],
    [186, 114, 129],
    [154, 132, 80],
    [137, 116, 176],
    [89, 152, 145],
    [199, 124, 46],
  ];
  let count = 0;
  let minArea = Number.POSITIVE_INFINITY;
  const pieces: PieceCell[] = [];
  const smallPieceIds: string[] = [];
  const neighbors = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  for (let start = 0; start < visible.length; start += 1) {
    if (!visible[start] || visited[start]) continue;
    const color = colors[count % colors.length];
    const pieceId = `piece_${String(count + 1).padStart(2, "0")}`;
    const componentPixels: number[] = [];
    count += 1;
    const stack = [start];
    visited[start] = 1;
    while (stack.length) {
      const index = stack.pop() as number;
      componentPixels.push(index);
      preview.data[index * 4] = color[0];
      preview.data[index * 4 + 1] = color[1];
      preview.data[index * 4 + 2] = color[2];
      preview.data[index * 4 + 3] = 88;
      const x = index % width;
      const y = Math.floor(index / width);
      for (const [dx, dy] of neighbors) {
        const nx = x + dx;
        const ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const nextIndex = ny * width + nx;
        if (!visible[nextIndex] || visited[nextIndex]) continue;
        visited[nextIndex] = 1;
        stack.push(nextIndex);
      }
    }

    const area = componentPixels.length / Math.max(1e-6, scale * scale);
    minArea = Math.min(minArea, area);
    if (area < 900) smallPieceIds.push(pieceId);

    const componentMask = new Uint8Array(width * height);
    for (const index of componentPixels) componentMask[index] = 1;
    const loops = traceBoundaryLoops(componentMask, width, height);
    const largestLoop = loops.sort((a, b) => Math.abs(polygonArea(b)) - Math.abs(polygonArea(a)))[0] || [];
    if (largestLoop.length >= 4) {
      const raw = largestLoop.map((point) => ({ x: point.x / scale, y: point.y / scale }));
      const simplified = simplifyClosedPath(raw, Math.max(1.5, 2.2 / Math.max(scale, 1e-6)));
      pieces.push({ id: pieceId, points: simplified });
    }
  }

  imageCtx.putImageData(preview, 0, 0);
  return {
    count,
    dataUrl: imageCanvas.toDataURL("image/png"),
    width,
    height,
    pieces,
    minArea: Number.isFinite(minArea) ? minArea : 0,
    smallPieceIds,
  };
}

export function findCutGaps(cuts: CutLine[], outlinePoints: Point[], connectedDistance = 1.5, warningDistance = 18): CutGap[] {
  const gaps: CutGap[] = [];
  for (const cut of cuts) {
    if (cut.points.length < 2 || cut.type !== "fracture") continue;
    const endpoints = [cut.points[0], cut.points[cut.points.length - 1]];
    for (const point of endpoints) {
      const outlineHit = nearestOnPath(point, outlinePoints, true);
      const cutHit = nearestOnPolyline(point, cuts, cut.id);
      let best: null | CutGap = null;
      if (outlineHit) {
        best = {
          cutId: cut.id,
          point,
          nearest: outlineHit.point,
          distance: outlineHit.distance,
          kind: "outline",
        };
      }
      if (cutHit && (!best || cutHit.distance < best.distance)) {
        best = {
          cutId: cut.id,
          point,
          nearest: cutHit.closest,
          distance: cutHit.distance,
          kind: "cut",
        };
      }
      if (best && best.distance > connectedDistance && best.distance <= warningDistance) gaps.push(best);
    }
  }
  return gaps.sort((a, b) => a.distance - b.distance);
}

export function serializePoints(points: Point[]): number[][] {
  return points.map((point) => [Math.round(point.x * 100) / 100, Math.round(point.y * 100) / 100]);
}

function serializePoint(point: Point): number[] {
  return [Math.round(point.x * 100) / 100, Math.round(point.y * 100) / 100];
}
