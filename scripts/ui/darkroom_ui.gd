class_name DarkroomUI
extends Control
## Утро после ночи: проявка плёнки «Зенита» под красным фонарём. Отпечатки проступают по одному.
## Подписи — что попало в кадр: аномалия (в журнал, доказательством), тот, кто звал из леса,
## или то, чего в кадре не было. В коопе — и плёнка напарника.

signal closed

const PRINT_SHADER := """shader_type canvas_item;
uniform float seed = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float n = fract(sin(dot(UV * vec2(311.7, 183.3) + seed, vec2(12.9898, 78.233))) * 43758.5453);
	// Плёнка мягко сжимает света и вытягивает тени: снег не белое пятно, ночь не сплошная чернота.
	g = (1.0 - exp(-1.9 * g)) / (1.0 - exp(-1.9));
	g = clamp(g + (n - 0.5) * 0.09, 0.0, 1.0);
	float v = 1.0 - length(UV - 0.5) * 0.55;
	COLOR = vec4(vec3(g * v) * vec3(1.0, 0.92, 0.8), c.a * COLOR.a);
}
"""
const CELL := Vector2(232, 130)

var _shader: Shader
var _n := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shader = Shader.new()
	_shader.code = PRINT_SHADER
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.015, 0.01, 1.0)
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)
	var lamp := ColorRect.new()   # красный фонарь сверху: пятно света
	lamp.color = Color(0.7, 0.05, 0.03, 0.12)
	UiKit.place(self, lamp, 0.2, 0.0, 0.8, 0.35, 0, 0, 0, 0)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	UiKit.place(self, root, 0.5, 0.5, 0.5, 0.5, -540, -330, 540, 330)
	var title := UiKit.label(Loc.t(&"zenit.dr_title", [Game.night]), 22)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45))
	root.add_child(title)
	var sub := UiKit.label(Loc.t(&"zenit.dr_sub"), 13)
	sub.add_theme_color_override(&"font_color", Color(0.85, 0.45, 0.4))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var z := Game.zenit
	_film(list, z.photos, "")
	if not z.partner_photos.is_empty():
		_film(list, z.partner_photos, Loc.t(&"zenit.dr_partner"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(row)
	var btn := UiKit.button(Loc.t(&"zenit.dr_done"), func() -> void: closed.emit())
	row.add_child(btn)
	btn.grab_focus.call_deferred()


func _film(list: VBoxContainer, shots: Array[Dictionary], head: String) -> void:
	if head != "":
		var h := UiKit.label(head, 15)
		h.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.5))
		list.add_child(h)
	if shots.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for i in shots.size():
		var ph: Dictionary = shots[i]
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(CELL.x, 0)
		cell.add_theme_constant_override("separation", 3)
		grid.add_child(cell)
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.9, 0.86, 0.78)
		sb.set_content_margin_all(5)
		frame.add_theme_stylebox_override(&"panel", sb)
		cell.add_child(frame)
		var tr := TextureRect.new()
		tr.custom_minimum_size = CELL
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var img: Image = ph.get("img")
		if img != null and not img.is_empty():
			tr.texture = ImageTexture.create_from_image(img)
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter(&"seed", float(i) * 1.37)
		tr.material = mat
		frame.add_child(tr)
		var cap := UiKit.label(_caption(ph), 12)
		cap.add_theme_color_override(&"font_color", Color(0.95, 0.7, 0.62) if not ph["ghost"] else Color(1.0, 0.42, 0.36))
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size = Vector2(CELL.x, 0)
		cell.add_child(cap)
		# Проявляется: сначала белая бумага, потом проступает изображение.
		frame.modulate = Color(1, 1, 1, 0)
		tr.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_interval(0.25 + _n * 0.35)
		tw.tween_property(frame, "modulate:a", 1.0, 0.3)
		tw.tween_property(tr, "modulate:a", 1.0, 1.4)
		_n += 1


func _caption(ph: Dictionary) -> String:
	var t := Game.minutes_to_clock(int(ph.get("min", 0))) + " — "
	var img: Image = ph.get("img")
	if ph.get("voice", false):
		return t + Loc.t(&"zenit.cap_voice")
	var parts := PackedStringArray()
	for id in ph.get("tags", []):
		parts.append(Loc.t(StringName("anom." + String(id))))
	if ph.get("ghost", false):
		parts.append(Loc.t(&"zenit.cap_ghost"))
	if parts.is_empty():
		return t + (Loc.t(&"zenit.cap_empty") if img != null else Loc.t(&"zenit.cap_fogged"))
	return t + "; ".join(parts)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return true
	return false
