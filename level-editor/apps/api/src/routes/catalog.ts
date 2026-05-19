import path from "node:path";
import type { Hono } from "hono";
import { catalogPath, projectRoot } from "../config/paths.js";
import { makeEmptyCatalog, normalizeCatalog } from "../catalog/service.js";
import { readJson, writeJson } from "../lib/fs-json.js";

export function registerCatalogRoutes(app: Hono) {
	app.get("/api/catalog", async (c) => {
		const catalog = await readJson(catalogPath, makeEmptyCatalog());
		return c.json(catalog);
	});

	app.post("/api/catalog", async (c) => {
		const catalog = await c.req.json();
		await writeJson(catalogPath, normalizeCatalog(catalog));
		return c.json({ ok: true, path: path.relative(projectRoot, catalogPath) });
	});
}
