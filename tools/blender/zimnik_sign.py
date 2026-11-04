# Модель массивного дорожного щита-указателя Зимника для «Кедр-7» (1983 год).
# Два бревенчатых столба с укосинами, обрезная дощатая основа, желто-белый эмалированный жестяной щит
# с советским ГОСТ-трафаретом «ЗИМНИК / БОЛЬШАЯ ЗЕМЛЯ / СТ. КЕДР-7», световозвращающая черно-желтая
# сигнальная штриховка внизу, снежная шапка и заносы у комлей.
# Запуск: blender --background --python tools/blender/zimnik_sign.py -- assets/models/kedr
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat, text

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/models/kedr"
os.makedirs(OUT, exist_ok=True)
kit.reset()

WOOD_POST = mat("sign_post", (0.32, 0.26, 0.20), rough=0.9, noise=0.25, wear=0.6, dirt=0.7, wear_col=(0.20, 0.16, 0.12))
WOOD_PLANK = mat("sign_plank", (0.38, 0.32, 0.24), rough=0.85, noise=0.2, wear=0.5, dirt=0.5)
SIGN_PLATE = mat("sign_plate", (0.88, 0.82, 0.65), rough=0.45, noise=0.1, wear=0.7, dirt=0.55, wear_col=(0.18, 0.18, 0.20))
SIGN_BLACK = mat("sign_black", (0.10, 0.10, 0.11), rough=0.75, wear=0.5, dirt=0.3)
SIGN_RED = mat("sign_red", (0.75, 0.15, 0.10), rough=0.65, wear=0.5, dirt=0.3)
IRON_BOLT = mat("sign_iron", (0.16, 0.17, 0.18), rough=0.5, wear=0.8, wear_col=(0.42, 0.24, 0.14))
SNOW = mat("sign_snow", (0.86, 0.90, 0.95), rough=0.9, noise=0.04)

# 1. Два мощных бревенчатых столба (x: -0.85, +0.85, h: 2.5m)
for x in (-0.85, 0.85):
    # Столб квадратный/гранёный 16х16 см
    box(f"post_{x}", (0.16, 0.16, 2.5), (x, 0.0, 1.25), WOOD_POST, 0.01)
    # Скошенный срез столба сверху
    box(f"post_cap_{x}", (0.17, 0.17, 0.06), (x, 0.0, 2.52), WOOD_POST, 0.008, rot=(math.radians(15), 0, 0))
    # Снежная шапочка на столбе
    box(f"post_snow_{x}", (0.19, 0.19, 0.04), (x, 0.0, 2.55), SNOW, 0.01)
    # Сугроб у подножия столба
    sphere(f"snow_base_{x}", 0.32, (x + (0.05 if x > 0 else -0.05), -0.04, 0.15), SNOW, scale=(1.2, 1.1, 0.7), segs=10, rings=6)

# Поперечный связующий брус сзади столбов на высоте 1.35m
box("cross_beam", (2.1, 0.10, 0.12), (0.0, -0.12, 1.35), WOOD_POST, 0.008)
# Диагональная укосина жесткости сзади
box("brace_diag", (1.8, 0.08, 0.08), (0.0, -0.11, 0.85), WOOD_POST, 0.006, rot=(0, math.radians(35), 0))

# 2. Дощатый щит (основа под знак): 5 горизонтальных обрезных досок 2.3м х 0.18м х 0.035м
for i in range(5):
    z = 1.62 + i * 0.175
    box(f"board_{i}", (2.3, 0.035, 0.17), (0.0, 0.09, z), WOOD_PLANK, 0.004)

# Стальные болты и прижимные планки крепления щита к столбам
for x in (-0.85, 0.85):
    for z in (1.65, 2.0, 2.35):
        cyl(f"bolt_{x}_{z}", 0.02, 0.02, (x, 0.115, z), IRON_BOLT, rot=(math.radians(90), 0, 0), verts=8)

# 3. Лист указателя (эмалированная жесть): 2.15м х 0.82м х 0.012м
# Перед предмета в kit смотрит в -Y, в Godot это +Z!
# Значит лицевая часть знака должна смотреть в -Y!
# Развернем лицевые элементы: знак ставим на y = -0.10 (перед столбов)!
# Переставим Y так, чтобы лицевая сторона была на -Y (в игре смотрит на юг/подъезд):
# Столбы стоят на y=0, доски спереди на y=-0.09, жестяной лист на y=-0.115

box("sign_sheet", (2.18, 0.012, 0.80), (0.0, -0.115, 2.02), SIGN_PLATE, 0.006)
# Рамка по периметру жестяного листа (черная окантовка)
box("border_top", (2.16, 0.005, 0.02), (0.0, -0.122, 2.41), SIGN_BLACK)
box("border_bot", (2.16, 0.005, 0.02), (0.0, -0.122, 1.63), SIGN_BLACK)
box("border_left", (0.02, 0.005, 0.78), (-1.08, -0.122, 2.02), SIGN_BLACK)
box("border_right", (0.02, 0.005, 0.78), (1.08, -0.122, 2.02), SIGN_BLACK)

# 4. Трафаретные рельефные надписи на знаке (лицом в -Y, rot=(pi/2, 0, 0))
# Основной заголовок «ЗИМНИК»
text("ЗИМНИК", 0.15, (0.0, -0.124, 2.24), SIGN_BLACK, rot=(math.pi / 2, 0, 0))

# Разделительная черта
box("div_line", (1.8, 0.004, 0.01), (0.0, -0.123, 2.14), SIGN_BLACK)

# Стрелка и километраж: Большая Земля
text("<-- БОЛЬШАЯ ЗЕМЛЯ 140 КМ", 0.082, (0.0, -0.124, 2.01), SIGN_BLACK, rot=(math.pi / 2, 0, 0))

# Стрелка и километраж: ст. Кедр-7
text("СТ. КЕДР-7  0.4 КМ -->", 0.082, (0.0, -0.124, 1.88), SIGN_RED, rot=(math.pi / 2, 0, 0))

# Нижняя полоса предупреждающей наклонной штриховки (черно-желтая зебра)
for s in range(12):
    sx = -0.95 + s * 0.17
    box(f"hatch_{s}", (0.08, 0.004, 0.10), (sx, -0.123, 1.70), SIGN_BLACK, rot=(0, math.radians(25), 0))

# 5. Снежная шапка вдоль всего верхнего края щита
box("snow_ridge", (2.28, 0.12, 0.06), (0.0, 0.0, 2.44), SNOW, 0.015)
box("snow_ridge2", (2.10, 0.08, 0.05), (0.05, -0.06, 2.46), SNOW, 0.02)

obj, img, tris = kit.finish("zimnik_sign", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "zimnik_sign.glb"), os.path.join(OUT, "zimnik_sign.blend"))
print(f"[OK] zimnik_sign: {tris} tris exported to {OUT}")
