import type { CatalogRenameOperation, LevelCatalog, LevelConfig, LevelStatus } from "./types";

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

export function sourceUrl(target: { topicId: string; groupId: string; levelId: string }) {
  return `/api/levels/${target.topicId}/${target.groupId}/${target.levelId}/source?mtime=${Date.now()}`;
}
