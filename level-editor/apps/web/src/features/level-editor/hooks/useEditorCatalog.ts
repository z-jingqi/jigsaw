import { useCallback, useState } from "react";
import { toast } from "sonner";
import type { LevelCatalog } from "../../../types";
import { makeDefaultCatalog, normalizeOrder } from "../../../shared/lib/catalog";

export type EditorCatalogState = {
  catalog: LevelCatalog;
  setCatalog: React.Dispatch<React.SetStateAction<LevelCatalog>>;
  loadCatalog: () => Promise<LevelCatalog | null>;
  persistCatalog: (next: LevelCatalog, announce?: boolean) => Promise<boolean>;
};

function showToast(message: string) {
  toast(message);
}

export function useEditorCatalog(): EditorCatalogState {
  const [catalog, setCatalog] = useState<LevelCatalog>(() => makeDefaultCatalog());

  const loadCatalog = useCallback(async (): Promise<LevelCatalog | null> => {
    try {
      const response = await fetch("/api/catalog");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const next = (await response.json()) as LevelCatalog;
      const normalized: LevelCatalog = {
        ...makeDefaultCatalog(),
        ...next,
        topics: normalizeOrder([...(next.topics || [])].map((topic) => ({ ...topic, levels: normalizeOrder([...(topic.levels || [])]) }))),
      };
      setCatalog(normalized);
      return normalized;
    } catch (error) {
      showToast(error instanceof Error ? `加载 catalog 失败：${error.message}` : "加载 catalog 失败");
      return null;
    }
  }, []);

  const persistCatalog = useCallback(async (next: LevelCatalog, announce = false): Promise<boolean> => {
    if (announce) showToast("保存关卡...");
    try {
      const response = await fetch("/api/catalog", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(next),
      });
      const result = (await response.json()) as { ok?: boolean; path?: string; error?: string };
      if (!response.ok || !result.ok) throw new Error(result.error || `HTTP ${response.status}`);
      if (announce) showToast(`关卡已保存到 ${result.path}`);
      return true;
    } catch (error) {
      showToast(error instanceof Error ? `保存关卡失败：${error.message}` : "保存关卡失败");
      return false;
    }
  }, []);

  return { catalog, setCatalog, loadCatalog, persistCatalog };
}
