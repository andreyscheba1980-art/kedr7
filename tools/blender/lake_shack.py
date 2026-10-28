# Лодочный сарай на озере — «старое и чужое»: серая некрашеная вертикальная доска с нащельниками,
# помост на сваях, тёсовая кровля со снегом, сосульки. Размеры — как Yard._build_lake: центр LAKE_SHACK
# (−36, 0, 20), помост 9×6.5 на высоте 0.45, сарай 7.5×5.2, стены 2.8, на юге проём x −1.5..1.5 высотой 2.4,
# конёк вдоль X на высоте 4.25.
# Запуск: blender --background --python lake_shack.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, prism, _rects, roof_slope, barge

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
P = ugms.painted
grey = (0.36, 0.34, 0.31)
moss = (0.22, 0.25, 0.18)
M["vx"] = P("l_vx", grey, under=moss, peel=0.15, scale=2.5, grain=0.15, boards="v", step=0.2)
M["vy"] = P("l_vy", grey, under=moss, peel=0.15, scale=2.5, grain=0.15, boards="y", step=0.2)
M["deck"] = P("l_deck", (0.30, 0.28, 0.25), under=(0.22, 0.20, 0.18), peel=0.4, scale=4.0, grain=0.1, boards="x", step=0.18)
M["tes"] = P("l_tes", (0.21, 0.19, 0.17), under=moss, peel=0.25, scale=3.0, grain=0.15, boards="x", step=0.22)
M["ice"] = kit.mat("l_ice", (0.70, 0.80, 0.88), rough=0.3, noise=0.1, noise_scale=10)
M["batten"] = kit.mat("l_bat", (0.30, 0.28, 0.25), rough=0.9, noise=0.3, noise_scale=20, wear=0.5, dirt=0.6)

CX, CZ = -36.0, 20.0
DH = 0.45
BH = 2.8
HX, HZ = 3.75, 2.575
SOUTH_OPEN = [CX - 1.5, CX + 1.5, DH, DH + 2.4]
TOP = DH + BH + 1.0

# Сваи с наледью
for sx in (-4.0, -2.0, 0.0, 2.0, 4.0):
    for sz in (-2.8, 0.0, 2.8):
        cyl((CX + sx, DH / 2 - 0.4, CZ + sz), 0.09, DH + 0.8, M["batten"], verts=8)
        cyl((CX + sx, 0.08, CZ + sz), 0.14, 0.2, M["ice"], verts=8, r2=0.1)
# Помост
box((CX, DH - 0.06, CZ), (9.0, 0.12, 6.5), M["deck"])
for sz in (-2.8, 0.0, 2.8):
    box((CX, DH - 0.18, CZ + sz), (9.0, 0.14, 0.16), M["batten"])

# Стены: доска снаружи и изнутри, нащельники снаружи
walls = [(0, CZ - HZ, -1, []), (0, CZ + HZ, +1, [SOUTH_OPEN]), (2, CX - HX, -1, []), (2, CX + HX, +1, [])]
for axis, c, n, holes in walls:
    lo, hi = (CX - HX, CX + HX) if axis == 0 else (CZ - HZ, CZ + HZ)
    mat = M["vx"] if axis == 0 else M["vy"]
    for r in _rects(lo, hi, DH, DH + BH, holes):
        pts = [(r[0], r[2]), (r[1], r[2]), (r[1], r[3]), (r[0], r[3])]
        prism(axis, c, n, pts, 0.03, 0.06, mat)
        prism(axis, c, -n, pts, -0.03, 0.0, mat)
    u = lo + 0.2
    while u < hi - 0.1:
        if not any(h[0] - 0.05 < u < h[1] + 0.05 for h in holes):
            sz = (0.05, BH - 0.1, 0.02)
            pos = ugms._uv(axis, u, c, DH + BH / 2, n * 0.07)
            box(pos, sz if axis == 0 else (sz[2], sz[1], sz[0]), M["batten"])
        u += 0.4
# Над проёмом — притолока и бревно-ригель
box((CX, DH + 2.45, CZ + HZ + 0.05), (3.2, 0.12, 0.12), M["batten"])
# Фронтоны
for x, n in ((CX - HX, -1), (CX + HX, +1)):
    prism(2, x, n, [(CZ - HZ, DH + BH), (CZ + HZ, DH + BH), (CZ, TOP - 0.05)], 0.03, 0.06, M["vy"])
    prism(2, x, -n, [(CZ - HZ, DH + BH), (CZ + HZ, DH + BH), (CZ, TOP - 0.05)], -0.03, 0.0, M["vy"])
# Кровля
half = HZ + 0.4
yl = TOP - half * (1.0 / 2.58)
roof_slope(CX - HX - 0.35, CX + HX + 0.35, CZ, CZ + half, TOP + 0.1, yl + 0.1, {**M, "slate": M["tes"], "white": M["batten"]})
roof_slope(CX - HX - 0.35, CX + HX + 0.35, CZ, CZ - half, TOP + 0.1, yl + 0.1, {**M, "slate": M["tes"], "white": M["batten"]})
box((CX, TOP + 0.2, CZ), (2 * HX + 0.8, 0.14, 0.2), M["batten"])
for x in (CX - HX - 0.33, CX + HX + 0.33):
    barge(x, CZ, TOP + 0.1, CZ + half, yl + 0.1, {**M, "white": M["batten"]})
    barge(x, CZ, TOP + 0.1, CZ - half, yl + 0.1, {**M, "white": M["batten"]})
# Затяжки и стойка под коньком (на них подвешен дощаник)
for bx in (-1.4, 1.6):
    box((CX + bx, DH + BH - 0.07, CZ), (0.14, 0.14, 5.0), M["batten"])
box((CX + 0.1, DH + BH + 0.5, CZ), (0.12, 0.95, 0.12), M["batten"])

obj, img, tris = kit.finish("lake_shack", OUT, res=2048, origin="keep", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "lake_shack.glb"), None)
print(f"[OK] lake_shack: {tris} tris")
