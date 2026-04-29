export interface PauseMenuHandle {
  show: (title: string) => void;
  hide: () => void;
  isOpen: () => boolean;
}

export function createPauseMenu(
  onResume: () => void,
  onRestart: () => void,
  onBackToLevels: () => void,
): PauseMenuHandle {
  const root = document.getElementById('pause-menu');
  const title = document.getElementById('pause-title');
  const resume = document.getElementById('pause-resume-button');
  const restart = document.getElementById('pause-restart-button');
  const back = document.getElementById('pause-back-to-levels-button');
  if (!root || !title || !resume || !restart || !back) {
    throw new Error('pause menu markup missing');
  }

  resume.addEventListener('click', () => onResume());
  restart.addEventListener('click', () => onRestart());
  back.addEventListener('click', () => onBackToLevels());
  root.addEventListener('click', (e) => {
    if (e.target === root) onResume();
  });

  return {
    show: (nextTitle) => {
      title.textContent = nextTitle;
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
    isOpen: () => !root.classList.contains('hidden'),
  };
}
