import path from "node:path";
import type { Hono } from "hono";
import { levelsDir, projectRoot } from "../config/paths.js";

export function registerHealthRoutes(app: Hono) {
	app.get("/api/health", (c) => c.json({ ok: true, levelsDir: path.relative(projectRoot, levelsDir) }));
}
