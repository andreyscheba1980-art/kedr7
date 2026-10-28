# Генератор 3D-модели советского эмалированного чайника со свистком и гранёного стакана в подстаканнике.
# Пузатый корпус из листовой стали с серо-голубой эмалью и сколами,
# изогнутый носик со свистком на цепочке, бакелитовая верхняя ручка-дуга,
# крышка с круглой ручкой-пуговицей; рядом — гранёный стакан с чаем в мельхиоровом подстаканнике.
# Запуск: blender --background --python soviet_kettle.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

ENAMEL_BLUE = mat("ket_enamel", (0.35, 0.44, 0.52), rough=0.35, wear=0.7, dirt=0.4, wear_col=(0.12, 0.12, 0.14))
BAKELITE = mat("ket_bakelite", (0.08, 0.08, 0.09), rough=0.45, wear=0.5, dirt=0.3, wear_col=(0.28, 0.26, 0.24))
CHROME_STEEL = mat("ket_chrome", (0.75, 0.77, 0.80), rough=0.25, wear=0.6, dirt=0.3, wear_col=(0.88, 0.90, 0.92))
BRASS = mat("ket_brass", (0.60, 0.50, 0.22), rough=0.35, wear=0.5, dirt=0.4, wear_col=(0.78, 0.70, 0.35))
NICKEL_HOLDER = mat("ket_holder", (0.58, 0.60, 0.62), rough=0.3, wear=0.6, dirt=0.5, wear_col=(0.82, 0.84, 0.85))
GLASS = mat("ket_glass", (0.85, 0.92, 0.94), rough=0.1, wear=0.1, dirt=0.2)
TEA_LIQUID = mat("ket_tea", (0.42, 0.18, 0.05), rough=0.2, wear=0.0, dirt=0.1)

# Габариты композиции: Чайник (диаметр ~20 см, высота ~22 см) + Стакан рядом
# Центр чайника в (0, 0, 0.10), стакан смещен вбок (+X = 0.18)

# 1. Корпус чайника (пузатый эмалированный сосуд)
# Нижнее дно
cyl("kettle_bottom", 0.095, 0.020, (0, 0, 0.010), ENAMEL_BLUE, rot=(0, 0, 0), verts=16, bevel=0.005)
# Расширяющаяся нижняя часть
cyl("kettle_belly", 0.095, 0.075, (0, 0, 0.055), ENAMEL_BLUE, rot=(0, 0, 0), verts=16, r2=0.115)
# Сужающаяся верхняя часть к горловине
cyl("kettle_shoulder", 0.115, 0.065, (0, 0, 0.125), ENAMEL_BLUE, rot=(0, 0, 0), verts=16, r2=0.070)
# Горловина с черным эмалированным бортиком
cyl("kettle_rim", 0.072, 0.012, (0, 0, 0.160), BAKELITE, rot=(0, 0, 0), verts=16, bevel=0.002)

# 2. Крышка чайника
cyl("lid_base", 0.068, 0.015, (0, 0, 0.165), ENAMEL_BLUE, rot=(0, 0, 0), verts=14, bevel=0.003)
sphere("lid_dome", 0.055, (0, 0, 0.165), ENAMEL_BLUE, scale=(1, 1, 0.35), segs=14, rings=8)
# Бакелитовая пуговица-ручка на крышке
cyl("lid_knob", 0.014, 0.018, (0, 0, 0.192), BAKELITE, rot=(0, 0, 0), verts=10, bevel=0.003)

# 3. Изогнутый носик со свистком
# Носик направлен вперед (-Y)
tube("spout", [
    (0, -0.095, 0.070),
    (0, -0.145, 0.120),
    (0, -0.165, 0.165)
], 0.018, ENAMEL_BLUE, 8)

# Свисток на кончике носика
cyl("whistle_cap", 0.022, 0.025, (0, -0.170, 0.172), CHROME_STEEL, rot=(math.radians(45), 0, 0), verts=10, bevel=0.002)
# Откидной колпачок с отверстием
cyl("whistle_tip", 0.015, 0.008, (0, -0.180, 0.182), BAKELITE, rot=(math.radians(45), 0, 0), verts=8)

# 4. Бакелитовая ручка над чайником
# Стальные боковые стойки-кронштейны
tube("handle_bracket_L", [(-0.065, 0, 0.155), (-0.065, 0, 0.205)], 0.005, CHROME_STEEL, 6)
tube("handle_bracket_R", [( 0.065, 0, 0.155), ( 0.065, 0, 0.205)], 0.005, CHROME_STEEL, 6)
# Дугообразная перекладина ручки из черного бакелита с выемками под пальцы
tube("handle_grip", [
    (-0.065, 0, 0.205),
    (-0.045, 0, 0.235),
    ( 0.000, 0, 0.245),
    ( 0.045, 0, 0.235),
    ( 0.065, 0, 0.205)
], 0.013, BAKELITE, 8)

# 5. Гранёный стакан с чаем в советском подстаканнике (сбоку)
GX = 0.185
GY = -0.040

# Подстаканник: массивное круглое основание с юбкой
cyl("podstak_base", 0.042, 0.010, (GX, GY, 0.005), NICKEL_HOLDER, rot=(0, 0, 0), verts=14, bevel=0.002)
# Ажурная стенка подстаканника
cyl("podstak_wall", 0.038, 0.060, (GX, GY, 0.038), NICKEL_HOLDER, rot=(0, 0, 0), verts=14, bevel=0.002)
# Фигурная ручка подстаканника (справа)
tube("podstak_handle", [
    (GX + 0.038, GY, 0.020),
    (GX + 0.065, GY, 0.035),
    (GX + 0.065, GY, 0.055),
    (GX + 0.038, GY, 0.062)
], 0.004, NICKEL_HOLDER, 6)

# Сам гранёный стакан (стекло с легкой конусностью и 14 гранями)
cyl("glass_body", 0.035, 0.095, (GX, GY, 0.052), GLASS, rot=(0, 0, 0), verts=14, r2=0.031)
# Утолщенный гладкий ободок стакана сверху
cyl("glass_lip", 0.036, 0.012, (GX, GY, 0.096), GLASS, rot=(0, 0, 0), verts=14, bevel=0.002)
# Крепкий черный чай внутри стакана
cyl("tea_inside", 0.031, 0.068, (GX, GY, 0.046), TEA_LIQUID, rot=(0, 0, 0), verts=12, r2=0.028)

# Чайная ложечка из нержавеющей стали, торчащая из стакана
tube("spoon_stem", [
    (GX - 0.015, GY, 0.025),
    (GX + 0.018, GY, 0.075),
    (GX + 0.032, GY, 0.115)
], 0.002, CHROME_STEEL, 4)
sphere("spoon_bowl", 0.008, (GX - 0.015, GY, 0.025), CHROME_STEEL, scale=(1, 0.6, 1.4), segs=6, rings=4)

obj, img, tris = kit.finish("soviet_kettle", OUT, res=1024, origin="bottom", samples=24)
kit.export(os.path.join(OUT, "soviet_kettle.glb"), os.path.join(OUT, "soviet_kettle.blend"))
print(f"[OK] Soviet Kettle exported: {tris} tris")
