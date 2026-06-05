import type { CatalogLevel, CatalogTopic, LevelCatalog } from "../../types";
import { defaultLocale } from "./i18n";

export type LevelTarget = {
  topicId: string;
  groupId?: string;
  levelId: string;
};

export function makeDefaultCatalog(): LevelCatalog {
	return {
		version: 3,
		default_locale: defaultLocale,
		locales: ["en", "zh", "ja"],
		image_presets: [{ id: "mobile_portrait_3x4", name: "Mobile portrait 3:4", aspect_ratio: 0.75, default: true }],
		topics: [],
	};
}

export function normalizeOrder<T extends { sort_order: number }>(items: T[]): T[] {
  return items.map((item, index) => ({ ...item, sort_order: index }));
}

export function updateCatalogLevel(catalog: LevelCatalog, target: LevelTarget, update: (level: CatalogLevel) => CatalogLevel): LevelCatalog {
  return {
    ...catalog,
    topics: catalog.topics.map((topic) =>
      topic.id === target.topicId
        ? {
            ...topic,
            levels: topic.levels.map((level) => (level.id === target.levelId ? update(level) : level)),
          }
        : topic,
    ),
  };
}

export function retargetGodotPath(value: string | undefined, oldTopicId: string, levelId: string, nextTopicId: string) {
  if (!value) return value || "";
  return value.replace(`res://levels/${oldTopicId}/${levelId}/`, `res://levels/${nextTopicId}/${levelId}/`);
}

export function retargetCatalogLevel(level: CatalogLevel, oldTopicId: string, nextTopicId: string): CatalogLevel {
  return {
    ...level,
    path: retargetGodotPath(level.path, oldTopicId, level.id, nextTopicId),
    source: retargetGodotPath(level.source, oldTopicId, level.id, nextTopicId),
  };
}

export function topicCoverUrl(topic: CatalogTopic) {
  if (!topic.cover) return "";
  const fileName = topic.cover.split("/").pop() || "";
  return fileName ? `/api/topics/${encodeURIComponent(topic.id)}/assets/${encodeURIComponent(fileName)}?mtime=${Date.now()}` : `/api/topics/${encodeURIComponent(topic.id)}/cover?mtime=${Date.now()}`;
}
