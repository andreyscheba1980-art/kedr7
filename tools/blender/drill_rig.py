# «Кедр-7» — брошенная разведочная буровая: решётчатая вышка 16 м на санном основании,
# площадка с лебёдкой, балок-«будка бурильщика», стеллаж труб. Всё в инее и ржавчине.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat, text
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
D = math.radians
STEEL = mat("rig_steel", (0.32, 0.14, 0.08), rough=0.7, wear=0.7, dirt=0.7, noise=0.3, noise_scale=20, wear_col=(0.5, 0.48, 0.45))
GREY = mat("rig_grey", (0.3, 0.31, 0.3), rough=0.6, wear=0.7, dirt=0.7, wear_col=(0.5, 0.3, 0.2))
WOOD = mat("rig_wood", (0.3, 0.22, 0.15), rough=0.85, wear=0.5, dirt=0.7, wear_col=(0.45, 0.38, 0.3))
BALOK = mat("rig_balok", (0.22, 0.33, 0.36), rough=0.6, wear=0.6, dirt=0.65, wear_col=(0.5, 0.5, 0.48))
DARK = mat("rig_dark", (0.06, 0.06, 0.06), rough=0.7)
WHITE = mat("rig_white", (0.8, 0.78, 0.72), rough=0.6, wear=0.4, dirt=0.5)
SNOW = mat("rig_snow", (0.88, 0.92, 0.96), rough=0.95)

H = 16.0; B = 2.4; T = 0.55; FLOOR = 2.0
def leg_pt(sx, sy, z):
    k = (z - FLOOR) / (H - FLOOR)
    h = B + (T - B) * k
    return (sx * h, sy * h, z)
# Санное основание и площадка
for sx in (-1, 1):
    box(f"skid{sx}", (0.4, 9.0, 0.5), (sx * 2.2, 0, 0.25), GREY, 0.03)
    box(f"skidnose{sx}", (0.4, 0.8, 0.4), (sx * 2.2, 4.7, 0.45), GREY, 0.03, rot=(D(35), 0, 0))
for y in (-3.5, -1.5, 0.5, 2.5):
    box(f"cross{y}", (4.8, 0.3, 0.3), (0, y, 0.6), GREY, 0.02)
box("floor", (5.6, 6.0, 0.15), (0, -0.5, FLOOR), WOOD, 0.01)
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl(f"post{sx}{sy}", 0.12, FLOOR - 0.6, (sx * 2.4, sy * 2.4 - 0.5, 0.6 + (FLOOR - 0.6) / 2), GREY, rot=(0, 0, 0), verts=8)
# Перила
tube("rail", [(-2.8, -3.5, FLOOR + 1.0), (2.8, -3.5, FLOOR + 1.0), (2.8, 2.5, FLOOR + 1.0)], 0.03, STEEL, 6)
# Лестница на площадку
for k in range(7):
    box(f"step{k}", (0.9, 0.28, 0.05), (-2.0, -3.9 - k * 0.3, FLOOR - k * 0.28), STEEL, 0.005)
tube("ladrail", [(-2.45, -3.6, FLOOR + 0.9), (-2.45, -5.9, 0.3)], 0.03, STEEL, 6)
# Вышка: четыре ноги и раскосы по секциям
levels = [FLOOR + i * (H - FLOOR) / 7 for i in range(8)]
corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
for sx, sy in corners:
    tube(f"leg{sx}{sy}", [leg_pt(sx, sy, FLOOR), leg_pt(sx, sy, H)], 0.09, STEEL, 8)
for i in range(7):
    z0, z1 = levels[i], levels[i + 1]
    for a, b in zip(corners, corners[1:] + corners[:1]):
        tube(f"h{i}{a}", [leg_pt(*a, z1), leg_pt(*b, z1)], 0.045, STEEL, 6)
        tube(f"x1{i}{a}", [leg_pt(*a, z0), leg_pt(*b, z1)], 0.03, STEEL, 6)
        tube(f"x2{i}{a}", [leg_pt(*b, z0), leg_pt(*a, z1)], 0.03, STEEL, 6)
# Кронблок и полати
box("crown", (1.6, 1.6, 0.5), (0, 0, H + 0.25), GREY, 0.03)
cyl("sheave", 0.4, 0.2, (0, 0, H + 0.55), DARK, rot=(0, D(90), 0), verts=16)
box("monkeyboard", (1.8, 0.8, 0.08), (0, -1.25, FLOOR + 9.0), WOOD, 0.01)
# Талевый блок на тросе и ротор
tube("line", [(0.05, 0, H + 0.2), (0.05, 0, FLOOR + 4.0)], 0.012, DARK, 4)
box("travel_block", (0.6, 0.4, 1.0), (0, 0, FLOOR + 3.5), GREY, 0.05)
cyl("hook", 0.08, 0.5, (0, 0, FLOOR + 2.8), DARK, rot=(0, 0, 0), verts=8)
cyl("rotary", 0.7, 0.4, (0, 0, FLOOR + 0.25), GREY, rot=(0, 0, 0), verts=20)
cyl("pipe_stub", 0.11, 1.0, (0, 0, FLOOR + 0.9), STEEL, rot=(0, 0, 0), verts=12)
# Лебёдка
box("drawworks", (2.0, 1.2, 1.1), (0, 1.8, FLOOR + 0.6), BALOK, 0.04)
cyl("drum", 0.45, 1.6, (0, 1.2, FLOOR + 0.9), DARK, rot=(0, D(90), 0), verts=16)
# Будка бурильщика на полозьях (рядом, на земле)
bx, by = 5.6, -1.0
for sx in (-1, 1):
    box(f"bskid{sx}", (0.25, 6.0, 0.3), (bx + sx * 1.1, by, 0.15), GREY, 0.02)
box("balok", (2.5, 5.6, 2.4), (bx, by, 1.5), BALOK, 0.05)
box("balok_roof", (2.7, 5.8, 0.15), (bx, by, 2.78), GREY, 0.03)
box("balok_door", (0.05, 0.8, 1.8), (bx - 1.26, by + 1.6, 1.25), DARK, 0.01)
box("balok_win", (0.05, 0.8, 0.6), (bx - 1.26, by - 1.0, 1.8), DARK, 0.01)
cyl("chimney", 0.08, 0.9, (bx + 0.6, by - 2.0, 3.2), DARK, rot=(0, 0, 0), verts=8)
text("СБУ-3 · ГЕОЛРАЗВЕДКА", 0.22, (bx + 1.262, by, 2.1), WHITE, rot=(D(90), 0, D(90)))
# Стеллаж труб
for k in range(3):
    box(f"rack{k}", (0.15, 0.15, 0.6), (-4.4 + k * 0.0, -3.5 + k * 3.0, 0.3), WOOD, 0.01)
for k in range(9):
    r = k // 4
    cyl(f"pipe{k}", 0.09, 6.4, (-4.65 + (k % 4) * 0.2 + r * 0.1, -0.5, 0.7 + r * 0.17), STEEL, rot=(D(90), 0, 0), verts=10)
# Бочки
for i, (x, y) in enumerate([(3.2, 4.0), (3.8, 4.3), (3.4, 4.8)]):
    cyl(f"barrel{i}", 0.29, 0.88, (x, y, 0.44), BALOK if i % 2 else STEEL, rot=(0, 0, 0), verts=14)
# Снег на площадке и крыше балка
box("snow_floor", (5.0, 5.2, 0.08), (0.2, -0.6, FLOOR + 0.1), SNOW, 0.04)
box("snow_roof", (2.5, 5.5, 0.12), (bx, by, 2.9), SNOW, 0.05)

obj, img, tris = kit.finish("drill_rig", OUT, res=2048, origin="bottom", samples=24)
kit.export(os.path.join(OUT, "drill_rig.glb"), os.path.join(OUT, "drill_rig.blend"))
print("[OK] drill_rig tris:", tris)
