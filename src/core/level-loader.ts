import { Assets, Texture } from 'pixi.js';
import type { LevelData, PieceData, PiecesData, Vec2 } from './types';
import { scale as scaleVec } from './geometry';
import { extractSilhouette } from './silhouette';
import { sliceLevel } from './slicer';

export interface LoadedLevel {
  level: LevelData;
  pieces: PieceData[];
  texture: Texture;
  bounds: { width: number; height: number };
  displayScale: number;
}

export async function loadLevel(basePath: string, overrides?: Partial<LevelData>): Promise<LoadedLevel> {
  const levelRes = await fetch(`${basePath}/level.json`);
  if (!levelRes.ok) throw new Error(`Failed to load level.json from ${basePath}`);
  let level = (await levelRes.json()) as LevelData;
  if (overrides) level = mergeLevel(level, overrides);

  const sourceUrl = `${basePath}/${level.source}`;
  const texture = (await Assets.load(sourceUrl)) as Texture;
  const displayScale = level.displayScale ?? 1;

  let rawPieces: PieceData[];
  let bounds: { width: number; height: number };

  if (level.slice) {
    const silhouette = await extractSilhouette(sourceUrl);
    rawPieces = sliceLevel(silhouette, level.slice);
    bounds = { width: silhouette.imageWidth, height: silhouette.imageHeight };
  } else {
    const piecesRes = await fetch(`${basePath}/pieces.json`);
    if (!piecesRes.ok) throw new Error(`Failed to load pieces.json from ${basePath}`);
    const piecesData = (await piecesRes.json()) as PiecesData;
    rawPieces = piecesData.pieces;
    bounds = piecesData.bounds;
  }

  const pieces: PieceData[] = rawPieces.map((p) => ({
    ...p,
    polygon: p.polygon.map((v) => scaleVec(v as Vec2, displayScale)),
    centroid: scaleVec(p.centroid as Vec2, displayScale),
    homePosition: scaleVec(p.homePosition as Vec2, displayScale),
  }));

  return {
    level,
    pieces,
    texture,
    bounds: {
      width: bounds.width * displayScale,
      height: bounds.height * displayScale,
    },
    displayScale,
  };
}

function mergeLevel(base: LevelData, over: Partial<LevelData>): LevelData {
  return {
    ...base,
    ...over,
    difficulty: { ...base.difficulty, ...(over.difficulty ?? {}) },
    snap: { ...base.snap, ...(over.snap ?? {}) },
    tablecloth: { ...base.tablecloth, ...(over.tablecloth ?? {}) },
    slice: over.slice !== undefined ? { ...(base.slice ?? { mode: 'grid', cols: 3, rows: 3 }), ...over.slice } : base.slice,
  };
}
