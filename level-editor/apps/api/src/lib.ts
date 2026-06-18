import fs from "node:fs/promises";
import path from "node:path";
import type { CatalogGroup, CatalogLevel, CatalogRenameOperation, CatalogTopic, LevelCatalog, LevelConfig, LevelStatus, SeedAssist } from "./types.js";
import { catalogPath, groupDir, levelDir, levelJsonPath, levelResPath, sourceImagePath, sourceResPath, topicDir } from "./paths.js";

export const defaultPreset = {
  id: "mobile_landscape_4x3",
  name: "Mobile landscape 4:3",
  aspect_ratio: 4 / 3,
  default: true,
};
const DEFAULT_KNOB_COLS = 8;
const DEFAULT_KNOB_ROWS = 6;
const DEFAULT_KNOB_SIZE = 0.24;
const DEFAULT_SWAP_COLS = 7;
const DEFAULT_SWAP_ROWS = 5;
const DEFAULT_POLYGON_SEED_COUNT = 1;
const DEFAULT_KNOB_SEED_COUNT = 1;
const DEFAULT_TOPIC_COLOR = "#D9933F";
const DEFAULT_GROUP_COLOR = "#F6EBD4";

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

function defaultAssist(count: number): SeedAssist {
  return {
    outline: true,
    seed: {
      mode: "auto",
      count,
      piece_ids: [],
    },
  };
}

function normalizeAssist(input: unknown, defaultCount: number, validIds?: Set<string>): SeedAssist {
  const raw = input && typeof input === "object" ? (input as Partial<SeedAssist>) : {};
  const rawSeed = raw.seed && typeof raw.seed === "object"
    ? (raw.seed as Partial<SeedAssist["seed"]>)
    : {};
  const mode = rawSeed.mode === "manual" ? "manual" : "auto";
  const count = Math.max(0, Math.floor(Number(rawSeed.count ?? defaultCount) || defaultCount));
  const pieceIds = Array.isArray(rawSeed.piece_ids)
    ? rawSeed.piece_ids.map((id: unknown) => String(id)).filter((id) => !validIds || validIds.has(id))
    : [];
  return {
    outline: raw.outline !== false,
    seed: {
      mode,
      count,
      piece_ids: mode === "manual" ? pieceIds : [],
    },
  };
}

function knobSeedIds(cols: number, rows: number) {
  const ids = new Set<string>();
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      ids.add(`knob_${row}_${col}`);
    }
  }
  return ids;
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
  return {
    id,
    name: topic.name,
    name_i18n: topic.name_i18n,
    cover: topic.cover,
    color: topic.color,
    icon: topic.icon,
    sort_order: Number(topic.sort_order ?? index),
    groups: Array.isArray(topic.groups)
      ? topic.groups.map((group, groupIndex) => normalizeGroup(group, id, groupIndex)).sort((a, b) => a.sort_order - b.sort_order)
      : [],
  };
}

function normalizeGroup(group: CatalogGroup, topicId: string, index: number): CatalogGroup {
  const id = safeId(group.id, paddedId("group", index));
  return {
    id,
    name: group.name,
    name_i18n: group.name_i18n,
    color: group.color,
    sort_order: Number(group.sort_order ?? index),
    levels: Array.isArray(group.levels)
      ? group.levels.map((level, levelIndex) => normalizeLevel(level, topicId, id, levelIndex)).sort((a, b) => a.sort_order - b.sort_order)
      : [],
  };
}

function normalizeLevel(level: CatalogLevel, topicId: string, groupId: string, index: number): CatalogLevel {
  const id = safeId(level.id, paddedId("level", index));
  return {
    id,
    title: level.title,
    title_i18n: level.title_i18n,
    cover: level.cover,
    sort_order: Number(level.sort_order ?? index),
    path: String(level.path || levelResPath(topicId, groupId, id)),
    source: level.source,
  };
}

export function extensionFromFile(file: File, allowed: string[]) {
  const mimeExtension = file.type === "image/svg+xml" ? "svg" : file.type.split("/")[1]?.toLowerCase();
  const nameExtension = path.extname(file.name).slice(1).toLowerCase();
  const extension = (mimeExtension || nameExtension).replace("jpeg", "jpg");
  if (allowed.includes(extension)) return extension;
  throw new Error(`文件格式不支持，请使用 ${allowed.join(" / ")}。`);
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
  await writeJson(catalogPath, storedCatalog(catalog));
}

function storedCatalog(catalog: LevelCatalog): LevelCatalog {
  const normalized = normalizeCatalog(catalog);
  return {
    ...normalized,
    topics: normalized.topics.map((topic, topicIndex) => ({
      id: topic.id,
      name: topic.name,
      name_i18n: topic.name_i18n,
      cover: topic.cover,
      color: topic.color,
      icon: topic.icon,
      sort_order: topicIndex,
      groups: topic.groups.map((group, groupIndex) => ({
        id: group.id,
        name: group.name,
        name_i18n: group.name_i18n,
        color: group.color,
        sort_order: groupIndex,
        levels: group.levels.map((level, levelIndex) => ({
          id: level.id,
          sort_order: levelIndex,
          path: level.path || levelResPath(topic.id, group.id, level.id),
        })),
      })),
    })),
  };
}

function catalogLevelRef(topicId: string, groupId: string, levelId: string, sortOrder: number): CatalogLevel {
  return normalizeLevel(
    {
      id: levelId,
      sort_order: sortOrder,
      path: levelResPath(topicId, groupId, levelId),
    },
    topicId,
    groupId,
    sortOrder,
  );
}

export async function hydrateCatalog(catalog: LevelCatalog): Promise<LevelCatalog> {
  const normalized = normalizeCatalog(catalog);
  const topics: CatalogTopic[] = [];
  for (const topic of normalized.topics) {
    const groups: CatalogGroup[] = [];
    for (const group of topic.groups) {
      const levels: CatalogLevel[] = [];
      for (const level of group.levels) {
        const config = await readLevel(topic.id, group.id, level.id, level.title || level.id);
        levels.push({
          ...level,
          title: config.title,
          title_i18n: config.title_i18n,
          cover: config.cover,
          background_color: config.background.color,
          source: config.image.path,
        });
      }
      groups.push({
        ...group,
        name: group.name || group.id,
        name_i18n: group.name_i18n || zhI18n(group.name || group.id),
        color: group.color || DEFAULT_GROUP_COLOR,
        levels,
      });
    }
    topics.push({
      ...topic,
      name: topic.name || topic.id,
      name_i18n: topic.name_i18n || zhI18n(topic.name || topic.id),
      cover: topic.cover || "",
      color: topic.color || DEFAULT_TOPIC_COLOR,
      icon: topic.icon || "",
      groups,
    });
  }
  return { ...normalized, topics };
}

export async function upsertCatalogLevel(config: LevelConfig) {
  const catalog = await readCatalog();
  let topic = catalog.topics.find((item) => item.id === config.topic_id);
  if (!topic) {
    topic = normalizeTopic(
      {
        id: config.topic_id,
        sort_order: catalog.topics.length,
        groups: [],
      },
      catalog.topics.length,
    );
    catalog.topics.push(topic);
  }

  let group = topic.groups.find((item) => item.id === config.group_id);
  if (!group) {
    group = normalizeGroup(
      {
        id: config.group_id,
        sort_order: topic.groups.length,
        levels: [],
      },
      topic.id,
      topic.groups.length,
    );
    topic.groups.push(group);
  }

  const existingIndex = group.levels.findIndex((item) => item.id === config.id);
  const existing = existingIndex >= 0 ? group.levels[existingIndex] : null;
  const nextLevel = catalogLevelRef(topic.id, group.id, config.id, existing?.sort_order ?? group.levels.length);

  if (existingIndex >= 0) group.levels[existingIndex] = nextLevel;
  else group.levels.push(nextLevel);

  await writeCatalog(catalog);
}

type RenamePathPair = { fromPath: string; toPath: string };

async function renameBatch(pairs: RenamePathPair[]) {
  const timestamp = Date.now();
  const planned = pairs.filter((pair) => pair.fromPath !== pair.toPath);
  const existingPairs: Array<RenamePathPair & { tempPath: string }> = [];
  const movingSources = new Set(planned.map((pair) => pair.fromPath));
  const targets = new Set<string>();

  for (const pair of planned) {
    if (targets.has(pair.toPath)) {
      throw new Error(`无法修改 ID，目标路径重复：${pair.toPath}`);
    }
    targets.add(pair.toPath);
    if (!(await exists(pair.fromPath))) continue;
    if ((await exists(pair.toPath)) && !movingSources.has(pair.toPath)) {
      throw new Error(`无法修改 ID，目标路径已存在：${pair.toPath}`);
    }
    existingPairs.push({
      ...pair,
      tempPath: `${pair.fromPath}.__renaming_${timestamp}_${existingPairs.length}`,
    });
  }

  for (const pair of existingPairs) {
    await fs.rename(pair.fromPath, pair.tempPath);
  }
  for (const pair of existingPairs) {
    await fs.mkdir(path.dirname(pair.toPath), { recursive: true });
    await fs.rename(pair.tempPath, pair.toPath);
  }
}

export async function applyCatalogRenames(renames: CatalogRenameOperation[]) {
  await renameBatch(
    renames
      .filter((rename) => rename.kind === "topic")
      .map((rename) => ({
        fromPath: topicDir(rename.fromTopicId),
        toPath: topicDir(rename.toTopicId),
      })),
  );
  await renameBatch(
    renames
      .filter((rename) => rename.kind === "group")
      .map((rename) => ({
        fromPath: groupDir(rename.topicId, rename.fromGroupId),
        toPath: groupDir(rename.topicId, rename.toGroupId),
      })),
  );
  await renameBatch(
    renames
      .filter((rename) => rename.kind === "level")
      .map((rename) => ({
        fromPath: levelDir(rename.topicId, rename.groupId, rename.fromLevelId),
        toPath: levelDir(rename.topicId, rename.groupId, rename.toLevelId),
      })),
  );
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
    cover: "",
    image: {
      path: sourceResPath(topicId, groupId, levelId),
      width: 0,
      height: 0,
      aspect_ratio: 4 / 3,
      preset: defaultPreset.id,
    },
    background: { type: "color", color: "#F6EBD4" },
    modes: {
      polygon: { pieces: [], generator: null, assist: defaultAssist(DEFAULT_POLYGON_SEED_COUNT) },
      knob: { auto: true, cols: DEFAULT_KNOB_COLS, rows: DEFAULT_KNOB_ROWS, knob_size: DEFAULT_KNOB_SIZE, assist: defaultAssist(DEFAULT_KNOB_SEED_COUNT) },
      swap: { auto: true, cols: DEFAULT_SWAP_COLS, rows: DEFAULT_SWAP_ROWS },
    },
  };
}

export function normalizeLevelConfig(input: unknown, topicId: string, groupId: string, levelId: string, title = levelId): LevelConfig {
	const base = defaultLevelConfig(topicId, groupId, levelId, title);
	const raw = input && typeof input === "object" ? (input as Partial<LevelConfig>) : {};
	const imageWidth = Number(raw.image?.width || 0);
	const imageHeight = Number(raw.image?.height || 0);
	const imageAspect = Number(raw.image?.aspect_ratio || (imageWidth && imageHeight ? imageWidth / imageHeight : 4 / 3));
  const polygonPieces = Array.isArray(raw.modes?.polygon?.pieces) ? raw.modes.polygon.pieces : [];
  const polygonSeedIds = new Set(polygonPieces.map((piece) => piece.id));
  const knobCols = Number(raw.modes?.knob?.cols || DEFAULT_KNOB_COLS);
  const knobRows = Number(raw.modes?.knob?.rows || DEFAULT_KNOB_ROWS);
		return {
	    ...base,
	    version: 3,
    id: levelId,
    topic_id: topicId,
    group_id: groupId,
    title: String(raw.title || title),
    title_i18n: raw.title_i18n || zhI18n(String(raw.title || title)),
    description: String(raw.description || ""),
    description_i18n: raw.description_i18n || zhI18n(String(raw.description || "")),
    cover: String(raw.cover || ""),
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
        pieces: polygonPieces,
        generator: raw.modes?.polygon?.generator ?? null,
        assist: normalizeAssist(raw.modes?.polygon?.assist, DEFAULT_POLYGON_SEED_COUNT, polygonSeedIds),
      },
      knob: {
        auto: true,
        cols: knobCols,
        rows: knobRows,
        knob_size: Number(raw.modes?.knob?.knob_size || DEFAULT_KNOB_SIZE),
        assist: normalizeAssist(raw.modes?.knob?.assist, DEFAULT_KNOB_SEED_COUNT, knobSeedIds(knobCols, knobRows)),
      },
      swap: {
        auto: true,
        cols: DEFAULT_SWAP_COLS,
        rows: DEFAULT_SWAP_ROWS,
      },
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
        const config = await readLevel(topic.id, group.id, level.id, level.title || level.id);
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

export function assertLandscape4x3(width: number, height: number) {
  const ratio = width / height;
  if (Math.abs(ratio - 4 / 3) > 0.01) {
    throw new Error(`图片比例必须是 4:3，当前是 ${width}x${height}。`);
  }
}
