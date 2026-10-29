class_name SeismographUI
extends Control
## Советский сейсмоприемник СВ-20 («Слухач»):
## При надевании наушников комната погружается в глухой вакуум (LowPass 220 Гц).
## Дежурный видит и слышит подземные колебания, шаги под мерзлотой и вектор угрозы.

signal closed

var _canvas: Control
var _status_label: Label
var _amp_label: Label
var _warning_label: Label
var _history: Array[float] = []
var _time_t := 0.0
var _thump_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.set_sv20(true)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel()
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -460, -290, 460, 290)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Заголовок
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)
	top_bar.add_child(UiStyle.brass_plate(Loc.t(&"sv20.title"), 17))

	top_bar.add_spacer(false)
	var close_btn := UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(close_btn)
	close_btn.grab_focus.call_deferred()

	var sub := UiKit.label(Loc.t(&"sv20.sub"), 13)
	sub.modulate = Color(1, 1, 1, 0.65)
	root_vbox.add_child(sub)

	# Экран самописца (барабан сейсмограммы)
	var drum_panel := PanelContainer.new()
	drum_panel.custom_minimum_size = Vector2(880, 260)
	root_vbox.add_child(drum_panel)

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_seismogram)
	drum_panel.add_child(_canvas)

	# Статусный блок
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 6)
	root_vbox.add_child(status_box)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 16)
	status_box.add_child(stat_row)

	_amp_label = UiKit.label(Loc.p("СИЛА КОЛЕБАНИЙ: 0.2 мм/с²", "VIBRATION: 0.2 mm/s²"), 14)
	_amp_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	stat_row.add_child(_amp_label)

	_status_label = UiKit.label("", 15)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(_status_label)

	_warning_label = UiKit.label(Loc.t(&"sv20.warning_deaf"), 13)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	status_box.add_child(_warning_label)

	# Нижняя кнопка возврата
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(bottom_row)
	bottom_row.add_child(UiKit.button(Loc.t(&"sv20.btn_remove"), _close))

	# Инициализация истории сейсмограммы
	for i in range(120):
		_history.append(0.0)


func _process(delta: float) -> void:
	_time_t += delta
	_thump_timer -= delta

	var st := Game.get_seismic_status()
	var base_amp: float = st.amplitude
	_amp_label.text = Loc.p("СИЛА КОЛЕБАНИЙ: %.1f мм/с²", "VIBRATION: %.1f mm/s²") % [base_amp]
	_status_label.text = st.text

	if bool(st.get("alert", false)):
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2) if int(_time_t * 4.0) % 2 == 0 else Color(1.0, 0.9, 0.4))
		# Периодические подземные удары в наушниках
		if _thump_timer <= 0.0:
			_thump_timer = 1.1
			if Game.audio != null:
				Game.audio.play_3d("res://assets/audio/clank.ogg", Game.player.global_position + Vector3(0, -2.0, 0), 2.0, 6.0)
			Game.vibrate(0.4, 0.65, 0.35)
	elif bool(st.get("warning", false)):
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
		if _thump_timer <= 0.0:
			_thump_timer = 2.2
			Game.vibrate(0.18, 0.12, 0.2)
	else:
		_status_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))

	# Сдвиг и добавление точки в график
	var noise := sin(_time_t * 18.0) * (base_amp * 0.15) + (randf() - 0.5) * (base_amp * 0.2)
	if st.vector == "otzvuk":
		# 4 Гц резкие пики
		if sin(_time_t * 4.0 * TAU) > 0.85:
			noise += base_amp * 0.85
	elif st.alert:
		if sin(_time_t * 1.8 * TAU) > 0.7:
			noise += (randf() - 0.5) * base_amp * 1.6

	_history.pop_front()
	_history.append(noise)
	_canvas.queue_redraw()


func _draw_seismogram() -> void:
	var rect := _canvas.get_rect()
	var w := rect.size.x
	var h := rect.size.y
	var mid_y := h * 0.5

	# Темно-зеленый фон советского осциллографа
	_canvas.draw_rect(rect, Color(0.04, 0.08, 0.05, 0.95))

	# Сетка миллиметровки
	for y_step in range(1, 6):
		var y := h * (float(y_step) / 6.0)
		_canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(0.12, 0.22, 0.14, 0.5), 1.0)
	for x_step in range(1, 12):
		var x := w * (float(x_step) / 12.0)
		_canvas.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.12, 0.22, 0.14, 0.4), 1.0)

	# Центральная нулевая ось
	_canvas.draw_line(Vector2(0, mid_y), Vector2(w, mid_y), Color(0.2, 0.45, 0.25, 0.7), 1.5)

	# Отрисовка кривой пера
	var step_x := w / float(_history.size() - 1)
	var prev_pt := Vector2(0, mid_y + _history[0] * 12.0)
	var col := Color(0.35, 1.0, 0.45)
	for i in range(1, _history.size()):
		var cur_pt := Vector2(float(i) * step_x, clampf(mid_y + _history[i] * 12.0, 6.0, h - 6.0))
		_canvas.draw_line(prev_pt, cur_pt, col, 1.8)
		prev_pt = cur_pt


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"pause"):
		_close()
		return true
	if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE):
		_close()
		return true
	return false


func _close() -> void:
	Game.set_sv20(false)
	closed.emit()
