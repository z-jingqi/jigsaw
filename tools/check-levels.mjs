import fs from 'node:fs/promises';
import path from 'node:path';

const cwd = process.cwd();
const levelsRoot = path.join(cwd, 'levels');
const indexPath = path.join(levelsRoot, 'index.json');
const validShapeStyles = new Set(['straight', 'curve', 'classic-knob', 'mixed']);

const index = JSON.parse(await fs.readFile(indexPath, 'utf8'));
const errors = [];

for (const series of index.series ?? []) {
  if (!series.id) errors.push('Series entry is missing id.');
  for (const level of series.levels ?? []) {
    const relLevelDir = level.path;
    const levelDir = path.join(levelsRoot, relLevelDir);
    const levelJsonPath = path.join(levelDir, 'level.json');
    const sourcePath = path.join(levelDir, 'source.png');

    await assertExists(levelJsonPath, `Missing level.json for ${relLevelDir}`);
    await assertExists(sourcePath, `Missing source.png for ${relLevelDir}`);

    const levelJson = JSON.parse(await fs.readFile(levelJsonPath, 'utf8'));
    if (!validShapeStyles.has(levelJson.difficulty?.shapeStyle)) {
      errors.push(`Invalid difficulty.shapeStyle in ${relLevelDir}: ${levelJson.difficulty?.shapeStyle}`);
    }
    if (levelJson.slice?.shapeStyle && !validShapeStyles.has(levelJson.slice.shapeStyle)) {
      errors.push(`Invalid slice.shapeStyle in ${relLevelDir}: ${levelJson.slice.shapeStyle}`);
    }
    for (const diff of level.difficulties ?? []) {
      if (diff.shapeStyle && !validShapeStyles.has(diff.shapeStyle)) {
        errors.push(`Invalid difficulty preset shapeStyle in ${relLevelDir} (${diff.label}): ${diff.shapeStyle}`);
      }
      if ((diff.cols ?? 0) < 2 || (diff.rows ?? 0) < 2) {
        errors.push(`Difficulty preset ${relLevelDir}/${diff.label} must be at least 2x2.`);
      }
    }
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log('Level index and level files look consistent.');

async function assertExists(filePath, message) {
  try {
    await fs.access(filePath);
  } catch {
    errors.push(message);
  }
}
