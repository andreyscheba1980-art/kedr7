class_name ControlsMemoUI
extends Control
## Советская типографская памятка дежурному по метеостанции «Кедр-7»:
## Полная схема раскладки управления для клавиатуры/мыши и геймпада с динамическим переключением.

signal closed

var _is_joy := false
var _layout_box: HBoxContainer
var _toggle_btn: Button
var _close_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_is_joy = Game.is_gamepad if Game != null else false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	UiKit.place(self, dim, 0, 0, 1, 1, 0, 0, 0, 0)

	var panel := UiKit.panel(UiKit.PAPER)
	UiKit.place(self, panel, 0.5, 0.5, 0.5, 0.5, -480, -320, 480, 320)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# Шапка формуляра
	var top_bar := HBoxContainer.new()
	root_vbox.add_child(top_bar)

	var title := UiKit.ink(UiKit.label(Loc.t(&"ctrl.title"), 18))
	top_bar.add_child(title)

	top_bar.add_spacer(false)

	_toggle_btn = UiKit.button(_toggle_text(), _toggle_device)
	top_bar.add_child(_toggle_btn)

	_close_btn = UiKit.button(Loc.t(&"ui.close"), _close)
	top_bar.add_child(_close_btn)

	var sub := UiKit.ink(UiKit.label(Loc.t(&"ctrl.sub"), 13))
	sub.modulate.a = 0.75
	root_vbox.add_child(sub)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Область колонок схемы управления
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cols)

	_layout_box = cols
	_rebuild_content()
	_close_btn.grab_focus.call_deferred()


func _toggle_text() -> String:
	return Loc.t(&"ctrl.device_joy") if _is_joy else Loc.t(&"ctrl.device_kb")


func _toggle_device() -> void:
	_is_joy = not _is_joy
	_toggle_btn.text = _toggle_text()
	_rebuild_content()


func _rebuild_content() -> void:
	for c in _layout_box.get_children():
		c.queue_free()

	# Колонка 1: Основные действия
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 8)
	_layout_box.add_child(col1)

	var h1 := UiKit.ink(UiKit.label(Loc.t(&"ctrl.group_main"), 15))
	h1.add_theme_color_override("font_color", Color(0.55, 0.22, 0.12))
	col1.add_child(h1)

	if _is_joy:
		_row(col1, Loc.t(&"ctrl.move"), Loc.p("Левый аналоговый стик (L-Stick)", "Left stick (L-Stick)"))
		_row(col1, Loc.t(&"ctrl.look"), Loc.p("Правый аналоговый стик (R-Stick)", "Right stick (R-Stick)"))
		_row(col1, Loc.t(&"ctrl.interact"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"interact"))
		_row(col1, Loc.t(&"ctrl.flashlight"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"flashlight"))
		_row(col1, Loc.t(&"ctrl.crank"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"crank"))
		_row(col1, Loc.t(&"ctrl.drop"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"drop"))
	else:
		_row(col1, Loc.t(&"ctrl.move"), Loc.p("[W, A, S, D] / Стрелки", "[W, A, S, D] / Arrows"))
		_row(col1, Loc.t(&"ctrl.look"), Loc.p("Движение мыши", "Mouse movement"))
		_row(col1, Loc.t(&"ctrl.interact"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"interact"))
		_row(col1, Loc.t(&"ctrl.flashlight"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"flashlight"))
		_row(col1, Loc.t(&"ctrl.crank"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"crank"))
		_row(col1, Loc.t(&"ctrl.drop"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"drop"))

	# Колонка 2: Документы и приборы
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 8)
	_layout_box.add_child(col2)

	var h2 := UiKit.ink(UiKit.label(Loc.t(&"ctrl.group_docs"), 15))
	h2.add_theme_color_override("font_color", Color(0.55, 0.22, 0.12))
	col2.add_child(h2)

	if _is_joy:
		_row(col2, Loc.t(&"ctrl.tasks"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"tasks"))
		_row(col2, Loc.t(&"ctrl.map"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"map"))
		_row(col2, Loc.t(&"ctrl.code"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"codebook"))
		_row(col2, Loc.t(&"ctrl.icp"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"intercepts"))
		_row(col2, Loc.t(&"ctrl.pause"), Loc.p("Кнопка (Menu / Start)", "Button (Menu / Start)"))
	else:
		_row(col2, Loc.t(&"ctrl.tasks"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"tasks"))
		_row(col2, Loc.t(&"ctrl.map"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"map"))
		_row(col2, Loc.t(&"ctrl.code"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"codebook"))
		_row(col2, Loc.t(&"ctrl.icp"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"intercepts"))
		_row(col2, Loc.t(&"ctrl.pause"), Loc.p("Клавиша [Esc]", "Key [Esc]"))

	# Колонка 3: Выживание в тайге
	var col3 := VBoxContainer.new()
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3.add_theme_constant_override("separation", 8)
	_layout_box.add_child(col3)

	var h3 := UiKit.ink(UiKit.label(Loc.t(&"ctrl.group_survival"), 15))
	h3.add_theme_color_override("font_color", Color(0.55, 0.22, 0.12))
	col3.add_child(h3)

	if _is_joy:
		_row(col3, Loc.t(&"ctrl.sprint"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"sprint"))
		_row(col3, Loc.t(&"ctrl.breath"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"hold_breath"))
		_row(col3, Loc.t(&"ctrl.flare"), Loc.p("Кнопка (%s)", "Button (%s)") % Game.pad_name(&"flare"))
		if Game.has_item(&"zenit"):
			_row(col3, Loc.t(&"ctrl.photo"), Loc.p("Держать %s, кадр — %s", "Hold %s, shoot — %s") % [Game.pad_name(&"photo"), Game.pad_name(&"photo_shoot")])
		if Net.role != "":
			_row(col3, Loc.t(&"key.coop_phrase"), Loc.p("%s, затем ↑ → ↓ ← / X / Y", "%s, then ↑ → ↓ ← / X / Y") % Game.pad_name(&"coop_phrase"))
	else:
		_row(col3, Loc.t(&"ctrl.sprint"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"sprint"))
		_row(col3, Loc.t(&"ctrl.breath"), Loc.p("Клавиша [%s]", "Key [%s]") % _k(&"hold_breath"))
		_row(col3, Loc.t(&"ctrl.flare"), Loc.p("Правая кнопка мыши / [%s]", "Right mouse button / [%s]") % _k(&"flare"))
		if Game.has_item(&"zenit"):
			_row(col3, Loc.t(&"ctrl.photo"), Loc.p("Держать [%s], кадр — ЛКМ", "Hold [%s], shoot — LMB") % _k(&"photo"))


static func _k(action: StringName) -> String:
	return OS.get_keycode_string(Game.key_of(action) as Key)


func _row(parent: Control, action_title: String, key_desc: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	parent.add_child(v)

	var lbl_act := UiKit.ink(UiKit.label(action_title, 13))
	v.add_child(lbl_act)

	var lbl_key := UiKit.ink(UiKit.label("  → " + key_desc, 13))
	lbl_key.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18))
	v.add_child(lbl_key)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close()


func handle_input(event: InputEvent) -> void:
	_unhandled_input(event)


func _close() -> void:
	closed.emit()
