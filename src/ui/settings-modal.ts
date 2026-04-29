import { getSettings, updateSettings, type ResolutionId } from '../core/settings';

export interface SettingsModalHandle {
  show: () => void;
  hide: () => void;
}

export function createSettingsModal(): SettingsModalHandle {
  const root = document.getElementById('settings-modal');
  const closeBtn = document.getElementById('settings-close-button');
  const sfx = document.getElementById('settings-sfx') as HTMLInputElement | null;
  const sfxValue = document.getElementById('settings-sfx-value');
  const longPressEnabled = document.getElementById('settings-longpress-enabled') as HTMLInputElement | null;
  const longPressMs = document.getElementById('settings-longpress-ms') as HTMLInputElement | null;
  const resolution = document.getElementById('settings-resolution') as HTMLSelectElement | null;
  if (
    !root ||
    !closeBtn ||
    !sfx ||
    !sfxValue ||
    !longPressEnabled ||
    !longPressMs ||
    !resolution
  ) {
    throw new Error('settings-modal markup missing');
  }

  const sync = (): void => {
    const s = getSettings();
    sfx.value = String(Math.round(s.sfxVolume * 100));
    sfxValue.textContent = `${Math.round(s.sfxVolume * 100)}%`;
    longPressEnabled.checked = s.longPressEnabled;
    longPressMs.value = String(s.longPressMs);
    longPressMs.disabled = !s.longPressEnabled;
    resolution.value = s.resolution;
  };

  sfx.addEventListener('input', () => {
    const v = Math.max(0, Math.min(100, Number(sfx.value) || 0));
    updateSettings({ sfxVolume: v / 100 });
    sfxValue.textContent = `${v}%`;
  });
  longPressEnabled.addEventListener('change', () => {
    updateSettings({ longPressEnabled: longPressEnabled.checked });
    longPressMs.disabled = !longPressEnabled.checked;
  });
  longPressMs.addEventListener('change', () => {
    const v = Math.max(150, Math.min(2000, Number(longPressMs.value) || 450));
    updateSettings({ longPressMs: v });
    longPressMs.value = String(v);
  });
  resolution.addEventListener('change', () => {
    updateSettings({ resolution: resolution.value as ResolutionId });
  });
  closeBtn.addEventListener('click', () => root.classList.add('hidden'));

  // Close on backdrop click (clicking the overlay itself, not its inner panel).
  root.addEventListener('click', (e) => {
    if (e.target === root) root.classList.add('hidden');
  });

  return {
    show: () => {
      sync();
      root.classList.remove('hidden');
    },
    hide: () => root.classList.add('hidden'),
  };
}
