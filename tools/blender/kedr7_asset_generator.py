import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, Euler

# ==============================================================================
# КОНФИГУРАЦИЯ ПРОИЗВОДСТВЕННОГО ПАЙПЛАЙНА «КЕДР-7» (BLENDER 5.x -> GODOT 4)
# ==============================================================================
EXPORT_TO_GLB = True
EXPORT_DIR = r"c:\Users\andre\OneDrive\Desktop\kedr7\assets\models\soviet"

def clean_scene():
    """Полная очистка сцены перед генерацией пакета моделей."""
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

# ==============================================================================
# БИБЛИОТЕКА МАТЕРИАЛОВ PBR (СОВМЕСТИМОСТЬ С BLENDER 4.0 - 5.x)
# ==============================================================================
def set_bsdf_input(bsdf, names, value):
    for n in names:
        if n in bsdf.inputs:
            bsdf.inputs[n].default_value = value
            return

def create_pbr_material(name, hex_color, metallic=0.0, roughness=0.5, alpha=1.0, transmission=0.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if not bsdf:
        bsdf = mat.node_tree.nodes.new(type="ShaderNodeBsdfPrincipled")

    # Перевод HEX -> sRGB -> Linear RGB
    h = hex_color.lstrip('#')
    rgb = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    lin = tuple(pow(c, 2.2) for c in rgb)

    set_bsdf_input(bsdf, ["Base Color"], (lin[0], lin[1], lin[2], 1.0))
    set_bsdf_input(bsdf, ["Metallic"], metallic)
    set_bsdf_input(bsdf, ["Roughness"], roughness)
    set_bsdf_input(bsdf, ["Alpha"], alpha)
    set_bsdf_input(bsdf, ["Transmission Weight", "Transmission"], transmission)
    if alpha < 1.0 or transmission > 0.0:
        if hasattr(mat, "blend_method"):
            mat.blend_method = 'BLEND'
    return mat

def init_materials():
    return {
        "Carbolite_Black": create_pbr_material("M_Carbolite_Black", "#161517", 0.0, 0.26),
        "Carbolite_Grey":  create_pbr_material("M_Carbolite_Grey",  "#424440", 0.0, 0.38),
        "Ebonite_Black":   create_pbr_material("M_Ebonite_Black",   "#111210", 0.0, 0.42),
        "Red_Stop_Plastic":create_pbr_material("M_Red_Stop_Plastic","#A81C14", 0.0, 0.30),
        "CastIron_Stove":  create_pbr_material("M_CastIron_Stove",  "#1F2122", 0.82, 0.78),
        "Steel_Corroded":  create_pbr_material("M_Steel_Corroded",  "#52585C", 0.88, 0.52),
        "Chrome_Switch":   create_pbr_material("M_Chrome_Switch",   "#D4D9DC", 0.98, 0.16),
        "Aluminum_Tag":    create_pbr_material("M_Aluminum_Tag",    "#9BA2A6", 0.90, 0.40),
        "Copper_Contact":  create_pbr_material("M_Copper_Contact",  "#B85D3B", 1.0,  0.34),
        "Brass_Inst":      create_pbr_material("M_Brass_Inst",      "#C49A45", 1.0,  0.32),
        "Brass_Mesh_Davy": create_pbr_material("M_Brass_Mesh_Davy", "#7A6230", 0.85, 0.65),
        "Asbestos_Slab":   create_pbr_material("M_Asbestos_Slab",   "#5E625E", 0.0,  0.88),
        "Lead_Seal":       create_pbr_material("M_Lead_Seal",       "#4A4E52", 0.75, 0.68),
        "Glass_Clear":     create_pbr_material("M_Glass_Clear",     "#DCE8E6", 0.0,  0.08, alpha=0.35, transmission=0.85),
        "Paper_Chart":     create_pbr_material("M_Paper_Chart",     "#E6DEC8", 0.0,  0.82),
        "Melchior_Silver": create_pbr_material("M_Melchior_Silver", "#8A8D8F", 0.95, 0.28),
        "Tea_Liquid":      create_pbr_material("M_Tea_Liquid",      "#4A1805", 0.0,  0.12, alpha=0.88, transmission=0.60),
        "Tea_Brick":       create_pbr_material("M_Tea_Brick_No36",  "#2B1F16", 0.0,  0.85),
        "Foil_Lead":       create_pbr_material("M_Foil_Lead",       "#7C8082", 0.85, 0.45),
    }

# ==============================================================================
# ГЕОМЕТРИЧЕСКОЕ ЯДРО (BMESH ПРИМИТИВЫ И ТОЧНЫЕ ПИВОТЫ)
# ==============================================================================
def add_box(bm, size_xyz, center=(0, 0, 0)):
    """Создает параллелепипед в bmesh с заданными размерами (м) и локальным центром."""
    ret = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size_xyz, verts=ret['verts'])
    bmesh.ops.translate(bm, vec=center, verts=ret['verts'])
    return ret['verts']

def add_cyl(bm, radius_bottom, radius_top, depth, segments=16, center=(0, 0, 0), rot_euler=(0, 0, 0)):
    """Создает цилиндр/конус в bmesh с поддержкой локального вращения и смещения."""
    ret = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False,
        segments=segments, radius1=radius_bottom, radius2=radius_top, depth=depth
    )
    if any(rot_euler):
        rot_mat = Euler(rot_euler, 'XYZ').to_matrix().to_4x4()
        bmesh.ops.rotate(bm, matrix=rot_mat, verts=ret['verts'])
    bmesh.ops.translate(bm, vec=center, verts=ret['verts'])
    return ret['verts']

def build_mesh_part(name, collection, build_fn, material, parent=None, local_pivot=(0, 0, 0), bevel_width=0.0015):
    """
    Создаёт объект меша, устанавливает его локальный пивот относительно родителя,
    применяет сглаживание и фаски Bevel.
    """
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm = bmesh.new()
    build_fn(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    for poly in mesh.polygons:
        poly.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)

    if material:
        obj.data.materials.append(material)

    if parent:
        obj.parent = parent
        obj.location = Vector(local_pivot)
    else:
        obj.location = Vector(local_pivot)

    if bevel_width > 0.0:
        bev = obj.modifiers.new(name="SovietBevel", type='BEVEL')
        bev.width = bevel_width
        bev.segments = 2
        bev.limit_method = 'ANGLE'
        bev.angle_limit = math.radians(32.0)

        wn = obj.modifiers.new(name="WeightedNormal", type='WEIGHTED_NORMAL')
        wn.keep_sharp = True

    return obj

# ==============================================================================
# УЗЕЛ 1: ЭЛЕКТРОТЕХНИКА И КОММУТАЦИЯ
# ==============================================================================
def build_node1_electrics(mats, col):
    roots = []

    # 1.1. Автоматический выключатель АП-50-2МТ (206 x 113 x 106 мм)
    def ap50_body(bm):
        add_box(bm, (0.113, 0.090, 0.176), center=(0, -0.045, 0))
        add_box(bm, (0.095, 0.022, 0.145), center=(0, -0.096, 0))
        add_box(bm, (0.042, 0.008, 0.030), center=(0, -0.004,  0.095))
        add_box(bm, (0.042, 0.008, 0.030), center=(0, -0.004, -0.095))
        add_box(bm, (0.044, 0.012, 0.068), center=(0, -0.104, 0.0))

    ap50_root = build_mesh_part("SM_AP50_Breaker", col, ap50_body, mats["Carbolite_Black"], local_pivot=(-0.6, 0, 0), bevel_width=0.0025)
    build_mesh_part("Plate_Nameplate_AP50", col, lambda bm: add_box(bm, (0.068, 0.002, 0.028), (0, 0, 0)), mats["Aluminum_Tag"], parent=ap50_root, local_pivot=(0, -0.107, 0.052), bevel_width=0.0005)
    build_mesh_part("Btn_Start_Black", col, lambda bm: add_box(bm, (0.026, 0.018, 0.020), (0, -0.009, 0)), mats["Carbolite_Black"], parent=ap50_root, local_pivot=(0, -0.102, 0.016), bevel_width=0.0015)
    build_mesh_part("Btn_Stop_Red", col, lambda bm: add_box(bm, (0.026, 0.024, 0.020), (0, -0.012, 0)), mats["Red_Stop_Plastic"], parent=ap50_root, local_pivot=(0, -0.102, -0.018), bevel_width=0.0015)
    roots.append(ap50_root)

    # 1.2. Пакетный выключатель ПВ2-10 (94 x 82 x 88 мм)
    def pv2_body(bm):
        add_cyl(bm, 0.041, 0.041, 0.048, segments=24, center=(0, -0.024, 0), rot_euler=(math.pi/2, 0, 0))
        add_cyl(bm, 0.032, 0.032, 0.018, segments=20, center=(0, -0.054, 0), rot_euler=(math.pi/2, 0, 0))
        add_cyl(bm, 0.014, 0.014, 0.094, segments=12, center=(0, -0.024, 0))

    pv2_root = build_mesh_part("SM_PV2_RotarySwitch", col, pv2_body, mats["Carbolite_Black"], local_pivot=(-0.35, 0, 0), bevel_width=0.0015)
    def pv2_handle(bm):
        add_cyl(bm, 0.010, 0.008, 0.022, segments=12, center=(0, -0.011, 0), rot_euler=(math.pi/2, 0, 0))
        add_box(bm, (0.068, 0.016, 0.014), center=(0, -0.020, 0))

    build_mesh_part("Handle_Butterfly", col, pv2_handle, mats["Carbolite_Black"], parent=pv2_root, local_pivot=(0, -0.062, 0), bevel_width=0.0012)
    roots.append(pv2_root)

    # 1.3. Тумблер ТВ1-2 с шильдиком ПЗС-35 (62 x 28 x 46 мм)
    def tv1_base(bm):
        add_box(bm, (0.034, 0.002, 0.062), center=(0, -0.001, 0))
        add_box(bm, (0.024, 0.022, 0.036), center=(0,  0.011, 0))
        add_cyl(bm, 0.008, 0.008, 0.014, segments=12, center=(0, -0.007, 0), rot_euler=(math.pi/2, 0, 0))

    tv1_root = build_mesh_part("SM_TV1_ToggleSwitch", col, tv1_base, mats["Aluminum_Tag"], local_pivot=(-0.15, 0, 0), bevel_width=0.0008)
    def tv1_lever(bm):
        add_cyl(bm, 0.0022, 0.0042, 0.026, segments=10, center=(0, -0.013, 0), rot_euler=(math.pi/2, 0, 0))

    lever_obj = build_mesh_part("Lever_Chrome", col, tv1_lever, mats["Chrome_Switch"], parent=tv1_root, local_pivot=(0, -0.012, 0), bevel_width=0.0005)
    lever_obj.rotation_euler.x = math.radians(26.0)
    roots.append(tv1_root)

    # 1.4. Силовой разъединитель РПБ-25 «Директива Забой» (240 x 130 x 115 мм)
    def rpb_base(bm):
        add_box(bm, (0.130, 0.022, 0.240), center=(0, -0.011, 0))
        for x_off in (-0.036, 0.036):
            add_box(bm, (0.012, 0.044, 0.036), center=(x_off, -0.042,  0.068))
            add_box(bm, (0.012, 0.038, 0.032), center=(x_off, -0.038, -0.055))

    rpb_root = build_mesh_part("SM_RPB_KnifeSwitch", col, rpb_base, mats["Asbestos_Slab"], local_pivot=(0.10, 0, 0), bevel_width=0.0018)
    def rpb_knives(bm):
        for x_off in (-0.036, 0.036):
            add_box(bm, (0.005, 0.018, 0.148), center=(x_off, -0.008, 0.065))
        add_box(bm, (0.092, 0.014, 0.016), center=(0, -0.022, 0.135))
        add_cyl(bm, 0.013, 0.016, 0.065, segments=14, center=(0, -0.058, 0.135), rot_euler=(math.pi/2, 0, 0))

    build_mesh_part("Knife_Blades_Assy", col, rpb_knives, mats["Copper_Contact"], parent=rpb_root, local_pivot=(0, -0.042, -0.055), bevel_width=0.001)
    build_mesh_part("Seal_KGB_Wire", col, lambda bm: add_cyl(bm, 0.009, 0.009, 0.005, segments=12, center=(0, 0, 0), rot_euler=(math.pi/2, 0, 0)), mats["Lead_Seal"], parent=rpb_root, local_pivot=(0.048, -0.055, 0.068), bevel_width=0.0005)
    roots.append(rpb_root)
    return roots

# ==============================================================================
# УЗЕЛ 2: ПЕЧНАЯ ЧУГУННАЯ АРМАТУРА И ЗАМОК ЧЗ-1
# ==============================================================================
def build_node2_stove_iron(mats, col):
    roots = []

    # 2.1. Вьюшка-задвижка дымохода ЗВ-1 (40 x 176 x 290 мм)
    def zv1_frame(bm):
        add_box(bm, (0.176, 0.260, 0.012), center=(0, 0.130,  0.014))
        add_box(bm, (0.176, 0.260, 0.012), center=(0, 0.130, -0.014))
        add_box(bm, (0.018, 0.260, 0.040), center=(-0.079, 0.130, 0))
        add_box(bm, (0.018, 0.260, 0.040), center=( 0.079, 0.130, 0))

    zv1_root = build_mesh_part("SM_ZV1_FlueDamper", col, zv1_frame, mats["CastIron_Stove"], local_pivot=(-0.6, 0.45, 0), bevel_width=0.002)
    def zv1_slide(bm):
        add_box(bm, (0.144, 0.250, 0.008), center=(0, 0.125, 0))
        add_cyl(bm, 0.024, 0.024, 0.010, segments=14, center=(0, -0.018, 0))

    build_mesh_part("Slide_Plate", col, zv1_slide, mats["CastIron_Stove"], parent=zv1_root, local_pivot=(0, 0.0, 0), bevel_width=0.0015)
    roots.append(zv1_root)

    # 2.2. Топочная дверца ДТ-3 (250 x 280 x 45 мм)
    def dt3_frame(bm):
        add_box(bm, (0.280, 0.040, 0.024), center=(0, 0.020,  0.113))
        add_box(bm, (0.280, 0.040, 0.024), center=(0, 0.020, -0.113))
        add_box(bm, (0.026, 0.040, 0.250), center=(-0.127, 0.020, 0))
        add_box(bm, (0.026, 0.040, 0.250), center=( 0.127, 0.020, 0))

    dt3_root = build_mesh_part("SM_DT3_FireboxDoor", col, dt3_frame, mats["CastIron_Stove"], local_pivot=(-0.25, 0.45, 0), bevel_width=0.0025)
    def dt3_leaf(bm):
        add_box(bm, (0.244, 0.014, 0.218), center=(0.122, -0.007, 0))
        add_box(bm, (0.180, 0.006, 0.160), center=(0.122, -0.016, 0))

    dt3_leaf_obj = build_mesh_part("Door_Leaf_DT3", col, dt3_leaf, mats["CastIron_Stove"], parent=dt3_root, local_pivot=(-0.122, -0.004, 0), bevel_width=0.002)
    build_mesh_part("Latch_Vertushok", col, lambda bm: add_box(bm, (0.016, 0.026, 0.068), (0, -0.013, -0.020)), mats["CastIron_Stove"], parent=dt3_leaf_obj, local_pivot=(0.228, -0.014, 0), bevel_width=0.0015)
    roots.append(dt3_root)

    # 2.3. Поддувальная дверца ДП-1 (140 x 250 x 40 мм)
    def dp1_frame(bm):
        add_box(bm, (0.250, 0.036, 0.018), center=(0, 0.018,  0.061))
        add_box(bm, (0.250, 0.036, 0.018), center=(0, 0.018, -0.061))
        add_box(bm, (0.022, 0.036, 0.140), center=(-0.114, 0.018, 0))
        add_box(bm, (0.022, 0.036, 0.140), center=( 0.114, 0.018, 0))

    dp1_root = build_mesh_part("SM_DP1_AshDoor", col, dp1_frame, mats["CastIron_Stove"], local_pivot=(0.12, 0.45, 0), bevel_width=0.002)
    dp1_leaf_obj = build_mesh_part("Door_Leaf_DP1", col, lambda bm: add_box(bm, (0.216, 0.012, 0.116), (0.108, -0.006, 0)), mats["CastIron_Stove"], parent=dp1_root, local_pivot=(-0.108, -0.004, 0), bevel_width=0.0018)
    build_mesh_part("Draft_Butterfly", col, lambda bm: add_cyl(bm, 0.028, 0.028, 0.008, segments=12, center=(0, -0.004, 0), rot_euler=(math.pi/2, 0, 0)), mats["CastIron_Stove"], parent=dp1_leaf_obj, local_pivot=(0.108, -0.012, 0), bevel_width=0.001)
    roots.append(dp1_root)

    # 2.4. Чугунный амбарный замок ЧЗ-1 (145 x 96 x 42 мм)
    def chz1_body(bm):
        add_cyl(bm, 0.048, 0.048, 0.038, segments=20, center=(0, 0, -0.015), rot_euler=(math.pi/2, 0, 0))
        add_box(bm, (0.076, 0.038, 0.045), center=(0, 0, 0.020))

    chz1_root = build_mesh_part("SM_CHZ1_Padlock", col, chz1_body, mats["CastIron_Stove"], local_pivot=(0.42, 0.45, 0), bevel_width=0.0025)
    def chz1_shackle(bm):
        add_cyl(bm, 0.007, 0.007, 0.048, segments=12, center=(0, 0, 0.024))
        add_cyl(bm, 0.007, 0.007, 0.048, segments=12, center=(0.056, 0, 0.024))
        add_box(bm, (0.068, 0.014, 0.014), center=(0.028, 0, 0.050))

    build_mesh_part("Shackle_Steel", col, chz1_shackle, mats["Steel_Corroded"], parent=chz1_root, local_pivot=(-0.028, 0, 0.042), bevel_width=0.0015)
    build_mesh_part("Keyhole_Shutter", col, lambda bm: add_box(bm, (0.018, 0.005, 0.034), (0, -0.003, -0.014)), mats["Brass_Inst"], parent=chz1_root, local_pivot=(0, -0.020, 0.008), bevel_width=0.0008)
    roots.append(chz1_root)
    return roots

# ==============================================================================
# УЗЕЛ 3: ПРИБОРЫ НАБЛЮДЕНИЯ, СВЯЗИ И РАЗВЕДКИ
# ==============================================================================
def build_node3_instruments(mats, col):
    roots = []

    # 3.1. Лампа бензиновая контрольная ЛБВК (275 x 92 x 92 мм)
    def lbvk_base(bm):
        add_cyl(bm, 0.046, 0.044, 0.068, segments=24, center=(0, 0, 0.034))
        add_cyl(bm, 0.046, 0.046, 0.012, segments=24, center=(0, 0, 0.145))
        add_cyl(bm, 0.036, 0.032, 0.095, segments=20, center=(0, 0, 0.198))
        add_cyl(bm, 0.042, 0.038, 0.018, segments=20, center=(0, 0, 0.248))
        for angle in (0, math.pi/2, math.pi, 3*math.pi/2):
            add_cyl(bm, 0.003, 0.003, 0.080, segments=8, center=(math.cos(angle)*0.040, math.sin(angle)*0.040, 0.105))

    lbvk_root = build_mesh_part("SM_LBVK_SafetyLamp", col, lbvk_base, mats["Brass_Inst"], local_pivot=(-0.6, 0.95, 0), bevel_width=0.0012)
    build_mesh_part("Glass_Cylinder", col, lambda bm: add_cyl(bm, 0.033, 0.033, 0.072, segments=20, center=(0, 0, 0.105)), mats["Glass_Clear"], parent=lbvk_root, local_pivot=(0, 0, 0), bevel_width=0.0)
    build_mesh_part("Wick_Adjust_Screw", col, lambda bm: add_cyl(bm, 0.006, 0.006, 0.018, segments=10, center=(0, 0, -0.008)), mats["Brass_Inst"], parent=lbvk_root, local_pivot=(0.028, 0, 0.068), bevel_width=0.0005)
    build_mesh_part("Hook_Ring_Top", col, lambda bm: add_cyl(bm, 0.022, 0.022, 0.006, segments=16, center=(0, 0, 0.018), rot_euler=(math.pi/2, 0, 0)), mats["Brass_Inst"], parent=lbvk_root, local_pivot=(0, 0, 0.256), bevel_width=0.0008)
    roots.append(lbvk_root)

    # 3.2. Головной светильник СГГ-3 «Коногонка»
    def sgg3_battery(bm):
        add_box(bm, (0.136, 0.056, 0.165), center=(0, 0, 0.0825))
        add_box(bm, (0.142, 0.060, 0.024), center=(0, 0, 0.165))
        for x_off in (-0.038, 0.0, 0.038):
            add_cyl(bm, 0.010, 0.010, 0.012, segments=12, center=(x_off, 0, 0.182))

    sgg3_root = build_mesh_part("SM_SGG3_MinerLamp", col, sgg3_battery, mats["Ebonite_Black"], local_pivot=(-0.3, 0.95, 0), bevel_width=0.002)
    def sgg3_headlight(bm):
        add_cyl(bm, 0.022, 0.037, 0.064, segments=20, center=(0, -0.020, 0), rot_euler=(math.pi/2, 0, 0))
        add_box(bm, (0.016, 0.028, 0.032), center=(0, 0.010, -0.028))

    head_obj = build_mesh_part("Headlight_Cone", col, sgg3_headlight, mats["Aluminum_Tag"], parent=sgg3_root, local_pivot=(0, -0.040, 0.230), bevel_width=0.0012)
    build_mesh_part("Switch_Rotary", col, lambda bm: add_cyl(bm, 0.007, 0.005, 0.014, segments=10, center=(0, 0, 0.007)), mats["Carbolite_Black"], parent=head_obj, local_pivot=(0.024, 0.0, 0.024), bevel_width=0.0005)
    roots.append(sgg3_root)

    # 3.3. Микрофон-тангента ДЭМШ-1А
    def demsh_shell(bm):
        add_cyl(bm, 0.024, 0.029, 0.098, segments=18, center=(0, 0, 0))
        add_cyl(bm, 0.022, 0.022, 0.012, segments=18, center=(0, -0.018, 0.018), rot_euler=(math.pi/2, 0, 0))

    demsh_root = build_mesh_part("SM_DEMSH_Handset", col, demsh_shell, mats["Carbolite_Grey"], local_pivot=(0.0, 0.95, 0), bevel_width=0.0018)
    build_mesh_part("PTT_Key_Lever", col, lambda bm: add_box(bm, (0.012, 0.018, 0.044), (-0.006, 0, -0.022)), mats["Carbolite_Black"], parent=demsh_root, local_pivot=(-0.026, 0, 0.025), bevel_width=0.001)
    roots.append(demsh_root)

    # 3.4. Недельный барограф М-22АН
    def m22_base(bm):
        add_box(bm, (0.295, 0.145, 0.022), center=(0, 0, 0.011))

    m22_root = build_mesh_part("SM_M22AN_Barograph", col, m22_base, mats["Carbolite_Grey"], local_pivot=(0.35, 0.95, 0), bevel_width=0.002)
    def m22_lid(bm):
        add_box(bm, (0.285, 0.135, 0.012), center=(0, -0.067, 0.155))
        for x_s in (-0.136, 0.136):
            for y_s in (-0.130, -0.005):
                add_box(bm, (0.012, 0.012, 0.155), center=(x_s, y_s, 0.077))

    build_mesh_part("Case_Hinged_Lid", col, m22_lid, mats["Aluminum_Tag"], parent=m22_root, local_pivot=(0, 0.068, 0.022), bevel_width=0.0012)
    build_mesh_part("Drum_Clockwork", col, lambda bm: add_cyl(bm, 0.046, 0.046, 0.098, segments=28, center=(0, 0, 0.049)), mats["Paper_Chart"], parent=m22_root, local_pivot=(-0.068, 0, 0.032), bevel_width=0.0008)
    def m22_aneroids(bm):
        for i in range(5):
            add_cyl(bm, 0.026, 0.026, 0.009, segments=20, center=(0, 0, i * 0.012 + 0.006))

    build_mesh_part("Aneroid_Stack_5x", col, m22_aneroids, mats["Brass_Inst"], parent=m22_root, local_pivot=(0.068, 0, 0.024), bevel_width=0.0006)
    build_mesh_part("Arm_Pointer_Pen", col, lambda bm: add_box(bm, (0.125, 0.003, 0.005), (-0.062, 0, 0)), mats["Aluminum_Tag"], parent=m22_root, local_pivot=(0.058, -0.025, 0.088), bevel_width=0.0003)
    build_mesh_part("Lever_Arretir", col, lambda bm: add_box(bm, (0.008, 0.042, 0.010), (0, -0.021, 0)), mats["Brass_Inst"], parent=m22_root, local_pivot=(0.018, -0.015, 0.035), bevel_width=0.0005)
    roots.append(m22_root)
    return roots

# ==============================================================================
# УЗЕЛ 4: СТАНЦИОННЫЙ БЫТ 1983 ГОДА
# ==============================================================================
def build_node4_station_life(mats, col):
    roots = []

    def podstakannik_mesh(bm):
        add_cyl(bm, 0.0345, 0.0345, 0.068, segments=24, center=(0, 0, 0.034))
        add_box(bm, (0.008, 0.028, 0.062), center=(0, 0.046, 0.038))

    tea_root = build_mesh_part("SM_Polar_TeaSet", col, podstakannik_mesh, mats["Melchior_Silver"], local_pivot=(0, 1.45, 0), bevel_width=0.001)

    def glass_14facet_mesh(bm):
        add_cyl(bm, 0.0275, 0.0355, 0.088, segments=14, center=(0, 0, 0.044))
        add_cyl(bm, 0.0355, 0.0360, 0.017, segments=28, center=(0, 0, 0.0965))

    glass_obj = build_mesh_part("Glass_14Facet", col, glass_14facet_mesh, mats["Glass_Clear"], parent=tea_root, local_pivot=(0, 0, 0.004), bevel_width=0.0006)
    build_mesh_part("Tea_Liquid_Surface", col, lambda bm: add_cyl(bm, 0.026, 0.033, 0.072, segments=14, center=(0, 0, -0.036)), mats["Tea_Liquid"], parent=glass_obj, local_pivot=(0, 0, 0.082), bevel_width=0.0)

    def tea_brick_mesh(bm):
        add_box(bm, (0.095, 0.190, 0.022), center=(0, 0, 0.011))

    build_mesh_part("Tea_Brick_No36", col, tea_brick_mesh, mats["Tea_Brick"], parent=tea_root, local_pivot=(0.115, 0, 0), bevel_width=0.002)
    roots.append(tea_root)
    return roots

# ==============================================================================
# ЭКСПОРТ В .GLB ДЛЯ GODOT 4 (Y-UP, СОХРАНЕНИЕ ИЕРАРХИИ И ПИВОТОВ)
# ==============================================================================
def export_roots_to_glb(root_objects):
    if not EXPORT_TO_GLB:
        return
    os.makedirs(EXPORT_DIR, exist_ok=True)
    for root in root_objects:
        bpy.ops.object.select_all(action='DESELECT')
        saved_loc = root.location.copy()
        root.location = Vector((0, 0, 0))

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
    print(f"[Кедр-7] Экспортировано {len(root_objects)} моделей (.glb) в: {EXPORT_DIR}")

def main():
    clean_scene()
    mats = init_materials()
    all_roots = []

    col1 = bpy.data.collections.new("Node1_Electrics")
    col2 = bpy.data.collections.new("Node2_StoveCastIron")
    col3 = bpy.data.collections.new("Node3_Instruments")
    col4 = bpy.data.collections.new("Node4_StationLife")
    for c in (col1, col2, col3, col4):
        bpy.context.scene.collection.children.link(c)

    all_roots.extend(build_node1_electrics(mats, col1))
    all_roots.extend(build_node2_stove_iron(mats, col2))
    all_roots.extend(build_node3_instruments(mats, col3))
    all_roots.extend(build_node4_station_life(mats, col4))

    export_roots_to_glb(all_roots)

if __name__ == "__main__":
    main()
