class_name SpruceMesh
extends RefCounted
## Гранёная заснеженная ель «как нарисованная»: ярусы-юбки с зубчатым нижним краем,
## снег лежит на верхней части каждого яруса (рваная граница), низ ярусов тёмный.
## Плоские нормали — каждая грань ловит лунный свет отдельно. Цвета — в вершинах, один материал,
## один меш на всё дерево: лес из сотен елей — это пара MultiMesh-ов.

const NEEDLE := Color(0.05, 0.1, 0.085)
const NEEDLE_LIT := Color(0.09, 0.17, 0.14)
const SNOW := Color(0.68, 0.78, 0.92)
const SNOW_SHADE := Color(0.46, 0.58, 0.78)
const BARK := Color(0.12, 0.085, 0.065)
const UNDER := Color(0.015, 0.03, 0.025)

static var _cache: Dictionary = {}
static var _mat: Material


## variant: 0 — густая ель, 1 — стройная высокая, 2 — молодая низкая, 3 — сухостой.
static func mesh(variant: int) -> ArrayMesh:
	if _cache.has(variant):
		return _cache[variant]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # плоские нормали: грани, а не «облако»
	var rng := RandomNumberGenerator.new()
	rng.seed = 101 + variant * 17
	match variant:
		0:
			_trunk(st, 0.2, 2.2, 6)
			_tiers(st, rng, [[0.45, 2.4, 1.5], [1.4, 2.0, 1.35], [2.25, 1.6, 1.25], [3.05, 1.2, 1.15], [3.8, 0.82, 1.1], [4.45, 0.45, 1.15]], 8)
		1:
			_trunk(st, 0.16, 2.6, 6)
			_tiers(st, rng, [[0.8, 1.6, 1.3], [1.75, 1.4, 1.25], [2.65, 1.18, 1.2], [3.5, 0.95, 1.15], [4.3, 0.72, 1.1], [5.05, 0.5, 1.05], [5.75, 0.3, 1.1]], 7)
		2:
			_trunk(st, 0.12, 1.0, 5)
			_tiers(st, rng, [[0.25, 1.45, 1.05], [0.95, 1.1, 0.95], [1.6, 0.72, 0.9], [2.15, 0.38, 0.9]], 7)
		_:
			_dead(st, rng)
	st.generate_normals()   # вершины не общие — нормали выйдут плоскими, по граням
	var m := st.commit()
	m.surface_set_material(0, material())
	_cache[variant] = m
	return m


static func material() -> Material:
	if _mat != null:
		return _mat
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/spruce.gdshader")   # качание на ветру (global wind)
	_mat = m
	return _mat


# --- Ель вблизи: лапы-карточки -----------------------------------------------------------
# Дальние ели остаются гранёными (mesh), ближние — из лап с текстурой хвои и снежными шапками
# (near). Переключение по дальности — у MultiMesh-ей двора и тайги (NEAR_RANGE).

const NEAR_RANGE := 46.0
static var _near_cache: Dictionary = {}
static var _card_mat: Material

## [высота нижней мутовки, высота ели, радиус низа, шаг мутовок, лап в мутовке]
const NEAR_SHAPES := {
	0: [0.35, 5.7, 2.35, 0.42, 7],
	1: [0.75, 6.9, 1.6, 0.44, 6],
	2: [0.18, 3.1, 1.4, 0.38, 6],
}


static func near(variant: int) -> ArrayMesh:
	if variant == 3 or not NEAR_SHAPES.has(variant):
		return mesh(variant)
	if _near_cache.has(variant):
		return _near_cache[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = 501 + variant * 31
	var sh: Array = NEAR_SHAPES[variant]
	var y0: float = sh[0]
	var top: float = sh[1]
	var r0: float = sh[2]
	var dy: float = sh[3]
	var per: int = sh[4]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Ствол (кора из атласа)
	var tr := 0.17 if variant == 0 else 0.13 if variant == 1 else 0.09
	for i in 7:
		var a0 := TAU * i / 7.0
		var a1 := TAU * (i + 1) / 7.0
		var u0 := 0.01 + 0.08 * i / 7.0
		var u1 := 0.01 + 0.08 * (i + 1) / 7.0
		var b0 := Vector3(cos(a0) * tr, -0.3, sin(a0) * tr)
		var b1 := Vector3(cos(a1) * tr, -0.3, sin(a1) * tr)
		var t0 := Vector3(cos(a0) * tr * 0.25, top * 0.92, sin(a0) * tr * 0.25)
		var t1 := Vector3(cos(a1) * tr * 0.25, top * 0.92, sin(a1) * tr * 0.25)
		var c := Color(0.75, 0.75, 0.75)
		_cv(st, b0, Vector2(u0, 1.0), Vector3(cos(a0), 0, sin(a0)), c)
		_cv(st, t0, Vector2(u0, 0.5), Vector3(cos(a0), 0, sin(a0)), c)
		_cv(st, b1, Vector2(u1, 1.0), Vector3(cos(a1), 0, sin(a1)), c)
		_cv(st, b1, Vector2(u1, 1.0), Vector3(cos(a1), 0, sin(a1)), c)
		_cv(st, t0, Vector2(u0, 0.5), Vector3(cos(a0), 0, sin(a0)), c)
		_cv(st, t1, Vector2(u1, 0.5), Vector3(cos(a1), 0, sin(a1)), c)
	# Тёмная сердцевина: лапы не просвечивают насквозь, ель плотная, а не «скелет»
	var core_c := Color(0.16, 0.22, 0.19)
	var levels := 4
	for k in levels:
		var ya := y0 + (top - y0) * k / float(levels)
		var yb := y0 + (top - y0) * (k + 1.4) / float(levels)
		var rr := r0 * 0.28 * (1.0 - float(k) / levels)
		for i in 6:
			var a0 := TAU * i / 6.0 + k
			var a1 := TAU * (i + 1) / 6.0 + k
			var p0 := Vector3(cos(a0) * rr, ya, sin(a0) * rr)
			var p1 := Vector3(cos(a1) * rr, ya, sin(a1) * rr)
			var ap := Vector3(0, minf(yb, top), 0)
			var n0 := Vector3(cos(a0), 0.6, sin(a0)).normalized()
			_cv(st, p0, Vector2(0.2, 0.75), n0, core_c)
			_cv(st, ap, Vector2(0.2, 0.75), Vector3.UP, core_c)
			_cv(st, p1, Vector2(0.2, 0.75), n0, core_c)
	# Мутовки лап снизу вверх
	var y := y0
	var turn := 0.0
	while y < top - 0.25:
		var f := (y - y0) / (top - y0)                  # 0 — низ, 1 — макушка
		var rad := r0 * pow(1.0 - f, 0.92) + 0.18
		var n := per + 1 if f < 0.75 else maxi(per - 1, 4)
		turn += 0.55
		var tone := lerpf(0.85, 1.2, f) * rng.randf_range(0.9, 1.08)
		for i in n:
			var ang := turn + TAU * i / float(n) + rng.randf_range(-0.25, 0.25)
			var ln := rad * rng.randf_range(0.82, 1.1)
			var droop := ln * lerpf(0.42, 0.08, f) * rng.randf_range(0.8, 1.2)
			var lift := ln * lerpf(0.0, 0.22, f)          # у макушки лапы смотрят вверх
			var light := rng.randf() < 0.3
			_branch(st, rng, Vector3(0, y + rng.randf_range(-0.05, 0.05), 0), ang, ln, droop - lift, tone, light,
				rng.randf() < lerpf(0.98, 0.8, f), f < 0.55)
		y += dy * rng.randf_range(0.85, 1.15)
	# Макушка: торчащий побег и снежный колпачок
	_branch(st, rng, Vector3(0, top - 0.5, 0), PI * 0.5, 0.55, -0.5, 1.05, false, true)
	st.index()
	var m := st.commit()
	m.surface_set_material(0, card_material())
	_near_cache[variant] = m
	return m


## Пара LOD для леса: гранёная ель исчезает ближе lod_m, карточная — дальше (по корню каждой ели,
## без зазоров на стыках клеток MultiMesh).
static var _lod_cache: Dictionary = {}


## Ели-карточки вблизи — с пресета «средний»; на «низком» и с --no_cards весь лес гранёный.
static func cards_enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return (Settings.quality >= 1 or args.has("--cards")) and not args.has("--no_cards")


static func lod_far(variant: int, lod_m: float) -> ArrayMesh:
	var key := "f%d_%d" % [variant, int(lod_m)]
	if not _lod_cache.has(key):
		var m := mesh(variant).duplicate() as ArrayMesh
		var mat := (material() as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"lod_near", lod_m if (variant != 3 and cards_enabled()) else 0.0)
		mat.set_meta(&"lod_m", lod_m if variant != 3 else 0.0)
		m.surface_set_material(0, mat)
		_lod_cache[key] = m
	return _lod_cache[key]


## Гранёные ели прячутся вблизи только когда рядом есть карточные (SpruceNear).
static func set_near_cut(on: bool) -> void:
	for key: String in _lod_cache:
		if key.begins_with("f"):
			var mat := (_lod_cache[key] as ArrayMesh).surface_get_material(0) as ShaderMaterial
			mat.set_shader_parameter(&"lod_near", float(mat.get_meta(&"lod_m", 0.0)) if on else 0.0)


static func lod_near(variant: int, lod_m: float) -> ArrayMesh:
	if variant == 3:
		return null
	var key := "n%d_%d" % [variant, int(lod_m)]
	if not _lod_cache.has(key):
		var m := near(variant).duplicate() as ArrayMesh
		var mat := (card_material() as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"lod_far", lod_m)
		m.surface_set_material(0, mat)
		_lod_cache[key] = m
	return _lod_cache[key]


static func card_material() -> Material:
	if _card_mat != null:
		return _card_mat
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/spruce_card.gdshader")
	m.set_shader_parameter(&"atlas", load("res://assets/textures/spruce_atlas.png"))
	_card_mat = m
	return _card_mat


static func _cv(st: SurfaceTool, p: Vector3, uv: Vector2, n: Vector3, c: Color) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.set_color(c)
	st.add_vertex(p)


## Лапа: изогнутая карточка хвои (3 сегмента вдоль, 2 поперёк, с килем по стеблю) и снежная шапка сверху.
static func _branch(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, ang: float, ln: float, droop: float,
		tone: float, light: bool, snowy: bool, heavy := false, sub := false) -> void:
	var dir := Vector3(cos(ang), 0, sin(ang))
	var side := Vector3(-dir.z, 0, dir.x)
	var w := ln * (0.86 if not sub else 0.95)
	var u_off := 0.5 if light else 0.0
	var v_off := 0.5 if light else 0.0
	var segs := 3 if not sub else 2
	# Подлапки: от середины лапы вбок и вниз — ярус пушистый, слоями, а не плоская юбка
	if not sub and ln > 0.9:   # только у крупных нижних лап: вершин вдвое не раздуваем
		for sgn: float in [-1.0, 1.0]:
			var tb := rng.randf_range(0.35, 0.55)
			var b2 := base + dir * (0.12 + ln * tb) + Vector3(0, -droop * tb * tb + ln * 0.06 * tb - ln * 0.05, 0)
			_branch(st, rng, b2, ang + sgn * rng.randf_range(0.55, 0.85), ln * rng.randf_range(0.42, 0.55),
				ln * 0.2, tone * 0.85, rng.randf() < 0.25, false, false, true)
	var pts: Array[Vector3] = []
	for k in segs + 1:
		var t := float(k) / segs
		# Лапа отходит почти горизонтально и провисает к кончику
		pts.append(base + dir * (0.12 + ln * t) + Vector3(0, -droop * t * t + ln * 0.06 * t, 0))
	var nrm := (dir * 0.55 + Vector3.UP * 0.8).normalized()
	for k in segs:
		var t0 := float(k) / segs
		var t1 := float(k + 1) / segs
		var w0 := w * (0.35 + 0.65 * sin(PI * clampf(0.15 + 0.85 * t0, 0.0, 1.0)))
		var w1 := w * (0.35 + 0.65 * sin(PI * clampf(0.15 + 0.85 * t1, 0.0, 1.0))) * (0.6 if k == segs - 1 else 1.0)
		var keel := Vector3(0, ln * 0.05, 0)                 # стебель чуть выше краёв
		var c0 := Color(tone * (0.75 + 0.55 * t0), tone * (0.8 + 0.55 * t0), tone * (0.8 + 0.55 * t0))
		var c1 := Color(tone * (0.75 + 0.55 * t1), tone * (0.8 + 0.55 * t1), tone * (0.8 + 0.55 * t1))
		for sgn: float in [-1.0, 1.0]:
			var a := pts[k] + keel
			var b := pts[k + 1] + keel
			var c := pts[k + 1] + side * sgn * w1 * 0.5 - Vector3(0, ln * 0.04, 0)
			var d := pts[k] + side * sgn * w0 * 0.5 - Vector3(0, ln * 0.04, 0)
			var ua := Vector2(u_off + t0 * 0.5, v_off + 0.25)
			var ub := Vector2(u_off + t1 * 0.5, v_off + 0.25)
			var uc := Vector2(u_off + t1 * 0.5, v_off + 0.25 + sgn * 0.25 * (w1 / w))
			var ud := Vector2(u_off + t0 * 0.5, v_off + 0.25 + sgn * 0.25 * (w0 / w))
			_cv(st, a, ua, nrm, c0)
			_cv(st, b, ub, nrm, c1)
			_cv(st, c, uc, nrm, c1)
			_cv(st, a, ua, nrm, c0)
			_cv(st, c, uc, nrm, c1)
			_cv(st, d, ud, nrm, c0)
	if not snowy:
		return
	# Снежная шапка: лежит на лапе от ствола почти до кончика
	var sw := w * rng.randf_range(0.4, 0.52)
	var reach := rng.randf_range(0.72, 0.95)
	var lift := Vector3(0, ln * 0.09, 0)
	for k in 2:
		var t0 := float(k) / 2.0 * reach
		var t1 := float(k + 1) / 2.0 * reach
		var p0 := base + dir * (0.1 + ln * t0) + Vector3(0, -droop * t0 * t0 + ln * 0.06 * t0, 0) + lift
		var p1 := base + dir * (0.1 + ln * t1) + Vector3(0, -droop * t1 * t1 + ln * 0.06 * t1, 0) + lift
		var cs := Color(0.74, 0.76, 0.82) if k == 0 else Color(0.86, 0.87, 0.9)
		var su0 := 0.5 + t0 / reach * 0.5
		var su1 := 0.5 + t1 / reach * 0.5
		# Подушка снега: середина выше краёв, края свисают; второй слой — уже и выше
		for layer in (2 if heavy else 1):
			var wk := 1.0 if layer == 0 else 0.55
			var up := Vector3(0, ln * (0.0 if layer == 0 else 0.045), 0)
			var mound := Vector3(0, ln * 0.05 * wk, 0)
			var sag := Vector3(0, -ln * 0.035, 0)
			var l0: Vector3 = p0 - side * sw * wk + sag + up
			var l1: Vector3 = p1 - side * sw * 0.8 * wk + sag + up
			var m0: Vector3 = p0 + mound + up
			var m1: Vector3 = p1 + mound + up
			var r0: Vector3 = p0 + side * sw * wk + sag + up
			var r1: Vector3 = p1 + side * sw * 0.8 * wk + sag + up
			var vl := 0.02 if layer == 0 else 0.1
			var vr := 0.48 if layer == 0 else 0.4
			var c := cs if layer == 0 else cs * 1.12
			var nl := (Vector3.UP - side * 0.5).normalized()
			var nr := (Vector3.UP + side * 0.5).normalized()
			for tri: Array in [[l0, vl, su0, nl], [l1, vl, su1, nl], [m1, 0.25, su1, Vector3.UP], [l0, vl, su0, nl], [m1, 0.25, su1, Vector3.UP], [m0, 0.25, su0, Vector3.UP],
					[m0, 0.25, su0, Vector3.UP], [m1, 0.25, su1, Vector3.UP], [r1, vr, su1, nr], [m0, 0.25, su0, Vector3.UP], [r1, vr, su1, nr], [r0, vr, su0, nr]]:
				_cv(st, tri[0], Vector2(tri[2], tri[1]), tri[3], c)


## Ярус: [высота низа, радиус юбки, высота конуса]. Верхушка яруса заходит под следующий.
static func _tiers(st: SurfaceTool, rng: RandomNumberGenerator, tiers: Array, sides: int) -> void:
	for t: Array in tiers:
		var y0: float = t[0]
		var r: float = t[1]
		var h: float = t[2]
		var phase := rng.randf() * TAU
		var apex := Vector3(rng.randf_range(-0.05, 0.05), y0 + h, rng.randf_range(-0.05, 0.05))
		var skirt: Array[Vector3] = []
		var mid: Array[Vector3] = []
		for i in range(sides):
			var a := phase + TAU * float(i) / float(sides)
			var rr := r * rng.randf_range(0.82, 1.12)
			var droop := rng.randf_range(-0.28, 0.02)      # кончики лап свисают ниже — «зубчатая юбка»
			skirt.append(Vector3(cos(a) * rr, y0 + droop, sin(a) * rr))
			# Граница снега близко к краю лапы: верх яруса — снег, по краю — тёмная хвоя, рваной полосой.
			var k := rng.randf_range(0.62, 0.86)
			mid.append(apex.lerp(skirt[i], k) + Vector3(0, rng.randf_range(-0.04, 0.04), 0))
		for i in range(sides):
			var j := (i + 1) % sides
			# Снег сверху (от вершины до рваной границы)
			_tri(st, apex, mid[i], mid[j], SNOW, SNOW_SHADE)
			# Хвоя: полоса от границы снега до юбки (два треугольника)
			_tri(st, mid[i], skirt[i], skirt[j], NEEDLE_LIT, NEEDLE)
			_tri(st, mid[i], skirt[j], mid[j], NEEDLE_LIT, NEEDLE)
			# Тёмное «брюхо» яруса снизу — видно, когда смотришь на ель вблизи снизу вверх.
			var c := Vector3(apex.x, y0 + h * 0.18, apex.z)
			_tri(st, skirt[j], skirt[i], c, UNDER, UNDER)


static func _trunk(st: SurfaceTool, r: float, h: float, sides: int) -> void:
	for i in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var b0 := Vector3(cos(a0) * r, -0.3, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, -0.3, sin(a1) * r)
		var t0 := Vector3(cos(a0) * r * 0.6, h, sin(a0) * r * 0.6)
		var t1 := Vector3(cos(a1) * r * 0.6, h, sin(a1) * r * 0.6)
		_tri(st, b0, t0, b1, BARK, BARK)
		_tri(st, b1, t0, t1, BARK, BARK)


## Сухостой: голый ствол с обломанными сучьями и снегом на развилках.
static func _dead(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	_trunk(st, 0.14, 5.2, 5)
	for i in range(7):
		var y := rng.randf_range(1.6, 4.8)
		var a := rng.randf() * TAU
		var l := rng.randf_range(0.5, 1.2) * (1.2 - y / 6.0)
		var base := Vector3(0, y, 0)
		var tip := Vector3(cos(a) * l, y - rng.randf_range(0.1, 0.4), sin(a) * l)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.05
		_tri(st, base - side, tip, base + side + Vector3(0, 0.08, 0), BARK, BARK)
		_tri(st, base + side, tip, base - side + Vector3(0, 0.08, 0), BARK, BARK)
		# Снег на сучке
		_tri(st, base + Vector3(0, 0.09, 0), tip + Vector3(0, 0.03, 0), base + side * 0.6 + Vector3(0, 0.1, 0), SNOW_SHADE, SNOW)


## Треугольник с цветом: c_top — для вершины выше остальных (свет сверху), c_low — для прочих.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, c_top: Color, c_low: Color) -> void:
	var top := maxf(a.y, maxf(b.y, c.y))
	for v: Vector3 in [a, b, c]:
		st.set_color(c_top if v.y >= top - 0.001 else c_low)
		st.add_vertex(v)
