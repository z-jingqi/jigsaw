import { Delaunay } from "d3-delaunay";
import polygonClipping from "polygon-clipping";
import type { MultiPolygon, Pair, Polygon, Ring } from "polygon-clipping";
import type { LevelPiece, Point } from "./types";

type CellPiece = LevelPiece & { cells: string[] };
export type ShapeKind = "circle" | "square" | "heart" | "triangle";
export type ShapeRequest = {
  kind: ShapeKind;
  count: number;
};

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

export function zhI18n(value: string) {
  return { zh: value, "zh-Hans": value, _: value };
}

export function slug(value: string, fallback: string) {
  const cleaned = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/gi, "_")
    .replace(/^_+|_+$/g, "");
  return /^[a-z][a-z0-9_]*$/.test(cleaned) ? cleaned : fallback;
}

export function sequentialId(prefix: string, existingIds: string[]) {
  const used = new Set(existingIds);
  let index = 1;
  while (true) {
    const id = `${prefix}_${String(index).padStart(2, "0")}`;
    if (!used.has(id)) return id;
    index += 1;
  }
}

export function chooseGrid(target: number, imageWidth: number, imageHeight: number) {
  const goal = clamp(Math.round(target), 4, 80);
  let best = { cols: 3, rows: 4, score: Number.POSITIVE_INFINITY };
  for (let rows = 2; rows <= 14; rows++) {
    for (let cols = 2; cols <= 14; cols++) {
      const count = cols * rows;
      const cellW = imageWidth / cols;
      const cellH = imageHeight / rows;
      const squareError = Math.abs(cellW - cellH) / Math.max(cellW, cellH);
      const countError = Math.abs(count - goal) / goal;
      const score = squareError * 1.8 + countError;
      if (score < best.score) best = { cols, rows, score };
    }
  }
  return best;
}

function random(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0xffffffff;
  };
}

export function generatePieces(imageWidth: number, imageHeight: number, targetCount: number, shapeRequests: ShapeRequest[] = []): LevelPiece[] {
  const rng = random(Math.round(imageWidth * 13 + imageHeight * 17 + targetCount * 31 + shapeRequests.length * 43));
  const pieces: CellPiece[] = [];
  const shapePolygons: Point[][] = [];
  let shapeIndex = 1;
  for (const request of shapeRequests) {
    for (let index = 0; index < request.count; index++) {
      const polygon = placeShape(request.kind, imageWidth, imageHeight, targetCount, shapePolygons, rng);
      if (polygon.length >= 3) {
        shapePolygons.push(polygon);
        pieces.push(pieceFromPolygon(`shape_${request.kind}_${shapeIndex}`, polygon, [`shape:${request.kind}:${shapeIndex}`]));
      }
      shapeIndex += 1;
    }
  }

  const randomPoints = generateVoronoiPoints(imageWidth, imageHeight, Math.max(4, targetCount - pieces.length), shapePolygons, rng);
  const delaunay = Delaunay.from(randomPoints);
  const voronoi = delaunay.voronoi([0, 0, imageWidth, imageHeight]);
  const shapeClips = shapePolygons.map((polygon) => [closedRing(polygon)] as Polygon);

  for (let index = 0; index < randomPoints.length; index++) {
    const cell = Array.from(voronoi.cellPolygon(index) || []) as Point[];
    const ring = cleanRing(cell);
    if (ring.length < 3) continue;
    const clipped = shapeClips.length ? polygonClipping.difference([closedRing(ring)], ...shapeClips) : ([[closedRing(ring)]] as MultiPolygon);
    for (const polygon of clipped) {
      const outer = cleanRing(polygon[0] as Point[]);
      if (outer.length < 3 || polygonAreaAbs(outer) < (imageWidth * imageHeight) / Math.max(240, targetCount * 10)) continue;
      pieces.push(pieceFromPolygon(`piece_${pieces.length + 1}`, outer, [`voronoi:${index}`]));
    }
  }
  return withNeighbors(pieces);
}

function generateVoronoiPoints(imageWidth: number, imageHeight: number, count: number, blocked: Point[][], rng: () => number): Point[] {
  const points: Point[] = [];
  const minDistance = Math.sqrt((imageWidth * imageHeight) / Math.max(1, count)) * 0.34;
  for (let attempt = 0; attempt < count * 80 && points.length < count; attempt++) {
    const marginX = imageWidth * 0.035;
    const marginY = imageHeight * 0.035;
    const point: Point = [
      marginX + rng() * (imageWidth - marginX * 2),
      marginY + rng() * (imageHeight - marginY * 2),
    ];
    if (blocked.some((polygon) => pointInPolygon(point, polygon))) continue;
    if (points.some((candidate) => distance(candidate, point) < minDistance * (0.75 + rng() * 0.25))) continue;
    points.push(point);
  }
  while (points.length < count) {
    points.push([rng() * imageWidth, rng() * imageHeight]);
  }
  return points;
}

function placeShape(kind: ShapeKind, imageWidth: number, imageHeight: number, targetCount: number, existing: Point[][], rng: () => number): Point[] {
  const averageSize = Math.sqrt((imageWidth * imageHeight) / Math.max(4, targetCount));
  const radius = averageSize * (kind === "heart" ? 0.78 : kind === "square" ? 0.68 : 0.72);
  for (let attempt = 0; attempt < 180; attempt++) {
    const center: Point = [
      radius * 1.5 + rng() * (imageWidth - radius * 3),
      radius * 1.5 + rng() * (imageHeight - radius * 3),
    ];
    const polygon = shapePolygon(kind, center, radius);
    if (existing.some((other) => polygonsOverlapRough(polygon, other))) continue;
    return polygon;
  }
  return [];
}

function shapePolygon(kind: ShapeKind, center: Point, radius: number): Point[] {
  if (kind === "square") {
    const angle = Math.PI / 9;
    return [
      [-1, -1],
      [1, -1],
      [1, 1],
      [-1, 1],
    ].map(([x, y]) => rotatePoint([center[0] + x * radius, center[1] + y * radius], center, angle));
  }
  if (kind === "triangle") {
    return [0, 1, 2].map((index) => {
      const angle = -Math.PI / 2 + index * (Math.PI * 2 / 3);
      return [center[0] + Math.cos(angle) * radius * 1.25, center[1] + Math.sin(angle) * radius * 1.25];
    });
  }
  if (kind === "heart") {
    const points: Point[] = [];
    for (let i = 0; i < 34; i++) {
      const t = (Math.PI * 2 * i) / 34;
      const x = 16 * Math.pow(Math.sin(t), 3);
      const y = -(13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t));
      points.push([center[0] + (x / 18) * radius, center[1] + (y / 18) * radius]);
    }
    return points;
  }
  const points: Point[] = [];
  for (let i = 0; i < 28; i++) {
    const angle = (Math.PI * 2 * i) / 28;
    points.push([center[0] + Math.cos(angle) * radius, center[1] + Math.sin(angle) * radius]);
  }
  return points;
}

function rotatePoint(point: Point, center: Point, angle: number): Point {
  const dx = point[0] - center[0];
  const dy = point[1] - center[1];
  return [
    center[0] + dx * Math.cos(angle) - dy * Math.sin(angle),
    center[1] + dx * Math.sin(angle) + dy * Math.cos(angle),
  ];
}

function cleanRing(points: Point[]) {
  const cleaned = points
    .map((point) => [Number(point[0]), Number(point[1])] as Point)
    .filter((point) => Number.isFinite(point[0]) && Number.isFinite(point[1]));
  if (cleaned.length > 1 && distance(cleaned[0], cleaned[cleaned.length - 1]) < 0.001) cleaned.pop();
  return cleaned;
}

function closedRing(points: Point[]): Ring {
  const ring = cleanRing(points).map((point) => [point[0], point[1]] as Pair);
  if (ring.length && (ring[0][0] !== ring[ring.length - 1][0] || ring[0][1] !== ring[ring.length - 1][1])) {
    ring.push([ring[0][0], ring[0][1]]);
  }
  return ring;
}

function polygonAreaAbs(points: Point[]) {
  return Math.abs(signedArea(points));
}

function signedArea(points: Point[]) {
  let area = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    area += a[0] * b[1] - b[0] * a[1];
  }
  return area / 2;
}

function pointInPolygon(point: Point, polygon: Point[]) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i];
    const b = polygon[j];
    const intersects = a[1] > point[1] !== b[1] > point[1] && point[0] < ((b[0] - a[0]) * (point[1] - a[1])) / (b[1] - a[1] || 1) + a[0];
    if (intersects) inside = !inside;
  }
  return inside;
}

function polygonsOverlapRough(a: Point[], b: Point[]) {
  const boundsA = boundsFor(a);
  const boundsB = boundsFor(b);
  const separated =
    boundsA.x + boundsA.width < boundsB.x ||
    boundsB.x + boundsB.width < boundsA.x ||
    boundsA.y + boundsA.height < boundsB.y ||
    boundsB.y + boundsB.height < boundsA.y;
  if (separated) return false;
  return a.some((point) => pointInPolygon(point, b)) || b.some((point) => pointInPolygon(point, a));
}

export function pieceFromPolygon(id: string, points: Point[], cells: string[] = []): CellPiece {
  const bounds = boundsFor(points);
  return {
    id,
    points,
    home: polygonCenter(points),
    neighbors: [],
    visible_bounds: [bounds.x, bounds.y, bounds.width, bounds.height],
    cells,
  };
}

export function withNeighbors(pieces: LevelPiece[]): LevelPiece[] {
  return pieces.map((piece) => ({
    ...piece,
    home: polygonCenter(piece.points),
    visible_bounds: rectTuple(boundsFor(piece.points)),
    neighbors: pieces
      .filter((other) => other.id !== piece.id && areAdjacent(piece, other))
      .map((other) => other.id),
  }));
}

export function areAdjacent(a: LevelPiece, b: LevelPiece) {
  const cellsA = new Set(a.cells || []);
  const cellsB = new Set(b.cells || []);
  if (cellsA.size && cellsB.size) {
    for (const cell of cellsA) {
      const [row, col] = cell.split(":").map(Number);
      for (const candidate of [`${row - 1}:${col}`, `${row + 1}:${col}`, `${row}:${col - 1}`, `${row}:${col + 1}`]) {
        if (cellsB.has(candidate)) return true;
      }
    }
  }
  let shared = 0;
  for (const pa of a.points) {
    for (const pb of b.points) {
      if (distance(pa, pb) < 2) shared++;
    }
  }
  if (shared >= 2) return true;
  const tolerance = Math.max(8, Math.min(boundsFor(a.points).width + boundsFor(a.points).height, boundsFor(b.points).width + boundsFor(b.points).height) * 0.035);
  for (const edgeA of polygonEdges(a.points)) {
    for (const edgeB of polygonEdges(b.points)) {
      if (segmentDistance(edgeA[0], edgeA[1], edgeB[0], edgeB[1]) <= tolerance) return true;
    }
  }
  return false;
}

export function mergePieces(a: LevelPiece, b: LevelPiece): LevelPiece {
  const cells = [...new Set([...(a.cells || []), ...(b.cells || [])])];
  const points = convexHull([...a.points, ...b.points]);
  return pieceFromPolygon(`${a.id}_${b.id}`, points, cells);
}

export function polygonCenter(points: Point[]): Point {
  if (!points.length) return [0, 0];
  const sum = points.reduce((acc, point) => [acc[0] + point[0], acc[1] + point[1]], [0, 0]);
  return [sum[0] / points.length, sum[1] / points.length];
}

export function boundsFor(points: Point[]) {
  const xs = points.map((point) => point[0]);
  const ys = points.map((point) => point[1]);
  const x = Math.min(...xs);
  const y = Math.min(...ys);
  const width = Math.max(...xs) - x;
  const height = Math.max(...ys) - y;
  return { x, y, width, height };
}

function rectTuple(rect: { x: number; y: number; width: number; height: number }): [number, number, number, number] {
  return [rect.x, rect.y, rect.width, rect.height];
}

function distance(a: Point, b: Point) {
  return Math.hypot(a[0] - b[0], a[1] - b[1]);
}

function polygonEdges(points: Point[]): Array<[Point, Point]> {
  return points.map((point, index) => [point, points[(index + 1) % points.length]]);
}

function segmentDistance(a1: Point, a2: Point, b1: Point, b2: Point) {
  if (segmentsIntersect(a1, a2, b1, b2)) return 0;
  return Math.min(
    pointSegmentDistance(a1, b1, b2),
    pointSegmentDistance(a2, b1, b2),
    pointSegmentDistance(b1, a1, a2),
    pointSegmentDistance(b2, a1, a2),
  );
}

function pointSegmentDistance(point: Point, start: Point, end: Point) {
  const dx = end[0] - start[0];
  const dy = end[1] - start[1];
  const lengthSq = dx * dx + dy * dy;
  if (lengthSq === 0) return distance(point, start);
  const t = clamp(((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / lengthSq, 0, 1);
  return distance(point, [start[0] + t * dx, start[1] + t * dy]);
}

function segmentsIntersect(a1: Point, a2: Point, b1: Point, b2: Point) {
  const direction = (a: Point, b: Point, c: Point) => (c[0] - a[0]) * (b[1] - a[1]) - (b[0] - a[0]) * (c[1] - a[1]);
  const d1 = direction(a1, a2, b1);
  const d2 = direction(a1, a2, b2);
  const d3 = direction(b1, b2, a1);
  const d4 = direction(b1, b2, a2);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

function convexHull(points: Point[]): Point[] {
  const sorted = [...points].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (sorted.length <= 3) return sorted;
  const cross = (o: Point, a: Point, b: Point) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower: Point[] = [];
  for (const point of sorted) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) lower.pop();
    lower.push(point);
  }
  const upper: Point[] = [];
  for (const point of sorted.reverse()) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) upper.pop();
    upper.push(point);
  }
  upper.pop();
  lower.pop();
  return lower.concat(upper);
}
