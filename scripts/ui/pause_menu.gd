class_name PauseMenu
extends CanvasLayer
## Пауза по Esc: продолжить, журнал ТМ-1, схема станции, настройки, выйти в главное меню. Работает при остановленном дереве.

signal resume_requested
signal menu_requested

const JournalTM1UIScript = preload("res://scripts/ui/journal_tm1_ui.gd")
const MapViewScript = preload("res://scripts/ui/map_view.gd")
const TelemetryButtonClass = preload("res://scripts/ui/telemetry_button.gd")

var _root: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _sub_modal: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.018, 0.026, 0.028, 0.84)
	UiKit.place(_root, dim, 0, 0, 1, 1, 0, 0, 0, 0)
	_show_main()


func _make_telem_btn(idx: String, title: String, hint: String, on_press: Callable) -> Button:
	var b = TelemetryButtonClass.new()
	b.custom_minimum_size = Vector2(520.0, 42.0)
	b.set_data(idx, title, hint)
	b.pressed.connect(on_press)
	return b


func _show_main() -> void:
	if _sub_modal != null and is_instance_valid(_sub_modal):
		_sub_modal.queue_free()
		_sub_modal = null

	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.042, 0.058, 0.062, 0.96)
	sb.border_color = Color("#4B5B53")
	sb.set_border_width_all(2)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 18
	sb.shadow_color = Color(0, 0, 0, 0.78)
	sb.shadow_size = 20
	_panel.add_theme_stylebox_override("panel", sb)

	UiKit.place(_root, _panel, 0.5, 0.5, 0.5, 0.5, -295, -248, 295, 248)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 7)
	_panel.add_child(_box)

	var agency := UiKit.label(Loc.p("ГОСКОМГИДРОМЕТ СССР · СТАНЦИЯ «КЕДР-7»", "USSR HYDROMET · STATION KEDR-7"), 10, HORIZONTAL_ALIGNMENT_CENTER)
	agency.add_theme_color_override("font_color", Color("#687873"))
	_box.add_child(agency)

	var t := UiKit.label(Loc.t(&"pause.title"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_color", Color("#FFA62B"))
	_box.add_child(t)

	# Телеметрическая плашка статуса текущей смены
	var night_n := Game.night
	var is_night := Game.is_night()
	var phase_str := Loc.p("ПОЛЯРНАЯ НОЧЬ", "POLAR NIGHT") if is_night else Loc.p("ДНЕВНАЯ СМЕНА", "DAY SHIFT")
	if Game.is_prologue():
		phase_str = Loc.p("ПРОЛОГ · ПРИБЫТИЕ", "PROLOGUE · ARRIVAL")
	var temp_c: int = int(roundf(Game.synoptic.temp_dry)) if Game.synoptic != null else -41
	var clock_str := Game.minutes_to_clock(int(Game.shift_minutes))
	var status_text := Loc.p(
		"СУТКИ %02d · %s // %s МСК // %d°C" % [night_n, phase_str, clock_str, temp_c],
		"SHIFT %02d · %s // %s MSK // %d°C" % [night_n, phase_str, clock_str, temp_c]
	)
	var sub := UiKit.label(status_text, 11, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color", Color("#8A9E96"))
	_box.add_child(sub)

	var sep := ColorRect.new()
	sep.color = Color("#3A4D48")
	sep.custom_minimum_size = Vector2(0, 1)
	_box.add_child(sep)

	var cont := _make_telem_btn(Loc.p("КН-01", "BTN-01"), Loc.p("ПРОДОЛЖИТЬ ВАХТУ", "RESUME WATCH"), "Esc", func() -> void: resume_requested.emit())
	_box.add_child(cont)

	var jrn_btn := _make_telem_btn(Loc.p("ТМ-02", "DOC-02"), Loc.p("ЖУРНАЛ СМЕНЫ ТМ-1", "LOGBOOK TM-1"), "J / F9", _show_journal)
	_box.add_child(jrn_btn)

	var map_btn := _make_telem_btn(Loc.p("СК-03", "MAP-03"), Loc.p("СХЕМА СТАНЦИИ И ЛЕЕРОВ", "STATION & GROUNDS MAP"), "M", _show_map)
	_box.add_child(map_btn)

	var ctrl_btn := _make_telem_btn(Loc.p("РГ-04", "REG-04"), Loc.p("ПАМЯТКА ДЕЖУРНОГО", "DUTY MANUAL"), Loc.p("ПРИБОРЫ", "CONTROLS"), _show_controls)
	_box.add_child(ctrl_btn)

	var set_btn := _make_telem_btn(Loc.p("КА-05", "CAL-05"), Loc.p("РЕГЛАМЕНТ ПРИБОРОВ", "CALIBRATION"), Loc.p("НАСТРОЙКИ", "SETTINGS"), _show_settings)
	_box.add_child(set_btn)

	var menu_btn := _make_telem_btn(Loc.p("ВЫХ-00", "EXT-00"), Loc.p("СДАТЬ СМЕНУ", "RELINQUISH POST"), Loc.p("ГЛ. МЕНЮ", "MAIN MENU"), func() -> void: menu_requested.emit())
	_box.add_child(menu_btn)

	var sep2 := ColorRect.new()
	sep2.color = Color(0.23, 0.30, 0.28, 0.55)
	sep2.custom_minimum_size = Vector2(0, 1)
	_box.add_child(sep2)

	var note := UiKit.label(Loc.t(&"pause.note"), 11, HORIZONTAL_ALIGNMENT_CENTER)
	note.modulate = Color(0.75, 0.82, 0.79, 0.72)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(note)

	var btns: Array[Button] = [cont, jrn_btn, map_btn, ctrl_btn, set_btn, menu_btn]
	for i in btns.size():
		btns[i].focus_neighbor_top = btns[(i - 1 + btns.size()) % btns.size()].get_path()
		btns[i].focus_neighbor_bottom = btns[(i + 1) % btns.size()].get_path()

	cont.grab_focus.call_deferred()


func _show_journal() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null
	var jrn = JournalTM1UIScript.new()
	_sub_modal = jrn
	UiKit.place(_root, jrn, 0, 0, 1, 1, 0, 0, 0, 0)
	jrn.closed.connect(func() -> void:
		_show_main())


func _show_map() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null
	var m = MapViewScript.new()
	_sub_modal = m
	UiKit.place(_root, m, 0, 0, 1, 1, 0, 0, 0, 0)
	m.closed.connect(func() -> void:
		_show_main())


func _show_controls() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null
	var c := ControlsMemoUI.new()
	_sub_modal = c
	UiKit.place(_root, c, 0, 0, 1, 1, 0, 0, 0, 0)
	c.closed.connect(func() -> void:
		_show_main())


func _show_settings() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_box = null
	var p := SettingsPanel.new()
	_sub_modal = p
	UiKit.place(_root, p, 0.5, 0.5, 0.5, 0.5, -420, -320, 420, 320)
	p.closed.connect(func() -> void:
		_show_main())


func _unhandled_input(event: InputEvent) -> void:
	if _sub_modal != null and is_instance_valid(_sub_modal):
		return
	if _panel != null:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			resume_requested.emit()
		elif event.is_action_pressed(&"map"):
			get_viewport().set_input_as_handled()
			_show_map()
		elif InputMap.has_action(&"journal") and event.is_action_pressed(&"journal"):
			get_viewport().set_input_as_handled()
			_show_journal()
