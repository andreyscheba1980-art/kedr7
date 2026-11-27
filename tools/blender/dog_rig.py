# «Кедр-7» — Найда, лайка-подросток. Скелет, гладкий силуэт и клипы (проверено по высоте z = 0).
# Блендер: морда в +Y (в Godot −Z), верх в +Z (в Godot +Y), лапы в стоячей стойке на z = 0.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians

GINGER = kit.mat("d_ginger", (0.68, 0.34, 0.13), rough=0.88, noise=0.06, noise_scale=28, dirt=0.0)
CREAM = kit.mat("d_white", (0.91, 0.88, 0.83), rough=0.88, noise=0.04, noise_scale=34, dirt=0.0)
DARK = kit.mat("d_dark", (0.08, 0.06, 0.05), rough=0.45)
EYE = kit.mat("d_eye", (0.025, 0.02, 0.015), rough=0.06)
SHINE = kit.mat("d_shine", (1.0, 1.0, 1.0), rough=0.1)
PINK = kit.mat("d_pink", (0.78, 0.45, 0.45), rough=0.65)
TONGUE = kit.mat("d_tongue", (0.82, 0.36, 0.40), rough=0.45)
COLLAR = kit.mat("d_collar", (0.58, 0.11, 0.07), rough=0.55, wear=0.25, dirt=0.15)

MATS = [GINGER, CREAM, DARK, EYE, SHINE, PINK, TONGUE, COLLAR]
MAT_IDX = {m.name: i for i, m in enumerate(MATS)}

BONES = [
    ("root", (0, 0, 0), (0, 0, 0.1), None),
    ("hips", (0, -0.17, 0.31), (0, 0.0, 0.325), "root"),
    ("chest", (0, 0.0, 0.325), (0, 0.17, 0.345), "hips"),
    ("neck", (0, 0.16, 0.355), (0, 0.23, 0.465), "chest"),
    ("head", (0, 0.23, 0.465), (0, 0.39, 0.485), "neck"),
    ("jaw", (0, 0.30, 0.425), (0, 0.41, 0.415), "head"),
    ("ear.L", (-0.055, 0.25, 0.535), (-0.072, 0.25, 0.635), "head"),
    ("ear.R", (0.055, 0.25, 0.535), (0.072, 0.25, 0.635), "head"),
    ("tail1", (0, -0.19, 0.34), (0, -0.25, 0.44), "hips"),
    ("tail2", (0, -0.25, 0.44), (0, -0.19, 0.525), "tail1"),
]
for s, n in ((-1, "L"), (1, "R")):
    BONES += [
        (f"arm.{n}", (0.07 * s, 0.12, 0.285), (0.07 * s, 0.13, 0.155), "chest"),
        (f"fore.{n}", (0.07 * s, 0.13, 0.155), (0.07 * s, 0.125, 0.032), f"arm.{n}"),
        (f"pawf.{n}", (0.07 * s, 0.125, 0.032), (0.07 * s, 0.175, 0.015), f"fore.{n}"),
        (f"thigh.{n}", (0.075 * s, -0.15, 0.285), (0.075 * s, -0.105, 0.16), "hips"),
        (f"shank.{n}", (0.075 * s, -0.105, 0.16), (0.075 * s, -0.165, 0.035), f"thigh.{n}"),
        (f"pawb.{n}", (0.075 * s, -0.165, 0.035), (0.075 * s, -0.115, 0.015), f"shank.{n}"),
    ]
B = {b[0]: b for b in BONES}
owner = {}


def own(bone, objs):
    for o in objs:
        owner[o.name] = bone


def mark():
    return len(kit.objs)


def since(m):
    return kit.objs[m:]


def limb(name, a, b, r1, r2, m, verts=10):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m)
    kit.objs.append(o)
    return o


def blob(name, c, r, m, scale=(1, 1, 1), segs=12, rings=8, fluff=0.0):
    o = kit.sphere(name, r, c, m, scale=scale, segs=segs, rings=rings)
    if fluff > 0:
        for v in o.data.vertices:
            v.co += v.normal * abs(noise.noise(v.co * 14.0)) * fluff
    return o


def smooth_torso():
    """Плавный единый корпус собаки вдоль позвоночника без стыков «картошка к картошке»."""
    sections = [
        # (y, z_center, rx, rz, back_weight)
        (-0.225, 0.305, 0.035, 0.035),
        (-0.185, 0.312, 0.078, 0.078),
        (-0.120, 0.318, 0.098, 0.095),
        (-0.040, 0.320, 0.090, 0.088),
        (0.050,  0.328, 0.104, 0.104),
        (0.130,  0.342, 0.098, 0.108),
        (0.185,  0.382, 0.078, 0.085),
        (0.225,  0.435, 0.065, 0.068),
    ]
    bm = bmesh.new()
    segs = 16
    rings = []
    for y, zc, rx, rz in sections:
        ring = []
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            ca = math.cos(ang)
            sa = math.sin(ang)
            # Нижняя часть чуть более плоская, грудная — глубже
            z_off = sa * rz * (0.86 if sa < 0 else 1.0)
            v = bm.verts.new((ca * rx, y, zc + z_off))
            ring.append(v)
        rings.append(ring)
    for r_idx in range(len(rings) - 1):
        r0 = rings[r_idx]
        r1 = rings[r_idx + 1]
        for i in range(segs):
            ni = (i + 1) % segs
            f = bm.faces.new((r0[i], r0[ni], r1[ni], r1[i]))
            f.smooth = True
    # Заглушки сзади и спереди
    tail_cap = bm.verts.new((0.0, -0.238, 0.302))
    neck_cap = bm.verts.new((0.0, 0.238, 0.455))
    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new((tail_cap, rings[0][ni], rings[0][i])).smooth = True
        bm.faces.new((neck_cap, rings[-1][i], rings[-1][ni])).smooth = True

    mesh = bpy.data.meshes.new("torso_mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("torso", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for m in MATS:
        obj.data.materials.append(m)
    # Белое брюшко/грудка (нижние и передне-нижние полигоны) и рыжая спина
    g_i = MAT_IDX[GINGER.name]
    w_i = MAT_IDX[CREAM.name]
    for poly in obj.data.polygons:
        c = poly.center
        belly = c.z < 0.285 and abs(c.x) < 0.075
        chest_bib = c.y > 0.115 and c.z < 0.375 and abs(c.x) < 0.068
        poly.material_index = w_i if (belly or chest_bib) else g_i

    # Плавная весовка по позвоночнику (hips / chest / neck)
    vg_hips = obj.vertex_groups.new(name="hips")
    vg_chest = obj.vertex_groups.new(name="chest")
    vg_neck = obj.vertex_groups.new(name="neck")
    for v in obj.data.vertices:
        y = v.co.y
        if y <= -0.04:
            vg_hips.add([v.index], 1.0, "REPLACE")
        elif y < 0.05:
            t = (y + 0.04) / 0.09
            vg_hips.add([v.index], 1.0 - t, "REPLACE")
            vg_chest.add([v.index], t, "REPLACE")
        elif y <= 0.165:
            vg_chest.add([v.index], 1.0, "REPLACE")
        else:
            t = min(1.0, (y - 0.165) / 0.065)
            vg_chest.add([v.index], 1.0 - t, "REPLACE")
            vg_neck.add([v.index], t, "REPLACE")
    kit.objs.append(obj)
    return obj


# --- Сборка геометрии Найды ---
torso_obj = smooth_torso()
# Воротник и ошейник на шее
m = mark()
blob("ruff", (0, 0.215, 0.39), 0.074, CREAM, scale=(1.1, 0.85, 1.0), segs=12, rings=8, fluff=0.006)
kit.torus("collar", 0.066, 0.013, (0, 0.20, 0.405), COLLAR, rot=(D(-35), 0, 0), maj=18, mino=7)
own("neck", since(m))

# Голова лайки: выразительная маска, белые щёки, чистый нос, брови и тёплые глаза
m = mark()
blob("skull", (0, 0.295, 0.495), 0.090, GINGER, scale=(1.04, 1.02, 0.96), segs=16, rings=10, fluff=0.003)
blob("cheeks", (0, 0.33, 0.456), 0.060, CREAM, scale=(1.18, 0.92, 0.72), segs=12, rings=8)
limb("snout", (0, 0.335, 0.458), (0, 0.415, 0.442), 0.036, 0.022, CREAM, 12)
blob("nose", (0, 0.420, 0.448), 0.015, DARK, scale=(1.22, 0.85, 0.88), segs=8, rings=6)
blob("blaze", (0, 0.362, 0.506), 0.028, CREAM, scale=(0.68, 1.25, 0.52), segs=10, rings=6)
for s in (-1, 1):
    blob(f"brow{s}", (0.036 * s, 0.358, 0.524), 0.016, CREAM, scale=(1.1, 0.8, 0.65), segs=8, rings=6)
    blob(f"eye{s}", (0.041 * s, 0.368, 0.498), 0.018, EYE, segs=10, rings=8)
    blob(f"shine{s}", (0.046 * s, 0.384, 0.506), 0.0055, SHINE, segs=6, rings=4)
own("head", since(m))

m = mark()
limb("jaw_l", (0, 0.32, 0.425), (0, 0.402, 0.428), 0.024, 0.016, CREAM, 10)
blob("tongue", (0, 0.385, 0.425), 0.014, TONGUE, scale=(1.0, 1.35, 0.4), segs=8, rings=4)
own("jaw", since(m))

for s, n in ((-1, "L"), (1, "R")):
    m = mark()
    e = limb(f"ear{n}", (0.055 * s, 0.25, 0.525), (0.074 * s, 0.25, 0.635), 0.033, 0.004, GINGER, 6)
    e.scale = (1.0, 0.42, 1.0)
    pin = limb(f"earin{n}", (0.055 * s, 0.258, 0.532), (0.072 * s, 0.258, 0.618), 0.020, 0.003, PINK, 6)
    pin.scale = (1.0, 0.3, 1.0)
    own(f"ear.{n}", since(m))

    a1 = Vector(B[f"arm.{n}"][1]); a2 = Vector(B[f"fore.{n}"][1]); a3 = Vector(B[f"pawf.{n}"][1]); a4 = Vector(B[f"pawf.{n}"][2])
    m = mark(); limb(f"upf{n}", a1, a2, 0.037, 0.027, CREAM, 10); own(f"arm.{n}", since(m))
    m = mark(); limb(f"lof{n}", a2, a3, 0.026, 0.021, CREAM, 10); own(f"fore.{n}", since(m))
    m = mark(); blob(f"pf{n}", (a3 + a4) / 2 + Vector((0, 0, 0.006)), 0.025, CREAM, scale=(1.0, 1.4, 0.72), segs=10, rings=6); own(f"pawf.{n}", since(m))

    t1 = Vector(B[f"thigh.{n}"][1]); t2 = Vector(B[f"shank.{n}"][1]); t3 = Vector(B[f"pawb.{n}"][1]); t4 = Vector(B[f"pawb.{n}"][2])
    m = mark(); blob(f"haunch{n}", t1 + Vector((0, 0.015, -0.025)), 0.056, GINGER, scale=(0.72, 1.15, 1.15), segs=10, rings=8, fluff=0.004); limb(f"th{n}", t1, t2, 0.044, 0.029, GINGER, 10); own(f"thigh.{n}", since(m))
    m = mark(); limb(f"sh{n}", t2, t3, 0.025, 0.019, CREAM, 10); own(f"shank.{n}", since(m))
    m = mark(); blob(f"pb{n}", (t3 + t4) / 2 + Vector((0, 0, 0.006)), 0.025, CREAM, scale=(1.0, 1.4, 0.72), segs=10, rings=6); own(f"pawb.{n}", since(m))

# Хвост бубликом
m = mark(); limb("tail_a", B["tail1"][1], B["tail1"][2], 0.040, 0.046, GINGER, 10); own("tail1", since(m))
m = mark(); limb("tail_b", B["tail2"][1], B["tail2"][2], 0.045, 0.022, CREAM, 10); blob("tail_tuft", B["tail2"][2], 0.036, CREAM, segs=10, rings=6, fluff=0.006); own("tail2", since(m))

for o in kit.objs:
    if o is torso_obj:
        continue
    vg = o.vertex_groups.new(name=owner[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")

# Голове отдаём больше места в атласе, margin=8 убирает чёрную кайму на границах UV
body, img, tris = kit.finish(
    "dog", OUT, res=512, origin="keep", samples=40, ao_min=0.72, ao_blur=2,
    uv_boost=(lambda c: c.y > 0.22 and c.z > 0.39, 1.65), bake_margin=8
)

arm_data = bpy.data.armatures.new("DogArm")
arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name, h, t, parent in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head = h; eb.tail = t; eb.roll = 0.0
    if parent:
        eb.parent = arm_data.edit_bones[parent]
    eb.use_deform = name != "root"
bpy.ops.object.mode_set(mode="OBJECT")
body.parent = arm
body.modifiers.new("Armature", "ARMATURE").object = arm

bpy.context.scene.render.fps = 24
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"


def _eval_min_z():
    deps = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(deps)
    me = ev.to_mesh()
    mz = min((ev.matrix_world @ v.co).z for v in me.vertices)
    ev.to_mesh_clear()
    return mz


def _apply_pose_dict(k):
    for pb in arm.pose.bones:
        r = k.get(pb.name, (0, 0, 0))
        pb.rotation_euler = (D(r[0]), D(r[1]), D(r[2]))
        pb.location = k.get(pb.name + "@loc", (0, 0, 0))
    bpy.context.view_layer.update()


def clip(name, keys, snap_to_ground=False):
    keys = {f: dict(v) for f, v in keys.items()}
    # Автоподстройка root@loc по минимальному z среди ВСЕХ кадров клипа — поза НИКОГДА не уходит в пол/снег
    if snap_to_ground:
        mz_clip = 999.0
        for f in sorted(keys):
            _apply_pose_dict(keys[f])
            mz_clip = min(mz_clip, _eval_min_z())
        if abs(mz_clip) > 0.004:
            dy_lift = -mz_clip
            for f in keys:
                cur = list(keys[f].get("root@loc", (0.0, 0.0, 0.0)))
                cur[1] += dy_lift
                keys[f]["root@loc"] = tuple(cur)
        # Если хвост в sit/growl опустился глубже из-за наклона бедра — проверим итоговую ось:
        # для кости root с head=(0,0,0), tail=(0,0,0.1), roll=0 локальная Y = мировая +Z.
        _apply_pose_dict(keys[sorted(keys)[0]])
        mz_after = _eval_min_z()
        if abs(mz_after) > 0.01:
            # Резервный сдвиг на случай иной ориентации roll
            for axis_i in (2, 0):
                for f in keys:
                    cur = list(keys[f].get("root@loc", (0.0, 0.0, 0.0)))
                    cur[axis_i] += -mz_after
                    keys[f]["root@loc"] = tuple(cur)
                _apply_pose_dict(keys[sorted(keys)[0]])
                if abs(_eval_min_z()) < 0.01:
                    break
                for f in keys:
                    cur = list(keys[f].get("root@loc", (0.0, 0.0, 0.0)))
                    cur[axis_i] -= -mz_after
                    keys[f]["root@loc"] = tuple(cur)

    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    min_z_all = 999.0
    for f in sorted(keys):
        k = keys[f]
        _apply_pose_dict(k)
        min_z_all = min(min_z_all, _eval_min_z())
        for pb in arm.pose.bones:
            pb.keyframe_insert("rotation_euler", frame=f)
            pb.keyframe_insert("location", frame=f)
    print(f"  clip {name:12s}: min_z={min_z_all:+.3f}")
    act.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new(); tr.name = name
    tr.strips.new(name, 1, act).name = name
    tr.mute = True
    arm.animation_data.action = None


def mix(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


def mirror(p):
    out = {}
    for k, v in p.items():
        nk = k.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")
        out[nk] = v if k.endswith("@loc") else (v[0], -v[1], -v[2])
    return out


# --- Стоит: дыхание, хвост ходит, уши дёргаются ---
ST = {"tail1": (-20, 0, 0), "tail2": (-40, 0, 0), "neck": (6, 0, 0)}
clip("stand", {
    1: mix(ST, {"tail1": (-20, 0, 10)}),
    13: mix(ST, {"tail1": (-20, 0, -10), "chest": (2, 0, 0), "ear.L": (-10, 0, 0)}),
    25: mix(ST, {"tail1": (-20, 0, 10), "head": (0, 0, 8)}),
    37: mix(ST, {"tail1": (-20, 0, -10), "chest": (2, 0, 0)}),
    49: mix(ST, {"tail1": (-20, 0, 10)})
}, snap_to_ground=True)

# --- Сидит, наклоняет голову ---
SIT = {
    "hips": (36, 0, 0), "hips@loc": (0, -0.02, -0.07), "chest": (-20, 0, 0), "neck": (-6, 0, 0),
    "arm.L": (-16, 0, 0), "arm.R": (-16, 0, 0),
    "thigh.L": (38, 0, 6), "thigh.R": (38, 0, -6),
    "shank.L": (-110, 0, 0), "shank.R": (-110, 0, 0),
    "pawb.L": (36, 0, 0), "pawb.R": (36, 0, 0),
    "tail1": (-55, 0, 0), "tail2": (-30, 0, 0)
}
clip("sit", {
    1: SIT,
    20: mix(SIT, {"head": (0, 0, 20), "ear.R": (-14, 0, 0)}),
    34: mix(SIT, {"head": (0, 0, 20), "ear.R": (-14, 0, 0)}),
    50: SIT,
    62: mix(SIT, {"head": (0, 0, -16), "ear.L": (-14, 0, 0)}),
    74: mix(SIT, {"head": (0, 0, -16)}),
    90: SIT
}, snap_to_ground=True)

# --- Шаг ---
WA = mix(ST, {"arm.L": (24, 0, 0), "fore.L": (-10, 0, 0), "arm.R": (-20, 0, 0), "fore.R": (-25, 0, 0),
              "thigh.L": (-22, 0, 0), "shank.L": (-15, 0, 0), "thigh.R": (24, 0, 0), "shank.R": (10, 0, 0), "tail1": (-20, 0, 8)})
WB = mix(ST, {"arm.L": (0, 0, 0), "arm.R": (0, 0, 0), "fore.R": (-40, 0, 0), "thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "shank.L": (-35, 0, 0),
              "chest": (0, 3, 0), "hips@loc": (0, 0, 0.012), "tail1": (-20, 0, -8)})
clip("walk", {1: WA, 7: WB, 13: mirror(WA), 19: mirror(WB), 25: WA}, snap_to_ground=True)

# --- Бег рысцой ---
RA = mix(ST, {"arm.L": (40, 0, 0), "fore.L": (-20, 0, 0), "arm.R": (-35, 0, 0), "fore.R": (-50, 0, 0),
              "thigh.L": (-40, 0, 0), "shank.L": (-30, 0, 0), "thigh.R": (40, 0, 0), "shank.R": (20, 0, 0), "neck": (-6, 0, 0), "ear.L": (-25, 0, 0), "ear.R": (-25, 0, 0)})
RB = mix(RA, {"arm.L": (0, 0, 0), "arm.R": (0, 0, 0), "thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "hips@loc": (0, 0, 0.02)})
clip("run", {1: RA, 5: RB, 9: mirror(RA), 13: mirror(RB), 17: RA}, snap_to_ground=True)

# --- Лежит на животе, поджав все четыре лапы вперёд/под себя, и дрожит ---
LIE = {
    "hips": (4, 0, 0), "chest": (-2, 0, 0),
    "arm.L": (-55, 0, 8), "arm.R": (-55, 0, -8),
    "fore.L": (110, 0, 0), "fore.R": (110, 0, 0),
    "pawf.L": (-50, 0, 0), "pawf.R": (-50, 0, 0),
    "thigh.L": (-64, 0, 14), "thigh.R": (-64, 0, -14),
    "shank.L": (118, 0, 0), "shank.R": (118, 0, 0),
    "pawb.L": (-48, 0, 0), "pawb.R": (-48, 0, 0),
    "neck": (-20, 0, 0), "head": (10, 0, 0),
    "ear.L": (-34, 0, 16), "ear.R": (-34, 0, -16),
    "tail1": (36, 0, 24), "tail2": (32, 0, 26),
}
shiv = {}
for f in range(1, 25, 2):
    a = 1.8 if (f // 2) % 2 == 0 else -1.8
    shiv[f] = mix(LIE, {"chest": (-2 + a, 0, a * 0.5), "head": (12 + a * 0.7, 0, 0), "hips": (2, 0, -a * 0.5)})
shiv[25] = dict(shiv[1])
clip("lie_shiver", shiv, snap_to_ground=True)

# --- Спит: свернулась на животе и медленно дышит ---
SL = mix(LIE, {
    "neck": (-28, 18, 0), "head": (16, 22, 10),
    "ear.L": (-48, 0, 22), "ear.R": (-48, 0, -22),
    "tail1": (38, 0, 46), "tail2": (32, 0, 52)
})
clip("sleep", {
    1: dict(SL),
    30: mix(SL, {"chest": (1, 0, 0)}),
    60: dict(SL),
    75: mix(SL, {"ear.L": (-30, 0, 22)}),
    80: dict(SL),
    96: mix(SL, {"chest": (1, 0, 0)}),
    120: dict(SL)
}, snap_to_ground=True)

# --- Ест из миски ---
EA = mix(ST, {"neck": (-46, 0, 0), "head": (-18, 0, 0), "arm.L": (8, 0, 0), "arm.R": (8, 0, 0), "chest": (-6, 0, 0), "tail1": (-20, 0, 15)})
EB = mix(EA, {"jaw": (-14, 0, 0), "head": (-12, 0, 0), "tail1": (-20, 0, -15)})
clip("eat", {1: EA, 4: EB, 7: EA, 10: EB, 13: EA, 16: EB, 19: EA, 22: EB, 25: EA}, snap_to_ground=True)

# --- Нюхает: нос у пола водит туда-сюда ---
SN = mix(ST, {"neck": (-40, 0, 0), "head": (-20, 0, 0), "chest": (-4, 0, 0)})
clip("sniff", {
    1: mix(SN, {"neck": (-40, 14, 0)}),
    9: mix(SN, {"neck": (-40, -12, 0), "head": (-16, 0, 0)}),
    17: mix(SN, {"neck": (-44, 8, 0)}),
    25: mix(SN, {"neck": (-40, 14, 0)})
}, snap_to_ground=True)

# --- Лает: голова вверх, пасть щёлкает ---
BK = mix(ST, {"neck": (22, 0, 0), "head": (8, 0, 0), "arm.L": (-8, 0, 0), "arm.R": (-8, 0, 0), "tail1": (-35, 0, 0)})
clip("bark", {
    1: BK,
    3: mix(BK, {"jaw": (-30, 0, 0), "chest": (-4, 0, 0), "head": (14, 0, 0)}),
    6: BK, 13: BK,
    15: mix(BK, {"jaw": (-30, 0, 0), "head": (14, 0, 0)}),
    18: BK, 24: BK
}, snap_to_ground=True)

# --- Рычит: голова ниже, уши прижаты, хвост вниз ---
GR = mix(ST, {
    "neck": (-10, 0, 0), "head": (-6, 0, 0), "jaw": (-8, 0, 0),
    "ear.L": (-45, 0, 15), "ear.R": (-45, 0, -15),
    "tail1": (36, 0, 0), "tail2": (10, 0, 0),
    "chest": (-6, 0, 0), "arm.L": (12, 0, 0), "arm.R": (12, 0, 0),
    "hips@loc": (0, -0.01, -0.02)
})
clip("growl", {
    1: GR,
    6: mix(GR, {"jaw": (-12, 0, 0), "chest": (-7, 0, 0)}),
    12: GR,
    18: mix(GR, {"jaw": (-10, 0, 0)}),
    24: GR
}, snap_to_ground=True)

# --- Радуется: сидит, виляет хвостом, наклоняет мордочку ---
HA = mix(SIT, {"neck": (10, 0, 0), "head": (12, 0, 0), "tail1": (-55, 0, 24), "jaw": (-10, 0, 0), "ear.L": (-16, 0, 0), "ear.R": (-16, 0, 0)})
HB = mix(HA, {"tail1": (-55, 0, -24), "arm.R": (-42, 0, 0), "fore.R": (-28, 0, 0), "head": (16, 0, 10)})
clip("happy", {1: HA, 4: HB, 7: HA, 10: HB, 13: HA, 16: mix(HA, {"head": (10, 0, -12)}), 19: HB, 24: HA}, snap_to_ground=True)

for t in arm.animation_data.nla_tracks:
    t.mute = False
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True); body.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT, "dog.glb"), export_format="GLB", use_selection=True,
    export_image_format="AUTO", export_animations=True, export_animation_mode="NLA_TRACKS",
    export_force_sampling=True, export_skins=True, export_def_bones=True
)
for im in bpy.data.images:
    if im.has_data and not im.packed_file and im.size[0] > 0 and not im.name.endswith(("_col", "_ao")):
        im.pack()
# Сохраняем запечённую текстуру явно в оба каталога (assets/models/kedr и assets/textures)
root_dir = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
for tex_dst in [
    os.path.abspath(os.path.join(OUT, "dog_dog.png")),
    os.path.join(root_dir, "assets", "textures", "dog_dog.png"),
]:
    img.filepath_raw = tex_dst
    img.file_format = "PNG"
    img.save()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(os.path.abspath(__file__)), "dog.blend"))
print("[OK] dog tris:", tris, "tex:", os.path.exists(os.path.join(OUT, "dog_dog.png")), "clips:", [a.name for a in bpy.data.actions])
