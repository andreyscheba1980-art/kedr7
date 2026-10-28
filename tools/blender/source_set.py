# «Кедр-7» — капище-источник: PART = chur | larch | otzvuk_box.
#   chur       — чур (идол): тёсаный столб 2.2 м с грубым лицом, «шапкой», зарубками; обгорелый низ
#   larch      — мёртвая лиственница ~9 м, сучья обломаны, на них — вещи пропавших (ушанки, варежки,
#                кружка, планшет), провод-антенна уходит в крону, ленточки
#   otzvuk_box — советский ящик «ОТЗВУК-2»: серый корпус с тремя стрелочными приборами, лампочкой,
#                клеммами; толстые провода уходят в мёрзлую землю
import bpy, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import mat, box, cyl, sphere, tube, torus, text
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
PART = os.environ.get("PART", "chur")
os.makedirs(OUT, exist_ok=True)
kit.reset()
random.seed(11)


def rod(name, a, b, r, m, verts=8, r2=None):
    a, b = Vector(a), Vector(b)
    d = b - a
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    return o


def lumpy(o, amt, sc=4.0):
    for v in o.data.vertices:
        v.co += v.normal * noise.noise(v.co * sc) * amt


SNOW = mat("snow", (0.6, 0.66, 0.74), rough=1.0, noise=0.12, noise_scale=30)
INK = mat("ink", (0.04, 0.04, 0.04), rough=0.9)

if PART == "chur":
    OLD = mat("chur", (0.32, 0.27, 0.21), rough=0.95, noise=0.35, noise_scale=25, wear=0.6, wear_col=(0.46, 0.4, 0.32), dirt=0.8)
    CHAR = mat("char", (0.08, 0.07, 0.06), rough=1.0, noise=0.3, noise_scale=50)
    RED = mat("ochre", (0.42, 0.12, 0.08), rough=1.0, noise=0.2, noise_scale=40)
    post = cyl("post", 0.17, 2.3, (0, 0, 1.05), OLD, rot=(0, 0, 0), verts=10)
    for v in post.data.vertices:
        v.co.x *= 1.0 + noise.noise(v.co * 3.0) * 0.12
        v.co.y *= 1.0 + noise.noise(v.co * 3.0 + Vector((5, 5, 5))) * 0.12
    cyl("char", 0.178, 0.5, (0, 0, 0.15), CHAR, rot=(0, 0, 0), verts=10)
    # Лицо к −Y: надбровье, глубокие глазницы, нос-клин, рот-зарубка
    box("brow", (0.26, 0.06, 0.05), (0, -0.16, 1.88), OLD, 0.01)
    for sx in (-0.07, 0.07):
        sphere(f"eye{sx}", 1.0, (sx, -0.155, 1.8), CHAR, scale=(0.04, 0.03, 0.03), segs=8, rings=5)
    rod("nose", (0, -0.17, 1.82), (0, -0.21, 1.68), 0.03, OLD, 4, r2=0.012)
    box("mouth", (0.14, 0.03, 0.025), (0, -0.165, 1.58), CHAR, 0.004)
    box("mouth_red", (0.15, 0.028, 0.012), (0, -0.168, 1.565), RED, 0.0)
    # «Шапка» — конический навершник
    rod("cap", (0, 0, 2.2), (0, 0, 2.55), 0.21, OLD, 10, r2=0.02)
    sphere("capsnow", 1.0, (0, 0, 2.3), SNOW, scale=(0.2, 0.2, 0.08), segs=10, rings=5)
    for k in range(6):
        box(f"notch{k}", (0.2, 0.03, 0.02), (0, -0.15, 0.6 + k * 0.12), CHAR, 0.0, rot=(0, 0, 0.0))
    m = sphere("mound", 1.0, (0, 0, -0.02), SNOW, scale=(0.45, 0.45, 0.14), segs=12, rings=6)
    lumpy(m, 0.12, 3.0)
    NAME = "chur_post"
elif PART == "larch":
    BARK = mat("larchbark", (0.2, 0.17, 0.14), rough=1.0, noise=0.4, noise_scale=30, wear=0.5, wear_col=(0.38, 0.33, 0.28))
    FUR = mat("fur", (0.24, 0.19, 0.15), rough=1.0, noise=0.4, noise_scale=120)
    WOOL = mat("wool", (0.4, 0.14, 0.1), rough=1.0, noise=0.3, noise_scale=150)
    WOOL2 = mat("wool2", (0.3, 0.32, 0.36), rough=1.0, noise=0.3, noise_scale=150)
    ENAM = mat("enamel", (0.7, 0.68, 0.62), rough=0.4, wear=0.8, wear_col=(0.1, 0.1, 0.1))
    LEATH = mat("leather", (0.22, 0.15, 0.1), rough=0.7, wear=0.5)
    WIRE = mat("wire", (0.1, 0.1, 0.1), rough=0.5)
    RIB = mat("ribbon", (0.6, 0.58, 0.52), rough=1.0)
    RIBR = mat("ribbonr", (0.5, 0.1, 0.08), rough=1.0)
    # Ствол — изогнутый, сужающийся, вершина сломана
    pts = [Vector((0, 0, -0.2)), Vector((0.05, 0.02, 2.0)), Vector((-0.1, 0.06, 4.5)), Vector((0.08, -0.05, 7.0)), Vector((0.0, 0.1, 8.8))]
    rads = [0.42, 0.33, 0.25, 0.17, 0.09]
    for i in range(len(pts) - 1):
        rod(f"trunk{i}", pts[i], pts[i + 1], rads[i], BARK, 10, r2=rads[i + 1])
    # Корневые лапы
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        rod(f"root{k}", (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.3), (math.cos(a) * 1.0, math.sin(a) * 1.0, -0.15), 0.14, BARK, 6, r2=0.04)
    # Обломанные сучья
    hooks = []
    for k in range(9):
        z = 2.2 + k * 0.62
        a = k * 2.2 + random.uniform(-0.3, 0.3)
        base = Vector((0, 0, z))
        ln = random.uniform(0.6, 1.4) * (1.0 - k * 0.06)
        tip = base + Vector((math.cos(a) * ln, math.sin(a) * ln, random.uniform(-0.25, 0.15)))
        rod(f"br{k}", base, tip, 0.07 - k * 0.004, BARK, 6, r2=0.015)
        hooks.append(tip)
    # Вещи пропавших на сучьях (свисают на верёвочках)
    things = ["ushanka", "mitten", "mug", "bag", "ushanka", "mitten2", "ribbon", "ribbonr", "ribbon"]
    for k, t in enumerate(things):
        h = hooks[k]
        hang = h + Vector((0, 0, -0.35))
        rod(f"str{k}", h, hang + Vector((0, 0, 0.08)), 0.006, RIB, 3)
        if t == "ushanka":
            u = sphere(f"ush{k}", 1.0, hang, FUR, scale=(0.13, 0.12, 0.1), segs=10, rings=7)
            lumpy(u, 0.02, 12.0)
        elif t.startswith("mitten"):
            sphere(f"mit{k}", 1.0, hang + Vector((0, 0, -0.05)), WOOL if t == "mitten" else WOOL2, scale=(0.05, 0.035, 0.11), segs=8, rings=6)
        elif t == "mug":
            cyl(f"mug{k}", 0.045, 0.09, hang + Vector((0, 0, -0.05)), ENAM, rot=(0.3, 0, 0), verts=12)
        elif t == "bag":
            box(f"bag{k}", (0.26, 0.07, 0.2), hang + Vector((0, 0, -0.1)), LEATH, 0.02, rot=(0, 0, 0.3))
        else:
            box(f"rib{k}", (0.03, 0.004, 0.5), hang + Vector((0, 0, -0.15)), RIB if t == "ribbon" else RIBR, 0.0, rot=(0.1, 0, k))
    # Провод-антенна: от земли по стволу и в крону
    tube("wire", [Vector((0.42, -0.1, 0.0)), Vector((0.32, -0.12, 1.5)), Vector((0.22, -0.05, 4.0)), Vector((0.12, 0.0, 7.5)), Vector((0.9, 0.4, 8.6))], 0.012, WIRE, 4)
    for k in range(4):
        z = 1.0 + k * 1.8
        torus(f"clamp{k}", 0.34 - k * 0.05, 0.012, (0.02, 0.02, z), WIRE, rot=(0, 0, 0), maj=14, mino=4)
    m = sphere("mound", 1.0, (0, 0, -0.1), SNOW, scale=(1.4, 1.3, 0.25), segs=14, rings=7)
    lumpy(m, 0.2, 2.0)
    NAME = "dead_larch"
else:
    GREY = mat("grey", (0.36, 0.38, 0.37), rough=0.55, noise=0.15, noise_scale=40, wear=0.7, wear_col=(0.42, 0.24, 0.12))
    DARK = mat("dark", (0.07, 0.07, 0.07), rough=0.5)
    DIAL = mat("dial", (0.78, 0.76, 0.68), rough=0.6)
    GLASS = mat("glass", (0.3, 0.32, 0.3), rough=0.1)
    REDL = mat("redlamp", (0.7, 0.08, 0.05), rough=0.3)
    COPPER = mat("copper", (0.5, 0.28, 0.14), rough=0.4, wear=0.4)
    FROST = mat("frost", (0.72, 0.76, 0.8), rough=1.0, noise=0.3, noise_scale=60)
    box("body", (0.8, 0.45, 0.6), (0, 0, 0.4), GREY, 0.012)
    box("feet", (0.86, 0.5, 0.1), (0, 0, 0.05), DARK, 0.006)
    box("panel", (0.72, 0.012, 0.42), (0, -0.226, 0.44), GREY, 0.004)
    for k, x in enumerate((-0.22, 0.0, 0.22)):
        cyl(f"dialrim{k}", 0.075, 0.02, (x, -0.235, 0.52), DARK, verts=16)
        cyl(f"dial{k}", 0.065, 0.006, (x, -0.246, 0.52), DIAL, verts=16)
        rod(f"needle{k}", (x, -0.25, 0.48), (x + 0.04 - k * 0.03, -0.25, 0.56), 0.003, DARK, 3)
        cyl(f"glass{k}", 0.066, 0.003, (x, -0.25, 0.52), GLASS, verts=16)
    cyl("lamp", 0.025, 0.03, (0.28, -0.24, 0.33), REDL, verts=10)
    for k in range(4):
        cyl(f"term{k}", 0.018, 0.04, (-0.25 + k * 0.1, -0.24, 0.3), COPPER, verts=8)
    box("plate", (0.3, 0.004, 0.06), (-0.08, -0.234, 0.68), DIAL, 0.0)
    text("ОТЗВУК-2", 0.035, (-0.08, -0.2365, 0.68), INK)
    text("в/ч 03110", 0.022, (-0.2, -0.2365, 0.22), INK)
    # Толстые кабели — в мёрзлую землю
    for k, sx in enumerate((-0.28, 0.0, 0.28)):
        tube(f"cable{k}", [Vector((sx, 0.2, 0.3)), Vector((sx * 1.1, 0.45, 0.12)), Vector((sx * 1.3, 0.7, -0.1))], 0.03, DARK, 8)
    box("frost_top", (0.82, 0.47, 0.03), (0, 0, 0.715), FROST, 0.01)
    NAME = "otzvuk_box"

body, img, tris = kit.finish(NAME, OUT, res=512, origin="bottom", samples=24, ao_min=0.45)
kit.export(os.path.join(OUT, NAME + ".glb"), os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris)
