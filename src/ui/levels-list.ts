import type { DifficultyEntry } from '../core/types';
import { completedDifficultyCount, formatBestTime, getCompletion, isDifficultyUnlocked } from '../core/progress';
import type { LevelEntry, SeriesEntry } from './series-list';

export interface LevelsListHandle {
  show: (series: SeriesEntry) => void;
  hide: () => void;
}

export function createLevelsList(
  onPick: (level: LevelEntry, difficulty: DifficultyEntry) => void,
  onBack: () => void,
): LevelsListHandle {
  const root = document.getElementById('levels-list');
  const grid = document.getElementById('levels-grid');
  const backBtn = document.getElementById('levels-back-button');
  const titleEl = document.getElementById('levels-title');
  if (!root || !grid || !backBtn || !titleEl) throw new Error('levels-list markup missing');

  backBtn.addEventListener('click', () => onBack());

  return {
    show: (series: SeriesEntry) => {
      titleEl.textContent = series.title;
      grid.innerHTML = '';
      for (const lvl of series.levels) {
        const card = document.createElement('div');
        card.className = 'level-card';

        const img = document.createElement('img');
        img.className = 'thumb';
        img.src = `/${lvl.path}/source.png`;
        img.alt = lvl.title;
        img.draggable = false;

        const title = document.createElement('div');
        title.className = 'title';
        title.textContent = lvl.title;

        const meta = document.createElement('div');
        meta.className = 'meta';
        const completed = completedDifficultyCount(lvl.path, lvl.difficulties);
        meta.textContent = `${lvl.path} · ${completed}/${lvl.difficulties.length} clears`;

        const best = lvl.difficulties
          .map((diff) => ({ diff, record: getCompletion(lvl.path, diff.label) }))
          .find((entry) => entry.record);
        const bestMeta = document.createElement('div');
        bestMeta.className = 'meta';
        bestMeta.textContent = best?.record
          ? `Best ${best.diff.label}: ${formatBestTime(best.record.bestElapsedMs)} · ${best.record.bestMoves} moves`
          : 'No clears yet';

        const buttons = document.createElement('div');
        buttons.className = 'difficulty-row';
        for (const [index, diff] of lvl.difficulties.entries()) {
          const btn = document.createElement('button');
          btn.className = 'difficulty-btn';
          const record = getCompletion(lvl.path, diff.label);
          const unlocked = isDifficultyUnlocked(lvl.path, lvl.difficulties, index);
          btn.textContent = record ? `${diff.label} ✓` : diff.label;
          btn.title = `${diff.cols} × ${diff.rows}`;
          btn.disabled = !unlocked;
          if (record) btn.dataset.state = 'complete';
          else if (!unlocked) btn.dataset.state = 'locked';
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            if (!unlocked) return;
            onPick(lvl, diff);
          });
          buttons.appendChild(btn);
        }

        card.appendChild(img);
        card.appendChild(title);
        card.appendChild(meta);
        card.appendChild(bestMeta);
        card.appendChild(buttons);
        grid.appendChild(card);
      }
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
  };
}
