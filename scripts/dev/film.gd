class_name FilmDirector
extends Node
## Съёмка роликов для itch.io через Movie Maker Godot:
##   godot --write-movie out.avi --fixed-fps 30 -- --film trailer|gameplay --lang ru|en
## Каждый план печатает в лог «[film] in/out <имя> <кадр>», монтаж — ffmpeg по этим меткам.
## В игре не используется.

var _app: Node
var _cam: Camera3D
var _light: SpotLight3D
var _clean := true
var _follow_player := true


func setup(app: Node) -> void:
	_app = app


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var lang := "ru"
	if args.has("--lang") and args.size() > args.find("--lang") + 1:
		lang = args[args.find("--lang") + 1]
	Settings.language = lang
	Settings.lang_chosen = true
	Settings.calibrated = true
	Loc.set_language(lang)
	var what := args[args.find("--film") + 1] if args.size() > args.find("--film") + 1 else "trailer"
	var part := 0
	if args.has("--part") and args.size() > args.find("--part") + 1:
		part = int(args[args.find("--part") + 1])
	if what == "gameplay":
		_gameplay.call_deferred(part)
	else:
		_trailer.call_deferred(part)


# --- Инфраструктура ------------------------------------------------------------

func _frame() -> int:
	return Engine.get_frames_drawn()


func _mark(kind: String, name: String) -> void:
	print("[film] %s %s %d" % [kind, name, _frame()])


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()


func _phase(kind: String, idx: int, minute := -1.0) -> void:
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": kind, "index": idx}
	for it in ["tape_recorder", "codebook", "flare_gun", "bunker_key", "tools", "skis"]:
		Game.give_item(StringName(it))
	for site in ["izba", "repeater", "lake", "bunker"]:
		Game.set_flag(site, true)
	_app.call(&"_start_phase")
	await _wait(6.0)
	if Game.hud != null:
		Game.hud.close_modal()
	Director.stop()
	if Game.yrka != null:
		Game.yrka.enabled = false
	if minute >= 0.0:
		Game.shift_minutes = minute
	Game.warmth = 100.0
	Game.fatigue = 0.0


func _ensure_cam() -> void:
	if _cam != null and is_instance_valid(_cam):
		return
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.near = 0.05
	_cam.far = 400.0
	Game.level.add_child(_cam)
	_light = SpotLight3D.new()
	_light.spot_range = 20.0
	_light.spot_angle = 26.0
	_light.light_energy = 2.4
	_light.light_color = Color(1.0, 0.93, 0.8)
	_light.shadow_enabled = true
	_light.position = Vector3(0.25, -0.25, 0.0)
	_cam.add_child(_light)


## Кинокамера: true — смотрим через неё; flash — свой «фонарь» на камере.
func _film_cam(on: bool, flash := false) -> void:
	_ensure_cam()
	_cam.current = on
	_light.visible = flash
	if Game.player != null:
		Game.player.flashlight.visible = false
		if not on:
			Game.player.camera.current = true


## Проезд камеры: позиция и точка взгляда плавно (smoothstep) из A в B.
func _dolly(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, dur: float, ease := true) -> void:
	_ensure_cam()
	var t := 0.0
	while t < dur:
		var k := t / dur
		if ease:
			k = k * k * (3.0 - 2.0 * k)
		_cam.global_position = p0.lerp(p1, k)
		_cam.look_at(l0.lerp(l1, k), Vector3.UP)
		if _follow_player and Game.player != null:
			# Игрок «ходит» вместе с камерой: зоны, ветер, звуки дома/улицы — как в игре.
			Game.player.global_position = _cam.global_position - Vector3(0, 1.6, 0)
			Game.player.velocity = Vector3.ZERO
		await get_tree().process_frame
		t += get_process_delta_time()


func _hud_clean(on: bool) -> void:
	_clean = on


func _process(_delta: float) -> void:
	if Game.hud == null or not is_instance_valid(Game.hud):
		return
	if Hints._inst != null and is_instance_valid(Hints._inst):
		Hints._inst.set_process(false)       # записки-подсказки в ролик не попадают
		Hints._inst._queue.clear()
	for n: String in ["_fps", "_tasks_panel"]:   # счётчик кадров и лист задач в кадре не нужны никогда
		var c0: Variant = Game.hud.get(n)
		if c0 is CanvasItem:
			(c0 as CanvasItem).visible = false
	var names := ["_clock", "_objective", "_prompt", "_held_label", "_flash_box", "_subtitle"]
	for n: String in names:
		var c: Variant = Game.hud.get(n)
		if c is CanvasItem:
			(c as CanvasItem).visible = not _clean
	# Точка-прицел — безымянный ColorRect 4×4 в корне HUD
	for ch in Game.hud.root.get_children():
		if ch is ColorRect and (ch as ColorRect).size.x <= 5.0:
			(ch as ColorRect).visible = not _clean


func _eyes(at: Vector3, look: Vector3) -> Node3D:
	var root := Node3D.new()
	Game.level.add_child(root)
	root.global_position = at
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	for side: float in [-0.065, 0.065]:
		var m := MeshInstance3D.new()
		m.mesh = sm
		m.material_override = Palette.glow(&"red", true)
		m.position = Vector3(side, 0, 0)
		root.add_child(m)
	root.look_at(look, Vector3.UP)
	return root


# --- Трейлер (под трек One Magnesium Flare, ~58 с) ---------------------------------

func _trailer(part: int) -> void:
	await _wait(0.5)
	match part:
		1: await _trailer_house()
		2: await _trailer_outside()
		3: await _trailer_window_radio()
		4: await _trailer_knock()
		5: await _trailer_chase()
		6: await _trailer_outro()
	print("[film] done")
	get_tree().quit()


func _trailer_house() -> void:
	# ===== Ночь 4: снаружи, дом и снег =====
	await _phase("night", 4, 150.0)
	_hud_clean(true)
	_film_cam(true)
	Game.weather.force_blizzard(false)
	_mark("in", "ext_wide")
	await _dolly(Vector3(31, 1.9, 17), Vector3(25.5, 1.7, 12.5), Vector3(9, 1.6, 2.5), Vector3(8, 1.4, 2.5), 6.0)
	_mark("out", "ext_wide")

	# Радиорубка: наезд на рацию
	_mark("in", "radio_push")
	await _dolly(Vector3(4.6, 1.65, 1.2), Vector3(7.6, 1.35, -0.4), Vector3(9.2, 1.1, -1.4), Vector3(9.2, 1.0, -1.5), 5.0)
	_mark("out", "radio_push")

	# Коридор: свет мигает
	_mark("in", "corridor")
	var fl := func() -> void: Game.level.flicker(2.2)
	get_tree().create_timer(1.6, false).timeout.connect(fl)
	await _dolly(Vector3(11.0, 1.6, 4.8), Vector3(9.4, 1.6, 4.6), Vector3(4.0, 1.4, 4.2), Vector3(4.0, 1.5, 4.0), 4.5)
	_mark("out", "corridor")

	# Комната: печь и стол, медленная панорама
	_mark("in", "room")
	await _dolly(Vector3(2.9, 1.6, 6.0), Vector3(2.4, 1.55, 5.2), Vector3(-1.5, 1.1, 0.6), Vector3(-1.2, 0.9, 2.6), 4.5)
	_mark("out", "room")



func _trailer_outside() -> void:
	await _phase("night", 4, 150.0)
	_hud_clean(true)
	# ===== Улица ночью: фонарь, трос, тропа =====
	_film_cam(true, true)
	_mark("in", "rope_walk")
	await _dolly(Vector3(19.5, 1.62, 5.4), Vector3(26.5, 1.62, 0.6), Vector3(26, 1.2, 0.5), Vector3(33, 0.9, -5.5), 4.0, false)
	_mark("out", "rope_walk")

	_mark("in", "meteo")
	await _dolly(Vector3(51.0, 1.6, -28.6), Vector3(53.2, 1.55, -30.2), Vector3(58, 1.4, -31.2), Vector3(58, 1.5, -31.0), 3.0)
	_mark("out", "meteo")

	# Глаза в чаще
	var eyes: Array[Node3D] = []
	_mark("in", "eyes")
	var cam_p := Vector3(38, 1.6, -12)
	var tgt := Vector3(52, 1.6, -4)
	_light.visible = false
	var fwd := (tgt - cam_p).normalized()
	for i in range(3):
		get_tree().create_timer(0.4 + i * 0.6, false).timeout.connect(func() -> void:
			var e := _eyes(cam_p + fwd.rotated(Vector3.UP, deg_to_rad(-16.0 + i * 15.0)) * (5.5 + i * 1.5) + Vector3(0, 0.15 * i, 0), cam_p)
			e.scale = Vector3.ONE * 1.8
			eyes.append(e))
	await _dolly(cam_p, cam_p + Vector3(0.3, 0, 0.15), tgt, tgt + Vector3(0, 0, 0.6), 3.0)
	_mark("out", "eyes")
	for e in eyes:
		if is_instance_valid(e):
			e.queue_free()

	# Крыльцо: возвращаешься к свету лампы над дверью, метель усиливается
	Game.weather.force_blizzard(true, 30.0)
	_light.visible = true
	_mark("in", "porch")
	await _dolly(Vector3(24, 1.6, 6.5), Vector3(18.4, 1.6, 4.0), Vector3(14.5, 1.5, 3.1), Vector3(14.5, 1.4, 3.1), 3.2)
	_mark("out", "porch")
	Game.weather.force_blizzard(false)



func _trailer_window_radio() -> void:
	await _phase("night", 4, 150.0)
	_hud_clean(true)
	# Жердяй в окне рубки
	_film_cam(true, false)
	var zh := Creatures.make_zherdyai(83.0)
	Game.level.add_child(zh)
	zh.global_position = Vector3(9.2, 0.0, -3.7)
	zh.look_at(Vector3(9.2, 0.0, 0.0), Vector3.UP)
	zh.visible = false
	# Холодный отсвет снега снаружи — без него силуэт за стеклом теряется в черноте
	var rim := OmniLight3D.new()
	rim.omni_range = 3.0
	rim.light_energy = 3.0
	rim.light_color = Color(0.65, 0.75, 0.95)
	Game.level.add_child(rim)
	rim.global_position = Vector3(9.2, 1.7, -2.35)
	_mark("in", "window")
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		zh.visible = true
		Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 0.0))
	get_tree().create_timer(2.6, false).timeout.connect(func() -> void: Game.level.flicker(0.8))
	await _dolly(Vector3(8.5, 1.55, 0.7), Vector3(9.05, 1.5, -0.55), Vector3(9.2, 1.6, -2.0), Vector3(9.2, 1.65, -2.0), 3.4)
	_mark("out", "window")
	zh.queue_free()
	rim.queue_free()

	# Рация: шкала (с панелью рации)
	_film_cam(false)
	Game.player.global_position = Vector3(9.2, 0.05, -0.3)
	Game.player.rotation.y = 0.0
	Game.player.head.rotation.x = deg_to_rad(-22.0)
	Game.radio.enter()
	_hud_clean(true)
	await _wait(0.6)
	_mark("in", "radio_ui")
	for i in range(45):
		Game.radio.set_freq(5180.0 + i * 3.0)
		await get_tree().process_frame
	await _wait(1.0)
	_mark("out", "radio_ui")
	Game.radio.exit()



func _trailer_knock() -> void:
	# ===== Ночь 3: стук и глазок =====
	await _phase("night", 3, 300.0)
	_hud_clean(true)
	Game.player.global_position = Vector3(13.4, 0.05, 3.1)
	Game.player.rotation.y = deg_to_rad(-90.0)
	Game.events._knock_sequence(false)
	await _wait(1.5)
	_film_cam(true)
	_mark("in", "door_knock")
	await _dolly(Vector3(11.8, 1.6, 4.9), Vector3(12.6, 1.6, 4.2), Vector3(14.5, 1.4, 3.1), Vector3(14.5, 1.35, 3.1), 3.0)
	_mark("out", "door_knock")
	_film_cam(false)
	EventBus.ui_requested.emit(&"peephole")
	await _wait(0.2)
	_mark("in", "peephole")
	await _wait(3.6)
	_mark("out", "peephole")
	Game.hud.close_modal()



func _trailer_chase() -> void:
	# ===== Ночь 5: Ырка, погоня и ракета =====
	await _phase("night", 5, 200.0)
	_hud_clean(true)
	# Ырка бежит из темноты прямо в луч фонаря (постановочно, кинокамера с «фонарём»)
	_film_cam(true, true)
	var cam_p := Vector3(30.0, 1.6, -6.0)
	var dir := Vector3(-0.7, 0, 0.7).normalized()       # смотрим на юго-запад, в лес
	var yr := Creatures.make_yrka()
	yr.gait = 1.0
	Game.level.add_child(yr)
	var y_from := cam_p + dir * 16.0
	var y_to := cam_p + dir * 2.4
	y_from.y = 0.0
	y_to.y = 0.0
	yr.global_position = y_from
	yr.look_at(Vector3(cam_p.x, 0, cam_p.z), Vector3.UP)
	_cam.global_position = cam_p
	_cam.look_at(cam_p + dir * 10.0 + Vector3(0, -0.6, 0), Vector3.UP)
	Game.player.global_position = cam_p - Vector3(0, 1.6, 0)
	Game.audio.play_2d("res://assets/audio/whistle.ogg", 2.0)
	_mark("in", "chase")
	var t := 0.0
	while t < 1.9:
		var k := t / 1.9
		yr.global_position = y_from.lerp(y_to, k * k)
		_cam.global_position = cam_p + Vector3(randf_range(-0.01, 0.01), randf_range(-0.01, 0.01), 0) * (1.0 + k * 4.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	_mark("out", "chase")
	# Ракета: вспышка, Ырка отшатывается
	_mark("in", "flare")
	_film_cam(false)
	Game.player.global_position = cam_p - Vector3(0, 1.6, 0)
	Game.player.rotation.y = atan2(-dir.x, -dir.z)
	Game.player.head.rotation.x = deg_to_rad(-6.0)
	Game.player.flashlight.visible = true
	Game.player.fire_flare()
	Game.audio.play_3d("res://assets/audio/shriek.ogg", yr.global_position + Vector3(0, 1.3, 0), 4.0, 8.0)
	t = 0.0
	while t < 2.4:
		yr.global_position = y_to.lerp(y_from, minf(t / 1.2, 1.0))
		await get_tree().process_frame
		t += get_process_delta_time()
	_mark("out", "flare")
	yr.queue_free()

	# Лицо — на кульминацию
	_mark("in", "face")
	Game.hud.flash_face(0.6)
	Game.audio.play_2d("res://assets/audio/scream.ogg", -2.0)
	await _wait(0.8)
	_mark("out", "face")



func _trailer_outro() -> void:
	# ===== Финал: дальний план станции, титр поверх =====
	await _phase("night", 7, 120.0)
	_hud_clean(true)
	_film_cam(true)
	_mark("in", "outro")
	await _dolly(Vector3(40, 3.0, 28), Vector3(34, 2.4, 22), Vector3(8, 1.5, 2), Vector3(8, 1.5, 2), 12.0)
	_mark("out", "outro")


# --- Геймплей (с интерфейсом и субтитрами, ~90 с) ------------------------------

func _walk(points: Array, speed := 2.6) -> void:
	# Игрок идёт по точкам (камера игрока, интерфейс включён).
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var d := a.distance_to(b)
		var t := 0.0
		var yaw := atan2(-(b.x - a.x), -(b.z - a.z))
		while t < d / speed:
			var k := t / (d / speed)
			Game.player.global_position = a.lerp(b, k)
			Game.player.rotation.y = lerp_angle(Game.player.rotation.y, yaw, 0.12)
			Game.player.head.rotation.x = lerpf(Game.player.head.rotation.x, deg_to_rad(-7.0), 0.08)
			Game.player.velocity = Vector3.ZERO
			await get_tree().process_frame
			t += get_process_delta_time()


func _turn_to(target: Vector3, dur := 0.6) -> void:
	var p := Game.player.global_position + Vector3(0, 1.6, 0)
	var d := target - p
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var y0 := Game.player.rotation.y
	var p0 := Game.player.head.rotation.x
	var t := 0.0
	while t < dur:
		var k := t / dur
		k = k * k * (3.0 - 2.0 * k)
		Game.player.rotation.y = lerp_angle(y0, yaw, k)
		Game.player.head.rotation.x = lerpf(p0, pitch, k)
		await get_tree().process_frame
		t += get_process_delta_time()


func _gameplay(part: int) -> void:
	await _wait(0.5)
	match part:
		1: await _gameplay_out()
		2: await _gameplay_back()
	print("[film] done")
	get_tree().quit()


func _gameplay_out() -> void:
	await _phase("night", 2, 20.0)
	_hud_clean(false)
	_film_cam(false)
	Game.player.global_position = Vector3(1.0, 0.05, 4.6)
	Game.player.rotation.y = deg_to_rad(90.0)
	_mark("in", "g_room")
	await _turn_to(Vector3(-1.5, 0.8, 1.0), 1.2)
	await _wait(0.8)
	# Подкинуть дров
	await _walk([Vector3(1.0, 0.05, 4.6), Vector3(-0.6, 0.05, 2.2)], 2.2)
	await _turn_to(Vector3(-1.5, 0.6, 1.0), 0.5)
	Game.stove_wood = 30.0
	Game.player.set_held(&"wood")
	Game.level.call(&"_on_stove_used", Game.player)
	await _wait(1.4)
	# На улицу через коридор и тамбур
	Game.player.toggle_flashlight()
	await _walk([Vector3(-0.6, 0.05, 2.2), Vector3(3.0, 0.05, 3.15), Vector3(11.0, 0.05, 3.15), Vector3(14.0, 0.05, 3.1)], 3.0)
	Game.level.set_door_open(true)
	await _walk([Vector3(14.0, 0.05, 3.1), Vector3(16.8, 0.05, 3.5)], 3.0)
	Game.level.set_door_open(false)
	await _walk([Vector3(16.8, 0.05, 3.5), Vector3(20, 0.05, 3.5), Vector3(29, 0.05, -2), Vector3(40, 0.05, -14), Vector3(50, 0.05, -24), Vector3(51.5, 0.05, -30)], 5.5)
	_mark("out", "g_room")
	# Показания
	_mark("in", "g_meteo")
	await _walk([Vector3(51.5, 0.05, -30), Vector3(55.4, 0.05, -30), Vector3(56.6, 0.05, -29.6)], 2.0)
	await _turn_to(Vector3(58, 1.45, -31.0), 0.6)
	await _wait(1.6)
	Game.take_reading(&"temp")
	await _wait(1.2)
	await _turn_to(Vector3(55.8, 1.3, -34.0), 0.7)
	await _wait(1.0)
	Game.take_reading(&"wind")
	await _wait(1.0)
	await _turn_to(Vector3(60.4, 1.0, -33.8), 0.7)
	await _wait(0.8)
	Game.take_reading(&"snow")
	await _wait(1.2)
	_mark("out", "g_meteo")


func _gameplay_back() -> void:
	await _phase("night", 2, 230.0)
	_hud_clean(false)
	_film_cam(false)
	for k in Game.READING_KEYS:
		Game.take_reading(k)
	Game.player.toggle_flashlight()
	Game.player.global_position = Vector3(57.4, 0.05, -30.4)
	# Возвращение: свист в лесу
	_mark("in", "g_back")
	await _walk([Vector3(57.4, 0.05, -30.4), Vector3(51.5, 0.05, -30), Vector3(50, 0.05, -24), Vector3(40, 0.05, -14)], 4.0)
	Game.audio.play_3d("res://assets/audio/whistle.ogg", Game.player.global_position + Vector3(-12, 2, -6), 4.0, 10.0)
	await _wait(0.6)
	await _turn_to(Game.player.global_position + Vector3(-12, 1.4, -6), 0.8)
	await _wait(1.6)
	await _walk([Vector3(40, 0.05, -14), Vector3(29, 0.05, -2), Vector3(20, 0.05, 3.5), Vector3(16.4, 0.05, 3.4)], 5.0)
	Game.level.set_door_open(true)
	await _walk([Vector3(16.4, 0.05, 3.4), Vector3(14.0, 0.05, 3.1), Vector3(11.0, 0.05, 3.15)], 3.0)
	Game.level.set_door_open(false)
	await _walk([Vector3(11.0, 0.05, 3.15), Vector3(7.55, 0.05, 3.0), Vector3(7.55, 0.05, 1.2), Vector3(8.6, 0.05, -0.4)], 2.6)
	_mark("out", "g_back")
	# Сводка по рации
	_mark("in", "g_radio")
	Game.player.toggle_flashlight()
	await _turn_to(Vector3(9.2, 0.95, -1.4), 0.6)
	Game.radio.enter()
	await _wait(0.8)
	for i in range(30):
		Game.radio.set_freq(6700.0 + i * 6.0)
		await get_tree().process_frame
	await _wait(1.2)
	Game.radio.transmit()
	await _wait(6.5)
	Game.radio.exit()
	_mark("out", "g_radio")
	# Окно: силуэт за стеклом
	_mark("in", "g_window")
	var zh := Creatures.make_zherdyai(83.0)
	Game.level.add_child(zh)
	zh.global_position = Vector3(9.2, 0.0, -3.7)
	zh.look_at(Vector3(9.2, 0.0, 0.0), Vector3.UP)
	var rim := OmniLight3D.new()
	rim.omni_range = 3.0
	rim.light_energy = 3.0
	rim.light_color = Color(0.65, 0.75, 0.95)
	Game.level.add_child(rim)
	rim.global_position = Vector3(9.2, 1.7, -2.35)
	await _turn_to(Vector3(9.2, 1.6, -2.0), 1.4)
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 0.0)
	Game.hud.subtitle(Loc.t(&"sub.window_reflection"), 3.0)
	await _wait(1.2)
	Game.level.flicker(1.0)
	await _wait(1.0)
	zh.queue_free()
	rim.queue_free()
	await _wait(1.0)
	_mark("out", "g_window")
