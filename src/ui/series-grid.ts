import {
  Building2,
  Cat,
  ChevronLeft,
  ChevronRight,
  Flower2,
  Image,
  Mountain,
  Palette,
  PawPrint,
  Puzzle,
  Star,
  createElement,
} from 'lucide';
import catCoverUrl from '../../assets/ui/series-cat-cover.png';
import masterpiecesCoverUrl from '../../assets/ui/series-masterpieces-cover.png';

type SeriesItem = {
  id: string;
  title: string;
  progress: string;
  coverUrl?: string;
  icon: typeof Cat;
  badge?: string;
};

export type SeriesSummary = Pick<SeriesItem, 'id' | 'title' | 'progress'>;

type GridLayout = {
  columns: number;
  rows: number;
};

const seriesItems: SeriesItem[] = [
  { id: 'cats', title: '猫系列', progress: '10/18', coverUrl: catCoverUrl, icon: Cat },
  { id: 'masterpieces', title: '名画系列', progress: '6/12', coverUrl: masterpiecesCoverUrl, icon: Palette },
  { id: 'landscapes', title: '风景系列', progress: '12/24', icon: Mountain, badge: '新' },
  { id: 'still-life', title: '静物系列', progress: '8/24', icon: Image },
  { id: 'animals', title: '动物系列', progress: '15/24', icon: PawPrint },
  { id: 'architecture', title: '建筑系列', progress: '10/24', icon: Building2 },
  { id: 'illustration', title: '插画系列', progress: '6/24', icon: Cat },
  { id: 'plants', title: '植物系列', progress: '9/24', icon: Flower2 },
  { id: 'desserts', title: '甜点系列', progress: '4/24', icon: Flower2 },
  { id: 'ocean', title: '海洋系列', progress: '3/24', icon: Mountain },
  { id: 'space', title: '星空系列', progress: '5/24', icon: Palette },
  { id: 'toys', title: '玩具系列', progress: '7/24', icon: Puzzle },
  { id: 'flowers', title: '花卉系列', progress: '11/24', icon: Flower2 },
  { id: 'food', title: '美食系列', progress: '2/24', icon: Image },
  { id: 'travel', title: '旅行系列', progress: '1/24', icon: Mountain },
  { id: 'room', title: '房间系列', progress: '0/24', icon: Building2 },
];

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function getGridLayout(): GridLayout {
  const width = window.innerWidth;
  const height = window.innerHeight;
  const sideReservedWidth = clamp(width * 0.19, 248, 320);
  const rightMargin = clamp(width * 0.04, 48, 96);
  const topReservedHeight = clamp(height * 0.19, 140, 230);
  const bottomMargin = clamp(height * 0.06, 48, 88);
  const gridWidth = width - sideReservedWidth - rightMargin;
  const gridHeight = height - topReservedHeight - bottomMargin;
  const gap = clamp(width * 0.0145, 12, 24);
  const targetCardWidth = 240;
  const targetCardHeight = 270;
  const columns = clamp(Math.floor((gridWidth + gap) / (targetCardWidth + gap)), 4, 8);
  const rows = clamp(Math.floor((gridHeight + gap) / (targetCardHeight + gap)), 2, 3);

  return { columns, rows };
}

function getPageSize(layout: GridLayout): number {
  return layout.columns * layout.rows;
}

function getDisplayLayout(itemCount: number, capacityLayout: GridLayout): GridLayout {
  if (itemCount <= 0) {
    return { columns: capacityLayout.columns, rows: capacityLayout.rows };
  }

  const rows = clamp(Math.ceil(itemCount / capacityLayout.columns), 2, capacityLayout.rows);
  const columns = clamp(Math.ceil(itemCount / rows), 4, capacityLayout.columns);

  return { columns, rows };
}

function createLucideIcon(icon: typeof Cat, className: string): SVGElement {
  return createElement(icon, {
    class: className,
    'aria-hidden': 'true',
    'stroke-width': 2.35,
  });
}

function createSeriesCard(item: SeriesItem, onSelectSeries?: (series: SeriesSummary) => void): HTMLButtonElement {
  const card = document.createElement('button');
  card.className = 'series-card';
  card.type = 'button';
  card.dataset.series = item.id;
  card.addEventListener('click', () => {
    onSelectSeries?.({ id: item.id, title: item.title, progress: item.progress });
  });

  const cover = document.createElement('div');
  cover.className = item.coverUrl ? 'series-card-cover' : 'series-card-cover series-card-cover-empty';

  if (item.coverUrl) {
    const image = document.createElement('img');
    image.alt = '';
    image.draggable = false;
    image.src = item.coverUrl;
    cover.appendChild(image);
  } else {
    cover.appendChild(createLucideIcon(item.icon, 'series-card-placeholder-icon'));
  }

  if (item.badge) {
    const badge = document.createElement('span');
    badge.className = 'series-card-badge';
    badge.textContent = item.badge;
    cover.appendChild(badge);
  }

  const title = document.createElement('span');
  title.className = 'series-card-title';
  title.textContent = item.title;

  const progress = document.createElement('span');
  progress.className = 'series-card-progress';
  progress.appendChild(createLucideIcon(Star, 'series-card-star'));
  progress.append(document.createTextNode(item.progress));

  card.append(cover, title, progress);
  return card;
}

export function createSeriesGrid(onSelectSeries?: (series: SeriesSummary) => void): HTMLElement {
  const panel = document.createElement('section');
  panel.className = 'series-grid-panel';
  panel.setAttribute('aria-label', '系列选择');

  const grid = document.createElement('div');
  grid.className = 'series-grid';

  let capacityLayout = getGridLayout();
  let currentPage = 0;

  const previousButton = document.createElement('button');
  previousButton.className = 'series-page-button series-page-button-prev';
  previousButton.type = 'button';
  previousButton.setAttribute('aria-label', '上一页');
  previousButton.appendChild(createLucideIcon(ChevronLeft, 'series-page-icon'));

  const nextButton = document.createElement('button');
  nextButton.className = 'series-page-button series-page-button-next';
  nextButton.type = 'button';
  nextButton.setAttribute('aria-label', '下一页');
  nextButton.appendChild(createLucideIcon(ChevronRight, 'series-page-icon'));

  function applyGridLayout(displayLayout: GridLayout): void {
    grid.style.setProperty('--series-columns', String(displayLayout.columns));
    grid.style.setProperty('--series-rows', String(displayLayout.rows));
    panel.dataset.pageSize = String(getPageSize(capacityLayout));
    panel.dataset.displayColumns = String(displayLayout.columns);
    panel.dataset.displayRows = String(displayLayout.rows);
  }

  function renderPage(): void {
    const pageSize = getPageSize(capacityLayout);
    const pageCount = Math.max(1, Math.ceil(seriesItems.length / pageSize));

    if (currentPage >= pageCount) {
      currentPage = pageCount - 1;
    }

    const start = currentPage * pageSize;
    const pageItems = seriesItems.slice(start, start + pageSize);
    const displayLayout = getDisplayLayout(pageItems.length, capacityLayout);
    applyGridLayout(displayLayout);
    grid.replaceChildren(...pageItems.map((item) => createSeriesCard(item, onSelectSeries)));

    previousButton.hidden = currentPage === 0;
    nextButton.hidden = currentPage >= pageCount - 1;
  }

  function updateLayout(): void {
    const nextLayout = getGridLayout();
    const layoutChanged =
      nextLayout.columns !== capacityLayout.columns || nextLayout.rows !== capacityLayout.rows;

    if (!layoutChanged) {
      return;
    }

    capacityLayout = nextLayout;
    renderPage();
  }

  previousButton.addEventListener('click', () => {
    if (currentPage === 0) {
      return;
    }

    currentPage -= 1;
    renderPage();
  });

  nextButton.addEventListener('click', () => {
    const pageCount = Math.max(1, Math.ceil(seriesItems.length / getPageSize(capacityLayout)));

    if (currentPage >= pageCount - 1) {
      return;
    }

    currentPage += 1;
    renderPage();
  });

  renderPage();

  window.addEventListener('resize', updateLayout);

  panel.append(previousButton, grid, nextButton);
  return panel;
}
