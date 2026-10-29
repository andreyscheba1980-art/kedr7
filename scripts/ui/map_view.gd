class_name MapView
extends Control
## Бумажная схема станции (M). Леера, постройки и подписи — без точки «вы здесь».

signal closed

const PAD := 60.0

var _bounds := Rect2(-45, -62, 150, 100)    ## мировые XZ, которые помещаются на лист (пересчёт по леерам)


var _paper: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout.call_deferred()


## Фактура листа поверх нарисованного (умножением: подписи и карандаш — «на бумаге»).
func _layout() -> void:
	var sheet := Rect2(size * 0.5 - Vector2(470, 330), Vector2(940, 660))
	if _paper == null:
		_paper = UiStyle.paper_mul(self, sheet, 4.4, 1.0)
	_paper.position = sheet.position
	_paper.size = sheet.size
	(_paper.material as ShaderMaterial).set_shader_parameter(&"px_size", sheet.size)
	queue_redraw()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var sheet := Rect2(size * 0.5 - Vector2(470, 330), Vector2(940, 660))
	draw_rect(sheet, UiKit.PAPER)
	draw_rect(sheet.grow(-10), Color(0.4, 0.33, 0.25, 0.5), false, 2.0)
	var font := UiKit.theme().default_font
	var ink := UiKit.INK
	draw_string(font, sheet.position + Vector2(30, 46), Loc.t(&"map.title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(font, sheet.position + Vector2(30, sheet.size.y - 24), Loc.t(&"map.close"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ink, 0.6))

	var area := Rect2(sheet.position + Vector2(PAD, PAD + 20), sheet.size - Vector2(PAD * 2, PAD * 2 + 20))
	if Game.yard == null:
		return
	_fit_bounds(area.size.x / area.size.y)
	var to_map := func(p: Vector3) -> Vector2:
		var u := (p.x - _bounds.position.x) / _bounds.size.x
		var v := (p.z - _bounds.position.y) / _bounds.size.y
		return area.position + Vector2(u, v) * area.size

	# Лес — штриховка по краям.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(160):
		var p := area.position + Vector2(rng.randf(), rng.randf()) * area.size
		draw_line(p, p + Vector2(4, -9), Color(0.2, 0.3, 0.2, 0.35), 1.5)
		draw_line(p, p + Vector2(-4, -9), Color(0.2, 0.3, 0.2, 0.35), 1.5)

	# Леера — цветом флажков своего маршрута (общий ствол от крыльца — тёмным карандашом).
	var legend: Array[Dictionary] = []
	for line in Game.yard.paths:
		var route: Dictionary = Game.yard.route_of(line)
		var col: Color = route.get("color", Color(0.3, 0.26, 0.22))
		if not route.is_empty() and not legend.has(route):
			legend.append(route)
		var ink_col := col.darkened(0.15) if col.get_luminance() > 0.25 else col.lightened(0.1)
		if col.get_luminance() > 0.8:
			ink_col = Color(0.55, 0.55, 0.52)   # белые флажки на бумаге — серым
		for i in range(line.size() - 1):
			var a: Vector2 = to_map.call(line[i])
			var b: Vector2 = to_map.call(line[i + 1])
			draw_dashed_line(a, b, ink_col, 3.0, 7.0)
	_draw_efir(area, to_map, font)   # под легендой: её подложка не даёт подписям слипаться
	# Легенда: цвет флажка → куда ведёт
	var lp := sheet.position + Vector2(sheet.size.x - 250, sheet.size.y - 40 - legend.size() * 22)
	if not legend.is_empty():
		var box := Rect2(lp + Vector2(-12, -30), Vector2(240, 34 + legend.size() * 22))
		draw_rect(box, UiKit.PAPER)                       # легенда на своей подложке — не сливается с лесом и подписями
		draw_rect(box, Color(ink, 0.5), false, 1.5)
		draw_string(font, lp + Vector2(0, -8), Loc.t(&"map.legend"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	for k in range(legend.size()):
		var r: Dictionary = legend[k]
		var y := lp.y + 8 + k * 22
		var fc: Color = r["color"]
		for poly: PackedVector2Array in flag_shape(int(r.get("shape", 0)), Vector2(lp.x, y)):
			draw_colored_polygon(poly, fc)
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(ink, 0.6), 1.0)
		if int(r.get("shape", 0)) == 4:
			draw_rect(Rect2(lp.x, y + 4.5, 22, 3), Color(0.95, 0.95, 0.92))
		draw_string(font, Vector2(lp.x + 32, y + 12), Loc.t(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)

	var region := FarSites.known()
	if region:
		# Зимники — сплошным двойным карандашом
		for road: StringName in Terrain.ROADS:
			if road == &"old_cut" and not (SourceSite.found() or FieldJobs.bearing_count() >= 3 or Efir.cross(&"numbers").size() == 2 or Efir.cross(&"otzvuk").size() == 2):
				continue
			var pts := Terrain.road_points(road, 12.0)
			for i in range(pts.size() - 1):
				var a: Vector2 = to_map.call(pts[i])
				var b: Vector2 = to_map.call(pts[i + 1])
				draw_line(a, b, Color(ink, 0.75), 3.0)
		draw_string(font, sheet.position + Vector2(30, 70), Loc.t(&"map.region_hint"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ink, 0.6))
		# Пеленги на сигнал 03:10 — карандашные лучи от АМС и вышки, круг поиска там, где сходятся
		var px_per_m := area.size.x / _bounds.size.x
		var graphite := Color(0.22, 0.2, 0.2, 0.75)
		for s: String in FieldJobs.BEARING_SITES:
			if not FieldJobs.has_bearing(s):
				continue
			var from := FieldJobs.site_pos(s)
			var a := FieldJobs.bearing_angle(s)
			var dist := Vector2(from.x, from.z).distance_to(Vector2(Terrain.pad_pos(&"source").x, Terrain.pad_pos(&"source").z))
			var to := from + Vector3(sin(a), 0, -cos(a)) * dist * 1.3
			draw_dashed_line(to_map.call(from), to_map.call(to), graphite, 1.6, 10.0)
		var zone := FieldJobs.search_zone()
		if not zone.is_empty() and not SourceSite.found():
			var zc: Vector2 = to_map.call(zone[0])
			draw_arc(zc, float(zone[1]) * px_per_m, 0.0, TAU, 40, Color(0.72, 0.1, 0.08), 2.0)
			draw_string(font, zc + Vector2(-6, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.62, 0.08, 0.06))
	for site: Dictionary in Game.yard.map_sites():
		if region and not site.get("far", false) and site["label"] != &"map.house":
			continue
		var c: Vector2 = to_map.call(site["pos"])
		var r: Vector2 = site.get("size", Vector2(14, 10))
		draw_rect(Rect2(c - r * 0.5, r), ink, false, 2.0)
		var lab_col := ink
		if site.get("job", false):
			# Наряд на выезд — обведено красным карандашом (у зонда — круг поиска в метрах)
			var cr := maxf(r.x, r.y) * 0.5 + 9.0
			if site.has("circle"):
				cr = float(site["circle"]) * area.size.x / _bounds.size.x
			draw_arc(c, cr, 0.0, TAU, 28, Color(0.72, 0.1, 0.08), 2.5)
			lab_col = Color(0.62, 0.08, 0.06)
		draw_string(font, c + Vector2(r.x * 0.5 + 6, 5), Loc.t(site["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, lab_col)

	# Стрелка севера.
	var n := sheet.position + Vector2(sheet.size.x - 70, 70)
	draw_line(n + Vector2(0, 26), n + Vector2(0, -26), ink, 2.0)
	draw_line(n + Vector2(0, -26), n + Vector2(-7, -12), ink, 2.0)
	draw_line(n + Vector2(0, -26), n + Vector2(7, -12), ink, 2.0)
	draw_string(font, n + Vector2(-6, -34), Loc.t(&"map.north"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)


## Эфир: пеленги дежурного синим карандашом (рамка не знает «туда/оттуда» — линия в обе стороны),
## где сошлись два — красный квадрат с частотой.
func _draw_efir(area: Rect2, to_map: Callable, font: Font) -> void:
	var blue := Color(0.12, 0.22, 0.55, 0.75)
	var red := Color(0.72, 0.1, 0.08)
	for id: StringName in Efir.df_ids():
		var f := int(float(Signals.get_def(id).get("freq", 0.0)))
		for point: StringName in Efir.POINTS:
			var az := Efir.df(id, point)
			if az < 0.0:
				continue
			var p: Vector3 = Efir.POINTS[point]
			var d := Efir.dir_of(az)
			var a: Vector2 = to_map.call(p - Vector3(d.x, 0, d.y) * 900.0)
			var b: Vector2 = to_map.call(p + Vector3(d.x, 0, d.y) * 900.0)
			var seg := _clip(a, b, area)
			if seg.is_empty():
				continue
			draw_dashed_line(seg[0], seg[1], blue, 1.4, 6.0)
			var at: Vector2 = to_map.call(p)
			draw_string(UiStyle.hand_font(), (at + (seg[1] - at).normalized() * 70.0).clamp(area.position, area.end - Vector2(60, 0)), str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, blue)
		var cr := Efir.cross(id)
		if cr.size() == 2:
			var c: Vector2 = to_map.call(cr[0])
			var rr := float(cr[1]) * area.size.x / _bounds.size.x
			draw_rect(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0), red, false, 2.2)
			draw_string(UiStyle.hand_font(), c + Vector2(rr + 4, -rr + 16), Loc.t(&"df.map_square", [f]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, red)


## Отрезок, обрезанный по прямоугольнику листа ([] — весь снаружи).
static func _clip(a: Vector2, b: Vector2, r: Rect2) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for e: Array in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var pp: float = e[0]
		var q: float = e[1]
		if absf(pp) < 0.0001:
			if q < 0.0:
				return []
			continue
		var t := q / pp
		if pp < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return []
	return [a + d * t0, a + d * t1]


## Значок флажка той же формы, что на леере (для тех, кто путает цвета).
static func flag_shape(shape: int, o: Vector2) -> Array[PackedVector2Array]:
	match shape:
		1, 4:
			return [PackedVector2Array([o, o + Vector2(22, 0), o + Vector2(22, 12), o + Vector2(0, 12)])]
		2:
			return [PackedVector2Array([o, o + Vector2(22, 0), o + Vector2(14, 6), o + Vector2(22, 12), o + Vector2(0, 12)])]
		3:
			return [PackedVector2Array([o + Vector2(0, -2), o + Vector2(16, 2), o + Vector2(0, 6)]),
				PackedVector2Array([o + Vector2(0, 7), o + Vector2(16, 11), o + Vector2(0, 15)])]
		_:
			return [PackedVector2Array([o, o + Vector2(22, 6), o + Vector2(0, 12)])]


## Схема растёт вместе с картой: охватываем все леера и постройки, сохраняя пропорции листа.
func _fit_bounds(aspect: float) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for line in Game.yard.paths:
		for p in line:
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	for site: Dictionary in Game.yard.map_sites():
		var c: Vector3 = site["pos"]
		lo = lo.min(Vector2(c.x, c.z))
		hi = hi.max(Vector2(c.x, c.z))
	for id: StringName in Efir.df_ids():
		var cr := Efir.cross(id)
		if cr.size() == 2:
			lo = lo.min(Vector2(cr[0].x, cr[0].z) - Vector2(cr[1], cr[1]))
			hi = hi.max(Vector2(cr[0].x, cr[0].z) + Vector2(cr[1], cr[1]))
	var pad := Vector2(12, 12)
	if FarSites.known():
		for road: StringName in Terrain.ROADS:
			for p in Terrain.road_points(road, 24.0):
				lo = lo.min(Vector2(p.x, p.z))
				hi = hi.max(Vector2(p.x, p.z))
		pad = Vector2(40, 40)
	lo -= pad
	hi += pad + Vector2(10, 0)
	var sz := hi - lo
	if sz.x / sz.y < aspect:
		var w := sz.y * aspect
		lo.x -= (w - sz.x) * 0.5
		sz.x = w
	else:
		var h := sz.x / aspect
		lo.y -= (h - sz.y) * 0.5
		sz.y = h
	_bounds = Rect2(lo, sz)
