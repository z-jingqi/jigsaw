import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function serveRepoAssets(): Plugin {
  return {
    name: "serve-jigcat-repo-assets",
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const requestPath = decodeURIComponent((req.url ?? "").split("?")[0] ?? "");
        if (!requestPath.startsWith("/levels/") && !requestPath.startsWith("/assets/")) {
          next();
          return;
        }
        const filePath = path.resolve(repoRoot, `.${requestPath}`);
        if (!filePath.startsWith(repoRoot) || !fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
          next();
          return;
        }
        res.setHeader("Cache-Control", "no-cache");
        res.setHeader("Content-Type", contentType(filePath));
        fs.createReadStream(filePath).pipe(res);
      });
    }
  };
}

function contentType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".json") return "application/json; charset=utf-8";
  if (ext === ".png") return "image/png";
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".svg") return "image/svg+xml";
  if (ext === ".webp") return "image/webp";
  return "application/octet-stream";
}

export default defineConfig({
  plugins: [react(), serveRepoAssets()],
  server: {
    host: "127.0.0.1",
    port: 5180,
    fs: {
      allow: [repoRoot]
    }
  },
  preview: {
    host: "127.0.0.1",
    port: 5180
  }
});
