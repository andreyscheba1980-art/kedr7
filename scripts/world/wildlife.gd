class_name Wildlife
extends Node
## Живая фауна тайги — не всё, что шевелится за окном, является Ыркой:
##   • Днём и утром: полярные беляки на опушках и рыжая лиса у поленницы/зимника; разбегаются от «Бурана»,
##     игрока и приближения хищника (ориентир безопасности).
##   • Ночью (ночи 2+, вдали от дома): стая волков — отпугиваются фонарём, фарой «Бурана» или ракетой;
##     Найда рядом держит их дальше; если волки вдруг смолкли — Ырка рядом.
##   • В тихих ночных паузах в кронах ухает филин; когда охотник близко, лес затихает.

const HOWL := "res://assets/audio/wolf_howl.ogg"
const OWL := "res://assets/audio/owl.ogg"
const GROWLS := ["res://assets/audio/growl.ogg", "res://assets/audio/growl_v2.ogg", "res://assets/audio/growl_v3.ogg"]
const HOME := Vector3(8.0, 0.0, 2.0)

static var instance: Wildlife

var state := &"idle"            ## idle → howl → circling → (lunge) → gone
var _t := 0.0
var _cool := 0.0
var _left := 0
var _pairs: Array[Dictionary] = []   ## {"node": Node3D, "a": угол, "r": радиус, "alive": bool}
var _growl_t := 0.0
var _still_t := 0.0
var _last_p := Vector3.ZERO
var _lunge: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _eye_mat: StandardMaterial3D

var _hares: Array[Dictionary] = []   ## {"node": Node3D, "home": Vector3, "target": Vector3, "hop": float, "pause": float, "flee": float}
var _fox: Dictionary = {}            ## {"node": Node3D, "route": Array, "idx": int, "pause": float, "flee": float, "yaw": float}
var _owl_t := 35.0


func _ready() -> void:
	name = "Wildlife"
	if Game.is_prologue() and not Game.has_flag("prologue_arrived"):
		queue_free()
		return
	instance = self
	_rng.seed = Game.run_seed + Game.phase_index * 71 + (13 if Game.is_daylight() else 0)
	_owl_t = _rng.randf_range(28.0, 55.0)

	if Game.is_daylight():
		_spawn_day_fauna.call_deferred()
	elif Game.is_night() and Game.night >= 2:
		_left = 1 if Game.night <= 3 else 2
		_cool = _rng.randf_range(50.0, 120.0)
		_eye_mat = StandardMaterial3D.new()
		_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_eye_mat.albedo_color = Color(0.95, 0.85, 0.35)
		_eye_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_eye_mat.disable_fog = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null


func _exit_tree() -> void:
	_clear()
	_clear_day_fauna()


func _process(delta: float) -> void:
	var p := Game.player
	if p == null or Game.yard == null:
		return

	if Game.is_daylight():
		_tick_hares(delta, p)
		_tick_fox(delta, p)
		return

	if Game.is_night() and Game.is_outside():
		_tick_owl(delta, p)

	if Game.night < 2:
		return

	match state:
		&"idle":
			_cool -= delta
			if _cool > 0.0 or _left <= 0 or not Game.is_outside() or _flat(p.global_position, HOME) < 60.0:
				return
			if Game.yrka != null and Game.yrka.stage >= YrkaThreat.Stage.CONTACT:
				return
			if Director.request_ambient(6.0, "волки рядом") or _cool < -120.0:
				start()
		&"howl":
			_t -= delta
			if _t <= 0.0:
				_spawn_pairs(p.global_position)
				state = &"circling"
				_t = 0.0
		&"circling":
			_tick_circling(delta, p)
		&"lunge":
			_tick_lunge(delta, p)


# --- Дневная живность (беляки и таёжная лиса) --------------------------------

func _spawn_day_fauna() -> void:
	if Game.yard == null or not is_inside_tree():
		return
	var hare_spots := [
		Vector3(28.0, 0.0, 14.0),
		Vector3(-12.0, 0.0, 22.0),
		Vector3(44.0, 0.0, -8.0),
		Terrain.pad_pos(&"camp") + Vector3(8.0, 0.0, 7.0),
	]
	for spot: Vector3 in hare_spots:
		var h_node := _make_hare()
		var p := Vector3(spot.x, Terrain.height(spot.x, spot.z), spot.z)
		h_node.position = p
		h_node.rotation.y = _rng.randf() * TAU
		Game.yard.add_child(h_node)
		_hares.append({
			"node": h_node,
			"home": p,
			"target": p + Vector3(_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-5.0, 5.0)),
			"hop": _rng.randf() * TAU,
			"pause": _rng.randf_range(0.5, 3.5),
			"flee": 0.0,
		})

	var fox_route := [
		Vector3(-10.0, 0.0, 26.0),
		Vector3(4.0, 0.0, 32.0),
		Vector3(18.0, 0.0, 22.0),
		Vector3(24.0, 0.0, 8.0),
		Vector3(-2.0, 0.0, 16.0),
	]
	var f_node := _make_fox()
	var fp: Vector3 = fox_route[0]
	fp.y = Terrain.height(fp.x, fp.z)
	f_node.position = fp
	Game.yard.add_child(f_node)
	_fox = {
		"node": f_node,
		"route": fox_route,
		"idx": 1,
		"pause": 1.0,
		"flee": 0.0,
		"yaw": 0.0,
	}


func _clear_day_fauna() -> void:
	for h: Dictionary in _hares:
		if is_instance_valid(h.get("node")):
			(h["node"] as Node3D).queue_free()
	_hares.clear()
	if not _fox.is_empty() and is_instance_valid(_fox.get("node")):
		(_fox["node"] as Node3D).queue_free()
	_fox = {}


func _make_hare() -> Node3D:
	var root := Node3D.new()
	root.name = "SnowHare"
	var white := Color(0.92, 0.93, 0.95)
	var ear_tip := Color(0.08, 0.08, 0.09)
	var eye := Color(0.04, 0.03, 0.03)
	var k := MeshKit.new(randi())
	k.blob(Vector3(0, 0.13, 0.02), Vector3(0.11, 0.10, 0.18), white, 6, 8)
	k.blob(Vector3(0, 0.21, -0.14), Vector3(0.075, 0.075, 0.095), white, 6, 6)
	k.blob(Vector3(0, 0.12, 0.19), Vector3(0.055, 0.055, 0.055), white, 5, 5)
	for s: float in [-1.0, 1.0]:
		k.tube([Vector3(0.03 * s, 0.26, -0.13), Vector3(0.045 * s, 0.39, -0.10)], [0.018, 0.011], white, 5)
		k.tube([Vector3(0.043 * s, 0.37, -0.105), Vector3(0.047 * s, 0.42, -0.095)], [0.012, 0.006], ear_tip, 5)
		k.blob(Vector3(0.05 * s, 0.22, -0.18), Vector3(0.014, 0.014, 0.014), eye, 4, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"hare", Color.WHITE, "", 0.02)
	root.add_child(mi)
	return root


func _make_fox() -> Node3D:
	var root := Node3D.new()
	root.name = "TaigaFox"
	var russet := Color(0.76, 0.33, 0.10)
	var white := Color(0.92, 0.90, 0.86)
	var dark := Color(0.09, 0.07, 0.06)
	var k := MeshKit.new(randi())
	k.tube([Vector3(0, 0.26, 0.24), Vector3(0, 0.28, 0.0), Vector3(0, 0.31, -0.22)], [0.09, 0.11, 0.10], russet, 7)
	k.blob(Vector3(0, 0.26, -0.24), Vector3(0.08, 0.09, 0.08), white, 5, 6)
	k.blob(Vector3(0, 0.37, -0.34), Vector3(0.09, 0.085, 0.10), russet, 6, 7)
	k.spike(Vector3(0, 0.35, -0.40), Vector3(0, 0.33, -0.54), 0.038, russet, 6)
	k.blob(Vector3(0, 0.332, -0.54), Vector3(0.014, 0.014, 0.014), dark, 4, 4)
	for s: float in [-1.0, 1.0]:
		k.spike(Vector3(0.055 * s, 0.43, -0.31), Vector3(0.07 * s, 0.54, -0.30), 0.025, dark, 4)
		k.tube([Vector3(0.07 * s, 0.24, -0.18), Vector3(0.07 * s, 0.0, -0.18)], [0.025, 0.015], dark, 5)
		k.tube([Vector3(0.07 * s, 0.24, 0.18), Vector3(0.07 * s, 0.0, 0.19)], [0.028, 0.016], dark, 5)
	# Пышный хвост с белым кончиком
	k.tube([Vector3(0, 0.27, 0.26), Vector3(0, 0.24, 0.48)], [0.055, 0.068], russet, 6)
	k.tube([Vector3(0, 0.24, 0.48), Vector3(0, 0.22, 0.63)], [0.064, 0.025], white, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"fox", Color.WHITE, "", 0.02)
	root.add_child(mi)
	return root


func _tick_hares(delta: float, p: Player) -> void:
	var pp := p.global_position
	var riding_noise := Game.has_flag("riding") and Snowmobile.instance != null and Snowmobile.instance.engine_on
	var danger := Game.yrka != null and Game.yrka.enabled and Game.yrka.stage >= YrkaThreat.Stage.CALLING
	for h: Dictionary in _hares:
		var node: Node3D = h["node"]
		if not is_instance_valid(node):
			continue
		var pos := node.position
		var dist := Vector2(pos.x - pp.x, pos.z - pp.z).length()
		var scare_r := 22.0 if riding_noise else 12.0
		if danger or (Game.is_outside() and dist < scare_r):
			h["flee"] = 4.5
			var away := (pos - pp)
			away.y = 0.0
			away = away.normalized() if away.length_squared() > 0.01 else Vector3(1, 0, 0)
			h["target"] = (h["home"] as Vector3) + away * 18.0
		if float(h["flee"]) > 0.0:
			h["flee"] = float(h["flee"]) - delta
		var tgt: Vector3 = h["target"]
		var to := tgt - pos
		to.y = 0.0
		if to.length() < 0.4:
			if float(h["pause"]) > 0.0:
				h["pause"] = float(h["pause"]) - delta
				node.position.y = Terrain.height(pos.x, pos.z)
			else:
				h["pause"] = _rng.randf_range(1.2, 4.0)
				var base_c: Vector3 = h["home"]
				h["target"] = base_c + Vector3(_rng.randf_range(-8.0, 8.0), 0.0, _rng.randf_range(-8.0, 8.0))
			continue
		var spd := 5.4 if float(h["flee"]) > 0.0 else 1.8
		var dir := to.normalized()
		var step := dir * minf(spd * delta, to.length())
		pos += step
		h["hop"] = float(h["hop"]) + delta * (14.0 if spd > 3.0 else 8.0)
		var bounce := absf(sin(float(h["hop"]))) * (0.26 if spd > 3.0 else 0.14)
		pos.y = Terrain.height(pos.x, pos.z) + bounce
		node.position = pos
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-dir.x, -dir.z), minf(delta * 10.0, 1.0))


func _tick_fox(delta: float, p: Player) -> void:
	if _fox.is_empty() or not is_instance_valid(_fox.get("node")):
		return
	var node: Node3D = _fox["node"]
	var route: Array = _fox["route"]
	var idx := int(_fox["idx"])
	var tgt: Vector3 = route[idx]
	var pos := node.position
	var pp := p.global_position
	var dist := Vector2(pos.x - pp.x, pos.z - pp.z).length()
	var scare_r := 20.0 if (Game.has_flag("riding") and Snowmobile.instance != null and Snowmobile.instance.engine_on) else 10.5
	if Game.is_outside() and dist < scare_r:
		_fox["flee"] = 3.0
		_fox["pause"] = 0.0
	if float(_fox["flee"]) > 0.0:
		_fox["flee"] = float(_fox["flee"]) - delta
	if float(_fox["pause"]) > 0.0:
		_fox["pause"] = float(_fox["pause"]) - delta
		node.rotation.y += sin(Time.get_ticks_msec() * 0.003) * 0.4 * delta
		return
	var to := tgt - pos
	to.y = 0.0
	if to.length() < 0.6:
		_fox["idx"] = (idx + 1) % route.size()
		_fox["pause"] = _rng.randf_range(1.5, 4.0)
		return
	var spd := 4.8 if float(_fox["flee"]) > 0.0 else 1.7
	var dir := to.normalized()
	pos += dir * minf(spd * delta, to.length())
	pos.y = Terrain.height(pos.x, pos.z) + absf(sin(Time.get_ticks_msec() * 0.012)) * 0.05
	node.position = pos
	_fox["yaw"] = lerp_angle(float(_fox["yaw"]), atan2(-dir.x, -dir.z), minf(delta * 7.0, 1.0))
	node.rotation.y = float(_fox["yaw"])


# --- Ночной филин: живой индикатор спокойного сектора леса ---------------------

func _tick_owl(delta: float, p: Player) -> void:
	# Если рядом Ырка или стая волков — филин молчит
	if state != &"idle" or (Game.yrka != null and Game.yrka.stage >= YrkaThreat.Stage.CALLING):
		return
	_owl_t -= delta
	if _owl_t <= 0.0:
		_owl_t = _rng.randf_range(40.0, 85.0)
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(26.0, 48.0)
		var pos := p.global_position + Vector3(cos(ang) * d, 9.0, sin(ang) * d)
		if Game.audio != null:
			Game.audio.play_3d(OWL, pos, -8.0, 22.0)


# --- Ночная волчья стая ------------------------------------------------------

func start() -> void:
	if Game.player == null:
		return
	_left -= 1
	state = &"howl"
	_t = 4.5
	var p := Game.player.global_position
	var a := _rng.randf() * TAU
	Game.audio.play_3d(HOWL, p + Vector3(cos(a), 0.0, sin(a)) * 38.0 + Vector3(0, 2, 0), 4.0, 30.0)
	Game.hud.subtitle(Loc.t(&"wolf.howl"), 4.5)


func _spawn_pairs(at: Vector3) -> void:
	_clear()
	var n := _rng.randi_range(3, 4)
	for i in n:
		var node := Node3D.new()
		node.name = "WolfEyes"
		Game.yard.add_child(node)
		for sx: float in [-0.07, 0.07]:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.075, 0.055)
			q.mesh = qm
			q.material_override = _eye_mat
			q.position = Vector3(sx, 0.0, 0.0)
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(q)
		_pairs.append({"node": node, "a": TAU * i / n + _rng.randf_range(-0.4, 0.4), "r": _rng.randf_range(18.0, 25.0), "alive": true, "spd": _rng.randf_range(0.05, 0.12) * (1.0 if i % 2 == 0 else -1.0), "blink": 0.0})
	_still_t = 0.0
	_last_p = at
	_growl_t = 1.5
	Game.hud.subtitle(Loc.t(&"wolf.eyes"), 5.0)
	Director.add_tension(10.0, "волчьи глаза в темноте")


func _tick_circling(delta: float, p: Player) -> void:
	var pp := p.global_position
	_t += delta
	# Тварь рядом — волки уходят разом, без звука
	if Game.yrka != null and (Game.yrka.stage >= YrkaThreat.Stage.PRESSURE or Vector2(pp.x, pp.z).distance_to(Game.yrka.virtual_pos) < 45.0):
		_flee(&"wolf.flee_yrka")
		return
	# Ракета в воздухе — уходят все
	if not get_tree().root.find_children("*", "Flare", true, false).is_empty():
		_flee(&"wolf.flee_flare")
		return
	if _flat(pp, HOME) < 35.0 or not Game.is_outside():
		_flee(&"wolf.flee_home")
		return
	var dog_k := 1.38 if Dog.instance != null and Dog.is_near_player() else 1.0
	var cam := p.camera
	var headlight_on := Game.has_flag("riding") and Snowmobile.instance != null and Snowmobile.instance.engine_on
	var alive := 0
	for w: Dictionary in _pairs:
		if not w["alive"]:
			continue
		alive += 1
		w["a"] = float(w["a"]) + float(w["spd"]) * delta
		var r: float = float(w["r"]) * dog_k
		var pos := pp + Vector3(cos(w["a"]), 0.0, sin(w["a"])) * r
		pos.y = Terrain.height(pos.x, pos.z) + 0.55
		var node: Node3D = w["node"]
		node.global_position = pos
		w["blink"] = float(w["blink"]) - delta
		if float(w["blink"]) <= 0.0:
			w["blink"] = _rng.randf_range(1.5, 4.0)
			node.visible = not node.visible if _rng.randf() < 0.3 else true
		# Луч фонаря ИЛИ фара «Бурана» прямо на пару — пятится и гаснет
		var flash_hit := p.flashlight != null and p.flashlight.visible and cam != null and (-cam.global_transform.basis.z).dot((pos - cam.global_position).normalized()) > 0.975
		var buran_hit := headlight_on and Snowmobile.instance.global_basis.z.dot((Snowmobile.instance.global_position - pos).normalized()) > 0.93
		if flash_hit or buran_hit:
			w["alive"] = false
			node.queue_free()
			Game.audio.play_3d(GROWLS[_rng.randi() % GROWLS.size()], pos, -6.0, 12.0)
			Game.hud.subtitle(Loc.t(&"wolf.backs"), 2.5)
	if alive <= 1:
		_flee(&"wolf.flee_light")
		return
	_growl_t -= delta
	if _growl_t <= 0.0:
		_growl_t = _rng.randf_range(3.0, 6.0)
		var w: Dictionary = _pairs[_rng.randi() % _pairs.size()]
		if w["alive"]:
			Game.audio.play_3d(GROWLS[_rng.randi() % GROWLS.size()], (w["node"] as Node3D).global_position, 0.0, 14.0)
	if pp.distance_to(_last_p) > 4.0:
		_last_p = pp
		_still_t = maxf(_still_t - 6.0, 0.0)
	else:
		_still_t += delta
	if _still_t > 25.0 or _t > 70.0:
		for w: Dictionary in _pairs:
			if w["alive"]:
				_lunge = w
				state = &"lunge"
				Game.audio.play_3d(GROWLS[0], (w["node"] as Node3D).global_position, 4.0, 16.0)
				return


func _tick_lunge(delta: float, p: Player) -> void:
	if _lunge.is_empty() or not is_instance_valid(_lunge["node"]):
		_flee(&"wolf.flee_light")
		return
	var node: Node3D = _lunge["node"]
	var to := p.global_position + Vector3(0, 0.6, 0) - node.global_position
	node.global_position += to.normalized() * minf(to.length(), 13.0 * delta)
	if to.length() < 1.2:
		Game.hud.flash_red(0.8, 0.6)
		p.shake(0.12, 0.6)
		Game.add_fatigue(25.0)
		Game.warmth = maxf(Game.warmth - 10.0, 0.0)
		Director.add_tension(20.0, "волк бросился")
		Game.audio.play_2d(GROWLS[1], 2.0)
		_flee(&"wolf.bite")


func _flee(key: StringName) -> void:
	state = &"idle"
	_cool = _rng.randf_range(160.0, 300.0)
	_clear()
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(key), 5.0)
	if key == &"wolf.flee_yrka":
		Director.add_tension(12.0, "волки смолкли — он рядом")
	else:
		Director.add_tension(-6.0, "волки ушли")


func _clear() -> void:
	for w: Dictionary in _pairs:
		if is_instance_valid(w["node"]):
			(w["node"] as Node3D).queue_free()
	_pairs.clear()
	_lunge = {}


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
