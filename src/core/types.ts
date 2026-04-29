export type Vec2 = [number, number];

export interface NeighborRef {
  pieceId: string;
  edge: [Vec2, Vec2];
}

export type EdgeType = 'cut' | 'outline';

export interface PieceData {
  id: string;
  polygon: Vec2[];
  uv: Vec2[];
  centroid: Vec2;
  /** Source-coord position used for snap math. For grid cells this is the polygon centroid,
   *  so two disjoint blobs from the same cell get distinct homes. */
  homePosition: Vec2;
  neighbors: NeighborRef[];
  /** Per-edge tag, one entry per polygon edge i→i+1 (modulo n). Optional;
   * when omitted, all edges are treated as 'cut' (drawn as outlines). */
  edgeTypes?: EdgeType[];
}

export interface PiecesData {
  sourceHash: string;
  generatedAt: string;
  bounds: { width: number; height: number };
  pieces: PieceData[];
}

export interface Tablecloth {
  type: 'color' | 'image';
  value: string;
}

export interface SliceConfig {
  mode: 'grid';
  cols: number;
  rows: number;
  knobs?: boolean;
}

export interface DifficultyEntry {
  /** Short label shown on the level card button (e.g. "1", "Easy"). */
  label: string;
  cols: number;
  rows: number;
  knobs?: boolean;
  /** Optional per-difficulty overrides for runtime feel. */
  scatterRadius?: number;
  rotationEnabled?: boolean;
}

export interface LevelData {
  id: string;
  title: string;
  source: string;
  tablecloth: Tablecloth;
  difficulty: {
    pieceCount: number;
    shapeStyle: string;
    rotationEnabled: boolean;
    scatterRadius: number;
  };
  snap: {
    positionTolerance: number;
    angleTolerance: number;
  };
  displayScale?: number;
  /** When present, pieces are generated at runtime from source.png + this config,
   *  bypassing pieces.json. */
  slice?: SliceConfig;
}
