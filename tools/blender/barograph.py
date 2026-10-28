# Недельный барограф М-22 для «Кедр-7»: чугунное основание, стопка анероидных коробок, рычаги, перо,
# часовой барабан с диаграммной лентой и фиолетовой кривой, латунная рама колпака. Стекло колпака
# ставит игра (прозрачный материал не запекается). Перед (табличка) смотрит в -Y → +Z в Godot.
# Запуск: python3 barograph.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()

IRON = mat("iron", (0.1, 0.14, 0.12), 0.6, 0, 0.3, 160, wear=0.7, dirt=0.5, wear_col=(0.3, 0.3, 0.28))
BRASS = mat("brass", (0.62, 0.48, 0.2), 0.35, 0, 0.12, 250, wear=0.4, dirt=0.5, wear_col=(0.85, 0.72, 0.42))
NICKEL = mat("nickel", (0.6, 0.62, 0.63), 0.3, 0, 0.08, 300, wear=0.3, dirt=0.4, wear_col=(0.45, 0.42, 0.36))
DARK = mat("dark", (0.03, 0.03, 0.03), 0.6)
INK = mat("ink", (0.32, 0.08, 0.42), 0.5)
FELT = mat("felt", (0.12, 0.05, 0.04), 0.9)

# Диаграммная лента: бумага с сеткой (давление — горизонтали, время — вертикали по окружности)
PAPER = bpy.data.materials.new("paper"); PAPER.use_nodes = True
nt = PAPER.node_tree
bsdf = nt.nodes["Principled BSDF"]
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
# горизонтали: каждые 4 мм по высоте
hz = nt.nodes.new("ShaderNodeMath"); hz.operation = "MULTIPLY"; hz.inputs[1].default_value = 250.0
nt.links.new(sep.outputs["Z"], hz.inputs[0])
hs = nt.nodes.new("ShaderNodeMath"); hs.operation = "PINGPONG"; hs.inputs[1].default_value = 0.5
nt.links.new(hz.outputs[0], hs.inputs[0])
hl = nt.nodes.new("ShaderNodeMath"); hl.operation = "LESS_THAN"; hl.inputs[1].default_value = 0.06
nt.links.new(hs.outputs[0], hl.inputs[0])
# вертикали: по углу вокруг оси барабана (x=0.08)
ox = nt.nodes.new("ShaderNodeMath"); ox.operation = "SUBTRACT"; ox.inputs[1].default_value = 0.08
nt.links.new(sep.outputs["X"], ox.inputs[0])
at = nt.nodes.new("ShaderNodeMath"); at.operation = "ARCTAN2"
nt.links.new(sep.outputs["Y"], at.inputs[0]); nt.links.new(ox.outputs[0], at.inputs[1])
vz = nt.nodes.new("ShaderNodeMath"); vz.operation = "MULTIPLY"; vz.inputs[1].default_value = 28.0 / math.pi
nt.links.new(at.outputs[0], vz.inputs[0])
vs = nt.nodes.new("ShaderNodeMath"); vs.operation = "PINGPONG"; vs.inputs[1].default_value = 0.5
nt.links.new(vz.outputs[0], vs.inputs[0])
vl = nt.nodes.new("ShaderNodeMath"); vl.operation = "LESS_THAN"; vl.inputs[1].default_value = 0.05
nt.links.new(vs.outputs[0], vl.inputs[0])
lines = nt.nodes.new("ShaderNodeMath"); lines.operation = "MAXIMUM"
nt.links.new(hl.outputs[0], lines.inputs[0]); nt.links.new(vl.outputs[0], lines.inputs[1])
mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"
mx.inputs[6].default_value = (0.86, 0.82, 0.7, 1); mx.inputs[7].default_value = (0.55, 0.4, 0.5, 1)
nt.links.new(lines.outputs[0], mx.inputs[0])
nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])

# 1. Чугунное основание с фаской и латунными ножками
box("base", (0.34, 0.18, 0.026), (0, 0, 0.017), IRON, 0.006)
box("base_top", (0.32, 0.16, 0.006), (0, 0, 0.032), IRON, 0.003)
for sx in (-1, 1):
    for sy in (-1, 1):
        cyl(f"foot{sx}{sy}", 0.012, 0.006, (sx * 0.15, sy * 0.07, 0.003), BRASS, rot=(0, 0, 0), verts=14, bevel=0.0015)
# Табличка спереди
box("plate", (0.13, 0.002, 0.016), (0, -0.0905, 0.018), BRASS, 0.0008)
text("БАРОГРАФ  М-22", 0.0072, (0, -0.0918, 0.0185), DARK, 0.0003)
for sx in (-1, 1):
    cyl(f"rivet{sx}", 0.0016, 0.0012, (sx * 0.06, -0.0915, 0.018), BRASS, verts=8)
# Войлочная подкладка-лоток для ключа
box("felt", (0.05, 0.03, 0.002), (-0.13, 0.05, 0.036), FELT, 0.001)
# Заводной ключ лежит на войлоке
cyl("key_shaft", 0.0025, 0.03, (-0.13, 0.05, 0.039), BRASS, rot=(0, math.pi / 2, 0), verts=8)
box("key_bow", (0.012, 0.016, 0.003), (-0.148, 0.05, 0.039), BRASS, 0.001)

# 2. Стопка анероидных коробок с гофром
AX = -0.08
cyl("aneroid_base", 0.03, 0.01, (AX, 0, 0.04), BRASS, rot=(0, 0, 0), verts=24, bevel=0.002)
for b in range(5):
    z = 0.05 + b * 0.0135
    cyl(f"cap{b}", 0.038, 0.007, (AX, 0, z), NICKEL, rot=(0, 0, 0), verts=32, bevel=0.002)
    for g in range(3):
        torus(f"corr{b}{g}", 0.012 + g * 0.009, 0.0009, (AX, 0, z + 0.0036), NICKEL, rot=(0, 0, 0), maj=32, mino=6)
    cyl(f"link{b}", 0.008, 0.006, (AX, 0, z + 0.0068), BRASS, rot=(0, 0, 0), verts=12)
cyl("aneroid_top", 0.006, 0.02, (AX, 0, 0.122), BRASS, rot=(0, 0, 0), verts=12)

# 3. Стойка, рычаги, ось пера
box("post", (0.012, 0.012, 0.085), (-0.02, 0.03, 0.077), BRASS, 0.002)
box("bridge", (0.075, 0.008, 0.006), (-0.05, 0.03, 0.12), BRASS, 0.0015)
tube("pushrod", [(AX, 0.0, 0.132), (AX + 0.01, 0.015, 0.124), (-0.02, 0.03, 0.118)], 0.0018, BRASS, 6)
cyl("pivot", 0.004, 0.018, (-0.02, 0.03, 0.105), BRASS, rot=(0, 0, 0), verts=12)
# Длинная стрелка к перу у барабана
PEN = (0.0325, -0.002, 0.092)
tube("pen_arm", [(-0.02, 0.03, 0.105), (0.006, 0.014, 0.099), PEN], 0.0012, DARK, 6)
box("pen", (0.006, 0.004, 0.006), (PEN[0] - 0.002, PEN[1], PEN[2]), INK, 0.001)
box("pen_lift", (0.03, 0.004, 0.004), (0.01, 0.045, 0.06), BRASS, 0.001)

# 4. Часовой барабан с лентой и кривой давления
DX, R = 0.08, 0.046
cyl("drum", R, 0.124, (DX, 0, 0.092), BRASS, rot=(0, 0, 0), verts=40, bevel=0.0015)
cyl("chart", R + 0.0012, 0.108, (DX, 0, 0.09), PAPER, rot=(0, 0, 0), verts=48)
box("clip", (0.004, 0.003, 0.11), (DX + R * math.cos(math.radians(-60)), R * math.sin(math.radians(-60)) - 0.001, 0.09), BRASS, 0.001)
pts = []
for i in range(46):
    th = math.radians(180 - i * 5)                  # от пера по фронту барабана
    z = 0.092 + 0.009 * math.sin(i * 0.33) + 0.004 * math.sin(i * 1.1 + 1.0) - i * 0.0003
    pts.append((DX + (R + 0.0016) * math.cos(th), (R + 0.0016) * math.sin(th) * -1, z))
tube("trace", pts, 0.0007, INK, 5)
cyl("drum_cap", 0.02, 0.008, (DX, 0, 0.158), BRASS, rot=(0, 0, 0), verts=24, bevel=0.0015)
cyl("drum_nut", 0.006, 0.01, (DX, 0, 0.166), BRASS, rot=(0, 0, 0), verts=6)

# 5. Латунная рама колпака
HX, HY, Z0, Z1 = 0.158, 0.078, 0.036, 0.186
for sy in (-1, 1):
    box(f"rimb{sy}", (HX * 2, 0.004, 0.006), (0, sy * HY, Z0 + 0.003), BRASS, 0.001)
    box(f"rimt{sy}", (HX * 2, 0.004, 0.004), (0, sy * HY, Z1), BRASS, 0.001)
for sx in (-1, 1):
    box(f"rimbs{sx}", (0.004, HY * 2, 0.006), (sx * HX, 0, Z0 + 0.003), BRASS, 0.001)
    box(f"rimts{sx}", (0.004, HY * 2, 0.004), (sx * HX, 0, Z1), BRASS, 0.001)
    for sy in (-1, 1):
        box(f"post{sx}{sy}", (0.005, 0.005, Z1 - Z0), (sx * HX, sy * HY, (Z0 + Z1) / 2), BRASS, 0.001)
box("handle_base", (0.05, 0.016, 0.003), (0, 0, Z1 + 0.003), BRASS, 0.001)
tube("handle", [(-0.02, 0, Z1 + 0.004), (-0.016, 0, Z1 + 0.014), (0.016, 0, Z1 + 0.014), (0.02, 0, Z1 + 0.004)], 0.0025, BRASS, 8)
for sx in (-1, 1):
    box(f"latch{sx}", (0.006, 0.008, 0.012), (sx * (HX + 0.004), 0, Z0 + 0.008), BRASS, 0.001)

obj, img, tris = kit.finish("barograph_m22", OUT, res=1024, origin="bottom", samples=48)
kit.export(os.path.join(OUT, "barograph_m22.glb"), os.path.join(OUT, "barograph_m22.blend"))
print("OK tris:", tris)
