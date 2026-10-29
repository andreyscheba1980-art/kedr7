# Вещи двора «Кедр-7» (свет улицы): по GLB на вещь, origin «bottom», перед — в −Y Блендера (+Z в игре).
# Запуск: blender --background --factory-startup --python yard_props.py -- <out_dir> [имя ...]
#   woodshed — навес над поленницей: стойки из неошкуренных брёвен, односкатная крыша из досок с шапкой
#              снега и сосульками, поленница колотых чурбаков со светлыми торцами, рассыпанные поленья.
import bpy, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, mat

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "."
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)


def want(name):
    return not ONLY or name in ONLY


def woodshed():
    kit.reset()
    rnd = random.Random(1983)
    bark = mat("ws_bark", (0.2, 0.15, 0.11), rough=0.95, noise=0.45, noise_scale=30, wear=0.3, dirt=0.6)
    plank = mat("ws_plank", (0.33, 0.29, 0.24), rough=0.9, noise=0.35, noise_scale=40, wear=0.5, dirt=0.7, wear_col=(0.45, 0.42, 0.38))
    logm = mat("ws_log", (0.3, 0.21, 0.14), rough=0.95, noise=0.4, noise_scale=35, dirt=0.5)
    endg = mat("ws_end", (0.62, 0.5, 0.34), rough=0.9, noise=0.3, noise_scale=60, dirt=0.4)
    snow = mat("ws_snow", (0.8, 0.84, 0.9), rough=0.75, noise=0.05, noise_scale=5)
    ice = mat("ws_ice", (0.78, 0.86, 0.92), rough=0.15)
    L, D = 3.0, 1.5        # навес: x — длина, y — глубина (в Блендере; −y — перед)
    # стойки: задние выше (скат вперёд)
    for sx in (-1, 1):
        for sy, h in ((-1, 1.95), (1, 2.3)):
            o = cyl("post", 0.075, h, (sx * L / 2, sy * D / 2, h / 2), bark, rot=(0, 0, 0), verts=8)
    # обвязка и стропила
    for sy, h in ((-1, 1.93), (1, 2.28)):
        box("beam", (L + 0.2, 0.1, 0.1), (0, sy * D / 2, h), bark, 0.01)
    tilt = math.atan2(0.35, D)
    for k in range(4):
        x = -L / 2 + k * L / 3
        box("rafter", (0.07, D + 0.5, 0.08), (x, 0, 2.15), bark, 0.006, rot=(-tilt, 0, 0))
    # кровля: доски внахлёст с щелями
    n = 14
    for k in range(n):
        x = -L / 2 - 0.1 + (k + 0.5) * (L + 0.2) / n
        box("roofboard", ((L + 0.2) / n - 0.012, D + 0.55, 0.025), (x, 0, 2.21 + rnd.uniform(-0.006, 0.006)), plank, 0.004, rot=(-tilt, 0, rnd.uniform(-0.01, 0.01)))
    # шапка снега — бугристая, со свесом на переднем краю
    for k in range(6):
        x = -L / 2 + (k + 0.5) * L / 6
        o = kit.sphere("snowcap", 1.0, (x, 0.05, 2.3), snow, scale=(L / 6 * 0.75, D / 2 + 0.25, 0.09 + rnd.uniform(0, 0.04)), segs=12, rings=6)
        o.rotation_euler = (-tilt, 0, 0)
    # сосульки по переднему свесу
    x = -L / 2
    while x < L / 2:
        ln = rnd.uniform(0.06, 0.35)
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.02 + ln * 0.05, radius2=0.0, depth=ln, location=(x, -D / 2 - 0.25, 2.05 - ln / 2), rotation=(math.pi, 0, 0))
        o = bpy.context.object
        o.data.materials.append(ice)
        kit.objs.append(o)
        x += rnd.uniform(0.12, 0.4)
    # поленница: колотые чурбаки (7-гранные, со светлыми торцами), рядами с перевязкой
    rows = 6
    r = 0.075
    for row in range(rows):
        z = 0.1 + r + row * r * 1.75
        cnt = 17 if row % 2 == 0 else 16
        for k in range(cnt):
            x = -1.25 + (k + (0.5 if row % 2 else 0)) * 0.155 + rnd.uniform(-0.01, 0.01)
            rr = r * rnd.uniform(0.85, 1.1)
            ln = 0.55 + rnd.uniform(-0.05, 0.05)
            yo = 0.15 + rnd.uniform(-0.04, 0.04)
            rot = (math.pi / 2, rnd.uniform(0, math.pi), 0)
            cyl("log", rr, ln, (x, yo, z), logm, rot=rot, verts=7)
            for e in (-1, 1):
                cyl("end", rr * 0.92, 0.012, (x, yo + e * (ln / 2 + 0.004), z), endg, rot=rot, verts=7)
    # подкладки под поленницей
    for x in (-1.1, 0, 1.1):
        box("skid", (0.12, 0.8, 0.08), (x, 0.15, 0.04), bark, 0.01)
    # рассыпанные поленья перед навесом и щепа
    for k in range(7):
        x, y = rnd.uniform(-1.3, 1.3), rnd.uniform(-1.4, -0.85)
        rot = (math.pi / 2, 0, rnd.uniform(-1.2, 1.2))
        cyl("loose", 0.07, 0.5, (x, y, 0.07), logm, rot=rot, verts=7)
    for k in range(30):
        box("chip", (rnd.uniform(0.03, 0.08), rnd.uniform(0.02, 0.05), 0.008), (rnd.uniform(-1.6, 1.6), rnd.uniform(-1.8, -0.6), 0.01), endg, 0.0, rot=(0, 0, rnd.uniform(0, 3)))
    obj, img, tris = kit.finish("woodshed", OUT, res=1024, origin="bottom", samples=24)
    kit.export(os.path.join(OUT, "woodshed.glb"), None)
    print("[OK] woodshed: %d tris" % tris)


if want("woodshed"):
    woodshed()
