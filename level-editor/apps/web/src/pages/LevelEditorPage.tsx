import { useEffect, useMemo, useState } from "react";
import { Hexagon, Puzzle, Shuffle } from "lucide-react";
import { toast } from "sonner";
import type { LevelConfig, PendingImageItem } from "../types";

type EditMode = "polygon" | "knob" | "swap";

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
};

type ModeDraft = {
  imageId?: string;
  levelTarget?: LevelModeTarget;
  mode: EditMode;
  updatedAt: string;
  data: Record<string, unknown>;
};

export type LevelModeTarget = {
  topicId: string;
  groupId: string;
  levelId: string;
};

type EditorContext =
  | { kind: "image"; imageId: string; mode: EditMode }
  | { kind: "level"; target: LevelModeTarget; mode: EditMode };

const modes: Array<{ id: EditMode; label: string; icon: typeof Hexagon; description: string }> = [
  { id: "polygon", label: "多边形", icon: Hexagon, description: "编辑多边形切割草稿，后续支持重点形状自动补全。" },
  { id: "knob", label: "凹凸拼图", icon: Puzzle, description: "默认 8x8，可统一调整 knob 尺寸。" },
  { id: "swap", label: "方格交换", icon: Shuffle, description: "不需要手工编辑，导出时自动生成。" },
];

function normalizeMode(value: string | null): EditMode {
  return value === "knob" || value === "swap" || value === "polygon" ? value : "polygon";
}

function imageDraftKey(imageId: string, mode: EditMode) {
  return `jigcat.mode-draft.${imageId}.${mode}`;
}

function levelDraftKey(target: LevelModeTarget, mode: EditMode) {
  return `jigcat.level-mode-draft.${target.topicId}.${target.groupId}.${target.levelId}.${mode}`;
}

function readStoredDraft(key: string): ModeDraft | null {
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as ModeDraft) : null;
  } catch {
    return null;
  }
}

function writeStoredDraft(key: string, draft: ModeDraft) {
  window.localStorage.setItem(key, JSON.stringify(draft));
}

function readImageDraft(imageId: string, mode: EditMode): ModeDraft | null {
  return imageId ? readStoredDraft(imageDraftKey(imageId, mode)) : null;
}

function readLevelDraft(target: LevelModeTarget, mode: EditMode): ModeDraft | null {
  return target.topicId && target.groupId && target.levelId ? readStoredDraft(levelDraftKey(target, mode)) : null;
}

export function modeDraftForExport(imageId: string, mode: EditMode): Record<string, unknown> | null {
  return readImageDraft(imageId, mode)?.data || null;
}

export function modeDraftForLevelExport(target: LevelModeTarget, mode: EditMode): Record<string, unknown> | null {
  return readLevelDraft(target, mode)?.data || null;
}

function contextFromUrl(): EditorContext {
  const params = new URLSearchParams(window.location.search);
  const mode = normalizeMode(params.get("mode"));
  const topicId = params.get("topic") || "";
  const groupId = params.get("group") || "";
  const levelId = params.get("level") || "";
  if (topicId && groupId && levelId) return { kind: "level", target: { topicId, groupId, levelId }, mode };
  return { kind: "image", imageId: params.get("image") || "", mode };
}

function contextTitle(context: EditorContext, levelConfig: LevelConfig | null, activeImage?: PendingImageItem) {
  if (context.kind === "level") return `${levelConfig?.title || context.target.levelId} / ${modeLabel(context.mode)}`;
  return `${activeImage?.name || "未选择图片"} / ${modeLabel(context.mode)}`;
}

function modeLabel(mode: EditMode) {
  if (mode === "polygon") return "多边形";
  if (mode === "knob") return "凹凸拼图";
  return "方格交换";
}

function existingModeData(levelConfig: LevelConfig | null, mode: EditMode): Record<string, unknown> | null {
  if (!levelConfig?.modes?.[mode]) return null;
  return levelConfig.modes[mode] as unknown as Record<string, unknown>;
}

function draftDataFromControls(mode: EditMode, polygonCount: string, knobRows: string, knobCols: string, knobSize: string) {
  if (mode === "polygon") {
    return {
      pieces: [],
      generator: { type: "guided_polygon", target_piece_count: Number(polygonCount) || 20, featured_shapes: [] },
    };
  }
  if (mode === "knob") {
    return {
      rows: Number(knobRows) || 8,
      cols: Number(knobCols) || 8,
      knob_size: Number(knobSize) || 0.24,
      pieces: [],
    };
  }
  return { auto: true, max_pieces: 25 };
}

export default function LevelEditorPage({ onUnsavedChange }: Props) {
  const [context, setContext] = useState<EditorContext>(() => contextFromUrl());
  const [images, setImages] = useState<PendingImageItem[]>([]);
  const [activeImageId, setActiveImageId] = useState(() => (context.kind === "image" ? context.imageId : ""));
  const [activeMode, setActiveMode] = useState<EditMode>(context.mode);
  const [levelConfig, setLevelConfig] = useState<LevelConfig | null>(null);
  const [loadingLevel, setLoadingLevel] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [polygonCount, setPolygonCount] = useState("20");
  const [knobRows, setKnobRows] = useState("8");
  const [knobCols, setKnobCols] = useState("8");
  const [knobSize, setKnobSize] = useState("0.24");

  useEffect(() => {
    const nextContext = contextFromUrl();
    setContext(nextContext);
    setActiveMode(nextContext.mode);
    if (nextContext.kind === "image") setActiveImageId(nextContext.imageId);
    setDirty(false);
  }, []);

  useEffect(() => {
    void loadImages();
  }, []);

  useEffect(() => {
    if (context.kind !== "level") {
      setLevelConfig(null);
      return;
    }
    void loadLevel(context.target);
  }, [context]);

  useEffect(() => {
    applyDraftToControls();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeImageId, activeMode, levelConfig, context]);

  useEffect(() => {
    onUnsavedChange?.(dirty);
    return () => onUnsavedChange?.(false);
  }, [dirty, onUnsavedChange]);

  const activeImage = useMemo(() => images.find((image) => image.id === activeImageId) || images[0], [activeImageId, images]);
  const sourcePreview = useMemo(() => {
    if (context.kind === "level") {
      return {
        name: levelConfig?.title || context.target.levelId,
        url: `/api/levels/${encodeURIComponent(context.target.topicId)}/${encodeURIComponent(context.target.groupId)}/${encodeURIComponent(context.target.levelId)}/source?mtime=${Date.now()}`,
        width: levelConfig?.image.width || 0,
        height: levelConfig?.image.height || 0,
      };
    }
    return activeImage
      ? { name: activeImage.name, url: activeImage.url, width: activeImage.source_info.width, height: activeImage.source_info.height }
      : null;
  }, [activeImage, context, levelConfig]);
  const savedDraft = currentStoredDraft();
  const inheritedMode = context.kind === "level" ? existingModeData(levelConfig, activeMode) : null;

  async function loadImages() {
    try {
      const response = await fetch("/api/pending-images");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { items?: PendingImageItem[] };
      const nextImages = (data.items || []).filter((item) => item.kind === "image" && !item.processed_path);
      setImages(nextImages);
      setActiveImageId((current) => (current && nextImages.some((item) => item.id === current) ? current : nextImages[0]?.id || ""));
    } catch (error) {
      toast.error(error instanceof Error ? `加载图片失败：${error.message}` : "加载图片失败");
    }
  }

  async function loadLevel(target: LevelModeTarget) {
    setLoadingLevel(true);
    try {
      const response = await fetch(`/api/levels/${encodeURIComponent(target.topicId)}/${encodeURIComponent(target.groupId)}/${encodeURIComponent(target.levelId)}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      setLevelConfig((await response.json()) as LevelConfig);
    } catch (error) {
      toast.error(error instanceof Error ? `加载关卡失败：${error.message}` : "加载关卡失败");
      setLevelConfig(null);
    } finally {
      setLoadingLevel(false);
    }
  }

  function currentStoredDraft() {
    if (context.kind === "level") return readLevelDraft(context.target, activeMode);
    return activeImage ? readImageDraft(activeImage.id, activeMode) : null;
  }

  function currentDraftData() {
    return currentStoredDraft()?.data || existingModeData(levelConfig, activeMode);
  }

  function applyDraftToControls() {
    const data = currentDraftData();
    if (activeMode === "polygon") {
      const generator = data?.generator as { target_piece_count?: number } | undefined;
      setPolygonCount(String(generator?.target_piece_count || 20));
    }
    if (activeMode === "knob") {
      setKnobRows(String(data?.rows || 8));
      setKnobCols(String(data?.cols || 8));
      setKnobSize(String(data?.knob_size || 0.24));
    }
  }

  function saveDraft() {
    const data = draftDataFromControls(activeMode, polygonCount, knobRows, knobCols, knobSize);
    if (context.kind === "level") {
      writeStoredDraft(levelDraftKey(context.target, activeMode), {
        levelTarget: context.target,
        mode: activeMode,
        updatedAt: new Date().toISOString(),
        data,
      });
    } else {
      if (!activeImage) {
        toast.warning("请先在图片页上传并确认一张关卡图片。");
        return;
      }
      writeStoredDraft(imageDraftKey(activeImage.id, activeMode), {
        imageId: activeImage.id,
        mode: activeMode,
        updatedAt: new Date().toISOString(),
        data,
      });
    }
    setDirty(false);
    toast.success("已保存模式草稿。");
  }

  function selectMode(mode: EditMode) {
    setActiveMode(mode);
    setDirty(false);
    if (context.kind === "level") {
      window.history.replaceState({}, "", `/editor?topic=${encodeURIComponent(context.target.topicId)}&group=${encodeURIComponent(context.target.groupId)}&level=${encodeURIComponent(context.target.levelId)}&mode=${mode}`);
      setContext({ ...context, mode });
    } else {
      const imageId = activeImage?.id || activeImageId;
      window.history.replaceState({}, "", imageId ? `/editor?image=${encodeURIComponent(imageId)}&mode=${mode}` : `/editor?mode=${mode}`);
      setContext({ kind: "image", imageId, mode });
    }
  }

  function selectImage(imageId: string) {
    setActiveImageId(imageId);
    setDirty(false);
    window.history.replaceState({}, "", `/editor?image=${encodeURIComponent(imageId)}&mode=${activeMode}`);
    setContext({ kind: "image", imageId, mode: activeMode });
  }

  function markDirty() {
    setDirty(true);
  }

  return (
    <div className="grid h-full min-h-0 grid-cols-[320px_1fr_340px] gap-4 p-4">
      <aside className="min-h-0 overflow-auto rounded-lg border border-stone-300 bg-paper p-4">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold">{context.kind === "level" ? "当前关卡" : "关卡图片"}</h2>
          {context.kind === "image" && <button className="btn" onClick={loadImages}>刷新</button>}
        </div>
        {context.kind === "level" ? (
          <div className="rounded-md border border-stone-300 bg-white p-3">
            <div className="text-sm text-muted">正在编辑</div>
            <div className="mt-1 font-semibold">{contextTitle(context, levelConfig)}</div>
            <div className="mt-2 text-xs text-muted">{context.target.topicId} / {context.target.groupId} / {context.target.levelId}</div>
            {loadingLevel && <div className="mt-3 text-sm text-muted">加载中...</div>}
          </div>
        ) : (
          <div className="space-y-2">
            {images.map((image) => (
              <button key={image.id} className={image.id === activeImage?.id ? "objectActive w-full" : "object w-full"} onClick={() => selectImage(image.id)}>
                <span className="min-w-0 flex-1 truncate">{image.name}</span>
                <small>{image.source_info.width}x{image.source_info.height}</small>
              </button>
            ))}
            {!images.length && <p className="rounded-md border border-dashed border-stone-300 bg-white/70 p-4 text-sm text-muted">暂无已确认图片。先去图片处理页上传并确认 JPG。</p>}
          </div>
        )}
      </aside>

      <section className="min-h-0 overflow-auto rounded-lg border border-stone-300 bg-[#fffaf0] p-4">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold">模式编辑</h1>
            <p className="text-sm text-muted">{context.kind === "level" ? "正在编辑已有关卡的模式草稿，保存后回到关卡页导出。" : "编辑器只处理一张图片的一个模式，不直接写入 Godot 关卡。"}</p>
          </div>
          <span className={dirty ? "statusBadge statusBadgePending" : "statusBadge statusBadgeDone"}>{dirty ? "未保存" : "已保存"}</span>
        </div>
        {sourcePreview ? (
          <div className="grid place-items-center rounded-lg bg-linen p-4">
            <img className="max-h-[70vh] max-w-full rounded-lg object-contain shadow-sm" src={sourcePreview.url} alt={sourcePreview.name} />
          </div>
        ) : (
          <div className="grid h-[60vh] place-items-center rounded-lg border border-dashed border-stone-300 text-muted">请选择图片</div>
        )}
      </section>

      <aside className="min-h-0 overflow-auto rounded-lg border border-stone-300 bg-paper p-4">
        <h2 className="mb-3 text-lg font-semibold">模式</h2>
        <div className="mb-5 grid gap-2">
          {modes.map((mode) => {
            const Icon = mode.icon;
            return (
              <button key={mode.id} className={activeMode === mode.id ? "btnActive justify-start" : "btn justify-start"} onClick={() => selectMode(mode.id)}>
                <Icon size={18} />
                {mode.label}
              </button>
            );
          })}
        </div>
        <div className="space-y-4">
          {activeMode === "polygon" && (
            <label className="block text-sm font-medium">
              目标碎片数
              <input className="input mt-1" value={polygonCount} onChange={(event) => { setPolygonCount(event.target.value); markDirty(); }} />
            </label>
          )}
          {activeMode === "knob" && (
            <>
              <label className="block text-sm font-medium">行数<input className="input mt-1" value={knobRows} onChange={(event) => { setKnobRows(event.target.value); markDirty(); }} /></label>
              <label className="block text-sm font-medium">列数<input className="input mt-1" value={knobCols} onChange={(event) => { setKnobCols(event.target.value); markDirty(); }} /></label>
              <label className="block text-sm font-medium">Knob 大小<input className="input mt-1" value={knobSize} onChange={(event) => { setKnobSize(event.target.value); markDirty(); }} /></label>
            </>
          )}
          {activeMode === "swap" && <p className="rounded-md bg-white p-3 text-sm text-muted">方格交换不需要手工编辑。导出时使用自动网格，最多 25 块。</p>}
          <button className="btnPrimary w-full" onClick={saveDraft}>保存模式草稿</button>
          <div className="rounded-md bg-white p-3 text-sm text-muted">
            <div className="font-medium text-ink">当前数据</div>
            {savedDraft ? <div>草稿：{new Date(savedDraft.updatedAt).toLocaleString()}</div> : inheritedMode ? <div>来自 level.json</div> : <div>未保存</div>}
          </div>
        </div>
      </aside>
    </div>
  );
}
