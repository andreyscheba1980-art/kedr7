# Общие кирпичики для моделей «Кедр-7»: материалы с износом, примитивы, сборка, запекание цвет×AO → GLB.
# Блендер: Z вверх. Перед предмета смотрит в -Y (в Godot это +Z), если не сказано иначе.
import bpy, math, os
from mathutils import Vector

objs = []


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs.clear()


def mat(name, col, rough=0.6, metal=0.0, noise=0.0, noise_scale=60.0, wear=0.0, dirt=0.55, wear_col=(0.42, 0.42, 0.4)):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None) or nt.nodes.get("Principled BSDF") or nt.nodes.get("Принципиальный BSDF")
    base_col_inp = bsdf.inputs.get("Base Color") or bsdf.inputs.get("Базовый цвет") or bsdf.inputs[0]
    base_col_inp.default_value = (*col, 1)
    rough_inp = bsdf.inputs.get("Roughness") or bsdf.inputs.get("Шероховатость") or bsdf.inputs[2]
    rough_inp.default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0   # для запекания DIFFUSE металл = чёрный; блеск даёт цвет
    src = None
    if noise > 0:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = noise_scale
        tex.inputs["Detail"].default_value = 6
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * (1 - noise) for c in col], 1)
        ramp.color_ramp.elements[1].color = (*[min(c * (1 + noise), 1) for c in col], 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        src = ramp.outputs["Color"]
        nt.links.new(src, bsdf.inputs["Base Color"])
    if wear > 0:
        # Потёртости по рёбрам: расхождение Bevel-нормали с истинной × шум
        bev = nt.nodes.new("ShaderNodeBevel"); bev.inputs["Radius"].default_value = 0.003; bev.samples = 16
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dp = nt.nodes.new("ShaderNodeVectorMath"); dp.operation = "DOT_PRODUCT"
        nt.links.new(bev.outputs["Normal"], dp.inputs[0]); nt.links.new(geo.outputs["Normal"], dp.inputs[1])
        nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 35; nz.inputs["Detail"].default_value = 8
        e1 = nt.nodes.new("ShaderNodeMath"); e1.operation = "SUBTRACT"; e1.inputs[0].default_value = 1.0
        nt.links.new(dp.outputs["Value"], e1.inputs[1])
        e2 = nt.nodes.new("ShaderNodeMath"); e2.operation = "MULTIPLY"; e2.inputs[1].default_value = 60.0 * wear
        nt.links.new(e1.outputs[0], e2.inputs[0])
        e3 = nt.nodes.new("ShaderNodeMath"); e3.operation = "MULTIPLY"; e3.use_clamp = True
        nt.links.new(e2.outputs[0], e3.inputs[0]); nt.links.new(nz.outputs["Fac"], e3.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
        if src: nt.links.new(src, mix.inputs[6])
        else: mix.inputs[6].default_value = (*col, 1)
        mix.inputs[7].default_value = (*wear_col, 1)
        nt.links.new(e3.outputs[0], mix.inputs[0])
        out = mix.outputs[2]
        if dirt > 0:
            # Грязь: темнее книзу и пятнами
            dz = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Position"], dz.inputs[0])
            dn = nt.nodes.new("ShaderNodeTexNoise"); dn.inputs["Scale"].default_value = 9
            dm = nt.nodes.new("ShaderNodeMath"); dm.operation = "MULTIPLY_ADD"
            nt.links.new(dz.outputs["Z"], dm.inputs[0]); dm.inputs[1].default_value = 2.2
            nt.links.new(dn.outputs["Fac"], dm.inputs[2])
            dc = nt.nodes.new("ShaderNodeMapRange"); dc.inputs[1].default_value = 0.2; dc.inputs[2].default_value = 0.9
            dc.inputs[3].default_value = dirt; dc.inputs[4].default_value = 0.0
            nt.links.new(dm.outputs[0], dc.inputs[0])
            dmix = nt.nodes.new("ShaderNodeMix"); dmix.data_type = "RGBA"; dmix.blend_type = "MULTIPLY"
            nt.links.new(dc.outputs[0], dmix.inputs[0])
            nt.links.new(out, dmix.inputs[6]); dmix.inputs[7].default_value = (0.35, 0.3, 0.22, 1)
            out = dmix.outputs[2]
        nt.links.new(out, bsdf.inputs["Base Color"])
    return m


def _bevel(o, w, seg=2):
    if w > 0:
        b = o.modifiers.new("bev", "BEVEL"); b.width = w; b.segments = seg; b.limit_method = "ANGLE"


def box(name, size, loc, m, bevel=0.003, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot: o.rotation_euler = rot
    _bevel(o, bevel)
    o.data.materials.append(m); objs.append(o)
    return o


def cyl(name, r, depth, loc, m, rot=(math.pi / 2, 0, 0), verts=24, bevel=0.0, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name
    _bevel(o, bevel)
    o.data.materials.append(m); objs.append(o)
    return o


def sphere(name, radius, loc, m, scale=(1, 1, 1), segs=24, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=loc)
    o = bpy.context.object; o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(m); objs.append(o)
    return o


def torus(name, R, r, loc, m, rot=(math.pi / 2, 0, 0), maj=32, mino=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=maj, minor_segments=mino, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name
    o.data.materials.append(m); objs.append(o)
    return o


def text(s, size, loc, m, depth=0.0006, rot=(math.pi / 2, 0, 0), align="CENTER"):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.data.body = s; o.data.size = size
    # Надписи — плоские и грубые по кривым: печатаются на поверхности, а с resolution 12 и торцами
    # каждая буква давала сотни треугольников (у «Весны» текст был 28 тыс. из 33)
    o.data.resolution_u = 2
    o.data.extrude = depth if depth >= 0.001 else 0.0
    o.data.align_x = align; o.data.align_y = "CENTER"
    o.data.materials.append(m)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object; objs.append(o)
    return o


def tube(name, pts, r, m, verts=8):
    """Трубка по ломаной (ручки, скобы): цилиндр на каждый отрезок + шарик на изломе."""
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        a, b = Vector(a), Vector(b)
        d = b - a
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
        o = bpy.context.object; o.name = f"{name}{i}"
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        o.data.materials.append(m); objs.append(o)
        if i > 0:
            sphere(f"{name}j{i}", r, a, m, segs=verts, rings=max(4, verts // 2))


def finish(name, out_dir, res=1024, origin="bottom", samples=48, ao_min=0.35, pack=0.0, ao_blur=0):
    """Сборка в один меш, UV, запекание цвет×AO в одну текстуру, GLB + .blend (текстура упакована).
    origin: "bottom" — центр по XY, низ на 0 (как ждёт Models.spawn); "keep" — мировые координаты как есть."""
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = name
    if origin == "bottom":
        bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
        cx = (min(v.x for v in bb) + max(v.x for v in bb)) / 2
        cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
        mz = min(v.z for v in bb)
        if os.environ.get("KIT_DRY"):
            print("SHIFT", name, cx, cy, mz)
            raise SystemExit
        for v in body.data.vertices:
            v.co -= Vector((cx, cy, mz)) - body.location
        body.location = (0, 0, 0)
    else:
        bpy.ops.object.transform_apply(location=True)
    bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012)
    if pack:
        # Большие модели (здания): равный масштаб островов и плотная упаковка — иначе текстура пустая
        bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(rotate=True, margin=pack)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = samples
    img_col = bpy.data.images.new(name + "_col", res, res)
    img_ao = bpy.data.images.new(name + "_ao", res, res)
    for m in body.data.materials:
        n = m.node_tree.nodes.new("ShaderNodeTexImage"); n.image = img_col; m.node_tree.nodes.active = n
    bk = sc.render.bake
    bk.use_pass_direct = False; bk.use_pass_indirect = False; bk.use_pass_color = True; bk.margin = 3
    bpy.ops.object.bake(type="DIFFUSE")
    for m in body.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE": n.image = img_ao
    bpy.ops.object.bake(type="AO")
    import numpy as np
    pc = np.empty(res * res * 4, dtype=np.float32); img_col.pixels.foreach_get(pc)
    pa = np.empty(res * res * 4, dtype=np.float32); img_ao.pixels.foreach_get(pa)
    pc = pc.reshape(res, res, 4)
    ao = pa.reshape(res, res, 4)[:, :, 0]
    if ao_blur > 0:
        # Шум AO при малом числе сэмплов на больших ровных плоскостях читается как помехи — сглаживаем
        r = ao_blur
        for axis in (0, 1):
            c = np.cumsum(np.pad(ao, [(r + 1, r) if a == axis else (0, 0) for a in (0, 1)], mode="edge"), axis=axis)
            ao = (np.take(c, range(2 * r + 1, c.shape[axis]), axis=axis) - np.take(c, range(0, c.shape[axis] - 2 * r - 1), axis=axis)) / (2 * r + 1)
    k = ao_min + (1 - ao_min) * ao
    outp = np.empty_like(pc)
    outp[:, :, :3] = pc[:, :, :3] * k[:, :, None]
    outp[:, :, 3] = 1.0
    out = bpy.data.images.new(name, res, res)
    out.pixels.foreach_set(outp.ravel())
    out.filepath_raw = os.path.join(out_dir, name + ".png"); out.file_format = "PNG"; out.save()
    final = bpy.data.materials.new(name + "_baked"); final.use_nodes = True
    tn = final.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = out
    f_bsdf = next((n for n in final.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) or final.node_tree.nodes.get("Principled BSDF") or final.node_tree.nodes.get("Принципиальный BSDF")
    f_base_col = f_bsdf.inputs.get("Base Color") or f_bsdf.inputs.get("Базовый цвет") or f_bsdf.inputs[0]
    final.node_tree.links.new(tn.outputs["Color"], f_base_col)
    f_rough = f_bsdf.inputs.get("Roughness") or f_bsdf.inputs.get("Шероховатость") or f_bsdf.inputs[2]
    f_rough.default_value = 0.8
    body.data.materials.clear(); body.data.materials.append(final)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    return body, out, tris


def export(path_glb, path_blend, only=None):
    if only is not None:
        bpy.ops.object.select_all(action="DESELECT")
        for o in only: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path_glb, export_format="GLB", use_selection=only is not None, export_image_format="AUTO",
                              export_apply=True)   # иначе «Smooth by Angle» не применяется и всё уходит гладким: свет треугольниками
    for im in bpy.data.images:
        if im.has_data and not im.packed_file and im.size[0] > 0 and not im.name.endswith(("_col", "_ao")):
            im.pack()
    if path_blend:
        bpy.ops.wm.save_as_mainfile(filepath=path_blend)
