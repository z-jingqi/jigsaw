import { CircleAlert, Eye, Pencil, Plus } from "lucide-react";
import { WithTooltip } from "../../../components/ui/tooltip";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import type { CutTemplate } from "../../../types";
import { presetTemplates, ShapeButton } from "../lib/shapes";
import type { PolygonViewMode } from "../types";

type Props = {
  polygonView: PolygonViewMode;
  onPolygonViewChange: (view: PolygonViewMode) => void;
  lineToolActive: boolean;
  onToggleLineTool: () => void;
  onAddPreset: (template: CutTemplate) => void;
  analyzing: boolean;
};

const polygonViews: PolygonViewMode[] = ["result", "edit", "inspect"];

function viewIcon(view: PolygonViewMode) {
  if (view === "result") return <Eye size={18} />;
  if (view === "edit") return <Pencil size={18} />;
  return <CircleAlert size={18} />;
}

function viewLabel(view: PolygonViewMode) {
  if (view === "result") return "结果";
  if (view === "edit") return "编辑";
  return "检查";
}

export function PolygonModePanel({
  polygonView,
  onPolygonViewChange,
  lineToolActive,
  onToggleLineTool,
  onAddPreset,
  analyzing,
}: Props) {
  return (
    <section className="flex min-h-0 flex-1 flex-col gap-3 border-t border-stone-300 pt-4">
      <div className="flex items-center justify-between">
        <PanelTitle>多边形</PanelTitle>
        {analyzing && <span className="text-xs text-muted">正在更新碎片…</span>}
      </div>
      <div className="grid grid-cols-3 gap-2">
        {polygonViews.map((view) => (
          <WithTooltip key={view} label={viewLabel(view)}>
            <button
              className={polygonView === view ? "iconBtnActive" : "iconBtn"}
              onClick={() => onPolygonViewChange(view)}
              aria-label={viewLabel(view)}
            >
              {viewIcon(view)}
            </button>
          </WithTooltip>
        ))}
      </div>
      <button className={lineToolActive ? "btnActive" : "btn"} onClick={onToggleLineTool}>
        <Plus size={16} />
        添加线段
      </button>
      <div className="grid min-h-0 flex-1 grid-cols-3 content-start gap-2 overflow-auto pr-1">
        {presetTemplates.map((template) => (
          <ShapeButton key={template} template={template} onClick={() => onAddPreset(template)} />
        ))}
      </div>
    </section>
  );
}
