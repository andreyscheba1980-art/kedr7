# «Кедр-7» — роспись лица по координатам болванки HBM (нос +Y, ноги z = 0): глазницы, веки, брови, губы,
# щетина, румянец. Всё — узлами в материале кожи, запекается kit.finish вместе с остальным цветом.
# Без этого лицо — ровная серая маска: в глазке и в окне двойник читался как манекен.
import bpy
import kit

EYE_X, EYE_Y, EYE_Z = 0.0329, 0.1222, 1.5737
MOUTH_Z = 1.497

LOOKS = {
    # Живой Михалыч: обветренный, красный нос и щёки, седые кустистые брови и щетина
    "driver": dict(socket=0.25, socket_col=(0.32, 0.2, 0.17), brow=(0.52, 0.5, 0.46), brow_w=1.2, lips=(0.52, 0.28, 0.25),
                   stubble=(0.38, 0.34, 0.31), stubble_amt=0.55, flush=(0.75, 0.36, 0.3), flush_amt=0.45, nose=0.55, lash=0.5),
    # Двойник Михалыча: то же лицо, но кровь ушла — румянца нет, глазницы темнее
    "mikhalych": dict(socket=0.5, socket_col=(0.2, 0.15, 0.15), brow=(0.5, 0.48, 0.45), brow_w=1.2, lips=(0.38, 0.3, 0.3),
                      stubble=(0.34, 0.31, 0.3), stubble_amt=0.5, flush=(0.55, 0.42, 0.4), flush_amt=0.12, nose=0.1, lash=0.6),
    "semenov": dict(socket=0.6, socket_col=(0.17, 0.13, 0.14), brow=(0.16, 0.13, 0.11), brow_w=1.0, lips=(0.34, 0.27, 0.27),
                    stubble=(0.17, 0.15, 0.14), stubble_amt=0.7, flush=(0.5, 0.4, 0.4), flush_amt=0.05, nose=0.0, lash=0.7),
    # Орехов-двойник: твоё лицо, из которого ушла жизнь. Серая кожа, провалы глаз, бескровные губы, брови редкие
    "orekhov": dict(socket=0.85, socket_col=(0.1, 0.08, 0.1), brow=(0.2, 0.17, 0.15), brow_w=0.6, lips=(0.33, 0.3, 0.32),
                    stubble=(0.24, 0.23, 0.24), stubble_amt=0.35, flush=(0.4, 0.4, 0.45), flush_amt=0.0, nose=0.0, lash=0.8),
}


def face_mat(name, skin, ne, look):
    L = LOOKS[look]
    m = kit.mat(name, skin, rough=0.7, noise=0.07, noise_scale=40)
    nt = m.node_tree
    N, K = nt.nodes, nt.links
    bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    base_in = bsdf.inputs["Base Color"]
    cur = base_in.links[0].from_socket if base_in.links else None
    if cur is None:
        rgb = N.new("ShaderNodeRGB"); rgb.outputs[0].default_value = (*skin, 1); cur = rgb.outputs[0]
    pos = N.new("ShaderNodeTexCoord").outputs["Object"]
    sep = N.new("ShaderNodeSeparateXYZ"); K.new(pos, sep.inputs[0])
    ax = N.new("ShaderNodeMath"); ax.operation = "ABSOLUTE"; K.new(sep.outputs[0], ax.inputs[0])
    X, Y, Z = ax.outputs[0], sep.outputs[1], sep.outputs[2]       # X — |x|: лицо симметрично
    ez, mz = EYE_Z + ne, MOUTH_Z + ne

    def band(sock, a, b, soft):
        """1 внутри [a, b], мягко к нулю на soft."""
        lo = N.new("ShaderNodeMapRange"); lo.interpolation_type = "SMOOTHSTEP"
        K.new(sock, lo.inputs["Value"]); lo.inputs["From Min"].default_value = a - soft; lo.inputs["From Max"].default_value = a
        hi = N.new("ShaderNodeMapRange"); hi.interpolation_type = "SMOOTHSTEP"
        K.new(sock, hi.inputs["Value"]); hi.inputs["From Min"].default_value = b + soft; hi.inputs["From Max"].default_value = b
        mul = N.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        K.new(lo.outputs[0], mul.inputs[0]); K.new(hi.outputs[0], mul.inputs[1])
        return mul.outputs[0]

    def prod(*socks):
        out = socks[0]
        for s in socks[1:]:
            mm = N.new("ShaderNodeMath"); mm.operation = "MULTIPLY"
            K.new(out, mm.inputs[0]); K.new(s, mm.inputs[1]); out = mm.outputs[0]
        return out

    def ball(c, r0, r1):
        """1 в центре до r0, к нулю на r1 (c — с |x|)."""
        cv = N.new("ShaderNodeCombineXYZ"); K.new(X, cv.inputs[0]); K.new(Y, cv.inputs[1]); K.new(Z, cv.inputs[2])
        d = N.new("ShaderNodeVectorMath"); d.operation = "DISTANCE"
        K.new(cv.outputs[0], d.inputs[0]); d.inputs[1].default_value = c
        mr = N.new("ShaderNodeMapRange"); mr.interpolation_type = "SMOOTHSTEP"
        K.new(d.outputs["Value"], mr.inputs["Value"]); mr.inputs["From Min"].default_value = r1; mr.inputs["From Max"].default_value = r0
        return mr.outputs[0]

    def speckle(scale, thr):
        nz = N.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 2
        K.new(pos, nz.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange"); K.new(nz.outputs["Fac"], mr.inputs["Value"])
        mr.inputs["From Min"].default_value = thr; mr.inputs["From Max"].default_value = thr + 0.12
        return mr.outputs[0]

    def paint(col, fac, amount=1.0):
        nonlocal cur
        if amount <= 0:
            return
        f = fac
        if amount != 1.0:
            mm = N.new("ShaderNodeMath"); mm.operation = "MULTIPLY"; K.new(fac, mm.inputs[0]); mm.inputs[1].default_value = amount
            f = mm.outputs[0]
        mx = N.new("ShaderNodeMix"); mx.data_type = "RGBA"
        K.new(f, mx.inputs[0]); K.new(cur, mx.inputs[6]); mx.inputs[7].default_value = (*col, 1)
        cur = mx.outputs[2]

    front = band(Y, 0.06, 0.4, 0.02)             # только лицевая сторона головы
    # Щетина: подбородок, щёки ниже скул, над губой
    jaw = prod(band(Z, mz - 0.065, mz + 0.022, 0.012), band(X, 0.0, 0.062, 0.012), band(Y, 0.02, 0.4, 0.02))
    paint(L["stubble"], prod(jaw, speckle(520.0, 0.5)), L["stubble_amt"])
    # Румянец на скулах и красный нос
    paint(L["flush"], prod(ball((0.047, 0.1, ez - 0.032), 0.006, 0.032), front), L["flush_amt"])
    paint((0.72, 0.32, 0.28), ball((0.0, 0.16, ez - 0.04), 0.004, 0.02), L["nose"])
    # Глазницы: тень вокруг глаза, глубже к внутреннему углу
    paint(L["socket_col"], prod(ball((EYE_X, EYE_Y - 0.004, ez - 0.002), 0.011, 0.03), front), L["socket"])
    paint(L["socket_col"], prod(ball((EYE_X - 0.014, EYE_Y - 0.008, ez - 0.006), 0.003, 0.014), front), L["socket"] * 0.8)
    # Линия ресниц по верхнему веку
    lid = prod(band(Z, ez + 0.003, ez + 0.0075, 0.0015), band(X, EYE_X - 0.013, EYE_X + 0.014, 0.003), band(Y, 0.1, 0.2, 0.01))
    paint((0.05, 0.04, 0.04), lid, L["lash"])
    # Брови: дуга над глазом, рвано (волоски — шумом)
    bw = L["brow_w"]
    # дуга: выше всего над зрачком, к краям опускается (Zb = Z + 14·(|x| − 0.03)²); к виску тоньше
    dx = N.new("ShaderNodeMath"); dx.operation = "SUBTRACT"; K.new(X, dx.inputs[0]); dx.inputs[1].default_value = 0.03
    sq = N.new("ShaderNodeMath"); sq.operation = "MULTIPLY"; K.new(dx.outputs[0], sq.inputs[0]); K.new(dx.outputs[0], sq.inputs[1])
    zb = N.new("ShaderNodeMath"); zb.operation = "MULTIPLY_ADD"; K.new(sq.outputs[0], zb.inputs[0]); zb.inputs[1].default_value = 14.0
    K.new(Z, zb.inputs[2])
    taper = N.new("ShaderNodeMapRange"); K.new(X, taper.inputs["Value"])
    taper.inputs["From Min"].default_value = 0.03; taper.inputs["From Max"].default_value = 0.058
    taper.inputs["To Min"].default_value = 1.0; taper.inputs["To Max"].default_value = 0.25
    brow = prod(band(zb.outputs[0], ez + 0.017, ez + 0.017 + 0.007 * bw, 0.0025), band(X, 0.009, 0.054, 0.007), band(Y, 0.08, 0.2, 0.01), taper.outputs[0])
    paint(L["brow"], prod(brow, speckle(330.0, 0.28)), 0.9)
    # Губы
    lips = prod(band(Z, mz - 0.0075, mz + 0.0055, 0.0025), band(X, 0.0, 0.023, 0.005), band(Y, 0.105, 0.2, 0.01))
    paint(L["lips"], lips, 0.85)
    K.new(cur, base_in)
    return m
