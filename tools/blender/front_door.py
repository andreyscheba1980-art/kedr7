# Входная дверь станции «Кедр-7»: снаружи обита дерматином с обойными гвоздями ромбом, изнутри —
# строганые доски с наугольником-«Z», кованые петли, скобы-ручки, засов, глазок.
# Оси двери в Godot: X — толщина (+X — улица), Y — вверх, Z — ширина (петли при −Z).
# В Блендере: X = X, Y = −Z Godot, Z = Y Godot. Начало — центр полотна (как у узла двери в игре).
# Запуск: python3 front_door.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

W, H, T = 1.0, 2.0, 0.08
LEATHER = mat("leather", (0.09, 0.05, 0.035), 0.5, 0, 0.35, 70, wear=1.0, dirt=0.6, wear_col=(0.2, 0.14, 0.1))
PLANK = mat("plank", (0.36, 0.25, 0.15), 0.7, 0, 0.35, 25, wear=0.6, dirt=0.6, wear_col=(0.5, 0.4, 0.28))
PLANK2 = mat("plank2", (0.3, 0.2, 0.12), 0.7, 0, 0.35, 25, wear=0.6, dirt=0.6, wear_col=(0.45, 0.35, 0.25))
IRON = mat("iron", (0.06, 0.06, 0.06), 0.6, 0, 0.3, 80, wear=0.7, dirt=0.4, wear_col=(0.3, 0.3, 0.3))
RUST = mat("rust", (0.17, 0.09, 0.05), 0.8, 0, 0.4, 60, wear=0.4, wear_col=(0.3, 0.16, 0.08))
NAIL = mat("nail", (0.55, 0.47, 0.3), 0.4)
BLACK = mat("black", (0.01, 0.01, 0.01), 0.5)
GLASS = mat("glass", (0.12, 0.14, 0.15), 0.2)

# Основа полотна (между обивкой и досками)
box("core", (T - 0.02, W, H), (0, 0, 0), PLANK2, 0.004)
# --- Внутренняя сторона (−X): вертикальные доски, щели, наугольник-Z
n = 6
pw = W / n
for i in range(n):
    y = -W / 2 + pw * (i + 0.5)
    box(f"plank{i}", (0.012, pw - 0.006, H - 0.01), (-T / 2 + 0.004, y, 0), PLANK if i % 2 else PLANK2, 0.002)
for z in (-0.72, 0.72):
    box(f"batten{z}", (0.022, W - 0.08, 0.11), (-T / 2 - 0.012, 0, z), PLANK, 0.004)
diag_len = math.hypot(W - 0.14, 1.44 - 0.11)
ang = math.atan2(1.44 - 0.11, W - 0.14)
box("brace", (0.022, diag_len, 0.1), (-T / 2 - 0.012, 0, 0), PLANK, 0.004, rot=(-ang, 0, 0))
# --- Наружная сторона (+X): дерматин на ватине (валики по краю) и гвозди ромбом
box("leather", (0.016, W - 0.04, H - 0.04), (T / 2 + 0.006, 0, 0), LEATHER, 0.008)
for sy in (-1, 1):
    cyl(f"roll_v{sy}", 0.016, H - 0.06, (T / 2 + 0.008, sy * (W / 2 - 0.035), 0), LEATHER, rot=(0, 0, 0), verts=10)
for sz in (-1, 1):
    cyl(f"roll_h{sz}", 0.016, W - 0.1, (T / 2 + 0.008, 0, sz * (H / 2 - 0.035)), LEATHER, rot=(math.pi / 2, 0, 0), verts=10)
# Ромбы из гвоздей: диагонали шагом 0.22
step = 0.2
pts = set()
for k in range(-12, 13):
    for t in range(-30, 31):
        y = t * 0.035
        z1 = k * step + y * 1.6
        if abs(y) < W / 2 - 0.08 and abs(z1) < H / 2 - 0.08:
            pts.add((round(y, 3), round(z1, 3)))
        z2 = k * step - y * 1.6
        if abs(y) < W / 2 - 0.08 and abs(z2) < H / 2 - 0.08:
            pts.add((round(y, 3), round(z2, 3)))
for i, (y, z) in enumerate(sorted(pts)):
    sphere(f"nail{i}", 0.006, (T / 2 + 0.015, y, z), NAIL, scale=(0.5, 1, 1), segs=6, rings=4)
# Гвозди по периметру обивки
for i in range(24):
    t = i / 23
    for sy in (-1, 1):
        sphere(f"edge_v{sy}{i}", 0.006, (T / 2 + 0.024, sy * (W / 2 - 0.035), -H / 2 + 0.06 + t * (H - 0.12)), NAIL, scale=(0.5, 1, 1), segs=6, rings=4)
# --- Петли (кованые полосы) на внутренней стороне у кромки −Z Godot = +Y Блендера
for z in (-0.72, 0.72):
    box(f"hinge{z}", (0.006, 0.42, 0.05), (-T / 2 - 0.026, W / 2 - 0.21, z), IRON, 0.002)
    cyl(f"knuckle{z}", 0.018, 0.12, (-T / 2 + 0.01, W / 2 + 0.01, z), IRON, rot=(0, 0, 0), verts=12)
    for b in range(3):
        cyl(f"bolt{z}{b}", 0.007, 0.006, (-T / 2 - 0.03, W / 2 - 0.08 - b * 0.12, z), IRON, rot=(0, math.pi / 2, 0), verts=8)
# --- Ручки-скобы с обеих сторон у кромки +Z Godot (−Y Блендера, z = 0.38 в игре → y = −0.38)
HY = -0.38
for sx in (-1, 1):
    x0 = sx * (T / 2 + (0.024 if sx > 0 else 0.026))
    tube(f"handle{sx}", [(x0, HY, 0.12), (x0 + sx * 0.05, HY, 0.1), (x0 + sx * 0.05, HY, -0.1), (x0, HY, -0.12)], 0.009, IRON, 8)
    for zz in (0.12, -0.12):
        box(f"hplate{sx}{zz}", (0.004, 0.04, 0.05), (x0, HY, zz), IRON, 0.002)
# --- Засов изнутри: две скобы и задвинутая полоса, уходит к косяку
for yy in (-0.28, -0.12):
    box(f"bolt_keep{yy}", (0.02, 0.025, 0.05), (-T / 2 - 0.03, yy, 0.12), IRON, 0.003)
box("bolt_bar", (0.014, 0.34, 0.03), (-T / 2 - 0.042, -0.31, 0.12), RUST, 0.003)
cyl("bolt_knob", 0.012, 0.04, (-T / 2 - 0.06, -0.2, 0.12), IRON, rot=(0, math.pi / 2, 0), verts=10)
# --- Глазок (в игре — отдельный интерактив на y +0.6; тут оправа с обеих сторон)
for sx in (-1, 1):
    cyl(f"peep{sx}", 0.016, 0.012, (sx * (T / 2 + 0.018), 0.0, 0.6), IRON, rot=(0, math.pi / 2, 0), verts=14)
    cyl(f"peepg{sx}", 0.008, 0.004, (sx * (T / 2 + 0.025), 0.0, 0.6), GLASS, rot=(0, math.pi / 2, 0), verts=12)
# --- Жестяная табличка с номером снаружи
box("number", (0.003, 0.14, 0.09), (T / 2 + 0.02, 0.0, 0.82), IRON, 0.002)
text("7", 0.07, (T / 2 + 0.022, 0.0, 0.82), NAIL, 0.0, rot=(math.pi / 2, 0, math.pi / 2))
# Нижняя накладка от пинков (железо) снаружи
box("kick", (0.004, W - 0.06, 0.12), (T / 2 + 0.02, 0, -H / 2 + 0.07), RUST, 0.002)

obj, img, tris = kit.finish("front_door", OUT, res=1024, origin="keep", samples=48)
kit.export(os.path.join(OUT, "front_door.glb"), os.path.join(OUT, "front_door.blend"))
print("OK tris:", tris)
