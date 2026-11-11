class_name PauseMenu
extends CanvasLayer
## Пауза по Esc: продолжить, настройки, выйти в главное меню. Работает при остановленном дереве.

signal resume_requested
signal menu_requested

var _root: Control
var _panel: PanelContainer
var _box: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.03, 0.78)
	UiKit.place(_root, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	_show_main()


func _show_main() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.06, 0.065, 0.95)
	sb.border_color = Color("#3A4D48")
	sb.set_border_width_all(2)
	sb.border_blend = true
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", sb)

	UiKit.place(_root, _panel, 0.5, 0.5, 0.5, 0.5, -230, -195, 230, 195)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_box)

	var t := UiKit.label(Loc.t(&"pause.title"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_color", UiKit.AMBER)
	_box.add_child(t)

	var sub := UiKit.label(Loc.p("МЕТЕОСТАНЦИЯ «КЕДР-7» · ДЕЖУРНАЯ СМЕНА", "METEO STATION KEDR-7 · ACTIVE SHIFT"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color", Color("#6B7E78"))
	_box.add_child(sub)

	var cont := UiKit.button(Loc.t(&"pause.resume"), func() -> void: resume_requested.emit())
	_box.add_child(cont)

	var ctrl_btn := UiKit.button(Loc.t(&"pause.controls"), _show_controls)
	_box.add_child(ctrl_btn)

	var set_btn := UiKit.button(Loc.t(&"pause.settings"), _show_settings)
	_box.add_child(set_btn)

	var menu_btn := UiKit.button(Loc.t(&"pause.to_menu"), func() -> void: menu_requested.emit())
	_box.add_child(menu_btn)

	var note := UiKit.label(Loc.t(&"pause.note"), 12, HORIZONTAL_ALIGNMENT_CENTER)
	note.modulate = Color(0.8, 0.85, 0.82, 0.65)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(note)

	cont.grab_focus.call_deferred()


func _show_controls() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null
	var c := ControlsMemoUI.new()
	UiKit.place(_root, c, 0, 0, 1, 1, 0, 0, 0, 0)
	c.closed.connect(func() -> void:
		c.queue_free()
		_show_main())


func _show_settings() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null
	var p := SettingsPanel.new()
	UiKit.place(_root, p, 0.5, 0.5, 0.5, 0.5, -420, -320, 420, 320)
	p.closed.connect(func() -> void:
		p.queue_free()
		_show_main())


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
