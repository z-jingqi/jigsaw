/**
 * Batch-generate `modes.polygon` for levels that do not have polygon pieces yet,
 * using the same generator as the level editor web app.
 *
 * Usage: apps/api/node_modules/.bin/tsx scripts/generate-polygons.ts [--force] [--dry-run]
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  boundsFor,
  generatePieces,
  PIECE_DIMENSION_RULE,
  pieceSizeRange,
} from "../apps/web/src/geometry";
import type { LevelPiece } from "../apps/web/src/types";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const levelsRoot = path.resolve(scriptDir, "../../levels");
const force = process.argv.includes("--force");
const dryRun = process.argv.includes("--dry-run");

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

function polygonAreaAbs(points: Array<[number, number]>) {
  let area = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    area += a[0] * b[1] - b[0] * a[1];
  }
  return Math.abs(area / 2);
}

function validate(pieces: LevelPiece[], width: number, height: number, targetCount: number, label: string) {
  const problems: string[] = [];
  const minExpectedCount = Math.floor(targetCount * 0.85);
  if (pieces.length < minExpectedCount) {
    problems.push(
      `${pieces.length} pieces, expected at least ${minExpectedCount} from ${targetCount} random seeds`,
    );
  }
  const sizeRange = pieceSizeRange(width, height, targetCount);
  let total = 0;
  for (const piece of pieces) {
    if (piece.points.length < 3) problems.push(`piece ${piece.id} has ${piece.points.length} points`);
    if (!piece.neighbors.length && pieces.length > 1) problems.push(`piece ${piece.id} has no neighbors`);
    const bounds = boundsFor(piece.points);
    if (bounds.width < sizeRange.minWidth || bounds.width > sizeRange.maxWidth) {
      problems.push(`piece ${piece.id} width ${bounds.width.toFixed(1)} outside ${sizeRange.minWidth.toFixed(1)}-${sizeRange.maxWidth.toFixed(1)}`);
    }
    if (bounds.height < sizeRange.minHeight || bounds.height > sizeRange.maxHeight) {
      problems.push(`piece ${piece.id} height ${bounds.height.toFixed(1)} outside ${sizeRange.minHeight.toFixed(1)}-${sizeRange.maxHeight.toFixed(1)}`);
    }
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
    const configuredTarget = Number(data?.modes?.polygon?.generator?.target_count || 0);
    const targetCount = configuredTarget > 0 ? Math.round(configuredTarget) : 33 + (hash % 8);
    const pieces = generatePieces(width, height, targetCount);
    const { coverage, problems } = validate(pieces, width, height, targetCount, label);
    allProblems.push(...problems);
    const validPieceIds = new Set(pieces.map((piece) => piece.id));
    const existingAssist = data?.modes?.polygon?.assist;
    const requestedSeedIds = Array.isArray(existingAssist?.seed?.piece_ids) ? existingAssist.seed.piece_ids : [];
    const validSeedIds = requestedSeedIds.filter((id: unknown): id is string => typeof id === "string" && validPieceIds.has(id));
    const seedMode = existingAssist?.seed?.mode === "manual" && validSeedIds.length ? "manual" : "auto";
    data.modes = {
      polygon: {
        pieces,
        generator: {
          version: PIECE_DIMENSION_RULE.version,
          target_count: targetCount,
          actual_count: pieces.length,
          dimension_range: {
            reference_axis: PIECE_DIMENSION_RULE.referenceAxis,
            min_width_factor: PIECE_DIMENSION_RULE.minWidthFactor,
            max_width_factor: PIECE_DIMENSION_RULE.maxWidthFactor,
            min_height_factor: PIECE_DIMENSION_RULE.minHeightFactor,
            max_height_factor: PIECE_DIMENSION_RULE.maxHeightFactor,
          },
        },
        assist: {
          outline: existingAssist?.outline !== false,
          seed: {
            mode: seedMode,
            count: Math.max(0, Math.round(Number(existingAssist?.seed?.count ?? 1))),
            piece_ids: seedMode === "manual" ? validSeedIds : [],
          },
        },
      },
      ...Object.fromEntries(Object.entries(data.modes || {}).filter(([key]) => key !== "polygon")),
    };
    if (!dryRun) await fs.writeFile(file, `${JSON.stringify(data, null, "\t")}\n`);
    generated += 1;
    console.log(`${dryRun ? "DRY" : "OK"} ${label}: ${pieces.length} pieces (target ${targetCount}, coverage ${(coverage * 100).toFixed(2)}%)`);
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
