import { copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";
import { catalogPath } from "../config/paths.js";
import { makeEmptyCatalog, normalizeCatalog, updateCatalogTopicCover } from "../catalog/service.js";
import { runImagePipeline, normalizeProcessStep } from "../image/pipeline.js";
import { contentTypeForFile, imageExtension } from "../lib/http-body.js";
import { readJson, writeJson } from "../lib/fs-json.js";
import { safeFileName, safeId } from "../lib/sanitize.js";
import { topicAssetPath, topicCoverPath, topicDir } from "../paths/levels.js";

export function registerTopicRoutes(app: Hono) {
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
}
