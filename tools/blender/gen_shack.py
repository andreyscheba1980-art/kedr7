# Будка дизель-генератора (ДЭС) у дома «Кедр-7» в стиле УГМС: зелёный тёс, белые углы и наличники,
# односкатный шифер на север со снегом и сосульками, выхлопная труба, таблички. Внутри — тёмная доска.
# Размеры — как Station._build_generator_shack: центр (14.5, 0.05, −13.5), 3.2×2.8, верх стен
# 2.1 (север) … 2.4 (юг), дверь на юг (x −0.6..0.6), окошко на восток (z −0.5..0.1, y 1.2..1.7).
# Запуск: blender --background --python gen_shack.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, prism, siding, corner, window_trim, roof_slope, barge, sign, _rects

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
M["lining_z"] = ugms.painted("g_lin_z", (0.26, 0.21, 0.16), under=(0.2, 0.16, 0.12), peel=0.5, scale=5.0, grain=0.05, detail=3, streaks=False, boards="x", step=0.2)
M["lining_x"] = ugms.painted("g_lin_x", (0.26, 0.21, 0.16), under=(0.2, 0.16, 0.12), peel=0.5, scale=5.0, grain=0.05, detail=3, streaks=False, boards="y", step=0.2)

CX, CY, CZ = 14.5, 0.05, -13.5
HX, HZ = 1.6, 1.4
SLOPE = 0.3 / 2.8
FLOOR = CY + 0.05


def top(zl):
    return CY + 2.1 + (zl + HZ) * SLOPE


DOOR = [CX - 0.6, CX + 0.6, 0.0, CY + 2.0]
WIN = [CZ - 0.5, CZ + 0.1, CY + 1.2, CY + 1.7]

# Стены: наружная грань — на линии ±HX/±HZ (face=0 → плита от −0.05 до 0)
siding(0, CX - HX, CX + HX, CZ + HZ, +1, FLOOR, top(HZ), [DOOR], M, face=0.0)
siding(0, CX - HX, CX + HX, CZ - HZ, -1, FLOOR, top(-HZ), [], M, face=0.0)
siding(2, CZ - HZ, CZ + HZ, CX - HX, -1, FLOOR, 0, [], M, face=0.0, top_fn=lambda u: top(u - CZ))
siding(2, CZ - HZ, CZ + HZ, CX + HX, +1, FLOOR, 0, [WIN], M, face=0.0, top_fn=lambda u: top(u - CZ))
# Изнутри — тёмная доска
for axis, c, n, holes, key in ((0, CZ + HZ, -1, [DOOR], "lining_z"), (0, CZ - HZ, +1, [], "lining_z"),
                               (2, CX - HX, +1, [], "lining_x"), (2, CX + HX, -1, [WIN], "lining_x")):
    lo, hi = (CX - HX + 0.07, CX + HX - 0.07) if axis == 0 else (CZ - HZ + 0.07, CZ + HZ - 0.07)
    for r in _rects(lo, hi, FLOOR, top(HZ), holes):
        if axis == 0:
            yt = top(c - CZ)
            pts = [(r[0], r[2]), (r[1], r[2]), (r[1], min(r[3], yt)), (r[0], min(r[3], yt))]
        else:
            pts = [(r[0], r[2]), (r[1], r[2]), (r[1], min(r[3], top(r[1] - CZ))), (r[0], min(r[3], top(r[0] - CZ)))]
        prism(axis, c, n, pts, 0.05, 0.07, M[key])

# Угловые доски, наличники двери и окна
for sx in (-1, 1):
    for sz in (-1, 1):
        corner(CX + sx * HX, CZ + sz * HZ, sx, sz, CY, top(sz * HZ), M, face=0.0, w=0.12)
for x in (CX - 0.66, CX + 0.66):
    box((x, CY + 1.02, CZ + HZ + 0.02), (0.1, 2.04, 0.03), M["white"])
box((CX, CY + 2.08, CZ + HZ + 0.02), (1.42, 0.12, 0.03), M["white"])
window_trim(2, CZ - 0.2, CX + HX, +1, CY + 1.45, 0.6, 0.5, M, face=0.0, kokoshnik=False)

# Цоколь-обвязка на лежнях
for sz in (-1, 1):
    box((CX, CY - 0.02, CZ + sz * (HZ - 0.05)), (2 * HX + 0.1, 0.14, 0.16), M["wood"])
for sx in (-1, 1):
    box((CX + sx * (HX - 0.05), CY - 0.02, CZ), (0.16, 0.14, 2 * HZ + 0.1), M["wood"])

# Крыша: односкатная на север, вылет 0.4 спереди, 0.35 сзади, 0.25 по бокам
z_hi, z_lo = CZ + HZ + 0.4, CZ - HZ - 0.35
x0, x1 = CX - HX - 0.25, CX + HX + 0.25
y_hi, y_lo = top(HZ + 0.4) + 0.1, top(-HZ - 0.35) + 0.1
roof_slope(x0, x1, z_hi, z_lo, y_hi, y_lo, M)
for x in (x0 + 0.02, x1 - 0.02):
    barge(x, z_hi, y_hi, z_lo, y_lo, M)
box((CX, y_hi - 0.1, z_hi), (x1 - x0, 0.2, 0.04), M["white"])     # лобовая доска спереди
# Стропила изнутри
for rx in (-1.05, 0.0, 1.05):
    zm = (z_hi + z_lo) / 2
    box((CX + rx, (y_hi + y_lo) / 2 - 0.2, zm), (0.07, 0.1, z_hi - z_lo - 0.1), M["wood"], tilt_x=math.atan(SLOPE))

# Выхлопная труба генератора с колпаком и хомутом (дым — в station.gd на (−0.5, 3.4, −0.6) от центра)
px, pz = CX - 0.5, CZ - 0.6
cyl((px, CY + 2.3, pz), 0.06, 1.6, M["iron"], verts=10)
cyl((px, CY + 3.12, pz), 0.12, 0.05, M["iron"], verts=10, r2=0.03)
box((px, CY + 2.62, pz), (0.2, 0.04, 0.2), M["iron"])

# Таблички у двери
sign((CX + 1.05, CY + 1.55, CZ + HZ + 0.03), 0.0, ["ДЭС-8", "дизельная"], M, w=0.5, h=0.26, size=0.06)
box((CX - 1.05, CY + 1.55, CZ + HZ + 0.025), (0.3, 0.3, 0.01), M["enamel"], yaw=0.0)
box((CX - 1.05, CY + 1.55, CZ + HZ + 0.032), (0.05, 0.22, 0.004), M["red"], tilt_z=0.35)

obj, img, tris = kit.finish("gen_shack", OUT, res=1024, origin="keep", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "gen_shack.glb"), None)
print(f"[OK] gen_shack: {tris} tris")
