class_name Player
extends CharacterBody3D
## Игрок от первого лица: ходьба/бег, обзор, фонарь-жучок, вещь в руках, удержание E,
## шаги и дыхание. Ввод приходит из main.gd через handle_input().

enum Mode { WALK, RADIO, READING, UI, LOCKED }

const WALK_SPEED := 2.3
const SPRINT_SPEED := 4.0
const CANISTER_SPEED := 1.75
const ACCEL := 12.0
const MOUSE_SENS := 0.0022
const INTERACT_DIST := 2.3
const LAYER_WORLD := 1
const LAYER_GLASS := 2
const LAYER_PLAYER := 4

const STAMINA_DRAIN := 20.0
const STAMINA_REGEN := 12.0
const FLASH_DRAIN := 100.0 / 170.0     ## полный заряд ≈ 3 минуты
const CRANK_RATE := 16.0
const STEP_LEN := 1.35
const STEPS_SNOW: Array[String] = ["res://assets/audio/step_snow_1.ogg", "res://assets/audio/step_snow_2.ogg", "res://assets/audio/step_snow_3.ogg",
	"res://assets/audio/step_snow_4.ogg", "res://assets/audio/step_snow_5.ogg", "res://assets/audio/step_snow_6.ogg", "res://assets/audio/step_snow_7.ogg", "res://assets/audio/step_snow_8.ogg"]
const STEPS_WOOD: Array[String] = ["res://assets/audio/step_wood_1.ogg", "res://assets/audio/step_wood_2.ogg", "res://assets/audio/step_wood_3.ogg",
	"res://assets/audio/step_wood_4.ogg", "res://assets/audio/step_wood_5.ogg", "res://assets/audio/step_wood_6.ogg", "res://assets/audio/step_wood_7.ogg"]
const GORE_HIT := "res://assets/audio/gore_hit.ogg"
const FLARE_SOUND := "res://assets/audio/flare.ogg"
const CRANK_LOOP := "res://assets/audio/crank_loop.ogg"
## Своё дыхание на морозе — мягкий шум без голоса (сгенерирован). Старое «хриплое» дыхание с вариантами
## от нейросети на повторе слышалось как шёпот «спи… спи…».
const BREATH_LOOP := "res://assets/sfx/cc0/player_breath_loop.ogg"

var mode := Mode.LOCKED
var head: Node3D
var camera: Camera3D
var zoom_fov := 0.0               ## видоискатель «Зенита»: > 0 — куда тянуть угол обзора
var flashlight: SpotLight3D
var closeup_dim := false               ## крупный план прибора: свой фонарь гаснет, светит подсветка крупного плана
var held: StringName = &""
var stamina := 100.0
var cranking := false

var _ray: RayCast3D
var _snow: CPUParticles3D
var _snow_near: CPUParticles3D
var _flash_dust: CPUParticles3D
var _beam_mesh: MeshInstance3D
var _beam_mat: ShaderMaterial
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _bob_t := 0.0
var _shake_left := 0.0
var _shake_power := 0.0
var _gust_timer := 12.0
var _gust_flinch_t := 0.0
var _gust_dip := 0.0
var _gust_jerk := 0.0
var _gust_roll := 0.0
var _focused: Interactable
var _hold_target: Interactable
var _hold_t := 0.0
var _hold_sound_t := 0.0
var _step_acc := 0.0
var _held_root: Node3D
var _hands: FPHands
var torch_lost := false        ## фонарь выронил (падение в шахту): не включить, пока не поднимешь
var _held_models: Dictionary = {}
var _held_base_pos := Vector3(0.26, -0.32, -0.50)
var _held_base_rot := Vector3.ZERO
var _crank_player: AudioStreamPlayer
var _breath_player: AudioStreamPlayer
var _sprinting := false
# Свои следы в снегу: цепочка валенок за спиной, последние FOOT_MAX отпечатков (старые исчезают)
const FOOT_STRIDE := 0.62
const FOOT_MAX := 160
var _foot_acc := 0.0
var _foot_left := false
var _foot_last := Vector3.INF
var _foot_root: Node3D
var _foot_pool: Array[Node3D] = []
var _sprint_latch := false
var _rope_tension_event_done := false
var _breath_latch := false
var _breath_emitter: CPUParticles3D
var _breath_timer := 2.0
var _still_time := 0.0
var _phantom_breath_done := false
var _walk_outside_time := 0.0
var _extra_step_pending := false
var _teeth_timer := 8.0
var _off_path_timer := 0.0
var _cached_off_path := 0.0
var _zone_timer := 0.0
var _flash_warned := false
var _flash_near := 1.0   ## приглушение фонаря у близкой стены
var _flash_base_pos := Vector3(-0.19, -0.2, -0.55)
var _mouse_sway := Vector2.ZERO

var holding_breath := false
var breath_stamina := 100.0
var _was_holding_breath := false
var _hold_breath_cooldown := 0.0
var _hold_breath_muffle := 0.0
var _hold_breath_hint_timer := 0.0
var _heartbeat_haptic_timer := 0.0

var compass_glitch := 0.0           ## отклонение стрелки компаса при «Белой тьме»
var compass_stuck := 0.0            ## угол залипания стрелки компаса (радиан)
var whiteout_panic := 0.0          ## дезориентация и паника без леера (0..1)
var whiteout_intensity := 0.0      ## оптическая белая мгла для экранного шейдера
var _whiteout_warned := false
var _drift_no_anchor_t := 0.0      ## время без ориентиров для вестибулярного сноса
var _drift_dir := 1.0              ## направление увода по кругу (+1 / -1)
var _circle_warned := false
var kettle_heat_timer := 0.0       ## таймер тепла чайника на морозе (секунды)

var nav_sense: Node = null
var _last_yaw: float = 0.0
var _snap_cd: float = 0.0

# Динамические психосоматические модификаторы (Deep Phobia Engine)
var fov_offset: float = 0.0
var stamina_drain_mult: float = 1.0
var speed_mult: float = 1.0
var target_head_y: float = 1.58
var yaw_limit_base: float = NAN
var yaw_limit_half_angle: float = deg_to_rad(28.0)
var _prev_velocity_len: float = 0.0
var _was_on_floor: bool = true
var _last_fall_vel: float = 0.0
var _landing_dip: float = 0.0
var _turn_roll: float = 0.0
var _slope_roll: float = 0.0
var _lantern_lag: Vector2 = Vector2.ZERO
var _filament_flicker_t: float = 0.0


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD | LAYER_GLASS
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)

	head = Node3D.new()
	head.position.y = 1.58
	add_child(head)

	camera = Camera3D.new()
	camera.fov = Settings.fov
	camera.near = 0.05
	camera.far = 250.0
	head.add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.93, 0.8)
	flashlight.light_energy = 3.4
	flashlight.spot_range = 34.0
	flashlight.spot_angle = 36.0
	flashlight.spot_attenuation = 1.65
	flashlight.light_cull_mask = 0xFFFFFFFF
	flashlight.shadow_caster_mask = 0xFFFFFFFF
	flashlight.position = _flash_base_pos   # из фонаря в левой руке
	flashlight.visible = false
	# Тени от фонаря: силуэты деревьев, тень существа на стене — половина атмосферы.
	flashlight.shadow_enabled = Settings.quality >= 1   # на низком пресете фонарь без теней
	flashlight.shadow_bias = 0.12
	flashlight.shadow_normal_bias = 2.0
	camera.add_child(flashlight)

	var flash_fill := OmniLight3D.new()
	flash_fill.name = "FlashlightFill"
	flash_fill.light_color = Color(1.0, 0.94, 0.82)
	flash_fill.light_energy = 0.65
	flash_fill.omni_range = 9.0
	flash_fill.omni_attenuation = 1.3
	flash_fill.light_cull_mask = 0xFFFFFFFF
	flash_fill.shadow_enabled = false
	flashlight.add_child(flash_fill)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -INTERACT_DIST)
	_ray.collision_mask = LAYER_WORLD | LAYER_GLASS | Geo.LAYER_INTERACT
	_ray.add_exception(self)
	camera.add_child(_ray)

	_held_root = Node3D.new()
	_held_root.position = _held_base_pos
	_held_root.visible = false
	camera.add_child(_held_root)

	_hands = FPHands.new()
	_hands.player = self
	camera.add_child(_hands)

	var held_can := Props.canister(true)
	held_can.visible = false
	_held_root.add_child(held_can)
	_held_models[&"canister"] = held_can

	var held_oil := Props.oil_can(true)
	held_oil.visible = false
	_held_root.add_child(held_oil)
	_held_models[&"oil"] = held_oil

	var held_wood := Props.firewood_bundle(true)
	held_wood.visible = false
	_held_root.add_child(held_wood)
	_held_models[&"wood"] = held_wood
	_held_models[&"firewood"] = held_wood

	var held_shovel := Props.snow_shovel(true)
	held_shovel.visible = false
	_held_root.add_child(held_shovel)
	_held_models[&"shovel"] = held_shovel

	var held_trunk := Props.expedition_trunk()
	held_trunk.visible = false
	_held_root.add_child(held_trunk)
	_held_models[&"trunk"] = held_trunk

	for m in _held_models.values():
		FPHands.to_view_layer(m)
	_crank_player = _loop_player(CRANK_LOOP)
	_breath_player = _loop_player(BREATH_LOOP)

	_build_snow()
	_build_flash_dust()
	_build_flashlight_beam()
	_build_breath_emitter()
	const NavigationSenseClass = preload("res://scripts/player/navigation_sense.gd")
	nav_sense = NavigationSenseClass.new()
	nav_sense.name = "NavigationSense"
	add_child(nav_sense)
	Game.player = self
	if Game.is_prologue_trail() and not Game.has_flag("in_cabin") and Game.has_flag("left_cabin"):
		flashlight.visible = true
	elif Game.has_flag("in_cabin") or (Game.is_prologue() and not Game.has_flag("left_cabin")):
		flashlight.visible = false
	EventBus.player_died.connect(_on_died)


func _on_died(_reason: StringName) -> void:
	mode = Mode.LOCKED


# --- Ввод --------------------------------------------------------------------

func handle_input(event: InputEvent) -> void:
	if mode == Mode.LOCKED or mode == Mode.UI:
		return

	if mode == Mode.READING:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.is_pressed()):
			Game.hud.note_input(event)
			if not Game.hud.is_note_open():
				mode = Mode.WALK
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens := MOUSE_SENS * Settings.mouse_sens
		var y_sign := -1.0 if Settings.invert_y else 1.0
		var rel_x := mm.relative.x
		var rel_y := mm.relative.y
		var f_stage: int = Game.finger_stage()
		if f_stage == 2:
			# Квантование ввода задубевшими пальцами (+22..+31°C)
			rel_x = roundf(rel_x / 2.5) * 2.5
			rel_y = roundf(rel_y / 2.5) * 2.5
		elif f_stage == 3:
			# Окоченение (+14..+21°C): тремор и потеря микромоторики
			rel_x = roundf(rel_x / 5.0) * 5.0 + randf_range(-2.0, 2.0)
			rel_y = roundf(rel_y / 5.0) * 5.0 + randf_range(-2.0, 2.0)
		_mouse_sway += Vector2(rel_x, rel_y * y_sign) * 0.00075
		_mouse_sway.x = clampf(_mouse_sway.x, -0.09, 0.09)
		_mouse_sway.y = clampf(_mouse_sway.y, -0.09, 0.09)
		if not is_nan(yaw_limit_base):
			var cur_yaw := wrapf(rotation.y - yaw_limit_base, -PI, PI)
			var new_yaw := clampf(cur_yaw - rel_x * sens, -yaw_limit_half_angle, yaw_limit_half_angle)
			rotation.y = yaw_limit_base + new_yaw
			head.rotation.x = clampf(head.rotation.x - rel_y * sens * y_sign, deg_to_rad(-45.0), deg_to_rad(35.0))
			return
		if Game.has_flag("in_cabin"):
			var base_yaw := deg_to_rad(225.0)
			var cur_yaw := wrapf(rotation.y - base_yaw, -PI, PI)
			var new_yaw := clampf(cur_yaw - rel_x * sens, deg_to_rad(-70.0), deg_to_rad(70.0))
			rotation.y = base_yaw + new_yaw
			head.rotation.x = clampf(head.rotation.x - rel_y * sens * y_sign, deg_to_rad(-45.0), deg_to_rad(35.0))
			return
		_turn_roll = clampf(_turn_roll - rel_x * sens * 1.6, deg_to_rad(-2.2), deg_to_rad(2.2))
		_lantern_lag.x = clampf(_lantern_lag.x - rel_x * sens * 14.0, -0.06, 0.06)
		_lantern_lag.y = clampf(_lantern_lag.y - rel_y * sens * y_sign * 14.0, -0.06, 0.06)
		rotate_y(-rel_x * sens)
		head.rotation.x = clampf(head.rotation.x - rel_y * sens * y_sign, deg_to_rad(-85.0), deg_to_rad(85.0))
		return

	if event.is_action_pressed(&"flashlight"):
		toggle_flashlight()
		return
	if event.is_action_pressed(&"map"):
		toggle_tablet()
		return
	if event.is_action_pressed(&"tasks"):
		Game.hud.toggle_tasks()
		return

	if mode == Mode.RADIO:
		_handle_radio_input(event)
		return

	if event.is_action_pressed(&"drop"):
		drop_held()
		return
	if Game.zenit != null and Game.zenit.raised:
		return   # у глаза «Зенит»: RT/ЛКМ — затвор, ракетница не стреляет
	if event.is_action_pressed(&"flare") or (event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		if _hands != null and _hands.is_tablet_up():
			tap_compass()
			return
		fire_flare()
		return
	if event.is_action_pressed(&"interact"):
		if Game.finger_stage() == 3 and Game.is_outside() and randf() < 0.22:
			Game.audio.play_2d("res://assets/audio/clank.ogg", -4.0)
			Game.hud.subtitle(Loc.t(&"sub.finger_numb_fumble"), 3.0)
			return
		if Game.has_flag("riding") and Snowmobile.instance != null:
			Snowmobile.instance.request_dismount()
			return
		if Game.has_flag("in_cabin"):
			if Vehicle.can_exit_cabin():
				Vehicle.request_exit()
				return
		if _focused != null and _focused.hold_time <= 0.0:
			_hands.reach()
			_focused.interact(self)


func _handle_radio_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		Game.radio.exit()
	elif event.is_action_pressed(&"transmit"):
		Game.radio.transmit()
	elif event.is_action_pressed(&"record"):
		Game.radio.start_recording()
	elif event is InputEventKey and event.pressed:
		var ke := event as InputEventKey
		if ke.keycode == KEY_Q:
			Game.radio.fine_step(-1.0)
		elif ke.keycode == KEY_E:
			Game.radio.fine_step(1.0)
		elif ke.keycode == KEY_TAB or ke.keycode == KEY_V:
			Game.radio.cycle_variometer()
	elif event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		var step_mult := 0.2 if Game.firm_hands_timer > 0.0 else (3.5 if Game.finger_stage() >= 2 else 1.0)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			Game.radio.nudge_scaled(1, step_mult)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Game.radio.nudge_scaled(-1, step_mult)


# --- Физика и обновление -----------------------------------------------------

func _physics_process(delta: float) -> void:
	if Game.has_flag("in_cabin"):
		velocity = Vector3.ZERO
		var look_vec := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		if look_vec.length_squared() > 0.005:
			var stick_sens: float = 3.2 * Settings.gamepad_sens
			var y_sign := -1.0 if Settings.invert_y else 1.0
			var base_yaw := deg_to_rad(225.0)
			var cur_yaw := wrapf(rotation.y - base_yaw, -PI, PI)
			var new_yaw := clampf(cur_yaw - look_vec.x * stick_sens * delta, deg_to_rad(-70.0), deg_to_rad(70.0))
			rotation.y = base_yaw + new_yaw
			head.rotation.x = clampf(head.rotation.x - look_vec.y * stick_sens * delta * y_sign, deg_to_rad(-45.0), deg_to_rad(35.0))
		return

	if Game.has_flag("riding"):
		velocity = Vector3.ZERO
		var rl := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		if rl.length_squared() > 0.005:
			var rs: float = 2.4 * Settings.gamepad_sens
			rotate_y(-rl.x * rs * delta)
			head.rotation.x = clampf(head.rotation.x - rl.y * rs * delta * (-1.0 if Settings.invert_y else 1.0), deg_to_rad(-60.0), deg_to_rad(60.0))
		_zone_timer -= delta
		if _zone_timer <= 0.0:
			_zone_timer = 0.2
			if Game.level != null:
				Game.set_zone(Game.level.zone_at(global_position))
		_update_focus(delta)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
		_last_fall_vel = velocity.y
	else:
		if not _was_on_floor and _last_fall_vel < -1.6:
			var drop_intensity := clampf(absf(_last_fall_vel) / 7.5, 0.02, 0.09)
			_landing_dip = -drop_intensity
			shake(0.012 * drop_intensity, 0.18)
			var land_snd := _step_sound(Game.is_outside())
			Game.audio.play_2d(land_snd, -8.0)
		_last_fall_vel = 0.0
	_was_on_floor = is_on_floor()

	if is_on_floor():
		var floor_n := get_floor_normal()
		var local_n := transform.basis.inverse() * floor_n
		var target_slope_roll := clampf(-local_n.x * 0.045, deg_to_rad(-2.5), deg_to_rad(2.5))
		_slope_roll = lerpf(_slope_roll, target_slope_roll, minf(delta * 6.0, 1.0))
	else:
		_slope_roll = lerpf(_slope_roll, 0.0, minf(delta * 4.0, 1.0))

	# Отслеживание резкого разворота в темноте снаружи (триггер внимания Ырки)
	if delta > 0.0:
		var yaw_speed := absf(angle_difference(_last_yaw, rotation.y)) / delta
		_last_yaw = rotation.y
		if _snap_cd > 0.0:
			_snap_cd -= delta
		if Game.is_outside() and not Game.is_daylight() and yaw_speed > 4.2 and _snap_cd <= 0.0:
			Attention.add(6.0)
			_snap_cd = 1.0
		if flashlight != null and flashlight.visible and Game.is_outside() and not Game.is_daylight():
			Attention.add(0.4 * delta)

	var dir := Vector3.ZERO
	_sprinting = false
	if mode == Mode.WALK:
		var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		dir = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
		# Режим «нажать» (Настройки): бег включается кнопкой и держится, пока идёшь вперёд и есть силы.
		var want_sprint := Input.is_action_pressed(&"sprint")
		if Settings.toggle_sprint:
			if Input.is_action_just_pressed(&"sprint"):
				_sprint_latch = not _sprint_latch
			if input.y >= 0.0 or stamina <= 1.0:
				_sprint_latch = false
			want_sprint = _sprint_latch
		_sprinting = want_sprint and held != &"canister" and held != &"trunk" and stamina > 1.0 and input.y < 0.0 and not cranking
		if Input.is_action_just_pressed(&"wipe_face") and Game.hud != null:
			Game.hud.wipe_face_frost()

		# Обзор правым аналоговым стиком геймпада
		var look_vec := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		if look_vec.length_squared() > 0.005:
			var stick_sens: float = 2.4 * Settings.gamepad_sens
			var y_sign := -1.0 if Settings.invert_y else 1.0
			_mouse_sway += Vector2(look_vec.x, look_vec.y * y_sign) * delta * 0.18
			_mouse_sway.x = clampf(_mouse_sway.x, -0.09, 0.09)
			_mouse_sway.y = clampf(_mouse_sway.y, -0.09, 0.09)
			_turn_roll = clampf(_turn_roll - look_vec.x * stick_sens * delta * 0.45, deg_to_rad(-2.2), deg_to_rad(2.2))
			_lantern_lag.x = clampf(_lantern_lag.x - look_vec.x * stick_sens * delta * 2.8, -0.06, 0.06)
			_lantern_lag.y = clampf(_lantern_lag.y - look_vec.y * stick_sens * delta * y_sign * 2.8, -0.06, 0.06)
			rotate_y(-look_vec.x * stick_sens * delta)
			head.rotation.x = clampf(head.rotation.x - look_vec.y * stick_sens * delta * y_sign, deg_to_rad(-85.0), deg_to_rad(85.0))
	var speed := WALK_SPEED
	if Game.is_prologue_trail():
		speed = PrologueTrail.TRAIL_SPEED * (1.35 if _sprinting else 1.0)
	elif Game.skis_equipped and Game.is_outside():
		speed = WALK_SPEED * 1.4
		_sprinting = false
	elif held == &"canister":
		speed = CANISTER_SPEED
	elif held == &"trunk" or held == &"dog":
		speed = 1.95
	elif held == &"kettle" or held == &"blowtorch":
		speed = WALK_SPEED * 0.92
	elif held == &"wood":
		speed = 2.7 if _sprinting else 2.1
	elif _sprinting:
		speed = SPRINT_SPEED

	# Целина и глубокие сугробы во дворе: вне нахоженных троп шаг замедляется (проверка 8 раз/сек вместо 60)
	_off_path_timer -= delta
	if _off_path_timer <= 0.0:
		_off_path_timer = 0.12
		if Game.is_outside() and Game.yard != null:
			_cached_off_path = Game.yard.distance_to_path(global_position)
		else:
			_cached_off_path = 0.0
	# На лыжах глубокий наст держит вес — целина не замедляет!
	var shoes := Gear.has(&"snowshoes") and Game.is_outside()   # снегоступы: целина не так держит
	if Game.has_flag("in_deep_snow"):
		speed *= 0.72 if shoes else 0.55
	elif not Game.skis_equipped and _cached_off_path > 6.0:
		speed *= 0.9 if shoes else 0.75
	if Game.is_outside() and global_position.y > 70.0 and not Game.skis_equipped:
		speed *= 0.78   # крутой каменистый курумник венца цирка: без лыж ноги проваливаются меж валунов

	# Натоптанная тропа: твёрдый плотный снег даёт надёжную опору
	if Game.is_outside() and _cached_off_path < 1.8:
		speed *= 1.15

	speed *= speed_mult

	var target := dir * speed
	var accel_rate := 14.0 if target.length_squared() < 0.01 else 9.5
	velocity.x = move_toward(velocity.x, target.x, accel_rate * delta)
	velocity.z = move_toward(velocity.z, target.z, accel_rate * delta)
	move_and_slide()
	_lay_footprints()
	_prev_velocity_len = Vector2(velocity.x, velocity.z).length()

	# Страховка от провала в пропасть (если игрок выпал из геометрии)
	var in_bunker_zone := Game.zone == &"bunker" or (global_position.x > 50.0 and global_position.z > 5.0 and global_position.z < 20.0 and global_position.y < -20.0) 		or StationLore.zone_at(global_position) != &"" or MineHorizon.zone_has(global_position)   # подпол Брагина, тоннель к «Отзвуку», Горизонт-40 — тоже под землёй
	if (global_position.y < -8.0 and not in_bunker_zone) or global_position.y < -55.0:
		global_position = Station.SPAWN
		velocity = Vector3.ZERO

	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_timer = 0.08
		if Game.level != null:
			Game.set_zone(Game.level.zone_at(global_position))
			if Game.skis_equipped and Game.level is Station and (Game.level as Station).is_pos_inside_house(global_position):
				Game.skis_equipped = false
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"sub.skis_auto_off"), 3.0)
	_update_activity()
	_update_focus(delta)
	_update_steps(delta)
	_update_extra_step(delta)


func _process(delta: float) -> void:
	if head != null:
		head.position.y = lerpf(head.position.y, target_head_y, minf(delta * 5.0, 1.0))
	_update_stamina(delta)
	_update_hold_breath(delta)
	_update_flashlight(delta)
	_update_breath(delta)
	_update_shiver(delta)
	_update_camera_fx(delta)
	_update_whiteout_disorientation(delta)
	var outside := Game.is_outside()
	for sn: CPUParticles3D in [_snow, _snow_near]:
		if sn == null:
			continue
		sn.visible = outside     # не выключаем эмиссию: при включении частицы заново просчитывали 4 с (фриз на выходе из дома)
		if Game.weather != null:
			sn.speed_scale = 1.0 + Game.weather.intensity * 1.6
			sn.direction = Vector3(0.3 + Game.weather.intensity * 2.5, -1.0, 0.1)
	var flash_active: bool = flashlight != null and flashlight.visible and Game.flash_charge > 0.5 and not closeup_dim and flashlight.light_energy > 0.15
	if _flash_dust != null:
		_flash_dust.visible = flash_active
		if flash_active:
			if outside and Game.weather != null:
				var w_int: float = Game.weather.intensity
				_flash_dust.direction = Vector3(0.3 + w_int * 2.2, -1.0, 0.15).normalized()
				_flash_dust.spread = 22.0
				_flash_dust.initial_velocity_min = 1.4 + w_int * 2.5
				_flash_dust.initial_velocity_max = 2.6 + w_int * 4.0
				_flash_dust.gravity = Vector3(0.4, -0.6, 0.0)
				_flash_dust.speed_scale = 1.0 + w_int * 1.5
			else:
				_flash_dust.direction = Vector3(0.0, -0.15, 0.0)
				_flash_dust.spread = 180.0
				_flash_dust.initial_velocity_min = 0.06
				_flash_dust.initial_velocity_max = 0.22
				_flash_dust.gravity = Vector3(0.0, -0.04, 0.0)
				_flash_dust.speed_scale = 1.0
	if _beam_mesh != null:
		_beam_mesh.visible = flash_active
		if flash_active and _beam_mat != null:
			var base_int := 0.16 * (_flash_near * (minf(flashlight.light_energy, 3.0) / 3.0))
			if outside and Game.weather != null:
				base_int *= (1.0 + Game.weather.intensity * 0.75)
			_beam_mat.set_shader_parameter(&"intensity", clampf(base_int, 0.0, 0.32))


func _update_whiteout_disorientation(delta: float) -> void:
	if held == &"kettle" and kettle_heat_timer > 0.0:
		if Game.is_outside():
			kettle_heat_timer -= delta
			if kettle_heat_timer <= 0.0 and Game.hud != null:
				Game.hud.subtitle(Loc.t(&"sub.kettle_cold_now"), 3.0)
		else:
			kettle_heat_timer = 90.0

	var outside := Game.is_outside()
	var in_whiteout: bool = outside and Game.weather != null and bool(Game.weather.get("is_whiteout"))

	# Оптическая плотность белой мглы (для шейдера ps1_post)
	var target_whiteout := 0.0
	if in_whiteout:
		target_whiteout = 0.92
	elif outside and Game.weather != null and Game.weather.intensity > 0.6:
		target_whiteout = clampf((Game.weather.intensity - 0.6) * 1.5, 0.0, 0.65)
	whiteout_intensity = move_toward(whiteout_intensity, target_whiteout, delta * 0.35)

	# Залипание стрелки компаса Адрианова на морозе без встряхивания
	if outside and Game.air_temp().x < -20.0:
		if absf(compass_stuck) < 0.05 and randf() < delta * 0.035:
			_drift_dir = -1.0 if randf() > 0.5 else 1.0
			compass_stuck = _drift_dir * randf_range(0.35, 0.85)
	elif not outside:
		compass_stuck = move_toward(compass_stuck, 0.0, delta * 0.25)

	# Если игрок на натоптанной тропе станции — он чувствует плотный снег под ногами и ориентируется
	if outside and _cached_off_path <= 2.8:
		whiteout_panic = move_toward(whiteout_panic, 0.0, delta * 1.5)
		compass_glitch = move_toward(compass_glitch, 0.0, delta * 2.5)
		_drift_no_anchor_t = maxf(0.0, _drift_no_anchor_t - delta * 3.0)
		_whiteout_warned = false
	elif in_whiteout and _cached_off_path > 3.2:
		whiteout_panic = minf(whiteout_panic + delta * 0.25, 1.0)
		compass_glitch = sin(Time.get_ticks_msec() * 0.007) * 1.85 * whiteout_panic + cos(Time.get_ticks_msec() * 0.011) * 0.4
		if camera != null:
			camera.rotation.z = sin(Time.get_ticks_msec() * 0.0025) * 0.035 * whiteout_panic
		if not _whiteout_warned and Game.hud != null:
			_whiteout_warned = true
			Game.hud.subtitle(Loc.t(&"sub.whiteout_lost"), 4.5)
			Director.add_tension(15.0, "сбился с тропы в белой тьме")
		if Game.audio != null and is_instance_valid(Game.audio._heart):
			Game.audio._heart.volume_db = maxf(Game.audio._heart.volume_db, lerpf(-22.0, -3.0, whiteout_panic))

		# Вестибулярный снос: человек без ориентиров неизбежно описывает круг
		if not Game.has_flag("riding") and Vector2(velocity.x, velocity.z).length() > 0.4:
			rotate_y(_drift_dir * 0.012 * delta)
			_drift_no_anchor_t += delta
			if _drift_no_anchor_t >= 40.0 and not _circle_warned:
				_circle_warned = true
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"sub.whiteout_circle"), 5.0)
				Director.add_tension(20.0, "циркуляция в белой мгле")
	else:
		whiteout_panic = move_toward(whiteout_panic, 0.0, delta * 0.8)
		compass_glitch = move_toward(compass_glitch, 0.0, delta * 2.0)
		if camera != null and absf(camera.rotation.z) > 0.001:
			camera.rotation.z = move_toward(camera.rotation.z, 0.0, delta * 0.1)
		_drift_no_anchor_t = maxf(0.0, _drift_no_anchor_t - delta * 2.5)
		if _drift_no_anchor_t <= 0.0:
			_circle_warned = false


## Механика гипноза/наваждения Ырки: мягкий дрейф взгляда назад, преодолеваемый мышью.
func apply_yaw_drift(target_yaw: float, strength: float, delta: float) -> void:
	if mode != Mode.WALK:
		return
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var step := signf(diff) * minf(absf(diff), strength * delta)
	rotate_y(step)


func is_sprinting() -> bool:
	return _sprinting


func _update_activity() -> void:
	if mode == Mode.RADIO:
		Game.set_activity(&"radio")
	elif _hold_target != null:
		Game.set_activity(&"working")
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		Game.set_activity(&"running" if _sprinting else &"walking")
	else:
		Game.set_activity(&"idle")


func _update_focus(delta: float) -> void:
	var found: Interactable = null
	if mode == Mode.WALK and _ray.is_colliding():
		found = _ray.get_collider() as Interactable
	_focused = found

	# Удержание E: прогресс сбрасывается, если отвёл взгляд или отпустил клавишу.
	var holding := found != null and found.hold_time > 0.0 and found.enabled and Input.is_action_pressed(&"interact") and found.can_hold()
	if holding:
		if _hold_target != found:
			_hold_target = found
			_hold_t = 0.0
			_hold_sound_t = 0.0
		_hold_t += delta * Consequences.hands_k()   # обморожение — пальцы не гнутся
		_hold_sound_t -= delta
		if found.hold_sound != "" and _hold_sound_t <= 0.0:
			_hold_sound_t = 0.55
			Game.audio.play_3d(found.hold_sound, found.global_position + Vector3(0, 0.5, 0), -8.0)
		if _hold_t >= found.hold_time:
			_hold_target = null
			_hold_t = 0.0
			_hands.reach()
			found.interact(self)
	else:
		_hold_target = null
		_hold_t = 0.0

	if Game.hud == null:
		return
	if found == null:
		if Game.has_flag("in_cabin") and Vehicle.can_exit_cabin():
			Game.hud.set_prompt(Loc.t(&"cab.exit"))
		else:
			Game.hud.set_prompt("")
	elif _hold_target != null:
		Game.hud.set_prompt(found.get_prompt())
	else:
		Game.hud.set_prompt(found.get_prompt())
	Game.hud.set_hold(_hold_t / found.hold_time if found != null and _hold_target != null else 0.0)


func _update_steps(delta: float) -> void:
	if not is_on_floor():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.3:
		_step_acc = 0.0
		return
	_step_acc += speed * delta
	var is_out := Game.is_outside()
	if Game.level is Station and (Game.level as Station).is_pos_inside_house(global_position):
		is_out = false
	var in_deep: bool = is_out and (Game.has_flag("in_deep_snow") or _cached_off_path > 4.5)
	var step_len := 1.85 if Game.skis_equipped else (1.55 if in_deep else STEP_LEN)
	if _step_acc < step_len:
		return
	_step_acc = 0.0
	var path := _step_sound(is_out)
	var vol_offset := randf_range(-1.2, 1.2)
	var base_vol := -12.0 if not _sprinting else -8.0
	if in_deep:
		base_vol -= 1.0
	var frost_pitch := 1.0
	if is_out and not Game.skis_equipped:
		# Хруст снега по реальной температуре: при -15°C мягкий, при -42°C резкий «стеклянный»
		var temp_c: float = Game.air_temp().x
		var frost_k := clampf((-15.0 - temp_c) / 27.0, 0.0, 1.0)
		frost_pitch = lerpf(0.92, 1.24, frost_k)
		base_vol += lerpf(-1.2, 2.2, frost_k)
	var p := Game.audio.play_2d(path, base_vol + vol_offset)
	if p != null:
		p.pitch_scale = (randf_range(0.82, 0.96) if in_deep else randf_range(0.95, 1.10)) * frost_pitch
	if is_out and Game.yrka != null and is_instance_valid(Game.yrka) and Game.yrka.enabled:
		Game.yrka.on_player_footstep(global_position, global_basis.z)
	if is_out and _sprinting and Game.audio != null and Game.audio.has_method(&"record_player_noise"):
		Game.audio.record_player_noise(global_position)
	if not is_out and Game.radio != null and Game.radio.tube_synth != null:
		Game.radio.tube_synth.trigger_tube_microphonics(0.35 if not _sprinting else 0.65)


## Звук шага по поверхности: доски дома, гулкие мостки и крыльцо, железо, снег и твёрдый наст.
func _step_sound(is_out: bool) -> String:
	const CC := "res://assets/sfx/cc0/"
	if Game.skis_equipped and is_out:
		return CC + ("step_crust_%d.ogg" % randi_range(1, 3))
	if Game.zone == &"bunker" or Game.zone == &"gen_shack":
		return CC + ("step_metal_%d.ogg" % randi_range(1, 6) if randf() < 0.7 else "step_metal_b_%d.ogg" % randi_range(1, 3))
	if Game.level != null and Game.level.has_method(&"on_boardwalk") and bool(Game.level.call(&"on_boardwalk", global_position)):
		return CC + "step_deck_%d.ogg" % randi_range(1, 8)
	if not is_out:
		if randf() < 0.08:
			return CC + ("floor_creak_%d.ogg" % randi_range(1, 2))
		if randf() < 0.65:
			return CC + "step_plank_%d.ogg" % randi_range(1, 8)
		return STEPS_WOOD[randi() % STEPS_WOOD.size()]
	var in_deep: bool = Game.has_flag("in_deep_snow") or _cached_off_path > 4.5
	if in_deep:
		return STEPS_SNOW[randi() % STEPS_SNOW.size()]
	if randf() < 0.70:
		return CC + "step_crust_%d.ogg" % randi_range(1, 3)
	return STEPS_SNOW[randi() % STEPS_SNOW.size()]


func _update_stamina(delta: float) -> void:
	if _sprinting and Vector2(velocity.x, velocity.z).length() > 0.5:
		var drain := STAMINA_DRAIN
		if held == &"wood":
			drain *= 1.8
		if Game.is_prologue_trail():
			drain *= 1.3
		if Game.has_flag("in_deep_snow"):
			drain *= 1.5
		drain *= stamina_drain_mult
		if Gear.has(&"snowshoes") and Game.is_outside() and (Game.has_flag("in_deep_snow") or _cached_off_path > 6.0):
			drain *= 0.75
		stamina = maxf(stamina - drain * delta, 0.0)
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, 100.0)
	# Дыхание: после бега и на морозе. Без полосок — только звук.
	var breath := maxf((60.0 - stamina) / 60.0, (40.0 - Game.warmth) / 40.0)
	breath = clampf(breath, 0.0, 1.0)
	if _breath_player != null:
		_breath_player.volume_db = lerpf(_breath_player.volume_db, linear_to_db(maxf(breath, 0.0001)) - 9.0, minf(delta * 3.0, 1.0))


## Мягкая круглая «дымка» для пара изо рта: радиальный градиент вместо квадратного спрайта.
static func puff_material(alpha: float) -> StandardMaterial3D:
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
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = gt
	smat.albedo_color = Color(0.86, 0.89, 0.95, alpha)
	smat.vertex_color_use_as_albedo = true
	return smat


## Пар растворяется к концу жизни частицы.
static func puff_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	return ramp


func _build_breath_emitter() -> void:
	_breath_emitter = CPUParticles3D.new()
	_breath_emitter.amount = 10
	_breath_emitter.lifetime = 1.3
	_breath_emitter.one_shot = true
	_breath_emitter.explosiveness = 0.85
	_breath_emitter.local_coords = false   # пар остаётся в воздухе, а не висит перед глазами
	_breath_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_breath_emitter.emission_sphere_radius = 0.03
	_breath_emitter.direction = Vector3(0.0, 0.1, -1.0)
	_breath_emitter.spread = 18.0
	_breath_emitter.initial_velocity_min = 0.3
	_breath_emitter.initial_velocity_max = 0.55
	_breath_emitter.damping_min = 0.3
	_breath_emitter.damping_max = 0.5
	_breath_emitter.gravity = Vector3(0.0, 0.08, 0.0)
	_breath_emitter.scale_amount_min = 0.6
	_breath_emitter.scale_amount_max = 1.4
	_breath_emitter.color_ramp = puff_ramp()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	qm.material = puff_material(0.13)
	_breath_emitter.mesh = qm
	_breath_emitter.position = Vector3(0.0, -0.2, -0.55)
	camera.add_child(_breath_emitter)


func _update_breath(delta: float) -> void:
	if _breath_emitter == null:
		return
	if holding_breath:
		return
	_breath_timer -= delta
	if _breath_timer <= 0.0:
		if Game.warmth < 55.0 or Game.is_outside() or Game.house_cold > 0.4:
			if Game.is_outside() and Game.weather != null:
				var w_int: float = Game.weather.intensity
				_breath_emitter.direction = Vector3(0.15 + w_int * 1.8, -0.05, -0.8).normalized()
				_breath_emitter.initial_velocity_min = 0.4 + w_int * 0.8
				_breath_emitter.initial_velocity_max = 0.8 + w_int * 1.5
				_breath_emitter.gravity = Vector3(w_int * 0.6, -0.05, 0.0)
			else:
				_breath_emitter.direction = Vector3(0.0, 0.2, -0.7).normalized()
				_breath_emitter.initial_velocity_min = 0.25
				_breath_emitter.initial_velocity_max = 0.45
				_breath_emitter.gravity = Vector3(0.0, 0.12, 0.0)
			_breath_emitter.restart()
		_breath_timer = randf_range(1.4, 2.0) if _sprinting else randf_range(3.2, 4.2)

	# Чужой выдох из-за плеча (Phantom Breath)
	if Vector2(velocity.x, velocity.z).length_squared() < 0.05:
		_still_time += delta
	else:
		_still_time = 0.0

	if Game.is_night() and Game.night >= 4 and not _phantom_breath_done and _still_time > 3.8 and Game.is_indoors():
		_phantom_breath_done = true
		_trigger_phantom_breath()


func _update_hold_breath(delta: float) -> void:
	if mode != Mode.WALK or cranking:
		holding_breath = false
	else:
		var space_pressed := Input.is_action_pressed(&"hold_breath")
		if Settings.toggle_breath:
			# «Нажать»: первое нажатие — задержать, второе — выдохнуть (держать пробел долго неудобно)
			if Input.is_action_just_pressed(&"hold_breath"):
				_breath_latch = not _breath_latch
			space_pressed = _breath_latch
		# Задержать дыхание снова можно, только отдышавшись: с 40 % запаса (или продолжая уже начатую задержку).
		# Раньше хватало 4 % и 1.3 с паузы — короткими «пробелами» Ырку держали на нуле.
		if space_pressed and _hold_breath_cooldown <= 0.0 and (breath_stamina > 40.0 or (holding_breath and breath_stamina > 0.0)):
			holding_breath = true
		else:
			holding_breath = false

	if holding_breath:
		breath_stamina = maxf(breath_stamina - delta * 15.0, 0.0)
		_hold_breath_muffle = lerpf(_hold_breath_muffle, 1.0, minf(delta * 5.0, 1.0))
		if _breath_player != null:
			_breath_player.volume_db = lerpf(_breath_player.volume_db, -80.0, minf(delta * 8.0, 1.0))
		if Game.audio != null and is_instance_valid(Game.audio._heart):
			var heart_vol: float = lerpf(-16.0, -2.0, (100.0 - breath_stamina) / 100.0)
			Game.audio._heart.volume_db = maxf(Game.audio._heart.volume_db, heart_vol)
		camera.fov = lerpf(camera.fov, Settings.fov - 4.0 + fov_offset, minf(delta * 5.0, 1.0))
		# Тактильная пульсация сердца на геймпаде
		_heartbeat_haptic_timer -= delta
		if _heartbeat_haptic_timer <= 0.0:
			var urgency: float = (100.0 - breath_stamina) / 100.0
			_heartbeat_haptic_timer = lerpf(0.85, 0.42, urgency)
			if Game != null:
				Game.vibrate(lerpf(0.18, 0.45, urgency), lerpf(0.1, 0.35, urgency), 0.12)
		if breath_stamina <= 0.0:
			holding_breath = false
	else:
		_breath_latch = false
		_heartbeat_haptic_timer = 0.0
		breath_stamina = minf(breath_stamina + delta * 20.0, 100.0)
		_hold_breath_cooldown = maxf(_hold_breath_cooldown - delta, 0.0)
		_hold_breath_muffle = lerpf(_hold_breath_muffle, 0.0, minf(delta * 4.0, 1.0))
		camera.fov = lerpf(camera.fov, (zoom_fov if zoom_fov > 0.0 else Settings.fov) + fov_offset, minf(delta * (8.0 if zoom_fov > 0.0 else 4.0), 1.0))

	# Аудиофильтр приглушения внешнего мира
	if AudioServer.get_bus_effect_count(0) > 2:
		var lp := AudioServer.get_bus_effect(0, 2) as AudioEffectLowPassFilter
		if lp != null:
			lp.cutoff_hz = lerpf(20000.0, 750.0, _hold_breath_muffle)

	if _was_holding_breath and not holding_breath:
		_on_breath_released()
	_was_holding_breath = holding_breath


func _on_breath_released() -> void:
	_hold_breath_cooldown = 2.0
	# Вдох — свой чистый звук дыхания (нейросетевые breath_close шипели «спи… спи…»).
	var gasp := Game.audio.play_2d("res://assets/sfx/cc0/player_breath_loop.ogg", -6.0, 1.1)
	if gasp != null:
		gasp.pitch_scale = randf_range(1.05, 1.2)

	# Кашель — расплата за передержку на морозе, а не лотерея при каждом вдохе:
	# отпустил вовремя (запас > 25 %) — не кашляешь; передержал — шанс растёт с холодом.
	var overheld := breath_stamina < 25.0
	var cold_danger: bool = Game.warmth < 44.0 or Game.is_outside()
	var cough_chance: float = 0.0
	if overheld:
		cough_chance = 0.75 if Game.warmth < 30.0 else (0.5 if cold_danger else 0.15)
	if randf() < cough_chance:
		var tree := get_tree()
		if tree != null:
			tree.create_timer(randf_range(0.35, 0.75), false).timeout.connect(func():
				if is_instance_valid(self):
					_trigger_cough()
			)


func _trigger_cough() -> void:
	var cough_snd := "res://assets/audio/cough.ogg"
	var p := Game.audio.play_3d(cough_snd, head.global_position, 0.0, 12.0)
	if p != null:
		p.pitch_scale = randf_range(0.85, 1.15)
	shake(0.04, 0.35)
	Game.hud.subtitle(Loc.t(&"sub.cough"), 2.5)
	Director.add_tension(14.0, "кашель дежурного")
	if Game.is_outside() and Game.yrka != null and is_instance_valid(Game.yrka) and Game.yrka.enabled:
		Game.yrka.threat = minf(Game.yrka.threat + 22.0, 100.0)
		Game.yrka.notice_sound(global_position)
	EventBus.noise_emitted.emit(global_position, 2.5, &"cough")
	if Game.is_outside() and Game.audio != null and Game.audio.has_method(&"record_player_noise"):
		Game.audio.record_player_noise(global_position)


func _trigger_phantom_breath() -> void:
	var phantom := CPUParticles3D.new()
	phantom.amount = 16
	phantom.lifetime = 1.8
	phantom.one_shot = true
	phantom.explosiveness = 0.92
	phantom.direction = Vector3(-0.15, 0.05, -1.0)
	phantom.spread = 12.0
	phantom.initial_velocity_min = 0.4
	phantom.initial_velocity_max = 0.75
	phantom.gravity = Vector3(0.0, 0.05, 0.0)
	phantom.scale_amount_min = 0.6
	phantom.scale_amount_max = 2.0
	phantom.color_ramp = puff_ramp()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	qm.material = puff_material(0.22)
	phantom.mesh = qm
	phantom.position = Vector3(0.26, -0.06, 0.08)
	camera.add_child(phantom)
	phantom.restart()

	Game.audio.play_3d("res://assets/audio/whisper.ogg", global_position + Vector3(0.2, 1.5, 0.2), -3.0)
	Game.hud.subtitle(Loc.t(&"sub.phantom_breath"), 3.5)
	Director.add_tension(12.0, "чужой выдох")
	Geo.free_after(phantom, 2.5)


func _update_shiver(delta: float) -> void:
	if (Game.warmth < 38.0 or Game.fatigue > 65.0) and Game.tea_warmth_timer <= 0.0:
		var factor := clampf((38.0 - Game.warmth) / 38.0 + (Game.fatigue - 65.0) / 35.0, 0.0, 1.0)
		var shake := (randf() - 0.5) * 0.0065 * factor
		camera.rotation.z = lerpf(camera.rotation.z, shake, minf(delta * 14.0, 1.0))
		camera.position.x = lerpf(camera.position.x, (randf() - 0.5) * 0.0045 * factor, minf(delta * 14.0, 1.0))
		camera.position.y = lerpf(camera.position.y, (randf() - 0.5) * 0.0045 * factor, minf(delta * 14.0, 1.0))
		# Окоченевшая микро-дрожь прицела при наведении на приборы в сильный мороз
		if Game.warmth < 32.0 and mode == Mode.WALK:
			var t_s := float(Time.get_ticks_msec()) * 0.009
			var aim_drift := clampf((32.0 - Game.warmth) / 32.0, 0.0, 1.0) * 0.00055
			head.rotation.x = clampf(head.rotation.x + sin(t_s * 1.7) * aim_drift, deg_to_rad(-82.0), deg_to_rad(82.0))
			rotation.y += cos(t_s * 1.3) * aim_drift

		# Звук стука зубов от лютого мороза
		_teeth_timer -= delta
		if _teeth_timer <= 0.0 and Game.warmth < 32.0:
			_teeth_timer = randf_range(8.0, 15.0)
			Game.audio.play_2d("res://assets/audio/teeth_chatter.ogg", -2.0)
	elif Game.tea_warmth_timer > 0.0:
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, minf(delta * 10.0, 1.0))
		camera.position.x = lerpf(camera.position.x, 0.0, minf(delta * 10.0, 1.0))
		camera.position.y = lerpf(camera.position.y, 0.0, minf(delta * 10.0, 1.0))


func _update_extra_step(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	if moving and Game.is_outside():
		_walk_outside_time += delta
	else:
		var step_thresh := 2.2
		if Game.psychosomatic != null and Game.psychosomatic.has_method(&"get_extra_step_threshold"):
			step_thresh = float(Game.psychosomatic.call(&"get_extra_step_threshold"))
		if Attention.tier >= 1:
			step_thresh = minf(step_thresh, 1.3)
		if _walk_outside_time > step_thresh and not _extra_step_pending and Game.is_outside() and Game.is_night():
			_extra_step_pending = true
			_play_delayed_extra_step()
		_walk_outside_time = 0.0


func _play_delayed_extra_step() -> void:
	var delay := 0.42
	var behind_dist := 2.2
	if Attention.tier >= 1:
		delay = randf_range(0.35, 0.65)
		behind_dist = randf_range(1.6, 2.6)
	elif Game.psychosomatic != null and Game.psychosomatic.has_method(&"get_delayed_step_params"):
		var p: Vector2 = Game.psychosomatic.call(&"get_delayed_step_params")
		delay = p.x
		behind_dist = p.y
	await get_tree().create_timer(delay, false).timeout
	_extra_step_pending = false
	if Game.player == null or not Game.is_outside():
		return
	var behind := global_position + global_transform.basis.z * behind_dist   # +Z тела — это за спиной
	var snd: String = STEPS_SNOW[randi() % STEPS_SNOW.size()]
	Game.audio.play_3d(snd, behind, -4.0, 6.0)
	Attention.add(2.0)
	Director.add_tension(8.0, "шаг за спиной")


func _update_flashlight(delta: float) -> void:
	var hands_busy := held == &"wood" or held == &"canister"
	if Input.is_action_just_pressed(&"crank") and hands_busy:
		Game.hud.subtitle(Loc.t(&"sub.hands_busy_crank"), 2.5)
	cranking = (mode == Mode.WALK or mode == Mode.RADIO) and Input.is_action_pressed(&"crank") and not hands_busy
	var crank_surge := 1.0
	if cranking:
		Game.flash_charge = minf(Game.flash_charge + CRANK_RATE * Consequences.hands_k() * delta, 100.0)
		# Физическая отдача «Жучка»: ритмичный толчок камеры + пульсирующий скачок яркости динамо на каждый жим
		var t_crank := float(Time.get_ticks_msec()) * 0.034
		var pulse := pow(0.5 + 0.5 * sin(t_crank), 2.0)
		crank_surge = lerpf(0.76, 1.26, pulse)
		camera.rotation.z = lerpf(camera.rotation.z, sin(t_crank) * 0.009, minf(delta * 18.0, 1.0))
		camera.position.y = lerpf(camera.position.y, -pulse * 0.008, minf(delta * 18.0, 1.0))
		if Game != null and randf() < delta * 10.0:
			Game.vibrate(0.22, 0.08, 0.09)
	if _crank_player != null:
		_crank_player.volume_db = lerpf(_crank_player.volume_db, -6.0 if cranking else -80.0, minf(delta * 12.0, 1.0))

	# Инерция взгляда, шаг и тремор замерзающих рук на фонаре
	_mouse_sway = _mouse_sway.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	_lantern_lag = _lantern_lag.lerp(Vector2.ZERO, minf(delta * 7.0, 1.0))
	var speed := Vector2(velocity.x, velocity.z).length()
	var walk_k := clampf(speed / WALK_SPEED, 0.0, 1.35)
	var bob_factor: float = Settings.head_bob if (Settings != null and "head_bob" in Settings) else 1.0
	var bob_offset := Vector3(
		sin(_bob_t * 0.5) * 0.015 * walk_k * bob_factor,
		-absf(cos(_bob_t)) * 0.016 * walk_k * bob_factor,
		0.0
	)
	var bob_rot := Vector3(
		cos(_bob_t) * 0.022 * walk_k * bob_factor,
		sin(_bob_t * 0.5) * 0.035 * walk_k * bob_factor,
		-sin(_bob_t * 0.5) * 0.025 * walk_k * bob_factor
	)
	var shiver_pos := Vector3.ZERO
	var shiver_rot := Vector3.ZERO
	if Game.warmth < 35.0:
		var cold_k := (35.0 - Game.warmth) / 35.0
		var t_ms := Time.get_ticks_msec() * 0.048
		var jx := sin(t_ms * 1.1) * 0.6 + (randf() - 0.5) * 0.4
		var jy := cos(t_ms * 1.3) * 0.6 + (randf() - 0.5) * 0.4
		var jz := sin(t_ms * 0.9) * 0.5 + (randf() - 0.5) * 0.3
		shiver_pos = Vector3(jx, jy, jz) * (cold_k * 0.014)
		shiver_rot = Vector3(jy * 1.2, jx * 1.5, jz * 0.8) * (cold_k * 0.045)
	var sway_pos := Vector3(-_mouse_sway.x * 0.16 + _lantern_lag.x * 0.16, _mouse_sway.y * 0.14 - _lantern_lag.y * 0.12, 0.0)
	var sway_rot := Vector3(-_mouse_sway.y * 0.42 - _lantern_lag.y * 0.40, -_mouse_sway.x * 0.52 - _lantern_lag.x * 0.50, _mouse_sway.x * 0.22 + _lantern_lag.x * 0.25)
	var target_pos := _flash_base_pos + bob_offset + shiver_pos + sway_pos
	var target_rot := bob_rot + shiver_rot + sway_rot
	if flashlight != null:
		if flashlight.visible and mode == Mode.WALK:
			flashlight.position = flashlight.position.lerp(target_pos, minf(delta * 13.0, 1.0))
			flashlight.rotation = flashlight.rotation.lerp(target_rot, minf(delta * 13.0, 1.0))
		else:
			flashlight.position = flashlight.position.lerp(_flash_base_pos, minf(delta * 10.0, 1.0))
			flashlight.rotation = flashlight.rotation.lerp(Vector3.ZERO, minf(delta * 10.0, 1.0))

	if not flashlight.visible:
		return
	Game.flash_charge = maxf(Game.flash_charge - FLASH_DRAIN * (0.5 if Gear.has(&"lamp_kuzbass") else 1.0) * delta, 0.0)   # «Кузбасс»: аккумулятор вдвое дольше
	var c := Game.flash_charge
	if c <= 0.0:
		flashlight.visible = false
		Game.hud.subtitle(Loc.t(&"sub.flash_dead"), 3.0)
		return

	if c > 25.0:
		_flash_warned = false
	elif c <= 15.0 and not _flash_warned:
		_flash_warned = true
		Game.audio.play_2d("res://assets/audio/clank.ogg", -14.0)
		Game.hud.subtitle(Loc.t(&"sub.flash_low"), 3.5, 1)
		Game.vibrate(0.2, 0.1, 0.15)

	# Фонарь из снабжения (галогенный, «Свердловск-2»): ярче и бьёт дальше
	var upg := Game.has_flag("upg_flashlight")
	var energy := (4.0 if upg else 3.0) * crank_surge
	var want_range := 46.0 if upg else 32.0
	if flashlight.spot_range != want_range:
		flashlight.spot_range = want_range
	if c < 25.0:
		energy *= lerpf(0.25, 1.0, c / 25.0)
		if randf() < delta * (25.0 - c) * 0.25:
			energy *= 0.2
	# Вплотную к стене или прибору пятно не выжигает белым: ближе 2.5 м фонарь «приглушается» (как глаз
	# привыкает). Приборы — на слое интерактива: раньше луч их не видел, и шкалы пересвечивало.
	var from := flashlight.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - flashlight.global_transform.basis.z * 2.6, Geo.LAYER_WORLD | Geo.LAYER_INTERACT)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var near_k := 1.0
	if not hit.is_empty():
		near_k = clampf(lerpf(0.18, 1.0, (from.distance_to(hit["position"]) - 0.35) / 2.2), 0.18, 1.0)
	if closeup_dim:
		near_k = 0.0
	if _filament_flicker_t > 0.0:
		_filament_flicker_t -= delta
		energy *= randf_range(0.4, 1.0)
	_flash_near = lerpf(_flash_near, near_k, minf(delta * 8.0, 1.0))
	energy *= _flash_near
	if absf(flashlight.light_energy - energy) > 0.01:
		flashlight.light_energy = energy
		var fill: OmniLight3D = flashlight.get_node_or_null("FlashlightFill") as OmniLight3D
		if fill != null:
			fill.light_energy = 0.65 * (minf(energy, 3.0) / 3.0)


func _update_camera_fx(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var in_deep: bool = Game.has_flag("in_deep_snow") or (_cached_off_path > 4.5 and not Game.skis_equipped and Game.is_outside())
	var bob_speed_k := 2.6 if in_deep else 3.2
	if speed > 0.3:
		_bob_t += delta * speed * bob_speed_k
	var bob_factor: float = Settings.head_bob if (Settings != null and "head_bob" in Settings) else 1.0
	var deep_bob_mult := 1.45 if in_deep else 1.0
	var bob := sin(_bob_t) * 0.025 * clampf(speed / WALK_SPEED, 0.0, 1.4) * bob_factor * deep_bob_mult
	var bob_h := cos(_bob_t * 0.5) * 0.012 * clampf(speed / WALK_SPEED, 0.0, 1.4) * bob_factor

	var sx := 0.0
	var sy := 0.0
	if _shake_left > 0.0:
		_shake_left -= delta
		sx = randf_range(-_shake_power, _shake_power)
		sy = randf_range(-_shake_power, _shake_power)
	# Дрожь от холода.
	if Game.warmth < 35.0:
		var k := (35.0 - Game.warmth) / 35.0 * 0.008
		sx += randf_range(-k, k)
		sy += randf_range(-k, k)
	# Механический рокот и вибрация пола в будке работающего дизель-генератора
	if Game.zone == &"gen_shack" and Game.power_on:
		var g_vib := sin(Time.get_ticks_msec() * 0.038) * 0.0028
		sx += g_vib * 0.5
		sy += g_vib

	# Вздрагивание и толчок камеры при сильных порывах ветра в метель
	if not Game.is_indoors() and Game.weather != null and (Game.weather.intensity > 0.22 or Game.weather.blizzard):
		_gust_timer -= delta
		if _gust_timer <= 0.0:
			var w_int: float = Game.weather.intensity
			_gust_timer = Game.rng.randf_range(7.0, 15.0) / (0.8 + w_int * 0.7)
			_gust_flinch_t = 0.16
			_gust_dip = Game.rng.randf_range(0.025, 0.046) * (1.0 + w_int * 0.55)
			_gust_jerk = Game.rng.randf_range(-0.024, 0.024) * (1.0 + w_int * 0.55)
			_gust_roll = Game.rng.randf_range(-0.012, 0.012) * (1.0 + w_int * 0.5)
			if randf() < 0.65:
				Game.audio.play_3d("res://assets/audio/gust.ogg", global_position, -6.5, 4.0)
	else:
		_gust_timer = minf(_gust_timer, 5.0)

	_turn_roll = lerpf(_turn_roll, 0.0, minf(delta * 8.0, 1.0))
	var base_roll := _turn_roll + _slope_roll
	if _gust_flinch_t > 0.0:
		_gust_flinch_t -= delta
		var gust_k := clampf(_gust_flinch_t / 0.16, 0.0, 1.0)
		sx += _gust_jerk * sin(gust_k * PI)
		sy -= _gust_dip * sin(gust_k * PI)
		base_roll += _gust_roll * sin(gust_k * PI)

	camera.rotation.z = lerpf(camera.rotation.z, base_roll, minf(delta * 12.0, 1.0))
	_landing_dip = lerpf(_landing_dip, 0.0, minf(delta * 8.0, 1.0))
	camera.h_offset = sx + bob_h
	camera.v_offset = bob + sy + _landing_dip

	# Покачивание переносимого предмета в руках при ходьбе с учётом массы (тяжёлый рундук)
	if _held_root != null and _held_root.visible:
		var walk_k := clampf(speed / WALK_SPEED, 0.0, 1.4)
		var is_heavy := held == &"trunk"
		var h_mult := 1.75 if is_heavy else 1.0
		var v_mult := 1.5 if is_heavy else 1.0
		var h_sway := sin(_bob_t * 0.5) * 0.012 * walk_k * h_mult
		var v_sway := cos(_bob_t) * 0.015 * walk_k * v_mult
		var rot_sway := sin(_bob_t * 0.5) * 2.2 * walk_k * (0.85 if is_heavy else 1.0)
		_held_root.position = _held_base_pos + Vector3(h_sway, -v_sway, 0.0)
		_held_root.rotation_degrees = _held_base_rot + Vector3(v_sway * 35.0, rot_sway, -h_sway * 25.0)


# --- API для систем и испугов ------------------------------------------------

func toggle_flashlight() -> void:
	if torch_lost:
		Game.hud.subtitle(Loc.t(&"mst.torch_lost"), 2.5)
		return
	if not flashlight.visible and Game.flash_charge <= 0.5:
		Game.hud.subtitle(Loc.t(&"sub.flash_dead"), 3.0)
		return
	flashlight.visible = not flashlight.visible
	var click := Game.audio.play_2d("res://assets/audio/clank.ogg", -10.0, randf_range(1.75, 1.95))
	if flashlight.visible:
		_filament_flicker_t = 0.07
	if flashlight.visible and Game.is_night():
		SaveGame.flags["flash_used_%d" % Game.night] = true
	if Game.profiler != null:
		Game.profiler.call(&"record_flashlight_toggle")


func set_flashlight(on: bool) -> void:
	if flashlight != null and flashlight.visible != on:
		flashlight.visible = on
		if on:
			_filament_flicker_t = 0.07


## Ракетница: одна ракета — и Ырка отступает, свет держится секунд десять.
func fire_flare() -> void:
	if not Game.has_item(&"flare_gun"):
		return
	if Game.is_indoors():
		Game.hud.subtitle(Loc.t(&"sub.flare_indoors"), 2.5)
		return
	if not Game.use_flare():
		Game.hud.subtitle(Loc.t(&"sub.flare_empty"), 2.5)
		return
	if Game.hunter_brain != null:
		Game.hunter_brain.call(&"record_flare_fired", global_position)
	var f := Flare.new()
	var fwd := -camera.global_basis.z
	f.velocity = fwd * 9.0 + Vector3(0, 6.0, 0)
	Game.level.add_child(f)
	f.global_position = camera.global_position + fwd * 0.6
	Game.audio.play_2d(FLARE_SOUND, 0.0)
	shake(0.04, 0.2)
	_hands.flare()
	EventBus.flare_fired.emit(f.global_position)
	Game.hud.subtitle(Loc.t(&"sub.flare_left", [Game.flares_total()]), 2.5)


## Для рук от первого лица: фаза шага, насколько идём, держатель переносимого предмета.
func bob_phase() -> float:
	return _bob_t


func walk_amount() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / WALK_SPEED, 0.0, 1.4)


func held_root() -> Node3D:
	return _held_root


func flashlight_on() -> bool:
	return flashlight.visible


func set_held(item: StringName) -> void:
	held = item
	if _held_root == null:
		return
	for m in _held_models.values():
		if m != null:
			m.visible = false
	if item == &"":
		_held_root.visible = false
		return
	if item == &"canister":
		_held_base_pos = Vector3(0.3, -0.52, -0.44)
		_held_base_rot = Vector3(10.0, -22.0, 5.0)
		if _held_models.has(&"canister"):
			_held_models[&"canister"].visible = true
	elif item == &"oil":
		_held_base_pos = Vector3(0.28, -0.42, -0.42)
		_held_base_rot = Vector3(12.0, -18.0, 2.0)
		if _held_models.has(&"oil"):
			_held_models[&"oil"].visible = true
	elif item == &"shovel":
		_held_base_pos = Vector3(0.24, -0.42, -0.48)
		_held_base_rot = Vector3(45.0, -15.0, 5.0)
		if _held_models.has(&"shovel"):
			_held_models[&"shovel"].visible = true
	elif item == &"dog":
		_held_base_pos = Vector3(0.02, -0.5, -0.52)
		_held_base_rot = Vector3(4.0, 160.0, 0.0)
		if not _held_models.has(&"dog"):
			var mm := Dog.make_model()
			if not mm.is_empty():
				var dm: Node3D = mm[0]
				dm.scale = Vector3.ONE * 0.85
				dm.position = Vector3(0, -0.12, 0)
				_held_root.add_child(dm)
				var da: AnimationPlayer = mm[1]
				if da != null and da.has_animation(&"lie_shiver"):
					da.play(&"lie_shiver")
				FPHands.to_view_layer(dm)
				_held_models[&"dog"] = dm
		if _held_models.has(&"dog"):
			_held_models[&"dog"].visible = true
	elif item == &"trunk":
		_held_base_pos = Vector3(0.0, -0.62, -0.44)
		_held_base_rot = Vector3(16.0, 0.0, 0.0)
		if _held_models.has(&"trunk"):
			var m = _held_models[&"trunk"]
			m.scale = Vector3(0.52, 0.52, 0.52)
			m.visible = true
	elif item == &"kettle":
		_held_base_pos = Vector3(0.25, -0.42, -0.42)
		_held_base_rot = Vector3(10.0, -15.0, 0.0)
		if not _held_models.has(&"kettle"):
			var km := Props.kettle()
			km.scale = Vector3.ONE * 0.75
			_held_root.add_child(km)
			_held_models[&"kettle"] = km
			FPHands.to_view_layer(km)
		_held_models[&"kettle"].visible = true
		kettle_heat_timer = 90.0
	elif item == &"blowtorch":
		_held_base_pos = Vector3(0.24, -0.40, -0.42)
		_held_base_rot = Vector3(12.0, -10.0, 0.0)
		if not _held_models.has(&"blowtorch"):
			var bm := Props.blowtorch()
			bm.scale = Vector3.ONE * 0.9
			_held_root.add_child(bm)
			_held_models[&"blowtorch"] = bm
			FPHands.to_view_layer(bm)
		_held_models[&"blowtorch"].visible = true
	else:
		_held_base_pos = Vector3(0.22, -0.32, -0.48)
		_held_base_rot = Vector3(8.0, -12.0, 6.0)
		if _held_models.has(&"wood"):
			_held_models[&"wood"].visible = true
	_held_root.position = _held_base_pos
	_held_root.rotation_degrees = _held_base_rot
	_held_root.visible = true


func drop_held() -> void:
	if held == &"" or (Game.yard == null and held != &"trunk"):
		return
	var item := held
	# Кладём перед собой — но не сквозь стену и на тот пол, где стоим (чердак, бункер, крыльцо).
	var space := get_world_3d().direct_space_state
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var chest := global_position + Vector3(0, 0.9, 0)
	var dist := 0.7
	var q := PhysicsRayQueryParameters3D.create(chest, chest + fwd * 0.9, LAYER_WORLD)
	q.exclude = [get_rid()]
	var wall := space.intersect_ray(q)
	if not wall.is_empty():
		dist = maxf(chest.distance_to(wall["position"]) - 0.3, 0.1)
	var front := global_position + fwd * dist
	var dq := PhysicsRayQueryParameters3D.create(front + Vector3(0, 0.8, 0), front + Vector3(0, -2.5, 0), LAYER_WORLD)
	dq.exclude = [get_rid()]
	var floor_hit := space.intersect_ray(dq)
	for _i in range(4):   # пропускаем невидимые объёмы интерактивов
		if floor_hit.is_empty() or not floor_hit["collider"] is Interactable:
			break
		dq.exclude = dq.exclude + [floor_hit["rid"]]
		floor_hit = space.intersect_ray(dq)
	front.y = (floor_hit["position"] as Vector3).y if not floor_hit.is_empty() else global_position.y
	var pt = get_tree().root.find_child("PrologueTrail", true, false)
	if item == &"dog" and Dog.instance != null:
		set_held(&"")
		Dog.instance.put_down(front)
		return
	if item == &"trunk" and pt != null and pt.has_method("spawn_trunk_pickup") and Game.is_outside() and front.z < -10.0:
		pt.spawn_trunk_pickup(front)
	elif Game.yard != null:
		Game.yard.spawn_pickup(item, front)
	elif item == &"trunk" and pt != null and pt.has_method("spawn_trunk_pickup"):
		pt.spawn_trunk_pickup(front)
	set_held(&"")
	var drop_snd := "res://assets/audio/clank.ogg" if (item == &"canister" or item == &"oil" or item == &"crowbar" or item == &"shovel" or item == &"trunk") else "res://assets/audio/stove_add.ogg"
	Game.audio.play_3d(drop_snd, front + Vector3(0, 0.2, 0), -2.0)
	Game.hud.subtitle(Loc.t(&"sub.dropped_item"), 2.0)


## Переключение 3D-планшета офицера в руках
func toggle_tablet() -> void:
	if not Game.has_flag("has_tablet"):
		Game.hud.subtitle(Loc.t(&"sub.tablet_in_truck"), 3.5)
		return
	if _hands != null:
		var state := _hands.toggle_tablet()
		if state:
			Game.audio.play_2d("res://assets/audio/clank.ogg", -12.0)


## Постукивание по стеклу компаса Адрианова: стряхивает налипшую от мороза стрелку
func tap_compass() -> void:
	if _hands != null:
		_hands.reach()
		_hands.tap_compass()
	compass_stuck = move_toward(compass_stuck, 0.0, 0.7)
	compass_glitch = move_toward(compass_glitch, 0.0, 0.9)
	Game.audio.play_2d("res://assets/audio/clank.ogg", -4.0, randf_range(1.15, 1.35))
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.compass_tapped"), 2.2)


## Сцена смерти от существа: разворот к нему, падение на снег, существо нависает, удары — темнота.
func death_fall(attacker: Node3D, lean_deg := -45.0, dist := 2.0) -> void:
	mode = Mode.LOCKED
	velocity = Vector3.ZERO
	if attacker != null:
		var to := attacker.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			var yaw := atan2(-to.x, -to.z)
			create_tween().tween_property(self, "rotation:y", yaw, 0.18)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(head, "position:y", 0.28, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(head, "rotation:x", deg_to_rad(6.0), 0.55)
	tw.tween_property(camera, "rotation:z", deg_to_rad(-22.0), 0.6).set_trans(Tween.TRANS_BACK)
	await tw.finished
	shake(0.06, 0.3)
	if attacker != null:
		# Существо наваливается сверху: наклоняем его так, чтобы морда оказалась прямо перед камерой.
		var fwd := -global_basis.z
		fwd.y = 0.0
		attacker.global_position = global_position + fwd.normalized() * dist
		attacker.look_at(Vector3(global_position.x, attacker.global_position.y, global_position.z), Vector3.UP)
		attacker.rotate_object_local(Vector3.RIGHT, deg_to_rad(lean_deg))
		if attacker is CreatureRig:
			(attacker as CreatureRig).gait = 0.0
			(attacker as CreatureRig).twitch = 2.5
			(attacker as CreatureRig).pose_override = &"pin"
			var hp := (attacker as CreatureRig).pivot(&"Head")
			if hp != null:
				# Взгляд — точно в морду.
				var d := hp.global_position + Vector3(0, -0.1, 0) - camera.global_position
				var pitch := atan2(d.y, Vector2(d.x, d.z).length())
				create_tween().tween_property(head, "rotation:x", pitch, 0.12)
	for i in range(3):
		await get_tree().create_timer(0.38, false).timeout
		shake(0.12, 0.25)
		Game.hud.flash_red(0.85, 0.35)
		Game.audio.play_2d(GORE_HIT, -2.0 + i * 2.0)
	await get_tree().create_timer(0.3, false).timeout
	Game.hud.set_black(true)


## Смерть от холода: колени подгибаются, фонарь гаснет, падение набок, иней на весь экран.
func death_freeze() -> void:
	mode = Mode.LOCKED
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.9, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	flashlight.visible = false
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(head, "position:y", 0.22, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(camera, "rotation:z", deg_to_rad(85.0), 1.4)
	tw2.tween_property(head, "rotation:x", deg_to_rad(-10.0), 1.4)
	await tw2.finished
	shake(0.04, 0.3)
	await get_tree().create_timer(2.0, false).timeout
	Game.hud.set_black(true)


func shake(power: float, duration: float) -> void:
	power *= Settings.camera_shake
	_shake_power = power
	_shake_left = duration
	if Game != null:
		Game.vibrate(clampf(power * 8.0, 0.15, 0.8), clampf(power * 10.0, 0.2, 1.0), minf(duration, 0.6))


func facing_angle_to(point: Vector3) -> float:
	var to := point - camera.global_position
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg((-camera.global_basis.z).angle_to(to))


func is_looking_at(point: Vector3, max_deg: float) -> bool:
	return facing_angle_to(point) <= max_deg


## Прямая видимость до точки. Стекло (слой glass) не мешает смотреть.
func has_line_of_sight(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, point, LAYER_WORLD, [get_rid()])
	return space.intersect_ray(q).is_empty()


# --- Хелперы -----------------------------------------------------------------

func _progress_bar(t: float) -> String:
	var n := clampi(int(t * 12.0), 0, 12)
	return "[" + "■".repeat(n) + "·".repeat(12 - n) + "]"


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = AudioDirector.cached_stream(path) if not path.contains("/cc0/") else load(path)
	p.volume_db = -80.0
	p.bus = &"SFX"
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	return p


func _build_snow() -> void:
	_snow = make_snow()
	add_child(_snow)
	# Ближний слой: плотный снег вокруг головы — именно он вспыхивает в луче фонаря и у ламп.
	_snow_near = make_snow(int(380 * Settings.detail()), Vector3(5.0, 2.2, 5.0), 1.4, 2.4)
	# Ближние снежинки мельче и проявляются дальше от лица: в луче фонаря у самой камеры они
	# вспыхивали белыми кругами.
	var nq := (_snow_near.mesh as QuadMesh).duplicate() as QuadMesh
	nq.size = Vector2(0.028, 0.028)
	var nm := (nq.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	nm.distance_fade_min_distance = 1.6
	nm.distance_fade_max_distance = 3.2
	nq.material = nm
	_snow_near.mesh = nq
	add_child(_snow_near)


func _build_flash_dust() -> void:
	_flash_dust = CPUParticles3D.new()
	_flash_dust.name = "FlashlightDust"
	_flash_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_dust.amount = maxi(int(90 * Settings.detail()), 24)
	_flash_dust.lifetime = 1.6
	_flash_dust.preprocess = 0.8
	_flash_dust.local_coords = false
	_flash_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flash_dust.emission_box_extents = Vector3(0.70, 0.65, 1.8)
	_flash_dust.position = Vector3(0.0, -0.05, -2.2)
	_flash_dust.direction = Vector3(0.0, -0.15, 0.0)
	_flash_dust.spread = 180.0
	_flash_dust.initial_velocity_min = 0.06
	_flash_dust.initial_velocity_max = 0.22
	_flash_dust.damping_min = 0.1
	_flash_dust.damping_max = 0.3
	_flash_dust.gravity = Vector3(0.0, -0.04, 0.0)
	_flash_dust.scale_amount_min = 0.5
	_flash_dust.scale_amount_max = 1.3

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.12, Color(1, 1, 1, 1.0))
	ramp.add_point(0.75, Color(1, 1, 1, 0.85))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	_flash_dust.color_ramp = ramp

	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.018)
	var mat := puff_material(0.75)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.emission_enabled = false
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.45
	mat.distance_fade_max_distance = 0.95
	quad.material = mat
	_flash_dust.mesh = quad
	_flash_dust.visible = false
	camera.add_child(_flash_dust)


func _build_flashlight_beam() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 24
	var r_top := 0.04
	var r_bot := 1.45
	var z_top := -0.15
	var z_bot := -7.5
	for i in range(segs):
		var a0 := (float(i) / float(segs)) * TAU
		var a1 := (float(i + 1) / float(segs)) * TAU
		var p0_top := Vector3(cos(a0) * r_top, sin(a0) * r_top, z_top)
		var p1_top := Vector3(cos(a1) * r_top, sin(a1) * r_top, z_top)
		var p0_bot := Vector3(cos(a0) * r_bot, sin(a0) * r_bot, z_bot)
		var p1_bot := Vector3(cos(a1) * r_bot, sin(a1) * r_bot, z_bot)
		var n0 := Vector3(cos(a0), sin(a0), 0.18).normalized()
		var n1 := Vector3(cos(a1), sin(a1), 0.18).normalized()

		st.set_normal(n0)
		st.add_vertex(p0_top)
		st.set_normal(n1)
		st.add_vertex(p1_top)
		st.set_normal(n0)
		st.add_vertex(p0_bot)

		st.set_normal(n1)
		st.add_vertex(p1_top)
		st.set_normal(n1)
		st.add_vertex(p1_bot)
		st.set_normal(n0)
		st.add_vertex(p0_bot)

	var cone_mesh := st.commit()
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "VolumetricBeam"
	_beam_mesh.mesh = cone_mesh
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load("res://assets/shaders/flashlight_beam.gdshader")
	_beam_mesh.material_override = _beam_mat
	_beam_mesh.visible = false
	flashlight.add_child(_beam_mesh)


## Снег вокруг точки. Используется и игроком, и фоном меню.
static func make_snow(amount := -1, extents := Vector3(12.0, 0.5, 12.0), height := 6.0, life := 4.0) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.amount = maxi(amount if amount > 0 else int(440 * Settings.detail()), 16)
	ps.lifetime = life
	ps.preprocess = life
	ps.local_coords = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = extents
	ps.position = Vector3(0, height, 0)
	ps.direction = Vector3(0.3, -1.0, 0.1)
	ps.spread = 14.0
	ps.initial_velocity_min = 1.0
	ps.initial_velocity_max = 1.8
	ps.gravity = Vector3(0.4, -0.6, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	# Круглая снежинка с мягким краем: у самой камеры квадратный спрайт выглядел белой плашкой.
	var mat := puff_material(1.0)
	mat.albedo_color = Color(0.85, 0.87, 0.92, 0.95)
	mat.vertex_color_use_as_albedo = false
	# Освещаемый снег: в луче фонаря и у ламп вспыхивает, в темноте почти гаснет — «лучи» без конуса.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.07, 0.09)   # свет почти только чужой: снег «загорается» в луче и у окон, а не висит сам по себе
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA   # снежинка у самого лица не лепится белым диском
	mat.distance_fade_min_distance = 1.8   # в пятне фонаря снежинка в 1.5–2 м вспыхивала белым шаром
	mat.distance_fade_max_distance = 3.6
	var g := (mat.albedo_texture as GradientTexture2D).gradient
	g.add_point(0.45, Color(1, 1, 1, 1))
	quad.material = mat
	ps.mesh = quad
	return ps


func _lay_footprints() -> void:
	if not is_on_floor() or not Game.is_outside() or Game.level == null or not Terrain.ready():
		_foot_last = Vector3.INF
		return
	var gp := global_position
	var ground := Terrain.height(gp.x, gp.z)
	if gp.y - ground > 0.2:          # на крыльце, мостках, кровле — не в снегу
		_foot_last = Vector3.INF
		return
	if _foot_last == Vector3.INF:
		_foot_last = gp
		return
	var step := Vector2(gp.x - _foot_last.x, gp.z - _foot_last.z)
	_foot_acc += step.length()
	_foot_last = gp
	if _foot_acc < FOOT_STRIDE or step.length_squared() < 0.000001:
		return
	_foot_acc = 0.0
	var dir := step.normalized()
	var side := Vector2(-dir.y, dir.x) * (0.11 if _foot_left else -0.11)
	var pos := Vector3(gp.x + side.x, maxf(gp.y, ground) + 0.025, gp.z + side.y)   # над утоптанной тропой, а не под ней
	if _foot_root == null or not is_instance_valid(_foot_root):
		_foot_root = Node3D.new()
		_foot_root.name = "PlayerFootprints"
		Game.level.add_child(_foot_root)
		_foot_pool.clear()
	var fp := Footprints.make(&"snow", pos, atan2(dir.x, dir.y), _foot_left)
	fp.set_meta("life", 90.0)
	_foot_root.add_child(fp)
	_foot_pool.append(fp)
	if _foot_pool.size() > FOOT_MAX:
		var old: Node3D = _foot_pool.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_foot_left = not _foot_left

	# Заметание следов метелью за ~90 секунд
	if not _foot_pool.is_empty():
		var w_intensity: float = Game.weather.intensity if Game.weather != null else 0.5
		var sweep_rate: float = 0.20 * (1.0 + w_intensity * 0.8)
		for i in range(_foot_pool.size() - 1, -1, -1):
			var item: Node3D = _foot_pool[i]
			if not is_instance_valid(item):
				_foot_pool.remove_at(i)
				continue
			var cur_life: float = item.get_meta("life", 90.0) - sweep_rate
			if cur_life <= 0.0:
				_foot_pool.remove_at(i)
				item.queue_free()
			else:
				item.set_meta("life", cur_life)
				if cur_life < 15.0:
					item.modulate.a = clampf(cur_life / 15.0, 0.0, 1.0)
