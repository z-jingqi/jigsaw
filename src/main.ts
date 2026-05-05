import type { FederatedPointerEvent } from 'pixi.js';
import { loadLevel, type LoadedLevel } from './core/level-loader';
import { PieceGroup, resetGroupIds } from './core/group';
import { trySnap } from './core/snap';
import { normalizeAngle, rotateDeg, sub } from './core/geometry';
import type { DifficultyEntry, LevelData, Vec2 } from './core/types';
import { buttonOf, isTouchDevice } from './core/input';
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
import mainBgUrl from '../assets/ui/main-bg.png';
import titlePuzzleHouseUrl from '../assets/ui/title-puzzle-house.png';
import btnStartHoverSpriteUrl from '../assets/ui/btn-start-hover-sprite.png';
import btnStartHoverMeta from '../assets/ui/btn-start-hover-sprite.json';
import btnSettingsHoverSpriteUrl from '../assets/ui/btn-settings-hover-sprite-v2.png';
import btnSettingsHoverMeta from '../assets/ui/btn-settings-hover-sprite-v2.json';
import settingsPanelUrl from '../assets/ui/settings-panel.png';
import settingsCloseUrl from '../assets/ui/settings-close.png';
import settingsGearUrl from '../assets/ui/settings-gear.png';
import completePanelUrl from '../assets/ui/complete-panel.png';
import seriesCatCoverUrl from '../assets/ui/series-cat-cover.png';
import sakuraMatUrl from '../assets/tablecloths/sakura-mat.png';

type AppView = 'main' | 'series' | 'levels' | 'game' | 'complete';

interface GameState {
  stage: StageHandles;
  loaded: LoadedLevel;
  groups: PieceGroup[];
  views: Map<number, GroupView>;
  activeDrag: ActiveDrag | null;
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

let state: GameState | null = null;
let currentSeries: SeriesEntry | null = null;
let currentLevel: LevelEntry | null = null;
let currentDifficulty: DifficultyEntry | null = null;
let currentView: AppView = 'main';

const hud = document.getElementById('hud')!;
const globalBackBtn = document.getElementById('global-back-button')!;
const globalSettingsBtn = document.getElementById('global-settings-button')!;
const DEFAULT_HUD_HELP = isTouchDevice()
  ? '拖动移动'
  : '左键拖动 · 右键旋转';

document.documentElement.style.setProperty('--main-bg-image', `url("${mainBgUrl}")`);
document.documentElement.style.setProperty('--main-title-image', `url("${titlePuzzleHouseUrl}")`);
document.documentElement.style.setProperty('--btn-start-image', `url("${btnStartHoverSpriteUrl}")`);
document.documentElement.style.setProperty('--btn-start-frame-count', String(btnStartHoverMeta.frameCount));
document.documentElement.style.setProperty('--btn-start-frame-steps', String(Math.max(1, btnStartHoverMeta.frameCount - 1)));
document.documentElement.style.setProperty('--btn-start-sheet-size', `${btnStartHoverMeta.frameCount * 100}% 100%`);
document.documentElement.style.setProperty('--btn-start-hover-duration', `${btnStartHoverMeta.duration}s`);
document.documentElement.style.setProperty('--btn-settings-image', `url("${btnSettingsHoverSpriteUrl}")`);
document.documentElement.style.setProperty('--btn-settings-frame-count', String(btnSettingsHoverMeta.frameCount));
document.documentElement.style.setProperty('--btn-settings-frame-steps', String(Math.max(1, btnSettingsHoverMeta.frameCount - 1)));
document.documentElement.style.setProperty('--btn-settings-sheet-size', `${btnSettingsHoverMeta.frameCount * 100}% 100%`);
document.documentElement.style.setProperty('--btn-settings-hover-duration', `${btnSettingsHoverMeta.duration}s`);
document.documentElement.style.setProperty('--settings-panel-image', `url("${settingsPanelUrl}")`);
document.documentElement.style.setProperty('--settings-close-image', `url("${settingsCloseUrl}")`);
document.documentElement.style.setProperty('--settings-gear-image', `url("${settingsGearUrl}")`);
document.documentElement.style.setProperty('--complete-panel-image', `url("${completePanelUrl}")`);
document.documentElement.style.setProperty('--series-cat-cover-image', `url("${seriesCatCoverUrl}")`);

function difficultyToOverrides(d: DifficultyEntry): Partial<LevelData> {
  const slice: LevelData['slice'] = {
    mode: 'grid',
    cols: d.cols,
    rows: d.rows,
    seed: `${levelSeedBase()}|${d.label}|${d.cols}x${d.rows}|${d.shapeStyle ?? 'default'}`,
  };
  if (d.knobs !== undefined) slice.knobs = d.knobs;
  if (d.shapeStyle !== undefined) slice.shapeStyle = d.shapeStyle;
  if (d.bounds !== undefined) slice.bounds = d.bounds;
  const difficulty: Partial<LevelData['difficulty']> = {};
  if (d.scatterRadius !== undefined) difficulty.scatterRadius = d.scatterRadius;
  return {
    slice,
    ...(Object.keys(difficulty).length ? { difficulty: difficulty as LevelData['difficulty'] } : {}),
  };
}

function levelSeedBase(): string {
  return currentLevel?.path ?? 'level';
}

function setHudCopy(): void {
  hud.textContent = `${DEFAULT_HUD_HELP} · 0:00 · 0 步`;
}
setHudCopy();

const settingsModal = createSettingsModal();
globalSettingsBtn.addEventListener('click', () => openSettings());

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
    () => openSettings(),
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
  globalBackBtn.classList.add('hidden');
  if (opts.gear) globalSettingsBtn.classList.remove('hidden');
  else globalSettingsBtn.classList.add('hidden');
}

function goToMain(): void {
  currentView = 'main';
  teardownGameIfAny();
  hideAllOverlays();
  hud.classList.add('hidden');
  setGlobalChrome({ gear: false, back: false });
  mainScreen?.show();
}

function goToSeries(): void {
  currentView = 'series';
  teardownGameIfAny();
  hideAllOverlays();
  hud.classList.add('hidden');
  setGlobalChrome({ gear: true, back: false });
  seriesList?.show();
}

function goToLevels(series?: SeriesEntry): void {
  currentView = 'levels';
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
  currentView = 'game';
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
  hud.textContent = `${DEFAULT_HUD_HELP} · ${formatElapsedMs(s.elapsedMs)} · ${s.moves} 步`;
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

function parseTablecloth(loaded: LoadedLevel): { color: number; imageUrl?: string } {
  const t = loaded.level.tablecloth;
  if (t.type === 'color' && t.value.startsWith('#')) {
    return { color: parseInt(t.value.slice(1), 16) };
  }
  if (t.type === 'image') {
    return {
      color: 0xf2e3c8,
      imageUrl: tableBackgroundUrl(t.value),
    };
  }
  return { color: 0xf2e3c8 };
}

function openSettings(): void {
  const goBack = (): void => {
    if (currentView === 'series') goToMain();
    else if (currentView === 'levels') goToSeries();
    else if (currentView === 'game' || currentView === 'complete') goToLevels();
  };
  settingsModal.setNavigation({
    backLabel: '返回',
    onBack: currentView === 'main' ? undefined : goBack,
    showMain: currentView !== 'main' && currentView !== 'series',
    onMain: goToMain,
  });
  settingsModal.show();
}

function tableBackgroundUrl(value: string): string | undefined {
  const backgrounds: Record<string, string> = {
    'sakura-mat.png': sakuraMatUrl,
  };
  return backgrounds[value];
}

function scatterPieces(loaded: LoadedLevel, stage: StageHandles): PieceGroup[] {
  const groups: PieceGroup[] = [];
  const minSide = Math.min(stage.canvasWidth, stage.canvasHeight);
  const requested = loaded.level.difficulty.scatterRadius;
  const cap = minSide * 0.46;
  const radius = Math.max(120, Math.min(requested, cap));
  const minR = radius * 0.62;
  const rotationEnabled = loaded.level.difficulty.rotationEnabled;

  const placements: Array<{ piece: LoadedLevel['pieces'][number]; footprint: number; pos: Vec2 }> = [];
  const footprintPadding = Math.max(20, minSide * 0.018);
  const orderedPieces = [...loaded.pieces]
    .map((piece) => ({ piece, footprint: estimatePieceFootprint(piece) + footprintPadding }))
    .sort((a, b) => b.footprint - a.footprint);

  for (const entry of orderedPieces) {
    const pos = findScatterPosition(placements, entry.footprint, minR, radius);
    placements.push({ ...entry, pos });
  }

  for (const entry of placements) {
    const rot = rotationEnabled ? Math.floor(Math.random() * 4) * 90 : 0;
    groups.push(new PieceGroup(entry.piece, entry.pos, rot));
  }
  return groups;
}

function estimatePieceFootprint(piece: LoadedLevel['pieces'][number]): number {
  let maxSq = 0;
  for (const [x, y] of piece.polygon) {
    const dx = x - piece.homePosition[0];
    const dy = y - piece.homePosition[1];
    const distSq = dx * dx + dy * dy;
    if (distSq > maxSq) maxSq = distSq;
  }
  return Math.max(18, Math.sqrt(maxSq));
}

function findScatterPosition(
  placements: Array<{ footprint: number; pos: Vec2 }>,
  footprint: number,
  minR: number,
  maxR: number,
): Vec2 {
  const tries = 140;
  for (let i = 0; i < tries; i++) {
    const angle = Math.random() * Math.PI * 2;
    const t = (i + Math.random()) / tries;
    const r = minR + (maxR - minR) * Math.sqrt(t);
    const candidate: Vec2 = [Math.cos(angle) * r, Math.sin(angle) * r];
    if (isScatterPositionValid(candidate, footprint, placements)) return candidate;
  }

  const goldenAngle = Math.PI * (3 - Math.sqrt(5));
  const startIndex = placements.length + 1;
  for (let i = 0; i < 220; i++) {
    const ringT = (i + startIndex) / (220 + startIndex);
    const r = minR + (maxR - minR) * Math.min(1, Math.sqrt(ringT));
    const angle = goldenAngle * (i + startIndex);
    const candidate: Vec2 = [Math.cos(angle) * r, Math.sin(angle) * r];
    if (isScatterPositionValid(candidate, footprint, placements, 0.92)) return candidate;
  }

  const fallbackAngle = goldenAngle * (placements.length + 1);
  return [Math.cos(fallbackAngle) * maxR, Math.sin(fallbackAngle) * maxR];
}

function isScatterPositionValid(
  candidate: Vec2,
  footprint: number,
  placements: Array<{ footprint: number; pos: Vec2 }>,
  looseness = 1,
): boolean {
  for (const placed of placements) {
    const dx = candidate[0] - placed.pos[0];
    const dy = candidate[1] - placed.pos[1];
    const minDistance = (footprint + placed.footprint) * looseness;
    if (dx * dx + dy * dy < minDistance * minDistance) return false;
  }
  return true;
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
      startDrag(s, view.group, e);
      e.stopPropagation();
    });
  }

  const onMove = (e: FederatedPointerEvent): void => {
    if (s.activeDrag) updateDrag(s, e);
  };
  stage.app.stage.on('globalpointermove', onMove);

  const release = (): void => {
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
      currentView = 'complete';
      hud.classList.add('hidden');
      setGlobalChrome({ gear: true, back: false });
      completeScreen.show({
        title: s.loaded.level.title,
        difficultyLabel: currentDifficulty?.label ? `难度 ${currentDifficulty.label}` : '拼图',
        elapsedMs: s.elapsedMs,
        moves: s.moves,
        imageUrl: `/${currentLevel?.path ?? ''}/source.png`,
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
  pauseGameplay();
});
