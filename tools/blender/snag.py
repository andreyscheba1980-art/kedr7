# «Кедр-7» — обгорелый сломанный ствол-«фигура» (silhouette_stump): издалека — сгорбленный человек.
# Неровный ствол с наплывами и ободранной корой, расщеплённая верхушка-«капюшон», два обломанных сука-«руки»,
# корневые лапы и снежный холмик у основания, шапки снега на «плечах» и «голове». Низ на z = 0.
import bpy, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import mat, sphere
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
random.seed(3)

CHAR = mat("char", (0.09, 0.075, 0.065), rough=0.9, noise=0.35, noise_scale=60, wear=0.35, wear_col=(0.3, 0.22, 0.15), dirt=0.6)
WOOD = mat("splinter", (0.34, 0.26, 0.18), rough=0.9, noise=0.3, noise_scale=80, wear=0.2)
SNOW = mat("snow", (0.56, 0.63, 0.72), rough=1.0, noise=0.15, noise_scale=40)


def obj(name, verts, faces, m):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    kit.objs.append(o)
    return o


def trunk(name, pts, radii, m, ring=10, jag_top=0.0, seed=0.0):
    verts, faces = [], []
    n = len(pts)
    for i, (c, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
        v = d.cross(u).normalized()
        for j in range(ring):
            th = 2 * math.pi * j / ring
            k = 1.0 + noise.noise(Vector((math.cos(th) * 1.5, math.sin(th) * 1.5, i * 0.6 + seed))) * 0.35
            off = (u * math.cos(th) + v * math.sin(th)) * r * k
            p = c + off
            if i == n - 1 and jag_top > 0:
                p = p + d * (random.uniform(-1, 1) * jag_top + (jag_top if j % 3 == 0 else 0))
            verts.append(p)
    for i in range(n - 1):
        for j in range(ring):
            a, b = i * ring + j, i * ring + (j + 1) % ring
            faces.append((a, b, b + ring, a + ring))
    verts.append(pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.02)
    ci = len(verts) - 1
    for j in range(ring):
        faces.append(((n - 1) * ring + j, (n - 1) * ring + (j + 1) % ring, ci))
    return obj(name, verts, faces, m)


# Ствол: сутулый, наклон вперёд к «голове»
spine = [Vector((0, 0, -0.1)), Vector((0.03, 0.0, 0.35)), Vector((0.05, 0.02, 0.75)), Vector((0.0, 0.06, 1.12)),
         Vector((-0.04, 0.13, 1.38)), Vector((-0.02, 0.2, 1.55))]
trunk("trunk", spine, [0.3, 0.24, 0.21, 0.19, 0.17, 0.13], CHAR, ring=12, jag_top=0.07)
# Расщеплённая верхушка: светлая сердцевина-щепа торчит из излома («лицо» под капюшоном)
for k in range(5):
    a = k * 1.3
    base = spine[-1] + Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, -0.04))
    tip = base + Vector((math.cos(a) * 0.04, math.sin(a) * 0.05 + 0.03, 0.12 + random.uniform(0, 0.12)))
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.035, radius2=0.004, depth=(tip - base).length, location=(base + tip) / 2)
    o = bpy.context.object
    o.rotation_euler = (tip - base).to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(WOOD if k % 2 else CHAR); kit.objs.append(o)
# «Капюшон»: перекошенный нарост-шапка с наплывом вперёд
hood = sphere("hood", 1.0, Vector((-0.02, 0.17, 1.6)), CHAR, scale=(0.17, 0.19, 0.13), segs=10, rings=7)
for vtx in hood.data.vertices:
    vtx.co += vtx.normal * noise.noise(vtx.co * 6.0) * 0.25
# Сучья-«руки»: левая опущена, правая — согнута в «локте» и тянется вперёд
trunk("armL", [Vector((-0.12, 0.08, 1.2)), Vector((-0.35, 0.12, 1.02)), Vector((-0.46, 0.22, 0.8))], [0.07, 0.05, 0.025], CHAR, ring=6, jag_top=0.03, seed=4)
trunk("armR", [Vector((0.12, 0.1, 1.18)), Vector((0.34, 0.2, 1.1)), Vector((0.42, 0.42, 1.0)), Vector((0.47, 0.6, 1.05))], [0.07, 0.05, 0.035, 0.018], CHAR, ring=6, jag_top=0.03, seed=8)
# «Пальцы» — обломки сучков на конце правой руки
for k in range(3):
    b = Vector((0.47, 0.6, 1.05))
    t = b + Vector((0.03 * (k - 1), 0.1, -0.04 + 0.04 * k))
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.012, radius2=0.002, depth=(t - b).length, location=(b + t) / 2)
    o = bpy.context.object; o.rotation_euler = (t - b).to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(CHAR); kit.objs.append(o)
# Корневые лапы
for k in range(5):
    a = k * 2 * math.pi / 5 + 0.4
    trunk(f"root{k}", [Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 0.18)), Vector((math.cos(a) * 0.42, math.sin(a) * 0.42, 0.02)),
                       Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, -0.06))], [0.09, 0.06, 0.03], CHAR, ring=6, seed=k * 3)
# Полосы ободранной коры — светлая древесина
for k in range(3):
    z = 0.4 + k * 0.32
    sphere(f"peel{k}", 1.0, Vector((0.17 - k * 0.03, -0.1, z)), WOOD, scale=(0.06, 0.03, 0.14), segs=6, rings=5)
# Снег: холмик у комля, шапки на «голове» и «плечах», на правом суку
mound = sphere("mound", 1.0, Vector((0, 0, 0.0)), SNOW, scale=(0.7, 0.65, 0.12), segs=16, rings=8)
for vtx in mound.data.vertices:
    vtx.co += vtx.normal * noise.noise(vtx.co * 3.0) * 0.12
    vtx.co.z = max(vtx.co.z, -0.02)
sphere("snowhead", 1.0, Vector((-0.02, 0.15, 1.71)), SNOW, scale=(0.15, 0.16, 0.05), segs=10, rings=5)
sphere("snowL", 1.0, Vector((-0.2, 0.1, 1.16)), SNOW, scale=(0.1, 0.07, 0.03), segs=8, rings=4)
sphere("snowR", 1.0, Vector((0.24, 0.15, 1.15)), SNOW, scale=(0.12, 0.07, 0.03), segs=8, rings=4)

NAME = "snag_figure"
body, img, tris = kit.finish(NAME, OUT, res=512, origin="bottom", samples=24, ao_min=0.45)
kit.export(os.path.join(OUT, NAME + ".glb"), os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris)
