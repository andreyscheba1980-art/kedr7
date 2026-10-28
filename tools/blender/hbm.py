# Общая сборка людей и нечисти «Кедр-7» на болванке Blender Studio «Human Base Meshes» (CC0, v1.4.1):
# загрузка realistic_body_male, скелет по ориентирам болванки (A-поза), одежда «оболочками» из той же кожи,
# привязка (тепловые веса + перенос на одежду), поза → покой, упрощение под PS1.
# Координаты Blender: нос +Y (после разворота), ноги на z = 0. Используется с kit.py и anatomy.py.
import bpy, bmesh, math
from mathutils import Vector, Matrix, noise
import kit, anatomy as an

# Ориентиры болванки (после разворота лицом в +Y)
HIP_Z, SH_Z, NECK_Z, HEAD_Z, TOP_Z = 0.92, 1.39, 1.43, 1.52, 1.70
EYE = (0.033, 0.098, 1.574)
MOUTH_Z = 1.497


def load_body(bundle, mat):
    with bpy.data.libraries.load(bundle, link=False) as (src, dst):
        dst.objects = ["GEO-body_male_realistic"]
    body = dst.objects[0]
    bpy.context.collection.objects.link(body)
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    body.parent = None
    body.data = body.data.copy()
    cx = sum((body.matrix_world @ v.co).x for v in body.data.vertices) / len(body.data.vertices)
    mw = body.matrix_world.copy()
    rot = Matrix.Rotation(math.pi, 4, "Z")
    for v in body.data.vertices:
        w = mw @ v.co
        v.co = rot @ Vector((w.x - cx, w.y, w.z))
    body.matrix_world = Matrix.Identity(4)
    body.data.update()
    body.name = "body"
    body.data.materials.clear()
    body.data.materials.append(mat)
    kit.objs.append(body)
    return body


def human_bones(neck_extra=0.0, with_shoulders=False, with_jaw=False):
    """Скелет по болванке. neck_extra — насколько длиннее шея (голова выше)."""
    ne = neck_extra
    bones = [
        ("root", (0, 0, 0), (0, 0, 0.2), None),
        ("hips", (0, 0.0, HIP_Z), (0, 0.0, 1.10), "root"),
        ("spine", (0, 0.0, 1.10), (0, 0.0, 1.27), "hips"),
        ("chest", (0, 0.0, 1.27), (0, 0.01, NECK_Z), "spine"),
        ("neck", (0, 0.01, NECK_Z), (0, 0.02, HEAD_Z + ne), "chest"),
        ("head", (0, 0.02, HEAD_Z + ne), (0, 0.03, TOP_Z + ne), "neck"),
    ]
    if with_jaw:
        bones.append(("jaw", (0, 0.03, 1.51 + ne), (0, 0.11, 1.47 + ne), "head"))
    for s, n in ((-1, "L"), (1, "R")):
        if with_shoulders:
            bones.append((f"shoulder.{n}", (0.03 * s, 0.0, 1.38), (0.18 * s, 0.0, SH_Z), "chest"))
        bones += [
            (f"upper_arm.{n}", (0.18 * s, 0.0, SH_Z), (0.30 * s, 0.02, 1.12), f"shoulder.{n}" if with_shoulders else "chest"),
            (f"forearm.{n}", (0.30 * s, 0.02, 1.12), (0.39 * s, 0.07, 0.88), f"upper_arm.{n}"),
            (f"hand.{n}", (0.39 * s, 0.07, 0.88), (0.44 * s, 0.13, 0.76), f"forearm.{n}"),
            (f"thigh.{n}", (0.09 * s, 0.0, HIP_Z), (0.10 * s, 0.0, 0.50), "hips"),
            (f"shin.{n}", (0.10 * s, 0.0, 0.50), (0.10 * s, -0.03, 0.08), f"thigh.{n}"),
            (f"foot.{n}", (0.10 * s, -0.03, 0.08), (0.11 * s, 0.12, 0.0), f"shin.{n}"),
        ]
    return bones


def stretch_neck(body, extra):
    """Шея длиннее: всё выше основания шеи поднимается, сама шея тянется плавно."""
    if extra <= 0:
        return
    sm = lambda a, b, x: (lambda t: t * t * (3 - 2 * t))(max(0.0, min(1.0, (x - a) / (b - a))))
    k_thin = min(extra / 0.1, 1.0)
    for v in body.data.vertices:
        z, ax = v.co.z, abs(v.co.x)
        # плавно по высоте; плечи (широко по X) не тянем, голову — целиком
        w = sm(1.40, 1.50, z) * (1.0 if z > 1.5 else 1.0 - sm(0.07, 0.13, ax))
        w = max(w, sm(1.43, 1.46, z) * sm(0.03, 0.06, v.co.y))     # подбородок едет целиком, иначе вытянется
        if w <= 0:
            continue
        v.co.z += extra * w
        # шея тоньше — сильнее всего в середине перехода
        mid = w * (1.0 - w) * 4.0
        v.co.x *= 1.0 - 0.14 * mid * k_thin
        v.co.y = 0.01 + (v.co.y - 0.01) * (1.0 - 0.1 * mid * k_thin)
    body.data.update()


def stretch_arms(body, bones_by_name, forearm_extra=0.0, hand_scale=1.0, thin=1.0):
    """Предплечья длиннее, кисти больше, руки тоньше (как у Ырки, но слабее)."""
    for v in body.data.vertices:
        p = v.co.copy()
        if not (abs(p.x) > 0.2 and 0.6 < p.z < 1.42):
            continue
        n = "R" if p.x > 0 else "L"
        sh, el = bones_by_name[f"upper_arm.{n}"]
        _, wr = bones_by_name[f"forearm.{n}"]
        fa = (wr - el).normalized()
        if (p - el).dot(fa) > 0:
            p += fa * forearm_extra * min(1.0, (p - el).dot(fa) / (wr - el).length)
            base = wr + fa * forearm_extra
            if (p - base).dot(fa) > 0:
                p = base + (p - base) * hand_scale
        if thin != 1.0:
            a, b = (sh, el) if (p - el).dot(fa) <= 0 else (el, wr + fa * forearm_extra)
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            ax = a + ab * t
            p = ax + (p - ax) * thin
        v.co = p
    body.data.update()


def face_region(p):
    return p.z > 1.44 and p.y > 0.04


def shell(body, name, keep, offset, mat, noise_amp=0.0, noise_scale=8.0, ridge=False, smooth=0):
    """Одежда из кожи: вырезать область, сгладить анатомию (smooth — проходов), раздуть по нормалям."""
    o = body.copy()
    o.data = body.data.copy()
    o.name = name
    bpy.context.collection.objects.link(o)
    bm = bmesh.new(); bm.from_mesh(o.data)
    kill = [v for v in bm.verts if not keep(v.co)]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.normal_update()
    if smooth:
        # Ткань: сглаживание (анатомия уходит, оболочка садится) и отталкивание от тела на offset —
        # ложится на выпуклости и перекрывает впадины, как настоящая одежда
        from mathutils.bvhtree import BVHTree
        tree = BVHTree.FromPolygons([v.co.copy() for v in body.data.vertices], [tuple(p.vertices) for p in body.data.polygons])
        for v in bm.verts:
            v.co += v.normal * offset
        for _ in range(smooth):
            bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
            for v in bm.verts:
                loc, nor, _i, _d = tree.find_nearest(v.co)
                if loc is None:
                    continue
                d = (v.co - loc).dot(nor)
                if d < offset:
                    v.co += nor * (offset - d)
    else:
        for v in bm.verts:
            v.co += v.normal * offset
    bm.to_mesh(o.data); bm.free()
    o.data.materials.clear(); o.data.materials.append(mat)
    if noise_amp:
        an.sculpt(o, amp=noise_amp, scale=noise_scale, seed=hash(name) % 97, ridge=ridge)
    kit.objs.append(o)
    return o


def cut_faces(o, pred):
    bm = bmesh.new(); bm.from_mesh(o.data)
    kill = [f for f in bm.faces if pred(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=kill, context="FACES"); bm.to_mesh(o.data); bm.free()
    o.data.update()


def arm_lower(bones_by_name, c, frac):
    n = "R" if c.x > 0 else "L"
    el = bones_by_name[f"upper_arm.{n}"][1]
    wr = bones_by_name[f"forearm.{n}"][1]
    fa = (wr - el).normalized()
    return abs(c.x) > 0.2 and (c - el).dot(fa) > (wr - el).length * frac


def bind(arm, body, others):
    """Тепловые веса на тело, на одежду — перенос с тела; всё под Armature."""
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for o in others:
        dt = o.modifiers.new("dt", "DATA_TRANSFER")
        dt.object = body
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.datalayout_transfer(modifier="dt")
        bpy.ops.object.modifier_apply(modifier="dt")
        o.parent = arm
        mod = o.modifiers.new("Armature", "ARMATURE"); mod.object = arm


def aim(pb, direction):
    bpy.context.view_layer.update()
    cur = (pb.tail - pb.head).normalized()
    q_world = cur.rotation_difference(Vector(direction).normalized())
    m = pb.matrix.to_quaternion()
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = pb.rotation_quaternion @ (m.inverted() @ q_world @ m)
    bpy.context.view_layer.update()


def pose_to_rest(arm, meshes, aims):
    """aims: {кость: направление}. Поза запекается в меши и становится покоем скелета."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for bn, d in aims:
        aim(arm.pose.bones[bn], d)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)
        o.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
    bpy.ops.object.mode_set(mode="OBJECT")


def decimate(objs_ratios):
    for o, ratio in objs_ratios:
        d = o.modifiers.new("dec", "DECIMATE")
        d.ratio = ratio
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="dec")
