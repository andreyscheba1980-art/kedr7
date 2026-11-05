# «Кедр-7» — люди эпилога (Свердловск, 1983) со скелетом, тот же набор костей, что у human_rig.py.
# Вариант — переменная окружения VARIANT (см. V ниже). Лицо (веки, брови, нос, губы, уши, скулы), причёски,
# одежда с лацканами, пуговицами, карманами, швами; пальцы, часы. PREVIEW=1 — ещё и картинки поз.
# Нос в +Y (в Godot −Z), ноги на z = 0. Части жёстко привязаны к костям.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, sphere, mat
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
VAR = os.environ.get("VARIANT", "officer1")
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians

# Описание вариантов: рост, полнота, пол, одежда, причёска, цвета
V = {
    # Майор в сером костюме, тёмный пробор, бритый
    "officer1": dict(h=1.0, girth=1.0, fem=False, outfit="suit", hair="part", hair_col=(0.12, 0.09, 0.07),
                     skin=(0.78, 0.6, 0.5), cloth=(0.3, 0.32, 0.35), pants=(0.27, 0.29, 0.32), tie=(0.42, 0.1, 0.1)),
    # Полковник: коричневый костюм, грузный, лысина с седым венцом, очки, усы
    "officer2": dict(h=0.98, girth=1.18, fem=False, outfit="suit", hair="bald", hair_col=(0.62, 0.6, 0.57), glasses=True, moustache=True,
                     skin=(0.8, 0.6, 0.52), cloth=(0.33, 0.25, 0.18), pants=(0.3, 0.23, 0.17), tie=(0.15, 0.17, 0.25)),
    # Молодой лейтенант: тёмно-синий костюм, худой, высокий, светлые волосы
    "officer3": dict(h=1.04, girth=0.9, fem=False, outfit="suit", hair="crew", hair_col=(0.5, 0.38, 0.24),
                     skin=(0.84, 0.68, 0.58), cloth=(0.15, 0.17, 0.25), pants=(0.14, 0.16, 0.23), tie=(0.2, 0.24, 0.3)),
    # Офицер в форме: оливковый китель, погоны, золотые пуговицы, седые виски, усы
    "uniform": dict(h=1.0, girth=1.05, fem=False, outfit="uniform", hair="part", hair_col=(0.35, 0.33, 0.31), moustache=True,
                    skin=(0.76, 0.58, 0.48), cloth=(0.3, 0.32, 0.22), pants=(0.27, 0.29, 0.2), tie=(0.25, 0.26, 0.18)),
    # Постовой войск КГБ: гимнастёрка, ремень с кобурой, сапоги, фуражка с васильковым околышем
    "guard": dict(h=1.01, girth=0.95, fem=False, outfit="guard", hair="crew", hair_col=(0.2, 0.15, 0.1),
                  skin=(0.8, 0.62, 0.52), cloth=(0.29, 0.32, 0.21), pants=(0.26, 0.29, 0.19), tie=(0.26, 0.29, 0.19)),
    # Зоя: молодая, пучок, бордовое платье с белым воротничком
    "clerk1": dict(h=0.95, girth=0.95, fem=True, outfit="dress", hair="bun", hair_col=(0.3, 0.18, 0.1),
                   skin=(0.86, 0.7, 0.6), cloth=(0.42, 0.14, 0.18), pants=(0.62, 0.5, 0.44), tie=(0.9, 0.88, 0.82)),
    # Архивариус: старше, пепельная химия, очки, кардиган поверх блузки, тёмная юбка
    "clerk2": dict(h=0.94, girth=1.12, fem=True, outfit="cardigan", hair="perm", hair_col=(0.58, 0.55, 0.52), glasses=True,
                   skin=(0.8, 0.64, 0.56), cloth=(0.36, 0.4, 0.46), pants=(0.6, 0.48, 0.42), tie=(0.82, 0.76, 0.64), skirt=(0.18, 0.18, 0.2)),
    # Лаборант: белый халат, очки, седеющий
    "lab": dict(h=0.99, girth=0.92, fem=False, outfit="lab", hair="part", hair_col=(0.45, 0.43, 0.4), glasses=True,
                skin=(0.8, 0.64, 0.55), cloth=(0.86, 0.86, 0.83), pants=(0.25, 0.25, 0.27), tie=(0.22, 0.22, 0.3)),
    # Прохожий: пальто, шарф, шапка-пирожок
    "civil1": dict(h=1.0, girth=1.05, fem=False, outfit="coat", hair="part", hair_col=(0.2, 0.15, 0.1), hat="pirozhok",
                   skin=(0.78, 0.6, 0.5), cloth=(0.24, 0.19, 0.15), pants=(0.16, 0.16, 0.18), tie=(0.5, 0.42, 0.3)),
    # Прохожая: пальто с меховым воротником, меховая шапка
    "civil2": dict(h=0.95, girth=1.0, fem=True, outfit="coat", hair="bun", hair_col=(0.25, 0.16, 0.1), hat="fur",
                   skin=(0.84, 0.68, 0.58), cloth=(0.28, 0.2, 0.26), pants=(0.36, 0.3, 0.27), tie=(0.4, 0.3, 0.22)),
}[VAR]
FEM = V["fem"]
G = V["girth"]
OUT_ = V["outfit"]


def cm(name, col, rough=0.85, n=0.18, ns=40, wear=0.0):
    return mat(f"{VAR}_{name}", col, rough=rough, noise=n, noise_scale=ns, wear=wear, dirt=0.4 if wear > 0 else 0.0,
               wear_col=tuple(min(c * 1.35, 1) for c in col))


SKIN = cm("skin", V["skin"], 0.6, 0.07, 30)
SKIN_D = cm("skin_d", tuple(c * 0.82 for c in V["skin"]), 0.7, 0.05, 30)     # ноздри, уголки, уши внутри
LIPS = cm("lips", tuple(c * f for c, f in zip(V["skin"], (0.78, 0.55, 0.55))), 0.5, 0.05)
HAIR = cm("hair", V["hair_col"], 0.7, 0.35, 140)
CLOTH = cm("cloth", V["cloth"], 0.9, 0.2, 55, wear=0.25)
CLOTH_D = cm("cloth_d", tuple(c * 0.7 for c in V["cloth"]), 0.9, 0.15, 55)   # швы, клапаны, тени складок
PANTS = cm("pants", V["pants"], 0.9, 0.18, 55, wear=0.2)
PANTS_D = cm("pants_d", tuple(c * 0.68 for c in V["pants"]), 0.9, 0.1, 55)
TIE = cm("tie", V["tie"], 0.6, 0.12, 80)
SHIRT = cm("shirt", (0.86, 0.86, 0.82) if OUT_ != "guard" else V["cloth"], 0.7, 0.06, 60)
SHOE = cm("shoe", (0.06, 0.05, 0.045), 0.35, 0.08, 30, wear=0.4)
SOLE = cm("sole", (0.03, 0.03, 0.03), 0.8, 0.0)
SCLERA = cm("sclera", (0.86, 0.84, 0.8), 0.3, 0.0)
IRIS = cm("iris", (0.16, 0.11, 0.07) if VAR not in ("officer3", "clerk2") else (0.22, 0.3, 0.36), 0.2, 0.0)
PUPIL = cm("pupil", (0.01, 0.01, 0.012), 0.2, 0.0)
GOLD = cm("gold", (0.78, 0.6, 0.22), 0.3, 0.05)
STEEL = cm("steel", (0.55, 0.56, 0.58), 0.3, 0.05)
FRAME = cm("frame", (0.1, 0.08, 0.06), 0.4, 0.0)
BUTTON = GOLD if OUT_ in ("uniform", "guard") else cm("button", tuple(c * 0.5 for c in V["cloth"]), 0.4, 0.0)

H = V["h"]
LEG = 0.92 * H
TORSO = 0.6 * H * (0.97 if FEM else 1.0)
NECK = 0.075 if not FEM else 0.085
ARM = 0.68 * H
SH = (0.2 if FEM else 0.215) * (1.0 + (G - 1.0) * 0.4)

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
        (f"upper_arm.{n}", (SH * s, 0, sh_z - 0.04), (SH * s + 0.03 * s, 0.01, sh_z - 0.04 - ARM * 0.47), "chest"),
        (f"forearm.{n}", (SH * s + 0.03 * s, 0.01, sh_z - 0.04 - ARM * 0.47), (SH * s + 0.025 * s, 0.04, sh_z - 0.04 - ARM * 0.9), f"upper_arm.{n}"),
        (f"hand.{n}", (SH * s + 0.025 * s, 0.04, sh_z - 0.04 - ARM * 0.9), (SH * s + 0.025 * s, 0.05, sh_z - 0.04 - ARM * 1.1), f"forearm.{n}"),
        (f"thigh.{n}", ((0.1 if not FEM else 0.095) * s, 0, hip_z), ((0.1 if not FEM else 0.085) * s, 0.02, hip_z * 0.5), "hips"),
        (f"shin.{n}", ((0.1 if not FEM else 0.085) * s, 0.02, hip_z * 0.5), ((0.1 if not FEM else 0.08) * s, 0, 0.08), f"thigh.{n}"),
        (f"foot.{n}", ((0.1 if not FEM else 0.08) * s, 0, 0.08), ((0.1 if not FEM else 0.08) * s, 0.19, 0.03), f"shin.{n}"),
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


def P(b, i):
    return Vector(B[b][i])


def limb(name, a, b, r1, r2, m, verts=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=max(d.length, 0.001), location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    return o


def blob(name, c, r, m, scale=(1, 1, 1), segs=12, rings=8, wobble=0.0):
    o = sphere(name, r, c, m, scale=scale, segs=segs, rings=rings)
    if wobble > 0:
        for v in o.data.vertices:
            v.co += v.normal * noise.noise(v.co * 9.0) * wobble
    return o


def strip(name, a, b, w, t, m, roll=0.0):
    """Плоская полоса от a до b (лацкан, ремень, шов): ширина w, толщина t."""
    a, b = Vector(a), Vector(b)
    d = b - a
    o = box(name, (w, t, d.length), (a + b) / 2, m, 0.0015)
    q = d.to_track_quat("Z", "Y")
    o.rotation_euler = q.to_euler()
    if roll:
        o.rotation_euler.rotate_axis("Z", roll)
    return o


def loft(name, rings, m, verts=16, caps=(True, True)):
    """Тело по кольцам (z, cx, cy, rx, ry): эллипсы в плоскости XY — грудь шире, чем толще."""
    me = bpy.data.meshes.new(name)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    loops = []
    for (z, cx, cy, rx, ry) in rings:
        loops.append([bm.verts.new((cx + rx * math.cos(2 * math.pi * i / verts), cy + ry * math.sin(2 * math.pi * i / verts), z)) for i in range(verts)])
    for a, b in zip(loops, loops[1:]):
        for i in range(verts):
            j = (i + 1) % verts
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps[0]:
        bm.faces.new(list(reversed(loops[0])))
    if caps[1]:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    me.materials.append(m)
    kit.objs.append(o)
    return o


def cut(o, fn):
    """Убрать вершины, где fn(co) — истина (шапка волос по линии роста)."""
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if fn(v.co + o.location)], context="VERTS")
    bm.to_mesh(o.data); bm.free()


def smooth(x0, x1, x):
    t = min(max((x - x0) / (x1 - x0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


long_coat = OUT_ in ("coat", "lab")
TOP = CLOTH if OUT_ != "cardigan" else CLOTH          # верх (пиджак, китель, халат, кардиган, платье)

# --- Таз: брюки/юбка, низ пиджака ------------------------------------------------------
m = mark()
hw = (0.165 if not FEM else 0.185) * G      # полуширина таза
wz = hip_z + TORSO * 0.33
loft("pelvis", [(hip_z - 0.1, 0, -0.005, hw * 0.92, 0.115 * G), (hip_z - 0.02, 0, 0, hw, 0.125 * G), (hip_z + 0.06, 0, 0.0, hw * 0.98, 0.122 * G),
                (wz, 0, 0.005, (0.15 if not FEM else 0.135) * G, 0.11 * G)],
     TOP if OUT_ in ("dress", "coat", "lab") else (cm("skirt", V.get("skirt", V["pants"]), 0.9, 0.18, 55) if FEM else PANTS))
if OUT_ in ("suit", "uniform", "lab", "coat", "cardigan"):
    # пояс брюк / низ пиджака
    if OUT_ == "suit" or OUT_ == "uniform":
        loft("jacket_hem", [(hip_z + 0.08, 0, 0.003, hw * 1.04, 0.13 * G), (hip_z - 0.06, 0, 0.0, hw * 1.08, 0.135 * G),
                            (hip_z - 0.14, 0, -0.004, hw * 1.08, 0.134 * G)], TOP, caps=(False, True))
        # разрез полы спереди
        strip("hem_split", (0, 0.133 * G + 0.003, hip_z - 0.14), (0, 0.13 * G + 0.003, hip_z + 0.0), 0.008, 0.004, CLOTH_D)
        for s in (-1, 1):   # клапаны нижних карманов
            strip(f"pocket{s}", (0.07 * s - 0.045, 0.128 * G + 0.006, hip_z - 0.02), (0.07 * s + 0.045, 0.128 * G + 0.006, hip_z - 0.02), 0.035, 0.006, CLOTH_D, 0.0)
    if OUT_ == "cardigan":
        loft("cardi_hem", [(hip_z + 0.06, 0, 0.003, hw * 1.04, 0.128 * G), (hip_z - 0.05, 0, 0, hw * 1.07, 0.133 * G)], TOP, caps=(False, True))
if FEM and OUT_ in ("dress", "cardigan"):
    pass
if OUT_ == "guard":
    # ремень с бляхой и кобурой
    loft("belt", [(hip_z + 0.07, 0, 0.003, hw * 1.05, 0.128 * G), (hip_z + 0.025, 0, 0.003, hw * 1.05, 0.128 * G)], cm("belt", (0.22, 0.14, 0.08), 0.5, 0.1, 40, 0.3))
    box("buckle", (0.06, 0.012, 0.045), (0, 0.13 * G + 0.006, hip_z + 0.048), GOLD, 0.003)
    box("holster", (0.04, 0.09, 0.13), (hw * 1.07, -0.02, hip_z - 0.02), cm("holster", (0.18, 0.11, 0.06), 0.5, 0.1, 40, 0.4), 0.012)
if (FEM and OUT_ != "coat") or OUT_ in ("coat", "lab"):
    # Середина юбки/полы между ног: стоя закрывает просвет (без неё — «кюлоты»)
    kz0 = LEG * 0.5 + 0.03
    loft("skirt_mid", [(hip_z - 0.02, 0, 0.0, 0.11 * G, 0.11 * G), (kz0, 0, 0.02, 0.1 * G, 0.1 * G),
                       (kz0 - (0.13 if FEM and OUT_ != "coat" else 0.24), 0, 0.025, 0.095 * G, 0.095 * G)],
         TOP if OUT_ in ("dress", "coat", "lab") else cm("skirt", V.get("skirt", V["pants"]), 0.9, 0.18, 55), 12, caps=(False, True))
own("hips", since(m))

# --- Живот --------------------------------------------------------------------------------
m = mark()
cz = hip_z + TORSO * 0.66
belly = 0.012 * (G - 1.0) * 10      # пузо у грузных
loft("belly", [(wz - 0.01, 0, 0.005, (0.15 if not FEM else 0.135) * G, 0.11 * G),
               ((wz + cz) / 2, 0, 0.012 + belly * 0.6, (0.155 if not FEM else 0.135) * G, (0.115 + belly) * G),
               (cz + 0.01, 0, 0.012, (0.17 if not FEM else 0.15) * G, 0.12 * G)], TOP)
if OUT_ in ("suit", "uniform", "lab", "coat", "cardigan"):
    fy = (0.12 + belly) * G + 0.012
    for k in range(2 if OUT_ != "coat" else 3):
        z = wz + 0.02 + k * 0.09
        for dx in ((0,) if OUT_ != "coat" else (-0.045, 0.045)):
            blob(f"btn_b{k}{dx}", (dx, fy, z), 0.008, BUTTON, scale=(1, 0.5, 1), segs=8, rings=4)
if OUT_ == "dress":
    loft("dress_belt", [(wz + 0.025, 0, 0.006, 0.137 * G, 0.112 * G), (wz - 0.005, 0, 0.006, 0.137 * G, 0.112 * G)], CLOTH_D)
own("spine", since(m))

# --- Грудь, плечи, лацканы, галстук, погоны --------------------------------------------
m = mark()
cw = (0.18 if not FEM else 0.16) * G
loft("ribs", [(cz - 0.01, 0, 0.012, (0.17 if not FEM else 0.15) * G, 0.12 * G), (cz + TORSO * 0.18, 0, 0.012, cw, 0.125 * G),
              (sh_z - 0.05, 0, 0.0, cw * 1.04, 0.11 * G), (sh_z - 0.01, 0, -0.01, cw * 0.72, 0.085), (sh_z + 0.015, 0, -0.01, 0.075, 0.065)], TOP)
for s in (-1, 1):   # дельты
    blob(f"delt{s}", (SH * s * 0.97, 0, sh_z - 0.055), 0.066 * (1 + (G - 1) * 0.5), TOP, scale=(1.0, 1.05, 0.95))
if FEM:
    for s in (-1, 1):
        blob(f"bust{s}", (0.062 * s, 0.078 * G, cz + 0.035), 0.052, TOP, scale=(1.0, 0.62, 0.78))
fy = 0.125 * G + 0.004
if OUT_ in ("suit", "uniform", "lab", "coat"):
    # Вырез: рубашка, галстук; лацканы поверх
    vz0 = cz - 0.02 if OUT_ != "coat" else sh_z - 0.12
    box("shirt_v", (0.085, 0.01, sh_z - vz0), (0, fy - 0.002, (sh_z + vz0) / 2 - 0.01), SHIRT, 0.002)
    if OUT_ != "coat":
        strip("tie", (0, fy + 0.004, sh_z - 0.05), (0, fy + 0.006, vz0 - 0.005), 0.034, 0.006, TIE)
        box("tie_knot", (0.03, 0.02, 0.026), (0, fy, sh_z - 0.03), TIE, 0.006)
    for s in (-1, 1):
        lap = strip(f"lapel{s}", (0.075 * s, fy - 0.005, sh_z - 0.015), (0.012 * s, fy + 0.006, vz0), 0.05 if OUT_ != "coat" else 0.07, 0.008, TOP)
        lap.rotation_euler.rotate_axis("Y", -0.25 * s)
        strip(f"lapel_edge{s}", (0.09 * s, fy - 0.004, sh_z - 0.02), (0.035 * s, fy + 0.007, vz0 + 0.01), 0.004, 0.009, CLOTH_D)
    if OUT_ != "coat":
        strip("breast_pocket", (-0.12, fy - 0.004, cz + 0.06), (-0.06, fy - 0.002, cz + 0.06), 0.012, 0.006, CLOTH_D)
    if OUT_ == "lab":
        strip("pen", (-0.09, fy + 0.002, cz + 0.07), (-0.09, fy + 0.002, cz + 0.13), 0.008, 0.008, cm("pen", (0.1, 0.2, 0.5), 0.4, 0.0))
elif OUT_ == "guard":
    # Гимнастёрка: стойка-воротник, планка с пуговицами, нагрудные карманы с клапанами
    strip("placket", (0, fy, sh_z - 0.02), (0, fy + 0.002, cz - 0.02), 0.03, 0.006, CLOTH_D)
    for k in range(3):
        blob(f"btn_c{k}", (0, fy + 0.006, sh_z - 0.04 - k * 0.06), 0.007, GOLD, scale=(1, 0.5, 1), segs=8, rings=4)
    for s in (-1, 1):
        box(f"chest_pocket{s}", (0.075, 0.008, 0.08), (0.075 * s, fy - 0.004, cz + 0.06), TOP, 0.004)
        box(f"pocket_flap{s}", (0.08, 0.012, 0.025), (0.075 * s, fy, cz + 0.105), CLOTH_D, 0.004)
        blob(f"pocket_btn{s}", (0.075 * s, fy + 0.007, cz + 0.1), 0.006, GOLD, scale=(1, 0.5, 1), segs=8, rings=4)
    # портупея через плечо
    strip("strap", (-0.13, fy - 0.01, sh_z - 0.02), (0.13, fy, hip_z + 0.07), 0.025, 0.006, cm("strap", (0.22, 0.14, 0.08), 0.5, 0.1, 40, 0.3))
elif OUT_ == "dress":
    # Белый отложной воротничок, пуговки
    for s in (-1, 1):
        box(f"collar{s}", (0.06, 0.012, 0.04), (0.035 * s, fy - 0.01, sh_z - 0.01), SHIRT, 0.006).rotation_euler = (D(-20), 0, D(-25 * s))
    for k in range(3):
        blob(f"btn_c{k}", (0, fy + 0.002, sh_z - 0.05 - k * 0.045), 0.006, SHIRT, scale=(1, 0.5, 1), segs=8, rings=4)
    blob("brooch", (-0.07, fy, sh_z - 0.08), 0.01, GOLD, scale=(1, 0.4, 1), segs=8, rings=4)
elif OUT_ == "cardigan":
    box("blouse_v", (0.08, 0.01, 0.15), (0, fy - 0.002, sh_z - 0.08), cm("blouse", V["tie"], 0.6, 0.06, 60), 0.002)
    for s in (-1, 1):
        strip(f"cardi_edge{s}", (0.05 * s, fy + 0.002, sh_z - 0.02), (0.012 * s, fy + 0.004, wz), 0.02, 0.007, TOP)
    for k in range(4):
        blob(f"btn_c{k}", (0.016, fy + 0.008, wz + 0.02 + k * 0.05), 0.006, BUTTON, scale=(1, 0.5, 1), segs=8, rings=4)
if OUT_ in ("uniform", "guard"):
    for s in (-1, 1):   # погоны
        box(f"epaulet{s}", (0.12, 0.055, 0.012), (SH * s * 0.78, -0.005, sh_z - 0.0), cm("epaulet", V["cloth"], 0.7, 0.1, 40), 0.003).rotation_euler = (0, D(-12 * s), 0)
        if OUT_ == "uniform":
            for k in range(2):
                blob(f"star{s}{k}", (SH * s * 0.78 + 0.02 * k * s, 0.0, sh_z + 0.008), 0.006, GOLD, segs=6, rings=4)
            strip(f"stripe{s}", (SH * s * 0.55, 0, sh_z + 0.008), (SH * s, 0, sh_z - 0.002), 0.006, 0.003, cm("blue", (0.2, 0.32, 0.62), 0.6, 0.0))
own("chest", since(m))

# --- Шея, воротник ------------------------------------------------------------------------
m = mark()
limb("neck_c", P("neck", 1) + Vector((0, -0.005, -0.03)), P("neck", 2) + Vector((0, 0.0, 0.03)), 0.05, 0.045, SKIN, 12)
if OUT_ in ("suit", "uniform", "lab"):
    loft("shirt_collar", [(sh_z - 0.005, 0, 0.005, 0.06, 0.058), (sh_z + 0.035, 0, 0.008, 0.055, 0.053)], SHIRT, 14, caps=(False, False))
elif OUT_ == "guard":
    loft("stand_collar", [(sh_z - 0.005, 0, 0.004, 0.062, 0.06), (sh_z + 0.04, 0, 0.006, 0.057, 0.055)], TOP, 14, caps=(False, False))
    loft("collar_white", [(sh_z + 0.04, 0, 0.006, 0.056, 0.054), (sh_z + 0.046, 0, 0.006, 0.055, 0.053)], SHIRT, 14, caps=(False, False))
elif OUT_ == "coat":
    # шарф и большой воротник
    loft("scarf", [(sh_z - 0.01, 0, 0.01, 0.075, 0.07), (sh_z + 0.03, 0, 0.012, 0.065, 0.062), (sh_z + 0.05, 0, 0.012, 0.058, 0.055)],
         cm("scarf", V["tie"], 0.95, 0.35, 90), 14)
    if FEM:
        blob("fur_collar", (0, -0.01, sh_z - 0.01), 0.12, cm("fur", (0.18, 0.13, 0.09), 0.95, 0.4, 160), scale=(1.15, 1.05, 0.45), wobble=0.008)
    else:
        loft("coat_collar", [(sh_z - 0.04, 0, -0.005, 0.13, 0.11), (sh_z + 0.02, 0, -0.02, 0.1, 0.085)], TOP, 14, caps=(False, False))
own("neck", since(m))

# --- Голова: череп, челюсть, скулы, уши, глаза с веками, нос, губы -------------------------
m = mark()
hc = Vector((0, 0.0, head_z + 0.115))
sk = 0.94 if FEM else 1.0
blob("skull", hc + Vector((0, -0.008, 0.008)), 0.1 * sk, SKIN, scale=(0.88, 1.02, 1.1), segs=18, rings=14)
blob("jaw", hc + Vector((0, 0.02, -0.042)), 0.08 * sk, SKIN, scale=(0.84 if not FEM else 0.78, 0.98, 0.76), segs=16, rings=10)
blob("chin", hc + Vector((0, 0.07 * sk, -0.08 * sk)), 0.018, SKIN, scale=(1.3, 0.75, 0.7))
for s in (-1, 1):
    blob(f"ear{s}", hc + Vector((0.091 * s * sk, -0.005, -0.008)), 0.028, SKIN, scale=(0.32, 0.62, 1.05))
    blob(f"ear_in{s}", hc + Vector((0.094 * s * sk, 0.0, -0.008)), 0.017, SKIN_D, scale=(0.3, 0.5, 0.8), segs=8, rings=5)
    # глаз: белок, радужка, зрачок; верхнее веко прикрывает треть, нижнее — чуть-чуть
    e = hc + Vector((0.032 * s * sk, 0.083 * sk, 0.016))
    blob(f"sclera{s}", e, 0.0125, SCLERA, segs=10, rings=7)
    blob(f"iris{s}", e + Vector((0, 0.0105, 0)), 0.0062, IRIS, scale=(1, 0.35, 1), segs=8, rings=5)
    blob(f"pupil{s}", e + Vector((0, 0.0128, 0)), 0.0028, PUPIL, scale=(1, 0.3, 1), segs=6, rings=4)
    lid = blob(f"lid_up{s}", e + Vector((0, 0.0015, 0.0068)), 0.0136, SKIN, scale=(1.08, 1.0, 0.62), segs=10, rings=6)
    blob(f"lid_lo{s}", e + Vector((0, 0.0015, -0.0085)), 0.0128, SKIN, scale=(1.02, 0.95, 0.4), segs=10, rings=5)
    blob(f"socket{s}", e + Vector((0.004 * s, -0.003, 0.012)), 0.017, SKIN_D, scale=(1.2, 0.7, 0.45), segs=8, rings=5)   # тень под бровью
    bro = strip(f"brow{s}", e + Vector((-0.015 * s, 0.0085, 0.0185)), e + Vector((0.018 * s, 0.003, 0.02 if FEM else 0.016)), 0.0055 if not FEM else 0.0035, 0.004, HAIR)
# нос: спинка, кончик, крылья, ноздри
limb("nose_bridge", hc + Vector((0, 0.092 * sk, 0.022)), hc + Vector((0, 0.112 * sk, -0.015)), 0.0065, 0.0095, SKIN, 10)
blob("nose_tip", hc + Vector((0, 0.115 * sk, -0.019)), 0.0115 if not FEM else 0.0095, SKIN, scale=(1.0, 0.95, 0.9))
for s in (-1, 1):
    blob(f"nostril_w{s}", hc + Vector((0.011 * s, 0.106 * sk, -0.022)), 0.008, SKIN, scale=(0.9, 1.0, 0.8), segs=8, rings=5)
    blob(f"nostril{s}", hc + Vector((0.006 * s, 0.11 * sk, -0.028)), 0.0035, SKIN_D, segs=6, rings=4)
# рот: верхняя и нижняя губа, линия смыкания, носогубная складка
blob("lip_up", hc + Vector((0, 0.1 * sk, -0.044)), 0.016, LIPS, scale=(1.25, 0.42, 0.32), segs=10, rings=6)
blob("lip_lo", hc + Vector((0, 0.098 * sk, -0.053)), 0.015, LIPS, scale=(1.1, 0.45, 0.38), segs=10, rings=6)
strip("mouth_line", hc + Vector((-0.017, 0.1035 * sk, -0.0485)), hc + Vector((0.017, 0.1035 * sk, -0.0485)), 0.002, 0.002, SKIN_D)
if V.get("moustache"):
    blob("moustache", hc + Vector((0, 0.108 * sk, -0.036)), 0.02, HAIR, scale=(1.5, 0.5, 0.45), segs=10, rings=6, wobble=0.0015)

# Причёска: шапка волос, срезанная по линии роста
hs = V["hair"]
def hairline(co, c0, front=0.052, back=-0.075, side=-0.012):
    lo = co - c0
    if abs(lo.x) > 0.06 and lo.y > -0.03 and lo.z < 0.02:   # над ушами — короче
        return True
    edge = back + (front - back) * smooth(-0.06, 0.07, lo.y)
    if -0.03 < lo.y < 0.05:
        edge = min(edge, side)
    return lo.z < edge
if hs in ("part", "crew", "bun", "perm", "bald"):
    hr = {"part": 0.108, "crew": 0.104, "bun": 0.106, "perm": 0.118, "bald": 0.106}[hs] * sk
    c0 = hc + Vector((0, -0.01, 0.012))
    cap = blob("hair_cap", c0, hr, HAIR, scale=(0.92, 1.04, 1.06 if hs != "perm" else 1.12), segs=16, rings=12, wobble=0.002 if hs != "perm" else 0.006)
    if hs == "bald":
        cut(cap, lambda co: hairline(co, c0, front=-0.02, back=-0.07, side=-0.03) or (co - c0).z > 0.035 + 0.04 * smooth(0.02, -0.08, (co - c0).y) or (co - c0).y > 0.05)
    else:
        cut(cap, lambda co: hairline(co, c0, front=0.045 if hs != "perm" else 0.035))
    if hs == "part":
        # пробор слева и чуб, зачёсанный набок
        strip("part_line", c0 + Vector((-0.032, 0.06, 0.088)), c0 + Vector((-0.04, -0.03, 0.1)), 0.003, 0.004, SKIN_D)
        blob("quiff", c0 + Vector((0.02, 0.065, 0.075)), 0.045, HAIR, scale=(1.3, 0.8, 0.45), wobble=0.002)
    if hs == "bun":
        blob("bun", hc + Vector((0, -0.105 * sk, 0.055)), 0.042, HAIR, scale=(1.1, 0.9, 1.0), wobble=0.003)
        limb("bun_band", hc + Vector((0, -0.075 * sk, 0.05)), hc + Vector((0, -0.085 * sk, 0.052)), 0.03, 0.03, cm("band", (0.1, 0.1, 0.12), 0.5, 0.0), 10)
    if hs == "perm":
        import random
        rnd = random.Random(7)
        for k in range(42):
            th = rnd.uniform(0, 2 * math.pi); ph = rnd.uniform(0.15, 1.45)
            dv = Vector((math.sin(ph) * math.cos(th) * 0.92, math.sin(ph) * math.sin(th) * 1.02, math.cos(ph) * 1.08))
            p = c0 + dv * hr
            if not hairline(p, c0, front=0.045):
                blob(f"curl{k}", p, 0.024, HAIR, segs=8, rings=5, wobble=0.002)
# Очки: оправа, перемычка, дужки
if V.get("glasses"):
    for s in (-1, 1):
        e = hc + Vector((0.032 * s * sk, 0.1 * sk, 0.016))
        kit.torus(f"rim{s}", 0.019, 0.0024, e, FRAME, maj=16, mino=4)
        limb(f"temple{s}", e + Vector((0.019 * s, -0.004, 0.003)), hc + Vector((0.09 * s * sk, -0.02, 0.012)), 0.002, 0.002, FRAME, 4)
    limb("bridge", hc + Vector((-0.013, 0.104 * sk, 0.02)), hc + Vector((0.013, 0.104 * sk, 0.02)), 0.0022, 0.0022, FRAME, 4)
# Головные уборы
if OUT_ == "guard":
    limb("cap_band", hc + Vector((0, -0.005, 0.06)), hc + Vector((0, -0.005, 0.1)), 0.108, 0.108, cm("cap_band", (0.2, 0.34, 0.68), 0.7, 0.05), 16)
    limb("cap_crown", hc + Vector((0, -0.012, 0.1)), hc + Vector((0, -0.015, 0.135)), 0.112, 0.138, cm("cap", V["cloth"], 0.8, 0.12, 50), 16)
    loft("cap_top", [(hc.z + 0.135, 0, -0.015, 0.138, 0.128), (hc.z + 0.14, 0, -0.015, 0.12, 0.11)], cm("cap", V["cloth"], 0.8, 0.12, 50), 16)
    box("cap_visor", (0.15, 0.065, 0.008), hc + Vector((0, 0.115, 0.063)), cm("visor", (0.04, 0.04, 0.04), 0.25, 0.0), 0.003, rot=(D(-14), 0, 0))
    blob("cap_star", hc + Vector((0, 0.11, 0.08)), 0.012, GOLD, scale=(1, 0.4, 1), segs=6, rings=4)
    strip("cap_cord", hc + Vector((-0.08, 0.085, 0.064)), hc + Vector((0.08, 0.085, 0.064)), 0.006, 0.004, GOLD)
elif V.get("hat") == "pirozhok":
    loft("pirozhok", [(hc.z + 0.065, 0, -0.01, 0.105, 0.112), (hc.z + 0.13, 0, -0.01, 0.1, 0.107), (hc.z + 0.135, 0, -0.01, 0.04, 0.09)],
         cm("karakul", (0.13, 0.12, 0.11), 0.95, 0.5, 220), 16)
    strip("pirozhok_crease", hc + Vector((0, 0.09, 0.135)), hc + Vector((0, -0.09, 0.135)), 0.012, 0.01, cm("karakul_d", (0.08, 0.075, 0.07), 0.95, 0.3, 200))
elif V.get("hat") == "fur":
    blob("fur_hat", hc + Vector((0, -0.01, 0.1)), 0.112, cm("fur_hat", (0.22, 0.16, 0.11), 0.95, 0.45, 160), scale=(1.0, 1.0, 0.68), wobble=0.009)
own("head", since(m))

# --- Руки: рукава, манжеты, кисти с пальцами, часы ---------------------------------------
for s, n in ((-1, "L"), (1, "R")):
    a0, a1, a2, a3 = P(f"upper_arm.{n}", 1), P(f"forearm.{n}", 1), P(f"hand.{n}", 1), P(f"hand.{n}", 2)
    sleeve = TOP
    r0 = (0.062 if not FEM else 0.055) * (1 + (G - 1) * 0.6)
    m = mark()
    limb(f"sleeve{n}", a0 + Vector((0, 0, 0.02)), a1, r0, r0 * 0.85, sleeve)
    blob(f"elbow{n}", a1, r0 * 0.84, sleeve)
    strip(f"seam_up{n}", a0 + Vector((0.0, -r0 * 0.98, -0.02)), a1 + Vector((0.0, -r0 * 0.82, 0.02)), 0.004, 0.004, CLOTH_D)
    own(f"upper_arm.{n}", since(m))
    m = mark()
    cuff = a2 + (a1 - a2).normalized() * 0.03
    limb(f"fore{n}", a1, cuff, r0 * 0.84, r0 * 0.7, sleeve)
    if OUT_ in ("suit", "lab", "uniform"):
        limb(f"shirt_cuff{n}", cuff + (a1 - a2).normalized() * 0.004, a2 + (a1 - a2).normalized() * 0.012, r0 * 0.62, r0 * 0.6, SHIRT)
    elif OUT_ in ("uniform", "guard"):
        limb(f"cuff_band{n}", cuff + (a1 - a2).normalized() * 0.02, cuff, r0 * 0.73, r0 * 0.72, CLOTH_D)
    for k in range(2 if OUT_ in ("suit", "uniform") else 0):   # пуговки на рукаве
        blob(f"slv_btn{n}{k}", cuff + (a1 - a2).normalized() * (0.015 + k * 0.016) + Vector((s * r0 * 0.68, 0, 0)), 0.005, BUTTON, segs=6, rings=4)
    limb(f"wrist{n}", a2 + (a1 - a2).normalized() * 0.02, a2, 0.026, 0.025, SKIN, 10)
    if s < 0 and VAR not in ("clerk2",):
        # Часы на левом: ремешок и циферблат с наружной стороны
        w = a2 + (a1 - a2).normalized() * 0.022
        limb("watch_strap", w + (a1 - a2).normalized() * 0.008, w - (a1 - a2).normalized() * 0.008, 0.029, 0.029, cm("strap_w", (0.12, 0.08, 0.05), 0.5, 0.0), 12)
        limb("watch_face", w + Vector((s * 0.026, 0, 0)), w + Vector((s * 0.033, 0, 0)), 0.013, 0.012, STEEL, 12)
        limb("watch_dial", w + Vector((s * 0.033, 0, 0)), w + Vector((s * 0.0335, 0, 0)), 0.0105, 0.0105, cm("dial", (0.85, 0.82, 0.72), 0.3, 0.0), 12)
    own(f"forearm.{n}", since(m))
    m = mark()
    # Кисть: ладонь (тонкая по X — ладонью к бедру), четыре пальца в две фаланги, большой палец вперёд
    inward = Vector((-s, 0, 0))
    down = (a3 - a2).normalized()
    palm_c = a2 + down * 0.045 + Vector((0, 0.004, 0))
    blob(f"palm{n}", palm_c, 0.04, SKIN, scale=(0.42, 0.88, 1.05), segs=10, rings=7)
    blob(f"knuckles{n}", palm_c + down * 0.032, 0.03, SKIN, scale=(0.48, 1.15, 0.55), segs=10, rings=6)
    for f in range(4):
        y = -0.022 + f * 0.0148
        ln = (0.03, 0.034, 0.032, 0.025)[f] * (0.93 if FEM else 1.0)
        p0 = palm_c + down * 0.04 + Vector((0, y, 0))
        p1 = p0 + down * ln + inward * 0.006
        p2 = p1 + down * ln * 0.75 + inward * 0.012
        limb(f"f{n}{f}a", p0, p1, 0.0078, 0.0068, SKIN, 6)
        blob(f"f{n}{f}j", p1, 0.0068, SKIN, segs=6, rings=4)
        limb(f"f{n}{f}b", p1, p2, 0.0066, 0.0052, SKIN, 6)
        if f == 3 and s > 0 and not FEM and VAR not in ("officer3", "guard"):
            limb("ring", p0 + down * 0.012, p0 + down * 0.018, 0.0092, 0.0092, GOLD, 8)
    t0 = palm_c + Vector((0, 0.03, 0.012)) + inward * 0.006
    t1 = t0 + down * 0.028 + Vector((0, 0.014, 0)) + inward * 0.012
    t2 = t1 + down * 0.02 + Vector((0, 0.006, 0)) + inward * 0.008
    limb(f"thumb{n}a", t0, t1, 0.0095, 0.008, SKIN, 6)
    limb(f"thumb{n}b", t1, t2, 0.0078, 0.006, SKIN, 6)
    own(f"hand.{n}", since(m))

# --- Ноги: брюки со стрелкой, юбки, обувь -------------------------------------------------
for s, n in ((-1, "L"), (1, "R")):
    l0, l1, l2, l3 = P(f"thigh.{n}", 1), P(f"shin.{n}", 1), P(f"foot.{n}", 1), P(f"foot.{n}", 2)
    skirt_mat = TOP if OUT_ in ("dress", "coat", "lab") else cm("skirt", V.get("skirt", V["pants"]), 0.9, 0.18, 55)
    m = mark()
    if not FEM:
        limb(f"thigh{n}", l0 + Vector((0, 0, 0.05)), l1, 0.085 * G, 0.064 * (1 + (G - 1) * 0.5), PANTS)
        blob(f"knee{n}", l1, 0.06 * (1 + (G - 1) * 0.5), PANTS)
        strip(f"crease_t{n}", l0 + Vector((0, 0.08 * G, -0.05)), l1 + Vector((0, 0.063, 0.02)), 0.003, 0.004, PANTS_D)
        if OUT_ == "guard":   # галифе
            blob(f"galife{n}", l0 + (l1 - l0) * 0.4 + Vector((0.012 * s, 0, 0)), 0.078, PANTS, scale=(1.0, 0.95, 1.7))
    else:
        limb(f"thigh{n}", l0 + Vector((0, 0, 0.05)), l1, 0.082 * G, 0.055, cm("stocking", tuple(c * 0.8 for c in V["skin"]), 0.5, 0.04, 30))
    if FEM or long_coat:
        # Пола юбки/пальто — половина на каждом бедре, сужается к колену (сидя — ровные колени, а не тумбы);
        # подол ниже колена — отдельно, на голени: стоя продолжает юбку, сидя свисает с колен вниз
        sw = (0.115 if FEM else 0.12) * G
        kz = l1.z + 0.03
        loft(f"skirt{n}", [(l0.z + 0.03, l0.x * 0.7, 0.0, sw, 0.118 * G), ((l0.z + kz) / 2, l0.x * 0.78 + 0.008 * s, 0.006, sw * 0.97, 0.105 * G),
                           (kz, l0.x * 0.82 + 0.012 * s, 0.012, sw * 0.86, 0.09 * G)],
             skirt_mat, 14, caps=(True, True))
        if long_coat and s > 0:
            strip("coat_split", (0.0, 0.135 * G, l0.z + 0.0), (0.0, 0.125 * G, kz), 0.01, 0.004, CLOTH_D)
    own(f"thigh.{n}", since(m))
    m = mark()
    if FEM or long_coat:
        hem = 0.13 if FEM and OUT_ != "coat" else 0.24
        sw = (0.115 if FEM else 0.12) * G
        cx = l1.x * 0.82 / 0.82 * 0.82 + 0.012 * s
        loft(f"drape{n}", [(l1.z + 0.06, cx, 0.016, sw * 0.9, 0.095 * G), (l1.z - hem * 0.5, cx + 0.008 * s, 0.014, sw * 0.98, 0.1 * G),
                           (l1.z - hem, cx + 0.012 * s, 0.01, sw * 1.03, 0.1 * G)],
             skirt_mat, 14, caps=(True, True))
    if OUT_ == "guard":
        limb(f"boot_shaft{n}", l1 + Vector((0, 0, -0.04)), l2, 0.062, 0.055, SHOE)
        blob(f"boot_top{n}", l1 + Vector((0, 0, -0.04)), 0.062, SHOE, scale=(1, 1, 0.3))
    elif FEM:
        limb(f"shin{n}", l1, l2, 0.05, 0.034, cm("stocking", tuple(c * 0.8 for c in V["skin"]), 0.5, 0.04, 30))
        blob(f"calf{n}", l1 + (l2 - l1) * 0.3 + Vector((0, -0.01, 0)), 0.045, cm("stocking", tuple(c * 0.8 for c in V["skin"]), 0.5, 0.04, 30), scale=(0.95, 1.0, 1.9))
        if OUT_ == "coat":   # зимой — сапожки
            limb(f"fboot{n}", l1 + Vector((0, 0, -0.1)), l2, 0.05, 0.042, SHOE)
    else:
        limb(f"shin{n}", l1, l2 + Vector((0, 0, 0.0)), 0.06 * (1 + (G - 1) * 0.5), 0.05, PANTS)
        strip(f"crease_s{n}", l1 + Vector((0, 0.06, -0.02)), l2 + Vector((0, 0.05, 0.02)), 0.003, 0.004, PANTS_D)
    own(f"shin.{n}", since(m))
    m = mark()
    mid = (l2 + l3) / 2
    if FEM and OUT_ != "coat":
        # туфли-лодочки на каблучке
        blob(f"shoe{n}", mid + Vector((0, 0.01, -0.03)), 0.05, SHOE, scale=(0.72, 2.0, 0.5))
        box(f"heel{n}", (0.03, 0.035, 0.045), l2 + Vector((0, -0.04, -0.06)), SHOE, 0.004)
    else:
        blob(f"shoe{n}", mid + Vector((0, 0.015, -0.025)), 0.058, SHOE, scale=(0.76, 2.05, 0.58))
        blob(f"shoe_ankle{n}", l2 + Vector((0, -0.01, -0.03)), 0.05, SHOE, scale=(0.9, 1.1, 0.9))
        box(f"sole{n}", (0.088, 0.25, 0.016), mid + Vector((0, 0.012, -0.068)), SOLE, 0.004)
        box(f"heel{n}", (0.08, 0.06, 0.022), l2 + Vector((0, -0.05, -0.068)), SOLE, 0.003)
        if OUT_ not in ("guard",):
            strip(f"laces{n}", mid + Vector((0, -0.005, 0.004)), mid + Vector((0, 0.05, -0.006)), 0.025, 0.004, SOLE)
    own(f"foot.{n}", since(m))

for o in kit.objs:
    vg = o.vertex_groups.new(name=owner[o.name])
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
NAME = f"human_ep_{VAR}"
body, img, tris = kit.finish(NAME, OUT, res=1024, origin="keep", samples=20, ao_min=0.55)

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

ACTS = {}


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
    ACTS[name] = keys


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


# Руки, ноги (кости вниз): +X — мах вперёд, Z — в сторону. Позвоночник: −X — наклон вперёд, Y — поворот.
ARMS_DOWN = {"upper_arm.L": (2, 0, 5), "upper_arm.R": (2, 0, -5), "forearm.L": (12, 0, 0), "forearm.R": (12, 0, 0),
             "hand.L": (4, 0, 0), "hand.R": (4, 0, 0)}
IDLE_A = mix(ARMS_DOWN, {"chest": (-2, 0, 0)})
IDLE_B = mix(ARMS_DOWN, {"chest": (-3.5, 0, 0.5), "hips": (0, 0, 1.0), "head": (1.5, 4, 0), "upper_arm.L": (3, 0, 5.5), "upper_arm.R": (3, 0, -5.5)})
clip("idle", {1: IDLE_A, 48: IDLE_B, 96: IDLE_A})

WA = mix(ARMS_DOWN, {"thigh.L": (24, 0, 0), "shin.L": (-6, 0, 0), "foot.L": (-12, 0, 0), "thigh.R": (-16, 0, 0), "shin.R": (-20, 0, 0), "foot.R": (14, 0, 0),
                     "upper_arm.L": (-14, 0, 5), "upper_arm.R": (16, 0, -5), "forearm.L": (10, 0, 0), "forearm.R": (22, 0, 0),
                     "hips": (0, -4, 2), "chest": (-2, 5, -1), "head": (0, -2, 0)})
WB = mix(ARMS_DOWN, {"thigh.L": (4, 0, 0), "shin.L": (-5, 0, 0), "thigh.R": (6, 0, 0), "shin.R": (-46, 0, 0), "foot.R": (8, 0, 0),
                     "root@loc": (0, 0, 0.018), "chest": (-2, 0, 0)})
clip("walk", cycle(WA, WB, 16))

RA = mix({"root@loc": (0, 0, 0.04), "thigh.L": (50, 0, 0), "shin.L": (-30, 0, 0), "thigh.R": (-30, 0, 0), "shin.R": (-70, 0, 0), "foot.R": (20, 0, 0),
          "upper_arm.L": (-40, 0, 6), "forearm.L": (50, 0, 0), "upper_arm.R": (45, 0, -6), "forearm.R": (60, 0, 0), "spine": (-10, 0, 0), "chest": (-6, 6, 0)})
RB = mix({"thigh.L": (10, 0, 0), "shin.L": (-60, 0, 0), "thigh.R": (20, 0, 0), "shin.R": (-20, 0, 0), "root@loc": (0, 0, 0.06),
          "upper_arm.L": (0, 0, 6), "forearm.L": (60, 0, 0), "upper_arm.R": (0, 0, -6), "forearm.R": (60, 0, 0), "spine": (-12, 0, 0)})
clip("run", cycle(RA, RB, 8))

ST = mix(ARMS_DOWN, {"head": (4, 0, 6), "neck": (2, 0, 2)})
clip("still", {1: ST, 60: mix(ST, {"head": (5, 2, 8)}), 70: ST, 120: ST})
PK = mix(ARMS_DOWN, {"spine": (0, 0, -10), "chest": (0, 0, -12), "neck": (0, 0, -8), "head": (0, -10, -22), "upper_arm.L": (30, 0, 20), "forearm.L": (40, 0, 0)})
clip("peek", {1: PK, 50: mix(PK, {"head": (2, -14, -28)}), 60: PK, 100: PK})

# Переминается с ноги на ногу
SH_A = mix(IDLE_A, {"hips": (0, 3, 3), "spine": (0, 0, -2), "chest": (-2, -2, -1.5), "thigh.L": (2, 0, -3), "thigh.R": (-1, 0, -2), "shin.L": (-6, 0, 0),
                    "root@loc": (0.015, 0, -0.005)})
clip("idle_shift", {1: IDLE_A, 22: SH_A, 70: mix(SH_A, {"head": (2, 8, 0)}), 92: IDLE_A, 110: IDLE_A})
# Смотрит на часы (левое запястье к груди, голова вниз)
WT = mix(IDLE_A, {"upper_arm.L": (30, 45, 20), "forearm.L": (90, 0, 0), "hand.L": (-10, 0, 0), "head": (-24, 12, 4), "neck": (-8, 0, 0)})
clip("idle_watch", {1: IDLE_A, 16: WT, 54: mix(WT, {"head": (-20, 12, 4)}), 70: IDLE_A, 100: IDLE_A})
# Поправляет очки/трёт переносицу
GL = mix(IDLE_A, {"upper_arm.R": (85, -15, -30), "forearm.R": (120, 0, 0), "hand.R": (-14, 0, 0), "head": (-6, -4, 0)})
clip("idle_glasses", {1: IDLE_A, 14: GL, 26: mix(GL, {"hand.R": (-20, 0, 4)}), 36: GL, 50: IDLE_A, 80: IDLE_A})
# Оглядывается
clip("look_around", {1: IDLE_A, 20: mix(IDLE_A, {"head": (2, 34, 0), "chest": (-2, 8, 0)}), 50: mix(IDLE_A, {"head": (2, 30, 0), "chest": (-2, 8, 0)}),
                     70: mix(IDLE_A, {"head": (4, -26, 0), "chest": (-2, -6, 0)}), 96: mix(IDLE_A, {"head": (3, -22, 0), "chest": (-2, -6, 0)}), 120: IDLE_A})
# Отдаёт честь: правая ладонь к козырьку
SA = mix(ARMS_DOWN, {"upper_arm.R": (60, 60, -60), "forearm.R": (130, 0, 0), "hand.R": (0, 0, 0), "chest": (1, 0, 0), "head": (-3, 0, 0),
                     "upper_arm.L": (0, 0, 3), "forearm.L": (4, 0, 0)})
clip("salute", {1: ARMS_DOWN, 8: SA, 40: SA, 50: ARMS_DOWN, 60: ARMS_DOWN})
# Говорит стоя: жесты правой, кивки, левая чуть
TA = mix(IDLE_A, {"upper_arm.R": (10, 0, -2), "forearm.R": (75, 0, 0), "hand.R": (-12, 20, 0), "head": (3, -4, 0)})
TB = mix(IDLE_A, {"upper_arm.R": (18, -15, -12), "forearm.R": (85, 0, 0), "hand.R": (8, -10, 10), "upper_arm.L": (10, 10, 6), "forearm.L": (45, 0, 0),
                  "head": (-3, 4, 2), "chest": (-3, -4, 0)})
clip("talk", {1: TA, 10: TB, 20: mix(TA, {"head": (6, -2, 0)}), 30: mix(TB, {"hand.R": (-6, 30, 0)}), 40: TA, 48: TA})

SIT = {"thigh.L": (88, 0, 4), "thigh.R": (88, 0, -4), "shin.L": (-88, 0, 0), "shin.R": (-88, 0, 0), "root@loc": (0, -0.05, 0.0),
       "upper_arm.L": (20, 20, 4), "upper_arm.R": (20, -20, -4), "forearm.L": (60, 0, 0), "forearm.R": (60, 0, 0), "chest": (-3, 0, 0)}
clip("sit_drive", {1: SIT, 40: mix(SIT, {"head": (4, 6, 0), "chest": (-4, 0, 0)}), 80: mix(SIT, {"head": (2, -4, 0)}), 120: SIT})
clip("sit_talk", {1: SIT, 12: mix(SIT, {"upper_arm.R": (12, 0, -4), "forearm.R": (85, 0, 0), "hand.R": (-10, 15, 0), "head": (4, -10, 0)}),
                  24: mix(SIT, {"upper_arm.R": (18, -15, -10), "forearm.R": (95, 0, 0), "head": (-3, -6, 0)}), 36: SIT})
TY = mix(SIT, {"upper_arm.L": (30, 30, 20), "upper_arm.R": (30, -30, -20), "forearm.L": (70, 0, 0), "forearm.R": (70, 0, 0), "head": (-14, 0, 0), "chest": (-6, 0, 0)})
clip("type", {1: TY, 3: mix(TY, {"hand.L": (-14, 0, 0)}), 5: mix(TY, {"hand.R": (-14, 0, 0)}), 7: TY, 9: mix(TY, {"hand.R": (-12, 0, 0), "forearm.R": (44, 0, 0)}),
              11: mix(TY, {"hand.L": (-12, 0, 0)}), 13: TY, 30: mix(TY, {"head": (-8, 8, 0)}), 40: TY})
# Сидя поднимает голову на собеседника
clip("sit_look", {1: SIT, 12: mix(SIT, {"head": (8, -14, 0), "chest": (-1, -6, 0)}), 60: mix(SIT, {"head": (7, -12, 0), "chest": (-1, -6, 0)}), 72: SIT})
SM = mix(ARMS_DOWN, {"upper_arm.R": (0, -15, -10), "forearm.R": (120, 0, 0), "hand.R": (0, 0, 10), "head": (-4, 0, 0)})
SM_IN = mix(ARMS_DOWN, {"upper_arm.R": (70, -30, -30), "forearm.R": (130, 0, 0), "head": (-6, 0, 0)})
clip("smoke", {1: SM, 30: SM, 45: SM_IN, 60: SM_IN, 75: SM, 120: SM})
WF = {"upper_arm.L": (-10, 30, 0), "forearm.L": (110, 0, 0)}
clip("walk_folder", {1: mix(WA, WF), 9: mix(WB, WF), 17: mix(mirror(WA), WF), 25: mix(mirror(WB), WF), 33: mix(WA, WF)})

if os.environ.get("PREVIEW"):
    # Картинки поз: лицо крупно и клипы в полный рост (Workbench)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 420; sc.render.resolution_y = 640
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    shots = [("face", "idle", 1, (0.35, 0.9, head_z + 0.12), (0, 0, head_z + 0.11), 30),
             ("idle", "idle", 1, (1.4, 3.2, 1.1), (0, 0, 0.9), 40)]
    for cn, fr in (("idle_watch", 30), ("idle_glasses", 20), ("salute", 20), ("talk", 10), ("walk", 5), ("sit_drive", 1), ("type", 1), ("smoke", 50)):
        shots.append((cn, cn, fr, (1.4, 3.2, 1.1), (0, 0, 0.85), 40))
        shots.append((cn + "_side", cn, fr, (3.4, 0.4, 1.1), (0, 0, 0.85), 40))
    for sn, cn, fr, cp, look, lens in shots:
        tr = arm.animation_data.nla_tracks[cn]
        tr.mute = False
        sc.frame_set(fr)
        cam.location = cp
        cam.rotation_euler = (Vector(look) - Vector(cp)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens if sn != "face" else 85
        sc.render.filepath = os.path.join(OUT, f"prev_{VAR}_{sn}.png")
        bpy.ops.render.render(write_still=True)
        tr.mute = True

for t in arm.animation_data.nla_tracks:
    t.mute = False
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True); body.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"), export_format="GLB", use_selection=True,
                          export_image_format="AUTO", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_skins=True, export_def_bones=True)
print("[OK]", NAME, "tris:", tris, "clips:", [a.name for a in bpy.data.actions])
