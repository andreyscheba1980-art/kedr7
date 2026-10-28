class_name PauseMenu
extends CanvasLayer
## Пауза по Esc: продолжить, настройки, выйти в главное меню. Работает при остановленном дереве.

signal resume_requested
signal menu_requested

var _root: Control
var _box: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	UiKit.place(_root, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	_show_main()


func _show_main() -> void:
	if _box != null:
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	UiKit.place(_root, _box, 0.5, 0.5, 0.5, 0.5, -200, -165, 200, 165)
	var t := UiKit.label(Loc.t(&"pause.title"), 30, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_color", UiKit.AMBER)
	_box.add_child(t)
	var cont := UiKit.button(Loc.t(&"pause.resume"), func() -> void: resume_requested.emit())
	_box.add_child(cont)
	_box.add_child(UiKit.button(Loc.t(&"menu.controls"), _show_controls))
	_box.add_child(UiKit.button(Loc.t(&"menu.settings"), _show_settings))
	_box.add_child(UiKit.button(Loc.t(&"pause.to_menu"), func() -> void: menu_requested.emit()))
	var note := UiKit.label(Loc.t(&"pause.note"), 13, HORIZONTAL_ALIGNMENT_CENTER)
	note.modulate = Color(1, 1, 1, 0.6)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(note)
	cont.grab_focus.call_deferred()


func _show_controls() -> void:
	_box.queue_free()
	_box = null
	var c := ControlsMemoUI.new()
	UiKit.place(_root, c, 0, 0, 1, 1, 0, 0, 0, 0)
	c.closed.connect(func() -> void:
		c.queue_free()
		_show_main())


func _show_settings() -> void:
	_box.queue_free()
	_box = null
	var p := SettingsPanel.new()
	UiKit.place(_root, p, 0.5, 0.5, 0.5, 0.5, -420, -320, 420, 320)
	p.closed.connect(func() -> void:
		p.queue_free()
		_show_main())


func _unhandled_input(event: InputEvent) -> void:
	if _box != null and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
