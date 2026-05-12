import homeBgUrl from '../assets/ui/home-bg.png';
import { createGameScreen } from './ui/game-screen';
import { createLevelList } from './ui/level-list';
import type { LevelSummary } from './ui/level-list';
import { createSeriesGrid } from './ui/series-grid';
import type { SeriesSummary } from './ui/series-grid';
import { createSideNav } from './ui/side-nav';

const app = document.getElementById('app');

function replaceAppContent(element: HTMLElement): void {
  if (!app) {
    return;
  }

  for (const child of app.children) {
    child.dispatchEvent(new CustomEvent('jigsaw:destroy'));
  }

  app.replaceChildren(element);
}

function createMainScreen(): HTMLElement {
  const mainScreen = document.createElement('main');
  mainScreen.className = 'main-screen';
  mainScreen.setAttribute('aria-label', '主界面');
  mainScreen.style.backgroundImage = `url("${homeBgUrl}")`;
  mainScreen.appendChild(createSideNav());
  mainScreen.appendChild(createSeriesGrid(showLevelList));
  return mainScreen;
}

function showHome(): void {
  if (!app) {
    return;
  }

  replaceAppContent(createMainScreen());
}

function showLevelList(series: SeriesSummary): void {
  if (!app) {
    return;
  }

  const mainScreen = document.createElement('main');
  mainScreen.className = 'main-screen';
  mainScreen.setAttribute('aria-label', `${series.title}关卡列表`);
  mainScreen.style.backgroundImage = `url("${homeBgUrl}")`;
  mainScreen.appendChild(createLevelList(series, showHome, showGame));
  replaceAppContent(mainScreen);
}

function showGame(level: LevelSummary): void {
  if (!app) {
    return;
  }

  replaceAppContent(
    createGameScreen({
      levelPath: level.path,
      onHome: showHome,
      onRestart: () => showGame(level),
      onExit: showHome,
    }),
  );
}

if (app) {
  showHome();
}
