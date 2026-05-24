import { copyFile, mkdir } from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";
import { catalogPath, projectRoot } from "../config/paths.js";
import { makeEmptyCatalog, upsertCatalogLevel } from "../catalog/service.js";
import { imageInfoForPath } from "../image/probe.js";
import { normalizedExtension, targetImageFileName } from "../lib/http-body.js";
import { readJson, writeJson } from "../lib/fs-json.js";
import { safeFileName, safeId, safeMode } from "../lib/sanitize.js";
import { makeLevelJson, normalizeLevelForModeSave, normalizeLevelImageModes } from "../level/service.js";
import { levelAssetPath, levelPath } from "../paths/levels.js";
import { readPendingImages, writePendingImages } from "../pending/store.js";

function imagePathFromValue(value: any) {
	if (typeof value === "string") return value;
	if (value && typeof value === "object") return String(value.path || "");
	return "";
}

export function registerEditorRoutes(app: Hono) {
	app.post("/api/editor/save-mode", async (c) => {
		const payload = await c.req.json();
		const topicId = safeId(payload.topicId);
		const levelId = safeId(payload.levelId);
		const mode = safeMode(payload.mode);
		const imageId = safeFileName(payload.imageId);
		const title = String(payload.title ?? "").trim();
		const description = String(payload.description ?? "").trim();
		const topicName = String(payload.topicName ?? "").trim();
		const incomingLevel = payload.level || {};
		const items = await readPendingImages();
		const imageItem = items.find((candidate) => candidate.id === imageId);
		if (!imageItem) return c.json({ ok: false, error: "pending image not found" }, 404);
		if (imageItem.processed_path) return c.json({ ok: false, error: "confirm processed image first" }, 400);

		const sharedModes = (["polygon", "knob"] as const).filter((candidate) => {
			if (candidate === mode) return true;
			const candidateImage = incomingLevel.modes?.[candidate]?.image;
			return imagePathFromValue(candidateImage) === imageItem.path;
		});
		const input = path.resolve(projectRoot, imageItem.path);
		const extension = normalizedExtension(input);
		const finalName = targetImageFileName(sharedModes.length > 1 ? "default" : mode, extension);
		const finalPath = levelAssetPath(topicId, levelId, finalName);
		await mkdir(path.dirname(finalPath), { recursive: true });
		await copyFile(input, finalPath);
		const imageInfo = await imageInfoForPath(finalPath);
		const modeImage = {
			path: `res://levels/${topicId}/${levelId}/${finalName}`,
			name: finalName,
			width: imageInfo.width,
			height: imageInfo.height,
		};

		const existingLevel = await readJson<any>(levelPath(topicId, levelId), makeLevelJson(topicId, levelId, title, description, finalName));
		normalizeLevelImageModes(existingLevel, topicId, levelId);
		const nextLevel = normalizeLevelForModeSave(existingLevel, incomingLevel, topicId, levelId, mode, modeImage, title, description, sharedModes);
		await writeJson(levelPath(topicId, levelId), nextLevel);

		const catalog = upsertCatalogLevel(await readJson(catalogPath, makeEmptyCatalog()), topicId, levelId, title, finalName, topicName);
		await writeJson(catalogPath, catalog);
		const savedModeSet = new Set([...(imageItem.saved_modes || []), ...sharedModes]);
		await writePendingImages(items.map((item) => {
			if (item.id !== imageItem.id) return item;
			const editorState = { ...(item.editor_state || {}) };
			for (const savedMode of sharedModes) {
				editorState[savedMode] = {
					...(editorState[savedMode] || {}),
					dirty: false,
					completed: true,
					saved: true,
					analysis_dirty: false,
				};
			}
			return { ...item, saved_modes: [...savedModeSet], editor_state: editorState };
		}));
		return c.json({
			ok: true,
			level: nextLevel,
			catalog,
			topicId,
			levelId,
			image: modeImage,
			sharedModes,
			path: path.relative(projectRoot, levelPath(topicId, levelId)),
			godotPath: modeImage.path,
			url: `/api/levels/${topicId}/${levelId}/assets/${finalName}?mtime=${Date.now()}`,
		});
	});
}
