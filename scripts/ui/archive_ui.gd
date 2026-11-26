class_name ArchiveUI
extends Control
## Архив служебных дел и расследований станции «Кедр-7» (УГМС Свердловск-44):
## Финалы вахт, найденные плёнки Семёнова, заветы дежурных и следственные вердикты.

signal closed

const CovenantsClass = preload("res://scripts/data/covenants.gd")

var _scroll: ScrollContainer
var _close_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel(Color(0.86, 0.82, 0.72, 0.98))
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -500, -330, 500, 330)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Заголовок архива
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title := UiKit.ink(UiKit.label(Loc.t(&"arch.title"), 18))
	top_bar.add_child(title)

	top_bar.add_spacer(false)

	_close_btn = UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(_close_btn)

	var sub := UiKit.ink(UiKit.label(Loc.t(&"arch.sub"), 13))
	sub.modulate.a = 0.75
	root_vbox.add_child(sub)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	root_vbox.add_child(_scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)

	# 1. Секция: Финалы вахты
	_build_endings_section(content)

	# 2. Секция: Плёнки Семёнова
	_build_tapes_section(content)

	# 3. Секция: Заветы дежурных
	_build_covenants_section(content)

	UiKit.safe_focus(_close_btn)


func _build_endings_section(parent: VBoxContainer) -> void:
	var sec_title := UiKit.ink(UiKit.label("I. " + Loc.t(&"arch.endings"), 16))
	sec_title.add_theme_color_override("font_color", Color(0.52, 0.18, 0.10))
	parent.add_child(sec_title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)

	# Те же шесть концовок, что в Session.ENDINGS; открыта — если session записала флаг ending_<id>.
	for id: StringName in [&"answer", &"burn", &"leave", &"silence", &"echo", &"source"]:
		var title := Loc.t(StringName("end.%s.title" % id)).split("\n")[0]
		var unlocked := bool(SaveGame.flags.get("ending_" + String(id), false))
		_ending_row(box, title, Loc.t(StringName("arch.desc_%s" % id)), unlocked)


func _ending_row(parent: VBoxContainer, title: String, desc: String, unlocked: bool) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var status_text := title if unlocked else Loc.t(&"arch.locked")
	var l_title := UiKit.ink(UiKit.label(status_text, 14))
	if not unlocked:
		l_title.modulate = Color(1, 1, 1, 0.45)
	row.add_child(l_title)

	if unlocked:
		var l_desc := UiKit.ink(UiKit.label("    " + desc, 12))
		l_desc.modulate = Color(1, 1, 1, 0.75)
		l_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l_desc)


func _build_tapes_section(parent: VBoxContainer) -> void:
	var sec_title := UiKit.ink(UiKit.label("II. " + Loc.t(&"arch.tapes"), 16))
	sec_title.add_theme_color_override("font_color", Color(0.52, 0.18, 0.10))
	parent.add_child(sec_title)

	var total_tapes: int = SaveGame.tapes.size()
	var cleaned_count: int = 0
	for d: Variant in SaveGame.decoded:
		if String(d).ends_with("_clean") or d == &"code":
			cleaned_count += 1

	var summary := UiKit.ink(UiKit.label(Loc.p("  • Найдено бобин в тайге: %d из 12   |   Очищено слоёв реверса: %d", "  • Reels found in the taiga: %d of 12   |   Reverse layers cleaned: %d") % [total_tapes, cleaned_count], 13))
	summary.modulate = Color(1, 1, 1, 0.85)
	parent.add_child(summary)


func _build_covenants_section(parent: VBoxContainer) -> void:
	var sec_title := UiKit.ink(UiKit.label("III. " + Loc.t(&"arch.covenants"), 16))
	sec_title.add_theme_color_override("font_color", Color(0.52, 0.18, 0.10))
	parent.add_child(sec_title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)

	for entry: Dictionary in CovenantsClass.ENTRIES:
		if not CovenantsClass.visible(entry):
			continue
		var st: String = CovenantsClass.get_state(CovenantsClass.eid(entry))
		var st_label := Loc.p("Не проверено", "Unchecked")
		var st_color := Color(0.4, 0.4, 0.4)
		if st == "true":
			st_label = Loc.p("✓ ИСТИНА", "✓ TRUE")
			st_color = Color(0.12, 0.55, 0.18)
		elif st == "false":
			st_label = Loc.p("✗ ЛОЖЬ", "✗ FALSE")
			st_color = Color(0.65, 0.22, 0.12)
		elif st == "sabotage" or st == "danger":
			st_label = Loc.p("⚠ ДИВЕРСИЯ", "⚠ SABOTAGE")
			st_color = Color(0.72, 0.42, 0.08)

		var row := HBoxContainer.new()
		box.add_child(row)

		var entry_text: String = CovenantsClass.text(entry)
		var entry_author: String = CovenantsClass.author(entry)
		var l_text := UiKit.ink(UiKit.label("  • " + entry_text + " (%s)" % entry_author, 12))
		l_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l_text)

		var l_st := UiKit.ink(UiKit.label(st_label, 12))
		l_st.add_theme_color_override("font_color", st_color)
		row.add_child(l_st)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()


func handle_input(event: InputEvent) -> void:
	_unhandled_input(event)


func _close() -> void:
	closed.emit()
