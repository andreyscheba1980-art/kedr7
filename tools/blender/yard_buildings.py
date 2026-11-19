# Дворовые постройки и интерьерная русская печь для «Кедр-7» (PS1 low-poly, gl_compatibility).
# Генерирует модели в assets/models/kedr/:
#   1. outpost_stand   — инфо-стенд кордона под козырьком с 512x512 плакатом ТБ в тайге
#                        и картой участков ГМС «Кедр-7» с красной звездой «ВЫ ЗДЕСЬ».
#   2. doghouse        — дощатая собачья конура со щелями, пологом, снегом на крыше,
#                        колышком и эмалированной миской со льдом.
#   3. ice_cellar      — погреб-ледник (земляной бугор со снегом, срубный оголовок, вытяжка)
#      + ice_cellar_lid — отдельная наклонная дощатая дверь на петлях с навесным замком
#                        (чтобы в игре сохранилась ночная аномалия приоткрывания HatchLid!).
#   4. russian_stove   — традиционная русская печь для избы (побелка, шесток, чугунная заслонка,
#                        варочная плита с конфоркой, чугунок и кирпичная труба).
#
# Оси: origin="keep" (низ на Z=0, перед в -Y Блендера = +Z Godot) — совпадает 1-в-1 с
# координатами дочерних узлов аномалий (RedPin, BloodScratch, ChainSlack/Taut, InsideEyes, HatchLid, VentSteam).
# Без внешних зависимостей (только bpy, bmesh, numpy).
# Запуск:
#   blender --background --factory-startup --python tools/blender/yard_buildings.py -- assets/models/kedr [имя ...]

import bpy
import bmesh
import math
import os
import random
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube, text, mat

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/kedr"
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)


def want(name):
    return not ONLY or name in ONLY


def _bsdf_of(m):
    nt = m.node_tree
    return (
        next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        or nt.nodes.get("Principled BSDF")
        or nt.nodes.get("Принципиальный BSDF")
    )


def _inp(node, names, idx):
    for n in names:
        if n in node.inputs:
            return node.inputs[n]
    return node.inputs[idx]


def make_image_mat(name, img, rough=0.86):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf_of(m)
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    tn.interpolation = "Closest"
    nt.links.new(tn.outputs["Color"], _inp(b, ("Base Color", "Базовый цвет"), 0))
    _inp(b, ("Roughness", "Шероховатость"), 2).default_value = rough
    _inp(b, ("Metallic", "Металличность"), 1).default_value = 0.0
    return m


# ---------------------------------------------------------------------------
# Чисто-numpy генератор советского плаката 512x512 (карта кордона + ТБ в тайге)
# ---------------------------------------------------------------------------

def _rect(buf, x0, y0, x1, y1, col):
    h, w, _ = buf.shape
    ix0, ix1 = max(0, min(w, int(x0))), max(0, min(w, int(x1)))
    iy0, iy1 = max(0, min(h, int(y0))), max(0, min(h, int(y1)))
    if ix1 > ix0 and iy1 > iy0:
        buf[iy0:iy1, ix0:ix1, :3] = col
        buf[iy0:iy1, ix0:ix1, 3] = 1.0


def _line(buf, x0, y0, x1, y1, col, thickness=2):
    dist = max(1, int(math.hypot(x1 - x0, y1 - y0)))
    r = max(0, thickness // 2)
    for i in range(dist + 1):
        t = i / dist
        x = int(x0 + (x1 - x0) * t)
        y = int(y0 + (y1 - y0) * t)
        _rect(buf, x - r, y - r, x + r + 1, y + r + 1, col)


def _star(buf, cx, cy, r_out, r_in, col):
    """Красная советская 5-конечная звезда «ВЫ ЗДЕСЬ»."""
    h, w, _ = buf.shape
    pts = []
    for i in range(10):
        a = math.pi * 0.5 + i * math.pi / 5.0
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    x0, x1 = max(0, int(cx - r_out - 2)), min(w, int(cx + r_out + 2))
    y0, y1 = max(0, int(cy - r_out - 2)), min(h, int(cy + r_out + 2))
    for y in range(y0, y1):
        for x in range(x0, x1):
            inside = False
            j = 9
            for i in range(10):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
                    inside = not inside
                j = i
            if inside:
                buf[y, x, :3] = col
                buf[y, x, 3] = 1.0


def _make_outpost_poster_image():
    """512x384 плакат кордона: слева — топографическая схема участков с красной звездой «ВЫ ЗДЕСЬ»,
    справа — плакат «ТЕХНИКА БЕЗОПАСНОСТИ В ТАЙГЕ» и график дежурств."""
    w, h = 512, 384
    buf = np.zeros((h, w, 4), dtype=np.float32)

    # Тёмно-зелёный окрашенный фанерный фон стенда
    _rect(buf, 0, 0, w, h, (0.14, 0.21, 0.16))
    # Деревянная внутренняя кайма
    _rect(buf, 4, 4, w - 4, 10, (0.24, 0.18, 0.13))
    _rect(buf, 4, h - 10, w - 4, h - 4, (0.24, 0.18, 0.13))
    _rect(buf, 4, 4, 10, h - 4, (0.24, 0.18, 0.13))
    _rect(buf, w - 10, 4, w - 4, h - 4, (0.24, 0.18, 0.13))

    paper = (0.79, 0.74, 0.61)
    paper_dk = (0.71, 0.66, 0.54)
    ink = (0.13, 0.15, 0.16)
    grid_c = (0.64, 0.61, 0.50)
    red = (0.72, 0.13, 0.10)
    red_dk = (0.48, 0.10, 0.08)
    blue = (0.18, 0.34, 0.48)
    pine = (0.24, 0.38, 0.25)

    # === ЛЕВЫЙ ЛИСТ: КАРТА УЧАСТКОВ ГМС «КЕДР-7» (x: 18..288, y: 20..364) ===
    lx0, ly0, lx1, ly1 = 18, 20, 288, 364
    _rect(buf, lx0, ly0, lx1, ly1, paper)
    # Красная верхняя плашка заголовка схемы
    _rect(buf, lx0, ly1 - 36, lx1, ly1, red)
    for sx in range(lx0 + 18, lx1 - 18, 12):
        _rect(buf, sx, ly1 - 24, sx + 7, ly1 - 12, (0.94, 0.90, 0.78))
    # Топографическая координатная сетка
    for gx in range(lx0 + 28, lx1, 32):
        _line(buf, gx, ly0 + 10, gx, ly1 - 40, grid_c, 1)
    for gy in range(ly0 + 28, ly1 - 40, 32):
        _line(buf, lx0 + 10, gy, lx1 - 10, gy, grid_c, 1)

    # Условные значки тайги по краям карты (елочки)
    trees = [(42, 300), (62, 306), (252, 295), (268, 272), (264, 148), (44, 72), (66, 56), (242, 64)]
    for tx, ty in trees:
        _line(buf, tx, ty - 8, tx, ty + 8, pine, 2)
        _line(buf, tx - 7, ty - 2, tx, ty + 8, pine, 2)
        _line(buf, tx + 7, ty - 2, tx, ty + 8, pine, 2)
        _line(buf, tx - 9, ty - 7, tx, ty + 2, pine, 2)
        _line(buf, tx + 9, ty - 7, tx, ty + 2, pine, 2)

    # Зона закрытой тропы в тайгу (правый верхний сектор, красная штриховка)
    _rect(buf, 196, 212, 276, 314, (0.76, 0.68, 0.56))
    for k in range(0, 120, 10):
        _line(buf, 196 + min(k, 80), 212 + max(0, k - 80),
              196 + max(0, k - 102), 212 + min(k, 102), red_dk, 2)
    _rect(buf, 196, 212, 276, 215, red)
    _rect(buf, 196, 311, 276, 314, red)
    _rect(buf, 196, 212, 199, 314, red)
    _rect(buf, 273, 212, 276, 314, red)

    # Тропы-просеки двора (крест маршрутов: дом -> площадка, ДЭС, ледник, дровяник)
    cx, cy = 148, 178
    _line(buf, cx, cy, cx, 304, ink, 4)        # на север — метеоплощадка
    _line(buf, cx, cy, 248, cy, ink, 4)       # на восток — ДЭС / генератор
    _line(buf, cx, cy, cx, 58, ink, 4)        # на юг — дровяник и уборная
    _line(buf, cx, cy, 56, cy, red, 4)        # на запад — кордон / зимник
    _line(buf, cx, cy, 206, 236, red_dk, 3)   # к леднику и закрытой тропе

    # Постройки на схеме
    _rect(buf, cx - 22, cy - 16, cx + 22, cy + 16, ink)        # Главный дом ГМС
    _rect(buf, cx - 18, cy - 12, cx + 18, cy + 12, paper_dk)
    _rect(buf, cx - 18, 286, cx + 18, 314, blue)               # Метеоплощадка (синий квадрат)
    _rect(buf, cx - 14, 290, cx + 14, 310, paper)
    _rect(buf, 234, cy - 12, 262, cy + 12, ink)                # ДЭС
    _rect(buf, 186, 224, 204, 242, blue)                       # Ледник-погреб
    _rect(buf, cx - 14, 46, cx + 14, 66, ink)                  # Дровяник

    # Роза ветров «С» в левом верхнем углу карты
    _line(buf, 48, 246, 48, 286, ink, 2)
    _line(buf, 36, 266, 60, 266, ink, 2)
    _line(buf, 48, 286, 42, 274, red, 2)
    _line(buf, 48, 286, 54, 274, red, 2)

    # КРАСНАЯ ЗВЕЗДА «ВЫ ЗДЕСЬ» (совпадает с положением RedPin слева от центра!)
    _star(buf, 98, 178, 18, 7, red)
    _star(buf, 98, 178, 7, 3, (0.96, 0.86, 0.45))

    # Рамка и легенда внизу схемы
    _rect(buf, lx0 + 10, ly0 + 10, lx1 - 10, ly0 + 36, paper_dk)
    _rect(buf, lx0 + 18, ly0 + 18, lx0 + 30, ly0 + 28, red)
    for row_x in range(lx0 + 38, lx1 - 24, 14):
        _rect(buf, row_x, ly0 + 20, row_x + 9, ly0 + 26, ink)

    # === ПРАВЫЙ ЛИСТ: ПЛАКАТ «ТБ В ТАЙГЕ» + ГРАФИК ВАХТЫ (x: 304..494, y: 20..364) ===
    rx0, ry0, rx1, ry1 = 304, 20, 494, 364
    _rect(buf, rx0, ry0, rx1, ry1, (0.76, 0.71, 0.58))
    # Агитационная алая шапка плаката
    _rect(buf, rx0, ry1 - 54, rx1, ry1, red)
    for sx in range(rx0 + 14, rx1 - 14, 11):
        _rect(buf, sx, ry1 - 22, sx + 7, ry1 - 10, (0.96, 0.92, 0.82))
        _rect(buf, sx + 2, ry1 - 42, sx + 8, ry1 - 32, (0.96, 0.84, 0.42))

    # Пиктограмма предупреждения (жёлто-чёрный треугольник с восклицательным знаком)
    _rect(buf, rx0 + 18, ry1 - 134, rx0 + 82, ry1 - 70, (0.86, 0.72, 0.20))
    _line(buf, rx0 + 22, ry1 - 130, rx0 + 50, ry1 - 74, ink, 3)
    _line(buf, rx0 + 78, ry1 - 130, rx0 + 50, ry1 - 74, ink, 3)
    _line(buf, rx0 + 22, ry1 - 130, rx0 + 78, ry1 - 130, ink, 3)
    _rect(buf, rx0 + 48, ry1 - 114, rx0 + 53, ry1 - 92, red)
    _rect(buf, rx0 + 48, ry1 - 124, rx0 + 53, ry1 - 119, red)

    # Строки инструкции справа от знака
    for row in range(0, 5):
        ry = ry1 - 80 - row * 12
        _rect(buf, rx0 + 92, ry, rx1 - 14 - (row % 2) * 18, ry + 4, ink)

    # Разделительная красная черта и таблица графика смен
    _rect(buf, rx0 + 12, ry1 - 150, rx1 - 12, ry1 - 146, red)
    for row in range(0, 8):
        ry = ry1 - 172 - row * 19
        _rect(buf, rx0 + 16, ry, rx0 + 44, ry + 5, blue if row < 6 else red)
        _rect(buf, rx0 + 52, ry, rx1 - 20 - (row % 3) * 14, ry + 5, ink)
        _line(buf, rx0 + 12, ry - 6, rx1 - 12, ry - 6, grid_c, 1)

    # Жирно перечёркнутая нижняя строка графика (Семёнов, 1982)
    _line(buf, rx0 + 18, ry0 + 44, rx1 - 24, ry0 + 58, (0.12, 0.08, 0.08), 5)
    _line(buf, rx0 + 18, ry0 + 54, rx1 - 28, ry0 + 42, (0.12, 0.08, 0.08), 4)

    # Канцелярские кнопки по углам обоих листов
    for px, py in [(lx0 + 7, ly0 + 7), (lx1 - 7, ly0 + 7), (lx0 + 7, ly1 - 7), (lx1 - 7, ly1 - 7),
                   (rx0 + 7, ry0 + 7), (rx1 - 7, ry0 + 7), (rx0 + 7, ry1 - 7), (rx1 - 7, ry1 - 7)]:
        _rect(buf, px - 3, py - 3, px + 3, py + 3, (0.72, 0.68, 0.58))

    # Лёгкая выцветшая фактура бумаги, влага по нижнему краю
    rng = np.random.default_rng(198301)
    grain = rng.uniform(-0.045, 0.045, (h, w, 1)).astype(np.float32)
    buf[:, :, :3] = np.clip(buf[:, :, :3] + grain, 0.0, 1.0)
    damp = np.linspace(0.76, 1.0, 60, dtype=np.float32)[:, None, None]
    buf[:60, :, :3] *= damp
    buf[:, :, 3] = 1.0

    img = bpy.data.images.new("outpost_poster_tex", w, h, alpha=True)
    img.pixels.foreach_set(buf.ravel())
    img.pack()
    return img


# ---------------------------------------------------------------------------
# 1. ИНФОРМАЦИОННЫЙ СТЕНД КОРДОНА (outpost_stand.glb)
# ---------------------------------------------------------------------------

def build_outpost_stand():
    kit.reset()

    POST_WOOD = mat("st_post", (0.27, 0.21, 0.15), rough=0.90, noise=0.28, wear=0.65, dirt=0.65,
                    wear_col=(0.40, 0.34, 0.26))
    PLANK_WOOD = mat("st_plank", (0.31, 0.25, 0.18), rough=0.88, noise=0.25, wear=0.6, dirt=0.55,
                     wear_col=(0.46, 0.40, 0.32))
    BOARD_GREEN = mat("st_green", (0.16, 0.23, 0.18), rough=0.82, noise=0.18, wear=0.65, dirt=0.5,
                      wear_col=(0.30, 0.34, 0.28))
    HEADER_RED = mat("st_red", (0.50, 0.14, 0.11), rough=0.72, noise=0.15, wear=0.6, dirt=0.4,
                     wear_col=(0.68, 0.36, 0.28))
    HEADER_TXT = mat("st_txt", (0.88, 0.84, 0.72), rough=0.75)
    IRON = mat("st_iron", (0.16, 0.17, 0.18), rough=0.55, wear=0.7, wear_col=(0.44, 0.26, 0.16))
    SNOW = mat("st_snow", (0.86, 0.90, 0.95), rough=0.88, noise=0.04)
    POSTER_MAT = make_image_mat("st_poster", _make_outpost_poster_image(), rough=0.86)

    # 1. Два окорённых столба с укосинами и снежными сугробами у основания (x = ±0.74 м)
    for sx in (-0.74, 0.74):
        cyl(f"post_{sx}", 0.072, 2.24, (sx, 0.0, 1.12), POST_WOOD, rot=(0, 0, 0), verts=8, r2=0.064)
        # Нижние и верхние подкосы
        sgn = 1.0 if sx > 0 else -1.0
        box(f"brace_bot_{sx}", (0.06, 0.06, 0.52), (sx * 0.82, 0.0, 0.30), POST_WOOD, 0.005,
            rot=(0, math.radians(-32 * sgn), 0))
        box(f"brace_top_{sx}", (0.055, 0.055, 0.36), (sx * 0.84, 0.0, 1.98), POST_WOOD, 0.005,
            rot=(0, math.radians(38 * sgn), 0))
        # Наметённый снег у комля
        sphere(f"base_snow_{sx}", 0.26, (sx, 0.02, 0.10), SNOW, scale=(1.1, 1.0, 0.55), segs=9, rings=5)

    # Поперечины сзади
    for zz in (0.94, 1.82):
        box(f"rear_bar_{zz}", (1.58, 0.05, 0.07), (0.0, 0.055, zz), POST_WOOD, 0.005)
        for sx in (-0.74, 0.74):
            cyl(f"bolt_{sx}_{zz}", 0.012, 0.015, (sx, -0.04, zz), IRON, rot=(math.pi * 0.5, 0, 0), verts=6)

    # 2. Дощатый короб стенда с обкладной рамкой (центр Z=1.38, перед Y=-0.032)
    box("board_back", (1.44, 0.055, 1.02), (0.0, 0.0, 1.38), BOARD_GREEN, 0.006)
    # Профилированная деревянная рамка по периметру
    box("frame_top", (1.48, 0.036, 0.045), (0.0, -0.022, 1.88), POST_WOOD, 0.004)
    box("frame_bot", (1.48, 0.045, 0.048), (0.0, -0.026, 0.88), POST_WOOD, 0.004)
    box("frame_L", (0.045, 0.036, 1.02), (-0.71, -0.022, 1.38), POST_WOOD, 0.004)
    box("frame_R", (0.045, 0.036, 1.02), (0.71, -0.022, 1.38), POST_WOOD, 0.004)

    # Красная фасадная табличка «УГМС • ПОСТ КЕДР-7» под козырьком
    box("header_bar", (1.48, 0.068, 0.145), (0.0, -0.010, 1.97), HEADER_RED, 0.005)
    text("УГМС • ПОСТ КЕДР-7", 0.072, (0.0, -0.047, 1.97), HEADER_TXT, rot=(math.pi * 0.5, 0, 0))

    # 3. UV-развёрнутое полотно плаката (перед на Y=-0.033 => +0.033 Z в Godot,
    # прямо под RedPin на Z=+0.045 и BloodScratch на Z=+0.044!)
    bm = bmesh.new()
    uv_l = bm.loops.layers.uv.new("UVMap")
    pw, ph = 1.32, 0.92
    y_face = -0.034
    z_mid = 1.38
    v0 = bm.verts.new((-pw * 0.5, y_face, z_mid - ph * 0.5))
    v1 = bm.verts.new((pw * 0.5, y_face, z_mid - ph * 0.5))
    v2 = bm.verts.new((pw * 0.5, y_face, z_mid + ph * 0.5))
    v3 = bm.verts.new((-pw * 0.5, y_face, z_mid + ph * 0.5))
    f = bm.faces.new((v0, v1, v2, v3))
    for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv_l].uv = uv
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    pmesh = bpy.data.meshes.new("poster_canvas")
    bm.to_mesh(pmesh)
    bm.free()
    pobj = bpy.data.objects.new("poster_canvas", pmesh)
    bpy.context.collection.objects.link(pobj)
    pobj.data.materials.append(POSTER_MAT)
    kit.objs.append(pobj)

    # 4. Двускатный дощатый козырёк с обрешёткой и снежной шапкой
    for sy_s, tilt in ((-1, -26), (1, 26)):
        for pi in range(3):
            dist = 0.08 + pi * 0.135
            ang = math.radians(tilt)
            yy = sy_s * dist * math.cos(abs(ang))
            zz = 2.28 - dist * math.sin(abs(ang))
            box(f"roof_p_{sy_s}_{pi}", (1.76, 0.130, 0.028), (0.0, yy, zz), PLANK_WOOD, 0.004,
                rot=(ang, 0, 0))
        # Снежная шапка на скате козырька
        box(f"roof_snow_{sy_s}", (1.72, 0.39, 0.068), (0.0, sy_s * 0.16, 2.25), SNOW, 0.022,
            rot=(math.radians(tilt), 0, 0))
    # Коньковый брус
    box("roof_ridge", (1.78, 0.075, 0.055), (0.0, 0.0, 2.31), POST_WOOD, 0.006)
    box("roof_ridge_snow", (1.74, 0.095, 0.050), (0.0, 0.0, 2.345), SNOW, 0.02)

    # origin="keep" сохраняет точные координаты под RedPin & BloodScratch
    # uv_boost отдает плакату больше пикселей в 512x512 атласе!
    body, img, tris = kit.finish(
        "outpost_stand",
        OUT,
        res=1024,
        origin="keep",
        samples=24,
        ao_min=0.45,
        uv_boost=(lambda c: abs(c.y + 0.034) < 0.015 and 0.9 < c.z < 1.86, 2.4),
    )
    kit.export(os.path.join(OUT, "outpost_stand.glb"), os.path.join(OUT, "outpost_stand.blend"))
    print(f"[OK] outpost_stand exported: {tris} tris")


# ---------------------------------------------------------------------------
# 2. СОБАЧЬЯ КОНУРА С БУДКОЙ И МИСКОЙ (doghouse.glb)
# ---------------------------------------------------------------------------

def build_doghouse():
    kit.reset()
    rnd = random.Random(198302)

    WOOD_A = mat("dog_wood_a", (0.31, 0.25, 0.19), rough=0.90, noise=0.28, wear=0.65, dirt=0.65,
                 wear_col=(0.47, 0.41, 0.34))
    WOOD_B = mat("dog_wood_b", (0.25, 0.20, 0.15), rough=0.92, noise=0.30, wear=0.60, dirt=0.70,
                 wear_col=(0.40, 0.34, 0.27))
    DARK_IN = mat("dog_dark", (0.02, 0.02, 0.025), rough=0.98)
    TARP = mat("dog_tarp", (0.20, 0.23, 0.17), rough=0.94, noise=0.26, wear=0.5, dirt=0.6,
               wear_col=(0.34, 0.35, 0.28))
    IRON = mat("dog_iron", (0.18, 0.17, 0.16), rough=0.65, wear=0.75, dirt=0.6, wear_col=(0.46, 0.27, 0.16))
    BOWL_ENAMEL = mat("dog_bowl", (0.22, 0.33, 0.30), rough=0.40, wear=0.80, dirt=0.5,
                      wear_col=(0.14, 0.12, 0.11))
    ICE = mat("dog_ice", (0.62, 0.74, 0.84), rough=0.18, noise=0.15)
    SNOW = mat("dog_snow", (0.86, 0.90, 0.95), rough=0.86, noise=0.04)

    # 1. Нижние полозья-лежни и дощатый пол
    for sx in (-0.38, 0.38):
        box(f"skid_{sx}", (0.09, 1.18, 0.075), (sx, 0.0, 0.038), WOOD_B, 0.008)
    for i in range(6):
        px = -0.375 + i * 0.15
        box(f"floor_{i}", (0.140, 1.10, 0.032), (px, 0.0, 0.088), WOOD_A if i % 2 == 0 else WOOD_B, 0.004)

    # 2. Внутренняя тёмная коробка (чтобы щели между досками и глубина лаза были черны,
    #    а InsideEyes на (0, 0.28, -0.22) Godot = (0, +0.22, 0.28) Blender светились из темноты!)
    box("inner_back", (0.78, 0.03, 0.68), (0.0, 0.47, 0.44), DARK_IN, 0.0)
    box("inner_L", (0.02, 0.96, 0.68), (-0.40, 0.0, 0.44), DARK_IN, 0.0)
    box("inner_R", (0.02, 0.96, 0.68), (0.40, 0.0, 0.44), DARK_IN, 0.0)

    # 3. Стены из отдельных горизонтальных выветренных досок со щелями 7-10 мм
    for row in range(5):
        z = 0.175 + row * 0.132
        h_b = 0.122
        m_b = WOOD_A if row % 2 == 0 else WOOD_B
        # Левая и правая стены
        for sx in (-0.435, 0.435):
            jit = rnd.uniform(-0.004, 0.004)
            box(f"side_{sx}_{row}", (0.028, 1.06, h_b), (sx + jit, 0.0, z), m_b, 0.004)
        # Задняя глухая стена (+Y Blender = -Z Godot)
        box(f"rear_{row}", (0.88, 0.028, h_b), (0.0, 0.505, z), m_b, 0.004)
        # Фасадная стена (-Y Blender = +Z Godot) с проёмом-лазом шириной 0.40 м и высотой 0.52 м
        if row < 4:
            for sx in (-0.32, 0.32):
                box(f"front_s_{sx}_{row}", (0.24, 0.028, h_b), (sx, -0.505, z), m_b, 0.004)
        else:
            box(f"front_top_{row}", (0.88, 0.028, h_b), (0.0, -0.505, z), m_b, 0.004)

    # Угловые нащельники-стойки и погрызенная обвязка лаза
    for sx in (-0.44, 0.44):
        for sy in (-0.50, 0.50):
            box(f"corner_{sx}_{sy}", (0.055, 0.055, 0.72), (sx, sy, 0.44), WOOD_B, 0.005)
    box("door_jamb_L", (0.04, 0.05, 0.54), (-0.21, -0.51, 0.37), WOOD_B, 0.005)
    box("door_jamb_R", (0.04, 0.05, 0.54), (0.21, -0.51, 0.37), WOOD_B, 0.005)
    box("door_lintel", (0.48, 0.055, 0.055), (0.0, -0.512, 0.65), WOOD_B, 0.005)

    # Фронтонные треугольные доски спереди и сзади
    for sy in (-0.50, 0.50):
        box(f"gable_1_{sy}", (0.64, 0.028, 0.13), (0.0, sy, 0.82), WOOD_A, 0.004)
        box(f"gable_2_{sy}", (0.34, 0.028, 0.12), (0.0, sy, 0.94), WOOD_B, 0.004)

    # 4. Рваный промёрзший брезентовый полог над лазом (прибит гвоздями к перемычке)
    box("tarp_top", (0.44, 0.020, 0.17), (-0.01, -0.542, 0.54), TARP, 0.005, rot=(math.radians(-14), 0, 0))
    box("tarp_flap_L", (0.19, 0.018, 0.21), (-0.12, -0.562, 0.38), TARP, 0.004,
        rot=(math.radians(-9), math.radians(-11), 0))
    box("tarp_flap_R", (0.14, 0.018, 0.14), (0.11, -0.556, 0.42), TARP, 0.004,
        rot=(math.radians(-18), math.radians(16), 0))
    for gx in (-0.18, -0.06, 0.06, 0.18):
        cyl(f"tack_{gx}", 0.006, 0.008, (gx, -0.545, 0.635), IRON, rot=(math.pi * 0.5, 0, 0), verts=6)

    # 5. Двускатная крыша из отдельных досок внахлёст + конёк + снежная шапка
    for sx_s, tilt in ((-1, 32), (1, -32)):
        ang = math.radians(tilt)
        for bi in range(4):
            d = 0.09 + bi * 0.155
            xx = sx_s * d * math.cos(abs(ang))
            zz = 1.07 - d * math.sin(abs(ang))
            box(f"roof_{sx_s}_{bi}", (0.160, 1.32, 0.028), (xx, -0.03, zz),
                WOOD_A if bi % 2 == 0 else WOOD_B, 0.004, rot=(0, ang, 0))
        box(f"roof_snow_{sx_s}", (0.60, 1.24, 0.085), (sx_s * 0.26, -0.02, 0.96), SNOW, 0.028,
            rot=(0, ang, 0))
    box("ridge_cap", (0.11, 1.35, 0.055), (0.0, -0.03, 1.08), WOOD_B, 0.006)
    box("ridge_snow", (0.13, 1.28, 0.06), (0.0, -0.02, 1.115), SNOW, 0.022)
    # Задний сугроб (+Y Blender = -Z Godot)
    sphere("rear_drift", 0.46, (0.0, 0.78, 0.18), SNOW, scale=(1.35, 0.90, 0.58), segs=10, rings=6)

    # 6. Вбитый железный колышек (совпадает с ChainSlack / ChainTaut: Godot (0.56, 0, 0.62) -> Blender (0.56, -0.62, 0))
    cyl("chain_stake", 0.022, 0.29, (0.55, -0.62, 0.145), IRON, rot=(math.radians(4), 0, 0), verts=8, r2=0.018)
    torus("stake_ring", 0.026, 0.006, (0.55, -0.62, 0.215), IRON, rot=(math.radians(78), 0, 0), maj=12, mino=5)

    # 7. Эмалированная миска со сколами и вмёрзшим льдом (Godot (-0.34, 0, 0.78) -> Blender (-0.34, -0.78, 0))
    BX, BY = -0.34, -0.78
    cyl("bowl_outer", 0.105, 0.072, (BX, BY, 0.036), BOWL_ENAMEL, rot=(0, 0, 0), verts=14, r2=0.132)
    torus("bowl_rim", 0.132, 0.007, (BX, BY, 0.072), IRON, rot=(0, 0, 0), maj=14, mino=5)
    cyl("bowl_ice", 0.114, 0.012, (BX, BY, 0.056), ICE, rot=(0, 0, 0), verts=12)

    body, img, tris = kit.finish("doghouse", OUT, res=512, origin="keep", samples=26, ao_min=0.36)
    kit.export(os.path.join(OUT, "doghouse.glb"), os.path.join(OUT, "doghouse.blend"))
    print(f"[OK] doghouse exported: {tris} tris")


# ---------------------------------------------------------------------------
# 3. ПОГРЕБ-ЛЕДНИК (ice_cellar.glb + ice_cellar_lid.glb)
# ---------------------------------------------------------------------------

def _add_earth_snow_mound(name, m_earth, m_snow):
    """Органический низкополигональный земляной бугор погреба-ледника с проплешинами мёрзлой земли и сугробами."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    rnd = random.Random(198303)
    for v in bm.verts:
        p = v.co
        # Срезаем нижнюю часть на Z=0, растягиваем купол назад и по бокам
        p.x *= 1.52
        p.y = p.y * 1.38 + 0.18
        if p.z < 0.0:
            p.z = 0.0
        else:
            p.z = (p.z ** 0.85) * 0.72
            # Выемка спереди-посередине под срубный оголовок люка
            if p.y < 0.65 and abs(p.x) < 0.84:
                p.z *= 0.22
            p.z += rnd.uniform(-0.035, 0.035)
            p.z = max(0.0, p.z)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(m_earth)
    kit.objs.append(obj)

    # Снежные надувы поверх земляного бугра
    drifts = [
        ((-1.05, 0.15, 0.22), (0.62, 1.05, 0.34)),
        ((1.02, 0.05, 0.20), (0.58, 0.98, 0.30)),
        ((0.0, 1.08, 0.28), (1.12, 0.64, 0.40)),
        ((-0.55, 0.82, 0.42), (0.55, 0.48, 0.24)),
        ((0.62, 0.72, 0.38), (0.52, 0.45, 0.22)),
    ]
    for i, (loc, sc) in enumerate(drifts):
        sphere(f"mound_snow_{i}", 1.0, loc, m_snow, scale=sc, segs=10, rings=6)


def build_ice_cellar():
    # --- Часть A: Земляной бугор, срубный оголовок и вытяжная труба (ice_cellar.glb) ---
    kit.reset()

    EARTH = mat("cel_earth", (0.20, 0.17, 0.14), rough=0.95, noise=0.35, noise_scale=28, dirt=0.6)
    SNOW = mat("cel_snow", (0.85, 0.89, 0.94), rough=0.88, noise=0.05)
    LOG_WOOD = mat("cel_log", (0.28, 0.22, 0.16), rough=0.90, noise=0.28, wear=0.65, dirt=0.65,
                   wear_col=(0.44, 0.38, 0.30))
    PLANK_WOOD = mat("cel_plank", (0.33, 0.27, 0.20), rough=0.88, noise=0.25, wear=0.6, dirt=0.55,
                     wear_col=(0.48, 0.42, 0.34))
    IRON = mat("cel_iron", (0.16, 0.17, 0.18), rough=0.60, wear=0.75, dirt=0.5, wear_col=(0.45, 0.26, 0.15))
    DARK_PIT = mat("cel_pit", (0.015, 0.018, 0.022), rough=0.98)

    # 1. Земляной бугор со снежными заносами
    _add_earth_snow_mound("earth_mound", EARTH, SNOW)

    # 2. Срубный оголовок из окорённых брёвен (в Blender: -Y = перед/+Z Godot, +Y = зад/-Z Godot)
    # 3 венца сруба по периметру лаза: X ∈ [-0.74, 0.74], Y ∈ [-0.78, 0.78]
    for tier in range(3):
        z_back = 0.11 + tier * 0.16
        # Задняя стенка выше (3 венца), передняя ниже (1 венец — под наклонный люк)
        cyl(f"log_back_{tier}", 0.088, 1.72, (0.0, 0.78, z_back), LOG_WOOD,
            rot=(0, math.pi * 0.5, 0), verts=8)
        if tier == 0:
            cyl(f"log_front_{tier}", 0.088, 1.72, (0.0, -0.78, 0.11), LOG_WOOD,
                rot=(0, math.pi * 0.5, 0), verts=8)
        # Боковые скошенные брёвна
        for sx in (-0.74, 0.74):
            z_mid = z_back - (0.0 if tier == 0 else tier * 0.08)
            tilt = math.radians(14.0 if tier > 0 else 0.0)
            cyl(f"log_side_{sx}_{tier}", 0.086, 1.74, (sx, 0.0, z_mid), LOG_WOOD,
                rot=(math.pi * 0.5 + tilt, 0, 0), verts=8)

    # Тёмная глубина погреба под люком (видна когда HatchLid приоткрывается ночью!)
    box("cellar_pit_dark", (1.36, 1.44, 0.14), (0.0, 0.0, 0.09), DARK_PIT, 0.0)
    # Проушина на переднем бревне под замок (Y = -0.82, Z = 0.16)
    torus("front_staple", 0.028, 0.007, (0.0, -0.82, 0.16), IRON, rot=(0, math.pi * 0.5, 0), maj=10, mino=5)

    # 3. Деревянная вытяжная труба-короб сзади слева (-0.48, +0.78 Blender = (-0.48, -0.78) Godot)
    VX, VY = -0.48, 0.78
    for dx, dy, sz in [
        (0.0, -0.105, (0.23, 0.024, 1.18)),
        (0.0, 0.105, (0.23, 0.024, 1.18)),
        (-0.105, 0.0, (0.024, 0.21, 1.18)),
        (0.105, 0.0, (0.024, 0.21, 1.18)),
    ]:
        box(f"vent_wall_{dx}_{dy}", sz, (VX + dx, VY + dy, 0.96), PLANK_WOOD, 0.003)
    box("vent_throat", (0.16, 0.16, 0.06), (VX, VY, 1.52), DARK_PIT, 0.0)
    # Стальные стойки и шатровый зонт-дефлектор вытяжки
    for sx in (-0.10, 0.10):
        for sy in (-0.10, 0.10):
            box(f"vent_leg_{sx}_{sy}", (0.018, 0.018, 0.16), (VX + sx, VY + sy, 1.58), IRON, 0.002)
    cyl("vent_hood", 0.24, 0.10, (VX, VY, 1.69), IRON, rot=(0, 0, math.pi * 0.25), verts=4, r2=0.04)
    sphere("vent_snow", 0.17, (VX, VY, 1.72), SNOW, scale=(1.0, 1.0, 0.34), segs=8, rings=4)

    body, img, tris = kit.finish("ice_cellar", OUT, res=512, origin="keep", samples=26, ao_min=0.38)
    kit.export(os.path.join(OUT, "ice_cellar.glb"), os.path.join(OUT, "ice_cellar.blend"))
    print(f"[OK] ice_cellar exported: {tris} tris")

    # --- Часть B: Наклонная дощатая дверь погреба с петлями и навесным замком (ice_cellar_lid.glb) ---
    # Локальный (0,0,0) = линия задних петель (в Godot HatchLid стоит на (0, 0.54, -0.78) с rotation.x = +14°).
    # Крышка уходит вперёд по -Y Блендера (от y=0 до y=-1.56 => в Godot +Z от 0 до +1.56).
    kit.reset()

    LID_A = mat("lid_plank_a", (0.35, 0.29, 0.22), rough=0.88, noise=0.28, wear=0.65, dirt=0.6,
                wear_col=(0.50, 0.44, 0.36))
    LID_B = mat("lid_plank_b", (0.29, 0.24, 0.18), rough=0.90, noise=0.30, wear=0.60, dirt=0.65,
                wear_col=(0.44, 0.38, 0.30))
    LID_IRON = mat("lid_iron", (0.15, 0.16, 0.17), rough=0.55, wear=0.80, dirt=0.5, wear_col=(0.48, 0.28, 0.16))
    LOCK_BODY = mat("lid_lock", (0.18, 0.15, 0.13), rough=0.50, wear=0.85, dirt=0.4, wear_col=(0.56, 0.34, 0.18))
    LID_SNOW = mat("lid_snow", (0.86, 0.90, 0.95), rough=0.88, noise=0.04)

    # 6 отдельных толстых досок с зазорами 8 мм
    for i in range(6):
        lx = -0.60 + i * 0.24
        box(f"lid_board_{i}", (0.228, 1.54, 0.046), (lx, -0.78, 0.0),
            LID_A if i % 2 == 0 else LID_B, 0.005)
    # Подложка под щели снизу
    box("lid_under", (1.36, 1.44, 0.018), (0.0, -0.78, -0.025), LID_B, 0.002)
    # Две массивные поперечные шпонки-стяжки + гвозди
    for ly in (-0.34, -1.24):
        box(f"batten_{ly}", (1.36, 0.105, 0.036), (0.0, ly, 0.038), LID_B, 0.005)
        for i in range(6):
            lx = -0.60 + i * 0.24
            cyl(f"nail_{ly}_{i}", 0.009, 0.008, (lx, ly, 0.058), LID_IRON, rot=(0, 0, 0), verts=6)

    # Кованые амбарные петли у шарнира (y = -0.02 .. -0.44)
    for sx in (-0.48, 0.48):
        box(f"hinge_strap_{sx}", (0.075, 0.44, 0.016), (sx, -0.22, 0.030), LID_IRON, 0.003)
        cyl(f"hinge_pin_{sx}", 0.018, 0.11, (sx, -0.01, 0.024), LID_IRON, rot=(0, math.pi * 0.5, 0), verts=8)

    # Кованое кольцо-ручка подъёма крышки
    box("lift_plate", (0.09, 0.09, 0.012), (0.28, -1.38, 0.028), LID_IRON, 0.003)
    torus("lift_ring", 0.045, 0.009, (0.28, -1.42, 0.034), LID_IRON, rot=(math.radians(15), 0, 0), maj=12, mino=5)

    # Накидная пробойная пластина (накладка) и тяжёлый советский навесной замок спереди по центру
    box("hasp_strap", (0.058, 0.22, 0.014), (0.0, -1.48, 0.030), LID_IRON, 0.003)
    box("hasp_drop", (0.058, 0.016, 0.13), (0.0, -1.585, -0.025), LID_IRON, 0.003)
    # Дужка и корпус замка (амбарный пузатый замок)
    torus("padlock_shackle", 0.024, 0.006, (0.0, -1.60, -0.055), LID_IRON,
          rot=(math.pi * 0.5, 0, 0), maj=12, mino=5)
    box("padlock_body", (0.072, 0.036, 0.088), (0.0, -1.60, -0.108), LOCK_BODY, 0.008)
    cyl("padlock_keyhole", 0.008, 0.006, (0.0, -1.619, -0.112), mat("pk_hole", (0.02, 0.02, 0.02)),
        rot=(math.pi * 0.5, 0, 0), verts=6)

    # Немного наметённого снега в верхней части крышки
    sphere("lid_snow_top", 0.34, (-0.36, -0.32, 0.038), LID_SNOW, scale=(1.1, 0.7, 0.16), segs=8, rings=4)

    body_l, img_l, tris_l = kit.finish("ice_cellar_lid", OUT, res=512, origin="keep", samples=24, ao_min=0.38)
    kit.export(os.path.join(OUT, "ice_cellar_lid.glb"), os.path.join(OUT, "ice_cellar_lid.blend"))
    print(f"[OK] ice_cellar_lid exported: {tris_l} tris")


# ---------------------------------------------------------------------------
# 4. РУССКАЯ ПЕЧЬ ДЛЯ ТАЁЖНОЙ ИЗБЫ (russian_stove.glb)
# ---------------------------------------------------------------------------

def build_russian_stove():
    kit.reset()

    WASH = mat("rs_wash", (0.76, 0.74, 0.69), rough=0.92, noise=0.14, noise_scale=35,
               wear=0.45, dirt=0.42, wear_col=(0.48, 0.25, 0.16))
    BRICK = mat("rs_brick", (0.46, 0.21, 0.13), rough=0.92, noise=0.28, noise_scale=55, dirt=0.5)
    IRON = mat("rs_iron", (0.08, 0.08, 0.085), rough=0.62, noise=0.22, wear=0.65, dirt=0.35,
               wear_col=(0.32, 0.28, 0.25))
    SOOT = mat("rs_soot", (0.03, 0.028, 0.026), rough=0.96)
    WOOD = mat("rs_wood", (0.28, 0.18, 0.11), rough=0.88, noise=0.25)

    # Основание (подпечье), основной массив, лежанка и карниз
    box("plinth", (1.16, 1.36, 0.14), (0, 0, 0.07), BRICK, 0.01)
    box("body", (1.10, 1.30, 0.82), (0, 0, 0.55), WASH, 0.015)
    box("ledge", (1.14, 1.34, 0.06), (0, 0, 0.99), WASH, 0.01)
    box("bed_top", (1.06, 0.96, 0.34), (0, -0.15, 1.18), WASH, 0.015)

    # Ниша подпечья для дров (спереди +Y в старом Props.russian_stove -> устье смотрит в -Z Godot = +Y Blender!)
    # Подогнано под Props.russian_stove() где устье на -Z Godot (= +Y Blender)
    box("wood_niche", (0.62, 0.24, 0.30), (0, 0.56, 0.26), SOOT, 0.0)
    for i, lx in enumerate((-0.18, -0.05, 0.08, 0.19)):
        cyl(f"log_{i}", 0.044, 0.34, (lx, 0.58, 0.17 + (i % 2) * 0.06), WOOD,
            rot=(math.pi * 0.5, 0, math.radians((i - 1.5) * 6)), verts=7)

    # Шесток с чугунной варочной плитой и двумя конфорками
    box("hearth_shelf", (0.96, 0.36, 0.06), (0, 0.52, 0.72), BRICK, 0.008)
    box("cook_plate", (0.62, 0.30, 0.022), (0, 0.54, 0.76), IRON, 0.004)
    for cx, r in ((-0.14, 0.10), (0.14, 0.08)):
        torus(f"ring_{cx}", r, 0.008, (cx, 0.54, 0.774), IRON, rot=(0, 0, 0), maj=16, mino=5)
        cyl(f"lid_{cx}", r * 0.55, 0.010, (cx, 0.54, 0.774), IRON, rot=(0, 0, 0), verts=12)

    # Арочное устье, копоть и чугунная заслонка с ручкой
    box("mouth_dark", (0.50, 0.06, 0.42), (0, 0.635, 1.00), SOOT, 0.0)
    box("damper_plate", (0.44, 0.022, 0.36), (0, 0.655, 0.96), IRON, 0.006)
    tube("damper_handle", [(-0.07, 0.665, 0.96), (-0.07, 0.71, 0.96), (0.07, 0.71, 0.96), (0.07, 0.665, 0.96)],
         0.008, IRON, verts=6)
    box("soot_arch", (0.56, 0.008, 0.18), (0, 0.655, 1.24), SOOT, 0.0)

    # Чугунок на шестке слева
    sphere("chugunok", 0.11, (-0.34, 0.52, 0.85), IRON, scale=(1.0, 1.0, 1.05), segs=12, rings=8)
    torus("chugunok_rim", 0.078, 0.010, (-0.34, 0.52, 0.95), IRON, rot=(0, 0, 0), maj=12, mino=5)

    # Кирпичная труба вверх
    box("chimney", (0.44, 0.44, 1.15), (0.22, 0.25, 1.72), BRICK, 0.01)
    box("chimney_band", (0.49, 0.49, 0.06), (0.22, 0.25, 1.85), WASH, 0.006)

    body, img, tris = kit.finish("russian_stove", OUT, res=512, origin="keep", samples=26, ao_min=0.38)
    kit.export(os.path.join(OUT, "russian_stove.glb"), os.path.join(OUT, "russian_stove.blend"))
    print(f"[OK] russian_stove exported: {tris} tris")


if __name__ == "__main__":
    if want("outpost_stand"):
        build_outpost_stand()
    if want("doghouse"):
        build_doghouse()
    if want("ice_cellar"):
        build_ice_cellar()
    if want("russian_stove"):
        build_russian_stove()
