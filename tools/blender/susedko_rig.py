# «Кедр-7» — Суседко (домовой) со скелетом. Ростом с ребёнка (~1.1 м): рваный сажистый балахон
# колоколом, лохматые плечи и голова, длинные тонкие руки с пальцами-сучками, две пустые глазницы.
# Нос в +Y (в Godot −Z), низ на z = 0. Жёсткая привязка частей к костям (PS1).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import sphere, mat
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians
S = 0.62          # всё задаётся во «взрослых» размерах старой модели и ужимается до детского роста


def V(x, y, z):
    return Vector((x * S, y * S, z * S))


ROBE = mat("sus_robe", (0.034, 0.032, 0.036), rough=0.95, noise=0.35, noise_scale=12, dirt=0.8)
FUR = mat("sus_fur", (0.026, 0.024, 0.026), rough=1.0, noise=0.4, noise_scale=30)
SOOT = mat("sus_soot", (0.05, 0.048, 0.05), rough=0.9, noise=0.3, noise_scale=20)
VOID = mat("void", (0.004, 0.004, 0.005), rough=0.9)

BONES = [
    ("root", V(0, 0, 0), V(0, 0, 0.2), None),
    ("hips", V(0, 0, 0.12), V(0, 0, 0.85), "root"),
    ("spine", V(0, 0, 0.85), V(0, 0, 1.25), "hips"),
    ("chest", V(0, 0, 1.25), V(0, 0, 1.45), "spine"),
    ("neck", V(0, 0, 1.45), V(0, 0.01, 1.56), "chest"),
    ("head", V(0, 0.01, 1.56), V(0, 0.02, 1.82), "neck"),
]
for s, n in ((-1, "L"), (1, "R")):
    BONES += [
        (f"upper_arm.{n}", V(0.22 * s, 0, 1.40), V(0.27 * s, -0.02, 1.08), "chest"),
        (f"forearm.{n}", V(0.27 * s, -0.02, 1.08), V(0.25 * s, 0.04, 0.72), f"upper_arm.{n}"),
        (f"hand.{n}", V(0.25 * s, 0.04, 0.72), V(0.26 * s, 0.07, 0.54), f"forearm.{n}"),
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


def limb(name, a, b, r1, r2, m, verts=8, wob=0.0):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1 * S, radius2=r2 * S, depth=max(d.length, 0.001), location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    if wob > 0:
        for v in o.data.vertices:
            v.co += v.normal * noise.noise(v.co * 23.0 + Vector((len(kit.objs), 0, 0))) * wob * S
    return o


def blob(name, c, r, m, scale=(1, 1, 1), segs=10, rings=7, wobble=0.0):
    o = sphere(name, r * S, c, m, scale=scale, segs=segs, rings=rings)
    if wobble > 0:
        for v in o.data.vertices:
            v.co += v.normal * noise.noise(v.co * 14.0) * wobble * S
    return o


def P(b, i):
    return Vector(B[b][i])


# --- Балахон: колокол с рваным подолом ----------------------------------------------
m = mark()
limb("robe_low", V(0, -0.04, 0.03), V(0, -0.02, 0.85), 0.35, 0.28, ROBE, 11, wob=0.03)
for i in range(9):   # лохмотья подола — клинья, торчащие вниз и в стороны
    a = i * (math.tau / 9) + 0.2
    r0, r1 = 0.3, 0.4 + 0.04 * math.sin(i * 2.3)
    limb(f"rag{i}", V(math.cos(a) * r0, math.sin(a) * r0 - 0.04, 0.3), V(math.cos(a) * r1, math.sin(a) * r1 - 0.04, 0.0), 0.07, 0.008, ROBE, 4)
for i in range(4):   # полосы сажистой ткани спереди
    x = -0.15 + i * 0.1
    limb(f"strip{i}", V(x, 0.26 - abs(x) * 0.3, 0.7), V(x * 1.2, 0.33 - abs(x) * 0.3, 0.12 + 0.05 * (i % 2)), 0.03, 0.01, FUR, 4)
own("hips", since(m))
m = mark()
limb("robe_mid", V(0, -0.02, 0.85), V(0, -0.01, 1.25), 0.28, 0.23, ROBE, 10, wob=0.025)
own("spine", since(m))
m = mark()
limb("robe_top", V(0, -0.01, 1.25), V(0, 0, 1.46), 0.23, 0.15, ROBE, 10, wob=0.02)
limb("shoulders", V(-0.24, 0, 1.39), V(0.24, 0, 1.39), 0.075, 0.075, ROBE, 7)
for i in range(10):   # лохматый «воротник» шерсти
    a = i * (math.tau / 10)
    c = V(math.cos(a) * 0.17, math.sin(a) * 0.15, 1.42)
    limb(f"tuft{i}", c, c + V(math.cos(a) * 0.12, math.sin(a) * 0.1, -0.1 - 0.04 * (i % 3)), 0.04, 0.006, FUR, 4)
own("chest", since(m))
m = mark()
limb("neck_c", P("neck", 1), P("neck", 2), 0.075, 0.07, FUR, 6)
for i in range(8):   # шерсть, поднявшаяся вокруг шеи — шеи не видно
    a = i * (math.tau / 8) + 0.2
    c = V(math.cos(a) * 0.08, math.sin(a) * 0.07, 1.44)
    limb(f"ruff{i}", c, c + V(math.cos(a) * 0.06, math.sin(a) * 0.05, 0.11), 0.045, 0.006, FUR, 4)
own("neck", since(m))

# --- Голова: вытянутый тёмный ком, глазницы, лохмы ------------------------------------------
m = mark()
hc = V(0, 0.0, 1.68)
blob("skull", hc, 0.125, FUR, scale=(0.85, 1.0, 1.18), segs=10, rings=8, wobble=0.012)
for s in (-1, 1):
    blob(f"socket{s}", hc + V(0.042 * s, 0.105, 0.01), 0.026, VOID, scale=(1, 0.55, 0.8), segs=7, rings=5)
blob("mouth", hc + V(0, 0.108, -0.075), 0.02, VOID, scale=(1.6, 0.5, 0.35), segs=6, rings=4)
for i in range(11):   # лохмы на макушке и затылке, свисают вперёд и вбок
    a = i * (math.tau / 11) + 0.3
    c = hc + V(math.cos(a) * 0.06, math.sin(a) * 0.06 - 0.02, 0.1)
    tip = c + V(math.cos(a) * 0.1, math.sin(a) * 0.08 - 0.03, -0.12 - 0.05 * (i % 3))
    limb(f"lock{i}", c, tip, 0.032, 0.005, FUR, 4)
own("head", since(m))

# --- Руки: тонкие, длинные, пальцы-сучки ниже колен ----------------------------------------------
for s, n in ((-1, "L"), (1, "R")):
    a0, a1, a2, a3 = P(f"upper_arm.{n}", 1), P(f"forearm.{n}", 1), P(f"hand.{n}", 1), P(f"hand.{n}", 2)
    m = mark()
    limb(f"sleeve{n}", a0, a1, 0.07, 0.055, ROBE, 6, wob=0.02)
    limb(f"rag_arm{n}", a0 + V(0.02 * s, -0.04, -0.05), a1 + V(0.05 * s, -0.06, -0.12), 0.04, 0.006, FUR, 4)
    own(f"upper_arm.{n}", since(m))
    m = mark()
    limb(f"fore{n}", a1, a2, 0.045, 0.03, SOOT, 6)
    own(f"forearm.{n}", since(m))
    m = mark()
    blob(f"palm{n}", a2 + V(0, 0.0, -0.03), 0.034, SOOT, scale=(0.8, 0.6, 1.2), segs=6, rings=4)
    for f in range(4):
        dx = (-0.021 + f * 0.014) * s
        p0 = a2 + V(dx, 0.0, -0.05)
        p1 = p0 + V(dx * 0.5, 0.01, -0.1)
        p2 = p1 + V(dx * 0.8, 0.02, -0.08)
        limb(f"f{n}{f}a", p0, p1, 0.011, 0.008, SOOT, 4)
        limb(f"f{n}{f}b", p1, p2, 0.008, 0.002, SOOT, 4)
    own(f"hand.{n}", since(m))

for o in kit.objs:
    vg = o.vertex_groups.new(name=owner[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
NAME = "susedko"
body, img, tris = kit.finish(NAME, OUT, res=512, origin="keep", samples=24, ao_min=0.55)

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


# Руки (вниз): +X — вперёд, Z — в сторону (у L отрицательный). Позвоночник (вверх): −X — наклон вперёд, Z — вбок.
ARMS = {"upper_arm.L": (6, 0, -3), "upper_arm.R": (6, 0, 3), "forearm.L": (10, 0, 0), "forearm.R": (10, 0, 0)}
# Сгорбился, голова набок, длинные руки висят вперёд; дышит рывками плечей
HUNCH = mix(ARMS, {"spine": (-8, 0, 0), "chest": (-12, 0, 0), "neck": (14, 0, 4), "head": (6, 0, 14)})
clip("idle", {1: HUNCH,
              30: mix(HUNCH, {"chest": (-14, 0, 2), "head": (8, 0, 18), "hand.R": (14, 0, 0)}),
              34: mix(HUNCH, {"chest": (-14, 0, 2), "head": (8, 0, 18)}),
              70: mix(HUNCH, {"head": (4, -6, 10), "hand.L": (16, 0, 0)}),
              74: mix(HUNCH, {"head": (4, -6, 10)}),
              100: HUNCH})
# Выглядывает из-за косяка: корпус клонится вбок, левая рука держится за косяк, голова почти лёжа
PK = mix(ARMS, {"hips": (0, 0, 6), "spine": (-4, 0, 12), "chest": (-6, 0, 14), "neck": (6, 0, 12), "head": (4, -12, 26),
                "upper_arm.L": (55, 0, -48), "forearm.L": (35, 0, 0), "hand.L": (-25, 0, 0)})
clip("peek", {1: PK, 40: mix(PK, {"head": (6, -16, 34)}), 44: PK, 80: mix(PK, {"chest": (-6, 0, 16)}), 110: PK})
# Замер столбом, голова свёрнута — смотрит, не моргая
ST = mix(ARMS, {"neck": (4, 0, 10), "head": (2, 8, 38)})
clip("still", {1: ST, 70: mix(ST, {"head": (3, 10, 41)}), 74: ST, 120: ST})
# Тянет руку к человеку
RE = mix(HUNCH, {"upper_arm.R": (78, 0, 4), "forearm.R": (12, 0, 0), "hand.R": (-12, 0, 0), "chest": (-18, 0, 0), "head": (14, 0, 8)})
clip("reach", {1: HUNCH, 14: RE, 28: mix(RE, {"hand.R": (14, 0, 0)}), 32: RE, 60: RE})
# Скользит: балахон раскачивается, ног не видно
GA = mix(HUNCH, {"hips": (0, 0, 5), "chest": (-12, 4, -3), "upper_arm.L": (-10, 0, -3), "upper_arm.R": (20, 0, 3), "root@loc": (0, 0, 0.02)})
GB = mix(HUNCH, {"hips": (0, 0, -5), "chest": (-12, -4, 3), "upper_arm.L": (20, 0, -3), "upper_arm.R": (-10, 0, 3), "root@loc": (0, 0, 0.0)})
clip("walk", {1: GA, 13: GB, 25: GA})

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
