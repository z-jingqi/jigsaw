import type { LevelCatalog } from "../../types";
import { fetchJson, postJson } from "./client";

export function fetchCatalog() {
  return fetchJson<LevelCatalog>("/api/catalog");
}

export function saveCatalog(catalog: LevelCatalog) {
  return postJson<{ ok?: boolean; path?: string; error?: string }>("/api/catalog", catalog);
}
