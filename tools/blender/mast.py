# Ферменная радиомачта 16 м для «Кедр-7»: четыре пояса из труб, распорки и раскосы, красно-белые секции,
# лестница с дугами на одной грани, площадка с ограждением под верхом, диполи, фидер вдоль пояса,
# снег на горизонталях. Начало — низ мачты по центру (как у Props.radio_mast()).
# Запуск: python3 mast.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

H = 16.0
BW, TW = 0.65, 0.28
RED = mat("red", (0.5, 0.08, 0.05), 0.6, 0, 0.25, 30, wear=0.8, dirt=0.3, wear_col=(0.3, 0.2, 0.17))
WHITE = mat("white", (0.72, 0.72, 0.7), 0.6, 0, 0.2, 30, wear=0.8, dirt=0.4, wear_col=(0.32, 0.22, 0.17))
IRON = mat("iron", (0.16, 0.17, 0.18), 0.6, 0, 0.3, 40, wear=0.5, dirt=0.4, wear_col=(0.3, 0.2, 0.15))
SNOW = mat("snow", (0.85, 0.88, 0.92), 0.9, 0, 0.08, 40)
BLACK = mat("black", (0.02, 0.02, 0.02), 0.8)
CERAMIC = mat("ceramic", (0.7, 0.66, 0.55), 0.4)


def half_w(z):
    return (BW + (TW - BW) * z / H) / 2


SEG = 1.6
segs = int(H / SEG)
# Пояса (ноги) — по секциям, чтобы красить красно-белыми полосами
for s in range(segs):
    z0, z1 = s * SEG, (s + 1) * SEG
    col = RED if (s % 2 == 1 or s >= segs - 2) else WHITE
    w0, w1 = half_w(z0), half_w(z1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(f"leg{s}{sx}{sy}", [(sx * w0, sy * w0, z0), (sx * w1, sy * w1, z1)], 0.03, col, 8)
    # распорки и раскосы по четырём граням
    c0 = [(-w0, -w0), (w0, -w0), (w0, w0), (-w0, w0)]
    c1 = [(-w1, -w1), (w1, -w1), (w1, w1), (-w1, w1)]
    for f in range(4):
        a0, b0 = c0[f], c0[(f + 1) % 4]
        a1, b1 = c1[f], c1[(f + 1) % 4]
        tube(f"hz{s}{f}", [(a0[0], a0[1], z0), (b0[0], b0[1], z0)], 0.014, col, 6)
        tube(f"dg{s}{f}a", [(a0[0], a0[1], z0), (b1[0], b1[1], z1)], 0.011, col, 6)
        tube(f"dg{s}{f}b", [(b0[0], b0[1], z0), (a1[0], a1[1], z1)], 0.011, col, 6)
        # снежок на горизонтальной распорке
        if s < segs - 1:
            mx, my = (a0[0] + b0[0]) / 2, (a0[1] + b0[1]) / 2
            ln = math.dist(a0, b0)
            box(f"snow{s}{f}", (ln * 0.8 if f % 2 == 0 else 0.03, 0.03 if f % 2 == 0 else ln * 0.8, 0.012), (mx, my, z0 + 0.02), SNOW, 0.005)
# Опорные пластины у основания
for sx in (-1, 1):
    for sy in (-1, 1):
        box(f"base{sx}{sy}", (0.14, 0.14, 0.02), (sx * BW / 2, sy * BW / 2, 0.01), IRON, 0.004)
        for bx in (-1, 1):
            cyl(f"bolt{sx}{sy}{bx}", 0.012, 0.03, (sx * BW / 2 + bx * 0.045, sy * BW / 2 + 0.045, 0.03), IRON, rot=(0, 0, 0), verts=6)
# Лестница на грани −Y (к тропе) со страховочными дугами выше 2.5 м
LY = -1
for sx in (-0.15, 0.15):
    pts = []
    for zz in (0.3, H - 0.6):
        w = half_w(zz)
        pts.append((sx * (w / 0.325) * 0.6, LY * (w + 0.07), zz))
    tube(f"rail{sx}", pts, 0.01, IRON, 6)
r = 0
z = 0.45
while z < H - 0.8:
    w = half_w(z)
    k = (w / 0.325) * 0.6
    tube(f"rung{r}", [(-0.15 * k, LY * (w + 0.07), z), (0.15 * k, LY * (w + 0.07), z)], 0.008, IRON, 6)
    if z > 2.5 and r % 3 == 0:
        arc = []
        for i in range(9):
            a = math.pi * i / 8
            arc.append((math.cos(a) * 0.26 * k, LY * (w + 0.07 + math.sin(a) * 0.32), z))
        tube(f"hoop{r}", arc, 0.008, IRON, 5)
    z += 0.32
    r += 1
# Площадка под верхом с ограждением
PZ = H - 0.9
pw = half_w(PZ) + 0.35
box("platform", (pw * 2, pw * 2, 0.04), (0, 0, PZ), IRON, 0.006)
for i in range(16):
    t = i / 16 * 4
    side = int(t); u = t - side
    corners = [(-pw, -pw), (pw, -pw), (pw, pw), (-pw, pw)]
    a, b = corners[side], corners[(side + 1) % 4]
    x, y = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
    tube(f"post{i}", [(x, y, PZ), (x, y, PZ + 0.9)], 0.012, IRON, 6)
for zz in (PZ + 0.45, PZ + 0.9):
    c = [(-pw, -pw, zz), (pw, -pw, zz), (pw, pw, zz), (-pw, pw, zz), (-pw, -pw, zz)]
    tube(f"railing{zz}", c, 0.014, RED, 6)
box("plat_snow", (pw * 1.9, pw * 1.9, 0.03), (0, 0, PZ + 0.035), SNOW, 0.01)
# Колпак сверху, заградительный огонь, громоотвод
box("cap", (TW * 1.3, TW * 1.3, 0.05), (0, 0, H), IRON, 0.008)
cyl("lamp_base", 0.07, 0.08, (0, 0, H + 0.08), IRON, rot=(0, 0, 0), verts=14)
sphere("lamp_glass", 0.075, (0, 0, H + 0.18), RED, segs=14, rings=8)
cyl("lamp_cage", 0.08, 0.02, (0, 0, H + 0.26), IRON, rot=(0, 0, 0), verts=14)
tube("rod", [(0, 0, H + 0.28), (0, 0, H + 1.4)], 0.012, IRON, 6)
# Диполи на траверсах (две высоты) с изоляторами
for zz, L in ((12.2, 1.6), (14.2, 1.2)):
    w = half_w(zz)
    tube(f"arm{zz}", [(-w, 0, zz), (-w - 0.6, 0, zz)], 0.02, IRON, 6)
    tube(f"arm2{zz}", [(w, 0, zz), (w + 0.6, 0, zz)], 0.02, IRON, 6)
    for sx in (-1, 1):
        x = sx * (w + 0.6)
        tube(f"dip{zz}{sx}", [(x, -L / 2, zz), (x, L / 2, zz)], 0.009, IRON, 6)
        for sy in (-1, 1):
            cyl(f"ins{zz}{sx}{sy}", 0.018, 0.06, (x, sy * (L / 2 + 0.03), zz), CERAMIC, rot=(math.pi / 2, 0, 0), verts=8)
# Фидер — кабель вдоль пояса с хомутами
fp = []
for i in range(12):
    zz = 0.6 + i * (H - 1.2) / 11
    w = half_w(zz)
    fp.append((w + 0.05, w + 0.05, zz))
tube("feeder", fp, 0.014, BLACK, 6)
for i, p in enumerate(fp[1:-1]):
    torus(f"clamp{i}", 0.022, 0.005, p, IRON, rot=(0, 0, 0), maj=10, mino=4)
# Табличка
box("sign", (0.004, 0.3, 0.2), (BW / 2 + 0.035, 0, 1.5), WHITE, 0.003)
text("КЕДР-7", 0.05, (BW / 2 + 0.038, 0, 1.55), BLACK, 0.0, rot=(math.pi / 2, 0, math.pi / 2))
text("ОПАСНО", 0.035, (BW / 2 + 0.038, 0, 1.46), RED, 0.0, rot=(math.pi / 2, 0, math.pi / 2))

obj, img, tris = kit.finish("radio_mast16", OUT, res=1024, origin="keep", samples=32)
kit.export(os.path.join(OUT, "radio_mast16.glb"), os.path.join(OUT, "radio_mast16.blend"))
print("OK tris:", tris)
