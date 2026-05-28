import path from "node:path";

export function imageExtension(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpg" || ext === ".jpeg") return ".jpg";
	if (ext === ".webp") return ".webp";
	return ".png";
}

export function normalizedExtension(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpeg") return ".jpg";
	return ext || ".png";
}

export function contentTypeForFile(fileName: string) {
	const ext = path.extname(fileName).toLowerCase();
	if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
	if (ext === ".webp") return "image/webp";
	if (ext === ".svg") return "image/svg+xml";
	return "image/png";
}

export function bodyFiles(value: unknown): File[] {
	if (Array.isArray(value)) return value.filter((item): item is File => item instanceof File);
	return value instanceof File ? [value] : [];
}

export function bodyStrings(value: unknown): string[] {
	if (Array.isArray(value)) return value.map((item) => String(item || ""));
	if (value === undefined || value === null) return [];
	return [String(value)];
}

export function targetImageFileName(target: "default" | "polygon" | "knob" | "swap", extension: string) {
	const ext = extension === ".jpeg" ? ".jpg" : extension || ".png";
	if (target === "default") return `source${ext}`;
	return `${target}_source${ext}`;
}
