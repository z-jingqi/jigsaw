import { Application, Container, Rectangle } from 'pixi.js';

export interface StageBackground {
  color: number;
  imageUrl?: string;
}

export interface StageHandles {
  app: Application;
  world: Container;
  resize: () => void;
  destroy: () => void;
  /** Logical canvas size (the coordinate system the game runs in). */
  canvasWidth: number;
  canvasHeight: number;
}

export async function createStage(host: HTMLElement, background: StageBackground): Promise<StageHandles> {
  const previousBackground = host.style.background;
  const previousBackgroundSize = host.style.backgroundSize;
  const previousBackgroundPosition = host.style.backgroundPosition;
  const previousBackgroundColor = host.style.backgroundColor;

  const solid = `#${background.color.toString(16).padStart(6, '0')}`;
  host.style.backgroundColor = solid;
  if (background.imageUrl) {
    host.style.background = `url("${background.imageUrl}") center / cover no-repeat`;
    host.style.backgroundSize = 'cover';
    host.style.backgroundPosition = 'center';
  } else {
    host.style.background = solid;
  }

  const app = new Application();
  await app.init({
    background: background.color,
    backgroundAlpha: background.imageUrl ? 0 : 1,
    resizeTo: window,
    antialias: true,
    autoDensity: true,
    resolution: Math.min(window.devicePixelRatio || 1, 2),
  });

  host.appendChild(app.canvas);
  app.canvas.style.left = '0';
  app.canvas.style.top = '0';
  app.canvas.style.width = '100vw';
  app.canvas.style.height = '100vh';
  app.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

  const world = new Container();
  world.label = 'world';
  app.stage.addChild(world);
  app.stage.eventMode = 'static';
  app.stage.hitArea = new Rectangle(0, 0, app.screen.width, app.screen.height);

  const resize = (): void => {
    world.position.set(app.screen.width / 2, app.screen.height / 2);
    app.stage.hitArea = new Rectangle(0, 0, app.screen.width, app.screen.height);
  };
  resize();
  window.addEventListener('resize', resize);

  return {
    app,
    world,
    resize,
    destroy: () => {
      window.removeEventListener('resize', resize);
      host.style.background = previousBackground;
      host.style.backgroundSize = previousBackgroundSize;
      host.style.backgroundPosition = previousBackgroundPosition;
      host.style.backgroundColor = previousBackgroundColor;
      app.destroy(true, { children: true, texture: false });
    },
    canvasWidth: app.screen.width,
    canvasHeight: app.screen.height,
  };
}
