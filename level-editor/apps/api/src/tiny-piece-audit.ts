import type { LevelConfig, LevelPiece, TinyPieceFinding } from "./types.js";

export const DEFAULT_TINY_PIECE_THRESHOLD_PERCENT = 0.1;

function polygonArea(points: LevelPiece["points"]) {
  if (points.length < 3) return 0;
  let doubledArea = 0;
  for (let index = 0; index < points.length; index += 1) {
    const current = points[index];
    const next = points[(index + 1) % points.length];
    doubledArea += current[0] * next[1] - next[0] * current[1];
  }
  return Math.abs(doubledArea / 2);
}

function visibleMinDimension(piece: LevelPiece) {
  const bounds = piece.visible_bounds;
  if (!bounds || bounds.length < 4) return null;
  return Math.min(Math.abs(Number(bounds[2])), Math.abs(Number(bounds[3])));
}

export function findTinyPieces(level: LevelConfig, thresholdPercent = DEFAULT_TINY_PIECE_THRESHOLD_PERCENT): TinyPieceFinding[] {
  const imageArea = Number(level.image.width) * Number(level.image.height);
  if (!Number.isFinite(imageArea) || imageArea <= 0) return [];

  const thresholdRatio = thresholdPercent / 100;
  const findings: TinyPieceFinding[] = [];
  for (const piece of level.modes.polygon?.pieces || []) {
    const area = polygonArea(piece.points);
    const areaRatio = area / imageArea;
    if (areaRatio >= thresholdRatio) continue;
    findings.push({
      pieceId: piece.id,
      area,
      areaPercent: areaRatio * 100,
      minDimension: visibleMinDimension(piece),
    });
  }
  return findings.sort((left, right) => left.areaPercent - right.areaPercent);
}
