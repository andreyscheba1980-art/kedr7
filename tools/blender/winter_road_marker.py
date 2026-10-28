# Генератор 3D-модели советской дорожной вешки зимника с катафотами для «Кедра-7».
# Деревянный граненый столб со скошенным верхом, черно-белыми полосами,
# двумя гранеными стеклянными световозвращателями (катафотами) и сугробом у комля.
# Запуск: blender --background --python winter_road_marker.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

WOOD_WHITE = mat("marker_white", (0.82, 0.84, 0.86), rough=0.75, wear=0.6, dirt=0.5, wear_col=(0.42, 0.35, 0.28))
WOOD_BLACK = mat("marker_black", (0.12, 0.12, 0.14), rough=0.8, wear=0.7, dirt=0.4, wear_col=(0.38, 0.30, 0.24))
REFLECTOR_AMBER = mat("cat_eye_amber", (0.92, 0.58, 0.10), rough=0.15, wear=0.2, dirt=0.3, wear_col=(1.0, 0.85, 0.4))
REFLECTOR_RED = mat("cat_eye_red", (0.85, 0.15, 0.12), rough=0.15, wear=0.2, dirt=0.3, wear_col=(1.0, 0.4, 0.3))
BRACKET_METAL = mat("bracket_iron", (0.22, 0.24, 0.26), rough=0.45, wear=0.7, dirt=0.4)
SNOW = mat("marker_snow", (0.88, 0.92, 0.96), rough=0.95, wear=0.0, dirt=0.0)

# Высота вешки ~2.1 м, сечение 10х10 см
H = 2.1
W = 0.10

# Чередующиеся черно-белые пояса (по 30 см каждый)
stripes = 7
step = H / stripes
for i in range(stripes):
    col = WOOD_BLACK if (i % 2 == 1) else WOOD_WHITE
    box(f"stripe_{i}", (W, W, step), (0, 0, step * 0.5 + i * step), col, 0.006)

# Скошенная под 45 градусов верхушка столба
box("slanted_cap", (W * 0.95, W * 0.95, 0.08), (0, 0, H + 0.03), WOOD_WHITE, 0.005, rot=(math.radians(25), 0, 0))
# Снежная шапочка на срезе
box("cap_snow", (W * 1.1, W * 1.1, 0.04), (0, 0, H + 0.06), SNOW, 0.008)

# Катафоты (световозвращатели):
# Верхний — оранжевый/янтарный (смотрит вперед по ходу движения +Y)
cyl("reflector_top_mount", 0.042, 0.012, (0, W * 0.5 + 0.008, 1.85), BRACKET_METAL, rot=(math.radians(90), 0, 0), verts=12)
cyl("reflector_top_glass", 0.036, 0.008, (0, W * 0.5 + 0.014, 1.85), REFLECTOR_AMBER, rot=(math.radians(90), 0, 0), verts=12)

# Нижний — красный (смотрит назад -Y)
cyl("reflector_bot_mount", 0.042, 0.012, (0, -W * 0.5 - 0.008, 1.55), BRACKET_METAL, rot=(math.radians(-90), 0, 0), verts=12)
cyl("reflector_bot_glass", 0.036, 0.008, (0, -W * 0.5 - 0.014, 1.55), REFLECTOR_RED, rot=(math.radians(-90), 0, 0), verts=12)

# Сугроб у подножия вешки
sphere("snow_base1", 0.28, (0.08, -0.06, 0.12), SNOW, segs=8, rings=6)
sphere("snow_base2", 0.22, (-0.12, 0.08, 0.08), SNOW, segs=8, rings=5)

obj, img, tris = kit.finish("winter_road_marker", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "winter_road_marker.glb"), os.path.join(OUT, "winter_road_marker.blend"))
print("[OK] Winter road marker exported, tris:", tris)
