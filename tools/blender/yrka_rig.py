# «Кедр-7» — Ырка со скелетом и анимациями. Нос смотрит в +Y (в Godot −Z), ноги на z = 0.
# Жёсткая привязка: каждая часть тела целиком висит на своей кости (PS1-стиль, без «резины»).
# Клипы: idle, stalk, run (на четвереньках), sniff, lunge, peek, pin.
# Запуск: blender --background --python yrka_rig.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, sphere, mat
from mathutils import Vector, Matrix, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians

SKIN = mat("y_skin", (0.47, 0.49, 0.46), rough=0.7, noise=0.25, noise_scale=40, wear=0.0, dirt=0.75)
SKIN_D = mat("y_skin_dark", (0.3, 0.31, 0.3), rough=0.7, noise=0.3, noise_scale=30, dirt=0.8)
JACKET = mat("y_jacket", (0.17, 0.19, 0.15), rough=0.9, noise=0.35, noise_scale=14, wear=0.5, dirt=0.8, wear_col=(0.3, 0.3, 0.26))
PANTS = mat("y_pants", (0.13, 0.14, 0.12), rough=0.9, noise=0.3, noise_scale=14, dirt=0.8)
SCARF = mat("y_scarf", (0.33, 0.36, 0.38), rough=0.9, noise=0.3, noise_scale=20)
WAD = mat("y_wad", (0.66, 0.64, 0.56), rough=0.95, noise=0.2)
FROST = mat("y_frost", (0.72, 0.78, 0.82), rough=0.6, noise=0.2)
CLAW = mat("y_claw", (0.06, 0.05, 0.045), rough=0.4)
BONE = mat("y_bone", (0.7, 0.66, 0.55), rough=0.5, dirt=0.6)
BLOOD = mat("y_blood", (0.22, 0.02, 0.015), rough=0.3)
VOID = mat("y_void", (0.01, 0.01, 0.01), rough=0.9)

# --- Кости: (имя, голова, хвост, родитель) ----------------------------------------
BONES = [
    ("root", (0, 0, 0), (0, 0, 0.25), None),
    ("hips", (0, -0.05, 0.88), (0, -0.03, 1.04), "root"),
    ("spine", (0, -0.03, 1.04), (0, 0.06, 1.24), "hips"),
    ("chest", (0, 0.06, 1.24), (0, 0.28, 1.37), "spine"),
    ("neck", (0, 0.28, 1.37), (0, 0.42, 1.41), "chest"),
    ("head", (0, 0.42, 1.41), (0, 0.66, 1.43), "neck"),
    ("jaw", (0, 0.49, 1.36), (0, 0.64, 1.31), "head"),
]
for s, n in ((-1, "L"), (1, "R")):
    sz = 1.36 if s < 0 else 1.29          # левое плечо вздёрнуто
    BONES += [
        (f"shoulder.{n}", (0.05 * s, 0.24, 1.36), (0.24 * s, 0.3, sz), "chest"),
        (f"upper_arm.{n}", (0.24 * s, 0.3, sz), (0.33 * s, 0.34, sz - 0.4), f"shoulder.{n}"),
        (f"forearm.{n}", (0.33 * s, 0.34, sz - 0.4), (0.31 * s, 0.44, sz - 0.86), f"upper_arm.{n}"),
        (f"hand.{n}", (0.31 * s, 0.44, sz - 0.86), (0.31 * s, 0.5, sz - 1.14), f"forearm.{n}"),
        (f"thigh.{n}", (0.12 * s, -0.05, 0.88), (0.15 * s, 0.13, 0.49), "hips"),
        (f"shin.{n}", (0.15 * s, 0.13, 0.49), (0.14 * s, -0.07, 0.1), f"thigh.{n}"),
        (f"foot.{n}", (0.14 * s, -0.07, 0.1), (0.14 * s, 0.14, 0.02), f"shin.{n}"),
    ]
B = {b[0]: b for b in BONES}

# --- Геометрия ------------------------------------------------------------------
owner = {}     # объект → кость


def own(bone, objs):
    for o in objs:
        owner[o.name] = bone


def mark():
    return len(kit.objs)


def since(m):
    return kit.objs[m:]


def limb(name, a, b, r1, r2, m, verts=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    return o


def blob(name, c, r, m, scale=(1, 1, 1), segs=10, rings=7, wobble=0.0):
    o = sphere(name, r, c, m, scale=scale, segs=segs, rings=rings)
    if wobble > 0:
        for v in o.data.vertices:
            v.co += v.normal * noise.noise(v.co * 9.0) * wobble
    return o


def spike(name, a, b, r, m):
    return limb(name, a, b, r, 0.0005, m, verts=5)


# Таз и ватные штаны
m = mark()
blob("pelvis", (0, -0.04, 0.9), 0.17, PANTS, scale=(1.0, 0.85, 0.75), wobble=0.01)
own("hips", since(m))
# Поясница
m = mark()
limb("waist", (0, -0.04, 0.98), (0, 0.04, 1.2), 0.15, 0.17, JACKET, 9)
blob("waist_b", (0, -0.02, 1.08), 0.16, JACKET, scale=(1.05, 0.95, 0.9), wobble=0.012)
own("spine", since(m))
# Грудь, горб, воротник, шарф, вата, иней
m = mark()
hump = blob("hump", (0, 0.12, 1.26), 0.23, JACKET, scale=(1.0, 0.9, 0.85), segs=12, rings=9, wobble=0.015)
for v in hump.data.vertices:          # горб сзади (−Y), впалая грудь спереди
    if v.co.y < 0.12 - 0.05 and v.co.z > 1.24:
        v.co.y -= 0.06; v.co.z += 0.03
limb("collar", (-0.25, 0.27, 1.37), (0.23, 0.27, 1.31), 0.085, 0.07, JACKET, 8)
blob("collar_mid", (0, 0.24, 1.42), 0.1, JACKET, scale=(1.4, 0.8, 0.7))
limb("scarf1", (0.04, 0.24, 1.38), (0.06, 0.06, 1.22), 0.05, 0.04, SCARF, 6)
limb("scarf2", (0.06, 0.06, 1.22), (0.03, -0.03, 1.05), 0.04, 0.022, SCARF, 6)
for i, (a, b) in enumerate([((-0.08, 0.04, 1.32), (-0.13, -0.05, 1.36)), ((0.1, 0.02, 1.26), (0.17, -0.06, 1.29)), ((-0.04, -0.07, 1.14), (-0.08, -0.13, 1.16))]):
    spike(f"wad{i}", a, b, 0.03, WAD)
blob("frost_hump", (-0.02, 0.1, 1.37), 0.08, FROST, scale=(1.2, 0.8, 0.5), wobble=0.01)
own("chest", since(m))
# Шея (кривая хорда)
m = mark()
limb("neck_c", (0, 0.27, 1.36), (0, 0.44, 1.42), 0.06, 0.05, SKIN, 7)
own("neck", since(m))
# Голова: длинный затылок, остатки шапки, лицо
m = mark()
skull = blob("skull", (0, 0.55, 1.45), 0.11, SKIN, scale=(0.95, 1.7, 1.0), segs=12, rings=9)
for v in skull.data.vertices:         # затылочный бугор
    if v.co.y < 0.48:
        v.co.z += 0.02; v.co.x *= 1.1
blob("hat", (0, 0.5, 1.5), 0.11, JACKET, scale=(1.05, 1.2, 0.55), wobble=0.008)
box("brow", (0.17, 0.05, 0.035), (0, 0.69, 1.485), SKIN_D, 0.01)
for s in (-1, 1):
    blob(f"socket{s}", (0.045 * s, 0.7, 1.455), 0.028, VOID, scale=(1.1, 0.7, 0.9), segs=8, rings=5)
    box(f"nostril{s}", (0.012, 0.01, 0.02), (0.012 * s, 0.735, 1.42), VOID, 0.0)
blob("maw", (0, 0.64, 1.39), 0.07, VOID, scale=(1.0, 1.3, 0.5), segs=8, rings=5)
for i in range(5):
    x = -0.04 + i * 0.02
    spike(f"tooth_up{i}", (x, 0.71, 1.4), (x * 1.1, 0.72, 1.34), 0.008, BONE)
own("head", since(m))
m = mark()
blob("jaw_b", (0, 0.6, 1.33), 0.07, SKIN, scale=(1.05, 1.8, 0.45), segs=9, rings=6)
blob("tongue", (0, 0.6, 1.355), 0.05, BLOOD, scale=(1.0, 1.6, 0.25), segs=8, rings=4)
for i in range(5):
    x = -0.04 + i * 0.02
    spike(f"tooth_lo{i}", (x, 0.7, 1.34), (x, 0.705, 1.385), 0.007, BONE)
own("jaw", since(m))
# Руки
for s, n in ((-1, "L"), (1, "R")):
    sh = Vector(B[f"upper_arm.{n}"][1]); el = Vector(B[f"forearm.{n}"][1]); wr = Vector(B[f"hand.{n}"][1]); tip = Vector(B[f"hand.{n}"][2])
    m = mark()
    blob(f"shoulder_pad{n}", sh, 0.085, JACKET, scale=(1, 1, 0.9), wobble=0.01)
    limb(f"sh_link{n}", B[f"shoulder.{n}"][1], sh, 0.07, 0.08, JACKET)
    own(f"shoulder.{n}", since(m))
    m = mark()
    limb(f"sleeve{n}", sh, el, 0.075, 0.055, JACKET, 8)
    blob(f"elbow{n}", el, 0.055, JACKET, wobble=0.006)
    spike(f"wad_arm{n}", el + Vector((0, -0.03, 0.04)), el + Vector((0.04 * s, -0.08, 0.06)), 0.02, WAD)
    own(f"upper_arm.{n}", since(m))
    m = mark()
    limb(f"forearm{n}", el, wr, 0.045, 0.03, SKIN, 7)
    own(f"forearm.{n}", since(m))
    m = mark()
    blob(f"palm{n}", wr + Vector((0, 0.01, -0.05)), 0.04, SKIN, scale=(0.9, 0.7, 1.3))
    for f in range(4):
        dx = (-0.03 + f * 0.02) * s
        a = wr + Vector((dx, 0.02, -0.08))
        b = a + Vector((dx * 0.6, 0.05, -0.12))
        c = b + Vector((dx * 0.4, -0.01, -0.1))
        limb(f"fing{n}{f}a", a, b, 0.012, 0.01, SKIN_D, 5)
        limb(f"fing{n}{f}b", b, c, 0.01, 0.008, SKIN_D, 5)
        spike(f"claw{n}{f}", c, c + Vector((0, 0.03, -0.065)), 0.009, CLAW)
    own(f"hand.{n}", since(m))
    # Ноги
    hp = Vector(B[f"thigh.{n}"][1]); kn = Vector(B[f"shin.{n}"][1]); an = Vector(B[f"foot.{n}"][1]); to = Vector(B[f"foot.{n}"][2])
    m = mark()
    limb(f"thigh{n}", hp, kn, 0.085, 0.06, PANTS, 8)
    blob(f"knee{n}", kn, 0.058, PANTS, wobble=0.006)
    own(f"thigh.{n}", since(m))
    m = mark()
    limb(f"shin{n}", kn, an, 0.045, 0.03, SKIN, 7)
    own(f"shin.{n}", since(m))
    m = mark()
    limb(f"foot{n}", an, to, 0.032, 0.02, SKIN, 6)
    for f in range(3):
        dx = (-0.02 + f * 0.02) * s
        spike(f"toe{n}{f}", to + Vector((dx, 0, 0)), to + Vector((dx * 1.5, 0.07, -0.01)), 0.01, CLAW)
    own(f"foot.{n}", since(m))

# Вершинные группы: каждая часть целиком на своей кости
for o in kit.objs:
    vg = o.vertex_groups.new(name=owner[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")

body, img, tris = kit.finish("yrka", OUT, res=1024, origin="keep", samples=32, ao_min=0.45)

# --- Арматура -------------------------------------------------------------------
arm_data = bpy.data.armatures.new("YrkaArm")
arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name, h, t, parent in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head = h; eb.tail = t; eb.roll = 0.0
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = False
    eb.use_deform = name != "root"
bpy.ops.object.mode_set(mode="OBJECT")
body.parent = arm
mod = body.modifiers.new("Armature", "ARMATURE"); mod.object = arm

# --- Анимации -------------------------------------------------------------------
FPS = 24
bpy.context.scene.render.fps = FPS
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"


def clip(name, length_f, keys, loop=True):
    """keys: {frame: {bone: (rx, ry, rz) град | ("loc", x, y, z)}}"""
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
    for f in sorted(keys):
        k = keys[f]
        for pb in arm.pose.bones:
            r = k.get(pb.name, (0, 0, 0))
            pb.rotation_euler = (D(r[0]), D(r[1]), D(r[2]))
            pb.keyframe_insert("rotation_euler", frame=f)
            pb.location = k.get(pb.name + "@loc", (0, 0, 0))
            pb.keyframe_insert("location", frame=f)
    for fc in act.fcurves if hasattr(act, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    act.use_fake_user = True
    act.frame_range = (1, length_f) if hasattr(act, "frame_range") else None
    track = arm.animation_data.nla_tracks.new(); track.name = name
    strip = track.strips.new(name, 1, act); strip.name = name
    track.mute = True
    arm.animation_data.action = None
    return act


def mirror(pose):
    """Зеркалим позу L↔R (для полуцикла шага)."""
    out = {}
    for k, v in pose.items():
        nk = k.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")
        if k.endswith("@loc"):
            out[nk] = (-v[0], v[1], v[2])
        else:
            out[nk] = (v[0], -v[1], -v[2])
    return out


def cycle(a, b, half):
    """Цикл из двух поз: a → b → mirror(a) → mirror(b) → a."""
    return {1: a, 1 + half // 2: b, 1 + half: mirror(a), 1 + half + half // 2: mirror(b), 1 + 2 * half: a}


IDLE_A = {"spine": (-6, 0, 0), "chest": (-4, 0, 2), "neck": (6, 0, 0), "head": (10, -14, 22), "jaw": (12, 0, 0),
          "upper_arm.L": (6, 0, 4), "upper_arm.R": (4, 0, -3), "forearm.L": (10, 0, 0), "forearm.R": (14, 0, 0)}
IDLE_B = {"spine": (-9, 0, 0), "chest": (-7, 0, -1), "neck": (8, 0, 0), "head": (6, -18, 26), "jaw": (18, 0, 0),
          "upper_arm.L": (9, 0, 5), "upper_arm.R": (7, 0, -4), "forearm.L": (14, 0, 0), "forearm.R": (18, 0, 0)}
clip("idle", 49, {1: IDLE_A, 25: IDLE_B, 49: IDLE_A})

# Крадётся: низко, на полусогнутых, руки висят до земли, голова вперёд
ST_BASE = {"hips@loc": (0, 0, -0.1), "spine": (-14, 0, 0), "chest": (-10, 0, 0), "neck": (14, 0, 0), "head": (10, -10, 18)}
ST_A = dict(ST_BASE, **{"thigh.L": (34, 0, 0), "shin.L": (-30, 0, 0), "foot.L": (-6, 0, 0),
                         "thigh.R": (-14, 0, 0), "shin.R": (-26, 0, 0), "foot.R": (16, 0, 0),
                         "upper_arm.L": (-16, 0, 3), "upper_arm.R": (20, 0, -3), "forearm.L": (8, 0, 0), "forearm.R": (16, 0, 0),
                         "hips": (0, 0, 4)})
ST_B = dict(ST_BASE, **{"hips@loc": (0, 0, -0.06), "thigh.L": (10, 0, 0), "shin.L": (-12, 0, 0),
                         "thigh.R": (12, 0, 0), "shin.R": (-58, 0, 0), "foot.R": (10, 0, 0),
                         "upper_arm.L": (0, 0, 3), "upper_arm.R": (4, 0, -3), "forearm.L": (10, 0, 0), "forearm.R": (12, 0, 0),
                         "hips": (0, 0, 0)})
clip("stalk", 41, cycle(ST_A, ST_B, 20))

# Бег на четвереньках: корпус почти горизонтально, руки — передние лапы, галоп
RUN_BASE = {"root": (-62, 0, 0), "root@loc": (0, 0, -0.03), "spine": (-8, 0, 0), "chest": (-6, 0, 0), "neck": (52, 0, 0), "head": (24, 0, 10)}
RUN_A = dict(RUN_BASE, **{"hips": (6, 0, 0), "thigh.L": (110, 0, 0), "shin.L": (-70, 0, 0), "thigh.R": (95, 0, 0), "shin.R": (-80, 0, 0),
                          "upper_arm.L": (-10, 0, 0), "upper_arm.R": (10, 0, 0), "forearm.L": (40, 0, 0), "forearm.R": (30, 0, 0),
                          "hand.L": (30, 0, 0), "hand.R": (30, 0, 0)})
RUN_B = dict(RUN_BASE, **{"root@loc": (0, 0, 0.1), "hips": (-8, 0, 0), "thigh.L": (40, 0, 0), "shin.L": (-20, 0, 0), "thigh.R": (30, 0, 0), "shin.R": (-30, 0, 0),
                          "upper_arm.L": (55, 0, 0), "upper_arm.R": (70, 0, 0), "forearm.L": (-10, 0, 0), "forearm.R": (0, 0, 0),
                          "hand.L": (-20, 0, 0), "hand.R": (-20, 0, 0), "chest": (6, 0, 0)})
clip("run", 15, {1: RUN_A, 8: RUN_B, 15: RUN_A})

# Принюхивается: голова вниз-вперёд рывками, грудь ходит
SN_A = {"hips@loc": (0, 0, -0.12), "spine": (-24, 0, 0), "chest": (-14, 0, 0), "neck": (20, 0, 0), "head": (-10, 8, 6), "jaw": (6, 0, 0),
        "thigh.L": (20, 0, 0), "shin.L": (-34, 0, 0), "thigh.R": (16, 0, 0), "shin.R": (-30, 0, 0),
        "upper_arm.L": (14, 0, 4), "upper_arm.R": (10, 0, -4)}
SN_B = dict(SN_A, **{"neck": (28, 0, 0), "head": (-18, -6, 14), "chest": (-11, 0, 0), "jaw": (14, 0, 0)})
SN_C = dict(SN_A, **{"neck": (24, 0, 0), "head": (-4, 14, -4), "jaw": (4, 0, 0)})
clip("sniff", 49, {1: SN_A, 9: SN_B, 13: SN_A, 25: SN_C, 33: SN_B, 37: SN_C, 49: SN_A})

# Бросок: присел → прыжок, руки вперёд, пасть настежь (один раз)
LU_0 = {"hips@loc": (0, 0, 0), "spine": (-6, 0, 0)}
LU_1 = {"hips@loc": (0, -0.08, -0.25), "spine": (-30, 0, 0), "chest": (-20, 0, 0), "neck": (30, 0, 0), "head": (6, 0, 0), "jaw": (10, 0, 0),
        "thigh.L": (60, 0, 0), "shin.L": (-90, 0, 0), "thigh.R": (60, 0, 0), "shin.R": (-90, 0, 0), "foot.L": (30, 0, 0), "foot.R": (30, 0, 0),
        "upper_arm.L": (-30, 0, 10), "upper_arm.R": (-30, 0, -10)}
LU_2 = {"hips@loc": (0, 0.35, 0.12), "root": (-30, 0, 0), "spine": (-10, 0, 0), "chest": (-6, 0, 0), "neck": (30, 0, 0), "head": (14, 0, 0), "jaw": (45, 0, 0),
        "thigh.L": (-20, 0, 0), "shin.L": (-10, 0, 0), "thigh.R": (-10, 0, 0), "shin.R": (-20, 0, 0),
        "upper_arm.L": (120, 0, 20), "upper_arm.R": (120, 0, -20), "forearm.L": (-20, 0, 0), "forearm.R": (-20, 0, 0)}
clip("lunge", 17, {1: LU_0, 6: LU_1, 12: LU_2, 17: LU_2}, loop=False)

# Выглядывает из-за дерева: корпус вбок, голова лежит на плече
PK_A = {"hips@loc": (0.0, 0, -0.04), "spine": (-6, 0, -16), "chest": (-6, 0, -18), "neck": (6, 0, -20), "head": (4, -20, -62), "jaw": (8, 0, 0),
        "upper_arm.L": (30, 0, 0), "forearm.L": (40, 0, 0), "upper_arm.R": (6, 0, -6)}
PK_B = dict(PK_A, **{"head": (6, -30, -78), "jaw": (20, 0, 0), "spine": (-6, 0, -20)})
clip("peek", 61, {1: PK_A, 30: PK_B, 34: PK_B, 61: PK_A})

# Навис над жертвой: корпус вперёд, руки рвут
PI_A = {"hips@loc": (0, 0, -0.18), "spine": (-30, 0, 0), "chest": (-24, 0, 0), "neck": (34, 0, 0), "head": (-8, 0, 10), "jaw": (40, 0, 0),
        "thigh.L": (40, 0, 0), "shin.L": (-60, 0, 0), "thigh.R": (36, 0, 0), "shin.R": (-56, 0, 0),
        "upper_arm.L": (110, 0, 20), "upper_arm.R": (40, 0, -20), "forearm.L": (-40, 0, 0), "forearm.R": (20, 0, 0)}
PI_B = dict(PI_A, **{"upper_arm.L": (40, 0, 20), "upper_arm.R": (110, 0, -20), "forearm.L": (20, 0, 0), "forearm.R": (-40, 0, 0), "jaw": (20, 0, 0), "head": (-14, 0, -6)})
clip("pin", 21, {1: PI_A, 11: PI_B, 21: PI_A})

# Превью-поза (если надо) и экспорт
for t in arm.animation_data.nla_tracks:
    t.mute = False
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True); body.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "yrka.glb"), export_format="GLB", use_selection=True,
                          export_image_format="AUTO", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_frame_step=1, export_skins=True, export_def_bones=True)
for im in bpy.data.images:
    if im.has_data and not im.packed_file and im.size[0] > 0 and not im.name.endswith(("_col", "_ao")):
        im.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "yrka.blend"))
print("[OK] yrka tris:", tris, "bones:", len(BONES), "clips:", [a.name for a in bpy.data.actions])
