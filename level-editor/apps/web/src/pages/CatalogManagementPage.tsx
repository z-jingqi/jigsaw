import { useEffect, useMemo, useState } from "react";
import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, arrayMove, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { Check, ChevronDown, ChevronRight, FolderPlus, GripVertical, Image as ImageIcon, Layers, Pencil, Plus, RotateCcw, Save, Trash2, Upload, X } from "lucide-react";
import { makeEmptyLevel, uid } from "../geometry";
import type { CatalogLevel, CatalogTopic, LevelCatalog, LevelConfig, ProcessStep, ProcessStepType, PythonTool } from "../types";

const defaultLocale = "zh-Hans";
const defaultStepTypes: ProcessStepType[] = ["convert_jpg", "remove_background", "trim_transparent", "compress"];

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
};

function makeDefaultCatalog(): LevelCatalog {
  return { schema: "jigsaw.catalog.v1", version: 1, default_locale: defaultLocale, locales: [defaultLocale, "en"], topics: [] };
}

function createProcessStep(type: ProcessStepType): ProcessStep {
  return { id: uid("cover_step"), type, tolerance: 35, padding: 0, quality: 88, background: "#F6EBD4" };
}

function processStepLabel(type: ProcessStepType) {
  if (type === "convert_jpg") return "转 JPG";
  if (type === "remove_background") return "去背景";
  if (type === "trim_transparent") return "裁透明边";
  return "压缩图片";
}

function fallbackPythonTool(type: ProcessStepType): PythonTool {
  return { name: `${type}.py`, label: processStepLabel(type), supported: true, description: "用于主题封面处理。", stepType: type };
}

function localized(value: Record<string, string> | undefined, locale: string, fallback: string) {
  return value?.[locale] || value?.[defaultLocale] || value?.en || fallback;
}

function normalizeOrder<T extends { sort_order: number }>(items: T[]): T[] {
  return items.map((item, index) => ({ ...item, sort_order: index }));
}

function nextSequentialId(prefix: string, existingIds: string[]): string {
  const used = new Set(existingIds);
  for (let index = 1; index < 10000; index += 1) {
    const id = `${prefix}_${String(index).padStart(2, "0")}`;
    if (!used.has(id)) return id;
  }
  return `${prefix}_${Date.now().toString(36)}`;
}

function levelKey(topicId: string, levelId: string) {
  return `${topicId}/${levelId}`;
}

function topicCoverUrl(topic: CatalogTopic) {
  if (!topic.cover) return "";
  const fileName = topic.cover.split("/").pop() || "";
  return fileName ? `/api/topics/${encodeURIComponent(topic.id)}/assets/${encodeURIComponent(fileName)}?mtime=${Date.now()}` : `/api/topics/${encodeURIComponent(topic.id)}/cover?mtime=${Date.now()}`;
}

function makeLevel(topicId: string, levelId: string, title: string, description = ""): LevelConfig {
  const blank = makeEmptyLevel();
  return {
    ...blank,
    id: levelId,
    topic_id: topicId,
    title,
    description,
    title_i18n: { [defaultLocale]: title },
    description_i18n: { [defaultLocale]: description },
    image: { ...blank.image, path: `res://levels/${topicId}/${levelId}/source.png` },
    assets: { default_image: { ...blank.image, path: `res://levels/${topicId}/${levelId}/source.png` } },
  };
}

function retargetGodotPath(value: string | undefined, oldTopicId: string, levelId: string, nextTopicId: string) {
  if (!value) return value || "";
  return value.replace(`res://levels/${oldTopicId}/${levelId}/`, `res://levels/${nextTopicId}/${levelId}/`);
}

function retargetCatalogLevel(level: CatalogLevel, oldTopicId: string, nextTopicId: string): CatalogLevel {
  return {
    ...level,
    path: retargetGodotPath(level.path, oldTopicId, level.id, nextTopicId),
    source: retargetGodotPath(level.source, oldTopicId, level.id, nextTopicId),
  };
}

function moveLevelInCatalog(topics: CatalogTopic[], activeTopicId: string, activeLevelId: string, overTopicId: string, overLevelId: string) {
  const sourceTopic = topics.find((topic) => topic.id === activeTopicId);
  const targetTopic = topics.find((topic) => topic.id === overTopicId);
  const moving = sourceTopic?.levels.find((level) => level.id === activeLevelId);
  if (!sourceTopic || !targetTopic || !moving) return topics;
  if (activeTopicId === overTopicId) {
    const oldIndex = sourceTopic.levels.findIndex((level) => level.id === activeLevelId);
    const newIndex = sourceTopic.levels.findIndex((level) => level.id === overLevelId);
    if (oldIndex < 0 || newIndex < 0) return topics;
    return topics.map((topic) => (topic.id === activeTopicId ? { ...topic, levels: normalizeOrder(arrayMove(topic.levels, oldIndex, newIndex)) } : topic));
  }
  const nextMoving = retargetCatalogLevel(moving, activeTopicId, overTopicId);
  return topics.map((topic) => {
    if (topic.id === activeTopicId) return { ...topic, levels: normalizeOrder(topic.levels.filter((level) => level.id !== activeLevelId)) };
    if (topic.id !== overTopicId) return topic;
    const insertIndex = overLevelId ? topic.levels.findIndex((level) => level.id === overLevelId) : -1;
    const levels = [...topic.levels];
    levels.splice(insertIndex >= 0 ? insertIndex : levels.length, 0, nextMoving);
    return { ...topic, levels: normalizeOrder(levels) };
  });
}

function moveLevelDraft(drafts: Record<string, LevelConfig>, activeTopicId: string, activeLevelId: string, overTopicId: string) {
  const oldKey = levelKey(activeTopicId, activeLevelId);
  const draft = drafts[oldKey];
  if (!draft) return drafts;
  const nextKey = levelKey(overTopicId, activeLevelId);
  const nextDraft: LevelConfig = {
    ...draft,
    topic_id: overTopicId,
    image: { ...draft.image, path: retargetGodotPath(draft.image.path, activeTopicId, activeLevelId, overTopicId) },
    assets: draft.assets?.default_image
      ? {
          ...draft.assets,
          default_image: {
            ...draft.assets.default_image,
            path: retargetGodotPath(draft.assets.default_image.path, activeTopicId, activeLevelId, overTopicId),
          },
        }
      : draft.assets,
  };
  const { [oldKey]: _removed, ...rest } = drafts;
  return { ...rest, [nextKey]: nextDraft };
}

function CatalogManagementPage({ onUnsavedChange }: Props) {
  const [catalog, setCatalog] = useState<LevelCatalog>(() => makeDefaultCatalog());
  const [locale, setLocale] = useState(defaultLocale);
  const [selectedTopicId, setSelectedTopicId] = useState("");
  const [selectedLevelId, setSelectedLevelId] = useState("");
  const [collapsedTopics, setCollapsedTopics] = useState<Set<string>>(() => new Set());
  const [treeEditMode, setTreeEditMode] = useState(false);
  const [selectedTopicIds, setSelectedTopicIds] = useState<Set<string>>(() => new Set());
  const [selectedLevelKeys, setSelectedLevelKeys] = useState<Set<string>>(() => new Set());
  const [editingTopicId, setEditingTopicId] = useState("");
  const [editingLevelKey, setEditingLevelKey] = useState("");
  const [levelDrafts, setLevelDrafts] = useState<Record<string, LevelConfig>>({});
  const [pythonTools, setPythonTools] = useState<PythonTool[]>([]);
  const [coverSteps, setCoverSteps] = useState<ProcessStep[]>(() => defaultStepTypes.map(createProcessStep));
  const [createDialog, setCreateDialog] = useState<"topic" | "level" | null>(null);
  const [newTopicName, setNewTopicName] = useState("新主题");
  const [newLevelTitle, setNewLevelTitle] = useState("新关卡");
  const [newLevelDescription, setNewLevelDescription] = useState("");
  const [newLevelTopicId, setNewLevelTopicId] = useState("");
  const [saving, setSaving] = useState(false);
  const [processingCover, setProcessingCover] = useState(false);
  const [message, setMessage] = useState("");
  const [dirty, setDirty] = useState(false);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  const selectedTopic = useMemo(() => catalog.topics.find((topic) => topic.id === selectedTopicId), [catalog.topics, selectedTopicId]);
  const selectedLevel = useMemo(() => selectedTopic?.levels.find((level) => level.id === selectedLevelId), [selectedLevelId, selectedTopic]);
  const selectedLevelDraft = selectedTopic && selectedLevel ? levelDrafts[levelKey(selectedTopic.id, selectedLevel.id)] : undefined;
  const hasTreeSelection = selectedTopicIds.size > 0 || selectedLevelKeys.size > 0;

  useEffect(() => {
    void resetFromGodot();
    void loadPythonTools();
  }, []);

  useEffect(() => () => onUnsavedChange?.(false), [onUnsavedChange]);

  useEffect(() => {
    onUnsavedChange?.(dirty);
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (!dirty) return;
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirty, onUnsavedChange]);

  useEffect(() => {
    if (!selectedTopicId && catalog.topics[0]) setSelectedTopicId(catalog.topics[0].id);
    if (selectedTopicId && selectedTopic && !selectedLevelId && selectedTopic.levels[0]) setSelectedLevelId(selectedTopic.levels[0].id);
  }, [catalog.topics, selectedLevelId, selectedTopic, selectedTopicId]);

  useEffect(() => {
    if (!selectedTopic || !selectedLevel) return;
    const key = levelKey(selectedTopic.id, selectedLevel.id);
    if (levelDrafts[key]) return;
    void loadLevelDraft(selectedTopic.id, selectedLevel.id, selectedLevel);
  }, [levelDrafts, selectedLevel, selectedTopic]);

  useEffect(() => {
    if (treeEditMode) return;
    setSelectedTopicIds(new Set());
    setSelectedLevelKeys(new Set());
    setEditingTopicId("");
    setEditingLevelKey("");
  }, [treeEditMode]);

  async function resetFromGodot() {
    try {
      const response = await fetch("/api/catalog");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelCatalog;
      const nextCatalog = {
        ...makeDefaultCatalog(),
        ...data,
        topics: normalizeOrder((data.topics || []).map((topic) => ({ ...topic, levels: normalizeOrder(topic.levels || []) }))),
      };
      setCatalog(nextCatalog);
      setLocale(nextCatalog.default_locale || nextCatalog.locales[0] || defaultLocale);
      setSelectedTopicId(nextCatalog.topics[0]?.id || "");
      setSelectedLevelId(nextCatalog.topics[0]?.levels[0]?.id || "");
      setLevelDrafts({});
      setDirty(false);
      setMessage("已从 Godot 关卡重置。");
    } catch (error) {
      setMessage(error instanceof Error ? `重置失败：${error.message}` : "重置失败");
    }
  }

  async function loadPythonTools() {
    try {
      const response = await fetch("/api/python-tools");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { tools?: PythonTool[] };
      setPythonTools(data.tools || []);
    } catch {
      setPythonTools([]);
    }
  }

  async function loadLevelDraft(topicId: string, levelId: string, catalogLevel: CatalogLevel) {
    const key = levelKey(topicId, levelId);
    try {
      const response = await fetch(`/api/levels/${topicId}/${levelId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelConfig;
      setLevelDrafts((current) => ({ ...current, [key]: data }));
    } catch {
      setLevelDrafts((current) => ({ ...current, [key]: makeLevel(topicId, levelId, catalogLevel.title) }));
    }
  }

  function updateSelectedTopic(patch: Partial<CatalogTopic>) {
    if (!selectedTopic) return;
    setDirty(true);
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) => (topic.id === selectedTopic.id ? { ...topic, ...patch } : topic)),
    }));
  }

  function updateSelectedLevel(patch: Partial<CatalogLevel>) {
    if (!selectedTopic || !selectedLevel) return;
    setDirty(true);
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) =>
        topic.id === selectedTopic.id
          ? { ...topic, levels: topic.levels.map((level) => (level.id === selectedLevel.id ? { ...level, ...patch } : level)) }
          : topic,
      ),
    }));
  }

  function updateSelectedLevelDraft(patch: Partial<LevelConfig>) {
    if (!selectedTopic || !selectedLevel) return;
    setDirty(true);
    const key = levelKey(selectedTopic.id, selectedLevel.id);
    setLevelDrafts((current) => {
      const existing = current[key] || makeLevel(selectedTopic.id, selectedLevel.id, selectedLevel.title);
      return { ...current, [key]: { ...existing, ...patch } };
    });
  }

  function renameTopic(topicId: string, name: string) {
    const cleanName = name.trim();
    if (!cleanName) {
      setEditingTopicId("");
      return;
    }
    setDirty(true);
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) =>
        topic.id === topicId ? { ...topic, name: cleanName, name_i18n: { ...(topic.name_i18n || {}), [locale]: cleanName } } : topic,
      ),
    }));
    setEditingTopicId("");
  }

  function renameLevel(topicId: string, levelId: string, title: string) {
    const cleanTitle = title.trim();
    if (!cleanTitle) {
      setEditingLevelKey("");
      return;
    }
    setDirty(true);
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) =>
        topic.id === topicId
          ? {
              ...topic,
              levels: topic.levels.map((level) =>
                level.id === levelId ? { ...level, title: cleanTitle, title_i18n: { ...(level.title_i18n || {}), [locale]: cleanTitle } } : level,
              ),
            }
          : topic,
      ),
    }));
    const key = levelKey(topicId, levelId);
    setLevelDrafts((current) => {
      const existing = current[key];
      if (!existing) return current;
      return { ...current, [key]: { ...existing, title: cleanTitle, title_i18n: { ...(existing.title_i18n || {}), [locale]: cleanTitle } } };
    });
    setEditingLevelKey("");
  }

  function toggleTopicSelection(topic: CatalogTopic, checked: boolean) {
    setSelectedTopicIds((current) => {
      const next = new Set(current);
      if (checked) next.add(topic.id);
      else next.delete(topic.id);
      return next;
    });
    setSelectedLevelKeys((current) => {
      const next = new Set(current);
      for (const level of topic.levels) {
        const key = levelKey(topic.id, level.id);
        if (checked) next.add(key);
        else next.delete(key);
      }
      return next;
    });
  }

  function toggleLevelSelection(topic: CatalogTopic, level: CatalogLevel, checked: boolean) {
    const key = levelKey(topic.id, level.id);
    setSelectedLevelKeys((current) => {
      const next = new Set(current);
      if (checked) next.add(key);
      else next.delete(key);
      setSelectedTopicIds((topics) => {
        const selectedTopics = new Set(topics);
        const allSelected = topic.levels.length > 0 && topic.levels.every((item) => next.has(levelKey(topic.id, item.id)));
        if (allSelected) selectedTopics.add(topic.id);
        else selectedTopics.delete(topic.id);
        return selectedTopics;
      });
      return next;
    });
  }

  function deleteSelectedTreeItems() {
    if (!hasTreeSelection) return;
    if (!window.confirm("删除选中的主题和关卡？")) return;
    setDirty(true);
    const removedTopicIds = new Set(selectedTopicIds);
    const removedLevelKeys = new Set(selectedLevelKeys);
    setLevelDrafts((current) =>
      Object.fromEntries(Object.entries(current).filter(([key]) => {
        const [topicId] = key.split("/");
        return !removedTopicIds.has(topicId) && !removedLevelKeys.has(key);
      })),
    );
    setCatalog((current) => {
      const topics = normalizeOrder(
        current.topics
          .filter((topic) => !removedTopicIds.has(topic.id))
          .map((topic) => ({ ...topic, levels: normalizeOrder(topic.levels.filter((level) => !removedLevelKeys.has(levelKey(topic.id, level.id)))) })),
      );
      window.setTimeout(() => {
        const activeTopic = topics.find((topic) => topic.id === selectedTopicId) || topics[0];
        const activeLevel = activeTopic?.levels.find((level) => level.id === selectedLevelId) || activeTopic?.levels[0];
        setSelectedTopicId(activeTopic?.id || "");
        setSelectedLevelId(activeLevel?.id || "");
      }, 0);
      return { ...current, topics };
    });
    setSelectedTopicIds(new Set());
    setSelectedLevelKeys(new Set());
  }

  function openCreateTopic() {
    setNewTopicName("新主题");
    setCreateDialog("topic");
  }

  function openCreateLevel() {
    setNewLevelTitle("新关卡");
    setNewLevelDescription("");
    setNewLevelTopicId(selectedTopic?.id || catalog.topics[0]?.id || "");
    setCreateDialog("level");
  }

  function createTopic() {
    const name = newTopicName.trim() || "新主题";
    const id = nextSequentialId("topic", catalog.topics.map((topic) => topic.id));
    const topic: CatalogTopic = { id, name, name_i18n: { [locale]: name }, sort_order: catalog.topics.length, cover: "", levels: [] };
    setDirty(true);
    setCatalog((current) => ({ ...current, topics: normalizeOrder([...current.topics, topic]) }));
    setSelectedTopicId(id);
    setSelectedLevelId("");
    setCreateDialog(null);
  }

  function createLevel() {
    const topic = catalog.topics.find((item) => item.id === newLevelTopicId) || selectedTopic || catalog.topics[0];
    if (!topic) return;
    const id = nextSequentialId("level", topic.levels.map((level) => level.id));
    const title = newLevelTitle.trim() || "新关卡";
    const description = newLevelDescription.trim();
    const level: CatalogLevel = {
      id,
      title,
      title_i18n: { [locale]: title },
      sort_order: topic.levels.length,
      path: `res://levels/${topic.id}/${id}/level.json`,
      source: `res://levels/${topic.id}/${id}/source.png`,
    };
    setDirty(true);
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((candidate) => (candidate.id === topic.id ? { ...candidate, levels: normalizeOrder([...candidate.levels, level]) } : candidate)),
    }));
    setLevelDrafts((current) => ({ ...current, [levelKey(topic.id, id)]: makeLevel(topic.id, id, title, description) }));
    setSelectedTopicId(topic.id);
    setSelectedLevelId(id);
    setCollapsedTopics((current) => {
      const next = new Set(current);
      next.delete(topic.id);
      return next;
    });
    setCreateDialog(null);
  }

  function deleteSelectedTopic() {
    if (!selectedTopic) return;
    if (!window.confirm(`删除主题「${localized(selectedTopic.name_i18n, locale, selectedTopic.name)}」？主题下的关卡也会移除。`)) return;
    setDirty(true);
    const removedKeys = new Set(selectedTopic.levels.map((level) => levelKey(selectedTopic.id, level.id)));
    setLevelDrafts((current) => Object.fromEntries(Object.entries(current).filter(([key]) => !removedKeys.has(key))));
    setCatalog((current) => {
      const topics = normalizeOrder(current.topics.filter((topic) => topic.id !== selectedTopic.id));
      window.setTimeout(() => {
        setSelectedTopicId(topics[0]?.id || "");
        setSelectedLevelId(topics[0]?.levels[0]?.id || "");
      }, 0);
      return { ...current, topics };
    });
  }

  function deleteSelectedLevel() {
    if (!selectedTopic || !selectedLevel) return;
    if (!window.confirm(`删除关卡「${localized(selectedLevel.title_i18n, locale, selectedLevel.title)}」？`)) return;
    setDirty(true);
    setLevelDrafts((current) => Object.fromEntries(Object.entries(current).filter(([key]) => key !== levelKey(selectedTopic.id, selectedLevel.id))));
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((topic) => {
        if (topic.id !== selectedTopic.id) return topic;
        const levels = normalizeOrder(topic.levels.filter((level) => level.id !== selectedLevel.id));
        window.setTimeout(() => setSelectedLevelId(levels[0]?.id || ""), 0);
        return { ...topic, levels };
      }),
    }));
  }

  function toggleTopic(topicId: string) {
    setCollapsedTopics((current) => {
      const next = new Set(current);
      if (next.has(topicId)) next.delete(topicId);
      else next.add(topicId);
      return next;
    });
  }

  function selectLevel(topicId: string, levelId: string) {
    setSelectedTopicId(topicId);
    setSelectedLevelId(levelId);
    setCollapsedTopics((current) => {
      const next = new Set(current);
      next.delete(topicId);
      return next;
    });
  }

  function onDragEnd(event: DragEndEvent) {
    const activeId = String(event.active.id);
    const overId = event.over ? String(event.over.id) : "";
    if (!overId || activeId === overId) return;
    if (activeId.startsWith("topic:") && overId.startsWith("topic:")) {
      const activeTopic = activeId.slice(6);
      const overTopic = overId.slice(6);
      setDirty(true);
      setCatalog((current) => {
        const oldIndex = current.topics.findIndex((topic) => topic.id === activeTopic);
        const newIndex = current.topics.findIndex((topic) => topic.id === overTopic);
        if (oldIndex < 0 || newIndex < 0) return current;
        return { ...current, topics: normalizeOrder(arrayMove(current.topics, oldIndex, newIndex)) };
      });
      return;
    }
    if (activeId.startsWith("level:")) {
      const [, activeTopic, activeLevel] = activeId.split(":");
      const overParts = overId.split(":");
      const overTopic = overParts[0] === "topic" ? overParts[1] : overParts[1];
      const overLevel = overParts[0] === "level" ? overParts[2] : "";
      if (!overTopic) return;
      setDirty(true);
      setCatalog((current) => ({
        ...current,
        topics: moveLevelInCatalog(current.topics, activeTopic, activeLevel, overTopic, overLevel),
      }));
      if (activeTopic !== overTopic) {
        setSelectedTopicId(overTopic);
        setSelectedLevelId(activeLevel);
        setSelectedLevelKeys((current) => {
          const next = new Set(current);
          const oldKey = levelKey(activeTopic, activeLevel);
          if (next.has(oldKey)) {
            next.delete(oldKey);
            next.add(levelKey(overTopic, activeLevel));
          }
          return next;
        });
        setSelectedTopicIds((current) => {
          const next = new Set(current);
          next.delete(activeTopic);
          next.delete(overTopic);
          return next;
        });
        setCollapsedTopics((current) => {
          const next = new Set(current);
          next.delete(overTopic);
          return next;
        });
        setLevelDrafts((current) => moveLevelDraft(current, activeTopic, activeLevel, overTopic));
      }
    }
  }

  async function uploadCover(file?: File) {
    if (!file || !selectedTopic) return;
    const form = new FormData();
    form.append("cover", file);
    try {
      const response = await fetch(`/api/topics/${selectedTopic.id}/cover`, { method: "POST", body: form });
      const data = (await response.json()) as { ok?: boolean; godotPath?: string; error?: string };
      if (!response.ok || !data.ok || !data.godotPath) throw new Error(data.error || `HTTP ${response.status}`);
      updateSelectedTopic({ cover: data.godotPath });
      setDirty(true);
      setMessage("封面已上传。");
    } catch (error) {
      setMessage(error instanceof Error ? `上传封面失败：${error.message}` : "上传封面失败");
    }
  }

  async function processCover() {
    if (!selectedTopic?.cover) {
      setMessage("请先上传主题封面。");
      return;
    }
    setProcessingCover(true);
    try {
      const response = await fetch(`/api/topics/${selectedTopic.id}/cover/process`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ coverPath: selectedTopic.cover, steps: coverSteps.map(({ id: _id, ...step }) => step) }),
      });
      const data = (await response.json()) as { ok?: boolean; godotPath?: string; error?: string };
      if (!response.ok || !data.ok || !data.godotPath) throw new Error(data.error || `HTTP ${response.status}`);
      updateSelectedTopic({ cover: data.godotPath });
      setDirty(true);
      setMessage("封面处理完成。");
    } catch (error) {
      setMessage(error instanceof Error ? `处理封面失败：${error.message}` : "处理封面失败");
    } finally {
      setProcessingCover(false);
    }
  }

  async function saveToGodot() {
    setSaving(true);
    try {
      const catalogResponse = await fetch("/api/catalog", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(catalog),
      });
      const catalogData = (await catalogResponse.json()) as { ok?: boolean; error?: string };
      if (!catalogResponse.ok || !catalogData.ok) throw new Error(catalogData.error || `HTTP ${catalogResponse.status}`);
      for (const [key, draft] of Object.entries(levelDrafts)) {
        const [topicId, levelId] = key.split("/");
        const response = await fetch(`/api/levels/${topicId}/${levelId}`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ level: draft, catalog }),
        });
        const data = (await response.json()) as { ok?: boolean; error?: string };
        if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      }
      setDirty(false);
      setMessage("关卡信息已保存到 Godot。");
    } catch (error) {
      setMessage(error instanceof Error ? `保存失败：${error.message}` : "保存失败");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid h-full min-h-0 grid-cols-[360px_1fr_360px] overflow-hidden bg-linen text-ink">
      <aside className="min-h-0 overflow-auto border-r border-stone-300 bg-paper p-4">
        <div className="flex items-start gap-3 border-b border-stone-300 pb-4">
          <Layers className="mt-1 text-clay" size={22} />
          <div>
            <h1 className="text-xl font-semibold">关卡管理</h1>
            <p className="text-sm text-muted">主题 / 关卡 / 封面</p>
          </div>
        </div>
        <section className="mt-5 grid gap-3">
          <div className="flex items-center justify-between gap-2">
            <PanelTitle>关卡树</PanelTitle>
            <div className="flex items-center gap-2">
              <button className="iconBtn" onClick={() => void resetFromGodot()} title="从 Godot 重置">
                <RotateCcw size={16} />
              </button>
              <button className={treeEditMode ? "iconBtnActive" : "iconBtn"} onClick={() => setTreeEditMode((current) => !current)} title={treeEditMode ? "退出编辑模式" : "编辑关卡树"}>
                <Pencil size={16} />
              </button>
              {treeEditMode && hasTreeSelection && (
                <button className="iconBtnDanger" onClick={deleteSelectedTreeItems} title="删除选中">
                  <Trash2 size={16} />
                </button>
              )}
              <button className="iconBtn" onClick={openCreateTopic} title="创建主题">
                <FolderPlus size={16} />
              </button>
              <button className="iconBtn" disabled={!catalog.topics.length} onClick={openCreateLevel} title="创建关卡">
                <Plus size={16} />
              </button>
            </div>
          </div>
          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
            <SortableContext items={catalog.topics.map((topic) => `topic:${topic.id}`)} strategy={verticalListSortingStrategy}>
              <div className="grid max-h-[calc(100vh-210px)] gap-3 overflow-auto pr-1">
                {catalog.topics.map((topic) => (
                  <TopicTree
                    key={topic.id}
                    topic={topic}
                    locale={locale}
                    collapsed={collapsedTopics.has(topic.id)}
                    selectedTopicId={selectedTopicId}
                    selectedLevelId={selectedLevelId}
                    editMode={treeEditMode}
                    selectedTopicIds={selectedTopicIds}
                    selectedLevelKeys={selectedLevelKeys}
                    editingTopicId={editingTopicId}
                    editingLevelKey={editingLevelKey}
                    onToggle={() => toggleTopic(topic.id)}
                    onSelectTopic={() => {
                      setSelectedTopicId(topic.id);
                      setSelectedLevelId(topic.levels[0]?.id || "");
                    }}
                    onSelectLevel={selectLevel}
                    onToggleTopicSelection={toggleTopicSelection}
                    onToggleLevelSelection={toggleLevelSelection}
                    onStartRenameTopic={setEditingTopicId}
                    onStartRenameLevel={setEditingLevelKey}
                    onRenameTopic={renameTopic}
                    onRenameLevel={renameLevel}
                  />
                ))}
                {!catalog.topics.length && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无主题。</div>}
              </div>
            </SortableContext>
          </DndContext>
        </section>
      </aside>

      <main className="min-h-0 overflow-auto p-6">
        <div className="mx-auto grid max-w-3xl gap-5">
          <section className="grid gap-3">
            <PanelTitle>主题</PanelTitle>
            {selectedTopic ? (
              <>
                <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-ink">
                  {localized(selectedTopic.name_i18n, locale, selectedTopic.name)}
                </div>
                <Field label="语言">
                  <select className="input" value={locale} onChange={(event) => setLocale(event.target.value)}>
                    {catalog.locales.map((item) => (
                      <option key={item} value={item}>{item}</option>
                    ))}
                  </select>
                </Field>
              </>
            ) : (
              <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">请选择或创建主题。</div>
            )}
          </section>

          <section className="grid gap-3">
            <PanelTitle>关卡信息</PanelTitle>
            {selectedTopic && selectedLevel ? (
              <>
                <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-ink">
                  {localized(selectedLevel.title_i18n, locale, selectedLevel.title)}
                </div>
                <Field label="介绍">
                  <textarea
                    className="input min-h-32"
                    value={localized(selectedLevelDraft?.description_i18n, locale, selectedLevelDraft?.description || "")}
                    onChange={(event) => {
                      const description = event.target.value;
                      updateSelectedLevelDraft({ description, description_i18n: { ...(selectedLevelDraft?.description_i18n || {}), [locale]: description } });
                    }}
                  />
                </Field>
                <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-muted">
                  {selectedTopic.id} / {selectedLevel.id}
                </div>
              </>
            ) : (
              <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">请选择或创建关卡。</div>
            )}
          </section>
        </div>
      </main>

      <aside className="min-h-0 overflow-auto border-l border-stone-300 bg-paper p-4">
        <section className="grid gap-3">
          <PanelTitle>主题封面</PanelTitle>
          {selectedTopic?.cover ? (
            <div className="overflow-hidden rounded-md border border-stone-300 bg-white">
              <img className="max-h-56 w-full object-contain" src={topicCoverUrl(selectedTopic)} alt="主题封面" />
            </div>
          ) : (
            <div className="grid min-h-32 place-items-center rounded-md border border-dashed border-stone-300 bg-white/70 text-sm text-muted">暂无封面</div>
          )}
          <label className="fileButton">
            <Upload size={16} />
            上传封面
            <input hidden type="file" accept="image/*" onChange={(event) => void uploadCover(event.target.files?.[0])} />
          </label>
        </section>

        <section className="mt-5 grid gap-3 border-t border-stone-300 pt-4">
          <div className="flex items-center justify-between gap-2">
            <PanelTitle>封面处理</PanelTitle>
            <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={() => setCoverSteps(defaultStepTypes.map(createProcessStep))}>
              <RotateCcw size={14} />
              默认
            </button>
          </div>
          {coverSteps.map((step) => (
            <CoverStepRow
              key={step.id}
              step={step}
              tool={pythonTools.find((tool) => tool.stepType === step.type) || fallbackPythonTool(step.type)}
              onUpdate={(patch) => setCoverSteps((current) => current.map((item) => (item.id === step.id ? { ...item, ...patch } : item)))}
              onEnabledChange={(checked) => {
                if (!checked) setCoverSteps((current) => current.filter((item) => item.id !== step.id));
              }}
            />
          ))}
          <button className="btnPrimary" disabled={!selectedTopic?.cover || processingCover} onClick={() => void processCover()}>
            <ImageIcon size={16} />
            {processingCover ? "处理中..." : "处理封面"}
          </button>
        </section>

        <section className="mt-5 grid gap-3 border-t border-stone-300 pt-4">
          <button className="btnPrimary" disabled={saving} onClick={() => void saveToGodot()}>
            <Save size={16} />
            {saving ? "保存中..." : "保存到 Godot"}
          </button>
          {message && <div className="rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-ink">{message}</div>}
        </section>
      </aside>
      {createDialog && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
          <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
            <div className="flex items-start justify-between gap-4">
              <h2 className="text-lg font-semibold">{createDialog === "topic" ? "创建主题" : "创建关卡"}</h2>
              <button className="iconBtn !min-h-8" onClick={() => setCreateDialog(null)} aria-label="关闭">
                <X size={16} />
              </button>
            </div>
            <div className="mt-4 grid gap-3">
              {createDialog === "topic" ? (
                <Field label="主题名">
                  <input className="input" autoFocus value={newTopicName} onChange={(event) => setNewTopicName(event.target.value)} onKeyDown={(event) => {
                    if (event.key === "Enter") createTopic();
                  }} />
                </Field>
              ) : (
                <>
                  <Field label="主题">
                    <select className="input" value={newLevelTopicId} onChange={(event) => setNewLevelTopicId(event.target.value)}>
                      {catalog.topics.map((topic) => (
                        <option key={topic.id} value={topic.id}>{localized(topic.name_i18n, locale, topic.name)}</option>
                      ))}
                    </select>
                  </Field>
                  <Field label="关卡名">
                    <input className="input" autoFocus value={newLevelTitle} onChange={(event) => setNewLevelTitle(event.target.value)} />
                  </Field>
                  <Field label="介绍">
                    <textarea className="input min-h-24" value={newLevelDescription} onChange={(event) => setNewLevelDescription(event.target.value)} />
                  </Field>
                </>
              )}
              <div className="mt-2 grid grid-cols-2 gap-2">
                <button className="btn" onClick={() => setCreateDialog(null)}>取消</button>
                <button className="btnPrimary" onClick={createDialog === "topic" ? createTopic : createLevel}>
                  <Check size={16} />
                  创建
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function TopicTree({
  topic,
  locale,
  collapsed,
  selectedTopicId,
  selectedLevelId,
  editMode,
  selectedTopicIds,
  selectedLevelKeys,
  editingTopicId,
  editingLevelKey,
  onToggle,
  onSelectTopic,
  onSelectLevel,
  onToggleTopicSelection,
  onToggleLevelSelection,
  onStartRenameTopic,
  onStartRenameLevel,
  onRenameTopic,
  onRenameLevel,
}: {
  topic: CatalogTopic;
  locale: string;
  collapsed: boolean;
  selectedTopicId: string;
  selectedLevelId: string;
  editMode: boolean;
  selectedTopicIds: Set<string>;
  selectedLevelKeys: Set<string>;
  editingTopicId: string;
  editingLevelKey: string;
  onToggle: () => void;
  onSelectTopic: () => void;
  onSelectLevel: (topicId: string, levelId: string) => void;
  onToggleTopicSelection: (topic: CatalogTopic, checked: boolean) => void;
  onToggleLevelSelection: (topic: CatalogTopic, level: CatalogLevel, checked: boolean) => void;
  onStartRenameTopic: (topicId: string) => void;
  onStartRenameLevel: (key: string) => void;
  onRenameTopic: (topicId: string, name: string) => void;
  onRenameLevel: (topicId: string, levelId: string, title: string) => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: `topic:${topic.id}` });
  const allLevelsSelected = topic.levels.length > 0 && topic.levels.every((level) => selectedLevelKeys.has(levelKey(topic.id, level.id)));
  const topicChecked = selectedTopicIds.has(topic.id) || allLevelsSelected;
  return (
    <section ref={setNodeRef} className={`rounded-md border border-stone-300 bg-white/70 p-2 ${isDragging ? "opacity-70" : ""}`} style={{ transform: CSS.Transform.toString(transform), transition }}>
      <div className="mb-2 flex items-center gap-2">
        <button className="iconBtn !min-h-7 border-0 bg-transparent px-1 py-1 shadow-none" onClick={onToggle} aria-label={collapsed ? "展开主题" : "收起主题"}>
          {collapsed ? <ChevronRight size={16} /> : <ChevronDown size={16} />}
        </button>
        {editMode && (
          <input
            className="h-4 w-4 shrink-0 accent-clay"
            type="checkbox"
            checked={topicChecked}
            onChange={(event) => onToggleTopicSelection(topic, event.target.checked)}
          />
        )}
        <button className="iconBtn !min-h-7 cursor-grab border-0 bg-transparent px-1 py-1 shadow-none active:cursor-grabbing" {...attributes} {...listeners} aria-label="拖拽主题">
          <GripVertical size={15} />
        </button>
        <div className="min-w-0 flex-1" onClick={onSelectTopic}>
          <InlineTreeName
            value={localized(topic.name_i18n, locale, topic.name)}
            active={topic.id === selectedTopicId}
            editMode={editMode}
            editing={editingTopicId === topic.id}
            onStart={() => onStartRenameTopic(topic.id)}
            onCommit={(value) => onRenameTopic(topic.id, value)}
          />
        </div>
        <small className="text-muted">{topic.levels.length}</small>
      </div>
      {!collapsed && (
        <SortableContext items={topic.levels.map((level) => `level:${topic.id}:${level.id}`)} strategy={verticalListSortingStrategy}>
          <div className="grid gap-2">
            {topic.levels.map((level) => (
              <LevelTreeRow
                key={level.id}
                topicId={topic.id}
                level={level}
                locale={locale}
                editMode={editMode}
                checked={selectedLevelKeys.has(levelKey(topic.id, level.id))}
                editing={editingLevelKey === levelKey(topic.id, level.id)}
                active={topic.id === selectedTopicId && level.id === selectedLevelId}
                onSelect={() => onSelectLevel(topic.id, level.id)}
                onToggle={(checked) => onToggleLevelSelection(topic, level, checked)}
                onStartRename={() => onStartRenameLevel(levelKey(topic.id, level.id))}
                onRename={(value) => onRenameLevel(topic.id, level.id, value)}
              />
            ))}
            {!topic.levels.length && <div className="rounded border border-dashed border-stone-200 px-3 py-2 text-xs text-muted">暂无关卡</div>}
          </div>
        </SortableContext>
      )}
    </section>
  );
}

function LevelTreeRow({
  topicId,
  level,
  locale,
  editMode,
  checked,
  editing,
  active,
  onSelect,
  onToggle,
  onStartRename,
  onRename,
}: {
  topicId: string;
  level: CatalogLevel;
  locale: string;
  editMode: boolean;
  checked: boolean;
  editing: boolean;
  active: boolean;
  onSelect: () => void;
  onToggle: (checked: boolean) => void;
  onStartRename: () => void;
  onRename: (value: string) => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: `level:${topicId}:${level.id}` });
  return (
    <div ref={setNodeRef} className={`${active ? "objectActive" : "object"} ${isDragging ? "opacity-70" : ""}`} style={{ transform: CSS.Transform.toString(transform), transition }}>
      {editMode && (
        <input
          className="h-4 w-4 shrink-0 accent-clay"
          type="checkbox"
          checked={checked}
          onClick={(event) => event.stopPropagation()}
          onChange={(event) => onToggle(event.target.checked)}
        />
      )}
      <button className="cursor-grab text-muted active:cursor-grabbing" {...attributes} {...listeners} aria-label="拖拽关卡">
        <GripVertical size={15} />
      </button>
      <div className="min-w-0 flex-1" onClick={onSelect}>
        <InlineTreeName
          value={localized(level.title_i18n, locale, level.title)}
          active={active}
          editMode={editMode}
          editing={editing}
          onStart={onStartRename}
          onCommit={onRename}
        />
      </div>
    </div>
  );
}

function InlineTreeName({
  value,
  active,
  editMode,
  editing,
  onStart,
  onCommit,
}: {
  value: string;
  active: boolean;
  editMode: boolean;
  editing: boolean;
  onStart: () => void;
  onCommit: (value: string) => void;
}) {
  const [draft, setDraft] = useState(value);

  useEffect(() => {
    if (editing) setDraft(value);
  }, [editing, value]);

  if (editing) {
    return (
      <input
        className="input h-8 min-w-0 px-2 py-1"
        autoFocus
        value={draft}
        onClick={(event) => event.stopPropagation()}
        onMouseDown={(event) => event.stopPropagation()}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={() => onCommit(draft)}
        onKeyDown={(event) => {
          if (event.key === "Enter") event.currentTarget.blur();
          if (event.key === "Escape") {
            event.preventDefault();
            onCommit(value);
          }
        }}
      />
    );
  }

  return (
    <span className="group/rename flex min-w-0 items-center gap-1 text-sm">
      <span className={`min-w-0 flex-1 truncate text-left font-medium ${active ? "text-clay" : "text-ink"}`}>{value}</span>
      {editMode && (
        <button
          className="editReveal shrink-0 rounded p-1 text-muted transition hover:bg-stone-100 hover:text-clay"
          onClick={(event) => {
            event.stopPropagation();
            onStart();
          }}
          aria-label={`重命名 ${value}`}
          title="重命名"
        >
          <Pencil size={13} />
        </button>
      )}
    </span>
  );
}

function CoverStepRow({
  step,
  tool,
  onUpdate,
  onEnabledChange,
}: {
  step: ProcessStep;
  tool: PythonTool;
  onUpdate: (patch: Partial<ProcessStep>) => void;
  onEnabledChange: (checked: boolean) => void;
}) {
  return (
    <div className="rounded-md border border-stone-300 bg-white p-2 text-sm">
      <label className="flex items-center gap-2">
        <input className="h-4 w-4 accent-clay" type="checkbox" checked onChange={(event) => onEnabledChange(event.target.checked)} />
        <span className="min-w-0 flex-1 font-medium">{tool.label}</span>
      </label>
      {step.type === "remove_background" && (
        <Field label="容差">
          <input className="input" type="number" min="0" max="441" value={step.tolerance} onChange={(event) => onUpdate({ tolerance: Number(event.target.value) })} />
        </Field>
      )}
      {step.type === "trim_transparent" && (
        <Field label="留边">
          <input className="input" type="number" min="0" max="256" value={step.padding} onChange={(event) => onUpdate({ padding: Number(event.target.value) })} />
        </Field>
      )}
      {(step.type === "convert_jpg" || step.type === "compress") && (
        <Field label="质量">
          <input className="input" type="number" min="1" max="100" value={step.quality} onChange={(event) => onUpdate({ quality: Number(event.target.value) })} />
        </Field>
      )}
      {step.type === "convert_jpg" && (
        <Field label="底色">
          <input className="input h-10 p-1" type="color" value={step.background} onChange={(event) => onUpdate({ background: event.target.value })} />
        </Field>
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

export default CatalogManagementPage;
