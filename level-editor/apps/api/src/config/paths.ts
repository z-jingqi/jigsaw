import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);

export const editorRoot = path.resolve(path.dirname(__filename), "../../../..");
export const projectRoot = path.resolve(editorRoot, "..");
export const levelsDir = path.join(projectRoot, "levels");
export const catalogPath = path.join(levelsDir, "catalog.json");
export const pendingDataDir = path.join(editorRoot, "data", "pending");
export const pendingImagesDir = path.join(pendingDataDir, "images");
export const pendingImagesIndexPath = path.join(pendingDataDir, "images.json");
export const toolsDir = path.join(projectRoot, "tools");
export const port = Number(process.env.LEVEL_EDITOR_API_PORT || 5174);
export const googleDriveFolderMime = "application/vnd.google-apps.folder";
