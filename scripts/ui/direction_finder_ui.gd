class_name DirectionFinderUI
extends Control
## Рамочная антенна-пеленгатор: в доме — у рации, на башне корпуса — приёмник в кабине и рамка на крыше.
## Настраиваешься на передачу (A/D, Shift — точно), крутишь рамку (W/S или мышью по лимбу), пока сигнал
## не провалится в «ноль», — и читаешь азимут по красному указателю. Рамка не различает «туда» и
## «оттуда»: линия на схеме идёт в обе стороны, второй пеленг с другой точки решает, где источник.
## Азимут вписываешь в книжку сам (KMBook) — ошибёшься, линия ляжет не туда (Efir.cross).
## На башне ловится и слабое, чего дома не слышно; здесь же можно записать передачу [R].

signal closed

const SPAN_KHZ := 160.0          ## видимая часть шкалы частот
const COARSE := 220.0
const STATIC_LOOP := "res://assets/audio/static_loop.ogg"
const PEN_SFX := "res://assets/audio/clank.ogg"
const LOCK_TIME := 1.5

static var tower_freq := 6100.0
static var next_point: StringName = &"house"    ## куда открыть следующий экран (ставит тот, кто открывает)

var point: StringName = &"house"
var _was_muted := false
var _freq := 6100.0
var _angle := 0.0               ## куда смотрит указатель рамки, градусы от севера
var _panel: Control
var _book: KMBook
var _hint: Label
var _sig: AudioStreamPlayer
var _sig_id: StringName = &""
var _static: AudioStreamPlayer
var _meter := 0.0
var _strength := 0.0
var _lock_t := 0.0
var _rec_t := -1.0
var _drag := false
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	point = next_point
	_freq = Game.radio.freq if point == &"house" and Game.radio != null else tower_freq
	_angle = randf_range(0.0, 360.0)
	ThermometerUI.backdrop(self)
	ThermometerUI.title_plate(self, Loc.t(&"df.title_house" if point == &"house" else &"df.title_tower"))

	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	UiKit.place(self, _panel, 0.5, 0.5, 0.5, 0.5, -500, -252, 100, 260)
	_panel.draw.connect(_draw_panel)
	_panel.gui_input.connect(_panel_input)

	_book = KMBook.new()
	HeldPaper.notebook(self, _book)   # книжка КМ-1 — в правой руке
	_book.setup([{"label": Loc.t(&"df.row"), "cells": [&"digit", &"digit", &"digit"], "unit": "°"}])
	ThermometerUI.add_buttons(self, false, _write, _close)
	_hint = UiStyle.hint()
	UiKit.place(self, _hint, 0.5, 0.5, 0.5, 0.5, -500, -282, 100, -254)

	_static = AudioStreamPlayer.new()
	_static.stream = AudioDirector.cached_stream(STATIC_LOOP)
	_static.bus = &"Radio"
	_static.volume_db = -14.0
	add_child(_static)
	_static.finished.connect(_static.play)
	_static.play()
	_sig = AudioStreamPlayer.new()
	_sig.bus = &"Radio"
	_sig.volume_db = -80.0
	add_child(_sig)
	_sig.finished.connect(func() -> void:
		if _sig_id != &"":
			_sig.play())
	if Game.radio != null:
		_was_muted = Game.radio.muted
		Game.radio.muted = true      # рация на столе молчит, слушаем через рамку


func _exit_tree() -> void:
	if point == &"tower":
		tower_freq = _freq
	elif Game.radio != null:
		Game.radio.freq = _freq
	if Game.radio != null:
		Game.radio.muted = _was_muted


## Какая передача сейчас на частоте и с какой силой.
func _tuned() -> Array:
	var best := &""
	var bs := 0.0
	if Game.radio == null:
		return [best, bs]
	for id: StringName in Game.radio.signals_on_air():
		if id == &"mainland" and point == &"tower":
			continue
		var s: float = Game.radio.strength_at(id, _freq, point == &"tower")
		if s > bs:
			bs = s
			best = id
	return [best, bs]


## Диаграмма рамки: «восьмёрка» — провал, когда указатель смотрит на источник (или от него).
func _pattern(id: StringName) -> float:
	if id == &"" or not Efir.can_bearing(id) or Efir.too_close(id, point):
		return 1.0
	var d := deg_to_rad(_angle - Efir.true_bearing(id, point))
	return clampf(pow(absf(sin(d)), 0.8), 0.04, 1.0)


func _process(delta: float) -> void:
	var fast := not Input.is_key_pressed(KEY_SHIFT)
	# A/D и левый стик — частота, W/S и правый стик — рамка; стрелки заняты книжкой
	var lx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var tune := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)) + (lx if absf(lx) > 0.2 else 0.0)
	if absf(tune) > 0.01 and _rec_t < 0.0:
		_freq = clampf(_freq + tune * COARSE * (1.0 if fast else 0.1) * delta, Radio.F_MIN, Radio.F_MAX)
	var rot := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(rx) > 0.2:
		rot += rx
	if absf(rot) > 0.01:
		_angle = fposmod(_angle + rot * (40.0 if fast else 5.0) * delta, 360.0)

	var t: Array = _tuned()
	var id: StringName = t[0]
	_strength = t[1]
	if id != _sig_id:
		_sig_id = id
		if id != &"":
			_sig.stream = NumbersVoice.stream_or_default(id)
			_sig.play()
		else:
			_sig.stop()
	var level := _strength * _pattern(id)
	_sig.volume_db = linear_to_db(maxf(level, 0.0001)) - 4.0
	_static.volume_db = linear_to_db(maxf(0.32 - _strength * 0.28 + 0.03, 0.0001)) - 8.0
	_meter = lerpf(_meter, level + randf_range(-0.02, 0.02) * _strength, clampf(delta * 8.0, 0.0, 1.0))

	# Перехват: подержал настройку — сигнал в журнале
	if _strength >= 0.85 and id != &"" and id != &"mainland":
		_lock_t += delta
		if _lock_t >= LOCK_TIME and Game.add_intercept(id):
			Game.hud.subtitle(Loc.t(&"radio.intercept", [_freq]), 3.0)
	else:
		_lock_t = 0.0
	# Запись на плёнку (как у рации): держи настройку 5 секунд
	if _rec_t >= 0.0:
		if id == &"" or _strength < 0.7:
			_rec_t = -1.0
			Game.hud.subtitle(Loc.t(&"radio.record_lost"), 2.5)
		else:
			_rec_t += delta
			if _rec_t >= Radio.RECORD_TIME:
				_rec_t = -1.0
				if Game.add_tape(id):
					Game.hud.subtitle(Loc.t(&"radio.recorded"), 3.0)
	if _strength > 0.5 and id != &"mainland":
		Efir.after3_tick(delta)
	_hint.text = _hint_text(id)
	_panel.queue_redraw()


func _hint_text(id: StringName) -> String:
	if _rec_t >= 0.0:
		return Loc.t(&"radio.recording")
	if id == &"" or _strength < 0.5:
		return Loc.t(&"df.hint_tune")
	if Efir.too_close(id, point):
		return Loc.t(&"df.hint_close")
	if not Efir.can_bearing(id):
		return Loc.t(&"df.hint_none")
	return Loc.t(&"df.hint_null")


# --- Рисунок ----------------------------------------------------------------------------

func _draw_panel() -> void:
	var w := _panel.size
	var font := UiStyle.plate_font()
	var face := Color(0.86, 0.83, 0.74)
	var ink := Color(0.12, 0.11, 0.09)
	UiStyle.bakelite(_panel, Rect2(Vector2.ZERO, w))
	# --- Шкала частот ---
	var strip := Rect2(14, 14, w.x - 190, 74)
	_panel.draw_rect(strip, Color(0.08, 0.07, 0.05))
	UiStyle.vgrad(_panel, strip.grow(-3), Color(0.95, 0.8, 0.5), Color(0.75, 0.6, 0.32))   # подсвеченная шкала верньера
	UiStyle.vgrad(_panel, Rect2(strip.position + Vector2(3, 3), Vector2(strip.size.x - 6, 10)), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0))
	var lo := _freq - SPAN_KHZ * 0.5
	for k in range(int(lo / 5.0) * 5, int(lo + SPAN_KHZ) + 6, 5):
		var x := strip.position.x + (float(k) - lo) / SPAN_KHZ * strip.size.x
		if x < strip.position.x + 4 or x > strip.end.x - 4:
			continue
		var long := k % 50 == 0
		var mid := k % 10 == 0
		_panel.draw_line(Vector2(x, strip.end.y - 6), Vector2(x, strip.end.y - (34 if long else (20 if mid else 12))), ink, 2.0 if long else 1.0)
		if long:
			_panel.draw_string(font, Vector2(x - 18, strip.position.y + 26), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var cx := strip.get_center().x
	_panel.draw_line(Vector2(cx, strip.position.y + 2), Vector2(cx, strip.end.y - 2), Color(0.75, 0.1, 0.08), 2.5)
	_panel.draw_string(font, Vector2(strip.end.x - 132, strip.end.y + 28), Loc.t(&"df.khz", [int(roundf(_freq))]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.95, 0.85, 0.6))
	# --- S-метр ---
	var mc := Vector2(w.x - 88, 92)
	_panel.draw_circle(mc, 72, Color(0.45, 0.44, 0.42))
	_panel.draw_circle(mc, 70, Color(0.08, 0.08, 0.08))
	_panel.draw_arc(mc, 62, PI * 1.15, PI * 1.85, 24, face, 22.0)
	for i in 11:
		var a := lerpf(PI * 1.15, PI * 1.85, i / 10.0)
		_panel.draw_line(mc + Vector2(cos(a), sin(a)) * 52, mc + Vector2(cos(a), sin(a)) * 72, ink, 1.5)
	var ma := lerpf(PI * 1.15, PI * 1.85, clampf(_meter, 0.0, 1.0))
	_panel.draw_line(mc, mc + Vector2(cos(ma), sin(ma)) * 66, Color(0.75, 0.1, 0.08), 2.5)
	_panel.draw_string(font, mc + Vector2(-8, 24), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, face)
	# --- Лимб и рамка ---
	var c := Vector2(w.x * 0.5, w.y * 0.62)
	var r := minf(w.x * 0.36, w.y * 0.34)
	UiStyle.dial_face(_panel, c, r)
	for d in 360:
		var a := deg_to_rad(float(d) - 90.0)
		var dir := Vector2(cos(a), sin(a))
		var len := 6.0
		var wd := 1.0
		if d % 10 == 0:
			len = 18.0
			wd = 2.0
		elif d % 5 == 0:
			len = 11.0
			wd = 1.4
		_panel.draw_line(c + dir * (r - len), c + dir * (r - 2), ink, wd)
		if d % 10 == 0:
			var s := str(d)
			_panel.draw_string(font, c + dir * (r - 32) - Vector2(4.5 * s.length(), -5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	var pa := deg_to_rad(_angle - 90.0)
	var pd := Vector2(cos(pa), sin(pa))
	# рамка — поперёк указателя
	var fr := Vector2(-pd.y, pd.x)
	_panel.draw_line(c - fr * (r * 0.55), c + fr * (r * 0.55), Color(0.25, 0.25, 0.27), 9.0)
	_panel.draw_line(c - pd * (r - 6), c + pd * (r - 6), Color(0.75, 0.1, 0.08), 2.0)
	_panel.draw_circle(c + pd * (r - 8), 5.0, Color(0.75, 0.1, 0.08))
	_panel.draw_circle(c, 10, Color(0.3, 0.29, 0.27))
	_panel.draw_circle(c, 6, ink)
	UiStyle.dial_glass(_panel, c, r)
	_panel.draw_string(font, c + Vector2(-6, -r - 22), Loc.t(&"map.north"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, face)


# --- Запись пеленга ---------------------------------------------------------------------

func _write() -> void:
	if _done:
		return
	var t: Array = _tuned()
	var id: StringName = t[0]
	if id == &"" or float(t[1]) < 0.6:
		Game.hud.subtitle(Loc.t(&"df.nothing"), 3.0)
		return
	if Efir.too_close(id, point):
		Game.hud.subtitle(Loc.t(&"df.close"), 4.0)
		return
	if not Efir.can_bearing(id):
		Game.hud.subtitle(Loc.t(&"df.no_null"), 3.5)
		return
	_done = true
	var az := fposmod(_book.value(0), 360.0)
	Efir.record_df(id, point, az)
	Game.add_intercept(id)
	SaveGame.write()
	Game.audio.play_2d(PEN_SFX, -12.0)
	var msg := Loc.t(&"df.written", [int(roundf(_freq)), int(az)])
	var cr := Efir.cross(id)
	if cr.size() == 1:
		msg += " " + Loc.t(&"df.far")
	elif cr.size() == 2:
		msg += " " + Loc.t(&"df.square")
		Director.add_tension(4.0, "пеленги сошлись")
	else:
		msg += " " + Loc.t(&"df.need_second_tower" if point == &"house" else &"df.need_second_house")
	Game.hud.subtitle(msg, 7.0)
	_close()


func _close() -> void:
	closed.emit()


func _panel_input(event: InputEvent) -> void:
	var w := _panel.size
	var c := Vector2(w.x * 0.5, w.y * 0.62)
	var r := minf(w.x * 0.36, w.y * 0.34)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var on_limb := mb.position.distance_to(c) <= r + 14.0
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_drag = mb.pressed and on_limb
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					if on_limb:
						_angle = fposmod(_angle + 0.5, 360.0)
					elif _rec_t < 0.0:
						_freq = clampf(_freq + Radio.WHEEL_STEP, Radio.F_MIN, Radio.F_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					if on_limb:
						_angle = fposmod(_angle - 0.5, 360.0)
					elif _rec_t < 0.0:
						_freq = clampf(_freq - Radio.WHEEL_STEP, Radio.F_MIN, Radio.F_MAX)
	if (event is InputEventMouseMotion and _drag) or (event is InputEventMouseButton and _drag):
		var v: Vector2 = (event as InputEventMouse).position - c
		_angle = fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		_close()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	if (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X):
		var t: Array = _tuned()
		if _rec_t < 0.0 and t[0] != &"" and float(t[1]) >= 0.85 and Game.has_item(&"tape_recorder") \
				and bool(Signals.get_def(t[0]).get("recordable", false)) and not SaveGame.tapes.has(t[0]):
			_rec_t = 0.0
		return
	_book.handle_key(event)
