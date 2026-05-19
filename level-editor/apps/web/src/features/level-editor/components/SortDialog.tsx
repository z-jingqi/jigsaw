import { DndContext, closestCenter, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import * as Dialog from "@radix-ui/react-dialog";
import { GripVertical, X } from "lucide-react";
import type { CatalogTopic, LevelCatalog } from "../../../types";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import { localized } from "../../../shared/lib/i18n";

type LevelTarget = {
  topicId: string;
  levelId: string;
};

export function SortDialog({
  open,
  onOpenChange,
  sensors,
  catalog,
  currentTopic,
  locale,
  currentTarget,
  onDragEnd,
  onSave,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  sensors: any;
  catalog: LevelCatalog;
  currentTopic?: CatalogTopic;
  locale: string;
  currentTarget: LevelTarget;
  onDragEnd: (event: DragEndEvent) => void;
  onSave: () => void;
}) {
  const topicIds = catalog.topics.map((topic) => `topic:${topic.id}`);
  const levelIds = (currentTopic?.levels || []).map((item) => `level:${item.id}`);
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="dialogOverlay" />
        <Dialog.Content className="dialogContent">
          <div className="flex items-start justify-between gap-4">
            <div>
              <Dialog.Title className="text-xl font-semibold text-ink">排序</Dialog.Title>
              <Dialog.Description className="mt-1 text-sm text-muted">拖拽调整主题和当前主题下的关卡顺序。</Dialog.Description>
            </div>
            <Dialog.Close className="iconBtn" aria-label="关闭">
              <X size={18} />
            </Dialog.Close>
          </div>
          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
            <div className="mt-5 grid grid-cols-2 gap-4 max-sm:grid-cols-1">
              <section className="grid gap-2">
                <PanelTitle>主题</PanelTitle>
                <SortableContext items={topicIds} strategy={verticalListSortingStrategy}>
                  {catalog.topics.map((topic) => (
                    <SortableRow
                      key={topic.id}
                      id={`topic:${topic.id}`}
                      label={localized(topic.name_i18n, locale, topic.name)}
                      detail={`${topic.levels.length}`}
                      active={topic.id === currentTarget.topicId}
                    />
                  ))}
                </SortableContext>
              </section>
              <section className="grid gap-2">
                <PanelTitle>关卡</PanelTitle>
                <SortableContext items={levelIds} strategy={verticalListSortingStrategy}>
                  {(currentTopic?.levels || []).map((item) => (
                    <SortableRow
                      key={item.id}
                      id={`level:${item.id}`}
                      label={localized(item.title_i18n, locale, item.title)}
                      detail={item.id}
                      active={item.id === currentTarget.levelId}
                    />
                  ))}
                </SortableContext>
              </section>
            </div>
          </DndContext>
          <div className="mt-5 flex justify-end gap-2">
            <button className="btn" onClick={onSave}>
              保存关卡
            </button>
            <Dialog.Close className="btnPrimary">完成</Dialog.Close>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function SortableRow({ id, label, detail, active }: { id: string; label: string; detail: string; active: boolean }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });
  return (
    <div
      ref={setNodeRef}
      className={`${active ? "sortRowActive" : "sortRow"} ${isDragging ? "opacity-70" : ""}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      {...attributes}
      {...listeners}
    >
      <GripVertical size={16} />
      <span className="min-w-0 truncate">{label}</span>
      <small className="ml-auto text-muted">{detail}</small>
    </div>
  );
}
