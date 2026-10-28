# Павильон наблюдателя у калитки метеоплощадки «Кедр-7» (docs/СТИЛЬ_ПОСТРОЕК.md): убежище от бурана.
# Зелёный тёс, белые углы, односкатный шифер на север, окно на площадку (восток), дверь на тропу (юг).
# Внутри: стол у окна, лавка, буржуйка с трубой, полевой телефон ТА-57 на стене, полка, лампа, календарь.
# Положение — Yard.METEO + Yard.M_PAV (центр), размеры 3.2×2.6; коллизии и интерактив — в yard.gd.
# Запуск: blender --background --python pavilion.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, cyl, prism, siding, corner, window_trim, roof_slope, barge, sign, _rects

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()
lin = lambda n, d: ugms.painted(n, (0.62, 0.62, 0.56), under=(0.42, 0.40, 0.34), peel=0.15, scale=4.0, grain=0.05, detail=3, streaks=False, boards=d, step=0.12)
M["lin_z"] = lin("p_lin_z", "x")
M["lin_x"] = lin("p_lin_x", "y")
M["floor"] = ugms.painted("p_floor", (0.33, 0.17, 0.08), under=(0.30, 0.25, 0.19), peel=0.25, scale=3.0, grain=0.05, detail=3, streaks=False, boards="x", step=0.14)
M["desk"] = kit.mat("p_desk", (0.30, 0.20, 0.12), rough=0.7, wear=0.5, dirt=0.3)
M["paper"] = kit.mat("p_paper", (0.75, 0.72, 0.62), rough=0.9)
M["phone"] = kit.mat("p_phone", (0.12, 0.16, 0.12), rough=0.6, wear=0.5)
M["stove"] = kit.mat("p_stove", (0.09, 0.09, 0.09), rough=0.7, wear=0.6, wear_col=(0.35, 0.2, 0.12))
M["lamp"] = kit.mat("p_lamp", (0.9, 0.82, 0.6), rough=0.3)

# --- Положение (как в yard.gd: METEO = (98, 0, −30), M_PAV = (−16.5, 0, −4.0)) ---
CX, CY, CZ = 98.0 - 16.5, 0.0, -30.0 - 4.0
HX, HZ = 1.6, 1.3
SLOPE = 0.3 / 2.6
FLOOR = CY + 0.12


def top(zl):
    return CY + 2.25 + (zl + HZ) * SLOPE


DOOR = [CX - 0.95, CX - 0.05, 0.0, FLOOR + 1.95]
WIN_E = [CZ - 0.55, CZ + 0.35, FLOOR + 0.95, FLOOR + 1.6]
WIN_W = [CZ - 0.25, CZ + 0.25, FLOOR + 1.1, FLOOR + 1.5]

# --- Снаружи ---
siding(0, CX - HX, CX + HX, CZ + HZ, +1, FLOOR, top(HZ), [DOOR], M, face=0.0)
siding(0, CX - HX, CX + HX, CZ - HZ, -1, FLOOR, top(-HZ), [], M, face=0.0)
siding(2, CZ - HZ, CZ + HZ, CX - HX, -1, FLOOR, 0, [WIN_W], M, face=0.0, top_fn=lambda u: top(u - CZ))
siding(2, CZ - HZ, CZ + HZ, CX + HX, +1, FLOOR, 0, [WIN_E], M, face=0.0, top_fn=lambda u: top(u - CZ))
for sx in (-1, 1):
    for sz in (-1, 1):
        corner(CX + sx * HX, CZ + sz * HZ, sx, sz, CY + 0.05, top(sz * HZ), M, face=0.0, w=0.12)
for x in (DOOR[0] - 0.06, DOOR[1] + 0.06):
    box((x, (FLOOR + DOOR[3]) / 2, CZ + HZ + 0.02), (0.1, DOOR[3] - FLOOR + 0.1, 0.03), M["white"])
box((CX - 0.5, DOOR[3] + 0.06, CZ + HZ + 0.02), (1.12, 0.12, 0.03), M["white"])
window_trim(2, (WIN_E[0] + WIN_E[1]) / 2, CX + HX, +1, (WIN_E[2] + WIN_E[3]) / 2, WIN_E[1] - WIN_E[0], WIN_E[3] - WIN_E[2], M, face=0.0)
window_trim(2, CZ, CX - HX, -1, (WIN_W[2] + WIN_W[3]) / 2, 0.5, 0.4, M, face=0.0, kokoshnik=False)
# Крыльцо-ступень и обвязка на лежнях
box((CX - 0.5, CY + 0.06, CZ + HZ + 0.45), (1.3, 0.12, 0.7), M["wood"])
for sz in (-1, 1):
    box((CX, CY + 0.05, CZ + sz * (HZ - 0.05)), (2 * HX + 0.1, 0.14, 0.16), M["wood"])
# Кровля: односкатная на север, вылеты
z_hi, z_lo = CZ + HZ + 0.45, CZ - HZ - 0.35
x0, x1 = CX - HX - 0.3, CX + HX + 0.3
y_hi, y_lo = top(HZ + 0.45) + 0.1, top(-HZ - 0.35) + 0.1
roof_slope(x0, x1, z_hi, z_lo, y_hi, y_lo, M)
for x in (x0 + 0.02, x1 - 0.02):
    barge(x, z_hi, y_hi, z_lo, y_lo, M)
box((CX, y_hi - 0.1, z_hi), (x1 - x0, 0.2, 0.04), M["white"])
# Труба буржуйки (северо-западный угол)
SX, SZ = CX - 1.05, CZ - 0.75
cyl((SX, (FLOOR + 0.75 + y_lo + 0.9) / 2 + 0.3, SZ), 0.06, y_lo + 1.3 - FLOOR - 0.75, M["iron"], verts=10)
cyl((SX, y_lo + 1.0 + 0.55, SZ), 0.13, 0.06, M["iron"], verts=10, r2=0.03)
# Табличка у двери
sign((CX + 0.75, FLOOR + 1.6, CZ + HZ + 0.03), 0.0, ["ПАВИЛЬОН", "наблюдателя"], M, w=0.62, h=0.26, size=0.06)

# --- Внутри ---
IN = 0.06
for axis, c, n, holes, key in ((0, CZ + HZ, -1, [DOOR], "lin_z"), (0, CZ - HZ, +1, [], "lin_z"),
                               (2, CX - HX, +1, [WIN_W], "lin_x"), (2, CX + HX, -1, [WIN_E], "lin_x")):
    lo, hi = (CX - HX + IN, CX + HX - IN) if axis == 0 else (CZ - HZ + IN, CZ + HZ - IN)
    for r in _rects(lo, hi, FLOOR, top(HZ), holes):
        if axis == 0:
            yt = top(c - CZ)
            pts = [(r[0], r[2]), (r[1], r[2]), (r[1], min(r[3], yt)), (r[0], min(r[3], yt))]
        else:
            pts = [(r[0], r[2]), (r[1], r[2]), (r[1], min(r[3], top(r[1] - CZ))), (r[0], min(r[3], top(r[0] - CZ)))]
        prism(axis, c, n, pts, IN, IN + 0.02, M[key])
box((CX, FLOOR - 0.015, CZ), (2 * HX - 2 * IN, 0.03, 2 * HZ - 2 * IN), M["floor"])
for rx in (-0.8, 0.8):
    box((CX + rx, (top(0) + top(0)) / 2 + 0.02, CZ), (0.07, 0.1, 2 * HZ), M["wood"], tilt_x=math.atan(SLOPE))
box((CX, top(0) + 0.08, CZ), (2 * HX, 0.02, 2 * HZ + 0.1), M["lin_z"], tilt_x=math.atan(SLOPE))
# Стол у восточного окна, журнал, чернильница, кружка
TX = CX + HX - 0.45
box((TX, FLOOR + 0.74, CZ - 0.1), (0.7, 0.04, 1.2), M["desk"])
for dz in (-0.62, 0.42):
    for dx in (-0.3, 0.3):
        box((TX + dx, FLOOR + 0.37, CZ + dz), (0.05, 0.74, 0.05), M["desk"])
box((TX - 0.05, FLOOR + 0.775, CZ - 0.2), (0.32, 0.03, 0.44), M["paper"], yaw=0.1)
box((TX - 0.05, FLOOR + 0.795, CZ - 0.2), (0.02, 0.012, 0.44), M["ink"])
cyl((TX + 0.18, FLOOR + 0.81, CZ + 0.25), 0.04, 0.09, M["white"], verts=10)
# Лавка вдоль южной стены
box((CX + 0.6, FLOOR + 0.42, CZ + HZ - 0.3), (1.6, 0.05, 0.36), M["desk"])
for dx in (-0.65, 0.65):
    box((CX + 0.6 + dx, FLOOR + 0.21, CZ + HZ - 0.3), (0.05, 0.42, 0.3), M["desk"])
# Буржуйка
cyl((SX, FLOOR + 0.42, SZ), 0.26, 0.6, M["stove"], verts=14)
for a in range(4):
    ang = a * math.pi / 2 + 0.6
    box((SX + math.cos(ang) * 0.18, FLOOR + 0.06, SZ + math.sin(ang) * 0.18), (0.04, 0.12, 0.04), M["stove"])
box((SX + 0.27, FLOOR + 0.38, SZ), (0.02, 0.16, 0.2), M["stove"])
cyl((SX, FLOOR + 0.95, SZ), 0.06, 0.5, M["stove"], verts=10)
box((SX + 0.15, FLOOR + 0.08, SZ + 0.2), (0.55, 0.05, 0.45), M["iron"])    # лист железа под печкой
# Полевой телефон ТА-57 на северной стене
PX, PZ = CX + 0.35, CZ - HZ + IN + 0.1
box((PX, FLOOR + 1.35, PZ), (0.28, 0.2, 0.14), M["phone"])
box((PX, FLOOR + 1.47, PZ + 0.03), (0.24, 0.05, 0.06), M["iron"])          # трубка
box((PX + 0.17, FLOOR + 1.33, PZ + 0.02), (0.03, 0.08, 0.03), M["iron"])    # ручка индуктора
kit.tube("cord", [ugms.g2b((PX, FLOOR + 1.25, PZ + 0.06)), ugms.g2b((PX, FLOOR + 1.1, PZ + 0.07)), ugms.g2b((PX - 0.2, FLOOR + 1.3, PZ + 0.02))], 0.008, M["iron"], 4)
kit.tube("wire", [ugms.g2b((PX + 0.14, FLOOR + 1.4, PZ - 0.04)), ugms.g2b((PX + 1.0, top(-HZ) - 0.05, PZ - 0.06)), ugms.g2b((CX + HX - 0.1, top(-HZ) - 0.05, PZ - 0.06))], 0.006, M["iron"], 4)
# Полка с барометром-анероидом и керосинкой, календарь
box((CX - 0.3, FLOOR + 1.7, CZ - HZ + IN + 0.12), (0.8, 0.03, 0.2), M["desk"])
cyl((CX - 0.5, FLOOR + 1.8, CZ - HZ + IN + 0.12), 0.08, 0.04, M["white"], verts=14, axis="z")
box((CX + HX - IN - 0.02, FLOOR + 1.3, CZ + 0.75), (0.01, 0.4, 0.3), M["paper"])
box((CX + HX - IN - 0.025, FLOOR + 1.43, CZ + 0.75), (0.008, 0.08, 0.3), M["red"])
# Лампа под потолком
cyl((CX + 0.2, top(0) - 0.25, CZ), 0.11, 0.1, M["iron"], verts=12, r2=0.05)
cyl((CX + 0.2, top(0) - 0.3, CZ), 0.045, 0.05, M["lamp"], verts=8)

obj, img, tris = kit.finish("pavilion", OUT, res=1024, origin="keep", samples=32, pack=0.003, ao_blur=2)
kit.export(os.path.join(OUT, "pavilion.glb"), None)
print(f"[OK] pavilion: {tris} tris")
