import type { Hono } from "hono";
import { safeFolderName } from "../lib/sanitize.js";
import { uniqueStrings } from "../lib/strings.js";
import { readPendingData, readPendingFolders, writePendingData } from "../pending/store.js";

export function registerPendingFolderRoutes(app: Hono) {
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
}
