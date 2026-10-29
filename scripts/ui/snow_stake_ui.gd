class_name SnowStakeUI
extends Control
## Снегомерная рейка М-103 на площадке: крупный кадр и книжка КМ-1. Деления — через сантиметр,
## цифры — через десять; читать там, где снег сходится с рейкой (вокруг наметает гребни и ямы).
## Ночью — в пятне фонаря; налипший снег на рейке стирается рукавицей (InstrumentView).

signal closed

const H_MAX := 200.0
const PPCM := 5.2                      ## пикселей на сантиметр
const CM_PER_NOTCH := 3.0
const PEN_SFX := "res://assets/audio/clank.ogg"

var _truth := 100.0
var _center := 100.0
var _view: InstrumentView
var _book: KMBook
var _hint: Label
var _drift_seed := 0.0
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_truth = float(Game.synoptic.snow_depth_cm) if Game.synoptic != null else float(randi_range(84, 112))
	_center = clampf(_truth + randf_range(-18.0, 18.0), 45.0, H_MAX - 45.0)
	_drift_seed = randf() * 100.0

	ThermometerUI.backdrop(self)
	ThermometerUI.title_plate(self, Loc.t(&"snow.title"))

	_view = InstrumentView.new()
	UiKit.place(self, _view, 0.5, 0.5, 0.5, 0.5, -500, -252, 100, 260)
	var temp := Game.air_temp().x
	_view.setup(_draw_view, func(n: float) -> void: _center = clampf(_center + n * CM_PER_NOTCH, 45.0, H_MAX - 45.0), InstrumentView.frost_for_weather(temp) * 0.8, [[0.44, 0.56]])

	_book = KMBook.new()
	HeldPaper.notebook(self, _book)   # книжка КМ-1 — в правой руке
	_book.setup([{"label": Loc.t(&"snow.row"), "cells": [&"digit", &"digit", &"digit"], "unit": Loc.t(&"snow.cm")}])
	if Game.notebook.has(&"snow"):
		_book.set_value(0, float(Game.notebook[&"snow"]["v"]))
	ThermometerUI.add_buttons(self, Game.notebook.has(&"snow"), _write, func() -> void: closed.emit())
	_hint = ThermometerUI.hint_label(self)


func _process(_delta: float) -> void:
	_hint.text = Loc.t(&"snow.hint") if _view.can_see() else Loc.t(&"thermo.hint_dark")


func _y(cm: float) -> float:
	return _view.size.y * 0.5 - (cm - _center) * PPCM


## Поверхность снега по горизонтали: у самой рейки — ровно высота, в стороны — гребни и ямки.
func _surface(x: float, rod_x: float) -> float:
	var d := absf(x - rod_x)
	var k := clampf((d - 26.0) / 120.0, 0.0, 1.0)
	var wav := sin(x * 0.021 + _drift_seed) * 6.0 + sin(x * 0.057 + _drift_seed * 2.0) * 2.5
	return _truth + wav * k


func _draw_view() -> void:
	var w := _view.size
	var font := UiStyle.plate_font()
	var ink := Color(0.08, 0.08, 0.1)
	var day := Game.is_daylight()
	# Фон: лес за площадкой
	_view.draw_rect(Rect2(Vector2.ZERO, w), Color(0.55, 0.6, 0.66) if day else Color(0.1, 0.13, 0.19))
	for i in 9:
		var tx := fmod(i * 83.0 + _drift_seed * 7.0, w.x)
		_view.draw_colored_polygon(PackedVector2Array([Vector2(tx - 40, w.y), Vector2(tx, w.y * 0.05), Vector2(tx + 40, w.y)]),
			Color(0.32, 0.38, 0.4) if day else Color(0.05, 0.07, 0.1))
	var rx := w.x * 0.5
	# Рейка: белая, деления слева (см / 5 / 10), справа — красно-белые полосы по 10 см
	_view.draw_rect(Rect2(rx - 26, 0, 60, w.y), Color(0, 0, 0, 0.35))   # тень рейки
	UiStyle.hgrad(_view, Rect2(rx - 30, 0, 60, w.y), Color(0.82, 0.82, 0.8), Color(0.97, 0.97, 0.95))
	var lo := _center - w.y * 0.5 / PPCM - 2.0
	var hi := _center + w.y * 0.5 / PPCM + 2.0
	for cm in range(int(floor(lo)), int(ceil(hi)) + 1):
		if cm < 0 or cm > int(H_MAX):
			continue
		var y := _y(cm)
		if cm % 10 == 0 and (cm / 10) % 2 == 0 and cm < int(H_MAX):
			_view.draw_rect(Rect2(rx + 14, _y(cm + 10), 16, 10 * PPCM), Color(0.72, 0.1, 0.08))
		var len := 8.0
		var width := 1.2
		if cm % 10 == 0:
			len = 26.0
			width = 2.2
		elif cm % 5 == 0:
			len = 16.0
			width = 1.6
		_view.draw_line(Vector2(rx - 30, y), Vector2(rx - 30 + len, y), ink, width)
		if cm % 10 == 0:
			_view.draw_string(font, Vector2(rx - 2, y - 3), str(cm), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	_view.draw_line(Vector2(rx - 30, 0), Vector2(rx - 30, w.y), Color(0.5, 0.5, 0.5), 1.0)
	_view.draw_line(Vector2(rx + 30, 0), Vector2(rx + 30, w.y), Color(0.5, 0.5, 0.5), 1.0)
	# Снег поверх нижней части рейки
	var pts := PackedVector2Array()
	pts.append(Vector2(0, w.y))
	var x := 0.0
	while x <= w.x:
		pts.append(Vector2(x, _y(_surface(x, rx))))
		x += 8.0
	pts.append(Vector2(w.x, w.y))
	_view.draw_colored_polygon(pts, Color(0.84, 0.88, 0.93) if day else Color(0.62, 0.68, 0.78))
	var edge := PackedVector2Array()
	for i in range(1, pts.size() - 1):
		edge.append(pts[i])
	_view.draw_polyline(edge, Color(1, 1, 1, 0.6), 2.0)
	_view.draw_string(font, Vector2(rx + 38, w.y - 10), Loc.t(&"snow.cm"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))


func _write() -> void:
	if _done:
		return
	_done = true
	var v := _book.value(0)
	Game.write_reading(&"snow", v, _truth)
	Game.take_reading(&"snow")
	Game.audio.play_2d(PEN_SFX, -12.0)
	Game.hud.subtitle(Loc.t(&"snow.written", [int(v)]) + " " + ThermometerUI.tail(), 5.0)
	closed.emit()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if event.is_action_pressed(&"flashlight") and Game.player != null:
		Game.player.toggle_flashlight()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)
