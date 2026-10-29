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


def helipad_kit():
    """Обвязка вертолётной площадки (центр — в нуле): колдун на мачте, побелённые шины по кругу
    (запад — проход), сигнальные фонари на столбиках, бочки с ручной помпой, табличка."""
    kit.reset()
    rnd = random.Random(44)
    white = mat("hp_white", (0.82, 0.82, 0.78), rough=0.8, wear=0.6, dirt=0.6, wear_col=(0.2, 0.2, 0.2))
    rubber = mat("hp_rubber", (0.1, 0.1, 0.1), rough=0.85)
    orange = mat("hp_orange", (0.85, 0.36, 0.08), rough=0.85, noise=0.2, noise_scale=10, dirt=0.4)
    pole = mat("hp_pole", (0.3, 0.3, 0.29), rough=0.6, wear=0.6, wear_col=(0.42, 0.28, 0.17))
    glass = mat("hp_glass", (0.65, 0.42, 0.18), rough=0.2)
    drum = mat("hp_drum", (0.16, 0.24, 0.16), rough=0.6, wear=0.7, dirt=0.6, wear_col=(0.42, 0.28, 0.15))
    snow = mat("hp_snow", (0.8, 0.84, 0.9), rough=0.75)
    # Blender: x — вправо (x игры), y — назад (−z игры). Хелпер — позиция в осях игры.
    G = lambda x, y, z: (x, -z, y)
    # шины по кругу, полузакопаны, белые с облезлостью
    for k in range(12):
        a = k * math.pi * 2 / 12
        if abs(math.cos(a) + 1) < 0.15:
            continue                               # запад — подход по лееру
        x, z = math.cos(a) * 5.8, math.sin(a) * 5.8
        bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.11, major_segments=14, minor_segments=7, location=G(x, 0.08, z), rotation=(0, 0, 0))
        o = bpy.context.object
        o.data.materials.append(white if k % 2 == 0 else rubber)
        kit.objs.append(o)
        kit.sphere("tsnow", 1.0, G(x, 0.13, z), snow, scale=(0.26, 0.26, 0.05), segs=10, rings=5)
    # колдун: мачта с растяжками и полосатый конус, обвисший от мороза
    mx, mz = 6.8, -6.8
    cyl("mast", 0.05, 6.0, G(mx, 3.0, mz), pole, rot=(0, 0, 0), verts=8)
    box("ring", (0.3, 0.3, 0.03), G(mx, 5.9, mz), pole, 0.01)
    for k in range(5):
        r1 = 0.28 - k * 0.04
        r2 = 0.24 - k * 0.04
        y = 5.9 - 0.35 * k - 0.15
        cyl("sock%d" % k, r1, 0.4, G(mx + 0.18 + k * 0.08, y, mz), orange if k % 2 == 0 else white, rot=(math.radians(15), 0, 0), verts=12, r2=r2)
    for a in (0.3, 2.4, 4.4):
        kit.tube("guy", [G(mx, 4.5, mz), G(mx + math.cos(a) * 2.2, 0.05, mz + math.sin(a) * 2.2)], 0.008, pole, 4)
    # сигнальные фонари по углам: столбик, жёлтый колпак
    for (x, z) in ((-5.2, -5.2), (5.2, -5.2), (-5.2, 5.2), (5.2, 5.2)):
        cyl("lpost", 0.04, 0.6, G(x, 0.3, z), pole, rot=(0, 0, 0), verts=6)
        cyl("lcap", 0.07, 0.12, G(x, 0.66, z), glass, rot=(0, 0, 0), verts=10)
        cyl("lhat", 0.08, 0.03, G(x, 0.73, z), pole, rot=(0, 0, 0), verts=10)
    # бочки авиатоплива с ручной помпой, сложены на поддоне (юго-запад, в стороне от подхода)
    bx, bz = -7.2, 4.0
    box("pallet", (1.7, 1.1, 0.12), G(bx, 0.06, bz), mat("hp_wood", (0.34, 0.27, 0.2), rough=0.9, noise=0.3, noise_scale=30), 0.01)
    for k, (dx, dz) in enumerate(((-0.45, -0.25), (0.15, -0.25), (-0.15, 0.3), (0.45, 0.3))):
        cyl("drum", 0.29, 0.88, G(bx + dx, 0.56, bz + dz), drum, rot=(0, 0, 0), verts=14)
        for yy in (0.36, 0.76):
            cyl("hoop", 0.295, 0.025, G(bx + dx, yy, bz + dz), pole, rot=(0, 0, 0), verts=14)
        if k != 2:
            kit.sphere("dsnow", 1.0, G(bx + dx, 1.0, bz + dz), snow, scale=(0.27, 0.27, 0.05), segs=10, rings=5)
    cyl("pump", 0.03, 0.9, G(bx - 0.45, 1.3, bz - 0.25), pole, rot=(0, 0, 0), verts=6)
    box("pumph", (0.35, 0.04, 0.04), G(bx - 0.3, 1.72, bz - 0.25), pole, 0.005)
    kit.tube("phose", [G(bx - 0.45, 1.2, bz - 0.25), G(bx - 0.8, 0.6, bz - 0.5), G(bx - 1.0, 0.05, bz - 0.9)], 0.018, rubber, 6)
    obj, img, tris = kit.finish("helipad_kit", OUT, res=1024, origin="keep", samples=24, pack=0.003)
    kit.export(os.path.join(OUT, "helipad_kit.glb"), None)
    print("[OK] helipad_kit: %d tris" % tris)


def izba_interior():
    """Изба внутри (в осях сруба: ноль — центр, +x — к сеням, +z — к югу): русская печь устьем к входу,
    нары, полка с банками и лампой, шкурки и капканы, снегоступы, ведро, туески, чугунок с ухватом."""
    kit.reset()
    rnd = random.Random(1937)
    G = lambda x, y, z: (x, -z, y)
    wash = mat("iz_wash", (0.7, 0.68, 0.62), rough=0.95, noise=0.35, noise_scale=18, wear=0.7, dirt=0.9, wear_col=(0.42, 0.25, 0.17))
    soot = mat("iz_soot", (0.07, 0.06, 0.05), rough=0.95, noise=0.4, noise_scale=12)
    brick = mat("iz_brick", (0.42, 0.22, 0.15), rough=0.9, noise=0.4, noise_scale=25, dirt=0.6)
    iron = mat("iz_iron", (0.13, 0.12, 0.11), rough=0.6, wear=0.6, wear_col=(0.35, 0.22, 0.14))
    plank = mat("iz_plank", (0.3, 0.22, 0.15), rough=0.9, noise=0.35, noise_scale=35, wear=0.5, dirt=0.7)
    fur = mat("iz_fur", (0.32, 0.24, 0.16), rough=1.0, noise=0.5, noise_scale=60)
    fur2 = mat("iz_fur2", (0.5, 0.45, 0.38), rough=1.0, noise=0.5, noise_scale=60)
    rag = mat("iz_rag", (0.36, 0.3, 0.26), rough=1.0, noise=0.4, noise_scale=20, dirt=0.7)
    glass = mat("iz_glass", (0.3, 0.33, 0.2), rough=0.2)
    bark = mat("iz_bark", (0.62, 0.55, 0.42), rough=0.9, noise=0.4, noise_scale=40)
    # --- русская печь: центр (−0.8, −1.6), устье смотрит на +x ---
    sx, sz = -0.8, -1.6
    box("podpech", (1.3, 0.6, 1.4), G(sx, 0.3, sz), wash, 0.02)
    box("podpech_arch", (0.04, 0.32, 0.5), G(sx + 0.66, 0.24, sz), soot, 0.01)
    box("body", (1.26, 0.72, 1.36), G(sx, 0.96, sz), wash, 0.03)
    box("shestok", (0.34, 0.06, 0.62), G(sx + 0.78, 0.66, sz), wash, 0.01)
    box("ustye", (0.04, 0.38, 0.44), G(sx + 0.645, 0.86, sz), soot, 0.01)
    cyl("ustye_arch", 0.22, 0.04, G(sx + 0.645, 1.04, sz), soot, rot=(0, math.pi / 2, 0), verts=12)
    box("lezhanka", (1.3, 0.1, 1.4), G(sx, 1.37, sz), wash, 0.03)
    for k in range(2):     # печурки-ниши
        box("pechurka", (0.04, 0.14, 0.16), G(sx + 0.645, 0.48, sz - 0.4 + k * 0.8), soot)
    box("chimney", (0.42, 1.4, 0.42), G(sx - 0.3, 2.1, sz - 0.4), brick, 0.01)
    for k in range(5):     # копоть над устьем и трещины в побелке
        box("crack", (0.006, rnd.uniform(0.15, 0.4), 0.01), G(sx + 0.64, rnd.uniform(0.7, 1.25), sz + rnd.uniform(-0.6, 0.6)), soot, rot=(rnd.uniform(-0.6, 0.6), 0, 0))
    box("sootmark", (0.005, 0.35, 0.6), G(sx + 0.646, 1.2, sz), soot)
    cyl("chugun", 0.13, 0.18, G(sx + 0.8, 0.79, sz + 0.12), iron, rot=(0, 0, 0), verts=12, r2=0.1)
    kit.tube("uhvat", [G(sx + 1.0, 0.05, sz + 0.6), G(sx + 0.75, 1.4, sz + 0.62)], 0.015, plank, 5)
    kit.tube("uhvat_h", [G(sx + 0.72, 1.45, sz + 0.52), G(sx + 0.75, 1.42, sz + 0.62), G(sx + 0.72, 1.45, sz + 0.72)], 0.012, iron, 5)
    # --- нары у северной стены (восточная часть) ---
    box("nary", (2.4, 0.06, 0.85), G(1.6, 0.5, -2.5), plank, 0.01)
    for x in (0.5, 2.7):
        for z in (-2.85, -2.15):
            box("naryleg", (0.08, 0.5, 0.08), G(x, 0.25, z), plank)
    box("ovchina", (1.5, 0.08, 0.7), G(1.9, 0.57, -2.5), fur2, 0.03)
    box("tryap", (0.6, 0.12, 0.5), G(0.9, 0.59, -2.5), rag, 0.04)
    # --- полка на восточной стене у двери: банки, лампа-коптилка ---
    box("shelf", (0.25, 0.03, 1.1), G(2.98, 1.55, 1.9), plank)
    for z in (1.5, 2.3):
        box("shelfbr", (0.2, 0.15, 0.03), G(3.0, 1.47, z), plank)
    for k in range(4):
        cyl("jar", 0.05, 0.14 + 0.03 * (k % 2), G(2.98, 1.64, 1.5 + k * 0.17), glass, rot=(0, 0, 0), verts=8)
    cyl("lamp", 0.06, 0.08, G(2.98, 1.6, 2.3), iron, rot=(0, 0, 0), verts=8)
    cyl("lampglass", 0.04, 0.12, G(2.98, 1.7, 2.3), glass, rot=(0, 0, 0), verts=8)
    # --- шкурки и капканы на западной стене, снегоступы ---
    for k in range(3):
        z = 0.6 + k * 0.45
        box("pelt%d" % k, (0.03, 0.55 - 0.08 * k, 0.28), G(-3.05, 1.7 - 0.05 * k, z), fur if k != 1 else fur2, 0.02)
        box("peg", (0.06, 0.03, 0.03), G(-3.05, 2.0, z), plank)
    for k in range(2):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.012, major_segments=10, minor_segments=4, location=G(-3.06, 1.35, 2.15 + k * 0.3), rotation=(0, math.pi / 2, 0))
        o = bpy.context.object
        o.data.materials.append(iron)
        kit.objs.append(o)
    for k in range(2):
        o = kit.sphere("snowshoe", 1.0, G(-3.04, 0.75, -0.15 + k * 0.32), plank, scale=(0.02, 0.15, 0.45), segs=10, rings=6)
    # --- пол: ведро, туески, щепа у печи ---
    cyl("bucket", 0.14, 0.28, G(0.2, 0.14, -0.9), iron, rot=(0, 0, 0), verts=12, r2=0.12)
    for k in range(3):
        cyl("tues", 0.08 + 0.02 * k, 0.16, G(-0.2 + k * 0.2, 0.08, -2.75), bark, rot=(0, 0, 0), verts=10)
    for k in range(12):
        box("chip", (rnd.uniform(0.04, 0.1), rnd.uniform(0.02, 0.04), 0.008), G(rnd.uniform(-0.1, 0.6), 0.005, rnd.uniform(-2.1, -1.0)), bark, rot=(0, 0, rnd.uniform(0, 3)))
    obj, img, tris = kit.finish("izba_interior", OUT, res=1024, origin="keep", samples=24, pack=0.003)
    kit.export(os.path.join(OUT, "izba_interior.glb"), None)
    print("[OK] izba_interior: %d tris" % tris)


if want("woodshed"):
    woodshed()
if want("izba_interior"):
    izba_interior()
if want("helipad_kit"):
    helipad_kit()
