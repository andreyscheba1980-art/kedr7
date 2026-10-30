# «Кедр-7» — обстановка аэрологического корпуса (свет «внутри»): аппаратная, кабинет наблюдателя,
# радиорубка, архив-фотолаборатория, кладовая, тамбур, коридор, газогенераторная, низ башни, кабина.
# Положения — как в tools/blender/corpus.py и scripts/world/meteo_corpus.gd (PULT_POS, BARO_POS, STOVE_POS…).
# Запуск: blender --background --python corpus_furn.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl

OUT = sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
mk = lambda n, c, **k: kit.mat(n, c, **k)
M["desk"] = mk("f_desk", (0.30, 0.20, 0.12), rough=0.7, wear=0.5, dirt=0.3)
M["paper"] = mk("f_paper", (0.75, 0.72, 0.62), rough=0.9)
M["steel"] = mk("f_steel", (0.30, 0.33, 0.32), rough=0.5, wear=0.5, wear_col=(0.5, 0.5, 0.48))
M["panel"] = mk("f_panel", (0.20, 0.26, 0.24), rough=0.6, wear=0.4)
M["dial"] = mk("f_dial", (0.86, 0.83, 0.74), rough=0.5)
M["black"] = mk("f_black", (0.05, 0.05, 0.05), rough=0.6)
M["stove"] = mk("f_stove", (0.09, 0.09, 0.09), rough=0.7, wear=0.6, wear_col=(0.35, 0.2, 0.12))
M["blanket"] = mk("f_blanket", (0.28, 0.12, 0.08), rough=0.95, noise=0.3, noise_scale=30)
M["coat"] = mk("f_coat", (0.34, 0.25, 0.16), rough=0.95, noise=0.3, noise_scale=20)
M["felt"] = mk("f_felt", (0.22, 0.21, 0.2), rough=0.95, noise=0.3, noise_scale=30)
M["folder"] = [mk("f_fold%d" % i, c, rough=0.9, noise=0.35, noise_scale=30, wear=0.5, dirt=0.6, wear_col=(0.55, 0.5, 0.42))
               for i, c in enumerate(((0.34, 0.26, 0.17), (0.2, 0.23, 0.25), (0.4, 0.36, 0.27), (0.27, 0.15, 0.12), (0.3, 0.3, 0.24)))]
M["radiator"] = mk("f_rad", (0.48, 0.47, 0.42), rough=0.55, wear=0.6, dirt=0.7, wear_col=(0.42, 0.28, 0.18))
M["pipe"] = mk("f_pipe", (0.5, 0.5, 0.47), rough=0.5, wear=0.6, dirt=0.6, wear_col=(0.4, 0.27, 0.17))
M["conduit"] = mk("f_cond", (0.7, 0.7, 0.66), rough=0.7, dirt=0.5)
M["plafond"] = mk("f_plaf", (0.86, 0.85, 0.8), rough=0.3)
M["bakelite"] = mk("f_bak", (0.12, 0.08, 0.06), rough=0.35, wear=0.4)
M["mattress"] = mk("f_matr", (0.55, 0.5, 0.42), rough=0.95, noise=0.3, noise_scale=12, dirt=0.6)
M["locker"] = mk("f_locker", (0.32, 0.38, 0.34), rough=0.55, wear=0.6, dirt=0.5, wear_col=(0.45, 0.3, 0.2))
M["rubber"] = mk("f_rubber", (0.08, 0.08, 0.08), rough=0.9, noise=0.3, noise_scale=40)
M["balloon"] = mk("f_balloon", (0.82, 0.8, 0.72), rough=0.4, noise=0.15, noise_scale=6)
M["drum"] = mk("f_drum", (0.22, 0.26, 0.2), rough=0.6, wear=0.7, dirt=0.6, wear_col=(0.45, 0.28, 0.15))
M["brass"] = mk("f_brass", (0.6, 0.48, 0.24), rough=0.35, wear=0.5)
M["redlamp"] = mk("f_redlamp", (0.7, 0.08, 0.06), rough=0.3)
M["shell"] = mk("f_shell", (0.75, 0.70, 0.55), rough=0.6)
M["gasgen"] = mk("f_gasgen", (0.25, 0.30, 0.28), rough=0.6, wear=0.6, wear_col=(0.45, 0.28, 0.15))
M["coal"] = mk("f_coal", (0.05, 0.05, 0.05), rough=0.9, noise=0.4, noise_scale=40)
M["sack"] = mk("f_sack", (0.45, 0.40, 0.30), rough=0.95, noise=0.3, noise_scale=25)
M["can"] = mk("f_can", (0.55, 0.52, 0.45), rough=0.4, wear=0.5)
M["kero"] = mk("f_kero", (0.35, 0.10, 0.07), rough=0.5, wear=0.5)
M["glassbox"] = mk("f_glassbox", (0.55, 0.62, 0.66), rough=0.15)

FL = 0.45
CAB = 9.75
COL = []


def colbox(c, s, yaw=0.0, tilt=0.0):
    COL.append([round(v, 3) for v in (*c, *s, yaw, tilt)])


def solid(c, s, m, yaw=0.0, col=True):
    box(c, s, m, yaw=yaw)
    if col:
        colbox(c, s, yaw)


def table(x0, x1, z0, z1, h=0.76, y=FL, m=None, col=True):
    m = m or M["desk"]
    box(((x0 + x1) / 2, y + h - 0.02, (z0 + z1) / 2), (x1 - x0, 0.04, z1 - z0), m)
    for x in (x0 + 0.04, x1 - 0.04):
        for z in (z0 + 0.04, z1 - 0.04):
            box((x, y + (h - 0.04) / 2, z), (0.05, h - 0.04, 0.05), m)
    if col:
        colbox(((x0 + x1) / 2, y + h / 2, (z0 + z1) / 2), (x1 - x0, h, z1 - z0))


def desk(x0, x1, z0, z1, ped="x1", y=FL, h=0.76, col=True):
    """Конторский стол: толстая столешница со свесом, царга, тумба с тремя ящиками и ручками со стороны оператора."""
    w, d = x1 - x0, z1 - z0
    box(((x0 + x1) / 2, y + h - 0.02, (z0 + z1) / 2), (w + 0.03, 0.035, d + 0.03), M["desk"], bevel=0.006)
    along_z = d > w
    if along_z:   # тумба у одного торца по z, ящики смотрят в +x (оператор с востока)
        pz0, pz1 = (z1 - 0.42, z1 - 0.02) if ped == "z1" else (z0 + 0.02, z0 + 0.42)
        box(((x0 + x1) / 2, y + (h - 0.04) / 2, (pz0 + pz1) / 2), (w - 0.04, h - 0.04, pz1 - pz0), M["desk"], bevel=0.004)
        for k in range(3):
            yy = y + 0.14 + k * 0.21
            box((x1 - 0.005, yy, (pz0 + pz1) / 2), (0.012, 0.18, pz1 - pz0 - 0.05), M["desk"], bevel=0.003)
            box((x1 + 0.006, yy + 0.04, (pz0 + pz1) / 2), (0.012, 0.015, 0.09), M["brass"])
        lz = (z0 + 0.04) if ped == "z1" else (z1 - 0.04)
        for x in (x0 + 0.04, x1 - 0.04):
            box((x, y + (h - 0.04) / 2, lz), (0.045, h - 0.04, 0.045), M["desk"])
        box((x0 + 0.02, y + h - 0.12, (z0 + z1) / 2), (0.02, 0.12, d - 0.1), M["desk"])
    else:         # тумба у одного торца по x, ящики смотрят в +z
        px0, px1 = (x1 - 0.42, x1 - 0.02) if ped == "x1" else (x0 + 0.02, x0 + 0.42)
        box(((px0 + px1) / 2, y + (h - 0.04) / 2, (z0 + z1) / 2), (px1 - px0, h - 0.04, d - 0.04), M["desk"], bevel=0.004)
        for k in range(3):
            yy = y + 0.14 + k * 0.21
            box(((px0 + px1) / 2, yy, z1 - 0.005), (px1 - px0 - 0.05, 0.18, 0.012), M["desk"], bevel=0.003)
            box(((px0 + px1) / 2, yy + 0.04, z1 + 0.006), (0.09, 0.015, 0.012), M["brass"])
        lx = (x0 + 0.04) if ped == "x1" else (x1 - 0.04)
        for z in (z0 + 0.04, z1 - 0.04):
            box((lx, y + (h - 0.04) / 2, z), (0.045, h - 0.04, 0.045), M["desk"])
        box(((x0 + x1) / 2, y + h - 0.12, z0 + 0.02), (w - 0.1, 0.12, 0.02), M["desk"])
    if col:
        colbox(((x0 + x1) / 2, y + h / 2, (z0 + z1) / 2), (w, h, d))


def iron_bed(x, z, along_x=True, y=FL):
    """Железная койка: трубчатые спинки с прутьями, панцирь, ватный матрас, шерстяное одеяло, подушка."""
    L, W = 1.95, 0.8
    sx, sz = (L, W) if along_x else (W, L)
    for e in (-1, 1):
        ex, ez = (x + e * L / 2, z) if along_x else (x, z + e * L / 2)
        hh = 0.95 if e < 0 else 0.75
        for s2 in (-1, 1):
            px, pz = (ex, ez + s2 * W / 2) if along_x else (ex + s2 * W / 2, ez)
            cyl((px, y + hh / 2, pz), 0.018, hh, M["iron"], verts=8)
        for yy in (y + 0.3, y + hh - 0.03):
            box((ex, yy, ez), (0.03, 0.03, W) if along_x else (W, 0.03, 0.03), M["iron"])
        for k in range(6):
            o = -W / 2 + (k + 0.5) * W / 6
            px, pz = (ex, ez + o) if along_x else (ex + o, ez)
            cyl((px, y + 0.3 + (hh - 0.33) / 2, pz), 0.008, hh - 0.33, M["iron"], verts=6)
    box((x, y + 0.36, z), (sx - 0.04, 0.03, sz - 0.04), M["iron"])
    box((x, y + 0.44, z), (sx - 0.1, 0.13, sz - 0.08), M["mattress"], bevel=0.04)
    bx, bz = (x + 0.15, z) if along_x else (x, z + 0.15)
    box((bx, y + 0.515, bz), ((sx - 0.5, 0.03, sz - 0.02) if along_x else (sx - 0.02, 0.03, sz - 0.5)), M["blanket"], bevel=0.012)
    px, pz = (x - L / 2 + 0.3, z) if along_x else (x, z - L / 2 + 0.3)
    box((px, y + 0.54, pz), ((0.35, 0.1, 0.55) if along_x else (0.55, 0.1, 0.35)), M["paper"], bevel=0.04)
    colbox((x, y + 0.3, z), (sx, 0.6, sz))


def radiator(x, z, along_x, n=8, y=FL + 0.12):
    """Чугунная батарея под окном: секции-рёбра и подводка к полу."""
    step = 0.085
    for k in range(n):
        o = (k - (n - 1) / 2) * step
        px, pz = (x + o, z) if along_x else (x, z + o)
        box((px, y + 0.27, pz), ((0.06, 0.52, 0.12) if along_x else (0.12, 0.52, 0.06)), M["radiator"], bevel=0.015)
    for yy in (y + 0.05, y + 0.49):
        box((x, yy, z), ((n * step, 0.05, 0.05) if along_x else (0.05, 0.05, n * step)), M["radiator"])
    half = n * step / 2 + 0.06
    px, pz = (x - half, z) if along_x else (x, z - half)
    cyl((px, y + 0.05, pz), 0.02, 0.0001 + y + 0.1 - FL, M["pipe"], verts=8)


def plafond(x, y, z):
    """Потолочный плафон-«блюдце» на коротком штоке (свет даёт лампа в игре)."""
    cyl((x, y + 0.06, z), 0.015, 0.12, M["iron"], verts=8)
    cyl((x, y - 0.01, z), 0.2, 0.05, M["plafond"], verts=16, r2=0.12)
    cyl((x, y + 0.02, z), 0.205, 0.012, M["iron"], verts=16)


def pipe(a, b, r=0.025):
    kit.tube(ugms._nm("pp"), [ugms.g2b(a), ugms.g2b(b)], r, M["pipe"], 8)


def conduit(a, b):
    """Кабель-канал по стене: тонкий короб."""
    ax, ay, az = a
    bx, by, bz = b
    box(((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), (max(abs(bx - ax), 0.025), max(abs(by - ay), 0.025), max(abs(bz - az), 0.025)), M["conduit"])


def switch(x, y, z, nx, nz):
    """Выключатель/розетка — бакелит на деревянном подрозетнике."""
    box((x + nx * 0.008, y, z + nz * 0.008), ((0.016, 0.1, 0.1) if nx else (0.1, 0.1, 0.016)), M["desk"])
    box((x + nx * 0.02, y, z + nz * 0.02), ((0.014, 0.07, 0.07) if nx else (0.07, 0.07, 0.014)), M["bakelite"], bevel=0.01)


def locker(x, z, yaw, w=0.6, d=0.45, h=1.8, y=FL):
    """Металлический шкаф: две дверцы, жалюзи, ручки."""
    box((x, y + h / 2, z), (w, h, d), M["locker"], yaw=yaw, bevel=0.01)
    fx, fz = math.sin(yaw) * (d / 2 + 0.005), math.cos(yaw) * (d / 2 + 0.005)
    rx, rz = math.cos(yaw), -math.sin(yaw)
    box((x + fx, y + h / 2, z + fz), (0.006, h - 0.06, 0.006) if False else (0.008, h - 0.06, 0.008), M["black"], yaw=yaw)
    for s2 in (-1, 1):
        box((x + fx + rx * s2 * 0.06, y + h * 0.55, z + fz + rz * s2 * 0.06), (0.015, 0.12, 0.02), M["steel"], yaw=yaw)
        for k in range(4):
            box((x + fx + rx * s2 * w * 0.25, y + h - 0.2 - k * 0.04, z + fz + rz * s2 * w * 0.25), (w * 0.3, 0.012, 0.01), M["black"], yaw=yaw)
    colbox((x, y + h / 2, z), (w, h, d), yaw)


def bench(x0, x1, z, y=FL, d=0.32):
    box(((x0 + x1) / 2, y + 0.43, z), (x1 - x0, 0.04, d), M["desk"], bevel=0.006)
    for x in (x0 + 0.08, x1 - 0.08):
        box((x, y + 0.21, z), (0.05, 0.42, d - 0.06), M["desk"])
    box(((x0 + x1) / 2, y + 0.12, z), (x1 - x0 - 0.16, 0.04, 0.03), M["desk"])
    colbox(((x0 + x1) / 2, y + 0.22, z), (x1 - x0, 0.45, d))


def chair(x, z, yaw, y=FL):
    box((x, y + 0.45, z), (0.42, 0.04, 0.42), M["desk"], yaw=yaw)
    for dx in (-0.18, 0.18):
        for dz in (-0.18, 0.18):
            cx = x + dx * math.cos(yaw) + dz * math.sin(yaw)
            cz = z - dx * math.sin(yaw) + dz * math.cos(yaw)
            box((cx, y + 0.22, cz), (0.04, 0.45, 0.04), M["desk"])
    bx, bz = x - 0.19 * math.sin(yaw), z - 0.19 * math.cos(yaw)
    for yy, hh in ((y + 0.86, 0.1), (y + 0.66, 0.06)):
        box((bx, yy, bz), (0.4, hh, 0.025), M["desk"], yaw=yaw, bevel=0.005)
    for s2 in (-0.18, 0.18):
        box((bx + s2 * math.cos(yaw), y + 0.68, bz - s2 * math.sin(yaw)), (0.035, 0.46, 0.035), M["desk"], yaw=yaw)
    colbox((x, y + 0.35, z), (0.45, 0.7, 0.45), yaw)


def shelf(x0, x1, z0, z1, h, rows, y=FL, fill=None):
    """Стеллаж: стойки и полки; fill(i, x0, x1, z0, z1, y) — что стоит на полке i."""
    for x in (x0, x1):
        for z in (z0, z1):
            box((x, y + h / 2, z), (0.04, h, 0.04), M["steel"])
    for i in range(rows):
        yy = y + 0.12 + i * (h - 0.2) / (rows - 1)
        box(((x0 + x1) / 2, yy, (z0 + z1) / 2), (x1 - x0, 0.025, z1 - z0), M["steel"])
        if fill:
            fill(i, x0, x1, z0, z1, yy + 0.0125)
    colbox(((x0 + x1) / 2, y + h / 2, (z0 + z1) / 2), (x1 - x0, h, z1 - z0))


M["amber"] = mk("f_amber", (0.75, 0.55, 0.22), rough=0.3)
M["glassd"] = mk("f_glassd", (0.04, 0.05, 0.05), rough=0.15)


def sack(x, z, w, h, d, m, y=FL, tilt=0.0):
    """Мешок: пузатый, осевший книзу, горловина перехвачена бечёвкой (коробками со скруглением смотрелись кубами)."""
    kit.sphere(ugms._nm("sack"), 1.0, ugms.g2b((x, y + h * 0.4, z)), m, scale=ugms.gsize((w / 2, h * 0.5, d / 2)), segs=12, rings=8)
    cyl((x, y + h * 0.86, z), w * 0.16, h * 0.18, m, verts=8, r2=w * 0.1)
    cyl((x, y + h * 0.9, z), w * 0.12, 0.02, M["felt"], verts=8)
    cyl((x + 0.02, y + h * 0.99, z), w * 0.14, 0.05, m, verts=8, r2=w * 0.04)


def chassis(cx, cy, cz, w, h, face, knobs=3, meter=True, lamp=False):
    """Блок аппаратуры лицом в face (+x/−x/+z): панель, окно шкалы, ручки с рисками, стрелочный прибор, тумблеры, рукоятки."""
    fx, fz = {"-x": (-1, 0), "+x": (1, 0), "+z": (0, 1)}[face]
    along_z = fx != 0
    def at(u, v, out):
        return (cx + fx * out + (0 if along_z else u), cy + v, cz + fz * out + (u if along_z else 0))
    def sz(u, v, t):
        return (t, v, u) if along_z else (u, v, t)
    ax = "x" if along_z else "z"
    box(at(0, 0, 0.0), sz(w, h, 0.02), M["steel"], bevel=0.004)
    for e in (-1, 1):                                  # рукоятки по краям
        box(at(e * (w / 2 - 0.035), 0, 0.03), sz(0.018, h * 0.6, 0.018), M["iron"])
        box(at(e * (w / 2 - 0.035), h * 0.3, 0.018), sz(0.018, 0.018, 0.03), M["iron"])
        box(at(e * (w / 2 - 0.035), -h * 0.3, 0.018), sz(0.018, 0.018, 0.03), M["iron"])
    box(at(-w * 0.12, h * 0.18, 0.012), sz(w * 0.5, h * 0.24, 0.006), M["glassd"])     # окно шкалы
    box(at(-w * 0.12, h * 0.18, 0.016), sz(w * 0.46, 0.012, 0.004), M["amber"])
    for k in range(9):
        box(at(-w * 0.34 + k * w * 0.055, h * 0.24, 0.016), sz(0.003, 0.025, 0.004), M["dial"])
    for k in range(knobs):                              # ручки с белой риской
        u = -w * 0.3 + k * w * 0.22
        cyl(at(u, -h * 0.2, 0.025), 0.028, 0.03, M["black"], verts=12, axis=ax)
        box(at(u, -h * 0.2 + 0.015, 0.041), sz(0.004, 0.018, 0.003), M["dial"])
    if meter:                                           # стрелочный прибор
        cyl(at(w * 0.3, h * 0.14, 0.014), 0.062, 0.012, M["black"], verts=16, axis=ax)
        cyl(at(w * 0.3, h * 0.14, 0.02), 0.05, 0.004, M["dial"], verts=16, axis=ax)
        box(at(w * 0.3 - 0.012, h * 0.15, 0.024), sz(0.004, 0.045, 0.002), M["black"])
    for k in range(2):                                  # тумблеры
        box(at(w * 0.22 + k * 0.07, -h * 0.25, 0.016), sz(0.03, 0.02, 0.01), M["iron"])
        box(at(w * 0.22 + k * 0.07, -h * 0.22, 0.03), sz(0.006, 0.03, 0.006), M["steel"])
    box(at(-w * 0.12, -h * 0.38, 0.012), sz(w * 0.3, 0.03, 0.004), M["paper"])          # табличка
    if lamp:
        cyl(at(w * 0.38, -h * 0.25, 0.016), 0.012, 0.01, M["redlamp"], verts=8, axis=ax)


# --- Аппаратная ---------------------------------------------------------------------------
# Пульт анеморумбометра у северной стены: стойка, наклонная панель с двумя шкалами, самописец сбоку
PX, PZ = 91.7, -33.75
solid((PX, FL + 0.42, PZ), (1.6, 0.84, 0.6), M["panel"])
box((PX, FL + 1.0, PZ - 0.12), (1.6, 0.45, 0.06), M["panel"], yaw=0.0)
box((PX, FL + 0.845, PZ + 0.1), (1.62, 0.02, 0.42), M["black"])     # столешница пульта
chair(PX, PZ + 0.85, math.pi)
# Стол с барографом и термографом у перегородки коридора
BX, BZ = 94.3, -30.0
desk(BX - 0.3, BX + 0.3, BZ - 0.8, BZ + 0.8, ped="z1")
# Шкаф с запасными приборами, плакат-схема на стене
solid((90.85, FL + 1.0, -28.95), (0.75, 2.0, 0.55), M["desk"])
box((90.85, FL + 1.0, -28.66), (0.02, 1.9, 0.01), M["black"])
cyl((94.68, FL + 2.35, -29.3), 0.14, 0.04, M["dial"], verts=16, axis="x")

# --- Кабинет наблюдателя -----------------------------------------------------------------
desk(90.45, 91.2, -25.0, -23.4, ped="z0")
box((91.0, FL + 0.8, -24.2), (0.3, 0.03, 0.42), M["paper"], yaw=0.1)       # журнал
box((90.7, FL + 0.82, -23.7), (0.12, 0.06, 0.12), M["steel"])               # чернильница/лампа
cyl((90.7, FL + 1.0, -23.7), 0.07, 0.04, M["dial"], verts=10)
chair(91.6, -24.2, -math.pi / 2)
SX, SZ = 91.2, -21.3
cyl((SX, FL + 0.42, SZ), 0.28, 0.6, M["stove"], verts=14)
for a in range(4):
    ang = a * math.pi / 2 + 0.6
    box((SX + math.cos(ang) * 0.2, FL + 0.06, SZ + math.sin(ang) * 0.2), (0.04, 0.12, 0.04), M["stove"])
box((SX + 0.29, FL + 0.38, SZ), (0.02, 0.16, 0.2), M["stove"])
cyl((SX, (FL + 0.72 + 3.6) / 2, SZ), 0.065, 3.6 - FL - 0.72, M["stove"], verts=10)
box((SX + 0.15, FL + 0.01, SZ - 0.1), (0.7, 0.02, 0.6), M["steel"])
cyl((SX + 0.55, FL + 0.17, SZ - 0.45), 0.13, 0.34, M["black"], verts=10)
box((SX + 0.55, FL + 0.33, SZ - 0.45), (0.2, 0.02, 0.2), M["coal"])
colbox((SX, FL + 0.4, SZ), (0.6, 0.8, 0.6))
# Лежанка у южной стены
iron_bed(93.3, -20.85, along_x=True)
# Телефон ТА-57 на перегородке
TX, TY, TZ = 94.66, FL + 1.4, -24.6
box((TX, TY, TZ), (0.14, 0.2, 0.28), M["panel"])
box((TX - 0.03, TY + 0.12, TZ), (0.06, 0.05, 0.24), M["black"])
box((TX - 0.02, TY - 0.02, TZ + 0.17), (0.03, 0.08, 0.03), M["black"])

# --- Радиорубка --------------------------------------------------------------------------
# Стойка аппаратуры: каркас, цоколь, три блока лицом на запад, решётка вентиляции, кабели сверху
solid((98.32, FL + 0.95, -33.0), (0.5, 1.9, 1.6), M["panel"])
box((98.32, FL + 0.04, -33.0), (0.54, 0.08, 1.64), M["black"])
for e in (-1, 1):
    box((98.06, FL + 0.95, -33.0 + e * 0.79), (0.03, 1.9, 0.03), M["iron"])
for i in range(3):
    chassis(98.07, FL + 0.42 + i * 0.52, -33.0, 1.5, 0.46, "-x", knobs=4 - i % 2, meter=i != 1, lamp=i == 2)
for k in range(8):
    box((98.32, FL + 1.905, -33.5 + k * 0.14), (0.4, 0.008, 0.05), M["black"])
desk(96.6, 97.9, -34.05, -33.45, ped="x0")
# Приёмник «Метеорит» на столе лицом в комнату: корпус, лицевая панель со шкалой, верньер, рукоятки
box((97.2, FL + 0.9, -33.75), (0.6, 0.25, 0.35), M["steel"], bevel=0.01)
chassis(97.2, FL + 0.9, -33.565, 0.56, 0.22, "+z", knobs=2, meter=True)
cyl((97.2, FL + 0.84, -33.54), 0.04, 0.03, M["black"], verts=14, axis="z")      # верньер
for e in (-1, 1):
    cyl((97.2 + e * 0.31, FL + 0.9, -33.75), 0.012, 0.3, M["iron"], verts=6, axis="z")
box((96.9, FL + 0.8, -33.65), (0.2, 0.06, 0.15), M["black"])
chair(97.2, -32.9, math.pi)

# --- Архив / фотолаборатория -------------------------------------------------------------


def folders(i, x0, x1, z0, z1, y):
    k = 0
    z = z0 + 0.03
    while z < z1 - 0.1:
        w = 0.07 + 0.03 * ((k * 7) % 3)
        box(((x0 + x1) / 2, y + 0.16, z + w / 2), (x1 - x0 - 0.06, 0.32, w - 0.01), M["folder"][(k + i) % 4])
        z += w
        k += 1
        if k % 9 == 4:
            z += 0.12


shelf(98.2, 98.55, -29.2, -25.3, 2.2, 5, fill=folders)
table(96.6, 97.5, -26.0, -25.15)
for dz in (-0.2, 0.2):
    box((97.05, FL + 0.79, -25.58 + dz), (0.45, 0.03, 0.32), M["black"])
box((96.6, FL + 2.15, -27.2), (0.12, 0.12, 0.12), M["redlamp"])
for k in range(6):
    cyl((96.7 + (k % 3) * 0.25, FL + 0.06 + (k // 3) * 0.12, -28.9), 0.06, 0.4, M["paper"], verts=8, axis="x")

# --- Кладовая ----------------------------------------------------------------------------


M["tin"] = [mk("f_tin%d" % i, c, rough=0.45, wear=0.5) for i, c in enumerate(((0.55, 0.52, 0.45), (0.42, 0.16, 0.12), (0.2, 0.3, 0.22), (0.62, 0.55, 0.3)))]
M["bottle"] = mk("f_bottle", (0.18, 0.24, 0.14), rough=0.2)
M["crate"] = mk("f_crate", (0.42, 0.33, 0.2), rough=0.85, noise=0.35, noise_scale=18)


def stores(i, x0, x1, z0, z1, y):
    """Полка кладовой: тушёнка, сгущёнка, мешки, ящики, бутыли — вперемешку, с пустотами."""
    z = z0 + 0.06
    k = 0
    xc = (x0 + x1) / 2
    while z < z1 - 0.1:
        kind = (k * 7 + i * 3) % 6
        if kind in (0, 1):      # стопка банок
            for h in range(1 + (k + i) % 3):
                cyl((xc + (0.05 if k % 2 else -0.05), y + 0.05 + h * 0.1, z + 0.05), 0.045, 0.095, M["tin"][(k + h + i) % 4], verts=10)
            z += 0.13
        elif kind == 2:         # мешок
            box((xc, y + 0.11, z + 0.13), (0.26, 0.22 - 0.03 * (k % 2), 0.24), M["sack"], bevel=0.05)
            z += 0.28
        elif kind == 3:         # фанерный ящик с маркировкой
            box((xc, y + 0.09, z + 0.11), (0.24, 0.18, 0.2), M["crate"])
            z += 0.24
        elif kind == 4:         # бутыли
            for b in range(2):
                cyl((xc - 0.06 + b * 0.12, y + 0.12, z + 0.05), 0.04, 0.24, M["bottle"], verts=8)
            z += 0.12
        else:                   # пусто — полка не забита
            z += 0.18
        k += 1


shelf(98.2, 98.55, -24.6, -22.3, 1.9, 4, fill=stores)
for k, (x, z) in enumerate(((97.0, -20.85), (97.5, -20.8), (96.85, -21.35))):
    sack(x, z, 0.48, 0.55, 0.38, M["sack"] if k < 2 else M["coal"])
    colbox((x, FL + 0.25, z), (0.45, 0.5, 0.35))
for k in range(5):
    cyl((98.1, FL + 0.08 + k * 0.15, -21.5 + (k % 2) * 0.05), 0.07, 0.7, M["old"], verts=7, axis="z")
colbox((98.1, FL + 0.4, -21.5), (0.4, 0.8, 0.75))
for z in (-23.8, -23.4):
    box((97.0, FL + 0.25, z), (0.18, 0.5, 0.3), M["kero"])
    colbox((97.0, FL + 0.25, z), (0.18, 0.5, 0.3))

# --- Тамбур ------------------------------------------------------------------------------
box((92.0, FL + 1.75, -26.07), (1.6, 0.06, 0.06), M["desk"])
for k, x in enumerate((91.4, 92.0, 92.6)):
    box((x, FL + 1.7, -26.12), (0.04, 0.12, 0.08), M["black"])
    if k != 1:
        box((x, FL + 1.2, -26.2), (0.5, 1.0, 0.18), M["coat"], bevel=0.04)
for x in (91.3, 91.55):
    box((x, FL + 0.2, -26.35), (0.13, 0.4, 0.28), M["felt"])
bench(91.5, 92.9, -28.25)

# --- Коридор: огнетушитель, доска приказов -------------------------------------------------
cyl((96.15, FL + 0.6, -34.0), 0.08, 0.5, M["kero"], verts=10)
box((94.9, FL + 1.55, -29.6), (0.02, 0.6, 0.9), M["desk"])

# --- Газогенераторная ---------------------------------------------------------------------
for x in (101.4, 103.2):
    cyl((x, FL + 1.0, -37.7), 0.45, 2.0, M["gasgen"], verts=16)
    cyl((x, FL + 2.05, -37.7), 0.25, 0.12, M["steel"], verts=12)
    cyl((x + 0.35, FL + 1.3, -37.3), 0.08, 0.04, M["dial"], verts=10, axis="z")
    colbox((x, FL + 1.0, -37.7), (0.9, 2.0, 0.9))
kit.tube("gaspipe", [ugms.g2b((101.4, FL + 2.1, -37.7)), ugms.g2b((101.4, FL + 2.6, -37.7)), ugms.g2b((103.2, FL + 2.6, -37.7)), ugms.g2b((103.2, FL + 2.1, -37.7))], 0.04, M["steel"], 6)
kit.tube("gaspipe2", [ugms.g2b((102.3, FL + 2.6, -37.7)), ugms.g2b((102.3, FL + 2.6, -35.5)), ugms.g2b((104.5, FL + 2.6, -35.5))], 0.035, M["steel"], 6)
table(99.6, 100.6, -38.4, -37.2)
for k in range(3):   # банки с реагентом: крашеная жесть, крышка с ободом, бумажная этикетка, черпак
    cyl((99.85 + k * 0.3, FL + 0.89, -37.8), 0.09, 0.23, M["drum"] if k != 1 else M["kero"], verts=16)
    cyl((99.85 + k * 0.3, FL + 1.012, -37.8), 0.094, 0.018, M["iron"], verts=16)
    cyl((99.85 + k * 0.3, FL + 1.024, -37.8), 0.03, 0.012, M["iron"], verts=10)
    cyl((99.85 + k * 0.3, FL + 0.88, -37.8), 0.092, 0.09, M["paper"], verts=16)
box((100.4, FL + 0.785, -37.55), (0.22, 0.02, 0.06), M["iron"], yaw=0.5)
M["h2"] = mk("f_h2", (0.12, 0.24, 0.16), rough=0.5, wear=0.5, wear_col=(0.4, 0.3, 0.2))
M["h2band"] = mk("f_h2band", (0.6, 0.1, 0.08), rough=0.5)
for row in range(2):
    for k in range(3):
        cx, cy = 100.7 + k * 0.42, FL + 0.18 + row * 0.34   # от стены на 1 м: щель в 0.45 м была ловушкой
        cyl((cx, cy, -34.6), 0.13, 1.3, M["h2"], verts=12, axis="z")
        cyl((cx, cy, -34.6 + 0.5), 0.135, 0.06, M["h2band"], verts=12, axis="z")
        cyl((cx, cy, -34.6 - 0.7), 0.04, 0.1, M["steel"], verts=8, axis="z")
for x in (100.45, 101.85):
    box((x, FL + 0.35, -34.6), (0.05, 0.7, 1.2), M["steel"])
colbox((101.1, FL + 0.35, -34.6), (1.5, 0.7, 1.3))

# --- Низ башни: пожарный щит --------------------------------------------------------------
box((94.92, FL + 1.3, -36.0), (0.03, 1.0, 1.4), M["red"])
for k in range(3):
    box((94.96, FL + 1.1 + k * 0.25, -36.3 + k * 0.3), (0.04, 0.05, 0.5), M["black"])

# --- Кабина: стол с журналом шаров и секундомером, табурет ---------------------------------------
# у западной стены — дверь на балкон (север, x 95.1..95.9) и проход с марша вдоль северной стены свободны
table(94.95, 95.75, -37.3, -36.5, y=CAB)
box((95.3, CAB + 0.79, -36.68), (0.3, 0.02, 0.3), M["paper"])
cyl((95.62, CAB + 0.8, -36.62), 0.03, 0.02, M["dial"], verts=10)
solid((96.05, CAB + 0.22, -36.9), (0.35, 0.44, 0.35), M["desk"])

# =============================================================================================
# ДОКАЧКА: корпус не пустой и не «коробки» — отопление, свет, проводка, жилые и рабочие мелочи
# =============================================================================================
CEIL = 3.6
# Плафоны под лампами игры (MeteoCorpus: inner)
for (x, z) in ((92.6, -31.3), (92.6, -27.2), (92.6, -23.0), (95.6, -31.0), (95.6, -24.0), (97.5, -31.8), (97.5, -22.6)):
    plafond(x, CEIL - 0.08, z)
plafond(102.0, CEIL - 0.08, -36.2)
plafond(98.0, 3.38, -37.0)   # над восточной полосой, не над маршем B (голова проходила сквозь плафон)
# Батареи под окнами западной стены, южной и в газогенераторной; стояки
for z in (-32.8, -30.0, -21.8):   # под окном у z −24.2 стоит стол кабинета, под южным окном — койка
    radiator(90.5, z, along_x=False, n=9)
radiator(95.6, -20.5, along_x=True, n=6)
radiator(97.6, -20.5, along_x=True, n=6)
radiator(102.0, -38.5, along_x=True, n=10)
# Отопление: магистраль под потолком коридора и стояки
pipe((95.0, CEIL - 0.25, -34.0), (95.0, CEIL - 0.25, -20.6), 0.035)
pipe((95.12, CEIL - 0.25, -34.0), (95.12, CEIL - 0.25, -20.6), 0.03)
for z in (-33.0, -27.0, -21.0):
    pipe((95.0, CEIL - 0.25, z), (95.0, FL + 0.2, z), 0.022)
# Проводка: кабель-каналы по стенам коридора и комнат к выключателям у дверей
conduit((94.86, CEIL - 0.4, -34.0), (94.86, CEIL - 0.4, -20.6))
conduit((96.34, CEIL - 0.4, -34.0), (96.34, CEIL - 0.4, -20.6))
for (x, z, nx) in ((94.86, -31.0, -1), (94.86, -27.6, -1), (94.86, -22.4, -1), (96.34, -32.0, 1), (96.34, -27.0, 1), (96.34, -21.6, 1)):
    conduit((x, FL + 1.35, z), (x, CEIL - 0.4, z))
    switch(x, FL + 1.35, z, nx, 0)
# Аппаратная: стойка приборов у северной стены, кабели от пульта под потолок (к мачте), барабан с кабелем
RX = 93.55
box((RX, FL + 1.0, -33.85), (0.6, 2.0, 0.42), M["panel"], bevel=0.01)
colbox((RX, FL + 1.0, -33.85), (0.6, 2.0, 0.42))
for k in range(5):
    yy = FL + 0.35 + k * 0.33
    box((RX, yy, -33.63), (0.54, 0.28, 0.03), M["steel"], bevel=0.004)
    for j in range(3):
        cyl((RX - 0.17 + j * 0.17, yy + 0.03, -33.61), 0.035 if k % 2 else 0.02, 0.012, M["dial"] if k % 2 else M["black"], verts=10, axis="z")
    box((RX + 0.2, yy - 0.08, -33.61), (0.06, 0.03, 0.01), M["redlamp"] if k == 2 else M["black"])
for dx in (-0.5, 0.5):
    conduit((PX + dx, FL + 1.25, -33.98), (PX + dx, CEIL - 0.05, -33.98))
conduit((PX - 0.5, CEIL - 0.05, -33.98), (PX + 0.5, CEIL - 0.05, -33.98))
# Пульт: боковины, жалюзи на тумбе, рамки вокруг шкал (сами шкалы рисует игра)
for e in (-1, 1):
    box((PX + e * 0.81, FL + 0.62, PZ), (0.02, 1.24, 0.62), M["panel"], bevel=0.004)
for k in range(5):
    box((PX, FL + 0.18 + k * 0.08, PZ + 0.305), (1.3, 0.02, 0.01), M["black"])
for dx in (-0.35, 0.35):
    for (ox, oy, sx2, sy2) in ((0, 0.2, 0.42, 0.025), (0, -0.2, 0.42, 0.025), (0.2, 0, 0.025, 0.42), (-0.2, 0, 0.025, 0.42)):
        box((PX + dx + ox, FL + 1.02 + oy, PZ - 0.085), (sx2, sy2, 0.012), M["steel"])
# Шкаф с запасными приборами: дверцы со стеклом, карниз
for s2 in (-1, 1):
    box((90.85 + s2 * 0.18, FL + 1.2, -28.665), (0.33, 1.3, 0.012), M["glassbox"])
    box((90.85 + s2 * 0.02, FL + 0.95, -28.66), (0.015, 0.1, 0.02), M["brass"])
box((90.85, FL + 2.03, -28.95), (0.82, 0.06, 0.62), M["desk"], bevel=0.008)
# Кабинет: этажерка с книгами между окнами, тумбочка у койки, ватник, кочерга и дрова у печки
for k in range(4):
    yy = FL + 0.3 + k * 0.35
    box((90.58, yy, -22.95), (0.3, 0.025, 0.55), M["desk"])
    if k < 3:
        z = -23.18
        j = 0
        while z < -22.75:
            w = 0.035 + 0.015 * ((j * 5) % 3)
            box((90.6, yy + 0.13, z + w / 2), (0.2, 0.22 + 0.03 * (j % 2), w - 0.004), M["folder"][(j + k) % 5])
            z += w
            j += 1
for e in (-1, 1):
    box((90.58, FL + 0.82, -22.95 + e * 0.27), (0.3, 1.64, 0.025), M["desk"])
colbox((90.58, FL + 0.82, -22.95), (0.3, 1.64, 0.56))
box((94.45, FL + 0.28, -21.0), (0.4, 0.56, 0.38), M["desk"], bevel=0.006)
box((94.45, FL + 0.4, -20.805), (0.32, 0.18, 0.012), M["desk"])
cyl((94.5, FL + 0.6, -21.05), 0.04, 0.08, M["kero"], verts=10)
colbox((94.45, FL + 0.28, -21.0), (0.4, 0.56, 0.38))
for k in range(6):
    cyl((91.85 + (k % 3) * 0.12, FL + 0.06 + (k // 3) * 0.1, -20.75), 0.05, 0.42, M["old"], verts=7, axis="z")
box((91.62, FL + 0.45, -21.0), (0.02, 0.9, 0.02), M["iron"], tilt_x=0.25)
# Тамбур: резиновый коврик, веник, ведро, лопата у стены
box((90.85, FL + 0.006, -27.25), (0.8, 0.012, 1.0), M["rubber"])
box((91.0, FL + 0.55, -28.45), (0.03, 1.0, 0.03), M["old"], tilt_x=0.15)
box((91.0, FL + 0.12, -28.38), (0.2, 0.24, 0.08), M["sack"], tilt_x=0.15, bevel=0.03)
cyl((93.4, FL + 0.15, -28.3), 0.14, 0.3, M["can"], verts=12, r2=0.11)
# Коридор: лавка, огнетушитель на кронштейне, ведро с песком, щиток
bench(94.95, 96.25, -20.75)
box((96.3, FL + 1.1, -32.9), (0.05, 0.1, 0.1), M["iron"])
cyl((96.22, FL + 0.6, -34.0), 0.08, 0.5, M["kero"], verts=12)
cyl((96.22, FL + 0.9, -34.0), 0.03, 0.08, M["black"], verts=8)
cyl((95.0, FL + 0.16, -34.05), 0.14, 0.32, M["red"], verts=12, r2=0.11)
box((94.87, FL + 1.65, -26.2), (0.08, 0.5, 0.36), M["steel"], bevel=0.01)
box((94.83, FL + 1.65, -26.2), (0.01, 0.44, 0.3), M["black"])
# Радиорубка: вторая стойка, наушники, ввод антенны
box((98.32, FL + 0.7, -31.6), (0.5, 1.4, 0.8), M["panel"], bevel=0.008)
colbox((98.32, FL + 0.7, -31.6), (0.5, 1.4, 0.8))
box((98.32, FL + 0.04, -31.6), (0.54, 0.08, 0.84), M["black"])
for k in range(3):
    chassis(98.07, FL + 0.32 + k * 0.42, -31.6, 0.72, 0.38, "-x", knobs=2 + k % 2, meter=k != 0)
cyl((97.4, FL + 0.82, -33.85), 0.045, 0.03, M["black"], verts=10, axis="x")
cyl((97.55, FL + 0.82, -33.85), 0.045, 0.03, M["black"], verts=10, axis="x")
kit.tube(ugms._nm("hp"), [ugms.g2b((97.4, FL + 0.84, -33.85)), ugms.g2b((97.47, FL + 0.92, -33.85)), ugms.g2b((97.55, FL + 0.84, -33.85))], 0.008, M["black"], 6)
conduit((98.5, FL + 1.9, -33.98), (98.5, CEIL - 0.05, -33.98))
# Архив: фотоувеличитель, сушка плёнок на верёвке, коробки на полу
box((97.25, FL + 0.8, -25.4), (0.3, 0.04, 0.35), M["black"])
box((97.25, FL + 1.2, -25.5), (0.04, 0.8, 0.04), M["steel"])
box((97.25, FL + 1.35, -25.4), (0.16, 0.22, 0.2), M["black"], bevel=0.01)
cyl((97.25, FL + 1.2, -25.4), 0.04, 0.08, M["steel"], verts=10)
box((97.5, FL + 2.1, -27.2), (0.01, 0.01, 2.0), M["felt"])
for k in range(5):
    box((97.5, FL + 1.82, -28.0 + k * 0.38), (0.006, 0.55, 0.035), M["black"])
    box((97.5, FL + 2.09, -28.0 + k * 0.38), (0.012, 0.02, 0.02), M["steel"])
for k, (x, z) in enumerate(((96.75, -29.1), (97.1, -29.15), (96.9, -28.8))):
    box((x, FL + 0.15 + (0.3 if k == 2 else 0), z), (0.35, 0.3, 0.28), M["folder"][k], bevel=0.02)
colbox((96.95, FL + 0.3, -29.0), (0.7, 0.6, 0.45))
# Газогенераторная: аппараты — фланцы, манометры, вентили, коллектор; баки с реагентом; верстак; оболочки
for x in (101.4, 103.2):
    for yy in (FL + 0.15, FL + 1.0, FL + 1.85):
        cyl((x, yy, -37.7), 0.47, 0.05, M["steel"], verts=16)
    cyl((x, FL + 2.18, -37.7), 0.3, 0.16, M["steel"], verts=12, r2=0.12)
    cyl((x + 0.32, FL + 1.55, -37.38), 0.08, 0.03, M["dial"], verts=12, axis="z")
    cyl((x + 0.32, FL + 1.55, -37.36), 0.085, 0.012, M["brass"], verts=12, axis="z")
    cyl((x - 0.3, FL + 0.6, -37.3), 0.06, 0.06, M["red"], verts=10, axis="z")
    pipe((x, FL + 2.3, -37.7), (x, FL + 2.6, -37.7), 0.04)
for k in range(3):
    cyl((99.9 + k * 0.62, FL + 0.42, -35.6), 0.28, 0.84, M["drum"], verts=14)
    cyl((99.9 + k * 0.62, FL + 0.85, -35.6), 0.285, 0.02, M["iron"], verts=14)
    box((99.9 + k * 0.62, FL + 0.5, -35.31), (0.22, 0.14, 0.01), M["paper"])
colbox((100.52, FL + 0.43, -35.6), (1.85, 0.86, 0.58))
desk(103.0, 104.5, -34.55, -33.95, ped="x1")
box((103.5, FL + 0.8, -34.25), (0.3, 0.06, 0.12), M["steel"])
box((104.0, FL + 0.82, -34.2), (0.04, 0.04, 0.25), M["iron"], yaw=0.4)
for k in range(3):
    zz = -38.3 + k * 0.55
    box((104.54, FL + 2.2, zz), (0.04, 0.04, 0.04), M["iron"])
    # сложенная оболочка шара-пилота висит на крюке мешком: узко у крюка, раздута книзу
    box((104.54, FL + 2.14, zz), (0.01, 0.1, 0.01), M["felt"])
    cyl((104.38, FL + 1.55, zz), 0.17 - 0.02 * k, 1.1, M["balloon"], verts=12, r2=0.05)
    cyl((104.38, FL + 0.98, zz), 0.15 - 0.02 * k, 0.06, M["balloon"], verts=12, r2=0.17 - 0.02 * k)
# Низ башни: пожарное ведро и ящик с песком, кабели в пролёте марша, лампа
box((98.3, FL + 0.25, -35.2), (0.45, 0.5, 0.35), M["red"], bevel=0.01)
colbox((98.3, FL + 0.25, -35.2), (0.45, 0.5, 0.35))
box((98.3, FL + 0.51, -35.2), (0.47, 0.02, 0.37), M["iron"])
conduit((94.95, FL + 0.5, -38.5), (94.95, 9.7, -38.5))
conduit((95.05, FL + 0.5, -38.5), (95.05, 9.7, -38.5))

obj, img, tris = kit.finish("corpus_furn", OUT, res=4096, origin="keep", samples=24, pack=0.002, ao_blur=2)
kit.export(os.path.join(OUT, "corpus_furn.glb"), None)
lo = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "data", "corpus_col_furn.gd")
with open(dst, "w", encoding="utf8") as f:
    f.write("# Сгенерировано tools/blender/corpus_furn.py — коллизии обстановки корпуса. Не править руками.\n")
    f.write("# Коробка: [cx, cy, cz, sx, sy, sz, yaw, tilt_x] в координатах игры.\n")
    f.write("const BOXES := [\n")
    for b in COL:
        f.write("\t[%s],\n" % ", ".join("%.3f" % v for v in b))
    f.write("]\n")
print("[OK] corpus_furn: %d tris, низ %.3f, коллизий %d" % (tris, lo, len(COL)))
