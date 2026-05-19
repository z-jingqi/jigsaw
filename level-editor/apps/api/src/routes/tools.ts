import { readdir } from "node:fs/promises";
import type { Hono } from "hono";
import { toolsDir } from "../config/paths.js";
import { pythonToolInfo } from "../image/python-tools.js";

export function registerToolsRoutes(app: Hono) {
	app.get("/api/python-tools", async (c) => {
		const entries = await readdir(toolsDir, { withFileTypes: true });
		const tools = entries
			.filter((entry) => entry.isFile() && entry.name.endsWith(".py"))
			.map((entry) => pythonToolInfo(entry.name))
			.filter((tool) => tool !== null)
			.sort((a, b) => Number(b.supported) - Number(a.supported) || a.name.localeCompare(b.name));
		return c.json({ ok: true, tools });
	});
}
