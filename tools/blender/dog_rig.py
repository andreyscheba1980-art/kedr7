# «Кедр-7» — Найда, лайка-подросток. Скелет и клипы. Нос в +Y (в Godot −Z), лапы на z = 0.
# Пропорции «детские»: большая голова, крупные глаза, уши торчком, хвост бубликом.
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, sphere, mat
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians

GINGER = mat("d_ginger", (0.62, 0.3, 0.11), rough=0.9, noise=0.25, noise_scale=30, dirt=0.5)
WHITE = mat("d_white", (0.86, 0.84, 0.8), rough=0.9, noise=0.12, noise_scale=40, dirt=0.4)
DARK = mat("d_dark", (0.02, 0.02, 0.02), rough=0.3)
EYE = mat("d_eye", (0.03, 0.02, 0.015), rough=0.05)
SHINE = mat("d_shine", (1.0, 1.0, 1.0), rough=0.1)
PINK = mat("d_pink", (0.75, 0.42, 0.42), rough=0.6)
TONGUE = mat("d_tongue", (0.8, 0.35, 0.38), rough=0.4)
COLLAR = mat("d_collar", (0.45, 0.08, 0.05), rough=0.6, wear=0.4, dirt=0.5)

BONES = [
    ("root", (0, 0, 0), (0, 0, 0.1), None),
    ("hips", (0, -0.17, 0.33), (0, 0.0, 0.345), "root"),
    ("chest", (0, 0.0, 0.345), (0, 0.17, 0.36), "hips"),
    ("neck", (0, 0.16, 0.37), (0, 0.23, 0.47), "chest"),
    ("head", (0, 0.23, 0.47), (0, 0.39, 0.49), "neck"),
    ("jaw", (0, 0.30, 0.43), (0, 0.41, 0.42), "head"),
    ("ear.L", (-0.055, 0.25, 0.54), (-0.07, 0.25, 0.63), "head"),
    ("ear.R", (0.055, 0.25, 0.54), (0.07, 0.25, 0.63), "head"),
    ("tail1", (0, -0.19, 0.36), (0, -0.25, 0.45), "hips"),
    ("tail2", (0, -0.25, 0.45), (0, -0.19, 0.53), "tail1"),
]
for s, n in ((-1, "L"), (1, "R")):
    BONES += [
        (f"arm.{n}", (0.07 * s, 0.12, 0.30), (0.07 * s, 0.13, 0.16), "chest"),
        (f"fore.{n}", (0.07 * s, 0.13, 0.16), (0.07 * s, 0.12, 0.035), f"arm.{n}"),
        (f"pawf.{n}", (0.07 * s, 0.12, 0.035), (0.07 * s, 0.17, 0.015), f"fore.{n}"),
        (f"thigh.{n}", (0.075 * s, -0.15, 0.30), (0.075 * s, -0.10, 0.17), "hips"),
        (f"shank.{n}", (0.075 * s, -0.10, 0.17), (0.075 * s, -0.17, 0.04), f"thigh.{n}"),
        (f"pawb.{n}", (0.075 * s, -0.17, 0.04), (0.075 * s, -0.12, 0.015), f"shank.{n}"),
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
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    return o


def blob(name, c, r, m, scale=(1, 1, 1), segs=12, rings=8, fluff=0.0):
    o = sphere(name, r, c, m, scale=scale, segs=segs, rings=rings)
    if fluff > 0:
        for v in o.data.vertices:
            v.co += v.normal * abs(noise.noise(v.co * 18.0)) * fluff
    return o


# Туловище: зад и грудь, рыжая спина, белое брюхо
m = mark()
blob("rump", (0, -0.12, 0.33), 0.1, GINGER, scale=(0.95, 1.2, 0.95), fluff=0.012)
blob("belly_b", (0, -0.1, 0.29), 0.085, WHITE, scale=(0.9, 1.2, 0.8), fluff=0.01)
own("hips", since(m))
m = mark()
blob("ribs", (0, 0.06, 0.345), 0.108, GINGER, scale=(0.95, 1.25, 1.0), fluff=0.012)
blob("chest_w", (0, 0.13, 0.3), 0.085, WHITE, scale=(0.95, 0.9, 1.05), fluff=0.014)
own("chest", since(m))
m = mark()
blob("neck_f", (0, 0.2, 0.42), 0.075, GINGER, scale=(1.0, 0.9, 1.15), fluff=0.012)
blob("ruff", (0, 0.23, 0.39), 0.07, WHITE, scale=(1.15, 0.8, 1.0), fluff=0.016)
kit.torus("collar", 0.062, 0.013, (0, 0.2, 0.41), COLLAR, rot=(D(-35), 0, 0), maj=16, mino=6)
own("neck", since(m))
# Голова: крупная, щёки белые, «маска» рыжая, глаза большие
m = mark()
blob("skull", (0, 0.295, 0.5), 0.092, GINGER, scale=(1.08, 1.0, 0.98), segs=14, rings=10, fluff=0.005)
blob("cheeks", (0, 0.33, 0.462), 0.062, WHITE, scale=(1.2, 0.9, 0.7))
limb("snout", (0, 0.34, 0.46), (0, 0.405, 0.448), 0.036, 0.024, WHITE, 10)
blob("nose", (0, 0.41, 0.453), 0.015, DARK, scale=(1.25, 0.8, 0.9), segs=8, rings=6)
blob("blaze", (0, 0.36, 0.515), 0.03, WHITE, scale=(0.7, 1.2, 0.5))
for s in (-1, 1):
    blob(f"eye{s}", (0.04 * s, 0.37, 0.502), 0.019, EYE, segs=10, rings=7)
    blob(f"shine{s}", (0.045 * s, 0.386, 0.51), 0.006, SHINE, segs=6, rings=4)
own("head", since(m))
m = mark()
limb("jaw_l", (0, 0.32, 0.43), (0, 0.4, 0.432), 0.026, 0.018, WHITE, 8)
blob("tongue", (0, 0.39, 0.43), 0.016, TONGUE, scale=(1.0, 1.4, 0.4), segs=8, rings=4)
own("jaw", since(m))
for s, n in ((-1, "L"), (1, "R")):
    m = mark()
    e = limb(f"ear{n}", (0.055 * s, 0.25, 0.53), (0.072 * s, 0.25, 0.635), 0.032, 0.002, GINGER, 4)
    e.scale = (1.0, 0.45, 1.0)
    pin = limb(f"earin{n}", (0.055 * s, 0.258, 0.535), (0.07 * s, 0.258, 0.62), 0.02, 0.002, PINK, 4)
    pin.scale = (1.0, 0.3, 1.0)
    own(f"ear.{n}", since(m))
    a1 = Vector(B[f"arm.{n}"][1]); a2 = Vector(B[f"fore.{n}"][1]); a3 = Vector(B[f"pawf.{n}"][1]); a4 = Vector(B[f"pawf.{n}"][2])
    m = mark(); limb(f"upf{n}", a1, a2, 0.036, 0.028, WHITE); own(f"arm.{n}", since(m))
    m = mark(); limb(f"lof{n}", a2, a3, 0.026, 0.022, WHITE); own(f"fore.{n}", since(m))
    m = mark(); blob(f"pf{n}", (a3 + a4) / 2 + Vector((0, 0, 0.005)), 0.026, WHITE, scale=(1.0, 1.4, 0.7)); own(f"pawf.{n}", since(m))
    t1 = Vector(B[f"thigh.{n}"][1]); t2 = Vector(B[f"shank.{n}"][1]); t3 = Vector(B[f"pawb.{n}"][1]); t4 = Vector(B[f"pawb.{n}"][2])
    m = mark(); blob(f"haunch{n}", t1 + Vector((0, 0.01, -0.04)), 0.055, GINGER, scale=(0.7, 1.1, 1.2), fluff=0.01); limb(f"th{n}", t1, t2, 0.045, 0.03, GINGER); own(f"thigh.{n}", since(m))
    m = mark(); limb(f"sh{n}", t2, t3, 0.026, 0.02, WHITE); own(f"shank.{n}", since(m))
    m = mark(); blob(f"pb{n}", (t3 + t4) / 2 + Vector((0, 0, 0.005)), 0.026, WHITE, scale=(1.0, 1.4, 0.7)); own(f"pawb.{n}", since(m))
# Хвост бубликом
m = mark(); limb("tail_a", B["tail1"][1], B["tail1"][2], 0.04, 0.045, GINGER); own("tail1", since(m))
m = mark(); limb("tail_b", B["tail2"][1], B["tail2"][2], 0.045, 0.02, WHITE); blob("tail_tuft", B["tail2"][2], 0.035, WHITE, fluff=0.012); own("tail2", since(m))

for o in kit.objs:
    vg = o.vertex_groups.new(name=owner[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")

body, img, tris = kit.finish("dog", OUT, res=512, origin="keep", samples=32, ao_min=0.55)

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


def mix(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


def mirror(p):
    out = {}
    for k, v in p.items():
        nk = k.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")
        out[nk] = (-v[0], v[1], v[2]) if k.endswith("@loc") and False else v if k.endswith("@loc") else (v[0], -v[1], -v[2])
    return out


# --- Стоит: дыхание, хвост ходит, уши дёргаются ---
ST = {"tail1": (-20, 0, 0), "tail2": (-40, 0, 0), "neck": (6, 0, 0)}
clip("stand", {1: mix(ST, {"tail1": (-20, 0, 10)}), 13: mix(ST, {"tail1": (-20, 0, -10), "chest": (2, 0, 0), "ear.L": (-10, 0, 0)}),
               25: mix(ST, {"tail1": (-20, 0, 10), "head": (0, 0, 8)}), 37: mix(ST, {"tail1": (-20, 0, -10), "chest": (2, 0, 0)}), 49: mix(ST, {"tail1": (-20, 0, 10)})})

# --- Сидит, наклоняет голову (самое «мимими») ---
SIT = {"hips": (38, 0, 0), "hips@loc": (0, 0.0, -0.1), "chest": (-20, 0, 0), "neck": (-4, 0, 0),
       "arm.L": (-18, 0, 0), "arm.R": (-18, 0, 0), "thigh.L": (40, 0, 6), "thigh.R": (40, 0, -6),
       "shank.L": (-115, 0, 0), "shank.R": (-115, 0, 0), "pawb.L": (40, 0, 0), "pawb.R": (40, 0, 0),
       "tail1": (-60, 0, 0), "tail2": (-30, 0, 0)}
clip("sit", {1: SIT, 20: mix(SIT, {"head": (0, 0, 22), "ear.R": (-15, 0, 0)}), 34: mix(SIT, {"head": (0, 0, 22), "ear.R": (-15, 0, 0)}),
             50: SIT, 62: mix(SIT, {"head": (0, 0, -18), "ear.L": (-15, 0, 0)}), 74: mix(SIT, {"head": (0, 0, -18)}), 90: SIT})

# --- Шаг ---
WA = mix(ST, {"arm.L": (24, 0, 0), "fore.L": (-10, 0, 0), "arm.R": (-20, 0, 0), "fore.R": (-25, 0, 0),
              "thigh.L": (-22, 0, 0), "shank.L": (-15, 0, 0), "thigh.R": (24, 0, 0), "shank.R": (10, 0, 0), "tail1": (-20, 0, 8)})
WB = mix(ST, {"arm.L": (0, 0, 0), "arm.R": (0, 0, 0), "fore.R": (-40, 0, 0), "thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "shank.L": (-35, 0, 0),
              "chest": (0, 3, 0), "hips@loc": (0, 0, 0.012), "tail1": (-20, 0, -8)})
clip("walk", {1: WA, 7: WB, 13: mirror(WA), 19: mirror(WB), 25: WA})

# --- Бег рысцой ---
RA = mix(ST, {"arm.L": (40, 0, 0), "fore.L": (-20, 0, 0), "arm.R": (-35, 0, 0), "fore.R": (-50, 0, 0),
              "thigh.L": (-40, 0, 0), "shank.L": (-30, 0, 0), "thigh.R": (40, 0, 0), "shank.R": (20, 0, 0), "neck": (-6, 0, 0), "ear.L": (-25, 0, 0), "ear.R": (-25, 0, 0)})
RB = mix(RA, {"arm.L": (0, 0, 0), "arm.R": (0, 0, 0), "thigh.L": (0, 0, 0), "thigh.R": (0, 0, 0), "hips@loc": (0, 0, 0.03)})
clip("run", {1: RA, 5: RB, 9: mirror(RA), 13: mirror(RB), 17: RA})

# --- Лежит и дрожит: замёрзший щенок под нарами ---
LIE = {"root@loc": (0, 0, -0.2), "hips": (0, 0, 0), "arm.L": (78, 0, 0), "arm.R": (78, 0, 0), "fore.L": (12, 0, 0), "fore.R": (12, 0, 0),
       "thigh.L": (70, 0, 12), "thigh.R": (70, 0, -12), "shank.L": (-125, 0, 0), "shank.R": (-125, 0, 0), "pawb.L": (40, 0, 0), "pawb.R": (40, 0, 0),
       "neck": (-28, 0, 0), "head": (-8, 0, 0), "ear.L": (-40, 0, 20), "ear.R": (-40, 0, -20), "tail1": (40, 0, 30), "tail2": (40, 0, 30)}
shiv = {}
for f in range(1, 25, 2):
    a = 2.0 if (f // 2) % 2 == 0 else -2.0
    shiv[f] = mix(LIE, {"chest": (a, 0, a * 0.5), "head": (-8 + a, 0, 0), "hips": (0, 0, -a * 0.6)})
shiv[25] = shiv[1]
clip("lie_shiver", shiv)

# --- Спит: лежит, медленно дышит, иногда ухо ---
SL = mix(LIE, {"neck": (-34, 18, 0), "head": (-12, 20, 10), "ear.L": (-55, 0, 25), "ear.R": (-55, 0, -25), "tail1": (40, 0, 60), "tail2": (30, 0, 60)})
clip("sleep", {1: SL, 30: mix(SL, {"chest": (3, 0, 0)}), 60: SL, 75: mix(SL, {"ear.L": (-35, 0, 25)}), 80: SL, 96: mix(SL, {"chest": (3, 0, 0)}), 120: SL})

# --- Ест из миски ---
EA = mix(ST, {"neck": (-48, 0, 0), "head": (-20, 0, 0), "arm.L": (8, 0, 0), "arm.R": (8, 0, 0), "chest": (-6, 0, 0), "tail1": (-20, 0, 15)})
EB = mix(EA, {"jaw": (-14, 0, 0), "head": (-14, 0, 0), "tail1": (-20, 0, -15)})
clip("eat", {1: EA, 4: EB, 7: EA, 10: EB, 13: EA, 16: EB, 19: EA, 22: EB, 25: EA})

# --- Нюхает: нос у пола водит туда-сюда ---
SN = mix(ST, {"neck": (-42, 0, 0), "head": (-22, 0, 0), "chest": (-4, 0, 0)})
clip("sniff", {1: mix(SN, {"neck": (-42, 14, 0)}), 9: mix(SN, {"neck": (-42, -12, 0), "head": (-18, 0, 0)}), 17: mix(SN, {"neck": (-46, 8, 0)}), 25: mix(SN, {"neck": (-42, 14, 0)})})

# --- Лает: голова вверх, пасть щёлкает ---
BK = mix(ST, {"neck": (22, 0, 0), "head": (8, 0, 0), "arm.L": (-8, 0, 0), "arm.R": (-8, 0, 0), "tail1": (-35, 0, 0)})
clip("bark", {1: BK, 3: mix(BK, {"jaw": (-30, 0, 0), "chest": (-4, 0, 0), "head": (14, 0, 0)}), 6: BK, 13: BK, 15: mix(BK, {"jaw": (-30, 0, 0), "head": (14, 0, 0)}), 18: BK, 24: BK})

# --- Рычит: голова ниже, уши прижаты, хвост вниз ---
GR = mix(ST, {"neck": (-10, 0, 0), "head": (-6, 0, 0), "jaw": (-8, 0, 0), "ear.L": (-45, 0, 15), "ear.R": (-45, 0, -15), "tail1": (40, 0, 0), "tail2": (10, 0, 0),
              "chest": (-6, 0, 0), "arm.L": (12, 0, 0), "arm.R": (12, 0, 0), "hips@loc": (0, 0, -0.02)})
clip("growl", {1: GR, 6: mix(GR, {"jaw": (-12, 0, 0), "chest": (-7, 0, 0)}), 12: GR, 18: mix(GR, {"jaw": (-10, 0, 0)}), 24: GR})

# --- Радуется: хвост винтом, лезет мордой под руку, лапу даёт ---
HA = mix(SIT, {"neck": (14, 0, 0), "head": (12, 0, 0), "tail1": (-60, 0, 25), "jaw": (-10, 0, 0), "ear.L": (-20, 0, 0), "ear.R": (-20, 0, 0)})
HB = mix(HA, {"tail1": (-60, 0, -25), "arm.R": (-70, 0, 0), "fore.R": (-40, 0, 0), "head": (16, 0, 10)})
clip("happy", {1: HA, 4: HB, 7: HA, 10: HB, 13: HA, 16: mix(HA, {"head": (10, 0, -12)}), 19: HB, 24: HA})

for t in arm.animation_data.nla_tracks:
    t.mute = False
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True); body.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dog.glb"), export_format="GLB", use_selection=True,
                          export_image_format="AUTO", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_skins=True, export_def_bones=True)
for im in bpy.data.images:
    if im.has_data and not im.packed_file and im.size[0] > 0 and not im.name.endswith(("_col", "_ao")):
        im.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "dog.blend"))
print("[OK] dog tris:", tris, "clips:", [a.name for a in bpy.data.actions])
