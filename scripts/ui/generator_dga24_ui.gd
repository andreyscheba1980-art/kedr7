class_name GeneratorDGA24UI
extends Control
## Аутентичный советский щит управления ДГА-24М и дизель 4Ч 10.5/13 (1983 г.):
## Протокол холодного пуска при -43°C:
## 1. Прогрев картера паяльной лампой ПЛ-64 (масло МС-20 до +15°C)
## 2. Ручной масляный насос РНМ-1 (давление по манометру МД-214 >= 1.5 кгс/см²)
## 3. Рычаг декомпрессора (сброс компрессии)
## 4. Накал спиральных свечей СН-150 («Соляной глаз» вишнёвый #FF2A00)
## 5. Электростартер СТ-721 (24 В, 8 л.с., раскрутка маховика до 280 об/мин)
## 6. Бросок декомпрессора в «РАБОТУ» (подхват компрессии, 1500 об/мин)
## 7. Слив конденсата из фильтра ЭТФ-3 и подкачка РНП (при перемерзании)
## 8. Виброчастотомер В85 (21 язычок, 50.0 Гц) и автомат АП-50 (включение сети 220 В)

signal closed

# Состояние ДГА-24 (сохраняется в сессии)
static var oil_temp: float = -43.0
static var oil_pressure: float = 0.0
static var decompressor_open: bool = false
static var glow_plugs_active: bool = false
static var glow_heat: float = 0.0
static var starter_engaged: bool = false
static var crank_rpm: float = 0.0
static var engine_running: bool = false
static var engine_rpm: float = 0.0
static var filter_iced: bool = true
static var filter_drained: bool = false
static var blowtorch_heating: bool = false

var _time_t: float = 0.0
var _canvas_gauges: Control
var _status_lbl: Label
var _oil_lbl: Label
var _action_lbl: Label
var _salt_eye_rect: ColorRect
var _v85_canvas: Control

var _btn_torch: Button
var _btn_pump: Button
var _btn_decompr: Button
var _btn_glow: Button
var _btn_starter: Button
var _btn_drain: Button
var _btn_ap50: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0:
		engine_running = true
		engine_rpm = 1500.0
		oil_temp = 45.0
		oil_pressure = 3.5
		filter_iced = false
		filter_drained = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel()
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -500, -320, 500, 320)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# Заголовок
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)
	top_bar.add_child(UiStyle.brass_plate(Loc.t(&"dga24.title"), 16))
	top_bar.add_spacer(false)
	var close_btn := UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(close_btn)

	var sub := UiKit.label("ЩСУ-24 • ДИЗЕЛЬ 4Ч 10.5/13 • ГЕНЕРАТОР ЕСС5-62-4У2 (24 кВт • 220/380 В)", 12)
	sub.modulate = Color(0.75, 0.82, 0.75, 0.8)
	root_vbox.add_child(sub)

	# Верхняя секция: Приборы ЩСУ-24 (Вольтметр Э377, Манометр МД-214, Соляной глаз, Виброчастотомер В85)
	var upper_panel := PanelContainer.new()
	upper_panel.custom_minimum_size = Vector2(960, 210)
	root_vbox.add_child(upper_panel)

	var hbox_meters := HBoxContainer.new()
	hbox_meters.add_theme_constant_override("separation", 14)
	upper_panel.add_child(hbox_meters)

	# 1. Круглые стрелочные приборы (Манометр МД-214, Вольтметр Э377, Амперметр Э378)
	_canvas_gauges = Control.new()
	_canvas_gauges.custom_minimum_size = Vector2(480, 200)
	_canvas_gauges.draw.connect(_draw_gauges)
	hbox_meters.add_child(_canvas_gauges)

	# 2. Блок накала: «Соляной глаз» (спираль накаливания СН-150)
	var eye_box := VBoxContainer.new()
	eye_box.custom_minimum_size = Vector2(110, 190)
	eye_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_meters.add_child(eye_box)
	var eye_title := UiKit.label("СОЛЯНОЙ ГЛАЗ\n(СВЕЧИ СН-150)", 10)
	eye_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eye_box.add_child(eye_title)

	_salt_eye_rect = ColorRect.new()
	_salt_eye_rect.custom_minimum_size = Vector2(60, 60)
	_salt_eye_rect.color = Color(0.12, 0.10, 0.08)
	var eye_center := CenterContainer.new()
	eye_center.add_child(_salt_eye_rect)
	eye_box.add_child(eye_center)

	var eye_status := UiKit.label("НИХРОМ", 9)
	eye_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eye_status.modulate = Color(0.6, 0.6, 0.6)
	eye_box.add_child(eye_status)

	# 3. Виброчастотомер В85 (21 стальной язычок 45–55 Гц)
	var v85_box := VBoxContainer.new()
	v85_box.custom_minimum_size = Vector2(320, 190)
	hbox_meters.add_child(v85_box)
	var v85_title := UiKit.label("ВИБРОЧАСТОТОМЕР В85 (45...55 Гц)", 11)
	v85_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v85_box.add_child(v85_title)

	_v85_canvas = Control.new()
	_v85_canvas.custom_minimum_size = Vector2(310, 150)
	_v85_canvas.draw.connect(_draw_v85_reeds)
	v85_box.add_child(_v85_canvas)

	# Информационная строка
	var info_panel := HBoxContainer.new()
	root_vbox.add_child(info_panel)
	_status_lbl = UiKit.label("СТАТУС: ОСТАНОВЛЕН", 13)
	info_panel.add_child(_status_lbl)
	info_panel.add_spacer(false)
	_oil_lbl = UiKit.label("МАСЛО МС-20: -43.0°C | ДАВЛЕНИЕ: 0.0 кгс/см²", 13)
	info_panel.add_child(_oil_lbl)

	# Кнопки управления (Тактические шаги советского регламента)
	var grid_btns := GridContainer.new()
	grid_btns.columns = 3
	grid_btns.add_theme_constant_override("h_separation", 10)
	grid_btns.add_theme_constant_override("v_separation", 6)
	root_vbox.add_child(grid_btns)

	_btn_torch = UiKit.button(Loc.t(&"dga24.blowtorch_heat"), _on_toggle_blowtorch)
	grid_btns.add_child(_btn_torch)

	_btn_pump = UiKit.button(Loc.t(&"dga24.rnm1_pump"), _on_pump_rnm1)
	grid_btns.add_child(_btn_pump)

	_btn_decompr = UiKit.button(Loc.t(&"dga24.decompr_toggle", ["РАБОТА"]), _on_toggle_decompressor)
	grid_btns.add_child(_btn_decompr)

	_btn_glow = UiKit.button(Loc.t(&"dga24.glow_plugs"), _on_toggle_glow)
	grid_btns.add_child(_btn_glow)

	_btn_starter = UiKit.button(Loc.t(&"dga24.starter_crank"), _on_starter_pressed)
	grid_btns.add_child(_btn_starter)

	_btn_drain = UiKit.button(Loc.t(&"dga24.drain_filter"), _on_drain_filter)
	grid_btns.add_child(_btn_drain)

	# Нижняя панель: Автомат АП-50 и оперативный лог
	var bot_box := HBoxContainer.new()
	bot_box.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_box)

	_btn_ap50 = UiKit.button(Loc.t(&"dga24.ap50_breaker"), _on_toggle_ap50)
	_btn_ap50.custom_minimum_size = Vector2(360, 42)
	bot_box.add_child(_btn_ap50)

	_action_lbl = UiKit.label("Для пуска при -43°C строго соблюдайте порядок: 1 → 2 → 3 → 4 → 5 → 3 → 7", 12)
	_action_lbl.modulate = Color(0.9, 0.85, 0.5)
	bot_box.add_child(_action_lbl)

	_update_ui_state()


func _process(delta: float) -> void:
	_time_t += delta

	# 1. Прогрев картера паяльной лампой ПЛ-64
	if blowtorch_heating:
		oil_temp = minf(oil_temp + delta * 9.5, 35.0)
		if randf() < delta * 1.5:
			Game.audio.play_3d("res://assets/audio/stove_add.ogg", Game.player.global_position, -8.0, 5.0)

	# 2. Накал свечей СН-150 (нагрев нихромовой спирали «соляного глаза»)
	if glow_plugs_active:
		glow_heat = minf(glow_heat + delta * 0.28, 1.0)
	else:
		glow_heat = maxf(glow_heat - delta * 0.20, 0.0)

	# Цвет «соляного глаза»: от тёмно-серого до вишнёво-красного #FF2A00
	var c_eye := Color(0.12, 0.10, 0.08).lerp(Color(1.0, 0.16, 0.0), glow_heat)
	_salt_eye_rect.color = c_eye

	# 3. Стартер СТ-721
	if starter_engaged:
		if oil_temp < 5.0:
			# Масло МС-20 застыло — стартер гудит под перегрузкой, но не крутит
			crank_rpm = 0.0
			_action_lbl.text = Loc.t(&"dga24.thick_oil_warn")
		elif not decompressor_open and not engine_running:
			# Нет декомпрессии — стартер захлёбывается на компрессии
			crank_rpm = 35.0
			_action_lbl.text = Loc.t(&"dga24.no_decompr")
		else:
			crank_rpm = minf(crank_rpm + delta * 140.0, 280.0)
	else:
		crank_rpm = maxf(crank_rpm - delta * 180.0, 0.0)

	# 4. Двигатель работает
	if engine_running:
		engine_rpm = move_toward(engine_rpm, 1500.0, delta * 350.0)
		oil_pressure = move_toward(oil_pressure, 3.2, delta * 0.8)
		oil_temp = move_toward(oil_temp, 55.0, delta * 1.5)

		# Если фильтр ЭТФ-3 не слит — дизель глохнет от ледяной пробки
		if filter_iced and not filter_drained:
			if _time_t > 3.5:
				engine_running = false
				engine_rpm = 0.0
				Game.set_power(false)
				AudioDirector.play_raw("res://assets/audio/generator_sputter.ogg", 0.0)
				_action_lbl.text = Loc.t(&"dga24.frozen_filter_die")
	else:
		if not starter_engaged:
			engine_rpm = maxf(engine_rpm - delta * 400.0, 0.0)
		# Медленный спад давления масла
		oil_pressure = maxf(oil_pressure - delta * 0.06, 0.0)

	_oil_lbl.text = "МАСЛО МС-20: %.1f°C | ДАВЛЕНИЕ: %.2f кгс/см²" % [oil_temp, oil_pressure]
	_canvas_gauges.queue_redraw()
	_v85_canvas.queue_redraw()


func _draw_gauges() -> void:
	# 3 круглых прибора: 1. Манометр МД-214 (0-6 кгс/см²), 2. Вольтметр Э377 (0-250 В), 3. Амперметр Э378 (0-50 А)
	var centers := [Vector2(80, 100), Vector2(240, 100), Vector2(400, 100)]
	var titles := ["МД-214 (МАСЛО)", "Э377 (НАПРЯЖЕНИЕ)", "Э378 (ТОК СЕТИ)"]
	var r: float = 65.0

	for i in range(3):
		var cp: Vector2 = centers[i]
		# Металлический безель
		_canvas_gauges.draw_circle(cp, r + 4.0, Color(0.2, 0.22, 0.2))
		_canvas_gauges.draw_circle(cp, r, Color(0.08, 0.09, 0.07))
		_canvas_gauges.draw_circle(cp, r - 3.0, Color(0.88, 0.86, 0.80)) # Бежевый советский циферблат

		# Шкала
		for k in range(11):
			var a := deg_to_rad(135.0 + float(k) * 27.0)
			var p1 := cp + Vector2(cos(a), sin(a)) * (r - 6.0)
			var p2 := cp + Vector2(cos(a), sin(a)) * (r - (14.0 if k % 2 == 0 else 10.0))
			_canvas_gauges.draw_line(p1, p2, Color(0.15, 0.15, 0.15), 1.5 if k % 2 == 0 else 1.0)

		# Значения для стрелки
		var val_norm: float = 0.0
		if i == 0:
			val_norm = clampf(oil_pressure / 6.0, 0.0, 1.0)
		elif i == 1:
			var target_v := 220.0 * (engine_rpm / 1500.0)
			val_norm = clampf(target_v / 250.0, 0.0, 1.0)
		elif i == 2:
			var target_a := 18.0 if Game.power_on else 0.0
			val_norm = clampf(target_a / 50.0, 0.0, 1.0)

		var needle_a := deg_to_rad(135.0 + val_norm * 270.0)
		var needle_end := cp + Vector2(cos(needle_a), sin(needle_a)) * (r - 12.0)
		_canvas_gauges.draw_line(cp, needle_end, Color(0.85, 0.1, 0.1), 2.0)
		_canvas_gauges.draw_circle(cp, 4.0, Color(0.2, 0.2, 0.2))

		# Подпись прибора
		_canvas_gauges.draw_string(ThemeDB.fallback_font, cp + Vector2(-60, 82), titles[i], HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.9, 0.9, 0.9))


func _draw_v85_reeds() -> void:
	# Виброчастотомер В85: 21 стальной язычок с белыми флажками (от 45.0 до 55.0 Гц с шагом 0.5 Гц)
	var w: float = 300.0
	var h: float = 140.0
	_v85_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.06, 0.07, 0.06))
	_v85_canvas.draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.12, 0.14, 0.12))

	var current_freq: float = (engine_rpm / 1500.0) * 50.0
	var reed_count: int = 21

	for idx in range(reed_count):
		var freq_val: float = 45.0 + float(idx) * 0.5
		var rx: float = 18.0 + float(idx) * 12.8
		var ry_base: float = h - 25.0

		# Амплитуда резонанса: язычок вибрирует, если частота генератора близка к его собственной
		var diff := absf(current_freq - freq_val)
		var vib_amp: float = 0.0
		if engine_running and diff < 1.2:
			vib_amp = (1.0 - (diff / 1.2)) * 36.0
			# Высокочастотное размытие полосы
			vib_amp *= (0.8 + 0.2 * sin(_time_t * 60.0 + float(idx)))

		var reed_len: float = 65.0 + vib_amp
		var reed_col := Color(0.75, 0.75, 0.8)
		if idx == 10: # 50.0 Гц — центральный язычок
			reed_col = Color(1.0, 0.95, 0.7)

		# Ножка язычка
		_v85_canvas.draw_line(Vector2(rx, ry_base), Vector2(rx, ry_base - reed_len), reed_col, 2.0)
		# Белый прямоугольный флажок на конце
		_v85_canvas.draw_rect(Rect2(rx - 3, ry_base - reed_len - 6, 6, 8 + (vib_amp * 0.4)), Color(0.95, 0.95, 0.95))

		# Подписи частот для ключевых значений
		if idx % 2 == 0:
			_v85_canvas.draw_string(ThemeDB.fallback_font, Vector2(rx - 8, h - 8), "%.0f" % freq_val, HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Color(0.8, 0.8, 0.8))


func _on_toggle_blowtorch() -> void:
	blowtorch_heating = not blowtorch_heating
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
	_btn_torch.text = "[1] Факел ПЛ-64: " + ("ГРЕЕТ КАРТЕР" if blowtorch_heating else "ПОТУШЕН")
	_action_lbl.text = "Паяльная лампа ПЛ-64 направлена в жаровую трубу картера дизеля." if blowtorch_heating else "Прогрев картера остановлен."


func _on_pump_rnm1() -> void:
	oil_pressure = minf(oil_pressure + 0.45, 2.8)
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
	if oil_pressure >= 1.5:
		_action_lbl.text = "Давление масла поднято до %.1f кгс/см²! Подшипники смазаны." % oil_pressure
	else:
		_action_lbl.text = "Качайте ещё! Давление %.1f кгс/см² (нужно не менее 1.5)." % oil_pressure


func _on_toggle_decompressor() -> void:
	decompressor_open = not decompressor_open
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 0.0)
	_btn_decompr.text = Loc.t(&"dga24.decompr_toggle", ["ДЕКОМПРЕССИЯ" if decompressor_open else "РАБОТА"])
	if decompressor_open:
		_action_lbl.text = "Декомпрессор открыт: выпускные клапаны приоткрыты, сопротивление вращению снято."
	else:
		_action_lbl.text = "Декомпрессор переведён в РАБОТУ: цилиндры под полной компрессией!"
		# Если стартер крутит маховик > 200 об/мин и свечи прогреты — подхват!
		if crank_rpm >= 180.0 and glow_heat >= 0.45 and oil_pressure >= 1.2:
			_start_engine_catch()


func _on_toggle_glow() -> void:
	glow_plugs_active = not glow_plugs_active
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -6.0)
	_btn_glow.text = "[4] Свечи СН-150: " + ("ВКЛЮЧЕНЫ" if glow_plugs_active else "ВЫКЛ")
	_action_lbl.text = "Спирали накала СН-150 включены. Следите за «Соляным глазом»." if glow_plugs_active else "Накал свечей отключен."


func _on_starter_pressed() -> void:
	if engine_running:
		_action_lbl.text = "Дизель уже запущен и работает на 1500 об/мин!"
		return
	starter_engaged = true
	AudioDirector.play_raw("res://assets/audio/engine_loop.ogg", 1.0)
	get_tree().create_timer(3.0, false).timeout.connect(func() -> void:
		starter_engaged = false
	)
	if oil_temp < 5.0:
		_action_lbl.text = Loc.t(&"dga24.thick_oil_warn")
		return
	if oil_pressure < 1.2:
		_action_lbl.text = Loc.t(&"dga24.no_oil_pressure")
		return
	if not decompressor_open:
		_action_lbl.text = Loc.t(&"dga24.no_decompr")
		return
	_action_lbl.text = "Стартер СТ-721 раскручивает маховик до 280 об/мин! Бросайте декомпрессор в РАБОТУ [3]!"


func _start_engine_catch() -> void:
	engine_running = true
	starter_engaged = false
	crank_rpm = 0.0
	_status_lbl.text = "СТАТУС: РАБОТАЕТ (1500 ОБ/МИН)"
	AudioDirector.play_raw("res://assets/audio/generator_sputter.ogg", 2.0)
	Game.vibrate(0.5, 0.3, 0.4)
	Game.hud.subtitle(Loc.t(&"dga24.started_ok"), 5.0)
	_action_lbl.text = Loc.t(&"dga24.started_ok")


func _on_drain_filter() -> void:
	filter_drained = true
	filter_iced = false
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 0.0)
	Game.audio.play_3d("res://assets/audio/snow_fall.ogg", Game.player.global_position, 0.0, 5.0)
	_action_lbl.text = "Кран ЭТФ-3 открыт 14 мм ключом: ледяная эмульсия слита, ТНВД прокачан ручным насосом РНП!"


func _on_toggle_ap50() -> void:
	if not engine_running or engine_rpm < 1400.0:
		_action_lbl.text = "Нельзя включить автомат сети! Дизель-генератор не вышел на 1500 об/мин и 50 Гц."
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
		return
	Game.set_power(true)
	Game.gen_broken = false
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 4.0)
	_action_lbl.text = "Автомат АП-50 замкнут! Сеть 220 В станции под напряжением."
	_btn_ap50.text = "[7] Автомат АП-50: СЕТЬ ПОДКЛЮЧЕНА [20 А]"


func _update_ui_state() -> void:
	_btn_decompr.text = Loc.t(&"dga24.decompr_toggle", ["ДЕКОМПРЕССИЯ" if decompressor_open else "РАБОТА"])
	_btn_torch.text = "[1] Факел ПЛ-64: " + ("ГРЕЕТ КАРТЕР" if blowtorch_heating else "ПОТУШЕН")
	_btn_glow.text = "[4] Свечи СН-150: " + ("ВКЛЮЧЕНЫ" if glow_plugs_active else "ВЫКЛ")
	_btn_ap50.text = "[7] Автомат АП-50: " + ("СЕТЬ ПОДКЛЮЧЕНА [20 А]" if Game.power_on else "СЕТЬ ОТКЛЮЧЕНА")
	_status_lbl.text = "СТАТУС: РАБОТАЕТ (1500 ОБ/МИН)" if engine_running else "СТАТУС: ОСТАНОВЛЕН"


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_close()
		return true
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_on_toggle_blowtorch()
				return true
			KEY_2:
				_on_pump_rnm1()
				return true
			KEY_3:
				_on_toggle_decompressor()
				return true
			KEY_4:
				_on_toggle_glow()
				return true
			KEY_5:
				_on_starter_pressed()
				return true
			KEY_6:
				_on_drain_filter()
				return true
			KEY_7:
				_on_toggle_ap50()
				return true
			KEY_TAB, KEY_ESCAPE, KEY_E:
				_close()
				return true
	return false


func _close() -> void:
	closed.emit()
