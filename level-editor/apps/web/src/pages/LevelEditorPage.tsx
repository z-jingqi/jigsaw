import { useEffect, useMemo, useRef, useState } from "react";
import { PointerSensor, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { arrayMove } from "@dnd-kit/sortable";
import { CircleAlert, Eye, Hexagon, Magnet, Pencil, Plus, Puzzle, Redo2, RefreshCcw, Save, Trash2, Undo2, X } from "lucide-react";
import { toast } from "sonner";
import {
  DEFAULT_BROWSER_IMAGE,
  DEFAULT_IMAGE_PATH,
  analyzeActualPieces,
  catmullRomPath,
  detectImageOutline,
  generateFractureNetwork,
  generateKnobPieces,
  makeEmptyLevel,
  presetCut,
  samplePath,
  serializePoints,
  snapPoint,
  uid,
  type ActualPiecePreview,
} from "../geometry";
import type { CatalogLevel, CutLine, CutTemplate, LevelCatalog, LevelConfig, LevelPiece, OutlineAnalysis, PieceCell, Point, LevelImageConfig, PendingImageItem } from "../types";
import { cellsToLevelPieces, mergePolygons, pointFromTuple, polygonCenter, polylinePath, translateCut, tupleBounds, tupleFromPoint, unionTupleBounds, visibleBoundsList } from "../features/level-editor/lib/polygonPieces";
import { presetTemplates, ShapeButton, shapeTension } from "../features/level-editor/lib/shapes";
import { Field } from "../shared/ui/Field";
import { Input } from "../shared/ui/Input";
import { PanelTitle } from "../shared/ui/PanelTitle";
import { SelectBox, type SelectOption } from "../shared/ui/SelectBox";
import { Textarea } from "../shared/ui/Textarea";
import { makeDefaultCatalog, normalizeOrder, updateCatalogLevel } from "../shared/lib/catalog";
import { idFromEnglishName, nextSequentialId } from "../shared/lib/ids";
import { localized, reservedI18n } from "../shared/lib/i18n";
import { WithTooltip } from "../components/ui/tooltip";
import { ToggleGroup, ToggleGroupItem } from "../components/ui/toggle-group";

const snapThreshold = 18;
const editorLocale = "zh-cn";

type EditMode = "polygon" | "knob";
type PolygonViewMode = "result" | "edit" | "inspect";

type LevelTarget = {
  topicId: string;
  levelId: string;
};

type ImageTarget = EditMode;

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
};

type CreateDialogKind = "topic" | "level" | null;

type SaveModeDialogState = {
  open: boolean;
  targetMode: "existing" | "new";
  topicId: string;
  levelId: string;
  newTopic: boolean;
  title: string;
  description: string;
  newTopicName: string;
  newTopicId: string;
  newLevelTitle: string;
  newLevelDescription: string;
  newBackgroundType: "color" | "image";
  newBackgroundColor: string;
  newBackgroundPath: string;
};

type EditorSnapshot = {
  level: LevelConfig;
  cuts: CutLine[];
  pieces: PieceCell[];
  knobPieces: LevelPiece[];
  completedModes: Record<EditMode, boolean>;
};

type DragState = {
  cutId: string;
  pointIndex: number | null;
  start: Point;
  original: CutLine;
};

type DrawingCutState = {
  id: string;
  points: Point[];
};

type AnalysisWorkerMessage =
  | {
      type: "imageReady";
      requestId: number;
    }
  | {
      type: "analysisResult";
      requestId: number;
      result: Omit<ActualPiecePreview, "dataUrl"> & { previewBuffer: ArrayBuffer };
    };

function cloneSnapshot(snapshot: EditorSnapshot): EditorSnapshot {
  return structuredClone(snapshot);
}

function isTextEditingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tagName = target.tagName.toLowerCase();
  return target.isContentEditable || tagName === "input" || tagName === "textarea" || tagName === "select";
}

function modeImageConfig(level: LevelConfig, mode: EditMode): LevelImageConfig {
  return level.modes[mode].image as LevelImageConfig;
}

function modeImagePath(level: LevelConfig, mode: EditMode): string {
  return imageConfigPath(modeImageConfig(level, mode));
}

function displayPendingImageName(item: PendingImageItem) {
  return item.name.replace(/\.[^.]+$/, "");
}

function normalizeLevelConfig(data: Partial<LevelConfig>, topicId?: string, levelId?: string): LevelConfig {
  const defaults = makeEmptyLevel();
  return {
    ...defaults,
    ...data,
    id: levelId || data.id || defaults.id,
    topic_id: topicId || data.topic_id || defaults.topic_id,
    image: { ...defaults.image, ...(data.image || {}) },
    assets: {
      ...(defaults.assets || {}),
      ...(data.assets || {}),
    },
    background: { ...defaults.background, ...data.background },
    grid: { ...defaults.grid, ...data.grid },
    modes: {
      polygon: {
        ...defaults.modes.polygon,
        ...(data.modes?.polygon || {}),
        image: data.modes?.polygon?.image || defaults.modes.polygon.image,
      },
      knob: {
        ...defaults.modes.knob,
        ...(data.modes?.knob || {}),
        image: data.modes?.knob?.image || defaults.modes.knob.image,
        cols: data.modes?.knob?.cols ?? data.grid?.cols ?? defaults.grid.cols,
        rows: data.modes?.knob?.rows ?? data.grid?.rows ?? defaults.grid.rows,
        piece_size: data.modes?.knob?.piece_size ?? data.grid?.piece_size ?? defaults.grid.piece_size,
      },
    },
    editor: { ...defaults.editor, ...data.editor },
  };
}

function imageConfigPath(value?: LevelImageConfig): string {
  if (!value) return "";
  return typeof value === "string" ? value : value.path || "";
}

function polygonViewLabel(view: PolygonViewMode): string {
  if (view === "result") return "查看";
  if (view === "edit") return "编辑";
  return "检查";
}

function previewBufferToDataUrl(width: number, height: number, previewBuffer: ArrayBuffer): string {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return "";
  ctx.putImageData(new ImageData(new Uint8ClampedArray(previewBuffer), width, height), 0, 0);
  return canvas.toDataURL("image/png");
}

function App({ onUnsavedChange }: Props) {
  const [catalog, setCatalog] = useState<LevelCatalog>(() => makeDefaultCatalog());
  const locale = editorLocale;
  const [currentTarget, setCurrentTarget] = useState<LevelTarget>({ topicId: "cat", levelId: "cat_moon_01" });
  const [pendingTarget, setPendingTarget] = useState<LevelTarget | null>(null);
  const [level, setLevel] = useState<LevelConfig>(() => makeEmptyLevel());
  const [pendingImages, setPendingImages] = useState<PendingImageItem[]>([]);
  const [backgroundImages, setBackgroundImages] = useState<PendingImageItem[]>([]);
  const [selectedImages, setSelectedImages] = useState<Record<EditMode, PendingImageItem | null>>({ polygon: null, knob: null });
  const [saveDialog, setSaveDialog] = useState<SaveModeDialogState>({
    open: false,
    targetMode: "existing",
    topicId: "cat",
    levelId: "cat_moon_01",
    newTopic: false,
    title: "月亮小睡",
    description: "",
    newTopicName: "新主题",
    newTopicId: "new_topic",
    newLevelTitle: "新关卡",
    newLevelDescription: "",
    newBackgroundType: "color",
    newBackgroundColor: "#F6EBD4",
    newBackgroundPath: "",
  });
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [imageUrl, setImageUrl] = useState(DEFAULT_BROWSER_IMAGE);
  const [analysis, setAnalysis] = useState<OutlineAnalysis>({ outline: [], edgePoints: [], bounds: null });
  const [activeMode, setActiveMode] = useState<EditMode>("polygon");
  const [cuts, setCuts] = useState<CutLine[]>([]);
  const [pieces, setPieces] = useState<PieceCell[]>([]);
  const [knobPieces, setKnobPieces] = useState<LevelPiece[]>([]);
  const [analysisCuts, setAnalysisCuts] = useState<CutLine[]>([]);
  const [actualPreview, setActualPreview] = useState<ActualPiecePreview | null>(null);
  const [selectedPieceIds, setSelectedPieceIds] = useState<string[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [drag, setDrag] = useState<DragState | null>(null);
  const [targetPieces, setTargetPieces] = useState(14);
  const [snapEnabled, setSnapEnabled] = useState(true);
  const [showKnobPieces, setShowKnobPieces] = useState(true);
  const [polygonView, setPolygonView] = useState<PolygonViewMode>("result");
  const [drawingCut, setDrawingCut] = useState<DrawingCutState | null>(null);
  const [drawingHoverPoint, setDrawingHoverPoint] = useState<Point | null>(null);
  const [dirtyModes, setDirtyModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [completedModes, setCompletedModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [knobGridDraft, setKnobGridDraft] = useState({ cols: "8", rows: "8", piece_size: "190" });
  const [pendingMode, setPendingMode] = useState<EditMode | null>(null);
  const [sortOpen, setSortOpen] = useState(false);
  const [createDialog, setCreateDialog] = useState<CreateDialogKind>(null);
  const [undoStack, setUndoStack] = useState<EditorSnapshot[]>([]);
  const [redoStack, setRedoStack] = useState<EditorSnapshot[]>([]);
  const svgRef = useRef<SVGSVGElement | null>(null);
  const cutPathCacheRef = useRef<WeakMap<CutLine, string>>(new WeakMap());
  const piecePathCacheRef = useRef<WeakMap<PieceCell, string>>(new WeakMap());
  const knobPiecePathCacheRef = useRef<WeakMap<LevelPiece, string>>(new WeakMap());
  const dragFrameRef = useRef<number | null>(null);
  const dragPointRef = useRef<Point | null>(null);
  const analysisWorkerRef = useRef<Worker | null>(null);
  const analysisRequestIdRef = useRef(0);
  const imageRequestIdRef = useRef(0);
  const [workerImageReady, setWorkerImageReady] = useState(false);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  useEffect(() => {
    void loadCatalog();
  }, []);

  useEffect(() => () => onUnsavedChange?.(false), [onUnsavedChange]);

  useEffect(() => {
    try {
      const worker = new Worker(new URL("../actualPieces.worker.ts", import.meta.url), { type: "module" });
      worker.onmessage = (event: MessageEvent<AnalysisWorkerMessage>) => {
        const message = event.data;
        if (message.type === "imageReady") {
          if (message.requestId === imageRequestIdRef.current) setWorkerImageReady(true);
          return;
        }
        if (message.requestId !== analysisRequestIdRef.current) return;
        const { previewBuffer, ...result } = message.result;
        setActualPreview({
          ...result,
          dataUrl: previewBufferToDataUrl(result.width, result.height, previewBuffer),
        });
      };
      worker.onerror = () => {
        worker.terminate();
        if (analysisWorkerRef.current === worker) analysisWorkerRef.current = null;
        setWorkerImageReady(false);
      };
      analysisWorkerRef.current = worker;
      return () => {
        worker.terminate();
        if (analysisWorkerRef.current === worker) analysisWorkerRef.current = null;
      };
    } catch {
      analysisWorkerRef.current = null;
      return undefined;
    }
  }, []);

  function showToast(message: string) {
    toast(message);
  }

  const currentTopic = useMemo(() => catalog.topics.find((topic) => topic.id === currentTarget.topicId), [catalog, currentTarget.topicId]);
  const currentCatalogLevel = useMemo(
    () => currentTopic?.levels.find((item) => item.id === currentTarget.levelId),
    [currentTopic, currentTarget.levelId],
  );
  const topicOptions = useMemo<SelectOption[]>(
    () => catalog.topics.map((topic) => ({ value: topic.id, label: localized(topic.name_i18n, locale, topic.name) })),
    [catalog.topics, locale],
  );
  const levelOptions = useMemo<SelectOption[]>(
    () => (currentTopic?.levels || []).map((item) => ({ value: item.id, label: localized(item.title_i18n, locale, item.title) })),
    [currentTopic, locale],
  );
  const saveTopic = useMemo(() => catalog.topics.find((topic) => topic.id === saveDialog.topicId) || catalog.topics[0], [catalog.topics, saveDialog.topicId]);
  const saveLevelOptions = useMemo<SelectOption[]>(
    () => (saveTopic?.levels || []).map((item) => ({ value: item.id, label: localized(item.title_i18n, locale, item.title) })),
    [locale, saveTopic],
  );
  const currentTopicName = localized(currentTopic?.name_i18n, locale, currentTopic?.name || currentTarget.topicId);
  const currentLevelName = localized(currentCatalogLevel?.title_i18n, locale, currentCatalogLevel?.title || level.title || currentTarget.levelId);
  const imageOptions = useMemo<SelectOption[]>(
    () =>
      pendingImages
        .filter((item) => !item.processed_path)
        .map((item) => ({
          value: item.id,
          label: displayPendingImageName(item),
        })),
    [pendingImages],
  );
  const backgroundImageOptions = useMemo<SelectOption[]>(
    () =>
      backgroundImages.map((item) => ({
        value: item.path,
        label: displayPendingImageName(item),
      })),
    [backgroundImages],
  );
  const canUseBackgroundImage = backgroundImageOptions.length > 0;
  const activePendingImage = selectedImages[activeMode];
  const canvasBackgroundStyle = { backgroundColor: level.background.color };

  useEffect(() => {
    if (!activePendingImage) {
      loadEditorImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH, activeMode, false);
      return;
    }
    loadEditorImage(activePendingImage.url, activePendingImage.name, activePendingImage.path, activeMode);
  }, [activeMode, activePendingImage?.id, activePendingImage?.url]);

  useEffect(() => {
    setKnobGridDraft({
      cols: String(level.grid.cols),
      rows: String(level.grid.rows),
      piece_size: String(level.grid.piece_size),
    });
  }, [level.grid.cols, level.grid.rows, level.grid.piece_size]);

  async function loadCatalog() {
    try {
      const response = await fetch("/api/catalog");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const nextCatalog = (await response.json()) as LevelCatalog;
      const normalized = {
        ...makeDefaultCatalog(),
        ...nextCatalog,
        topics: normalizeOrder([...(nextCatalog.topics || [])].map((topic) => ({ ...topic, levels: normalizeOrder([...(topic.levels || [])]) }))),
      };
      setCatalog(normalized);
      const params = new URLSearchParams(window.location.search);
      const firstTopic = normalized.topics[0];
      const firstLevel = firstTopic?.levels[0];
      if (firstTopic && firstLevel) {
        setCurrentTarget({ topicId: firstTopic.id, levelId: firstLevel.id });
        setSaveDialog((current) => ({
          ...current,
          topicId: firstTopic.id,
          levelId: firstLevel.id,
          title: firstLevel.title,
        }));
      }
      await loadPendingImages(params.get("image") || "");
      const requestedMode = params.get("mode");
      if (requestedMode === "polygon" || requestedMode === "knob") setActiveMode(requestedMode);
    } catch (error) {
      showToast(error instanceof Error ? `加载 catalog 失败：${error.message}` : "加载 catalog 失败");
      await loadPendingImages(new URLSearchParams(window.location.search).get("image") || "");
    }
  }

  async function loadPendingImages(preferredId = "") {
    try {
      const response = await fetch("/api/pending-images");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[] };
      const availableItems = (data.items || []).filter((item) => !item.processed_path);
      const items = availableItems.filter((item) => item.kind !== "tablecloth");
      const tableclothItems = availableItems.filter((item) => item.kind === "tablecloth");
      setPendingImages(items);
      setBackgroundImages(tableclothItems);
      setSaveDialog((current) => ({
        ...current,
        newBackgroundPath: current.newBackgroundPath || tableclothItems[0]?.path || "",
        newBackgroundType: current.newBackgroundType === "image" && !tableclothItems.length ? "color" : current.newBackgroundType,
      }));
      const preferred = items.find((item) => item.id === preferredId) || items.find((item) => item.processed) || items[0] || null;
      if (preferred) {
        setSelectedImages({ polygon: preferred, knob: preferred });
        applyPendingImageToMode("polygon", preferred);
        applyPendingImageToMode("knob", preferred);
      }
    } catch (error) {
      showToast(error instanceof Error ? `加载图片池失败：${error.message}` : "加载图片池失败");
    }
  }

  async function loadLevel(topicId: string, levelId: string, catalogLevel?: CatalogLevel) {
    try {
      const response = await fetch(`/api/levels/${topicId}/${levelId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelConfig;
      applyLoadedLevel(data, topicId, levelId);
    } catch (error) {
      const fallback = makeEmptyLevel();
      fallback.id = levelId;
      fallback.topic_id = topicId;
      fallback.title = catalogLevel?.title || levelId;
      fallback.title_i18n = catalogLevel?.title_i18n || { [locale]: fallback.title };
      fallback.image.path = `res://levels/${topicId}/${levelId}/source.png`;
      applyLoadedLevel(fallback, topicId, levelId);
    }
  }

  function applyPendingImageToMode(mode: EditMode, item: PendingImageItem) {
    const nextImage = {
      path: item.path,
      name: item.name,
      width: item.source_info.width,
      height: item.source_info.height,
    };
    setLevel((current) => ({
      ...current,
      modes: {
        ...current.modes,
        [mode]: {
          ...current.modes[mode],
          image: nextImage,
        },
      },
    }));
  }

  function selectImageForMode(mode: EditMode, imageId: string) {
    const item = pendingImages.find((candidate) => candidate.id === imageId) || null;
    if (!item) return;
    recordImageEdit(mode);
    setSelectedImages((current) => ({ ...current, [mode]: item }));
    applyPendingImageToMode(mode, item);
  }

  function applyLoadedLevel(data: LevelConfig, topicId: string, levelId: string) {
    const nextLevel = normalizeLevelConfig(data, topicId, levelId);
    setCurrentTarget({ topicId, levelId });
    setLevel(nextLevel);
    const importedCuts: CutLine[] = [
      ...(data.editor?.cuts || []).map((cut) => ({ ...cut, points: cut.points.map(([x, y]) => ({ x, y })) })),
      ...(data.editor?.shapes || []).map((shape) => ({ ...shape, points: shape.points.map(([x, y]) => ({ x, y })) })),
    ];
    setCuts(importedCuts);
    setAnalysisCuts(importedCuts);
    setPieces((data.editor?.pieces || []).map((piece) => ({ ...piece, points: piece.points.map(([x, y]) => ({ x, y })) })));
    setKnobPieces(data.modes?.knob?.pieces || []);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDirtyModes({ polygon: false, knob: false });
    setCompletedModes({
      polygon: Boolean(data.modes?.polygon?.pieces?.length),
      knob: Boolean(data.modes?.knob?.pieces?.length),
    });
    setUndoStack([]);
    setRedoStack([]);
  }

  useEffect(() => {
    if (!image) return;
    const nextAnalysis = detectImageOutline(image);
    setAnalysis(nextAnalysis);
    setActiveImageDimensions(image.naturalWidth, image.naturalHeight);
    setLevel((current) => ({
      ...current,
      editor: {
        ...current.editor,
        outline: serializePoints(nextAnalysis.outline),
      },
    }));
  }, [image]);

  useEffect(() => {
    setActualPreview(null);
    setWorkerImageReady(false);
    if (!image) return;
    const worker = analysisWorkerRef.current;
    if (!worker || !("createImageBitmap" in window)) return;
    let cancelled = false;
    const requestId = imageRequestIdRef.current + 1;
    imageRequestIdRef.current = requestId;
    void createImageBitmap(image)
      .then((bitmap) => {
        if (cancelled) {
          bitmap.close();
          return;
        }
        worker.postMessage({ type: "setImage", requestId, image: bitmap }, [bitmap]);
      })
      .catch(() => {
        if (imageRequestIdRef.current === requestId) setWorkerImageReady(false);
      });
    return () => {
      cancelled = true;
    };
  }, [image]);

  const viewBox = useMemo(() => {
    if (!image) return "0 0 1024 1024";
    return `0 0 ${image.naturalWidth} ${image.naturalHeight}`;
  }, [image]);

  const selected = cuts.find((cut) => cut.id === selectedId);
  const snapPoints = useMemo(() => {
    if (!analysis.outline.length) return [];
    return samplePath([...analysis.outline, analysis.outline[0]], Math.min(300, Math.max(100, analysis.outline.length)));
  }, [analysis.outline]);
  const generatedKnobPieces = useMemo(
    () => (activeMode === "knob" ? generateKnobPieces(image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size) : []),
    [activeMode, image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size],
  );
  const modeReady = {
    polygon: pieces.length > 0,
    knob: knobPieces.length > 0,
  };
  const canSaveCurrentMode = Boolean(activePendingImage && modeReady[activeMode]);
  const canSaveToGodot = canSaveCurrentMode;
  const canvasModeLabel =
    activeMode === "polygon"
      ? `多边形 · ${drawingCut ? "添加线条" : polygonViewLabel(polygonView)}`
      : `凹凸 · ${showKnobPieces ? "预览" : "编辑"}`;

  useEffect(() => {
    if (!image) {
      setActualPreview(null);
      return;
    }
    const requestId = analysisRequestIdRef.current + 1;
    analysisRequestIdRef.current = requestId;
    const worker = analysisWorkerRef.current;
    if (worker && workerImageReady) {
      worker.postMessage({ type: "analyze", requestId, cuts: analysisCuts, maxSize: 840 });
      return;
    }
    const timeout = window.setTimeout(() => {
      if (requestId !== analysisRequestIdRef.current) return;
      setActualPreview(analyzeActualPieces(image, analysisCuts, 840));
    }, 0);
    return () => window.clearTimeout(timeout);
  }, [image, analysisCuts, workerImageReady]);

  useEffect(() => {
    if (!analysisCuts.length || !actualPreview?.pieces.length) return;
    setPieces(actualPreview.pieces);
    setSelectedPieceIds((current) => current.filter((id) => actualPreview.pieces.some((piece) => piece.id === id)));
  }, [actualPreview, analysisCuts.length]);

  useEffect(() => {
    if (activeMode !== "polygon") return;
    if (drag) return;
    const timeout = window.setTimeout(() => setAnalysisCuts(structuredClone(cuts)), 180);
    return () => window.clearTimeout(timeout);
  }, [activeMode, cuts, drag]);
  useEffect(() => {
    if (activeMode === "knob" && !knobPieces.length && generatedKnobPieces.length) setKnobPieces(generatedKnobPieces);
  }, [activeMode, generatedKnobPieces, knobPieces.length]);

  useEffect(() => {
    const hasDirtyMode = dirtyModes.polygon || dirtyModes.knob;
    onUnsavedChange?.(hasDirtyMode);
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (!hasDirtyMode) return;
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirtyModes, onUnsavedChange]);

  function snapshot(): EditorSnapshot {
    return cloneSnapshot({ level, cuts, pieces, knobPieces, completedModes });
  }

  function recordEdit(mode: EditMode = activeMode) {
    setUndoStack((current) => [...current.slice(-49), snapshot()]);
    setRedoStack([]);
    setDirtyModes((current) => ({ ...current, [mode]: true }));
    setCompletedModes((current) => ({ ...current, [mode]: false }));
  }

  function restoreSnapshot(next: EditorSnapshot) {
    setLevel(next.level);
    setCuts(next.cuts);
    setAnalysisCuts(next.cuts);
    setPieces(next.pieces);
    setKnobPieces(next.knobPieces);
    setCompletedModes(next.completedModes || { polygon: false, knob: false });
    setSelectedId("");
    setSelectedPieceIds([]);
    setDrag(null);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
  }

  function undo() {
    setUndoStack((current) => {
      if (!current.length) return current;
      const previous = current[current.length - 1];
      setRedoStack((redo) => [...redo, snapshot()]);
      restoreSnapshot(previous);
      setDirtyModes((dirty) => ({ ...dirty, [activeMode]: true }));
      return current.slice(0, -1);
    });
  }

  function redo() {
    setRedoStack((current) => {
      if (!current.length) return current;
      const next = current[current.length - 1];
      setUndoStack((undoItems) => [...undoItems, snapshot()]);
      restoreSnapshot(next);
      setDirtyModes((dirty) => ({ ...dirty, [activeMode]: true }));
      return current.slice(0, -1);
    });
  }

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (drawingCut && event.key === "Escape") {
        event.preventDefault();
        finishDrawingCut();
        return;
      }
      if (isTextEditingTarget(event.target)) return;
      const modKey = event.metaKey || event.ctrlKey;
      const key = event.key.toLowerCase();
      if (modKey && key === "z") {
        event.preventDefault();
        if (event.shiftKey) redo();
        else undo();
        return;
      }
      if (modKey && key === "y") {
        event.preventDefault();
        redo();
        return;
      }
      if (!modKey && activeMode === "polygon" && selectedId && (event.key === "Backspace" || event.key === "Delete")) {
        event.preventDefault();
        removeSelected();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [activeMode, drawingCut, redoStack.length, selectedId, undoStack.length]);

  function requestModeChange(mode: EditMode) {
    if (mode === activeMode) return;
    if (dirtyModes[activeMode]) {
      setPendingMode(mode);
      return;
    }
    switchMode(mode);
  }

  function switchMode(mode: EditMode) {
    setActiveMode(mode);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDrag(null);
    setPendingMode(null);
  }

  function hasUnsavedChanges() {
    return dirtyModes.polygon || dirtyModes.knob;
  }

  function requestLevelChange(target: LevelTarget) {
    if (target.topicId === currentTarget.topicId && target.levelId === currentTarget.levelId) return;
    if (hasUnsavedChanges()) {
      setPendingTarget(target);
      return;
    }
    void switchLevel(target);
  }

  async function switchLevel(target: LevelTarget) {
    const topic = catalog.topics.find((item) => item.id === target.topicId);
    const levelItem = topic?.levels.find((item) => item.id === target.levelId);
    if (!topic || !levelItem) return;
    setPendingTarget(null);
    await loadLevel(topic.id, levelItem.id, levelItem);
  }

  async function saveAndSwitchLevel() {
    if (!pendingTarget) return;
    if (!canSaveToGodot) {
      showToast("当前关卡两个模式都完成后，才能保存并切换。");
      return;
    }
    const ok = await saveJsonToGodot();
    if (ok) await switchLevel(pendingTarget);
  }

  async function saveCatalogOnly() {
    return persistCatalog(catalog, true);
  }

  async function persistCatalog(nextCatalog: LevelCatalog, announce = false) {
    if (announce) showToast("保存关卡...");
    try {
      const response = await fetch("/api/catalog", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(nextCatalog),
      });
      const result = (await response.json()) as { ok?: boolean; path?: string; error?: string };
      if (!response.ok || !result.ok) throw new Error(result.error || `HTTP ${response.status}`);
      if (announce) showToast(`关卡已保存到 ${result.path}`);
      return true;
    } catch (error) {
      showToast(error instanceof Error ? `保存关卡失败：${error.message}` : "保存关卡失败");
      return false;
    }
  }

  function selectTopic(topicId: string) {
    const topic = catalog.topics.find((item) => item.id === topicId);
    const firstLevel = topic?.levels[0];
    if (!topic || !firstLevel) return;
    requestLevelChange({ topicId: topic.id, levelId: firstLevel.id });
  }

  function selectLevel(levelId: string) {
    if (!currentTopic?.levels.some((item) => item.id === levelId)) return;
    requestLevelChange({ topicId: currentTarget.topicId, levelId });
  }

  function onSortDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const activeId = String(active.id);
    const overId = String(over.id);
    if (activeId.startsWith("topic:") && overId.startsWith("topic:")) {
      const activeTopicId = activeId.replace("topic:", "");
      const overTopicId = overId.replace("topic:", "");
      setCatalog((current) => {
        const oldIndex = current.topics.findIndex((topic) => topic.id === activeTopicId);
        const newIndex = current.topics.findIndex((topic) => topic.id === overTopicId);
        if (oldIndex < 0 || newIndex < 0) return current;
        return { ...current, topics: normalizeOrder(arrayMove(current.topics, oldIndex, newIndex)) };
      });
      return;
    }
    if (activeId.startsWith("level:") && overId.startsWith("level:")) {
      const activeLevelId = activeId.replace("level:", "");
      const overLevelId = overId.replace("level:", "");
      setCatalog((current) => ({
        ...current,
        topics: current.topics.map((topic) => {
          if (topic.id !== currentTarget.topicId) return topic;
          const oldIndex = topic.levels.findIndex((item) => item.id === activeLevelId);
          const newIndex = topic.levels.findIndex((item) => item.id === overLevelId);
          if (oldIndex < 0 || newIndex < 0) return topic;
          return { ...topic, levels: normalizeOrder(arrayMove(topic.levels, oldIndex, newIndex)) };
        }),
      }));
    }
  }

  function adjacentLevel(direction: 1 | -1): LevelTarget | null {
    const flat = catalog.topics.flatMap((topic) => topic.levels.map((levelItem) => ({ topicId: topic.id, levelId: levelItem.id })));
    const index = flat.findIndex((item) => item.topicId === currentTarget.topicId && item.levelId === currentTarget.levelId);
    if (index < 0) return null;
    return flat[index + direction] || null;
  }

  function addTopic() {
    setCreateDialog("topic");
  }

  function createTopic(name: string) {
    const id = nextSequentialId("topic", catalog.topics.map((topic) => topic.id));
    const nextCatalog = {
      ...catalog,
      topics: normalizeOrder([
        ...catalog.topics,
        {
          id,
          name,
          name_i18n: { [locale]: name },
          sort_order: catalog.topics.length,
          cover: "",
          levels: [],
        },
      ]),
    };
    setCatalog(nextCatalog);
    void persistCatalog(nextCatalog);
    showToast(`已创建主题 ${name}`);
    return true;
  }

  function addLevelToCurrentTopic() {
    setCreateDialog("level");
  }

  function createLevelInCurrentTopic(title: string) {
    const topicId = currentTopic?.id;
    if (!topicId || !currentTopic) return false;
    const id = nextSequentialId("level", currentTopic.levels.map((item) => item.id));
    const nextTarget = { topicId, levelId: id };
    const nextCatalog: LevelCatalog = {
      ...catalog,
      topics: catalog.topics.map((topic) =>
          topic.id === topicId
            ? {
                ...topic,
                levels: normalizeOrder([
                  ...topic.levels,
                  {
                    id,
                    title,
                    title_i18n: { [locale]: title },
                    sort_order: topic.levels.length,
                    path: `res://levels/${topic.id}/${id}/level.json`,
                    source: `res://levels/${topic.id}/${id}/source.png`,
                  },
                ]),
              }
            : topic,
        ),
    };
    setCatalog(nextCatalog);
    void persistCatalog(nextCatalog);
    setCurrentTarget(nextTarget);
    const blankLevel = makeEmptyLevel();
    const newLevel: LevelConfig = {
      ...blankLevel,
      id,
      topic_id: topicId,
      title,
      title_i18n: { [locale]: title },
      image: {
        ...blankLevel.image,
        path: `res://levels/${topicId}/${id}/source.png`,
      },
    };
    applyLoadedLevel(
      newLevel,
      topicId,
      id,
    );
    void fetch(`/api/levels/${topicId}/${id}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ level: newLevel, catalog: nextCatalog }),
    });
    showToast(`已创建 ${title}`);
    return true;
  }

  function markCurrentModeComplete() {
    if (!modeReady[activeMode]) {
      showToast(activeMode === "polygon" ? "多边形模式还没有生成可用碎片。" : "凹凸模式还没有可用碎片。");
      return;
    }
    setCompletedModes((current) => ({ ...current, [activeMode]: true }));
    setDirtyModes((current) => ({ ...current, [activeMode]: false }));
    showToast(`${activeMode === "polygon" ? "多边形" : "凹凸"}模式已标记完成。`);
  }

  function catalogForSave() {
    return updateCatalogLevel(catalog, currentTarget, (item) => ({
      ...item,
      title: level.title,
      title_i18n: level.title_i18n || item.title_i18n,
      path: `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/level.json`,
      source: modeImagePath(level, activeMode) || item.source,
    }));
  }

  function togglePieceSelection(pieceId: string) {
    setSelectedId("");
    setSelectedPieceIds((current) => {
      if (current.includes(pieceId)) return current.filter((id) => id !== pieceId);
      return [...current, pieceId].slice(-2);
    });
  }

  function mergeSelectedPieces() {
    if (selectedPieceIds.length !== 2) {
      showToast("请选择两个相邻碎片。");
      return;
    }
    if (activeMode === "polygon") {
      const selectedPieces = selectedPieceIds.map((id) => pieces.find((piece) => piece.id === id));
      if (!selectedPieces[0] || !selectedPieces[1]) return;
      const mergedPoints = mergePolygons(selectedPieces[0].points, selectedPieces[1].points);
      if (!mergedPoints) {
        showToast("只能合并相邻碎片。");
        return;
      }
      recordEdit("polygon");
      const merged: PieceCell = { id: `poly_merge_${Date.now().toString(36)}`, points: mergedPoints };
      setPieces((current) => [...current.filter((piece) => !selectedPieceIds.includes(piece.id)), merged]);
      setSelectedPieceIds([merged.id]);
      showToast("已合并多边形碎片。");
      return;
    }

    const selectedKnobPieces = selectedPieceIds.map((id) => knobPieces.find((piece) => piece.id === id));
    if (!selectedKnobPieces[0] || !selectedKnobPieces[1]) return;
    const firstPoints = selectedKnobPieces[0].points.map(pointFromTuple);
    const secondPoints = selectedKnobPieces[1].points.map(pointFromTuple);
    const mergedPoints = mergePolygons(firstPoints, secondPoints);
    if (!mergedPoints) {
      showToast("只能合并相邻碎片。");
      return;
    }
    recordEdit("knob");
    const mergedId = `knob_merge_${Date.now().toString(36)}`;
    const neighborIds = [...new Set([...selectedKnobPieces[0].neighbors, ...selectedKnobPieces[1].neighbors].filter((id) => !selectedPieceIds.includes(id)))];
    const mergedVisibleBoundsList = selectedKnobPieces.flatMap(visibleBoundsList);
    const merged: LevelPiece = {
      id: mergedId,
      cell: selectedKnobPieces[0].cell,
      home: tupleFromPoint(polygonCenter(mergedPoints)),
      points: mergedPoints.map(tupleFromPoint),
      neighbors: neighborIds,
      cut_lines: [],
      visible_bounds: unionTupleBounds(mergedVisibleBoundsList, mergedPoints),
      visible_bounds_list: mergedVisibleBoundsList.length ? mergedVisibleBoundsList : [tupleBounds(mergedPoints)],
    };
    setKnobPieces((current) =>
      current
        .filter((piece) => !selectedPieceIds.includes(piece.id))
        .map((piece) => ({
          ...piece,
          neighbors: [...new Set(piece.neighbors.map((id) => (selectedPieceIds.includes(id) ? mergedId : id)).filter((id) => id !== piece.id))],
        }))
        .concat(merged),
    );
    setSelectedPieceIds([mergedId]);
    showToast("已合并凹凸碎片。");
  }

  function setActiveImageDimensions(width: number, height: number) {
    setLevel((current) => {
      const modeConfig = current.modes[activeMode];
      const imageConfig = typeof modeConfig.image === "string" ? { path: modeConfig.image } : { ...(modeConfig.image || {}) };
      return {
        ...current,
        modes: {
          ...current.modes,
          [activeMode]: {
            ...modeConfig,
            image: {
              ...imageConfig,
              width,
              height,
            },
          },
        },
      };
    });
  }

  function loadEditorImage(src: string, name: string, godotPath: string, target: ImageTarget, updateConfig = true) {
    const next = new Image();
    next.onload = () => {
      setImage(next);
      setImageUrl(src);
      if (!updateConfig) return;
      setLevel((current) => {
        const modeConfig = current.modes[target];
        return {
          ...current,
          modes: {
            ...current.modes,
            [target]: {
              ...modeConfig,
              image: {
                path: godotPath,
                name,
                width: next.naturalWidth,
                height: next.naturalHeight,
              },
            },
          },
        };
      });
    };
    next.onerror = () => {
      if (src !== DEFAULT_BROWSER_IMAGE) {
        loadEditorImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH, target, false);
        showToast("当前图片无法加载，已临时使用示例图预览。");
      }
    };
    next.src = src;
  }

  function recordImageEdit(target: ImageTarget) {
    setUndoStack((current) => [...current.slice(-49), snapshot()]);
    setRedoStack([]);
    setDirtyModes((current) => ({ ...current, [target]: true }));
    setCompletedModes((current) => ({ ...current, [target]: false }));
  }

  function updateLevel<T extends keyof LevelConfig>(key: T, value: LevelConfig[T]) {
    recordEdit(activeMode);
    setLevel((current) => ({ ...current, [key]: value }));
  }

  function updateLocalizedTitle(value: string) {
    recordEdit(activeMode);
    setLevel((current) => ({
      ...current,
      title: value,
      title_i18n: { ...(current.title_i18n || {}), [locale]: value },
    }));
    setCatalog((current) => updateCatalogLevel(current, currentTarget, (levelItem) => ({
      ...levelItem,
      title: value,
      title_i18n: { ...(levelItem.title_i18n || {}), [locale]: value },
    })));
  }

  function updateLocalizedDescription(value: string) {
    recordEdit(activeMode);
    setLevel((current) => ({
      ...current,
      description: value,
      description_i18n: { ...(current.description_i18n || {}), [locale]: value },
    }));
  }

  function updateTopicName(value: string) {
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) =>
        topic.id === currentTarget.topicId
          ? {
              ...topic,
              name: locale === current.default_locale ? value : topic.name,
              name_i18n: { ...(topic.name_i18n || {}), [locale]: value },
            }
          : topic,
      ),
    }));
  }

  function updateImagePath(path: string) {
    updateModeImagePath(activeMode, path);
  }

  function updateModeImagePath(mode: EditMode, path: string) {
    recordEdit(mode);
    setLevel((current) => {
      const modeConfig = current.modes[mode];
      const imageConfig = typeof modeConfig.image === "string" ? { path: modeConfig.image } : { ...(modeConfig.image || {}) };
      return {
        ...current,
        modes: {
          ...current.modes,
          [mode]: {
            ...modeConfig,
            image: {
              ...imageConfig,
              path: path.trim(),
            },
          },
        },
      };
    });
  }

  function updateGrid<K extends keyof LevelConfig["grid"]>(key: K, value: number) {
    recordEdit("knob");
    const nextValue = key === "piece_size" ? Math.max(80, Math.min(320, Math.round(value))) : Math.max(1, Math.min(12, Math.round(value)));
    const nextGrid = { ...level.grid, [key]: nextValue };
    setLevel((current) => ({
      ...current,
      grid: {
        ...current.grid,
        [key]: nextValue,
      },
      modes: {
        ...current.modes,
        knob: {
          ...current.modes.knob,
          [key]: nextValue,
        },
      },
    }));
    setKnobPieces(generateKnobPieces(image, nextGrid.cols, nextGrid.rows, level.modes.knob.knob_size));
    setSelectedPieceIds([]);
  }

  function commitKnobGrid<K extends keyof LevelConfig["grid"]>(key: K) {
    const fallback = level.grid[key];
    const parsed = Number(knobGridDraft[key]);
    updateGrid(key, Number.isFinite(parsed) ? parsed : fallback);
  }

  function updateKnobSize(value: number) {
    recordEdit("knob");
    setLevel((current) => ({
      ...current,
      modes: {
        ...current.modes,
        knob: {
          ...current.modes.knob,
          knob_size: value,
        },
      },
    }));
    setKnobPieces(generateKnobPieces(image, level.grid.cols, level.grid.rows, value));
    setSelectedPieceIds([]);
  }

  function autoGenerate() {
    recordEdit("polygon");
    const result = generateFractureNetwork(analysis.outline, analysis.bounds, targetPieces);
    setCuts(result.cuts);
    setAnalysisCuts(result.cuts);
    setPieces(result.pieces);
    setSelectedId(result.cuts[0]?.id || "");
  }

  function addPreset(template: CutTemplate) {
    if (!analysis.bounds) return;
    addPresetAt(template, {
      x: analysis.bounds.x + analysis.bounds.width * 0.5,
      y: analysis.bounds.y + analysis.bounds.height * 0.5,
    });
  }

  function addPresetAt(template: CutTemplate, center: Point) {
    if (!analysis.bounds) return;
    recordEdit("polygon");
    const next = translateCut(presetCut(template, analysis.bounds), center);
    setCuts((current) => [...current, next]);
    setSelectedId(next.id);
  }

  function dropShape(event: React.DragEvent<SVGSVGElement>) {
    const template = event.dataTransfer.getData("application/x-jigcat-shape") as CutTemplate;
    if (!template) return;
    event.preventDefault();
    addPresetAt(template, clientPointToSvg(event.clientX, event.clientY));
    setPolygonView("edit");
  }

  function addBridgeCut() {
    if (!analysis.outline.length) return;
    setPolygonView("edit");
    setSelectedId("");
    setDrawingHoverPoint(null);
    setDrawingCut({ id: uid("cut"), points: [] });
    showToast("左键添加点，右键结束线条。");
  }

  function finishDrawingCut() {
    if (!drawingCut) return;
    if (drawingCut.points.length < 2) {
      setDrawingCut(null);
      setDrawingHoverPoint(null);
      showToast("已取消添加线条。");
      return;
    }
    recordEdit("polygon");
    const next: CutLine = {
      id: drawingCut.id,
      type: "fracture",
      template: "knob",
      points: drawingCut.points,
    };
    setCuts((current) => [...current, next]);
    setSelectedId(next.id);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
  }

  function removeSelected() {
    if (!selectedId) return;
    recordEdit("polygon");
    setCuts((current) => current.filter((cut) => cut.id !== selectedId));
    setSelectedId("");
  }

  function clearAllCuts() {
    if (!cuts.length) return;
    recordEdit("polygon");
    setCuts([]);
    setAnalysisCuts([]);
    setPieces([]);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
    showToast("已清空所有线条。");
  }

  function clientPointToSvg(clientX: number, clientY: number): Point {
    const svg = svgRef.current;
    if (!svg) return { x: 0, y: 0 };
    const ctm = svg.getScreenCTM();
    if (ctm) {
      const point = svg.createSVGPoint();
      point.x = clientX;
      point.y = clientY;
      const transformed = point.matrixTransform(ctm.inverse());
      return { x: transformed.x, y: transformed.y };
    }
    const rect = svg.getBoundingClientRect();
    const [minX, minY, width, height] = viewBox.split(" ").map(Number);
    return { x: minX + ((clientX - rect.left) / rect.width) * width, y: minY + ((clientY - rect.top) / rect.height) * height };
  }

  function svgPoint(event: React.PointerEvent<SVGElement>): Point {
    return clientPointToSvg(event.clientX, event.clientY);
  }

  function handleCanvasPointerDown(event: React.PointerEvent<SVGSVGElement>) {
    if (drawingCut) {
      if (event.button !== 0) return;
      event.preventDefault();
      const point = svgPoint(event);
      setDrawingCut((current) => (current ? { ...current, points: [...current.points, point] } : current));
      setDrawingHoverPoint(point);
      return;
    }
    setSelectedId("");
  }

  function handleCanvasContextMenu(event: React.MouseEvent<SVGSVGElement>) {
    if (!drawingCut) return;
    event.preventDefault();
    finishDrawingCut();
  }

  function beginDrag(event: React.PointerEvent<SVGElement>, cutId: string, pointIndex: number | null) {
    if (drawingCut) return;
    event.stopPropagation();
    const cut = cuts.find((item) => item.id === cutId);
    if (!cut) return;
    recordEdit("polygon");
    setSelectedId(cutId);
    setDrag({
      cutId,
      pointIndex,
      start: svgPoint(event),
      original: structuredClone(cut),
    });
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function moveDrag(event: React.PointerEvent<SVGSVGElement>) {
    if (drawingCut) {
      setDrawingHoverPoint(svgPoint(event));
      return;
    }
    if (!drag) return;
    dragPointRef.current = svgPoint(event);
    if (dragFrameRef.current != null) return;
    dragFrameRef.current = window.requestAnimationFrame(() => {
      dragFrameRef.current = null;
      const currentPoint = dragPointRef.current;
      if (!currentPoint) return;
      applyDragMove(currentPoint);
    });
  }

  function applyDragMove(currentPoint: Point) {
    if (!drag) return;
    const dx = currentPoint.x - drag.start.x;
    const dy = currentPoint.y - drag.start.y;
    setCuts((items) =>
      items.map((cut) => {
        if (cut.id !== drag.cutId) return cut;
        const next = structuredClone(drag.original);
        if (drag.pointIndex === null) {
          next.points = next.points.map((point) => ({ x: point.x + dx, y: point.y + dy }));
          if (snapEnabled && next.type !== "preset_shape") {
            const endpoints = [
              { index: 0, point: next.points[0] },
              { index: next.points.length - 1, point: next.points[next.points.length - 1] },
            ];
            const hit = endpoints
              .map((endpoint) => {
                const snap = snapPoint(endpoint.point, snapPoints, cuts, snapThreshold, next.id);
                return snap ? { ...snap, endpoint } : null;
              })
              .filter((item): item is NonNullable<typeof item> => Boolean(item))
              .sort((a, b) => a.distance - b.distance)[0];
            if (hit) {
              const snapDx = hit.point.x - hit.endpoint.point.x;
              const snapDy = hit.point.y - hit.endpoint.point.y;
              next.points = next.points.map((point) => ({ x: point.x + snapDx, y: point.y + snapDy }));
            }
          }
        } else {
          next.points[drag.pointIndex] = { x: next.points[drag.pointIndex].x + dx, y: next.points[drag.pointIndex].y + dy };
          if (snapEnabled && next.type !== "preset_shape") {
            const hit = snapPoint(next.points[drag.pointIndex], snapPoints, cuts, snapThreshold, next.id);
            if (hit) next.points[drag.pointIndex] = { ...hit.point };
          }
        }
        return next;
      }),
    );
  }

  function endDrag() {
    if (dragFrameRef.current != null) {
      window.cancelAnimationFrame(dragFrameRef.current);
      dragFrameRef.current = null;
    }
    const finalPoint = dragPointRef.current;
    if (finalPoint) applyDragMove(finalPoint);
    dragPointRef.current = null;
    setDrag(null);
  }

  function cutPathD(cut: CutLine): string {
    const cached = cutPathCacheRef.current.get(cut);
    if (cached) return cached;
    const value = cut.type === "preset_shape" ? catmullRomPath(cut.points, shapeTension(cut.template), true) : polylinePath(cut.points);
    cutPathCacheRef.current.set(cut, value);
    return value;
  }

  function piecePathD(piece: PieceCell): string {
    const cached = piecePathCacheRef.current.get(piece);
    if (cached) return cached;
    const value = catmullRomPath(piece.points, 0.15, true);
    piecePathCacheRef.current.set(piece, value);
    return value;
  }

  function knobPiecePathD(piece: LevelPiece): string {
    const cached = knobPiecePathCacheRef.current.get(piece);
    if (cached) return cached;
    const value = catmullRomPath(piece.points.map(pointFromTuple), 0.15, true);
    knobPiecePathCacheRef.current.set(piece, value);
    return value;
  }

  function buildJson() {
    const validPolygonPieces = pieces.filter((piece) => piece.points.length >= 3);
    const polygonPieces = validPolygonPieces.map((piece) => ({ id: piece.id, points: serializePoints(piece.points) }));
    const polygonLevelPieces = cellsToLevelPieces(validPolygonPieces);
    const normalizedLevel = normalizeLevelConfig(level, currentTarget.topicId, currentTarget.levelId);
    const data: LevelConfig = {
      ...normalizedLevel,
      id: currentTarget.levelId,
      topic_id: currentTarget.topicId,
      locale,
      title_i18n: reservedI18n(normalizedLevel.title_i18n, normalizedLevel.title),
      description_i18n: reservedI18n(normalizedLevel.description_i18n, normalizedLevel.description),
      modes: {
        polygon: {
          ...level.modes.polygon,
          pieces: polygonLevelPieces,
        },
        knob: {
          ...level.modes.knob,
          rows: Math.max(1, Math.round(level.grid.rows)),
          cols: Math.max(1, Math.round(level.grid.cols)),
          piece_size: level.grid.piece_size,
          knob_size: level.modes.knob.knob_size,
          pieces: knobPieces,
        },
      },
      editor: {
        outline: serializePoints(analysis.outline),
        cuts: cuts
          .filter((cut) => cut.type === "fracture")
          .map((cut) => ({
            id: cut.id,
            type: cut.type,
            template: cut.template,
            points: serializePoints(cut.points),
          })),
        shapes: cuts
          .filter((cut) => cut.type === "preset_shape")
          .map((cut) => ({
            id: cut.id,
            type: cut.type,
            template: cut.template,
            points: serializePoints(cut.points),
          })),
        pieces: polygonPieces,
      },
    };
    const text = JSON.stringify(data, null, 2);
    return text;
  }

  function openSaveDialog() {
    if (!canSaveToGodot) {
      showToast("请先为当前模式选择图片并生成可用碎片。");
      return;
    }
    const topic = catalog.topics.find((item) => item.id === saveDialog.topicId) || catalog.topics[0];
    const levelItem = topic?.levels.find((item) => item.id === saveDialog.levelId) || topic?.levels[0];
    const nextTopicId = idFromEnglishName(saveDialog.newTopicId, "topic", catalog.topics.map((item) => item.id));
    setSaveDialog((current) => ({
      ...current,
      open: true,
      targetMode: current.targetMode || "existing",
      topicId: topic?.id || current.topicId,
      levelId: levelItem?.id || current.levelId,
      title: localized(levelItem?.title_i18n, locale, levelItem?.title || level.title),
      description: level.description,
      newTopicId: current.newTopicId || nextTopicId,
      newLevelTitle: current.newLevelTitle || "新关卡",
    }));
  }

  async function saveJsonToGodot(): Promise<boolean> {
    if (!canSaveToGodot || !activePendingImage) {
      showToast("请先为当前模式选择图片并生成可用碎片。");
      return false;
    }
    const existingTopic = catalog.topics.find((item) => item.id === saveDialog.topicId) || catalog.topics[0];
    const existingLevel = existingTopic?.levels.find((item) => item.id === saveDialog.levelId);
    const targetTopicId =
      saveDialog.targetMode === "new" && saveDialog.newTopic
        ? idFromEnglishName(saveDialog.newTopicId, "topic", catalog.topics.map((item) => item.id))
        : saveDialog.topicId;
    const targetLevelId =
      saveDialog.targetMode === "new"
        ? nextSequentialId("level", (saveDialog.newTopic ? [] : existingTopic?.levels || []).map((item) => item.id))
        : saveDialog.levelId;
    const targetTitle = saveDialog.targetMode === "new" ? saveDialog.newLevelTitle.trim() || "新关卡" : localized(existingLevel?.title_i18n, locale, existingLevel?.title || level.title);
    const targetDescription = saveDialog.targetMode === "new" ? saveDialog.newLevelDescription.trim() : level.description;
    const nextLevel = JSON.parse(buildJson()) as LevelConfig;
    nextLevel.id = targetLevelId;
    nextLevel.topic_id = targetTopicId;
    nextLevel.title = targetTitle;
    nextLevel.description = targetDescription;
    nextLevel.title_i18n = { ...(nextLevel.title_i18n || {}), [locale]: targetTitle };
    nextLevel.description_i18n = { ...(nextLevel.description_i18n || {}), [locale]: targetDescription };
    if (saveDialog.targetMode === "new") {
      nextLevel.background = {
        type: saveDialog.newBackgroundType === "image" && canUseBackgroundImage ? "image" : "color",
        color: saveDialog.newBackgroundColor,
        path: saveDialog.newBackgroundType === "image" && canUseBackgroundImage ? saveDialog.newBackgroundPath : "",
      };
    }
    showToast("保存中...");
    try {
      const response = await fetch("/api/editor/save-mode", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          topicId: targetTopicId,
          levelId: targetLevelId,
          mode: activeMode,
          imageId: activePendingImage.id,
          title: targetTitle,
          description: targetDescription,
          topicName: saveDialog.targetMode === "new" && saveDialog.newTopic ? saveDialog.newTopicName.trim() : undefined,
          level: nextLevel,
        }),
      });
      const result = (await response.json()) as { ok?: boolean; path?: string; error?: string; catalog?: LevelCatalog; topicId?: string; levelId?: string; sharedModes?: EditMode[] };
      if (!response.ok || !result.ok) {
        throw new Error(result.error || `HTTP ${response.status}`);
      }
      showToast(`已保存到 ${result.path}`);
      if (result.catalog) setCatalog(result.catalog);
      setCurrentTarget({ topicId: result.topicId || saveDialog.topicId, levelId: result.levelId || saveDialog.levelId });
      const savedModes = new Set<EditMode>(result.sharedModes?.length ? result.sharedModes : [activeMode]);
      setDirtyModes((current) => ({
        ...current,
        polygon: savedModes.has("polygon") ? false : current.polygon,
        knob: savedModes.has("knob") ? false : current.knob,
      }));
      setCompletedModes((current) => ({
        ...current,
        polygon: savedModes.has("polygon") ? modeReady.polygon : current.polygon,
        knob: savedModes.has("knob") ? modeReady.knob : current.knob,
      }));
      setSaveDialog((current) => ({ ...current, open: false }));
      return true;
    } catch (error) {
      showToast(error instanceof Error ? `保存失败：${error.message}` : "保存失败");
      return false;
    }
  }

  const activeSaveStatus = dirtyModes[activeMode] ? "未保存" : completedModes[activeMode] ? "已保存" : "";

  return (
    <div className="grid h-full min-h-0 grid-cols-[minmax(520px,1fr)_380px] overflow-hidden bg-linen text-ink">
      <main className="grid min-h-0 min-w-0 grid-rows-[auto_1fr] overflow-hidden">
        <div className="grid min-h-14 grid-cols-[1fr_minmax(260px,420px)_1fr] items-center gap-3 overflow-auto border-b border-stone-300 bg-[#f7efe2] px-3">
          <div className="flex min-w-0 items-center gap-3 justify-self-start">
            <ToggleGroup type="single" value={activeMode} onValueChange={(value) => {
              if (value === "polygon" || value === "knob") requestModeChange(value);
            }}>
              <WithTooltip label="多边形">
                <ToggleGroupItem value="polygon" aria-label="多边形" className="relative gap-2 px-3">
                  <Hexagon size={18} />
                  <span>多边形</span>
                  {(completedModes.polygon || dirtyModes.polygon) && <span className={completedModes.polygon ? "statusDot done" : "statusDot dirty"} />}
                </ToggleGroupItem>
              </WithTooltip>
              <WithTooltip label="凹凸">
                <ToggleGroupItem value="knob" aria-label="凹凸" className="relative gap-2 px-3">
                  <Puzzle size={18} />
                  <span>凹凸</span>
                  {(completedModes.knob || dirtyModes.knob) && <span className={completedModes.knob ? "statusDot done" : "statusDot dirty"} />}
                </ToggleGroupItem>
              </WithTooltip>
            </ToggleGroup>
            {activeSaveStatus && <span className={dirtyModes[activeMode] ? "text-sm font-medium text-amber-700" : "text-sm font-medium text-emerald-700"}>{activeSaveStatus}</span>}
          </div>
          <div className="min-w-0">
            <SelectBox value={activePendingImage?.id || ""} options={imageOptions} onValueChange={(id) => selectImageForMode(activeMode, id)} placeholder="选择拼图图片" />
          </div>
          <div className="flex items-center gap-2 justify-self-end">
            <button className="btnPrimary" onClick={markCurrentModeComplete}>
              完成
            </button>
            <button className="btnPrimary" disabled={!canSaveToGodot} onClick={openSaveDialog}>
              <Save size={16} />
              保存模式
            </button>
          </div>
        </div>

        <div className="relative grid min-h-0 place-items-center overflow-hidden p-5" style={canvasBackgroundStyle}>
          <div className="canvasModeBadge">{canvasModeLabel}</div>
          <svg
            ref={svgRef}
            className="h-[min(calc(100vh-96px),760px)] w-full max-w-[1040px] border border-black/15 bg-white/20"
            viewBox={viewBox}
            onPointerMove={moveDrag}
            onPointerUp={endDrag}
            onPointerLeave={endDrag}
            onPointerDown={handleCanvasPointerDown}
            onContextMenu={handleCanvasContextMenu}
            onDragOver={(event) => event.preventDefault()}
            onDrop={dropShape}
          >
            {image && <image href={imageUrl} x="0" y="0" width={image.naturalWidth} height={image.naturalHeight} preserveAspectRatio="xMidYMid meet" />}
            {activeMode === "polygon" && polygonView !== "edit" && actualPreview?.dataUrl && (
              <image href={actualPreview.dataUrl} x="0" y="0" width={image?.naturalWidth || 0} height={image?.naturalHeight || 0} preserveAspectRatio="none" />
            )}
            {activeMode === "polygon" && polygonView === "inspect" &&
              pieces.map((piece) => (
                <path
                  key={piece.id}
                  className={[
                    "pieceSelectable",
                    selectedPieceIds.includes(piece.id) ? "selectedPiece" : "",
                  ]
                    .filter(Boolean)
                    .join(" ")}
                  d={piecePathD(piece)}
                  onPointerDown={(event) => {
                    event.stopPropagation();
                    togglePieceSelection(piece.id);
                  }}
                />
              ))}
            {activeMode === "polygon" && polygonView === "result" &&
              cuts.map((cut) => (
                <path
                  key={cut.id}
                  className="resultCutPath"
                  d={cutPathD(cut)}
                />
              ))}
            {activeMode === "knob" && showKnobPieces &&
              knobPieces.map((piece) => (
                <path
                  key={piece.id}
                  className={selectedPieceIds.includes(piece.id) ? "knobPreview selectedPiece" : "knobPreview"}
                  d={knobPiecePathD(piece)}
                  onPointerDown={(event) => {
                    event.stopPropagation();
                    togglePieceSelection(piece.id);
                  }}
                />
              ))}
            {activeMode === "polygon" && polygonView !== "result" && cuts.map((cut) => (
              <g key={cut.id} className={cut.id === selectedId ? "selected" : ""}>
                <path
                  className={cut.type === "preset_shape" ? "shapePath" : "cutPath"}
                  d={cutPathD(cut)}
                  onPointerDown={(event) => beginDrag(event, cut.id, null)}
                />
                {cut.id === selectedId &&
                  cut.points.map((point, index) => (
                    <circle key={`${cut.id}_${index}`} className="handle" cx={point.x} cy={point.y} r={10} onPointerDown={(event) => beginDrag(event, cut.id, index)} />
                  ))}
              </g>
            ))}
            {activeMode === "polygon" && drawingCut && (
              <g className="drawingCutPreview">
                {drawingCut.points.length > 0 && (
                  <path d={polylinePath(drawingHoverPoint ? [...drawingCut.points, drawingHoverPoint] : drawingCut.points)} />
                )}
                {drawingCut.points.map((point, index) => (
                  <circle key={`${drawingCut.id}_${index}`} cx={point.x} cy={point.y} r={8} />
                ))}
              </g>
            )}
          </svg>
        </div>
      </main>

      <aside className="flex min-h-0 flex-col gap-4 overflow-hidden border-l border-stone-300 bg-paper p-4">
        <section className="grid gap-3">
          <PanelTitle>工具</PanelTitle>
          <div className="grid grid-cols-6 gap-2">
            <WithTooltip label="撤销 (Cmd/Ctrl+Z)"><button className="iconBtn" disabled={!undoStack.length} onClick={undo} aria-label="撤销"><Undo2 size={18} /></button></WithTooltip>
            <WithTooltip label="重做 (Cmd/Ctrl+Shift+Z / Cmd/Ctrl+Y)"><button className="iconBtn" disabled={!redoStack.length} onClick={redo} aria-label="重做"><Redo2 size={18} /></button></WithTooltip>
            <WithTooltip label="吸附"><button className={snapEnabled ? "iconBtnActive" : "iconBtn"} onClick={() => setSnapEnabled((value) => !value)} aria-label="吸附"><Magnet size={18} /></button></WithTooltip>
            <WithTooltip label="合并"><button className="iconBtnActive" onClick={mergeSelectedPieces} aria-label="合并"><Plus size={18} /></button></WithTooltip>
            {activeMode === "polygon" && (
              <WithTooltip label="删除选中线条 (Backspace)"><button className="iconBtnDanger" disabled={!selectedId} onClick={removeSelected} aria-label="删除选中线条"><Trash2 size={18} /></button></WithTooltip>
            )}
            {activeMode === "polygon" && (
              <WithTooltip label="清空线条"><button className="iconBtnDanger" disabled={!cuts.length} onClick={clearAllCuts} aria-label="清空线条"><X size={18} /></button></WithTooltip>
            )}
          </div>
        </section>

        {activeMode === "polygon" && (
          <section className="flex min-h-0 flex-1 flex-col gap-3 border-t border-stone-300 pt-4">
            <PanelTitle>多边形</PanelTitle>
            <div className="grid grid-cols-3 gap-2">
              {(["result", "edit", "inspect"] as PolygonViewMode[]).map((view) => (
                <WithTooltip key={view} label={view === "result" ? "结果" : view === "edit" ? "编辑" : "检查"}>
                  <button className={polygonView === view ? "iconBtnActive" : "iconBtn"} onClick={() => setPolygonView(view)} aria-label={view === "result" ? "结果" : view === "edit" ? "编辑" : "检查"}>
                    {view === "result" ? <Eye size={18} /> : view === "edit" ? <Pencil size={18} /> : <CircleAlert size={18} />}
                  </button>
                </WithTooltip>
              ))}
            </div>
            <Field label={`${targetPieces} 片`}>
              <input type="range" min="6" max="36" value={targetPieces} onChange={(event) => setTargetPieces(Number(event.target.value))} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <button className="btnPrimary" onClick={autoGenerate}>
                <RefreshCcw size={16} />
                生成
              </button>
              <button className={drawingCut ? "btnActive" : "btn"} onClick={drawingCut ? finishDrawingCut : addBridgeCut}>
                <Plus size={16} />
                {drawingCut ? "结束" : "线"}
              </button>
            </div>
            <div className="grid min-h-0 flex-1 grid-cols-3 content-start gap-2 overflow-auto pr-1">
              {presetTemplates.map((template) => (
                <ShapeButton key={template} template={template} onClick={() => addPreset(template)} />
              ))}
            </div>
          </section>
        )}

        {activeMode === "knob" && (
          <section className="grid gap-3 border-t border-stone-300 pt-4">
            <PanelTitle>凹凸</PanelTitle>
            <button className={showKnobPieces ? "btnActive" : "btn"} onClick={() => setShowKnobPieces((value) => !value)}>
              <Eye size={16} />
              预览
            </button>
            <div className="grid grid-cols-2 gap-2">
              <Field label="列">
                <Input
                  type="number"
                  min="1"
                  max="12"
                  step="1"
                  value={knobGridDraft.cols}
                  onChange={(event) => setKnobGridDraft((current) => ({ ...current, cols: event.target.value }))}
                  onBlur={() => commitKnobGrid("cols")}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") event.currentTarget.blur();
                  }}
                />
              </Field>
              <Field label="行">
                <Input
                  type="number"
                  min="1"
                  max="12"
                  step="1"
                  value={knobGridDraft.rows}
                  onChange={(event) => setKnobGridDraft((current) => ({ ...current, rows: event.target.value }))}
                  onBlur={() => commitKnobGrid("rows")}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") event.currentTarget.blur();
                  }}
                />
              </Field>
            </div>
            <Field label="尺寸">
              <Input
                type="number"
                min="80"
                max="320"
                step="10"
                value={knobGridDraft.piece_size}
                onChange={(event) => setKnobGridDraft((current) => ({ ...current, piece_size: event.target.value }))}
                onBlur={() => commitKnobGrid("piece_size")}
                onKeyDown={(event) => {
                  if (event.key === "Enter") event.currentTarget.blur();
                }}
              />
            </Field>
            <Field label={`凸耳 ${level.modes.knob.knob_size.toFixed(2)}`}>
              <input type="range" min="0.12" max="0.36" step="0.01" value={level.modes.knob.knob_size} onChange={(event) => updateKnobSize(Number(event.target.value))} />
            </Field>
          </section>
        )}
      </aside>
      {saveDialog.open && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-lg rounded-lg border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-xl font-semibold">保存当前模式</h2>
                <p className="mt-1 text-sm text-muted">当前图片会复制到目标关卡文件夹。</p>
              </div>
              <button className="iconBtn" onClick={() => setSaveDialog((current) => ({ ...current, open: false }))} aria-label="关闭">
                <X size={18} />
              </button>
            </div>
            <div className="mt-5 grid gap-3">
              <div className="grid grid-cols-2 gap-2">
                <button className={saveDialog.targetMode === "existing" ? "btnActive" : "btn"} onClick={() => setSaveDialog((current) => ({ ...current, targetMode: "existing" }))}>
                  选择模式
                </button>
                <button className={saveDialog.targetMode === "new" ? "btnActive" : "btn"} onClick={() => setSaveDialog((current) => ({ ...current, targetMode: "new" }))}>
                  新增模式
                </button>
              </div>
              {saveDialog.targetMode === "existing" ? (
                <>
                  <Field label="主题">
                    <SelectBox
                      value={saveDialog.topicId}
                      options={topicOptions}
                      onValueChange={(topicId) => {
                        const topic = catalog.topics.find((item) => item.id === topicId);
                        const firstLevel = topic?.levels[0];
                        setSaveDialog((current) => ({
                          ...current,
                          topicId,
                          levelId: firstLevel?.id || "",
                          title: firstLevel?.title || current.title,
                        }));
                      }}
                      placeholder="选择主题"
                    />
                  </Field>
                  <Field label="关卡">
                    <SelectBox
                      value={saveDialog.levelId}
                      options={saveLevelOptions}
                      onValueChange={(levelId) => {
                        const levelItem = saveTopic?.levels.find((item) => item.id === levelId);
                        setSaveDialog((current) => ({ ...current, levelId, title: levelItem?.title || current.title }));
                      }}
                      placeholder="选择关卡"
                    />
                  </Field>
                </>
              ) : (
                <>
                  <label className="flex items-center gap-2 text-sm text-ink">
                    <input className="h-4 w-4 accent-clay" type="checkbox" checked={saveDialog.newTopic} onChange={(event) => setSaveDialog((current) => ({ ...current, newTopic: event.target.checked }))} />
                    新增主题
                  </label>
                  {saveDialog.newTopic ? (
                    <>
                      <Field label="主题">
                        <Input value={saveDialog.newTopicName} onChange={(event) => setSaveDialog((current) => ({ ...current, newTopicName: event.target.value }))} />
                      </Field>
                      <Field label="英文名称">
                        <Input
                          value={saveDialog.newTopicId}
                          onChange={(event) => setSaveDialog((current) => ({ ...current, newTopicId: idFromEnglishName(event.target.value, "topic", []) }))}
                        />
                      </Field>
                    </>
                  ) : (
                    <Field label="主题">
                      <SelectBox
                        value={saveDialog.topicId}
                        options={topicOptions}
                        onValueChange={(topicId) => setSaveDialog((current) => ({ ...current, topicId }))}
                        placeholder="选择主题"
                      />
                    </Field>
                  )}
                  <Field label="关卡">
                    <Input value={saveDialog.newLevelTitle} onChange={(event) => setSaveDialog((current) => ({ ...current, newLevelTitle: event.target.value }))} />
                  </Field>
                  <Field label="关卡介绍">
                    <Textarea className="min-h-20" value={saveDialog.newLevelDescription} onChange={(event) => setSaveDialog((current) => ({ ...current, newLevelDescription: event.target.value }))} />
                  </Field>
                  <div className="grid gap-2 rounded-md border border-stone-200 bg-white/60 p-3">
                    <div className="text-sm font-medium text-ink">关卡背景</div>
                    <div className="flex flex-wrap items-center gap-3">
                      <ToggleGroup
                        type="single"
                        value={saveDialog.newBackgroundType}
                        onValueChange={(value) => {
                          if (value === "color") setSaveDialog((current) => ({ ...current, newBackgroundType: "color" }));
                          if (value === "image" && canUseBackgroundImage) {
                            setSaveDialog((current) => ({ ...current, newBackgroundType: "image", newBackgroundPath: current.newBackgroundPath || backgroundImages[0]?.path || "" }));
                          }
                        }}
                      >
                        <ToggleGroupItem value="color">纯色</ToggleGroupItem>
                        <ToggleGroupItem value="image" disabled={!canUseBackgroundImage}>
                          图片
                        </ToggleGroupItem>
                      </ToggleGroup>
                      {saveDialog.newBackgroundType === "image" && canUseBackgroundImage ? (
                        <div className="w-64">
                          <SelectBox
                            value={saveDialog.newBackgroundPath}
                            options={backgroundImageOptions}
                            onValueChange={(newBackgroundPath) => setSaveDialog((current) => ({ ...current, newBackgroundPath }))}
                            placeholder="选择背景图片"
                          />
                        </div>
                      ) : (
                        <input
                          className="h-9 w-24 rounded border border-stone-300 bg-white p-1"
                          type="color"
                          value={saveDialog.newBackgroundColor}
                          onChange={(event) => setSaveDialog((current) => ({ ...current, newBackgroundColor: event.target.value }))}
                          aria-label="背景颜色"
                        />
                      )}
                      {!canUseBackgroundImage && <span className="text-xs text-muted">暂无背景图片</span>}
                    </div>
                  </div>
                </>
              )}
              <div className="px-1 py-1 text-sm text-muted">
                写入模式：{activeMode === "polygon" ? "多边形" : "凹凸"}；图片：{activePendingImage ? displayPendingImageName(activePendingImage) : "未选择"}
              </div>
            </div>
            <div className="mt-5 grid grid-cols-2 gap-2">
              <button className="btn" onClick={() => setSaveDialog((current) => ({ ...current, open: false }))}>
                取消
              </button>
              <button className="btnPrimary" onClick={() => void saveJsonToGodot()}>
                保存
              </button>
            </div>
          </div>
        </div>
      )}
      {pendingMode && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-lg border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-xl font-semibold">当前模式有未保存修改</h2>
            <p className="mt-2 text-sm text-muted">切换到其他模式前，建议先保存到 Godot。继续切换不会丢弃当前数据，但这些修改仍会保持未保存状态。</p>
            <div className="mt-5 grid grid-cols-2 gap-2">
              <button className="btn" onClick={() => setPendingMode(null)}>
                继续编辑
              </button>
              <button className="btnPrimary" onClick={() => switchMode(pendingMode)}>
                切换模式
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
