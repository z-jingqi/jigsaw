import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import type { Hono } from "hono";
import { googleDriveFolderMime, projectRoot } from "../config/paths.js";
import { driveFileMetadata, driveFileUrl, driveFolderImageFiles, isDriveImageMime } from "../drive/client.js";
import { imageInfoForPath } from "../image/probe.js";
import { imageExtension } from "../lib/http-body.js";
import { safeDriveFileName, safeFolderName, safePendingImageKind, safeStem } from "../lib/sanitize.js";
import { pendingNameKey, uniqueStrings } from "../lib/strings.js";
import { globalPendingImagePath } from "../paths/pending.js";
import { readPendingData, writePendingData } from "../pending/store.js";
import type { PendingImageItem } from "../types/pending.js";

export function registerGoogleDriveRoutes(app: Hono) {
	app.post("/api/google-drive/import", async (c) => {
		const payload = await c.req.json();
		const accessToken = String(payload.accessToken || "").trim();
		const kind = safePendingImageKind(payload.kind);
		const files = Array.isArray(payload.files) ? payload.files : [];
		if (!accessToken) return c.json({ ok: false, error: "Google Drive access token is required" }, 400);
		if (!files.length) return c.json({ ok: false, error: "files are required" }, 400);

		const existingData = await readPendingData();
		const usedNames = new Set(existingData.items.map((item) => pendingNameKey(item.folder || "", item.name)));
		const created: PendingImageItem[] = [];
		const skipped: Array<{ name: string; folder: string; reason: string }> = [];
		const candidates: Array<{ id: string; name: string; folder: string; mimeType?: string }> = [];

		for (const [index, file] of files.entries()) {
			const fileId = String(file?.id || "").trim();
			const fallbackName = file?.name || `drive-${index}.png`;
			const metadata = fileId ? await driveFileMetadata(accessToken, fileId).catch(() => null) : null;
			const name = safeDriveFileName(metadata?.name || fallbackName);
			const mimeType = String(metadata?.mimeType || file?.mimeType || "").trim();
			let folder = safeFolderName(file?.folder || "");
			if (!fileId) {
				skipped.push({ name, folder, reason: "missing_file_id" });
				continue;
			}
			if (mimeType === googleDriveFolderMime) {
				const folderName = safeFolderName(metadata?.name || fallbackName);
				const children = await driveFolderImageFiles(accessToken, fileId).catch((error) => {
					skipped.push({
						name: folderName || fallbackName,
						folder: folderName,
						reason: error instanceof Error ? `folder_list_failed:${error.message}` : "folder_list_failed",
					});
					return [];
				});
				if (!children.length) {
					if (!skipped.some((item) => item.name === (folderName || fallbackName) && item.folder === folderName && item.reason.startsWith("folder_list_failed"))) {
						skipped.push({ name: folderName || fallbackName, folder: folderName, reason: "folder_has_no_images" });
					}
					continue;
				}
				for (const child of children) {
					candidates.push({
						id: String(child.id || ""),
						name: safeDriveFileName(child.name || "drive-image.png"),
						folder: folderName,
						mimeType: child.mimeType,
					});
				}
				continue;
			}
			if (!isDriveImageMime(mimeType)) {
				skipped.push({ name, folder, reason: "unsupported_mime" });
				continue;
			}
			if (!folder && metadata?.parents?.[0]) {
				const parent = await driveFileMetadata(accessToken, metadata.parents[0], "id,name").catch(() => null);
				folder = safeFolderName(parent?.name || "");
			}
			candidates.push({ id: fileId, name, folder, mimeType });
		}

		for (const [index, file] of candidates.entries()) {
			const fileId = file.id;
			const name = file.name;
			const folder = file.folder;
			const nameKey = pendingNameKey(folder, name);
			if (usedNames.has(nameKey)) {
				skipped.push({ name, folder, reason: "duplicate_name" });
				continue;
			}
			usedNames.add(nameKey);
			const response = await fetch(driveFileUrl(fileId, { alt: "media" }), {
				headers: { authorization: `Bearer ${accessToken}` },
			});
			if (!response.ok) {
				skipped.push({ name, folder, reason: `drive_http_${response.status}` });
				continue;
			}
			const bytes = Buffer.from(await response.arrayBuffer());
			const extension = imageExtension(name);
			const id = `${Date.now()}-${index}-${safeStem(name)}`;
			const target = globalPendingImagePath(id, `original${extension}`);
			await mkdir(path.dirname(target), { recursive: true });
			await writeFile(target, bytes);
			created.push({
				id,
				name,
				kind,
				path: path.relative(projectRoot, target),
				url: `/api/pending-images/${id}/source?mtime=${Date.now()}`,
				source_info: await imageInfoForPath(target),
				processed: false,
				folder,
				created_at: new Date().toISOString(),
			});
		}

		const items = [...created, ...existingData.items.filter((existing) => !created.some((item) => item.id === existing.id))];
		await writePendingData(items, uniqueStrings([...(existingData.folders || []), ...created.map((item) => item.folder || "")]));
		return c.json({ ok: true, items: created, skipped, skipped_count: skipped.length });
	});
}
