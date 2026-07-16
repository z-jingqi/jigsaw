import type { CatalogRenameOperation, LevelCatalog, LevelConfig, LevelStatus, SelectedLevel, TinyPieceAuditResponse } from "./types";

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: init?.body instanceof FormData ? init.headers : { "Content-Type": "application/json", ...(init?.headers || {}) },
  });
  if (!response.ok) {
    let message = response.statusText;
    try {
      message = (await response.json()).error || message;
    } catch {
      // ignore
    }
    throw new Error(message);
  }
  return response.json() as Promise<T>;
}

export function loadCatalog() {
  return request<{ catalog: LevelCatalog; statuses: LevelStatus[] }>("/api/catalog");
}

export function saveCatalog(catalog: LevelCatalog, renames: CatalogRenameOperation[] = []) {
  return request<{ catalog: LevelCatalog; statuses: LevelStatus[] }>("/api/catalog", {
    method: "PUT",
    body: JSON.stringify({ catalog, renames }),
  });
}

export function loadLevel(target: { topicId: string; groupId: string; levelId: string }) {
  return request<LevelConfig>(`/api/levels/${target.topicId}/${target.groupId}/${target.levelId}`);
}

export function auditTinyPieces(levels: SelectedLevel[]) {
  return request<TinyPieceAuditResponse>("/api/audits/tiny-pieces", {
    method: "POST",
    body: JSON.stringify({ levels }),
  });
}

export function saveLevel(config: LevelConfig) {
  return request<LevelConfig>(`/api/levels/${config.topic_id}/${config.group_id}/${config.id}`, {
    method: "PUT",
    body: JSON.stringify(config),
  });
}

export function uploadSource(target: { topicId: string; groupId: string; levelId: string }, file: File) {
  const body = new FormData();
  body.append("file", file);
  return request<LevelConfig>(`/api/levels/${target.topicId}/${target.groupId}/${target.levelId}/source`, {
    method: "POST",
    body,
  });
}

export function uploadTopicAsset(topicId: string, asset: "cover" | "icon", file: File) {
  const body = new FormData();
  body.append("file", file);
  return request<{ path: string }>(`/api/topics/${topicId}/${asset}`, {
    method: "POST",
    body,
  });
}

export function sourceUrl(target: { topicId: string; groupId: string; levelId: string }) {
  return `/api/levels/${target.topicId}/${target.groupId}/${target.levelId}/source?mtime=${Date.now()}`;
}

export function assetUrl(path: string) {
  if (!path) return "";
  return `${path.replace("res://levels/", "/levels/")}?mtime=${Date.now()}`;
}
