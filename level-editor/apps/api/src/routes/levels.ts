import { copyFile, readdir, readFile, rm } from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";
import { catalogPath, projectRoot } from "../config/paths.js";
import { makeEmptyCatalog, normalizeCatalog } from "../catalog/service.js";
import { contentTypeForFile } from "../lib/http-body.js";
import { readJson, writeJson } from "../lib/fs-json.js";
import { safeFileName, safeId } from "../lib/sanitize.js";
import { normalizeLevelImageModes } from "../level/service.js";
import { levelAssetPath, levelDir, levelPath, sourcePath, topicDir } from "../paths/levels.js";

function levelFileNameFromGodotPath(value: unknown, topicId: string, levelId: string) {
	const pathValue = typeof value === "string" ? value : value && typeof value === "object" ? String((value as { path?: string }).path || "") : "";
	const prefix = `res://levels/${topicId}/${levelId}/`;
	if (!pathValue.startsWith(prefix)) return "";
	return safeFileName(path.basename(pathValue.slice(prefix.length)));
}

function collectReferencedLevelFiles(value: unknown, topicId: string, levelId: string, files = new Set<string>()) {
	const fileName = levelFileNameFromGodotPath(value, topicId, levelId);
	if (fileName) files.add(fileName);
	if (Array.isArray(value)) {
		for (const item of value) collectReferencedLevelFiles(item, topicId, levelId, files);
	} else if (value && typeof value === "object") {
		for (const item of Object.values(value)) collectReferencedLevelFiles(item, topicId, levelId, files);
	}
	return files;
}

function replaceSharedImagePath(value: unknown, oldPath: string, nextPath: string, nextName: string): unknown {
	if (typeof value === "string") return value === oldPath ? nextPath : value;
	if (Array.isArray(value)) return value.map((item) => replaceSharedImagePath(item, oldPath, nextPath, nextName));
	if (value && typeof value === "object") {
		for (const [key, item] of Object.entries(value)) {
			(value as Record<string, unknown>)[key] = key === "name" && (value as { path?: string }).path === nextPath ? nextName : replaceSharedImagePath(item, oldPath, nextPath, nextName);
		}
	}
	return value;
}

async function normalizeSharedModeImage(level: any, topicId: string, levelId: string) {
	const polygonPath = typeof level.modes?.polygon?.image === "string" ? level.modes.polygon.image : String(level.modes?.polygon?.image?.path || "");
	const knobPath = typeof level.modes?.knob?.image === "string" ? level.modes.knob.image : String(level.modes?.knob?.image?.path || "");
	if (!polygonPath || polygonPath !== knobPath) return;
	const currentName = levelFileNameFromGodotPath(polygonPath, topicId, levelId);
	const match = currentName.match(/^(?:polygon_source|knob_source)\.(png|jpe?g|webp)$/i);
	if (!match) return;
	const nextName = `source.${match[1].toLowerCase() === "jpeg" ? "jpg" : match[1].toLowerCase()}`;
	const nextPath = `res://levels/${topicId}/${levelId}/${nextName}`;
	await copyFile(levelAssetPath(topicId, levelId, currentName), levelAssetPath(topicId, levelId, nextName)).catch(() => undefined);
	replaceSharedImagePath(level, polygonPath, nextPath, nextName);
}

async function cleanupUnreferencedLevelImages(level: unknown, topicId: string, levelId: string) {
	const referencedFiles = collectReferencedLevelFiles(level, topicId, levelId);
	const dir = levelDir(topicId, levelId);
	const entries = await readdir(dir, { withFileTypes: true }).catch(() => []);
	const removableSourceFile = /^(source|polygon_source|knob_source)\.(png|jpe?g|webp)$/i;
	await Promise.all(
		entries
			.filter((entry) => entry.isFile())
			.filter((entry) => {
				const sourceName = entry.name.endsWith(".import") ? entry.name.slice(0, -".import".length) : entry.name;
				return removableSourceFile.test(sourceName) && !referencedFiles.has(sourceName);
			})
			.map((entry) => rm(levelAssetPath(topicId, levelId, entry.name), { force: true })),
	);
}

export function registerLevelRoutes(app: Hono) {
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
		await normalizeSharedModeImage(level, topicId, levelId);
		await writeJson(target, level);
		await cleanupUnreferencedLevelImages(level, topicId, levelId);
		const catalog = normalizeCatalog(payload.catalog ?? (await readJson(catalogPath, makeEmptyCatalog())));
		await writeJson(catalogPath, catalog);
		return c.json({ ok: true, path: path.relative(projectRoot, target), catalogPath: path.relative(projectRoot, catalogPath) });
	});

	app.post("/api/levels/cleanup", async (c) => {
		const payload = await c.req.json();
		const removedTopics = Array.isArray(payload.removedTopics) ? payload.removedTopics.map((topicId: string) => safeId(topicId)).filter(Boolean) : [];
		const removedLevels = Array.isArray(payload.removedLevels)
			? payload.removedLevels
					.map((target: any) => ({ topicId: safeId(target?.topicId), levelId: safeId(target?.levelId) }))
					.filter((target: any) => target.topicId && target.levelId && !removedTopics.includes(target.topicId))
			: [];
		await Promise.all(removedLevels.map((target: any) => rm(levelDir(target.topicId, target.levelId), { recursive: true, force: true })));
		await Promise.all(removedTopics.map((topicId: string) => rm(topicDir(topicId), { recursive: true, force: true })));
		return c.json({ ok: true, removedTopics, removedLevels });
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
}
