class_name UiKit
extends RefCounted
## Общий стиль интерфейса: машинописный шрифт (PT Mono, assets/fonts), «бумага» для записок и тёмные
## панели приборов. Панель цвета PAPER — настоящий лист (UiStyle.paper) со своей темой: чернила вместо
## обводки, кнопки — рамкой ручкой, поля ввода — строкой, в которую пишут от руки.

const PAPER := Color(0.86, 0.82, 0.7, 0.97)
const INK := Color(0.12, 0.1, 0.12)
const DARK := Color(0.05, 0.06, 0.05, 0.88)
const AMBER := Color(1.0, 0.68, 0.28)
const TEXT := Color(0.92, 0.9, 0.85)

static var _theme: Theme
static var _paper_theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = UiStyle.type_font()   # свой шрифт в игре: у игроков без Consolas всё выглядит так же
	th.default_font_size = 18
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.72))
	th.set_constant("outline_size", "Label", 2)
	th.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.42))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)

	var normal := _box(Color(0.05, 0.07, 0.075, 0.90), Color(0.24, 0.30, 0.28))
	var hover := _box(Color(0.14, 0.12, 0.09, 0.96), AMBER)
	var pressed := _box(Color(0.22, 0.16, 0.08, 0.98), AMBER)
	for state: String in ["normal", "focus"]:
		th.set_stylebox(state, "Button", normal if state == "normal" else hover)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", AMBER)
	th.set_color("font_focus_color", "Button", AMBER)
	th.set_font_size("font_size", "Button", 18)
	th.set_stylebox("normal", "LineEdit", _box(Color(0.95, 0.92, 0.82), INK))
	th.set_stylebox("focus", "LineEdit", _box(Color(1.0, 0.97, 0.88), AMBER))
	th.set_color("font_color", "LineEdit", INK)
	th.set_font_size("font_size", "LineEdit", 22)
	th.set_stylebox("panel", "ItemList", _box(Color(0.045, 0.06, 0.065, 0.94), Color(0.24, 0.30, 0.28)))
	th.set_color("font_color", "ItemList", TEXT)
	th.set_color("font_selected_color", "ItemList", AMBER)
	_theme = th
	return th


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size := 18, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Надпись «чернилами» на бумаге — без обводки и тени.
static func ink(l: Label) -> Label:
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


## Тема для всего, что лежит на бумаге.
static func paper_theme() -> Theme:
	if _paper_theme != null:
		return _paper_theme
	var th := Theme.new()
	th.default_font = UiStyle.type_font()
	th.default_font_size = 18
	th.set_color("font_color", "Label", INK)
	th.set_constant("outline_size", "Label", 0)
	th.set_constant("shadow_offset_x", "Label", 0)
	th.set_constant("shadow_offset_y", "Label", 0)
	for st: Array in [["normal", 0.0], ["focus", 0.06], ["hover", 0.1], ["pressed", 0.18]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UiStyle.INK_PEN, float(st[1]))
		sb.border_color = Color(UiStyle.INK_PEN, 0.7)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		th.set_stylebox(st[0], "Button", sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", UiStyle.INK_PEN)
	th.set_constant("outline_size", "Button", 0)
	th.set_font_size("font_size", "Button", 18)
	# Поле ввода — строка на бумаге, пишут ручкой
	for st in ["normal", "focus", "read_only"]:
		var le := StyleBoxFlat.new()
		le.bg_color = Color(1.0, 0.97, 0.86, 0.35 if st == "focus" else 0.0)
		le.border_color = Color(UiStyle.INK_PRINT, 0.8)
		le.border_width_bottom = 2
		le.content_margin_left = 6
		le.content_margin_right = 6
		le.content_margin_top = 0
		le.content_margin_bottom = 2
		th.set_stylebox(st, "LineEdit", le)
	th.set_font("font", "LineEdit", UiStyle.hand_font())
	th.set_font_size("font_size", "LineEdit", 32)
	th.set_color("font_color", "LineEdit", UiStyle.INK_PEN)
	th.set_color("caret_color", "LineEdit", UiStyle.INK_PEN)
	th.set_color("font_placeholder_color", "LineEdit", Color(UiStyle.PENCIL, 0.5))
	th.set_color("font_color", "ItemList", INK)
	th.set_color("font_selected_color", "ItemList", UiStyle.INK_PEN)
	_paper_theme = th
	return th


static func panel(color := DARK) -> PanelContainer:
	var p := PanelContainer.new()
	if color == PAPER:
		# Лист: шейдер под содержимым на всю панель (контейнер растягивает детей по полю — поправляем после)
		var sbp := StyleBoxEmpty.new()
		sbp.content_margin_left = 26
		sbp.content_margin_right = 22
		sbp.content_margin_top = 18
		sbp.content_margin_bottom = 16
		p.add_theme_stylebox_override("panel", sbp)
		p.theme = paper_theme()
		var sheet := UiStyle.paper(p, randf() * 9.0)
		sheet.set_anchors_preset(Control.PRESET_TOP_LEFT)
		p.sort_children.connect(func() -> void:
			sheet.position = Vector2.ZERO
			sheet.size = p.size)
		return p
	if color == DARK:
		var tex := GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(0.16, 0.13, 0.11, 0.97))
		g.set_color(1, Color(0.06, 0.05, 0.045, 0.97))
		tex.gradient = g
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 8
		tex.height = 64
		var st := StyleBoxTexture.new()
		st.texture = tex
		st.content_margin_left = 18
		st.content_margin_right = 18
		st.content_margin_top = 14
		st.content_margin_bottom = 14
		p.add_theme_stylebox_override("panel", st)
		var edge := Panel.new()   # латунная кромка и тень поверх градиента
		var eb := StyleBoxFlat.new()
		eb.draw_center = false
		eb.border_color = Color(0.42, 0.34, 0.22)
		eb.set_border_width_all(2)
		eb.set_corner_radius_all(3)
		eb.shadow_color = Color(0, 0, 0, 0.5)
		eb.shadow_size = 6
		edge.add_theme_stylebox_override("panel", eb)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.show_behind_parent = true
		p.add_child(edge)
		p.sort_children.connect(func() -> void:
			edge.position = Vector2.ZERO
			edge.size = p.size)
		return p
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


static var _tick_player: AudioStreamPlayer
static var _tick_stream: AudioStream = preload("res://assets/audio/ui_tick.ogg")


static func play_tick(vol_db := -8.0, pitch := 1.0) -> void:
	if _tick_stream == null:
		return
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop == null or main_loop.root == null:
		return
	if _tick_player == null or not is_instance_valid(_tick_player):
		_tick_player = AudioStreamPlayer.new()
		_tick_player.stream = _tick_stream
		_tick_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	if not _tick_player.is_inside_tree():
		if _tick_player.get_parent() == null:
			main_loop.root.add_child.call_deferred(_tick_player)
		return
	_tick_player.volume_db = vol_db
	_tick_player.pitch_scale = pitch * randf_range(0.97, 1.03)
	_tick_player.play()


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		play_tick(-6.0, 1.0)
		on_press.call()
	)
	b.mouse_entered.connect(func() -> void:
		if b.is_inside_tree():
			play_tick(-14.0, 1.35)
	)
	b.focus_entered.connect(func() -> void:
		if b.is_inside_tree():
			play_tick(-14.0, 1.35)
	)
	return b


## Ставит контрол в родителя с якорями (доли) и отступами (пиксели).
static func place(parent: Control, c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	parent.add_child(c)
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob
