import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties } from "react";
import { type DragEndEvent } from "@dnd-kit/core";
import { arrayMove } from "@dnd-kit/sortable";
import { Hexagon, Puzzle } from "lucide-react";
import { toast } from "sonner";
import type { CatalogLevel, CatalogTopic, LevelCatalog, LevelConfig, PendingImageItem, ProcessStep, PythonTool } from "../types";
import { CatalogTreeAside } from "../features/catalog/components/CatalogTreeAside";
import {
  LevelDetailsPanel,
  type ModePreviewGroup,
  type TableclothPreview,
} from "../features/catalog/components/LevelDetailsPanel";
import { TopicCoverAside } from "../features/catalog/components/TopicCoverAside";
import { CatalogCreateDialog } from "../features/catalog/components/CatalogCreateDialog";
import { CatalogDeleteDialog } from "../features/catalog/components/CatalogDeleteDialog";
import {
  imageName,
  imagePath,
  levelAssetUrl,
  levelBackgroundUrl,
  makeLevel,
  modeStatus,
  moveLevelDraft,
  moveLevelInCatalog,
  sameImageInfoExceptName,
  type CatalogDeleteDialogKind,
} from "../features/catalog/lib/catalogPage";
import { makeDefaultCatalog, normalizeOrder } from "../shared/lib/catalog";
import { idFromEnglishName, levelKey, nextSequentialId } from "../shared/lib/ids";
import { defaultLocale, localized } from "../shared/lib/i18n";
import { createProcessStep, defaultStepTypes } from "../shared/lib/processSteps";

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
};

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
  const [deleteDialog, setDeleteDialog] = useState<CatalogDeleteDialogKind>(null);
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

  const selectedTopic = useMemo(() => catalog.topics.find((topic) => topic.id === selectedTopicId), [catalog.topics, selectedTopicId]);
  const selectedLevel = useMemo(() => selectedTopic?.levels.find((level) => level.id === selectedLevelId), [selectedLevelId, selectedTopic]);
  const selectedLevelDraft = selectedTopic && selectedLevel ? levelDrafts[levelKey(selectedTopic.id, selectedLevel.id)] : undefined;
  const selectedModePreviews = useMemo<ModePreviewGroup[]>(() => {
    if (!selectedTopic || !selectedLevel || !selectedLevelDraft) return [];
    const previews = ([
      { mode: "polygon", label: "多边形", icon: Hexagon, image: selectedLevelDraft.modes?.polygon?.image, path: imagePath(selectedLevelDraft.modes?.polygon?.image) },
      { mode: "knob", label: "凹凸", icon: Puzzle, image: selectedLevelDraft.modes?.knob?.image, path: imagePath(selectedLevelDraft.modes?.knob?.image) },
    ] as const)
      .filter((item) => item.path)
      .map((item) => ({ ...item, name: imageName(item.image), url: levelAssetUrl(selectedTopic.id, selectedLevel.id, item.path) }));
    const groups = new Map<string, ModePreviewGroup>();
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
  const levelModeStatus = useMemo(
    () => Object.fromEntries(Object.entries(levelDrafts).map(([key, draft]) => [key, modeStatus(draft)])),
    [levelDrafts],
  );
  const backgroundImageOptions = useMemo(
    () => backgroundImages.map((item) => ({ value: item.path, label: item.name.split(/[\\/]/).pop() || item.name })),
    [backgroundImages],
  );
  const canUseBackgroundImage = backgroundImageOptions.length > 0;
  const tableclothPreview = useMemo<TableclothPreview>(() => {
    const background = selectedLevelDraft?.background;
    const color = background?.color || "#ead8bd";
    if (!selectedTopic || !selectedLevel || background?.type !== "image" || !background.path) {
      return { type: "color", color, url: "", label: "纯色桌布" };
    }
    const url = levelBackgroundUrl(selectedTopic.id, selectedLevel.id, background.path, backgroundImages);
    return { type: url ? "image" : "color", color, url, label: url ? "桌布图片" : "桌布图片未保存" };
  }, [backgroundImages, selectedLevel, selectedLevelDraft?.background, selectedTopic]);
  const tableclothStyle = useMemo<CSSProperties>(() => {
    if (tableclothPreview.type === "image") {
      return {
        backgroundColor: tableclothPreview.color,
        backgroundImage: `url("${tableclothPreview.url}")`,
        backgroundPosition: "center",
        backgroundSize: "cover",
      };
    }
    return { backgroundColor: tableclothPreview.color };
  }, [tableclothPreview]);
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
      const overTopic = overParts[1];
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

  const fallbackBackground = useMemo(() => {
    if (!selectedTopic || !selectedLevel) return makeLevel("", "", "").background;
    return makeLevel(selectedTopic.id, selectedLevel.id, selectedLevel.title).background;
  }, [selectedLevel, selectedTopic]);

  return (
    <div className="grid h-full min-h-0 grid-cols-[360px_1fr_360px] overflow-hidden bg-linen text-ink">
      <CatalogTreeAside
        catalog={catalog}
        locale={locale}
        collapsedTopics={collapsedTopics}
        selectedTopicId={selectedTopicId}
        selectedLevelId={selectedLevelId}
        treeEditMode={treeEditMode}
        selectedTopicIds={selectedTopicIds}
        selectedLevelKeys={selectedLevelKeys}
        editingTopicId={editingTopicId}
        editingLevelKey={editingLevelKey}
        levelModeStatus={levelModeStatus}
        hasTreeSelection={hasTreeSelection}
        loadingGodot={loadingGodot}
        saving={saving}
        dirty={dirty}
        onSaveToGodot={() => void saveToGodot()}
        onResetFromGodot={() => void resetFromGodot()}
        onToggleEditMode={() => setTreeEditMode((current) => !current)}
        onRequestDelete={() => setDeleteDialog("selected")}
        onCreateTopic={openCreateTopic}
        onCreateLevel={openCreateLevel}
        onDragEnd={onDragEnd}
        onToggleTopicCollapse={toggleTopic}
        onSelectTopic={(topic) => {
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

      <LevelDetailsPanel
        locale={locale}
        selectedTopic={selectedTopic}
        selectedLevel={selectedLevel}
        selectedLevelDraft={selectedLevelDraft}
        selectedModePreviews={selectedModePreviews}
        canMergeSelectedModeImages={canMergeSelectedModeImages}
        onMergeSelectedModeImages={mergeSelectedModeImages}
        tableclothPreview={tableclothPreview}
        tableclothStyle={tableclothStyle}
        backgroundImageOptions={backgroundImageOptions}
        canUseBackgroundImage={canUseBackgroundImage}
        onUpdateDescription={(description) =>
          updateSelectedLevelDraft({ description, description_i18n: { ...(selectedLevelDraft?.description_i18n || {}), [locale]: description } })
        }
        onUpdateBackground={(background) => updateSelectedLevelDraft({ background })}
        fallbackBackground={fallbackBackground}
      />

      <TopicCoverAside
        selectedTopic={selectedTopic}
        loadingGodot={loadingGodot}
        coverLoadError={coverLoadError}
        onCoverLoadError={() => setCoverLoadError(true)}
        onUploadCover={(file) => void uploadCover(file)}
        coverSteps={coverSteps}
        pythonTools={pythonTools}
        disabledCoverStepIds={disabledCoverStepIds}
        onResetCoverSteps={() => {
          setCoverSteps(defaultStepTypes.map(createProcessStep));
          setDisabledCoverStepIds(new Set());
        }}
        onUpdateCoverStep={(id, patch) => setCoverSteps((current) => current.map((item) => (item.id === id ? { ...item, ...patch } : item)))}
        onToggleCoverStepEnabled={(id, checked) =>
          setDisabledCoverStepIds((current) => {
            const next = new Set(current);
            if (checked) next.delete(id);
            else next.add(id);
            return next;
          })
        }
        onCoverStepDragEnd={onCoverStepDragEnd}
        processingCover={processingCover}
        onProcessCover={() => void processCover()}
      />

      <CatalogCreateDialog
        open={createDialog}
        locale={locale}
        topics={catalog.topics}
        topicName={newTopicName}
        topicId={newTopicId}
        levelTitle={newLevelTitle}
        levelDescription={newLevelDescription}
        levelTopicId={newLevelTopicId}
        onTopicNameChange={setNewTopicName}
        onTopicIdChange={setNewTopicId}
        onLevelTitleChange={setNewLevelTitle}
        onLevelDescriptionChange={setNewLevelDescription}
        onLevelTopicIdChange={setNewLevelTopicId}
        onCreateTopic={createTopic}
        onCreateLevel={createLevel}
        onClose={() => setCreateDialog(null)}
      />

      <CatalogDeleteDialog content={deleteDialogContent} onCancel={() => setDeleteDialog(null)} onConfirm={confirmDeleteDialog} />
    </div>
  );
}

export default CatalogManagementPage;
