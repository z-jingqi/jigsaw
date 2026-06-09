export type I18nText = Record<string, string>;

export type CatalogLevel = {
  id: string;
  title: string;
  title_i18n?: I18nText;
  sort_order: number;
  path: string;
  source: string;
};

export type CatalogGroup = {
  id: string;
  name: string;
  name_i18n?: I18nText;
  sort_order: number;
  levels: CatalogLevel[];
};

export type CatalogTopic = {
  id: string;
  name: string;
  name_i18n?: I18nText;
  cover: string;
  sort_order: number;
  groups: CatalogGroup[];
};

export type LevelCatalog = {
  version: 3;
  default_locale: "en";
  locales: string[];
  image_presets: Array<{
    id: string;
    name: string;
    aspect_ratio: number;
    default: boolean;
  }>;
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
  background: {
    type: "color";
    color: string;
  };
  modes: {
    polygon?: {
      pieces: LevelPiece[];
      generator?: unknown;
    };
    knob?: {
      auto: true;
      cols: number;
      rows: number;
      knob_size: number;
    };
    swap?: {
      auto: true;
      cols: number;
      rows: number;
    };
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

export type CatalogRenameOperation =
  | { kind: "topic"; fromTopicId: string; toTopicId: string }
  | { kind: "group"; topicId: string; fromGroupId: string; toGroupId: string }
  | { kind: "level"; topicId: string; groupId: string; fromLevelId: string; toLevelId: string };
