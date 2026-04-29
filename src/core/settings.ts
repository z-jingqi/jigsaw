/** User-facing settings persisted in localStorage and applied at runtime. */

export type ResolutionId = '1280x720' | '1920x1080' | '2560x1440' | 'native';

export interface Settings {
  /** SFX gain multiplier in [0, 1]. */
  sfxVolume: number;
  /** Whether long-press triggers rotation on touch / left-click. */
  longPressEnabled: boolean;
  /** Long-press duration in ms when enabled. */
  longPressMs: number;
  /** Canvas resolution preset. `native` fits to window. */
  resolution: ResolutionId;
}

const DEFAULTS: Settings = {
  sfxVolume: 0.6,
  longPressEnabled: true,
  longPressMs: 450,
  resolution: '1920x1080',
};

const STORAGE_KEY = 'jigsaw.settings.v1';

let cached: Settings | null = null;
const listeners = new Set<(s: Settings) => void>();

function read(): Settings {
  if (cached) return cached;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<Settings>;
      cached = { ...DEFAULTS, ...parsed };
    } else {
      cached = { ...DEFAULTS };
    }
  } catch {
    cached = { ...DEFAULTS };
  }
  return cached;
}

export function getSettings(): Settings {
  return read();
}

export function updateSettings(patch: Partial<Settings>): Settings {
  const next: Settings = { ...read(), ...patch };
  cached = next;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    /* ignore quota / privacy errors */
  }
  for (const fn of listeners) fn(next);
  return next;
}

export function onSettingsChange(fn: (s: Settings) => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function resolutionDimensions(id: ResolutionId): { width: number; height: number } | null {
  switch (id) {
    case '1280x720':
      return { width: 1280, height: 720 };
    case '1920x1080':
      return { width: 1920, height: 1080 };
    case '2560x1440':
      return { width: 2560, height: 1440 };
    case 'native':
      return null;
  }
}
