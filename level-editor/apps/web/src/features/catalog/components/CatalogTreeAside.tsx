import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { FolderPlus, Layers, Pencil, Plus, RotateCcw, Save, Trash2 } from "lucide-react";
import type { CatalogLevel, CatalogTopic, LevelCatalog } from "../../../types";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import { WithTooltip } from "../../../components/ui/tooltip";
import { TopicTree } from "./TopicTree";

type Props = {
  catalog: LevelCatalog;
  locale: string;
  collapsedTopics: Set<string>;
  selectedTopicId: string;
  selectedLevelId: string;
  treeEditMode: boolean;
  selectedTopicIds: Set<string>;
  selectedLevelKeys: Set<string>;
  editingTopicId: string;
  editingLevelKey: string;
  levelModeStatus: Record<string, { polygon: boolean; knob: boolean; swap?: boolean }>;
  hasTreeSelection: boolean;
  loadingGodot: boolean;
  saving: boolean;
  dirty: boolean;
  onSaveToGodot: () => void;
  onResetFromGodot: () => void;
  onToggleEditMode: () => void;
  onRequestDelete: () => void;
  onCreateTopic: () => void;
  onCreateLevel: () => void;
  onDragEnd: (event: DragEndEvent) => void;
  onToggleTopicCollapse: (topicId: string) => void;
  onSelectTopic: (topic: CatalogTopic) => void;
  onSelectLevel: (topicId: string, levelId: string) => void;
  onToggleTopicSelection: (topic: CatalogTopic, checked: boolean) => void;
  onToggleLevelSelection: (topic: CatalogTopic, level: CatalogLevel, checked: boolean) => void;
  onStartRenameTopic: (topicId: string) => void;
  onStartRenameLevel: (key: string) => void;
  onRenameTopic: (topicId: string, name: string) => void;
  onRenameLevel: (topicId: string, levelId: string, title: string) => void;
};

export function CatalogTreeAside({
  catalog,
  locale,
  collapsedTopics,
  selectedTopicId,
  selectedLevelId,
  treeEditMode,
  selectedTopicIds,
  selectedLevelKeys,
  editingTopicId,
  editingLevelKey,
  levelModeStatus,
  hasTreeSelection,
  loadingGodot,
  saving,
  dirty,
  onSaveToGodot,
  onResetFromGodot,
  onToggleEditMode,
  onRequestDelete,
  onCreateTopic,
  onCreateLevel,
  onDragEnd,
  onToggleTopicCollapse,
  onSelectTopic,
  onSelectLevel,
  onToggleTopicSelection,
  onToggleLevelSelection,
  onStartRenameTopic,
  onStartRenameLevel,
  onRenameTopic,
  onRenameLevel,
}: Props) {
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));
  return (
    <aside className="min-h-0 overflow-auto border-r border-stone-300 bg-paper p-4">
      <div className="flex items-start justify-between gap-3 border-b border-stone-300 pb-4">
        <div className="flex min-w-0 items-start gap-3">
          <Layers className="mt-1 shrink-0 text-clay" size={22} />
          <div className="min-w-0">
            <h1 className="text-xl font-semibold">关卡管理</h1>
            <p className="text-sm text-muted">主题 / 关卡 / 封面</p>
          </div>
        </div>
        <button className="btnPrimary shrink-0" disabled={loadingGodot || saving || !dirty} onClick={onSaveToGodot}>
          <Save size={16} />
          {saving ? "保存中..." : loadingGodot ? "读取中..." : "保存到 Godot"}
        </button>
      </div>
      <section className="mt-5 grid gap-3">
        <div className="flex items-center justify-between gap-2">
          <PanelTitle>关卡树</PanelTitle>
          <div className="flex items-center gap-2">
            <WithTooltip label="从 Godot 重置">
              <button className="iconBtn" disabled={loadingGodot || saving} onClick={onResetFromGodot} aria-label="从 Godot 重置">
                <RotateCcw size={16} />
              </button>
            </WithTooltip>
            <WithTooltip label={treeEditMode ? "退出编辑模式" : "编辑关卡树"}>
              <button className={treeEditMode ? "iconBtnActive" : "iconBtn"} disabled={loadingGodot} onClick={onToggleEditMode} aria-label={treeEditMode ? "退出编辑模式" : "编辑关卡树"}>
                <Pencil size={16} />
              </button>
            </WithTooltip>
            {treeEditMode && hasTreeSelection && (
              <WithTooltip label="删除选中">
                <button className="iconBtnDanger" disabled={loadingGodot} onClick={onRequestDelete} aria-label="删除选中">
                  <Trash2 size={16} />
                </button>
              </WithTooltip>
            )}
            <WithTooltip label="创建主题">
              <button className="iconBtn" disabled={loadingGodot} onClick={onCreateTopic} aria-label="创建主题">
                <FolderPlus size={16} />
              </button>
            </WithTooltip>
            <WithTooltip label="创建关卡">
              <button className="iconBtn" disabled={loadingGodot || !catalog.topics.length} onClick={onCreateLevel} aria-label="创建关卡">
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
                  onToggle={() => onToggleTopicCollapse(topic.id)}
                  onSelectTopic={() => onSelectTopic(topic)}
                  onSelectLevel={onSelectLevel}
                  onToggleTopicSelection={onToggleTopicSelection}
                  onToggleLevelSelection={onToggleLevelSelection}
                  onStartRenameTopic={onStartRenameTopic}
                  onStartRenameLevel={onStartRenameLevel}
                  onRenameTopic={onRenameTopic}
                  onRenameLevel={onRenameLevel}
                />
              ))}
              {loadingGodot && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">正在读取 Godot 关卡...</div>}
              {!loadingGodot && !catalog.topics.length && <div className="rounded-md border border-dashed border-stone-300 bg-white/70 px-3 py-4 text-sm text-muted">暂无主题。</div>}
            </div>
          </SortableContext>
        </DndContext>
      </section>
    </aside>
  );
}
