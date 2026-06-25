import type { CSSProperties } from "react";

interface CompleteDialogProps {
  imageUrl: string;
  title: string;
  onConfirm: () => void;
}

export function CompleteDialog({ imageUrl, title, onConfirm }: CompleteDialogProps) {
  return (
    <div className="modal-backdrop modal-backdrop--strong" role="dialog" aria-modal="true">
      <div className="complete-fx" aria-hidden="true">
        {Array.from({ length: 16 }).map((_, index) => (
          <span key={index} style={{ "--i": index } as CSSProperties} />
        ))}
      </div>
      <section className="complete-dialog">
        <h2>恭喜完成！</h2>
        <img src={imageUrl} alt="" />
        <h3>{title}</h3>
        <button className="primary-button" type="button" onClick={onConfirm}>
          确认
        </button>
      </section>
    </div>
  );
}
