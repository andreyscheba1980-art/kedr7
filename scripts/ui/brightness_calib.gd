class_name BrightnessCalib
extends Control
## Калибровка яркости при первом запуске: ель слева должна быть едва видна, справа — не видна совсем.
## Рисуем через тот же пост-шейдер, что и игру (зерно, холодные тени), — иначе калибровка врала бы.

signal done

const POST_SHADER := "res://assets/shaders/ps1_post.gdshader"


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)

	var cont := SubViewportContainer.new()
	cont.stretch = true
	var post := ShaderMaterial.new()
	post.shader = load(POST_SHADER)
	cont.material = post
	UiKit.place(self, cont, 0, 0, 1, 1, 0, 0, 0, 0)   # весь экран через пост-шейдер — без рамки вокруг ёлок
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	cont.add_child(vp)
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.draw.connect(func() -> void:
		art.draw_rect(Rect2(Vector2.ZERO, art.size), Color.BLACK)
		_pine(art, Vector2(art.size.x * 0.38, art.size.y * 0.43), Color(0.075, 0.075, 0.08))   # едва видна
		_pine(art, Vector2(art.size.x * 0.62, art.size.y * 0.43), Color(0.022, 0.022, 0.025))  # не видна
	)
	vp.add_child(art)

	var title := UiKit.label(Loc.t(&"calib.title"), 26, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", UiKit.AMBER)
	UiKit.place(self, title, 0.5, 0.5, 0.5, 0.5, -400, -300, 400, -250)
	var hint := UiKit.label(Loc.t(&"calib.hint"), 17, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(self, hint, 0.5, 0.5, 0.5, 0.5, -420, 85, 420, 150)

	var s := HSlider.new()
	s.min_value = 0.7
	s.max_value = 1.5
	s.step = 0.02
	s.value = Settings.brightness
	s.value_changed.connect(func(v: float) -> void:
		Settings.brightness = v
		Settings.apply())
	UiKit.place(self, s, 0.5, 0.5, 0.5, 0.5, -260, 160, 260, 190)
	var ok := UiKit.button(Loc.t(&"calib.done"), func() -> void:
		Settings.calibrated = true
		Settings.save()
		done.emit())
	UiKit.place(self, ok, 0.5, 0.5, 0.5, 0.5, -120, 215, 120, 265)
	s.grab_focus.call_deferred()


static func _pine(c: Control, at: Vector2, col: Color) -> void:
	for k in range(4):
		var w := 46.0 + k * 22.0
		var top := at + Vector2(0, -120 + k * 52)
		c.draw_colored_polygon(PackedVector2Array([top, top + Vector2(w * 0.5, 70), top + Vector2(-w * 0.5, 70)]), col)
	c.draw_rect(Rect2(at + Vector2(-8, 86), Vector2(16, 34)), col)
