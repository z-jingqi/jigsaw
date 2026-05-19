import { serve } from "@hono/node-server";
import { app } from "./app.js";
import { levelsDir, port } from "./config/paths.js";

serve({ fetch: app.fetch, hostname: "127.0.0.1", port }, (info) => {
	console.log(`[level-editor-api] http://${info.address}:${info.port}`);
	console.log(`[level-editor-api] writing levels to ${levelsDir}`);
});
