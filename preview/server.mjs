import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const PORT = Number(process.env.PORT || 3000);

const MODIFIED_FILES = [
  {
    path: "scripts/ui/hud.gd",
    role: "Аналоговый HUD 1983: живой прицел, гальванометр, панель «Волна-К» + 6Е1П и телетайпный отчёт",
  },
  {
    path: "scripts/ui/journal_tm1_ui.gd",
    role: "Журнал ТМ-1: авто-зона по локации, счётчики, звук пера и рукописная лента аномалий",
  },
  {
    path: "scripts/ui/main_menu.gd",
    role: "Главное меню: эмалевый ГОСТ-шильдик с заклёпками и пульсирующим диодом дежурства",
  },
  {
    path: "scripts/ui/pause_menu.gd",
    role: "Меню паузы: унификация с Главным меню на TelemetryButton и шильдике смены",
  },
  {
    path: "scripts/ui/ui_kit.gd",
    role: "Чистая типографика UI (мягкая обводка 2px, эмалевые кнопки и поля)",
  },
  {
    path: "tools/blender/bake_kedr_props.py",
    role: "Автосборщик Blender (4.x/5.2): запекание всех новых low-poly .glb в assets/models/kedr/",
  },
  {
    path: "tools/blender/new_year_table.py",
    role: "Новогодний стол: ель в 3-л банке (дождик + игрушки), шампанское/мандарин/стакан, тульский самовар",
  },
  {
    path: "tools/blender/yard_buildings.py",
    role: "Двор + изба: инфо-щит с картой кордона и ТБ, конура, ледник + крышка люка, русская печь",
  },
  {
    path: "tools/blender/outhouse.py",
    role: "Станционная уборная: наборные доски со щелями, петли, скоба, щеколда, козырёк со снегом",
  },
  {
    path: "tools/blender/stove.py",
    role: "Кирпичная печь: чугунная варочная плита с 2 конфорками и рельефная топочная дверца ДТ-3",
  },
  {
    path: "scripts/world/models.gd",
    role: "Поддержка полупрозрачного стекла GLB (3-л банка, гранёный стакан) и alpha-scissor без артефактов",
  },
  {
    path: "scripts/world/props.gd",
    role: "Подключение GLB-моделей Блока 1/2 и печей + сохранение узлов всех дворовых аномалий",
  },
  {
    path: "assets/shaders/trodden_path.gdshader",
    role: "Шейдер бесшовных троп (blend_mix из main + depth_bias + мягкий край)",
  },
  {
    path: "scripts/world/footprints.gd",
    role: "Следы в снегу (синхронизировано с актуальным main)",
  },
  {
    path: "scripts/world/yard.gd",
    role: "Коридорная планировка двора, сугробы вдоль стен и поляна у уборной (синхронизировано с main)",
  },
  {
    path: "scripts/world/anomalies.gd",
    role: "5 новых микро-аномалий (DEFS, _apply/_revert, журнал ТМ-1)",
  },
  {
    path: "scripts/world/station.gd",
    role: "Мерцание гирлянды 1983 года, реакция на блэкаут и garland_red",
  },
  {
    path: "scripts/world/yrka.gd",
    role: "Акустический вакуум в CALLING и просадка динамо-фонаря в PRESSURE",
  },
  {
    path: "scripts/data/phases.gd",
    role: "Темп ночей (~11 мин), зубы Ночи 1 и активная Ырка с Ночи 2",
  },
  {
    path: "scripts/loc/strings.gd",
    role: "Сухой слог вахтенного журнала 1983 г. + ключи 5 аномалий (RU/EN)",
  },
];

const ALLOWED_SET = new Set(MODIFIED_FILES.map((f) => f.path));

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

  if (url.pathname === "/api/files") {
    const payload = MODIFIED_FILES.map((entry) => {
      const abs = path.join(ROOT, entry.path);
      const stat = fs.existsSync(abs) ? fs.statSync(abs) : null;
      const lines = stat ? fs.readFileSync(abs, "utf8").split(/\r?\n/).length : 0;
      return {
        ...entry,
        exists: Boolean(stat),
        bytes: stat ? stat.size : 0,
        lines,
      };
    });
    res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify({ files: payload }));
    return;
  }

  if (url.pathname === "/api/file") {
    const rel = url.searchParams.get("path") || "";
    if (!ALLOWED_SET.has(rel)) {
      res.writeHead(404, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ error: "File not found" }));
      return;
    }
    const abs = path.join(ROOT, rel);
    const content = fs.readFileSync(abs, "utf8");
    res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(content);
    return;
  }

  if (url.pathname === "/" || url.pathname === "/index.html") {
    const html = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(html);
    return;
  }

  res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Not found");
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Kedr-7 Yard & Patch Preview running at http://0.0.0.0:${PORT}`);
});
