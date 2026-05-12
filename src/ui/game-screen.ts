import { Home, Lightbulb, LogOut, Pause, Play, RotateCcw, Settings, Timer, X, createElement } from 'lucide';
import type { FederatedPointerEvent, Texture } from 'pixi.js';
import { Ticker } from 'pixi.js';
import { playSfx, preloadSfx } from '../core/audio';
import { sub, normalizeAngle } from '../core/geometry';
import { PieceGroup, resetGroupIds } from '../core/group';
import { loadLevel } from '../core/level-loader';
import { trySnap } from '../core/snap';
import type { PieceData, Tablecloth, Vec2 } from '../core/types';
import { GroupView } from '../render/piece-view';
import { createStage, type StageHandles } from '../render/stage';
import decorCatOrangeUrl from '../../assets/ui/decor-cat-orange.png';
import pausePanelBgUrl from '../../assets/ui/pause-panel-bg.png';

interface DragState {
  group: PieceGroup;
  view: GroupView;
  pointerId: number;
  offset: Vec2;
}

interface HintState {
  stop: () => void;
}

export interface GameScreenOptions {
  levelPath: string;
  onHome?: () => void;
  onRestart?: () => void;
  onExit?: () => void;
}

const DEFAULT_TABLE_COLOR = 0xeacb98;
const DESK_PADDING = 24;
const HUD_SAFE_TOP = 104;
const ALIGN_TOOLTIP = '全部转正：所有碎片回到原图方向';

function createLucideIcon(icon: typeof Timer, className: string): SVGElement {
  return createElement(icon, {
    class: className,
    'aria-hidden': 'true',
    'stroke-width': 2.5,
  });
}

function formatElapsed(ms: number): string {
  const seconds = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(seconds / 60);
  return `${String(minutes).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}

function parseColor(value: string | undefined): number {
  if (!value) return DEFAULT_TABLE_COLOR;
  const normalized = value.trim().replace('#', '');
  const parsed = Number.parseInt(normalized, 16);
  return Number.isFinite(parsed) ? parsed : DEFAULT_TABLE_COLOR;
}

function tableclothToBackground(tablecloth: Tablecloth, levelPath: string): { color: number; imageUrl?: string } {
  if (tablecloth.type === 'image') {
    const imageUrl = tablecloth.value.startsWith('/') ? tablecloth.value : `/${levelPath}/${tablecloth.value}`;
    return { color: DEFAULT_TABLE_COLOR, imageUrl };
  }

  return { color: parseColor(tablecloth.value) };
}

function randomBetween(min: number, max: number): number {
  if (max <= min) return min;
  return min + Math.random() * (max - min);
}

function screenToWorld(stage: StageHandles, point: { x: number; y: number }): Vec2 {
  return [point.x - stage.app.screen.width / 2, point.y - stage.app.screen.height / 2];
}

function getPlayRect(stage: StageHandles): { left: number; top: number; right: number; bottom: number } {
  return {
    left: DESK_PADDING,
    top: HUD_SAFE_TOP,
    right: stage.app.screen.width - DESK_PADDING,
    bottom: stage.app.screen.height - DESK_PADDING,
  };
}

function findHintPair(groups: PieceGroup[]): { a: PieceGroup; b: PieceGroup; aPieceId: string; bPieceId: string } | null {
  for (const a of groups) {
    for (const aMember of a.members) {
      for (const neighbor of aMember.piece.neighbors) {
        const b = groups.find((group) => group !== a && group.hasPiece(neighbor.pieceId));
        if (b) {
          return { a, b, aPieceId: aMember.piece.id, bPieceId: neighbor.pieceId };
        }
      }
    }
  }

  return null;
}

export function createGameScreen(options: GameScreenOptions): HTMLElement {
  const root = document.createElement('main');
  root.className = 'game-screen';
  root.setAttribute('aria-label', '游戏中界面');

  const stageHost = document.createElement('div');
  stageHost.className = 'game-stage-host';

  const loading = document.createElement('div');
  loading.className = 'game-loading';
  loading.textContent = '加载中';

  const hud = document.createElement('div');
  hud.className = 'game-hud';

  const timerChip = document.createElement('div');
  timerChip.className = 'game-timer';
  timerChip.appendChild(createLucideIcon(Timer, 'game-hud-icon'));
  const timerValue = document.createElement('span');
  timerValue.textContent = '00:00';
  timerChip.appendChild(timerValue);

  const actions = document.createElement('div');
  actions.className = 'game-actions';

  const hintButton = createHudButton(Lightbulb, '提示', '高亮一组可拼接碎片');
  const alignButton = createHudButton(RotateCcw, '转正', ALIGN_TOOLTIP);
  const settingsButton = createHudButton(Settings, '设置', '设置');
  const pauseButton = createHudButton(Pause, '暂停', '暂停');
  actions.append(hintButton, alignButton, settingsButton, pauseButton);
  hud.append(timerChip, actions);

  const pauseModal = createPauseModal();
  root.append(stageHost, loading, hud, pauseModal.overlay);

  let stage: StageHandles | null = null;
  let drag: DragState | null = null;
  let paused = false;
  let elapsedBeforePause = 0;
  let timerStart = performance.now();
  let timerHandle = window.setInterval(updateTimer, 250);
  let hintState: HintState | null = null;
  let groups: PieceGroup[] = [];
  const views = new Map<PieceGroup, GroupView>();
  let snapOptions = { positionTolerance: 12, angleTolerance: 8 };

  void init();

  hintButton.addEventListener('click', () => {
    if (!paused) showHint();
  });
  alignButton.addEventListener('click', () => {
    if (!paused) alignAllPieces();
  });
  pauseButton.addEventListener('click', () => {
    setPaused(true);
  });
  pauseModal.closeButton.addEventListener('click', () => {
    setPaused(false);
  });
  pauseModal.continueButton.addEventListener('click', () => {
    setPaused(false);
  });
  pauseModal.restartButton.addEventListener('click', () => {
    options.onRestart?.();
  });
  pauseModal.homeButton.addEventListener('click', () => {
    options.onHome?.();
  });
  pauseModal.exitButton.addEventListener('click', () => {
    (options.onExit ?? options.onHome)?.();
  });
  settingsButton.addEventListener('click', () => {
    settingsButton.classList.add('game-control-pulse');
    window.setTimeout(() => settingsButton.classList.remove('game-control-pulse'), 360);
  });

  root.addEventListener('jigsaw:destroy', cleanup);
  window.addEventListener('resize', clampAllPieces);

  function createHudButton(icon: typeof Timer, label: string, tooltip: string): HTMLButtonElement {
    const button = document.createElement('button');
    button.className = 'game-control';
    button.type = 'button';
    button.title = tooltip;
    button.setAttribute('aria-label', tooltip);
    button.append(createLucideIcon(icon, 'game-hud-icon'), document.createTextNode(label));
    return button;
  }

  function createPauseModal(): {
    overlay: HTMLDivElement;
    continueButton: HTMLButtonElement;
    closeButton: HTMLButtonElement;
    restartButton: HTMLButtonElement;
    homeButton: HTMLButtonElement;
    exitButton: HTMLButtonElement;
  } {
    const overlay = document.createElement('div');
    overlay.className = 'pause-modal-overlay';
    overlay.hidden = true;

    const panel = document.createElement('section');
    panel.className = 'pause-modal';
    panel.style.setProperty('--pause-panel-bg', `url("${pausePanelBgUrl}")`);
    panel.setAttribute('aria-label', '游戏暂停');

    const closeButton = document.createElement('button');
    closeButton.className = 'pause-close-button';
    closeButton.type = 'button';
    closeButton.setAttribute('aria-label', '关闭暂停弹窗');
    closeButton.appendChild(createLucideIcon(X, 'pause-close-icon'));

    const title = document.createElement('h2');
    title.className = 'pause-title';
    title.textContent = '游戏暂停';

    const cat = document.createElement('img');
    cat.className = 'pause-cat';
    cat.alt = '';
    cat.draggable = false;
    cat.src = decorCatOrangeUrl;

    const actions = document.createElement('div');
    actions.className = 'pause-actions';

    const continueButton = createPauseButton(Play, '继续游戏', 'primary');
    const restartButton = createPauseButton(RotateCcw, '重新开始');
    const homeButton = createPauseButton(Home, '回到主页');
    const exitButton = createPauseButton(LogOut, '退出游戏', 'danger');
    actions.append(continueButton, restartButton, homeButton, exitButton);
    panel.append(closeButton, title, cat, actions);
    overlay.appendChild(panel);

    return { overlay, continueButton, closeButton, restartButton, homeButton, exitButton };
  }

  function createPauseButton(icon: typeof Timer, label: string, tone?: 'primary' | 'danger'): HTMLButtonElement {
    const button = document.createElement('button');
    button.className = tone ? `pause-action pause-action-${tone}` : 'pause-action';
    button.type = 'button';
    button.append(createLucideIcon(icon, 'pause-action-icon'), document.createTextNode(label));
    return button;
  }

  async function init(): Promise<void> {
    try {
      preloadSfx();
      const loaded = await loadLevel(`/${options.levelPath}`);
      snapOptions = loaded.level.snap;
      stage = await createStage(stageHost, tableclothToBackground(loaded.level.tablecloth, options.levelPath));
      resetGroupIds();
      createPieces(loaded.pieces, loaded.texture);
      loading.remove();
    } catch (error) {
      loading.textContent = error instanceof Error ? error.message : '加载失败';
    }
  }

  function createPieces(pieces: PieceData[], texture: Texture): void {
    if (!stage) return;
    const playRect = getPlayRect(stage);
    const rotations = [0, 90, 180, 270];

    groups = pieces.map((piece, index) => {
      const x = randomBetween(playRect.left + 80, playRect.right - 80);
      const y = randomBetween(playRect.top + 70, playRect.bottom - 70);
      const group = new PieceGroup(piece, screenToWorld(stage!, { x, y }), rotations[index % rotations.length]);
      const view = new GroupView(group, texture);
      views.set(group, view);
      stage!.world.addChild(view.container);
      wirePieceInput(group, view);
      clampView(view);
      return group;
    });

    stage.app.stage.on('globalpointermove', onPointerMove);
    stage.app.stage.on('pointerup', onPointerUp);
    stage.app.stage.on('pointerupoutside', onPointerUp);
  }

  function wirePieceInput(group: PieceGroup, view: GroupView): void {
    if (!stage) return;
    view.container.on('pointerdown', (event: FederatedPointerEvent) => {
      if (!stage || paused || event.button !== 0) return;
      const pointer = screenToWorld(stage, event.global);
      drag = {
        group,
        view,
        pointerId: event.pointerId,
        offset: sub(pointer, group.worldPosition),
      };
      view.setDragging(true);
      stage.world.addChild(view.container);
      event.stopPropagation();
    });

    view.container.on('rightclick', (event: FederatedPointerEvent) => {
      if (paused) return;
      event.preventDefault();
      rotateGroupTo(group, view, normalizeAngle(group.worldRotation + 90));
    });

    view.container.on('pointertap', (event: FederatedPointerEvent) => {
      if (paused || event.detail < 2) return;
      rotateGroupTo(group, view, normalizeAngle(group.worldRotation + 90));
    });
  }

  function onPointerMove(event: FederatedPointerEvent): void {
    if (!stage || !drag || drag.pointerId !== event.pointerId) return;
    const pointer = screenToWorld(stage, event.global);
    drag.group.worldPosition = sub(pointer, drag.offset);
    drag.view.syncTransform();
    clampView(drag.view);
  }

  function onPointerUp(event: FederatedPointerEvent): void {
    if (!stage || !drag || drag.pointerId !== event.pointerId) return;
    const active = drag;
    drag = null;
    active.view.setDragging(false);
    clampView(active.view);
    attemptSnap(active.group, active.view);
  }

  function rotateGroupTo(group: PieceGroup, view: GroupView, rotation: number): void {
    const startPosition = [...group.worldPosition] as Vec2;
    const startRotation = group.worldRotation;
    group.worldRotation = rotation;
    view.animateRotateAround(group.worldPosition, startPosition, startRotation);
    window.setTimeout(() => clampView(view), 140);
  }

  function attemptSnap(group: PieceGroup, view: GroupView): void {
    const result = trySnap(
      group,
      groups.filter((item) => item !== group),
      snapOptions.positionTolerance,
      snapOptions.angleTolerance,
    );

    if (result.consumed.length === 0) return;

    for (const consumed of result.consumed) {
      const consumedView = views.get(consumed);
      if (consumedView) {
        consumedView.destroy();
        views.delete(consumed);
      }
      groups = groups.filter((item) => item !== consumed);
    }

    view.syncMembers();
    view.syncTransform();
    clampView(view);
    playSfx(groups.length === 1 ? 'complete' : 'snap');
  }

  function alignAllPieces(): void {
    for (const group of groups) {
      const view = views.get(group);
      if (!view || group.worldRotation === 0) continue;
      group.worldRotation = 0;
      view.syncTransform();
      clampView(view);
    }
  }

  function showHint(): void {
    const pair = findHintPair(groups);
    if (!pair) return;

    hintState?.stop();
    const aView = views.get(pair.a);
    const bView = views.get(pair.b);
    if (!aView || !bView) return;

    const aIds = new Set([pair.aPieceId]);
    const bIds = new Set([pair.bPieceId]);
    const start = performance.now();
    const tick = (): void => {
      const elapsed = performance.now() - start;
      const alpha = 0.36 + 0.64 * ((Math.sin(elapsed / 260) + 1) / 2);
      aView.setHint(aIds, alpha);
      bView.setHint(bIds, alpha);
    };
    Ticker.shared.add(tick);
    tick();

    const timeout = window.setTimeout(() => {
      Ticker.shared.remove(tick);
      aView.clearHint();
      bView.clearHint();
      hintState = null;
    }, 3000);

    hintState = {
      stop: () => {
        window.clearTimeout(timeout);
        Ticker.shared.remove(tick);
        aView.clearHint();
        bView.clearHint();
      },
    };
  }

  function clampAllPieces(): void {
    for (const view of views.values()) clampView(view);
  }

  function clampView(view: GroupView): void {
    if (!stage) return;
    view.syncTransform();
    const rect = getPlayRect(stage);
    const bounds = view.container.getBounds();
    let dx = 0;
    let dy = 0;

    if (bounds.minX < rect.left) dx = rect.left - bounds.minX;
    if (bounds.maxX > rect.right) dx = rect.right - bounds.maxX;
    if (bounds.minY < rect.top) dy = rect.top - bounds.minY;
    if (bounds.maxY > rect.bottom) dy = rect.bottom - bounds.maxY;

    if (dx !== 0 || dy !== 0) {
      view.group.worldPosition = [view.group.worldPosition[0] + dx, view.group.worldPosition[1] + dy];
      view.syncTransform();
    }
  }

  function setPaused(nextPaused: boolean): void {
    if (paused === nextPaused) return;
    paused = nextPaused;
    pauseButton.classList.toggle('game-control-active', paused);
    pauseButton.lastChild!.textContent = paused ? '继续' : '暂停';
    pauseModal.overlay.hidden = !paused;

    if (paused) {
      elapsedBeforePause += performance.now() - timerStart;
      if (drag) {
        drag.view.setDragging(false);
        drag = null;
      }
    } else {
      timerStart = performance.now();
    }
  }

  function updateTimer(): void {
    const elapsed = elapsedBeforePause + (paused ? 0 : performance.now() - timerStart);
    timerValue.textContent = formatElapsed(elapsed);
  }

  function cleanup(): void {
    window.clearInterval(timerHandle);
    window.removeEventListener('resize', clampAllPieces);
    hintState?.stop();
    stage?.destroy();
  }

  return root;
}
