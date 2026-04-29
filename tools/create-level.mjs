import fs from 'node:fs/promises';
import path from 'node:path';

const cwd = process.cwd();
const levelsRoot = path.join(cwd, 'levels');
const indexPath = path.join(levelsRoot, 'index.json');

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: pnpm level:create <series-id> <level-id> [--title "Title"] [--series-title "Series"] [--source /path/to/source.png]');
  process.exit(1);
}

const seriesId = args[0];
const levelId = args[1];
const options = parseFlags(args.slice(2));
const levelTitle = options.title ?? titleCase(levelId.replace(/^\d+-/, '').replace(/-/g, ' '));
const seriesTitle = options['series-title'] ?? titleCase(seriesId.replace(/-/g, ' '));
const levelDirName = /^\d/.test(levelId) ? levelId : `001-${levelId}`;
const levelPath = path.join(levelsRoot, seriesId, levelDirName);
const sourceName = 'source.png';

await fs.mkdir(levelPath, { recursive: true });

if (options.source) {
  const sourceTarget = path.join(levelPath, sourceName);
  await fs.copyFile(path.resolve(cwd, options.source), sourceTarget);
}

const levelJson = {
  id: `${seriesId}/${levelDirName}`,
  title: levelTitle,
  source: sourceName,
  tablecloth: { type: 'color', value: '#2b2b2b' },
  difficulty: {
    pieceCount: 9,
    shapeStyle: 'curve',
    rotationEnabled: true,
    scatterRadius: 320,
  },
  snap: { positionTolerance: 11, angleTolerance: 8 },
  displayScale: 1,
  slice: { mode: 'grid', cols: 3, rows: 3, shapeStyle: 'curve', seed: `${seriesId}-${levelDirName}` },
};

await writeJson(path.join(levelPath, 'level.json'), levelJson);

const index = await readJson(indexPath);
if (!Array.isArray(index.series)) index.series = [];
let series = index.series.find((entry) => entry.id === seriesId);
if (!series) {
  series = { id: seriesId, title: seriesTitle, levels: [] };
  index.series.push(series);
}
if (!Array.isArray(series.levels)) series.levels = [];
const existing = series.levels.find((entry) => entry.path === `${seriesId}/${levelDirName}`);
if (!existing) {
    series.levels.push({
      path: `${seriesId}/${levelDirName}`,
      title: levelTitle,
      difficulties: [
        { label: '简单', cols: 2, rows: 2, shapeStyle: 'straight', rotationEnabled: false, scatterRadius: 300 },
        { label: '中等', cols: 3, rows: 3, shapeStyle: 'curve', scatterRadius: 360 },
        { label: '困难', cols: 5, rows: 5, shapeStyle: 'classic-knob', scatterRadius: 430 },
      ],
    });
  }
series.levels.sort((a, b) => a.path.localeCompare(b.path));
index.series.sort((a, b) => a.id.localeCompare(b.id));
await writeJson(indexPath, index);

console.log(`Created level scaffold at levels/${seriesId}/${levelDirName}`);
if (!options.source) {
  console.log('No source image was copied. Add source.png to the level folder before testing the level.');
}

function parseFlags(raw) {
  const flags = {};
  for (let i = 0; i < raw.length; i += 1) {
    const key = raw[i];
    if (!key.startsWith('--')) continue;
    flags[key.slice(2)] = raw[i + 1];
    i += 1;
  }
  return flags;
}

async function readJson(filePath) {
  const raw = await fs.readFile(filePath, 'utf8');
  return JSON.parse(raw);
}

async function writeJson(filePath, value) {
  await fs.writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function titleCase(input) {
  return input
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join(' ');
}
