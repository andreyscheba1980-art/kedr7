# Генератор 3D-модели советского офицерского полевого планшета сержантского/офицерского состава (ГОСТ 1970-х).
# Кожаный планшет с прозрачным целлулоидным окном, топографической картой, компасом Адрианова,
# петлями для карандашей и наплечным ремнем с латунными пряжками.
# Запуск: blender --background --python officer_tablet.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

LEATHER_DARK = mat("tablet_leather", (0.22, 0.14, 0.08), rough=0.75, wear=0.6, dirt=0.5, wear_col=(0.38, 0.26, 0.16))
LEATHER_LIGHT = mat("tablet_strap", (0.32, 0.20, 0.12), rough=0.8, wear=0.5, dirt=0.4, wear_col=(0.48, 0.32, 0.20))
BRASS = mat("tablet_brass", (0.58, 0.48, 0.22), rough=0.35, wear=0.6, dirt=0.4, wear_col=(0.78, 0.68, 0.38))
MAP_PAPER = mat("tablet_map", (0.84, 0.82, 0.72), rough=0.9, wear=0.3, dirt=0.4, wear_col=(0.92, 0.90, 0.82))
CELLULOID = mat("tablet_window", (0.75, 0.82, 0.80), rough=0.15, wear=0.2, dirt=0.3)
COMPASS_BODY = mat("compass_bakelite", (0.12, 0.12, 0.12), rough=0.4, wear=0.6, dirt=0.4, wear_col=(0.3, 0.3, 0.3))
LUM_DIAL = mat("compass_lum", (0.65, 0.82, 0.55), rough=0.3, wear=0.1, dirt=0.1)
GRAPHITE = mat("pencil_wood", (0.45, 0.12, 0.10), rough=0.7, wear=0.4, dirt=0.3)

# 1. Основное тело планшета (размер в сложенном виде ~22 см ширина, ~28 см высота, толщина ~3.5 см)
# Лежит горизонтально в плоскости XY
box("case_body", (0.22, 0.28, 0.035), (0, 0, 0.018), LEATHER_DARK, 0.008)

# Верхний откидной клапан на кнопках
box("case_flap", (0.224, 0.12, 0.012), (0, 0.085, 0.040), LEATHER_DARK, 0.006)

# Две латунные кнопки-застежки на клапане
cyl("snap_btn1", 0.009, 0.006, (-0.065, 0.035, 0.046), BRASS, verts=10)
cyl("snap_btn2", 0.009, 0.006, (0.065, 0.035, 0.046), BRASS, verts=10)

# 2. Прозрачное целлулоидное окно с топографической картой
box("map_backing", (0.18, 0.16, 0.004), (0, -0.045, 0.036), MAP_PAPER, 0.002)
# Кожаная рамка вокруг окна
box("frame_top", (0.19, 0.012, 0.006), (0, 0.038, 0.038), LEATHER_LIGHT, 0.002)
box("frame_bot", (0.19, 0.012, 0.006), (0, -0.128, 0.038), LEATHER_LIGHT, 0.002)
box("frame_L", (0.012, 0.17, 0.006), (-0.092, -0.045, 0.038), LEATHER_LIGHT, 0.002)
box("frame_R", (0.012, 0.17, 0.006), (0.092, -0.045, 0.038), LEATHER_LIGHT, 0.002)
box("celluloid_sheet", (0.176, 0.156, 0.002), (0, -0.045, 0.041), CELLULOID, 0.001)

# Топографические линии и координатная сетка на карте
for i in range(4):
    box(f"grid_h{i}", (0.16, 0.002, 0.001), (0, -0.11 + i * 0.04, 0.038), LEATHER_DARK, 0.001)
for i in range(4):
    box(f"grid_v{i}", (0.002, 0.14, 0.001), (-0.06 + i * 0.04, -0.045, 0.038), LEATHER_DARK, 0.001)

# 3. Интегрированный компас Адрианова
# Расположен в кожаном кармашке на клапане справа
CP_POS = (0.055, 0.088, 0.047)
cyl("compass_pocket", 0.032, 0.015, CP_POS, LEATHER_LIGHT, verts=12)
cyl("compass_body", 0.026, 0.016, (CP_POS[0], CP_POS[1], CP_POS[2] + 0.006), COMPASS_BODY, verts=16)
cyl("compass_dial", 0.022, 0.002, (CP_POS[0], CP_POS[1], CP_POS[2] + 0.014), LUM_DIAL, verts=16)
# Стрелка компаса (север-юг)
box("compass_needle_N", (0.003, 0.018, 0.002), (CP_POS[0], CP_POS[1] + 0.006, CP_POS[2] + 0.016), mat("needle_red", (0.85, 0.15, 0.10)), 0.001)
box("compass_needle_S", (0.003, 0.018, 0.002), (CP_POS[0], CP_POS[1] - 0.006, CP_POS[2] + 0.016), mat("needle_blue", (0.15, 0.35, 0.70)), 0.001)
cyl("compass_glass", 0.025, 0.002, (CP_POS[0], CP_POS[1], CP_POS[2] + 0.018), CELLULOID, verts=16)

# 4. Петли для карандашей и два карандаша (слева)
cyl("pencil_loop1", 0.008, 0.035, (-0.075, 0.09, 0.046), LEATHER_LIGHT, rot=(0, math.radians(90), 0), verts=8)
cyl("pencil_loop2", 0.008, 0.035, (-0.045, 0.09, 0.046), LEATHER_LIGHT, rot=(0, math.radians(90), 0), verts=8)
# Карандаш графитовый
cyl("pencil1", 0.004, 0.14, (-0.075, 0.085, 0.049), GRAPHITE, rot=(0, 0, math.radians(90)), verts=6)
# Карандаш химический / синий
cyl("pencil2", 0.004, 0.14, (-0.045, 0.085, 0.049), mat("pencil_blue", (0.12, 0.28, 0.55)), rot=(0, 0, math.radians(90)), verts=6)

# 5. Боковые проушины и кожаный ремешок с латунными карабинами
box("eyelet_L", (0.015, 0.024, 0.012), (-0.115, 0.04, 0.02), BRASS, 0.002)
box("eyelet_R", (0.015, 0.024, 0.012), (0.115, 0.04, 0.02), BRASS, 0.002)

tube("strap_tail_L", [
    (-0.115, 0.04, 0.02),
    (-0.14, 0.02, 0.01),
    (-0.16, -0.04, 0.005)
], 0.008, LEATHER_LIGHT, 4)

tube("strap_tail_R", [
    (0.115, 0.04, 0.02),
    (0.14, 0.02, 0.01),
    (0.16, -0.04, 0.005)
], 0.008, LEATHER_LIGHT, 4)

obj, img, tris = kit.finish("officer_tablet", OUT, res=1024, origin="center", samples=32)
kit.export(os.path.join(OUT, "officer_tablet.glb"), os.path.join(OUT, "officer_tablet.blend"))
print("[OK] Officer tablet exported, tris:", tris)
