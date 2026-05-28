import { copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";
import { projectRoot } from "../config/paths.js";
import { canRunPendingStep, normalizeProcessStep, uniqueStepTypes } from "../image/pipeline.js";
import { imageInfoForPath } from "../image/probe.js";
import { bodyFiles, bodyStrings, contentTypeForFile, imageExtension } from "../lib/http-body.js";
import { safeFileName, safeFolderName, safePendingImageKind, safeStem } from "../lib/sanitize.js";
import { pendingNameKey, uniqueStrings } from "../lib/strings.js";
import { globalPendingDir, globalPendingImagePath } from "../paths/pending.js";
import {
	readPendingData,
	readPendingFolders,
	readPendingImage,
	readPendingImages,
	writePendingData,
	writePendingImage,
	writePendingImages,
} from "../pending/store.js";
import type { PendingImageItem } from "../types/pending.js";
import type { ProcessStep } from "../types/process.js";
import { runImagePipeline } from "../image/pipeline.js";

export function registerPendingImageRoutes(app: Hono) {
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
			const name = path.basename(file.name || "source.png");
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

	app.patch("/api/pending-images/:pendingId/editor-state", async (c) => {
		const pendingId = safeFileName(c.req.param("pendingId"));
		const payload = await c.req.json();
		// 仅读写单张图片的 JSON 文件，避免每次编辑都重写整个图片库索引。
		const item = await readPendingImage(pendingId);
		if (!item) return c.json({ ok: false, error: "pending image not found" }, 404);
		const next: PendingImageItem = { ...item, editor_state: normalizePendingEditorState(payload.editor_state) };
		await writePendingImage(next);
		return c.json({ ok: true, item: next });
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
			url: `/api/pending-images/${pendingId}/source?mtime=${Date.now()}`,
			source_info: await imageInfoForPath(path.resolve(projectRoot, item.path)),
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
}

function normalizePendingEditorState(value: any) {
	const state = value && typeof value === "object" ? value : {};
	return {
		polygon: normalizePendingEditorModeState(state.polygon, false),
		knob: normalizePendingEditorModeState(state.knob, true),
		swap: normalizePendingEditorModeState(state.swap, false),
	};
}

function normalizePendingEditorModeState(value: any, knob: boolean) {
	const state = value && typeof value === "object" ? value : {};
	return {
		dirty: Boolean(state.dirty),
		completed: Boolean(state.completed),
		saved: Boolean(state.saved),
		cuts: knob ? [] : Array.isArray(state.cuts) ? state.cuts : [],
		pieces: knob ? [] : Array.isArray(state.pieces) ? state.pieces : [],
		knob_pieces: knob && Array.isArray(state.knob_pieces) ? state.knob_pieces : [],
		analysis_dirty: Boolean(state.analysis_dirty),
	};
}
