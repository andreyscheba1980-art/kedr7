# «Кедр-7» — Жердяй на болванке Blender Studio «Human Base Meshes» (CC0, v1.4.1, realistic_body_male).
# Иссохший человек, растянутый до высоты елей (~4.8 м): ноги и шея длиннее в разы, руки свисают до колен,
# кисти огромные. Тёмный рваный ватник с капюшоном, надвинутым на лицо; голени и ступни голые, почерневшие.
# Голова склонена набок. Виден только издалека — главное в нём силуэт.
# Скелет и клипы — как у прежнего Жердяя из human_rig.py (idle, walk, run, still, peek, bend, bend83, bend45, reach).
# Нос в +Y (в Godot −Z), ноги на z = 0.
# Запуск: blender --background --python zherdyai_hbm.py -- <bundle.blend> <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, hbm, anatomy as an
from anatomy import frosted
from mathutils import Vector, noise

BUNDLE, OUT = sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()

SKIN = frosted("zh_skin", (0.15, 0.145, 0.15), frost=(0.55, 0.6, 0.66), amount=0.12, top_bias=0.7,
               dark=(0.03, 0.028, 0.03), dark_z=0.45)
VAT = frosted("zh_vat", (0.07, 0.072, 0.068), frost=(0.62, 0.68, 0.75), amount=0.22, top_bias=0.9)
PANTS = frosted("zh_pants", (0.06, 0.062, 0.06), amount=0.15)
WAD = kit.mat("zh_wad", (0.5, 0.48, 0.42), rough=0.95, noise=0.3, noise_scale=40)
VOID = kit.mat("zh_void", (0.008, 0.008, 0.01), rough=0.9)

# --- Пропорции: исходная высота болванки → новая --------------------------------------------
FOOT_K, LEG_K, TORSO_K, NECK_K, HEAD_K = 1.3, 3.5, 2.5, 4.0, 1.15
Z_FOOT, Z_HIP, Z_SH, Z_NECK = 0.08, 0.92, 1.43, 1.50


def Z(z):
    """Высота: стопы чуть выше, ноги ×3.5, туловище ×2.5, шея ×4, голова ×1.15."""
    if z < Z_FOOT:
        return z * FOOT_K
    zf = Z_FOOT * FOOT_K
    if z < Z_HIP:
        return zf + (z - Z_FOOT) * LEG_K
    zh = zf + (Z_HIP - Z_FOOT) * LEG_K
    if z < Z_SH:
        return zh + (z - Z_HIP) * TORSO_K
    zs = zh + (Z_SH - Z_HIP) * TORSO_K
    if z < Z_NECK:
        return zs + (z - Z_SH) * NECK_K
    return zs + (Z_NECK - Z_SH) * NECK_K + (z - Z_NECK) * HEAD_K


def sm(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def torso_map(p):
    """Всё, кроме рук: вытянуть по высоте, ноги и шею — истончить к оси."""
    x, y, z = p.x, p.y, p.z
    zn = Z(z)
    # подбородок едет вместе с головой, иначе челюсть растянется по шее
    zh = Z(Z_NECK) + (z - Z_NECK) * HEAD_K
    w = sm(1.43, 1.46, z) * sm(0.03, 0.06, y)
    zn = zn + (zh - zn) * w
    if z < Z_HIP + 0.02:
        cx = 0.1 if x > 0 else -0.1
        k = 0.72 if z > Z_FOOT + 0.04 else 0.9
        x = cx * 0.85 + (x - cx) * k
        y = y * (k if z > Z_FOOT + 0.04 else 1.0)
        if z < Z_FOOT + 0.04:
            y = 0.03 + (y - 0.03) * 1.3       # длинные ступни
    elif z < Z_SH:
        x *= 0.92
        y *= 0.88                              # плоская впалая грудь
    elif z < Z_NECK + 0.02 and w < 0.5:
        x *= 0.78
        y = 0.01 + (y - 0.01) * 0.8
    return Vector((x, y, zn))


# --- Болванка и её A-поза ----------------------------------------------------------------
body = hbm.load_body(BUNDLE, SKIN)
B0 = {b[0]: (Vector(b[1]), Vector(b[2])) for b in hbm.human_bones(0.0)}

# Рука: цепь плечо → локоть → запястье → кончики пальцев; каждый отрезок длиннее в свой раз
ARM_K = (3.6, 4.4, 3.0)          # кончики пальцев — у колен
ARM_THIN = (0.75, 0.68, 1.15)
chains = {}
for n in ("L", "R"):
    j0 = [B0[f"upper_arm.{n}"][0], B0[f"upper_arm.{n}"][1], B0[f"forearm.{n}"][1], B0[f"hand.{n}"][1]]
    j1 = [torso_map(j0[0])]
    for i in range(3):
        j1.append(j1[-1] + (j0[i + 1] - j0[i]) * ARM_K[i])
    chains[n] = (j0, j1)


def arm_map(p, n):
    j0, j1 = chains[n]
    best = None
    for i in range(3):
        a, b = j0[i], j0[i + 1]
        ab = b - a
        t = (p - a).dot(ab) / ab.length_squared
        tc = max(0.0, min(1.0, t))
        d = (p - (a + ab * tc)).length
        if best is None or d < best[0]:
            best = (d, i, t if i == 2 else tc)   # за кончиками пальцев — продолжаем отрезок кисти
    _, i, t = best
    a, b = j0[i], j0[i + 1]
    perp = p - (a + (b - a) * t)
    return j1[i] + (j1[i + 1] - j1[i]) * t + perp * ARM_THIN[i]


for v in body.data.vertices:
    p = v.co.copy()
    n = "R" if p.x > 0 else "L"
    a = sm(0.17, 0.235, abs(p.x)) * (1.0 - sm(1.42, 1.46, p.z)) * sm(0.55, 0.62, p.z)
    tm = torso_map(p)
    v.co = tm if a <= 0 else tm.lerp(arm_map(p, n), a)
body.data.update()
an.sculpt(body, amp=0.006, scale=18.0, seed=11.0)       # иссохшая, бугристая кожа
an.sculpt(body, amp=0.003, scale=60.0, seed=12.0)

# Скелет по пересчитанным суставам
bones = []
for bn, h, t, par in hbm.human_bones(0.0):
    if bn.startswith(("upper_arm.", "forearm.", "hand.")):
        n = bn[-1]
        k = {"upper_arm": 0, "forearm": 1, "hand": 2}[bn.split(".")[0]]
        h1, t1 = chains[n][1][k], chains[n][1][k + 1]
    else:
        h1, t1 = torso_map(Vector(h)), torso_map(Vector(t))
        if bn == "root":
            h1, t1 = Vector((0, 0, 0)), Vector((0, 0, 0.3))
    bones.append((bn, tuple(h1), tuple(t1), par))
BN = {b[0]: (Vector(b[1]), Vector(b[2])) for b in bones}


def arm_part(c, n):
    """Доля вдоль руки: 0 плечо, 1 локоть, 2 запястье, 3 кончики (по новой цепи)."""
    j = chains[n][1]
    best = None
    for i in range(3):
        ab = j[i + 1] - j[i]
        t = max(0.0, min(1.0, (c - j[i]).dot(ab) / ab.length_squared))
        d = (c - (j[i] + ab * t)).length
        if best is None or d < best[0]:
            best = (d, i + t)
    return best[0], best[1]


def is_arm(c):
    n = "R" if c.x > 0 else "L"
    d, s = arm_part(c, n)
    return d < 0.09 and s > 0.15


def arm_s(c):
    return arm_part(c, "R" if c.x > 0 else "L")[1]


# --- Одежда ----------------------------------------------------------------------------------
Z_HEM = Z(0.74)
vat = hbm.shell(body, "vatnik", lambda c: (Z_HEM - 0.1 < c.z < Z(1.47) and not is_arm(c)) or (is_arm(c) and arm_s(c) < 1.45),
                0.09, VAT, smooth=24)
for v in vat.data.vertices:                       # стёганка, вытянутая вместе с ним
    v.co += v.normal * 0.022 * (0.5 + 0.5 * math.cos(v.co.z * math.tau / 0.2))
vat.data.update()
an.sculpt(vat, amp=0.04, scale=3.0, seed=1.0)
an.rag_hem(vat, Z_HEM, amp=0.25, scale=3.0)
hbm.cut_faces(vat, lambda c: is_arm(c) and arm_s(c) > 1.25 + noise.noise(c * 6.0) * 0.18)        # рваные рукава
hbm.cut_faces(vat, lambda c: c.y > 0.0 and abs(c.x) < 0.03 + 0.05 * noise.noise(c * 5.0) ** 2 and Z(1.0) < c.z < Z(1.36))  # прореха
wads = hbm.shell(body, "wad", lambda c: Z_HEM - 0.05 < c.z < Z(0.8) and not is_arm(c), 0.04, WAD, 0.03, 6.0, smooth=10)
an.rag_hem(wads, Z(0.765), amp=0.12, scale=5.0, below=False)
an.rag_hem(wads, Z_HEM - 0.05, amp=0.12, scale=5.0)
pants = hbm.shell(body, "pants", lambda c: Z(0.42) < c.z < Z(0.96) and not is_arm(c), 0.03, PANTS, 0.02, 4.0, smooth=10)
an.rag_hem(pants, Z(0.5), amp=0.3, scale=3.5)
# Капюшон надвинут на лицо: лица не видно, только темнота
FACE_Z0, FACE_Z1 = Z(1.475), Z(1.64)
# Капюшон — объёмный кокон вокруг головы, вытянутый вперёд за лицо; спереди проём, внутри темнота
HC = Vector((0.0, 0.045, Z(1.585)))
hood = kit.sphere("hood", 1.0, tuple(HC), VAT, scale=(0.125, 0.165, 0.16), segs=22, rings=16)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
hbm.cut_faces(hood, lambda c: (c.y > 0.13 and ((c.x / 0.08) ** 2 + ((c.z - HC.z) / 0.1) ** 2) < 1.0) or c.z < Z(1.47))
for v in hood.data.vertices:
    if v.co.z < HC.z and v.co.y < 0.12:          # полы капюшона ложатся на плечи
        v.co.x *= 1.0 + 0.6 * sm(HC.z, Z(1.47), v.co.z)
        v.co.y = HC.y + (v.co.y - HC.y) * (1.0 + 0.3 * sm(HC.z, Z(1.47), v.co.z))
    # острый мысок сзади-сверху, как у капюшона ватника
    k = sm(HC.y - 0.02, HC.y - 0.12, v.co.y) * sm(HC.z - 0.02, HC.z + 0.1, v.co.z)
    v.co.y -= 0.11 * k
    v.co.z += 0.08 * k
    v.co.x *= 1.0 - 0.35 * k
    # козырёк: верхний край проёма нависает и опускается на лицо
    if v.co.y > 0.1 and v.co.z > HC.z + 0.02:
        kk = sm(0.1, 0.2, v.co.y)
        v.co.y += 0.03 * kk
        v.co.z -= 0.035 * kk
hood.data.update()
an.sculpt(hood, amp=0.012, scale=14.0, seed=8.0)
# Чёрное «лицо» под капюшоном и глаза перед ним (центры глаз — для отсветов в Godot)
kit.sphere("faceshade", 1.0, (0.0, 0.15, HC.z - 0.01), VOID, scale=(0.088, 0.06, 0.115), segs=12, rings=8)   # глотает нос и лицо
shade = kit.objs[-1]
EYE_Z = Z(1.574)
for s in (-1, 1):
    kit.sphere("eye", 0.008, (0.03 * s, 0.15, EYE_Z), VOID, segs=6, rings=4)
eyes = kit.objs[-2:]

extra = [vat, wads, pants, hood, shade] + eyes
arm = an.armature(bones, "ZherdArm")
hbm.bind(arm, body, extra)

# --- Поза покоя: руки висят до колен, плечи опущены, голова склонена набок ------------------
aims = [("chest", (0, 0.12, 1)), ("neck", (0, 0.32, 1)), ("head", (0.42, 0.18, 1))]
for n, s in (("L", -1), ("R", 1)):
    aims += [(f"upper_arm.{n}", (0.1 * s, 0.03, -1)), (f"forearm.{n}", (0.04 * s, 0.06, -1)), (f"hand.{n}", (0.02 * s, 0.05, -1))]
hbm.pose_to_rest(arm, [body] + extra, aims)
for e in eyes:
    c = sum((e.matrix_world @ v.co for v in e.data.vertices), Vector()) / len(e.data.vertices)
    print("EYE_GODOT", round(c.x, 3), round(c.z, 3), round(-c.y, 3))
bpy.context.view_layer.update()
for nm in ("head", "chest", "hand.R", "shin.R"):
    pb = arm.pose.bones[nm]
    print("BONE", nm, tuple(round(x, 3) for x in (arm.matrix_world @ pb.head)), tuple(round(x, 3) for x in (arm.matrix_world @ pb.tail)))

hbm.decimate([(body, 0.3), (vat, 0.3), (wads, 0.4), (pants, 0.35)])
kit.objs = [o for o in kit.objs if o.name in bpy.data.objects and o.type == "MESH"]
bodym, img, tris = kit.finish("zherdyai", OUT, res=2048, origin="keep", samples=32, ao_min=0.4, pack=0.004, ao_blur=2)

# --- Клипы (как у прежнего Жердяя), медленнее и тяжелее ---------------------------------------
bpy.context.scene.render.fps = 24
clip = lambda nm, length, keys: an.clip(arm, nm, length, keys)
mix = lambda *ps: {k: v for p in ps for k, v in p.items()}
ARMS = {"forearm.L": (5, 0, 0), "forearm.R": (5, 0, 0)}
clip("idle", 120, {1: mix(ARMS, {"chest": (-2, 0, 0)}), 60: mix(ARMS, {"chest": (-3, 0, 1), "hips": (0, 0, 1.0), "head": (2, 3, 0)}),
                   120: mix(ARMS, {"chest": (-2, 0, 0)})})
WA = mix(ARMS, {"thigh.L": (20, 0, 0), "shin.L": (-6, 0, 0), "foot.L": (-10, 0, 0), "thigh.R": (-14, 0, 0), "shin.R": (-18, 0, 0), "foot.R": (12, 0, 0),
                "upper_arm.L": (-10, 0, 0), "upper_arm.R": (12, 0, 0), "hips": (0, 0, 3), "chest": (-3, 2, -2)})
WB = mix(ARMS, {"thigh.L": (3, 0, 0), "shin.L": (-5, 0, 0), "thigh.R": (5, 0, 0), "shin.R": (-40, 0, 0), "foot.R": (8, 0, 0),
                "root@loc": (0, 0, 0.05), "chest": (-3, 0, 0)})
clip("walk", 57, an.cycle(WA, WB, 28))
RA = {"root@loc": (0, 0, 0.08), "thigh.L": (40, 0, 0), "shin.L": (-24, 0, 0), "thigh.R": (-24, 0, 0), "shin.R": (-56, 0, 0), "foot.R": (16, 0, 0),
      "upper_arm.L": (-30, 0, 0), "forearm.L": (30, 0, 0), "upper_arm.R": (34, 0, 0), "forearm.R": (36, 0, 0), "spine": (-12, 0, 0), "chest": (-8, 4, 0)}
RB = {"thigh.L": (8, 0, 0), "shin.L": (-48, 0, 0), "thigh.R": (16, 0, 0), "shin.R": (-16, 0, 0), "root@loc": (0, 0, 0.12),
      "forearm.L": (40, 0, 0), "forearm.R": (40, 0, 0), "spine": (-14, 0, 0)}
clip("run", 25, an.cycle(RA, RB, 12))
ST = mix(ARMS, {"head": (4, 0, 6), "neck": (3, 0, 2)})
clip("still", 120, {1: ST, 70: mix(ST, {"head": (5, 3, 9)}), 72: ST, 120: ST})
PK = mix(ARMS, {"spine": (0, 0, -8), "chest": (0, 0, -10), "neck": (0, 0, -8), "head": (0, -10, -20)})
clip("peek", 100, {1: PK, 50: mix(PK, {"head": (2, -14, -26)}), 60: PK, 100: PK})
BEND = mix(ARMS, {"spine": (-25, 0, 0), "chest": (-35, 0, 0), "neck": (35, 0, 0), "head": (25, 0, 6),
                  "upper_arm.L": (40, 0, 0), "upper_arm.R": (44, 0, 0)})
clip("bend", 80, {1: BEND, 40: mix(BEND, {"head": (29, 6, 10), "chest": (-37, 0, 0)}), 80: BEND})
B83 = mix(ARMS, {"hips": (-40, 0, 0), "thigh.L": (40, 0, 0), "thigh.R": (40, 0, 0), "spine": (-40, 0, 0), "chest": (-40, 0, 0),
                 "neck": (70, 0, 0), "head": (20, 0, 8), "upper_arm.L": (100, 0, 0), "upper_arm.R": (106, 0, 0)})
clip("bend83", 100, {1: B83, 50: mix(B83, {"head": (30, 4, 14)}), 60: B83, 100: B83})
B45 = mix(ARMS, {"hips": (-15, 0, 0), "thigh.L": (15, 0, 0), "thigh.R": (15, 0, 0), "spine": (-15, 0, 0), "chest": (-15, 0, 0),
                 "neck": (25, 0, 0), "head": (10, 0, 6), "upper_arm.L": (36, 0, 0), "upper_arm.R": (40, 0, 0)})
clip("bend45", 100, {1: B45, 50: mix(B45, {"head": (12, 6, 10)}), 60: B45, 100: B45})
RE = mix(ARMS, {"upper_arm.R": (80, 0, 0), "forearm.R": (10, 0, 0), "hand.R": (-10, 0, 0), "chest": (-10, 0, 0), "head": (6, 0, 8)})
clip("reach", 90, {1: ARMS, 30: RE, 60: mix(RE, {"hand.R": (10, 0, 0)}), 90: RE})

an.export_rigged(arm, bodym, OUT, "zherdyai")
if os.environ.get("PREVIEW"):
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.view_settings.exposure = 1.3       # материалы тёмные: для проверки формы высветляем
    sc.render.resolution_x, sc.render.resolution_y = 700, 1000
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    # Человек 1.75 м рядом — для масштаба
    kit.box("ref", (0.4, 0.25, 1.75), (1.2, 0, 0.875), kit.mat("ref", (0.6, 0.3, 0.2)), bevel=0.0)
    for tag, loc, tgt, lens in (("full", (2.6, 8.5, 2.4), (0.4, 0, 2.3), 35), ("head", (0.8, 1.6, 4.4), (0, 0, 4.4), 50),
                                ("side", (8.5, 0.5, 2.4), (0, 0, 2.3), 35)):
        cam.location = loc
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(OUT, f"_prev_zherdyai_{tag}.png")
        bpy.ops.render.render(write_still=True)
print("[OK] zherdyai (HBM) tris:", tris)
