# Кирпичная печь-голландка для «Кедр-7»: побелка с проплешинами кирпича, копоть у топки, чугунная плита
# с конфорками, открытая дверца топки, поддувало, кирпичная труба до потолка с задвижкой, кочерга.
# Оси как у Props.stove(): начало — пол под центром печи, топка смотрит в +Z Godot (= -Y Блендера).
# Запуск: python3 stove.py <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, text, tube, mat

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "."
os.makedirs(OUT, exist_ok=True)
kit.reset()
CEIL = 2.8


def brick_mat(name, wash=0.8):
    """Кирпич под побелкой: кладка (Brick), побелка с проплешинами (шум), копоть у топки и вверху."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 4.0
    br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Brick Width"].default_value = 0.25
    br.inputs["Row Height"].default_value = 0.075
    br.inputs["Color1"].default_value = (0.42, 0.17, 0.1, 1)
    br.inputs["Color2"].default_value = (0.5, 0.22, 0.13, 1)
    br.inputs["Mortar"].default_value = (0.62, 0.6, 0.55, 1)
    # кладка по двум осям: X–Z и Y–Z (иначе на боковых гранях полосы)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath"); add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0]); nt.links.new(sep.outputs["Y"], add.inputs[1])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(add.outputs[0], comb.inputs["X"]); nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
    nt.links.new(comb.outputs[0], br.inputs["Vector"])
    # побелка: где шум выше порога — белое, иначе видна кладка
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 7; nz.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.62 - wash * 0.35; ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.66 - wash * 0.35; ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    wash_col = nt.nodes.new("ShaderNodeMix"); wash_col.data_type = "RGBA"
    nt.links.new(ramp.outputs["Color"], wash_col.inputs[0])
    nt.links.new(br.outputs["Color"], wash_col.inputs[6])
    wn = nt.nodes.new("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 40
    wr = nt.nodes.new("ShaderNodeValToRGB")
    wr.color_ramp.elements[0].color = (0.7, 0.69, 0.64, 1); wr.color_ramp.elements[1].color = (0.82, 0.81, 0.76, 1)
    nt.links.new(wn.outputs["Fac"], wr.inputs["Fac"])
    nt.links.new(wr.outputs["Color"], wash_col.inputs[7])
    # копоть: тёмное пятно над топкой (спереди, y<0) и кверху на трубе
    soot_d = nt.nodes.new("ShaderNodeVectorMath"); soot_d.operation = "DISTANCE"
    soot_d.inputs[1].default_value = (0.0, -0.5, 0.62)
    nt.links.new(tc.outputs["Object"], soot_d.inputs[0])
    sr = nt.nodes.new("ShaderNodeMapRange")
    sr.inputs[1].default_value = 0.05; sr.inputs[2].default_value = 0.42; sr.inputs[3].default_value = 0.75; sr.inputs[4].default_value = 0.0
    nt.links.new(soot_d.outputs["Value"], sr.inputs[0])
    sn = nt.nodes.new("ShaderNodeTexNoise"); sn.inputs["Scale"].default_value = 14
    smul = nt.nodes.new("ShaderNodeMath"); smul.operation = "MULTIPLY"; smul.use_clamp = True
    nt.links.new(sr.outputs[0], smul.inputs[0]); nt.links.new(sn.outputs["Fac"], smul.inputs[1])
    smul2 = nt.nodes.new("ShaderNodeMath"); smul2.operation = "MULTIPLY"; smul2.inputs[1].default_value = 1.6; smul2.use_clamp = True
    nt.links.new(smul.outputs[0], smul2.inputs[0])
    soot = nt.nodes.new("ShaderNodeMix"); soot.data_type = "RGBA"
    nt.links.new(smul2.outputs[0], soot.inputs[0])
    nt.links.new(wash_col.outputs[2], soot.inputs[6]); soot.inputs[7].default_value = (0.05, 0.045, 0.04, 1)
    nt.links.new(soot.outputs[2], b.inputs["Base Color"])
    return m


BRICK = brick_mat("brick", 0.85)
BRICK_PIPE = brick_mat("brick_pipe", 0.7)
IRON = mat("iron", (0.07, 0.065, 0.06), 0.7, 0, 0.25, 120, wear=0.6, dirt=0.3, wear_col=(0.3, 0.27, 0.24))
IRON_RUST = mat("iron_rust", (0.12, 0.08, 0.06), 0.8, 0, 0.35, 60, wear=0.6, dirt=0.3, wear_col=(0.32, 0.2, 0.12))
BLACK = mat("black", (0.012, 0.01, 0.01), 0.9)
EMBER = mat("ember", (0.35, 0.09, 0.02), 0.9, 0, 0.4, 30)
BRASS = mat("brass", (0.55, 0.42, 0.18), 0.4, 0, 0.1, 200, wear=0.4, wear_col=(0.8, 0.68, 0.4))
WOOD = mat("wood", (0.25, 0.16, 0.09), 0.8, 0, 0.3, 40, wear=0.4, wear_col=(0.4, 0.3, 0.2))

FY = -0.45        # передняя грань тела печи (Блендер −Y = Godot +Z)
# Цоколь, тело, карниз
box("plinth", (0.98, 0.98, 0.16), (0, 0, 0.08), BRICK, 0.01)
box("body", (0.9, 0.9, 1.0), (0, 0, 0.66), BRICK, 0.012)
box("cornice", (0.96, 0.96, 0.08), (0, 0, 1.2), BRICK, 0.01)
box("cornice2", (0.93, 0.93, 0.03), (0, 0, 1.145), BRICK, 0.006)
# Чугунная плита с двумя конфорками (кольца)
box("plate", (0.62, 0.46, 0.022), (0, -0.12, 1.247), IRON, 0.004)
for i, (x, r) in enumerate(((-0.13, 0.11), (0.15, 0.09))):
    torus(f"ring{i}", r, 0.008, (x, -0.12, 1.26), IRON, rot=(0, 0, 0), maj=28, mino=6)
    torus(f"ring{i}b", r * 0.6, 0.006, (x, -0.12, 1.26), IRON, rot=(0, 0, 0), maj=24, mino=6)
    cyl(f"lid{i}", r * 0.35, 0.012, (x, -0.12, 1.262), IRON, rot=(0, 0, 0), verts=16)
# Топка: рамка, тёмная глубина с углями, открытая дверца на петлях слева
TZ = 0.5
box("fb_frame", (0.46, 0.02, 0.32), (0, FY - 0.006, TZ), IRON, 0.004)
box("fb_hole", (0.38, 0.03, 0.24), (0, FY - 0.004, TZ), BLACK, 0)
box("embers", (0.34, 0.02, 0.06), (0, FY - 0.008, TZ - 0.09), EMBER, 0)
for i in range(4):
    box(f"grate{i}", (0.006, 0.022, 0.05), (-0.12 + i * 0.08, FY - 0.012, TZ - 0.095), IRON, 0)
door = box("fb_door", (0.2, 0.014, 0.24), (0, 0, 0), IRON, 0.003)
for dz in (-0.06, 0.06):
    box(f"fb_rib{dz}", (0.17, 0.006, 0.012), (0, -0.01, dz), IRON, 0.001)
    kit.objs[-1].parent = door
for dx in (-0.05, 0.0, 0.05):
    cyl(f"fb_vent{dx}", 0.01, 0.006, (dx, -0.01, 0.0), BLACK, rot=(math.pi / 2, 0, 0), verts=10)
    kit.objs[-1].parent = door
cyl("fb_knob", 0.012, 0.03, (0.08, -0.02, 0.0), BRASS, rot=(math.pi / 2, 0, 0), verts=10)
kit.objs[-1].parent = door
# открыта на ~110° вокруг левой петли
door.location = (-0.23 - 0.1 * math.cos(math.radians(110)), FY - 0.012 - 0.1 * math.sin(math.radians(110)), TZ)
door.rotation_euler = (0, 0, math.radians(110))
for dz in (-0.08, 0.08):
    cyl(f"hinge{dz}", 0.01, 0.04, (-0.23, FY - 0.015, TZ + dz), IRON, rot=(0, 0, 0), verts=10)
# Поддувало
box("ash_frame", (0.3, 0.016, 0.12), (0, FY - 0.006, 0.24), IRON, 0.003)
box("ash_door", (0.26, 0.012, 0.09), (0, FY - 0.013, 0.24), IRON, 0.002)
for dx in (-0.06, 0.0, 0.06):
    box(f"ash_slot{dx}", (0.03, 0.01, 0.012), (dx, FY - 0.02, 0.245), BLACK, 0)
cyl("ash_knob", 0.01, 0.025, (0.1, FY - 0.03, 0.24), BRASS, rot=(math.pi / 2, 0, 0), verts=10)
# Лист железа перед топкой (пожарный)
box("fire_sheet", (0.7, 0.4, 0.004), (0, FY - 0.25, 0.002), IRON_RUST, 0.002)
# Кирпичная труба до потолка, у задней стенки, с задвижкой
box("chimney", (0.38, 0.38, CEIL - 1.24), (0, 0.25, 1.24 + (CEIL - 1.24) / 2), BRICK_PIPE, 0.008)
box("chim_band", (0.42, 0.42, 0.05), (0, 0.25, 2.2), BRICK_PIPE, 0.006)
box("damper", (0.22, 0.02, 0.04), (0, 0.25 - 0.2, 1.95), IRON, 0.003)
box("damper_handle", (0.06, 0.05, 0.015), (0.14, 0.25 - 0.22, 1.95), IRON, 0.002)
cyl("damper_ring", 0.018, 0.005, (0.18, 0.25 - 0.23, 1.95), IRON, rot=(math.pi / 2, 0, 0), verts=12)
# Кочерга у правого бока
tube("poker", [(0.5, -0.32, 0.02), (0.53, -0.3, 0.95)], 0.007, IRON, 6)
tube("poker_hook", [(0.5, -0.32, 0.02), (0.47, -0.36, 0.05)], 0.007, IRON, 6)
torus("poker_ring", 0.022, 0.005, (0.535, -0.3, 0.98), IRON, rot=(math.pi / 2, 0, 0), maj=14, mino=5)
# Пара поленьев у печки
for i, (x, y, rz) in enumerate(((0.58, 0.12, 10), (0.6, 0.28, -14))):
    cyl(f"log{i}", 0.045, 0.34, (x, y, 0.05 + i * 0.0), WOOD, rot=(math.pi / 2, 0, math.radians(rz)), verts=10)

obj, img, tris = kit.finish("stove_brick", OUT, res=1024, origin="keep", samples=48)
kit.export(os.path.join(OUT, "stove_brick.glb"), os.path.join(OUT, "stove_brick.blend"))
print("OK tris:", tris)
