# «Кедр-7» — люди эпилога (Свердловск, 1983) на реалистичной болванке Blender Studio «Human Base Meshes»
# (CC0, v1.4.1): мужская и женская (та же топология). Раньше — тела из простых форм (ep_people.py), лица как
# у кукол. Здесь: настоящая анатомия, роспись лица (face_paint.py), одежда оболочками, причёски, веки-кости.
# Скелет и клипы — те же, что у ep_people.py (берём оттуда блок клипов как есть): игра не меняется.
# Нос в +Y (в Godot −Z), ноги на z = 0.
# Запуск: VARIANT=officer1 blender --background --python ep_hbm.py -- <bundle.blend> <out_dir>
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, hbm, anatomy as an, face_paint
from mathutils import Vector

BUNDLE, OUT = sys.argv[-2], sys.argv[-1]
VAR = os.environ.get("VARIANT", "officer1")
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians

V = {
    "officer1": dict(h=1.0, fem=False, outfit="suit", hair="part", hair_col=(0.12, 0.09, 0.07), skin=(0.78, 0.6, 0.5),
                     cloth=(0.3, 0.32, 0.35), pants=(0.27, 0.29, 0.32), tie=(0.42, 0.1, 0.1), stubble=0.15),
    "officer2": dict(h=0.98, fem=False, outfit="suit", hair="bald", hair_col=(0.62, 0.6, 0.57), glasses=True, moustache=True, girth=1.12,
                     skin=(0.8, 0.6, 0.52), cloth=(0.33, 0.25, 0.18), pants=(0.3, 0.23, 0.17), tie=(0.15, 0.17, 0.25), stubble=0.1),
    "officer3": dict(h=1.03, fem=False, outfit="suit", hair="crew", hair_col=(0.5, 0.38, 0.24), girth=0.94,
                     skin=(0.84, 0.68, 0.58), cloth=(0.15, 0.17, 0.25), pants=(0.14, 0.16, 0.23), tie=(0.2, 0.24, 0.3), stubble=0.05),
    "uniform": dict(h=1.0, fem=False, outfit="uniform", hair="part", hair_col=(0.35, 0.33, 0.31), moustache=True,
                    skin=(0.76, 0.58, 0.48), cloth=(0.3, 0.32, 0.22), pants=(0.27, 0.29, 0.2), tie=(0.25, 0.26, 0.18), stubble=0.2),
    "guard": dict(h=1.01, fem=False, outfit="guard", hair="crew", hair_col=(0.2, 0.15, 0.1),
                  skin=(0.8, 0.62, 0.52), cloth=(0.29, 0.32, 0.21), pants=(0.26, 0.29, 0.19), tie=(0.26, 0.29, 0.19), stubble=0.25),
    "clerk1": dict(h=0.98, fem=True, outfit="dress", hair="bun", hair_col=(0.3, 0.18, 0.1),
                   skin=(0.86, 0.7, 0.6), cloth=(0.42, 0.14, 0.18), pants=(0.62, 0.5, 0.44), tie=(0.9, 0.88, 0.82)),
    "clerk2": dict(h=0.97, fem=True, outfit="cardigan", hair="perm", hair_col=(0.58, 0.55, 0.52), glasses=True, girth=1.1,
                   skin=(0.8, 0.64, 0.56), cloth=(0.36, 0.4, 0.46), pants=(0.6, 0.48, 0.42), tie=(0.82, 0.76, 0.64), skirt=(0.18, 0.18, 0.2)),
    "lab": dict(h=0.99, fem=False, outfit="lab", hair="part", hair_col=(0.45, 0.43, 0.4), glasses=True,
                skin=(0.8, 0.64, 0.55), cloth=(0.86, 0.86, 0.83), pants=(0.25, 0.25, 0.27), tie=(0.22, 0.22, 0.3), stubble=0.12),
    "civil1": dict(h=1.0, fem=False, outfit="coat", hair="part", hair_col=(0.2, 0.15, 0.1), hat="pirozhok",
                   skin=(0.78, 0.6, 0.5), cloth=(0.24, 0.19, 0.15), pants=(0.16, 0.16, 0.18), tie=(0.5, 0.42, 0.3), stubble=0.3),
    "civil2": dict(h=0.98, fem=True, outfit="coat", hair="bun", hair_col=(0.25, 0.16, 0.1), hat="fur",
                   skin=(0.84, 0.68, 0.58), cloth=(0.28, 0.2, 0.26), pants=(0.36, 0.3, 0.27), tie=(0.4, 0.3, 0.22)),
}[VAR]
FEM = V["fem"]
OUT_ = V["outfit"]
NAME = f"human_ep_{VAR}"
EYE_X, EYE_Y, EYE_Z = face_paint.EYE_X, face_paint.EYE_Y, face_paint.EYE_Z
EYE_R = 0.0124


def cm(name, col, rough=0.85, n=0.18, ns=40, wear=0.0):
    return kit.mat(f"{VAR}_{name}", col, rough=rough, noise=n, noise_scale=ns, wear=wear, dirt=0.4 if wear > 0 else 0.0,
                   wear_col=tuple(min(c * 1.35, 1) for c in col))


# --- Лицо: живое, по варианту ----------------------------------------------------------------
sk = V["skin"]
face_paint.LOOKS[VAR] = dict(
    socket=0.2, socket_col=tuple(c * 0.55 for c in sk),
    brow=V["hair_col"] if V["hair"] != "bald" else (0.5, 0.48, 0.45), brow_w=0.7 if FEM else 1.05,
    lips=(0.62, 0.22, 0.24) if FEM else (sk[0] * 0.78, sk[1] * 0.5, sk[2] * 0.48),
    stubble=tuple(c * 0.55 for c in sk), stubble_amt=0.0 if FEM else V.get("stubble", 0.15),
    flush=(0.85, 0.45, 0.42), flush_amt=0.3 if FEM else 0.18, nose=0.08, lash=0.85 if FEM else 0.4)
SKIN = face_paint.face_mat(f"{NAME}_skin", sk, 0.0, VAR)
WHITE = kit.mat(f"{NAME}_sclera", (0.78, 0.76, 0.72), rough=0.4)
IRIS = kit.mat(f"{NAME}_iris", (0.12, 0.09, 0.06) if VAR not in ("officer3", "clerk1") else (0.18, 0.24, 0.3), rough=0.3)
HAIR = cm("hair", V["hair_col"], 0.9, 0.35, 160)
body = hbm.load_body(BUNDLE, SKIN, fem=FEM)
me = body.data

# Полнота: живот и бока шире (полковник, архивариус) — до разметки одежды
g = V.get("girth", 1.0)
if g != 1.0:
    for v in me.vertices:
        p = v.co
        w = max(0.0, 1.0 - abs(p.z - 1.08) / 0.3) * (1.0 if abs(p.x) < 0.2 else 0.0)
        p.x *= 1.0 + (g - 1.0) * w
        p.y = 0.01 + (p.y - 0.01) * (1.0 + (g - 1.0) * 1.3 * w)
    me.update()
an.sculpt(body, amp=0.0008, scale=60.0, seed=11.0)

bones = hbm.human_bones(0.0)
B = {b[0]: (Vector(b[1]), Vector(b[2])) for b in bones}
arm_lower = lambda c, frac: hbm.arm_lower(B, c, frac)


def front_y(z, x=0.0, band=0.02):
    """Насколько вперёд выдаётся тело на высоте z (для галстука, пуговиц)."""
    ys = [v.co.y for v in me.vertices if abs(v.co.z - z) < band and abs(v.co.x - x) < 0.03]
    return max(ys) if ys else 0.12


# --- Глаза и веки ----------------------------------------------------------------------------
extra = []
lids = []
for s in (-1, 1):
    kit.sphere("sclera", EYE_R, (EYE_X * s, EYE_Y, EYE_Z), WHITE, segs=10, rings=7)
    kit.sphere("iris", 0.0056, (EYE_X * s, EYE_Y + EYE_R - 0.0015, EYE_Z), IRIS, scale=(1, 0.45, 1), segs=8, rings=5)
    extra += kit.objs[-2:]
    lid = kit.sphere(f"lid{'L' if s < 0 else 'R'}", 0.0138, (EYE_X * s, EYE_Y + 0.0012, EYE_Z + 0.0066), SKIN, scale=(1.1, 1.0, 0.62), segs=10, rings=6)
    lids.append(lid)

# --- Причёска --------------------------------------------------------------------------------
hair = V["hair"]
if hair in ("part", "crew"):
    off = 0.009 if hair == "part" else 0.005
    def male_hair(c):
        if abs(c.x) > 0.1:
            return False
        if c.y > 0.075:                       # лоб: линия волос
            return c.z > 1.612
        if c.y > 0.03:                        # виски
            return c.z > 1.575 or (abs(c.x) > 0.068 and c.z > 1.548)
        return c.z > 1.528                    # затылок
    h = hbm.shell(body, "hair", male_hair, off, HAIR, 0.003, 90.0, smooth=10)
    extra.append(h)
elif hair == "bald":
    h = hbm.shell(body, "hair", lambda c: 1.53 < c.z < 1.63 and c.y < 0.03 and abs(c.x) < 0.098, 0.006, HAIR, 0.003, 120.0, smooth=4)
    extra.append(h)
elif hair == "bun":
    def fem_hair(c):
        if abs(c.x) > 0.11:
            return False
        if c.y > 0.075:
            return c.z > 1.61
        if c.y > 0.02:
            return c.z > 1.56 or (abs(c.x) > 0.072 and c.z > 1.53)    # волосы закрывают верх ушей
        return c.z > 1.5
    h = hbm.shell(body, "hair", fem_hair, 0.013, HAIR, 0.002, 60.0, smooth=18)
    bun = kit.sphere("bun", 0.046, (0.0, -0.085, 1.64), HAIR, scale=(1.0, 0.85, 0.9), segs=12, rings=8)
    an.sculpt(bun, amp=0.004, scale=40.0, seed=3.0)
    extra += [h, bun]
else:   # химия: пышно и кудряво
    h = hbm.shell(body, "hair", lambda c: (c.z > 1.585 or (c.y < 0.07 and c.z > 1.47)) and abs(c.x) < 0.11 and not (c.y > 0.05 and c.z < 1.6),
                  0.02, HAIR, 0.005, 45.0, smooth=12)
    extra.append(h)

if V.get("moustache"):
    GREY = cm("moust", tuple(c * 0.9 for c in V["hair_col"]), 0.9, 0.35, 120)
    must = hbm.shell(body, "moustache", lambda c: face_paint.MOUTH_Z + 0.003 < c.z < face_paint.MOUTH_Z + 0.022 and abs(c.x) < 0.035 and c.y > 0.1, 0.006, GREY, 0.002, 140.0, smooth=3)
    extra.append(must)

if V.get("glasses"):
    FRAME = kit.mat(f"{NAME}_frame", (0.08, 0.07, 0.06), rough=0.4)
    for s in (-1, 1):
        extra.append(kit.torus("lens", 0.0175, 0.0016, (EYE_X * s, 0.15, EYE_Z + 0.002), FRAME))
        kit.box("temple", (0.003, 0.12, 0.003), (0.071 * s, 0.09, EYE_Z + 0.004), FRAME, bevel=0.0)
        extra.append(kit.objs[-1])
    kit.box("bridge", (0.018, 0.003, 0.003), (0, 0.153, EYE_Z + 0.006), FRAME, bevel=0.0)
    extra.append(kit.objs[-1])


# --- Одежда ----------------------------------------------------------------------------------
def skirt(name, z_top, z_bot, r_top, r_bot, mat, n=24, rings=6, y_off=0.0):
    m = bpy.data.meshes.new(name)
    bm = bmesh.new()
    loops = []
    for i in range(rings):
        t = i / (rings - 1)
        z = z_top + (z_bot - z_top) * t
        rx = r_top[0] + (r_bot[0] - r_top[0]) * t
        ry = r_top[1] + (r_bot[1] - r_top[1]) * t
        loops.append([bm.verts.new((math.cos(a) * rx, y_off + math.sin(a) * ry, z)) for a in (j * math.tau / n for j in range(n))])
    for i in range(rings - 1):
        for j in range(n):
            bm.faces.new((loops[i][j], loops[i][(j + 1) % n], loops[i + 1][(j + 1) % n], loops[i + 1][j]))
    bm.normal_update(); bm.to_mesh(m); bm.free()
    o = bpy.data.objects.new(name, m)
    bpy.context.collection.objects.link(o)
    m.materials.append(mat)
    kit.objs.append(o)
    for v in o.data.vertices:                    # складки
        a = math.atan2(v.co.y - y_off, v.co.x)
        k = (z_top - v.co.z) / max(z_top - z_bot, 1e-3)
        r = 1.0 + 0.03 * k * math.sin(a * 9.0)
        v.co.x *= r
        v.co.y = y_off + (v.co.y - y_off) * r
    o.data.update()
    return o


def shoes(mat, h=0.075):
    parts = []
    for s in (-1, 1):
        ft = [v.co for v in me.vertices if v.co.z < 0.11 and v.co.x * s > 0.02]
        x0, x1 = min(p.x for p in ft), max(p.x for p in ft)
        y0, y1 = min(p.y for p in ft), max(p.y for p in ft)
        kit.box("shoe", (x1 - x0 + 0.014, y1 - y0 + 0.016, h), ((x0 + x1) / 2, (y0 + y1) / 2 + 0.004, h / 2), mat, bevel=0.025)
        parts.append(kit.objs[-1])
    return parts


CLOTH = cm("cloth", V["cloth"], 0.85, 0.16, 45, wear=0.15)
PANTS = cm("pants", V["pants"], 0.85, 0.15, 40)
LEATHER = cm("leather", (0.07, 0.055, 0.045), 0.45, 0.1, 30)
WHITE_C = cm("shirt", (0.86, 0.85, 0.8), 0.8, 0.06, 40)
TIE = cm("tie", V["tie"], 0.7, 0.12, 60)
dec = []
full_arm = lambda c: not arm_lower(c, 0.95)
cy = front_y(1.3)

if OUT_ in ("suit", "uniform", "guard", "lab", "coat"):
    jz = (0.76 if OUT_ in ("suit", "uniform") else (0.84 if OUT_ == "guard" else 0.82), 1.468)
    jacket = hbm.shell(body, "jacket", lambda c: jz[0] < c.z < jz[1] and full_arm(c), 0.04 if OUT_ != "coat" else 0.055, CLOTH, 0.004, 9.0, smooth=44)
    an.sculpt(jacket, amp=0.008, scale=5.0, seed=5.0)

    pants = hbm.shell(body, "pants", lambda c: 0.08 < c.z < 0.99 and abs(c.x) < 0.22, 0.018, PANTS, 0.003, 9.0, smooth=12)
    extra += [jacket, pants]
    dec += [(jacket, 0.35), (pants, 0.35)]
    if OUT_ in ("suit", "lab"):
        collar = hbm.shell(body, "collar", lambda c: 1.44 < c.z < 1.492 and abs(c.x) < 0.056 and c.y > -0.035, 0.013, WHITE_C, 0.0, 9.0, smooth=14)
        kit.box("tie", (0.036, 0.008, 0.3), (0.0, cy + 0.03, 1.27), TIE, bevel=0.004, rot=(-0.06, 0, 0))
        extra += [collar, kit.objs[-1]]
        for i in range(3):
            extra.append(kit.sphere("button", 0.007, (0.0, front_y(1.05 + i * 0.09) + 0.034, 1.05 + i * 0.09), LEATHER, segs=6, rings=4))
    if OUT_ in ("uniform", "guard"):
        BELT = cm("belt", (0.16, 0.1, 0.06), 0.5, 0.1, 30)
        GOLD = kit.mat(f"{NAME}_gold", (0.72, 0.56, 0.22), rough=0.35)
        belt = hbm.shell(body, "belt", lambda c: 0.95 < c.z < 1.01 and abs(c.x) < 0.24, 0.04, BELT, smooth=12)
        extra.append(belt)
        for s in (-1, 1):
            kit.box("epaulet", (0.05, 0.12, 0.008), (0.16 * s, 0.0, 1.452), GOLD if OUT_ == "uniform" else CLOTH, bevel=0.003)
            extra.append(kit.objs[-1])
        for i in range(4):
            extra.append(kit.sphere("button", 0.0065, (0.0, front_y(1.05 + i * 0.1) + 0.031, 1.05 + i * 0.1), GOLD, segs=6, rings=4))
        boots = hbm.shell(body, "boots", lambda c: 0.07 < c.z < 0.42, 0.026, LEATHER, 0.002, 20.0, smooth=16)
        extra.append(boots)
        extra += shoes(LEATHER, 0.1)
        if OUT_ == "guard":
            kit.box("holster", (0.06, 0.04, 0.12), (0.2, 0.03, 0.92), LEATHER, bevel=0.01)
            extra.append(kit.objs[-1])
            BLUE = cm("capband", (0.2, 0.34, 0.68), 0.7, 0.05, 30)
            band = skirt("capband", 1.668, 1.622, (0.1, 0.115), (0.098, 0.113), BLUE, n=24, rings=2, y_off=0.012)
            crown = skirt("capcrown", 1.712, 1.668, (0.132, 0.148), (0.102, 0.117), CLOTH, n=24, rings=3, y_off=0.012)
            kit.box("visor", (0.15, 0.06, 0.006), (0.0, 0.128, 1.628), LEATHER, bevel=0.0, rot=(0.25, 0, 0))
            extra += [band, crown, kit.objs[-1]]
    if OUT_ in ("lab", "coat"):
        hem = 0.52 if OUT_ == "lab" else 0.42
        sk_ = skirt("coatskirt", 0.88, hem, (0.2, 0.15), (0.26, 0.21), CLOTH, n=28, rings=6)
        an.sculpt(sk_, amp=0.006, scale=7.0, seed=8.0)
        extra.append(sk_)
    if OUT_ == "coat":
        SCARF = cm("scarf", V["tie"], 0.95, 0.3, 50)
        scarf = hbm.shell(body, "scarf", lambda c: 1.39 < c.z < 1.49 and abs(c.x) < 0.1, 0.035, SCARF, 0.004, 30.0, smooth=8)
        extra.append(scarf)
        if V.get("hat") == "pirozhok":
            K = cm("karakul", (0.13, 0.12, 0.11), 0.95, 0.5, 220)
            extra.append(skirt("pirozhok", 1.71, 1.612, (0.1, 0.115), (0.104, 0.119), K, n=24, rings=4, y_off=0.01))
        elif V.get("hat") == "fur":
            F = cm("furhat", (0.22, 0.16, 0.11), 0.95, 0.45, 160)
            fh = kit.sphere("furhat", 1.0, (0.0, 0.005, 1.648), F, scale=(0.118, 0.13, 0.085), segs=16, rings=10)
            an.sculpt(fh, amp=0.008, scale=30.0, seed=2.0)
            extra.append(fh)
        extra += shoes(LEATHER, 0.1)
    elif OUT_ in ("suit", "lab"):
        extra += shoes(LEATHER)
elif OUT_ in ("dress", "cardigan"):
    top_mat = CLOTH if OUT_ == "dress" else WHITE_C
    blouse = hbm.shell(body, "blouse", lambda c: 0.9 < c.z < 1.468 and not arm_lower(c, 0.9 if OUT_ == "dress" else 0.95), 0.016, top_mat, 0.002, 12.0, smooth=16)
    extra.append(blouse)
    dec.append((blouse, 0.4))
    skirt_mat = CLOTH if OUT_ == "dress" else cm("skirtcl", V.get("skirt", (0.2, 0.2, 0.22)), 0.85, 0.15, 40)
    sk_ = skirt("skirt", 0.98, 0.5, (0.17, 0.13), (0.22, 0.17), skirt_mat, n=26, rings=6)
    extra.append(sk_)
    # чулки: голени чуть темнее и глаже кожи
    STOCK = cm("stock", tuple(c * 0.75 for c in sk), 0.5, 0.04, 30)
    stock = hbm.shell(body, "stock", lambda c: 0.08 < c.z < 0.52, 0.002, STOCK, smooth=4)
    extra.append(stock)
    if OUT_ == "dress":
        collar = hbm.shell(body, "collar", lambda c: 1.44 < c.z < 1.488 and abs(c.x) < 0.058 and c.y > -0.035, 0.012, WHITE_C, smooth=14)
        extra.append(collar)
    else:
        card = hbm.shell(body, "cardigan", lambda c: 0.88 < c.z < 1.45 and full_arm(c) and not (abs(c.x) < 0.035 and c.y > 0.0), 0.03, CLOTH, 0.005, 50.0, smooth=18)
        extra.append(card)
        dec.append((card, 0.4))
    extra += shoes(LEATHER, 0.06)

# --- Скелет, привязка, поза покоя (руки по швам) ------------------------------------------------
arm = an.armature(bones, NAME + "_arm")
hbm.bind(arm, body, extra)
aims = []
for n, s in (("L", -1), ("R", 1)):
    aims += [(f"upper_arm.{n}", (0.06 * s, 0.02, -1)), (f"forearm.{n}", (0.03 * s, 0.08, -1)), (f"hand.{n}", (0.01 * s, 0.08, -1))]
hbm.pose_to_rest(arm, [body] + extra, aims)

# Веки — свои кости (добавляем после тепловой привязки, чтобы они не тянули лицо)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for s, n in ((-1, "L"), (1, "R")):
    eb = arm.data.edit_bones.new(f"lid.{n}")
    e = Vector((EYE_X * s, EYE_Y, EYE_Z))
    eb.head = e; eb.tail = e + Vector((0, 0.02, 0)); eb.roll = 0.0
    eb.parent = arm.data.edit_bones["head"]
bpy.ops.object.mode_set(mode="OBJECT")
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"
for lid, n in zip(lids, ("L", "R")):
    vg = lid.vertex_groups.new(name=f"lid.{n}")
    vg.add(list(range(len(lid.data.vertices))), 1.0, "REPLACE")
    lid.parent = arm
    lid.modifiers.new("Armature", "ARMATURE").object = arm

# --- Под PS1: голова — почти без потерь, тело и одежда — сильнее ---------------------------------
keep = body.vertex_groups.new(name="dec_keep")
keep.add([v.index for v in body.data.vertices if v.co.z < 1.43], 1.0, "REPLACE")
keep.add([v.index for v in body.data.vertices if v.co.z >= 1.43], 0.08, "REPLACE")
dm = body.modifiers.new("dec", "DECIMATE")
dm.ratio = 0.42
dm.vertex_group = "dec_keep"
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True); bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)
bpy.ops.object.modifier_apply(modifier="dec")
hbm.decimate(dec)
kit.objs = [o for o in kit.objs if o.name in bpy.data.objects and o.type == "MESH"]
bodym, img, tris = kit.finish(NAME, OUT, res=2048, origin="keep", samples=24, ao_min=0.5, pack=0.004, ao_blur=2,
                              uv_boost=(lambda c: c.z > 1.45 and abs(c.x) < 0.13, 2.6))

# --- Клипы: тот же набор, что у ep_people.py (блок оттуда — как есть) ------------------------------
bpy.context.scene.render.fps = 24
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ep_people.py"), encoding="utf-8").read()
a = src.index("ACTS = {}")
b = src.index('if os.environ.get("PREVIEW")')
ns = {"bpy": bpy, "math": math, "os": os, "D": D, "arm": arm, "Vector": Vector, "FEM": FEM, "V": V}
exec(compile(src[a:b], "ep_people_clips", "exec"), ns)
print("CLIPS", sorted(ns["ACTS"].keys()))

arm.scale = (V["h"],) * 3
an.export_rigged(arm, bodym, OUT, NAME)

if os.environ.get("PREVIEW"):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 600, 900
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    hz = V["h"]
    for tag, loc, tgt, lens, clipn in (("full", (1.1, 3.4, 1.0), (0, 0, 0.9), 50, "idle"), ("face", (0.18, 0.75, 1.6 * hz), (0, 0, 1.56 * hz), 60, "idle"),
                                       ("talk", (1.1, 3.4, 1.0), (0, 0, 0.9), 50, "talk"), ("sit", (2.6, 2.4, 0.9), (0, 0, 0.6), 50, "type")):
        tr = arm.animation_data.nla_tracks[clipn]
        tr.mute = False
        sc.frame_set(6)
        cam.location = loc
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        sc.render.filepath = os.path.join(OUT, f"_prev_{VAR}_{tag}.png")
        bpy.ops.render.render(write_still=True)
        tr.mute = True
print("[OK]", NAME, "tris:", tris)
