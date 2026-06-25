import {
  Catalog,
  CatalogGroup,
  CatalogTopic,
  GameMode,
  LevelConfig,
  LevelRecord,
  RepositorySnapshot,
} from "./types";
import { normalizeColor, resPathToUrl } from "./paths";

const CATALOG_URL = "/levels/catalog.json";
const DEFAULT_TOPIC_COLOR = "#D9933F";
const DEFAULT_GROUP_COLOR = "#F6EBD4";
const DEFAULT_BACKGROUND = "#F6EBD4";

export function localized(
  direct: string | undefined,
  i18n: Record<string, string | undefined> | undefined,
  fallback: string,
): string {
  return direct || i18n?.["zh-Hans"] || i18n?.zh || i18n?._ || fallback;
}

function bySortOrder<T extends { sortOrder: number; id: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id));
}

function modeAvailable(level: LevelConfig, mode: GameMode): boolean {
  if (!level.image?.path) return false;
  if (mode === "polygon") {
    return Boolean(level.modes.polygon?.pieces?.length);
  }
  if (mode === "knob") {
    return Boolean(level.modes.knob);
  }
  return Boolean(level.modes.swap);
}

function availableModes(level: LevelConfig): GameMode[] {
  return (["polygon", "knob", "swap"] as GameMode[]).filter((mode) => modeAvailable(level, mode));
}

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Failed to load ${url}: ${response.status}`);
  }
  return (await response.json()) as T;
}

async function buildLevelRecord(
  topic: CatalogTopic,
  group: CatalogGroup,
  ref: { id: string; path: string; sort_order?: number },
): Promise<LevelRecord | null> {
  const url = resPathToUrl(ref.path);
  if (!url) return null;

  const config = await fetchJson<LevelConfig>(url);
  if (!config.image?.path) return null;

  const imageUrl = resPathToUrl(config.image.path);
  if (!imageUrl) return null;

  const coverUrl = resPathToUrl(config.cover) ?? resPathToUrl(`${ref.path.replace(/level\.json$/, "cover.jpg")}`);
  const modes = availableModes(config);

  return {
    id: config.id || ref.id,
    title: localized(config.title, config.title_i18n, ref.id),
    description: localized(config.description, config.description_i18n, ""),
    coverUrl,
    imageUrl,
    imageWidth: config.image.width,
    imageHeight: config.image.height,
    backgroundColor: normalizeColor(config.background?.color, DEFAULT_BACKGROUND),
    sortOrder: ref.sort_order ?? 0,
    topicId: topic.id,
    groupId: group.id,
    jsonPath: url,
    config,
    availableModes: modes,
  };
}

export async function loadRepository(): Promise<RepositorySnapshot> {
  const catalog = await fetchJson<Catalog>(CATALOG_URL);
  const levelsById = new Map<string, LevelRecord>();

  const topics = await Promise.all(
    (catalog.topics ?? []).map(async (topic) => {
      const groups = await Promise.all(
        (topic.groups ?? []).map(async (group) => {
          const levelRecords = await Promise.all(
            (group.levels ?? []).map((ref) => buildLevelRecord(topic, group, ref)),
          );
          const levels = bySortOrder(
            levelRecords.filter((level): level is LevelRecord => Boolean(level)),
          );
          levels.forEach((level) => levelsById.set(level.id, level));

          return {
            id: group.id,
            title: localized(group.name, group.name_i18n, group.id),
            color: normalizeColor(group.color, DEFAULT_GROUP_COLOR),
            sortOrder: group.sort_order ?? 0,
            levels,
          };
        }),
      );

      return {
        id: topic.id,
        title: localized(topic.name, topic.name_i18n, topic.id),
        coverUrl: resPathToUrl(topic.cover),
        iconUrl: resPathToUrl(topic.icon),
        color: normalizeColor(topic.color, DEFAULT_TOPIC_COLOR),
        sortOrder: topic.sort_order ?? 0,
        groups: bySortOrder(groups),
      };
    }),
  );

  return {
    topics: bySortOrder(topics),
    levelsById,
  };
}

export function countTopicModes(topic: { groups: Array<{ levels: LevelRecord[] }> }): number {
  return topic.groups.reduce((sum, group) => {
    return sum + group.levels.reduce((levelSum, level) => levelSum + level.availableModes.length, 0);
  }, 0);
}
