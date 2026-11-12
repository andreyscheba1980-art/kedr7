class_name GeneratorDGA24UI
extends Control
## Аутентичный советский щит управления ДГА-24М и дизель 4Ч 10.5/13 (1983 г.).
## Все переменные состояния хранятся в Game (сбрасываются в Game.setup_phase / SaveGame).
## Единственный источник 3D-звука дизеля — AudioStreamPlayer3D в Station (без дублирования в UI).

signal closed
signal starter_engaged
signal engine_started
signal engine_stopped
signal breaker_toggled(engaged: bool)

var _time_t: float = 0.0
var _glow_heat: float = 0.0
var _starter_active: bool = false
var _starter_timer: float = 0.0
var _crank_rpm: float = 0.0
var _engine_rpm: float = 0.0

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


func _is_hot_mode() -> bool:
	return Game.dga_engine_temp >= 15.0 or Game.is_story()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0:
		Game.dga_engine_running = true
		Game.dga_ap50_engaged = true
		_engine_rpm = 1500.0
		Game.dga_oil_pressure = maxf(Game.dga_oil_pressure, 3.0)
	elif Game.dga_engine_running:
		_engine_rpm = 1200.0

	# Режим «Повесть» или тёплый блок: подготовительные тумблеры выставлены для быстрого пуска в 2 клика
	if not Game.dga_engine_running and _is_hot_mode():
		Game.dga_switches["etf3"] = true
		Game.dga_switches["decomp"] = false
		if Game.is_story():
			Game.dga_switches["pl64"] = false
			Game.dga_switches["sn150"] = false
			Game.dga_oil_pressure = maxf(Game.dga_oil_pressure, 2.2)
			_glow_heat = 0.85

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

	var sub := UiKit.label(Loc.p(
		"ЩСУ-24 · ДИЗЕЛЬ 4Ч 10.5/13 · ГЕНЕРАТОР ЕСС5-62-4У2 (24 кВт · 220/380 В)",
		"ShSU-24 · DIESEL 4Ch 10.5/13 · GENERATOR ESS5-62-4U2 (24 kW · 220/380V)"
	), 12)
	sub.modulate = Color(0.75, 0.82, 0.75, 0.8)
	root_vbox.add_child(sub)

	# Верхняя секция: Приборы ЩСУ-24
	var upper_panel := PanelContainer.new()
	upper_panel.custom_minimum_size = Vector2(960, 210)
	root_vbox.add_child(upper_panel)

	var hbox_meters := HBoxContainer.new()
	hbox_meters.add_theme_constant_override("separation", 14)
	upper_panel.add_child(hbox_meters)

	_canvas_gauges = Control.new()
	_canvas_gauges.custom_minimum_size = Vector2(480, 200)
	_canvas_gauges.draw.connect(_draw_gauges)
	hbox_meters.add_child(_canvas_gauges)

	# «Соляной глаз»
	var eye_box := VBoxContainer.new()
	eye_box.custom_minimum_size = Vector2(110, 190)
	eye_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_meters.add_child(eye_box)
	var eye_title := UiKit.label(Loc.p("СОЛЯНОЙ ГЛАЗ\n(СВЕЧИ СН-150)", "SALT EYE\n(GLOW SN-150)"), 10)
	eye_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eye_box.add_child(eye_title)

	_salt_eye_rect = ColorRect.new()
	_salt_eye_rect.custom_minimum_size = Vector2(60, 60)
	_salt_eye_rect.color = Color(0.12, 0.10, 0.08)
	var eye_center := CenterContainer.new()
	eye_center.add_child(_salt_eye_rect)
	eye_box.add_child(eye_center)

	var eye_status := UiKit.label(Loc.p("НИХРОМ", "NICHROME"), 9)
	eye_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eye_status.modulate = Color(0.6, 0.6, 0.6)
	eye_box.add_child(eye_status)

	# Виброчастотомер В85
	var v85_box := VBoxContainer.new()
	v85_box.custom_minimum_size = Vector2(320, 190)
	hbox_meters.add_child(v85_box)
	var v85_title := UiKit.label(Loc.p("ВИБРОЧАСТОТОМЕР В85 (45...55 Гц)", "REED FREQ METER V85 (45...55 Hz)"), 11)
	v85_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v85_box.add_child(v85_title)

	_v85_canvas = Control.new()
	_v85_canvas.custom_minimum_size = Vector2(310, 150)
	_v85_canvas.draw.connect(_draw_v85_reeds)
	v85_box.add_child(_v85_canvas)

	# Информационная строка
	var info_panel := HBoxContainer.new()
	root_vbox.add_child(info_panel)
	_status_lbl = UiKit.label("", 13)
	info_panel.add_child(_status_lbl)
	info_panel.add_spacer(false)
	_oil_lbl = UiKit.label("", 13)
	info_panel.add_child(_oil_lbl)

	# Кнопки управления
	var grid_btns := GridContainer.new()
	grid_btns.columns = 3
	grid_btns.add_theme_constant_override("h_separation", 10)
	grid_btns.add_theme_constant_override("v_separation", 6)
	root_vbox.add_child(grid_btns)

	_btn_torch = UiKit.button(Loc.t(&"dga24.blowtorch_heat"), _on_toggle_blowtorch)
	grid_btns.add_child(_btn_torch)

	_btn_pump = UiKit.button(Loc.t(&"dga24.rnm1_pump"), _on_pump_rnm1)
	grid_btns.add_child(_btn_pump)

	_btn_decompr = UiKit.button("", _on_toggle_decompressor)
	grid_btns.add_child(_btn_decompr)

	_btn_glow = UiKit.button(Loc.t(&"dga24.glow_plugs"), _on_toggle_glow)
	grid_btns.add_child(_btn_glow)

	_btn_starter = UiKit.button(Loc.t(&"dga24.starter_crank"), _on_starter_pressed)
	grid_btns.add_child(_btn_starter)

	_btn_drain = UiKit.button("", _on_toggle_etf3)
	grid_btns.add_child(_btn_drain)

	# Нижняя панель
	var bot_box := HBoxContainer.new()
	bot_box.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_box)

	_btn_ap50 = UiKit.button(Loc.t(&"dga24.ap50_breaker"), _on_toggle_ap50)
	_btn_ap50.custom_minimum_size = Vector2(360, 42)
	bot_box.add_child(_btn_ap50)

	_action_lbl = UiKit.label("", 12)
	_action_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_lbl.modulate = Color(0.9, 0.85, 0.5)
	bot_box.add_child(_action_lbl)

	if Game.is_story():
		_action_lbl.text = Loc.t(&"dga24.story_hint")
	elif Game.dga_engine_temp >= 15.0:
		_action_lbl.text = Loc.t(&"dga24.hot_hint", [int(roundf(Game.dga_engine_temp))])
	else:
		_action_lbl.text = Loc.t(&"dga24.cold_hint", [int(roundf(Game.dga_engine_temp))])

	_update_ui_state()


func _process(delta: float) -> void:
	_time_t += delta

	# 1. Подогреватель ПЛ-64
	if bool(Game.dga_switches.get("pl64", false)) and not Game.dga_engine_running:
		Game.dga_engine_temp = minf(Game.dga_engine_temp + delta * 9.5, 25.0)
		Game.dga_pl64_used_before_start = true
		if randf() < delta * 1.3 and Game.player != null:
			Game.audio.play_3d("res://assets/audio/stove_add.ogg", Game.player.global_position, -9.0, 5.0)

	# 2. Накал свечей СН-150 («Соляной глаз»)
	if bool(Game.dga_switches.get("sn150", false)):
		_glow_heat = minf(_glow_heat + delta * 0.35, 1.0)
	else:
		_glow_heat = maxf(_glow_heat - delta * 0.18, 0.0)
	_salt_eye_rect.color = Color(0.12, 0.10, 0.08).lerp(Color(1.0, 0.16, 0.0), _glow_heat)

	# 3. Стартер СТ-721
	if _starter_active:
		_starter_timer -= delta
		if _starter_timer <= 0.0:
			_starter_active = false
		elif Game.generator_fuel <= 0.5:
			_crank_rpm = 180.0
		elif Game.dga_filter_clogged:
			_crank_rpm = 160.0
		elif Game.dga_engine_temp < -5.0 and not Game.is_story():
			_crank_rpm = 0.0
		elif bool(Game.dga_switches.get("decomp", false)) or _is_hot_mode():
			_crank_rpm = minf(_crank_rpm + delta * 260.0, 280.0)
			if _is_hot_mode() and _crank_rpm >= 190.0 and not Game.dga_engine_running:
				_catch_diesel()
		else:
			_crank_rpm = 35.0
	else:
		_crank_rpm = maxf(_crank_rpm - delta * 200.0, 0.0)

	# 4. Двигатель работает
	if Game.dga_engine_running and Game.generator_fuel > 0.0 and not Game.dga_filter_clogged:
		var target_rpm := 1500.0 if Game.dga_ap50_engaged else 1180.0
		_engine_rpm = move_toward(_engine_rpm, target_rpm, delta * 360.0)
		Game.dga_oil_pressure = move_toward(Game.dga_oil_pressure, 3.2, delta * 0.8)
	else:
		if Game.dga_engine_running and (Game.generator_fuel <= 0.0 or Game.dga_filter_clogged):
			Game.dga_engine_running = false
			Game.dga_ap50_engaged = false
			Game.set_power(false)
			engine_stopped.emit()
		if not _starter_active:
			_engine_rpm = maxf(_engine_rpm - delta * 420.0, 0.0)
		Game.dga_oil_pressure = maxf(Game.dga_oil_pressure - delta * 0.04, 0.0)

	_oil_lbl.text = Loc.p(
		"БЛОК: %.1f°C · ТОПЛИВО: %d%% · МАСЛО: %.2f кгс/см²",
		"BLOCK: %.1f°C · FUEL: %d%% · OIL: %.2f kgf/cm²"
	) % [Game.dga_engine_temp, int(roundf(Game.generator_fuel)), Game.dga_oil_pressure]
	_update_ui_state()
	_canvas_gauges.queue_redraw()
	_v85_canvas.queue_redraw()


func _draw_gauges() -> void:
	var centers := [Vector2(80, 100), Vector2(240, 100), Vector2(400, 100)]
	var titles := [
		Loc.p("МД-214 (МАСЛО)", "MD-214 (OIL)"),
		Loc.p("Э377 (НАПРЯЖЕНИЕ)", "E377 (VOLTAGE)"),
		Loc.p("Э378 (ТОК СЕТИ)", "E378 (LOAD AMPS)")
	]
	var r: float = 65.0

	for i in range(3):
		var cp: Vector2 = centers[i]
		_canvas_gauges.draw_circle(cp, r + 4.0, Color(0.2, 0.22, 0.2))
		_canvas_gauges.draw_circle(cp, r, Color(0.08, 0.09, 0.07))
		_canvas_gauges.draw_circle(cp, r - 3.0, Color(0.88, 0.86, 0.80))

		for k in range(11):
			var a := deg_to_rad(135.0 + float(k) * 27.0)
			var p1 := cp + Vector2(cos(a), sin(a)) * (r - 6.0)
			var p2 := cp + Vector2(cos(a), sin(a)) * (r - (14.0 if k % 2 == 0 else 10.0))
			_canvas_gauges.draw_line(p1, p2, Color(0.15, 0.15, 0.15), 1.5 if k % 2 == 0 else 1.0)

		var val_norm: float = 0.0
		if i == 0:
			val_norm = clampf(Game.dga_oil_pressure / 6.0, 0.0, 1.0)
		elif i == 1:
			var target_v := 220.0 * (_engine_rpm / 1500.0)
			val_norm = clampf(target_v / 250.0, 0.0, 1.0)
		elif i == 2:
			var target_a := 18.0 if Game.power_on else 0.0
			val_norm = clampf(target_a / 50.0, 0.0, 1.0)

		var needle_a := deg_to_rad(135.0 + val_norm * 270.0)
		var needle_end := cp + Vector2(cos(needle_a), sin(needle_a)) * (r - 12.0)
		_canvas_gauges.draw_line(cp, needle_end, Color(0.85, 0.1, 0.1), 2.0)
		_canvas_gauges.draw_circle(cp, 4.0, Color(0.2, 0.2, 0.2))

		_canvas_gauges.draw_string(ThemeDB.fallback_font, cp + Vector2(-60, 82), titles[i], HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.9, 0.9, 0.9))


func _draw_v85_reeds() -> void:
	var w: float = 300.0
	var h: float = 140.0
	_v85_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.06, 0.07, 0.06))
	_v85_canvas.draw_rect(Rect2(4, 4, w - 8, h - 8), Color(0.12, 0.14, 0.12))

	var current_freq: float = (_engine_rpm / 1500.0) * 50.0
	var reed_count: int = 21

	for idx in range(reed_count):
		var freq_val: float = 45.0 + float(idx) * 0.5
		var rx: float = 18.0 + float(idx) * 12.8
		var ry_base: float = h - 25.0

		var diff := absf(current_freq - freq_val)
		var vib_amp: float = 0.0
		if Game.dga_engine_running and diff < 1.2:
			vib_amp = (1.0 - (diff / 1.2)) * 36.0
			vib_amp *= (0.8 + 0.2 * sin(_time_t * 60.0 + float(idx)))

		var reed_len: float = 65.0 + vib_amp
		var reed_col := Color(0.75, 0.75, 0.8) if idx != 10 else Color(1.0, 0.95, 0.7)
		_v85_canvas.draw_line(Vector2(rx, ry_base), Vector2(rx, ry_base - reed_len), reed_col, 2.0)
		_v85_canvas.draw_rect(Rect2(rx - 3, ry_base - reed_len - 6, 6, 8 + (vib_amp * 0.4)), Color(0.95, 0.95, 0.95))

		if idx % 2 == 0:
			_v85_canvas.draw_string(ThemeDB.fallback_font, Vector2(rx - 8, h - 8), "%.0f" % freq_val, HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Color(0.8, 0.8, 0.8))


func _on_toggle_blowtorch() -> void:
	var on := not bool(Game.dga_switches.get("pl64", false))
	Game.dga_switches["pl64"] = on
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
	_action_lbl.text = Loc.p("Паяльная лампа ПЛ-64 греет жаровую трубу картера.", "PL-64 blowtorch warming oil sump heat tube.") if on else Loc.p("Паяльная лампа ПЛ-64 выключена.", "PL-64 blowtorch off.")


func _on_pump_rnm1() -> void:
	Game.dga_oil_pressure = minf(Game.dga_oil_pressure + 0.55, 3.0)
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
	if Game.dga_oil_pressure >= 1.5:
		_action_lbl.text = Loc.p("Давление масла %.1f кгс/см² — подшипники смазаны.", "Oil pressure %.1f kgf/cm² — bearings primed.") % Game.dga_oil_pressure
	else:
		_action_lbl.text = Loc.p("Качайте ещё! Давление %.1f кгс/см² (норма >= 1.5).", "Keep pumping! Oil %.1f kgf/cm² (min 1.5).") % Game.dga_oil_pressure


func _on_toggle_decompressor() -> void:
	var decomp := not bool(Game.dga_switches.get("decomp", false))
	Game.dga_switches["decomp"] = decomp
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 0.0)
	if decomp:
		_action_lbl.text = Loc.p("Декомпрессор ОТКРЫТ: клапаны разгружены для раскрутки маховика.", "Decompressor OPEN: valves unloaded for flywheel spin-up.")
	else:
		_action_lbl.text = Loc.p("Декомпрессор в РАБОТЕ: цилиндры под полной компрессией!", "Decompressor in RUN: full cylinder compression!")
		if _starter_active and _crank_rpm >= 160.0 and (_glow_heat >= 0.35 or _is_hot_mode()) and Game.dga_oil_pressure >= 1.2:
			_catch_diesel()


func _on_toggle_glow() -> void:
	var on := not bool(Game.dga_switches.get("sn150", false))
	Game.dga_switches["sn150"] = on
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -6.0)
	_action_lbl.text = Loc.p("Спирали накала СН-150 включены — грейте «Соляной глаз».", "SN-150 glow plugs ON — watch the Salt Eye.") if on else Loc.p("Накал свечей отключён.", "Glow plugs OFF.")


func _on_toggle_etf3() -> void:
	var on := not bool(Game.dga_switches.get("etf3", false))
	Game.dga_switches["etf3"] = on
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 0.0)
	if Game.dga_filter_clogged:
		_action_lbl.text = Loc.t(&"dga24.err_filter_clogged")
	else:
		_action_lbl.text = Loc.p("Топливный кран ЭТФ-3 открыт.", "ETF-3 fuel valve opened.") if on else Loc.p("Топливный кран ЭТФ-3 закрыт.", "ETF-3 fuel valve closed.")


func _on_starter_pressed() -> void:
	if Game.dga_engine_running:
		_action_lbl.text = Loc.p("Дизель уже работает! Включите автомат АП-50 [7].", "Diesel already running! Engage AP-50 breaker [7].")
		return
	if Game.generator_fuel <= 0.5:
		AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", 2.0)
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
		_action_lbl.text = Loc.t(&"dga24.err_no_fuel")
		return
	if Game.dga_filter_clogged:
		AudioDirector.play_raw("res://assets/audio/generator_sputter.ogg", 0.0)
		_action_lbl.text = Loc.t(&"dga24.err_filter_clogged")
		return
	if not bool(Game.dga_switches.get("etf3", false)):
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -3.0)
		_action_lbl.text = Loc.p("Сначала откройте топливный кран ЭТФ-3 [6]!", "Open ETF-3 fuel valve [6] first!")
		return
	if Game.dga_engine_temp < -5.0 and not Game.is_story():
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
		_action_lbl.text = Loc.t(&"dga24.thick_oil_warn")
		return
	if Game.dga_oil_pressure < 1.2 and not _is_hot_mode():
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
		_action_lbl.text = Loc.t(&"dga24.no_oil_pressure")
		return
	if not bool(Game.dga_switches.get("decomp", false)) and not _is_hot_mode():
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
		_action_lbl.text = Loc.t(&"dga24.no_decompr")
		return

	_starter_active = true
	_starter_timer = 1.6 if _is_hot_mode() else 4.0
	starter_engaged.emit()
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 1.0)
	if _is_hot_mode():
		_action_lbl.text = Loc.p("Стартер СТ-721 крутит прогретый дизель...", "Starter ST-721 cranking warm diesel...")
	else:
		_action_lbl.text = Loc.p("Стартер СТ-721 раскручивает маховик! Переведите декомпрессор [3] в РАБОТУ!", "Starter cranking flywheel! Throw decompressor [3] to RUN!")


func _catch_diesel() -> void:
	Game.dga_engine_running = true
	Game.dga_switches["pl64"] = false
	Game.dga_switches["sn150"] = false
	Game.dga_switches["decomp"] = false
	_starter_active = false
	_crank_rpm = 0.0
	AudioDirector.play_raw("res://assets/audio/generator_sputter.ogg", 1.5)
	Game.vibrate(0.5, 0.3, 0.4)
	engine_started.emit()
	_action_lbl.text = Loc.p("Дизель 4Ч запущен! Замкните автомат АП-50 [7] для подачи 220 В в станцию.", "4Ch diesel running! Close AP-50 breaker [7] to power the station.")


func _on_toggle_ap50() -> void:
	if not Game.dga_engine_running:
		_action_lbl.text = Loc.p("Нельзя включить АП-50: сначала запустите дизель стартером СТ-721 [5].", "Cannot close AP-50: start the diesel with ST-721 [5] first.")
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
		return
	if Game.gen_broken:
		_action_lbl.text = Loc.p("Генератор повреждён! Отремонтируйте корпус инструментами.", "Generator broken! Repair the unit body with tools.")
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
		return
	var next_on := not Game.power_on
	Game.dga_ap50_engaged = next_on
	Game.set_power(next_on)
	breaker_toggled.emit(next_on)
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 4.0)
	if next_on:
		Game.hud.subtitle(Loc.t(&"dga24.started_ok"), 4.5)
		_action_lbl.text = Loc.p("Автомат АП-50 замкнут! Сеть 220 В подана в станцию.", "AP-50 breaker closed! 220V power supplied to station.")
	else:
		_action_lbl.text = Loc.p("Автомат АП-50 разомкнут — дизель работает на холостом ходу.", "AP-50 breaker opened — diesel idling.")


func _update_ui_state() -> void:
	var pl_on := bool(Game.dga_switches.get("pl64", false))
	var dec_on := bool(Game.dga_switches.get("decomp", false))
	var glow_on := bool(Game.dga_switches.get("sn150", false))
	var etf_on := bool(Game.dga_switches.get("etf3", false))

	_btn_torch.text = Loc.p("[1] ПЛ-64: ГРЕЕТ КАРТЕР", "[1] PL-64: HEATING SUMP") if pl_on else Loc.p("[1] ПЛ-64: ПОТУШЕНА", "[1] PL-64: OFF")
	_btn_decompr.text = Loc.t(&"dga24.decompr_toggle", [Loc.p("ДЕКОМПРЕССИЯ", "OPEN") if dec_on else Loc.p("РАБОТА", "RUN")])
	_btn_glow.text = Loc.p("[4] СН-150: ВКЛ", "[4] SN-150: ON") if glow_on else Loc.p("[4] СН-150: ВЫКЛ", "[4] SN-150: OFF")
	_btn_drain.text = Loc.p("[6] Кран ЭТФ-3: ОТКРЫТ", "[6] ETF-3 Valve: OPEN") if etf_on else Loc.p("[6] Кран ЭТФ-3: ЗАКРЫТ", "[6] ETF-3 Valve: CLOSED")
	_btn_ap50.text = Loc.p("[7] АП-50: СЕТЬ 220 В ВКЛ [20 А]", "[7] AP-50: 220V ONLINE [20A]") if Game.power_on else Loc.p("[7] АП-50: СЕТЬ ОТКЛЮЧЕНА", "[7] AP-50: GRID OFFLINE")
	_status_lbl.text = Loc.p("СТАТУС: РАБОТАЕТ (%d ОБ/МИН)", "STATUS: RUNNING (%d RPM)") % int(roundf(_engine_rpm)) if Game.dga_engine_running else Loc.p("СТАТУС: ОСТАНОВЛЕН", "STATUS: STOPPED")


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
				_on_toggle_etf3()
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
