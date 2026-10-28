# Главный дом станции «Кедр-7» снаружи (docs/СТИЛЬ_ПОСТРОЕК.md): сруб, обшитый тёсом, выцветшая зелёная
# краска, белые наличники и угловые доски, бетонный цоколь, шиферная кровля со снегом, крыльцо с навесом.
# Координаты — как в station.gd (линии стен, RIDGE_TOP, ROOF_PITCH, SHED_PITCH): модель встаёт на место.
# Запуск: blender --background --python house_ext.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, siding, gable_boards, corner, window_trim, roof_slope, barge, plinth, sign

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
M = ugms.mats()

O = 0.23                 # CabinBuilder.OFFSET — ось бывшего бревна
F = 0.36                 # наружная грань обшивки от линии стены (Station.LOG_FACE)
RIDGE = 5.5
PITCH = math.tan(math.radians(28.0))
SHED = math.tan(math.radians(6.0))
ROOF_T = 0.16
EAVE_OVER = 0.45
Y0 = 0.3                 # низ обшивки над цоколем


def top(z):
    return RIDGE - abs(z - 3.3) * PITCH


def under(z):
    return top(z) - ROOF_T / math.cos(math.radians(28.0))


def shed_top(z):
    return top(0.0) + z * SHED


def shed_under(z):
    return shed_top(z) - ROOF_T / math.cos(math.radians(6.0))


EAVE = under(6.6 + O)

# --- Проёмы (как в station.gd: [вдоль стены от, до, низ, верх]) ---
WIN_LIVING = [-0.04, 1.04, 1.06, 1.94]
WIN_CORR = [7.06, 7.94, 1.16, 2.04]
WIN_WEST = [2.71, 3.89, 1.01, 1.89]
WIN_NORTH = [8.56, 9.84, 1.01, 1.89]
DOOR = [2.56, 3.64, -1.0, 2.18]
ATTIC = [2.93, 3.67, 3.43, 4.17]

# --- Стены (ось, от, до, линия, наружу, верх) ---
flat = lambda h: (lambda u: h)
siding(0, -2.5 - F, 14.5 + F, 6.6, +1, Y0, EAVE, [WIN_LIVING, WIN_CORR], M)            # юг
siding(2, -F, 6.6 + F, 14.5, +1, Y0, EAVE, [DOOR], M)                                # восток (тамбур)
siding(0, 11.5 + F, 14.5 + F, 0.0, -1, Y0, EAVE, [], M)                              # север тамбура
siding(0, -2.5 - F, 3.5 - F, 0.0, -1, Y0, EAVE, [], M)                               # север жилой
siding(2, -F, 6.6 + F, -2.5, -1, Y0, EAVE, [WIN_WEST], M)                            # запад жилой
siding(2, -2.0 - F, -F, 11.5, +1, Y0, 0, [], M, top_fn=lambda u: shed_under(u))     # восток рубки
siding(0, 7.0 + F, 11.5 + F, -2.0, -1, Y0, shed_under(-2.0 - F), [WIN_NORTH], M)     # север рубки
siding(2, -5.5 - F, -2.0 - F, 7.0, +1, Y0, 0, [], M, top_fn=lambda u: shed_under(u))  # восток кладовой
siding(0, 3.5 - F, 7.0 + F, -5.5, -1, Y0, shed_under(-5.5 - F), [], M)               # север кладовой
siding(2, -5.5 - F, -F, 3.5, -1, Y0, 0, [], M, top_fn=lambda u: shed_under(u))       # запад крыла

# --- Фронтоны: вертикальная доска, на западном — слуховое окно чердака ---
gable_boards(2, 3.3, 3.3 + F, 14.5, +1, EAVE, under(3.3) - 0.02, M)
gable_boards(2, 3.3, 3.3 + F, -2.5, -1, EAVE, under(3.3) - 0.02, M, holes=[ATTIC])
for x, n in ((14.5, 1), (-2.5, -1)):
    # пояс-карниз между стеной и фронтоном
    box((x + n * (F + 0.04), EAVE + 0.02, 3.3), (0.08, 0.1, 6.6 + 2 * F + 0.1), M["white"])
# слуховое окно: белая рамка и тёмные жалюзи
for dz in (-0.42, 0.42):
    box((-2.5 - F - 0.03, 3.8, 3.3 + dz), (0.04, 0.84, 0.08), M["white"])
for y in (3.39, 4.21):
    box((-2.5 - F - 0.03, y, 3.3), (0.04, 0.08, 0.92), M["white"])
for i in range(5):
    box((-2.5 - F + 0.02, 3.5 + i * 0.15, 3.3), (0.03, 0.05, 0.74), M["iron"], tilt_z=0.5)

# --- Угловые доски на наружных углах ---
for (x, z, nx, nz, y1) in [(-2.5, 6.6, -1, 1, EAVE), (14.5, 6.6, 1, 1, EAVE), (14.5, 0.0, 1, -1, EAVE),
                           (11.5, -2.0, 1, -1, shed_under(-2.36)), (7.0, -5.5, 1, -1, shed_under(-5.86)),
                           (3.5, -5.5, -1, -1, shed_under(-5.86)), (-2.5, 0.0, -1, -1, EAVE)]:
    corner(x, z, nx, nz, Y0 - 0.05, y1, M)
# Фриз под свесом юга и севера основного корпуса
box((6.0, EAVE - 0.08, 6.6 + F + 0.02), (17.0 + 2 * F, 0.16, 0.03), M["white"])
box((0.3, EAVE - 0.08, -F - 0.02), (5.6 + 2 * F - 0.7, 0.16, 0.03), M["white"])
box((13.2, EAVE - 0.08, -F - 0.02), (2.6 + F, 0.16, 0.03), M["white"])

# --- Наличники окон ---
window_trim(0, 0.5, 6.6, +1, 1.5, 1.08, 0.88, M)
window_trim(0, 7.5, 6.6, +1, 1.6, 0.88, 0.88, M)
window_trim(2, 3.3, -2.5, -1, 1.45, 1.18, 0.88, M)
window_trim(0, 9.2, -2.0, -1, 1.45, 1.28, 0.88, M)
# Входная дверь: белый косяк с козырьком-фронтоном над наличником
for z in (2.5, 3.7):
    box((14.5 + F + 0.02, 1.1, z), (0.04, 2.2, 0.12), M["white"])
box((14.5 + F + 0.02, 2.26, 3.1), (0.04, 0.14, 1.36), M["white"])

# --- Цоколь ---
plinth([(-2.5, 6.6), (14.5, 6.6), (14.5, 0.0), (11.5, 0.0), (11.5, -2.0), (7.0, -2.0), (7.0, -5.5),
        (3.5, -5.5), (3.5, 0.0), (-2.5, 0.0)], -0.25, Y0, M)

# --- Кровля ---
xw, xe = -2.5 - O - EAVE_OVER, 14.5 + O + EAVE_OVER
wing0, wing1 = 3.5 - O - 0.35, 11.5 + O + 0.35
zs, zn = 6.6 + O + EAVE_OVER, -O - EAVE_OVER
roof_slope(xw, xe, 3.3, zs, RIDGE, top(zs), M)
roof_slope(xw, wing0, 3.3, zn, RIDGE, top(zn), M)
roof_slope(wing1, xe, 3.3, zn, RIDGE, top(zn), M)
roof_slope(wing0, wing1, 3.3, 0.0, RIDGE, top(0.0), M, eave=False)
z_radio, z_store, x_store = -2.0 - O - 0.35, -5.5 - O - 0.35, 7.0 + O + 0.35
roof_slope(wing0, x_store, 0.0, z_radio, shed_top(0.0), shed_top(z_radio), M, eave=False)
roof_slope(x_store, wing1, 0.0, z_radio, shed_top(0.0), shed_top(z_radio), M)
roof_slope(wing0, x_store, z_radio, z_store, shed_top(z_radio), shed_top(z_store), M)
# Конёк: шиферные коньковые элементы и снежный гребень
for s in (-1, 1):
    box(((xw + xe) / 2, RIDGE + 0.02, 3.3 + s * 0.12), (xe - xw + 0.06, 0.03, 0.3), M["slate"], tilt_x=s * 0.45)
box(((xw + xe) / 2, RIDGE + 0.1, 3.3), (xe - xw - 0.2, 0.12, 0.32), M["snow"], bevel=0.05)
# Ветровые доски
for x in (xw + 0.02, xe - 0.02):
    barge(x, 3.3, RIDGE, zs, top(zs), M)
    barge(x, 3.3, RIDGE, zn, top(zn), M)
barge(wing0 + 0.02, 0.0, shed_top(0.0), z_store, shed_top(z_store), M)
barge(wing1 - 0.02, 0.0, shed_top(0.0), z_radio, shed_top(z_radio), M)
barge(x_store - 0.02, z_radio, shed_top(z_radio), z_store, shed_top(z_store), M)

# --- Крыльцо: настил, ступени, столбы, перила, навес с шифером и снегом ---
x0 = 14.5 + F
box((x0 + 0.78, 0.02, 3.1), (1.56, 0.14, 2.3), M["wood"])
for i in range(7):
    box((x0 + 0.78, 0.095, 2.05 + i * 0.35), (1.56, 0.012, 0.025), M["iron"])   # щели настила
box((x0 + 1.75, -0.07, 3.1), (0.4, 0.1, 1.7), M["wood"])
box((x0 + 2.1, -0.15, 3.1), (0.35, 0.08, 1.7), M["wood"])
for z in (2.0, 4.2):
    box((x0 + 1.45, 1.3, z), (0.12, 2.5, 0.12), M["white"])
    box((x0 + 0.06, 1.3, z), (0.1, 2.5, 0.1), M["white"])
    # перила вдоль крыльца
    box((x0 + 0.75, 0.95, z), (1.4, 0.07, 0.07), M["green"])
    box((x0 + 0.75, 0.55, z), (1.4, 0.05, 0.04), M["green"])
    for k in range(5):
        box((x0 + 0.2 + k * 0.28, 0.55, z), (0.04, 0.8, 0.04), M["green"])
for z in (2.0, 4.2):
    box((x0 + 0.75, 2.58, z), (1.6, 0.1, 0.1), M["white"])
# навес двускатный, конёк поперёк — вдоль X
for s in (-1, 1):
    zc = 3.1 + s * 0.65
    box((x0 + 0.8, 2.86, zc), (1.9, 0.04, 1.42), M["slate"], tilt_x=s * 0.42)
    box((x0 + 0.8, 2.93, zc), (1.84, 0.1, 1.3), M["snow"], tilt_x=s * 0.42, bevel=0.03)
    box((x0 + 0.8, 2.56, 3.1 + s * 1.28), (1.9, 0.16, 0.03), M["white"])
for x in (x0 + 1.74,):
    for s in (-1, 1):
        box((x, 2.92, 3.1 + s * 0.6), (0.03, 0.18, 1.3), M["white"], tilt_x=s * 0.42)

# --- Табличка станции и инвентарный номер ---
sign((12.9, 2.25, 6.6 + F + 0.03), 0.0, ["МЕТЕОСТАНЦИЯ «КЕДР-7»", "Свердловское УГМС"], M, w=1.5, h=0.42, size=0.1)
sign((14.5 + F + 0.03, 1.75, 4.15), math.pi / 2, ["ИНВ. № 0417"], M, w=0.5, h=0.16, size=0.06)

obj, img, tris = kit.finish("house_ext", OUT, res=2048, origin="keep", samples=32, pack=0.002, ao_blur=2)
kit.export(os.path.join(OUT, "house_ext.glb"), None)
print(f"[OK] house_ext: {tris} tris")
