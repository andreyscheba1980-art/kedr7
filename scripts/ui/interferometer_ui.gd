class_name InterferometerUI
extends Control
## Шахтный оптический интерферометр ШИ-11 (1978 г.):
## Оптический прибор для экспресс-анализа метана (CH4) и углекислого газа (CO2).
## В окуляре виден дифракционный радужный спектр с двумя чёрными интерференционными полосами.
## При прокачке резиновой грушей (5 объёмов) газовая камера заполняется воздухом забоя.
## Вблизи Объекта «Отзвук» полосы интерференции искажаются в вертикальный зрачок хищника.

signal closed

static var zero_offset: float = 0.0
static var pump_strokes: int = 0
static var chamber_co2: float = 0.0
static var chamber_ch4: float = 0.0

var _time_t: float = 0.0
var _eyepiece_canvas: Control
var _status_lbl: Label
var _reading_lbl: Label
var _pupil_warp: float = 0.0
var _near_yrka_or_anomaly: bool = false


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

	# Заголовок
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)
	top_bar.add_child(UiStyle.brass_plate(Loc.t(&"shi11.title"), 16))
	top_bar.add_spacer(false)
	var close_btn := UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(close_btn)

	var sub := UiKit.label("ИНТЕРФЕРОМЕТР ОПТИЧЕСКИЙ • ЗАВОД «КРАСНЫЙ МЕТАЛЛИСТ» • ГОСТ 12.4.083-80", 11)
	sub.modulate = Color(0.7, 0.8, 0.7, 0.75)
	root_vbox.add_child(sub)

	# Окуляр интерферометра
	var center_box := CenterContainer.new()
	root_vbox.add_child(center_box)

	_eyepiece_canvas = Control.new()
	_eyepiece_canvas.custom_minimum_size = Vector2(500, 340)
	_eyepiece_canvas.draw.connect(_draw_eyepiece)
	center_box.add_child(_eyepiece_canvas)

	# Информационные надписи
	_status_lbl = UiKit.label("ГРУША: 0/5 ПРОКАЧЕК • КАМЕРА НЕ ЗАПОЛНЕНА", 13)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_status_lbl)

	_reading_lbl = UiKit.label("НАВЕДИТЕ НА ШКАЛУ [Z — ЮСТИРОВКА, ПРОБЕЛ — ПРОКАЧКА]", 12)
	_reading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reading_lbl.modulate = Color(0.9, 0.85, 0.6)
	root_vbox.add_child(_reading_lbl)

	# Кнопки
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(btn_row)

	var btn_pump := UiKit.button(Loc.t(&"shi11.pump"), _on_squeeze_bulb)
	btn_row.add_child(btn_pump)

	var btn_zero := UiKit.button(Loc.t(&"shi11.zero"), _on_zero_calibrate)
	btn_row.add_child(btn_zero)

	# Определение текущей среды в точке игрока
	_detect_environment()


func _detect_environment() -> void:
	if Game.player == null:
		return
	var pp := Game.player.global_position
	# Штольня №4 (Горизонт-40):
	if MineHorizon.instance != null and MineHorizon.zone_has(pp):
		var local := pp - MineHorizon.ROOT
		if local.z < -38.0:
			# Глубокий забой / Объект «Отзвук»
			_near_yrka_or_anomaly = true
		elif local.z < -15.0:
			# Дальний штрек — накопление CO2
			chamber_co2 = 2.45
			chamber_ch4 = 0.1
		elif local.x < -4.0:
			# Западный тупик / пласт с метаном
			chamber_co2 = 0.3
			chamber_ch4 = 1.6
		else:
			chamber_co2 = 0.85
			chamber_ch4 = 0.0
	else:
		# На открытом воздухе
		chamber_co2 = 0.04
		chamber_ch4 = 0.0

	# Проверка близости Ырки
	if Game.yrka_nearby:
		_near_yrka_or_anomaly = true


func _process(delta: float) -> void:
	_time_t += delta
	if _near_yrka_or_anomaly:
		_pupil_warp = move_toward(_pupil_warp, 1.0, delta * 1.5)
		if _pupil_warp > 0.8 and randf() < delta * 0.4:
			Game.audio.play_3d("res://assets/audio/whisper.ogg", Game.player.global_position, -4.0, 6.0)
			Director.add_tension(8.0, "аномальный зрачок ШИ-11")
	else:
		_pupil_warp = move_toward(_pupil_warp, 0.0, delta * 2.0)

	_eyepiece_canvas.queue_redraw()


func _draw_eyepiece() -> void:
	var w: float = 500.0
	var h: float = 340.0
	var center := Vector2(w * 0.5, h * 0.5)
	var r: float = 145.0

	# Карболитовый корпус окуляра
	_eyepiece_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.04, 0.04))
	_eyepiece_canvas.draw_circle(center, r + 15.0, Color(0.12, 0.13, 0.12))
	_eyepiece_canvas.draw_circle(center, r + 6.0, Color(0.25, 0.26, 0.22))
	_eyepiece_canvas.draw_circle(center, r, Color(0.02, 0.02, 0.02))

	# Оптическая щель спектра внутри окуляра (прямоугольник с маской)
	var spec_w: float = 230.0
	var spec_h: float = 180.0
	var spec_rect := Rect2(center.x - spec_w * 0.5, center.y - spec_h * 0.5, spec_w, spec_h)

	# Отрисовка радужного непрерывного спектра (дисперсионная призма ШИ-11)
	var bands := 60
	var dx := spec_w / float(bands)
	for b in range(bands):
		var t := float(b) / float(bands)
		# Дисперсия от красного через жёлтый, зелёный к сине-фиолетовому
		var col := Color.from_hsv(lerpf(0.0, 0.72, t), 0.85, 0.85)
		_eyepiece_canvas.draw_rect(Rect2(spec_rect.position.x + float(b) * dx, spec_rect.position.y, dx + 1.0, spec_h), col)

	# Измерительная шкала (0 to 6% CH4 / CO2)
	var scale_y := spec_rect.position.y + spec_h - 22.0
	_eyepiece_canvas.draw_line(Vector2(spec_rect.position.x, scale_y), Vector2(spec_rect.end.x, scale_y), Color(0.05, 0.05, 0.05), 1.5)
	for s_i in range(7):
		var sx := spec_rect.position.x + (float(s_i) / 6.0) * spec_w
		_eyepiece_canvas.draw_line(Vector2(sx, scale_y), Vector2(sx, scale_y - 12.0), Color(0.05, 0.05, 0.05), 1.5)
		_eyepiece_canvas.draw_string(ThemeDB.fallback_font, Vector2(sx - 4, scale_y + 14), str(s_i), HORIZONTAL_ALIGNMENT_CENTER, 10, 9, Color(0.1, 0.1, 0.1))

	# Смещение полос интерференции от концентрации газа в рабочей кювете
	# CO2 смещает полосы вправо, CH4 влево
	var effective_shift: float = (chamber_co2 * 22.0 - chamber_ch4 * 18.0) * (float(pump_strokes) / 5.0) + zero_offset
	var fringe_x1 := center.x - 14.0 + effective_shift
	var fringe_x2 := center.x + 14.0 + effective_shift

	# АНОМАЛИЯ «ОТЗВУК» / ЫРКА: Полосы интерференции изгибаются в вертикальный кошачий/человеческий зрачок!
	if _pupil_warp > 0.01:
		var pulse := 0.85 + 0.15 * sin(_time_t * 3.5)
		var curve_pts1: PackedVector2Array = []
		var curve_pts2: PackedVector2Array = []
		var steps := 24
		for st in range(steps + 1):
			var fy := spec_rect.position.y + (float(st) / float(steps)) * spec_h
			var ny := (fy - center.y) / (spec_h * 0.5)
			# Формула зрачка: выпуклость наружу в центре
			var bulge := cos(ny * PI * 0.5) * (32.0 * _pupil_warp * pulse)
			curve_pts1.append(Vector2(center.x - 6.0 - bulge, fy))
			curve_pts2.append(Vector2(center.x + 6.0 + bulge, fy))

		# Чёрные полосы искажённого зрачка
		for st in range(steps):
			_eyepiece_canvas.draw_line(curve_pts1[st], curve_pts1[st + 1], Color(0.02, 0.02, 0.02), 3.5)
			_eyepiece_canvas.draw_line(curve_pts2[st], curve_pts2[st + 1], Color(0.02, 0.02, 0.02), 3.5)

		# Внутри зрачка — неестественная абсолютная чернота
		_reading_lbl.text = Loc.t(&"shi11.reading_anomaly")
		_reading_lbl.modulate = Color(1.0, 0.3, 0.3)
	else:
		# Обычные 2 вертикальные черные интерференционные полосы ШИ-11
		_eyepiece_canvas.draw_line(Vector2(fringe_x1, spec_rect.position.y), Vector2(fringe_x1, spec_rect.end.y), Color(0.02, 0.02, 0.02), 3.0)
		_eyepiece_canvas.draw_line(Vector2(fringe_x2, spec_rect.position.y), Vector2(fringe_x2, spec_rect.end.y), Color(0.02, 0.02, 0.02), 3.0)

	# Круговая диафрагма-маска (виньетирование окуляра)
	_eyepiece_canvas.draw_arc(center, r + 1.0, 0, TAU, 64, Color(0.08, 0.09, 0.08), 8.0)


func _on_squeeze_bulb() -> void:
	pump_strokes = mini(pump_strokes + 1, 5)
	AudioDirector.play_raw("res://assets/audio/stove_add.ogg", -6.0)
	Game.vibrate(0.2, 0.1, 0.15)
	_detect_environment()
	_status_lbl.text = "ГРУША: %d/5 ПРОКАЧЕК • КАМЕРА %s" % [pump_strokes, "ЗАПОЛНЕНА" if pump_strokes == 5 else "ПРОДУВАЕТСЯ"]

	if pump_strokes == 5:
		if _near_yrka_or_anomaly:
			_reading_lbl.text = Loc.t(&"shi11.reading_anomaly")
		elif chamber_co2 > 1.5:
			_reading_lbl.text = Loc.t(&"shi11.reading_co2")
		elif chamber_ch4 > 1.0:
			_reading_lbl.text = Loc.t(&"shi11.reading_ch4")
		else:
			_reading_lbl.text = Loc.t(&"shi11.reading_fresh")


func _on_zero_calibrate() -> void:
	zero_offset = 0.0
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
	_reading_lbl.text = "Микрометрический винт: нулевые полосы совмещены с риской 0.0%."


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
