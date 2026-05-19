import type { PythonTool } from "../../../types";

export function PythonToolRow({
  tool,
  disabled,
  disabledReason,
  onEnabledChange,
}: {
  tool: PythonTool;
  disabled: boolean;
  disabledReason: string;
  onEnabledChange: (checked: boolean) => void;
}) {
  return (
    <label
      className={`flex items-start gap-2 rounded-md border px-3 py-2 text-sm ${
        tool.supported && !disabled ? "border-stone-300 bg-stone-100/80 text-ink" : "border-stone-200 bg-stone-100/70 text-muted opacity-70"
      }`}
    >
      <input
        className="mt-0.5 h-4 w-4 accent-clay disabled:accent-stone-300"
        type="checkbox"
        disabled={!tool.supported || !tool.stepType || disabled}
        checked={false}
        onChange={(event) => onEnabledChange(event.target.checked)}
      />
      <span className="min-w-0 flex-1">
        <span className="block font-medium">{tool.label}</span>
        <span className="mt-1 block text-xs text-muted">{disabledReason || tool.description}</span>
      </span>
    </label>
  );
}
