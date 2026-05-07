import { Building2, Cat, Flower2, Image, Mountain, Palette, PawPrint, Star, createElement } from 'lucide';
import seriesCardBgUrl from '../../assets/ui/series-list-panel-bg.png';
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

const seriesItems: SeriesItem[] = [
  { id: 'cats', title: '猫系列', progress: '24/24', coverUrl: catCoverUrl, icon: Cat },
  { id: 'masterpieces', title: '名画系列', progress: '18/24', coverUrl: masterpiecesCoverUrl, icon: Palette },
  { id: 'landscapes', title: '风景系列', progress: '12/24', icon: Mountain, badge: '新' },
  { id: 'still-life', title: '静物系列', progress: '8/24', icon: Image },
  { id: 'animals', title: '动物系列', progress: '15/24', icon: PawPrint },
  { id: 'architecture', title: '建筑系列', progress: '10/24', icon: Building2 },
  { id: 'illustration', title: '插画系列', progress: '6/24', icon: Cat },
  { id: 'plants', title: '植物系列', progress: '9/24', icon: Flower2 },
];

function createLucideIcon(icon: typeof Cat, className: string): SVGElement {
  return createElement(icon, {
    class: className,
    'aria-hidden': 'true',
    'stroke-width': 2.35,
  });
}

function createSeriesCard(item: SeriesItem): HTMLButtonElement {
  const card = document.createElement('button');
  card.className = 'series-card';
  card.type = 'button';
  card.dataset.series = item.id;
  card.style.backgroundImage = `url("${seriesCardBgUrl}")`;

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

export function createSeriesGrid(): HTMLElement {
  const panel = document.createElement('section');
  panel.className = 'series-grid-panel';
  panel.setAttribute('aria-label', '系列选择');

  const grid = document.createElement('div');
  grid.className = 'series-grid';
  seriesItems.forEach((item) => grid.appendChild(createSeriesCard(item)));

  panel.appendChild(grid);
  return panel;
}
