import type { LevelData } from '../core/types';
import type { Application } from 'pixi.js';

export interface DevPanelDeps {
  getApp: () => Application | null;
  getLevel: () => LevelData | null;
  /** Re-slice the *current* level with overrides merged into its level.json. */
  reslice: (overrides: Partial<LevelData>) => Promise<void>;
  solveCurrent: () => void;
}

export function mountDevPanel(deps: DevPanelDeps): void {
  const root = document.createElement('div');
  root.id = 'dev-panel';
  root.className = 'dev-panel hidden';
  root.innerHTML = `
    <div class="dev-panel-header">
      <span>Dev (toggle ` + '`' + `)</span>
      <span class="dev-current" data-field="currentLabel"></span>
    </div>
    <label>Cols
      <input type="number" min="2" max="10" data-field="cols" />
    </label>
    <label>Rows
      <input type="number" min="2" max="10" data-field="rows" />
    </label>
    <label>Classic knobs only
      <input type="checkbox" data-field="knobs" />
    </label>
    <label>Long side
      <input type="number" min="240" max="1200" step="20" data-field="displayLongSide" />
    </label>
    <label>Snap dist (px)
      <input type="number" min="0" step="1" data-field="snap" />
    </label>
    <label>Snap angle (°)
      <input type="number" min="0" max="45" step="1" data-field="angle" />
    </label>
    <label>Scatter radius
      <input type="number" min="0" step="10" data-field="scatter" />
    </label>
    <label>Rotation enabled
      <input type="checkbox" data-field="rotEnabled" />
    </label>
    <label>Tablecloth
      <input type="color" data-field="bg" />
    </label>
    <button data-action="solve">Solve current puzzle</button>
    <button data-action="reslice">Re-slice current level</button>
  `;
  document.body.appendChild(root);

  const style = document.createElement('style');
  style.textContent = `
    .dev-panel {
      position: fixed;
      top: 12px;
      right: 12px;
      z-index: 50;
      background: rgba(20, 20, 20, 0.92);
      backdrop-filter: blur(6px);
      color: #f5f5f5;
      font: 12px -apple-system, BlinkMacSystemFont, sans-serif;
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 10px;
      padding: 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      width: 240px;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    }
    .dev-panel.hidden { display: none; }
    .dev-panel-header { display: flex; justify-content: space-between; align-items: center; font-weight: 600; opacity: 0.7; margin-bottom: 4px; }
    .dev-panel .dev-current { font-weight: 400; opacity: 0.6; font-size: 11px; }
    .dev-panel label { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    .dev-panel input, .dev-panel select {
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.12);
      color: inherit;
      border-radius: 6px;
      padding: 4px 6px;
      font-size: 12px;
      max-width: 110px;
    }
    .dev-panel input[type="checkbox"] { max-width: none; }
    .dev-panel input[type="color"] { padding: 2px; height: 26px; width: 60px; }
    .dev-panel button {
      padding: 6px 8px;
      background: #f5f5f5;
      color: #111;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      font-weight: 600;
      font-size: 12px;
    }
    .dev-panel button:hover { background: #fff; }
    .dev-panel button:disabled { opacity: 0.4; cursor: not-allowed; }
  `;
  document.head.appendChild(style);

  const $ = <T extends HTMLElement>(field: string): T =>
    root.querySelector<T>(`[data-field="${field}"]`)!;
  const colsIn = $<HTMLInputElement>('cols');
  const rowsIn = $<HTMLInputElement>('rows');
  const knobsIn = $<HTMLInputElement>('knobs');
  const displayLongSideIn = $<HTMLInputElement>('displayLongSide');
  const snapIn = $<HTMLInputElement>('snap');
  const angleIn = $<HTMLInputElement>('angle');
  const scatterIn = $<HTMLInputElement>('scatter');
  const rotIn = $<HTMLInputElement>('rotEnabled');
  const bgIn = $<HTMLInputElement>('bg');
  const currentLabel = $<HTMLSpanElement>('currentLabel');
  const solveBtn = root.querySelector<HTMLButtonElement>('[data-action="solve"]')!;
  const resliceBtn = root.querySelector<HTMLButtonElement>('[data-action="reslice"]')!;

  const sync = (): void => {
    const lv = deps.getLevel();
    if (!lv) {
      currentLabel.textContent = '(no level)';
      solveBtn.disabled = true;
      resliceBtn.disabled = true;
      return;
    }
    currentLabel.textContent = lv.id;
    solveBtn.disabled = false;
    resliceBtn.disabled = false;
    colsIn.value = String(lv.slice?.cols ?? 3);
    rowsIn.value = String(lv.slice?.rows ?? 3);
    knobsIn.checked = lv.slice?.shapeStyle === 'classic-knob' || lv.slice?.knobs === true;
    displayLongSideIn.value = String(lv.displayLongSide ?? 660);
    snapIn.value = String(lv.snap.positionTolerance);
    angleIn.value = String(lv.snap.angleTolerance);
    scatterIn.value = String(lv.difficulty.scatterRadius);
    rotIn.checked = lv.difficulty.rotationEnabled;
    bgIn.value = lv.tablecloth.type === 'color' ? lv.tablecloth.value : '#2b2b2b';
  };

  // Live tweaks (no reload).
  snapIn.addEventListener('input', () => {
    const lv = deps.getLevel();
    if (!lv) return;
    lv.snap.positionTolerance = Number(snapIn.value) || 0;
  });
  angleIn.addEventListener('input', () => {
    const lv = deps.getLevel();
    if (!lv) return;
    lv.snap.angleTolerance = Number(angleIn.value) || 0;
  });
  rotIn.addEventListener('change', () => {
    const lv = deps.getLevel();
    if (!lv) return;
    lv.difficulty.rotationEnabled = rotIn.checked;
  });
  bgIn.addEventListener('input', () => {
    const app = deps.getApp();
    const lv = deps.getLevel();
    if (!app || !lv) return;
    const hex = bgIn.value;
    const num = parseInt(hex.slice(1), 16);
    app.renderer.background.color = num;
    if (lv.tablecloth.type === 'color') lv.tablecloth.value = hex;
  });

  // Re-slice (full reload of CURRENT level with overrides).
  solveBtn.addEventListener('click', () => {
    deps.solveCurrent();
  });
  resliceBtn.addEventListener('click', async () => {
    const lv = deps.getLevel();
    if (!lv) return;
    const overrides: Partial<LevelData> = {
      displayLongSide: Number(displayLongSideIn.value) || 660,
      difficulty: {
        ...lv.difficulty,
        rotationEnabled: rotIn.checked,
        scatterRadius: Number(scatterIn.value) || 350,
      },
      snap: {
        positionTolerance: Number(snapIn.value) || 11,
        angleTolerance: Number(angleIn.value) || 8,
      },
      slice: {
        mode: 'grid',
        cols: Number(colsIn.value) || 3,
        rows: Number(rowsIn.value) || 3,
        knobs: knobsIn.checked,
        shapeStyle: knobsIn.checked ? 'classic-knob' : 'mixed',
      },
      tablecloth: { type: 'color', value: bgIn.value },
    };
    await deps.reslice(overrides);
    sync();
  });

  // Toggle visibility.
  window.addEventListener('keydown', (e) => {
    if (e.key === '`' || e.key === '~') {
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA') return;
      e.preventDefault();
      root.classList.toggle('hidden');
      sync();
    }
  });

  // Re-sync when overlays toggle (proxy for "level just loaded").
  const observer = new MutationObserver(sync);
  const watch = (id: string): void => {
    const el = document.getElementById(id);
    if (el) observer.observe(el, { attributes: true, attributeFilter: ['class'] });
  };
  watch('hud');
  watch('level-select');
  watch('complete-screen');
  sync();
}
