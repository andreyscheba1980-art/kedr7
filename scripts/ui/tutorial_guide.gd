class_name TutorialGuide
extends Node
## Пролог-обучение делом, а не строкой в углу (план «демо → 1.0», этап 4).
## Когда начинается шаг (Game.TUTORIAL_STEPS после приезда), справа сверху — небольшая плашка: что сделать и как,
## с клавишей (не поверх центра экрана; пока открыт прибор или книга — спрятана). В мире над нужной вещью мерцает тусклый янтарный огонёк (виден сквозь метель, гаснет вблизи):
## будка/флюгер/рейка, рация, канистры → генератор, поленница → печь, «Буран», журнал.
## Стоишь без дела 45 с — карточка повторяется, огонёк вспыхивает. Шаг сделан — короткое «✓».

const IDLE_REPEAT := 45.0
const NEAR := 2.8

var _step: StringName = &""
var _card: Control
var _marker: MeshInstance3D
var _idle := 0.0
var _last_pos := Vector3.ZERO
var _pulse := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not Game.is_prologue() or not Game.has_flag("prologue_arrived") or Game.player == null or Game.dead or Game.hud == null:
		_hide_marker()
		return
	var step := _current()
	if step != _step:
		if _step != &"" and Game.tutorial.get(_step, false):
			_card_show(Loc.t(&"tutg.done", [Loc.t(StringName("tutg.%s.title" % _step))]), "", 2.5)
		_step = step
		_idle = 0.0
		if step != &"":
			_show_step(4.0 if _card == null else 6.5)
	if _card != null and is_instance_valid(_card):
		_card.visible = Game.hud.modal() == null
	if step == &"":
		_hide_marker()
		return
	# Простой: игрок почти не двигается и не в окне — напомнить
	var pp := Game.player.global_position
	if Game.hud.modal() == null and pp.distance_to(_last_pos) < 0.6:
		_idle += delta
	else:
		_idle = 0.0
	_last_pos = pp
	if _idle > IDLE_REPEAT:
		_idle = 0.0
		_show_step(0.0)
		_pulse = 1.5
	_update_marker(delta)


func _current() -> StringName:
	for s: StringName in Game.TUTORIAL_STEPS:
		if s == &"driver":
			continue
		if not Game.tutorial.get(s, false):
			return s
	return &""


func _show_step(delay: float) -> void:
	var s := _step
	await get_tree().create_timer(delay, false).timeout
	if s != _step:
		return
	_card_show(Loc.t(StringName("tutg.%s.title" % s)), Loc.t(StringName("tutg.%s.how" % s)), 9.0)
	_pulse = 1.5


## Плашка справа под часами: заголовок, ниже — как сделать.
func _card_show(title: String, how: String, dur: float) -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	var card := UiKit.panel(Color(0.04, 0.05, 0.07, 0.86))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var t := UiKit.label(title, 17, HORIZONTAL_ALIGNMENT_LEFT)
	t.modulate = Color(0.98, 0.86, 0.55)
	box.add_child(t)
	if how != "":
		var h := UiKit.label(how, 13, HORIZONTAL_ALIGNMENT_LEFT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(280, 0)
		h.modulate = Color(0.9, 0.9, 0.86)
		box.add_child(h)
	Game.hud._place(card, 1.0, 0.0, 1.0, 0.0, -320, 78, -20, 78)   # HUD — CanvasLayer, у него свой корневой контейнер
	card.visible = Game.hud.modal() == null
	card.modulate.a = 0.0
	_card = card
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.4)
	tw.tween_interval(dur)
	tw.tween_property(card, "modulate:a", 0.0, 1.0)
	tw.tween_callback(card.queue_free)
	Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -8.0)


## Куда сейчас идти: ближайшая несделанная цель шага (с учётом того, что в руках).
func _target() -> Vector3:
	var p := Game.player
	match _step:
		&"readings":
			var best := Vector3.INF
			for r: Array in [[&"temp", Yard.METEO + Yard.M_BOOTH + Vector3(0, 1.6, 0)], [&"wind", MeteoCorpus.PULT_POS + Vector3(0, 1.0, 0.4)],
					[&"snow", Yard.METEO + Yard.M_ROD + Vector3(0, 1.6, 0)], [&"baro", Vector3(8.5, 1.2, -1.48)],
					[&"baro", MeteoCorpus.BARO_POS + Vector3(0, 1.2, 0)]]:
				if not Game.readings.get(r[0], false):
					if best == Vector3.INF or p.global_position.distance_to(r[1]) < p.global_position.distance_to(best):
						best = r[1]
			return best
		&"test_report":
			return Vector3(8.6, 1.2, -1.2)
		&"refuel":
			if p.held == &"canister":
				return Vector3(14.2, 1.2, -13.7)
			return Yard.SHED + Vector3(-2.2, 1.4, -2.1)
		&"wood":
			if p.held == &"wood":
				return Vector3(-1.5, 1.0, 1.4)
			return Yard.WOODPILE + Vector3(0, 1.6, 0)
		&"buran":
			if Snowmobile.instance != null and is_instance_valid(Snowmobile.instance):
				return Snowmobile.instance.global_position + Vector3(0, 1.4, 0)
		&"journal":
			return Vector3(9.1, 1.05, -1.05)
	return Vector3.INF


func _update_marker(delta: float) -> void:
	if Game.is_indoors():
		_hide_marker()
		return
	var t := _target()
	if t == Vector3.INF:
		_hide_marker()
		return
	if _marker == null or not is_instance_valid(_marker):
		_marker = _make_marker()
	_marker.visible = true
	_marker.global_position = t
	var d := Game.player.global_position.distance_to(t)
	_pulse = maxf(_pulse - delta, 0.0)
	var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
	var a := clampf((d - NEAR) / 6.0, 0.0, 1.0) * (0.55 + 0.45 * blink) + _pulse * 0.4
	(_marker.material_override as StandardMaterial3D).albedo_color.a = clampf(a, 0.0, 1.0)
	var s := clampf(d * 0.07, 0.6, 6.0) * (1.0 + _pulse * 0.6)   # на расстоянии — заметная точка, вблизи — маленькая
	_marker.scale = Vector3(s, s, s)


func _make_marker() -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	m.disable_fog = false
	m.albedo_texture = _dot_texture()
	m.albedo_color = Color(1.0, 0.72, 0.3, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "TutorialMarker"
	Game.level.add_child(mi)
	return mi


## Мягкий ромб-огонёк: светлая середина, размытые края.
static func _dot_texture() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := absf(x - n * 0.5 + 0.5) / (n * 0.5)
			var dy := absf(y - n * 0.5 + 0.5) / (n * 0.5)
			var d := dx + dy
			# ядро-ромб плотное, ореол мягко гаснет к краю
			var a := 1.0 if d < 0.45 else clampf((1.0 - d) / 0.55, 0.0, 1.0) * 0.7
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _hide_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.visible = false


func _exit_tree() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
