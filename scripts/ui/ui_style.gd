class_name UiStyle
extends RefCounted
## Единый язык экранов станции: «бумага и бакелит», 1983 год.
## Три шрифта (OFL, assets/fonts): машинка (PT Mono) — бланки и журналы; шильдик (PT Sans Narrow) —
## таблички, шкалы, штампы; почерк (Caveat) — то, что вписывает дежурный. Бумага — шейдером
## (волокна, зерно, пятна, рваный край), штамп — кнопка с непрокрасом.

const INK_PEN := Color(0.12, 0.18, 0.46)        ## шариковая ручка
const INK_TYPE := Color(0.13, 0.12, 0.11)       ## машинописная лента
const INK_PRINT := Color(0.28, 0.33, 0.45)      ## типографская сетка бланка
const INK_STAMP := Color(0.42, 0.18, 0.55)      ## штемпельная краска
const INK_RED := Color(0.62, 0.12, 0.10)
const PENCIL := Color(0.35, 0.34, 0.33)
const PAPER := Color(0.91, 0.88, 0.79)
const BRASS := Color(0.62, 0.5, 0.27)

const PAPER_SHADER := """
shader_type canvas_item;
uniform vec4 base : source_color = vec4(0.91, 0.88, 0.79, 1.0);
uniform vec2 px_size = vec2(400.0, 500.0);
uniform float seed = 1.0;
uniform float stains = 1.0;
uniform float ragged = 1.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), u.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * n(p); p *= 2.03; a *= 0.5; } return v; }

void fragment() {
	vec2 p = UV * px_size;
	vec2 s = vec2(seed * 17.3, seed * 9.1);
	float mottle = fbm(p * 0.012 + s);
	float fibres = n(vec2(p.x * 0.9, p.y * 0.035) + s * 3.0) * n(vec2(p.x * 0.05, p.y * 0.8) + s);
	float grain = h(floor(p * 0.75) + s);
	vec3 col = base.rgb * (0.92 + 0.08 * mottle) + (fibres - 0.25) * 0.035 - (grain - 0.5) * 0.04;
	// пятно от кружки и пара мелких — кольцом, чай подсох по краю
	float m = min(px_size.x, px_size.y);
	vec2 c1 = vec2(0.82, 0.16) + vec2(h(s) - 0.5, h(s + 3.0) - 0.5) * 0.08;
	float d1 = length((UV - c1) * px_size) / m;
	float ring = smoothstep(0.135, 0.125, d1) * smoothstep(0.095, 0.13, d1) * (0.6 + 0.4 * n(p * 0.08));
	float blot = smoothstep(0.05, 0.0, length((UV - vec2(0.12 + h(s + 7.0) * 0.2, 0.86)) * px_size) / m - fbm(p * 0.05) * 0.03);
	col = mix(col, col * vec3(0.86, 0.78, 0.62), clamp(ring * 0.8 + blot * 0.35, 0.0, 1.0) * stains);
	// края темнее и рваные
	float ed = min(min(UV.x, 1.0 - UV.x) * px_size.x, min(UV.y, 1.0 - UV.y) * px_size.y);
	col *= mix(0.80, 1.0, smoothstep(0.0, 18.0, ed));
	float rag = n(vec2(UV.x * px_size.x + UV.y * px_size.y) * 0.18 + s) * 3.0 * ragged;
	COLOR = vec4(col, smoothstep(0.0, 1.5, ed - rag));
}
"""

static var _fonts: Dictionary = {}
static var _paper_shader: Shader


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


## Машинка: бланки, журналы, подписи приборов.
static func type_font() -> Font:
	return _font("res://assets/fonts/pt_mono.ttf")


## Шильдик: таблички, цифры шкал, штампы.
static func plate_font(bold := true) -> Font:
	return _font("res://assets/fonts/pt_sans_narrow_bold.ttf" if bold else "res://assets/fonts/pt_sans_narrow.ttf")


## Почерк дежурного (ручкой, с нажимом).
static func hand_font() -> Font:
	if not _fonts.has("hand"):
		var v := FontVariation.new()
		v.base_font = _font("res://assets/fonts/caveat.ttf")
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 620}
		_fonts["hand"] = v
	return _fonts["hand"]


## Лист бумаги: ColorRect с шейдером (размер в пикселях — для волокон и края).
static func paper(parent: Control, seed := 1.0, base := PAPER, stains := 1.0) -> ColorRect:
	if _paper_shader == null:
		_paper_shader = Shader.new()
		_paper_shader.code = PAPER_SHADER
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _paper_shader
	m.set_shader_parameter(&"base", base)
	m.set_shader_parameter(&"seed", seed)
	m.set_shader_parameter(&"stains", stains)
	r.material = m
	parent.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.resized.connect(func() -> void: m.set_shader_parameter(&"px_size", r.size))
	return r


## Кнопка-штамп: рамка штемпельной краской, чуть набок.
static func stamp_button(text: String, on_press: Callable, ink := INK_STAMP) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		UiKit.play_tick(-6.0, 1.0)
		on_press.call()
	)
	b.add_theme_font_override("font", plate_font())
	b.add_theme_font_size_override("font_size", 24)
	for st: Array in [["normal", 0.0], ["hover", 0.10], ["pressed", 0.2], ["focus", 0.08]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAPER.lerp(ink, float(st[1]) * 2.0)   # бумажный ярлычок: штамп читается и на снегу
		sb.border_color = UiKit.AMBER if st[0] == "focus" else Color(ink, 0.85)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(st[0], sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(ink, 0.92))
	b.add_theme_constant_override("outline_size", 0)
	b.rotation_degrees = -1.6
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	return b


## Кнопка-надпись: машинописью, без рамки.
static func text_button(text: String, on_press: Callable, color := Color(0.82, 0.78, 0.68)) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		UiKit.play_tick(-6.0, 1.05)
		on_press.call()
	)
	b.add_theme_font_override("font", type_font())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(color, 0.75))
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_focus_color", UiKit.AMBER)
	b.add_theme_color_override("font_pressed_color", color)
	b.add_theme_constant_override("outline_size", 0)
	return b


## Латунный шильдик с гравировкой: заголовок прибора.
static func brass_plate(text: String, size := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BRASS
	sb.border_color = BRASS.darkened(0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(1, 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", plate_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.18, 0.13, 0.06))
	l.add_theme_color_override("font_shadow_color", Color(1, 0.92, 0.7, 0.45))   # гравировка: светлая кромка снизу
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


## Подсказка по клавишам — машинописью, приглушённо.
static func hint(text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", type_font())
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.78, 0.74, 0.64, 0.7))
	l.add_theme_constant_override("outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Вертикальный градиент прямоугольником (для стекла, бакелита, планок).
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func hgrad(ci: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([left, right, right, left]))


## Бакелитовая панель прибора: тёмный градиент, кромка, винты по углам.
static func bakelite(ci: CanvasItem, r: Rect2) -> void:
	vgrad(ci, r, Color(0.17, 0.14, 0.12), Color(0.07, 0.06, 0.05))
	ci.draw_rect(r, Color(0.32, 0.27, 0.22), false, 2.0)
	ci.draw_rect(r.grow(-6), Color(0, 0, 0, 0.5), false, 1.0)
	for c: Vector2 in [r.position + Vector2(14, 14), Vector2(r.end.x - 14, r.position.y + 14), r.end - Vector2(14, 14), Vector2(r.position.x + 14, r.end.y - 14)]:
		ci.draw_circle(c, 5.0, Color(0.55, 0.52, 0.46))
		ci.draw_line(c - Vector2(3.5, 1.5), c + Vector2(3.5, 1.5), Color(0.2, 0.18, 0.16), 1.5)


## Круглая шкала: хромированный ободок, кремовая шкала с затемнением к краю.
static func dial_face(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(3, 5), r + 16, Color(0, 0, 0, 0.45))
	for i in 8:
		var k := float(i) / 7.0
		ci.draw_arc(c, r + 13 - i * 1.6, 0.0, TAU, 72, Color(0.75, 0.74, 0.7).lerp(Color(0.3, 0.3, 0.3), absf(k - 0.35) * 1.4), 2.0, true)
	ci.draw_circle(c, r, Color(0.87, 0.84, 0.75))
	for i in 6:
		ci.draw_arc(c, r - i * 2.0, 0.0, TAU, 72, Color(0.55, 0.5, 0.4, 0.06 * (6 - i)), 2.0, true)


## Стекло поверх шкалы: блик дугой сверху-слева.
static func dial_glass(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r * 0.86, deg_to_rad(200.0), deg_to_rad(250.0), 24, Color(1, 1, 1, 0.22), r * 0.08, true)
	ci.draw_arc(c, r * 0.70, deg_to_rad(205.0), deg_to_rad(232.0), 16, Color(1, 1, 1, 0.12), r * 0.04, true)


const PAPER_MUL_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
uniform vec2 px_size = vec2(400.0, 500.0);
uniform float seed = 1.0;
uniform float stains = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), u.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec2 p = UV * px_size;
	vec2 s = vec2(seed * 17.3, seed * 9.1);
	float mottle = fbm(p * 0.012 + s);
	float fibres = n(vec2(p.x * 0.9, p.y * 0.035) + s * 3.0) * n(vec2(p.x * 0.05, p.y * 0.8) + s);
	float grain = h(floor(p * 0.75) + s);
	vec3 m = vec3(0.93 + 0.07 * mottle + (fibres - 0.25) * 0.04 - (grain - 0.5) * 0.05);
	float mn = min(px_size.x, px_size.y);
	float blot = smoothstep(0.06, 0.0, length((UV - vec2(0.15 + h(s + 7.0) * 0.6, 0.8)) * px_size) / mn - fbm(p * 0.05) * 0.03);
	m = mix(m, m * vec3(0.9, 0.82, 0.68), blot * 0.4 * stains);
	float ed = min(min(UV.x, 1.0 - UV.x) * px_size.x, min(UV.y, 1.0 - UV.y) * px_size.y);
	m *= mix(0.84, 1.0, smoothstep(0.0, 22.0, ed));
	COLOR = vec4(m, 1.0);
}
"""
static var _paper_mul_shader: Shader


## Фактура бумаги поверх уже нарисованного (умножением): текст и штампы остаются, лист — живой.
static func paper_mul(parent: Control, rect: Rect2, seed := 1.0, stains := 1.0) -> ColorRect:
	if _paper_mul_shader == null:
		_paper_mul_shader = Shader.new()
		_paper_mul_shader.code = PAPER_MUL_SHADER
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _paper_mul_shader
	m.set_shader_parameter(&"seed", seed)
	m.set_shader_parameter(&"stains", stains)
	m.set_shader_parameter(&"px_size", rect.size)
	r.material = m
	r.position = rect.position
	r.size = rect.size
	parent.add_child(r)
	return r
