class_name Weather
extends Node
## Погода: затишье ↔ метель. intensity (0..1) читают туман, ветер, снег, холод и Ырка.
## В помещении тумана почти нет — иначе комната выглядит задымлённой. Днём метелей нет, туман светлый.

const FOG_INDOOR := 0.012
const FOG_CALM := 0.035   ## ясная ночь: лес уходит в бирюзовую дымку силуэтами, а не в черноту
const FOG_BLIZZARD := 0.2
const FOG_DAY := 0.022

var intensity := 0.0
var _wind := 0.3
var blizzard := false
var _aurora := 0.0
var _aurora_init := false

var _env: Environment
var _timer := 150.0
var _target := 0.0


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
		if _timer <= 0.0:
			_set_blizzard(not blizzard)
	intensity = move_toward(intensity, _target, delta / 6.0)
	# Ветер для качания елей и флажков: масштабируется от синоптической скорости ветра
	var syn_wind_mult: float = (Game.synoptic.wind_speed / 12.0) if Game.synoptic != null else 1.0
	_wind = lerpf(_wind, (0.22 + intensity * 0.78) * clampf(syn_wind_mult, 0.4, 2.2) + sin(Time.get_ticks_msec() * 0.00031) * 0.08, minf(delta, 1.0))
	RenderingServer.global_shader_parameter_set(&"wind", _wind)

	if _env != null:
		var max_fog := FOG_BLIZZARD
		if Game.synoptic != null and Game.synoptic.front_type == &"fog":
			max_fog = 0.28
		elif Game.synoptic != null and Game.synoptic.front_type == &"storm":
			max_fog = 0.24
		var outdoor_fog := FOG_DAY if Game.is_daylight() else lerpf(FOG_CALM, max_fog, intensity)
		var target_fog := FOG_INDOOR if Game.is_indoors() else outdoor_fog
		_env.fog_density = lerpf(_env.fog_density, target_fog, minf(delta * 3.0, 1.0))
		# Небо затягивает: днём пасмурно, ночью — ясно до первой метели.
		if _env.sky != null and _env.sky.sky_material is ShaderMaterial:
			var base := 0.85 if Game.is_daylight() else 0.12
			(_env.sky.sky_material as ShaderMaterial).set_shader_parameter("cloud_amount", lerpf(base, 1.0, intensity))
			# Северное сияние в ясные ночи; с 5-й ночи — не того цвета, что бывает.
			var sky_m := _env.sky.sky_material as ShaderMaterial
			var clear := 1.0 - clampf(intensity * 2.5, 0.0, 1.0)
			var want_aurora := clear * ((1.15 if Game.night >= 5 else 0.85) if Game.is_night() and Game.night >= 2 else 0.0)
			_aurora = want_aurora if not _aurora_init else move_toward(_aurora, want_aurora, delta * 0.05)
			_aurora_init = true
			sky_m.set_shader_parameter("aurora", _aurora)
			var wrong := Game.is_night() and Game.night >= 5
			sky_m.set_shader_parameter("aurora_tint", Color(0.8, 0.1, 0.16) if wrong else Color(0.16, 0.9, 0.48))
			sky_m.set_shader_parameter("aurora_top", Color(0.25, 0.04, 0.12) if wrong else Color(0.42, 0.22, 0.62))


func force_blizzard(on: bool, duration := 40.0) -> void:
	_set_blizzard(on)
	_timer = duration


func _set_blizzard(on: bool) -> void:
	blizzard = on
	_target = 1.0 if on else 0.0
	_timer = Game.rng.randf_range(35.0, 60.0) if on else Game.rng.randf_range(100.0, 170.0)
	EventBus.blizzard_changed.emit(on)
	if on and Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.blizzard"), 3.0)
