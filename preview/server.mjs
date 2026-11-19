import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const PORT = Number(process.env.PORT || 3000);

const MODIFIED_FILES = [
  {
    path: "scripts/autoload/audio_mix.gd",
    role: "3 акустические зоны (изба 360 Гц + тёплый реверб / сени 1150 Гц / двор 18 кГц) + фикс AudioMix.filter",
  },
  {
    path: "scripts/director/director.gd",
    role: "Окно мнимого покоя (45–65 с), in_calm_window(), force_relax() и выдох tension в RELAX",
  },
  {
    path: "scripts/player/player.gd",
    role: "Хруст снега по температуре (-15..-42°C), отдача динамо «Жучок» и микро-дрожь прицела в мороз",
  },
  {
    path: "scripts/ui/barograph_ui.gd",
    role: "Живой самописец М-22: кардиограмма пера при Ырке, тремор рычага и чернильная надпись на сетке",
  },
  {
    path: "scripts/ui/darkroom_ui.gd",
    role: "Скример #4 «Красный кадр» под 8× лупой (задержка 1.15 с, зум, визг, «ОН УЖЕ В ДОМЕ»)",
  },
  {
    path: "scripts/ui/hud.gd",
    role: "Аналоговый HUD 1983, 6Е1П с просадкой от ДЭС-8 и вспышка жёсткого скримера trigger_jumpscare_flash()",
  },
  {
    path: "scripts/world/radio_orders.gd",
    role: "Фальшивый приказ «Свердловск-44» (fake_vane_trap) с засадой Ырки у флюгера / закрытой тропы",
  },
  {
    path: "scripts/world/zenit.gd",
    role: "Проявка невидимого глазом силуэта на плёнке Зенит-Е с Ночи 2+ (18%/28%/36%)",
  },
  {
    path: "assets/shaders/frost.gdshader",
    role: "Процедурный отпечаток ладони и 5 пальцев снаружи (hand_reveal), подтаивающий в инее окна",
  },
  {
    path: "scripts/world/station.gd",
    role: "Самовар/ледяной чай, пар в сенях, 22-с просадка ДЭС-8, ладонь на стекле, 3 зоны звука и Скримеры #1/#2",
  },
  {
    path: "scripts/world/yard.gd",
    role: "Следы от ледника к окну в метель, периферийный Жердяй в 12 FPS и Скример #3 в будке +36.6°C",
  },
  {
    path: "scripts/world/anomalies.gd",
    role: "Аномалия frozen_tea (ледяной чай и почерневший мандарин) + 5 дворовых/домовых микро-аномалий",
  },
  {
    path: "scripts/world/yrka.gd",
    role: "Акустический вакуум в CALLING и просадка динамо-фонаря в PRESSURE",
  },
  {
    path: "scripts/data/phases.gd",
    role: "Расписание fake_vane_trap на Ночах 3–4, темп смен и активная Ырка",
  },
  {
    path: "scripts/loc/strings.gd",
    role: "Все новые ключи субтитров, приказов, самовара, самописца и 4 скримеров (RU/EN)",
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
