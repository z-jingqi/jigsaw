import type { LevelConfig } from "./types.js";

/** Replace artwork without leaving old previews or coordinates in the runtime data. */
export function replaceSource(level: LevelConfig, resourcePath: string, width: number, height: number): LevelConfig {
  const scaleX = level.image.width > 0 ? width / level.image.width : 1;
  const scaleY = level.image.height > 0 ? height / level.image.height : 1;
  const next = structuredClone(level);
  delete next.thumbnail;
  next.image = { ...next.image, path: resourcePath, width, height, aspect_ratio: width / height };
  if (next.modes.polygon) {
    for (const piece of next.modes.polygon.pieces) {
      piece.points = piece.points.map(([x, y]) => [x * scaleX, y * scaleY]);
      piece.home = [piece.home[0] * scaleX, piece.home[1] * scaleY];
      if (piece.visible_bounds) {
        const [x, y, w, h] = piece.visible_bounds;
        piece.visible_bounds = [x * scaleX, y * scaleY, w * scaleX, h * scaleY];
      }
    }
  }
  return next;
}
