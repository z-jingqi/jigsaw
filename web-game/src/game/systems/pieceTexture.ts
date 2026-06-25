import Phaser from "phaser";
import { Point, Rect } from "../../data/types";
import { PieceTextureResult } from "../types";
import { boundsOf } from "./geometry";

const PADDING = 8;

export function createPieceTexture(
  scene: Phaser.Scene,
  key: string,
  source: HTMLImageElement,
  points: Point[],
): PieceTextureResult {
  const bounds = boundsOf(points);
  const textureBounds = {
    x: bounds.x - PADDING,
    y: bounds.y - PADDING,
    width: bounds.width + PADDING * 2,
    height: bounds.height + PADDING * 2,
  };

  const canvas = document.createElement("canvas");
  canvas.width = Math.ceil(textureBounds.width);
  canvas.height = Math.ceil(textureBounds.height);
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas 2D context is not available");

  ctx.save();
  ctx.beginPath();
  points.forEach((point, index) => {
    const x = point.x - textureBounds.x;
    const y = point.y - textureBounds.y;
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.closePath();
  ctx.clip();
  ctx.drawImage(source, -textureBounds.x, -textureBounds.y, source.width, source.height);
  ctx.restore();

  ctx.save();
  ctx.beginPath();
  points.forEach((point, index) => {
    const x = point.x - textureBounds.x;
    const y = point.y - textureBounds.y;
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.closePath();
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  ctx.strokeStyle = "rgba(78, 55, 34, 0.52)";
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.restore();

  if (scene.textures.exists(key)) {
    scene.textures.remove(key);
  }
  scene.textures.addCanvas(key, canvas);

  return {
    key,
    width: canvas.width,
    height: canvas.height,
    textureBounds,
  };
}

export function createRectTexture(
  scene: Phaser.Scene,
  key: string,
  source: HTMLImageElement,
  rect: Rect,
): PieceTextureResult {
  const canvas = document.createElement("canvas");
  canvas.width = Math.ceil(rect.width);
  canvas.height = Math.ceil(rect.height);
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas 2D context is not available");

  ctx.drawImage(source, rect.x, rect.y, rect.width, rect.height, 0, 0, rect.width, rect.height);
  ctx.lineWidth = 2;
  ctx.strokeStyle = "rgba(90, 58, 34, 0.32)";
  ctx.strokeRect(1, 1, rect.width - 2, rect.height - 2);

  if (scene.textures.exists(key)) scene.textures.remove(key);
  scene.textures.addCanvas(key, canvas);

  return { key, width: canvas.width, height: canvas.height, textureBounds: { ...rect } };
}
