import path from "node:path";
import { pendingImagesIndexPath, projectRoot } from "../config/paths.js";
import { imageInfoForPath } from "../image/probe.js";
import { readJson, writeJson } from "../lib/fs-json.js";
import { safeFileName, safeFolderName } from "../lib/sanitize.js";
import { uniqueStrings } from "../lib/strings.js";
import { normalizeStepTypeList } from "../image/pipeline.js";
import type { PendingImageItem, PendingImagesData } from "../types/pending.js";

export async function readPendingData(): Promise<PendingImagesData> {
	const data = await readJson<{ items?: PendingImageItem[]; folders?: string[] }>(pendingImagesIndexPath, { items: [] });
	if (!Array.isArray(data.items)) return { items: [], folders: uniqueStrings((data as any).folders || []) };
	const items: PendingImageItem[] = [];
	for (const item of data.items) {
		const sourcePath = path.resolve(projectRoot, String(item.path || ""));
		const processedPath = item.processed_path ? path.resolve(projectRoot, item.processed_path) : "";
		const sourceInfo = item.source_info || (await imageInfoForPath(sourcePath).catch(() => ({ format: "UNKNOWN", width: 0, height: 0, bytes: 0 })));
		const processedInfo = item.processed_info || (processedPath ? await imageInfoForPath(processedPath).catch(() => undefined) : undefined);
		items.push({
			id: safeFileName(item.id),
			name: String(item.name || item.id),
			kind: item.kind === "tablecloth" ? "tablecloth" : "image",
			path: String(item.path || ""),
			url: `/api/pending-images/${safeFileName(item.id)}/source?mtime=${Date.now()}`,
			source_info: sourceInfo,
			processed: Boolean(item.processed || item.processed_path),
			processed_path: item.processed_path ? String(item.processed_path) : undefined,
			processed_url: item.processed_path ? `/api/pending-images/${safeFileName(item.id)}/processed?mtime=${Date.now()}` : undefined,
			processed_info: processedInfo,
			processed_at: item.processed_at ? String(item.processed_at) : undefined,
			applied_step_types: normalizeStepTypeList(item.applied_step_types),
			pending_step_types: normalizeStepTypeList(item.pending_step_types),
			compression_stable: Boolean(item.compression_stable),
			was_processed_before_preview: Boolean(item.was_processed_before_preview),
			folder: safeFolderName(item.folder),
			created_at: String(item.created_at || new Date().toISOString()),
		});
	}
	return { items, folders: uniqueStrings((data as any).folders || []) };
}

export async function readPendingImages(): Promise<PendingImageItem[]> {
	return (await readPendingData()).items;
}

export async function readPendingFolders(items?: PendingImageItem[], storedFolders?: string[]) {
	const data = items ? { items, folders: storedFolders || [] } : await readPendingData();
	return uniqueStrings([...(data.folders || []), ...data.items.map((item) => item.folder || "")]);
}

export async function writePendingImages(items: PendingImageItem[]) {
	const data = await readPendingData();
	await writePendingData(items, data.folders || []);
}

export async function writePendingData(items: PendingImageItem[], folders: string[] = []) {
	await writeJson(pendingImagesIndexPath, { schema: "jigsaw.pending-images.v1", version: 1, folders: uniqueStrings(folders), items });
}
