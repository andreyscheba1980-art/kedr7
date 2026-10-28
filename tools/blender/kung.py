# Вагончик-КУНГ на полозьях (вахтовка лесосеки, вышки, зимника): заводская окраска, рёбра жёсткости,
# окна с решётками, дверь в торце (−X) с откидной лесенкой, труба буржуйки, снег на крыше, ржавчина.
# Габарит как у Props.kung_trailer: полозья 5.6 по X, кузов 5.0×2.5, высота ~2.8. Ставится через _kedr_model.
# Запуск: blender --background --python kung.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, cone

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
P = ugms.painted
M["body"] = P("k_body", (0.48, 0.26, 0.12), under=(0.30, 0.18, 0.11), peel=0.22, scale=3.5, grain=0.12)
M["frame"] = kit.mat("k_frame", (0.16, 0.16, 0.17), rough=0.6, wear=0.7, wear_col=(0.40, 0.24, 0.13), dirt=0.6)
M["roof"] = kit.mat("k_roof", (0.30, 0.30, 0.30), rough=0.7, wear=0.6, wear_col=(0.42, 0.26, 0.15))

L, W, H0, H = 5.0, 2.5, 0.42, 2.45
# Полозья с загнутыми носами и поперечины
for sz in (-1.0, 1.0):
    box((0, 0.1, sz * 1.0), (5.2, 0.16, 0.2), M["frame"])
    for sx in (-1, 1):
        box((sx * 2.75, 0.24, sz * 1.0), (0.5, 0.14, 0.2), M["frame"], tilt_z=-sx * 0.6)
for x in (-2.0, -0.7, 0.7, 2.0):
    box((x, 0.28, 0), (0.14, 0.14, 2.3), M["frame"])
# Кузов
box((0, H0 + H / 2, 0), (L, H, W), M["body"])
# Рёбра жёсткости и уголки
for x in (-2.48, -1.25, 0.0, 1.25, 2.48):
    for sz in (-1, 1):
        box((x, H0 + H / 2, sz * (W / 2 + 0.02)), (0.07, H, 0.04), M["body"])
for y in (H0 + 0.04, H0 + H - 0.04):
    for sz in (-1, 1):
        box((0, y, sz * (W / 2 + 0.03)), (L + 0.04, 0.07, 0.05), M["frame"])
# Окна с решётками на обеих длинных сторонах
for sz in (-1, 1):
    for x in (-0.6, 1.5):
        box((x, H0 + 1.35, sz * (W / 2 + 0.01)), (0.8, 0.6, 0.02), M["glass"])
        box((x, H0 + 1.35, sz * (W / 2 + 0.025)), (0.9, 0.7, 0.01), M["white"])
        box((x, H0 + 1.35, sz * (W / 2 + 0.03)), (0.76, 0.56, 0.012), M["glass"])
        for k in range(4):
            box((x - 0.3 + k * 0.2, H0 + 1.35, sz * (W / 2 + 0.05)), (0.025, 0.62, 0.025), M["frame"])
# Дверь в торце −X и лесенка
box((-L / 2 - 0.02, H0 + 1.0, 0.35), (0.04, 1.9, 0.85), M["body"])
box((-L / 2 - 0.05, H0 + 1.0, 0.68), (0.03, 0.16, 0.05), M["frame"])
box((-L / 2 - 0.03, H0 + 1.0, 0.35), (0.02, 2.0, 0.95), M["frame"])
for i in range(3):
    box((-L / 2 - 0.25 - i * 0.12, H0 - 0.12 - i * 0.14, 0.35), (0.22, 0.03, 0.7), M["frame"])
for dz in (0.0, 0.7):
    box((-L / 2 - 0.36, H0 - 0.25, dz), (0.04, 0.5, 0.04), M["frame"], tilt_z=0.4)
# Крыша: скруглённая кромка, снег, труба буржуйки
box((0, H0 + H + 0.05, 0), (L + 0.1, 0.1, W + 0.1), M["roof"], bevel=0.04)
box((0.2, H0 + H + 0.16, 0), (L - 0.2, 0.14, W - 0.15), M["snow"], bevel=0.06)
cyl((1.6, H0 + H + 0.55, -0.6), 0.07, 1.0, M["frame"], verts=10)
cyl((1.6, H0 + H + 1.08, -0.6), 0.14, 0.05, M["frame"], verts=10, r2=0.03)
for x in (-2.2, -1.0, 0.2, 1.4):
    L2 = 0.15 + 0.2 * abs(math.sin(x * 3.1))
    cone((x, H0 + H - 0.02, W / 2 + 0.06), (x, H0 + H - 0.02 - L2, W / 2 + 0.06), 0.035, M["snow"], verts=5)
# Ящик АКБ и баллон под днищем
box((0.9, H0 - 0.15, 0.6), (0.6, 0.28, 0.4), M["frame"])
cyl((-1.2, H0 - 0.15, -0.5), 0.15, 0.9, M["red"], verts=10, axis="x")

obj, img, tris = kit.finish("kung", OUT, res=1024, origin="bottom", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "kung.glb"), None)
print(f"[OK] kung: {tris} tris")
