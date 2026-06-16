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
import { ChevronDown, ChevronRight, Edit3, Eye, FolderPlus, Gamepad2, GripVertical, Hexagon, ImageIcon, ImageUp, Pencil, Plus, Save, Sparkles, Trash2, Wand2 } from "lucide-react";
import { toast } from "sonner";
import { assetUrl, loadCatalog, loadLevel, saveCatalog, saveLevel, sourceUrl, uploadLevelCover, uploadSource, uploadTopicAsset } from "./api";
import { Button } from "./components/ui/button";
import { Input } from "./components/ui/input";
import { Toaster } from "./components/ui/sonner";
import { Textarea } from "./components/ui/textarea";
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
import { generatePieces, mergePieces, sequentialId, withNeighbors, zhI18n } from "./geometry";
import { cn } from "./lib/utils";
import type { CatalogGroup, CatalogLevel, CatalogRenameOperation, CatalogTopic, LevelCatalog, LevelConfig, LevelPiece, LevelStatus, Point, SelectedLevel } from "./types";
import "./styles.css";

const emptyCatalog: LevelCatalog = {
  version: 3,
  default_locale: "en",
  locales: ["en", "zh", "ja"],
  image_presets: [{ id: "mobile_portrait_3x4", name: "Mobile portrait 3:4", aspect_ratio: 0.75, default: true }],
  topics: [],
};
const DEFAULT_POLYGON_TARGET_COUNT = 36;
const DEFAULT_KNOB_COLS = 6;
const DEFAULT_KNOB_ROWS = 8;
const DEFAULT_KNOB_SIZE = 0.24;
const DEFAULT_SWAP_COLS = 5;
const DEFAULT_SWAP_ROWS = 7;
const DEFAULT_TOPIC_COLOR = "#D9933F";
const DEFAULT_GROUP_COLOR = "#F6EBD4";
const HEX_COLOR_RE = /^#[0-9a-fA-F]{6}$/;

type DeleteTarget =
  | { kind: "topic"; topic: CatalogTopic }
  | { kind: "group"; topic: CatalogTopic; group: CatalogGroup }
  | { kind: "level"; topic: CatalogTopic; group: CatalogGroup; level: CatalogLevel };

function App() {
  const [catalog, setCatalog] = React.useState<LevelCatalog>(emptyCatalog);
  const [statuses, setStatuses] = React.useState<LevelStatus[]>([]);
  const [selected, setSelected] = React.useState<SelectedLevel | null>(null);
  const [level, setLevel] = React.useState<LevelConfig | null>(null);
  const [expanded, setExpanded] = React.useState<Record<string, boolean>>({});
  const [editingPolygon, setEditingPolygon] = React.useState(false);
  const [editMode, setEditMode] = React.useState(false);
  const [renames, setRenames] = React.useState<CatalogRenameOperation[]>([]);
  const skipNextLevelLoad = React.useRef(false);

  React.useEffect(() => {
    void refresh();
  }, []);

  React.useEffect(() => {
    if (!selected) {
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
    const group = topic?.groups.find((item) => item.id === selected?.groupId);
    const levelItem = group?.levels.find((item) => item.id === selected?.levelId);
    return { topic, group, levelItem };
  }

  const names = selectedNames();

  function updateSelected(next: SelectedLevel | null) {
    setSelected(next);
  }

  function updateSelectedAfterIdRename(next: SelectedLevel) {
    skipNextLevelLoad.current = true;
    setSelected(next);
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
        <aside className="border-r border-border bg-card">
          <TreePanel
            catalog={catalog}
            expanded={expanded}
            statuses={statuses}
            selected={selected}
            editMode={editMode}
            onExpanded={setExpanded}
            onSelect={updateSelected}
            onClearSelection={() => setSelected(null)}
            onChange={setCatalog}
            onEditMode={setEditMode}
            onRename={recordRename}
            onRenameSelection={updateSelectedAfterIdRename}
            onTopicAsset={async (topicId, asset, file) => {
              const result = await uploadTopicAsset(topicId, asset, file);
              setCatalog((current) => ({
                ...current,
                topics: current.topics.map((topic) => (topic.id === topicId ? { ...topic, [asset]: result.path } : topic)),
              }));
              toast.success(asset === "cover" ? "主题封面已上传" : "主题 icon 已上传");
            }}
          />
        </aside>
        <section className="min-w-0 overflow-hidden">
          {editingPolygon && selected && level ? (
            <PolygonEditor
              target={selected}
              title={`${names.topic?.name || ""} / ${names.group?.name || ""} / ${level.title}`}
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
          ) : selected && level ? (
            <LevelDetails
              catalog={catalog}
              target={selected}
              level={level}
              status={statusFor(selected)}
              editMode={editMode}
              onLevel={setLevel}
              onCatalog={setCatalog}
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
              onUploadCover={async (file) => {
                try {
                  const result = await uploadLevelCover(selected, file);
                  setCatalog((current) => ({
                    ...current,
                    topics: current.topics.map((topic) =>
                      topic.id === selected.topicId
                        ? {
                            ...topic,
                            groups: topic.groups.map((group) =>
                              group.id === selected.groupId
                                ? { ...group, levels: group.levels.map((item) => (item.id === selected.levelId ? { ...item, cover: result.path } : item)) }
                                : group,
                            ),
                          }
                        : topic,
                    ),
                  }));
                  toast.success("关卡封面已上传");
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
            />
          ) : (
            <div className="grid h-full place-items-center text-muted-foreground">从左侧创建或选择一个关卡。</div>
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
  selected: SelectedLevel | null;
  editMode: boolean;
  onExpanded: (value: Record<string, boolean>) => void;
  onSelect: (value: SelectedLevel) => void;
  onClearSelection: () => void;
  onChange: (value: LevelCatalog) => void;
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
    toast.success("已添加主题");
  }

  function withLevelPaths(topicId: string, groupId: string, level: CatalogLevel): CatalogLevel {
    return {
      ...level,
      path: `res://levels/${topicId}/${groupId}/${level.id}/level.json`,
      source: `res://levels/${topicId}/${groupId}/${level.id}/source.jpg`,
    };
  }

  function remapResPath(value: string, fromPrefix: string, toPrefix: string) {
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
          levels: group.levels.map((level) =>
            withLevelPaths(id, group.id, {
              ...level,
              cover: remapResPath(level.cover, `res://levels/${topic.id}/`, `res://levels/${id}/`),
            }),
          ),
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
        levels: group.levels.map((level) =>
          withLevelPaths(topic.id, id, {
            ...level,
            cover: remapResPath(level.cover, `res://levels/${topic.id}/${group.id}/`, `res://levels/${topic.id}/${id}/`),
          }),
        ),
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
      return withLevelPaths(topic.id, group.id, {
        ...level,
        id,
        sort_order: index,
        cover: remapResPath(level.cover, `res://levels/${topic.id}/${group.id}/${level.id}/`, `res://levels/${topic.id}/${group.id}/${id}/`),
      });
    });
    return { levels: nextLevels, renames, levelIdMap };
  }

  function selectionWithMaps(maps: { topic?: Map<string, string>; group?: Map<string, string>; level?: Map<string, string> }) {
    if (!selected) return null;
    return {
      topicId: maps.topic?.get(selected.topicId) || selected.topicId,
      groupId: maps.group?.get(selected.groupId) || selected.groupId,
      levelId: maps.level?.get(selected.levelId) || selected.levelId,
    };
  }

  function applyRenumberedSelection(next: SelectedLevel | null) {
    if (next && selected && (next.topicId !== selected.topicId || next.groupId !== selected.groupId || next.levelId !== selected.levelId)) {
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
    toast.success("已添加分组");
  }

  function addLevel(topic: CatalogTopic, group: CatalogGroup) {
    const title = `关卡 ${group.levels.length + 1}`;
    const id = sequentialId("level", group.levels.map((level) => level.id));
    const level: CatalogLevel = {
      id,
      title,
      title_i18n: zhI18n(title),
      cover: "",
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
    onSelect({ topicId: topic.id, groupId: group.id, levelId: id });
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
      if (selected?.topicId === target.topic.id && selected.groupId === target.group.id) {
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
    if (selected?.topicId === target.topic.id && selected.groupId === target.group.id && selected.levelId === target.level.id) {
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
                        name={topic.name}
                        color={topic.color}
                        cover={topic.cover}
                        icon={topic.icon}
                        strong
                        handleProps={handleProps}
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
                                  name={group.name}
                                  color={group.color}
                                  handleProps={handleProps}
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
                                  const active = selected?.topicId === topic.id && selected.groupId === group.id && selected.levelId === level.id;
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
                                          onSelect={() => onSelect(target)}
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
  if (target.kind === "topic") return `删除主题「${target.topic.name}」？主题下的分组和关卡也会从结构中移除。`;
  if (target.kind === "group") return `删除分组「${target.group.name}」？该分组下的关卡也会从结构中移除。`;
  return `删除关卡「${target.level.title}」？`;
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
  onChange: (value: string) => void;
}) {
  const normalized = HEX_COLOR_RE.test(props.value) ? props.value.toUpperCase() : props.fallback;
  const [draft, setDraft] = React.useState(normalized);

  React.useEffect(() => {
    setDraft(normalized);
  }, [normalized]);

  function commit(value: string) {
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
    <span className="inline-flex items-center gap-1.5">
      <input
        className="h-6 w-8 cursor-pointer rounded border border-input bg-transparent p-0"
        type="color"
        value={normalized}
        onChange={(event) => {
          const next = event.target.value.toUpperCase();
          setDraft(next);
          props.onChange(next);
        }}
      />
      <Input
        className="h-7 w-24 font-mono text-[11px]"
        value={draft}
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
  if (props.editMode) {
    const hasMetaControls = Boolean(props.onColor || props.onCoverUpload || props.onIconUpload);
    return (
      <div
        className={cn("min-h-16 rounded-md px-1 py-1.5", !props.isDraggingTree && "hover:bg-accent")}
        style={{ paddingLeft: `${props.depth * 18 + 4}px` }}
      >
        <div className="flex min-w-0 items-center gap-1">
          <button className="grid h-7 w-6 shrink-0 cursor-grab place-items-center text-muted-foreground active:cursor-grabbing" {...props.handleProps} title="拖拽排序">
            <GripVertical size={15} />
          </button>
          <button className="grid h-7 w-7 shrink-0 place-items-center text-muted-foreground" onClick={props.onToggle}>
            {props.expanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
          </button>
          <Input
            className={cn("h-8 min-w-0 flex-1 border-transparent bg-transparent px-2 shadow-none focus-visible:bg-background", props.strong && "font-medium")}
            value={props.name}
            onChange={(event) => props.onName(event.target.value)}
          />
          <Button size="icon" variant="ghost" className="h-7 w-7 shrink-0" onClick={props.onAdd} title={props.addTitle}>
            <Plus size={14} />
          </Button>
          <Button size="icon" variant="ghost" className="h-7 w-7 shrink-0 text-destructive hover:text-destructive" onClick={props.onDelete} title="删除">
            <Trash2 size={14} />
          </Button>
        </div>
        {hasMetaControls && (
          <div className="mt-2 flex items-center gap-3 pl-[64px] text-xs text-muted-foreground">
            {props.onColor && (
              <label className="inline-flex items-center gap-1.5" title="颜色">
                <span>颜色</span>
                <ColorField
                  value={props.color || ""}
                  fallback={props.strong ? DEFAULT_TOPIC_COLOR : DEFAULT_GROUP_COLOR}
                  onChange={props.onColor}
                />
              </label>
            )}
            {props.onCoverUpload && (
              <span className="inline-flex items-center gap-1.5">
                <AssetUploadButton
                  title={props.cover ? "替换主题封面" : "上传主题封面"}
                  accept="image/jpeg,image/png,image/webp"
                  active={Boolean(props.cover)}
                  onUpload={props.onCoverUpload}
                >
                  <ImageIcon size={14} />
                </AssetUploadButton>
                <span>封面</span>
              </span>
            )}
            {props.onIconUpload && (
              <span className="inline-flex items-center gap-1.5">
                <AssetUploadButton
                  title={props.icon ? "替换主题 icon" : "上传主题 icon"}
                  accept="image/svg+xml,image/png"
                  active={Boolean(props.icon)}
                  onUpload={props.onIconUpload}
                >
                  <Sparkles size={14} />
                </AssetUploadButton>
                <span>Icon</span>
              </span>
            )}
          </div>
        )}
      </div>
    );
  }

  return (
    <div className={cn("flex min-h-10 items-center gap-1 rounded-md px-1", !props.isDraggingTree && "hover:bg-accent")} style={{ paddingLeft: `${props.depth * 18 + 4}px` }}>
      <button className="grid h-7 w-7 place-items-center text-muted-foreground" onClick={props.onToggle}>
        {props.expanded ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
      </button>
      {props.strong && props.icon && <img className="h-5 w-5 shrink-0 object-contain" src={assetUrl(props.icon)} alt="" />}
      {props.color && <span className="h-3 w-3 shrink-0 rounded-full border border-border" style={{ backgroundColor: props.color }} />}
      <span className={cn("min-w-0 flex-1 truncate px-2", props.strong && "font-medium")}>{props.name}</span>
    </div>
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
    <div className={cn("ml-8 flex h-9 items-center gap-2 rounded-md px-2 text-muted-foreground", !props.isDraggingTree && "hover:bg-accent hover:text-foreground", props.active && "bg-accent text-foreground")}>
      {props.editMode && (
        <button className="grid h-7 w-5 cursor-grab place-items-center text-muted-foreground active:cursor-grabbing" {...props.handleProps} title="拖拽排序">
          <GripVertical size={14} />
        </button>
      )}
      <Gamepad2 className="h-4 w-4 shrink-0 text-primary" />
      <button className="min-w-0 flex-1 truncate text-left" onClick={props.onSelect}>{props.level.title}</button>
      {props.level.cover && <ImageIcon className="h-4 w-4 shrink-0 text-success" aria-label="已有封面" />}
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

function LevelDetails(props: {
  catalog: LevelCatalog;
  target: SelectedLevel;
  level: LevelConfig;
  status?: LevelStatus;
  editMode: boolean;
  onLevel: (level: LevelConfig) => void;
  onCatalog: (catalog: LevelCatalog) => void;
  onUpload: (file: File) => Promise<void>;
  onUploadCover: (file: File) => Promise<void>;
  onSave: () => Promise<void>;
  onEditPolygon: () => void;
}) {
  const { catalog, target, level, status, editMode, onLevel, onCatalog, onUpload, onUploadCover, onSave, onEditPolygon } = props;
  const topic = catalog.topics.find((item) => item.id === target.topicId);
  const group = topic?.groups.find((item) => item.id === target.groupId);
  const catalogLevel = group?.levels.find((item) => item.id === target.levelId);

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
        {editMode && (
          <Button onClick={() => void onSave()}>
            <Save size={16} />保存关卡
          </Button>
        )}
      </div>
      <div className="grid grid-cols-[1fr_320px] gap-8">
        <div className="space-y-4">
          <label className="block text-sm font-medium text-foreground">
            中文标题
            <Input className="mt-1" value={level.title} disabled={!editMode} onChange={(event) => updateTitle(event.target.value)} />
          </label>
          <label className="block text-sm font-medium text-foreground">
            中文描述
            <Textarea className="mt-1 min-h-32" value={level.description} disabled={!editMode} onChange={(event) => onLevel({ ...level, description: event.target.value, description_i18n: zhI18n(event.target.value) })} />
          </label>
          <div className="border-y border-border py-3">
            <div className="mb-2 text-sm font-semibold text-foreground">模式数据</div>
            <StatusLine label="Polygon" value={status?.hasPolygon ? `已有 ${status.pieceCount} 块` : "未生成"} />
            <StatusLine label="凹凸" value={`Godot 自动生成 ${DEFAULT_KNOB_COLS} x ${DEFAULT_KNOB_ROWS}`} />
            <StatusLine label="Swap" value={`Godot 自动生成 ${DEFAULT_SWAP_COLS} x ${DEFAULT_SWAP_ROWS}`} />
          </div>
          <Button disabled={!status?.hasSource} onClick={onEditPolygon}>
            <Edit3 size={16} />编辑多边形
          </Button>
        </div>
        <div className="space-y-4">
          <div className="imageBox">
            {status?.hasSource ? <img src={sourceUrl(target)} alt={level.title} /> : <span>未上传 source.jpg</span>}
          </div>
          <div className="space-y-2">
            <div className="text-sm font-medium text-foreground">关卡封面</div>
            <div className="imageBox h-36">
              {catalogLevel?.cover ? <img src={assetUrl(catalogLevel.cover)} alt={`${level.title} 封面`} /> : <span>未上传关卡封面</span>}
            </div>
            {editMode && (
              <label className="inline-flex h-9 w-full cursor-pointer items-center justify-center gap-2 rounded-md border border-input bg-background px-4 py-2 text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground">
                <ImageUp size={16} />上传封面
                <input
                  className="hidden"
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    event.currentTarget.value = "";
                    if (file) void onUploadCover(file);
                  }}
                />
              </label>
            )}
          </div>
          {editMode && (
            <label className="inline-flex h-9 w-full cursor-pointer items-center justify-center gap-2 rounded-md border border-input bg-background px-4 py-2 text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground">
              <ImageUp size={16} />上传 JPG 3:4
              <input
                className="hidden"
                type="file"
                accept="image/jpeg"
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  if (file) void onUpload(file);
                }}
              />
            </label>
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

function PolygonEditor(props: {
  target: SelectedLevel;
  title: string;
  level: LevelConfig;
  onBack: () => void;
  onSave: (level: LevelConfig) => Promise<void>;
}) {
  const { target, title, level, onBack, onSave } = props;
  const [pieces, setPieces] = React.useState<LevelPiece[]>(() => level.modes.polygon?.pieces || []);
  const [selectedIds, setSelectedIds] = React.useState<string[]>([]);
  const [targetCount, setTargetCount] = React.useState(Math.max(DEFAULT_POLYGON_TARGET_COUNT, level.modes.polygon?.pieces?.length || DEFAULT_POLYGON_TARGET_COUNT));
  const [drag, setDrag] = React.useState<{ pieceId: string; pointIndex: number } | null>(null);
  const svgRef = React.useRef<SVGSVGElement | null>(null);
  const width = level.image.width || 1080;
  const height = level.image.height || 1440;

  function svgPoint(event: React.PointerEvent): Point {
    const svg = svgRef.current;
    if (!svg) return [0, 0];
    const rect = svg.getBoundingClientRect();
    return [((event.clientX - rect.left) / rect.width) * width, ((event.clientY - rect.top) / rect.height) * height];
  }

  function savePieces(nextPieces: LevelPiece[]) {
    setPieces(withNeighbors(nextPieces));
  }

  function selectPiece(id: string, additive: boolean) {
    setSelectedIds((current) => {
      if (!additive) return [id];
      return current.includes(id) ? current.filter((item) => item !== id) : [...current, id].slice(-2);
    });
  }

  function mergeSelected() {
    if (selectedIds.length !== 2) return;
    const first = pieces.find((piece) => piece.id === selectedIds[0]);
    const second = pieces.find((piece) => piece.id === selectedIds[1]);
    if (!first || !second) return;
    const merged = mergePieces(first, second);
    savePieces([...pieces.filter((piece) => piece.id !== first.id && piece.id !== second.id), merged]);
    setSelectedIds([merged.id]);
  }

  function movePoint(point: Point) {
    if (!drag) return;
    savePieces(
      pieces.map((piece) =>
        piece.id === drag.pieceId
          ? { ...piece, points: piece.points.map((candidate, index) => (index === drag.pointIndex ? point : candidate)) }
          : piece,
      ),
    );
  }

  async function save() {
    await onSave({
      ...level,
      modes: {
        ...level.modes,
        polygon: { pieces: withNeighbors(pieces), generator: { target_count: targetCount } },
        knob: { auto: true, cols: DEFAULT_KNOB_COLS, rows: DEFAULT_KNOB_ROWS, knob_size: DEFAULT_KNOB_SIZE },
        swap: { auto: true, cols: DEFAULT_SWAP_COLS, rows: DEFAULT_SWAP_ROWS },
      },
    });
  }

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
            <Input className="h-8 w-20" type="number" value={targetCount} min={4} max={80} onChange={(event) => setTargetCount(Number(event.target.value))} />
          </label>
          <Button variant="outline" onClick={() => { setPieces(generatePieces(width, height, targetCount)); setSelectedIds([]); }}>
            <Wand2 size={16} />生成
          </Button>
          <Button variant="outline" disabled={selectedIds.length !== 2} onClick={mergeSelected}>合并</Button>
          <Button onClick={() => void save()}>
            <Save size={16} />保存
          </Button>
          <Button variant="outline" onClick={onBack}>返回</Button>
        </div>
      </div>
      <div className="grid min-h-0 flex-1 grid-cols-[1fr_260px]">
        <div className="overflow-auto bg-secondary p-4">
          <div className="relative mx-auto aspect-[3/4] max-h-full max-w-[min(72vw,720px)] bg-white">
            <img className="absolute inset-0 h-full w-full object-contain" src={sourceUrl(target)} alt="" draggable={false} />
            <svg
              ref={svgRef}
              className="absolute inset-0 h-full w-full touch-none"
              viewBox={`0 0 ${width} ${height}`}
              onPointerMove={(event) => drag && movePoint(svgPoint(event))}
              onPointerUp={() => setDrag(null)}
              onPointerLeave={() => setDrag(null)}
            >
              {pieces.map((piece, index) => {
                const selected = selectedIds.includes(piece.id);
                return (
                  <g key={piece.id}>
                    <polygon
                      points={piece.points.map((point) => point.join(",")).join(" ")}
                      fill={`hsla(${(index * 47) % 360}, 74%, 62%, 0.28)`}
                      stroke={selected ? "#D9933F" : "#5A3A22"}
                      strokeWidth={selected ? 7 : 3}
                      onPointerDown={(event) => {
                        event.stopPropagation();
                        selectPiece(piece.id, event.shiftKey);
                      }}
                    />
                    {selected && piece.points.map((point, pointIndex) => (
                      <circle
                        key={pointIndex}
                        cx={point[0]}
                        cy={point[1]}
                        r={14}
                        fill="#FFF6E6"
                        stroke="#2f7667"
                        strokeWidth={7}
                        onPointerDown={(event) => {
                          event.stopPropagation();
                          setDrag({ pieceId: piece.id, pointIndex });
                        }}
                      />
                    ))}
                  </g>
                );
              })}
            </svg>
          </div>
        </div>
        <aside className="border-l border-border bg-card p-4 text-sm">
          <div className="mb-2 text-sm font-semibold text-foreground">编辑说明</div>
          <p className="mb-4 text-muted-foreground">点击碎片选择，按住 Shift 可选择两个碎片后合并。选中碎片后拖动圆点微调轮廓。</p>
          <StatusLine label="碎片数" value={String(pieces.length)} />
          <StatusLine label="已选择" value={String(selectedIds.length)} />
          <Button variant="outline" className="mt-4 w-full" onClick={() => setPieces([])}>
            <Trash2 size={16} />清空
          </Button>
        </aside>
      </div>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(<App />);
