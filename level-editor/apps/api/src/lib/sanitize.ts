import path from "node:path";
import type { PendingImageKind } from "../types/pending.js";

export function safeJoin(root: string, ...parts: string[]) {
	const target = path.resolve(root, ...parts);
	if (!target.startsWith(`${path.resolve(root)}${path.sep}`)) {
		throw new Error("refusing to access outside levels directory");
	}
	return target;
}

export function safeId(value: unknown) {
	const id = String(value || "").trim();
	if (!/^[a-zA-Z0-9_-]+$/.test(id)) {
		throw new Error("id must contain only letters, numbers, underscore, or dash");
	}
	return id;
}

export function safeMode(value: unknown): "polygon" | "knob" | "swap" {
	const mode = String(value || "").trim();
	if (mode !== "polygon" && mode !== "knob" && mode !== "swap") {
		throw new Error("mode must be polygon, knob, or swap");
	}
	return mode;
}

export function safePendingImageKind(value: unknown): PendingImageKind {
	const kind = String(value || "image").trim();
	if (kind !== "image" && kind !== "tablecloth") {
		throw new Error("kind must be image or tablecloth");
	}
	return kind;
}

export function safeFolderName(value: unknown) {
	return String(value || "")
		.trim()
		.replace(/[<>:"/\\|?*\u0000-\u001f]/g, "")
		.replace(/\s+/g, " ")
		.slice(0, 64);
}

export function safeFileName(value: unknown) {
	const fileName = path.basename(String(value || "").trim());
	if (!/^[a-zA-Z0-9_.-]+$/.test(fileName)) {
		throw new Error("file name must contain only letters, numbers, dash, underscore, or dot");
	}
	return fileName;
}

export function safeDriveFileName(value: unknown) {
	const fileName = path.basename(String(value || "drive-image.png").trim());
	const parsed = path.parse(fileName);
	const stem = parsed.name.replace(/[^a-zA-Z0-9_.-]+/g, "-").replace(/^-+|-+$/g, "") || "drive-image";
	const ext = safeImageExtension(fileName);
	return `${stem}${ext}`;
}

export function safeStem(value: unknown) {
	const fileName = path.basename(String(value || "source").trim());
	const stem = path.parse(fileName).name.replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/^-+|-+$/g, "");
	return stem || "source";
}

export function safeColor(value: unknown) {
	const color = String(value || "").trim();
	if (!/^#[0-9a-fA-F]{6}$/.test(color)) return "#F6EBD4";
	return color;
}

function safeImageExtension(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpg" || ext === ".jpeg") return ".jpg";
	if (ext === ".webp") return ".webp";
	return ".png";
}
