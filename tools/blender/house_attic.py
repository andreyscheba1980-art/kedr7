# Чердак дома «Кедр-7» изнутри: пол из доски с люком, коленные стенки, стропила и обшивка скатов,
# ригели со стойками, кирпичный ствол трубы, изнанка фронтонов (на западном — жалюзи слухового окна), хлам.
# Габарит — внутри зоны чердака Station.is_pos_inside_house (y ≥ 2.8, x −2.6..14.6, z 0..6.6).
# Запуск: blender --background --python house_attic.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, prism, cyl, _rects

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

p = lambda *a, **k: ugms.painted(*a, grain=0.05, detail=3, streaks=False, **k)
M = {
    "floor": p("a_floor", (0.40, 0.33, 0.25), under=(0.32, 0.27, 0.21), peel=0.4, scale=6.0, boards="x", step=0.16),
    "wall_z": p("a_wall", (0.36, 0.30, 0.23), under=(0.28, 0.23, 0.18), peel=0.5, scale=5.0, boards="x", step=0.18),
    "wall_x": p("a_wallx", (0.36, 0.30, 0.23), under=(0.28, 0.23, 0.18), peel=0.5, scale=5.0, boards="y", step=0.18),
    "sheath": p("a_sheath", (0.32, 0.27, 0.21), under=(0.26, 0.22, 0.17), peel=0.5, scale=5.0, boards="x", step=0.2),
    "beam": kit.mat("a_beam", (0.30, 0.23, 0.16), rough=0.9, noise=0.25, noise_scale=20, wear=0.4, dirt=0.3),
    "brick": kit.mat("a_brick", (0.46, 0.20, 0.13), rough=0.9, noise=0.35, noise_scale=10, wear=0.5, dirt=0.5, wear_col=(0.62, 0.58, 0.52)),
    "dark": kit.mat("a_dark", (0.03, 0.03, 0.035), rough=0.9),
    "felt": kit.mat("a_felt", (0.10, 0.10, 0.09), rough=0.8, noise=0.2, noise_scale=12),
    "zinc": kit.mat("a_zinc", (0.42, 0.44, 0.45), rough=0.5, wear=0.6, wear_col=(0.3, 0.27, 0.22)),
    "paper": kit.mat("a_paper", (0.62, 0.58, 0.48), rough=0.9, noise=0.2, noise_scale=30),
    "frame": ugms.painted("a_frame", (0.70, 0.70, 0.65), peel=0.3, scale=8.0, grain=0.05, detail=3, streaks=False),
    "glass": kit.mat("a_glass", (0.10, 0.12, 0.13), rough=0.2),
}

RIDGE, PITCH, T = 5.5, math.tan(math.radians(28.0)), 0.16
FY = 2.97          # верх настила


def under(z):
    return RIDGE - abs(z - 3.3) * PITCH - T / math.cos(math.radians(28.0))


ZN, ZS = 1.95, 4.65              # грани коленных стенок (блоки 0.2 на z 1.85 и 4.75)
KN_TOP = 4.3
X0, X1 = -2.5, 14.5

# Пол с проёмом люка (центр 6.0, 4.2; 1.1×1.1)
for r in _rects(X0, X1, ZN - 0.1, ZS + 0.1, [[5.45, 6.55, 3.65, 4.75]]):
    box(((r[0] + r[1]) / 2, FY - 0.02, (r[2] + r[3]) / 2), (r[1] - r[0], 0.04, r[3] - r[2]), M["floor"])

# Коленные стенки: доска вертикально
for z, n in ((ZN - 0.1, +1), (ZS + 0.1, -1)):
    # стенка доходит до обшивки ската — без щели на изнанку кровли
    prism(0, z, n, [(X0, FY), (X1, FY), (X1, under(z) + 0.03), (X0, under(z) + 0.03)], 0.08, 0.1, M["wall_z"])
    box((6.0, KN_TOP + 0.03, z + n * 0.1), (X1 - X0, 0.06, 0.14), M["beam"])    # мауэрлат

# Обшивка скатов изнутри и стропила
for side in (-1, 1):
    za = ZN if side < 0 else ZS
    zm = (za + 3.3) / 2
    ym = (under(za) + under(3.3)) / 2 - 0.04
    ln = math.hypot(3.3 - za, under(3.3) - under(za))
    tilt = math.atan2(under(3.3) - under(za), abs(3.3 - za))
    tilt = -tilt if side < 0 else tilt
    box((6.0, ym, zm), (X1 - X0, 0.03, ln), M["sheath"], tilt_x=tilt)
    x = X0 + 0.45
    while x < X1:
        box((x, ym - 0.09, zm), (0.08, 0.16, ln), M["beam"], tilt_x=tilt)
        x += 0.9
# Ригели и стойки (как в station.gd)
for bx in (0.6, 3.2, 8.8, 12.2):
    box((bx, 4.15, 3.3), (0.12, 0.12, 2.6), M["beam"])
    box((bx, 3.56, 3.3), (0.12, 1.18, 0.12), M["beam"])
box((6.0, under(3.3) - 0.12, 3.3), (X1 - X0, 0.14, 0.14), M["beam"])     # коньковый прогон

# Изнанка фронтонов
for x, n in ((X0, +1), (X1, -1)):
    pts = [(ZN - 0.1, FY), (ZS + 0.1, FY), (ZS + 0.1, under(ZS + 0.1)), (3.3, under(3.3)), (ZN - 0.1, under(ZN - 0.1))]
    if x == X0:
        # Слуховое окно: проём в доске, рама, жалюзи — сквозь щели виден свет
        win = [2.93, 3.67, 3.43, 4.17]
        for r in _rects(ZN - 0.1, ZS + 0.1, FY, under(3.3), [win]):
            sub = [(r[0], r[2]), (r[1], r[2]), (r[1], min(r[3], under(r[1]))), (r[0], min(r[3], under(r[0])))]
            prism(2, x, n, sub, 0.0, 0.02, M["wall_x"])
        for dz in (-0.39, 0.39):
            box((x + 0.03, 3.8, 3.3 + dz), (0.04, 0.82, 0.06), M["frame"])
        for y in (3.41, 4.19):
            box((x + 0.03, y, 3.3), (0.04, 0.06, 0.84), M["frame"])
    else:
        prism(2, x, n, pts, 0.0, 0.02, M["wall_x"])

# Кирпичный ствол трубы (центр −1.5, 1.0; 0.65×0.65) — над коленной стенкой виден верх
box((-1.5, 3.85, 1.0), (0.64, 1.8, 0.64), M["brick"])
for i in range(9):
    box((-1.5, 3.0 + i * 0.2, 1.0), (0.66, 0.015, 0.66), M["paper"])      # швы раствора

# Хлам: рулоны рубероида, старая рама, ведро, кипа газет, валенок
for i, (x, z) in enumerate(((10.4, 2.4), (10.8, 2.35), (10.6, 2.65))):
    cyl((x, FY + 0.12 + (0.2 if i == 2 else 0), z), 0.11, 0.9, M["felt"], verts=10, axis="z")
box((13.6, 3.55, 2.2), (0.06, 1.1, 0.8), M["frame"], tilt_z=-0.25)
box((13.62, 3.55, 2.2), (0.02, 0.9, 0.6), M["glass"], tilt_z=-0.25)
cyl((9.3, FY + 0.15, 4.3), 0.15, 0.3, M["zinc"], verts=12, r2=0.12)
for i in range(5):
    box((3.9 + (i % 2) * 0.02, FY + 0.03 + i * 0.03, 2.4), (0.42, 0.03, 0.3), M["paper"], yaw=i * 0.15)

obj, img, tris = kit.finish("house_int_attic", OUT, res=2048, origin="keep", samples=32, pack=0.003, ao_blur=3, ao_min=0.4)
kit.export(os.path.join(OUT, "house_int_attic.glb"), None)
print(f"[OK] house_int_attic: {tris} tris")
