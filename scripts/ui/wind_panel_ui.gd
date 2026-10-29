class_name WindPanelUI
extends Control
## Пульт анеморумбометра М-63 в аппаратной: камера подходит к настоящим шкалам пульта (CorpusDressing),
## колёсико / A D — от шкалы скорости к шкале румба. Стрелками на это время правит экран.
## Слева — скорость (0..40 м/с): стрелка гуляет вокруг средней, на порывах рывком уходит выше;
## красный «контрольный» указатель держит максимум — это порыв. Справа — румб (16 направлений).
## Цифр нет: среднюю скорость дежурный оценивает на глаз, порыв и румб считывает и вписывает сам.

signal closed

const MAX_SPEED := 40.0
const PEN_SFX := "res://assets/audio/clank.ogg"

var _close: Closeup3D
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

	ThermometerUI.title_plate(self, Loc.t(&"pult.title"))
	# Шкала скорости — левее центра кадра: справа книжка в руке
	var c0 := CorpusDressing.dial_center(0)
	var eye := c0 + Vector3(0.15, 0.0, 0.75)
	_close = Closeup3D.new()
	Game.level.add_child(_close)
	_close.setup(eye, eye + Vector3(0, 0, -1), 34.0, Vector3.RIGHT, 0.0, CorpusDressing.dial_center(1).x - c0.x, 0.0)

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
	if CorpusDressing.instance != null:
		CorpusDressing.instance.drive(_needle, _gust_max, _az_needle)
	var dx := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(rx) > 0.2:
		dx += rx
	if absf(dx) > 0.01:
		_close.scroll(dx * 0.8 * delta)


func _exit_tree() -> void:
	if _close != null and is_instance_valid(_close):
		_close.queue_free()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_close.scroll(0.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_close.scroll(-0.1)


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
