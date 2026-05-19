import { safeFolderName } from "./sanitize.js";

export function clampInt(value: unknown, min: number, max: number, fallback: number) {
	const parsed = Number(value);
	if (!Number.isFinite(parsed)) return fallback;
	return Math.max(min, Math.min(max, Math.round(parsed)));
}

export function uniqueStrings(values: string[]) {
	return [...new Set(values.map(safeFolderName).filter(Boolean))];
}

export function pendingNameKey(folder: string, name: string) {
	return `${safeFolderName(folder).toLocaleLowerCase()}::${String(name || "").trim().toLocaleLowerCase()}`;
}

export function withReservedI18n(value: Record<string, string>, primary: string) {
	return {
		...value,
		"zh-cn": value["zh-cn"] ?? primary,
	};
}
