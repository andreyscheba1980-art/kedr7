class_name CoopReportUI
extends Control
## Кооп «Две вахты»: бланк синоптической сводки у хоста. Приборы на площадке снимал напарник —
## цифры он диктует по рации [C], хост вписывает их сюда и только потом передаёт на Большую Землю.
## Неверные цифры Свердловск не примет. А продиктовать «не те» может и не напарник.

signal closed

const STAMP := "res://assets/audio/clank.ogg"

var _temp: LineEdit
var _wind: LineEdit
var _snow: LineEdit
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Net.report_open = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	var panel := UiKit.panel(Color(0.88, 0.84, 0.74, 0.98))
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -380, -180, 380, 180)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.ink(UiKit.label(Loc.t(&"coop.rep.title"), 20)))
	var sub := UiKit.ink(UiKit.label(Loc.t(&"coop.rep.sub"), 14))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(700, 0)
	box.add_child(sub)
	_temp = _field(box, Loc.t(&"coop.rep.temp"), "…")
	_wind = _field(box, Loc.t(&"coop.rep.wind"), "…")
	_snow = _field(box, Loc.t(&"coop.rep.snow"), "…")
	_status = UiKit.ink(UiKit.label("", 14))
	_status.add_theme_color_override(&"font_color", Color(0.55, 0.1, 0.1))
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(UiKit.button(Loc.t(&"coop.rep.send"), _submit))
	row.add_child(UiKit.button(Loc.t(&"ui.close"), _close))
	_temp.grab_focus.call_deferred()


func _field(box: VBoxContainer, title: String, hint: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var l := UiKit.ink(UiKit.label(title, 16))
	l.custom_minimum_size = Vector2(380, 0)
	row.add_child(l)
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(140, 40)
	e.max_length = 5
	e.text_submitted.connect(func(_t: String) -> void: _next(e))
	# Рацию [C] можно держать прямо над бланком — буквы в поле не попадают.
	e.text_changed.connect(func(t: String) -> void:
		var clean := ""
		for ch in t:
			if ch in "0123456789-−+,.":
				clean += ch
		if clean != t:
			e.text = clean
			e.caret_column = clean.length())
	row.add_child(e)
	return e


func _next(e: LineEdit) -> void:
	if e == _temp:
		_wind.grab_focus()
	elif e == _wind:
		_snow.grab_focus()
	else:
		_submit()


static func _num(e: LineEdit) -> Variant:
	var t := e.text.strip_edges().replace("−", "-").replace("+", "").replace(",", ".")
	if t == "" or not t.is_valid_float():
		return null
	return int(roundf(float(t)))


func _submit() -> void:
	var t: Variant = _num(_temp)
	var w: Variant = _num(_wind)
	var s: Variant = _num(_snow)
	if t == null or w == null or s == null:
		_status.text = Loc.t(&"coop.rep.empty")
		return
	match Net.check_report(int(t), int(w), int(s)):
		&"ok":
			if Game.audio != null:
				Game.audio.play_2d(STAMP, -8.0)
			Game.coop_report_ok = true
			_close()
			# Бланк подписан — передаём сразу, рация всё ещё на частоте Большой Земли.
			if Game.radio != null:
				(func() -> void:
					Game.radio.enter()
					Game.radio.transmit()).call_deferred()
		&"fever":
			_status.text = Loc.t(&"coop.rep.fever")
			Director.add_tension(14.0, "сводка: +36,6 — это температура человека")
		_:
			_status.text = Loc.t(&"coop.rep.wrong")
			Director.add_tension(6.0, "сводка не сходится")
			Game.add_fatigue(2.0)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_close()
		return true
	return false


func _close() -> void:
	Net.report_open = false
	closed.emit()


func _exit_tree() -> void:
	Net.report_open = false
