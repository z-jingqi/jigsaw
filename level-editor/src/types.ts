export type Point = {
  x: number;
  y: number;
};

export type Bounds = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export type CutKind = "fracture" | "preset_shape";

export type CutTemplate = "classic" | "round" | "circle" | "star" | "blob" | "zigzag" | "crescent";

export type CutLine = {
  id: string;
  type: CutKind;
  template: CutTemplate;
  points: Point[];
};

export type PieceCell = {
  id: string;
  points: Point[];
};

export type OutlineAnalysis = {
  outline: Point[];
  edgePoints: Point[];
  bounds: Bounds | null;
};

export type LevelConfig = {
  schema: "jigsaw.level.v1";
  version: number;
  id: string;
  title: string;
  description: string;
  image: {
    path: string;
    name: string;
    width: number;
    height: number;
  };
  background: {
    type: "color" | "image";
    color: string;
    path: string;
  };
  component_overrides: Record<string, string>;
  editor: {
    outline: number[][];
    cuts: Array<{
      id: string;
      type: CutKind;
      template: CutTemplate;
      points: number[][];
    }>;
    shapes: Array<{
      id: string;
      type: CutKind;
      template: CutTemplate;
      points: number[][];
    }>;
    pieces: Array<{
      id: string;
      points: number[][];
    }>;
  };
};
