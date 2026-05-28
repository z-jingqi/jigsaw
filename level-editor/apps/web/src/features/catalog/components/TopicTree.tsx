import { SortableContext, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { ChevronDown, ChevronRight, GripVertical } from "lucide-react";
import type { CatalogLevel, CatalogTopic } from "../../../types";
import { levelKey } from "../../../shared/lib/ids";
import { localized } from "../../../shared/lib/i18n";
import { InlineTreeName } from "./InlineTreeName";
import { LevelTreeRow } from "./LevelTreeRow";

export function TopicTree({
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
  levelModeStatus,
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
  levelModeStatus: Record<string, { polygon: boolean; knob: boolean; swap?: boolean }>;
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
                modes={levelModeStatus[levelKey(topic.id, level.id)]}
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
