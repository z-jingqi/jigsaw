import path from "node:path";
import { fileURLToPath } from "node:url";

const apiDir = path.dirname(fileURLToPath(import.meta.url));
export const repoRoot = path.resolve(apiDir, "../../../..");
export const levelsRoot = path.join(repoRoot, "levels");
export const catalogPath = path.join(levelsRoot, "catalog.json");

export function topicDir(topicId: string) {
  return path.join(levelsRoot, topicId);
}

export function groupDir(topicId: string, groupId: string) {
  return path.join(levelsRoot, topicId, groupId);
}

export function levelDir(topicId: string, groupId: string, levelId: string) {
  return path.join(groupDir(topicId, groupId), levelId);
}

export function levelJsonPath(topicId: string, groupId: string, levelId: string) {
  return path.join(levelDir(topicId, groupId, levelId), "level.json");
}

export function sourceImagePath(topicId: string, groupId: string, levelId: string) {
  return path.join(levelDir(topicId, groupId, levelId), "source.jpg");
}

export function sourceResPath(topicId: string, groupId: string, levelId: string) {
  return `res://levels/${topicId}/${groupId}/${levelId}/source.jpg`;
}

export function levelResPath(topicId: string, groupId: string, levelId: string) {
  return `res://levels/${topicId}/${groupId}/${levelId}/level.json`;
}
