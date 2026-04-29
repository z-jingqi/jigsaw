import type { DifficultyEntry } from '../core/types';
import { completedDifficultyCount } from '../core/progress';

export interface LevelEntry {
  path: string;
  title: string;
  difficulties: DifficultyEntry[];
}

export interface SeriesEntry {
  id: string;
  title: string;
  levels: LevelEntry[];
}

export interface LevelIndex {
  series: SeriesEntry[];
}

export interface SeriesListHandle {
  show: () => void;
  hide: () => void;
}

export async function loadLevelIndex(): Promise<LevelIndex> {
  const res = await fetch('/index.json');
  if (!res.ok) throw new Error('failed to load levels/index.json');
  const raw = (await res.json()) as { series?: SeriesEntry[] };
  if (!raw.series) throw new Error('levels/index.json must have a "series" array');
  return {
    series: raw.series.map((s) => ({
      id: s.id,
      title: s.title ?? s.id,
      levels: (s.levels ?? []).map((l) => ({
        path: l.path,
        title: l.title ?? l.path,
        difficulties:
          l.difficulties && l.difficulties.length > 0
            ? l.difficulties
            : [{ label: '1', cols: 3, rows: 3 }],
      })),
    })),
  };
}

export function createSeriesList(
  index: LevelIndex,
  onPick: (series: SeriesEntry) => void,
  onBack: () => void,
): SeriesListHandle {
  const root = document.getElementById('series-list');
  const grid = document.getElementById('series-grid');
  const backBtn = document.getElementById('series-back-button');
  if (!root || !grid || !backBtn) throw new Error('series-list markup missing');

  backBtn.addEventListener('click', () => onBack());

  const render = (): void => {
    grid.innerHTML = '';
    for (const s of index.series) {
      const card = document.createElement('div');
      card.className = 'series-card';
      card.tabIndex = 0;

      const cover = s.levels[0]?.path
        ? `/${s.levels[0].path}/source.png`
        : '';
      if (cover) {
        const img = document.createElement('img');
        img.className = 'thumb';
        img.src = cover;
        img.alt = s.title;
        img.draggable = false;
        card.appendChild(img);
      }

      const title = document.createElement('div');
      title.className = 'title';
      title.textContent = s.title;
      card.appendChild(title);

      const meta = document.createElement('div');
      meta.className = 'meta';
      const levelCount = s.levels.length;
      const done = s.levels.reduce((sum, level) => sum + completedDifficultyCount(level.path, level.difficulties), 0);
      const total = s.levels.reduce((sum, level) => sum + level.difficulties.length, 0);
      meta.textContent = `${levelCount} 个关卡 · ${done}/${total} 已完成`;
      card.appendChild(meta);

      const pick = (): void => onPick(s);
      card.addEventListener('click', pick);
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          pick();
        }
      });
      grid.appendChild(card);
    }
  };

  return {
    show: () => {
      render();
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
  };
}
