import path from "node:path";
import { levelsDir } from "../config/paths.js";
import { safeFileName, safeJoin } from "../lib/sanitize.js";

export function levelPath(topicId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, levelId, "level.json");
}

export function topicDir(topicId: string) {
	return safeJoin(levelsDir, topicId);
}

export function topicAssetPath(topicId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, safeFileName(fileName));
}

export function topicCoverPath(topicId: string, coverPath: string) {
	const prefix = `res://levels/${topicId}/`;
	const fileName = coverPath.startsWith(prefix) ? coverPath.slice(prefix.length) : path.basename(coverPath);
	return topicAssetPath(topicId, fileName || "cover.png");
}

export function levelDir(topicId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, levelId);
}

export function sourcePath(topicId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, levelId, "source.png");
}

export function levelAssetPath(topicId: string, levelId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, levelId, fileName);
}
