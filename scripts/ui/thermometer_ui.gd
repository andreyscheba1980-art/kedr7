class_name ThermometerUI
extends Control
## Психрометрическая будка: крупный кадр двух спиртовых термометров (сухой и смоченный) и книжка КМ-1.
## Цифр игра не подсказывает: шкалу читаешь сам (колёсико / W S — вдоль шкалы), ночью видно только
## в пятне фонаря, иней на стекле стираешь рукавицей (InstrumentView). Вписал барабанчиками (KMBook) —
## замер снят; по рации Свердловск сверит книжку с соседями (Game.report_check).

signal closed

const T_MIN := -60.0
const T_MAX := 40.0
const PPD := 34.0                       ## пикселей на градус
const DEG_PER_NOTCH := 0.6
const FEVER := 36.6
const PEN_SFX := "res://assets/audio/clank.ogg"

var _truth := Vector2(-28.0, -30.0)     ## что на самом деле в воздухе
var _shown := Vector2(-28.0, -30.0)     ## что показывают столбики (в «жар» сухой врёт)
var _center := 0.0
var _fever := false
var _fever_seen := false
var _view: InstrumentView
var _book: KMBook
var _hint: Label
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_truth = Game.air_temp()
	_shown = _truth
	if Game.yard != null and Game.yard.has_method(&"claim_fever") and Game.yard.claim_fever():
		_fever = true
		_shown.x = FEVER
	_center = clampf(_truth.x + randf_range(-4.0, 4.0), T_MIN + 7.0, T_MAX - 7.0)

	ThermometerUI.backdrop(self)
	title_plate(self, Loc.t(&"thermo.title"))

	_view = InstrumentView.new()
	UiKit.place(self, _view, 0.5, 0.5, 0.5, 0.5, -500, -252, 100, 260)
	_view.setup(_draw_view, func(n: float) -> void: _scroll(n * DEG_PER_NOTCH), InstrumentView.frost_for_weather(_truth.x),
		[[0.32 - 0.085, 0.32 + 0.085], [0.70 - 0.085, 0.70 + 0.085]])   # иней — на стекле термометров

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
	UiKit.place(owner, write_btn, 0.5, 0.5, 0.5, 0.5, 170, 196, 450, 238)
	var close_btn := UiStyle.text_button(Loc.t(&"thermo.close_key"), on_close)
	UiKit.place(owner, close_btn, 0.5, 0.5, 0.5, 0.5, 220, 244, 400, 270)


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


func _process(_delta: float) -> void:
	_hint.text = Loc.t(&"thermo.hint") if _view.can_see() else Loc.t(&"thermo.hint_dark")
	_check_fever()


func _scroll(deg: float) -> void:
	_center = clampf(_center + deg, T_MIN + 7.0, T_MAX - 7.0)


## Сухой показывает +36,6: заметили столбик — тот же холодок, что раньше давала подпись.
func _check_fever() -> void:
	if not _fever or _fever_seen or not _view.can_see():
		return
	var half := _view.size.y * 0.5 / PPD
	if absf(_center - FEVER) > half - 1.0:
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


# --- Шкалы ------------------------------------------------------------------------------

func _y(t: float) -> float:
	return _view.size.y * 0.5 - (t - _center) * PPD


func _draw_view() -> void:
	var w := _view.size
	# Нутро будки Селянинова: белёные жалюзи — объёмные планки, в щелях темно
	_view.draw_rect(Rect2(Vector2.ZERO, w), Color(0.16, 0.17, 0.18))
	for y in range(-10, int(w.y), 26):
		UiStyle.vgrad(_view, Rect2(0, y, w.x, 19), Color(0.80, 0.80, 0.76), Color(0.56, 0.57, 0.55))
		_view.draw_line(Vector2(0, y), Vector2(w.x, y), Color(0.9, 0.9, 0.86), 1.0)
	UiStyle.hgrad(_view, Rect2(0, 0, 70, w.y), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))   # стойки будки в тени
	UiStyle.hgrad(_view, Rect2(w.x - 70, 0, 70, w.y), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45))
	_draw_thermo(w.x * 0.32, _shown.x, Loc.t(&"thermo.dry"), false)
	_draw_thermo(w.x * 0.70, _shown.y, Loc.t(&"thermo.wet"), true)


func _draw_thermo(x: float, value: float, label: String, wet: bool) -> void:
	var h := _view.size.y
	var pf := UiStyle.plate_font()
	var ink := Color(0.10, 0.10, 0.12)
	# Тень и молочная шкальная пластина
	_view.draw_rect(Rect2(x - 44, 0, 100, h), Color(0, 0, 0, 0.35))
	UiStyle.hgrad(_view, Rect2(x - 48, 0, 96, h), Color(0.86, 0.87, 0.85), Color(0.97, 0.97, 0.95))
	var lo := _center - h * 0.5 / PPD - 1.0
	var hi := _center + h * 0.5 / PPD + 1.0
	for k in range(int(floor(lo * 5.0)), int(ceil(hi * 5.0)) + 1):
		var t := k / 5.0
		var y := _y(t)
		var len := 7.0
		var width := 1.0
		if k % 25 == 0:
			len = 24.0
			width = 2.0
		elif k % 5 == 0:
			len = 15.0
			width = 1.5
		_view.draw_line(Vector2(x - 9 - len, y), Vector2(x - 9, y), ink, width)
		_view.draw_line(Vector2(x + 9, y), Vector2(x + 9 + len * 0.6, y), ink, width)
		if k % 25 == 0:
			var n := int(roundf(t))
			var s := ("−" if n < 0 else "+" if n > 0 else "") + str(absi(n))
			_view.draw_string(pf, Vector2(x - 46, y + 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
	# Стеклянная трубка: блик слева, тень справа
	UiStyle.hgrad(_view, Rect2(x - 8, 0, 8, h), Color(1, 1, 1, 0.55), Color(0.85, 0.9, 0.95, 0.25))
	UiStyle.hgrad(_view, Rect2(x, 0, 8, h), Color(0.8, 0.86, 0.9, 0.25), Color(0.35, 0.4, 0.45, 0.45))
	# Спиртовой столбик в капилляре
	var top := clampf(_y(value), -4.0, h + 4.0)
	if top < h:
		UiStyle.hgrad(_view, Rect2(x - 2.5, top, 5, h - top), Color(0.85, 0.15, 0.12), Color(0.5, 0.03, 0.04))
		if top > -4.0:
			_view.draw_circle(Vector2(x, top + 1.0), 2.6, Color(0.62, 0.06, 0.06))
	_view.draw_line(Vector2(x - 6, 0), Vector2(x - 6, h), Color(1, 1, 1, 0.65), 1.5)
	# Латунная табличка над прибором
	var lw := pf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var pr := Rect2(x - lw * 0.5 - 8, 8, lw + 16, 22)
	_view.draw_rect(pr.grow(1), UiStyle.BRASS.darkened(0.5))
	UiStyle.vgrad(_view, pr, UiStyle.BRASS.lightened(0.15), UiStyle.BRASS.darkened(0.15))
	_view.draw_string(pf, Vector2(x - lw * 0.5, 25), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.18, 0.13, 0.06))
	_view.draw_string(pf, Vector2(x + 22, h - 10), "°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	if wet:   # батист смоченного: обледенелая ткань уходит вниз, к резервуару
		UiStyle.vgrad(_view, Rect2(x - 10, h - 30, 20, 30), Color(0.9, 0.93, 0.95, 0.6), Color(0.82, 0.86, 0.9, 0.95))


# --- Запись -----------------------------------------------------------------------------

func _write() -> void:
	if _done:
		return
	_done = true
	var dry := _book.value(0)
	var wet := _book.value(1)
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
	if event.is_action_pressed(&"flashlight") and Game.player != null:
		Game.player.toggle_flashlight()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)
