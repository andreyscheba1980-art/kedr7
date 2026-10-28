# «Кедр-7» — набор моделей 2: выезды (АМС, аккумулятор, кейс с пробами), интерьеры (полка с банками,
# вешалка, книги, мелочи на стол), двор (бельё на верёвке), просека (поклонный крест, жестянки на верёвке,
# лабаз, лосиный череп на шесте). PART = имя. Перед — −Y (в Godot +Z), низ на z = 0.
import bpy, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import mat, box, cyl, sphere, tube, torus, text
from mathutils import Vector, noise

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
PART = os.environ.get("PART", "ams_post")
os.makedirs(OUT, exist_ok=True)
kit.reset()
random.seed(hash(PART) % 1000)
UP = (0, 0, 0)            # cyl вертикально


def vcyl(name, r, h, base, m, verts=12, r2=None):
    return cyl(name, r, h, Vector(base) + Vector((0, 0, h / 2)), m, rot=UP, verts=verts, r2=r2)


def rod(name, a, b, r, m, verts=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.name = name
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    return o


def lumpy(o, amt, sc=4.0):
    for v in o.data.vertices:
        v.co += v.normal * noise.noise(v.co * sc) * amt


SNOW = mat("snow", (0.62, 0.68, 0.76), rough=1.0, noise=0.12, noise_scale=30)
WOOD = mat("wood", (0.36, 0.27, 0.18), rough=0.85, noise=0.25, noise_scale=40, wear=0.4, wear_col=(0.5, 0.42, 0.3))
OLDWOOD = mat("oldwood", (0.3, 0.27, 0.23), rough=0.95, noise=0.3, noise_scale=30, wear=0.5, wear_col=(0.44, 0.4, 0.34))
ROPE = mat("rope", (0.42, 0.37, 0.27), rough=1.0, noise=0.2, noise_scale=120)
INK = mat("ink", (0.05, 0.05, 0.05), rough=0.9)

if PART == "ams_post":
    # Автоматическая метеостанция «М-106» на просеке: мачта-труба на оттяжках, анеморумбометр,
    # жалюзийная будочка датчиков, серый шкаф с аккумулятором и радиоблоком, штыревая антенна.
    GREY = mat("grey", (0.4, 0.42, 0.42), rough=0.6, noise=0.15, noise_scale=50, wear=0.6, wear_col=(0.5, 0.3, 0.18))
    WHITE = mat("white", (0.72, 0.72, 0.68), rough=0.8, noise=0.1, noise_scale=40, wear=0.5, wear_col=(0.4, 0.3, 0.2))
    DARK = mat("dark", (0.1, 0.1, 0.1), rough=0.5)
    RED = mat("red", (0.55, 0.1, 0.07), rough=0.8, wear=0.5)
    CONC = mat("conc", (0.45, 0.44, 0.42), rough=1.0, noise=0.3, noise_scale=25)
    box("base", (0.9, 0.9, 0.25), (0, 0, 0.12), CONC, 0.01)
    vcyl("mast", 0.045, 4.6, (0, 0, 0.2), GREY)
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.5
        g = Vector((math.cos(a) * 2.4, math.sin(a) * 2.4, 0.05))
        rod(f"guy{k}", (0, 0, 3.6), g, 0.006, DARK, 4)
        vcyl(f"anchor{k}", 0.05, 0.25, g - Vector((0, 0, 0.05)), CONC, 6)
    # Траверса наверху: анемометр (чашки) и флюгер
    rod("arm", (-0.6, 0, 4.6), (0.6, 0, 4.6), 0.025, GREY)
    vcyl("anem_shaft", 0.015, 0.25, (-0.6, 0, 4.6), GREY)
    for k in range(3):
        a = k * 2 * math.pi / 3
        e = Vector((-0.6 + math.cos(a) * 0.16, math.sin(a) * 0.16, 4.86))
        rod(f"cuparm{k}", (-0.6, 0, 4.86), e, 0.006, GREY, 4)
        sphere(f"cup{k}", 0.05, e, GREY, scale=(1, 1, 1), segs=10, rings=6)
    vcyl("vane_shaft", 0.015, 0.3, (0.6, 0, 4.6), GREY)
    box("vane_tail", (0.3, 0.01, 0.16), (0.78, 0, 4.88), RED, 0.002)
    rod("vane_nose", (0.6, 0, 4.88), (0.42, 0, 4.88), 0.012, GREY, 6)
    sphere("vane_weight", 0.03, (0.42, 0, 4.88), DARK, segs=8, rings=5)
    # Будочка датчиков на кронштейне
    rod("bracket", (0, 0, 2.2), (0, -0.45, 2.2), 0.02, GREY, 6)
    box("screen", (0.34, 0.3, 0.38), (0, -0.55, 2.2), WHITE, 0.01)
    for k in range(5):
        box(f"louver{k}", (0.35, 0.31, 0.012), (0, -0.55, 2.04 + k * 0.08), WHITE, 0.0)
    box("screen_roof", (0.42, 0.38, 0.03), (0, -0.55, 2.42), WHITE, 0.004)
    box("screen_snow", (0.4, 0.36, 0.05), (0, -0.55, 2.46), SNOW, 0.01)
    # Шкаф: на двух ножках у мачты, дверца к −Y
    vcyl("legL", 0.025, 0.7, (0.35, -0.55, 0.0), GREY, 8)
    vcyl("legR", 0.025, 0.7, (0.95, -0.55, 0.0), GREY, 8)
    box("cab", (0.7, 0.36, 0.85), (0.65, -0.55, 1.12), GREY, 0.01)
    box("door", (0.64, 0.02, 0.78), (0.65, -0.74, 1.12), GREY, 0.004)
    box("handle", (0.03, 0.03, 0.12), (0.92, -0.76, 1.12), DARK, 0.004)
    box("stripe", (0.645, 0.022, 0.06), (0.65, -0.745, 1.42), RED, 0.0)
    text("АМС", 0.09, (0.58, -0.7525, 1.27), INK)
    box("plate", (0.16, 0.005, 0.08), (0.45, -0.7525, 0.92), WHITE, 0.0)
    box("cab_snow", (0.74, 0.4, 0.06), (0.65, -0.55, 1.58), SNOW, 0.015)
    rod("ant", (0.88, -0.45, 1.55), (0.88, -0.45, 3.1), 0.006, DARK, 4)
    sphere("ant_tip", 0.015, (0.88, -0.45, 3.1), DARK, segs=6, rings=4)
    rod("cable", (0.32, -0.55, 1.3), (0.04, -0.05, 1.6), 0.012, DARK, 6)
    rod("cable2", (0.04, -0.05, 1.6), (0.04, -0.05, 4.4), 0.01, DARK, 6)
    snow = sphere("drift", 1.0, (0.2, 0.0, 0.0), SNOW, scale=(1.2, 1.0, 0.18), segs=14, rings=7)
    lumpy(snow, 0.15, 2.0)
    NAME = "ams_post"
elif PART == "akb":
    BLACK = mat("akb", (0.08, 0.08, 0.085), rough=0.4, noise=0.1, noise_scale=60, wear=0.3, wear_col=(0.25, 0.25, 0.25))
    LEAD = mat("lead", (0.38, 0.38, 0.4), rough=0.5)
    REDC = mat("redc", (0.6, 0.12, 0.08), rough=0.6)
    LBL = mat("lbl", (0.7, 0.66, 0.5), rough=0.9, noise=0.2, noise_scale=40, wear=0.3)
    box("body", (0.52, 0.23, 0.22), (0, 0, 0.11), BLACK, 0.008)
    box("lid", (0.53, 0.24, 0.03), (0, 0, 0.235), BLACK, 0.006)
    for k in range(6):
        vcyl(f"cap{k}", 0.016, 0.02, (-0.2 + k * 0.08, 0.03, 0.25), BLACK, 8)
    vcyl("termA", 0.018, 0.04, (-0.22, -0.07, 0.25), LEAD, 8)
    vcyl("termB", 0.018, 0.04, (0.22, -0.07, 0.25), LEAD, 8)
    vcyl("termAc", 0.022, 0.012, (-0.22, -0.07, 0.29), REDC, 8)
    box("label", (0.22, 0.004, 0.09), (0.0, -0.117, 0.13), LBL, 0.0)
    text("6СТ-190", 0.03, (0.0, -0.1195, 0.14), INK)
    tube("rope", [(-0.24, 0.0, 0.25), (-0.18, 0.0, 0.36), (0.18, 0.0, 0.36), (0.24, 0.0, 0.25)], 0.008, ROPE, 6)
    NAME = "akb"
elif PART == "sample_case":
    ALU = mat("alu", (0.55, 0.57, 0.58), rough=0.4, noise=0.15, noise_scale=40, wear=0.5, wear_col=(0.35, 0.35, 0.35))
    DARK = mat("dark", (0.12, 0.12, 0.12), rough=0.5)
    YEL = mat("yel", (0.7, 0.55, 0.12), rough=0.7, wear=0.5)
    box("case", (0.5, 0.3, 0.24), (0, 0, 0.12), ALU, 0.012)
    box("rim", (0.51, 0.31, 0.02), (0, 0, 0.16), ALU, 0.004)
    for sx in (-0.15, 0.15):
        box(f"latch{sx}", (0.04, 0.02, 0.05), (sx, -0.155, 0.16), DARK, 0.003)
    tube("handle", [(-0.07, 0, 0.24), (-0.07, 0, 0.29), (0.07, 0, 0.29), (0.07, 0, 0.24)], 0.009, DARK, 6)
    box("tag", (0.2, 0.004, 0.07), (0.0, -0.152, 0.08), YEL, 0.0)
    text("ПРОБЫ", 0.035, (0.0, -0.1545, 0.08), INK)
    NAME = "sample_case"
elif PART == "shelf_jars":
    # Полка на стену 1.2 м, две доски на кронштейнах; банки с вареньем, огурцами, тушёнка, бидон, свёртки
    GLASS_R = mat("jar_r", (0.42, 0.08, 0.06), rough=0.2, noise=0.2, noise_scale=30)
    GLASS_G = mat("jar_g", (0.32, 0.38, 0.18), rough=0.2, noise=0.3, noise_scale=20)
    GLASS_O = mat("jar_o", (0.6, 0.35, 0.08), rough=0.2, noise=0.2, noise_scale=30)
    LIDM = mat("lid", (0.55, 0.52, 0.42), rough=0.4, wear=0.4)
    TIN = mat("tin", (0.5, 0.5, 0.48), rough=0.4, wear=0.5, wear_col=(0.45, 0.25, 0.15))
    LBL = mat("lbl", (0.68, 0.6, 0.42), rough=0.9, noise=0.2, noise_scale=40)
    PAPER = mat("paper", (0.62, 0.56, 0.44), rough=1.0, noise=0.2, noise_scale=30)
    BLUE = mat("enamel", (0.22, 0.32, 0.48), rough=0.4, wear=0.6, wear_col=(0.12, 0.1, 0.08))
    for z in (0.0, 0.45):
        box(f"board{z}", (1.2, 0.24, 0.025), (0, 0, 0.6 + z), WOOD, 0.004)
        for sx in (-0.5, 0.5):
            box(f"brk{z}{sx}", (0.03, 0.2, 0.025), (sx, 0.02, 0.58 + z - 0.06), WOOD, 0.002, rot=(math.radians(-35), 0, 0))
    x = -0.54
    jars = [GLASS_R, GLASS_G, GLASS_G, GLASS_O, GLASS_R, GLASS_G]
    for k, gm in enumerate(jars):
        h = random.uniform(0.14, 0.2)
        vcyl(f"jar{k}", 0.045, h, (x, -0.02, 0.613), gm, 12)
        vcyl(f"jarlid{k}", 0.047, 0.015, (x, -0.02, 0.613 + h), LIDM, 12)
        if k % 2 == 0:
            box(f"jlbl{k}", (0.05, 0.004, 0.04), (x, -0.066, 0.613 + h * 0.45), LBL, 0.0)
        x += 0.105
    # Тушёнка пирамидой и бидон
    for k in range(3):
        vcyl(f"tin{k}", 0.042, 0.08, (0.2 + k * 0.088, -0.03, 0.613), TIN, 12)
    vcyl("tin3", 0.042, 0.08, (0.244, -0.03, 0.693), TIN, 12)
    vcyl("tin4", 0.042, 0.08, (0.332, -0.03, 0.693), TIN, 12)
    vcyl("bidon", 0.07, 0.26, (0.5, -0.02, 1.063), BLUE, 14, r2=None)
    vcyl("bidon_neck", 0.04, 0.06, (0.5, -0.02, 1.323), BLUE, 12)
    torus("bidon_handle", 0.05, 0.006, (0.5, -0.02, 1.4), BLUE, rot=(math.pi / 2, 0, 0), maj=12, mino=4)
    # Свёртки и коробки на верхней полке
    for k in range(3):
        b = sphere(f"bundle{k}", 1.0, (-0.45 + k * 0.17, -0.01, 1.11), PAPER, scale=(0.08, 0.09, 0.06), segs=10, rings=6)
        lumpy(b, 0.015, 30.0)
    box("box1", (0.22, 0.16, 0.12), (0.05, 0.0, 1.123), PAPER, 0.004)
    box("box2", (0.16, 0.12, 0.08), (0.06, 0.0, 1.223), LBL, 0.004)
    NAME = "shelf_jars"
elif PART == "coat_hooks":
    KHAKI = mat("vatnik", (0.2, 0.22, 0.17), rough=0.95, noise=0.25, noise_scale=90, wear=0.25, wear_col=(0.3, 0.3, 0.24))
    FUR = mat("fur", (0.25, 0.2, 0.16), rough=1.0, noise=0.4, noise_scale=150)
    SCARF = mat("scarf", (0.45, 0.12, 0.1), rough=1.0, noise=0.3, noise_scale=100)
    BAG = mat("bag", (0.3, 0.3, 0.22), rough=0.9, noise=0.25, noise_scale=60, wear=0.4)
    IRON = mat("iron", (0.15, 0.15, 0.15), rough=0.5)
    box("board", (1.1, 0.03, 0.12), (0, 0.0, 1.7), WOOD, 0.004)
    for k in range(4):
        x = -0.4 + k * 0.27
        rod(f"hook{k}", (x, -0.015, 1.68), (x, -0.08, 1.74), 0.007, IRON, 6)
    # Ватник: корпус-«мешок» с рукавами, стёжка — шумом
    v = sphere("coat", 1.0, (-0.4, -0.1, 1.25), KHAKI, scale=(0.22, 0.09, 0.42), segs=16, rings=10)
    for p in v.data.vertices:
        p.co.x *= 1.0 + 0.25 * max(0.0, -p.co.z)
        p.co += p.normal * abs(math.sin(p.co.x * 60)) * 0.008
    for sx in (-1, 1):
        s = sphere(f"sleeve{sx}", 1.0, (-0.4 + sx * 0.2, -0.1, 1.2), KHAKI, scale=(0.06, 0.07, 0.3), segs=10, rings=6)
    sphere("collar", 1.0, (-0.4, -0.1, 1.64), FUR, scale=(0.13, 0.08, 0.05), segs=10, rings=6)
    # Ушанка
    u = sphere("ushanka", 1.0, (-0.13, -0.11, 1.62), FUR, scale=(0.13, 0.12, 0.1), segs=12, rings=8)
    lumpy(u, 0.06, 10.0)
    for sx in (-1, 1):
        sphere(f"flap{sx}", 1.0, (-0.13 + sx * 0.12, -0.11, 1.52), FUR, scale=(0.03, 0.08, 0.08), segs=8, rings=5)
    # Шарф свисает с третьего крючка, сумка-планшет на четвёртом
    tube("scarf", [(0.14, -0.08, 1.74), (0.12, -0.09, 1.4), (0.15, -0.085, 1.1)], 0.03, SCARF, 8)
    tube("scarf2", [(0.18, -0.08, 1.74), (0.2, -0.09, 1.3)], 0.028, SCARF, 8)
    rod("strap", (0.41, -0.08, 1.74), (0.41, -0.09, 1.35), 0.01, BAG, 6)
    box("bag", (0.28, 0.08, 0.22), (0.41, -0.1, 1.24), BAG, 0.02)
    box("bagflap", (0.28, 0.01, 0.12), (0.41, -0.145, 1.29), BAG, 0.01)
    NAME = "coat_hooks"
elif PART == "books":
    cols = [(0.4, 0.12, 0.1), (0.18, 0.26, 0.38), (0.3, 0.32, 0.2), (0.5, 0.42, 0.28), (0.22, 0.2, 0.18), (0.45, 0.35, 0.15)]
    PAGES = mat("pages", (0.72, 0.68, 0.56), rough=1.0)
    z = 0.0
    for k in range(5):
        c = mat(f"cov{k}", cols[k % len(cols)], rough=0.8, noise=0.15, noise_scale=40, wear=0.6, wear_col=(0.5, 0.45, 0.38))
        w, d, h = random.uniform(0.17, 0.24), random.uniform(0.12, 0.16), random.uniform(0.02, 0.045)
        rz = random.uniform(-0.25, 0.25)
        box(f"cover{k}", (w, d, h), (random.uniform(-0.01, 0.01), 0, z + h / 2), c, 0.002, rot=(0, 0, rz))
        box(f"pages{k}", (w - 0.01, d - 0.008, h - 0.006), (random.uniform(-0.01, 0.01) + 0.004, 0, z + h / 2), PAGES, 0.0, rot=(0, 0, rz))
        z += h
    # Журнал «Метеорология и гидрология» сверху, раскрытый блокнот рядом
    jm = mat("journal", (0.62, 0.6, 0.5), rough=1.0, noise=0.15, noise_scale=30)
    box("journal", (0.2, 0.27, 0.006), (0.0, 0.0, z + 0.003), jm, 0.0, rot=(0, 0, 0.3))
    text("МиГ", 0.04, (0.02, -0.04, z + 0.0065), INK, rot=(0, 0, 0.3))
    box("note_l", (0.1, 0.15, 0.008), (0.24, 0.02, 0.004), PAGES, 0.0, rot=(0, math.radians(4), 0.1))
    box("note_r", (0.1, 0.15, 0.008), (0.34, 0.03, 0.004), PAGES, 0.0, rot=(0, math.radians(-4), 0.1))
    for k in range(5):
        box(f"line{k}", (0.07, 0.002, 0.001), (0.34, 0.0 + k * 0.02, 0.009), INK, 0.0, rot=(0, 0, 0.1))
    NAME = "books"
elif PART == "table_clutter":
    ENAM = mat("enamel_w", (0.78, 0.76, 0.7), rough=0.3, wear=0.7, wear_col=(0.1, 0.1, 0.1))
    BLUE = mat("enamel_b", (0.2, 0.3, 0.5), rough=0.3)
    GLASS = mat("ashtray", (0.3, 0.38, 0.36), rough=0.2)
    BUTT = mat("butt", (0.75, 0.7, 0.6), rough=1.0)
    ASH = mat("ash", (0.3, 0.3, 0.3), rough=1.0)
    PAPER = mat("paper", (0.7, 0.66, 0.55), rough=1.0, noise=0.2, noise_scale=40)
    NEWS = mat("news", (0.6, 0.58, 0.52), rough=1.0, noise=0.35, noise_scale=200)
    MATCH = mat("match", (0.55, 0.42, 0.2), rough=0.9)
    TEA = mat("tea", (0.18, 0.08, 0.03), rough=0.1)
    vcyl("mug", 0.045, 0.09, (0, 0, 0), ENAM, 16)
    vcyl("mugrim", 0.046, 0.008, (0, 0, 0.088), BLUE, 16)
    vcyl("tea", 0.04, 0.002, (0, 0, 0.075), TEA, 12)
    torus("mughandle", 0.028, 0.006, (0.055, 0, 0.045), ENAM, rot=(math.pi / 2, 0, 0), maj=12, mino=4)
    vcyl("ashtray", 0.06, 0.025, (0.18, 0.05, 0), GLASS, 10)
    vcyl("ash", 0.05, 0.004, (0.18, 0.05, 0.02), ASH, 10)
    for k in range(4):
        a = k * 1.4
        rod(f"butt{k}", (0.18 + math.cos(a) * 0.01, 0.05 + math.sin(a) * 0.01, 0.026), (0.18 + math.cos(a) * 0.05, 0.05 + math.sin(a) * 0.05, 0.032), 0.005, BUTT, 6)
    box("matchbox", (0.05, 0.035, 0.015), (0.12, -0.08, 0.0075), MATCH, 0.001, rot=(0, 0, 0.4))
    box("paper1", (0.21, 0.297, 0.002), (-0.2, 0.05, 0.001), PAPER, 0.0, rot=(0, 0, -0.2))
    box("paper2", (0.21, 0.297, 0.002), (-0.17, 0.08, 0.003), PAPER, 0.0, rot=(0, 0, 0.15))
    for k in range(8):
        box(f"pl{k}", (0.15, 0.003, 0.001), (-0.17, -0.02 + k * 0.025, 0.0045), INK, 0.0, rot=(0, 0, 0.15))
    box("news", (0.3, 0.42, 0.004), (0.05, 0.22, 0.002), NEWS, 0.0, rot=(0, 0, 0.6))
    text("ПРАВДА", 0.045, (0.03, 0.15, 0.0045), INK, rot=(0, 0, 0.6))
    rod("pencil", (-0.08, -0.12, 0.004), (0.06, -0.15, 0.004), 0.004, mat("pencil", (0.2, 0.35, 0.2), rough=0.6), 6)
    NAME = "table_clutter"
elif PART == "laundry_line":
    WHITEC = mat("linen", (0.62, 0.62, 0.58), rough=1.0, noise=0.2, noise_scale=40)
    STRIPE = mat("towel", (0.6, 0.58, 0.52), rough=1.0, noise=0.2, noise_scale=40)
    REDS = mat("redst", (0.5, 0.1, 0.08), rough=1.0)
    GREYC = mat("johns", (0.42, 0.42, 0.4), rough=1.0, noise=0.25, noise_scale=60)
    FROSTM = mat("frost", (0.7, 0.75, 0.8), rough=1.0, noise=0.2, noise_scale=80)
    for sx in (-2.6, 2.6):
        vcyl(f"post{sx}", 0.06, 1.95, (sx, 0, 0), OLDWOOD, 7)
        rod(f"cross{sx}", (sx, -0.25, 1.85), (sx, 0.25, 1.85), 0.03, OLDWOOD, 6)
    pts = [Vector((-2.6 + 5.2 * t / 10, 0.0, 1.86 - 0.18 * math.sin(math.pi * t / 10))) for t in range(11)]
    tube("line", pts, 0.006, ROPE, 4)
    def ly(x):
        return 1.86 - 0.18 * math.sin(math.pi * (x + 2.6) / 5.2)
    # Рубаха — колом от мороза: корпус + рукава в стороны
    x = -1.6
    box("shirt", (0.5, 0.03, 0.62), (x, 0, ly(x) - 0.31), WHITEC, 0.02, rot=(0.05, 0, 0))
    for sx in (-1, 1):
        box(f"shirt_sl{sx}", (0.2, 0.025, 0.42), (x + sx * 0.32, 0, ly(x) - 0.2), WHITEC, 0.015, rot=(0, sx * 0.5, 0))
    # Кальсоны
    x = -0.5
    box("johns_top", (0.4, 0.03, 0.18), (x, 0, ly(x) - 0.09), GREYC, 0.015)
    for sx in (-1, 1):
        box(f"leg{sx}", (0.16, 0.03, 0.75), (x + sx * 0.11, 0, ly(x) - 0.5), GREYC, 0.015, rot=(0, sx * 0.06, 0))
    # Полотенце с красной полосой
    x = 0.55
    box("towel", (0.45, 0.02, 0.7), (x, 0, ly(x) - 0.35), STRIPE, 0.01, rot=(0.03, 0, 0))
    box("towel_st", (0.455, 0.022, 0.05), (x, 0, ly(x) - 0.6), REDS, 0.0)
    # Носки-варежки парами
    for k in range(3):
        x = 1.35 + k * 0.28
        box(f"sock{k}", (0.09, 0.025, 0.3), (x, 0, ly(x) - 0.15), GREYC if k != 1 else REDS, 0.02)
    # Иней по верху вещей
    for k in range(10):
        x = random.uniform(-1.9, 2.0)
        sphere(f"fr{k}", 1.0, (x, 0, ly(x) - 0.02), FROSTM, scale=(0.05, 0.03, 0.015), segs=6, rings=4)
    NAME = "laundry_line"
elif PART == "trail_cross":
    TOWEL = mat("rushnik", (0.68, 0.66, 0.6), rough=1.0, noise=0.15, noise_scale=40)
    EMB = mat("embroid", (0.55, 0.08, 0.06), rough=1.0)
    vcyl("stem", 0.07, 2.5, (0, 0, -0.1), OLDWOOD, 8)
    box("bar_top", (0.36, 0.08, 0.07), (0, 0, 2.05), OLDWOOD, 0.006)
    box("bar_mid", (0.8, 0.09, 0.09), (0, 0, 1.78), OLDWOOD, 0.008)
    box("bar_low", (0.5, 0.08, 0.07), (0, 0, 1.2), OLDWOOD, 0.006, rot=(0, math.radians(-22), 0))
    # Кровелька-«голбец»
    for sy in (-1, 1):
        box(f"roof{sy}", (0.16, 0.24, 0.02), (0, sy * 0.08, 2.47), OLDWOOD, 0.004, rot=(sy * math.radians(35), 0, 0))
        box(f"roofsnow{sy}", (0.15, 0.22, 0.03), (0, sy * 0.085, 2.5), SNOW, 0.008, rot=(sy * math.radians(35), 0, 0))
    box("barsnow", (0.78, 0.08, 0.03), (0, 0, 1.84), SNOW, 0.008)
    # Рушник: перекинут через перекладину, концы свисают
    for sx in (-0.3, 0.3):
        box(f"towel{sx}", (0.12, 0.012, 0.55), (sx, -0.055, 1.52), TOWEL, 0.004, rot=(0.04, 0, sx * 0.1))
        for k in range(3):
            box(f"emb{sx}{k}", (0.122, 0.014, 0.025), (sx + sx * 0.01 * (k + 1), -0.055, 1.32 + k * 0.05), EMB, 0.0, rot=(0.04, 0, sx * 0.1))
    m = sphere("mound", 1.0, (0, 0, 0), SNOW, scale=(0.5, 0.5, 0.15), segs=12, rings=6)
    lumpy(m, 0.15, 3.0)
    NAME = "trail_cross"
elif PART == "can_line":
    TIN = mat("tin", (0.45, 0.45, 0.43), rough=0.4, wear=0.7, wear_col=(0.45, 0.22, 0.1))
    for sx in (-3.0, 3.0):
        vcyl(f"stake{sx}", 0.04, 1.35, (sx, 0, 0), OLDWOOD, 6)
    pts = [Vector((-3.0 + 6.0 * t / 12, 0.0, 1.25 - 0.25 * math.sin(math.pi * t / 12))) for t in range(13)]
    tube("line", pts, 0.005, ROPE, 4)
    for k in range(7):
        t = (k + 1) / 8
        x = -3.0 + 6.0 * t
        z = 1.25 - 0.25 * math.sin(math.pi * t)
        rod(f"str{k}", (x, 0, z), (x, 0, z - 0.18), 0.002, ROPE, 3)
        c = vcyl(f"can{k}", 0.04, 0.11, (x, 0, z - 0.3), TIN, 10)
        c.rotation_euler = (random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), 0)
    NAME = "can_line"
elif PART == "labaz":
    # Лабаз — избушка-амбарчик на высоких пнях, чтоб зверь не достал. Лестница-бревно с зарубками.
    BARK = mat("bark", (0.22, 0.17, 0.12), rough=1.0, noise=0.35, noise_scale=40)
    for sx in (-0.7, 0.7):
        for sy in (-0.6, 0.6):
            vcyl(f"pile{sx}{sy}", 0.13, 2.3, (sx, sy, 0), BARK, 9)
            vcyl(f"pilecap{sx}{sy}", 0.135, 0.04, (sx, sy, 2.3), WOOD, 9)
    box("floor", (1.8, 1.6, 0.12), (0, 0, 2.38), WOOD, 0.01)
    for k in range(5):
        z = 2.5 + k * 0.17
        for sy in (-0.7, 0.7):
            rod(f"logx{k}{sy}", (-0.85, sy, z), (0.85, sy, z), 0.085, BARK, 8)
        for sx in (-0.78, 0.78):
            rod(f"logy{k}{sx}", (sx, -0.75, z + 0.085), (sx, 0.75, z + 0.085), 0.085, BARK, 8)
    for sy in (-1, 1):
        box(f"roof{sy}", (2.1, 1.05, 0.06), (0, sy * 0.45, 3.58), OLDWOOD, 0.01, rot=(sy * math.radians(28), 0, 0))
        box(f"roofsnow{sy}", (2.05, 1.0, 0.1), (0, sy * 0.47, 3.66), SNOW, 0.02, rot=(sy * math.radians(28), 0, 0))
    box("door", (0.5, 0.04, 0.6), (0.0, -0.8, 2.82), OLDWOOD, 0.005)
    rod("ladder", (0.3, -1.6, 0.0), (0.1, -0.85, 2.4), 0.09, BARK, 8)
    for k in range(5):
        t = 0.15 + k * 0.17
        p = Vector((0.3, -1.6, 0.0)).lerp(Vector((0.1, -0.85, 2.4)), t)
        box(f"notch{k}", (0.16, 0.06, 0.03), p + Vector((0, -0.07, 0)), WOOD, 0.004)
    # Мешок, свисающий с края на верёвке
    rod("bagrope", (0.6, -0.75, 2.38), (0.6, -0.85, 1.75), 0.006, ROPE, 4)
    b = sphere("bag", 1.0, (0.6, -0.85, 1.55), mat("sack", (0.36, 0.32, 0.24), rough=1.0, noise=0.3, noise_scale=60), scale=(0.15, 0.13, 0.22), segs=10, rings=7)
    lumpy(b, 0.03, 10.0)
    NAME = "labaz"
else:  # skull_stake
    BONE = mat("bone", (0.7, 0.66, 0.56), rough=0.9, noise=0.25, noise_scale=30, wear=0.3, wear_col=(0.5, 0.45, 0.35), dirt=0.6)
    RIB1 = mat("rib1", (0.55, 0.1, 0.08), rough=1.0)
    RIB2 = mat("rib2", (0.25, 0.3, 0.45), rough=1.0)
    vcyl("stake", 0.05, 2.0, (0, 0, -0.1), OLDWOOD, 7, r2=None)
    # Лосиный череп: вытянутая морда вниз-вперёд, глазницы, лопаты рогов
    sk = sphere("cranium", 1.0, (0, -0.02, 2.0), BONE, scale=(0.13, 0.15, 0.12), segs=14, rings=9)
    sn = sphere("snout", 1.0, (0, -0.22, 1.86), BONE, scale=(0.08, 0.2, 0.08), segs=12, rings=8)
    sn.rotation_euler = (math.radians(-25), 0, 0)
    for sx in (-1, 1):
        sphere(f"eye{sx}", 1.0, (sx * 0.085, -0.1, 2.02), INK, scale=(0.035, 0.03, 0.035), segs=8, rings=5)
        sphere(f"nose{sx}", 1.0, (sx * 0.025, -0.38, 1.8), INK, scale=(0.015, 0.02, 0.02), segs=6, rings=4)
        # Лопата рога: изогнутая плоскость с отростками
        base = Vector((sx * 0.1, 0.02, 2.08))
        rod(f"pedicle{sx}", base, base + Vector((sx * 0.14, 0.02, 0.06)), 0.028, BONE, 8)
        palm = box(f"palm{sx}", (0.42, 0.04, 0.24), base + Vector((sx * 0.36, 0.06, 0.18)), BONE, 0.02, rot=(0.2, sx * -0.4, sx * 0.25))
        for k in range(4):
            tip = base + Vector((sx * (0.24 + k * 0.1), 0.06, 0.33 + (k % 2) * 0.05))
            rod(f"tine{sx}{k}", tip, tip + Vector((sx * 0.02, 0.0, 0.12)), 0.012, BONE, 5)
    # Ленточки, привязанные к шесту
    for k, m in enumerate((RIB1, RIB2, RIB1)):
        a = k * 2.1
        top = Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 1.6 - k * 0.05))
        box(f"rib{k}", (0.025, 0.004, 0.35), top + Vector((math.cos(a) * 0.04, math.sin(a) * 0.04, -0.18)), m, 0.0, rot=(0.15, 0.1 * k, a))
    m = sphere("mound", 1.0, (0, 0, 0), SNOW, scale=(0.35, 0.35, 0.1), segs=10, rings=5)
    lumpy(m, 0.15, 3.0)
    NAME = "skull_stake"

ORIGIN = "keep" if PART in ("shelf_jars", "coat_hooks") else "bottom"
body, img, tris = kit.finish(NAME, OUT, res=512, origin=ORIGIN, samples=24, ao_min=0.45)
kit.export(os.path.join(OUT, NAME + ".glb"), os.path.join(OUT, NAME + ".blend"))
print("[OK]", NAME, "tris:", tris)
