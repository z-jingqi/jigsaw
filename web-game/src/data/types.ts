export type LocaleMap = Record<string, string | undefined>;

export type GameMode = "polygon" | "knob" | "swap";

export interface ImagePreset {
  id: string;
  name: string;
  aspect_ratio: number;
  default?: boolean;
}

export interface CatalogLevelRef {
  id: string;
  sort_order?: number;
  path: string;
}

export interface CatalogGroup {
  id: string;
  name?: string;
  name_i18n?: LocaleMap;
  color?: string;
  sort_order?: number;
  levels?: CatalogLevelRef[];
}

export interface CatalogTopic {
  id: string;
  name?: string;
  name_i18n?: LocaleMap;
  cover?: string;
  color?: string;
  icon?: string;
  sort_order?: number;
  groups?: CatalogGroup[];
}

export interface Catalog {
  version: number;
  image_presets?: ImagePreset[];
  topics: CatalogTopic[];
}

export interface SeedConfig {
  mode: "auto" | "manual";
  count: number;
  piece_ids: string[];
}

export interface AssistConfig {
  outline?: boolean;
  seed?: SeedConfig;
}

export interface Point {
  x: number;
  y: number;
}

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface PolygonPieceConfig {
  id: string;
  points: Array<[number, number]>;
  home?: [number, number];
  neighbors?: string[];
  visible_bounds?: [number, number, number, number];
  cells?: string[];
}

export interface PolygonModeConfig {
  pieces?: PolygonPieceConfig[];
  generator?: unknown;
  assist?: AssistConfig;
}

export interface KnobModeConfig {
  auto?: boolean;
  cols?: number;
  rows?: number;
  knob_size?: number;
  assist?: AssistConfig;
}

export interface SwapModeConfig {
  auto?: boolean;
  cols?: number;
  rows?: number;
}

export interface LevelImageConfig {
  path: string;
  width: number;
  height: number;
  aspect_ratio?: number;
  preset?: string;
}

export interface LevelConfig {
  version: number;
  id: string;
  topic_id: string;
  group_id: string;
  title?: string;
  title_i18n?: LocaleMap;
  description?: string;
  description_i18n?: LocaleMap;
  cover?: string;
  image: LevelImageConfig;
  background?: {
    type?: string;
    color?: string;
  };
  modes: {
    polygon?: PolygonModeConfig;
    knob?: KnobModeConfig;
    swap?: SwapModeConfig;
  };
}

export interface TopicRecord {
  id: string;
  title: string;
  coverUrl?: string;
  iconUrl?: string;
  color: string;
  sortOrder: number;
  groups: GroupRecord[];
}

export interface GroupRecord {
  id: string;
  title: string;
  color: string;
  sortOrder: number;
  levels: LevelRecord[];
}

export interface LevelRecord {
  id: string;
  title: string;
  description: string;
  coverUrl?: string;
  imageUrl: string;
  imageWidth: number;
  imageHeight: number;
  backgroundColor: string;
  sortOrder: number;
  topicId: string;
  groupId: string;
  jsonPath: string;
  config: LevelConfig;
  availableModes: GameMode[];
}

export interface RepositorySnapshot {
  topics: TopicRecord[];
  levelsById: Map<string, LevelRecord>;
}
