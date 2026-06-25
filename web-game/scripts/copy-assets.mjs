import fs from "node:fs";
import path from "node:path";

const repoRoot = path.resolve(new URL(".", import.meta.url).pathname, "../..");
const distRoot = path.resolve(repoRoot, "web-game/dist");

copyDir(path.resolve(repoRoot, "levels"), path.resolve(distRoot, "levels"));
copyDir(path.resolve(repoRoot, "assets"), path.resolve(distRoot, "assets"));

function copyDir(source, target) {
  if (!fs.existsSync(source)) return;
  fs.mkdirSync(target, { recursive: true });
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    const sourcePath = path.join(source, entry.name);
    const targetPath = path.join(target, entry.name);
    if (entry.isDirectory()) {
      copyDir(sourcePath, targetPath);
    } else if (entry.isFile() && !entry.name.endsWith(".import")) {
      fs.copyFileSync(sourcePath, targetPath);
    }
  }
}
