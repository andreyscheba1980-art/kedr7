# Кассетный магнитофон «Весна-306» для «Кедр-7»: лежит на столе, кассетой вверх. Габарит как у старой модели
# (0,36 × 0,24 × ~0,11 м). Перед (клавиши) смотрит в -Y Блендера → +Z в Godot.
# Запуск: python3 vesna.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

BODY = mat("body", (0.07, 0.065, 0.06), 0.6, 0, 0.12, 150, wear=0.6, dirt=0.5, wear_col=(0.3, 0.29, 0.27))
ALU = mat("alu", (0.58, 0.59, 0.6), 0.4, 0, 0.06, 900, wear=0.3, dirt=0.6, wear_col=(0.75, 0.75, 0.74))
DARK = mat("dark", (0.03, 0.03, 0.03), 0.7)
GRILLE = mat("grille", (0.11, 0.11, 0.11), 0.7, 0, 0.1, 200)
CAS = mat("cassette", (0.12, 0.07, 0.04), 0.4, 0, 0.1, 160, wear=0.4, dirt=0.3, wear_col=(0.25, 0.16, 0.1))
LABEL = mat("label", (0.8, 0.76, 0.64), 0.8, 0, 0.12, 50)
INK = mat("ink", (0.12, 0.13, 0.35), 0.8)
TAPE = mat("tape", (0.18, 0.1, 0.05), 0.5)
WHITE = mat("white", (0.85, 0.84, 0.8), 0.5)
RED = mat("red", (0.6, 0.07, 0.05), 0.5, 0, 0.05, 80, wear=0.4, wear_col=(0.8, 0.4, 0.35))
METER = mat("meter", (0.82, 0.78, 0.62), 0.6)
CHROME = mat("chrome", (0.66, 0.67, 0.68), 0.3, 0, 0.05, 300, wear=0.3, wear_col=(0.45, 0.4, 0.33))
LED = mat("led", (0.9, 0.15, 0.08), 0.3)

W, D, H = 0.36, 0.24, 0.09
FY = -D / 2
TOP = H
# Корпус: чёрный пластик со скруглёнными рёбрами
box("case", (W, D, H), (0, 0, H / 2), BODY, 0.012)
# Резиновые ножки
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl(f"foot{sx}{sy}", 0.012, 0.006, (sx * 0.15, sy * 0.095, -0.002), DARK, rot=(0, 0, 0), verts=12)
# Алюминиевая верхняя панель (утоплена в рамку)
box("top", (W - 0.024, D - 0.024, 0.004), (0, 0, TOP + 0.001), ALU, 0.002)

# --- Кассетный отсек слева: углубление, кассета, рамка крышки ---
CX, CYc = -0.08, 0.012
box("bay", (0.15, 0.105, 0.004), (CX, CYc, TOP + 0.0025), DARK, 0.002)
box("cas", (0.112, 0.07, 0.006), (CX, CYc, TOP + 0.005), CAS, 0.0015)
box("label", (0.096, 0.042, 0.001), (CX, CYc + 0.004, TOP + 0.0085), LABEL, 0)
text("Семёнов · ноябрь 82", 0.0065, (CX, CYc + 0.019, TOP + 0.0092), INK, 0.0002, rot=(0, 0, 0))
text("стор. А", 0.005, (CX - 0.032, CYc - 0.012, TOP + 0.0092), INK, 0.0002, rot=(0, 0, 0))
box("window", (0.05, 0.016, 0.001), (CX, CYc - 0.004, TOP + 0.0092), DARK, 0)
for i, dx in enumerate((-0.03, 0.03)):
    cyl(f"reel{i}", 0.0075, 0.0015, (CX + dx, CYc - 0.004, TOP + 0.0095), WHITE, rot=(0, 0, 0), verts=12)
    for t in range(6):
        a = t * math.pi / 3
        box(f"tooth{i}{t}", (0.0016, 0.0016, 0.0015), (CX + dx + math.cos(a) * 0.0042, CYc - 0.004 + math.sin(a) * 0.0042, TOP + 0.0102), DARK, 0)
box("tape_pack", (0.024, 0.014, 0.0006), (CX - 0.008, CYc - 0.004, TOP + 0.0096), TAPE, 0)
box("cas_edge", (0.1, 0.008, 0.003), (CX, CYc - 0.03, TOP + 0.009), CAS, 0.001)
# Хромированная рамка крышки (стекло не печём — оно бы закрыло кассету)
for sy in (-1, 1):
    box(f"lidf{sy}", (0.152, 0.004, 0.004), (CX, CYc + sy * 0.0535, TOP + 0.011), CHROME, 0.001)
for sx in (-1, 1):
    box(f"lids{sx}", (0.004, 0.107, 0.004), (CX + sx * 0.076, CYc, TOP + 0.011), CHROME, 0.001)
box("eject", (0.02, 0.008, 0.006), (CX + 0.05, CYc + 0.06, TOP + 0.004), CHROME, 0.0015)

# --- Громкоговоритель справа: решётка из дырочек ---
GX, GY = 0.085, 0.012
# Решётка: дырочки нарисованы в материале и запекаются в текстуру (раньше — 150 цилиндров, 30 тыс. треугольников)
G = bpy.data.materials.new("grille_holes"); G.use_nodes = True
gn = G.node_tree; gb = gn.nodes["Principled BSDF"]
gtc = gn.nodes.new("ShaderNodeTexCoord")
gsep = gn.nodes.new("ShaderNodeSeparateXYZ"); gn.links.new(gtc.outputs["Object"], gsep.inputs[0])
def mnode(op, a=None, b=None, va=None, vb=None):
    n = gn.nodes.new("ShaderNodeMath"); n.operation = op
    if a is not None: gn.links.new(a, n.inputs[0])
    elif va is not None: n.inputs[0].default_value = va
    if b is not None: gn.links.new(b, n.inputs[1])
    elif vb is not None: n.inputs[1].default_value = vb
    return n.outputs[0]
# координаты относительно центра решётки, шаг 1 см
ux = mnode("SUBTRACT", gsep.outputs["X"], vb=GX)
uy = mnode("SUBTRACT", gsep.outputs["Y"], vb=GY)
fx = mnode("SUBTRACT", mnode("FRACT", mnode("MULTIPLY", ux, vb=100.0)), vb=0.5)
fy = mnode("SUBTRACT", mnode("FRACT", mnode("MULTIPLY", uy, vb=100.0)), vb=0.5)
dist = mnode("SQRT", mnode("ADD", mnode("MULTIPLY", fx, fx), mnode("MULTIPLY", fy, fy)))
hole = mnode("LESS_THAN", dist, vb=0.27)
ex = mnode("DIVIDE", ux, vb=0.064); ey = mnode("DIVIDE", uy, vb=0.058)
inside = mnode("LESS_THAN", mnode("ADD", mnode("MULTIPLY", ex, ex), mnode("MULTIPLY", ey, ey)), vb=1.0)
mask = mnode("MULTIPLY", hole, inside)
gmix = gn.nodes.new("ShaderNodeMix"); gmix.data_type = "RGBA"
gmix.inputs[6].default_value = (0.11, 0.11, 0.11, 1); gmix.inputs[7].default_value = (0.012, 0.012, 0.012, 1)
gn.links.new(mask, gmix.inputs[0]); gn.links.new(gmix.outputs[2], gb.inputs["Base Color"])
box("grille", (0.13, 0.12, 0.002), (GX, GY, TOP + 0.003), G, 0.001)
text("ВЕСНА-306", 0.011, (GX, GY - 0.074, TOP + 0.0032), DARK, 0.0, rot=(0, 0, 0))

# --- Индикатор уровня записи и ручки сзади ---
box("vu_bezel", (0.07, 0.03, 0.004), (-0.08, 0.085, TOP + 0.003), CHROME, 0.0015)
box("vu", (0.062, 0.023, 0.002), (-0.08, 0.085, TOP + 0.0045), METER, 0)
for t in range(9):
    a = math.radians(-40 + t * 10)
    box(f"vut{t}", (0.0007, 0.004, 0.0004), (-0.08 + math.sin(a) * 0.024, 0.076 + math.cos(a) * 0.016, TOP + 0.0057), DARK if t < 6 else RED, 0)
box("vu_red", (0.016, 0.0018, 0.0004), (-0.064, 0.094, TOP + 0.0057), RED, 0)
nd = box("vu_needle", (0.0008, 0.019, 0.0004), (-0.084, 0.083, TOP + 0.006), DARK, 0, rot=(0, 0, math.radians(18)))
for i, x in enumerate((0.05, 0.11)):
    cyl(f"knob{i}", 0.014, 0.014, (x, 0.085, TOP + 0.009), DARK, rot=(0, 0, 0), verts=20, bevel=0.002, r2=0.012)
    cyl(f"knobcap{i}", 0.009, 0.002, (x, 0.085, TOP + 0.0165), CHROME, rot=(0, 0, 0), verts=20)
    box(f"knobmark{i}", (0.0018, 0.008, 0.001), (x, 0.081, TOP + 0.0175), WHITE, 0)
text("ГРОМК.", 0.004, (0.05, 0.065, TOP + 0.0032), DARK, 0.0002, rot=(0, 0, 0))
text("ТЕМБР", 0.004, (0.11, 0.065, TOP + 0.0032), DARK, 0.0002, rot=(0, 0, 0))
cyl("led_ring", 0.005, 0.003, (0.155, 0.085, TOP + 0.003), CHROME, rot=(0, 0, 0), verts=12)
sphere("led", 0.0035, (0.155, 0.085, TOP + 0.005), LED, segs=10, rings=6)

# --- Клавиши-«пианино» у переднего края ---
labels = ["ЗАП", "◀◀", "▶", "▶▶", "СТОП", "ПАУЗА"]
for b in range(6):
    bx = -0.135 + b * 0.025
    col = RED if b == 0 else ALU
    box(f"key{b}", (0.021, 0.03, 0.012), (bx, FY + 0.016, TOP + 0.002), col, 0.002)
    box(f"keygap{b}", (0.023, 0.032, 0.006), (bx, FY + 0.016, TOP - 0.002), DARK, 0)
box("keyrow_lip", (0.16, 0.006, 0.006), (-0.072, FY + 0.003, TOP - 0.002), BODY, 0.002)
# Гнёзда и ползунок на правом боку
for i in range(2):
    cyl(f"jack{i}", 0.006, 0.004, (W / 2 + 0.0015, -0.04 + i * 0.03, 0.045), CHROME, rot=(0, math.pi / 2, 0), verts=12)
    cyl(f"jackh{i}", 0.0028, 0.005, (W / 2 + 0.002, -0.04 + i * 0.03, 0.045), DARK, rot=(0, math.pi / 2, 0), verts=8)
# Шов корпуса по периметру
box("seam_f", (W + 0.001, 0.002, 0.003), (0, FY, 0.03), DARK, 0)
box("seam_b", (W + 0.001, 0.002, 0.003), (0, -FY, 0.03), DARK, 0)
# Ручка для переноски сзади: кронштейны + хромированная скоба, откинута назад
for sx in (-1, 1):
    box(f"hbr{sx}", (0.012, 0.016, 0.024), (sx * 0.165, -FY + 0.004, 0.06), BODY, 0.003)
tube("handle", [(-0.165, -FY + 0.012, 0.062), (-0.15, -FY + 0.034, 0.064), (0.15, -FY + 0.034, 0.064), (0.165, -FY + 0.012, 0.062)], 0.005, CHROME, 10)

obj, img, tris = kit.finish("vesna306", OUT, res=1024, origin="bottom", samples=48)
kit.export(os.path.join(OUT, "vesna306.glb"), os.path.join(OUT, "vesna306.blend"))
print("OK tris:", tris)
