import { pendingImagesDir } from "../config/paths.js";
import { safeJoin } from "../lib/sanitize.js";

export function globalPendingDir(pendingId: string) {
	return safeJoin(pendingImagesDir, pendingId);
}

export function globalPendingImagePath(pendingId: string, fileName: string) {
	return safeJoin(pendingImagesDir, pendingId, fileName);
}
