# «Кедр-7» — Двойник на болванке Blender Studio «Human Base Meshes» (CC0, v1.4.1, realistic_body_male).
# Тот, кто стучится. Лицо меняется по ночам, и каждый раз он чуть неправильнее:
#   mikhalych — ночи 2–3: Михалыч в тулупе и ушанке, усы. Почти человек: шея чуть длиннее, лицо застывшее.
#   semenov   — ночи 4–5: Семёнов в ватнике, вязаной шапке и очках. Шея длиннее, руки длиннее, глаза распахнуты.
#   orekhov   — ночи 6–7: сам Орехов в твоей каэшке. Шея вытянута, пальцы длинные, застывшая улыбка.
# Скелет и клипы — как у людей из human_rig.py (idle, walk, run, still, peek) плюс knock: встаёт во все сцены силуэта.
# Нос в +Y (в Godot −Z), ноги на z = 0.
# Запуск: blender --background --python double_hbm.py -- <bundle.blend> <out_dir> <variant|all>
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit, hbm, anatomy as an, face_paint
from mathutils import Vector, Matrix, noise

BUNDLE, OUT, WHICH = sys.argv[-3], sys.argv[-2], sys.argv[-1]
os.makedirs(OUT, exist_ok=True)

VARIANTS = {
    "mikhalych": dict(neck=0.025, fore=0.0, hand=1.0, thin=1.0, eye_open=0.0, smile=0.0, skin=(0.6, 0.45, 0.38)),
    "semenov": dict(neck=0.07, fore=0.035, hand=1.1, thin=0.95, eye_open=0.6, smile=0.0, skin=(0.55, 0.48, 0.45)),
    "orekhov": dict(neck=0.13, fore=0.075, hand=1.24, thin=0.9, eye_open=1.0, smile=1.0, skin=(0.5, 0.48, 0.48)),
    # Живой Михалыч (human_driver.glb): то же лицо и тулуп, что у двойника, но шея своя, кожа обветренная, тёплая
    "driver": dict(neck=0.0, fore=0.0, hand=1.0, thin=1.0, eye_open=0.0, smile=0.0, skin=(0.68, 0.46, 0.37)),
}
EYE_C = (0.0329, 0.1222, 1.5737)        # центр глазного яблока болванки (до вытягивания шеи)
EYE_R = 0.0124


def cloth(name, col, noise_amt=0.22, scale=16.0, wear=0.0):
    return kit.mat(name, col, rough=0.85, noise=noise_amt, noise_scale=scale, wear=wear, dirt=0.6,
                   wear_col=tuple(min(c * 1.6, 1) for c in col))


def skirt(name, z_top, z_bot, r_top, r_bot, mat, n=20, rings=5, y_off=0.0):
    """Полы до колен колоколом: кольца эллипсов, открытый низ."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    loops = []
    for i in range(rings):
        t = i / (rings - 1)
        z = z_top + (z_bot - z_top) * t
        rx = r_top[0] + (r_bot[0] - r_top[0]) * t
        ry = r_top[1] + (r_bot[1] - r_top[1]) * t
        loops.append([bm.verts.new((math.cos(a) * rx, y_off + math.sin(a) * ry, z))
                      for a in (j * math.tau / n for j in range(n))])
    for i in range(rings - 1):
        for j in range(n):
            a, b = loops[i][j], loops[i][(j + 1) % n]
            c, d = loops[i + 1][(j + 1) % n], loops[i + 1][j]
            bm.faces.new((a, b, c, d))
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(mat)
    kit.objs.append(o)
    return o


def folds(o, n=7, amp=0.012):
    """Вертикальные складки полов: глубже книзу."""
    zt = max(v.co.z for v in o.data.vertices)
    zb = min(v.co.z for v in o.data.vertices)
    for v in o.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        k = (zt - v.co.z) / max(zt - zb, 1e-4)
        v.co += v.normal * amp * k * math.sin(a * n + noise.noise(v.co * 3.0) * 2.0)
    o.data.update()


def dome(name, c, r, cut, tilt, mat, segs=18, rings=12):
    """Купол шапки: эллипсоид, низ срезан наклонной плоскостью (сзади ниже, чем надо лбом)."""
    o = kit.sphere(name, 1.0, c, mat, scale=r, segs=segs, rings=rings)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    bm = bmesh.new(); bm.from_mesh(o.data)
    plane = lambda p: cut - tilt * (c[1] - p.y) / r[1]
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < plane(v.co)], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.data.update()
    return o


def band(name, c, r, z0, z1, tilt, mat, n=24):
    """Отворот: эллиптическое кольцо по наклонной плоскости шапки."""
    o = skirt(name, z1, z0, r, (r[0] * 1.03, r[1] * 1.03), mat, n=n, rings=5, y_off=c[1])
    for v in o.data.vertices:
        t = (z1 - v.co.z) / (z1 - z0)
        roll = 1.0 + 0.07 * math.sin(math.pi * t)          # отворот скатан валиком
        v.co.x *= roll
        v.co.y = c[1] + (v.co.y - c[1]) * roll
        v.co.z -= tilt * (c[1] - v.co.y) / r[1]
    o.data.update()
    return o


def valenki(body, mat):
    """Валенки: голенище — гладкая оболочка, стопа — округлый короб по габаритам ступни болванки."""
    shaft = hbm.shell(body, "shaft", lambda c: 0.09 < c.z < 0.44, 0.03, mat, 0.005, 16.0, smooth=25)
    parts = [shaft]
    for s in (-1, 1):
        ft = [v.co for v in body.data.vertices if v.co.z < 0.13 and v.co.x * s > 0.02]
        x0, x1 = min(p.x for p in ft), max(p.x for p in ft)
        y0, y1 = min(p.y for p in ft), max(p.y for p in ft)
        kit.box("boot", (x1 - x0 + 0.022, y1 - y0 + 0.02, 0.12), ((x0 + x1) / 2, (y0 + y1) / 2 + 0.004, 0.058), mat, bevel=0.045)
        o = kit.objs[-1]
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); bpy.context.view_layer.objects.active = o
        o.modifiers["bev"].segments = 4
        bpy.ops.object.modifier_apply(modifier="bev")
        parts.append(o)
    return parts


def ushanka(body, name, ne, mat, flaps_down=True):
    """Ушанка по форме черепа (1.56): тулья — оболочка головы, толстый меховой отворот надо лбом,
    затыльник, уши вниз (flaps_down) или подняты и подвязаны на макушке. Раньше — купол шире головы («гриб»)."""
    hz = lambda z: z + ne
    def crown_pred(c):
        if abs(c.x) > 0.105:
            return False
        if c.y > 0.07:                     # лоб: край чуть выше бровей
            return c.z > hz(1.612)
        if c.y > 0.0:                      # виски — до верха ушей
            return c.z > hz(1.572)
        return c.z > hz(1.535)             # затылок — низко
    crown = hbm.shell(body, name + "_crown", crown_pred, 0.026, mat, 0.006, 22.0, smooth=6)
    # отворот надо лбом: мех валиком
    front = hbm.shell(body, name + "_front", lambda c: hz(1.607) < c.z < hz(1.652) and c.y > 0.065 and abs(c.x) < 0.078, 0.032, mat, 0.006, 30.0, smooth=10)
    back = hbm.shell(body, name + "_back", lambda c: hz(1.53) < c.z < hz(1.57) and c.y < -0.04 and abs(c.x) < 0.07, 0.03, mat, 0.006, 30.0, smooth=10)
    parts = [crown, front, back]
    if flaps_down:
        for s in (-1, 1):
            kit.box(name + "_flap", (0.03, 0.095, 0.125), (0.092 * s, 0.008, hz(1.545)), mat, bevel=0.014, rot=(0.0, -0.1 * s, 0.0))
            parts.append(kit.objs[-1])
    else:
        # уши подняты: меховые клапаны лежат на тулье по бокам, сверху шнурок
        up = hbm.shell(body, name + "_flapsup", lambda c: c.z > hz(1.66) and 0.03 < abs(c.x) < 0.085 and -0.035 < c.y < 0.055, 0.044, mat, 0.005, 28.0, smooth=12)
        parts.append(up)
    return parts


def quilt(o, step=0.07, amp=0.007):
    """Стёганка ватника: горизонтальные валики."""
    for v in o.data.vertices:
        v.co += v.normal * amp * (0.5 + 0.5 * math.cos(v.co.z * math.tau / step))
    o.data.update()


def torus(name, r, rr, loc, mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=rr, major_segments=12, minor_segments=4,
                                     location=loc, rotation=(math.pi / 2, 0, 0))
    o = bpy.context.object; o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    kit.objs.append(o)
    return o


def preview(name, ne):
    """Быстрый кадр в Workbench (тело во весь рост + лицо) — проверить форму до игры."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 600, 900
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for tag, loc, tgt, lens in (("full", (1.1, 3.4, 1.0), (0, 0, 0.92), 50), ("face", (0.18, 0.75, 1.6 + ne), (0, 0, 1.56 + ne), 60)):
        cam.location = loc
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        cam_d.lens = lens
        sc.render.filepath = os.path.join(OUT, f"_prev_{name}_{tag}.png")
        bpy.ops.render.render(write_still=True)


def build(variant):
    V = VARIANTS[variant]
    name = "human_driver" if variant == "driver" else "double_" + variant
    ne = V["neck"]
    kit.reset()
    SKIN = face_paint.face_mat(f"{name}_skin", V["skin"], ne, variant)   # глазницы, брови, губы, щетина — по координатам
    WHITE = kit.mat(f"{name}_sclera", (0.74, 0.72, 0.67), rough=0.4)
    IRIS = kit.mat(f"{name}_iris", (0.03, 0.025, 0.02), rough=0.3)
    body = hbm.load_body(BUNDLE, SKIN)

    # --- Скелет (A-поза), руки длиннее по варианту ----------------------------------------
    bones = hbm.human_bones(ne)
    B = {b[0]: (Vector(b[1]), Vector(b[2])) for b in bones}
    hbm.stretch_arms(body, B, forearm_extra=V["fore"], hand_scale=V["hand"], thin=V["thin"])
    fixed = []
    for bn, h, t, par in bones:
        h, t = Vector(h), Vector(t)
        if bn.startswith("forearm."):
            t = t + (t - h).normalized() * V["fore"]
        elif bn.startswith("hand."):
            fa = (B["forearm." + bn[-1]][1] - B["forearm." + bn[-1]][0]).normalized()
            nh = h + fa * V["fore"]
            t = nh + (t - h) * V["hand"]
            h = nh
        fixed.append((bn, tuple(h), tuple(t), par))
    bones = fixed

    # --- Лицо: распахнутые глаза, застывшая улыбка (до вытягивания шеи) ---------------------
    me = body.data
    for v in me.vertices:
        p = v.co
        if p.z < 1.44 or p.y < 0.06:
            continue
        if V["eye_open"] > 0:
            for ex in (-EYE_C[0], EYE_C[0]):
                c = Vector((ex, EYE_C[1], EYE_C[2]))
                d = Vector((p.x - c.x, 0, p.z - c.z))
                if d.length < 0.024 and p.y > 0.115:
                    k = (1.0 - d.length / 0.024) * V["eye_open"]
                    if d.length > 1e-4:
                        p.x += d.x / d.length * 0.0035 * k
                        p.z += d.z / d.length * 0.0045 * k
        if V["smile"] > 0 and abs(p.z - hbm.MOUTH_Z) < 0.02 and abs(p.x) < 0.055 and p.y > 0.09:
            # Застывшая улыбка: углы рта вверх и в стороны. Колокол и по x, и по z — без складки на краю зоны
            tz = abs(p.z - hbm.MOUTH_Z) / 0.02
            wz = (1.0 - tz * tz) ** 2
            tx = abs(p.x) / 0.055
            wx = math.sin(math.pi * min(tx * 1.15, 1.0)) ** 2
            w = wz * wx * V["smile"]
            p.x *= 1.0 + 0.12 * w
            p.z += 0.005 * w
    me.update()
    hbm.stretch_neck(body, ne)
    an.sculpt(body, amp=0.0012, scale=50.0, seed=7.0)

    ez = EYE_C[2] + ne
    for s in (-1, 1):
        kit.sphere("sclera", EYE_R, (EYE_C[0] * s, EYE_C[1], ez), WHITE, segs=10, rings=7)
        ir = 0.0042 if variant == "orekhov" else 0.0058
        kit.sphere("iris", ir, (EYE_C[0] * s, EYE_C[1] + EYE_R - 0.0015, ez), IRIS, scale=(1, 0.45, 1), segs=8, rings=5)
    eyes = kit.objs[-4:]

    def arm_lower(c, frac):
        n = "R" if c.x > 0 else "L"
        el = Vector(dict((b[0], b) for b in bones)[f"forearm.{n}"][1])
        wr = Vector(dict((b[0], b) for b in bones)[f"forearm.{n}"][2])
        fa = (wr - el).normalized()
        return abs(c.x) > 0.2 and (c - el).dot(fa) > (wr - el).length * frac

    head_z = lambda z: z + ne      # пороги головы сдвигаются вместе с ней
    extra = list(eyes)

    # --- Одежда ---------------------------------------------------------------------------
    if variant in ("mikhalych", "driver"):
        COAT = cloth(f"{name}_coat", (0.34, 0.25, 0.16), wear=0.4)
        FUR = cloth(f"{name}_fur", (0.6, 0.53, 0.43), 0.35, 40)
        PANTS = cloth(f"{name}_pants", (0.18, 0.2, 0.24))
        FELT = cloth(f"{name}_felt", (0.22, 0.21, 0.2), 0.3, 30)
        HAT = cloth(f"{name}_hat", (0.22, 0.17, 0.12), 0.3, 30)
        MIT = cloth(f"{name}_mit", (0.25, 0.2, 0.15))
        BELT = cloth(f"{name}_belt", (0.09, 0.07, 0.05), 0.1)
        GREY = kit.mat(f"{name}_grey", (0.5, 0.46, 0.38), rough=0.9, noise=0.35, noise_scale=120)
        coat = hbm.shell(body, "coat", lambda c: 0.84 < c.z < 1.47 and not arm_lower(c, 0.93), 0.055, COAT, smooth=30)
        an.sculpt(coat, amp=0.018, scale=5.0, seed=1.0)
        sk = skirt("skirt", 0.95, 0.47, (0.215, 0.17), (0.29, 0.24), COAT, n=28, rings=7)
        folds(sk, 7, 0.016)
        an.sculpt(sk, amp=0.012, scale=6.0, seed=2.0)
        collar = hbm.shell(body, "collar", lambda c: 1.34 < c.z < 1.47 + ne * 0.4 and abs(c.x) < 0.17, 0.07, FUR, 0.006, 30.0, smooth=14)
        cuffs = hbm.shell(body, "cuffs", lambda c: arm_lower(c, 0.78) and not arm_lower(c, 0.95), 0.065, FUR, 0.005, 30.0, smooth=10)
        belt = hbm.shell(body, "belt", lambda c: 0.94 < c.z < 1.0 and abs(c.x) < 0.22, 0.07, BELT, smooth=20)
        pants = hbm.shell(body, "pants", lambda c: 0.3 < c.z < 0.98 and abs(c.x) < 0.22, 0.02, PANTS, 0.01, 7.0, smooth=12)
        boots = valenki(body, FELT)
        mits = hbm.shell(body, "mits", lambda c: arm_lower(c, 0.97), 0.016, MIT, 0.004, 20.0, smooth=4)
        hat = ushanka(body, "hat", ne, HAT, flaps_down=True)
        must = hbm.shell(body, "moustache", lambda c: head_z(hbm.MOUTH_Z + 0.003) < c.z < head_z(hbm.MOUTH_Z + 0.024) and abs(c.x) < 0.04 and c.y > 0.1, 0.008, GREY, 0.003, 140.0, smooth=3)
        # усы свисают по углам рта
        for v in must.data.vertices:
            if abs(v.co.x) > 0.022:
                v.co.z -= (abs(v.co.x) - 0.022) * 0.7
        must.data.update()
        extra += [coat, sk, collar, cuffs, belt, pants, mits, must] + hat + boots
        dec = [(coat, 0.3), (collar, 0.3), (cuffs, 0.3), (belt, 0.3), (pants, 0.3), (boots[0], 0.3), (mits, 0.35)]
    elif variant == "semenov":
        VAT = cloth(f"{name}_vat", (0.17, 0.19, 0.21), 0.2, 12)
        PANTS = cloth(f"{name}_pants", (0.16, 0.17, 0.18))
        FELT = cloth(f"{name}_felt", (0.2, 0.19, 0.18), 0.3, 30)
        CAP = cloth(f"{name}_cap", (0.3, 0.1, 0.09), 0.35, 70)
        METAL = kit.mat(f"{name}_metal", (0.12, 0.11, 0.1), rough=0.4)
        vat = hbm.shell(body, "vatnik", lambda c: 0.8 < c.z < 1.47 and not arm_lower(c, 0.93), 0.045, VAT, smooth=30)
        quilt(vat)
        an.sculpt(vat, amp=0.01, scale=6.0, seed=4.0)
        collar = hbm.shell(body, "collar", lambda c: 1.36 < c.z < 1.46 and abs(c.x) < 0.14 and c.y < 0.06, 0.055, VAT, 0.006, 12.0, smooth=8)
        pants = hbm.shell(body, "pants", lambda c: 0.3 < c.z < 0.98 and abs(c.x) < 0.22, 0.024, PANTS, 0.01, 7.0, smooth=12)
        quilt(pants, 0.09, 0.005)
        boots = valenki(body, FELT)
        cap = hbm.shell(body, "cap", lambda c: abs(c.x) < 0.1 and (c.z > head_z(1.62) if c.y > 0.06 else c.z > head_z(1.585)), 0.014, CAP, 0.003, 60.0, smooth=10)
        cband = hbm.shell(body, "capband", lambda c: abs(c.x) < 0.085 and (head_z(1.62) < c.z < head_z(1.652) if c.y > 0.04 else head_z(1.59) < c.z < head_z(1.622)), 0.02, CAP, 0.002, 80.0, smooth=12)
        g = [torus("lens", 0.0175, 0.0017, (EYE_C[0] * s, 0.15, ez + 0.002), METAL) for s in (-1, 1)]
        kit.box("bridge", (0.018, 0.003, 0.003), (0, 0.153, ez + 0.006), METAL, bevel=0.0)
        g.append(kit.objs[-1])
        for s in (-1, 1):
            kit.box("temple", (0.003, 0.12, 0.003), (0.071 * s, 0.09, ez + 0.004), METAL, bevel=0.0)
            g.append(kit.objs[-1])
        extra += [vat, collar, pants, cap, cband] + g + boots
        dec = [(vat, 0.3), (collar, 0.3), (pants, 0.3), (boots[0], 0.3)]
    else:
        JACK = cloth(f"{name}_jack", (0.09, 0.11, 0.15), 0.18, 10, wear=0.25)
        FUR = cloth(f"{name}_fur", (0.32, 0.27, 0.21), 0.4, 50)
        SWEAT = cloth(f"{name}_sweat", (0.4, 0.38, 0.35), 0.3, 80)
        PANTS = cloth(f"{name}_pants", (0.12, 0.12, 0.13))
        FELT = cloth(f"{name}_felt", (0.16, 0.15, 0.15), 0.3, 30)
        HAT = cloth(f"{name}_hat", (0.07, 0.065, 0.06), 0.3, 30)
        jack = hbm.shell(body, "jacket", lambda c: 0.84 < c.z < 1.43 and not arm_lower(c, 0.93), 0.05, JACK, smooth=30)
        an.sculpt(jack, amp=0.016, scale=5.0, seed=5.0)
        hood = hbm.shell(body, "hood", lambda c: c.y < -0.02 and 1.28 < c.z < 1.47 and abs(c.x) < 0.14, 0.085, JACK, 0.015, 9.0, smooth=12)
        rim = hbm.shell(body, "hoodrim", lambda c: c.y < -0.02 and 1.43 < c.z < 1.49 and abs(c.x) < 0.15, 0.1, FUR, 0.014, 30.0, smooth=8)
        sweat = hbm.shell(body, "sweater", lambda c: 1.37 < c.z < 1.445 and abs(c.x) < 0.12, 0.016, SWEAT, 0.003, 40.0, smooth=4)
        pants = hbm.shell(body, "pants", lambda c: 0.3 < c.z < 0.98 and abs(c.x) < 0.22, 0.02, PANTS, 0.01, 7.0, smooth=12)
        boots = valenki(body, FELT)
        hat = ushanka(body, "hat", ne, HAT, flaps_down=False)
        extra += [jack, hood, rim, sweat, pants] + hat + boots
        dec = [(jack, 0.3), (hood, 0.35), (rim, 0.35), (sweat, 0.4), (pants, 0.3), (boots[0], 0.3)]

    # --- Привязка и поза покоя: стоит прямо, руки по швам ----------------------------------
    arm = an.armature(bones, name + "_arm")
    hbm.bind(arm, body, extra)
    stiff = 0.6 if variant == "orekhov" else 1.0
    aims = []
    for n, s in (("L", -1), ("R", 1)):
        aims += [(f"upper_arm.{n}", (0.07 * s * stiff, 0.02, -1)), (f"forearm.{n}", (0.03 * s, 0.07 * stiff, -1)),
                 (f"hand.{n}", (0.01 * s, 0.07 * stiff, -1))]
    hbm.pose_to_rest(arm, [body] + extra, aims)
    print("EYE_GODOT", [(round(EYE_C[0] * s, 3), round(ez, 3), round(-(EYE_C[1] + EYE_R), 3)) for s in (-1, 1)])

    keep = body.vertex_groups.new(name="dec_keep")
    keep.add([v.index for v in body.data.vertices if v.co.z < 1.43 + ne], 1.0, "REPLACE")
    keep.add([v.index for v in body.data.vertices if v.co.z >= 1.43 + ne], 0.08, "REPLACE")
    dm = body.modifiers.new("dec", "DECIMATE")
    dm.ratio = 0.4
    dm.vertex_group = "dec_keep"
    dm.vertex_group_factor = 1.0
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True); bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier="dec")
    hbm.decimate([d for d in dec if d[1] < 1.0])
    kit.objs = [o for o in kit.objs if o.name in bpy.data.objects and o.type == "MESH"]
    head_z0 = 1.45 + ne
    bodym, img, tris = kit.finish(name, OUT, res=2048, origin="keep", samples=32, ao_min=0.45, pack=0.004, ao_blur=2,
                                  uv_boost=(lambda c: c.z > head_z0 and abs(c.x) < 0.13, 2.6))

    # --- Клипы людей (human_rig.py), поверх покоя «руки по швам» --------------------------
    bpy.context.scene.render.fps = 24
    clip = lambda nm, length, keys: an.clip(arm, nm, length, keys)
    mix = lambda *ps: {k: v for p in ps for k, v in p.items()}
    ARMS = {"forearm.L": (6, 0, 0), "forearm.R": (6, 0, 0)}
    clip("idle", 80, {1: mix(ARMS, {"chest": (-2, 0, 0)}), 40: mix(ARMS, {"chest": (-3, 0, 1), "hips": (0, 0, 1.5)}), 80: mix(ARMS, {"chest": (-2, 0, 0)})})
    WA = mix(ARMS, {"thigh.L": (26, 0, 0), "shin.L": (-8, 0, 0), "foot.L": (-12, 0, 0), "thigh.R": (-18, 0, 0), "shin.R": (-22, 0, 0), "foot.R": (14, 0, 0),
                    "upper_arm.L": (-14, 0, 0), "upper_arm.R": (16, 0, 0), "forearm.R": (14, 0, 0), "hips": (0, 0, 4), "chest": (-3, 3, -2)})
    WB = mix(ARMS, {"thigh.L": (4, 0, 0), "shin.L": (-6, 0, 0), "thigh.R": (6, 0, 0), "shin.R": (-50, 0, 0), "foot.R": (10, 0, 0),
                    "root@loc": (0, 0, 0.025), "chest": (-3, 0, 0)})
    clip("walk", 33, an.cycle(WA, WB, 16))
    RA = {"root@loc": (0, 0, 0.04), "thigh.L": (50, 0, 0), "shin.L": (-30, 0, 0), "thigh.R": (-30, 0, 0), "shin.R": (-70, 0, 0), "foot.R": (20, 0, 0),
          "upper_arm.L": (-40, 0, 0), "forearm.L": (50, 0, 0), "upper_arm.R": (45, 0, 0), "forearm.R": (60, 0, 0), "spine": (-10, 0, 0), "chest": (-6, 6, 0)}
    RB = {"thigh.L": (10, 0, 0), "shin.L": (-60, 0, 0), "thigh.R": (20, 0, 0), "shin.R": (-20, 0, 0), "root@loc": (0, 0, 0.06),
          "forearm.L": (60, 0, 0), "forearm.R": (60, 0, 0), "spine": (-12, 0, 0)}
    clip("run", 17, an.cycle(RA, RB, 8))
    # Стоит. Голова чуть склонена — и не шевелится, только раз в пару секунд дёргается на градус
    ST = mix(ARMS, {"head": (4, 0, 7), "neck": (2, 0, 3)})
    clip("still", 120, {1: ST, 60: mix(ST, {"head": (5, 2, 9)}), 62: ST, 120: ST})
    PK = mix(ARMS, {"spine": (0, 0, -10), "chest": (0, 0, -12), "neck": (0, 0, -8), "head": (0, -10, -22), "upper_arm.L": (30, 0, -20), "forearm.L": (40, 0, 0)})
    clip("peek", 100, {1: PK, 50: mix(PK, {"head": (2, -14, -28)}), 60: PK, 100: PK})
    # Стучит в дверь костяшками правой — три удара, пауза
    KN_UP = mix(ARMS, {"upper_arm.R": (70, 0, 10), "forearm.R": (75, 0, 0), "hand.R": (-10, 0, 0), "head": (2, 0, 0)})
    KN_HIT = mix(KN_UP, {"forearm.R": (95, 0, 0), "hand.R": (5, 0, 0), "upper_arm.R": (74, 0, 10)})
    clip("knock", 48, {1: KN_UP, 4: KN_HIT, 7: KN_UP, 10: KN_HIT, 13: KN_UP, 16: KN_HIT, 19: KN_UP, 48: KN_UP})
    # Приник к двери и говорит в щель: ладонь на полотне, голова у косяка
    LN = mix(ARMS, {"spine": (-8, 0, 0), "chest": (-10, 0, 0), "neck": (14, 0, 6), "head": (8, 10, 14),
                    "upper_arm.R": (78, 0, 14), "forearm.R": (58, 0, 0), "hand.R": (-30, 0, 0)})
    clip("lean", 96, {1: LN, 48: mix(LN, {"head": (10, 12, 16), "chest": (-11, 0, 0)}), 96: LN})
    if variant == "driver":
        # Сидит за рычагами ГТ-Т: бёдра вперёд, голени вниз, руки на рычагах; разговаривает; машет на прощание
        SIT = {"thigh.L": (88, 0, 4), "thigh.R": (88, 0, -4), "shin.L": (-88, 0, 0), "shin.R": (-88, 0, 0), "root@loc": (0, -0.05, 0.0),
               "upper_arm.L": (40, 0, -6), "upper_arm.R": (40, 0, 6), "forearm.L": (50, 0, 0), "forearm.R": (50, 0, 0), "chest": (-4, 0, 0), "spine": (-4, 0, 0)}
        clip("sit_drive", 60, {1: SIT, 20: mix(SIT, {"upper_arm.L": (44, 0, -6), "chest": (-5, 0, 0)}), 40: mix(SIT, {"upper_arm.R": (44, 0, 6)}), 60: SIT})
        T1 = mix(SIT, {"upper_arm.R": (70, 0, 18), "forearm.R": (70, 0, 0), "hand.R": (-20, 0, 0), "head": (6, -12, 0), "chest": (-2, -6, 0)})
        T2 = mix(SIT, {"upper_arm.R": (55, 0, 26), "forearm.R": (40, 0, 0), "hand.R": (10, 0, 20), "head": (-4, -8, 3), "chest": (-3, -4, 0)})
        clip("sit_talk", 44, {1: SIT, 8: T1, 16: T2, 24: T1, 32: mix(T2, {"head": (8, -16, 0)}), 44: SIT})
        WV = mix(ARMS, {"upper_arm.R": (10, 0, 140), "forearm.R": (0, 0, 20), "head": (0, 10, 0)})
        clip("wave", 32, {1: WV, 8: mix(WV, {"forearm.R": (0, 0, -25)}), 16: WV, 24: mix(WV, {"forearm.R": (0, 0, -25)}), 32: WV})

    an.export_rigged(arm, bodym, OUT, name)
    if os.environ.get("PREVIEW"):
        for t in arm.animation_data.nla_tracks:
            t.mute = True
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        bpy.context.view_layer.update()
        preview(name, ne)
    print("[OK]", name, "tris:", tris)


for v in (VARIANTS if WHICH == "all" else [WHICH]):
    build(v)
