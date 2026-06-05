import { mkdir, readdir, rm } from "node:fs/promises";
import path from "node:path";
import { pendingIndexPath, pendingItemsDir, projectRoot } from "../config/paths.js";
import { imageInfoForPath } from "../image/probe.js";
import { readJson, writeJson } from "../lib/fs-json.js";
import { safeFileName, safeFolderName } from "../lib/sanitize.js";
import { uniqueStrings } from "../lib/strings.js";
import { normalizeStepTypeList } from "../image/pipeline.js";
import type { PendingImageItem, PendingImagesData } from "../types/pending.js";

const PENDING_INDEX_SCHEMA = "jigsaw.pending-images.v3";

type PendingIndex = {
	folders: string[];
	ids: string[];
};

function pendingItemFilePath(id: string) {
	return path.join(pendingItemsDir, `${id}.json`);
}

async function readPendingIndex(): Promise<PendingIndex> {
	const data = await readJson<{ folders?: string[]; ids?: string[] } | null>(pendingIndexPath, null);
	if (!data) return { folders: [], ids: [] };
	return {
		folders: uniqueStrings(Array.isArray(data.folders) ? data.folders : []),
		ids: Array.isArray(data.ids) ? data.ids.filter((id): id is string => typeof id === "string" && Boolean(id)) : [],
	};
}

async function writePendingIndex(index: PendingIndex) {
	await writeJson(pendingIndexPath, {
		schema: PENDING_INDEX_SCHEMA,
		version: 2,
		folders: uniqueStrings(index.folders),
		ids: index.ids,
	});
}

async function readRawItem(id: string): Promise<PendingImageItem | null> {
	return await readJson<PendingImageItem | null>(pendingItemFilePath(id), null);
}

async function writeRawItem(item: PendingImageItem) {
	await mkdir(pendingItemsDir, { recursive: true });
	await writeJson(pendingItemFilePath(item.id), item);
}

async function deleteRawItem(id: string) {
	await rm(pendingItemFilePath(id), { force: true });
}

async function loadAllItems(): Promise<{ items: PendingImageItem[]; folders: string[] }> {
	const index = await readPendingIndex();
	const items = (await Promise.all(index.ids.map((id) => readRawItem(id)))).filter(
		(item): item is PendingImageItem => Boolean(item),
	);
	return { items, folders: index.folders };
}

async function normalizeItem(item: PendingImageItem): Promise<PendingImageItem> {
	const id = safeFileName(item.id);
	const sourcePath = path.resolve(projectRoot, String(item.path || ""));
	const processedPath = item.processed_path ? path.resolve(projectRoot, item.processed_path) : "";
	const sourceInfo =
		item.source_info ||
		(await imageInfoForPath(sourcePath).catch(() => ({ format: "UNKNOWN", width: 0, height: 0, bytes: 0 })));
	const processedInfo =
		item.processed_info || (processedPath ? await imageInfoForPath(processedPath).catch(() => undefined) : undefined);
	return {
		id,
		name: String(item.name || id),
		kind: item.kind === "tablecloth" ? "tablecloth" : "image",
		path: String(item.path || ""),
		url: `/api/pending-images/${id}/source?mtime=${Date.now()}`,
		source_info: sourceInfo,
		processed: Boolean(item.processed || item.processed_path),
		processed_path: item.processed_path ? String(item.processed_path) : undefined,
		processed_url: item.processed_path ? `/api/pending-images/${id}/processed?mtime=${Date.now()}` : undefined,
		processed_info: processedInfo,
		processed_at: item.processed_at ? String(item.processed_at) : undefined,
		applied_step_types: normalizeStepTypeList(item.applied_step_types),
		pending_step_types: normalizeStepTypeList(item.pending_step_types),
		compression_stable: Boolean(item.compression_stable),
		was_processed_before_preview: Boolean(item.was_processed_before_preview),
		folder: safeFolderName(item.folder),
		created_at: String(item.created_at || new Date().toISOString()),
	};
}

export async function readPendingData(): Promise<PendingImagesData> {
	const { items: rawItems, folders } = await loadAllItems();
	const items: PendingImageItem[] = [];
	for (const raw of rawItems) {
		items.push(await normalizeItem(raw));
	}
	return { items, folders: uniqueStrings(folders) };
}

export async function readPendingImages(): Promise<PendingImageItem[]> {
	return (await readPendingData()).items;
}

export async function readPendingFolders(items?: PendingImageItem[], storedFolders?: string[]) {
	const data = items ? { items, folders: storedFolders || [] } : await readPendingData();
	return uniqueStrings([...(data.folders || []), ...data.items.map((item) => item.folder || "")]);
}

export async function readPendingImage(id: string): Promise<PendingImageItem | null> {
	const safeId = safeFileName(id);
	if (!safeId) return null;
	const raw = await readRawItem(safeId);
	if (!raw) return null;
	return await normalizeItem(raw);
}

/** 仅写入单张图片的 JSON 文件，不重写整个索引；若 id 是新加入的会自动加入索引。 */
export async function writePendingImage(item: PendingImageItem) {
	const safeItem = { ...item, id: safeFileName(item.id) };
	if (!safeItem.id) throw new Error("pending image id is required");
	await writeRawItem(safeItem);
	const index = await readPendingIndex();
	if (!index.ids.includes(safeItem.id)) {
		await writePendingIndex({ folders: index.folders, ids: [...index.ids, safeItem.id] });
	}
}

export async function writePendingImages(items: PendingImageItem[]) {
	const data = await readPendingData();
	await writePendingData(items, data.folders || []);
}

/** 全量替换：用 items 列表覆盖现有数据，文件夹列表跟随更新；不再使用的 item 文件会被删除。 */
export async function writePendingData(items: PendingImageItem[], folders: string[] = []) {
	await mkdir(pendingItemsDir, { recursive: true });
	const existingFiles = await readdir(pendingItemsDir).catch(() => [] as string[]);
	const existingIds = new Set(
		existingFiles.filter((file) => file.endsWith(".json")).map((file) => file.slice(0, -".json".length)),
	);
	const newIds = items.map((item) => safeFileName(item.id)).filter(Boolean);
	const newIdSet = new Set(newIds);
	await Promise.all(
		[...existingIds].filter((id) => !newIdSet.has(id)).map((id) => deleteRawItem(id)),
	);
	await Promise.all(items.map((item) => writeRawItem({ ...item, id: safeFileName(item.id) })));
	await writePendingIndex({ folders: uniqueStrings(folders), ids: newIds });
}
