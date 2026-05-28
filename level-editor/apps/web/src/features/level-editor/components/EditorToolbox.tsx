import { Magnet, Plus, Redo2, Trash2, Undo2, X } from "lucide-react";
import { WithTooltip } from "../../../components/ui/tooltip";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import type { EditMode } from "../types";

type Props = {
  activeMode: EditMode;
  canUndo: boolean;
  canRedo: boolean;
  snapEnabled: boolean;
  hasSelectedCut: boolean;
  hasCuts: boolean;
  cutLineColor: string;
  onCutLineColorChange: (value: string) => void;
  onUndo: () => void;
  onRedo: () => void;
  onToggleSnap: () => void;
  onMerge: () => void;
  onRemoveSelected: () => void;
  onClearCuts: () => void;
};

export function EditorToolbox({
  activeMode,
  canUndo,
  canRedo,
  snapEnabled,
  hasSelectedCut,
  hasCuts,
  cutLineColor,
  onCutLineColorChange,
  onUndo,
  onRedo,
  onToggleSnap,
  onMerge,
  onRemoveSelected,
  onClearCuts,
}: Props) {
  if (activeMode === "swap") {
    return (
      <section className="grid gap-3">
        <PanelTitle>工具</PanelTitle>
        <div className="rounded-md border border-stone-200 bg-white/70 px-3 py-3 text-sm text-muted">
          方格交换模式使用固定 3x4 网格，不需要手动切割。选择图片后直接标记完成并保存模式。
        </div>
      </section>
    );
  }
  return (
    <section className="grid gap-3">
      <PanelTitle>工具</PanelTitle>
      <div className="grid grid-cols-6 items-center gap-2">
        <WithTooltip label="撤销 (Cmd/Ctrl+Z)">
          <button className="iconBtn" disabled={!canUndo} onClick={onUndo} aria-label="撤销">
            <Undo2 size={18} />
          </button>
        </WithTooltip>
        <WithTooltip label="重做 (Cmd/Ctrl+Shift+Z / Cmd/Ctrl+Y)">
          <button className="iconBtn" disabled={!canRedo} onClick={onRedo} aria-label="重做">
            <Redo2 size={18} />
          </button>
        </WithTooltip>
        <WithTooltip label="吸附">
          <button className={snapEnabled ? "iconBtnActive" : "iconBtn"} onClick={onToggleSnap} aria-label="吸附">
            <Magnet size={18} />
          </button>
        </WithTooltip>
        <WithTooltip label="合并">
          <button className="iconBtnActive" onClick={onMerge} aria-label="合并">
            <Plus size={18} />
          </button>
        </WithTooltip>
        {activeMode === "polygon" && (
          <WithTooltip label="删除选中线条 (Backspace)">
            <button className="iconBtnDanger" disabled={!hasSelectedCut} onClick={onRemoveSelected} aria-label="删除选中线条">
              <Trash2 size={18} />
            </button>
          </WithTooltip>
        )}
        {activeMode === "polygon" && (
          <WithTooltip label="清空线条">
            <button className="iconBtnDanger" disabled={!hasCuts} onClick={onClearCuts} aria-label="清空线条">
              <X size={18} />
            </button>
          </WithTooltip>
        )}
        <WithTooltip label="线条颜色">
          <input
            className="h-9 w-full cursor-pointer rounded-md border border-stone-300 bg-white p-1"
            type="color"
            value={cutLineColor}
            onChange={(event) => onCutLineColorChange(event.target.value)}
            aria-label="线条颜色"
          />
        </WithTooltip>
      </div>
    </section>
  );
}
