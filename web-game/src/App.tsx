import { useEffect, useMemo, useRef, useState } from "react";
import { countTopicModes, loadRepository } from "./data/levelRepository";
import { GameMode, LevelRecord, RepositorySnapshot, TopicRecord } from "./data/types";
import { progressStore, ProgressSnapshot } from "./store/progressStore";
import { TopicScreen } from "./screens/TopicScreen";
import { LevelScreen } from "./screens/LevelScreen";
import { ModeDialog } from "./screens/ModeDialog";
import { GameScreen } from "./screens/GameScreen";

type Screen =
  | { name: "topics" }
  | { name: "levels"; topicId: string }
  | { name: "game"; topicId: string; groupId: string; levelId: string; mode: GameMode };

type CloudTransitionState = "idle" | "covering" | "covered" | "opening";

const CLOUD_COVER_MS = 1650;
const CLOUD_HOLD_MS = 620;
const CLOUD_OPEN_MS = 1680;
const CLOUD_SPRITES = [
  ["top-left", "/assets/web-ui/island-map/cloud-wide.webp"],
  ["top-right", "/assets/web-ui/island-map/cloud-wide.webp"],
  ["top-cap", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["upper-left", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["upper-right", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["top-fill", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["side-left-upper", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["side-right-upper", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["center-top", "/assets/web-ui/island-map/cloud-wide.webp"],
  ["left-mid", "/assets/web-ui/island-map/cloud-round.webp"],
  ["right-mid", "/assets/web-ui/island-map/cloud-round.webp"],
  ["middle-fill", "/assets/web-ui/island-map/cloud-wide.webp"],
  ["side-left-lower", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["side-right-lower", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["center-mid", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["left-low", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["right-low", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["lower-fill", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["center-low", "/assets/web-ui/island-map/cloud-wide.webp"],
  ["bottom-fill", "/assets/web-ui/island-map/cloud-medium.webp"],
  ["bottom-left", "/assets/web-ui/island-map/cloud-wide.webp"],
  ["bottom-right", "/assets/web-ui/island-map/cloud-wide.webp"],
] as const;

export function App() {
  const [repository, setRepository] = useState<RepositorySnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [screen, setScreen] = useState<Screen>({ name: "topics" });
  const [selectedLevel, setSelectedLevel] = useState<LevelRecord | null>(null);
  const [progress, setProgress] = useState<ProgressSnapshot>(() => progressStore.read());
  const [cloudTransition, setCloudTransition] = useState<CloudTransitionState>("idle");
  const hasPlayedInitialTransition = useRef(false);
  const topicScrollTop = useRef(0);
  const transitionTimers = useRef<number[]>([]);

  useEffect(() => {
    loadRepository()
      .then(setRepository)
      .catch((reason) => setError(reason instanceof Error ? reason.message : String(reason)));
  }, []);

  useEffect(() => {
    return () => {
      transitionTimers.current.forEach((timer) => window.clearTimeout(timer));
      transitionTimers.current = [];
    };
  }, []);

  useEffect(() => {
    if (!repository || hasPlayedInitialTransition.current) return;
    hasPlayedInitialTransition.current = true;
    setCloudTransition("covered");
    const openTimer = window.setTimeout(() => setCloudTransition("opening"), 360);
    const idleTimer = window.setTimeout(() => setCloudTransition("idle"), 360 + CLOUD_OPEN_MS + 180);
    transitionTimers.current.push(openTimer, idleTimer);
  }, [repository]);

  useEffect(() => {
    if (screen.name === "topics") return;

    const resetScrollTimer = window.setTimeout(() => window.scrollTo(0, 0), 0);
    return () => window.clearTimeout(resetScrollTimer);
  }, [screen.name]);

  const selectedTopic = useMemo<TopicRecord | undefined>(() => {
    if (!repository || screen.name === "topics") return undefined;
    return repository.topics.find((topic) => topic.id === screen.topicId);
  }, [repository, screen]);

  function startLevel(level: LevelRecord, mode: GameMode) {
    setSelectedLevel(null);
    setProgress(progressStore.remember(level.topicId, level.groupId, level.id, mode));
    setScreen({ name: "game", topicId: level.topicId, groupId: level.groupId, levelId: level.id, mode });
  }

  function onComplete(level: LevelRecord, mode: GameMode) {
    setProgress(progressStore.markCompleted(level.topicId, level.groupId, level.id, mode));
    setScreen({ name: "levels", topicId: level.topicId });
  }

  function runCloudTransition(action: () => void) {
    transitionTimers.current.forEach((timer) => window.clearTimeout(timer));
    transitionTimers.current = [];
    setCloudTransition("covering");
    transitionTimers.current.push(
      window.setTimeout(() => {
        setCloudTransition("covered");
        action();
        transitionTimers.current.push(
          window.setTimeout(() => setCloudTransition("opening"), CLOUD_HOLD_MS),
          window.setTimeout(() => setCloudTransition("idle"), CLOUD_HOLD_MS + CLOUD_OPEN_MS + 180),
        );
      }, CLOUD_COVER_MS),
    );
  }

  function rememberTopicScroll(scrollTop: number) {
    topicScrollTop.current = scrollTop;
  }

  function openTopicLevels(topic: TopicRecord) {
    runCloudTransition(() => {
      setScreen({ name: "levels", topicId: topic.id });
    });
  }

  if (error) {
    return (
      <main className="app-shell app-shell--center">
        <div className="empty-state">读取关卡失败：{error}</div>
      </main>
    );
  }

  if (!repository) {
    return (
      <main className="app-shell app-shell--center">
        <div className="empty-state">正在读取关卡...</div>
      </main>
    );
  }

  if (screen.name === "game") {
    const level = repository.levelsById.get(screen.levelId);
    if (!level) {
      return (
        <main className="app-shell app-shell--center">
          <div className="empty-state">关卡不存在</div>
        </main>
      );
    }
    return (
      <GameScreen
        level={level}
        mode={screen.mode}
        onBack={() => setScreen({ name: "levels", topicId: level.topicId })}
        onComplete={() => onComplete(level, screen.mode)}
      />
    );
  }

  const shellClassName = screen.name === "topics" ? "app-shell app-shell--island" : "app-shell";

  return (
    <main className={shellClassName}>
      {screen.name === "topics" ? (
        <TopicScreen
          topics={repository.topics}
          progress={progress}
          totalForTopic={countTopicModes}
          restoreScrollTop={topicScrollTop.current}
          onScrollPositionChange={rememberTopicScroll}
          onSelectTopic={openTopicLevels}
        />
      ) : selectedTopic ? (
        <LevelScreen
          topic={selectedTopic}
          progress={progress}
          onBack={() => setScreen({ name: "topics" })}
          onSelectLevel={setSelectedLevel}
        />
      ) : (
        <div className="empty-state">主题不存在</div>
      )}

      {selectedLevel ? (
        <ModeDialog
          level={selectedLevel}
          progress={progress}
          onClose={() => setSelectedLevel(null)}
          onStart={startLevel}
        />
      ) : null}
      <CloudTransition state={cloudTransition} />
    </main>
  );
}

function CloudTransition({ state }: { state: CloudTransitionState }) {
  return (
    <div className={`cloud-transition cloud-transition--${state}`} aria-hidden="true">
      {CLOUD_SPRITES.map(([name, src]) => (
        <img
          key={name}
          className={`cloud-transition__sprite cloud-transition__sprite--${name}`}
          src={src}
          alt=""
          draggable={false}
        />
      ))}
    </div>
  );
}
