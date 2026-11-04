class_name MineStory
extends Node
## Ночь 4 — «Логово». Сюжетная вылазка в «Горизонт-40»:
##   1. Большая Земля по рации: на 4170 сигнал идёт из старой штольни (POI 11) — снять с треноги
##      у устья маяк Дубова с кассетой.
##   2. Катсцена «Провал»: под ногами трещит наледь, пол уходит, падение, темнота. Очнулся в забое.
##   3. Логово: кости, лёжки из ватников пропавших дежурных, их вещи; кассета выпала рядом.
##   4. Стелс: оно ходит по штреку. Видит луч фонаря издалека и тебя вблизи, слышит бег; задержанное
##      дыхание и темнота спасают, за поворотом рассечки — не видно. Заметило — погоня; поймало —
##      снова в забое (без смерти, как контрольная точка). Ракета отгоняет.
##   5. У самого выхода: крик в глубине, топот — оно бежит сюда. Добеги до лестницы.
##   6. Катсцена «Наверх»: вылез, внизу в темноте — два огня глаз. Тишина.

const ROOT := MineHorizon.ROOT
const FALL_LOCAL := Vector3(0.6, 0.05, -41.8)      ## где очнулся — забой
const LADDER_LOCAL := Vector3(0.0, 0.05, 1.2)
const PATROL: Array[Vector3] = [Vector3(0, 0, -30), Vector3(0, 0, -20), Vector3(0, 0, -8), Vector3(0, 0, -16), Vector3(-7, 0, -26), Vector3(0, 0, -26)]
const RUN_TRIGGER_Z := -9.0                        ## ближе к стволу — оно бросается из глубины
const STEP := "res://assets/audio/yrka_steps.ogg"
const SHRIEK := "res://assets/audio/shriek.ogg"
const GROWL := "res://assets/audio/growl.ogg"
const HEART := "res://assets/audio/heartbeat.ogg"

static var instance: MineStory

var stage := &"idle"        ## idle → ordered → fallen → stealth → run → done
var _lurker: CreatureRig
var _pi := 0
var _sus := 0.0
var _chase := false
var _t := 0.0
var _step_t := 0.0
var _beacon: Node3D
var _hint_t := 0.0
var _grace := 0.0          ## после поимки: пока не видит (экран в затемнении, ты в забое)


static func is_active() -> bool:
	return instance != null and instance.stage in [&"fallen", &"stealth", &"run"]


func _ready() -> void:
	name = "MineStory"
	if not Game.is_night() or Game.night != 4 or Game.is_prologue() or Game.has_flag("mine_story_done"):
		queue_free()
		return
	instance = self
	_t = 150.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


func _process(delta: float) -> void:
	match stage:
		&"idle":
			_t -= delta
			if _t <= 0.0 and Game.is_home() and not Cutscene.active:
				_order()
		&"stealth", &"run":
			_tick_lurker(delta)


# --- 1. Приказ ---------------------------------------------------------------------

func _order() -> void:
	stage = &"ordered"
	Game.audio.play_2d("res://assets/audio/static_loop.ogg", -12.0)
	for i in range(1, 4):
		Game.hud.subtitle(Loc.t(StringName("mst.order.%d" % i)), 5.5)
		await get_tree().create_timer(5.6, false).timeout
	Game.story_goal = Loc.t(&"mst.goal.beacon")
	_build_beacon()


func _build_beacon() -> void:
	var mh := MineHorizon.instance
	if mh == null:
		return
	var at: Vector3 = mh.get("_surface") + Vector3(1.8, 0, 2.6)
	at.y = Terrain.height(at.x, at.z)
	_beacon = Node3D.new()
	_beacon.name = "DubovBeacon"
	Game.yard.add_child(_beacon)
	_beacon.global_position = at
	for k in 3:
		var a := k * TAU / 3.0
		var leg := Geo.cylinder(_beacon, 0.02, 1.3, Vector3(cos(a) * 0.22, 0.6, sin(a) * 0.22), Palette.m(&"metal"), false)
		leg.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	Geo.block(_beacon, Vector3(0.36, 0.2, 0.26), Vector3(0, 1.28, 0), Palette.m(&"radio"), false)
	var lamp := Geo.omni(_beacon, Vector3(0, 1.5, 0), 4.0, 1.2, Color(1.0, 0.25, 0.15))
	var tw := lamp.create_tween().set_loops()
	tw.tween_property(lamp, "light_energy", 0.0, 0.1).set_delay(0.8)
	tw.tween_property(lamp, "light_energy", 1.2, 0.1)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = AudioDirector.cached_stream("res://assets/audio/morse_loop.ogg")
	snd.volume_db = -8.0
	snd.max_distance = 60.0
	snd.position = Vector3(0, 1.3, 0)
	_beacon.add_child(snd)
	snd.play()
	var it := Geo.interactable(_beacon, Vector3(1.0, 1.6, 1.0), Vector3(0, 0.8, 0), null, Loc.t(&"mst.it.beacon"), func(_p: Player) -> void: _fall())
	it.name = "DubovBeaconIt"


# --- 2. Провал ---------------------------------------------------------------------

func _fall() -> void:
	if stage != &"ordered":
		return
	stage = &"falling"
	Game.story_goal = ""
	if Game.yrka != null:
		Game.yrka.enabled = false
	Director.hold = true
	var p := Game.player
	Game.flash_charge = maxf(Game.flash_charge, 40.0)
	p.set_flashlight(true)
	var pp := p.global_position
	var fwd := -p.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	await Cutscene.play([
		{"cam": [pp + Vector3(0, 1.55, 0), pp + fwd * 2.0 + Vector3(0, 0.9, 0)]},
		{"say": "mst.fall.1", "t": 2.5},
		{"sfx": "res://assets/audio/ice_hit.ogg", "vol": 2.0},
		{"shake": 0.6, "t": 0.8},
		{"wait": 0.9},
		{"sfx": "res://assets/audio/ice_hit_v2.ogg", "vol": 4.0},
		{"move": [pp + Vector3(0, 1.1, 0), pp + fwd * 0.5 + Vector3(0, -1.0, 0)], "t": 0.5},
		{"shake": 1.6, "t": 1.0},
		{"sfx": "res://assets/audio/sub_drop.ogg", "vol": 4.0},
		{"fade": 1.0, "t": 0.25},
		{"call": func() -> void:
			if _beacon != null:
				_beacon.queue_free()
			p.global_position = ROOT + FALL_LOCAL
			p.rotation.y = 0.0
			p.velocity = Vector3.ZERO
			p.set_flashlight(false)},
		{"sfx": "res://assets/audio/gore_hit.ogg", "vol": -2.0},
		{"wait": 2.2},
		{"say": "mst.fall.2", "t": 4.0, "hold": true},
		{"cam": [ROOT + FALL_LOCAL + Vector3(0.3, 0.25, 0.4), ROOT + FALL_LOCAL + Vector3(0, 2.6, -1.5)]},
		{"fade": 0.6, "t": 1.4},
		{"fade": 0.92, "t": 0.5},
		{"fade": 0.0, "t": 1.6},
		{"move": [ROOT + FALL_LOCAL + Vector3(0, 1.55, 0), ROOT + FALL_LOCAL + Vector3(0, 1.4, 3.0)], "t": 2.2},
	])
	_wake()


func _wake() -> void:
	stage = &"fallen"
	var p := Game.player
	Game.flash_charge = maxf(Game.flash_charge, 75.0)   # сюжетной сцене нужен свет: батарею берёг
	# Фонарь не сразу: мигает и ловит контакт
	for k in 6:
		p.set_flashlight(k % 2 == 0)
		await get_tree().create_timer(randf_range(0.08, 0.3), false).timeout
	p.set_flashlight(true)
	Game.hud.subtitle(Loc.t(&"mst.wake"), 6.0)
	Game.story_goal = Loc.t(&"mst.goal.out")
	_build_lair()
	await get_tree().create_timer(5.0, false).timeout
	_spawn_lurker()
	stage = &"stealth"


# --- 3. Логово ---------------------------------------------------------------------

func _build_lair() -> void:
	var w := Game.yard
	var bone := Palette.m(&"paper")
	var cloth := Palette.m(&"cloth")
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var root := Node3D.new()
	root.name = "Lair"
	w.add_child(root)
	# Лёжки из ватников и тряпья — в забое и тупике
	for c: Vector3 in [Vector3(-1.0, 0, -43.0), Vector3(1.2, 0, -40.5), Vector3(-8.5, 0, -26.5)]:
		var m := MeshInstance3D.new()
		m.mesh = Props.snow_mound_mesh(rng.randi())
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.19, 0.16)
		mat.roughness = 1.0
		m.material_override = mat
		m.scale = Vector3(0.9, 0.22, 0.7)
		m.position = ROOT + c + Vector3(0, 0.05, 0)
		root.add_child(m)
		for k in 6:
			var b := Geo.cylinder(root, 0.025, rng.randf_range(0.25, 0.45), ROOT + c + Vector3(rng.randf_range(-0.8, 0.8), 0.08, rng.randf_range(-0.6, 0.6)), bone, false)
			b.rotation = Vector3(PI * 0.5, rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	# Вещи пропавших: ключ радиста Брагина, шарф Ерёминой, ракетница Голубева (её нашли в схроне), ушанка Семёнова
	var items := [[&"bragin", Vector3(-1.4, 0.1, -42.6)], [&"eryomina", Vector3(1.5, 0.1, -40.2)], [&"golubev", Vector3(-8.0, 0.1, -25.9)]]
	for it: Array in items:
		var pos: Vector3 = ROOT + (it[1] as Vector3)
		var mark := Geo.block(root, Vector3(0.22, 0.05, 0.16), pos, cloth, false)
		mark.rotation.y = rng.randf() * TAU
		var spot := Geo.interactable(root, Vector3(0.6, 0.5, 0.6), pos + Vector3(0, 0.2, 0), null, Loc.t(StringName("mst.it.%s" % it[0])), func(_pl: Player) -> void:
			Game.hud.subtitle(Loc.t(StringName("mst.item.%s" % it[0])), 6.0))
		spot.name = "LairItem"
	# Кассета Дубова выпала рядом
	var tape := Geo.block(root, Vector3(0.1, 0.02, 0.065), ROOT + FALL_LOCAL + Vector3(0.5, 0.02, 0.6), Palette.m(&"dark"), false)
	var tit := Geo.interactable(root, Vector3(0.5, 0.4, 0.5), ROOT + FALL_LOCAL + Vector3(0.5, 0.2, 0.6), null, Loc.t(&"mst.it.tape"), func(_pl: Player) -> void:
		Game.set_flag("mine_story_tape", true)
		tape.visible = false
		Game.hud.subtitle(Loc.t(&"mst.tape"), 5.0))
	tit.name = "DubovTape"
	# Провал над забоем: лунный луч и снег, что насыпался сверху
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.6, 0.7, 0.95)
	moon.light_energy = 4.0
	moon.spot_range = 12.0
	moon.spot_angle = 22.0
	moon.shadow_enabled = false
	root.add_child(moon)
	moon.global_position = ROOT + FALL_LOCAL + Vector3(0.2, 6.0, 0.0)
	moon.rotation.x = -PI * 0.5
	var pile := MeshInstance3D.new()
	pile.mesh = Props.snow_mound_mesh(1)
	pile.material_override = Palette.m(&"drift")
	pile.scale = Vector3(1.0, 0.3, 0.9)
	pile.position = ROOT + FALL_LOCAL + Vector3(0.2, 0.0, 0.2)
	root.add_child(pile)
	var dust := CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 5.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.6, 0.1, 0.6)
	dust.direction = Vector3(0, -1, 0)
	dust.initial_velocity_min = 0.2
	dust.initial_velocity_max = 0.5
	dust.gravity = Vector3.ZERO
	var dq := QuadMesh.new()
	dq.size = Vector2(0.03, 0.03)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(0.85, 0.9, 1.0, 0.8)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dq.material = dm
	dust.mesh = dq
	root.add_child(dust)
	dust.global_position = ROOT + FALL_LOCAL + Vector3(0.2, 3.0, 0.0)
	# Керосинка в тупике — кто-то оставил, еле тлеет
	var kl := Props.kerosene_lamp()
	root.add_child(kl)
	kl.global_position = ROOT + Vector3(-8.8, 0.0, -25.4)
	var flame := Geo.omni(root, ROOT + Vector3(-8.8, 0.45, -25.4), 8.0, 1.6, Color(1.0, 0.6, 0.3))
	flame.shadow_enabled = false
	var ftw := flame.create_tween().set_loops()
	ftw.tween_property(flame, "light_energy", 1.0, 0.25)
	ftw.tween_property(flame, "light_energy", 1.7, 0.3)
	# Зарубки на стене — счёт ночей, чужой рукой
	for k in 14:
		Geo.block(root, Vector3(0.01, 0.16, 0.012), ROOT + Vector3(-1.86, 1.0 + (k % 7) * 0.02, -43.6 + k * 0.05), Palette.m(&"dark"), false)


# --- 4–5. Оно в штреке ---------------------------------------------------------------

func _spawn_lurker() -> void:
	_lurker = Creatures.make_yrka()
	_lurker.name = "MineLurker"
	Game.yard.add_child(_lurker)
	_lurker.global_position = ROOT + PATROL[0]
	_lurker.gait = 0.3
	_pi = 1
	Game.audio.play_3d(GROWL, ROOT + PATROL[0] + Vector3(0, 1.2, 0), -4.0, 10.0)


func _tick_lurker(delta: float) -> void:
	if _lurker == null or Game.player == null:
		return
	if _grace > 0.0:
		_grace -= delta
		return
	var p := Game.player
	var pp := p.global_position
	var lp := _lurker.global_position
	var to_p := pp - lp
	to_p.y = 0.0
	var d := to_p.length()
	# Ракета — отступает в глубину
	if not get_tree().root.find_children("*", "Flare", true, false).is_empty() and d < 18.0:
		if _chase:
			Game.audio.play_3d(SHRIEK, lp + Vector3(0, 1.3, 0), 4.0, 10.0)
		_chase = false
		_sus = 0.0
		_go_to(ROOT + PATROL[0], 4.0, delta)
		return
	if stage == &"stealth" and pp.z - ROOT.z > RUN_TRIGGER_Z and not _chase:
		_start_run()
	if _chase or stage == &"run":
		_lurker.gait = 1.0
		var spd := 4.6 if stage == &"run" else 4.3
		_go_to(pp, spd, delta)
		if d < 1.1:
			_caught()
		return
	# Патруль
	var tgt := ROOT + PATROL[_pi]
	if Vector2(lp.x - tgt.x, lp.z - tgt.z).length() < 0.6:
		_pi = (_pi + 1) % PATROL.size()
	_lurker.gait = 0.3
	_go_to(tgt, 1.5, delta)
	# Шаги — слышно, где оно
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.9
		Game.audio.play_3d(STEP, lp + Vector3(0, 0.2, 0), -6.0, 6.0)
	# Восприятие: свет фонаря издали, тело вблизи, бег — на слух; за углом не видно
	var head := lp + Vector3(0, 1.6, 0)
	var los := _clear(head, pp + Vector3(0, 1.3, 0))
	var breath := 0.7 if p.holding_breath else 1.0
	var sight := (15.0 if p.flashlight_on() else 5.0) * breath
	var seen := los and d < sight
	var heard := (p.is_sprinting() and d < 11.0) or (p.velocity.length() > 0.5 and d < 3.0)
	if seen or heard:
		_sus += delta * (1.6 if heard else clampf(1.8 - d / sight, 0.3, 1.8))
	else:
		_sus = maxf(_sus - delta * 0.35, 0.0)
	if _sus > 0.45 and _hint_t <= 0.0:
		_hint_t = 6.0
		Game.hud.subtitle(Loc.t(&"mst.suspect"), 3.0)
		_lurker.pose_override = &"sniff" if _lurker.has_clip(&"sniff") else &""
		Game.audio.play_3d(GROWL, head, -2.0, 8.0)
	_hint_t -= delta
	if _sus >= 1.0:
		_chase = true
		_lurker.pose_override = &""
		Game.audio.play_3d(SHRIEK, head, 6.0, 12.0)
		Game.player.shake(0.05, 0.5)
		Game.hud.subtitle(Loc.t(&"mst.seen"), 2.5)


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Geo.LAYER_WORLD)
	return Game.yard.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _go_to(target: Vector3, speed: float, delta: float) -> void:
	var lp := _lurker.global_position
	var dir := target - lp
	dir.y = 0.0
	var l := dir.length()
	if l < 0.01:
		return
	# По штреку: сперва на ось x≈0, если цель на оси, — не срезать сквозь породу
	var step := dir / l * minf(speed * delta, l)
	_lurker.global_position = lp + step
	_lurker.global_position.y = ROOT.y
	_lurker.rotation.y = atan2(-dir.x, -dir.z)


func _start_run() -> void:
	stage = &"run"
	Game.audio.play_3d(SHRIEK, ROOT + Vector3(0, 1.5, -38.0), 8.0, 40.0)
	Game.hud.subtitle(Loc.t(&"mst.run"), 3.5)
	Game.player.shake(0.04, 1.0)
	_lurker.global_position = ROOT + Vector3(0, 0, -30.0)
	var steps := AudioStreamPlayer3D.new()
	steps.stream = AudioDirector.cached_stream("res://assets/audio/yrka_steps_v3.ogg")
	steps.volume_db = 4.0
	steps.max_distance = 40.0
	_lurker.add_child(steps)
	steps.play()
	steps.finished.connect(steps.play)
	Director.add_tension(40.0, "оно бежит по штреку")


func _caught() -> void:
	# Не смерть — назад в забой: «очнулся снова», оно опять в глубине
	_chase = false
	_sus = 0.0
	_grace = 6.0
	stage = &"stealth"
	var p := Game.player
	Game.audio.play_2d(SHRIEK, 2.0)
	Game.hud.flash_red(0.9, 0.6)
	p.shake(0.1, 0.5)
	Game.add_fatigue(15.0)
	await Game.hud.blink(1.2)
	p.global_position = ROOT + FALL_LOCAL
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	_lurker.global_position = ROOT + PATROL[0]
	for c in _lurker.get_children():
		if c is AudioStreamPlayer3D:
			c.queue_free()
	_pi = 1
	Game.hud.subtitle(Loc.t(&"mst.again"), 5.0)


# --- 6. Наверх ------------------------------------------------------------------------

## Лестница у ствола: во время сюжета — катсцена выхода вместо обычного подъёма.
func climb(p: Player) -> bool:
	if not is_active():
		return false
	stage = &"done"
	Game.story_goal = ""
	var mh := MineHorizon.instance
	var surf: Vector3 = mh.get("_surface") + MineHorizon.ENTRY
	surf.y = Terrain.height(surf.x, surf.z)
	var lp := _lurker.global_position if _lurker != null else ROOT + Vector3(0, 0, -10)
	await Cutscene.play([
		{"cam": [ROOT + Vector3(0.0, 2.6, 1.6), lp + Vector3(0, 1.2, 0)]},
		{"sfx": SHRIEK, "at": lp + Vector3(0, 1.3, 0), "vol": 8.0},
		{"shake": 0.8, "t": 0.8},
		{"call": func() -> void:
			if _lurker != null:
				_lurker.global_position = ROOT + Vector3(0, 0, 0.2)
				_lurker.gait = 0.0},
		{"move": [ROOT + Vector3(0.0, 5.0, 1.6), ROOT + Vector3(0, 0.8, 0.6)], "t": 1.6},
		{"fade": 1.0, "t": 0.4},
		{"call": func() -> void:
			if _lurker != null:
				_lurker.queue_free()
				_lurker = null
			p.global_position = surf + Vector3(1.4, 0.05, -1.0)
			p.velocity = Vector3.ZERO},
		{"wait": 0.8},
		{"cam": [surf + Vector3(1.6, 1.4, 1.6), surf + Vector3(0, 0.2, 0)]},
		{"call": func() -> void: _eyes(surf + Vector3(0, -0.3, 0))},
		{"fade": 0.0, "t": 1.8},
		{"say": "mst.out.1", "t": 4.5, "hold": true},
		{"sfx": "res://assets/audio/whisper.ogg", "at": surf, "vol": 2.0},
		{"move": [surf + Vector3(3.0, 2.0, 3.5), surf + Vector3(0, 0.2, 0)], "t": 3.0},
		{"say": "mst.out.2", "t": 4.5, "hold": true},
	])
	Game.set_flag("mine_story_done", true)
	if Game.yrka != null:
		Game.yrka.enabled = true
		Game.yrka.set_cooldown(90.0)
	Director.hold = false
	Director.add_tension(-30.0, "выбрался из логова")
	Supply.add(2, &"mst.r")
	SaveGame.write()
	return true


func _eyes(at: Vector3) -> void:
	for sx: float in [-0.06, 0.06]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.035)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(1.0, 0.75, 0.4)
		m.disable_fog = true
		q.material_override = m
		Game.yard.add_child(q)
		q.global_position = at + Vector3(sx, 0, 0)
		get_tree().create_timer(9.0, false).timeout.connect(q.queue_free)
