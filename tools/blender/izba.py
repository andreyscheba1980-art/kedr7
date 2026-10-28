# Изба Семёнова (заброшенная) — «старое и чужое» (docs/СТИЛЬ_ПОСТРОЕК.md): некрашеный тёмный сруб из
# брёвен с выпусками на углах, мох и лишайник понизу, тёсовая кровля со снегом, прируб-сени с односкатной
# крышей, наличник с облезлой резьбой. Внутри — те же брёвна, дощатый потолок с матицей, пол.
# Размеры — как Yard._build_izba: IZBA = (−16, 0, −30); сруб 6.3×6.0×2.8 (центр x −16.65), сени 3.2×3.4×2.4
# (центр x −12.2), проём сруб→сени z −30.6..−29.4, вход в сени с востока там же, окно на юг x −17.2..−16.1.
# Запуск: blender --background --python izba.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, prism, _rects, roof_slope, barge

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
P = ugms.painted
M["log"] = P("z_log", (0.22, 0.19, 0.16), under=(0.20, 0.23, 0.15), peel=0.18, scale=2.2, grain=0.2, detail=8)
M["log_end"] = kit.mat("z_logend", (0.40, 0.32, 0.22), rough=0.9, noise=0.3, noise_scale=40, wear=0.3, dirt=0.6)
M["tes"] = P("z_tes", (0.20, 0.17, 0.14), under=(0.24, 0.27, 0.18), peel=0.3, scale=3.0, grain=0.15, boards="x", step=0.22)
M["gable_y"] = P("z_gab", (0.21, 0.18, 0.15), under=(0.24, 0.26, 0.18), peel=0.3, scale=3.0, grain=0.15, boards="y", step=0.2)
M["board_x"] = P("z_bx", (0.27, 0.22, 0.17), under=(0.22, 0.18, 0.14), peel=0.4, scale=4.0, grain=0.08, detail=4, streaks=False, boards="x", step=0.2)
M["trim_old"] = P("z_trim", (0.48, 0.47, 0.42), under=(0.22, 0.19, 0.16), peel=0.55, scale=5.0, grain=0.1)

R = 0.13          # радиус бревна
STEP = 0.235      # шаг рядов
CX, CZ = -16.65, -30.0
W, D, H = 6.3, 6.0, 2.8
SX, SW, SD, SH = -12.2, 3.2, 3.4, 2.4


def log_wall(axis, u0, u1, c, y0, y1, holes, over=0.25, ends=(True, True)):
    """Стена из брёвен вдоль оси (axis 0 — вдоль X на z=c, 2 — вдоль Z на x=c), с выпусками по углам."""
    y = y0 + R
    row = 0
    while y < y1:
        a, b = u0 - (over if ends[0] else 0), u1 + (over if ends[1] else 0)
        for r in _rects(a, b, y - R, y + R, holes):
            if r[3] - r[2] < 2 * R - 0.01:
                continue
            L = r[1] - r[0]
            if L < 0.05:
                continue
            um = (r[0] + r[1]) / 2
            rr = R * (0.94 + 0.06 * math.sin(row * 2.1 + um))
            if axis == 0:
                cyl((um, y, c), rr, L, M["log"], verts=8, axis="x")
                for e in (r[0], r[1]):
                    cyl((e, y, c), rr * 0.9, 0.02, M["log_end"], verts=8, axis="x")
            else:
                cyl((c, y, um), rr, L, M["log"], verts=8, axis="z")
                for e in (r[0], r[1]):
                    cyl((c, y, e), rr * 0.9, 0.02, M["log_end"], verts=8, axis="z")
        y += STEP
        row += 1


# --- Сруб: стены по осям (снаружи брёвна от линии наружу и внутрь по R) ---
x0, x1, z0, z1 = CX - W / 2, CX + W / 2, CZ - D / 2, CZ + D / 2
WIN = [-17.2, -16.1, 1.0, 2.0]
PASS = [-30.6, -29.4, 0.0, 2.0]
log_wall(0, x0, x1, z0, 0.0, H, [])
log_wall(0, x0, x1, z1, 0.0, H, [WIN])
log_wall(2, z0, z1, x0, 0.0 + STEP / 2, H, [])
log_wall(2, z0, z1, x1, 0.0 + STEP / 2, H, [PASS])
# Фронтоны: тёс вертикально
RIDGE = H + (D / 2 + 0.3) * math.tan(math.radians(28)) + 0.1


def top(z):
    return RIDGE - abs(z - CZ) * math.tan(math.radians(28))


for x, n in ((x0, -1), (x1, +1)):
    prism(2, x, n, [(z0 - 0.1, H), (z1 + 0.1, H), (CZ, top(CZ) - 0.2)], 0.0, 0.05, M["gable_y"])
    prism(2, x, -n, [(z0 + 0.15, H), (z1 - 0.15, H), (CZ, top(CZ) - 0.25)], 0.12, 0.14, M["gable_y"])
# Кровля: тёс, мох, снег
roof_slope(x0 - 0.45, x1 + 0.45, CZ, z1 + 0.45, RIDGE, top(z1 + 0.45), {**M, "slate": M["tes"], "white": M["trim_old"]})
roof_slope(x0 - 0.45, x1 + 0.45, CZ, z0 - 0.45, RIDGE, top(z0 - 0.45), {**M, "slate": M["tes"], "white": M["trim_old"]})
box((CX, RIDGE + 0.05, CZ), (W + 1.0, 0.2, 0.3), M["log"])      # охлупень
for x in (x0 - 0.43, x1 + 0.43):
    barge(x, CZ, RIDGE, z1 + 0.45, top(z1 + 0.45), {**M, "white": M["trim_old"]})
    barge(x, CZ, RIDGE, z0 - 0.45, top(z0 - 0.45), {**M, "white": M["trim_old"]})
# Наличник южного окна: облезлая резьба
wx = (WIN[0] + WIN[1]) / 2
for dx in (-0.62, 0.62):
    box((wx + dx, 1.5, z1 + R + 0.03), (0.12, 1.25, 0.04), M["trim_old"])
box((wx, 2.18, z1 + R + 0.03), (1.5, 0.16, 0.04), M["trim_old"])
for i in range(5):
    box((wx - 0.5 + i * 0.25, 2.3, z1 + R + 0.03), (0.12, 0.12, 0.03), M["trim_old"], yaw=0.0, tilt_z=math.pi / 4)
box((wx, 0.92, z1 + R + 0.08), (1.4, 0.05, 0.14), M["trim_old"])

# --- Прируб-сени ---
sx0, sx1, sz0, sz1 = SX - SW / 2, SX + SW / 2, CZ - SD / 2, CZ + SD / 2
DOOR = [-30.6, -29.4, 0.0, 2.15]
log_wall(0, x1, sx1, sz0, 0.0, SH, [], ends=(False, True))
log_wall(0, x1, sx1, sz1, 0.0, SH, [], ends=(False, True))
log_wall(2, sz0, sz1, sx1, STEP / 2, SH, [DOOR])
for z in (DOOR[0] - 0.08, DOOR[1] + 0.08):
    box((sx1 + 0.02, 1.08, z), (0.18, 2.16, 0.14), M["board_x"])
box((sx1 + 0.02, 2.22, -30.0), (0.18, 0.14, 1.4), M["board_x"])
# Односкатная крыша сеней — на восток
roof_slope_x = lambda: None
sy_hi, sy_lo = SH + 0.45, SH + 0.05
ln = math.hypot(sx1 + 0.4 - x1, sy_hi - sy_lo)
ang = math.atan2(sy_hi - sy_lo, sx1 + 0.4 - x1)
box(((x1 + sx1 + 0.4) / 2, (sy_hi + sy_lo) / 2, CZ), (ln, 0.08, SD + 0.6), M["tes"], tilt_z=-ang)
box(((x1 + sx1 + 0.4) / 2 - 0.05, (sy_hi + sy_lo) / 2 + 0.1, CZ), (ln * 0.9, 0.12, SD + 0.5), M["snow"], tilt_z=-ang, bevel=0.04)

# --- Внутри: пол, потолок с матицей ---
box((CX, 0.012, CZ), (W + 0.1, 0.03, D + 0.1), M["board_x"])   # пол под брёвна — без щели со снегом
box((CX, H - 0.02, CZ), (W - 0.2, 0.04, D - 0.2), M["board_x"])
box((CX, H - 0.14, CZ), (W - 0.2, 0.2, 0.22), M["log"])
box((SX - 0.05, 0.012, CZ), (SW + 0.1, 0.03, SD + 0.1), M["board_x"])
# Мох и наледь по низу снаружи — завалинка из старых досок
for z, n in ((z0, -1), (z1, 1)):
    box((CX, 0.2, z + n * 0.22), (W + 0.3, 0.4, 0.12), M["board_x"], tilt_x=n * 0.2)

obj, img, tris = kit.finish("izba", OUT, res=2048, origin="keep", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "izba.glb"), None)
print(f"[OK] izba: {tris} tris")
