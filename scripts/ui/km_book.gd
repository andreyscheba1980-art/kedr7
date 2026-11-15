class_name KMBook
extends Control
## Книжка КМ-1: страница с барабанчиками, в которые дежурный сам вписывает снятое с прибора.
## Строка — {"label": String, "cells": [&"sign" | &"digit" | &"rumb"], "dot": индекс ячейки, перед которой
## десятичная точка (-1 — нет), "unit": String}. Ввод: клик по верхней/нижней половине барабана,
## колёсико, стрелки, цифры, «−»/«+», крестовина. Enter (записать) ловит владелец.
## Вид — листок книжки (UiStyle): бумага шейдером, типографская сетка бланка, вписанное — почерком
## синей ручкой; выбранная клетка подсвечена карандашом.

const C_PAGE := Color(0.93, 0.90, 0.82)
const C_INK := Color(0.10, 0.12, 0.28)
const C_MUTED := Color(0.42, 0.40, 0.36)
const TICK_SFX := "res://assets/audio/ui_tick.ogg"
const TOP := 92.0
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
var _ink: Control
var _hover := -1
var heading := ""           ## не книжка КМ-1, а что-то своё (сейф): заголовок вместо бланка


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
	if _ink == null:
		UiStyle.paper(self, float(get_instance_id() % 97) * 0.37)
		_ink = Control.new()
		_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ink)
		_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ink.draw.connect(_draw_ink)
		rotation_degrees = -0.8
		resized.connect(func() -> void: pivot_offset = size * 0.5)
	_redraw()


func _redraw() -> void:
	queue_redraw()
	if _ink != null:
		_ink.queue_redraw()


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
	_redraw()


# --- Правка -----------------------------------------------------------------------------

func select(i: int) -> void:
	_sel = clampi(i, 0, _flat.size() - 1)
	_redraw()


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
	_redraw()


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
	_redraw()


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
	if event is InputEventMouseMotion:
		var hv := -1
		for i in _flat.size():
			if cell_rect(_flat[i][0], _flat[i][1]).grow_individual(4, 20, 4, 20).has_point((event as InputEventMouseMotion).position):
				hv = i
		if hv != _hover:
			_hover = hv
			_redraw()
		return
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

## Под листком — тень (сам листок с чернилами рисуют дети: бумага и слой чернил).
func _draw() -> void:
	draw_rect(Rect2(Vector2(6, 8), size), Color(0, 0, 0, 0.45))


func _draw_ink() -> void:
	var ci := _ink
	var w := size
	var tf := UiStyle.type_font()
	var hf := UiStyle.hand_font()
	# Типографская разлиновка и поля
	for y in range(TOP - 6, int(w.y) - 12, 24):
		ci.draw_line(Vector2(14, y), Vector2(w.x - 12, y), Color(UiStyle.INK_PRINT, 0.16), 1.0)
	ci.draw_line(Vector2(44, 6), Vector2(44, w.y - 6), Color(UiStyle.INK_RED, 0.45), 1.0)
	ci.draw_line(Vector2(47, 6), Vector2(47, w.y - 6), Color(UiStyle.INK_RED, 0.3), 1.0)
	# Шапка бланка
	if heading != "":
		ci.draw_string(tf, Vector2(56, 52), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiStyle.INK_TYPE)
	else:
		ci.draw_string(tf, Vector2(56, 24), Loc.t(&"km.head"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UiStyle.INK_PRINT, 0.9))
		ci.draw_string(tf, Vector2(56, 46), Loc.t(&"thermo.book"), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiStyle.INK_TYPE)
		ci.draw_string(tf, Vector2(56, 70), Loc.t(&"km.term"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiStyle.INK_TYPE, 0.8))
		ci.draw_string(hf, Vector2(56 + tf.get_string_size(Loc.t(&"km.term"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8, 72), Game.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.INK_PEN)
	var ch := _cell_h()
	var fs := 50 if ch >= 56.0 else 42
	for r in rows.size():
		var cells: Array = rows[r]["cells"]
		ci.draw_string(tf, Vector2(56, TOP + r * _row_h() + 16), String(rows[r]["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.INK_TYPE)
		for c in cells.size():
			var rect := cell_rect(r, c)
			var idx := _flat.find([r, c])
			var sel := idx == _sel
			if sel:
				ci.draw_rect(rect.grow(2), Color(1.0, 0.86, 0.35, 0.28))       # подсвечено карандашом
			ci.draw_rect(rect, Color(UiStyle.INK_PRINT, 0.55), false, 1.0)   # клетка бланка
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
					size_f = fs - 12
			var sw := hf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_f).x
			var base := rect.position.y + rect.size.y * 0.5 + hf.get_ascent(size_f) * 0.36
			# почерк чуть пляшет: у каждой клетки свой наклон и сдвиг
			var jit := Vector2(float((r * 7 + c * 13) % 5) - 2.0, float((r * 3 + c * 5) % 3) - 1.0)
			ci.draw_string(hf, Vector2(rect.position.x + (rect.size.x - sw) * 0.5, base) + jit, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_f, UiStyle.INK_PEN)
			var cx := rect.get_center().x
			var a := 0.8 if sel else (0.35 if idx == _hover else 0.0)
			if a > 0.0:
				var col := Color(UiStyle.PENCIL, a)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 7, rect.position.y - 5), Vector2(cx + 7, rect.position.y - 5), Vector2(cx, rect.position.y - 13)]), col)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 7, rect.end.y + 5), Vector2(cx + 7, rect.end.y + 5), Vector2(cx, rect.end.y + 13)]), col)
		var dot := int(rows[r].get("dot", -1))
		if dot > 0:
			var prev := cell_rect(r, dot - 1)
			ci.draw_string(hf, Vector2(prev.end.x + 2, prev.end.y - 4), ",", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.INK_PEN)
		var last := cell_rect(r, cells.size() - 1)
		ci.draw_string(tf, Vector2(last.end.x + 8, last.end.y - ch * 0.3), String(rows[r].get("unit", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.INK_TYPE)
	if heading == "" and Game.is_night() and Game.night == 1:
		var faded_col := Color(0.24, 0.28, 0.38, 0.70)
		var sem_txt := "Семёнов (02:00): t=-32.4°C, ветер ССВ 14 м/с. На площадке слыш..." if Loc.is_ru() else "Semyonov (02:00): t=-32.4°C, wind NNW 14 m/s. At yard heard..."
		ci.draw_string(hf, Vector2(56, w.y - 28), sem_txt, HORIZONTAL_ALIGNMENT_LEFT, w.x - 70, 16, faded_col)
	ci.draw_string(tf, Vector2(56, w.y - 14), Loc.t(&"thermo.keys"), HORIZONTAL_ALIGNMENT_LEFT, w.x - 66, 11, Color(UiStyle.PENCIL, 0.75))
