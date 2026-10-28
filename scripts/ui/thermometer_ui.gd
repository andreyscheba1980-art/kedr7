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

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	var title := UiKit.label(Loc.t(&"thermo.title"), 20)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	UiKit.place(self, title, 0.5, 0.5, 0.5, 0.5, -500, -318, 500, -286)

	_view = InstrumentView.new()
	UiKit.place(self, _view, 0.5, 0.5, 0.5, 0.5, -500, -252, 100, 260)
	_view.setup(_draw_view, func(n: float) -> void: _scroll(n * DEG_PER_NOTCH), InstrumentView.frost_for_weather(_truth.x))

	_book = KMBook.new()
	UiKit.place(self, _book, 0.5, 0.5, 0.5, 0.5, 120, -252, 500, 180)
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
static func add_buttons(owner: Control, again: bool, on_write: Callable, on_close: Callable) -> void:
	var write_btn := UiKit.button(Loc.t(&"thermo.write_again" if again else &"thermo.write"), on_write)
	write_btn.focus_mode = Control.FOCUS_NONE
	UiKit.place(owner, write_btn, 0.5, 0.5, 0.5, 0.5, 120, 192, 500, 230)
	var close_btn := UiKit.button(Loc.t(&"thermo.close"), on_close)
	close_btn.focus_mode = Control.FOCUS_NONE
	UiKit.place(owner, close_btn, 0.5, 0.5, 0.5, 0.5, 220, 236, 400, 268)


static func hint_label(owner: Control) -> Label:
	var hint := UiKit.label("", 14, HORIZONTAL_ALIGNMENT_LEFT)
	hint.modulate = Color(1, 1, 1, 0.72)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(owner, hint, 0.5, 0.5, 0.5, 0.5, -500, -282, 500, -258)
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
	# Нутро будки Селянинова: белёные жалюзи
	_view.draw_rect(Rect2(Vector2.ZERO, w), Color(0.70, 0.70, 0.66))
	for y in range(0, int(w.y), 24):
		_view.draw_rect(Rect2(0, y + 15, w.x, 6), Color(0.52, 0.53, 0.52))
		_view.draw_line(Vector2(0, y + 15), Vector2(w.x, y + 15), Color(0.82, 0.82, 0.78), 1.0)
	_draw_thermo(w.x * 0.32, _shown.x, Loc.t(&"thermo.dry"), false)
	_draw_thermo(w.x * 0.70, _shown.y, Loc.t(&"thermo.wet"), true)


func _draw_thermo(x: float, value: float, label: String, wet: bool) -> void:
	var h := _view.size.y
	var font := ThemeDB.fallback_font
	var ink := Color(0.10, 0.10, 0.12)
	# Молочная шкальная пластина и стеклянная оболочка
	_view.draw_rect(Rect2(x - 52, 0, 104, h), Color(0.18, 0.2, 0.22, 0.35))
	_view.draw_rect(Rect2(x - 46, 0, 92, h), Color(0.94, 0.94, 0.91))
	var lo := _center - h * 0.5 / PPD - 1.0
	var hi := _center + h * 0.5 / PPD + 1.0
	for k in range(int(floor(lo * 5.0)), int(ceil(hi * 5.0)) + 1):
		var t := k / 5.0
		var y := _y(t)
		var len := 7.0
		var width := 1.2
		if k % 25 == 0:
			len = 24.0
			width = 2.2
		elif k % 5 == 0:
			len = 15.0
			width = 1.6
		_view.draw_line(Vector2(x - 7 - len, y), Vector2(x - 7, y), ink, width)
		_view.draw_line(Vector2(x + 7, y), Vector2(x + 7 + len * 0.6, y), ink, width)
		if k % 25 == 0:
			var n := int(roundf(t))
			var s := ("−" if n < 0 else "+" if n > 0 else "") + str(absi(n))
			_view.draw_string(font, Vector2(x - 44, y - 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	# Капилляр и спиртовой столбик
	_view.draw_rect(Rect2(x - 3, 0, 6, h), Color(0.82, 0.86, 0.88))
	var top := clampf(_y(value), -4.0, h + 4.0)
	if top < h:
		_view.draw_rect(Rect2(x - 2.5, top, 5, h - top), Color(0.72, 0.08, 0.08))
		if top > -4.0:
			_view.draw_circle(Vector2(x, top + 0.5), 2.6, Color(0.6, 0.05, 0.05))
	# Блик на стекле
	_view.draw_line(Vector2(x - 11, 0), Vector2(x - 11, h), Color(1, 1, 1, 0.35), 2.0)
	_view.draw_line(Vector2(x + 13, 0), Vector2(x + 13, h), Color(0.4, 0.45, 0.5, 0.35), 1.0)
	# Табличка над прибором
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_view.draw_rect(Rect2(x - lw * 0.5 - 6, 6, lw + 12, 20), Color(0.16, 0.16, 0.15, 0.9))
	_view.draw_string(font, Vector2(x - lw * 0.5, 21), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.9, 0.82))
	_view.draw_string(font, Vector2(x + 20, h - 10), "°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	if wet:   # батист смоченного: обледенелая ткань уходит вниз, к резервуару
		_view.draw_rect(Rect2(x - 9, h - 26, 18, 26), Color(0.86, 0.9, 0.93, 0.85))


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
