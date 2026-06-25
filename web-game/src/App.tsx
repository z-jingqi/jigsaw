import { useEffect, useMemo, useState } from "react";
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

export function App() {
  const [repository, setRepository] = useState<RepositorySnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [screen, setScreen] = useState<Screen>({ name: "topics" });
  const [selectedLevel, setSelectedLevel] = useState<LevelRecord | null>(null);
  const [progress, setProgress] = useState<ProgressSnapshot>(() => progressStore.read());

  useEffect(() => {
    loadRepository()
      .then(setRepository)
      .catch((reason) => setError(reason instanceof Error ? reason.message : String(reason)));
  }, []);

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

  return (
    <main className="app-shell">
      {screen.name === "topics" ? (
        <TopicScreen
          topics={repository.topics}
          progress={progress}
          totalForTopic={countTopicModes}
          onSelectTopic={(topic) => setScreen({ name: "levels", topicId: topic.id })}
          onStartLevel={startLevel}
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
    </main>
  );
}
