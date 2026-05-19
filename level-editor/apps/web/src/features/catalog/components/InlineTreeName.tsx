import { useEffect, useState } from "react";
import { Pencil } from "lucide-react";
import { WithTooltip } from "../../../components/ui/tooltip";

export function InlineTreeName({
  value,
  active,
  editMode,
  editing,
  onStart,
  onCommit,
}: {
  value: string;
  active: boolean;
  editMode: boolean;
  editing: boolean;
  onStart: () => void;
  onCommit: (value: string) => void;
}) {
  const [draft, setDraft] = useState(value);

  useEffect(() => {
    if (editing) setDraft(value);
  }, [editing, value]);

  if (editing) {
    return (
      <input
        className="input h-8 min-w-0 px-2 py-1"
        autoFocus
        value={draft}
        onClick={(event) => event.stopPropagation()}
        onMouseDown={(event) => event.stopPropagation()}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={() => onCommit(draft)}
        onKeyDown={(event) => {
          if (event.key === "Enter") event.currentTarget.blur();
          if (event.key === "Escape") {
            event.preventDefault();
            onCommit(value);
          }
        }}
      />
    );
  }

  return (
    <span className="group/rename flex min-w-0 items-center gap-1 text-sm">
      <span className={`min-w-0 flex-1 truncate text-left font-medium ${active ? "text-clay" : "text-ink"}`}>{value}</span>
      {editMode && (
        <WithTooltip label="重命名">
          <button
            className="editReveal shrink-0 rounded p-1 text-muted transition hover:bg-stone-100 hover:text-clay"
            onClick={(event) => {
              event.stopPropagation();
              onStart();
            }}
            aria-label={`重命名 ${value}`}
          >
            <Pencil size={13} />
          </button>
        </WithTooltip>
      )}
    </span>
  );
}
