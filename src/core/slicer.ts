import polygonClipping from 'polygon-clipping';
import type { Pair, Polygon, Ring } from 'polygon-clipping';
import type { NeighborRef, PieceData, Vec2 } from './types';
import type { Silhouette } from './silhouette';
import { knobPolyline, randomSide } from './knob';
import { pickRandomCut } from './cuts';
import { pointSegSqDist } from './geometry';

export interface GridSliceConfig {
  mode: 'grid';
  cols: number;
  rows: number;
  /** When true (default), internal cuts are knob/socket curves. When false, straight lines. */
  knobs?: boolean;
}

export type SliceConfig = GridSliceConfig;

const CUT_EPS_SQ = 0.4 * 0.4;
/** Pieces whose area is below this fraction of the average piece area get dropped.
 * Catches thin slivers produced when the silhouette barely clips into a cell, which
 * are unpleasant to manipulate at higher difficulties. */
const MIN_PIECE_AREA_RATIO = 0.1;

export function sliceLevel(silhouette: Silhouette, cfg: SliceConfig): PieceData[] {
  if (cfg.mode === 'grid') return sliceGrid(silhouette, cfg);
  throw new Error(`unsupported slice mode: ${(cfg as { mode: string }).mode}`);
}

function sliceGrid(silhouette: Silhouette, cfg: GridSliceConfig): PieceData[] {
  const { bounds, outline, imageWidth, imageHeight } = silhouette;
  const { cols, rows } = cfg;
  const useKnobs = cfg.knobs === true;
  const debug = (import.meta as { env?: { DEV?: boolean } }).env?.DEV;
  const skipped: string[] = [];

  const xs: number[] = [];
  const ys: number[] = [];
  for (let i = 0; i <= cols; i++) xs.push(bounds.x + (bounds.width * i) / cols);
  for (let j = 0; j <= rows; j++) ys.push(bounds.y + (bounds.height * j) / rows);

  // Build the polyline for one internal cut segment. Boundary segments
  // (top/bottom-most row, left/right-most column) are always straight because
  // they sit on the silhouette bbox and never produce visible cut edges.
  const internalCut = (a: Vec2, b: Vec2): Vec2[] =>
    useKnobs ? knobPolyline(a, b, randomSide()) : pickRandomCut(a, b);

  const straightSeg = (a: Vec2, b: Vec2): Vec2[] => [a, b];

  // Pre-generate the polyline for each cut segment.
  // hCuts[r][c]: horizontal cut at y=ys[r] between xs[c] and xs[c+1].
  // vCuts[c][r]: vertical cut at x=xs[c] between ys[r] and ys[r+1].
  const hCuts: Vec2[][][] = [];
  const vCuts: Vec2[][][] = [];
  for (let r = 0; r <= rows; r++) {
    hCuts.push([]);
    for (let c = 0; c < cols; c++) {
      const a: Vec2 = [xs[c], ys[r]];
      const b: Vec2 = [xs[c + 1], ys[r]];
      const isBoundary = r === 0 || r === rows;
      hCuts[r].push(isBoundary ? straightSeg(a, b) : internalCut(a, b));
    }
  }
  for (let c = 0; c <= cols; c++) {
    vCuts.push([]);
    for (let r = 0; r < rows; r++) {
      const a: Vec2 = [xs[c], ys[r]];
      const b: Vec2 = [xs[c], ys[r + 1]];
      const isBoundary = c === 0 || c === cols;
      vCuts[c].push(isBoundary ? straightSeg(a, b) : internalCut(a, b));
    }
  }

  const sil: Polygon = [closeRing(outline.map(([x, y]) => [x, y] as Pair))];

  // Each disjoint silhouette region in a cell becomes its own piece. Pieces in the same
  // cell get unique suffixes (`_0`, `_1`, ...). HomePosition = polygon centroid so that
  // fragments at different image positions snap to distinct relative locations.
  const allPieces: PieceData[] = [];
  // Track which cut polylines each piece touches, so adjacency can be derived from
  // shared polylines instead of cell neighborship.
  const pieceCutKeys = new Map<string, Set<string>>();

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const cellRing = buildCellRing(r, c, cols, rows, hCuts, vCuts);
      const cell: Polygon = [cellRing];

      let result;
      try {
        result = polygonClipping.intersection(sil, cell);
      } catch (err) {
        if (debug) console.warn(`[slicer] cell p_${r}_${c}: clip threw`, err);
        skipped.push(`p_${r}_${c}(clip-error)`);
        continue;
      }
      if (!result.length) {
        skipped.push(`p_${r}_${c}(empty-clip)`);
        continue;
      }

      // Cut polylines this cell can produce edges from, paired with stable keys.
      const cellCuts: Array<{ poly: Vec2[]; key: string }> = [];
      if (r > 0) cellCuts.push({ poly: hCuts[r][c], key: `h:${r}:${c}` });
      if (r < rows - 1) cellCuts.push({ poly: hCuts[r + 1][c], key: `h:${r + 1}:${c}` });
      if (c > 0) cellCuts.push({ poly: vCuts[c][r], key: `v:${c}:${r}` });
      if (c < cols - 1) cellCuts.push({ poly: vCuts[c + 1][r], key: `v:${c + 1}:${r}` });

      let blobIndex = 0;
      for (const poly of result) {
        const ring = poly[0];
        const area = Math.abs(signedArea(ring));
        if (area < 0.5) continue;
        const open = openRing(ring);
        if (open.length < 3) continue;

        const polygon: Vec2[] = open.map(([x, y]) => [x, y]);
        const uv: Vec2[] = polygon.map(([x, y]) => [x / imageWidth, y / imageHeight]);
        const centroid = polygonCentroid(polygon);
        const homePosition: Vec2 = [centroid[0], centroid[1]];

        const edgeTypes: Array<'cut' | 'outline'> = [];
        const usedKeys = new Set<string>();
        for (let i = 0; i < polygon.length; i++) {
          const a = polygon[i] as Pair;
          const b = polygon[(i + 1) % polygon.length] as Pair;
          const tag = classifyEdgeWithKey(a, b, cellCuts);
          edgeTypes.push(tag.type);
          if (tag.key) usedKeys.add(tag.key);
        }

        const id = `p_${r}_${c}_${blobIndex++}`;
        allPieces.push({
          id,
          polygon,
          uv,
          centroid,
          homePosition,
          neighbors: [],
          edgeTypes,
        });
        pieceCutKeys.set(id, usedKeys);
      }

      if (blobIndex === 0) skipped.push(`p_${r}_${c}(no-valid-blobs)`);
    }
  }

  // Drop unmanageably tiny slivers — typically thin pieces produced where the silhouette
  // grazes a cell boundary. Threshold is a fraction of the average piece area, so it
  // scales naturally with grid difficulty.
  let pieces = allPieces;
  if (pieces.length > 1) {
    const pieceAreas = new Map<string, number>();
    let totalArea = 0;
    for (const p of pieces) {
      const a = Math.abs(signedArea(p.polygon));
      pieceAreas.set(p.id, a);
      totalArea += a;
    }
    const avgArea = totalArea / pieces.length;
    const minArea = avgArea * MIN_PIECE_AREA_RATIO;
    const tinyIds = new Set<string>();
    for (const p of pieces) {
      const a = pieceAreas.get(p.id)!;
      if (a < minArea) tinyIds.add(p.id);
    }
    if (tinyIds.size > 0 && tinyIds.size < pieces.length) {
      pieces = pieces.filter((p) => !tinyIds.has(p.id));
      for (const id of tinyIds) {
        pieceCutKeys.delete(id);
        skipped.push(`${id}(tiny<${minArea.toFixed(1)}px²)`);
      }
    }
  }

  // Adjacency: any two pieces that share a cut-polyline key are neighbors.
  // (Pieces from the same cell never share a cut polyline with each other since cell
  // boundaries are shared with OTHER cells, not within.)
  const byKey = new Map<string, string[]>();
  for (const [id, keys] of pieceCutKeys) {
    for (const k of keys) {
      let list = byKey.get(k);
      if (!list) {
        list = [];
        byKey.set(k, list);
      }
      list.push(id);
    }
  }
  const piecesById = new Map<string, PieceData>();
  for (const p of pieces) piecesById.set(p.id, p);
  const seen = new Set<string>();
  for (const ids of byKey.values()) {
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const a = piecesById.get(ids[i])!;
        const b = piecesById.get(ids[j])!;
        const pairKey = a.id < b.id ? `${a.id}|${b.id}` : `${b.id}|${a.id}`;
        if (seen.has(pairKey)) continue;
        seen.add(pairKey);
        const edge: NeighborRef['edge'] = [
          [a.homePosition[0], a.homePosition[1]],
          [b.homePosition[0], b.homePosition[1]],
        ];
        a.neighbors.push({ pieceId: b.id, edge });
        b.neighbors.push({ pieceId: a.id, edge });
      }
    }
  }

  // Solvability fallback: any piece with 0 neighbors (e.g., an isolated silhouette island
  // entirely inside a single cell) gets linked to its nearest piece by centroid distance.
  for (const p of pieces) {
    if (p.neighbors.length > 0) continue;
    let nearest: PieceData | null = null;
    let nearestDist = Infinity;
    for (const q of pieces) {
      if (q === p) continue;
      const dx = q.homePosition[0] - p.homePosition[0];
      const dy = q.homePosition[1] - p.homePosition[1];
      const d = dx * dx + dy * dy;
      if (d < nearestDist) {
        nearestDist = d;
        nearest = q;
      }
    }
    if (nearest) {
      const edge: NeighborRef['edge'] = [
        [p.homePosition[0], p.homePosition[1]],
        [nearest.homePosition[0], nearest.homePosition[1]],
      ];
      p.neighbors.push({ pieceId: nearest.id, edge });
      nearest.neighbors.push({ pieceId: p.id, edge });
    }
  }

  if (debug) {
    console.info(
      `[slicer] grid ${cols}x${rows}, knobs=${useKnobs}, produced ${pieces.length} pieces (${cols * rows} cells)` +
        (skipped.length ? `; skipped: ${skipped.join(', ')}` : ''),
    );
  }

  return pieces;
}

/** Build a closed ring for cell (r, c) by walking top→right→bottom→left, splicing in cut polylines. */
function buildCellRing(
  r: number,
  c: number,
  cols: number,
  rows: number,
  hCuts: Vec2[][][],
  vCuts: Vec2[][][],
): Ring {
  const ring: Pair[] = [];
  // Top: hCuts[r][c] traversed forward, all points.
  const top = hCuts[r][c];
  ring.push([top[0][0], top[0][1]]);
  for (let i = 1; i < top.length; i++) ring.push([top[i][0], top[i][1]]);
  // Right: vCuts[c+1][r] traversed forward, skipping first (it's = top last).
  const right = vCuts[c + 1][r];
  for (let i = 1; i < right.length; i++) ring.push([right[i][0], right[i][1]]);
  // Bottom: hCuts[r+1][c] traversed REVERSED, skipping first (which is hCuts[r+1][c].last = right.last).
  const bottom = hCuts[r + 1][c];
  for (let i = bottom.length - 2; i >= 0; i--) ring.push([bottom[i][0], bottom[i][1]]);
  // Left: vCuts[c][r] traversed REVERSED, skipping first AND last (last is start of top).
  const left = vCuts[c][r];
  for (let i = left.length - 2; i >= 1; i--) ring.push([left[i][0], left[i][1]]);
  // Close ring.
  ring.push([ring[0][0], ring[0][1]]);
  // Suppress unused-arg warning
  void cols;
  void rows;
  return ring;
}

function classifyEdgeWithKey(
  a: Pair,
  b: Pair,
  cellCuts: Array<{ poly: Vec2[]; key: string }>,
): { type: 'cut' | 'outline'; key: string | null } {
  const m: Vec2 = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  for (const { poly, key } of cellCuts) {
    for (let i = 0; i < poly.length - 1; i++) {
      if (pointSegSqDist(m, poly[i], poly[i + 1]) < CUT_EPS_SQ) {
        return { type: 'cut', key };
      }
    }
  }
  return { type: 'outline', key: null };
}

function closeRing(ring: Pair[]): Ring {
  if (ring.length === 0) return ring;
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (first[0] === last[0] && first[1] === last[1]) return ring;
  return [...ring, [first[0], first[1]]];
}

function openRing(ring: Ring): Pair[] {
  if (ring.length < 2) return ring.slice();
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (first[0] === last[0] && first[1] === last[1]) return ring.slice(0, -1);
  return ring.slice();
}

function signedArea(ring: Ring): number {
  let a = 0;
  const n = ring.length;
  for (let i = 0; i < n; i++) {
    const [x1, y1] = ring[i];
    const [x2, y2] = ring[(i + 1) % n];
    a += x1 * y2 - x2 * y1;
  }
  return a / 2;
}

function polygonCentroid(ring: Vec2[]): Vec2 {
  let cx = 0;
  let cy = 0;
  let a = 0;
  const n = ring.length;
  for (let i = 0; i < n; i++) {
    const [x1, y1] = ring[i];
    const [x2, y2] = ring[(i + 1) % n];
    const cross = x1 * y2 - x2 * y1;
    cx += (x1 + x2) * cross;
    cy += (y1 + y2) * cross;
    a += cross;
  }
  if (Math.abs(a) < 1e-6) {
    let sx = 0, sy = 0;
    for (const [x, y] of ring) {
      sx += x;
      sy += y;
    }
    return [sx / n, sy / n];
  }
  a /= 2;
  return [cx / (6 * a), cy / (6 * a)];
}
