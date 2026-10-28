import type { LevelCatalog, LevelConfig } from "./types.js";

function record(value: unknown): value is Record<string, any> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
const validId = (id: unknown) => typeof id === "string" && /^[a-zA-Z0-9_-]+$/.test(id);

export function validateCatalogInput(value: unknown): asserts value is LevelCatalog {
  if (!record(value) || !Array.isArray(value.topics)) throw new Error("目录必须包含 topics 数组，未写入任何数据");
  const topics = new Set<string>();
  for (const topic of value.topics) {
    if (!record(topic) || !validId(topic.id) || topics.has(topic.id)) throw new Error("主题 ID 无效或重复");
    topics.add(topic.id);
    const groups = Array.isArray(topic.levels) ? [{ id: "levels", levels: topic.levels }] : topic.groups;
    if (!Array.isArray(groups)) throw new Error("主题必须包含关卡或分组数组");
    const groupIds = new Set<string>();
    for (const group of groups) {
      if (!record(group) || !validId(group.id) || groupIds.has(group.id) || !Array.isArray(group.levels)) throw new Error("分组无效或 ID 重复");
      groupIds.add(group.id);
      const ids = new Set<string>();
      for (const level of group.levels) {
        if (!record(level) || !validId(level.id) || ids.has(level.id)) throw new Error("关卡 ID 无效或重复");
        ids.add(level.id);
      }
    }
  }
}

export function validateLevelInput(value: unknown): asserts value is LevelConfig {
  if (!record(value) || !record(value.image) || !record(value.modes)) throw new Error("关卡缺少 image 或 modes，未写入任何数据");
  if (typeof value.image.path !== "string" || !/^res:\/\/(levels|assets)\//.test(value.image.path)) throw new Error("图片资源路径无效");
  for (const dimension of [value.image.width, value.image.height]) {
    if (!Number.isFinite(dimension) || dimension < 0) throw new Error("图片尺寸必须是非负有限数值");
  }
  if (Boolean(value.image.width) !== Boolean(value.image.height)) throw new Error("图片宽高必须同时设置");
  const polygon = value.modes.polygon;
  if (polygon !== undefined) {
    if (!record(polygon) || !Array.isArray(polygon.pieces)) throw new Error("多边形碎片必须为数组");
    const ids = new Set<string>();
    for (const piece of polygon.pieces) {
      if (!record(piece) || typeof piece.id !== "string" || !piece.id || ids.has(piece.id)) throw new Error("碎片 ID 无效或重复");
      ids.add(piece.id);
      if (!Array.isArray(piece.points) || piece.points.length < 3 || !piece.points.every((p: unknown) => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite))) throw new Error("碎片至少需要三个有限坐标顶点");
    }
  }
  for (const name of ["knob", "swap"]) {
    const mode = value.modes[name];
    if (mode === undefined) continue;
    if (!record(mode) || ![mode.cols, mode.rows].every(v => Number.isInteger(v) && v > 0 && v <= 100)) throw new Error("模式行列数必须在 1 到 100 之间");
  }
}
