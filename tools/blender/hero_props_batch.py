# Пакетная генерация PS1-моделей реквизита «Кедр-7» (1983, gl_compatibility) в Blender 5.2.
# Создаёт 7 моделей в assets/models/kedr/:
#   1. soviet_garland_wire — витой провод, изоляторы и 12 карболитово-латунных цоколей «Золотой фонарик»
#   2. soviet_desk         — письменный стол оператора (2.10 × 0.75 × 0.85, 3 ящика с латунными ручками)
#   3. soviet_chair        — венский деревянный стул с гнутой спинкой
#   4. soviet_bed          — армейская металлическая койка с шариками, матрасом, одеялом с полосой и подушкой
#   5. oil_can_ms20        — жестяная канистра масла МС-20 с красной этикеткой и латунным носиком
#   6. snow_shovel_wood    — фанерная снеговая лопата со стальной оковкой и черенком
#   7. axe_stump           — сосновая плаха с корой, трещиной и воткнутым кованым топором
#
# Запуск:
#   blender --background --factory-startup --python tools/blender/hero_props_batch.py -- assets/models/kedr

import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube

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


def make_mat(name, col, rough=0.7, noise=0.10, scale=45.0):
    """Безопасный RU/EN материал с лёгким шумом фактуры без зависимости от имён сокетов."""
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


def _bake_and_save(name, res=256, origin="bottom", samples=18, ao_min=0.40):
    body, img, tris = kit.finish(name, OUT, res=res, origin=origin, samples=samples, ao_min=ao_min)
    glb_path = os.path.join(OUT, name + ".glb")
    kit.export(glb_path, None)
    # Удаляем промежуточный PNG: текстура уже вшита в GLB
    png_path = os.path.join(OUT, name + ".png")
    if os.path.exists(png_path):
        try:
            os.remove(png_path)
        except OSError:
            pass
    print(f"[OK] {name}.glb exported ({tris} tris, {os.path.getsize(glb_path) // 1024} KB)")


def build_soviet_garland_wire():
    kit.reset()
    WIRE = make_mat("wire", (0.05, 0.05, 0.06), 0.78, noise=0.05)
    BAKELITE = make_mat("bakelite", (0.14, 0.22, 0.14), 0.45, noise=0.08)
    BRASS = make_mat("brass", (0.72, 0.56, 0.22), 0.35, noise=0.10)
    PORCELAIN = make_mat("porcelain", (0.82, 0.80, 0.74), 0.40, noise=0.05)

    width = 1.9
    drop = 0.22
    pts = []
    for i in range(19):
        t = i / 18.0
        x = (t - 0.5) * (width + 0.12)
        z = -4.0 * drop * t * (1.0 - t) + 0.015
        pts.append((x, 0.0, z))
    tube("cable", pts, 0.0045, WIRE, verts=6)

    # Концевые фарфоровые ролики крепления к стене
    for sx in (-1, 1):
        cx = sx * (width * 0.5 + 0.06)
        cyl(f"cleat_{sx}", 0.014, 0.022, (cx, 0.005, 0.015), PORCELAIN, rot=(math.pi * 0.5, 0, 0), verts=10)
        sphere(f"screw_{sx}", 0.005, (cx, -0.008, 0.015), BRASS, segs=6, rings=4)

    # 12 карболитовых патронов + лепестковые короны «Золотой фонарик»
    n_bulbs = 12
    for i in range(n_bulbs):
        t = i / float(n_bulbs - 1)
        x = (t - 0.5) * width
        z = -4.0 * drop * t * (1.0 - t)
        ang = (t - 0.5) * 0.35
        # Узелок крепления к проводу
        box(f"knot_{i}", (0.016, 0.014, 0.014), (x, 0.0, z + 0.004), BAKELITE, bevel=0.002, rot=(0, -ang, 0))
        # Карболитовый патрон
        cyl(f"socket_{i}", 0.012, 0.020, (x, 0.0, z - 0.006), BAKELITE, rot=(0, -ang, 0), verts=8)
        # Золотой рефлектор-звёздочка над лампочкой
        cyl(f"crown_{i}", 0.024, 0.008, (x, 0.0, z - 0.016), BRASS, rot=(0, -ang, 0), verts=6, r2=0.013)

    _bake_and_save("soviet_garland_wire", res=256, origin="keep", samples=14)


def build_soviet_desk():
    kit.reset()
    OAK = make_mat("oak", (0.30, 0.21, 0.13), 0.72, noise=0.14, scale=28.0)
    OAK_DARK = make_mat("oak_dark", (0.20, 0.14, 0.09), 0.78, noise=0.12, scale=32.0)
    BRASS = make_mat("brass", (0.68, 0.52, 0.22), 0.38, noise=0.08)
    INK_STAIN = make_mat("ink", (0.14, 0.14, 0.19), 0.85, noise=0.15)

    # Столешница 2.10 x 0.85, верх ровно на Z = 0.75
    box("top", (2.10, 0.85, 0.05), (0.0, 0.0, 0.725), OAK, bevel=0.005)
    box("apron_front", (1.60, 0.03, 0.08), (-0.15, -0.37, 0.66), OAK_DARK, bevel=0.002)
    box("apron_back", (1.60, 0.03, 0.08), (-0.15, 0.37, 0.66), OAK_DARK, bevel=0.002)
    # Пятно-след от журнала/подстаканника
    cyl("desk_stain", 0.065, 0.001, (0.12, -0.14, 0.7505), INK_STAIN, rot=(0, 0, 0), verts=12)

    # Левые 4 ножки
    for sx in (-0.96, -0.38):
        for sy in (-0.36, 0.36):
            box(f"leg_{sx}_{sy}", (0.06, 0.06, 0.70), (sx, sy, 0.35), OAK_DARK, bevel=0.003)
    # Продольные перекладины (царги)
    box("crossbar_l", (0.035, 0.70, 0.04), (-0.67, 0.0, 0.16), OAK_DARK, bevel=0.002)
    box("crossbar_main", (1.30, 0.035, 0.04), (-0.10, 0.36, 0.16), OAK_DARK, bevel=0.002)

    # Правая тумба с 3 ящиками (перед = -Y в Blender -> +Z в Godot)
    box("pedestal", (0.56, 0.76, 0.68), (0.70, 0.0, 0.36), OAK_DARK, bevel=0.004)
    for sx in (0.45, 0.95):
        for sy in (-0.34, 0.34):
            box(f"pleg_{sx}_{sy}", (0.045, 0.045, 0.04), (sx, sy, 0.02), OAK_DARK, bevel=0.002)
    for i in range(3):
        z = 0.16 + i * 0.205
        box(f"drawer_{i}", (0.50, 0.02, 0.175), (0.70, -0.385, z), OAK, bevel=0.003)
        # Скоба ручки ящика
        tube(f"pull_{i}", [(0.64, -0.398, z), (0.64, -0.415, z), (0.76, -0.415, z), (0.76, -0.398, z)], 0.006, BRASS, verts=6)
        box(f"lock_{i}", (0.022, 0.006, 0.032), (0.70, -0.396, z + 0.045), BRASS, bevel=0.001)

    _bake_and_save("soviet_desk", res=256, origin="bottom", samples=18)


def build_soviet_chair():
    kit.reset()
    WOOD = make_mat("wood", (0.32, 0.22, 0.13), 0.72, noise=0.14, scale=35.0)
    DARK = make_mat("wood_dark", (0.21, 0.14, 0.08), 0.76, noise=0.12)

    # Сиденье на Z = 0.435 (низ ножек на Z = 0.0)
    box("seat", (0.44, 0.42, 0.038), (0.0, 0.0, 0.435), WOOD, bevel=0.008)
    for sx in (-0.185, 0.185):
        for sy in (-0.175, 0.175):
            box(f"leg_{sx}_{sy}", (0.038, 0.038, 0.42), (sx, sy, 0.21), DARK, bevel=0.003)
    # Проножки
    box("rung_f", (0.37, 0.024, 0.024), (0.0, -0.175, 0.14), DARK, bevel=0.002)
    box("rung_l", (0.024, 0.35, 0.024), (-0.185, 0.0, 0.16), DARK, bevel=0.002)
    box("rung_r", (0.024, 0.35, 0.024), (0.185, 0.0, 0.16), DARK, bevel=0.002)
    # Спинка (+Y в Blender -> -Z в Godot, лицом к +Z Godot)
    for sx in (-0.185, 0.185):
        box(f"stile_{sx}", (0.038, 0.036, 0.50), (sx, 0.185, 0.68), DARK, bevel=0.004)
    box("slat_top", (0.42, 0.026, 0.11), (0.0, 0.185, 0.84), WOOD, bevel=0.005)
    box("slat_mid", (0.39, 0.022, 0.05), (0.0, 0.185, 0.64), WOOD, bevel=0.004)

    _bake_and_save("soviet_chair", res=256, origin="bottom", samples=16)


def build_soviet_bed():
    kit.reset()
    IRON = make_mat("iron", (0.14, 0.17, 0.15), 0.58, noise=0.10)
    BRASS = make_mat("brass", (0.68, 0.52, 0.22), 0.35, noise=0.08)
    MATTRESS = make_mat("mattress", (0.58, 0.56, 0.50), 0.88, noise=0.12)
    BLANKET = make_mat("blanket", (0.30, 0.15, 0.11), 0.90, noise=0.14)
    STRIPE = make_mat("stripe", (0.58, 0.44, 0.18), 0.88, noise=0.10)
    PILLOW = make_mat("pillow", (0.80, 0.78, 0.72), 0.86, noise=0.10)

    # Изголовье на Y = -0.96, изножье на Y = +0.96
    for sy in (-0.96, 0.96):
        h = 0.94 if sy < 0 else 0.70
        for sx in (-0.43, 0.43):
            cyl(f"post_{sx}_{sy}", 0.018, h, (sx, sy, h * 0.5), IRON, rot=(0, 0, 0), verts=10)
            sphere(f"finial_{sx}_{sy}", 0.026, (sx, sy, h + 0.015), BRASS, segs=10, rings=6)
        tube(f"rail_{sy}", [(-0.43, sy, h), (0.43, sy, h)], 0.018, IRON, verts=8)
        tube(f"rail_low_{sy}", [(-0.43, sy, 0.30), (0.43, sy, 0.30)], 0.016, IRON, verts=8)
        for i in range(5):
            x = -0.30 + i * 0.15
            cyl(f"bal_{sy}_{i}", 0.008, h - 0.30, (x, sy, (h + 0.30) * 0.5), IRON, rot=(0, 0, 0), verts=6)

    for sx in (-0.43, 0.43):
        tube(f"side_{sx}", [(sx, -0.96, 0.30), (sx, 0.96, 0.30)], 0.020, IRON, verts=8)

    # Матрас, подушка и шерстяное одеяло
    box("mattress", (0.84, 1.90, 0.14), (0.0, 0.0, 0.38), MATTRESS, bevel=0.025)
    box("blanket", (0.88, 1.38, 0.045), (0.0, 0.24, 0.455), BLANKET, bevel=0.015)
    box("blanket_fold", (0.89, 0.14, 0.05), (0.0, -0.34, 0.462), BLANKET, bevel=0.012)
    box("blanket_stripe", (0.895, 0.06, 0.052), (0.0, 0.30, 0.458), STRIPE, bevel=0.005)
    box("blanket_drape", (0.025, 1.34, 0.18), (0.445, 0.24, 0.37), BLANKET, bevel=0.008)
    sphere("pillow", 0.20, (0.0, -0.70, 0.495), PILLOW, scale=(1.55, 0.92, 0.38), segs=14, rings=8)

    _bake_and_save("soviet_bed", res=256, origin="bottom", samples=18)


def build_oil_can_ms20():
    kit.reset()
    TIN = make_mat("tin", (0.18, 0.23, 0.19), 0.46, noise=0.10)
    TIN_BRIGHT = make_mat("tin_rim", (0.44, 0.46, 0.47), 0.35, noise=0.08)
    LABEL = make_mat("label", (0.72, 0.16, 0.12), 0.65, noise=0.06)
    CREAM = make_mat("cream", (0.88, 0.84, 0.72), 0.65, noise=0.05)
    BRASS = make_mat("brass", (0.72, 0.56, 0.22), 0.34, noise=0.08)

    box("body", (0.18, 0.11, 0.24), (0.0, 0.0, 0.13), TIN, bevel=0.008)
    box("rim_b", (0.188, 0.118, 0.018), (0.0, 0.0, 0.01), TIN_BRIGHT, bevel=0.003)
    box("rim_t", (0.188, 0.118, 0.018), (0.0, 0.0, 0.25), TIN_BRIGHT, bevel=0.003)
    # Рёбра жёсткости по стенке
    for rz in (0.07, 0.19):
        box(f"rib_{rz}", (0.184, 0.114, 0.010), (0.0, 0.0, rz), TIN_BRIGHT, bevel=0.002)
    # Красная и кремовая полосы этикетки МС-20 на фронте (-Y)
    box("label_red", (0.13, 0.004, 0.11), (0.0, -0.056, 0.13), LABEL, bevel=0.001)
    box("label_band", (0.132, 0.005, 0.03), (0.0, -0.056, 0.155), CREAM, bevel=0.001)
    # Горловина и проволочная ручка
    cyl("neck", 0.016, 0.022, (0.052, 0.0, 0.268), BRASS, rot=(0, 0, 0), verts=12)
    cyl("cap", 0.019, 0.012, (0.052, 0.0, 0.282), BRASS, rot=(0, 0, 0), verts=12)
    tube("handle", [(-0.06, 0.0, 0.258), (-0.06, 0.0, 0.302), (0.015, 0.0, 0.302), (0.015, 0.0, 0.258)], 0.006, TIN_BRIGHT, verts=8)

    _bake_and_save("oil_can_ms20", res=256, origin="bottom", samples=16)


def build_snow_shovel_wood():
    kit.reset()
    PLY = make_mat("plywood", (0.56, 0.44, 0.28), 0.76, noise=0.14, scale=32.0)
    ASH = make_mat("ash", (0.44, 0.33, 0.20), 0.72, noise=0.12)
    STEEL = make_mat("steel", (0.36, 0.39, 0.41), 0.42, noise=0.10)

    # Широкий фанерный совок с бортиками и оковкой
    box("blade", (0.50, 0.022, 0.46), (0.0, 0.0, 0.24), PLY, bevel=0.004)
    for sx in (-0.245, 0.245):
        box(f"cheek_{sx}", (0.020, 0.055, 0.44), (sx, -0.018, 0.24), PLY, bevel=0.003)
    box("edge", (0.515, 0.028, 0.036), (0.0, 0.0, 0.018), STEEL, bevel=0.002)
    # Стальная обойма крепления черенка
    box("socket", (0.058, 0.038, 0.12), (0.0, 0.008, 0.42), STEEL, bevel=0.003)
    # Длинный деревянный черенок
    cyl("shaft", 0.019, 1.05, (0.0, 0.018, 0.88), ASH, rot=(math.radians(-4), 0, 0), verts=10)
    # Верхняя перекладина рукояти
    cyl("grip", 0.016, 0.13, (0.0, 0.055, 1.40), ASH, rot=(0, math.pi * 0.5, 0), verts=10)

    _bake_and_save("snow_shovel_wood", res=256, origin="bottom", samples=16)


def build_axe_stump():
    kit.reset()
    BARK = make_mat("bark", (0.22, 0.17, 0.13), 0.92, noise=0.22, scale=42.0)
    HEART = make_mat("heartwood", (0.58, 0.46, 0.30), 0.78, noise=0.14, scale=26.0)
    CRACK = make_mat("crack", (0.08, 0.06, 0.05), 0.95, noise=0.05)
    STEEL = make_mat("forged_steel", (0.26, 0.28, 0.31), 0.45, noise=0.14)
    EDGE = make_mat("edge", (0.62, 0.64, 0.66), 0.28, noise=0.08)
    HANDLE = make_mat("birch", (0.52, 0.40, 0.25), 0.74, noise=0.12)

    # Плаха-чурбак
    cyl("stump", 0.24, 0.50, (0.0, 0.0, 0.25), BARK, rot=(0, 0, 0), verts=16, r2=0.22)
    cyl("top_cut", 0.215, 0.01, (0.0, 0.0, 0.501), HEART, rot=(0, 0, 0), verts=16)
    box("split_crack", (0.36, 0.016, 0.02), (0.0, 0.0, 0.498), CRACK, bevel=0.001, rot=(0, 0, 0.4))

    # Воткнутый кованый топор
    ax_rot = (math.radians(22), math.radians(-12), math.radians(20))
    box("axe_head", (0.045, 0.16, 0.095), (0.03, -0.02, 0.535), STEEL, bevel=0.004, rot=ax_rot)
    box("axe_edge", (0.012, 0.165, 0.035), (0.03, -0.02, 0.495), EDGE, bevel=0.002, rot=ax_rot)
    box("axe_haft", (0.030, 0.046, 0.56), (-0.01, 0.06, 0.76), HANDLE, bevel=0.005, rot=(math.radians(32), math.radians(-12), math.radians(20)))

    _bake_and_save("axe_stump", res=256, origin="bottom", samples=16)


if __name__ == "__main__":
    if want("soviet_garland_wire"):
        build_soviet_garland_wire()
    if want("soviet_desk"):
        build_soviet_desk()
    if want("soviet_chair"):
        build_soviet_chair()
    if want("soviet_bed"):
        build_soviet_bed()
    if want("oil_can_ms20"):
        build_oil_can_ms20()
    if want("snow_shovel_wood"):
        build_snow_shovel_wood()
    if want("axe_stump"):
        build_axe_stump()
