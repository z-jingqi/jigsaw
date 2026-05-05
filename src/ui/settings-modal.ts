import { getSettings, updateSettings } from '../core/settings';

export interface SettingsModalHandle {
  show: () => void;
  hide: () => void;
  setNavigation: (options: SettingsNavigation) => void;
}

export interface SettingsNavigation {
  backLabel?: string;
  onBack?: () => void;
  showMain?: boolean;
  onMain?: () => void;
}

export function createSettingsModal(): SettingsModalHandle {
  const root = document.getElementById('settings-modal');
  const closeBtn = document.getElementById('settings-close-button');
  const sfx = document.getElementById('settings-sfx') as HTMLInputElement | null;
  const sfxValue = document.getElementById('settings-sfx-value');
  const nav = document.getElementById('settings-nav');
  const mainBtn = document.getElementById('settings-main-button');
  const backBtn = document.getElementById('settings-back-button');
  if (
    !root ||
    !closeBtn ||
    !sfx ||
    !sfxValue ||
    !nav ||
    !mainBtn ||
    !backBtn
  ) {
    throw new Error('settings-modal markup missing');
  }

  let navigation: SettingsNavigation = {};

  const sync = (): void => {
    const s = getSettings();
    sfx.value = String(Math.round(s.sfxVolume * 100));
    sfxValue.textContent = `${Math.round(s.sfxVolume * 100)}%`;
    const hasBack = Boolean(navigation.onBack);
    const hasMain = Boolean(navigation.showMain && navigation.onMain);
    nav.classList.toggle('hidden', !hasBack && !hasMain);
    backBtn.classList.toggle('hidden', !hasBack);
    mainBtn.classList.toggle('hidden', !hasMain);
    backBtn.textContent = navigation.backLabel ?? '返回';
  };

  sfx.addEventListener('input', () => {
    const v = Math.max(0, Math.min(100, Number(sfx.value) || 0));
    updateSettings({ sfxVolume: v / 100 });
    sfxValue.textContent = `${v}%`;
  });
  mainBtn.addEventListener('click', () => {
    root.classList.add('hidden');
    navigation.onMain?.();
  });
  backBtn.addEventListener('click', () => {
    root.classList.add('hidden');
    navigation.onBack?.();
  });
  closeBtn.addEventListener('click', () => root.classList.add('hidden'));

  // Close on backdrop click (clicking the overlay itself, not its inner panel).
  root.addEventListener('click', (e) => {
    if (e.target === root) root.classList.add('hidden');
  });

  return {
    setNavigation: (options) => {
      navigation = options;
      sync();
    },
    show: () => {
      sync();
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
  };
}
