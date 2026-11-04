# Генератор 3D-моделей советской паяльной лампы и обледеневшего амбарного замка.
# Запуск: blender --background --python blowtorch.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)

# ==========================================
# МОДЕЛЬ 1: Советская бензиновая паяльная лампа
# ==========================================
kit.reset()

BRASS = mat("bt_brass", (0.58, 0.48, 0.22), rough=0.35, wear=0.6, dirt=0.45, wear_col=(0.75, 0.65, 0.35))
STEEL_BURN = mat("bt_steel", (0.28, 0.28, 0.30), rough=0.55, wear=0.7, dirt=0.5, wear_col=(0.42, 0.35, 0.28))
BAKELITE = mat("bt_handle", (0.09, 0.09, 0.10), rough=0.6, wear=0.5, dirt=0.35)
COPPER_COIL = mat("bt_copper", (0.62, 0.35, 0.20), rough=0.4, wear=0.5, dirt=0.4)

# Цилиндрический резервуар для бензина (диаметр 11 см, высота 14 см)
cyl("tank_body", 0.055, 0.14, (0, 0, 0.07), BRASS, verts=14, bevel=0.005)
# Верхний куполообразный свод бачка
sphere("tank_dome", 0.054, (0, 0, 0.14), BRASS, scale=(1, 1, 0.3), segs=14, rings=6)
# Заливная горловина с латунной резьбовой пробкой
cyl("filler_neck", 0.016, 0.02, (0.025, -0.025, 0.155), BRASS, verts=10)
cyl("filler_cap", 0.020, 0.012, (0.025, -0.025, 0.165), BRASS, verts=10, bevel=0.002)

# Насос подкачки давления воздуха (наклонный шток с грибком)
cyl("pump_tube", 0.012, 0.12, (-0.03, 0.02, 0.17), BRASS, rot=(math.radians(20), math.radians(-15), 0), verts=8)
cyl("pump_knob", 0.022, 0.012, (-0.05, 0.04, 0.23), BAKELITE, rot=(math.radians(20), math.radians(-15), 0), verts=10)

# Бакелитовая удобная рукоятка сзади (+Y)
tube("handle_frame", [
    (0, 0.055, 0.03),
    (0, 0.115, 0.04),
    (0, 0.115, 0.13),
    (0, 0.055, 0.14)
], 0.011, BAKELITE, 6)

# Эжекторная горелка-сопло (направлена вперед, -Y)
# Стойка подачи топлива из бачка
cyl("burner_stem", 0.010, 0.06, (0, -0.02, 0.16), BRASS, verts=8)
# Предпусковая чаша для спирта/бензина (для предварительного разогрева)
cyl("preheat_cup", 0.035, 0.022, (0, -0.06, 0.18), STEEL_BURN, verts=10, bevel=0.003)
# Сопло горелки (конус-сопло, откуда вырывается пламя)
cyl("burner_nozzle", 0.024, 0.09, (0, -0.09, 0.20), STEEL_BURN, rot=(math.radians(-90), 0, 0), verts=12, bevel=0.003)
cyl("burner_flange", 0.028, 0.015, (0, -0.135, 0.20), STEEL_BURN, rot=(math.radians(-90), 0, 0), verts=12)
# Латунный регулировочный маховичок (вентиль) подачи бензина
cyl("valve_stem", 0.006, 0.04, (0, 0.01, 0.20), BRASS, rot=(math.radians(-90), 0, 0), verts=6)
cyl("valve_wheel", 0.022, 0.010, (0, 0.035, 0.20), BAKELITE, rot=(math.radians(-90), 0, 0), verts=8)

body, img, tris = kit.finish("blowtorch", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
print(f"[OK] blowtorch: {tris} tris, texture -> {img.filepath_raw}")
kit.export(os.path.join(OUT, "blowtorch.glb"), os.path.join(OUT, "blowtorch.blend"))

# ==========================================
# МОДЕЛЬ 2: Обледеневший амбарный замок
# ==========================================
kit.reset()

CAST_IRON = mat("pad_iron", (0.24, 0.25, 0.27), rough=0.65, wear=0.7, dirt=0.55, wear_col=(0.48, 0.40, 0.32))
SHACKLE_STEEL = mat("pad_shackle", (0.45, 0.47, 0.50), rough=0.45, wear=0.6, dirt=0.4)
FROST_ICE = mat("pad_frost", (0.88, 0.92, 0.96), rough=0.25, wear=0.0, dirt=0.1)

# Массивный каплевидный корпус замка
box("lock_body", (0.09, 0.035, 0.11), (0, 0, 0.055), CAST_IRON, bevel=0.005)
# Скважина для ключа со шторкой
box("keyhole_plate", (0.025, 0.037, 0.035), (0, 0, 0.035), CAST_IRON)
box("keyhole_slit", (0.006, 0.038, 0.020), (0, 0, 0.035), mat("slit", (0.05, 0.05, 0.05)))

# Стальная дужка (U-образная)
tube("shackle", [
    (-0.030, 0, 0.10),
    (-0.030, 0, 0.16),
    (-0.015, 0, 0.18),
    ( 0.015, 0, 0.18),
    ( 0.030, 0, 0.16),
    ( 0.030, 0, 0.10)
], 0.012, SHACKLE_STEEL, 8)

# Наросшая корка льда и игольчатый куржак на верхушке и дужке
sphere("frost_crust1", 0.045, (0.01, 0.005, 0.17), FROST_ICE, scale=(1.2, 0.8, 0.6), segs=10, rings=6)
sphere("frost_crust2", 0.035, (-0.025, -0.005, 0.14), FROST_ICE, scale=(0.9, 0.9, 0.7), segs=8, rings=6)
box("frost_side", (0.094, 0.02, 0.06), (0.01, -0.01, 0.07), FROST_ICE, bevel=0.003)

body, img, tris = kit.finish("frozen_padlock", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
print(f"[OK] frozen_padlock: {tris} tris, texture -> {img.filepath_raw}")
kit.export(os.path.join(OUT, "frozen_padlock.glb"), os.path.join(OUT, "frozen_padlock.blend"))
