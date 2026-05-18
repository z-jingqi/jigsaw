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

export type CutTemplate = "knob" | "round" | "circle" | "star" | "blob" | "zigzag" | "crescent";

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

export type LevelPiece = {
  id: string;
  cell: number[];
  home: number[];
  points: number[][];
  neighbors: string[];
  cut_lines: number[][][];
  visible_bounds?: number[];
  visible_bounds_list?: number[][];
};

export type LevelImageConfig =
  | string
  | {
      use?: "default";
      path?: string;
      name?: string;
      width?: number;
      height?: number;
    };

export type LevelAssets = {
  default_image: {
    path: string;
    name: string;
    width: number;
    height: number;
  };
  cover?: LevelImageConfig;
};

export type LocaleCode = "zh-Hans" | "en" | string;

export type CatalogLevel = {
  id: string;
  title: string;
  title_i18n?: Record<LocaleCode, string>;
  sort_order: number;
  path: string;
  source: string;
};

export type CatalogTopic = {
  id: string;
  name: string;
  name_i18n?: Record<LocaleCode, string>;
  sort_order: number;
  cover: string;
  levels: CatalogLevel[];
};

export type LevelCatalog = {
  schema: "jigsaw.catalog.v1";
  version: number;
  default_locale: LocaleCode;
  locales: LocaleCode[];
  topics: CatalogTopic[];
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
  topic_id?: string;
  locale?: LocaleCode;
  title: string;
  description: string;
  title_i18n?: Record<LocaleCode, string>;
  description_i18n?: Record<LocaleCode, string>;
  image: {
    path: string;
    name: string;
    width: number;
    height: number;
  };
  assets?: LevelAssets;
  background: {
    type: "color" | "image";
    color: string;
    path: string;
  };
  grid: {
    cols: number;
    rows: number;
    piece_size: number;
  };
  runtime_layout?: {
    coordinate_space: "source_pixels";
    target: "mobile_portrait";
    min_viewport: number[];
    board_margin_ratio: number;
    hud_height_ratio: number;
    side_margin_ratio: number;
    bottom_margin_ratio: number;
  };
  component_overrides: Record<string, string>;
  modes: {
    polygon: {
      source: "precomputed";
      image?: LevelImageConfig;
      source_image?: LevelImageConfig;
      pieces: LevelPiece[];
    };
    knob: {
      source: "precomputed";
      image?: LevelImageConfig;
      source_image?: LevelImageConfig;
      rows: number;
      cols: number;
      piece_size: number;
      knob_size: number;
      pieces: LevelPiece[];
    };
  };
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
