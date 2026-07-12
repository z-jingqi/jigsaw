/**
 * Batch-generate `modes.polygon` for levels that do not have polygon pieces yet,
 * using the same generator as the level editor web app.
 *
 * Usage: apps/api/node_modules/.bin/tsx scripts/generate-polygons.ts [--force]
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { generatePieces, type ShapeKind, type ShapeRequest } from "../apps/web/src/geometry";
import type { LevelPiece } from "../apps/web/src/types";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const levelsRoot = path.resolve(scriptDir, "../../levels");
const force = process.argv.includes("--force");

const SHAPE_POOL: ShapeKind[] = ["circle", "heart", "star", "hexagon", "blob", "crescent", "triangle", "sector"];

function fnv1a(text: string) {
  let hash = 2166136261;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash >>> 0;
}

async function findLevelFiles(dir: string): Promise<string[]> {
  const found: string[] = [];
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...(await findLevelFiles(full)));
    else if (entry.name === "level.json") found.push(full);
  }
  return found;
}

function shapeRequestsFor(hash: number): ShapeRequest[] {
  // roughly half of the levels get 1-2 special shapes for variety
  const roll = (hash >>> 4) % 10;
  const count = roll < 3 ? 1 : roll < 5 ? 2 : 0;
  const requests: ShapeRequest[] = [];
  for (let i = 0; i < count; i++) {
    requests.push({ kind: SHAPE_POOL[(hash >>> (8 + i * 4)) % SHAPE_POOL.length], count: 1 });
  }
  return requests;
}

function polygonAreaAbs(points: Array<[number, number]>) {
  let area = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    area += a[0] * b[1] - b[0] * a[1];
  }
  return Math.abs(area / 2);
}

function validate(pieces: LevelPiece[], width: number, height: number, label: string) {
  const problems: string[] = [];
  if (pieces.length < 20) problems.push(`only ${pieces.length} pieces`);
  let total = 0;
  for (const piece of pieces) {
    if (piece.points.length < 3) problems.push(`piece ${piece.id} has ${piece.points.length} points`);
    if (!piece.neighbors.length && pieces.length > 1) problems.push(`piece ${piece.id} has no neighbors`);
    total += polygonAreaAbs(piece.points as Array<[number, number]>);
  }
  const coverage = total / (width * height);
  if (coverage < 0.995 || coverage > 1.03) problems.push(`coverage ${(coverage * 100).toFixed(2)}%`);
  return { coverage, problems: problems.map((problem) => `${label}: ${problem}`) };
}

async function main() {
  const files = (await findLevelFiles(levelsRoot)).sort();
  let generated = 0;
  let skipped = 0;
  const allProblems: string[] = [];
  for (const file of files) {
    const data = JSON.parse(await fs.readFile(file, "utf8"));
    const existing = data?.modes?.polygon?.pieces;
    if (!force && Array.isArray(existing) && existing.length > 0) {
      skipped += 1;
      continue;
    }
    const width = Number(data?.image?.width || 0);
    const height = Number(data?.image?.height || 0);
    const label = `${data?.topic_id || "?"}/${data?.id || path.basename(path.dirname(file))}`;
    if (!width || !height) {
      allProblems.push(`${label}: missing image size, skipped`);
      continue;
    }
    const hash = fnv1a(label);
    const targetCount = 33 + (hash % 8);
    const shapes = shapeRequestsFor(hash);
    const pieces = generatePieces(width, height, targetCount, shapes, []);
    const { coverage, problems } = validate(pieces, width, height, label);
    allProblems.push(...problems);
    data.modes = {
      polygon: {
        pieces,
        generator: { target_count: targetCount, shapes, manual_shapes: [] },
        assist: { outline: true, seed: { mode: "auto", count: 1, piece_ids: [] } },
      },
      ...Object.fromEntries(Object.entries(data.modes || {}).filter(([key]) => key !== "polygon")),
    };
    await fs.writeFile(file, `${JSON.stringify(data, null, "\t")}\n`);
    generated += 1;
    console.log(`OK ${label}: ${pieces.length} pieces (target ${targetCount}, shapes [${shapes.map((s) => s.kind).join(", ")}], coverage ${(coverage * 100).toFixed(2)}%)`);
  }
  console.log(`\nDone. generated=${generated} skipped=${skipped}`);
  if (allProblems.length) {
    console.log(`\nProblems:\n${allProblems.join("\n")}`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
