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

export type CutTemplate =
  | "knob"
  | "round"
  | "circle"
  | "star"
  | "blob"
  | "zigzag"
  | "crescent"
  | "rectangle"
  | "trapezoid"
  | "sector"
  | "heart"
  | "triangle"
  | "diamond"
  | "pentagon"
  | "hexagon"
  | "octagon"
  | "parallelogram"
  | "arrow"
  | "cross"
  | "shield"
  | "leaf"
  | "semicircle";

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
      path?: string;
      name?: string;
      width?: number;
      height?: number;
      aspect_ratio?: number;
      preset?: string;
    };

export type LevelAssets = {
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

export type CatalogGroup = {
  id: string;
  name: string;
  name_i18n?: Record<LocaleCode, string>;
  sort_order: number;
  levels: CatalogLevel[];
};

export type CatalogTopic = {
  id: string;
  name: string;
  name_i18n?: Record<LocaleCode, string>;
  sort_order: number;
  cover: string;
  levels: CatalogLevel[];
  groups: CatalogGroup[];
};

export type LevelCatalog = {
  schema?: "jigsaw.catalog.v3";
  version: number;
  default_locale: LocaleCode;
  locales: LocaleCode[];
  image_presets?: Array<{
    id: string;
    name: string;
    aspect_ratio: number;
    default?: boolean;
  }>;
  topics: CatalogTopic[];
};

export type ImageTarget = "polygon" | "knob" | "swap";

export type ProcessStepType = "convert_jpg" | "remove_background" | "trim_transparent" | "compress";

export type PendingImageKind = "image" | "tablecloth";

export type ImageInfo = {
  format: string;
  width: number;
  height: number;
  bytes: number;
};

export type ProcessStep = {
  id: string;
  type: ProcessStepType;
  tolerance: number;
  padding: number;
  quality: number;
  background: string;
};

export type PendingImageItem = {
  id: string;
  name: string;
  kind: PendingImageKind;
  path: string;
  url: string;
  source_info: ImageInfo;
  processed: boolean;
  processed_path?: string;
  processed_url?: string;
  processed_info?: ImageInfo;
  processed_at?: string;
  applied_step_types?: ProcessStepType[];
  pending_step_types?: ProcessStepType[];
  compression_stable?: boolean;
  folder?: string;
  created_at: string;
};

export type PythonTool = {
  name: string;
  label: string;
  supported: boolean;
  description: string;
  stepType?: ProcessStepType;
};

export type OutlineAnalysis = {
  outline: Point[];
  edgePoints: Point[];
  bounds: Bounds | null;
};

export type LevelConfig = {
  schema?: "jigsaw.level.v3";
  version: number;
  id: string;
  topic_id?: string;
  group_id?: string;
  locale?: LocaleCode;
  title: string;
  description: string;
  title_i18n?: Record<LocaleCode, string>;
  description_i18n?: Record<LocaleCode, string>;
  image: {
    path: string;
    name?: string;
    width: number;
    height: number;
    aspect_ratio?: number;
    preset?: string;
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
      pieces: LevelPiece[];
      generator?: unknown;
    };
    knob: {
      rows: number;
      cols: number;
      piece_size: number;
      knob_size: number;
      pieces: LevelPiece[];
    };
    swap: {
      auto?: boolean;
      max_pieces?: number;
      rows: number;
      cols: number;
    };
  };
  editor: {
    outline: number[][];
    cut_color?: string;
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
