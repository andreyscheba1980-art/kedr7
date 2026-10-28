# «Кедр-7» — «Буран» под армейским брезентом, обвязан верёвкой, на брезенте снег. Нос в +Y.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians
TARP = mat("tarp", (0.24, 0.27, 0.19), rough=0.9, noise=0.25, noise_scale=8, wear=0.4, dirt=0.75, wear_col=(0.36, 0.38, 0.3))
ROPE = mat("rope", (0.5, 0.43, 0.3), rough=0.9, noise=0.2)
STEEL = mat("steel", (0.2, 0.21, 0.22), rough=0.4, wear=0.8, dirt=0.6, wear_col=(0.55, 0.56, 0.58))
RUBBER = mat("rubber", (0.05, 0.05, 0.05), rough=0.9, dirt=0.8)
SNOW = mat("snow", (0.88, 0.92, 0.96), rough=0.95)

# Невидимый «скелет» под брезентом: сиденье, капот, стекло, руль
proxy = []
def pbox(size, loc, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.scale = size
    if rot: o.rotation_euler = rot
    proxy.append(o)
pbox((0.95, 1.95, 0.42), (0, -0.55, 0.3))
pbox((0.5, 1.15, 0.2), (0, -0.55, 0.55))
pbox((0.9, 1.0, 0.5), (0, 0.45, 0.5))
pbox((0.88, 0.5, 0.3), (0, 1.0, 0.45), (D(30), 0, 0))
pbox((0.62, 0.05, 0.3), (0, 0.15, 0.9), (D(-38), 0, 0))
pbox((0.8, 0.08, 0.08), (0, -0.05, 1.03))
bpy.ops.object.select_all(action="DESELECT")
for o in proxy: o.select_set(True)
bpy.context.view_layer.objects.active = proxy[0]
bpy.ops.object.join()
hull = bpy.context.object; hull.name = "hull"

# Полотно: подразделённый куб, натянутый на скелет, края свисают и мнутся
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.2, 0.62))
cloth = bpy.context.object; cloth.name = "tarp"
cloth.scale = (1.15, 2.75, 1.0)
bpy.ops.object.transform_apply(scale=True)
sub = cloth.modifiers.new("s", "SUBSURF"); sub.levels = 4; sub.subdivision_type = "SIMPLE"
bpy.ops.object.modifier_apply(modifier="s")
sw = cloth.modifiers.new("w", "SHRINKWRAP"); sw.target = hull; sw.wrap_method = "NEAREST_SURFACEPOINT"; sw.offset = 0.035
bpy.ops.object.modifier_apply(modifier="w")
for v in cloth.data.vertices:
    c = v.co
    n = noise.noise(Vector((c.x * 3.0, c.y * 3.0, c.z * 3.0)))
    if c.z < 0.25:            # подол лежит на снегу, раздаётся вширь
        c.x *= 1.0 + min(0.25 - c.z, 0.2) * 0.4
        c.z = max(c.z, 0.02)
    c.z += n * 0.025
    c.x += n * 0.02
bpy.data.objects.remove(hull)
sm = cloth.modifiers.new("sm", "SMOOTH"); sm.iterations = 12; sm.factor = 0.6
bpy.ops.object.modifier_apply(modifier="sm")
cloth.data.materials.append(TARP); kit.objs.append(cloth)
from mathutils.bvhtree import BVHTree
bpy.context.view_layer.update()
bvh = BVHTree.FromObject(cloth, bpy.context.evaluated_depsgraph_get())
def top(x, y):
    hit = bvh.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))
    return hit[0].z if hit[0] is not None else 0.05
def side(x, y, z):
    d = Vector((-1 if x < 0 else 1, 0, 0))
    hit = bvh.ray_cast(Vector((x * 3.0, y, z)), -d)
    return hit[0].x if hit[0] is not None else x

# Из-под брезента торчат лыжа и задний край гусениц
box("ski", (0.2, 0.7, 0.035), (0, 1.35, 0.02), STEEL, 0.006)
box("ski_tip", (0.2, 0.32, 0.035), (0, 1.8, 0.12), STEEL, 0.006, rot=(D(35), 0, 0))
for sx in (-0.21, 0.21):
    cyl(f"trackend{sx}", 0.15, 0.36, (sx, -1.45, 0.16), RUBBER, rot=(0, D(90), 0), verts=16)
# Верёвки: сечение брезента плоскостью → кольцо по поверхности, чуть наружу
def rope_at(y):
    bm = bmesh.new(); bm.from_mesh(cloth.data)
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, y, 0), plane_no=(0, 1, 0))
    cut = set(e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge))
    for e in [e for e in bm.edges if e not in cut]:
        bm.edges.remove(e)
    for v in [v for v in bm.verts if not v.link_edges]:
        bm.verts.remove(v)
    for v in bm.verts:
        n = Vector((v.co.x, 0, v.co.z - 0.35)).normalized()
        v.co += n * 0.012
        if v.co.z < 0.03: v.co.z = 0.03
    me = bpy.data.meshes.new(f"rope{y}"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(f"rope{y}", me); bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="CURVE")
    o.data.bevel_depth = 0.012; o.data.bevel_resolution = 1
    bpy.ops.object.convert(target="MESH")
    o.data.materials.append(ROPE); kit.objs.append(o)
for y in (-1.0, -0.3, 0.55):
    rope_at(y)
# Снег: верхние грани брезента копией чуть выше, с рваным краем по шуму
bm = bmesh.new(); bm.from_mesh(cloth.data)
bm.normal_update()
kill = [f for f in bm.faces if f.normal.z < 0.8 or noise.noise(f.calc_center_median() * 1.6) < -0.35]
bmesh.ops.delete(bm, geom=kill, context="FACES")
for v in bm.verts:
    v.co.z += 0.012 + max(0.0, noise.noise(v.co * 7.0)) * 0.02
me = bpy.data.meshes.new("snowcap"); bm.to_mesh(me); bm.free()
sn = bpy.data.objects.new("snowcap", me); bpy.context.scene.collection.objects.link(sn)
sn.data.materials.append(SNOW); kit.objs.append(sn)

obj, img, tris = kit.finish("buran_tarp", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "buran_tarp.glb"), os.path.join(OUT, "buran_tarp.blend"))
print("[OK] buran_tarp tris:", tris)
