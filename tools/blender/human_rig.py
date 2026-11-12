# «Кедр-7» — люди и Жердяй со скелетом. Стиль берётся из переменной окружения STYLE:
#   driver  — Михалыч (тулуп, ушанка, седые усы)
#   hunter  — «охотник»-обмирало (восковое лицо, пустые глаза, ружьё за спиной)
#   shadow  — тень без лица (две тусклые точки на месте глаз)
#   noon    — Полуденница (белое, длинные чёрные волосы на лице, руки-прутья)
#   zherdyai — Жердяй, 3.4 м (рваный ватник, часы на запястье, кольцо, пальцы-ветки)
# Нос в +Y (в Godot −Z), ноги на z = 0. Жёсткая привязка частей к костям (PS1).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, sphere, mat
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
STYLE = os.environ.get("STYLE", "driver")
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians

PAL = {
    "driver": dict(coat=(0.36, 0.27, 0.18), pants=(0.18, 0.2, 0.24), boots=(0.12, 0.11, 0.1), belt=(0.1, 0.08, 0.06),
                   mitten=(0.25, 0.2, 0.15), face=(0.72, 0.56, 0.48), hat=(0.22, 0.17, 0.12)),
    "hunter": dict(coat=(0.27, 0.24, 0.19), pants=(0.2, 0.19, 0.17), boots=(0.1, 0.09, 0.08), belt=(0.12, 0.08, 0.05),
                   mitten=(0.22, 0.18, 0.14), face=(0.86, 0.86, 0.82), hat=(0.3, 0.27, 0.22)),
    "shadow": dict(coat=(0.035, 0.035, 0.04), pants=(0.035, 0.035, 0.04), boots=(0.03, 0.03, 0.035), belt=(0.03, 0.03, 0.035),
                   mitten=(0.035, 0.035, 0.04), face=(0.05, 0.05, 0.055), hat=(0.035, 0.035, 0.04)),
    "noon": dict(coat=(0.7, 0.69, 0.64), pants=(0.7, 0.69, 0.64), boots=(0.62, 0.6, 0.57), belt=(0.63, 0.62, 0.58),
                 mitten=(0.74, 0.72, 0.68), face=(0.56, 0.59, 0.62), hat=(0.025, 0.025, 0.03)),
    # Эпилог «Свердловск, 1983»: люди управления и улицы
    "officer": dict(coat=(0.2, 0.21, 0.23), pants=(0.17, 0.18, 0.2), boots=(0.06, 0.05, 0.05), belt=(0.55, 0.12, 0.1),
                    mitten=(0.78, 0.62, 0.52), face=(0.78, 0.62, 0.52), hat=(0.2, 0.15, 0.11)),
    "clerk": dict(coat=(0.36, 0.22, 0.28), pants=(0.62, 0.5, 0.44), boots=(0.08, 0.06, 0.06), belt=(0.82, 0.8, 0.74),
                  mitten=(0.82, 0.66, 0.56), face=(0.82, 0.66, 0.56), hat=(0.42, 0.28, 0.16)),
    "guard": dict(coat=(0.24, 0.29, 0.19), pants=(0.2, 0.24, 0.17), boots=(0.06, 0.05, 0.05), belt=(0.3, 0.2, 0.1),
                  mitten=(0.76, 0.6, 0.5), face=(0.76, 0.6, 0.5), hat=(0.2, 0.25, 0.17)),
    "civil": dict(coat=(0.22, 0.2, 0.18), pants=(0.15, 0.15, 0.17), boots=(0.08, 0.07, 0.06), belt=(0.18, 0.16, 0.14),
                  mitten=(0.2, 0.15, 0.12), face=(0.76, 0.6, 0.5), hat=(0.16, 0.15, 0.14)),
    "zherdyai": dict(coat=(0.24, 0.25, 0.22), pants=(0.2, 0.21, 0.19), boots=(0.13, 0.12, 0.12), belt=(0.15, 0.14, 0.12),
                     mitten=(0.13, 0.12, 0.12), face=(0.13, 0.12, 0.12), hat=(0.2, 0.21, 0.19)),
}[STYLE]
M = {k: mat(f"{STYLE}_{k}", v, rough=0.85, noise=0.25 if k in ("coat", "pants", "hat") else 0.12, noise_scale=16,
            wear=0.4 if k == "coat" else 0.0, dirt=0.7, wear_col=tuple(min(c * 1.6, 1) for c in v)) for k, v in PAL.items()}
VOID = mat("void", (0.008, 0.008, 0.01), rough=0.9)
WHITE = mat("white", (0.78, 0.78, 0.74), rough=0.8)
GUN = mat("gun", (0.18, 0.12, 0.08), rough=0.6, wear=0.5)
METAL = mat("metal", (0.4, 0.4, 0.42), rough=0.3, wear=0.6)
GOLD = mat("gold", (0.75, 0.6, 0.2), rough=0.3)
WAD = mat("wad", (0.66, 0.64, 0.56), rough=0.95)
FROST = mat("frost", (0.7, 0.76, 0.82), rough=0.6)

TALL = STYLE == "zherdyai"
OFFICE = STYLE in ("officer", "clerk", "guard")   # без варежек и валенок: голые руки, ботинки
K = 1.0                                   # масштаб тела по высоте
LEG = 1.75 if TALL else 0.92              # высота тазобедренного сустава
TORSO = 0.95 if TALL else 0.6             # от таза до плеч
NECK = 0.28 if TALL else (0.12 if STYLE == "noon" else 0.07)
ARM = 1.25 if TALL else (0.95 if STYLE == "noon" else 0.68)
SH = 0.2 if TALL else 0.22                # полуширина плеч
THIN = 0.62 if TALL else 1.0              # толщина конечностей

hip_z = LEG
sh_z = LEG + TORSO
head_z = sh_z + NECK
BONES = [
    ("root", (0, 0, 0), (0, 0, 0.2), None),
    ("hips", (0, 0, hip_z), (0, 0, hip_z + TORSO * 0.33), "root"),
    ("spine", (0, 0, hip_z + TORSO * 0.33), (0, 0, hip_z + TORSO * 0.66), "hips"),
    ("chest", (0, 0, hip_z + TORSO * 0.66), (0, 0, sh_z), "spine"),
    ("neck", (0, 0, sh_z), (0, 0.01, head_z), "chest"),
    ("head", (0, 0.01, head_z), (0, 0.02, head_z + 0.24), "neck"),
]
for s, n in ((-1, "L"), (1, "R")):
    BONES += [
        (f"upper_arm.{n}", (SH * s, 0, sh_z - 0.04), (SH * s + 0.04 * s, 0.02, sh_z - 0.04 - ARM * 0.47), "chest"),
        (f"forearm.{n}", (SH * s + 0.04 * s, 0.02, sh_z - 0.04 - ARM * 0.47), (SH * s + 0.03 * s, 0.05, sh_z - 0.04 - ARM * 0.92), f"upper_arm.{n}"),
        (f"hand.{n}", (SH * s + 0.03 * s, 0.05, sh_z - 0.04 - ARM * 0.92), (SH * s + 0.03 * s, 0.06, sh_z - 0.04 - ARM * 1.12), f"forearm.{n}"),
        (f"thigh.{n}", (0.11 * s, 0, hip_z), (0.11 * s, 0.02, hip_z * 0.5), "hips"),
        (f"shin.{n}", (0.11 * s, 0.02, hip_z * 0.5), (0.11 * s, 0, 0.08), f"thigh.{n}"),
        (f"foot.{n}", (0.11 * s, 0, 0.08), (0.11 * s, 0.2, 0.03), f"shin.{n}"),
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


def limb(name, a, b, r1, r2, m, verts=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=max(d.length, 0.001), location=(a + b) / 2)
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


def P(b, i):
    return Vector(B[b][i])


# --- Туловище ------------------------------------------------------------------
coat_long = STYLE in ("driver", "hunter", "shadow", "noon", "civil")
m = mark()
limb("pelvis", (0, 0, hip_z - 0.06), (0, 0, hip_z + TORSO * 0.33), 0.2 * THIN, 0.21 * THIN, M["coat"], 10)
if coat_long:
    # Полы тулупа — колокол до колен, на тазе
    limb("skirt", (0, 0.01, hip_z + 0.02), (0, 0.02, hip_z * 0.55), 0.22, 0.29, M["coat"], 10)
    blob("belt", (0, 0, hip_z + 0.04), 0.255, M["belt"], scale=(1, 1, 0.12), segs=12, rings=4)
elif STYLE == "clerk":
    limb("skirt", (0, 0.01, hip_z + 0.02), (0, 0.02, hip_z * 0.5), 0.21, 0.25, M["coat"], 10)   # платье до колен
elif OFFICE:
    limb("jacket_hem", (0, 0.0, hip_z + 0.04), (0, 0.01, hip_z - 0.16), 0.215, 0.225, M["coat"], 10)
    if STYLE == "guard":
        blob("belt", (0, 0, hip_z + 0.04), 0.225, M["belt"], scale=(1, 1, 0.12), segs=12, rings=4)
elif TALL:
    for s in (-1, 1):   # Жердяй: рваные полы ватника
        limb(f"rag{s}", (0.08 * s, 0.05, hip_z), (0.13 * s, 0.07, hip_z - 0.45), 0.07, 0.02, M["coat"], 5)
own("hips", since(m))
m = mark()
limb("belly", (0, 0, hip_z + TORSO * 0.33), (0, 0, hip_z + TORSO * 0.66), 0.21 * THIN, 0.22 * THIN, M["coat"], 10)
own("spine", since(m))
m = mark()
limb("ribs", (0, 0, hip_z + TORSO * 0.66), (0, 0, sh_z - 0.03), 0.22 * THIN, 0.18 * THIN, M["coat"], 10)
limb("shoulders", (-SH - 0.02, 0, sh_z - 0.05), (SH + 0.02, 0, sh_z - 0.05), 0.08 * THIN, 0.08 * THIN, M["coat"], 8)
if STYLE == "hunter":
    limb("gun_stock", (-0.22, -0.24, hip_z - 0.17), (0.25, -0.2, sh_z + 0.15), 0.022, 0.018, GUN, 5)
    limb("gun_barrel", (0.12, -0.21, sh_z - 0.05), (0.32, -0.19, sh_z + 0.33), 0.012, 0.012, METAL, 5)
if TALL:
    for i, (a, b) in enumerate([((-0.1, -0.08, sh_z - 0.2), (-0.16, -0.16, sh_z - 0.14)), ((0.12, -0.06, sh_z - 0.4), (0.19, -0.13, sh_z - 0.37))]):
        limb(f"wad{i}", a, b, 0.035, 0.005, WAD, 4)
    blob("frost_sh", (0.0, -0.02, sh_z - 0.02), 0.12, FROST, scale=(1.4, 0.8, 0.35), wobble=0.01)
if STYLE == "officer":
    box("shirt", (0.09, 0.02, 0.16), (0, 0.185, sh_z - 0.1), WHITE, 0.005)
    box("tie", (0.035, 0.022, 0.2), (0, 0.195, sh_z - 0.14), M["belt"], 0.004)
if STYLE == "clerk":
    box("blouse", (0.12, 0.02, 0.1), (0, 0.18, sh_z - 0.07), M["belt"], 0.005)
if STYLE == "guard":
    limb("strap", (-0.15, 0.17, sh_z - 0.02), (0.17, 0.17, hip_z + 0.06), 0.012, 0.012, M["belt"], 4)
    for s in (-1, 1):
        box(f"epaulet{s}", (0.1, 0.06, 0.015), (SH * s * 0.9, 0, sh_z - 0.0), mat("red_band", (0.6, 0.1, 0.08), rough=0.7), 0.004)
own("chest", since(m))
m = mark()
limb("neck_c", P("neck", 1), P("neck", 2), 0.055 * THIN, 0.05 * THIN, M["face"], 7)
if STYLE != "noon" and not TALL:
    limb("collar", (0, 0, sh_z - 0.05), (0, 0, sh_z + 0.045), 0.155, 0.115, M["coat"], 10)   # воротник
own("neck", since(m))

# --- Голова --------------------------------------------------------------------
m = mark()
hc = Vector((0, 0.0, head_z + 0.12))
blob("skull", hc, 0.105 if not TALL else 0.09, M["face"], scale=(0.95, 1.05, 1.15), segs=12, rings=9)
if STYLE in ("driver", "hunter", "shadow"):
    blob("hat_top", hc + Vector((0, 0, 0.08)), 0.13, M["hat"], scale=(1, 1, 0.62), wobble=0.006)
    for s in (-1, 1):
        box(f"flap{s}", (0.04, 0.12, 0.13), hc + Vector((0.11 * s, 0, -0.01)), M["hat"], 0.01)
    box("visor", (0.2, 0.04, 0.06), hc + Vector((0, 0.12, 0.09)), M["hat"], 0.01)
if STYLE == "driver":
    for s in (-1, 1):
        blob(f"eye{s}", hc + Vector((0.035 * s, 0.1, 0.02)), 0.012, VOID, segs=6, rings=4)
    box("moustache", (0.09, 0.03, 0.035), hc + Vector((0, 0.105, -0.05)), WHITE, 0.01)
    blob("nose", hc + Vector((0, 0.11, -0.01)), 0.02, M["face"], scale=(0.8, 1, 1.2), segs=6, rings=4)
elif STYLE == "hunter":
    for s in (-1, 1):
        blob(f"eye{s}", hc + Vector((0.037 * s, 0.1, 0.015)), 0.02, VOID, scale=(1, 0.6, 0.9), segs=8, rings=5)
    box("mouth", (0.065, 0.01, 0.008), hc + Vector((0, 0.108, -0.06)), VOID, 0.0)
elif STYLE == "noon":
    blob("hair_top", hc + Vector((0, -0.02, 0.03)), 0.125, M["hat"], scale=(1, 1.1, 1.12))
    limb("hair_back", hc + Vector((0, -0.08, 0.0)), (0, -0.16, hip_z + 0.1), 0.13, 0.1, M["hat"], 7)
    limb("strand_l", hc + Vector((-0.055, 0.11, 0.1)), hc + Vector((-0.05, 0.1, -0.42)), 0.05, 0.02, M["hat"], 5)
    limb("strand_r", hc + Vector((0.075, 0.105, 0.1)), hc + Vector((0.09, 0.095, -0.4)), 0.022, 0.012, M["hat"], 4)
    blob("one_eye", hc + Vector((0.035, 0.105, 0.015)), 0.016, VOID, segs=6, rings=4)
elif STYLE in ("officer", "clerk", "guard", "civil"):
    for s in (-1, 1):
        blob(f"eye{s}", hc + Vector((0.035 * s, 0.1, 0.02)), 0.011, VOID, segs=6, rings=4)
        box(f"brow{s}", (0.04, 0.012, 0.01), hc + Vector((0.036 * s, 0.103, 0.045)), M["hat"], 0.002)
    blob("nose", hc + Vector((0, 0.112, -0.01)), 0.018, M["face"], scale=(0.8, 1, 1.2), segs=6, rings=4)
    box("mouth", (0.04, 0.008, 0.006), hc + Vector((0, 0.104, -0.055)), mat("lips", (0.5, 0.28, 0.26), rough=0.7), 0.0)
    if STYLE == "clerk":
        blob("hair", hc + Vector((0, -0.015, 0.04)), 0.118, M["hat"], scale=(1, 1.05, 1.0), wobble=0.004)
        blob("bun", hc + Vector((0, -0.1, 0.08)), 0.055, M["hat"])
    elif STYLE == "guard":
        limb("cap_band", hc + Vector((0, 0, 0.065)), hc + Vector((0, 0, 0.11)), 0.118, 0.118, mat("red_band", (0.6, 0.1, 0.08), rough=0.7), 12)
        limb("cap_top", hc + Vector((0, -0.01, 0.11)), hc + Vector((0, -0.01, 0.14)), 0.14, 0.15, M["hat"], 12)
        box("cap_visor", (0.16, 0.08, 0.012), hc + Vector((0, 0.12, 0.075)), mat("visor", (0.05, 0.05, 0.05), rough=0.3), 0.003)
        box("cap_star", (0.02, 0.01, 0.02), hc + Vector((0, 0.12, 0.09)), GOLD, 0.0)
    elif STYLE == "civil":
        box("pirozhok", (0.22, 0.2, 0.09), hc + Vector((0, 0, 0.11)), M["hat"], 0.02)
    else:
        blob("hair", hc + Vector((0, -0.02, 0.05)), 0.112, M["hat"], scale=(1, 1.05, 0.85), wobble=0.003)
elif TALL:
    for s in (-1, 1):
        blob(f"eye{s}", hc + Vector((0.032 * s, 0.085, 0.02)), 0.016, VOID, segs=6, rings=4)
    limb("hood", hc + Vector((0, -0.05, 0.06)), hc + Vector((0, -0.09, -0.15)), 0.13, 0.11, M["coat"], 8)
own("head", since(m))

# --- Руки ------------------------------------------------------------------------
for s, n in ((-1, "L"), (1, "R")):
    a0, a1, a2, a3 = P(f"upper_arm.{n}", 1), P(f"forearm.{n}", 1), P(f"hand.{n}", 1), P(f"hand.{n}", 2)
    m = mark()
    limb(f"sleeve{n}", a0, a1, 0.075 * THIN, 0.065 * THIN, M["coat"], 7)
    blob(f"elbow{n}", a1, 0.062 * THIN, M["coat"])
    own(f"upper_arm.{n}", since(m))
    m = mark()
    bare = STYLE == "noon" or TALL
    skin_hand = OFFICE
    limb(f"fore{n}", a1, a2 if bare else a2 + Vector((0, 0, -0.035)), 0.062 * THIN if not bare else 0.035, 0.062 * THIN if not bare else 0.026, M["coat"] if not bare else M["face"], 7)
    if TALL and s < 0:
        limb("watch", a2 + Vector((0, 0, 0.05)), a2 + Vector((0, 0, 0.09)), 0.04, 0.04, METAL, 10)
    own(f"forearm.{n}", since(m))
    m = mark()
    if bare:
        for f in range(4):
            dx = (-0.02 + f * 0.013) * s
            p0 = a2 + Vector((dx, 0, -0.02))
            p1 = p0 + Vector((dx * 0.6, 0.02, -0.13 if not TALL else -0.18))
            p2 = p1 + Vector((dx, 0.0, -0.13 if not TALL else -0.2))
            limb(f"f{n}{f}a", p0, p1, 0.009, 0.007, M["face"], 4)
            limb(f"f{n}{f}b", p1, p2, 0.007, 0.002, M["face"], 4)
            if TALL and s > 0 and f == 2:
                limb("ring", p0 + Vector((0, 0, -0.04)), p0 + Vector((0, 0, -0.055)), 0.013, 0.013, GOLD, 8)
    elif skin_hand:
        blob(f"hand{n}", a2 + Vector((0, 0.01, -0.05)), 0.042, M["face"], scale=(0.75, 0.9, 1.3))
    else:
        blob(f"mitten{n}", a2 + Vector((0, 0.01, -0.035)), 0.055, M["mitten"], scale=(0.95, 0.9, 1.35))
    own(f"hand.{n}", since(m))
# --- Ноги ------------------------------------------------------------------------
for s, n in ((-1, "L"), (1, "R")):
    l0, l1, l2, l3 = P(f"thigh.{n}", 1), P(f"shin.{n}", 1), P(f"foot.{n}", 1), P(f"foot.{n}", 2)
    m = mark(); limb(f"thigh{n}", l0, l1, 0.085 * THIN, 0.07 * THIN, M["pants"], 7); blob(f"knee{n}", l1, 0.066 * THIN, M["pants"]); own(f"thigh.{n}", since(m))
    m = mark()
    if TALL:
        limb(f"shin{n}", l1, l2, 0.05, 0.03, M["face"], 6)
    elif OFFICE:
        limb(f"shin{n}", l1, l2, 0.06 if STYLE != "clerk" else 0.045, 0.055 if STYLE != "clerk" else 0.04, M["pants"], 7)
    else:
        limb(f"shin{n}", l1, l2, 0.068, 0.07, M["boots"], 7)   # валенок до колена
    own(f"shin.{n}", since(m))
    m = mark()
    if TALL:
        limb(f"foot{n}", l2, l3 + Vector((0, 0.06, 0)), 0.03, 0.015, M["face"], 5)
    elif OFFICE:
        box(f"shoe{n}", (0.09, 0.24, 0.07), (l2 + l3) / 2 + Vector((0, 0.02, -0.01)), M["boots"], 0.015)
    else:
        box(f"boot{n}", (0.11, 0.26, 0.1), (l2 + l3) / 2 + Vector((0, 0.02, 0.0)), M["boots"], 0.02)
    own(f"foot.{n}", since(m))

for o in kit.objs:
    vg = o.vertex_groups.new(name=owner[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
NAME = "zherdyai" if TALL else f"human_{STYLE}"
body, img, tris = kit.finish(NAME, OUT, res=512, origin="keep", samples=24, ao_min=0.5)
import skin
print("[skin] плавных вершин у суставов:", skin.smooth_joints(body, BONES))

arm_data = bpy.data.armatures.new(NAME + "_arm")
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


def clip(name, keys):
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in sorted(keys):
        k = keys[f]
        for pb in arm.pose.bones:
            r = k.get(pb.name, (0, 0, 0))
            pb.rotation_euler = (D(r[0]), D(r[1]), D(r[2]))
            pb.keyframe_insert("rotation_euler", frame=f)
            pb.location = k.get(pb.name + "@loc", (0, 0, 0))
            pb.keyframe_insert("location", frame=f)
    act.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new(); tr.name = name
    tr.strips.new(name, 1, act).name = name
    tr.mute = True
    arm.animation_data.action = None


def mix(*ps):
    o = {}
    for p in ps:
        o.update(p)
    return o


def mirror(p):
    o = {}
    for k, v in p.items():
        nk = k.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")
        o[nk] = v if k.endswith("@loc") else (v[0], -v[1], -v[2])
    return o


def cycle(a, b, half):
    return {1: a, 1 + half // 2: b, 1 + half: mirror(a), 1 + half + half // 2: mirror(b), 1 + 2 * half: a}


# Кости, направленные вниз (руки, ноги): +X — мах вперёд. Позвоночник (вверх): −X — наклон вперёд.
ARMS_DOWN = {"upper_arm.L": (0, 0, -4), "upper_arm.R": (0, 0, 4), "forearm.L": (8, 0, 0), "forearm.R": (8, 0, 0)}
IDLE_A = mix(ARMS_DOWN, {"chest": (-2, 0, 0)})
IDLE_B = mix(ARMS_DOWN, {"chest": (-4, 0, 1), "hips": (0, 0, 1.5), "head": (2, 6, 0)})
clip("idle", {1: IDLE_A, 40: IDLE_B, 80: IDLE_A})

WA = mix(ARMS_DOWN, {"thigh.L": (26, 0, 0), "shin.L": (-8, 0, 0), "foot.L": (-12, 0, 0), "thigh.R": (-18, 0, 0), "shin.R": (-22, 0, 0), "foot.R": (14, 0, 0),
                     "upper_arm.L": (-18, 0, -4), "upper_arm.R": (20, 0, 4), "forearm.R": (16, 0, 0), "hips": (0, 0, 4), "chest": (-3, 3, -2)})
WB = mix(ARMS_DOWN, {"thigh.L": (4, 0, 0), "shin.L": (-6, 0, 0), "thigh.R": (6, 0, 0), "shin.R": (-50, 0, 0), "foot.R": (10, 0, 0),
                     "root@loc": (0, 0, 0.025), "chest": (-3, 0, 0)})
clip("walk", cycle(WA, WB, 16 if not TALL else 28))

RA = mix({"root@loc": (0, 0, 0.04), "thigh.L": (50, 0, 0), "shin.L": (-30, 0, 0), "thigh.R": (-30, 0, 0), "shin.R": (-70, 0, 0), "foot.R": (20, 0, 0),
          "upper_arm.L": (-40, 0, -6), "forearm.L": (50, 0, 0), "upper_arm.R": (45, 0, 6), "forearm.R": (60, 0, 0), "spine": (-10, 0, 0), "chest": (-6, 6, 0)})
RB = mix({"thigh.L": (10, 0, 0), "shin.L": (-60, 0, 0), "thigh.R": (20, 0, 0), "shin.R": (-20, 0, 0), "root@loc": (0, 0, 0.06),
          "upper_arm.L": (0, 0, -6), "forearm.L": (60, 0, 0), "upper_arm.R": (0, 0, 6), "forearm.R": (60, 0, 0), "spine": (-12, 0, 0)})
clip("run", cycle(RA, RB, 8))

# Неподвижный, чуть склонив голову — жуткая стойка
ST = mix(ARMS_DOWN, {"head": (4, 0, 9), "neck": (2, 0, 3)})
clip("still", {1: ST, 60: mix(ST, {"head": (5, 2, 11)}), 70: ST, 120: ST})

# Выглядывает из-за косяка
PK = mix(ARMS_DOWN, {"spine": (0, 0, -10), "chest": (0, 0, -12), "neck": (0, 0, -8), "head": (0, -10, -22), "upper_arm.L": (30, 0, -20), "forearm.L": (40, 0, 0)})
clip("peek", {1: PK, 50: mix(PK, {"head": (2, -14, -28)}), 60: PK, 100: PK})

if STYLE == "driver":
    # Сидит за рычагами ГТ-Т
    SIT = {"thigh.L": (88, 0, 4), "thigh.R": (88, 0, -4), "shin.L": (-88, 0, 0), "shin.R": (-88, 0, 0), "root@loc": (0, -0.02, -0.42),
           "upper_arm.L": (42, 0, -4), "upper_arm.R": (42, 0, 4), "forearm.L": (48, 0, 0), "forearm.R": (48, 0, 0), "chest": (-4, 0, 0), "spine": (-4, 0, 0)}
    clip("sit_drive", {1: SIT, 20: mix(SIT, {"upper_arm.L": (45, 0, -4), "chest": (-5, 0, 0)}), 40: mix(SIT, {"upper_arm.R": (45, 0, 4)}), 60: SIT})
    T1 = mix(SIT, {"upper_arm.R": (46, 0, 8), "forearm.R": (56, 0, 0), "hand.R": (-8, 0, 0), "head": (5, -14, 0), "chest": (-3, -5, 0)})
    T2 = mix(SIT, {"upper_arm.R": (43, 0, 6), "forearm.R": (46, 0, 0), "hand.R": (4, 0, 8), "head": (-3, -10, 3), "chest": (-4, -3, 0)})
    clip("sit_talk", {1: SIT, 8: T1, 16: T2, 24: T1, 32: mix(T2, {"head": (6, -16, 0)}), 44: SIT})
    WV = mix(ARMS_DOWN, {"upper_arm.R": (10, 0, 140), "forearm.R": (0, 0, 20), "head": (0, 10, 0)})
    clip("wave", {1: WV, 8: mix(WV, {"forearm.R": (0, 0, -25)}), 16: WV, 24: mix(WV, {"forearm.R": (0, 0, -25)}), 32: WV})
if STYLE in ("officer", "clerk", "guard", "civil"):
    # Сидит (на стуле, скамье) — руки на коленях; печатает; курит; несёт папку
    SIT = {"thigh.L": (88, 0, 4), "thigh.R": (88, 0, -4), "shin.L": (-88, 0, 0), "shin.R": (-88, 0, 0), "root@loc": (0, -0.05, 0.0),
           "upper_arm.L": (30, 0, -4), "upper_arm.R": (30, 0, 4), "forearm.L": (55, 0, 0), "forearm.R": (55, 0, 0), "chest": (-3, 0, 0)}
    clip("sit_drive", {1: SIT, 40: mix(SIT, {"head": (4, 6, 0), "chest": (-4, 0, 0)}), 80: SIT})
    clip("sit_talk", {1: SIT, 12: mix(SIT, {"upper_arm.R": (60, 0, 14), "forearm.R": (60, 0, 0), "head": (4, -10, 0)}), 24: SIT})
    TY = mix(SIT, {"upper_arm.L": (55, 0, -8), "upper_arm.R": (55, 0, 8), "forearm.L": (40, 0, 0), "forearm.R": (40, 0, 0), "head": (14, 0, 0), "chest": (-6, 0, 0)})
    clip("type", {1: TY, 3: mix(TY, {"hand.L": (-14, 0, 0)}), 5: mix(TY, {"hand.R": (-14, 0, 0)}), 7: TY, 9: mix(TY, {"hand.R": (-12, 0, 0), "forearm.R": (44, 0, 0)}),
                  11: mix(TY, {"hand.L": (-12, 0, 0)}), 13: TY, 30: mix(TY, {"head": (10, 8, 0)}), 40: TY})
    SM = mix(ARMS_DOWN, {"upper_arm.R": (40, 0, 22), "forearm.R": (110, 0, 0), "hand.R": (0, 0, 10), "head": (-6, 0, 0)})
    SM_IN = mix(ARMS_DOWN, {"upper_arm.R": (62, 0, 18), "forearm.R": (128, 0, 0), "head": (-2, 0, 0)})
    clip("smoke", {1: SM, 30: SM, 45: SM_IN, 60: SM_IN, 75: SM, 120: SM})
    WF_A = mix(WA, {"upper_arm.L": (34, 0, -10), "forearm.L": (78, 0, 0)})
    WF_B = mix(WB, {"upper_arm.L": (34, 0, -10), "forearm.L": (78, 0, 0)})
    WF_C = mix(mirror(WA), {"upper_arm.L": (34, 0, -10), "forearm.L": (78, 0, 0)})
    WF_D = mix(mirror(WB), {"upper_arm.L": (34, 0, -10), "forearm.L": (78, 0, 0)})
    clip("walk_folder", {1: WF_A, 9: WF_B, 17: WF_C, 25: WF_D, 33: WF_A})
if TALL:
    BEND = mix(ARMS_DOWN, {"hips": (0, 0, 0), "spine": (-30, 0, 0), "chest": (-40, 0, 0), "neck": (40, 0, 0), "head": (30, 0, 6),
                           "upper_arm.L": (62, 0, -4), "upper_arm.R": (66, 0, 4), "forearm.L": (6, 0, 0), "forearm.R": (10, 0, 0)})
    clip("bend", {1: BEND, 40: mix(BEND, {"head": (34, 6, 10), "chest": (-42, 0, 0)}), 80: BEND})
    B83 = mix(ARMS_DOWN, {"hips": (-40, 0, 0), "thigh.L": (40, 0, 0), "thigh.R": (40, 0, 0), "spine": (-40, 0, 0), "chest": (-40, 0, 0),
                          "neck": (70, 0, 0), "head": (20, 0, 8),
                          "upper_arm.L": (112, 0, -4), "upper_arm.R": (118, 0, 4), "forearm.L": (4, 0, 0), "forearm.R": (8, 0, 0)})
    clip("bend83", {1: B83, 50: mix(B83, {"head": (30, 4, 14)}), 60: B83, 100: B83})
    B45 = mix(ARMS_DOWN, {"hips": (-15, 0, 0), "thigh.L": (15, 0, 0), "thigh.R": (15, 0, 0), "spine": (-15, 0, 0), "chest": (-15, 0, 0),
                          "neck": (25, 0, 0), "head": (10, 0, 6), "upper_arm.L": (42, 0, -4), "upper_arm.R": (46, 0, 4)})
    clip("bend45", {1: B45, 50: mix(B45, {"head": (12, 6, 10)}), 60: B45, 100: B45})
    RE = mix(ARMS_DOWN, {"upper_arm.R": (85, 0, 6), "forearm.R": (10, 0, 0), "hand.R": (-10, 0, 0), "chest": (-12, 0, 0), "head": (6, 0, 8)})
    clip("reach", {1: ARMS_DOWN, 30: RE, 60: mix(RE, {"hand.R": (10, 0, 0)}), 90: RE})

for t in arm.animation_data.nla_tracks:
    t.mute = False
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True); body.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"), export_format="GLB", use_selection=True,
                          export_image_format="AUTO", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_skins=True, export_def_bones=True)
for im in bpy.data.images:
    if im.has_data and not im.packed_file and im.size[0] > 0 and not im.name.endswith(("_col", "_ao")):
        im.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris, "clips:", [a.name for a in bpy.data.actions])
