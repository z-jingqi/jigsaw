import React from "react";
import { createRoot } from "react-dom/client";
import {
  closestCenter,
  DndContext,
  type DragEndEvent,
  type DragStartEvent,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { Check, ChevronDown, ChevronRight, Edit3, Eye, FolderPlus, Gamepad2, GripVertical, Hexagon, ImageUp, Pencil, Plus, Redo2, Save, Sparkles, Trash2, Undo2, Wand2 } from "lucide-react";
import { HexColorPicker } from "react-colorful";
import Cropper, { type Area } from "react-easy-crop";
import { toast } from "sonner";
import { assetUrl, loadCatalog, loadLevel, saveCatalog, saveLevel, sourceUrl, uploadSource, uploadTopicAsset } from "./api";
import { Button } from "./components/ui/button";
import { Input } from "./components/ui/input";
import { Toaster } from "./components/ui/sonner";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "./components/ui/alert-dialog";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "./components/ui/dialog";
import { fillCoverageGaps, generatePieces, manualShapePolygon, mergePieces, sequentialId, withNeighbors, zhI18n, type ManualShape, type ShapeKind, type ShapeRequest } from "./geometry";
import { cn } from "./lib/utils";
import type { CatalogGroup, CatalogLevel, CatalogRenameOperation, CatalogTopic, LevelCatalog, LevelConfig, LevelPiece, LevelStatus, Point, SeedAssist, SelectedLevel } from "./types";
import "./styles.css";
import "react-easy-crop/react-easy-crop.css";

const emptyCatalog: LevelCatalog = {
  version: 4,
  default_locale: "zh-Hans",
  locales: ["zh-Hans", "zh", "en", "ja"],
  image_presets: [{ id: "mobile_portrait_3x4", name: "Mobile portrait 3:4", aspect_ratio: 3 / 4, default: true }],
  topics: [],
};
const DEFAULT_POLYGON_TARGET_COUNT = 36;
const DEFAULT_KNOB_COLS = 6;
const DEFAULT_KNOB_ROWS = 8;
const DEFAULT_KNOB_SIZE = 0.24;
const DEFAULT_SWAP_COLS = 5;
const DEFAULT_SWAP_ROWS = 7;
const DEFAULT_POLYGON_SEED_COUNT = 1;
const DEFAULT_KNOB_SEED_COUNT = 1;
const DEFAULT_TOPIC_COLOR = "#D9933F";
const DEFAULT_GROUP_COLOR = "#F6EBD4";
const FLAT_GROUP_ID = "levels";
const HEX_COLOR_RE = /^#[0-9a-fA-F]{6}$/;
const LINE_COLOR_OPTIONS = ["#FFF6E6", "#5A3A22", "#D9933F", "#2f7667", "#38BDF8", "#FFFFFF", "#111827"];
const SHAPE_OPTIONS: Array<{ kind: ShapeKind; label: string }> = [
  { kind: "circle", label: "圆形" },
  { kind: "square", label: "正方形" },
  { kind: "heart", label: "心形" },
  { kind: "triangle", label: "三角形" },
  { kind: "star", label: "五角星" },
  { kind: "sector", label: "扇形" },
  { kind: "crescent", label: "月牙" },
  { kind: "hexagon", label: "六边形" },
  { kind: "blob", label: "不规则块" },
  { kind: "shard", label: "碎片块" },
];

type DeleteTarget =
  | { kind: "topic"; topic: CatalogTopic }
  | { kind: "group"; topic: CatalogTopic; group: CatalogGroup }
  | { kind: "level"; topic: CatalogTopic; group: CatalogGroup; level: CatalogLevel };
type TreeSelection =
  | { kind: "topic"; topicId: string }
  | { kind: "group"; topicId: string; groupId: string }
  | { kind: "level"; topicId: string; groupId: string; levelId: string };

function defaultAssist(count: number): SeedAssist {
  return {
    outline: true,
    seed: {
      mode: "auto",
      count,
      piece_ids: [],
    },
  };
}

function normalizeAssist(input: SeedAssist | undefined, defaultCount: number, validIds?: Set<string>): SeedAssist {
  const mode = input?.seed.mode === "manual" ? "manual" : "auto";
  const count = Math.max(0, Math.floor(Number(input?.seed.count ?? defaultCount) || defaultCount));
  const pieceIds = Array.isArray(input?.seed.piece_ids)
    ? input.seed.piece_ids.filter((id) => !validIds || validIds.has(id))
    : [];
  return {
    outline: input?.outline !== false,
    seed: {
      mode,
      count,
      piece_ids: mode === "manual" ? pieceIds : [],
    },
  };
}

function knobSeedIds(cols: number, rows: number) {
  const ids = new Set<string>();
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) ids.add(`knob_${row}_${col}`);
  }
  return ids;
}

function filterAssistPieceIds(assist: SeedAssist, validIds: Set<string>) {
  return normalizeAssist(assist, assist.seed.count, validIds);
}

function App() {
  const [catalog, setCatalog] = React.useState<LevelCatalog>(emptyCatalog);
  const [statuses, setStatuses] = React.useState<LevelStatus[]>([]);
  const [selected, setSelected] = React.useState<TreeSelection | null>(null);
  const [level, setLevel] = React.useState<LevelConfig | null>(null);
  const [expanded, setExpanded] = React.useState<Record<string, boolean>>({});
  const [editingPolygon, setEditingPolygon] = React.useState(false);
  const [editingKnob, setEditingKnob] = React.useState(false);
  const [editMode, setEditMode] = React.useState(false);
  const [renames, setRenames] = React.useState<CatalogRenameOperation[]>([]);
  const [catalogPast, setCatalogPast] = React.useState<LevelCatalog[]>([]);
  const [catalogFuture, setCatalogFuture] = React.useState<LevelCatalog[]>([]);
  const [levelPast, setLevelPast] = React.useState<LevelConfig[]>([]);
  const [levelFuture, setLevelFuture] = React.useState<LevelConfig[]>([]);
  const skipNextLevelLoad = React.useRef(false);

  React.useEffect(() => {
    void refresh();
  }, []);

  React.useEffect(() => {
    if (!selected || selected.kind !== "level") {
      setLevel(null);
      return;
    }
    if (skipNextLevelLoad.current) {
      skipNextLevelLoad.current = false;
      return;
    }
    loadLevel(selected)
      .then(setLevel)
      .catch((error) => toast.error(error.message));
  }, [selected]);

  async function refresh() {
    try {
      const data = await loadCatalog();
      setCatalog(data.catalog);
      setStatuses(data.statuses);
      const nextExpanded: Record<string, boolean> = {};
      for (const topic of data.catalog.topics) {
        nextExpanded[`topic:${topic.id}`] = true;
        for (const group of topic.groups) nextExpanded[`group:${topic.id}:${group.id}`] = true;
      }
      setExpanded((current) => ({ ...nextExpanded, ...current }));
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "加载关卡失败");
    }
  }

  async function persistCatalog(next: LevelCatalog) {
    try {
      const data = await saveCatalog(next, renames);
      setCatalog(data.catalog);
      setStatuses(data.statuses);
      setRenames([]);
      toast.success("已保存关卡结构");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "保存失败");
    }
  }

  function statusFor(target: SelectedLevel) {
    return statuses.find((item) => item.topicId === target.topicId && item.groupId === target.groupId && item.levelId === target.levelId);
  }

  function selectedNames() {
    const topic = catalog.topics.find((item) => item.id === selected?.topicId);
    const group = selected && selected.kind !== "topic" ? topic?.groups.find((item) => item.id === selected.groupId) : undefined;
    const levelItem = selected?.kind === "level" ? group?.levels.find((item) => item.id === selected.levelId) : undefined;
    return { topic, group, levelItem };
  }

  const names = selectedNames();

  function commitCatalog(next: LevelCatalog | ((current: LevelCatalog) => LevelCatalog)) {
    setCatalog((current) => {
      const value = typeof next === "function" ? next(current) : next;
      setCatalogPast((history) => [...history.slice(-39), current]);
      setCatalogFuture([]);
      return value;
    });
  }

  function commitLevel(next: LevelConfig | ((current: LevelConfig) => LevelConfig)) {
    setLevel((current) => {
      if (!current) return current;
      const value = typeof next === "function" ? next(current) : next;
      setLevelPast((history) => [...history.slice(-39), current]);
      setLevelFuture([]);
      return value;
    });
  }

  function undoCatalog() {
    setCatalogPast((history) => {
      if (!history.length) return history;
      const previous = history[history.length - 1];
      setCatalogFuture((future) => [catalog, ...future].slice(0, 40));
      setCatalog(previous);
      return history.slice(0, -1);
    });
  }

  function redoCatalog() {
    setCatalogFuture((future) => {
      if (!future.length) return future;
      const next = future[0];
      setCatalogPast((history) => [...history.slice(-39), catalog]);
      setCatalog(next);
      return future.slice(1);
    });
  }

  function undoLevel() {
    if (!level) return;
    setLevelPast((history) => {
      if (!history.length) return history;
      const previous = history[history.length - 1];
      setLevelFuture((future) => [level, ...future].slice(0, 40));
      setLevel(previous);
      return history.slice(0, -1);
    });
  }

  function redoLevel() {
    setLevelFuture((future) => {
      if (!future.length) return future;
      const next = future[0];
      setLevelPast((history) => (level ? [...history.slice(-39), level] : history));
      setLevel(next);
      return future.slice(1);
    });
  }

  function updateSelected(next: TreeSelection | null) {
    setSelected(next);
    setLevelPast([]);
    setLevelFuture([]);
  }

  function updateSelectedAfterIdRename(next: SelectedLevel) {
    skipNextLevelLoad.current = true;
    setSelected({ kind: "level", ...next });
    setLevel((current) =>
      current
        ? {
            ...current,
            id: next.levelId,
            topic_id: next.topicId,
            group_id: next.groupId,
            image: {
              ...current.image,
              path: `res://levels/${next.topicId}/${next.groupId}/${next.levelId}/source.jpg`,
            },
          }
        : current,
    );
  }

  function recordRename(operation: CatalogRenameOperation | CatalogRenameOperation[]) {
    setRenames((current) => (Array.isArray(operation) ? mergeRenameOperation(current, operation) : mergeRenameOperation(current, operation)));
  }

  return (
    <main className="h-screen bg-background text-foreground">
      <Toaster />
      <header className="flex h-14 items-center justify-between border-b border-border bg-card px-4">
        <div>
          <div className="text-lg font-semibold">JigCat 关卡编辑器</div>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={() => void persistCatalog(catalog)}>
            <Save size={16} />保存结构
          </Button>
        </div>
      </header>
      <div className="grid h-[calc(100vh-56px)] grid-cols-[340px_1fr] overflow-hidden">
        <aside className="min-h-0 overflow-y-auto border-r border-border bg-card">
          <TreePanel
            catalog={catalog}
            expanded={expanded}
            statuses={statuses}
            selected={selected}
            editMode={editMode}
            onExpanded={setExpanded}
            onSelect={updateSelected}
            onClearSelection={() => setSelected(null)}
            onChange={commitCatalog}
            onEditMode={setEditMode}
            onRename={recordRename}
            onRenameSelection={updateSelectedAfterIdRename}
            onTopicAsset={async (topicId, asset, file) => {
              const result = await uploadTopicAsset(topicId, asset, file);
              commitCatalog((current) => ({
                ...current,
                topics: current.topics.map((topic) => (topic.id === topicId ? { ...topic, [asset]: result.path } : topic)),
              }));
              toast.success(asset === "cover" ? "主题封面已上传" : "主题 icon 已上传");
            }}
          />
        </aside>
        <section className="min-w-0 overflow-hidden">
          {editingPolygon && selected?.kind === "level" && level ? (
            <PolygonEditor
              target={selected}
              title={`${names.topic?.name || names.topic?.id || ""} / ${names.group?.name || names.group?.id || ""} / ${level.title}`}
              level={level}
              onBack={async () => {
                setEditingPolygon(false);
                const fresh = await loadLevel(selected);
                setLevel(fresh);
                await refresh();
              }}
              onSave={async (next) => {
                const saved = await saveLevel(next);
                setLevel(saved);
                toast.success("已保存多边形碎片");
                await refresh();
              }}
            />
          ) : editingKnob && selected?.kind === "level" && level ? (
            <KnobEditor
              target={selected}
              title={`${names.topic?.name || names.topic?.id || ""} / ${names.group?.name || names.group?.id || ""} / ${level.title}`}
              level={level}
              onBack={async () => {
                setEditingKnob(false);
                const fresh = await loadLevel(selected);
                setLevel(fresh);
                await refresh();
              }}
              onSave={async (next) => {
                const saved = await saveLevel(next);
                setLevel(saved);
                toast.success("已保存凹凸 Seed");
                await refresh();
              }}
            />
          ) : selected?.kind === "level" && level ? (
            <LevelDetails
              catalog={catalog}
              target={selected}
              level={level}
              status={statusFor(selected)}
              editMode={editMode}
              onLevel={commitLevel}
              onCatalog={commitCatalog}
              onUndo={undoLevel}
              onRedo={redoLevel}
              canUndo={levelPast.length > 0}
              canRedo={levelFuture.length > 0}
              onUpload={async (file) => {
                try {
                  const saved = await uploadSource(selected, file);
                  setLevel(saved);
                  toast.success("图片已上传");
                  await refresh();
                } catch (error) {
                  toast.error(error instanceof Error ? error.message : "上传失败");
                }
              }}
              onSave={async () => {
                try {
                  const saved = await saveLevel(level);
                  setLevel(saved);
                  toast.success("关卡已保存");
                  await refresh();
                } catch (error) {
                  toast.error(error instanceof Error ? error.message : "保存失败");
                }
              }}
              onEditPolygon={() => setEditingPolygon(true)}
              onEditKnob={() => setEditingKnob(true)}
            />
          ) : selected?.kind === "topic" && names.topic ? (
            <TopicDetails
              topic={names.topic}
              catalog={catalog}
              editMode={editMode}
              onCatalog={commitCatalog}
              onUndo={undoCatalog}
              onRedo={redoCatalog}
              canUndo={catalogPast.length > 0}
              canRedo={catalogFuture.length > 0}
              onUploadAsset={async (asset, file) => {
                const result = await uploadTopicAsset(selected.topicId, asset, file);
                commitCatalog((current) => ({
                  ...current,
                  topics: current.topics.map((topic) => (topic.id === selected.topicId ? { ...topic, [asset]: result.path } : topic)),
                }));
                toast.success(asset === "cover" ? "主题封面已上传" : "主题 icon 已上传");
              }}
            />
          ) : selected?.kind === "group" && names.topic && names.group ? (
            <GroupDetails
              topic={names.topic}
              group={names.group}
              catalog={catalog}
              editMode={editMode}
              onCatalog={commitCatalog}
              onUndo={undoCatalog}
              onRedo={redoCatalog}
              canUndo={catalogPast.length > 0}
              canRedo={catalogFuture.length > 0}
            />
          ) : (
            <div className="grid h-full place-items-center text-muted-foreground">从左侧创建或选择主题、分组或关卡。</div>
          )}
        </section>
      </div>
    </main>
  );
}

function mergeRenameOperation(current: CatalogRenameOperation[], operation: CatalogRenameOperation[]) : CatalogRenameOperation[];
function mergeRenameOperation(current: CatalogRenameOperation[], operation: CatalogRenameOperation): CatalogRenameOperation[];
function mergeRenameOperation(current: CatalogRenameOperation[], operation: CatalogRenameOperation | CatalogRenameOperation[]) {
  const operations = Array.isArray(operation) ? operation : [operation];
  if (Array.isArray(operation)) {
    return mergeRenameBatch(current, operation);
  }
  let next = [...current];
  for (const item of operations) {
    if (item.kind === "topic") {
      next = next.map((rename) => {
        if (rename.kind === "group" || rename.kind === "level") {
          return rename.topicId === item.fromTopicId ? { ...rename, topicId: item.toTopicId } : rename;
        }
        return rename;
      });
      const existing = next.findIndex((rename) => rename.kind === "topic" && rename.toTopicId === item.fromTopicId);
      if (existing >= 0 && next[existing].kind === "topic") {
        next[existing] = { ...next[existing], toTopicId: item.toTopicId };
      } else {
        next.push(item);
      }
    }
    if (item.kind === "group") {
      next = next.map((rename) => {
        if (rename.kind === "level") {
          return rename.topicId === item.topicId && rename.groupId === item.fromGroupId ? { ...rename, groupId: item.toGroupId } : rename;
        }
        return rename;
      });
      const existing = next.findIndex((rename) => rename.kind === "group" && rename.topicId === item.topicId && rename.toGroupId === item.fromGroupId);
      if (existing >= 0 && next[existing].kind === "group") {
        next[existing] = { ...next[existing], toGroupId: item.toGroupId };
      } else {
        next.push(item);
      }
    }
    if (item.kind === "level") {
      const existing = next.findIndex((rename) => rename.kind === "level" && rename.topicId === item.topicId && rename.groupId === item.groupId && rename.toLevelId === item.fromLevelId);
      if (existing >= 0 && next[existing].kind === "level") {
        next[existing] = { ...next[existing], toLevelId: item.toLevelId };
      } else {
        next.push(item);
      }
    }
  }
  return next.filter((rename) => {
    if (rename.kind === "topic") return rename.fromTopicId !== rename.toTopicId;
    if (rename.kind === "group") return rename.fromGroupId !== rename.toGroupId;
    return rename.fromLevelId !== rename.toLevelId;
  });
}

function mergeRenameBatch(current: CatalogRenameOperation[], operations: CatalogRenameOperation[]) {
  if (operations.length === 0) return current;
  let next = [...current];
  const groups = new Map<string, CatalogRenameOperation[]>();
  for (const operation of operations) {
    const key = renameScopeKey(operation);
    groups.set(key, [...(groups.get(key) || []), operation]);
  }
  for (const batch of groups.values()) {
    const fromTo = new Map(batch.map((operation) => [renameFromId(operation), renameToId(operation)]));
    const existingTargetIds = new Set<string>();
    next = next.map((rename) => {
      const currentId = renameToId(rename);
      if (renameScopeKey(rename) !== renameScopeKey(batch[0]) || !fromTo.has(currentId)) return rename;
      existingTargetIds.add(currentId);
      return withRenameToId(rename, fromTo.get(currentId) || currentId);
    });
    for (const operation of batch) {
      if (!existingTargetIds.has(renameFromId(operation))) {
        next.push(operation);
      }
    }
  }
  return next.filter((rename) => renameFromId(rename) !== renameToId(rename));
}

function renameScopeKey(rename: CatalogRenameOperation) {
  if (rename.kind === "topic") return "topic";
  if (rename.kind === "group") return `group:${rename.topicId}`;
  return `level:${rename.topicId}:${rename.groupId}`;
}

function renameFromId(rename: CatalogRenameOperation) {
  if (rename.kind === "topic") return rename.fromTopicId;
  if (rename.kind === "group") return rename.fromGroupId;
  return rename.fromLevelId;
}

function renameToId(rename: CatalogRenameOperation) {
  if (rename.kind === "topic") return rename.toTopicId;
  if (rename.kind === "group") return rename.toGroupId;
  return rename.toLevelId;
}

function withRenameToId(rename: CatalogRenameOperation, id: string): CatalogRenameOperation {
  if (rename.kind === "topic") return { ...rename, toTopicId: id };
  if (rename.kind === "group") return { ...rename, toGroupId: id };
  return { ...rename, toLevelId: id };
}

function TreePanel(props: {
  catalog: LevelCatalog;
  statuses: LevelStatus[];
  expanded: Record<string, boolean>;
  selected: TreeSelection | null;
  editMode: boolean;
  onExpanded: (value: Record<string, boolean>) => void;
  onSelect: (value: TreeSelection) => void;
  onClearSelection: () => void;
  onChange: (value: LevelCatalog | ((current: LevelCatalog) => LevelCatalog)) => void;
  onEditMode: (value: boolean) => void;
  onRename: (operation: CatalogRenameOperation | CatalogRenameOperation[]) => void;
  onRenameSelection: (value: SelectedLevel) => void;
  onTopicAsset: (topicId: string, asset: "cover" | "icon", file: File) => Promise<void>;
}) {
  const { catalog, statuses, expanded, selected, editMode, onExpanded, onSelect, onClearSelection, onChange, onEditMode, onRename, onRenameSelection, onTopicAsset } = props;
  const [deleteTarget, setDeleteTarget] = React.useState<DeleteTarget | null>(null);
  const [draggingId, setDraggingId] = React.useState<string | null>(null);
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  function toggle(key: string) {
    onExpanded({ ...expanded, [key]: !expanded[key] });
  }

  function ordered<T extends { sort_order: number }>(items: T[]) {
    return items.map((item, index) => ({ ...item, sort_order: index }));
  }

  function addTopic() {
    const name = `主题 ${catalog.topics.length + 1}`;
    const id = sequentialId("topic", catalog.topics.map((topic) => topic.id));
    onChange({ ...catalog, topics: [...catalog.topics, { id, name, name_i18n: zhI18n(name), cover: "", color: DEFAULT_TOPIC_COLOR, icon: "", sort_order: catalog.topics.length, groups: [] }] });
    onExpanded({ ...expanded, [`topic:${id}`]: true });
    onSelect({ kind: "topic", topicId: id });
    toast.success("已添加主题");
  }

  function withLevelPaths(topicId: string, groupId: string, level: CatalogLevel): CatalogLevel {
    const base = `res://levels/${topicId}/${groupId === FLAT_GROUP_ID ? "" : `${groupId}/`}${level.id}`;
    return {
      ...level,
      path: `${base}/level.json`,
      source: `${base}/source.jpg`,
    };
  }

  function remapResPath(value: string | undefined, fromPrefix: string, toPrefix: string) {
    if (!value) return "";
    return value.startsWith(fromPrefix) ? value.replace(fromPrefix, toPrefix) : value;
  }

  function fixedOrderId(prefix: string, index: number) {
    return `${prefix}_${String(index + 1).padStart(2, "0")}`;
  }

  function remapExpandedKeys(current: Record<string, boolean>, maps: { topic?: Map<string, string>; group?: { topicId: string; ids: Map<string, string> } }) {
    const next: Record<string, boolean> = {};
    for (const [key, value] of Object.entries(current)) {
      const parts = key.split(":");
      if (parts[0] === "topic" && maps.topic?.has(parts[1])) {
        next[`topic:${maps.topic.get(parts[1])}`] = value;
        continue;
      }
      if (parts[0] === "group") {
        if (maps.topic?.has(parts[1])) {
          next[`group:${maps.topic.get(parts[1])}:${parts[2]}`] = value;
          continue;
        }
        if (maps.group && parts[1] === maps.group.topicId && maps.group.ids.has(parts[2])) {
          next[`group:${parts[1]}:${maps.group.ids.get(parts[2])}`] = value;
          continue;
        }
      }
      next[key] = value;
    }
    return next;
  }

  function renumberTopics(topics: CatalogTopic[]) {
    const topicIdMap = new Map(topics.map((topic, index) => [topic.id, fixedOrderId("topic", index)]));
    const renames: CatalogRenameOperation[] = [];
    const nextTopics = topics.map((topic, index) => {
      const id = topicIdMap.get(topic.id) || topic.id;
      if (id !== topic.id) renames.push({ kind: "topic", fromTopicId: topic.id, toTopicId: id });
      return {
        ...topic,
        id,
        sort_order: index,
        cover: remapResPath(topic.cover, `res://levels/${topic.id}/`, `res://levels/${id}/`),
        icon: remapResPath(topic.icon, `res://levels/${topic.id}/`, `res://levels/${id}/`),
        groups: topic.groups.map((group) => ({
          ...group,
          levels: group.levels.map((level) => withLevelPaths(id, group.id, level)),
        })),
      };
    });
    return { topics: nextTopics, renames, topicIdMap };
  }

  function renumberGroups(topic: CatalogTopic, groups: CatalogGroup[]) {
    const groupIdMap = new Map(groups.map((group, index) => [group.id, fixedOrderId("group", index)]));
    const renames: CatalogRenameOperation[] = [];
    const nextGroups = groups.map((group, index) => {
      const id = groupIdMap.get(group.id) || group.id;
      if (id !== group.id) renames.push({ kind: "group", topicId: topic.id, fromGroupId: group.id, toGroupId: id });
      return {
        ...group,
        id,
        sort_order: index,
        levels: group.levels.map((level) => withLevelPaths(topic.id, id, level)),
      };
    });
    return { groups: nextGroups, renames, groupIdMap };
  }

  function renumberLevels(topic: CatalogTopic, group: CatalogGroup, levels: CatalogLevel[]) {
    const levelIdMap = new Map(levels.map((level, index) => [level.id, fixedOrderId("level", index)]));
    const renames: CatalogRenameOperation[] = [];
    const nextLevels = levels.map((level, index) => {
      const id = levelIdMap.get(level.id) || level.id;
      if (id !== level.id) renames.push({ kind: "level", topicId: topic.id, groupId: group.id, fromLevelId: level.id, toLevelId: id });
      return withLevelPaths(topic.id, group.id, { ...level, id, sort_order: index });
    });
    return { levels: nextLevels, renames, levelIdMap };
  }

  function selectionWithMaps(maps: { topic?: Map<string, string>; group?: Map<string, string>; level?: Map<string, string> }) {
    if (!selected) return null;
    if (selected.kind !== "level") return null;
    return {
      topicId: maps.topic?.get(selected.topicId) || selected.topicId,
      groupId: maps.group?.get(selected.groupId) || selected.groupId,
      levelId: maps.level?.get(selected.levelId) || selected.levelId,
    };
  }

  function applyRenumberedSelection(next: SelectedLevel | null) {
    if (next && selected?.kind === "level" && (next.topicId !== selected.topicId || next.groupId !== selected.groupId || next.levelId !== selected.levelId)) {
      onRenameSelection(next);
    }
  }

  function addGroup(topic: CatalogTopic) {
    const name = `分组 ${topic.groups.length + 1}`;
    const id = sequentialId("group", topic.groups.map((group) => group.id));
    onChange({
      ...catalog,
      topics: catalog.topics.map((item) =>
        item.id === topic.id ? { ...item, groups: [...item.groups, { id, name, name_i18n: zhI18n(name), color: DEFAULT_GROUP_COLOR, sort_order: item.groups.length, levels: [] }] } : item,
      ),
    });
    onExpanded({ ...expanded, [`topic:${topic.id}`]: true, [`group:${topic.id}:${id}`]: true });
    onSelect({ kind: "group", topicId: topic.id, groupId: id });
    toast.success("已添加分组");
  }

  function addLevel(topic: CatalogTopic, group: CatalogGroup) {
    const title = `关卡 ${group.levels.length + 1}`;
    const id = sequentialId("level", group.levels.map((level) => level.id));
    const level: CatalogLevel = {
      id,
      title,
      title_i18n: zhI18n(title),
      sort_order: group.levels.length,
      path: `res://levels/${topic.id}/${group.id}/${id}/level.json`,
      source: `res://levels/${topic.id}/${group.id}/${id}/source.jpg`,
    };
    onChange({
      ...catalog,
      topics: catalog.topics.map((item) =>
        item.id === topic.id
          ? { ...item, groups: item.groups.map((candidate) => (candidate.id === group.id ? { ...candidate, levels: [...candidate.levels, level] } : candidate)) }
          : item,
      ),
    });
    onExpanded({ ...expanded, [`topic:${topic.id}`]: true, [`group:${topic.id}:${group.id}`]: true });
    onSelect({ kind: "level", topicId: topic.id, groupId: group.id, levelId: id });
    toast.success("已添加关卡");
  }

  function renameTopic(topic: CatalogTopic, name: string) {
    onChange({ ...catalog, topics: catalog.topics.map((item) => (item.id === topic.id ? { ...item, name, name_i18n: zhI18n(name) } : item)) });
  }

  function renameGroup(topic: CatalogTopic, group: CatalogGroup, name: string) {
    onChange({
      ...catalog,
      topics: catalog.topics.map((item) => (item.id === topic.id ? { ...item, groups: item.groups.map((candidate) => (candidate.id === group.id ? { ...candidate, name, name_i18n: zhI18n(name) } : candidate)) } : item)),
    });
  }

  function updateTopicColor(topic: CatalogTopic, color: string) {
    onChange({ ...catalog, topics: catalog.topics.map((item) => (item.id === topic.id ? { ...item, color } : item)) });
  }

  function updateTopicAssetPath(topic: CatalogTopic, asset: "cover" | "icon", path: string) {
    onChange({ ...catalog, topics: catalog.topics.map((item) => (item.id === topic.id ? { ...item, [asset]: path } : item)) });
  }

  function updateGroupColor(topic: CatalogTopic, group: CatalogGroup, color: string) {
    onChange({
      ...catalog,
      topics: catalog.topics.map((item) =>
        item.id === topic.id ? { ...item, groups: item.groups.map((candidate) => (candidate.id === group.id ? { ...candidate, color } : candidate)) } : item,
      ),
    });
  }

  function deleteSelected(target: DeleteTarget) {
    if (target.kind === "topic") {
      const result = renumberTopics(catalog.topics.filter((item) => item.id !== target.topic.id));
      onChange({ ...catalog, topics: result.topics });
      onExpanded(remapExpandedKeys(expanded, { topic: result.topicIdMap }));
      onRename(result.renames);
      if (selected?.topicId === target.topic.id) {
        onClearSelection();
      } else {
        applyRenumberedSelection(selectionWithMaps({ topic: result.topicIdMap }));
      }
      return;
    }
    if (target.kind === "group") {
      var deletedGroupSelection: SelectedLevel | null = null;
      var deletedGroupRenames: CatalogRenameOperation[] = [];
      var deletedGroupIdMap = new Map<string, string>();
      onChange({
        ...catalog,
        topics: catalog.topics.map((item) => {
          if (item.id !== target.topic.id) return item;
          const result = renumberGroups(item, item.groups.filter((candidate) => candidate.id !== target.group.id));
          deletedGroupRenames = result.renames;
          deletedGroupIdMap = result.groupIdMap;
          deletedGroupSelection = selectionWithMaps({ group: deletedGroupIdMap });
          return { ...item, groups: result.groups };
        }),
      });
      onExpanded(remapExpandedKeys(expanded, { group: { topicId: target.topic.id, ids: deletedGroupIdMap } }));
      onRename(deletedGroupRenames);
      if (selected?.kind !== "topic" && selected?.topicId === target.topic.id && selected.groupId === target.group.id) {
        onClearSelection();
      } else {
        applyRenumberedSelection(deletedGroupSelection);
      }
      return;
    }
    var deletedLevelSelection: SelectedLevel | null = null;
    var deletedLevelRenames: CatalogRenameOperation[] = [];
    onChange({
      ...catalog,
      topics: catalog.topics.map((item) =>
        item.id === target.topic.id
          ? {
              ...item,
              groups: item.groups.map((candidate) => {
                if (candidate.id !== target.group.id) return candidate;
                const result = renumberLevels(item, candidate, candidate.levels.filter((levelItem) => levelItem.id !== target.level.id));
                deletedLevelRenames = result.renames;
                deletedLevelSelection = selectionWithMaps({ level: result.levelIdMap });
                return { ...candidate, levels: result.levels };
              }),
            }
          : item,
      ),
    });
    onRename(deletedLevelRenames);
    if (selected?.kind === "level" && selected.topicId === target.topic.id && selected.groupId === target.group.id && selected.levelId === target.level.id) {
      onClearSelection();
    } else {
      applyRenumberedSelection(deletedLevelSelection);
    }
  }

  function handleDragStart(event: DragStartEvent) {
    setDraggingId(String(event.active.id));
  }

  function handleDragEnd(event: DragEndEvent) {
    setDraggingId(null);
    if (!editMode || !event.over || event.active.id === event.over.id) return;
    const active = String(event.active.id).split(":");
    const over = String(event.over.id).split(":");
    if (active[0] !== over[0]) return;

    if (active[0] === "topic") {
      const oldIndex = catalog.topics.findIndex((topic) => topic.id === active[1]);
      const newIndex = catalog.topics.findIndex((topic) => topic.id === over[1]);
      if (oldIndex < 0 || newIndex < 0) return;
      const result = renumberTopics(arrayMove(catalog.topics, oldIndex, newIndex));
      onChange({ ...catalog, topics: result.topics });
      onExpanded(remapExpandedKeys(expanded, { topic: result.topicIdMap }));
      onRename(result.renames);
      applyRenumberedSelection(selectionWithMaps({ topic: result.topicIdMap }));
      return;
    }

    if (active[0] === "group") {
      const [, topicId, groupId] = active;
      const [, overTopicId, overGroupId] = over;
      if (topicId !== overTopicId) return;
      var groupSelection: SelectedLevel | null = null;
      var groupRenames: CatalogRenameOperation[] = [];
      var groupIdMap = new Map<string, string>();
      onChange({
        ...catalog,
        topics: catalog.topics.map((topic) => {
          if (topic.id !== topicId) return topic;
          const oldIndex = topic.groups.findIndex((group) => group.id === groupId);
          const newIndex = topic.groups.findIndex((group) => group.id === overGroupId);
          if (oldIndex < 0 || newIndex < 0) return topic;
          const result = renumberGroups(topic, arrayMove(topic.groups, oldIndex, newIndex));
          groupRenames = result.renames;
          groupIdMap = result.groupIdMap;
          groupSelection = selectionWithMaps({ group: groupIdMap });
          return { ...topic, groups: result.groups };
        }),
      });
      onExpanded(remapExpandedKeys(expanded, { group: { topicId, ids: groupIdMap } }));
      onRename(groupRenames);
      applyRenumberedSelection(groupSelection);
      return;
    }

    if (active[0] === "level") {
      const [, topicId, groupId, levelId] = active;
      const [, overTopicId, overGroupId, overLevelId] = over;
      if (topicId !== overTopicId || groupId !== overGroupId) return;
      var levelSelection: SelectedLevel | null = null;
      var levelRenames: CatalogRenameOperation[] = [];
      onChange({
        ...catalog,
        topics: catalog.topics.map((topic) =>
          topic.id === topicId
            ? {
                ...topic,
                groups: topic.groups.map((group) => {
                  if (group.id !== groupId) return group;
                  const oldIndex = group.levels.findIndex((level) => level.id === levelId);
                  const newIndex = group.levels.findIndex((level) => level.id === overLevelId);
                  if (oldIndex < 0 || newIndex < 0) return group;
                  const result = renumberLevels(topic, group, arrayMove(group.levels, oldIndex, newIndex));
                  levelRenames = result.renames;
                  levelSelection = selectionWithMaps({ level: result.levelIdMap });
                  return { ...group, levels: result.levels };
                }),
              }
            : topic,
        ),
      });
      onRename(levelRenames);
      applyRenumberedSelection(levelSelection);
    }
  }

  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-border px-3 py-2">
        <div className="mb-2 flex rounded-md border border-input bg-background p-1">
          <Button className="flex-1" size="sm" variant={!editMode ? "default" : "ghost"} onClick={() => onEditMode(false)}>
            <Eye size={14} />浏览
          </Button>
          <Button className="flex-1" size="sm" variant={editMode ? "default" : "ghost"} onClick={() => onEditMode(true)}>
            <Pencil size={14} />编辑
          </Button>
        </div>
        <div className="flex items-center justify-between">
          <span className="font-medium">关卡树</span>
        {editMode && (
          <Button size="icon" variant="ghost" onClick={addTopic} title="新增主题">
            <FolderPlus size={16} />
          </Button>
        )}
        </div>
      </div>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragStart={handleDragStart} onDragCancel={() => setDraggingId(null)} onDragEnd={handleDragEnd}>
        <div className="flex-1 space-y-1 overflow-auto p-2 text-sm">
          <SortableContext items={catalog.topics.map((topic) => `topic:${topic.id}`)} strategy={verticalListSortingStrategy}>
            {catalog.topics.map((topic) => {
              const topicKey = `topic:${topic.id}`;
              return (
                <div key={topic.id} className="space-y-1">
                  <SortableTreeRow id={`topic:${topic.id}`} editMode={editMode}>
                    {({ handleProps }) => (
                      <TreeRow
                        depth={0}
                        editMode={editMode}
                        isDraggingTree={draggingId !== null}
                        expanded={expanded[topicKey]}
                        name={topic.name || topic.id}
                        color={topic.color}
                        cover={topic.cover}
                        icon={topic.icon}
                        strong
                        handleProps={handleProps}
                        onSelect={() => onSelect({ kind: "topic", topicId: topic.id })}
                        onToggle={() => toggle(topicKey)}
                        onName={(name) => renameTopic(topic, name)}
                        onColor={(color) => updateTopicColor(topic, color)}
                        onCoverPath={(path) => updateTopicAssetPath(topic, "cover", path)}
                        onIconPath={(path) => updateTopicAssetPath(topic, "icon", path)}
                        onCoverUpload={async (file) => {
                          try {
                            await onTopicAsset(topic.id, "cover", file);
                          } catch (error) {
                            toast.error(error instanceof Error ? error.message : "上传失败");
                          }
                        }}
                        onIconUpload={async (file) => {
                          try {
                            await onTopicAsset(topic.id, "icon", file);
                          } catch (error) {
                            toast.error(error instanceof Error ? error.message : "上传失败");
                          }
                        }}
                        onAdd={() => addGroup(topic)}
                        onDelete={() => setDeleteTarget({ kind: "topic", topic })}
                        addTitle="新增分组"
                      />
                    )}
                  </SortableTreeRow>
                  {expanded[topicKey] && (
                    <SortableContext items={topic.groups.map((group) => `group:${topic.id}:${group.id}`)} strategy={verticalListSortingStrategy}>
                      {topic.groups.map((group) => {
                        const groupKey = `group:${topic.id}:${group.id}`;
                        return (
                          <div key={group.id} className="space-y-1">
                            <SortableTreeRow id={`group:${topic.id}:${group.id}`} editMode={editMode}>
                              {({ handleProps }) => (
                                <TreeRow
                                  depth={1}
                                  editMode={editMode}
                                  isDraggingTree={draggingId !== null}
                                  expanded={expanded[groupKey]}
                                  name={group.name || group.id}
                                  color={group.color}
                                  handleProps={handleProps}
                                  onSelect={() => onSelect({ kind: "group", topicId: topic.id, groupId: group.id })}
                                  onToggle={() => toggle(groupKey)}
                                  onName={(name) => renameGroup(topic, group, name)}
                                  onColor={(color) => updateGroupColor(topic, group, color)}
                                  onAdd={() => addLevel(topic, group)}
                                  onDelete={() => setDeleteTarget({ kind: "group", topic, group })}
                                  addTitle="新增关卡"
                                />
                              )}
                            </SortableTreeRow>
                            {expanded[groupKey] && (
                              <SortableContext items={group.levels.map((level) => `level:${topic.id}:${group.id}:${level.id}`)} strategy={verticalListSortingStrategy}>
                                {group.levels.map((level) => {
                                  const target = { topicId: topic.id, groupId: group.id, levelId: level.id };
                                  const status = statuses.find((item) => item.topicId === topic.id && item.groupId === group.id && item.levelId === level.id);
                                  const active = selected?.kind === "level" && selected.topicId === topic.id && selected.groupId === group.id && selected.levelId === level.id;
                                  return (
                                    <SortableLevelRow key={level.id} id={`level:${topic.id}:${group.id}:${level.id}`} editMode={editMode}>
                                      {({ handleProps }) => (
                                        <LevelTreeRow
                                          active={active}
                                          editMode={editMode}
                                          level={level}
                                          status={status}
                                          isDraggingTree={draggingId !== null}
                                          handleProps={handleProps}
                                          onSelect={() => onSelect({ kind: "level", ...target })}
                                          onDelete={() => setDeleteTarget({ kind: "level", topic, group, level })}
                                        />
                                      )}
                                    </SortableLevelRow>
                                  );
                                })}
                              </SortableContext>
                            )}
                          </div>
                        );
                      })}
                    </SortableContext>
                  )}
                </div>
              );
            })}
          </SortableContext>
        </div>
      </DndContext>
      <AlertDialog open={deleteTarget !== null} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>确认删除</AlertDialogTitle>
            <AlertDialogDescription>
              {deleteTarget ? deleteMessage(deleteTarget) : "删除后需要保存结构才会写入文件。"}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (deleteTarget) {
                  deleteSelected(deleteTarget);
                  toast.success("已删除，记得保存结构");
                }
                setDeleteTarget(null);
              }}
            >
              删除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function deleteMessage(target: DeleteTarget) {
  if (target.kind === "topic") return `删除主题「${target.topic.name || target.topic.id}」？主题下的分组和关卡也会从结构中移除。`;
  if (target.kind === "group") return `删除分组「${target.group.name || target.group.id}」？该分组下的关卡也会从结构中移除。`;
  return `删除关卡「${target.level.title || target.level.id}」？`;
}

function SortableTreeRow(props: {
  id: string;
  editMode: boolean;
  children: (value: { handleProps: Record<string, unknown> }) => React.ReactNode;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: props.id, disabled: !props.editMode });
  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={cn(isDragging && "relative z-10 opacity-70")}
    >
      {props.children({ handleProps: props.editMode ? { ...attributes, ...listeners } : {} })}
    </div>
  );
}

function SortableLevelRow(props: {
  id: string;
  editMode: boolean;
  children: (value: { handleProps: Record<string, unknown> }) => React.ReactNode;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: props.id, disabled: !props.editMode });
  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={cn(isDragging && "relative z-10 opacity-70")}
    >
      {props.children({ handleProps: props.editMode ? { ...attributes, ...listeners } : {} })}
    </div>
  );
}

function ColorField(props: {
  value: string;
  fallback: string;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  const normalized = HEX_COLOR_RE.test(props.value) ? props.value.toUpperCase() : props.fallback;
  const [draft, setDraft] = React.useState(normalized);
  const [open, setOpen] = React.useState(false);

  React.useEffect(() => {
    setDraft(normalized);
  }, [normalized]);

  function commit(value: string) {
    if (props.disabled) return;
    const next = value.trim();
    const withPrefix = next.startsWith("#") ? next : `#${next}`;
    if (HEX_COLOR_RE.test(withPrefix)) {
      const normalizedNext = withPrefix.toUpperCase();
      setDraft(normalizedNext);
      props.onChange(normalizedNext);
      return;
    }
    setDraft(normalized);
  }

  return (
    <span className="relative inline-flex items-center gap-1.5">
      <button
        className={cn("h-7 w-8 rounded-md border border-input shadow-sm", props.disabled && "cursor-not-allowed opacity-70")}
        style={{ backgroundColor: normalized }}
        type="button"
        aria-label="选择颜色"
        disabled={props.disabled}
        onClick={() => !props.disabled && setOpen((value) => !value)}
      />
      <Input
        className="h-7 w-24 font-mono text-[11px]"
        value={draft}
        disabled={props.disabled}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={() => commit(draft)}
        onKeyDown={(event) => {
          if (event.key === "Enter") event.currentTarget.blur();
          if (event.key === "Escape") {
            setDraft(normalized);
            event.currentTarget.blur();
          }
        }}
      />
      {open && (
        <div className="absolute left-0 top-9 z-50 rounded-lg border bg-popover p-3 shadow-lg">
          <HexColorPicker
            color={normalized}
            onChange={(value) => {
              const next = value.toUpperCase();
              setDraft(next);
              props.onChange(next);
            }}
          />
          <div className="mt-2 flex justify-end">
            <Button size="sm" variant="outline" type="button" onClick={() => setOpen(false)}>
              完成
            </Button>
          </div>
        </div>
      )}
    </span>
  );
}

function TreeRow(props: {
  depth: number;
  name: string;
  color?: string;
  cover?: string;
  icon?: string;
  expanded: boolean;
  editMode: boolean;
  isDraggingTree: boolean;
  strong?: boolean;
  handleProps: Record<string, unknown>;
  addTitle: string;
  onSelect: () => void;
  onToggle: () => void;
  onName: (name: string) => void;
  onColor?: (color: string) => void;
  onCoverPath?: (path: string) => void;
  onIconPath?: (path: string) => void;
  onCoverUpload?: (file: File) => Promise<void>;
  onIconUpload?: (file: File) => Promise<void>;
  onAdd: () => void;
  onDelete: () => void;
}) {
  const indent = props.depth * 20;
  if (props.editMode) {
    return (
      <div
        className={cn("min-h-10 rounded-md px-1 py-1.5", !props.isDraggingTree && "hover:bg-accent")}
        style={{ paddingLeft: `${indent + 4}px` }}
      >
        <div className="flex min-w-0 items-center gap-1">
          <button className="grid h-7 w-6 shrink-0 cursor-grab place-items-center text-muted-foreground active:cursor-grabbing" {...props.handleProps} title="拖拽排序">
            <GripVertical size={15} />
          </button>
          <button className="grid h-7 w-7 shrink-0 place-items-center text-muted-foreground" onClick={props.onToggle}>
            {props.expanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
          </button>
          <TreeMarker color={props.color} icon={props.strong ? props.icon : undefined} strong={props.strong} />
          <button className={cn("h-8 min-w-0 flex-1 truncate px-2 text-left", props.strong && "font-medium")} onClick={props.onSelect}>
            {props.name}
          </button>
          <Button size="icon" variant="ghost" className="h-7 w-7 shrink-0" onClick={props.onAdd} title={props.addTitle}>
            <Plus size={14} />
          </Button>
          <Button size="icon" variant="ghost" className="h-7 w-7 shrink-0 text-destructive hover:text-destructive" onClick={props.onDelete} title="删除">
            <Trash2 size={14} />
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className={cn("flex min-h-10 items-center gap-1 rounded-md px-1", !props.isDraggingTree && "hover:bg-accent")} style={{ paddingLeft: `${indent + 4}px` }}>
      <button className="grid h-7 w-7 place-items-center text-muted-foreground" onClick={props.onToggle}>
        {props.expanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
      </button>
      <TreeMarker color={props.color} icon={props.strong ? props.icon : undefined} strong={props.strong} />
      <button className={cn("min-w-0 flex-1 truncate px-2 text-left", props.strong && "font-medium")} onClick={props.onSelect}>
        {props.name}
      </button>
    </div>
  );
}

function TreeMarker(props: { color?: string; icon?: string; strong?: boolean }) {
  const color = props.color || (props.strong ? DEFAULT_TOPIC_COLOR : DEFAULT_GROUP_COLOR);
  return (
    <span
      className={cn(
        "grid h-6 w-6 shrink-0 place-items-center border border-border/70",
        props.strong ? "rounded-md" : "rounded-sm",
      )}
      style={{ backgroundColor: color }}
    >
      {props.icon && <img className="h-4 w-4 object-contain" src={assetUrl(props.icon)} alt="" />}
    </span>
  );
}

function AssetUploadButton(props: {
  title: string;
  accept: string;
  active: boolean;
  children: React.ReactNode;
  onUpload: (file: File) => Promise<void>;
}) {
  return (
    <label
      className={cn(
        "grid h-7 w-7 shrink-0 cursor-pointer place-items-center rounded-md text-muted-foreground hover:bg-accent hover:text-accent-foreground",
        props.active && "text-success",
      )}
      title={props.title}
    >
      {props.children}
      <input
        className="hidden"
        type="file"
        accept={props.accept}
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.currentTarget.value = "";
          if (file) void props.onUpload(file);
        }}
      />
    </label>
  );
}

function LevelTreeRow(props: {
  active: boolean;
  editMode: boolean;
  level: CatalogLevel;
  status?: LevelStatus;
  isDraggingTree: boolean;
  handleProps: Record<string, unknown>;
  onSelect: () => void;
  onDelete: () => void;
}) {
  return (
    <div className={cn("flex h-9 items-center gap-2 rounded-md px-2 text-muted-foreground", !props.isDraggingTree && "hover:bg-accent hover:text-foreground", props.active && "bg-accent text-foreground")} style={{ paddingLeft: "58px" }}>
      {props.editMode && (
        <button className="grid h-7 w-5 cursor-grab place-items-center text-muted-foreground active:cursor-grabbing" {...props.handleProps} title="拖拽排序">
          <GripVertical size={14} />
        </button>
      )}
      {!props.editMode && <span className="h-7 w-5 shrink-0" />}
      <span className="grid shrink-0 gap-0.5">
        <span className="grid h-6 w-6 place-items-center rounded-full bg-secondary">
          <Gamepad2 className="h-3.5 w-3.5 text-primary" />
        </span>
        <span className="h-0.5 w-6 rounded-full" style={{ backgroundColor: props.level.background_color || DEFAULT_GROUP_COLOR }} />
      </span>
      <button className="min-w-0 flex-1 truncate text-left" onClick={props.onSelect}>{props.level.title || props.level.id}</button>
      {props.status?.hasSource && <ImageUp className="h-4 w-4 shrink-0 text-success" aria-label="已有原图" />}
      {props.status?.hasPolygon && <Hexagon className="h-4 w-4 shrink-0 text-success" aria-label="已有多边形" />}
      {props.editMode && (
        <Button size="icon" variant="ghost" className="h-7 w-7 text-destructive hover:text-destructive" onClick={props.onDelete} title="删除">
          <Trash2 size={13} />
        </Button>
      )}
    </div>
  );
}

function EditorActions(props: { editMode: boolean; canUndo: boolean; canRedo: boolean; onUndo: () => void; onRedo: () => void; onSave?: () => void }) {
  if (!props.editMode) return null;
  return (
    <div className="flex items-center gap-2">
      <Button variant="outline" disabled={!props.canUndo} onClick={props.onUndo}>
        <Undo2 size={16} />撤销
      </Button>
      <Button variant="outline" disabled={!props.canRedo} onClick={props.onRedo}>
        <Redo2 size={16} />重做
      </Button>
      {props.onSave && (
        <Button onClick={props.onSave}>
          <Save size={16} />保存
        </Button>
      )}
    </div>
  );
}

function TopicDetails(props: {
  topic: CatalogTopic;
  catalog: LevelCatalog;
  editMode: boolean;
  onCatalog: (catalog: LevelCatalog | ((current: LevelCatalog) => LevelCatalog)) => void;
  onUndo: () => void;
  onRedo: () => void;
  canUndo: boolean;
  canRedo: boolean;
  onUploadAsset: (asset: "cover" | "icon", file: File) => Promise<void>;
}) {
  function updateTopic(partial: Partial<CatalogTopic>) {
    props.onCatalog((catalog) => ({
      ...catalog,
      topics: catalog.topics.map((topic) => (topic.id === props.topic.id ? { ...topic, ...partial } : topic)),
    }));
  }

  return (
    <div className="h-full overflow-auto p-6">
      <div className="mb-5 flex items-center justify-between border-b border-border pb-3">
        <div>
          <h1 className="text-2xl font-semibold">主题</h1>
          <p className="text-sm text-muted-foreground">{props.editMode ? "编辑主题名称、颜色、封面和 icon。" : "主题预览"}</p>
        </div>
        <EditorActions editMode={props.editMode} canUndo={props.canUndo} canRedo={props.canRedo} onUndo={props.onUndo} onRedo={props.onRedo} />
      </div>
      <div className="grid grid-cols-[1fr_320px] gap-8">
        <div className="space-y-4">
          <label className="block text-sm font-medium">
            主题名称
            <Input className="mt-1" value={props.topic.name || ""} disabled={!props.editMode} onChange={(event) => updateTopic({ name: event.target.value, name_i18n: zhI18n(event.target.value) })} />
          </label>
          <label className="block text-sm font-medium">
            主题色
            <div className="mt-1">
              <ColorField value={props.topic.color || DEFAULT_TOPIC_COLOR} fallback={DEFAULT_TOPIC_COLOR} onChange={(color) => updateTopic({ color })} />
            </div>
          </label>
        </div>
        <div className="space-y-4">
          <AssetPreview title="主题封面" path={props.topic.cover} />
          {props.editMode && (
            <AssetUploadButton title="上传主题封面" accept="image/jpeg,image/png,image/webp" active={Boolean(props.topic.cover)} onUpload={(file) => props.onUploadAsset("cover", file)}>
              <ImageUp size={16} />
            </AssetUploadButton>
          )}
          <AssetPreview title="主题 Icon" path={props.topic.icon} small />
          {props.editMode && (
            <AssetUploadButton title="上传主题 icon" accept="image/svg+xml,image/png" active={Boolean(props.topic.icon)} onUpload={(file) => props.onUploadAsset("icon", file)}>
              <Sparkles size={16} />
            </AssetUploadButton>
          )}
        </div>
      </div>
    </div>
  );
}

function GroupDetails(props: {
  topic: CatalogTopic;
  group: CatalogGroup;
  catalog: LevelCatalog;
  editMode: boolean;
  onCatalog: (catalog: LevelCatalog | ((current: LevelCatalog) => LevelCatalog)) => void;
  onUndo: () => void;
  onRedo: () => void;
  canUndo: boolean;
  canRedo: boolean;
}) {
  function updateGroup(partial: Partial<CatalogGroup>) {
    props.onCatalog((catalog) => ({
      ...catalog,
      topics: catalog.topics.map((topic) =>
        topic.id === props.topic.id
          ? { ...topic, groups: topic.groups.map((group) => (group.id === props.group.id ? { ...group, ...partial } : group)) }
          : topic,
      ),
    }));
  }

  return (
    <div className="h-full overflow-auto p-6">
      <div className="mb-5 flex items-center justify-between border-b border-border pb-3">
        <div>
          <h1 className="text-2xl font-semibold">分组</h1>
          <p className="text-sm text-muted-foreground">{props.topic.name || props.topic.id}</p>
        </div>
        <EditorActions editMode={props.editMode} canUndo={props.canUndo} canRedo={props.canRedo} onUndo={props.onUndo} onRedo={props.onRedo} />
      </div>
      <div className="max-w-xl space-y-4">
        <label className="block text-sm font-medium">
          分组名称
          <Input className="mt-1" value={props.group.name || ""} disabled={!props.editMode} onChange={(event) => updateGroup({ name: event.target.value, name_i18n: zhI18n(event.target.value) })} />
        </label>
        <label className="block text-sm font-medium">
          分组色
          <div className="mt-1">
            <ColorField value={props.group.color || DEFAULT_GROUP_COLOR} fallback={DEFAULT_GROUP_COLOR} onChange={(color) => updateGroup({ color })} />
          </div>
        </label>
      </div>
    </div>
  );
}

function AssetPreview(props: { title: string; path?: string; small?: boolean }) {
  return (
    <div>
      <div className="mb-2 text-sm font-medium text-foreground">{props.title}</div>
      <div className={cn("imageBox", props.small ? "h-24" : "h-40")}>
        {props.path ? <img src={assetUrl(props.path)} alt={props.title} /> : <span>未设置</span>}
      </div>
    </div>
  );
}

function CoverCropDialog(props: {
  open: boolean;
  imageUrl: string;
  title: string;
  onOpenChange: (open: boolean) => void;
  onSave: (file: File) => Promise<void>;
}) {
  const [crop, setCrop] = React.useState({ x: 0, y: 0 });
  const [zoom, setZoom] = React.useState(1);
  const [area, setArea] = React.useState<Area | null>(null);
  const [saving, setSaving] = React.useState(false);

  React.useEffect(() => {
    if (props.open) {
      setCrop({ x: 0, y: 0 });
      setZoom(1);
      setArea(null);
    }
  }, [props.open]);

  async function save() {
    if (!area) return;
    setSaving(true);
    try {
      const blob = await cropImageToJpeg(props.imageUrl, area, 200);
      await props.onSave(new File([blob], "cover.jpg", { type: "image/jpeg" }));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog open={props.open} onOpenChange={props.onOpenChange}>
      <DialogContent className="max-w-3xl">
        <DialogHeader>
          <DialogTitle>制作封面</DialogTitle>
          <DialogDescription>{props.title}，固定输出 200 x 200。拖拽图片调整位置，滚轮或滑块缩放，方向键每次移动 1px。</DialogDescription>
        </DialogHeader>
        <div
          className="relative h-[460px] overflow-hidden rounded-lg bg-black"
          tabIndex={0}
          onKeyDown={(event) => {
            if (event.key === "ArrowLeft") setCrop((value) => ({ ...value, x: value.x - 1 }));
            if (event.key === "ArrowRight") setCrop((value) => ({ ...value, x: value.x + 1 }));
            if (event.key === "ArrowUp") setCrop((value) => ({ ...value, y: value.y - 1 }));
            if (event.key === "ArrowDown") setCrop((value) => ({ ...value, y: value.y + 1 }));
          }}
        >
          <Cropper
            image={props.imageUrl}
            crop={crop}
            zoom={zoom}
            aspect={1}
            cropSize={{ width: 200, height: 200 }}
            onCropChange={setCrop}
            onZoomChange={setZoom}
            onCropComplete={(_, croppedAreaPixels) => setArea(croppedAreaPixels)}
            showGrid={false}
          />
        </div>
        <div className="flex items-center gap-3">
          <span className="text-sm text-muted-foreground">缩放</span>
          <input className="w-full" type="range" min={1} max={4} step={0.01} value={zoom} onChange={(event) => setZoom(Number(event.target.value))} />
          <span className="w-12 text-right text-sm tabular-nums">{zoom.toFixed(2)}x</span>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => props.onOpenChange(false)}>取消</Button>
          <Button disabled={!area || saving} onClick={() => void save()}>{saving ? "保存中..." : "保存封面"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

async function cropImageToJpeg(imageUrl: string, area: Area, size: number) {
  const image = await loadImage(imageUrl);
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("无法创建裁剪画布。");
  context.drawImage(image, area.x, area.y, area.width, area.height, 0, 0, size, size);
  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("封面导出失败。"))), "image/jpeg", 0.88);
  });
}

function loadImage(src: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image();
    image.crossOrigin = "anonymous";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("图片加载失败。"));
    image.src = src;
  });
}

function LevelDetails(props: {
  catalog: LevelCatalog;
  target: SelectedLevel;
  level: LevelConfig;
  status?: LevelStatus;
  editMode: boolean;
  onLevel: (level: LevelConfig | ((current: LevelConfig) => LevelConfig)) => void;
  onCatalog: (catalog: LevelCatalog | ((current: LevelCatalog) => LevelCatalog)) => void;
  onUndo: () => void;
  onRedo: () => void;
  canUndo: boolean;
  canRedo: boolean;
  onUpload: (file: File) => Promise<void>;
  onSave: () => Promise<void>;
  onEditPolygon: () => void;
  onEditKnob: () => void;
}) {
  const { catalog, target, level, status, editMode, onLevel, onCatalog, onUpload, onSave, onEditPolygon, onEditKnob } = props;
  const sourceInputRef = React.useRef<HTMLInputElement | null>(null);
  const sourceImageUrl = React.useMemo(() => sourceUrl(target), [target.topicId, target.groupId, target.levelId, status?.hasSource, level.image.width, level.image.height]);

  function updateTitle(title: string) {
    onLevel({ ...level, title, title_i18n: zhI18n(title) });
    onCatalog({
      ...catalog,
      topics: catalog.topics.map((topic) =>
        topic.id === target.topicId
          ? {
              ...topic,
              groups: topic.groups.map((group) =>
                group.id === target.groupId
                  ? { ...group, levels: group.levels.map((item) => (item.id === target.levelId ? { ...item, title, title_i18n: zhI18n(title) } : item)) }
                  : group,
              ),
            }
          : topic,
      ),
    });
  }

  return (
    <div className="h-full overflow-auto p-6">
      <div className="mb-5 flex items-center justify-between border-b border-border pb-3">
        <div>
          <h1 className="text-2xl font-semibold">关卡详情</h1>
          <p className="text-sm text-muted-foreground">这里只管理关卡基础信息和 polygon 数据。</p>
        </div>
        <div className="flex items-center gap-3">
          {editMode && (
            <>
            <Button variant="outline" disabled={!props.canUndo} onClick={props.onUndo}>
              <Undo2 size={16} />撤销
            </Button>
            <Button variant="outline" disabled={!props.canRedo} onClick={props.onRedo}>
              <Redo2 size={16} />重做
            </Button>
            <Button onClick={() => void onSave()}>
              <Save size={16} />保存关卡
            </Button>
            </>
          )}
        </div>
      </div>
      <div className="grid grid-cols-[1fr_320px] gap-8">
        <div className="space-y-4">
          <label className="block text-sm font-medium text-foreground">
            中文标题
            <Input className="mt-1" value={level.title} disabled={!editMode} onChange={(event) => updateTitle(event.target.value)} />
          </label>
          <label className="block text-sm font-medium text-foreground">
            桌布背景色
            <div className="mt-1">
              <ColorField
                value={level.background.color}
                fallback="#F6EBD4"
                disabled={!editMode}
                onChange={(color) => {
                  if (!editMode) return;
                  onLevel({ ...level, background: { type: "color", color } });
                  onCatalog((catalog) => ({
                    ...catalog,
                    topics: catalog.topics.map((topic) =>
                      topic.id === target.topicId
                        ? {
                            ...topic,
                            groups: topic.groups.map((group) =>
                              group.id === target.groupId
                                ? {
                                    ...group,
                                    levels: group.levels.map((item) => (item.id === target.levelId ? { ...item, background_color: color } : item)),
                                  }
                                : group,
                            ),
                          }
                        : topic,
                    ),
                  }));
                }}
              />
            </div>
          </label>
          <div className="border-y border-border py-3">
            <div className="mb-2 text-sm font-semibold text-foreground">模式数据</div>
            <ModeDataLine
              label="Polygon"
              value={`${status?.hasPolygon ? `已有 ${status.pieceCount} 块` : "未生成"} · ${seedSummary(level.modes.polygon?.assist, DEFAULT_POLYGON_SEED_COUNT)}`}
              actionLabel="编辑多边形"
              disabled={!status?.hasSource}
              onAction={onEditPolygon}
            />
            <ModeDataLine
              label="凹凸"
              value={`Godot 自动生成 ${DEFAULT_KNOB_COLS} x ${DEFAULT_KNOB_ROWS} · ${seedSummary(level.modes.knob?.assist, DEFAULT_KNOB_SEED_COUNT)}`}
              actionLabel="编辑凹凸"
              disabled={!status?.hasSource}
              onAction={onEditKnob}
            />
            <StatusLine label="Swap" value={`Godot 自动生成 ${DEFAULT_SWAP_COLS} x ${DEFAULT_SWAP_ROWS}`} />
          </div>
        </div>
        <div className="space-y-4">
          <button
            className={cn("imageBox w-full text-left", editMode && "cursor-pointer hover:ring-2 hover:ring-primary/40")}
            onClick={() => editMode && sourceInputRef.current?.click()}
            type="button"
          >
            {status?.hasSource ? <img src={sourceImageUrl} alt={level.title} /> : <span>未上传 source.jpg</span>}
          </button>
          {editMode && (
            <input
              ref={sourceInputRef}
              className="hidden"
              type="file"
              accept="image/jpeg"
              onChange={(event) => {
                const file = event.target.files?.[0];
                event.currentTarget.value = "";
                if (file) void onUpload(file);
              }}
            />
          )}
        </div>
      </div>
    </div>
  );
}

function StatusLine(props: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between border-b border-border/60 py-2 text-sm">
      <span>{props.label}</span>
      <span>{props.value}</span>
    </div>
  );
}

function seedSummary(assist: SeedAssist | undefined, defaultCount: number) {
  const normalized = normalizeAssist(assist, defaultCount);
  if (normalized.seed.mode === "manual") return `手动 ${normalized.seed.piece_ids.length} 块`;
  return `自动 ${normalized.seed.count || defaultCount} 块`;
}

function ModeDataLine(props: { label: string; value: string; actionLabel: string; disabled?: boolean; onAction: () => void }) {
  return (
    <div className="grid grid-cols-[92px_1fr_auto] items-center gap-3 border-b border-border/60 py-2 text-sm">
      <span>{props.label}</span>
      <span className="text-muted-foreground">{props.value}</span>
      <Button size="sm" variant="outline" disabled={props.disabled} onClick={props.onAction}>
        <Edit3 size={14} />{props.actionLabel}
      </Button>
    </div>
  );
}

function SeedSettingsPanel(props: {
  title: string;
  description?: string;
  assist: SeedAssist;
  defaultCount: number;
  disabled?: boolean;
  onChange: (assist: SeedAssist) => void;
  children?: (assist: SeedAssist, setAssist: (assist: SeedAssist) => void) => React.ReactNode;
}) {
  const { title, description, assist, defaultCount, disabled, onChange, children } = props;
  const setAssist = React.useCallback((next: SeedAssist) => onChange(normalizeAssist(next, defaultCount)), [defaultCount, onChange]);

  return (
    <div className="rounded-md border border-border bg-background p-3">
      <div className="mb-1 text-sm font-semibold text-foreground">{title}</div>
      {description ? <p className="mb-3 text-xs leading-5 text-muted-foreground">{description}</p> : null}
      <div className="mb-3 grid grid-cols-2 gap-2">
        <Button
          type="button"
          variant={assist.seed.mode === "auto" ? "default" : "outline"}
          disabled={disabled}
          onClick={() => setAssist({ ...assist, seed: { mode: "auto", count: assist.seed.count || defaultCount, piece_ids: [] } })}
        >
          自动
        </Button>
        <Button
          type="button"
          variant={assist.seed.mode === "manual" ? "default" : "outline"}
          disabled={disabled}
          onClick={() => setAssist({ ...assist, seed: { ...assist.seed, mode: "manual" } })}
        >
          手动
        </Button>
      </div>
      {assist.seed.mode === "auto" ? (
        <label className="block text-xs font-medium text-foreground">
          种子数量
          <Input
            className="mt-1 h-8"
            type="number"
            min={0}
            max={99}
            disabled={disabled}
            value={assist.seed.count}
            onChange={(event) => setAssist({ ...assist, seed: { ...assist.seed, count: Number(event.target.value), piece_ids: [] } })}
          />
        </label>
      ) : (
        <>
          {children?.(assist, setAssist)}
          <div className="mt-2 text-xs text-muted-foreground">已选 {assist.seed.piece_ids.length} 块</div>
        </>
      )}
    </div>
  );
}

function KnobSeedGrid(props: {
  cols: number;
  rows: number;
  selectedIds: string[];
  disabled?: boolean;
  onToggle: (id: string) => void;
}) {
  const cells = React.useMemo(() => {
    const items: Array<{ id: string; row: number; col: number }> = [];
    for (let row = 0; row < props.rows; row += 1) {
      for (let col = 0; col < props.cols; col += 1) items.push({ id: `knob_${row}_${col}`, row, col });
    }
    return items;
  }, [props.cols, props.rows]);
  return (
    <div className="rounded-sm border border-border bg-card p-2">
      <div className="grid gap-1" style={{ gridTemplateColumns: `repeat(${props.cols}, minmax(0, 1fr))` }}>
        {cells.map((cell) => {
          const selected = props.selectedIds.includes(cell.id);
          return (
            <button
              key={cell.id}
              type="button"
              disabled={props.disabled}
              className={cn(
                "aspect-square rounded-sm border text-[10px] transition-colors",
                selected ? "border-primary bg-primary text-primary-foreground" : "border-border bg-background text-muted-foreground hover:border-primary/50",
                props.disabled && "cursor-not-allowed opacity-70",
              )}
              title={cell.id}
              onClick={() => props.onToggle(cell.id)}
            >
              {selected ? <Check className="mx-auto h-3 w-3" /> : `${cell.row + 1}-${cell.col + 1}`}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function shapeRequests(counts: Record<ShapeKind, number>): ShapeRequest[] {
  return SHAPE_OPTIONS.map((option) => ({
    kind: option.kind,
    count: counts[option.kind] || 0,
  })).filter((shape) => shape.count > 0);
}

function manualShapesFromGenerator(generator: unknown): ManualShape[] {
  if (!generator || typeof generator !== "object" || !("manual_shapes" in generator) || !Array.isArray((generator as { manual_shapes?: unknown }).manual_shapes)) return [];
  return (generator as { manual_shapes: unknown[] }).manual_shapes
    .map((shape, index) => normalizeManualShape(shape, `manual_shape_${index + 1}`))
    .filter((shape): shape is ManualShape => Boolean(shape));
}

function normalizeManualShape(input: unknown, fallbackId: string): ManualShape | null {
  if (!input || typeof input !== "object") return null;
  const raw = input as Partial<ManualShape>;
  const kind = raw.kind;
  if (!kind || !SHAPE_OPTIONS.some((option) => option.kind === kind)) return null;
  const center = Array.isArray(raw.center) && raw.center.length >= 2 ? raw.center : [0, 0];
  const radius = Number(raw.radius || 0);
  return {
    id: String(raw.id || fallbackId),
    kind,
    center: [Number(center[0]) || 0, Number(center[1]) || 0],
    radius: Number.isFinite(radius) && radius > 0 ? radius : 120,
    rotation: Number(raw.rotation || 0),
  };
}

function nextManualShapeId(shapes: ManualShape[]) {
  const used = new Set(shapes.map((shape) => shape.id));
  let index = shapes.length + 1;
  while (used.has(`manual_shape_${index}`)) index += 1;
  return `manual_shape_${index}`;
}

type PolygonEditorSnapshot = {
  pieces: LevelPiece[];
  manualShapes: ManualShape[];
  shapeCounts: Record<ShapeKind, number>;
  polygonAssist: SeedAssist;
  targetCount: number;
};

function clonePoint(point: Point): Point {
  return [point[0], point[1]];
}

function clonePiece(piece: LevelPiece): LevelPiece {
  return {
    ...piece,
    points: piece.points.map(clonePoint),
    home: clonePoint(piece.home),
    neighbors: [...(piece.neighbors || [])],
    visible_bounds: [...(piece.visible_bounds || [0, 0, 0, 0])] as [number, number, number, number],
  };
}

function cloneManualShape(shape: ManualShape): ManualShape {
  return {
    ...shape,
    center: clonePoint(shape.center),
  };
}

function cloneSeedAssist(assist: SeedAssist): SeedAssist {
  return {
    outline: assist.outline,
    seed: {
      mode: assist.seed.mode,
      count: assist.seed.count,
      piece_ids: [...assist.seed.piece_ids],
    },
  };
}

function seedAssistSignature(assist: SeedAssist) {
  return {
    outline: assist.outline,
    seed: {
      mode: assist.seed.mode,
      count: assist.seed.count,
      piece_ids: [...assist.seed.piece_ids].sort(),
    },
  };
}

function cloneShapeCounts(counts: Record<ShapeKind, number>): Record<ShapeKind, number> {
  return SHAPE_OPTIONS.reduce(
    (acc, option) => ({ ...acc, [option.kind]: counts[option.kind] || 0 }),
    {} as Record<ShapeKind, number>,
  );
}

function clonePolygonSnapshot(snapshot: PolygonEditorSnapshot): PolygonEditorSnapshot {
  return {
    pieces: snapshot.pieces.map(clonePiece),
    manualShapes: snapshot.manualShapes.map(cloneManualShape),
    shapeCounts: cloneShapeCounts(snapshot.shapeCounts),
    polygonAssist: cloneSeedAssist(snapshot.polygonAssist),
    targetCount: snapshot.targetCount,
  };
}

function polygonEditorSignature(snapshot: PolygonEditorSnapshot) {
  return JSON.stringify({
    pieces: snapshot.pieces.map((piece) => ({
      id: piece.id,
      points: piece.points,
      home: piece.home,
      neighbors: [...(piece.neighbors || [])].sort(),
      visible_bounds: piece.visible_bounds || null,
      cells: piece.cells || [],
    })),
    manualShapes: snapshot.manualShapes,
    shapeCounts: cloneShapeCounts(snapshot.shapeCounts),
    polygonAssist: seedAssistSignature(snapshot.polygonAssist),
    targetCount: snapshot.targetCount,
  });
}

function knobEditorSignature(input: { cols: number; rows: number; knobSize: number; assist: SeedAssist }) {
  return JSON.stringify({
    cols: input.cols,
    rows: input.rows,
    knob_size: input.knobSize,
    assist: seedAssistSignature(input.assist),
  });
}

function isEditableElement(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false;
  return Boolean(target.closest("input, textarea, select, [contenteditable='true']"));
}

function pointInPolygon(point: Point, polygon: Point[]) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i];
    const b = polygon[j];
    const intersects = a[1] > point[1] !== b[1] > point[1] && point[0] < ((b[0] - a[0]) * (point[1] - a[1])) / (b[1] - a[1] || 1) + a[0];
    if (intersects) inside = !inside;
  }
  return inside;
}

function polygonArea(points: Point[]) {
  let area = 0;
  for (let index = 0; index < points.length; index += 1) {
    const a = points[index];
    const b = points[(index + 1) % points.length];
    area += a[0] * b[1] - b[0] * a[1];
  }
  return Math.abs(area / 2);
}

function distanceToPolygon(point: Point, polygon: Point[]) {
  let closest = Number.POSITIVE_INFINITY;
  for (let index = 0; index < polygon.length; index += 1) {
    closest = Math.min(closest, pointSegmentDistance(point, polygon[index], polygon[(index + 1) % polygon.length]));
  }
  return closest;
}

function polygonEdges(points: Point[]): Array<[Point, Point]> {
  return points.map((point, index) => [point, points[(index + 1) % points.length]]);
}

function segmentIntersection(a1: Point, a2: Point, b1: Point, b2: Point): Point | null {
  const r: Point = [a2[0] - a1[0], a2[1] - a1[1]];
  const s: Point = [b2[0] - b1[0], b2[1] - b1[1]];
  const denominator = cross(r, s);
  if (Math.abs(denominator) < 0.000001) return null;
  const delta: Point = [b1[0] - a1[0], b1[1] - a1[1]];
  const t = cross(delta, s) / denominator;
  const u = cross(delta, r) / denominator;
  if (t < 0 || t > 1 || u < 0 || u > 1) return null;
  return [a1[0] + r[0] * t, a1[1] + r[1] * t];
}

function cross(a: Point, b: Point) {
  return a[0] * b[1] - a[1] * b[0];
}

function intersectionMarkers(shapePoints: Point[], pieces: LevelPiece[], width: number, height: number) {
  const shapeEdges = polygonEdges(shapePoints);
  const boundaryEdges: Array<[Point, Point]> = [
    [[0, 0], [width, 0]],
    [[width, 0], [width, height]],
    [[width, height], [0, height]],
    [[0, height], [0, 0]],
  ];
  pieces.forEach((piece) => boundaryEdges.push(...polygonEdges(piece.points)));
  const points: Point[] = [];
  for (const shapeEdge of shapeEdges) {
    for (const boundaryEdge of boundaryEdges) {
      const point = segmentIntersection(shapeEdge[0], shapeEdge[1], boundaryEdge[0], boundaryEdge[1]);
      if (!point) continue;
      if (points.some((candidate) => Math.hypot(candidate[0] - point[0], candidate[1] - point[1]) < 5)) continue;
      points.push(point);
      if (points.length >= 80) return points;
    }
  }
  return points;
}

function pointSegmentDistance(point: Point, start: Point, end: Point) {
  const dx = end[0] - start[0];
  const dy = end[1] - start[1];
  const lengthSq = dx * dx + dy * dy;
  if (lengthSq <= 0) return Math.hypot(point[0] - start[0], point[1] - start[1]);
  const t = Math.max(0, Math.min(1, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / lengthSq));
  return Math.hypot(point[0] - (start[0] + dx * t), point[1] - (start[1] + dy * t));
}

function ShapeIcon(props: { kind: ShapeKind }) {
  const common = { fill: "rgba(217, 147, 63, 0.16)", stroke: "currentColor", strokeWidth: 2.4, strokeLinejoin: "round" as const, strokeLinecap: "round" as const };
  const paths: Record<ShapeKind, React.ReactNode> = {
    circle: <circle cx="18" cy="18" r="10" {...common} />,
    square: <rect x="9" y="9" width="18" height="18" rx="2" transform="rotate(12 18 18)" {...common} />,
    heart: <path d="M18 28 C8 21 6 12 12 9 C15 7 17 9 18 12 C19 9 21 7 24 9 C30 12 28 21 18 28 Z" {...common} />,
    triangle: <path d="M18 7 L29 27 L7 27 Z" {...common} />,
    star: <path d="M18 6 L21.4 13.6 L29.6 14.4 L23.4 19.8 L25.2 28 L18 23.8 L10.8 28 L12.6 19.8 L6.4 14.4 L14.6 13.6 Z" {...common} />,
    sector: <path d="M10 27 L18 8 C25 10 29 16 28 24 Z" {...common} />,
    crescent: <path d="M24.5 7.5 C18 9.4 14.2 14.2 14.2 19.2 C14.2 23.4 17 26.6 21.2 28.2 C13.4 29.2 7 24.2 7 17.4 C7 10.8 14.2 5.6 24.5 7.5 Z" {...common} />,
    hexagon: <path d="M18 6 L28 12 L28 24 L18 30 L8 24 L8 12 Z" {...common} />,
    blob: <path d="M18 7 C24 6 29 11 28 17 C31 23 24 30 17 28 C11 31 6 24 8 18 C5 12 11 7 18 7 Z" {...common} />,
    shard: <path d="M18 5 L28 13 L25 24 L15 30 L7 20 L10 10 Z" {...common} />,
  };
  return (
    <svg className="h-9 w-9 text-primary" viewBox="0 0 36 36" aria-hidden="true">
      {paths[props.kind]}
    </svg>
  );
}

function KnobEditor(props: {
  target: SelectedLevel;
  title: string;
  level: LevelConfig;
  onBack: () => void;
  onSave: (level: LevelConfig) => Promise<void>;
}) {
  const { target, title, level, onBack, onSave } = props;
  const knob = level.modes.knob || { auto: true as const, cols: DEFAULT_KNOB_COLS, rows: DEFAULT_KNOB_ROWS, knob_size: DEFAULT_KNOB_SIZE, assist: defaultAssist(DEFAULT_KNOB_SEED_COUNT) };
  const cols = knob.cols || DEFAULT_KNOB_COLS;
  const rows = knob.rows || DEFAULT_KNOB_ROWS;
  const width = level.image.width || 1080;
  const height = level.image.height || 1440;
  const validIds = React.useMemo(() => knobSeedIds(cols, rows), [cols, rows]);
  const [assist, setAssist] = React.useState<SeedAssist>(() => normalizeAssist(knob.assist, DEFAULT_KNOB_SEED_COUNT, validIds));
  const cellWidth = width / cols;
  const cellHeight = height / rows;
  const knobAmount = Math.min(cellWidth, cellHeight) * (knob.knob_size || DEFAULT_KNOB_SIZE);
  const knobSize = knob.knob_size || DEFAULT_KNOB_SIZE;
  const initialSignatureRef = React.useRef("");
  const currentAssist = filterAssistPieceIds(assist, validIds);
  const currentSignature = knobEditorSignature({ cols, rows, knobSize, assist: currentAssist });
  if (!initialSignatureRef.current) initialSignatureRef.current = currentSignature;
  const hasChanges = currentSignature !== initialSignatureRef.current;

  async function save() {
    if (!hasChanges) return;
    const savedAssist = filterAssistPieceIds(assist, validIds);
    const nextLevel = {
      ...level,
      modes: {
        ...level.modes,
        knob: {
          auto: true as const,
          cols,
          rows,
          knob_size: knobSize,
          assist: savedAssist,
        },
      },
    };
    await onSave(nextLevel);
    setAssist(savedAssist);
    initialSignatureRef.current = knobEditorSignature({ cols, rows, knobSize, assist: savedAssist });
  }

  function toggle(id: string) {
    setAssist((current) => {
      const pieceIds = current.seed.piece_ids.includes(id)
        ? current.seed.piece_ids.filter((item) => item !== id)
        : [...current.seed.piece_ids, id];
      return { ...current, seed: { ...current.seed, mode: "manual", piece_ids: pieceIds } };
    });
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex h-14 items-center justify-between border-b border-border bg-card px-4">
        <div>
          <div className="font-semibold">{title}</div>
          <div className="text-xs text-muted-foreground">凹凸 Seed 编辑</div>
        </div>
        <div className="flex items-center gap-2">
          <Button disabled={!hasChanges} onClick={() => void save()}>
            <Save size={16} />保存
          </Button>
          <Button variant="outline" onClick={onBack}>返回</Button>
        </div>
      </div>
      <div className="grid min-h-0 flex-1 grid-cols-[minmax(0,1fr)_280px] overflow-hidden">
        <div className="min-h-0 overflow-auto bg-secondary p-4">
          <div className="relative mx-auto aspect-[3/4] w-[min(72vw,720px)] min-w-[420px] bg-white">
            <img className="absolute inset-0 h-full w-full object-contain" src={sourceUrl(target)} alt="" draggable={false} />
            <svg className="absolute inset-0 h-full w-full" viewBox={`0 0 ${width} ${height}`}>
              {Array.from({ length: rows * cols }, (_, index) => {
                const row = Math.floor(index / cols);
                const col = index % cols;
                const id = `knob_${row}_${col}`;
                const selected = assist.seed.mode === "manual" && assist.seed.piece_ids.includes(id);
                const path = knobPath(col, row, cols, rows, cellWidth, cellHeight, knobAmount);
                return (
                  <g key={id}>
                    <path
                      d={path}
                      fill={selected ? "rgba(47, 118, 103, 0.36)" : "rgba(217, 147, 63, 0.16)"}
                      stroke={selected ? "#2f7667" : "#5A3A22"}
                      strokeWidth={selected ? 7 : 3}
                      onClick={() => assist.seed.mode === "manual" && toggle(id)}
                    />
                    {selected ? (
                      <g pointerEvents="none">
                        <circle cx={(col + 0.5) * cellWidth} cy={(row + 0.5) * cellHeight} r={22} fill="#2f7667" stroke="#FFF6E6" strokeWidth={5} />
                        <Check x={(col + 0.5) * cellWidth - 10} y={(row + 0.5) * cellHeight - 10} width={20} height={20} color="#FFF6E6" strokeWidth={4} />
                      </g>
                    ) : null}
                  </g>
                );
              })}
            </svg>
          </div>
        </div>
        <aside className="min-h-0 overflow-auto border-l border-border bg-card p-4 text-sm">
          <SeedSettingsPanel
            title="Seed 设置"
            description="自动模式只保存数量；手动模式直接在左侧凹凸预览中选择种子碎片。"
            assist={assist}
            defaultCount={DEFAULT_KNOB_SEED_COUNT}
            onChange={(next) => setAssist(filterAssistPieceIds(next, validIds))}
          >
            {(current, setCurrent) => (
              <div className="space-y-2">
                <KnobSeedGrid cols={cols} rows={rows} selectedIds={current.seed.piece_ids} onToggle={toggle} />
                <Button
                  type="button"
                  variant="outline"
                  className="w-full"
                  disabled={!current.seed.piece_ids.length}
                  onClick={() => setCurrent({ ...current, seed: { ...current.seed, piece_ids: [] } })}
                >
                  清空 Seed
                </Button>
              </div>
            )}
          </SeedSettingsPanel>
          <StatusLine label="网格" value={`${cols} x ${rows}`} />
          <StatusLine label="已选" value={String(assist.seed.piece_ids.length)} />
        </aside>
      </div>
    </div>
  );
}

function knobPath(col: number, row: number, cols: number, rows: number, cellWidth: number, cellHeight: number, amount: number) {
  const x0 = col * cellWidth;
  const y0 = row * cellHeight;
  const x1 = (col + 1) * cellWidth;
  const y1 = (row + 1) * cellHeight;
  const points: Point[] = [];
  appendKnobEdge(points, [x0, y0], [x1, y0], [0, -1], row === 0 ? 0 : -knobHorizontalSign(col, row), amount);
  appendKnobEdge(points, [x1, y0], [x1, y1], [1, 0], col === cols - 1 ? 0 : knobVerticalSign(col + 1, row), amount);
  appendKnobEdge(points, [x1, y1], [x0, y1], [0, 1], row === rows - 1 ? 0 : knobHorizontalSign(col, row + 1), amount);
  appendKnobEdge(points, [x0, y1], [x0, y0], [-1, 0], col === 0 ? 0 : -knobVerticalSign(col, row), amount);
  return points.map((point, index) => `${index === 0 ? "M" : "L"} ${point[0].toFixed(2)} ${point[1].toFixed(2)}`).join(" ") + " Z";
}

function appendKnobEdge(target: Point[], start: Point, end: Point, normal: Point, sign: number, amount: number) {
  const edgePoints = knobEdgePoints(start, end, normal, sign, amount);
  edgePoints.forEach((point, index) => {
    if (target.length > 0 && index === 0) return;
    target.push(point);
  });
}

function knobEdgePoints(start: Point, end: Point, normal: Point, sign: number, amount: number): Point[] {
  if (sign === 0) return [start, end];
  const edge: Point = [end[0] - start[0], end[1] - start[1]];
  const edgeLength = Math.hypot(edge[0], edge[1]);
  if (edgeLength <= 0 || amount <= 0) return [start, end];
  const tangent: Point = [edge[0] / edgeLength, edge[1] / edgeLength];
  const signedNormal: Point = [normal[0] * sign, normal[1] * sign];
  const centerOnEdge: Point = [(start[0] + end[0]) * 0.5, (start[1] + end[1]) * 0.5];
  const radius = amount / (1 + Math.SQRT1_2);
  const halfChord = radius * Math.SQRT1_2;
  const center: Point = [
    centerOnEdge[0] + signedNormal[0] * halfChord,
    centerOnEdge[1] + signedNormal[1] * halfChord,
  ];
  const before: Point = [
    centerOnEdge[0] - tangent[0] * halfChord,
    centerOnEdge[1] - tangent[1] * halfChord,
  ];
  const after: Point = [
    centerOnEdge[0] + tangent[0] * halfChord,
    centerOnEdge[1] + tangent[1] * halfChord,
  ];
  const points: Point[] = [start, before];
  const steps = 18;
  for (let step = 1; step < steps; step += 1) {
    const t = step / steps;
    const angle = Math.PI * 1.25 - Math.PI * 1.5 * t;
    points.push([
      center[0] + tangent[0] * Math.cos(angle) * radius + signedNormal[0] * Math.sin(angle) * radius,
      center[1] + tangent[1] * Math.cos(angle) * radius + signedNormal[1] * Math.sin(angle) * radius,
    ]);
  }
  points.push(after, end);
  return points;
}

function knobVerticalSign(edgeCol: number, row: number) {
  return ((edgeCol + row) % 2 === 0) ? 1 : -1;
}

function knobHorizontalSign(col: number, edgeRow: number) {
  return ((col + edgeRow) % 2 === 0) ? -1 : 1;
}

function PolygonEditor(props: {
  target: SelectedLevel;
  title: string;
  level: LevelConfig;
  onBack: () => void;
  onSave: (level: LevelConfig) => Promise<void>;
}) {
  const { target, title, level, onBack, onSave } = props;
  const width = level.image.width || 1080;
  const height = level.image.height || 1440;
  const initialPieces = React.useMemo(
    () => withNeighbors(fillCoverageGaps(level.modes.polygon?.pieces || [], width, height)),
    [height, level.modes.polygon?.pieces, width],
  );
  const [pieces, setPieces] = React.useState<LevelPiece[]>(() => initialPieces);
  const [past, setPast] = React.useState<PolygonEditorSnapshot[]>([]);
  const [future, setFuture] = React.useState<PolygonEditorSnapshot[]>([]);
  const [selectedIds, setSelectedIds] = React.useState<string[]>([]);
  const [polygonAssist, setPolygonAssist] = React.useState<SeedAssist>(() =>
    normalizeAssist(level.modes.polygon?.assist, DEFAULT_POLYGON_SEED_COUNT, new Set((level.modes.polygon?.pieces || []).map((piece) => piece.id))),
  );
  const [seedPicking, setSeedPicking] = React.useState(false);
  const [targetCount, setTargetCount] = React.useState(Math.max(DEFAULT_POLYGON_TARGET_COUNT, level.modes.polygon?.pieces?.length || DEFAULT_POLYGON_TARGET_COUNT));
  const [lineColor, setLineColor] = React.useState("#FFF6E6");
  const [manualShapes, setManualShapes] = React.useState<ManualShape[]>(() => manualShapesFromGenerator(level.modes.polygon?.generator));
  const [selectedManualShapeId, setSelectedManualShapeId] = React.useState<string | null>(null);
  const [shapeCounts, setShapeCounts] = React.useState<Record<ShapeKind, number>>(() => {
    const raw = level.modes.polygon?.generator;
    const shapes = raw && typeof raw === "object" && "shapes" in raw && Array.isArray((raw as { shapes?: unknown }).shapes) ? (raw as { shapes: ShapeRequest[] }).shapes : [];
    return SHAPE_OPTIONS.reduce(
      (acc, option) => ({
        ...acc,
        [option.kind]: shapes.find((shape) => shape.kind === option.kind)?.count || 0,
      }),
      {} as Record<ShapeKind, number>,
    );
  });
  const [drag, setDrag] = React.useState<{ pieceId: string; pointIndex: number; before: PolygonEditorSnapshot; moved: boolean } | null>(null);
  const [shapeDrag, setShapeDrag] = React.useState<
    | { id: string; mode: "move"; startPoint: Point; startShape: ManualShape; before: PolygonEditorSnapshot; moved: boolean }
    | { id: string; mode: "resize"; startPoint: Point; startShape: ManualShape; before: PolygonEditorSnapshot; moved: boolean }
    | null
  >(null);
  const svgRef = React.useRef<SVGSVGElement | null>(null);
  const currentSnapshotRef = React.useRef<PolygonEditorSnapshot | null>(null);
  const pastRef = React.useRef<PolygonEditorSnapshot[]>([]);
  const futureRef = React.useRef<PolygonEditorSnapshot[]>([]);
  const selectedManualShapeIdRef = React.useRef<string | null>(null);
  const initialSignatureRef = React.useRef("");

  function snapshotEditorState(): PolygonEditorSnapshot {
    return clonePolygonSnapshot({
      pieces,
      manualShapes,
      shapeCounts,
      polygonAssist,
      targetCount,
    });
  }

  function restoreSnapshot(snapshot: PolygonEditorSnapshot) {
    const cloned = clonePolygonSnapshot(snapshot);
    currentSnapshotRef.current = cloned;
    setPieces(cloned.pieces);
    setManualShapes(cloned.manualShapes);
    setShapeCounts(cloned.shapeCounts);
    setPolygonAssist(cloned.polygonAssist);
    setTargetCount(cloned.targetCount);
    setSelectedIds([]);
    selectedManualShapeIdRef.current = null;
    setSelectedManualShapeId(null);
    setSeedPicking(false);
  }

  function currentSnapshot() {
    return clonePolygonSnapshot(currentSnapshotRef.current || snapshotEditorState());
  }

  function setPastStack(next: PolygonEditorSnapshot[]) {
    pastRef.current = next;
    setPast(next);
  }

  function setFutureStack(next: PolygonEditorSnapshot[]) {
    futureRef.current = next;
    setFuture(next);
  }

  function recordHistory(snapshot = snapshotEditorState()) {
    setPastStack([...pastRef.current.slice(-39), clonePolygonSnapshot(snapshot)]);
    setFutureStack([]);
  }

  React.useEffect(() => {
    currentSnapshotRef.current = snapshotEditorState();
    pastRef.current = past;
    futureRef.current = future;
    selectedManualShapeIdRef.current = selectedManualShapeId;
  });

  function clientToSvgPoint(clientX: number, clientY: number): Point {
    const svg = svgRef.current;
    if (!svg) return [0, 0];
    const rect = svg.getBoundingClientRect();
    return [((clientX - rect.left) / rect.width) * width, ((clientY - rect.top) / rect.height) * height];
  }

  function svgPoint(event: React.PointerEvent): Point {
    return clientToSvgPoint(event.clientX, event.clientY);
  }

  function normalizedPieces(nextPieces: LevelPiece[]) {
    return withNeighbors(fillCoverageGaps(nextPieces, width, height));
  }

  function commitPieces(nextPieces: LevelPiece[]) {
    const normalized = normalizedPieces(nextPieces);
    recordHistory();
    setPieces(normalized);
    setPolygonAssist((current) => filterAssistPieceIds(current, new Set(normalized.map((piece) => piece.id))));
  }

  function selectPiece(id: string, additive: boolean) {
    setSelectedIds((current) => {
      if (!additive) return [id];
      return current.includes(id) ? current.filter((item) => item !== id) : [...current, id];
    });
  }

  function pieceAtPoint(point: Point) {
    const directHits = pieces.filter((piece) => pointInPolygon(point, piece.points));
    if (directHits.length) {
      return directHits.reduce((best, piece) => (polygonArea(piece.points) < polygonArea(best.points) ? piece : best), directHits[0]);
    }
    const tolerance = Math.max(12, Math.min(width, height) * 0.012);
    let best: { piece: LevelPiece; distance: number; area: number } | null = null;
    for (const piece of pieces) {
      const distance = distanceToPolygon(point, piece.points);
      if (distance > tolerance) continue;
      const area = polygonArea(piece.points);
      if (!best || distance < best.distance - 4 || (Math.abs(distance - best.distance) <= 4 && area < best.area)) {
        best = { piece, distance, area };
      }
    }
    return best?.piece || null;
  }

  function selectPieceAtPoint(point: Point, additive: boolean) {
    const piece = pieceAtPoint(point);
    if (!piece) return;
    if (seedPicking && polygonAssist.seed.mode === "manual") {
      toggleSeedPiece(piece.id);
      return;
    }
    selectedManualShapeIdRef.current = null;
    setSelectedManualShapeId(null);
    selectPiece(piece.id, additive);
  }

  function toggleSeedPiece(id: string) {
    recordHistory();
    setPolygonAssist((current) => {
      const pieceIds = current.seed.piece_ids.includes(id)
        ? current.seed.piece_ids.filter((item) => item !== id)
        : [...current.seed.piece_ids, id];
      return {
        ...current,
        seed: {
          ...current.seed,
          mode: "manual",
          piece_ids: pieceIds,
        },
      };
    });
  }

  function mergeSelected() {
    if (selectedIds.length < 2) return;
    const selectedPieces = selectedIds.map((id) => pieces.find((piece) => piece.id === id)).filter((piece): piece is LevelPiece => Boolean(piece));
    if (selectedPieces.length < 2) return;
    const merged = selectedPieces.slice(1).reduce((acc, piece) => mergePieces(acc, piece), selectedPieces[0]);
    commitPieces([...pieces.filter((piece) => !selectedIds.includes(piece.id)), merged]);
    setSelectedIds([merged.id]);
  }

  function movePoint(point: Point) {
    if (!drag) return;
    setDrag({ ...drag, moved: true });
    setPieces(
      normalizedPieces(pieces.map((piece) =>
        piece.id === drag.pieceId
          ? { ...piece, points: piece.points.map((candidate, index) => (index === drag.pointIndex ? point : candidate)) }
          : piece,
      )),
    );
  }

  function finishDrag() {
    if (drag) {
      recordHistory(drag.before);
    }
    setDrag(null);
  }

  function addManualShape(kind: ShapeKind, center: Point) {
    const before = snapshotEditorState();
    const radius = Math.sqrt((width * height) / Math.max(4, targetCount)) * 0.72;
    const shape: ManualShape = {
      id: nextManualShapeId(manualShapes),
      kind,
      center,
      radius,
      rotation: Math.random() * Math.PI * 2,
    };
    recordHistory(before);
    setManualShapes((current) => [...current, shape]);
    selectedManualShapeIdRef.current = shape.id;
    setSelectedManualShapeId(shape.id);
    svgRef.current?.focus();
  }

  function updateManualShape(id: string, patch: Partial<ManualShape>) {
    setManualShapes((current) => current.map((shape) => (shape.id === id ? { ...shape, ...patch } : shape)));
  }

  function removeManualShape(id: string, before = snapshotEditorState()) {
    recordHistory(before);
    setManualShapes((current) => current.filter((shape) => shape.id !== id));
    if (selectedManualShapeIdRef.current === id || selectedManualShapeId === id) {
      selectedManualShapeIdRef.current = null;
      setSelectedManualShapeId(null);
    }
  }

  function deleteSelectedManualShape() {
    const id = selectedManualShapeIdRef.current || selectedManualShapeId;
    if (!id) return false;
    removeManualShape(id, currentSnapshot());
    return true;
  }

  function moveManualShape(point: Point) {
    if (!shapeDrag) return;
    setShapeDrag({ ...shapeDrag, moved: true });
    if (shapeDrag.mode === "move") {
      const dx = point[0] - shapeDrag.startPoint[0];
      const dy = point[1] - shapeDrag.startPoint[1];
      updateManualShape(shapeDrag.id, { center: [shapeDrag.startShape.center[0] + dx, shapeDrag.startShape.center[1] + dy] });
      return;
    }
    const radius = Math.max(28, Math.hypot(point[0] - shapeDrag.startShape.center[0], point[1] - shapeDrag.startShape.center[1]));
    const rotation = Math.atan2(point[1] - shapeDrag.startShape.center[1], point[0] - shapeDrag.startShape.center[0]);
    updateManualShape(shapeDrag.id, { radius, rotation });
  }

  function finishShapeDrag() {
    if (shapeDrag) {
      recordHistory(shapeDrag.before);
    }
    setShapeDrag(null);
  }

  function undo() {
    const stack = pastRef.current;
    if (!stack.length) return;
    const previous = stack[stack.length - 1];
    setFutureStack([currentSnapshot(), ...futureRef.current].slice(0, 40));
    setPastStack(stack.slice(0, -1));
    restoreSnapshot(previous);
  }

  function redo() {
    const stack = futureRef.current;
    if (!stack.length) return;
    const next = stack[0];
    setPastStack([...pastRef.current.slice(-39), currentSnapshot()]);
    setFutureStack(stack.slice(1));
    restoreSnapshot(next);
  }

  async function save() {
    if (!hasChanges) return;
    const shapes = shapeRequests(shapeCounts);
    const savedPieces = normalizedPieces(pieces);
    const validPolygonIds = new Set(savedPieces.map((piece) => piece.id));
    const savedAssist = filterAssistPieceIds(polygonAssist, validPolygonIds);
    const savedSnapshot = clonePolygonSnapshot({
      pieces: savedPieces,
      manualShapes,
      shapeCounts,
      polygonAssist: savedAssist,
      targetCount,
    });
    const knob = level.modes.knob || { auto: true as const, cols: DEFAULT_KNOB_COLS, rows: DEFAULT_KNOB_ROWS, knob_size: DEFAULT_KNOB_SIZE, assist: defaultAssist(DEFAULT_KNOB_SEED_COUNT) };
    const nextLevel = {
      ...level,
      modes: {
        ...level.modes,
        polygon: { pieces: savedPieces, generator: { target_count: targetCount, shapes, manual_shapes: manualShapes }, assist: savedAssist },
        knob: {
          auto: true as const,
          cols: knob.cols || DEFAULT_KNOB_COLS,
          rows: knob.rows || DEFAULT_KNOB_ROWS,
          knob_size: knob.knob_size || DEFAULT_KNOB_SIZE,
          assist: normalizeAssist(knob.assist, DEFAULT_KNOB_SEED_COUNT, knobSeedIds(knob.cols || DEFAULT_KNOB_COLS, knob.rows || DEFAULT_KNOB_ROWS)),
        },
        swap: { auto: true as const, cols: DEFAULT_SWAP_COLS, rows: DEFAULT_SWAP_ROWS },
      },
    };
    await onSave(nextLevel);
    setPieces(savedPieces);
    setPolygonAssist(savedAssist);
    currentSnapshotRef.current = savedSnapshot;
    initialSignatureRef.current = polygonEditorSignature(savedSnapshot);
    setPastStack([]);
    setFutureStack([]);
  }

  function updateShape(kind: ShapeKind, delta: number) {
    recordHistory();
    setShapeCounts((current) => ({ ...current, [kind]: Math.max(0, Math.min(12, (current[kind] || 0) + delta)) }));
  }

  function updateTargetCount(value: number) {
    recordHistory();
    setTargetCount(value);
  }

  function generate() {
    const nextPieces = generatePieces(width, height, targetCount, shapeRequests(shapeCounts), manualShapes);
    commitPieces(nextPieces);
    setSelectedIds([]);
  }

  const effectiveLineColor = HEX_COLOR_RE.test(lineColor) ? lineColor : "#FFF6E6";
  const currentSignature = polygonEditorSignature(snapshotEditorState());
  if (!initialSignatureRef.current) initialSignatureRef.current = currentSignature;
  const hasChanges = currentSignature !== initialSignatureRef.current;

  React.useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      const modifier = event.metaKey || event.ctrlKey;
      const key = event.key.toLowerCase();
      if (isEditableElement(event.target) && !(modifier && (key === "z" || key === "y"))) return;
      if (modifier && key === "z") {
        event.preventDefault();
        if (event.shiftKey) redo();
        else undo();
        return;
      }
      if (modifier && key === "y") {
        event.preventDefault();
        redo();
        return;
      }
      if ((event.key === "Delete" || event.key === "Backspace") && selectedManualShapeIdRef.current) {
        event.preventDefault();
        deleteSelectedManualShape();
      }
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  });

  return (
    <div className="flex h-full flex-col">
      <div className="flex h-14 items-center justify-between border-b border-border bg-card px-4">
        <div>
          <div className="font-semibold">{title}</div>
          <div className="text-xs text-muted-foreground">多边形编辑</div>
        </div>
        <div className="flex items-center gap-2">
          <label className="inline-flex items-center gap-2 text-sm text-foreground">
            目标块数
            <Input className="h-8 w-20" type="number" value={targetCount} min={4} max={80} onChange={(event) => updateTargetCount(Number(event.target.value))} />
          </label>
          <Button variant="outline" onClick={generate}>
            <Wand2 size={16} />生成
          </Button>
          <Button variant="outline" disabled={!past.length} onClick={undo}>
            <Undo2 size={16} />撤销
          </Button>
          <Button variant="outline" disabled={!future.length} onClick={redo}>
            <Redo2 size={16} />重做
          </Button>
          <Button variant="outline" disabled={selectedIds.length < 2} onClick={mergeSelected}>合并</Button>
          <Button disabled={!hasChanges} onClick={() => void save()}>
            <Save size={16} />保存
          </Button>
          <Button variant="outline" onClick={onBack}>返回</Button>
        </div>
      </div>
      <div className="grid min-h-0 flex-1 grid-cols-[minmax(0,1fr)_280px] overflow-hidden">
        <div className="min-h-0 overflow-auto bg-secondary p-4">
          <div
            className="relative mx-auto aspect-[3/4] w-[min(72vw,720px)] min-w-[420px] bg-white"
            onDragOver={(event) => event.preventDefault()}
            onDrop={(event) => {
              event.preventDefault();
              const kind = event.dataTransfer.getData("application/x-jigcat-shape") as ShapeKind;
              if (!SHAPE_OPTIONS.some((option) => option.kind === kind)) return;
              addManualShape(kind, clientToSvgPoint(event.clientX, event.clientY));
            }}
          >
            <img className="absolute inset-0 h-full w-full object-contain" src={sourceUrl(target)} alt="" draggable={false} />
            <svg
              ref={svgRef}
              tabIndex={0}
              className="absolute inset-0 h-full w-full touch-none"
              viewBox={`0 0 ${width} ${height}`}
              onPointerDown={(event) => {
                svgRef.current?.focus();
                selectPieceAtPoint(svgPoint(event), event.metaKey || event.ctrlKey);
              }}
              onPointerMove={(event) => {
                if (shapeDrag) moveManualShape(svgPoint(event));
                else if (drag) movePoint(svgPoint(event));
              }}
              onPointerUp={() => {
                finishShapeDrag();
                finishDrag();
              }}
              onPointerLeave={() => {
                finishShapeDrag();
                finishDrag();
              }}
            >
              {manualShapes.map((shape) => {
                const shapeSelected = shape.id === selectedManualShapeId;
                const polygon = manualShapePolygon(shape, width, height);
                const markers = shapeDrag?.id === shape.id ? intersectionMarkers(polygon, pieces, width, height) : [];
                const handle: Point = [
                  shape.center[0] + Math.cos(shape.rotation) * shape.radius,
                  shape.center[1] + Math.sin(shape.rotation) * shape.radius,
                ];
                return (
                  <g key={shape.id}>
                    <polygon
                      points={polygon.map((point) => point.join(",")).join(" ")}
                      fill={shapeSelected ? "rgba(217,147,63,0.20)" : "rgba(47,118,103,0.15)"}
                      stroke={effectiveLineColor}
                      strokeWidth={shapeSelected ? 7 : 4}
                      strokeDasharray="16 10"
                      pointerEvents="stroke"
                      onPointerDown={(event) => {
                        event.stopPropagation();
                        svgRef.current?.focus();
                        selectedManualShapeIdRef.current = shape.id;
                        setSelectedManualShapeId(shape.id);
                        setShapeDrag({ id: shape.id, mode: "move", startPoint: svgPoint(event), startShape: shape, before: snapshotEditorState(), moved: false });
                      }}
                    />
                    <circle
                      cx={shape.center[0]}
                      cy={shape.center[1]}
                      r={16}
                      fill="#FFF6E6"
                      stroke={effectiveLineColor}
                      strokeWidth={6}
                      onPointerDown={(event) => {
                        event.stopPropagation();
                        svgRef.current?.focus();
                        selectedManualShapeIdRef.current = shape.id;
                        setSelectedManualShapeId(shape.id);
                        setShapeDrag({ id: shape.id, mode: "move", startPoint: svgPoint(event), startShape: shape, before: snapshotEditorState(), moved: false });
                      }}
                    />
                    {shapeSelected && (
                      <>
                        <line x1={shape.center[0]} y1={shape.center[1]} x2={handle[0]} y2={handle[1]} stroke={effectiveLineColor} strokeWidth={4} strokeDasharray="10 8" />
                        <circle
                          cx={handle[0]}
                          cy={handle[1]}
                          r={18}
                          fill="#FFF6E6"
                          stroke={effectiveLineColor}
                          strokeWidth={7}
                          onPointerDown={(event) => {
                            event.stopPropagation();
                            setShapeDrag({ id: shape.id, mode: "resize", startPoint: svgPoint(event), startShape: shape, before: snapshotEditorState(), moved: false });
                          }}
                        />
                      </>
                    )}
                    {markers.map((point, markerIndex) => (
                      <g key={`intersection-${markerIndex}`} pointerEvents="none">
                        <circle cx={point[0]} cy={point[1]} r={10} fill="#38BDF8" stroke="#FFF6E6" strokeWidth={4} />
                        <circle cx={point[0]} cy={point[1]} r={3} fill="#0F766E" />
                      </g>
                    ))}
                  </g>
                );
              })}
              {pieces.map((piece, index) => {
                const selected = selectedIds.includes(piece.id);
                const seedSelected = polygonAssist.seed.mode === "manual" && polygonAssist.seed.piece_ids.includes(piece.id);
                return (
                  <g key={piece.id}>
                    <polygon
                      points={piece.points.map((point) => point.join(",")).join(" ")}
                      fill={`hsla(${(index * 47) % 360}, 74%, 62%, 0.28)`}
                      stroke={seedSelected ? "#2f7667" : effectiveLineColor}
                      strokeWidth={selected || seedSelected ? 7 : 3}
                      pointerEvents="none"
                    />
                    {seedSelected && (
                      <g pointerEvents="none">
                        <circle cx={piece.home[0]} cy={piece.home[1]} r={22} fill="#2f7667" stroke="#FFF6E6" strokeWidth={5} />
                        <Check x={piece.home[0] - 10} y={piece.home[1] - 10} width={20} height={20} color="#FFF6E6" strokeWidth={4} />
                      </g>
                    )}
                    {selected && piece.points.map((point, pointIndex) => (
                      <circle
                        key={pointIndex}
                        cx={point[0]}
                        cy={point[1]}
                        r={8}
                        fill="#FFF6E6"
                        stroke={effectiveLineColor}
                        strokeWidth={4}
                        onPointerDown={(event) => {
                          event.stopPropagation();
                          setDrag({ pieceId: piece.id, pointIndex, before: snapshotEditorState(), moved: false });
                        }}
                      />
                    ))}
                  </g>
                );
              })}
            </svg>
          </div>
        </div>
        <aside className="min-h-0 overflow-auto border-l border-border bg-card p-4 text-sm">
          <div className="mb-2 text-sm font-semibold text-foreground">编辑说明</div>
          <p className="mb-4 text-muted-foreground">点击碎片选择，按住 Cmd/Ctrl 可多选并合并。选中碎片后拖动圆点微调轮廓。</p>
          <div className="mb-4 border-y border-border py-3">
            <div className="mb-2 text-sm font-semibold text-foreground">指定形状</div>
            <div className="grid grid-cols-2 gap-2">
              {SHAPE_OPTIONS.map((option) => (
                <div
                  key={option.kind}
                  className="cursor-grab rounded-md border border-border bg-background p-2 active:cursor-grabbing"
                  draggable
                  onDragStart={(event) => {
                    event.dataTransfer.setData("application/x-jigcat-shape", option.kind);
                    event.dataTransfer.effectAllowed = "copy";
                  }}
                >
                  <div className="mb-1 grid place-items-center">
                    <ShapeIcon kind={option.kind} />
                    <span className="mt-1 text-xs text-foreground">{option.label}</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Button size="icon" variant="outline" className="h-7 w-7" onClick={() => updateShape(option.kind, -1)}>-</Button>
                    <span className="min-w-6 flex-1 text-center tabular-nums">{shapeCounts[option.kind] || 0}</span>
                    <Button size="icon" variant="outline" className="h-7 w-7" onClick={() => updateShape(option.kind, 1)}>+</Button>
                  </div>
                </div>
              ))}
            </div>
            <p className="mt-2 text-xs text-muted-foreground">拖拽形状到图片上可手动指定位置；下方数量仍会随机生成。</p>
          </div>
          <div className="mb-4 border-b border-border pb-4">
            <div className="mb-2 text-sm font-semibold text-foreground">线条颜色</div>
            <div className="flex flex-wrap gap-2">
              {LINE_COLOR_OPTIONS.map((color) => (
                <button
                  key={color}
                  type="button"
                  className={cn("h-8 w-8 rounded-full border", effectiveLineColor === color ? "border-primary ring-2 ring-primary/30" : "border-border")}
                  style={{ backgroundColor: color }}
                  onClick={() => setLineColor(color)}
                  aria-label={`线条颜色 ${color}`}
                />
              ))}
            </div>
            <Input className="mt-2 h-8" value={lineColor} onChange={(event) => setLineColor(event.target.value)} />
          </div>
          <div className="mb-4">
            <SeedSettingsPanel
              title="Seed 设置"
              description="Seed 是之后托盘玩法中预先放好的碎片。手动模式需要打开选择后，在预览里点选碎片。"
              assist={polygonAssist}
              defaultCount={DEFAULT_POLYGON_SEED_COUNT}
              onChange={(assist) => {
                recordHistory();
                const next = filterAssistPieceIds(assist, new Set(pieces.map((piece) => piece.id)));
                setPolygonAssist(next);
                if (next.seed.mode !== "manual") setSeedPicking(false);
              }}
            >
              {(assist, setAssist) => (
                <div className="space-y-2">
                  <Button
                    type="button"
                    variant={seedPicking ? "default" : "outline"}
                    className="w-full"
                    onClick={() => setSeedPicking((current) => !current)}
                  >
                    {seedPicking ? "正在选择 Seed" : "选择 Seed 碎片"}
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    className="w-full"
                    disabled={!assist.seed.piece_ids.length}
                    onClick={() => setAssist({ ...assist, seed: { ...assist.seed, piece_ids: [] } })}
                  >
                    清空 Seed
                  </Button>
                </div>
              )}
            </SeedSettingsPanel>
          </div>
          <StatusLine label="碎片数" value={String(pieces.length)} />
          <StatusLine label="已选择" value={String(selectedIds.length)} />
          <Button variant="outline" className="mt-4 w-full" onClick={() => { commitPieces([]); setSelectedIds([]); }}>
            <Trash2 size={16} />清空
          </Button>
        </aside>
      </div>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(<App />);
