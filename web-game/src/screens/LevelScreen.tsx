import type { CSSProperties } from "react";
import { ProgressSnapshot } from "../store/progressStore";
import { GameMode, LevelRecord, TopicRecord } from "../data/types";

interface LevelScreenProps {
  topic: TopicRecord;
  progress: ProgressSnapshot;
  onBack: () => void;
  onSelectLevel: (level: LevelRecord) => void;
}

const modeIcon: Record<GameMode, [string, string]> = {
  polygon: ["/assets/icons/status/mode_polygon_done.png", "/assets/icons/status/mode_polygon_todo.png"],
  knob: ["/assets/icons/status/mode_knob_done.png", "/assets/icons/status/mode_knob_todo.png"],
  swap: ["/assets/icons/status/mode_swap_done.png", "/assets/icons/status/mode_swap_todo.png"],
};

function completedForTopic(topic: TopicRecord, progress: ProgressSnapshot): number {
  let done = 0;
  topic.groups.forEach((group) => {
    group.levels.forEach((level) => {
      level.availableModes.forEach((mode) => {
        if (progress.completed[`${level.id}:${mode}`]) done += 1;
      });
    });
  });
  return done;
}

function totalForTopic(topic: TopicRecord): number {
  return topic.groups.reduce((sum, group) => {
    return sum + group.levels.reduce((levelSum, level) => levelSum + level.availableModes.length, 0);
  }, 0);
}

export function LevelScreen({ topic, progress, onBack, onSelectLevel }: LevelScreenProps) {
  const done = completedForTopic(topic, progress);
  const total = totalForTopic(topic);

  return (
    <section className="level-screen">
      <header className="level-header">
        <button className="plain-icon-button" type="button" onClick={onBack} aria-label="返回">
          <img src="/assets/icons/phosphor/caret-left.svg" alt="" />
        </button>
        <div className="level-header__title">
          {topic.iconUrl ? <img className="level-header__icon" src={topic.iconUrl} alt="" /> : <span className="title-decoration" />}
          <h1>{topic.title}</h1>
          <img className="level-header__decor" src="/assets/web-ui/decor-cluster.png" alt="" />
        </div>
        <span className="level-header__progress">
          {done}/{total}
        </span>
      </header>

      <div className="group-list">
        {topic.groups.length === 0 ? <div className="empty-state">这个主题还没有关卡</div> : null}
        {topic.groups.map((group) => (
          <section key={group.id} className="level-group" style={{ "--group-color": group.color } as CSSProperties}>
            <h2>
              <span />
              {group.title}
            </h2>
            {group.levels.length === 0 ? <p className="group-empty">这一组还没有关卡</p> : null}
            {group.levels.length > 0 ? (
              <div className="level-group__levels">
                {group.levels.map((level) => (
                  <button key={level.id} className="level-row" type="button" onClick={() => onSelectLevel(level)}>
                    {level.coverUrl ? (
                      <img className="level-row__cover" src={level.coverUrl} alt="" />
                    ) : (
                      <span className="level-row__cover" />
                    )}
                    <span className="level-row__title">{level.title}</span>
                    <span className="level-row__modes">
                      {(["polygon", "knob", "swap"] as GameMode[]).map((mode) => {
                        const hasMode = level.availableModes.includes(mode);
                        const doneMode = Boolean(progress.completed[`${level.id}:${mode}`]);
                        const src = modeIcon[mode][doneMode && hasMode ? 0 : 1];
                        return <img key={mode} className={!hasMode ? "is-muted" : ""} src={src} alt="" />;
                      })}
                    </span>
                  </button>
                ))}
              </div>
            ) : null}
          </section>
        ))}
      </div>
    </section>
  );
}
