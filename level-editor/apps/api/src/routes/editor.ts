import type { Hono } from "hono";

export function registerEditorRoutes(app: Hono) {
	app.post("/api/editor/save-mode", (c) =>
		c.json({
			ok: false,
			error: "Mode data is now saved through the simplified catalog export flow.",
		}, 410),
	);
}
