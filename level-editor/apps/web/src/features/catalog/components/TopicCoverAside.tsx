import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { Image as ImageIcon, RotateCcw, Upload } from "lucide-react";
import type { CatalogTopic, ProcessStep, PythonTool } from "../../../types";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import { topicCoverUrl } from "../../../shared/lib/catalog";
import { fallbackPythonTool } from "../../../shared/lib/processSteps";
import { CoverStepRow } from "./CoverStepRow";

type Props = {
  selectedTopic: CatalogTopic | undefined;
  loadingGodot: boolean;
  coverLoadError: boolean;
  onCoverLoadError: () => void;
  onUploadCover: (file: File | undefined) => void;
  coverSteps: ProcessStep[];
  pythonTools: PythonTool[];
  disabledCoverStepIds: Set<string>;
  onResetCoverSteps: () => void;
  onUpdateCoverStep: (id: string, patch: Partial<ProcessStep>) => void;
  onToggleCoverStepEnabled: (id: string, enabled: boolean) => void;
  onCoverStepDragEnd: (event: DragEndEvent) => void;
  processingCover: boolean;
  onProcessCover: () => void;
};

export function TopicCoverAside({
  selectedTopic,
  loadingGodot,
  coverLoadError,
  onCoverLoadError,
  onUploadCover,
  coverSteps,
  pythonTools,
  disabledCoverStepIds,
  onResetCoverSteps,
  onUpdateCoverStep,
  onToggleCoverStepEnabled,
  onCoverStepDragEnd,
  processingCover,
  onProcessCover,
}: Props) {
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));
  const hasCover = Boolean(selectedTopic?.cover && !coverLoadError);

  return (
    <aside className="min-h-0 overflow-auto border-l border-stone-300 bg-paper p-4">
      <section className="grid gap-3">
        <PanelTitle>主题封面</PanelTitle>
        <label
          className={[
            "group relative grid min-h-36 cursor-pointer place-items-center overflow-hidden rounded-md border bg-white/70 transition hover:border-clay",
            hasCover ? "border-stone-300" : "border-dashed border-stone-300",
            loadingGodot || !selectedTopic ? "pointer-events-none opacity-60" : "",
          ].join(" ")}
        >
          {hasCover && selectedTopic ? (
            <>
              <img className="max-h-56 w-full object-contain" src={topicCoverUrl(selectedTopic)} alt="主题封面" onError={onCoverLoadError} />
              <span className="absolute inset-0 grid place-items-center bg-black/0 text-sm font-medium text-white opacity-0 transition group-hover:bg-black/35 group-hover:opacity-100">
                点击上传封面
              </span>
            </>
          ) : (
            <span className="grid place-items-center gap-2 text-sm text-muted">
              <span>{coverLoadError ? "封面加载失败" : "暂无封面"}</span>
              <span className="btn pointer-events-none">
                <Upload size={16} />
                上传封面
              </span>
            </span>
          )}
          <input hidden disabled={loadingGodot} type="file" accept="image/*" onChange={(event) => onUploadCover(event.target.files?.[0])} />
        </label>
      </section>

      <section className="mt-5 grid gap-3 border-t border-stone-300 pt-4">
        <div className="flex items-center justify-between gap-2">
          <PanelTitle>封面处理</PanelTitle>
          <button className="btn !min-h-8 px-2 py-1 text-xs" onClick={onResetCoverSteps}>
            <RotateCcw size={14} />
            默认
          </button>
        </div>
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onCoverStepDragEnd}>
          <SortableContext items={coverSteps.map((step) => step.id)} strategy={verticalListSortingStrategy}>
            <div className="grid gap-2">
              {coverSteps.map((step) => (
                <CoverStepRow
                  key={step.id}
                  step={step}
                  tool={pythonTools.find((tool) => tool.stepType === step.type) || fallbackPythonTool(step.type)}
                  disabled={disabledCoverStepIds.has(step.id)}
                  onUpdate={(patch) => onUpdateCoverStep(step.id, patch)}
                  onEnabledChange={(checked) => onToggleCoverStepEnabled(step.id, checked)}
                />
              ))}
            </div>
          </SortableContext>
        </DndContext>
        <button className="btnPrimary" disabled={loadingGodot || !selectedTopic?.cover || processingCover} onClick={onProcessCover}>
          <ImageIcon size={16} />
          {processingCover ? "处理中..." : "处理封面"}
        </button>
      </section>
    </aside>
  );
}
