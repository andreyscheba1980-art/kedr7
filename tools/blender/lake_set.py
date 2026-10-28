# «Кедр-7» — реквизит лодочного сарая на озере. PART:
#   boat   — плоскодонка-дощаник 4.2 м, вверх дном (подвешивается под стропилами), смолёные доски
#   skis   — пара широких охотничьих лыж с камусом и ремнями, стоят у стены
#   tarp   — брезент с провисом и складками, висит на верёвке
#   flares — деревянный ящик сигнальных ракет с красной полосой и трафаретом
# Нос/перёд — +Y в Блендере (−Z в Godot), низ на z = 0 (origin «bottom»).
import bpy, bmesh, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import mat, box, cyl, sphere
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
PART = os.environ.get("PART", "boat")
os.makedirs(OUT, exist_ok=True)
kit.reset()
random.seed(5)


def mesh_obj(name, verts, faces, m):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    kit.objs.append(o)
    return o


def solidify(o, t):
    md = o.modifiers.new("s", "SOLIDIFY")
    md.thickness = t
    md.offset = 0.0


if PART == "boat":
    TAR = mat("tar", (0.16, 0.12, 0.09), rough=0.7, noise=0.3, noise_scale=40, wear=0.5, dirt=0.6, wear_col=(0.42, 0.38, 0.32))
    PAINT = mat("paint", (0.22, 0.32, 0.26), rough=0.9, noise=0.3, noise_scale=30, wear=0.8, wear_col=(0.4, 0.36, 0.3))
    RIB = mat("rib", (0.3, 0.24, 0.17), rough=0.9, noise=0.2, noise_scale=50)
    L, W, H = 4.2, 1.15, 0.46
    N = 22
    # Сечения корпуса: плоское дно, развал бортов; нос (+Y) сходится в штевень, корма — транец
    secs = []
    for i in range(N + 1):
        t = i / N                              # 0 — корма, 1 — нос
        y = -L / 2 + L * t
        bow = max(0.0, (t - 0.55) / 0.45)
        w = W * (0.78 + 0.22 * math.sin(math.pi * min(t / 0.55, 1.0) * 0.5)) * (1.0 - bow ** 1.6 * 0.96)
        h = H + 0.16 * bow ** 2                # нос задран
        zb = 0.0 + 0.14 * bow ** 2             # дно к носу поднимается
        bw = w * 0.62 * (1.0 - bow * 0.9)
        secs.append([Vector((-w / 2, y, h)), Vector((-bw / 2, y, zb)), Vector((bw / 2, y, zb)), Vector((w / 2, y, h))])
    # Обшивка — 3 пояса досок на борт (разный тон: доски), дно
    def strip(name, k0, k1, m):
        verts, faces = [], []
        for i, s in enumerate(secs):
            verts.append(s[k0]); verts.append(s[k1])
        for i in range(N):
            a = i * 2
            faces.append((a, a + 2, a + 3, a + 1))
        o = mesh_obj(name, verts, faces, m)
        solidify(o, 0.025)
        return o
    # пояса борта: делим ребро верх-низ на 3 доски
    for side, (top, bot) in (("L", (0, 1)), ("R", (3, 2))):
        for p in range(3):
            v0, v1 = [], []
            for s in secs:
                a = s[top].lerp(s[bot], p / 3.0)
                b = s[top].lerp(s[bot], (p + 1) / 3.0 - 0.012)
                v0.append(a); v1.append(b)
            verts, faces = [], []
            for i in range(N + 1):
                verts += [v0[i], v1[i]]
            for i in range(N):
                faces.append((i * 2, i * 2 + 2, i * 2 + 3, i * 2 + 1))
            o = mesh_obj(f"plank{side}{p}", verts, faces, PAINT if p == 0 else TAR)
            solidify(o, 0.022)
    strip("bottom", 1, 2, TAR)
    # Транец (корма) и банки-сиденья, шпангоуты внутри
    s0 = secs[0]
    mesh_obj("transom", [s0[0], s0[1], s0[2], s0[3]], [(0, 1, 2, 3)], TAR)
    solidify(kit.objs[-1], 0.03)
    for t in (0.3, 0.62):
        i = int(t * N)
        s = secs[i]
        a = s[0].lerp(s[1], 0.25); b = s[3].lerp(s[2], 0.25)
        box(f"bench{i}", ((b - a).length, 0.22, 0.03), (a + b) / 2, RIB, 0.004)
    for i in range(2, N - 2, 3):
        s = secs[i]
        for k0, k1 in ((0, 1), (1, 2), (2, 3)):
            a, b = s[k0], s[k1]
            d = b - a
            bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
            o = bpy.context.object
            o.scale = (0.035, 0.035, d.length)
            o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
            o.data.materials.append(RIB); kit.objs.append(o)
    # Привальный брус по борту
    for side in (0, 3):
        pts = [s[side] for s in secs]
        for i in range(0, N, 2):
            a, b = pts[i], pts[min(i + 2, N)]
            d = b - a
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.025, depth=d.length, location=(a + b) / 2)
            o = bpy.context.object
            o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
            o.data.materials.append(RIB); kit.objs.append(o)
    NAME = "lake_boat"
elif PART == "skis":
    WOOD = mat("skiwood", (0.42, 0.28, 0.16), rough=0.6, noise=0.25, noise_scale=25, wear=0.6, wear_col=(0.6, 0.5, 0.36))
    FUR = mat("kamus", (0.36, 0.3, 0.24), rough=1.0, noise=0.4, noise_scale=200)
    STRAP = mat("strap", (0.18, 0.11, 0.07), rough=0.7, wear=0.4)
    for sx in (-0.11, 0.11):
        # лыжа стоит почти вертикально у стены: длина по Z, носок загнут к +Y наверху
        verts, faces = [], []
        n = 16
        for i in range(n + 1):
            t = i / n
            z = 0.02 + 1.85 * t
            bend = max(0.0, (t - 0.82) / 0.18)
            y = -0.06 * (1 - t) + 0.16 * bend ** 2
            w = 0.085 * (1.0 - 0.35 * bend)
            verts += [Vector((sx - w, y, z)), Vector((sx + w, y, z))]
        for i in range(n):
            faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
        o = mesh_obj(f"ski{sx}", verts, faces, WOOD)
        solidify(o, 0.022)
        # камус (мех снизу), чуть позади доски
        v2 = [v + Vector((0, -0.016, 0)) for v in verts[:2 * 13]]
        f2 = [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(12)]
        o2 = mesh_obj(f"fur{sx}", v2, f2, FUR)
        solidify(o2, 0.012)
        box(f"strap{sx}", (0.2, 0.05, 0.04), (sx, 0.0, 0.95), STRAP, 0.006)
        box(f"toe{sx}", (0.19, 0.04, 0.025), (sx, 0.01, 1.08), STRAP, 0.006)
    NAME = "lake_skis"
elif PART == "tarp":
    CANVAS = mat("canvas", (0.36, 0.34, 0.24), rough=1.0, noise=0.3, noise_scale=60, wear=0.0, dirt=0.8)
    ROPE = mat("rope", (0.45, 0.4, 0.3), rough=1.0)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=16, y_subdivisions=20, size=1.0)
    o = bpy.context.object
    o.data.materials.append(CANVAS); kit.objs.append(o)
    o.rotation_euler = (math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    for v in o.data.vertices:
        x, z = v.co.x * 1.4, (v.co.z + 0.5) * 2.0          # 1.4 × 2.0 м, верх на z = 2
        sag = math.sin((x / 1.4 + 0.5) * math.pi) * 0.08 * (z / 2.0)
        fold = math.sin(x * 9.0 + z * 0.8) * 0.035 * (1 - z / 2.0) + noise.noise(Vector((x * 2, z * 2, 0.3))) * 0.03
        v.co = Vector((x, fold, z - sag * (1.0 - (z / 2.0))))
    solidify(o, 0.008)
    cyl("rope", 0.012, 1.7, (0, 0.0, 2.02), ROPE, rot=(0, math.pi / 2, 0), verts=6)
    NAME = "lake_tarp"
elif PART == "nets":
    # Вешала для сетей: две наклонные жерди, поперечина, сеть из тонких лент-ниток с провисом,
    # поплавки-берёзовые колобашки сверху, грузила снизу, ком сети на полу.
    POLE = mat("pole", (0.32, 0.25, 0.18), rough=0.9, noise=0.25, noise_scale=40, wear=0.4)
    NET = mat("net", (0.36, 0.37, 0.38), rough=1.0, noise=0.3, noise_scale=80, wear=0.0, dirt=0.3)
    CORK = mat("cork", (0.52, 0.4, 0.26), rough=0.9, noise=0.3, noise_scale=40, wear=0.3)
    LEAD = mat("lead", (0.2, 0.2, 0.21), rough=0.5)
    FROST = mat("frost", (0.6, 0.64, 0.68), rough=1.0, noise=0.3, noise_scale=90)
    from kit import tube
    tube("poleL", [Vector((-1.1, 0.0, 0.0)), Vector((-0.9, 0.0, 2.1))], 0.045, POLE, 6)
    tube("poleR", [Vector((1.1, 0.0, 0.0)), Vector((0.9, 0.0, 2.05))], 0.045, POLE, 6)
    tube("bar", [Vector((-1.05, 0.0, 1.97)), Vector((1.05, 0.0, 1.92))], 0.035, POLE, 6)
    def drape(x, z):
        # провис между точками подвеса (каждые 0.38 м) и волна по глубине
        u = (x + 0.95) / 0.38
        sag = 0.06 * abs(math.sin(u * math.pi)) * (z - 0.45) / 1.45
        return Vector((x, 0.05 * math.sin(z * 4.0 + x * 1.3) + 0.03 * math.sin(x * 7.0), z - sag))
    def ribbon(name, pts, w, m):
        verts, faces = [], []
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            side = d.cross(Vector((0, 1, 0))).normalized() * (w / 2)
            verts += [p - side, p + side]
        for i in range(len(pts) - 1):
            faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
        o = mesh_obj(name, verts, faces, m)
        solidify(o, 0.006)
    top, bot = 1.88, 0.45
    cols = 22
    for i in range(cols + 1):
        x = -0.95 + 1.9 * i / cols
        ribbon(f"nv{i}", [drape(x + 0.02 * math.sin(k), top - (top - bot) * k / 14) for k in range(15)], 0.008, NET)
    for j in range(17):
        z = top - (top - bot) * j / 16
        ribbon(f"nh{j}", [drape(-0.95 + 1.9 * k / 20, z) for k in range(21)], 0.008, NET)
    # иней комками на узлах сети
    random.seed(9)
    for k in range(26):
        x = random.uniform(-0.9, 0.9); z = random.uniform(0.5, 1.8)
        sphere(f"fr{k}", 1.0, drape(x, z), FROST, scale=(0.018, 0.012, 0.014), segs=6, rings=4)
    for i in range(6):
        x = -0.9 + i * 0.36
        sphere(f"cork{i}", 1.0, drape(x, top) + Vector((0, 0.02, 0)), CORK, scale=(0.045, 0.03, 0.035), segs=8, rings=5)
    for i in range(9):
        x = -0.92 + i * 0.23
        cyl(f"lead{i}", 0.012, 0.05, drape(x, bot), LEAD, rot=(0, math.pi / 2, 0), verts=6)
    # ком сетки на полу у правой жерди
    heap = sphere("heap", 1.0, Vector((0.55, 0.15, 0.09)), NET, scale=(0.42, 0.28, 0.11), segs=14, rings=8)
    for v in heap.data.vertices:
        v.co += v.normal * noise.noise(v.co * 7.0) * 0.18
    NAME = "lake_nets"
elif PART == "oars":
    WOOD = mat("oar", (0.4, 0.31, 0.2), rough=0.8, noise=0.25, noise_scale=30, wear=0.6, wear_col=(0.56, 0.48, 0.36))
    PAINT = mat("oarpaint", (0.22, 0.32, 0.26), rough=0.9, wear=0.8, wear_col=(0.4, 0.36, 0.3))
    for k, sx in enumerate((-0.12, 0.12)):
        lean = 0.06 + k * 0.03
        a = Vector((sx, -lean * 0.1, 0.0)); b = Vector((sx + 0.04, lean, 2.3))
        # лопасть снизу
        box(f"blade{k}", (0.15, 0.025, 0.55), a.lerp(b, 0.12), PAINT, 0.004)
        cyl(f"loom{k}", 0.024, 1.75, a.lerp(b, 0.62), WOOD, rot=(-math.atan2(b.y - a.y, b.z - a.z), 0, 0), verts=8)
        cyl(f"grip{k}", 0.019, 0.18, a.lerp(b, 0.98), WOOD, rot=(-math.atan2(b.y - a.y, b.z - a.z), 0, 0), verts=8)
    NAME = "lake_oars"
else:
    BOARD = mat("board", (0.38, 0.3, 0.18), rough=0.8, noise=0.25, noise_scale=30, wear=0.5, wear_col=(0.55, 0.47, 0.33))
    RED = mat("redstripe", (0.55, 0.1, 0.07), rough=0.8, noise=0.2, noise_scale=40, wear=0.6)
    IRON = mat("iron", (0.16, 0.16, 0.17), rough=0.5, wear=0.6)
    INK = mat("ink", (0.05, 0.05, 0.05), rough=0.9)
    box("crate", (0.36, 0.24, 0.2), (0, 0, 0.1), BOARD, 0.006)
    box("lid", (0.37, 0.25, 0.025), (0, 0, 0.212), BOARD, 0.004)
    box("stripe", (0.365, 0.245, 0.04), (0, 0, 0.13), RED, 0.002)
    for sx in (-0.15, 0.15):
        box(f"band{sx}", (0.02, 0.252, 0.205), (sx, 0, 0.105), IRON, 0.002)
    for sy in (-1, 1):
        cyl(f"handle{sy}", 0.008, 0.08, (0, sy * 0.128, 0.16), IRON, rot=(0, math.pi / 2, 0), verts=6)
    kit.text("РАКЕТЫ СИГН.", 0.032, (0, -0.1205, 0.07), INK)
    NAME = "lake_flares"

body, img, tris = kit.finish(NAME, OUT, res=512, origin="bottom", samples=24, ao_min=0.45)
kit.export(os.path.join(OUT, NAME + ".glb"), os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris)
