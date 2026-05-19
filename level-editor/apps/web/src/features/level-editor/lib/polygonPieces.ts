import { polygonArea, simplifyClosedPath, traceBoundaryLoops } from "../../../geometry";
import type { CutLine, LevelPiece, PieceCell, Point } from "../../../types";

const mergePolygonTolerance = 5;

export function pointFromTuple(point: number[]): Point {
  return { x: point[0] || 0, y: point[1] || 0 };
}

export function tupleFromPoint(point: Point): number[] {
  return [Math.round(point.x * 100) / 100, Math.round(point.y * 100) / 100];
}

export function polygonCenter(points: Point[]): Point {
  if (!points.length) return { x: 0, y: 0 };
  return {
    x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
    y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
  };
}

export function pointBounds(points: Point[]): { x: number; y: number; width: number; height: number } {
  if (!points.length) return { x: 0, y: 0, width: 0, height: 0 };
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

export function tupleBounds(points: Point[]): number[] {
  const bounds = pointBounds(points);
  return [bounds.x, bounds.y, bounds.width, bounds.height].map((value) => Math.round(value * 100) / 100);
}

export function unionTupleBounds(boundsList: Array<number[] | undefined>, fallbackPoints: Point[]): number[] {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const bounds of boundsList) {
    if (!bounds || bounds.length < 4) continue;
    minX = Math.min(minX, bounds[0]);
    minY = Math.min(minY, bounds[1]);
    maxX = Math.max(maxX, bounds[0] + bounds[2]);
    maxY = Math.max(maxY, bounds[1] + bounds[3]);
  }
  if (!Number.isFinite(minX)) return tupleBounds(fallbackPoints);
  return [minX, minY, Math.max(1, maxX - minX), Math.max(1, maxY - minY)].map((value) => Math.round(value * 100) / 100);
}

export function visibleBoundsList(piece?: LevelPiece): number[][] {
  if (!piece) return [];
  if (piece.visible_bounds_list?.length) return piece.visible_bounds_list;
  return piece.visible_bounds ? [piece.visible_bounds] : [];
}

export function translateCut(cut: CutLine, center: Point): CutLine {
  const currentCenter = polygonCenter(cut.points);
  const dx = center.x - currentCenter.x;
  const dy = center.y - currentCenter.y;
  return {
    ...cut,
    points: cut.points.map((point) => ({ x: point.x + dx, y: point.y + dy })),
  };
}

function edgePointKey(point: Point, precision = 2): string {
  return `${Math.round(point.x / precision)},${Math.round(point.y / precision)}`;
}

function edgeKey(a: Point, b: Point, precision = 2): string {
  return `${edgePointKey(a, precision)}>${edgePointKey(b, precision)}`;
}

function undirectedEdgeKey(a: Point, b: Point, precision = 2): string {
  const ak = edgePointKey(a, precision);
  const bk = edgePointKey(b, precision);
  return ak < bk ? `${ak}|${bk}` : `${bk}|${ak}`;
}

function polygonEdges(points: Point[]) {
  return points.map((from, index) => ({ from, to: points[(index + 1) % points.length] }));
}

export function polylinePath(points: Point[], closed = false): string {
  if (!points.length) return "";
  const commands = [`M ${points[0].x.toFixed(2)} ${points[0].y.toFixed(2)}`];
  for (let i = 1; i < points.length; i += 1) {
    commands.push(`L ${points[i].x.toFixed(2)} ${points[i].y.toFixed(2)}`);
  }
  if (closed) commands.push("Z");
  return commands.join(" ");
}

function pointToSegmentDistance(point: Point, a: Point, b: Point): number {
  const vx = b.x - a.x;
  const vy = b.y - a.y;
  const wx = point.x - a.x;
  const wy = point.y - a.y;
  const len2 = vx * vx + vy * vy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, (wx * vx + wy * vy) / len2));
  return Math.hypot(point.x - (a.x + vx * t), point.y - (a.y + vy * t));
}

function nearestBoundaryDistance(point: Point, points: Point[]): number {
  return polygonEdges(points).reduce((best, edge) => Math.min(best, pointToSegmentDistance(point, edge.from, edge.to)), Infinity);
}

function sampleSegment(a: Point, b: Point, spacing: number): Point[] {
  const length = Math.hypot(b.x - a.x, b.y - a.y);
  const count = Math.max(2, Math.ceil(length / spacing));
  return Array.from({ length: count + 1 }, (_, index) => ({
    x: a.x + ((b.x - a.x) * index) / count,
    y: a.y + ((b.y - a.y) * index) / count,
  }));
}

function sharedBoundaryLength(a: Point[], b: Point[], tolerance = 4): number {
  let length = 0;
  for (const edge of polygonEdges(a)) {
    const edgeLength = Math.hypot(edge.to.x - edge.from.x, edge.to.y - edge.from.y);
    if (edgeLength < 1) continue;
    const samples = sampleSegment(edge.from, edge.to, 8);
    let closeSamples = 0;
    for (const point of samples) {
      if (nearestBoundaryDistance(point, b) <= tolerance) closeSamples += 1;
    }
    if (closeSamples >= Math.max(2, samples.length * 0.45)) {
      length += edgeLength * (closeSamples / samples.length);
    }
  }
  return length;
}

function areNeighborPieces(a: Point[], b: Point[]): boolean {
  return Math.max(sharedBoundaryLength(a, b), sharedBoundaryLength(b, a)) >= 16;
}

function edgeSharedWithPolygon(edge: { from: Point; to: Point }, polygon: Point[], tolerance = mergePolygonTolerance): boolean {
  const edgeLength = Math.hypot(edge.to.x - edge.from.x, edge.to.y - edge.from.y);
  if (edgeLength < 1) return false;
  const samples = sampleSegment(edge.from, edge.to, 6);
  let closeSamples = 0;
  for (const point of samples) {
    if (nearestBoundaryDistance(point, polygon) <= tolerance) closeSamples += 1;
  }
  return closeSamples >= Math.max(2, samples.length * 0.45);
}

function mergePolygonsByExactEdges(a: Point[], b: Point[]): Point[] | null {
  const allEdges = [...polygonEdges(a), ...polygonEdges(b)];
  const edgeCounts = new Map<string, number>();
  for (const edge of allEdges) {
    const key = undirectedEdgeKey(edge.from, edge.to);
    edgeCounts.set(key, (edgeCounts.get(key) || 0) + 1);
  }
  const sharedEdges = [...edgeCounts.values()].filter((count) => count > 1).length;
  if (sharedEdges === 0) return null;

  const boundary = allEdges.filter((edge) => edgeCounts.get(undirectedEdgeKey(edge.from, edge.to)) === 1);
  if (boundary.length < 3) return null;
  const unused = new Map(boundary.map((edge) => [edgeKey(edge.from, edge.to), edge]));
  const first = boundary[0];
  const merged: Point[] = [first.from, first.to];
  unused.delete(edgeKey(first.from, first.to));
  let current = first.to;
  let guard = 0;

  while (unused.size && guard < boundary.length + 4) {
    guard += 1;
    const currentKey = edgePointKey(current);
    let foundKey = "";
    let found = null as null | { from: Point; to: Point };
    for (const [key, edge] of unused) {
      if (edgePointKey(edge.from) === currentKey) {
        foundKey = key;
        found = edge;
        break;
      }
      if (edgePointKey(edge.to) === currentKey) {
        foundKey = key;
        found = { from: edge.to, to: edge.from };
        break;
      }
    }
    if (!found) break;
    current = found.to;
    if (edgePointKey(current) === edgePointKey(merged[0])) {
      unused.delete(foundKey);
      break;
    }
    merged.push(current);
    unused.delete(foundKey);
  }

  return merged.length >= 3 ? merged : null;
}

function drawPolygonToMask(ctx: CanvasRenderingContext2D, points: Point[], bounds: { x: number; y: number }, padding: number, scale: number) {
  if (points.length < 3) return;
  ctx.beginPath();
  ctx.moveTo((points[0].x - bounds.x + padding) * scale, (points[0].y - bounds.y + padding) * scale);
  for (let i = 1; i < points.length; i += 1) {
    ctx.lineTo((points[i].x - bounds.x + padding) * scale, (points[i].y - bounds.y + padding) * scale);
  }
  ctx.closePath();
}

function strokeSharedEdgesToMask(ctx: CanvasRenderingContext2D, edges: Array<{ from: Point; to: Point }>, bounds: { x: number; y: number }, padding: number, scale: number) {
  for (const edge of edges) {
    ctx.beginPath();
    ctx.moveTo((edge.from.x - bounds.x + padding) * scale, (edge.from.y - bounds.y + padding) * scale);
    ctx.lineTo((edge.to.x - bounds.x + padding) * scale, (edge.to.y - bounds.y + padding) * scale);
    ctx.stroke();
  }
}

function mergePolygonsByMask(a: Point[], b: Point[]): Point[] | null {
  if (!areNeighborPieces(a, b)) return null;
  const bounds = pointBounds([...a, ...b]);
  const padding = mergePolygonTolerance * 4 + 8;
  const rawWidth = Math.max(1, bounds.width + padding * 2);
  const rawHeight = Math.max(1, bounds.height + padding * 2);
  const scale = Math.min(1, 1400 / Math.max(rawWidth, rawHeight));
  const width = Math.max(4, Math.ceil(rawWidth * scale));
  const height = Math.max(4, Math.ceil(rawHeight * scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return null;

  ctx.fillStyle = "#fff";
  drawPolygonToMask(ctx, a, bounds, padding, scale);
  ctx.fill();
  drawPolygonToMask(ctx, b, bounds, padding, scale);
  ctx.fill();

  const sharedEdges = [
    ...polygonEdges(a).filter((edge) => edgeSharedWithPolygon(edge, b)),
    ...polygonEdges(b).filter((edge) => edgeSharedWithPolygon(edge, a)),
  ];
  ctx.strokeStyle = "#fff";
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.lineWidth = Math.max(2, mergePolygonTolerance * 2.5 * scale);
  strokeSharedEdgesToMask(ctx, sharedEdges, bounds, padding, scale);

  const data = ctx.getImageData(0, 0, width, height).data;
  const mask = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i += 1) mask[i] = data[i * 4 + 3] > 0 ? 1 : 0;
  const loops = traceBoundaryLoops(mask, width, height);
  const largestLoop = loops.sort((left, right) => Math.abs(polygonArea(right)) - Math.abs(polygonArea(left)))[0] || [];
  if (largestLoop.length < 4) return null;
  const raw = largestLoop.map((point) => ({
    x: point.x / scale + bounds.x - padding,
    y: point.y / scale + bounds.y - padding,
  }));
  const simplified = simplifyClosedPath(raw, Math.max(1.2, 2.2 / Math.max(scale, 1e-6)));
  return simplified.length >= 3 ? simplified : null;
}

export function mergePolygons(a: Point[], b: Point[]): Point[] | null {
  return mergePolygonsByExactEdges(a, b) || mergePolygonsByMask(a, b);
}

export function cellsToLevelPieces(cells: PieceCell[]): LevelPiece[] {
  const validCells = cells.filter((piece) => piece.points.length >= 3);
  return validCells.map((piece) => {
    const neighbors = validCells
      .filter((candidate) => candidate.id !== piece.id && areNeighborPieces(piece.points, candidate.points))
      .map((candidate) => candidate.id);
    return {
      id: piece.id,
      cell: [0, 0],
      home: tupleFromPoint(polygonCenter(piece.points)),
      points: piece.points.map(tupleFromPoint),
      neighbors,
      cut_lines: [],
      visible_bounds: tupleBounds(piece.points),
      visible_bounds_list: [tupleBounds(piece.points)],
    };
  });
}
