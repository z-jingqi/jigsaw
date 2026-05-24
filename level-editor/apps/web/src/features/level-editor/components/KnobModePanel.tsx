import { Eye } from "lucide-react";
import { Field } from "../../../shared/ui/Field";
import { Input } from "../../../shared/ui/Input";
import { PanelTitle } from "../../../shared/ui/PanelTitle";
import type { LevelConfig } from "../../../types";

type GridDraft = { cols: string; rows: string; piece_size: string };

type Props = {
  showKnobPieces: boolean;
  onToggleShowKnobPieces: () => void;
  draft: GridDraft;
  onDraftChange: (draft: GridDraft) => void;
  onCommitDraft: (key: keyof LevelConfig["grid"]) => void;
  knobSize: number;
  onKnobSizeChange: (value: number) => void;
};

export function KnobModePanel({
  showKnobPieces,
  onToggleShowKnobPieces,
  draft,
  onDraftChange,
  onCommitDraft,
  knobSize,
  onKnobSizeChange,
}: Props) {
  return (
    <section className="grid gap-3 border-t border-stone-300 pt-4">
      <PanelTitle>凹凸</PanelTitle>
      <button className={showKnobPieces ? "btnActive" : "btn"} onClick={onToggleShowKnobPieces}>
        <Eye size={16} />
        预览
      </button>
      <div className="grid grid-cols-2 gap-2">
        <Field label="列">
          <Input
            type="number"
            min="1"
            max="12"
            step="1"
            value={draft.cols}
            onChange={(event) => onDraftChange({ ...draft, cols: event.target.value })}
            onBlur={() => onCommitDraft("cols")}
            onKeyDown={(event) => {
              if (event.key === "Enter") event.currentTarget.blur();
            }}
          />
        </Field>
        <Field label="行">
          <Input
            type="number"
            min="1"
            max="12"
            step="1"
            value={draft.rows}
            onChange={(event) => onDraftChange({ ...draft, rows: event.target.value })}
            onBlur={() => onCommitDraft("rows")}
            onKeyDown={(event) => {
              if (event.key === "Enter") event.currentTarget.blur();
            }}
          />
        </Field>
      </div>
      <Field label="尺寸">
        <Input
          type="number"
          min="80"
          max="320"
          step="10"
          value={draft.piece_size}
          onChange={(event) => onDraftChange({ ...draft, piece_size: event.target.value })}
          onBlur={() => onCommitDraft("piece_size")}
          onKeyDown={(event) => {
            if (event.key === "Enter") event.currentTarget.blur();
          }}
        />
      </Field>
      <Field label={`凸耳 ${knobSize.toFixed(2)}`}>
        <input
          type="range"
          min="0.12"
          max="0.36"
          step="0.01"
          value={knobSize}
          onChange={(event) => onKnobSizeChange(Number(event.target.value))}
        />
      </Field>
    </section>
  );
}
