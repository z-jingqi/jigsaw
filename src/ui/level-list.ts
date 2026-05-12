import { ArrowLeft, ChevronLeft, ChevronRight, Hexagon, Puzzle, createElement } from 'lucide';
import seriesTitleBgUrl from '../../assets/ui/series-title-bg.png';
import levelsIndex from '../../levels/index.json';
import catSourceUrl from '../../levels/cats/001-cat/source.png';
import monaLisaSourceUrl from '../../levels/masterpieces/001-mona-lisa/source.png';
import type { SeriesSummary } from './series-grid';

type LevelIndex = {
  series: Array<{
    id: string;
    title: string;
    levels: Array<{
      path: string;
      title: string;
    }>;
  }>;
};

type LevelItem = {
  id: string;
  path: string;
  title: string;
  imageUrl: string;
  completed: boolean;
};

export type LevelSummary = Pick<LevelItem, 'id' | 'path' | 'title'>;

const typedLevelsIndex = levelsIndex as LevelIndex;

const levelImageUrls: Record<string, string> = {
  'cats/001-cat': catSourceUrl,
  'masterpieces/001-mona-lisa': monaLisaSourceUrl,
};

const PAGE_SIZE = 8;

function getLevelImageUrl(path: string): string {
  if (levelImageUrls[path]) {
    return levelImageUrls[path];
  }

  if (path.startsWith('cats/')) {
    return catSourceUrl;
  }

  if (path.startsWith('masterpieces/')) {
    return monaLisaSourceUrl;
  }

  return '';
}

function getCompletedCount(progress: string): number {
  const [completed] = progress.split('/');
  return Number.parseInt(completed, 10) || 0;
}

function getTotalCount(progress: string): number {
  const [, total] = progress.split('/');
  return Number.parseInt(total, 10) || 0;
}

function createLucideIcon(icon: typeof Puzzle, className: string): SVGElement {
  return createElement(icon, {
    class: className,
    'aria-hidden': 'true',
    'stroke-width': 2.35,
  });
}

function getSeriesLevels(series: SeriesSummary): LevelItem[] {
  const seriesEntry = typedLevelsIndex.series.find((item) => item.id === series.id);
  const completedCount = getCompletedCount(series.progress);
  const totalCount = getTotalCount(series.progress);

  if (!seriesEntry || seriesEntry.levels.length === 0) {
    const displayCount = Math.max(totalCount, 1);

    return Array.from({ length: displayCount }, (_, index) => {
      const displayNumber = index + 1;

      return {
        id: `${series.id}-${displayNumber}`,
        path: 'cats/001-cat',
        title: `${series.title} ${String(displayNumber).padStart(2, '0')}`,
        imageUrl: catSourceUrl,
        completed: index < completedCount,
      };
    });
  }

  const sourceLevels = seriesEntry.levels;
  const displayCount = Math.max(sourceLevels.length, totalCount);

  return Array.from({ length: displayCount }, (_, index) => {
    const level = sourceLevels[index % sourceLevels.length];
    const displayNumber = index + 1;

    return {
      id: `${level.path}-${displayNumber}`,
      path: level.path,
      title: displayNumber === 1 ? level.title : `${level.title} ${displayNumber}`,
      imageUrl: getLevelImageUrl(level.path),
      completed: index < completedCount,
    };
  });
}

function createLevelCard(level: LevelItem, onPlay?: (level: LevelSummary) => void): HTMLButtonElement {
  const card = document.createElement('button');
  card.className = 'level-card';
  card.type = 'button';
  card.dataset.level = level.id;
  card.addEventListener('click', () => {
    onPlay?.({ id: level.id, path: level.path, title: level.title });
  });

  const imageFrame = document.createElement('div');
  imageFrame.className = 'level-card-image-frame';

  if (level.imageUrl) {
    const image = document.createElement('img');
    image.alt = '';
    image.draggable = false;
    image.src = level.imageUrl;
    imageFrame.appendChild(image);
  }

  const status = document.createElement('div');
  status.className = level.completed ? 'level-card-status level-card-status-completed' : 'level-card-status';
  status.append(createLucideIcon(Hexagon, 'level-card-status-icon'));
  status.append(createLucideIcon(Puzzle, 'level-card-status-icon'));
  imageFrame.appendChild(status);

  const title = document.createElement('span');
  title.className = 'level-card-title';
  title.textContent = level.title;

  card.append(imageFrame, title);
  return card;
}

export function createLevelList(
  series: SeriesSummary,
  onBack: () => void,
  onPlay?: (level: LevelSummary) => void,
): HTMLElement {
  const page = document.createElement('section');
  page.className = 'level-list-page';
  page.setAttribute('aria-label', `${series.title}关卡列表`);

  const backButton = document.createElement('button');
  backButton.className = 'level-back-button';
  backButton.type = 'button';
  backButton.setAttribute('aria-label', '返回');
  backButton.appendChild(createLucideIcon(ArrowLeft, 'level-back-icon'));
  backButton.addEventListener('click', onBack);

  const titlePanel = document.createElement('div');
  titlePanel.className = 'level-title-panel';
  titlePanel.style.backgroundImage = `url("${seriesTitleBgUrl}")`;

  const title = document.createElement('h1');
  title.className = 'level-title';
  title.textContent = series.title;

  const progress = document.createElement('span');
  progress.className = 'level-title-progress';
  progress.textContent = series.progress;

  titlePanel.append(title, progress);

  const gridPanel = document.createElement('div');
  gridPanel.className = 'level-grid-panel';

  const grid = document.createElement('div');
  grid.className = 'level-grid';

  const prevButton = document.createElement('button');
  prevButton.className = 'level-page-button level-page-button-prev';
  prevButton.type = 'button';
  prevButton.setAttribute('aria-label', '上一页');
  prevButton.appendChild(createLucideIcon(ChevronLeft, 'level-page-icon'));

  const nextButton = document.createElement('button');
  nextButton.className = 'level-page-button level-page-button-next';
  nextButton.type = 'button';
  nextButton.setAttribute('aria-label', '下一页');
  nextButton.appendChild(createLucideIcon(ChevronRight, 'level-page-icon'));

  const levels = getSeriesLevels(series);
  let currentPage = 0;

  function renderPage(): void {
    const pageCount = Math.max(1, Math.ceil(levels.length / PAGE_SIZE));

    if (currentPage >= pageCount) {
      currentPage = pageCount - 1;
    }

    const start = currentPage * PAGE_SIZE;
    const pageItems = levels.slice(start, start + PAGE_SIZE);
    grid.replaceChildren(...pageItems.map((level) => createLevelCard(level, onPlay)));

    prevButton.hidden = currentPage === 0;
    nextButton.hidden = currentPage >= pageCount - 1;
  }

  prevButton.addEventListener('click', () => {
    if (currentPage === 0) {
      return;
    }

    currentPage -= 1;
    renderPage();
  });

  nextButton.addEventListener('click', () => {
    const pageCount = Math.max(1, Math.ceil(levels.length / PAGE_SIZE));

    if (currentPage >= pageCount - 1) {
      return;
    }

    currentPage += 1;
    renderPage();
  });

  renderPage();
  gridPanel.append(prevButton, grid, nextButton);
  page.append(backButton, titlePanel, gridPanel);
  return page;
}
