import { copyFile, mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
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
const pendingImagesDir = path.join(levelsDir, "_pending", "images");
const pendingImagesIndexPath = path.join(levelsDir, "_pending", "images.json");
const toolsDir = path.join(projectRoot, "tools");
const port = Number(process.env.LEVEL_EDITOR_API_PORT || 5174);
const execFileAsync = promisify(execFile);

const app = new Hono();

app.onError((error, c) => {
	console.error("[level-editor-api]", error);
	return c.json({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
});

app.use(
  "/api/*",
  cors({
    origin: ["http://127.0.0.1:5173", "http://localhost:5173"],
    allowHeaders: ["content-type"],
    allowMethods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
  }),
);

app.get("/api/health", (c) => c.json({ ok: true, levelsDir: path.relative(projectRoot, levelsDir) }));

app.get("/api/python-tools", async (c) => {
	const entries = await readdir(toolsDir, { withFileTypes: true });
	const tools = entries
		.filter((entry) => entry.isFile() && entry.name.endsWith(".py"))
		.map((entry) => pythonToolInfo(entry.name))
		.filter((tool) => tool !== null)
		.sort((a, b) => Number(b.supported) - Number(a.supported) || a.name.localeCompare(b.name));
	return c.json({ ok: true, tools });
});

app.get("/api/catalog", async (c) => {
  const catalog = await readJson(catalogPath, makeEmptyCatalog());
  return c.json(catalog);
});

app.get("/api/topics/:topicId/cover", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const catalog = normalizeCatalog(await readJson(catalogPath, makeEmptyCatalog()));
	const topic = catalog.topics.find((item: any) => item.id === topicId);
	if (!topic?.cover) return c.json({ ok: false, error: "topic cover not found" }, 404);
	const target = topicCoverPath(topicId, topic.cover);
	const bytes = await readFile(target);
	return new Response(bytes, {
		headers: {
			"content-type": contentTypeForFile(target),
			"cache-control": "no-store",
		},
	});
});

app.get("/api/topics/:topicId/assets/:fileName", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const fileName = safeFileName(c.req.param("fileName"));
	const target = topicAssetPath(topicId, fileName);
	const bytes = await readFile(target);
	return new Response(bytes, {
		headers: {
			"content-type": contentTypeForFile(target),
			"cache-control": "no-store",
		},
	});
});

app.post("/api/catalog", async (c) => {
  const catalog = await c.req.json();
  await writeJson(catalogPath, normalizeCatalog(catalog));
  return c.json({ ok: true, path: path.relative(projectRoot, catalogPath) });
});

app.post("/api/topics/:topicId/cover", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const body = await c.req.parseBody();
	const file = body.cover ?? body.source;
	if (!(file instanceof File)) return c.json({ ok: false, error: "cover file is required" }, 400);
	const extension = imageExtension(file.name || "cover.png");
	const fileName = `cover${extension}`;
	const target = topicAssetPath(topicId, fileName);
	await mkdir(path.dirname(target), { recursive: true });
	await writeFile(target, Buffer.from(await file.arrayBuffer()));
	const catalog = updateCatalogTopicCover(await readJson(catalogPath, makeEmptyCatalog()), topicId, fileName);
	await writeJson(catalogPath, catalog);
	return c.json({
		ok: true,
		catalog,
		godotPath: `res://levels/${topicId}/${fileName}`,
		url: `/api/topics/${topicId}/cover?mtime=${Date.now()}`,
	});
});

app.post("/api/topics/:topicId/cover/process", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const payload = await c.req.json();
	const steps = Array.isArray(payload.steps) ? payload.steps.map(normalizeProcessStep) : [];
	if (!steps.length) return c.json({ ok: false, error: "processing steps are required" }, 400);
	const catalog = normalizeCatalog(await readJson(catalogPath, makeEmptyCatalog()));
	const topic = catalog.topics.find((item: any) => item.id === topicId);
	const cover = String(payload.coverPath || topic?.cover || "");
	if (!cover) return c.json({ ok: false, error: "topic cover not found" }, 404);
	const input = topicCoverPath(topicId, cover);
	const workDir = await mkdtemp(path.join(topicDir(topicId), "_process-"));
	try {
		const processed = await runImagePipeline(input, workDir, steps);
		const processedExt = path.extname(processed).toLowerCase();
		const extension = processedExt === ".jpeg" ? ".jpg" : processedExt || ".png";
		const finalName = `cover${extension}`;
		const finalPath = topicAssetPath(topicId, finalName);
		await copyFile(processed, finalPath);
		const nextCatalog = updateCatalogTopicCover(catalog, topicId, finalName);
		await writeJson(catalogPath, nextCatalog);
		return c.json({
			ok: true,
			catalog: nextCatalog,
			godotPath: `res://levels/${topicId}/${finalName}`,
			url: `/api/topics/${topicId}/cover?mtime=${Date.now()}`,
		});
	} finally {
		await rm(workDir, { recursive: true, force: true });
	}
});

app.get("/api/pending-images", async (c) => {
	const items = await readPendingImages();
	const folders = await readPendingFolders(items);
	return c.json({ ok: true, items, folders });
});

app.post("/api/pending-images", async (c) => {
	const body = await c.req.parseBody({ all: true });
	const kind = safePendingImageKind(body.kind);
	const files = bodyFiles(body.files ?? body.source);
	const folders = bodyStrings(body.folders);
	if (!files.length) return c.json({ ok: false, error: "source file is required" }, 400);
	const existingData = await readPendingData();
	const usedNames = new Set(existingData.items.map((item) => pendingNameKey(item.folder || "", item.name)));
	const created: PendingImageItem[] = [];
	const skipped: Array<{ name: string; folder: string; reason: string }> = [];
	for (const [index, file] of files.entries()) {
		const folder = safeFolderName(folders[index] || "");
		const name = file.name || "source.png";
		const nameKey = pendingNameKey(folder, name);
		if (usedNames.has(nameKey)) {
			skipped.push({ name, folder, reason: "duplicate_name" });
			continue;
		}
		usedNames.add(nameKey);
		const extension = imageExtension(file.name || "source.png");
		const id = `${Date.now()}-${index}-${safeStem(file.name || "source")}`;
		const fileName = `original${extension}`;
		const target = globalPendingImagePath(id, fileName);
		await mkdir(path.dirname(target), { recursive: true });
		await writeFile(target, Buffer.from(await file.arrayBuffer()));
		created.push({
			id,
			name,
			kind,
			path: path.relative(projectRoot, target),
			url: `/api/pending-images/${id}/source?mtime=${Date.now()}`,
			source_info: await imageInfoForPath(target),
			processed: false,
			folder,
			created_at: new Date().toISOString(),
		});
	}
	if (!created.length) {
		return c.json({ ok: true, item: null, items: [], skipped, skipped_count: skipped.length });
	}
	const items = [...created, ...existingData.items.filter((existing) => !created.some((item) => item.id === existing.id))];
	await writePendingData(items, uniqueStrings([...(existingData.folders || []), ...created.map((item) => item.folder || "")]));
	return c.json({ ok: true, item: created[0], items: created, skipped, skipped_count: skipped.length });
});

app.post("/api/pending-folders", async (c) => {
	const payload = await c.req.json();
	const folder = safeFolderName(payload.name);
	if (!folder) return c.json({ ok: false, error: "folder name is required" }, 400);
	const data = await readPendingData();
	const folders = uniqueStrings([...(data.folders || []), folder]);
	await writePendingData(data.items || [], folders);
	return c.json({ ok: true, folders });
});

app.patch("/api/pending-folders", async (c) => {
	const payload = await c.req.json();
	const oldName = safeFolderName(payload.oldName);
	const newName = safeFolderName(payload.newName);
	if (!oldName || !newName) return c.json({ ok: false, error: "folder name is required" }, 400);
	const data = await readPendingData();
	const items = (data.items || []).map((item) => ((item.folder || "") === oldName ? { ...item, folder: newName } : item));
	const folders = uniqueStrings([...(data.folders || []).filter((folder) => folder !== oldName), newName]);
	await writePendingData(items, folders);
	return c.json({ ok: true, items, folders: await readPendingFolders(items, folders) });
});

app.post("/api/pending-images/batch-update", async (c) => {
	const payload = await c.req.json();
	const ids = Array.isArray(payload.ids) ? payload.ids.map(safeFileName) : [];
	const folder = payload.folder === null ? "" : safeFolderName(payload.folder || "");
	if (!ids.length) return c.json({ ok: false, error: "ids are required" }, 400);
	const idSet = new Set(ids);
	const data = await readPendingData();
	const items = (data.items || []).map((item) => (idSet.has(item.id) ? { ...item, folder } : item));
	const folders = folder ? uniqueStrings([...(data.folders || []), folder]) : data.folders || [];
	await writePendingData(items, folders);
	return c.json({ ok: true, items, folders: await readPendingFolders(items, folders) });
});

app.post("/api/pending-images/batch-delete", async (c) => {
	const payload = await c.req.json();
	const imageIds = new Set<string>(Array.isArray(payload.imageIds) ? payload.imageIds.map(safeFileName) : []);
	const foldersToRemove = new Set<string>(Array.isArray(payload.folders) ? payload.folders.map(safeFolderName).filter(Boolean) : []);
	const data = await readPendingData();
	const keptItems: PendingImageItem[] = [];
	for (const item of data.items || []) {
		if (imageIds.has(item.id)) continue;
		keptItems.push(foldersToRemove.has(item.folder || "") ? { ...item, folder: "" } : item);
	}
	const nextFolders = (data.folders || []).filter((folder) => !foldersToRemove.has(folder));
	await writePendingData(keptItems, nextFolders);
	await Promise.all([...imageIds].map((id) => rm(globalPendingDir(id), { recursive: true, force: true })));
	return c.json({ ok: true, items: keptItems, folders: await readPendingFolders(keptItems, nextFolders) });
});

app.patch("/api/pending-images/:pendingId", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const payload = await c.req.json();
	const items = await readPendingImages();
	const index = items.findIndex((item) => item.id === pendingId);
	if (index < 0) return c.json({ ok: false, error: "pending image not found" }, 404);
	const name = String(payload.name ?? items[index].name).trim();
	items[index] = {
		...items[index],
		name: name || items[index].name,
		kind: payload.kind ? safePendingImageKind(payload.kind) : items[index].kind,
		folder: payload.folder === undefined ? items[index].folder : safeFolderName(payload.folder),
	};
	await writePendingImages(items);
	return c.json({ ok: true, item: items[index] });
});

app.get("/api/pending-images/:pendingId/source", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const item = (await readPendingImages()).find((candidate) => candidate.id === pendingId);
	if (!item) return c.json({ ok: false, error: "pending image not found" }, 404);
	const target = path.resolve(projectRoot, item.path);
	const bytes = await readFile(target);
	return new Response(bytes, {
		headers: {
			"content-type": contentTypeForFile(target),
			"cache-control": "no-store",
		},
	});
});

app.get("/api/pending-images/:pendingId/processed", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const item = (await readPendingImages()).find((candidate) => candidate.id === pendingId);
	if (!item?.processed_path) return c.json({ ok: false, error: "processed image not found" }, 404);
	const target = path.resolve(projectRoot, item.processed_path);
	const bytes = await readFile(target);
	return new Response(bytes, {
		headers: {
			"content-type": contentTypeForFile(target),
			"cache-control": "no-store",
		},
	});
});

app.post("/api/pending-images/:pendingId/process", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const payload = await c.req.json();
	const steps: ProcessStep[] = Array.isArray(payload.steps) ? payload.steps.map(normalizeProcessStep) : [];
	if (!steps.length) return c.json({ ok: false, error: "processing steps are required" }, 400);
	const items = await readPendingImages();
	const index = items.findIndex((candidate) => candidate.id === pendingId);
	if (index < 0) return c.json({ ok: false, error: "pending image not found" }, 404);
	if (items[index].processed_path) return c.json({ ok: false, error: "confirm or reject current processed image first" }, 400);
	const runnableSteps = steps.filter((step) => canRunPendingStep(items[index], step.type));
	if (!runnableSteps.length) return c.json({ ok: false, error: "no enabled processing steps" }, 400);
	const input = path.resolve(projectRoot, items[index].path);
	const workDir = await mkdtemp(path.join(globalPendingDir(pendingId), "_process-"));
	try {
		const processed = await runImagePipeline(input, workDir, runnableSteps);
		const processedExt = path.extname(processed).toLowerCase();
		const extension = processedExt === ".jpeg" ? ".jpg" : processedExt || imageExtension(processed);
		const finalPath = globalPendingImagePath(pendingId, `processed${extension || ".png"}`);
		const pendingStepTypes = uniqueStepTypes(runnableSteps.map((step) => step.type));
		await copyFile(processed, finalPath);
		items[index] = {
			...items[index],
			processed: true,
			processed_path: path.relative(projectRoot, finalPath),
			processed_url: `/api/pending-images/${pendingId}/processed?mtime=${Date.now()}`,
			processed_info: await imageInfoForPath(finalPath),
			pending_step_types: pendingStepTypes,
			was_processed_before_preview: Boolean(items[index].processed && !items[index].processed_path),
			processed_at: new Date().toISOString(),
		};
		await writePendingImages(items);
		return c.json({ ok: true, item: items[index] });
	} finally {
		await rm(workDir, { recursive: true, force: true });
	}
});

app.post("/api/pending-images/:pendingId/confirm-processed", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const items = await readPendingImages();
	const index = items.findIndex((candidate) => candidate.id === pendingId);
	if (index < 0) return c.json({ ok: false, error: "pending image not found" }, 404);
	const item = items[index];
	if (!item.processed_path) return c.json({ ok: false, error: "processed image not found" }, 404);
	const originalPath = path.resolve(projectRoot, item.path);
	const processedPath = path.resolve(projectRoot, item.processed_path);
	const processedInfo = item.processed_info || (await imageInfoForPath(processedPath));
	const pendingStepTypes = item.pending_step_types || [];
	const appliedStepTypes = uniqueStepTypes([...(item.applied_step_types || []), ...pendingStepTypes.filter((type) => type !== "compress")]);
	const compressionStable = Boolean(item.compression_stable || (pendingStepTypes.includes("compress") && processedInfo.bytes >= item.source_info.bytes));
	if (originalPath !== processedPath) {
		await rm(originalPath, { force: true });
	}
	items[index] = {
		...item,
		path: path.relative(projectRoot, processedPath),
		url: `/api/pending-images/${pendingId}/source?mtime=${Date.now()}`,
		source_info: processedInfo,
		processed: true,
		processed_path: undefined,
		processed_url: undefined,
		processed_info: undefined,
		applied_step_types: appliedStepTypes,
		pending_step_types: undefined,
		was_processed_before_preview: undefined,
		compression_stable: compressionStable,
		processed_at: new Date().toISOString(),
	};
	await writePendingImages(items);
	return c.json({ ok: true, item: items[index] });
});

app.post("/api/pending-images/:pendingId/reject-processed", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const items = await readPendingImages();
	const index = items.findIndex((candidate) => candidate.id === pendingId);
	if (index < 0) return c.json({ ok: false, error: "pending image not found" }, 404);
	const item = items[index];
	if (!item.processed_path) return c.json({ ok: false, error: "processed image not found" }, 404);
	await rm(path.resolve(projectRoot, item.processed_path), { force: true });
	const stillProcessed = Boolean(item.was_processed_before_preview || (item.applied_step_types || []).length || item.compression_stable);
	items[index] = {
		...item,
		processed: stillProcessed,
		processed_path: undefined,
		processed_url: undefined,
		processed_info: undefined,
		pending_step_types: undefined,
		was_processed_before_preview: undefined,
		processed_at: stillProcessed ? item.processed_at : undefined,
	};
	await writePendingImages(items);
	return c.json({ ok: true, item: items[index] });
});

app.delete("/api/pending-images/:pendingId", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const items = await readPendingImages();
	const nextItems = items.filter((item) => item.id !== pendingId);
	await writePendingImages(nextItems);
	await rm(globalPendingDir(pendingId), { recursive: true, force: true });
	return c.json({ ok: true });
});

app.post("/api/pending-images/:pendingId/create-level", async (c) => {
	const pendingId = safeFileName(c.req.param("pendingId"));
	const payload = await c.req.json();
	const imageId = safeFileName(payload.imageId || pendingId);
	const tableclothId = payload.tableclothId ? safeFileName(payload.tableclothId) : "";
	const topicId = safeId(payload.topicId);
	const levelId = safeId(payload.levelId);
	const title = String(payload.title || levelId).trim() || levelId;
	const description = String(payload.description || "").trim();
	const items = await readPendingImages();
	const imageItem = items.find((candidate) => candidate.id === imageId);
	const tableclothItem = tableclothId ? items.find((candidate) => candidate.id === tableclothId) : undefined;
	if (!imageItem) return c.json({ ok: false, error: "pending image not found" }, 404);
	if (imageItem.kind === "tablecloth") return c.json({ ok: false, error: "level image cannot be a tablecloth" }, 400);
	if (imageItem.processed_path) return c.json({ ok: false, error: "confirm processed level image first" }, 400);
	if (tableclothId && !tableclothItem) return c.json({ ok: false, error: "tablecloth image not found" }, 404);
	if (tableclothItem?.processed_path) return c.json({ ok: false, error: "confirm processed tablecloth image first" }, 400);

	const imageInput = path.resolve(projectRoot, imageItem.path);
	const imageExt = normalizedExtension(imageInput);
	const finalName = targetImageFileName("default", imageExt);
	const finalPath = levelAssetPath(topicId, levelId, finalName);
	await mkdir(path.dirname(finalPath), { recursive: true });
	await copyFile(imageInput, finalPath);

	let tableclothFileName = "";
	if (tableclothItem) {
		const tableclothInput = path.resolve(projectRoot, tableclothItem.path);
		tableclothFileName = `tablecloth${normalizedExtension(tableclothInput)}`;
		await copyFile(tableclothInput, levelAssetPath(topicId, levelId, tableclothFileName));
	}

	const level = makeLevelJson(topicId, levelId, title, description, finalName, tableclothFileName);
	await writeJson(levelPath(topicId, levelId), level);
	const catalog = upsertCatalogLevel(await readJson(catalogPath, makeEmptyCatalog()), topicId, levelId, title, finalName);
	await writeJson(catalogPath, catalog);
	const removeIds = new Set([imageId, ...(tableclothId ? [tableclothId] : [])]);
	await writePendingImages(items.filter((candidate) => !removeIds.has(candidate.id)));
	await Promise.all([...removeIds].map((id) => rm(globalPendingDir(id), { recursive: true, force: true })));
	return c.json({
		ok: true,
		level,
		catalog,
		topicId,
		levelId,
		godotPath: `res://levels/${topicId}/${levelId}/${finalName}`,
		url: `/api/levels/${topicId}/${levelId}/assets/${finalName}?mtime=${Date.now()}`,
	});
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
	normalizeLevelImageModes(level, topicId, levelId);
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

app.post("/api/levels/:topicId/:levelId/process-existing-image", async (c) => {
	const topicId = safeId(c.req.param("topicId"));
	const levelId = safeId(c.req.param("levelId"));
	const payload = await c.req.json();
	const target = safeImageTarget(payload.target);
	const source = safeImageTarget(payload.source || payload.target);
	const steps = Array.isArray(payload.steps) ? payload.steps.map(normalizeProcessStep) : [];
	if (!steps.length) return c.json({ ok: false, error: "processing steps are required" }, 400);
	const input = imageTargetPath(topicId, levelId, source);
	const workDir = await mkdtemp(path.join(levelDir(topicId, levelId), "_process-"));
	try {
		const processed = await runImagePipeline(input, workDir, steps);
		const processedExt = path.extname(processed).toLowerCase();
		const extension = processedExt === ".jpeg" ? ".jpg" : processedExt;
		const finalName = targetImageFileName(target, extension || ".png");
		const finalPath = levelAssetPath(topicId, levelId, finalName);
		await copyFile(processed, finalPath);
		const level = await updateLevelImageReference(topicId, levelId, target, finalName);
		let catalog = null;
		if (target === "default") {
			catalog = updateCatalogImage(await readJson(catalogPath, makeEmptyCatalog()), topicId, levelId, finalName);
			await writeJson(catalogPath, catalog);
		}
		return c.json({
			ok: true,
			path: path.relative(projectRoot, finalPath),
			godotPath: `res://levels/${topicId}/${levelId}/${finalName}`,
			url: `/api/levels/${topicId}/${levelId}/assets/${finalName}?mtime=${Date.now()}`,
			level,
			catalog,
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

function topicDir(topicId: string) {
	return safeJoin(levelsDir, topicId);
}

function topicAssetPath(topicId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, safeFileName(fileName));
}

function topicCoverPath(topicId: string, coverPath: string) {
	const prefix = `res://levels/${topicId}/`;
	const fileName = coverPath.startsWith(prefix) ? coverPath.slice(prefix.length) : path.basename(coverPath);
	return topicAssetPath(topicId, fileName || "cover.png");
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

function imageTargetPath(topicId: string, levelId: string, target: "default" | "polygon" | "knob") {
	if (target === "default") return sourcePath(topicId, levelId);
	return modeSourcePath(topicId, levelId, target);
}

function globalPendingDir(pendingId: string) {
	return safeJoin(pendingImagesDir, pendingId);
}

function globalPendingImagePath(pendingId: string, fileName: string) {
	return safeJoin(pendingImagesDir, pendingId, fileName);
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

function safePendingImageKind(value: unknown): PendingImageKind {
	const kind = String(value || "image").trim();
	if (kind !== "image" && kind !== "tablecloth") {
		throw new Error("kind must be image or tablecloth");
	}
	return kind;
}

function safeFolderName(value: unknown) {
	return String(value || "")
		.trim()
		.replace(/[<>:"/\\|?*\u0000-\u001f]/g, "")
		.replace(/\s+/g, " ")
		.slice(0, 64);
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

function normalizedExtension(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpeg") return ".jpg";
	return ext || ".png";
}

function contentTypeForFile(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
	if (ext === ".webp") return "image/webp";
	if (ext === ".svg") return "image/svg+xml";
	return "image/png";
}

type ProcessStep = {
	type: "convert_jpg" | "remove_background" | "trim_transparent" | "compress";
	tolerance?: number;
	padding?: number;
	quality?: number;
	background?: string;
};

function normalizeProcessStep(value: any): ProcessStep {
	const type = String(value?.type || "");
	if (type !== "convert_jpg" && type !== "remove_background" && type !== "trim_transparent" && type !== "compress") {
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

function isProcessStepType(value: unknown): value is ProcessStep["type"] {
	return value === "convert_jpg" || value === "remove_background" || value === "trim_transparent" || value === "compress";
}

function normalizeStepTypeList(value: unknown): ProcessStep["type"][] {
	if (!Array.isArray(value)) return [];
	return uniqueStepTypes(value.filter(isProcessStepType));
}

function uniqueStepTypes(values: ProcessStep["type"][]) {
	return [...new Set(values)];
}

function canRunPendingStep(item: PendingImageItem, type: ProcessStep["type"]) {
	if (type === "compress") return !item.compression_stable;
	return !(item.applied_step_types || []).includes(type);
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

function pythonToolInfo(name: string) {
	const supported: Record<string, { label: string; stepType: ProcessStep["type"]; description: string }> = {
		"convert_to_jpg.py": {
			label: "转 JPG",
			stepType: "convert_jpg",
			description: "用指定底色合成透明区域，并导出 JPG；已是 JPG 时会跳过。",
		},
		"remove_solid_background.py": {
			label: "去背景",
			stepType: "remove_background",
			description: "移除图片周围的纯色背景，适合透明化原图底色。",
		},
		"trim_transparent_image.py": {
			label: "裁透明边",
			stepType: "trim_transparent",
			description: "裁掉透明边缘，并可保留指定像素的留边。",
		},
		"compress_images.py": {
			label: "压缩图片",
			stepType: "compress",
			description: "在保持图片尺寸和透明度的前提下压缩文件。",
		},
	};
	const info = supported[name];
	if (!info) return null;
	return {
		name,
		label: info.label,
		supported: true,
		description: info.description,
		stepType: info.stepType,
	};
}

function readableToolName(name: string) {
	return name.replace(/\.py$/i, "").replace(/_/g, " ");
}

function bodyFiles(value: unknown): File[] {
	if (Array.isArray(value)) return value.filter((item): item is File => item instanceof File);
	return value instanceof File ? [value] : [];
}

function bodyStrings(value: unknown): string[] {
	if (Array.isArray(value)) return value.map((item) => String(item || ""));
	if (value === undefined || value === null) return [];
	return [String(value)];
}

function uniqueStrings(values: string[]) {
	return [...new Set(values.map(safeFolderName).filter(Boolean))];
}

function pendingNameKey(folder: string, name: string) {
	return `${safeFolderName(folder).toLocaleLowerCase()}::${String(name || "").trim().toLocaleLowerCase()}`;
}

type ImageInfo = {
	format: string;
	width: number;
	height: number;
	bytes: number;
};

async function imageInfoForPath(target: string): Promise<ImageInfo> {
	const [fileStat, bytes] = await Promise.all([stat(target), readFile(target)]);
	const size = imageDimensions(bytes);
	return {
		format: imageFormat(target, bytes),
		width: size.width,
		height: size.height,
		bytes: fileStat.size,
	};
}

function imageFormat(fileName: string, bytes: Buffer) {
	const ext = path.extname(fileName).toLowerCase();
	if (bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "PNG";
	if (bytes[0] === 0xff && bytes[1] === 0xd8) return "JPG";
	if (bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") return "WEBP";
	if (ext === ".jpg" || ext === ".jpeg") return "JPG";
	if (ext === ".webp") return "WEBP";
	if (ext === ".png") return "PNG";
	return ext.replace(/^\./, "").toUpperCase() || "UNKNOWN";
}

function imageDimensions(bytes: Buffer) {
	if (bytes.length >= 24 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
		return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
	}
	if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
		const size = jpegDimensions(bytes);
		if (size) return size;
	}
	if (bytes.length >= 30 && bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") {
		const size = webpDimensions(bytes);
		if (size) return size;
	}
	return { width: 0, height: 0 };
}

function jpegDimensions(bytes: Buffer) {
	let offset = 2;
	while (offset + 9 < bytes.length) {
		if (bytes[offset] !== 0xff) {
			offset += 1;
			continue;
		}
		const marker = bytes[offset + 1];
		offset += 2;
		if (marker === 0xd9 || marker === 0xda) break;
		if (offset + 2 > bytes.length) break;
		const length = bytes.readUInt16BE(offset);
		if (length < 2 || offset + length > bytes.length) break;
		if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf)) {
			return { width: bytes.readUInt16BE(offset + 5), height: bytes.readUInt16BE(offset + 3) };
		}
		offset += length;
	}
	return null;
}

function webpDimensions(bytes: Buffer) {
	const type = bytes.toString("ascii", 12, 16);
	if (type === "VP8X" && bytes.length >= 30) {
		return {
			width: 1 + bytes.readUIntLE(24, 3),
			height: 1 + bytes.readUIntLE(27, 3),
		};
	}
	if (type === "VP8L" && bytes.length >= 25) {
		const bits = bytes.readUInt32LE(21);
		return {
			width: (bits & 0x3fff) + 1,
			height: ((bits >> 14) & 0x3fff) + 1,
		};
	}
	if (type === "VP8 " && bytes.length >= 30) {
		return {
			width: bytes.readUInt16LE(26) & 0x3fff,
			height: bytes.readUInt16LE(28) & 0x3fff,
		};
	}
	return null;
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
			if ([".jpg", ".jpeg"].includes(path.extname(current).toLowerCase())) {
				continue;
			}
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
			continue;
		}
		if (step.type === "compress") {
			await execTool("compress_images.py", [
				current,
				"-o",
				outDir,
				"--jpeg-quality",
				String(step.quality ?? 88),
			]);
			current = await outputOrCopied(current, path.join(outDir, parsed.base));
		}
	}
	return current;
}

async function execTool(scriptName: string, args: Array<string>) {
	const script = path.join(toolsDir, scriptName);
	const { stderr } = await execPython([script, ...args.map(String)]);
	if (stderr.trim()) {
		console.warn(`[level-editor-api] ${scriptName}: ${stderr.trim()}`);
	}
}

async function execPython(args: string[]) {
	const defaultCandidates = process.platform === "win32" ? ["python", "python3"] : ["python3", "python"];
	const candidates = [process.env.PYTHON, ...defaultCandidates].filter(Boolean) as string[];
	let lastError: unknown = null;
	for (const command of candidates) {
		try {
			return await execFileAsync(command, args, {
				cwd: projectRoot,
				maxBuffer: 1024 * 1024 * 8,
			});
		} catch (error: any) {
			lastError = error;
			if (error?.code !== "ENOENT") throw error;
		}
	}
	throw lastError || new Error("python executable not found");
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

function normalizeLevelImageModes(level: any, topicId: string, levelId: string) {
	const defaultImage = normalizeDefaultImage(level.assets?.default_image || level.image, topicId, levelId);
	level.image = defaultImage;
	level.assets = {
		...(level.assets || {}),
		default_image: defaultImage,
	};
	level.modes = level.modes || {};
	for (const mode of ["polygon", "knob"] as const) {
		const modeData = level.modes[mode] || {};
		const configured = modeData.image || modeData.source_image;
		const configuredPath = typeof configured === "string" ? configured : configured?.path || "";
		level.modes[mode] = {
			...modeData,
			image: configuredPath ? configured : { use: "default" },
		};
		delete level.modes[mode].source_image;
	}
}

type PendingImageItem = {
	id: string;
	name: string;
	kind: PendingImageKind;
	path: string;
	url: string;
	source_info: ImageInfo;
	processed: boolean;
	processed_path?: string;
	processed_url?: string;
	processed_info?: ImageInfo;
	processed_at?: string;
	applied_step_types?: ProcessStep["type"][];
	pending_step_types?: ProcessStep["type"][];
	compression_stable?: boolean;
	was_processed_before_preview?: boolean;
	folder?: string;
	created_at: string;
};

type PendingImageKind = "image" | "tablecloth";

type PendingImagesData = {
	items: PendingImageItem[];
	folders?: string[];
};

async function readPendingData(): Promise<PendingImagesData> {
	const data = await readJson<{ items?: PendingImageItem[] }>(pendingImagesIndexPath, { items: [] });
	if (!Array.isArray(data.items)) return { items: [], folders: uniqueStrings((data as any).folders || []) };
	const items: PendingImageItem[] = [];
	for (const item of data.items) {
		const sourcePath = path.resolve(projectRoot, String(item.path || ""));
		const processedPath = item.processed_path ? path.resolve(projectRoot, item.processed_path) : "";
		const sourceInfo = item.source_info || (await imageInfoForPath(sourcePath).catch(() => ({ format: "UNKNOWN", width: 0, height: 0, bytes: 0 })));
		const processedInfo = item.processed_info || (processedPath ? await imageInfoForPath(processedPath).catch(() => undefined) : undefined);
		items.push({
				id: safeFileName(item.id),
				name: String(item.name || item.id),
				kind: item.kind === "tablecloth" ? "tablecloth" : "image",
				path: String(item.path || ""),
				url: `/api/pending-images/${safeFileName(item.id)}/source?mtime=${Date.now()}`,
				source_info: sourceInfo,
				processed: Boolean(item.processed || item.processed_path),
				processed_path: item.processed_path ? String(item.processed_path) : undefined,
				processed_url: item.processed_path ? `/api/pending-images/${safeFileName(item.id)}/processed?mtime=${Date.now()}` : undefined,
				processed_info: processedInfo,
				processed_at: item.processed_at ? String(item.processed_at) : undefined,
				applied_step_types: normalizeStepTypeList(item.applied_step_types),
				pending_step_types: normalizeStepTypeList(item.pending_step_types),
				compression_stable: Boolean(item.compression_stable),
				was_processed_before_preview: Boolean(item.was_processed_before_preview),
				folder: safeFolderName(item.folder),
				created_at: String(item.created_at || new Date().toISOString()),
			});
	}
	return { items, folders: uniqueStrings((data as any).folders || []) };
}

async function readPendingImages(): Promise<PendingImageItem[]> {
	return (await readPendingData()).items;
}

async function readPendingFolders(items?: PendingImageItem[], storedFolders?: string[]) {
	const data = items ? { items, folders: storedFolders || [] } : await readPendingData();
	return uniqueStrings([...(data.folders || []), ...data.items.map((item) => item.folder || "")]);
}

async function writePendingImages(items: PendingImageItem[]) {
	const data = await readPendingData();
	await writePendingData(items, data.folders || []);
}

async function writePendingData(items: PendingImageItem[], folders: string[] = []) {
	await writeJson(pendingImagesIndexPath, { schema: "jigsaw.pending-images.v1", version: 1, folders: uniqueStrings(folders), items });
}

function makeLevelJson(topicId: string, levelId: string, title: string, description: string, imageFileName = "source.png", tableclothFileName = "") {
	const image = {
		path: `res://levels/${topicId}/${levelId}/${imageFileName}`,
		name: imageFileName,
		width: 0,
		height: 0,
	};
	const background = tableclothFileName
		? { type: "image", color: "#ead8bd", path: `res://levels/${topicId}/${levelId}/${tableclothFileName}` }
		: { type: "color", color: "#ead8bd", path: "" };
	return {
		schema: "jigsaw.level.v1",
		version: 1,
		id: levelId,
		topic_id: topicId,
		locale: "zh-Hans",
		title,
		description,
		title_i18n: { "zh-Hans": title },
		description_i18n: { "zh-Hans": description },
		image,
		assets: tableclothFileName ? { default_image: image, cover: background.path } : { default_image: image },
		background,
		grid: { cols: 8, rows: 8, piece_size: 190 },
		runtime_layout: {
			coordinate_space: "source_pixels",
			target: "mobile_portrait",
			min_viewport: [360, 640],
			board_margin_ratio: 1,
			hud_height_ratio: 0,
			side_margin_ratio: 0,
			bottom_margin_ratio: 0,
		},
		component_overrides: {},
		modes: {
			polygon: { source: "precomputed", image: { use: "default" }, pieces: [] },
			knob: { source: "precomputed", image: { use: "default" }, cols: 8, rows: 8, piece_size: 190, knob_size: 0.24, pieces: [] },
		},
		editor: { outline: [], cuts: [], shapes: [], pieces: [] },
	};
}

function upsertCatalogLevel(catalog: any, topicId: string, levelId: string, title: string, imageFileName = "source.png") {
	const normalized = normalizeCatalog(catalog);
	const level = {
		id: levelId,
		title,
		title_i18n: { "zh-Hans": title },
		sort_order: 0,
		path: `res://levels/${topicId}/${levelId}/level.json`,
		source: `res://levels/${topicId}/${levelId}/${imageFileName}`,
	};
	const topicIndex = normalized.topics.findIndex((topic: any) => topic.id === topicId);
	if (topicIndex < 0) {
		normalized.topics.push({
			id: topicId,
			name: topicId,
			name_i18n: { "zh-Hans": topicId },
			sort_order: normalized.topics.length,
			cover: "",
			levels: [{ ...level, sort_order: 0 }],
		});
		return normalizeCatalog(normalized);
	}
	const topic = normalized.topics[topicIndex];
	const existingIndex = topic.levels.findIndex((item: any) => item.id === levelId);
	if (existingIndex >= 0) {
		topic.levels[existingIndex] = { ...topic.levels[existingIndex], ...level, sort_order: topic.levels[existingIndex].sort_order };
	} else {
		topic.levels.push({ ...level, sort_order: topic.levels.length });
	}
	return normalizeCatalog(normalized);
}

function updateCatalogTopicCover(catalog: any, topicId: string, imageFileName: string) {
	const normalized = normalizeCatalog(catalog);
	const topic = normalized.topics.find((item: any) => item.id === topicId);
	if (topic) topic.cover = `res://levels/${topicId}/${imageFileName}`;
	return normalized;
}

async function updateLevelImageReference(topicId: string, levelId: string, target: "default" | "polygon" | "knob", imageFileName: string) {
	const targetPath = levelPath(topicId, levelId);
	const level = await readJson<any>(targetPath, makeLevelJson(topicId, levelId, levelId, "", imageFileName));
	const image = {
		path: `res://levels/${topicId}/${levelId}/${imageFileName}`,
		name: imageFileName,
		width: Number(level.image?.width || level.assets?.default_image?.width || 0),
		height: Number(level.image?.height || level.assets?.default_image?.height || 0),
	};
	if (target === "default") {
		level.image = { ...(level.image || {}), ...image };
		level.assets = { ...(level.assets || {}), default_image: { ...(level.assets?.default_image || {}), ...image } };
	} else {
		level.modes = level.modes || {};
		level.modes[target] = { ...(level.modes[target] || {}), image };
		delete level.modes[target].source_image;
	}
	await writeJson(targetPath, level);
	return level;
}

function updateCatalogImage(catalog: any, topicId: string, levelId: string, imageFileName: string) {
	const normalized = normalizeCatalog(catalog);
	const topic = normalized.topics.find((item: any) => item.id === topicId);
	const level = topic?.levels.find((item: any) => item.id === levelId);
	if (level) level.source = `res://levels/${topicId}/${levelId}/${imageFileName}`;
	return normalizeCatalog(normalized);
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
