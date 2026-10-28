# Общий кит казённых построек УГМС для «Кедр-7» (docs/СТИЛЬ_ПОСТРОЕК.md).
# Всё задаётся в координатах игры (Godot: Y вверх, X восток, Z юг) и переводится в Blender (Z вверх):
#   точка игры (X, Y, Z) → Blender (X, −Z, Y); поворот игры вокруг Y (yaw) → Blender вокруг Z; вокруг X → вокруг X.
# Модели собираются с origin="keep" — сразу на своём месте в мире игры.
import bpy, math
from mathutils import Vector
import kit

# --- Палитра ---------------------------------------------------------------------
GREEN = (0.20, 0.30, 0.22)
WOOD_UNDER = (0.38, 0.35, 0.31)
WHITE = (0.78, 0.78, 0.74)
SLATE = (0.46, 0.47, 0.46)
CONCRETE = (0.42, 0.41, 0.39)
SNOW = (0.86, 0.90, 0.95)
IRON = (0.10, 0.10, 0.11)
OLD_WOOD = (0.24, 0.21, 0.18)


def g2b(p):
    return (p[0], -p[2], p[1])


def gsize(s):
    return (s[0], s[2], s[1])


# --- Материалы ---------------------------------------------------------------------

def painted(name, paint, under=WOOD_UNDER, peel=0.32, scale=4.5, streaks=True, boards=None, step=0.16, grain=0.25, detail=12):
    """Краска по дереву: облупившиеся пятна до серой доски + грязь книзу + вертикальные потёки."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = detail
    nz.inputs["Roughness"].default_value = 0.65
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*under, 1)
    ramp.color_ramp.elements[1].position = peel
    ramp.color_ramp.elements[1].color = (*paint, 1)
    # Неровный тон самой краски
    var = nt.nodes.new("ShaderNodeTexNoise")
    var.inputs["Scale"].default_value = 25
    nt.links.new(tc.outputs["Object"], var.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    tone = nt.nodes.new("ShaderNodeMix"); tone.data_type = "RGBA"; tone.blend_type = "OVERLAY"
    tone.inputs[0].default_value = grain
    nt.links.new(ramp.outputs["Color"], tone.inputs[6]); nt.links.new(var.outputs["Color"], tone.inputs[7])
    out = tone.outputs[2]
    if streaks:
        # Потёки и грязь: темнее книзу, вертикальные полосы от свеса
        sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
        wv = nt.nodes.new("ShaderNodeTexWave"); wv.wave_type = "BANDS"; wv.bands_direction = "X"
        wv.inputs["Scale"].default_value = 3.0; wv.inputs["Distortion"].default_value = 6.0
        nt.links.new(tc.outputs["Object"], wv.inputs["Vector"])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs[1].default_value = -0.3; mr.inputs[2].default_value = 1.2
        mr.inputs[3].default_value = 0.55; mr.inputs[4].default_value = 1.0
        nt.links.new(sep.outputs["Z"], mr.inputs[0])
        dirt = nt.nodes.new("ShaderNodeMix"); dirt.data_type = "RGBA"; dirt.blend_type = "MULTIPLY"
        dirt.inputs[0].default_value = 1.0
        nt.links.new(out, dirt.inputs[6])
        st = nt.nodes.new("ShaderNodeMix"); st.data_type = "RGBA"
        st.inputs[6].default_value = (1, 1, 1, 1); st.inputs[7].default_value = (0.82, 0.8, 0.76, 1)
        nt.links.new(wv.outputs["Fac"], st.inputs[0])
        mm = nt.nodes.new("ShaderNodeMix"); mm.data_type = "RGBA"; mm.blend_type = "MULTIPLY"; mm.inputs[0].default_value = 1.0
        nt.links.new(st.outputs[2], mm.inputs[6])
        gr = nt.nodes.new("ShaderNodeCombineColor")
        nt.links.new(mr.outputs[0], gr.inputs[0]); nt.links.new(mr.outputs[0], gr.inputs[1]); nt.links.new(mr.outputs[0], gr.inputs[2])
        nt.links.new(gr.outputs[0], mm.inputs[7])
        nt.links.new(mm.outputs[2], dirt.inputs[7])
        out = dirt.outputs[2]
    if boards:
        # Доски: пилообразная полоса — светлый верх доски, тёмная тень нахлёста внизу; щели — для вертикальных
        bw = nt.nodes.new("ShaderNodeTexWave"); bw.wave_type = "BANDS"
        bw.bands_direction = {"h": "Z", "v": "X", "x": "X", "y": "Y"}[boards]
        bw.wave_profile = "SAW"
        bw.inputs["Scale"].default_value = 1.0 / step / (2 * math.pi) * (2 * math.pi)
        bw.inputs["Distortion"].default_value = 0.0
        nt.links.new(tc.outputs["Object"], bw.inputs["Vector"])
        br = nt.nodes.new("ShaderNodeMapRange")
        br.inputs[3].default_value = 0.55; br.inputs[4].default_value = 1.05
        nt.links.new(bw.outputs["Fac"], br.inputs[0])
        bm = nt.nodes.new("ShaderNodeMix"); bm.data_type = "RGBA"; bm.blend_type = "MULTIPLY"; bm.inputs[0].default_value = 1.0
        nt.links.new(out, bm.inputs[6])
        bc = nt.nodes.new("ShaderNodeCombineColor")
        for i in range(3):
            nt.links.new(br.outputs[0], bc.inputs[i])
        nt.links.new(bc.outputs[0], bm.inputs[7])
        out = bm.outputs[2]
    nt.links.new(out, bsdf.inputs["Base Color"])
    return m


def slate_mat(name):
    """Волнистый шифер: светлые и тёмные полосы волн вдоль ската, лишайник и потёки."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wv = nt.nodes.new("ShaderNodeTexWave"); wv.wave_type = "BANDS"; wv.bands_direction = "X"
    wv.inputs["Scale"].default_value = 0.6
    wv.inputs["Distortion"].default_value = 0.0
    wv.wave_profile = "SIN"
    nt.links.new(tc.outputs["Object"], wv.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*[c * 0.62 for c in SLATE], 1)
    ramp.color_ramp.elements[1].color = (*[min(c * 1.18, 1) for c in SLATE], 1)
    nt.links.new(wv.outputs["Fac"], ramp.inputs["Fac"])
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; nz.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = "MULTIPLY"; mx.inputs[0].default_value = 0.45
    nt.links.new(ramp.outputs["Color"], mx.inputs[6]); nt.links.new(nz.outputs["Color"], mx.inputs[7])
    nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])
    return m


def mats():
    """Стандартный набор материалов казённой постройки."""
    return {
        "green": painted("u_green", GREEN),
        "siding": painted("u_siding", GREEN, boards="h", step=0.16),
        "vboard": painted("u_vboard", GREEN, boards="v", step=0.18),
        "vboard_y": painted("u_vboard_y", GREEN, boards="y", step=0.18),
        "white": painted("u_white", WHITE, peel=0.22, scale=6.0),
        "door": painted("u_door", (0.17, 0.26, 0.19), peel=0.28, scale=7.0),
        "wood": kit.mat("u_wood", WOOD_UNDER, rough=0.9, noise=0.25, noise_scale=30, wear=0.5, dirt=0.6),
        "old": kit.mat("u_old", OLD_WOOD, rough=0.95, noise=0.3, noise_scale=20, wear=0.6, dirt=0.7),
        "slate": slate_mat("u_slate"),
        "concrete": kit.mat("u_conc", CONCRETE, rough=0.95, noise=0.25, noise_scale=8, wear=0.4, dirt=0.8),
        "snow": kit.mat("u_snow", SNOW, rough=0.7, noise=0.04, noise_scale=6),
        "iron": kit.mat("u_iron", IRON, rough=0.6, wear=0.5, wear_col=(0.4, 0.26, 0.16)),
        "glass": kit.mat("u_glass", (0.05, 0.06, 0.07), rough=0.2),
        "enamel": kit.mat("u_enamel", (0.80, 0.80, 0.76), rough=0.4, wear=0.6, wear_col=(0.12, 0.12, 0.13)),
        "ink": kit.mat("u_ink", (0.05, 0.08, 0.20), rough=0.5),
        "red": kit.mat("u_red", (0.45, 0.07, 0.05), rough=0.6, wear=0.5),
        "brick": kit.mat("u_brick", (0.42, 0.16, 0.10), rough=0.9, noise=0.3, noise_scale=14, wear=0.4, dirt=0.7),
    }


# --- Примитивы в координатах игры ---------------------------------------------------

_n = [0]


def _nm(p):
    _n[0] += 1
    return "%s%d" % (p, _n[0])


def box(center, size, m, yaw=0.0, tilt_x=0.0, tilt_z=0.0, bevel=0.0):
    """Коробка: центр и размер в осях игры, yaw — поворот вокруг вертикали (рад), tilt_x/tilt_z — наклон."""
    o = kit.box(_nm("b"), gsize(size), g2b(center), m, bevel=bevel)
    # Godot: R = Ry·Rx·Rz → Blender: Rz·Rx·R(−y) — режим YXZ
    o.rotation_mode = "YXZ"
    o.rotation_euler = (tilt_x, -tilt_z, yaw)
    return o


def cyl(center, r, h, m, verts=10, axis="y", r2=None):
    rot = {"y": (0, 0, 0), "x": (0, math.pi / 2, 0), "z": (math.pi / 2, 0, 0)}[axis]
    return kit.cyl(_nm("c"), r, h, g2b(center), m, rot=rot, verts=verts, r2=r2)


def cone(base, tip, r, m, verts=6):
    a, b = Vector(g2b(base)), Vector(g2b(tip))
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=0.0, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object; o.name = _nm("k")
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(m); kit.objs.append(o)
    return o


def text(s, size, center, m, yaw=0.0):
    """Надпись на вертикальной плоскости, лицом по +Z игры, повёрнутая yaw."""
    o = kit.text(s, size, g2b(center), m, rot=(math.pi / 2, 0, yaw))
    return o


# --- Стены ---------------------------------------------------------------------------

def _uv(axis, u, c, y, out):
    """Точка стены: axis 0 — стена вдоль X на z=c, axis 2 — вдоль Z на x=c; out — выступ наружу по нормали."""
    return (u, y, c + out) if axis == 0 else (c + out, y, u)


def prism(axis, c, nrm, pts, f0, f1, m):
    """Плоская плита в плоскости стены: многоугольник pts=[(u, y)], от выноса f0 до f1 (наружу)."""
    verts = []
    for f in (f1, f0):
        for (u, y) in pts:
            verts.append(g2b(_uv(axis, u, c, y, nrm * f)))
    n = len(pts)
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    me = bpy.data.meshes.new(_nm("pm"))
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(me.name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    kit.objs.append(o)
    # нормали наружу
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    return o


def siding(axis, u0, u1, c, nrm, y0, y1, holes, M, face=0.36, top_fn=None, **_):
    """Обшивка тёсом: крупные плиты (доски нарисованы в материале), с проёмами holes=[[u0,u1,v0,v1]].
    top_fn(u) — верх стены по уклону (односкатная кровля)."""
    lo, hi = min(u0, u1), max(u0, u1)
    ymax = max(top_fn(lo), top_fn(hi)) if top_fn else y1
    for r in _rects(lo, hi, y0, ymax, holes):
        a, b, v0, v1 = r
        if top_fn and v1 >= ymax - 0.001:
            pts = [(a, v0), (b, v0), (b, top_fn(b)), (a, top_fn(a))]
        else:
            pts = [(a, v0), (b, v0), (b, v1), (a, v1)]
        prism(axis, c, nrm, pts, face - 0.05, face, M["siding"])


def _rects(lo, hi, y0, y1, holes, gap=0.0):
    """Прямоугольник [lo..hi]×[y0..y1] минус проёмы → список прямоугольников."""
    hs = sorted([h for h in holes if h[3] > y0 and h[2] < y1 and h[1] > lo and h[0] < hi], key=lambda h: h[0])
    out = []
    u = lo
    for h in hs:
        h0, h1 = max(h[0], lo), min(h[1], hi)
        if h0 > u + 0.005:
            out.append([u, h0, y0, y1])
        if h[2] > y0 + 0.005:
            out.append([h0, h1, y0, min(h[2], y1)])
        if h[3] < y1 - 0.005:
            out.append([h0, h1, max(h[3], y0), y1])
        u = max(u, h1)
    if hi > u + 0.005:
        out.append([u, hi, y0, y1])
    return out


def gable_boards(axis, u_c, half, c, nrm, y0, ridge, M, holes=(), face=0.36, **_):
    """Фронтон: треугольная плита с вертикальной доской (в материале), нащельники — рейками."""
    prism(axis, c, nrm, [(u_c - half, y0), (u_c + half, y0), (u_c, ridge)], face - 0.05, face, M["vboard_y" if axis == 2 else "vboard"])
    n = int(2 * half / 0.36)
    for i in range(1, n):
        u = u_c - half + i * (2 * half / n)
        t = ridge - (ridge - y0) * abs(u - u_c) / half
        if t - y0 < 0.1:
            continue
        sz = (0.05, t - y0 - 0.04, 0.02)
        box(_uv(axis, u, c, (y0 + t) / 2 - 0.02, nrm * (face + 0.01)), sz if axis == 0 else (sz[2], sz[1], sz[0]), M["green"])


def corner(x, z, nx, nz, y0, y1, M, face=0.36, w=0.14):
    """Угловые белые доски на наружном углу (nx, nz — направления наружу по X и Z)."""
    h = y1 - y0
    box((x + nx * (face + 0.012), y0 + h / 2, z + nz * (face - w / 2)), (0.025, h, w), M["white"])
    box((x + nx * (face - w / 2), y0 + h / 2, z + nz * (face + 0.012)), (w, h, 0.025), M["white"])


def window_trim(axis, u, c, nrm, yc, w, h, M, face=0.36, kokoshnik=True):
    """Белый наличник: косяки, верх с карнизом-«кокошником», отлив; тёмная рама со стеклом в глубине."""
    f = nrm * (face + 0.02)

    def P(du, y, out):
        return _uv(axis, u + du, c, y, out)

    def S(su, sy, sd):
        return (su, sy, sd) if axis == 0 else (sd, sy, su)
    for s in (-1, 1):
        box(P(s * (w / 2 + 0.05), yc, f), S(0.1, h + 0.12, 0.04), M["white"])
    box(P(0, yc + h / 2 + 0.07, f), S(w + 0.3, 0.12, 0.04), M["white"])
    if kokoshnik:
        box(P(0, yc + h / 2 + 0.17, f + nrm * 0.03), S(w + 0.42, 0.06, 0.1), M["white"])
        box(P(0, yc + h / 2 + 0.24, f + nrm * 0.01), S(w * 0.5, 0.08, 0.05), M["white"])
    box(P(0, yc - h / 2 - 0.05, f + nrm * 0.05), S(w + 0.3, 0.05, 0.14), M["white"])
    # Откосы — короб из досок до стены
    d = face - 0.12
    mid = nrm * (0.12 + d / 2)
    for s in (-1, 1):
        box(P(s * w / 2, yc, mid), S(0.03, h, d), M["wood"])
    box(P(0, yc + h / 2, mid), S(w, 0.03, d), M["wood"])
    box(P(0, yc - h / 2, mid), S(w, 0.03, d), M["wood"])


def roof_slope(x0, x1, z_hi, z_lo, y_hi, y_lo, M, t=0.16, snow=True, eave=True, slate_rows=True):
    """Скат: верх (конёк) на z_hi высоте y_hi, низ (свес) на z_lo высоте y_lo. Шифер, снег, лобовая доска, сосульки."""
    run = z_lo - z_hi
    rise = y_hi - y_lo
    ln = math.hypot(run, rise)
    ang = math.atan2(rise, abs(run))
    tilt = ang if run > 0 else -ang     # +угол опускает дальний (+Z) край
    zc, yc = (z_hi + z_lo) / 2, (y_hi + y_lo) / 2
    nz, ny = math.sin(tilt), math.cos(tilt)    # нормаль ската (z, y)
    w = x1 - x0
    xc = (x0 + x1) / 2
    # Обрешётка/основание
    box((xc, yc - ny * t * 0.6, zc - nz * t * 0.6), (w, t * 0.8, ln), M["wood"], tilt_x=tilt)
    # Шифер рядами внахлёст (по 1.1 м вдоль ската)
    rows = max(1, int(ln / 1.1) + 1)
    for i in range(rows):
        k0, k1 = i / rows, (i + 1) / rows
        km = (k0 + k1) / 2
        cz = z_hi + run * km
        cy = y_hi - rise * km
        box((xc, cy + ny * 0.01 * (i % 2), cz + nz * 0.01 * (i % 2)), (w, 0.03, ln / rows + 0.08), M["slate"], tilt_x=tilt)
    if snow:
        # Пласт снега: не доходит до свеса — кромка шифера и сосульки видны
        s0, s1 = 0.0, 0.86
        cz = z_hi + run * (s0 + s1) / 2
        cy = y_hi - rise * (s0 + s1) / 2
        box((xc, cy + ny * 0.08, cz + nz * 0.08), (w - 0.1, 0.13, ln * (s1 - s0)), M["snow"], tilt_x=tilt, bevel=0.05)
    if eave:
        # Лобовая доска и сосульки по свесу
        box((xc, y_lo - 0.1, z_lo), (w, 0.22, 0.04), M["white"])
        k = 0
        x = x0 + 0.25
        while x < x1 - 0.2:
            L = 0.12 + 0.28 * abs(math.sin(x * 7.3 + k))
            cone((x, y_lo - 0.18, z_lo), (x, y_lo - 0.18 - L, z_lo), 0.025 + L * 0.06, M["snow"], verts=5)
            x += 0.35 + 0.25 * abs(math.sin(x * 3.1))
            k += 1


def barge(x, z_a, y_a, z_b, y_b, M):
    """Ветровая доска вдоль ската на линии x."""
    ln = math.hypot(z_b - z_a, y_b - y_a)
    tilt = math.atan2(y_a - y_b, z_b - z_a)
    box((x, (y_a + y_b) / 2 - 0.08, (z_a + z_b) / 2), (0.04, 0.24, ln + 0.04), M["white"], tilt_x=tilt)


def plinth(pts, y0, y1, M, face=0.42):
    """Бетонный цоколь по замкнутому контуру pts [(x, z), ...] по линии стены; наружная сторона — по обходу."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    for a, b in zip(pts, pts[1:] + pts[:1]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dz)
        dx, dz = dx / L, dz / L
        ox, oz = (dz, -dx) if area > 0 else (-dz, dx)
        mx = (a[0] + b[0]) / 2 + ox * (face - 0.1)
        mz = (a[1] + b[1]) / 2 + oz * (face - 0.1)
        yaw = math.atan2(dx, dz)
        box((mx, (y0 + y1) / 2, mz), (0.22, y1 - y0, L + 2 * face - 0.2), M["concrete"], yaw=yaw)
        box((mx + ox * 0.08, y1 + 0.02, mz + oz * 0.08), (0.2, 0.03, L + 2 * face - 0.2), M["iron"], yaw=yaw)


def sign(center, yaw, lines, M, w=1.3, h=0.42, size=0.09):
    """Эмалированная табличка: белая жесть, синие буквы, тёмная кромка."""
    b = box(center, (w + 0.04, h + 0.04, 0.01), M["ink"], yaw=yaw)
    box((center[0] + math.sin(yaw) * 0.006, center[1], center[2] + math.cos(yaw) * 0.006), (w, h, 0.01), M["enamel"], yaw=yaw)
    n = len(lines)
    for i, s in enumerate(lines):
        y = center[1] + (n - 1) * size * 0.65 - i * size * 1.3
        text(s, size, (center[0] + math.sin(yaw) * 0.013, y, center[2] + math.cos(yaw) * 0.013), M["ink"], yaw=yaw)
    return b
