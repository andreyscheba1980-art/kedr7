# Станционная уборная (деревянный дощатый туалет) для «Кедр-7» (1983, PS1 low-poly).
# Индивидуальные выветренные вертикальные доски с тёмными щелями, каркасные брусья,
# дощатая дверь на двух кованых петлях с Z-обвязкой, вырезом-ромбом, деревянным вертушком
# и железной ручкой-скобой, односкатная крыша с козырьком, ржавой жестью и снежной шапкой,
# вытяжная труба и заструга-сугроб у основания.
# Оси: origin="bottom", перед (дверь) в -Y Блендера = +Z Godot.
# Запуск:
#   blender --background --factory-startup --python tools/blender/outhouse.py -- assets/models/kedr

import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/kedr"
ONLY = ARGS[1:]
if ONLY and "outhouse" not in ONLY:
    sys.exit(0)
os.makedirs(OUT, exist_ok=True)

kit.reset()
rnd = random.Random(198304)

WOOD_A = mat("out_wood_a", (0.34, 0.30, 0.25), rough=0.88, noise=0.28, wear=0.70, dirt=0.62,
             wear_col=(0.54, 0.50, 0.45))
WOOD_B = mat("out_wood_b", (0.27, 0.23, 0.19), rough=0.92, noise=0.30, wear=0.65, dirt=0.70,
             wear_col=(0.44, 0.40, 0.35))
DARK_GAP = mat("out_gap", (0.02, 0.02, 0.025), rough=0.98)
RUSTY_TIN = mat("out_tin", (0.34, 0.30, 0.27), rough=0.62, noise=0.22, wear=0.82, dirt=0.70,
                wear_col=(0.56, 0.36, 0.22))
RUST_IRON = mat("out_iron", (0.14, 0.13, 0.13), rough=0.65, wear=0.82, dirt=0.65,
                wear_col=(0.48, 0.28, 0.16))
SNOW = mat("out_snow", (0.88, 0.92, 0.96), rough=0.86, noise=0.04)

# Габариты: ширина 1.12 м, глубина 1.18 м, высота спереди 2.28 м, сзади 1.98 м
W, D = 1.12, 1.18
HW, HD = W * 0.5, D * 0.5

# 1. Фундаментные лежни и дощатый порог
for sx in (-0.48, 0.48):
    box(f"skid_{sx}", (0.14, 1.34, 0.13), (sx, 0.0, 0.065), WOOD_B, bevel=0.01)
box("threshold", (0.98, 0.16, 0.08), (0.0, -HD + 0.02, 0.16), WOOD_B, bevel=0.008)

# 2. Тёмная внутренняя камера (чтобы щели между досками и вырез на двери имели реальную глубину!)
box("inner_dark", (W - 0.10, D - 0.10, 1.88), (0.0, 0.02, 1.10), DARK_GAP, bevel=0.0)

# 3. Угловые стойки и обвязочные брусья
box("post_FL", (0.09, 0.09, 2.18), (-HW + 0.05, -HD + 0.05, 1.20), WOOD_B, bevel=0.008)
box("post_FR", (0.09, 0.09, 2.18), ( HW - 0.05, -HD + 0.05, 1.20), WOOD_B, bevel=0.008)
box("post_RL", (0.09, 0.09, 1.92), (-HW + 0.05,  HD - 0.05, 1.08), WOOD_B, bevel=0.008)
box("post_RR", (0.09, 0.09, 1.92), ( HW - 0.05,  HD - 0.05, 1.08), WOOD_B, bevel=0.008)
box("door_lintel", (0.96, 0.09, 0.14), (0.0, -HD + 0.04, 2.18), WOOD_A, bevel=0.006)

# 4. Обшивка стен отдельными вертикальными досками с реальными щелями 8-12 мм
# Задняя стена (+Y): 7 вертикальных досок
for i in range(7):
    px = -0.465 + i * 0.155
    thick = 0.026 + rnd.uniform(-0.003, 0.003)
    h_p = 1.92 + rnd.uniform(-0.015, 0.015)
    box(f"rear_plank_{i}", (0.143, thick, h_p), (px, HD + rnd.uniform(-0.003, 0.003), 0.12 + h_p * 0.5),
        WOOD_A if i % 2 == 0 else WOOD_B, bevel=0.004)

# Боковые стены (-X и +X): по 7 досок, обрезанных по наклону односкатной крыши
for sx in (-1, 1):
    for i in range(7):
        py = -0.49 + i * 0.162
        # Высота понижается от переда (-Y, 2.24 м) к заду (+Y, 1.94 м)
        t = (py + HD) / D
        top_z = 2.24 * (1.0 - t) + 1.94 * t
        h_p = top_z - 0.12
        thick = 0.026 + rnd.uniform(-0.003, 0.003)
        box(f"side_{sx}_{i}", (thick, 0.148, h_p),
            (sx * (HW + rnd.uniform(-0.003, 0.003)), py, 0.12 + h_p * 0.5),
            WOOD_A if (i + (1 if sx > 0 else 0)) % 2 == 0 else WOOD_B, bevel=0.004)
    # Наружная горизонтальная стяжка на боковой стене
    box(f"side_belt_{sx}", (0.032, D + 0.02, 0.075), (sx * (HW + 0.018), 0.0, 1.05), WOOD_B, bevel=0.004)

# Передние узкие простенки по краям дверного проёма
for sx in (-1, 1):
    box(f"front_jamb_{sx}", (0.13, 0.035, 2.12), (sx * (HW - 0.065), -HD - 0.006, 1.18), WOOD_A, bevel=0.004)

# 5. Дощатая дверь (5 отдельных вертикальных досок + Z-обвязка + петли + ручка-скоба + вертушок)
# Чуть приоткрыта от ветра (-6° вокруг левой петли на x=-0.43, y=-HD)
DOOR_ANG = math.radians(-6.0)
PIV_X, PIV_Y = -0.43, -HD - 0.01


def _door_pt(lx, ly, lz):
    ca, sa = math.cos(DOOR_ANG), math.sin(DOOR_ANG)
    return (PIV_X + lx * ca - ly * sa, PIV_Y + lx * sa + ly * ca, lz)


# 5 отдельных досок полотна двери (ширина двери 0.84 м, высота 1.92 м)
for i in range(5):
    lx = 0.088 + i * 0.166
    box(f"door_p_{i}", (0.156, 0.032, 1.90), _door_pt(lx, -0.012, 1.15),
        WOOD_B if i % 2 == 0 else WOOD_A, bevel=0.004, rot=(0, 0, DOOR_ANG))

# Z-образная силовая обвязка двери снаружи
box("door_z_top", (0.76, 0.026, 0.085), _door_pt(0.42, -0.038, 1.84), WOOD_B, bevel=0.004, rot=(0, 0, DOOR_ANG))
box("door_z_bot", (0.76, 0.026, 0.085), _door_pt(0.42, -0.038, 0.48), WOOD_B, bevel=0.004, rot=(0, 0, DOOR_ANG))
box("door_z_diag", (0.082, 0.024, 1.46), _door_pt(0.42, -0.036, 1.16), WOOD_B, bevel=0.004,
    rot=(0, math.radians(26), DOOR_ANG))

# Тёмный ромбовидный прорез вентиляции в верхней части двери с накладной рамкой
box("vent_cutout", (0.095, 0.045, 0.095), _door_pt(0.42, -0.016, 1.58), DARK_GAP, bevel=0.0,
    rot=(0, math.radians(45), DOOR_ANG))
box("vent_trim", (0.115, 0.014, 0.115), _door_pt(0.42, -0.032, 1.58), WOOD_A, bevel=0.002,
    rot=(0, math.radians(45), DOOR_ANG))

# Кованые амбарные петли (2 шт.: шарнир на косяке + длинная стальная полоса с болтами)
for hz in (0.52, 1.76):
    cyl(f"hinge_knuckle_{hz}", 0.018, 0.085, (PIV_X, PIV_Y - 0.026, hz), RUST_IRON, rot=(0, 0, 0), verts=8)
    box(f"hinge_strap_{hz}", (0.30, 0.014, 0.044), _door_pt(0.16, -0.034, hz), RUST_IRON, bevel=0.003,
        rot=(0, 0, DOOR_ANG))
    for bx in (0.06, 0.16, 0.26):
        cyl(f"hinge_bolt_{hz}_{bx}", 0.009, 0.010, _door_pt(bx, -0.044, hz), RUST_IRON,
            rot=(math.pi * 0.5, 0, DOOR_ANG), verts=6)

# Железная дверная ручка-скоба (справа на двери) и деревянный вертушок на косяке
tube("door_handle", [
    _door_pt(0.73, -0.032, 1.00),
    _door_pt(0.73, -0.078, 1.02),
    _door_pt(0.73, -0.078, 1.18),
    _door_pt(0.73, -0.032, 1.20),
], 0.009, RUST_IRON, verts=6)
for hz in (1.00, 1.20):
    box(f"handle_pad_{hz}", (0.042, 0.010, 0.042), _door_pt(0.73, -0.032, hz), RUST_IRON, bevel=0.002,
        rot=(0, 0, DOOR_ANG))

# Деревянный вертушок-засов на правом косяке
box("wood_latch", (0.15, 0.028, 0.042), (HW - 0.09, -HD - 0.035, 1.10), WOOD_A, bevel=0.004,
    rot=(0, math.radians(18), 0))
cyl("latch_bolt", 0.009, 0.024, (HW - 0.05, -HD - 0.042, 1.10), RUST_IRON, rot=(math.pi * 0.5, 0, 0), verts=6)

# 6. Односкатная крыша с козырьком спереди, стропилами, листами жести и снежной шапкой
ROOF_TILT = math.radians(11.5)
# Три стропильные балки под свесом
for rx in (-0.48, 0.0, 0.48):
    box(f"rafter_{rx}", (0.06, 1.66, 0.075), (rx, -0.06, 2.20), WOOD_B, bevel=0.005, rot=(ROOF_TILT, 0, 0))
# Дощатый настил-обрешётка (козырёк выдаётся вперёд на 0.30 м над дверью)
box("roof_deck", (1.34, 1.68, 0.032), (0.0, -0.06, 2.255), WOOD_A, bevel=0.004, rot=(ROOF_TILT, 0, 0))
# Два листа ржавого кровельного железа со стыковым фальцем
for sx in (-0.33, 0.33):
    box(f"roof_tin_{sx}", (0.66, 1.72, 0.018), (sx, -0.06, 2.282), RUSTY_TIN, bevel=0.003, rot=(ROOF_TILT, 0, 0))
box("roof_seam", (0.026, 1.72, 0.028), (0.0, -0.06, 2.292), RUSTY_TIN, bevel=0.002, rot=(ROOF_TILT, 0, 0))

# Толстая снежная шапка на крыше с нависающим карнизом
box("roof_snow", (1.30, 1.60, 0.11), (0.0, -0.04, 2.345), SNOW, bevel=0.036, rot=(ROOF_TILT, 0, 0))
sphere("roof_snow_lump", 0.34, (-0.32, 0.36, 2.26), SNOW, scale=(1.2, 1.1, 0.32), segs=8, rings=4)

# 7. Оцинкованная вентиляционная труба с дефлектором
cyl("vent_pipe", 0.056, 0.88, (0.34, 0.38, 2.38), RUSTY_TIN, rot=(0, 0, 0), verts=10)
cyl("vent_collar", 0.088, 0.03, (0.34, 0.38, 2.18), RUST_IRON, rot=(ROOF_TILT, 0, 0), verts=10)
cyl("vent_cap", 0.105, 0.042, (0.34, 0.38, 2.83), RUSTY_TIN, rot=(0, 0, 0), verts=10, r2=0.015)

# 8. Сугроб заструги у наветренной боковой стены
sphere("drift_base", 0.45, (-0.64, 0.15, 0.20), SNOW, scale=(0.68, 1.35, 0.56), segs=10, rings=6)

body, img, tris = kit.finish("outhouse", OUT, res=1024, origin="bottom", samples=26, ao_min=0.35)
kit.export(os.path.join(OUT, "outhouse.glb"), os.path.join(OUT, "outhouse.blend"))
print(f"[OK] outhouse exported: {tris} tris")
