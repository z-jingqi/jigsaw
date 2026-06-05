import { useEffect, useMemo, useState } from "react";
import { Hexagon, Puzzle, Shuffle } from "lucide-react";
import { toast } from "sonner";
import type { CatalogGroup, CatalogLevel, CatalogTopic, LevelCatalog, LevelConfig, PendingImageItem } from "../types";
import { makeDefaultCatalog, normalizeOrder } from "../shared/lib/catalog";
import { modeDraftForExport, modeDraftForLevelExport, type LevelModeTarget } from "./LevelEditorPage";

type Props = {
  onUnsavedChange?: (dirty: boolean) => void;
  onEditLevelMode?: (target: LevelModeTarget & { mode: "polygon" | "knob" | "swap" }) => void;
};

type SelectedTarget = {
  topicId: string;
  groupId: string;
  levelId: string;
};

type LevelDraft = {
  title: string;
  description: string;
  sourceImageId: string;
  useExistingSource: boolean;
  modes: {
    polygon: boolean;
    knob: boolean;
    swap: boolean;
  };
};

const defaultDraft: LevelDraft = {
  title: "",
  description: "",
  sourceImageId: "",
  useExistingSource: false,
  modes: { polygon: false, knob: false, swap: true },
};

function slug(value: string, fallback: string) {
  const cleaned = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/gi, "_")
    .replace(/^_+|_+$/g, "");
  return cleaned || fallback;
}

function topicGroups(topic: CatalogTopic | undefined) {
  return topic?.groups || [];
}

function levelKey(target: SelectedTarget) {
  return `${target.topicId}/${target.groupId}/${target.levelId}`;
}

function emptyTarget(): SelectedTarget {
  return { topicId: "", groupId: "", levelId: "" };
}

function makeLevelConfig(target: SelectedTarget, draft: LevelDraft, image: PendingImageItem | undefined, existing: LevelConfig | undefined): LevelConfig {
  const imageWidth = image?.source_info.width || existing?.image.width || 0;
  const imageHeight = image?.source_info.height || existing?.image.height || 0;
  const imagePath = `res://levels/${target.topicId}/${target.groupId}/${target.levelId}/source.jpg`;
  const polygonData = modeDraftForLevelExport(target, "polygon") || (draft.sourceImageId ? modeDraftForExport(draft.sourceImageId, "polygon") : null) || existing?.modes?.polygon || { pieces: [], generator: null };
  const knobData = modeDraftForLevelExport(target, "knob") || (draft.sourceImageId ? modeDraftForExport(draft.sourceImageId, "knob") : null) || existing?.modes?.knob || { rows: 8, cols: 8, knob_size: 0.24, pieces: [] };
  const swapData = modeDraftForLevelExport(target, "swap") || (draft.sourceImageId ? modeDraftForExport(draft.sourceImageId, "swap") : null) || existing?.modes?.swap || { auto: true, max_pieces: 25 };
  const modes: LevelConfig["modes"] = {
    polygon: draft.modes.polygon ? { pieces: [], generator: null, ...(polygonData as any) } : { pieces: [] },
    knob: draft.modes.knob ? { rows: 8, cols: 8, knob_size: 0.24, pieces: [], ...(knobData as any) } : { rows: 8, cols: 8, knob_size: 0.24, pieces: [] },
    swap: draft.modes.swap ? { auto: true, max_pieces: 25, ...(swapData as any) } as any : { rows: 0, cols: 0 },
  };
  if (!draft.modes.polygon) delete (modes as any).polygon;
  if (!draft.modes.knob) delete (modes as any).knob;
  if (!draft.modes.swap) delete (modes as any).swap;
  return {
    version: 3,
    id: target.levelId,
    topic_id: target.topicId,
    group_id: target.groupId,
    title: draft.title || target.levelId,
    title_i18n: { en: draft.title || target.levelId, _: draft.title || target.levelId },
    description: draft.description,
    description_i18n: { en: draft.description, _: draft.description },
    image: {
      path: imagePath,
      width: imageWidth,
      height: imageHeight,
      aspect_ratio: imageWidth && imageHeight ? imageWidth / imageHeight : 0.75,
      preset: "mobile_portrait_3x4",
    },
    background: { type: "color", color: "#F6EBD4", path: "" },
    grid: { cols: 8, rows: 8, piece_size: 190 },
    component_overrides: {},
    modes,
    editor: { outline: [], cuts: [], shapes: [], pieces: [] },
  };
}

export default function CatalogManagementPage({ onUnsavedChange, onEditLevelMode }: Props) {
  const [catalog, setCatalog] = useState<LevelCatalog>(() => makeDefaultCatalog());
  const [images, setImages] = useState<PendingImageItem[]>([]);
  const [selected, setSelected] = useState<SelectedTarget>(() => emptyTarget());
  const [drafts, setDrafts] = useState<Record<string, LevelDraft>>({});
  const [levelConfigs, setLevelConfigs] = useState<Record<string, LevelConfig>>({});
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void loadAll();
  }, []);

  useEffect(() => {
    onUnsavedChange?.(dirty);
    return () => onUnsavedChange?.(false);
  }, [dirty, onUnsavedChange]);

  const selectedTopic = useMemo(() => catalog.topics.find((topic) => topic.id === selected.topicId), [catalog.topics, selected.topicId]);
  const selectedGroup = useMemo(() => topicGroups(selectedTopic).find((group) => group.id === selected.groupId), [selected.groupId, selectedTopic]);
  const selectedLevel = useMemo(() => selectedGroup?.levels.find((level) => level.id === selected.levelId), [selected.levelId, selectedGroup]);
  const selectedConfig = selected.levelId ? levelConfigs[levelKey(selected)] : undefined;
  const selectedDraft = selected.levelId ? drafts[levelKey(selected)] || draftFromLevelConfig(selectedConfig, selectedLevel?.title || "") : defaultDraft;
  const selectedImage = images.find((image) => image.id === selectedDraft.sourceImageId);
  const existingSourceUrl = selected.levelId ? `/api/levels/${encodeURIComponent(selected.topicId)}/${encodeURIComponent(selected.groupId)}/${encodeURIComponent(selected.levelId)}/source?mtime=${Date.now()}` : "";

  useEffect(() => {
    if (!selected.topicId || !selected.groupId || !selected.levelId) return;
    void loadSelectedLevel(selected);
  }, [selected.topicId, selected.groupId, selected.levelId]);

  async function loadAll() {
    await Promise.all([loadCatalog(), loadImages()]);
  }

  async function loadCatalog() {
    try {
      const response = await fetch("/api/catalog");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as LevelCatalog;
      const normalized = normalizeCatalog(data);
      setCatalog(normalized);
      const firstTopic = normalized.topics[0];
      const firstGroup = firstTopic?.groups[0];
      const firstLevel = firstGroup?.levels[0];
      setSelected(firstTopic && firstGroup && firstLevel ? { topicId: firstTopic.id, groupId: firstGroup.id, levelId: firstLevel.id } : emptyTarget());
    } catch (error) {
      toast.error(error instanceof Error ? `加载关卡失败：${error.message}` : "加载关卡失败");
    }
  }

  async function loadImages() {
    try {
      const response = await fetch("/api/pending-images");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = (await response.json()) as { items?: PendingImageItem[] };
      setImages((data.items || []).filter((item) => item.kind === "image" && !item.processed_path));
    } catch (error) {
      toast.error(error instanceof Error ? `加载图片失败：${error.message}` : "加载图片失败");
    }
  }

  async function loadSelectedLevel(target: SelectedTarget) {
    const key = levelKey(target);
    if (levelConfigs[key]) return;
    try {
      const response = await fetch(`/api/levels/${encodeURIComponent(target.topicId)}/${encodeURIComponent(target.groupId)}/${encodeURIComponent(target.levelId)}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const config = (await response.json()) as LevelConfig;
      setLevelConfigs((current) => ({ ...current, [key]: config }));
      setDrafts((current) => current[key] ? current : { ...current, [key]: draftFromLevelConfig(config, config.title || target.levelId) });
    } catch {
      setDrafts((current) => current[key] ? current : { ...current, [key]: { ...defaultDraft, title: selectedLevel?.title || target.levelId } });
    }
  }

  function draftFromLevelConfig(config: LevelConfig | undefined, fallbackTitle: string): LevelDraft {
    return {
      ...defaultDraft,
      title: config?.title || fallbackTitle,
      description: config?.description || "",
      sourceImageId: "",
      useExistingSource: Boolean(config?.image?.path),
      modes: {
        polygon: Boolean(config?.modes?.polygon),
        knob: Boolean(config?.modes?.knob),
        swap: Boolean(config?.modes?.swap ?? true),
      },
    };
  }

  function normalizeCatalog(next: LevelCatalog): LevelCatalog {
    return {
      ...makeDefaultCatalog(),
      ...next,
      version: 3,
      topics: normalizeOrder((next.topics || []).map((topic) => ({
        ...topic,
        levels: [],
        groups: normalizeOrder((topic.groups || []).map((group) => ({ ...group, levels: normalizeOrder(group.levels || []) }))),
      }))),
    };
  }

  function markDirty() {
    setDirty(true);
  }

  function setCurrentDraft(update: Partial<LevelDraft>) {
    if (!selected.levelId) return;
    setDrafts((current) => ({ ...current, [levelKey(selected)]: { ...selectedDraft, ...update } }));
    markDirty();
  }

  function updateSelectedTitle(title: string) {
    setCurrentDraft({ title });
    setCatalog((current) => normalizeCatalog({
      ...current,
      topics: current.topics.map((topic) =>
        topic.id === selected.topicId
          ? {
              ...topic,
              groups: topic.groups.map((group) =>
                group.id === selected.groupId
                  ? {
                      ...group,
                      levels: group.levels.map((level) => level.id === selected.levelId ? { ...level, title, title_i18n: { ...(level.title_i18n || {}), en: title, _: title } } : level),
                    }
                  : group,
              ),
            }
          : topic,
      ),
    }));
  }

  function addTopic() {
    const name = `Topic ${catalog.topics.length + 1}`;
    const id = slug(name, `topic_${catalog.topics.length + 1}`);
    setCatalog((current) => normalizeCatalog({
      ...current,
      topics: [...current.topics, { id, name, name_i18n: { en: name, _: name }, sort_order: current.topics.length, cover: "", levels: [], groups: [] }],
    }));
    setSelected({ topicId: id, groupId: "", levelId: "" });
    markDirty();
  }

  function addGroup(topicId = selected.topicId) {
    if (!topicId) return;
    const topic = catalog.topics.find((item) => item.id === topicId);
    if (!topic) return;
    const name = `Group ${topic.groups.length + 1}`;
    const id = slug(name, `group_${topic.groups.length + 1}`);
    setCatalog((current) => normalizeCatalog({
      ...current,
      topics: current.topics.map((item) =>
        item.id === topicId
          ? { ...item, groups: [...item.groups, { id, name, name_i18n: { en: name, _: name }, sort_order: item.groups.length, levels: [] }] }
          : item,
      ),
    }));
    setSelected({ topicId, groupId: id, levelId: "" });
    markDirty();
  }

  function addLevel() {
    if (!selected.topicId || !selected.groupId) return;
    const group = selectedGroup;
    if (!group) return;
    const title = `Level ${group.levels.length + 1}`;
    const id = slug(title, `level_${group.levels.length + 1}`);
    const level: CatalogLevel = {
      id,
      title,
      title_i18n: { en: title, _: title },
      sort_order: group.levels.length,
      path: `res://levels/${selected.topicId}/${selected.groupId}/${id}/level.json`,
      source: `res://levels/${selected.topicId}/${selected.groupId}/${id}/source.jpg`,
    };
    setCatalog((current) => normalizeCatalog({
      ...current,
      topics: current.topics.map((topic) =>
        topic.id === selected.topicId
          ? { ...topic, groups: topic.groups.map((candidate) => (candidate.id === selected.groupId ? { ...candidate, levels: [...candidate.levels, level] } : candidate)) }
          : topic,
      ),
    }));
    setSelected({ topicId: selected.topicId, groupId: selected.groupId, levelId: id });
    setDrafts((current) => ({ ...current, [`${selected.topicId}/${selected.groupId}/${id}`]: { ...defaultDraft, title } }));
    markDirty();
  }

  function renameTopic(topicId: string, name: string) {
    setCatalog((current) => normalizeCatalog({ ...current, topics: current.topics.map((topic) => (topic.id === topicId ? { ...topic, name, name_i18n: { ...(topic.name_i18n || {}), en: name, _: name } } : topic)) }));
    markDirty();
  }

  function renameGroup(topicId: string, groupId: string, name: string) {
    setCatalog((current) => normalizeCatalog({ ...current, topics: current.topics.map((topic) => topic.id === topicId ? { ...topic, groups: topic.groups.map((group) => group.id === groupId ? { ...group, name, name_i18n: { ...(group.name_i18n || {}), en: name, _: name } } : group) } : topic) }));
    markDirty();
  }

  async function saveToGodot() {
    setSaving(true);
    try {
      await fetch("/api/catalog", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(catalog),
      });
      for (const topic of catalog.topics) {
        for (const group of topic.groups) {
          for (const level of group.levels) {
            const target = { topicId: topic.id, groupId: group.id, levelId: level.id };
            const draft = drafts[levelKey(target)] || { ...defaultDraft, title: level.title };
            if (!draft.sourceImageId && !draft.useExistingSource) continue;
            const image = images.find((item) => item.id === draft.sourceImageId);
            const levelConfig = makeLevelConfig(target, draft, image, levelConfigs[levelKey(target)]);
            const response = await fetch(`/api/levels/${topic.id}/${group.id}/${level.id}`, {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify({ level: levelConfig, catalog, ...(draft.sourceImageId ? { sourcePendingId: draft.sourceImageId } : {}) }),
            });
            const data = (await response.json()) as { ok?: boolean; error?: string };
            if (!response.ok || !data.ok) throw new Error(data.error || `${topic.name}/${group.name}/${level.title} 保存失败`);
          }
        }
      }
      setDirty(false);
      toast.success("已导出到 Godot。");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "导出失败");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid h-full min-h-0 grid-cols-[360px_1fr] gap-4 p-4">
      <aside className="min-h-0 overflow-auto rounded-lg border border-stone-300 bg-paper p-4">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-semibold">关卡</h2>
          <div className="flex gap-2">
            <button className="btn" onClick={addTopic}>主题</button>
            <button className="btn" disabled={!selected.topicId} onClick={() => addGroup()}>分组</button>
            <button className="btnPrimary" disabled={!selected.groupId} onClick={addLevel}>关卡</button>
          </div>
        </div>
        <div className="space-y-3">
          {catalog.topics.map((topic) => (
            <div key={topic.id} className="rounded-md border border-stone-300 bg-white p-3">
              <input className="input mb-2 font-semibold" value={topic.name} onChange={(event) => renameTopic(topic.id, event.target.value)} onFocus={() => setSelected({ topicId: topic.id, groupId: topic.groups[0]?.id || "", levelId: topic.groups[0]?.levels[0]?.id || "" })} />
              <div className="space-y-2">
                {topic.groups.map((group) => (
                  <div key={group.id} className="rounded border border-stone-200 p-2">
                    <input className="input mb-2 text-sm font-medium" value={group.name} onChange={(event) => renameGroup(topic.id, group.id, event.target.value)} onFocus={() => setSelected({ topicId: topic.id, groupId: group.id, levelId: group.levels[0]?.id || "" })} />
                    <div className="space-y-1">
                      {group.levels.map((level) => (
                        <button key={level.id} className={selected.topicId === topic.id && selected.groupId === group.id && selected.levelId === level.id ? "objectActive w-full" : "object w-full"} onClick={() => setSelected({ topicId: topic.id, groupId: group.id, levelId: level.id })}>
                          <span className="truncate">{level.title}</span>
                        </button>
                      ))}
                      {!group.levels.length && <p className="text-xs text-muted">暂无关卡</p>}
                    </div>
                  </div>
                ))}
                {!topic.groups.length && <p className="text-xs text-muted">暂无分组</p>}
              </div>
            </div>
          ))}
          {!catalog.topics.length && <p className="rounded-md border border-dashed border-stone-300 bg-white/70 p-4 text-sm text-muted">暂无主题。</p>}
        </div>
      </aside>

      <main className="min-h-0 overflow-auto rounded-lg border border-stone-300 bg-paper p-5">
        <div className="mb-5 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold">关卡详情</h1>
            <p className="text-sm text-muted">{selected.topicId && selected.groupId ? `${selectedTopic?.name || selected.topicId} -> ${selectedGroup?.name || selected.groupId}` : "先选择或创建分组"}</p>
          </div>
          <button className="btnPrimary" disabled={saving} onClick={saveToGodot}>{saving ? "导出中..." : "导出到 Godot"}</button>
        </div>

        {selected.levelId ? (
          <div className="grid grid-cols-[1fr_320px] gap-5">
            <section className="space-y-4">
              <label className="block text-sm font-medium">关卡名<input className="input mt-1" value={selectedDraft.title} onChange={(event) => updateSelectedTitle(event.target.value)} /></label>
              <label className="block text-sm font-medium">介绍<textarea className="input mt-1 min-h-24" value={selectedDraft.description} onChange={(event) => setCurrentDraft({ description: event.target.value })} /></label>
              <label className="block text-sm font-medium">
                原图
                <select
                  className="input mt-1"
                  value={selectedDraft.useExistingSource ? "__existing" : selectedDraft.sourceImageId}
                  onChange={(event) => {
                    const value = event.target.value;
                    setCurrentDraft(value === "__existing" ? { sourceImageId: "", useExistingSource: true } : { sourceImageId: value, useExistingSource: false });
                  }}
                >
                  {selectedConfig?.image?.path && <option value="__existing">使用已有关卡 source.jpg</option>}
                  <option value="">选择已处理图片</option>
                  {images.map((image) => <option key={image.id} value={image.id}>{image.name}</option>)}
                </select>
              </label>
              <div className="grid gap-2">
                <div className="flex items-center gap-2">
                  <label className="btn flex-1 justify-start"><input type="checkbox" checked={selectedDraft.modes.polygon} onChange={(event) => setCurrentDraft({ modes: { ...selectedDraft.modes, polygon: event.target.checked } })} /><Hexagon size={18} />多边形</label>
                  <button className="btn" disabled={!selectedDraft.modes.polygon || !onEditLevelMode} onClick={() => onEditLevelMode?.({ topicId: selected.topicId, groupId: selected.groupId, levelId: selected.levelId, mode: "polygon" })}>编辑</button>
                </div>
                <div className="flex items-center gap-2">
                  <label className="btn flex-1 justify-start"><input type="checkbox" checked={selectedDraft.modes.knob} onChange={(event) => setCurrentDraft({ modes: { ...selectedDraft.modes, knob: event.target.checked } })} /><Puzzle size={18} />凹凸拼图</label>
                  <button className="btn" disabled={!selectedDraft.modes.knob || !onEditLevelMode} onClick={() => onEditLevelMode?.({ topicId: selected.topicId, groupId: selected.groupId, levelId: selected.levelId, mode: "knob" })}>编辑</button>
                </div>
                <div className="flex items-center gap-2">
                  <label className="btn flex-1 justify-start"><input type="checkbox" checked={selectedDraft.modes.swap} onChange={(event) => setCurrentDraft({ modes: { ...selectedDraft.modes, swap: event.target.checked } })} /><Shuffle size={18} />方格交换</label>
                  <button className="btn" disabled={!selectedDraft.modes.swap || !onEditLevelMode} onClick={() => onEditLevelMode?.({ topicId: selected.topicId, groupId: selected.groupId, levelId: selected.levelId, mode: "swap" })}>预览</button>
                </div>
              </div>
            </section>
            <aside className="rounded-lg bg-linen p-4">
              {selectedImage ? (
                <img className="w-full rounded-lg object-contain" src={selectedImage.url} alt={selectedImage.name} />
              ) : selectedDraft.useExistingSource && selectedConfig?.image?.path ? (
                <img className="w-full rounded-lg object-contain" src={existingSourceUrl} alt={selectedDraft.title} />
              ) : (
                <div className="grid aspect-[3/4] place-items-center rounded-lg border border-dashed border-stone-300 text-sm text-muted">未选择图片</div>
              )}
            </aside>
          </div>
        ) : (
          <div className="grid h-[50vh] place-items-center rounded-lg border border-dashed border-stone-300 text-muted">请选择一个关卡</div>
        )}
      </main>
    </div>
  );
}
