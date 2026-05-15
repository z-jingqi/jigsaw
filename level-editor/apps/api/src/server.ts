import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { cors } from "hono/cors";

const __filename = fileURLToPath(import.meta.url);
const editorRoot = path.resolve(path.dirname(__filename), "../../..");
const projectRoot = path.resolve(editorRoot, "..");
const levelsDir = path.join(projectRoot, "levels");
const catalogPath = path.join(levelsDir, "catalog.json");
const port = Number(process.env.LEVEL_EDITOR_API_PORT || 5174);

const app = new Hono();

app.use(
  "/api/*",
  cors({
    origin: ["http://127.0.0.1:5173", "http://localhost:5173"],
    allowHeaders: ["content-type"],
    allowMethods: ["GET", "POST", "OPTIONS"],
  }),
);

app.get("/api/health", (c) => c.json({ ok: true, levelsDir: path.relative(projectRoot, levelsDir) }));

app.get("/api/catalog", async (c) => {
  const catalog = await readJson(catalogPath, makeEmptyCatalog());
  return c.json(catalog);
});

app.post("/api/catalog", async (c) => {
  const catalog = await c.req.json();
  await writeJson(catalogPath, normalizeCatalog(catalog));
  return c.json({ ok: true, path: path.relative(projectRoot, catalogPath) });
});

app.get("/api/levels/:topicId/:levelId", async (c) => {
  const topicId = safeId(c.req.param("topicId"));
  const levelId = safeId(c.req.param("levelId"));
  const target = levelPath(topicId, levelId);
  const level = await readJson(target, null);
  if (!level) return c.json({ ok: false, error: "level not found" }, 404);
  return c.json(level);
});

app.post("/api/levels/:topicId/:levelId", async (c) => {
  const topicId = safeId(c.req.param("topicId"));
  const levelId = safeId(c.req.param("levelId"));
  const payload = await c.req.json();
  const level = payload.level ?? payload;
  const target = levelPath(topicId, levelId);
  level.id = levelId;
  level.topic_id = topicId;
  level.image = {
    ...(level.image || {}),
    path: `res://levels/${topicId}/${levelId}/source.png`,
    name: "source.png",
  };
  await writeJson(target, level);
  const catalog = normalizeCatalog(payload.catalog ?? (await readJson(catalogPath, makeEmptyCatalog())));
  await writeJson(catalogPath, catalog);
  return c.json({ ok: true, path: path.relative(projectRoot, target), catalogPath: path.relative(projectRoot, catalogPath) });
});

app.get("/api/levels/:topicId/:levelId/source", async (c) => {
  const topicId = safeId(c.req.param("topicId"));
  const levelId = safeId(c.req.param("levelId"));
  const bytes = await readFile(sourcePath(topicId, levelId));
  return new Response(bytes, {
    headers: {
      "content-type": "image/png",
      "cache-control": "no-store",
    },
  });
});

app.post("/api/levels/:topicId/:levelId/source", async (c) => {
  const topicId = safeId(c.req.param("topicId"));
  const levelId = safeId(c.req.param("levelId"));
  const body = await c.req.parseBody();
  const file = body.source;
  if (!(file instanceof File)) return c.json({ ok: false, error: "source file is required" }, 400);
  const target = sourcePath(topicId, levelId);
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, Buffer.from(await file.arrayBuffer()));
  return c.json({
    ok: true,
    path: path.relative(projectRoot, target),
    godotPath: `res://levels/${topicId}/${levelId}/source.png`,
    url: `/api/levels/${topicId}/${levelId}/source?mtime=${Date.now()}`,
  });
});

function levelPath(topicId: string, levelId: string) {
  return safeJoin(levelsDir, topicId, levelId, "level.json");
}

function sourcePath(topicId: string, levelId: string) {
  return safeJoin(levelsDir, topicId, levelId, "source.png");
}

function safeJoin(root: string, ...parts: string[]) {
  const target = path.resolve(root, ...parts);
  if (!target.startsWith(`${path.resolve(root)}${path.sep}`)) {
    throw new Error("refusing to access outside levels directory");
  }
  return target;
}

function safeId(value: unknown) {
  const id = String(value || "").trim();
  if (!/^[a-zA-Z0-9_-]+$/.test(id)) {
    throw new Error("id must contain only letters, numbers, underscore, or dash");
  }
  return id;
}

async function readJson<T>(target: string, fallback: T): Promise<T> {
  try {
    return JSON.parse(await readFile(target, "utf8")) as T;
  } catch {
    return fallback;
  }
}

async function writeJson(target: string, data: unknown) {
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, `${JSON.stringify(data, null, "\t")}\n`, "utf8");
}

function makeEmptyCatalog() {
  return {
    schema: "jigsaw.catalog.v1",
    version: 1,
    default_locale: "zh-Hans",
    locales: ["zh-Hans", "en"],
    topics: [],
  };
}

function normalizeCatalog(input: any) {
  const catalog = {
    ...makeEmptyCatalog(),
    ...(input || {}),
  };
  catalog.topics = [...(catalog.topics || [])]
    .map((topic, topicIndex) => ({
      id: safeId(topic.id),
      name: String(topic.name || topic.id),
      name_i18n: topic.name_i18n || {},
      sort_order: Number(topic.sort_order ?? topicIndex),
      cover: String(topic.cover || ""),
      levels: [...(topic.levels || [])]
        .map((level, levelIndex) => ({
          id: safeId(level.id),
          title: String(level.title || level.id),
          title_i18n: level.title_i18n || {},
          sort_order: Number(level.sort_order ?? levelIndex),
          path: String(level.path || `res://levels/${topic.id}/${level.id}/level.json`),
          source: String(level.source || `res://levels/${topic.id}/${level.id}/source.png`),
        }))
        .sort((a, b) => a.sort_order - b.sort_order),
    }))
    .sort((a, b) => a.sort_order - b.sort_order);
  return catalog;
}

serve({ fetch: app.fetch, hostname: "127.0.0.1", port }, (info) => {
  console.log(`[level-editor-api] http://${info.address}:${info.port}`);
  console.log(`[level-editor-api] writing levels to ${levelsDir}`);
});
