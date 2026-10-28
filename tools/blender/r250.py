# Радиоприёмник Р-250 «Кит» для «Кедр-7»: модель + запекание цвета и AO в одну текстуру 512 → r250.glb
# Запуск: python3 r250.py <out_dir>
import bpy, bmesh, math, sys, os
from mathutils import Vector

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
W, H, D = 0.9, 0.42, 0.36          # габарит как у старой модели: ширина, высота, глубина (м)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, col, rough=0.6, metal=0.0, noise=0.0, noise_scale=60.0, wear=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*col, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if noise > 0:
        # «Молотковая» эмаль: мелкие лунки шумом в цвете
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 6
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (col[0] * (1 - noise), col[1] * (1 - noise), col[2] * (1 - noise), 1)
        ramp.color_ramp.elements[1].color = (min(col[0] * (1 + noise), 1), min(col[1] * (1 + noise), 1), min(col[2] * (1 + noise), 1), 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    if wear > 0:
        src = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].is_linked else None
        bev = nt.nodes.new("ShaderNodeBevel"); bev.inputs["Radius"].default_value = 0.004; bev.samples = 16
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dp = nt.nodes.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"
        nt.links.new(bev.outputs["Normal"], dp.inputs[0]); nt.links.new(geo.outputs["Normal"], dp.inputs[1])
        nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 35; nz.inputs["Detail"].default_value = 8
        edge = nt.nodes.new("ShaderNodeMath"); edge.operation = "SUBTRACT"; edge.inputs[0].default_value = 1.0
        nt.links.new(dp.outputs["Value"], edge.inputs[1])
        e2 = nt.nodes.new("ShaderNodeMath"); e2.operation = "MULTIPLY"; e2.inputs[1].default_value = 60.0
        nt.links.new(edge.outputs[0], e2.inputs[0])
        e3 = nt.nodes.new("ShaderNodeMath"); e3.operation = "MULTIPLY"; e3.use_clamp = True
        nt.links.new(e2.outputs[0], e3.inputs[0]); nt.links.new(nz.outputs["Fac"], e3.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
        if src: nt.links.new(src, mix.inputs[6])
        else: mix.inputs[6].default_value = (*col, 1)
        mix.inputs[7].default_value = (0.42, 0.42, 0.4, 1)          # голый металл / грунт под эмалью
        nt.links.new(e3.outputs[0], mix.inputs[0])
        # грязь: темнее книзу и пятнами
        dz = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Position"], dz.inputs[0])
        dn = nt.nodes.new("ShaderNodeTexNoise"); dn.inputs["Scale"].default_value = 6
        dm = nt.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY_ADD"
        nt.links.new(dz.outputs["Z"], dm.inputs[0]); dm.inputs[1].default_value = 2.2
        nt.links.new(dn.outputs["Fac"], dm.inputs[2])
        dirt = nt.nodes.new("ShaderNodeMix"); dirt.data_type = "RGBA"; dirt.blend_type = "MULTIPLY"
        dc = nt.nodes.new("ShaderNodeMapRange"); dc.inputs[1].default_value = 0.2; dc.inputs[2].default_value = 0.9
        dc.inputs[3].default_value = 0.55; dc.inputs[4].default_value = 0.0
        nt.links.new(dm.outputs[0], dc.inputs[0]); nt.links.new(dc.outputs[0], dirt.inputs[0])
        nt.links.new(mix.outputs[2], dirt.inputs[6]); dirt.inputs[7].default_value = (0.35, 0.3, 0.22, 1)
        nt.links.new(dirt.outputs[2], bsdf.inputs["Base Color"])
    return m


M_BODY = mat("body", (0.16, 0.21, 0.18), 0.7, 0, 0.25, 140, 1.0)      # серо-зелёная молотковая эмаль
M_PANEL = mat("panel", (0.12, 0.155, 0.14), 0.65, 0, 0.18, 220, 1.0)
M_CHROME = mat("chrome", (0.62, 0.63, 0.62), 0.3, 1.0)
M_BLACK = mat("black", (0.025, 0.025, 0.025), 0.5)
M_SCALE = mat("scale", (0.78, 0.66, 0.42), 0.6, 0, 0.15, 30)                     # шкала-барабан, пожелтевшая
M_GLASS = mat("glass", (0.05, 0.06, 0.06), 0.15)
M_PLATE = mat("plate", (0.55, 0.52, 0.45), 0.4, 0.6)              # латунные таблички
M_WHITE = mat("white", (0.82, 0.8, 0.72), 0.6)
M_RED = mat("red", (0.55, 0.06, 0.04), 0.5)

objs = []


def box(name, size, loc, m, bevel=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    o.data.materials.append(m)
    objs.append(o)
    return o


def cyl(name, r, depth, loc, m, rot=(math.pi / 2, 0, 0), verts=24, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    if bevel > 0:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    o.data.materials.append(m)
    objs.append(o)
    return o


def text(s, size, loc, m, depth=0.0008, align="CENTER"):
    bpy.ops.object.text_add(location=loc, rotation=(math.pi / 2, 0, 0))
    o = bpy.context.object
    o.data.body = s
    o.data.size = size
    o.data.extrude = depth
    o.data.align_x = align
    o.data.align_y = "CENTER"
    o.data.materials.append(m)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    objs.append(o)
    return o


# Блендер: Z вверх, перед прибора смотрит в -Y (после экспорта в glTF это +Z в Godot).
FY = -D / 2               # плоскость передней панели
box("cabinet", (W, D, H), (0, 0, H / 2), M_BODY, 0.012)
# Утопленная лицевая панель с рамкой
box("panel", (W - 0.05, 0.012, H - 0.05), (0, FY + 0.004, H / 2), M_PANEL, 0.004)
# Окно шкалы-барабана с хромированной рамкой и стеклом
SX, SZ = -0.17, H * 0.66
box("scale_frame", (0.38, 0.012, 0.13), (SX, FY - 0.004, SZ), M_CHROME, 0.004)
box("scale_bg", (0.35, 0.006, 0.105), (SX, FY - 0.008, SZ), M_SCALE, 0)
for i in range(31):                                           # деления шкалы
    x = SX - 0.16 + i * (0.32 / 30)
    h = 0.03 if i % 5 == 0 else 0.016
    box(f"tick{i}", (0.0016, 0.002, h), (x, FY - 0.0115, SZ + 0.03 - h / 2), M_BLACK, 0)
for i, label in enumerate(["1,5", "3", "6", "12", "25"]):
    text(label, 0.013, (SX - 0.16 + i * 0.08, FY - 0.0118, SZ - 0.018), M_BLACK)
box("needle", (0.003, 0.003, 0.085), (SX + 0.05, FY - 0.013, SZ), M_RED, 0)
# Два стрелочных прибора справа (круглые)
for i, mx in enumerate([0.14, 0.31]):
    cyl(f"meter_rim{i}", 0.052, 0.014, (mx, FY - 0.004, SZ), M_CHROME, bevel=0.003)
    cyl(f"meter_face{i}", 0.044, 0.004, (mx, FY - 0.011, SZ), M_WHITE)
    for k in range(9):
        a = math.radians(-50 + k * 12.5)
        box(f"m{i}t{k}", (0.0015, 0.001, 0.008), (mx + math.sin(a) * 0.034, FY - 0.0135, SZ + math.cos(a) * 0.034 - 0.012), M_BLACK, 0)
    nd = box(f"m{i}needle", (0.0015, 0.001, 0.036), (mx - 0.006, FY - 0.0145, SZ + 0.0), M_BLACK, 0)
    nd.rotation_euler = (0, math.radians(-25 + i * 40), 0)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT"); nd.select_set(True); bpy.context.view_layer.objects.active = nd
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
text("Р-250", 0.026, (0.22, FY - 0.004, H * 0.9), M_WHITE, 0.0012)
# Ряд ручек: большая ручка настройки и малые
cyl("tune_knob", 0.045, 0.035, (SX + 0.02, FY - 0.02, H * 0.27), M_BLACK, verts=32, bevel=0.004)
cyl("tune_knob_skirt", 0.055, 0.008, (SX + 0.02, FY - 0.006, H * 0.27), M_CHROME, verts=32)
cyl("tune_handle", 0.008, 0.02, (SX + 0.05, FY - 0.045, H * 0.32), M_BLACK)
for i in range(4):
    x = 0.02 + i * 0.09
    cyl(f"knob{i}", 0.02, 0.028, (x, FY - 0.016, H * 0.27), M_BLACK, verts=16, bevel=0.002)
    box(f"knobmark{i}", (0.002, 0.002, 0.012), (x, FY - 0.0305, H * 0.27 + 0.01), M_WHITE, 0)
    box(f"plate{i}", (0.05, 0.002, 0.012), (x, FY - 0.003, H * 0.27 - 0.04), M_PLATE, 0)
# Тумблер питания и гнёзда телефонов
box("toggle_base", (0.03, 0.006, 0.03), (0.39, FY - 0.004, H * 0.2), M_CHROME, 0.002)
cyl("toggle", 0.004, 0.03, (0.39, FY - 0.02, H * 0.2), M_CHROME, rot=(math.radians(70), 0, 0))
for i in range(2):
    cyl(f"jack{i}", 0.009, 0.01, (-0.38 + i * 0.03, FY - 0.006, H * 0.14), M_CHROME, verts=12)
    cyl(f"jackhole{i}", 0.004, 0.012, (-0.38 + i * 0.03, FY - 0.007, H * 0.14), M_BLACK, verts=8)
# Винты по углам панели
for sx in (-1, 1):
    for sz in (-1, 1):
        cyl(f"screw{sx}{sz}", 0.008, 0.006, (sx * (W / 2 - 0.045), FY - 0.003, H / 2 + sz * (H / 2 - 0.045)), M_CHROME, verts=10)
# Ручки для переноски на лицевой стороне (скобы)
for sx in (-1, 1):
    x = sx * (W / 2 - 0.018)
    pts = [(x, FY - 0.0, H * 0.78), (x, FY - 0.04, H * 0.78), (x, FY - 0.04, H * 0.22), (x, FY - 0.0, H * 0.22)]
    for a, b in zip(pts, pts[1:]):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        ln = math.dist(a, b)
        if abs(a[2] - b[2]) > 0.001:
            cyl(f"h{sx}{mid[2]:.2f}", 0.008, ln, mid, M_CHROME, rot=(0, 0, 0), verts=10)
        else:
            cyl(f"h{sx}{mid[1]:.2f}{mid[2]:.2f}", 0.008, ln, mid, M_CHROME, rot=(math.pi / 2, 0, 0), verts=10)
# Вентиляционные жалюзи на боках
for sx in (-1, 1):
    for i in range(7):
        box(f"vent{sx}{i}", (0.004, 0.18, 0.008), (sx * (W / 2 + 0.001), 0.02, H * 0.3 + i * 0.03), M_BLACK, 0)

# --- Сборка в один меш ----------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "R250"
# Центр по XY, низ на 0 — как ждёт Models.spawn
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
body.location = (0, 0, 0)
bpy.ops.object.transform_apply(location=True)
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
minz = min(v.z for v in bb)
for v in body.data.vertices:
    v.co.z -= minz
bpy.ops.object.shade_auto_smooth(angle=math.radians(35))

# --- UV и запекание ------------------------------------------------------------
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012)
bpy.ops.object.mode_set(mode="OBJECT")

RES = 1024
img_col = bpy.data.images.new("r250_col", RES, RES)
img_ao = bpy.data.images.new("r250_ao", RES, RES)
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
for m in body.data.materials:
    n = m.node_tree.nodes.new("ShaderNodeTexImage")
    n.image = img_col
    m.node_tree.nodes.active = n
bake = scene.render.bake
bake.use_pass_direct = False
bake.use_pass_indirect = False
bake.use_pass_color = True
bake.margin = 3
bpy.ops.object.bake(type="DIFFUSE")
for m in body.data.materials:
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            n.image = img_ao
bpy.ops.object.bake(type="AO")
# Цвет × мягкий AO (0.35..1) → одна текстура
px_c = list(img_col.pixels)
px_a = list(img_ao.pixels)
out = bpy.data.images.new("r250", RES, RES)
res = [0.0] * len(px_c)
for i in range(0, len(px_c), 4):
    ao = 0.35 + 0.65 * px_a[i]
    res[i] = px_c[i] * ao
    res[i + 1] = px_c[i + 1] * ao
    res[i + 2] = px_c[i + 2] * ao
    res[i + 3] = 1.0
out.pixels = res
out.filepath_raw = os.path.join(OUT, "r250.png")
out.file_format = "PNG"
out.save()

# --- Один материал с запечённой текстурой и экспорт ---------------------------------
final = bpy.data.materials.new("r250_baked")
final.use_nodes = True
tn = final.node_tree.nodes.new("ShaderNodeTexImage")
tn.image = out
final.node_tree.links.new(tn.outputs["Color"], final.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
final.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
body.data.materials.clear()
body.data.materials.append(final)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "r250.glb"), export_format="GLB", use_selection=False, export_image_format="AUTO")
out.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "r250.blend"))
print("OK tris:", sum(len(p.vertices) - 2 for p in body.data.polygons))
