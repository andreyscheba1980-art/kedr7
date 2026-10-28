# «Кедр-7» — Ырка v2: замёрзший прежний дежурный (docs/ПЛАН_МОБЫ_И_КОРПУС.md).
# Рваный тулуп с инеем, шерстяной воротник, ушанка набок, ватные штаны, валенки. Руки тонкие, до колен,
# пальцы на треть длиннее человеческих и почерневшие от обморожения. Лицо: впалые щёки, глазницы под
# коркой инея, рот шире человеческого — зубы в щели. Сплошная кожа и плавные веса (anatomy.py).
# Скелет и клипы — как у прежнего yrka_rig.py (idle, stalk, run, sniff, lunge, peek, pin): поведение то же.
# Нос смотрит в +Y (в Godot −Z), ноги на z = 0.
# Запуск: blender --background --python yrka_v2.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, anatomy as an
from anatomy import skin, sculpt, dent, squash, rag_hem, weights, frosted
from mathutils import Vector

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

# --- Материалы ---------------------------------------------------------------------
COAT = frosted("y2_coat", (0.075, 0.06, 0.05), amount=0.2, top_bias=0.85)
WOOL = frosted("y2_wool", (0.14, 0.12, 0.10), amount=0.18, top_bias=0.7)
SKIN = frosted("y2_skin", (0.21, 0.23, 0.26), frost=(0.62, 0.68, 0.75), amount=0.18, top_bias=0.6)
HAND = frosted("y2_hand", (0.22, 0.23, 0.26), amount=0.3, dark=(0.05, 0.04, 0.045), dark_z=1.0)
HAND_R = frosted("y2_hand_r", (0.22, 0.23, 0.26), amount=0.3, dark=(0.05, 0.04, 0.045), dark_z=0.93)
PANTS = frosted("y2_pants", (0.06, 0.065, 0.06), amount=0.25)
FELT = frosted("y2_felt", (0.11, 0.105, 0.1), amount=0.2, top_bias=0.9)
HAT = frosted("y2_hat", (0.09, 0.08, 0.07), amount=0.25)
RIBS = frosted("y2_ribs", (0.2, 0.2, 0.22), amount=0.1)
ROPE = kit.mat("y2_rope", (0.33, 0.28, 0.2), rough=0.9, noise=0.3, noise_scale=40)
TEETH = kit.mat("y2_teeth", (0.62, 0.58, 0.46), rough=0.5, dirt=0.4)
VOID = kit.mat("y2_void", (0.01, 0.01, 0.012), rough=0.9)

# --- Кости (как в прежнем yrka_rig.py) ------------------------------------------------
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
    sz = 1.36 if s < 0 else 1.29
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
parts = []          # (объект, разрешённые кости)

# --- Тулуп: корпус, рукава до середины предплечья, полы до бедра --------------------
zl, zr = 1.36, 1.29
coat_nodes = [
    (0, -0.04, 0.86, 0.20, 0.17), (0, -0.01, 1.04, 0.175, 0.15), (0, 0.08, 1.22, 0.21, 0.17), (0, 0.2, 1.34, 0.17, 0.13),
    (0, -0.03, 0.64, 0.23, 0.2),
    (-0.22, 0.27, zl - 0.01, 0.09, 0.09), (-0.33, 0.34, zl - 0.41, 0.066, 0.066), (-0.325, 0.38, zl - 0.6, 0.062, 0.062),
    (0.22, 0.27, zr - 0.01, 0.09, 0.09), (0.33, 0.34, zr - 0.41, 0.066, 0.066), (0.325, 0.38, zr - 0.6, 0.062, 0.062),
]
coat = skin("coat", coat_nodes, [(4, 0), (0, 1), (1, 2), (2, 3), (3, 5), (5, 6), (6, 7), (3, 8), (8, 9), (9, 10)], COAT, root=1)
squash(coat, (0, 0.14, 1.28), 0.28, (1.0, 0.88, 1.0))        # впалая грудь
dent(coat, (0, 0.0, 1.3), 0.2, 0.05)                           # горб сзади (−Y)
sculpt(coat, amp=0.04, scale=4.0, seed=1.0)                    # крупные заломы: форма неровная, не трубка
sculpt(coat, amp=0.02, scale=11.0, seed=2.5, ridge=True)        # складки овчины
sculpt(coat, amp=0.006, scale=30.0, seed=4.0)
rag_hem(coat, 0.6, amp=0.05, scale=10.0)                       # рваные полы
# Тулуп распахнут на груди: полы расходятся — под ними иссохшая грудь с рёбрами
import bmesh
from mathutils import noise as _nz
bm = bmesh.new(); bm.from_mesh(coat.data)
kill = [f for f in bm.faces if (lambda c: c.y > 0.12 and abs(c.x) < 0.07 + 0.04 * (1.3 - c.z) * 3 + _nz.noise(c * 14) * 0.02 and 0.95 < c.z < 1.33)(f.calc_center_median())]
bmesh.ops.delete(bm, geom=kill, context="FACES"); bm.to_mesh(coat.data); bm.free(); coat.data.update()
for n, s in (("L", -1), ("R", 1)):                             # рваные обшлага
    cz = (zl if s < 0 else zr) - 0.58
    bm_sel = None
parts.append((coat, ["hips", "spine", "chest", "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "thigh.L", "thigh.R"]))

# Иссохшая грудь в прорехе: впалый живот, рёбра проступают дугами
ribcage = skin("ribs", [(0, 0.1, 0.98, 0.13, 0.1), (0, 0.15, 1.14, 0.15, 0.11), (0, 0.18, 1.3, 0.14, 0.1)], [(0, 1), (1, 2)], RIBS, root=1)
dent(ribcage, (0, 0.25, 1.02), 0.12, -0.03)
for i in range(5):
    z = 1.08 + i * 0.045
    for v in ribcage.data.vertices:
        if v.co.y > 0.15 and abs(v.co.z - z - abs(v.co.x) * 0.25) < 0.012:
            v.co += v.normal * 0.012
ribcage.data.update()
sculpt(ribcage, amp=0.004, scale=50.0, seed=11.0)
parts.append((ribcage, ["hips", "spine", "chest"]))
# Верёвка вместо ремня
belt = []
for i in range(12):
    a = i / 12 * math.tau
    belt.append((math.cos(a) * 0.19, -0.01 + math.sin(a) * 0.165, 1.0 + math.sin(a * 2) * 0.01, 0.014, 0.014))
belt_o = skin("belt", belt, [(i, (i + 1) % 12) for i in range(12)], ROPE)
parts.append((belt_o, ["hips", "spine"]))

# Шерстяной воротник: кольцо вокруг шеи
ring = []
for i in range(10):
    a = i / 10 * math.tau
    ring.append((math.cos(a) * 0.12, 0.25 + math.sin(a) * 0.09, 1.40 + math.sin(a) * 0.03, 0.036, 0.036))
collar = skin("collar", ring, [(i, (i + 1) % 10) for i in range(10)], WOOL)
sculpt(collar, amp=0.02, scale=22.0, seed=2.0, ridge=True)
parts.append((collar, ["chest", "neck"]))

# --- Шея и голова --------------------------------------------------------------------
head = skin("head", [
    (0, 0.27, 1.36, 0.048, 0.045), (0, 0.38, 1.41, 0.044, 0.042), (0, 0.48, 1.46, 0.098, 0.108),
    (0, 0.57, 1.455, 0.094, 0.1), (0, 0.635, 1.39, 0.05, 0.045)], [(0, 1), (1, 2), (2, 3), (3, 4)], SKIN, subdiv=2, root=2)
squash(head, (0, 0.52, 1.46), 0.16, (0.92, 1.12, 1.02))        # вытянутый череп
for s in (-1, 1):
    dent(head, (0.042 * s, 0.655, 1.475), 0.035, -0.026)       # глазницы
    dent(head, (0.065 * s, 0.625, 1.415), 0.045, -0.018)       # впалые щёки
dent(head, (0, 0.672, 1.445), 0.022, 0.012)                    # нос
dent(head, (0, 0.66, 1.5), 0.05, 0.006)                        # надбровье
# Рот шире человеческого: щель через всё лицо
for v in head.data.vertices:
    if v.co.y > 0.6 and abs(v.co.x) < 0.075 and abs(v.co.z - 1.405 - abs(v.co.x) * 0.15) < 0.011:
        v.co -= v.normal * 0.03
head.data.update()
sculpt(head, amp=0.004, scale=40.0, seed=3.0)                  # морщины и обмороженная кожа
parts.append((head, ["neck", "head", "jaw"]))
# Зубы в щели и тёмная глотка
for i in range(9):
    x = -0.06 + i * 0.015
    kit.box(f"tooth{i}", (0.009, 0.008, 0.016 - abs(x) * 0.08), (x, 0.648 - abs(x) * 0.25, 1.407 + abs(x) * 0.15), TEETH, bevel=0.0)
    parts.append((kit.objs[-1], ["head"]))
kit.box("throat", (0.11, 0.03, 0.018), (0, 0.63, 1.405), VOID, bevel=0.0)
parts.append((kit.objs[-1], ["head", "jaw"]))

# Ушанка набок: тулья и уши (одно задрано)
hat = skin("hat", [(0.015, 0.47, 1.535, 0.115, 0.13), (0.03, 0.5, 1.56, 0.1, 0.1),
                   (-0.105, 0.5, 1.47, 0.028, 0.045), (-0.11, 0.52, 1.39, 0.024, 0.04),
                   (0.12, 0.47, 1.52, 0.028, 0.045), (0.17, 0.46, 1.58, 0.024, 0.04)],
           [(0, 1), (0, 2), (2, 3), (0, 4), (4, 5)], HAT)
squash(hat, (0.015, 0.47, 1.535), 0.15, (1.0, 1.0, 0.6))
sculpt(hat, amp=0.012, scale=26.0, seed=5.0, ridge=True)
parts.append((hat, ["head"]))

# --- Предплечья и кисти с длинными пальцами -----------------------------------------
for s, n, sz, mat in ((-1, "L", zl, HAND), (1, "R", zr, HAND_R)):
    wr = Vector(B[f"hand.{n}"][1])
    nodes = [(0.325 * s, 0.37, sz - 0.56, 0.042, 0.04), (wr.x, wr.y, wr.z, 0.03, 0.028),
             (wr.x, wr.y + 0.025, wr.z - 0.07, 0.042, 0.022)]
    edges = [(0, 1), (1, 2)]
    for f in range(4):
        dx = (-0.027 + f * 0.018) * s
        base = len(nodes)
        L = 0.085 - abs(f - 1.5) * 0.008
        p0 = Vector((wr.x + dx, wr.y + 0.03, wr.z - 0.1))
        p1 = p0 + Vector((dx * 0.4, 0.035, -L))
        p2 = p1 + Vector((dx * 0.2, 0.02, -L * 0.95))
        p3 = p2 + Vector((0.0, -0.012, -L * 0.8))
        nodes += [(*p0, 0.011, 0.01), (*p1, 0.009, 0.009), (*p2, 0.008, 0.008), (*p3, 0.004, 0.004)]
        edges += [(2, base), (base, base + 1), (base + 1, base + 2), (base + 2, base + 3)]
    # большой палец
    t0 = Vector((wr.x - 0.03 * s, wr.y + 0.035, wr.z - 0.06))
    base = len(nodes)
    nodes += [(*t0, 0.011, 0.011), (*(t0 + Vector((-0.02 * s, 0.05, -0.04))), 0.009, 0.009), (*(t0 + Vector((-0.025 * s, 0.09, -0.08))), 0.005, 0.005)]
    edges += [(2, base), (base, base + 1), (base + 1, base + 2)]
    arm_o = skin("arm" + n, nodes, edges, mat, root=1)
    sculpt(arm_o, amp=0.003, scale=60.0, seed=6.0 + s)
    parts.append((arm_o, [f"upper_arm.{n}", f"forearm.{n}", f"hand.{n}"]))

# --- Ноги: ватные штаны и валенки -----------------------------------------------------
for s, n in ((-1, "L"), (1, "R")):
    hp = Vector(B[f"thigh.{n}"][1]); kn = Vector(B[f"shin.{n}"][1]); an_ = Vector(B[f"foot.{n}"][1]); to = Vector(B[f"foot.{n}"][2])
    mid = kn.lerp(an_, 0.45)
    legs = skin("pants" + n, [(*hp, 0.09, 0.09), (*kn, 0.066, 0.066), (*mid, 0.058, 0.058)], [(0, 1), (1, 2)], PANTS)
    sculpt(legs, amp=0.025, scale=6.0, seed=7.0 + s)
    sculpt(legs, amp=0.01, scale=16.0, seed=17.0 + s, ridge=True)
    parts.append((legs, ["hips", f"thigh.{n}", f"shin.{n}"]))
    boot = skin("boot" + n, [(*(kn.lerp(an_, 0.35)), 0.07, 0.07), (*an_, 0.068, 0.068), (*(to + Vector((0, 0.02, 0.02))), 0.055, 0.045)], [(0, 1), (1, 2)], FELT)
    sculpt(boot, amp=0.01, scale=18.0, seed=9.0 + s)
    parts.append((boot, [f"shin.{n}", f"foot.{n}"]))

# --- Лохмотья: рваные полосы с пол и обшлагов — силуэт перестаёт быть гладким ----------
import random
rnd = random.Random(7)
def rag(top, length, bones, w=0.035):
    t = Vector(top)
    sway = Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), 0))
    nodes = [(*t, w, 0.006), (*(t + sway * 0.5 + Vector((0, 0, -length * 0.5))), w * 0.8, 0.005), (*(t + sway + Vector((0, 0, -length))), w * 0.3, 0.004)]
    o = skin("rag", nodes, [(0, 1), (1, 2)], COAT, subdiv=0)
    parts.append((o, bones))
for i in range(13):
    a = rnd.uniform(-2.6, 2.6) + math.pi * 0.5
    r = 0.21
    rag((math.cos(a) * r, -0.03 + math.sin(a) * 0.18, 0.62), rnd.uniform(0.12, 0.3), ["hips", "thigh.L" if math.cos(a) < 0 else "thigh.R"])
for s_, n in ((-1, "L"), (1, "R")):
    cz = (zl if s_ < 0 else zr) - 0.6
    for k in range(3):
        a = k * 2.1 + rnd.uniform(0, 1)
        rag((0.325 * s_ + math.cos(a) * 0.055, 0.38 + math.sin(a) * 0.055, cz), rnd.uniform(0.08, 0.16), [f"forearm.{n}"], w=0.025)

# --- Веса и сборка ----------------------------------------------------------------------
for o, allowed in parts:
    weights(o, BONES, allowed)

body, img, tris = kit.finish("yrka", OUT, res=2048, origin="keep", samples=32, ao_min=0.4, pack=0.004, ao_blur=2)

# --- Арматура и клипы (как прежде) ---------------------------------------------------
arm = an.armature(BONES, "YrkaArm")
FPS = 24
bpy.context.scene.render.fps = FPS
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

an.export_rigged(arm, body, OUT, "yrka")
print("[OK] yrka v2 tris:", tris, "bones:", len(BONES))
