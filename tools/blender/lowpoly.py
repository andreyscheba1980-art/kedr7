# Лоупольные версии моделей «Кедр-7» в духе PS1: простые коробки и 6–10-гранные цилиндры,
# а вся мелочь (ручки, шкалы, надписи, гвозди, кирпичи) запекается с хайполи в текстуру 64–256 px.
# Хайполи берутся из out/<имя>.blend (их делают r250.py, vesna.py и т. д.), результат — out_lo/<имя>.glb.
# Координаты прокси — те же, что в скриптах хайполи (Блендер: Z вверх, перед в −Y); для моделей,
# которые kit.finish центрировал (origin="bottom"), сдвиг SHIFT вычитается.
# Запуск: python3 lowpoly.py [имя ...]   (без имён — все)
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out")
DST = os.path.join(HERE, "out_lo")
os.makedirs(DST, exist_ok=True)


class P:
    """Сборщик прокси на bmesh. smooth — грани, которые сглаживать (бока цилиндров)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.smooth = set()

    def _mat(self, loc, rot, scale=(1, 1, 1)):
        return Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))

    def box(self, size, loc, rot=(0, 0, 0), drop=()):
        before = set(self.bm.faces)
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._mat(loc, rot, size))
        new = [f for f in self.bm.faces if f not in before]
        if drop:
            dirs = {"-z": (0, 0, -1), "+z": (0, 0, 1), "-y": (0, -1, 0), "+y": (0, 1, 0), "-x": (-1, 0, 0), "+x": (1, 0, 0)}
            kill = []
            for f in new:
                f.normal_update()
                for d in drop:
                    if f.normal.dot(Vector(dirs[d])) > 0.99:
                        kill.append(f)
            bmesh.ops.delete(self.bm, geom=kill, context="FACES")
        return self

    def cyl(self, r, depth, loc, rot=(math.pi / 2, 0, 0), verts=8, r2=None, caps=True, smooth=None):
        before = set(self.bm.faces)
        bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=verts, radius1=r,
                              radius2=r if r2 is None else r2, depth=depth, matrix=self._mat(loc, rot))
        if smooth is None:
            smooth = verts >= 6
        if smooth:
            for f in self.bm.faces:
                if f not in before and len(f.verts) == 4:
                    self.smooth.add(f)
        return self

    def beam(self, a, b, r, sides=4, caps=False):
        a, b = Vector(a), Vector(b)
        d = b - a
        q = d.to_track_quat("Z", "Y")
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        before = set(self.bm.faces)
        bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=sides, radius1=r, radius2=r,
                              depth=d.length, matrix=m)
        if sides >= 6:
            for f in self.bm.faces:
                if f not in before and len(f.verts) == 4:
                    self.smooth.add(f)
        return self

    def path(self, pts, r, sides=4):
        for a, b in zip(pts, pts[1:]):
            self.beam(a, b, r, sides)
        return self

    def lathe(self, prof, c, verts=8):
        """Тело вращения вокруг вертикали через c=(x, y): prof — [(r, z), ...] снизу вверх, крышки сверху и снизу."""
        rings = []
        for r, z in prof:
            ring = []
            for i in range(verts):
                a = 2 * math.pi * i / verts
                ring.append(self.bm.verts.new((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r, z)))
            rings.append(ring)
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(verts):
                j = (i + 1) % verts
                self.smooth.add(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
        self.bm.faces.new(list(reversed(rings[0])))
        self.bm.faces.new(rings[-1])
        return self

    def sphere(self, r, loc, scale=(1, 1, 1), segs=8, rings=5):
        before = set(self.bm.faces)
        bmesh.ops.create_uvsphere(self.bm, u_segments=segs, v_segments=rings, radius=r,
                                  matrix=self._mat(loc, (0, 0, 0), scale))
        for f in self.bm.faces:
            if f not in before:
                self.smooth.add(f)
        return self

    def to_object(self, name, shift=(0, 0, 0)):
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(shift))
        for f in self.bm.faces:
            f.smooth = f in self.smooth
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        # Острые рёбра между плоскими гранями и на стыке «гладкий бок — плоская крышка»
        for e in me.edges:
            e.use_edge_sharp = False
        me.update()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        bm = bmesh.new(); bm.from_mesh(me)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                f1, f2 = e.link_faces
                if not (f1.smooth and f2.smooth) or f1.normal.angle(f2.normal, 0) > math.radians(50):
                    e.smooth = False
        bm.to_mesh(me); bm.free()
        return ob


def tris_of(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def weight_islands(ob, front):
    """Важным граням — больше пикселей: остров UV масштабируется по направлению его граней
    (лицевая сторона ×2 по площади, верх ×1, бока ×0.7, тыл и низ ×0.35), потом острова пакуются заново."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    uv = bm.loops.layers.uv.active
    parent = {f.index: f.index for f in bm.faces}
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        f1, f2 = e.link_faces
        ok = True
        for v in e.verts:
            u1 = [l[uv].uv for l in f1.loops if l.vert == v][0]
            u2 = [l[uv].uv for l in f2.loops if l.vert == v][0]
            if (u1 - u2).length > 1e-5:
                ok = False
        if ok:
            parent[find(f1.index)] = find(f2.index)
    islands = {}
    for f in bm.faces:
        islands.setdefault(find(f.index), []).append(f)
    fr = Vector(front).normalized() if front else None
    for faces in islands.values():
        n = Vector((0, 0, 0))
        for f in faces:
            n += f.normal * f.calc_area()
        n = n.normalized() if n.length > 0 else Vector((0, 0, 1))
        if fr is not None and n.dot(fr) > 0.6:
            w = 2.0
        elif fr is not None and n.dot(fr) < -0.6:
            w = 0.35
        elif n.z > 0.6:
            w = 1.0
        elif n.z < -0.6:
            w = 0.35
        else:
            w = 0.7
        k = math.sqrt(w)
        loops = [l for f in faces for l in f.loops]
        c = sum((l[uv].uv for l in loops), Vector((0, 0))) / len(loops)
        for l in loops:
            l[uv].uv = c + (l[uv].uv - c) * k
    bm.to_mesh(me); bm.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(name, build, res=256, shift=(0, 0, 0), extr=0.02, dist=0.05, margin=2, front=(0, -1, 0)):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, name + ".blend"))
    hi = [o for o in bpy.data.objects if o.type == "MESH"]
    assert len(hi) == 1, [o.name for o in hi]
    hi = hi[0]
    p = P()
    build(p)
    lo = p.to_object(name + "_lo", shift)
    # UV
    bpy.ops.object.select_all(action="DESELECT")
    lo.select_set(True); bpy.context.view_layer.objects.active = lo
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=0.03)
    bpy.ops.object.mode_set(mode="OBJECT")
    weight_islands(lo, front)
    img = bpy.data.images.new(name + "_lo", res, res)
    mat = bpy.data.materials.new(name + "_lo"); mat.use_nodes = True
    tn = mat.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = img
    tn.interpolation = "Linear"   # как у остальных текстур дома: без крупных пикселей
    mat.node_tree.links.new(tn.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    mat.node_tree.nodes.active = tn
    lo.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 4
    bk = sc.render.bake
    bk.use_pass_direct = False; bk.use_pass_indirect = False; bk.use_pass_color = True
    bk.use_selected_to_active = True; bk.use_cage = False
    bk.cage_extrusion = extr; bk.max_ray_distance = dist; bk.margin = margin
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type="DIFFUSE")
    img.filepath_raw = os.path.join(DST, name + ".png"); img.file_format = "PNG"; img.save()
    img.pack()
    bpy.ops.object.select_all(action="DESELECT")
    lo.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(DST, name + ".glb"), export_format="GLB",
                              use_selection=True, export_image_format="AUTO")
    nt_lo, nt_hi = tris_of(lo), tris_of(hi)
    bpy.data.objects.remove(hi)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DST, name + "_lo.blend"))
    print(f"LO {name}: {nt_lo} tris (hi {nt_hi}), tex {res}px")


# ---------------------------------------------------------------- прокси --------------------

def r250(p):
    W, D, H = 0.9, 0.36, 0.42
    FY = -D / 2
    SX, SZ = -0.17, H * 0.66
    p.box((W, D, H), (0, 0, H / 2), drop=("-z",))
    p.box((0.38, 0.012, 0.13), (SX, FY - 0.004, SZ), drop=("+y",))
    for mx in (0.14, 0.31):
        p.cyl(0.052, 0.016, (mx, FY - 0.006, SZ), verts=8)
    p.cyl(0.055, 0.04, (SX + 0.02, FY - 0.02, H * 0.27), verts=8)
    for i in range(4):
        p.cyl(0.02, 0.03, (0.02 + i * 0.09, FY - 0.015, H * 0.27), verts=6)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.018)
        for z in (H * 0.78, H * 0.22):
            p.box((0.016, 0.044, 0.016), (x, FY - 0.022, z), drop=("+y",))
        p.box((0.016, 0.016, H * 0.56 + 0.016), (x, FY - 0.04, H / 2))


def vesna(p):
    W, D, H = 0.36, 0.24, 0.09
    FY, TOP = -D / 2, H
    CX, CYc = -0.08, 0.012
    p.box((W, D, H), (0, 0, H / 2), drop=("-z",))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.cyl(0.012, 0.006, (sx * 0.15, sy * 0.095, -0.002), rot=(0, 0, 0), verts=4, smooth=False)
    p.box((0.156, 0.11, 0.012), (CX, CYc, TOP + 0.006), drop=("-z",))
    for i, x in enumerate((0.05, 0.11)):
        p.cyl(0.014, 0.018, (x, 0.085, TOP + 0.009), rot=(0, 0, 0), verts=6, r2=0.011)
    for b in range(6):
        p.box((0.021, 0.03, 0.01), (-0.135 + b * 0.025, FY + 0.016, TOP + 0.003), drop=("-z",))
    by = -FY
    for sx in (-1, 1):
        p.box((0.012, 0.03, 0.024), (sx * 0.165, by + 0.012, 0.06))
    p.box((0.32, 0.01, 0.01), (0, by + 0.034, 0.064))


def barograph(p):
    AX, DX, R = -0.08, 0.08, 0.046
    HX, HY, Z0, Z1 = 0.158, 0.078, 0.036, 0.186
    p.box((0.34, 0.18, 0.035), (0, 0, 0.0175), drop=("-z",))
    # стопка анероидных коробок — токарный профиль: широкие «таблетки» и узкие перемычки
    prof = [(0.03, 0.035)]
    for b in range(5):
        z = 0.05 + b * 0.0145
        prof += [(0.038, z), (0.013, z + 0.0068)]
    p.lathe(prof, (AX, 0), verts=8)
    p.cyl(0.006, 0.02, (AX, 0, 0.13), rot=(0, 0, 0), verts=4, smooth=False)
    p.box((0.012, 0.012, 0.085), (-0.02, 0.03, 0.077))
    p.box((0.075, 0.008, 0.008), (-0.05, 0.03, 0.12))
    p.path([(-0.02, 0.03, 0.105), (0.006, 0.014, 0.099), (0.0325, -0.002, 0.092)], 0.002, 3)
    p.cyl(R + 0.0015, 0.124, (DX, 0, 0.092), rot=(0, 0, 0), verts=10)
    p.cyl(0.02, 0.018, (DX, 0, 0.162), rot=(0, 0, 0), verts=6)
    for sy in (-1, 1):
        p.box((HX * 2, 0.005, 0.006), (0, sy * HY, Z0 + 0.003))
        p.box((HX * 2, 0.005, 0.005), (0, sy * HY, Z1))
    for sx in (-1, 1):
        p.box((0.005, HY * 2, 0.006), (sx * HX, 0, Z0 + 0.003))
        p.box((0.005, HY * 2, 0.005), (sx * HX, 0, Z1))
        for sy in (-1, 1):
            p.box((0.005, 0.005, Z1 - Z0), (sx * HX, sy * HY, (Z0 + Z1) / 2))
        p.box((0.007, 0.009, 0.012), (sx * (HX + 0.004), 0, Z0 + 0.008))
    p.box((0.05, 0.016, 0.004), (0, 0, Z1 + 0.003))
    p.path([(-0.02, 0, Z1 + 0.004), (-0.016, 0, Z1 + 0.014), (0.016, 0, Z1 + 0.014), (0.02, 0, Z1 + 0.004)], 0.003, 4)


def stove(p):
    FY, TZ, CEIL = -0.45, 0.5, 2.8
    p.box((0.98, 0.98, 0.16), (0, 0, 0.08), drop=("-z",))
    p.box((0.9, 0.9, 1.0), (0, 0, 0.66), drop=("-z",))
    p.box((0.96, 0.96, 0.085), (0, 0, 1.1975))
    p.box((0.62, 0.46, 0.024), (0, -0.12, 1.25), drop=("-z",))
    p.box((0.46, 0.02, 0.32), (0, FY - 0.006, TZ), drop=("+y",))
    a = math.radians(110)
    p.box((0.2, 0.024, 0.24), (-0.23 - 0.1 * math.cos(a), FY - 0.012 - 0.1 * math.sin(a), TZ), rot=(0, 0, a))
    p.box((0.3, 0.02, 0.12), (0, FY - 0.008, 0.24), drop=("+y",))
    p.box((0.7, 0.4, 0.004), (0, FY - 0.25, 0.002), drop=("-z",))
    p.box((0.38, 0.38, CEIL - 1.24), (0, 0.25, 1.24 + (CEIL - 1.24) / 2), drop=("-z", "+z"))
    p.box((0.42, 0.42, 0.05), (0, 0.25, 2.2))
    p.box((0.08, 0.06, 0.02), (0.14, 0.25 - 0.22, 1.95))
    p.beam((0.5, -0.32, 0.02), (0.53, -0.3, 0.99), 0.008, 4)
    p.beam((0.5, -0.32, 0.02), (0.47, -0.36, 0.05), 0.008, 4)
    for x, y, rz in ((0.58, 0.12, 10), (0.6, 0.28, -14)):
        p.cyl(0.045, 0.34, (x, y, 0.05), rot=(math.pi / 2, 0, math.radians(rz)), verts=6)


def generator(p):
    PY = 0.27
    for sx in (-0.45, 0.45):
        p.box((0.08, 0.7, 0.07), (sx, 0, 0.035), drop=("-z",))
    for sy in (-0.22, 0.22):
        p.box((0.98, 0.06, 0.05), (0, sy, 0.095))
    p.box((0.5, 0.36, 0.002), (-0.1, 0.0, 0.001), drop=("-z",))
    p.box((0.55, 0.46, 0.26), (-0.15, 0, 0.25))
    p.box((0.36, 0.34, 0.2), (-0.2, 0, 0.47))
    p.box((0.36, 0.34, 0.185), (-0.2, 0, 0.67))
    for i in range(4):                       # рёбра охлаждения — четыре настоящих, остальное текстурой
        p.box((0.42, 0.4, 0.01), (-0.2, 0, 0.586 + i * 0.055))
    p.box((0.3, 0.28, 0.05), (-0.2, 0, 0.79))
    for sx in (-0.4, 0.1):
        p.box((0.03, 0.3, 0.14), (sx, 0, 0.83))
    p.box((0.62, 0.34, 0.16), (-0.15, 0, 0.96))
    p.cyl(0.04, 0.03, (-0.3, 0.05, 1.05), rot=(0, 0, 0), verts=6)
    p.cyl(0.19, 0.34, (0.32, 0, 0.32), rot=(0, math.pi / 2, 0), verts=10)
    p.box((0.1, 0.3, 0.3), (0.12, 0, 0.32))
    p.cyl(0.07, 0.1, (-0.2, 0.22, 0.62), verts=6)
    p.cyl(0.12, 0.06, (-0.45, 0, 0.36), rot=(0, math.pi / 2, 0), verts=8)
    p.box((0.32, 0.06, 0.22), (0.3, PY - 0.03, 0.56))
    p.box((0.04, 0.04, 0.3), (0.3, PY - 0.07, 0.36))
    p.path([(0.42, PY - 0.03, 0.5), (0.5, 0.2, 0.4), (0.55, 0.1, 0.06), (0.62, -0.3, 0.02)], 0.012, 4)
    p.path([(-0.42, -0.1, 0.45), (-0.5, -0.25, 0.6), (-0.5, -0.3, 1.6)], 0.035, 6)
    p.cyl(0.06, 0.22, (-0.5, -0.27, 0.85), rot=(0, 0, 0), verts=6)


def front_door(p):
    W, H, T = 1.0, 2.0, 0.08
    p.box((T, W, H), (0, 0, 0))
    p.box((0.018, W - 0.04, H - 0.04), (T / 2 + 0.009, 0, 0), drop=("-x",))
    for z in (-0.72, 0.72):
        p.box((0.024, W - 0.08, 0.11), (-T / 2 - 0.012, 0, z), drop=("+x",))
        p.cyl(0.018, 0.12, (-T / 2 + 0.01, W / 2 + 0.01, z), rot=(0, 0, 0), verts=6)
    ang = math.atan2(1.44 - 0.11, W - 0.14)
    p.box((0.024, math.hypot(W - 0.14, 1.44 - 0.11), 0.1), (-T / 2 - 0.012, 0, 0), rot=(-ang, 0, 0), drop=("+x",))
    HY = -0.38
    for sx in (-1, 1):
        x0 = sx * (T / 2 + (0.024 if sx > 0 else 0.026))
        p.path([(x0, HY, 0.12), (x0 + sx * 0.05, HY, 0.1), (x0 + sx * 0.05, HY, -0.1), (x0, HY, -0.12)], 0.01, 4)
    p.box((0.016, 0.36, 0.034), (-T / 2 - 0.042, -0.3, 0.12))


def zhuchok(p):
    CY = 0.06
    p.sphere(1.0, (0, CY, 0), scale=(0.031, 0.063, 0.037), segs=10, rings=7)
    for v in p.bm.verts:
        if v.co.z < -0.022:
            v.co.z = -0.022 + (v.co.z + 0.022) * 0.35
    p.cyl(0.0285, 0.03, (0, 0.115, 0.004), rot=(-math.pi / 2, 0, 0), verts=12, r2=0.0275)
    p.box((0.016, 0.014, 0.012), (0, 0.105, -0.027))
    p.box((0.004, 0.02, 0.02), (0, -0.004, 0.0))
    p.path([(0, -0.013, -0.002), (0.003, -0.022, -0.012), (-0.002, -0.028, -0.026), (0.003, -0.03, -0.045)], 0.0025, 3)


def zhuchok_lever(p):
    p.path([(0, 0, 0), (0, -0.05, -0.006), (0, -0.1, -0.004)], 0.005, 4)
    p.cyl(0.005, 0.016, (0, 0, 0), rot=(0, math.pi / 2, 0), verts=6)
    p.box((0.023, 0.072, 0.007), (0, -0.06, -0.009))


def mast(p):
    H, BW, TW, SEG = 16.0, 0.65, 0.28, 1.6
    hw = lambda z: (BW + (TW - BW) * z / H) / 2
    segs = int(H / SEG)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.beam((sx * hw(0), sy * hw(0), 0), (sx * hw(H), sy * hw(H), H), 0.034, 4)
            p.box((0.14, 0.14, 0.02), (sx * BW / 2, sy * BW / 2, 0.01), drop=("-z",))
    for s in range(segs):
        z0, z1 = s * SEG, (s + 1) * SEG
        w0, w1 = hw(z0), hw(z1)
        c0 = [(-w0, -w0), (w0, -w0), (w0, w0), (-w0, w0)]
        c1 = [(-w1, -w1), (w1, -w1), (w1, w1), (-w1, w1)]
        for f in range(4):
            a0, b0 = c0[f], c0[(f + 1) % 4]
            a1, b1 = c1[f], c1[(f + 1) % 4]
            p.beam((*a0, z0), (*b0, z0), 0.02, 3)
            p.beam((*a0, z0), (*b1, z1), 0.016, 3)
            p.beam((*b0, z0), (*a1, z1), 0.016, 3)
    LY = -1
    for sx in (-0.15, 0.15):
        a = (sx * (hw(0.3) / 0.325) * 0.6, LY * (hw(0.3) + 0.07), 0.3)
        b = (sx * (hw(H - 0.6) / 0.325) * 0.6, LY * (hw(H - 0.6) + 0.07), H - 0.6)
        p.beam(a, b, 0.014, 3)
    r, z = 0, 0.45
    while z < H - 0.8:
        w = hw(z); k = (w / 0.325) * 0.6
        p.beam((-0.15 * k, LY * (w + 0.07), z), (0.15 * k, LY * (w + 0.07), z), 0.012, 3)
        if z > 2.5 and r % 3 == 0:
            arc = [(math.cos(math.pi * i / 4) * 0.26 * k, LY * (w + 0.07 + math.sin(math.pi * i / 4) * 0.32), z) for i in range(5)]
            p.path(arc, 0.012, 3)
        z += 0.32; r += 1
    PZ = H - 0.9
    pw = hw(PZ) + 0.35
    p.box((pw * 2, pw * 2, 0.06), (0, 0, PZ + 0.01))
    corners = [(-pw, -pw), (pw, -pw), (pw, pw), (-pw, pw)]
    for i in range(16):
        t = i / 16 * 4; side = int(t); u = t - side
        a, b = corners[side], corners[(side + 1) % 4]
        x, y = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
        p.beam((x, y, PZ), (x, y, PZ + 0.9), 0.016, 3)
    for zz in (PZ + 0.45, PZ + 0.9):
        p.path([(-pw, -pw, zz), (pw, -pw, zz), (pw, pw, zz), (-pw, pw, zz), (-pw, -pw, zz)], 0.018, 3)
    p.box((TW * 1.3, TW * 1.3, 0.05), (0, 0, H))
    p.cyl(0.08, 0.22, (0, 0, H + 0.16), rot=(0, 0, 0), verts=6)
    p.beam((0, 0, H + 0.27), (0, 0, H + 1.4), 0.014, 3)
    for zz, L in ((12.2, 1.6), (14.2, 1.2)):
        w = hw(zz)
        for sx in (-1, 1):
            x = sx * (w + 0.6)
            p.beam((sx * w, 0, zz), (x, 0, zz), 0.022, 3)
            p.beam((x, -L / 2 - 0.06, zz), (x, L / 2 + 0.06, zz), 0.016, 3)
    fp = []
    for i in range(12):
        zz = 0.6 + i * (H - 1.2) / 11
        w = hw(zz)
        fp.append((w + 0.05, w + 0.05, zz))
    p.path(fp, 0.018, 3)
    p.box((0.01, 0.3, 0.2), (BW / 2 + 0.035, 0, 1.5))


JOBS = {
    "radio_mast16": (mast, dict(res=512, extr=0.025, dist=0.06, front=None)),
    "r250": (r250, dict(res=512, shift=(0, -0.0275, 0), extr=0.03, dist=0.07)),
    "vesna306": (vesna, dict(res=512, shift=(0.002, 0.018878, -0.005), extr=0.012, dist=0.03, front=(0, 0, 1))),
    "barograph_m22": (barograph, dict(res=512, shift=(0, -0.00105, 0), extr=0.01, dist=0.025)),
    "stove_brick": (stove, dict(res=1024, extr=0.03, dist=0.08)),
    "generator_ab4": (generator, dict(res=1024, extr=0.03, dist=0.08, front=(0, 1, 0))),
    "front_door": (front_door, dict(res=1024, extr=0.02, dist=0.05, front=None)),
    "zhuchok": (zhuchok, dict(res=256, extr=0.006, dist=0.015, front=(0, 1, 0))),
    "zhuchok_lever": (zhuchok_lever, dict(res=64, extr=0.004, dist=0.01)),
}

if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in JOBS] or list(JOBS)
    for n in names:
        fn, kw = JOBS[n]
        bake(n, fn, **kw)
