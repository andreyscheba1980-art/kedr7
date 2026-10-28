class_name Snowmobile
extends Node3D
## Снегоход «Буран» у гаража: расчехлить утром в обучении, дальше — транспорт по карте.
## Аркадная езда по Terrain: высота и наклон — лучами вниз, удар — лучом вперёд.
## Мотор шумит: ночью звук двигателя слышит Ырка (EventBus.noise_emitted).

const PARK := Vector3(40.0, 0.0, 25.0)
const PARK_YAW := PI * 0.5
const MAX_SPEED := 8.5           ## ≈ 30 км/ч по укатанному зимнику
const DEEP_SPEED := 3.6          ## ≈ 13 км/ч в целине
const REVERSE_SPEED := 2.2
const ACCEL := 2.6               ## тяжёлый, разгоняется неохотно
const BRAKE := 7.0
const DRAG := 2.4
const TURN := 1.15
const FUEL_IDLE := 0.12          ## % в секунду на холостых
const FUEL_RUN := 0.05           ## % за метр: полного бака — на два километра зимника
const STALL_CHANCE := 0.07       ## ночью, раз в 20 с под нагрузкой
const ENGINE := "res://assets/audio/engine_loop.ogg"
const CLANK := "res://assets/audio/clank.ogg"

static var instance: Snowmobile

var riding := false
var engine_on := false
var speed := 0.0
var fuel := 60.0
var driven := 0.0                ## метров за поездку (для шага обучения)
var steer_amount := 0.0          ## сглаженный руль −1…1 (для рук игрока)

var _yaw := PARK_YAW
var _body: Node3D
var _tarp: Node3D
var _model: Node3D
var _light: SpotLight3D
var _lamp_mat: StandardMaterial3D
var _engine: AudioStreamPlayer3D
var _rev: AudioStreamPlayer3D
var _solid: StaticBody3D
var _start_t := 0.0
var _noise_t := 0.0
var _mount_guard := 0.0
var _player_yaw_prev := 0.0
var _deep := 0.0                 ## 0 — зимник/двор, 1 — целина (сглаженно)
var _deep_told := false
var _stuck_t := 0.0
var _stall_t := 20.0


func _ready() -> void:
	instance = self
	name = "Buran"
	Game.set_flag("riding", false)
	fuel = float(SaveGame.flags.get("buran_fuel", 60.0))
	var saved: Variant = SaveGame.flags.get("buran_pos", null)
	var p := PARK
	if saved is Array and (saved as Array).size() == 3:
		p = Vector3(float(saved[0]), 0.0, float(saved[1]))
		_yaw = float(saved[2])
	_build()
	_place(p)
	_set_body_meshes(Game.has_flag("buran_uncovered"))


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if riding:
		Game.set_flag("riding", false)


func is_covered() -> bool:
	return _tarp.visible


# --- Модель -------------------------------------------------------------------

func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	_model = Node3D.new()
	_body.add_child(_model)
	var glb := Models.spawn(_model, "kedr/buran", Vector3.ZERO, 0.0, -1.0, {"grime": 0.0, "bright": 1.15, "sat": 0.95})
	if glb == null:
		_build_blocks(_model)
	# Фара
	_lamp_mat = _mat(Color(0.9, 0.88, 0.75), 0.2)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.9, 0.7)
	_lamp_mat.emission_energy_multiplier = 0.0
	Geo.cylinder(_model, 0.08, 0.02, Vector3(0, 0.78, -0.76), _lamp_mat, false).rotation.x = deg_to_rad(90.0 - 30.0)
	_light = SpotLight3D.new()
	_light.position = Vector3(0, 0.8, -0.85)
	_light.light_color = Color(1.0, 0.92, 0.78)
	_light.light_energy = 3.5
	_light.spot_range = 34.0
	_light.spot_angle = 30.0
	_light.shadow_enabled = false
	_light.visible = false
	_body.add_child(_light)
	apply_upgrades()
	# Чехол — тот же брезент, что в гараже
	_tarp = Node3D.new()
	_body.add_child(_tarp)
	if Models.spawn(_tarp, "kedr/buran_tarp", Vector3.ZERO, 0.0, -1.0, {"grime": 0.0, "bright": 1.1, "sat": 0.9}) == null:
		var old := Props.snowmobile_tarp()
		old.rotation.y = PI
		_tarp.add_child(old)
	# Твёрдое тело, чтобы не проходить сквозь
	_solid = StaticBody3D.new()
	_solid.collision_layer = Geo.LAYER_WORLD
	_solid.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.95, 0.9, 3.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.45, 0.1)
	_solid.add_child(cs)
	_body.add_child(_solid)
	# Взаимодействие
	var it := Interactable.new()
	it.collision_layer = Geo.LAYER_INTERACT
	it.add_child(Geo.box_shape(Vector3(1.4, 1.3, 3.2)))
	it.position = Vector3(0, 0.6, 0.1)
	it.prompt_provider = _prompt
	it.used.connect(_on_use)
	_body.add_child(it)
	# Мотор
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AudioDirector.cached_stream(Voice.sfx_or(&"buran_idle", ENGINE))
	_engine.unit_size = 10.0
	_engine.max_distance = 320.0
	_engine.volume_db = -60.0
	_engine.bus = &"SFX"
	_body.add_child(_engine)
	_engine.finished.connect(func() -> void:
		if engine_on:
			_engine.play())
	# Второй слой — высокие обороты: подмешивается с газом
	var rev_path := Voice.sfx(&"buran_rev")
	if rev_path != "":
		_rev = AudioStreamPlayer3D.new()
		_rev.stream = AudioDirector.cached_stream(rev_path)
		_rev.unit_size = 12.0
		_rev.max_distance = 420.0
		_rev.volume_db = -60.0
		_rev.bus = &"SFX"
		_body.add_child(_rev)
		_rev.finished.connect(func() -> void:
			if engine_on:
				_rev.play())


func _prompt() -> String:
	if riding:
		return ""
	if is_covered():
		return Loc.t(&"it.buran_tarp") if Game.has_flag("prologue_arrived") else Loc.t(&"it.snowmobile")
	if Game.player != null and Game.player.held == &"canister":
		return Loc.t(&"it.buran_refuel")
	return Loc.t(&"it.buran_ride", [roundi(fuel)])


func _on_use(p: Player) -> void:
	if riding:
		return
	if is_covered():
		if not Game.has_flag("prologue_arrived"):
			Game.hud.subtitle(Loc.t(&"sub.buran_night"), 3.5)
			return
		Game.set_flag("buran_uncovered")
		_set_body_meshes(true)
		Game.audio.play_3d(CLANK, global_position, -6.0)
		Game.hud.subtitle(Loc.t(&"sub.buran_uncovered"), 4.0)
		return
	if p.held == &"canister":
		p.set_held(&"")
		fuel = 100.0
		Game.set_flag("buran_fuel", fuel)
		Game.audio.play_3d(CLANK, global_position, 0.0)
		Game.hud.subtitle(Loc.t(&"sub.buran_filled"), 3.0)
		return
	if p.held != &"" and p.held != &"dog":
		Game.hud.subtitle(Loc.t(&"sub.buran_hands"), 3.0)
		return
	_mount(p)


# --- Посадка ------------------------------------------------------------------

func _mount(p: Player) -> void:
	riding = true
	driven = 0.0
	_mount_guard = 0.4
	Game.set_flag("riding", true)
	p.velocity = Vector3.ZERO
	p.rotation.y = _yaw
	p.head.rotation.x = deg_to_rad(-6.0)
	_player_yaw_prev = _yaw
	_seat_player(p)
	Game.hud.subtitle(Loc.t(&"sub.buran_controls2"), 6.0)
	_try_start()


func request_dismount() -> void:
	if not riding or _mount_guard > 0.0:
		return
	if absf(speed) > 2.5:
		Game.hud.subtitle(Loc.t(&"sub.buran_too_fast"), 2.0)
		return
	_dismount()


func _dismount() -> void:
	riding = false
	speed = 0.0
	Game.set_flag("riding", false)
	_set_engine(false)
	Game.set_flag("buran_pos", [global_position.x, global_position.z, _yaw])
	Game.set_flag("buran_fuel", fuel)
	var p := Game.player
	if p != null and not Game.dead:
		var side := _body.global_basis.x
		var spot := global_position + side * 1.3
		spot.y = _ground(spot, global_position.y + 2.0) + 0.05
		p.global_position = spot
		p.velocity = Vector3.ZERO
	if Game.is_prologue() and driven > 100.0:
		Game.complete_step(&"buran")


func _seat_player(p: Player) -> void:
	p.global_position = _body.to_global(Vector3(0, 0.15, 0.72))


func _try_start() -> void:
	if engine_on:
		return
	if fuel <= 0.0:
		Game.hud.subtitle(Loc.t(&"sub.buran_empty"), 3.0)
		return
	_start_t = 1.1
	var chance := 0.9 if Game.is_daylight() else 0.6
	if SaveGame.flags.get("buran_started_once", false) == false or SaveGame.flags.get("buran_plug", false):
		chance = 1.0
	if randf() < chance:
		Game.set_flag("buran_started_once", true)
		Game.audio.play_3d(Voice.sfx_or(&"buran_start", CLANK), global_position, -2.0)
		_set_engine(true)
	else:
		Game.audio.play_3d(Voice.sfx_or(&"buran_fail", CLANK), global_position, -2.0)
		Game.hud.subtitle(Loc.t(&"sub.buran_nostart"), 2.5)


func _set_engine(on: bool) -> void:
	engine_on = on
	_light.visible = on
	_lamp_mat.emission_energy_multiplier = 2.5 if on else 0.0
	if on and not _engine.playing:
		_engine.play()
		if _rev != null:
			_rev.play()
	elif not on:
		_engine.stop()
		if _rev != null:
			_rev.stop()


# --- Езда ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_mount_guard = maxf(_mount_guard - delta, 0.0)
	_start_t = maxf(_start_t - delta, 0.0)
	if not riding:
		if absf(speed) > 0.05:
			speed = move_toward(speed, 0.0, BRAKE * delta)
			_move(delta)
		return
	var p := Game.player
	if p == null or Game.dead:
		_dismount()
		return
	var throttle := 0.0
	var steer := 0.0
	if p.mode == Player.Mode.WALK:
		throttle = Input.get_axis(&"move_back", &"move_forward")
		steer = Input.get_axis(&"move_right", &"move_left")
	if not engine_on:
		if throttle > 0.3 and _start_t <= 0.0:
			_try_start()
		throttle = 0.0
	# Целина: всё, что не зимник, не площадка и не двор, — глубокий снег.
	var pos := global_position
	var packed := Terrain.is_clear(pos.x, pos.z) or Vector2(pos.x, pos.z).distance_to(Vector2(Yard.HOUSE_CENTER.x, Yard.HOUSE_CENTER.z)) < 55.0
	_deep = move_toward(_deep, 0.0 if packed else 1.0, delta * 1.5)
	if _deep > 0.6 and not _deep_told and absf(speed) > 1.5:
		_deep_told = true
		Game.hud.subtitle(Loc.t(&"sub.buran_deep"), 3.0)
	# В гору «Буран» тянет хуже, в целине — ещё и проваливается.
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var slope := -Terrain.normal(pos.x, pos.z).dot(fwd)   # > 0 — в гору
	var cap := lerpf(MAX_SPEED, DEEP_SPEED, _deep) * clampf(1.0 - maxf(slope, 0.0) * (1.6 + _deep * 2.0), 0.25, 1.0)
	var acc := ACCEL * lerpf(1.0, 0.55, _deep)
	if throttle > 0.0:
		speed = move_toward(speed, cap * throttle, acc * delta)
		if speed > cap:
			speed = move_toward(speed, cap, BRAKE * 0.5 * delta)
		# Зарылся: газ в целине в гору, а скорости нет
		if _deep > 0.8 and slope > 0.12 and speed < 0.8:
			_stuck_t += delta
			if _stuck_t > 1.5:
				speed = 0.0
				if _stuck_t < 1.5 + delta * 1.5:
					Game.hud.subtitle(Loc.t(&"sub.buran_stuck"), 3.5)
		else:
			_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)
	elif throttle < 0.0:
		speed = move_toward(speed, -REVERSE_SPEED, (BRAKE if speed > 0.0 else ACCEL * 0.6) * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	steer_amount = move_toward(steer_amount, steer, get_physics_process_delta_time() * 4.0)
	var grip := clampf(absf(speed) / 4.0, 0.0, 1.0) * (1.0 - clampf((absf(speed) - 10.0) / 12.0, 0.0, 0.35))
	var dyaw := steer * TURN * grip * signf(speed if absf(speed) > 0.01 else 1.0) * delta
	_yaw += dyaw
	p.rotation.y += dyaw
	_move(delta)
	_seat_player(p)
	# Топливо, звук, шум для Ырки
	if engine_on:
		fuel = maxf(fuel - (FUEL_IDLE * delta + absf(speed) * delta * FUEL_RUN * lerpf(1.0, 1.7, _deep)), 0.0)
		var load := clampf(absf(speed) / MAX_SPEED, 0.0, 1.0)
		_engine.pitch_scale = 0.75 + load * 0.75
		_engine.volume_db = lerpf(-6.0, -9.0, load) if _rev != null else lerpf(-9.0, -2.0, load)
		if _rev != null:
			_rev.volume_db = lerpf(-40.0, -1.0, clampf(load * 1.3, 0.0, 1.0))
			_rev.pitch_scale = 0.85 + load * 0.3
		_noise_t -= delta
		if _noise_t <= 0.0:
			_noise_t = 0.6
			if not Game.is_daylight():
				EventBus.noise_emitted.emit(global_position, 0.75 + load * 0.6, &"engine")
		# Ночью на морозе мотор может заглохнуть под нагрузкой (новая свеча — не глохнет)
		_stall_t -= delta
		if _stall_t <= 0.0:
			_stall_t = 20.0
			if not Game.is_daylight() and load > 0.3 and not SaveGame.flags.get("buran_plug", false) and randf() < STALL_CHANCE:
				_set_engine(false)
				Game.audio.play_3d(Voice.sfx_or(&"buran_fail", CLANK), global_position, -2.0)
				Game.hud.subtitle(Loc.t(&"sub.buran_stall"), 3.5)
		if fuel <= 0.0:
			_set_engine(false)
			Game.hud.subtitle(Loc.t(&"sub.buran_empty"), 3.0)
		if absf(speed) > 6.0:
			p.shake(0.012 * load, 0.15)


func _move(delta: float) -> void:
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var step := fwd * speed * delta
	if step.length() > 0.0001:
		var space := get_world_3d().direct_space_state
		var from := global_position + Vector3(0, 0.55, 0)
		var reach := (1.8 if speed > 0.0 else 1.7) + step.length()
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * signf(speed) * reach, Geo.LAYER_WORLD)
		var ex: Array[RID] = [_solid.get_rid()]
		if Game.player != null:
			ex.append(Game.player.get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and not hit["collider"] is Interactable:
			if absf(speed) > 5.0:
				Game.audio.play_3d(CLANK, global_position, 2.0)
				if Game.player != null and riding:
					Game.player.shake(0.06, 0.35)
			speed = -speed * 0.15
			return
		driven += step.length()
	_place(global_position + step)


func _place(p: Vector3) -> void:
	var y := _ground(p, maxf(p.y, Terrain.height(p.x, p.z)) + 3.0)
	global_position = Vector3(p.x, y, p.z)
	var n := Terrain.normal(p.x, p.z) if not Vector2(p.x, p.z).distance_to(Terrain.CENTER) < Terrain.FLAT_R - 5.0 else Vector3.UP
	var b := Basis(Vector3.UP, _yaw)
	var up := n.normalized()
	var z := b.z - up * b.z.dot(up)
	if z.length() < 0.01:
		z = b.z
	z = z.normalized()
	var x := up.cross(z).normalized()
	_body.global_basis = _body.global_basis.slerp(Basis(x, up, z).orthonormalized(), 0.35) if is_inside_tree() and riding else Basis(x, up, z).orthonormalized()


func _ground(p: Vector3, from_y: float) -> float:
	if not is_inside_tree():
		return Terrain.height(p.x, p.z)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, from_y, p.z), Vector3(p.x, from_y - 12.0, p.z), Geo.LAYER_WORLD)
	q.exclude = [_solid.get_rid()]
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else Terrain.height(p.x, p.z)


func _set_body_meshes(on: bool) -> void:
	_model.visible = on
	_tarp.visible = not on


## Запасная модель из коробок (если glb не импортирован).
func _build_blocks(root: Node3D) -> void:
	var orange := _mat(Color(0.78, 0.33, 0.1), 0.5)
	var cream := _mat(Color(0.8, 0.78, 0.7))
	var steel := _mat(Color(0.16, 0.17, 0.19), 0.4)
	var rubber := _mat(Color(0.07, 0.07, 0.07), 0.9)
	var seat := _mat(Color(0.1, 0.1, 0.11), 0.8)
	# Гусеница и туннель
	Geo.block(root, Vector3(0.5, 0.36, 2.3), Vector3(0, 0.22, 0.45), rubber, false)
	Geo.block(root, Vector3(0.82, 0.12, 2.1), Vector3(0, 0.46, 0.5), steel, false)
	for sx: float in [-0.44, 0.44]:
		Geo.block(root, Vector3(0.14, 0.05, 1.3), Vector3(sx, 0.4, 0.55), steel, false)     # подножки
	# Сиденье
	Geo.block(root, Vector3(0.5, 0.16, 1.1), Vector3(0, 0.6, 0.6), seat, false)
	Geo.block(root, Vector3(0.6, 0.22, 0.4), Vector3(0, 0.62, 1.38), cream, false)       # багажник
	# Капот: кремовая боковина + оранжевый верх, скошенный нос
	Geo.block(root, Vector3(0.9, 0.34, 1.0), Vector3(0, 0.52, -0.6), cream, false)
	var hood := Geo.block(root, Vector3(0.88, 0.2, 1.0), Vector3(0, 0.78, -0.62), orange, false)
	hood.rotation.x = deg_to_rad(-9.0)
	var nose := Geo.block(root, Vector3(0.86, 0.3, 0.5), Vector3(0, 0.46, -1.2), orange, false)
	nose.rotation.x = deg_to_rad(32.0)
	# Стекло, руль
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.78, 0.86, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ws := Geo.block(root, Vector3(0.7, 0.32, 0.02), Vector3(0, 1.02, -0.2), glass, false)
	ws.rotation.x = deg_to_rad(-28.0)
	Geo.block(root, Vector3(0.78, 0.04, 0.04), Vector3(0, 0.98, -0.05), steel, false)
	# Лыжа спереди (у «Бурана» — одна поворотная) и стойка
	Geo.block(root, Vector3(0.18, 0.04, 1.2), Vector3(0, 0.06, -1.25), steel, false)
	var tip := Geo.block(root, Vector3(0.18, 0.04, 0.3), Vector3(0, 0.16, -1.9), steel, false)
	tip.rotation.x = deg_to_rad(35.0)
	Geo.block(root, Vector3(0.08, 0.36, 0.08), Vector3(0, 0.26, -1.15), steel, false)


func body_node() -> Node3D:
	return _body


## Фара-искатель из снабжения: свет вдвое дальше и шире (ставится сразу при открытии ящика).
func apply_upgrades() -> void:
	if _light == null:
		return
	var up := Game.has_flag("upg_headlight")
	_light.light_energy = 5.5 if up else 3.5
	_light.spot_range = 62.0 if up else 34.0
	_light.spot_angle = 36.0 if up else 30.0
