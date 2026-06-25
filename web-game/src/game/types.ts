import { GameMode, LevelRecord, Point, Rect } from "../data/types";

export interface PieceDefinition {
  id: string;
  points: Point[];
  bounds: Rect;
  textureBounds: Rect;
  neighbors: string[];
  row?: number;
  col?: number;
}

export interface RuntimePiece {
  definition: PieceDefinition;
  sprite: Phaser.GameObjects.Image;
  state: "tray" | "dragging" | "locked";
  trayIndex: number;
}

export interface TraySlot {
  pieceId: string;
  x: number;
  y: number;
  scale: number;
  width: number;
  height: number;
}

export interface PuzzleSceneOptions {
  level: LevelRecord;
  mode: GameMode;
  onComplete: () => void;
}

export interface PieceTextureResult {
  key: string;
  width: number;
  height: number;
  textureBounds: Rect;
}
