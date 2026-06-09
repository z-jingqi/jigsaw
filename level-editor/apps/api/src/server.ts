import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { cors } from "hono/cors";
import fs from "node:fs/promises";
import { serveStatic } from "@hono/node-server/serve-static";
import type { CatalogRenameOperation, LevelCatalog, LevelConfig } from "./types.js";
import {
  applyCatalogRenames,
  assertPortrait3x4,
  ensureLevelDir,
  levelStatuses,
  normalizeCatalog,
  readCatalog,
  readJpegSize,
  readLevel,
  writeCatalog,
  writeLevel,
} from "./lib.js";
import { repoRoot, sourceImagePath } from "./paths.js";

const app = new Hono();

app.use("*", cors());
app.use("/levels/*", serveStatic({ root: repoRoot }));

app.get("/api/catalog", async (c) => {
  const catalog = await readCatalog();
  const statuses = await levelStatuses(catalog);
  return c.json({ catalog, statuses });
});

app.put("/api/catalog", async (c) => {
  const body = (await c.req.json()) as LevelCatalog | { catalog: LevelCatalog; renames?: unknown };
  const payload = "catalog" in body ? body.catalog : body;
  const renames = "catalog" in body && Array.isArray(body.renames) ? body.renames : [];
  const catalog = normalizeCatalog(payload);
  await applyCatalogRenames(renames as CatalogRenameOperation[]);
  await writeCatalog(catalog);
  for (const topic of catalog.topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        await ensureLevelDir(topic.id, group.id, level.id);
        await writeLevel(await readLevel(topic.id, group.id, level.id, level.title));
      }
    }
  }
  return c.json({ catalog, statuses: await levelStatuses(catalog) });
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
  return c.json(await readLevel(topicId, groupId, levelId, payload.title));
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

const port = Number(process.env.PORT || 8787);
serve({ fetch: app.fetch, port });
console.log(`JigCat level editor API listening on http://localhost:${port}`);
