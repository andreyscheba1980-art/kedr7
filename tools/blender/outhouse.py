# Генератор 3D-модели сурового полярного дощатого туалета («сортир») для «Кедра-7».
# Дощатый сруб с односкатной крышей, заметенный снегом у основания,
# дощатая дверь на стальных петлях с деревянным вертушком-засовом и вырезом-сердечком,
# вентиляционная труба из оцинковки, стропильные балки.
# Запуск: blender --background --python outhouse.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

WEATHERED_WOOD = mat("out_wood", (0.35, 0.32, 0.28), rough=0.85, wear=0.7, dirt=0.6, wear_col=(0.55, 0.52, 0.48))
DARK_PLANK = mat("out_plank", (0.28, 0.24, 0.20), rough=0.9, wear=0.6, dirt=0.7, wear_col=(0.45, 0.40, 0.35))
RUSTY_TIN = mat("out_tin", (0.38, 0.35, 0.32), rough=0.6, wear=0.8, dirt=0.7, wear_col=(0.60, 0.42, 0.28))
SNOW = mat("out_snow", (0.90, 0.94, 0.96), rough=0.7, wear=0.1, dirt=0.2)
RUST_IRON = mat("out_iron", (0.18, 0.16, 0.15), rough=0.7, wear=0.8, dirt=0.7, wear_col=(0.52, 0.38, 0.25))

# Габариты: 1.2 м глубина, 1.1 м ширина, высота 2.3 м спереди, 2.0 м сзади (уклон крыши)

# 1. Фундаментные брусья (лежни на мерзлоте)
box("foundation_L", (0.14, 1.30, 0.14), (-0.50, 0, 0.07), DARK_PLANK, bevel=0.01)
box("foundation_R", (0.14, 1.30, 0.14), ( 0.50, 0, 0.07), DARK_PLANK, bevel=0.01)

# 2. Каркасные угловые брусья
box("post_FL", (0.09, 0.09, 2.20), (-0.48, -0.52, 1.20), WEATHERED_WOOD, bevel=0.01)
box("post_FR", (0.09, 0.09, 2.20), ( 0.48, -0.52, 1.20), WEATHERED_WOOD, bevel=0.01)
box("post_RL", (0.09, 0.09, 1.95), (-0.48,  0.52, 1.07), WEATHERED_WOOD, bevel=0.01)
box("post_RR", (0.09, 0.09, 1.95), ( 0.48,  0.52, 1.07), WEATHERED_WOOD, bevel=0.01)

# 3. Обшивка вертикальными досками
# Задняя глухая стена
box("wall_rear", (1.02, 0.03, 1.92), (0, 0.52, 1.07), WEATHERED_WOOD, bevel=0.005)
# Боковые скошенные стены
box("wall_L", (0.03, 1.02, 2.05), (-0.48, 0, 1.14), WEATHERED_WOOD, bevel=0.005)
box("wall_R", (0.03, 1.02, 2.05), ( 0.48, 0, 1.14), WEATHERED_WOOD, bevel=0.005)

# Фасадный косяк двери (перемычка сверху и порог)
box("door_threshold", (0.90, 0.12, 0.08), (0, -0.52, 0.16), DARK_PLANK, bevel=0.008)
box("door_lintel", (0.90, 0.08, 0.18), (0, -0.52, 2.16), WEATHERED_WOOD, bevel=0.008)

# 4. Дощатая дверь (чуть приоткрыта на 8 градусов от ветра)
DOOR_W = 0.82
DOOR_H = 1.90
box("door_leaf", (DOOR_W, 0.04, DOOR_H), (0.02, -0.54, 1.12), DARK_PLANK, bevel=0.006, rot=(0, 0, math.radians(-8)))
# Z-образная поперечная обвязка двери (снаружи)
box("door_z_top", (0.74, 0.025, 0.08), (0.02, -0.565, 1.80), DARK_PLANK, bevel=0.004, rot=(0, 0, math.radians(-8)))
box("door_z_bot", (0.74, 0.025, 0.08), (0.02, -0.565, 0.45), DARK_PLANK, bevel=0.004, rot=(0, 0, math.radians(-8)))
box("door_z_diag", (0.08, 0.025, 1.45), (0.02, -0.565, 1.12), DARK_PLANK, bevel=0.004, rot=(0, math.radians(28), math.radians(-8)))

# Вырез сердечка на двери (ромбовидный прорез света)
box("heart_cutout", (0.09, 0.06, 0.09), (0.02, -0.54, 1.55), RUST_IRON, bevel=0.002, rot=(0, 0, math.radians(45)))

# Кованые амбарные петли
for z in [0.55, 1.70]:
    box(f"hinge_{z}", (0.24, 0.02, 0.04), (-0.28, -0.56, z), RUST_IRON, bevel=0.003, rot=(0, 0, math.radians(-8)))
# Деревянный вертушок-засов и ручка-скоба
box("latch_wood", (0.16, 0.03, 0.04), (0.26, -0.57, 1.05), WEATHERED_WOOD, bevel=0.004, rot=(0, 0, math.radians(15)))
tube("handle_bracket", [(0.32, -0.57, 0.95), (0.35, -0.60, 0.95), (0.35, -0.60, 1.15), (0.32, -0.57, 1.15)], 0.008, RUST_IRON, 4)

# 5. Односкатная крыша с листом ржавого железа и наносом снега
# Скат наклонен назад (-Y к +Y с понижением)
box("roof_sheet", (1.25, 1.45, 0.03), (0, 0.05, 2.22), RUSTY_TIN, bevel=0.005, rot=(math.radians(11), 0, 0))
# Наметенная снежная шапка на крыше
box("roof_snow", (1.20, 1.38, 0.09), (0, 0.03, 2.27), SNOW, bevel=0.03, rot=(math.radians(11), 0, 0))

# 6. Оцинкованная вентиляционная труба, проходящая сквозь крышу
cyl("vent_pipe", 0.055, 0.85, (0.32, 0.38, 2.35), RUSTY_TIN, rot=(0, 0, 0), verts=10)
cyl("vent_cap", 0.090, 0.030, (0.32, 0.38, 2.78), RUSTY_TIN, rot=(0, 0, 0), verts=10, r2=0.02)

# 7. Сугроб заструги у подножия
box("drift_base", (0.65, 0.70, 0.30), (-0.52, 0.30, 0.12), SNOW, bevel=0.08)

obj, img, tris = kit.finish("outhouse", OUT, res=1024, origin="bottom", samples=24)
kit.export(os.path.join(OUT, "outhouse.glb"), os.path.join(OUT, "outhouse.blend"))
print(f"[OK] Polar Outhouse exported: {tris} tris")
