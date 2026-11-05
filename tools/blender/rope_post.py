# «Кедр-7» — леерный столбик (их во дворе больше всего — аудит autotest --propaudit): тёсаный восьмигранный
# кол с трещинами и сучками, стёсанный оголовок, рым-скоба на гвоздях, комковатая снежная шапка, снег у комля.
# (Бочка и поленница уже есть моделями: soviet_barrel.glb, woodshed.glb — yard_props.py.) Нос в −Y (в Godot +Z), низ на z = 0. Запуск: blender --background --python yard_props.py -- <out_dir>
import bpy, bmesh, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube, mat
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
PROP = os.environ.get("PROP", "rope_post")
os.makedirs(OUT, exist_ok=True)
kit.reset()
rnd = random.Random(7)

SNOW = mat("snow", (0.86, 0.9, 0.96), rough=0.95, noise=0.08, noise_scale=30)
WOOD = mat("wood", (0.36, 0.3, 0.23), rough=0.9, noise=0.35, noise_scale=55, wear=0.6, dirt=0.8, wear_col=(0.52, 0.46, 0.38))
WOOD_D = mat("wood_d", (0.22, 0.18, 0.14), rough=0.9, noise=0.3, noise_scale=40, wear=0.4, dirt=0.8, wear_col=(0.36, 0.3, 0.24))
IRON = mat("iron", (0.2, 0.19, 0.18), rough=0.55, noise=0.25, noise_scale=40, wear=0.8, dirt=0.5, wear_col=(0.45, 0.28, 0.16))


def lumpy(o, amount, scale=6.0):
    for v in o.data.vertices:
        v.co += v.normal * noise.noise(v.co * scale) * amount


def crack_lines(x, y0, y1, n, m):
    for i in range(n):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(y0, y1)
        box(f"crack{i}", (0.004, 0.004, rnd.uniform(0.12, 0.35)), (math.cos(a) * x, math.sin(a) * x, z), m, 0.0,
            rot=(0, 0, a))


if PROP == "rope_post":
    # Тёсаный восьмигранный кол, к верху тоньше; сучки, продольные трещины
    c = cyl("post", 0.044, 1.34, (0, 0, 0.67), WOOD, rot=(0, 0, 0), verts=8, r2=0.037)
    lumpy(c, 0.004, 14)
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.3, 1.1)
        sphere(f"knot{i}", 0.012, (math.cos(a) * 0.04, math.sin(a) * 0.04, z), WOOD_D, scale=(1, 1, 1.4), segs=6, rings=4)
    crack_lines(0.041, 0.25, 1.15, 4, WOOD_D)
    # Оголовок: стёсанный конус и шапка снега, комковатая
    cyl("cap", 0.04, 0.05, (0, 0, 1.365), WOOD_D, rot=(0, 0, 0), verts=8, r2=0.02)
    s = sphere("snowcap", 0.055, (0.004, 0, 1.4), SNOW, scale=(1.05, 1.0, 0.5), segs=10, rings=6)
    lumpy(s, 0.008, 9)
    # Рым-скоба для троса — полукольцо на высоте 1.05 вбок (+X), шляпки гвоздей
    kit.torus("ring", 0.028, 0.0055, (0.06, 0, 1.05), IRON, rot=(math.pi / 2, 0, 0), maj=14, mino=6)
    for dz in (-0.03, 0.03):
        sphere(f"nail{dz}", 0.007, (0.043, 0, 1.05 + dz), IRON, segs=6, rings=4)
    # Утоптанный снег у комля
    b = sphere("drift", 0.18, (0, 0, 0.02), SNOW, scale=(1.0, 0.9, 0.32), segs=14, rings=7)
    lumpy(b, 0.02, 4)
    NAME = "rope_post"

obj, img, tris = kit.finish(NAME, OUT, res=1024, origin="bottom", samples=24)
kit.export(os.path.join(OUT, NAME + ".glb"), os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris)
