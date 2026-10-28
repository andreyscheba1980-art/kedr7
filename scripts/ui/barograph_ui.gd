class_name BarographUI
extends Control
## Советский суточный барограф М-22 («Дыхание станции»): лента на барабане и книжка КМ-1.
## Перо пишет давление по часам смены. Дежурный сам читает, где перо сейчас, и насколько
## давление изменилось за три часа (барическая тенденция) — и вписывает оба числа.
## Мышь над лентой кладёт линейку — по ней удобно вести к шкале. Пружину барабана заводят ключом
## (раз за ночь): кончится завод — перо встанет, и прочитать «сейчас» будет нельзя.
## На ленте видно и то, чего в воздухе не было: зубец baro_tooth, удар сигнала 03:10.

signal closed

const CLANK_SFX := "res://assets/audio/clank.ogg"
const SCRATCH_SFX := "res://assets/audio/clock_tick.ogg"
const PEN_SFX := "res://assets/audio/clank.ogg"
const HOURS_BACK := 12.0
const HOURS_AHEAD := 2.0
const MM_HALF := 13.0                   ## от центра ленты вверх/вниз, мм рт. ст.
const SIGNAL_H := 430.0 / 60.0          ## 03:10 ночи — в часах смены

var _chart: Control
var _book: KMBook
var _hint: Label
var _status: Label
var _scratch_player: AudioStreamPlayer
var _listening := 0.0
var _now_h := 0.0
var _hour0 := 20.0
var _center_p := 746.0
var _truth := 746.0
var _truth_tend := 0.0
var _ruler_y := -1.0
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_now_h = Game.shift_minutes / 60.0
	_hour0 = float(Game.base_hour)
	_truth = Game.pressure_at(_now_h)
	_truth_tend = _truth - Game.pressure_at(_now_h - 3.0)
	# Лента стоит так, чтобы и «сейчас», и «три часа назад» были на ней
	_center_p = roundf(_truth - _truth_tend * 0.5 + randf_range(-2.0, 2.0))

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	var title := UiKit.label(Loc.t(&"barograph.title"), 20)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	UiKit.place(self, title, 0.5, 0.5, 0.5, 0.5, -500, -318, 500, -286)

	_chart = Control.new()
	_chart.clip_contents = true
	_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.place(self, _chart, 0.5, 0.5, 0.5, 0.5, -500, -252, 100, 196)
	_chart.draw.connect(_draw_chart)
	_chart.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			_ruler_y = (e as InputEventMouseMotion).position.y)
	_chart.mouse_exited.connect(func() -> void: _ruler_y = -1.0)

	_status = UiKit.label("", 14)
	_status.add_theme_color_override("font_color", Color(0.9, 0.55, 0.4))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(self, _status, 0.5, 0.5, 0.5, 0.5, -500, 200, 100, 226)
	var wind_btn := UiKit.button(Loc.t(&"barograph.wind_key"), _wind_mechanism)
	wind_btn.focus_mode = Control.FOCUS_NONE
	UiKit.place(self, wind_btn, 0.5, 0.5, 0.5, 0.5, -500, 232, -205, 268)
	var listen_btn := UiKit.button(Loc.t(&"barograph.listen_pen"), _listen_pen)
	listen_btn.focus_mode = Control.FOCUS_NONE
	UiKit.place(self, listen_btn, 0.5, 0.5, 0.5, 0.5, -195, 232, 100, 268)

	_book = KMBook.new()
	UiKit.place(self, _book, 0.5, 0.5, 0.5, 0.5, 120, -252, 500, 180)
	_book.setup([
		{"label": Loc.t(&"barograph.row_p"), "cells": [&"digit", &"digit", &"digit", &"digit"], "dot": 3, "unit": Loc.t(&"barograph.mm")},
		{"label": Loc.t(&"barograph.row_tend"), "cells": [&"sign", &"digit", &"digit"], "dot": 2, "unit": Loc.t(&"barograph.mm")},
	])
	if Game.notebook.has(&"baro"):
		_book.set_value(0, float(Game.notebook[&"baro"]["v"]))
		_book.set_value(1, float(Game.notebook[&"baro_tend"]["v"]))
	ThermometerUI.add_buttons(self, Game.notebook.has(&"baro"), _write, _close)
	_hint = ThermometerUI.hint_label(self)
	_hint.text = Loc.t(&"barograph.hint")

	_scratch_player = AudioStreamPlayer.new()
	_scratch_player.stream = AudioDirector.cached_stream(SCRATCH_SFX)
	_scratch_player.volume_db = -12.0
	_scratch_player.pitch_scale = 1.3
	add_child(_scratch_player)
	_update_status()


func _process(delta: float) -> void:
	if _listening > 0.0:
		_listening -= delta
		if _listening <= 0.0:
			_scratch_player.stop()
			_update_status()
	_chart.queue_redraw()


func _update_status() -> void:
	if _listening > 0.0:
		_status.text = Loc.t(&"barograph.listening_text")
	elif not Game.barograph_live():
		_status.text = Loc.t(&"barograph.stopped")
	elif Game.anomalies != null and Game.anomalies.is_active(&"baro_tooth"):
		_status.text = Loc.t(&"barograph.tooth")
	else:
		_status.text = Loc.t(&"barograph.wound_status", [int(Game.barograph_wound)])


func _wind_mechanism() -> void:
	Game.barograph_wound = 100.0
	AudioDirector.play_raw(CLANK_SFX, -3.0)
	Game.vibrate(0.35, 0.2, 0.2)
	Game.hud.subtitle(Loc.t(&"barograph.wound_done"), 2.5)
	Director.add_tension(-4.0, "завод барабана барографа")
	if Game.tasks != null and Game.tasks.is_active(&"barograph_check"):
		Game.tasks.complete(&"barograph_check")
	_update_status()


func _listen_pen() -> void:
	_listening = 5.0
	_scratch_player.play()
	Director.add_tension(4.0, "барограф: подслушан скрип пера")
	_update_status()


# --- Лента ------------------------------------------------------------------------------

func _x(h: float) -> float:
	var w := _chart.size.x - 70.0
	return 56.0 + (h - (_now_h - HOURS_BACK)) / (HOURS_BACK + HOURS_AHEAD) * w


func _y(p: float) -> float:
	var hgt := _chart.size.y - 50.0
	return 18.0 + (MM_HALF - (p - _center_p)) / (MM_HALF * 2.0) * hgt


## Что пишет перо в час h: давление плюс то, чего в воздухе не было.
func _pen(h: float) -> float:
	var p := Game.pressure_at(h)
	if Game.is_night() and h >= SIGNAL_H and h < SIGNAL_H + 0.06:
		p = _center_p + MM_HALF * 1.4                           # удар 03:10 — до края ленты
	if Game.anomalies != null and Game.anomalies.is_active(&"baro_tooth"):
		var th := _now_h - 0.7                                  # зуб: −9 мм за четверть часа, и назад
		if h > th and h < th + 0.5:
			p -= 9.0 * sin(PI * (h - th) / 0.5)
	return p


func _draw_chart() -> void:
	var w := _chart.size
	var font := ThemeDB.fallback_font
	var grid := Color(0.55, 0.42, 0.55, 0.35)
	var grid_b := Color(0.45, 0.3, 0.45, 0.7)
	var ink_l := Color(0.25, 0.2, 0.25)
	_chart.draw_rect(Rect2(Vector2.ZERO, w), Color(0.10, 0.10, 0.11))
	_chart.draw_rect(Rect2(6, 6, w.x - 12, w.y - 12), Color(0.93, 0.91, 0.84))
	# Давление: линия через 1 мм, жирная и подпись — через 5
	for mm in range(int(_center_p - MM_HALF) - 1, int(_center_p + MM_HALF) + 2):
		var y := _y(mm)
		if y < 8.0 or y > w.y - 30.0:
			continue
		var bold := mm % 5 == 0
		_chart.draw_line(Vector2(50, y), Vector2(w.x - 10, y), grid_b if bold else grid, 1.6 if bold else 1.0)
		if bold:
			_chart.draw_string(font, Vector2(10, y + 5), str(mm), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink_l)
	# Время: дуги часов (как на ленте барабана), подписи через 3 часа
	for k in range(int(floor(_now_h - HOURS_BACK)), int(ceil(_now_h + HOURS_AHEAD)) + 1):
		var x := _x(k)
		if x < 50.0 or x > w.x - 10.0:
			continue
		var hour := posmod(int(_hour0) + k, 24)
		var bold := hour % 3 == 0
		_chart.draw_line(Vector2(x, 10), Vector2(x, w.y - 30), grid_b if bold else grid, 1.4 if bold else 1.0)
		if bold:
			_chart.draw_string(font, Vector2(x - 8, w.y - 12), "%02d" % hour, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink_l)
	# Перо: фиолетовые чернила до «сейчас» (или до остановки пружины)
	var end_h := _now_h if Game.barograph_live() else _now_h - 1.0
	var pts := PackedVector2Array()
	var h := _now_h - HOURS_BACK - 0.2
	while h <= end_h:
		pts.append(Vector2(_x(h), clampf(_y(_pen(h)), 10.0, w.y - 32.0)))
		h += 0.05
	pts.append(Vector2(_x(end_h), clampf(_y(_pen(end_h)), 10.0, w.y - 32.0)))
	if pts.size() > 1:
		_chart.draw_polyline(pts, Color(0.42, 0.12, 0.55, 0.92), 2.2, true)
	var tip := pts[pts.size() - 1]
	if Game.barograph_live():
		# Стрелка пера с лёгкой дрожью
		var j := Vector2(0, sin(Time.get_ticks_msec() * 0.02) * 0.6)
		_chart.draw_line(tip + Vector2(0, -2) + j, tip + Vector2(46, -30) + j, Color(0.2, 0.2, 0.22), 2.0)
		_chart.draw_circle(tip + j, 3.5, Color(0.28, 0.08, 0.38))
	# Линейка у мыши
	if _ruler_y >= 0.0:
		_chart.draw_line(Vector2(50, _ruler_y), Vector2(w.x - 10, _ruler_y), Color(0.15, 0.35, 0.75, 0.55), 1.0)
	var ax := Loc.t(&"barograph.mm_axis")
	var aw := font.get_string_size(ax, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_chart.draw_rect(Rect2(w.x - aw - 22, 10, aw + 10, 18), Color(0.93, 0.91, 0.84))
	_chart.draw_string(font, Vector2(w.x - aw - 17, 24), ax, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink_l)


# --- Запись -----------------------------------------------------------------------------

func _write() -> void:
	if _done:
		return
	if not Game.barograph_live():
		Game.hud.subtitle(Loc.t(&"barograph.stopped"), 3.0)
		return
	_done = true
	var p := _book.value(0)
	var t := _book.value(1)
	Game.write_reading(&"baro", p, _truth)
	Game.write_reading(&"baro_tend", t, _truth_tend)
	Game.take_reading(&"baro")
	Game.audio.play_2d(PEN_SFX, -12.0)
	Game.hud.subtitle(Loc.t(&"barograph.written", [ThermometerUI.fmt(p, 1).trim_prefix("+"), ThermometerUI.fmt(t, 1)]) + " " + ThermometerUI.tail(), 5.0)
	_close()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		_close()
		return
	if event.is_action_pressed(&"crank"):
		_wind_mechanism()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)


func _close() -> void:
	if _scratch_player.playing:
		_scratch_player.stop()
	closed.emit()
