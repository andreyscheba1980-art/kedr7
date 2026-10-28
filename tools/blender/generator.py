# Бензоэлектрический агрегат АБ-4 на салазках для «Кедр-7»: двигатель с оребрённым цилиндром, бак,
# генератор, кожух ремня, воздушный фильтр, щиток с вольтметром, выхлоп в стену.
# Оси как у Props.generator(): начало — пол под агрегатом, щиток смотрит в −Z Godot (= +Y Блендера).
# Запуск: python3 generator.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

GREEN = mat("green", (0.17, 0.21, 0.14), 0.6, 0, 0.25, 120, wear=0.8, dirt=0.7, wear_col=(0.35, 0.33, 0.3))
RED = mat("red", (0.42, 0.07, 0.04), 0.6, 0, 0.2, 100, wear=0.8, dirt=0.6, wear_col=(0.4, 0.33, 0.3))
STEEL = mat("steel", (0.3, 0.31, 0.32), 0.5, 0, 0.2, 200, wear=0.5, dirt=0.6, wear_col=(0.55, 0.55, 0.55))
DARK = mat("dark", (0.04, 0.04, 0.04), 0.7, 0, 0.2, 100, wear=0.4, dirt=0.4, wear_col=(0.2, 0.2, 0.2))
RUST = mat("rust", (0.2, 0.1, 0.05), 0.9, 0, 0.5, 50, wear=0.4, wear_col=(0.35, 0.18, 0.08))
WHITE = mat("white", (0.78, 0.76, 0.68), 0.6)
BLACK = mat("black", (0.015, 0.015, 0.015), 0.7)
RUBBER = mat("rubber", (0.03, 0.03, 0.03), 0.9)
BRASS = mat("brass", (0.55, 0.42, 0.18), 0.4, 0, 0.1, 200, wear=0.4, wear_col=(0.8, 0.68, 0.4))
OIL = mat("oil", (0.02, 0.018, 0.015), 0.2)

# Салазки (полозья вдоль Z Godot = вдоль Y Блендера) и поперечины
for sx in (-0.45, 0.45):
    box(f"skid{sx}", (0.08, 0.66, 0.07), (sx, 0, 0.035), STEEL, 0.006)
    for sy in (-1, 1):
        box(f"skidcurl{sx}{sy}", (0.08, 0.05, 0.05), (sx, sy * 0.34, 0.06), STEEL, 0.008)
for sy in (-0.22, 0.22):
    box(f"cross{sy}", (0.98, 0.06, 0.05), (0, sy, 0.095), STEEL, 0.005)
box("oil_puddle", (0.5, 0.36, 0.002), (-0.1, 0.0, 0.001), OIL, 0)
# Картер и блок двигателя
box("crankcase", (0.55, 0.46, 0.26), (-0.15, 0, 0.25), GREEN, 0.02)
box("block", (0.36, 0.34, 0.2), (-0.2, 0, 0.47), GREEN, 0.015)
# Оребрённый цилиндр (рёбра охлаждения)
for i in range(9):
    box(f"fin{i}", (0.42, 0.4, 0.008), (-0.2, 0, 0.58 + i * 0.022), STEEL, 0.002)
box("head", (0.3, 0.28, 0.05), (-0.2, 0, 0.79), GREEN, 0.01)
cyl("plug", 0.012, 0.05, (-0.2, 0.0, 0.83), BLACK, rot=(0, 0, 0), verts=8)
tube("plug_wire", [(-0.2, 0.0, 0.855), (-0.05, 0.08, 0.9), (0.1, 0.2, 0.7)], 0.004, BLACK, 5)
# Бак сверху на кронштейнах
for sx in (-0.4, 0.1):
    box(f"tank_brk{sx}", (0.03, 0.3, 0.14), (sx, 0, 0.83), STEEL, 0.004)
box("tank", (0.62, 0.34, 0.16), (-0.15, 0, 0.96), RED, 0.03)
cyl("tank_cap", 0.04, 0.03, (-0.3, 0.05, 1.05), STEEL, rot=(0, 0, 0), verts=14, bevel=0.004)
tube("fuel_line", [(-0.4, -0.12, 0.89), (-0.44, -0.14, 0.7), (-0.36, -0.18, 0.55)], 0.005, BLACK, 5)
cyl("fuel_cock", 0.012, 0.04, (-0.4, -0.13, 0.86), BRASS, rot=(math.pi / 2, 0, 0), verts=8)
text("АБ-4", 0.05, (-0.15, 0.172, 0.96), WHITE, 0.0, rot=(math.pi / 2, 0, math.pi))
# Генератор (цилиндр вдоль X) с вентиляционными прорезями и торцевой крышкой
cyl("alt", 0.19, 0.3, (0.3, 0, 0.32), RED, rot=(0, math.pi / 2, 0), verts=28, bevel=0.01)
cyl("alt_cap", 0.17, 0.04, (0.47, 0, 0.32), STEEL, rot=(0, math.pi / 2, 0), verts=28, bevel=0.006)
for i in range(8):
    a = i * math.pi / 4
    box(f"alt_slot{i}", (0.04, 0.012, 0.03), (0.49, math.cos(a) * 0.1, 0.32 + math.sin(a) * 0.1), BLACK, 0)
for i in range(6):
    torus(f"alt_band{i}", 0.192, 0.004, (0.18 + i * 0.045, 0, 0.32), STEEL, rot=(0, math.pi / 2, 0), maj=28, mino=4)
# Кожух ремня / муфта между двигателем и генератором
box("coupling", (0.1, 0.3, 0.3), (0.12, 0, 0.32), GREEN, 0.02)
# Воздушный фильтр и ручной стартер
cyl("airfilter", 0.07, 0.1, (-0.2, 0.22, 0.62), DARK, rot=(math.pi / 2, 0, 0), verts=18, bevel=0.006)
cyl("starter", 0.12, 0.06, (-0.45, 0, 0.36), GREEN, rot=(0, math.pi / 2, 0), verts=24, bevel=0.008)
box("starter_grip", (0.03, 0.1, 0.025), (-0.5, 0, 0.36), BLACK, 0.008)
# Щиток на лицевой стороне (+Y Блендера = −Z Godot): вольтметр, тумблер, красная кнопка «СТОП», табличка
PY = 0.27
box("panel_box", (0.32, 0.06, 0.22), (0.3, PY - 0.03, 0.56), DARK, 0.01)
box("panel_post", (0.04, 0.04, 0.3), (0.3, PY - 0.07, 0.36), STEEL, 0.004)
cyl("volt_rim", 0.048, 0.012, (0.24, PY + 0.003, 0.58), STEEL, verts=24)
cyl("volt_face", 0.04, 0.004, (0.24, PY + 0.008, 0.58), WHITE, verts=24)
for t in range(7):
    a = math.radians(-50 + t * 16.6)
    box(f"vt{t}", (0.002, 0.001, 0.008), (0.24 + math.sin(a) * 0.03, PY + 0.011, 0.57 + math.cos(a) * 0.03), BLACK, 0)
nd = box("volt_needle", (0.0016, 0.001, 0.03), (0.244, PY + 0.012, 0.585), BLACK, 0, rot=(0, math.radians(-30), 0))
box("toggle_base", (0.03, 0.01, 0.03), (0.35, PY + 0.003, 0.6), STEEL, 0.003)
cyl("toggle", 0.004, 0.03, (0.35, PY + 0.015, 0.61), STEEL, rot=(math.radians(70), 0, 0), verts=8)
cyl("stop_btn", 0.016, 0.02, (0.39, PY + 0.008, 0.52), RED, verts=16, bevel=0.003)
box("plate", (0.12, 0.003, 0.03), (0.3, PY + 0.002, 0.49), BRASS, 0.001)
text("СТОП", 0.012, (0.39, PY + 0.003, 0.495), WHITE, 0.0, rot=(math.pi / 2, 0, math.pi))
# Розетки/клеммы и кабель уходит в стену
for i in range(2):
    cyl(f"socket{i}", 0.018, 0.02, (0.22 + i * 0.05, PY + 0.008, 0.5), BLACK, verts=12)
tube("cable", [(0.42, PY - 0.03, 0.5), (0.5, 0.2, 0.4), (0.55, 0.1, 0.06), (0.62, -0.3, 0.02)], 0.012, RUBBER, 8)
# Выхлоп: колено от головки и труба вверх в стену/крышу (как у старой модели)
tube("exhaust", [(-0.42, -0.1, 0.45), (-0.5, -0.25, 0.6), (-0.5, -0.3, 1.6)], 0.035, RUST, 10)
torus("exh_clamp", 0.04, 0.007, (-0.5, -0.29, 1.2), STEEL, rot=(0, 0, 0), maj=16, mino=5)
cyl("muffler", 0.06, 0.22, (-0.5, -0.27, 0.85), RUST, rot=(0, 0, 0), verts=16, bevel=0.01)

obj, img, tris = kit.finish("generator_ab4", OUT, res=1024, origin="keep", samples=48)
kit.export(os.path.join(OUT, "generator_ab4.glb"), os.path.join(OUT, "generator_ab4.blend"))
print("OK tris:", tris)
