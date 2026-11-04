class_name Wildlife
extends Node
## Звери — не всё, что ходит ночью, — тварь.
## Волки (ночи 2+, вдали от дома, раз-два за ночь): вой рядом, потом глаза в темноте — 3–4 пары
## кружат на 16–26 м и рычат. Отогнать: луч фонаря прямо на пару (пятится и гаснет), ракета — уходят все,
## Найда рядом — держатся дальше. Стоишь столбом 25 с — один бросается: укус (усталость, холод, рывок).
## Главное: если рядом тварь, волки разом смолкают и уходят. «Замолчали волки — значит, он здесь».

const HOWL := "res://assets/audio/wolf_howl.ogg"
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


func _ready() -> void:
	name = "Wildlife"
	if not Game.is_night() or Game.is_prologue() or Game.night < 2:
		queue_free()
		return
	instance = self
	_rng.seed = Game.run_seed + Game.night * 71
	_left = 1 if Game.night <= 3 else 2
	_cool = _rng.randf_range(60.0, 140.0)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = Color(0.95, 0.85, 0.35)
	_eye_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_eye_mat.disable_fog = true   # глаза светятся сквозь туман, как в свете луны


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


func _process(delta: float) -> void:
	var p := Game.player
	if p == null:
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
	var dog_k := 1.35 if Dog.instance != null and Dog.is_near_player() else 1.0
	var cam := p.camera
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
		# Моргают — глаза то гаснут, то загораются
		w["blink"] = float(w["blink"]) - delta
		if float(w["blink"]) <= 0.0:
			w["blink"] = _rng.randf_range(1.5, 4.0)
			node.visible = not node.visible if _rng.randf() < 0.3 else true
		# Луч фонаря прямо на пару — пятится и гаснет
		if p.flashlight != null and p.flashlight.visible and cam != null:
			var to := (pos - cam.global_position).normalized()
			if (-cam.global_transform.basis.z).dot(to) > 0.975:
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
	# Стоишь на месте — смелеют
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
