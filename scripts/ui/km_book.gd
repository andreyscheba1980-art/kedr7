class_name KMBook
extends Control
## Книжка КМ-1: страница с барабанчиками, в которые дежурный сам вписывает снятое с прибора.
## Строка — {"label": String, "cells": [&"sign" | &"digit" | &"rumb"], "dot": индекс ячейки, перед которой
## десятичная точка (-1 — нет), "unit": String}. Ввод: клик по верхней/нижней половине барабана,
## колёсико, стрелки, цифры, «−»/«+», крестовина. Enter (записать) ловит владелец.

const C_PAGE := Color(0.93, 0.90, 0.82)
const C_INK := Color(0.10, 0.12, 0.28)
const C_MUTED := Color(0.42, 0.40, 0.36)
const TICK_SFX := "res://assets/audio/ui_tick.ogg"
const TOP := 72.0
const BOTTOM := 40.0
const CELL_W := 46.0
const RUMB_W := 78.0
const GAP := 6.0
const X0 := 70.0

var rows: Array = []
var vals: Array = []        ## по строке: Array[int] (знак: 1 — минус; цифра 0..9; румб 0..15)
var _flat: Array = []       ## [[строка, ячейка]] в порядке обхода
var _sel := 0
var _rumbs: PackedStringArray


func setup(p_rows: Array) -> void:
	rows = p_rows
	vals.clear()
	_flat.clear()
	for r in rows.size():
		var cells: Array = rows[r]["cells"]
		var v: Array = []
		for c in cells.size():
			v.append(1 if cells[c] == &"sign" else 0)
			_flat.append([r, c])
		vals.append(v)
	_rumbs = Loc.t(&"pult.rumbs").split(",")
	_sel = 0
	while _sel < _flat.size() - 1 and _cell(_sel) == &"sign":
		_sel += 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not gui_input.is_connected(_mouse):
		gui_input.connect(_mouse)
	queue_redraw()


func _cell(i: int) -> StringName:
	var rc: Array = _flat[i]
	return rows[rc[0]]["cells"][rc[1]]


func _row_h() -> float:
	return (size.y - TOP - BOTTOM) / maxf(1.0, rows.size())


func _cell_h() -> float:
	return clampf(_row_h() - 54.0, 40.0, 62.0)


func cell_rect(r: int, c: int) -> Rect2:
	var cells: Array = rows[r]["cells"]
	var x := X0
	for i in c:
		x += (RUMB_W if cells[i] == &"rumb" else CELL_W) + GAP
		if int(rows[r].get("dot", -1)) == i + 1:
			x += 12.0
	var y := TOP + r * _row_h() + 34.0
	return Rect2(x, y, RUMB_W if cells[c] == &"rumb" else CELL_W, _cell_h())


# --- Значения ---------------------------------------------------------------------------

func value(r: int) -> float:
	var cells: Array = rows[r]["cells"]
	var dot := int(rows[r].get("dot", -1))
	var neg := false
	var s := ""
	for c in cells.size():
		match cells[c]:
			&"sign":
				neg = vals[r][c] == 1
			&"digit":
				if c == dot:
					s += "."
				s += str(vals[r][c])
			&"rumb":
				return float(vals[r][c])
	var v := float(s) if s != "" else 0.0
	return -v if neg else v


func set_value(r: int, v: float) -> void:
	var cells: Array = rows[r]["cells"]
	var dot := int(rows[r].get("dot", -1))
	var frac := 0
	if dot >= 0:
		for c in range(dot, cells.size()):
			if cells[c] == &"digit":
				frac += 1
	var n := int(roundf(absf(v) * pow(10.0, frac)))
	for c in range(cells.size() - 1, -1, -1):
		match cells[c]:
			&"digit":
				vals[r][c] = n % 10
				n /= 10
			&"sign":
				vals[r][c] = 1 if v < 0.0 else 0
			&"rumb":
				vals[r][c] = posmod(int(v), 16)
	queue_redraw()


# --- Правка -----------------------------------------------------------------------------

func select(i: int) -> void:
	_sel = clampi(i, 0, _flat.size() - 1)
	queue_redraw()


func bump(step: int) -> void:
	var rc: Array = _flat[_sel]
	match _cell(_sel):
		&"sign":
			vals[rc[0]][rc[1]] = 1 - int(vals[rc[0]][rc[1]])
		&"digit":
			vals[rc[0]][rc[1]] = posmod(int(vals[rc[0]][rc[1]]) + step, 10)
		&"rumb":
			vals[rc[0]][rc[1]] = posmod(int(vals[rc[0]][rc[1]]) + step, 16)
	Game.audio.play_2d(TICK_SFX, -14.0)
	queue_redraw()


func type_digit(n: int) -> void:
	if _cell(_sel) == &"sign" and _sel < _flat.size() - 1:
		_sel += 1
	if _cell(_sel) != &"digit":
		return
	var rc: Array = _flat[_sel]
	vals[rc[0]][rc[1]] = n
	Game.audio.play_2d(TICK_SFX, -14.0)
	select(_sel + 1)


func set_sign(neg: bool) -> void:
	var r: int = _flat[_sel][0]
	var cells: Array = rows[r]["cells"]
	for c in cells.size():
		if cells[c] == &"sign":
			vals[r][c] = 1 if neg else 0
			for i in _flat.size():
				if _flat[i][0] == r and _flat[i][1] == c + 1:
					select(i)
					return
	queue_redraw()


## Клавиатура и крестовина; true — событие съедено.
func handle_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		match k:
			KEY_LEFT, KEY_BACKSPACE:
				select(_sel - 1)
			KEY_RIGHT, KEY_TAB:
				select(_sel + 1)
			KEY_UP:
				bump(1)
			KEY_DOWN:
				bump(-1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_sign(true)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				set_sign(false)
			_:
				if k >= KEY_0 and k <= KEY_9:
					type_digit(k - KEY_0)
				elif k >= KEY_KP_0 and k <= KEY_KP_9:
					type_digit(k - KEY_KP_0)
				else:
					return false
		return true
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT:
				select(_sel - 1)
			JOY_BUTTON_DPAD_RIGHT:
				select(_sel + 1)
			JOY_BUTTON_DPAD_UP:
				bump(1)
			JOY_BUTTON_DPAD_DOWN:
				bump(-1)
			_:
				return false
		return true
	return false


func _mouse(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.is_pressed():
		return
	var mb := event as InputEventMouseButton
	for i in _flat.size():
		var rc: Array = _flat[i]
		var r := cell_rect(rc[0], rc[1])
		if not r.grow_individual(4, 20, 4, 20).has_point(mb.position):
			continue
		select(i)
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				bump(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				bump(-1)
			MOUSE_BUTTON_LEFT:
				bump(1 if mb.position.y < r.get_center().y else -1)
		return


# --- Рисунок ----------------------------------------------------------------------------

func _draw() -> void:
	var w := size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, w), Color(0.20, 0.18, 0.15))
	draw_rect(Rect2(6, 6, w.x - 12, w.y - 12), C_PAGE)
	for y in range(70, int(w.y) - 10, 22):
		draw_line(Vector2(16, y), Vector2(w.x - 16, y), Color(0.78, 0.74, 0.64, 0.4), 1.0)
	draw_line(Vector2(46, 12), Vector2(46, w.y - 12), Color(0.75, 0.25, 0.25, 0.45), 1.0)
	draw_string(font, Vector2(58, 36), Loc.t(&"thermo.book"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_INK)
	draw_string(font, Vector2(58, 57), Loc.t(&"thermo.term", [Game.clock_text()]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_MUTED)
	var ch := _cell_h()
	var fs := 34 if ch >= 56.0 else 28
	for r in rows.size():
		var cells: Array = rows[r]["cells"]
		draw_string(font, Vector2(58, TOP + r * _row_h() + 16), String(rows[r]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_INK)
		for c in cells.size():
			var rect := cell_rect(r, c)
			var sel: bool = _flat[_sel][0] == r and _flat[_sel][1] == c
			draw_rect(rect, Color(0.16, 0.15, 0.14))
			draw_rect(rect.grow(-3), Color(0.97, 0.95, 0.88) if sel else Color(0.88, 0.85, 0.77))
			if sel:
				draw_rect(rect.grow(2), Color(0.75, 0.45, 0.1), false, 2.0)
			var d: int = vals[r][c]
			var s := ""
			var size_f := fs
			match cells[c]:
				&"sign":
					s = "−" if d == 1 else "+"
				&"digit":
					s = str(d)
				&"rumb":
					s = _rumbs[d] if d < _rumbs.size() else "?"
					size_f = fs - 6
			var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_f).x
			draw_string(font, Vector2(rect.position.x + (rect.size.x - sw) * 0.5, rect.position.y + rect.size.y * 0.5 + size_f * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_f, C_INK)
			var cx := rect.get_center().x
			var ac := C_INK if sel else C_MUTED
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, rect.position.y - 5), Vector2(cx + 8, rect.position.y - 5), Vector2(cx, rect.position.y - 14)]), ac)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, rect.end.y + 5), Vector2(cx + 8, rect.end.y + 5), Vector2(cx, rect.end.y + 14)]), ac)
		var dot := int(rows[r].get("dot", -1))
		if dot > 0:
			var prev := cell_rect(r, dot - 1)
			draw_circle(Vector2(prev.end.x + 9, prev.end.y - 9), 3.5, C_INK)
		var last := cell_rect(r, cells.size() - 1)
		draw_string(font, Vector2(last.end.x + 8, last.end.y - ch * 0.3), String(rows[r].get("unit", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, C_INK)
	draw_string(font, Vector2(58, w.y - 16), Loc.t(&"thermo.keys"), HORIZONTAL_ALIGNMENT_LEFT, w.x - 70, 12, C_MUTED)
