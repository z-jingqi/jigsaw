export interface MainScreenHandle {
  show: () => void;
  hide: () => void;
}

export function createMainScreen(
  onStart: () => void,
  onSettings: () => void,
): MainScreenHandle {
  const root = document.getElementById('main-screen');
  const startBtn = document.getElementById('main-start-button');
  const settingsBtn = document.getElementById('main-settings-button');
  if (!root || !startBtn || !settingsBtn) throw new Error('main-screen markup missing');

  startBtn.addEventListener('click', () => onStart());
  settingsBtn.addEventListener('click', () => onSettings());

  return {
    show: () => root.classList.remove('hidden'),
    hide: () => root.classList.add('hidden'),
  };
}
