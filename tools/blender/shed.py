# Сарай ГСМ «Кедр-7» в стиле УГМС (снаружи и внутри). Размеры — как Yard._build_shed:
# центр (50, 0, 34), 11.2×6.6, стены 0.24 по осям x 44.4/55.6, z 30.7/37.3, высота стен 3.5,
# ворота на западе (z 32.9..35.1, высота 2.7), перегородка на x 47.4 с проёмом 2.2×2.6.
# Запуск: blender --background --python shed.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, prism, siding, gable_boards, corner, roof_slope, barge, plinth, sign, _rects

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
lin = lambda n, d: ugms.painted(n, (0.30, 0.25, 0.19), under=(0.22, 0.18, 0.14), peel=0.5, scale=5.0, grain=0.05, detail=3, streaks=False, boards=d, step=0.2)
M["lin_z"] = lin("s_lin_z", "x")
M["lin_x"] = lin("s_lin_x", "y")
M["floor"] = lin("s_floor", "x")
M["sheath"] = lin("s_sheath", "x")

CX, CZ = 50.0, 34.0
X0, X1, Z0, Z1 = 44.4, 55.6, 30.7, 37.3
F = 0.12                      # наружная грань от оси стены
WALL_H = 3.5
PITCH = math.tan(math.radians(26.0))
RIDGE = WALL_H + 0.16 + (Z1 - CZ + F) * PITCH


def top(z):
    return RIDGE - abs(z - CZ) * PITCH


def under(z):
    return top(z) - 0.16 / math.cos(math.radians(26.0))


GATE = [32.9, 35.1, 0.0, 2.7]
Y0 = 0.3

# --- Снаружи ---
siding(0, X0 - F, X1 + F, Z1, +1, Y0, WALL_H, [], M, face=F)
siding(0, X0 - F, X1 + F, Z0, -1, Y0, WALL_H, [], M, face=F)
siding(2, Z0 - F, Z1 + F, X1, +1, Y0, WALL_H, [], M, face=F)
siding(2, Z0 - F, Z1 + F, X0, -1, Y0, WALL_H, [GATE], M, face=F)
for x, n in ((X0, -1), (X1, +1)):
    gable_boards(2, CZ, Z1 - CZ + F, x, n, WALL_H, under(CZ) - 0.02, M, face=F)
    box((x + n * (F + 0.04), WALL_H + 0.02, CZ), (0.08, 0.1, Z1 - Z0 + 2 * F + 0.1), M["white"])
    # Продух-жалюзи во фронтоне
    for i in range(4):
        box((x + n * (F + 0.02), 4.0 + i * 0.13, CZ), (0.03, 0.05, 0.6), M["iron"], tilt_z=n * 0.5)
    for dz in (-0.33, 0.33):
        box((x + n * (F + 0.03), 4.2, CZ + dz), (0.04, 0.62, 0.06), M["white"])
for sx, sz in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
    corner(X0 if sx < 0 else X1, Z0 if sz < 0 else Z1, sx, sz, Y0 - 0.05, WALL_H, M, face=F)
for z in (Z0, Z1):
    n = 1 if z == Z1 else -1
    box((CX, WALL_H - 0.08, z + n * (F + 0.02)), (X1 - X0 + 2 * F, 0.16, 0.03), M["white"])
plinth([(X0, Z0), (X1, Z0), (X1, Z1), (X0, Z1)], -0.2, Y0, M, face=F + 0.06)
# Ворота: белый наличник с козырьком
for z in (GATE[0] - 0.06, GATE[1] + 0.06):
    box((X0 - F - 0.02, 1.38, z), (0.04, 2.76, 0.12), M["white"])
box((X0 - F - 0.02, 2.78, CZ), (0.04, 0.14, 2.44), M["white"])
box((X0 - F - 0.25, 3.0, CZ), (0.5, 0.05, 2.7), M["slate"], tilt_z=-0.2)
box((X0 - F - 0.25, 3.06, CZ), (0.48, 0.06, 2.62), M["snow"], tilt_z=-0.2, bevel=0.02)
sign((X0 - F - 0.03, 3.25, CZ), -math.pi / 2, ["СКЛАД ГСМ"], M, w=1.1, h=0.22, size=0.09)
box((X0 - F - 0.03, 1.6, GATE[1] + 0.55), (0.01, 0.4, 0.4), M["red"], yaw=math.pi / 2, tilt_x=math.pi / 4)
sign((X0 - F - 0.03, 1.15, GATE[1] + 0.55), -math.pi / 2, ["ОГНЕОПАСНО"], M, w=0.6, h=0.14, size=0.05)

# Кровля
EO = 0.4
roof_slope(X0 - F - 0.35, X1 + F + 0.35, CZ, Z1 + F + EO, RIDGE, top(Z1 + F + EO), M)
roof_slope(X0 - F - 0.35, X1 + F + 0.35, CZ, Z0 - F - EO, RIDGE, top(Z0 - F - EO), M)
for s in (-1, 1):
    box((CX, RIDGE + 0.02, CZ + s * 0.12), (X1 - X0 + 1.0, 0.03, 0.3), M["slate"], tilt_x=s * 0.45)
box((CX, RIDGE + 0.1, CZ), (X1 - X0 + 0.6, 0.12, 0.32), M["snow"], bevel=0.05)
for x in (X0 - F - 0.33, X1 + F + 0.33):
    barge(x, CZ, RIDGE, Z1 + F + EO, top(Z1 + F + EO), M)
    barge(x, CZ, RIDGE, Z0 - F - EO, top(Z0 - F - EO), M)

# --- Внутри ---
IN = F                       # внутренняя грань — тоже на 0.12 от оси
for axis, c, n, holes, key in ((0, Z0, +1, [], "lin_z"), (0, Z1, -1, [], "lin_z"),
                               (2, X0, +1, [GATE], "lin_x"), (2, X1, -1, [], "lin_x")):
    lo, hi = (X0 + IN, X1 - IN) if axis == 0 else (Z0 + IN, Z1 - IN)
    for r in _rects(lo, hi, 0.0, WALL_H, holes):
        prism(axis, c, n, [(r[0], r[2]), (r[1], r[2]), (r[1], r[3]), (r[0], r[3])], IN, IN + 0.02, M[key])
    for x in ((X0, X1) if axis == 2 else ()):
        pass
# Изнанка фронтонов
for x, n in ((X0, +1), (X1, -1)):
    prism(2, x, n, [(Z0 + IN, WALL_H), (Z1 - IN, WALL_H), (CZ, under(CZ))], IN, IN + 0.02, M["lin_x"])
# Пол
box((CX, 0.005, CZ), (X1 - X0 - 2 * IN, 0.03, Z1 - Z0 - 2 * IN), M["floor"])   # чуть выше земли — иначе снег проступает
# Перегородка мастерская / склад (x 47.4) с проёмом
PX = 47.4
for n in (-1, 1):
    for r in _rects(Z0 + IN, Z1 - IN, 0.0, WALL_H, [[32.9, 35.1, 0.0, 2.6]]):
        prism(2, PX, n, [(r[0], r[2]), (r[1], r[2]), (r[1], r[3]), (r[0], r[3])], 0.09, 0.11, M["lin_x"])
for z in (32.9, 35.1):
    box((PX, 1.3, z), (0.2, 2.6, 0.06), M["wood"])
box((PX, 2.6, CZ), (0.2, 0.06, 2.26), M["wood"])
# Обшивка скатов изнутри и фермы
for side in (-1, 1):
    za = (Z0 + IN) if side < 0 else (Z1 - IN)
    zm = (za + CZ) / 2
    ym = (under(za) + under(CZ)) / 2 - 0.03
    ln = math.hypot(CZ - za, under(CZ) - under(za))
    tilt = math.atan2(under(CZ) - under(za), abs(CZ - za))
    box((CX, ym, zm), (X1 - X0 - 2 * IN, 0.03, ln), M["sheath"], tilt_x=-tilt if side < 0 else tilt)
for i in range(5):
    tx = 44.8 + i * 2.6
    box((tx, WALL_H, CZ), (0.14, 0.14, Z1 - Z0 - 0.2), M["wood"])
    box((tx, WALL_H + 0.8, CZ), (0.12, 1.6, 0.12), M["wood"])
    for side in (-1, 1):
        box((tx, WALL_H + 0.7, CZ + side * 1.6), (0.1, 0.1, 3.4), M["wood"], tilt_x=-side * math.radians(26.0))

obj, img, tris = kit.finish("shed", OUT, res=2048, origin="keep", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "shed.glb"), None)
print(f"[OK] shed: {tris} tris")
