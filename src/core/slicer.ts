import polygonClipping from 'polygon-clipping';
import type { Pair, Polygon, Ring } from 'polygon-clipping';
import type { NeighborRef, PieceData, ShapeStyle, SliceBoundsMode, Vec2 } from './types';
import type { Silhouette } from './silhouette';
import { KNOB_RADIUS_RATIO, knobPolyline, randomSide } from './knob';
import { pickCurvedCut, pickMixedCut, straightCut } from './cuts';
import { pointSegSqDist } from './geometry';

export interface GridSliceConfig {
  mode: 'grid';
  cols: number;
  rows: number;
  /** Legacy flag retained for old level data. */
  knobs?: boolean;
  shapeStyle?: ShapeStyle;
  bounds?: SliceBoundsMode;
  seed?: string;
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
  const { imageWidth, imageHeight } = silhouette;
  const useRectBounds = cfg.bounds === 'rect' || cfg.bounds === 'image';
  const bounds = cfg.bounds === 'image'
    ? { x: 0, y: 0, width: imageWidth, height: imageHeight }
    : silhouette.bounds;
  const outline = useRectBounds
    ? rectOutline(bounds.x, bounds.y, bounds.width, bounds.height)
    : silhouette.outline;
  const { cols, rows } = cfg;
  const shapeStyle = resolveShapeStyle(cfg);
  const debug = (import.meta as { env?: { DEV?: boolean } }).env?.DEV;
  const skipped: string[] = [];
  const rng = createSeededRng([
    cfg.seed ?? '',
    `${imageWidth}x${imageHeight}`,
    `${bounds.x},${bounds.y},${bounds.width},${bounds.height}`,
    `${cols}x${rows}`,
    shapeStyle,
  ].join('|'));

  const xs: number[] = [];
  const ys: number[] = [];
  for (let i = 0; i <= cols; i++) xs.push(bounds.x + (bounds.width * i) / cols);
  for (let j = 0; j <= rows; j++) ys.push(bounds.y + (bounds.height * j) / rows);
  const knobRadiusPx = Math.min(bounds.width / cols, bounds.height / rows) * KNOB_RADIUS_RATIO;

  // Build the polyline for one internal cut segment. Boundary segments
  // (top/bottom-most row, left/right-most column) are always straight because
  // they sit on the silhouette bbox and never produce visible cut edges.
  const internalCut = (a: Vec2, b: Vec2): Vec2[] => buildCut(a, b, shapeStyle, rng, knobRadiusPx);

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
      hCuts[r].push(isBoundary ? straightCut(a, b) : internalCut(a, b));
    }
  }
  for (let c = 0; c <= cols; c++) {
    vCuts.push([]);
    for (let r = 0; r < rows; r++) {
      const a: Vec2 = [xs[c], ys[r]];
      const b: Vec2 = [xs[c], ys[r + 1]];
      const isBoundary = c === 0 || c === cols;
      vCuts[c].push(isBoundary ? straightCut(a, b) : internalCut(a, b));
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

  if (useRectBounds) {
    const merged = buildMergedRectPieces({
      cols,
      rows,
      hCuts,
      vCuts,
      imageWidth,
      imageHeight,
      visibleOutline: cfg.bounds === 'image' ? outline : silhouette.outline,
    });
    allPieces.push(...merged.pieces);
    for (const [id, keys] of merged.pieceCutKeys) pieceCutKeys.set(id, keys);
    skipped.push(...merged.skipped);
  } else {
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
      `[slicer] grid ${cols}x${rows}, produced ${pieces.length} pieces (${cols * rows} cells)` +
        `, style=${shapeStyle}` +
        (skipped.length ? `; skipped: ${skipped.join(', ')}` : ''),
    );
  }

  return pieces;
}

function buildMergedRectPieces({
  cols,
  rows,
  hCuts,
  vCuts,
  imageWidth,
  imageHeight,
  visibleOutline,
}: {
  cols: number;
  rows: number;
  hCuts: Vec2[][][];
  vCuts: Vec2[][][];
  imageWidth: number;
  imageHeight: number;
  visibleOutline: Vec2[];
}): { pieces: PieceData[]; pieceCutKeys: Map<string, Set<string>>; skipped: string[] } {
  const skipped: string[] = [];
  const visibleSil: Polygon = [closeRing(visibleOutline.map(([x, y]) => [x, y] as Pair))];
  const cells: Array<{ index: number; r: number; c: number; poly: Polygon; visibleArea: number }> = [];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const index = r * cols + c;
      const poly: Polygon = [buildCellRing(r, c, cols, rows, hCuts, vCuts)];
      let visibleArea = 0;
      try {
        visibleArea = multiPolygonArea(polygonClipping.intersection(visibleSil, poly));
      } catch {
        visibleArea = 0;
      }
      cells.push({ index, r, c, poly, visibleArea });
    }
  }

  const visibleCells = cells.filter((cell) => cell.visibleArea > 0.5);
  const avgVisibleArea = visibleCells.reduce((sum, cell) => sum + cell.visibleArea, 0) / Math.max(1, visibleCells.length);
  const tinyVisibleArea = avgVisibleArea * 0.28;
  const parent = cells.map((cell) => cell.index);
  const find = (x: number): number => {
    let p = parent[x];
    while (p !== parent[p]) p = parent[p];
    while (x !== p) {
      const next = parent[x];
      parent[x] = p;
      x = next;
    }
    return p;
  };
  const union = (a: number, b: number): void => {
    const ra = find(a);
    const rb = find(b);
    if (ra !== rb) parent[ra] = rb;
  };
  const at = (r: number, c: number): number | null =>
    r >= 0 && r < rows && c >= 0 && c < cols ? r * cols + c : null;

  for (const cell of cells) {
    if (cell.visibleArea >= tinyVisibleArea) continue;
    const neighbors = [
      at(cell.r - 1, cell.c),
      at(cell.r + 1, cell.c),
      at(cell.r, cell.c - 1),
      at(cell.r, cell.c + 1),
    ].filter((n): n is number => n !== null);
    if (neighbors.length === 0) continue;
    let best = neighbors[0];
    for (const n of neighbors) {
      if (cells[n].visibleArea > cells[best].visibleArea) best = n;
    }
    union(cell.index, best);
    skipped.push(`p_${cell.r}_${cell.c}(merged-visible<${tinyVisibleArea.toFixed(1)}px²)`);
  }

  const byRoot = new Map<number, typeof cells>();
  for (const cell of cells) {
    const root = find(cell.index);
    const group = byRoot.get(root);
    if (group) group.push(cell);
    else byRoot.set(root, [cell]);
  }

  const pieces: PieceData[] = [];
  const pieceCutKeys = new Map<string, Set<string>>();
  let groupIndex = 0;
  for (const groupCells of byRoot.values()) {
    const groupCutsByKey = new Map<string, Vec2[]>();
    for (const cell of groupCells) {
      for (const cut of cellCutsFor(cell.r, cell.c, rows, cols, hCuts, vCuts)) {
        groupCutsByKey.set(cut.key, cut.poly);
      }
    }
    const groupCuts = [...groupCutsByKey.entries()].map(([key, poly]) => ({ key, poly }));
    const groupPolys = groupCells.map((cell) => cell.poly) as [Polygon, ...Polygon[]];
    const unioned = polygonClipping.union(...groupPolys);
    let blobIndex = 0;
    for (const poly of unioned) {
      const ring = poly[0];
      if (Math.abs(signedArea(ring)) < 0.5) continue;
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
        const tag = classifyEdgeWithKey(a, b, groupCuts);
        edgeTypes.push(tag.type);
        if (tag.key) usedKeys.add(tag.key);
      }
      const id = `p_g${groupIndex}_${blobIndex++}`;
      pieces.push({
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
    groupIndex++;
  }

  return { pieces, pieceCutKeys, skipped };
}

function cellCutsFor(
  r: number,
  c: number,
  rows: number,
  cols: number,
  hCuts: Vec2[][][],
  vCuts: Vec2[][][],
): Array<{ poly: Vec2[]; key: string }> {
  const cellCuts: Array<{ poly: Vec2[]; key: string }> = [];
  if (r > 0) cellCuts.push({ poly: hCuts[r][c], key: `h:${r}:${c}` });
  if (r < rows - 1) cellCuts.push({ poly: hCuts[r + 1][c], key: `h:${r + 1}:${c}` });
  if (c > 0) cellCuts.push({ poly: vCuts[c][r], key: `v:${c}:${r}` });
  if (c < cols - 1) cellCuts.push({ poly: vCuts[c + 1][r], key: `v:${c + 1}:${r}` });
  return cellCuts;
}

function multiPolygonArea(polys: Polygon[]): number {
  let total = 0;
  for (const poly of polys) {
    total += Math.abs(signedArea(poly[0]));
  }
  return total;
}

function resolveShapeStyle(cfg: GridSliceConfig): ShapeStyle {
  if (cfg.shapeStyle) return cfg.shapeStyle;
  if (cfg.knobs === true) return 'classic-knob';
  return 'mixed';
}

function buildCut(a: Vec2, b: Vec2, shapeStyle: ShapeStyle, rng: () => number, knobRadiusPx: number): Vec2[] {
  switch (shapeStyle) {
    case 'straight':
      return straightCut(a, b);
    case 'curve':
      return pickCurvedCut(a, b, rng);
    case 'classic-knob':
      return knobPolyline(a, b, randomSide(rng), knobRadiusPx);
    case 'mixed':
      return pickMixedCut(a, b, rng);
  }
}

function createSeededRng(seed: string): () => number {
  let h = 1779033703 ^ seed.length;
  for (let i = 0; i < seed.length; i++) {
    h = Math.imul(h ^ seed.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  return () => {
    h = Math.imul(h ^ (h >>> 16), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    h ^= h >>> 16;
    return (h >>> 0) / 4294967296;
  };
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

function rectOutline(x: number, y: number, width: number, height: number): Vec2[] {
  return [
    [x, y],
    [x + width, y],
    [x + width, y + height],
    [x, y + height],
  ];
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
