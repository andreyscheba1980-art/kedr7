class_name UiKit
extends RefCounted
## Общий стиль интерфейса: моноширинный шрифт, «бумага» для записок и тёмные панели приборов.

const PAPER := Color(0.86, 0.82, 0.7, 0.97)
const INK := Color(0.12, 0.1, 0.12)
const DARK := Color(0.05, 0.06, 0.05, 0.88)
const AMBER := Color(1.0, 0.68, 0.28)
const TEXT := Color(0.92, 0.9, 0.85)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 18
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	th.set_constant("shadow_offset_x", "Label", 2)
	th.set_constant("shadow_offset_y", "Label", 2)

	var normal := _box(Color(0.08, 0.09, 0.08, 0.85), Color(0.35, 0.33, 0.28))
	var hover := _box(Color(0.16, 0.14, 0.1, 0.95), AMBER)
	var pressed := _box(Color(0.25, 0.18, 0.08, 0.95), AMBER)
	for state: String in ["normal", "focus"]:
		th.set_stylebox(state, "Button", normal if state == "normal" else hover)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", AMBER)
	th.set_color("font_focus_color", "Button", AMBER)
	th.set_font_size("font_size", "Button", 20)
	th.set_stylebox("normal", "LineEdit", _box(Color(0.95, 0.92, 0.82), INK))
	th.set_stylebox("focus", "LineEdit", _box(Color(1.0, 0.97, 0.88), AMBER))
	th.set_color("font_color", "LineEdit", INK)
	th.set_font_size("font_size", "LineEdit", 22)
	th.set_stylebox("panel", "ItemList", _box(Color(0.06, 0.07, 0.06, 0.9), Color(0.35, 0.33, 0.28)))
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


static func panel(color := DARK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
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
