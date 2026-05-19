import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { GripVertical, Hexagon, Puzzle } from "lucide-react";
import type { CatalogLevel } from "../../../types";
import { localized } from "../../../shared/lib/i18n";
import { InlineTreeName } from "./InlineTreeName";

export function LevelTreeRow({
  topicId,
  level,
  locale,
  editMode,
  checked,
  editing,
  active,
  modes,
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
  modes?: { polygon: boolean; knob: boolean };
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
      {(modes?.polygon || modes?.knob) && (
        <div className="flex shrink-0 items-center gap-1 text-clay" aria-label="已保存模式">
          {modes.polygon && <Hexagon size={14} aria-label="多边形模式" />}
          {modes.knob && <Puzzle size={14} aria-label="凹凸模式" />}
        </div>
      )}
    </div>
  );
}
