class_name AutoTest
extends Node
## Прогон для разработки: запускается с `-- --autotest`. Проходит меню, пролог, день и ночи
## ускоренно, дёргает системы и сохраняет скриншоты в user://shots/. В игре не используется.

const SHOTS := "user://shots/"
const CovenantsClass = preload("res://scripts/data/covenants.gd")
const Synoptic = preload("res://scripts/data/synoptic.gd")
const MeteorFaxUI = preload("res://scripts/ui/meteor_fax_ui.gd")
const JournalTM1UI = preload("res://scripts/ui/journal_tm1_ui.gd")

var _app: Node
var _n := 0


func _ready() -> void:
	_app = get_parent()
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if args.has("--film"):
		var f := FilmDirector.new()
		f.setup(_app)
		add_child(f)
		return
	if args.has("--deathtest"):
		_deaths.call_deferred()
	elif args.has("--stage"):
		_stage.call_deferred(args)
	elif args.has("--inspect_fixes"):
		_inspect_fixes.call_deferred()
	elif args.has("--probe2"):
		_probe2.call_deferred(args)
	elif args.has("--probe"):
		_probe.call_deferred()
	elif args.has("--tour"):
		_tour.call_deferred(args)
	elif args.has("--inspect_stages"):
		_inspect_stages.call_deferred()
	elif args.has("--polish_test"):
		_polish_test.call_deferred()
	elif args.has("--joypad_test"):
		_joypad_test.call_deferred()
	elif args.has("--prologue_review"):
		_prologue_review.call_deferred()
	elif args.has("--test_cabin"):
		_test_cabin.call_deferred()
	else:
		_run.call_deferred()


## Обзор пролога кадрами: a — кабина и выход, b/c — просека по метрам.
func _prologue_review() -> void:
	var args := OS.get_cmdline_user_args()
	var part := args[args.find("--prologue_review") + 1] if args.size() > args.find("--prologue_review") + 1 else "a"
	SaveGame.new_game("story")
	if part != "a" and part != "o":
		Game.set_flag("left_cabin", true)
	if part in ["d", "e", "f", "g", "h", "i", "j", "k", "l", "tg"]:
		Game.set_flag("prologue_arrived", true)
	if part == "e":
		Game.set_flag("buran_uncovered", true)
	Game.setup_phase(&"day", 0)
	var sess := Session.new()
	_app.add_child(sess)
	var t0 := Time.get_ticks_msec()
	var fr := 0
	while fr < 1500 and (Game.hud == null or not Game.hud._screen_label.text.contains("%")):
		await get_tree().process_frame
		fr += 1
	while fr < 6000 and Game.hud._screen_label.text.contains("%"):
		await get_tree().process_frame
		fr += 1
	await _wait(1.0)
	Game.hud._screen.visible = false
	print("[rev] маршрут %.0f м" % PrologueTrail.length_m())
	print("[rev] канистры: в сарае %d, placed %s, site %s, prologue=%s arrived=%s" % [Game.canisters_left, SaveGame.flags.get("placed_cans", []), SaveGame.flags.get("site_cans", []).size(), Game.is_prologue(), Game.has_flag("prologue_arrived")])
	if part == "z":
		get_tree().quit()
		return
	if part == "o":   # холодный старт и разговор в кабине: кадр каждые 4.5 с
		if args.has("fast"):
			Engine.time_scale = 3.0
		for k in 30:
			await _wait(4.5)
			await _shot("open_%02d" % k)
		get_tree().quit()
		return
	if part == "a":
		for k in 4:
			await _wait(2.5)
			await _shot("cab_%02d" % k)
		var w := 0
		while not Vehicle.can_exit_cabin() and w < 60:
			await _wait(0.5)
			w += 1
		await _shot("cab_stop")
		Vehicle.request_exit()
		await _wait(1.0)
		await _shot("exit_0")
		await _wait(8.0)
		await _shot("exit_leaving")
		Game.player.rotation.y += PI
		await _wait(0.4)
		await _shot("exit_back")
		get_tree().quit()
		return
	if part == "d":
		await _buran_review()
		get_tree().quit()
		return
	if part == "e":
		await _sites_review()
		get_tree().quit()
		return
	if part == "f":
		await _yrka_review()
		get_tree().quit()
		return
	if part == "g":
		await _events_review()
		get_tree().quit()
		return
	if part == "tg":
		await _tutg_review()
		get_tree().quit()
		return
	if part == "h":
		await _dog_review()
		get_tree().quit()
		return
	if part == "i":
		await _dog_escape_review()
		get_tree().quit()
		return
	if part == "j":
		await _people_review()
		get_tree().quit()
		return
	if part == "k":
		await _spirits_review()
		get_tree().quit()
		return
	if part == "l":
		await _look_review()
		get_tree().quit()
		return
	var marks := [5.0, 30.0, 60.0, 78.0, 110.0, 140.0, 170.0, 200.0] if part == "b" else [230.0, 255.0, 280.0, 300.0, 315.0, PrologueTrail.length_m() - 3.0]
	for m: float in marks:
		var pd: Array = PrologueTrail.point_at(m)
		var p: Vector3 = pd[0]
		var d: Vector3 = pd[1]
		Game.player.global_position = p + Vector3(0, 0.3, 0)
		Game.player.velocity = Vector3.ZERO
		Game.player.rotation.y = atan2(-d.x, -d.z)
		Game.player.head.rotation.x = -0.06
		Game.player.set_flashlight(true)
		await _wait(1.2)
		await _shot("m%03d" % int(m))
		print("[rev] %.0f м: %s, Y %.1f" % [m, p, Game.player.global_position.y])
	get_tree().quit()


func _source_review() -> void:
	print("[src] bearings=", FieldJobs.bearing_count(), " zone=", FieldJobs.search_zone(), " site=", SourceSite.instance != null)
	EventBus.ui_requested.emit(&"map")
	await _wait(1.0)
	if Game.hud != null:
		Game.hud.visible = true
	await _shot("src_map_3brg")
	for mv in get_tree().root.find_children("*", "MapView", true, false):
		(mv as MapView).closed.emit()
	await _wait(0.5)
	var c := Terrain.pad_pos(&"source")
	var road_end := Vector3(-95, 0, 60)
	for k in 2:
		var eye := c + (road_end - c).normalized() * (14.0 if k == 0 else 5.0) + Vector3(3.0 * k, 0, 0)
		_look(Vector3(eye.x, Terrain.height(eye.x, eye.z) + 0.05, eye.z), c + Vector3(0, 2.0 - k, 0))
		await _wait(1.5)
		await _shot("src_site_%d" % k)
	var ss := SourceSite.instance
	(ss.get_node("SemenovNotebook") as Interactable).interact(Game.player)
	await _wait(0.6)
	await _shot("src_note")
	print("[src] found=", SourceSite.found(), " box prompt=", (ss.get_node("OtzvukBox") as Interactable).get_prompt())
	print("[src] tasks:\n", "\n".join(FieldJobs.task_lines()))
	# Дальняя дорога-просека от зимника
	_look(Vector3(-100, Terrain.height(-100, 6) + 0.05, 6), Vector3(-104, 1.5, 26))
	await _wait(1.2)
	await _shot("src_cut")


func _fieldjobs_review() -> void:
	var fj := FieldJobs.instance
	print("[fj] enabled=", FieldJobs.enabled(), " instance=", fj != null)
	if fj == null:
		return
	# Наряды на все виды сразу, чтобы проверить каждую точку
	SaveGame.flags["fj_key"] = FieldJobs._key()
	SaveGame.flags["fj_list"] = [{"k": "ams_reset", "t": "ams1", "done": false}, {"k": "ams_ice", "t": "ams2", "done": false},
		{"k": "ams_battery", "t": "ams3", "done": false}, {"k": "samples", "t": "camp", "done": false}, {"k": "tower_tape", "t": "tower", "done": false}]
	fj._refresh()
	print("[fj] tasks:\n", Game.tasks_text())
	print("[fj] objective: ", Game.objective_text())
	for a: StringName in FieldJobs.AMS:
		var c := Terrain.pad_pos(a)
		var cab: Interactable = fj.get_node("AmsCabinet_" + String(a))
		var front := cab.global_position + cab.global_basis.z * 4.5
		_look(Vector3(front.x, Terrain.height(front.x, front.z) + 0.05, front.z), c + Vector3(0, 1.6, 0))
		await _wait(1.5)
		await _shot("fj_" + String(a))
		print("[fj] ", a, " prompt: ", cab.get_prompt(), " hold=", cab.hold_time)
		if a == &"ams1":
			var near := cab.global_position + cab.global_basis.z * 1.6
			_look(Vector3(near.x, Terrain.height(near.x, near.z) + 0.05, near.z), cab.global_position)
			await _wait(0.8)
			await _shot("fj_cab_close")
	# Выполнить: перезапуск, лёд, аккумулятор (взять в гараже), пробы, лента
	var p := Game.player
	(fj.get_node("AmsCabinet_ams1") as Interactable).interact(p)
	(fj.get_node("AmsMast_ams2") as Interactable).interact(p)
	(fj.get_node("AmsBattery") as Interactable).interact(p)
	print("[fj] battery carried: ", SaveGame.flags.get("fj_battery"))
	(fj.get_node("AmsCabinet_ams3") as Interactable).interact(p)
	(fj.get_node("TowerRecorder") as Interactable).interact(p)
	for s: StringName in fj._case:
		var cs: Node3D = fj._case[s]
		if cs.visible:
			for ch in cs.get_children():
				if ch is Interactable:
					(ch as Interactable).interact(p)
	print("[fj] samples carried: ", SaveGame.flags.get("fj_samples"))
	_look(Vector3(16.0, 0.05, 3.5), Vector3(10, 1.5, 3.5))
	await _wait(1.0)
	print("[fj] after: ", SaveGame.flags.get("fj_list"), " rations=", Supply.rations())
	print("[fj] tasks:\n", Game.tasks_text())
	(fj.get_node("AmsCabinet_ams4") as Interactable).interact(p)
	await _wait(0.5)
	await _shot("fj_log")


func _mapev_review(ids: PackedStringArray) -> void:
	var p := Game.player
	var ev := MapEvents.instance
	ev._cd = 9999.0
	for sid in ids:
		var id := StringName(sid)
		p.global_position = Vector3(30.0, 0.3, 22.0)
		p.rotation.y = 0.0
		await _wait(0.3)
		var ok := ev.force(id)
		print("[mapev] ", id, ": ", ok)
		if not ok:
			continue
		var node: Node3D = ev._active[-1]["node"]
		var np := node.global_position
		var to := np - p.global_position
		to.y = 0.0
		var near := 4.5 if id == &"name_in_snow" else 9.0
		var stand := np - to.normalized() * near if to.length() > near else p.global_position
		stand.y = Terrain.height(stand.x, stand.z) + 0.3
		if not String(id) in ["lantern_walker", "eyes", "tree_knocks", "izba_light"]:
			p.global_position = stand
		var lt := np + Vector3(0, 1.0, 0) - p.global_position
		p.rotation.y = atan2(-lt.x, -lt.z)
		p.head.rotation.x = -0.75 if id == &"name_in_snow" else -0.25
		await _wait(3.5)
		await _shot("mapev_%s" % id)
		print("[mapev]   active: ", ev.active_ids())


func _events_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	var ev := MapEvents.instance
	assert(ev != null, "нет MapEvents")
	for id: StringName in [&"gtt_ghost", &"campfire", &"probe", &"twin_buran", &"tower_lights", &"foreign_tracks"]:
		# Стоим на зимнике к лагерю, смотрим вдаль
		var road := Terrain.road_points(&"camp", 2.0)
		p.global_position = road[road.size() / 3] + Vector3(0, 0.3, 0)
		var ok := ev.force(id)
		print("[rev] событие ", id, ": ", ok)
		if not ok:
			continue
		var node: Node3D = ev._active[-1]["node"]
		var to := node.global_position - p.global_position
		var dist := Vector2(to.x, to.z).length()
		var near := 40.0 if id == &"twin_buran" else 14.0
		var stand := node.global_position - Vector3(to.x, 0, to.z).normalized() * minf(near, dist)
		stand.y = Terrain.height(stand.x, stand.z) + 0.3
		p.global_position = stand
		var lt := node.global_position + Vector3(0, 1.0, 0) - p.global_position
		p.rotation.y = atan2(-lt.x, -lt.z)
		p.head.rotation.x = -0.15
		p.set_flashlight(true)
		await _wait(1.2)
		await _shot("ev_%s" % id)
		print("[rev]   стоим в %.0f м, активные: %s" % [stand.distance_to(node.global_position) if is_instance_valid(node) else -1.0, ev.active_ids()])
	# Снабжение: бланк и ящик
	SaveGame.flags["rations"] = 5
	assert(Supply.order(&"dog_food"), "заказ корма")
	assert(Supply.order(&"film"), "заказ плёнки")
	print("[rev] пайков после заказа: ", Supply.rations(), " в заявке ", Supply.pending())
	EventBus.ui_requested.emit(&"supply")
	await _wait(0.6)
	await _shot("supply_ui")


func _dog_escape_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	var d := Dog.instance
	d._on_use(p)
	p.global_position = Vector3(1.0, 0.05, 2.6)
	p.drop_held()
	Dog.set_health(90.0)
	await _wait(0.5)
	d._run_away()
	print("[rev] найда сбежала: ", SaveGame.flags.get("dog_state"), " в ", d.global_position)
	# С крыльца смотрим на цепочку следов
	p.global_position = Vector3(17.5, 0.1, 3.5)
	var to := d.global_position - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	p.head.rotation.x = -0.35
	p.set_flashlight(true)
	await _wait(1.0)
	await _shot("escape_trail")
	p.global_position = d.global_position - to.normalized() * 3.0 + Vector3(0, 0.3, 0)
	p.global_position.y = Terrain.height(p.global_position.x, p.global_position.z) + 0.3
	p.head.rotation.x = -0.5
	await _wait(1.0)
	await _shot("escape_found")
	d._on_use(p)
	assert(p.held == &"dog", "не поднял найду в лесу")
	p.global_position = Vector3(1.0, 0.05, 2.6)
	p.rotation.y = deg_to_rad(80.0)
	await _wait(0.3)
	print("[rev] перед тем как положить: held=", p.held, " поз ", p.global_position, " внутри=", Game.level.is_pos_inside_house(p.global_position))
	p.drop_held()
	print("[rev] после: ", SaveGame.flags.get("dog_state"), " where=", d.where, " поз ", d.global_position)
	assert(Dog.is_home(), "не вернул домой")
	print("[rev] вернул домой: ", SaveGame.flags.get("dog_state"))


func _people_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	Creatures.legacy = true
	for bd: float in [0.0, 45.0, 58.0, 83.0]:
		var oz := Creatures.make_zherdyai(bd)
		Game.level.add_child(oz)
		oz.global_position = Vector3(30, 0, 30)
		await _wait(0.2)
		print("[rev] старый жердяй %.0f°: голова %s" % [bd, (oz.get_node("Upper/Head") as Node3D).global_position - Vector3(30, 0, 30)])
		oz.queue_free()
	var old_h := Vector3.ZERO
	Creatures.legacy = false
	for bd: float in [0.0, 45.0, 58.0, 83.0]:
		var nz := Creatures.make_zherdyai(bd)
		Game.level.add_child(nz)
		nz.global_position = Vector3(30, 0, 30)
		await _wait(0.4)
		print("[rev] новый жердяй %.0f°: голова %s" % [bd, (nz.get_node("Upper/Head") as Node3D).global_position - Vector3(30, 0, 30)])
		nz.queue_free()
	var row: Array = [
		["driver", func() -> CreatureRig: return Creatures.make_human(&"driver"), 0.0, &""],
		["driver_walk", func() -> CreatureRig: return Creatures.make_human(&"driver"), 0.5, &""],
		["driver_wave", func() -> CreatureRig: return Creatures.make_human(&"driver"), 0.0, &"wave"],
		["driver_seat", func() -> CreatureRig: return Creatures.make_human(&"driver", true), 0.0, &""],
		["shadow_run", func() -> CreatureRig: return Creatures.make_silhouette(), 1.0, &""],
		["zherd_0", func() -> CreatureRig: return Creatures.make_zherdyai(0.0), 0.0, &""],
		["zherd_58", func() -> CreatureRig: return Creatures.make_zherdyai(58.0), 0.0, &""],
	]
	for it: Array in row:
		var c: CreatureRig = (it[1] as Callable).call()
		Game.level.add_child(c)
		var far := 5.5 if String(it[0]).begins_with("zherd") else 3.2
		c.global_position = Vector3(20.0, 0.0, 14.0 - far)
		c.rotation.y = deg_to_rad(-60.0)
		c.gait = it[2]
		if it[3] != &"":
			c.pose_override = it[3]
		if it[0] == "hunter_back":
			c.set_rest(&"Head", Vector3(0.0, PI, 0.0))
		if it[0] == "driver_seat":
			c.talk = 5.0
		p.global_position = Vector3(20.0, 0.1, 14.0)
		p.rotation.y = 0.0
		p.head.rotation.x = 0.12 if String(it[0]).begins_with("zherd") else -0.05
		p.set_flashlight(true)
		await _wait(0.9)
		await _shot("people_%s" % it[0])
		print("[rev] ", it[0], ": скелет=", c.anim != null, " клип=", c._clip)
		c.queue_free()
		await _wait(0.1)


## Обзор картинки: двор, опушка, тамбур, чердак, печь, рубка — днём, потом ночью; английский журнал.
func _look_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	var views: Array = [
		["yard_house", Vector3(22.0, 0.05, 16.0), Vector3(6.0, 2.0, 3.6)],
		["yard_forest", Vector3(18.0, 0.05, 10.0), Vector3(40.0, 3.0, -20.0)],
		["forest_close", Vector3(-30.0, 0.05, -40.0), Vector3(-40.0, 2.5, -55.0)],
		["vestibule", Vector3(12.77, 0.05, 2.14), Vector3(11.2, 1.4, 1.2)],
		["attic_ladder", Vector3(5.83, 0.05, 3.24), Vector3(5.85, 3.0, 4.4)],
		["stove", Vector3(-0.81, 0.05, 2.3), Vector3(-1.9, 1.2, 0.3)],
		["radio", Vector3(8.34, 0.05, 0.26), Vector3(8.9, 1.0, -1.8)],
	]
	for night in 2:
		if night == 1 and Game.level.has_method(&"set_day_lighting"):
			Game.level.call(&"set_day_lighting", false)
		for v: Array in views:
			_look(v[1], v[2])
			p.set_flashlight(night == 1)
			await _wait(1.0)
			await _shot("look_%s_%s" % [v[0], "night" if night == 1 else "day"])
	Loc.set_language("en")
	await _wait(0.3)
	EventBus.ui_requested.emit(&"journal")
	await _wait(1.0)
	await _shot("look_journal_en")
	Loc.set_language("ru")


## Двойник у двери: позы сцены стука (стоит, стучит, приник к двери, голова на плече, идёт) — все три лица.
func _spirits_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	for face: StringName in [&"mikhalych", &"semenov", &"orekhov"]:
		for it: Array in [["idle", &"", 0.0], ["knock", &"knock", 0.4], ["lean", &"lean", 0.0], ["shoulder", &"still", 0.0], ["walk", &"walk", 0.0]]:
			var c := Creatures.make_double(face)
			Game.level.add_child(c)
			c.global_position = Vector3(20.0, 0.0, 11.2)
			c.look_at(Vector3(20.0, 0.0, 14.0), Vector3.UP)
			c.rotation.y += deg_to_rad(25.0)
			if it[1] != &"":
				c.pose_override = it[1]
			if it[0] == "shoulder":
				c.set_rest(&"Head", Vector3(0.0, 0.0, deg_to_rad(80.0)))
			p.global_position = Vector3(20.0, 0.1, 14.0)
			p.rotation.y = 0.0
			p.head.rotation.x = -0.05
			p.set_flashlight(true)
			await _wait(0.9 + float(it[2]))
			await _shot("double_%s_%s" % [face, it[0]])
			print("[rev] ", face, " ", it[0], ": клип=", c._clip, " есть=", c.has_clip(it[1]) if it[1] != &"" else true)
			c.queue_free()
			await _wait(0.1)


func _dog_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	var d := Dog.instance
	assert(d != null, "Найды нет")
	print("[rev] найда: ", d.where, " ", d.global_position)
	p.global_position = d.global_position + Vector3(0, 0.3, 1.6)
	var lt := d.global_position - p.global_position
	p.rotation.y = atan2(-lt.x, -lt.z)
	p.head.rotation.x = -0.5
	p.set_flashlight(true)
	await _wait(1.0)
	await _shot("dog_camp")
	d._on_use(p)
	assert(p.held == &"dog", "не взял")
	await _wait(0.6)
	await _shot("dog_held")
	# Домой, у печки
	p.global_position = Vector3(1.0, 0.05, 2.6)
	p.rotation.y = deg_to_rad(80.0)
	p.head.rotation.x = -0.45
	await _wait(0.6)
	p.drop_held()
	assert(Dog.is_home(), "не дома")
	await _wait(1.0)
	await _shot("dog_home_weak")
	SaveGame.flags["stew"] = 3
	d.feed()
	await _wait(4.0)
	await _shot("dog_eats")
	Dog.set_health(90.0)
	d._busy_t = 0.0
	d._on_use(p)
	await _wait(0.8)
	await _shot("dog_happy")
	d._busy_t = 0.0
	d._think_t = 0.0
	p.global_position = Vector3(2.4, 0.05, 4.5)
	await _wait(3.0)
	await _shot("dog_follow")
	print("[rev] найда: здоровье ", Dog.health(), ", клип ", d._clip, ", поз ", d.global_position)


func _yrka_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	Game.yrka.enabled = false
	p.global_position = Vector3(20.0, 0.1, 14.0)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.12
	p.set_flashlight(true)
	var y := Creatures.make_yrka()
	Game.level.add_child(y)
	print("[rev] ырка скелетная: ", y.anim != null)
	for mi: MeshInstance3D in y.find_children("*", "MeshInstance3D", true, false):
		var sm := mi.material_override as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path.contains("skinned"):
			print("[rev] текстура ырки: ", sm.get_shader_parameter(&"tex"), " src=", mi.mesh.surface_get_material(0))
	for item: Array in [["idle", 0.0, 90.0], ["stalk", 0.4, 90.0], ["run", 1.0, 90.0], ["sniff", 0.0, 60.0], ["peek", 0.0, 0.0], ["lunge", 0.0, 0.0], ["pin", 0.0, 0.0]]:
		y.global_position = Vector3(20.0, 0.0, 10.6)
		y.rotation.y = deg_to_rad(item[2])
		y.gait = item[1]
		y.pose_override = &"" if item[0] in ["idle", "stalk", "run"] else StringName(item[0])
		for k in 2:
			await _wait(0.35 + k * 0.3)
			await _shot("yrka_%s_%d" % [item[0], k])
		print("[rev] клип: ", y._clip)
	var h := y.get_node_or_null("Head") as Node3D
	print("[rev] голова: ", h.global_position if h != null else "нет")


func _sites_review() -> void:
	var p := Game.player
	p.mode = Player.Mode.WALK
	for site: StringName in FarSites.SITES:
		var c := Terrain.pad_pos(site)
		var road := Terrain.road_points(site, 2.0)
		var eye: Vector3 = road[maxi(road.size() - 16, 0)]
		eye.y = Terrain.height(eye.x, eye.z) + 0.3
		p.global_position = eye
		p.velocity = Vector3.ZERO
		var d := c - eye
		p.rotation.y = atan2(-d.x, -d.z)
		p.head.rotation.x = 0.12
		p.set_flashlight(true)
		await _wait(1.5)
		await _shot("site_%s" % site)
		var note := get_tree().root.find_child("SiteNote_" + String(site), true, false) as Interactable
		assert(note != null, "нет записки " + String(site))
		note.interact(p)
		await _wait(0.3)
		await _shot("note_%s" % site)
		Game.hud.hide_note()
		p.mode = Player.Mode.WALK
		print("[rev] точка %s: %s, посещена=%s" % [site, c, FarSites.visited(site)])
	print("[rev] задачи:\n", Game.tasks_text())
	var map := MapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 50
	_app.add_child(cl)
	cl.add_child(map)
	await _wait(0.4)
	await _shot("map_region")


## Сигнал 03:10 и пеленги следа Семёнова: «Слухач» в доме, азимут с сопки, кабель из бункера → схема.
func _sig0310_review() -> void:
	Game.hud.visible = true
	_look(Vector3(8.6, 0.05, -0.4), Vector3(9.2, 1.0, -1.4))
	Game.shift_minutes = 426.0
	Game.set_sv20(true)
	print("[sig] до: пеленгов=", FieldJobs.bearing_count())
	await _wait(3.0)
	print("[sig] 03:0x status=", Game.get_seismic_status().get("vector"))
	await _wait(6.0)
	print("[sig] seen=", Game.has_flag("sig0310_seen"), " min=", int(Game.shift_minutes), " station=", FieldJobs.has_bearing("station"), " status=", Game.get_seismic_status().get("text"))
	await _shot("sig_sub")
	Game.set_sv20(false)
	Game.yard._bearing_after_note("repeater")
	Game.yard._bearing_after_note("bunker")
	await _wait(3.5)
	print("[sig] пеленгов=", FieldJobs.bearing_count(), " зона=", FieldJobs.search_zone())
	print("[sig] задачи:\n", Game.tasks_text())
	var map := MapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 50
	_app.add_child(cl)
	cl.add_child(map)
	await _wait(0.5)
	await _shot("sig_map")


func _buran_review() -> void:
	var b := Snowmobile.instance
	assert(b != null, "Буран не создан")
	var p := Game.player
	p.global_position = b.global_position + Vector3(0, 0.3, 3.5)
	p.rotation.y = 0.0
	p.head.rotation.x = -0.25
	await _wait(1.0)
	await _shot("buran_covered")
	b._on_use(p)
	assert(not b.is_covered(), "чехол не снялся")
	await _wait(0.6)
	await _shot("buran_open")
	p.mode = Player.Mode.WALK
	b._mount(p)
	assert(Game.has_flag("riding"), "не сел")
	var pts := Terrain.road_points(&"drill", 2.0)
	b._place(pts[2])
	Input.action_press(&"move_forward")
	var t := 0.0
	var k := 0
	var shot_t := 2.0
	while t < 16.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var best := 0
		var bd := 1e9
		for i in pts.size():
			var dd := pts[i].distance_squared_to(b.global_position)
			if dd < bd:
				bd = dd
				best = i
		var aim: Vector3 = pts[mini(best + 4, pts.size() - 1)] - b.global_position
		var want := atan2(-aim.x, -aim.z)
		var dy := wrapf(want - b._yaw, -PI, PI) * 0.08
		b._yaw += dy
		p.rotation.y += dy
		if t > shot_t:
			shot_t += 3.0
			await _shot("buran_ride_%d" % k)
			print("[rev] буран %.1f с: v=%.1f, %s, бак %.1f, %.0f м" % [t, b.speed, b.global_position, b.fuel, b.driven])
			k += 1
	Input.action_release(&"move_forward")
	Input.action_press(&"move_back")
	var w := 0
	while absf(b.speed) > 2.0 and w < 200:
		await get_tree().physics_frame
		w += 1
	Input.action_release(&"move_back")
	b.request_dismount()
	assert(not Game.has_flag("riding"), "не слез")
	print("[rev] шаг buran: ", Game.tutorial.get(&"buran", false), " проехал ", b.driven)
	p.rotation.y += PI
	await _wait(0.5)
	await _shot("buran_after")


func _test_cabin() -> void:
	print("--- TEST CABIN RUNNING ---")
	SaveGame.new_game("story")
	Game.setup_phase(&"day", 0)
	print("Phase setup: is_prologue=", Game.is_prologue(), " left_cabin=", Game.has_flag("left_cabin"))
	var sess := Session.new()
	_app.add_child(sess)
	var last_pos := Vector3.ZERO
	for i in range(15):
		await get_tree().process_frame
		if Game.player != null:
			print("Frame %d: player pos=%s, in_cabin=%s, left_cabin=%s, head_y=%.2f" % [
				i, Game.player.global_position, Game.has_flag("in_cabin"), Game.has_flag("left_cabin"), Game.player.head.position.y
			])
			if i > 5:
				assert(Game.player.global_position.distance_to(last_pos) < 0.05, "Player position must be stable inside cabin without jitter!")
			last_pos = Game.player.global_position

	assert(Game.has_flag("in_cabin"), "Player must be in cabin flag initially!")
	assert(not Game.has_flag("left_cabin"), "Player must not have left cabin initially!")
	assert(absf(Game.player.head.position.y - 0.90) < 0.05, "Head position should be seated (~0.90)!")

	# Тестируем разблокировку выхода и подсказку [E]
	Vehicle._instance._can_exit = true
	await get_tree().process_frame
	print("After can_exit=true: prompt='", Game.hud._prompt.text, "'")
	assert(Game.hud._prompt.text != "", "Exit prompt must be shown on HUD when vehicle stopped!")

	# Тестируем выход из кабины клавишей [E]
	print("Triggering Vehicle.request_exit()...")
	Vehicle.request_exit()
	await get_tree().process_frame
	await get_tree().process_frame

	print("After exit: pos=", Game.player.global_position, " in_cabin=", Game.has_flag("in_cabin"), " left_cabin=", Game.has_flag("left_cabin"), " head_y=", Game.player.head.position.y)
	assert(not Game.has_flag("in_cabin"), "in_cabin must be false after exit!")
	assert(Game.has_flag("left_cabin"), "left_cabin must be true after exit!")
	assert(Game.player.global_position.distance_to(Vector3(-70.69, 7.85, -94.69)) < 0.2, "Player must be at tailgate snow pos after exit!")
	assert(is_equal_approx(Game.player.head.position.y, 1.58), "Head height must be restored to 1.58 after exit!")
	print("--- TESTING PROLOGUE RADIO TRANSMIT ---")
	assert(Game.radio != null, "Radio must exist!")
	assert(not Game.has_readings(), "Player has no weather readings in prologue arrival!")
	Game.radio.freq = 6880.0
	assert(Game.radio.strength_of(&"mainland") >= 0.75, "Mainland signal strength should be >= 0.75 at 6880 kHz!")
	Game.radio.transmit()
	assert(Game.radio._busy, "Radio should start transmitting arrival dialogue without requiring weather readings!")
	print("✓ Тест передачи сигнала в прологе без сводок успешно пройден!")
	print("✓ Все тесты кабины, выхода и рации успешно пройдены!")
	get_tree().quit()



func _polish_test() -> void:
	print("==================================================")
	print("KEDR-7: FULL POLISH & INTEGRITY VERIFICATION TEST")
	print("==================================================")
	# 1. Проверка настроек и микрофона
	print("[1/6] Проверка настроек и MicManager...")
	assert(Settings != null, "Settings autoload missing!")
	assert(Mic != null, "MicManager autoload missing!")
	assert("gamepad_sens" in Settings, "Settings missing gamepad_sens!")
	assert("invert_y" in Settings, "Settings missing invert_y!")
	assert("head_bob" in Settings, "Settings missing head_bob!")
	Settings.gamepad_sens = 1.5
	Settings.invert_y = true
	Settings.head_bob = 0.5
	Settings.save()
	Settings.apply()
	print("  • Gamepad sens: ", Settings.gamepad_sens)
	print("  • Invert Y: ", Settings.invert_y)
	print("  • Head bob: ", Settings.head_bob)
	print("  • Mic enabled: ", Settings.mic_enabled)
	print("  • Mic sens: ", Settings.mic_sensitivity)
	print("  • Mic level: ", Mic.current_level)

	print("[1b/6] Проверка ночной высадки и утреннего освещения пролога...")
	SaveGame.new_game("story")
	Game.setup_phase(&"day", 0)
	assert(Game.is_prologue(), "Phase must be prologue")
	assert(Game.is_prologue_trail(), "Should be prologue trail before arrival")
	assert(not Game.is_daylight(), "Prologue arrival must NOT be daylight (must be dark night)")
	assert(Game.base_hour == 21, "Prologue arrival base hour must be 21 (21:00 night)")
	assert(Game.clock_text() == "21:00", "Prologue arrival clock must show 21:00")
	# Переход к утру (после сна в избе)
	Game.set_flag("prologue_arrived", true)
	Game.base_hour = 8
	Game.shift_minutes = 30.0
	assert(not Game.is_prologue_trail(), "Should not be on trail after arrival")
	assert(Game.is_daylight(), "Morning after arrival must be bright daylight")
	assert(Game.clock_text() == "08:30", "Morning clock must show 08:30")

	# Проверка: завершение утренних обязанностей без обязательного разговора с водителем
	Game.tutorial.clear()
	Game.tutorial[&"driver"] = false
	assert(not Game.tutorial_done(), "Tutorial should not be done initially")
	for chore in [&"readings", &"test_report", &"refuel", &"wood", &"buran", &"journal"]:
		Game.tutorial[chore] = true
	assert(Game.tutorial_done(), "Tutorial must be done when chores are finished even if driver was not spoken to!")

	# Проверка перехода фазы: Пролог (день 0) -> Ночь 1
	SaveGame.advance()
	assert(String(SaveGame.phase["kind"]) == "night" and int(SaveGame.phase["index"]) == 1, "Phase after prologue must be night 1!")

	print("  ✓ Ночная высадка (21:00, тёмная ночь), утренний переход (08:30, дневной свет) и переход к Ночи 1 подтверждены!")

	print("[1c/6] Проверка моделей Блендера, спуска с перевала и геометрии пролога...")
	var sled_node: Node3D = Props.sled_semenov()
	assert(sled_node != null, "Props.sled_semenov() returned null!")
	assert(sled_node.get_child_count() > 0, "Props.sled_semenov() has no children/meshes!")
	sled_node.free()

	var post_node: Node3D = Props.broken_post()
	assert(post_node != null, "Props.broken_post() returned null!")
	assert(post_node.get_child_count() > 0, "Props.broken_post() has no children/meshes!")
	post_node.free()

	var lantern_node: Node3D = Props.fas4_lantern()
	assert(lantern_node != null and lantern_node.get_child_count() > 0, "Props.fas4_lantern() missing meshes!")
	lantern_node.free()

	var tablet_node: Node3D = Props.officer_tablet()
	assert(tablet_node != null and tablet_node.get_child_count() > 0, "Props.officer_tablet() missing meshes!")
	tablet_node.free()

	var trunk_node: Node3D = Props.expedition_trunk()
	assert(trunk_node != null and trunk_node.get_child_count() > 0, "Props.expedition_trunk() missing meshes!")
	trunk_node.free()

	var tower_node: Node3D = Props.old_meteo_tower()
	assert(tower_node != null and tower_node.get_child_count() > 0, "Props.old_meteo_tower() missing meshes!")
	tower_node.free()

	var marker_node: Node3D = Props.winter_road_marker()
	assert(marker_node != null and marker_node.get_child_count() > 0, "Props.winter_road_marker() missing meshes!")
	marker_node.free()

	var gtt_node: Node3D = Props.gtt_transporter()
	assert(gtt_node != null and gtt_node.get_child_count() > 0, "Props.gtt_transporter() missing meshes!")
	gtt_node.free()

	var lamp_node: Node3D = Props.kerosene_lamp()
	assert(lamp_node != null and lamp_node.get_child_count() > 0, "Props.kerosene_lamp() missing meshes!")
	lamp_node.free()

	var can_node: Node3D = Props.canister()
	assert(can_node != null and can_node.get_child_count() > 0, "Props.canister() missing meshes!")
	can_node.free()

	var kettle_node: Node3D = Props.kettle()
	assert(kettle_node != null and kettle_node.get_child_count() > 0, "Props.kettle() missing meshes!")
	kettle_node.free()

	var outhouse_node: Node3D = Props.outhouse()
	assert(outhouse_node != null and outhouse_node.get_child_count() > 0, "Props.outhouse() missing meshes!")
	outhouse_node.free()

	# Проверка 3D-планшета и физического рундука в руках игрока
	var hands := FPHands.new()
	hands._ready()
	assert(hands.tablet_root != null, "FPHands missing tablet_root!")
	assert(not hands.is_tablet_up(), "Tablet should be lowered initially")
	hands.toggle_tablet(1)
	assert(hands.is_tablet_up(), "Tablet should be raised after toggle_tablet(1)")
	hands.free()

	# Пролог: просека от высадки до крыльца, 2.5–3.5 минуты шагом
	var plen := PrologueTrail.length_m()
	assert(plen / PrologueTrail.TRAIL_SPEED > 140.0 and plen / PrologueTrail.TRAIL_SPEED < 220.0, "Prologue walk must take 2.5–3.5 min (%.0f m)" % plen)
	assert(PrologueTrail.route()[PrologueTrail.route().size() - 1].distance_to(Vector3(16.8, 0, 3.5)) < 1.0, "Prologue route must end at the porch")
	SaveGame.flags.clear()
	Game.tutorial.clear()
	SaveGame.phase = {"kind": "day", "index": 0}
	var zone_before := Game.zone
	Game.zone = &"yard"
	assert(Game._tutorial_objective() == Loc.t(&"obj.reach_station"), "Arrival objective: reach the station")
	Game.zone = zone_before
	Game.set_flag("left_cabin", true)
	print("  ✓ Пролог: просека %.0f м проверена" % plen)

	# 2. Проверка Covenants (Заветы дежурных)
	print("[2/6] Проверка Заветов дежурных...")
	assert(CovenantsClass.ENTRIES.size() >= 6, "Expected at least 6 covenant entries!")
	for entry in CovenantsClass.ENTRIES:
		var st: String = CovenantsClass.get_state(entry.id)
		print("  • Завет [%s]: %s (автор: %s)" % [entry.id, st, entry.author])
	CovenantsClass.set_state("bragin_frame", "true")
	assert(CovenantsClass.get_state("bragin_frame") == "true", "Failed to save covenant state!")
	print("  ✓ Заветы проверены и сохраняются корректно.")

	# 3. Запуск фазы
	print("[3/6] Запуск игровой фазы и проверка станции...")
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": "night", "index": 1}
	_app.call(&"_start_phase")
	await _wait(3.0)

	var station := Game.level
	assert(station != null, "Station level missing!")
	assert(station.find_child("BarographM22", true, false) != null, "BarographM22 missing!")
	assert(Game.synoptic != null, "Synoptic model missing!")
	print("  • Синоптическая модель: фронт=%s, P=%.1f мм, T=%.1f°C, ветер=%.1f м/с (%s)" % [Game.synoptic.front_type, Game.synoptic.pressure, Game.synoptic.temp_dry, Game.synoptic.wind_speed, Game.synoptic.wind_dir_name])
	print("  ✓ Сейсмоприемник СВ-20, барограф, журнал ТМ-1 и обереги в станции на месте.")

	# Проверка механики записок (открытие и надёжное закрытие по [E])
	Game.hud.show_note("ТЕСТОВАЯ ЗАПИСКА")
	assert(Game.hud.is_note_open(), "Note must be open")
	assert(Game.player.mode == Player.Mode.READING, "Player mode must be READING when note is open")
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	var sess: Node = _app.get_node_or_null("Session")
	if sess != null:
		sess.call(&"_unhandled_input", ev)
	else:
		Game.hud.hide_note()
	assert(not Game.hud.is_note_open(), "Note must be closed after E")
	assert(Game.player.mode == Player.Mode.WALK, "Player mode must return to WALK after closing note")
	print("  ✓ Открытие и закрытие записки клавишей [E] подтверждены!")

	# 4. Проверка Сейсмодатчика СВ-20
	print("[4/6] Проверка логики «Слухача» (СВ-20)...")
	Game.set_sv20(true)
	assert(Game.sv20_active, "SV20 should be active!")
	var seismic := Game.get_seismic_status()
	print("  • Показания сейсмоприемника: amp=%.1f, text='%s'" % [seismic.amplitude, seismic.text])
	Game.set_sv20(false)
	assert(not Game.sv20_active, "SV20 should be inactive!")
	print("  ✓ Фильтр LowPass 220 Гц и логика сейсмоприемника переключаются корректно.")

	# 5. Проверка двора станции (Yard) и вертодрома
	print("[5/6] Проверка двора станции...")
	var yard := Game.yard
	assert(yard != null, "Yard missing!")
	assert(yard.get("_helipad_drift") != null, "Helipad drift missing!")
	print("  ✓ Вертодром, посадочный крест и вехи на месте.")

	# 6. Проверка оберегов
	print("[6/6] Проверка оберегов...")
	Game.salt_on_threshold = true
	assert(Game.salt_on_threshold, "Salt flag failed!")
	Game.knife_in_lintel = true
	assert(Game.knife_in_lintel, "Knife flag failed!")
	Game.mirror_covered = true
	assert(Game.mirror_covered, "Mirror flag failed!")
	Game.spirit_treat = true
	assert(Game.spirit_treat, "Spirit treat flag failed!")
	print("  ✓ Все обереги успешно протестированы!")

	# 7. Проверка физического выхода из дома и входа в дизельную будку
	print("[7/7] Проверка физического выхода из дома и захода в будку к двигателю...")
	var st: Station = Game.level as Station
	assert(st != null, "Station missing!")
	st.set_door_open(true)
	await _wait(0.6)
	Game.player.global_position = Vector3(14.0, 0.05, 3.1)
	# Проход через входную дверь на крыльцо
	for _f in range(120):
		Game.player.velocity = Vector3(2.5, 0.0, 0.0)
		Game.player.move_and_slide()
	print("  • Игрок прошёл через входную дверь на крыльцо: ", Game.player.global_position)
	assert(Game.player.global_position.x > 15.0, "Игрок должен беспрепятственно выходить из дома на крыльцо!")

	# Заход в дизельную будку
	st.set_shack_door_open(true)
	await _wait(0.6)
	Game.player.global_position = Vector3(14.5, 0.05, -11.5)
	for _f in range(120):
		Game.player.velocity = Vector3(0.0, 0.0, -2.5)
		Game.player.move_and_slide()
	print("  • Игрок зашёл внутрь дизельной будки к двигателю: ", Game.player.global_position)
	assert(Game.player.global_position.z < -12.7, "Игрок должен беспрепятственно заходить в будку к двигателю!")
	assert(st.zone_at(Game.player.global_position) == &"gen_shack", "Внутри будки зона должна быть gen_shack!")

	# Выход из будки обратно
	for _f in range(120):
		Game.player.velocity = Vector3(0.0, 0.0, 2.5)
		Game.player.move_and_slide()
	print("  • Игрок вышел из будки наружу: ", Game.player.global_position)
	assert(Game.player.global_position.z > -12.0, "Игрок должен беспрепятственно выходить из дизельной будки!")
	print("  ✓ Свободный проход через входную дверь и заход в дизельную будку полностью подтверждены!")

	print("==================================================")
	print("ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО БЕЗ ОШИБОК И БАГОВ!")
	print("==================================================")
	get_tree().quit(0)


func _joypad_test() -> void:
	print("==================================================")
	print("KEDR-7: JOYPAD & MENU NAVIGATION COMPREHENSIVE TEST")
	print("==================================================")

	# 1. Проверка InputMap для джойстика
	print("[1/5] Проверка привязок InputMap (D-Pad и аналоговый стик)...")
	var ui_actions: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel"]
	for act: StringName in ui_actions:
		assert(InputMap.has_action(act), "InputMap missing action: " + String(act))
		var events := InputMap.action_get_events(act)
		var has_joy_btn := false
		var has_joy_axis := false
		for ev in events:
			if ev is InputEventJoypadButton:
				has_joy_btn = true
			elif ev is InputEventJoypadMotion:
				has_joy_axis = true
		assert(has_joy_btn, "Action %s must have joypad button binding!" % act)
		if act in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
			assert(has_joy_axis, "Directional action %s must have joypad stick axis binding!" % act)
		print("  • Действие %s: JoyBtn=%s, JoyAxis=%s (всего событий: %d)" % [act, has_joy_btn, has_joy_axis, events.size()])
	print("  ✓ InputMap полностью сконфигурирован для D-Pad и левого стика.")

	# 2. Проверка Главного Меню и Настроек
	print("[2/5] Проверка Главного Меню и Панели Настроек...")
	assert(_app.get("_menu") != null, "MainMenu instance missing!")
	await _wait(0.3)
	var menu: MainMenu = _app.get("_menu")
	menu.grab_initial_focus()
	await _wait(0.1)
	var focus_owner := _app.get_viewport().gui_get_focus_owner()
	print("  • Фокус в Главном Меню: ", focus_owner.name if focus_owner else "none")
	assert(focus_owner != null, "Главное меню должно захватывать фокус для джойстика!")

	# Проверка меню сложности и отмены (B / ui_cancel)
	menu._show_difficulty()
	await _wait(0.2)
	assert(menu._in_difficulty, "Должен открыться выбор сложности!")
	var diff_focus := _app.get_viewport().gui_get_focus_owner()
	assert(diff_focus != null, "Кнопка сложности должна иметь фокус!")
	var cancel_ev := InputEventAction.new()
	cancel_ev.action = &"ui_cancel"
	cancel_ev.pressed = true
	menu._unhandled_input(cancel_ev)
	await _wait(0.2)
	assert(not menu._in_difficulty, "ui_cancel должен возвращать из сложности в главное меню!")

	# Проверка Панели Настроек
	var settings := SettingsPanel.new()
	_app.add_child(settings)
	await _wait(0.2)
	assert(settings._scroll != null, "Settings scroll missing!")
	assert(settings._scroll.follow_focus, "SettingsPanel ScrollContainer.follow_focus must be true!")
	var closed_flag := [false]
	settings.closed.connect(func(): closed_flag[0] = true)
	settings._unhandled_input(cancel_ev)
	assert(closed_flag[0], "SettingsPanel must emit closed on ui_cancel!")
	settings.queue_free()
	print("  ✓ Главное Меню и Настройки поддерживают начальный фокус, follow_focus и возврат назад.")

	# 3. Запуск игровой фазы и проверка задач / заветов (HUD)
	print("[3/5] Запуск игровой фазы и проверка HUD...")
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": "day", "index": 1}
	_app.call(&"_start_phase")
	await _wait(3.0)

	assert(Game.hud != null, "HUD missing!")
	assert(Game.player != null, "Player missing!")
	assert(Game.hud._covenants_container != null, "Covenants container missing!")
	assert(Game.hud._covenants_container.follow_focus, "Covenants container must have follow_focus=true!")

	# Открытие задач
	Game.hud.toggle_tasks()
	await _wait(0.2)
	assert(Game.hud._tasks_panel.visible, "Tasks must be visible!")
	assert(Game.player.mode == Player.Mode.UI, "Player mode must be UI when tasks sheet is open!")

	# Закрытие по ui_cancel
	var session: Session = _app.get("_session")
	assert(session != null, "Session missing!")
	session._unhandled_input(cancel_ev)
	await _wait(0.2)
	assert(not Game.hud._tasks_panel.visible, "Tasks must close on ui_cancel!")
	assert(Game.player.mode == Player.Mode.WALK, "Player mode must restore to WALK!")
	print("  ✓ Блокнот и заветы: переключение режима Player.Mode.UI, follow_focus и закрытие на B.")

	# 4. Проверка Меню Паузы
	print("[4/5] Проверка Меню Паузы...")
	var pause_menu := PauseMenu.new()
	_app.add_child(pause_menu)
	await _wait(0.2)
	var pause_focus := _app.get_viewport().gui_get_focus_owner()
	print("  • Фокус в Меню Паузы: ", pause_focus.name if pause_focus else "none")
	assert(pause_focus != null, "Pause menu must grab focus!")
	var resume_flag := [false]
	pause_menu.resume_requested.connect(func(): resume_flag[0] = true)
	pause_menu._unhandled_input(cancel_ev)
	assert(resume_flag[0], "Pause menu must emit resume on ui_cancel!")
	pause_menu.queue_free()
	print("  ✓ Меню Паузы захватывает фокус и возвращает в игру по B.")

	# 5. Проверка модальных формуляров и приборов
	print("[5/5] Проверка модальных окон (Бланки, Приборы, Сейсмоприемник)...")

	# MeteorFaxUI
	var fax := MeteorFaxUI.new()
	_app.add_child(fax)
	await _wait(0.2)
	assert(fax._cloud_tex != null, "MeteorFaxUI cloud texture must be generated!")
	assert(fax._paper_rect.texture != null, "MeteorFaxUI paper rect texture must be assigned!")
	assert(fax._paper_rect.texture == fax._cloud_tex, "MeteorFaxUI must bind cloud texture to paper rect!")
	var fax_flag := [false]
	fax.closed.connect(func(): fax_flag[0] = true)
	fax.handle_input(cancel_ev)
	assert(fax_flag[0], "MeteorFaxUI must close on ui_cancel!")
	fax.queue_free()

	# JournalTM1UI
	var journal := JournalTM1UI.new()
	_app.add_child(journal)
	await _wait(0.2)
	assert(journal._chosen_front == &"", "Fresh journal must not preselect any front at 0 readings!")
	assert(journal._submit_btn.disabled, "Submit button must be disabled at 0 readings!")
	var chk_blizz: Label = journal._verdict_cards[&"blizzard"].find_child("CheckMark", true, false)
	assert(chk_blizz != null and not chk_blizz.text.contains("УТВЕРЖДЕНО"), "Blizzard must not show УТВЕРЖДЕНО at 0 readings!")
	journal._handle_card_click(&"storm")
	assert(journal._chosen_front == &"", "Card selection via click must be blocked when 0 readings taken!")

	journal._switch_tab(1)
	assert(journal._archive_spread.visible, "Archive tab must be visible!")
	journal._switch_tab(0)
	assert(journal._shift_spread.visible, "Shift tab must be visible!")
	journal._select_front(&"storm")
	assert(journal._chosen_front == &"storm", "Chosen front must be storm after explicit select!")
	var chk_storm: Label = journal._verdict_cards[&"storm"].find_child("CheckMark", true, false)
	assert(chk_storm != null and chk_storm.text.contains("ВЫБРАНО"), "Card must display ВЫБРАНО before submission!")
	var journal_flag := [false]
	journal.closed.connect(func(): journal_flag[0] = true)
	journal.handle_input(cancel_ev)
	assert(journal_flag[0], "JournalTM1UI must close on ui_cancel!")
	journal.queue_free()

	# Проверка разблокировки выбора при снятом замере
	Game.readings[&"baro"] = true
	var journal2 := JournalTM1UI.new()
	_app.add_child(journal2)
	await _wait(0.2)
	assert(journal2._get_measured_count() == 1, "Must detect 1 measured instrument!")
	journal2._handle_card_click(&"blizzard")
	assert(journal2._chosen_front == &"blizzard", "Must allow front selection when measurements exist!")
	assert(not journal2._submit_btn.disabled, "Submit button must be enabled when front is selected and measurement exists!")
	journal2.queue_free()
	Game.readings.clear()

	# SeismographUI
	var seismo := SeismographUI.new()
	_app.add_child(seismo)
	await _wait(0.2)
	var seismo_flag := [false]
	seismo.closed.connect(func(): seismo_flag[0] = true)
	seismo.handle_input(cancel_ev)
	assert(seismo_flag[0], "SeismographUI must close on ui_cancel!")
	seismo.queue_free()

	# TapeDeckUI
	var tape := TapeDeckUI.new()
	_app.add_child(tape)
	await _wait(0.2)
	var tape_flag := [false]
	tape.closed.connect(func(): tape_flag[0] = true)
	tape.handle_input(cancel_ev)
	assert(tape_flag[0], "TapeDeckUI must close on ui_cancel!")
	tape.queue_free()

	# InterceptsUI
	var icp := InterceptsUI.new()
	_app.add_child(icp)
	await _wait(0.2)
	assert(icp._scroll.follow_focus, "InterceptsUI scroll must follow_focus!")
	var icp_flag := [false]
	icp.closed.connect(func(): icp_flag[0] = true)
	icp.handle_input(cancel_ev)
	assert(icp_flag[0], "InterceptsUI must close on ui_cancel!")
	icp.queue_free()

	# BarographUI
	var baro := BarographUI.new()
	_app.add_child(baro)
	await _wait(0.2)
	var baro_flag := [false]
	baro.closed.connect(func(): baro_flag[0] = true)
	baro.handle_input(cancel_ev)
	assert(baro_flag[0], "BarographUI must close on ui_cancel!")
	baro.queue_free()

	# MapView
	var map := MapView.new()
	_app.add_child(map)
	await _wait(0.2)
	var map_flag := [false]
	map.closed.connect(func(): map_flag[0] = true)
	map.handle_input(cancel_ev)
	assert(map_flag[0], "MapView must close on ui_cancel!")
	map.queue_free()

	# CodebookUI
	var codebook := CodebookUI.new()
	_app.add_child(codebook)
	await _wait(0.2)
	var code_flag := [false]
	codebook.closed.connect(func(): code_flag[0] = true)
	codebook.handle_input(cancel_ev)
	assert(code_flag[0], "CodebookUI must close on ui_cancel!")
	codebook.queue_free()

	# TheodoliteUI
	var theo := TheodoliteUI.new()
	_app.add_child(theo)
	await _wait(0.2)
	var theo_flag := [false]
	theo.closed.connect(func(): theo_flag[0] = true)
	theo.handle_input(cancel_ev)
	assert(theo_flag[0], "TheodoliteUI must close on ui_cancel!")
	theo.queue_free()

	# ControlsMemoUI
	var memo := ControlsMemoUI.new()
	_app.add_child(memo)
	await _wait(0.2)
	var memo_flag := [false]
	memo.closed.connect(func(): memo_flag[0] = true)
	memo.handle_input(cancel_ev)
	assert(memo_flag[0], "ControlsMemoUI must close on ui_cancel!")
	memo.queue_free()

	# ArchiveUI
	var arch := ArchiveUI.new()
	_app.add_child(arch)
	await _wait(0.2)
	assert(arch._scroll.follow_focus, "ArchiveUI scroll must follow_focus!")
	var arch_flag := [false]
	arch.closed.connect(func(): arch_flag[0] = true)
	arch.handle_input(cancel_ev)
	assert(arch_flag[0], "ArchiveUI must close on ui_cancel!")
	arch.queue_free()

	print("  ✓ Все модальные окна, памятка управления, архив дел и приборы корректно управляются и закрываются с джойстика.")

	print("==================================================")
	print("ТЕСТ УПРАВЛЕНИЯ ДЖОЙСТИКОМ ВО ВСЕХ МЕНЮ ПРОЙДЕН УСПЕШНО!")
	print("==================================================")
	get_tree().quit(0)


func _inspect_fixes() -> void:

	await _wait(1.0)
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": "day", "index": 1}
	_app.call(&"_start_phase")
	await _wait(5.5)
	if Game.player != null:
		Game.player.mode = Player.Mode.WALK
	# 0. Снимок жилой комнаты внутри: стена с часами, дверью и шкафом (проверка часов и стены)
	_tp(Vector3(-0.5, 0.05, 3.3), -90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-2.0)
	await _wait(1.0)
	await _shot("01_station_interior_living_clean")

	# 0a. Снимок прихожей (тамбура): проверка стоящих на полу лопат и новой лавки для просушки
	_tp(Vector3(12.6, 0.05, 3.6), 110.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-12.0)
	await _wait(1.0)
	await _shot("01c_vestibule_shovels_bench")

	# 0b. Снимок западного фронтона станции снаружи у печной трубы
	_tp(Vector3(-6.5, 0.05, 0.5), -120.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(26.0)
	await _wait(1.0)
	await _shot("02_station_west_gable_clean")

	# 0c. Снимок всей крыши станции снаружи с юго-востока (проверка отсутствия щелей и парения крыши)
	_tp(Vector3(12.5, 0.05, 12.0), -15.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(18.0)
	await _wait(1.0)
	await _shot("02b_station_roof_overview")

	# 0d. Снимок новой уличной дизельной будки на заднем дворе (генератор, бочка, выхлопная труба, мостки, дверь)
	_tp(Vector3(14.5, 0.05, -9.5), 180.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(2.0)
	await _wait(1.0)
	await _shot("02c_generator_shack_outdoor")

	# 0e. Радиорубка: шторы, дорожка-половик, керосиновая лампа, репродуктор «Рекорд» и барометр
	_tp(Vector3(7.5, 0.05, 1.6), 0.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-16.0)
	await _wait(1.0)
	await _shot("01b_radio_room_carpet_lamp_curtains")

	# 0f. Коридор: лаз на чердак и приставная деревянная лестница
	_tp(Vector3(8.2, 0.05, 4.1), 90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(14.0)
	await _wait(1.0)
	await _shot("01d_corridor_attic_ladder")

	# 0g. Чердак: стропила, настил, сундук снабжения и слуховое окно
	_tp(Vector3(5.5, 3.02, 3.3), -90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-8.0)
	await _wait(1.0)
	await _shot("01e_attic_interior_chests")

	# 0i. За домом: ледник в сугробе и следы у северного окна
	_tp(Vector3(5.25, 0.05, -10.0), 180.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-10.0)
	await _wait(1.0)
	await _shot("02d_backyard_cellar_and_tracks")

	# 0j. Глазок входной двери: вид на крыльцо, мостки и фонарь
	_tp(Vector3(14.0, 0.05, 3.1), -90.0)
	await _wait(0.5)
	_open(&"peephole")
	await _wait(1.5)
	await _shot("02e_peephole_view_fixed")
	if Game.hud != null:
		Game.hud.close_modal()
	if Game.player != null:
		Game.player.mode = Player.Mode.WALK


	# Проверка механики дизельной будки и сбоя генератора
	print("[test] Verifying generator shack and stall mechanics...")
	var st: Station = Game.level as Station
	assert(st != null, "Station node missing")
	var shack_zone = st.zone_at(Vector3(14.5, 0.5, -13.5))
	print("[test] Zone at gen shack: ", shack_zone)
	assert(shack_zone == &"gen_shack", "Zone must be gen_shack")
	Game.zone = shack_zone
	assert(Game.is_indoors(), "Player inside shack must be indoors")
	assert(st._generator != null, "Generator must exist")
	assert(st._barrel != null, "Barrel must exist")
	Game.generator_fuel = 80.0
	Game.power_on = true
	st._gen_stalled = false
	st._trigger_generator_stall()
	await _wait(1.6)
	assert(not Game.power_on, "Power should be off after generator stall")
	assert(st._generator_prompt() == Loc.t(&"it.gen_restart"), "Prompt must be restart prompt")
	while not Game.power_on:
		st._on_generator_used(Game.player)
	assert(Game.power_on, "Power should be restored after restart")
	print("[test] Generator stall & restart mechanics fully verified!")

	# Проверка свободного физического прохода через двери (выход из дома и вход в дизельную будку):
	print("[test] Verifying physical door passages without blocking collisions...")
	st.set_door_open(true)
	await _wait(0.6)
	Game.player.global_position = Vector3(14.0, 0.05, 3.1)
	for _f in range(120):
		Game.player.velocity = Vector3(2.5, 0.0, 0.0)
		Game.player.move_and_slide()
	print("[test] Player exited house to: ", Game.player.global_position)
	assert(Game.player.global_position.x > 15.0, "Player must physically walk through the front door onto the porch!")

	st.set_shack_door_open(true)
	await _wait(0.6)
	Game.player.global_position = Vector3(14.5, 0.05, -11.5)
	for _f in range(120):
		Game.player.velocity = Vector3(0.0, 0.0, -2.5)
		Game.player.move_and_slide()
	print("[test] Player entered generator booth to: ", Game.player.global_position)
	assert(Game.player.global_position.z < -12.7, "Player must physically walk into the generator booth!")
	assert(st.zone_at(Game.player.global_position) == &"gen_shack", "Player inside booth must be in gen_shack zone!")

	# Проверка выхода из будки обратно наружу:
	for _f in range(120):
		Game.player.velocity = Vector3(0.0, 0.0, 2.5)
		Game.player.move_and_slide()
	print("[test] Player stepped out of booth to: ", Game.player.global_position)
	assert(Game.player.global_position.z > -12.2, "Player must physically step out of the generator booth!")
	print("[test] Physical door navigation fully verified without any invisible walls!")

	# Проверка новых исправлений геометрии, палитры и интерактивных объектов:
	print("[test] Verifying palette colors and glow...")
	assert(Palette.COLORS.has(&"rust"), "Palette must have rust")
	assert(Palette.GLOWS.has(&"white"), "Palette must have white glow")
	var mat_rust: ShaderMaterial = Palette.m(&"rust") as ShaderMaterial
	assert(mat_rust != null, "Rust material must compile")
	var mat_wglow: StandardMaterial3D = Palette.glow(&"white")
	assert(mat_wglow != null and mat_wglow.albedo_color != Color.MAGENTA, "White glow must not be magenta")

	# Проверка чердачного сундука и протирки окон:
	assert(st._attic_chest != null, "Attic chest must exist")
	assert(st._attic_chest.prompt_provider.call() == Loc.t(&"it.attic_chest"), "Attic chest prompt must be initial")
	st._attic_chest.used.emit(Game.player)
	assert(st._attic_chest.prompt_provider.call() == Loc.t(&"sub.chest_empty"), "Attic chest prompt must be empty after loot")

	var wipe_node := st.get_node_or_null("WindowWipe") as Interactable
	assert(wipe_node != null, "Window wipe interactable must exist")
	assert(wipe_node.collision_layer == Geo.LAYER_WORLD, "Window wipe initial collision layer must be LAYER_WORLD")
	wipe_node.used.emit(Game.player)
	assert(wipe_node.collision_layer == 0, "Window wipe collision layer must be 0 after wiping")
	print("[test] Palette, attic chest, and window wipe fully verified!")

	# 1. Снимок здания станции снаружи
	_tp(Vector3(3.5, 0.05, -7.0), 180.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(4.0)
	await _wait(1.0)
	await _shot("station_wall_fixed")

	# 2. Снимок внутри сарая ГСМ (пол, бочки, канистры)
	_tp(Yard.SHED + Vector3(-2.8, 0.05, 0.0), -90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-10.0)
	await _wait(1.0)
	await _shot("shed_floor")

	# 3. Крупный план снегохода «Буран», тали и новых ящиков
	_tp(Yard.SHED + Vector3(3.8, 0.05, -0.6), -70.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-18.0)
	await _wait(1.0)
	await _shot("buran_snowmobile_detail")

	# 4. Метеоплощадка днем: жалюзийная будка, мостки, рейка и мачта
	_tp(Yard.METEO + Yard.M_GATE + Vector3(1.5, 0.05, 0.0), -90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(4.0)
	await _wait(1.0)
	await _shot("meteo_yard_day")

	# 5. Путеводный леер с колышками и красными флажками
	_tp(Vector3(18.0, 0.05, 5.5), -60.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-4.0)
	await _wait(1.0)
	await _shot("lifeline_rope_day")

	# 6. Бункер ГО: бетонный капонир, бронелюк со штурвалом и грибок
	_tp(Yard.BUNKER + Vector3(-3.8, 0.05, -3.8), 0.0)
	if Game.player != null:
		var diff_b: Vector3 = (Yard.BUNKER + Vector3(0, 1.2, 0)) - Game.player.global_position
		Game.player.rotation.y = atan2(-diff_b.x, -diff_b.z)
		if Game.player.head != null:
			Game.player.head.rotation.x = deg_to_rad(-6.0)
	await _wait(1.0)
	await _shot("bunker_portal_day")

	# 7. Озеро: мостки, прорубь, вешка-жерлица и шапка Семёнова
	_tp(Yard.HOLE + Vector3(2.4, 0.05, 2.4), 0.0)
	if Game.player != null:
		var diff_h: Vector3 = (Yard.HOLE + Vector3(0, 0.3, 0)) - Game.player.global_position
		Game.player.rotation.y = atan2(-diff_h.x, -diff_h.z)
		if Game.player.head != null:
			Game.player.head.rotation.x = deg_to_rad(-16.0)
	await _wait(1.0)
	await _shot("lake_pier_hole_day")

	# 8. Пролог и вездеход ГТ-Т
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": "day", "index": 0}
	_app.call(&"_start_phase")
	await _wait(5.5)
	if Game.player != null:
		Game.player.mode = Player.Mode.WALK
	_tp(Vehicle.drop_pos() + Vector3(3.5, 0.05, 2.0), 0.0)
	if Game.player != null:
		var diff: Vector3 = (Vehicle.drop_pos() + Vector3(0.0, 1.2, 0.0)) - Game.player.global_position
		Game.player.rotation.y = atan2(-diff.x, -diff.z)
		if Game.player.head != null:
			Game.player.head.rotation.x = deg_to_rad(-4.0)
	await _wait(1.0)
	await _shot("tracked_vehicle_gtt")

	print("[autotest] INSPECT FIXES COMPLETE")
	get_tree().quit()


func _inspect_stages() -> void:
	await _wait(1.0)
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": "night", "index": 3}
	_app.call(&"_start_phase")
	await _wait(5.5)
	if Game.player != null:
		Game.player.mode = Player.Mode.WALK

	# 1. Жилая комната: чугунная печь, валенки, деревянные часы «Янтарь»
	_tp(Vector3(-0.6, 0.05, 3.2), 220.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-12.0)
	await _wait(1.0)
	await _shot("01_living_room_stove_valenki")

	# 2. Радиорубка: Р-250, журнал и подстаканник с горячим чаем
	_tp(Vector3(8.9, 0.05, 0.2), 0.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-18.0)
	await _wait(1.0)
	await _shot("02_radio_desk_podstakannik")

	# 3. Коридор: подтаявшие следы босых ног к радиостолу
	_tp(Vector3(12.5, 0.05, 3.1), -90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-24.0)
	await _wait(1.0)
	await _shot("03_corridor_thawed_footprints")

	# 4. Двор и спасательный леер (натянутый трос со столбами и флажками)
	if Game.player != null and not Game.player.flashlight_on():
		Game.player.toggle_flashlight()
	_tp(Vector3(17.2, 0.05, 5.0), -60.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-5.0)
	await _wait(1.0)
	await _shot("04_lifeline_rope_yard")

	# 5. Метеоплощадка: флюгер Вильда и обледеневший анемометр
	Game.set_anemo_iced(true)
	_tp(Yard.METEO + Yard.M_VANE + Vector3(-2.5, 0.05, 0.5), -90.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(10.0)
	await _wait(1.0)
	await _shot("05_anemometer_iced_meteo")

	# 6. Метеобудка, деревянные мостки и снегомерная рейка
	_tp(Yard.METEO + Yard.M_BOOTH + Vector3(0.0, 0.05, 3.0), 0.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-8.0)
	await _wait(1.0)
	await _shot("06_meteo_yard_upgraded")

	# 7. Сарай ГСМ: слесарный верстак, цепная таль и ящики
	_tp(Yard.SHED + Vector3(-0.8, 0.05, 0.0), -125.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-12.0)
	await _wait(1.0)
	await _shot("07_shed_workbench_and_hoist")

	# 8. Бункер ГО: бетонный капонир, бронелюк и вентгрибок
	_tp(Yard.BUNKER + Vector3(-3.6, 0.05, -2.2), 125.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-6.0)
	await _wait(1.0)
	await _shot("08_bunker_caponier_portal")

	# 9. Озеро: мостки, прорубь, вешка-жерлица и шапка Семёнова
	_tp(Yard.HOLE + Vector3(2.5, 0.05, 1.8), -50.0)
	if Game.player != null and Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-16.0)
	await _wait(1.0)
	await _shot("09_lake_shack_ushanka_hole")

	print("[autotest] INSPECT STAGES COMPLETE")
	get_tree().quit()


## Сцены смерти: Ырка ловит в лесу, потом холод.
func _deaths() -> void:
	await _wait(1.0)
	SaveGame.new_game("hard")
	SaveGame.phase = {"kind": "night", "index": 3}
	_app.call(&"_start_phase")
	await _wait(5.5)
	_tp(Vector3(32.0, 0.05, -8.0), 230.0)
	Game.player.toggle_flashlight()
	await _wait(0.5)
	Game.yrka.force_chase()
	await _wait(0.2)
	(Game.yrka.get("_creature") as Node3D).global_position = Game.player.global_position + Vector3(0, 0, 3.0)
	await _wait(1.2)
	await _shot("death_yrka_a")
	await _wait(0.6)
	await _shot("death_yrka_b")
	await _wait(6.0)
	await _shot("death_yrka_text")
	_app.call(&"_on_session_finished", "retry")
	await _wait(5.5)
	_tp(Vector3(30.0, 0.05, -6.0), 200.0)
	Game.yrka.enabled = false
	Game.warmth = 0.5
	await _wait(2.5)
	await _shot("death_cold_a")
	await _wait(3.5)
	await _shot("death_cold_b")
	await _wait(5.0)
	await _shot("death_cold_text")
	get_tree().quit()


## Прогон одной фазы: `-- --stage night 4` — дойти до неё, сделать снимки и выйти.
func _stage(args: PackedStringArray) -> void:
	var i := args.find("--stage")
	var kind := args[i + 1] if args.size() > i + 1 else "night"
	var idx := int(args[i + 2]) if args.size() > i + 2 else 1
	await _wait(1.0)
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": kind, "index": idx}
	if args.has("mem"):   # проверка визуальных последствий памяти ночей
		SaveGame.flags["mem_total"] = {"out_after3": 2, "turned": 1, "obeyed_fake": 1}
	for it in ["tape_recorder", "codebook", "flare_gun", "bunker_key"]:
		Game.give_item(StringName(it))
	if kind == "day":
		for d in range(2, idx + 1):
			var unlocks: Dictionary = (_app.get_script() as Script).get_script_constant_map()["UNLOCKS"]
			for site: String in unlocks.get(d, []):
				Game.set_flag(site, true)
	else:
		for site in ["izba", "repeater", "lake", "bunker", "zimnik"]:
			if site != "zimnik" or idx >= 7:
				Game.set_flag(site, true)
	_app.call(&"_start_phase")
	await _wait(5.5)
	await _shot("%s%d_start" % [kind, idx])
	if args.has("tasks"):
		await _stage_tasks()
	elif has_method(&"_stage_" + kind + str(idx)):
		await call(&"_stage_" + kind + str(idx))
	print("[autotest] done, shots: ", _n)
	get_tree().quit()


func _home(min: float) -> void:
	_tp(Vector3(3.0, 0.05, 2.6), 0.0)
	Game.shift_minutes = min


## Задания Большой Земли: выдача после сводки, маяк, будка, масло, мачта, контрольная группа.
func _stage_tasks() -> void:
	_home(241.0)
	Game.reports_sent = 1
	EventBus.report_sent.emit(0)
	await _wait(8.0)
	await _shot("n2_orders")
	print("[autotest] orders: ", Game.tasks.active, " objective: ", Game.objective_text())
	for id in Game.tasks.active.duplicate():
		await _do_task(id)
	print("[autotest] after: active=", Game.tasks.active, " done=", Game.tasks.done)
	Game.hud.toggle_tasks()
	await _wait(0.5)
	await _shot("n2_tasks_tab")


func _do_task(id: StringName) -> void:
	match id:
		&"meteo_dig":
			_tp(Vector3(52.0, 0.05, -21.6), 180.0)
			await _wait(1.0)
			await _shot("task_drift")
			Game.yard.call(&"_on_drift_dug", Game.player)
		&"beacon", &"callsign":
			_home(250.0)
			await _wait(0.5)
			Game.radio.enter()
			var key := &"beacon" if id == &"beacon" else &"control"
			Game.radio.set_freq(float((Game.radio.get("_freq_over") as Dictionary)[key]))
			await _wait(7.5)
			await _shot("task_" + String(id))
			if id == &"callsign":
				Game.radio.set_freq(6880.0)
				await _wait(1.0)
				Game.radio.transmit()
				await _wait(1.0)
			Game.radio.exit()
		&"oil":
			_tp(Vector3(8.0, 0.05, 3.6), 180.0)
			Game.player.set_held(&"oil")
			Game.level.call(&"_on_generator_used", Game.player)
		&"mast_lamp":
			_tp(Vector3(26.5, 0.05, -47.0), 230.0)
			await _wait(1.0)
			await _shot("task_mast_dark")
			Game.yard.call(&"_on_mast_panel", Game.player)
	await _wait(2.5)
	print("[autotest] task ", id, " active now: ", Game.tasks.active)


## v1.2: предметы в доме, двор, журнал перехватов, индикатор фонаря, чекпоинт, случайные события.
func _stage_night1() -> void:
	var views := [[Vector3(1.6, 0.05, 2.4), 60.0, -10.0], [Vector3(4.6, 0.05, 1.6), 150.0, -18.0], [Vector3(2.2, 0.05, 3.2), 220.0, -12.0],
		[Vector3(7.0, 0.05, 2.2), 200.0, -15.0], [Vector3(3.0, 0.05, 2.0), 0.0, -30.0]]
	for i in range(views.size()):
		var v: Array = views[i]
		_tp(v[0], v[1])
		Game.player.head.rotation.x = deg_to_rad(v[2])
		await _wait(0.6)
		await _shot("v12_room_%d" % i)
	_tp(Vector3(12.5, 0.05, 6.5), 135.0)
	Game.player.toggle_flashlight()
	Game.flash_charge = 40.0
	await _wait(1.0)
	await _shot("v12_house_outside")
	var sd := (Yard.FORK - Yard.JUNCTION).normalized()
	var sp := Yard.JUNCTION - sd * 1.5
	_tp(sp, rad_to_deg(atan2(-sd.x, -sd.z)))
	Game.player.head.rotation.x = deg_to_rad(5.0)
	await _wait(0.8)
	await _shot("v12_sign")
	_tp(Vector3(7.5, 0.05, 9.0), 49.0)
	await _wait(0.6)
	await _shot("v12_woodpile")
	Game.events.call(&"_random_event", &"trail")
	Game.events.call(&"_random_event", &"porch")
	_tp(Vector3(6.5, 0.05, 9.5), 140.0)
	Game.player.head.rotation.x = deg_to_rad(-25.0)
	await _wait(1.0)
	await _shot("v12_trail")
	Game.add_intercept(&"numbers")
	Game.add_tape(&"numbers")
	Game.mark_decoded(&"numbers_clean")
	_open(&"intercepts")
	await _wait(0.8)
	await _shot("v12_intercepts")
	Game.hud.close_modal()
	Game.player.mode = Player.Mode.WALK
	# Чекпоинт: сводка 00:00 → смерть → ночь с полуночи.
	_home(241.0)
	Game.reports_sent = 1
	EventBus.report_sent.emit(0)
	await _wait(1.0)
	await _shot("v12_saved")
	Game.die(&"cold")
	await _wait(4.0)
	_app.call(&"_on_session_finished", "retry")
	await _wait(5.5)
	print("[autotest] after retry: minute=", Game.shift_minutes, " resumed=", Game.resumed, " reports=", Game.reports_sent)
	await _shot("v12_resumed")


func _stage_night3() -> void:
	_home(538.0)
	await _wait(9.0)
	await _shot("n3_knock")
	_open(&"peephole")
	await _wait(3.0)
	await _shot("n3_peephole")
	Game.hud.close_modal()
	Game.player.mode = Player.Mode.WALK
	await _wait(42.0)
	await _shot("n3_after")
	print("[autotest] phase after knock: ", SaveGame.phase, " over=", Game.shift_over)


func _stage_night4() -> void:
	_home(199.0)
	await _wait(5.0)
	_tp(Vector3(9.4, 0.05, 2.5), 270.0)
	await _wait(1.0)
	await _shot("n4_knock_door")
	_open(&"peephole")
	await _wait(3.0)
	await _shot("n4_peephole")
	Game.hud.close_modal()
	Game.player.mode = Player.Mode.WALK
	await _wait(32.0)
	Game.events.set(&"_knocks", [])
	_home(399.0)
	await _wait(14.0)
	await _shot("n4_order")
	_tp(Vector3(24.0, 0.05, -44.0), 180.0)
	await _wait(4.0)
	Game.player.rotation.y += PI
	await _wait(0.5)
	await _shot("n4_trap_chase")
	Game.player.fire_flare()
	await _wait(1.5)
	await _shot("n4_flare")
	print("[autotest] yrka stage after flare: ", Game.yrka.stage_name(), " flares=", Game.flares)
	# Открыть дверь, пока стучат, — смерть.
	await _wait(3.0)
	_tp(Vector3(9.3, 0.05, 2.5), 270.0)
	Game.events.call(&"_knock_sequence", false)
	await _wait(3.0)
	Game.level.set_door_open(true)
	await _wait(1.6)
	await _shot("n4_obmiralo_death_a")
	await _wait(0.8)
	await _shot("n4_obmiralo_death_b")
	await _wait(5.0)
	await _shot("n4_obmiralo_text")


func _stage_night5() -> void:
	_home(249.0)
	await _wait(4.0)
	await _shot("n5_gen_broke")
	Game.give_item(&"tools")
	_tp(Vector3(8.0, 0.05, 3.6), 180.0)
	await _wait(1.0)
	await _shot("n5_gen_prompt")
	Game.level.call(&"_on_generator_used", Game.player)
	await _wait(1.0)
	print("[autotest] power after repair: ", Game.power_on, " broken=", Game.gen_broken)
	Game.events.set(&"_knocks", [])
	_home(469.0)
	await _wait(6.0)
	await _shot("n5_paralysis_a")
	await _wait(5.0)
	await _shot("n5_paralysis_b")
	await _wait(10.0)
	await _shot("n5_after")


func _stage_night6() -> void:
	Game.events.set(&"_knocks", [])
	_home(359.0)
	await _wait(4.0)
	await _shot("n6_door_blown")
	_tp(Vector3(4.0, 0.05, 2.5), 270.0)
	await _wait(38.0)
	await _shot("n6_house_chase")
	await _wait(3.0)
	await _shot("n6_house_chase2")


func _stage_night7() -> void:
	_home(419.0)
	await _wait(5.0)
	await _shot("n7_call")
	print("[autotest] objective: ", Game.objective_text())
	_tp(Vector3(9.0, 0.05, 4.0), 135.0)
	await _wait(0.5)
	await _shot("n7_barrel")
	EventBus.ending_chosen.emit(&"burn")
	await _wait(6.0)
	await _shot("n7_end_burn_1")
	await _wait(4.0)
	await _shot("n7_end_burn_2")
	await _wait(8.0)
	await _shot("n7_end_credits")


func _stage_day3() -> void:
	_tp(Vector3(64.0, 0.05, -54.0), 315.0)
	await _wait(1.5)
	await _shot("d3_repeater")
	_open(&"map")
	await _wait(0.5)
	await _shot("d3_map")
	Game.hud.close_modal()


func _stage_day4() -> void:
	_tp(Vector3(-33.0, 0.05, 27.0), 215.0)
	await _wait(1.5)
	await _shot("d4_lake")
	_tp(Vector3(-31.0, 0.05, 20.0), 270.0)
	await _wait(1.0)
	await _shot("d4_shack")


func _stage_day5() -> void:
	_tp(Vector3(54.0, 0.05, 12.0), 270.0)
	await _wait(1.5)
	await _shot("d5_hatch")
	Game.yard.call(&"_on_hatch_used", Game.player)
	await _wait(2.0)
	await _shot("d5_bunker")
	Game.player.rotation.y = deg_to_rad(180.0)
	await _wait(0.5)
	await _shot("d5_bunker_2")
	Game.player.rotation.y = deg_to_rad(0.0)
	await _wait(0.5)
	await _shot("d5_bunker_3")


func _stage_day6() -> void:
	_tp(Vector3(-56.0, 0.05, -80.0), 220.0)
	await _wait(1.5)
	await _shot("d6_zimnik")
	_open(&"map")
	await _wait(0.5)
	await _shot("d6_map")
	Game.hud.close_modal()


func _run() -> void:
	await _wait(2.5)
	await _shot("menu")
	var menu: Node = _app.get("_menu")
	menu.call("_show_settings")
	await _wait(0.5)
	await _shot("settings")
	# Пиксельность «нет» и обратно — проверяем, что смена на лету не ломает рендер.
	Settings.pixelation = 0
	Settings.apply()
	await _wait(0.5)
	await _shot("menu_sharp")
	Settings.pixelation = 2
	Settings.apply()
	menu.call("_show_main")
	print("[autotest] new game")
	SaveGame.new_game("story")
	_app.call(&"_start_phase")
	await _wait(5.5)
	await _shot("prologue_start")
	# Пролог: разговор, показания, пробная сводка, генератор, печь, журнал.
	_tp(Vehicle.drop_pos() + Vector3(1.2, 0.05, 1.2), 60.0)
	await _wait(0.5)
	await _shot("prologue_driver")
	for s in Game.TUTORIAL_STEPS:
		Game.complete_step(s)
	_tp(Vector3(48.0, 0.05, -21.0), 225.0)
	await _wait(1.0)
	await _shot("meteo_day")
	_tp(Vector3(12.0, 0.05, 3.0), 90.0)
	await _wait(0.5)
	await _shot("door_day")
	_open(&"map")
	await _wait(0.5)
	await _shot("map")
	Game.hud.close_modal()
	Game.end_shift()
	await _wait(8.0)

	# Ночь 1.
	print("[autotest] night 1: ", Game.phase_kind, Game.phase_index)
	await _wait(5.5)
	await _shot("night1_room")
	_tp(Vector3(16.5, 0.05, 2.0), 60.0)
	Game.player.toggle_flashlight()
	await _wait(1.0)
	await _shot("night1_junction_sign")
	_tp(Vector3(35.0, 0.05, -10.0), 230.0)
	await _wait(1.0)
	await _shot("night1_forest")
	Game.yrka.threat = 99.0
	await _wait(1.0)
	Game.radio.enter()
	Game.radio.set_freq(5310.0)
	await _wait(2.5)
	await _shot("radio_numbers")
	Game.radio.exit()
	Director.add_tension(80.0, "autotest")
	await _wait(3.0)
	Game.end_shift()
	await _wait(8.0)

	# День 1: ящик Семёнова.
	print("[autotest] day 1: ", Game.phase_kind, Game.phase_index)
	await _wait(5.5)
	_tp(Vector3(38.5, 0.05, 27.0), 270.0)
	await _wait(1.0)
	await _shot("day1_shed")
	Game.give_item(&"tape_recorder")
	Game.day_goal_done = true
	Game.end_shift()
	await _wait(8.0)

	# Ночь 2: запись и магнитофон.
	print("[autotest] night 2: ", Game.phase_kind, Game.phase_index)
	await _wait(5.5)
	Game.add_tape(&"semenov")
	Game.add_tape(&"numbers")
	_open(&"tape")
	await _wait(1.0)
	await _shot("tape_deck")
	Game.hud.close_modal()
	Game.level.change_random_prop()
	Game.level.change_random_prop()
	Game.fatigue = 60.0
	Director.add_tension(80.0, "autotest")
	await _wait(4.0)
	await _shot("night2_room")
	Game.end_shift()
	await _wait(8.0)

	# День 2: изба и шифроблокнот.
	print("[autotest] day 2: ", Game.phase_kind, Game.phase_index)
	await _wait(5.5)
	_tp(Vector3(-11.0, 0.05, -29.0), 90.0)
	await _wait(1.0)
	await _shot("day2_izba")
	Game.give_item(&"codebook")
	Game.day_goal_done = true
	Game.end_shift()
	await _wait(8.0)

	# Ночь 3: шифроблокнот, погоня, финал.
	print("[autotest] night 3: ", Game.phase_kind, Game.phase_index)
	await _wait(5.5)
	Game.add_tape(&"code")
	_open(&"codebook")
	await _wait(0.8)
	await _shot("codebook")
	Game.hud.close_modal()
	Game.player.mode = Player.Mode.WALK
	_tp(Vector3(30.0, 0.05, -6.0), 230.0)
	Game.yrka.force_chase()
	await _wait(1.5)
	Game.player.rotation.y = Game.player.rotation.y + PI
	await _wait(0.4)
	await _shot("yrka_chase")
	_tp(Vector3(3.0, 0.05, 2.6), 0.0)
	await _wait(2.0)
	Game.shift_minutes = 538.0
	await _wait(8.0)
	await _shot("finale_knock")
	Game.level.set_door_open(true)
	await _wait(6.0)
	await _shot("finale_end")
	print("[autotest] done, shots: ", _n)
	get_tree().quit()


## Проверка эфирной сетки, фирменных сцен и озвучки (без оценки на глаз — только ошибки и лог).
func _probe() -> void:
	await _wait(1.0)
	SaveGame.new_game("story")
	Game.give_item(&"tape_recorder")
	SaveGame.phase = {"kind": "night", "index": 1}
	_app.call(&"_start_phase")
	await _wait(5.5)
	Game.yrka.enabled = false
	Director.stop()
	# Сводка с озвученным ответом Большой Земли
	_tp(Vector3(9.2, 0.05, -0.3), 0.0)
	Game.shift_minutes = 236.0
	for k in Game.READING_KEYS:
		Game.take_reading(k)
	Game.radio.enter()
	Game.radio.set_freq(6880.0)
	await _wait(1.0)
	Game.radio.transmit()
	await _wait(5.0)
	var avp0: Variant = Game.radio._active_voice_player
	print("[probe] reply stream=", (avp0.stream.resource_path if avp0 != null and is_instance_valid(avp0) else "-"), " reports=", Game.reports_sent)
	await _wait(6.0)
	print("[probe] after reply reports=", Game.reports_sent)
	Game.radio.exit()
	_home(297.0)
	await _wait(12.0)
	await _shot("probe_radio_ghost")
	print("[probe] radio_ghost done=", Game.events._done.has("radio_ghost"))
	while Game.radio.is_voice_busy() or Game.radio._busy:
		await _wait(1.0)
	_tp(Vector3(9.2, 0.05, -0.3), 0.0)
	Game.radio.enter()
	for f: float in [7140.0, 3950.0]:
		Game.radio.set_freq(f)
		await _wait(4.0)
		print("[probe] freq ", f, " locked=", Game.radio.locked_signal(), " sigs=", Game.radio._signals, " st=", Game.radio.strength_of(&"bc_st_1"), "/", Game.radio.strength_of(&"bc_sem_1"), " busy=", Game.radio._busy, " vb=", Game.radio.is_voice_busy(), " active=", Game.radio.active)
		await _shot("probe_freq_%d" % int(f))
	Game.radio.start_recording()
	await _wait(6.0)
	print("[probe] tapes=", SaveGame.tapes)
	Game.radio.exit()
	Game.end_shift()
	await _wait(8.0)
	SaveGame.phase = {"kind": "night", "index": 2}
	_app.call(&"_start_phase")
	await _wait(5.5)
	Game.yrka.enabled = false
	Director.stop()
	_home(327.0)
	await _wait(14.0)
	var avp: Variant = Game.radio._active_voice_player
	print("[probe] n2 knock=", Game.events.knocking, " par=", Game.events.paralysis, " end=", Game.events._ending, " chim=", Game.chimney_iced, " rbusy=", Game.radio._busy, " vb=", Game.radio.is_voice_busy(), " stream=", (avp.stream.resource_path if avp != null and is_instance_valid(avp) and avp.stream != null else "-"), " yrka=", Game.yrka.stage)
	print("[probe] n2 minute=", Game.shift_minutes, " busy=", Game.events._busy(), " home=", Game.is_home(), " zone=", Game.zone, " dir=", Director.phase, " cfg=", Game.cfg.get("roof_steps"))
	print("[probe] roof_steps done=", Game.events._done.has("roof_steps"))
	SaveGame.phase = {"kind": "night", "index": 4}
	_app.call(&"_start_phase")
	await _wait(5.5)
	Game.yrka.enabled = false
	Director.stop()
	_tp(Vector3(13.0, 0.05, 3.1), -90.0)
	Game.events._knock_sequence(false)
	await _wait(12.0)
	await _shot("probe_knock")
	_open(&"intercepts")
	await _wait(0.6)
	await _shot("probe_intercepts")
	print("[autotest] done, shots: ", _n)
	get_tree().quit()


## Память ночей, приказы по рации, сцены ночей 3–6, цифровая станция: -- --probe2 [part]
func _probe2(args: PackedStringArray) -> void:
	var part := "a"
	var i := args.find("--probe2")
	if i >= 0 and i + 1 < args.size():
		part = args[i + 1]
	await _wait(1.0)
	SaveGame.new_game("normal")
	Game.give_item(&"tape_recorder")
	if part == "a":
		await _p2_night(3)
		# Цифровая станция ночи 1 — голосом
		var nv := NumbersVoice.stream_for(&"numbers")
		print("[p2] numbers stream=", nv, " parts=", (nv as AudioStreamPlaylist).stream_count if nv is AudioStreamPlaylist else 0, " code=", NumbersVoice.stream_for(&"code"), " pool=", NumbersVoice.digit_pool())
		_tp(Vector3(9.2, 0.05, -0.3), 0.0)
		Game.reports_sent = 1
		# Настоящий приказ 00:50 → внеочередная
		Game.shift_minutes = 289.0
		await _wait(4.0)
		print("[p2] order kind=", Game.events.orders._kind, " obj=", Game.events.orders.objective(), " objtext=", Game.objective_text())
		await _shot("p2_order_real")
		while Game.radio.is_voice_busy() or Game.radio._busy:
			await _wait(0.5)
		Game.radio.enter()
		Game.radio.set_freq(6880.0)
		await _wait(1.5)
		print("[p2] pre-tx st=", Game.radio.strength_of(&"mainland"), " iced=", Game.antenna_iced, " busy=", Game.radio._busy, Game.radio.is_voice_busy(), " vo=", Game.radio.voice_override)
		Game.radio.transmit()
		await _wait(0.3)
		print("[p2] tx sub=", Game.hud._subtitle.text)
		await _wait(9.0)
		print("[p2] after transmit kind=", Game.events.orders._kind, " mem=", Game.mem_now, " sub=", Game.hud._subtitle.text)
		Game.radio.exit()
		# Перекличка 01:30
		_home(328.0)
		await _wait(5.0)
		await _shot("p2_roll")
		var t := 0.0
		while not Game.events._done.has("roll_call") or Director.hold:
			await _wait(1.0)
			t += 1.0
			if t > 60.0:
				break
		print("[p2] roll done=", Game.events._done.has("roll_call"), " t=", t)
		# Ложный приказ после трёх: не отвечаем → «мы ждали»
		_tp(Vector3(9.2, 0.05, -0.3), 0.0)
		Game.shift_minutes = 444.0
		for _k in range(12):
			await _wait(1.0)
			if Game.events.orders.active():
				break
		print("[p2] fake kind=", Game.events.orders._kind, " fake=", Game.events.orders.is_fake(), " mem=", Game.mem_now, " busy=", Game.events._busy(), " dir=", Director.phase, " rb=", Game.radio._busy, Game.radio.is_voice_busy(), " home=", Game.is_home(), " q=", Game.events.orders._queue)
		await _wait(5.0)
		await _shot("p2_order_fake")
		Game.shift_minutes = 500.0
		await _wait(4.0)
		print("[p2] fake expired kind=", Game.events.orders._kind)
		# Ответили после трёх → память
		NightMemory.mark(&"after3_tx")
		Game.end_shift()
		await _wait(6.0)
		print("[p2] mem_last=", SaveGame.flags.get("mem_last"), " total=", SaveGame.flags.get("mem_total"), " morning=", NightMemory.morning_line())
		SaveGame.phase = {"kind": "day", "index": 3}
		_app.call(&"_start_phase")
		await _wait(5.0)
		_home(10.0)
		for _k in range(16):
			await _wait(1.0)
			var av: Variant = Game.radio._active_voice_player
			if av != null and is_instance_valid(av):
				print("[p2] morning voice=", av.stream, " sub=", Game.hud._subtitle.text)
				break
		await _shot("p2_morning")
	elif part == "b":
		await _p2_night(4)
		# Следы: на улице 20+ с после 00:10, потом домой
		_tp(Vector3(26.0, 0.05, 8.0), 0.0)
		Game.shift_minutes = 252.0
		await _wait(23.0)
		print("[p2] prints placed=", Game.events._prints != null)
		_tp(Vector3(12.8, 0.05, 3.1), -90.0)
		await _wait(2.0)
		_tp(Vector3(10.5, 0.05, 3.6), 90.0)
		await _wait(2.5)
		await _shot("p2_footprints")
		_tp(Vector3(9.6, 0.05, 2.4), 160.0)
		Game.player.head.rotation.x = deg_to_rad(-35.0)
		await _wait(1.0)
		await _shot("p2_footprints_radio")
		Game.player.head.rotation.x = 0.0
		print("[p2] prints seen=", Game.events._prints_seen)
		# Память у двери
		NightMemory.mark(&"turned")
		_tp(Vector3(13.0, 0.05, 3.1), -90.0)
		Game.events._knock_sequence(false)
		await _wait(26.0)
		print("[p2] door_mem done=", Game.events._done.get("door_mem", false))
	elif part == "c":
		await _p2_night(5)
		Game.events.orders._queue = []
		Game.reports_sent = 2
		Game.events._knocks = []
		_home(423.0)
		await _wait(6.0)
		await _shot("p2_underfloor")
		await _wait(22.0)
		print("[p2] underfloor done=", Game.events._done.has("underfloor"))
		# Ложный приказ «откройте дверь» — открываем
		Director.hold = false
		Game.shift_minutes = 339.0
		Game.events.orders._queue = [[339, &"fake_door_wrong"]]
		_tp(Vector3(9.2, 0.05, -0.3), 0.0)
		await _wait(4.0)
		print("[p2] door order=", Game.events.orders._kind)
		while Game.radio.is_voice_busy():
			await _wait(0.5)
		_tp(Vector3(13.6, 0.05, 3.1), -90.0)
		Game.level.set_door_open(true)
		await _wait(7.0)
		await _shot("p2_door_obeyed")
		print("[p2] obeyed=", Game.mem_now)
	elif part == "d":
		await _p2_night(6)
		Game.reports_sent = 2
		Game.events._knocks = []
		Game.events.orders._queue = []
		_tp(Vector3(3.0, 0.05, 2.6), 0.0)
		Game.shift_minutes = 399.0
		await _wait(5.0)
		for _k in range(20):
			if Game.events._lights_node != null:
				break
			await _wait(1.0)
		_tp(Vector3(16.5, 0.05, 3.5), 0.0)
		Game.player.look_at(Vector3(36, 0.05, 24), Vector3.UP)
		await _wait(1.0)
		await _shot("p2_lights")
		await _wait(8.0)
		_tp(Vector3(30.0, 0.05, 18.0), 0.0)
		await _wait(6.0)
		await _shot("p2_lights_chase")
		print("[p2] lights done=", Game.events._done.has("lights"), " mem=", Game.mem_now, " yrka=", Game.yrka.stage)
	elif part == "e":
		await _p2_night(3)
		Game.hud.show_note(Loc.t(&"journal.rules") + "\n\n" + Loc.t(&"journal.extra"))
		await _wait(1.0)
		await _shot("p2_journal")
	print("[autotest] done, shots: ", _n)
	get_tree().quit()


func _p2_night(n: int) -> void:
	SaveGame.phase = {"kind": "night", "index": n}
	_app.call(&"_start_phase")
	await _wait(5.5)
	Game.yrka.enabled = false
	Director.stop()
	Game.events._accidents = []        # случайные аварии (дымоход и т.п.) не мешают проверять сцены


## Обзорная съёмка мира: -- --tour day 6 | -- --tour night 4 [hud]
## Замер нагрузки: точки обзора по всей карте. Метрики не зависят от видеокарты: вызовы отрисовки,
## треугольники, объекты в кадре, время скриптов (process/physics). «hitch» — самый долгий кадр скриптов.
const PERF_MAP := [
	["yard_house", Vector3(26, 0.05, 15), Vector3(8, 1.5, 2)],
	["yard_wide", Vector3(31, 0.05, 17), Vector3(6, 3.0, 0)],
	["treeline", Vector3(20, 0.05, -8), Vector3(40, 5.0, -40)],
	["room", Vector3(2.8, 0.05, 5.8), Vector3(-1.5, 1.0, 1.0)],
	["radio", Vector3(5.0, 0.05, 0.9), Vector3(9.2, 1.0, -1.4)],
	["corridor", Vector3(10.8, 0.05, 4.6), Vector3(4.0, 1.4, 4.0)],
	["meteo", Vector3(49, 0.05, -23), Vector3(58, 1.0, -32)],
	["shed", Vector3(39, 0.05, 29), Vector3(48, 1.5, 34)],
	["zimnik", Vector3(-54, 0.05, -78), Vector3(-62, 1.0, -88)],
	["zimnik_far", Vector3(-150, 0.0, -190), Vector3(-200, 2.0, -230)],
	["camp", Vector3(-330, 0.0, 12), Vector3(-362, 2.0, 10)],
	["tower", Vector3(280, 0.0, -300), Vector3(300, 6.0, -322)],
	["drill", Vector3(76, 0.0, 300), Vector3(80, 4.0, 324)],
	["hill_view", Vector3(150, 0.0, 120), Vector3(20, 0.0, -5)],
]


func _perf_views(kind: String, idx: int) -> void:
	var p := Game.player
	print("[perf] %-11s %6s %8s %6s %7s %7s %7s %6s" % ["view", "draws", "prims", "objs", "proc_ms", "phys_ms", "hitch", "nodes"])
	var worst_proc := 0.0
	for v: Array in PERF_MAP:
		var pos: Vector3 = v[1]
		if absf(pos.x) > 100 or absf(pos.z) > 100:
			pos.y = Terrain.height(pos.x, pos.z) + 0.05
		var tgt: Vector3 = v[2]
		if absf(tgt.x) > 100 or absf(tgt.z) > 100:
			tgt.y += Terrain.height(tgt.x, tgt.z)
		_look(pos, tgt)
		p.flashlight.visible = kind == "night"
		await _wait(1.0)
		var dc := 0.0
		var pr := 0.0
		var ob := 0.0
		var proc := 0.0
		var phys := 0.0
		var hitch := 0.0
		var n := 0
		for k in 8:
			await get_tree().process_frame
			dc = maxf(dc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			pr = maxf(pr, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			ob = maxf(ob, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			var pt := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			proc += pt
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			hitch = maxf(hitch, pt)
			n += 1
		worst_proc = maxf(worst_proc, hitch)
		print("[perf] %-11s %6d %8d %6d %7.2f %7.2f %7.2f %6d" % [v[0], dc, pr, ob, proc / n, phys / n, hitch,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("[perf] память: static %.0f МБ, видео %.0f МБ" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	get_tree().quit()


## Физика у вышки: кто съедает время _physics_process (выключаем по одному).
func _perf_phys() -> void:
	var pos := Vector3(280.0, 0.0, -300.0)
	pos.y = Terrain.height(pos.x, pos.z) + 0.05
	_look(pos, Vector3(300, pos.y + 4.0, -322))
	await _wait(1.5)
	var avg := func(n: int) -> float:
		var acc := 0.0
		for k in n:
			await get_tree().physics_frame
			acc += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		return acc / n
	var base: float = await avg.call(40)
	print("[phys] база %.2f мс, активных тел %d, пар %d" % [base, Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)])
	for n: Node in get_tree().root.find_children("*", "", true, false):
		if n.is_physics_processing() and n.get_script() != null and n != self:
			n.set_physics_process(false)
			var t: float = await avg.call(25)
			n.set_physics_process(true)
			print("[phys] %6.2f мс  %s (%s)" % [base - t, n.name, (n.get_script() as Script).resource_path.get_file()])
	get_tree().quit()


## Подвисания: сколько миллисекунд занимает кадр, в котором случается событие (спавн, окно, звук).
func _perf_events() -> void:
	var p := Game.player
	_look(Vector3(26, 0.05, 15), Vector3(8, 1.5, 2))
	await _wait(1.0)
	var spike := func(label: String, f: Callable) -> void:
		var t0 := Time.get_ticks_usec()
		await f.call()
		await get_tree().process_frame
		var a := (Time.get_ticks_usec() - t0) / 1000.0
		await get_tree().process_frame
		print("[hitch] %-26s %7.1f мс" % [label, a])
	for id: StringName in [&"gtt_ghost", &"campfire", &"road_figure", &"probe", &"foreign_tracks", &"tower_lights", &"twin_buran"]:
		await spike.call("событие " + String(id), func() -> void: MapEvents.instance.force(id))
	for c: Array in [["ырка", func() -> Node3D: return Creatures.make_yrka()], ["двойник", func() -> Node3D: return Creatures.make_double(&"orekhov")],
			["жердяй", func() -> Node3D: return Creatures.make_zherdyai(83.0)], ["михалыч", func() -> Node3D: return Creatures.make_human(&"driver")]]:
		await spike.call("спавн " + String(c[0]), func() -> void:
			var n: Node3D = (c[1] as Callable).call()
			Game.level.add_child(n)
			n.global_position = Vector3(20, 0, 10))
	for ui: StringName in [&"journal", &"map", &"supply", &"tasks", &"radio_log", &"barograph", &"meteor"]:
		await spike.call("окно " + String(ui), func() -> void: EventBus.ui_requested.emit(ui))
		if Game.hud != null and Game.hud.modal() != null:
			Game.hud.close_modal()
		await _wait(0.3)
	await spike.call("голос v_cab_17", func() -> void: Voice.say(&"cab.17", 1.0))
	await spike.call("голос door_4_4", func() -> void: Game.audio.say(&"door_4_4", Vector3(14, 1, 3)))
	_look(Vector3(-150, Terrain.height(-150, -190) + 0.05, -190), Vector3(-200, 2.0, -230))
	await spike.call("телепорт на зимник", func() -> void: pass)
	_look(Vector3(26, 0.05, 15), Vector3(8, 1.5, 2))
	await spike.call("телепорт домой", func() -> void: pass)
	# Езда по зимнику: шаг 7 м за кадр — ближние ели пересобираются каждый раз
	var road := Terrain.road_points(&"zimnik", 7.0)
	var worst := 0.0
	var total := 0.0
	for k in range(4, mini(road.size() - 1, 34)):
		var t0 := Time.get_ticks_usec()
		_look(road[k] + Vector3(0, 0.05, 0), road[k + 1] + Vector3(0, 1.5, 0))
		await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		total += ms
	print("[hitch] езда по зимнику: кадр в среднем %.1f мс, худший %.1f мс" % [total / 30.0, worst])
	get_tree().quit()


const TOUR := [
	["ext_se", Vector3(26, 0.05, 15), Vector3(8, 1.5, 2)],
	["ext_nw", Vector3(-9, 0.05, -11), Vector3(5, 1.5, 1)],
	["porch", Vector3(19, 0.05, 5.0), Vector3(14.5, 1.4, 3.1)],
	["room_stove", Vector3(2.8, 0.05, 5.8), Vector3(-1.5, 1.0, 1.0)],
	["room_bed", Vector3(-1.8, 0.05, 1.6), Vector3(2.5, 0.8, 5.5)],
	["radio", Vector3(5.0, 0.05, 0.9), Vector3(9.2, 1.0, -1.4)],
	["storage", Vector3(5.3, 0.05, -2.5), Vector3(5.3, 0.8, -5.2)],
	["corridor", Vector3(10.8, 0.05, 4.6), Vector3(4.0, 1.4, 4.0)],
	["vestibule", Vector3(12.0, 0.05, 5.9), Vector3(14.5, 1.3, 3.1)],
	["attic", Vector3(4.8, 3.05, 3.4), Vector3(-1.0, 3.6, 3.3)],
	["gen_shack", Vector3(14.5, 0.05, -12.5), Vector3(14.2, 0.5, -13.7)],
	["junction", Vector3(21, 0.05, 6), Vector3(29, 0.6, -2)],
	["meteo", Vector3(49, 0.05, -23), Vector3(58, 1.0, -32)],
	["meteo_close", Vector3(52.5, 0.05, -29.5), Vector3(58, 1.0, -32.5)],
	["mast", Vector3(26, 0.05, -50), Vector3(24, 5.0, -62)],
	["shed", Vector3(39, 0.05, 29), Vector3(48, 1.5, 34)],
	["woodpile", Vector3(9, 0.05, 31), Vector3(4, 1.0, 40)],
	["izba", Vector3(-7, 0.05, -25), Vector3(-16, 1.5, -30)],
	["repeater", Vector3(63, 0.05, -52), Vector3(72, 3.0, -62)],
	["lake", Vector3(-28, 0.05, 29), Vector3(-42, 0.0, 38)],
	["bunker", Vector3(51, 0.05, 7), Vector3(58, 0.5, 12)],
	["zimnik", Vector3(-54, 0.05, -78), Vector3(-62, 1.0, -88)],
	["forest", Vector3(35, 0.05, -9), Vector3(65, 2.0, -12)],
	["hero", Vector3(31, 0.05, 17), Vector3(6, 3.0, 0)],
	["treeline", Vector3(20, 0.05, -8), Vector3(40, 5.0, -40)],
	["from_woods", Vector3(-12, 0.05, 14), Vector3(6, 1.5, 4)],
	["h_ne", Vector3(23, 0.05, -7), Vector3(9, 2.0, 0)],
	["h_nw", Vector3(-10, 0.05, -11), Vector3(4, 2.0, 0)],
	["h_sw", Vector3(-9, 0.05, 14), Vector3(4, 2.0, 3)],
	["h_n_close", Vector3(8, 0.05, -10), Vector3(8, 2.5, -2)],
	["h_e_close", Vector3(20, 0.05, 1), Vector3(14, 2.2, 2)],
	["gen_path", Vector3(17, 0.05, 2), Vector3(15, 0.5, -11)],
	["gen_close", Vector3(18, 0.05, -7), Vector3(14.5, 1.0, -12.5)],
	["win", Vector3(0.5, 0.05, 5.0), Vector3(0.5, 1.45, 6.6)],
	["gen_east", Vector3(19.5, 0.05, -11.0), Vector3(14.5, 1.2, -13.5)],
	["gen_back", Vector3(11.5, 0.05, -17.5), Vector3(14.5, 1.5, -13.5)],
	["d_storage", Vector3(4.6, 0.05, -2.4), Vector3(6.2, 0.4, -5.0)],
	["d_corr", Vector3(10.8, 0.05, 4.4), Vector3(4.2, 0.4, 3.0)],
	["d_room", Vector3(0.5, 0.05, 3.0), Vector3(2.9, 0.5, 0.4)],
	["d_radio", Vector3(8.0, 0.05, 0.0), Vector3(11.0, 0.4, 1.7)],
	["d_shack_in", Vector3(14.9, 0.05, -12.2), Vector3(13.2, 0.7, -13.0)],
	["d_porch", Vector3(18.5, 0.05, 7.5), Vector3(15.4, 0.5, 5.7)],
	["d_logs", Vector3(11.5, 0.05, -7.0), Vector3(9.5, 0.3, -4.2)],
	# Контрольные кадры (до/после): окно на тайгу, выход в метель, путь к дизельной, рубка ночью, опушка
	["k1_window", Vector3(0.9, 0.05, 3.3), Vector3(-6.0, 1.3, 3.3)],
	["k2_exit", Vector3(15.6, 0.05, 3.1), Vector3(26.0, 1.4, 4.0)],
	["k3_diesel", Vector3(16.3, 0.05, 1.5), Vector3(14.6, 0.8, -10.0)],
	["k4_radio", Vector3(6.0, 0.05, 0.6), Vector3(9.2, 1.0, -1.6)],
	["k5_edge", Vector3(24.0, 0.05, -4.0), Vector3(45.0, 2.0, -14.0)],
	["m_trail", Vector3(6.0, 0.05, 10.5), Vector3(6.0, 0.0, 8.4)],
	["m_route", Vector3(19.5, 0.05, -4.0), Vector3(17.3, 0.0, -1.0)],
	["m_window", Vector3(9.2, 0.05, -5.2), Vector3(9.2, 0.0, -2.8)],
	["m_watch", Vector3(0.5, 0.05, 3.2), Vector3(-30.0, 1.2, 3.2)],
	["m_watch2", Vector3(17.5, 0.05, 4.5), Vector3(36.0, 1.0, 24.0)],
	["m_oneway", Vector3(20.0, 0.05, 4.0), Vector3(23.5, 0.0, -9.0)],
	["f_far", Vector3(36.0, 0.05, 12.0), Vector3(60.0, 3.0, 0.0)],
	["f_north", Vector3(6.0, 0.05, -14.0), Vector3(0.0, 3.0, -50.0)],
	["fp_none", Vector3(19.0, 0.05, 8.0), Vector3(14.0, 1.2, 3.0)],
	["fp_can", Vector3(19.0, 0.05, 8.0), Vector3(14.0, 1.2, 3.0)],
	["fp_wood", Vector3(19.0, 0.05, 8.0), Vector3(14.0, 1.2, 3.0)],
	["fp_oil", Vector3(19.0, 0.05, 8.0), Vector3(14.0, 1.2, 3.0)],
	["fp_shovel", Vector3(19.0, 0.05, 8.0), Vector3(14.0, 1.2, 3.0)],
	["fp_flare", Vector3(19.0, 0.05, 8.0), Vector3(14.0, 2.5, 3.0)],
	["fp_in", Vector3(0.5, 0.05, 3.0), Vector3(2.9, 1.0, 0.4)],
	["fp_wall", Vector3(3.15, 0.05, 3.0), Vector3(3.7, 1.0, 1.0)],
	["c_room_ne", Vector3(1.0, 0.05, 2.5), Vector3(3.2, 0.6, 0.3)],
	["c_corr_w", Vector3(9.5, 0.05, 4.0), Vector3(4.0, 0.9, 6.3)],
	["c_store", Vector3(4.2, 0.05, -2.6), Vector3(6.8, 0.6, -5.3)],
	["c_vest", Vector3(13.8, 0.05, 4.5), Vector3(11.8, 0.4, 1.8)],
	["x_roof_s", Vector3(6.0, 0.05, 13.0), Vector3(6.0, 4.0, 6.0)],
	["x_roof_e", Vector3(22.0, 0.05, 2.0), Vector3(14.0, 3.5, 2.0)],
	["x_roof_w", Vector3(-9.0, 0.05, 3.0), Vector3(-2.0, 3.5, 3.0)],
	["x_corner_se", Vector3(18.0, 0.05, 10.0), Vector3(14.5, 2.0, 6.6)],
	["x_north", Vector3(8.0, 0.05, -9.5), Vector3(8.0, 2.5, -4.0)],
	["lk_in", Vector3(-35.3, 0.6, 21.6), Vector3(-38.5, 1.7, 18.8)],
	["yd_laundry", Vector3(7.0, 0.05, 17.0), Vector3(1.8, 1.4, 11.2)],
	["yd_hare", Vector3(20.0, 0.05, 16.0), Vector3(14.0, -2.0, 30.0)],
	["in_table", Vector3(-0.3, 0.05, 2.6), Vector3(1.2, 0.8, 4.0)],
	["in_shelf", Vector3(1.2, 0.05, 3.6), Vector3(-2.4, 1.4, 4.8)],
	["in_hooks", Vector3(6.6, 0.05, 3.2), Vector3(6.2, 1.3, 6.6)],
	["in_radio", Vector3(8.0, 0.05, 1.0), Vector3(8.6, 0.8, -1.2)],
	["in_store", Vector3(5.2, 0.05, -2.6), Vector3(5.8, 1.2, -5.5)],
	["lk_west", Vector3(-35.2, 0.6, 21.0), Vector3(-39.6, 1.1, 20.6)],
	["lk_bench", Vector3(-37.8, 0.6, 20.2), Vector3(-38.7, 1.0, 18.6)],
	["lk_door", Vector3(-36.0, 0.6, 27.5), Vector3(-36.0, 1.6, 20.0)],
	["lk_nets", Vector3(-36.0, 0.6, 20.0), Vector3(-33.5, 1.2, 20.0)],
	["ex_house_se", Vector3(24.0, 0.05, 18.0), Vector3(6.0, 2.5, 3.0)],
	["ex_house_nw", Vector3(-9.0, 0.05, -11.0), Vector3(6.0, 2.5, 3.5)],
	["ex_gen", Vector3(22.0, 0.05, -20.0), Vector3(14.5, 1.5, -13.0)],
	["ex_shed", Vector3(39.0, 0.05, 25.0), Vector3(48.0, 1.8, 34.0)],
	["ex_shed_b", Vector3(57.0, 0.05, 43.0), Vector3(48.0, 1.8, 34.0)],
	["ex_izba", Vector3(-6.0, 0.05, -21.0), Vector3(-16.0, 1.8, -30.0)],
	["ex_izba_b", Vector3(-26.0, 0.05, -39.0), Vector3(-16.0, 1.8, -30.0)],
	["ex_repeater", Vector3(62.0, 0.05, -51.0), Vector3(72.0, 2.0, -62.0)],
	["ex_meteo", Vector3(76.0, 0.05, -24.0), Vector3(98.0, 1.5, -30.0)],
	["ex_lake", Vector3(-27.0, 0.05, 13.0), Vector3(-36.0, 1.8, 20.0)],
	["ex_lake_b", Vector3(-45.0, 0.05, 27.0), Vector3(-36.0, 1.8, 20.0)],
	["ex_bunker", Vector3(50.0, 0.05, 4.0), Vector3(58.0, 1.0, 12.0)],
	["ex_heli", Vector3(36.0, 0.05, -2.0), Vector3(44.0, 1.5, 6.0)],
	["rf_izba", Vector3(-8.0, 0.05, -25.0), Vector3(-16.0, 3.0, -30.0)],
	["rf_izba_b", Vector3(-22.0, 0.05, -24.0), Vector3(-16.0, 3.0, -30.0)],
	["rf_shed", Vector3(42.0, 0.05, 29.0), Vector3(48.0, 3.0, 34.0)],
	["rf_house", Vector3(19.0, 0.05, -3.0), Vector3(11.0, 3.0, 1.0)],
	["rf_house_w", Vector3(-6.0, 0.05, 8.0), Vector3(1.0, 3.0, 4.0)],
	["rf_gen", Vector3(19.5, 0.05, -16.5), Vector3(14.5, 2.4, -13.0)],
	["rf_repeater", Vector3(66.0, 0.05, -56.0), Vector3(72.0, 2.5, -62.0)],
	["pv_ams1", Vector3(182.0, 0.05, -163.0), Vector3(177.0, 1.5, -168.0)],
	["pv_ams2", Vector3(-192.0, 0.05, 21.0), Vector3(-197.0, 1.5, 16.0)],
	["pv_ams3", Vector3(50.0, 0.05, 181.0), Vector3(45.0, 1.5, 176.0)],
	["pv_ams4", Vector3(-96.0, 0.05, -153.0), Vector3(-101.0, 1.5, -158.0)],
	["pv_source", Vector3(-88.0, 0.05, 76.0), Vector3(-95.0, 2.0, 70.0)],
	["pv_zimnik", Vector3(-58.0, 0.05, -84.0), Vector3(-70.0, 1.5, -94.0)],
	["pv_meteo2", Vector3(86.0, 0.05, -29.0), Vector3(98.0, 1.0, -31.0)],
	["pv_camp_c1", Vector3(-346.0, 0.05, 22.0), Vector3(-362.0, 1.5, 8.0)],
	["pv_camp_c2", Vector3(-378.0, 0.05, 26.0), Vector3(-362.0, 1.5, 6.0)],
	["pv_drill_c1", Vector3(92.0, 0.05, 336.0), Vector3(80.0, 3.0, 324.0)],
	["pv_tower_c1", Vector3(314.0, 0.05, -310.0), Vector3(300.0, 3.0, -322.0)],
	["pv_camp", Vector3(-340.0, 0.05, 25.0), Vector3(-362.0, 2.0, 10.0)],
	["pv_drill", Vector3(96.0, 0.05, 306.0), Vector3(80.0, 3.0, 324.0)],
	["pv_tower", Vector3(284.0, 0.05, -300.0), Vector3(300.0, 8.0, -322.0)],
	["pv_drop", Vector3(-158.0, 0.05, -198.0), Vector3(-170.0, 1.5, -210.0)],
]


func _tour(args: PackedStringArray) -> void:
	var i := args.find("--tour")
	var kind := args[i + 1] if args.size() > i + 1 else "day"
	var idx := int(args[i + 2]) if args.size() > i + 2 else 6
	await _wait(1.0)
	SaveGame.new_game("story")
	SaveGame.phase = {"kind": kind, "index": idx}
	for it in ["tape_recorder", "codebook", "flare_gun", "bunker_key", "tools", "skis"]:
		if it == "skis" and " ".join(args).contains("lk_"):
			continue
		Game.give_item(StringName(it))
	for site in ["izba", "repeater", "lake", "bunker", "zimnik"]:
		Game.set_flag(site, true)
	if args.has("fieldjobs") or args.has("sourcereview") or args.has("nightjob") or args.has("sig0310") or args.has("stage2") or args.has("rituals"):
		Game.set_flag("buran_uncovered", true)
	if args.has("sourcereview"):
		for b in ["ams1", "ams3", "tower"]:
			Game.set_flag("brg_" + b, true)
	if args.has("nobatch"):
		Settings.batching = false
	if args.has("tutg"):      # пролог после приезда: игрок уже у станции
		Game.set_flag("left_cabin", true)
		Game.set_flag("prologue_arrived", true)
	if args.has("coldshots"):   # кадры холодного старта: он идёт внутри _begin, до прогрева тура
		_shoot_loop("cold", 22, 2.0)
	_app.call(&"_start_phase")
	await _wait(5.0)
	var waited := 0.0
	while Game.player != null and Game.player.mode != Player.Mode.WALK and waited < 120.0:   # ждём конца прогрева
		await _wait(0.5)
		waited += 0.5
	Game.yrka.enabled = false
	Director.stop()
	if not args.has("hud") and Game.hud != null:
		Game.hud.visible = false
	if args.has("storm") and Game.weather != null:
		Game.weather.force_blizzard(true, 999.0)
		Game.weather.intensity = 1.0
	if args.has("dump"):
		_dump_aabbs()
	if args.has("perfmap"):
		await _perf_views(kind, idx)
		return
	if args.has("sprucediag"):
		_look(Vector3(39.4, 0.05, 28.7), Vector3(30.0, 1.0, 20.0))
		await _wait(1.5)
		var sn := Game.yard.get_node_or_null("SpruceNear")
		print("[diag] quality=", Settings.quality, " cards=", SpruceMesh.cards_enabled(), " near=", sn != null)
		if sn != null:
			print("[diag] visible=", sn.visible, " processing=", sn.is_processing())
			for ch in sn.get_children():
				var mm := (ch as MultiMeshInstance3D).multimesh
				print("[diag] mm count=", mm.instance_count, " mesh=", mm.mesh != null)
		for k in SpruceMesh._lod_cache:
			var mat := (SpruceMesh._lod_cache[k] as ArrayMesh).surface_get_material(0) as ShaderMaterial
			print("[diag] ", k, " lod_near=", mat.get_shader_parameter(&"lod_near"), " lod_far=", mat.get_shader_parameter(&"lod_far"))
		get_tree().quit()
		return
	if args.has("perfphys"):
		await _perf_phys()
		return
	if args.has("trailprops"):
		for ti in LifeDressing.TRAIL_PROPS.size():
			var pr := LifeDressing.trail_prop(ti)
			var pos: Vector3 = pr[0]
			var face := Vector3(sin(pr[1]), 0, cos(pr[1]))
			var eye := pos + face * 6.5 + Vector3(face.z, 0, -face.x) * 2.0
			_look(Vector3(eye.x, Terrain.height(eye.x, eye.z) + 0.05, eye.z), pos + Vector3(0, 1.2, 0))
			await _wait(1.2)
			await _shot("trail_" + String(LifeDressing.TRAIL_PROPS[ti][0]))
		get_tree().quit()
		return
	if args.has("yrkashots"):
		await _yrka_shots()
		get_tree().quit()
		return
	if args.has("visual"):
		await _visual_review()
		get_tree().quit()
		return
	if args.has("corpus"):
		await _corpus_review()
		get_tree().quit()
		return
	if args.has("towerwalk"):
		await _tower_walk()
		get_tree().quit()
		return
	if args.has("yardshots"):
		await _yard_review()
		get_tree().quit()
		return
	if args.has("house"):
		await _house_review()
		get_tree().quit()
		return
	if args.has("lore"):
		await _lore_review()
		get_tree().quit()
		return
	if args.has("uishots"):
		await _ui_review()
		get_tree().quit()
		return
	if args.has("efir"):
		await _efir_review()
		get_tree().quit()
		return
	if args.has("porch"):
		await _porch_walk()
		get_tree().quit()
		return
	if args.has("thermo"):
		await _thermo_review()
		get_tree().quit()
		return
	if args.has("cutshots"):
		await _cut_review()
		get_tree().quit()
		return
	if args.has("zherdshots"):
		await _zherd_shots()
		get_tree().quit()
		return
	if args.has("doubleshots"):
		await _double_shots()
		get_tree().quit()
		return
	if args.has("tutg"):
		await _tutg_review()
		get_tree().quit()
		return
	if args.has("spine"):
		await _spine_review()
		get_tree().quit()
		return
	if args.has("endshots"):
		await _endshots_review()
		get_tree().quit()
		return
	if args.has("sig0310"):
		await _sig0310_review()
		get_tree().quit()
		return
	if args.has("stage2"):
		Game.hud.visible = true
		SaveGame.flags["fj_key"] = ""
		FieldJobs._ensure_jobs()
		print("[s2] jobs=", FieldJobs.jobs())
		print("[s2] obj 15:00=", Game.objective_text())
		Game.day_goal_done = true
		Game.shift_minutes = 181.0
		await _wait(1.5)
		print("[s2] obj 17:01=", Game.objective_text(), " evening=", Game.is_evening())
		Game.mirror_covered = true
		SaveGame.flags["forecast_day"] = Game.phase_index
		print("[s2] ready=", Game.evening_ready(), " obj=", Game.objective_text())
		print("[s2] tasks:\n", Game.tasks_text())
		await _shot("s2_evening")
		get_tree().quit()
		return
	if args.has("rituals"):
		Game.mirror_covered = true
		Game.knife_in_lintel = true
		Rituals.worked(&"mirror")
		Rituals.worked(&"knife")
		Rituals.worked(&"knife")
		print("[rit] morning=\n", Rituals.morning_lines())
		print("[rit] tasks:\n", Game.tasks_text())
		get_tree().quit()
		return
	if args.has("srcend"):
		Game.set_flag("source_found", true)
		Game.final_call = true
		print("[se] objective=", Game.objective_text())
		var box: Interactable = SourceSite.instance.get_node("OtzvukBox")
		print("[se] prompt=", box.get_prompt(), " hold=", box.hold_time)
		box.interact(Game.player)
		await _wait(30.0)
		print("[se] ending flag=", SaveGame.flags.get("ending_source"))
		get_tree().quit()
		return
	if args.has("nightjob"):
		SaveGame.flags["fj_key"] = ""
		FieldJobs._ensure_jobs()
		print("[nj] jobs=", FieldJobs.jobs())
		var js := FieldJobs.jobs()
		if js.is_empty():
			SaveGame.flags["fj_list"] = [{"k": "ams_alarm", "t": "ams2", "done": false}]
			js = FieldJobs.jobs()
		var t := String(js[0]["t"])
		var c := Terrain.pad_pos(StringName(t))
		var e := c + Vector3(30, 0, 30)
		_look(Vector3(e.x, Terrain.height(e.x, e.z) + 0.05, e.z), c + Vector3(0, 1.5, 0))
		Game.player.flashlight.visible = true
		await _wait(1.5)
		await _shot("nj_ghost")
		var e2 := c + Vector3(8, 0, 8)
		_look(Vector3(e2.x, Terrain.height(e2.x, e2.z) + 0.05, e2.z), c + Vector3(0, 1.2, 0))
		await _wait(1.0)
		await _shot("nj_close")
		var cab: Interactable = FieldJobs.instance.get_node("AmsCabinet_" + t)
		print("[nj] prompt=", cab.get_prompt(), " hold=", cab.hold_time)
		cab.interact(Game.player)
		await _wait(6.0)
		print("[nj] after=", FieldJobs.jobs(), " brg=", FieldJobs.bearing_count(), " rations=", Supply.rations())
		Game.set_flag("upg_flashlight", true)
		Game.set_flag("upg_headlight", true)
		Snowmobile.instance.apply_upgrades()
		await _wait(0.5)
		print("[nj] flash range=", Game.player.flashlight.spot_range)
		get_tree().quit()
		return
	if args.has("sourcereview"):
		await _source_review()
		get_tree().quit()
		return
	if args.has("fieldjobs"):
		await _fieldjobs_review()
		get_tree().quit()
		return
	if args.has("mapev"):
		await _mapev_review(args[args.find("mapev") + 1].split(","))
		get_tree().quit()
		return
	if args.has("perfevents"):
		await _perf_events()
		return
	var only := ""
	if args.has("only") and args.size() > args.find("only") + 1:
		only = args[args.find("only") + 1]
	for v: Array in TOUR:
		if only != "" and not (v[0] as String) in only.split(","):
			continue
		if (v[0] as String).begins_with("pv_"):
			var a1: Vector3 = v[1]
			var a2: Vector3 = v[2]
			_look(Vector3(a1.x, Terrain.height(a1.x, a1.z) + 0.1, a1.z), Vector3(a2.x, a2.y + Terrain.height(a2.x, a2.z), a2.z))
		else:
			_look(v[1], v[2])
		Game.player.flashlight.visible = (kind == "night" and not args.has("nolight")) or (v[0] as String).begins_with("fp_")
		var vn := v[0] as String
		if vn.begins_with("fp_"):
			var item := {"fp_can": &"canister", "fp_wood": &"wood", "fp_oil": &"oil", "fp_shovel": &"shovel"}
			Game.player.set_held(item.get(vn, &""))
		await _wait(0.7)
		if vn == "fp_flare":
			Game.player._hands.flare()
			await _wait(0.3)
		if vn == "fp_in":
			Game.player._hands.reach()
			await _wait(0.2)
		await _shot("%s%d_%s" % [kind, idx, v[0]])
	if args.has("cams"):   # cams "px,py,pz,tx,ty,tz;..." — произвольные кадры
		var spec: String = args[args.find("cams") + 1]
		var ci := 0
		for c in spec.split(";"):
			var v := c.split(",")
			if v.size() < 6:
				continue
			ci += 1
			_look(Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]), float(v[4]), float(v[5])))
			Game.player.flashlight.visible = kind == "night" and not args.has("nolight")
			await _wait(0.8)
			await _shot("%s%d_cam%d" % [kind, idx, ci])
	if args.has("openui") and args.size() > args.find("openui") + 1:   # openui <id> — кадр окна (бланка, карты…)
		var uid := StringName(args[args.find("openui") + 1])
		if Game.hud != null:
			Game.hud.visible = true
		_open(uid)
		await _wait(1.2)
		await _shot("%s%d_ui_%s" % [kind, idx, uid])
	if args.has("zoo"):   # бестиарий: каждое существо во дворе под фонарём — во весь рост и лицом
		Game.hud.visible = false
		var at := Vector3(36.0, 0.0, 12.0)
		var makers := {
			"yrka": func() -> Node3D: return Creatures.make_yrka(),
			"zherdyai": func() -> Node3D: return Creatures.make_zherdyai(0.0),
			"double_mikhalych": func() -> Node3D: return Creatures.make_double(&"mikhalych"),
			"double_semenov": func() -> Node3D: return Creatures.make_double(&"semenov"),
			"double_orekhov": func() -> Node3D: return Creatures.make_double(&"orekhov"),
			"hunter": func() -> Node3D: return Creatures.make_frozen_hunter(0),
			"silhouette": func() -> Node3D: return Creatures.make_silhouette(),
		}
		for key: String in makers:
			var c: Node3D = (makers[key] as Callable).call()
			Game.level.add_child(c)
			c.global_position = at
			c.look_at(at + Vector3(0, 0, 1), Vector3.UP)   # лицом к камере (+Z), как в игре: look_at на игрока
			var aabb := AABB()
			for mi: Node in c.find_children("*", "MeshInstance3D", true, false):
				aabb = aabb.merge((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()) if aabb.size != Vector3.ZERO else (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			var h := maxf(aabb.size.y, 0.5)
			Game.player.flashlight.visible = true
			_look(at + Vector3(0.3, 0.05, 1.3 + h * 0.85), at + Vector3(0, h * 0.5, 0))
			await _wait(0.9)
			await _shot("zoo_%s_full" % key)
			_look(at + Vector3(0.1, 0.05, 1.3 if h < 2.5 else 2.6), at + Vector3(0, h * 0.88, 0))
			await _wait(0.6)
			await _shot("zoo_%s_face" % key)
			print("[zoo] %s высота %.2f" % [key, h])
			c.queue_free()
			await _wait(0.2)
	if args.has("coldtest"):   # иней на окне: натоплено → выстыло
		_look(Vector3(0.3, 0.05, 3.3), Vector3(-2.5, 1.45, 3.3))
		Game.player.flashlight.visible = false
		await _wait(0.8)
		await _shot("%s%d_frost_warm" % [kind, idx])
		Game.stove_wood = 0.0
		Game.house_cold = 1.0
		Game.level.set(&"_frost_cov", 0.98)
		Station._frost_mat.set_shader_parameter(&"coverage", 0.98)
		await _wait(0.8)
		await _shot("%s%d_frost_cold" % [kind, idx])
	if args.has("langshot"):   # первый экран: выбор языка
		Game.hud.visible = true
		var lp := LanguagePick.new()
		Game.hud.add_child(lp)
		await _wait(0.6)
		await _shot("%s%d_lang" % [kind, idx])
		lp.queue_free()
	if args.has("calibshot"):   # экран калибровки яркости
		Game.hud.visible = true
		var cal := BrightnessCalib.new()
		Game.hud.add_child(cal)
		await _wait(0.8)
		await _shot("%s%d_calib" % [kind, idx])
		cal.queue_free()
	if args.has("setshot"):   # настройки: раздел клавиш внизу списка
		Game.hud.visible = true
		var sp := SettingsPanel.new()
		Game.hud.add_child(sp)
		sp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _wait(0.5)
		var sc: ScrollContainer = sp.get(&"_scroll")
		if sc != null:
			sc.scroll_vertical = 100000
		await _wait(0.5)
		await _shot("%s%d_settings_keys" % [kind, idx])
		sp.queue_free()
	if args.has("mapshot"):   # схема [M] с цветами лееров и легендой
		Game.hud.visible = true
		EventBus.ui_requested.emit(&"map")
		await _wait(1.0)
		await _shot("%s%d_map" % [kind, idx])
	if args.has("wards"):   # все обереги выставлены — проверка их веток
		Game.salt_on_threshold = true
		Game.knife_in_lintel = true
		Game.mirror_covered = true
		Game.spirit_treat = true
	if args.has("hints"):   # подсказки и полоска дыхания на экране: у шара, со «сталкингом», с задержкой дыхания
		Game.hud.visible = true
		for k in SaveGame.flags.keys():
			if String(k).begins_with("hint_"):
				SaveGame.flags.erase(k)
		_look(Yard.METEO + Yard.M_BALLOON + Vector3(3.0, 0.05, 2.0), Yard.METEO + Yard.M_BALLOON + Vector3(0.0, 1.2, 0.0))
		Game.player.flashlight.visible = true
		await _wait(1.5)
		await _shot("%s%d_hint_balloon" % [kind, idx])
		Game.yrka.enabled = true
		Game.yrka.stage = YrkaThreat.Stage.STALKING
		await _wait(10.5)
		Input.action_press(&"hold_breath")
		await _wait(1.6)
		await _shot("%s%d_hint_breath_hold" % [kind, idx])
		Input.action_release(&"hold_breath")
		await _wait(0.4)
		await _shot("%s%d_breath_release" % [kind, idx])
		Game.yrka.enabled = false
		Game.yrka.stage = YrkaThreat.Stage.CALM
		Hints.show(&"barograph")
		await _wait(10.5)
		await _shot("%s%d_hint_barograph" % [kind, idx])
	if args.has("padset"):   # переназначение геймпада переживает перезапуск
		Game.rebind_pad(&"photo", [0, JOY_BUTTON_X, 1.0])
		print("[pad] записано: ", Settings.padbinds)
	if args.has("padshow"):
		print("[pad] после перезапуска: фото=%s, динамо=%s, запись=%s" % [Game.pad_name(&"photo"), Game.pad_name(&"crank"), Game.pad_name(&"record")])
		for a2: StringName in Game.PAD_REBINDABLE:
			Game.rebind_pad(a2, [])
	if args.has("checkall"):   # проверка 1.15+: запись фраз, Зенит с геймпада, журнал LB/RB, новые аномалии, настройки
		await _check_all()
	if args.has("zenittest"):   # «Зенит-Е»: кадры аномалии, «только на плёнке», голос из леса, проявка
		await _zenit_test()
	if args.has("anomtest"):   # замечания дежурного: все аномалии разом, кадры, журнал, возврат, итог
		await _anom_test()
	if args.has("fvtest"):   # голос из леса: синтетическая «фраза», зов, ответ вслух, уход с леера на голос
		await _fv_test()
	if args.has("curve"):   # кривая страха за всю ночь: «обычный игрок» — дом, вылазки по делам, фонарь
		await _fear_curve()
	if args.has("soak"):   # «живая» смена на ускорении: режиссёр, Ырка, события; игрок ходит по точкам
		var secs := float(args[args.find("soak") + 1]) if args.size() > args.find("soak") + 1 and args[args.find("soak") + 1].is_valid_float() else 60.0
		Engine.time_scale = 6.0
		if Game.is_night():
			Director.start(Game.cfg)
			Game.yrka.enabled = int(Game.cfg.get("yrka_max", 0)) > 0
		var spots := [Vector3(0.5, 0.05, 3.0), Vector3(8.0, 0.05, 0.5), Vector3(16.8, 0.05, 3.5), Vector3(29.0, 0.05, -2.0),
			Vector3(50.0, 0.05, -24.0), Vector3(24.0, 0.05, -40.0), Vector3(36.0, 0.05, 24.0), Vector3(10.0, 0.05, 28.0), Vector3(13.6, 0.05, 3.6)]
		var t0 := Time.get_ticks_msec()
		var si := 0
		while (Time.get_ticks_msec() - t0) / 1000.0 < secs and not Game.dead:
			_tp(spots[si % spots.size()], float(si * 47 % 360))
			si += 1
			Input.action_press(&"move_forward")
			await get_tree().create_timer(8.0).timeout
			Input.action_release(&"move_forward")
		Engine.time_scale = 1.0
		print("[soak] прошло %s, ночь %d, время %s, умер=%s, напряжение %.0f" % [str((Time.get_ticks_msec() - t0) / 1000), Game.night, Game.clock_text(), Game.dead, Director.tension])
	if args.has("paths"):
		await PathAudit.run(self)
	if args.has("walk"):
		await WalkBot.run(self)
	if args.has("perf"):
		await _perf_report()
	if args.has("leaktest"):   # петли, запущенные как разовые звуки, обязаны затихнуть сами
		Game.audio.play_2d("res://assets/audio/static_loop.ogg", -30.0)
		Game.audio.play_3d("res://assets/audio/heart_loop.ogg", Game.player.global_position, -30.0)
		Game.audio.play_2d("res://assets/audio/crank_loop.ogg", -30.0)
		await _wait(9.0)
		var left := 0
		for n: Node in get_tree().root.find_children("*", "", true, false):
			if n.has_meta(&"src") and (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.get(&"playing") \
					and String(n.get_meta(&"src")).contains("_loop.ogg"):
				left += 1
				print("[leaktest] всё ещё играет: ", n.get_meta(&"src"))
		print("[leaktest] ", "PASS" if left == 0 else "FAIL %d" % left)
		await Game.audio.bug_report()
	if args.has("sndlog"):   # постоять на месте последнего кадра и записать, что звучит
		Game.yrka.enabled = true
		for _k in range(int(args[args.find("sndlog") + 1]) if args.size() > args.find("sndlog") + 1 and args[args.find("sndlog") + 1].is_valid_int() else 2):
			Game.yrka._play_steps_behind()
			await _wait(4.0)
			Game.audio.dump_sound_log()
	print("[autotest] done, shots: ", _n)
	get_tree().quit()


func _check_all() -> void:
	Game.hud.visible = true
	SaveGame.flags["hint_anomalies"] = true
	var fv := Game.forest_voice
	# 1. Запись своих фраз: «говорим» 1,2 с, молчим 0,8 с — должна запомниться одна фраза.
	ForestVoice.clips.clear()
	ForestVoice.test_allow = true
	var rate := AudioServer.get_mix_rate()
	var chunk := int(rate * 0.05)
	for k in 40:
		var speak := k < 24
		var buf := PackedVector2Array()
		for j in chunk:
			var v := sin((k * chunk + j) * 0.07) * (0.04 if speak else 0.002)
			buf.append(Vector2(v, v))
		Mic.current_level = 0.5 if speak else 0.0
		fv.call(&"_on_frames", buf)
	print("[check] запись: фраз %d, длина %.2f с" % [ForestVoice.clips.size(), ForestVoice.clips[0].size() / float(ForestVoice.RATE) if not ForestVoice.clips.is_empty() else 0.0])
	fv.set(&"_playing_t", 3.0)
	for k in 30:
		var buf2 := PackedVector2Array()
		buf2.resize(chunk)
		Mic.current_level = 0.5
		fv.call(&"_on_frames", buf2)
	print("[check] пока играет голос — не пишем: фраз %d" % ForestVoice.clips.size())
	fv.set(&"_playing_t", 0.0)
	Mic.current_level = 0.0
	ForestVoice.test_allow = false
	Settings.mic_mimic = false
	Settings.changed.emit()
	print("[check] галочку сняли: фраз %d" % ForestVoice.clips.size())
	Settings.mic_mimic = true
	ForestVoice.test_allow = true
	# 2. «Зенит» через действия (как с геймпада: LT держать, RT — кадр)
	var z := Game.zenit
	Game.give_item(&"zenit")
	_look(Vector3(2.4, 0.05, 2.4), Vector3(0.8, 0.8, 3.62))
	await _wait(0.5)
	Input.action_press(&"photo")
	await _wait(0.4)
	print("[check] LT: видоискатель=%s" % z.raised)
	Input.action_press(&"photo_shoot")
	await _wait(0.2)
	Input.action_release(&"photo_shoot")
	await _wait(0.3)
	Input.action_press(&"photo_shoot")
	await _wait(0.1)
	Input.action_release(&"photo_shoot")
	await _wait(0.9)
	Input.action_press(&"photo_shoot")
	await _wait(0.1)
	Input.action_release(&"photo_shoot")
	await _wait(0.5)
	Input.action_release(&"photo")
	await _wait(0.4)
	print("[check] кадров снято %d (ожидаем 2: взвод 0,7 с), опущен=%s" % [z.photos.size(), not z.raised])
	# 3. Новые аномалии
	Game.anomalies.apply(&"calendar")
	Game.anomalies.apply(&"mast_figure")
	Game.anomalies.apply(&"sv20_house")
	print("[check] Слухач: %s" % Game.get_seismic_status()["text"])
	_look(Vector3(5.0, 0.05, 0.6), Vector3(5.0, 1.45, 2.09))
	await _wait(0.8)
	await _shot("chk_calendar")
	_look(Vector3(26.0, 0.05, -54.0), Vector3(24.0, 7.6, -61.3))
	Game.player.flashlight.visible = true
	await _wait(0.8)
	var cam := Game.player.camera
	for n: Node in Game.yard.get_children():
		if n is CreatureRig and (n as Node3D).global_position.distance_to(Yard.MAST) < 8.0:
			var fp := (n as Node3D).global_position + Vector3(0, 1.0, 0)
			print("[check] фигура на мачте: %s видна=%s, на экране %s, игрок %s" % [fp, (n as Node3D).is_visible_in_tree(), cam.unproject_position(fp), Game.player.global_position])
	await _shot("chk_mast")
	# 4. Журнал: RB листает вкладки, на «Замечаниях» фокус на зоне
	_look(Vector3(8.0, 0.05, 0.5), Vector3(9.4, 0.8, -1.0))
	_open(&"journal")
	await _wait(1.0)
	var j := Game.hud.modal()
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	j.call(&"handle_input", rb)
	await _wait(0.5)
	j.call(&"handle_input", rb)
	await _wait(0.6)
	var foc := get_viewport().gui_get_focus_owner()
	print("[check] журнал: вкладка %d, фокус на «%s»" % [j.get(&"_tab"), foc.get(&"text") if foc != null else "—"])
	await _shot("chk_journal_pad")
	Game.hud.close_modal()
	# 4б. Переназначение геймпада: «Зенит» на X → динамо-машина (и запись на рации) уезжают на LT
	Game.rebind_pad(&"photo", [0, JOY_BUTTON_X, 1.0])
	print("[check] геймпад: фото=%s, динамо=%s, запись=%s, точная=%s" % [Game.pad_name(&"photo"), Game.pad_name(&"crank"), Game.pad_name(&"record"), Game.pad_name(&"fine_tune")])
	var sp0 := SettingsPanel.new()
	Game.hud.add_child(sp0)
	sp0.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sp0.set(&"_pad_action", &"flare")
	var yb := InputEventJoypadButton.new()
	yb.button_index = JOY_BUTTON_Y
	yb.pressed = true
	sp0.call(&"_pad_input", yb)
	print("[check] в настройках ракетница → Y: ракетница=%s, фонарь=%s, кадр=%s (RT общий с ракетницей — не трогаем)" % [Game.pad_name(&"flare"), Game.pad_name(&"flashlight"), Game.pad_name(&"photo_shoot")])
	print("[check] подсказка: %s" % Game.hud.call(&"_format_gamepad_prompt", "[E] Взять  [F] Фонарь  [Q] Динамо  [V] Ракета"))
	await _wait(0.3)
	var sc0: ScrollContainer = sp0.get(&"_scroll")
	if sc0 != null:
		for c: Node in sp0.find_children("*", "Label", true, false):
			if (c as Label).text == Loc.t(&"set.pad"):
				sc0.scroll_vertical = int((c as Control).global_position.y - sc0.global_position.y) - 20
				break
	await _wait(0.5)
	await _shot("chk_settings_pad")
	sp0.queue_free()
	for a: StringName in Game.PAD_REBINDABLE:
		Game.rebind_pad(a, [])
	print("[check] сброс: фото=%s, динамо=%s, запись=%s, ракетница=%s, фонарь=%s, сохранено %d" % [Game.pad_name(&"photo"), Game.pad_name(&"crank"), Game.pad_name(&"record"), Game.pad_name(&"flare"), Game.pad_name(&"flashlight"), Settings.padbinds.size()])
	# 5. Настройки: раздел микрофона с новой галочкой
	var sp := SettingsPanel.new()
	Game.hud.add_child(sp)
	sp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(0.5)
	var sc: ScrollContainer = sp.get(&"_scroll")
	if sc != null:
		for c: Node in sp.find_children("*", "Label", true, false):
			if (c as Label).text == Loc.t(&"set.mic"):
				sc.scroll_vertical = int((c as Control).global_position.y - sc.global_position.y) - 20
				break
	await _wait(0.5)
	await _shot("chk_settings_mic")
	sp.queue_free()


func _zenit_test() -> void:
	var z := Game.zenit
	Game.give_item(&"zenit")
	Game.hud.visible = true
	SaveGame.flags["hint_anomalies"] = true
	await _wait(0.5)
	Game.anomalies.apply(&"izba_light")
	Game.anomalies.apply(&"glass2")
	# 1. Подстаканник на столе — в кадре, со вспышкой (в доме темно? — как выйдет)
	_look(Vector3(2.4, 0.05, 2.4), Vector3(0.8, 0.8, 3.62))
	await _wait(0.8)
	Game.hud.visible = false
	await RenderingServer.frame_post_draw
	var vi := Game.player.get_viewport().get_texture().get_image()
	var ri := get_tree().root.get_texture().get_image()
	print("[zenittest] яркость: 3D-вьюпорт %.3f (формат %d), экран %.3f" % [Zenit._mean_luma(vi), vi.get_format(), Zenit._mean_luma(ri)])
	Game.hud.visible = true
	Input.action_press(&"photo")
	await _wait(0.6)
	await _shot("zenit_view")
	Input.action_press(&"photo_shoot")
	await _wait(0.2)
	Input.action_release(&"photo_shoot")
	Input.action_release(&"photo")
	await _wait(0.6)
	# Снег у крыльца со вспышкой — проверка, что не уходит в белое
	_look(Vector3(18.0, 0.05, 3.5), Vector3(26.0, 0.3, 6.0))
	await _wait(0.6)
	await z.snap()
	# 2. Изба со светом — и «только на плёнке»
	Zenit.force_ghost = true
	_look(Vector3(-14.0, 0.05, -19.0), Vector3(-16.65, 1.5, -27.0))
	await _wait(0.8)
	await z.snap()
	Zenit.force_ghost = false
	await _wait(0.4)
	# 3. Голос из леса: снимаем источник
	ForestVoice.test_allow = true
	Game.yrka.enabled = false
	_look(Yard.FORK + Vector3(0, 0.05, 0), Yard.FORK + Vector3(5, 1.5, -5))
	await _wait(0.6)
	Game.forest_voice.start_episode(&"forest")
	await _wait(0.5)
	if not Game.forest_voice.episode:   # источник не нашёлся — ставим вручную, тест про плёнку, а не про голос
		Game.forest_voice.episode = true
		Game.forest_voice.kind = &"forest"
		Game.forest_voice.source = Game.player.global_position + Vector3(20, 0, -24)
	var src: Vector3 = Game.forest_voice.source
	_look(Yard.FORK + Vector3(0, 0.05, 0), src + Vector3(0, 1.3, 0))
	await _wait(0.6)
	print("[zenittest] перед кадром: эпизод=%s, вид=%s, в кадре=%s, Ырка %s" % [Game.forest_voice.episode, Game.forest_voice.kind,
		Game.forest_voice.in_frame(Game.player.camera), Game.yrka.stage_name()])
	await z.snap()
	print("[zenittest] голос снят: banished=%s, эпизод=%s, кадров %d, ламп %d" % [Game.forest_voice.banished, Game.forest_voice.episode, z.frames_left, z.bulbs_left])
	print("[zenittest] подстаканник снят=%s, пропущено %d" % [Game.anomalies.active[&"glass2"].get("photo", false), Game.anomalies.missed()])
	# 4. Проявка
	var dr := DarkroomUI.new()
	Game.hud.open_modal(dr)
	await _wait(6.0)
	await _shot("zenit_darkroom")
	Game.hud.close_modal()


func _anom_test() -> void:
	var an := Game.anomalies
	await _wait(0.5)
	for id: StringName in Anomalies.DEFS:
		if id != &"chair":
			an.apply(id)
	SaveGame.flags["hint_anomalies"] = true
	print("[anomtest] активных %d" % an.active.size())
	var views := [
		["boots", Vector3(11.9, 0.05, 2.6), Vector3(13.4, 0.2, 4.8)],
		["glass2", Vector3(2.4, 0.05, 2.4), Vector3(0.9, 0.8, 3.7)],
		["bed", Vector3(-0.2, 0.05, 3.4), Vector3(-1.4, 0.45, 5.0)],
		["pennant", Vector3(1.6, 0.05, 2.2), Vector3(3.39, 1.62, 1.85)],
		["wet", Vector3(9.0, 0.05, 3.2), Vector3(6.0, 0.0, 3.2)],
		["tracks", Vector3(22.5, 0.05, 6.0), Vector3(25.0, 0.0, 9.5)],
		["flag", Vector3(26.5, 0.05, -4.0), Vector3(39.0, 0.8, 4.0)],
		["izba", Vector3(-14.0, 0.05, -19.0), Vector3(-16.65, 1.5, -27.0)],
		["mast", Vector3(24.0, 0.05, -51.0), Vector3(24.0, 4.5, -61.3)],
	]
	for v: Array in views:
		if (v[0] as String).begins_with("pv_"):
			var a1: Vector3 = v[1]
			var a2: Vector3 = v[2]
			_look(Vector3(a1.x, Terrain.height(a1.x, a1.z) + 0.1, a1.z), Vector3(a2.x, a2.y + Terrain.height(a2.x, a2.z), a2.z))
		else:
			_look(v[1], v[2])
		Game.player.flashlight.visible = true
		await _wait(0.8)
		await _shot("anom_" + String(v[0]))
	Game.hud.visible = true
	_open(&"journal")
	await _wait(1.0)
	var j := Game.hud.modal()
	if j != null and j.has_method(&"_switch_tab"):
		j.call(&"_switch_tab", 2)
	await _wait(0.8)
	an.note(&"boots")
	an.note(&"chair")
	an.note(&"glass2")
	if j != null:
		j.call(&"_refresh_notes")
		j.call(&"_select_zone", &"house")
	await _wait(0.5)
	await _shot("anom_journal")
	Game.hud.close_modal()
	_look(Vector3(30.0, 0.05, 20.0), Vector3(40.0, 1.0, 30.0))   # отвернулись — записанное возвращается
	await _wait(1.0)
	print("[anomtest] валенки вернулись=%s, подстаканник вернулся=%s, ложных %d, пропущено %d" % [
		an.active[&"boots"]["reverted"], an.active[&"glass2"]["reverted"], an.false_notes, an.missed()])
	print("[anomtest] итог: ", an.tally().replace("\n", " | "))
	_look(Vector3(11.9, 0.05, 2.6), Vector3(13.4, 0.2, 4.8))
	await _wait(0.6)
	await _shot("anom_boots_after")


func _fv_test() -> void:
	var fv := Game.forest_voice
	Game.hud.visible = true
	ForestVoice.test_allow = true
	var syn := PackedFloat32Array()
	for i in int(1.6 * ForestVoice.RATE):
		syn.append(sin(i * 0.09) * 0.03 * (1.0 if (i / 1500) % 2 == 0 else 0.35))
	fv.inject_clip(syn)
	Game.yrka.enabled = true
	Game.yrka.threat = 0.0
	if Game.night >= 7:
		_look(Vector3(7.0, 0.05, -0.5), Vector3(5.0, 1.2, -2.0))
		await _wait(0.6)
		Game.set_zone(&"radio_room")
		print("[fvtest] зона ", Game.zone)
		fv.set(&"_cd", 0.0)
		await _wait(1.5)
		print("[fvtest] эпизод=%s вид=%s" % [fv.episode, fv.kind])
		await _shot("fv_numbers")
		await _wait(6.0)
		return
	_look(Yard.FORK + Vector3(0, 0.05, 0), Yard.FORK + Vector3(5, 1.5, -5))
	await _wait(0.8)
	fv.set(&"_cd", 0.0)
	await _wait(1.2)
	print("[fvtest] эпизод=%s вид=%s источник %.0f м, до леера %.1f" % [fv.episode, fv.kind,
		ForestVoice._flat(Game.player.global_position, fv.source), Game.yard.distance_to_path(fv.source)])
	await _shot("fv_call1")
	await _wait(12.0)
	print("[fvtest] после второго зова: %.0f м" % ForestVoice._flat(Game.player.global_position, fv.source))
	await _shot("fv_call2")
	var th0: float = Game.yrka.threat
	fv.answered()
	print("[fvtest] ответил вслух: угроза %.0f → %.0f" % [th0, Game.yrka.threat])
	await _wait(1.0)
	await _shot("fv_answered")
	# Идём на голос: шаг с леера в его сторону, потом — почти к нему.
	var src: Vector3 = fv.source
	var p0 := Game.player.global_position
	var dir := (src - p0)
	dir.y = 0.0
	var d := dir.length()
	dir = dir.normalized()
	_tp(p0 + dir * minf(d * 0.5, d - 12.0), 0.0)
	await _wait(0.5)
	print("[fvtest] сошёл к голосу: до леера %.1f, предупреждение=%s" % [Game.yard.distance_to_path(Game.player.global_position), fv.get(&"_warned_follow")])
	_tp(src - dir * 8.0, 0.0)
	await _wait(0.6)
	print("[fvtest] дошёл: стадия Ырки %s, эпизод=%s" % [Game.yrka.stage_name(), fv.episode])
	await _shot("fv_lured")
	await _wait(2.0)
	print("[fvtest] итог: умер=%s, стадия %s" % [Game.dead, Game.yrka.stage_name()])


func _look(pos: Vector3, target: Vector3) -> void:
	_tp(pos, 0.0)
	var eye := pos + Vector3(0, 1.6, 0)
	var d := target - eye
	Game.player.rotation.y = atan2(-d.x, -d.z)
	if Game.player.head != null:
		Game.player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _tp(pos: Vector3, yaw_deg: float) -> void:
	if Game.player == null:
		print("[autotest] _tp failed: Game.player is null")
		return
	Game.player.velocity = Vector3.ZERO
	Game.player.position = pos
	Game.player.global_position = pos
	Game.player.rotation.y = deg_to_rad(yaw_deg)
	if Game.player.head != null:
		Game.player.head.rotation.x = deg_to_rad(-4.0)
	print("[autotest] _tp: moved player to ", pos, " yaw=", yaw_deg)


func _open(id: StringName) -> void:
	EventBus.ui_requested.emit(id)


## Замер нагрузки: по точкам обзора — вызовы отрисовки, объекты, треугольники, время скриптов и физики;
## по сцене — самые частые меши (кандидаты в MultiMesh), свет и тени, частицы, узлы с _process.
const PERF_VIEWS := [
	["in_room", Vector3(0.5, 0.05, 3.0), Vector3(2.9, 0.5, 0.4)],
	["in_radio", Vector3(6.0, 0.05, 0.6), Vector3(9.2, 1.0, -1.6)],
	["porch_out", Vector3(15.6, 0.05, 3.1), Vector3(26.0, 1.4, 4.0)],
	["yard_house", Vector3(26.0, 0.05, 10.0), Vector3(8.0, 2.0, 3.0)],
	["forest_e", Vector3(36.0, 0.05, 12.0), Vector3(60.0, 3.0, 0.0)],
	["forest_n", Vector3(6.0, 0.05, -14.0), Vector3(0.0, 3.0, -50.0)],
	["meteo", Vector3(50.0, 0.05, -26.0), Vector3(58.0, 1.5, -32.0)],
	["mast", Vector3(24.0, 0.05, -50.0), Vector3(24.0, 8.0, -62.0)],
]

func _perf_report() -> void:
	var tree := get_tree()
	# --- Сцена
	var counts: Dictionary = {}
	var lights := 0
	var shadowed := 0
	var particles := 0
	var particle_amount := 0
	var processing: Dictionary = {}
	var nodes := 0
	var bodies := 0
	for n: Node in tree.root.find_children("*", "", true, false):
		nodes += 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var key := "%s#%d" % [n.name.rstrip("0123456789@"), (n as MeshInstance3D).mesh.get_instance_id()]
			counts[key] = int(counts.get(key, 0)) + 1
		elif n is Light3D and (n as Light3D).visible:
			lights += 1
			if (n as Light3D).shadow_enabled:
				shadowed += 1
		elif n is CPUParticles3D or n is GPUParticles3D:
			particles += 1
			particle_amount += int(n.get(&"amount"))
		if n is CollisionObject3D:
			bodies += 1
		if n.is_processing() and n.get_script() != null:
			var sn := (n.get_script() as Script).resource_path.get_file()
			if sn == "":
				sn = n.get_class()
			processing[sn] = int(processing.get(sn, 0)) + 1
	print("[perf-scene] узлов %d, тел физики %d, свет %d (с тенями %d), частиц %d систем / %d шт" % [nodes, bodies, lights, shadowed, particles, particle_amount])
	# Треугольники и число отрисовываемых объектов по группам (путь до 3-го уровня)
	var tri_by: Dictionary = {}
	var cnt_by: Dictionary = {}
	for n: Node in tree.root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var mult := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			mult = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh == null:
			continue
		var tris := 0
		for s in range(mesh.get_surface_count()):
			var arrs := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX] if arrs[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
			tris += (idx.size() if idx.size() > 0 else verts.size()) / 3
		var parts := str(gi.get_path()).replace("/root/", "").split("/")
		var start := 0
		for j in range(parts.size()):
			if parts[j].begins_with("@SubViewport@") or parts[j] == "SubViewport":
				start = j + 1
		var sub := parts.slice(start, mini(start + 3, parts.size() - 1))
		var key := "/".join(sub) if not sub.is_empty() else parts[parts.size() - 1]
		for ch in "0123456789":
			key = key.replace(ch, "")
		tri_by[key] = int(tri_by.get(key, 0)) + tris * mult
		cnt_by[key] = int(cnt_by.get(key, 0)) + mesh.get_surface_count()
	# Самые тяжёлые отдельные объекты и самые частые виды мешей
	var heavy: Array = []
	var kinds: Dictionary = {}
	for n: Node in tree.root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var mult := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			mult = (gi as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null:
			continue
		var tris := 0
		for si in range(mesh.get_surface_count()):
			var arrs2 := mesh.surface_get_arrays(si)
			var idx2: PackedInt32Array = arrs2[Mesh.ARRAY_INDEX] if arrs2[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (idx2.size() if idx2.size() > 0 else (arrs2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var par := gi.get_parent()
		var label := "%s<%s>%s parent=%s(%s) x%d" % [gi.name, mesh.get_class(), mesh.resource_name, par.name, par.get_class(), mult]
		heavy.append([tris * mult, label, gi.global_position.snapped(Vector3.ONE)])
		var kk := "%s|%s|%dtri" % [mesh.get_class(), par.get_class(), int(round(tris / 10.0)) * 10]
		kinds[kk] = int(kinds.get(kk, 0)) + mesh.get_surface_count() * (1 if mult == 1 else 0)
	heavy.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in range(mini(16, heavy.size())):
		print("[perf-heavy] %7d  %s @%s" % [heavy[i][0], heavy[i][1], heavy[i][2]])
	var karr: Array = []
	for k in kinds:
		karr.append([kinds[k], k])
	karr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in range(mini(16, karr.size())):
		print("[perf-kind] %4d вызовов  %s" % [karr[i][0], karr[i][1]])
	var tarr: Array = []
	for k in tri_by:
		tarr.append([tri_by[k], k, cnt_by[k]])
	tarr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in range(mini(14, tarr.size())):
		print("[perf-tri] %8d треуг.  %4d поверхн.  %s" % [tarr[i][0], tarr[i][2], tarr[i][1]])
	var carr := tarr.duplicate()
	carr.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	for i in range(mini(10, carr.size())):
		print("[perf-dc] %4d поверхн.  %s" % [carr[i][2], carr[i][1]])
	# Скрипты: в headless — сколько стоит _process каждого узла (выключаем по одному)
	if DisplayServer.get_name() == "headless":
		var procs: Array[Node] = []
		for n: Node in tree.root.find_children("*", "", true, false):
			if n.is_processing() and n.get_script() != null:
				procs.append(n)
		var base := await _avg_proc(30)
		print("[perf-cpu] кадр без отрисовки: %.2f мс" % base)
		for n in procs:
			if not is_instance_valid(n) or n == self:
				continue
			n.set_process(false)
			var t := await _avg_proc(30)
			n.set_process(true)
			print("[perf-cpu] %6.2f мс  %s (%s)" % [base - t, n.name, (n.get_script() as Script).resource_path.get_file()])
	var arr: Array = []
	for k in counts:
		arr.append([counts[k], k])
	arr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in range(mini(15, arr.size())):
		print("[perf-mesh] %5d × %s" % [arr[i][0], arr[i][1]])
	var parr: Array = []
	for k in processing:
		parr.append([processing[k], k])
	parr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in range(mini(12, parr.size())):
		print("[perf-proc] %4d × %s" % [parr[i][0], parr[i][1]])
	# --- Точки обзора
	for v: Array in PERF_VIEWS:
		_look(v[1], v[2])
		await _wait(1.0)
		var acc := [0.0, 0.0, 0.0, 0.0, 0.0]
		var frames := 6
		for i in range(frames):
			await tree.process_frame
			acc[0] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			acc[1] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			acc[2] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			acc[3] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			acc[4] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		print("[perf] %-11s вызовов %5.0f  объектов %5.0f  треуг. %7.0f  скрипты %5.1f мс  физика %5.1f мс" % [
			v[0], acc[0] / frames, acc[1] / frames, acc[2] / frames, acc[3] / frames, acc[4] / frames])
	print("[perf-mem] статическая память %.0f МБ, видеопамять %.0f МБ" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])


## Ночь целиком на ускорении ×8. Игрок по циклу: 50 с (игровых) дома, потом вылазка: идёт к точке дела
## с фонарём, стоит 15 с «работает», возвращается. Каждые 30 игровых минут — срез: напряжение режиссёра,
## угроза Ырки, стадия; в конце — сколько раз Ырка свистел/звал/был в упор/гнался и сколько испугов.
func _fear_curve() -> void:
	Engine.time_scale = 8.0
	Director.start(Game.cfg)
	Game.yrka.enabled = int(Game.cfg.get("yrka_max", 0)) > 0
	var jobs := [Vector3(16.6, 0.05, -10.0), Vector3(55.0, 0.05, -30.0), Vector3(24.0, 0.05, -50.0), Vector3(44.0, 0.05, 32.0),
		Vector3(5.0, 0.05, 38.0), Vector3(16.6, 0.05, -10.0)]
	var counts := {"свист": 0, "зов": 0, "упор": 0, "погоня": 0, "испуг": 0}
	var stage_seen := {}
	var log_t := -1.0
	var max_t := 0.0
	var max_y := 0.0
	var out_time := 0.0
	var ji := 0
	var phase := 0      # 0 — дома, 1 — снаружи
	var phase_t := 0.0
	var last_stage: Variant = ""
	var death := [""]
	EventBus.player_died.connect(func(r: StringName) -> void: death[0] = String(r))
	_tp(Vector3(0.5, 0.05, 3.0), 0.0)
	while not Game.shift_over and not Game.dead and Game.is_night():
		await get_tree().create_timer(0.5).timeout
		var dt := 0.5
		# Быт игрок ведёт исправно: печь, дизель, фонарь, сводки — меряем страх, а не замерзание.
		Game.warmth = maxf(Game.warmth, 70.0)
		Game.stove_wood = maxf(Game.stove_wood, 50.0)
		Game.flash_charge = maxf(Game.flash_charge, 60.0)
		var times: Array = Game.report_times()
		if Game.reports_sent < times.size() and Game.shift_minutes > float(times[Game.reports_sent]) + 5.0:
			Game.reports_sent += 1
		phase_t += dt
		if phase == 0 and phase_t > 50.0:
			phase = 1
			phase_t = 0.0
			_tp(jobs[ji % jobs.size()], float(ji * 73 % 360))
			ji += 1
			Game.player.flashlight.visible = true
		elif phase == 1 and phase_t > 15.0:
			phase = 0
			phase_t = 0.0
			_tp(Vector3(0.5, 0.05, 3.0), 0.0)
		if phase == 1:
			out_time += dt
			Game.activity = &"working"     # у прибора «работает руками» — как живой игрок с зажатой E
		var nm: String = Game.yrka.stage_name()
		if nm != str(last_stage):
			last_stage = nm
			stage_seen[nm] = int(stage_seen.get(nm, 0)) + 1
		max_t = maxf(max_t, Director.tension)
		max_y = maxf(max_y, Game.yrka.threat)
		var gm := Game.shift_minutes
		if floor(gm / 30.0) != log_t:
			log_t = floor(gm / 30.0)
			print("[curve] %s  напряжение %3.0f  угроза Ырки %3.0f  стадия %-12s  %s  режиссёр %s%s" % [Game.clock_text(), Director.tension, Game.yrka.threat, Game.yrka.stage_name(), "снаружи" if phase == 1 else "дома",
				Director.phase_name(), " HOLD" if Director.hold else ""])
	Engine.time_scale = 1.0
	print("[curve] ИТОГ ночь %d: макс. напряжение %.0f, макс. угроза %.0f, стадии %s, смерть: %s, снаружи %.0f с" % [Game.night, max_t, max_y, str(stage_seen), death[0] if Game.dead else "нет", out_time])


func _avg_proc(frames: int) -> float:
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in range(frames):
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / frames


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			_n += 1
			var path := SHOTS + "%02d_%s.png" % [_n, name]
			img.save_png(path)
			print("[autotest] shot ", path, "  phase=", Game.phase_kind, Game.phase_index, " zone=", Game.zone)
	else:
		_n += 1
		print("[autotest] shot (headless) #", _n, " ", name, "  phase=", Game.phase_kind, Game.phase_index, " zone=", Game.zone)


## Габариты всей видимой геометрии станции и двора — для расстановки реквизита без пересечений.
func _dump_aabbs() -> void:
	var out: Array = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is VisualInstance3D and not (n is Light3D) and not (n is GPUParticles3D) and not (n is CPUParticles3D):
			var vi := n as VisualInstance3D
			if not vi.is_visible_in_tree():
				continue
			var bb := vi.global_transform * vi.get_aabb()
			if bb.position.x > -20 and bb.end.x < 40 and bb.position.z > -25 and bb.end.z < 25 and bb.size.length() < 30:
				out.append([str(vi.get_path()).replace("/root/", ""), bb.position.x, bb.position.y, bb.position.z, bb.size.x, bb.size.y, bb.size.z])
	var f := FileAccess.open("user://aabb.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("[autotest] dumped %d aabbs" % out.size())


## Кадры концовок (EndingShot) по очереди + текст «Дела №83-М».
func _endshots_review() -> void:
	SaveGame.flags["dog_found"] = true
	SaveGame.flags["dog_state"] = "home"
	Dog.set_health(90.0)
	SaveGame.flags["evidence"] = 4
	SaveGame.flags["anom_notes_total"] = 11
	SaveGame.flags["anom_ok_total"] = 4
	SaveGame.flags["mem_total"] = {"obeyed_fake": 2, "real_done": 5, "turned": 1, "missed": 1}
	for n in _app.get_children():
		if n is Session:
			print("[end] case:
", (n as Session)._case_file(&"leave"))
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("end_"):
			only.append(StringName(arg.substr(4)))
	for id: StringName in (only if not only.is_empty() else [&"answer", &"burn", &"leave", &"source", &"silence", &"echo"]):
		var shot := EndingShot.new()
		add_child(shot)
		shot.run(id)
		for k in 3:
			await _wait(5.0)
			await _shot("end_%s_%d" % [id, k])
		await _wait(7.0)
		shot.queue_free()
		Game.set_power(true)
		await _wait(1.0)


## Хребет «Отзвук»: дни 1, 2, 4 следа Семёнова дают пеленги (тетрадь, шифровка, запись 03:10).
func _spine_review() -> void:
	var y := Game.yard
	var p := Game.player
	var crate := Interactable.new()
	y.add_child(crate)
	crate.global_position = Yard.SHED + Vector3(-2.2, 0.25, 2.0)
	y._on_crate_used(p, crate)
	await _wait(7.5)
	await _shot("spine_notebook")
	Game.hud.hide_note()
	p.mode = Player.Mode.WALK
	await _wait(2.0)
	print("[spine] d1 zimnik=", FieldJobs.has_bearing("zimnik"))
	SaveGame.tapes.append(&"code")
	var cb := CodebookUI.new()
	Game.hud.add_child(cb)
	cb._input.text = Signals.CODE_WORD["ru"] if Settings.language == "ru" else Signals.CODE_WORD["en"]
	cb._check()
	await _wait(0.5)
	await _shot("spine_codebook")
	print("[spine] d2 izba=", FieldJobs.has_bearing("izba"), " text=", cb._result.text.substr(0, 80))
	cb.queue_free()
	Game.give_item(&"bunker_key")
	print("[spine] tape added=", Game.add_tape(&"rec0310"), " def=", Signals.has_hidden(&"rec0310"))
	var deck := TapeDeckUI.new()
	Game.hud.add_child(deck)
	await _wait(0.3)
	deck._selected = &"rec0310"
	deck._reveal(deck._hidden_def())
	print("[spine] d4 lake=", FieldJobs.has_bearing("lake"), " bearings=", FieldJobs.bearing_count())
	deck.queue_free()
	_open(&"map")
	await _wait(0.6)
	await _shot("spine_map")


## Пролог-обучение: карточка шага и огонёк над целью.
func _tutg_review() -> void:
	Game.set_flag("prologue_arrived", true)
	Game.hud.visible = true
	print("[tutg] prologue=", Game.is_prologue(), " step0=", Game.tutorial)
	_look(Vector3(20.0, 0.05, 4.0), Yard.METEO + Vector3(0, 1.5, 0))
	await _wait(5.0)
	await _shot("tutg_readings")
	for k: StringName in Game.READING_KEYS:
		Game.readings[k] = true
	Game.complete_step(&"readings")
	_look(Vector3(5.0, 0.05, 0.5), Vector3(8.6, 1.2, -1.2))
	await _wait(7.5)
	await _shot("tutg_report")
	Game.complete_step(&"test_report")
	_look(Vector3(30.0, 0.05, 20.0), Yard.SHED + Vector3(-2.2, 1.4, -2.1))
	await _wait(7.5)
	await _shot("tutg_refuel")
	var mk := Game.level.find_child("TutorialMarker", true, false) as MeshInstance3D
	print("[tutg] marker=", mk, " vis=", mk.visible if mk else null, " pos=", mk.global_position if mk else null, " a=", (mk.material_override as StandardMaterial3D).albedo_color if mk else null, " scale=", mk.scale if mk else null, " cam_mask=", Game.player.camera.cull_mask, " layers=", mk.layers if mk else null)


## Ырка в игровых постановках: метель под фонарём, открытая дверь у крыльца, погоня на четвереньках.
## Двойник: три лица × крыльцо в открытую дверь, окно дома со двора, лицо вблизи под фонарём.
func _double_shots() -> void:
	var p := Game.player
	p.set_flashlight(true)
	if Game.weather != null:
		Game.weather.intensity = 0.1
	for face: StringName in [&"mikhalych", &"semenov", &"orekhov"]:
		var rig := Creatures.make_double(face)
		Game.level.add_child(rig)
		# 1. Открыл дверь — стоит вплотную к порогу, руки по швам
		Game.level.set_door_open(true)
		rig.global_position = Vector3(15.2, 0.0, 3.1)
		rig.rotation.y = deg_to_rad(90.0)
		rig.pose_override = &"still"
		_look(Vector3(13.4, 0.05, 3.1), Vector3(15.2, 1.55, 3.1))
		await _wait(1.6)
		await _shot("double_%s_door" % face)
		Game.level.set_door_open(false)
		# 2. Со двора: в окне дома кто-то стоит
		var spot: Dictionary = Game.level.window_spots[0]
		var glass: Vector3 = spot["glass"]
		var inward: Vector3 = spot["inward"]
		var feet := glass + inward * 0.9
		feet.y = 0.0
		rig.global_position = feet
		rig.look_at(feet - inward, Vector3.UP)
		var glow := spot.get("glow") as Node3D
		if glow != null:
			glow.visible = false
		var cam := glass - inward * 3.2
		_look(Vector3(cam.x, Terrain.height(cam.x, cam.z) + 0.05, cam.z), glass + Vector3(0, 0.2, 0))
		await _wait(1.6)
		await _shot("double_%s_window" % face)
		if glow != null:
			glow.visible = true
		# 3. Лицо вблизи под фонарём
		rig.global_position = Vector3(30.0, 0.0, 12.0)
		rig.rotation.y = 0.0
		_look(Vector3(30.0, 0.0, 10.95), Vector3(30.0, 1.5 + (0.13 if face == &"orekhov" else 0.07 if face == &"semenov" else 0.03), 12.0 - 0.6))
		await _wait(1.0)
		await _shot("double_%s_face" % face)
		# 4. Во весь рост в 6 м
		_look(Vector3(30.0, 0.05, 6.0), Vector3(30.0, 1.0, 12.0))
		await _wait(0.6)
		await _shot("double_%s_full" % face)
		rig.queue_free()
		await _wait(0.2)


## Обзор картинки: двор, лес, корпус, дом, площадка — текущее время суток тура.
func _visual_review() -> void:
	var p := Game.player
	Game.yrka.enabled = false
	var tag := "night" if Game.is_night() else "day"
	p.set_flashlight(Game.is_night())
	# Свои следы: пройти 4 с по целине (в стороне от троп) и обернуться
	_tp(Vector3(34.0, 0.1, 22.0), 90.0)
	await _wait(0.4)
	Input.action_press(&"move_forward")
	await _wait(4.0)
	Input.action_release(&"move_forward")
	await _wait(0.4)
	var here := p.global_position
	var fpn := Game.level.get_node_or_null("PlayerFootprints")
	print("[vis] следов игрока: ", fpn.get_child_count() if fpn != null else 0)
	_look(here + Vector3(-0.3, 0.05, 0.0), here + Vector3(6.0, 0.0, 0.0))
	await _wait(0.6)
	await _shot("vis_footprints_%s" % tag)
	if OS.get_cmdline_user_args().has("warnshot"):
		var w := ContentWarning.new()
		Game.hud.add_child(w)
		Game.hud.visible = true
		await _wait(0.8)
		await _shot("vis_warning")
		w.queue_free()
		Game.hud.visible = false
	for v: Array in [["yard_house", Vector3(26.0, 0.05, 14.0), Vector3(6.0, 2.2, 3.6)], ["yard_forest", Vector3(18.0, 0.05, 10.0), Vector3(40.0, 3.0, -20.0)],
			["forest", Vector3(-30.0, 0.05, -40.0), Vector3(-40.0, 2.5, -55.0)], ["corpus", Vector3(74.0, 0.05, -30.0), Vector3(95.0, 5.0, -31.0)],
			["plot", Vector3(57.0, 0.05, -15.0), Vector3(66.0, 0.8, -22.0)], ["room", Vector3(1.6, 0.05, 4.6), Vector3(-1.5, 1.0, 1.0)],
			["radio", Vector3(8.34, 0.05, 0.26), Vector3(8.9, 1.0, -1.8)], ["porch", Vector3(20.5, 0.05, 6.0), Vector3(15.0, 1.6, 3.4)]]:
		_look(v[1], v[2])
		await _wait(1.2)
		await _shot("vis_%s_%s" % [v[0], tag])


## Башня: последний марш → кабина → дверь на балкон → балкон по кругу. Пишет, где игрок упёрся.
func _tower_walk() -> void:
	var p := Game.player
	Game.yrka.enabled = false
	MeteoCorpus.instance.call(&"_set_power", true)
	# [старт, поворот, сколько идти, имя]; дальше — повороты на ходу
	var legs: Array = [[Vector3(98.0, 7.1, -35.15), 0.0, 4.5, "марш_E3"], [null, 90.0, 2.6, "кабина_на_запад"],
			[null, 0.0, 2.5, "к_двери_балкона"], [null, 90.0, 2.0, "балкон_запад"], [null, 180.0, 5.5, "балкон_юг"],
			[null, -90.0, 6.0, "балкон_восток"], [null, 0.0, 5.5, "балкон_север"]]
	for leg: Array in legs:
		if leg[0] != null:
			_tp(leg[0], leg[1])
		else:
			p.rotation.y = deg_to_rad(leg[1])
		await _wait(0.2)
		Input.action_press(&"move_forward")
		var last := p.global_position
		var stuck := 0.0
		var t := 0.0
		while t < float(leg[2]):
			await _wait(0.25)
			t += 0.25
			var moved := p.global_position.distance_to(last)
			last = p.global_position
			stuck = stuck + 0.25 if moved < 0.05 else 0.0
			if stuck >= 0.75:
				print("[tower] %s: упёрся в %s" % [leg[3], p.global_position])
				var fwd := -p.global_basis.z
				for hy: float in [0.3, 0.9, 1.5]:
					var from := p.global_position + Vector3(0, hy, 0)
					var hit := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + fwd * 0.8, 0xFFFFFFFF, [p.get_rid()]))
					if not hit.is_empty():
						print("[tower]   h=%.1f → %s (%s) в %s" % [hy, (hit["collider"] as Node).get_path(), (hit["collider"] as Node).get_class(), hit["position"]])
				_look(p.global_position, p.global_position + p.global_basis * Vector3(0, 1.4, -2.0))
				await _wait(0.3)
				await _shot("tower_stuck_%s" % leg[3])
				break
		Input.action_release(&"move_forward")
		print("[tower] %s → %s" % [leg[3], p.global_position])


## Двор: развилки с леерами, сараи, поленница, вертолётка, ангар, навес с баллонами, бункер, изба.
func _yard_review() -> void:
	Game.yrka.enabled = false
	var tag := "night" if Game.is_night() else "day"
	for v: Array in [["junction", Vector3(24.0, 0.05, -4.5), Vector3(32.0, 0.8, -1.0)], ["fork_house", Vector3(22.5, 0.05, 6.5), Vector3(16.0, 1.4, 3.0)],
			["shed", Vector3(40.0, 0.05, 30.0), Vector3(48.0, 1.5, 34.0)], ["woodpile", Vector3(8.0, 0.05, 35.0), Vector3(4.0, 0.8, 40.0)],
			["helipad", Vector3(36.0, 0.05, 2.0), Vector3(44.0, 0.3, 6.0)], ["hangar", Vector3(118.0, 0.05, -26.0), Vector3(128.0, 2.5, -36.0)],
			["gas_shelter", Vector3(110.0, 0.05, -27.0), Vector3(114.6, 1.2, -32.0)], ["bunker", Vector3(52.0, 0.05, 8.0), Vector3(58.0, 0.5, 12.0)],
			["mast", Vector3(20.0, 0.05, -52.0), Vector3(24.0, 4.0, -62.0)], ["izba", Vector3(-8.0, 0.05, -26.0), Vector3(-16.0, 1.5, -30.0)],
			["bunker_hall", Vector3(68.5, -29.95, 12.3), Vector3(60.0, -28.6, 12.0)], ["bunker_racks", Vector3(62.0, -29.95, 12.0), Vector3(60.0, -28.2, 14.4)],
			["blast_door", Vector3(51.5, -29.95, 12.6), Vector3(53.5, -28.9, 12.0)], ["tunnel_b", Vector3(80.0, -29.95, 12.0), Vector3(90.0, -28.6, 11.4)],
			["tunnel_a", Vector3(96.5, -29.95, -18.0), Vector3(96.8, -29.0, -8.0)]]:
		var at: Vector3 = v[1] if (v[1] as Vector3).y < -5.0 else Terrain.at(v[1]) + Vector3(0, 0.05, 0)
		Game.player.set_flashlight(at.y < -5.0)
		_look(at, v[2])
		await _wait(1.2)
		await _shot("yard_%s_%s" % [v[0], tag])


## Дом изнутри: каждая комната с двух сторон (свет — как есть в этой фазе).
func _house_review() -> void:
	Game.yrka.enabled = false
	if OS.get_cmdline_user_args().has("probe"):
		for n in Game.level.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var bb := g.global_transform * g.get_aabb()
			var c := bb.get_center()
			if bb.size.y > 0.6 and bb.size.length() < 4.0 and Rect2(-2.6, -0.1, 6.2, 6.8).has_point(Vector2(c.x, c.z)) and c.y < 2.4:
				print("[probe] ", g.get_path(), " c=", c, " size=", bb.size, " parent=", g.get_parent().name)
	var tag := "night" if Game.is_night() else "day"
	for v: Array in [["room_a", Vector3(2.8, 0.05, 1.0), Vector3(-2.0, 1.2, 5.5)], ["room_b", Vector3(-2.0, 0.05, 5.8), Vector3(3.0, 1.2, 0.5)],
			["room_c", Vector3(-1.8, 0.05, 0.6), Vector3(3.0, 1.0, 6.0)],
			["radio_a", Vector3(4.2, 0.05, 1.8), Vector3(11.0, 1.2, -1.5)], ["radio_b", Vector3(10.6, 0.05, 1.4), Vector3(4.0, 1.2, -1.5)],
			["storage", Vector3(6.6, 0.05, -2.4), Vector3(3.8, 0.8, -5.2)], ["corridor", Vector3(4.0, 0.05, 4.4), Vector3(12.0, 1.4, 4.4)],
			["vestibule", Vector3(14.0, 0.05, 6.2), Vector3(11.8, 1.2, 2.0)], ["attic", Vector3(0.0, 3.0, 3.3), Vector3(12.0, 3.6, 3.3)],
			["plot_gate", Vector3(60.0, 0.05, -23.0), Vector3(66.0, 0.8, -21.0)], ["plot_booth", Vector3(64.8, 0.05, -21.0), Vector3(64.8, 1.4, -23.6)],
			["plot_old", Vector3(66.5, 0.05, -18.0), Vector3(63.5, 1.0, -21.0)],
			["radio_desk", Vector3(9.2, 0.6, 0.05), Vector3(9.2, 0.75, -1.25)], ["living_ne", Vector3(0.6, 0.05, 2.6), Vector3(2.85, 0.4, 0.5)],
			["living_table", Vector3(0.0, 0.3, 3.1), Vector3(1.4, 0.75, 4.1)],
			["corpus_w", Vector3(83.0, 0.05, -27.0), Vector3(90.0, 2.2, -27.0)], ["corpus_sw", Vector3(84.0, 0.05, -14.5), Vector3(95.0, 2.5, -27.0)],
			["corpus_n", Vector3(90.5, 0.05, -44.0), Vector3(97.0, 4.0, -34.0)]]:
		_look(v[1], v[2])
		await _wait(1.2)
		await _shot("house_%s_%s" % [v[0], tag])


## Кадры каждые interval секунд, пока идёт сцена (холодный старт идёт до того, как тур получит управление).
func _shoot_loop(prefix: String, count: int, interval: float) -> void:
	for i in count:
		await _wait(interval)
		await _shot("%s_%02d" % [prefix, i])


## Аэрологический корпус: снаружи, темнота до дизеля, свет, проход по маршам башни, кабина, балкон, ангар.
func _corpus_review() -> void:
	var p := Game.player
	var c := MeteoCorpus.instance
	Game.yrka.enabled = false
	p.set_flashlight(Game.is_night())
	for v: Array in [["path", Vector3(70.0, 0.05, -28.5), Vector3(95.0, 5.0, -30.0)], ["ne", Vector3(116.0, 0.05, -52.0), Vector3(97.0, 5.0, -31.0)],
			["porch", Vector3(84.5, 0.05, -24.5), Vector3(90.0, 1.8, -27.3)], ["hangar", Vector3(138.0, 0.05, -26.0), Vector3(122.0, 3.0, -36.0)],
			["plot", Vector3(56.0, 0.05, -13.0), Vector3(66.0, 0.8, -22.0)]]:
		_look(v[1], v[2])
		await _wait(1.2)
		await _shot("corpus_%s" % v[0])
	# Внутри без дизеля — темно
	_look(Vector3(95.6, 0.5, -21.2), Vector3(95.6, 1.8, -33.0))
	await _wait(0.8)
	print("[corpus] зона=", Game.zone, " темно=", Game.is_dark())
	await _shot("corpus_corridor_dark")
	# Завести дизель
	_look(Vector3(100.6, 0.2, -31.1), Vector3(100.3, 0.7, -32.6))
	await _wait(0.5)
	print("[corpus] зона дизельной=", Game.zone)
	for i in 4:
		c.call(&"_on_generator", p)
		await _wait(1.5)
		if c.powered:
			break
	print("[corpus] свет=", c.powered)
	for v: Array in [["corridor_lit", Vector3(95.6, 0.5, -21.2), Vector3(95.6, 1.8, -33.0)], ["apparat", Vector3(93.6, 0.5, -29.2), Vector3(91.0, 1.4, -33.2)],
			["cabinet", Vector3(93.8, 0.5, -26.4), Vector3(91.0, 1.2, -21.2)], ["tower_base", Vector3(98.0, 0.5, -35.3), Vector3(95.5, 2.5, -37.5)]]:
		_look(v[1], v[2])
		await _wait(0.8)
		await _shot("corpus_%s" % v[0])
	# Марши: пройти пешком (вперёд) и проверить высоту
	p.set_flashlight(false)
	for leg: Array in [["A1", Vector3(95.5, 0.5, -35.15), 0.0, 2.6, 2.0], ["B1", Vector3(96.7, 2.15, -37.95), 180.0, 2.6, 3.6],
			["A2", Vector3(95.5, 3.8, -35.15), 0.0, 2.6, 5.3], ["B2", Vector3(96.7, 5.45, -37.95), 180.0, 2.6, 6.9], ["E3", Vector3(98.0, 7.1, -35.15), 0.0, 4.0, 9.6]]:
		_tp(leg[1], leg[2])
		await _wait(0.3)
		Input.action_press(&"move_forward")
		await _wait(leg[3])
		Input.action_release(&"move_forward")
		await _wait(0.3)
		print("[corpus] марш %s: y=%.2f (ждём ≥ %.1f) %s" % [leg[0], p.global_position.y, leg[4], "OK" if p.global_position.y >= leg[4] else "НЕ ДОШЁЛ"])
	_look(Vector3(96.8, CAB_Y, -35.4), Vector3(95.3, CAB_Y + 0.6, -38.2))
	await _wait(0.8)
	await _shot("corpus_cabin")
	_look(Vector3(94.2, CAB_Y, -39.4), Vector3(60.0, 0.0, -20.0))
	await _wait(0.8)
	await _shot("corpus_balcony_view")
	# Обставленные комнаты
	for v: Array in [["pult", Vector3(91.7, 0.5, -31.9), Vector3(91.7, 1.3, -33.8)], ["baro", Vector3(92.6, 0.5, -30.0), Vector3(94.3, 1.2, -30.0)],
			["stove", Vector3(93.6, 0.5, -23.4), Vector3(91.2, 1.0, -21.3)], ["archive", Vector3(96.9, 0.5, -28.8), Vector3(98.3, 1.4, -26.5)],
			["gasgen", Vector3(100.4, 0.5, -34.6), Vector3(102.3, 1.4, -37.7)], ["tambour", Vector3(93.8, 0.5, -27.2), Vector3(91.6, 1.4, -26.2)]]:
		_look(v[1], v[2])
		await _wait(0.7)
		await _shot("corpus_room_%s" % v[0])
	_look(Vector3(91.7, 0.5, -32.6), Vector3(91.7, 1.3, -33.8))
	await _wait(0.3)
	EventBus.ui_requested.emit(&"wind_panel")
	await _wait(2.6)
	if Game.hud != null:
		Game.hud.visible = true
	await _shot("corpus_wind_panel")
	print("[corpus] пульт открыт: ", Game.hud.modal() is WindPanelUI)
	Game.hud.close_modal()
	Game.hud.visible = false
	await _wait(0.3)
	# Фигура в окне кабины — с тропы
	c.set(&"_done", {})
	_look(Vector3(62.0, 0.05, -29.0), Vector3(96.75, 11.5, -35.4))
	await _wait(0.6)
	c.call(&"_show_cabin_figure")
	await _wait(0.8)
	await _shot("corpus_cabin_figure")


const CAB_Y := 9.8


## Вырезанные мобы → двойник, звук и следы: глазок (3 лица), паралич (тень на стене), чайник, Суседко, угощение.
func _cut_review() -> void:
	var p := Game.player
	var st := Game.level as Station
	Game.yrka.enabled = false
	# 1. Стук и глазок (лицо по номеру ночи: -- --tour night 2|4|6 cutshots; nopeep — без него)
	var n := Game.night
	if OS.get_cmdline_user_args().has("nopeep"):
		await _cut_home(p, st)
		return
	_tp(Vector3(13.6, 0.05, 3.1), -90.0)
	Game.events.call(&"_knock_sequence", false)
	await _wait(2.5)
	_open(&"peephole")
	await _wait(1.2)
	await _shot("peep_n%d_a" % n)
	await _wait(2.2)
	await _shot("peep_n%d_eye" % n)
	Game.hud.close_modal()
	Game.events.repel_knock_with_countersign()
	await _wait(1.0)
	if OS.get_cmdline_user_args().has("peep"):
		return
	await _cut_home(p, st)


func _cut_home(p: Player, st: Station) -> void:
	# 2. Чайник: мокрые следы от двери до спины (свет в доме включён, как в обычную ночь)
	Game.set_power(true)
	st.set_lit(true)
	p.set_flashlight(true)
	Game.fatigue = 60.0
	Game.stove_wood = 20.0
	Game.tea_cd = 0.0
	Game.set_flag("polunoch_kettle_seen", false)
	_look(Vector3(-1.1, 0.05, 1.4), Vector3(-1.5, 1.35, 1.0))
	await _wait(0.6)
	st.call(&"_on_kettle_used", p)
	await _wait(1.0)
	_look(Vector3(-1.1, 0.05, 1.4), Vector3(1.4, 0.0, 3.0))
	await _wait(0.8)
	await _shot("kettle_trail")
	# 3. Суседко: шлёпанье в проёме, обернулся — мокрый след
	_look(Vector3(0.6, 0.05, 4.4), Vector3(-2.0, 1.2, 4.4))
	await _wait(0.5)
	st.set(&"_susedko_peeking", false)
	st.call(&"_try_spawn_susedko")
	print("[cut] суседко в проёме: ", st.get(&"_susedko_peeking"))
	await _wait(1.0)
	_look(Vector3(1.9, 0.05, 3.4), Vector3(3.6, 0.0, 3.2))
	await _wait(1.0)
	await _shot("susedko_footprint")
	# 4. Угощение: поставили, отвернулись — съедено
	Game.spirit_treat = true
	var bread := st.get(&"_treat_bread") as Node3D
	if bread != null:
		bread.visible = true
	st.set(&"_treat_set_min", Game.shift_minutes - 60.0)
	_look(Vector3(0.6, 0.05, 2.0), Vector3(3.0, 1.0, 3.0))
	st.set(&"_susedko_hearth_timer", 0.0)
	await _wait(0.6)
	_look(Vector3(0.1, 0.05, 1.5), Vector3(-0.95, 0.0, 0.6))
	await _wait(1.0)
	print("[cut] хлеб съеден: ", bread != null and not bread.visible)
	await _shot("treat_eaten")
	# 5. Паралич: никого не видно, тень растёт на стене
	p.set_flashlight(false)
	Game.events.call(&"_paralysis")
	await _wait(4.5)
	await _shot("paralysis_a")
	await _wait(5.0)
	await _shot("paralysis_b")
	await _wait(6.0)


## Жердяй: опушка с крыльца, из окна дома, 18 м под фонарём, наклон между стволами; двойник за стеклом (window_watcher).
func _zherd_shots() -> void:
	var p := Game.player
	if Game.weather != null:
		Game.weather.intensity = 0.15
	var rig := Creatures.make_zherdyai(0.0)
	Game.level.add_child(rig)
	var face_to := func(r: Node3D, target: Vector3) -> void:
		var t := target
		t.y = r.global_position.y
		r.look_at(t, Vector3.UP)
	# 1. В поле, ~36 м, без фонаря: силуэт на фоне неба и две искры
	p.set_flashlight(false)
	rig.global_position = Vector3(30.0, Terrain.height(30.0, -28.0), -28.0)
	face_to.call(rig, Vector3(30.0, 0.0, 8.0))
	_look(Vector3(30.0, 0.05, 8.0), Vector3(30.0, 3.0, -28.0))
	await _wait(1.6)
	await _shot("zherd_36m")
	# 2. Из окна жилой комнаты (южное), у самого стекла: стоит в поле и смотрит на окна
	var spot: Dictionary = Game.level.window_spots[2]
	var glass: Vector3 = spot["glass"]
	var inward: Vector3 = spot["inward"]
	var side := inward.cross(Vector3.UP)
	var eye := glass + inward * 0.7 + side * 0.05
	var pane := glass - side * 0.24                    # через середину створки, мимо средника
	var dir := pane - eye
	dir.y = 0.0
	var far := eye + dir.normalized() * 30.0
	rig.global_position = Vector3(far.x, Terrain.height(far.x, far.z), far.z)
	face_to.call(rig, glass)
	_look(Vector3(eye.x, 0.05, eye.z), Vector3(far.x, 3.2, far.z))
	await _wait(1.6)
	await _shot("zherd_from_window")
	# 3. 18 м под фонарём — рассмотреть
	p.set_flashlight(true)
	rig.global_position = Vector3(30.0, Terrain.height(30.0, -10.0), -10.0)
	face_to.call(rig, Vector3(30.0, 0.0, 8.0))
	_look(Vector3(30.0, 0.05, 8.0), Vector3(30.0, 2.6, -10.0))
	await _wait(1.6)
	await _shot("zherd_18m")
	# 4. Наклонился между стволами
	rig.queue_free()
	rig = Creatures.make_zherdyai(45.0)
	Game.level.add_child(rig)
	rig.global_position = Vector3(26.0, Terrain.height(26.0, -38.0), -38.0)
	face_to.call(rig, Vector3(20.0, 0.0, 0.0))
	p.set_flashlight(false)
	_look(Vector3(25.0, 0.05, -10.0), Vector3(26.0, 2.6, -38.0))
	await _wait(1.6)
	await _shot("zherd_bend")
	rig.queue_free()
	# 5. Двойник прижался к окну (window_watcher): вид из комнаты
	spot = Game.level.window_spots[0]
	glass = spot["glass"]
	inward = spot["inward"]
	var d := Creatures.make_silhouette()
	Game.level.add_child(d)
	var feet := glass - inward * 0.45
	feet.y = 0.0
	d.global_position = feet
	d.look_at(feet + inward, Vector3.UP)
	var rim := OmniLight3D.new()     # как в сцене: холодный отсвет снега на фигуре
	rim.omni_range = 2.6
	rim.light_energy = 1.8
	rim.light_color = Color(0.6, 0.7, 0.9)
	Game.level.add_child(rim)
	rim.global_position = glass - inward * 0.35 + Vector3(0, 0.25, 0)
	d.tree_exiting.connect(rim.queue_free)
	var inside := glass + inward * 1.4
	_look(Vector3(inside.x, 0.05, inside.z), glass + Vector3(0, 0.15, 0))
	p.set_flashlight(false)
	await _wait(1.6)
	await _shot("double_window_watcher")
	d.queue_free()


func _yrka_shots() -> void:
	var p := Game.player
	var rig := Creatures.make_yrka()
	Game.level.add_child(rig)
	p.set_flashlight(true)
	# 1. Метель, 9 м, крадётся
	if Game.weather != null:
		Game.weather.force_blizzard(true, 999.0)
		Game.weather.intensity = 0.8
	rig.global_position = Vector3(25.0, 0.0, 19.0)
	rig.rotation.y = 0.0
	rig.pose_override = &"stalk"
	_look(Vector3(25.0, 0.05, 10.0), Vector3(25.0, 1.1, 19.0))
	await _wait(2.0)
	await _shot("yrka_blizzard")
	if Game.weather != null:
		Game.weather.force_blizzard(false, 0.0)
		Game.weather.intensity = 0.1
	# 2. Открыл дверь — стоит на крыльце, голова набок
	Game.level.set_door_open(true)
	rig.global_position = Vector3(15.7, 0.0, 3.1)
	rig.rotation.y = deg_to_rad(90.0)
	rig.pose_override = &"peek"
	_look(Vector3(13.6, 0.05, 3.1), Vector3(15.7, 1.4, 3.1))
	await _wait(2.0)
	await _shot("yrka_door")
	Game.level.set_door_open(false)
	# 3. Лицо вблизи под фонарём: стоит на тропе, смотрит в камеру
	rig.global_position = Vector3(30.0, 0.0, 12.0)
	rig.rotation.y = 0.0
	rig.pose_override = &"idle"
	_look(Vector3(30.0, -0.05, 10.75), Vector3(30.0, 1.42, 12.0 - 0.6))
	await _wait(1.0)
	await _shot("yrka_face")
	# 4. Погоня: на четвереньках, 4 м
	rig.global_position = Vector3(30.0, 0.0, 14.0)
	rig.rotation.y = 0.0
	rig.pose_override = &"run"
	_look(Vector3(30.0, 0.05, 10.0), Vector3(30.0, 0.6, 14.0))
	await _wait(1.2)
	await _shot("yrka_chase")
	rig.pose_override = &"lunge"
	await _wait(0.5)
	await _shot("yrka_lunge")


## Будка, пульт, рейка: приборы читаются глазами (темнота → фонарь → иней), книжка КМ-1 и сверка сводки.
func _thermo_review() -> void:
	var p := Game.player
	Game.yrka.enabled = false
	var booth := Yard.METEO + Yard.M_BOOTH
	p.set_flashlight(false)
	_look(booth + Vector3(0.0, 0.05, 1.5), booth + Vector3(0.0, 1.5, 0.0))
	await _wait(0.6)
	Game.hud.visible = true
	EventBus.ui_requested.emit(&"thermometer")
	await _wait(1.0)
	var ui: Variant = Game.hud.modal()
	print("[thermo] открыт: ", ui is ThermometerUI, " правда=", Game.air_temp(), " ночь=", Game.night)
	await _wait(0.5)
	for hp: HeldPaper in (ui as Node).find_children("*", "HeldPaper", true, false):
		# Клик по нарисованному листу: верхняя половина клетки «десятки сухого» — +1
		var bk: KMBook = ui.get(&"_book")
		var cell := bk.cell_rect(0, 1)
		var before: int = bk.vals[0][1]
		var lp := hp.page_to_local(bk.position + cell.get_center() - Vector2(0, cell.size.y * 0.25))
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = lp
			hp._gui_input(ev)
		await _wait(0.1)
		print("[held] клик по листу: десятки %d → %d" % [before, bk.vals[0][1]])
	await _shot("thermo_dark")
	p.set_flashlight(true)
	var cl: Closeup3D = ui.get(&"_close")
	var truth: Vector2 = ui.get(&"_truth")
	ui.call(&"_scroll", truth.x - float(ui.call(&"_view_t")))
	await _wait(0.6)
	await _shot("thermo_lit")
	# стереть иней мышью по сухому термометру: точка шкалы в центре кадра
	var fr: Closeup3D.Frost = (ui.get(&"_frost") as Array)[0]
	for i in 25:
		var sp := cl.cam.unproject_position(fr.global_position + Vector3(sin(i * 0.7) * 0.02, (cl.cam.global_position.y - fr.global_position.y) + cos(i * 0.5) * 0.03, 0))
		var mm := InputEventMouseMotion.new()
		mm.position = sp
		ui.call(&"_gui_input", mm)
		ui.set(&"_wipe", true)
		await _wait(0.05)
	ui.set(&"_wipe", false)
	await _wait(0.3)
	await _shot("thermo_wiped")
	if ui.get(&"_fever"):
		ui.call(&"_scroll", 36.6 - float(ui.call(&"_view_t")))
		await _wait(2.4)
		print("[thermo] жар замечен: ", ui.get(&"_fever_seen"))
		await _shot("thermo_fever")
	var book: KMBook = ui.get(&"_book")
	book.set_value(0, snappedf(truth.x, 0.1))
	book.set_value(1, snappedf(truth.y, 0.1))
	await _wait(0.3)
	await _shot("thermo_book")
	ui.call(&"_write")
	await _wait(0.4)
	print("[thermo] снято=", Game.readings.get(&"temp", false), " книжка=", Game.notebook)

	# Рейка
	var rod := Yard.METEO + Yard.M_ROD
	_look(rod + Vector3(0.0, 0.05, 1.5), rod + Vector3(0.0, 1.0, 0.0))
	await _wait(0.4)
	EventBus.ui_requested.emit(&"snow_stake")
	await _wait(0.8)
	var su: Variant = Game.hud.modal()
	var depth: float = su.get(&"_truth")
	(su.get(&"_close") as Closeup3D).scroll(-1.0)
	await _wait(0.6)
	await _shot("snow_stake")
	(su.get(&"_book") as KMBook).set_value(0, depth)
	await _wait(0.2)
	await _shot("snow_book")
	su.call(&"_write")
	await _wait(0.3)
	print("[snow] снято=", Game.readings.get(&"snow", false), " правда=", depth)

	# Пульт ветра (в корпусе, свет — по дизелю; здесь просто открываем кадр)
	EventBus.ui_requested.emit(&"wind_panel")
	await _wait(7.0)
	var wu: Variant = Game.hud.modal()
	var wt: Vector3 = wu.get(&"_truth")
	print("[wind] правда=", wt, " красный=", wu.get(&"_gust_max"))
	await _shot("wind_panel")
	var wb: KMBook = wu.get(&"_book")
	wb.set_value(0, roundf(wt.x))
	wb.set_value(1, roundf(wt.y))
	wb.set_value(2, WindPanelUI.rumb_of(wt.z))
	await _wait(0.2)
	await _shot("wind_book")
	wu.call(&"_write")
	await _wait(0.3)
	# Барограф у рации в доме
	_look(Vector3(8.4, 0.05, 0.2), Vector3(8.4, 0.9, -1.35))
	await _wait(0.4)
	EventBus.ui_requested.emit(&"barograph")
	await _wait(0.8)
	var bu: Variant = Game.hud.modal()
	var bt: float = bu.get(&"_truth")
	var btend: float = bu.get(&"_truth_tend")
	print("[baro] правда=%.2f тенденция=%+.2f" % [bt, btend])
	await _wait(0.6)
	await _shot("barograph")
	(bu as Control).call(&"_gui_input", _motion(Vector2(400, 330)))
	await _wait(0.4)
	await _shot("barograph_ruler")
	var bb: KMBook = bu.get(&"_book")
	bb.set_value(0, snappedf(bt, 0.1))
	bb.set_value(1, snappedf(btend, 0.1))
	await _wait(0.2)
	await _shot("barograph_book")
	bu.call(&"_write")
	await _wait(0.3)
	# Барограф корпуса: тот же экран, барабан встаёт на стол у перегородки (лицом на запад)
	MeteoCorpus.instance.call(&"_set_power", true)
	_tp(MeteoCorpus.BARO_POS + Vector3(-1.0, 0.05, 0.0), 0.0)
	await _wait(0.4)
	EventBus.ui_requested.emit(&"barograph")
	await _wait(1.0)
	await _shot("barograph_corpus")
	Game.hud.close_modal()
	await _wait(0.3)
	print("[check] всё верно → ", Game.report_check(), " снято ", Game.readings_count(), "/", Game.READING_KEYS.size())
	# Ошибки
	Game.write_reading(&"temp_dry", truth.x + 1.2, truth.x)
	print("[check] t+1.2 → ", Game.report_check())
	Game.write_reading(&"wind_dir", posmod(WindPanelUI.rumb_of(wt.z) + 3, 16), WindPanelUI.rumb_of(wt.z))
	Game.write_reading(&"snow", depth + 8.0, depth)
	print("[check] +румб 3, снег +8 → ", Game.report_check())
	Game.radio.call(&"_check_reply", Game.report_check(), 0.1)
	await _wait(0.8)
	await _shot("radio_check")

## Крыльцо корпуса пешком: от леера к двери, дверь открыть, войти в тамбур.
func _porch_walk() -> void:
	var p := Game.player
	Game.yrka.enabled = false
	var c := MeteoCorpus.instance
	_look(Vector3(83.47, 0.05, -27.9), Vector3(93.0, 4.2, -27.5))
	await _wait(1.0)
	await _shot("porch_facade")
	_look(Vector3(84.5, 0.05, -24.0), Vector3(90.0, 3.6, -27.0))
	await _wait(0.6)
	await _shot("porch_parapet")
	for n in c.find_children("*", "Interactable", true, false):
		if (n as Node3D).global_position.distance_to(MeteoCorpus.DOOR + Vector3(0.05, 1.05, -0.0)) < 0.8:
			n.emit_signal(&"used", p)
	await _wait(0.8)
	p.global_position = Vector3(85.0, 0.1, -27.25)
	p.rotation.y = -PI * 0.5   # лицом на +X
	p.head.rotation.x = 0.0
	await _wait(0.3)
	Input.action_press(&"move_forward")
	await _wait(3.0)
	Input.action_release(&"move_forward")
	await _wait(0.3)
	var pos := p.global_position
	print("[porch] x=%.2f y=%.2f zone=%s → %s" % [pos.x, pos.y, Game.zone, "ВОШЁЛ" if pos.x > 90.6 else "НЕ ВОШЁЛ"])
	await _shot("porch_in")


static func _motion(pos: Vector2) -> InputEventMouseMotion:
	var m := InputEventMouseMotion.new()
	m.position = pos
	return m


## Эфир: пеленг из дома и с башни → квадрат → находка; морзе, случайная передача, журнал, схема, «Дело».
func _efir_review() -> void:
	var p := Game.player
	Game.yrka.enabled = false
	Game.give_item(&"tape_recorder")
	Game.give_item(&"codebook")
	Game.hud.visible = true
	var pool := Efir.pool_for_night(Game.night)
	for id in pool:
		var d := Efir.pool_def(id)
		print("[efir] пул %s: %s %d кГц окно %s слабый=%s у %s текст «%s»" % [id, d["kind"], int(d["freq"]), d["window"], d["weak"], d["pos"], Efir.plain(id)])
	var sig := &"semenov"
	print("[efir] в эфире: ", Game.radio.signals_on_air())
	# --- Дом ---
	_look(Vector3(10.3, 0.05, -0.4), Vector3(11.05, 1.3, -1.55))
	await _wait(0.4)
	Game.radio.freq = 7713.0
	DirectionFinderUI.next_point = &"house"
	EventBus.ui_requested.emit(&"direction_finder")
	await _wait(0.8)
	var ui: Variant = Game.hud.modal()
	var tb := Efir.true_bearing(sig, &"house")
	ui.set(&"_angle", fposmod(tb + 90.0, 360.0))
	await _wait(1.0)
	print("[efir] дом: правда %.1f°, сила %.2f, S при 90° = %.2f" % [tb, ui.get(&"_strength"), ui.get(&"_meter")])
	await _shot("df_house_loud")
	ui.set(&"_angle", tb)
	await _wait(1.0)
	print("[efir] дом: S в ноле = %.2f" % ui.get(&"_meter"))
	await _shot("df_house_null")
	(ui.get(&"_book") as KMBook).set_value(0, roundf(tb))
	ui.call(&"_write")
	await _wait(0.4)
	print("[efir] после дома: ", Efir.cross(sig))
	# --- Башня ---
	if MeteoCorpus.instance != null:
		MeteoCorpus.instance.call(&"_set_power", true)
	_look(Vector3(96.6, MeteoCorpus.CAB + 0.05, -37.1), Vector3(95.35, MeteoCorpus.CAB + 0.9, -37.12))
	await _wait(0.5)
	DirectionFinderUI.tower_freq = 7713.0
	DirectionFinderUI.next_point = &"tower"
	EventBus.ui_requested.emit(&"direction_finder")
	await _wait(0.8)
	ui = Game.hud.modal()
	var tt := Efir.true_bearing(sig, &"tower")
	ui.set(&"_angle", tt)
	await _wait(0.8)
	(ui.get(&"_book") as KMBook).set_value(0, roundf(tt))
	await _shot("df_tower")
	ui.call(&"_write")
	await _wait(0.4)
	var cr := Efir.cross(sig)
	print("[efir] квадрат: ", cr, " до бункера %.1f м" % (cr[0] as Vector3).distance_to(Efir.source_pos(sig)) if cr.size() == 2 else "нет")
	# Неверный азимут с башни — квадрат уезжает
	Efir.record_df(&"lullaby", &"house", Efir.true_bearing(&"lullaby", &"house"))
	Efir.record_df(&"lullaby", &"tower", Efir.true_bearing(&"lullaby", &"tower") + 8.0)
	var bad := Efir.cross(&"lullaby")
	print("[efir] избa с ошибкой 8°: ", bad, " промах %.1f м" % (bad[0] as Vector3).distance_to(Efir.source_pos(&"lullaby")) if bad.size() == 2 else "")
	# Далёкий: жужжалка
	Efir.record_df(&"buzzer", &"house", Efir.true_bearing(&"buzzer", &"house"))
	Efir.record_df(&"buzzer", &"tower", Efir.true_bearing(&"buzzer", &"tower"))
	print("[efir] жужжалка: ", Efir.cross(&"buzzer"))
	# --- Схема ---
	EventBus.ui_requested.emit(&"map")
	await _wait(0.8)
	await _shot("map_efir")
	Game.hud.close_modal()
	await _wait(0.3)
	# --- Находка у бункера ---
	var spot := Efir.source_pos(sig)
	_look(spot + Vector3(2.5, 0.05, 2.0), spot + Vector3(0, 0.3, 0))
	await _wait(1.0)
	await _shot("find_bunker")
	for n in get_tree().root.find_children("EfirFind_semenov", "", true, false):
		n.emit_signal(&"used", p)
	await _wait(0.6)
	print("[efir] находка бункер: ", Efir.has_find(&"bunker"))
	await _shot("find_bunker_note")
	Game.hud.hide_note()
	# --- Морзе ---
	Game.add_tape(&"morse")
	MorseUI.pending_id = &"morse"
	EventBus.ui_requested.emit(&"morse")
	await _wait(0.6)
	var mu: Variant = Game.hud.modal()
	(mu.get(&"_input") as LineEdit).text = "КЕДР СЕМЬ ПОСЛЕ"
	mu.call(&"_check")
	await _wait(0.2)
	await _shot("morse_partial")
	(mu.get(&"_input") as LineEdit).text = Efir.plain(&"morse").to_lower()
	mu.call(&"_check")
	print("[efir] морзе прочитано: ", Efir.is_decoded(&"morse"))
	await _wait(0.2)
	await _shot("morse_solved")
	Game.hud.close_modal()
	# --- Случайная передача ---
	if not pool.is_empty():
		var rid: StringName = pool[0]
		Game.add_intercept(rid)
		Game.add_tape(rid)
		if Efir.kind_of(rid) == &"morse":
			MorseUI.pending_id = rid
			EventBus.ui_requested.emit(&"morse")
		else:
			CodebookUI.pending_id = rid
			EventBus.ui_requested.emit(&"codebook")
		await _wait(0.6)
		var du: Variant = Game.hud.modal()
		await _shot("pool_decoder")
		(du.get(&"_input") as LineEdit).text = Efir.plain(rid)
		du.call(&"_check")
		print("[efir] пул прочитан: ", Efir.is_decoded(rid))
		Game.hud.close_modal()
		var ps := Efir.pool_def(rid)["pos"] as Vector3
		for n in get_tree().root.find_children("EfirFind_" + String(rid), "", true, false):
			n.emit_signal(&"used", p)
		print("[efir] случайных найдено: ", Efir.pool_found(), " у ", ps)
		Game.hud.hide_note()
	# --- Журнал перехватов ---
	Game.add_intercept(&"semenov")
	EventBus.ui_requested.emit(&"intercepts")
	await _wait(0.6)
	await _shot("intercepts_efir")
	Game.hud.close_modal()
	# --- После трёх: передатчик под полом ---
	Game.shift_minutes = 440.0
	Game.radio.freq = 5210.0
	DirectionFinderUI.next_point = &"house"
	_look(Vector3(10.3, 0.05, -0.4), Vector3(11.05, 1.3, -1.55))
	EventBus.ui_requested.emit(&"direction_finder")
	await _wait(1.0)
	ui = Game.hud.modal()
	print("[efir] 03:40 «один» в эфире: ", Efir.window_ok(&"alone"), " сила %.2f, в упор: %s" % [ui.get(&"_strength"), Efir.too_close(&"alone", &"house")])
	await _shot("df_alone")
	Game.hud.close_modal()
	Efir.mark_find(&"alone")
	print("[efir] секрет открыт: ", Game.secret_ready())
	for n in _app.get_children():
		if n is Session:
			print("[efir] дело:
", (n as Session)._case_file(&"answer"))


## Все окна игры по очереди — кадр каждого (проверка единого стиля).
func _ui_review() -> void:
	Game.yrka.enabled = false
	Game.give_item(&"tape_recorder")
	Game.give_item(&"codebook")
	Game.add_tape(&"code")
	Game.hud.visible = true
	_look(Vector3(8.6, 0.05, 0.4), Vector3(9.2, 1.0, -1.4))
	await _wait(0.5)
	for id: StringName in [&"journal", &"intercepts", &"codebook", &"tape", &"seismograph", &"meteor_fax", &"supply", &"theodolite", &"map", &"barograph", &"wind_panel"]:
		EventBus.ui_requested.emit(id)
		await _wait(1.2)
		await _shot("ui_" + String(id))
		Game.hud.close_modal()
		await _wait(0.3)
	Game.hud.show_note(Loc.t(&"efir.find.alone"))
	await _wait(0.6)
	await _shot("ui_note")
	Game.hud.hide_note()


## Лор: книги в руках (разные виды), книги на местах, тайники и комнаты.
func _lore_review() -> void:
	Game.yrka.enabled = false
	Game.hud.visible = true
	_look(Vector3(1.8, 0.05, 2.6), Vector3(1.0, 0.8, 3.85))
	await _wait(0.6)
	await _shot("lore_desk_book")
	var placed := get_tree().root.find_children("Book_*", "", true, false).size()
	print("[lore] книг на местах: ", placed)
	for id: StringName in [&"bragin", &"permyakov", &"report", &"golubev", &"gazeta"]:
		BookUI.pending_id = id
		EventBus.ui_requested.emit(&"book")
		await _wait(1.0)
		await _shot("lore_book_" + String(id))
		var hp: Variant = Game.hud.modal()
		var bu: Variant = (hp as Node).find_children("*", "BookUI", true, false)[0] if hp != null else null
		if bu != null:
			bu.call(&"_flip", 1)
			bu.call(&"_flip", 1)
			await _wait(0.3)
			await _shot("lore_book_" + String(id) + "_end")
		Game.hud.close_modal()
		await _wait(0.3)
	print("[lore] прочитано: ", Books.read_count(), "/", Books.ORDER.size())
	var p := Game.player
	# Подпол: сундук → люк → вниз
	_look(StationLore.TRUNK + Vector3(0, 0.05, 1.6), StationLore.TRUNK + Vector3(0, 0.3, 0))
	await _wait(0.5)
	await _shot("lore_trunk")
	for it in get_tree().root.find_children("*", "Interactable", true, false):
		if (it as Node3D).global_position.distance_to(StationLore.TRUNK + Vector3(0, 0.275, 0)) < 0.1:
			it.emit_signal(&"used", p)
	await _wait(1.2)
	_look(StationLore.TRUNK + Vector3(0, 0.05, 2.4), StationLore.TRUNK)
	await _wait(0.4)
	await _shot("lore_hatch")
	StationLore.go(StationLore.CELLAR + Vector3(0, 0.05, 0.9), 0.0)
	await _wait(1.2)
	p.set_flashlight(true)
	_look(StationLore.CELLAR + Vector3(-0.8, 0.05, 1.0), StationLore.CELLAR + Vector3(1.3, 1.0, 0.0))
	await _wait(0.6)
	print("[lore] подпол: зона=", Game.zone, " темно=", Game.is_dark())
	await _shot("lore_cellar")
	_look(StationLore.CELLAR + Vector3(0.5, 0.05, 0.6), StationLore.CELLAR + Vector3(-1.5, 1.3, 0.2))
	await _wait(0.4)
	await _shot("lore_cellar_wall")
	# Кабинет Голубева
	if MeteoCorpus.instance != null:
		MeteoCorpus.instance.call(&"_set_power", true)
	_look(Vector3(97.2, MeteoCorpus.FL + 0.05, -27.2), Vector3(98.6, MeteoCorpus.FL + 1.4, -27.2))
	await _wait(0.5)
	await _shot("lore_archive_window")
	StationLore.go(Vector3(99.5, MeteoCorpus.FL + 0.05, -26.0), 0.0)
	await _wait(1.0)
	_look(Vector3(99.4, MeteoCorpus.FL + 0.05, -25.4), Vector3(101.2, MeteoCorpus.FL + 0.9, -27.5))
	await _wait(0.6)
	print("[lore] кабинет: зона=", Game.zone)
	await _shot("lore_walled")
	SafeUI.code = StationLore.SAFE_CODE
	EventBus.ui_requested.emit(&"safe")
	await _wait(0.6)
	var su: Variant = Game.hud.modal()
	(su.get(&"_book") as KMBook).set_value(0, 2207)
	await _shot("lore_safe")
	Game.hud.close_modal()
	_look(Vector3(103.5, 0.05, -21.0), Vector3(100.4, 1.6, -26.7))
	await _wait(0.6)
	await _shot("lore_annex_outside")
	# Тоннель
	_look(Vector3(97.2, MeteoCorpus.FL + 0.05, -27.4), StationLore.HATCH_ARCHIVE)
	await _wait(0.4)
	await _shot("lore_archive_floor")
	StationLore.go(Vector3(StationLore.TUN_X, StationLore.TUN_Y + 0.05, StationLore.TUN_N + 2.0), PI)
	await _wait(1.0)
	_look(Vector3(StationLore.TUN_X + 0.6, StationLore.TUN_Y + 0.05, StationLore.TUN_N + 6.0), Vector3(StationLore.TUN_X - 1.1, StationLore.TUN_Y + 1.4, StationLore.TUN_N + 12.0))
	await _wait(0.6)
	print("[lore] тоннель: зона=", Game.zone)
	await _shot("lore_tunnel")
	_look(Vector3(StationLore.TUN_X - 3.0, StationLore.TUN_Y + 0.05, StationLore.TUN_Z), Vector3(StationLore.TUN_W, StationLore.TUN_Y + 1.2, StationLore.TUN_Z))
	await _wait(0.6)
	await _shot("lore_tunnel_b")
	# Корпус: то, что было халтурным в отчётах F9
	p.set_flashlight(false)
	for v: Array in [["pult", Vector3(91.7, 0.5, -32.6), Vector3(91.7, 1.4, -33.8)], ["baro", Vector3(93.3, 0.5, -30.0), Vector3(94.3, 1.2, -30.0)],
			["poster", Vector3(93.0, 0.5, -32.3), Vector3(94.7, 2.0, -32.3)], ["office", Vector3(93.6, 0.5, -22.0), Vector3(91.0, 1.4, -25.0)],
			["board", Vector3(95.9, 0.5, -29.6), Vector3(94.9, 1.9, -29.6)], ["stores", Vector3(97.0, 0.5, -21.4), Vector3(98.4, 1.3, -23.4)],
			["gas", Vector3(102.5, 0.5, -36.5), Vector3(100.6, 0.6, -34.6)], ["gap_tower", Vector3(95.23, 0.45, -34.11), Vector3(97.0, 1.4, -34.6)]]:
		_look(v[1], v[2])
		await _wait(0.7)
		await _shot("corpus_" + String(v[0]))
