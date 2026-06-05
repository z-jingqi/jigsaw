import { useEffect, useState } from "react";
import { toast } from "sonner";
import LevelEditorPage from "./pages/LevelEditorPage";
import ImagePipelinePage, { type ImagePipelineSelectionState } from "./pages/ImagePipelinePage";
import CatalogManagementPage from "./pages/CatalogManagementPage";
import { Toaster } from "./components/ui/sonner";
import { TooltipProvider } from "./components/ui/tooltip";

type Route = "/editor" | "/images" | "/catalog";
type EditLevelModeTarget = {
  topicId: string;
  groupId: string;
  levelId: string;
  mode: "polygon" | "knob" | "swap";
};

type NavigationGuardState = {
  dirty: boolean;
  title: string;
  message: string;
};

type PendingNavigation = {
  route: Route;
  url: string;
};

function routeFromPath(): Route {
  if (window.location.pathname.startsWith("/catalog")) return "/catalog";
  return window.location.pathname.startsWith("/images") ? "/images" : "/editor";
}

function currentUrlForRoute(route: Route) {
  if (routeFromPath() === route) return `${window.location.pathname}${window.location.search}`;
  return route;
}

function routeLabel(route: Route) {
  if (route === "/editor") return "编辑";
  if (route === "/catalog") return "关卡";
  return "图片处理";
}

const navItems: Route[] = ["/images", "/editor", "/catalog"];

function App() {
  const [route, setRoute] = useState<Route>(() => routeFromPath());
  const [imageSelection, setImageSelection] = useState<ImagePipelineSelectionState | null>(null);
  const [pendingNavigation, setPendingNavigation] = useState<PendingNavigation | null>(null);
  const [openingEditor, setOpeningEditor] = useState(false);
  const [editorDirty, setEditorDirty] = useState(false);
  const [catalogDirty, setCatalogDirty] = useState(false);

  const imageDirty = Boolean(imageSelection?.hasUnconfirmed);
  const guardByRoute: Record<Route, NavigationGuardState> = {
    "/editor": {
      dirty: editorDirty,
      title: "当前关卡还没有保存",
      message: "离开编辑器前，建议先保存当前关卡。继续离开会保留页面状态，但未保存内容可能在刷新后丢失。",
    },
    "/images": {
      dirty: imageDirty,
      title: "当前处理结果尚未确认",
      message: "离开图片处理页前，建议先确认或放弃当前处理结果。继续离开会保留待确认状态。",
    },
    "/catalog": {
      dirty: catalogDirty,
      title: "关卡改动还没有保存",
      message: "离开关卡页前，建议先保存到 Godot。继续离开会保留页面状态，但未保存内容可能在刷新后丢失。",
    },
  };
  const activeGuard = guardByRoute[route];

  useEffect(() => {
    const onPopState = () => {
      const nextRoute = routeFromPath();
      if (nextRoute !== route && activeGuard.dirty) {
        window.history.pushState({}, "", currentUrlForRoute(route));
        setPendingNavigation({ route: nextRoute, url: currentUrlForRoute(nextRoute) });
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
  }, [activeGuard.dirty, route]);

  useEffect(() => {
    const hasUnsavedState = editorDirty || catalogDirty || imageDirty;
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (!hasUnsavedState) return;
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [catalogDirty, editorDirty, imageDirty]);

  function navigate(nextRoute: Route, url: string = nextRoute) {
    if (nextRoute === route) return;
    if (activeGuard.dirty) {
      setPendingNavigation({ route: nextRoute, url });
      return;
    }
    window.history.pushState({}, "", url);
    setRoute(nextRoute);
  }

  function editCurrentImage() {
    if (route !== "/images") {
      navigate("/images");
      return;
    }
    if (!imageSelection) {
      toast.warning("请先选择一张关卡图片。");
      return;
    }
    if (imageSelection.status === "待确认") {
      toast.warning("请先确认或放弃当前处理结果，再进入编辑器。");
      return;
    }
    setOpeningEditor(true);
    const editorUrl = `/editor?image=${encodeURIComponent(imageSelection.id)}&mode=polygon`;
    window.history.pushState({}, "", editorUrl);
    setRoute("/editor");
    window.setTimeout(() => setOpeningEditor(false), 0);
  }

  function editLevelMode(target: EditLevelModeTarget) {
    const editorUrl = `/editor?topic=${encodeURIComponent(target.topicId)}&group=${encodeURIComponent(target.groupId)}&level=${encodeURIComponent(target.levelId)}&mode=${encodeURIComponent(target.mode)}`;
    navigate("/editor", editorUrl);
  }

  function confirmRouteChange() {
    const next = pendingNavigation;
    setPendingNavigation(null);
    if (!next) return;
    window.history.pushState({}, "", next.url);
    setRoute(next.route);
  }

  return (
    <>
      <TooltipProvider delayDuration={250}>
      <div className="grid h-screen min-h-0 grid-rows-[64px_1fr] bg-linen text-ink">
        <header className="z-[80] grid min-w-0 grid-cols-[1fr_auto_1fr] items-center gap-4 border-b border-[#dec8a5] bg-[#fff7e8]/95 px-5 shadow-[0_2px_12px_rgba(90,58,34,0.08)] backdrop-blur">
          <div className="flex min-w-0 items-center gap-3">
            <div className="grid h-9 w-9 place-items-center rounded-xl bg-clay text-sm font-bold text-white shadow-sm">J</div>
            <div className="min-w-0">
              <div className="truncate text-sm font-semibold text-ink">jigcat level editor</div>
              <div className="text-[11px] text-muted">图片 - 编辑 - 关卡</div>
            </div>
            {activeGuard.dirty && <span className="rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-medium text-amber-700">未保存</span>}
          </div>
          <nav className="flex shrink-0 items-center gap-1 rounded-full border border-[#dec8a5] bg-white/80 p-1 shadow-inner">
            {navItems.map((item, index) => (
              <button
                key={item}
                className={`flex min-h-9 items-center gap-2 rounded-full px-4 text-sm font-semibold transition ${
                  route === item ? "bg-clay text-white shadow-sm" : "text-muted hover:bg-linen hover:text-ink"
                }`}
                disabled={openingEditor}
                onClick={() => navigate(item)}
              >
                <span className={`grid h-5 w-5 place-items-center rounded-full text-[11px] ${route === item ? "bg-white/20" : "bg-[#f6ebd4]"}`}>{index + 1}</span>
                {routeLabel(item)}
              </button>
            ))}
          </nav>
          <div className="ml-auto flex min-w-0 items-center justify-end gap-2">
            {route === "/images" && imageSelection && (
              <div className="flex min-w-0 max-w-[360px] items-center gap-2 rounded-md border border-stone-300 bg-white px-2 py-1 text-xs text-muted">
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
            {route === "/images" && (
              <button className="btnPrimary" disabled={openingEditor} onClick={editCurrentImage}>
                {openingEditor ? "打开中..." : "去编辑"}
              </button>
            )}
          </div>
        </header>
        <main className="min-h-0 overflow-hidden">
          {route === "/images" ? (
            <ImagePipelinePage onSelectionStateChange={setImageSelection} />
          ) : route === "/catalog" ? (
            <CatalogManagementPage onUnsavedChange={setCatalogDirty} onEditLevelMode={editLevelMode} />
          ) : (
            <LevelEditorPage onUnsavedChange={setEditorDirty} />
          )}
        </main>
      </div>
      {pendingNavigation && (
        <div className="fixed inset-0 z-[90] grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-lg font-semibold">{activeGuard.title}</h2>
            <p className="mt-2 text-sm text-muted">{activeGuard.message}</p>
            <div className="mt-5 grid grid-cols-2 gap-2">
              <button className="btn" onClick={() => setPendingNavigation(null)}>
                留在当前
              </button>
              <button className="btnPrimary" onClick={confirmRouteChange}>
                继续离开
              </button>
            </div>
          </div>
        </div>
      )}
      </TooltipProvider>
      <Toaster />
    </>
  );
}

export default App;
