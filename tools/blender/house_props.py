# Вещи дома «Кедр-7» (свет «внутри»): по GLB на вещь, origin «bottom», перед — в −Y Блендера (+Z в игре).
# Запуск: blender --background --factory-startup --python house_props.py -- <out_dir> [имя ...]
#   bragin_chest — старый деревянный сундук Брагина (1961) на люке в подпол: доски, кованые полосы,
#                  выпуклая крышка, замочная накладка, ручки-скобы, стёртые углы.
import bpy, math, sys, os, random
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


def attic_junk():
    """Чердачный хлам в координатах игры (origin «keep»): вдоль скатов, проход посередине свободен."""
    import ugms
    from ugms import box as gbox, cyl as gcyl
    kit.reset()
    rnd = random.Random(1970)
    A = 2.93                                         # настил чердака
    paper = mat("aj_paper", (0.62, 0.58, 0.48), rough=0.95, noise=0.3, noise_scale=40, dirt=0.6)
    twine = mat("aj_twine", (0.5, 0.42, 0.28), rough=0.95)
    wood = mat("aj_wood", (0.3, 0.2, 0.13), rough=0.85, noise=0.3, noise_scale=40, wear=0.5, dirt=0.6)
    leather = mat("aj_leather", (0.24, 0.15, 0.1), rough=0.6, wear=0.7, dirt=0.5, wear_col=(0.4, 0.3, 0.22))
    rug = mat("aj_rug", (0.36, 0.12, 0.1), rough=0.95, noise=0.4, noise_scale=20, dirt=0.6)
    broom = mat("aj_broom", (0.34, 0.33, 0.2), rough=0.95, noise=0.4, noise_scale=30)
    linen = mat("aj_linen", (0.7, 0.66, 0.56), rough=0.9, noise=0.2, noise_scale=10, dirt=0.7)
    glass = mat("aj_glass", (0.2, 0.26, 0.16), rough=0.2)
    iron = mat("aj_iron", (0.16, 0.15, 0.14), rough=0.6, wear=0.6, wear_col=(0.38, 0.25, 0.16))
    # связки газет под бечёвкой
    for (x, z, n) in ((0.2, 1.0, 3), (3.1, 5.6, 2), (9.0, 5.7, 2)):
        for k in range(n):
            y = A + 0.07 + k * 0.14
            gbox((x + rnd.uniform(-0.03, 0.03), y, z), (0.42, 0.13, 0.32), paper, yaw=rnd.uniform(-0.2, 0.2), bevel=0.01)
            gbox((x, y, z), (0.44, 0.135, 0.012), twine, yaw=0.0)
    # рулон ковра вдоль ската
    gcyl((4.6, A + 0.12, 5.55), 0.12, 1.7, rug, verts=12, axis="x")
    # стопка чемоданов
    for k, (w, h) in enumerate(((0.62, 0.2), (0.55, 0.18), (0.48, 0.16))):
        y = A + 0.1 + sum(hh for _, hh in ((0.62, 0.2), (0.55, 0.18), (0.48, 0.16))[:k]) + h / 2 - 0.1
        gbox((-1.6, y, 5.2), (w, h, 0.36), leather, yaw=0.1 * k, bevel=0.02)
        gbox((-1.6, y + h / 2 + 0.01, 5.2 - 0.1), (0.12, 0.03, 0.03), iron)
    # сломанный стул на боку
    gbox((8.4, A + 0.22, 1.2), (0.42, 0.42, 0.04), wood, tilt_x=1.4, yaw=0.3)
    gbox((8.4, A + 0.04, 1.4), (0.4, 0.04, 0.4), wood, yaw=0.3)
    for k in range(3):
        gbox((8.2 + k * 0.2, A + 0.03, 1.0 + k * 0.05), (0.04, 0.04, 0.45), wood, yaw=0.3 + k * 0.2)
    # ящик с пустыми бутылями
    gbox((7.4, A + 0.12, 5.6), (0.5, 0.24, 0.36), wood, bevel=0.01)
    for k in range(6):
        gcyl((7.24 + (k % 3) * 0.16, A + 0.3, 5.52 + (k // 3) * 0.16), 0.05, 0.3, glass, verts=8)
    # веники на стропилах
    for k in range(4):
        x = 2.2 + k * 0.3
        gcyl((x, A + 1.45, 3.3), 0.006, 0.4, twine, verts=4)
        gcyl((x, A + 1.05, 3.3), 0.09, 0.45, broom, verts=8, r2=0.03)
    # лыжи и палки на балке у ската
    for k in range(2):
        gbox((10.2, A + 0.62 + k * 0.03, 1.3 + k * 0.12), (1.9, 0.02, 0.07), wood, tilt_z=0.04)
    # портновский манекен в дальнем углу: стойка, торс под простынёй
    gcyl((13.6, A + 0.35, 4.9), 0.02, 0.7, iron, verts=6)
    gcyl((13.6, A + 0.03, 4.9), 0.18, 0.04, iron, verts=10)
    o = kit.sphere(ugms._nm("torso"), 1.0, ugms.g2b((13.6, A + 1.0, 4.9)), linen, scale=ugms.gsize((0.2, 0.32, 0.15)), segs=14, rings=10)
    gcyl((13.6, A + 0.78, 4.9), 0.24, 0.5, linen, verts=12, r2=0.17)
    # люлька на очепе у восточного фронтона
    gcyl((13.4, A + 1.75, 3.3), 0.012, 0.9, twine, verts=4)
    gbox((13.4, A + 1.12, 3.3), (0.75, 0.24, 0.42), wood, bevel=0.02)
    gbox((13.4, A + 1.06, 3.3), (0.7, 0.04, 0.38), linen)
    obj, img, tris = kit.finish("attic_junk", OUT, res=1024, origin="keep", samples=24, pack=0.003)
    kit.export(os.path.join(OUT, "attic_junk.glb"), None)
    print("[OK] attic_junk: %d tris" % tris)


if want("bragin_chest"):
    bragin_chest()
if want("attic_junk"):
    attic_junk()
