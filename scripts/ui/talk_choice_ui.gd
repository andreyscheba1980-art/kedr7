class_name TalkChoiceUI
extends Control
## Выбор реплики в сеансе связи. Не останавливает мир и не забирает управление: внизу экрана 2–3 строки,
## [1]/[2]/[3] — сразу ответ; колесо или крестовина — выбрать, [E] — сказать. Время вышло — молчание (-1).
## await TalkChoiceUI.ask(["...", "..."], 14.0) → индекс или -1.

signal picked(i: int)

var _opts: Array = []
var _labels: Array[Label] = []
var _sel := 0
var _time := 14.0
var _left := 14.0
var _bar: ColorRect
var _done := false


static func ask(opts: Array, time := 14.0) -> int:
	var ui := TalkChoiceUI.new()
	ui._opts = opts
	ui._time = time
	ui._left = time
	Game.hud.add_child(ui)
	var r: int = await ui.picked
	ui.queue_free()
	return r


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UiKit.panel(Color(0.03, 0.035, 0.03, 0.82))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -330
	panel.offset_bottom = -180
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	for i in _opts.size():
		var l := UiKit.label("", 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(720, 0)
		box.add_child(l)
		_labels.append(l)
	var hint := UiKit.label(Loc.t(&"talk.hint") + "    " + Loc.t(&"talk.silent"), 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	box.add_child(hint)
	_bar = ColorRect.new()
	_bar.color = UiKit.AMBER
	_bar.custom_minimum_size = Vector2(720, 3)
	box.add_child(_bar)
	_refresh()
	Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -8.0)


func _refresh() -> void:
	for i in _labels.size():
		var on := i == _sel
		_labels[i].text = ("▶ " if on else "   ") + "%d. %s" % [i + 1, String(_opts[i])]
		_labels[i].add_theme_color_override("font_color", UiKit.AMBER if on else UiKit.TEXT)


func _process(delta: float) -> void:
	if _done:
		return
	if get_tree().paused:
		return
	_left -= delta
	if _bar != null:
		_bar.scale.x = clampf(_left / _time, 0.0, 1.0)
	if _left <= 0.0 or Game.dead or Game.shift_over:
		_pick(-1)


func _input(event: InputEvent) -> void:
	if _done or get_tree().paused or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k < KEY_1 + _opts.size():
			get_viewport().set_input_as_handled()
			_pick(k - KEY_1)
			return
	if event is InputEventMouseButton:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			_sel = posmod(_sel + (1 if b == MOUSE_BUTTON_WHEEL_DOWN else -1), _opts.size())
			_refresh()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_up"):
		_sel = posmod(_sel + (1 if event.is_action_pressed(&"ui_down") else -1), _opts.size())
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_pick(_sel)


func _pick(i: int) -> void:
	if _done:
		return
	_done = true
	if i >= 0:
		Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -6.0)
	picked.emit(i)
