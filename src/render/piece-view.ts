import { Container, Graphics, Mesh, MeshGeometry, Texture, Ticker } from 'pixi.js';
import { DropShadowFilter } from 'pixi-filters';
import earcut from 'earcut';
import type { EdgeType, Vec2 } from '../core/types';
import type { GroupMember, PieceGroup } from '../core/group';
import { add, degToRad, rotateDeg, sub } from '../core/geometry';

const OUTLINE_COLOR = 0x1a1a1a;
const OUTLINE_ALPHA = 0.28;
const OUTLINE_WIDTH = 1;

const SHADOW_OFFSET_Y = 10;
const SHADOW_BLUR = 10;
const SHADOW_ALPHA = 0.5;

const ROTATE_DURATION_MS = 120;

/** Triangulate a (possibly non-convex) simple polygon using earcut. */
function triangulatePolygon(localVerts: Float32Array): Uint32Array {
  // earcut accepts a flat array of x,y pairs.
  const idx = earcut(Array.from(localVerts), undefined, 2);
  return new Uint32Array(idx);
}

/** Build a Mesh whose local origin is `home`. */
function buildMeshFromPolygon(
  polygon: Vec2[],
  uv: Vec2[],
  home: Vec2,
  texture: Texture,
  label: string,
): Mesh {
  const [hx, hy] = home;
  const n = polygon.length;
  const positions = new Float32Array(n * 2);
  const uvs = new Float32Array(n * 2);
  for (let i = 0; i < n; i++) {
    positions[i * 2] = polygon[i][0] - hx;
    positions[i * 2 + 1] = polygon[i][1] - hy;
    uvs[i * 2] = uv[i][0];
    uvs[i * 2 + 1] = uv[i][1];
  }
  const geometry = new MeshGeometry({
    positions,
    uvs,
    indices: triangulatePolygon(positions),
  });
  const mesh = new Mesh({ geometry, texture });
  mesh.label = label;
  return mesh;
}

/**
 * Build a Graphics that outlines only the edges tagged 'cut'. If `edgeTypes`
 * is missing, the entire polygon is outlined.
 */
function buildOutlineFromPolygon(
  polygon: Vec2[],
  edgeTypes: EdgeType[] | undefined,
  home: Vec2,
  label: string,
): Graphics {
  const [hx, hy] = home;
  const n = polygon.length;
  const local: Vec2[] = polygon.map(([x, y]) => [x - hx, y - hy]);
  const g = new Graphics();
  g.label = label;
  g.eventMode = 'none';

  const types = edgeTypes;
  if (!types || types.length === 0) {
    const path: number[] = [];
    for (const [x, y] of local) path.push(x, y);
    g.poly(path, true).stroke({ width: OUTLINE_WIDTH, color: OUTLINE_COLOR, alpha: OUTLINE_ALPHA });
    return g;
  }

  // Group consecutive cut edges into open polylines.
  // First, find any boundary between cut and non-cut so we can start traversal cleanly.
  let start = 0;
  for (let i = 0; i < n; i++) {
    const prev = types[(i - 1 + n) % n];
    if (types[i] === 'cut' && prev !== 'cut') {
      start = i;
      break;
    }
  }
  // If every edge is cut, just draw the closed polygon.
  if (types.every((t) => t === 'cut')) {
    const path: number[] = [];
    for (const [x, y] of local) path.push(x, y);
    g.poly(path, true).stroke({ width: OUTLINE_WIDTH, color: OUTLINE_COLOR, alpha: OUTLINE_ALPHA });
    return g;
  }
  // If no edge is cut, nothing to draw.
  if (types.every((t) => t !== 'cut')) return g;

  // Walk around the polygon collecting cut runs as polylines.
  let visited = 0;
  let i = start;
  while (visited < n) {
    if (types[i] === 'cut') {
      // Start a polyline at vertex i, follow consecutive cut edges.
      const pts: number[] = [];
      pts.push(local[i][0], local[i][1]);
      let j = i;
      while (visited < n && types[j] === 'cut') {
        const next = (j + 1) % n;
        pts.push(local[next][0], local[next][1]);
        visited++;
        j = next;
      }
      g.poly(pts, false).stroke({ width: OUTLINE_WIDTH, color: OUTLINE_COLOR, alpha: OUTLINE_ALPHA });
      i = j;
    } else {
      visited++;
      i = (i + 1) % n;
    }
  }

  return g;
}

interface MemberView {
  mesh: Mesh;
  outline: Graphics;
}

/**
 * GroupView mirrors a PieceGroup: a Pixi Container whose position/rotation are
 * driven by group state, containing one Mesh + outline per member.
 */
export class GroupView {
  readonly container: Container;
  readonly group: PieceGroup;
  private memberViews: Map<string, MemberView> = new Map();
  private texture: Texture;
  private shadowFilter: DropShadowFilter | null = null;
  private rotateTickerCb: ((ticker: Ticker) => void) | null = null;

  constructor(group: PieceGroup, texture: Texture) {
    this.group = group;
    this.texture = texture;
    this.container = new Container();
    this.container.label = `group:${group.id}`;
    this.container.eventMode = 'static';
    this.container.cursor = 'grab';

    for (const m of group.members) this.attachMember(m);
    this.syncTransform();
  }

  attachMember(m: GroupMember): void {
    if (this.memberViews.has(m.piece.id)) return;
    const mesh = buildMeshFromPolygon(
      m.piece.polygon,
      m.piece.uv,
      m.piece.homePosition,
      this.texture,
      `mesh:${m.piece.id}`,
    );
    const outline = buildOutlineFromPolygon(
      m.piece.polygon,
      m.piece.edgeTypes,
      m.piece.homePosition,
      `outline:${m.piece.id}`,
    );
    mesh.position.set(m.localOffset[0], m.localOffset[1]);
    outline.position.set(m.localOffset[0], m.localOffset[1]);
    this.container.addChild(mesh);
    this.container.addChild(outline);
    this.memberViews.set(m.piece.id, { mesh, outline });
  }

  syncMembers(): void {
    for (const m of this.group.members) {
      const view = this.memberViews.get(m.piece.id);
      if (!view) {
        this.attachMember(m);
      } else {
        view.mesh.position.set(m.localOffset[0], m.localOffset[1]);
        view.outline.position.set(m.localOffset[0], m.localOffset[1]);
      }
    }
  }

  syncTransform(): void {
    const [x, y] = this.group.worldPosition;
    this.container.position.set(x, y);
    this.container.rotation = degToRad(this.group.worldRotation);
  }

  setDragging(isDragging: boolean): void {
    if (isDragging) {
      this.cancelRotateAnim();
      this.syncTransform();
    }
    this.container.cursor = isDragging ? 'grabbing' : 'grab';
    if (isDragging) {
      if (!this.shadowFilter) {
        this.shadowFilter = new DropShadowFilter({
          offset: { x: 0, y: SHADOW_OFFSET_Y },
          blur: SHADOW_BLUR,
          alpha: SHADOW_ALPHA,
          color: 0x000000,
          quality: 4,
        });
      }
      this.container.filters = [this.shadowFilter];
    } else {
      this.container.filters = [];
    }
  }

  /**
   * Animate a rotation around `pivot` from the given start position/rotation
   * to the group's current `worldPosition`/`worldRotation`. State must already
   * have been updated by the caller; this only animates the visual.
   */
  animateRotateAround(pivot: Vec2, startPosition: Vec2, startRotation: number): void {
    this.cancelRotateAnim();
    const endRot = this.group.worldRotation;
    // Shortest signed delta in (-180, 180] so wraps (e.g. 270→0) animate as +90.
    let delta = ((endRot - startRotation + 540) % 360) - 180;
    if (delta === -180) delta = 180;

    const startTime = performance.now();
    const cb = (): void => {
      const t = Math.min(1, (performance.now() - startTime) / ROTATE_DURATION_MS);
      const eased = 1 - Math.pow(1 - t, 3);
      const currentDelta = delta * eased;
      const offset = sub(startPosition, pivot);
      const rotated = rotateDeg(offset, currentDelta);
      const pos = add(pivot, rotated);
      this.container.position.set(pos[0], pos[1]);
      this.container.rotation = degToRad(startRotation + currentDelta);
      if (t >= 1) {
        this.cancelRotateAnim();
        this.syncTransform();
      }
    };
    this.rotateTickerCb = cb;
    Ticker.shared.add(cb);
  }

  private cancelRotateAnim(): void {
    if (this.rotateTickerCb) {
      Ticker.shared.remove(this.rotateTickerCb);
      this.rotateTickerCb = null;
    }
  }

  pieceCenter(_pieceId: string): Vec2 {
    return [this.container.position.x, this.container.position.y];
  }

  destroy(): void {
    this.cancelRotateAnim();
    this.container.destroy({ children: true, texture: false });
    this.memberViews.clear();
  }
}
