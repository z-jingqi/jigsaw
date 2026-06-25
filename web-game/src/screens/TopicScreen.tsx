import type { CSSProperties } from "react";
import { ProgressSnapshot } from "../store/progressStore";
import { GameMode, TopicRecord } from "../data/types";

interface TopicScreenProps {
  topics: TopicRecord[];
  progress: ProgressSnapshot;
  totalForTopic: (topic: TopicRecord) => number;
  onSelectTopic: (topic: TopicRecord) => void;
}

function completedForTopic(topic: TopicRecord, progress: ProgressSnapshot): number {
  let done = 0;
  topic.groups.forEach((group) => {
    group.levels.forEach((level) => {
      level.availableModes.forEach((mode: GameMode) => {
        if (progress.completed[`${level.id}:${mode}`]) done += 1;
      });
    });
  });
  return done;
}

export function TopicScreen({ topics, progress, totalForTopic, onSelectTopic }: TopicScreenProps) {
  return (
    <section className="topic-screen">
      <header className="home-header">
        <img className="home-logo" src="/assets/ui/title.png" alt="jigcat" />
        <div className="home-actions">
          <button className="icon-button" aria-label="相册">
            <img src="/assets/icons/phosphor/image.svg" alt="" />
          </button>
          <button className="icon-button" aria-label="设置">
            <img src="/assets/icons/phosphor/gear-six.svg" alt="" />
          </button>
        </div>
      </header>

      <div className="topic-list">
        {topics.map((topic) => {
          const total = totalForTopic(topic);
          const done = completedForTopic(topic, progress);
          const ratio = total > 0 ? done / total : 0;

          return (
            <button
              key={topic.id}
              className="topic-card"
              type="button"
              onClick={() => onSelectTopic(topic)}
              style={{ "--topic-color": topic.color } as CSSProperties}
            >
              <span className="topic-card__badge">
                {topic.iconUrl ? <img src={topic.iconUrl} alt="" /> : null}
              </span>
              <span className="topic-card__content">
                <span className="topic-card__title">{topic.title}</span>
                <span className="topic-card__progress-text">
                  {done}/{total}
                </span>
                <span className="topic-card__progress">
                  <span style={{ width: `${Math.max(0.08, ratio) * 100}%` }} />
                </span>
              </span>
              {topic.coverUrl ? <img className="topic-card__cover" src={topic.coverUrl} alt="" /> : null}
            </button>
          );
        })}
      </div>
    </section>
  );
}
