import type { CSSProperties } from "react";
import { ProgressSnapshot } from "../store/progressStore";
import { GameMode, LevelRecord, TopicRecord } from "../data/types";

interface TopicScreenProps {
  topics: TopicRecord[];
  progress: ProgressSnapshot;
  totalForTopic: (topic: TopicRecord) => number;
  onSelectTopic: (topic: TopicRecord) => void;
  onStartLevel: (level: LevelRecord, mode: GameMode) => void;
}

interface FeaturedLevel {
  topic: TopicRecord;
  level: LevelRecord;
  mode: GameMode;
  isResume: boolean;
}

const modePriority: GameMode[] = ["polygon", "knob", "swap"];

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

function firstMode(level: LevelRecord): GameMode | undefined {
  return modePriority.find((mode) => level.availableModes.includes(mode)) ?? level.availableModes[0];
}

function findFeaturedLevel(topics: TopicRecord[], progress: ProgressSnapshot): FeaturedLevel | undefined {
  const last = progress.last;
  if (last) {
    const topic = topics.find((candidate) => candidate.id === last.topicId);
    const group = topic?.groups.find((candidate) => candidate.id === last.groupId);
    const level = group?.levels.find((candidate) => candidate.id === last.levelId);
    const mode = level?.availableModes.includes(last.mode) ? last.mode : level ? firstMode(level) : undefined;
    if (topic && level && mode) {
      return { topic, level, mode, isResume: true };
    }
  }

  for (const topic of topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        const mode = firstMode(level);
        if (mode) return { topic, level, mode, isResume: false };
      }
    }
  }

  return undefined;
}

function scrollToTopics() {
  document.getElementById("topic-preview")?.scrollIntoView({ behavior: "smooth", block: "start" });
}

export function TopicScreen({
  topics,
  progress,
  totalForTopic,
  onSelectTopic,
  onStartLevel,
}: TopicScreenProps) {
  const featured = findFeaturedLevel(topics, progress);
  const previewTopics = topics.slice(0, 4);

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

      <div className="home-decor home-decor--top" aria-hidden="true">
        <img src="/assets/web-ui/decor-cluster.png" alt="" />
      </div>

      {featured ? (
        <section className="home-feature" style={{ "--topic-color": featured.topic.color } as CSSProperties}>
          <div className="home-feature__copy">
            <span className="home-feature__label">{featured.isResume ? "最近游玩" : "新的拼图"}</span>
            <h1>{featured.topic.title}</h1>
            <p>{featured.level.title}</p>
            <TopicProgress topic={featured.topic} progress={progress} totalForTopic={totalForTopic} />
            <button className="home-feature__button" type="button" onClick={() => onStartLevel(featured.level, featured.mode)}>
              {featured.isResume ? "继续游戏" : "开始游戏"}
            </button>
          </div>
          <div className="home-feature__art">
            <img src={featured.level.imageUrl || featured.topic.coverUrl} alt="" />
          </div>
        </section>
      ) : (
        <section className="home-feature home-feature--empty">
          <div className="home-feature__copy">
            <span className="home-feature__label">欢迎回来</span>
            <h1>准备新的拼图</h1>
            <p>当前还没有可游玩的关卡。</p>
            <button className="home-feature__button" type="button" onClick={scrollToTopics}>
              选择主题
            </button>
          </div>
        </section>
      )}

      <button className="choose-topic-button" type="button" onClick={scrollToTopics}>
        <span className="choose-topic-button__mark" aria-hidden="true" />
        选择主题
        <span className="choose-topic-button__arrow" aria-hidden="true" />
      </button>

      <section id="topic-preview" className="topic-preview" aria-label="主题预览">
        <div className="section-heading">
          <h2>主题预览</h2>
          <span>轻点进入关卡</span>
        </div>

        {previewTopics.length === 0 ? (
          <div className="empty-state">还没有主题</div>
        ) : (
          <div className="topic-preview__grid">
            {previewTopics.map((topic) => {
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
                      <span style={{ width: `${ratio * 100}%` }} />
                    </span>
                  </span>
                  {topic.coverUrl ? <img className="topic-card__cover" src={topic.coverUrl} alt="" /> : null}
                </button>
              );
            })}
          </div>
        )}
      </section>
    </section>
  );
}

function TopicProgress({
  topic,
  progress,
  totalForTopic,
}: {
  topic: TopicRecord;
  progress: ProgressSnapshot;
  totalForTopic: (topic: TopicRecord) => number;
}) {
  const total = totalForTopic(topic);
  const done = completedForTopic(topic, progress);
  const ratio = total > 0 ? done / total : 0;

  return (
    <div className="home-progress">
      <span>拼图进度</span>
      <strong>
        {done}/{total}
      </strong>
      <div>
        <i style={{ width: `${ratio * 100}%` }} />
      </div>
    </div>
  );
}
