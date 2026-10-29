class_name InstrumentView
extends Control
## Крупный кадр прибора на улице. Сам прибор рисует владелец (draw_fn); здесь — общее для всех:
## курсор и пятно фонаря, темнота ночью, иней (стирается рукавицей — ЛКМ или правый курок),
## прокрутка вдоль шкалы (колёсико, W/S, правый стик) — scroll_fn получает «щелчки колёсика».

const FROST_W := 60
const FROST_H := 54
const WIPE_SFX := "res://assets/audio/step_snow_1.ogg"
const DARK_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(600.0, 540.0);
uniform vec2 spot = vec2(300.0, 270.0);
uniform float radius = 150.0;
uniform float dark = 0.95;
uniform float lit = 1.0;
void fragment() {
	float d = distance(UV * rect_size, spot);
	float a = lit > 0.5 ? smoothstep(radius * 0.5, radius, d) : 1.0;
	COLOR = vec4(0.0, 0.004, 0.012, a * dark);
}
"""

var draw_fn: Callable
var scroll_fn: Callable
var cursor := Vector2(300, 270)
var needs_light := false
var mouse_wipe := false
## Где на кадре стекло: полосы [x0, x1] в долях ширины — иней только там (пусто — везде)
var frost_bands: Array = []
var _frost_img: Image
var _frost_tex: ImageTexture
var _frost_dirty := false
var _dark_mat: ShaderMaterial
var _wipe_snd := 0.0


## frost_amount: 0 — чисто, 1 — всё в инее.
func setup(p_draw: Callable, p_scroll: Callable, frost_amount: float, bands: Array = []) -> void:
	frost_bands = bands
	draw_fn = p_draw
	scroll_fn = p_scroll
	needs_light = not Game.is_daylight()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	draw.connect(func() -> void: draw_fn.call())
	gui_input.connect(_input_mouse)

	_frost_img = Image.create(FROST_W, FROST_H, false, Image.FORMAT_RGBA8)
	_make_frost(frost_amount)
	_frost_tex = ImageTexture.create_from_image(_frost_img)
	var frost := TextureRect.new()
	frost.texture = _frost_tex
	frost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frost.stretch_mode = TextureRect.STRETCH_SCALE
	frost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frost)
	frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dark := ColorRect.new()
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DARK_SHADER
	_dark_mat = ShaderMaterial.new()
	_dark_mat.shader = sh
	dark.material = _dark_mat
	dark.visible = needs_light
	add_child(dark)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Рама: косяк дверцы прибора — дерево с тенью внутрь
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.draw.connect(func() -> void:
		var s := frame.size
		var wood := Color(0.24, 0.2, 0.16)
		for r: Rect2 in [Rect2(0, 0, s.x, 12), Rect2(0, s.y - 12, s.x, 12), Rect2(0, 0, 12, s.y), Rect2(s.x - 12, 0, 12, s.y)]:
			frame.draw_rect(r, wood)
		UiStyle.vgrad(frame, Rect2(12, 12, s.x - 24, 18), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
		UiStyle.hgrad(frame, Rect2(12, 12, 14, s.y - 24), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
		frame.draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), Color(0.45, 0.38, 0.3), false, 1.0)
		frame.draw_rect(Rect2(Vector2(12, 12), s - Vector2(24, 24)), Color(0.08, 0.06, 0.05), false, 2.0))


## Мороз сильнее −20 и метель — инея больше.
static func frost_for_weather(temp: float) -> float:
	return clampf(0.55 + (-temp - 20.0) / 40.0 + (Game.weather.intensity * 0.3 if Game.weather != null else 0.0), 0.45, 1.0)


func _make_frost(amount: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.07
	var grain := FastNoiseLite.new()
	grain.seed = randi()
	grain.frequency = 0.6
	for y in FROST_H:
		for x in FROST_W:
			var a := 0.0
			if amount > 0.0:
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var g := grain.get_noise_2d(x, y) * 0.5 + 0.5
				a = clampf((n - 0.55 + amount * 0.45) * 3.4, 0.0, 1.0) * (0.55 + g * 0.3)
				if not frost_bands.is_empty():
					var u := (float(x) + 0.5) / FROST_W
					var inside := 0.0
					for b: Array in frost_bands:
						inside = maxf(inside, clampf(minf(u - float(b[0]), float(b[1]) - u) * FROST_W * 0.7, 0.0, 1.0))
					a *= inside
			_frost_img.set_pixel(x, y, Color(0.84, 0.88, 0.93, a))   # иней на стекле, в луче фонаря не выжигается


func lit() -> bool:
	return Game.player != null and Game.player.flashlight != null and Game.player.flashlight.visible


## Видно ли шкалу вообще (днём — да; ночью — только с фонарём).
func can_see() -> bool:
	return not needs_light or lit()


func _process(delta: float) -> void:
	# W/S и правый стик: стрелки заняты книжкой, левый стик — курсором
	var dy := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var ry := -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(ry) > 0.2:
		dy += ry
	if absf(dy) > 0.01 and scroll_fn.is_valid():
		scroll_fn.call(dy * 15.0 * delta)
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		cursor = (cursor + stick * 520.0 * delta).clamp(Vector2.ZERO, size)
	if mouse_wipe or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		_wipe(delta)
	if _frost_dirty:
		_frost_dirty = false
		_frost_tex.update(_frost_img)
	if needs_light:
		var on := lit()
		_dark_mat.set_shader_parameter(&"rect_size", size)
		_dark_mat.set_shader_parameter(&"spot", cursor)
		_dark_mat.set_shader_parameter(&"lit", 1.0 if on else 0.0)
		_dark_mat.set_shader_parameter(&"dark", 0.94 if on else 0.985)
	queue_redraw()


func _wipe(delta: float) -> void:
	var cell := Vector2(cursor.x / size.x * FROST_W, cursor.y / size.y * FROST_H)
	var r := 3.2
	for y in range(maxi(0, int(cell.y - r)), mini(FROST_H, int(cell.y + r) + 1)):
		for x in range(maxi(0, int(cell.x - r)), mini(FROST_W, int(cell.x + r) + 1)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(cell)
			if d > r:
				continue
			var c := _frost_img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			c.a = maxf(0.0, c.a - delta * 3.5 * (1.0 - d / r))
			_frost_img.set_pixel(x, y, c)
			_frost_dirty = true
	_wipe_snd -= delta
	if _frost_dirty and _wipe_snd <= 0.0:
		_wipe_snd = 0.32
		Game.audio.play_2d(WIPE_SFX, -20.0, 0.25)


func _input_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		cursor = mb.position
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed and scroll_fn.is_valid():
					scroll_fn.call(1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed and scroll_fn.is_valid():
					scroll_fn.call(-1.0)
			MOUSE_BUTTON_LEFT:
				mouse_wipe = mb.pressed
