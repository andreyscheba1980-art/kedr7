# Кирпичная печь-голландка для «Кедр-7» (1983, PS1 low-poly, gl_compatibility):
# побелка с проплешинами красного кирпича, копоть над топкой, выразительная чугунная
# варочная плита со съёмными конфорочными кольцами и бортиком, чугунная топочная дверца ДТ-3
# с рельефом, петлями и латунным вертушком, поддувало, железный предтопочный лист,
# кирпичная труба до потолка с разделкой, кочерга и берёзовые поленья.
# Оси как у Props.stove(): начало — пол под центром печи, топка смотрит в +Z Godot (= -Y Блендера).
# Запуск:
#   blender --background --factory-startup --python tools/blender/stove.py -- assets/models/kedr

import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube, mat

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/kedr"
ONLY = ARGS[1:]
if ONLY and "stove_brick" not in ONLY and "stove" not in ONLY:
    sys.exit(0)
os.makedirs(OUT, exist_ok=True)
kit.reset()

CEIL = 2.8


def _bsdf_of(m):
    nt = m.node_tree
    return (
        next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        or nt.nodes.get("Principled BSDF")
        or nt.nodes.get("Принципиальный BSDF")
    )


def _inp(node, names, idx):
    for n in names:
        if n in node.inputs:
            return node.inputs[n]
    return node.inputs[idx]


def brick_mat(name, wash=0.42):
    """Кирпич под побелкой с копотью над топкой (RU/EN locale safe)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf_of(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")

    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 4.0
    br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Brick Width"].default_value = 0.25
    br.inputs["Row Height"].default_value = 0.075
    br.inputs["Color1"].default_value = (0.44, 0.18, 0.10, 1)
    br.inputs["Color2"].default_value = (0.52, 0.23, 0.13, 1)
    br.inputs["Mortar"].default_value = (0.62, 0.60, 0.55, 1)

    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Y"], add.inputs[1])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(add.outputs[0], comb.inputs["X"])
    nt.links.new(sep.outputs["Z"], comb.inputs["Y"])
    nt.links.new(comb.outputs[0], br.inputs["Vector"])

    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 7.0
    nz.inputs["Detail"].default_value = 8.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])

    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.62 - wash * 0.35
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.66 - wash * 0.35
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])

    wash_col = nt.nodes.new("ShaderNodeMix")
    wash_col.data_type = "RGBA"
    nt.links.new(ramp.outputs["Color"], wash_col.inputs[0])
    nt.links.new(br.outputs["Color"], wash_col.inputs[6])

    wn = nt.nodes.new("ShaderNodeTexNoise")
    wn.inputs["Scale"].default_value = 40.0
    wr = nt.nodes.new("ShaderNodeValToRGB")
    wr.color_ramp.elements[0].color = (0.70, 0.69, 0.64, 1)
    wr.color_ramp.elements[1].color = (0.82, 0.81, 0.76, 1)
    nt.links.new(wn.outputs["Fac"], wr.inputs["Fac"])
    nt.links.new(wr.outputs["Color"], wash_col.inputs[7])

    soot_d = nt.nodes.new("ShaderNodeVectorMath")
    soot_d.operation = "DISTANCE"
    soot_d.inputs[1].default_value = (0.0, -0.5, 0.64)
    nt.links.new(tc.outputs["Object"], soot_d.inputs[0])

    sr = nt.nodes.new("ShaderNodeMapRange")
    sr.inputs[1].default_value = 0.05
    sr.inputs[2].default_value = 0.45
    sr.inputs[3].default_value = 0.78
    sr.inputs[4].default_value = 0.0
    nt.links.new(soot_d.outputs["Value"], sr.inputs[0])

    sn = nt.nodes.new("ShaderNodeTexNoise")
    sn.inputs["Scale"].default_value = 14.0
    smul = nt.nodes.new("ShaderNodeMath")
    smul.operation = "MULTIPLY"
    smul.use_clamp = True
    nt.links.new(sr.outputs[0], smul.inputs[0])
    nt.links.new(sn.outputs["Fac"], smul.inputs[1])

    smul2 = nt.nodes.new("ShaderNodeMath")
    smul2.operation = "MULTIPLY"
    smul2.inputs[1].default_value = 1.65
    smul2.use_clamp = True
    nt.links.new(smul.outputs[0], smul2.inputs[0])

    soot = nt.nodes.new("ShaderNodeMix")
    soot.data_type = "RGBA"
    nt.links.new(smul2.outputs[0], soot.inputs[0])
    nt.links.new(wash_col.outputs[2], soot.inputs[6])
    soot.inputs[7].default_value = (0.05, 0.045, 0.04, 1)

    nt.links.new(soot.outputs[2], _inp(b, ("Base Color", "Базовый цвет"), 0))
    _inp(b, ("Roughness", "Шероховатость"), 2).default_value = 0.92
    _inp(b, ("Metallic", "Металличность"), 1).default_value = 0.0
    return m


BRICK = brick_mat("brick", 0.42)
BRICK_PIPE = brick_mat("brick_pipe", 0.28)
BRICK_LOW = brick_mat("brick_low", 0.14)
CAST_IRON = mat("cast_iron", (0.09, 0.088, 0.086), 0.62, 0, 0.25, 110,
                wear=0.78, dirt=0.35, wear_col=(0.42, 0.39, 0.36))
CAST_RING = mat("cast_ring", (0.14, 0.135, 0.13), 0.52, 0, 0.20, 140,
                wear=0.85, dirt=0.25, wear_col=(0.52, 0.48, 0.44))
IRON_RUST = mat("iron_rust", (0.15, 0.10, 0.07), 0.78, 0, 0.35, 60,
                wear=0.65, dirt=0.35, wear_col=(0.38, 0.24, 0.14))
BLACK = mat("black", (0.012, 0.01, 0.01), 0.95)
EMBER = mat("ember", (0.46, 0.12, 0.02), 0.88, 0, 0.4, 30)
BRASS = mat("brass", (0.64, 0.48, 0.20), 0.38, 0, 0.1, 180, wear=0.5, wear_col=(0.88, 0.76, 0.44))
WOOD = mat("wood", (0.28, 0.18, 0.10), 0.85, 0, 0.3, 40, wear=0.4, wear_col=(0.44, 0.32, 0.20))
SOOT = mat("soot", (0.03, 0.025, 0.02), 0.96)

FY = -0.45   # передняя грань печи (-Y Blender = +Z Godot)
H = 0.452

# 1. Цоколь, массив тела, ступенчатый карниз
box("plinth", (0.98, 0.98, 0.16), (0, 0, 0.08), BRICK_LOW, 0.01)
box("body", (0.90, 0.90, 1.00), (0, 0, 0.66), BRICK, 0.012)
box("cornice2", (0.93, 0.93, 0.032), (0, 0, 1.145), BRICK, 0.006)
box("cornice", (0.97, 0.97, 0.085), (0, 0, 1.20), BRICK, 0.01)

# 2. Чугунные уголки и стальные обвязочные пояса с заклёпками
for sx in (-1, 1):
    for sy in (-1, 1):
        box(f"angle_a{sx}{sy}", (0.055, 0.010, 1.00), (sx * (H - 0.022), sy * H, 0.66), CAST_IRON, 0.002)
        box(f"angle_b{sx}{sy}", (0.010, 0.055, 1.00), (sx * H, sy * (H - 0.022), 0.66), CAST_IRON, 0.002)
for zz in (0.29, 0.80, 1.02):
    for sy in (-1, 1):
        box(f"band_y{zz}{sy}", (0.92, 0.010, 0.030), (0, sy * H, zz), CAST_IRON, 0.002)
    for sx in (-1, 1):
        box(f"band_x{zz}{sx}", (0.010, 0.92, 0.030), (sx * H, 0, zz), CAST_IRON, 0.002)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(f"rivet{zz}{sx}{sy}", 0.009, 0.010, (sx * (H - 0.04), sy * (H + 0.005), zz),
                BRASS if zz == 1.02 else CAST_IRON, rot=(math.pi * 0.5, 0, 0), verts=8)

# 3. Выразительная чугунная варочная плита с высоким бортиком и 2 конфорками со съёмными кольцами
box("plate_base", (0.90, 0.64, 0.034), (0, -0.14, 1.258), CAST_IRON, 0.005)
# Периметральный чугунный бортик варочной плиты
for sy, ln in ((-0.455, 0.91), (0.175, 0.91)):
    box(f"plate_rim_y{sy}", (ln, 0.026, 0.026), (0, sy, 1.278), CAST_RING, 0.004)
for sx in (-0.445, 0.445):
    box(f"plate_rim_x{sx}", (0.026, 0.64, 0.026), (sx, -0.14, 1.278), CAST_RING, 0.004)
# Две наборные чугунные конфорки (большая и малая) с глубокими канавками и заглушкой с проушиной
for i, (x, r) in enumerate(((-0.19, 0.138), (0.18, 0.108))):
    cyl(f"burner_well_{i}", r + 0.008, 0.008, (x, -0.15, 1.273), BLACK, rot=(0, 0, 0), verts=18)
    torus(f"ring_out_{i}", r, 0.012, (x, -0.15, 1.280), CAST_RING, rot=(0, 0, 0), maj=20, mino=6)
    torus(f"ring_mid_{i}", r * 0.68, 0.010, (x, -0.15, 1.281), CAST_IRON, rot=(0, 0, 0), maj=18, mino=6)
    cyl(f"lid_center_{i}", r * 0.42, 0.015, (x, -0.15, 1.280), CAST_RING, rot=(0, 0, 0), verts=14)
    # Прорезь под крючок-съёмник в центре заглушки
    box(f"lid_slot_{i}", (0.028, 0.010, 0.008), (x, -0.15, 1.288), BLACK, 0.0)
# Чугунная перекладина-сушилка спереди плиты
tube("plate_rail", [
    (-0.36, -0.46, 1.276), (-0.36, -0.50, 1.276),
    ( 0.36, -0.50, 1.276), ( 0.36, -0.46, 1.276),
], 0.007, BRASS, verts=6)

# 4. Топка: массивная литая чугунная рамка, тёмное устье с углями и колосником,
#    рельефная приоткрытая чугунная дверца с рёбрами и латунным вертушком
TZ = 0.50
box("fb_frame_outer", (0.48, 0.032, 0.34), (0, FY - 0.012, TZ), CAST_IRON, 0.005)
box("fb_frame_inner", (0.42, 0.038, 0.28), (0, FY - 0.015, TZ), CAST_RING, 0.003)
box("fb_hole", (0.36, 0.044, 0.23), (0, FY - 0.008, TZ), BLACK, 0.0)
box("embers", (0.33, 0.025, 0.065), (0, FY - 0.010, TZ - 0.085), EMBER, 0.0)
for i in range(5):
    box(f"grate_{i}", (0.008, 0.024, 0.055), (-0.13 + i * 0.065, FY - 0.016, TZ - 0.090), CAST_IRON, 0.0)

# Приоткрытая чугунная дверца слева на петлях (не перекрывает центр топки для _fire_glow в station.gd!)
door = box("fb_door", (0.24, 0.018, 0.25), (0, 0, 0), CAST_IRON, 0.004)
for dz in (-0.075, 0.075):
    box(f"fb_rib_{dz}", (0.20, 0.008, 0.016), (0, -0.012, dz), CAST_RING, 0.002)
    kit.objs[-1].parent = door
# Советский чугунный ромбовидный рельеф по центру дверцы
box("fb_diamond", (0.075, 0.009, 0.075), (0, -0.012, 0.0), CAST_RING, 0.002, rot=(0, math.radians(45), 0))
kit.objs[-1].parent = door
cyl("fb_knob", 0.014, 0.034, (0.09, -0.024, 0.0), BRASS, rot=(math.pi * 0.5, 0, 0), verts=10)
kit.objs[-1].parent = door
box("fb_latch", (0.055, 0.010, 0.016), (0.09, -0.036, 0.0), BRASS, 0.002, rot=(0, math.radians(22), 0))
kit.objs[-1].parent = door

ang_open = math.radians(112.0)
door.location = (-0.235 - 0.12 * math.cos(ang_open), FY - 0.018 - 0.12 * math.sin(ang_open), TZ)
door.rotation_euler = (0, 0, ang_open)

for dz in (-0.085, 0.085):
    cyl(f"hinge_{dz}", 0.012, 0.048, (-0.235, FY - 0.020, TZ + dz), CAST_RING, rot=(0, 0, 0), verts=10)
box("fb_soot", (0.52, 0.004, 0.22), (0, FY - 0.003, TZ + 0.25), SOOT, 0.0)

# 5. Поддувало: чугунная рамка и тёмный зев (подвижную дверцу ДП-1 ставит station.gd)
box("ash_frame", (0.32, 0.024, 0.145), (0, FY - 0.010, 0.18), CAST_IRON, 0.004)
box("ash_hole", (0.24, 0.028, 0.095), (0, FY - 0.006, 0.18), BLACK, 0.0)

# 6. Печурка для варежек и спичек на правом боку
box("niche", (0.022, 0.19, 0.15), (H - 0.004, 0.05, 0.86), SOOT, 0.0)
box("niche_lip", (0.016, 0.23, 0.018), (H + 0.005, 0.05, 0.785), BRICK, 0.002)

# 7. Пожарный предтопочный лист железа с клёпкой по краям
box("fire_sheet", (0.76, 0.44, 0.006), (0, FY - 0.26, 0.003), IRON_RUST, 0.002)

# 8. Кирпичная труба до потолка с разделкой
box("chimney", (0.42, 0.38, CEIL - 1.24), (0, 0.19, 1.24 + (CEIL - 1.24) * 0.5), BRICK_PIPE, 0.008)
box("chim_band", (0.46, 0.42, 0.052), (0, 0.19, 1.62), BRICK_PIPE, 0.006)
box("razdelka", (0.62, 0.58, 0.26), (0, 0.19, CEIL - 0.13), BRICK_PIPE, 0.01)
box("razdelka_band", (0.64, 0.60, 0.032), (0, 0.19, CEIL - 0.27), CAST_IRON, 0.003)

# 9. Кочерга и берёзовые поленья у правого бока
tube("poker", [(0.50, -0.32, 0.02), (0.53, -0.30, 0.95)], 0.008, CAST_IRON, 6)
tube("poker_hook", [(0.50, -0.32, 0.02), (0.46, -0.36, 0.05)], 0.008, CAST_IRON, 6)
torus("poker_ring", 0.024, 0.006, (0.535, -0.30, 0.98), CAST_IRON, rot=(math.pi * 0.5, 0, 0), maj=12, mino=5)
for i, (x, y, rz) in enumerate(((0.58, 0.12, 10), (0.60, 0.28, -14))):
    cyl(f"log_{i}", 0.045, 0.34, (x, y, 0.05), WOOD, rot=(math.pi * 0.5, 0, math.radians(rz)), verts=10)

body, img, tris = kit.finish("stove_brick", OUT, res=1024, origin="keep", samples=40, ao_min=0.35)
kit.export(os.path.join(OUT, "stove_brick.glb"), os.path.join(OUT, "stove_brick.blend"))
print(f"[OK] stove_brick exported: {tris} tris")
