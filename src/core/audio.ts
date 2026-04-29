import snapUrl from '../../assets/sfx/snap.wav';
import completeUrl from '../../assets/sfx/complete.wav';
import { getSettings } from './settings';

type SoundName = 'snap' | 'complete';

const sources: Record<SoundName, string> = {
  snap: snapUrl,
  complete: completeUrl,
};

/** Per-sound base volume; user's settings.sfxVolume scales these down further. */
const baseVolumes: Record<SoundName, number> = {
  snap: 0.9,
  complete: 1.0,
};

const elements: Partial<Record<SoundName, HTMLAudioElement>> = {};

function get(name: SoundName): HTMLAudioElement {
  let el = elements[name];
  if (!el) {
    el = new Audio(sources[name]);
    el.preload = 'auto';
    elements[name] = el;
  }
  return el;
}

export function playSfx(name: SoundName): void {
  const el = get(name);
  const userVol = getSettings().sfxVolume;
  el.volume = Math.max(0, Math.min(1, baseVolumes[name] * userVol));
  el.currentTime = 0;
  el.play().catch(() => {});
}

export function preloadSfx(): void {
  for (const name of Object.keys(sources) as SoundName[]) get(name);
}
