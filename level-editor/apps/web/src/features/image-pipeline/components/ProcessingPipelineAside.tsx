import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { Check, RotateCcw } from "lucide-react";
import type { PendingImageItem, ProcessStep, ProcessStepType, PythonTool } from "../../../types";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import { fallbackPythonTool } from "../../../shared/lib/processSteps";
import { ProcessStepRow } from "./ProcessStepRow";
import { PythonToolRow } from "./PythonToolRow";

type Props = {
  steps: ProcessStep[];
  pythonTools: PythonTool[];
  inactiveTools: PythonTool[];
  selectedPending: PendingImageItem | undefined;
  hasProcessedPreview: boolean;
  usableSteps: ProcessStep[];
  processing: boolean;
  confirming: boolean;
  rejecting: boolean;
  canUseStep: (type: ProcessStepType, item?: PendingImageItem) => boolean;
  disabledStepReason: (type: ProcessStepType, item?: PendingImageItem) => string;
  onResetStepsToDefault: () => void;
  onUpdateStep: (id: string, patch: Partial<ProcessStep>) => void;
  onRemoveStep: (id: string) => void;
  onAddStep: (type: ProcessStepType) => void;
  onStepDragEnd: (event: DragEndEvent) => void;
  onProcessSelected: () => void;
  onConfirmProcessed: () => void;
  onRejectProcessed: () => void;
};

export function ProcessingPipelineAside({
  steps,
  pythonTools,
  inactiveTools,
  selectedPending,
  hasProcessedPreview,
  usableSteps,
  processing,
  confirming,
  rejecting,
  canUseStep,
  disabledStepReason,
  onResetStepsToDefault,
  onUpdateStep,
  onRemoveStep,
  onAddStep,
  onStepDragEnd,
  onProcessSelected,
  onConfirmProcessed,
  onRejectProcessed,
}: Props) {
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  return (
    <aside className="min-h-0 overflow-auto border-l border-stone-300 bg-paper p-4">
      <section className="grid gap-3">
        <div className="flex items-center justify-between gap-2">
          <PanelTitle>处理链</PanelTitle>
          <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={onResetStepsToDefault}>
            <RotateCcw size={14} />
            恢复默认
          </button>
        </div>
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onStepDragEnd}>
          <SortableContext items={steps.map((step) => step.id)} strategy={verticalListSortingStrategy}>
            <div className="grid gap-2">
              {steps.map((step) => (
                <ProcessStepRow
                  key={step.id}
                  step={step}
                  tool={pythonTools.find((candidate) => candidate.stepType === step.type) || fallbackPythonTool(step.type)}
                  disabled={!canUseStep(step.type, selectedPending)}
                  disabledReason={disabledStepReason(step.type, selectedPending)}
                  onUpdate={(patch) => onUpdateStep(step.id, patch)}
                  onEnabledChange={(checked) => {
                    if (!checked) onRemoveStep(step.id);
                  }}
                />
              ))}
            </div>
          </SortableContext>
        </DndContext>
        <div className="grid gap-2">
          {inactiveTools.map((tool) => (
            <PythonToolRow
              key={tool.name}
              tool={tool}
              disabled={Boolean(tool.stepType && !canUseStep(tool.stepType, selectedPending))}
              disabledReason={tool.stepType ? disabledStepReason(tool.stepType, selectedPending) : ""}
              onEnabledChange={(checked) => {
                if (checked && tool.stepType) onAddStep(tool.stepType);
              }}
            />
          ))}
        </div>
        <button className="btnPrimary" disabled={processing || !selectedPending || hasProcessedPreview || !usableSteps.length} onClick={onProcessSelected}>
          <Check size={16} />
          {processing ? "处理中..." : "处理当前图片"}
        </button>
        {selectedPending?.processed_path && (
          <div className="grid grid-cols-2 gap-2">
            <button className="btnPrimary" disabled={confirming} onClick={onConfirmProcessed}>
              <Check size={16} />
              {confirming ? "确认中..." : "确认使用"}
            </button>
            <button className="btn" disabled={rejecting} onClick={onRejectProcessed}>
              {rejecting ? "放弃中..." : "放弃并继续"}
            </button>
          </div>
        )}
      </section>
    </aside>
  );
}
