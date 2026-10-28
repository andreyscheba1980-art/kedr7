# «Кедр-7» — снегоход «Буран» С-640 (одна лыжа, две гусеницы). Нос смотрит в +Y (в Godot −Z).
# Запуск: blender --background --python buran.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat, text

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

ORANGE = mat("bur_orange", (0.72, 0.26, 0.05), rough=0.45, wear=0.7, dirt=0.6, wear_col=(0.55, 0.5, 0.45))
CREAM = mat("bur_cream", (0.72, 0.70, 0.62), rough=0.55, wear=0.5, dirt=0.65)
BLACK = mat("bur_black", (0.04, 0.04, 0.045), rough=0.5, wear=0.3, dirt=0.5)
SEAT = mat("bur_seat", (0.06, 0.055, 0.05), rough=0.65, wear=0.6, dirt=0.4, wear_col=(0.2, 0.18, 0.16))
STEEL = mat("bur_steel", (0.2, 0.21, 0.22), rough=0.4, wear=0.8, dirt=0.6, wear_col=(0.55, 0.56, 0.58))
RUBBER = mat("bur_rubber", (0.05, 0.05, 0.05), rough=0.9, wear=0.4, dirt=0.8)
GLASS = mat("bur_glass", (0.35, 0.42, 0.45), rough=0.15, dirt=0.3)
LAMP = mat("bur_lamp", (0.9, 0.88, 0.78), rough=0.1)
RED = mat("bur_red", (0.6, 0.04, 0.03), rough=0.3)
SNOW = mat("bur_snow", (0.88, 0.92, 0.96), rough=0.95)

D = math.radians
# --- Гусеницы и тоннель (зад, y < 0) ---
for sx in (-0.21, 0.21):
    box(f"track{sx}", (0.36, 1.7, 0.3), (sx, -0.55, 0.17), RUBBER, 0.03)
    for yy in (-1.4, 0.3):
        cyl(f"trackend{sx}{yy}", 0.15, 0.36, (sx, yy, 0.17), RUBBER, rot=(0, D(90), 0), verts=16)
    for k in range(9):   # грунтозацепы сверху (видны из-под тоннеля)
        box(f"lug{sx}{k}", (0.37, 0.04, 0.02), (sx, -1.35 + k * 0.2, 0.33), STEEL, 0.004)
box("tunnel", (0.94, 1.95, 0.06), (0, -0.55, 0.38), ORANGE, 0.01)
for sx in (-0.47, 0.47):
    box(f"tunnel_side{sx}", (0.03, 1.95, 0.2), (sx, -0.55, 0.3), ORANGE, 0.005)
    box(f"foot{sx}", (0.16, 1.15, 0.03), (sx * 1.18, -0.35, 0.28), STEEL, 0.004)
    for k in range(5):
        box(f"footrib{sx}{k}", (0.16, 0.02, 0.025), (sx * 1.18, -0.85 + k * 0.25, 0.3), BLACK, 0.002)
# Сиденье двухместное + спинка
box("seat", (0.5, 1.15, 0.17), (0, -0.55, 0.5), SEAT, 0.05)
box("seat_seam", (0.51, 0.02, 0.17), (0, -0.4, 0.5), BLACK, 0.004)
box("seat_back", (0.46, 0.12, 0.2), (0, -1.15, 0.65), SEAT, 0.04)
# Багажник и бампер
tube("rack", [(-0.42, -1.25, 0.45), (-0.42, -1.55, 0.5), (0.42, -1.55, 0.5), (0.42, -1.25, 0.45)], 0.018, STEEL)
tube("bumper", [(-0.46, -1.45, 0.25), (-0.46, -1.62, 0.3), (0.46, -1.62, 0.3), (0.46, -1.45, 0.25)], 0.022, STEEL)
box("flap", (0.8, 0.02, 0.28), (0, -1.5, 0.15), BLACK, 0.003, rot=(D(-10), 0, 0))
box("taillight", (0.14, 0.03, 0.06), (0, -1.535, 0.4), RED, 0.01)
# --- Капот (перед, y > 0) ---
box("belly", (0.92, 1.05, 0.28), (0, 0.48, 0.32), CREAM, 0.04)
box("stripe", (0.94, 1.0, 0.05), (0, 0.48, 0.47), BLACK, 0.01)
box("hood", (0.9, 0.85, 0.3), (0, 0.4, 0.64), ORANGE, 0.06, rot=(D(-6), 0, 0))
box("nose", (0.88, 0.5, 0.3), (0, 1.0, 0.48), ORANGE, 0.06, rot=(D(30), 0, 0))
box("console", (0.6, 0.25, 0.2), (0, -0.02, 0.76), BLACK, 0.03)
for sx in (-1, 1):
    box(f"vent{sx}", (0.02, 0.4, 0.12), (sx * 0.455, 0.45, 0.6), BLACK, 0.003)
    text("БУРАН", 0.12, (sx * 0.462, 0.5, 0.36), CREAM, rot=(D(90), 0, D(90) * sx))
# Фара и стекло
cyl("lamp_rim", 0.1, 0.06, (0, 0.88, 0.76), STEEL, rot=(D(90 - 30), 0, 0), verts=20)
cyl("lamp", 0.085, 0.03, (0, 0.905, 0.775), LAMP, rot=(D(90 - 30), 0, 0), verts=20)
ws = box("windshield", (0.62, 0.02, 0.26), (0, 0.16, 0.9), GLASS, 0.02, rot=(D(-38), 0, 0))
for v in ws.data.vertices:
    if v.co.z > 0: v.co.x *= 0.7
# Руль
cyl("column", 0.025, 0.3, (0, 0.0, 0.9), STEEL, rot=(D(-20), 0, 0), verts=10)
tube("bar", [(-0.38, -0.08, 1.02), (-0.2, -0.04, 1.04), (0.2, -0.04, 1.04), (0.38, -0.08, 1.02)], 0.016, STEEL)
for sx in (-1, 1):
    cyl(f"grip{sx}", 0.024, 0.12, (sx * 0.37, -0.08, 1.02), RUBBER, rot=(0, D(90), 0), verts=10)
# Лыжа и амортизатор
box("ski", (0.2, 1.0, 0.035), (0, 1.15, 0.02), STEEL, 0.006)
box("ski_tip", (0.2, 0.32, 0.035), (0, 1.75, 0.12), STEEL, 0.006, rot=(D(35), 0, 0))
box("ski_keel", (0.03, 0.9, 0.03), (0, 1.15, -0.0), STEEL, 0.003)
cyl("strut", 0.035, 0.38, (0, 1.05, 0.22), STEEL, rot=(D(12), 0, 0), verts=12)
cyl("spring", 0.055, 0.2, (0, 1.06, 0.25), BLACK, rot=(D(12), 0, 0), verts=12)
tube("ski_handle", [(0, 1.55, 0.06), (0, 1.75, 0.3), (0, 1.86, 0.3)], 0.014, STEEL)
# Иней на капоте и сиденье

obj, img, tris = kit.finish("buran", OUT, res=1024, origin="bottom", samples=32)
kit.export(os.path.join(OUT, "buran.glb"), os.path.join(OUT, "buran.blend"))
print("[OK] buran tris:", tris)
