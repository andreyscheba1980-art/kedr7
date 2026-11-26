class_name AchievementsUI
extends Control
## Список достижений: бумажный лист, полученные — чернилами, остальные — серым под замком с намёком.

signal closed


func _ready() -> void:
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sheet := UiKit.panel(Color(0.86, 0.82, 0.7, 0.97))
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(720, 560)
	sheet.position = -sheet.custom_minimum_size * 0.5
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	sheet.add_child(v)
	v.add_child(UiKit.ink(UiKit.label(Loc.t(&"ach.title") + "   %d / %d" % [Achievements.count(), Achievements.LIST.size()], 22)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id: StringName in Achievements.LIST:
		var got := Achievements.has(id)
		var row := VBoxContainer.new()
		list.add_child(row)
		var t := UiKit.ink(UiKit.label(("✓  " if got else "🔒  ") + Loc.t(StringName("ach.%s" % id)), 17))
		if not got:
			t.add_theme_color_override("font_color", Color(0.4, 0.38, 0.34))
		row.add_child(t)
		var d := UiKit.ink(UiKit.label(Loc.t(StringName("ach.%s.d" % id)), 13))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 660
		d.modulate.a = 1.0 if got else 0.6
		row.add_child(d)
	var back := UiKit.button(Loc.t(&"ui.back"), func() -> void: closed.emit())
	v.add_child(back)
	UiKit.safe_focus(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
