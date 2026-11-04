# Интерьер дома «Кедр-7» по комнатам (docs/СТИЛЬ_ПОСТРОЕК.md): отдельный GLB на комнату — у дома свой
# световой слой «внутри», и меш не должен выходить за габарит комнаты (Station.is_pos_inside_house).
# Линии стен, проёмы и высота потолка — как в Station._build_house (ROOM_H = 2.8, пол на 0.05).
# Запуск: blender --background --python house_int.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, ugms
from ugms import box, prism, _rects

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "."
os.makedirs(OUT, exist_ok=True)

H = 2.8          # потолок
FL = 0.05        # верх пола
FACE = 0.1       # от линии стены до поверхности (полстены)
PANEL = 1.5      # высота масляной панели


def mats():
    # Внутри — без мелкого зерна (на экране оно читается как помехи) и светлее, чем снаружи
    p = lambda *a, **k: ugms.painted(*a, grain=0.05, detail=3, **k)
    m = {
        "whitewash": p("i_white", (0.80, 0.79, 0.72), under=(0.58, 0.55, 0.48), peel=0.1, scale=3.0, streaks=False),
        "panel_green": p("i_pgreen", (0.24, 0.40, 0.34), under=(0.40, 0.38, 0.33), peel=0.08, scale=5.0, streaks=False),
        "panel_blue": p("i_pblue", (0.27, 0.37, 0.43), under=(0.40, 0.38, 0.33), peel=0.08, scale=5.0, streaks=False),
        "floor": p("i_floor", (0.33, 0.17, 0.08), under=(0.30, 0.25, 0.19), peel=0.18, scale=3.0, streaks=False, boards="x", step=0.14),
        "floor_raw": p("i_floor_raw", (0.40, 0.33, 0.25), under=(0.33, 0.28, 0.22), peel=0.16, scale=4.0, streaks=False, boards="x", step=0.16),
        "trim": p("i_trim", (0.74, 0.73, 0.68), under=(0.42, 0.40, 0.35), peel=0.12, scale=7.0, streaks=False),
        "plinth": p("i_plinth", (0.25, 0.14, 0.07), peel=0.1, scale=8.0, streaks=False),
        "strip": kit.mat("i_strip", (0.10, 0.12, 0.11), rough=0.6),
        "beam": kit.mat("i_beam", (0.30, 0.24, 0.17), rough=0.9, noise=0.25, noise_scale=20, wear=0.4, dirt=0.4),
        "reveal": kit.mat("i_reveal", (0.55, 0.52, 0.46), rough=0.9, noise=0.2, noise_scale=12),
    }
    # Вертикальная доска зависит от оси стены: рисунок полос идёт вдоль X или вдоль Y Blender
    for axis, d in ((0, "v"), (2, "y")):
        m[("lining", axis)] = p("i_lining%d" % axis, (0.52, 0.34, 0.17), under=(0.36, 0.30, 0.22), peel=0.06, scale=6.0, streaks=False, boards=d, step=0.09)
        m[("wallpaper", axis)] = p("i_paper%d" % axis, (0.66, 0.58, 0.44), under=(0.52, 0.45, 0.34), peel=0.14, scale=2.5, streaks=False, boards=d, step=0.26)
        m[("plank", axis)] = p("i_plank%d" % axis, (0.42, 0.35, 0.27), under=(0.32, 0.27, 0.21), peel=0.18, scale=3.5, streaks=False, boards=d, step=0.18)
    return m


def W(M, key, axis):
    v = M.get((key, axis))
    return v if v is not None else M[key]


def wall(M, axis, c, nrm, u0, u1, holes, lower, upper, divider=True, floor_key="floor"):
    """Стена комнаты: поверхность на FACE от линии стены внутрь (nrm — в сторону комнаты)."""
    for y0, y1, key in ((FL, PANEL, lower), (PANEL, H, upper)):
        for r in _rects(u0, u1, y0, y1, holes):
            prism(axis, c, nrm, [(r[0], r[2]), (r[1], r[2]), (r[1], r[3]), (r[0], r[3])], FACE, FACE + 0.02, W(M, key, axis))
    for y0, y1, key, depth in (((PANEL - 0.02, PANEL + 0.02, "strip", 0.03),) if divider else ()) + ((FL, FL + 0.11, "plinth", 0.035), (H - 0.07, H, "trim", 0.05)):
        for r in _rects(u0, u1, y0, y1, holes):
            if r[3] - r[2] < y1 - y0 - 0.001:
                continue    # над/под проёмом плинтус и поясок не ставим
            prism(axis, c, nrm, [(r[0], y0), (r[1], y0), (r[1], y1), (r[0], y1)], FACE + 0.02, FACE + 0.02 + depth, M[key])
    for h in holes:
        opening(M, axis, c, nrm, h, floor_key)


def opening(M, axis, c, nrm, h, floor_key="floor"):
    """Откосы проёма (от поверхности до линии стены), порог двери и наличник по поверхности комнаты."""
    u0, u1, v0, v1 = h
    v0 = max(v0, FL)
    door = v0 <= FL + 0.01
    def P(u, y, out):
        return ugms._uv(axis, u, c, y, nrm * out)
    def S(su, sy, sd):
        return (su, sy, sd) if axis == 0 else (sd, sy, su)
    mid = FACE / 2 + 0.01
    for u in (u0, u1):
        box(P(u, (v0 + v1) / 2, mid), S(0.025, v1 - v0, FACE + 0.02), M["reveal"])
    box(P((u0 + u1) / 2, v1, mid), S(u1 - u0, 0.025, FACE + 0.02), M["reveal"])
    if not door:
        box(P((u0 + u1) / 2, v0, mid), S(u1 - u0, 0.025, FACE + 0.02), M["reveal"])
    else:
        # Порог в дверном проёме: закрывает 20-сантиметровый зазор между комнатами
        box(P((u0 + u1) / 2, FL - 0.015, mid), S(u1 - u0, 0.03, FACE + 0.02), M.get(floor_key, M["floor"]))
    f = FACE + 0.035
    w = 0.08
    for u in (u0 - w / 2, u1 + w / 2):
        box(P(u, (v0 + v1 + (0.0 if door else 0.0)) / 2 + w / 2, f), S(w, v1 - v0 + w, 0.025), M["trim"])
    box(P((u0 + u1) / 2, v1 + w / 2, f), S(u1 - u0 + 2 * w, w, 0.025), M["trim"])
    if not door:
        box(P((u0 + u1) / 2, v0 - w / 2, f), S(u1 - u0 + 2 * w, w, 0.025), M["trim"])


def floor_ceiling(M, x0, x1, z0, z1, floor_key, beams_along_z=True, ceil_key="whitewash", beam=True):
    xa, xb, za, zb = x0 + FACE, x1 - FACE, z0 + FACE, z1 - FACE
    box(((xa + xb) / 2, FL - 0.015, (za + zb) / 2), (xb - xa, 0.03, zb - za), M[floor_key])
    box(((xa + xb) / 2, H - 0.01, (za + zb) / 2), (xb - xa, 0.02, zb - za), M[ceil_key])
    if beam:
        if beams_along_z:
            n = max(1, int((xb - xa) / 1.2))
            for i in range(1, n):
                x = xa + i * (xb - xa) / n
                box((x, H - 0.07, (za + zb) / 2), (0.12, 0.12, zb - za), M["beam"])
        else:
            n = max(1, int((zb - za) / 1.2))
            for i in range(1, n):
                z = za + i * (zb - za) / n
                box(((xa + xb) / 2, H - 0.07, z), (xb - xa, 0.12, 0.12), M["beam"])


DOOR_H = 2.1


ONLY = [a for a in sys.argv if a.startswith("house_int_")]   # -- <out_dir> house_int_store … — только эти комнаты


def room(name, x0, x1, z0, z1, holes, lower, upper, floor_key, res, divider=True, beams_along_z=True, ceil_key="whitewash"):
    if ONLY and name not in ONLY:
        return
    kit.reset()
    M = mats()
    # N: z = z0 (внутрь +Z), S: z = z1 (внутрь −Z), W: x = x0 (внутрь +X), E: x = x1 (внутрь −X)
    wall(M, 0, z0, +1, x0 + FACE, x1 - FACE, holes.get("N", []), lower, upper, divider, floor_key)
    wall(M, 0, z1, -1, x0 + FACE, x1 - FACE, holes.get("S", []), lower, upper, divider, floor_key)
    wall(M, 2, x0, +1, z0 + FACE, z1 - FACE, holes.get("W", []), lower, upper, divider, floor_key)
    wall(M, 2, x1, -1, z0 + FACE, z1 - FACE, holes.get("E", []), lower, upper, divider, floor_key)
    floor_ceiling(M, x0, x1, z0, z1, floor_key, beams_along_z, ceil_key)
    obj, img, tris = kit.finish(name, OUT, res=res, origin="keep", samples=32, pack=0.003, ao_blur=3, ao_min=0.45)
    kit.export(os.path.join(OUT, name + ".glb"), None)
    print(f"[OK] {name}: {tris} tris")


D = lambda a, b: [a, b, 0.0, DOOR_H]
room("house_int_living", -2.5, 3.5, 0.0, 6.6,
     {"S": [[0.0, 1.0, 1.1, 1.9]], "W": [[2.75, 3.85, 1.05, 1.85]], "E": [D(2.6, 3.7)]},
     "lining", "wallpaper", "floor", 2048, divider=False)
room("house_int_radio", 3.5, 11.5, -2.0, 2.2,
     {"N": [D(4.8, 5.8), [8.6, 9.8, 1.05, 1.85]], "S": [D(7.0, 8.1)]},
     "panel_green", "whitewash", "floor", 2048)
room("house_int_corridor", 3.5, 11.5, 2.2, 6.6,
     {"N": [D(7.0, 8.1)], "S": [[7.1, 7.9, 1.2, 2.0]], "W": [D(2.6, 3.7)], "E": [D(2.6, 3.7)]},
     "panel_blue", "whitewash", "floor", 2048)
room("house_int_store", 3.5, 7.0, -5.5, -2.0, {"S": [D(4.8, 5.8)]},
     "plank", "plank", "floor_raw", 2048, divider=False, beams_along_z=False, ceil_key="floor_raw")
room("house_int_vest", 11.5, 14.5, 1.5, 6.6, {"W": [D(2.6, 3.7)], "E": [D(2.6, 3.6)]},
     "plank", "plank", "floor_raw", 2048, divider=False, ceil_key="floor_raw")
