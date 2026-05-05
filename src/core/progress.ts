import type { DifficultyEntry } from './types';

export interface CompletionRecord {
  bestElapsedMs: number;
  bestMoves: number;
  completedAt: string;
  timesCompleted: number;
}

interface ProgressData {
  completions: Record<string, CompletionRecord>;
}

const STORAGE_KEY = 'jigsaw.progress.v2';

let cached: ProgressData | null = null;

function read(): ProgressData {
  if (cached) return cached;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    cached = raw ? { completions: {}, ...JSON.parse(raw) } : { completions: {} };
  } catch {
    cached = { completions: {} };
  }
  return cached ?? { completions: {} };
}

function write(progress: ProgressData): void {
  cached = progress;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
  } catch {
    /* ignore storage failures */
  }
}

function keyFor(levelPath: string, difficultyLabel: string): string {
  return `${levelPath}::${difficultyLabel}`;
}

export function saveCompletion(levelPath: string, difficultyLabel: string, elapsedMs: number, moves: number): CompletionRecord {
  const progress = read();
  const key = keyFor(levelPath, difficultyLabel);
  const prev = progress.completions[key];
  const next: CompletionRecord = {
    bestElapsedMs: prev ? Math.min(prev.bestElapsedMs, elapsedMs) : elapsedMs,
    bestMoves: prev ? Math.min(prev.bestMoves, moves) : moves,
    completedAt: new Date().toISOString(),
    timesCompleted: (prev?.timesCompleted ?? 0) + 1,
  };
  progress.completions[key] = next;
  write(progress);
  return next;
}

export function getCompletion(levelPath: string, difficultyLabel: string): CompletionRecord | null {
  return read().completions[keyFor(levelPath, difficultyLabel)] ?? null;
}

export function hasCompletedLevel(levelPath: string, difficulties: DifficultyEntry[]): boolean {
  return difficulties.some((diff) => getCompletion(levelPath, diff.label) !== null);
}

export function completedDifficultyCount(levelPath: string, difficulties: DifficultyEntry[]): number {
  return difficulties.filter((diff) => getCompletion(levelPath, diff.label) !== null).length;
}

export function isDifficultyUnlocked(levelPath: string, difficulties: DifficultyEntry[], index: number): boolean {
  if (index <= 0) return true;
  const previous = difficulties[index - 1];
  return previous ? getCompletion(levelPath, previous.label) !== null : true;
}

export function formatBestTime(elapsedMs: number): string {
  const totalSeconds = Math.max(0, Math.round(elapsedMs / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
}
