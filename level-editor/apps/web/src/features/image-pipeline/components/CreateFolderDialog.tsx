import { Check } from "lucide-react";
import type { PendingImageKind } from "../../../types";
import { kindLabel } from "../lib/display";

type Props = {
  open: boolean;
  kind: PendingImageKind;
  name: string;
  onNameChange: (value: string) => void;
  onCancel: () => void;
  onConfirm: () => void;
};

export function CreateFolderDialog({ open, kind, name, onNameChange, onCancel, onConfirm }: Props) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
        <h2 className="text-lg font-semibold">创建{kindLabel(kind)}文件夹</h2>
        <p className="mt-2 text-sm text-muted">文件夹可用于整理{kindLabel(kind)}。</p>
        <input
          className="input mt-4"
          autoFocus
          value={name}
          placeholder="新文件夹"
          onChange={(event) => onNameChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") onConfirm();
            if (event.key === "Escape") onCancel();
          }}
        />
        <div className="mt-5 grid grid-cols-2 gap-2">
          <button className="btn" onClick={onCancel}>
            取消
          </button>
          <button className="btnPrimary" onClick={onConfirm}>
            <Check size={16} />
            创建
          </button>
        </div>
      </div>
    </div>
  );
}
