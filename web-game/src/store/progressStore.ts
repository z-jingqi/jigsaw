import { GameMode } from "../data/types";

const STORAGE_KEY = "jigcat-web-progress-v1";

export interface ProgressSnapshot {
  completed: Record<string, true>;
  last?: {
    topicId: string;
    groupId: string;
    levelId: string;
    mode: GameMode;
  };
}

function key(levelId: string, mode: GameMode): string {
  return `${levelId}:${mode}`;
}

function read(): ProgressSnapshot {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { completed: {} };
    const parsed = JSON.parse(raw) as ProgressSnapshot;
    return {
      completed: parsed.completed ?? {},
      last: parsed.last,
    };
  } catch {
    return { completed: {} };
  }
}

function write(snapshot: ProgressSnapshot): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot));
}

export const progressStore = {
  read,
  isCompleted(levelId: string, mode: GameMode, snapshot = read()): boolean {
    return Boolean(snapshot.completed[key(levelId, mode)]);
  },
  markCompleted(topicId: string, groupId: string, levelId: string, mode: GameMode): ProgressSnapshot {
    const snapshot = read();
    snapshot.completed[key(levelId, mode)] = true;
    snapshot.last = { topicId, groupId, levelId, mode };
    write(snapshot);
    return snapshot;
  },
  remember(topicId: string, groupId: string, levelId: string, mode: GameMode): ProgressSnapshot {
    const snapshot = read();
    snapshot.last = { topicId, groupId, levelId, mode };
    write(snapshot);
    return snapshot;
  },
  clear(): ProgressSnapshot {
    const snapshot: ProgressSnapshot = { completed: {} };
    write(snapshot);
    return snapshot;
  },
};
