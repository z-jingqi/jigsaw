import { copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
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
const toolsDir = path.join(projectRoot, "tools");
const port = Number(process.env.LEVEL_EDITOR_API_PORT || 5174);
const execFileAsync = promisify(execFile);

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
	level.image = normalizeDefaultImage(level.image, topicId, levelId);
	level.assets = {
		...(level.assets || {}),
		default_image: normalizeDefaultImage(level.assets?.default_image || level.image, topicId, levelId),
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

app.get("/api/levels/:topicId/:levelId/source/:mode", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const mode = safeMode(c.req.param("mode"));
	const bytes = await readFile(modeSourcePath(topicId, levelId, mode));
	return new Response(bytes, {
		headers: {
			"content-type": "image/png",
			"cache-control": "no-store",
		},
	});
});

app.get("/api/levels/:topicId/:levelId/assets/:fileName", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const fileName = safeFileName(c.req.param("fileName"));
	const bytes = await readFile(levelAssetPath(topicId, levelId, fileName));
	return new Response(bytes, {
		headers: {
			"content-type": contentTypeForFile(fileName),
			"cache-control": "no-store",
		},
	});
});

app.get("/api/levels/:topicId/:levelId/pending/:fileName", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const fileName = safeFileName(c.req.param("fileName"));
	const bytes = await readFile(pendingImagePath(topicId, levelId, fileName));
	return new Response(bytes, {
		headers: {
			"content-type": contentTypeForFile(fileName),
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

app.post("/api/levels/:topicId/:levelId/pending-image", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const body = await c.req.parseBody();
	const file = body.source;
	if (!(file instanceof File)) return c.json({ ok: false, error: "source file is required" }, 400);
	const extension = imageExtension(file.name || "source.png");
	const fileName = `${Date.now()}-${safeStem(file.name || "source")}${extension}`;
	const target = pendingImagePath(topicId, levelId, fileName);
	await mkdir(path.dirname(target), { recursive: true });
	await writeFile(target, Buffer.from(await file.arrayBuffer()));
	return c.json({
		ok: true,
		pendingId: fileName,
		name: file.name || fileName,
		path: path.relative(projectRoot, target),
		url: `/api/levels/${topicId}/${levelId}/pending/${fileName}?mtime=${Date.now()}`,
	});
});

app.post("/api/levels/:topicId/:levelId/process-image", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const payload = await c.req.json();
	const pendingId = safeFileName(payload.pendingId);
	const target = safeImageTarget(payload.target);
	const steps = Array.isArray(payload.steps) ? payload.steps.map(normalizeProcessStep) : [];
	if (!steps.length) return c.json({ ok: false, error: "processing steps are required" }, 400);

	const input = pendingImagePath(topicId, levelId, pendingId);
	const workDir = await mkdtemp(path.join(levelDir(topicId, levelId), "_process-"));
	try {
		const processed = await runImagePipeline(input, workDir, steps);
		const processedExt = path.extname(processed).toLowerCase();
		const extension = processedExt === ".jpeg" ? ".jpg" : processedExt;
		const finalName = targetImageFileName(target, extension || ".png");
		const finalPath = levelAssetPath(topicId, levelId, finalName);
		await copyFile(processed, finalPath);
		return c.json({
			ok: true,
			path: path.relative(projectRoot, finalPath),
			godotPath: `res://levels/${topicId}/${levelId}/${finalName}`,
			url: `/api/levels/${topicId}/${levelId}/assets/${finalName}?mtime=${Date.now()}`,
		});
	} finally {
		await rm(workDir, { recursive: true, force: true });
	}
});

app.post("/api/levels/:topicId/:levelId/source/:mode", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const mode = safeMode(c.req.param("mode"));
	const body = await c.req.parseBody();
	const file = body.source;
	if (!(file instanceof File)) return c.json({ ok: false, error: "source file is required" }, 400);
	const target = modeSourcePath(topicId, levelId, mode);
	await mkdir(path.dirname(target), { recursive: true });
	await writeFile(target, Buffer.from(await file.arrayBuffer()));
	return c.json({
		ok: true,
		path: path.relative(projectRoot, target),
		godotPath: `res://levels/${topicId}/${levelId}/${mode}_source.png`,
		url: `/api/levels/${topicId}/${levelId}/source/${mode}?mtime=${Date.now()}`,
	});
});

function levelPath(topicId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, levelId, "level.json");
}

function levelDir(topicId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, levelId);
}

function sourcePath(topicId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, levelId, "source.png");
}

function modeSourcePath(topicId: string, levelId: string, mode: "polygon" | "knob") {
	return safeJoin(levelsDir, topicId, levelId, `${mode}_source.png`);
}

function levelAssetPath(topicId: string, levelId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, levelId, fileName);
}

function pendingImagePath(topicId: string, levelId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, levelId, "_pending", fileName);
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

function safeMode(value: unknown): "polygon" | "knob" {
	const mode = String(value || "").trim();
	if (mode !== "polygon" && mode !== "knob") {
		throw new Error("mode must be polygon or knob");
	}
	return mode;
}

function safeImageTarget(value: unknown): "default" | "polygon" | "knob" {
	const target = String(value || "").trim();
	if (target !== "default" && target !== "polygon" && target !== "knob") {
		throw new Error("target must be default, polygon, or knob");
	}
	return target;
}

function safeFileName(value: unknown) {
	const fileName = path.basename(String(value || "").trim());
	if (!/^[a-zA-Z0-9_.-]+$/.test(fileName)) {
		throw new Error("file name must contain only letters, numbers, dash, underscore, or dot");
	}
	return fileName;
}

function safeStem(value: unknown) {
	const fileName = path.basename(String(value || "source").trim());
	const stem = path.parse(fileName).name.replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
	return stem || "source";
}

function imageExtension(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpg" || ext === ".jpeg") return ".jpg";
	if (ext === ".webp") return ".webp";
	return ".png";
}

function contentTypeForFile(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
	if (ext === ".webp") return "image/webp";
	if (ext === ".svg") return "image/svg+xml";
	return "image/png";
}

type ProcessStep = {
	type: "remove_background" | "trim_transparent" | "convert_jpg";
	tolerance?: number;
	padding?: number;
	quality?: number;
	background?: string;
};

function normalizeProcessStep(value: any): ProcessStep {
	const type = String(value?.type || "");
	if (type !== "remove_background" && type !== "trim_transparent" && type !== "convert_jpg") {
		throw new Error(`unsupported processing step: ${type}`);
	}
	return {
		type,
		tolerance: clampInt(value?.tolerance, 0, 441, 35),
		padding: clampInt(value?.padding, 0, 256, 0),
		quality: clampInt(value?.quality, 1, 100, 88),
		background: safeColor(value?.background || "#F6EBD4"),
	};
}

function clampInt(value: unknown, min: number, max: number, fallback: number) {
	const parsed = Number(value);
	if (!Number.isFinite(parsed)) return fallback;
	return Math.max(min, Math.min(max, Math.round(parsed)));
}

function safeColor(value: unknown) {
	const color = String(value || "").trim();
	if (!/^#[0-9a-fA-F]{6}$/.test(color)) return "#F6EBD4";
	return color;
}

function targetImageFileName(target: "default" | "polygon" | "knob", extension: string) {
	const ext = extension === ".jpeg" ? ".jpg" : extension || ".png";
	if (target === "default") return `source${ext}`;
	return `${target}_source${ext}`;
}

async function runImagePipeline(input: string, workDir: string, steps: ProcessStep[]) {
	let current = input;
	for (const [index, step] of steps.entries()) {
		const outDir = path.join(workDir, `step-${index}`);
		await mkdir(outDir, { recursive: true });
		const parsed = path.parse(current);
		if (step.type === "remove_background") {
			await execTool("remove_solid_background.py", [
				current,
				"-o",
				outDir,
				"--suffix",
				"",
				"--tolerance",
				String(step.tolerance ?? 35),
			]);
			current = await outputOrCopied(current, path.join(outDir, `${parsed.name}.png`));
			continue;
		}
		if (step.type === "trim_transparent") {
			await execTool("trim_transparent_image.py", [
				current,
				"-o",
				outDir,
				"--padding",
				String(step.padding ?? 0),
			]);
			current = await outputOrCopied(current, path.join(outDir, parsed.base));
			continue;
		}
		if (step.type === "convert_jpg") {
			await execTool("convert_to_jpg.py", [
				current,
				"-o",
				outDir,
				"--suffix",
				"",
				"--quality",
				String(step.quality ?? 88),
				"--background",
				step.background || "#F6EBD4",
				"--overwrite",
			]);
			current = await outputOrCopied(current, path.join(outDir, `${parsed.name}.jpg`));
		}
	}
	return current;
}

async function execTool(scriptName: string, args: Array<string>) {
	const script = path.join(toolsDir, scriptName);
	const { stderr } = await execFileAsync("python3", [script, ...args.map(String)], {
		cwd: projectRoot,
		maxBuffer: 1024 * 1024 * 8,
	});
	if (stderr.trim()) {
		console.warn(`[level-editor-api] ${scriptName}: ${stderr.trim()}`);
	}
}

async function outputOrCopied(input: string, output: string) {
	const target = path.resolve(output);
	try {
		await readFile(target);
		return target;
	} catch {
		await copyFile(input, target);
		return target;
	}
}

function normalizeDefaultImage(image: any, topicId: string, levelId: string) {
	return {
		...(image || {}),
		path: String(image?.path || `res://levels/${topicId}/${levelId}/source.png`),
		name: String(image?.name || "source.png"),
		width: Number(image?.width || 0),
		height: Number(image?.height || 0),
	};
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
