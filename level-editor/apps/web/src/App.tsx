import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowDown, ArrowUp, Download, FileJson, Magnet, Plus, Redo2, RefreshCcw, Save, Trash2, Undo2, Upload } from "lucide-react";
import {
  DEFAULT_BROWSER_IMAGE,
  DEFAULT_IMAGE_PATH,
  analyzeActualPieces,
  catmullRomPath,
  detectImageOutline,
  findCutGaps,
  generateFractureNetwork,
  generateKnobPieces,
  makeEmptyLevel,
  presetCut,
  samplePath,
  serializePoints,
  snapPoint,
  uid,
} from "./geometry";
import type { CatalogLevel, CatalogTopic, CutLine, CutTemplate, LevelCatalog, LevelConfig, LevelPiece, OutlineAnalysis, PieceCell, Point } from "./types";

const snapThreshold = 18;
const edgePrecision = 2;

type EditMode = "polygon" | "knob";

type LevelTarget = {
  topicId: string;
  levelId: string;
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

function cloneSnapshot(snapshot: EditorSnapshot): EditorSnapshot {
  return structuredClone(snapshot);
}

function makeDefaultCatalog(): LevelCatalog {
  return {
    schema: "jigsaw.catalog.v1",
    version: 1,
    default_locale: "zh-Hans",
    locales: ["zh-Hans", "en"],
    topics: [],
  };
}

function localized(value: Record<string, string> | undefined, locale: string, fallback: string) {
  return value?.[locale] || value?.["zh-Hans"] || value?.en || fallback;
}

function normalizeOrder<T extends { sort_order: number }>(items: T[]): T[] {
  return items.map((item, index) => ({ ...item, sort_order: index }));
}

function sourceUrl(topicId: string, levelId: string) {
  return `/api/levels/${topicId}/${levelId}/source?mtime=${Date.now()}`;
}

function updateCatalogLevel(catalog: LevelCatalog, target: LevelTarget, update: (level: CatalogLevel) => CatalogLevel): LevelCatalog {
  return {
    ...catalog,
    topics: catalog.topics.map((topic) =>
      topic.id === target.topicId
        ? {
            ...topic,
            levels: topic.levels.map((level) => (level.id === target.levelId ? update(level) : level)),
          }
        : topic,
    ),
  };
}

function pointFromTuple(point: number[]): Point {
  return { x: point[0] || 0, y: point[1] || 0 };
}

function tupleFromPoint(point: Point): number[] {
  return [Math.round(point.x * 100) / 100, Math.round(point.y * 100) / 100];
}

function polygonCenter(points: Point[]): Point {
  if (!points.length) return { x: 0, y: 0 };
  return {
    x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
    y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
  };
}

function edgePointKey(point: Point): string {
  return `${Math.round(point.x / edgePrecision)},${Math.round(point.y / edgePrecision)}`;
}

function edgeKey(a: Point, b: Point): string {
  return `${edgePointKey(a)}>${edgePointKey(b)}`;
}

function undirectedEdgeKey(a: Point, b: Point): string {
  const ak = edgePointKey(a);
  const bk = edgePointKey(b);
  return ak < bk ? `${ak}|${bk}` : `${bk}|${ak}`;
}

function polygonEdges(points: Point[]) {
  return points.map((from, index) => ({ from, to: points[(index + 1) % points.length] }));
}

function mergePolygons(a: Point[], b: Point[]): Point[] | null {
  const allEdges = [...polygonEdges(a), ...polygonEdges(b)];
  const edgeCounts = new Map<string, number>();
  for (const edge of allEdges) {
    const key = undirectedEdgeKey(edge.from, edge.to);
    edgeCounts.set(key, (edgeCounts.get(key) || 0) + 1);
  }
  const sharedEdges = [...edgeCounts.values()].filter((count) => count > 1).length;
  if (sharedEdges === 0) return null;

  const boundary = allEdges.filter((edge) => edgeCounts.get(undirectedEdgeKey(edge.from, edge.to)) === 1);
  if (boundary.length < 3) return null;
  const unused = new Map(boundary.map((edge) => [edgeKey(edge.from, edge.to), edge]));
  const first = boundary[0];
  const merged: Point[] = [first.from, first.to];
  unused.delete(edgeKey(first.from, first.to));
  let current = first.to;
  let guard = 0;

  while (unused.size && guard < boundary.length + 4) {
    guard += 1;
    const currentKey = edgePointKey(current);
    let foundKey = "";
    let found = null as null | { from: Point; to: Point };
    for (const [key, edge] of unused) {
      if (edgePointKey(edge.from) === currentKey) {
        foundKey = key;
        found = edge;
        break;
      }
      if (edgePointKey(edge.to) === currentKey) {
        foundKey = key;
        found = { from: edge.to, to: edge.from };
        break;
      }
    }
    if (!found) break;
    current = found.to;
    if (edgePointKey(current) === edgePointKey(merged[0])) {
      unused.delete(foundKey);
      break;
    }
    merged.push(current);
    unused.delete(foundKey);
  }

  return merged.length >= 3 ? merged : null;
}

function cellsToLevelPieces(cells: PieceCell[]): LevelPiece[] {
  return cells.map((piece) => {
    const neighbors = cells
      .filter((candidate) => candidate.id !== piece.id && mergePolygons(piece.points, candidate.points))
      .map((candidate) => candidate.id);
    return {
      id: piece.id,
      cell: [0, 0],
      home: tupleFromPoint(polygonCenter(piece.points)),
      points: piece.points.map(tupleFromPoint),
      neighbors,
      cut_lines: [],
    };
  });
}

function App() {
  const [catalog, setCatalog] = useState<LevelCatalog>(() => makeDefaultCatalog());
  const [locale, setLocale] = useState("zh-Hans");
  const [currentTarget, setCurrentTarget] = useState<LevelTarget>({ topicId: "cat", levelId: "cat_moon_01" });
  const [pendingTarget, setPendingTarget] = useState<LevelTarget | null>(null);
  const [level, setLevel] = useState<LevelConfig>(() => makeEmptyLevel());
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [imageUrl, setImageUrl] = useState(DEFAULT_BROWSER_IMAGE);
  const [analysis, setAnalysis] = useState<OutlineAnalysis>({ outline: [], edgePoints: [], bounds: null });
  const [activeMode, setActiveMode] = useState<EditMode>("polygon");
  const [cuts, setCuts] = useState<CutLine[]>([]);
  const [pieces, setPieces] = useState<PieceCell[]>([]);
  const [knobPieces, setKnobPieces] = useState<LevelPiece[]>([]);
  const [selectedPieceIds, setSelectedPieceIds] = useState<string[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [drag, setDrag] = useState<DragState | null>(null);
  const [targetPieces, setTargetPieces] = useState(14);
  const [snapEnabled, setSnapEnabled] = useState(true);
  const [showPieces, setShowPieces] = useState(true);
  const [showKnobPieces, setShowKnobPieces] = useState(true);
  const [jsonText, setJsonText] = useState("");
  const [saveStatus, setSaveStatus] = useState("");
  const [dirtyModes, setDirtyModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [completedModes, setCompletedModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [pendingMode, setPendingMode] = useState<EditMode | null>(null);
  const [undoStack, setUndoStack] = useState<EditorSnapshot[]>([]);
  const [redoStack, setRedoStack] = useState<EditorSnapshot[]>([]);
  const svgRef = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    void loadCatalog();
  }, []);

  const currentTopic = useMemo(() => catalog.topics.find((topic) => topic.id === currentTarget.topicId), [catalog, currentTarget.topicId]);
  const currentCatalogLevel = useMemo(
    () => currentTopic?.levels.find((item) => item.id === currentTarget.levelId),
    [currentTopic, currentTarget.levelId],
  );

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
      setLocale(normalized.default_locale || normalized.locales[0] || "zh-Hans");
      const firstTopic = normalized.topics[0];
      const firstLevel = firstTopic?.levels[0];
      if (firstTopic && firstLevel) await loadLevel(firstTopic.id, firstLevel.id, firstLevel);
      else loadBrowserImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH);
    } catch (error) {
      setSaveStatus(error instanceof Error ? `加载 catalog 失败：${error.message}` : "加载 catalog 失败");
      loadBrowserImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH);
    }
  }

  async function loadLevel(topicId: string, levelId: string, catalogLevel?: CatalogLevel) {
    try {
      const response = await fetch(`/api/levels/${topicId}/${levelId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelConfig;
      applyLoadedLevel(data, topicId, levelId);
      loadBrowserImage(sourceUrl(topicId, levelId), "source.png", `res://levels/${topicId}/${levelId}/source.png`);
    } catch (error) {
      const fallback = makeEmptyLevel();
      fallback.id = levelId;
      fallback.topic_id = topicId;
      fallback.title = catalogLevel?.title || levelId;
      fallback.title_i18n = catalogLevel?.title_i18n || { [locale]: fallback.title };
      fallback.image.path = `res://levels/${topicId}/${levelId}/source.png`;
      applyLoadedLevel(fallback, topicId, levelId);
      loadBrowserImage(sourceUrl(topicId, levelId), "source.png", fallback.image.path);
    }
  }

  function applyLoadedLevel(data: LevelConfig, topicId: string, levelId: string) {
    const defaults = makeEmptyLevel();
    setCurrentTarget({ topicId, levelId });
    setLevel({
      ...defaults,
      ...data,
      id: levelId,
      topic_id: topicId,
      image: { ...defaults.image, ...data.image },
      background: { ...defaults.background, ...data.background },
      grid: { ...defaults.grid, ...data.grid },
      modes: {
        polygon: { ...defaults.modes.polygon, ...data.modes?.polygon },
        knob: {
          ...defaults.modes.knob,
          ...(data.modes?.knob || {}),
          cols: data.modes?.knob?.cols ?? data.grid?.cols ?? defaults.grid.cols,
          rows: data.modes?.knob?.rows ?? data.grid?.rows ?? defaults.grid.rows,
          piece_size: data.modes?.knob?.piece_size ?? data.grid?.piece_size ?? defaults.grid.piece_size,
        },
      },
      editor: { ...defaults.editor, ...data.editor },
    });
    const importedCuts: CutLine[] = [
      ...(data.editor?.cuts || []).map((cut) => ({ ...cut, points: cut.points.map(([x, y]) => ({ x, y })) })),
      ...(data.editor?.shapes || []).map((shape) => ({ ...shape, points: shape.points.map(([x, y]) => ({ x, y })) })),
    ];
    setCuts(importedCuts);
    setPieces((data.editor?.pieces || []).map((piece) => ({ ...piece, points: piece.points.map(([x, y]) => ({ x, y })) })));
    setKnobPieces(data.modes?.knob?.pieces || []);
    setSelectedId("");
    setSelectedPieceIds([]);
    setJsonText(JSON.stringify(data, null, 2));
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
    setLevel((current) => ({
      ...current,
      image: {
        ...current.image,
        width: image.naturalWidth,
        height: image.naturalHeight,
      },
      editor: {
        ...current.editor,
        outline: serializePoints(nextAnalysis.outline),
      },
    }));
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
  const actualPreview = useMemo(() => (image ? analyzeActualPieces(image, cuts) : null), [image, cuts]);
  const cutGaps = useMemo(() => findCutGaps(cuts, snapPoints), [cuts, snapPoints]);
  const generatedKnobPieces = useMemo(
    () => generateKnobPieces(image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size),
    [image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size],
  );
  const modeReady = {
    polygon: pieces.length > 0,
    knob: knobPieces.length > 0,
  };
  const canSaveToGodot = completedModes.polygon && completedModes.knob && modeReady.polygon && modeReady.knob;
  useEffect(() => {
    if (!knobPieces.length && generatedKnobPieces.length) setKnobPieces(generatedKnobPieces);
  }, [generatedKnobPieces, knobPieces.length]);

  useEffect(() => {
    const hasDirtyMode = dirtyModes.polygon || dirtyModes.knob;
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (!hasDirtyMode) return;
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirtyModes]);

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
    setPieces(next.pieces);
    setKnobPieces(next.knobPieces);
    setCompletedModes(next.completedModes || { polygon: false, knob: false });
    setSelectedId("");
    setSelectedPieceIds([]);
    setDrag(null);
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
      setSaveStatus("当前关卡两个模式都完成后，才能保存并切换。");
      return;
    }
    const ok = await saveJsonToGodot();
    if (ok) await switchLevel(pendingTarget);
  }

  function currentLevelPosition() {
    const topicIndex = catalog.topics.findIndex((topic) => topic.id === currentTarget.topicId);
    const levelIndex = topicIndex >= 0 ? catalog.topics[topicIndex].levels.findIndex((item) => item.id === currentTarget.levelId) : -1;
    return { topicIndex, levelIndex };
  }

  function adjacentLevel(direction: 1 | -1): LevelTarget | null {
    const flat = catalog.topics.flatMap((topic) => topic.levels.map((levelItem) => ({ topicId: topic.id, levelId: levelItem.id })));
    const index = flat.findIndex((item) => item.topicId === currentTarget.topicId && item.levelId === currentTarget.levelId);
    if (index < 0) return null;
    return flat[index + direction] || null;
  }

  function moveCurrentLevel(direction: 1 | -1) {
    const { topicIndex, levelIndex } = currentLevelPosition();
    if (topicIndex < 0 || levelIndex < 0) return;
    setCatalog((current) => {
      const topics = [...current.topics];
      const topic = topics[topicIndex];
      const levels = [...topic.levels];
      const nextIndex = levelIndex + direction;
      if (nextIndex < 0 || nextIndex >= levels.length) return current;
      [levels[levelIndex], levels[nextIndex]] = [levels[nextIndex], levels[levelIndex]];
      topics[topicIndex] = { ...topic, levels: normalizeOrder(levels) };
      return { ...current, topics };
    });
  }

  function moveCurrentTopic(direction: 1 | -1) {
    const { topicIndex } = currentLevelPosition();
    const nextIndex = topicIndex + direction;
    if (topicIndex < 0 || nextIndex < 0 || nextIndex >= catalog.topics.length) return;
    setCatalog((current) => {
      const topics = [...current.topics];
      [topics[topicIndex], topics[nextIndex]] = [topics[nextIndex], topics[topicIndex]];
      return { ...current, topics: normalizeOrder(topics) };
    });
  }

  function addTopic() {
    const id = window.prompt("大关卡 ID（英文/数字/下划线）");
    if (!id) return;
    const name = window.prompt("大关卡名称", id) || id;
    setCatalog((current) => ({
      ...current,
      topics: normalizeOrder([
        ...current.topics,
        {
          id,
          name,
          name_i18n: { [locale]: name },
          sort_order: current.topics.length,
          cover: "",
          levels: [],
        },
      ]),
    }));
  }

  function addLevelToCurrentTopic() {
    const topicId = currentTopic?.id;
    if (!topicId) return;
    const id = window.prompt("小关卡 ID（英文/数字/下划线）");
    if (!id) return;
    const title = window.prompt("小关卡名称", id) || id;
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) =>
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
    }));
    requestLevelChange({ topicId, levelId: id });
  }

  function markExported() {
    setDirtyModes({ polygon: false, knob: false });
  }

  function markCurrentModeComplete() {
    if (!modeReady[activeMode]) {
      setSaveStatus(activeMode === "polygon" ? "多边形模式还没有生成可用碎片。" : "凹凸模式还没有可用碎片。");
      return;
    }
    setCompletedModes((current) => ({ ...current, [activeMode]: true }));
    setDirtyModes((current) => ({ ...current, [activeMode]: false }));
    setSaveStatus(`${activeMode === "polygon" ? "多边形" : "凹凸"}模式已标记完成。`);
  }

  function catalogForSave() {
    return updateCatalogLevel(catalog, currentTarget, (item) => ({
      ...item,
      title: level.title,
      title_i18n: level.title_i18n || item.title_i18n,
      path: `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/level.json`,
      source: `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/source.png`,
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
      setSaveStatus("请选择两个相邻碎片。");
      return;
    }
    if (activeMode === "polygon") {
      const selectedPieces = selectedPieceIds.map((id) => pieces.find((piece) => piece.id === id));
      if (!selectedPieces[0] || !selectedPieces[1]) return;
      const mergedPoints = mergePolygons(selectedPieces[0].points, selectedPieces[1].points);
      if (!mergedPoints) {
        setSaveStatus("只能合并相邻碎片。");
        return;
      }
      recordEdit("polygon");
      const merged: PieceCell = { id: `poly_merge_${Date.now().toString(36)}`, points: mergedPoints };
      setPieces((current) => [...current.filter((piece) => !selectedPieceIds.includes(piece.id)), merged]);
      setSelectedPieceIds([merged.id]);
      setSaveStatus("已合并多边形碎片。");
      return;
    }

    const selectedKnobPieces = selectedPieceIds.map((id) => knobPieces.find((piece) => piece.id === id));
    if (!selectedKnobPieces[0] || !selectedKnobPieces[1]) return;
    const firstPoints = selectedKnobPieces[0].points.map(pointFromTuple);
    const secondPoints = selectedKnobPieces[1].points.map(pointFromTuple);
    const mergedPoints = mergePolygons(firstPoints, secondPoints);
    if (!mergedPoints) {
      setSaveStatus("只能合并相邻碎片。");
      return;
    }
    recordEdit("knob");
    const mergedId = `knob_merge_${Date.now().toString(36)}`;
    const neighborIds = [...new Set([...selectedKnobPieces[0].neighbors, ...selectedKnobPieces[1].neighbors].filter((id) => !selectedPieceIds.includes(id)))];
    const merged: LevelPiece = {
      id: mergedId,
      cell: selectedKnobPieces[0].cell,
      home: tupleFromPoint(polygonCenter(mergedPoints)),
      points: mergedPoints.map(tupleFromPoint),
      neighbors: neighborIds,
      cut_lines: [],
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
    setSaveStatus("已合并凹凸碎片。");
  }

  function loadBrowserImage(src: string, name: string, godotPath: string) {
    const next = new Image();
    next.onload = () => {
      setImage(next);
      setImageUrl(src);
      setLevel((current) => ({
        ...current,
        image: {
          ...current.image,
          name,
          path: godotPath || current.image.path,
          width: next.naturalWidth,
          height: next.naturalHeight,
        },
      }));
    };
    next.src = src;
  }

  async function onUploadImage(file?: File) {
    if (!file) return;
    recordEdit(activeMode);
    const form = new FormData();
    form.append("source", file);
    try {
      const response = await fetch(`/api/levels/${currentTarget.topicId}/${currentTarget.levelId}/source`, { method: "POST", body: form });
      const result = (await response.json()) as { ok?: boolean; godotPath?: string; url?: string; error?: string };
      if (!response.ok || !result.ok) throw new Error(result.error || `HTTP ${response.status}`);
      loadBrowserImage(result.url || URL.createObjectURL(file), file.name, result.godotPath || level.image.path || DEFAULT_IMAGE_PATH);
      setCatalog((current) =>
        updateCatalogLevel(current, currentTarget, (item) => ({
          ...item,
          source: result.godotPath || item.source,
          path: `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/level.json`,
        })),
      );
    } catch (error) {
      setSaveStatus(error instanceof Error ? `上传 source 失败：${error.message}` : "上传 source 失败");
      loadBrowserImage(URL.createObjectURL(file), file.name, level.image.path || DEFAULT_IMAGE_PATH);
    }
  }

  function updateLevel<T extends keyof LevelConfig>(key: T, value: LevelConfig[T]) {
    recordEdit(activeMode);
    setLevel((current) => ({ ...current, [key]: value }));
  }

  function updateLocalizedTitle(value: string) {
    recordEdit(activeMode);
    setLevel((current) => ({
      ...current,
      title: locale === catalog.default_locale ? value : current.title,
      title_i18n: { ...(current.title_i18n || {}), [locale]: value },
    }));
    setCatalog((current) => updateCatalogLevel(current, currentTarget, (levelItem) => ({
      ...levelItem,
      title: locale === current.default_locale ? value : levelItem.title,
      title_i18n: { ...(levelItem.title_i18n || {}), [locale]: value },
    })));
  }

  function updateLocalizedDescription(value: string) {
    recordEdit(activeMode);
    setLevel((current) => ({
      ...current,
      description: locale === catalog.default_locale ? value : current.description,
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
    recordEdit(activeMode);
    setLevel((current) => ({ ...current, image: { ...current.image, path } }));
  }

  function updateBackground<K extends keyof LevelConfig["background"]>(key: K, value: LevelConfig["background"][K]) {
    recordEdit(activeMode);
    setLevel((current) => ({ ...current, background: { ...current.background, [key]: value } }));
  }

  function updateGrid<K extends keyof LevelConfig["grid"]>(key: K, value: number) {
    recordEdit("knob");
    const nextGrid = { ...level.grid, [key]: value };
    setLevel((current) => ({
      ...current,
      grid: {
        ...current.grid,
        [key]: value,
      },
      modes: {
        ...current.modes,
        knob: {
          ...current.modes.knob,
          [key]: value,
        },
      },
    }));
    setKnobPieces(generateKnobPieces(image, nextGrid.cols, nextGrid.rows, level.modes.knob.knob_size));
    setSelectedPieceIds([]);
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
    setPieces(result.pieces);
    setSelectedId(result.cuts[0]?.id || "");
  }

  function addPreset(template: CutTemplate) {
    if (!analysis.bounds) return;
    recordEdit("polygon");
    const next = presetCut(template, analysis.bounds);
    setCuts((current) => [...current, next]);
    setSelectedId(next.id);
  }

  function addBridgeCut() {
    if (!analysis.outline.length) return;
    recordEdit("polygon");
    const a = analysis.outline[Math.floor(analysis.outline.length * 0.12)];
    const b = analysis.outline[Math.floor(analysis.outline.length * 0.62)];
    const next: CutLine = {
      id: uid("cut"),
      type: "fracture",
      template: "knob",
      points: samplePath([a, b], 7),
    };
    setCuts((current) => [...current, next]);
    setSelectedId(next.id);
  }

  function removeSelected() {
    if (!selectedId) return;
    recordEdit("polygon");
    setCuts((current) => current.filter((cut) => cut.id !== selectedId));
    setSelectedId("");
  }

  function svgPoint(event: React.PointerEvent<SVGElement>): Point {
    const svg = svgRef.current;
    if (!svg) return { x: 0, y: 0 };
    const rect = svg.getBoundingClientRect();
    const [minX, minY, width, height] = viewBox.split(" ").map(Number);
    return {
      x: minX + ((event.clientX - rect.left) / rect.width) * width,
      y: minY + ((event.clientY - rect.top) / rect.height) * height,
    };
  }

  function beginDrag(event: React.PointerEvent<SVGElement>, cutId: string, pointIndex: number | null) {
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
    if (!drag) return;
    const currentPoint = svgPoint(event);
    const dx = currentPoint.x - drag.start.x;
    const dy = currentPoint.y - drag.start.y;
    setCuts((items) =>
      items.map((cut) => {
        if (cut.id !== drag.cutId) return cut;
        const next = structuredClone(drag.original);
        if (drag.pointIndex === null) {
          next.points = next.points.map((point) => ({ x: point.x + dx, y: point.y + dy }));
        } else {
          next.points[drag.pointIndex] = { x: next.points[drag.pointIndex].x + dx, y: next.points[drag.pointIndex].y + dy };
        }
        if (snapEnabled) {
          next.points = next.points.map((point, index) => {
            const isEndpoint = index === 0 || index === next.points.length - 1;
            const canSnap = drag.pointIndex === null ? isEndpoint : drag.pointIndex === index;
            if (!canSnap) return point;
            const hit = snapPoint(point, snapPoints, cuts, snapThreshold, next.id);
            return hit ? { ...hit.point } : point;
          });
        }
        return next;
      }),
    );
  }

  function buildJson() {
    const polygonPieces = pieces.map((piece) => ({ id: piece.id, points: serializePoints(piece.points) }));
    const polygonLevelPieces = cellsToLevelPieces(pieces);
    const data: LevelConfig = {
      ...level,
      id: currentTarget.levelId,
      topic_id: currentTarget.topicId,
      locale,
      modes: {
        polygon: {
          source: "precomputed",
          pieces: polygonLevelPieces,
        },
        knob: {
          source: "precomputed",
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
    setJsonText(text);
    return text;
  }

  function downloadJson() {
    const text = jsonText || buildJson();
    const blob = new Blob([text], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${level.id || "level"}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
    markExported();
  }

  async function saveJsonToGodot(): Promise<boolean> {
    if (!canSaveToGodot) {
      setSaveStatus("需要先完成多边形和凹凸两个模式，才允许保存到 Godot。");
      return false;
    }
    const text = buildJson();
    setSaveStatus("保存中...");
    try {
      const response = await fetch(`/api/levels/${currentTarget.topicId}/${currentTarget.levelId}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ level: JSON.parse(text), catalog: catalogForSave() }),
      });
      const result = (await response.json()) as { ok?: boolean; path?: string; error?: string };
      if (!response.ok || !result.ok) {
        throw new Error(result.error || `HTTP ${response.status}`);
      }
      setSaveStatus(`已保存到 ${result.path}`);
      setCatalog(catalogForSave());
      markExported();
      return true;
    } catch (error) {
      setSaveStatus(error instanceof Error ? `保存失败：${error.message}` : "保存失败");
      return false;
    }
  }

  function importJson(file?: File) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const data = JSON.parse(String(reader.result)) as LevelConfig;
      const defaults = makeEmptyLevel();
      setLevel({
        ...defaults,
        ...data,
        image: { ...defaults.image, ...data.image },
        background: { ...defaults.background, ...data.background },
        grid: { ...defaults.grid, ...data.grid },
        modes: {
          polygon: { ...defaults.modes.polygon, ...data.modes?.polygon },
          knob: {
            ...defaults.modes.knob,
            ...(data.modes?.knob || {}),
            cols: data.modes?.knob?.cols ?? data.grid?.cols ?? defaults.grid.cols,
            rows: data.modes?.knob?.rows ?? data.grid?.rows ?? defaults.grid.rows,
            piece_size: data.modes?.knob?.piece_size ?? data.grid?.piece_size ?? defaults.grid.piece_size,
          },
        },
        editor: { ...defaults.editor, ...data.editor },
      });
      const importedCuts: CutLine[] = [
        ...(data.editor?.cuts || []).map((cut) => ({ ...cut, points: cut.points.map(([x, y]) => ({ x, y })) })),
        ...(data.editor?.shapes || []).map((shape) => ({ ...shape, points: shape.points.map(([x, y]) => ({ x, y })) })),
      ];
      setCuts(importedCuts);
      setPieces((data.editor?.pieces || []).map((piece) => ({ ...piece, points: piece.points.map(([x, y]) => ({ x, y })) })));
      setKnobPieces(data.modes?.knob?.pieces || []);
      setSelectedId(importedCuts[0]?.id || "");
      setSelectedPieceIds([]);
      setJsonText(JSON.stringify(data, null, 2));
      setDirtyModes({ polygon: false, knob: false });
      setCompletedModes({
        polygon: Boolean(data.modes?.polygon?.pieces?.length),
        knob: Boolean(data.modes?.knob?.pieces?.length),
      });
      setUndoStack([]);
      setRedoStack([]);
    };
    reader.readAsText(file);
  }

  return (
    <div className="grid h-screen min-h-0 grid-cols-[320px_minmax(720px,1fr)_340px] overflow-hidden bg-linen text-ink max-xl:grid-cols-[290px_minmax(520px,1fr)]">
      <aside className="min-h-0 overflow-auto border-r border-stone-300 bg-paper p-4">
        <div className="flex items-start gap-3 border-b border-stone-300 pb-4">
          <FileJson className="mt-1 text-clay" size={22} />
          <div>
            <h1 className="text-xl font-semibold">关卡编辑器</h1>
            <p className="text-sm text-muted">TypeScript · Tailwind · 非网格切割</p>
          </div>
        </div>

        <section className="mt-5 grid gap-3">
          <PanelTitle>关卡导航</PanelTitle>
          <div className="grid grid-cols-[1fr_auto_auto] gap-2">
            <select className="input" value={locale} onChange={(event) => setLocale(event.target.value)}>
              {catalog.locales.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
            <button className="btn" onClick={addTopic}>
              主题
            </button>
            <button className="btn" onClick={addLevelToCurrentTopic}>
              关卡
            </button>
          </div>
          <Field label="当前主题名">
            <input className="input" value={localized(currentTopic?.name_i18n, locale, currentTopic?.name || "")} onChange={(event) => updateTopicName(event.target.value)} />
          </Field>
          <div className="grid grid-cols-2 gap-2">
            <button className="btn" onClick={() => moveCurrentTopic(-1)}>
              <ArrowUp size={16} />
              主题
            </button>
            <button className="btn" onClick={() => moveCurrentTopic(1)}>
              <ArrowDown size={16} />
              主题
            </button>
          </div>
          <div className="grid max-h-40 gap-2 overflow-auto pr-1">
            {catalog.topics.map((topic) => (
              <div key={topic.id} className="rounded-md border border-stone-300 bg-white/70 p-2">
                <button className={topic.id === currentTarget.topicId ? "objectActive w-full" : "object w-full"} onClick={() => topic.levels[0] && requestLevelChange({ topicId: topic.id, levelId: topic.levels[0].id })}>
                  <span>{localized(topic.name_i18n, locale, topic.name)}</span>
                  <small>{topic.levels.length}</small>
                </button>
                {topic.id === currentTarget.topicId && (
                  <div className="mt-2 grid gap-1">
                    {topic.levels.map((item) => (
                      <button key={item.id} className={item.id === currentTarget.levelId ? "objectActive" : "object"} onClick={() => requestLevelChange({ topicId: topic.id, levelId: item.id })}>
                        <span>{localized(item.title_i18n, locale, item.title)}</span>
                        <small>{item.id}</small>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-2">
            <button className="btn" onClick={() => adjacentLevel(-1) && requestLevelChange(adjacentLevel(-1) as LevelTarget)}>
              上一关
            </button>
            <button className="btn" onClick={() => adjacentLevel(1) && requestLevelChange(adjacentLevel(1) as LevelTarget)}>
              下一关
            </button>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <button className="btn" onClick={() => moveCurrentLevel(-1)}>
              <ArrowUp size={16} />
              排序
            </button>
            <button className="btn" onClick={() => moveCurrentLevel(1)}>
              <ArrowDown size={16} />
              排序
            </button>
          </div>
        </section>

        <section className="mt-5 grid gap-3">
          <PanelTitle>编辑模式</PanelTitle>
          <div className="grid grid-cols-2 gap-2">
            <button className={activeMode === "polygon" ? "btnActive" : "btn"} onClick={() => requestModeChange("polygon")}>
              多边形{completedModes.polygon ? " ✓" : dirtyModes.polygon ? " *" : ""}
            </button>
            <button className={activeMode === "knob" ? "btnActive" : "btn"} onClick={() => requestModeChange("knob")}>
              凹凸{completedModes.knob ? " ✓" : dirtyModes.knob ? " *" : ""}
            </button>
          </div>
          <button className="btnPrimary" onClick={markCurrentModeComplete}>
            标记当前模式完成
          </button>
          <p className="text-sm text-muted">每次只编辑一个模式。* 表示有未完成修改，✓ 表示该模式已完成。</p>
        </section>

        <section className="mt-5 grid gap-3">
          <PanelTitle>关卡</PanelTitle>
          <Field label="标题">
            <input className="input" value={localized(level.title_i18n, locale, level.title)} onChange={(event) => updateLocalizedTitle(event.target.value)} />
          </Field>
          <Field label="介绍">
            <textarea className="input min-h-24" value={localized(level.description_i18n, locale, level.description)} onChange={(event) => updateLocalizedDescription(event.target.value)} />
          </Field>
          <Field label="Godot 图片路径">
            <input className="input" value={level.image.path} onChange={(event) => updateImagePath(event.target.value)} />
          </Field>
          <label className="fileButton">
            <Upload size={16} />
            上传原图预览
            <input hidden type="file" accept="image/*" onChange={(event) => onUploadImage(event.target.files?.[0])} />
          </label>
        </section>

        <section className="mt-6 grid gap-3">
          <PanelTitle>背景</PanelTitle>
          <div className="grid grid-cols-[1fr_56px] gap-2">
            <select className="input" value={level.background.type} onChange={(event) => updateBackground("type", event.target.value as "color" | "image")}>
              <option value="color">纯色</option>
              <option value="image">图片</option>
            </select>
            <input className="h-10 rounded-md border border-stone-300" type="color" value={level.background.color} onChange={(event) => updateBackground("color", event.target.value)} />
          </div>
          <Field label="背景图片路径">
            <input className="input" value={level.background.path} onChange={(event) => updateBackground("path", event.target.value)} />
          </Field>
        </section>

        {activeMode === "knob" && (
        <section className="mt-6 grid gap-3">
          <PanelTitle>Godot 生成参数</PanelTitle>
          <div className="grid grid-cols-2 gap-2">
            <Field label="列数">
              <input className="input" type="number" min="1" max="10" step="1" value={level.grid.cols} onChange={(event) => updateGrid("cols", Number(event.target.value))} />
            </Field>
            <Field label="行数">
              <input className="input" type="number" min="1" max="10" step="1" value={level.grid.rows} onChange={(event) => updateGrid("rows", Number(event.target.value))} />
            </Field>
          </div>
          <Field label="碎片显示尺寸">
            <input className="input" type="number" min="80" max="320" step="10" value={level.grid.piece_size} onChange={(event) => updateGrid("piece_size", Number(event.target.value))} />
          </Field>
          <Field label={`凹凸凸耳大小：${level.modes.knob.knob_size.toFixed(2)}`}>
            <input type="range" min="0.12" max="0.36" step="0.01" value={level.modes.knob.knob_size} onChange={(event) => updateKnobSize(Number(event.target.value))} />
          </Field>
          <p className="text-sm text-muted">凹凸模式会预生成 {knobPieces.length} 个可见碎片，并写入 JSON。Godot 会优先读取这些碎片。</p>
        </section>
        )}

        {activeMode === "polygon" && (
        <section className="mt-6 grid gap-3">
          <PanelTitle>自动生成</PanelTitle>
          <Field label={`目标碎片数：${targetPieces}`}>
            <input type="range" min="6" max="36" value={targetPieces} onChange={(event) => setTargetPieces(Number(event.target.value))} />
          </Field>
          <button className="btnPrimary" onClick={autoGenerate}>
            <RefreshCcw size={16} />
            生成碎片切割线
          </button>
          <button className="btn" onClick={addBridgeCut}>
            <Plus size={16} />
            添加平滑切割线
          </button>
        </section>
        )}
      </aside>

      <main className="grid min-h-0 min-w-0 grid-rows-[auto_1fr] overflow-hidden">
        <div className="flex min-h-14 items-center gap-2 overflow-auto border-b border-stone-300 bg-[#f7efe2] px-3">
          <button className="btn" disabled={!undoStack.length} onClick={undo}>
            <Undo2 size={16} />
            Undo
          </button>
          <button className="btn" disabled={!redoStack.length} onClick={redo}>
            <Redo2 size={16} />
            Redo
          </button>
          <button className="btnPrimary" onClick={mergeSelectedPieces}>
            合并选中碎片
          </button>
          <button className={snapEnabled ? "btnActive" : "btn"} onClick={() => setSnapEnabled((value) => !value)}>
            <Magnet size={16} />
            边缘吸附
          </button>
          {activeMode === "polygon" && <button className={showPieces ? "btnActive" : "btn"} onClick={() => setShowPieces((value) => !value)}>
            碎片预览
          </button>}
          {activeMode === "knob" && <button className={showKnobPieces ? "btnActive" : "btn"} onClick={() => setShowKnobPieces((value) => !value)}>
            凹凸预览
          </button>}
          {activeMode === "polygon" && (["knob", "circle", "star", "blob", "zigzag", "crescent"] as CutTemplate[]).map((template) => (
            <button key={template} className="btn" onClick={() => addPreset(template)}>
              {templateName(template)}
            </button>
          ))}
          {activeMode === "polygon" && <button className="btnDanger" onClick={removeSelected}>
            <Trash2 size={16} />
          </button>
          }
        </div>

        <div className="grid min-h-0 place-items-center overflow-hidden p-5" style={{ background: level.background.color }}>
          <svg
            ref={svgRef}
            className="h-[min(calc(100vh-96px),760px)] w-full max-w-[1040px] border border-black/15 bg-white/20"
            viewBox={viewBox}
            onPointerMove={moveDrag}
            onPointerUp={() => setDrag(null)}
            onPointerLeave={() => setDrag(null)}
            onPointerDown={() => setSelectedId("")}
          >
            {image && <image href={imageUrl} x="0" y="0" width={image.naturalWidth} height={image.naturalHeight} preserveAspectRatio="xMidYMid meet" />}
            {activeMode === "polygon" && showPieces && actualPreview?.dataUrl && (
              <image href={actualPreview.dataUrl} x="0" y="0" width={image?.naturalWidth || 0} height={image?.naturalHeight || 0} preserveAspectRatio="none" />
            )}
            {activeMode === "polygon" &&
              pieces.map((piece) => (
                <path
                  key={piece.id}
                  className={selectedPieceIds.includes(piece.id) ? "pieceSelectable selectedPiece" : "pieceSelectable"}
                  d={catmullRomPath(piece.points, 0.15, true)}
                  onPointerDown={(event) => {
                    event.stopPropagation();
                    togglePieceSelection(piece.id);
                  }}
                />
              ))}
            {activeMode === "knob" && showKnobPieces &&
              knobPieces.map((piece) => (
                <path
                  key={piece.id}
                  className={selectedPieceIds.includes(piece.id) ? "knobPreview selectedPiece" : "knobPreview"}
                  d={catmullRomPath(piece.points.map(pointFromTuple), 0.15, true)}
                  onPointerDown={(event) => {
                    event.stopPropagation();
                    togglePieceSelection(piece.id);
                  }}
                />
              ))}
            {activeMode === "polygon" && cutGaps.map((gap, index) => (
              <g key={`${gap.cutId}_${index}`} className="gapWarning">
                <line x1={gap.point.x} y1={gap.point.y} x2={gap.nearest.x} y2={gap.nearest.y} />
                <circle cx={gap.point.x} cy={gap.point.y} r={12} />
              </g>
            ))}
            {activeMode === "polygon" && cuts.map((cut) => (
              <g key={cut.id} className={cut.id === selectedId ? "selected" : ""}>
                <path
                  className={cut.type === "preset_shape" ? "shapePath" : "cutPath"}
                  d={catmullRomPath(cut.points, cut.type === "preset_shape" ? 0.25 : 0.9, cut.type === "preset_shape")}
                  onPointerDown={(event) => beginDrag(event, cut.id, null)}
                />
                {cut.id === selectedId &&
                  cut.points.map((point, index) => (
                    <circle key={`${cut.id}_${index}`} className="handle" cx={point.x} cy={point.y} r={10} onPointerDown={(event) => beginDrag(event, cut.id, index)} />
                  ))}
              </g>
            ))}
          </svg>
        </div>
      </main>

      <aside className="grid min-h-0 grid-rows-[minmax(0,1fr)_auto] gap-4 overflow-hidden border-l border-stone-300 bg-paper p-4 max-xl:col-span-2 max-xl:border-l-0 max-xl:border-t">
        <section className="grid min-h-0 grid-rows-[auto_auto_auto_auto_minmax(0,1fr)_auto]">
          <PanelTitle>对象</PanelTitle>
          <div className="mb-3 rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-muted">
            <p className="text-ink">当前模式：{activeMode === "polygon" ? "多边形" : "凹凸"}</p>
            <p>已选中 {selectedPieceIds.length}/2 个碎片。只能合并两个相邻碎片，合并后删除内部边，只保留外轮廓。</p>
          </div>
          {activeMode === "polygon" && (
          <div className="mb-3 rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-muted">
            <p className="text-ink">实际碎片：{actualPreview?.count || 0}</p>
            <p>按当前切割线做像素级连通检测。若有细小缺口，数量不会增加。</p>
          </div>
          )}
          {activeMode === "knob" && (
          <div className="mb-3 rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-muted">
            <p className="text-ink">凹凸碎片：{knobPieces.length}</p>
            <p>按当前行列和凸耳大小预生成，导出后 Godot 直接读取。</p>
          </div>
          )}
          {activeMode === "polygon" && cutGaps.length > 0 && (
            <div className="mb-3 rounded-md border border-[#d9933f]/50 bg-[#fff3de] px-3 py-2 text-sm text-muted">
              <p className="font-medium text-ink">发现 {cutGaps.length} 个近距离未连接端点</p>
              {cutGaps.slice(0, 4).map((gap, index) => (
                <p key={`${gap.cutId}_${index}`}>距离 {gap.distance.toFixed(1)}px，靠近{gap.kind === "outline" ? "外边缘" : "另一条切割线"}</p>
              ))}
            </div>
          )}
          {activeMode === "polygon" && <div className="grid min-h-0 gap-2 overflow-auto pr-1">
            {cuts.map((cut) => (
              <button key={cut.id} className={cut.id === selectedId ? "objectActive" : "object"} onClick={() => setSelectedId(cut.id)}>
                <span>{templateName(cut.template)}</span>
                <small>{cut.type === "preset_shape" ? "预设图形" : "切割边"}</small>
              </button>
            ))}
          </div>}
          {activeMode === "polygon" && selected && <p className="mt-3 text-sm text-muted">选中：{selected.template}，拖拽整条线或白色节点，端点会吸附到外轮廓/其他分割线。</p>}
        </section>

        <section className="grid gap-3 border-t border-stone-300 pt-4">
          <PanelTitle>导出</PanelTitle>
          <div className="rounded-md bg-white/70 px-3 py-2 text-sm text-muted">
            <p className="text-ink">Godot 导出状态</p>
            <p>多边形：{completedModes.polygon ? "完成" : "未完成"} · 凹凸：{completedModes.knob ? "完成" : "未完成"}</p>
            <p>{canSaveToGodot ? "可以保存到 Godot。" : "两个模式都标记完成后，才允许保存到 Godot。"}</p>
          </div>
          <button className="btnPrimary" onClick={buildJson}>
            <FileJson size={16} />
            生成 JSON
          </button>
          <button className="btn" onClick={downloadJson}>
            <Download size={16} />
            下载 JSON
          </button>
          <button className="btnPrimary" disabled={!canSaveToGodot} onClick={saveJsonToGodot}>
            <Save size={16} />
            保存到 Godot
          </button>
          {saveStatus && <p className="rounded-md bg-white/60 px-3 py-2 text-sm text-muted">{saveStatus}</p>}
          <label className="fileButton">
            <Upload size={16} />
            导入 JSON
            <input hidden type="file" accept="application/json,.json" onChange={(event) => importJson(event.target.files?.[0])} />
          </label>
          <textarea className="input min-h-[340px] font-mono text-xs" value={jsonText} onChange={(event) => setJsonText(event.target.value)} spellCheck={false} />
        </section>

        <section className="mt-6 border-t border-stone-300 pt-4 text-sm text-muted">
          <PanelTitle>规则</PanelTitle>
          <p>这里不做自由手绘。自动生成会创建非网格碎片边界；新增线条也是平滑曲线或预设图形，靠吸附来保证连接。</p>
        </section>
      </aside>
      {pendingMode && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-lg border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-xl font-semibold">当前模式有未保存修改</h2>
            <p className="mt-2 text-sm text-muted">切换到其他模式前，建议先保存到 Godot 或下载 JSON。继续切换不会丢弃当前数据，但这些修改仍会保持未保存状态。</p>
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
      {pendingTarget && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-lg border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <h2 className="text-xl font-semibold">当前关卡有未保存修改</h2>
            <p className="mt-2 text-sm text-muted">切换关卡前可以先保存。保存到 Godot 需要两个模式都标记完成。</p>
            <div className="mt-5 grid gap-2">
              <button className="btnPrimary" disabled={!canSaveToGodot} onClick={saveAndSwitchLevel}>
                保存并切换
              </button>
              <button className="btn" onClick={() => switchLevel(pendingTarget)}>
                不保存，直接切换
              </button>
              <button className="btn" onClick={() => setPendingTarget(null)}>
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-1.5 text-sm text-muted">
      {label}
      {children}
    </label>
  );
}

function PanelTitle({ children }: { children: React.ReactNode }) {
  return <h2 className="text-xs font-semibold uppercase tracking-wide text-muted">{children}</h2>;
}

function templateName(template: CutTemplate) {
  const names: Record<CutTemplate, string> = {
    knob: "凹凸",
    round: "圆形凸起",
    circle: "圆形",
    star: "五角星",
    blob: "圆润块",
    zigzag: "折线",
    crescent: "月牙",
  };
  return names[template];
}

export default App;
