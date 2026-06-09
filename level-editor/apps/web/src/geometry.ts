import type { LevelPiece, Point } from "./types";

type CellPiece = LevelPiece & { cells: string[] };

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

export function generatePieces(imageWidth: number, imageHeight: number, targetCount: number): LevelPiece[] {
  const { cols, rows } = chooseGrid(targetCount, imageWidth, imageHeight);
  const cellW = imageWidth / cols;
  const cellH = imageHeight / rows;
  const jitter = Math.min(cellW, cellH) * 0.16;
  const points: Point[][] = [];
  for (let row = 0; row <= rows; row++) {
    points[row] = [];
    for (let col = 0; col <= cols; col++) {
      const x = col * cellW;
      const y = row * cellH;
      const edge = row === 0 || col === 0 || row === rows || col === cols;
      const seed = Math.sin((row + 1) * 19.13 + (col + 1) * 41.71);
      const seed2 = Math.cos((row + 1) * 27.37 + (col + 1) * 13.11);
      points[row][col] = [
        edge ? x : clamp(x + seed * jitter, 0, imageWidth),
        edge ? y : clamp(y + seed2 * jitter, 0, imageHeight),
      ];
    }
  }
  const pieces: CellPiece[] = [];
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const id = `piece_${row}_${col}`;
      const polygon = [points[row][col], points[row][col + 1], points[row + 1][col + 1], points[row + 1][col]];
      pieces.push(pieceFromPolygon(id, polygon, [`${row}:${col}`]));
    }
  }
  return withNeighbors(pieces);
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
  return shared >= 2;
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
