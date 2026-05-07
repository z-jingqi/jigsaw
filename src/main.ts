import homeBgUrl from '../assets/ui/home-bg.png';
import { createSeriesGrid } from './ui/series-grid';
import { createSideNav } from './ui/side-nav';

const app = document.getElementById('app');

if (app) {
  const mainScreen = document.createElement('main');
  mainScreen.className = 'main-screen';
  mainScreen.setAttribute('aria-label', '主界面');
  mainScreen.style.backgroundImage = `url("${homeBgUrl}")`;
  mainScreen.appendChild(createSideNav());
  mainScreen.appendChild(createSeriesGrid());
  app.replaceChildren(mainScreen);
}
