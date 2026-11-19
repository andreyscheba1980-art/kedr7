import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, Euler

# ==============================================================================
# ПАКЕТ 2: СОВЕТСКИЕ МОДЕЛИ ГОСКОМГИДРОМЕТА И ГЕОЛОГИИ 1983 ГОДА (11 УЗЛОВ)
# BLENDER 5.2 LTS -> GLTF 2.0 / GLB -> GODOT 4.7
# ==============================================================================

EXPORT_DIR = r"c:\Users\andre\OneDrive\Desktop\kedr7\assets\models\soviet"

def clean_scene():
    if bpy.context.active_object and bpy.context.active_object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)

def set_bsdf_input(bsdf, names, value):
    for n in names:
        if n in bsdf.inputs:
            bsdf.inputs[n].default_value = value
            return

def create_pbr(name, hex_col, metallic=0.0, roughness=0.5, alpha=1.0, transmission=0.0, emission=None, emission_strength=1.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        bsdf = mat.node_tree.nodes.new(type="ShaderNodeBsdfPrincipled")
        out = next((n for n in mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out:
            mat.node_tree.links.new(bsdf.outputs[0], out.inputs[0])

    h = hex_col.lstrip('#')
    rgb = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    lin = tuple(pow(c, 2.2) for c in rgb)

    set_bsdf_input(bsdf, ["Base Color"], (lin[0], lin[1], lin[2], 1.0))
    set_bsdf_input(bsdf, ["Metallic"], metallic)
    set_bsdf_input(bsdf, ["Roughness"], roughness)
    set_bsdf_input(bsdf, ["Alpha"], alpha)
    set_bsdf_input(bsdf, ["Transmission Weight", "Transmission"], transmission)

    if emission:
        eh = emission.lstrip('#')
        ergb = tuple(int(eh[i:i+2], 16) / 255.0 for i in (0, 2, 4))
        elin = tuple(pow(c, 2.2) for c in ergb)
        set_bsdf_input(bsdf, ["Emission Color", "Emission"], (elin[0], elin[1], elin[2], 1.0))
        set_bsdf_input(bsdf, ["Emission Strength"], emission_strength)

    if alpha < 1.0 or transmission > 0.0:
        if hasattr(mat, "blend_method"):
            mat.blend_method = 'BLEND'
    return mat

def init_mats():
    return {
        "DGA_Frame": create_pbr("M_DGA_Frame", "#3A4A42", 0.4, 0.45),
        "DGA_CastIron": create_pbr("M_DGA_CastIron", "#26201D", 0.85, 0.88),
        "Cadmium_Steel": create_pbr("M_Cadmium_Steel", "#B5AD96", 0.9, 0.35),
        "Hammer_Grey": create_pbr("M_Hammer_Grey", "#4C5654", 0.35, 0.42),
        "Carbolite_Black": create_pbr("M_Carbolite_Black", "#161517", 0.0, 0.28),
        "Glow_Nichrome": create_pbr("M_Glow_Nichrome", "#FF2A00", 0.1, 0.3, emission="#FF2A00", emission_strength=4.0),
        "Red_Plastic": create_pbr("M_Red_Plastic", "#A81C14", 0.0, 0.30),
        "Brass_Soot": create_pbr("M_Brass_Soot", "#7A6338", 0.92, 0.55),
        "Steel_Khaki": create_pbr("M_Steel_Khaki", "#5C3422", 0.4, 0.55),
        "Leather_Brown": create_pbr("M_Leather_Brown", "#3B2314", 0.0, 0.65),
        "Moire_Black": create_pbr("M_Moire_Black", "#1A1B1C", 0.1, 0.45),
        "Rubber_Red": create_pbr("M_Rubber_Red", "#6E221E", 0.0, 0.78),
        "Silumin_Grey": create_pbr("M_Silumin_Grey", "#7A8285", 0.65, 0.48),
        "Signal_Orange": create_pbr("M_Signal_Orange", "#C84B18", 0.1, 0.40),
        "Steel_Blued": create_pbr("M_Steel_Blued", "#222528", 0.95, 0.30),
        "Wood_Core": create_pbr("M_Wood_Core", "#8C7A62", 0.0, 0.88),
        "Core_Gabbro": create_pbr("M_Core_Gabbro", "#1C2024", 0.2, 0.25),
        "Plywood": create_pbr("M_Plywood", "#A08A6B", 0.0, 0.75),
        "Grey_Enamel": create_pbr("M_Grey_Enamel", "#5A6E78", 0.3, 0.38),
        "Mirror": create_pbr("M_Mirror", "#FFFFFF", 1.0, 0.05),
        "Glass_Dome": create_pbr("M_Glass_Dome", "#DCE8E6", 0.0, 0.08, alpha=0.35, transmission=0.85),
        "White_Paint": create_pbr("M_White_Paint", "#D8DDD8", 0.0, 0.60),
        "Black_Paint": create_pbr("M_Black_Paint", "#181818", 0.0, 0.60),
        "Rusty_Drum": create_pbr("M_Rusty_Drum", "#2B211E", 0.75, 0.85),
        "Snow_Frost": create_pbr("M_Snow_Frost", "#E8EFF5", 0.0, 0.90),
        "Carbolite_Brown": create_pbr("M_Carbolite_Brown", "#3D241A", 0.0, 0.32),
    }

def add_box(bm, size_xyz, center=(0, 0, 0)):
    ret = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size_xyz, verts=ret['verts'])
    bmesh.ops.translate(bm, vec=center, verts=ret['verts'])
    return ret['verts']

def add_cyl(bm, r_bot, r_top, depth, segments=16, center=(0, 0, 0), rot_euler=(0, 0, 0)):
    ret = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False,
        segments=segments, radius1=r_bot, radius2=r_top, depth=depth
    )
    if any(rot_euler):
        rot_mat = Euler(rot_euler, 'XYZ').to_matrix().to_4x4()
        bmesh.ops.rotate(bm, matrix=rot_mat, verts=ret['verts'])
    bmesh.ops.translate(bm, vec=center, verts=ret['verts'])
    return ret['verts']

def build_part(name, col, build_fn, mat, parent=None, local_pivot=(0, 0, 0), bevel=0.002):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm = bmesh.new()
    build_fn(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    for poly in mesh.polygons:
        poly.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)

    if mat:
        obj.data.materials.append(mat)

    obj.location = Vector(local_pivot)
    if parent:
        obj.parent = parent

    if bevel > 0.0:
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = bevel
        bev.segments = 2
        bev.limit_method = 'ANGLE'
        bev.angle_limit = math.radians(34.0)

    return obj

# ==============================================================================
# БЛОК А: ДИЗЕЛЬНАЯ СТАНЦИЯ ДГА-24 (4Ч 10.5/13)
# ==============================================================================

def build_model_1_dga_genset(mats, col):
    # SM_DGA24_Genset: 138 x 78 x 212 см (2.12 x 0.78 x 1.38 м)
    def body_genset(bm):
        # Сварная стальная рама из швеллеров
        add_box(bm, (0.78, 2.12, 0.18), center=(0, 0, 0.09))
        # Блок дизеля 4Ч 10.5/13 (чугун)
        add_box(bm, (0.54, 1.10, 0.72), center=(0, -0.42, 0.54))
        # Клапанная крышка 4 цилиндров
        add_box(bm, (0.36, 0.98, 0.22), center=(0, -0.42, 1.01))
        # Генератор ГСФ-24 (цилиндрический корпус)
        add_cyl(bm, 0.32, 0.32, 0.82, segments=24, center=(0, 0.55, 0.52), rot_euler=(math.pi/2, 0, 0))
        # Выхлопной коллектор и глушитель
        add_cyl(bm, 0.07, 0.07, 0.95, segments=12, center=(0.30, -0.42, 0.82), rot_euler=(math.pi/2, 0, 0))
        add_cyl(bm, 0.09, 0.09, 0.45, segments=12, center=(0.30, -0.90, 1.15))

    root = build_part("SM_DGA24_Genset", col, body_genset, mats["DGA_Frame"], bevel=0.003)

    # 1. Рычаг декомпрессора на клапанной крышке
    def decompressor_mesh(bm):
        add_box(bm, (0.04, 0.26, 0.03), (0, 0.10, 0))
        add_cyl(bm, 0.025, 0.025, 0.06, segments=12, center=(0, 0.22, 0))
    build_part("Lever_Decompressor", col, decompressor_mesh, mats["Cadmium_Steel"], parent=root, local_pivot=(0.18, -0.42, 1.10))

    # 2. Рукоятка плунжерного насоса РНМ-1 (масло)
    def rnm1_handle(bm):
        add_cyl(bm, 0.015, 0.015, 0.32, segments=12, center=(0, 0, 0.16), rot_euler=(0, math.pi/6, 0))
        add_box(bm, (0.04, 0.08, 0.04), (0, 0, 0.32))
    build_part("Handle_RNM1_OilPump", col, rnm1_handle, mats["Cadmium_Steel"], parent=root, local_pivot=(0.28, -0.22, 0.45))

    # 3. Шток ручной прокачки ТНВД
    def tnvd_plunger(bm):
        add_cyl(bm, 0.018, 0.018, 0.08, segments=12, center=(0, 0, 0.04))
        add_cyl(bm, 0.032, 0.032, 0.02, segments=16, center=(0, 0, 0.08))
    build_part("Plunger_TNVD_Primer", col, tnvd_plunger, mats["Brass_Soot"], parent=root, local_pivot=(-0.28, -0.35, 0.65))

    # 4. Латунный краник слива отстоя фильтра
    def drain_cock(bm):
        add_cyl(bm, 0.012, 0.012, 0.05, segments=8, center=(0, 0, -0.025))
        add_box(bm, (0.05, 0.015, 0.015), (0, 0, -0.01))
    build_part("Cock_Filter_Drain", col, drain_cock, mats["Brass_Soot"], parent=root, local_pivot=(-0.30, -0.80, 0.28))

    # 5. Маховик чугунный (120 кг, Ø52 см)
    def flywheel_mesh(bm):
        add_cyl(bm, 0.26, 0.26, 0.12, segments=32, center=(0, 0, 0), rot_euler=(math.pi/2, 0, 0))
    build_part("Flywheel_Main", col, flywheel_mesh, mats["DGA_CastIron"], parent=root, local_pivot=(0, 0.12, 0.52))

    return root

def build_model_2_dga_switchboard(mats, col):
    # SM_DGA24_Switchboard: 162 x 65 x 45 см (шкаф ЩСУ)
    def switchboard_body(bm):
        add_box(bm, (0.65, 0.45, 1.62), center=(0, 0, 0.81))
        # Козырек и петли
        add_box(bm, (0.67, 0.47, 0.04), center=(0, 0, 1.62))
        add_box(bm, (0.65, 0.02, 0.08), center=(0, -0.23, 0.04))

    root = build_part("SM_DGA24_Switchboard", col, switchboard_body, mats["Hammer_Grey"], bevel=0.003)

    # Приборы Э377, Э378, МД-214
    def meter_frame(bm):
        add_box(bm, (0.12, 0.03, 0.12), (0, -0.015, 0))
    build_part("Frame_Voltmeter_E377", col, meter_frame, mats["Carbolite_Black"], parent=root, local_pivot=(-0.16, -0.23, 1.25))
    build_part("Frame_Ammeter_E378", col, meter_frame, mats["Carbolite_Black"], parent=root, local_pivot=(0.16, -0.23, 1.25))

    def needle_mesh(bm):
        add_box(bm, (0.002, 0.005, 0.045), (0, -0.002, 0.02))
    build_part("Needle_Voltmeter_E377", col, needle_mesh, mats["Carbolite_Black"], parent=root, local_pivot=(-0.16, -0.245, 1.23))
    build_part("Needle_Ammeter_E378", col, needle_mesh, mats["Carbolite_Black"], parent=root, local_pivot=(0.16, -0.245, 1.23))

    def oil_gauge_mesh(bm):
        add_cyl(bm, 0.045, 0.045, 0.03, segments=16, center=(0, -0.015, 0), rot_euler=(math.pi/2, 0, 0))
    build_part("Needle_OilGauge_MD214", col, oil_gauge_mesh, mats["Carbolite_Black"], parent=root, local_pivot=(-0.16, -0.23, 1.02))

    # Вибрационный частотомер В85 (21 язычок в ряд)
    def v85_body(bm):
        add_box(bm, (0.16, 0.03, 0.08), (0, -0.015, 0))
    v85_frame = build_part("Frame_Freq_V85", col, v85_body, mats["Carbolite_Black"], parent=root, local_pivot=(0.16, -0.23, 1.02))

    for idx in range(21):
        x_pos = -0.065 + float(idx) * (0.13 / 20.0)
        def reed_mesh(bm, xp=x_pos):
            add_box(bm, (0.003, 0.002, 0.035), (0, -0.001, 0))
        build_part(f"Reeds_Freq_V85_{idx}", col, reed_mesh, mats["White_Paint"], parent=v85_frame, local_pivot=(x_pos, -0.032, 0.0))

    # Маховик реостата возбуждения РВ
    def rheostat_wheel(bm):
        add_cyl(bm, 0.05, 0.05, 0.035, segments=18, center=(0, -0.018, 0), rot_euler=(math.pi/2, 0, 0))
        add_cyl(bm, 0.015, 0.015, 0.05, segments=12, center=(0, -0.03, 0), rot_euler=(math.pi/2, 0, 0))
    build_part("Wheel_Rheostat_RV", col, rheostat_wheel, mats["Carbolite_Black"], parent=root, local_pivot=(-0.14, -0.23, 0.80))

    # Переключатель фаз ПМОФ-45
    def pmof_switch(bm):
        add_cyl(bm, 0.035, 0.035, 0.03, segments=16, center=(0, -0.015, 0), rot_euler=(math.pi/2, 0, 0))
        add_box(bm, (0.012, 0.03, 0.06), (0, -0.025, 0))
    build_part("Switch_Phase_PMOF45", col, pmof_switch, mats["Carbolite_Black"], parent=root, local_pivot=(0.14, -0.23, 0.80))

    # Контрольная нихромовая спираль «Соляной глаз»
    def glow_eye_mesh(bm):
        add_cyl(bm, 0.025, 0.025, 0.025, segments=16, center=(0, -0.012, 0), rot_euler=(math.pi/2, 0, 0))
        add_cyl(bm, 0.012, 0.012, 0.015, segments=12, center=(0, -0.025, 0), rot_euler=(math.pi/2, 0, 0))
    build_part("GlowEye_Spiral", col, glow_eye_mesh, mats["Glow_Nichrome"], parent=root, local_pivot=(0.0, -0.23, 0.64))

    return root

def build_model_3_pl64_blowtorch(mats, col):
    # SM_PL64_Blowtorch: 26 x 16 x 28 см
    def torch_body(bm):
        # Цилиндрический резервуар 1.5 л
        add_cyl(bm, 0.08, 0.08, 0.16, segments=24, center=(0, 0, 0.08))
        # Ручка стальная трубчатая
        add_box(bm, (0.025, 0.08, 0.14), (-0.10, 0, 0.09))
        # Чашечка розжига
        add_cyl(bm, 0.035, 0.045, 0.025, segments=16, center=(0.06, 0, 0.17))
        # Сопло / эжектор горелки
        add_cyl(bm, 0.022, 0.026, 0.11, segments=16, center=(0.08, 0, 0.21), rot_euler=(0, math.pi/2, 0))

    root = build_part("SM_PL64_Blowtorch", col, torch_body, mats["Steel_Khaki"], bevel=0.002)

    # Шток ручного воздушного насоса
    def pump_rod(bm):
        add_cyl(bm, 0.01, 0.01, 0.08, segments=12, center=(0, 0, 0.04))
        add_cyl(bm, 0.025, 0.025, 0.015, segments=16, center=(0, 0, 0.08))
    build_part("Pump_Rod_Knob", col, pump_rod, mats["Cadmium_Steel"], parent=root, local_pivot=(-0.04, 0, 0.16))

    # Карболитовый маховик регулировочного вентиля
    def valve_wheel(bm):
        add_cyl(bm, 0.022, 0.022, 0.02, segments=16, center=(0, 0, 0), rot_euler=(0, math.pi/2, 0))
    build_part("Valve_Wheel_Bakelite", col, valve_wheel, mats["Carbolite_Black"], parent=root, local_pivot=(0.01, 0, 0.21))

    return root

# ==============================================================================
# БЛОК Б: ШТОЛЬНЯ №4 (ЭКСПЕДИЦИЯ ДУБОВА, ОБЪЕКТ «ОТЗВУК»)
# ==============================================================================

def build_model_4_shi11_interferometer(mats, col):
    # SM_SHI11_Interferometer: 12.5 x 9.5 x 5.2 см
    def shi11_case(bm):
        # Кожаный футляр с крышкой
        add_box(bm, (0.095, 0.052, 0.125), (0, 0, 0.062))
        # Окулярная трубка
        add_cyl(bm, 0.018, 0.018, 0.03, segments=16, center=(0.02, 0.03, 0.11), rot_euler=(math.pi/2, 0, 0))

    root = build_part("SM_SHI11_Interferometer", col, shi11_case, mats["Leather_Brown"], bevel=0.002)

    # Резиновая груша-аспиратор на шланге
    def rubber_bulb(bm):
        add_cyl(bm, 0.028, 0.028, 0.07, segments=16, center=(0, 0, 0))
        add_cyl(bm, 0.008, 0.008, 0.08, segments=8, center=(0, 0, 0.06))
    build_part("Bulb_Rubber_Pump", col, rubber_bulb, mats["Rubber_Red"], parent=root, local_pivot=(-0.08, 0.04, 0.05))

    # Кнопка подсветки шкалы
    def btn_light(bm):
        add_cyl(bm, 0.008, 0.008, 0.015, segments=12, center=(0, 0, 0), rot_euler=(0, math.pi/2, 0))
    build_part("Btn_Light_Cap", col, btn_light, mats["Cadmium_Steel"], parent=root, local_pivot=(0.05, 0, 0.08))

    # Окулярная плоскость (для шейдера интерференции)
    def eyepiece_quad(bm):
        add_cyl(bm, 0.015, 0.015, 0.005, segments=16, center=(0, 0, 0), rot_euler=(math.pi/2, 0, 0))
    build_part("Eyepiece_Lens_Quad", col, eyepiece_quad, mats["Glass_Dome"], parent=root, local_pivot=(0.02, 0.045, 0.11))

    return root

def build_model_5_srp68_radiometer(mats, col):
    # SM_SRP68_Radiometer: 15 x 20 x 9.5 см + штанга 85 см
    def console_body(bm):
        # Литой силуминовый пульт
        add_box(bm, (0.20, 0.15, 0.095), (0, 0, 0.047))
        # Рамка микроамперметра со шкалой
        add_box(bm, (0.12, 0.08, 0.015), (0, -0.01, 0.095))

    root = build_part("SM_SRP68_Radiometer", col, console_body, mats["Silumin_Grey"], bevel=0.002)

    def meter_needle(bm):
        add_box(bm, (0.0015, 0.055, 0.002), (0, 0.025, 0))
    build_part("Needle_MicroR_Meter", col, meter_needle, mats["Carbolite_Black"], parent=root, local_pivot=(0, -0.02, 0.10))

    def range_switch(bm):
        add_cyl(bm, 0.016, 0.016, 0.02, segments=12, center=(0, 0, 0.01))
        add_box(bm, (0.008, 0.03, 0.02), (0, 0, 0.02))
    build_part("Toggle_Range_Switch", col, range_switch, mats["Carbolite_Black"], parent=root, local_pivot=(-0.06, 0.04, 0.095))

    # Выносная штанга с гильзой БДГ-1 (сцинтиллятор)
    def probe_wand(bm):
        # Ручка и трубка штанги 85 см
        add_cyl(bm, 0.012, 0.012, 0.85, segments=12, center=(0, 0, 0.42))
        # Сцинтилляционная гильза БДГ-1 на конце
        add_cyl(bm, 0.026, 0.026, 0.18, segments=16, center=(0, 0, 0.85))
    build_part("Probe_Wand_BDG1", col, probe_wand, mats["Silumin_Grey"], parent=root, local_pivot=(0.18, 0, 0))

    return root

def build_model_6_sv20_geophone(mats, col):
    # SM_SV20_Geophone: 18 x 6.2 x 6.2 см
    def geophone_body(bm):
        # Стальной цилиндрический стакан
        add_cyl(bm, 0.031, 0.031, 0.11, segments=20, center=(0, 0, 0.11))
        # Конусный штырь для забивки в породу
        add_cyl(bm, 0.016, 0.002, 0.07, segments=12, center=(0, 0, 0.035))

    root = build_part("SM_SV20_Geophone", col, geophone_body, mats["Signal_Orange"], bevel=0.0015)

    def clamps_top(bm):
        add_cyl(bm, 0.008, 0.008, 0.02, segments=8, center=(-0.012, 0, 0.17))
        add_cyl(bm, 0.008, 0.008, 0.02, segments=8, center=(0.012, 0, 0.17))
        add_box(bm, (0.04, 0.015, 0.005), (0, 0, 0.165))
    build_part("Cable_Clamps_Top", col, clamps_top, mats["Brass_Soot"], parent=root, local_pivot=(0, 0, 0))

    return root

def build_model_7_core_box(mats, col):
    # SM_CoreBox_1979: 10 x 100 x 40 см
    def box_body(bm):
        # Деревянный ящик на 5 ручьев
        add_box(bm, (0.40, 1.00, 0.09), (0, 0, 0.045))
        # 4 продольные перегородки
        for i in range(4):
            x = -0.12 + float(i) * 0.08
            add_box(bm, (0.015, 0.98, 0.08), (x, 0, 0.05))

    root = build_part("SM_CoreBox_1979", col, box_body, mats["Wood_Core"], bevel=0.002)

    # Сдвижная фанерная крышка с маркировкой
    def lid_mesh(bm):
        add_box(bm, (0.41, 0.99, 0.012), (0, 0.12, 0.095))
    build_part("Lid_Plywood", col, lid_mesh, mats["Plywood"], parent=root, local_pivot=(0, 0, 0))

    # Образец аномального керна Ø59 мм
    def core_anomaly(bm):
        add_cyl(bm, 0.029, 0.029, 0.28, segments=16, center=(0, 0, 0), rot_euler=(math.pi/2, 0, 0))
    build_part("Core_Sample_Anomaly", col, core_anomaly, mats["Core_Gabbro"], parent=root, local_pivot=(0.04, -0.22, 0.05))

    return root

# ==============================================================================
# БЛОК В: ВЕРТОЛЕТНАЯ ПЛОЩАДКА И НОЧЬ 7 (ПОЛЯРНАЯ АВИАЦИЯ)
# ==============================================================================

def build_model_8_ivo1m_cloud_meter(mats, col):
    # SM_IVO1M_CloudMeter: 95 x 68 x 68 см
    def ivo_pedestal(bm):
        # Серо-голубой цилиндрический бак на коническом постаменте
        add_cyl(bm, 0.34, 0.30, 0.65, segments=24, center=(0, 0, 0.325))
        add_cyl(bm, 0.28, 0.28, 0.25, segments=24, center=(0, 0, 0.775))
        # Параболический зеркальный рефлектор
        add_cyl(bm, 0.25, 0.20, 0.08, segments=20, center=(0, 0, 0.86))

    root = build_part("SM_IVO1M_CloudMeter", col, ivo_pedestal, mats["Grey_Enamel"], bevel=0.003)

    # Откидная металлическая крышка купола
    def lid_protective(bm):
        add_cyl(bm, 0.30, 0.30, 0.04, segments=24, center=(0, 0, 0.02))
        add_box(bm, (0.05, 0.12, 0.03), (0, -0.26, 0.02))
    build_part("Cover_Protective_Lid", col, lid_protective, mats["Grey_Enamel"], parent=root, local_pivot=(0, 0.28, 0.92))

    # Импульсная ксеноновая лампа ИСШ-100 в фокусе зеркала
    def flash_lamp(bm):
        add_cyl(bm, 0.025, 0.025, 0.06, segments=12, center=(0, 0, 0.03))
    build_part("Flash_Lamp_Emitter", col, flash_lamp, mats["Glass_Dome"], parent=root, local_pivot=(0, 0, 0.88))

    return root

def build_model_9_m37_visibility_shield(mats, col):
    # SM_M37_VisibilityShield: 220 x 150 x 25 см
    def shield_post(bm):
        # Стальная стойка
        add_cyl(bm, 0.04, 0.04, 2.20, segments=12, center=(0, 0, 1.10))
        # Консоль светильника
        add_cyl(bm, 0.015, 0.015, 0.35, segments=8, center=(0, 0.18, 2.15), rot_euler=(math.pi/2, 0, 0))

    root = build_part("SM_M37_VisibilityShield", col, shield_post, mats["Cadmium_Steel"], bevel=0.002)

    # Черный щит кровельной стали 150 х 120 см
    def shield_board(bm):
        add_box(bm, (1.50, 0.02, 1.20), (0, 0.03, 1.50))
    build_part("Shield_Board", col, shield_board, mats["Black_Paint"], parent=root)

    # Контрастная белая мишень по ГОСТ (для видимости на фоне темного леса)
    def shield_target(bm):
        add_box(bm, (0.45, 0.025, 0.75), (0, 0.035, 1.50))
    build_part("Shield_Target", col, shield_target, mats["White_Paint"], parent=root)

    # Плафон ночного ориентира видимости
    def marker_lantern(bm):
        add_cyl(bm, 0.07, 0.03, 0.06, segments=12, center=(0, 0, 0))
    build_part("Lantern_Marker_Bulb", col, marker_lantern, mats["Cadmium_Steel"], parent=root, local_pivot=(0, 0.34, 2.15))

    return root

def build_model_10_helipad_fire_pot(mats, col):
    # SM_Helipad_FirePot: 65 x 58 x 58 см
    def drum_tripod(bm):
        # Полубочка из-под ГСМ Ø58 см
        add_cyl(bm, 0.29, 0.29, 0.42, segments=24, center=(0, 0, 0.44))
        # Три ножки из уголка
        for i in range(3):
            ang = float(i) * (2.0 * math.pi / 3.0)
            x = math.cos(ang) * 0.24
            y = math.sin(ang) * 0.24
            add_cyl(bm, 0.018, 0.018, 0.35, segments=8, center=(x, y, 0.175), rot_euler=(0.15 * math.sin(ang), 0.15 * math.cos(ang), 0))

    root = build_part("SM_Helipad_FirePot", col, drum_tripod, mats["Rusty_Drum"], bevel=0.002)

    # Тающая шапка снега
    def snow_cap(bm):
        add_cyl(bm, 0.28, 0.25, 0.08, segments=20, center=(0, 0, 0))
    build_part("Snow_Cap_Mesh", col, snow_cap, mats["Snow_Frost"], parent=root, local_pivot=(0, 0, 0.62))

    # Сокет для привязки огня и дыма
    def socket_marker(bm):
        add_box(bm, (0.05, 0.05, 0.05), (0, 0, 0))
    build_part("Fire_Emitter_Socket", col, socket_marker, mats["Brass_Soot"], parent=root, local_pivot=(0, 0, 0.65))

    return root

def build_model_11_psnd_flare(mats, col):
    # SM_PSND_Flare: 19.5 x 4.2 x 4.2 см
    def flare_tube(bm):
        # Рифленая карболитовая гильза Ø42 мм, L=195 мм
        add_cyl(bm, 0.021, 0.021, 0.195, segments=20, center=(0, 0, 0.097))
        # Дневная гладкая крышка снизу
        add_cyl(bm, 0.022, 0.022, 0.02, segments=20, center=(0, 0, 0.01))

    root = build_part("SM_PSND_Flare", col, flare_tube, mats["Carbolite_Brown"], bevel=0.001)

    # Ночная крышка с рельефными пупырышками
    def cap_knurled(bm):
        add_cyl(bm, 0.0225, 0.0225, 0.025, segments=20, center=(0, 0, 0.012))
        for j in range(8):
            ang = float(j) * (2.0 * math.pi / 8.0)
            add_cyl(bm, 0.002, 0.002, 0.006, segments=6, center=(0.021 * math.cos(ang), 0.021 * math.sin(ang), 0.015))
    build_part("Cap_Night_Knurled", col, cap_knurled, mats["Carbolite_Brown"], parent=root, local_pivot=(0, 0, 0.185))

    # Вытяжное тёрочное кольцо на шнуре
    def pull_ring(bm):
        add_cyl(bm, 0.014, 0.014, 0.004, segments=16, center=(0, 0, 0))
    build_part("Pull_Ring_Cord", col, pull_ring, mats["Cadmium_Steel"], parent=root, local_pivot=(0, 0, 0.20))

    return root

# ==============================================================================
# ЭКСПОРТ В GLB (Y-UP)
# ==============================================================================

def export_roots_to_glb(roots):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    for root in roots:
        saved_loc = root.location.copy()
        root.location = Vector((0, 0, 0))

        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for child in root.children_recursive:
            child.select_set(True)
        bpy.context.view_layer.objects.active = root

        filepath = os.path.join(EXPORT_DIR, f"{root.name}.glb")
        bpy.ops.export_scene.gltf(
            filepath=filepath,
            use_selection=True,
            export_format='GLB',
            export_yup=True,
            export_apply=True
        )
        root.location = saved_loc
        print(f"[Кедр-7 / Аргон] Сгенерирован .glb: {filepath}")

def main():
    clean_scene()
    mats = init_mats()
    roots = []

    colA = bpy.data.collections.new("BlockA_DGA24")
    colB = bpy.data.collections.new("BlockB_AditDubov")
    colC = bpy.data.collections.new("BlockC_HelipadAviation")
    for c in (colA, colB, colC):
        bpy.context.scene.collection.children.link(c)

    # Блок А
    roots.append(build_model_1_dga_genset(mats, colA))
    roots.append(build_model_2_dga_switchboard(mats, colA))
    roots.append(build_model_3_pl64_blowtorch(mats, colA))

    # Блок Б
    roots.append(build_model_4_shi11_interferometer(mats, colB))
    roots.append(build_model_5_srp68_radiometer(mats, colB))
    roots.append(build_model_6_sv20_geophone(mats, colB))
    roots.append(build_model_7_core_box(mats, colB))

    # Блок В
    roots.append(build_model_8_ivo1m_cloud_meter(mats, colC))
    roots.append(build_model_9_m37_visibility_shield(mats, colC))
    roots.append(build_model_10_helipad_fire_pot(mats, colC))
    roots.append(build_model_11_psnd_flare(mats, colC))

    export_roots_to_glb(roots)
    print(f"\n[Кедр-7] Успешно сгенерировано и экспортировано {len(roots)} советских 3D-моделей!")

if __name__ == "__main__":
    main()
