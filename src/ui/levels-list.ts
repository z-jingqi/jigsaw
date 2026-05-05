import type { DifficultyEntry } from '../core/types';
import { getCompletion } from '../core/progress';
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
        img.src = lvl.silhouette ? `/${lvl.path}/${lvl.silhouette}` : `/${lvl.path}/source.png`;
        img.alt = lvl.title;
        img.draggable = false;

        const buttons = document.createElement('div');
        buttons.className = 'difficulty-row';
        for (const diff of lvl.difficulties) {
          const btn = document.createElement('button');
          btn.className = 'difficulty-btn';
          const record = getCompletion(lvl.path, diff.label);
          btn.textContent = record ? `${diff.label} ✓` : diff.label;
          btn.title = `${diff.cols} × ${diff.rows}`;
          if (record) btn.dataset.state = 'complete';
          btn.addEventListener('click', (e) => {
            e.stopPropagation();
            onPick(lvl, diff);
          });
          buttons.appendChild(btn);
        }

        card.appendChild(img);
        card.appendChild(buttons);
        grid.appendChild(card);
      }
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
  };
}
