import fs from "node:fs/promises";
import path from "node:path";
import type { CatalogGroup, CatalogLevel, CatalogRenameOperation, CatalogTopic, LevelCatalog, LevelConfig, LevelStatus } from "./types.js";
import { catalogPath, groupDir, levelDir, levelJsonPath, levelResPath, sourceImagePath, sourceResPath, topicDir } from "./paths.js";

export const defaultPreset = {
  id: "mobile_portrait_3x4",
  name: "Mobile portrait 3:4",
  aspect_ratio: 0.75,
  default: true,
};

export function safeId(input: string, fallback: string) {
  const cleaned = String(input || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/gi, "_")
    .replace(/^_+|_+$/g, "");
  return /^[a-z][a-z0-9_]*$/.test(cleaned) ? cleaned : fallback;
}

function paddedId(prefix: string, index: number) {
  return `${prefix}_${String(index + 1).padStart(2, "0")}`;
}

export function zhI18n(value: string) {
  return { zh: value, "zh-Hans": value, _: value };
}

export function emptyCatalog(): LevelCatalog {
  return {
    version: 3,
    default_locale: "en",
    locales: ["en", "zh", "ja"],
    image_presets: [defaultPreset],
    topics: [],
  };
}

export function normalizeCatalog(input: unknown): LevelCatalog {
  const raw = input && typeof input === "object" ? (input as Partial<LevelCatalog>) : {};
  return {
    ...emptyCatalog(),
    ...raw,
    version: 3,
    default_locale: "en",
    locales: ["en", "zh", "ja"],
    image_presets: Array.isArray(raw.image_presets) && raw.image_presets.length ? raw.image_presets : [defaultPreset],
    topics: Array.isArray(raw.topics)
      ? raw.topics.map(normalizeTopic).sort((a, b) => a.sort_order - b.sort_order)
      : [],
  };
}

function normalizeTopic(topic: CatalogTopic, index: number): CatalogTopic {
  const id = safeId(topic.id, paddedId("topic", index));
  const name = String(topic.name || id);
  return {
    id,
    name,
    name_i18n: topic.name_i18n || zhI18n(name),
    cover: String(topic.cover || ""),
    sort_order: Number(topic.sort_order ?? index),
    groups: Array.isArray(topic.groups)
      ? topic.groups.map((group, groupIndex) => normalizeGroup(group, id, groupIndex)).sort((a, b) => a.sort_order - b.sort_order)
      : [],
  };
}

function normalizeGroup(group: CatalogGroup, topicId: string, index: number): CatalogGroup {
  const id = safeId(group.id, paddedId("group", index));
  const name = String(group.name || id);
  return {
    id,
    name,
    name_i18n: group.name_i18n || zhI18n(name),
    sort_order: Number(group.sort_order ?? index),
    levels: Array.isArray(group.levels)
      ? group.levels.map((level, levelIndex) => normalizeLevel(level, topicId, id, levelIndex)).sort((a, b) => a.sort_order - b.sort_order)
      : [],
  };
}

function normalizeLevel(level: CatalogLevel, topicId: string, groupId: string, index: number): CatalogLevel {
  const id = safeId(level.id, paddedId("level", index));
  const title = String(level.title || id);
  return {
    id,
    title,
    title_i18n: level.title_i18n || zhI18n(title),
    sort_order: Number(level.sort_order ?? index),
    path: String(level.path || levelResPath(topicId, groupId, id)),
    source: String(level.source || sourceResPath(topicId, groupId, id)),
  };
}

export async function readJson<T>(filePath: string, fallback: T): Promise<T> {
  try {
    return JSON.parse(await fs.readFile(filePath, "utf8")) as T;
  } catch {
    return fallback;
  }
}

export async function writeJson(filePath: string, value: unknown) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(value, null, "\t")}\n`);
}

export async function readCatalog() {
  return normalizeCatalog(await readJson(catalogPath, emptyCatalog()));
}

export async function writeCatalog(catalog: LevelCatalog) {
  await writeJson(catalogPath, normalizeCatalog(catalog));
}

async function renameIfNeeded(fromPath: string, toPath: string) {
  if (fromPath === toPath) return;
  if (!(await exists(fromPath))) return;
  if (await exists(toPath)) {
    throw new Error(`无法修改 ID，目标路径已存在：${toPath}`);
  }
  await fs.mkdir(path.dirname(toPath), { recursive: true });
  await fs.rename(fromPath, toPath);
}

export async function applyCatalogRenames(renames: CatalogRenameOperation[]) {
  for (const rename of renames) {
    if (rename.kind === "topic") {
      await renameIfNeeded(topicDir(rename.fromTopicId), topicDir(rename.toTopicId));
    }
  }
  for (const rename of renames) {
    if (rename.kind === "group") {
      await renameIfNeeded(groupDir(rename.topicId, rename.fromGroupId), groupDir(rename.topicId, rename.toGroupId));
    }
  }
  for (const rename of renames) {
    if (rename.kind === "level") {
      await renameIfNeeded(levelDir(rename.topicId, rename.groupId, rename.fromLevelId), levelDir(rename.topicId, rename.groupId, rename.toLevelId));
    }
  }
}

export function defaultLevelConfig(topicId: string, groupId: string, levelId: string, title = levelId, description = ""): LevelConfig {
  return {
    version: 3,
    id: levelId,
    topic_id: topicId,
    group_id: groupId,
    title,
    title_i18n: zhI18n(title),
    description,
    description_i18n: zhI18n(description),
    image: {
      path: sourceResPath(topicId, groupId, levelId),
      width: 0,
      height: 0,
      aspect_ratio: 0.75,
      preset: defaultPreset.id,
    },
    background: { type: "color", color: "#F6EBD4" },
    modes: {
      polygon: { pieces: [], generator: null },
      knob: { auto: true, cols: 6, rows: 8, knob_size: 0.24 },
      swap: { auto: true, cols: 3, rows: 4 },
    },
  };
}

export function normalizeLevelConfig(input: unknown, topicId: string, groupId: string, levelId: string, title = levelId): LevelConfig {
	const base = defaultLevelConfig(topicId, groupId, levelId, title);
	const raw = input && typeof input === "object" ? (input as Partial<LevelConfig>) : {};
	const imageWidth = Number(raw.image?.width || 0);
	const imageHeight = Number(raw.image?.height || 0);
	const imageAspect = Number(raw.image?.aspect_ratio || (imageWidth && imageHeight ? imageWidth / imageHeight : 0.75));
	return {
    ...base,
    ...raw,
    version: 3,
    id: levelId,
    topic_id: topicId,
    group_id: groupId,
    title: String(raw.title || title),
    title_i18n: raw.title_i18n || zhI18n(String(raw.title || title)),
    description: String(raw.description || ""),
    description_i18n: raw.description_i18n || zhI18n(String(raw.description || "")),
		image: {
			...base.image,
			...(raw.image || {}),
			path: sourceResPath(topicId, groupId, levelId),
			width: imageWidth,
			height: imageHeight,
			aspect_ratio: imageAspect,
			preset: raw.image?.preset || defaultPreset.id,
		},
    modes: {
      polygon: {
        pieces: Array.isArray(raw.modes?.polygon?.pieces) ? raw.modes.polygon.pieces : [],
        generator: raw.modes?.polygon?.generator ?? null,
      },
      knob: { auto: true, cols: 6, rows: 8, knob_size: Number(raw.modes?.knob?.knob_size || 0.24) },
      swap: { auto: true, cols: 3, rows: 4 },
    },
  };
}

export async function readLevel(topicId: string, groupId: string, levelId: string, title = levelId) {
  return normalizeLevelConfig(await readJson(levelJsonPath(topicId, groupId, levelId), defaultLevelConfig(topicId, groupId, levelId, title)), topicId, groupId, levelId, title);
}

export async function writeLevel(config: LevelConfig) {
  await writeJson(levelJsonPath(config.topic_id, config.group_id, config.id), normalizeLevelConfig(config, config.topic_id, config.group_id, config.id, config.title));
}

export async function levelStatuses(catalog: LevelCatalog): Promise<LevelStatus[]> {
  const statuses: LevelStatus[] = [];
  for (const topic of catalog.topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        const config = await readLevel(topic.id, group.id, level.id, level.title);
        const hasSource = await exists(sourceImagePath(topic.id, group.id, level.id));
        const pieceCount = config.modes.polygon?.pieces?.length || 0;
        statuses.push({ topicId: topic.id, groupId: group.id, levelId: level.id, hasSource, hasPolygon: pieceCount > 0, pieceCount });
      }
    }
  }
  return statuses;
}

export async function exists(filePath: string) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

export async function ensureLevelDir(topicId: string, groupId: string, levelId: string) {
  await fs.mkdir(levelDir(topicId, groupId, levelId), { recursive: true });
}

export function readJpegSize(buffer: Buffer) {
  if (buffer.length < 4 || buffer[0] !== 0xff || buffer[1] !== 0xd8) {
    throw new Error("只支持 JPG 图片。");
  }
  let offset = 2;
  while (offset < buffer.length) {
    if (buffer[offset] !== 0xff) throw new Error("JPG 文件格式不正确。");
    const marker = buffer[offset + 1];
    const length = buffer.readUInt16BE(offset + 2);
    if (marker >= 0xc0 && marker <= 0xc3) {
      return {
        height: buffer.readUInt16BE(offset + 5),
        width: buffer.readUInt16BE(offset + 7),
      };
    }
    offset += 2 + length;
  }
  throw new Error("无法读取 JPG 尺寸。");
}

export function assertPortrait3x4(width: number, height: number) {
  const ratio = width / height;
  if (Math.abs(ratio - 0.75) > 0.01) {
    throw new Error(`图片比例必须是 3:4，当前是 ${width}x${height}。`);
  }
}
