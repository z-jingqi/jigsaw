import { useEffect, useMemo, useRef, useState } from "react";
import { PointerSensor, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { arrayMove } from "@dnd-kit/sortable";
import { toast } from "sonner";
import {
  EMPTY_IMAGE_PATH,
  analyzeActualPieces,
  detectImageOutline,
  findCutIntersections,
  findCutGaps,
  generateKnobPieces,
  makeEmptyLevel,
  presetCut,
  samplePath,
  serializePoints,
  snapPoint,
  uid,
} from "../geometry";
import type { CatalogLevel, CutLine, CutTemplate, LevelCatalog, LevelConfig, LevelPiece, OutlineAnalysis, PieceCell, Point, PendingImageEditorState, PendingImageItem } from "../types";
import { cellsToLevelPieces, mergePolygons, pointFromTuple, polygonCenter, polylinePath, translateCut, tupleBounds, tupleFromPoint, unionTupleBounds, visibleBoundsList } from "../features/level-editor/lib/polygonPieces";
import { type SelectOption } from "../shared/ui/SelectBox";
import { makeDefaultCatalog, normalizeOrder, updateCatalogLevel } from "../shared/lib/catalog";
import { idFromEnglishName, nextSequentialId } from "../shared/lib/ids";
import { localized, reservedI18n } from "../shared/lib/i18n";
import { EditorTopBar } from "../features/level-editor/components/EditorTopBar";
import { EditorCanvas } from "../features/level-editor/components/EditorCanvas";
import { EditorToolbox } from "../features/level-editor/components/EditorToolbox";
import { PolygonModePanel } from "../features/level-editor/components/PolygonModePanel";
import { KnobModePanel } from "../features/level-editor/components/KnobModePanel";
import { EditorSaveDialog } from "../features/level-editor/components/EditorSaveDialog";
import { EditorModeSwitchDialog } from "../features/level-editor/components/EditorModeSwitchDialog";
import { useEditorHistory } from "../features/level-editor/hooks/useEditorHistory";
import { useAnalysisWorker } from "../features/level-editor/hooks/useAnalysisWorker";
import { useEditorCanvasView } from "../features/level-editor/hooks/useEditorCanvasView";
import {
  DEFAULT_CUT_COLOR,
  EDITOR_LOCALE,
  SNAP_THRESHOLD,
  clamp,
  cloneSnapshot,
  displayPendingImageName,
  imageConfigPath,
  isTextEditingTarget,
  levelImageUrl,
  modeImageConfig,
  modeImagePath,
  normalizeLevelConfig,
  polygonViewLabel,
  scaleCutPoints,
} from "../features/level-editor/lib/editor";
import type {
  DragState,
  DrawingCutState,
  EditMode,
  EditorSnapshot,
  LevelTarget,
  PolygonViewMode,
  SaveModeDialogState,
  SnapConnectionMarker,
} from "../features/level-editor/types";

type ImageTarget = EditMode;

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
};

type CreateDialogKind = "topic" | "level" | null;

function App({ onUnsavedChange }: Props) {
  const [catalog, setCatalog] = useState<LevelCatalog>(() => makeDefaultCatalog());
  const locale = EDITOR_LOCALE;
  const [currentTarget, setCurrentTarget] = useState<LevelTarget>({ topicId: "", levelId: "" });
  const [pendingTarget, setPendingTarget] = useState<LevelTarget | null>(null);
  const [level, setLevel] = useState<LevelConfig>(() => makeEmptyLevel());
  const [pendingImages, setPendingImages] = useState<PendingImageItem[]>([]);
  const [backgroundImages, setBackgroundImages] = useState<PendingImageItem[]>([]);
  const [selectedImages, setSelectedImages] = useState<Record<EditMode, PendingImageItem | null>>({ polygon: null, knob: null });
  const [saveDialog, setSaveDialog] = useState<SaveModeDialogState>({
    open: false,
    targetMode: "existing",
    topicId: "",
    levelId: "",
    newTopic: false,
    title: "",
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
  const [imageUrl, setImageUrl] = useState("");
  const [analysis, setAnalysis] = useState<OutlineAnalysis>({ outline: [], edgePoints: [], bounds: null });
  const [activeMode, setActiveMode] = useState<EditMode>("polygon");
  const [cuts, setCuts] = useState<CutLine[]>([]);
  const [pieces, setPieces] = useState<PieceCell[]>([]);
  const [knobPieces, setKnobPieces] = useState<LevelPiece[]>([]);
  const [analysisCuts, setAnalysisCuts] = useState<CutLine[]>([]);
  const [selectedPieceIds, setSelectedPieceIds] = useState<string[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [drag, setDrag] = useState<DragState | null>(null);
  const [polygonAnalysisDirty, setPolygonAnalysisDirty] = useState(false);
  const [snapEnabled, setSnapEnabled] = useState(true);
  const [showKnobPieces, setShowKnobPieces] = useState(true);
  const [polygonView, setPolygonView] = useState<PolygonViewMode>("result");
  const [lineToolActive, setLineToolActive] = useState(false);
  // 切割线颜色按"关卡"维度保存（在 level.json 的 editor.cut_color），polygon 与 knob 模式共用。
  const [cutLineColor, setCutLineColor] = useState<string>(DEFAULT_CUT_COLOR);
  const [drawingCut, setDrawingCut] = useState<DrawingCutState | null>(null);
  const [drawingHoverPoint, setDrawingHoverPoint] = useState<Point | null>(null);
  const [dirtyModes, setDirtyModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [completedModes, setCompletedModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [knobGridDraft, setKnobGridDraft] = useState({ cols: "8", rows: "8", piece_size: "190" });
  const [pendingMode, setPendingMode] = useState<EditMode | null>(null);
  const [createDialog, setCreateDialog] = useState<CreateDialogKind>(null);

  const history = useEditorHistory();

  const [actualPreview, setActualPreview] = useState<ReturnType<typeof analyzeActualPieces> | null>(null);
  const analysisWorker = useAnalysisWorker(setActualPreview);

  const svgRef = useRef<SVGSVGElement | null>(null);
  const cutPathCacheRef = useRef<WeakMap<CutLine, string>>(new WeakMap());
  const piecePathCacheRef = useRef<WeakMap<PieceCell, string>>(new WeakMap());
  const knobPiecePathCacheRef = useRef<WeakMap<LevelPiece, string>>(new WeakMap());
  const dragFrameRef = useRef<number | null>(null);
  const dragPointRef = useRef<Point | null>(null);
  // 一次方向键按下→抬起期间的连续微移共享同一个 undo 项，避免按住方向键产生大量历史记录。
  const nudgeSessionRef = useRef(false);
  // 用户在空白画布上按下并拖拽时的 pan 状态。每次 pointermove 都基于 lastClient 增量更新 pan，
  // 避免累计 client→svg 的转换误差，且 zoom 变化时不需要重新计算。
  const panDragRef = useRef<{
    pointerId: number;
    lastClientX: number;
    lastClientY: number;
    svgRect: DOMRect;
    viewBoxWidth: number;
    viewBoxHeight: number;
    moved: boolean;
  } | null>(null);
  const editorStateSaveTimerRef = useRef<number | null>(null);
  const editorStateHydratingRef = useRef(false);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  useEffect(() => {
    void loadCatalog();
  }, []);

  useEffect(() => () => onUnsavedChange?.(false), [onUnsavedChange]);

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
  const activeLevelImageConfig = modeImageConfig(level, activeMode);
  const activeLevelImagePath = imageConfigPath(activeLevelImageConfig);
  const activeLevelImageName = typeof activeLevelImageConfig === "string" ? "source.png" : activeLevelImageConfig.name || "source.png";
  const canvasBackgroundStyle = { backgroundColor: level.background.color };

  useEffect(() => {
    if (!activePendingImage) {
      const url = levelImageUrl(currentTarget.topicId, currentTarget.levelId, activeLevelImagePath);
      if (!url) {
        clearEditorImage();
        return;
      }
      loadEditorImage(url, activeLevelImageName, activeLevelImagePath || EMPTY_IMAGE_PATH, activeMode, false);
      return;
    }
    loadEditorImage(activePendingImage.url, activePendingImage.name, activePendingImage.path, activeMode);
  }, [activeMode, activeLevelImageName, activeLevelImagePath, activePendingImage?.id, activePendingImage?.url, currentTarget.levelId, currentTarget.topicId]);

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
        setSaveDialog((current) => ({
          ...current,
          topicId: firstTopic.id,
          levelId: firstLevel.id,
          title: firstLevel.title,
        }));
      }
      // 并行拉关卡 + pending 图片，最后一次性 hydrate，避免「先看到关卡线段、再看到图片草稿」的闪烁。
      const [levelData, pendingData] = await Promise.all([
        firstTopic && firstLevel
          ? fetchLevelConfig(firstTopic.id, firstLevel.id, firstLevel)
          : Promise.resolve<LevelConfig | null>(null),
        fetchPendingPool(),
      ]);
      hydrateInitialEditorState({
        levelData,
        topicId: firstTopic?.id || "",
        levelId: firstLevel?.id || "",
        catalogLevel: firstLevel,
        pendingItems: pendingData.items,
        tableclothItems: pendingData.tablecloths,
        preferredImageId: params.get("image") || "",
      });
      const requestedMode = params.get("mode");
      if (requestedMode === "polygon" || requestedMode === "knob") setActiveMode(requestedMode);
    } catch (error) {
      showToast(error instanceof Error ? `加载 catalog 失败：${error.message}` : "加载 catalog 失败");
      await loadPendingImages(new URLSearchParams(window.location.search).get("image") || "");
    }
  }

  async function fetchLevelConfig(topicId: string, levelId: string, catalogLevel?: CatalogLevel): Promise<LevelConfig> {
    try {
      const response = await fetch(`/api/levels/${topicId}/${levelId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return (await response.json()) as LevelConfig;
    } catch (error) {
      const fallback = makeEmptyLevel();
      fallback.id = levelId;
      fallback.topic_id = topicId;
      fallback.title = catalogLevel?.title || levelId;
      fallback.title_i18n = catalogLevel?.title_i18n || { [locale]: fallback.title };
      fallback.image.path = catalogLevel?.source || "";
      fallback.modes.polygon.image = { path: catalogLevel?.source || "", name: "", width: 0, height: 0 };
      fallback.modes.knob.image = { path: catalogLevel?.source || "", name: "", width: 0, height: 0 };
      showToast(error instanceof Error ? `加载关卡失败：${error.message}` : "加载关卡失败");
      return fallback;
    }
  }

  async function fetchPendingPool(): Promise<{ items: PendingImageItem[]; tablecloths: PendingImageItem[] }> {
    try {
      const response = await fetch("/api/pending-images");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { ok?: boolean; items?: PendingImageItem[] };
      const availableItems = (data.items || []).filter((item) => !item.processed_path);
      return {
        items: availableItems.filter((item) => item.kind !== "tablecloth"),
        tablecloths: availableItems.filter((item) => item.kind === "tablecloth"),
      };
    } catch (error) {
      showToast(error instanceof Error ? `加载图片池失败：${error.message}` : "加载图片池失败");
      return { items: [], tablecloths: [] };
    }
  }

  async function loadPendingImages(preferredId = "", applySelection = true) {
    const data = await fetchPendingPool();
    setPendingImages(data.items);
    setBackgroundImages(data.tablecloths);
    setSaveDialog((current) => ({
      ...current,
      newBackgroundPath: current.newBackgroundPath || data.tablecloths[0]?.path || "",
      newBackgroundType: current.newBackgroundType === "image" && !data.tablecloths.length ? "color" : current.newBackgroundType,
    }));
    if (!applySelection) return;
    const preferred = data.items.find((item) => item.id === preferredId) || data.items.find((item) => item.processed) || data.items[0] || null;
    if (preferred) {
      setSelectedImages({ polygon: preferred, knob: preferred });
      applyPendingImageToMode("polygon", preferred);
      applyPendingImageToMode("knob", preferred);
    }
  }

  async function loadLevel(topicId: string, levelId: string, catalogLevel?: CatalogLevel) {
    const data = await fetchLevelConfig(topicId, levelId, catalogLevel);
    applyLoadedLevel(data, topicId, levelId);
  }

  /** 选定 mode 的初始数据：若 image 草稿非空就用草稿；否则用 level.json 里的数据。和首次 hydrate / 切换图片走一致的判断。 */
  function pickInitialModeState(mode: EditMode, item: PendingImageItem | null, levelData: LevelConfig | null) {
    const modeState = item?.editor_state?.[mode];
    const polygonHasDraft =
      mode === "polygon" &&
      Boolean(
        modeState &&
          ((modeState.cuts?.length ?? 0) > 0 ||
            (modeState.pieces?.length ?? 0) > 0 ||
            modeState.dirty ||
            modeState.completed ||
            modeState.saved),
      );
    const knobHasDraft =
      mode === "knob" &&
      Boolean(
        modeState &&
          ((modeState.knob_pieces?.length ?? 0) > 0 || modeState.dirty || modeState.completed || modeState.saved),
      );

    if (mode === "polygon") {
      if (polygonHasDraft && modeState) {
        const cuts = structuredClone(modeState.cuts || []) as CutLine[];
        const pieces = structuredClone(modeState.pieces || []) as PieceCell[];
        return {
          cuts,
          pieces,
          knobPieces: [] as LevelPiece[],
          dirty: Boolean(modeState.dirty),
          completed: Boolean(modeState.completed || modeState.saved || item?.saved_modes?.includes("polygon")),
          analysisDirty: Boolean(modeState.analysis_dirty),
        };
      }
      const importedCuts: CutLine[] = [
        ...((levelData?.editor?.cuts || []).map((cut) => ({ ...cut, points: cut.points.map(([x, y]) => ({ x, y })) }))),
        ...((levelData?.editor?.shapes || []).map((shape) => ({ ...shape, points: shape.points.map(([x, y]) => ({ x, y })) }))),
      ];
      const importedPieces: PieceCell[] = (levelData?.editor?.pieces || []).map((piece) => ({
        ...piece,
        points: piece.points.map(([x, y]) => ({ x, y })),
      })) as PieceCell[];
      return {
        cuts: importedCuts,
        pieces: importedPieces,
        knobPieces: [] as LevelPiece[],
        dirty: false,
        completed:
          Boolean(levelData?.modes?.polygon?.pieces?.length) || Boolean(item?.saved_modes?.includes("polygon")),
        analysisDirty: false,
      };
    }
    if (knobHasDraft && modeState) {
      return {
        cuts: [] as CutLine[],
        pieces: [] as PieceCell[],
        knobPieces: structuredClone(modeState.knob_pieces || []) as LevelPiece[],
        dirty: Boolean(modeState.dirty),
        completed: Boolean(modeState.completed || modeState.saved || item?.saved_modes?.includes("knob")),
        analysisDirty: false,
      };
    }
    return {
      cuts: [] as CutLine[],
      pieces: [] as PieceCell[],
      knobPieces: (levelData?.modes?.knob?.pieces || []) as LevelPiece[],
      dirty: false,
      completed: Boolean(levelData?.modes?.knob?.pieces?.length) || Boolean(item?.saved_modes?.includes("knob")),
      analysisDirty: false,
    };
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
    applyPendingEditorStateToMode(mode, item);
  }

  function selectImageForMode(mode: EditMode, imageId: string) {
    const item = pendingImages.find((candidate) => candidate.id === imageId) || null;
    if (!item) return;
    const previous = selectedImages[mode];
    if (previous) {
      const latestPrevious = pendingImages.find((candidate) => candidate.id === previous.id) || previous;
      void persistPendingEditorState(latestPrevious, pendingEditorStateForCurrentMode(latestPrevious, mode));
    }
    setSelectedImages((current) => ({ ...current, [mode]: item }));
    applyPendingImageToMode(mode, item);
  }

  function applyPendingEditorStateToMode(mode: EditMode, item: PendingImageItem) {
    editorStateHydratingRef.current = true;
    const modeState = item.editor_state?.[mode];
    // 只有当图片实际有草稿（已编辑过/已保存过/含数据），才覆盖编辑器中现有的 cuts/pieces/knobPieces；
    // 否则保留来自 level.json 的数据（避免新图片把关卡已有的形状清空）。
    const polygonHasDraft =
      mode === "polygon" &&
      Boolean(
        modeState &&
          ((modeState.cuts?.length ?? 0) > 0 ||
            (modeState.pieces?.length ?? 0) > 0 ||
            modeState.dirty ||
            modeState.completed ||
            modeState.saved),
      );
    const knobHasDraft =
      mode === "knob" &&
      Boolean(
        modeState &&
          ((modeState.knob_pieces?.length ?? 0) > 0 || modeState.dirty || modeState.completed || modeState.saved),
      );

    const hasDraft = mode === "polygon" ? polygonHasDraft : knobHasDraft;
    if (mode === "polygon" && polygonHasDraft) {
      const nextCuts = structuredClone(modeState!.cuts || []);
      const nextPieces = modeState!.pieces || [];
      setCuts(nextCuts);
      setAnalysisCuts(nextCuts);
      setPieces(structuredClone(nextPieces));
      setPolygonAnalysisDirty(Boolean(modeState!.analysis_dirty));
    } else if (mode === "knob" && knobHasDraft) {
      const savedKnobPieces = modeState!.knob_pieces || [];
      setKnobPieces(structuredClone(savedKnobPieces));
    }
    setSelectedId("");
    setSelectedPieceIds([]);
    // 仅当图片有草稿时才用图片的 dirty/completed 覆盖；否则保留 applyLoadedLevel 写入的关卡级状态。
    if (hasDraft) {
      setDirtyModes((current) => ({ ...current, [mode]: Boolean(modeState?.dirty) }));
      setCompletedModes((current) => ({ ...current, [mode]: Boolean(modeState?.completed || modeState?.saved || item.saved_modes?.includes(mode)) }));
    } else if (item.saved_modes?.includes(mode)) {
      setCompletedModes((current) => ({ ...current, [mode]: true }));
    }
    window.setTimeout(() => {
      editorStateHydratingRef.current = false;
    }, 0);
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
    setCutLineColor(data.editor?.cut_color || DEFAULT_CUT_COLOR);
    setPolygonAnalysisDirty(false);
    setLineToolActive(false);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDirtyModes({ polygon: false, knob: false });
    setCompletedModes({
      polygon: Boolean(data.modes?.polygon?.pieces?.length),
      knob: Boolean(data.modes?.knob?.pieces?.length),
    });
    history.reset();
  }

  /**
   * 首次进入编辑器时，把 level + pending image 一次性写入所有 state，避免：
   * 1) 先 setCuts(level) → 渲染 → setCuts(image draft) 的两帧闪烁；
   * 2) 切换 image / 关卡时遗留的过渡状态。
   */
  function hydrateInitialEditorState(args: {
    levelData: LevelConfig | null;
    topicId: string;
    levelId: string;
    catalogLevel?: CatalogLevel;
    pendingItems: PendingImageItem[];
    tableclothItems: PendingImageItem[];
    preferredImageId: string;
  }) {
    const { levelData, topicId, levelId, pendingItems, tableclothItems, preferredImageId } = args;
    setPendingImages(pendingItems);
    setBackgroundImages(tableclothItems);
    setSaveDialog((current) => ({
      ...current,
      newBackgroundPath: current.newBackgroundPath || tableclothItems[0]?.path || "",
      newBackgroundType: current.newBackgroundType === "image" && !tableclothItems.length ? "color" : current.newBackgroundType,
    }));
    if (!levelData) return;
    const preferred =
      pendingItems.find((item) => item.id === preferredImageId) ||
      pendingItems.find((item) => item.processed) ||
      pendingItems[0] ||
      null;
    const baseLevel = normalizeLevelConfig(levelData, topicId, levelId);
    const polygonInitial = pickInitialModeState("polygon", preferred, levelData);
    const knobInitial = pickInitialModeState("knob", preferred, levelData);
    const nextLevel: LevelConfig = preferred
      ? {
          ...baseLevel,
          modes: {
            polygon: {
              ...baseLevel.modes.polygon,
              image: {
                path: preferred.path,
                name: preferred.name,
                width: preferred.source_info.width,
                height: preferred.source_info.height,
              },
            },
            knob: {
              ...baseLevel.modes.knob,
              image: {
                path: preferred.path,
                name: preferred.name,
                width: preferred.source_info.width,
                height: preferred.source_info.height,
              },
            },
          },
        }
      : baseLevel;
    editorStateHydratingRef.current = true;
    setCurrentTarget({ topicId, levelId });
    setLevel(nextLevel);
    setCuts(polygonInitial.cuts);
    setAnalysisCuts(polygonInitial.cuts);
    setPieces(polygonInitial.pieces);
    setKnobPieces(knobInitial.knobPieces);
    setCutLineColor(levelData.editor?.cut_color || DEFAULT_CUT_COLOR);
    setPolygonAnalysisDirty(polygonInitial.analysisDirty);
    setLineToolActive(false);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDirtyModes({ polygon: polygonInitial.dirty, knob: knobInitial.dirty });
    setCompletedModes({ polygon: polygonInitial.completed, knob: knobInitial.completed });
    if (preferred) {
      setSelectedImages({ polygon: preferred, knob: preferred });
    }
    history.reset();
    window.setTimeout(() => {
      editorStateHydratingRef.current = false;
    }, 0);
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
    analysisWorker.setWorkerImageReady(false);
    if (!image) return;
    const worker = analysisWorker.workerRef.current;
    if (!worker || !("createImageBitmap" in window)) return;
    let cancelled = false;
    const requestId = analysisWorker.imageRequestIdRef.current + 1;
    analysisWorker.imageRequestIdRef.current = requestId;
    void createImageBitmap(image)
      .then((bitmap) => {
        if (cancelled) {
          bitmap.close();
          return;
        }
        worker.postMessage({ type: "setImage", requestId, image: bitmap }, [bitmap]);
      })
      .catch(() => {
        if (analysisWorker.imageRequestIdRef.current === requestId) analysisWorker.setWorkerImageReady(false);
      });
    return () => {
      cancelled = true;
    };
  }, [image]);

  const selected = cuts.find((cut) => cut.id === selectedId) || null;
  const canvasView = useEditorCanvasView({ image, locked: Boolean(drag) });
  const viewBox = canvasView.viewBox;
  const snapPoints = useMemo(() => {
    if (!analysis.outline.length) return [];
    return samplePath([...analysis.outline, analysis.outline[0]], Math.min(300, Math.max(100, analysis.outline.length)));
  }, [analysis.outline]);
  const generatedKnobPieces = useMemo(
    () => (activeMode === "knob" ? generateKnobPieces(image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size) : []),
    [activeMode, image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size],
  );
  const effectiveKnobPieces = useMemo(
    () => (knobPieces.length ? knobPieces : generatedKnobPieces),
    [knobPieces, generatedKnobPieces],
  );
  const modeReady = {
    polygon: pieces.length > 0 && !polygonAnalysisDirty,
    knob: effectiveKnobPieces.length > 0,
  };
  const cutIntersections = useMemo(() => findCutIntersections(cuts), [cuts]);
  const cutGaps = useMemo(() => findCutGaps(cuts, snapPoints, 2.5, SNAP_THRESHOLD), [cuts, snapPoints]);
  const snapConnectionMarkers = useMemo<SnapConnectionMarker[]>(() => {
    const markers: SnapConnectionMarker[] = [];
    const seen = new Set<string>();
    for (const cut of cuts) {
      if (cut.type !== "fracture" || cut.points.length < 2) continue;
      const endpoints = [
        { id: "start", point: cut.points[0] },
        { id: "end", point: cut.points[cut.points.length - 1] },
      ];
      for (const endpoint of endpoints) {
        const hit = snapPoint(endpoint.point, snapPoints, cuts, 2.5, cut.id);
        if (!hit) continue;
        const key = `${Math.round(hit.point.x * 10)},${Math.round(hit.point.y * 10)},${hit.kind}`;
        if (seen.has(key)) continue;
        seen.add(key);
        markers.push({ id: key, point: hit.point, kind: hit.kind });
      }
    }
    return markers;
  }, [cuts, snapPoints]);
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
    if (!analysisCuts.length) {
      setActualPreview(null);
      return;
    }
    const requestId = analysisWorker.analysisRequestIdRef.current + 1;
    analysisWorker.analysisRequestIdRef.current = requestId;
    const worker = analysisWorker.workerRef.current;
    if (worker && analysisWorker.workerImageReady) {
      worker.postMessage({ type: "analyze", requestId, cuts: analysisCuts, maxSize: 840 });
      return;
    }
    const timeout = window.setTimeout(() => {
      if (requestId !== analysisWorker.analysisRequestIdRef.current) return;
      setActualPreview(analyzeActualPieces(image, analysisCuts, 840));
    }, 0);
    return () => window.clearTimeout(timeout);
  }, [image, analysisCuts, analysisWorker.workerImageReady]);

  useEffect(() => {
    if (!analysisCuts.length) {
      setPieces([]);
      setSelectedPieceIds([]);
      return;
    }
    if (!actualPreview) return;
    setPieces(actualPreview.pieces);
    setSelectedPieceIds((current) => current.filter((id) => actualPreview.pieces.some((piece) => piece.id === id)));
    setPolygonAnalysisDirty(false);
  }, [actualPreview, analysisCuts.length]);

  useEffect(() => {
    if (activeMode !== "polygon") return;
    if (editorStateHydratingRef.current) return;
    if (drag) return;
    if (analysisCuts === cuts) return;
    if (!cuts.length) {
      if (analysisCuts.length) {
        setAnalysisCuts([]);
        setPieces([]);
        setActualPreview(null);
        setSelectedPieceIds([]);
        setPolygonAnalysisDirty(false);
      }
      return;
    }
    setPolygonAnalysisDirty(true);
    const timer = window.setTimeout(() => {
      setAnalysisCuts(cuts);
    }, 250);
    return () => window.clearTimeout(timer);
  }, [activeMode, analysisCuts, cuts, drag]);


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

  useEffect(() => {
    if (!activePendingImage || editorStateHydratingRef.current) return;
    if (editorStateSaveTimerRef.current != null) window.clearTimeout(editorStateSaveTimerRef.current);
    editorStateSaveTimerRef.current = window.setTimeout(() => {
      const latestItem = pendingImages.find((item) => item.id === activePendingImage.id) || activePendingImage;
      void persistPendingEditorState(latestItem, pendingEditorStateForCurrentMode(latestItem));
    }, 450);
    return () => {
      if (editorStateSaveTimerRef.current != null) window.clearTimeout(editorStateSaveTimerRef.current);
    };
  }, [
    activeMode,
    activePendingImage?.id,
    cuts,
    pieces,
    effectiveKnobPieces,
    dirtyModes,
    completedModes,
    polygonAnalysisDirty,
  ]);

  function snapshot(): EditorSnapshot {
    return cloneSnapshot({ level, cuts, pieces, knobPieces, completedModes, cutLineColor });
  }

  function recordEdit(mode: EditMode = activeMode) {
    history.pushUndo(snapshot());
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
    setCutLineColor(next.cutLineColor || DEFAULT_CUT_COLOR);
    setPolygonAnalysisDirty(false);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDrag(null);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
  }

  function pendingEditorStateForCurrentMode(item: PendingImageItem, mode: EditMode = activeMode): PendingImageEditorState {
    const currentState = item.editor_state || {};
    const savedModeSet = new Set(item.saved_modes || []);
    return {
      ...currentState,
      [mode]:
        mode === "polygon"
          ? {
              ...(currentState.polygon || {}),
              dirty: dirtyModes.polygon,
              completed: completedModes.polygon,
              saved: savedModeSet.has("polygon"),
              cuts: structuredClone(cuts),
              pieces: structuredClone(pieces),
              analysis_dirty: polygonAnalysisDirty,
            }
          : {
              ...(currentState.knob || {}),
              dirty: dirtyModes.knob,
              completed: completedModes.knob,
              saved: savedModeSet.has("knob"),
              knob_pieces: structuredClone(effectiveKnobPieces),
            },
    };
  }

  async function persistPendingEditorState(item: PendingImageItem, state: PendingImageEditorState) {
    setPendingImages((current) => current.map((candidate) => (candidate.id === item.id ? { ...candidate, editor_state: state } : candidate)));
    setBackgroundImages((current) => current.map((candidate) => (candidate.id === item.id ? { ...candidate, editor_state: state } : candidate)));
    setSelectedImages((current) => ({
      polygon: current.polygon?.id === item.id ? { ...current.polygon, editor_state: state } : current.polygon,
      knob: current.knob?.id === item.id ? { ...current.knob, editor_state: state } : current.knob,
    }));
    await fetch(`/api/pending-images/${encodeURIComponent(item.id)}/editor-state`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ editor_state: state }),
    });
  }

  function undo() {
    const previous = history.undo(snapshot());
    if (!previous) return;
    restoreSnapshot(previous);
    setDirtyModes((dirty) => ({ ...dirty, [activeMode]: true }));
  }

  function redo() {
    const next = history.redo(snapshot());
    if (!next) return;
    restoreSnapshot(next);
    setDirtyModes((dirty) => ({ ...dirty, [activeMode]: true }));
  }

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (lineToolActive && event.key === "Escape") {
        // ESC：完全退出添加线段模式（无论当前是否已经按下了第一点）。
        event.preventDefault();
        setLineToolActive(false);
        setDrawingCut(null);
        setDrawingHoverPoint(null);
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
        return;
      }
      // 方向键微移：只在多边形编辑模式且已选中线段/形状时生效；按住会随浏览器自动重复。
      if (!modKey && activeMode === "polygon" && selectedId && !drawingCut) {
        const dx = event.key === "ArrowLeft" ? -1 : event.key === "ArrowRight" ? 1 : 0;
        const dy = event.key === "ArrowUp" ? -1 : event.key === "ArrowDown" ? 1 : 0;
        if (dx !== 0 || dy !== 0) {
          event.preventDefault();
          nudgeSelectedCut(dx, dy);
        }
      }
    };
    const onKeyUp = (event: KeyboardEvent) => {
      if (event.key.startsWith("Arrow")) nudgeSessionRef.current = false;
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
    };
  }, [activeMode, drawingCut, lineToolActive, history.canRedo, history.canUndo, selectedId]);

  function requestModeChange(mode: EditMode) {
    if (mode === activeMode) return;
    if (dirtyModes[activeMode]) {
      setPendingMode(mode);
      return;
    }
    switchMode(mode);
  }

  function switchMode(mode: EditMode) {
    const previous = selectedImages[activeMode];
    if (previous) {
      const latestPrevious = pendingImages.find((candidate) => candidate.id === previous.id) || previous;
      void persistPendingEditorState(latestPrevious, pendingEditorStateForCurrentMode(latestPrevious, activeMode));
    }
    setActiveMode(mode);
    setSelectedId("");
    setSelectedPieceIds([]);
    setDrag(null);
    setLineToolActive(false);
    setDrawingCut(null);
    setDrawingHoverPoint(null);
    setPendingMode(null);
    const item = selectedImages[mode];
    if (item) applyPendingEditorStateToMode(mode, item);
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
      showToast(activeMode === "polygon" ? "多边形模式还没有更新出可用碎片。" : "凹凸模式还没有可用碎片。");
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

    const selectedKnobPieces = selectedPieceIds.map((id) => effectiveKnobPieces.find((piece) => piece.id === id));
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
    const baseKnobPieces = effectiveKnobPieces;
    setKnobPieces(
      baseKnobPieces
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

  function clearEditorImage() {
    setImage(null);
    setImageUrl("");
    setAnalysis({ outline: [], edgePoints: [], bounds: null });
    setActualPreview(null);
    analysisWorker.setWorkerImageReady(false);
  }

  function loadEditorImage(src: string, name: string, godotPath: string, target: ImageTarget, updateConfig = true) {
    if (!src) {
      clearEditorImage();
      return;
    }
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
      clearEditorImage();
      showToast("当前图片无法加载，请检查关卡图片是否存在。");
    };
    next.src = src;
  }

  function recordImageEdit(target: ImageTarget) {
    history.pushUndo(snapshot());
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
    setKnobPieces([]);
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
    setKnobPieces([]);
    setSelectedPieceIds([]);
  }

  function updateCutLineColor(value: string) {
    setCutLineColor(value);
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
    setPolygonAnalysisDirty(true);
    setSelectedId(next.id);
  }

  function dropShape(event: React.DragEvent<SVGSVGElement>) {
    const template = event.dataTransfer.getData("application/x-jigcat-shape") as CutTemplate;
    if (!template) return;
    event.preventDefault();
    addPresetAt(template, clientPointToSvg(event.clientX, event.clientY));
    setPolygonView("edit");
  }

  function startDrawingCut(initialPoint?: Point) {
    setDrawingHoverPoint(initialPoint || null);
    setDrawingCut({ id: uid("cut"), points: initialPoint ? [initialPoint] : [] });
  }

  function addBridgeCut() {
    if (!analysis.outline.length) return;
    setPolygonView("edit");
    setSelectedId("");
    setLineToolActive(true);
    startDrawingCut();
    showToast("左键添加点，右键结束线条。");
  }

  function toggleLineTool() {
    if (lineToolActive) {
      setLineToolActive(false);
      setDrawingCut(null);
      setDrawingHoverPoint(null);
      return;
    }
    addBridgeCut();
  }

  function finishDrawingCut() {
    if (!drawingCut) return;
    if (drawingCut.points.length < 2) {
      if (lineToolActive) startDrawingCut();
      else {
        setDrawingCut(null);
        setDrawingHoverPoint(null);
      }
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
    setPolygonAnalysisDirty(true);
    setSelectedId(next.id);
    if (lineToolActive) startDrawingCut();
    else {
      setDrawingCut(null);
      setDrawingHoverPoint(null);
    }
  }

  function removeSelected() {
    if (!selectedId) return;
    recordEdit("polygon");
    setCuts((current) => current.filter((cut) => cut.id !== selectedId));
    setPolygonAnalysisDirty(true);
    setSelectedId("");
  }

  /** 用方向键微移当前选中的线段/形状，单次 1 像素，按住时浏览器自动重复触发。 */
  function nudgeSelectedCut(dx: number, dy: number) {
    if (!selectedId) return;
    if (!nudgeSessionRef.current) {
      recordEdit("polygon");
      nudgeSessionRef.current = true;
    } else {
      setDirtyModes((current) => ({ ...current, polygon: true }));
      setCompletedModes((current) => ({ ...current, polygon: false }));
    }
    setPolygonAnalysisDirty(true);
    setCuts((current) =>
      current.map((cut) => {
        if (cut.id !== selectedId) return cut;
        return { ...cut, points: cut.points.map((point) => ({ x: point.x + dx, y: point.y + dy })) };
      }),
    );
  }

  function clearAllCuts() {
    if (!cuts.length) return;
    recordEdit("polygon");
    setCuts([]);
    setAnalysisCuts([]);
    setPieces([]);
    setPolygonAnalysisDirty(false);
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

  function snapEditorPoint(point: Point, excludeId = ""): Point {
    if (!snapEnabled) return point;
    const hit = snapPoint(point, snapPoints, cuts, SNAP_THRESHOLD, excludeId);
    return hit ? { ...hit.point } : point;
  }


  function handleCanvasPointerDown(event: React.PointerEvent<SVGSVGElement>) {
    if (lineToolActive && !drawingCut) {
      if (event.button !== 0) return;
      event.preventDefault();
      const point = snapEditorPoint(svgPoint(event));
      startDrawingCut(point);
      return;
    }
    if (drawingCut) {
      if (event.button !== 0) return;
      event.preventDefault();
      const point = snapEditorPoint(svgPoint(event), drawingCut.id);
      setDrawingCut((current) => (current ? { ...current, points: [...current.points, point] } : current));
      setDrawingHoverPoint(point);
      return;
    }
    // 编辑模式下空白处左键按下：开始拖拽底图；松手时若没有移动过，再当作 deselect。
    if (event.button !== 0) return;
    const svg = event.currentTarget;
    const [, , widthStr, heightStr] = viewBox.split(" ");
    panDragRef.current = {
      pointerId: event.pointerId,
      lastClientX: event.clientX,
      lastClientY: event.clientY,
      svgRect: svg.getBoundingClientRect(),
      viewBoxWidth: Number(widthStr),
      viewBoxHeight: Number(heightStr),
      moved: false,
    };
    svg.setPointerCapture(event.pointerId);
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
    setPolygonAnalysisDirty(true);
    setSelectedId(cutId);
    setDrag({
      cutId,
      pointIndex,
      action: "move",
      start: svgPoint(event),
      original: structuredClone(cut),
    });
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function beginScale(event: React.PointerEvent<SVGElement>, cutId: string) {
    if (drawingCut) return;
    event.stopPropagation();
    const cut = cuts.find((item) => item.id === cutId);
    if (!cut || cut.type !== "preset_shape") return;
    const start = svgPoint(event);
    const center = polygonCenter(cut.points);
    recordEdit("polygon");
    setPolygonAnalysisDirty(true);
    setSelectedId(cutId);
    setDrag({
      cutId,
      pointIndex: null,
      action: "scale",
      start,
      original: structuredClone(cut),
      center,
      startDistance: Math.max(1, Math.hypot(start.x - center.x, start.y - center.y)),
    });
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function moveDrag(event: React.PointerEvent<SVGSVGElement>) {
    if (drawingCut) {
      setDrawingHoverPoint(snapEditorPoint(svgPoint(event), drawingCut.id));
      return;
    }
    const panDrag = panDragRef.current;
    if (panDrag && event.pointerId === panDrag.pointerId) {
      const dxClient = event.clientX - panDrag.lastClientX;
      const dyClient = event.clientY - panDrag.lastClientY;
      if (!panDrag.moved && (Math.abs(dxClient) > 1 || Math.abs(dyClient) > 1)) {
        panDrag.moved = true;
      }
      if (panDrag.moved) {
        const scaleX = panDrag.viewBoxWidth / Math.max(1, panDrag.svgRect.width);
        const scaleY = panDrag.viewBoxHeight / Math.max(1, panDrag.svgRect.height);
        // 鼠标向右拖 → viewBox 应该向左移 → pan.x 减小，因此取相反符号。
        canvasView.panBy(-dxClient * scaleX, -dyClient * scaleY);
      }
      panDrag.lastClientX = event.clientX;
      panDrag.lastClientY = event.clientY;
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
        if (drag.action === "scale" && drag.center && drag.startDistance) {
          const distance = Math.hypot(currentPoint.x - drag.center.x, currentPoint.y - drag.center.y);
          const scale = Math.max(0.15, Math.min(5, distance / drag.startDistance));
          next.points = scaleCutPoints(next.points, drag.center, scale);
        } else if (drag.pointIndex === null) {
          next.points = next.points.map((point) => ({ x: point.x + dx, y: point.y + dy }));
          if (snapEnabled && next.type !== "preset_shape") {
            const endpoints = [
              { index: 0, point: next.points[0] },
              { index: next.points.length - 1, point: next.points[next.points.length - 1] },
            ];
            const hit = endpoints
              .map((endpoint) => {
                const snap = snapPoint(endpoint.point, snapPoints, cuts, SNAP_THRESHOLD, next.id);
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
            const hit = snapPoint(next.points[drag.pointIndex], snapPoints, cuts, SNAP_THRESHOLD, next.id);
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
    const panDrag = panDragRef.current;
    if (panDrag) {
      // 没有真正拖动过 → 视为点击空白 → 取消选中（保留旧的 deselect 行为）。
      if (!panDrag.moved) setSelectedId("");
      panDragRef.current = null;
    }
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
          pieces: effectiveKnobPieces,
        },
      },
      editor: {
        outline: serializePoints(analysis.outline),
        cut_color: cutLineColor,
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
      showToast("请先为当前模式选择图片并更新出可用碎片。");
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
      showToast("请先为当前模式选择图片并更新出可用碎片。");
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
      const result = (await response.json()) as { ok?: boolean; path?: string; error?: string; catalog?: LevelCatalog; level?: LevelConfig; topicId?: string; levelId?: string; sharedModes?: EditMode[] };
      if (!response.ok || !result.ok) {
        throw new Error(result.error || `HTTP ${response.status}`);
      }
      showToast(`已保存到 ${result.path}`);
      if (result.catalog) setCatalog(result.catalog);
      const savedModes = new Set<EditMode>(result.sharedModes?.length ? result.sharedModes : [activeMode]);
      const savedTarget = { topicId: result.topicId || saveDialog.topicId, levelId: result.levelId || saveDialog.levelId };
      // 必须先清掉已保存模式的 selectedImages，再 applyLoadedLevel；
      // 否则 useEffect 会以"旧 pending image + 新 level"组合 触发 loadEditorImage(updateConfig=true)，
      // 把 level.modes[mode].image.path 反向覆盖回 pending 路径，随后再次清选时找不到合法 res:// → 图片消失。
      setSelectedImages((current) => ({
        polygon: savedModes.has("polygon") ? null : current.polygon,
        knob: savedModes.has("knob") ? null : current.knob,
      }));
      if (result.level) applyLoadedLevel(result.level, savedTarget.topicId, savedTarget.levelId);
      else setCurrentTarget(savedTarget);
      await loadPendingImages(activePendingImage.id, false);
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

  const canvasCaches = {
    cutPath: cutPathCacheRef.current,
    piecePath: piecePathCacheRef.current,
    knobPiecePath: knobPiecePathCacheRef.current,
  };

  return (
    <div className="grid h-full min-h-0 grid-cols-[minmax(520px,1fr)_380px] overflow-hidden bg-linen text-ink">
      <main className="grid min-h-0 min-w-0 grid-rows-[auto_1fr] overflow-hidden">
        <EditorTopBar
          activeMode={activeMode}
          onModeChange={requestModeChange}
          dirtyModes={dirtyModes}
          completedModes={completedModes}
          activeImageId={activePendingImage?.id || ""}
          imageOptions={imageOptions}
          onSelectImage={(id) => selectImageForMode(activeMode, id)}
          activeSaveStatus={activeSaveStatus}
          canSaveToGodot={canSaveToGodot}
          onMarkComplete={markCurrentModeComplete}
          onOpenSaveDialog={openSaveDialog}
        />
        <EditorCanvas
          ref={svgRef}
          viewBox={viewBox}
          background={canvasBackgroundStyle}
          modeBadge={canvasModeLabel}
          zoom={canvasView.zoom}
          onZoomChange={canvasView.changeZoom}
          onSetZoom={canvasView.setZoom}
          onZoomReset={canvasView.resetZoom}
          image={image}
          imageUrl={imageUrl}
          activeMode={activeMode}
          polygonView={polygonView}
          showKnobPieces={showKnobPieces}
          cutLineColor={cutLineColor}
          lineToolActive={lineToolActive}
          cuts={cuts}
          pieces={pieces}
          knobPieces={effectiveKnobPieces}
          selectedId={selectedId}
          selectedPieceIds={selectedPieceIds}
          drawingCut={drawingCut}
          drawingHoverPoint={drawingHoverPoint}
          actualPreview={actualPreview}
          cutGaps={cutGaps}
          cutIntersections={cutIntersections}
          snapConnectionMarkers={snapConnectionMarkers}
          caches={canvasCaches}
          onCanvasPointerDown={handleCanvasPointerDown}
          onCanvasPointerMove={moveDrag}
          onCanvasPointerUp={endDrag}
          onCanvasPointerLeave={endDrag}
          onCanvasContextMenu={handleCanvasContextMenu}
          onCanvasDrop={dropShape}
          onTogglePieceSelection={togglePieceSelection}
          onBeginDragCut={beginDrag}
          onBeginScaleCut={beginScale}
        />
      </main>

      <aside className="flex min-h-0 flex-col gap-4 overflow-hidden border-l border-stone-300 bg-paper p-4">
        <EditorToolbox
          activeMode={activeMode}
          canUndo={history.canUndo}
          canRedo={history.canRedo}
          snapEnabled={snapEnabled}
          hasSelectedCut={Boolean(selectedId)}
          hasCuts={cuts.length > 0}
          cutLineColor={cutLineColor}
          onCutLineColorChange={updateCutLineColor}
          onUndo={undo}
          onRedo={redo}
          onToggleSnap={() => setSnapEnabled((value) => !value)}
          onMerge={mergeSelectedPieces}
          onRemoveSelected={removeSelected}
          onClearCuts={clearAllCuts}
        />
        {activeMode === "polygon" && (
          <PolygonModePanel
            polygonView={polygonView}
            onPolygonViewChange={setPolygonView}
            lineToolActive={lineToolActive}
            onToggleLineTool={toggleLineTool}
            onAddPreset={addPreset}
            analyzing={polygonAnalysisDirty}
          />
        )}
        {activeMode === "knob" && (
          <KnobModePanel
            showKnobPieces={showKnobPieces}
            onToggleShowKnobPieces={() => setShowKnobPieces((value) => !value)}
            draft={knobGridDraft}
            onDraftChange={setKnobGridDraft}
            onCommitDraft={commitKnobGrid}
            knobSize={level.modes.knob.knob_size}
            onKnobSizeChange={updateKnobSize}
          />
        )}
      </aside>

      <EditorSaveDialog
        state={saveDialog}
        topicOptions={topicOptions}
        saveLevelOptions={saveLevelOptions}
        backgroundImages={backgroundImages}
        backgroundImageOptions={backgroundImageOptions}
        canUseBackgroundImage={canUseBackgroundImage}
        activePendingImage={activePendingImage}
        activeMode={activeMode}
        onChange={setSaveDialog}
        onClose={() => setSaveDialog((current) => ({ ...current, open: false }))}
        onSave={() => void saveJsonToGodot()}
        onTopicChange={(topicId) => {
          const topic = catalog.topics.find((item) => item.id === topicId);
          const firstLevel = topic?.levels[0];
          setSaveDialog((current) => ({
            ...current,
            topicId,
            levelId: firstLevel?.id || "",
            title: firstLevel?.title || current.title,
          }));
        }}
        onLevelChange={(levelId) => {
          const levelItem = saveTopic?.levels.find((item) => item.id === levelId);
          setSaveDialog((current) => ({ ...current, levelId, title: levelItem?.title || current.title }));
        }}
      />
      <EditorModeSwitchDialog pendingMode={pendingMode} onCancel={() => setPendingMode(null)} onConfirm={() => pendingMode && switchMode(pendingMode)} />
    </div>
  );
}

export default App;
