import { CheckCircle2, ChevronDown, ChevronRight, Hexagon, Puzzle } from "lucide-react";
import type { PendingImageItem } from "../../../types";
import { displayName, pendingImageRowId } from "../lib/display";
import { InlineEditableName } from "./InlineEditableName";

export function FolderGroup({
  folder,
  label,
  items,
  droppable,
  collapsed,
  editMode,
  selectedPendingId,
  selectedImageIds,
  selectedFolders,
  dragOverFolder,
  onSelectPending,
  onToggleImage,
  onToggleFolder,
  onToggleCollapsed,
  editingImageId,
  editingFolder,
  onStartRenameImage,
  onStartRenameFolder,
  onRenameImage,
  onRenameFolder,
  onMoveImages,
  onDragStart,
  onDragOverFolder,
}: {
  folder: string;
  label: string;
  items: PendingImageItem[];
  droppable: boolean;
  collapsed: boolean;
  editMode: boolean;
  selectedPendingId: string;
  selectedImageIds: Set<string>;
  selectedFolders: Set<string>;
  dragOverFolder: string | null;
  onSelectPending: (id: string) => void;
  onToggleImage: (id: string, checked: boolean) => void;
  onToggleFolder: (folder: string, checked: boolean) => void;
  onToggleCollapsed: (folder: string) => void;
  editingImageId: string;
  editingFolder: string;
  onStartRenameImage: (id: string) => void;
  onStartRenameFolder: (folder: string) => void;
  onRenameImage: (id: string, name: string) => void;
  onRenameFolder: (oldName: string, nextName: string) => void;
  onMoveImages: (ids: string[], folder: string) => void;
  onDragStart: (item: PendingImageItem, event: React.DragEvent) => void;
  onDragOverFolder: (folder: string | null) => void;
}) {
  const canSelectFolder = folder !== "";
  const activeDrop = droppable && dragOverFolder === folder;
  return (
    <section
      className={`rounded-md border ${activeDrop ? "border-clay bg-white" : "border-stone-300 bg-white/60"} p-2`}
      onDragOver={(event) => {
        if (!droppable) return;
        event.preventDefault();
        onDragOverFolder(folder);
      }}
      onDragLeave={() => onDragOverFolder(null)}
      onDrop={(event) => {
        if (!droppable) return;
        event.preventDefault();
        onDragOverFolder(null);
        const raw = event.dataTransfer.getData("application/x-jigcat-pending-ids");
        if (!raw) return;
        const ids = JSON.parse(raw) as string[];
        onMoveImages(ids, folder);
      }}
    >
      <div className="mb-2 flex items-center justify-between gap-2 text-sm font-medium text-ink">
        <div className="flex min-w-0 items-center gap-2">
          {canSelectFolder ? (
            <button className="iconBtn !min-h-7 border-0 bg-transparent px-1 py-1 shadow-none" onClick={() => onToggleCollapsed(folder)} aria-label={collapsed ? "展开文件夹" : "收起文件夹"}>
              {collapsed ? <ChevronRight size={16} /> : <ChevronDown size={16} />}
            </button>
          ) : (
            <span className="w-7" />
          )}
          {editMode && canSelectFolder && (
            <input
              className="mr-2 h-4 w-4 shrink-0 accent-clay"
              type="checkbox"
              checked={selectedFolders.has(folder)}
              onChange={(event) => onToggleFolder(folder, event.target.checked)}
            />
          )}
          <InlineEditableName
            value={label}
            editMode={editMode && canSelectFolder}
            editing={editingFolder === folder}
            className="font-medium text-ink"
            onStart={() => onStartRenameFolder(folder)}
            onCommit={(value) => onRenameFolder(folder, value)}
          />
        </div>
        <small className="text-muted">{items.length}</small>
      </div>
      <div className={collapsed ? "hidden" : "grid gap-2"}>
        {items.length ? (
          items.map((item) => (
            <div
              id={pendingImageRowId(item.id)}
              key={item.id}
              className={item.id === selectedPendingId ? "objectActive" : "object"}
              draggable
              onClick={() => onSelectPending(item.id)}
              onDragStart={(event) => onDragStart(item, event)}
            >
              {editMode && (
                <input
                  className="h-4 w-4 shrink-0 accent-clay"
                  type="checkbox"
                  checked={selectedImageIds.has(item.id)}
                  onClick={(event) => event.stopPropagation()}
                  onChange={(event) => onToggleImage(item.id, event.target.checked)}
                />
              )}
              <div className={`flex min-w-0 flex-1 items-center gap-2 text-left ${editMode ? "ml-0" : ""}`}>
                <InlineEditableName
                  value={displayName(item.name)}
                  editMode={editMode}
                  editing={editingImageId === item.id}
                  className={item.processed && !item.processed_path ? "text-emerald-700" : "text-ink"}
                  onStart={() => onStartRenameImage(item.id)}
                  onCommit={(value) => onRenameImage(item.id, value)}
                />
                {item.processed_path && <span className="mr-1 shrink-0 rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-medium text-amber-700">待确认</span>}
                {modeStatusIcon(item, "polygon")}
                {modeStatusIcon(item, "knob")}
                {item.processed && !item.processed_path && <CheckCircle2 className="mr-1 shrink-0 text-emerald-700" size={16} />}
              </div>
            </div>
          ))
        ) : (
          <div className="rounded border border-dashed border-stone-200 px-3 py-2 text-xs text-muted">{droppable ? "拖拽图片到这里" : "暂无图片"}</div>
        )}
      </div>
    </section>
  );
}

function modeStatusIcon(item: PendingImageItem, mode: "polygon" | "knob") {
  const state = item.editor_state?.[mode];
  const saved = Boolean((item.saved_modes || []).includes(mode) || state?.saved);
  const edited = Boolean(saved || state?.dirty || state?.completed || state?.cuts?.length || state?.pieces?.length || state?.knob_pieces?.length);
  if (!edited) return null;
  const Icon = mode === "polygon" ? Hexagon : Puzzle;
  const label = `${mode === "polygon" ? "多边形" : "凹凸"}${saved ? "已保存" : "已编辑未保存"}`;
  return <Icon className={`shrink-0 ${saved ? "text-emerald-700" : "text-amber-700"}`} size={15} aria-label={label} />;
}
