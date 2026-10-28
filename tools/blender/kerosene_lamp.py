# Генератор 3D-модели классической керосиновой лампы «Летучая мышь» для «Кедра-7».
# Круглое штампованное основание-резервуар с заливной горловиной и барашком фитиля,
# две изогнутые боковые воздуховодные трубки, стекловидная колба с фитилем,
# защитная проволочная решетка, перфорированный тепловой колпак с кольцом и откидная ручка-дужка.
# Запуск: blender --background --python kerosene_lamp.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

TIN_GREEN = mat("lamp_tin", (0.16, 0.22, 0.16), rough=0.55, wear=0.7, dirt=0.5, wear_col=(0.45, 0.45, 0.42))
BURNED_METAL = mat("lamp_burner", (0.22, 0.20, 0.18), rough=0.6, wear=0.8, dirt=0.6, wear_col=(0.55, 0.45, 0.35))
BRASS = mat("lamp_brass", (0.55, 0.45, 0.20), rough=0.35, wear=0.5, dirt=0.3, wear_col=(0.75, 0.65, 0.35))
GLASS = mat("lamp_glass", (0.88, 0.94, 0.96), rough=0.1, wear=0.1, dirt=0.25)
WIRE = mat("lamp_wire", (0.35, 0.36, 0.38), rough=0.4, wear=0.6, dirt=0.3)
WICK = mat("lamp_wick", (0.85, 0.82, 0.75), rough=0.9, wear=0.3, dirt=0.6)

# Габариты: высота без дужки ~30 см, диаметр основания ~14 см

# 1. Резервуар для керосина (нижняя штампованная база)
cyl("fuel_base", 0.070, 0.045, (0, 0, 0.0225), TIN_GREEN, rot=(0, 0, 0), verts=16, bevel=0.004)
# Верхний конусный переход резервуара
cyl("fuel_cone", 0.070, 0.025, (0, 0, 0.055), TIN_GREEN, rot=(0, 0, 0), verts=16, r2=0.048)
# Горловина с завинчивающейся латунной пробкой
cyl("filler_neck", 0.012, 0.014, (0.045, 0.015, 0.055), BRASS, rot=(0, 0, 0), verts=8)
cyl("filler_cap", 0.015, 0.008, (0.045, 0.015, 0.064), BRASS, rot=(0, 0, 0), verts=8)

# 2. Механизм горелки и регулятор фитиля
cyl("burner_cup", 0.038, 0.020, (0, 0, 0.075), BRASS, rot=(0, 0, 0), verts=14)
# Регулятор фитиля (барашек на оси)
cyl("wick_axis", 0.003, 0.055, (0, 0.026, 0.075), WIRE, rot=(math.radians(90), 0, 0), verts=6)
cyl("wick_knob", 0.012, 0.005, (0, 0.052, 0.075), BRASS, rot=(math.radians(90), 0, 0), verts=10)
# Сам хлопковый фитиль внутри горелки
box("wick_cloth", (0.018, 0.004, 0.025), (0, 0, 0.092), WICK, bevel=0.001)

# 3. Боковые трубчатые воздуховоды (силуэт «Летучей мыши»)
for sign, side in [(-1, "L"), (1, "R")]:
    tube(f"air_duct_{side}", [
        (sign * 0.055, 0, 0.055),
        (sign * 0.072, 0, 0.095),
        (sign * 0.072, 0, 0.210),
        (sign * 0.040, 0, 0.250),
        (sign * 0.024, 0, 0.250)
    ], 0.011, TIN_GREEN, 8)

# 4. Стеклянная колба (пузатая грушевидная)
cyl("glass_lower", 0.032, 0.040, (0, 0, 0.105), GLASS, rot=(0, 0, 0), verts=14, r2=0.048)
cyl("glass_mid", 0.048, 0.055, (0, 0, 0.150), GLASS, rot=(0, 0, 0), verts=14, r2=0.035)
cyl("glass_upper", 0.035, 0.045, (0, 0, 0.198), GLASS, rot=(0, 0, 0), verts=14, r2=0.028)

# 5. Защитная проволочная сетка вокруг стекла
for angle in [0, 60, 120, 180, 240, 300]:
    rad = math.radians(angle)
    x = math.cos(rad) * 0.046
    y = math.sin(rad) * 0.046
    tube(f"guard_wire_{angle}", [
        (x * 0.75, y * 0.75, 0.085),
        (x, y, 0.155),
        (x * 0.70, y * 0.70, 0.225)
    ], 0.0022, WIRE, 4)
# Горизонтальные проволочные кольца
torus("guard_ring_1", 0.046, 0.0022, (0, 0, 0.140), WIRE, rot=(0, 0, 0), maj=16, mino=4)
torus("guard_ring_2", 0.044, 0.0022, (0, 0, 0.180), WIRE, rot=(0, 0, 0), maj=16, mino=4)

# 6. Верхний перфорированный тепловой колпак (дефлектор)
cyl("cap_base", 0.032, 0.030, (0, 0, 0.235), BURNED_METAL, rot=(0, 0, 0), verts=14)
cyl("cap_roof", 0.042, 0.018, (0, 0, 0.258), BURNED_METAL, rot=(0, 0, 0), verts=14, r2=0.022)
# Кольцо подъема колпака
torus("top_ring", 0.015, 0.003, (0, 0, 0.278), WIRE, rot=(0, math.radians(90), 0), maj=12, mino=4)

# 7. Проволочная подвижная ручка-дужка для подвешивания и переноски
tube("handle_bail", [
    (-0.068, 0, 0.200),
    (-0.080, 0, 0.240),
    (-0.055, 0, 0.335),
    (0.000, 0, 0.345),
    (0.055, 0, 0.335),
    (0.080, 0, 0.240),
    (0.068, 0, 0.200)
], 0.0035, WIRE, 6)

obj, img, tris = kit.finish("kerosene_lamp", OUT, res=1024, origin="bottom", samples=24)
kit.export(os.path.join(OUT, "kerosene_lamp.glb"), os.path.join(OUT, "kerosene_lamp.blend"))
print(f"[OK] Kerosene Lamp exported: {tris} tris")
