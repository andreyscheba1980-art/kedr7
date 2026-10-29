# Вещи дома «Кедр-7» (свет «внутри»): по GLB на вещь, origin «bottom», перед — в −Y Блендера (+Z в игре).
# Запуск: blender --background --factory-startup --python house_props.py -- <out_dir> [имя ...]
#   bragin_chest — старый деревянный сундук Брагина (1961) на люке в подпол: доски, кованые полосы,
#                  выпуклая крышка, замочная накладка, ручки-скобы, стёртые углы.
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, tube, mat

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "."
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)


def want(name):
    return not ONLY or name in ONLY


def bragin_chest():
    kit.reset()
    wood = mat("ch_wood", (0.30, 0.19, 0.11), rough=0.85, noise=0.3, noise_scale=40, wear=0.6, dirt=0.6, wear_col=(0.45, 0.33, 0.22))
    plank = mat("ch_plank", (0.26, 0.16, 0.09), rough=0.85, noise=0.35, noise_scale=55, wear=0.5, dirt=0.6, wear_col=(0.42, 0.3, 0.2))
    iron = mat("ch_iron", (0.12, 0.11, 0.1), rough=0.6, noise=0.25, noise_scale=80, wear=0.9, dirt=0.4, wear_col=(0.36, 0.26, 0.18))
    brass = mat("ch_brass", (0.5, 0.4, 0.2), rough=0.4, wear=0.7, dirt=0.4, wear_col=(0.72, 0.6, 0.34))
    W, D, H = 0.92, 0.52, 0.42     # ящик
    # Короб: доски вдоль, щели между ними
    for k in range(4):
        z = 0.05 + k * (H - 0.06) / 4 + (H - 0.06) / 8
        for y in (-D / 2 + 0.012, D / 2 - 0.012):
            box("pf%d_%s" % (k, y), (W - 0.02, 0.024, (H - 0.06) / 4 - 0.006), (0, y, z), plank, 0.004)
        for x in (-W / 2 + 0.012, W / 2 - 0.012):
            box("ps%d_%s" % (k, x), (0.024, D - 0.04, (H - 0.06) / 4 - 0.006), (x, 0, z), plank, 0.004)
    box("inner", (W - 0.05, D - 0.05, H - 0.04), (0, 0, H / 2), mat("ch_dark", (0.06, 0.04, 0.03)), 0.0)
    box("bottom", (W + 0.02, D + 0.02, 0.05), (0, 0, 0.025), wood, 0.006)
    # Выпуклая крышка: пять досок по дуге
    for k in range(5):
        a = (k - 2) * 0.22
        r = 0.36
        y = math.sin(a) * r
        z = H + 0.02 + (math.cos(a) * r - r * 0.86)
        box("lid%d" % k, (W + 0.03, 0.115, 0.028), (0, y, z), wood, 0.005, rot=(a, 0, 0))
    for x in (-W / 2 - 0.006, W / 2 + 0.006):
        box("lidend_%s" % x, (0.02, D + 0.02, 0.07), (x, 0, H + 0.035), wood, 0.004)
    # Кованые полосы через крышку и короб
    for x in (-0.3, 0.0, 0.3):
        box("bandf_%s" % x, (0.045, 0.008, H), (x, -D / 2 - 0.006, H / 2), iron, 0.002)
        box("bandb_%s" % x, (0.045, 0.008, H), (x, D / 2 + 0.006, H / 2), iron, 0.002)
        for k in range(5):
            a = (k - 2) * 0.22
            y = math.sin(a) * 0.37
            z = H + 0.03 + (math.cos(a) * 0.37 - 0.37 * 0.86)
            box("bandl_%s_%d" % (x, k), (0.047, 0.12, 0.008), (x, y, z), iron, 0.002, rot=(a, 0, 0))
        for zz in (0.08, H - 0.08):   # заклёпки
            cyl("rv_%s_%s" % (x, zz), 0.008, 0.006, (x, -D / 2 - 0.011, zz), iron, rot=(math.pi / 2, 0, 0), verts=8)
    # Окованные углы
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("corner_%d_%d" % (sx, sy), (0.07, 0.07, 0.07), (sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), 0.045), iron, 0.006)
    # Замочная накладка и проушина
    box("lockplate", (0.1, 0.01, 0.13), (0, -D / 2 - 0.012, H - 0.05), brass, 0.004)
    cyl("keyhole", 0.008, 0.012, (0, -D / 2 - 0.018, H - 0.045), mat("ch_hole", (0.02, 0.02, 0.02)), rot=(math.pi / 2, 0, 0), verts=8)
    tube("hasp", [(-0.02, -D / 2 - 0.02, H + 0.02), (0, -D / 2 - 0.035, H + 0.04), (0.02, -D / 2 - 0.02, H + 0.02)], 0.006, iron, 6)
    # Ручки-скобы по бокам
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.02)
        tube("handle_%d" % sx, [(x, -0.08, H * 0.62), (x + sx * 0.03, -0.07, H * 0.55), (x + sx * 0.03, 0.07, H * 0.55), (x, 0.08, H * 0.62)], 0.009, iron, 6)
        for y in (-0.08, 0.08):
            box("hm_%d_%s" % (sx, y), (0.012, 0.03, 0.05), (sx * (W / 2 + 0.008), y, H * 0.62), iron, 0.002)
    obj, img, tris = kit.finish("bragin_chest", OUT, res=1024, origin="bottom", samples=32)
    kit.export(os.path.join(OUT, "bragin_chest.glb"), None)
    print("[OK] bragin_chest: %d tris" % tris)


if want("bragin_chest"):
    bragin_chest()
