import { useCallback, useEffect, useLayoutEffect, useRef, type CSSProperties } from "react";
import { ProgressSnapshot } from "../store/progressStore";
import { TopicRecord } from "../data/types";

interface TopicScreenProps {
  topics: TopicRecord[];
  progress: ProgressSnapshot;
  totalForTopic: (topic: TopicRecord) => number;
  restoreScrollTop: number;
  onScrollPositionChange: (scrollTop: number) => void;
  onSelectTopic: (topic: TopicRecord) => void;
}

interface TopicStats {
  completedModes: number;
  totalModes: number;
  ratio: number;
}

const islandAssets = [
  "/assets/web-ui/island-map/island-1.webp",
  "/assets/web-ui/island-map/island-2.webp",
  "/assets/web-ui/island-map/island-3.webp",
];

const topicIslandArt: Record<string, string> = {
  topic_01: "/assets/web-ui/island-map/topic-shanhai.webp",
  topic_02: "/assets/web-ui/island-map/topic-greek.webp",
  topic_03: "/assets/web-ui/island-map/topic-cat.webp",
  topic_04: "/assets/web-ui/island-map/topic-dog.webp",
};

function getTopicStats(topic: TopicRecord, progress: ProgressSnapshot): TopicStats {
  let completedModes = 0;
  let totalModes = 0;

  topic.groups.forEach((group) => {
    group.levels.forEach((level) => {
      totalModes += level.availableModes.length;
      level.availableModes.forEach((mode) => {
        if (progress.completed[`${level.id}:${mode}`]) completedModes += 1;
      });
    });
  });

  return {
    completedModes,
    totalModes,
    ratio: totalModes > 0 ? completedModes / totalModes : 0,
  };
}

function getTotalStats(topics: TopicRecord[], progress: ProgressSnapshot): TopicStats {
  return topics.reduce<TopicStats>(
    (total, topic) => {
      const stats = getTopicStats(topic, progress);
      total.completedModes += stats.completedModes;
      total.totalModes += stats.totalModes;
      total.ratio = total.totalModes > 0 ? total.completedModes / total.totalModes : 0;
      return total;
    },
    { completedModes: 0, totalModes: 0, ratio: 0 },
  );
}

export function TopicScreen({
  topics,
  progress,
  totalForTopic,
  restoreScrollTop,
  onScrollPositionChange,
  onSelectTopic,
}: TopicScreenProps) {
  const screenRef = useRef<HTMLElement | null>(null);
  const totalStats = getTotalStats(topics, progress);

  const getCurrentScrollTop = useCallback(() => {
    return Math.max(
      screenRef.current?.scrollTop ?? 0,
      window.scrollY,
      document.documentElement.scrollTop,
      document.body.scrollTop,
    );
  }, []);

  useLayoutEffect(() => {
    if (restoreScrollTop <= 0) return;

    const applyScroll = () => {
      if (screenRef.current) screenRef.current.scrollTop = restoreScrollTop;
      window.scrollTo(0, restoreScrollTop);
    };

    applyScroll();
    const frame = window.requestAnimationFrame(applyScroll);
    return () => window.cancelAnimationFrame(frame);
  }, [restoreScrollTop, topics.length]);

  useEffect(() => {
    const handleScroll = () => onScrollPositionChange(getCurrentScrollTop());

    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, [getCurrentScrollTop, onScrollPositionChange]);

  function handleTopicSelect(topic: TopicRecord) {
    onScrollPositionChange(getCurrentScrollTop());
    onSelectTopic(topic);
  }

  return (
    <section
      ref={screenRef}
      className="topic-screen island-topic-screen"
      onScroll={() => onScrollPositionChange(getCurrentScrollTop())}
    >
      <header className="island-topbar" aria-label="主题页面操作">
        <button className="island-icon-button" type="button" aria-label="设置">
          <img src="/assets/icons/phosphor/gear-six.svg" alt="" />
        </button>
        <h1 className="island-game-title" aria-label="JigCat">
          <span>Jig</span>
          <span>Cat</span>
        </h1>
        <div className="island-overall-progress" aria-label="游玩进度">
          <strong>
            {totalStats.completedModes}/{totalStats.totalModes}
          </strong>
          <span>
            <i style={{ width: `${totalStats.ratio * 100}%` }} />
          </span>
        </div>
      </header>

      <section className="island-map" aria-label="主题列表">
        {topics.length === 0 ? (
          <div className="empty-state">还没有主题</div>
        ) : (
          topics.map((topic, index) => {
            const stats = getTopicStats(topic, progress);
            const total = totalForTopic(topic);
            const island = islandAssets[index % islandAssets.length];
            const topicArt = topicIslandArt[topic.id];
            const islandSide = index % 2 === 0 ? "left" : "right";
            return (
              <button
                key={topic.id}
                type="button"
                className={`theme-island theme-island--${index % 3} theme-island--${islandSide}`}
                aria-label={`${topic.title} ${stats.completedModes}/${total}`}
                onClick={() => handleTopicSelect(topic)}
                style={
                  {
                    "--topic-color": topic.color,
                    "--topic-progress": `${stats.ratio * 100}%`,
                  } as CSSProperties
                }
              >
                <img className="theme-island__base" src={island} alt="" />
                {topicArt ? <img className="theme-island__cover" src={topicArt} alt="" /> : null}
                <span className="theme-island__label">
                  {topic.iconUrl ? <img className="theme-island__icon" src={topic.iconUrl} alt="" /> : null}
                  <strong>{topic.title}</strong>
                  <span className="theme-island__progress">
                    {stats.completedModes}/{total}
                  </span>
                </span>
              </button>
            );
          })
        )}
      </section>
    </section>
  );
}
