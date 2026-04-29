export interface CompleteScreenHandle {
  show: (summary: CompletionSummary) => void;
  hide: () => void;
}

export interface CompletionSummary {
  title: string;
  difficultyLabel: string;
  elapsedMs: number;
  moves: number;
}

export function createCompleteScreen(
  onRestart: () => void,
  onBackToLevels: () => void,
): CompleteScreenHandle {
  const root = document.getElementById('complete-screen');
  const title = document.getElementById('complete-title');
  const subtitle = document.getElementById('complete-subtitle');
  const stats = document.getElementById('complete-stats');
  const restart = document.getElementById('restart-button');
  const back = document.getElementById('back-to-levels-button');
  if (!root || !title || !subtitle || !stats || !restart || !back) {
    throw new Error('complete screen markup missing');
  }

  restart.addEventListener('click', () => onRestart());
  back.addEventListener('click', () => onBackToLevels());

  const formatMs = (elapsedMs: number): string => {
    const totalSeconds = Math.max(0, Math.round(elapsedMs / 1000));
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  };

  return {
    show: (summary) => {
      title.textContent = `${summary.title} Complete!`;
      subtitle.textContent = `${summary.difficultyLabel} · ${formatMs(summary.elapsedMs)} · ${summary.moves} move${summary.moves === 1 ? '' : 's'}`;
      stats.textContent = 'Nice work.';
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
  };
}
