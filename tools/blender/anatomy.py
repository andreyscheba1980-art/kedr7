# Анатомия мобов «Кедр-7» (docs/ПЛАН_МОБЫ_И_КОРПУС.md): сплошная кожа по графу точек (Skin-модификатор),
# сглаживание, «скульпт» шумом вдоль нормалей, правки формы по областям (глазницы, рот, скулы),
# и плавные веса на две ближайшие кости — тело гнётся, а не ломается на шарнирах, как у старых мобов.
# Координаты Blender: X вправо, Y вперёд (нос), Z вверх. Используется вместе с kit.py.
import bpy, bmesh, math
from mathutils import Vector, noise
import kit


def skin(name, nodes, edges, m, subdiv=1, root=0):
    """Тело из графа: nodes = [(x, y, z, rx, ry)], edges = [(i, j)]. Возвращает меш с применённым скином."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([n[:3] for n in nodes], edges, [])
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.6
    for i, n in enumerate(nodes):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (n[3], n[4] if len(n) > 4 else n[3])
        sv.use_root = (i == root)
    if subdiv:
        sd = o.modifiers.new("sub", "SUBSURF")
        sd.levels = subdiv
        sd.render_levels = subdiv
    _apply_all(o)
    o.data.materials.append(m)
    kit.objs.append(o)
    return o


def _apply_all(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def sculpt(o, amp=0.01, scale=8.0, seed=0.0, ridge=False):
    """Неровности вдоль нормали: складки ткани (низкая частота) или морщины/жилы кожи (высокая)."""
    me = o.data
    me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
    off = Vector((seed, seed * 1.7, seed * 0.3))
    for v in me.vertices:
        p = v.co * scale + off
        n = noise.noise(p)
        if ridge:
            n = 1.0 - abs(n) * 2.0
        v.co += v.normal * n * amp
    me.update()


def dent(o, center, radius, depth, axis=None):
    """Вмятина/выпуклость: вершины в сфере radius сдвигаются по нормали (depth < 0 — внутрь), плавно к краю."""
    c = Vector(center)
    for v in o.data.vertices:
        d = (v.co - c).length
        if d < radius:
            k = (1.0 - d / radius)
            k = k * k * (3 - 2 * k)
            dirv = v.normal if axis is None else Vector(axis)
            v.co += dirv * depth * k
    o.data.update()


def squash(o, center, radius, scale):
    """Сжать/растянуть область вокруг центра (scale — вектор множителей), плавно к краю."""
    c = Vector(center)
    s = Vector(scale)
    for v in o.data.vertices:
        d = (v.co - c).length
        if d < radius:
            k = 1.0 - d / radius
            k = k * k * (3 - 2 * k)
            rel = v.co - c
            tgt = c + Vector((rel.x * s.x, rel.y * s.y, rel.z * s.z))
            v.co = v.co.lerp(tgt, k)
    o.data.update()


def rag_hem(o, z_cut, amp=0.06, scale=9.0, below=True):
    """Рваный край одежды: грани ниже/выше z_cut с шумовой кромкой удаляются."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        edge = z_cut + noise.noise(c * scale) * amp
        if (below and c.z < edge) or (not below and c.z > edge):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def weights(o, bones, allowed, falloff=4.0, top=2):
    """Плавные веса: каждая вершина — на 1–2 ближайшие кости из allowed (по расстоянию до отрезка кости)."""
    B = {b[0]: (Vector(b[1]), Vector(b[2])) for b in bones}
    groups = {name: o.vertex_groups.new(name=name) for name in allowed}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        ds = sorted(((_seg_dist(p, *B[n]), n) for n in allowed))[:top]
        ws = [1.0 / max(d, 0.01) ** falloff for d, _ in ds]
        s = sum(ws)
        for (d, n), w in zip(ds, ws):
            groups[n].add([v.index], w / s, "REPLACE")


def frosted(name, base, frost=(0.78, 0.84, 0.9), amount=0.35, top_bias=0.6, dark=None, dark_z=None):
    """Материал с инеем: белёсые пятна по шуму, гуще на верхних гранях (иней садится сверху).
    dark/dark_z: обморожение — к низу объекта (z < dark_z) цвет уходит в dark (почерневшие пальцы)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    tc = nt.nodes.new("ShaderNodeTexCoord")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    # Тон основы с пятнами
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 18; nz.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    rb = nt.nodes.new("ShaderNodeValToRGB")
    rb.color_ramp.elements[0].color = (*[c * 0.7 for c in base], 1)
    rb.color_ramp.elements[1].color = (*[min(c * 1.2, 1) for c in base], 1)
    nt.links.new(nz.outputs["Fac"], rb.inputs["Fac"])
    col = rb.outputs["Color"]
    if dark is not None:
        sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Position"], sep.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs[1].default_value = dark_z - 0.12; mr.inputs[2].default_value = dark_z
        mr.inputs[3].default_value = 1.0; mr.inputs[4].default_value = 0.0
        nt.links.new(sep.outputs["Z"], mr.inputs[0])
        dm = nt.nodes.new("ShaderNodeMix"); dm.data_type = "RGBA"
        dm.inputs[7].default_value = (*dark, 1)
        nt.links.new(mr.outputs[0], dm.inputs[0]); nt.links.new(col, dm.inputs[6])
        col = dm.outputs[2]
    # Иней: шум × (нормаль вверх)
    fz = nt.nodes.new("ShaderNodeTexNoise"); fz.inputs["Scale"].default_value = 30; fz.inputs["Detail"].default_value = 10
    nt.links.new(tc.outputs["Object"], fz.inputs["Vector"])
    nsep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Normal"], nsep.inputs[0])
    up = nt.nodes.new("ShaderNodeMapRange"); up.inputs[1].default_value = -0.2; up.inputs[2].default_value = 1.0
    up.inputs[3].default_value = 1.0 - top_bias; up.inputs[4].default_value = 1.0
    nt.links.new(nsep.outputs["Z"], up.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    nt.links.new(fz.outputs["Fac"], mul.inputs[0]); nt.links.new(up.outputs[0], mul.inputs[1])
    th = nt.nodes.new("ShaderNodeMapRange"); th.inputs[1].default_value = 0.55 - amount * 0.5; th.inputs[2].default_value = 0.62 - amount * 0.4
    nt.links.new(mul.outputs[0], th.inputs[0])
    fm = nt.nodes.new("ShaderNodeMix"); fm.data_type = "RGBA"
    fm.inputs[7].default_value = (*frost, 1)
    nt.links.new(th.outputs[0], fm.inputs[0]); nt.links.new(col, fm.inputs[6])
    nt.links.new(fm.outputs[2], bsdf.inputs["Base Color"])
    return m


# --- Анимация: общая с прежним yrka_rig.py, клипы на NLA-дорожках --------------------

def armature(bones, name="Arm"):
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, h, t, parent in bones:
        eb = arm_data.edit_bones.new(bname)
        eb.head = h; eb.tail = t; eb.roll = 0.0
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
        eb.use_deform = bname != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


def clip(arm, name, length_f, keys):
    """keys: {кадр: {кость: (rx, ry, rz) в градусах, "кость@loc": (x, y, z)}}."""
    D = math.radians
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in sorted(keys):
        k = keys[f]
        for pb in arm.pose.bones:
            r = k.get(pb.name, (0, 0, 0))
            pb.rotation_euler = (D(r[0]), D(r[1]), D(r[2]))
            pb.keyframe_insert("rotation_euler", frame=f)
            pb.location = k.get(pb.name + "@loc", (0, 0, 0))
            pb.keyframe_insert("location", frame=f)
    act.use_fake_user = True
    track = arm.animation_data.nla_tracks.new(); track.name = name
    strip = track.strips.new(name, 1, act); strip.name = name
    track.mute = True
    arm.animation_data.action = None
    return act


def mirror(pose):
    out = {}
    for k, v in pose.items():
        nk = k.replace(".L", ".X").replace(".R", ".L").replace(".X", ".R")
        out[nk] = (-v[0], v[1], v[2]) if k.endswith("@loc") else (v[0], -v[1], -v[2])
    return out


def cycle(a, b, half):
    return {1: a, 1 + half // 2: b, 1 + half: mirror(a), 1 + half + half // 2: mirror(b), 1 + 2 * half: a}


def export_rigged(arm, body, out_dir, name):
    import os
    for t in arm.animation_data.nla_tracks:
        t.mute = False
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE"); mod.object = arm
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True); body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB", use_selection=True,
                              export_image_format="AUTO", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1, export_skins=True, export_def_bones=True)
