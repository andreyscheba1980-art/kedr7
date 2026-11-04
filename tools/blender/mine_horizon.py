# «Кедр-7» — подземный горизонт заброшенной штольни «Горизонт-40» (скрытая локация под POI 11).
# Координаты — от околоствольного двора (ноль = пол двора под лестницей), оси игры: X восток, Z юг, Y вверх.
# Околоствольный двор → главный штрек на север 36 м (крепь-оклады через 2 м, рельсы, наледь) → восточная
# рассечка к камере взрывников (схрон) → западный тупик с сошедшей вагонеткой → завал с лазом → забой
# (последняя стоянка Семёнова). Стены — порода с выступами, не коробки.
# Запуск: blender --background --factory-startup --python mine_horizon.py -- <out_dir>
import bpy, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl

OUT = sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()
rnd = random.Random(40)
mk = lambda n, c, **k: kit.mat(n, c, **k)
ROCK = mk("mh_rock", (0.27, 0.25, 0.23), rough=0.95, noise=0.45, noise_scale=9, dirt=0.8)
ROCK2 = mk("mh_rock2", (0.33, 0.3, 0.26), rough=0.95, noise=0.5, noise_scale=14, dirt=0.7)
ICE = mk("mh_ice", (0.62, 0.72, 0.8), rough=0.2, noise=0.15, noise_scale=6)
TIMBER = mk("mh_timber", (0.28, 0.2, 0.13), rough=0.9, noise=0.4, noise_scale=40, wear=0.6, dirt=0.8, wear_col=(0.45, 0.38, 0.3))
RAIL = mk("mh_rail", (0.2, 0.15, 0.12), rough=0.6, wear=0.7, wear_col=(0.45, 0.25, 0.12))
IRON = mk("mh_iron", (0.13, 0.12, 0.11), rough=0.6, wear=0.6, wear_col=(0.4, 0.22, 0.12))
CRATE = mk("mh_crate", (0.36, 0.28, 0.17), rough=0.85, noise=0.35, noise_scale=20, wear=0.5)
CLOTH = mk("mh_cloth", (0.22, 0.24, 0.18), rough=1.0, noise=0.4, noise_scale=25)
PAPER = mk("mh_paper", (0.75, 0.72, 0.6), rough=0.9)
RED = mk("mh_red", (0.55, 0.1, 0.07), rough=0.6, wear=0.5)
CABLE = mk("mh_cable", (0.06, 0.06, 0.06), rough=0.8)

COL = []


def colbox(c, s):
    COL.append([round(v, 3) for v in (*c, *s, 0.0, 0.0)])


def rock_chunks(x0, x1, z0, z1, y0, y1, side, n):
    """Выступы породы по стене: сплюснутые сферы, чтобы стена не читалась коробкой."""
    for _ in range(n):
        if side in ("w", "e"):
            x = x0 if side == "w" else x1
            p = (x + (0.08 if side == "w" else -0.08), rnd.uniform(y0, y1), rnd.uniform(z0, z1))
            sc = (rnd.uniform(0.12, 0.25), rnd.uniform(0.18, 0.45), rnd.uniform(0.25, 0.6))
        else:
            z = z0 if side == "n" else z1
            p = (rnd.uniform(x0, x1), rnd.uniform(y0, y1), z + (0.08 if side == "n" else -0.08))
            sc = (rnd.uniform(0.25, 0.6), rnd.uniform(0.18, 0.45), rnd.uniform(0.12, 0.25))
        kit.sphere(ugms._nm("rk"), 1.0, ugms.g2b(p), ROCK2 if rnd.random() < 0.4 else ROCK, scale=ugms.gsize(sc), segs=8, rings=5)


def drift(x0, x1, z0, z1, h, along_z=True, sets=True, rails=True, walls=("w", "e"), gaps=None):
    """Выработка-прямоугольник: пол, кровля, стены породой, крепь-оклады, рельсы, наледь."""
    w, d = x1 - x0, z1 - z0
    xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
    box((xc, -0.1, zc), (w + 0.6, 0.2, d + 0.6), ROCK)
    colbox((xc, -0.1, zc), (w + 0.6, 0.2, d + 0.6))
    box((xc, h + 0.15, zc), (w + 0.6, 0.3, d + 0.6), ROCK)
    colbox((xc, h + 0.15, zc), (w + 0.6, 0.3, d + 0.6))
    gaps = gaps or {}

    def segs(lo, hi, cut):
        """Отрезки стены [lo, hi] за вычетом проёмов cut (примыкания выработок)."""
        out, cur = [], lo
        for a, b in sorted(cut):
            if a > cur:
                out.append((cur, a))
            cur = max(cur, b)
        if cur < hi:
            out.append((cur, hi))
        return out
    for sd in walls:
        if sd in ("w", "e"):
            x = x0 - 0.2 if sd == "w" else x1 + 0.2
            for a, b in segs(z0 - 0.2, z1 + 0.2, gaps.get(sd, [])):
                c, sz = (x, h / 2, (a + b) / 2), (0.4, h + 0.2, b - a)
                box(c, sz, ROCK)
                colbox(c, sz)
                rock_chunks(x0, x1, a, b, 0.2, h - 0.2, sd, max(1, int((b - a) * 1.6)))
        else:
            z = z0 - 0.2 if sd == "n" else z1 + 0.2
            for a, b in segs(x0 - 0.2, x1 + 0.2, gaps.get(sd, [])):
                c, sz = ((a + b) / 2, h / 2, z), (b - a, h + 0.2, 0.4)
                box(c, sz, ROCK)
                colbox(c, sz)
                rock_chunks(a, b, z0, z1, 0.2, h - 0.2, sd, max(1, int((b - a) * 1.6)))
    L = d if along_z else w
    n = int(L / 2.0)
    for i in range(n + 1):
        t = i * 2.0 + 0.3
        if t > L - 0.2:
            break
        if sets:
            if along_z:
                z = z0 + t
                for xx in (x0 + 0.12, x1 - 0.12):
                    cyl((xx, (h - 0.1) / 2, z), 0.09, h - 0.1, TIMBER, verts=7)
                box((xc, h - 0.08, z), (w, 0.18, 0.2), TIMBER)
                for k in range(4):     # затяжки над окладом
                    box((x0 + 0.3 + k * (w - 0.6) / 3, h + 0.02, z + 0.5), (0.12, 0.04, 1.0), TIMBER)
            else:
                x = x0 + t
                for zz in (z0 + 0.12, z1 - 0.12):
                    cyl((x, (h - 0.1) / 2, zz), 0.09, h - 0.1, TIMBER, verts=7)
                box((x, h - 0.08, zc), (0.2, 0.18, d), TIMBER)
        if rnd.random() < 0.45:       # сосульки с кровли
            ix = rnd.uniform(x0 + 0.3, x1 - 0.3)
            iz = (z0 + t + 1.0) if along_z else rnd.uniform(z0 + 0.3, z1 - 0.3)
            ixx = ix if along_z else x0 + t + 1.0
            cyl((ixx, h - 0.25, iz), 0.05, 0.45, ICE, verts=6, r2=0.005)
    if rails:
        if along_z:
            for xx in (xc - 0.3, xc + 0.3):
                box((xx, 0.06, zc), (0.05, 0.08, d), RAIL)
            for i in range(int(d / 0.7)):
                box((xc, 0.02, z0 + 0.35 + i * 0.7), (1.0, 0.05, 0.14), TIMBER)
        else:
            for zz in (zc - 0.3, zc + 0.3):
                box((xc, 0.06, zz), (w, 0.08, 0.05), RAIL)
            for i in range(int(w / 0.7)):
                box((x0 + 0.35 + i * 0.7, 0.02, zc), (0.14, 0.05, 1.0), TIMBER)
    for _ in range(int(L / 6)):    # наледь на почве
        p = (rnd.uniform(x0 + 0.3, x1 - 0.3), 0.015, rnd.uniform(z0 + 0.3, z1 - 0.3))
        kit.sphere(ugms._nm("ice"), 1.0, ugms.g2b(p), ICE, scale=ugms.gsize((rnd.uniform(0.3, 0.7), 0.02, rnd.uniform(0.3, 0.9))), segs=8, rings=3)


# --- Околоствольный двор (лестница наверх у южной стены) ---
drift(-2.0, 2.0, -2.0, 2.0, 2.8, sets=False, rails=False, walls=("w", "e", "s", "n"), gaps={"n": [(-1.2, 1.2)]})
for k in range(9):
    box((0.0, 0.25 + k * 0.32, 1.75), (0.6, 0.04, 0.05), IRON)
for xx in (-0.3, 0.3):
    box((xx, 1.5, 1.78), (0.05, 3.0, 0.05), IRON)
box((-1.6, 0.5, 1.2), (0.6, 1.0, 0.5), RED)     # пожарный ящик
box((-1.6, 1.3, 1.2), (0.62, 0.06, 0.52), IRON)
# --- Главный штрек на север ---
drift(-1.2, 1.2, -38.0, -2.0, 2.5, gaps={"e": [(-15.2, -12.8)], "w": [(-27.2, -24.8)]})
# кабель по стене
for z in range(-36, -2, 3):
    box((1.12, 2.1, z + 0.0), (0.03, 0.03, 3.0), CABLE)
# --- Восточная рассечка (z -15..-13) к камере взрывников ---
drift(1.2, 15.0, -15.2, -12.8, 2.3, along_z=False, walls=("n", "s"))
drift(15.0, 20.0, -17.0, -11.0, 2.8, sets=False, rails=False, walls=("n", "s", "e", "w"), gaps={"w": [(-15.2, -12.8)]})
# схрон: ящики, деревянный щит «Опасно ВВ», стол, лампа
for k, (x, z) in enumerate(((18.8, -16.2), (19.3, -15.5), (18.6, -12.0))):
    box((x, 0.25 + (0.5 if k == 1 else 0), z), (0.7, 0.5, 0.45), CRATE)
    box((x, 0.51 + (0.5 if k == 1 else 0), z), (0.72, 0.03, 0.47), IRON)
colbox((19.0, 0.5, -15.8), (1.3, 1.0, 1.4))
box((16.0, 0.75, -11.6), (1.4, 0.06, 0.7), TIMBER)
for xx in (15.4, 16.6):
    for zz in (-11.85, -11.35):
        box((xx, 0.37, zz), (0.06, 0.74, 0.06), TIMBER)
colbox((16.0, 0.4, -11.6), (1.4, 0.8, 0.7))
box((19.95, 1.6, -14.0), (0.04, 0.6, 0.9), RED)
# --- Западный тупик (z -27..-25) с сошедшей вагонеткой ---
drift(-10.0, -1.2, -27.2, -24.8, 2.2, along_z=False, walls=("n", "s", "w"))
box((-7.0, 0.5, -26.0), (0.9, 0.7, 1.3), IRON)          # вагонетка на боку
for zz in (-26.5, -25.5):
    cyl((-6.5, 0.2, zz), 0.18, 0.08, IRON, verts=10, axis="x")
colbox((-7.0, 0.5, -26.0), (0.9, 0.9, 1.3))
for _ in range(14):
    p = (rnd.uniform(-9.5, -5.5), 0.1, rnd.uniform(-27.0, -25.0))
    kit.sphere(ugms._nm("ore"), 1.0, ugms.g2b(p), ROCK2, scale=ugms.gsize((0.15, 0.1, 0.15)), segs=6, rings=4)
# --- Завал в конце штрека и лаз (кровля 1.1 м) ---
for _ in range(26):
    p = (rnd.uniform(-1.1, 1.1), rnd.uniform(0.2, 1.8), rnd.uniform(-38.4, -36.2))
    if -0.45 < p[0] < 0.45 and p[1] < 1.0:
        continue                          # лаз посередине у почвы
    kit.sphere(ugms._nm("rub"), 1.0, ugms.g2b(p), ROCK, scale=ugms.gsize((rnd.uniform(0.3, 0.6), rnd.uniform(0.25, 0.5), rnd.uniform(0.3, 0.6))), segs=8, rings=5)
colbox((-0.85, 1.2, -37.3), (0.7, 2.4, 2.2))
colbox((0.85, 1.2, -37.3), (0.7, 2.4, 2.2))
colbox((0.0, 1.8, -37.3), (1.2, 1.4, 2.2))
# --- Забой: последняя стоянка ---
drift(-2.0, 2.0, -44.0, -38.4, 2.3, sets=False, rails=False, walls=("w", "e", "n", "s"), gaps={"s": [(-1.2, 1.2)]})
box((-1.2, 0.12, -42.6), (0.8, 0.12, 1.9), CLOTH)                     # спальник
kit.sphere(ugms._nm("bag"), 1.0, ugms.g2b((-1.2, 0.22, -41.8)), CLOTH, scale=ugms.gsize((0.35, 0.12, 0.25)), segs=8, rings=5)
cyl((1.1, 0.18, -42.9), 0.08, 0.3, IRON, verts=8)                   # керосинка без огня
cyl((1.1, 0.38, -42.9), 0.05, 0.12, ICE, verts=8)
box((0.9, 0.05, -42.4), (0.21, 0.01, 0.3), PAPER)                   # записка
kit.sphere(ugms._nm("hat"), 1.0, ugms.g2b((0.3, 0.1, -43.2)), CLOTH, scale=ugms.gsize((0.16, 0.09, 0.16)), segs=8, rings=5)
for k in range(5):                                                   # зарубки на стойке — счёт ночей
    box((-1.9, 1.0 + k * 0.08, -40.0), (0.02, 0.012, 0.12), PAPER)

obj, img, tris = kit.finish("mine_horizon", OUT, res=2048, origin="keep", samples=24, pack=0.002)
kit.export(os.path.join(OUT, "mine_horizon.glb"), None)
lo = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "data", "mine_col.gd")
with open(dst, "w", encoding="utf8") as f:
    f.write("# Сгенерировано tools/blender/mine_horizon.py — коллизии горизонта штольни. Не править руками.\n")
    f.write("# Коробка: [cx, cy, cz, sx, sy, sz, yaw, tilt_x] от околоствольного двора.\n")
    f.write("const BOXES := [\n")
    for b in COL:
        f.write("\t[%s],\n" % ", ".join("%.3f" % v for v in b))
    f.write("]\n")
print("[OK] mine_horizon: %d tris, низ %.3f, коллизий %d" % (tris, lo, len(COL)))
