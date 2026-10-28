# Генератор 3D-модели советской 20-литровой стальной армейской канистры для «Кедра-7».
# Характерная прямоугольная штампованная форма, выштамповки жесткости в виде буквы «X» на боковинах,
# тройная трубчатая ручка для переноски (в одиночку за среднюю или вдвоем по бокам),
# горловина с откидной рычажной крышкой и шплинтом.
# Запуск: blender --background --python fuel_canister.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

CAN_KHAKI = mat("can_khaki", (0.22, 0.25, 0.16), rough=0.6, wear=0.75, dirt=0.7, wear_col=(0.55, 0.52, 0.45))
RAW_STEEL = mat("can_steel", (0.35, 0.36, 0.37), rough=0.45, wear=0.8, dirt=0.5, wear_col=(0.75, 0.77, 0.80))
RUST_SEAM = mat("can_rust", (0.28, 0.18, 0.12), rough=0.85, wear=0.6, dirt=0.8)
RED_LABEL = mat("can_red", (0.65, 0.12, 0.08), rough=0.7, wear=0.8, dirt=0.6)

# Габариты стандартной 20-литровой канистры: Высота 47 см, Ширина 34.5 см, Толщина 16.5 см
# X = толщина (0.165), Y = ширина (0.345), Z = высота (0.47)

# 1. Основной штампованный корпус из двух сваренных половин
box("can_body", (0.165, 0.345, 0.420), (0, 0, 0.210), CAN_KHAKI, bevel=0.022)

# Продольный сварной шов (бортик толщиной 8 мм по периметру стыка)
box("weld_seam_bottom", (0.174, 0.354, 0.015), (0, 0, 0.010), RUST_SEAM, bevel=0.003)
box("weld_seam_sides", (0.174, 0.354, 0.410), (0, 0, 0.215), RUST_SEAM, bevel=0.004)

# 2. Характерные выштамповки «X» жесткости на обеих широких боковых стенках
for side, x in [("L", -0.084), ("R", 0.084)]:
    # Две диагональные полосы
    box(f"x_rib_1_{side}", (0.008, 0.260, 0.024), (x, 0, 0.210), CAN_KHAKI, bevel=0.003, rot=(0, math.radians(48), 0))
    box(f"x_rib_2_{side}", (0.008, 0.260, 0.024), (x, 0, 0.210), CAN_KHAKI, bevel=0.003, rot=(0, math.radians(-48), 0))
    # Центральный ромб усиления
    box(f"x_center_{side}", (0.009, 0.065, 0.065), (x, 0, 0.210), CAN_KHAKI, bevel=0.004, rot=(0, math.radians(45), 0))

# Трафаретная надпись «20 Л» или «БЕНЗИН»
box("stencil_plate", (0.003, 0.12, 0.045), (0.085, 0, 0.340), RED_LABEL, bevel=0.002)

# 3. Верхняя ручка: знаменитая тройная трубчатая система
# Средняя ручка (для одного человека)
tube("handle_mid", [
    (0, -0.110, 0.420),
    (0, -0.110, 0.468),
    (0,  0.110, 0.468),
    (0,  0.110, 0.420)
], 0.011, CAN_KHAKI, 6)

# Две боковые ручки (для передачи вдвоем или переноски по две канистры)
for side, x in [("L", -0.046), ("R", 0.046)]:
    tube(f"handle_{side}", [
        (x, -0.085, 0.420),
        (x, -0.085, 0.468),
        (x,  0.085, 0.468),
        (x,  0.085, 0.420)
    ], 0.010, CAN_KHAKI, 6)

# 4. Заливная горловина со скошенным носиком и рычажной крышкой
# Находится в передней части верха (-Y)
cyl("spout_neck", 0.026, 0.045, (0, -0.115, 0.435), RAW_STEEL, rot=(0, 0, 0), verts=10)
# Рычажная крышка с эксцентриковым затвором
box("spout_cap", (0.042, 0.055, 0.022), (0, -0.115, 0.460), RAW_STEEL, bevel=0.004)
# Рычаг защелки
tube("spout_lever", [
    (0, -0.100, 0.465),
    (0, -0.060, 0.472),
    (0, -0.045, 0.450)
], 0.004, RAW_STEEL, 4)

obj, img, tris = kit.finish("fuel_canister", OUT, res=1024, origin="bottom", samples=24)
kit.export(os.path.join(OUT, "fuel_canister.glb"), os.path.join(OUT, "fuel_canister.blend"))
print(f"[OK] Fuel Canister exported: {tris} tris")
