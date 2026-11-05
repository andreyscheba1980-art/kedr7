class_name Terrain
extends RefCounted
## Рельеф большой карты: квадрат 1 км вокруг станции.
##
## Двор станции (радиус FLAT_R) — ровно на нуле: всё, что было построено раньше, стоит где стояло.
## Дальше — пологие сопки и распадки, у краёв карты — хребты, за которые не пройти.
## Зимники и площадки (лесоучасток, вышка, буровая) вписаны в рельеф: дорога идёт по сглаженной
## отметке, площадка — ровная. Высоты считаются один раз за запуск игры в сетку с шагом 4 м,
## меши и коллизия кусков 64×64 м тоже кешируются — смена ночь/день их не пересобирает.

const CENTER := Vector2(20.0, -5.0)
const HALF := 512.0
const STEP := 4.0
const N := 257                     ## вершин по стороне (256 клеток × 4 м = 1024 м)
const CHUNK := 16                  ## клеток в куске (64 м)
const FLAT_R := 145.0              ## двор станции — ровный
const BLEND := 75.0
const ROAD_HALF := 2.6             ## полуширина зимника: узкая просека, «Буран» и ГТ-Т проходят
const ROAD_SHOULDER := 10.0

## Зимники (x, z). Первая точка — на сети троп станции.
const ROADS := {
	&"zimnik": [Vector2(-62, -88), Vector2(-84, -112), Vector2(-110, -150), Vector2(-138, -182), Vector2(-170, -210),
		Vector2(-205, -238), Vector2(-250, -262), Vector2(-310, -290), Vector2(-380, -318), Vector2(-450, -342), Vector2(-500, -356)],
	&"tower": [Vector2(72, -62), Vector2(96, -92), Vector2(128, -132), Vector2(168, -176), Vector2(214, -228), Vector2(258, -276), Vector2(292, -312)],
	## Старая заросшая просека от зимника к лесосеке — к капищу (на схеме — только когда пеленги сошлись)
	&"old_cut": [Vector2(-100, 4), Vector2(-106, 26), Vector2(-99, 48), Vector2(-95, 60)],
	&"camp": [Vector2(-36, 20), Vector2(-62, 14), Vector2(-100, 4), Vector2(-146, -2), Vector2(-198, 4), Vector2(-256, 14), Vector2(-312, 12), Vector2(-350, 10)],
	&"drill": [Vector2(4, 44), Vector2(8, 84), Vector2(18, 130), Vector2(34, 180), Vector2(52, 230), Vector2(70, 282), Vector2(78, 312)],
}
## Овраги и распадки: ломаная по дну, глубина, полуширина, есть ли ручей подо льдом.
## «Распадок» пересекает дорогу к буровой — там насыпь с бревенчатым мостком (Landscape).
const RAVINES := [
	{"pts": [Vector2(-90, 236), Vector2(-40, 226), Vector2(0, 230), Vector2(49, 222), Vector2(90, 232), Vector2(140, 226), Vector2(200, 238), Vector2(260, 230)], "depth": 11.0, "half": 17.0, "river": true},
	{"pts": [Vector2(-176, -64), Vector2(-214, -84), Vector2(-262, -92), Vector2(-318, -120), Vector2(-372, -150)], "depth": 14.0, "half": 15.0, "river": false},
]
## Площадки: центр, радиус. Высота — отметка рельефа в центре.
const PADS := {
	&"tower": [Vector2(300, -322), 22.0],
	&"camp": [Vector2(-362, 10), 30.0],
	&"drill": [Vector2(80, 324), 24.0],
	&"drop": [Vector2(-90, -121), 9.0],   # где ГТ-Т садится в перемёт (пролог): ~210 м до крыльца
	# Автоматические метеостанции у зимников (наряды на выезд, FieldJobs)
	&"ams1": [Vector2(177, -168), 8.0],
	&"ams2": [Vector2(-197, 16), 8.0],
	&"ams3": [Vector2(45, 176), 8.0],
	&"ams4": [Vector2(-101, -158), 8.0],
	&"source": [Vector2(-95, 70), 13.0],     ## капище-источник (SourceSite)
	&"labaz": [Vector2(-200, -40), 8.0],
	&"numcache": [Vector2(-83.2, -152.0), 4.5],   ## схрон по цифровой станции (NumbersCache)      ## шаманский лабаз (DayPOIs) — поляна в ельнике
}

static var _h := PackedFloat32Array()
static var _clear := PackedByteArray()        ## 1 — дорога/площадка: деревья не ставим
static var _near := PackedByteArray()         ## 1 — в 10 м от зимника: лес стеной
static var _road_h: Dictionary = {}           ## road → PackedFloat32Array отметок по точкам ломаной (после сглаживания)
static var _chunks: Array = []                ## [{"mesh": ArrayMesh, "shape": ConcavePolygonShape3D, "pos": Vector3}]
static var _noise: FastNoiseLite
static var _material: ShaderMaterial


# --- Высоты -----------------------------------------------------------------------

static func ready() -> bool:
	return _h.size() == N * N


static func ensure() -> void:
	if ready():
		return
	var t0 := Time.get_ticks_msec()
	_noise = FastNoiseLite.new()
	_noise.seed = 1983
	_noise.frequency = 0.0042
	_noise.fractal_octaves = 3
	_noise.fractal_gain = 0.45
	var detail := FastNoiseLite.new()
	detail.seed = 77
	detail.frequency = 0.02
	_h.resize(N * N)
	_clear.resize(N * N)
	_clear.fill(0)
	_near.resize(N * N)
	_near.fill(0)
	for j in N:
		for i in N:
			var x := CENTER.x - HALF + i * STEP
			var z := CENTER.y - HALF + j * STEP
			_h[j * N + i] = _base(x, z, detail)
	for road: StringName in ROADS:
		_stamp_road(road)
	for pad: StringName in PADS:
		_stamp_pad(PADS[pad][0], PADS[pad][1])
	for j in N:
		for i in N:
			var p := Vector2(CENTER.x - HALF + i * STEP, CENTER.y - HALF + j * STEP)
			for rv: Dictionary in RAVINES:
				if rv["river"] and ravine_dist(rv, p) < 4.0:
					_clear[j * N + i] = 1   # русло подо льдом — ели не ставим
	print("[terrain] сетка %d×%d за %d мс" % [N, N, Time.get_ticks_msec() - t0])


## Рельеф без дорог: сопки + хребты у краёв, двор — ровный.
static func _base(x: float, z: float, detail: FastNoiseLite) -> float:
	var d := Vector2(x, z).distance_to(CENTER)
	var w := smoothstep(FLAT_R, FLAT_R + BLEND, d)
	if w <= 0.0:
		return 0.0
	var n := _noise.get_noise_2d(x, z)
	var hills := (n * 0.5 + 0.5) * 30.0 + detail.get_noise_2d(x, z) * 1.6
	# Гребни сопок: острый перегиб там, где шум переходит через ноль — каменистые увалы, а не блин
	hills += pow(1.0 - absf(_noise.get_noise_2d(z * 0.7 + 400.0, x * 0.7)), 4.0) * 12.0
	hills -= _ravine_cut(x, z)
	var edge := maxf(absf(x - CENTER.x), absf(z - CENTER.y))
	var ridge := smoothstep(400.0, 505.0, edge) * 46.0
	return (hills + ridge) * w


## Насколько опустить рельеф оврагом в точке: гладкий профиль «корыта» с крутыми бортами.
static func _ravine_cut(x: float, z: float) -> float:
	var cut := 0.0
	for rv: Dictionary in RAVINES:
		var d := ravine_dist(rv, Vector2(x, z))
		var half: float = rv["half"]
		if d < half:
			var t := d / half
			cut = maxf(cut, float(rv["depth"]) * pow(1.0 - t * t, 1.6))
	return cut


static func ravine_dist(rv: Dictionary, p: Vector2) -> float:
	var pts: Array = rv["pts"]
	var best := INF
	for k in range(pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func _idx(i: int, j: int) -> int:
	return clampi(j, 0, N - 1) * N + clampi(i, 0, N - 1)


static func _grid_xy(x: float, z: float) -> Vector2:
	return Vector2((x - (CENTER.x - HALF)) / STEP, (z - (CENTER.y - HALF)) / STEP)


## Отметка в точке (билинейно по сетке).
static func height(x: float, z: float) -> float:
	if not ready():
		return 0.0
	var g := _grid_xy(x, z)
	var i := clampi(floori(g.x), 0, N - 2)
	var j := clampi(floori(g.y), 0, N - 2)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fz := clampf(g.y - j, 0.0, 1.0)
	var a := lerpf(_h[j * N + i], _h[j * N + i + 1], fx)
	var b := lerpf(_h[(j + 1) * N + i], _h[(j + 1) * N + i + 1], fx)
	return lerpf(a, b, fz)


static func at(p: Vector3) -> Vector3:
	return Vector3(p.x, height(p.x, p.z), p.z)


## Нормаль поверхности (для наклона «Бурана» и деревьев).
static func normal(x: float, z: float) -> Vector3:
	var e := 1.5
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## Свободно ли место под дерево (не дорога и не площадка).
static func is_clear(x: float, z: float) -> bool:
	var g := _grid_xy(x, z)
	return _clear[_idx(roundi(g.x), roundi(g.y))] == 0


## Постройки за квадратом лесного двора (корпус с ангаром): дальний лес сюда не сажаем —
## ели росли прямо внутри ангара.
const BUILDINGS: Array[Rect2] = [Rect2(84.0, -50.0, 54.0, 36.0)]


static func _in_buildings(x: float, z: float) -> bool:
	for r: Rect2 in BUILDINGS:
		if r.has_point(Vector2(x, z)):
			return true
	return false


static func in_map(x: float, z: float) -> bool:
	return absf(x - CENTER.x) < HALF - 14.0 and absf(z - CENTER.y) < HALF - 14.0


# --- Дороги и площадки -------------------------------------------------------------

## Точки ломаной дороги с отметками (после того как сетка готова).
static func road_points(road: StringName, spacing := 4.0) -> PackedVector3Array:
	var pts: Array = ROADS[road]
	var out := PackedVector3Array()
	for k in range(pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := maxi(1, ceili(a.distance_to(b) / spacing))
		for s in n:
			var p := a.lerp(b, float(s) / n)
			out.append(Vector3(p.x, height(p.x, p.y), p.y))
	var last: Vector2 = pts[pts.size() - 1]
	out.append(Vector3(last.x, height(last.x, last.y), last.y))
	return out


static func _stamp_road(road: StringName) -> void:
	var pts: Array = ROADS[road]
	# Профиль дороги: отметки по пути каждые 4 м, сглаженные окном — дорога не повторяет каждый бугор.
	var dense: Array[Vector2] = []
	for k in range(pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := maxi(1, ceili(a.distance_to(b) / STEP))
		for s in n:
			dense.append(a.lerp(b, float(s) / n))
	dense.append(pts[pts.size() - 1])
	var raw := PackedFloat32Array()
	for p in dense:
		raw.append(_sample_grid(p.x, p.y))
	var prof := PackedFloat32Array()
	prof.resize(raw.size())
	var win := 7
	for k in raw.size():
		var s := 0.0
		var c := 0
		for o in range(-win, win + 1):
			var q := clampi(k + o, 0, raw.size() - 1)
			s += raw[q]
			c += 1
		prof[k] = s / c
	_road_h[road] = prof
	# Впечатываем: в полосе дороги — профиль, на обочине — плавный переход к рельефу.
	var reach := ROAD_HALF + ROAD_SHOULDER
	var weights := PackedFloat32Array()
	weights.resize(N * N)
	weights.fill(0.0)
	var targets := PackedFloat32Array()
	targets.resize(N * N)
	for k in range(dense.size() - 1):
		var a := dense[k]
		var b := dense[k + 1]
		var lo := _grid_xy(minf(a.x, b.x) - reach, minf(a.y, b.y) - reach)
		var hi := _grid_xy(maxf(a.x, b.x) + reach, maxf(a.y, b.y) + reach)
		for j in range(maxi(floori(lo.y), 0), mini(ceili(hi.y), N - 1) + 1):
			for i in range(maxi(floori(lo.x), 0), mini(ceili(hi.x), N - 1) + 1):
				var x := CENTER.x - HALF + i * STEP
				var z := CENTER.y - HALF + j * STEP
				var ab := b - a
				var t := clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				var d := Vector2(x, z).distance_to(a + ab * t)
				if d > reach:
					continue
				var w := 1.0 - smoothstep(ROAD_HALF, reach, d)
				var id := j * N + i
				if w > weights[id]:
					weights[id] = w
					targets[id] = lerpf(prof[k], prof[k + 1], t)
				if d < ROAD_HALF + 2.4:
					_clear[id] = 1
				elif d < 10.0:
					_near[id] = 1
	for id in weights.size():
		if weights[id] > 0.0:
			_h[id] = lerpf(_h[id], targets[id], weights[id])


static func _sample_grid(x: float, z: float) -> float:
	var g := _grid_xy(x, z)
	return _h[_idx(roundi(g.x), roundi(g.y))]


static func _stamp_pad(c: Vector2, r: float) -> void:
	var target := _sample_grid(c.x, c.y)
	var reach := r + 14.0
	var lo := _grid_xy(c.x - reach, c.y - reach)
	var hi := _grid_xy(c.x + reach, c.y + reach)
	for j in range(maxi(floori(lo.y), 0), mini(ceili(hi.y), N - 1) + 1):
		for i in range(maxi(floori(lo.x), 0), mini(ceili(hi.x), N - 1) + 1):
			var x := CENTER.x - HALF + i * STEP
			var z := CENTER.y - HALF + j * STEP
			var d := Vector2(x, z).distance_to(c)
			if d > reach:
				continue
			var w := 1.0 - smoothstep(r, reach, d)
			var id := j * N + i
			_h[id] = lerpf(_h[id], target, w)
			if d < r:
				_clear[id] = 1


static func pad_pos(pad: StringName) -> Vector3:
	var c: Vector2 = PADS[pad][0]
	return Vector3(c.x, height(c.x, c.y), c.y)


# --- Меш и коллизия ----------------------------------------------------------------

static func _build_chunks() -> void:
	if not _chunks.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	var per := (N - 1) / CHUNK
	for cj in per:
		for ci in per:
			var i0 := ci * CHUNK
			var j0 := cj * CHUNK
			var origin := Vector3(CENTER.x - HALF + i0 * STEP, 0.0, CENTER.y - HALF + j0 * STEP)
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var flat := true
			for j in CHUNK + 1:
				for i in CHUNK + 1:
					var gi := i0 + i
					var gj := j0 + j
					var y := _h[_idx(gi, gj)]
					if absf(y) > 0.001:
						flat = false
					verts.append(Vector3(i * STEP, y, j * STEP))
					var hx := _h[_idx(gi + 1, gj)] - _h[_idx(gi - 1, gj)]
					var hz := _h[_idx(gi, gj + 1)] - _h[_idx(gi, gj - 1)]
					norms.append(Vector3(-hx, 2.0 * STEP, -hz).normalized())
			var idx := PackedInt32Array()
			var faces := PackedVector3Array()
			var row := CHUNK + 1
			for j in CHUNK:
				for i in CHUNK:
					var a := j * row + i
					var b := a + 1
					var c := a + row
					var d := c + 1
					idx.append_array([a, b, c, b, d, c])
					faces.append_array([verts[a], verts[b], verts[c], verts[b], verts[d], verts[c]])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			_chunks.append({"mesh": mesh, "shape": shape, "pos": origin, "flat": flat})
	print("[terrain] %d кусков за %d мс" % [_chunks.size(), Time.get_ticks_msec() - t0])


static func material() -> ShaderMaterial:
	if _material != null:
		return _material
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/shaders/snow_ground.gdshader")
	var base_m := Palette.m(&"snow") as ShaderMaterial
	_material.set_shader_parameter(&"albedo", base_m.get_shader_parameter(&"albedo"))
	_material.set_shader_parameter(&"tex", base_m.get_shader_parameter(&"tex"))
	_material.set_shader_parameter(&"tex_scale", base_m.get_shader_parameter(&"tex_scale"))
	return _material


## Земля всей карты: куски с отсечением по дальности и коллизией.
static func build(parent: Node3D, far: float) -> void:
	ensure()
	_build_chunks()
	var mat := material()
	var bodies := Node3D.new()
	bodies.name = "TerrainBodies"
	parent.add_child(bodies)
	for c: Dictionary in _chunks:
		var mi := MeshInstance3D.new()
		mi.mesh = c["mesh"]
		mi.material_override = mat
		mi.position = c["pos"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Двор виден всегда; сопки — пока не съел туман
		if not c["flat"]:
			mi.visibility_range_end = far + 60.0
			mi.visibility_range_end_margin = 12.0
		parent.add_child(mi)
		var body := StaticBody3D.new()
		body.collision_layer = Geo.LAYER_WORLD
		body.position = c["pos"]
		var cs := CollisionShape3D.new()
		cs.shape = c["shape"]
		body.add_child(cs)
		bodies.add_child(body)


# --- Дальний лес ------------------------------------------------------------------

## Лес за пределами двора: куртины, распадки, редколесье на хребтах. Деревья у самой дороги —
## стеной, чтобы зимник был просекой. Коллизии — напрямую в физическом сервере (без узлов).
static func _near_pad(x: float, z: float) -> bool:
	for pad: StringName in PADS:
		var pp: Vector3 = pad_pos(pad)
		if Vector2(x, z).distance_to(Vector2(pp.x, pp.z)) < float(PADS[pad][1]) + 6.0:
			return true
	return false


static func build_forest(parent: Node3D, far: float, inner_center: Vector3, inner_half: float) -> void:
	ensure()
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var groves := FastNoiseLite.new()
	groves.seed = 91
	groves.frequency = 0.012
	var glades := FastNoiseLite.new()
	glades.seed = 92
	glades.frequency = 0.03
	var spacing := 4.4 / sqrt(maxf(Settings.detail(), 0.4))
	var cells: Dictionary = {}       ## Vector2i → [Array[Transform3D] × 4 вида]
	var cell_size := 64.0
	var shapes: Dictionary = {}      ## Vector2i → Array[Transform3D] (стволы)
	var place := func(px: float, pz: float, forced: bool) -> void:
		var h := height(px, pz)
		var s := rng.randf_range(1.0, 1.9)
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), deg_to_rad(rng.randf_range(0.0, 3.5)))
		var b := tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		var t := Transform3D(b, Vector3(px, h - 0.15, pz))
		var roll := rng.randf()
		var v := 0 if roll < 0.55 else 1 if roll < 0.86 else 2 if roll < 0.95 else 3
		if forced and roll < 0.2:
			v = 1
		var ck := Vector2i(floori(px / cell_size), floori(pz / cell_size))
		if not cells.has(ck):
			cells[ck] = [[], [], [], []]
			shapes[ck] = []
		(cells[ck][v] as Array).append(t)
		(shapes[ck] as Array).append(Transform3D(Basis.IDENTITY, Vector3(px, h + 1.5, pz)))
	var x := CENTER.x - HALF + 8.0
	while x < CENTER.x + HALF - 8.0:
		var z := CENTER.y - HALF + 8.0
		while z < CENTER.y + HALF - 8.0:
			var px := x + rng.randf_range(-spacing * 0.45, spacing * 0.45)
			var pz := z + rng.randf_range(-spacing * 0.45, spacing * 0.45)
			z += spacing
			if absf(px - inner_center.x) < inner_half and absf(pz - inner_center.z) < inner_half:
				continue       # двор засажен своим лесом (Yard._build_forest)
			if not is_clear(px, pz) or _in_buildings(px, pz):
				continue
			var h := height(px, pz)
			var g := _grid_xy(px, pz)
			var by_road := _near[_idx(roundi(g.x), roundi(g.y))] == 1
			var dens := smoothstep(-0.35, 0.25, groves.get_noise_2d(px, pz))
			if glades.get_noise_2d(px, pz) > 0.5:
				dens *= 0.15
			if by_road:
				dens = 1.0                       # у зимника лес стеной — просека
			if h > 38.0:
				dens *= 0.35                     # голые гребни хребтов
			if rng.randf() > dens:
				continue
			place.call(px, pz, false)
		x += spacing
	# Стены просеки: два ряда елей вдоль каждого зимника, вне двора и площадок.
	for road: StringName in ROADS:
		var pts := road_points(road, 2.6)
		for k in range(1, pts.size() - 1):
			var p := pts[k]
			if Vector2(p.x, p.z).distance_to(CENTER) < FLAT_R + 6.0:
				continue
			var dir := pts[k + 1] - pts[k - 1]
			dir.y = 0.0
			dir = dir.normalized()
			var side := Vector3(-dir.z, 0, dir.x)
			for sgn: float in [-1.0, 1.0]:
				for band: Vector2 in [Vector2(5.3, 8.5), Vector2(8.5, 12.0)]:
					if rng.randf() < 0.18:
						continue
					var q: Vector3 = p + side * sgn * rng.randf_range(band.x, band.y) + dir * rng.randf_range(-1.0, 1.0)
					if _near_pad(q.x, q.z) or _in_buildings(q.x, q.z):
						continue
					place.call(q.x, q.z, true)
	var count := 0
	for ck: Vector2i in cells:
		var cc := Vector3((ck.x + 0.5) * cell_size, 0.0, (ck.y + 0.5) * cell_size)
		for v in 4:
			var list: Array = cells[ck][v]
			if list.is_empty():
				continue
			count += list.size()
			for t: Transform3D in list:
				SpruceNear.register(v, t)
			for lod in 1:
				var lm: ArrayMesh = SpruceMesh.lod_far(v, SpruceMesh.NEAR_RANGE)
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = lm
				mm.instance_count = list.size()
				for k in list.size():
					var t: Transform3D = list[k]
					mm.set_instance_transform(k, Transform3D(t.basis, t.origin - cc))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.position = cc
				mmi.visibility_range_end = far + 40.0
				mmi.visibility_range_end_margin = 8.0
				mmi.layers = Station.LAYER_OUT   # лес — только «снаружи»: лампы в доме не рисуют его в свои тени
				parent.add_child(mmi)
	# Стволы: один статический «корпус» на клетку, формы добавлены в сервер напрямую.
	var trunk := PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(trunk, {"radius": 0.38, "height": 3.0})
	var space := parent.get_world_3d().space
	var rids: Array[RID] = [trunk]
	for ck: Vector2i in shapes:
		var body := PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body, Geo.LAYER_WORLD)
		PhysicsServer3D.body_set_collision_mask(body, 0)
		for t: Transform3D in shapes[ck]:
			PhysicsServer3D.body_add_shape(body, trunk, t)
		PhysicsServer3D.body_set_space(body, space)
		rids.append(body)
	parent.tree_exiting.connect(func() -> void:
		for k in range(rids.size() - 1, -1, -1):
			PhysicsServer3D.free_rid(rids[k]))
	print("[terrain] дальний лес: %d елей за %d мс" % [count, Time.get_ticks_msec() - t0])


# --- Полотно дорог -----------------------------------------------------------------

## Укатанный снег зимников (чуть темнее и с колеёй) и вешки со световозвращателями.
static func build_roads(parent: Node3D) -> void:
	ensure()
	var mat := material().duplicate() as ShaderMaterial
	var base: Color = mat.get_shader_parameter(&"albedo")
	mat.set_shader_parameter(&"albedo", Color(base.r * 0.82, base.g * 0.84, base.b * 0.9, 1.0))
	mat.set_shader_parameter(&"sastrugi", 0.12)
	for road: StringName in ROADS:
		var pts := road_points(road, 3.0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in pts.size():
			var p := pts[k]
			var dir := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)])
			dir.y = 0.0
			dir = dir.normalized()
			var side := Vector3(-dir.z, 0, dir.x) * (ROAD_HALF - 0.4)
			var l := at(p - side) + Vector3(0, 0.04, 0)
			var r := at(p + side) + Vector3(0, 0.04, 0)
			if k > 0:
				for v in [prev_l, prev_r, l, prev_r, r, l]:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			prev_l = l
			prev_r = r
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		# Вешки: через 24 м попеременно по сторонам, вне двора (во дворе — свои леера)
		var acc := 0.0
		var flip := 1.0
		for k in range(1, pts.size()):
			acc += pts[k].distance_to(pts[k - 1])
			if acc < 24.0:
				continue
			acc = 0.0
			flip = -flip
			var p := pts[k]
			if Vector2(p.x, p.z).distance_to(CENTER) < FLAT_R - 20.0:
				continue
			var dir := pts[mini(k + 1, pts.size() - 1)] - pts[k - 1]
			dir.y = 0.0
			dir = dir.normalized()
			var mpos := at(p + Vector3(-dir.z, 0, dir.x) * (ROAD_HALF + 0.6) * flip)
			var marker := _road_pole()
			marker.position = mpos
			marker.rotation.y = atan2(dir.x, dir.z) + (0.0 if flip > 0.0 else PI)
			parent.add_child(marker)


## Вешка зимника: полосатый шест (чёрно-белый) со световозвращателем.
static func _road_pole() -> Node3D:
	var root := Node3D.new()
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.86, 0.86, 0.84)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.06, 0.06, 0.06)
	for i in 6:
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.04
		cyl.height = 0.3
		cyl.radial_segments = 6
		seg.mesh = cyl
		seg.material_override = white if i % 2 == 0 else black
		seg.position.y = 0.15 + i * 0.3
		root.add_child(seg)
	var refl := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.09, 0.16, 0.012)
	refl.mesh = bx
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.75, 0.05, 0.03)
	rm.emission_enabled = true
	rm.emission = Color(0.6, 0.03, 0.02)
	rm.emission_energy_multiplier = 0.6
	refl.material_override = rm
	refl.position = Vector3(0, 1.55, 0.045)
	root.add_child(refl)
	return root
