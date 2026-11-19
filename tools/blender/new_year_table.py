# Новогодний натюрморт дежурного для «Кедр-7» (декабрь 1983, PS1 low-poly, gl_compatibility).
# Генерирует 3 модели в assets/models/kedr/:
#   1. table_fir_jar — ветка сибирской ели в 3-литровой стеклянной банке с дождиком,
#                      рубиновой стеклянной шишкой и красной/золотой звёздочкой.
#   2. ny_still_life — бутылка «Советское Шампанское» (плавный профиль, золотая фольга, этикетка),
#                      сморщенный мандарин с ромбовидной наклейкой «Maroc»,
#                      классический советский 14-гранный стакан с чаем и ложечкой.
#   3. samovar       — тульский латунный самовар «банка/рюмка» (ступенчатый поддон, краник «ветка»,
#                      ручки с деревянными валиками, венец конфорки, паровичок).
#
# Оси: origin="keep" (низ на Z=0, перед в -Y Блендера = +Z Godot).
# Без внешних зависимостей (только bpy, bmesh, numpy).
# Запуск:
#   blender --background --factory-startup --python tools/blender/new_year_table.py -- assets/models/kedr [имя ...]

import bpy
import bmesh
import math
import os
import random
import sys
import numpy as np
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import box, cyl, sphere, torus, tube, mat

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/kedr"
ONLY = ARGS[1:]
os.makedirs(OUT, exist_ok=True)


def want(name):
    return not ONLY or name in ONLY


# ---------------------------------------------------------------------------
# Вспомогательные функции (Blender 4.x / 5.x, RU/EN локали)
# ---------------------------------------------------------------------------

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


def make_glass_mat(name, color=(0.76, 0.90, 0.87), alpha=0.34, rough=0.14):
    """Полупрозрачный стеклянный материал для glTF -> Godot Models._restyle()."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    if hasattr(m, "blend_method"):
        m.blend_method = "BLEND"
    b = _bsdf_of(m)
    _inp(b, ("Base Color", "Базовый цвет"), 0).default_value = (*color, 1.0)
    _inp(b, ("Roughness", "Шероховатость"), 2).default_value = rough
    _inp(b, ("Metallic", "Металличность"), 1).default_value = 0.0
    a_inp = b.inputs.get("Alpha") or b.inputs.get("Альфа")
    if a_inp is not None:
        a_inp.default_value = alpha
    return m


def make_image_mat(name, img, rough=0.65):
    """Материал с процедурной растровой картинкой (этикетки, наклейки)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = _bsdf_of(m)
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    tn.interpolation = "Closest"
    nt.links.new(tn.outputs["Color"], _inp(b, ("Base Color", "Базовый цвет"), 0))
    _inp(b, ("Roughness", "Шероховатость"), 2).default_value = rough
    _inp(b, ("Metallic", "Металличность"), 1).default_value = 0.0
    return m


def add_lathe(name, profile_rz, segs, m, loc=(0, 0, 0), cap_bottom=True, cap_top=True,
              add_to_kit=True, smooth=True):
    """Тело вращения по профилю [(r, z), ...]."""
    bm = bmesh.new()
    rings = []
    for r, z in profile_rz:
        ring = []
        for i in range(segs):
            a = 2.0 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)

    for k in range(len(rings) - 1):
        r0, r1 = rings[k], rings[k + 1]
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((r0[i], r0[ni], r1[ni], r1[i]))

    if cap_bottom and len(rings[0]) >= 3:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and len(rings[-1]) >= 3:
        bm.faces.new(rings[-1])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.use_smooth = smooth
    if add_to_kit:
        kit.objs.append(obj)
    return obj


def add_curved_label(name, radius, z0, z1, ang_center, ang_span, segs, m, loc=(0, 0, 0)):
    """Изогнутая цилиндрическая этикетка с чистой UV-развёрткой [0..1]x[0..1]."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    v_bot = []
    v_top = []
    for i in range(segs + 1):
        u = i / segs
        a = ang_center - ang_span * 0.5 + u * ang_span
        x, y = radius * math.cos(a), radius * math.sin(a)
        v_bot.append(bm.verts.new((x, y, z0)))
        v_top.append(bm.verts.new((x, y, z1)))
    for i in range(segs):
        u0, u1 = i / segs, (i + 1) / segs
        f = bm.faces.new((v_bot[i], v_bot[i + 1], v_top[i + 1], v_top[i]))
        uvs = ((u0, 0.0), (u1, 0.0), (u1, 1.0), (u0, 1.0))
        for loop, uv in zip(f.loops, uvs):
            loop[uv_layer].uv = uv
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(m)
    kit.objs.append(obj)
    return obj


# ---------------------------------------------------------------------------
# Процедурная графика этикеток (чистый numpy -> bpy.data.images)
# ---------------------------------------------------------------------------

def _draw_rect(buf, x0, y0, x1, y1, col):
    h, w, _ = buf.shape
    ix0 = max(0, min(w, int(x0)))
    ix1 = max(0, min(w, int(x1)))
    iy0 = max(0, min(h, int(y0)))
    iy1 = max(0, min(h, int(y1)))
    if ix1 > ix0 and iy1 > iy0:
        buf[iy0:iy1, ix0:ix1, :3] = col
        buf[iy0:iy1, ix0:ix1, 3] = 1.0


def _make_champagne_label_image():
    """Чёрно-золотая советская этикетка «Советское Шампанское» (128x96)."""
    w, h = 128, 96
    buf = np.zeros((h, w, 4), dtype=np.float32)
    # Кремово-золотой бумажный кант
    _draw_rect(buf, 0, 0, w, h, (0.88, 0.78, 0.46))
    # Глубокое чёрное поле этикетки (в стиле 1980-х)
    _draw_rect(buf, 5, 5, w - 5, h - 5, (0.07, 0.07, 0.06))
    # Внутренняя тонкая золотая рамка
    _draw_rect(buf, 9, 9, w - 9, 11, (0.86, 0.72, 0.30))
    _draw_rect(buf, 9, h - 11, w - 9, h - 9, (0.86, 0.72, 0.30))
    _draw_rect(buf, 9, 9, 11, h - 9, (0.86, 0.72, 0.30))
    _draw_rect(buf, w - 11, 9, w - 9, h - 9, (0.86, 0.72, 0.30))
    # Красная верхняя лента «СОВЕТСКОЕ»
    _draw_rect(buf, 18, 66, w - 18, 78, (0.64, 0.14, 0.11))
    # Белые/золотые имитации букв заголовка
    for x in range(24, w - 24, 7):
        _draw_rect(buf, x, 69, x + 4, 75, (0.95, 0.88, 0.64))
    # Крупная золотая диагональная строка «ШАМПАНСКОЕ»
    _draw_rect(buf, 16, 42, w - 16, 56, (0.90, 0.76, 0.34))
    for x in range(20, w - 20, 6):
        _draw_rect(buf, x, 45, x + 3, 53, (0.10, 0.09, 0.07))
    # Нижний золотой герб / медаль и строка «ПОЛУСЛАДКОЕ • 0.75 Л»
    yy, xx = np.ogrid[:h, :w]
    medal = ((xx - w * 0.5) ** 2 + (yy - 25) ** 2) <= 9 ** 2
    buf[medal, :3] = (0.88, 0.73, 0.28)
    _draw_rect(buf, 28, 15, w - 28, 18, (0.78, 0.68, 0.40))
    # Лёгкая потёртость бумаги
    rng = np.random.default_rng(1983)
    noise = rng.uniform(-0.04, 0.04, (h, w, 1)).astype(np.float32)
    buf[:, :, :3] = np.clip(buf[:, :, :3] + noise, 0.0, 1.0)
    buf[:, :, 3] = 1.0
    img = bpy.data.images.new("champ_label_tex", w, h, alpha=True)
    img.pixels.foreach_set(buf.ravel())
    img.pack()
    return img


def _make_maroc_sticker_image():
    """Чёрно-золотая ромбовидная наклейка «Maroc» (64x64)."""
    w, h = 64, 64
    buf = np.zeros((h, w, 4), dtype=np.float32)
    _draw_rect(buf, 0, 0, w, h, (0.08, 0.09, 0.07))
    # Золотой ободок по краям квадрата (который повернут ромбом на 45°)
    _draw_rect(buf, 3, 3, w - 3, 7, (0.90, 0.76, 0.26))
    _draw_rect(buf, 3, h - 7, w - 3, h - 3, (0.90, 0.76, 0.26))
    _draw_rect(buf, 3, 3, 7, h - 3, (0.90, 0.76, 0.26))
    _draw_rect(buf, w - 7, 3, w - 3, h - 3, (0.90, 0.76, 0.26))
    # Белая надпись «MAROC» по диагонали (полоса штрихов в центре)
    _draw_rect(buf, 11, 26, w - 11, 38, (0.95, 0.92, 0.80))
    for x in range(14, w - 14, 7):
        _draw_rect(buf, x, 28, x + 4, 36, (0.10, 0.10, 0.09))
    # Крошечная зелёная веточка сверху
    _draw_rect(buf, 26, 44, 38, 49, (0.18, 0.52, 0.22))
    img = bpy.data.images.new("maroc_sticker_tex", w, h, alpha=True)
    img.pixels.foreach_set(buf.ravel())
    img.pack()
    return img


# ---------------------------------------------------------------------------
# 1. ВЕТКА СИБИРСКОЙ ЕЛИ В 3-ЛИТРОВОЙ БАНКЕ (table_fir_jar.glb)
# ---------------------------------------------------------------------------

def _add_spruce_frond(name, origin, direction, length, width, m, tilt_roll=0.0):
    """Скульптурная low-poly еловая лапка (зубчатый перистый силуэт с V-изгибом)."""
    bm = bmesh.new()
    d = Vector(direction).normalized()
    up_ref = Vector((0, 0, 1)) if abs(d.z) < 0.92 else Vector((1, 0, 0))
    side = d.cross(up_ref).normalized()
    up = side.cross(d).normalized()

    # Поворот вокруг оси ветки
    cr, sr = math.cos(tilt_roll), math.sin(tilt_roll)
    side_r = side * cr + up * sr
    up_r = -side * sr + up * cr

    # 5 поясов вдоль лапы: формируем «ёлочку» с выступающими боковыми пучками хвои
    steps = [
        (0.00, 0.14, 0.000),
        (0.22, 0.86, 0.010),
        (0.46, 1.00, 0.014),
        (0.72, 0.72, 0.010),
        (1.00, 0.08, -0.004),
    ]
    spine = []
    left_v = []
    right_v = []
    for t, wk, arch in steps:
        p = Vector(origin) + d * (length * t) + up_r * (arch - 0.018 * (t ** 2))
        hw = width * 0.5 * wk
        vs = bm.verts.new(p + up_r * 0.007)
        vl = bm.verts.new(p - side_r * hw - up_r * (0.006 * wk))
        vr = bm.verts.new(p + side_r * hw - up_r * (0.006 * wk))
        spine.append(vs)
        left_v.append(vl)
        right_v.append(vr)

    for i in range(len(steps) - 1):
        bm.faces.new((spine[i], left_v[i], left_v[i + 1], spine[i + 1]))
        bm.faces.new((spine[i], spine[i + 1], right_v[i + 1], right_v[i]))

    # Придаём крошечную толщину (0.004 м) чтобы не просвечивало с изнанки при cull_back
    res = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    ext_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=ext_verts, vec=-up_r * 0.004)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(m)
    kit.objs.append(obj)
    return obj


def _add_glass_star_ornament(name, center, radius, m_body, m_cap, yaw=0.0):
    """5-конечная объёмная советская ёлочная звёздочка."""
    bm = bmesh.new()
    z_front = bm.verts.new((0.0, -radius * 0.36, 0.0))
    z_back = bm.verts.new((0.0, radius * 0.36, 0.0))
    ring = []
    for i in range(10):
        ang = math.pi * 0.5 + i * math.pi / 5.0
        r = radius if i % 2 == 0 else radius * 0.42
        ring.append(bm.verts.new((r * math.cos(ang), 0.0, r * math.sin(ang))))
    for i in range(10):
        ni = (i + 1) % 10
        bm.faces.new((z_front, ring[i], ring[ni]))
        bm.faces.new((z_back, ring[ni], ring[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = center
    obj.rotation_euler = (0.0, 0.0, yaw)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(m_body)
    kit.objs.append(obj)
    # Металлический колпачок-петелька сверху
    cyl(name + "_cap", radius * 0.22, radius * 0.26,
        (center[0], center[1], center[2] + radius * 0.96), m_cap, rot=(0, 0, 0), verts=8)


def _add_pinecone_ornament(name, center, m_body, m_cap):
    """Советская стеклянная рубиново-золотая шишка на ниточке."""
    prof = [
        (0.002, -0.030),
        (0.011, -0.022),
        (0.017, -0.010),
        (0.019, 0.004),
        (0.016, 0.018),
        (0.009, 0.028),
        (0.005, 0.032),
    ]
    obj = add_lathe(name, prof, 8, m_body, loc=center, smooth=False)
    obj.rotation_euler = (math.radians(8), math.radians(-10), 0)
    # Рифлёный металлический колпачок + петелька
    cyl(name + "_cap", 0.0065, 0.008, (center[0] - 0.005, center[1] - 0.003, center[2] + 0.034),
        m_cap, rot=(0, 0, 0), verts=8)
    tube(name + "_hook", [
        (center[0] - 0.005, center[1] - 0.003, center[2] + 0.038),
        (center[0] - 0.008, center[1] - 0.004, center[2] + 0.058),
    ], 0.0014, m_cap, verts=4)


def build_table_fir_jar():
    kit.reset()
    rnd = random.Random(198312)

    BARK = mat("fir_bark", (0.24, 0.16, 0.10), rough=0.9, noise=0.25, dirt=0.3)
    PINE_DARK = mat("fir_dark", (0.06, 0.16, 0.08), rough=0.88, noise=0.25, noise_scale=60)
    PINE_MID = mat("fir_mid", (0.10, 0.24, 0.12), rough=0.85, noise=0.25, noise_scale=75)
    PINE_TIP = mat("fir_tip", (0.18, 0.34, 0.20), rough=0.82, noise=0.22, noise_scale=90,
                   wear=0.35, wear_col=(0.62, 0.72, 0.74))
    WATER = mat("jar_water", (0.36, 0.50, 0.46), rough=0.2, noise=0.1, noise_scale=30)
    TINSEL = mat("fir_tinsel", (0.82, 0.88, 0.94), rough=0.22, noise=0.15, noise_scale=120)
    RUBY_GLASS = mat("toy_ruby", (0.72, 0.07, 0.12), rough=0.18, wear=0.35, wear_col=(0.95, 0.66, 0.32))
    STAR_GOLD = mat("toy_star", (0.86, 0.22, 0.14), rough=0.2, wear=0.45, wear_col=(0.96, 0.82, 0.30))
    TOY_CAP = mat("toy_cap", (0.76, 0.74, 0.68), rough=0.35, wear=0.4, wear_col=(0.90, 0.88, 0.84))

    # 1. Вода на дне 3-литровой банки (видна сквозь стеклянную оболочку)
    cyl("jar_water", 0.070, 0.105, (0.0, 0.0, 0.058), WATER, rot=(0, 0, 0), verts=16)

    # 2. Три живые еловые ветки сибирской ели (выходят из воды и расходятся в стороны)
    boughs = [
        # (база в банке, точка горлышка, вершина ветки, длина лап)
        ((0.018, 0.010, 0.025), (0.008, 0.005, 0.225), (0.115, -0.055, 0.465), 0.145),
        ((-0.020, 0.012, 0.028), (-0.010, 0.006, 0.225), (-0.125, -0.035, 0.435), 0.135),
        ((0.002, -0.018, 0.026), (0.002, -0.008, 0.225), (-0.015, 0.095, 0.495), 0.130),
    ]
    needle_mats = [PINE_DARK, PINE_MID, PINE_TIP]

    for bi, (p0, p1, p2, base_len) in enumerate(boughs):
        v0, v1, v2 = Vector(p0), Vector(p1), Vector(p2)
        mid = v1.lerp(v2, 0.52) + Vector((rnd.uniform(-0.012, 0.012), rnd.uniform(-0.012, 0.012), 0.01))
        tube(f"stem_{bi}", [v0, v1, mid, v2], 0.0065, BARK, verts=6)

        # Ярусы хвойных лапок вдоль надводной части ветки
        axis = (v2 - v1).normalized()
        up_ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        lat_a = axis.cross(up_ref).normalized()
        lat_b = axis.cross(lat_a).normalized()

        for tier in range(5):
            t = 0.14 + tier * 0.19
            base_pt = v1.lerp(v2, t)
            scale_t = 1.0 - t * 0.52
            n_fronds = 4 if tier < 3 else 3
            for fi in range(n_fronds):
                az = (fi / n_fronds) * math.tau + tier * 0.72 + bi * 1.1
                radial = lat_a * math.cos(az) + lat_b * math.sin(az)
                frond_dir = (radial * 0.82 + axis * 0.56 + Vector((0, 0, -0.18))).normalized()
                flen = base_len * scale_t * rnd.uniform(0.84, 1.12)
                fwid = flen * rnd.uniform(0.46, 0.58)
                nm = needle_mats[min(2, tier // 2)]
                _add_spruce_frond(
                    f"frond_{bi}_{tier}_{fi}",
                    base_pt,
                    frond_dir,
                    flen,
                    fwid,
                    nm,
                    tilt_roll=rnd.uniform(-0.35, 0.35),
                )
        # Макушечная свечка-побег
        _add_spruce_frond(f"crown_{bi}", v2 - axis * 0.02, axis, 0.075, 0.036, PINE_TIP)

    # 3. Серебристый «дождик» — тонкие нити мишуры, свисающие с веток
    tinsel_starts = [
        (0.088, -0.055, 0.355),
        (0.115, -0.020, 0.335),
        (-0.095, -0.045, 0.340),
        (-0.060, 0.068, 0.370),
        (0.035, 0.072, 0.385),
        (-0.015, -0.085, 0.320),
    ]
    for ti, (tx, ty, tz) in enumerate(tinsel_starts):
        drop = rnd.uniform(0.14, 0.21)
        sway_x = rnd.uniform(-0.014, 0.014)
        sway_y = rnd.uniform(-0.014, 0.014)
        pts = [
            (tx, ty, tz),
            (tx + sway_x * 0.5, ty + sway_y * 0.5, tz - drop * 0.35),
            (tx - sway_x * 0.3, ty + sway_y * 0.9, tz - drop * 0.72),
            (tx + sway_x * 0.6, ty - sway_y * 0.4, tz - drop),
        ]
        tube(f"tinsel_{ti}", pts, 0.0022, TINSEL, verts=4)

    # 4. Советские стеклянные ёлочные игрушки
    # Рубиновая шишка справа спереди
    _add_pinecone_ornament("ruby_cone", (0.105, -0.072, 0.285), RUBY_GLASS, TOY_CAP)
    # Красно-золотая звёздочка слева спереди
    _add_glass_star_ornament("red_star", (-0.098, -0.066, 0.300), 0.032, STAR_GOLD, TOY_CAP, yaw=math.radians(18))

    # Запекаем всю непрозрачную часть (ветки, воду, дождик, игрушки) в единый атлас 512x512
    body, img, tris = kit.finish("table_fir_jar", OUT, res=512, origin="keep", samples=28, ao_min=0.40)

    # 5. Добавляем отдельную полупрозрачную 3-литровую банку (сохраняет прозрачность в Godot!)
    JAR_GLASS = make_glass_mat("jar_glass_3l", color=(0.74, 0.90, 0.86), alpha=0.34, rough=0.14)
    jar_profile = [
        (0.064, 0.002),
        (0.078, 0.014),
        (0.081, 0.035),
        (0.081, 0.175),
        (0.075, 0.198),
        (0.056, 0.214),
        (0.049, 0.224),
        (0.053, 0.232),   # валик венчика горлышка под крышку СКО
        (0.048, 0.238),
        (0.044, 0.238),
    ]
    jar_obj = add_lathe("glass_jar_3l", jar_profile, 16, JAR_GLASS, loc=(0, 0, 0),
                        cap_bottom=True, cap_top=False, add_to_kit=False, smooth=True)

    tris_total = tris + sum(len(p.vertices) - 2 for p in jar_obj.data.polygons)
    kit.export(os.path.join(OUT, "table_fir_jar.glb"), os.path.join(OUT, "table_fir_jar.blend"))
    print(f"[OK] table_fir_jar exported: {tris_total} tris (opaque={tris})")


# ---------------------------------------------------------------------------
# 2. ШАМПАНСКОЕ, МАНДАРИН «MAROC» И 14-ГРАННЫЙ СТАКАН (ny_still_life.glb)
# ---------------------------------------------------------------------------

def _build_wrinkled_mandarin(name, loc, m_peel, m_stem, m_sticker):
    """Низкополигональный сморщенный мандарин с вмятинками и ромбовидной наклейкой «Maroc»."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.030)
    for v in bm.verts:
        p = v.co
        # Сплюснутая цитрусовая форма
        p.z *= 0.74
        # Сморщенные дольки и неровности подсохшей кожуры
        ang = math.atan2(p.y, p.x)
        rib = 1.0 + 0.045 * math.sin(ang * 9.0) + 0.035 * math.cos(p.z * 110.0 + ang * 3.0)
        p.x *= rib
        p.y *= rib
        # Небольшая ямка у плодоножки сверху и снизу
        r_xy = math.hypot(p.x, p.y)
        if r_xy < 0.011:
            p.z *= 0.86
    # Ставим нижнюю точку ровно на Z=0
    min_z = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= min_z
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(m_peel)
    for p in obj.data.polygons:
        p.use_smooth = True
    kit.objs.append(obj)

    # Сухая зелёно-бурая звёздочка плодоножки
    top_z = max(v.co.z for v in obj.data.vertices)
    cyl(name + "_calyx", 0.0045, 0.004, (loc[0], loc[1], top_z + 0.001), m_stem, rot=(0, 0, 0), verts=6)

    # Ромбовидная наклейка «Maroc» спереди-сверху (слегка прилегает к кожуре)
    bm_s = bmesh.new()
    uv_l = bm_s.loops.layers.uv.new("UVMap")
    sz = 0.0082
    pts = [(-sz, -sz, 0.0), (sz, -sz, 0.0), (sz, sz, 0.0), (-sz, sz, 0.0)]
    vs = [bm_s.verts.new(pt) for pt in pts]
    f = bm_s.faces.new(vs)
    for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv_l].uv = uv
    mesh_s = bpy.data.meshes.new(name + "_maroc")
    bm_s.to_mesh(mesh_s)
    bm_s.free()
    st_obj = bpy.data.objects.new(name + "_maroc", mesh_s)
    st_obj.location = (loc[0] - 0.004, loc[1] - 0.0225, top_z * 0.72)
    # Наклон под касательную к кожуре + поворот на 45° (ромб)
    st_obj.rotation_euler = Euler((math.radians(52), math.radians(-10), math.radians(45)), "XYZ")
    bpy.context.collection.objects.link(st_obj)
    st_obj.data.materials.append(m_sticker)
    kit.objs.append(st_obj)


def build_ny_still_life():
    kit.reset()

    CHAMP_GLASS = mat("champ_dark", (0.04, 0.13, 0.06), rough=0.22, noise=0.06, noise_scale=30,
                      wear=0.25, wear_col=(0.14, 0.28, 0.16))
    GOLD_FOIL = mat("champ_foil", (0.86, 0.68, 0.22), rough=0.28, noise=0.14, noise_scale=90,
                    wear=0.45, wear_col=(0.98, 0.88, 0.48))
    CORK = mat("champ_cork", (0.52, 0.38, 0.22), rough=0.88, noise=0.25)
    MANDARIN = mat("mandarin_peel", (0.82, 0.34, 0.05), rough=0.82, noise=0.24, noise_scale=110,
                   dirt=0.25, wear=0.35, wear_col=(0.94, 0.52, 0.10))
    STEM_GREEN = mat("mandarin_stem", (0.14, 0.24, 0.09), rough=0.9)
    TEA_AMBER = mat("tea_liquid", (0.44, 0.17, 0.04), rough=0.18, noise=0.08)
    SPOON_STEEL = mat("spoon_steel", (0.72, 0.75, 0.78), rough=0.28, wear=0.4, wear_col=(0.90, 0.92, 0.94))

    LABEL_MAT = make_image_mat("champ_label_mat", _make_champagne_label_image(), rough=0.72)
    MAROC_MAT = make_image_mat("maroc_sticker_mat", _make_maroc_sticker_image(), rough=0.55)

    # 1. Бутылка «Советское Шампанское» в центре (0, 0, 0), высота 0.315 м
    champ_profile = [
        (0.038, 0.000),
        (0.043, 0.006),
        (0.044, 0.025),
        (0.044, 0.145),   # цилиндрический корпус
        (0.042, 0.172),   # начало покатых плеч шампанского
        (0.036, 0.198),
        (0.027, 0.225),
        (0.019, 0.254),   # длинное тонкое горлышко
        (0.0155, 0.286),
        (0.0175, 0.298),  # венчик горлышка
        (0.0150, 0.306),
    ]
    add_lathe("champagne_bottle", champ_profile, 16, CHAMP_GLASS, loc=(0, 0, 0), smooth=True)

    # Золотая фольга на горлышке и мюзле (кольеретка с рифлением)
    foil_profile = [
        (0.0280, 0.223),
        (0.0200, 0.254),
        (0.0165, 0.286),
        (0.0185, 0.299),
        (0.0165, 0.312),
        (0.0120, 0.315),
    ]
    add_lathe("champagne_foil", foil_profile, 16, GOLD_FOIL, loc=(0, 0, 0), cap_bottom=False, smooth=True)
    # Золотой поясок-кольеретка у основания фольги
    torus("foil_band", 0.0278, 0.0022, (0, 0, 0.224), GOLD_FOIL, rot=(0, 0, 0), maj=16, mino=6)
    # Пробка чуть проглядывает (бутылка недопита/распечатана или закрыта)
    cyl("champ_cork_top", 0.011, 0.004, (0, 0, 0.315), CORK, rot=(0, 0, 0), verts=10)

    # Изогнутая основная этикетка спереди (-Y Блендера = +Z Godot)
    add_curved_label(
        "champagne_label",
        radius=0.0448,
        z0=0.068,
        z1=0.138,
        ang_center=-math.pi * 0.5,
        ang_span=math.radians(122.0),
        segs=10,
        m=LABEL_MAT,
        loc=(0, 0, 0),
    )

    # 2. Сморщенный советский мандарин с наклейкой «Maroc» справа спереди (+0.115, -0.035)
    _build_wrinkled_mandarin("mandarin", (0.115, -0.035, 0.0), MANDARIN, STEM_GREEN, MAROC_MAT)

    # 3. Классический 14-гранный стакан с крепким чаем и ложечкой слева спереди (-0.095, -0.055)
    GX, GY = -0.095, -0.055
    # Крепкий янтарный чай внутри стакана (виден сквозь полупрозрачное стекло)
    tea_prof = [
        (0.0255, 0.014),
        (0.0298, 0.066),
        (0.0294, 0.068),
    ]
    add_lathe("tea_inside", tea_prof, 14, TEA_AMBER, loc=(GX, GY, 0.0), smooth=False)
    # Нержавеющая чайная ложечка, опирающаяся на край стакана
    tube("tea_spoon", [
        (GX - 0.012, GY + 0.004, 0.018),
        (GX + 0.010, GY - 0.004, 0.068),
        (GX + 0.028, GY - 0.010, 0.118),
    ], 0.0020, SPOON_STEEL, verts=5)
    sphere("tea_spoon_bowl", 0.0075, (GX - 0.012, GY + 0.004, 0.018), SPOON_STEEL,
           scale=(1.0, 0.55, 1.35), segs=6, rings=4)

    # Запекаем все непрозрачные элементы (бутылка, этикетка, мандарин, чай, ложка) в 512x512
    body, img, tris = kit.finish("ny_still_life", OUT, res=512, origin="keep", samples=28, ao_min=0.38)

    # Добавляем отдельный 14-гранный стеклянный стакан (полупрозрачное стекло, острые грани!)
    GLASS_14 = make_glass_mat("faceted_glass_14", color=(0.82, 0.92, 0.94), alpha=0.38, rough=0.14)
    glass_prof = [
        (0.0265, 0.000),   # массивное дно
        (0.0285, 0.014),   # нижнее кольцо
        (0.0345, 0.086),   # 14 плоских граней с конусностью
        (0.0360, 0.090),   # переход на гладкий ободок
        (0.0365, 0.104),   # верхняя кромка стакана
        (0.0338, 0.104),   # толщина стенки сверху
        (0.0320, 0.088),
        (0.0262, 0.015),   # внутреннее дно
    ]
    # Важно: smooth=False чтобы 14 граней стакана чётко ловили блики!
    glass_obj = add_lathe("soviet_glass_14", glass_prof, 14, GLASS_14, loc=(GX, GY, 0.0),
                          cap_bottom=True, cap_top=False, add_to_kit=False, smooth=False)

    tris_total = tris + sum(len(p.vertices) - 2 for p in glass_obj.data.polygons)
    kit.export(os.path.join(OUT, "ny_still_life.glb"), os.path.join(OUT, "ny_still_life.blend"))
    print(f"[OK] ny_still_life exported: {tris_total} tris (opaque={tris})")


# ---------------------------------------------------------------------------
# 3. СОВЕТСКИЙ ТУЛЬСКИЙ САМОВАР (samovar.glb)
# ---------------------------------------------------------------------------

def build_samovar():
    kit.reset()

    BRASS = mat("sam_brass", (0.76, 0.58, 0.22), rough=0.32, noise=0.10, noise_scale=50,
                wear=0.45, dirt=0.25, wear_col=(0.94, 0.80, 0.42))
    BRASS_DARK = mat("sam_brass_dk", (0.50, 0.37, 0.14), rough=0.45, noise=0.14,
                     wear=0.5, dirt=0.45, wear_col=(0.76, 0.60, 0.28))
    WOOD_DARK = mat("sam_wood", (0.16, 0.09, 0.05), rough=0.65, noise=0.20,
                    wear=0.35, wear_col=(0.34, 0.22, 0.12))
    SOOT = mat("sam_soot", (0.04, 0.035, 0.03), rough=0.95)

    # 1. Ступенчатый квадратный поддон с 4 точёными ножками
    box("plinth_plate", (0.175, 0.175, 0.014), (0, 0, 0.022), BRASS_DARK, bevel=0.004)
    box("plinth_step", (0.148, 0.148, 0.012), (0, 0, 0.034), BRASS, bevel=0.003)
    for sx in (-0.072, 0.072):
        for sy in (-0.072, 0.072):
            cyl(f"foot_{sx}_{sy}", 0.014, 0.016, (sx, sy, 0.008), BRASS_DARK, rot=(0, 0, 0), verts=8, r2=0.018)

    # 2. Шейка + тулово («рюмка/банка») + крышка — единый плавный профиль вращения (20 граней)
    body_profile = [
        (0.068, 0.040),   # основание шейки
        (0.046, 0.058),   # сужение шейки с поддувалом
        (0.048, 0.088),
        (0.066, 0.104),   # нижний поясок тулова
        (0.096, 0.120),   # расширение корпуса
        (0.114, 0.158),
        (0.118, 0.215),   # широкое пузо самовара
        (0.116, 0.275),
        (0.108, 0.305),   # плечо корпуса
        (0.114, 0.314),   # декоративный валик под крышкой
        (0.104, 0.320),   # крышка ступенька
        (0.092, 0.344),   # купол крышки
        (0.064, 0.362),
        (0.056, 0.372),   # горловина трубы
    ]
    add_lathe("samovar_body", body_profile, 20, BRASS, loc=(0, 0, 0), smooth=True)

    # Тёмные прорези поддувала на шейке
    for i in range(6):
        a = i * math.tau / 6.0
        box(f"vent_{i}", (0.014, 0.008, 0.020), (0.048 * math.cos(a), 0.048 * math.sin(a), 0.074),
            SOOT, bevel=0.001, rot=(0, 0, a + math.pi * 0.5))

    # Декоративные точёные кольца-валики на тулове
    torus("waist_ring_low", 0.114, 0.0045, (0, 0, 0.155), BRASS_DARK, rot=(0, 0, 0), maj=20, mino=6)
    torus("waist_ring_hi", 0.115, 0.0045, (0, 0, 0.285), BRASS_DARK, rot=(0, 0, 0), maj=20, mino=6)

    # 3. Венец конфорки (корона под заварочный чайник)
    cyl("crown_base", 0.056, 0.022, (0, 0, 0.382), BRASS_DARK, rot=(0, 0, 0), verts=16, r2=0.066)
    cyl("flue_dark", 0.040, 0.010, (0, 0, 0.390), SOOT, rot=(0, 0, 0), verts=12)
    # 8 зубцов короны конфорки
    for i in range(8):
        a = i * math.tau / 8.0
        r = 0.062
        box(f"crown_tooth_{i}", (0.024, 0.008, 0.032), (r * math.cos(a), r * math.sin(a), 0.408),
            BRASS, bevel=0.002, rot=(0, 0, a + math.pi * 0.5))
    torus("crown_rim", 0.064, 0.005, (0, 0, 0.422), BRASS, rot=(0, 0, 0), maj=20, mino=6)

    # Деревянные шишечки-хватки на крышке и паровичок
    for sx in (-0.072, 0.072):
        cyl(f"lid_stem_{sx}", 0.004, 0.016, (sx, 0, 0.354), BRASS_DARK, rot=(0, 0, 0), verts=6)
        sphere(f"lid_knob_{sx}", 0.011, (sx, 0, 0.365), WOOD_DARK, scale=(1.0, 1.0, 0.78), segs=10, rings=6)
    cyl("steam_valve", 0.006, 0.018, (0.045, -0.055, 0.358), BRASS_DARK, rot=(0, 0, 0), verts=8)

    # 4. Краник «ветка» спереди (-Y Блендера = +Z Godot)
    # Фигурная розетка (репеёк) на корпусе
    cyl("spigot_rosette", 0.026, 0.010, (0, -0.115, 0.168), BRASS_DARK, rot=(math.pi * 0.5, 0, 0), verts=12)
    # Носик крана с изгибом вниз
    tube("spigot_pipe", [
        (0, -0.112, 0.168),
        (0, -0.162, 0.166),
        (0, -0.180, 0.156),
        (0, -0.184, 0.136),
    ], 0.011, BRASS, verts=8)
    # Вертикальная втулка поворотного крана
    cyl("spigot_barrel", 0.013, 0.036, (0, -0.162, 0.172), BRASS_DARK, rot=(0, 0, 0), verts=10)
    # Классический изогнутый ключ-верток «ветка» (S-образный завиток вверх)
    tube("spigot_branch", [
        (0, -0.162, 0.190),
        (0.012, -0.168, 0.208),
        (0.024, -0.175, 0.220),
        (0.016, -0.178, 0.232),
        (0.002, -0.175, 0.228),
    ], 0.0042, BRASS, verts=6)
    sphere("spigot_tip", 0.007, (0.024, -0.175, 0.220), BRASS_DARK, segs=8, rings=5)

    # 5. Две боковые фигурные ручки с точёными деревянными валиками (±X)
    for sx in (-1, 1):
        # Верхняя и нижняя латунные дужки крепления к тулову
        for sy in (-0.034, 0.034):
            tube(f"handle_arm_{sx}_{sy}", [
                (sx * 0.112, sy * 0.85, 0.242),
                (sx * 0.145, sy, 0.262),
                (sx * 0.162, sy, 0.256),
            ], 0.006, BRASS_DARK, verts=6)
            cyl(f"handle_stud_{sx}_{sy}", 0.012, 0.008, (sx * 0.115, sy * 0.85, 0.242),
                BRASS_DARK, rot=(0, math.pi * 0.5, 0), verts=8)
        # Точёный деревянный валик-ручка по оси Y
        cyl(f"handle_roller_{sx}", 0.013, 0.072, (sx * 0.162, 0.0, 0.256),
            WOOD_DARK, rot=(math.pi * 0.5, 0, 0), verts=10, bevel=0.003)
        for sy in (-0.038, 0.038):
            sphere(f"handle_cap_{sx}_{sy}", 0.008, (sx * 0.162, sy, 0.256), BRASS, segs=8, rings=5)

    body, img, tris = kit.finish("samovar", OUT, res=512, origin="bottom", samples=28, ao_min=0.38)
    kit.export(os.path.join(OUT, "samovar.glb"), os.path.join(OUT, "samovar.blend"))
    print(f"[OK] samovar exported: {tris} tris")


if __name__ == "__main__":
    if want("table_fir_jar"):
        build_table_fir_jar()
    if want("ny_still_life"):
        build_ny_still_life()
    if want("samovar"):
        build_samovar()
