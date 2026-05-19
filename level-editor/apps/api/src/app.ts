import { Hono } from "hono";
import { cors } from "hono/cors";
import { registerCatalogRoutes } from "./routes/catalog.js";
import { registerEditorRoutes } from "./routes/editor.js";
import { registerGoogleDriveRoutes } from "./routes/google-drive.js";
import { registerHealthRoutes } from "./routes/health.js";
import { registerLevelRoutes } from "./routes/levels.js";
import { registerPendingFolderRoutes } from "./routes/pending-folders.js";
import { registerPendingImageRoutes } from "./routes/pending-images.js";
import { registerToolsRoutes } from "./routes/tools.js";
import { registerTopicRoutes } from "./routes/topics.js";

export const app = new Hono();

app.onError((error, c) => {
	console.error("[level-editor-api]", error);
	return c.json({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
});

app.use(
	"/api/*",
	cors({
		origin: ["http://127.0.0.1:5173", "http://localhost:5173"],
		allowHeaders: ["content-type"],
		allowMethods: ["GET", "POST", "PATCH", "OPTIONS"],
	}),
);

registerHealthRoutes(app);
registerToolsRoutes(app);
registerCatalogRoutes(app);
registerTopicRoutes(app);
registerPendingImageRoutes(app);
registerPendingFolderRoutes(app);
registerGoogleDriveRoutes(app);
registerEditorRoutes(app);
registerLevelRoutes(app);
