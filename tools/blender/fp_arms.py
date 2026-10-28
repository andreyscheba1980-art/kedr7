# «Кедр-7» — руки от первого лица: рукав ватника (вертикальная стёжка каналами, вязаная манжета)
# и шерстяная варежка (большой палец, кожаная накладка, полоска узора на отвороте).
# PART = sleeve | mitten, SIDE = l | r. Координаты — оси узла руки в Godot (fp_hands.gd: _arm):
# Godot (x, y, z) → Блендер (x, −z, y). Запястье — (0, 0, 0.05), локоть — (0.03·s, −0.2, 0.17).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import mat, sphere
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
PART = os.environ.get("PART", "mitten")
SIDE = os.environ.get("SIDE", "r")
s = 1.0 if SIDE == "r" else -1.0
os.makedirs(OUT, exist_ok=True)
kit.reset()


def G(x, y, z):
    return Vector((x, -z, y))


def lathe(name, a, b, radius_fn, m, ring=24, steps=20):
    """Трубка от a до b с радиусом radius_fn(t, θ) — для стёжки, рубчика вязки."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    ax = d.normalized()
    up = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((0, 1, 0))
    u = ax.cross(up).normalized()
    v = ax.cross(u).normalized()
    me = bpy.data.meshes.new(name)
    verts, faces = [], []
    for i in range(steps + 1):
        t = i / steps
        c = a + d * t
        for j in range(ring):
            th = 2 * math.pi * j / ring
            r = radius_fn(t, th)
            verts.append(c + (u * math.cos(th) + v * math.sin(th)) * r)
    for i in range(steps):
        for j in range(ring):
            k0 = i * ring + j
            k1 = i * ring + (j + 1) % ring
            faces.append((k0, k1, k1 + ring, k0 + ring))
    # торцы
    verts.append(a); verts.append(b)
    ca, cb = len(verts) - 2, len(verts) - 1
    for j in range(ring):
        faces.append((ca, (j + 1) % ring, j))
        faces.append((cb, steps * ring + j, steps * ring + (j + 1) % ring))
    me.from_pydata([tuple(p) for p in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    kit.objs.append(o)
    return o


if PART == "sleeve":
    KHAKI = mat("vatnik", (0.2, 0.22, 0.165), rough=0.95, noise=0.22, noise_scale=90, wear=0.25, dirt=0.4,
                wear_col=(0.3, 0.3, 0.24))
    SEAM = mat("seam", (0.1, 0.11, 0.085), rough=1.0)
    RIB = mat("rib", (0.15, 0.14, 0.13), rough=1.0, noise=0.3, noise_scale=140)
    wrist = G(0, 0, 0.05)
    elbow = G(0.03 * s, -0.2, 0.17)
    far = elbow + (elbow - wrist) * 0.35          # уходит за край кадра
    CH = 9                                         # каналов стёжки по окружности
    def r_sleeve(t, th):
        base = 0.047 + 0.016 * t
        quilt = 0.07 * abs(math.sin(th * CH / 2))  # валики между швами
        rumple = noise.noise(Vector((t * 6, math.cos(th) * 2, math.sin(th) * 2))) * 0.08
        return base * (0.93 + quilt + rumple)
    lathe("sleeve", wrist, far, r_sleeve, KHAKI, ring=36, steps=18)
    # вязаная манжета-напульсник из-под рукава
    def r_cuff(t, th):
        return 0.043 * (1.0 + 0.05 * (1 if (int(th / (2 * math.pi) * 40) % 2) else -1))
    lathe("cuff", wrist + (wrist - elbow).normalized() * 0.035, wrist + (elbow - wrist).normalized() * 0.02, r_cuff, RIB, ring=40, steps=3)
    NAME = f"fp_sleeve_{SIDE}"
else:
    WOOL = mat("wool", (0.33, 0.3, 0.27), rough=1.0, noise=0.28, noise_scale=180, wear=0.0)
    LEATHER = mat("leather", (0.2, 0.15, 0.11), rough=0.6, noise=0.2, noise_scale=40, wear=0.6, wear_col=(0.32, 0.26, 0.2))
    STRIPE = mat("stripe", (0.48, 0.12, 0.09), rough=1.0, noise=0.25, noise_scale=180)
    CREAM = mat("cream", (0.7, 0.66, 0.58), rough=1.0, noise=0.2, noise_scale=180)
    # кулак-мешок
    body = sphere("fist", 1.0, G(0, 0, -0.068), WOOL, scale=(0.044, 0.082, 0.05), segs=24, rings=16)
    for vtx in body.data.vertices:
        p = vtx.co
        # к кончику сужение и лёгкий загиб вниз (пальцы сжаты), вязаные «петли» шумом
        k = max(0.0, (-p.y - 0.0) / 0.082)
        vtx.co.x *= 1.0 - 0.18 * k
        vtx.co.z -= 0.012 * k * k
        vtx.co += vtx.normal * noise.noise(p * 260) * 0.0012
    # большой палец
    th = [G(-0.03 * s, 0.012, -0.032), G(-0.046 * s, 0.026, -0.068), G(-0.04 * s, 0.026, -0.098)]
    for i, (a, b) in enumerate(zip(th, th[1:])):
        d = b - a
        bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.019 - i * 0.004, radius2=0.016 - i * 0.004, depth=d.length, location=(a + b) / 2)
        o = bpy.context.object; o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        o.data.materials.append(WOOL); kit.objs.append(o)
    sphere("thumbtip", 0.0125, th[-1], WOOL, segs=12, rings=8)
    sphere("thumbbase", 0.019, th[0], WOOL, segs=12, rings=8)
    # кожаная накладка на ладони (низ кулака)
    sphere("palm", 1.0, G(0, -0.034, -0.07), LEATHER, scale=(0.034, 0.06, 0.012), segs=16, rings=8)
    # отворот: рубчик + красно-белая полоска узора
    def r_turn(t, th_):
        return 0.046 * (1.0 + 0.04 * math.cos(th_ * 20))
    lathe("turn", G(0, 0, 0.004), G(0, 0, 0.04), r_turn, WOOL, ring=40, steps=4)
    lathe("stripe1", G(0, 0, 0.012), G(0, 0, 0.018), lambda t, a: 0.0475, STRIPE, ring=40, steps=1)
    lathe("stripe2", G(0, 0, 0.022), G(0, 0, 0.027), lambda t, a: 0.0475, CREAM, ring=40, steps=1)
    NAME = f"fp_mitten_{SIDE}"

body, img, tris = kit.finish(NAME, OUT, res=512, origin="keep", samples=32, ao_min=0.45)
kit.export(os.path.join(OUT, NAME + ".glb"), os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris)
