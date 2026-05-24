type Props = {
  open: boolean;
  onCancel: () => void;
  onConfirm: () => void;
};

export function PendingSelectionDialog({ open, onCancel, onConfirm }: Props) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/35 px-4">
      <div className="w-full max-w-md rounded-md border border-stone-300 bg-paper p-5 text-ink shadow-xl">
        <h2 className="text-lg font-semibold">当前处理结果尚未确认</h2>
        <p className="mt-2 text-sm text-muted">切换图片前，请确认或放弃当前处理结果。继续切换会保留当前待确认结果，但你之后需要回到这张图片处理。</p>
        <div className="mt-5 grid grid-cols-2 gap-2">
          <button className="btn" onClick={onCancel}>
            留在当前
          </button>
          <button className="btnPrimary" onClick={onConfirm}>
            继续切换
          </button>
        </div>
      </div>
    </div>
  );
}
