export type I18nText = Record<string, string>;

export type CatalogLevel = {
  id: string;
  title?: string;
  title_i18n?: I18nText;
  background_color?: string;
  sort_order: number;
  path: string;
  source?: string;
};

export type CatalogGroup = {
  id: string;
  name?: string;
  name_i18n?: I18nText;
  color?: string;
  sort_order: number;
  levels: CatalogLevel[];
};

export type CatalogTopic = {
  id: string;
  name?: string;
  name_i18n?: I18nText;
  cover?: string;
  color?: string;
  ui_palette?: Record<string, string>;
  icon?: string;
  level_background?: string;
  card_back?: string;
  sort_order: number;
  groups: CatalogGroup[];
  levels?: CatalogLevel[];
  flat_levels?: boolean;
};

export type LevelCatalog = {
  version: number;
  default_locale: string;
  locales: string[];
  image_presets: Array<{ id: string; name: string; aspect_ratio: number; default: boolean }>;
  topics: CatalogTopic[];
};

export type Point = [number, number];

export type LevelPiece = {
  id: string;
  points: Point[];
  home: Point;
  neighbors: string[];
  visible_bounds?: [number, number, number, number];
  cells?: string[];
};

export type SeedAssist = {
  outline: boolean;
  seed: {
    mode: "auto" | "manual";
    count: number;
    piece_ids: string[];
  };
};

export type LevelConfig = {
  version: 3;
  id: string;
  topic_id: string;
  group_id: string;
  title: string;
  title_i18n: I18nText;
  description: string;
  description_i18n: I18nText;
  image: {
    path: string;
    width: number;
    height: number;
    aspect_ratio: number;
    preset: string;
  };
  background: { type: "color"; color: string };
  modes: {
    polygon?: { pieces: LevelPiece[]; generator?: unknown; assist: SeedAssist };
    knob?: { auto: true; cols: number; rows: number; knob_size: number; assist: SeedAssist };
    swap?: { auto: true; cols: number; rows: number };
  };
};

export type LevelStatus = {
  topicId: string;
  groupId: string;
  levelId: string;
  hasSource: boolean;
  hasPolygon: boolean;
  pieceCount: number;
};

export type SelectedLevel = {
  topicId: string;
  groupId: string;
  levelId: string;
};

export type CatalogRenameOperation =
  | { kind: "topic"; fromTopicId: string; toTopicId: string }
  | { kind: "group"; topicId: string; fromGroupId: string; toGroupId: string }
  | { kind: "level"; topicId: string; groupId: string; fromLevelId: string; toLevelId: string };
