import Phaser from "phaser";
import { GameMode, PolygonPieceConfig, Point, Rect } from "../../data/types";
import { PieceDefinition, PuzzleSceneOptions, RuntimePiece, TraySlot } from "../types";
import { boundsOf, centerOf, distance, fallbackNeighbors, normalizeNeighbors, toPoints } from "../systems/geometry";
import { createPieceTexture, createRectTexture } from "../systems/pieceTexture";
import { generateKnobDefinitions } from "../systems/knobGenerator";
import { shuffledIndexes, SwapTile, tileRect } from "../systems/swapGenerator";

const SNAP_TOLERANCE = 72;
const BOARD_GAP = 8;
const TRAY_VERTICAL_PADDING = 50;
const TRAY_GAP = 64;

type DragState =
  | {
      kind: "piece";
      piece: RuntimePiece;
      pointerId: number;
      trayScale: number;
    }
  | {
      kind: "swap";
      tile: SwapTile;
      pointerId: number;
      offsetX: number;
      offsetY: number;
    };

export class PuzzleScene extends Phaser.Scene {
  private readonly options: PuzzleSceneOptions;
  private sourceImage!: HTMLImageElement;
  private world!: Phaser.GameObjects.Container;
  private trayRoot!: Phaser.GameObjects.Container;
  private dragLayer!: Phaser.GameObjects.Container;
  private trayBackground!: Phaser.GameObjects.Rectangle;
  private outline!: Phaser.GameObjects.Graphics;
  private hintGraphics?: Phaser.GameObjects.Graphics;
  private boardScale = 1;
  private trayHeight = 150;
  private trayScroll = 0;
  private maxTrayScroll = 0;
  private pieces = new Map<string, RuntimePiece>();
  private trayOrder: string[] = [];
  private traySlots = new Map<string, TraySlot>();
  private dragState?: DragState;
  private completed = false;
  private swapTiles: SwapTile[] = [];
  private panning?: { pointerId: number; x: number; y: number };

  constructor(options: PuzzleSceneOptions) {
    super("PuzzleScene");
    this.options = options;
  }

  preload() {
    this.load.image("source", this.options.level.imageUrl);
  }

  create() {
    this.sourceImage = this.textures.get("source").getSourceImage() as HTMLImageElement;
    this.cameras.main.setBackgroundColor(this.options.level.backgroundColor);

    this.world = this.add.container(0, 0);
    this.outline = this.add.graphics();
    this.world.add(this.outline);
    this.trayRoot = this.add.container(0, 0).setDepth(50);
    this.trayBackground = this.add.rectangle(0, 0, 10, 10, 0x222222, 0.28).setOrigin(0);
    this.trayRoot.add(this.trayBackground);
    this.dragLayer = this.add.container(0, 0).setDepth(100);

    if (this.options.mode === "swap") {
      this.createSwapMode();
    } else {
      this.createTrayMode(this.options.mode);
    }

    this.layoutAll();
    this.scale.on("resize", this.layoutAll, this);

    this.input.on("pointermove", this.onPointerMove, this);
    this.input.on("pointerup", this.onPointerUp, this);
    this.input.on("wheel", (_pointer: Phaser.Input.Pointer, _objects: unknown, dx: number) => {
      this.trayScroll = Phaser.Math.Clamp(this.trayScroll + dx, 0, this.maxTrayScroll);
      this.layoutTray();
    });
    this.input.on("pointerdown", this.onBackgroundPointerDown, this);
  }

  destroy() {
    this.scale.off("resize", this.layoutAll, this);
  }

  showHint() {
    if (this.options.mode === "swap" || this.completed) return;
    this.clearHint();

    const target = this.findHintPiece();
    if (!target) return;

    this.hintGraphics = this.add.graphics();
    this.world.add(this.hintGraphics);
    this.drawDashedPolygon(this.hintGraphics, target.definition.points, 8 / this.boardScale, 0x4e9cff, 15, 9);
    this.tweens.add({
      targets: this.hintGraphics,
      alpha: { from: 1, to: 0.45 },
      yoyo: true,
      repeat: -1,
      duration: 480,
    });

    target.sprite.setTint(0x80c7ff);
    this.tweens.add({
      targets: target.sprite,
      alpha: { from: 1, to: 0.55 },
      yoyo: true,
      repeat: -1,
      duration: 420,
    });

    this.time.delayedCall(3000, () => {
      target.sprite.clearTint();
      target.sprite.setAlpha(1);
      this.clearHint();
    });
  }

  private createTrayMode(mode: Exclude<GameMode, "swap">) {
    const definitions = mode === "polygon" ? this.polygonDefinitions() : this.knobDefinitions();
    const seedIds = this.seedIds(mode, definitions);

    definitions.forEach((definition, index) => {
      const texture = createPieceTexture(this, `piece:${definition.id}`, this.sourceImage, definition.points);
      definition.textureBounds = texture.textureBounds;
      const sprite = this.add.image(texture.textureBounds.x, texture.textureBounds.y, texture.key).setOrigin(0);
      sprite.setInteractive({ useHandCursor: true });
      const runtime: RuntimePiece = {
        definition,
        sprite,
        state: seedIds.has(definition.id) ? "locked" : "tray",
        trayIndex: index,
      };
      this.pieces.set(definition.id, runtime);

      sprite.on("pointerdown", (pointer: Phaser.Input.Pointer, _x: number, _y: number, event: Phaser.Types.Input.EventData) => {
        event.stopPropagation();
        if (runtime.state === "locked") {
          this.startPan(pointer);
          return;
        }
        this.startPieceDrag(runtime, pointer);
      });

      if (runtime.state === "locked") {
        this.world.add(sprite);
      } else {
        this.trayOrder.push(definition.id);
        this.trayRoot.add(sprite);
      }
    });
  }

  private polygonDefinitions(): PieceDefinition[] {
    const pieces = this.options.level.config.modes.polygon?.pieces ?? [];
    const definitions = pieces.map((piece: PolygonPieceConfig) => {
      const points = toPoints(piece.points);
      const bounds = boundsOf(points);
      return {
        id: piece.id,
        points,
        bounds,
        textureBounds: bounds,
        neighbors: [...(piece.neighbors ?? [])],
      };
    });
    if (definitions.every((piece) => piece.neighbors.length === 0)) fallbackNeighbors(definitions);
    else normalizeNeighbors(definitions);
    return definitions;
  }

  private knobDefinitions(): PieceDefinition[] {
    const knob = this.options.level.config.modes.knob;
    const cols = knob?.cols ?? 6;
    const rows = knob?.rows ?? 8;
    return generateKnobDefinitions(this.sourceImage.width, this.sourceImage.height, cols, rows, knob?.knob_size ?? 0.24);
  }

  private seedIds(mode: Exclude<GameMode, "swap">, definitions: PieceDefinition[]): Set<string> {
    const assist = mode === "polygon" ? this.options.level.config.modes.polygon?.assist : this.options.level.config.modes.knob?.assist;
    const seed = assist?.seed;
    if (seed?.mode === "manual") {
      const valid = seed.piece_ids.filter((id) => definitions.some((piece) => piece.id === id));
      if (valid.length > 0) return new Set(valid);
    }

    const count = Math.max(1, seed?.count ?? 1);
    const center = { x: this.sourceImage.width / 2, y: this.sourceImage.height / 2 };
    const sorted = [...definitions].sort((a, b) => distance(centerOf(b.bounds), center) - distance(centerOf(a.bounds), center));
    return new Set(sorted.slice(0, count).map((piece) => piece.id));
  }

  private createSwapMode() {
    const swap = this.options.level.config.modes.swap;
    const cols = swap?.cols ?? 5;
    const rows = swap?.rows ?? 7;
    const count = cols * rows;
    const order = shuffledIndexes(count);

    for (let correctIndex = 0; correctIndex < count; correctIndex += 1) {
      const rect = tileRect(correctIndex, cols, rows, this.sourceImage.width, this.sourceImage.height);
      const texture = createRectTexture(this, `swap:${correctIndex}`, this.sourceImage, rect);
      const currentIndex = order[correctIndex];
      const sprite = this.add.image(0, 0, texture.key).setOrigin(0).setInteractive({ useHandCursor: true });
      const tile: SwapTile = { id: `swap_${correctIndex}`, correctIndex, currentIndex, sprite };
      this.swapTiles.push(tile);
      this.world.add(sprite);
      sprite.on("pointerdown", (pointer: Phaser.Input.Pointer, localX: number, localY: number, event: Phaser.Types.Input.EventData) => {
        event.stopPropagation();
        const local = this.screenToWorld(pointer.x, pointer.y);
        this.dragState = {
          kind: "swap",
          tile,
          pointerId: pointer.id,
          offsetX: local.x - sprite.x,
          offsetY: local.y - sprite.y,
        };
        sprite.setDepth(10);
      });
    }
  }

  private layoutAll = () => {
    const width = this.scale.width;
    const height = this.scale.height;
    this.trayHeight = this.options.mode === "swap" ? 0 : Math.max(138, height / 6);
    this.trayBackground.setPosition(0, height - this.trayHeight);
    this.trayBackground.setSize(width, this.trayHeight);

    const availableHeight = height - this.trayHeight - BOARD_GAP * 2;
    this.boardScale = Math.min((width - BOARD_GAP * 2) / this.sourceImage.width, (availableHeight - BOARD_GAP * 2) / this.sourceImage.height);
    this.world.setScale(this.boardScale);
    this.world.setPosition((width - this.sourceImage.width * this.boardScale) / 2, BOARD_GAP);
    this.drawBoardOutline();

    if (this.options.mode === "swap") this.layoutSwapTiles();
    else this.layoutTray();
  };

  private drawBoardOutline() {
    this.outline.clear();
    this.outline.fillStyle(0x000000, 0.045);
    this.outline.fillRoundedRect(0, 0, this.sourceImage.width, this.sourceImage.height, 14 / this.boardScale);
    this.outline.lineStyle(2 / this.boardScale, 0x5a3a22, 0.12);
    this.outline.strokeRoundedRect(0, 0, this.sourceImage.width, this.sourceImage.height, 14 / this.boardScale);
  }

  private layoutTray() {
    const height = this.scale.height;
    const maxHeight = Math.max(1, this.trayHeight - TRAY_VERTICAL_PADDING * 2);
    let cursor = 18;
    this.traySlots.clear();

    for (const id of this.trayOrder) {
      const piece = this.pieces.get(id);
      if (!piece || piece.state === "locked") continue;
      const textureHeight = piece.definition.textureBounds.height;
      const textureWidth = piece.definition.textureBounds.width;
      const originalDisplayHeight = textureHeight * this.boardScale;
      const scale = originalDisplayHeight > maxHeight ? maxHeight / textureHeight : this.boardScale;
      const width = textureWidth * scale;
      const displayHeight = textureHeight * scale;
      const slot: TraySlot = {
        pieceId: id,
        x: cursor,
        y: height - this.trayHeight + (this.trayHeight - displayHeight) / 2,
        scale,
        width,
        height: displayHeight,
      };
      this.traySlots.set(id, slot);
      cursor += width + TRAY_GAP;
    }

    this.maxTrayScroll = Math.max(0, cursor - this.scale.width + 18);
    this.trayScroll = Phaser.Math.Clamp(this.trayScroll, 0, this.maxTrayScroll);

    for (const id of this.trayOrder) {
      const piece = this.pieces.get(id);
      const slot = this.traySlots.get(id);
      if (!piece || !slot || piece.state === "dragging") continue;
      piece.sprite.setScale(slot.scale);
      piece.sprite.setPosition(slot.x - this.trayScroll, slot.y);
      piece.sprite.setDepth(2);
    }
  }

  private layoutSwapTiles() {
    const swap = this.options.level.config.modes.swap;
    const cols = swap?.cols ?? 5;
    const rows = swap?.rows ?? 7;
    for (const tile of this.swapTiles) {
      const rect = tileRect(tile.currentIndex, cols, rows, this.sourceImage.width, this.sourceImage.height);
      tile.sprite.setPosition(rect.x, rect.y);
      tile.sprite.setDepth(1);
    }
  }

  private startPieceDrag(piece: RuntimePiece, pointer: Phaser.Input.Pointer) {
    this.clearHint();
    const slot = this.traySlots.get(piece.definition.id);
    piece.state = "dragging";
    piece.sprite.setDepth(500);
    this.dragLayer.add(piece.sprite);
    this.dragState = {
      kind: "piece",
      piece,
      pointerId: pointer.id,
      trayScale: slot?.scale ?? this.boardScale,
    };
    this.positionDraggedPiece(pointer);
  }

  private onPointerMove(pointer: Phaser.Input.Pointer) {
    if (this.dragState?.pointerId === pointer.id) {
      if (this.dragState.kind === "piece") this.positionDraggedPiece(pointer);
      else this.positionDraggedSwap(pointer);
      return;
    }

    if (this.panning?.pointerId === pointer.id) {
      const dx = pointer.x - this.panning.x;
      const dy = pointer.y - this.panning.y;
      this.panning = { pointerId: pointer.id, x: pointer.x, y: pointer.y };
      this.world.x += dx;
      this.world.y += dy;
      this.clampWorld();
    }
  }

  private onPointerUp(pointer: Phaser.Input.Pointer) {
    if (this.dragState?.pointerId !== pointer.id) {
      if (this.panning?.pointerId === pointer.id) this.panning = undefined;
      return;
    }

    if (this.dragState.kind === "piece") this.releasePiece(pointer);
    else this.releaseSwap(pointer);
    this.dragState = undefined;
  }

  private positionDraggedPiece(pointer: Phaser.Input.Pointer) {
    if (this.dragState?.kind !== "piece") return;
    const { piece, trayScale } = this.dragState;
    const outsideTray = pointer.y < this.scale.height - this.trayHeight;
    const scale = outsideTray ? this.boardScale : trayScale;
    const width = piece.definition.textureBounds.width * scale;
    const height = piece.definition.textureBounds.height * scale;
    const safeOffset = outsideTray ? Math.max(28, height + 22) : height / 2;
    piece.sprite.setScale(scale);
    piece.sprite.setPosition(pointer.x - width / 2, pointer.y - safeOffset);
  }

  private releasePiece(pointer: Phaser.Input.Pointer) {
    if (this.dragState?.kind !== "piece") return;
    const piece = this.dragState.piece;
    if (pointer.y < this.scale.height - this.trayHeight && this.canSnap(piece)) {
      piece.state = "locked";
      this.world.add(piece.sprite);
      piece.sprite.setScale(1);
      piece.sprite.setPosition(piece.definition.textureBounds.x, piece.definition.textureBounds.y);
      piece.sprite.clearTint();
      this.trayOrder = this.trayOrder.filter((id) => id !== piece.definition.id);
      this.layoutTray();
      this.checkComplete();
      return;
    }

    piece.state = "tray";
    this.trayRoot.add(piece.sprite);
    this.layoutTray();
  }

  private canSnap(piece: RuntimePiece): boolean {
    const screenX = piece.sprite.x;
    const screenY = piece.sprite.y;
    const local = this.screenToWorld(screenX, screenY);
    const closeEnough = distance(local, { x: piece.definition.textureBounds.x, y: piece.definition.textureBounds.y }) < SNAP_TOLERANCE / this.boardScale;
    if (!closeEnough) return false;
    return piece.definition.neighbors.some((neighborId) => this.pieces.get(neighborId)?.state === "locked");
  }

  private findHintPiece(): RuntimePiece | undefined {
    return this.trayOrder
      .map((id) => this.pieces.get(id))
      .find((piece): piece is RuntimePiece => Boolean(piece && piece.definition.neighbors.some((neighbor) => this.pieces.get(neighbor)?.state === "locked")));
  }

  private checkComplete() {
    if (this.completed) return;
    const complete = [...this.pieces.values()].every((piece) => piece.state === "locked");
    if (complete) {
      this.completed = true;
      this.time.delayedCall(450, this.options.onComplete);
    }
  }

  private positionDraggedSwap(pointer: Phaser.Input.Pointer) {
    if (this.dragState?.kind !== "swap") return;
    const local = this.screenToWorld(pointer.x, pointer.y);
    this.dragState.tile.sprite.setPosition(local.x - this.dragState.offsetX, local.y - this.dragState.offsetY);
  }

  private releaseSwap(pointer: Phaser.Input.Pointer) {
    if (this.dragState?.kind !== "swap") return;
    const tile = this.dragState.tile;
    const swap = this.options.level.config.modes.swap;
    const cols = swap?.cols ?? 5;
    const rows = swap?.rows ?? 7;
    const local = this.screenToWorld(pointer.x, pointer.y);
    const col = Phaser.Math.Clamp(Math.floor((local.x / this.sourceImage.width) * cols), 0, cols - 1);
    const row = Phaser.Math.Clamp(Math.floor((local.y / this.sourceImage.height) * rows), 0, rows - 1);
    const targetIndex = row * cols + col;
    const other = this.swapTiles.find((candidate) => candidate.currentIndex === targetIndex);
    if (other && other !== tile) {
      const old = tile.currentIndex;
      tile.currentIndex = other.currentIndex;
      other.currentIndex = old;
    }
    this.layoutSwapTiles();
    tile.sprite.setDepth(1);
    this.checkSwapComplete();
  }

  private checkSwapComplete() {
    if (this.completed) return;
    if (this.swapTiles.every((tile) => tile.currentIndex === tile.correctIndex)) {
      this.completed = true;
      this.time.delayedCall(450, this.options.onComplete);
    }
  }

  private onBackgroundPointerDown(pointer: Phaser.Input.Pointer) {
    if (this.dragState || pointer.y > this.scale.height - this.trayHeight) return;
    this.startPan(pointer);
  }

  private startPan(pointer: Phaser.Input.Pointer) {
    if (this.options.mode === "swap") return;
    this.panning = { pointerId: pointer.id, x: pointer.x, y: pointer.y };
  }

  private clampWorld() {
    const width = this.scale.width;
    const availableHeight = this.scale.height - this.trayHeight;
    const boardW = this.sourceImage.width * this.boardScale;
    const boardH = this.sourceImage.height * this.boardScale;
    if (boardW <= width - BOARD_GAP * 2) this.world.x = (width - boardW) / 2;
    else this.world.x = Phaser.Math.Clamp(this.world.x, width - boardW - BOARD_GAP, BOARD_GAP);
    if (boardH <= availableHeight - BOARD_GAP * 2) this.world.y = (availableHeight - boardH) / 2;
    else this.world.y = Phaser.Math.Clamp(this.world.y, availableHeight - boardH - BOARD_GAP, BOARD_GAP);
  }

  private screenToWorld(x: number, y: number): Point {
    return {
      x: (x - this.world.x) / this.boardScale,
      y: (y - this.world.y) / this.boardScale,
    };
  }

  private clearHint() {
    if (this.hintGraphics) {
      this.tweens.killTweensOf(this.hintGraphics);
      this.hintGraphics.destroy();
      this.hintGraphics = undefined;
    }
    for (const piece of this.pieces.values()) {
      this.tweens.killTweensOf(piece.sprite);
      piece.sprite.clearTint();
      piece.sprite.setAlpha(1);
    }
  }

  private drawDashedPolygon(graphics: Phaser.GameObjects.Graphics, points: Point[], width: number, color: number, dash: number, gap: number) {
    graphics.clear();
    graphics.lineStyle(width, color, 1);
    for (let i = 0; i < points.length; i += 1) {
      const start = points[i];
      const end = points[(i + 1) % points.length];
      this.drawDashedLine(graphics, start, end, dash / this.boardScale, gap / this.boardScale);
    }
  }

  private drawDashedLine(graphics: Phaser.GameObjects.Graphics, start: Point, end: Point, dash: number, gap: number) {
    const lineLength = distance(start, end);
    const direction = { x: (end.x - start.x) / lineLength, y: (end.y - start.y) / lineLength };
    let current = 0;
    while (current < lineLength) {
      const from = current;
      const to = Math.min(lineLength, current + dash);
      graphics.beginPath();
      graphics.moveTo(start.x + direction.x * from, start.y + direction.y * from);
      graphics.lineTo(start.x + direction.x * to, start.y + direction.y * to);
      graphics.strokePath();
      current += dash + gap;
    }
  }
}
