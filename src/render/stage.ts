import { Application, Container, Rectangle } from 'pixi.js';
import { getSettings, resolutionDimensions } from '../core/settings';

export interface StageHandles {
  app: Application;
  world: Container;
  resize: () => void;
  destroy: () => void;
  /** Logical canvas size (the coordinate system the game runs in). */
  canvasWidth: number;
  canvasHeight: number;
}

export async function createStage(host: HTMLElement, background: number): Promise<StageHandles> {
  const settings = getSettings();
  const fixed = resolutionDimensions(settings.resolution);

  const app = new Application();
  if (fixed) {
    await app.init({
      background,
      width: fixed.width,
      height: fixed.height,
      antialias: true,
      autoDensity: true,
      resolution: Math.min(window.devicePixelRatio || 1, 2),
    });
  } else {
    await app.init({
      background,
      resizeTo: window,
      antialias: true,
      autoDensity: true,
      resolution: Math.min(window.devicePixelRatio || 1, 2),
    });
  }

  host.appendChild(app.canvas);
  app.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

  const world = new Container();
  world.label = 'world';
  app.stage.addChild(world);
  app.stage.eventMode = 'static';
  app.stage.hitArea = new Rectangle(0, 0, app.screen.width, app.screen.height);

  const fitCanvas = (): void => {
    if (!fixed) return;
    const winW = window.innerWidth;
    const winH = window.innerHeight;
    const scale = Math.min(winW / fixed.width, winH / fixed.height);
    const w = fixed.width * scale;
    const h = fixed.height * scale;
    app.canvas.style.width = `${w}px`;
    app.canvas.style.height = `${h}px`;
    app.canvas.style.left = `${(winW - w) / 2}px`;
    app.canvas.style.top = `${(winH - h) / 2}px`;
  };

  const resize = (): void => {
    world.position.set(app.screen.width / 2, app.screen.height / 2);
    if (!fixed) {
      app.stage.hitArea = new Rectangle(0, 0, app.screen.width, app.screen.height);
    }
    fitCanvas();
  };
  resize();
  window.addEventListener('resize', resize);

  return {
    app,
    world,
    resize,
    destroy: () => {
      window.removeEventListener('resize', resize);
      app.destroy(true, { children: true, texture: false });
    },
    canvasWidth: app.screen.width,
    canvasHeight: app.screen.height,
  };
}
