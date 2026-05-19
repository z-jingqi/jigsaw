import { CSS } from "@dnd-kit/utilities";
import { useSortable } from "@dnd-kit/sortable";
import type { ProcessStep, PythonTool } from "../../../types";
import { InlineControl } from "../../../shared/ui/InlineControl";

export function CoverStepRow({
  step,
  tool,
  onUpdate,
  onEnabledChange,
  disabled = false,
}: {
  step: ProcessStep;
  tool: PythonTool;
  onUpdate: (patch: Partial<ProcessStep>) => void;
  onEnabledChange: (checked: boolean) => void;
  disabled?: boolean;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: step.id });
  return (
    <div
      ref={setNodeRef}
      className={`rounded-md border border-stone-300 bg-white p-2 text-sm ${disabled ? "opacity-55" : ""} ${isDragging ? "opacity-70" : ""}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
    >
      <label className="flex cursor-grab items-center gap-2 active:cursor-grabbing" {...attributes} {...listeners}>
        <input className="h-4 w-4 cursor-default accent-clay" type="checkbox" checked={!disabled} onPointerDown={(event) => event.stopPropagation()} onChange={(event) => onEnabledChange(event.target.checked)} />
        <span className="min-w-0 flex-1 font-medium">{tool.label}</span>
      </label>
      {step.type === "remove_background" && (
        <InlineControl label="容差">
          <input className="input" type="number" min="0" max="441" value={step.tolerance} disabled={disabled} onChange={(event) => onUpdate({ tolerance: Number(event.target.value) })} />
        </InlineControl>
      )}
      {step.type === "trim_transparent" && (
        <InlineControl label="留边">
          <input className="input" type="number" min="0" max="256" value={step.padding} disabled={disabled} onChange={(event) => onUpdate({ padding: Number(event.target.value) })} />
        </InlineControl>
      )}
      {(step.type === "convert_jpg" || step.type === "compress") && (
        <InlineControl label="质量">
          <input className="input" type="number" min="1" max="100" value={step.quality} disabled={disabled} onChange={(event) => onUpdate({ quality: Number(event.target.value) })} />
        </InlineControl>
      )}
      {step.type === "convert_jpg" && (
        <InlineControl label="底色">
          <input className="input h-10 p-1" type="color" value={step.background} disabled={disabled} onChange={(event) => onUpdate({ background: event.target.value })} />
        </InlineControl>
      )}
    </div>
  );
}
