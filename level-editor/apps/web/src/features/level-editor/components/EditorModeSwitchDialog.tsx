import type { EditMode } from "../types";

type Props = {
  pendingMode: EditMode | null;
  onCancel: () => void;
  onConfirm: () => void;
};

export function EditorModeSwitchDialog({ pendingMode, onCancel, onConfirm }: Props) {
  if (!pendingMode) return null;
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="w-full max-w-md rounded-lg border border-stone-300 bg-paper p-5 text-ink shadow-xl">
        <h2 className="text-xl font-semibold">当前模式有未保存修改</h2>
        <p className="mt-2 text-sm text-muted">切换到其他模式前，建议先保存到 Godot。继续切换不会丢弃当前数据，但这些修改仍会保持未保存状态。</p>
        <div className="mt-5 grid grid-cols-2 gap-2">
          <button className="btn" onClick={onCancel}>
            继续编辑
          </button>
          <button className="btnPrimary" onClick={onConfirm}>
            切换模式
          </button>
        </div>
      </div>
    </div>
  );
}
