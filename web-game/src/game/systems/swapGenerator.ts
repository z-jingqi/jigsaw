import Phaser from "phaser";
import { Rect } from "../../data/types";

export interface SwapTile {
  id: string;
  correctIndex: number;
  currentIndex: number;
  sprite: Phaser.GameObjects.Image;
}

export function tileRect(index: number, cols: number, rows: number, width: number, height: number): Rect {
  const col = index % cols;
  const row = Math.floor(index / cols);
  const tileW = width / cols;
  const tileH = height / rows;
  return {
    x: col * tileW,
    y: row * tileH,
    width: tileW,
    height: tileH,
  };
}

export function shuffledIndexes(count: number): number[] {
  const indexes = Array.from({ length: count }, (_, index) => index);
  for (let i = indexes.length - 1; i > 0; i -= 1) {
    const j = (i * 7 + 3) % (i + 1);
    [indexes[i], indexes[j]] = [indexes[j], indexes[i]];
  }
  if (indexes.every((value, index) => value === index) && indexes.length > 1) {
    [indexes[0], indexes[1]] = [indexes[1], indexes[0]];
  }
  return indexes;
}
