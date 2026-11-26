class_name ThermometerUI
extends Control
## Психрометрическая будка: два спиртовых термометра (сухой и смоченный) — настоящие модели в будке,
## камера подходит к ним вплотную (Closeup3D) и ездит вдоль шкалы (колёсико / W S). Цифр игра не
## подсказывает. Ночью видно только в пятне фонаря; иней на стекле стираешь рукавицей (ЛКМ — прямо по
## стеклу). Книжка КМ-1 — в правой руке (HeldPaper). Свердловск сверит книжку (Game.report_check).

signal closed

const T_MIN := -60.0
const T_MAX := 40.0
const T_MID := -10.0
const LEN := 0.52                       ## длина шкалы, м (−60…+40)
const DEG_PER_NOTCH := 0.6
const FEVER := 36.6
const PEN_SFX := "res://assets/audio/clank.ogg"
const SEP := 0.05                       ## термометры — в 5 см от оси будки, сухой слева
const DIST := 0.26                      ## глаз — в 26 см от шкал

var _truth := Vector2(-28.0, -30.0)     ## что на самом деле в воздухе
var _shown := Vector2(-28.0, -30.0)     ## что показывают столбики (в «жар» сухой врёт)
var _fever := false
var _fever_seen := false
var _tm4_frozen := false
var _use_tm9 := false
var _mode_btn: Button
var _title_node: Control
var _book: KMBook
var _hint: Label
var _done := false
var _close: Closeup3D
var _rig: Node3D                        ## термометры в будке (на время крупного плана)
var _frost: Array = []
var _plates: Array[StandardMaterial3D] = []
var _light := 0.0
var _base := Vector3.ZERO               ## центр шкал (T_MID) в мире
var _start_t := 0.0
var _wipe := false
var _mouse := Vector2.ZERO
var _breath_timer := 0.0
var _breath_warned := false
var _lantern_on_nail := false
var _nail_btn: Button
var _shake_btn: Button
var _max_t: float = 0.0
var _max_shaken := false
var _glare_mat: StandardMaterial3D
var _nail_audio: AudioStreamPlayer
var _creepy_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_truth = Game.air_temp()
	_shown = _truth
	if Game.is_night() and Game.night == 4:
		_shown.x = -31.6 # Ночь 4: ртуть залипает на отметке 00:00 (-31.6°C)
	elif Game.is_night() and Game.night == 7:
		_shown.x = 52.0  # Ночь 7: ртуть кипит в капилляре (+52°C)
	if Game.yard != null and Game.yard.has_method(&"claim_fever") and Game.yard.claim_fever():
		_fever = true
		_shown.x = FEVER
	if _truth.x <= -38.83:
		_tm4_frozen = true
	_start_t = clampf(_truth.x + randf_range(-4.0, 4.0), T_MIN + 8.0, T_MAX - 8.0)

	title_plate(self, Loc.t(&"thermo.title"))
	_max_t = clampf(_truth.x + 3.4 + (0.4 if Game.night == 2 else 0.0), T_MIN + 6.0, T_MAX - 5.0)
	if Game.is_night() and Game.night == 5:
		get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"sub.psychrometer_dark_liquid"), 5.0)
		)
	_mode_btn = UiStyle.text_button(Loc.p("[Tab] ТМ-9 (-70°C)", "[Tab] TM-9 (-70°C)"), _toggle_tm9)
	UiKit.place(self, _mode_btn, 0.5, 0.5, 0.5, 0.5, -500, 230, -260, 266)
	_nail_btn = UiStyle.text_button(Loc.t(&"thermo.nail_hang"), _toggle_lantern_nail)
	UiKit.place(self, _nail_btn, 0.5, 0.5, 0.5, 0.5, -250, 230, 20, 266)
	_shake_btn = UiStyle.text_button(Loc.t(&"thermo.shake_max"), _shake_max_thermo)
	UiKit.place(self, _shake_btn, 0.5, 0.5, 0.5, 0.5, 30, 230, 310, 266)

	_nail_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/sfx/cc0/wind_indoor_loop.ogg"):
		_nail_audio.stream = load("res://assets/sfx/cc0/wind_indoor_loop.ogg")
	elif ResourceLoader.exists("res://assets/audio/wind_loop.ogg"):
		_nail_audio.stream = load("res://assets/audio/wind_loop.ogg")
	_nail_audio.volume_db = -80.0
	_nail_audio.bus = &"SFX"
	add_child(_nail_audio)
	_nail_audio.play()

	_build_rig()
	_close = Closeup3D.new()
	Game.level.add_child(_close)
	var eye_x := _base.x - SEP + 0.09
	var eye := Vector3(eye_x, _y(_start_t), _base.z + DIST)
	_close.setup(eye, Vector3(eye_x, _y(_start_t), _base.z), 34.0, Vector3.UP, _y(T_MIN + 8.0) - eye.y, _y(T_MAX - 8.0) - eye.y, 0.0)

	_book = KMBook.new()
	HeldPaper.notebook(self, _book)   # книжка КМ-1 — в правой руке
	_book.setup([
		{"label": Loc.t(&"thermo.dry_row"), "cells": [&"sign", &"digit", &"digit", &"digit"], "dot": 3, "unit": "°C"},
		{"label": Loc.t(&"thermo.wet_row"), "cells": [&"sign", &"digit", &"digit", &"digit"], "dot": 3, "unit": "°C"},
	])
	if Game.notebook.has(&"temp_dry"):
		_book.set_value(0, float(Game.notebook[&"temp_dry"]["v"]))
		_book.set_value(1, float(Game.notebook[&"temp_wet"]["v"]))

	add_buttons(self, Game.notebook.has(&"temp_dry"), _write, func() -> void: closed.emit())
	_hint = hint_label(self)
	Game.audio.play_2d("res://assets/sfx/door_handle.ogg", -10.0)   # дверца будки
	if _tm4_frozen:
		Game.audio.play_2d(PEN_SFX, -4.0)
		get_tree().create_timer(0.4, false).timeout.connect(func() -> void:
			if Game.hud != null:
				Game.hud.subtitle(Loc.p("Тихий звон стекла: ртуть в ТМ-4 замерзла (-38.83°C)! По регламенту перейдите на ТМ-9 [Tab].", "Quiet glass clink: TM-4 mercury froze (-38.83°C)! Switch to TM-9 [Tab] per regulations."), 4.5))


func _exit_tree() -> void:
	var bm := _booth_model()
	if bm != null:
		bm.visible = true
	if _nail_audio != null and is_instance_valid(_nail_audio):
		_nail_audio.queue_free()
	if _close != null and is_instance_valid(_close):
		_close.queue_free()
	if _rig != null and is_instance_valid(_rig):
		_rig.queue_free()


static func _booth_model() -> Node3D:
	if Game.yard == null or not is_instance_valid(Game.yard):
		return null
	return Game.yard.get_node_or_null("BoothModel") as Node3D


## Высота точки шкалы T над землёй (мир).
func _y(t: float) -> float:
	return _base.y + (t - T_MID) / (T_MAX - T_MIN) * LEN


## Два термометра на передней стенке будки: молочная пластина со шкалой, капилляр, стекло, иней.
func _build_rig() -> void:
	var booth := Yard.METEO + Yard.M_BOOTH
	_base = booth + Vector3(0, 1.6, 0.268)
	_rig = Node3D.new()
	Game.level.add_child(_rig)
	# Модель будки целиком лезет в кадр досками — на время крупного плана вместо неё нутро будки:
	# белёная задняя стенка, жалюзи по бокам, полка под термометрами
	var booth_model := _booth_model()
	if booth_model != null:
		booth_model.visible = false
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.78, 0.79, 0.78)
	white.roughness = 1.0
	white.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var back := Geo.box_mesh(Vector3(0.7, 0.7, 0.02), white)
	back.position = Vector3(_base.x, _base.y, _base.z - 0.03)
	_rig.add_child(back)
	for side: int in [-1, 1]:
		for k in 8:
			var lv := Geo.box_mesh(Vector3(0.01, 0.025, 0.3), white)
			lv.position = Vector3(_base.x + side * 0.3, _base.y - 0.3 + k * 0.085, _base.z + 0.12)
			lv.rotation.z = side * 0.45
			_rig.add_child(lv)
	var shelf := Geo.box_mesh(Vector3(0.5, 0.02, 0.12), white)
	shelf.position = Vector3(_base.x, _base.y - LEN * 0.5 - 0.06, _base.z + 0.03)
	_rig.add_child(shelf)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.92, 0.96, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	var amount := InstrumentView.frost_for_weather(_truth.x)
	for i in 2:
		var wet := i == 1
		var x := _base.x + (SEP if wet else -SEP)
		var value := _shown.y if wet else _shown.x
		var label := Loc.t(&"thermo.wet") if wet else Loc.t(&"thermo.dry")
		# шкала двумя половинами по 2048 px: текстура выше 2048 в GL Compatibility обрезается
		for half in 2:
			var lo := T_MIN if half == 0 else T_MID
			var hi := T_MID if half == 0 else T_MAX
			var tex := Closeup3D.canvas_tex(_rig, Vector2i(128, 2048), func(c: Control) -> void: _draw_scale(c, value, lo, hi))
			var q := QuadMesh.new()
			q.size = Vector2(0.06, LEN * 0.5)
			var plate := MeshInstance3D.new()
			plate.mesh = q
			var pm := StandardMaterial3D.new()
			pm.albedo_texture = tex
			# Свет считаем сами (_process): у будки сходятся фонарь в руке и фонарь игрока — шкала пересвечивалась
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_plates.append(pm)
			pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			plate.material_override = pm
			plate.position = Vector3(x, _y((lo + hi) * 0.5), _base.z)
			_rig.add_child(plate)
		# стеклянная оболочка и резервуар внизу
		var tube := CylinderMesh.new()
		tube.top_radius = 0.011
		tube.bottom_radius = 0.011
		tube.height = LEN + 0.04
		var tm := MeshInstance3D.new()
		tm.mesh = tube
		tm.material_override = glass
		tm.position = Vector3(x, _base.y, _base.z + 0.014)
		_rig.add_child(tm)
		var bulb := SphereMesh.new()
		bulb.radius = 0.012
		bulb.height = 0.032
		var bm := MeshInstance3D.new()
		bm.mesh = bulb
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.86, 0.9, 0.93) if wet else Color(0.7, 0.08, 0.08)
		bmat.roughness = 0.8 if wet else 0.2
		bm.material_override = bmat
		bm.position = Vector3(x, _base.y - LEN * 0.5 - 0.03, _base.z + 0.014)
		_rig.add_child(bm)
		var l := Label3D.new()
		l.text = label
		l.font = UiStyle.plate_font()
		l.font_size = 40
		l.pixel_size = 0.0004
		l.modulate = Color(0.2, 0.15, 0.08)
		l.outline_size = 0
		l.shaded = true
		l.position = Vector3(x, _base.y + LEN * 0.5 + 0.012, _base.z + 0.002)
		_rig.add_child(l)
		var fr := Closeup3D.Frost.new(Vector2(0.06, LEN), amount, Vector2i(16, 220))
		fr.position = Vector3(x, _base.y, _base.z + 0.026)
		_rig.add_child(fr)
		_frost.append(fr)

		if wet:
			if Game.is_night() and Game.night == 5:
				var wl := Label3D.new()
				wl.text = "В СТАКАНЧИКЕ — ТЁПЛАЯ ТЁМНАЯ ЖИЖА..." if Loc.is_ru() else "WARM DARK LIQUID IN CUP..."
				wl.font_size = 22
				wl.pixel_size = 0.0003
				wl.modulate = Color(0.85, 0.25, 0.20)
				wl.position = Vector3(x, _base.y - LEN * 0.5 - 0.065, _base.z + 0.015)
				_rig.add_child(wl)
			elif _truth.x <= -10.0:
				var wl := Label3D.new()
				wl.text = "ФИТИЛЬ ОБМЁРЗ (см. § 16)" if Loc.is_ru() else "WICK FROZEN (see § 16)"
				wl.font_size = 24
				wl.pixel_size = 0.0003
				wl.modulate = Color(0.42, 0.48, 0.58)
				wl.position = Vector3(x, _base.y - LEN * 0.5 - 0.065, _base.z + 0.015)
				_rig.add_child(wl)

	# Волосной гигрометр М-19 (справа от термометров)
	var hx: float = _base.x + SEP * 2.3
	var hygro_body := CylinderMesh.new()
	hygro_body.top_radius = 0.052
	hygro_body.bottom_radius = 0.052
	hygro_body.height = 0.018
	var hm := MeshInstance3D.new()
	hm.mesh = hygro_body
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.68, 0.58, 0.28)
	hmat.metallic = 0.75
	hmat.roughness = 0.35
	hm.material_override = hmat
	hm.rotation.x = deg_to_rad(90.0)
	hm.position = Vector3(hx, _base.y, _base.z + 0.01)
	_rig.add_child(hm)

	var rh := int(Game.synoptic.humidity if Game.synoptic != null else 82)
	var dial_tex := Closeup3D.canvas_tex(_rig, Vector2i(256, 256), func(c: Control) -> void: _draw_hygrometer(c, rh))
	var dial_q := QuadMesh.new()
	dial_q.size = Vector2(0.096, 0.096)
	var dial_mi := MeshInstance3D.new()
	dial_mi.mesh = dial_q
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_texture = dial_tex
	dial_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plates.append(dial_mat)
	dial_mi.material_override = dial_mat
	dial_mi.position = Vector3(hx, _base.y, _base.z + 0.021)
	_rig.add_child(dial_mi)

	var hl := Label3D.new()
	hl.text = "ГИГРОМЕТР М-19" if Loc.is_ru() else "HYGROMETER M-19"
	hl.font = UiStyle.plate_font()
	hl.font_size = 28
	hl.pixel_size = 0.00032
	hl.modulate = Color(0.2, 0.15, 0.08)
	hl.position = Vector3(hx, _base.y + 0.075, _base.z + 0.005)
	_rig.add_child(hl)

	# Максимальный ртутный термометр ТМ-1 (горизонтально-наклонный вверху)
	var max_tex := Closeup3D.canvas_tex(_rig, Vector2i(512, 64), func(c: Control) -> void: _draw_horizontal_scale(c, _max_t, -30.0, 40.0, "ТМ-1 МАКС. °C"))
	var max_q := QuadMesh.new()
	max_q.size = Vector2(0.24, 0.035)
	var max_mi := MeshInstance3D.new()
	max_mi.mesh = max_q
	var max_mat := StandardMaterial3D.new()
	max_mat.albedo_texture = max_tex
	max_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plates.append(max_mat)
	max_mi.material_override = max_mat
	max_mi.position = Vector3(_base.x - 0.02, _base.y + LEN * 0.5 + 0.05, _base.z + 0.005)
	max_mi.rotation.z = deg_to_rad(-4.0)
	_rig.add_child(max_mi)

	# Минимальный спиртовой термометр ТМ-2 (внизу на полке со штифтиком)
	var min_t := -60.0 if (Game.is_night() and Game.night == 7) else (_truth.x - 1.8)
	var min_tex := Closeup3D.canvas_tex(_rig, Vector2i(512, 64), func(c: Control) -> void: _draw_horizontal_scale(c, min_t, -60.0, 20.0, "ТМ-2 МИН. °C", true))
	var min_q := QuadMesh.new()
	min_q.size = Vector2(0.24, 0.035)
	var min_mi := MeshInstance3D.new()
	min_mi.mesh = min_q
	var min_mat := StandardMaterial3D.new()
	min_mat.albedo_texture = min_tex
	min_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plates.append(min_mat)
	min_mi.material_override = min_mat
	min_mi.position = Vector3(_base.x - 0.02, _base.y - LEN * 0.5 - 0.02, _base.z + 0.01)
	_rig.add_child(min_mi)

	# Кованый гвоздь для подвешивания фонаря ФАС-4
	var nail_box := BoxMesh.new()
	nail_box.size = Vector3(0.012, 0.012, 0.07)
	var nail_mi := MeshInstance3D.new()
	nail_mi.mesh = nail_box
	var nail_mat := StandardMaterial3D.new()
	nail_mat.albedo_color = Color(0.25, 0.26, 0.28)
	nail_mat.metallic = 0.8
	nail_mat.roughness = 0.5
	nail_mi.material_override = nail_mat
	nail_mi.position = Vector3(_base.x + SEP * 2.8, _base.y + LEN * 0.44, _base.z + 0.04)
	_rig.add_child(nail_mi)

	# Блик на стекле капилляра при прямом взгляде
	var glare_q := QuadMesh.new()
	glare_q.size = Vector2(0.18, LEN * 0.7)
	var glare_mi := MeshInstance3D.new()
	glare_mi.mesh = glare_q
	_glare_mat = StandardMaterial3D.new()
	_glare_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	_glare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glare_mi.material_override = _glare_mat
	glare_mi.position = Vector3(_base.x, _base.y, _base.z + 0.028)
	_rig.add_child(glare_mi)


## Шкала во весь термометр: −60 внизу, +40 вверху; спиртовой столбик до value.
func _draw_scale(c: Control, value: float, t_lo: float, t_hi: float) -> void:
	var w := c.size.x
	var h := c.size.y
	var ink := Color(0.1, 0.1, 0.12)
	var pf := UiStyle.plate_font()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.95, 0.95, 0.92))
	var y_of := func(t: float) -> float: return (t_hi - t) / (t_hi - t_lo) * h
	var cx := w * 0.62
	for k in range(int(t_lo * 5.0) - 1, int(t_hi * 5.0) + 2):
		var t := k / 5.0
		var y: float = y_of.call(t)
		var len := 10.0
		var width := 1.6
		if k % 25 == 0:
			len = 30.0
			width = 3.0
		elif k % 5 == 0:
			len = 20.0
			width = 2.2
		c.draw_line(Vector2(cx - 8 - len, y), Vector2(cx - 8, y), ink, width)
		c.draw_line(Vector2(cx + 8, y), Vector2(cx + 8 + len * 0.6, y), ink, width)
		if k % 25 == 0:
			var n := int(roundf(t))
			var s := ("−" if n < 0 else "+" if n > 0 else "") + str(absi(n))
			c.draw_string(pf, Vector2(4, y + 12), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
	c.draw_rect(Rect2(cx - 4, 0, 8, h), Color(0.84, 0.88, 0.9))
	var top: float = clampf(y_of.call(value), -4.0, h + 4.0)
	if top < h:
		c.draw_rect(Rect2(cx - 3, top, 6, h - top), Color(0.72, 0.08, 0.08))
		if top > 0.0:
			c.draw_circle(Vector2(cx, top + 1.0), 3.2, Color(0.6, 0.05, 0.05))
	if t_lo <= T_MIN:
		c.draw_string(pf, Vector2(cx + 14, h - 14), "°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)


func _draw_horizontal_scale(c: Control, value: float, t_lo: float, t_hi: float, title: String, with_pin: bool = false) -> void:
	var w := c.size.x
	var h := c.size.y
	var ink := Color(0.12, 0.12, 0.14)
	var pf := UiStyle.plate_font()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.95, 0.95, 0.92))
	c.draw_string(pf, Vector2(10, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	var x_of := func(t: float) -> float: return (t - t_lo) / (t_hi - t_lo) * (w - 40.0) + 20.0
	var cy := h * 0.65
	c.draw_line(Vector2(20, cy), Vector2(w - 20, cy), Color(0.8, 0.84, 0.88), 6.0)
	var vx: float = clampf(x_of.call(value), 20.0, w - 20.0)
	c.draw_line(Vector2(20, cy), Vector2(vx, cy), Color(0.72, 0.08, 0.08) if not with_pin else Color(0.15, 0.35, 0.65), 4.5)
	if with_pin:
		c.draw_rect(Rect2(vx - 6, cy - 3, 6, 6), Color(0.12, 0.12, 0.15))
	for t in range(int(t_lo), int(t_hi) + 1, 10):
		var x: float = x_of.call(float(t))
		c.draw_line(Vector2(x, cy - 6), Vector2(x, cy + 6), ink, 1.6)
		c.draw_string(pf, Vector2(x - 10, cy - 8), str(t), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, ink)


func _draw_hygrometer(c: Control, rh: int) -> void:
	var w := c.size.x
	var h := c.size.y
	var center := Vector2(w * 0.5, h * 0.5)
	var radius := w * 0.44
	var ink := Color(0.12, 0.12, 0.14)
	var pf := UiStyle.plate_font()
	c.draw_circle(center, radius, Color(0.94, 0.94, 0.91))
	c.draw_arc(center, radius - 2.0, 0, TAU, 64, ink, 2.5)
	for pct in range(0, 101, 10):
		var ang := deg_to_rad(135.0 + float(pct) / 100.0 * 270.0)
		var p1 := center + Vector2(cos(ang), sin(ang)) * (radius - 12.0)
		var p2 := center + Vector2(cos(ang), sin(ang)) * (radius - 4.0)
		c.draw_line(p1, p2, ink, 2.0 if pct % 20 == 0 else 1.2)
		if pct % 20 == 0:
			var txt_pos := center + Vector2(cos(ang), sin(ang)) * (radius - 26.0) - Vector2(10, -6)
			c.draw_string(pf, txt_pos, str(pct), HORIZONTAL_ALIGNMENT_CENTER, -1, 15, ink)
	c.draw_string(pf, center + Vector2(-12, 24), "%", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, ink)
	c.draw_string(pf, center + Vector2(-30, -18), "ВОЛОСНОЙ", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.35, 0.35, 0.35))
	var arrow_ang := deg_to_rad(135.0 + clampf(float(rh), 0.0, 100.0) / 100.0 * 270.0)
	var arrow_tip := center + Vector2(cos(arrow_ang), sin(arrow_ang)) * (radius - 10.0)
	c.draw_line(center, arrow_tip, Color(0.1, 0.1, 0.12), 2.5)
	c.draw_circle(center, 4.0, Color(0.1, 0.1, 0.12))


## Кнопки «Записать» / «Закрыть» под книжкой — общие для всех приборов.
## Подложка экрана прибора: слева — темно (там кадр прибора), справа мир виден — там книжка в руке.
static func backdrop(owner: Control) -> void:
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.8), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.25)])
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 64
	tex.height = 4
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(owner, r, 0, 0, 1, 1, 0, 0, 0, 0)


## Кнопки под книжкой — общие для всех приборов: «Записать» — штампом, «Закрыть» — машинописью.
static func add_buttons(owner: Control, again: bool, on_write: Callable, on_close: Callable) -> void:
	var write_btn := UiStyle.stamp_button(Loc.t(&"thermo.write_again" if again else &"thermo.write").to_upper(), on_write)
	UiKit.place(owner, write_btn, 0.5, 0.5, 0.5, 0.5, 110, 196, 315, 238)
	var close_btn := UiStyle.text_button(Loc.t(&"thermo.close_key"), on_close)
	UiKit.place(owner, close_btn, 0.5, 0.5, 0.5, 0.5, 325, 196, 455, 238)


## Латунный шильдик прибора над кадром.
static func title_plate(owner: Control, text: String) -> void:
	var plate := UiStyle.brass_plate(text, 17)
	UiKit.place(owner, plate, 0.5, 0.5, 0.5, 0.5, -500, -318, -500, -286)


## Подсказка по клавишам — машинописью над кадром.
static func hint_label(owner: Control) -> Label:
	var hint := UiStyle.hint()
	UiKit.place(owner, hint, 0.5, 0.5, 0.5, 0.5, -500, -276, 500, -256)
	return hint


## Хвост подписи после записи: сколько приборов осталось (в коопе — продиктуй напарнику).
static func tail() -> String:
	if Net.active() and Net.role == "client":
		return Loc.t(&"coop.read_tell")   # сводку передаёт тот, кто в доме: цифры — ему по рации
	var left := Game.READING_KEYS.size() - Game.readings_count()
	return Loc.t(&"read.all") if left == 0 else Loc.t(&"read.left", [left])


func _process(delta: float) -> void:
	var dy := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var ry := -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(ry) > 0.2:
		dy += ry
	if absf(dy) > 0.01:
		_scroll(dy * 9.0 * delta)
	var holding_breath := Input.is_action_pressed(&"hold_breath") or Input.is_physical_key_pressed(KEY_SPACE)
	if not holding_breath:
		_breath_timer += delta
		if _breath_timer > 3.5:
			_shown.x += delta * 0.2
			for f: Closeup3D.Frost in _frost:
				var m := f.material_override as StandardMaterial3D
				if m != null:
					m.albedo_color.a = clampf(m.albedo_color.a + delta * 0.25, 1.0, 2.5)
			if not _breath_warned and Game.hud != null:
				_breath_warned = true
				Game.hud.subtitle(Loc.t(&"thermo.fog_warning"), 3.5)
	else:
		_breath_timer = maxf(0.0, _breath_timer - delta * 2.0)

	if _wipe or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		var r := _close.ray(get_global_transform_with_canvas() * _mouse)
		var hit := false
		for f: Closeup3D.Frost in _frost:
			var lp: Variant = Closeup3D.hit_plane(r, f)
			if lp != null and f.wipe(lp, delta):
				hit = true
		if hit:
			_wipe_sfx(delta)
			for f: Closeup3D.Frost in _frost:
				var m := f.material_override as StandardMaterial3D
				if m != null:
					m.albedo_color.a = 1.0
			if not _fever:
				_shown.x = move_toward(_shown.x, _truth.x, delta * 0.5)
	_light = lerpf(_light, (1.0 if Game.is_daylight() else 0.85) if _close.can_see() else 0.03, clampf(delta * 8.0, 0.0, 1.0))
	for pm in _plates:
		pm.albedo_color = Color(_light, _light, _light * 0.95)
	_hint.text = Loc.t(&"thermo.hint") if _close.can_see() else Loc.t(&"thermo.hint_dark")
	_check_fever()

	if _nail_audio != null and is_instance_valid(_nail_audio):
		var target_vol: float = -14.0 if _lantern_on_nail else -80.0
		_nail_audio.volume_db = lerpf(_nail_audio.volume_db, target_vol, clampf(delta * 4.0, 0.0, 1.0))
		if _lantern_on_nail:
			_creepy_t -= delta
			if _creepy_t <= 0.0:
				_creepy_t = randf_range(8.0, 16.0)
				Game.audio.play_2d("res://assets/audio/step_snow_1.ogg", -18.0, randf_range(0.8, 1.1))

	if _glare_mat != null:
		var center_dist: float = absf(_mouse.x - size.x * 0.5)
		var glare_k: float = clampf(1.0 - (center_dist / 110.0), 0.0, 0.65)
		_glare_mat.albedo_color = Color(1.0, 1.0, 1.0, glare_k)


var _wipe_t := 0.0


func _wipe_sfx(delta: float) -> void:
	_wipe_t -= delta
	if _wipe_t <= 0.0:
		_wipe_t = 0.32
		Game.audio.play_2d(InstrumentView.WIPE_SFX, -20.0, 0.25)


func _scroll(deg: float) -> void:
	_close.scroll(deg / (T_MAX - T_MIN) * LEN)


## Какая температура сейчас в центре кадра.
func _view_t() -> float:
	var eye_y := _y(_start_t) + _close.offset()
	return T_MID + (eye_y - _base.y) / LEN * (T_MAX - T_MIN)


## Сухой показывает +36,6: заметили столбик — тот же холодок, что раньше давала подпись.
func _check_fever() -> void:
	if not _fever or _fever_seen or not _close.can_see():
		return
	if absf(_view_t() - FEVER) > 6.0:
		return
	_fever_seen = true
	if Game.anomalies != null:
		Game.anomalies.occur(&"therm_366")
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 0.0)
	Director.add_tension(14.0, "аномалия термометра +36.6")
	Game.add_fatigue(4.0)
	get_tree().create_timer(1.8, false).timeout.connect(func() -> void:
		if Game.hud != null and is_instance_valid(Game.hud):
			Game.hud.subtitle(Loc.t(&"sub.fever_meteo"), 4.5))


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		closed.emit()
		accept_event()
		return
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse = mb.position
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_scroll(DEG_PER_NOTCH)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_scroll(-DEG_PER_NOTCH)
			MOUSE_BUTTON_LEFT:
				_wipe = mb.pressed


func _toggle_lantern_nail() -> void:
	_lantern_on_nail = not _lantern_on_nail
	Game.audio.play_2d("res://assets/audio/clank.ogg", -8.0, 1.4)
	if _lantern_on_nail:
		_close.set_spot_pose(Vector3(0.24, 0.22, 0.12), Vector3(-0.45, -0.6, 0.0))
		if _nail_btn != null:
			_nail_btn.text = Loc.t(&"thermo.nail_take")
		if Game.hud != null:
			Game.hud.subtitle(Loc.p("ФАС-4 повешен на гвоздь будки. Руки свободны, но за спиной — тьма.", "FAS-4 hung on booth nail. Hands free, but darkness is at your back."), 3.5)
	else:
		_close.reset_spot_pose()
		if _nail_btn != null:
			_nail_btn.text = Loc.t(&"thermo.nail_hang")
		if Game.hud != null:
			Game.hud.subtitle(Loc.p("Фонарь снят с гвоздя в руку.", "Lantern taken back in hand."), 2.5)


func _shake_max_thermo() -> void:
	if _max_shaken:
		return
	_max_shaken = true
	_max_t = _truth.x
	Game.audio.play_2d("res://assets/audio/ice_hit.ogg", -6.0, 1.8)
	if _close != null and is_instance_valid(_close.cam):
		var orig_y := _close.cam.position.y
		var tw := create_tween()
		tw.tween_property(_close.cam, "position:y", orig_y - 0.025, 0.08)
		tw.tween_property(_close.cam, "position:y", orig_y, 0.14)
	if _shake_btn != null:
		_shake_btn.text = Loc.p("ТМ-1 стряхнут", "TM-1 shaken")
	if Game.hud != null:
		Game.hud.subtitle(Loc.p("Резкий кистевой взмах — ртутный столбик ТМ-1 сброшен.", "Sharp wrist flick — TM-1 mercury reset."), 3.0)


func _toggle_tm9() -> void:
	_use_tm9 = not _use_tm9
	Game.audio.play_2d(PEN_SFX, -8.0)
	if _mode_btn != null:
		_mode_btn.text = Loc.p("[Tab] ТМ-4 (ртутный)" if _use_tm9 else "[Tab] ТМ-9 (спиртовой -70°C)", "[Tab] TM-4 (mercury)" if _use_tm9 else "[Tab] TM-9 (spirit -70°C)")
	if Game.hud != null:
		var msg: String = Loc.p("Переключено на ТМ-9: шкала до -70°C (толуол/спирт) по Наставлению ГМС", "Switched to TM-9: scale down to -70°C (toluene/spirit) per HMS regulations") if _use_tm9 else Loc.p("Переключено на ТМ-4 (станционный ртутный)", "Switched to TM-4 (station mercury)")
		Game.hud.subtitle(msg, 3.5)


# --- Запись -----------------------------------------------------------------------------

func _write() -> void:
	if _done:
		return
	_done = true
	var dry := _book.value(0)
	var wet := _book.value(1)
	if _tm4_frozen and not _use_tm9:
		Game.set_flag("tm4_mercury_violation", true)
		Game.hud.subtitle(Loc.p("НАРУШЕНИЕ РЕГЛАМЕНТА: Записаны показания замерзшей ртути ТМ-4 (-38.8°C)! Сводка забракована.", "REGULATION VIOLATION: Recorded frozen TM-4 mercury (-38.8°C)! Report rejected by Sverdlovsk."), 5.0)
	else:
		Game.set_flag("tm4_mercury_violation", false)
	Game.write_reading(&"temp_dry", dry, _truth.x)
	Game.write_reading(&"temp_wet", wet, _truth.y)
	Game.take_reading(&"temp")
	Game.audio.play_2d(PEN_SFX, -12.0)
	Game.hud.subtitle(Loc.t(&"thermo.written", [fmt(dry, 1), fmt(wet, 1)]) + " " + tail(), 5.0)
	closed.emit()


static func fmt(v: float, decimals: int) -> String:
	var s := (("%." + str(decimals) + "f") % absf(v)).replace(".", Loc.p(",", "."))
	return ("−" if v < 0.0 else "+" if v > 0.0 else "") + s


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_TAB:
		_toggle_tm9()
		return
	if (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F) or event.is_action_pressed(&"flashlight"):
		_toggle_lantern_nail()
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_R:
		_shake_max_thermo()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)
