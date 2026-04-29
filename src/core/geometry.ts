import type { Vec2 } from './types';

export const TAU = Math.PI * 2;

export function add(a: Vec2, b: Vec2): Vec2 {
  return [a[0] + b[0], a[1] + b[1]];
}

export function sub(a: Vec2, b: Vec2): Vec2 {
  return [a[0] - b[0], a[1] - b[1]];
}

export function scale(a: Vec2, s: number): Vec2 {
  return [a[0] * s, a[1] * s];
}

export function dist(a: Vec2, b: Vec2): number {
  const dx = a[0] - b[0];
  const dy = a[1] - b[1];
  return Math.hypot(dx, dy);
}

export function rotateRad(p: Vec2, rad: number): Vec2 {
  const c = Math.cos(rad);
  const s = Math.sin(rad);
  return [p[0] * c - p[1] * s, p[0] * s + p[1] * c];
}

export function rotateDeg(p: Vec2, deg: number): Vec2 {
  return rotateRad(p, (deg * Math.PI) / 180);
}

export function degToRad(d: number): number {
  return (d * Math.PI) / 180;
}

export function normalizeAngle(deg: number): number {
  let a = deg % 360;
  if (a < 0) a += 360;
  return a;
}

export function angleDeltaAbs(a: number, b: number): number {
  const delta = Math.abs(normalizeAngle(a) - normalizeAngle(b)) % 360;
  return Math.min(delta, 360 - delta);
}

/** Squared distance from point p to the line segment a..b. */
export function pointSegSqDist(p: Vec2, a: Vec2, b: Vec2): number {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  if (dx === 0 && dy === 0) {
    const ex = p[0] - a[0], ey = p[1] - a[1];
    return ex * ex + ey * ey;
  }
  const t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy);
  const ct = Math.max(0, Math.min(1, t));
  const x = a[0] + ct * dx, y = a[1] + ct * dy;
  const ex = p[0] - x, ey = p[1] - y;
  return ex * ex + ey * ey;
}
