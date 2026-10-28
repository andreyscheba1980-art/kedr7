# Генератор 3D-модели советского аккумуляторного фонаря ФАС-4 для «Кедра-7».
# Прямоугольный корпус молотковой эмали, цилиндрический отражатель с толстым стеклом,
# поворотный тумблер на верхней ручке и кожаный ремень.
# Запуск: blender --background --python fas4_lantern.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

KHAKI = mat("fas_khaki", (0.24, 0.28, 0.20), rough=0.65, wear=0.6, dirt=0.5, wear_col=(0.42, 0.44, 0.40))
BLACK_METAL = mat("fas_black", (0.10, 0.10, 0.11), rough=0.5, wear=0.7, dirt=0.4, wear_col=(0.55, 0.58, 0.60))
STEEL = mat("fas_steel", (0.62, 0.64, 0.66), rough=0.3, wear=0.8, dirt=0.3, wear_col=(0.85, 0.88, 0.90))
BRASS = mat("fas_brass", (0.58, 0.48, 0.22), rough=0.35, wear=0.6, dirt=0.4, wear_col=(0.75, 0.68, 0.35))
GLASS = mat("fas_glass", (0.85, 0.92, 0.95), rough=0.1, wear=0.1, dirt=0.2)
LEATHER = mat("fas_leather", (0.28, 0.18, 0.12), rough=0.8, wear=0.5, dirt=0.6, wear_col=(0.42, 0.30, 0.22))

# 1. Основной аккумуляторный блок (прямоугольный металлический корпус)
# Высота корпуса ~20 см, ширина ~12 см, глубина ~9 см
box("battery_case", (0.12, 0.09, 0.18), (0, 0, 0.09), KHAKI, 0.012)

# Верхняя крышка на петлях и винтовых зажимах
box("case_lid", (0.126, 0.096, 0.024), (0, 0, 0.185), BLACK_METAL, 0.006)
box("lid_rim", (0.128, 0.098, 0.008), (0, 0, 0.174), BLACK_METAL, 0.003)

# 2. Оптическая головка фонаря (цилиндрический фасад с рефлектором)
# Направлена вперед (+Y)
HEAD_Y = 0.045
cyl("head_base", 0.046, 0.035, (0, HEAD_Y + 0.018, 0.11), KHAKI, rot=(math.radians(90), 0, 0), verts=14)
cyl("head_rim", 0.052, 0.015, (0, HEAD_Y + 0.040, 0.11), BRASS, rot=(math.radians(90), 0, 0), verts=14)
# Стекло и глубокий параболический рефлектор
cyl("head_glass", 0.045, 0.004, (0, HEAD_Y + 0.046, 0.11), GLASS, rot=(math.radians(90), 0, 0), verts=14)
sphere("head_bulb", 0.012, (0, HEAD_Y + 0.030, 0.11), STEEL, segs=8, rings=6)

# 3. Рукоятка для переноски (сверху)
tube("handle_bracket", [
    (-0.042, 0, 0.198),
    (-0.042, 0, 0.245),
    (0.042, 0, 0.245),
    (0.042, 0, 0.198)
], 0.009, BLACK_METAL, 8)

# Карболитовый переключатель режимов на рукоятке
cyl("switch_base", 0.012, 0.016, (0, 0, 0.252), BLACK_METAL, verts=8)
box("switch_toggle", (0.006, 0.018, 0.014), (0, 0, 0.264), BRASS, 0.002, rot=(0, math.radians(25), 0))

# 4. Боковые антабки и кожаный наплечный ремень
cyl("strap_loop_L", 0.006, 0.024, (-0.063, 0, 0.15), STEEL, rot=(0, math.radians(90), 0), verts=6)
cyl("strap_loop_R", 0.006, 0.024, (0.063, 0, 0.15), STEEL, rot=(0, math.radians(90), 0), verts=6)

# Ремень свободно свисает по бокам
tube("strap_left", [
    (-0.064, 0, 0.15),
    (-0.082, 0.02, 0.10),
    (-0.085, 0.03, 0.03),
    (-0.065, 0.04, 0.005)
], 0.012, LEATHER, 4)

tube("strap_right", [
    (0.064, 0, 0.15),
    (0.082, -0.02, 0.10),
    (0.085, -0.03, 0.03),
    (0.065, -0.04, 0.005)
], 0.012, LEATHER, 4)

# Заводская латунная табличка на задней стенке
box("nameplate", (0.06, 0.002, 0.035), (0, -0.046, 0.09), BRASS, 0.002)

obj, img, tris = kit.finish("fas4_lantern", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "fas4_lantern.glb"), os.path.join(OUT, "fas4_lantern.blend"))
print("[OK] FAS-4 lantern exported, tris:", tris)
