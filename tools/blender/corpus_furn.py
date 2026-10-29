# «Кедр-7» — обстановка аэрологического корпуса (свет «внутри»): аппаратная, кабинет наблюдателя,
# радиорубка, архив-фотолаборатория, кладовая, тамбур, коридор, газогенераторная, низ башни, кабина.
# Положения — как в tools/blender/corpus.py и scripts/world/meteo_corpus.gd (PULT_POS, BARO_POS, STOVE_POS…).
# Запуск: blender --background --python corpus_furn.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl

OUT = sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
mk = lambda n, c, **k: kit.mat(n, c, **k)
M["desk"] = mk("f_desk", (0.30, 0.20, 0.12), rough=0.7, wear=0.5, dirt=0.3)
M["paper"] = mk("f_paper", (0.75, 0.72, 0.62), rough=0.9)
M["steel"] = mk("f_steel", (0.30, 0.33, 0.32), rough=0.5, wear=0.5, wear_col=(0.5, 0.5, 0.48))
M["panel"] = mk("f_panel", (0.20, 0.26, 0.24), rough=0.6, wear=0.4)
M["dial"] = mk("f_dial", (0.86, 0.83, 0.74), rough=0.5)
M["black"] = mk("f_black", (0.05, 0.05, 0.05), rough=0.6)
M["stove"] = mk("f_stove", (0.09, 0.09, 0.09), rough=0.7, wear=0.6, wear_col=(0.35, 0.2, 0.12))
M["blanket"] = mk("f_blanket", (0.28, 0.12, 0.08), rough=0.95, noise=0.3, noise_scale=30)
M["coat"] = mk("f_coat", (0.34, 0.25, 0.16), rough=0.95, noise=0.3, noise_scale=20)
M["felt"] = mk("f_felt", (0.22, 0.21, 0.2), rough=0.95, noise=0.3, noise_scale=30)
M["folder"] = [mk("f_fold%d" % i, c, rough=0.8, noise=0.2, noise_scale=40) for i, c in enumerate(((0.45, 0.32, 0.18), (0.22, 0.3, 0.42), (0.5, 0.45, 0.32), (0.3, 0.12, 0.1)))]
M["redlamp"] = mk("f_redlamp", (0.7, 0.08, 0.06), rough=0.3)
M["shell"] = mk("f_shell", (0.75, 0.70, 0.55), rough=0.6)
M["gasgen"] = mk("f_gasgen", (0.25, 0.30, 0.28), rough=0.6, wear=0.6, wear_col=(0.45, 0.28, 0.15))
M["coal"] = mk("f_coal", (0.05, 0.05, 0.05), rough=0.9, noise=0.4, noise_scale=40)
M["sack"] = mk("f_sack", (0.45, 0.40, 0.30), rough=0.95, noise=0.3, noise_scale=25)
M["can"] = mk("f_can", (0.55, 0.52, 0.45), rough=0.4, wear=0.5)
M["kero"] = mk("f_kero", (0.35, 0.10, 0.07), rough=0.5, wear=0.5)
M["glassbox"] = mk("f_glassbox", (0.55, 0.62, 0.66), rough=0.15)

FL = 0.45
CAB = 9.75
COL = []


def colbox(c, s, yaw=0.0, tilt=0.0):
    COL.append([round(v, 3) for v in (*c, *s, yaw, tilt)])


def solid(c, s, m, yaw=0.0, col=True):
    box(c, s, m, yaw=yaw)
    if col:
        colbox(c, s, yaw)


def table(x0, x1, z0, z1, h=0.76, y=FL, m=None, col=True):
    m = m or M["desk"]
    box(((x0 + x1) / 2, y + h - 0.02, (z0 + z1) / 2), (x1 - x0, 0.04, z1 - z0), m)
    for x in (x0 + 0.04, x1 - 0.04):
        for z in (z0 + 0.04, z1 - 0.04):
            box((x, y + (h - 0.04) / 2, z), (0.05, h - 0.04, 0.05), m)
    if col:
        colbox(((x0 + x1) / 2, y + h / 2, (z0 + z1) / 2), (x1 - x0, h, z1 - z0))


def chair(x, z, yaw, y=FL):
    box((x, y + 0.45, z), (0.42, 0.04, 0.42), M["desk"], yaw=yaw)
    for dx in (-0.18, 0.18):
        for dz in (-0.18, 0.18):
            cx = x + dx * math.cos(yaw) + dz * math.sin(yaw)
            cz = z - dx * math.sin(yaw) + dz * math.cos(yaw)
            box((cx, y + 0.22, cz), (0.04, 0.45, 0.04), M["desk"])
    bx, bz = x - 0.19 * math.sin(yaw), z - 0.19 * math.cos(yaw)
    box((bx, y + 0.7, bz), (0.42, 0.45, 0.04), M["desk"], yaw=yaw)
    colbox((x, y + 0.35, z), (0.45, 0.7, 0.45), yaw)


def shelf(x0, x1, z0, z1, h, rows, y=FL, fill=None):
    """Стеллаж: стойки и полки; fill(i, x0, x1, z0, z1, y) — что стоит на полке i."""
    for x in (x0, x1):
        for z in (z0, z1):
            box((x, y + h / 2, z), (0.04, h, 0.04), M["steel"])
    for i in range(rows):
        yy = y + 0.12 + i * (h - 0.2) / (rows - 1)
        box(((x0 + x1) / 2, yy, (z0 + z1) / 2), (x1 - x0, 0.025, z1 - z0), M["steel"])
        if fill:
            fill(i, x0, x1, z0, z1, yy + 0.0125)
    colbox(((x0 + x1) / 2, y + h / 2, (z0 + z1) / 2), (x1 - x0, h, z1 - z0))


# --- Аппаратная ---------------------------------------------------------------------------
# Пульт анеморумбометра у северной стены: стойка, наклонная панель с двумя шкалами, самописец сбоку
PX, PZ = 91.7, -33.75
solid((PX, FL + 0.42, PZ), (1.6, 0.84, 0.6), M["panel"])
box((PX, FL + 1.0, PZ - 0.12), (1.6, 0.45, 0.06), M["panel"], yaw=0.0)
box((PX, FL + 0.845, PZ + 0.1), (1.62, 0.02, 0.42), M["black"])     # столешница пульта
chair(PX, PZ + 0.85, math.pi)
# Стол с барографом и термографом у перегородки коридора
BX, BZ = 94.3, -30.0
table(BX - 0.3, BX + 0.3, BZ - 0.8, BZ + 0.8)
# Шкаф с запасными приборами, плакат-схема на стене
solid((90.85, FL + 1.0, -28.95), (0.75, 2.0, 0.55), M["desk"])
box((90.85, FL + 1.0, -28.66), (0.02, 1.9, 0.01), M["black"])
cyl((94.68, FL + 2.35, -29.3), 0.14, 0.04, M["dial"], verts=16, axis="x")

# --- Кабинет наблюдателя -----------------------------------------------------------------
table(90.45, 91.2, -25.0, -23.4)
box((91.0, FL + 0.8, -24.2), (0.3, 0.03, 0.42), M["paper"], yaw=0.1)       # журнал
box((90.7, FL + 0.82, -23.7), (0.12, 0.06, 0.12), M["steel"])               # чернильница/лампа
cyl((90.7, FL + 1.0, -23.7), 0.07, 0.04, M["dial"], verts=10)
chair(91.6, -24.2, -math.pi / 2)
SX, SZ = 91.2, -21.3
cyl((SX, FL + 0.42, SZ), 0.28, 0.6, M["stove"], verts=14)
for a in range(4):
    ang = a * math.pi / 2 + 0.6
    box((SX + math.cos(ang) * 0.2, FL + 0.06, SZ + math.sin(ang) * 0.2), (0.04, 0.12, 0.04), M["stove"])
box((SX + 0.29, FL + 0.38, SZ), (0.02, 0.16, 0.2), M["stove"])
cyl((SX, (FL + 0.72 + 3.6) / 2, SZ), 0.065, 3.6 - FL - 0.72, M["stove"], verts=10)
box((SX + 0.15, FL + 0.01, SZ - 0.1), (0.7, 0.02, 0.6), M["steel"])
cyl((SX + 0.55, FL + 0.17, SZ - 0.45), 0.13, 0.34, M["black"], verts=10)
box((SX + 0.55, FL + 0.33, SZ - 0.45), (0.2, 0.02, 0.2), M["coal"])
colbox((SX, FL + 0.4, SZ), (0.6, 0.8, 0.6))
# Лежанка у южной стены
solid((93.3, FL + 0.22, -20.85), (2.0, 0.44, 0.75), M["desk"])
box((93.3, FL + 0.47, -20.85), (1.9, 0.08, 0.7), M["blanket"], bevel=0.02)
box((92.45, FL + 0.55, -20.85), (0.3, 0.1, 0.5), M["paper"], bevel=0.03)
# Телефон ТА-57 на перегородке
TX, TY, TZ = 94.66, FL + 1.4, -24.6
box((TX, TY, TZ), (0.14, 0.2, 0.28), M["panel"])
box((TX - 0.03, TY + 0.12, TZ), (0.06, 0.05, 0.24), M["black"])
box((TX - 0.02, TY - 0.02, TZ + 0.17), (0.03, 0.08, 0.03), M["black"])

# --- Радиорубка --------------------------------------------------------------------------
solid((98.32, FL + 0.95, -33.0), (0.5, 1.9, 1.6), M["panel"])
for i in range(3):
    for j in range(3):
        cyl((98.06, FL + 0.6 + i * 0.5, -33.5 + j * 0.5), 0.07, 0.02, M["dial"], verts=12, axis="x")
table(96.6, 97.9, -34.05, -33.45)
box((97.2, FL + 0.9, -33.75), (0.6, 0.25, 0.35), M["steel"])
for dx in (-0.15, 0.15):
    cyl((97.2 + dx, FL + 0.9, -33.56), 0.05, 0.02, M["dial"], verts=10, axis="z")
box((96.9, FL + 0.8, -33.65), (0.2, 0.06, 0.15), M["black"])
chair(97.2, -32.9, math.pi)

# --- Архив / фотолаборатория -------------------------------------------------------------


def folders(i, x0, x1, z0, z1, y):
    k = 0
    z = z0 + 0.03
    while z < z1 - 0.1:
        w = 0.07 + 0.03 * ((k * 7) % 3)
        box(((x0 + x1) / 2, y + 0.16, z + w / 2), (x1 - x0 - 0.06, 0.32, w - 0.01), M["folder"][(k + i) % 4])
        z += w
        k += 1
        if k % 9 == 4:
            z += 0.12


shelf(98.2, 98.55, -29.2, -25.3, 2.2, 5, fill=folders)
table(96.6, 97.5, -26.0, -25.15)
for dz in (-0.2, 0.2):
    box((97.05, FL + 0.79, -25.58 + dz), (0.45, 0.03, 0.32), M["black"])
box((96.6, FL + 2.15, -27.2), (0.12, 0.12, 0.12), M["redlamp"])
for k in range(6):
    cyl((96.7 + (k % 3) * 0.25, FL + 0.06 + (k // 3) * 0.12, -28.9), 0.06, 0.4, M["paper"], verts=8, axis="x")

# --- Кладовая ----------------------------------------------------------------------------


M["tin"] = [mk("f_tin%d" % i, c, rough=0.45, wear=0.5) for i, c in enumerate(((0.55, 0.52, 0.45), (0.42, 0.16, 0.12), (0.2, 0.3, 0.22), (0.62, 0.55, 0.3)))]
M["bottle"] = mk("f_bottle", (0.18, 0.24, 0.14), rough=0.2)
M["crate"] = mk("f_crate", (0.42, 0.33, 0.2), rough=0.85, noise=0.35, noise_scale=18)


def stores(i, x0, x1, z0, z1, y):
    """Полка кладовой: тушёнка, сгущёнка, мешки, ящики, бутыли — вперемешку, с пустотами."""
    z = z0 + 0.06
    k = 0
    xc = (x0 + x1) / 2
    while z < z1 - 0.1:
        kind = (k * 7 + i * 3) % 6
        if kind in (0, 1):      # стопка банок
            for h in range(1 + (k + i) % 3):
                cyl((xc + (0.05 if k % 2 else -0.05), y + 0.05 + h * 0.1, z + 0.05), 0.045, 0.095, M["tin"][(k + h + i) % 4], verts=10)
            z += 0.13
        elif kind == 2:         # мешок
            box((xc, y + 0.11, z + 0.13), (0.26, 0.22 - 0.03 * (k % 2), 0.24), M["sack"], bevel=0.05)
            z += 0.28
        elif kind == 3:         # фанерный ящик с маркировкой
            box((xc, y + 0.09, z + 0.11), (0.24, 0.18, 0.2), M["crate"])
            z += 0.24
        elif kind == 4:         # бутыли
            for b in range(2):
                cyl((xc - 0.06 + b * 0.12, y + 0.12, z + 0.05), 0.04, 0.24, M["bottle"], verts=8)
            z += 0.12
        else:                   # пусто — полка не забита
            z += 0.18
        k += 1


shelf(98.2, 98.55, -24.6, -22.3, 1.9, 4, fill=stores)
for k, (x, z) in enumerate(((97.0, -20.85), (97.5, -20.8), (96.85, -21.35))):
    box((x, FL + 0.25, z), (0.45, 0.5, 0.35), M["sack"] if k < 2 else M["coal"], bevel=0.05)
    colbox((x, FL + 0.25, z), (0.45, 0.5, 0.35))
for k in range(5):
    cyl((98.1, FL + 0.08 + k * 0.15, -21.5 + (k % 2) * 0.05), 0.07, 0.7, M["old"], verts=7, axis="z")
colbox((98.1, FL + 0.4, -21.5), (0.4, 0.8, 0.75))
for z in (-23.8, -23.4):
    box((97.0, FL + 0.25, z), (0.18, 0.5, 0.3), M["kero"])
    colbox((97.0, FL + 0.25, z), (0.18, 0.5, 0.3))

# --- Тамбур ------------------------------------------------------------------------------
box((92.0, FL + 1.75, -26.07), (1.6, 0.06, 0.06), M["desk"])
for k, x in enumerate((91.4, 92.0, 92.6)):
    box((x, FL + 1.7, -26.12), (0.04, 0.12, 0.08), M["black"])
    if k != 1:
        box((x, FL + 1.2, -26.2), (0.5, 1.0, 0.18), M["coat"], bevel=0.04)
for x in (91.3, 91.55):
    box((x, FL + 0.2, -26.35), (0.13, 0.4, 0.28), M["felt"])
solid((92.2, FL + 0.22, -28.2), (1.4, 0.44, 0.35), M["desk"])

# --- Коридор: огнетушитель, доска приказов -------------------------------------------------
cyl((96.15, FL + 0.6, -34.0), 0.08, 0.5, M["kero"], verts=10)
box((94.9, FL + 1.55, -29.6), (0.02, 0.6, 0.9), M["desk"])

# --- Газогенераторная ---------------------------------------------------------------------
for x in (101.4, 103.2):
    cyl((x, FL + 1.0, -37.7), 0.45, 2.0, M["gasgen"], verts=16)
    cyl((x, FL + 2.05, -37.7), 0.25, 0.12, M["steel"], verts=12)
    cyl((x + 0.35, FL + 1.3, -37.3), 0.08, 0.04, M["dial"], verts=10, axis="z")
    colbox((x, FL + 1.0, -37.7), (0.9, 2.0, 0.9))
kit.tube("gaspipe", [ugms.g2b((101.4, FL + 2.1, -37.7)), ugms.g2b((101.4, FL + 2.6, -37.7)), ugms.g2b((103.2, FL + 2.6, -37.7)), ugms.g2b((103.2, FL + 2.1, -37.7))], 0.04, M["steel"], 6)
kit.tube("gaspipe2", [ugms.g2b((102.3, FL + 2.6, -37.7)), ugms.g2b((102.3, FL + 2.6, -35.5)), ugms.g2b((104.5, FL + 2.6, -35.5))], 0.035, M["steel"], 6)
table(99.6, 100.6, -38.4, -37.2)
for k in range(3):
    cyl((99.85 + k * 0.3, FL + 0.9, -37.8), 0.1, 0.25, M["can"], verts=8)
for k in range(3):
    box((104.4, FL + 1.6 - k * 0.05, -38.1 + k * 0.7), (0.1, 1.2, 0.55), M["shell"], bevel=0.05)
M["h2"] = mk("f_h2", (0.12, 0.24, 0.16), rough=0.5, wear=0.5, wear_col=(0.4, 0.3, 0.2))
M["h2band"] = mk("f_h2band", (0.6, 0.1, 0.08), rough=0.5)
for row in range(2):
    for k in range(3):
        cx, cy = 100.2 + k * 0.42, FL + 0.18 + row * 0.34
        cyl((cx, cy, -34.6), 0.13, 1.3, M["h2"], verts=12, axis="z")
        cyl((cx, cy, -34.6 + 0.5), 0.135, 0.06, M["h2band"], verts=12, axis="z")
        cyl((cx, cy, -34.6 - 0.7), 0.04, 0.1, M["steel"], verts=8, axis="z")
for x in (99.95, 101.35):
    box((x, FL + 0.35, -34.6), (0.05, 0.7, 1.2), M["steel"])
colbox((100.6, FL + 0.35, -34.6), (1.5, 0.7, 1.3))

# --- Низ башни: пожарный щит --------------------------------------------------------------
box((94.92, FL + 1.3, -36.0), (0.03, 1.0, 1.4), M["red"])
for k in range(3):
    box((94.96, FL + 1.1 + k * 0.25, -36.3 + k * 0.3), (0.04, 0.05, 0.5), M["black"])

# --- Кабина: стол с журналом шаров и секундомером, табурет ---------------------------------------
table(94.95, 95.75, -38.55, -37.75, y=CAB)
box((95.35, CAB + 0.79, -38.15), (0.3, 0.02, 0.4), M["paper"])
cyl((95.6, CAB + 0.8, -37.9), 0.03, 0.02, M["dial"], verts=10)
solid((95.6, CAB + 0.22, -37.3), (0.35, 0.44, 0.35), M["desk"])

obj, img, tris = kit.finish("corpus_furn", OUT, res=2048, origin="keep", samples=24, pack=0.002, ao_blur=2)
kit.export(os.path.join(OUT, "corpus_furn.glb"), None)
lo = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "data", "corpus_col_furn.gd")
with open(dst, "w", encoding="utf8") as f:
    f.write("# Сгенерировано tools/blender/corpus_furn.py — коллизии обстановки корпуса. Не править руками.\n")
    f.write("# Коробка: [cx, cy, cz, sx, sy, sz, yaw, tilt_x] в координатах игры.\n")
    f.write("const BOXES := [\n")
    for b in COL:
        f.write("\t[%s],\n" % ", ".join("%.3f" % v for v in b))
    f.write("]\n")
print("[OK] corpus_furn: %d tris, низ %.3f, коллизий %d" % (tris, lo, len(COL)))
