class_name HouseDecor
extends RefCounted
## Обжитой дом дежурного, январь 1983: настенная карта района, календарь, график дежурств, ковёр над кроватью,
## фото родителей, вымпел, плакат по ТБ, бельё над печью, тулуп в сенях.
## Бумажные вещи рисуются один раз в маленький SubViewport (2D) и висят на стене текстурой — одна плоскость
## на вещь, без десятков Label3D. Некоторые вещи меняются по ночам — тихо, без субтитров.

const FIRST_DAY := 14          ## первая смена Мальцева — 14 ноября (пролог); ночь N — вечер 14 + N - 1
const NOV_FIRST_COL := 1       ## 1 ноября 1983 — вторник (неделя с понедельника = 0, вторник = 1)


static func build(st: Station) -> void:
	_wall_map(st)
	_calendar(st)
	_roster(st)
	_rug(st)
	_family_photo(st)
	_pennant(st)
	_safety_poster(st)
	_clothesline(st)
	_coat(st)
	_beams(st)
	_lamps(st)


# --- Общие помощники ------------------------------------------------------------

## Бумага на стене: SubViewport рисуется один раз, его текстура — на плоскости. normal — куда смотрит лист.
static func _paper(st: Station, px: Vector2i, size_m: Vector2, pos: Vector3, normal: Vector3, draw: Callable,
		frame := true, transparent := false) -> MeshInstance3D:
	var vp := SubViewport.new()
	vp.size = px
	vp.disable_3d = true
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(px)
	c.draw.connect(func() -> void: draw.call(c))
	c.add_to_group(&"lang_redraw")   # смена языка — перерисовать бумагу (карта, календарь, плакаты)
	vp.add_child(c)
	st.add_child(vp)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size_m
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st.add_child(mi)
	mi.position = pos + normal * 0.012
	mi.rotation.y = atan2(normal.x, normal.z)
	if frame:
		var fr := Geo.block(st, Vector3(size_m.x + 0.05, size_m.y + 0.05, 0.02), pos, Palette.m(&"dark"), false)
		fr.rotation.y = atan2(normal.x, normal.z)
	return mi


static func _font() -> Font:
	return UiKit.theme().default_font


static func _today() -> int:
	return FIRST_DAY + (Game.phase_index if Game.is_day() else maxi(Game.night - 1, 0))


# --- Настенная карта района (рубка) ---------------------------------------------

## Топокарта над столом: те же леера и постройки, что на схеме [M], карандашом; красный кружок — где пропал
## Семёнов. По [E] открывается схема — карта становится вещью в доме, а не меню.
static func _wall_map(st: Station) -> void:
	var pos := Vector3(6.55, 1.62, -1.89)
	var mi := _paper(st, Vector2i(520, 380), Vector2(1.3, 0.95), pos, Vector3(0, 0, 1), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r, Color(0.84, 0.8, 0.66))
		# Горизонтали и болота — фон топокарты
		var rng := RandomNumberGenerator.new()
		rng.seed = 1983
		for i in range(9):
			var cy := rng.randf_range(20, c.size.y - 20)
			var pts := PackedVector2Array()
			for x in range(0, int(c.size.x) + 20, 20):
				pts.append(Vector2(x, cy + sin(x * 0.02 + i) * 14.0))
			c.draw_polyline(pts, Color(0.62, 0.48, 0.3, 0.45), 1.5)
		for i in range(140):
			var p := Vector2(rng.randf() * c.size.x, rng.randf() * c.size.y)
			c.draw_line(p, p + Vector2(3, -7), Color(0.2, 0.36, 0.22, 0.5), 1.2)
			c.draw_line(p, p + Vector2(-3, -7), Color(0.2, 0.36, 0.22, 0.5), 1.2)
		if Game.yard == null:
			return
		var lo := Vector2(-70, -95)
		var hi := Vector2(85, 45)
		var to := func(p: Vector3) -> Vector2:
			return Vector2((p.x - lo.x) / (hi.x - lo.x), (p.z - lo.y) / (hi.y - lo.y)) * c.size
		for line in Game.yard.paths:
			var col: Color = Game.yard.route_of(line).get("color", Color(0.25, 0.22, 0.2))
			if col.get_luminance() > 0.8:
				col = Color(0.5, 0.5, 0.48)
			for i in range(line.size() - 1):
				c.draw_line(to.call(line[i]), to.call(line[i + 1]), col, 2.5)
		for site: Dictionary in Game.yard.map_sites():
			var sp: Vector2 = to.call(site["pos"])
			c.draw_rect(Rect2(sp - Vector2(6, 5), Vector2(12, 10)), Color(0.15, 0.12, 0.12), false, 2.0)
			c.draw_string(_font(), sp + Vector2(9, 5), Loc.t(site["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.15, 0.12, 0.12))
		# Карандашная пометка Семёнова: кружок за мачтой и вопрос
		var m: Vector2 = to.call(Vector3(30, 0, -80))
		c.draw_arc(m, 16, 0, TAU, 24, Color(0.7, 0.08, 0.06), 2.5)
		c.draw_string(_font(), m + Vector2(18, -8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.08, 0.06))
		c.draw_string(_font(), Vector2(12, 24), Loc.t(&"decor.map_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.12, 0.12))
	)
	mi.name = "WallMap"
	var it := Geo.interactable(st, Vector3(1.3, 0.95, 0.12), pos + Vector3(0, 0, 0.06), null, Loc.t(&"it.wall_map"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"map"))
	it.name = "WallMapIt"


# --- Календарь (рубка) -------------------------------------------------------------

## Табель-календарь «Январь 1983»: прошедшие смены зачёркнуты карандашом.
## С 5-й ночи зачёркнут и завтрашний день — другим, бурым, будто ногтем.
static func _calendar(st: Station) -> void:
	var today := _today()
	var pos := Vector3(5.0, 1.5, 2.09)
	_paper(st, Vector2i(300, 360), Vector2(0.42, 0.5), pos, Vector3(0, 0, -1), func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.93, 0.9, 0.82))
		c.draw_rect(Rect2(0, 0, c.size.x, 70), Color(0.66, 0.1, 0.08))
		c.draw_string(_font(), Vector2(0, 46), Loc.t(&"decor.cal_month"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 30, Color(0.98, 0.94, 0.86))
		var days := ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"] if Settings.language == "ru" else ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
		var cw := c.size.x / 7.0
		var ink := Color(0.15, 0.12, 0.12)
		for k in range(7):
			c.draw_string(_font(), Vector2(k * cw, 98), days[k], HORIZONTAL_ALIGNMENT_CENTER, cw, 15, Color(0.66, 0.1, 0.08) if k >= 5 else ink)
		for d in range(1, 31):
			var idx := d - 1 + NOV_FIRST_COL
			var cell := Vector2((idx % 7) * cw, 112 + (idx / 7) * 42)
			var col := Color(0.66, 0.1, 0.08) if idx % 7 >= 5 else ink
			c.draw_string(_font(), cell + Vector2(0, 28), str(d), HORIZONTAL_ALIGNMENT_CENTER, cw, 20, col)
			# Смены Семёнова (до 12-го включительно) и прошедшие дни зачеркнуты
			var crossed := (d <= 12) or (d >= FIRST_DAY and d < today)
			var foreign := Game.is_night() and Game.night >= 5 and d == today + 1
			if crossed or foreign:
				var pc := Color(0.25, 0.25, 0.3, 0.85) if crossed else Color(0.4, 0.16, 0.08, 0.9)
				c.draw_line(cell + Vector2(8, 6), cell + Vector2(cw - 8, 36), pc, 2.5 if crossed else 3.5)
				c.draw_line(cell + Vector2(cw - 8, 6), cell + Vector2(8, 36), pc, 2.5 if crossed else 3.5)
			if d == today:
				c.draw_arc(cell + Vector2(cw * 0.5, 20), 17, 0, TAU, 20, Color(0.25, 0.25, 0.3, 0.8), 2.0)
	)
	Geo.interactable(st, Vector3(0.42, 0.5, 0.1), pos + Vector3(0, 0, -0.05), null, Loc.t(&"it.calendar"), func(_p: Player) -> void:
		var left := maxi(Phases.LAST_NIGHT - (Game.night if Game.is_night() else Game.phase_index), 0)
		if Game.is_night() and Game.night >= 5:
			Game.hud.subtitle(Loc.t(&"sub.calendar_foreign", [_today() + 1]), 5.0)
		else:
			Game.hud.subtitle(Loc.t(&"sub.calendar", [_today(), left]), 4.0))


# --- График дежурств (рубка) ----------------------------------------------------------

static func _roster(st: Station) -> void:
	var late := Game.is_night() and Game.night >= 5
	var pos := Vector3(4.2, 1.5, -1.89)
	_paper(st, Vector2i(280, 360), Vector2(0.42, 0.54), pos, Vector3(0, 0, 1), func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.9, 0.88, 0.8))
		var ink := Color(0.12, 0.12, 0.2)
		c.draw_string(_font(), Vector2(0, 34), Loc.t(&"decor.roster_title"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 17, ink)
		c.draw_line(Vector2(14, 46), Vector2(c.size.x - 14, 46), ink, 1.5)
		var rows := Loc.t(&"decor.roster_rows").split("\n")
		for i in range(rows.size()):
			var y := 84 + i * 38
			c.draw_string(_font(), Vector2(18, y), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
			c.draw_line(Vector2(14, y + 10), Vector2(c.size.x - 14, y + 10), Color(ink, 0.3), 1.0)
		# Семёнов вычеркнут
		c.draw_line(Vector2(14, 84 - 6), Vector2(c.size.x - 14, 84 - 2), Color(0.1, 0.1, 0.1), 3.0)
		if late:
			# Новая строка — не машинкой, а неровно, бурым: на дату, которой ещё не было
			var y2 := 84 + rows.size() * 38
			c.draw_string(_font(), Vector2(22, y2), Loc.t(&"decor.roster_late"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.42, 0.16, 0.08))
	)
	Geo.interactable(st, Vector3(0.42, 0.54, 0.1), pos + Vector3(0, 0, 0.05), null, Loc.t(&"it.roster"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.roster_late") if late else Loc.t(&"sub.roster"), 5.0))


# --- Жилая комната --------------------------------------------------------------------

## Ковёр над кроватью — как у всех: бордовый, с медальоном.
static func _rug(st: Station) -> void:
	_paper(st, Vector2i(380, 250), Vector2(1.9, 1.25), Vector3(-1.3, 1.6, 6.49), Vector3(0, 0, -1), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r, Color(0.42, 0.07, 0.07))
		c.draw_rect(r.grow(-10), Color(0.16, 0.06, 0.08), false, 8.0)
		c.draw_rect(r.grow(-22), Color(0.72, 0.56, 0.3), false, 3.0)
		var ctr := c.size * 0.5
		for k in range(3):
			var s := 80.0 - k * 22.0
			var col: Color = [Color(0.16, 0.06, 0.08), Color(0.72, 0.56, 0.3), Color(0.12, 0.22, 0.3)][k]
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -s), ctr + Vector2(s * 1.4, 0), ctr + Vector2(0, s), ctr + Vector2(-s * 1.4, 0)]), col)
		for corner: Vector2 in [Vector2(52, 50), Vector2(c.size.x - 52, 50), Vector2(52, c.size.y - 50), Vector2(c.size.x - 52, c.size.y - 50)]:
			c.draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -18), corner + Vector2(22, 0), corner + Vector2(0, 18), corner + Vector2(-22, 0)]), Color(0.72, 0.56, 0.3))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in range(900):   # ворс
			c.draw_rect(Rect2(rng.randf() * c.size.x, rng.randf() * c.size.y, 2, 2), Color(0, 0, 0, 0.12))
	, false)


static func _family_photo(st: Station) -> void:
	var pos := Vector3(2.3, 1.62, 6.49)
	_paper(st, Vector2i(160, 200), Vector2(0.22, 0.28), pos, Vector3(0, 0, -1), func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.88, 0.84, 0.74))
		var inner := Rect2(12, 12, c.size.x - 24, c.size.y - 40)
		c.draw_rect(inner, Color(0.55, 0.47, 0.36))
		# Двое: мать и отец у крыльца — сепия, лица не разобрать
		for fx: float in [0.36, 0.64]:
			var base := inner.position + Vector2(inner.size.x * fx, inner.size.y)
			c.draw_rect(Rect2(base + Vector2(-13, -70), Vector2(26, 70)), Color(0.3, 0.24, 0.18))
			c.draw_circle(base + Vector2(0, -82), 11, Color(0.42, 0.34, 0.26))
		c.draw_string(_font(), Vector2(0, c.size.y - 10), "1971", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 14, Color(0.3, 0.26, 0.22))
	)
	Geo.interactable(st, Vector3(0.24, 0.3, 0.1), pos + Vector3(0, 0, -0.05), null, Loc.t(&"it.family_photo"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.family_photo"), 5.0))


## Вымпел «Ударнику коммунистического труда» на гвоздике у двери.
static func _pennant(st: Station) -> void:
	var mi := _paper(st, Vector2i(160, 220), Vector2(0.3, 0.42), Vector3(3.39, 1.62, 1.85), Vector3(-1, 0, 0), func(c: Control) -> void:
		var w := c.size.x
		var h := c.size.y
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.72), Vector2(w * 0.5, h), Vector2(0, h * 0.72)])
		c.draw_colored_polygon(shape, Color(0.72, 0.08, 0.06))
		c.draw_polyline(shape + PackedVector2Array([Vector2(0, 0)]), Color(0.85, 0.68, 0.25), 4.0)
		c.draw_string(_font(), Vector2(0, 50), Loc.t(&"decor.pennant_1"), HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.95, 0.82, 0.4))
		c.draw_string(_font(), Vector2(0, 76), Loc.t(&"decor.pennant_2"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.95, 0.82, 0.4))
		c.draw_string(_font(), Vector2(0, 98), Loc.t(&"decor.pennant_3"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.95, 0.82, 0.4))
		# Звезда
		var ctr := Vector2(w * 0.5, h * 0.66)
		var star := PackedVector2Array()
		for k in range(10):
			var rr := 22.0 if k % 2 == 0 else 9.0
			var a := -PI / 2.0 + k * PI / 5.0
			star.append(ctr + Vector2(cos(a), sin(a)) * rr)
		c.draw_colored_polygon(star, Color(0.95, 0.82, 0.4))
	, false, true)
	st.set_meta(&"pennant", mi)   # «Замечания дежурного»: однажды ночью он висит вверх ногами


# --- Коридор: плакат по технике безопасности ----------------------------------------------

static func _safety_poster(st: Station) -> void:
	_paper(st, Vector2i(300, 420), Vector2(0.5, 0.7), Vector3(8.9, 1.55, 6.49), Vector3(0, 0, -1), func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.9, 0.86, 0.74))
		c.draw_rect(Rect2(0, 0, c.size.x, 90), Color(0.72, 0.1, 0.07))
		c.draw_string(_font(), Vector2(0, 40), Loc.t(&"decor.poster_1"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 24, Color(0.97, 0.93, 0.85))
		c.draw_string(_font(), Vector2(0, 74), Loc.t(&"decor.poster_2"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 20, Color(0.97, 0.93, 0.85))
		# Человечек держится за леер в косой пурге
		var ink := Color(0.15, 0.12, 0.12)
		c.draw_line(Vector2(20, 260), Vector2(c.size.x - 20, 230), Color(0.5, 0.4, 0.25), 4.0)
		for px: float in [40.0, c.size.x - 40.0]:
			c.draw_line(Vector2(px, 220), Vector2(px, 340), Color(0.35, 0.3, 0.25), 6.0)
		var b := Vector2(150, 330)
		c.draw_line(b, b + Vector2(-14, -60), ink, 6.0)
		c.draw_line(b + Vector2(-14, -60), b + Vector2(-20, -110), ink, 8.0)
		c.draw_circle(b + Vector2(-22, -126), 13, ink)
		c.draw_line(b + Vector2(-20, -100), b + Vector2(10, -86), ink, 5.0)
		c.draw_line(b + Vector2(-14, -60), b + Vector2(16, 0), ink, 6.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in range(70):
			var p := Vector2(rng.randf() * c.size.x, 100 + rng.randf() * 260)
			c.draw_line(p, p + Vector2(14, 5), Color(1, 1, 1, 0.8), 1.5)
		c.draw_string(_font(), Vector2(0, 392), Loc.t(&"decor.poster_3"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 15, ink)
	)


# --- Бельё над печью и тулуп в сенях ---------------------------------------------------

static func _clothesline(st: Station) -> void:
	var a := Vector3(-2.38, 2.15, 1.95)
	var b := Vector3(-0.35, 2.15, 1.95)
	Geo.block(st, Vector3(b.x - a.x, 0.012, 0.012), (a + b) * 0.5, Palette.m(&"rope"), false)
	var k := MeshKit.new(83)
	k.mottle = 0.15
	var wool := [Color(0.55, 0.52, 0.48), Color(0.3, 0.28, 0.3), Color(0.5, 0.18, 0.14), Color(0.55, 0.52, 0.48)]
	var xs := [-2.15, -1.85, -1.35, -0.9]
	for i in range(xs.size()):
		var x: float = xs[i]
		var col: Color = wool[i]
		if i == 2:
			# Варежки на шнурке
			k.blob(Vector3(x - 0.07, 2.02, 1.95), Vector3(0.05, 0.08, 0.025), col, 3, 5)
			k.blob(Vector3(x + 0.07, 2.02, 1.95), Vector3(0.05, 0.08, 0.025), col, 3, 5)
		else:
			# Шерстяной носок: голенище вниз, пятка вбок
			k.tube([Vector3(x, 2.14, 1.95), Vector3(x, 1.94, 1.95)], [0.035, 0.032], col, 5)
			k.tube([Vector3(x, 1.94, 1.95), Vector3(x + 0.09, 1.9, 1.95)], [0.032, 0.026], col, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"decor_wool", Color.WHITE, "tex_cloth.png", 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st.add_child(mi)


## Тулуп на крюке в сенях. С 4-й ночи крюк пустой — куда делся, никто не скажет.
static func _coat(st: Station) -> void:
	Geo.block(st, Vector3(0.04, 0.04, 0.08), Vector3(14.0, 1.72, 6.46), Palette.m(&"dark"), false)
	if Game.is_night() and Game.night >= 4:
		return
	var k := MeshKit.new(84)
	k.mottle = 0.14
	var sheep := Color(0.36, 0.28, 0.2)
	k.tube([Vector3(14.0, 1.7, 6.42), Vector3(14.0, 1.45, 6.4), Vector3(14.0, 0.75, 6.38)], [0.08, 0.2, 0.26], sheep, 7, true, false)
	k.blob(Vector3(14.0, 1.66, 6.41), Vector3(0.2, 0.06, 0.06), Color(0.78, 0.74, 0.66), 3, 6)   # овчинный воротник
	for s: float in [-1.0, 1.0]:
		k.tube([Vector3(14.0 + 0.17 * s, 1.58, 6.4), Vector3(14.0 + 0.2 * s, 1.0, 6.36)], [0.06, 0.055], sheep * 0.9, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"decor_coat", Color.WHITE, "tex_cloth.png", 0.0)
	st.add_child(mi)


# --- Потолок и свет -------------------------------------------------------------------

## Балки-матицы в жилой комнате: потолок перестаёт быть ровной плитой.
static func _beams(st: Station) -> void:
	for z: float in [2.0, 4.8]:
		Geo.block(st, Vector3(5.96, 0.16, 0.18), Vector3(0.5, Station.ROOM_H - 0.08, z), Palette.m(&"log"), false)
	Geo.block(st, Vector3(0.18, 0.14, 6.56), Vector3(-0.9, Station.ROOM_H - 0.07, 3.3), Palette.m(&"log"), false)


## Потолочные лампы: резче спад к углам (тёплое пятно под лампой, тёмные углы) и эмалированный абажур.
static func _lamps(st: Station) -> void:
	for n: Node in st.get_children():
		var l := n as OmniLight3D
		if l == null:
			continue
		for at: Vector3 in [Vector3(0.5, 2.65, 3.3), Vector3(7.5, 2.65, 0.1), Vector3(13.0, 2.65, 3.5)]:
			if l.position.distance_to(at) < 0.05:
				l.omni_attenuation = 1.6
				var k := MeshKit.new(91)
				# Конус абажура над лампочкой: снаружи зелёная эмаль, изнутри белый
				k.tube([at + Vector3(0, 0.12, 0), at + Vector3(0, 0.02, 0), at + Vector3(0, -0.06, 0)], [0.03, 0.12, 0.2], Color(0.1, 0.17, 0.13), 8, false, false)
				k.tube([at + Vector3(0, 0.12, 0), at + Vector3(0, Station.ROOM_H - at.y, 0)], [0.008, 0.008], Color(0.1, 0.1, 0.1), 4)
				var mi := MeshInstance3D.new()
				mi.mesh = k.commit()
				mi.material_override = Creatures._mat(&"decor_shade", Color.WHITE, "", 0.0)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				st.add_child(mi)
