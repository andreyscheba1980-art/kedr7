class_name TheodoliteUI
extends Control
## Оптический окуляр метеорологического теодолита АШТ / ПТ-1.
## Наведение на шар-пилот, снятие углов азимута и высоты, ночной перехват шара тайгой.

signal closed

const RETICLE_TEX := "res://assets/textures/tex_theodolite_reticle.png"
const FROST_TEX := "res://assets/textures/frost_vignette.png"

var _reticle_rect: TextureRect
var _frost_rect: TextureRect
var _balloon_dot: ColorRect
var _azimuth_label: Label
var _elevation_label: Label
var _tracking_bar: ProgressBar
var _hint_label: Label

var _azimuth := 42.5
var _elevation := 28.0
var _target_azimuth := 45.0
var _target_elevation := 30.0
var _tracking_progress := 0.0
var _anomaly_triggered := false
var _anomaly_t := 0.0
var _no_balloon := false
# Жердяй у кромки леса: раз за ночь попадает в окуляр, пока ведёшь шар; навёл перекрестие — его нет
var _zh: Control
var _zh_az := 0.0
var _zh_t := 0.0
var _zh_on_cross := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_no_balloon = not Game.balloon_launched

	# Темный виньетированный фон окуляра
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.05, 0.96)
	UiKit.place(self, bg, 0, 0, 1, 1, 0, 0, 0, 0)

	# Светящаяся точка шара-пилота в окуляре
	_balloon_dot = ColorRect.new()
	_balloon_dot.custom_minimum_size = Vector2(8, 8)
	_balloon_dot.color = Color(1.0, 0.85, 0.45)
	add_child(_balloon_dot)

	# Сетка окуляра по центру экрана
	_reticle_rect = TextureRect.new()
	_reticle_rect.texture = load(RETICLE_TEX)
	_reticle_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reticle_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UiKit.place(self, _reticle_rect, 0.5, 0.5, 0.5, 0.5, -340, -340, 340, 340)

	# Морозная виньетка при аномалии
	_frost_rect = TextureRect.new()
	_frost_rect.texture = load(FROST_TEX)
	_frost_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frost_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_frost_rect.modulate.a = 0.0
	UiKit.place(self, _frost_rect, 0, 0, 1, 1, 0, 0, 0, 0)

	# Интерфейс показаний углов (лимбы)
	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 6)
	UiKit.place(self, hud_box, 0.05, 0.05, 0.4, 0.2, 0, 0, 0, 0)

	var title := UiStyle.brass_plate(Loc.t(&"theodolite.title"), 17)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hud_box.add_child(title)

	_azimuth_label = UiKit.label("", 14)
	hud_box.add_child(_azimuth_label)

	_elevation_label = UiKit.label("", 14)
	hud_box.add_child(_elevation_label)

	var tr_box := HBoxContainer.new()
	tr_box.add_theme_constant_override("separation", 10)
	hud_box.add_child(tr_box)

	var tr_lbl := UiKit.label(Loc.t(&"theodolite.tracking"), 13)
	tr_box.add_child(tr_lbl)

	_tracking_bar = ProgressBar.new()
	_tracking_bar.custom_minimum_size = Vector2(160, 16)
	_tracking_bar.max_value = 100.0
	tr_box.add_child(_tracking_bar)

	_hint_label = UiKit.label(Loc.t(&"theodolite.controls_hint"), 12)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hud_box.add_child(_hint_label)

	# Начальные координаты цели (шар-пилот поднимается под ветром)
	_target_azimuth = 45.0 + randf_range(-8.0, 8.0)
	_target_elevation = 25.0
	if _no_balloon:
		_balloon_dot.visible = false
		_hint_label.text = Loc.t(&"theodolite.no_balloon")
	# Тонкая высокая фигура у леса — только ночью, со второй ночи, раз за ночь
	if Game.is_night() and Game.night >= 2 and not Game.has_flag("theo_zh_%d" % Game.night):
		_zh_az = _target_azimuth - randf_range(10.0, 16.0)
		_zh = Control.new()
		_zh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zh.draw.connect(func() -> void:
			var ink := Color(0.01, 0.015, 0.02, 0.95)
			_zh.draw_rect(Rect2(-3, -110, 6, 110), ink)
			_zh.draw_rect(Rect2(-7, -128, 14, 18), ink)
			_zh.draw_rect(Rect2(-12, -108, 3, 70), ink)
			_zh.draw_rect(Rect2(9, -106, 3, 72), ink)
			_zh.draw_circle(Vector2(-3, -120), 1.4, Color(0.6, 0.9, 0.5, 0.8))
			_zh.draw_circle(Vector2(3, -120), 1.4, Color(0.6, 0.9, 0.5, 0.8)))
		_zh.visible = false
		add_child(_zh)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Плавный микрометрический доворот маховиков теодолита
		_azimuth = fposmod(_azimuth + event.relative.x * 0.04, 360.0)
		_elevation = clampf(_elevation - event.relative.y * 0.04, 0.0, 85.0)
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_cancel"):
		_close()


func handle_input(event: InputEvent) -> void:
	_input(event)


func _process(delta: float) -> void:
	# Управление маховиками со стиков геймпада
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick.length_squared() < 0.005:
		var move_stick := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		stick = Vector2(move_stick.x, -move_stick.y)
	if stick.length_squared() > 0.005:
		_azimuth = fposmod(_azimuth + stick.x * delta * 24.0, 360.0)
		_elevation = clampf(_elevation - stick.y * delta * 20.0, 0.0, 85.0)

	# Движение шара-пилота в атмосфере
	if not _anomaly_triggered:
		_target_elevation += delta * 1.5
		_target_azimuth += delta * 0.4

		# Проверка на ночную аномалию (шар уводят в лес)
		if Game.night >= 3 and _target_elevation > 42.0:
			_anomaly_triggered = true
			Director.add_tension(15.0, "теодолит: шар перехвачен в чаще")
			AudioDirector.play_raw("res://assets/audio/sub_drop.ogg", -2.0)
			AudioDirector.play_raw("res://assets/audio/tree_creak.ogg", -4.0)
			Game.hud.subtitle(Loc.t(&"theodolite.anomaly_sub"), 4.0)

	else:
		# Аномальная траектория: шар прекращает подъем и неестественно уходит горизонтально над кронами
		_anomaly_t += delta
		_target_elevation = maxf(38.0 - _anomaly_t * 0.8, 15.0)
		_target_azimuth += delta * 3.5
		_frost_rect.modulate.a = minf(_frost_rect.modulate.a + delta * 0.35, 0.75)
		if _anomaly_t > 6.0:
			_balloon_dot.visible = false

	# Отображение точки шара на экране относительно центра перекрестия
	var vp_center := get_viewport_rect().size * 0.5
	var d_az := (_target_azimuth - _azimuth)
	if d_az > 180.0: d_az -= 360.0
	elif d_az < -180.0: d_az += 360.0

	var d_el := (_target_elevation - _elevation)
	var screen_pos := vp_center + Vector2(d_az * 45.0, -d_el * 45.0)
	_balloon_dot.position = screen_pos - Vector2(4, 4)
	_tick_zherdyai(delta, vp_center)

	# Проверка удержания в перекрестии (радиус 35 пикселей)
	var dist_to_cross := screen_pos.distance_to(vp_center)
	if dist_to_cross < 35.0 and _balloon_dot.visible and not _no_balloon:
		_tracking_progress = minf(_tracking_progress + delta * 18.0, 100.0)
		_balloon_dot.color = Color(0.4, 1.0, 0.6)
	else:
		_balloon_dot.color = Color(1.0, 0.85, 0.45)

	_tracking_bar.value = _tracking_progress
	_azimuth_label.text = Loc.t(&"theodolite.azimuth", [str(_azimuth).pad_decimals(1)])
	_elevation_label.text = Loc.t(&"theodolite.elevation", [str(_elevation).pad_decimals(1)])

	if _tracking_progress >= 100.0 and not Game.balloon_task_done:
		Game.balloon_task_done = true
		if Game.tasks != null and Game.tasks.is_active(&"balloon"):
			Game.tasks.complete(&"balloon")
		Director.add_tension(-10.0, "успешное зондирование ветра теодолитом")
		AudioDirector.play_raw("res://assets/audio/dawn_chime.ogg", -4.0)
		Game.hud.subtitle(Loc.t(&"theodolite.tracking_complete"), 3.5)


## Фигура стоит на линии горизонта (возвышение ~1.5°) левее шара; видна, пока не наведёшь на неё перекрестие.
func _tick_zherdyai(delta: float, vp_center: Vector2) -> void:
	if _zh == null or not is_instance_valid(_zh):
		return
	_zh_t += delta
	if _zh_t < 4.0:
		return
	var d_az := _zh_az - _azimuth
	if d_az > 180.0: d_az -= 360.0
	elif d_az < -180.0: d_az += 360.0
	var pos := vp_center + Vector2(d_az * 45.0, -(1.5 - _elevation) * 45.0)
	_zh.position = pos
	_zh.visible = true
	if pos.distance_to(vp_center + Vector2(0, -60)) < 70.0:
		_zh_on_cross += delta
		if _zh_on_cross > 0.35:
			Game.set_flag("theo_zh_%d" % Game.night, true)
			_zh.queue_free()
			_zh = null
			AudioDirector.play_raw("res://assets/audio/sub_drop.ogg", -4.0)
			Game.hud.subtitle(Loc.t(&"theodolite.zherdyai"), 4.5)
			Director.add_tension(12.0, "теодолит: фигура у кромки леса")
	else:
		_zh_on_cross = 0.0


func _close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit()
