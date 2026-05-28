import { Hexagon, Puzzle, Save } from "lucide-react";
import { ToggleGroup, ToggleGroupItem } from "../../../components/ui/toggle-group";
import { WithTooltip } from "../../../components/ui/tooltip";
import { SelectBox, type SelectOption } from "../../../shared/ui/SelectBox";
import type { EditMode } from "../types";

type Props = {
  activeMode: EditMode;
  onModeChange: (mode: EditMode) => void;
  dirtyModes: Record<EditMode, boolean>;
  completedModes: Record<EditMode, boolean>;
  activeImageId: string;
  imageOptions: SelectOption[];
  onSelectImage: (id: string) => void;
  activeSaveStatus: string;
  canSaveToGodot: boolean;
  onMarkComplete: () => void;
  onOpenSaveDialog: () => void;
};

export function EditorTopBar({
  activeMode,
  onModeChange,
  dirtyModes,
  completedModes,
  activeImageId,
  imageOptions,
  onSelectImage,
  activeSaveStatus,
  canSaveToGodot,
  onMarkComplete,
  onOpenSaveDialog,
}: Props) {
  return (
    <div className="grid min-h-14 grid-cols-[1fr_minmax(260px,420px)_1fr] items-center gap-3 overflow-auto border-b border-stone-300 bg-[#f7efe2] px-3">
      <div className="flex min-w-0 items-center gap-3 justify-self-start">
        <ToggleGroup
          type="single"
          value={activeMode}
          onValueChange={(value: string) => {
            if (value === "polygon" || value === "knob" || value === "swap") onModeChange(value);
          }}
        >
          <WithTooltip label="多边形">
            <ToggleGroupItem
              value="polygon"
              aria-label="多边形"
              className={`relative gap-2 px-3 ${activeMode === "polygon" ? "bg-clay text-white shadow-[inset_0_0_0_1px_#a95f25] hover:bg-clay hover:text-white" : ""}`}
            >
              <Hexagon size={18} />
              <span>多边形</span>
              {(completedModes.polygon || dirtyModes.polygon) && <span className={completedModes.polygon ? "statusDot done" : "statusDot dirty"} />}
            </ToggleGroupItem>
          </WithTooltip>
          <WithTooltip label="凹凸">
            <ToggleGroupItem
              value="knob"
              aria-label="凹凸"
              className={`relative gap-2 px-3 ${activeMode === "knob" ? "bg-clay text-white shadow-[inset_0_0_0_1px_#a95f25] hover:bg-clay hover:text-white" : ""}`}
            >
              <Puzzle size={18} />
              <span>凹凸</span>
              {(completedModes.knob || dirtyModes.knob) && <span className={completedModes.knob ? "statusDot done" : "statusDot dirty"} />}
            </ToggleGroupItem>
          </WithTooltip>
          <WithTooltip label="方格交换">
            <ToggleGroupItem
              value="swap"
              aria-label="方格交换"
              className={`relative gap-2 px-3 ${activeMode === "swap" ? "bg-clay text-white shadow-[inset_0_0_0_1px_#a95f25] hover:bg-clay hover:text-white" : ""}`}
            >
              <span className="text-xs font-bold leading-none">3x4</span>
              <span>交换</span>
              {(completedModes.swap || dirtyModes.swap) && <span className={completedModes.swap ? "statusDot done" : "statusDot dirty"} />}
            </ToggleGroupItem>
          </WithTooltip>
        </ToggleGroup>
        {activeSaveStatus && (
          <span className={dirtyModes[activeMode] ? "text-sm font-medium text-amber-700" : "text-sm font-medium text-emerald-700"}>{activeSaveStatus}</span>
        )}
      </div>
      <div className="min-w-0">
        <SelectBox value={activeImageId} options={imageOptions} onValueChange={onSelectImage} placeholder="选择拼图图片" />
      </div>
      <div className="flex items-center gap-2 justify-self-end">
        <button className="btnPrimary" onClick={onMarkComplete}>
          完成
        </button>
        <button className="btnPrimary" disabled={!canSaveToGodot} onClick={onOpenSaveDialog}>
          <Save size={16} />
          保存模式
        </button>
      </div>
    </div>
  );
}
