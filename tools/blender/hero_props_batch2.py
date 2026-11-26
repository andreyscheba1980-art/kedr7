# Пакетная генерация второй очереди PS1-моделей реквизита «Кедр-7» (Blender 5.2, gl_compatibility).
# Создаёт 8 моделей в assets/models/kedr/:
#   1. storage_shelves   — стеллаж кладовой с коробками ламп и банками
#   2. woodbox_frame     — дощатый ящик под дрова у печи (брёвна добавляет игра динамически по count)
#   3. firewood_bundle   — охапка колотых берёзовых и сосновых поленьев на бечёвке
#   4. valenki           — пара советских валенок в чёрных резиновых калошах
#   5. seismograph_sv20  — сейсмоприёмник СВ-20 «Слухач» с барабаном самописца и трубкой
#   6. bear_trap         — стальной ржавый капкан с зубьями, тарелочкой и пружиной
#   7. surveyor_sledge   — экспедиционные деревянные нарты с брезентом, ящиками и полозьями
#   8. kedr_supply_crate — дощатый ящик 0.8×0.6×0.6 со стальными оковками
#
# Запуск:
#   blender --background --factory-startup --python tools/blender/hero_props_batch2.py -- assets/models/kedr

import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, tube

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/kedr"
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)


def want(name):
    return not ONLY or name in ONLY


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


def make_mat(name, col, rough=0.72, noise=0.12, scale=42.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf_of(m)
    base_inp = _inp(b, ("Base Color", "Базовый цвет"), 0)
    rough_inp = _inp(b, ("Roughness", "Шероховатость"), 2)
    metal_inp = _inp(b, ("Metallic", "Металличность"), 1)
    rough_inp.default_value = rough
    metal_inp.default_value = 0.0
    if noise > 0:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Detail"].default_value = 5
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (col[0] * (1 - noise), col[1] * (1 - noise), col[2] * (1 - noise), 1.0)
        ramp.color_ramp.elements[1].color = (min(col[0] * (1 + noise), 1.0), min(col[1] * (1 + noise), 1.0), min(col[2] * (1 + noise), 1.0), 1.0)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], base_inp)
    else:
        base_inp.default_value = (*col, 1.0)
    return m


def _bake_and_save(name, res=256, origin="bottom", samples=16, ao_min=0.40):
    body, img, tris = kit.finish(name, OUT, res=res, origin=origin, samples=samples, ao_min=ao_min)
    glb_path = os.path.join(OUT, name + ".glb")
    kit.export(glb_path, None)
    png_path = os.path.join(OUT, name + ".png")
    if os.path.exists(png_path):
        try:
            os.remove(png_path)
        except OSError:
            pass
    print(f"[OK] {name}.glb exported ({tris} tris, {os.path.getsize(glb_path) // 1024} KB)")


def build_storage_shelves():
    kit.reset()
    WOOD = make_mat("wood", (0.35, 0.25, 0.16), 0.78, noise=0.14)
    DARK = make_mat("dark", (0.21, 0.15, 0.09), 0.80, noise=0.12)
    CARDBOARD = make_mat("cardboard", (0.55, 0.44, 0.30), 0.85, noise=0.10)
    LABEL = make_mat("label", (0.86, 0.82, 0.72), 0.70, noise=0.04)
    TIN = make_mat("tin", (0.24, 0.28, 0.26), 0.50, noise=0.10)

    for sx in (-0.68, 0.68):
        for sy in (-0.18, 0.18):
            box(f"post_{sx}_{sy}", (0.055, 0.055, 1.70), (sx, sy, 0.85), DARK, bevel=0.003)
    for z in (0.35, 0.80, 1.25, 1.65):
        box(f"shelf_{z}", (1.42, 0.42, 0.036), (0.0, 0.0, z), WOOD, bevel=0.003)
    # Картонные коробки с запасными лампами на верхней полке
    for i in range(4):
        cx = -0.45 + i * 0.18
        box(f"box_{i}", (0.15, 0.18, 0.14), (cx, 0.05, 1.34), CARDBOARD, bevel=0.002)
        box(f"lbl_{i}", (0.12, 0.004, 0.06), (cx, -0.042, 1.34), LABEL, bevel=0.001)
    # Банки тушёнки и консервы на средней полке
    for i in range(5):
        cx = -0.48 + i * 0.14
        cyl(f"can_{i}", 0.046, 0.11, (cx, -0.02, 0.875), TIN, rot=(0, 0, 0), verts=10)

    _bake_and_save("storage_shelves", res=256, origin="bottom", samples=16)


def build_woodbox_frame():
    kit.reset()
    WOOD = make_mat("wood", (0.40, 0.28, 0.17), 0.82, noise=0.16)
    DARK = make_mat("dark", (0.24, 0.17, 0.10), 0.84, noise=0.12)
    IRON = make_mat("iron", (0.20, 0.20, 0.22), 0.55, noise=0.10)

    box("bottom", (0.70, 0.45, 0.04), (0.0, 0.0, 0.02), DARK, bevel=0.002)
    box("side_l", (0.04, 0.45, 0.40), (-0.33, 0.0, 0.22), WOOD, bevel=0.003)
    box("side_r", (0.04, 0.45, 0.40), (0.33, 0.0, 0.22), WOOD, bevel=0.003)
    box("back", (0.66, 0.03, 0.40), (0.0, 0.21, 0.22), WOOD, bevel=0.003)
    box("front", (0.66, 0.03, 0.16), (0.0, -0.21, 0.10), WOOD, bevel=0.003)
    for sx in (-0.33, 0.33):
        for sy in (-0.21, 0.21):
            box(f"cleat_{sx}_{sy}", (0.045, 0.045, 0.38 if sy > 0 else 0.16), (sx, sy, 0.21 if sy > 0 else 0.10), IRON, bevel=0.002)

    _bake_and_save("woodbox_frame", res=256, origin="bottom", samples=16)


def build_firewood_bundle():
    kit.reset()
    BIRCH = make_mat("birch", (0.76, 0.74, 0.68), 0.85, noise=0.18, scale=48.0)
    PINE = make_mat("pine", (0.28, 0.19, 0.13), 0.88, noise=0.16)
    CORE = make_mat("heartwood", (0.62, 0.48, 0.31), 0.78, noise=0.12)
    ROPE = make_mat("rope", (0.48, 0.41, 0.28), 0.90, noise=0.10)

    logs = [
        (-0.085, 0.060, 0.056, BIRCH, 0.0),
        (0.085, 0.062, 0.058, PINE, 0.1),
        (0.0, 0.058, 0.052, CORE, -0.08),
        (-0.048, 0.145, 0.054, PINE, 0.05),
        (0.052, 0.145, 0.055, BIRCH, -0.05),
    ]
    for idx, (lx, lz, lr, m, yaw) in enumerate(logs):
        cyl(f"log_{idx}", lr, 0.44, (lx, 0.0, lz), m, rot=(math.pi * 0.5, 0.0, yaw), verts=8)
        for sy in (-0.221, 0.221):
            cyl(f"end_{idx}_{sy}", lr * 0.92, 0.004, (lx, sy, lz), CORE, rot=(math.pi * 0.5, 0.0, yaw), verts=8)
    for ry in (-0.11, 0.11):
        tube(f"twine_{ry}", [
            (-0.14, ry, 0.06), (-0.09, ry, 0.19), (0.0, ry, 0.205), (0.09, ry, 0.19),
            (0.14, ry, 0.06), (0.09, ry, 0.005), (-0.09, ry, 0.005), (-0.14, ry, 0.06)
        ], 0.007, ROPE, verts=6)

    _bake_and_save("firewood_bundle", res=256, origin="bottom", samples=16)


def build_valenki():
    kit.reset()
    FELT = make_mat("felt", (0.28, 0.27, 0.26), 0.92, noise=0.14, scale=55.0)
    GALOSH = make_mat("galosh", (0.07, 0.07, 0.08), 0.42, noise=0.06)
    RED_LINING = make_mat("lining", (0.42, 0.12, 0.10), 0.85, noise=0.05)

    for sx in (-0.085, 0.085):
        # Резиновая калоша (мыс смотрит вперёд, в -Y Blender -> +Z Godot)
        box(f"gal_{sx}", (0.112, 0.25, 0.048), (sx, -0.04, 0.024), GALOSH, bevel=0.012)
        cyl(f"toe_{sx}", 0.052, 0.06, (sx, -0.10, 0.036), GALOSH, rot=(0, 0, 0), verts=10)
        # Войлочная стопа и высокое голенище
        box(f"foot_{sx}", (0.10, 0.22, 0.058), (sx, -0.03, 0.066), FELT, bevel=0.014)
        cyl(f"shaft_{sx}", 0.062, 0.30, (sx, 0.01, 0.23), FELT, rot=(0, 0, 0), verts=12, r2=0.067)
        cyl(f"cuff_{sx}", 0.069, 0.016, (sx, 0.01, 0.382), FELT, rot=(0, 0, 0), verts=12)
        cyl(f"in_{sx}", 0.054, 0.01, (sx, 0.01, 0.385), RED_LINING, rot=(0, 0, 0), verts=10)

    _bake_and_save("valenki", res=256, origin="bottom", samples=16)


def build_seismograph_sv20():
    kit.reset()
    BODY = make_mat("cast_iron", (0.20, 0.25, 0.22), 0.60, noise=0.10)
    DARK = make_mat("dark", (0.10, 0.11, 0.12), 0.50, noise=0.08)
    PAPER = make_mat("paper", (0.90, 0.87, 0.78), 0.82, noise=0.05)
    BRASS = make_mat("brass", (0.64, 0.50, 0.22), 0.36, noise=0.08)
    BAKELITE = make_mat("bakelite", (0.06, 0.06, 0.07), 0.38, noise=0.04)
    INK = make_mat("ink", (0.14, 0.16, 0.42), 0.65)

    box("base", (0.36, 0.26, 0.08), (0.0, 0.0, 0.05), BODY, bevel=0.004)
    for sx in (-0.15, 0.15):
        for sy in (-0.10, 0.10):
            cyl(f"foot_{sx}_{sy}", 0.016, 0.018, (sx, sy, 0.009), BRASS, rot=(0, 0, 0), verts=8)
    # Вертикальный датчик слева
    cyl("sensor", 0.062, 0.16, (-0.095, 0.0, 0.165), BODY, rot=(0, 0, 0), verts=14)
    cyl("sensor_cap", 0.065, 0.018, (-0.095, 0.0, 0.248), BRASS, rot=(0, 0, 0), verts=14)
    # Барабан самописца с бумажной лентой и синей линией
    cyl("drum", 0.048, 0.13, (0.08, 0.0, 0.155), BRASS, rot=(0, 0, 0), verts=16)
    cyl("paper", 0.050, 0.112, (0.08, 0.0, 0.155), PAPER, rot=(0, 0, 0), verts=16)
    cyl("trace_line", 0.051, 0.006, (0.08, 0.0, 0.155), INK, rot=(0, 0, 0), verts=16)
    # Рычаг пера
    tube("pen_arm", [(-0.02, 0.0, 0.165), (0.025, -0.015, 0.155), (0.032, -0.02, 0.155)], 0.004, DARK, verts=6)
    # Телефонная трубка «Слухач» сверху на скобе
    box("cradle", (0.08, 0.05, 0.04), (0.0, 0.06, 0.105), BRASS, bevel=0.002)
    tube("handset", [(-0.09, 0.06, 0.13), (0.0, 0.06, 0.145), (0.09, 0.06, 0.13)], 0.014, BAKELITE, verts=8)
    cyl("ear", 0.028, 0.024, (-0.09, 0.06, 0.125), BAKELITE, rot=(math.radians(20), 0, 0), verts=10)
    cyl("mouth", 0.028, 0.024, (0.09, 0.06, 0.125), BAKELITE, rot=(math.radians(-20), 0, 0), verts=10)

    _bake_and_save("seismograph_sv20", res=256, origin="bottom", samples=16)


def build_bear_trap():
    kit.reset()
    RUST = make_mat("rust", (0.28, 0.20, 0.16), 0.72, noise=0.18, scale=50.0)
    STEEL = make_mat("steel", (0.22, 0.23, 0.25), 0.50, noise=0.12)

    for sy in (-1, 1):
        pts = [(-0.24, sy * 0.10, 0.02), (-0.14, sy * 0.22, 0.02), (0.0, sy * 0.25, 0.02), (0.14, sy * 0.22, 0.02), (0.24, sy * 0.10, 0.02)]
        tube(f"jaw_{sy}", pts, 0.018, RUST, verts=6)
        for i in range(5):
            tx = -0.16 + i * 0.08
            cyl(f"tooth_{sy}_{i}", 0.012, 0.055, (tx, sy * 0.20, 0.045), STEEL, rot=(0, 0, 0), verts=4, r2=0.002)
    # Насторожка-тарелочка и мощная V-пружина
    cyl("pan", 0.075, 0.016, (0.0, 0.0, 0.014), RUST, rot=(0, 0, 0), verts=12)
    box("cross", (0.50, 0.045, 0.018), (0.0, 0.0, 0.009), RUST, bevel=0.002)
    box("spring_top", (0.22, 0.065, 0.022), (0.31, 0.0, 0.022), STEEL, bevel=0.003)

    _bake_and_save("bear_trap", res=256, origin="bottom", samples=16)


def build_surveyor_sledge():
    kit.reset()
    WOOD = make_mat("wood", (0.34, 0.25, 0.17), 0.80, noise=0.15)
    DARK = make_mat("dark", (0.22, 0.16, 0.11), 0.84, noise=0.12)
    STEEL = make_mat("steel", (0.20, 0.21, 0.23), 0.50, noise=0.12)
    TARP = make_mat("tarp", (0.23, 0.28, 0.23), 0.88, noise=0.14)
    ROPE = make_mat("rope", (0.50, 0.43, 0.30), 0.90, noise=0.08)
    SNOW = make_mat("snow", (0.86, 0.90, 0.95), 0.90, noise=0.08)

    # Полозья с загнутыми передними носками (-Y Blender -> +Z Godot)
    for sx in (-0.54, 0.54):
        box(f"runner_{sx}", (0.13, 2.40, 0.14), (sx, 0.10, 0.09), DARK, bevel=0.005)
        box(f"shoe_{sx}", (0.14, 2.42, 0.024), (sx, 0.10, 0.012), STEEL, bevel=0.002)
        tube(f"curl_{sx}", [(sx, -1.08, 0.09), (sx, -1.30, 0.22), (sx, -1.42, 0.42)], 0.062, DARK, verts=6)
    # Стойки и поперечный настил
    for sy in (-0.75, 0.0, 0.75):
        for sx in (-0.54, 0.54):
            box(f"stanchion_{sx}_{sy}", (0.08, 0.08, 0.24), (sx, sy, 0.27), DARK, bevel=0.003)
        box(f"cross_{sy}", (1.24, 0.12, 0.06), (0.0, sy, 0.39), WOOD, bevel=0.003)
    for sx in (-0.42, -0.14, 0.14, 0.42):
        box(f"plank_{sx}", (0.22, 2.15, 0.04), (sx, 0.10, 0.44), WOOD, bevel=0.003)
    # Груз под выцветшим брезентом, перетянутый верёвками, со снежной наледью
    box("cargo", (0.96, 1.55, 0.44), (0.0, 0.15, 0.68), TARP, bevel=0.04)
    box("snow_cap", (0.76, 1.15, 0.06), (0.0, 0.18, 0.90), SNOW, bevel=0.02)
    for sy in (-0.35, 0.15, 0.65):
        tube(f"rope_{sy}", [(-0.56, sy, 0.44), (-0.50, sy, 0.91), (0.50, sy, 0.91), (0.56, sy, 0.44)], 0.014, ROPE, verts=6)

    _bake_and_save("surveyor_sledge", res=256, origin="bottom", samples=16)


def build_kedr_supply_crate():
    kit.reset()
    WOOD = make_mat("wood", (0.38, 0.29, 0.20), 0.78, noise=0.14)
    IRON = make_mat("iron", (0.20, 0.20, 0.22), 0.52, noise=0.10)
    STENCIL = make_mat("stencil", (0.62, 0.16, 0.14), 0.70, noise=0.05)

    box("core", (0.78, 0.58, 0.58), (0.0, 0.0, 0.30), WOOD, bevel=0.005)
    for sx in (-0.37, 0.37):
        box(f"strap_x_{sx}", (0.05, 0.60, 0.60), (sx, 0.0, 0.30), IRON, bevel=0.002)
    for sy in (-0.27, 0.27):
        box(f"strap_y_{sy}", (0.80, 0.05, 0.60), (0.0, sy, 0.30), IRON, bevel=0.002)
    box("mark", (0.22, 0.005, 0.08), (0.0, -0.292, 0.32), STENCIL, bevel=0.001)

    _bake_and_save("kedr_supply_crate", res=256, origin="bottom", samples=16)


if __name__ == "__main__":
    if want("storage_shelves"):
        build_storage_shelves()
    if want("woodbox_frame"):
        build_woodbox_frame()
    if want("firewood_bundle"):
        build_firewood_bundle()
    if want("valenki"):
        build_valenki()
    if want("seismograph_sv20"):
        build_seismograph_sv20()
    if want("bear_trap"):
        build_bear_trap()
    if want("surveyor_sledge"):
        build_surveyor_sledge()
    if want("kedr_supply_crate"):
        build_kedr_supply_crate()
