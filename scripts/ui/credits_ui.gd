class_name CreditsUI
extends Control
## Титры: медленно ползут снизу вверх на чёрном, под метель за окном. Любая клавиша — быстрее, Esc — выйти.

signal closed

const SPEED := 38.0

var _col: VBoxContainer
var _fast := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.012, 0.02)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	add_child(_col)
	_col.custom_minimum_size.x = 900
	for line: String in Loc.t(&"credits.text").split("\n"):
		var big := line.begins_with("#")
		var l := UiKit.label(line.trim_prefix("#").strip_edges(), 26 if big else 17, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = 900
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if big:
			l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
		else:
			l.modulate.a = 0.85
		_col.add_child(l)
	_col.position = Vector2((get_viewport_rect().size.x - 900) * 0.5, get_viewport_rect().size.y + 20)


func _process(delta: float) -> void:
	_col.position.y -= SPEED * delta * (4.0 if _fast else 1.0)
	if _col.position.y + _col.size.y < -40:
		closed.emit()
		set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
		set_process(false)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		_fast = event.is_pressed()
