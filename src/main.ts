import type { FederatedPointerEvent } from 'pixi.js';
import { loadLevel, type LoadedLevel } from './core/level-loader';
import { PieceGroup, resetGroupIds } from './core/group';
import { trySnap } from './core/snap';
import { normalizeAngle, rotateDeg, sub } from './core/geometry';
import type { DifficultyEntry, LevelData, Vec2 } from './core/types';
import { buttonOf, isTouchDevice, pointerKind } from './core/input';
import { createStage, type StageHandles } from './render/stage';
import { GroupView } from './render/piece-view';
import { createMainScreen } from './ui/main-screen';
import { createSeriesList, loadLevelIndex, type LevelEntry, type SeriesEntry } from './ui/series-list';
import { createLevelsList } from './ui/levels-list';
import { createCompleteScreen } from './ui/complete-screen';
import { createPauseMenu } from './ui/pause-menu';
import { createSettingsModal } from './ui/settings-modal';
import { playSfx, preloadSfx } from './core/audio';
import { saveCompletion } from './core/progress';
import { getSettings } from './core/settings';

const LONG_PRESS_MOVE_THRESHOLD = 6;

interface GameState {
  stage: StageHandles;
  loaded: LoadedLevel;
  groups: PieceGroup[];
  views: Map<number, GroupView>;
  activeDrag: ActiveDrag | null;
  pending: PendingGesture | null;
  startedAt: number;
  elapsedMs: number;
  moves: number;
  hudTimerId: number | null;
  cleanup: Array<() => void>;
}

interface ActiveDrag {
  group: PieceGroup;
  pointerOffset: Vec2;
}

interface PendingGesture {
  group: PieceGroup;
  startWorld: Vec2;
  pointerOffset: Vec2;
  timer: number;
}

let state: GameState | null = null;
let currentSeries: SeriesEntry | null = null;
let currentLevel: LevelEntry | null = null;
let currentDifficulty: DifficultyEntry | null = null;

const hud = document.getElementById('hud')!;
const globalBackBtn = document.getElementById('global-back-button')!;
const globalSettingsBtn = document.getElementById('global-settings-button')!;
const DEFAULT_HUD_HELP = isTouchDevice()
  ? 'Drag to move · Long-press to rotate'
  : 'Left-drag to move · Right-click to rotate';

function difficultyToOverrides(d: DifficultyEntry): Partial<LevelData> {
  const slice: LevelData['slice'] = {
    mode: 'grid',
    cols: d.cols,
    rows: d.rows,
    knobs: d.knobs ?? false,
    shapeStyle: d.shapeStyle,
    seed: `${levelSeedBase()}|${d.label}|${d.cols}x${d.rows}|${d.shapeStyle ?? 'default'}`,
  };
  const difficulty: Partial<LevelData['difficulty']> = {};
  if (d.scatterRadius !== undefined) difficulty.scatterRadius = d.scatterRadius;
  if (d.rotationEnabled !== undefined) difficulty.rotationEnabled = d.rotationEnabled;
  return {
    slice,
    ...(Object.keys(difficulty).length ? { difficulty: difficulty as LevelData['difficulty'] } : {}),
  };
}

function levelSeedBase(): string {
  return currentLevel?.path ?? 'level';
}

function setHudCopy(): void {
  hud.textContent = `${DEFAULT_HUD_HELP} · 0:00 · 0 moves`;
}
setHudCopy();

const settingsModal = createSettingsModal();
globalSettingsBtn.addEventListener('click', () => settingsModal.show());

const completeScreen = createCompleteScreen(
  () => void onPlayAgain(),
  () => goToLevels(),
);
const pauseMenu = createPauseMenu(
  () => resumeGameplay(),
  () => void onPlayAgain(),
  () => goToLevels(),
);

let mainScreen: ReturnType<typeof createMainScreen> | null = null;
let seriesList: ReturnType<typeof createSeriesList> | null = null;
let levelsList: ReturnType<typeof createLevelsList> | null = null;

void boot();

async function boot(): Promise<void> {
  const index = await loadLevelIndex();

  mainScreen = createMainScreen(
    () => goToSeries(),
    () => settingsModal.show(),
  );
  seriesList = createSeriesList(
    index,
    (series) => goToLevels(series),
    () => goToMain(),
  );
  levelsList = createLevelsList(
    (level, diff) => void onPickLevel(level, diff),
    () => goToSeries(),
  );

  goToMain();

  if (import.meta.env.DEV) {
    const { mountDevPanel } = await import('./dev/dev-panel');
    mountDevPanel({
      getApp: () => state?.stage.app ?? null,
      getLevel: () => state?.loaded.level ?? null,
      reslice: async (overrides) => {
        if (!currentLevel) return;
        await onStart(currentLevel, overrides);
      },
      solveCurrent: () => {
        if (!state) return;
        autoSolveCurrent(state);
      },
    });
  }
}

function hideAllOverlays(): void {
  mainScreen?.hide();
  seriesList?.hide();
  levelsList?.hide();
  completeScreen.hide();
  pauseMenu.hide();
}

function setGlobalChrome(opts: { gear: boolean; back: boolean }): void {
  if (opts.back) globalBackBtn.classList.remove('hidden');
  else globalBackBtn.classList.add('hidden');
  if (opts.gear) globalSettingsBtn.classList.remove('hidden');
  else globalSettingsBtn.classList.add('hidden');
}

function goToMain(): void {
  teardownGameIfAny();
  hideAllOverlays();
  hud.classList.add('hidden');
  setGlobalChrome({ gear: false, back: false });
  mainScreen?.show();
}

function goToSeries(): void {
  teardownGameIfAny();
  hideAllOverlays();
  hud.classList.add('hidden');
  setGlobalChrome({ gear: true, back: false });
  seriesList?.show();
}

function goToLevels(series?: SeriesEntry): void {
  if (series) currentSeries = series;
  if (!currentSeries) {
    goToSeries();
    return;
  }
  teardownGameIfAny();
  hideAllOverlays();
  hud.classList.add('hidden');
  setGlobalChrome({ gear: true, back: false });
  levelsList?.show(currentSeries);
}

function teardownGameIfAny(): void {
  if (state) {
    teardown(state);
    state = null;
  }
}

async function onPickLevel(level: LevelEntry, diff: DifficultyEntry): Promise<void> {
  currentLevel = level;
  currentDifficulty = diff;
  await onStart(level, difficultyToOverrides(diff));
}

async function onPlayAgain(): Promise<void> {
  if (!currentLevel || !currentDifficulty) return;
  await onStart(currentLevel, difficultyToOverrides(currentDifficulty));
}

async function onStart(level: LevelEntry, overrides?: Partial<LevelData>): Promise<void> {
  hideAllOverlays();
  hud.classList.remove('hidden');
  setGlobalChrome({ gear: true, back: true });
  preloadSfx();

  if (state) {
    teardown(state);
    state = null;
  }

  const basePath = `/${level.path}`;
  const loaded = await loadLevel(basePath, overrides);
  const stage = await createStage(document.getElementById('app')!, parseTablecloth(loaded));

  resetGroupIds();
  const groups = scatterPieces(loaded, stage);
  const views = new Map<number, GroupView>();
  for (const g of groups) {
    const v = new GroupView(g, loaded.texture);
    stage.world.addChild(v.container);
    views.set(g.id, v);
  }

  state = {
    stage,
    loaded,
    groups,
    views,
    activeDrag: null,
    pending: null,
    startedAt: performance.now(),
    elapsedMs: 0,
    moves: 0,
    hudTimerId: null,
    cleanup: [],
  };
  beginHudTicker(state);
  wireInteraction(state);
}

function teardown(s: GameState): void {
  if (s.pending) clearTimeout(s.pending.timer);
  if (s.hudTimerId !== null) window.clearInterval(s.hudTimerId);
  for (const cleanup of s.cleanup) cleanup();
  s.cleanup.length = 0;
  for (const v of s.views.values()) v.destroy();
  s.stage.destroy();
}

function formatElapsedMs(elapsedMs: number): string {
  const totalSeconds = Math.max(0, Math.round(elapsedMs / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
}

function updateHud(s: GameState): void {
  hud.textContent = `${DEFAULT_HUD_HELP} · ${formatElapsedMs(s.elapsedMs)} · ${s.moves} move${s.moves === 1 ? '' : 's'}`;
}

function beginHudTicker(s: GameState): void {
  const tick = (): void => {
    if (pauseMenu.isOpen()) return;
    s.elapsedMs = performance.now() - s.startedAt;
    updateHud(s);
  };
  tick();
  s.hudTimerId = window.setInterval(tick, 250);
}

function pauseGameplay(): void {
  if (!state || pauseMenu.isOpen()) return;
  if (state.hudTimerId !== null) {
    window.clearInterval(state.hudTimerId);
    state.hudTimerId = null;
  }
  state.elapsedMs = performance.now() - state.startedAt;
  updateHud(state);
  pauseMenu.show(currentLevel?.title ?? state.loaded.level.title);
}

function resumeGameplay(): void {
  if (!state || !pauseMenu.isOpen()) return;
  state.startedAt = performance.now() - state.elapsedMs;
  pauseMenu.hide();
  beginHudTicker(state);
}

function parseTablecloth(loaded: LoadedLevel): number {
  const t = loaded.level.tablecloth;
  if (t.type === 'color' && t.value.startsWith('#')) {
    return parseInt(t.value.slice(1), 16);
  }
  return 0x2b2b2b;
}

function scatterPieces(loaded: LoadedLevel, stage: StageHandles): PieceGroup[] {
  const groups: PieceGroup[] = [];
  const minSide = Math.min(stage.canvasWidth, stage.canvasHeight);
  const requested = loaded.level.difficulty.scatterRadius;
  const cap = minSide * 0.45;
  const radius = Math.max(80, Math.min(requested, cap));
  const minR = radius * 0.45;
  const rotationEnabled = loaded.level.difficulty.rotationEnabled;
  for (const piece of loaded.pieces) {
    const angle = Math.random() * Math.PI * 2;
    const r = minR + Math.random() * (radius - minR);
    const pos: Vec2 = [Math.cos(angle) * r, Math.sin(angle) * r];
    const rot = rotationEnabled ? Math.floor(Math.random() * 4) * 90 : 0;
    groups.push(new PieceGroup(piece, pos, rot));
  }
  return groups;
}

function wireInteraction(s: GameState): void {
  const { stage, views } = s;

  for (const view of views.values()) {
    view.container.on('pointerdown', (e: FederatedPointerEvent) => {
      const btn = buttonOf(e);
      if (btn === 'right') {
        rotateGroupAt(s, view.group, worldOf(s, e));
        e.stopPropagation();
        return;
      }
      if (btn !== 'left') return;
      const settings = getSettings();
      if (pointerKind(e) === 'touch' && settings.longPressEnabled) {
        startGesture(s, view.group, e);
      } else {
        startDrag(s, view.group, e);
      }
      e.stopPropagation();
    });
  }

  const onMove = (e: FederatedPointerEvent): void => {
    if (s.pending) {
      const cur = worldOf(s, e);
      const dx = cur[0] - s.pending.startWorld[0];
      const dy = cur[1] - s.pending.startWorld[1];
      if (Math.hypot(dx, dy) > LONG_PRESS_MOVE_THRESHOLD) {
        promotePendingToDrag(s);
      }
      return;
    }
    if (s.activeDrag) updateDrag(s, e);
  };
  stage.app.stage.on('globalpointermove', onMove);

  const release = (): void => {
    if (s.pending) {
      clearTimeout(s.pending.timer);
      s.pending = null;
      return;
    }
    if (s.activeDrag) endDrag(s);
  };
  stage.app.stage.on('pointerup', release);
  stage.app.stage.on('pointerupoutside', release);
  window.addEventListener('pointerup', release);
  window.addEventListener('blur', release);
  const onKeyDown = (e: KeyboardEvent): void => {
    if (e.key !== 'Escape' || !state) return;
    e.preventDefault();
    if (pauseMenu.isOpen()) resumeGameplay();
    else pauseGameplay();
  };
  window.addEventListener('keydown', onKeyDown);

  s.cleanup.push(() => stage.app.stage.off('globalpointermove', onMove));
  s.cleanup.push(() => stage.app.stage.off('pointerup', release));
  s.cleanup.push(() => stage.app.stage.off('pointerupoutside', release));
  s.cleanup.push(() => window.removeEventListener('pointerup', release));
  s.cleanup.push(() => window.removeEventListener('blur', release));
  s.cleanup.push(() => window.removeEventListener('keydown', onKeyDown));
}

function worldOf(s: GameState, e: FederatedPointerEvent): Vec2 {
  const w = e.getLocalPosition(s.stage.world);
  return [w.x, w.y];
}

function startGesture(s: GameState, group: PieceGroup, e: FederatedPointerEvent): void {
  const startWorld = worldOf(s, e);
  const pointerOffset = sub(startWorld, group.worldPosition);
  const ms = getSettings().longPressMs;
  const timer = window.setTimeout(() => {
    if (!s.pending || s.pending.group !== group) return;
    const pivot = s.pending.startWorld;
    s.pending = null;
    rotateGroupAt(s, group, pivot);
  }, ms);
  s.pending = { group, startWorld, pointerOffset, timer };
}

function promotePendingToDrag(s: GameState): void {
  if (!s.pending) return;
  const { group, pointerOffset } = s.pending;
  clearTimeout(s.pending.timer);
  s.pending = null;
  s.activeDrag = { group, pointerOffset };
  s.stage.world.addChild(s.views.get(group.id)!.container);
  s.views.get(group.id)!.setDragging(true);
}

function startDrag(s: GameState, group: PieceGroup, e: FederatedPointerEvent): void {
  const world = e.getLocalPosition(s.stage.world);
  const pointerOffset: Vec2 = sub([world.x, world.y], group.worldPosition);
  s.activeDrag = { group, pointerOffset };
  s.stage.world.addChild(s.views.get(group.id)!.container);
  s.views.get(group.id)!.setDragging(true);
}

function updateDrag(s: GameState, e: FederatedPointerEvent): void {
  if (!s.activeDrag) return;
  const world = e.getLocalPosition(s.stage.world);
  const newPos: Vec2 = sub([world.x, world.y], s.activeDrag.pointerOffset);
  s.activeDrag.group.worldPosition = newPos;
  s.views.get(s.activeDrag.group.id)!.syncTransform();
}

function endDrag(s: GameState): void {
  if (!s.activeDrag) return;
  const group = s.activeDrag.group;
  s.views.get(group.id)!.setDragging(false);
  s.activeDrag = null;
  s.moves += 1;
  updateHud(s);
  runSnap(s, group);
  checkComplete(s);
}

function rotateGroupAt(s: GameState, group: PieceGroup, cursor: Vec2): void {
  if (!s.loaded.level.difficulty.rotationEnabled) return;
  const startPos: Vec2 = [group.worldPosition[0], group.worldPosition[1]];
  const startRot = group.worldRotation;
  const offset = sub(cursor, group.worldPosition);
  const rotatedOffset = rotateDeg(offset, 90);
  group.worldPosition = sub(cursor, rotatedOffset);
  group.worldRotation = normalizeAngle(group.worldRotation + 90);
  s.moves += 1;
  updateHud(s);
  s.views.get(group.id)!.animateRotateAround(cursor, startPos, startRot);
  runSnap(s, group);
  checkComplete(s);
}

function runSnap(s: GameState, group: PieceGroup): void {
  const tolerance = s.loaded.level.snap.positionTolerance;
  const angleTolerance = s.loaded.level.snap.angleTolerance;
  const result = trySnap(group, s.groups, tolerance, angleTolerance);
  if (result.consumed.length === 0) return;
  playSfx('snap');

  for (const c of result.consumed) {
    const v = s.views.get(c.id);
    if (v) {
      s.stage.world.removeChild(v.container);
      v.destroy();
      s.views.delete(c.id);
    }
  }
  s.groups = s.groups.filter((g) => !result.consumed.includes(g));

  const survivorView = s.views.get(group.id)!;
  survivorView.syncMembers();
  survivorView.syncTransform();
  s.stage.world.addChild(survivorView.container);
}

function checkComplete(s: GameState): void {
  if (s.groups.length === 1 && s.groups[0].members.length === s.loaded.pieces.length) {
    if (s.hudTimerId !== null) {
      window.clearInterval(s.hudTimerId);
      s.hudTimerId = null;
    }
    s.elapsedMs = performance.now() - s.startedAt;
    updateHud(s);
    if (currentLevel && currentDifficulty) {
      saveCompletion(currentLevel.path, currentDifficulty.label, s.elapsedMs, s.moves);
    }
    playSfx('complete');
    setTimeout(() => {
      hud.classList.add('hidden');
      setGlobalChrome({ gear: true, back: false });
      completeScreen.show({
        title: s.loaded.level.title,
        difficultyLabel: currentDifficulty?.label ? `Difficulty ${currentDifficulty.label}` : 'Puzzle',
        elapsedMs: s.elapsedMs,
        moves: s.moves,
      });
    }, 350);
  }
}

function autoSolveCurrent(s: GameState): void {
  if (s.hudTimerId !== null) {
    window.clearInterval(s.hudTimerId);
    s.hudTimerId = null;
  }
  const center: Vec2 = [s.loaded.bounds.width / 2, s.loaded.bounds.height / 2];
  for (const group of s.groups) {
    const anchor = group.members[0]?.piece.homePosition;
    if (!anchor) continue;
    group.worldRotation = 0;
    group.worldPosition = sub(anchor, center);
    s.views.get(group.id)?.syncTransform();
  }

  let changed = true;
  while (changed) {
    changed = false;
    for (const group of [...s.groups]) {
      if (!s.views.has(group.id)) continue;
      const before = s.groups.length;
      runSnap(s, group);
      if (s.groups.length !== before) changed = true;
    }
  }
  checkComplete(s);
}

globalBackBtn.addEventListener('click', () => {
  if (pauseMenu.isOpen()) resumeGameplay();
  else pauseGameplay();
});
