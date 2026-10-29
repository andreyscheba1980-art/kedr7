# «Кедр-7» — аэрологический корпус УГМС с башней (docs/ПЛАН_МОБЫ_И_КОРПУС.md, часть 2).
# Г-образный кирпичный корпус, белёная штукатурка с обвалами до кирпича, плоская кровля с парапетом;
# из угла «Г» — кирпичная башня в три этажа с застеклённой кабиной и балконом. Дизельная пристройка
# во внутреннем углу, пожарные лестницы, мачта с анеморумбометром на крыше, антенны на кабине.
# Всё в координатах игры (ugms.py), модели — сразу на месте (origin="keep").
# Запуск: blender --background --python corpus.py -- <out_dir> <ext|int>
#   ext — фасады, кровли, крыльцо, пристройка, лестницы, мачта, антенны (снаружи; свет улицы);
#   int — внутренние стены, полы, потолки, перегородки, марши башни, кабина (свет корпуса).
# Коллизии обеих частей пишутся в scripts/data/corpus_col_<part>.gd (коробки: центр, размер, yaw, наклон).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, cone, prism, _rects, _uv, sign, text

OUT, PART = sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
EXT, INT = PART == "ext", PART == "int"
p_in = lambda *a, **k: ugms.painted(*a, grain=0.05, detail=3, streaks=False, **k)
# Без вертикальных потёков: ночью в PS1-свете они читались широкими полосами («зебра»); обвалы до кирпича — пятнами
M["plaster"] = ugms.painted("c_plaster", (0.74, 0.73, 0.68), under=(0.5, 0.42, 0.37), peel=0.36, scale=1.2, grain=0.2, detail=10, streaks=False)
M["grime"] = kit.mat("c_grime", (0.32, 0.3, 0.27), rough=0.95, noise=0.4, noise_scale=7, dirt=0.9)
M["ice"] = kit.mat("c_ice", (0.78, 0.86, 0.92), rough=0.15)
M["drift"] = kit.mat("c_drift", (0.6, 0.66, 0.74), rough=0.85, noise=0.06, noise_scale=3)
M["reveal"] = ugms.painted("c_reveal", (0.70, 0.69, 0.64), under=(0.44, 0.19, 0.12), peel=0.3, scale=5.0, streaks=False)
M["whitewash"] = p_in("c_white", (0.80, 0.79, 0.72), under=(0.58, 0.55, 0.48), peel=0.1, scale=3.0)
M["panel"] = p_in("c_panel", (0.27, 0.37, 0.43), under=(0.40, 0.38, 0.33), peel=0.08, scale=5.0)
# Масляная панель — у каждой комнаты своя (как красили в УГМС: аппаратная зелёная, кабинет — охра, склад — серый)
M["panel_green"] = p_in("c_pgreen", (0.25, 0.37, 0.31), under=(0.40, 0.38, 0.33), peel=0.1, scale=5.0)
M["panel_ochre"] = p_in("c_pochre", (0.46, 0.34, 0.2), under=(0.40, 0.38, 0.33), peel=0.1, scale=5.0)
M["panel_grey"] = p_in("c_pgrey", (0.38, 0.39, 0.37), under=(0.30, 0.28, 0.25), peel=0.14, scale=5.0)
M["panel_brown"] = p_in("c_pbrown", (0.3, 0.22, 0.16), under=(0.40, 0.38, 0.33), peel=0.1, scale=5.0)
M["skirt"] = kit.mat("c_skirt", (0.2, 0.13, 0.08), rough=0.7, wear=0.5, dirt=0.4)


def panel_at(x, z):
    """Какая панель у стены, что смотрит в комнату с точкой (x, z)."""
    if x < 94.8:
        return M["panel_green"] if z < -28.52 else (M["panel_grey"] if z < -25.93 else M["panel_ochre"])
    if x < 96.4:
        return M["panel"]
    if x < 99.0:
        return M["panel_green"] if z < -29.52 else (M["panel_brown"] if z < -24.92 else M["panel_grey"])
    return M["panel_grey"]


# Границы комнат вдоль стены: по ним режем полосу панели, чтобы краска менялась на углу комнаты
BREAKS = {0: [94.8, 96.4], 2: [-29.52, -28.52, -25.93, -24.92]}


def _split(lo, hi, axis):
    cuts = [lo] + [b for b in BREAKS[axis] if lo < b < hi] + [hi]
    return list(zip(cuts, cuts[1:]))


def _trim(axis, u0, u1, c, out, y0, y1):
    """Плинтус и отбивка поверх полосы панели (out — сдвиг от плоскости стены в комнату)."""
    if u1 - u0 < 0.05:
        return
    um = (u0 + u1) / 2
    for yy, hh, dd in ((y0 + 0.05, 0.1, 0.025), (y1, 0.04, 0.02)):
        sz = (u1 - u0, hh, dd) if axis == 0 else (dd, hh, u1 - u0)
        box(_uv(axis, um, c, yy, out), sz, M["skirt"])
M["floor"] = p_in("c_floor", (0.33, 0.17, 0.08), under=(0.30, 0.25, 0.19), peel=0.18, scale=3.0, boards="x", step=0.14)
M["cfloor"] = kit.mat("c_cfloor", (0.36, 0.35, 0.33), rough=0.95, noise=0.25, noise_scale=6, wear=0.3, dirt=0.8)
M["frame"] = kit.mat("c_frame", (0.16, 0.13, 0.10), rough=0.8, wear=0.4)
M["ply"] = kit.mat("c_ply", (0.50, 0.42, 0.30), rough=0.9, noise=0.3, noise_scale=12, wear=0.3, dirt=0.6)
M["rail"] = kit.mat("c_rail", (0.22, 0.24, 0.22), rough=0.6, wear=0.6, wear_col=(0.42, 0.24, 0.12))
M["soot"] = kit.mat("c_soot", (0.06, 0.05, 0.05), rough=0.9)
M["roofing"] = kit.mat("c_roofing", (0.12, 0.12, 0.12), rough=0.9, noise=0.3, noise_scale=5)
M["paint"] = kit.mat("c_paint", (0.18, 0.08, 0.06), rough=0.8)

# --- Размеры (игра: X восток, Z юг, Y вверх) ------------------------------------------------
T = 0.4                   # кирпичная стена
FL = 0.45                 # верх пола (корпус на цоколе)
CEIL = 3.6                # потолок корпуса
ROOF = 3.8                # верх плиты кровли
PAR = 4.2                 # верх парапета
DOOR_H = FL + 2.1
WIN_Y0, WIN_Y1 = FL + 0.9, FL + 2.1
# Длинное крыло
LX0, LX1, LZ0, LZ1 = 90.0, 99.0, -34.5, -20.0
# Башня и её этажи
TX0, TX1, TZ0, TZ1 = 94.5, 99.0, -39.0, -34.5
L1, L2, L3, CAB = FL, 3.75, 7.05, 9.75
SILL, GLASS1, CROOF = CAB + 0.9, CAB + 2.4, CAB + 2.6
# Короткое крыло (газогенераторная) и дизельная пристройка во внутреннем углу
SX0, SX1, SZ0, SZ1 = 99.0, 105.0, -39.0, -33.5
GX0, GX1, GZ0, GZ1, GH = 99.0, 102.4, -33.5, -30.5, 2.8
# Внутренние линии
CW0, CW1 = 94.8, 96.4     # перегородки коридора (оси)
DOOR_Z = (-27.75, -26.75) # вход в тамбур с запада

COL = []


def colbox(c, s, yaw=0.0, tilt=0.0):
    COL.append([round(v, 3) for v in (*c, *s, yaw, tilt)])


def rect_pts(r):
    return [(r[0], r[2]), (r[1], r[2]), (r[1], r[3]), (r[0], r[3])]


def slab(c, s, m, collide=True, yaw=0.0, tilt=0.0):
    box(c, s, m, yaw=yaw, tilt_x=tilt)
    if collide:
        colbox(c, s, yaw, tilt)


def wall(axis, u0, u1, c, n, y0, y1, holes=(), outer=True, out_y0=None, inner=(FL, CEIL), in_u=None, panel=True, collide=True, reveal=True):
    """Наружная стена: линия c — наружная плоскость, n — наружу. holes = [[u0, u1, y0, y1, kind]] (kind: 'door'|'win')."""
    hs = [h[:4] for h in holes]
    if EXT and outer:
        oy = y0 if out_y0 is None else out_y0
        for r in _rects(min(u0, u1), max(u0, u1), oy, y1, hs):
            prism(axis, c, n, rect_pts(r), 0.0, 0.03, M["plaster"])
        if reveal:
            for h in holes:
                hw, hh = h[1] - h[0], h[3] - h[2]
                mid = -n * T / 2
                S = (lambda su, sy, sd: (su, sy, sd) if axis == 0 else (sd, sy, su))
                for uu in (h[0] + 0.01, h[1] - 0.01):
                    box(_uv(axis, uu, c, (h[2] + h[3]) / 2, mid), S(0.02, hh, T), M["reveal"])
                box(_uv(axis, (h[0] + h[1]) / 2, c, h[3] - 0.01, mid), S(hw, 0.02, T), M["reveal"])
                if h[4] != "door":
                    box(_uv(axis, (h[0] + h[1]) / 2, c, h[2] + 0.01, mid), S(hw, 0.02, T), M["reveal"])
    if INT and inner:
        lo, hi = in_u if in_u else (min(u0, u1) + T, max(u0, u1) - T)
        ci = c - n * T
        if panel:
            for (a, b) in _split(lo, hi, axis):
                um = (a + b) / 2
                px, _, pz = _uv(axis, um, ci, 1.0, -n * 0.3)
                pm = panel_at(px, pz)
                for r in _rects(a, b, inner[0], inner[0] + 1.5, hs):
                    prism(axis, ci, -n, rect_pts(r), 0.0, 0.02, pm)
                    if r[2] <= inner[0] + 0.01 and r[3] >= inner[0] + 1.49:
                        _trim(axis, r[0], r[1], ci, -n * 0.03, inner[0], inner[0] + 1.5)
            for r in _rects(lo, hi, inner[0] + 1.5, inner[1], hs):
                prism(axis, ci, -n, rect_pts(r), 0.0, 0.02, M["whitewash"])
        else:
            for r in _rects(lo, hi, inner[0], inner[1], hs):
                prism(axis, ci, -n, rect_pts(r), 0.0, 0.02, M["whitewash"])
    if collide:
        doors = [h[:4] for h in holes if h[4] == "door"]
        for r in _rects(min(u0, u1), max(u0, u1), y0, y1, doors):
            cu, cy = (r[0] + r[1]) / 2, (r[2] + r[3]) / 2
            p = _uv(axis, cu, c, cy, -n * T / 2)
            colbox(p, (r[1] - r[0], r[3] - r[2], T) if axis == 0 else (T, r[3] - r[2], r[1] - r[0]))


def window(axis, u, c, n, w, y0, y1, boarded=False):
    """Окно в проёме: тёмная двойная рама со стеклом в глубине, отлив снаружи, подоконник внутри; или фанера."""
    S = (lambda su, sy, sd: (su, sy, sd) if axis == 0 else (sd, sy, su))
    hgt = y1 - y0
    yc = (y0 + y1) / 2
    if EXT:
        if boarded:
            box(_uv(axis, u, c, yc, n * 0.045), S(w + 0.12, hgt + 0.1, 0.03), M["ply"])
            for k in (-0.28, 0.28):
                box(_uv(axis, u, c, yc + k * hgt, n * 0.065), S(w + 0.2, 0.07, 0.02), M["old"])
        for depth in (0.12, 0.3):
            f = -n * depth
            for s in (-1, 1):
                box(_uv(axis, u + s * (w / 2 - 0.03), c, yc, f), S(0.06, hgt, 0.06), M["frame"])
            for yy in (y0 + 0.03, y1 - 0.03, y0 + hgt * 0.68):
                box(_uv(axis, u, c, yy, f), S(w, 0.06, 0.06), M["frame"])
            box(_uv(axis, u, c, yc, f), S(0.05, hgt, 0.05), M["frame"])
            box(_uv(axis, u, c, yc, f + n * 0.01), S(w - 0.06, hgt - 0.06, 0.008), M["glass"])
        box(_uv(axis, u, c, y0 - 0.03, n * 0.06), S(w + 0.1, 0.04, 0.16), M["iron"])
    if INT:
        box(_uv(axis, u, c, y0 - 0.02, -n * (T + 0.08)), S(w + 0.1, 0.04, 0.2), M["frame"])


def inner_floor(x0, x1, z0, z1, y, m, collide=True, t=0.1):
    if INT:
        box(((x0 + x1) / 2, y - t / 2, (z0 + z1) / 2), (x1 - x0, t, z1 - z0), m)
    if collide:
        colbox(((x0 + x1) / 2, y - t / 2, (z0 + z1) / 2), (x1 - x0, t, z1 - z0))


def ceiling(x0, x1, z0, z1, y):
    if INT:
        box(((x0 + x1) / 2, y + 0.01, (z0 + z1) / 2), (x1 - x0, 0.02, z1 - z0), M["whitewash"])


def partition(axis, u0, u1, c, holes=(), y0=FL, y1=CEIL, t=0.14):
    """Внутренняя перегородка: обе стороны — панель + побелка, проёмы дверей с наличником."""
    hs = [h[:4] for h in holes]
    for side in (-1, 1):
        if INT:
            for (a, b) in _split(min(u0, u1), max(u0, u1), axis):
                px, _, pz = _uv(axis, (a + b) / 2, c, 1.0, side * 0.3)
                pm = panel_at(px, pz)
                for r in _rects(a, b, y0, y0 + 1.5, hs):
                    prism(axis, c, side, rect_pts(r), t / 2, t / 2 + 0.01, pm)
                    if r[2] <= y0 + 0.01 and r[3] >= y0 + 1.49:
                        _trim(axis, r[0], r[1], c, side * (t / 2 + 0.02), y0, y0 + 1.5)
            for r in _rects(u0, u1, y0 + 1.5, y1, hs):
                prism(axis, c, side, rect_pts(r), t / 2, t / 2 + 0.01, M["whitewash"])
    S = (lambda su, sy, sd: (su, sy, sd) if axis == 0 else (sd, sy, su))
    for r in _rects(u0, u1, y0, y1, hs):
        colbox(_uv(axis, (r[0] + r[1]) / 2, c, (r[2] + r[3]) / 2, 0), S(r[1] - r[0], r[3] - r[2], t))
    if INT:
        # торцы перегородки: без них между двумя листами панели видна щель насквозь
        for uu in (u0, u1):
            box(_uv(axis, uu, c, (y0 + y1) / 2, 0), S(0.03, y1 - y0, t + 0.02), M["whitewash"])
        for h in holes:
            # торцы проёма и наличник; полотно двери — приоткрыто к стене
            for uu in (h[0], h[1]):
                box(_uv(axis, uu, c, (h[2] + h[3]) / 2, 0), S(0.02, h[3] - h[2], t + 0.02), M["reveal"])
                box(_uv(axis, uu + (-0.04 if uu == h[0] else 0.04), c, (h[2] + h[3]) / 2, 0), S(0.07, h[3] - h[2], t + 0.06), M["white"])
            box(_uv(axis, (h[0] + h[1]) / 2, c, h[3] + 0.04, 0), S(h[1] - h[0] + 0.15, 0.08, t + 0.06), M["white"])


# --- Длинное крыло -------------------------------------------------------------------------
W_WIN = 1.1
west_holes = [[-33.35, -32.25, WIN_Y0, WIN_Y1, "win"], [-30.55, -29.45, WIN_Y0, WIN_Y1, "win"],
              [DOOR_Z[0], DOOR_Z[1], FL, DOOR_H, "door"],
              [-24.75, -23.65, WIN_Y0, WIN_Y1, "win"], [-22.35, -21.25, WIN_Y0, WIN_Y1, "win"]]
wall(2, LZ0, LZ1, LX0, -1, 0.0, PAR, west_holes)
for zc, b in ((-32.8, False), (-30.0, False), (-24.2, False), (-21.8, True)):
    window(2, zc, LX0, -1, W_WIN, WIN_Y0, WIN_Y1, boarded=b)
south_holes = [[91.95, 93.05, WIN_Y0, WIN_Y1, "win"], [95.25, 95.95, FL + 1.1, FL + 2.0, "win"], [97.25, 97.95, FL + 1.2, FL + 1.9, "win"]]
wall(0, LX0, LX1, LZ1, +1, 0.0, PAR, south_holes)
window(0, 92.5, LZ1, +1, W_WIN, WIN_Y0, WIN_Y1)
window(0, 95.6, LZ1, +1, 0.7, FL + 1.1, FL + 2.0)
window(0, 97.6, LZ1, +1, 0.7, FL + 1.2, FL + 1.9)
east_holes = [[-27.75, -26.65, WIN_Y0, WIN_Y1, "win"], [-23.0, -22.2, FL + 1.2, FL + 1.9, "win"]]
wall(2, GZ1, LZ1, LX1, +1, 0.0, PAR, east_holes, in_u=(GZ1, LZ1 - T))
window(2, -27.2, LX1, +1, W_WIN, WIN_Y0, WIN_Y1, boarded=True)
window(2, -22.6, LX1, +1, 0.8, FL + 1.2, FL + 1.9)
# За пристройкой и коротким крылом: снаружи видна только верхняя часть стены
wall(2, LZ0, GZ1, LX1, +1, 0.0, PAR, (), out_y0=GH, in_u=(LZ0 + T, GZ1))
# Северная стена: открытый кусок до башни (окно аппаратной) и общая стена с башней (проём в башню)
wall(0, LX0, TX0, LZ0, -1, 0.0, PAR, [[91.65, 92.75, WIN_Y0, WIN_Y1, "win"]], in_u=(LX0 + T, TX0))
window(0, 92.2, LZ0, -1, W_WIN, WIN_Y0, WIN_Y1)
# Общая стена корпус/башня (z = −34.5): снаружи её нет, внутри две стороны; проём из коридора в башню
TOWER_DOOR = [95.0, 96.0, FL, DOOR_H, "door"]
if INT:
    for r in _rects(TX0, LX1 - T, FL, CEIL, [TOWER_DOOR[:4]]):
        prism(0, LZ0 + 0.0, +1, rect_pts(r), 0.0, 0.02, M["whitewash"])
    for r in _rects(TX0 + T, TX1 - T, L1, L1 + 3.0, [TOWER_DOOR[:4]]):
        prism(0, LZ0 - T, -1, rect_pts(r), 0.0, 0.02, M["whitewash"])
for r in _rects(TX0, TX1, 0.0, CEIL, [TOWER_DOOR[:4]]):
    colbox(((r[0] + r[1]) / 2, (r[2] + r[3]) / 2, LZ0 - T / 2), (r[1] - r[0], r[3] - r[2], T))
# Кровля длинного крыла: плита, снег, парапет изнутри и сверху (жесть)
if EXT:
    box(((LX0 + LX1) / 2, (CEIL + ROOF) / 2, (LZ0 + LZ1) / 2), (LX1 - LX0 - 0.02, ROOF - CEIL, LZ1 - LZ0 - 0.02), M["roofing"])
    box(((LX0 + LX1) / 2, ROOF + 0.06, (LZ0 + LZ1) / 2), (LX1 - LX0 - 2 * T - 0.1, 0.12, LZ1 - LZ0 - 2 * T - 0.1), M["snow"], bevel=0.04)
    for (a, b, c, n, ax) in ((LZ0, LZ1, LX0, -1, 2), (LX0, LX1, LZ1, +1, 0), (GZ0, LZ1, LX1, +1, 2), (LX0, TX0, LZ0, -1, 0)):
        lo, hi = min(a, b), max(a, b)
        prism(ax, c - n * T, -n, [(lo + T, ROOF), (hi - T, ROOF), (hi - T, PAR), (lo + T, PAR)], 0.0, 0.02, M["plaster"])
        mid = c - n * T / 2
        sz = (hi - lo, 0.04, T + 0.08) if ax == 0 else (T + 0.08, 0.04, hi - lo)
        box(_uv(ax, (lo + hi) / 2, c, PAR + 0.02, -n * T / 2), sz, M["iron"])
colbox(((LX0 + LX1) / 2, (CEIL + ROOF) / 2, (LZ0 + LZ1) / 2), (LX1 - LX0, ROOF - CEIL, LZ1 - LZ0))

# Перегородки и комнаты длинного крыла
IX0, IX1, IZ0, IZ1 = LX0 + T, LX1 - T, LZ0 + T, LZ1 - T
# у башни стена корпуса тоньше (общая с башней, z = LZ0) — перегородки коридора доводим до неё
partition(2, LZ0, IZ1, CW0, [[-31.8, -30.9, FL, DOOR_H, 0], [DOOR_Z[0], DOOR_Z[1], FL, DOOR_H, 0], [-23.5, -22.6, FL, DOOR_H, 0]])
partition(2, LZ0, IZ1, CW1, [[-32.5, -31.6, FL, DOOR_H, 0], [-27.6, -26.7, FL, DOOR_H, 0], [-22.0, -21.1, FL, DOOR_H, 0]])
partition(0, IX0, CW0 - 0.07, -28.52)
partition(0, IX0, CW0 - 0.07, -25.93)
partition(0, CW1 + 0.07, IX1, -29.52)
partition(0, CW1 + 0.07, IX1, -24.92)
for (x0, x1, z0, z1, m) in ((IX0, CW0, IZ0, -28.52, M["floor"]), (IX0, CW0, -28.52, -25.93, M["cfloor"]), (IX0, CW0, -25.93, IZ1, M["floor"]),
                            (CW0, CW1, IZ0, IZ1, M["floor"]), (CW1, IX1, IZ0, -29.52, M["floor"]), (CW1, IX1, -29.52, -24.92, M["floor"]),
                            (CW1, IX1, -24.92, IZ1, M["cfloor"])):
    inner_floor(x0, x1, z0, z1, FL, m)
ceiling(IX0, IX1, IZ0, IZ1, CEIL)
# Цоколь под полом (коллизия пола от земли до FL — чтобы не провалиться под корпус)
colbox(((LX0 + LX1) / 2, FL / 2 - 0.05, (LZ0 + LZ1) / 2), (LX1 - LX0, FL - 0.1, LZ1 - LZ0))

# --- Башня -------------------------------------------------------------------------------------
TW_TOP = SILL
slit = lambda u, y: [u - 0.2, u + 0.2, y - 0.5, y + 0.5, "win"]
wall(2, TZ0, TZ1, TX0, -1, 0.0, TW_TOP, [slit(-37.8, 2.4), slit(-37.8, 5.7)], inner=(L1, SILL), panel=False, in_u=(TZ0 + T, TZ1 - T))
wall(0, TX0, TX1, TZ0, -1, 0.0, TW_TOP, [slit(96.0, 4.0), slit(96.0, 7.3), [95.1, 95.9, CAB, SILL, "door"]], inner=(L1, SILL), panel=False)
wall(2, TZ0, TZ1, TX1, +1, 0.0, TW_TOP, [[-37.1, -36.1, FL, DOOR_H, "door"]], out_y0=PAR, inner=(L1, SILL), panel=False, in_u=(TZ0 + T, TZ1 - T))
if EXT:   # южная грань башни над кровлей корпуса
    prism(0, TZ1, +1, [(TX0, ROOF), (TX1, ROOF), (TX1, TW_TOP), (TX0, TW_TOP)], 0.0, 0.03, M["plaster"])
for (u, y) in ((-37.8, 2.4), (-37.8, 5.7)):     # бойницы у северного края — индекс станции по центру грани
    window(2, u, TX0, -1, 0.4, y - 0.5, y + 0.5)
for (u, y) in ((96.0, 4.0), (96.0, 7.3)):
    window(0, u, TZ0, -1, 0.4, y - 0.5, y + 0.5)
colbox(((TX0 + TX1) / 2, (TW_TOP + CEIL) / 2, TZ1 - T / 2), (TX1 - TX0, TW_TOP - CEIL, T))
# Индекс станции на западной грани башни
if EXT:
    text("23711", 0.75, (TX0 - 0.04, 8.55, -36.75), M["paint"], yaw=-math.pi / 2)
# Внутри башни: пол, марши «зигзагом» (A вдоль западной стены на север, B обратно на юг), полосы этажей
BI_X0, BI_X1, BI_Z0, BI_Z1 = TX0 + T, TX1 - T, TZ0 + T, TZ1 - T   # 94.9..98.6, −38.6..−34.9
AX0, AX1, BX0, BX1 = BI_X0, BI_X0 + 1.2, BI_X0 + 1.2, BI_X0 + 2.4
RUN0, RUN1 = -35.6, -37.4
inner_floor(BI_X0, BI_X1, BI_Z0, BI_Z1, L1, M["cfloor"])
colbox(((TX0 + TX1) / 2, FL / 2 - 0.05, (TZ0 + TZ1) / 2), (TX1 - TX0, FL - 0.1, TZ1 - TZ0))


def ramp(x0, x1, za, ya, zb, yb):
    """Марш: пандус-коллизия + ступени для глаза (сталь, рифлёный лист) и косоуры."""
    ln = math.hypot(zb - za, yb - ya)
    tilt = -math.atan((yb - ya) / (zb - za))     # +: дальний (+Z) край ниже
    zc, yc = (za + zb) / 2, (ya + yb) / 2
    colbox(((x0 + x1) / 2, yc - 0.05, zc), (x1 - x0, 0.1, ln), 0.0, tilt)
    if INT:
        n = max(2, int(abs(yb - ya) / 0.19))
        for i in range(n):
            k = (i + 0.5) / n
            box(((x0 + x1) / 2, ya + (yb - ya) * k - 0.02, za + (zb - za) * k), (x1 - x0 - 0.06, 0.05, abs(zb - za) / n + 0.02), M["iron"])
        for xx in (x0 + 0.03, x1 - 0.03):
            box((xx, yc - 0.12, zc), (0.05, 0.22, ln), M["rail"], tilt_x=tilt)


def railing(x0, z0, x1, z1, y, h=1.0):
    ln = math.hypot(x1 - x0, z1 - z0)
    yaw = math.atan2(x1 - x0, z1 - z0)
    if INT:
        for k in (0.0, 1.0):
            box((x0 + (x1 - x0) * k, y + h / 2, z0 + (z1 - z0) * k), (0.04, h, 0.04), M["rail"])
        for hh in (h, h * 0.5):
            box(((x0 + x1) / 2, y + hh, (z0 + z1) / 2), (0.04, 0.04, ln), M["rail"], yaw=yaw)
    colbox(((x0 + x1) / 2, y + h / 2, (z0 + z1) / 2), (0.06, h, ln), yaw)


for lv in (L1, L2):
    mid = lv + (L2 - L1) / 2
    ramp(AX0, AX1, RUN0, lv, RUN1, mid)                     # A: на север
    inner_floor(BI_X0, BX1, BI_Z0, RUN1, mid, M["cfloor"])  # площадка в северо-западном углу
    ramp(BX0, BX1, RUN1, mid, RUN0, lv + (L2 - L1))         # B: на юг
    top = lv + (L2 - L1)
    inner_floor(BI_X0, BI_X1, RUN0, BI_Z1, top, M["cfloor"])    # полоса этажа у южной стены
    if top < L3:
        inner_floor(BX1, BI_X1, BI_Z0, RUN0, top, M["cfloor"])   # восточная полоса (на этаже 2)
    if top < L3:
        railing(BX1 + 0.03, RUN0, BX1 + 0.03, BI_Z0, top)   # восточная полоса — от пролёта марша B
# Последний марш — прямой вдоль восточной стены с этажа 3 в кабину
EX0, EX1 = BX1 + 0.05, BI_X1
ramp(EX0, EX1, RUN0, L3, BI_Z0 + 0.05, CAB)

# --- Кабина: подоконная стена, остекление, балкон, кровля ----------------------------------
# пол кабины — без проёма над последним маршем
inner_floor(BI_X0, EX0, BI_Z0, BI_Z1, CAB, M["floor"])
inner_floor(EX0, BI_X1, RUN0, BI_Z1, CAB, M["floor"])
railing(EX0 - 0.02, RUN0, EX0 - 0.02, BI_Z0 + 1.0, CAB)   # проход с марша в кабину — 1 м (было 0.6: капсулу игрока заклинивало)
railing(EX0, RUN0 + 0.02, BI_X1, RUN0 + 0.02, CAB)
BAL = 0.9
# Плита балкона — четыре полосы вокруг башни (внутри башни — лестничный проём, сплошная плита его перекрывала)
_by = CAB - 0.08
BAL_STRIPS = [(((TX0 + TX1) / 2, _by, TZ0 - BAL / 2), (TX1 - TX0 + 2 * BAL, 0.14, BAL)),
              (((TX0 + TX1) / 2, _by, TZ1 + BAL / 2), (TX1 - TX0 + 2 * BAL, 0.14, BAL)),
              ((TX0 - BAL / 2, _by, (TZ0 + TZ1) / 2), (BAL, 0.14, TZ1 - TZ0)),
              ((TX1 + BAL / 2, _by, (TZ0 + TZ1) / 2), (BAL, 0.14, TZ1 - TZ0))]
if EXT:
    # Балкон-обход: плита, ограждение
    for (c, sz) in BAL_STRIPS:
        box(c, sz, M["concrete"])
        box((c[0], c[1] + 0.09, c[2]), (sz[0] - 0.05, 0.05, sz[2] - 0.05), M["snow"])
    for (a, b, c, ax) in ((TX0 - BAL, TX1 + BAL, TZ0 - BAL, 0), (TX0 - BAL, TX1 + BAL, TZ1 + BAL, 0), (TZ0 - BAL, TZ1 + BAL, TX0 - BAL, 2), (TZ0 - BAL, TZ1 + BAL, TX1 + BAL, 2)):
        L = b - a
        for hh in (1.0, 0.5):
            box(_uv(ax, (a + b) / 2, c, CAB + hh, 0), (L, 0.04, 0.04) if ax == 0 else (0.04, 0.04, L), M["rail"])
        k = 0.0
        while k <= L + 0.01:
            box(_uv(ax, a + k, c, CAB + 0.5, 0), (0.04, 1.0, 0.04), M["rail"])
            k += L / max(1, round(L / 1.1))
for (a, b, c, ax) in ((TX0 - BAL, TX1 + BAL, TZ0 - BAL, 0), (TX0 - BAL, TX1 + BAL, TZ1 + BAL, 0), (TZ0 - BAL, TZ1 + BAL, TX0 - BAL, 2), (TZ0 - BAL, TZ1 + BAL, TX1 + BAL, 2)):
    colbox(_uv(ax, (a + b) / 2, c, CAB + 0.55, 0), (b - a, 1.1, 0.08) if ax == 0 else (0.08, 1.1, b - a))
for (c, sz) in BAL_STRIPS:
    colbox(c, sz)
# Остекление: стойки и ригели, стёкла; дверь на балкон с севера (95.1..95.9)
CAB_DOOR = (95.1, 95.9)
for (a, b, c, n, ax) in ((TX0, TX1, TZ0, -1, 0), (TX0, TX1, TZ1, +1, 0), (TZ0, TZ1, TX0, -1, 2), (TZ0, TZ1, TX1, +1, 2)):
    L = b - a
    nseg = 4
    if EXT:
        for i in range(nseg + 1):
            u = a + L * i / nseg
            box(_uv(ax, u, c, (SILL + GLASS1) / 2, -n * 0.05), (0.08, GLASS1 - SILL, 0.1) if ax == 0 else (0.1, GLASS1 - SILL, 0.08), M["frame"])
        for yy in (SILL, SILL + 0.85, GLASS1):
            box(_uv(ax, (a + b) / 2, c, yy, -n * 0.05), (L, 0.07, 0.1) if ax == 0 else (0.1, 0.07, L), M["frame"])
        box(_uv(ax, (a + b) / 2, c, (SILL + GLASS1) / 2, -n * 0.05), (L - 0.04, GLASS1 - SILL, 0.01) if ax == 0 else (0.01, GLASS1 - SILL, L - 0.04), M["glass"])
    is_door_side = ax == 0 and c == TZ0
    holes = [[CAB_DOOR[0], CAB_DOOR[1], CAB, GLASS1]] if is_door_side else []
    for r in _rects(a, b, CAB, GLASS1, holes):
        colbox(_uv(ax, (r[0] + r[1]) / 2, c, (r[2] + r[3]) / 2, -n * 0.1), (r[1] - r[0], r[3] - r[2], 0.2) if ax == 0 else (0.2, r[3] - r[2], r[1] - r[0]))
# Дверь на балкон: застеклённая, распахнута наружу к стене; подоконная доска по периметру кабины
if EXT:
    box((CAB_DOOR[0] + 0.03, (CAB + GLASS1) / 2, TZ0 - 0.42), (0.05, GLASS1 - CAB - 0.05, 0.8), M["door"])
if INT:
    for (a, b, c, n, ax) in ((TX0, TX1, TZ0, -1, 0), (TX0, TX1, TZ1, +1, 0), (TZ0, TZ1, TX0, -1, 2), (TZ0, TZ1, TX1, +1, 2)):
        holes = [[CAB_DOOR[0], CAB_DOOR[1]]] if (ax == 0 and c == TZ0) else []
        for r in _rects(a + T, b - T, 0, 1, [h + [0, 2] for h in holes]):
            box(_uv(ax, (r[0] + r[1]) / 2, c, SILL + 0.02, -n * (T / 2 + 0.05)), (r[1] - r[0], 0.04, T + 0.12) if ax == 0 else (T + 0.12, 0.04, r[1] - r[0]), M["frame"])
# Кровля кабины с вылетом, антенны и решётка приёма радиозонда
if EXT:
    box(((TX0 + TX1) / 2, CROOF + 0.1, (TZ0 + TZ1) / 2), (TX1 - TX0 + 0.8, 0.2, TZ1 - TZ0 + 0.8), M["concrete"])
    box(((TX0 + TX1) / 2, CROOF + 0.24, (TZ0 + TZ1) / 2), (TX1 - TX0 + 0.5, 0.1, TZ1 - TZ0 + 0.5), M["snow"], bevel=0.04)
    AXC, AZC = 96.0, -36.2
    cyl((AXC, CROOF + 1.0, AZC), 0.06, 1.8, M["rail"], verts=8)
    box((AXC, CROOF + 1.95, AZC), (0.5, 0.12, 0.3), M["rail"])
    # решётка: рамка 1.8×1.1 с вертикальными вибраторами
    RX, RY, RZ = AXC, CROOF + 2.6, AZC
    for dy in (-0.55, 0.55):
        box((RX, RY + dy, RZ), (1.8, 0.04, 0.04), M["rail"])
    for k in range(7):
        box((RX - 0.9 + k * 0.3, RY, RZ), (0.03, 1.1, 0.03), M["rail"])
    for k in range(6):
        box((RX - 0.75 + k * 0.3, RY, RZ - 0.25), (0.02, 0.9, 0.02), M["iron"])
    box((RX, RY, RZ - 0.12), (0.06, 0.06, 0.26), M["rail"])
    for (x, z, h) in ((98.4, -38.4, 2.6), (95.0, -34.9, 1.8)):
        cyl((x, CROOF + 0.3 + h / 2, z), 0.02, h, M["iron"], verts=6)
    # проводка с кабины вниз к радиорубке
    kit.tube("feed", [ugms.g2b((98.7, CROOF, -36.0)), ugms.g2b((99.15, CROOF - 0.5, -35.9)), ugms.g2b((99.15, ROOF + 0.5, -35.9))], 0.02, M["iron"], 5)

# --- Пожарная лестница на башню (север) и на кровлю (юг) ---------------------------------
def fire_ladder(x, z, nz, y0, y1, hoops_from=None):
    """Скоба-лестница у стены: тетивы, ступени через 0.3, кольца ограждения выше hoops_from."""
    if not EXT:
        return
    off = nz * 0.2
    for s in (-0.25, 0.25):
        box((x + s, (y0 + y1) / 2, z + off), (0.05, y1 - y0, 0.05), M["rail"])
        box((x + s, y0 + 0.5, z + nz * 0.08), (0.04, 0.04, 0.25), M["rail"])
    y = y0 + 0.3
    while y < y1:
        box((x, y, z + off), (0.5, 0.03, 0.03), M["rail"])
        y += 0.3
    if hoops_from is not None:
        y = hoops_from
        while y < y1:
            for s in (-1, 1):
                box((x + s * 0.38, y + 0.0, z + off + nz * 0.3), (0.03, 0.03, 0.62), M["rail"])
            box((x, y, z + off + nz * 0.62), (0.8, 0.03, 0.03), M["rail"])
            y += 0.9
        for s in (-1, 0, 1):
            box((x + s * 0.38, (hoops_from + y1) / 2, z + off + nz * (0.62 if s == 0 else 0.3)), (0.025, y1 - hoops_from, 0.025), M["rail"])


fire_ladder(97.8, TZ0, -1, 0.0, CAB + 1.0, hoops_from=2.4)
fire_ladder(98.2, LZ1, +1, 0.0, PAR + 0.9)

# --- Мачта с анеморумбометром и флюгером на кровле -----------------------------------------
MAST_X, MAST_Z = 93.2, -31.5
if EXT:
    cyl((MAST_X, ROOF + 2.0, MAST_Z), 0.05, 4.0, M["rail"], verts=8)
    for (dx, dz) in ((1.2, 0.0), (-0.6, 1.0), (-0.6, -1.0)):
        kit.tube("guy", [ugms.g2b((MAST_X, ROOF + 3.4, MAST_Z)), ugms.g2b((MAST_X + dx, ROOF + 0.1, MAST_Z + dz))], 0.008, M["iron"], 4)
    # анеморумбометр: датчик-«пропеллер» с хвостовиком
    box((MAST_X, ROOF + 4.1, MAST_Z), (0.12, 0.12, 0.6), M["white"])
    box((MAST_X, ROOF + 4.15, MAST_Z + 0.42), (0.02, 0.3, 0.25), M["white"])
    for a in range(4):
        ang = a * math.pi / 2
        box((MAST_X + math.cos(ang) * 0.15, ROOF + 4.1 + math.sin(ang) * 0.15, MAST_Z - 0.33), (0.06, 0.32, 0.02), M["iron"], tilt_z=ang)
    # флюгер Вильда на перекладине
    box((MAST_X, ROOF + 3.3, MAST_Z), (0.9, 0.04, 0.04), M["rail"])
    cyl((MAST_X + 0.45, ROOF + 3.55, MAST_Z), 0.02, 0.5, M["rail"], verts=6)
    box((MAST_X + 0.45, ROOF + 3.85, MAST_Z), (0.02, 0.3, 0.2), M["white"])
    box((MAST_X + 0.45, ROOF + 3.85, MAST_Z - 0.35), (0.02, 0.14, 0.5), M["rail"])
colbox((MAST_X, ROOF + 1.0, MAST_Z), (0.2, 2.0, 0.2))

# --- Короткое крыло: газогенераторная --------------------------------------------------------
wall(0, SX0, SX1, SZ0, -1, 0.0, PAR, [[100.6, 101.4, FL + 2.0, FL + 2.6, "win"], [103.1, 103.9, FL + 2.0, FL + 2.6, "win"]], in_u=(SX0, SX1 - T), panel=False)
window(0, 101.0, SZ0, -1, 0.8, FL + 2.0, FL + 2.6)
window(0, 103.5, SZ0, -1, 0.8, FL + 2.0, FL + 2.6, boarded=True)
GG_DOOR = [-36.85, -35.65, FL, FL + 2.3, "door"]
wall(2, SZ0, SZ1, SX1, +1, 0.0, PAR, [GG_DOOR], panel=False)
wall(0, SX0, SX1, SZ1, +1, 0.0, PAR, [[103.6, 104.4, FL + 2.0, FL + 2.6, "win"]], out_y0=0.0, in_u=(SX0 + T, SX1 - T), panel=False)
window(0, 104.0, SZ1, +1, 0.8, FL + 2.0, FL + 2.6)
if EXT:
    # Двустворчатые ворота газогенераторной (закрыты) и бетонный пандус
    for s in (0, 1):
        z0 = GG_DOOR[0] + s * 0.6
        box((SX1 + 0.03, (FL + GG_DOOR[3]) / 2, z0 + 0.3), (0.05, GG_DOOR[3] - FL - 0.04, 0.58), M["door"])
    box((SX1 + 0.7, FL / 2, -36.25), (1.4, FL, 1.8), M["concrete"])
    sign((SX1 + 0.03, FL + 1.3, -37.4), math.pi / 2, ["ВОДОРОД", "Огнеопасно!"], M, w=0.5, h=0.3, size=0.06)
    box(((SX0 + SX1) / 2, (CEIL + ROOF) / 2, (SZ0 + SZ1) / 2), (SX1 - SX0, ROOF - CEIL, SZ1 - SZ0), M["roofing"])
    box(((SX0 + SX1) / 2 + 0.2, ROOF + 0.06, (SZ0 + SZ1) / 2), (SX1 - SX0 - 2 * T, 0.12, SZ1 - SZ0 - 2 * T), M["snow"], bevel=0.04)
    for (a, b, c, n, ax) in ((SX0, SX1, SZ0, -1, 0), (SZ0, SZ1, SX1, +1, 2), (SX0, SX1, SZ1, +1, 0)):
        box(_uv(ax, (a + b) / 2, c, PAR + 0.02, -n * T / 2), (b - a, 0.04, T + 0.08) if ax == 0 else (T + 0.08, 0.04, b - a), M["iron"])
colbox(((SX0 + SX1) / 2, (CEIL + ROOF) / 2, (SZ0 + SZ1) / 2), (SX1 - SX0, ROOF - CEIL, SZ1 - SZ0))
inner_floor(SX0 + T, SX1 - T, SZ0 + T, SZ1 - T, FL, M["cfloor"])
ceiling(SX0 + T, SX1 - T, SZ0 + T, SZ1 - T, CEIL)
colbox(((SX0 + SX1) / 2, FL / 2 - 0.05, (SZ0 + SZ1) / 2), (SX1 - SX0, FL - 0.1, SZ1 - SZ0))

# --- Фасад: водостоки, сосульки, переметы снега у стен, грязь у цоколя, светильник, кабель ввода ---
def drainpipe(x, z, top=PAR, ox=0.0, oz=0.0):
    """Водосточная труба: воронка под парапетом, колено, колено внизу на отмостку."""
    cyl((x + ox, (top - 0.3 + 0.3) / 2, z + oz), 0.055, top - 0.3 - 0.3, M["iron"], verts=8)
    cyl((x + ox, top - 0.2, z + oz), 0.12, 0.2, M["iron"], verts=8, r2=0.06)
    for k in range(5):
        box((x + ox * 0.6, 0.6 + k * (top - 1.2) / 4, z + oz * 0.6), (0.14 if not oz else 0.03, 0.03, 0.03 if not oz else 0.14), M["iron"])
    cyl((x + ox * 1.5, 0.22, z + oz * 1.5), 0.055, 0.25, M["iron"], verts=8)


def icicles(axis, u0, u1, c, out, y, seed):
    import random
    rnd = random.Random(seed)
    u = u0 + 0.1
    while u < u1 - 0.1:
        L = rnd.uniform(0.08, 0.45) if rnd.random() < 0.7 else rnd.uniform(0.45, 0.8)
        x, _, z = _uv(axis, u, c, 0, out)
        cone((x, y, z), (x, y - L, z), 0.02 + L * 0.05, M["ice"], verts=5)
        u += rnd.uniform(0.12, 0.5)


def drift(axis, u0, u1, c, out, h=0.35, d=0.7):
    """Перемёт снега у стены: цепочка сплюснутых бугров разной длины и высоты, наполовину в земле."""
    import random
    rnd = random.Random(int(u0 * 100 + c))
    u = u0
    while u < u1:
        L = min(rnd.uniform(2.0, 3.6), u1 - u + 0.4)
        hh = h * rnd.uniform(0.45, 0.8)
        dd = d * rnd.uniform(0.75, 1.2)
        x, _, z = _uv(axis, u + L / 2, c, 0, out * dd * 0.35)
        sc = (L / 2, hh, dd / 2) if axis == 0 else (dd / 2, hh, L / 2)
        kit.sphere(ugms._nm("dr"), 1.0, ugms.g2b((x, -hh * 0.45, z)), M["drift"], scale=ugms.gsize(sc), segs=14, rings=8)
        u += L * 0.55


if EXT:
    # водостоки — по углам длинного крыла и у башни
    for (x, z, ox, oz) in ((LX0, LZ1, -0.12, 0.12), (LX0, LZ0, -0.12, -0.12), (LX1, LZ1, 0.12, 0.12), (SX1, SZ0, 0.12, -0.12), (SX1, SZ1, 0.12, 0.12)):
        drainpipe(x, z, ox=ox, oz=oz)
    # сосульки по парапету с подветренных сторон
    icicles(0, LX0, LX1, LZ1, 0.08, PAR - 0.02, 1)
    icicles(2, LZ0, LZ1, LX0, -0.08, PAR - 0.02, 2)
    icicles(2, SZ0, SZ1, SX1, 0.08, PAR - 0.02, 3)
    icicles(0, TX0, TX1, TZ0, -0.08, TW_TOP - 0.05, 4)
    # переметы у стен (вход и пандус оставлены чистыми)
    drift(2, LZ0 + 0.5, DOOR_Z[0] - 1.6, LX0, -1, h=0.45, d=0.9)
    drift(2, DOOR_Z[1] + 1.6, LZ1 - 0.4, LX0, -1, h=0.35, d=0.8)
    drift(0, LX0 + 0.4, LX1 - 0.4, LZ1, 1, h=0.4, d=0.9)
    drift(0, SX0 + 0.3, SX1 - 0.3, SZ0, -1, h=0.5, d=1.0)
    drift(2, TZ0 + 0.3, TZ1 - 0.3, TX0, -1, h=0.4, d=0.8)
    # грязь и сырость у цоколя — тёмная полоса поверх штукатурки
    for (a, b, c, n, ax) in ((LZ0, LZ1, LX0, -1, 2), (LX0, LX1, LZ1, 1, 0), (SX0, SX1, SZ0, -1, 0), (TZ0, TZ1, TX0, -1, 2)):
        lo, hi = min(a, b), max(a, b)
        x, _, z = _uv(ax, (lo + hi) / 2, c, 0, n * 0.035)
        box((x, 0.75, z), (hi - lo, 0.5, 0.01) if ax == 0 else (0.01, 0.5, hi - lo), M["grime"])
    # светильник над входом (свет даёт игра): кронштейн, жестяной абажур, патрон
    LZC = sum(DOOR_Z) / 2
    box((LX0 - 0.25, 2.95, LZC), (0.5, 0.03, 0.03), M["iron"])
    cyl((LX0 - 0.48, 2.85, LZC), 0.17, 0.12, M["green"], verts=12, r2=0.05)
    cyl((LX0 - 0.48, 2.78, LZC), 0.04, 0.05, M["white"], verts=8)
    # кабель ввода с изолятором под парапетом и вентрешётки
    for k in range(3):
        cyl((LX0 - 0.1, PAR - 0.5, -21.0 - k * 0.15), 0.03, 0.08, M["white"], verts=8, axis="x")
    for (zz, yy) in ((-33.9, 3.1), (-25.2, 3.1), (-21.0, 0.25)):
        box((LX0 - 0.02, yy, zz), (0.02, 0.22, 0.3), M["rail"])
        for k in range(4):
            box((LX0 - 0.035, yy - 0.075 + k * 0.05, zz), (0.01, 0.015, 0.26), M["soot"])


# --- Дизельная пристройка во внутреннем углу (вход с юга) -----------------------------------
GFL = 0.15
GEN_DOOR = [100.1, 101.0, GFL, GFL + 2.0, "door"]
wall(0, GX0, GX1, GZ1, +1, 0.0, GH, [GEN_DOOR], inner=(GFL, GH - 0.2), panel=False, in_u=(GX0, GX1 - T))
wall(2, GZ0, GZ1, GX1, +1, 0.0, GH, [[-32.4, -31.6, 1.4, 2.0, "win"]], inner=(GFL, GH - 0.2), panel=False, in_u=(GZ0, GZ1 - T))
window(2, -32.0, GX1, +1, 0.8, 1.4, 2.0)
if EXT:
    # односкатная кровля из рубероида, свес на юг; выхлоп дизеля с копотью на стене
    box(((GX0 + GX1) / 2 + 0.15, GH + 0.06, (GZ0 + GZ1) / 2 + 0.15), (GX1 - GX0 + 0.3, 0.12, GZ1 - GZ0 + 0.6), M["roofing"], tilt_x=0.06)
    box(((GX0 + GX1) / 2 + 0.15, GH + 0.17, (GZ0 + GZ1) / 2 + 0.1), (GX1 - GX0, 0.1, GZ1 - GZ0 + 0.2), M["snow"], tilt_x=0.06, bevel=0.03)
    cyl((101.8, GH + 0.9, -32.6), 0.07, 1.8, M["iron"], verts=8)
    cyl((101.8, GH + 1.85, -32.6), 0.12, 0.1, M["iron"], verts=8, r2=0.05)
    box((GX1 + 0.025, 1.6, -31.0), (0.01, 1.2, 0.5), M["soot"])
    sign((GEN_DOOR[1] + 0.45, 1.6, GZ1 + 0.03), 0.0, ["ДЭС"], M, w=0.4, h=0.2, size=0.08)
    # дверь (вид); открывает Godot
colbox(((GX0 + GX1) / 2, GH + 0.06, (GZ0 + GZ1) / 2), (GX1 - GX0, 0.12, GZ1 - GZ0))
inner_floor(GX0, GX1 - T, GZ0, GZ1 - T, GFL, M["cfloor"])
ceiling(GX0, GX1 - T, GZ0, GZ1 - T, GH - 0.2)
if INT:
    # дизель-генератор на раме, бак, щиток
    box((100.4, GFL + 0.15, -32.6), (1.6, 0.1, 0.7), M["iron"])
    box((100.1, GFL + 0.6, -32.6), (0.9, 0.8, 0.62), M["green"])
    box((100.95, GFL + 0.55, -32.6), (0.6, 0.6, 0.55), M["rail"])
    cyl((101.8, GFL + 1.2, -32.6), 0.07, 2.2, M["iron"], verts=8)
    cyl((99.85, GFL + 1.5, -31.3), 0.28, 0.9, M["red"], verts=12, axis="x")
    box((101.7, GFL + 1.4, -31.15), (0.5, 0.6, 0.12), M["rail"])
colbox((100.4, GFL + 0.5, -32.6), (1.8, 1.0, 0.75))

# --- Цоколь, крыльцо с козырьком, табличка ----------------------------------------------
if EXT:
    for (a, b, c, ax) in ((LZ0, LZ1, LX0, 2), (LX0, LX1, LZ1, 0), (GZ1, LZ1, LX1, 2), (LX0, TX0, LZ0, 0), (TZ0, TZ1, TX0, 2), (TX0, TX1, TZ0, 0),
                          (SX0, SX1, SZ0, 0), (SZ0, SZ1, SX1, 2), (102.4, SX1, SZ1, 0), (GX0, GX1, GZ1, 0), (GZ0, GZ1, GX1, 2)):
        L = b - a
        out = 0.05 if c in (LX1, LZ1, SX1, SZ1, GX1, GZ1) else -0.05
        box(_uv(ax, (a + b) / 2, c, 0.22, out), (L + 0.1, 0.44, 0.12) if ax == 0 else (0.12, 0.44, L + 0.1), M["concrete"])
    # крыльцо
    PZ = sum(DOOR_Z) / 2
    box((LX0 - 0.75, FL / 2, PZ), (1.5, FL, 2.6), M["concrete"])
    box((LX0 - 1.7, FL / 4, PZ), (0.45, FL / 2, 2.0), M["concrete"])
    box((LX0 - 0.7, 2.95, PZ), (1.5, 0.12, 2.8), M["concrete"])
    box((LX0 - 0.7, 3.05, PZ), (1.4, 0.1, 2.7), M["snow"], bevel=0.03)
    for s in (-1, 1):
        box((LX0 - 0.55, 2.7, PZ + s * 1.2), (1.1, 0.06, 0.06), M["rail"], tilt_z=0.4)
    # перила
    for s in (-1, 1):
        box((LX0 - 0.75, FL + 0.5, PZ + s * 1.27), (1.5, 0.04, 0.04), M["rail"])
        box((LX0 - 1.48, FL + 0.25, PZ + s * 1.27), (0.04, 0.95, 0.04), M["rail"])
    # входная дверь (вид; открывает Godot) — обитая, тёмно-зелёная
    sign((LX0 - 0.04, FL + 1.7, DOOR_Z[0] - 0.8), -math.pi / 2, ["АЭРОЛОГИЧЕСКАЯ СТАНЦИЯ", "КЕДР-7", "Якутское УГМС"], M, w=1.2, h=0.46, size=0.075)
    # лампа над дверью
    box((LX0 - 0.12, DOOR_H + 0.3, PZ), (0.2, 0.08, 0.08), M["rail"])
    cyl((LX0 - 0.25, DOOR_H + 0.22, PZ), 0.1, 0.1, M["rail"], verts=10, r2=0.05)
colbox((LX0 - 0.75, FL / 2, sum(DOOR_Z) / 2), (1.5, FL, 2.6))
# Ступень — для глаза, а ходят по пандусу: шага вверх у игрока нет, 22 см не взять
colbox((LX0 - 1.5 - 0.625, FL / 2 - 0.05, sum(DOOR_Z) / 2), (2.0, 0.1, math.hypot(1.25, FL)), math.pi / 2, -math.atan(FL / 1.25))

# --- Сборка ------------------------------------------------------------------------------
name = "corpus_" + PART
# Фасады — со слабым AO: каждая плита стены запекалась со своим затенением краёв, и ночью корпус «гофрировался»
obj, img, tris = kit.finish(name, OUT, res=4096, origin="keep", samples=24, pack=0.002, ao_blur=2, ao_min=0.62 if EXT else 0.35)
kit.export(os.path.join(OUT, name + ".glb"), None)
lo = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "data", "corpus_col_%s.gd" % PART)
with open(dst, "w", encoding="utf8") as f:
    f.write("# Сгенерировано tools/blender/corpus.py — коллизии корпуса (%s). Не править руками.\n" % PART)
    f.write("# Коробка: [cx, cy, cz, sx, sy, sz, yaw, tilt_x] в координатах игры.\n")
    f.write("const BOXES := [\n")
    for b in COL:
        f.write("\t[%s],\n" % ", ".join("%.3f" % v for v in b))
    f.write("]\n")
print("[OK] %s: %d tris, низ %.3f, коллизий %d" % (name, tris, lo, len(COL)))

if os.environ.get("PREVIEW"):
    from mathutils import Vector
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 1100, 700
    cam_d = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam); sc.camera = cam
    views = {"ext": [("west", (70.0, 3.0, -16.0), (95.0, 4.5, -30.0), 28), ("ne", (118.0, 9.0, -52.0), (97.0, 5.0, -30.0), 28),
                     ("se", (114.0, 4.0, -12.0), (97.0, 4.5, -30.0), 28), ("porch", (84.0, 1.7, -24.0), (90.0, 2.0, -27.3), 30)],
             "int": [("corridor", (95.6, 2.1, -21.0), (95.6, 1.6, -34.0), 18), ("apparat", (93.0, 2.2, -29.2), (91.5, 1.4, -33.5), 18),
                     ("tower", (98.2, 2.0, -35.2), (95.5, 5.5, -37.8), 16), ("cabin", (98.2, CAB + 1.6, -35.3), (95.0, CAB + 0.6, -38.5), 16)]}[PART]
    for tag, loc, tgt, lens in views:
        L, G = Vector(ugms.g2b(loc)), Vector(ugms.g2b(tgt))
        cam.location = L
        cam.rotation_euler = (G - L).to_track_quat("-Z", "Y").to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(OUT, "_prev_%s_%s.png" % (PART, tag))
        bpy.ops.render.render(write_still=True)
