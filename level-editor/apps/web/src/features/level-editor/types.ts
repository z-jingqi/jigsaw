import type { CutLine, LevelConfig, LevelPiece, PieceCell, Point } from "../../types";

export type EditMode = "polygon" | "knob" | "swap";
export type PolygonViewMode = "result" | "edit" | "inspect";

export type LevelTarget = {
  topicId: string;
  levelId: string;
};

export type EditorSnapshot = {
  level: LevelConfig;
  cuts: CutLine[];
  pieces: PieceCell[];
  knobPieces: LevelPiece[];
  completedModes: Record<EditMode, boolean>;
  cutLineColor: string;
};

export type DragState = {
  cutId: string;
  pointIndex: number | null;
  action: "move" | "scale";
  start: Point;
  original: CutLine;
  center?: Point;
  startDistance?: number;
};

export type SnapConnectionMarker = {
  id: string;
  point: Point;
  kind: string;
};

export type DrawingCutState = {
  id: string;
  points: Point[];
};

export type SaveModeDialogState = {
  open: boolean;
  targetMode: "existing" | "new";
  topicId: string;
  levelId: string;
  newTopic: boolean;
  title: string;
  description: string;
  newTopicName: string;
  newTopicId: string;
  newLevelTitle: string;
  newLevelDescription: string;
  newBackgroundType: "color" | "image";
  newBackgroundColor: string;
  newBackgroundPath: string;
};
