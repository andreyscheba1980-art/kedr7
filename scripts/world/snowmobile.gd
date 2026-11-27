class_name Snowmobile
extends Node3D
## Снегоход «Буран» у гаража: расчехлить утром в обучении, дальше — транспорт по карте.
## Аркадная езда по Terrain: высота и наклон — лучами вниз, удар — лучом вперёд.
## Мотор шумит: ночью звук двигателя слышит Ырка (EventBus.noise_emitted).

const PARK := Vector3(40.0, 0.0, 25.0)
const PARK_YAW := PI * 0.5
const MAX_SPEED := 8.8           ## ≈ 32 км/ч по укатанному зимнику
const DEEP_SPEED := 4.4          ## ≈ 16 км/ч в целине (тяговитый буксир)
const REVERSE_SPEED := 3.2
const ACCEL := 3.0
const BRAKE := 7.5
const DRAG := 2.4
const TURN := 1.45
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
var mittens_off := false
var frostbite_timer := 0.0
var wrench_dropped := false

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
var _ark_gauge: Node3D
var _ark_needle: Node3D
var _ark_eye_mat: StandardMaterial3D
var _ark_angle := 0.0
var _rpm_factor := 0.0               ## 0.0 (заглушен), 0.08 (холостые), 1.0 (полный газ)
var _primer_pumps := 0              ## подкачка топлива карбюратора
var _plugs_flooded := false         ## свечи залиты
var _starter_pull_t := 0.0
var _sled: Node3D                   ## нарты-волокуши сзади снегохода
var _sled_anomaly_t := 140.0        ## таймер редкого рывка нарт
var _sled_shadow: MeshInstance3D    ## призрачная тень на санях
var _trail_mmi: MultiMeshInstance3D
var _trail_mm: MultiMesh
var _trail_idx := 0
var _last_trail_pos := Vector3.INF
const MAX_TRAIL_SEGMENTS := 350
static var _trail_mat: StandardMaterial3D


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
	_reset_audio_buses()
	if _trail_mmi != null and is_instance_valid(_trail_mmi):
		_trail_mmi.queue_free()
		_trail_mmi = null


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
	_build_ark_gauge(_body)
	_build_sled()
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
	if mittens_off:
		return Loc.p("[E] Обслужить свечи А17ДВ и магнето МД-4Б | [G] Надеть рукавицы", "[E] Service A17DV plugs & MD-4B magneto | [G] Put mittens on")
	return Loc.p("[G] Снять рукавицы для тонкого ремонта · ", "[G] Remove mittens for repair · ") + Loc.t(&"it.buran_ride", [roundi(fuel)])


func toggle_mittens() -> void:
	mittens_off = not mittens_off
	if mittens_off:
		Game.audio.play_3d("res://assets/audio/clank.ogg", global_position, -8.0)
		Game.hud.subtitle(Loc.p("Снял меховые рукавицы [G]: руки обнажены на -41°C. До обморожения 45 секунд!", "Removed fur mittens [G]: bare hands at -41°C. 45 seconds to severe frostbite!"), 4.0)
	else:
		Game.audio.play_3d("res://assets/audio/clank.ogg", global_position, -8.0)
		Game.hud.subtitle(Loc.p("Надел меховые рукавицы [G]: пальцы отогреваются.", "Put fur mittens back on [G]: fingers warming up."), 3.0)


func service_engine() -> void:
	if not mittens_off:
		Game.hud.subtitle(Loc.p("В толстых рукавицах невозможно выставить зазор контактов магнето МД-4Б! Снимите их [G].", "Impossible to adjust MD-4B magneto contact gap in heavy mittens! Take them off [G]."), 3.5)
		return
	if wrench_dropped:
		wrench_dropped = false
		Game.audio.play_3d(CLANK, global_position, -2.0)
		Game.hud.subtitle(Loc.p("Поднял ключ 21 мм из сугроба.", "Retrieved 21mm wrench from snow."), 2.5)
		return
	Game.audio.play_3d(CLANK, global_position, 0.0)
	SaveGame.flags["buran_plug"] = true
	SaveGame.flags["buran_tuned"] = true
	_plugs_flooded = false
	Game.hud.subtitle(Loc.p("Вывернул свечи А17ДВ ключом на 21, прокалил, выставил зазор магнето 0.4 мм и продул жиклёр карбюратора!", "Extracted A17DV spark plugs with 21mm wrench, cleaned gap to 0.4mm and purged carburetor jet!"), 5.0)


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
	if mittens_off:
		service_engine()
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
	if not engine_on:
		Game.hud.subtitle(Loc.t(&"sub.buran_controls2") + "\n[F] — праймер | [Пробел/W] — трос стартера", 7.0)
	else:
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
	_reset_audio_buses()
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


func pump_primer() -> void:
	_primer_pumps += 1
	Game.audio.play_3d(Voice.sfx_or(&"primer_squish", CLANK), global_position, -2.0)
	if _primer_pumps <= 3:
		Game.hud.subtitle(Loc.t(&"sub.buran_primed", [_primer_pumps]), 2.0)
	elif _primer_pumps >= 5:
		_plugs_flooded = true
		Game.hud.subtitle(Loc.t(&"sub.buran_flooded"), 3.5)


func pull_starter() -> void:
	if engine_on or _starter_pull_t > 0.0:
		return
	if fuel <= 0.0:
		Game.hud.subtitle(Loc.t(&"sub.buran_empty"), 3.0)
		return
	if Troubles.blocks(&"buran_cold"):
		Game.audio.play_3d(Voice.sfx_or(&"buran_fail", CLANK), global_position, -2.0)
		Game.hud.subtitle(Loc.t(&"tr.block.buran_cold"), 3.5)
		return
	_starter_pull_t = 0.8
	Game.audio.play_3d(Voice.sfx_or(&"buran_start", CLANK), global_position, -1.0)
	if Game.is_night() and randf() < 0.35:
		Game.audio.play_3d(Voice.sfx_or(&"footstep_snow", CLANK), _body.to_global(Vector3(0, 0.2, 2.8)), -4.0)

	if _plugs_flooded:
		var clearing := Input.is_action_pressed(&"move_forward")
		if clearing:
			_primer_pumps = max(_primer_pumps - 2, 0)
			if _primer_pumps <= 2:
				_plugs_flooded = false
				Game.hud.subtitle(Loc.t(&"sub.buran_started"), 3.0)
				_set_engine(true)
			else:
				Game.hud.subtitle(Loc.t(&"sub.buran_flooded_hint"), 2.5)
		else:
			Game.audio.play_3d(Voice.sfx_or(&"buran_fail", CLANK), global_position, -2.0)
			Game.hud.subtitle(Loc.t(&"sub.buran_flooded_hint"), 3.0)
		return

	var chance := 0.9 if Game.is_daylight() else 0.65
	if SaveGame.flags.get("buran_plug", false) or Gear.has(&"spark_plug") or _primer_pumps >= 1:
		chance = 1.0
	if randf() <= chance:
		Game.set_flag("buran_started_once", true)
		_primer_pumps = 0
		_set_engine(true)
		Game.hud.subtitle(Loc.t(&"sub.buran_started"), 2.5)
	else:
		Game.audio.play_3d(Voice.sfx_or(&"buran_fail", CLANK), global_position, -2.0)
		Game.hud.subtitle(Loc.t(&"sub.buran_nostart"), 2.5)


func _try_start() -> void:
	pull_starter()


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
	_starter_pull_t = maxf(_starter_pull_t - delta, 0.0)
	if not riding:
		if absf(speed) > 0.05:
			speed = move_toward(speed, 0.0, BRAKE * delta)
			_move(delta)
		# Механика обморожения при ремонте без рукавиц [G]
		if mittens_off:
			frostbite_timer += delta
			var p_ref := Game.player
			if frostbite_timer > 20.0 and frostbite_timer < 35.0:
				if randf() < delta * 0.4 and p_ref != null:
					p_ref.shake(0.04, 0.3)
					Game.hud.subtitle(Loc.p("Пальцы деревенеют от холода (-41°C)... Надень рукавицы [G]!", "Fingers going numb from the bitter cold (-41°C)... Put mittens on [G]!"), 2.5)
			elif frostbite_timer >= 45.0 and not wrench_dropped:
				wrench_dropped = true
				Game.audio.play_3d(CLANK, global_position, 2.0)
				if p_ref != null:
					p_ref.shake(0.08, 0.5)
				Game.hud.subtitle(Loc.p("Онемевшие пальцы свело судорогой — рожковый ключ 21 мм выскользнул в сугроб!", "Numb fingers cramped — 21mm open-end wrench slipped into the snowbank!"), 4.5)
		else:
			frostbite_timer = maxf(frostbite_timer - delta * 1.5, 0.0)
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
	var packed := Terrain.is_clear(pos.x, pos.z) or Terrain.road_dist(pos.x, pos.z) < 7.0 or Vector2(pos.x, pos.z).distance_to(Vector2(Yard.HOUSE_CENTER.x, Yard.HOUSE_CENTER.z)) < 58.0
	_deep = move_toward(_deep, 0.0 if packed else 1.0, delta * 1.5)
	if _deep > 0.6 and not _deep_told and absf(speed) > 1.5:
		_deep_told = true
		Game.hud.subtitle(Loc.t(&"sub.buran_deep"), 3.0)
	# В гору «Буран» тянет хуже, в целине — чуть тяжелее, но не мёртвый клин.
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var slope := -Terrain.normal(pos.x, pos.z).dot(fwd)   # > 0 — в гору
	var deep_cap: float = DEEP_SPEED * (1.35 if (Game.has_item(&"belt_variator") or Game.has_flag("buran_belt")) else 1.0)
	var cap := maxf(lerpf(MAX_SPEED, deep_cap, _deep) * clampf(1.0 - maxf(slope, 0.0) * (1.25 + _deep * 1.3), 0.35, 1.0), 1.8)
	# Ярус 3 (гольцы и курумники > 72 м): крутизна и каменные россыпи не пускают тяжелый снегоход
	if pos.y > 72.0:
		var kurumnik := clampf((pos.y - 72.0) / 18.0, 0.0, 1.0)
		cap *= (1.0 - kurumnik * 0.85)
		if kurumnik > 0.4 and absf(speed) > 0.4 and randf() < delta * 0.35:
			Game.hud.subtitle(Loc.t(&"sub.buran_kurumnik_slip"), 3.0)
	var acc := ACCEL * lerpf(1.0, 0.65, _deep)
	if throttle > 0.0:
		speed = move_toward(speed, cap * throttle, acc * delta)
		if speed > cap:
			speed = move_toward(speed, cap, BRAKE * 0.5 * delta)
		# Зарылся только на очень крутом целиновом склоне
		if _deep > 0.85 and slope > 0.28 and speed < 0.5:
			_stuck_t += delta
			if _stuck_t > 2.2:
				speed = 0.0
				if _stuck_t < 2.2 + delta * 1.5:
					Game.hud.subtitle(Loc.t(&"sub.buran_stuck"), 3.5)
		else:
			_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)
	elif throttle < 0.0:
		speed = move_toward(speed, -REVERSE_SPEED, (BRAKE if speed > 0.0 else ACCEL * 0.75) * delta)
	else:
		speed = move_toward(speed, 0.0, DRAG * delta)
	steer_amount = move_toward(steer_amount, steer, get_physics_process_delta_time() * 4.5)
	var min_grip := 0.52 if engine_on else 0.0
	var grip := maxf(min_grip, clampf(absf(speed) / 3.0, 0.0, 1.0) * (1.0 - clampf((absf(speed) - 10.0) / 12.0, 0.0, 0.3)))
	var rev_sign := -1.0 if speed < -0.15 else 1.0
	var dyaw := steer * TURN * grip * rev_sign * delta
	_yaw += dyaw
	p.rotation.y += dyaw
	_move(delta)
	_seat_player(p)
	_tick_ark(delta)
	# Дилемма «Свет против Слуха»:
	if engine_on:
		var moving := absf(speed) > 0.4 or throttle != 0.0
		var target_rpm := 1.0 if moving else 0.08
		_rpm_factor = move_toward(_rpm_factor, target_rpm, delta * (3.5 if moving else 1.2))

		# Фара ФГ-122: на холостых едва тлеет оранжевым, на ходу заливает ярким лучом
		_light.visible = true
		_light.light_energy = lerpf(0.38, 3.5, _rpm_factor)
		_light.spot_range = lerpf(7.5, 38.0, _rpm_factor)
		_light.light_color = Color(1.0, 0.62, 0.28).lerp(Color(1.0, 0.94, 0.85), _rpm_factor)
		_lamp_mat.emission = Color(1.0, 0.5, 0.18).lerp(Color(1.0, 0.9, 0.7), _rpm_factor)
		_lamp_mat.emission_energy_multiplier = lerpf(0.5, 2.8, _rpm_factor)

		# Оглушение аудио-шин: ревущий мотор глушит звуки тайги
		var amb_idx := AudioServer.get_bus_index(&"Ambient")
		var wth_idx := AudioServer.get_bus_index(&"Weather")
		var deaf_db: float = lerpf(-3.0, -22.0, _rpm_factor)
		if amb_idx >= 0:
			AudioServer.set_bus_volume_db(amb_idx, deaf_db)
		if wth_idx >= 0:
			AudioServer.set_bus_volume_db(wth_idx, deaf_db)

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
	else:
		_rpm_factor = move_toward(_rpm_factor, 0.0, delta * 3.0)
		_reset_audio_buses()

	# Паранойя нарт: редкий рывок саней ночью в буран
	if riding and engine_on and Game.is_night() and absf(speed) > 4.0:
		_sled_anomaly_t -= delta
		if _sled_anomaly_t <= 0.0:
			_sled_anomaly_t = randf_range(110.0, 220.0)
			speed *= 0.82
			Game.audio.play_3d(CLANK, _sled.global_position if _sled != null else global_position, -2.0)
			if _sled_shadow != null and _sled_shadow.material_override != null:
				var sm := _sled_shadow.material_override as StandardMaterial3D
				sm.albedo_color = Color(0.04, 0.01, 0.01, 0.75)
				var tw := create_tween()
				tw.tween_property(sm, "albedo_color:a", 0.0, 0.65)


func _move(delta: float) -> void:
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var step := fwd * speed * delta
	if step.length() > 0.0001:
		var space := get_world_3d().direct_space_state
		var dir := fwd * signf(speed)
		var reach := (1.65 if speed > 0.0 else 1.55) + step.length()
		var ex: Array[RID] = [_solid.get_rid()]
		if Game.player != null:
			ex.append(Game.player.get_rid())
		var best_hit: Dictionary = {}
		var best_d := INF
		for lat: float in [0.0, -0.40, 0.40]:
			var from := global_position + Vector3(0, 0.62, 0) + right * lat
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Geo.LAYER_WORLD)
			q.exclude = ex
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and not (hit["collider"] is Interactable):
				var hd := from.distance_squared_to(hit["position"] as Vector3)
				if hd < best_d:
					best_d = hd
					best_hit = hit
		if not best_hit.is_empty():
			var hn := best_hit["normal"] as Vector3
			hn.y = 0.0
			if hn.length_squared() > 0.01:
				hn = hn.normalized()
			else:
				hn = -dir
			# Почти лобовой удар — притормозили и чуть оттолкнулись; по касательной — скользим вдоль препятствия!
			if dir.dot(hn) < -0.86:
				if absf(speed) > 5.0:
					Game.audio.play_3d(CLANK, global_position, 2.0)
					if Game.player != null and riding:
						Game.player.shake(0.06, 0.35)
				speed = -speed * 0.12
				_place(global_position + hn * 0.05)
				return
			var slide := step - hn * step.dot(hn)
			slide.y = 0.0
			step = slide * 0.75 + hn * 0.02
			speed *= 0.78
		driven += step.length()
	_place(global_position + step)
	_tick_trail()


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


# --- АРК (Автоматический Радиокомпас) и буранный след ------------------------

func _build_ark_gauge(parent: Node3D) -> void:
	_ark_gauge = Node3D.new()
	_ark_gauge.name = "ARK9Gauge"
	_ark_gauge.position = Vector3(0.0, 0.96, -0.05)
	_ark_gauge.rotation.x = deg_to_rad(-35.0)

	var housing_mat := _mat(Color(0.12, 0.13, 0.14), 0.5)
	var face_mat := _mat(Color(0.08, 0.09, 0.08), 0.7)
	Geo.cylinder(_ark_gauge, 0.085, 0.03, Vector3.ZERO, housing_mat, false)
	Geo.cylinder(_ark_gauge, 0.076, 0.005, Vector3(0, 0.016, 0), face_mat, false)

	var rim_mat := _mat(Color(0.75, 0.72, 0.65), 0.4)
	for i in range(12):
		var ang := float(i) * TAU / 12.0
		var r_outer := 0.068
		var r_inner := 0.056 if (i % 3 == 0) else 0.062
		var p_tick := Vector3(sin(ang) * (r_outer + r_inner) * 0.5, 0.018, cos(ang) * (r_outer + r_inner) * 0.5)
		var tick := Geo.block(_ark_gauge, Vector3(0.004, 0.004, 0.012 if i % 3 == 0 else 0.006), p_tick, rim_mat, false)
		tick.rotation.y = ang

	_ark_eye_mat = StandardMaterial3D.new()
	_ark_eye_mat.albedo_color = Color(0.2, 0.9, 0.35)
	_ark_eye_mat.emission_enabled = true
	_ark_eye_mat.emission = Color(0.15, 0.85, 0.3)
	_ark_eye_mat.emission_energy_multiplier = 1.2
	var eye := Geo.cylinder(_ark_gauge, 0.012, 0.006, Vector3(0.0, 0.019, 0.045), _ark_eye_mat, false)
	eye.name = "MagicEye"

	_ark_needle = Node3D.new()
	_ark_needle.name = "NeedlePivot"
	_ark_needle.position = Vector3(0, 0.021, 0)
	_ark_gauge.add_child(_ark_needle)

	var needle_mat := _mat(Color(0.95, 0.3, 0.1), 0.3)
	needle_mat.emission_enabled = true
	needle_mat.emission = Color(0.9, 0.25, 0.08)
	needle_mat.emission_energy_multiplier = 0.5
	var needle_tail_mat := _mat(Color(0.7, 0.75, 0.8), 0.4)

	# Стрелка: северный нос по -Z, противовес по +Z
	Geo.block(_ark_needle, Vector3(0.006, 0.003, 0.045), Vector3(0, 0, -0.024), needle_mat, false)
	Geo.block(_ark_needle, Vector3(0.005, 0.003, 0.025), Vector3(0, 0, 0.015), needle_tail_mat, false)
	Geo.cylinder(_ark_needle, 0.008, 0.006, Vector3.ZERO, housing_mat, false)

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.7, 0.8, 0.88, 0.25)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.1
	Geo.cylinder(_ark_gauge, 0.08, 0.004, Vector3(0, 0.025, 0), glass_mat, false)

	parent.add_child(_ark_gauge)


func _tick_ark(delta: float) -> void:
	if _ark_needle == null:
		return
	var station_pos := Yard.HOUSE_CENTER
	var to_station := station_pos - global_position
	to_station.y = 0.0
	var dist := to_station.length()
	var station_bearing := atan2(to_station.x, -to_station.z)
	var rel_yaw := wrapf(station_bearing - _yaw, -PI, PI)

	var anomaly_strength := 0.0
	for pos: Vector3 in [Vector3(86.0, 0.0, 16.0), Vector3(30.0, 0.0, -78.0), Vector3(145.0, 0.0, -140.0), Vector3(-140.0, 0.0, -135.0)]:
		var d := global_position.distance_to(pos)
		if d < 35.0:
			anomaly_strength = maxf(anomaly_strength, 1.0 - (d / 35.0))

	if anomaly_strength > 0.05:
		_ark_angle += (randf() - 0.5) * anomaly_strength * 3.5
		if _ark_eye_mat != null:
			_ark_eye_mat.albedo_color = Color(1.0, 0.2, 0.1)
			_ark_eye_mat.emission = Color(0.9, 0.15, 0.05)
	else:
		_ark_angle = lerp_angle(_ark_angle, -rel_yaw, delta * 7.0)
		if _ark_eye_mat != null:
			var sig := clampf(1.0 - (dist / 900.0), 0.25, 1.0)
			_ark_eye_mat.albedo_color = Color(0.2 * sig, 0.9 * sig, 0.4 * sig)
			_ark_eye_mat.emission = Color(0.15 * sig, 0.85 * sig, 0.3 * sig)

	_ark_needle.rotation.y = _ark_angle


func _tick_trail() -> void:
	var cur_pos := global_position
	if _last_trail_pos == Vector3.INF:
		_last_trail_pos = cur_pos
		return
	var d := _last_trail_pos.distance_to(cur_pos)
	if d >= 2.6:
		_spawn_trail_segment(_last_trail_pos, cur_pos)
		_last_trail_pos = cur_pos


static var _trail_combined_mesh: ArrayMesh = null


static func _get_trail_mesh() -> ArrayMesh:
	if _trail_combined_mesh != null:
		return _trail_combined_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := BoxMesh.new()
	cm.size = Vector3(0.48, 0.012, 2.8)
	st.append_from(cm, 0, Transform3D.IDENTITY)
	var sm1 := BoxMesh.new()
	sm1.size = Vector3(0.12, 0.012, 2.8)
	st.append_from(sm1, 0, Transform3D(Basis.IDENTITY, Vector3(-0.42, 0, 0)))
	var sm2 := BoxMesh.new()
	sm2.size = Vector3(0.12, 0.012, 2.8)
	st.append_from(sm2, 0, Transform3D(Basis.IDENTITY, Vector3(0.42, 0, 0)))
	st.generate_normals()
	_trail_combined_mesh = st.commit()
	return _trail_combined_mesh


func _init_trail_multimesh() -> void:
	if _trail_mmi != null and is_instance_valid(_trail_mmi):
		return
	_trail_mmi = MultiMeshInstance3D.new()
	_trail_mmi.name = "BuranTrackTrail"
	_trail_mmi.top_level = true
	_trail_mm = MultiMesh.new()
	_trail_mm.transform_format = MultiMesh.TRANSFORM_3D
	_trail_mm.mesh = _get_trail_mesh()
	_trail_mm.instance_count = MAX_TRAIL_SEGMENTS
	for i in MAX_TRAIL_SEGMENTS:
		_trail_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -999.0, 0)))
	_trail_mmi.multimesh = _trail_mm
	if _trail_mat == null:
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.albedo_color = Color(0.32, 0.38, 0.46)
		_trail_mat.roughness = 0.95
	_trail_mmi.material_override = _trail_mat
	_trail_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent_node := get_parent()
	if parent_node != null:
		parent_node.add_child(_trail_mmi)


func _spawn_trail_segment(p0: Vector3, p1: Vector3) -> void:
	if _trail_mmi == null or not is_instance_valid(_trail_mmi):
		_init_trail_multimesh()
	if _trail_mm == null:
		return
	var dir := p1 - p0
	dir.y = 0.0
	var seg_len := dir.length()
	if seg_len < 0.2:
		return
	var mid := (p0 + p1) * 0.5
	mid.y = Terrain.height(mid.x, mid.z) + 0.02
	var yaw := atan2(dir.x, dir.z)
	var scale_z := (seg_len + 0.12) / 2.8
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.0, 1.0, scale_z)), mid)
	_trail_mm.set_instance_transform(_trail_idx, t)
	_trail_idx = (_trail_idx + 1) % MAX_TRAIL_SEGMENTS


func _unhandled_input(event: InputEvent) -> void:
	if not riding:
		if event.is_action_pressed(&"drop") and Game.player != null and global_position.distance_to(Game.player.global_position) < 3.2:
			toggle_mittens()
		return
	if not engine_on:
		if event.is_action_pressed(&"flashlight"):
			pump_primer()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"jump"):
			pull_starter()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.y > 28.0:
			pull_starter()
			get_viewport().set_input_as_handled()


func _reset_audio_buses() -> void:
	var amb_idx := AudioServer.get_bus_index(&"Ambient")
	var wth_idx := AudioServer.get_bus_index(&"Weather")
	if amb_idx >= 0:
		AudioServer.set_bus_volume_db(amb_idx, 0.0)
	if wth_idx >= 0:
		AudioServer.set_bus_volume_db(wth_idx, 0.0)


func _build_sled() -> void:
	_sled = Node3D.new()
	_sled.name = "CargoSled"
	_sled.position = Vector3(0.0, 0.05, 2.3)
	_body.add_child(_sled)
	var wood_mat := Palette.m(&"wood")
	var dark_mat := Palette.m(&"dark")
	var s_l := Geo.block(_sled, Vector3(0.08, 0.08, 1.6), Vector3(-0.42, 0.04, 0.0), wood_mat, false)
	var s_r := Geo.block(_sled, Vector3(0.08, 0.08, 1.6), Vector3(0.42, 0.04, 0.0), wood_mat, false)
	var n_l := Geo.cylinder(_sled, 0.04, 0.3, Vector3(-0.42, 0.12, -0.85), dark_mat, false)
	n_l.rotation.x = deg_to_rad(-45.0)
	var n_r := Geo.cylinder(_sled, 0.04, 0.3, Vector3(0.42, 0.12, -0.85), dark_mat, false)
	n_r.rotation.x = deg_to_rad(-45.0)
	for i in range(5):
		var z_off: float = -0.6 + float(i) * 0.3
		Geo.block(_sled, Vector3(0.88, 0.03, 0.12), Vector3(0.0, 0.1, z_off), wood_mat, false)
	Geo.block(_sled, Vector3(0.04, 0.18, 1.4), Vector3(-0.42, 0.18, 0.0), dark_mat, false)
	Geo.block(_sled, Vector3(0.04, 0.18, 1.4), Vector3(0.42, 0.18, 0.0), dark_mat, false)
	var hitch := Geo.cylinder(_sled, 0.02, 0.75, Vector3(0.0, 0.18, -1.25), dark_mat, false)
	hitch.rotation.x = deg_to_rad(90.0)
	_sled_shadow = MeshInstance3D.new()
	var cap_m := CapsuleMesh.new()
	cap_m.radius = 0.22
	cap_m.height = 0.7
	_sled_shadow.mesh = cap_m
	_sled_shadow.position = Vector3(0.0, 0.45, 0.1)
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.albedo_color = Color(0.05, 0.02, 0.02, 0.0)
	_sled_shadow.material_override = s_mat
	_sled.add_child(_sled_shadow)
