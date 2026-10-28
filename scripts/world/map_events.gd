class_name MapEvents
extends Node3D
## События большой карты (как в VotV): раз в 40–90 с директор пробует одно событие,
## если игрок снаружи. Часть событий срабатывает по близости к точкам (лесосека, буровая).
## Каждое событие — функция _ev_<id>(), которая ставит сцену и возвращает словарь:
##   {"node": Node3D, "update": Callable(delta) -> bool (false — убрать), "ttl": секунды}
## Новое событие = новая функция + строчка в POOL.

const POOL := [
	# id, вес, когда (&"night" | &"day" | &"any"), раз за фазу
	[&"gtt_ghost", 1.0, &"any", 1],
	[&"campfire", 1.3, &"night", 1],
	[&"road_figure", 1.6, &"night", 2],
	[&"probe", 1.6, &"day", 1],
	[&"foreign_tracks", 1.0, &"day", 1],
	[&"tower_lights", 1.0, &"night", 1],
	[&"twin_buran", 0.08, &"night", 1],      ## редкое: твой «Буран» стоит там, где его быть не может
	# Ближние события — в 20–70 м от игрока, чтобы двор и тропы жили, а не только дальние зимники
	[&"snowman", 1.2, &"day", 1],
	[&"name_in_snow", 0.9, &"day", 1],
	[&"blood_trail", 1.0, &"any", 1],
	[&"tree_fall", 1.4, &"any", 2],
	[&"distant_horn", 0.8, &"day", 1],
	[&"lantern_walker", 1.5, &"night", 2],
	[&"tree_knocks", 1.3, &"night", 2],
	[&"whistle_call", 1.1, &"night", 1],
	[&"eyes", 1.3, &"night", 2],
	[&"wolf_chorus", 0.9, &"night", 1],
]

## Места, у которых ближние события не ставим (дом, сараи, точки карты).
const KEEP_OUT := [Vector3(6.1, 0, 3.6), Vector3(1.0, 0, 3.6), Vector3(12.0, 0, 3.6), Vector3(17.0, 0, 3.5), Vector3(14.5, 0, -13.0), Vector3(48, 0, 34), Vector3(-16, 0, -30),
	Vector3(72, 0, -62), Vector3(58, 0, -32), Vector3(-36, 0, 20), Vector3(58, 0, 12), Vector3(44, 0, 6), Vector3(24, 0, -62)]

static var instance: MapEvents

var _active: Array[Dictionary] = []
var _count: Dictionary = {}        ## id → сколько раз за фазу
var _cd := 60.0
var _phase_key := ""
var _roads: Array[PackedVector3Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	instance = self
	name = "MapEvents"
	_rng.randomize()
	_cd = _rng.randf_range(45.0, 80.0)
	for r: StringName in Terrain.ROADS:
		if r != &"old_cut":
			_roads.append(Terrain.road_points(r, 4.0))


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _phase() -> String:
	return "%s_%d" % [Game.phase_kind, Game.phase_index]


func _process(delta: float) -> void:
	if Game.player == null or Game.is_prologue_trail():
		return
	var pk := _phase()
	if pk != _phase_key:
		_phase_key = pk
		_count.clear()
	# Активные события живут сами
	for i in range(_active.size() - 1, -1, -1):
		var ev: Dictionary = _active[i]
		ev["ttl"] = float(ev["ttl"]) - delta
		var keep: bool = (ev["update"] as Callable).call(delta) if ev.has("update") else true
		var n: Node = ev.get("node")
		if not keep or float(ev["ttl"]) <= 0.0 or n == null or not is_instance_valid(n):
			if n != null and is_instance_valid(n) and not ev.get("keep_node", false):
				n.queue_free()
			_active.remove_at(i)
	_proximity()
	if not Game.is_outside() or Game.is_prologue():
		return
	_cd -= delta
	if _cd > 0.0:
		return
	_cd = _rng.randf_range(40.0, 90.0)
	if _active.size() >= 2:
		return
	force(_pick())


## Запустить событие вручную (и для автотеста).
func force(id: StringName) -> bool:
	if id == &"":
		return false
	var fn := "_ev_" + String(id)
	if not has_method(fn):
		return false
	var ev: Dictionary = call(fn)
	if ev.is_empty():
		return false
	ev["id"] = id
	_active.append(ev)
	_count[id] = int(_count.get(id, 0)) + 1
	print("[events] ", id)
	return true


func active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for ev in _active:
		out.append(ev["id"])
	return out


func _pick() -> StringName:
	var night := not Game.is_daylight()
	var total := 0.0
	var cands: Array = []
	for e: Array in POOL:
		var when: StringName = e[2]
		if when == &"night" and not night:
			continue
		if when == &"day" and night:
			continue
		if int(_count.get(e[0], 0)) >= int(e[3]):
			continue
		if e[0] == &"road_figure" and not Game.has_flag("riding"):
			continue
		cands.append(e)
		total += float(e[1])
	if cands.is_empty():
		return &""
	var r := _rng.randf() * total
	for e: Array in cands:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return cands[-1][0]


# --- Помощники ---------------------------------------------------------------------

func _ppos() -> Vector3:
	return Game.player.global_position


## Точка на любом зимнике на расстоянии [lo, hi] от игрока (и не во дворе). Возвращает [pos, dir] или [].
func _road_spot(lo: float, hi: float) -> Array:
	var p := _ppos()
	var best: Array = []
	for _try in 24:
		var road: PackedVector3Array = _roads[_rng.randi() % _roads.size()]
		var k := _rng.randi_range(1, road.size() - 2)
		var q := road[k]
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < lo or d > hi:
			continue
		if Vector2(q.x, q.z).distance_to(Terrain.CENTER) < Terrain.FLAT_R - 10.0:
			continue
		var dir := (road[k + 1] - road[k - 1])
		dir.y = 0.0
		best = [q, dir.normalized()]
		break
	return best


## Точка в лесу сбоку от дороги.
func _forest_spot(lo: float, hi: float, off_road: float) -> Vector3:
	var rs := _road_spot(lo, hi)
	if rs.is_empty():
		return Vector3.INF
	var q: Vector3 = rs[0]
	var dir: Vector3 = rs[1]
	var side := Vector3(-dir.z, 0, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var f := q + side * off_road
	f.y = Terrain.height(f.x, f.z)
	return f


func _say(key: StringName, dur := 4.0) -> void:
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(key), dur)


func _loop3d(parent: Node3D, path: String, vol: float, unit: float, pitch := 1.0) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = AudioDirector.cached_stream(path)
	a.volume_db = vol
	a.unit_size = unit
	a.max_distance = unit * 40.0
	a.pitch_scale = pitch
	a.bus = &"SFX"
	parent.add_child(a)
	a.finished.connect(a.play)
	a.play()
	return a


func _root_at(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	return n


# --- События ----------------------------------------------------------------------

## ГТ-Т на зимнике: мотор работает, фары горят, дверь открыта, в кабине никого.
func _ev_gtt_ghost() -> Dictionary:
	var rs := _road_spot(110.0, 220.0)
	if rs.is_empty():
		return {}
	var root := _root_at(rs[0])
	var dir: Vector3 = rs[1]
	root.rotation.y = atan2(-dir.x, -dir.z) + PI * 0.06
	var m := Props.gtt_transporter()
	root.add_child(m)
	for sx: float in [-0.75, 0.75]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(sx, 1.4, -3.0)
		sl.light_color = Color(1.0, 0.9, 0.7)
		sl.light_energy = 4.0
		sl.spot_range = 40.0
		sl.spot_angle = 24.0
		sl.distance_fade_enabled = true
		sl.distance_fade_begin = 300.0
		root.add_child(sl)
	var snd := _loop3d(root, "res://assets/audio/engine_loop.ogg", -4.0, 10.0)
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.add_child(Geo.box_shape(Vector3(3.0, 2.4, 6.6), Vector3(0, 1.2, 0)))
	root.add_child(body)
	var st := {"seen": false}
	return {"node": root, "ttl": 420.0, "update": func(_d: float) -> bool:
		var d := _ppos().distance_to(root.global_position)
		if not st["seen"] and d < 9.0:
			st["seen"] = true
			snd.stop()
			Game.audio.play_3d("res://assets/audio/clank.ogg", root.global_position, -4.0)
			_say(&"ev.gtt_empty", 5.0)
			Director.add_tension(10.0, "пустой ГТ-Т на зимнике")
		return not (st["seen"] and d > 160.0)}


## Костёр в лесу: виден издалека, а подойдёшь — угли холодные, вокруг босые следы.
func _ev_campfire() -> Dictionary:
	var f := _forest_spot(80.0, 170.0, _rng.randf_range(16.0, 28.0))
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.6, 0)
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 260.0
	root.add_child(light)
	var flame_m := StandardMaterial3D.new()
	flame_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_m.albedo_color = Color(1.0, 0.6, 0.2)
	var flames: Array[MeshInstance3D] = []
	for i in 3:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.16 - i * 0.03
		cm.height = 0.55 - i * 0.1
		cm.radial_segments = 5
		c.mesh = cm
		c.material_override = flame_m
		c.position = Vector3(randf_range(-0.12, 0.12), 0.3, randf_range(-0.12, 0.12))
		root.add_child(c)
		flames.append(c)
	var logs_m := Palette.m(&"canister")
	for a in 4:
		var lg := Geo.block(root, Vector3(0.08, 0.08, 0.7), Vector3(0, 0.06, 0), logs_m, false)
		lg.rotation.y = a * PI / 4.0
	var snd := _loop3d(root, "res://assets/audio/fire_loop.ogg", -2.0, 4.0)
	for i in 14:
		var ang := i * TAU / 14.0 + randf_range(-0.2, 0.2)
		var r := randf_range(1.4, 2.6)
		var fp := f + Vector3(cos(ang) * r, 0, sin(ang) * r)
		fp.y = Terrain.height(fp.x, fp.z) + 0.02
		var mk := Footprints.make(&"bare", Vector3.ZERO, ang + PI * 0.5, i % 2 == 0)
		root.add_child(mk)
		mk.global_position = fp
	var st := {"out": false, "t": 0.0}
	return {"node": root, "ttl": 600.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var dist := _ppos().distance_to(root.global_position)
		if not st["out"]:
			light.light_energy = 2.6 + sin(float(st["t"]) * 13.0) * 0.4 + sin(float(st["t"]) * 7.3) * 0.3
			if dist < 13.0:
				st["out"] = true
				light.visible = false
				for fl in flames:
					fl.visible = false
				snd.stop()
				Game.audio.play_3d("res://assets/audio/gust.ogg", root.global_position, 0.0)
				_say(&"ev.fire_out", 5.0)
				Director.add_tension(12.0, "костёр погас")
		return not (st["out"] and dist > 140.0)}


## На зимнике в свете фары «Бурана» стоит человек. Моргнёшь — его нет.
func _ev_road_figure() -> Dictionary:
	var p := _ppos()
	var fwd := -Game.player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var want := p + fwd * 48.0
	var best := Vector3.INF
	var bd := 1e9
	for road in _roads:
		for q in road:
			var dd := Vector2(q.x - want.x, q.z - want.z).length_squared()
			if dd < bd:
				bd = dd
				best = q
	if bd > 25.0 * 25.0:
		return {}
	var root := _root_at(best)
	var fig := Creatures.make_silhouette()
	root.add_child(fig)
	var to := p - best
	root.rotation.y = atan2(-to.x, -to.z)
	var st := {"t": 0.0}
	return {"node": root, "ttl": 20.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var dist := _ppos().distance_to(root.global_position)
		if dist < 22.0 or float(st["t"]) > 9.0:
			Game.audio.play_3d("res://assets/audio/whisper.ogg", root.global_position + Vector3(0, 1.5, 0), -4.0)
			Director.add_tension(14.0, "фигура на зимнике")
			return false
		return true}


## Упавший метеозонд: днём, у дороги. Сдашь — Свердловск начислит пайки.
func _ev_probe() -> Dictionary:
	var f := _forest_spot(100.0, 240.0, _rng.randf_range(6.0, 14.0))
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.9, 0.86)
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.9, 0.35, 0.08)
	Geo.block(root, Vector3(0.28, 0.22, 0.2), Vector3(0, 0.11, 0), orange, false)
	var chute := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.2, 1.6)
	pm.subdivide_width = 4
	pm.subdivide_depth = 3
	chute.mesh = pm
	chute.material_override = white
	chute.position = Vector3(1.4, 0.05, 0.4)
	chute.rotation = Vector3(deg_to_rad(4.0), 0.4, deg_to_rad(-6.0))
	root.add_child(chute)
	var it := Geo.interactable(root, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), null, Loc.t(&"ev.probe_prompt"), Callable())
	var st := {"taken": false}
	it.used.connect(func(_p: Player) -> void:
		if st["taken"]:
			return
		st["taken"] = true
		Supply.add(2, &"sup.r_probe")
		FieldJobs.on_probe_taken(root.global_position)
		Game.audio.play_3d("res://assets/audio/clank.ogg", root.global_position, -6.0)
		root.queue_free())
	var beep := OmniLight3D.new()
	beep.light_color = Color(1.0, 0.25, 0.1)
	beep.omni_range = 4.0
	beep.position = Vector3(0, 0.35, 0)
	root.add_child(beep)
	var t := {"t": 0.0}
	return {"node": root, "ttl": 1500.0, "update": func(d: float) -> bool:
		t["t"] = float(t["t"]) + d
		beep.light_energy = 2.0 if fmod(float(t["t"]), 1.6) < 0.2 else 0.0
		return not st["taken"]}


## Чужой след снегохода: от гаража в лес — и обрывается посреди целины.
func _ev_foreign_tracks() -> Dictionary:
	var start := Snowmobile.PARK + Vector3(-3.0, 0, -4.0)
	var ang := _rng.randf_range(-0.6, 0.6) + PI * 0.75
	var dir := Vector3(cos(ang), 0, sin(ang))
	var root := _root_at(start)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.6, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.55
	var trail_len := 85.0
	var seg := 2.0
	var s := 0.0
	var wob := _rng.randf() * 10.0
	while s < trail_len:
		var p := start + dir * s + Vector3(-dir.z, 0, dir.x) * sin(s * 0.05 + wob) * 3.0
		p.y = Terrain.height(p.x, p.z) + 0.03
		for sx: float in [-0.24, 0.24]:
			var q := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.36, seg + 0.1)
			q.mesh = pm
			q.material_override = m
			root.add_child(q)
			q.global_position = p + Vector3(-dir.z, 0, dir.x) * sx
			q.rotation.y = atan2(-dir.x, -dir.z)
		s += seg
	return {"node": root, "ttl": 1800.0, "keep_node": false}


## Огонёк на старой метеовышке мигает морзянкой — видно даже со двора.
func _ev_tower_lights() -> Dictionary:
	var c := Terrain.pad_pos(&"tower") + Vector3(0, 21.0, 0)
	var root := _root_at(c)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.5)
	l.omni_range = 14.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 700.0
	root.add_child(l)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	bulb.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.9, 0.6)
	bulb.material_override = bm
	root.add_child(bulb)
	# «КЕДР» морзянкой: -.- . -.. .-.
	var pattern := "-.- . -.. .-."
	var seq: Array[float] = []
	for ch in pattern:
		if ch == "-":
			seq.append_array([0.9, 0.3])
		elif ch == ".":
			seq.append_array([0.3, 0.3])
		else:
			seq.append_array([0.0, 0.9])
	seq.append_array([0.0, 3.0])
	var st := {"i": 0, "t": 0.0}
	return {"node": root, "ttl": 200.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) - d
		if float(st["t"]) <= 0.0:
			var i: int = st["i"]
			var on := i % 2 == 0 and seq[i] > 0.0
			l.visible = on
			bulb.visible = on
			st["t"] = seq[i] if seq[i] > 0.0 else 0.01
			st["i"] = (i + 1) % seq.size()
		return true}


## Редкое: твой «Буран» стоит на дальнем зимнике с горящей фарой. Подъедешь — его нет, а следов к нему не было.
func _ev_twin_buran() -> Dictionary:
	var rs := _road_spot(140.0, 260.0)
	if rs.is_empty():
		return {}
	var root := _root_at(rs[0])
	var dir: Vector3 = rs[1]
	root.rotation.y = atan2(-dir.x, -dir.z)
	if Models.spawn(root, "kedr/buran", Vector3.ZERO, 0.0, -1.0, {"grime": 0.0, "bright": 1.15, "sat": 0.95}) == null:
		return {}
	var sl := SpotLight3D.new()
	sl.position = Vector3(0, 0.8, -0.85)
	sl.light_energy = 3.5
	sl.spot_range = 34.0
	sl.spot_angle = 30.0
	root.add_child(sl)
	return {"node": root, "ttl": 300.0, "update": func(_d: float) -> bool:
		if _ppos().distance_to(root.global_position) < 30.0:
			Game.audio.play_3d("res://assets/sfx/wind_gust.ogg", root.global_position, 0.0)
			Director.add_tension(18.0, "второй Буран")
			return false
		return true}


# --- События по близости к точкам ----------------------------------------------------

func _proximity() -> void:
	if not Game.is_outside():
		return
	var p := _ppos()
	_near_once(&"meteo_screen", p, Vector3(58, 0, -32), 26.0)
	if Game.is_daylight():
		_near_once(&"shed_prints", p, Vector3(48, 0, 34), 38.0)
		return
	_near_ring(&"izba_light", p, Vector3(-16, 0, -30), 40.0, 95.0)
	_near_once(&"lake_knock", p, Vector3(-38, 0, 34), 30.0)
	_near_once(&"repeater_song", p, Vector3(72, 0, -62), 38.0)
	if int(_count.get(&"camp_phone", 0)) == 0 and p.distance_to(Terrain.pad_pos(&"camp")) < 55.0:
		force(&"camp_phone")
	if int(_count.get(&"drill_breath", 0)) == 0 and p.distance_to(Terrain.pad_pos(&"drill")) < 60.0:
		force(&"drill_breath")


## На лесосеке в вагончике звонит полевой телефон. Линия оборвана ещё в марте.
func _ev_camp_phone() -> Dictionary:
	var c := Terrain.pad_pos(&"camp") + Vector3(6.0, 0.0, -8.0)
	c.y = Terrain.height(c.x, c.z)
	var root := _root_at(c)
	var ring := _loop3d(root, "res://assets/audio/buzzer_loop.ogg", 2.0, 5.0, 1.45)
	var it := Geo.interactable(root, Vector3(1.2, 1.4, 1.2), Vector3(0, 1.1, 0), null, Loc.t(&"ev.phone_prompt"), Callable())
	var st := {"answered": false}
	it.used.connect(func(_p: Player) -> void:
		if st["answered"]:
			return
		st["answered"] = true
		ring.stop()
		it.prompt = ""
		Game.audio.play_3d("res://assets/audio/static_loop.ogg", c + Vector3(0, 1.2, 0), -6.0, 2.0, 4.0)
		_say(&"ev.phone_call", 6.0)
		Director.add_tension(15.0, "телефон на лесосеке"))
	return {"node": root, "ttl": 240.0, "update": func(_d: float) -> bool:
		return not (st["answered"] and _ppos().distance_to(c) > 40.0)}


## Из скважины буровой тянет тёплым паром, и снизу слышно ровное дыхание.
func _ev_drill_breath() -> Dictionary:
	var c := Terrain.pad_pos(&"drill") + Vector3(0, 2.2, 0)
	var root := _root_at(c)
	var steam := CPUParticles3D.new()
	steam.amount = 40
	steam.lifetime = 4.0
	steam.direction = Vector3.UP
	steam.spread = 12.0
	steam.initial_velocity_min = 0.6
	steam.initial_velocity_max = 1.2
	steam.gravity = Vector3(0, 0.15, 0)
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.6
	var qm := QuadMesh.new()
	qm.size = Vector2(0.8, 0.8)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.8, 0.84, 0.88, 0.18)
	qm.material = sm
	steam.mesh = qm
	root.add_child(steam)
	_loop3d(root, "res://assets/audio/breath_loop.ogg", 4.0, 6.0, 0.55)
	_loop3d(root, "res://assets/sfx/underfloor_hum.ogg", 0.0, 8.0, 0.8)
	var st := {"said": false}
	return {"node": root, "ttl": 300.0, "update": func(_d: float) -> bool:
		var d := _ppos().distance_to(c)
		if not st["said"] and d < 25.0:
			st["said"] = true
			_say(&"ev.drill_steam", 5.0)
			Director.add_tension(10.0, "дыхание из скважины")
		return d < 120.0}


func _near_once(id: StringName, p: Vector3, at: Vector3, r: float) -> void:
	if int(_count.get(id, 0)) == 0 and Vector2(p.x - at.x, p.z - at.z).length() < r:
		force(id)


func _near_ring(id: StringName, p: Vector3, at: Vector3, lo: float, hi: float) -> void:
	var d := Vector2(p.x - at.x, p.z - at.z).length()
	if int(_count.get(id, 0)) == 0 and d > lo and d < hi:
		force(id)


# --- Ближние события ------------------------------------------------------------------

## Точка вокруг игрока в кольце [lo, hi] м; ahead — доля «впереди» (cos угла к взгляду ≥ ahead), −1 — где угодно.
func _near_spot(lo: float, hi: float, ahead := -1.0) -> Vector3:
	var p := _ppos()
	var fwd := -Game.player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for _try in 60:
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0.0, sin(a))
		if _try < 30 and dir.dot(fwd) < ahead:   # сперва — в поле зрения, потом где угодно
			continue
		var q := p + dir * _rng.randf_range(lo, hi)
		var bad := false
		for k: Vector3 in KEEP_OUT:
			if Vector2(q.x - k.x, q.z - k.z).length() < 13.0:
				bad = true
				break
		if bad:
			continue
		q.y = Terrain.height(q.x, q.z)
		return q
	return Vector3.INF


## Босые следы по ломаной в мировых координатах (Footprints.trail ставит их локально к узлу).
func _trail(root: Node3D, route: PackedVector3Array) -> void:
	var loc := PackedVector3Array()
	for q in route:
		loc.append(q - root.global_position)
	Footprints.trail(root, &"bare", loc, 0.01)


static var _dot_tex: Texture2D

## Мягкое круглое пятно для снежной пыли (вместо квадратов).
static func _soft_dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 32
		gt.height = 32
		_dot_tex = gt
	return _dot_tex


func _in_view(pos: Vector3) -> bool:
	var cam := Game.player.camera
	return cam != null and cam.is_position_in_frustum(pos)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _face(root: Node3D, to: Vector3) -> void:
	var d := to - root.global_position
	root.rotation.y = atan2(-d.x, -d.z)


func _snow_mat() -> Material:
	return Palette.m(&"snow")


func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.9
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Снеговик у тропы. Отвернёшься — он снова смотрит на тебя. Глаза — пуговицы от ватника.
func _ev_snowman() -> Dictionary:
	var f := _near_spot(22.0, 40.0, 0.2)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var snow := _snow_mat()
	_ball(root, 0.42, Vector3(0, 0.36, 0), snow)
	_ball(root, 0.3, Vector3(0, 0.98, 0), snow)
	var head := Node3D.new()
	head.position = Vector3(0, 1.42, 0)
	root.add_child(head)
	_ball(head, 0.21, Vector3.ZERO, snow)
	var dark := Palette.m(&"dark")
	for sx: float in [-0.07, 0.07]:
		_ball(head, 0.025, Vector3(sx, 0.04, -0.19), dark)
	for k in 3:
		_ball(root, 0.03, Vector3(0, 0.88 + k * 0.14, -0.29 + absi(k - 1) * 0.01), dark)
	# Руки-ветки
	for sx: float in [-1.0, 1.0]:
		var arm := Geo.cylinder(root, 0.018, 0.7, Vector3(sx * 0.48, 1.08, 0), Palette.m(&"bark"), false)
		arm.rotation.z = sx * deg_to_rad(62.0)
	_face(root, _ppos())
	var st := {"said": false, "away": 0.0}
	return {"node": root, "ttl": 900.0, "update": func(d: float) -> bool:
		var pp := _ppos()
		var dist := _flat_dist(pp, root.global_position)
		if _in_view(root.global_position + Vector3(0, 1.0, 0)):
			st["away"] = 0.0
		else:
			st["away"] = float(st["away"]) + d
			if float(st["away"]) > 2.5:
				_face(root, pp)
		if not st["said"] and dist < 5.0:
			st["said"] = true
			_say(&"ev.snowman", 5.0)
			Director.add_tension(8.0, "снеговик")
		return not (st["said"] and dist > 90.0)}


## Вытоптано в снегу: «ВИТЯ». От букв — босые следы в лес.
func _ev_name_in_snow() -> Dictionary:
	var f := _near_spot(18.0, 32.0, 0.3)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f + Vector3(0, 0.02, 0))
	var lb := Label3D.new()
	lb.text = Loc.p("ВИТЯ", "VITYA")
	lb.font_size = 220
	lb.pixel_size = 0.01
	lb.modulate = Color(0.16, 0.21, 0.3, 0.92)
	lb.outline_size = 0
	lb.rotation.x = PI / 2.0   # плашмя, верх букв — от игрока
	lb.scale.x = -1.0          # с этой стороны текст читается зеркально — отражаем
	lb.double_sided = true
	lb.no_depth_test = false
	root.add_child(lb)
	_face(root, _ppos())
	# Цепочка босых следов от надписи прочь от игрока
	var away := root.global_position - _ppos()
	away.y = 0.0
	away = away.normalized()
	var route := PackedVector3Array()
	for k in 4:
		var q := root.global_position + away * (1.5 + k * 6.0) + Vector3(-away.z, 0, away.x) * sin(k * 1.3) * 1.2
		q.y = Terrain.height(q.x, q.z)
		route.append(q)
	_trail(root, route)
	var st := {"said": false}
	return {"node": root, "ttl": 1200.0, "update": func(_d: float) -> bool:
		var dist := _flat_dist(_ppos(), root.global_position)
		if not st["said"] and dist < 7.0:
			st["said"] = true
			_say(&"ev.name_snow", 5.5)
			Director.add_tension(10.0, "имя в снегу")
		return not (st["said"] and dist > 80.0)}


## Глухаря утащили в лес: перья, кровь на снегу, след волочения — и двуногие следы рядом.
func _ev_blood_trail() -> Dictionary:
	var f := _near_spot(20.0, 45.0)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var blood := StandardMaterial3D.new()
	blood.albedo_color = Color(0.32, 0.03, 0.03)
	blood.roughness = 1.0
	var feather := StandardMaterial3D.new()
	feather.albedo_color = Color(0.16, 0.13, 0.1)
	feather.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 6:
		var spot := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(_rng.randf_range(0.35, 0.9), _rng.randf_range(0.3, 0.7))
		spot.mesh = pm
		spot.material_override = blood
		spot.position = Vector3(_rng.randf_range(-0.8, 0.8), 0.02 + k * 0.001, _rng.randf_range(-0.8, 0.8))
		spot.rotation.y = _rng.randf() * TAU
		root.add_child(spot)
	for k in 14:
		var fe := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.05, 0.16)
		fe.mesh = qm
		fe.material_override = feather
		fe.position = Vector3(_rng.randf_range(-1.6, 1.6), 0.04, _rng.randf_range(-1.6, 1.6))
		fe.rotation = Vector3(-PI / 2.0 + _rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, 0)
		root.add_child(fe)
	# След волочения и двуногие следы — в ближний лес
	var dir := Vector3(cos(_rng.randf() * TAU), 0, 0)
	dir.z = sqrt(1.0 - dir.x * dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var route := PackedVector3Array()
	for k in 4:
		var q := f + dir * (1.0 + k * 5.0)
		q.y = Terrain.height(q.x, q.z)
		route.append(q)
	_trail(root, route)
	for k in 9:
		var drag := MeshInstance3D.new()
		var pm2 := PlaneMesh.new()
		pm2.size = Vector2(0.12, 1.8)
		drag.mesh = pm2
		drag.material_override = blood if k < 2 else Footprints.material(&"snow")
		var q2 := f + dir * (1.0 + k * 1.8)
		drag.position = q2 - f + Vector3(0, 0.015 + Terrain.height(q2.x, q2.z) - f.y, 0)
		drag.rotation.y = atan2(-dir.x, -dir.z)
		root.add_child(drag)
	Game.audio.play_3d("res://assets/sfx/raven.ogg", f + Vector3(0, 8, 0), -2.0, 8.0)
	var st := {"said": false}
	return {"node": root, "ttl": 1200.0, "update": func(_d: float) -> bool:
		var dist := _flat_dist(_ppos(), root.global_position)
		if not st["said"] and dist < 6.0:
			st["said"] = true
			_say(&"ev.blood_trail", 6.0)
			Director.add_tension(9.0, "кровь на снегу")
		return not (st["said"] and dist > 80.0)}


## Рядом с треском валится ель под снегом: облако снежной пыли, ствол остаётся лежать.
func _ev_tree_fall() -> Dictionary:
	var f := _near_spot(28.0, 55.0)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var yaw := _rng.randf() * TAU
	var pivot := Node3D.new()
	pivot.rotation.y = yaw
	root.add_child(pivot)
	var tree := Node3D.new()
	pivot.add_child(tree)
	var sm_tree := MeshInstance3D.new()
	sm_tree.mesh = SpruceMesh.mesh(_rng.randi_range(0, 2))
	sm_tree.material_override = SpruceMesh.material()
	tree.add_child(sm_tree)
	var dust := CPUParticles3D.new()
	dust.emitting = false
	dust.one_shot = true
	dust.amount = 60
	dust.lifetime = 3.5
	dust.explosiveness = 0.8
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -0.4, 0)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.8, 0.3, 4.5)
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 1.4)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.78, 0.83, 0.9, 0.35)
	sm.albedo_texture = _soft_dot()
	qm.material = sm
	dust.mesh = qm
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.8
	dust.position = Vector3(0, 0.4, -4.5)
	pivot.add_child(dust)
	Game.audio.play_3d("res://assets/audio/tree_creak_v2.ogg", f + Vector3(0, 4, 0), 4.0, 10.0)
	var st := {"t": 0.0, "down": false}
	return {"node": root, "ttl": 600.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var t: float = st["t"]
		if t > 1.4 and not st["down"]:
			var k := clampf((t - 1.4) / 1.6, 0.0, 1.0)
			tree.rotation.x = -k * k * deg_to_rad(86.0)
			if k >= 1.0:
				st["down"] = true
				dust.emitting = true
				Game.audio.play_3d("res://assets/audio/sub_drop.ogg", f, 6.0, 12.0)
				Game.audio.play_3d("res://assets/audio/snow_fall.ogg", f, 2.0, 10.0)
				if _flat_dist(_ppos(), f) < 40.0:
					_say(&"ev.tree_fall", 4.0)
				Director.add_tension(5.0, "упала ель")
		return true}


## Днём со стороны зимника гудит колонна. Колонну ждали только в четверг.
func _ev_distant_horn() -> Dictionary:
	var rs := _road_spot(150.0, 320.0)
	if rs.is_empty():
		return {}
	var root := _root_at(rs[0])
	Game.audio.play_3d("res://assets/sfx/horn_far.ogg", rs[0] + Vector3(0, 3, 0), 8.0, 60.0)
	var st := {"t": 0.0, "n": 0}
	return {"node": root, "ttl": 30.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		if int(st["n"]) == 0 and float(st["t"]) > 4.0:
			st["n"] = 1
			Game.audio.play_3d("res://assets/sfx/horn_far_v2.ogg", rs[0] + Vector3(0, 3, 0), 6.0, 60.0)
		if int(st["n"]) == 1 and float(st["t"]) > 9.0:
			st["n"] = 2
			_say(&"ev.horn", 5.5)
			Director.add_tension(6.0, "гудок с зимника")
		return true}


## Между деревьев идёт кто-то с керосиновым фонарём. Подойдёшь — фонарь гаснет, шаги уходят.
func _ev_lantern_walker() -> Dictionary:
	var f := _near_spot(45.0, 70.0, -0.2)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.66, 0.3)
	l.light_energy = 2.4
	l.omni_range = 10.0
	l.position = Vector3(0, 1.0, 0)
	root.add_child(l)
	var bulb := _ball(root, 0.09, Vector3(0, 1.0, 0), Palette.glow(&"amber", true))
	var steps := _loop3d(root, "res://assets/sfx/snow_steps_walk.ogg", -8.0, 4.0, 0.9)
	# Идёт по касательной к игроку, медленно
	var to := _ppos() - f
	to.y = 0.0
	var dir := Vector3(-to.z, 0, to.x).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
	var st := {"t": 0.0, "out": false}
	return {"node": root, "ttl": 120.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var t: float = st["t"]
		if not st["out"]:
			var np := root.global_position + dir * 0.9 * d
			np.y = Terrain.height(np.x, np.z)
			root.global_position = np
			# Фонарь покачивается в руке
			l.position.y = 1.0 + sin(t * 4.2) * 0.05
			bulb.position = l.position + Vector3(sin(t * 2.1) * 0.04, 0, 0)
			l.light_energy = 1.5 + sin(t * 9.0) * 0.15
			if _flat_dist(_ppos(), root.global_position) < 28.0:
				st["out"] = true
				l.visible = false
				bulb.visible = false
				steps.stop()
				Game.audio.play_3d("res://assets/sfx/snow_steps_run.ogg", root.global_position, -2.0, 6.0)
				Game.audio.play_3d("res://assets/audio/whisper.ogg", root.global_position + Vector3(0, 1.4, 0), -6.0)
				_say(&"ev.lantern", 5.0)
				Director.add_tension(12.0, "фонарь в лесу")
		return not (st["out"] and float(st["t"]) > 8.0 and _flat_dist(_ppos(), root.global_position) > 30.0)}


## Стук по стволу: три удара — тишина — снова три, ближе. И ещё раз — совсем рядом.
func _ev_tree_knocks() -> Dictionary:
	var f := _near_spot(48.0, 60.0)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var st := {"t": 0.0, "stage": 0, "beat": 0, "next": 0.5}
	var dists := [55.0, 36.0, 19.0]
	return {"node": root, "ttl": 60.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var stage: int = st["stage"]
		if stage >= 3:
			return float(st["t"]) < 3.0
		if float(st["t"]) >= float(st["next"]):
			var pp := _ppos()
			var from := root.global_position - pp
			from.y = 0.0
			var at: Vector3 = pp + from.normalized() * float(dists[stage])
			at.y = Terrain.height(at.x, at.z) + 1.4
			var snd: String = ["res://assets/audio/knock.ogg", "res://assets/audio/knock_v2.ogg", "res://assets/audio/knock_v3.ogg"][int(st["beat"])]
			Game.audio.play_3d(snd, at, 4.0 + stage * 2.0, 8.0)
			st["beat"] = int(st["beat"]) + 1
			st["next"] = float(st["t"]) + 0.55
			if int(st["beat"]) >= 3:
				st["beat"] = 0
				st["stage"] = stage + 1
				st["next"] = float(st["t"]) + _rng.randf_range(6.0, 9.0)
				if stage == 2:
					st["t"] = 0.0
					_say(&"ev.knocks", 5.0)
					Director.add_tension(10.0, "стук по стволу")
		return true}


## Свист в лесу с одной стороны — и ответный с другой. Семёнов: свистнут — не отвечай.
func _ev_whistle_call() -> Dictionary:
	var f := _near_spot(40.0, 60.0)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	Game.audio.play_3d("res://assets/audio/whistle.ogg", f + Vector3(0, 2, 0), 2.0, 12.0)
	var other := _ppos() * 2.0 - f
	other.y = Terrain.height(other.x, other.z) + 2.0
	var st := {"t": 0.0, "done": false}
	return {"node": root, "ttl": 20.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		if not st["done"] and float(st["t"]) > 3.2:
			st["done"] = true
			Game.audio.play_3d("res://assets/audio/whistle_v3.ogg", other, 2.0, 12.0)
			_say(&"ev.whistle", 5.5)
			Director.add_tension(9.0, "пересвист")
		return true}


## Пара глаз у кромки леса. Луч фонаря — и их нет, только хруст бегущих шагов.
func _ev_eyes() -> Dictionary:
	var f := _near_spot(26.0, 42.0, 0.35)
	if f == Vector3.INF:
		return {}
	var root := _root_at(f)
	var glow := Palette.glow(&"eyes", true)
	for sx: float in [-0.07, 0.07]:
		_ball(root, 0.03, Vector3(sx, 1.55, 0), glow)
	_face(root, _ppos())
	var st := {"t": 0.0, "gone": false}
	return {"node": root, "ttl": 50.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		if st["gone"]:
			return float(st["t"]) < 2.0
		_face(root, _ppos())
		var pl := Game.player
		var to := root.global_position + Vector3(0, 1.5, 0) - pl.camera.global_position
		var looking := (-pl.camera.global_basis.z).dot(to.normalized()) > 0.985
		if (looking and pl.flashlight.visible) or to.length() < 14.0:
			st["gone"] = true
			st["t"] = 0.0
			for c in root.get_children():
				(c as Node3D).visible = false
			Game.audio.play_3d("res://assets/sfx/snow_steps_run_v2.ogg", root.global_position, 0.0, 6.0)
			Director.add_tension(8.0, "глаза в лесу")
		return true}


## Волки воют с трёх сторон по очереди — и разом замолкают, на полуноте.
func _ev_wolf_chorus() -> Dictionary:
	var p := _ppos()
	var root := _root_at(p)
	var spots: Array[Vector3] = []
	var a0 := _rng.randf() * TAU
	for k in 3:
		var a := a0 + k * TAU / 3.0
		spots.append(p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(110.0, 160.0) + Vector3(0, 6, 0))
	var st := {"t": 0.0, "i": 0}
	var sounds := ["res://assets/sfx/wolf_far.ogg", "res://assets/sfx/wolf_far_v2.ogg", "res://assets/sfx/wolf_far_v3.ogg"]
	return {"node": root, "ttl": 30.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var i: int = st["i"]
		if i < 3 and float(st["t"]) > i * 3.5:
			Game.audio.play_3d(sounds[i], spots[i], 6.0, 40.0, 6.0 if i == 2 else 0.0)
			st["i"] = i + 1
		if i == 3 and float(st["t"]) > 13.0:
			st["i"] = 4
			_say(&"ev.wolves", 5.0)
			Director.add_tension(6.0, "волки замолчали")
		return true}


# --- События у точек карты ----------------------------------------------------------

## Ночью в избе горит окно. Подойдёшь — гаснет, внутри скрипят половицы.
func _ev_izba_light() -> Dictionary:
	var c := Vector3(-16, 0, -30)
	var root := _root_at(c + Vector3(0, 1.4, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.28)
	l.light_energy = 2.6
	l.omni_range = 7.5
	root.add_child(l)
	var st := {"t": 0.0, "out": false}
	return {"node": root, "ttl": 400.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var dist := _flat_dist(_ppos(), c)
		if not st["out"]:
			l.light_energy = 2.0 + sin(float(st["t"]) * 7.0) * 0.25 + sin(float(st["t"]) * 17.0) * 0.12
			if dist < 22.0:
				st["out"] = true
				l.visible = false
				Game.audio.play_3d("res://assets/sfx/house_creak_v2.ogg", c + Vector3(0, 1, 0), 0.0, 5.0)
				_say(&"ev.izba_light", 5.0)
				Director.add_tension(10.0, "свет в избе")
		return not (st["out"] and dist > 60.0)}


## У проруби из-подо льда стучат: три удара. Потом скребут.
func _ev_lake_knock() -> Dictionary:
	var c := Vector3(-38, 0.0, 34)
	var root := _root_at(c)
	var st := {"t": 0.0, "n": 0}
	var hits := ["res://assets/audio/ice_hit.ogg", "res://assets/audio/ice_hit_v2.ogg", "res://assets/audio/ice_hit_v3.ogg", "res://assets/sfx/scratch_wall.ogg"]
	return {"node": root, "ttl": 20.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var n: int = st["n"]
		if n < 4 and float(st["t"]) > 1.0 + n * (0.9 if n < 3 else 2.5):
			Game.audio.play_3d(hits[n], c, 4.0, 6.0)
			st["n"] = n + 1
			if n == 3:
				_say(&"ev.lake_knock", 5.5)
				Director.add_tension(12.0, "стук подо льдом")
		return true}


## Динамик ретранслятора сквозь шипение поёт колыбельную. Голос — мамин.
func _ev_repeater_song() -> Dictionary:
	var c := Vector3(72, 2.0, -62)
	var root := _root_at(c)
	var song := _loop3d(root, "res://assets/audio/lullaby_loop.ogg", -2.0, 6.0, 0.92)
	var hiss := _loop3d(root, "res://assets/audio/static_loop.ogg", -6.0, 6.0)
	var st := {"said": false, "t": 0.0}
	return {"node": root, "ttl": 70.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var dist := _flat_dist(_ppos(), c)
		if not st["said"] and float(st["t"]) > 2.5:
			st["said"] = true
			_say(&"ev.repeater_song", 6.0)
			Director.add_tension(10.0, "колыбельная из ретранслятора")
		if dist < 6.0 or dist > 55.0:
			song.stop()
			hiss.stop()
			return false
		return true}


## Дверца метеобудки сама хлопает на ветру — а ветра нет.
func _ev_meteo_screen() -> Dictionary:
	var c := Vector3(58, 1.4, -32)
	var root := _root_at(c)
	var st := {"t": 0.0, "n": 0}
	return {"node": root, "ttl": 16.0, "update": func(d: float) -> bool:
		st["t"] = float(st["t"]) + d
		var n: int = st["n"]
		if n < 3 and float(st["t"]) > 0.5 + n * 1.6:
			Game.audio.play_3d("res://assets/audio/clank_v%d.ogg" % (n + 2), c, 2.0, 6.0)
			st["n"] = n + 1
			if n == 2 and Game.weather != null and Game.weather.intensity < 0.4:
				_say(&"ev.meteo_door", 4.5)
		return true}


## Днём вокруг гаража — свежие босые следы. Обходят сарай кругом и упираются в стену.
func _ev_shed_prints() -> Dictionary:
	var c := Vector3(48, 0, 34)
	var root := _root_at(c)
	var route := PackedVector3Array()
	var a0 := _rng.randf() * TAU
	for k in 11:
		var a := a0 + k * TAU * 0.09
		var r := 7.5 - k * 0.25
		var q := c + Vector3(cos(a) * r, 0, sin(a) * r * 0.8)
		q.y = Terrain.height(q.x, q.z)
		route.append(q)
	_trail(root, route)
	var st := {"said": false}
	return {"node": root, "ttl": 1500.0, "update": func(_d: float) -> bool:
		if not st["said"] and _flat_dist(_ppos(), c) < 12.0:
			st["said"] = true
			_say(&"ev.shed_prints", 5.5)
			Director.add_tension(8.0, "следы у гаража")
		return true}
