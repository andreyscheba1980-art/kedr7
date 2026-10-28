# «Кедр-7» — Ырка v3 на анатомической болванке Blender Studio «Human Base Meshes» (CC0, v1.4.1,
# https://www.blender.org/download/demo-files/ — realistic_body_male). Болванка не входит в репозиторий:
# путь к human_base_meshes_bundle.blend передаётся вторым аргументом.
# Что делаем с человеком: иссушаем, вытягиваем предплечья и пальцы, растягиваем рот шире человеческого,
# проваливаем глазницы, одеваем в рваный тулуп с прорехой на груди (рёбра), ватные штаны, валенки, ушанку.
# Скелет — имена и клипы прежней Ырки (idle, stalk, run, sniff, lunge, peek, pin); поза покоя — сутулая.
# Нос смотрит в +Y (в Godot −Z), ноги на z = 0.
# Запуск: blender --background --python yrka_hbm.py -- <bundle.blend> <out_dir>
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, anatomy as an
from anatomy import frosted, sculpt, rag_hem
from mathutils import Vector, Matrix, Quaternion, noise

BUNDLE, OUT = sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()

# --- Материалы (тёмные: под фонарём читается иней, а не ткань) ------------------------
SKIN = frosted("y3_skin", (0.21, 0.23, 0.26), frost=(0.62, 0.68, 0.75), amount=0.16, top_bias=0.6,
               dark=(0.04, 0.035, 0.04), dark_z=0.86)
COAT = frosted("y3_coat", (0.075, 0.06, 0.05), amount=0.2, top_bias=0.85)
PANTS = frosted("y3_pants", (0.06, 0.065, 0.06), amount=0.22)
FELT = frosted("y3_felt", (0.11, 0.105, 0.1), amount=0.2, top_bias=0.9)
HAT = frosted("y3_hat", (0.09, 0.08, 0.07), amount=0.25)
VOID = kit.mat("y3_void", (0.01, 0.01, 0.012), rough=0.9)

# --- Болванка ----------------------------------------------------------------------------
with bpy.data.libraries.load(BUNDLE, link=False) as (src, dst):
    dst.objects = ["GEO-body_male_realistic"]
body = dst.objects[0]
bpy.context.collection.objects.link(body)
for m in list(body.modifiers):
    body.modifiers.remove(m)
body.parent = None
body.data = body.data.copy()
# Центр по X в ноль и разворот лицом в +Y
cx = sum((body.matrix_world @ v.co).x for v in body.data.vertices) / len(body.data.vertices)
mw = body.matrix_world.copy()
rot = Matrix.Rotation(math.pi, 4, "Z")
for v in body.data.vertices:
    w = mw @ v.co
    v.co = rot @ Vector((w.x - cx, w.y, w.z))
body.matrix_world = Matrix.Identity(4)
body.data.update()
body.name = "body"
body.data.materials.clear()
body.data.materials.append(SKIN)

# --- Скелет в A-позе по ориентирам болванки ---------------------------------------------
BONES = [
    ("root", (0, 0, 0), (0, 0, 0.25), None),
    ("hips", (0, 0.0, 0.92), (0, 0.0, 1.10), "root"),
    ("spine", (0, 0.0, 1.10), (0, 0.0, 1.27), "hips"),
    ("chest", (0, 0.0, 1.27), (0, 0.01, 1.43), "spine"),
    ("neck", (0, 0.01, 1.43), (0, 0.02, 1.52), "chest"),
    ("head", (0, 0.02, 1.52), (0, 0.03, 1.70), "neck"),
    ("jaw", (0, 0.03, 1.51), (0, 0.11, 1.47), "head"),
]
for s, n in ((-1, "L"), (1, "R")):
    BONES += [
        (f"shoulder.{n}", (0.03 * s, 0.0, 1.38), (0.18 * s, 0.0, 1.39), "chest"),
        (f"upper_arm.{n}", (0.18 * s, 0.0, 1.39), (0.30 * s, 0.02, 1.12), f"shoulder.{n}"),
        (f"forearm.{n}", (0.30 * s, 0.02, 1.12), (0.39 * s, 0.07, 0.88), f"upper_arm.{n}"),
        (f"hand.{n}", (0.39 * s, 0.07, 0.88), (0.44 * s, 0.13, 0.76), f"forearm.{n}"),
        (f"thigh.{n}", (0.09 * s, 0.0, 0.92), (0.10 * s, 0.0, 0.50), "hips"),
        (f"shin.{n}", (0.10 * s, 0.0, 0.50), (0.10 * s, -0.03, 0.08), f"thigh.{n}"),
        (f"foot.{n}", (0.10 * s, -0.03, 0.08), (0.11 * s, 0.12, 0.0), f"shin.{n}"),
    ]
B = {b[0]: (Vector(b[1]), Vector(b[2])) for b in BONES}


def seg_t(p, a, b):
    ab = b - a
    return max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))


# --- Уродуем человека ------------------------------------------------------------------
me = body.data
for v in me.vertices:
    p = v.co.copy()
    side = 1 if p.x > 0 else -1
    n = "R" if side > 0 else "L"
    sh, el = B[f"upper_arm.{n}"]
    _, wr = B[f"forearm.{n}"]
    _, tip = B[f"hand.{n}"]
    is_arm = abs(p.x) > 0.2 and p.z < 1.42 and p.z > 0.6
    if is_arm:
        # Предплечье длиннее на 0.14, кисть — в 1.45 раза: всё ниже локтя уезжает вдоль руки
        fa = (wr - el).normalized()
        t = seg_t(p, el, wr)
        beyond_el = (p - el).dot(fa) > 0
        if beyond_el:
            p += fa * 0.14 * min(1.0, (p - el).dot(fa) / (wr - el).length)
            if (p - (wr + fa * 0.14)).dot(fa) > 0:
                base = wr + fa * 0.14
                p = base + (p - base) * 1.45
        # Иссохшие руки: ближе к оси кости
        a, b = (sh, el) if not beyond_el else (el, wr + fa * 0.14)
        tt = seg_t(p, a, b)
        axis_pt = a + (b - a) * tt
        p = axis_pt + (p - axis_pt) * 0.82
    elif p.z > 0.95 and p.z < 1.42:
        # Туловище: впалый живот, острые рёбра, сутулые узкие плечи
        p.x *= 0.9
        if p.y > 0.02 and p.z < 1.2:
            p.y -= 0.025 * (1.0 - abs(p.z - 1.07) / 0.15)
    elif p.z <= 0.95:
        # Ноги: тоньше к оси
        _, kn = B[f"thigh.{n}"]
        hp = B[f"thigh.{n}"][0]
        _, an_ = B[f"shin.{n}"]
        a, b = (hp, kn) if p.z > 0.5 else (kn, an_)
        tt = seg_t(p, a, b)
        axis_pt = a + (b - a) * tt
        if p.z > 0.1:
            p = axis_pt + (p - axis_pt) * 0.86
    v.co = p
me.update()

# Лицо: рот шире человеческого, губы разошлись, глазницы провалены, скулы острые
MOUTH_Z = 1.497
for v in me.vertices:
    p = v.co
    if p.z < 1.44 or p.y < 0.04:
        continue
    # уголки рта растягиваем к ушам
    if abs(p.z - MOUTH_Z) < 0.022 and abs(p.x) < 0.06:
        k = 1.0 - abs(p.z - MOUTH_Z) / 0.022
        p.x *= 1.0 + 0.9 * k
        if p.z < MOUTH_Z:
            p.z -= 0.012 * k            # нижняя губа отвисла: рот приоткрыт
        else:
            p.z += 0.004 * k
    # глазницы
    for ex in (-0.033, 0.033):
        d = (Vector((p.x, p.y, p.z)) - Vector((ex, 0.11, 1.574))).length
        if d < 0.035:
            k = 1.0 - d / 0.035
            p.y -= 0.018 * k
    # впалые щёки
    for cx_ in (-0.05, 0.05):
        d = (Vector((p.x, p.y, p.z)) - Vector((cx_, 0.09, 1.52))).length
        if d < 0.04:
            p.y -= 0.012 * (1.0 - d / 0.04)
me.update()
sculpt(body, amp=0.003, scale=45.0, seed=3.0)          # обмороженная, сморщенная кожа

# Чёрная глотка и щели глаз
kit.box("throat", (0.075, 0.03, 0.02), (0, 0.095, MOUTH_Z - 0.004), VOID, bevel=0.0)
throat = kit.objs[-1]
for ex in (-0.033, 0.033):
    kit.sphere("eyevoid", 0.014, (ex, 0.098, 1.574), VOID, scale=(1.2, 0.7, 0.7), segs=8, rings=5)
eyes = kit.objs[-2:]


# --- Одежда из той же кожи с отступом ---------------------------------------------------
def shell(name, keep, offset, mat, noise_amp=0.0, noise_scale=8.0):
    o = body.copy()
    o.data = body.data.copy()
    o.name = name
    bpy.context.collection.objects.link(o)
    bm = bmesh.new(); bm.from_mesh(o.data)
    kill = [v for v in bm.verts if not keep(v.co)]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    bm.to_mesh(o.data); bm.free()
    o.data.materials.clear(); o.data.materials.append(mat)
    if noise_amp:
        sculpt(o, amp=noise_amp, scale=noise_scale, seed=hash(name) % 97)
    kit.objs.append(o)
    return o


def is_arm_lower(c, frac):
    """Точка руки ниже доли frac предплечья (от локтя)."""
    n = "R" if c.x > 0 else "L"
    el = B[f"upper_arm.{n}"][1]
    wr = B[f"forearm.{n}"][1]
    fa = (wr - el).normalized()
    return abs(c.x) > 0.2 and (c - el).dot(fa) > (wr - el).length * frac


coat = shell("coat", lambda c: 0.6 < c.z < 1.45 and not is_arm_lower(c, 0.35), 0.035, COAT)
sculpt(coat, amp=0.035, scale=4.0, seed=1.0)
sculpt(coat, amp=0.018, scale=11.0, seed=2.5, ridge=True)
rag_hem(coat, 0.66, amp=0.05, scale=10.0)
# Прореха на груди: полы разошлись
bm = bmesh.new(); bm.from_mesh(coat.data)
kill = [f for f in bm.faces if (lambda c: c.y > 0.04 and abs(c.x) < 0.05 + 0.06 * max(0.0, 1.38 - c.z) / 0.4 + noise.noise(c * 14) * 0.02 and 0.97 < c.z < 1.38)(f.calc_center_median())]
bmesh.ops.delete(bm, geom=kill, context="FACES"); bm.to_mesh(coat.data); bm.free()
# Обшлага рукавов рваные
bm = bmesh.new(); bm.from_mesh(coat.data)
kill = [f for f in bm.faces if (lambda c: is_arm_lower(c, 0.2 + noise.noise(c * 12) * 0.12))(f.calc_center_median())]
bmesh.ops.delete(bm, geom=kill, context="FACES"); bm.to_mesh(coat.data); bm.free()
coat.data.update()

pants = shell("pants", lambda c: 0.3 < c.z < 1.0 and abs(c.x) < 0.22, 0.018, PANTS, 0.02, 7.0)
boots = shell("boots", lambda c: c.z < 0.34, 0.025, FELT, 0.012, 16.0)
hat = shell("hat", lambda c: c.z > 1.6 or (c.z > 1.47 and abs(c.x) > 0.06 and c.y < 0.05), 0.03, HAT, 0.012, 24.0)
# Ушанка набок
for v in hat.data.vertices:
    v.co = Matrix.Rotation(math.radians(9), 3, "Y") @ (v.co - Vector((0, 0, 1.62))) + Vector((0.01, 0, 1.63))
hat.data.update()

# --- Скелет, веса, сутулая поза покоя ----------------------------------------------------
arm = an.armature(BONES, "YrkaArm")
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True); arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
for o in [coat, pants, boots, hat, throat] + list(eyes):
    dt = o.modifiers.new("dt", "DATA_TRANSFER")
    dt.object = body
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.datalayout_transfer(modifier="dt")
    bpy.ops.object.modifier_apply(modifier="dt")
    o.parent = arm
    mod = o.modifiers.new("Armature", "ARMATURE"); mod.object = arm


def aim(pb, direction):
    """Повернуть кость так, чтобы в позе она смотрела в direction (мировые оси)."""
    bpy.context.view_layer.update()
    cur = (pb.tail - pb.head).normalized()
    q_world = cur.rotation_difference(Vector(direction).normalized())
    m = pb.matrix.to_quaternion()
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = pb.rotation_quaternion @ (m.inverted() @ q_world @ m)
    bpy.context.view_layer.update()


bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
P = arm.pose.bones
aim(P["spine"], (0, 0.3, 1))
aim(P["chest"], (0, 0.75, 0.66))
aim(P["neck"], (0, 0.95, 0.3))
aim(P["head"], (0, 0.25, 1))
for n, s in (("L", -1), ("R", 1)):
    aim(P[f"upper_arm.{n}"], (0.08 * s, 0.2, -1))
    aim(P[f"forearm.{n}"], (0.02 * s, 0.32, -1))
    aim(P[f"hand.{n}"], (0.0, 0.3, -1))
    aim(P[f"thigh.{n}"], (0.02 * s, 0.25, -1))
    aim(P[f"shin.{n}"], (0.0, -0.18, -1))
bpy.ops.object.mode_set(mode="OBJECT")
# Поза → меш и покой скелета
for o in [body, coat, pants, boots, hat, throat] + list(eyes):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    o.parent = None
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply(selected=False)
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (0, 0, 0)
bpy.ops.object.mode_set(mode="OBJECT")

# Глаза после сутулой позы — для катафотов в Godot (точка игры = (x, z, −y))
for e in eyes:
    c = sum((e.matrix_world @ v.co for v in e.data.vertices), Vector()) / len(e.data.vertices)
    print("EYE_GODOT", round(c.x, 3), round(c.z, 3), round(-c.y, 3))

# --- Под PS1: упростить, собрать, запечь -------------------------------------------------
for o, ratio in ((body, 0.32), (coat, 0.3), (pants, 0.35), (boots, 0.3), (hat, 0.35)):
    d = o.modifiers.new("dec", "DECIMATE")
    d.ratio = ratio
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="dec")
kit.objs = [o for o in kit.objs if o.name in bpy.data.objects and o.type == "MESH"]
if body not in kit.objs:
    kit.objs.insert(0, body)
bodym, img, tris = kit.finish("yrka", OUT, res=2048, origin="keep", samples=32, ao_min=0.4, pack=0.004, ao_blur=2)

# --- Клипы: прежние, поверх сутулого покоя -----------------------------------------------
bpy.context.scene.render.fps = 24
clip = lambda name, length, keys: an.clip(arm, name, length, keys)
mirror, cycle = an.mirror, an.cycle
IDLE_A = {"spine": (-6, 0, 0), "chest": (-4, 0, 2), "neck": (6, 0, 0), "head": (10, -14, 22), "jaw": (12, 0, 0),
          "upper_arm.L": (6, 0, 4), "upper_arm.R": (4, 0, -3), "forearm.L": (10, 0, 0), "forearm.R": (14, 0, 0)}
IDLE_B = {"spine": (-9, 0, 0), "chest": (-7, 0, -1), "neck": (8, 0, 0), "head": (6, -18, 26), "jaw": (18, 0, 0),
          "upper_arm.L": (9, 0, 5), "upper_arm.R": (7, 0, -4), "forearm.L": (14, 0, 0), "forearm.R": (18, 0, 0)}
clip("idle", 49, {1: IDLE_A, 25: IDLE_B, 49: IDLE_A})
ST_BASE = {"hips@loc": (0, 0, -0.1), "spine": (-14, 0, 0), "chest": (-10, 0, 0), "neck": (14, 0, 0), "head": (10, -10, 18)}
ST_A = dict(ST_BASE, **{"thigh.L": (34, 0, 0), "shin.L": (-30, 0, 0), "foot.L": (-6, 0, 0), "thigh.R": (-14, 0, 0), "shin.R": (-26, 0, 0), "foot.R": (16, 0, 0),
                        "upper_arm.L": (-16, 0, 3), "upper_arm.R": (20, 0, -3), "forearm.L": (8, 0, 0), "forearm.R": (16, 0, 0), "hips": (0, 0, 4)})
ST_B = dict(ST_BASE, **{"hips@loc": (0, 0, -0.06), "thigh.L": (10, 0, 0), "shin.L": (-12, 0, 0), "thigh.R": (12, 0, 0), "shin.R": (-58, 0, 0), "foot.R": (10, 0, 0),
                        "upper_arm.L": (0, 0, 3), "upper_arm.R": (4, 0, -3), "forearm.L": (10, 0, 0), "forearm.R": (12, 0, 0), "hips": (0, 0, 0)})
clip("stalk", 41, cycle(ST_A, ST_B, 20))
RUN_BASE = {"root": (-62, 0, 0), "root@loc": (0, 0, -0.03), "spine": (-8, 0, 0), "chest": (-6, 0, 0), "neck": (52, 0, 0), "head": (24, 0, 10)}
RUN_A = dict(RUN_BASE, **{"hips": (6, 0, 0), "thigh.L": (110, 0, 0), "shin.L": (-70, 0, 0), "thigh.R": (95, 0, 0), "shin.R": (-80, 0, 0),
                          "upper_arm.L": (-10, 0, 0), "upper_arm.R": (10, 0, 0), "forearm.L": (40, 0, 0), "forearm.R": (30, 0, 0), "hand.L": (30, 0, 0), "hand.R": (30, 0, 0)})
RUN_B = dict(RUN_BASE, **{"root@loc": (0, 0, 0.1), "hips": (-8, 0, 0), "thigh.L": (40, 0, 0), "shin.L": (-20, 0, 0), "thigh.R": (30, 0, 0), "shin.R": (-30, 0, 0),
                          "upper_arm.L": (55, 0, 0), "upper_arm.R": (70, 0, 0), "forearm.L": (-10, 0, 0), "forearm.R": (0, 0, 0), "hand.L": (-20, 0, 0), "hand.R": (-20, 0, 0), "chest": (6, 0, 0)})
clip("run", 15, {1: RUN_A, 8: RUN_B, 15: RUN_A})
SN_A = {"hips@loc": (0, 0, -0.12), "spine": (-24, 0, 0), "chest": (-14, 0, 0), "neck": (20, 0, 0), "head": (-10, 8, 6), "jaw": (6, 0, 0),
        "thigh.L": (20, 0, 0), "shin.L": (-34, 0, 0), "thigh.R": (16, 0, 0), "shin.R": (-30, 0, 0), "upper_arm.L": (14, 0, 4), "upper_arm.R": (10, 0, -4)}
SN_B = dict(SN_A, **{"neck": (28, 0, 0), "head": (-18, -6, 14), "chest": (-11, 0, 0), "jaw": (14, 0, 0)})
SN_C = dict(SN_A, **{"neck": (24, 0, 0), "head": (-4, 14, -4), "jaw": (4, 0, 0)})
clip("sniff", 49, {1: SN_A, 9: SN_B, 13: SN_A, 25: SN_C, 33: SN_B, 37: SN_C, 49: SN_A})
LU_0 = {"hips@loc": (0, 0, 0), "spine": (-6, 0, 0)}
LU_1 = {"hips@loc": (0, -0.08, -0.25), "spine": (-30, 0, 0), "chest": (-20, 0, 0), "neck": (30, 0, 0), "head": (6, 0, 0), "jaw": (10, 0, 0),
        "thigh.L": (60, 0, 0), "shin.L": (-90, 0, 0), "thigh.R": (60, 0, 0), "shin.R": (-90, 0, 0), "foot.L": (30, 0, 0), "foot.R": (30, 0, 0),
        "upper_arm.L": (-30, 0, 10), "upper_arm.R": (-30, 0, -10)}
LU_2 = {"hips@loc": (0, 0.35, 0.12), "root": (-30, 0, 0), "spine": (-10, 0, 0), "chest": (-6, 0, 0), "neck": (30, 0, 0), "head": (14, 0, 0), "jaw": (45, 0, 0),
        "thigh.L": (-20, 0, 0), "shin.L": (-10, 0, 0), "thigh.R": (-10, 0, 0), "shin.R": (-20, 0, 0),
        "upper_arm.L": (120, 0, 20), "upper_arm.R": (120, 0, -20), "forearm.L": (-20, 0, 0), "forearm.R": (-20, 0, 0)}
clip("lunge", 17, {1: LU_0, 6: LU_1, 12: LU_2, 17: LU_2})
PK_A = {"hips@loc": (0.0, 0, -0.04), "spine": (-6, 0, -16), "chest": (-6, 0, -18), "neck": (6, 0, -20), "head": (4, -20, -62), "jaw": (8, 0, 0),
        "upper_arm.L": (30, 0, 0), "forearm.L": (40, 0, 0), "upper_arm.R": (6, 0, -6)}
PK_B = dict(PK_A, **{"head": (6, -30, -78), "jaw": (20, 0, 0), "spine": (-6, 0, -20)})
clip("peek", 61, {1: PK_A, 30: PK_B, 34: PK_B, 61: PK_A})
PI_A = {"hips@loc": (0, 0, -0.18), "spine": (-30, 0, 0), "chest": (-24, 0, 0), "neck": (34, 0, 0), "head": (-8, 0, 10), "jaw": (40, 0, 0),
        "thigh.L": (40, 0, 0), "shin.L": (-60, 0, 0), "thigh.R": (36, 0, 0), "shin.R": (-56, 0, 0),
        "upper_arm.L": (110, 0, 20), "upper_arm.R": (40, 0, -20), "forearm.L": (-40, 0, 0), "forearm.R": (20, 0, 0)}
PI_B = dict(PI_A, **{"upper_arm.L": (40, 0, 20), "upper_arm.R": (110, 0, -20), "forearm.L": (20, 0, 0), "forearm.R": (-40, 0, 0), "jaw": (20, 0, 0), "head": (-14, 0, -6)})
clip("pin", 21, {1: PI_A, 11: PI_B, 21: PI_A})

an.export_rigged(arm, bodym, OUT, "yrka")
# Где глаза в покое — для катафотов в Godot (Creatures._make_yrka_skeletal)
eye_pts = [Vector((ex, 0.098, 1.574)) for ex in (-0.033, 0.033)]
print("[OK] yrka v3 (HBM) tris:", tris, "bones:", len(BONES))
