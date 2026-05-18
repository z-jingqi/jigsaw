import { useEffect, useMemo, useRef, useState } from "react";
import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, arrayMove, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import * as Dialog from "@radix-ui/react-dialog";
import * as Select from "@radix-ui/react-select";
import { Check, ChevronDown, CircleAlert, Download, Eye, GripVertical, Hexagon, Magnet, Pencil, Plus, Puzzle, Redo2, RefreshCcw, Save, Trash2, Undo2, Upload, X } from "lucide-react";
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
  polygonArea,
  presetCut,
  presetShapePoints,
  samplePath,
  serializePoints,
  simplifyClosedPath,
  snapPoint,
  traceBoundaryLoops,
  uid,
  type ActualPiecePreview,
} from "./geometry";
import type { CatalogLevel, CatalogTopic, CutLine, CutTemplate, LevelCatalog, LevelConfig, LevelPiece, OutlineAnalysis, PieceCell, Point, LevelImageConfig } from "./types";

const snapThreshold = 18;
const mergePolygonTolerance = 5;

type EditMode = "polygon" | "knob";
type PolygonViewMode = "result" | "edit" | "inspect";

type LevelTarget = {
  topicId: string;
  levelId: string;
};

type ImageTarget = "default" | EditMode;

type ProcessStepType = "remove_background" | "trim_transparent" | "convert_jpg";

type ProcessStep = {
  id: string;
  type: ProcessStepType;
  tolerance: number;
  padding: number;
  quality: number;
  background: string;
};

type PendingImage = {
  pendingId: string;
  name: string;
  url: string;
} | null;

type CreateDialogKind = "topic" | "level" | null;

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

type SelectOption = {
  value: string;
  label: string;
  detail?: string;
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

type ToastNotice = {
  id: number;
  message: string;
};

function cloneSnapshot(snapshot: EditorSnapshot): EditorSnapshot {
  return structuredClone(snapshot);
}

function isTextEditingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tagName = target.tagName.toLowerCase();
  return target.isContentEditable || tagName === "input" || tagName === "textarea" || tagName === "select";
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

function modeSourceUrl(topicId: string, levelId: string, mode: EditMode) {
  return `/api/levels/${topicId}/${levelId}/source/${mode}?mtime=${Date.now()}`;
}

function defaultImageConfig(level: LevelConfig) {
  return level.assets?.default_image || level.image;
}

function isDefaultImageConfig(value?: LevelImageConfig): boolean {
  return !value || (typeof value !== "string" && value.use === "default" && !value.path);
}

function modeUsesDefaultImage(level: LevelConfig, mode: EditMode): boolean {
  return isDefaultImageConfig(level.modes[mode].image || level.modes[mode].source_image);
}

function modeImageConfig(level: LevelConfig, mode: EditMode): LevelImageConfig {
  const configured = level.modes[mode].image || level.modes[mode].source_image;
  if (!isDefaultImageConfig(configured)) return configured as LevelImageConfig;
  return defaultImageConfig(level);
}

function modeImagePath(level: LevelConfig, mode: EditMode): string {
  return imageConfigPath(modeImageConfig(level, mode)) || imageConfigPath(defaultImageConfig(level));
}

function modeImageTarget(level: LevelConfig, mode: EditMode): ImageTarget {
  return modeUsesDefaultImage(level, mode) ? "default" : mode;
}

function godotAssetFileName(target: LevelTarget, godotPath: string): string {
  const prefix = `res://levels/${target.topicId}/${target.levelId}/`;
  if (!godotPath.startsWith(prefix)) return "";
  return godotPath.slice(prefix.length).split(/[?#]/)[0];
}

function browserUrlForGodotImage(target: LevelTarget, godotPath: string, mode: EditMode): string {
  if (!godotPath) return DEFAULT_BROWSER_IMAGE;
  if (/^(https?:|data:|blob:)/.test(godotPath)) return godotPath;
  const fileName = godotAssetFileName(target, godotPath);
  if (!fileName) return DEFAULT_BROWSER_IMAGE;
  if (fileName === "source.png") return sourceUrl(target.topicId, target.levelId);
  if (fileName === `${mode}_source.png`) return modeSourceUrl(target.topicId, target.levelId, mode);
  return `/api/levels/${target.topicId}/${target.levelId}/assets/${encodeURIComponent(fileName)}?mtime=${Date.now()}`;
}

function imageNameFromPath(godotPath: string, fallback: string) {
  return godotPath.split("/").pop()?.split(/[?#]/)[0] || fallback;
}

function processStepLabel(type: ProcessStepType) {
  if (type === "remove_background") return "去背景";
  if (type === "trim_transparent") return "裁透明边";
  return "转 JPG";
}

function createProcessStep(type: ProcessStepType): ProcessStep {
  return {
    id: uid("process"),
    type,
    tolerance: 35,
    padding: 0,
    quality: 88,
    background: "#F6EBD4",
  };
}

function normalizeLevelConfig(data: Partial<LevelConfig>, topicId?: string, levelId?: string): LevelConfig {
  const defaults = makeEmptyLevel();
  const defaultPath = `res://levels/${topicId || data.topic_id || defaults.topic_id}/${levelId || data.id || defaults.id}/source.png`;
  const legacyImage = { ...defaults.image, path: defaultPath, ...(data.image || {}) };
  const defaultImage = { ...legacyImage, ...(data.assets?.default_image || {}) };
  return {
    ...defaults,
    ...data,
    id: levelId || data.id || defaults.id,
    topic_id: topicId || data.topic_id || defaults.topic_id,
    image: defaultImage,
    assets: {
      ...(defaults.assets || {}),
      ...(data.assets || {}),
      default_image: defaultImage,
    },
    background: { ...defaults.background, ...data.background },
    grid: { ...defaults.grid, ...data.grid },
    modes: {
      polygon: {
        ...defaults.modes.polygon,
        ...(data.modes?.polygon || {}),
        image: data.modes?.polygon?.image || data.modes?.polygon?.source_image || defaults.modes.polygon.image,
      },
      knob: {
        ...defaults.modes.knob,
        ...(data.modes?.knob || {}),
        image: data.modes?.knob?.image || data.modes?.knob?.source_image || defaults.modes.knob.image,
        cols: data.modes?.knob?.cols ?? data.grid?.cols ?? defaults.grid.cols,
        rows: data.modes?.knob?.rows ?? data.grid?.rows ?? defaults.grid.rows,
        piece_size: data.modes?.knob?.piece_size ?? data.grid?.piece_size ?? defaults.grid.piece_size,
      },
    },
    editor: { ...defaults.editor, ...data.editor },
  };
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

function imageConfigPath(value?: LevelImageConfig): string {
  if (!value) return "";
  return typeof value === "string" ? value : value.path || "";
}

function polygonCenter(points: Point[]): Point {
  if (!points.length) return { x: 0, y: 0 };
  return {
    x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
    y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
  };
}

function pointBounds(points: Point[]): { x: number; y: number; width: number; height: number } {
  if (!points.length) return { x: 0, y: 0, width: 0, height: 0 };
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const point of points) {
    minX = Math.min(minX, point.x);
    minY = Math.min(minY, point.y);
    maxX = Math.max(maxX, point.x);
    maxY = Math.max(maxY, point.y);
  }
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
}

function tupleBounds(points: Point[]): number[] {
  const bounds = pointBounds(points);
  return [bounds.x, bounds.y, bounds.width, bounds.height].map((value) => Math.round(value * 100) / 100);
}

function unionTupleBounds(boundsList: Array<number[] | undefined>, fallbackPoints: Point[]): number[] {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const bounds of boundsList) {
    if (!bounds || bounds.length < 4) continue;
    minX = Math.min(minX, bounds[0]);
    minY = Math.min(minY, bounds[1]);
    maxX = Math.max(maxX, bounds[0] + bounds[2]);
    maxY = Math.max(maxY, bounds[1] + bounds[3]);
  }
  if (!Number.isFinite(minX)) return tupleBounds(fallbackPoints);
  return [minX, minY, Math.max(1, maxX - minX), Math.max(1, maxY - minY)].map((value) => Math.round(value * 100) / 100);
}

function visibleBoundsList(piece?: LevelPiece): number[][] {
  if (!piece) return [];
  if (piece.visible_bounds_list?.length) return piece.visible_bounds_list;
  return piece.visible_bounds ? [piece.visible_bounds] : [];
}

function translateCut(cut: CutLine, center: Point): CutLine {
  const currentCenter = polygonCenter(cut.points);
  const dx = center.x - currentCenter.x;
  const dy = center.y - currentCenter.y;
  return {
    ...cut,
    points: cut.points.map((point) => ({ x: point.x + dx, y: point.y + dy })),
  };
}

function edgePointKey(point: Point, precision = 2): string {
  return `${Math.round(point.x / precision)},${Math.round(point.y / precision)}`;
}

function edgeKey(a: Point, b: Point, precision = 2): string {
  return `${edgePointKey(a, precision)}>${edgePointKey(b, precision)}`;
}

function undirectedEdgeKey(a: Point, b: Point, precision = 2): string {
  const ak = edgePointKey(a, precision);
  const bk = edgePointKey(b, precision);
  return ak < bk ? `${ak}|${bk}` : `${bk}|${ak}`;
}

function polygonEdges(points: Point[]) {
  return points.map((from, index) => ({ from, to: points[(index + 1) % points.length] }));
}

function polylinePath(points: Point[], closed = false): string {
  if (!points.length) return "";
  const commands = [`M ${points[0].x.toFixed(2)} ${points[0].y.toFixed(2)}`];
  for (let i = 1; i < points.length; i += 1) {
    commands.push(`L ${points[i].x.toFixed(2)} ${points[i].y.toFixed(2)}`);
  }
  if (closed) commands.push("Z");
  return commands.join(" ");
}

function pointToSegmentDistance(point: Point, a: Point, b: Point): number {
  const vx = b.x - a.x;
  const vy = b.y - a.y;
  const wx = point.x - a.x;
  const wy = point.y - a.y;
  const len2 = vx * vx + vy * vy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, (wx * vx + wy * vy) / len2));
  return Math.hypot(point.x - (a.x + vx * t), point.y - (a.y + vy * t));
}

function nearestBoundaryDistance(point: Point, points: Point[]): number {
  return polygonEdges(points).reduce((best, edge) => Math.min(best, pointToSegmentDistance(point, edge.from, edge.to)), Infinity);
}

function sampleSegment(a: Point, b: Point, spacing: number): Point[] {
  const length = Math.hypot(b.x - a.x, b.y - a.y);
  const count = Math.max(2, Math.ceil(length / spacing));
  return Array.from({ length: count + 1 }, (_, index) => ({
    x: a.x + ((b.x - a.x) * index) / count,
    y: a.y + ((b.y - a.y) * index) / count,
  }));
}

function sharedBoundaryLength(a: Point[], b: Point[], tolerance = 4): number {
  let length = 0;
  for (const edge of polygonEdges(a)) {
    const edgeLength = Math.hypot(edge.to.x - edge.from.x, edge.to.y - edge.from.y);
    if (edgeLength < 1) continue;
    const samples = sampleSegment(edge.from, edge.to, 8);
    let closeSamples = 0;
    for (const point of samples) {
      if (nearestBoundaryDistance(point, b) <= tolerance) closeSamples += 1;
    }
    if (closeSamples >= Math.max(2, samples.length * 0.45)) {
      length += edgeLength * (closeSamples / samples.length);
    }
  }
  return length;
}

function areNeighborPieces(a: Point[], b: Point[]): boolean {
  return Math.max(sharedBoundaryLength(a, b), sharedBoundaryLength(b, a)) >= 16;
}

function edgeSharedWithPolygon(edge: { from: Point; to: Point }, polygon: Point[], tolerance = mergePolygonTolerance): boolean {
  const edgeLength = Math.hypot(edge.to.x - edge.from.x, edge.to.y - edge.from.y);
  if (edgeLength < 1) return false;
  const samples = sampleSegment(edge.from, edge.to, 6);
  let closeSamples = 0;
  for (const point of samples) {
    if (nearestBoundaryDistance(point, polygon) <= tolerance) closeSamples += 1;
  }
  return closeSamples >= Math.max(2, samples.length * 0.45);
}

function mergePolygonsByExactEdges(a: Point[], b: Point[]): Point[] | null {
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

function drawPolygonToMask(ctx: CanvasRenderingContext2D, points: Point[], bounds: { x: number; y: number }, padding: number, scale: number) {
  if (points.length < 3) return;
  ctx.beginPath();
  ctx.moveTo((points[0].x - bounds.x + padding) * scale, (points[0].y - bounds.y + padding) * scale);
  for (let i = 1; i < points.length; i += 1) {
    ctx.lineTo((points[i].x - bounds.x + padding) * scale, (points[i].y - bounds.y + padding) * scale);
  }
  ctx.closePath();
}

function strokeSharedEdgesToMask(ctx: CanvasRenderingContext2D, edges: Array<{ from: Point; to: Point }>, bounds: { x: number; y: number }, padding: number, scale: number) {
  for (const edge of edges) {
    ctx.beginPath();
    ctx.moveTo((edge.from.x - bounds.x + padding) * scale, (edge.from.y - bounds.y + padding) * scale);
    ctx.lineTo((edge.to.x - bounds.x + padding) * scale, (edge.to.y - bounds.y + padding) * scale);
    ctx.stroke();
  }
}

function mergePolygonsByMask(a: Point[], b: Point[]): Point[] | null {
  if (!areNeighborPieces(a, b)) return null;
  const bounds = pointBounds([...a, ...b]);
  const padding = mergePolygonTolerance * 4 + 8;
  const rawWidth = Math.max(1, bounds.width + padding * 2);
  const rawHeight = Math.max(1, bounds.height + padding * 2);
  const scale = Math.min(1, 1400 / Math.max(rawWidth, rawHeight));
  const width = Math.max(4, Math.ceil(rawWidth * scale));
  const height = Math.max(4, Math.ceil(rawHeight * scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return null;

  ctx.fillStyle = "#fff";
  drawPolygonToMask(ctx, a, bounds, padding, scale);
  ctx.fill();
  drawPolygonToMask(ctx, b, bounds, padding, scale);
  ctx.fill();

  const sharedEdges = [
    ...polygonEdges(a).filter((edge) => edgeSharedWithPolygon(edge, b)),
    ...polygonEdges(b).filter((edge) => edgeSharedWithPolygon(edge, a)),
  ];
  ctx.strokeStyle = "#fff";
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.lineWidth = Math.max(2, mergePolygonTolerance * 2.5 * scale);
  strokeSharedEdgesToMask(ctx, sharedEdges, bounds, padding, scale);

  const data = ctx.getImageData(0, 0, width, height).data;
  const mask = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i += 1) mask[i] = data[i * 4 + 3] > 0 ? 1 : 0;
  const loops = traceBoundaryLoops(mask, width, height);
  const largestLoop = loops.sort((left, right) => Math.abs(polygonArea(right)) - Math.abs(polygonArea(left)))[0] || [];
  if (largestLoop.length < 4) return null;
  const raw = largestLoop.map((point) => ({
    x: point.x / scale + bounds.x - padding,
    y: point.y / scale + bounds.y - padding,
  }));
  const simplified = simplifyClosedPath(raw, Math.max(1.2, 2.2 / Math.max(scale, 1e-6)));
  return simplified.length >= 3 ? simplified : null;
}

function mergePolygons(a: Point[], b: Point[]): Point[] | null {
  return mergePolygonsByExactEdges(a, b) || mergePolygonsByMask(a, b);
}

function cellsToLevelPieces(cells: PieceCell[]): LevelPiece[] {
  const validCells = cells.filter((piece) => piece.points.length >= 3);
  return validCells.map((piece) => {
    const neighbors = validCells
      .filter((candidate) => candidate.id !== piece.id && areNeighborPieces(piece.points, candidate.points))
      .map((candidate) => candidate.id);
    return {
      id: piece.id,
      cell: [0, 0],
      home: tupleFromPoint(polygonCenter(piece.points)),
      points: piece.points.map(tupleFromPoint),
      neighbors,
      cut_lines: [],
      visible_bounds: tupleBounds(piece.points),
      visible_bounds_list: [tupleBounds(piece.points)],
    };
  });
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
  const [jsonText, setJsonText] = useState("");
  const [toast, setToast] = useState<ToastNotice | null>(null);
  const [dirtyModes, setDirtyModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [completedModes, setCompletedModes] = useState<Record<EditMode, boolean>>({ polygon: false, knob: false });
  const [pendingMode, setPendingMode] = useState<EditMode | null>(null);
  const [sortOpen, setSortOpen] = useState(false);
  const [createDialog, setCreateDialog] = useState<CreateDialogKind>(null);
  const [undoStack, setUndoStack] = useState<EditorSnapshot[]>([]);
  const [redoStack, setRedoStack] = useState<EditorSnapshot[]>([]);
  const [pendingImage, setPendingImage] = useState<PendingImage>(null);
  const [processingSteps, setProcessingSteps] = useState<ProcessStep[]>([
    createProcessStep("trim_transparent"),
    createProcessStep("convert_jpg"),
  ]);
  const [processing, setProcessing] = useState(false);
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

  useEffect(() => {
    if (!toast) return undefined;
    const timeout = window.setTimeout(() => setToast((current) => (current?.id === toast.id ? null : current)), 3000);
    return () => window.clearTimeout(timeout);
  }, [toast]);

  useEffect(() => {
    try {
      const worker = new Worker(new URL("./actualPieces.worker.ts", import.meta.url), { type: "module" });
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
    setToast({ id: Date.now(), message });
  }

  const currentTopic = useMemo(() => catalog.topics.find((topic) => topic.id === currentTarget.topicId), [catalog, currentTarget.topicId]);
  const currentCatalogLevel = useMemo(
    () => currentTopic?.levels.find((item) => item.id === currentTarget.levelId),
    [currentTopic, currentTarget.levelId],
  );
  const topicOptions = useMemo<SelectOption[]>(
    () => catalog.topics.map((topic) => ({ value: topic.id, label: localized(topic.name_i18n, locale, topic.name), detail: `${topic.levels.length}` })),
    [catalog.topics, locale],
  );
  const levelOptions = useMemo<SelectOption[]>(
    () => (currentTopic?.levels || []).map((item) => ({ value: item.id, label: localized(item.title_i18n, locale, item.title), detail: item.id })),
    [currentTopic, locale],
  );
  const currentTopicName = localized(currentTopic?.name_i18n, locale, currentTopic?.name || currentTarget.topicId);
  const currentLevelName = localized(currentCatalogLevel?.title_i18n, locale, currentCatalogLevel?.title || level.title || currentTarget.levelId);
  const activeImagePath = modeImagePath(level, activeMode);
  const activeImageTarget = modeImageTarget(level, activeMode);

  useEffect(() => {
    loadEditorImage(
      browserUrlForGodotImage(currentTarget, activeImagePath, activeMode),
      imageNameFromPath(activeImagePath, activeImageTarget === "default" ? "source.png" : `${activeMode}_source.png`),
      activeImagePath,
      activeImageTarget,
      false,
    );
  }, [activeImagePath, activeImageTarget, activeMode, currentTarget.topicId, currentTarget.levelId]);

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
      else loadEditorImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH, "default");
    } catch (error) {
      showToast(error instanceof Error ? `加载 catalog 失败：${error.message}` : "加载 catalog 失败");
      loadEditorImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH, "default");
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
    setJsonText(JSON.stringify(nextLevel, null, 2));
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
  const cutGaps = useMemo(() => findCutGaps(analysisCuts, snapPoints, 1.5, snapThreshold), [analysisCuts, snapPoints]);
  const generatedKnobPieces = useMemo(
    () => (activeMode === "knob" ? generateKnobPieces(image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size) : []),
    [activeMode, image, level.grid.cols, level.grid.rows, level.modes.knob.knob_size],
  );
  const modeReady = {
    polygon: pieces.length > 0,
    knob: knobPieces.length > 0,
  };
  const canSaveToGodot = completedModes.polygon && completedModes.knob && modeReady.polygon && modeReady.knob;
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
    showToast("保存目录...");
    try {
      const response = await fetch("/api/catalog", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(catalog),
      });
      const result = (await response.json()) as { ok?: boolean; path?: string; error?: string };
      if (!response.ok || !result.ok) throw new Error(result.error || `HTTP ${response.status}`);
      showToast(`目录已保存到 ${result.path}`);
    } catch (error) {
      showToast(error instanceof Error ? `保存目录失败：${error.message}` : "保存目录失败");
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

  function createTopic(id: string, name: string) {
    if (!/^[a-zA-Z0-9_-]+$/.test(id)) {
      showToast("主题 ID 只能包含英文、数字、下划线或短横线。");
      return false;
    }
    if (catalog.topics.some((topic) => topic.id === id)) {
      showToast("主题 ID 已存在。");
      return false;
    }
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
    showToast(`已创建主题 ${name}`);
    return true;
  }

  function addLevelToCurrentTopic() {
    setCreateDialog("level");
  }

  function createLevelInCurrentTopic(id: string, title: string) {
    const topicId = currentTopic?.id;
    if (!topicId) return false;
    if (!/^[a-zA-Z0-9_-]+$/.test(id)) {
      showToast("关卡 ID 只能包含英文、数字、下划线或短横线。");
      return false;
    }
    if (currentTopic?.levels.some((item) => item.id === id)) {
      showToast("当前主题下已存在这个关卡 ID。");
      return false;
    }
    const nextTarget = { topicId, levelId: id };
    setCatalog((current) => {
      return {
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
      };
    });
    setCurrentTarget(nextTarget);
    const blankLevel = makeEmptyLevel();
    applyLoadedLevel(
      {
        ...blankLevel,
        id,
        topic_id: topicId,
        title,
        title_i18n: { [locale]: title },
        image: {
          ...blankLevel.image,
          path: `res://levels/${topicId}/${id}/source.png`,
        },
      },
      topicId,
      id,
    );
    showToast(`已创建 ${title}，请上传 source 图并完成两种模式。`);
    return true;
  }

  function markExported() {
    setDirtyModes({ polygon: false, knob: false });
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
      source: imageConfigPath(defaultImageConfig(level)) || `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/source.png`,
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
      if (activeImageTarget === "default") {
        const nextImage = { ...defaultImageConfig(current), width, height };
        return {
          ...current,
          image: nextImage,
          assets: {
            ...(current.assets || {}),
            default_image: nextImage,
          },
        };
      }
      const modeConfig = current.modes[activeImageTarget];
      const imageConfig = typeof modeConfig.image === "string" ? { path: modeConfig.image } : { ...(modeConfig.image || {}) };
      return {
        ...current,
        modes: {
          ...current.modes,
          [activeImageTarget]: {
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
        if (target === "default") {
          const nextImage = {
            ...defaultImageConfig(current),
            name,
            path: godotPath || imageConfigPath(defaultImageConfig(current)),
            width: next.naturalWidth,
            height: next.naturalHeight,
          };
          return {
            ...current,
            image: nextImage,
            assets: {
              ...(current.assets || {}),
              default_image: nextImage,
            },
          };
        }
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
        loadEditorImage(DEFAULT_BROWSER_IMAGE, "cat_moon.png", DEFAULT_IMAGE_PATH, "default", false);
        showToast("当前关卡还没有 source 图，已临时使用示例图预览。");
      }
    };
    next.src = src;
  }

  function recordImageEdit(target: ImageTarget) {
    setUndoStack((current) => [...current.slice(-49), snapshot()]);
    setRedoStack([]);
    const affectedModes: EditMode[] =
      target === "default"
        ? (["polygon", "knob"] as EditMode[]).filter((mode) => modeUsesDefaultImage(level, mode))
        : [target];
    setDirtyModes((current) => affectedModes.reduce((next, mode) => ({ ...next, [mode]: true }), current));
    setCompletedModes((current) => affectedModes.reduce((next, mode) => ({ ...next, [mode]: false }), current));
  }

  async function onUploadImage(file?: File, target: ImageTarget = activeImageTarget) {
    if (!file) return;
    recordImageEdit(target);
    const form = new FormData();
    form.append("source", file);
    try {
      const endpoint =
        target === "default"
          ? `/api/levels/${currentTarget.topicId}/${currentTarget.levelId}/source`
          : `/api/levels/${currentTarget.topicId}/${currentTarget.levelId}/source/${target}`;
      const response = await fetch(endpoint, { method: "POST", body: form });
      const result = (await response.json()) as { ok?: boolean; godotPath?: string; url?: string; error?: string };
      if (!response.ok || !result.ok) throw new Error(result.error || `HTTP ${response.status}`);
      loadEditorImage(
        result.url || URL.createObjectURL(file),
        file.name,
        result.godotPath || (target === "default" ? imageConfigPath(defaultImageConfig(level)) : modeImagePath(level, target)) || DEFAULT_IMAGE_PATH,
        target,
      );
      if (target === "default") {
        setCatalog((current) =>
          updateCatalogLevel(current, currentTarget, (item) => ({
            ...item,
            source: result.godotPath || item.source,
            path: `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/level.json`,
          })),
        );
      }
    } catch (error) {
      showToast(error instanceof Error ? `上传 source 失败：${error.message}` : "上传 source 失败");
      loadEditorImage(
        URL.createObjectURL(file),
        file.name,
        target === "default" ? imageConfigPath(defaultImageConfig(level)) || DEFAULT_IMAGE_PATH : modeImagePath(level, target),
        target,
      );
    }
  }

  async function onUploadPendingImage(file?: File) {
    if (!file) return;
    const form = new FormData();
    form.append("source", file);
    try {
      const response = await fetch(`/api/levels/${currentTarget.topicId}/${currentTarget.levelId}/pending-image`, { method: "POST", body: form });
      const result = (await response.json()) as { ok?: boolean; pendingId?: string; name?: string; url?: string; error?: string };
      if (!response.ok || !result.ok || !result.pendingId || !result.url) throw new Error(result.error || `HTTP ${response.status}`);
      setPendingImage({ pendingId: result.pendingId, name: result.name || file.name, url: result.url });
      showToast("待处理图片已上传。");
    } catch (error) {
      showToast(error instanceof Error ? `上传待处理图片失败：${error.message}` : "上传待处理图片失败");
    }
  }

  function addProcessingStep(type: ProcessStepType) {
    setProcessingSteps((current) => [...current, createProcessStep(type)]);
  }

  function updateProcessingStep(id: string, patch: Partial<ProcessStep>) {
    setProcessingSteps((current) => current.map((step) => (step.id === id ? { ...step, ...patch } : step)));
  }

  function removeProcessingStep(id: string) {
    setProcessingSteps((current) => current.filter((step) => step.id !== id));
  }

  function onProcessStepDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    setProcessingSteps((current) => {
      const oldIndex = current.findIndex((step) => step.id === active.id);
      const newIndex = current.findIndex((step) => step.id === over.id);
      if (oldIndex < 0 || newIndex < 0) return current;
      return arrayMove(current, oldIndex, newIndex);
    });
  }

  async function applyProcessingPipeline(target: ImageTarget) {
    if (!pendingImage) {
      showToast("请先上传待处理图片。");
      return;
    }
    if (!processingSteps.length) {
      showToast("请先添加至少一个处理步骤。");
      return;
    }
    recordImageEdit(target);
    setProcessing(true);
    try {
      const response = await fetch(`/api/levels/${currentTarget.topicId}/${currentTarget.levelId}/process-image`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          pendingId: pendingImage.pendingId,
          target,
          steps: processingSteps.map(({ id: _id, ...step }) => step),
        }),
      });
      const result = (await response.json()) as { ok?: boolean; godotPath?: string; url?: string; error?: string };
      if (!response.ok || !result.ok || !result.godotPath || !result.url) throw new Error(result.error || `HTTP ${response.status}`);
      loadEditorImage(result.url, imageNameFromPath(result.godotPath, target === "default" ? "source.png" : `${target}_source.png`), result.godotPath, target);
      if (target === "default") {
        setCatalog((current) =>
          updateCatalogLevel(current, currentTarget, (item) => ({
            ...item,
            source: result.godotPath || item.source,
            path: `res://levels/${currentTarget.topicId}/${currentTarget.levelId}/level.json`,
          })),
        );
      }
      showToast("图片处理完成。");
    } catch (error) {
      showToast(error instanceof Error ? `图片处理失败：${error.message}` : "图片处理失败");
    } finally {
      setProcessing(false);
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
    recordImageEdit("default");
    setLevel((current) => {
      const nextImage = { ...defaultImageConfig(current), path };
      return {
        ...current,
        image: nextImage,
        assets: {
          ...(current.assets || {}),
          default_image: nextImage,
        },
      };
    });
  }

  function updateModeImagePath(mode: EditMode, path: string) {
    recordEdit(mode);
    setLevel((current) => {
      const modeConfig = current.modes[mode];
      const nextMode = { ...modeConfig };
      if (path.trim()) nextMode.image = { path: path.trim() };
      else nextMode.image = { use: "default" };
      delete nextMode.source_image;
      return {
        ...current,
        modes: {
          ...current.modes,
          [mode]: nextMode,
        },
      };
    });
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
      modes: {
        polygon: {
          ...level.modes.polygon,
          source: "precomputed",
          pieces: polygonLevelPieces,
        },
        knob: {
          ...level.modes.knob,
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
    showToast("JSON 已导出。");
  }

  async function saveJsonToGodot(): Promise<boolean> {
    if (!canSaveToGodot) {
      showToast("需要先完成多边形和凹凸两个模式，才允许保存到 Godot。");
      return false;
    }
    const text = buildJson();
    showToast("保存中...");
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
      showToast(`已保存到 ${result.path}`);
      setCatalog(catalogForSave());
      markExported();
      return true;
    } catch (error) {
      showToast(error instanceof Error ? `保存失败：${error.message}` : "保存失败");
      return false;
    }
  }

  function importJson(file?: File) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const data = JSON.parse(String(reader.result)) as LevelConfig;
        const nextLevel = normalizeLevelConfig(data, currentTarget.topicId, currentTarget.levelId);
        setLevel(nextLevel);
        const importedCuts: CutLine[] = [
          ...(data.editor?.cuts || []).map((cut) => ({ ...cut, points: cut.points.map(([x, y]) => ({ x, y })) })),
          ...(data.editor?.shapes || []).map((shape) => ({ ...shape, points: shape.points.map(([x, y]) => ({ x, y })) })),
        ];
        setCuts(importedCuts);
        setAnalysisCuts(importedCuts);
        setPieces((data.editor?.pieces || []).map((piece) => ({ ...piece, points: piece.points.map(([x, y]) => ({ x, y })) })));
        setKnobPieces(data.modes?.knob?.pieces || []);
        setSelectedId(importedCuts[0]?.id || "");
        setSelectedPieceIds([]);
        setJsonText(JSON.stringify(nextLevel, null, 2));
        setDirtyModes({ polygon: false, knob: false });
        setCompletedModes({
          polygon: Boolean(data.modes?.polygon?.pieces?.length),
          knob: Boolean(data.modes?.knob?.pieces?.length),
        });
        setUndoStack([]);
        setRedoStack([]);
        showToast("JSON 已导入。");
      } catch (error) {
        showToast(error instanceof Error ? `导入 JSON 失败：${error.message}` : "导入 JSON 失败");
      }
    };
    reader.onerror = () => showToast("读取 JSON 失败");
    reader.readAsText(file);
  }

  return (
    <div className="grid h-screen min-h-0 grid-cols-[320px_minmax(720px,1fr)_340px] overflow-hidden bg-linen text-ink max-xl:grid-cols-[290px_minmax(520px,1fr)]">
      <aside className="min-h-0 overflow-auto border-r border-stone-300 bg-paper p-4">
        <div className="flex items-start gap-3 border-b border-stone-300 pb-4">
          <Hexagon className="mt-1 text-clay" size={22} />
          <div>
            <h1 className="text-xl font-semibold">关卡编辑器</h1>
            <p className="text-sm text-muted">TypeScript · Tailwind · 非网格切割</p>
          </div>
        </div>

        <section className="mt-5 grid gap-3">
          <PanelTitle>关卡导航</PanelTitle>
          <div className="grid grid-cols-[1fr_auto_auto_auto] gap-2">
            <SelectBox value={locale} options={catalog.locales.map((item) => ({ value: item, label: item }))} onValueChange={setLocale} placeholder="语言" />
            <button className="btn" onClick={addTopic}>
              主题
            </button>
            <button className="btn" onClick={addLevelToCurrentTopic}>
              关卡
            </button>
            <button className="btn" onClick={() => setSortOpen(true)}>
              <GripVertical size={16} />
            </button>
          </div>
          <Field label="主题">
            <SelectBox value={currentTarget.topicId} options={topicOptions} onValueChange={selectTopic} placeholder="选择主题" />
          </Field>
          <Field label="关卡">
            <SelectBox value={currentTarget.levelId} options={levelOptions} onValueChange={selectLevel} placeholder="选择关卡" />
          </Field>
          <Field label="当前主题名">
            <Input value={localized(currentTopic?.name_i18n, locale, currentTopic?.name || "")} onChange={(event) => updateTopicName(event.target.value)} />
          </Field>
          <div className="grid grid-cols-2 gap-2">
            <button className="btn" onClick={() => adjacentLevel(-1) && requestLevelChange(adjacentLevel(-1) as LevelTarget)}>
              上一关
            </button>
            <button className="btn" onClick={() => adjacentLevel(1) && requestLevelChange(adjacentLevel(1) as LevelTarget)}>
              下一关
            </button>
          </div>
        </section>

        <section className="mt-5 grid gap-3">
          <PanelTitle>关卡</PanelTitle>
          <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-ink">
            {currentTopicName} <span className="text-muted">-&gt;</span> {currentLevelName}
          </div>
          <Field label="标题">
            <Input value={localized(level.title_i18n, locale, level.title)} onChange={(event) => updateLocalizedTitle(event.target.value)} />
          </Field>
          <Field label="介绍">
            <Textarea className="min-h-24" value={localized(level.description_i18n, locale, level.description)} onChange={(event) => updateLocalizedDescription(event.target.value)} />
          </Field>
          <Field label="公共图片路径">
            <Input value={imageConfigPath(defaultImageConfig(level))} onChange={(event) => updateImagePath(event.target.value)} />
          </Field>
          <Field label="多边形图片路径">
            <Input
              placeholder="留空则使用公共图片"
              value={imageConfigPath(level.modes.polygon.image || level.modes.polygon.source_image)}
              onChange={(event) => updateModeImagePath("polygon", event.target.value)}
            />
          </Field>
          <Field label="凹凸图片路径">
            <Input
              placeholder="留空则使用公共图片"
              value={imageConfigPath(level.modes.knob.image || level.modes.knob.source_image)}
              onChange={(event) => updateModeImagePath("knob", event.target.value)}
            />
          </Field>
          <div className="grid grid-cols-2 gap-2">
            <label className="fileButton">
              <Upload size={16} />
              上传公共图
              <input hidden type="file" accept="image/*" onChange={(event) => onUploadImage(event.target.files?.[0], "default")} />
            </label>
            <label className="fileButton">
              <Upload size={16} />
              上传当前模式图
              <input hidden type="file" accept="image/*" onChange={(event) => onUploadImage(event.target.files?.[0], activeMode)} />
            </label>
          </div>
          <div className="rounded-md border border-stone-300 bg-white/70 p-3">
            <div className="flex items-center justify-between gap-2">
              <PanelTitle>图片处理链</PanelTitle>
              <label className="btn !min-h-8 cursor-pointer !px-2 !py-1">
                <Upload size={14} />
                待处理图
                <input hidden type="file" accept="image/*" onChange={(event) => onUploadPendingImage(event.target.files?.[0])} />
              </label>
            </div>
            {pendingImage && (
              <div className="mt-3 grid gap-2">
                <img src={pendingImage.url} alt={pendingImage.name} className="max-h-36 w-full rounded-md border border-stone-200 bg-white object-contain" />
                <div className="truncate text-xs text-muted">{pendingImage.name}</div>
              </div>
            )}
            <div className="mt-3 grid grid-cols-3 gap-2">
              <button className="btn !px-2" onClick={() => addProcessingStep("remove_background")}>
                去背景
              </button>
              <button className="btn !px-2" onClick={() => addProcessingStep("trim_transparent")}>
                裁边
              </button>
              <button className="btn !px-2" onClick={() => addProcessingStep("convert_jpg")}>
                JPG
              </button>
            </div>
            <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onProcessStepDragEnd}>
              <SortableContext items={processingSteps.map((step) => step.id)} strategy={verticalListSortingStrategy}>
                <div className="mt-3 grid gap-2">
                  {processingSteps.map((step) => (
                    <ProcessStepRow
                      key={step.id}
                      step={step}
                      onUpdate={(patch) => updateProcessingStep(step.id, patch)}
                      onRemove={() => removeProcessingStep(step.id)}
                    />
                  ))}
                </div>
              </SortableContext>
            </DndContext>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <button className="btnPrimary" disabled={processing || !pendingImage || !processingSteps.length} onClick={() => applyProcessingPipeline("default")}>
                应用到公共图
              </button>
              <button className="btn" disabled={processing || !pendingImage || !processingSteps.length} onClick={() => applyProcessingPipeline(activeMode)}>
                应用到当前模式
              </button>
            </div>
          </div>
        </section>

        <section className="mt-6 grid gap-3">
          <PanelTitle>背景</PanelTitle>
          <div className="grid grid-cols-[1fr_56px] gap-2">
            <SelectBox
              value={level.background.type}
              options={[
                { value: "color", label: "纯色" },
                { value: "image", label: "图片" },
              ]}
              onValueChange={(value) => updateBackground("type", value as "color" | "image")}
              placeholder="背景"
            />
            <Input className="h-10 p-1" type="color" value={level.background.color} onChange={(event) => updateBackground("color", event.target.value)} />
          </div>
          <Field label="背景图片路径">
            <Input value={level.background.path} onChange={(event) => updateBackground("path", event.target.value)} />
          </Field>
        </section>

      </aside>

      <main className="grid min-h-0 min-w-0 grid-rows-[auto_1fr] overflow-hidden">
        <div className="flex min-h-14 items-center justify-between gap-3 overflow-auto border-b border-stone-300 bg-[#f7efe2] px-3">
          <div className="flex min-w-0 items-center gap-3">
            <div className="inline-flex shrink-0 gap-1 rounded-md border border-stone-300 bg-white p-1">
              <button className={activeMode === "polygon" ? "iconBtnActive" : "iconBtn"} onClick={() => requestModeChange("polygon")} title="多边形">
                <Hexagon size={18} />
                {(completedModes.polygon || dirtyModes.polygon) && <span className={completedModes.polygon ? "statusDot done" : "statusDot dirty"} />}
              </button>
              <button className={activeMode === "knob" ? "iconBtnActive" : "iconBtn"} onClick={() => requestModeChange("knob")} title="凹凸">
                <Puzzle size={18} />
                {(completedModes.knob || dirtyModes.knob) && <span className={completedModes.knob ? "statusDot done" : "statusDot dirty"} />}
              </button>
            </div>
            <div className="min-w-0 truncate text-sm text-ink">
              {currentTopicName} <span className="text-muted">-&gt;</span> {currentLevelName}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button className="btnPrimary" onClick={markCurrentModeComplete}>
              完成
            </button>
            <button className="btn" onClick={downloadJson}>
              <Download size={16} />
              JSON
            </button>
            <label className="fileButton !min-h-9 !border-solid">
              <Upload size={16} />
              JSON
              <input hidden type="file" accept="application/json,.json" onChange={(event) => importJson(event.target.files?.[0])} />
            </label>
            <button className="btnPrimary" disabled={!canSaveToGodot} onClick={saveJsonToGodot}>
              <Save size={16} />
              Godot
            </button>
            <button className="btn" onClick={saveCatalogOnly}>
              目录
            </button>
          </div>
        </div>

        <div className="relative grid min-h-0 place-items-center overflow-hidden p-5" style={{ background: level.background.color }}>
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
                    polygonView === "inspect" && actualPreview?.smallPieceIds.includes(piece.id) ? "smallPiece" : "",
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
            {activeMode === "polygon" && polygonView === "inspect" && cutGaps.map((gap, index) => (
              <g key={`${gap.cutId}_${index}`} className="gapWarning">
                <line x1={gap.point.x} y1={gap.point.y} x2={gap.nearest.x} y2={gap.nearest.y} />
                <circle cx={gap.point.x} cy={gap.point.y} r={12} />
              </g>
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

      <aside className="flex min-h-0 flex-col gap-4 overflow-y-auto border-l border-stone-300 bg-paper p-4 max-xl:col-span-2 max-xl:border-l-0 max-xl:border-t">
        <section className="grid gap-3">
          <PanelTitle>工具</PanelTitle>
          <div className="grid grid-cols-6 gap-2">
            <button className="iconBtn" disabled={!undoStack.length} onClick={undo} title="撤销 (Cmd/Ctrl+Z)">
              <Undo2 size={18} />
            </button>
            <button className="iconBtn" disabled={!redoStack.length} onClick={redo} title="重做 (Cmd/Ctrl+Shift+Z / Cmd/Ctrl+Y)">
              <Redo2 size={18} />
            </button>
            <button className={snapEnabled ? "iconBtnActive" : "iconBtn"} onClick={() => setSnapEnabled((value) => !value)} title="吸附">
              <Magnet size={18} />
            </button>
            <button className="iconBtnActive" onClick={mergeSelectedPieces} title="合并">
              <Plus size={18} />
            </button>
            {activeMode === "polygon" && (
              <button className="iconBtnDanger" disabled={!selectedId} onClick={removeSelected} title="删除选中线条 (Backspace)">
                <Trash2 size={18} />
              </button>
            )}
            {activeMode === "polygon" && (
              <button className="iconBtnDanger" disabled={!cuts.length} onClick={clearAllCuts} title="清空线条">
                <X size={18} />
              </button>
            )}
          </div>
        </section>

        {activeMode === "polygon" && (
          <section className="grid gap-3 border-t border-stone-300 pt-4">
            <PanelTitle>多边形</PanelTitle>
            <div className="grid grid-cols-3 gap-2">
              {(["result", "edit", "inspect"] as PolygonViewMode[]).map((view) => (
                <button key={view} className={polygonView === view ? "iconBtnActive" : "iconBtn"} onClick={() => setPolygonView(view)} title={view === "result" ? "结果" : view === "edit" ? "编辑" : "检查"}>
                  {view === "result" ? <Eye size={18} /> : view === "edit" ? <Pencil size={18} /> : <CircleAlert size={18} />}
                </button>
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
            <div className="grid grid-cols-3 gap-2">
              {(["knob", "circle", "star", "blob", "zigzag", "crescent"] as CutTemplate[]).map((template) => (
                <ShapeButton key={template} template={template} onClick={() => addPreset(template)} />
              ))}
            </div>
            {(actualPreview?.smallPieceIds.length || 0) > 0 && <p className="rounded-md bg-[#fff3de] px-3 py-2 text-sm text-[#9e3f35]">过小碎片：{actualPreview?.smallPieceIds.length}</p>}
            {cutGaps.length > 0 && <p className="rounded-md bg-[#fff3de] px-3 py-2 text-sm text-muted">未连接端点：{cutGaps.length}</p>}
            <div className="grid max-h-56 gap-2 overflow-auto pr-1">
              {cuts.map((cut) => (
                <button key={cut.id} className={cut.id === selectedId ? "objectActive" : "object"} onClick={() => setSelectedId(cut.id)}>
                  <span>{templateName(cut.template)}</span>
                  <small>{cut.type === "preset_shape" ? "形状" : "线"}</small>
                </button>
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
                <Input type="number" min="1" max="12" step="1" value={level.grid.cols} onChange={(event) => updateGrid("cols", Number(event.target.value))} />
              </Field>
              <Field label="行">
                <Input type="number" min="1" max="12" step="1" value={level.grid.rows} onChange={(event) => updateGrid("rows", Number(event.target.value))} />
              </Field>
            </div>
            <Field label="尺寸">
              <Input type="number" min="80" max="320" step="10" value={level.grid.piece_size} onChange={(event) => updateGrid("piece_size", Number(event.target.value))} />
            </Field>
            <Field label={`凸耳 ${level.modes.knob.knob_size.toFixed(2)}`}>
              <input type="range" min="0.12" max="0.36" step="0.01" value={level.modes.knob.knob_size} onChange={(event) => updateKnobSize(Number(event.target.value))} />
            </Field>
          </section>
        )}
      </aside>
      {toast && (
        <div className="toastViewport" role="status" aria-live="polite">
          <div className="toastCard">
            <span>{toast.message}</span>
            <button className="toastClose" onClick={() => setToast(null)} aria-label="关闭提示">
              <X size={16} />
            </button>
          </div>
        </div>
      )}
      <SortDialog
        open={sortOpen}
        onOpenChange={setSortOpen}
        sensors={sensors}
        catalog={catalog}
        currentTopic={currentTopic}
        locale={locale}
        currentTarget={currentTarget}
        onDragEnd={onSortDragEnd}
        onSave={saveCatalogOnly}
      />
      <CreateItemDialog
        open={createDialog === "topic"}
        title="新建主题"
        idLabel="主题 ID"
        nameLabel="主题名"
        defaultName="新主题"
        onOpenChange={(open) => setCreateDialog(open ? "topic" : null)}
        onSubmit={createTopic}
      />
      <CreateItemDialog
        open={createDialog === "level"}
        title="新建关卡"
        idLabel="关卡 ID"
        nameLabel="关卡名"
        defaultName="新关卡"
        description={currentTopicName ? `创建到 ${currentTopicName}` : undefined}
        onOpenChange={(open) => setCreateDialog(open ? "level" : null)}
        onSubmit={createLevelInCurrentTopic}
      />
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

type InputProps = React.InputHTMLAttributes<HTMLInputElement>;

function Input({ className = "", ...props }: InputProps) {
  return <input className={`input ${className}`} {...props} />;
}

type TextareaProps = React.TextareaHTMLAttributes<HTMLTextAreaElement>;

function Textarea({ className = "", ...props }: TextareaProps) {
  return <textarea className={`input ${className}`} {...props} />;
}

function SelectBox({ value, options, placeholder, onValueChange }: { value: string; options: SelectOption[]; placeholder: string; onValueChange: (value: string) => void }) {
  return (
    <Select.Root value={value} onValueChange={onValueChange}>
      <Select.Trigger className="selectTrigger" aria-label={placeholder}>
        <Select.Value placeholder={placeholder} />
        <Select.Icon>
          <ChevronDown size={16} />
        </Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content className="selectContent" position="popper" sideOffset={6}>
          <Select.Viewport className="p-1">
            {options.map((option) => (
              <Select.Item key={option.value} value={option.value} className="selectItem">
                <Select.ItemText>
                  <span>{option.label}</span>
                  {option.detail && <small>{option.detail}</small>}
                </Select.ItemText>
                <Select.ItemIndicator>
                  <Check size={14} />
                </Select.ItemIndicator>
              </Select.Item>
            ))}
          </Select.Viewport>
        </Select.Content>
      </Select.Portal>
    </Select.Root>
  );
}

function SortDialog({
  open,
  onOpenChange,
  sensors,
  catalog,
  currentTopic,
  locale,
  currentTarget,
  onDragEnd,
  onSave,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  sensors: ReturnType<typeof useSensors>;
  catalog: LevelCatalog;
  currentTopic?: CatalogTopic;
  locale: string;
  currentTarget: LevelTarget;
  onDragEnd: (event: DragEndEvent) => void;
  onSave: () => void;
}) {
  const topicIds = catalog.topics.map((topic) => `topic:${topic.id}`);
  const levelIds = (currentTopic?.levels || []).map((item) => `level:${item.id}`);
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="dialogOverlay" />
        <Dialog.Content className="dialogContent">
          <div className="flex items-start justify-between gap-4">
            <div>
              <Dialog.Title className="text-xl font-semibold text-ink">排序</Dialog.Title>
              <Dialog.Description className="mt-1 text-sm text-muted">拖拽调整主题和当前主题下的关卡顺序。</Dialog.Description>
            </div>
            <Dialog.Close className="iconBtn" aria-label="关闭">
              <X size={18} />
            </Dialog.Close>
          </div>
          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
            <div className="mt-5 grid grid-cols-2 gap-4 max-sm:grid-cols-1">
              <section className="grid gap-2">
                <PanelTitle>主题</PanelTitle>
                <SortableContext items={topicIds} strategy={verticalListSortingStrategy}>
                  {catalog.topics.map((topic) => (
                    <SortableRow
                      key={topic.id}
                      id={`topic:${topic.id}`}
                      label={localized(topic.name_i18n, locale, topic.name)}
                      detail={`${topic.levels.length}`}
                      active={topic.id === currentTarget.topicId}
                    />
                  ))}
                </SortableContext>
              </section>
              <section className="grid gap-2">
                <PanelTitle>关卡</PanelTitle>
                <SortableContext items={levelIds} strategy={verticalListSortingStrategy}>
                  {(currentTopic?.levels || []).map((item) => (
                    <SortableRow
                      key={item.id}
                      id={`level:${item.id}`}
                      label={localized(item.title_i18n, locale, item.title)}
                      detail={item.id}
                      active={item.id === currentTarget.levelId}
                    />
                  ))}
                </SortableContext>
              </section>
            </div>
          </DndContext>
          <div className="mt-5 flex justify-end gap-2">
            <button className="btn" onClick={onSave}>
              保存目录
            </button>
            <Dialog.Close className="btnPrimary">完成</Dialog.Close>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function CreateItemDialog({
  open,
  title,
  description,
  idLabel,
  nameLabel,
  defaultName,
  onOpenChange,
  onSubmit,
}: {
  open: boolean;
  title: string;
  description?: string;
  idLabel: string;
  nameLabel: string;
  defaultName: string;
  onOpenChange: (open: boolean) => void;
  onSubmit: (id: string, name: string) => boolean;
}) {
  const [id, setId] = useState("");
  const [name, setName] = useState(defaultName);

  useEffect(() => {
    if (!open) return;
    setId("");
    setName(defaultName);
  }, [defaultName, open]);

  function submit(event: React.FormEvent) {
    event.preventDefault();
    const cleanId = id.trim();
    const cleanName = name.trim() || cleanId;
    if (!cleanId) return;
    if (onSubmit(cleanId, cleanName)) onOpenChange(false);
  }

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="dialogOverlay" />
        <Dialog.Content className="dialogContent max-w-md">
          <div className="flex items-start justify-between gap-4">
            <div>
              <Dialog.Title className="text-xl font-semibold text-ink">{title}</Dialog.Title>
              {description && <Dialog.Description className="mt-1 text-sm text-muted">{description}</Dialog.Description>}
            </div>
            <Dialog.Close className="iconBtn" aria-label="关闭">
              <X size={18} />
            </Dialog.Close>
          </div>
          <form className="mt-5 grid gap-3" onSubmit={submit}>
            <Field label={idLabel}>
              <Input value={id} placeholder="english_id" autoFocus onChange={(event) => setId(event.target.value)} />
            </Field>
            <Field label={nameLabel}>
              <Input value={name} onChange={(event) => setName(event.target.value)} />
            </Field>
            <p className="text-xs text-muted">ID 只能包含英文、数字、下划线或短横线。</p>
            <div className="mt-2 flex justify-end gap-2">
              <Dialog.Close className="btn" type="button">
                取消
              </Dialog.Close>
              <button className="btnPrimary" type="submit">
                创建
              </button>
            </div>
          </form>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function SortableRow({ id, label, detail, active }: { id: string; label: string; detail: string; active: boolean }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });
  return (
    <div
      ref={setNodeRef}
      className={`${active ? "sortRowActive" : "sortRow"} ${isDragging ? "opacity-70" : ""}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      {...attributes}
      {...listeners}
    >
      <GripVertical size={16} />
      <span className="min-w-0 truncate">{label}</span>
      <small className="ml-auto text-muted">{detail}</small>
    </div>
  );
}

function ProcessStepRow({
  step,
  onUpdate,
  onRemove,
}: {
  step: ProcessStep;
  onUpdate: (patch: Partial<ProcessStep>) => void;
  onRemove: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: step.id });
  return (
    <div
      ref={setNodeRef}
      className={`rounded-md border border-stone-300 bg-white p-2 text-sm ${isDragging ? "opacity-70" : ""}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
    >
      <div className="flex items-center gap-2">
        <button className="iconBtn !min-h-8 !px-2" type="button" {...attributes} {...listeners} aria-label="拖拽排序">
          <GripVertical size={15} />
        </button>
        <div className="min-w-0 flex-1 font-medium text-ink">{processStepLabel(step.type)}</div>
        <button className="iconBtnDanger !min-h-8 !px-2" type="button" onClick={onRemove} aria-label="删除步骤">
          <Trash2 size={15} />
        </button>
      </div>
      {step.type === "remove_background" && (
        <Field label="容差">
          <Input type="number" min="0" max="441" value={step.tolerance} onChange={(event) => onUpdate({ tolerance: Number(event.target.value) })} />
        </Field>
      )}
      {step.type === "trim_transparent" && (
        <Field label="留边">
          <Input type="number" min="0" max="256" value={step.padding} onChange={(event) => onUpdate({ padding: Number(event.target.value) })} />
        </Field>
      )}
      {step.type === "convert_jpg" && (
        <div className="mt-2 grid grid-cols-[1fr_56px] gap-2">
          <Field label="质量">
            <Input type="number" min="1" max="100" value={step.quality} onChange={(event) => onUpdate({ quality: Number(event.target.value) })} />
          </Field>
          <Field label="底色">
            <Input className="h-10 p-1" type="color" value={step.background} onChange={(event) => onUpdate({ background: event.target.value })} />
          </Field>
        </div>
      )}
    </div>
  );
}

function ShapeButton({ template, onClick }: { template: CutTemplate; onClick: () => void }) {
  return (
    <button
      className="shapeButton"
      draggable
      title={templateName(template)}
      onClick={onClick}
      onDragStart={(event) => {
        event.dataTransfer.setData("application/x-jigcat-shape", template);
        event.dataTransfer.effectAllowed = "copy";
      }}
    >
      <svg viewBox="0 0 64 64" className="h-10 w-full" aria-hidden="true">
        <path d={shapeIconPath(template)} />
      </svg>
    </button>
  );
}

function shapeIconPath(template: CutTemplate) {
  return catmullRomPath(presetShapePoints(template, { x: 0, y: 0, width: 64, height: 64 }), shapeTension(template), true);
}

function shapeTension(template: CutTemplate) {
  return template === "star" || template === "zigzag" || template === "knob" ? 0 : 0.25;
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
