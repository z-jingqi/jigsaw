import path from "node:path";
import { levelsDir } from "../config/paths.js";
import { safeFileName, safeJoin } from "../lib/sanitize.js";

export function levelPath(topicId: string, groupId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, groupId, levelId, "level.json");
}

export function topicDir(topicId: string) {
	return safeJoin(levelsDir, topicId);
}

export function groupDir(topicId: string, groupId: string) {
	return safeJoin(levelsDir, topicId, groupId);
}

export function topicAssetPath(topicId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, safeFileName(fileName));
}

export function topicCoverPath(topicId: string, coverPath: string) {
	const prefix = `res://levels/${topicId}/`;
	const fileName = coverPath.startsWith(prefix) ? coverPath.slice(prefix.length) : path.basename(coverPath);
	return topicAssetPath(topicId, fileName || "cover.jpg");
}

export function levelDir(topicId: string, groupId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, groupId, levelId);
}

export function sourcePath(topicId: string, groupId: string, levelId: string) {
	return safeJoin(levelsDir, topicId, groupId, levelId, "source.jpg");
}

export function levelAssetPath(topicId: string, groupId: string, levelId: string, fileName: string) {
	return safeJoin(levelsDir, topicId, groupId, levelId, safeFileName(fileName));
}

export function godotLevelDir(topicId: string, groupId: string, levelId: string) {
	return `res://levels/${topicId}/${groupId}/${levelId}`;
}
