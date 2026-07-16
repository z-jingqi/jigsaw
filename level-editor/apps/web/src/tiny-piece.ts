import type { LevelPiece } from "./types";

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

export function findTinyPieceIds(
  pieces: LevelPiece[],
  imageWidth: number,
  imageHeight: number,
  thresholdPercent = DEFAULT_TINY_PIECE_THRESHOLD_PERCENT,
) {
  const imageArea = imageWidth * imageHeight;
  if (!Number.isFinite(imageArea) || imageArea <= 0) return new Set<string>();

  const thresholdArea = imageArea * (thresholdPercent / 100);
  return new Set(pieces.filter((piece) => polygonArea(piece.points) < thresholdArea).map((piece) => piece.id));
}
