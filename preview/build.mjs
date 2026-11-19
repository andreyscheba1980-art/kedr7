import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const required = [
  "preview/index.html",
  "preview/server.mjs",
  "scripts/autoload/audio_mix.gd",
  "scripts/director/director.gd",
  "scripts/player/player.gd",
  "scripts/ui/barograph_ui.gd",
  "scripts/ui/darkroom_ui.gd",
  "scripts/ui/hud.gd",
  "scripts/ui/journal_tm1_ui.gd",
  "scripts/ui/main_menu.gd",
  "scripts/ui/pause_menu.gd",
  "scripts/ui/ui_kit.gd",
  "assets/shaders/frost.gdshader",
  "assets/shaders/trodden_path.gdshader",
  "scripts/data/phases.gd",
  "scripts/loc/strings.gd",
  "tools/blender/bake_kedr_props.py",
  "tools/blender/new_year_table.py",
  "tools/blender/yard_buildings.py",
  "tools/blender/outhouse.py",
  "tools/blender/stove.py",
  "scripts/world/anomalies.gd",
  "scripts/world/footprints.gd",
  "scripts/world/models.gd",
  "scripts/world/props.gd",
  "scripts/world/radio_orders.gd",
  "scripts/world/station.gd",
  "scripts/world/yard.gd",
  "scripts/world/yrka.gd",
  "scripts/world/zenit.gd",
];

const missing = required.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Build verification failed. Missing files:", missing);
  process.exit(1);
}

console.log(`Build OK: verified ${required.length} preview and Godot 4 patch files.`);
