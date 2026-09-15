import { Delaunay } from "d3-delaunay";
import polygonClipping from "polygon-clipping";
import type { MultiPolygon, Pair, Polygon, Ring } from "polygon-clipping";
import type { LevelPiece, Point } from "./types";

type CellPiece = LevelPiece & { cells: string[] };

export type PieceSizeRange = {
  minWidth: number;
  maxWidth: number;
  minHeight: number;
  maxHeight: number;
};

export const PIECE_DIMENSION_RULE = {
  version: 4,
  referenceAxis: "image_width",
  minWidthFactor: 0.1,
  maxWidthFactor: 0.32,
  minHeightFactor: 0.085,
  maxHeightFactor: 0.17,
} as const;
const GENERATION_ATTEMPTS = 12;
const MAX_REPAIR_STEPS_FACTOR = 5;
const VORONOI_VERTICAL_SCALE = 2.6;
const CURVE_STEPS = 5;
const CURVED_EDGE_TARGET_PER_PIECE = 0.58;
const MAX_CURVED_EDGES_PER_PIECE = 2;

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

export function pieceSizeRange(imageWidth: number, _imageHeight: number, _targetCount: number): PieceSizeRange {
  return {
    minWidth: imageWidth * PIECE_DIMENSION_RULE.minWidthFactor,
    maxWidth: imageWidth * PIECE_DIMENSION_RULE.maxWidthFactor,
    minHeight: imageWidth * PIECE_DIMENSION_RULE.minHeightFactor,
    maxHeight: imageWidth * PIECE_DIMENSION_RULE.maxHeightFactor,
  };
}

function random(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0xffffffff;
  };
}

export function generatePieces(imageWidth: number, imageHeight: number, targetCount: number): LevelPiece[] {
  const count = clamp(Math.round(targetCount), 4, 80);
  const seedCount = count;
  const sizeRange = pieceSizeRange(imageWidth, imageHeight, targetCount);
  const baseSeed = Math.round(imageWidth * 13 + imageHeight * 17 + count * 31 + seedCount * 43);
  let best: LevelPiece[] = [];
  let bestEvaluation = { score: Number.POSITIVE_INFINITY, violations: Number.POSITIVE_INFINITY };
  let bestCurved: LevelPiece[] = [];
  let bestCountDrift = Number.POSITIVE_INFINITY;

  for (let attempt = 0; attempt < GENERATION_ATTEMPTS; attempt += 1) {
    const attemptSeed = (baseSeed + Math.imul(attempt + 1, 2654435761)) >>> 0;
    const initial = generateVoronoiPartition(imageWidth, imageHeight, seedCount, attemptSeed);
    const repaired = repairPieceSizes(initial, sizeRange, imageWidth, imageHeight, count);
    const evaluation = evaluatePieces(repaired, sizeRange, count);
    if (evaluation.score < bestEvaluation.score) {
      best = repaired;
      bestEvaluation = evaluation;
    }
    if (evaluation.violations !== 0) continue;

    for (const curveFactor of [1, 0.72, 0.5, 0.32]) {
      const curved = curveSharedEdges(repaired, sizeRange, imageWidth, imageHeight, attemptSeed, curveFactor);
      if (!curved.curvedEdges) continue;
      if (!curved.pieces.every((piece) => isSimplePolygon(piece.points))) continue;
      if (evaluatePieces(curved.pieces, sizeRange, count).violations !== 0) continue;
      const coverage = curved.pieces.reduce((total, piece) => total + polygonAreaAbs(piece.points), 0) / (imageWidth * imageHeight);
      if (Math.abs(coverage - 1) > 0.0005) continue;
      const countDrift = Math.abs(curved.pieces.length - count);
      if (countDrift < bestCountDrift) {
        bestCurved = curved.pieces;
        bestCountDrift = countDrift;
      }
      if (countDrift === 0) return renumberPieces(curved.pieces);
      break;
    }
  }

  if (bestCurved.length) return renumberPieces(bestCurved);

  const details = sizeViolationDetails(best, sizeRange).slice(0, 3).join("；");
  throw new Error(`无法生成全部符合宽高范围的不规则碎片${details ? `：${details}` : ""}。请调整目标块数后重试`);
}

function generateVoronoiPartition(
  imageWidth: number,
  imageHeight: number,
  count: number,
  seed: number,
): LevelPiece[] {
  const rng = random(seed);
  const points = generateRandomPoints(imageWidth, imageHeight, count, rng);
  return voronoiPolygons(points, imageWidth, imageHeight).map((polygon, index) =>
    pieceFromPolygon(`seed_${index + 1}`, polygon),
  );
}

function generateRandomPoints(
  imageWidth: number,
  imageHeight: number,
  count: number,
  rng: () => number,
): Point[] {
  return Array.from({ length: count }, () => [rng() * imageWidth, rng() * imageHeight] as Point);
}

function voronoiPolygons(points: Point[], imageWidth: number, imageHeight: number) {
  const transformed = points.map(([x, y]) => [x, y * VORONOI_VERTICAL_SCALE] as Point);
  const voronoi = Delaunay.from(transformed).voronoi([
    0,
    0,
    imageWidth,
    imageHeight * VORONOI_VERTICAL_SCALE,
  ]);
  return points.map((_, index) =>
    cleanRing(
      (Array.from(voronoi.cellPolygon(index) || []) as Point[]).map(([x, y]) => [
        x,
        y / VORONOI_VERTICAL_SCALE,
      ]),
    ),
  );
}

function repairPieceSizes(source: LevelPiece[], range: PieceSizeRange, imageWidth: number, imageHeight: number, targetCount: number) {
  let pieces = source;
  const seen = new Set<string>();
  const maxSteps = targetCount * MAX_REPAIR_STEPS_FACTOR;
  for (let step = 0; step < maxSteps; step += 1) {
    const fingerprint = geometryFingerprint(pieces);
    if (seen.has(fingerprint)) break;
    seen.add(fingerprint);
    const current = evaluatePieces(pieces, range, targetCount);
    if (current.violations === 0) return pieces;

    const offenders = pieces
      .map((piece, index) => ({ index, issue: pieceSizeIssue(piece, range) }))
      .filter((item) => item.issue.penalty > 0)
      .sort((a, b) => b.issue.penalty - a.issue.penalty)
      .slice(0, 8);
    let bestCandidate: { pieces: LevelPiece[]; evaluation: ReturnType<typeof evaluatePieces> } | null = null;

    for (const offender of offenders) {
      if (offender.issue.oversized) {
        for (const fragments of splitCandidates(pieces[offender.index], imageWidth, imageHeight, step)) {
          const candidate = [...pieces.slice(0, offender.index), ...fragments, ...pieces.slice(offender.index + 1)];
          bestCandidate = betterRepairCandidate(bestCandidate, candidate, range, targetCount);
        }
      }
      if (offender.issue.undersized) {
        for (let neighborIndex = 0; neighborIndex < pieces.length; neighborIndex += 1) {
          if (neighborIndex === offender.index) continue;
          const merged = mergeAdjacentPiecesStrict(pieces[offender.index], pieces[neighborIndex], step);
          if (!merged) continue;
          const next = pieces.filter((_, index) => index !== offender.index && index !== neighborIndex);
          next.push(merged);
          bestCandidate = betterRepairCandidate(bestCandidate, next, range, targetCount);
        }
      }
    }
    if (!bestCandidate || bestCandidate.evaluation.score >= current.score - 0.000001) break;
    pieces = bestCandidate.pieces;
  }
  return pieces;
}

function betterRepairCandidate(
  current: { pieces: LevelPiece[]; evaluation: ReturnType<typeof evaluatePieces> } | null,
  pieces: LevelPiece[],
  range: PieceSizeRange,
  targetCount: number,
) {
  const evaluation = evaluatePieces(pieces, range, targetCount);
  return !current || evaluation.score < current.evaluation.score ? { pieces, evaluation } : current;
}

function evaluatePieces(pieces: LevelPiece[], range: PieceSizeRange, targetCount: number) {
  let penalty = 0;
  let violations = 0;
  for (const piece of pieces) {
    const issue = pieceSizeIssue(piece, range);
    penalty += issue.penalty;
    if (issue.penalty > 0) violations += 1;
  }
  return {
    violations,
    score: penalty * 100 + violations * 4 + Math.abs(pieces.length - targetCount) * 0.18,
  };
}

function pieceSizeIssue(piece: LevelPiece, range: PieceSizeRange) {
  const bounds = boundsFor(piece.points);
  const widthPenalty = dimensionPenalty(bounds.width, range.minWidth, range.maxWidth);
  const heightPenalty = dimensionPenalty(bounds.height, range.minHeight, range.maxHeight);
  return {
    oversized: bounds.width > range.maxWidth || bounds.height > range.maxHeight,
    undersized: bounds.width < range.minWidth || bounds.height < range.minHeight,
    penalty: widthPenalty * widthPenalty + heightPenalty * heightPenalty,
  };
}

function dimensionPenalty(value: number, min: number, max: number) {
  if (value < min) return (min - value) / min;
  if (value > max) return (value - max) / max;
  return 0;
}

function splitCandidates(piece: LevelPiece, imageWidth: number, imageHeight: number, step: number) {
  const bounds = boundsFor(piece.points);
  const axes: Array<"x" | "y"> = bounds.width / imageWidth >= bounds.height / imageHeight ? ["x", "y"] : ["y", "x"];
  const candidates: LevelPiece[][] = [];
  for (const axis of axes) {
    const start = axis === "x" ? bounds.x : bounds.y;
    const length = axis === "x" ? bounds.width : bounds.height;
    for (const ratio of [0.5, 0.44, 0.56, 0.38, 0.62]) {
      const fragments = clipPieceAt(piece, axis, start + length * ratio, imageWidth, imageHeight, step);
      if (fragments.length === 2) candidates.push(fragments);
    }
  }
  return candidates;
}

function clipPieceAt(piece: LevelPiece, axis: "x" | "y", cut: number, imageWidth: number, imageHeight: number, step: number) {
  const padding = Math.max(imageWidth, imageHeight) + 1;
  const rectangles: Point[][] = axis === "x"
    ? [
        [[-padding, -padding], [cut, -padding], [cut, imageHeight + padding], [-padding, imageHeight + padding]],
        [[cut, -padding], [imageWidth + padding, -padding], [imageWidth + padding, imageHeight + padding], [cut, imageHeight + padding]],
      ]
    : [
        [[-padding, -padding], [imageWidth + padding, -padding], [imageWidth + padding, cut], [-padding, cut]],
        [[-padding, cut], [imageWidth + padding, cut], [imageWidth + padding, imageHeight + padding], [-padding, imageHeight + padding]],
      ];
  const fragments: LevelPiece[] = [];
  for (let side = 0; side < rectangles.length; side += 1) {
    let clipped: MultiPolygon;
    try {
      clipped = polygonClipping.intersection([closedRing(piece.points)], [closedRing(rectangles[side])]) as MultiPolygon;
    } catch {
      return [];
    }
    for (const polygon of clipped) {
      const points = cleanRing(polygon[0] as Point[]);
      if (points.length >= 3 && polygonAreaAbs(points) > 4) {
        fragments.push(pieceFromPolygon(`${piece.id}_split_${step}_${side}`, points));
      }
    }
  }
  const area = fragments.reduce((total, fragment) => total + polygonAreaAbs(fragment.points), 0);
  return Math.abs(area - polygonAreaAbs(piece.points)) <= Math.max(2, area * 0.001) ? fragments : [];
}

function mergeAdjacentPiecesStrict(a: LevelPiece, b: LevelPiece, step: number) {
  let union: MultiPolygon;
  try {
    union = polygonClipping.union([closedRing(a.points)], [closedRing(b.points)]) as MultiPolygon;
  } catch {
    return null;
  }
  if (union.length !== 1) return null;
  const points = cleanRing(union[0][0] as Point[]);
  if (points.length < 3) return null;
  const sourceArea = polygonAreaAbs(a.points) + polygonAreaAbs(b.points);
  if (Math.abs(polygonAreaAbs(points) - sourceArea) > Math.max(2, sourceArea * 0.001)) return null;
  return pieceFromPolygon(`${a.id}_${b.id}_merge_${step}`, points);
}

function curveSharedEdges(
  source: LevelPiece[],
  range: PieceSizeRange,
  imageWidth: number,
  imageHeight: number,
  seed: number,
  factor: number,
) {
  const edgeUses = new Map<string, Array<{ pieceIndex: number; edgeIndex: number; forward: boolean }>>();
  const canonicalEdges = new Map<string, [Point, Point]>();
  source.forEach((piece, pieceIndex) => {
    piece.points.forEach((start, edgeIndex) => {
      const end = piece.points[(edgeIndex + 1) % piece.points.length];
      const startKey = pointKey(start);
      const endKey = pointKey(end);
      const forward = startKey < endKey;
      const key = forward ? `${startKey}|${endKey}` : `${endKey}|${startKey}`;
      if (!edgeUses.has(key)) edgeUses.set(key, []);
      edgeUses.get(key)!.push({ pieceIndex, edgeIndex, forward });
      if (!canonicalEdges.has(key)) canonicalEdges.set(key, forward ? [start, end] : [end, start]);
    });
  });

  const replacements = new Map<string, Point[]>();
  const nominalSize = Math.sqrt((imageWidth * imageHeight) / Math.max(1, source.length));
  const candidates: Array<{
    key: string;
    uses: Array<{ pieceIndex: number; edgeIndex: number; forward: boolean }>;
    edge: [Point, Point];
    length: number;
    order: number;
  }> = [];
  for (const [key, uses] of edgeUses) {
    if (uses.length !== 2) continue;
    const edge = canonicalEdges.get(key)!;
    const length = distance(edge[0], edge[1]);
    if (length < nominalSize * 0.16) continue;
    candidates.push({ key, uses, edge, length, order: hashText(`${seed}:${key}`) });
  }
  candidates.sort((a, b) => a.order - b.order);

  const selected = new Set<string>();
  const pieceCurveCounts = Array.from({ length: source.length }, () => 0);
  const targetCurvedEdges = Math.min(
    candidates.length,
    Math.max(1, Math.ceil(source.length * CURVED_EDGE_TARGET_PER_PIECE)),
  );
  const selectCandidate = (candidate: (typeof candidates)[number]) => {
    if (selected.has(candidate.key)) return false;
    if (candidate.uses.some((use) => pieceCurveCounts[use.pieceIndex] >= MAX_CURVED_EDGES_PER_PIECE)) return false;
    selected.add(candidate.key);
    candidate.uses.forEach((use) => {
      pieceCurveCounts[use.pieceIndex] += 1;
    });
    return true;
  };

  for (const candidate of candidates) {
    if (selected.size >= targetCurvedEdges) break;
    if (candidate.uses.every((use) => pieceCurveCounts[use.pieceIndex] === 0)) selectCandidate(candidate);
  }
  for (const candidate of candidates) {
    if (selected.size >= targetCurvedEdges) break;
    if (candidate.uses.some((use) => pieceCurveCounts[use.pieceIndex] === 0)) selectCandidate(candidate);
  }
  for (const candidate of candidates) {
    if (selected.size >= targetCurvedEdges) break;
    selectCandidate(candidate);
  }

  let curvedEdges = 0;
  for (const { key, uses, edge, length } of candidates) {
    if (!selected.has(key)) continue;
    const edgeRng = random((seed ^ hashText(key)) >>> 0);
    const amplitude = Math.min(length * 0.115, nominalSize * 0.105) * factor * (0.72 + edgeRng() * 0.28);
    const phase = edgeRng() * Math.PI * 2;
    const preferredAmplitude = amplitude * (edgeRng() < 0.5 ? -1 : 1);
    let path = curvedEdge(edge[0], edge[1], preferredAmplitude, phase);
    if (!pathWithinImage(path, imageWidth, imageHeight)) path = curvedEdge(edge[0], edge[1], -preferredAmplitude, phase);
    if (!pathWithinImage(path, imageWidth, imageHeight)) continue;
    for (const use of uses) replacements.set(`${use.pieceIndex}:${use.edgeIndex}`, use.forward ? path : [...path].reverse());
    curvedEdges += 1;
  }

  const pieces = source.map((piece, pieceIndex) => {
    const points: Point[] = [];
    piece.points.forEach((start, edgeIndex) => {
      const replacement = replacements.get(`${pieceIndex}:${edgeIndex}`) || [start, piece.points[(edgeIndex + 1) % piece.points.length]];
      points.push(...(points.length ? replacement.slice(1) : replacement));
    });
    return pieceFromPolygon(piece.id, cleanRing(points), piece.cells || []);
  });
  const validBounds = evaluatePieces(pieces, range, source.length).violations === 0;
  return { pieces: validBounds ? pieces : source, curvedEdges: validBounds ? curvedEdges : 0 };
}

function curvedEdge(start: Point, end: Point, amplitude: number, phase: number) {
  const dx = end[0] - start[0];
  const dy = end[1] - start[1];
  const length = Math.max(0.001, Math.hypot(dx, dy));
  const normal: Point = [-dy / length, dx / length];
  return Array.from({ length: CURVE_STEPS + 1 }, (_, index) => {
    const t = index / CURVE_STEPS;
    const envelope = Math.sin(Math.PI * t);
    const irregularity = 0.82 + Math.sin(Math.PI * 2 * t + phase) * 0.18;
    const offset = amplitude * envelope * irregularity;
    return [start[0] + dx * t + normal[0] * offset, start[1] + dy * t + normal[1] * offset] as Point;
  });
}

function pathWithinImage(points: Point[], imageWidth: number, imageHeight: number) {
  return points.every((point) => point[0] >= -0.001 && point[0] <= imageWidth + 0.001 && point[1] >= -0.001 && point[1] <= imageHeight + 0.001);
}

function pointKey(point: Point) {
  return `${point[0].toFixed(4)},${point[1].toFixed(4)}`;
}

function hashText(value: string) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash >>> 0;
}

function geometryFingerprint(pieces: LevelPiece[]) {
  return pieces
    .map((piece) => {
      const bounds = boundsFor(piece.points);
      return `${bounds.x.toFixed(1)},${bounds.y.toFixed(1)},${bounds.width.toFixed(1)},${bounds.height.toFixed(1)},${polygonAreaAbs(piece.points).toFixed(1)}`;
    })
    .sort()
    .join("|");
}

function sizeViolationDetails(pieces: LevelPiece[], range: PieceSizeRange) {
  return pieces.flatMap((piece) => {
    const bounds = boundsFor(piece.points);
    const details: string[] = [];
    if (bounds.width < range.minWidth || bounds.width > range.maxWidth) details.push(`${piece.id} 宽 ${bounds.width.toFixed(1)}`);
    if (bounds.height < range.minHeight || bounds.height > range.maxHeight) details.push(`${piece.id} 高 ${bounds.height.toFixed(1)}`);
    return details;
  });
}

function renumberPieces(pieces: LevelPiece[]) {
  return withNeighbors(pieces.map((piece, index) => pieceFromPolygon(`piece_${index + 1}`, cleanRing(piece.points))));
}

function isSimplePolygon(points: Point[]) {
  if (points.length < 3 || polygonAreaAbs(points) < 4) return false;
  for (let first = 0; first < points.length; first += 1) {
    const firstEnd = (first + 1) % points.length;
    for (let second = first + 1; second < points.length; second += 1) {
      const secondEnd = (second + 1) % points.length;
      if (first === second || firstEnd === second || secondEnd === first) continue;
      if (first === 0 && secondEnd === 0) continue;
      if (segmentsIntersect(points[first], points[firstEnd], points[second], points[secondEnd])) return false;
    }
  }
  return true;
}

export function fillCoverageGaps(sourcePieces: LevelPiece[], imageWidth: number, imageHeight: number): LevelPiece[] {
  if (!sourcePieces.length || imageWidth <= 0 || imageHeight <= 0) return sourcePieces;
  const inputPolygons = sourcePieces
    .map((piece) => cleanRing(piece.points))
    .filter((points) => points.length >= 3 && polygonAreaAbs(points) > 1)
    .map((points) => [closedRing(points)] as Polygon);
  if (!inputPolygons.length) return sourcePieces;
  const [firstPolygon, ...restPolygons] = inputPolygons;
  const imageBounds: Point[] = [[0, 0], [imageWidth, 0], [imageWidth, imageHeight], [0, imageHeight]];
  const imageRect: Polygon = [closedRing(imageBounds)];
  let gaps: MultiPolygon;
  try {
    const union = polygonClipping.union(firstPolygon, ...restPolygons) as MultiPolygon;
    gaps = polygonClipping.difference(imageRect, union) as MultiPolygon;
  } catch {
    return sourcePieces;
  }
  const minGapArea = Math.max(16, (imageWidth * imageHeight) / 50000);
  const existingIds = new Set(sourcePieces.map((piece) => piece.id));
  let gapIndex = 1;
  const gapPieces: LevelPiece[] = [];
  for (const polygon of gaps) {
    const outer = cleanRing(polygon[0] as Point[]);
    if (outer.length < 3 || polygonAreaAbs(outer) < minGapArea) continue;
    while (existingIds.has(`gap_${gapIndex}`)) gapIndex += 1;
    const piece = pieceFromPolygon(`gap_${gapIndex}`, outer, [`gap:${gapIndex}`]);
    existingIds.add(piece.id);
    gapPieces.push(piece);
    gapIndex += 1;
  }
  return gapPieces.length ? [...sourcePieces, ...gapPieces] : sourcePieces;
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
  const points = unionOuterPolygon(a.points, b.points) || convexHull([...a.points, ...b.points]);
  return pieceFromPolygon(`${a.id}_${b.id}`, points, cells);
}

function unionOuterPolygon(a: Point[], b: Point[]) {
  const union = polygonClipping.union([closedRing(a)], [closedRing(b)]) as MultiPolygon;
  let best: Point[] = [];
  let bestArea = 0;
  for (const polygon of union) {
    const outer = cleanRing(polygon[0] as Point[]);
    const area = polygonAreaAbs(outer);
    if (outer.length >= 3 && area > bestArea) {
      best = outer;
      bestArea = area;
    }
  }
  return best.length >= 3 ? best : null;
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
