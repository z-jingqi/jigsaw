import { useEffect, useState } from "react";
import LevelEditorPage from "./pages/LevelEditorPage";
import ImagePipelinePage, { type ImagePipelineSelectionState } from "./pages/ImagePipelinePage";
import CatalogManagementPage from "./pages/CatalogManagementPage";
import type { LevelCatalog } from "./types";

type Route = "/editor" | "/images" | "/catalog";

function routeFromPath(): Route {
  if (window.location.pathname.startsWith("/catalog")) return "/catalog";
  return window.location.pathname.startsWith("/images") ? "/images" : "/editor";
}

function nextSequentialId(prefix: string, existingIds: string[]): string {
  const used = new Set(existingIds);
  for (let index = 1; index < 10000; index += 1) {
    const id = `${prefix}_${String(index).padStart(2, "0")}`;
    if (!used.has(id)) return id;
  }
  return `${prefix}_${Date.now().toString(36)}`;
}

function App() {
  const [route, setRoute] = useState<Route>(() => routeFromPath());
  const [imageSelection, setImageSelection] = useState<ImagePipelineSelectionState | null>(null);
  const [pendingRoute, setPendingRoute] = useState<Route | null>(null);
  const [creatingLevel, setCreatingLevel] = useState(false);
  const [navMessage, setNavMessage] = useState("");

  useEffect(() => {
    const onPopState = () => {
      const nextRoute = routeFromPath();
      if (route === "/images" && nextRoute !== "/images" && imageSelection?.hasUnconfirmed) {
        window.history.pushState({}, "", "/images");
        setPendingRoute(nextRoute);
        return;
      }
      setRoute(nextRoute);
    };
    window.addEventListener("popstate", onPopState);
    if (window.location.pathname === "/") {
      window.history.replaceState({}, "", "/editor");
      setRoute("/editor");
    }
    return () => window.removeEventListener("popstate", onPopState);
  }, [imageSelection?.hasUnconfirmed, route]);

  function navigate(nextRoute: Route, url: string = nextRoute) {
    if (nextRoute === route) return;
    if (route === "/images" && nextRoute !== "/images" && imageSelection?.hasUnconfirmed) {
      setPendingRoute(nextRoute);
      return;
    }
    window.history.pushState({}, "", url);
    setRoute(nextRoute);
  }

  async function createLevelFromCurrentImage() {
    if (route !== "/images") {
      navigate("/images");
      return;
    }
    if (!imageSelection) {
      setNavMessage("请先选择一张关卡图片。");
      return;
    }
    if (imageSelection.kind === "tablecloth") {
      setNavMessage("桌布不能直接创建关卡，请选择关卡图片。");
      return;
    }
    if (imageSelection.status === "待确认") {
      setNavMessage("请先确认或放弃当前处理结果，再创建关卡。");
      return;
    }
    setCreatingLevel(true);
    setNavMessage("");
    try {
      const catalogResponse = await fetch("/api/catalog");
      if (!catalogResponse.ok) throw new Error(`HTTP ${catalogResponse.status}`);
      const catalog = (await catalogResponse.json()) as LevelCatalog;
      const topic = catalog.topics[0];
      const topicId = topic?.id || "topic_01";
      const levelId = nextSequentialId("level", topic?.levels.map((level) => level.id) || []);
      const response = await fetch(`/api/pending-images/${imageSelection.id}/create-level`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          imageId: imageSelection.id,
          topicId,
          levelId,
          title: imageSelection.name,
          description: "",
        }),
      });
      const data = (await response.json()) as { ok?: boolean; topicId?: string; levelId?: string; error?: string };
      if (!response.ok || !data.ok || !data.topicId || !data.levelId) throw new Error(data.error || `HTTP ${response.status}`);
      const editorUrl = `/editor?topic=${encodeURIComponent(data.topicId)}&level=${encodeURIComponent(data.levelId)}`;
      window.history.pushState({}, "", editorUrl);
      setRoute("/editor");
    } catch (error) {
      setNavMessage(error instanceof Error ? `创建关卡失败：${error.message}` : "创建关卡失败");
    } finally {
      setCreatingLevel(false);
    }
  }

  function confirmRouteChange() {
    const nextRoute = pendingRoute;
    setPendingRoute(null);
    if (!nextRoute) return;
    window.history.pushState({}, "", nextRoute);
    setRoute(nextRoute);
  }

  return (
    <>
      <div className="fixed bottom-5 right-5 z-[80] grid justify-items-end gap-1">
        <button
          className="rounded-md border border-stone-300 bg-white/95 px-4 py-2 text-sm font-medium text-ink shadow-lg transition hover:border-clay hover:text-clay"
          disabled={creatingLevel}
          onClick={() => {
            if (route === "/editor") navigate("/catalog");
            else if (route === "/catalog") navigate("/editor");
            else void createLevelFromCurrentImage();
          }}
        >
          {route === "/editor" ? "目录管理" : route === "/catalog" ? "返回编辑器" : creatingLevel ? "创建中..." : "创建关卡"}
        </button>
        {route === "/images" && imageSelection && (
          <div className="flex max-w-56 items-center gap-2 rounded-md border border-stone-300 bg-white/95 px-2 py-1 text-[12px] text-muted shadow-sm">
            <span className="min-w-0 truncate">{imageSelection.name}</span>
            <span
              className={`shrink-0 rounded px-1.5 py-0.5 font-medium ${
                imageSelection.status === "待确认" ? "bg-amber-100 text-amber-700" : imageSelection.status === "已处理" ? "bg-emerald-100 text-emerald-700" : "bg-stone-100 text-muted"
              }`}
            >
              {imageSelection.status}
            </span>
          </div>
        )}
        {route === "/images" && navMessage && <div className="max-w-56 rounded-md border border-amber-200 bg-amber-50 px-2 py-1 text-[12px] text-amber-700 shadow-sm">{navMessage}</div>}
      </div>
      {route === "/images" ? <ImagePipelinePage onSelectionStateChange={setImageSelection} /> : route === "/catalog" ? <CatalogManagementPage /> : <LevelEditorPage />}
      {pendingRoute && (
        <div className="fixed inset-0 z-[90] grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-lg font-semibold">当前处理结果尚未确认</h2>
            <p className="mt-2 text-sm text-muted">离开图片处理页前，建议先确认或放弃当前处理结果。继续离开会保留待确认状态。</p>
            <div className="mt-5 grid grid-cols-2 gap-2">
              <button className="btn" onClick={() => setPendingRoute(null)}>
                留在当前
              </button>
              <button className="btnPrimary" onClick={confirmRouteChange}>
                继续离开
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

export default App;
