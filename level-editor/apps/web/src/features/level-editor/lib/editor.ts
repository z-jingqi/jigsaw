import { makeEmptyLevel } from "../../../geometry";
import type { CutLine, LevelConfig, PendingImageItem, Point } from "../../../types";
import { pointBounds } from "./polygonPieces";
import type { EditMode, EditorSnapshot, PolygonViewMode } from "../types";

export const SNAP_THRESHOLD = 18;
export const EDITOR_LOCALE = "en";
export const DEFAULT_CUT_COLOR = "#5a3a22";

export function cloneSnapshot(snapshot: EditorSnapshot): EditorSnapshot {
  return structuredClone(snapshot);
}

export function isTextEditingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tagName = target.tagName.toLowerCase();
  return target.isContentEditable || tagName === "input" || tagName === "textarea" || tagName === "select";
}

export function levelImageUrl(topicId: string, levelId: string, path: string) {
  if (!topicId || !levelId || !path) return "";
  const prefix = `res://levels/${topicId}/`;
  if (!path.startsWith(prefix)) return "";
  const fileName = path.slice(prefix.length);
  const parts = fileName.split("/");
  if (parts.length < 3) return "";
  return `/api/levels/${encodeURIComponent(topicId)}/${encodeURIComponent(parts[0])}/${encodeURIComponent(parts[1])}/assets/${encodeURIComponent(parts.slice(2).join("/"))}?mtime=${Date.now()}`;
}

export function displayPendingImageName(item: PendingImageItem) {
  return item.name.replace(/\.[^.]+$/, "");
}

export function polygonViewLabel(view: PolygonViewMode): string {
  if (view === "result") return "查看";
  if (view === "edit") return "编辑";
  return "检查";
}

export function previewBufferToDataUrl(width: number, height: number, previewBuffer: ArrayBuffer): string {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return "";
  ctx.putImageData(new ImageData(new Uint8ClampedArray(previewBuffer), width, height), 0, 0);
  return canvas.toDataURL("image/png");
}

export function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

export function scaleCutPoints(points: Point[], center: Point, scale: number): Point[] {
  return points.map((point) => ({
    x: center.x + (point.x - center.x) * scale,
    y: center.y + (point.y - center.y) * scale,
  }));
}

export function shapeResizeHandles(cut: CutLine) {
  const bounds = pointBounds(cut.points);
  return [
    { id: "nw", x: bounds.x, y: bounds.y },
    { id: "ne", x: bounds.x + bounds.width, y: bounds.y },
    { id: "se", x: bounds.x + bounds.width, y: bounds.y + bounds.height },
    { id: "sw", x: bounds.x, y: bounds.y + bounds.height },
  ];
}

export function normalizeLevelConfig(data: Partial<LevelConfig>, topicId?: string, levelId?: string): LevelConfig {
  const defaults = makeEmptyLevel();
  return {
    ...defaults,
    ...data,
    id: levelId || data.id || defaults.id,
    topic_id: topicId || data.topic_id || defaults.topic_id,
    image: { ...defaults.image, ...(data.image || {}) },
    assets: { ...(defaults.assets || {}), ...(data.assets || {}) },
    background: { ...defaults.background, ...data.background },
    grid: { ...defaults.grid, ...data.grid },
    modes: {
      polygon: {
        ...defaults.modes.polygon,
        ...(data.modes?.polygon || {}),
      },
      knob: {
        ...defaults.modes.knob,
        ...(data.modes?.knob || {}),
        cols: data.modes?.knob?.cols ?? data.grid?.cols ?? defaults.grid.cols,
        rows: data.modes?.knob?.rows ?? data.grid?.rows ?? defaults.grid.rows,
        piece_size: data.modes?.knob?.piece_size ?? data.grid?.piece_size ?? defaults.grid.piece_size,
      },
      swap: {
        ...defaults.modes.swap,
        ...(data.modes?.swap || {}),
        cols: 3,
        rows: 4,
      },
    },
    editor: { ...defaults.editor, ...data.editor },
  };
}
