class_name NightIntro
extends RefCounted
## Вступления к ночам 2–7 (1.54): 8–10 секунд на движке между карточкой «НОЧЬ N» и началом смены.
## Не рассказываем — показываем, что сегодня изменилось, и обрываем на чёрном. Один раз за прохождение
## (флаг intro_N), не с чекпоинта, не в коопе. [Esc] — пропустить.
##   2 — на коньке крыши стоит человек;      3 — на пороге иней крестом, стук, у двери никого;
##   4 — от леса к крыльцу босые следы;      5 — в кладовой дрожат половицы;
##   6 — у старой дороги вспыхивают фары;    7 — за окном рубки — твоё лицо.

const KNOCK := "res://assets/audio/door_knock.ogg"
const STINGER := "res://assets/audio/sub_drop.ogg"
const HUM := "res://assets/audio/hum_loop.ogg"
const STATIC := "res://assets/audio/radio_anomaly.ogg"
const GUST := "res://assets/audio/gust.ogg"
const ENGINE := "res://assets/audio/engine_loop.ogg"


static func wants() -> bool:
	if not Game.is_night() or Game.night < 2 or Game.resumed or Net.role != "":
		return false
	var cli := OS.get_cmdline_user_args()
	if cli.has("--no_intro") or (SaveGame._testing() and not cli.has("intros")):
		return false
	return not SaveGame.flags.get("intro_%d" % Game.night, false)


static func _h(x: float, z: float) -> float:
	return Terrain.height(x, z)


static func play(n: int, title: String) -> void:
	SaveGame.flags["intro_%d" % n] = true
	var made: Array[Node] = []
	var add := func(node: Node) -> Node:
		Game.level.add_child(node)
		made.append(node)
		return node
	var cam_a: Array = []
	var cam_b: Array = []
	var mid: Array = []                 ## шаги посередине (звуки, действие)
	var dur := 6.0
	match n:
		2:
			var g := Creatures.make_double(&"semenov")
			if g != null:
				add.call(g)
				g.global_position = Vector3(4.2, 5.45, 3.3)
				g.look_at(Vector3(10.0, 5.45, 14.0), Vector3.UP)
				g.pose_override = &"still"
			var l := OmniLight3D.new()
			l.light_color = Color(0.6, 0.7, 0.95)
			l.light_energy = 0.9
			l.omni_range = 4.0
			add.call(l)
			l.global_position = Vector3(5.5, 7.0, 5.0)
			cam_a = [Vector3(13.0, _h(13, 21) + 1.3, 21.0), Vector3(5.0, 4.6, 3.3)]
			cam_b = [Vector3(11.0, _h(11, 17) + 1.5, 17.0), Vector3(4.4, 5.9, 3.3)]
			mid = [{"wait": 3.2}, {"sfx": "res://assets/sfx/cc0/step_plank_3.ogg", "at": Vector3(4.2, 5.5, 3.3), "vol": 2.0}]
		3:
			for a: float in [35.0, -35.0]:
				var bar := Geo.box_mesh(Vector3(0.05, 0.012, 0.9), Palette.m(&"ice"))
				add.call(bar)
				bar.global_position = Vector3(15.35, 0.07, 3.1)
				bar.rotation.y = deg_to_rad(a)
			cam_a = [Vector3(19.5, 1.0, 5.2), Vector3(15.0, 0.4, 3.1)]
			cam_b = [Vector3(17.4, 0.75, 4.0), Vector3(15.2, 0.2, 3.1)]
			mid = [{"wait": 2.6}, {"sfx": KNOCK, "at": Vector3(14.6, 1.3, 3.1), "vol": 4.0}, {"wait": 0.42},
				{"sfx": KNOCK, "at": Vector3(14.6, 1.3, 3.1), "vol": 4.0}, {"wait": 0.42}, {"sfx": KNOCK, "at": Vector3(14.6, 1.3, 3.1), "vol": 4.0}]
		4:
			var from := Vector3(38.0, 0, 20.0)
			var to := Vector3(16.6, 0, 3.6)
			var dir := (to - from).normalized()
			for i in 22:
				var k := float(i) / 21.0
				var pos := from.lerp(to, k) + dir.cross(Vector3.UP) * (0.13 if i % 2 == 0 else -0.13)
				var foot := Geo.box_mesh(Vector3(0.1, 0.012, 0.24), Palette.m(&"dark"))
				add.call(foot)
				foot.global_position = Vector3(pos.x, _h(pos.x, pos.z) + 0.012, pos.z)
				foot.look_at(foot.global_position + dir, Vector3.UP)
			cam_a = [Vector3(30.0, _h(30, 4) + 5.5, 4.0), Vector3(30.0, 0.0, 14.0)]
			cam_b = [Vector3(21.0, _h(21, 1) + 3.2, 1.0), Vector3(16.0, 0.5, 3.4)]
			mid = [{"wait": 1.0}, {"sfx": GUST, "vol": -2.0}]
		5:
			var cold := OmniLight3D.new()     # в кладовой нет лампы — только отсвет снега из щелей
			cold.light_color = Color(0.6, 0.7, 0.95)
			cold.light_energy = 1.1
			cold.omni_range = 4.5
			add.call(cold)
			cold.global_position = Vector3(5.8, 1.5, -3.8)
			cam_a = [Vector3(6.6, 0.35, -3.5), Vector3(5.0, 0.0, -4.9)]
			cam_b = [Vector3(6.2, 0.28, -3.9), Vector3(5.0, 0.0, -5.0)]
			mid = [{"sfx": HUM, "at": Vector3(5.2, -0.6, -4.6), "vol": 4.0}, {"wait": 3.0},
				{"sfx": "res://assets/audio/knock.ogg", "at": Vector3(5.2, -0.5, -4.6), "vol": 4.0}, {"wait": 0.45},
				{"sfx": "res://assets/audio/knock.ogg", "at": Vector3(5.2, -0.5, -4.6), "vol": 4.0}, {"wait": 0.45},
				{"sfx": "res://assets/audio/knock.ogg", "at": Vector3(5.2, -0.5, -4.6), "vol": 4.0}]
			dur = 4.0
		6:
			var lp := Vector3(36.0, _h(36, 24), 24.0)
			var lights := Node3D.new()
			add.call(lights)
			lights.global_position = lp
			lights.look_at(Vector3(15.8, lp.y, 3.1), Vector3.UP)
			lights.visible = false
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.92, 0.7)
			var sph := SphereMesh.new()
			sph.radius = 0.2
			sph.height = 0.4
			for x: float in [-0.75, 0.75]:
				var lamp := MeshInstance3D.new()
				lamp.mesh = sph
				lamp.material_override = mat
				lamp.position = Vector3(x, 1.1, -0.2)
				lights.add_child(lamp)
			var glow := OmniLight3D.new()
			glow.position = Vector3(0, 1.3, -1.5)
			glow.omni_range = 10.0
			glow.light_energy = 1.6
			glow.light_color = Color(1.0, 0.9, 0.7)
			lights.add_child(glow)
			cam_a = [Vector3(16.4, 1.55, 2.4), Vector3(36.0, 1.2, 24.0)]
			cam_b = [Vector3(16.9, 1.5, 2.9), Vector3(36.0, 1.2, 24.0)]
			mid = [{"wait": 2.4}, {"call": func() -> void: lights.visible = true},
				{"sfx": ENGINE, "at": lp + Vector3(0, 1, 0), "vol": -2.0, "unit": 14.0}, {"wait": 2.2},
				{"call": func() -> void: lights.visible = false}]
		7:
			var g := Creatures.make_double(&"orekhov")
			if g != null:
				add.call(g)
				g.global_position = Vector3(9.35, _h(9.35, -4.4), -4.4)
				g.look_at(Vector3(9.2, g.global_position.y, 0.0), Vector3.UP)
				g.pose_override = &"still"
			var l := OmniLight3D.new()
			l.light_color = Color(0.62, 0.72, 0.92)
			l.light_energy = 0.7
			l.omni_range = 3.5
			add.call(l)
			l.global_position = Vector3(9.0, 2.2, -3.4)
			cam_a = [Vector3(9.2, 1.55, 0.9), Vector3(9.2, 1.45, -2.0)]
			cam_b = [Vector3(9.2, 1.5, -0.6), Vector3(9.25, 1.5, -2.0)]
			mid = [{"sfx": STATIC, "at": Vector3(9.2, 1.0, -1.4), "vol": -4.0}, {"wait": 2.5}]
		_:
			return
	var steps: Array = [
		{"fade": 1.0, "t": 0.01},
		{"call": func() -> void: Game.hud.fade_out_screen(0.25)},
		{"wait": 0.3},
		{"cam": cam_a},
		{"fade": 0.0, "t": 1.3},
	]
	# Проезд камеры идёт сам (твином); звуки и действие — поверх
	steps.append({"call": func() -> void: _slow_move(cam_b, dur)})
	steps.append_array(mid)
	steps.append({"wait": 1.2})
	steps.append({"sfx": STINGER, "vol": 0.0})
	steps.append({"fade": 1.0, "t": 0.05})
	steps.append({"wait": 0.9})
	steps.append({"call": func() -> void:
		Game.hud.show_screen(title)
		for node in made:
			if is_instance_valid(node):
				node.queue_free()})
	await Cutscene.play(steps, true)


## Медленный наезд камеры катсцены — параллельно со звуками (не ждём его).
static func _slow_move(to: Array, dur: float) -> void:
	var cam := Game.level.get_viewport().get_camera_3d()
	if cam != null:
		var tw := cam.create_tween()
		var target := Transform3D(Basis.looking_at((to[1] as Vector3) - (to[0] as Vector3), Vector3.UP), to[0])
		tw.tween_property(cam, "global_transform", target, dur + 2.0).set_trans(Tween.TRANS_SINE)
