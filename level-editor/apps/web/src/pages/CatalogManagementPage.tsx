import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, arrayMove, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { Check, FolderPlus, Hexagon, Image as ImageIcon, Layers, Link2, Pencil, Plus, Puzzle, RotateCcw, Save, Trash2, Upload, X } from "lucide-react";
import { toast } from "sonner";
import { makeEmptyLevel } from "../geometry";
import type { CatalogLevel, CatalogTopic, LevelCatalog, LevelConfig, LevelImageConfig, PendingImageItem, ProcessStep, ProcessStepType, PythonTool } from "../types";
import { CoverStepRow } from "../features/catalog/components/CoverStepRow";
import { TopicTree } from "../features/catalog/components/TopicTree";
import { Field } from "../shared/ui/Field";
import { PanelTitle } from "../shared/ui/PanelTitle";
import { SelectBox } from "../shared/ui/SelectBox";
import { ToggleGroup, ToggleGroupItem } from "../components/ui/toggle-group";
import { WithTooltip } from "../components/ui/tooltip";
import { makeDefaultCatalog, normalizeOrder, retargetCatalogLevel, retargetGodotPath, topicCoverUrl } from "../shared/lib/catalog";
import { idFromEnglishName, levelKey, nextSequentialId } from "../shared/lib/ids";
import { defaultLocale, localized } from "../shared/lib/i18n";
import { createProcessStep, defaultStepTypes, fallbackPythonTool } from "../shared/lib/processSteps";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "../components/ui/alert-dialog";

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
};

type DeleteDialogKind = "selected" | "topic" | "level" | null;

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

function imagePath(value?: LevelImageConfig) {
  if (!value) return "";
  return typeof value === "string" ? value : value.path || "";
}

function imageName(value?: LevelImageConfig) {
  if (!value || typeof value === "string") return "";
  return value.name || imagePath(value).split("/").pop() || "";
}

function imageExtension(path: string) {
  const fileName = path.split(/[\\/]/).pop() || "";
  const index = fileName.lastIndexOf(".");
  return index >= 0 ? fileName.slice(index).toLowerCase() : "";
}

function sameImageInfoExceptName(a?: LevelImageConfig, b?: LevelImageConfig) {
  if (!a || !b || typeof a === "string" || typeof b === "string") return false;
  const aPath = imagePath(a);
  const bPath = imagePath(b);
  if (!aPath || !bPath || aPath === bPath) return false;
  return Number(a.width || 0) > 0 && a.width === b.width && a.height === b.height && imageExtension(aPath) === imageExtension(bPath);
}

function levelAssetUrl(topicId: string, levelId: string, path: string) {
  const fileName = path.split("/").pop() || "";
  return fileName ? `/api/levels/${encodeURIComponent(topicId)}/${encodeURIComponent(levelId)}/assets/${encodeURIComponent(fileName)}?mtime=${Date.now()}` : "";
}

function modeStatus(draft?: LevelConfig) {
  return {
    polygon: Boolean(draft?.modes?.polygon?.pieces?.length),
    knob: Boolean(draft?.modes?.knob?.pieces?.length),
  };
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
  const [backgroundImages, setBackgroundImages] = useState<PendingImageItem[]>([]);
  const [pythonTools, setPythonTools] = useState<PythonTool[]>([]);
  const [coverSteps, setCoverSteps] = useState<ProcessStep[]>(() => defaultStepTypes.map(createProcessStep));
  const [disabledCoverStepIds, setDisabledCoverStepIds] = useState<Set<string>>(() => new Set());
  const [createDialog, setCreateDialog] = useState<"topic" | "level" | null>(null);
  const [deleteDialog, setDeleteDialog] = useState<DeleteDialogKind>(null);
  const [newTopicName, setNewTopicName] = useState("新主题");
  const [newTopicId, setNewTopicId] = useState("new_topic");
  const [newLevelTitle, setNewLevelTitle] = useState("新关卡");
  const [newLevelDescription, setNewLevelDescription] = useState("");
  const [newLevelTopicId, setNewLevelTopicId] = useState("");
  const [loadingGodot, setLoadingGodot] = useState(false);
  const [saving, setSaving] = useState(false);
  const [processingCover, setProcessingCover] = useState(false);
  const [coverLoadError, setCoverLoadError] = useState(false);
  const [dirty, setDirty] = useState(false);
  const dirtyLevelKeysRef = useRef<Set<string>>(new Set());
  const removedTopicIdsRef = useRef<Set<string>>(new Set());
  const removedLevelKeysRef = useRef<Set<string>>(new Set());
  const loadGenerationRef = useRef(0);
  const catalogRef = useRef(catalog);
  const levelDraftsRef = useRef(levelDrafts);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  const selectedTopic = useMemo(() => catalog.topics.find((topic) => topic.id === selectedTopicId), [catalog.topics, selectedTopicId]);
  const selectedLevel = useMemo(() => selectedTopic?.levels.find((level) => level.id === selectedLevelId), [selectedLevelId, selectedTopic]);
  const selectedLevelDraft = selectedTopic && selectedLevel ? levelDrafts[levelKey(selectedTopic.id, selectedLevel.id)] : undefined;
  const selectedModePreviews = useMemo(() => {
    if (!selectedTopic || !selectedLevel || !selectedLevelDraft) return [];
    const previews = ([
      { mode: "polygon", label: "多边形", icon: Hexagon, image: selectedLevelDraft.modes?.polygon?.image, path: imagePath(selectedLevelDraft.modes?.polygon?.image) },
      { mode: "knob", label: "凹凸", icon: Puzzle, image: selectedLevelDraft.modes?.knob?.image, path: imagePath(selectedLevelDraft.modes?.knob?.image) },
    ] as const)
      .filter((item) => item.path)
      .map((item) => ({ ...item, name: imageName(item.image), url: levelAssetUrl(selectedTopic.id, selectedLevel.id, item.path) }));
    const groups = new Map<string, { path: string; url: string; modes: typeof previews }>();
    for (const preview of previews) {
      const existing = groups.get(preview.path);
      if (existing) existing.modes.push(preview);
      else groups.set(preview.path, { path: preview.path, url: preview.url, modes: [preview] });
    }
    return [...groups.values()];
  }, [selectedLevel, selectedLevelDraft, selectedTopic]);
  const canMergeSelectedModeImages = useMemo(
    () => sameImageInfoExceptName(selectedLevelDraft?.modes?.polygon?.image, selectedLevelDraft?.modes?.knob?.image),
    [selectedLevelDraft],
  );
  const levelModeStatus = useMemo(() => {
    return Object.fromEntries(Object.entries(levelDrafts).map(([key, draft]) => [key, modeStatus(draft)]));
  }, [levelDrafts]);
  const backgroundImageOptions = useMemo(() => backgroundImages.map((item) => ({ value: item.path, label: item.name.split(/[\\/]/).pop() || item.name })), [backgroundImages]);
  const canUseBackgroundImage = backgroundImageOptions.length > 0;
  const hasTreeSelection = selectedTopicIds.size > 0 || selectedLevelKeys.size > 0;

  useEffect(() => {
    void resetFromGodot();
    void loadPythonTools();
    void loadBackgroundImages();
  }, []);

  useLayoutEffect(() => {
    catalogRef.current = catalog;
  }, [catalog]);

  useLayoutEffect(() => {
    levelDraftsRef.current = levelDrafts;
  }, [levelDrafts]);

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
    setCoverLoadError(false);
  }, [selectedTopic?.cover]);

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
    const generation = loadGenerationRef.current + 1;
    loadGenerationRef.current = generation;
    setLoadingGodot(true);
    try {
      const response = await fetch("/api/catalog");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelCatalog;
      const nextCatalog = {
        ...makeDefaultCatalog(),
        ...data,
        topics: normalizeOrder((data.topics || []).map((topic) => ({ ...topic, levels: normalizeOrder(topic.levels || []) }))),
      };
      const draftEntries = await preloadLevelDrafts(nextCatalog);
      if (loadGenerationRef.current !== generation) return;
      dirtyLevelKeysRef.current.clear();
      removedTopicIdsRef.current.clear();
      removedLevelKeysRef.current.clear();
      setCatalog(nextCatalog);
      setLocale(defaultLocale);
      setSelectedTopicId(nextCatalog.topics[0]?.id || "");
      setSelectedLevelId(nextCatalog.topics[0]?.levels[0]?.id || "");
      setLevelDrafts(Object.fromEntries(draftEntries));
      setDirty(false);
      toast.success("已从 Godot 关卡重置。");
    } catch (error) {
      if (loadGenerationRef.current !== generation) return;
      toast.error(error instanceof Error ? `重置失败：${error.message}` : "重置失败");
    } finally {
      if (loadGenerationRef.current === generation) setLoadingGodot(false);
    }
  }

  async function preloadLevelDrafts(nextCatalog: LevelCatalog) {
    const requests = nextCatalog.topics.flatMap((topic) => topic.levels.map((level) => fetchLevelDraft(topic.id, level.id, level)));
    return Promise.all(requests);
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

  async function loadBackgroundImages() {
    try {
      const response = await fetch("/api/pending-images");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { items?: PendingImageItem[] };
      setBackgroundImages((data.items || []).filter((item) => item.kind === "tablecloth" && !item.processed_path));
    } catch {
      setBackgroundImages([]);
    }
  }

  async function fetchLevelDraft(topicId: string, levelId: string, catalogLevel: CatalogLevel): Promise<[string, LevelConfig]> {
    const key = levelKey(topicId, levelId);
    try {
      const response = await fetch(`/api/levels/${topicId}/${levelId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelConfig;
      return [key, data];
    } catch {
      return [key, makeLevel(topicId, levelId, catalogLevel.title)];
    }
  }

  async function loadLevelDraft(topicId: string, levelId: string, catalogLevel: CatalogLevel) {
    const generation = loadGenerationRef.current;
    const [key, draft] = await fetchLevelDraft(topicId, levelId, catalogLevel);
    if (loadGenerationRef.current !== generation) return;
    setLevelDrafts((current) => {
      if (current[key] || dirtyLevelKeysRef.current.has(key)) return current;
      return { ...current, [key]: draft };
    });
  }

  function markLevelDraftDirty(key: string) {
    dirtyLevelKeysRef.current.add(key);
  }

  function clearLevelDraftDirty(key: string) {
    dirtyLevelKeysRef.current.delete(key);
  }

  function markTopicRemoved(topic: CatalogTopic) {
    removedTopicIdsRef.current.add(topic.id);
    for (const level of topic.levels) {
      removedLevelKeysRef.current.delete(levelKey(topic.id, level.id));
    }
  }

  function markLevelRemoved(topicId: string, levelId: string) {
    if (removedTopicIdsRef.current.has(topicId)) return;
    removedLevelKeysRef.current.add(levelKey(topicId, levelId));
  }

  function moveLevelDraftDirtyKey(oldKey: string, nextKey: string) {
    if (!dirtyLevelKeysRef.current.has(oldKey)) return;
    dirtyLevelKeysRef.current.delete(oldKey);
    dirtyLevelKeysRef.current.add(nextKey);
  }

  async function flushActiveInlineEdit() {
    const activeElement = document.activeElement;
    if (activeElement instanceof HTMLElement) activeElement.blur();
    await new Promise<void>((resolve) => window.setTimeout(resolve, 0));
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
    markLevelDraftDirty(key);
    setLevelDrafts((current) => {
      const existing = current[key] || makeLevel(selectedTopic.id, selectedLevel.id, selectedLevel.title);
      return { ...current, [key]: { ...existing, ...patch } };
    });
  }

  function mergeSelectedModeImages() {
    if (!selectedLevelDraft || !sameImageInfoExceptName(selectedLevelDraft.modes?.polygon?.image, selectedLevelDraft.modes?.knob?.image)) return;
    const polygonImage = selectedLevelDraft.modes.polygon.image;
    if (!polygonImage || typeof polygonImage === "string") return;
    const sharedImage = {
      path: polygonImage.path || "",
      name: polygonImage.name || imageName(polygonImage),
      width: Number(polygonImage.width || 0),
      height: Number(polygonImage.height || 0),
    };
    updateSelectedLevelDraft({
      image: sharedImage,
      assets: { ...(selectedLevelDraft.assets || {}), default_image: sharedImage },
      modes: {
        ...selectedLevelDraft.modes,
        polygon: { ...selectedLevelDraft.modes.polygon, image: sharedImage },
        knob: { ...selectedLevelDraft.modes.knob, image: sharedImage },
      },
    });
    toast.success("两个模式已合并使用同一张图片。");
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
    markLevelDraftDirty(key);
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
    setDirty(true);
    const removedTopicIds = new Set(selectedTopicIds);
    const removedLevelKeys = new Set(selectedLevelKeys);
    for (const topic of catalog.topics) {
      if (removedTopicIds.has(topic.id)) markTopicRemoved(topic);
      else {
        for (const level of topic.levels) {
          if (removedLevelKeys.has(levelKey(topic.id, level.id))) markLevelRemoved(topic.id, level.id);
        }
      }
    }
    for (const key of removedLevelKeys) clearLevelDraftDirty(key);
    for (const topicId of removedTopicIds) {
      for (const level of catalog.topics.find((topic) => topic.id === topicId)?.levels || []) {
        clearLevelDraftDirty(levelKey(topicId, level.id));
      }
    }
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
    setNewTopicId(idFromEnglishName("new_topic", "topic", catalog.topics.map((topic) => topic.id)));
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
    const id = idFromEnglishName(newTopicId, "topic", catalog.topics.map((topic) => topic.id));
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
    const nextLevelKey = levelKey(topic.id, id);
    setDirty(true);
    setCatalog((current) => ({
      ...current,
      topics: current.topics.map((candidate) => (candidate.id === topic.id ? { ...candidate, levels: normalizeOrder([...candidate.levels, level]) } : candidate)),
    }));
    markLevelDraftDirty(nextLevelKey);
    setLevelDrafts((current) => ({ ...current, [nextLevelKey]: makeLevel(topic.id, id, title, description) }));
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
    setDirty(true);
    markTopicRemoved(selectedTopic);
    const removedKeys = new Set(selectedTopic.levels.map((level) => levelKey(selectedTopic.id, level.id)));
    for (const key of removedKeys) clearLevelDraftDirty(key);
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
    setDirty(true);
    const removedKey = levelKey(selectedTopic.id, selectedLevel.id);
    markLevelRemoved(selectedTopic.id, selectedLevel.id);
    clearLevelDraftDirty(removedKey);
    setLevelDrafts((current) => Object.fromEntries(Object.entries(current).filter(([key]) => key !== removedKey)));
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

  function confirmDeleteDialog() {
    if (deleteDialog === "selected") deleteSelectedTreeItems();
    if (deleteDialog === "topic") deleteSelectedTopic();
    if (deleteDialog === "level") deleteSelectedLevel();
    setDeleteDialog(null);
  }

  const deleteDialogContent = useMemo(() => {
    if (deleteDialog === "selected") {
      return {
        title: "删除选中的主题和关卡？",
        description: "删除后需要点击“保存到 Godot”才会清理对应的关卡文件夹和文件。",
      };
    }
    if (deleteDialog === "topic" && selectedTopic) {
      return {
        title: `删除主题「${localized(selectedTopic.name_i18n, locale, selectedTopic.name)}」？`,
        description: "主题下的关卡也会移除，保存到 Godot 后会删除对应文件夹。",
      };
    }
    if (deleteDialog === "level" && selectedLevel) {
      return {
        title: `删除关卡「${localized(selectedLevel.title_i18n, locale, selectedLevel.title)}」？`,
        description: "保存到 Godot 后会删除这个关卡对应的文件夹和文件。",
      };
    }
    return null;
  }, [deleteDialog, locale, selectedLevel, selectedTopic]);

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
        moveLevelDraftDirtyKey(levelKey(activeTopic, activeLevel), levelKey(overTopic, activeLevel));
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
      setCoverLoadError(false);
      setDirty(true);
      toast.success("封面已上传。");
    } catch (error) {
      toast.error(error instanceof Error ? `上传封面失败：${error.message}` : "上传封面失败");
    }
  }

  async function processCover() {
    if (!selectedTopic?.cover) {
      toast.warning("请先上传主题封面。");
      return;
    }
    setProcessingCover(true);
    try {
      const response = await fetch(`/api/topics/${selectedTopic.id}/cover/process`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ coverPath: selectedTopic.cover, steps: coverSteps.filter((step) => !disabledCoverStepIds.has(step.id)).map(({ id: _id, ...step }) => step) }),
      });
      const data = (await response.json()) as { ok?: boolean; godotPath?: string; error?: string };
      if (!response.ok || !data.ok || !data.godotPath) throw new Error(data.error || `HTTP ${response.status}`);
      updateSelectedTopic({ cover: data.godotPath });
      setDirty(true);
      toast.success("封面处理完成。");
    } catch (error) {
      toast.error(error instanceof Error ? `处理封面失败：${error.message}` : "处理封面失败");
    } finally {
      setProcessingCover(false);
    }
  }

  function onCoverStepDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    setCoverSteps((current) => {
      const oldIndex = current.findIndex((step) => step.id === active.id);
      const newIndex = current.findIndex((step) => step.id === over.id);
      if (oldIndex < 0 || newIndex < 0) return current;
      return arrayMove(current, oldIndex, newIndex);
    });
  }

  async function saveToGodot() {
    await flushActiveInlineEdit();
    const currentCatalog = catalogRef.current;
    const currentDrafts = levelDraftsRef.current;
    const removedTopics = [...removedTopicIdsRef.current];
    const removedLevels = [...removedLevelKeysRef.current].map((key) => {
      const [topicId, levelId] = key.split("/");
      return { topicId, levelId };
    });
    const finalLevelEntries = currentCatalog.topics.flatMap((topic) =>
      topic.levels.map((level) => {
        const key = levelKey(topic.id, level.id);
        return [key, currentDrafts[key] || makeLevel(topic.id, level.id, level.title)] as const;
      }),
    );
    setSaving(true);
    try {
      const catalogResponse = await fetch("/api/catalog", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(currentCatalog),
      });
      const catalogData = (await catalogResponse.json()) as { ok?: boolean; error?: string };
      if (!catalogResponse.ok || !catalogData.ok) throw new Error(catalogData.error || `HTTP ${catalogResponse.status}`);
      for (const [key, draft] of finalLevelEntries) {
        const [topicId, levelId] = key.split("/");
        const response = await fetch(`/api/levels/${topicId}/${levelId}`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ level: draft, catalog: currentCatalog }),
        });
        const data = (await response.json()) as { ok?: boolean; error?: string };
        if (!response.ok || !data.ok) throw new Error(data.error || `HTTP ${response.status}`);
      }
      if (removedTopics.length || removedLevels.length) {
        const cleanupResponse = await fetch("/api/levels/cleanup", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ removedTopics, removedLevels }),
        });
        const cleanupData = (await cleanupResponse.json()) as { ok?: boolean; error?: string };
        if (!cleanupResponse.ok || !cleanupData.ok) throw new Error(cleanupData.error || `HTTP ${cleanupResponse.status}`);
      }
      const finalDrafts = Object.fromEntries(finalLevelEntries);
      levelDraftsRef.current = finalDrafts;
      setLevelDrafts(finalDrafts);
      dirtyLevelKeysRef.current.clear();
      removedTopicIdsRef.current.clear();
      removedLevelKeysRef.current.clear();
      setDirty(false);
      toast.success("关卡信息已保存到 Godot。");
    } catch (error) {
      toast.error(error instanceof Error ? `保存失败：${error.message}` : "保存失败");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid h-full min-h-0 grid-cols-[360px_1fr_360px] overflow-hidden bg-linen text-ink">
      <aside className="min-h-0 overflow-auto border-r border-stone-300 bg-paper p-4">
        <div className="flex items-start justify-between gap-3 border-b border-stone-300 pb-4">
          <div className="flex min-w-0 items-start gap-3">
            <Layers className="mt-1 shrink-0 text-clay" size={22} />
            <div className="min-w-0">
              <h1 className="text-xl font-semibold">关卡管理</h1>
              <p className="text-sm text-muted">主题 / 关卡 / 封面</p>
            </div>
          </div>
          <button className="btnPrimary shrink-0" disabled={loadingGodot || saving || !dirty} onClick={() => void saveToGodot()}>
            <Save size={16} />
            {saving ? "保存中..." : loadingGodot ? "读取中..." : "保存到 Godot"}
          </button>
        </div>
        <section className="mt-5 grid gap-3">
          <div className="flex items-center justify-between gap-2">
            <PanelTitle>关卡树</PanelTitle>
            <div className="flex items-center gap-2">
              <WithTooltip label="从 Godot 重置">
                <button className="iconBtn" disabled={loadingGodot || saving} onClick={() => void resetFromGodot()} aria-label="从 Godot 重置">
                  <RotateCcw size={16} />
                </button>
              </WithTooltip>
              <WithTooltip label={treeEditMode ? "退出编辑模式" : "编辑关卡树"}>
                <button className={treeEditMode ? "iconBtnActive" : "iconBtn"} disabled={loadingGodot} onClick={() => setTreeEditMode((current) => !current)} aria-label={treeEditMode ? "退出编辑模式" : "编辑关卡树"}>
                  <Pencil size={16} />
                </button>
              </WithTooltip>
              {treeEditMode && hasTreeSelection && (
                <WithTooltip label="删除选中">
                  <button className="iconBtnDanger" disabled={loadingGodot} onClick={() => setDeleteDialog("selected")} aria-label="删除选中">
                    <Trash2 size={16} />
                  </button>
                </WithTooltip>
              )}
              <WithTooltip label="创建主题">
                <button className="iconBtn" disabled={loadingGodot} onClick={openCreateTopic} aria-label="创建主题">
                  <FolderPlus size={16} />
                </button>
              </WithTooltip>
              <WithTooltip label="创建关卡">
                <button className="iconBtn" disabled={loadingGodot || !catalog.topics.length} onClick={openCreateLevel} aria-label="创建关卡">
                  <Plus size={16} />
                </button>
              </WithTooltip>
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
                    levelModeStatus={levelModeStatus}
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
                {loadingGodot && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">正在读取 Godot 关卡...</div>}
                {!loadingGodot && !catalog.topics.length && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无主题。</div>}
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
              <div className="rounded-md border border-stone-300 bg-white/70 px-3 py-2 text-sm text-ink">
                {localized(selectedTopic.name_i18n, locale, selectedTopic.name)}
              </div>
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
                <section className="grid gap-3">
                  <PanelTitle>关卡背景</PanelTitle>
                  <div className="flex flex-wrap items-center gap-3">
                    <ToggleGroup
                      type="single"
                      value={canUseBackgroundImage ? selectedLevelDraft?.background.type || "color" : "color"}
                      onValueChange={(value) => {
                        if (value === "color" || (value === "image" && canUseBackgroundImage)) {
                          const fallbackBackground = makeLevel(selectedTopic.id, selectedLevel.id, selectedLevel.title).background;
                          updateSelectedLevelDraft({
                            background: {
                              ...(selectedLevelDraft?.background || fallbackBackground),
                              type: value,
                              path: value === "image" ? selectedLevelDraft?.background.path || backgroundImageOptions[0]?.value || "" : selectedLevelDraft?.background.path || "",
                            },
                          });
                        }
                      }}
                    >
                      <ToggleGroupItem value="color">纯色</ToggleGroupItem>
                      <ToggleGroupItem value="image" disabled={!canUseBackgroundImage}>
                        图片
                      </ToggleGroupItem>
                    </ToggleGroup>
                    {canUseBackgroundImage && selectedLevelDraft?.background.type === "image" ? (
                      <div className="w-64">
                        <SelectBox
                          value={selectedLevelDraft.background.path || backgroundImageOptions[0]?.value || ""}
                          options={backgroundImageOptions}
                          onValueChange={(path) => updateSelectedLevelDraft({ background: { ...selectedLevelDraft.background, type: "image", path } })}
                          placeholder="选择背景图片"
                        />
                      </div>
                    ) : (
                      <input
                        className="input h-10 w-24 p-1"
                        type="color"
                        value={selectedLevelDraft?.background.color || "#F6EBD4"}
                        onChange={(event) =>
                          updateSelectedLevelDraft({
                            background: {
                              ...(selectedLevelDraft?.background || makeLevel(selectedTopic.id, selectedLevel.id, selectedLevel.title).background),
                              type: "color",
                              color: event.target.value,
                            },
                          })
                        }
                      />
                    )}
                  </div>
                </section>
                <section className="grid gap-3">
                  <div className="flex items-center justify-between gap-2">
                    <PanelTitle>模式图片</PanelTitle>
                    {canMergeSelectedModeImages && (
                      <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={mergeSelectedModeImages}>
                        <Link2 size={14} />
                        合并同图
                      </button>
                    )}
                  </div>
                  <div className="grid gap-3 sm:grid-cols-2">
                    {selectedModePreviews.map((preview) => {
                      return (
                        <div key={preview.path} className="overflow-hidden rounded-md border border-stone-300 bg-white/70">
                          <div className="flex items-center gap-2 border-b border-stone-200 px-3 py-2 text-sm font-medium">
                            {preview.modes.map((mode) => {
                              const Icon = mode.icon;
                              return (
                                <span key={mode.mode} className="inline-flex items-center gap-1">
                                  <Icon size={15} />
                                  {mode.label}
                                </span>
                              );
                            })}
                            {preview.modes.length > 1 && <span className="ml-auto rounded bg-clay/10 px-2 py-0.5 text-xs text-clay">同图</span>}
                          </div>
                          <div className="grid min-h-36 place-items-center bg-stone-100/70 p-2">
                            <img className="max-h-44 w-full object-contain" src={preview.url} alt={`${preview.modes.map((mode) => mode.label).join("/")}图片`} />
                          </div>
                        </div>
                      );
                    })}
                    {!selectedModePreviews.length && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无模式图片</div>}
                  </div>
                </section>
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
          <label
            className={[
              "group relative grid min-h-36 cursor-pointer place-items-center overflow-hidden rounded-md border bg-white/70 transition hover:border-clay",
              selectedTopic?.cover && !coverLoadError ? "border-stone-300" : "border-dashed border-stone-300",
              loadingGodot || !selectedTopic ? "pointer-events-none opacity-60" : "",
            ].join(" ")}
          >
            {selectedTopic?.cover && !coverLoadError ? (
              <>
                <img className="max-h-56 w-full object-contain" src={topicCoverUrl(selectedTopic)} alt="主题封面" onError={() => setCoverLoadError(true)} />
                <span className="absolute inset-0 grid place-items-center bg-black/0 text-sm font-medium text-white opacity-0 transition group-hover:bg-black/35 group-hover:opacity-100">
                  点击上传封面
                </span>
              </>
            ) : (
              <span className="grid place-items-center gap-2 text-sm text-muted">
                <span>{coverLoadError ? "封面加载失败" : "暂无封面"}</span>
                <span className="btn pointer-events-none">
                  <Upload size={16} />
                  上传封面
                </span>
              </span>
            )}
            <input hidden disabled={loadingGodot} type="file" accept="image/*" onChange={(event) => void uploadCover(event.target.files?.[0])} />
          </label>
        </section>

        <section className="mt-5 grid gap-3 border-t border-stone-300 pt-4">
          <div className="flex items-center justify-between gap-2">
            <PanelTitle>封面处理</PanelTitle>
            <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={() => {
              setCoverSteps(defaultStepTypes.map(createProcessStep));
              setDisabledCoverStepIds(new Set());
            }}>
              <RotateCcw size={14} />
              默认
            </button>
          </div>
          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onCoverStepDragEnd}>
            <SortableContext items={coverSteps.map((step) => step.id)} strategy={verticalListSortingStrategy}>
              <div className="grid gap-2">
                {coverSteps.map((step) => (
                  <CoverStepRow
                    key={step.id}
                    step={step}
                    tool={pythonTools.find((tool) => tool.stepType === step.type) || fallbackPythonTool(step.type)}
                    disabled={disabledCoverStepIds.has(step.id)}
                    onUpdate={(patch) => setCoverSteps((current) => current.map((item) => (item.id === step.id ? { ...item, ...patch } : item)))}
                    onEnabledChange={(checked) => {
                      setDisabledCoverStepIds((current) => {
                        const next = new Set(current);
                        if (checked) next.delete(step.id);
                        else next.add(step.id);
                        return next;
                      });
                    }}
                  />
                ))}
              </div>
            </SortableContext>
          </DndContext>
          <button className="btnPrimary" disabled={loadingGodot || !selectedTopic?.cover || processingCover} onClick={() => void processCover()}>
            <ImageIcon size={16} />
            {processingCover ? "处理中..." : "处理封面"}
          </button>
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
                <>
                  <Field label="主题名">
                    <input className="input" autoFocus value={newTopicName} onChange={(event) => setNewTopicName(event.target.value)} onKeyDown={(event) => {
                      if (event.key === "Enter") createTopic();
                    }} />
                  </Field>
                  <Field label="英文名称">
                    <input
                      className="input"
                      value={newTopicId}
                      onChange={(event) => setNewTopicId(idFromEnglishName(event.target.value, "topic", []))}
                      onKeyDown={(event) => {
                        if (event.key === "Enter") createTopic();
                      }}
                    />
                  </Field>
                </>
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
      <AlertDialog open={Boolean(deleteDialogContent)} onOpenChange={(open) => {
        if (!open) setDeleteDialog(null);
      }}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{deleteDialogContent?.title}</AlertDialogTitle>
            <AlertDialogDescription>{deleteDialogContent?.description}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction className="bg-[#9e3f35] hover:bg-[#87342c]" onClick={confirmDeleteDialog}>
              删除
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

export default CatalogManagementPage;
