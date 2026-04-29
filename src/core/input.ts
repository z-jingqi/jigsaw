import type { FederatedPointerEvent } from 'pixi.js';

export type PointerButton = 'left' | 'right' | 'other';
export type PointerKind = 'mouse' | 'touch' | 'pen';

export function buttonOf(e: FederatedPointerEvent | PointerEvent): PointerButton {
  if (e.button === 0) return 'left';
  if (e.button === 2) return 'right';
  return 'other';
}

export function pointerKind(e: FederatedPointerEvent | PointerEvent): PointerKind {
  const t = e.pointerType;
  if (t === 'touch') return 'touch';
  if (t === 'pen') return 'pen';
  return 'mouse';
}

export function isTouchDevice(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(pointer: coarse)').matches === true;
}
