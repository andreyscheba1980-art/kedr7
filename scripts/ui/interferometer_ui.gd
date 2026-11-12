class_name InterferometerUI
extends Control
## Шахтный оптический интерферометр ШИ-11 (ГОСТ 13320-69).
## Работает на пикетах Штольни №4:
## Пикет 1 (вход, z > -15): CH4 0.2%, CO2 0.4% (норма)
## Пикет 2 (средний штрек, -38 <= z <= -15): смещение и дрожание 7 Гц (одноразовая улика в ТМ-1)
## Пикет 3 (глубокий забой, z < -38 / близость Ырки): аномальный зрачок (одноразовая улика и +12 tension)

signal closed

var _zero_offset: float = 0.0
var _pump_strokes: int = 0
var _chamber_co2: float = 0.4
var _chamber_ch4: float = 0.2
var _picket: int = 1
var _time_t: float = 0.0
var _eyepiece_canvas: Control
var _status_lbl: Label
var _reading_lbl: Label
var _pupil_warp: float = 0.0
var _near_yrka_or_anomaly: bool = false
var _eye_whisper_played: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel()
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -420, -310, 420, 310)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)
	top_bar.add_child(UiStyle.brass_plate(Loc.t(&"shi11.title"), 16))
	top_bar.add_spacer(false)
	var close_btn := UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(close_btn)

	var sub := UiKit.label(Loc.p(
		"ИНТЕРФЕРОМЕТР ОПТИЧЕСКИЙ · ЗАВОД «КРАСНЫЙ МЕТАЛЛИСТ» · ГОСТ 13320-69",
		"OPTICAL INTERFEROMETER · KRASNY METALLIST · GOST 13320-69"
	), 11)
	sub.modulate = Color(0.7, 0.8, 0.7, 0.75)
	root_vbox.add_child(sub)

	var center_box := CenterContainer.new()
	root_vbox.add_child(center_box)

	_eyepiece_canvas = Control.new()
	_eyepiece_canvas.custom_minimum_size = Vector2(500, 340)
	_eyepiece_canvas.draw.connect(_draw_eyepiece)
	center_box.add_child(_eyepiece_canvas)

	_status_lbl = UiKit.label(Loc.p(
		"ГРУША: 0/5 ПРОКАЧЕК · КАМЕРА НЕ ЗАПОЛНЕНА",
		"BULB: 0/5 SQUEEZES · CHAMBER EMPTY"
	), 13)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_status_lbl)

	_reading_lbl = UiKit.label(Loc.p(
		"ПРОКАЧАЙТЕ ГРУШУ [ПРОБЕЛ] ДЛЯ ЗАМЕРА НА ПИКЕТЕ",
		"SQUEEZE BULB [SPACE] TO SAMPLE AT PICKET"
	), 12)
	_reading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reading_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reading_lbl.modulate = Color(0.9, 0.85, 0.6)
	root_vbox.add_child(_reading_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(btn_row)

	var btn_pump := UiKit.button(Loc.t(&"shi11.pump"), _on_squeeze_bulb)
	btn_row.add_child(btn_pump)

	var btn_zero := UiKit.button(Loc.t(&"shi11.zero"), _on_zero_calibrate)
	btn_row.add_child(btn_zero)

	_detect_environment()


func _detect_environment() -> void:
	_near_yrka_or_anomaly = false
	if Game.player == null:
		return
	var pp := Game.player.global_position
	if MineHorizon.instance != null and MineHorizon.zone_has(pp):
		var local := pp - MineHorizon.ROOT
		if local.z < -38.0:
			_picket = 3
			_chamber_co2 = 3.2
			_chamber_ch4 = 1.8
			_near_yrka_or_anomaly = true
		elif local.z <= -15.0:
			_picket = 2
			_chamber_co2 = 3.2
			_chamber_ch4 = 1.8
		else:
			_picket = 1
			_chamber_co2 = 0.4
			_chamber_ch4 = 0.2
	else:
		_picket = 1
		_chamber_co2 = 0.04
		_chamber_ch4 = 0.0

	if Game.yrka_nearby:
		_near_yrka_or_anomaly = true


func _process(delta: float) -> void:
	_time_t += delta
	if _near_yrka_or_anomaly and _pump_strokes >= 3:
		_pupil_warp = move_toward(_pupil_warp, 1.0, delta * 1.5)
		if _pupil_warp > 0.8 and not _eye_whisper_played:
			_eye_whisper_played = true
			if Game.player != null:
				Game.audio.play_3d("res://assets/audio/whisper.ogg", Game.player.global_position, -4.0, 6.0)
			if not Game.shi11_eye_seen:
				Game.shi11_eye_seen = true
				Director.add_tension(12.0, "аномальный зрачок ШИ-11")
				Game.add_evidence(&"shi11_void_refraction")
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"mine.shi11_picket3"), 5.5)
	else:
		_pupil_warp = move_toward(_pupil_warp, 0.0, delta * 2.0)

	_eyepiece_canvas.queue_redraw()


func _draw_eyepiece() -> void:
	var w: float = 500.0
	var h: float = 340.0
	var center := Vector2(w * 0.5, h * 0.5)
	var r: float = 145.0

	_eyepiece_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.04, 0.04))
	_eyepiece_canvas.draw_circle(center, r + 15.0, Color(0.12, 0.13, 0.12))
	_eyepiece_canvas.draw_circle(center, r + 6.0, Color(0.25, 0.26, 0.22))
	_eyepiece_canvas.draw_circle(center, r, Color(0.02, 0.02, 0.02))

	var spec_w: float = 230.0
	var spec_h: float = 180.0
	var spec_rect := Rect2(center.x - spec_w * 0.5, center.y - spec_h * 0.5, spec_w, spec_h)

	var bands := 60
	var dx := spec_w / float(bands)
	for b in range(bands):
		var t := float(b) / float(bands)
		var col := Color.from_hsv(lerpf(0.0, 0.72, t), 0.85, 0.85)
		_eyepiece_canvas.draw_rect(Rect2(spec_rect.position.x + float(b) * dx, spec_rect.position.y, dx + 1.0, spec_h), col)

	var scale_y := spec_rect.position.y + spec_h - 22.0
	_eyepiece_canvas.draw_line(Vector2(spec_rect.position.x, scale_y), Vector2(spec_rect.end.x, scale_y), Color(0.05, 0.05, 0.05), 1.5)
	for s_i in range(7):
		var sx := spec_rect.position.x + (float(s_i) / 6.0) * spec_w
		_eyepiece_canvas.draw_line(Vector2(sx, scale_y), Vector2(sx, scale_y - 12.0), Color(0.05, 0.05, 0.05), 1.5)
		_eyepiece_canvas.draw_string(ThemeDB.fallback_font, Vector2(sx - 4, scale_y + 14), str(s_i), HORIZONTAL_ALIGNMENT_CENTER, 10, 9, Color(0.1, 0.1, 0.1))

	var vib_7hz: float = sin(_time_t * 44.0) * (3.5 if _picket == 2 and _pump_strokes >= 3 else 0.0)
	var effective_shift: float = (_chamber_co2 * 22.0 - _chamber_ch4 * 18.0) * (float(_pump_strokes) / 5.0) + _zero_offset + vib_7hz
	var fringe_x1 := center.x - 14.0 + effective_shift
	var fringe_x2 := center.x + 14.0 + effective_shift

	if _pupil_warp > 0.01:
		var pulse := 0.85 + 0.15 * sin(_time_t * 3.5)
		var curve_pts1: PackedVector2Array = []
		var curve_pts2: PackedVector2Array = []
		var steps := 24
		for st in range(steps + 1):
			var fy := spec_rect.position.y + (float(st) / float(steps)) * spec_h
			var ny := (fy - center.y) / (spec_h * 0.5)
			var bulge := cos(ny * PI * 0.5) * (32.0 * _pupil_warp * pulse)
			curve_pts1.append(Vector2(center.x - 6.0 - bulge, fy))
			curve_pts2.append(Vector2(center.x + 6.0 + bulge, fy))

		for st in range(steps):
			_eyepiece_canvas.draw_line(curve_pts1[st], curve_pts1[st + 1], Color(0.02, 0.02, 0.02), 3.5)
			_eyepiece_canvas.draw_line(curve_pts2[st], curve_pts2[st + 1], Color(0.02, 0.02, 0.02), 3.5)

		_reading_lbl.text = Loc.t(&"shi11.reading_anomaly")
		_reading_lbl.modulate = Color(1.0, 0.3, 0.3)
	else:
		_eyepiece_canvas.draw_line(Vector2(fringe_x1, spec_rect.position.y), Vector2(fringe_x1, spec_rect.end.y), Color(0.02, 0.02, 0.02), 3.0)
		_eyepiece_canvas.draw_line(Vector2(fringe_x2, spec_rect.position.y), Vector2(fringe_x2, spec_rect.end.y), Color(0.02, 0.02, 0.02), 3.0)

	_eyepiece_canvas.draw_arc(center, r + 1.0, 0, TAU, 64, Color(0.08, 0.09, 0.08), 8.0)


func _on_squeeze_bulb() -> void:
	_pump_strokes = mini(_pump_strokes + 1, 5)
	AudioDirector.play_raw("res://assets/audio/stove_add.ogg", -6.0)
	Game.vibrate(0.2, 0.1, 0.15)
	_detect_environment()
	_status_lbl.text = Loc.p(
		"ПИКЕТ %d · ГРУША: %d/5 · КАМЕРА %s",
		"PICKET %d · BULB: %d/5 · CHAMBER %s"
	) % [_picket, _pump_strokes, Loc.p("ЗАПОЛНЕНА", "FILLED") if _pump_strokes == 5 else Loc.p("ПРОДУВАЕТСЯ", "FLUSHING")]

	if _pump_strokes == 5:
		if _near_yrka_or_anomaly:
			_reading_lbl.text = Loc.t(&"mine.shi11_picket3")
		elif _picket == 2:
			_reading_lbl.text = Loc.t(&"mine.shi11_picket2")
			if not Game.clue_shi11_infrasound:
				Game.clue_shi11_infrasound = true
				Game.add_evidence(&"shi11_infrasound")
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"mine.shi11_picket2"), 5.5)
		else:
			_reading_lbl.text = Loc.t(&"mine.shi11_picket1")


func _on_zero_calibrate() -> void:
	_zero_offset = 0.0
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
	_reading_lbl.modulate = Color(0.9, 0.85, 0.6)
	_reading_lbl.text = Loc.p(
		"Микрометрический винт: нулевые полосы совмещены с риской 0.0%.",
		"Micrometer screw: zero fringes aligned to 0.0% mark."
	)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_close()
		return true
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_on_squeeze_bulb()
				return true
			KEY_Z:
				_on_zero_calibrate()
				return true
			KEY_TAB, KEY_ESCAPE, KEY_E:
				_close()
				return true
	return false


func _close() -> void:
	closed.emit()
