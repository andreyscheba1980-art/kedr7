# Генератор 3D-модели вывороченного леерного столба для игры «Кедр-7».
# Деревянный кол с обтесанным верхом, вырванный из мерзлоты (глыба льда и камней у комля),
# фарфоровый изолятор, обрывок стального витого троса и белая сигнальная лента.
# Запуск: blender --background --python broken_post.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

WOOD = mat("post_wood", (0.34, 0.25, 0.16), rough=0.85, wear=0.7, dirt=0.75, wear_col=(0.50, 0.40, 0.28))
FROZEN_EARTH = mat("frozen_earth", (0.18, 0.14, 0.11), rough=0.9, wear=0.2, dirt=0.9, wear_col=(0.3, 0.25, 0.2))
PORCELAIN = mat("porcelain", (0.86, 0.88, 0.89), rough=0.25, wear=0.3, dirt=0.4, wear_col=(0.95, 0.95, 0.95))
WIRE = mat("steel_wire", (0.22, 0.23, 0.24), rough=0.4, wear=0.8, dirt=0.4, wear_col=(0.6, 0.62, 0.65))
RIBBON = mat("signal_cloth", (0.78, 0.76, 0.72), rough=0.9, wear=0.4, dirt=0.5)
SNOW = mat("snow_ice", (0.88, 0.92, 0.96), rough=0.95, wear=0.0, dirt=0.0)

# Деревянный столб: повален под углом ~45 градусов
H_POST = 1.7
cyl("post_trunk", 0.065, H_POST, (0.35, 0.0, 0.55), WOOD, rot=(0, math.radians(48.0), math.radians(15.0)), verts=10)

# Ком мерзлой земли и льда на вывороченном комле
box("root_clod", (0.42, 0.38, 0.32), (-0.18, -0.05, 0.12), FROZEN_EARTH, 0.06, rot=(0.1, -0.2, 0.3))
sphere("ice_chunk1", 0.16, (-0.24, 0.08, 0.10), SNOW, segs=8, rings=6)
sphere("ice_chunk2", 0.12, (-0.10, -0.16, 0.08), SNOW, segs=6, rings=5)

# Фарфоровый изолятор у верхушки столба (с "юбками")
ins_pos = (0.75, 0.08, 0.98)
cyl("insulator_body", 0.038, 0.14, ins_pos, PORCELAIN, rot=(0, math.radians(48.0), 0), verts=12)
cyl("insulator_skirt1", 0.055, 0.025, (0.73, 0.08, 0.95), PORCELAIN, rot=(0, math.radians(48.0), 0), verts=12)
cyl("insulator_skirt2", 0.050, 0.025, (0.77, 0.08, 1.01), PORCELAIN, rot=(0, math.radians(48.0), 0), verts=12)

# Стальная проволочная скоба крепления изолятора к столбу
tube("ins_bracket", [
    (0.70, 0.02, 0.92),
    (0.72, 0.14, 0.94),
    (0.78, 0.14, 1.02),
    (0.76, 0.02, 1.00)
], 0.007, WIRE, 6)

# Оборванный стальной трос леера: один конец уходит в сугроб, второй свисает раскрученными жилами
tube("cable_to_ground", [
    (0.74, 0.08, 0.98),
    (0.55, 0.25, 0.65),
    (0.35, 0.45, 0.28),
    (0.15, 0.60, 0.02)
], 0.008, WIRE, 6)

# Раскрученный и закрученный обрывок стального троса в воздухе
tube("cable_snapped_end", [
    (0.74, 0.08, 0.98),
    (0.92, 0.12, 1.15),
    (1.08, -0.05, 1.22),
    (1.22, -0.12, 1.10)
], 0.007, WIRE, 6)

# Растрёпанные жилы троса на конце
tube("cable_strand1", [(1.22, -0.12, 1.10), (1.30, -0.18, 1.16)], 0.003, WIRE, 4)
tube("cable_strand2", [(1.22, -0.12, 1.10), (1.28, -0.08, 1.04)], 0.003, WIRE, 4)

# Полотняная белая сигнальная лента, привязанная к верхушке и треплющаяся по ветру (-Y / +X)
tube("signal_ribbon", [
    (0.80, 0.04, 1.06),
    (0.95, -0.14, 1.02),
    (1.15, -0.28, 0.96),
    (1.35, -0.38, 0.88),
    (1.50, -0.42, 0.78)
], 0.018, RIBBON, 4)

# Снежная шапка на вывороченном комле
box("snow_on_post", (0.55, 0.10, 0.06), (0.42, 0.02, 0.65), SNOW, 0.02, rot=(0, math.radians(48.0), 0))

obj, img, tris = kit.finish("broken_post", OUT, res=1024, origin="center", samples=32)
kit.export(os.path.join(OUT, "broken_post.glb"), os.path.join(OUT, "broken_post.blend"))
print("[OK] Broken post exported, tris:", tris)
