import type { LevelPiece, Point } from "./types";

export type ShortEdge = {
  key: string;
  start: Point;
  end: Point;
  length: number;
  owners: { pieceId: string; pointIndex: number }[];
  sampling: boolean;
};

const pointKey = (p: Point) => `${Math.round(p[0] * 10000)},${Math.round(p[1] * 10000)}`;
const edgeKey = (a: Point, b: Point) => [pointKey(a), pointKey(b)].sort().join("|");
const valid = (p: Point) => p?.length === 2 && p.every(Number.isFinite);
const distance = (a: Point, b: Point) => Math.hypot(a[0] - b[0], a[1] - b[1]);

function smooth(a: Point, b: Point, c: Point) {
  const ab = distance(a, b), bc = distance(b, c);
  if (ab < 0.0001 || bc < 0.0001) return false;
  const cosine = ((b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1])) / (ab * bc);
  return cosine >= Math.cos(25 * Math.PI / 180);
}

/** Image-coordinate lengths, including the closing edge; shared edges count once.
 * Sampling is a heuristic, never a reason to rewrite geometry. Strict view retains it.
 */
export function findShortEdges(pieces: LevelPiece[], threshold: number): ShortEdge[] {
  if (!Number.isFinite(threshold) || threshold <= 0) return [];
  const rings = pieces.map((piece) => {
    const points = piece.points || [];
    const closed = points.length > 3 && valid(points[0]) && valid(points.at(-1)!) && distance(points[0], points.at(-1)!) < 0.0001;
    return { id: piece.id, points: closed ? points.slice(0, -1) : points };
  });
  const edges = new Map<string, ShortEdge>();
  const vertexOwners = new Map<string, Set<string>>();
  for (const piece of rings) {
    if (piece.points.length < 3 || !piece.points.every(valid)) continue;
    piece.points.forEach((start, index) => {
      const end = piece.points[(index + 1) % piece.points.length];
      const key = edgeKey(start, end);
      const edge = edges.get(key) || { key, start, end, length: distance(start, end), owners: [], sampling: true };
      edge.owners.push({ pieceId: piece.id, pointIndex: index });
      edges.set(key, edge);
      const owners = vertexOwners.get(pointKey(start)) || new Set<string>();
      owners.add(piece.id);
      vertexOwners.set(pointKey(start), owners);
    });
  }
  const ownerKey = (a: Point, b: Point) => [...new Set(edges.get(edgeKey(a, b))?.owners.map((owner) => owner.pieceId))].sort().join("|");
  for (const piece of rings) {
    const points = piece.points;
    if (points.length < 3 || !points.every(valid)) continue;
    points.forEach((start, index) => {
      const prev = points[(index + points.length - 1) % points.length];
      const end = points[(index + 1) % points.length];
      const next = points[(index + 2) % points.length];
      const edge = edges.get(edgeKey(start, end))!;
      edge.sampling &&= edge.length > 0.0001 && smooth(prev, start, end) && smooth(start, end, next)
        && (vertexOwners.get(pointKey(start))?.size || 0) < 3 && (vertexOwners.get(pointKey(end))?.size || 0) < 3
        && ownerKey(prev, start) === ownerKey(start, end) && ownerKey(start, end) === ownerKey(end, next);
    });
  }
  return [...edges.values()].filter((edge) => edge.length < threshold).sort((a, b) => a.length - b.length || a.key.localeCompare(b.key));
}
