// The production generator is deterministic for dimensions and target count.
import fs from "node:fs/promises";
import path from "node:path";
import { generatePieces, boundsFor, pieceSizeRange, PIECE_DIMENSION_RULE } from "../../level-editor/apps/web/src/geometry";

const stage = path.resolve(process.argv[2] || ".artifacts/content-rebuild-20261005/staging/levels");
const maximumCount = Number(process.argv[3] || 80);
const minimumCount = Number(process.argv[4] || 4);

async function files(dir: string): Promise<string[]> {
  const result: string[] = [];
  for (const item of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, item.name);
    if (item.isDirectory()) result.push(...await files(full));
    else if (item.name === "level.json") result.push(full);
  }
  return result;
}

async function main() {
  let built = 0;
  const layouts = new Map<string, ReturnType<typeof generatePieces>>();
  const unsupported = new Set<string>();
  for (const file of (await files(stage)).sort()) {
    const config = JSON.parse(await fs.readFile(file, "utf8"));
    if (config.modes.polygon.pieces.length) continue;
    const { width, height } = config.image;
    const requested = config.modes.polygon.generator.target_count;
    let target = requested;
    let pieces: ReturnType<typeof generatePieces> = [];
    for (const count of [requested, requested + 1, requested - 1, 28, 30, 26, 24]) {
      const key = `${width}x${height}/${count}`;
      if (unsupported.has(key)) continue;
      try {
        target = count;
        if (!layouts.has(key)) layouts.set(key, generatePieces(width, height, count));
        const candidate = layouts.get(key)!;
        if (candidate.length < minimumCount || candidate.length > maximumCount) continue;
        pieces = candidate;
        break;
      } catch {
        unsupported.add(key);
      }
    }
    if (!pieces.length) throw Error(`No valid production layout: ${config.id}`);
    const range = pieceSizeRange(width, height, target);
    let area = 0;
    for (const piece of pieces) {
      const bounds = boundsFor(piece.points);
      if (piece.points.length < 3 || !piece.neighbors.length || bounds.width < range.minWidth || bounds.width > range.maxWidth || bounds.height < range.minHeight || bounds.height > range.maxHeight) throw Error(`Invalid geometry: ${config.id}/${piece.id}`);
      let sum = 0;
      for (let index = 0; index < piece.points.length; index++) {
        const a = piece.points[index], b = piece.points[(index + 1) % piece.points.length];
        sum += a[0] * b[1] - b[0] * a[1];
      }
      area += Math.abs(sum / 2);
    }
    if (area / (width * height) < 0.995 || area / (width * height) > 1.03) throw Error(`Bad coverage: ${config.id}`);
    config.modes.polygon.pieces = pieces;
    config.modes.polygon.generator = {
      version: PIECE_DIMENSION_RULE.version, target_count: target, actual_count: pieces.length,
      dimension_range: { reference_axis: PIECE_DIMENSION_RULE.referenceAxis, min_width_factor: PIECE_DIMENSION_RULE.minWidthFactor, max_width_factor: PIECE_DIMENSION_RULE.maxWidthFactor, min_height_factor: PIECE_DIMENSION_RULE.minHeightFactor, max_height_factor: PIECE_DIMENSION_RULE.maxHeightFactor },
    };
    await fs.writeFile(file, JSON.stringify(config, null, "\t") + "\n");
    built++;
  }
  console.log(JSON.stringify({ ok: true, built }));
}

main().catch(error => { console.error(error); process.exit(1); });
