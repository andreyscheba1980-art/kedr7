# Генератор 3D-моделей охотничьих лыж «Тайга» и снегомерной рейки М-103.
# Запуск: blender --background --python skis_survey.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)

# ==========================================
# МОДЕЛЬ 1: Охотничьи лыжи «Тайга» с палкой
# ==========================================
kit.reset()

SKI_WOOD = mat("ski_wood", (0.42, 0.28, 0.16), rough=0.55, wear=0.7, dirt=0.45, wear_col=(0.60, 0.44, 0.28))
SKI_BASE = mat("ski_base", (0.22, 0.16, 0.10), rough=0.4, wear=0.5, dirt=0.5, wear_col=(0.35, 0.26, 0.18))
CANVAS_STRAP = mat("ski_strap", (0.45, 0.42, 0.35), rough=0.8, wear=0.6, dirt=0.6, wear_col=(0.32, 0.30, 0.25))
RUBBER_PAD = mat("ski_rubber", (0.12, 0.12, 0.13), rough=0.7, wear=0.4, dirt=0.4)
BAMBOO_POLE = mat("ski_pole", (0.65, 0.58, 0.38), rough=0.5, wear=0.6, dirt=0.4)
LEATHER = mat("ski_leather", (0.28, 0.18, 0.12), rough=0.6, wear=0.5, dirt=0.5)

def make_ski(offset_x):
    # Полотно лыжи (ширина 0.14 м, толщина 0.016 м, длина 1.6 м)
    # Пятка и средняя часть
    box(f"ski_body_{offset_x}", (0.14, 1.40, 0.016), (offset_x, -0.05, 0.008), SKI_WOOD, bevel=0.003)
    # Загнутый носок лыжи (плавный подъем)
    tube(f"ski_tip_{offset_x}", [
        (offset_x, 0.65, 0.008),
        (offset_x, 0.78, 0.045),
        (offset_x, 0.85, 0.110),
        (offset_x, 0.87, 0.145)
    ], 0.012, SKI_WOOD, 6)
    
    # Резиновая рифленая накладка под валенок по центру
    box(f"foot_pad_{offset_x}", (0.12, 0.32, 0.008), (offset_x, 0.0, 0.020), RUBBER_PAD, bevel=0.002)
    
    # Брезентово-кожаный носковый ремень-петля
    tube(f"strap_toe_{offset_x}", [
        (offset_x - 0.065, 0.08, 0.016),
        (offset_x - 0.055, 0.08, 0.085),
        (offset_x + 0.055, 0.08, 0.085),
        (offset_x + 0.065, 0.08, 0.016)
    ], 0.008, CANVAS_STRAP, 6)
    
    # Пяточный регулируемый ремень
    tube(f"strap_heel_{offset_x}", [
        (offset_x - 0.06, 0.06, 0.03),
        (offset_x - 0.05, -0.12, 0.05),
        (offset_x + 0.05, -0.12, 0.05),
        (offset_x + 0.06, 0.06, 0.03)
    ], 0.006, LEATHER, 6)

# Две лыжи рядом (левая и правая)
make_ski(-0.11)
make_ski(0.11)

# Бамбуковая лыжная палка с широким кольцом (стоит рядом справа)
cyl("pole_shaft", 0.012, 1.35, (0.26, 0.0, 0.675), BAMBOO_POLE, verts=8, bevel=0.002)
# Кожаный темляк (петля на ручке)
tube("pole_strap", [
    (0.26, 0.0, 1.33),
    (0.28, 0.04, 1.25),
    (0.26, 0.06, 1.20)
], 0.004, LEATHER, 6)
# Опорное кольцо (лапка) внизу (диаметр 16 см, чтобы не проваливаться в пухлый снег)
tube("pole_ring", [
    (0.26 + 0.07 * math.cos(a), 0.07 * math.sin(a), 0.14) for a in [i * math.pi / 4 for i in range(9)]
], 0.005, LEATHER, 6)
# Крестовина из сыромятной кожи в кольце
box("ring_cross1", (0.13, 0.012, 0.004), (0.26, 0.0, 0.14), LEATHER)
box("ring_cross2", (0.012, 0.13, 0.004), (0.26, 0.0, 0.14), LEATHER)
# Металлический штычок-наконечник
cyl("pole_tip", 0.005, 0.12, (0.26, 0.0, 0.06), SKI_BASE, verts=6)

body, img, tris = kit.finish("taiga_skis", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
print(f"[OK] taiga_skis: {tris} tris, texture -> {img.filepath_raw}")
kit.export(os.path.join(OUT, "taiga_skis.glb"), os.path.join(OUT, "taiga_skis.blend"))

# ==========================================
# МОДЕЛЬ 2: Снегомерная рейка М-103
# ==========================================
kit.reset()

STAKE_WOOD = mat("stake_wood", (0.85, 0.83, 0.78), rough=0.6, wear=0.7, dirt=0.45, wear_col=(0.42, 0.35, 0.25))
STAKE_BLACK = mat("stake_black", (0.12, 0.12, 0.14), rough=0.65, wear=0.6, dirt=0.4)
CYLINDER_METAL = mat("stake_metal", (0.62, 0.64, 0.66), rough=0.35, wear=0.5, dirt=0.35)
SNOW_MOUND = mat("stake_snow", (0.93, 0.95, 0.97), rough=0.85, wear=0.0, dirt=0.05)

# Рейка М-103 (деревянный брус 0.06 x 0.03 x 1.80 м)
box("stake_main", (0.06, 0.03, 1.80), (0, 0, 0.90), STAKE_WOOD, bevel=0.002)

# Шахматная черно-белая сантиметровая разметка (накладные полосы делений)
for i in range(12):
    z_pos = 0.20 + float(i) * 0.12
    box(f"mark_band_{i}", (0.062, 0.032, 0.055), (0, 0, z_pos), STAKE_BLACK)

# Затесанный козырек от налипания снега
cyl("stake_top", 0.03, 0.05, (0, 0, 1.825), STAKE_WOOD, verts=8, r2=0.01)

# Снеговой холмик у основания
sphere("base_snow", 0.35, (0, 0, 0.08), SNOW_MOUND, scale=(1.2, 1.1, 0.35), segs=12, rings=8)

# Рядом на снегу стоит снегоотборник ВС-43 (металлическая градуированная труба с ручкой)
cyl("sampler_tube", 0.045, 0.75, (0.22, 0.08, 0.375), CYLINDER_METAL, verts=12, bevel=0.003)
# Зубчатая режущая кромка внизу
cyl("sampler_teeth", 0.047, 0.04, (0.22, 0.08, 0.03), STAKE_BLACK, verts=12)
# Т-образная ручка сверху
cyl("sampler_handle_stem", 0.012, 0.08, (0.22, 0.08, 0.77), CYLINDER_METAL, verts=8)
box("sampler_handle_bar", (0.20, 0.024, 0.024), (0.22, 0.08, 0.81), STAKE_WOOD, bevel=0.003)

body, img, tris = kit.finish("snow_stake", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
print(f"[OK] snow_stake: {tris} tris, texture -> {img.filepath_raw}")
kit.export(os.path.join(OUT, "snow_stake.glb"), os.path.join(OUT, "snow_stake.blend"))
