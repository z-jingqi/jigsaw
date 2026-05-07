import { BookOpen, Puzzle, Settings, createElement } from 'lucide';

type NavItem = {
  id: string;
  label: string;
  icon: typeof Puzzle;
  active?: boolean;
};

const navItems: NavItem[] = [
  { id: 'series', label: '系列', icon: Puzzle, active: true },
  { id: 'gallery', label: '图鉴', icon: BookOpen },
  { id: 'settings', label: '设置', icon: Settings },
];

function createIcon(icon: typeof Puzzle): SVGElement {
  const iconElement = createElement(icon, {
    class: 'side-nav-icon',
    'aria-hidden': 'true',
    'stroke-width': 2.4,
  });

  return iconElement;
}

export function createSideNav(): HTMLElement {
  const nav = document.createElement('nav');
  nav.className = 'side-nav';
  nav.setAttribute('aria-label', '主导航');

  navItems.forEach((item) => {
    const button = document.createElement('button');
    button.className = item.active ? 'side-nav-item side-nav-item-active' : 'side-nav-item';
    button.type = 'button';
    button.dataset.nav = item.id;
    button.append(createIcon(item.icon));

    const label = document.createElement('span');
    label.textContent = item.label;
    button.append(label);

    nav.appendChild(button);
  });

  return nav;
}
