import { serve } from "@hono/node-server";
import { Hono, type Context } from "hono";
import { cors } from "hono/cors";
import fs from "node:fs/promises";
import { serveStatic } from "@hono/node-server/serve-static";
import path from "node:path";
import type { CatalogRenameOperation, LevelCatalog, LevelConfig, SelectedLevel, TinyPieceAuditResult } from "./types.js";
import {
  applyCatalogRenames,
  assertPortrait3x4,
  ensureLevelDir,
  extensionFromFile,
  hydrateCatalog,
  levelStatuses,
  normalizeCatalog,
  readCatalog,
  readJpegSize,
  readLevel,
  upsertCatalogLevel,
  writeCatalog,
  writeLevel,
} from "./lib.js";
import { repoRoot, sourceImagePath, topicCoverPath, topicCoverResPath, topicIconPath, topicIconResPath, resourceDiskPath, sourceResPath } from "./paths.js";
import { validateCatalogInput, validateLevelInput } from "./validation.js";
import { replaceSource } from "./source-image.js";
import { DEFAULT_TINY_PIECE_THRESHOLD_PERCENT, findTinyPieces } from "./tiny-piece-audit.js";

const app = new Hono();

app.use("*", cors());
app.use("/levels/*", serveStatic({ root: repoRoot }));
app.use("/assets/*", serveStatic({ root: repoRoot }));
app.onError((error, c) => c.json({ error: error.message }, 400));
app.use("/api/*", async (c, next) => {
  for (const name of ["topicId", "groupId", "levelId"]) {
    const value = c.req.param(name);
    if (value && !/^[a-zA-Z0-9_-]+$/.test(value)) return c.json({ error: "无效的资源标识" }, 400);
  }
  await next();
});

app.get("/api/catalog", async (c) => {
  const catalog = await readCatalog();
  const hydrated = await hydrateCatalog(catalog);
  const statuses = await levelStatuses(hydrated);
  return c.json({ catalog: hydrated, statuses });
});

app.put("/api/catalog", async (c) => {
  const body = (await c.req.json()) as LevelCatalog | { catalog: LevelCatalog; renames?: unknown };
  if (!body || typeof body !== "object") return c.json({ error: "目录数据无效" }, 400);
  const payload = "catalog" in body ? body.catalog : body;
  validateCatalogInput(payload);
  const renames = "catalog" in body && Array.isArray(body.renames) ? body.renames : [];
  const catalog = normalizeCatalog(payload);
  await applyCatalogRenames(renames as CatalogRenameOperation[]);
  for (const topic of catalog.topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        await ensureLevelDir(topic.id, group.id, level.id);
        const config = await readLevel(topic.id, group.id, level.id, level.title || level.id);
        const nextTitle = level.title || config.title;
        const identityChanged = renames.length > 0;
        const titleChanged = nextTitle !== config.title;
        if (identityChanged || titleChanged) {
          await writeLevel({
            ...config,
            title: nextTitle,
            title_i18n: level.title_i18n || config.title_i18n,
          });
        }
      }
    }
  }
  await writeCatalog(catalog);
  const hydrated = await hydrateCatalog(await readCatalog());
  return c.json({ catalog: hydrated, statuses: await levelStatuses(hydrated) });
});

app.get("/api/levels/:topicId/:groupId/:levelId", async (c) => {
  const topicId = c.req.param("topicId");
  const groupId = c.req.param("groupId");
  const levelId = c.req.param("levelId");
  const level = await readLevel(topicId, groupId, levelId);
  return c.json(level);
});

app.post("/api/audits/tiny-pieces", async (c) => {
  const body = (await c.req.json()) as { levels?: SelectedLevel[] };
  const requested = Array.isArray(body.levels) ? body.levels : [];
  const catalog = await readCatalog();
  const available = new Map<string, { target: SelectedLevel; title: string }>();
  for (const topic of catalog.topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        const target = { topicId: topic.id, groupId: group.id, levelId: level.id };
        available.set(`${target.topicId}/${target.groupId}/${target.levelId}`, {
          target,
          title: level.title || level.id,
        });
      }
    }
  }

  const uniqueTargets = new Map<string, { target: SelectedLevel; title: string }>();
  for (const target of requested) {
    const key = `${target.topicId}/${target.groupId}/${target.levelId}`;
    const match = available.get(key);
    if (match) uniqueTargets.set(key, match);
  }

  const selected = [...uniqueTargets.values()];
  const results: TinyPieceAuditResult[] = [];
  const batchSize = 8;
  for (let offset = 0; offset < selected.length; offset += batchSize) {
    const batch = selected.slice(offset, offset + batchSize);
    const audited = await Promise.all(
      batch.map(async ({ target, title }) => {
        const level = await readLevel(target.topicId, target.groupId, target.levelId, title);
        return {
          ...target,
          title: level.title || title,
          tinyPieces: findTinyPieces(level),
        };
      }),
    );
    results.push(...audited);
  }

  return c.json({
    thresholdPercent: DEFAULT_TINY_PIECE_THRESHOLD_PERCENT,
    checkedCount: results.length,
    abnormalCount: results.filter((result) => result.tinyPieces.length > 0).length,
    tinyPieceCount: results.reduce((count, result) => count + result.tinyPieces.length, 0),
    results,
  });
});

app.put("/api/levels/:topicId/:groupId/:levelId", async (c) => {
  const topicId = c.req.param("topicId");
  const groupId = c.req.param("groupId");
  const levelId = c.req.param("levelId");
  const payload = (await c.req.json()) as LevelConfig;
  validateLevelInput(payload);
  resourceDiskPath(payload.image.path);
  await writeLevel({ ...payload, topic_id: topicId, group_id: groupId, id: levelId });
  const level = await readLevel(topicId, groupId, levelId, payload.title);
  await upsertCatalogLevel(level);
  return c.json(level);
});

async function readUploadFile(c: Context) {
  const body = await c.req.parseBody();
  const file = body.file;
  if (!(file instanceof File)) {
    throw new Error("请选择文件。");
  }
  return file;
}

async function writeUpload(filePath: string, file: File) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, Buffer.from(await file.arrayBuffer()));
}

app.post("/api/topics/:topicId/:asset", async (c) => {
  const topicId = c.req.param("topicId");
  const asset = c.req.param("asset");
  if (asset !== "cover" && asset !== "icon") {
    return c.json({ error: "未知的主题资源。" }, 400);
  }
  try {
    const file = await readUploadFile(c);
    const extension = extensionFromFile(file, asset === "icon" ? ["svg", "png"] : ["jpg", "png", "webp"]);
    const filePath = asset === "icon" ? topicIconPath(topicId, extension) : topicCoverPath(topicId, extension);
    await writeUpload(filePath, file);
    return c.json({ path: asset === "icon" ? topicIconResPath(topicId, extension) : topicCoverResPath(topicId, extension) });
  } catch (error) {
    return c.json({ error: error instanceof Error ? error.message : "上传失败。" }, 400);
  }
});

app.post("/api/levels/:topicId/:groupId/:levelId/source", async (c) => {
  const topicId = c.req.param("topicId");
  const groupId = c.req.param("groupId");
  const levelId = c.req.param("levelId");
  const body = await c.req.parseBody();
  const file = body.file;
  if (!(file instanceof File)) {
    return c.json({ error: "请选择 JPG 文件。" }, 400);
  }
  const buffer = Buffer.from(await file.arrayBuffer());
  try {
    const size = readJpegSize(buffer);
    assertPortrait3x4(size.width, size.height);
    const original = await readLevel(topicId, groupId, levelId);
    const level = replaceSource(original, sourceResPath(topicId, groupId, levelId), size.width, size.height);
    await ensureLevelDir(topicId, groupId, levelId);
    await fs.writeFile(sourceImagePath(topicId, groupId, levelId), buffer);
    await writeLevel(level);
    await upsertCatalogLevel(level);
    return c.json(level);
  } catch (error) {
    return c.json({ error: error instanceof Error ? error.message : "上传失败。" }, 400);
  }
});

app.get("/api/levels/:topicId/:groupId/:levelId/source", async (c) => {
  const level = await readLevel(c.req.param("topicId"), c.req.param("groupId"), c.req.param("levelId"));
  const source = resourceDiskPath(level.image.path);
  try {
    const bytes = await fs.readFile(source);
    return new Response(bytes, {
      headers: { "Content-Type": source.endsWith(".webp") ? "image/webp" : source.endsWith(".png") ? "image/png" : "image/jpeg", "Cache-Control": "no-cache" },
    });
  } catch {
    return c.notFound();
  }
});

const port = Number(process.env.PORT || 8888);
serve({ fetch: app.fetch, port });
console.log(`JigCat level editor API listening on http://localhost:${port}`);
