import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const required = [
  "preview/index.html",
  "preview/server.mjs",
  "assets/shaders/trodden_path.gdshader",
  "scripts/data/phases.gd",
  "scripts/loc/strings.gd",
  "scripts/world/anomalies.gd",
  "scripts/world/footprints.gd",
  "scripts/world/props.gd",
  "scripts/world/station.gd",
  "scripts/world/yard.gd",
  "scripts/world/yrka.gd",
];

const missing = required.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Build verification failed. Missing files:", missing);
  process.exit(1);
}

console.log(`Build OK: verified ${required.length} preview and Godot 4 patch files.`);
