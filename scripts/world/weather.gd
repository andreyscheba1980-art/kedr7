class_name Weather
extends Node
## Погода: затишье ↔ метель. intensity (0..1) читают туман, ветер, снег, холод и Ырка.
## В помещении тумана почти нет — иначе комната выглядит задымлённой. Днём метелей нет, туман светлый.

const FOG_INDOOR := 0.012
const FOG_CALM := 0.025   ## ясная ночь: лес уходит в тёмно-синюю дымку силуэтами, а не в белёсый туман
const FOG_BLIZZARD := 0.2
const FOG_DAY := 0.022

var intensity := 0.0
var _wind := 0.3
var blizzard := false
var is_whiteout := false            ## «Белая тьма»: видимость 1.5–2м, потеря ориентации без леера
var _aurora := 0.0
var _aurora_init := false

var _env: Environment
var _timer := 150.0
var _target := 0.0
var _ramp := 6.0                    ## за сколько секунд метель набирает силу
## Буран идёт стеной: перед началом с наветренной стороны встаёт белёсая стена и ползёт на станцию
const FRONT_TIME := 24.0
var _front := -1.0
var _wall: MeshInstance3D
var _wall_mat: ShaderMaterial
var _roar: AudioStreamPlayer


func _ready() -> void:
	Game.weather = self
	_timer = float(Game.cfg.get("first_blizzard", 150.0))


func setup(env: Environment) -> void:
	_env = env


func _process(delta: float) -> void:
	if not Game.clock_running:
		return
	if Game.is_night():
		_timer -= delta
		if _timer <= 0.0 and _front < 0.0:
			if blizzard:
				_set_blizzard(false)
			else:
				_start_front()
	_tick_front(delta)
	intensity = move_toward(intensity, _target, delta / _ramp)
	is_whiteout = blizzard and intensity > 0.82 and (Game.night >= 2 or (Game.synoptic != null and Game.synoptic.front_type == &"storm"))
	# Ветер для качания елей и флажков: масштабируется от синоптической скорости ветра
	var syn_wind_mult: float = (Game.synoptic.wind_speed / 12.0) if Game.synoptic != null else 1.0
	_wind = lerpf(_wind, (0.22 + intensity * 0.78) * clampf(syn_wind_mult, 0.4, 2.2) + sin(Time.get_ticks_msec() * 0.00031) * 0.08, minf(delta, 1.0))
	RenderingServer.global_shader_parameter_set(&"wind", _wind)

	if _env != null:
		var max_fog := FOG_BLIZZARD
		if is_whiteout:
			max_fog = 0.48
		elif Game.synoptic != null and Game.synoptic.front_type == &"fog":
			max_fog = 0.28
		elif Game.synoptic != null and Game.synoptic.front_type == &"storm":
			max_fog = 0.26
		var outdoor_fog := FOG_DAY if Game.is_daylight() else lerpf(FOG_CALM, max_fog, intensity)
		var target_fog := FOG_INDOOR if Game.is_indoors() else outdoor_fog
		_env.fog_density = lerpf(_env.fog_density, target_fog, minf(delta * 3.0, 1.0))
		# Небо затягивает: днём пасмурно, ночью — ясно до первой метели.
		if _env.sky != null and _env.sky.sky_material is ShaderMaterial:
			var base := lerpf(0.85, 0.22, clearness()) if Game.is_daylight() else 0.12
			(_env.sky.sky_material as ShaderMaterial).set_shader_parameter("cloud_amount", lerpf(base, 1.0, intensity))
			# Северное сияние в ясные ночи; с 5-й ночи — не того цвета, что бывает.
			var sky_m := _env.sky.sky_material as ShaderMaterial
			var clear := 1.0 - clampf(intensity * 2.5, 0.0, 1.0)
			var want_aurora := clear * ((1.15 if Game.night >= 5 else 0.95) if Game.is_night() and Game.night >= 1 else 0.0)
			_aurora = want_aurora if not _aurora_init else move_toward(_aurora, want_aurora, delta * 0.05)
			_aurora_init = true
			sky_m.set_shader_parameter("aurora", _aurora)
			var wrong := Game.is_night() and Game.night >= 5
			sky_m.set_shader_parameter("aurora_tint", Color(0.8, 0.1, 0.16) if wrong else Color(0.16, 0.9, 0.48))
			sky_m.set_shader_parameter("aurora_top", Color(0.25, 0.04, 0.12) if wrong else Color(0.42, 0.22, 0.62))


## Насколько ясно. Ночью — до метели. Днём — перед ночным фронтом утро ясное и морозное (антициклон),
## к вечеру небо затягивает: буря идёт; в туманный день — белёсая мгла; каждый третий день — пасмурно.
func clearness() -> float:
	var c := 1.0 - clampf(intensity * 2.5, 0.0, 1.0)
	if not Game.is_daylight():
		return c
	var front: StringName = Game.synoptic.front_type if Game.synoptic != null else &""
	if front == &"fog":
		c *= 0.25
	elif front in [&"storm", &"blizzard", &"anomaly"]:
		c *= 1.0 - smoothstep(60.0, 150.0, Game.shift_minutes) * 0.85
	if Game.night % 3 == 2:
		c *= 0.15
	return c


func force_blizzard(on: bool, duration := 40.0) -> void:
	_end_front()
	_ramp = 6.0
	_set_blizzard(on)
	_timer = duration


## Начало бурана: стена снега на горизонте с той стороны, откуда ветер. Гул нарастает.
func _start_front() -> void:
	if Game.player == null or Game.is_prologue_trail():
		_ramp = 6.0
		_set_blizzard(true)
		return
	_front = FRONT_TIME
	if _wall == null:
		_wall = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 48
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		_wall.mesh = cm
		_wall_mat = ShaderMaterial.new()
		_wall_mat.shader = load("res://assets/shaders/blizzard_wall.gdshader") as Shader
		_wall.material_override = _wall_mat
		_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Game.level.add_child(_wall)
		_roar = AudioStreamPlayer.new()
		_roar.stream = AudioDirector.cached_stream("res://assets/audio/wind_loop.ogg")
		_roar.bus = &"Weather"
		add_child(_roar)
	var az: float = deg_to_rad(Game.synoptic.wind_azimuth_deg) if Game.synoptic != null else 0.0
	_wall_mat.set_shader_parameter(&"wind_angle", az)
	_wall_mat.set_shader_parameter(&"tint", Color(0.86, 0.88, 0.92) if Game.is_daylight() else Color(0.55, 0.6, 0.7))
	_wall.visible = true
	_roar.volume_db = -36.0
	_roar.pitch_scale = 0.7
	_roar.play()
	if Game.hud != null and Game.is_outside():
		Game.hud.subtitle(Loc.t(&"sub.blizzard_front"), 4.0)


func _tick_front(delta: float) -> void:
	if _front < 0.0:
		return
	_front -= delta
	var k := 1.0 - clampf(_front / FRONT_TIME, 0.0, 1.0)      # 0 — на горизонте, 1 — накрыла
	if Game.player != null and _wall != null:
		var r := lerpf(82.0, 3.0, k * k)
		var pp := Game.player.global_position
		_wall.global_position = Vector3(pp.x, pp.y + 12.0, pp.z)
		_wall.scale = Vector3(r, 46.0, r)
		_wall_mat.set_shader_parameter(&"amount", lerpf(0.6, 1.0, k))
		if _env != null and k > 0.6 and not Game.is_indoors():
			_env.fog_density = maxf(_env.fog_density, lerpf(FOG_CALM, FOG_BLIZZARD * 0.6, (k - 0.6) / 0.4))   # мгла впереди стены
	if _roar != null:
		_roar.volume_db = lerpf(-36.0, -4.0, k)
		_roar.pitch_scale = lerpf(0.7, 1.05, k)
	if _front <= 0.0:
		_end_front()
		_ramp = 2.5          # накрыло разом
		_set_blizzard(true)
		Game.audio.play_2d("res://assets/audio/gust.ogg", 2.0)
		if Game.player != null:
			Game.player.shake(0.05, 1.2)


func _end_front() -> void:
	_front = -1.0
	if _wall != null:
		_wall.visible = false
	if _roar != null:
		_roar.stop()


func _set_blizzard(on: bool) -> void:
	if not on:
		_ramp = 6.0
	blizzard = on
	_target = 1.0 if on else 0.0
	_timer = Game.rng.randf_range(35.0, 60.0) if on else Game.rng.randf_range(100.0, 170.0)
	EventBus.blizzard_changed.emit(on)
	if on and Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.blizzard"), 3.0)
