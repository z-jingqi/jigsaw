export async function driveFileMetadata(accessToken: string, fileId: string, fields = "id,name,parents,mimeType") {
	const response = await fetch(driveFileUrl(fileId, { fields }), {
		headers: { authorization: `Bearer ${accessToken}` },
	});
	if (!response.ok) throw new Error(await driveHttpError(response, "metadata"));
	return (await response.json()) as { id?: string; name?: string; parents?: string[]; mimeType?: string };
}

export async function driveFolderImageFiles(accessToken: string, folderId: string) {
	const files: Array<{ id?: string; name?: string; parents?: string[]; mimeType?: string }> = [];
	let pageToken = "";
	do {
		const params = new URLSearchParams({
			includeItemsFromAllDrives: "true",
			supportsAllDrives: "true",
			fields: "nextPageToken,files(id,name,parents,mimeType)",
			pageSize: "1000",
			q: `'${folderId.replace(/'/g, "\\'")}' in parents and trashed = false`,
		});
		if (pageToken) params.set("pageToken", pageToken);
		const response = await fetch(`https://www.googleapis.com/drive/v3/files?${params.toString()}`, {
			headers: { authorization: `Bearer ${accessToken}` },
		});
		if (!response.ok) throw new Error(await driveHttpError(response, "folder"));
		const data = (await response.json()) as {
			nextPageToken?: string;
			files?: Array<{ id?: string; name?: string; parents?: string[]; mimeType?: string }>;
		};
		files.push(...(data.files || []).filter(isDriveImageFile));
		pageToken = data.nextPageToken || "";
	} while (pageToken);
	return files;
}

async function driveHttpError(response: Response, operation: string) {
	let reason = "";
	try {
		const data = await response.json() as { error?: { message?: string; errors?: Array<{ reason?: string; message?: string }> } };
		reason = data.error?.errors?.[0]?.reason || data.error?.message || "";
	} catch {
		reason = await response.text().catch(() => "");
	}
	const detail = reason ? `:${String(reason).slice(0, 180)}` : "";
	return `Drive ${operation} HTTP ${response.status}${detail}`;
}

export function driveFileUrl(fileId: string, params: Record<string, string>) {
	const query = new URLSearchParams({ supportsAllDrives: "true", ...params });
	return `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}?${query.toString()}`;
}

function isDriveImageFile(file: { id?: string; name?: string; mimeType?: string }) {
	return Boolean(file.id && (isDriveImageMime(file.mimeType) || isImageFileName(file.name)));
}

export function isDriveImageMime(mimeType: unknown) {
	return String(mimeType || "").startsWith("image/");
}

function isImageFileName(name: unknown) {
	return /\.(png|jpe?g|webp|gif|svg)$/i.test(String(name || ""));
}
