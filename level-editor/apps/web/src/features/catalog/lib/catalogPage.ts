import { arrayMove } from "@dnd-kit/sortable";
import { makeEmptyLevel } from "../../../geometry";
import type { CatalogLevel, CatalogTopic, LevelConfig, LevelImageConfig, PendingImageItem } from "../../../types";
import { defaultLocale } from "../../../shared/lib/i18n";
import { normalizeOrder, retargetCatalogLevel, retargetGodotPath } from "../../../shared/lib/catalog";
import { levelKey } from "../../../shared/lib/ids";

export function makeLevel(topicId: string, levelId: string, title: string, description = ""): LevelConfig {
  const blank = makeEmptyLevel();
  return {
    ...blank,
    id: levelId,
    topic_id: topicId,
    title,
    description,
    title_i18n: { [defaultLocale]: title },
    description_i18n: { [defaultLocale]: description },
    image: { ...blank.image, path: `res://levels/${topicId}/${levelId}/source.png` },
    assets: { default_image: { ...blank.image, path: `res://levels/${topicId}/${levelId}/source.png` } },
  };
}

export function moveLevelInCatalog(topics: CatalogTopic[], activeTopicId: string, activeLevelId: string, overTopicId: string, overLevelId: string) {
  const sourceTopic = topics.find((topic) => topic.id === activeTopicId);
  const targetTopic = topics.find((topic) => topic.id === overTopicId);
  const moving = sourceTopic?.levels.find((level) => level.id === activeLevelId);
  if (!sourceTopic || !targetTopic || !moving) return topics;
  if (activeTopicId === overTopicId) {
    const oldIndex = sourceTopic.levels.findIndex((level) => level.id === activeLevelId);
    const newIndex = sourceTopic.levels.findIndex((level) => level.id === overLevelId);
    if (oldIndex < 0 || newIndex < 0) return topics;
    return topics.map((topic) => (topic.id === activeTopicId ? { ...topic, levels: normalizeOrder(arrayMove(topic.levels, oldIndex, newIndex)) } : topic));
  }
  const nextMoving = retargetCatalogLevel(moving, activeTopicId, overTopicId);
  return topics.map((topic) => {
    if (topic.id === activeTopicId) return { ...topic, levels: normalizeOrder(topic.levels.filter((level) => level.id !== activeLevelId)) };
    if (topic.id !== overTopicId) return topic;
    const insertIndex = overLevelId ? topic.levels.findIndex((level) => level.id === overLevelId) : -1;
    const levels = [...topic.levels];
    levels.splice(insertIndex >= 0 ? insertIndex : levels.length, 0, nextMoving);
    return { ...topic, levels: normalizeOrder(levels) };
  });
}

export function moveLevelDraft(drafts: Record<string, LevelConfig>, activeTopicId: string, activeLevelId: string, overTopicId: string) {
  const oldKey = levelKey(activeTopicId, activeLevelId);
  const draft = drafts[oldKey];
  if (!draft) return drafts;
  const nextKey = levelKey(overTopicId, activeLevelId);
  const nextDraft: LevelConfig = {
    ...draft,
    topic_id: overTopicId,
    image: { ...draft.image, path: retargetGodotPath(draft.image.path, activeTopicId, activeLevelId, overTopicId) },
    assets: draft.assets?.default_image
      ? {
          ...draft.assets,
          default_image: {
            ...draft.assets.default_image,
            path: retargetGodotPath(draft.assets.default_image.path, activeTopicId, activeLevelId, overTopicId),
          },
        }
      : draft.assets,
  };
  const { [oldKey]: _removed, ...rest } = drafts;
  return { ...rest, [nextKey]: nextDraft };
}

export function imagePath(value?: LevelImageConfig) {
  if (!value) return "";
  return typeof value === "string" ? value : value.path || "";
}

export function imageName(value?: LevelImageConfig) {
  if (!value || typeof value === "string") return "";
  return value.name || imagePath(value).split("/").pop() || "";
}

export function imageExtension(path: string) {
  const fileName = path.split(/[\\/]/).pop() || "";
  const index = fileName.lastIndexOf(".");
  return index >= 0 ? fileName.slice(index).toLowerCase() : "";
}

export function sameImageInfoExceptName(a?: LevelImageConfig, b?: LevelImageConfig) {
  if (!a || !b || typeof a === "string" || typeof b === "string") return false;
  const aPath = imagePath(a);
  const bPath = imagePath(b);
  if (!aPath || !bPath || aPath === bPath) return false;
  return Number(a.width || 0) > 0 && a.width === b.width && a.height === b.height && imageExtension(aPath) === imageExtension(bPath);
}

export function levelAssetUrl(topicId: string, levelId: string, path: string) {
  const fileName = path.split("/").pop() || "";
  return fileName ? `/api/levels/${encodeURIComponent(topicId)}/${encodeURIComponent(levelId)}/assets/${encodeURIComponent(fileName)}?mtime=${Date.now()}` : "";
}

export function pendingImageUrl(items: PendingImageItem[], path: string) {
  return items.find((item) => item.path === path)?.url || "";
}

export function levelBackgroundUrl(topicId: string, levelId: string, path: string, items: PendingImageItem[]) {
  if (!path) return "";
  if (path.startsWith(`res://levels/${topicId}/${levelId}/`)) return levelAssetUrl(topicId, levelId, path);
  return pendingImageUrl(items, path);
}

export function modeStatus(draft?: LevelConfig) {
  return {
    polygon: Boolean(draft?.modes?.polygon?.pieces?.length),
    knob: Boolean(draft?.modes?.knob?.pieces?.length),
  };
}

export type CatalogDeleteDialogKind = "selected" | "topic" | "level" | null;
