class_name WindPanelUI
extends Control
## Пульт анеморумбометра М-63 в аппаратной: крупный кадр двух шкал и книжка КМ-1.
## Слева — скорость (0..40 м/с): стрелка гуляет вокруг средней, на порывах рывком уходит выше;
## красный «контрольный» указатель держит максимум — это порыв. Справа — румб (16 направлений).
## Цифр нет: среднюю скорость дежурный оценивает на глаз, порыв и румб считывает и вписывает сам.

signal closed

const MAX_SPEED := 40.0
const PEN_SFX := "res://assets/audio/clank.ogg"

var _dial: Control
var _book: KMBook
var _hint: Label
var _t := 0.0
## Правда (что сверит Свердловск) и то, что показывает прибор (аномалия «чашки живут своей жизнью»)
var _truth := Vector3(8.0, 12.0, 0.0)     ## x — средняя, y — порыв, z — азимут
var _speed := 8.0
var _gusts := 12.0
var _az := 0.0
var _needle := 0.0
var _gust_max := 0.0
var _az_needle := 0.0
var _spike_in := 1.5
var _spike_t := 0.0
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sy = Game.synoptic
	if sy != null:
		_truth = Vector3(sy.wind_speed, sy.wind_gusts, sy.wind_azimuth_deg)
	_speed = _truth.x
	_gusts = _truth.y
	_az = _truth.z
	# Аномалия: в метель стрелка мертва, в штиль — гуляет под 30
	if Game.anomalies != null and Game.anomalies.is_active(&"anemo_calm"):
		var storm := Game.weather != null and Game.weather.intensity > 0.45
		_speed = 0.0 if storm else 27.0
		_gusts = 0.0 if storm else 34.0
	_needle = _speed
	_az_needle = _az
	_spike_in = randf_range(1.0, 2.5)

	ThermometerUI.backdrop(self)
	ThermometerUI.title_plate(self, Loc.t(&"pult.title"))
	_dial = Control.new()
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, _dial, 0.5, 0.5, 0.5, 0.5, -500, -252, 100, 260)
	_dial.draw.connect(_draw_dials)

	_book = KMBook.new()
	HeldPaper.notebook(self, _book)   # книжка КМ-1 — в правой руке
	_book.setup([
		{"label": Loc.t(&"pult.row_speed"), "cells": [&"digit", &"digit"], "unit": Loc.t(&"pult.ms")},
		{"label": Loc.t(&"pult.row_gust"), "cells": [&"digit", &"digit"], "unit": Loc.t(&"pult.ms")},
		{"label": Loc.t(&"pult.row_dir"), "cells": [&"rumb"], "unit": ""},
	])
	if Game.notebook.has(&"wind_speed"):
		_book.set_value(0, float(Game.notebook[&"wind_speed"]["v"]))
		_book.set_value(1, float(Game.notebook[&"wind_gust"]["v"]))
		_book.set_value(2, float(Game.notebook[&"wind_dir"]["v"]))
	ThermometerUI.add_buttons(self, Game.notebook.has(&"wind_speed"), _write, func() -> void: closed.emit())
	_hint = ThermometerUI.hint_label(self)
	_hint.text = Loc.t(&"pult.hint")


static func rumb_of(az: float) -> int:
	return posmod(int(roundf(fposmod(az, 360.0) / 22.5)), 16)


func _process(delta: float) -> void:
	_t += delta
	# Скорость: колебания вокруг средней (в среднем — ноль) + редкие рывки до порыва; инерция стрелки
	var amp := (_gusts - _speed) * 0.4
	var target := _speed + (sin(_t * 0.9) * 0.55 + sin(_t * 2.3 + 1.3) * 0.35 + randf_range(-0.1, 0.1)) * amp
	_spike_in -= delta
	if _spike_in <= 0.0 and _gusts > 0.0:
		_spike_in = randf_range(3.5, 6.5)
		_spike_t = 1.2
	if _spike_t > 0.0:
		_spike_t -= delta
		target = lerpf(target, _gusts, sin(PI * clampf(1.0 - _spike_t / 1.2, 0.0, 1.0)))
	target = maxf(target, 0.0) if _speed > 0.0 else 0.0
	_needle = lerpf(_needle, target, clampf(delta * 6.0, 0.0, 1.0))
	_gust_max = maxf(_gust_max, _needle)
	_az_needle = _az + sin(_t * 0.7) * 6.0 + sin(_t * 2.1) * 3.0 if _speed > 0.0 else _az_needle
	_dial.queue_redraw()


func _draw_dials() -> void:
	var w := _dial.size
	var font := UiStyle.plate_font()
	var ink := Color(0.12, 0.11, 0.09)
	var r := minf(w.x * 0.22, w.y * 0.34)
	UiStyle.bakelite(_dial, Rect2(Vector2.ZERO, w))
	# --- Скорость ---
	var c1 := Vector2(w.x * 0.26, w.y * 0.46)
	UiStyle.dial_face(_dial, c1, r)
	var a0 := deg_to_rad(135.0)
	var span := deg_to_rad(270.0)
	for v in range(0, int(MAX_SPEED) + 1):
		var a := a0 + span * v / MAX_SPEED
		var dir := Vector2(cos(a), sin(a))
		var long := v % 5 == 0
		_dial.draw_line(c1 + dir * (r - (18 if long else 9)), c1 + dir * (r - 3), ink, 2.5 if long else 1.2)
		if long:
			var s := str(v)
			_dial.draw_string(font, c1 + dir * (r - 32) - Vector2(6 * s.length(), -6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	_dial.draw_string(font, c1 + Vector2(-16, r * 0.45), Loc.t(&"pult.ms"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var ag := a0 + span * clampf(_gust_max, 0.0, MAX_SPEED) / MAX_SPEED
	_dial.draw_line(c1, c1 + Vector2(cos(ag), sin(ag)) * (r - 14), Color(0.7, 0.1, 0.08), 3.0)
	var an := a0 + span * clampf(_needle, 0.0, MAX_SPEED) / MAX_SPEED
	_dial.draw_line(c1 + Vector2(2, 3), c1 + Vector2(cos(an), sin(an)) * (r - 8) + Vector2(2, 3), Color(0, 0, 0, 0.25), 4.0)   # тень стрелки
	_dial.draw_line(c1, c1 + Vector2(cos(an), sin(an)) * (r - 8), ink, 4.0)
	_dial.draw_circle(c1, 9, Color(0.3, 0.29, 0.27))
	_dial.draw_circle(c1, 5, ink)
	UiStyle.dial_glass(_dial, c1, r)
	# --- Румб ---
	var c2 := Vector2(w.x * 0.74, w.y * 0.46)
	UiStyle.dial_face(_dial, c2, r)
	var names := Loc.t(&"pult.rumbs").split(",")
	for i in 16:
		var a := deg_to_rad(i * 22.5 - 90.0)
		var dir := Vector2(cos(a), sin(a))
		var major := i % 4 == 0
		_dial.draw_line(c2 + dir * (r - (20 if major else 10)), c2 + dir * (r - 3), ink, 2.5 if major else 1.2)
		if names.size() == 16 and (major or i % 2 == 0):
			var s: String = names[i]
			_dial.draw_string(font, c2 + dir * (r - (40 if major else 36)) - Vector2(6 * s.length(), -6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 19 if major else 14, ink)
	var az := deg_to_rad(_az_needle - 90.0)
	var tip := c2 + Vector2(cos(az), sin(az)) * (r - 12)
	var tl := c2 - Vector2(cos(az), sin(az)) * (r * 0.35)
	_dial.draw_line(tl + Vector2(2, 3), tip + Vector2(2, 3), Color(0, 0, 0, 0.25), 4.0)
	_dial.draw_line(tl, tip, ink, 4.0)
	_dial.draw_circle(tip, 6, Color(0.7, 0.1, 0.08))
	_dial.draw_circle(c2, 9, Color(0.3, 0.29, 0.27))
	_dial.draw_circle(c2, 5, ink)
	UiStyle.dial_glass(_dial, c2, r)
	# Подписи под шкалами
	for pair: Array in [[c1, Loc.t(&"pult.cap_speed")], [c2, Loc.t(&"pult.cap_dir")]]:
		var s: String = pair[1]
		var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var pr := Rect2((pair[0] as Vector2) + Vector2(-sw * 0.5 - 8, r + 28), Vector2(sw + 16, 22))
		_dial.draw_rect(pr.grow(1), UiStyle.BRASS.darkened(0.5))
		UiStyle.vgrad(_dial, pr, UiStyle.BRASS.lightened(0.15), UiStyle.BRASS.darkened(0.15))
		_dial.draw_string(font, pr.position + Vector2(8, 17), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.18, 0.13, 0.06))


func _write() -> void:
	if _done:
		return
	_done = true
	var sp := _book.value(0)
	var gu := _book.value(1)
	var rb := int(_book.value(2))
	Game.write_reading(&"wind_speed", sp, _truth.x)
	Game.write_reading(&"wind_gust", gu, _truth.y)
	Game.write_reading(&"wind_dir", rb, rumb_of(_truth.z))
	Game.take_reading(&"wind")
	Game.audio.play_2d(PEN_SFX, -12.0)
	var names := Loc.t(&"pult.rumbs").split(",")
	Game.hud.subtitle(Loc.t(&"pult.written", [names[rb] if rb < names.size() else "?", int(sp), int(gu)]) + " " + ThermometerUI.tail(), 5.0)
	closed.emit()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)
