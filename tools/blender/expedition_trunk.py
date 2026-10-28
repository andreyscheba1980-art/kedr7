# Генератор 3D-модели советского экспедиционного металлического сундука / чемодана дежурного.
# Дюралевый штампованный корпус с ребрами жесткости, стальными уголками, защелками-лягушками,
# откидными ручками по бокам и трафаретными надписями.
# Запуск: blender --background --python expedition_trunk.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

DURAL = mat("trunk_metal", (0.36, 0.40, 0.38), rough=0.55, wear=0.75, dirt=0.55, wear_col=(0.65, 0.68, 0.70))
STEEL_DARK = mat("trunk_corners", (0.16, 0.17, 0.18), rough=0.45, wear=0.8, dirt=0.5, wear_col=(0.50, 0.52, 0.55))
LATCH_COL = mat("trunk_latches", (0.55, 0.56, 0.58), rough=0.35, wear=0.7, dirt=0.35, wear_col=(0.80, 0.82, 0.85))
SEAL_RED = mat("trunk_seal", (0.65, 0.15, 0.12), rough=0.5, wear=0.4, dirt=0.3)
STENCIL_WHITE = mat("trunk_stencil", (0.85, 0.86, 0.88), rough=0.9, wear=0.4, dirt=0.5)

# 1. Основной короб рундука (длина 70 см, глубина 42 см, высота 34 см)
box("trunk_body", (0.70, 0.42, 0.26), (0, 0, 0.13), DURAL, 0.015)

# Откидная верхняя крышка с фальцем
box("trunk_lid", (0.708, 0.428, 0.09), (0, 0, 0.305), DURAL, 0.012)
box("lid_seam", (0.712, 0.432, 0.012), (0, 0, 0.26), STEEL_DARK, 0.004)

# 2. Штампованные ребра жесткости (по 3 продольных валика на боковинах и крышке)
for i in [-0.22, 0.0, 0.22]:
    # На передней и задней стенках
    box(f"rib_front_{i}", (0.018, 0.012, 0.22), (i, 0.216, 0.13), DURAL, 0.006)
    box(f"rib_back_{i}", (0.018, 0.012, 0.22), (i, -0.216, 0.13), DURAL, 0.006)
    # На верхней крышке
    box(f"rib_top_{i}", (0.018, 0.38, 0.012), (i, 0, 0.355), DURAL, 0.006)

# 3. Усиленные защитные стальные уголки с заклепками (все 8 углов)
for sx in [-0.352, 0.352]:
    for sy in [-0.212, 0.212]:
        for sz in [0.03, 0.33]:
            box(f"corner_{sx}_{sy}_{sz}", (0.045, 0.045, 0.045), (sx, sy, sz), STEEL_DARK, 0.006)

# 4. Защелки-лягушки (3 штуки на фасаде)
for lx in [-0.22, 0.0, 0.22]:
    box(f"latch_base_{lx}", (0.032, 0.012, 0.06), (lx, 0.218, 0.26), LATCH_COL, 0.003)
    box(f"latch_lever_{lx}", (0.026, 0.016, 0.04), (lx, 0.224, 0.25), LATCH_COL, 0.002)
    # Пломбировочная проволока с красной свинцовой пломбой на центральном замке
    if lx == 0.0:
        box("wire_seal", (0.012, 0.018, 0.012), (0, 0.228, 0.23), SEAL_RED, 0.003)

# 5. Две мощные откидные боковые ручки для переноски
for hx, rot_y in [(-0.355, math.radians(90)), (0.355, math.radians(-90))]:
    box(f"handle_mount_{hx}", (0.012, 0.08, 0.05), (hx, 0, 0.18), STEEL_DARK, 0.004)
    tube(f"handle_grip_{hx}", [
        (hx, -0.05, 0.16),
        (hx * 1.08, -0.05, 0.13),
        (hx * 1.08, 0.05, 0.13),
        (hx, 0.05, 0.16)
    ], 0.009, STEEL_DARK, 6)

# 6. Трафаретная надпись на передней стенке рундука
box("stencil_plate", (0.28, 0.002, 0.06), (0, 0.217, 0.11), STENCIL_WHITE, 0.002)
box("stencil_line2", (0.16, 0.002, 0.025), (0, 0.217, 0.05), STENCIL_WHITE, 0.002)

obj, img, tris = kit.finish("expedition_trunk", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "expedition_trunk.glb"), os.path.join(OUT, "expedition_trunk.blend"))
print("[OK] Expedition trunk exported, tris:", tris)
