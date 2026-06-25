import { Point } from "../../data/types";
import { PieceDefinition } from "../types";
import { boundsOf } from "./geometry";

export function generateKnobDefinitions(width: number, height: number, cols: number, rows: number, knobSize = 0.24): PieceDefinition[] {
  const cellW = width / cols;
  const cellH = height / rows;
  const radius = Math.min(cellW, cellH) * knobSize;
  const pieces: PieceDefinition[] = [];

  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      const id = `knob_${row}_${col}`;
      const x = col * cellW;
      const y = row * cellH;
      const points = knobPoints(x, y, cellW, cellH, radius, row, col, rows, cols);
      const neighbors = [
        row > 0 ? `knob_${row - 1}_${col}` : null,
        row < rows - 1 ? `knob_${row + 1}_${col}` : null,
        col > 0 ? `knob_${row}_${col - 1}` : null,
        col < cols - 1 ? `knob_${row}_${col + 1}` : null,
      ].filter((value): value is string => Boolean(value));
      pieces.push({
        id,
        points,
        bounds: boundsOf(points),
        textureBounds: boundsOf(points),
        neighbors,
        row,
        col,
      });
    }
  }

  return pieces;
}

function knobPoints(
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number,
  row: number,
  col: number,
  rows: number,
  cols: number,
): Point[] {
  const points: Point[] = [];
  appendEdge(points, { x, y }, { x: x + width, y }, row > 0 ? knobDirection(row, col, "top") * -1 : 0, radius, "horizontal");
  appendEdge(points, { x: x + width, y }, { x: x + width, y: y + height }, col < cols - 1 ? knobDirection(row, col, "right") : 0, radius, "vertical");
  appendEdge(points, { x: x + width, y: y + height }, { x, y: y + height }, row < rows - 1 ? knobDirection(row, col, "bottom") : 0, radius, "horizontal");
  appendEdge(points, { x, y: y + height }, { x, y }, col > 0 ? knobDirection(row, col, "left") * -1 : 0, radius, "vertical");
  return points;
}

function knobDirection(row: number, col: number, side: string): number {
  const seed = (row * 17 + col * 31 + side.length * 13) % 2;
  return seed === 0 ? 1 : -1;
}

function appendEdge(points: Point[], start: Point, end: Point, direction: number, radius: number, axis: "horizontal" | "vertical") {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const length = Math.hypot(dx, dy);
  const ux = dx / length;
  const uy = dy / length;
  const nx = axis === "horizontal" ? 0 : direction;
  const ny = axis === "horizontal" ? direction : 0;
  const mid = { x: start.x + dx * 0.5, y: start.y + dy * 0.5 };
  const startKnob = { x: mid.x - ux * radius, y: mid.y - uy * radius };
  const endKnob = { x: mid.x + ux * radius, y: mid.y + uy * radius };

  pushPoint(points, start);
  if (direction === 0) {
    pushPoint(points, end);
    return;
  }
  pushPoint(points, startKnob);
  const steps = 10;
  for (let i = 0; i <= steps; i += 1) {
    const t = i / steps;
    const angle = Math.PI * t;
    const along = (t - 0.5) * radius * 2;
    const lift = Math.sin(angle) * radius;
    pushPoint(points, {
      x: mid.x + ux * along + nx * lift,
      y: mid.y + uy * along + ny * lift,
    });
  }
  pushPoint(points, endKnob);
  pushPoint(points, end);
}

function pushPoint(points: Point[], point: Point) {
  const last = points[points.length - 1];
  if (!last || Math.hypot(last.x - point.x, last.y - point.y) > 0.1) {
    points.push(point);
  }
}
