# Генератор 3D-модели советской фотолаборатории «Ленинград-4».
# Стол фотолаборатории: фотоувеличитель «Ленинград-4» на стойке с кадрирующей рамкой,
# лабораторный фонарь ВЗГ с рубиновым стеклом,
# три эмалированные кюветы (проявитель, стоп-ванна, фиксаж),
# пинцет из нержавейки, реле времени и латунная оптическая лупа.
# Запуск: blender --background --python darkroom_set.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

WOOD_DESK = mat("dk_wood", (0.32, 0.22, 0.14), rough=0.7, wear=0.6, dirt=0.55, wear_col=(0.48, 0.38, 0.28))
ENAMEL_WHITE = mat("dk_enamel", (0.86, 0.88, 0.88), rough=0.3, wear=0.6, dirt=0.4, wear_col=(0.15, 0.16, 0.18))
ENAMEL_BLUE_RIM = mat("dk_blue_rim", (0.14, 0.22, 0.45), rough=0.4, wear=0.5, dirt=0.3)
BLACK_CRACKLE = mat("dk_black", (0.11, 0.11, 0.12), rough=0.55, wear=0.7, dirt=0.4, wear_col=(0.35, 0.35, 0.36))
CHROME_ROD = mat("dk_chrome", (0.75, 0.77, 0.80), rough=0.25, wear=0.5, dirt=0.3)
RUBY_GLASS = mat("dk_ruby", (0.75, 0.08, 0.05), rough=0.15, wear=0.2, dirt=0.2)
BRASS_LOUPE = mat("dk_brass", (0.68, 0.54, 0.24), rough=0.3, wear=0.5, dirt=0.3)
GLASS_LENS = mat("dk_lens", (0.88, 0.94, 0.96), rough=0.08, wear=0.1, dirt=0.1)
FLUID_DEV = mat("dk_fluid_dev", (0.45, 0.38, 0.25), rough=0.15, wear=0.0, dirt=0.1)
FLUID_STOP = mat("dk_fluid_stop", (0.65, 0.70, 0.72), rough=0.15, wear=0.0, dirt=0.1)
FLUID_FIX = mat("dk_fluid_fix", (0.50, 0.52, 0.55), rough=0.15, wear=0.0, dirt=0.1)

# 1. Деревянная столешница рабочего стола (1.20 x 0.65 x 0.04 м)
box("table_top", (1.20, 0.65, 0.04), (0, 0, 0.72), WOOD_DESK, bevel=0.004)
# Ножки стола
for x in (-0.54, 0.54):
    for y in (-0.26, 0.26):
        box(f"table_leg_{x}_{y}", (0.05, 0.05, 0.70), (x, y, 0.35), WOOD_DESK, bevel=0.003)

# 2. Фотоувеличитель «Ленинград-4» (стоит слева: X = -0.32)
# Деревянный экран-основание увеличителя
box("enlarger_base", (0.38, 0.45, 0.024), (-0.32, 0.02, 0.752), WOOD_DESK, bevel=0.003)
# Кадрирующая металлическая рамка с подвижными планками
box("frame_border", (0.24, 0.30, 0.008), (-0.32, 0.02, 0.768), BLACK_CRACKLE, bevel=0.002)
# Белая фотобумага внутри рамки
box("photo_paper", (0.18, 0.24, 0.002), (-0.32, 0.02, 0.772), mat("paper_white", (0.95, 0.94, 0.90)))

# Вертикальная хромированная зубчатая штанга-колонна
cyl("enlarger_column", 0.016, 0.68, (-0.32, 0.20, 1.10), CHROME_ROD, verts=10, bevel=0.003)
# Кронштейн держателя головки
box("enlarger_bracket", (0.06, 0.12, 0.06), (-0.32, 0.14, 1.25), BLACK_CRACKLE, bevel=0.003)
# Осветительный фонарь-кожух (черный эмалированный цилиндр с куполом)
cyl("lamp_housing", 0.075, 0.18, (-0.32, 0.04, 1.35), BLACK_CRACKLE, verts=14, bevel=0.004)
sphere("lamp_cap", 0.074, (-0.32, 0.04, 1.44), BLACK_CRACKLE, scale=(1, 1, 0.4), segs=14, rings=6)
# Раздвижной мех фокусировки (гармошка) под фонарем
cyl("bellows", 0.050, 0.08, (-0.32, 0.04, 1.22), BLACK_CRACKLE, verts=10, r2=0.035)
# Объектив «Индустар-50» с латунным кольцом диафрагмы
cyl("lens_barrel", 0.024, 0.03, (-0.32, 0.04, 1.165), BLACK_CRACKLE, verts=10)
cyl("lens_ring", 0.026, 0.008, (-0.32, 0.04, 1.160), BRASS_LOUPE, verts=10)

# 3. Три эмалированные ванночки (кюветы) справа (X от 0.05 до 0.45)
def make_tray(name, offset_x, offset_y, fluid_mat):
    # Корпус ванночки (длина 0.24, ширина 0.18, высота 0.045)
    box(f"{name}_body", (0.24, 0.18, 0.042), (offset_x, offset_y, 0.761), ENAMEL_WHITE, bevel=0.003)
    # Синий эмалированный закругленный бортик
    box(f"{name}_rim", (0.246, 0.186, 0.008), (offset_x, offset_y, 0.780), ENAMEL_BLUE_RIM, bevel=0.002)
    # Зеркало реактива внутри
    box(f"{name}_fluid", (0.22, 0.16, 0.02), (offset_x, offset_y, 0.755), fluid_mat)

make_tray("tray_dev",  0.08, -0.06, FLUID_DEV)    # Ванночка 1: Проявитель
make_tray("tray_stop", 0.35, -0.06, FLUID_STOP)   # Ванночка 2: Стоп-ванна (вода)
make_tray("tray_fix",  0.22,  0.15, FLUID_FIX)    # Ванночка 3: Фиксаж

# Пинцет из нержавейки лежит на краю ванночки
tube("tweezer", [
    (0.20, -0.15, 0.745),
    (0.22, -0.16, 0.775),
    (0.20, -0.17, 0.782)
], 0.003, CHROME_ROD, 4)

# 4. Лабораторный красный фонарь ВЗГ (висит/стоит сзади справа: X = 0.48, Y = 0.20)
cyl("dark_lamp_base", 0.055, 0.03, (0.48, 0.20, 0.755), BLACK_CRACKLE, verts=10)
cyl("dark_lamp_body", 0.048, 0.12, (0.48, 0.20, 0.83), BLACK_CRACKLE, verts=10, bevel=0.003)
# Рубиновое стекло (светящийся экран фонаря, обращенный вперед -Y)
box("ruby_screen", (0.07, 0.015, 0.09), (0.48, 0.15, 0.84), RUBY_GLASS, bevel=0.002)

# 5. Механическое реле времени (таймер) рядом с увеличителем
box("timer_case", (0.09, 0.07, 0.05), (-0.08, 0.20, 0.765), BLACK_CRACKLE, bevel=0.003)
cyl("timer_dial", 0.028, 0.006, (-0.08, 0.16, 0.765), ENAMEL_WHITE, rot=(math.radians(90), 0, 0), verts=12)
cyl("timer_knob", 0.010, 0.012, (-0.08, 0.15, 0.765), BLACK_CRACKLE, rot=(math.radians(90), 0, 0), verts=8)

# 6. Латунная оптическая лупа (для инспекции снимков)
cyl("loupe_rim", 0.038, 0.008, (-0.05, -0.12, 0.745), BRASS_LOUPE, verts=16, bevel=0.002)
cyl("loupe_glass", 0.035, 0.004, (-0.05, -0.12, 0.745), GLASS_LENS, verts=16)
tube("loupe_handle", [
    (-0.05, -0.155, 0.744),
    (-0.05, -0.235, 0.742)
], 0.006, WOOD_DESK, 6)

body, img, tris = kit.finish("darkroom_set", OUT, res=512, origin="bottom", samples=16, ao_min=0.35)
print(f"[OK] darkroom_set: {tris} tris, texture -> {img.filepath_raw}")
kit.export(os.path.join(OUT, "darkroom_set.glb"), os.path.join(OUT, "darkroom_set.blend"))
