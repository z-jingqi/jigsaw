import type { CSSProperties } from "react";
import { GameMode, LevelRecord } from "../data/types";
import { ProgressSnapshot } from "../store/progressStore";

interface ModeDialogProps {
  level: LevelRecord;
  progress: ProgressSnapshot;
  onClose: () => void;
  onStart: (level: LevelRecord, mode: GameMode) => void;
}

const modeMeta: Record<GameMode, { title: string; caption: string; color: string; icon: string; todoIcon: string }> = {
  polygon: {
    title: "多边形模式",
    caption: "自由拼片边缘",
    color: "#6BAE57",
    icon: "/assets/icons/status/mode_polygon_done.png",
    todoIcon: "/assets/icons/status/mode_polygon_todo.png",
  },
  knob: {
    title: "经典凹凸模式",
    caption: "经典拼图体验",
    color: "#9B7BC1",
    icon: "/assets/icons/status/mode_knob_done.png",
    todoIcon: "/assets/icons/status/mode_knob_todo.png",
  },
  swap: {
    title: "交换模式",
    caption: "移动交换还原",
    color: "#F0874D",
    icon: "/assets/icons/status/mode_swap_done.png",
    todoIcon: "/assets/icons/status/mode_swap_todo.png",
  },
};

export function ModeDialog({ level, progress, onClose, onStart }: ModeDialogProps) {
  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <section className="mode-dialog">
        <button className="plain-icon-button mode-dialog__close" type="button" onClick={onClose} aria-label="关闭">
          <img src="/assets/icons/phosphor/x.svg" alt="" />
        </button>
        <div className="mode-dialog__title">
          <span className="mode-title-spark mode-title-spark--left" />
          <h2>选择模式</h2>
          <span className="mode-title-spark mode-title-spark--right" />
        </div>
        <p className="mode-dialog__hint">选择一个模式开始游戏</p>

        <div className="mode-card-list">
          {level.availableModes.map((mode) => {
            const meta = modeMeta[mode];
            const done = Boolean(progress.completed[`${level.id}:${mode}`]);
            return (
              <button
                key={mode}
                type="button"
                className="mode-card"
                onClick={() => onStart(level, mode)}
                style={{ "--mode-color": meta.color } as CSSProperties}
              >
                {done ? <span className="mode-card__check">✓</span> : null}
                <img className="mode-card__icon" src={done ? meta.icon : meta.todoIcon} alt="" />
                <span className="mode-card__copy">
                  <strong>{meta.title}</strong>
                  <small>{meta.caption}</small>
                </span>
                <span className="mode-card__action">{done ? "再玩一次" : "开始游戏"}</span>
              </button>
            );
          })}
        </div>
      </section>
    </div>
  );
}
