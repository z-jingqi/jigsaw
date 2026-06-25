import { Point, Rect } from "../../data/types";
import { PieceDefinition } from "../types";

export function toPoints(points: Array<[number, number]>): Point[] {
  return points.map(([x, y]) => ({ x, y }));
}

export function boundsOf(points: Point[]): Rect {
  const xs = points.map((point) => point.x);
  const ys = points.map((point) => point.y);
  const minX = Math.min(...xs);
  const minY = Math.min(...ys);
  const maxX = Math.max(...xs);
  const maxY = Math.max(...ys);
  return {
    x: minX,
    y: minY,
    width: Math.max(1, maxX - minX),
    height: Math.max(1, maxY - minY),
  };
}

export function centerOf(rect: Rect): Point {
  return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

export function distance(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export function normalizeNeighbors(pieces: PieceDefinition[]): void {
  const byId = new Map(pieces.map((piece) => [piece.id, piece]));
  for (const piece of pieces) {
    piece.neighbors = [...new Set(piece.neighbors.filter((id) => id !== piece.id && byId.has(id)))];
  }
}

export function fallbackNeighbors(pieces: PieceDefinition[]): void {
  for (let i = 0; i < pieces.length; i += 1) {
    for (let j = i + 1; j < pieces.length; j += 1) {
      const a = pieces[i];
      const b = pieces[j];
      if (areBoundsAdjacent(a.bounds, b.bounds) || closestPointDistance(a.points, b.points) < 10) {
        a.neighbors.push(b.id);
        b.neighbors.push(a.id);
      }
    }
  }
  normalizeNeighbors(pieces);
}

function areBoundsAdjacent(a: Rect, b: Rect): boolean {
  const ax2 = a.x + a.width;
  const ay2 = a.y + a.height;
  const bx2 = b.x + b.width;
  const by2 = b.y + b.height;
  const horizontalTouch = Math.abs(ax2 - b.x) < 12 || Math.abs(bx2 - a.x) < 12;
  const verticalOverlap = Math.min(ay2, by2) - Math.max(a.y, b.y) > 20;
  const verticalTouch = Math.abs(ay2 - b.y) < 12 || Math.abs(by2 - a.y) < 12;
  const horizontalOverlap = Math.min(ax2, bx2) - Math.max(a.x, b.x) > 20;
  return (horizontalTouch && verticalOverlap) || (verticalTouch && horizontalOverlap);
}

function closestPointDistance(a: Point[], b: Point[]): number {
  let best = Number.POSITIVE_INFINITY;
  for (let ai = 0; ai < a.length; ai += Math.max(1, Math.floor(a.length / 18))) {
    for (let bi = 0; bi < b.length; bi += Math.max(1, Math.floor(b.length / 18))) {
      best = Math.min(best, distance(a[ai], b[bi]));
      if (best < 10) return best;
    }
  }
  return best;
}

export function pointInRect(point: Point, rect: Rect): boolean {
  return point.x >= rect.x && point.x <= rect.x + rect.width && point.y >= rect.y && point.y <= rect.y + rect.height;
}
