import { serve } from "@hono/node-server";
import { Hono, type Context } from "hono";
import { cors } from "hono/cors";
import fs from "node:fs/promises";
import { serveStatic } from "@hono/node-server/serve-static";
import path from "node:path";
import { spawn } from "node:child_process";
import type { CatalogRenameOperation, LevelCatalog, LevelConfig } from "./types.js";
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
import { levelCoverPath, levelCoverResPath, repoRoot, sourceImagePath, topicCoverPath, topicCoverResPath, topicIconPath, topicIconResPath } from "./paths.js";

const app = new Hono();

app.use("*", cors());
app.use("/levels/*", serveStatic({ root: repoRoot }));

app.get("/api/catalog", async (c) => {
  const catalog = await readCatalog();
  const hydrated = await hydrateCatalog(catalog);
  const statuses = await levelStatuses(hydrated);
  return c.json({ catalog: hydrated, statuses });
});

app.put("/api/catalog", async (c) => {
  const body = (await c.req.json()) as LevelCatalog | { catalog: LevelCatalog; renames?: unknown };
  const payload = "catalog" in body ? body.catalog : body;
  const renames = "catalog" in body && Array.isArray(body.renames) ? body.renames : [];
  const catalog = normalizeCatalog(payload);
  await applyCatalogRenames(renames as CatalogRenameOperation[]);
  for (const topic of catalog.topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        await ensureLevelDir(topic.id, group.id, level.id);
        const config = await readLevel(topic.id, group.id, level.id, level.title || level.id);
        await writeLevel({
          ...config,
          title: level.title || config.title,
          title_i18n: level.title_i18n || config.title_i18n,
          cover: level.cover || config.cover,
        });
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

app.put("/api/levels/:topicId/:groupId/:levelId", async (c) => {
  const topicId = c.req.param("topicId");
  const groupId = c.req.param("groupId");
  const levelId = c.req.param("levelId");
  const payload = (await c.req.json()) as LevelConfig;
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

async function compressImage(filePath: string) {
  const toolPath = path.join(repoRoot, "tools", "compress_images.py");
  await new Promise<void>((resolve, reject) => {
    const child = spawn("python3", [toolPath, filePath, "--jpeg-quality", "88"], { cwd: repoRoot });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += String(chunk);
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || "封面压缩失败。"));
    });
  });
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

app.post("/api/levels/:topicId/:groupId/:levelId/cover", async (c) => {
  const topicId = c.req.param("topicId");
  const groupId = c.req.param("groupId");
  const levelId = c.req.param("levelId");
  try {
    const file = await readUploadFile(c);
    extensionFromFile(file, ["jpg"]);
    await ensureLevelDir(topicId, groupId, levelId);
    const coverPath = levelCoverPath(topicId, groupId, levelId, "jpg");
    await writeUpload(coverPath, file);
    await compressImage(coverPath);
    return c.json({ path: levelCoverResPath(topicId, groupId, levelId, "jpg") });
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
    await ensureLevelDir(topicId, groupId, levelId);
    await fs.writeFile(sourceImagePath(topicId, groupId, levelId), buffer);
    const level = await readLevel(topicId, groupId, levelId);
    level.image.width = size.width;
    level.image.height = size.height;
    level.image.aspect_ratio = size.width / size.height;
    await writeLevel(level);
    await upsertCatalogLevel(level);
    return c.json(level);
  } catch (error) {
    return c.json({ error: error instanceof Error ? error.message : "上传失败。" }, 400);
  }
});

app.get("/api/levels/:topicId/:groupId/:levelId/source", async (c) => {
  const path = sourceImagePath(c.req.param("topicId"), c.req.param("groupId"), c.req.param("levelId"));
  try {
    const bytes = await fs.readFile(path);
    return new Response(bytes, {
      headers: { "Content-Type": "image/jpeg" },
    });
  } catch {
    return c.notFound();
  }
});

const port = Number(process.env.PORT || 8888);
serve({ fetch: app.fetch, port });
console.log(`JigCat level editor API listening on http://localhost:${port}`);
