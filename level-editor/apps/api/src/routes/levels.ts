import { copyFile, mkdir, readFile, rm } from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";
import { catalogPath, projectRoot } from "../config/paths.js";
import { makeEmptyCatalog, normalizeCatalog } from "../catalog/service.js";
import { imageInfoForPath } from "../image/probe.js";
import { contentTypeForFile } from "../lib/http-body.js";
import { readJson, writeJson } from "../lib/fs-json.js";
import { safeFileName } from "../lib/sanitize.js";
import { levelAssetPath, levelDir, levelPath, sourcePath } from "../paths/levels.js";
import { readPendingImage } from "../pending/store.js";
import { makeLevelJson, normalizeLevelJson } from "../level/service.js";

export function registerLevelRoutes(app: Hono) {
	app.get("/api/levels/:topicId/:groupId/:levelId", async (c) => {
		const { topicId, groupId, levelId } = safeParams(c.req.param());
		const target = levelPath(topicId, groupId, levelId);
		const data = await readJson(target, makeLevelJson(topicId, groupId, levelId, levelId));
		return c.json(normalizeLevelJson(data, topicId, groupId, levelId));
	});

	app.post("/api/levels/:topicId/:groupId/:levelId", async (c) => {
		const { topicId, groupId, levelId } = safeParams(c.req.param());
		const payload = await c.req.json();
		const dir = levelDir(topicId, groupId, levelId);
		await mkdir(dir, { recursive: true });

		let imageInfo = payload.level?.image || {};
		if (payload.sourcePendingId) {
			const pending = await readPendingImage(String(payload.sourcePendingId));
			if (!pending) return c.json({ ok: false, error: "source image not found" }, 404);
			const sourceFile = path.resolve(projectRoot, pending.path);
			const targetSource = sourcePath(topicId, groupId, levelId);
			await copyFile(sourceFile, targetSource);
			const info = await imageInfoForPath(targetSource);
			imageInfo = {
				path: `res://levels/${topicId}/${groupId}/${levelId}/source.jpg`,
				width: info.width,
				height: info.height,
				aspect_ratio: info.width && info.height ? info.width / info.height : 0.75,
				preset: "mobile_portrait_3x4",
			};
		}

		const nextLevel = normalizeLevelJson(
			{
				...(payload.level || {}),
				image: {
					...(payload.level?.image || {}),
					...imageInfo,
					path: `res://levels/${topicId}/${groupId}/${levelId}/source.jpg`,
				},
			},
			topicId,
			groupId,
			levelId,
		);
		await writeJson(levelPath(topicId, groupId, levelId), nextLevel);
		if (payload.catalog) {
			await writeJson(catalogPath, normalizeCatalog(payload.catalog));
		}
		return c.json({ ok: true, level: nextLevel, path: path.relative(projectRoot, levelPath(topicId, groupId, levelId)) });
	});

	app.post("/api/levels/cleanup", async (c) => {
		const payload = await c.req.json().catch(() => ({}));
		const removed = Array.isArray(payload.removed) ? payload.removed : [];
		await Promise.all(
			removed.map((item: any) => {
				const topicId = safeFileName(item.topicId || "");
				const groupId = safeFileName(item.groupId || "");
				const levelId = safeFileName(item.levelId || "");
				return topicId && groupId && levelId ? rm(levelDir(topicId, groupId, levelId), { recursive: true, force: true }) : Promise.resolve();
			}),
		);
		return c.json({ ok: true });
	});

	app.get("/api/levels/:topicId/:groupId/:levelId/source", async (c) => {
		const { topicId, groupId, levelId } = safeParams(c.req.param());
		const bytes = await readFile(sourcePath(topicId, groupId, levelId));
		return new Response(bytes, { headers: { "content-type": "image/jpeg", "cache-control": "no-store" } });
	});

	app.get("/api/levels/:topicId/:groupId/:levelId/assets/:fileName", async (c) => {
		const { topicId, groupId, levelId } = safeParams(c.req.param());
		const fileName = safeFileName(c.req.param("fileName"));
		const target = levelAssetPath(topicId, groupId, levelId, fileName);
		const bytes = await readFile(target);
		return new Response(bytes, { headers: { "content-type": contentTypeForFile(target), "cache-control": "no-store" } });
	});
}

function safeParams(params: Record<string, string>) {
	return {
		topicId: safeFileName(params.topicId || ""),
		groupId: safeFileName(params.groupId || ""),
		levelId: safeFileName(params.levelId || ""),
	};
}
