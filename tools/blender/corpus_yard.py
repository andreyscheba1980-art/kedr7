# «Кедр-7» — хозяйство аэрологического корпуса (docs/ПЛАН_МОБЫ_И_КОРПУС.md):
#   ангар для наполнения шаров (зелёный тёс УГМС, ворота в поле на восток), навес с баллонами водорода
#   и бочками реагента, решётчатая радиомачта на растяжках, огороженная приборная площадка у тропы.
# Запуск: blender --background --python corpus_yard.py -- <out_dir> <yard|gate>
#   gate — одна створка ворот ангара (петля в начале координат, створка уходит по −Z, лицом на +X).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, cone, prism, siding, corner, roof_slope, barge, gable_boards, sign, text, _rects

OUT, PART = sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
M["cyl"] = kit.mat("y_cyl", (0.10, 0.22, 0.14), rough=0.5, wear=0.5, wear_col=(0.35, 0.33, 0.3))
M["barrel"] = kit.mat("y_barrel", (0.30, 0.10, 0.07), rough=0.6, wear=0.6, wear_col=(0.4, 0.25, 0.15))
M["lattice"] = kit.mat("y_lattice", (0.55, 0.12, 0.08), rough=0.6, wear=0.5, wear_col=(0.8, 0.8, 0.78))
COL = []


def colbox(c, s, yaw=0.0, tilt=0.0):
    COL.append([round(v, 3) for v in (*c, *s, yaw, tilt)])


# Ангар: x 116..128, z −40..−32, стены 5.0, конёк 7.0 вдоль X; ворота 4×4.6 в восточном фронтоне
HX0, HX1, HZ0, HZ1, HH, HR = 116.0, 128.0, -40.0, -32.0, 5.0, 7.0
HZC = (HZ0 + HZ1) / 2
GATE = [HZC - 2.0, HZC + 2.0, 0.1, 4.7]
WICKET = [HZC + 1.2, HZC + 2.1, 0.1, 2.1]      # калитка в западном фронтоне — вход для человека

if PART == "gate":
    # Створка 2.0×4.6: каркас из бруса, обшивка тёсом (рисунок в материале), раскос, петли, засов
    W, H = 2.0, 4.6
    box((0.03, H / 2, -W / 2), (0.06, H, W), M["vboard_y"])
    for y in (0.25, H / 2, H - 0.25):
        box((0.08, y, -W / 2), (0.05, 0.14, W - 0.06), M["green"])
    ang = math.atan2(H - 0.5, W - 0.2)
    box((0.08, H / 2, -W / 2), (0.05, 0.14, math.hypot(H - 0.5, W - 0.2)), M["green"], tilt_x=ang)
    for y in (0.6, H - 0.6):
        box((0.1, y, -0.25), (0.03, 0.08, 0.5), M["iron"])
    box((0.1, 2.0, -W + 0.15), (0.04, 0.3, 0.06), M["iron"])
    obj, img, tris = kit.finish("hangar_gate", OUT, res=512, origin="keep", samples=16, pack=0.003)
    kit.export(os.path.join(OUT, "hangar_gate.glb"), None)
    print("[OK] hangar_gate:", tris)
    raise SystemExit

# --- Ангар ---------------------------------------------------------------------------
F = 0.0     # тёс прямо на линии стены
siding(0, HX0, HX1, HZ0, -1, 0.15, HH, [[120.0, 121.2, 2.6, 3.6]], M, face=F)
siding(0, HX0, HX1, HZ1, +1, 0.15, HH, [[120.0, 121.2, 2.6, 3.6], [124.0, 125.2, 2.6, 3.6]], M, face=F)
siding(2, HZ0, HZ1, HX1, +1, 0.15, HH, [GATE], M, face=F)
siding(2, HZ0, HZ1, HX0, -1, 0.15, HH, [WICKET], M, face=F)
for (x, n) in ((HX1, +1), (HX0, -1)):
    gable_boards(2, HZC, (HZ1 - HZ0) / 2, x, n, HH, HR, M, face=F)
for sx, x in ((-1, HX0), (1, HX1)):
    for sz, z in ((-1, HZ0), (1, HZ1)):
        corner(x, z, sx, sz, 0.1, HH, M, face=F, w=0.14)
for (u, z, n) in ((120.6, HZ0, -1), (120.6, HZ1, +1), (124.6, HZ1, +1)):
    ugms.window_trim(0, u, z, n, 3.1, 1.2, 1.0, M, face=F, kokoshnik=False)
    box((u, 3.1, z - n * 0.1), (1.2, 1.0, 0.01), M["glass"])
# Кровля: два ската шифера, ветровые доски
for (zh, zl) in ((HZC, HZ0 - 0.5), (HZC, HZ1 + 0.5)):
    yl = HH - 0.5 * (HR - HH) / ((HZ1 - HZ0) / 2)
    roof_slope(HX0 - 0.4, HX1 + 0.4, zh, zl, HR + 0.05, yl + 0.05, M)
for x in (HX0 - 0.38, HX1 + 0.38):
    for zl in (HZ0 - 0.5, HZ1 + 0.5):
        barge(x, HZC, HR + 0.05, zl, HH - 0.5 * (HR - HH) / ((HZ1 - HZ0) / 2) + 0.05, M)
# Обвязка ворот: белые косяки и притолока, табличка; пандус-въезд
for z in (GATE[0] - 0.08, GATE[1] + 0.08):
    box((HX1 + 0.03, GATE[3] / 2, z), (0.06, GATE[3], 0.16), M["white"])
box((HX1 + 0.03, GATE[3] + 0.08, HZC), (0.06, 0.16, GATE[1] - GATE[0] + 0.32), M["white"])
box((HX1 + 0.04, 3.3, HZC + 0.05), (0.06, 0.14, 0.14), M["iron"])   # кронштейн лампы
cyl((HX1 + 0.25, 3.22, HZC + 0.05), 0.12, 0.1, M["rail"] if "rail" in M else M["iron"], verts=10, r2=0.05)
sign((HX1 + 0.04, 2.6, GATE[1] + 0.9), math.pi / 2, ["ОБОЛОЧЕЧНАЯ", "Курить запрещено"], M, w=0.7, h=0.3, size=0.06)
for z in (WICKET[0] - 0.06, WICKET[1] + 0.06):
    box((HX0 - 0.03, 1.1, z), (0.05, 2.2, 0.1), M["white"])
box((HX0 - 0.03, 2.2, sum(WICKET[:2]) / 2), (0.05, 0.1, 1.1), M["white"])
# Внутри: дощатая обшивка изнанки, бетонный пол, стол для наполнения, крюки
ugms.prism(0, HZ0, +1, [(HX0, 0.15), (HX1, 0.15), (HX1, HH), (HX0, HH)], 0.02, 0.04, M["wood"])
ugms.prism(0, HZ1, -1, [(HX0, 0.15), (HX1, 0.15), (HX1, HH), (HX0, HH)], 0.02, 0.04, M["wood"])
for (x, n, holes) in ((HX1, -1, [GATE]), (HX0, +1, [WICKET])):
    for r in _rects(HZ0, HZ1, 0.15, HH, [h[:4] for h in holes]):
        prism(2, x, n, [(r[0], r[2]), (r[1], r[2]), (r[1], r[3]), (r[0], r[3])], 0.02, 0.04, M["wood"])
box(((HX0 + HX1) / 2, 0.08, HZC), (HX1 - HX0 - 0.1, 0.16, HZ1 - HZ0 - 0.1), M["concrete"])
for x in (118.0, 122.0, 126.0):
    box((x, HH - 0.1, HZC), (0.18, 0.22, HZ1 - HZ0), M["wood"])
box((119.0, 0.85, HZ0 + 0.7), (2.2, 0.06, 0.9), M["wood"])
for dx in (-1.0, 1.0):
    for dz in (-0.35, 0.35):
        box((119.0 + dx, 0.42, HZ0 + 0.7 + dz), (0.06, 0.84, 0.06), M["wood"])
# Оболочечная внутри: стеллаж с коробками оболочек и зондов, стенд наполнения, полунадутый шар на балке,
# лавка и вешалка у калитки, круг разметки на полу. Место у ворот (запуск шара) свободно.
M["carton"] = kit.mat("y_carton", (0.5, 0.42, 0.3), rough=0.95, noise=0.3, noise_scale=20, dirt=0.6)
M["balloon"] = kit.mat("y_balloon", (0.85, 0.83, 0.76), rough=0.35, noise=0.12, noise_scale=5)
M["hose"] = kit.mat("y_hose", (0.12, 0.12, 0.11), rough=0.6)
M["gauge"] = kit.mat("y_gauge", (0.86, 0.84, 0.76), rough=0.4)
M["paint_f"] = kit.mat("y_paintf", (0.75, 0.7, 0.3), rough=0.8, noise=0.3, noise_scale=8, dirt=0.7)
for x in (121.0, 125.0):
    for z in (HZ0 + 0.15, HZ0 + 0.65):
        box((x, 1.1, z), (0.05, 2.2, 0.05), M["iron"])
for k in range(4):
    y = 0.2 + k * 0.6
    box((123.0, y, HZ0 + 0.4), (4.05, 0.04, 0.55), M["wood"])
    j = 0
    x = 121.15
    while x < 124.8:
        w = 0.35 + 0.1 * ((j + k) % 3)
        if (j * 3 + k) % 5 != 4:
            box((x + w / 2, y + 0.02 + 0.13, HZ0 + 0.4), (w - 0.03, 0.26, 0.42), M["carton"], bevel=0.01)
        x += w
        j += 1
colbox((123.0, 1.1, HZ0 + 0.4), (4.1, 2.2, 0.6))
# стенд наполнения: баллон в стойке, манометр, шланг к наконечнику на столе
cyl((117.0, 0.75, HZ1 - 0.6), 0.11, 1.32, M["cyl"], verts=12)
cyl((117.0, 1.48, HZ1 - 0.6), 0.11, 0.12, M["cyl"], verts=12, r2=0.055)
cyl((117.0, 1.6, HZ1 - 0.6), 0.04, 0.12, M["iron"], verts=8)
cyl((117.16, 1.62, HZ1 - 0.6), 0.07, 0.03, M["gauge"], verts=12, axis="x")
box((117.0, 0.9, HZ1 - 0.42), (0.3, 0.04, 0.04), M["iron"])
kit.tube(ugms._nm("hose"), [ugms.g2b(p) for p in ((117.0, 1.62, HZ1 - 0.6), (117.5, 1.0, HZ1 - 0.9), (118.2, 0.3, HZ1 - 1.2), (118.9, 0.9, HZ0 + 0.9))], 0.02, M["hose"], 6)
colbox((117.0, 0.8, HZ1 - 0.6), (0.3, 1.6, 0.3))
# полунадутая оболочка на верёвке от балки — висит над столом наполнения
kit.tube(ugms._nm("rope"), [ugms.g2b((119.0, HH - 0.1, HZ0 + 1.6)), ugms.g2b((119.0, 3.2, HZ0 + 1.6))], 0.01, M["hose"], 4)
o = kit.sphere(ugms._nm("ball"), 1.0, ugms.g2b((119.0, 2.55, HZ0 + 1.6)), M["balloon"], scale=ugms.gsize((0.62, 0.72, 0.58)), segs=16, rings=10)
cyl((119.0, 1.75, HZ0 + 1.6), 0.08, 0.2, M["balloon"], verts=10, r2=0.03)
# лавка и вешалка с ватником у калитки
box((HX0 + 0.35, 0.45, HZC - 1.0), (0.32, 0.04, 1.6), M["wood"])
for dz in (-0.7, 0.7):
    box((HX0 + 0.35, 0.22, HZC - 1.0 + dz), (0.28, 0.44, 0.05), M["wood"])
colbox((HX0 + 0.35, 0.24, HZC - 1.0), (0.34, 0.48, 1.6))
box((HX0 + 0.06, 1.75, HZC - 1.0), (0.04, 0.06, 1.2), M["wood"])
box((HX0 + 0.16, 1.25, HZC - 1.3), (0.16, 0.9, 0.45), M["carton"], bevel=0.05)
# разметка: жёлтый круг у ворот, где выпускают шар
for k in range(24):
    a = k * math.pi * 2 / 24
    box((126.0 + math.cos(a) * 1.2, 0.165, HZC + math.sin(a) * 1.2), (0.32, 0.005, 0.07), M["paint_f"], yaw=-a + math.pi / 2)
# Коллизии ангара: стены (с проёмами ворот и калитки), пол
for (x0, x1, z0, z1) in ((HX0, HX1, HZ0 - 0.06, HZ0 + 0.06), (HX0, HX1, HZ1 - 0.06, HZ1 + 0.06)):
    colbox(((x0 + x1) / 2, HH / 2, (z0 + z1) / 2), (x1 - x0, HH, z1 - z0))
for (x, holes) in ((HX1, [GATE]), (HX0, [WICKET])):
    for r in _rects(HZ0, HZ1, 0.0, HH, [h[:4] for h in holes]):
        colbox((x, (r[2] + r[3]) / 2, (r[0] + r[1]) / 2), (0.12, r[3] - r[2], r[1] - r[0]))
colbox((119.0, 0.45, HZ0 + 0.7), (2.2, 0.9, 0.9))

# --- Навес с баллонами водорода и бочками -------------------------------------------------
SX0, SX1, SZ0, SZ1 = 117.0, 122.0, -29.6, -27.4
for x in (SX0, SX1):
    for z in (SZ0, SZ1):
        box((x, 1.2, z), (0.12, 2.4 if z == SZ0 else 2.1, 0.12), M["wood"])
box(((SX0 + SX1) / 2, 2.32, (SZ0 + SZ1) / 2), (SX1 - SX0 + 0.5, 0.06, SZ1 - SZ0 + 0.6), M["slate"], tilt_x=0.14)
box(((SX0 + SX1) / 2, 2.4, (SZ0 + SZ1) / 2), (SX1 - SX0 + 0.3, 0.1, SZ1 - SZ0 + 0.4), M["snow"], tilt_x=0.14, bevel=0.03)
box(((SX0 + SX1) / 2, 0.9, SZ0 + 0.25), (SX1 - SX0, 0.06, 0.08), M["wood"])
M["band"] = kit.mat("y_band", (0.55, 0.1, 0.07), rough=0.5, wear=0.5)
M["stencil"] = kit.mat("y_stencil", (0.82, 0.82, 0.78), rough=0.8)
box(((SX0 + SX1) / 2, 1.3, SZ0 + 0.25), (SX1 - SX0, 0.06, 0.08), M["wood"])     # второй брус-упор
for i in range(9):
    x = SX0 + 0.35 + i * 0.5
    zc = SZ0 + 0.35
    # баллон: корпус, плечики, вентиль под колпаком, красный поясок «водород», трафарет, башмак
    cyl((x, 0.66, zc), 0.11, 1.32, M["cyl"], verts=12)
    cyl((x, 1.38, zc), 0.11, 0.12, M["cyl"], verts=12, r2=0.055)
    cyl((x, 1.5, zc), 0.058, 0.13, M["iron"], verts=8)
    cyl((x, 1.58, zc), 0.045, 0.04, M["iron"], verts=8, r2=0.02)
    cyl((x, 1.18, zc), 0.113, 0.06, M["band"], verts=12)
    box((x, 0.85, zc + 0.108), (0.08, 0.3, 0.008), M["stencil"])
    cyl((x, 0.03, zc), 0.12, 0.06, M["iron"], verts=12)
    colbox((x, 0.75, zc), (0.22, 1.5, 0.22))
for k, (x, z) in enumerate(((118.6, SZ1 - 0.4), (119.4, SZ1 - 0.4), (121.2, SZ1 - 0.45))):
    cyl((x, 0.45, z), 0.3, 0.9, M["barrel"], verts=14)
    for yy in (0.0, 0.3, 0.6, 0.88):   # зиги и закатанные края
        cyl((x, yy + 0.01, z), 0.305, 0.025, M["iron"], verts=14)
    cyl((x + 0.15, 0.905, z - 0.08), 0.03, 0.012, M["iron"], verts=8)        # пробка
    box((x, 0.5, z + 0.29), (0.22, 0.12, 0.01), M["stencil"])
    if k != 1:
        kit.sphere(ugms._nm("bs"), 1.0, ugms.g2b((x, 0.92, z)), M["snow"], scale=ugms.gsize((0.27, 0.05, 0.27)), segs=12, rings=6)
    colbox((x, 0.45, z), (0.6, 0.9, 0.6))
sign((SX0 - 0.07, 1.6, (SZ0 + SZ1) / 2), -math.pi / 2, ["ОГНЕОПАСНО", "Водород"], M, w=0.6, h=0.3, size=0.06)
for x in (SX0, SX1):
    for z in (SZ0, SZ1):
        colbox((x, 1.2, z), (0.14, 2.4, 0.14))

# --- Радиомачта на растяжках (решётчатая, красно-белая) ------------------------------------
MX, MZ, MH = 112.0, -13.0, 20.0
R = 0.35
legs = [(MX + R * math.cos(a), MZ + R * math.sin(a)) for a in (0.0, 2.094, 4.189)]
for (x, z) in legs:
    cyl((x, MH / 2, z), 0.035, MH, M["lattice"], verts=6)
y = 0.0
seg = 1.0
while y < MH - 0.1:
    for i in range(3):
        a, b = legs[i], legs[(i + 1) % 3]
        p0 = (a[0], y, a[1]); p1 = (b[0], y + seg, b[1])
        kit.tube("br", [ugms.g2b(p0), ugms.g2b(p1)], 0.015, M["lattice"] if int(y / 4) % 2 == 0 else M["white"], 4)
    y += seg
cyl((MX, MH + 0.15, MZ), 0.08, 0.3, M["iron"], verts=8)
for a in (0.5, 2.6, 4.7):
    ax, az = MX + 9.0 * math.cos(a), MZ + 9.0 * math.sin(a)
    for h in (MH * 0.45, MH * 0.9):
        kit.tube("guy", [ugms.g2b((MX, h, MZ)), ugms.g2b((ax, 0.3, az))], 0.012, M["iron"], 4)
    box((ax, 0.15, az), (0.6, 0.3, 0.6), M["concrete"])
    colbox((ax, 0.15, az), (0.6, 0.3, 0.6))
box((MX, 0.15, MZ), (1.2, 0.3, 1.2), M["concrete"])
colbox((MX, MH / 2, MZ), (0.9, MH, 0.9))

# --- Приборная площадка 9×9 у тропы: белая ограда, калитка с запада, табличка ------------------
PX, PZ, PH = 66.0, -22.0, 4.5
for side in range(4):
    corners = [(-PH, -PH), (PH, -PH), (PH, PH), (-PH, PH)]
    a, b = corners[side], corners[(side + 1) % 4]
    n = 9
    for i in range(n):
        k0, k1 = i / n, (i + 1) / n
        p = (PX + a[0] + (b[0] - a[0]) * k0, PZ + a[1] + (b[1] - a[1]) * k0)
        q = (PX + a[0] + (b[0] - a[0]) * k1, PZ + a[1] + (b[1] - a[1]) * k1)
        gate = side == 3 and i == 4          # западная сторона, середина — калитка
        box((p[0], 0.55, p[1]), (0.08, 1.1, 0.08), M["white"])
        colbox((p[0], 0.55, p[1]), (0.1, 1.1, 0.1))
        if gate:
            continue
        L = math.hypot(q[0] - p[0], q[1] - p[1])
        yaw = math.atan2(q[0] - p[0], q[1] - p[1])
        for hh in (0.4, 0.95):
            box(((p[0] + q[0]) / 2, hh, (p[1] + q[1]) / 2), (0.04, 0.07, L), M["white"], yaw=yaw)
        colbox(((p[0] + q[0]) / 2, 0.55, (p[1] + q[1]) / 2), (0.06, 1.1, L), yaw)
sign((PX - PH - 0.6, 1.2, PZ + 1.6), -math.pi / 2, ["МЕТЕОПЛОЩАДКА", "Посторонним вход воспрещён"], M, w=0.8, h=0.3, size=0.05)
box((PX - PH - 0.6, 0.6, PZ + 1.6), (0.06, 1.2, 0.06), M["wood"])

obj, img, tris = kit.finish("corpus_yard", OUT, res=2048, origin="keep", samples=24, pack=0.002, ao_blur=2)
kit.export(os.path.join(OUT, "corpus_yard.glb"), None)
lo = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "data", "corpus_col_yard.gd")
with open(dst, "w", encoding="utf8") as f:
    f.write("# Сгенерировано tools/blender/corpus_yard.py — коллизии хозяйства корпуса. Не править руками.\n")
    f.write("# Коробка: [cx, cy, cz, sx, sy, sz, yaw, tilt_x] в координатах игры.\n")
    f.write("const BOXES := [\n")
    for b in COL:
        f.write("\t[%s],\n" % ", ".join("%.3f" % v for v in b))
    f.write("]\n")
print("[OK] corpus_yard: %d tris, низ %.3f, коллизий %d" % (tris, lo, len(COL)))

if os.environ.get("PREVIEW"):
    from mathutils import Vector
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 1100, 700
    cam_d = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam); sc.camera = cam
    for tag, loc, tgt, lens in (("hangar", (138.0, 4.0, -22.0), (121.0, 3.0, -35.0), 26), ("mast", (95.0, 3.0, 4.0), (112.0, 10.0, -13.0), 22),
                                ("plot", (56.0, 2.5, -12.0), (66.0, 0.6, -22.0), 30)):
        L, G = Vector(ugms.g2b(loc)), Vector(ugms.g2b(tgt))
        cam.location = L
        cam.rotation_euler = (G - L).to_track_quat("-Z", "Y").to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(OUT, "_prev_yard_%s.png" % tag)
        bpy.ops.render.render(write_still=True)
