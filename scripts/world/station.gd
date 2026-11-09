class_name Station
extends Node3D
## Станция «Кедр-7»: окружение, дом (комната + сени) и всё, что внутри. Двор строит Yard.
##
## План дома (вид сверху, X вправо, Z вниз):
##   комната x 0..6, сени x 6..10, z 0..5. Проём комната→сени на x=6, z 1..2.
##   Входная дверь на x=10, z 2..3 (открывается наружу). Окна: север, запад, юг (в сенях).

const SPAWN := Vector3(0.0, 0.05, 2.2)
const ROOM_H := 2.8    ## потолок стал выше — больше ощущение старого дома
const DOOR_LAMP := Vector3(14.95, 2.3, 3.1)   ## на наружной грани сруба, под навесом крыльца
const DOOR_SOUND := "res://assets/audio/door.ogg"
const CLANK_SOUND := "res://assets/audio/clank.ogg"
const STOVE_SOUND := "res://assets/audio/stove_add.ogg"

## Окна: стекло, где ставить существо снаружи (feet) и направление внутрь дома.
var window_spots: Array[Dictionary] = []
## Дверной проём из комнаты в сени — для фигуры в дверях.
var door_spot: Dictionary = {}
var env: Environment
var door_open := false
var is_backdrop := false
## Предметы, которые «сами» меняются (паранойя): id → {node, apply: Callable, changed: bool}.
var props: Dictionary = {}

var _lamps: Array[Light3D] = []
var _lit := true
var _fire: OmniLight3D
var _fire_glow: Node3D
var _t := 0.0
var _fuel_warned := false
var _door_hinge: Node3D
var _door_busy := false
var _shack_door_hinge: Node3D
var _shack_door_busy := false
var shack_door_open := false
var _vestibule_shovel: Interactable
var _gen_warm := false
var _gen_pull_count := 0
var _wind_door_timer := 65.0
var _clock_label: Label3D
var _tape_deck: Interactable
var _peephole: Interactable
var _generator: Interactable
var _barrel: Interactable
var _chimney_ice_node: Node3D
var _smoke: CPUParticles3D
var _kettle: Node3D
var _door_scratches: Node3D
var _frost_hand: Node3D
var _teapot_noticed := false
var _scratches_noticed := false
var _frost_hand_noticed := false
var _door_snow: Node3D
var _door_snow_noticed := false
var _handle_jiggle_timer := 80.0
var _window_look_timer := 0.0
var _window_face_flashed := false
var _draft_was_home := false
var _baro_warn_timer := 0.0
var _baro_dead_said := false
var _sky_light: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _post: ShaderMaterial         ## постобработка кадра (лучи от солнца и луны сквозь ели)
static var dbg_no_rays := false   ## замер FPS: лучи выключены
var _sat_t := 2.6                 ## спутник на орбите
var _sat_stop := -1.0             ## > 0 — спутник «встал» (с 5-й ночи, один раз)
var _sat_stop_at := -1.0
var _sparks: CPUParticles3D
var _wood_last := 0.0

var _front_door_slit: MeshInstance3D
var _front_door_slit_mat: StandardMaterial3D
var _living_door_hinge: Node3D
var living_door_open := false
var _living_door_busy := false
var _living_door_slit: MeshInstance3D
var _living_door_slit_mat: StandardMaterial3D
var _shack_light_slits: Array = []

## Палитра неба и тумана: 0 — пасмурный день, 1 — лунная ночь (между ними — сумерки).
const SKY_DAY := {"top_color": Color(0.42, 0.47, 0.55), "horizon_color": Color(0.63, 0.67, 0.73),
	"below_color": Color(0.5, 0.53, 0.58), "far_ridge": Color(0.52, 0.57, 0.64), "near_ridge": Color(0.38, 0.42, 0.48),
	"moon_color": Color(0.25, 0.25, 0.25)}
const SKY_NIGHT := {"top_color": Color(0.008, 0.015, 0.03), "horizon_color": Color(0.075, 0.115, 0.17),
	"below_color": Color(0.02, 0.03, 0.04), "far_ridge": Color(0.038, 0.06, 0.085), "near_ridge": Color(0.02, 0.032, 0.048),
	"moon_color": Color(0.85, 0.92, 1.0)}
## Ясный морозный день: глубокое синее небо, низкое солнце (диск — на месте «луны» в шейдере неба).
const SKY_CLEAR := {"top_color": Color(0.13, 0.27, 0.52), "horizon_color": Color(0.66, 0.74, 0.84),
	"below_color": Color(0.56, 0.62, 0.7), "far_ridge": Color(0.48, 0.58, 0.72), "near_ridge": Color(0.28, 0.36, 0.48),
	"moon_color": Color(1.0, 0.86, 0.66)}
const FOG_DAY_COL := Color(0.58, 0.61, 0.68)
const FOG_CLEAR_COL := Color(0.7, 0.76, 0.86)   ## ясно: дымка голубая, дальний лес — светлыми слоями
const FOG_NIGHT_COL := Color(0.032, 0.052, 0.08)   ## лунная дымка: дальний лес — слоями силуэтов, а не светлой стеной
## Ночь: без фонаря видно только силуэты на фоне неба, окна и огни; снег под ногами — еле-еле.
const NIGHT_AMB_COL := Color(0.03, 0.06, 0.11)
const NIGHT_AMB := 0.06
const PROLOGUE_FOG := Color(0.085, 0.115, 0.16)
const NIGHT_MOON := 0.05
const MOON_CLEAR := 0.3          ## ясная ночь: снег светится синим, от елей — чёрные тени
var _moon_gap := 1.0             ## 1 — луна открыта, 0 — ушла за тучу
var _swinging_bulb: Node3D
var _porch_bulb: Node3D
var _storm_beacon: OmniLight3D
var _beacon_prop: Node3D
var _beacon_blackout_active := false
var _woodbox_count := 2
var _woodbox_node: Node3D
var _woodbox_it: Interactable
var _kettle_cd := 0.0
var _stove_fire_player: AudioStreamPlayer3D
var _stove_crackle_player: AudioStreamPlayer3D
var _clock_player: AudioStreamPlayer3D
var _gen_sputter_player: AudioStreamPlayer3D
var _gen_engine_player: AudioStreamPlayer3D
var _underfloor_hum_player: AudioStreamPlayer
var _gen_stall_timer := 140.0
var _gen_stalled := false
var _gen_smoke: CPUParticles3D
var _window_shadow: Node3D
var _window_shadow_done := false
var _curtain_panels: Array[Node3D] = []
var _kerosene_lamp_prop: Node3D
var _kerosene_light: OmniLight3D
var _kerosene_lit := false
var _susedko_node: Node3D = null
var _susedko_timer := 45.0
var _susedko_peeking := false
var _window_wiped := false
var _wipe_it: Interactable
var _house_draft_sfx_timer := 0.0
var _creak_t := 60.0   ## дом «садится» на морозе — скрип брёвен, просто фон
var _attic_searched := false
var _attic_chest: Interactable
var _susedko_hearth: Node3D = null
var _susedko_hearth_timer := 25.0
var _treat_bread: Node3D = null          ## хлеб на блюдце у подпечья: ночью его съедают
var _treat_set_min := -1.0               ## когда поставили угощение (минуты смены)
var _treat_eaten_seen := true            ## игрок уже заметил пустое блюдце

var _clock_pendulum: Node3D
var _kettle_steam: CPUParticles3D
var _living_trunk: Node3D
var _damper_door: Node3D
var _flue_handle: Node3D
var _switch_lever: Node3D
var _stove_haze: Node3D
var _stove_haze_mat: ShaderMaterial
var _moon_windows: Array[Dictionary] = []
static var _window_cross_tex: ImageTexture



func _ready() -> void:
	if SaveGame.flags.get("new_shift", false) and not SaveGame.flags.get("new_shift_intro", false):
		SaveGame.flags["new_shift_intro"] = true
		get_tree().create_timer(3.0, false).timeout.connect(func() -> void:
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"ns.intro"), 8.0))
	var refl := WindowReflection.new()
	refl.station = self
	add_child(refl)
	Game.level = self
	_gen_stall_timer = Game.rng.randf_range(200.0, 320.0)
	Perf.mark("station start")
	_build_environment()
	Perf.mark("station _build_environment()")
	_build_house()
	Perf.mark("station _build_house()")
	_build_chimney()
	Perf.mark("station _build_chimney()")
	_build_living_quarters()
	Perf.mark("station _build_living_quarters()")
	_build_radio_room()
	Perf.mark("station _build_radio_room()")
	_build_corridor()
	Perf.mark("station _build_corridor()")
	_build_storage()
	Perf.mark("station _build_storage()")
	_build_vestibule()
	Perf.mark("station _build_vestibule()")
	_build_front_door()
	Perf.mark("station _build_front_door()")
	_build_living_door()
	Perf.mark("station _build_living_door()")
	_build_curtains()
	Perf.mark("station _build_curtains()")
	_build_attic()
	Perf.mark("station _build_attic()")
	_build_generator_shack()
	Perf.mark("station _build_generator_shack()")
	_build_storm_beacon()
	Perf.mark("station _build_storm_beacon()")
	add_child(Yard.new())
	Perf.mark("station add_child(Yard.new())")
	Dressing.build(self)
	add_child(LifeDressing.new())
	MemoryMarks.build(self)
	if Game.is_prologue() and not Game.has_flag("prologue_arrived"):
		add_child(Vehicle.new())
		var pt: Node3D = PrologueTrail.new()
		pt.name = "PrologueTrail"
		add_child(pt)
	_split_light_layers()
	_build_sun_blockers()
	Perf.mark("station _split_light_layers()")
	var amb := Ambience.new()
	amb.setup(self)
	add_child(amb)
	add_child(Crows.new())
	EventBus.power_changed.connect(_on_power_changed)
	EventBus.chimney_iced_changed.connect(_on_chimney_iced)
	EventBus.clock_minute.connect(_on_clock_minute)
	_on_chimney_iced(Game.chimney_iced)


var _last_pips_hour := -1
static var _time_pips_stream: AudioStreamWAV


func _on_clock_minute(minute: int) -> void:
	if minute > 0 and minute % 60 == 0:
		var hour := minute / 60
		if hour != _last_pips_hour:
			_last_pips_hour = hour
			_play_time_pips()


func _play_time_pips() -> void:
	if _time_pips_stream == null:
		_time_pips_stream = _generate_time_pips()
	var p := AudioStreamPlayer3D.new()
	p.stream = _time_pips_stream
	p.position = Vector3(9.2, 1.0, -1.4)
	p.bus = &"Radio"
	p.unit_size = 6.0
	p.max_distance = 25.0
	p.volume_db = 0.0
	add_child(p)
	p.play()
	Geo.free_after(p, 7.0)
	if Game.is_home():
		Game.hud.subtitle(Loc.t(&"sub.time_signals"), 5.5)


static func _generate_time_pips() -> AudioStreamWAV:
	var rate := 22050
	var freq := 1000.0
	var data := PackedByteArray()
	for _p in range(5):
		var count := int(rate * 0.1)
		for i in range(count):
			var t := float(i) / rate
			var s := sin(t * freq * TAU) * 0.45
			data.append(clampi(int(s * 127.0), -128, 127) & 0xFF)
		var pause := int(rate * 0.9)
		for _i in range(pause):
			data.append(0)
	var count6 := int(rate * 0.5)
	for i in range(count6):
		var t := float(i) / rate
		var s := sin(t * freq * TAU) * 0.55
		data.append(clampi(int(s * 127.0), -128, 127) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


var _bulb_omni: OmniLight3D
var _shadow_t := 0.0


## Тени печи и лампы коридора нужны только в доме: снаружи их не видно, а каждая — лишний проход
## теней на кадр (во дворе ~14 FPS). Раз в полсекунды включаем по месту.
func _tick_indoor_shadows(delta: float) -> void:
	_shadow_t -= delta
	if _shadow_t > 0.0:
		return
	_shadow_t = 0.5
	var inside := Game.is_indoors() or Game.player == null or Game.player.global_position.distance_to(Vector3(6.0, 1.0, 2.0)) < 14.0
	if _fire != null:
		_fire.shadow_enabled = Settings.quality >= 1 and inside
	if _bulb_omni != null:
		_bulb_omni.shadow_enabled = Settings.quality >= 2 and inside


func _process(delta: float) -> void:
	_t += delta
	_tick_creak(delta)
	_tick_indoor_shadows(delta)
	var burning := Game.stove_wood > 0.0
	if _fire != null:
		_fire.visible = burning
	if _fire_glow != null:
		_fire_glow.visible = burning
	if _smoke != null:
		_smoke.emitting = burning and not Game.chimney_iced and not Game.stove_flue
	if burning and _fire != null:
		var strength := clampf(Game.stove_wood / 40.0, 0.25, 1.0)
		if Game.stove_damper or Game.stove_flue:
			strength *= 0.45   # прикрыто — огонь тлеет, топка светит тускло
		var flick := sin(_t * 7.3) * 0.18 + sin(_t * 14.9) * 0.10 + sin(_t * 23.1) * 0.06 + (randf() - 0.5) * 0.08
		_fire.light_energy = clampf((0.72 + flick) * strength, 0.12, 1.35)
		_fire.omni_range = 3.6 * clampf(strength, 0.7, 1.15)   # дрожит яркость, не радиус: смена радиуса заново строила тени
		_fire.light_color = Color(1.0, 0.46 + sin(_t * 3.8) * 0.07, 0.14)
		if _fire_glow != null and _fire_glow.get_child_count() > 0:
			var mi := _fire_glow.get_child(0) as MeshInstance3D
			if mi != null and mi.material_override != null and mi.material_override is StandardMaterial3D:
				(mi.material_override as StandardMaterial3D).emission_energy_multiplier = 0.85 + flick * 0.5
	var target_fire_vol := -80.0
	var target_crackle_vol := -80.0
	if burning:
		var fuel_k := clampf(Game.stove_wood / 50.0, 0.0, 1.0)
		var draft_k := 0.45 if Game.stove_damper else 1.0
		if Game.stove_flue:
			draft_k = 0.2
		target_fire_vol = lerpf(-24.0, -9.0, fuel_k * draft_k)
		target_crackle_vol = lerpf(-20.0, -7.5, fuel_k * (0.75 + draft_k * 0.25))
	if _stove_fire_player != null:
		_stove_fire_player.volume_db = lerpf(_stove_fire_player.volume_db, target_fire_vol, minf(delta * 2.5, 1.0))
		_stove_fire_player.pitch_scale = 0.95 + (0.08 if not Game.stove_damper else -0.05)
	if _stove_crackle_player != null:
		_stove_crackle_player.volume_db = lerpf(_stove_crackle_player.volume_db, target_crackle_vol, minf(delta * 2.5, 1.0))
	if _stove_haze != null:
		_stove_haze.visible = burning
		if burning and _stove_haze_mat != null:
			var haze_k := clampf(Game.stove_wood / 30.0, 0.35, 1.0)
			_stove_haze_mat.set_shader_parameter(&"distortion_strength", 0.009 * haze_k)

	# Лунный свет через окна: серебристо-голубые проекции рам на полу в тёмных комнатах
	var is_night_time := not Game.is_daylight()
	var house_dark := not lights_lit()
	var base_moon_a := (0.36 if house_dark else 0.06) if is_night_time else 0.0
	var moon_flicker := 1.0 + sin(_t * 0.75) * 0.05
	for mw: Dictionary in _moon_windows:
		var mp: MeshInstance3D = mw["proj"]
		var ms: MeshInstance3D = mw["shaft"]
		var mat_p: StandardMaterial3D = mw["mat_proj"]
		var mat_s: ShaderMaterial = mw["mat_shaft"]
		var cur_a: float = mat_p.albedo_color.a
		var target_a: float = base_moon_a * moon_flicker
		var new_a: float = move_toward(cur_a, target_a, delta * 1.2)
		mat_p.albedo_color.a = new_a
		if mat_s != null:
			mat_s.set_shader_parameter(&"color", Color(0.20, 0.36, 0.62, new_a * 0.55))
		mp.visible = new_a > 0.01
		ms.visible = new_a > 0.01

	# Тёплые полоски света из-под дверей (щели под входной дверью и дверью в жилую)
	var house_has_light := lights_lit() or burning
	if _front_door_slit != null and _front_door_slit_mat != null:
		var show_front := not door_open and house_has_light and not Game.is_daylight()
		_front_door_slit.visible = show_front
		if show_front:
			var flick := 1.0 + (sin(_t * 7.3) * 0.08 if burning and not lights_lit() else 0.0)
			_front_door_slit_mat.albedo_color.a = clampf(0.82 * flick, 0.0, 1.0)

	if _living_door_slit != null and _living_door_slit_mat != null:
		var show_living := not living_door_open and house_has_light
		_living_door_slit.visible = show_living
		if show_living:
			var flick := 1.0 + (sin(_t * 7.3) * 0.08 if burning and not lights_lit() else 0.0)
			_living_door_slit_mat.albedo_color.a = clampf(0.85 * flick, 0.0, 1.0)

	# Мерцающий свет в сарае/будке генератора сквозь щели стен
	var gen_running := Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0
	for sd: Dictionary in _shack_light_slits:
		var mi: MeshInstance3D = sd["mesh"]
		var smat: StandardMaterial3D = sd["mat"]
		var base_a: float = sd["base_a"]
		mi.visible = gen_running
		if gen_running:
			var gflick := clampf(0.78 + sin(_t * 31.0) * 0.16 + sin(_t * 67.0) * 0.08 + (randf() - 0.5) * 0.08, 0.2, 1.15)
			smat.albedo_color.a = clampf(base_a * gflick, 0.0, 1.0)

	if _gen_engine_player != null:
		var target_eng_vol := -80.0
		if gen_running:
			target_eng_vol = -5.5
			if not shack_door_open:
				target_eng_vol -= 5.0
			if Game.generator_fuel < 15.0:
				target_eng_vol += sin(_t * 14.0) * 1.5
				_gen_engine_player.pitch_scale = 1.02 + sin(_t * 11.0) * 0.05
			else:
				_gen_engine_player.pitch_scale = 1.02
		_gen_engine_player.volume_db = lerpf(_gen_engine_player.volume_db, target_eng_vol, minf(delta * 4.0, 1.0))

	if _underfloor_hum_player != null:
		var target_uf_vol := -80.0
		if gen_running and Game.is_home():
			target_uf_vol = -24.0
		_underfloor_hum_player.volume_db = lerpf(_underfloor_hum_player.volume_db, target_uf_vol, minf(delta * 2.0, 1.0))

	if _swinging_bulb != null:
		_swinging_bulb.rotation.z = sin(_t * 1.35) * 0.16 + sin(_t * 2.1) * 0.05
		_swinging_bulb.rotation.x = cos(_t * 1.1) * 0.12 + sin(_t * 1.7) * 0.04
	if _porch_bulb != null:
		var w_str: float = 0.6 + (Game.weather.intensity * 1.4 if Game.weather != null else 0.0)
		_porch_bulb.rotation.z = (sin(_t * 2.3) * 0.18 + sin(_t * 4.1) * 0.06) * w_str
		_porch_bulb.rotation.x = (cos(_t * 1.7) * 0.14 + sin(_t * 3.3) * 0.05) * w_str
	_process_lamp_sag(delta)
	if _clock_pendulum != null:
		_clock_pendulum.rotation.z = sin(Time.get_ticks_msec() * 0.00314159) * deg_to_rad(14.0)
	if _kettle_steam != null:
		_kettle_steam.emitting = burning or not Game.is_prologue()
	_update_living_trunk_visibility()
	if _storm_beacon != null and outside_lit() and not _beacon_blackout_active:
		_storm_beacon.visible = true
		_storm_beacon.light_energy = 1.7 + sin(_t * 3.0) * 0.65 + (randf() * 0.12)
	elif _storm_beacon != null:
		_storm_beacon.visible = false
	if _gen_smoke != null:
		_gen_smoke.emitting = Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0
	if is_backdrop:
		return   # фон главного меню: только картинка, никаких событий смены (HUD нет)
	# Заглохание — только ночью и не чаще пары раз за смену (правило журнала: «генератор капризный, но не каждый час»).
	if Game.is_night() and Game.clock_running and Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0 and not Game.is_prologue():
		_gen_stall_timer -= delta
		var scripted := Game.events != null and (Game.events.knocking or Game.events.paralysis) \
			or (Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE)
		if _gen_stall_timer <= 0.0 and scripted:
			_gen_stall_timer = 30.0   # не гасим свет посреди стука, паралича или погони
		elif _gen_stall_timer <= 0.0:
			_gen_stall_timer = Game.rng.randf_range(300.0, 460.0)
			_trigger_generator_stall()
	if _kettle_cd > 0.0:
		_kettle_cd -= delta
	if not props.get("clock", {}).get("changed", false):
		var ct := Game.clock_text()
		if _clock_label != null and _clock_label.text != ct:
			_clock_label.text = ct

	# Дом остывает, когда печь погасла, и прогревается, когда горит: иней на окнах и пар изо рта в комнате.
	if not is_backdrop and Game.clock_running:
		var heating := Game.stove_wood > 0.0
		Game.house_cold = clampf(Game.house_cold + delta * (-1.0 / 70.0 if heating else 1.0 / 160.0), 0.0, 1.0)
		var cov := lerpf(0.22, 0.92, Game.house_cold) + (0.08 if Game.is_night() else 0.0)
		if absf(cov - _frost_cov) > 0.004 and _frost_mat != null:
			_frost_cov = move_toward(_frost_cov, cov, delta * 0.05)
			_frost_mat.set_shader_parameter(&"coverage", _frost_cov)

	# Барограф М-22 как сейсмо-детектор аномалий и скачков давления
	if Game.is_night() and not is_backdrop:
		var yrka_near: bool = Game.yrka != null and is_instance_valid(Game.yrka) and Game.yrka.stage in [YrkaThreat.Stage.STALKING, YrkaThreat.Stage.CALLING, YrkaThreat.Stage.PRESSURE, YrkaThreat.Stage.CHASE]
		if Director.tension > 62.0 or yrka_near:
			_baro_warn_timer -= delta
			if _baro_warn_timer <= 0.0:
				_baro_warn_timer = Game.rng.randf_range(25.0, 42.0)
				if Game.barograph_live():
					AudioDirector.play_raw("res://assets/sfx/scratch_wall.ogg", 0.0)
					if Game.is_home():
						Game.hud.subtitle(Loc.t(&"sub.barograph_warning"), 4.0)
						Hints.show(&"barograph")
				elif Game.is_home() and not _baro_dead_said:
					# Барограф встал — и молчит именно тогда, когда должен был заскрежетать.
					_baro_dead_said = true
					Game.hud.subtitle(Loc.t(&"sub.barograph_dead"), 4.5)
		else:
			_baro_warn_timer = minf(_baro_warn_timer, 6.0)

		# Расход завода пружины: хватает примерно до 02:30 (~10 мин) — раз за ночь надо подойти и завести.
		Game.barograph_wound = maxf(Game.barograph_wound - delta * 0.165, 0.0)
		if Game.barograph_live():
			_baro_dead_said = false

	# День: пасмурно или ясно (низкое тёплое солнце, синее небо, длинные голубые тени); к 17:30 — сумерки
	if Game.is_daylight() and _sky_light != null and env != null:
		var t_dusk := clampf((Game.shift_minutes - 120.0) / 100.0, 0.0, 1.0)
		var clear: float = Game.weather.clearness() if Game.weather != null else 0.0
		env.background_color = Color(0.4, 0.43, 0.5).lerp(Color(0.055, 0.155, 0.235), t_dusk)
		env.ambient_light_color = Color(0.55, 0.6, 0.7).lerp(Color(0.46, 0.56, 0.8), clear).lerp(NIGHT_AMB_COL, t_dusk)
		env.ambient_light_energy = lerpf(lerpf(0.75, 0.62, clear), NIGHT_AMB, t_dusk)
		_apply_sky_tint(t_dusk, clear)
		_sky_light.light_color = Color(0.85, 0.85, 0.9).lerp(Color(1.0, 0.84, 0.64), clear).lerp(Color(1.0, 0.55, 0.35), clear * smoothstep(0.3, 0.8, t_dusk)).lerp(Color(0.58, 0.72, 0.92), smoothstep(0.75, 1.0, t_dusk))
		_sky_light.light_energy = lerpf(lerpf(0.45, 2.1, clear), NIGHT_MOON, t_dusk)
		# Зимнее солнце низко: к вечеру садится к хребтам — тени через весь двор
		_sky_light.rotation_degrees = Vector3(lerpf(-25.0, lerpf(-21.0, -6.0, t_dusk), clear), lerpf(40.0, 60.0, t_dusk), 0.0)

	_update_rays()
	_update_sky_life(delta)

	# Медленное покачивание лунного света на ветру (±1–2°): тени вековых елей и построек тягуче ползут по снегу
	if not Game.is_daylight() and _sky_light != null:
		var w_intensity: float = Game.weather.intensity if Game.weather != null else 0.0
		var w_scale := 1.0 + w_intensity * 0.85
		var sway_y := (sin(_t * 0.32) * 1.5 + sin(_t * 0.68) * 0.65) * w_scale
		var sway_x := (cos(_t * 0.24) * 0.8 + sin(_t * 0.53) * 0.35) * w_scale
		_sky_light.rotation_degrees = Vector3(-32.0 + sway_x, -135.0 + sway_y, 0.0)
		# Ясно — луна светит в полную, снег светится, от елей тени; тучи то и дело закрывают её — и темно
		if not Game.is_prologue_trail():
			var clear_n := 1.0 - clampf(w_intensity * 2.5, 0.0, 1.0)
			var cov := sin(_t * 0.021) * 0.6 + sin(_t * 0.057 + 1.3) * 0.4
			var gap_want := 1.0 - smoothstep(0.35, 0.75, cov) * 0.85
			_moon_gap = move_toward(_moon_gap, gap_want, delta * 0.08)
			var moon := clear_n * _moon_gap
			_sky_light.light_energy = lerpf(NIGHT_MOON, MOON_CLEAR, moon)
			env.ambient_light_energy = lerpf(NIGHT_AMB, NIGHT_AMB + 0.015, moon)
			if _sky_mat != null:
				_sky_mat.set_shader_parameter("moon_cover", 1.0 - _moon_gap)

	if _tape_deck != null:
		var has_deck := Game.has_item(&"tape_recorder")   # стоит на столе только когда его нашли
		_tape_deck.visible = has_deck
		_tape_deck.collision_layer = Geo.LAYER_WORLD if has_deck else 0
	if _generator != null:
		if Game.player != null and Game.player.held == &"canister":
			_generator.hold_time = 2.5
			_generator.hold_sound = "res://assets/audio/stove_add.ogg"
		elif Game.gen_broken and Game.has_item(&"tools"):
			_generator.hold_time = 5.0
			_generator.hold_sound = CLANK_SOUND
		elif not Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0:
			_generator.hold_time = 1.2
			_generator.hold_sound = "res://assets/audio/generator_sputter.ogg"
		else:
			_generator.hold_time = 0.0
			_generator.hold_sound = ""
	if _barrel != null:
		_barrel.hold_time = 3.0 if Game.final_call else 0.0
	if _peephole != null:
		_peephole.collision_layer = 0 if door_open else Geo.LAYER_WORLD

	# Ледяные порывы ветра могут распахнуть входную дверь во время ночной метели
	if Game.is_night() and not door_open and not _door_busy and not is_backdrop and not Game.is_prologue():
		var storm_active := Game.weather != null and Game.weather.intensity > 0.4
		if storm_active:
			_wind_door_timer -= delta
			if _wind_door_timer <= 0.0:
				_wind_door_timer = Game.rng.randf_range(75.0, 140.0)
				if Game.rng.randf() < 0.6:
					_trigger_wind_door_burst()

	# Загустение солярки на морозе: дизель задыхается, свет моргает
	if Game.fuel_sputter and Game.power_on:
		if _gen_sputter_player != null and not _gen_sputter_player.playing:
			_gen_sputter_player.play()
		if randf() < delta * 0.8:   # реже: это сигнал «иди к ГСМ», а не стробоскоп
			_brownout()
		# Густая солярка: дизель задыхается и заглохнет сам, если не продуть фильтр в сарае
		_gen_stall_timer = minf(_gen_stall_timer, 75.0)
	else:
		if _gen_sputter_player != null and _gen_sputter_player.playing:
			_gen_sputter_player.stop()

	# Отражение за плечом в окне радиорубки (психологический ужас)
	if not _window_shadow_done and Game.is_night() and Game.after_hour(2) and Game.zone == &"radio_room":
		if Game.player != null and Game.player.is_looking_at(Vector3(9.2, 1.45, -2.0), 35.0) \
				and Game.player.has_line_of_sight(Vector3(9.2, 1.45, -1.9)):
			_window_shadow_done = true
			if _window_shadow != null:
				_window_shadow.visible = true
			Game.audio.play_3d("res://assets/audio/whisper.ogg", Vector3(9.2, 1.45, -2.0), 0.0, 6.0)
			Game.hud.subtitle(Loc.t(&"sub.window_reflection"), 3.5)
			Director.add_tension(12.0, "силуэт в окне")
			var tree := get_tree()
			if tree != null:
				tree.create_timer(1.6).timeout.connect(func():
					if is_instance_valid(_window_shadow):
						_window_shadow.visible = false
				)

	# Мало топлива — лампы подрагивают. И предупреждение, и атмосфера.
	if Game.power_on and _lit and Game.generator_fuel < 20.0 and Game.clock_running:
		if not _fuel_warned:
			_fuel_warned = true
			Game.hud.subtitle(Loc.t(&"sub.lights_flicker"), 4.0)
		if randf() < delta * 0.9:
			_brownout()
	elif Game.generator_fuel >= 20.0:
		_fuel_warned = false

	# Проверка паранойи / следов Ырки
	if Game.player != null:
		var p_pos := Game.player.global_position
		# Чайник переместился на стол
		if not _teapot_noticed and props.get("teapot", {}).get("changed", false) and _kettle != null:
			if p_pos.distance_to(_kettle.global_position) < 3.2 and Game.player.is_looking_at(_kettle.global_position, 45.0):
				_teapot_noticed = true
				Game.hud.subtitle(Loc.t(&"sub.teapot_moved"), 4.0)
				Game.add_fatigue(3.0)
				Director.add_tension(6.0, "чайник сам переместился")
		# Царапины на двери
		if not _scratches_noticed and _door_scratches != null and _door_scratches.visible:
			if p_pos.x > 12.8 and p_pos.distance_to(_door_scratches.global_position) < 3.2 and Game.player.is_looking_at(_door_scratches.global_position, 55.0):
				_scratches_noticed = true
				Game.hud.subtitle(Loc.t(&"sub.door_scratches"), 4.0)
				Director.add_tension(8.0, "царапины на двери")
		# След на северном окне
		if not _frost_hand_noticed and _frost_hand != null and _frost_hand.visible:
			if p_pos.z < 2.0 and p_pos.distance_to(_frost_hand.global_position) < 2.6 and Game.player.is_looking_at(_frost_hand.global_position, 40.0):
				_frost_hand_noticed = true
				Game.hud.subtitle(Loc.t(&"sub.frost_hand"), 4.0)
				Director.add_tension(10.0, "след ладони на стекле")
		# Проверка снега у двери в тамбуре
		if not _door_snow_noticed and _door_snow != null and _door_snow.visible:
			if p_pos.x > 11.0 and p_pos.distance_to(_door_snow.global_position) < 2.5:
				_door_snow_noticed = true
				Game.hud.subtitle(Loc.t(&"sub.door_ajar"), 4.0)
				Director.add_tension(6.0, "снег в тамбуре")
		# Проверка окна: память директора (если игрок часто всматривается)
		if _frost_hand != null and p_pos.z < 2.0 and p_pos.distance_to(_frost_hand.global_position) < 2.5 and Game.player.is_looking_at(_frost_hand.global_position, 40.0):
			_window_look_timer += delta
			if _window_look_timer > 1.2:
				_window_look_timer = 0.0
				var wkey := "window_checks_%d" % Game.night   # счёт взглядов — свой на каждую ночь (правило 3)
				var cnt: int = int(SaveGame.flags.get(wkey, 0)) + 1
				SaveGame.flags[wkey] = cnt
				if cnt >= 4 and Game.is_night() and Game.night >= 3 and not _window_face_flashed \
						and not Game.has_flag("window_face_" + str(Game.night)):
					Game.set_flag("window_face_" + str(Game.night), true)
					_window_face_flashed = true
					_flash_window_face()

	# Подёргивание ручки входной двери
	if Game.is_night() and Game.night >= 3 and not door_open:
		_handle_jiggle_timer -= delta
		if _handle_jiggle_timer <= 0.0:
			_handle_jiggle_timer = randf_range(80.0, 160.0)
			jiggle_door_handle()

	# Колыхание занавесок от сквозняка / ветра
	if not _curtain_panels.is_empty():
		var sway_base := sin(_t * 1.6) * 0.03
		if door_open:
			var storm_factor := 1.0 + (Game.weather.intensity if Game.weather != null else 0.0) * 1.8
			sway_base += sin(_t * 4.2) * 0.16 * storm_factor + (randf() * 0.02)
		# Только от стены в комнату (отрицательный угол): иначе низ шторы уходил в раму и стену
		var sway := -clampf(absf(sway_base), 0.0, 0.22)
		for panel: Node3D in _curtain_panels:
			if is_instance_valid(panel):
				panel.rotation.x = sway

	# Мерцание керосиновой лампы
	if _kerosene_lit and _kerosene_light != null:
		_kerosene_light.light_energy = 1.1 + sin(_t * 8.5) * 0.08 + randf() * 0.05

	# Выстуживание дома при открытой наружной двери
	if door_open and Game.is_night():
		var draft_rate := delta * 0.9 * (1.0 + (Game.weather.intensity if Game.weather != null else 0.0))
		Game.add_cold(draft_rate)
		_house_draft_sfx_timer -= delta
		# Напоминание — сразу, как вернулся в дом, и дальше каждые 20 с (ночи 6–7: Ырка войдёт через 25 с).
		var home_now := Game.is_home()
		if home_now and not _draft_was_home:
			_house_draft_sfx_timer = 0.0
		_draft_was_home = home_now
		if _house_draft_sfx_timer <= 0.0 and home_now:
			_house_draft_sfx_timer = 20.0
			Game.hud.subtitle(Loc.t(&"sub.door_draft"), 3.5, 2)

	# Суседко (Тень)
	_process_susedko(delta)


# --- API для систем ----------------------------------------------------------

func is_pos_inside_house(pos: Vector3) -> bool:
	if pos.y < -0.8 or pos.y > 5.5:
		return false
	# Чердак
	if pos.y >= 2.8 and pos.x >= -2.6 and pos.x <= 14.6 and pos.z >= 0.0 and pos.z <= 6.6:
		return true
	# Жилая комната
	if pos.x >= -2.6 and pos.x <= 3.6 and pos.z >= -0.1 and pos.z <= 6.7:
		return true
	# Радиорубка
	if pos.x >= 3.4 and pos.x <= 11.6 and pos.z >= -2.1 and pos.z <= 2.3:
		return true
	# Холодная кладовая
	if pos.x >= 3.4 and pos.x <= 7.1 and pos.z >= -5.6 and pos.z <= -1.9:
		return true
	# Г-образный коридор
	if pos.x >= 3.4 and pos.x <= 11.6 and pos.z >= 2.1 and pos.z <= 6.7:
		return true
	# Прихожая-тамбур
	if pos.x >= 11.4 and pos.x <= 14.6 and pos.z >= 1.4 and pos.z <= 6.7:
		return true
	return false


## Солнце и луна в дом не светят (у них слой «снаружи»), но стены сруба — общие коробки на обе стороны и
## живут в слое «снаружи». На стыках стен и под кровлей тень «пробивала», и ясным днём по стенам и потолку
## изнутри шли оранжевые клинья — дом казался собранным со щелями. Внутри каждой комнаты — невидимый короб,
## который только отбрасывает тень (слой «снаружи» — его видит лишь небесный свет): внутрь солнце не попадёт.
const SUN_BLOCK_ROOMS := [
	[Vector3(-2.6, 0.0, -0.1), Vector3(3.6, 0.0, 6.7)],      # жилая
	[Vector3(3.4, 0.0, -2.1), Vector3(11.6, 0.0, 2.3)],      # рубка
	[Vector3(3.4, 0.0, -5.6), Vector3(7.1, 0.0, -1.9)],      # кладовая
	[Vector3(3.4, 0.0, 2.1), Vector3(11.6, 0.0, 6.7)],       # коридор
	[Vector3(11.4, 0.0, 1.4), Vector3(14.6, 0.0, 6.7)],      # сени
]


func _build_sun_blockers() -> void:
	for r: Array in SUN_BLOCK_ROOMS:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var size := Vector3(b.x - a.x - 0.24, ROOM_H - 0.08, b.z - a.z - 0.24)
		var bm := BoxMesh.new()
		bm.size = size
		var mi := MeshInstance3D.new()
		mi.name = "SunBlocker"
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.layers = LAYER_OUT
		add_child(mi)
		mi.position = Vector3((a.x + b.x) * 0.5, 0.04 + size.y * 0.5, (a.z + b.z) * 0.5)


const LAYER_OUT := 2      ## визуальный слой «снаружи дома»
const LAYER_IN := 4       ## визуальный слой «внутри дома»

## Без теней точечный свет проходит сквозь стены: лампы комнат светили на сруб и снег снаружи,
## фонарь крыльца — в сени. Делим геометрию на «внутри» и «снаружи» (по габаритам целиком),
## а лампы светят только своей стороне. Свободные предметы и существа остаются в общем слое.
## Живое применение пресета графики (без перестройки сцены): тени луны/солнца, свечение.
func apply_quality() -> void:
	if _sky_light != null:
		_sky_light.shadow_enabled = Settings.quality >= 1
	if env != null:
		env.glow_enabled = Settings.quality >= 1


func _split_light_layers() -> void:
	var stack: Array[Node] = [self]
	var n_in := 0
	var n_out := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is Light3D:
			var l := n as Light3D
			if l is DirectionalLight3D:
				continue
			var lp := l.global_position
			if lp.y >= 2.8 and is_pos_inside_house(lp):
				continue            # чердак: его лампа светит и на изнанку крыши, а она — «снаружи»
			l.light_cull_mask = (1 | LAYER_IN) if is_pos_inside_house(lp) else (1 | LAYER_OUT)
			# Тени — тоже только от своей стороны: иначе фонарь крыльца перерисовывал в 6 гранях
			# куба всю обстановку дома (её всё равно закрывает сруб) — минус ~450 вызовов в кадре
			l.shadow_caster_mask = l.light_cull_mask
		elif n is GeometryInstance3D:
			var g := n as GeometryInstance3D
			var bb := g.global_transform * g.get_aabb()
			var inside := true
			for i in 8:
				if not is_pos_inside_house(bb.get_endpoint(i)):
					inside = false
					break
			g.layers = LAYER_IN if inside else LAYER_OUT
			# Мелочь снаружи (сосульки, флажки, шапки снега, верёвки, гвозди) тень не отбрасывает:
			# её тень в пару пикселей не видна, а каждая — отдельный вызов в каждом каскаде и грани куба
			var dims := [bb.size.x, bb.size.y, bb.size.z]
			dims.sort()
			if not inside and (dims[2] < 0.45 or dims[1] < 0.1):   # мелочь и тонкие линии (леера, провода)
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if inside:
				n_in += 1
			else:
				n_out += 1
	if OS.is_debug_build():
		print("[layers] inside %d, outside %d" % [n_in, n_out])


func zone_at(pos: Vector3) -> StringName:
	if pos.y >= 2.8 and pos.x >= -2.6 and pos.x <= 14.6 and pos.z >= 0.0 and pos.z <= 6.6:
		return &"attic"
	if pos.y < -5.0:
		if Game.yard != null:
			return Game.yard.zone_at(pos)
		return &"yard"
	if pos.x >= -2.6 and pos.x <= 3.6 and pos.z >= -0.1 and pos.z <= 6.7:
		return &"room"
	if pos.x >= 3.4 and pos.x <= 11.6 and pos.z >= -2.1 and pos.z <= 2.3:
		return &"radio_room"
	if pos.x >= 3.4 and pos.x <= 7.1 and pos.z >= -5.6 and pos.z <= -1.9:
		return &"storage"
	if pos.x >= 3.4 and pos.x <= 11.6 and pos.z >= 2.1 and pos.z <= 6.7:
		return &"corridor"
	if pos.x >= 11.4 and pos.x <= 14.6 and pos.z >= 1.4 and pos.z <= 6.7:
		return &"vestibule"
	if pos.x >= 12.8 and pos.x <= 16.2 and pos.z >= -15.2 and pos.z <= -11.8:
		return &"gen_shack"
	if Game.yard != null:
		return Game.yard.zone_at(pos)
	return &"yard"



func kerosene_on() -> bool:
	return _kerosene_lit


## Свет в доме: есть ток и рубильник у двери не выключен.
func lights_lit() -> bool:
	return _lit and Game.power_on and not Game.house_switch_off


## Свет снаружи (крыльцо, маяк, сарай): от рубильника дома не зависит.
func outside_lit() -> bool:
	return _lit and Game.power_on


func _lamp_on(l: Light3D, base: bool) -> bool:
	if not base:
		return false
	return not Game.house_switch_off or not is_pos_inside_house(l.global_position)


## Свет, питающийся от генератора (дом, фонарь у двери, сарай). Двор регистрирует свои лампы сюда.
func register_lamp(l: Light3D) -> void:
	_lamps.append(l)
	l.visible = _lamp_on(l, outside_lit())


func set_lit(on: bool) -> void:
	_lit = on
	_apply_lamps()


func _apply_lamps() -> void:
	var on := outside_lit()
	for l in _lamps:
		l.visible = _lamp_on(l, on)


## Мигание света. Корутина — испуги ждут её через await.
func flicker(duration: float) -> void:
	var t := 0.0
	while t < duration:
		var on := randf() > 0.45 and Game.power_on
		for l in _lamps:
			l.visible = _lamp_on(l, on)
		var step := randf_range(0.04, 0.16)
		await get_tree().create_timer(step, false).timeout
		t += step
	_apply_lamps()


## «Живой» свет: изредка одна лампа в доме чуть проседает и возвращается — дизель тянет нагрузку.
## Не чаще раза в 40–110 с, никогда две сразу и не во время мигания/испугов.
var _sag_t := 60.0
var _sagging := false

func _process_lamp_sag(delta: float) -> void:
	if _sagging or not lights_lit():
		return
	_sag_t -= delta
	if _sag_t > 0.0:
		return
	_sag_t = randf_range(40.0, 110.0)
	var pool: Array[Light3D] = []
	for l in _lamps:
		if is_instance_valid(l) and l.visible and (l is OmniLight3D or l is SpotLight3D) and l.light_energy > 0.3 and is_pos_inside_house(l.global_position):
			pool.append(l)
	if pool.is_empty():
		return
	var lamp: Light3D = pool.pick_random()
	if not lamp.has_meta(&"base_e"):
		lamp.set_meta(&"base_e", lamp.light_energy)
	var base: float = lamp.get_meta(&"base_e")
	_sagging = true
	var tw := create_tween()
	tw.tween_property(lamp, "light_energy", base * randf_range(0.45, 0.65), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(randf_range(0.2, 0.7))
	if randf() < 0.35:   # иногда — второй, короткий провал
		tw.tween_property(lamp, "light_energy", base * 0.85, 0.12)
		tw.tween_property(lamp, "light_energy", base * 0.55, 0.1)
	tw.tween_property(lamp, "light_energy", base, 0.45).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(func() -> void: _sagging = false)


func _brownout() -> void:
	for l in _lamps:
		l.visible = false
	await get_tree().create_timer(randf_range(0.05, 0.12), false).timeout
	_apply_lamps()


func _on_power_changed(on: bool) -> void:
	_apply_lamps()
	if on:
		_gen_stall_timer = Game.rng.randf_range(300.0, 460.0)   # только что завели/залили/починили — не глохнет сразу
	if not on and Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.gen_died"), 3.0)


func _on_chimney_iced(iced: bool) -> void:
	if is_instance_valid(_chimney_ice_node):
		_chimney_ice_node.visible = iced


## Паранойя: меняет один ещё не изменённый предмет, если игрок его сейчас не видит.
func change_random_prop() -> bool:
	if Game.anomalies != null:
		return Game.anomalies.trigger_random(&"house")
	var ids: Array = props.keys()
	ids.shuffle()
	for id: String in ids:
		var p: Dictionary = props[id]
		if p["changed"]:
			continue
		var node: Node3D = p["node"]
		if Game.player != null and Game.player.is_looking_at(node.global_position, 70.0) \
				and Game.player.global_position.distance_to(node.global_position) < 12.0:
			continue
		(p["apply"] as Callable).call()
		p["changed"] = true
		return true
	return false


func prop_changed(id: String) -> bool:
	return bool(props.get(id, {}).get("changed", false))


# --- Окружение ---------------------------------------------------------------

func _build_environment() -> void:
	var day := Game.is_daylight()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.43, 0.5) if day else Color(0.055, 0.155, 0.235)
	# Небо — шейдер: светящийся горизонт, луна, звёзды, гранёные хребты. Задник даёт глубину кадру.
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://assets/shaders/night_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_sky_affect = 0.12
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7) if day else NIGHT_AMB_COL
	env.ambient_light_energy = 0.75 if day else (0.1 if Game.is_prologue_trail() else NIGHT_AMB)   # пролог: темно, но силуэты елей и снег читаются
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.61, 0.68) if day else FOG_NIGHT_COL
	env.fog_density = Weather.FOG_INDOOR

	# Кинематографичный тонемаппинг Filmic и выверенная палитра (-35% насыщенности)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	_apply_sky_tint(0.0 if day else 1.0)
	if Game.is_prologue_trail():
		env.fog_light_color = PROLOGUE_FOG   # дымка светлее леса: ели встают силуэтами, а не тонут в черноте
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85   # бирюза ночи и оранжевый свет окон должны оставаться цветом, а не серостью
	env.adjustment_contrast = 1.18
	# Мягкое свечение огней: лампы, окна, фонарь, маяк — ореол вокруг светлого (кроме низкого пресета).
	env.glow_enabled = Settings.quality >= 1
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.72
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_sky_light = DirectionalLight3D.new()
	_sky_light.light_color = Color(0.85, 0.85, 0.9) if day else Color(0.58, 0.72, 0.92)
	_sky_light.light_energy = 0.45 if day else (0.12 if Game.is_prologue_trail() else NIGHT_MOON)
	_sky_light.rotation_degrees = Vector3(-25.0, 40.0, 0.0) if day else Vector3(-32.0, -135.0, 0.0)   # луна на северо-западе, над лесом за домом
	# Тени луны ночью почти не видны (свет 0.08 против фонаря и окон), а стоят ещё 2 прохода всей сцены.
	# Ночью — только на высоком пресете; днём солнце даёт заметные тени — со среднего.
	_sky_light.shadow_enabled = Settings.quality >= 1   # тени елей от луны на снегу — главная красота ночи
	_sky_light.light_cull_mask = 1 | LAYER_OUT   # в дом луна не светит и без теней: внутренность — свой слой
	# И тени солнца/луны отбрасывает только наружная геометрия. Раньше вся обстановка дома (сотни
	# предметов) шла в каскады теней, как только дом попадал в кадр: ~1100 лишних вызовов, просадка FPS
	_sky_light.shadow_caster_mask = 1 | LAYER_OUT
	# 4 каскада — только «Ультра»: каждый каскад — ещё один проход всей наружной сцены
	_sky_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if Settings.quality < 3 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sky_light.directional_shadow_max_distance = 30.0 if Settings.quality < 2 else (40.0 if Settings.quality == 2 else 140.0)
	_sky_light.shadow_bias = 0.04
	add_child(_sky_light)

	var weather := Weather.new()
	add_child(weather)
	weather.setup(env)


## Ночное небо живёт: спутник ползёт по дуге; с 5-й ночи однажды встаёт посреди неба и мигает красным.
## Труба: дым гуще, когда подкинул дров; в сильный огонь ночью — искры.
func _update_sky_life(delta: float) -> void:
	if _sky_mat != null:
		var night := not Game.is_daylight()
		_sky_mat.set_shader_parameter(&"sat_on", 1.0 if night else 0.0)
		if night:
			if _sat_stop_at < 0.0:
				_sat_stop_at = randf_range(90.0, 400.0) if Game.night >= 5 and not Game.has_flag("sat_stopped_%d" % Game.night) else 1e9
			_sat_stop_at -= delta
			if _sat_stop_at <= 0.0 and _sat_stop < 0.0:
				_sat_stop = 28.0
				Game.set_flag("sat_stopped_%d" % Game.night, true)
				if Game.is_outside():
					Game.hud.subtitle(Loc.t(&"th.satellite"), 4.0)
					Achievements.unlock(&"satellite")
			if _sat_stop > 0.0:
				_sat_stop -= delta
				_sky_mat.set_shader_parameter(&"sat_alarm", 1.0)
				if _sat_stop <= 0.0:
					_sat_t += 1.6          # «пропал» — дальше уже на другом конце неба
			else:
				_sky_mat.set_shader_parameter(&"sat_alarm", 0.0)
				_sat_t = wrapf(_sat_t + delta * 0.006, 0.25, 2.9)
			_sky_mat.set_shader_parameter(&"sat_t", _sat_t)
	# Дым и искры трубы
	if _smoke != null:
		var strength := clampf(Game.stove_wood / 40.0, 0.2, 1.0)
		if Game.stove_wood > _wood_last + 4.0:
			_smoke.scale_amount_max = 6.0      # подкинул — повалило густо
			var q0 := _smoke.mesh as QuadMesh
			if q0 != null and q0.material is StandardMaterial3D:
				(q0.material as StandardMaterial3D).albedo_color.a = 0.5
		_smoke.scale_amount_max = move_toward(_smoke.scale_amount_max, lerpf(2.0, 4.0, strength), delta * 0.4)
		var qm := _smoke.mesh as QuadMesh
		if qm != null and qm.material is StandardMaterial3D:
			var m := qm.material as StandardMaterial3D
			m.albedo_color.a = move_toward(m.albedo_color.a, lerpf(0.18, 0.34, strength), delta * 0.03)
		_wood_last = Game.stove_wood
		if _sparks == null:
			_sparks = CPUParticles3D.new()
			_sparks.amount = 10
			_sparks.lifetime = 1.3
			_sparks.local_coords = false
			_sparks.position = _smoke.position + Vector3(0, -0.15, 0)
			_sparks.direction = Vector3(0.2, 1, 0)
			_sparks.spread = 25.0
			_sparks.initial_velocity_min = 1.2
			_sparks.initial_velocity_max = 2.4
			_sparks.gravity = Vector3(0.3, -0.6, 0)
			var sq := QuadMesh.new()
			sq.size = Vector2(0.03, 0.03)
			var spm := StandardMaterial3D.new()
			spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			spm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			spm.albedo_color = Color(1.0, 0.55, 0.2)
			spm.emission_enabled = true
			spm.emission = Color(1.0, 0.5, 0.15)
			spm.emission_energy_multiplier = 3.0
			sq.material = spm
			_sparks.mesh = sq
			_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_sparks)
		_sparks.emitting = _smoke.emitting and not Game.is_daylight() and strength > 0.6 and not Game.stove_damper


## Лучи сквозь ели: где на экране светило, насколько ясно и смотрим ли в его сторону. В доме — нет.
func _update_rays() -> void:
	if _post == null:
		var c := get_viewport().get_parent() as CanvasItem if get_viewport() != null else null
		if c == null or not (c.material is ShaderMaterial):
			return
		_post = c.material as ShaderMaterial
	var w_intensity: float = Game.player.whiteout_intensity if Game.player != null and "whiteout_intensity" in Game.player else 0.0
	_post.set_shader_parameter(&"whiteout", w_intensity)
	var cam := get_viewport().get_camera_3d()
	if cam == null or _sky_light == null or Game.is_indoors() or Game.is_prologue_trail() or dbg_no_rays:
		_post.set_shader_parameter(&"ray_amount", 0.0)
		_post.set_shader_parameter(&"warm", 0.0)
		return
	var dir := _sky_light.global_basis.z
	var face := (-cam.global_basis.z).dot(dir)
	var far := cam.global_position + dir * 400.0
	var amount := 0.0
	var clear: float = Game.weather.clearness() if Game.weather != null else 0.0
	if not cam.is_position_behind(far) and face > 0.1:
		var uv := cam.unproject_position(far) / get_viewport().get_visible_rect().size
		_post.set_shader_parameter(&"ray_uv", uv)
		var day := Game.is_daylight()
		var t_dusk := clampf((Game.shift_minutes - 120.0) / 100.0, 0.0, 1.0) if day else 1.0
		if day:
			amount = clear * 0.9 * (1.0 - smoothstep(0.7, 1.0, t_dusk))
			_post.set_shader_parameter(&"ray_thresh", 0.74)
			_post.set_shader_parameter(&"ray_color", Color(1.0, 0.82, 0.58).lerp(Color(1.0, 0.55, 0.32), t_dusk))
		else:
			amount = clear * _moon_gap * 0.55
			_post.set_shader_parameter(&"ray_thresh", 0.2)
			_post.set_shader_parameter(&"ray_color", Color(0.55, 0.68, 1.0))
		amount *= smoothstep(0.1, 0.75, face)
	_post.set_shader_parameter(&"ray_amount", amount)
	_post.set_shader_parameter(&"warm", clear * 0.6 if Game.is_daylight() else 0.0)


func _apply_sky_tint(t: float, clear := 0.0) -> void:
	if env != null:
		env.fog_light_color = FOG_DAY_COL.lerp(FOG_CLEAR_COL, clear).lerp(FOG_NIGHT_COL, t)
	if _sky_mat == null:
		return
	for k: String in SKY_DAY:
		_sky_mat.set_shader_parameter(k, (SKY_DAY[k] as Color).lerp(SKY_CLEAR[k], clear).lerp(SKY_NIGHT[k], t))
	_sky_mat.set_shader_parameter("star_amount", t)


func set_day_lighting(day: bool) -> void:
	if env != null:
		env.background_color = Color(0.4, 0.43, 0.5) if day else Color(0.02, 0.04, 0.07)
		env.ambient_light_color = Color(0.55, 0.6, 0.7) if day else NIGHT_AMB_COL
		env.ambient_light_energy = 0.75 if day else NIGHT_AMB
		env.fog_light_color = Color(0.58, 0.61, 0.68) if day else FOG_NIGHT_COL
	if _sky_light != null:
		_sky_light.light_color = Color(0.85, 0.85, 0.9) if day else Color(0.58, 0.72, 0.92)
		_sky_light.light_energy = 0.45 if day else NIGHT_MOON
		_sky_light.rotation_degrees = Vector3(-25.0, 40.0, 0.0) if day else Vector3(-32.0, -135.0, 0.0)
	_apply_sky_tint(0.0 if day else 1.0)


# --- Дом (Архитектурный комплекс метеостанции) ------------------------------
##
## 5-комнатный комплекс таёжной метеостанции:
##   1. Жилая комната дежурного: x -2.5 .. 3.5,  z  0.0 .. 6.6  (русская печь, кровать, стол с самоваром)
##   2. Г-образный коридор:     x  3.5 .. 11.5, z  2.2 .. 6.6  (лаз на чердак, качающаяся лампа)
##   3. Радиорубка/дежурка:      x  3.5 .. 11.5, z -2.0 .. 2.2  (стол, аппаратура, сейф, окно на север)
##   4. Холодная кладовая:      x  3.5 .. 7.0,  z -5.5 .. -2.0 (глухой тёмный чулан, аккумуляторы)
##   5. Прихожая-тамбур (сени): x 11.5 .. 14.5, z  1.5 .. 6.6  (двойная дверь, валенки, тулупы, генератор)

func _build_house() -> void:
	var wall := Palette.m(&"wall")
	var floor_m := Palette.m(&"floor")
	var ceil_m := Palette.m(&"ceiling")
	var logm := Palette.m(&"log")
	var found_m := Palette.m(&"wood")
	# Новый интерьер (tools/blender/house_int.py): по модели на комнату — коробки ниже становятся только коллизией
	_int_models = true
	for room: String in ["living", "radio", "corridor", "store", "vest"]:
		if Models.spawn(self, "kedr/house_int_" + room, Vector3(0, HOUSE_INT_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.7, "sat": 1.0}) == null:
			_int_models = false

	# 1. Полы (сплошной дощатый настил с физической коллизией):
	# Жилая комната дежурного (x: -2.5..3.5, z: 0.0..6.6):
	_shell(Vector3(6.0, 0.24, 6.6), Vector3(0.5, -0.07, 3.3), floor_m, true)
	# Г-образный коридор (x: 3.5..11.5, z: 2.2..6.6):
	_shell(Vector3(8.0, 0.24, 4.4), Vector3(7.5, -0.07, 4.4), floor_m, true)
	# Радиорубка / операторская (x: 3.5..11.5, z: -2.0..2.2):
	_shell(Vector3(8.0, 0.24, 4.2), Vector3(7.5, -0.07, 0.1), floor_m, true)
	# Холодная аккумуляторная / кладовая (x: 3.5..7.0, z: -5.5..-2.0):
	_shell(Vector3(3.5, 0.24, 3.5), Vector3(5.25, -0.07, -3.75), floor_m, true)
	# Прихожая-тамбур / сени (x: 11.5..14.5, z: 1.5..6.6):
	_shell(Vector3(3.0, 0.24, 5.1), Vector3(13.0, -0.07, 4.05), floor_m, true)

	# 2. Потолки:
	_shell(Vector3(6.0, 0.2, 6.6), Vector3(0.5, ROOM_H + 0.1, 3.3), ceil_m, false)
	_shell(Vector3(8.0, 0.2, 4.4), Vector3(7.5, ROOM_H + 0.1, 4.4), ceil_m, false)
	_shell(Vector3(8.0, 0.2, 4.2), Vector3(7.5, ROOM_H + 0.1, 0.1), ceil_m, false)
	_shell(Vector3(3.5, 0.2, 3.5), Vector3(5.25, ROOM_H + 0.1, -3.75), ceil_m, false)
	_shell(Vector3(3.0, 0.2, 5.1), Vector3(13.0, ROOM_H + 0.1, 4.05), ceil_m, false)

	# 3. Фундамент (сплошной цоколь под всеми наружными стенами, уходящий вглубь до y=-0.8):
	_shell(Vector3(17.0, 0.8, 0.3), Vector3(6.0, -0.4, 6.6), found_m, true)     # юг общий
	_shell(Vector3(0.3, 0.8, 6.6), Vector3(-2.5, -0.4, 3.3), found_m, true)    # запад жилой
	_shell(Vector3(6.0, 0.8, 0.3), Vector3(0.5, -0.4, 0.0), found_m, true)     # север жилой
	_shell(Vector3(0.3, 0.8, 2.0), Vector3(3.5, -0.4, -1.0), found_m, true)    # запад радиорубки
	_shell(Vector3(0.3, 0.8, 3.5), Vector3(3.5, -0.4, -3.75), found_m, true)   # запад кладовой
	_shell(Vector3(3.5, 0.8, 0.3), Vector3(5.25, -0.4, -5.5), found_m, true)   # север кладовой
	_shell(Vector3(0.3, 0.8, 3.5), Vector3(7.0, -0.4, -3.75), found_m, true)   # восток кладовой
	_shell(Vector3(4.5, 0.8, 0.3), Vector3(9.25, -0.4, -2.0), found_m, true)   # север радиорубки
	_shell(Vector3(0.3, 0.8, 3.5), Vector3(11.5, -0.4, -0.25), found_m, true)  # восток радиорубки
	_shell(Vector3(3.0, 0.8, 0.3), Vector3(13.0, -0.4, 1.5), found_m, true)    # север тамбура
	_shell(Vector3(0.3, 0.8, 5.1), Vector3(14.5, -0.4, 4.05), found_m, true)   # восток тамбура

	# 4. Стены:
	# 4.1 Южная наружная стена (z = 6.6, x: -2.5..14.5):
	# Окно жилой комнаты (x = 0.5):
	_shell(Vector3(2.5, ROOM_H, 0.2), Vector3(-1.25, 1.4, 6.6), wall, true)
	_shell(Vector3(1.0, 1.1, 0.2), Vector3(0.5, 0.55, 6.6), wall, true)
	_shell(Vector3(1.0, 0.9, 0.2), Vector3(0.5, 2.35, 6.6), wall, true)
	_shell(Vector3(2.5, ROOM_H, 0.2), Vector3(2.25, 1.4, 6.6), wall, true)
	# Окно коридора (x = 7.5):
	_shell(Vector3(3.6, ROOM_H, 0.2), Vector3(5.3, 1.4, 6.6), wall, true)
	_shell(Vector3(0.8, 1.2, 0.2), Vector3(7.5, 0.6, 6.6), wall, true)
	_shell(Vector3(0.8, 0.8, 0.2), Vector3(7.5, 2.4, 6.6), wall, true)
	_shell(Vector3(3.6, ROOM_H, 0.2), Vector3(9.7, 1.4, 6.6), wall, true)
	# Тамбур (x: 11.5..14.5):
	_shell(Vector3(3.0, ROOM_H, 0.2), Vector3(13.0, 1.4, 6.6), wall, true)

	# 4.2 Западная наружная стена жилой комнаты (x = -2.5, z: 0.0..6.6):
	_shell(Vector3(0.2, ROOM_H, 2.75), Vector3(-2.5, 1.4, 1.375), wall, true)
	_shell(Vector3(0.2, 1.05, 1.1), Vector3(-2.5, 0.525, 3.3), wall, true) # под окном
	_shell(Vector3(0.2, 0.95, 1.1), Vector3(-2.5, 2.325, 3.3), wall, true) # над окном
	_shell(Vector3(0.2, ROOM_H, 2.75), Vector3(-2.5, 1.4, 5.225), wall, true)

	# 4.3 Северная наружная стена жилой комнаты (z = 0.0, x: -2.5..3.5):
	_shell(Vector3(6.0, ROOM_H, 0.2), Vector3(0.5, 1.4, 0.0), wall, true)

	# 4.4 Перегородка: Жилая комната <-> Радиорубка / Коридор (x = 3.5, z: 0.0..6.6):
	_shell(Vector3(0.2, ROOM_H, 2.6), Vector3(3.5, 1.4, 1.3), wall, true)
	_shell(Vector3(0.2, 0.7, 1.1), Vector3(3.5, 2.45, 3.15), wall, true) # над дверью в коридор
	_shell(Vector3(0.2, ROOM_H, 2.9), Vector3(3.5, 1.4, 5.15), wall, true)

	# 4.5 Перегородка: Радиорубка <-> Коридор (z = 2.2, x: 3.5..11.5, проём двери на x = 7.55):
	_shell(Vector3(3.5, ROOM_H, 0.2), Vector3(5.25, 1.4, 2.2), wall, true)
	_shell(Vector3(1.1, 0.7, 0.2), Vector3(7.55, 2.45, 2.2), wall, true) # над дверью
	_shell(Vector3(3.4, ROOM_H, 0.2), Vector3(9.8, 1.4, 2.2), wall, true)

	# 4.6 Холодная кладовая / аккумуляторная (x: 3.5..7.0, z: -5.5..-2.0):
	# Стена между кладовой и радиорубкой (проём двери на x = 5.3):
	_shell(Vector3(1.3, ROOM_H, 0.2), Vector3(4.15, 1.4, -2.0), wall, true)
	_shell(Vector3(1.0, 0.7, 0.2), Vector3(5.3, 2.45, -2.0), wall, true)
	_shell(Vector3(1.2, ROOM_H, 0.2), Vector3(6.4, 1.4, -2.0), wall, true)
	# Глухие наружные стены чулана:
	_shell(Vector3(0.2, ROOM_H, 3.5), Vector3(3.5, 1.4, -3.75), wall, true) # запад
	_shell(Vector3(3.5, ROOM_H, 0.2), Vector3(5.25, 1.4, -5.5), wall, true) # север
	_shell(Vector3(0.2, ROOM_H, 3.5), Vector3(7.0, 1.4, -3.75), wall, true)  # восток

	# 4.7 Северная наружная стена радиорубки с окном на площадку (z = -2.0, x: 7.0..11.5):
	_shell(Vector3(1.6, ROOM_H, 0.2), Vector3(7.8, 1.4, -2.0), wall, true)
	_shell(Vector3(1.2, 1.05, 0.2), Vector3(9.2, 0.525, -2.0), wall, true) # под окном
	_shell(Vector3(1.2, 0.95, 0.2), Vector3(9.2, 2.325, -2.0), wall, true) # над окном
	_shell(Vector3(1.7, ROOM_H, 0.2), Vector3(10.65, 1.4, -2.0), wall, true)

	# 4.7b Западная наружная стена радиорубки (x = 3.5, z: -2.0..0.0):
	_shell(Vector3(0.2, ROOM_H, 2.0), Vector3(3.5, 1.4, -1.0), wall, true)

	# 4.8 Восточная наружная стена радиорубки (x = 11.5, z: -2.0..1.5):
	_shell(Vector3(0.2, ROOM_H, 3.5), Vector3(11.5, 1.4, -0.25), wall, true)

	# 4.9 Перегородка: Коридор <-> Прихожая-тамбур (x = 11.5, z: 1.5..6.6, проём на z = 3.15):
	_shell(Vector3(0.2, ROOM_H, 1.1), Vector3(11.5, 1.4, 2.05), wall, true)
	_shell(Vector3(0.2, 0.7, 1.1), Vector3(11.5, 2.45, 3.15), wall, true) # над дверью
	_shell(Vector3(0.2, ROOM_H, 2.9), Vector3(11.5, 1.4, 5.15), wall, true)

	# 4.10 Северная наружная стена тамбура (z = 1.5, x: 11.5..14.5):
	_shell(Vector3(3.0, ROOM_H, 0.2), Vector3(13.0, 1.4, 1.5), wall, true)

	# 4.11 Восточная наружная стена тамбура с входной дверью (x = 14.5, z: 1.5..6.6, проём на z = 3.1):
	_shell(Vector3(0.2, ROOM_H, 1.1), Vector3(14.5, 1.4, 2.05), wall, true)
	_shell(Vector3(0.2, 0.7, 1.0), Vector3(14.5, 2.45, 3.1), wall, true) # над дверью
	_shell(Vector3(0.2, ROOM_H, 3.0), Vector3(14.5, 1.4, 5.1), wall, true)

	# 5. Наружный сруб, фронтоны, крыши, наличники, крыльцо — см. _build_exterior().
	_build_exterior()
	_build_occluders()

	# 8. Окна:
	_window(Vector3(9.2, 1.45, -2.0), Vector3(1.1, 0.8, 0.03), Vector3(0, 0, 1), "north")
	_window(Vector3(-2.5, 1.45, 3.3), Vector3(0.03, 0.8, 1.0), Vector3(1, 0, 0), "west")
	_window(Vector3(0.5, 1.45, 6.6), Vector3(0.9, 0.8, 0.03), Vector3(0, 0, -1), "south_living")
	_window(Vector3(7.5, 1.5, 6.6), Vector3(0.7, 0.6, 0.03), Vector3(0, 0, -1), "south_corridor")

	door_spot = {
		"look": Vector3(3.5, 1.4, 3.15),
		"feet": Vector3(4.2, 0.0, 3.15),
		"inward": Vector3(-1, 0, 0),
	}


## Коробка оболочки дома: при модели интерьера — только коллизия (вид даёт house_int_*.glb).
func _shell(size: Vector3, pos: Vector3, mat: Material, collide: bool) -> void:
	if not _int_models:
		Geo.block(self, size, pos, mat, collide)
		return
	if not collide:
		return
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.add_child(Geo.box_shape(size))
	add_child(body)


func _build_chimney() -> void:
	var pipe := Props.chimney_pipe()
	pipe.position = Vector3(-1.5, ROOM_H + 0.85, 1.0)
	add_child(pipe)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 20
	_smoke.lifetime = 3.2
	_smoke.local_coords = false
	_smoke.position = Vector3(-1.5, ROOM_H + 2.3, 1.0)
	_smoke.direction = Vector3(0.4, 1.0, 0.1)
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 0.9
	_smoke.gravity = Vector3(0.25, 0.12, 0.0)
	_smoke.scale_amount_min = 1.0
	_smoke.scale_amount_max = 3.5
	var qm := QuadMesh.new()
	qm.size = Vector2(0.4, 0.4)
	var smat := Player.puff_material(0.3)
	# Ночью дым серебрится в лунном свете, днём — серый
	smat.albedo_color = Color(0.7, 0.72, 0.76, 0.3) if Game.is_daylight() else Color(0.5, 0.56, 0.68, 0.32)
	qm.material = smat
	_smoke.mesh = qm
	_smoke.color_ramp = Player.puff_ramp()
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)

	# Наружная лестница и лючок прочистки дымохода на западной стене сруба
	var ladder := Props.wall_ladder(ROOM_H + 0.8)
	ladder.position = Vector3(-2.5 - LOG_FACE - 0.04, 0.0, 1.0)
	ladder.rotation.y = deg_to_rad(90.0)
	add_child(ladder)

	var chimney_ice_node := Props.chimney_ice()
	chimney_ice_node.position = Vector3(-1.5, ROOM_H + 2.1, 1.0)
	chimney_ice_node.name = "ChimneyIce"
	chimney_ice_node.visible = Game.chimney_iced
	add_child(chimney_ice_node)

	var chimney_it := Geo.interactable(self, Vector3(0.5, 1.8, 0.8), Vector3(-2.95, 1.2, 1.0), null, "", func(_p: Player) -> void:
		if Game.chimney_iced:
			Game.set_chimney_iced(false)
			chimney_ice_node.visible = false
			Game.audio.play_3d("res://assets/audio/ice_hit.ogg", Vector3(-2.7, 1.5, 1.0), -3.0)
			Game.hud.subtitle(Loc.t(&"sub.chimney_cleared"), 3.5)
	)
	chimney_it.hold_time = 3.0
	chimney_it.hold_sound = "res://assets/audio/ice_hit.ogg"
	chimney_it.hold_check = func() -> bool: return Game.chimney_iced
	chimney_it.prompt_provider = func() -> String:
		return Loc.t(&"it.chimney_iced") if Game.chimney_iced else Loc.t(&"it.chimney")
	_chimney_ice_node = chimney_ice_node
	_chimney_ice_node.visible = Game.chimney_iced



# --- Наружный сруб и кровля -------------------------------------------------
## Геометрия кровли. Основная двускатная крыша: конёк вдоль X на z = 3.3. Северное крыло (рубка и
## кладовая) — под пологой односкатной, которая продолжает северный скат от линии z = 0 (без щелей).
const RIDGE_TOP := 5.5
const ROOF_PITCH := 28.0
const ROOF_T := 0.16
const SHED_PITCH := 6.0
const EAVE_OVER := 0.45          ## свес крыши за стену
const LOG_FACE := 0.36           ## от линии стены до наружной грани бревна
const HOUSE_EXT_Y := -0.25        ## низ цоколя house_ext.glb
const HOUSE_INT_Y := 0.02         ## низ пола house_int_*.glb
const HOUSE_ATTIC_Y := 2.93       ## низ настила house_int_attic.glb
const GEN_SHACK_Y := -0.04        ## низ лежней gen_shack.glb
var _int_models := false


func _roof_top(z: float) -> float:
	return RIDGE_TOP - absf(z - 3.3) * tan(deg_to_rad(ROOF_PITCH))


func _shed_top(z: float) -> float:
	return _roof_top(0.0) + z * tan(deg_to_rad(SHED_PITCH))


func _roof_under(z: float) -> float:
	return _roof_top(z) - ROOF_T / cos(deg_to_rad(ROOF_PITCH))


func _shed_under(z: float) -> float:
	return _shed_top(z) - ROOF_T / cos(deg_to_rad(SHED_PITCH))


## Заслонки для отсечения невидимого (occlusion culling) по линии сруба, с прорезями под окна и дверь.
## Снаружи движок больше не рисует обстановку дома за стенами (~200 вызовов), изнутри — двор за
## стенами. Через окна и открытую дверь видно всё, как раньше: там заслонок нет.
## Проёмы — те же, что у сруба в _build_exterior(), с запасом 5 см, чтобы край не «съедал» вид.
func _build_occluders() -> void:
	var o := CabinBuilder.OFFSET
	var y0 := 0.05
	var y1 := ROOM_H - 0.05
	var win_living := [-0.04, 1.04, 1.06, 1.94]
	var win_corr := [7.06, 7.94, 1.16, 2.04]
	var win_west := [2.71, 3.89, 1.01, 1.89]
	var win_north := [8.56, 9.84, 1.01, 1.89]
	var door := [2.56, 3.64, -1.0, 2.18]
	var walls := [
		[0, -2.5 - o, 14.5 + o, 6.6 + o, [win_living, win_corr]],   # юг
		[2, -o, 6.6 + o, 14.5 + o, [door]],                        # восток (тамбур)
		[0, 11.5 + o, 14.5 + o, -o, []],                           # север тамбура
		[0, -2.5 - o, 3.5 - o, -o, []],                            # север жилой
		[2, -o, 6.6 + o, -2.5 - o, [win_west]],                    # запад жилой
		[2, -2.0 - o, -o, 11.5 + o, []],                           # восток рубки
		[0, 7.0 + o, 11.5 + o, -2.0 - o, [win_north]],             # север рубки
		[2, -5.5 - o, -2.0 - o, 7.0 + o, []],                      # восток кладовой
		[0, 3.5 - o, 7.0 + o, -5.5 - o, []],                       # север кладовой
		[2, -5.5 - o, -o, 3.5 - o, []],                            # запад крыла
	]
	var n := 0
	for w: Array in walls:
		for r: Array in _wall_rects(float(w[1]), float(w[2]), y0, y1, w[4]):
			var q := QuadOccluder3D.new()
			q.size = Vector2(float(r[1]) - float(r[0]), float(r[3]) - float(r[2]))
			var oi := OccluderInstance3D.new()
			oi.occluder = q
			var cu := (float(r[0]) + float(r[1])) * 0.5
			var cv := (float(r[2]) + float(r[3])) * 0.5
			if int(w[0]) == 0:
				oi.position = Vector3(cu, cv, float(w[3]))      # квад лежит в плоскости XY
			else:
				oi.position = Vector3(float(w[3]), cv, cu)
				oi.rotation.y = PI * 0.5
			add_child(oi)
			n += 1
	if OS.is_debug_build():
		print("[occluders] %d заслонок" % n)


## Прямоугольник стены [a..b]×[y0..y1] минус проёмы [u0, u1, v0, v1] → набор прямоугольников.
static func _wall_rects(a: float, b: float, y0: float, y1: float, holes: Array) -> Array:
	var lo := minf(a, b)
	var hi := maxf(a, b)
	var hs := holes.duplicate()
	hs.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var out := []
	var u := lo
	for h: Array in hs:
		var h0 := clampf(float(h[0]) - 0.05, lo, hi)
		var h1 := clampf(float(h[1]) + 0.05, lo, hi)
		if h0 > u + 0.01:
			out.append([u, h0, y0, y1])
		var hv0 := maxf(float(h[2]) - 0.05, y0)
		var hv1 := minf(float(h[3]) + 0.05, y1)
		if hv0 > y0 + 0.01:
			out.append([h0, h1, y0, hv0])
		if hv1 < y1 - 0.01:
			out.append([h0, h1, hv1, y1])
		u = maxf(u, h1)
	if hi > u + 0.01:
		out.append([u, hi, y0, y1])
	return out


func _build_exterior() -> void:
	var o := CabinBuilder.OFFSET
	var cb := CabinBuilder.new()
	var base := 0.08
	var eave_s := _roof_under(6.6 + o)
	var eave_n := _roof_under(-o)
	# Проёмы (в координатах вдоль стены): окна и дверь с небольшим запасом под наличник.
	var win_living := [-0.04, 1.04, 1.06, 1.94]
	var win_corr := [7.06, 7.94, 1.16, 2.04]
	var win_west := [2.71, 3.89, 1.01, 1.89]
	var win_north := [8.56, 9.84, 1.01, 1.89]
	var door := [2.56, 3.64, -1.0, 2.18]
	# Основной корпус
	cb.wall(0, -2.5 - o, 14.5 + o, 6.6 + o, base, eave_s, eave_s, [win_living, win_corr], true, true, 0.0)   # юг
	cb.wall(2, -o, 6.6 + o, 14.5 + o, base, eave_s, eave_s, [door], true, true, 0.5)                         # восток (тамбур)
	cb.wall(0, 11.5 + o, 14.5 + o, -o, base, eave_n, eave_n, [], false, true, 0.0)                         # север тамбура
	cb.wall(0, -2.5 - o, 3.5 - o, -o, base, eave_n, eave_n, [], true, false, 0.0)                          # север жилой
	cb.wall(2, -o, 6.6 + o, -2.5 - o, base, eave_s, eave_s, [win_west], true, true, 0.5)                     # запад жилой
	# Северное крыло под односкатной крышей: верх стен идёт по уклону
	cb.wall(2, -2.0 - o, -o, 11.5 + o, base, _shed_under(-2.0 - o), _shed_under(-o), [], true, false, 0.5)       # восток рубки
	cb.wall(0, 7.0 + o, 11.5 + o, -2.0 - o, base, _shed_under(-2.0 - o), _shed_under(-2.0 - o), [win_north], false, true, 0.0)  # север рубки
	cb.wall(2, -5.5 - o, -2.0 - o, 7.0 + o, base, _shed_under(-5.5 - o), _shed_under(-2.0 - o), [], true, false, 0.5)  # восток кладовой
	cb.wall(0, 3.5 - o, 7.0 + o, -5.5 - o, base, _shed_under(-5.5 - o), _shed_under(-5.5 - o), [], true, true, 0.0)   # север кладовой
	cb.wall(2, -5.5 - o, -o, 3.5 - o, base, _shed_under(-5.5 - o), _shed_under(-o), [], true, false, 0.5)           # запад крыла
	# Фронтоны (рубленые, брёвна укорачиваются к коньку); на западном — слуховое окно чердака.
	cb.gable(2, 3.3, 3.3 + o + 0.05, 14.5 + o, eave_s, _roof_under(3.3))
	cb.gable(2, 3.3, 3.3 + o + 0.05, -2.5 - o, eave_s, _roof_under(3.3), [[2.93, 3.67, 3.43, 4.17]])
	# Новый облик (tools/blender/house_ext.py): обшитый тёсом дом УГМС — вместо сруба, кровли, наличников и крыльца.
	# Коллизии ниже — прежние, по линии бывшего сруба.
	var ext := Models.spawn(self, "kedr/house_ext", Vector3(0, HOUSE_EXT_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0})
	if ext == null:
		cb.build(self, Palette.m(&"log_round"), Palette.m(&"log_end"))

	# Коллизия сруба: игрок упирается в брёвна, а не проходит в них до штукатурки.
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for w: Array in [[Vector3(6.0, 1.7, 6.6 + o), Vector3(17.9, 3.4, 0.3)], [Vector3(14.5 + o, 1.7, 3.3), Vector3(0.3, 3.4, 7.1)],
			[Vector3(-2.5 - o, 1.7, 3.3), Vector3(0.3, 3.4, 7.1)], [Vector3(0.5, 1.7, -o), Vector3(6.4, 3.4, 0.3)],
			[Vector3(13.0, 1.7, -o), Vector3(3.4, 3.4, 0.3)], [Vector3(11.5 + o, 1.7, -1.1), Vector3(0.3, 3.4, 2.4)],
			[Vector3(9.25, 1.7, -2.0 - o), Vector3(4.9, 3.4, 0.3)], [Vector3(7.0 + o, 1.7, -3.75), Vector3(0.3, 3.4, 3.9)],
			[Vector3(5.25, 1.7, -5.5 - o), Vector3(3.9, 3.4, 0.3)], [Vector3(3.5 - o, 1.7, -2.85), Vector3(0.3, 3.4, 5.8)]]:
		# Дверной проём востока не перекрываем: коллизию восточной стены режем на два куска.
		if (w[0] as Vector3).x > 14.0:
			for part: Array in [[Vector3(14.72, 1.7, 1.0), Vector3(0.44, 3.4, 3.1)], [Vector3(14.72, 1.7, 5.25), Vector3(0.44, 3.4, 3.2)],
					[Vector3(14.72, 2.8, 3.1), Vector3(0.44, 1.2, 1.1)]]:
				var cs2 := CollisionShape3D.new()
				var sh2 := BoxShape3D.new()
				sh2.size = part[1]
				cs2.shape = sh2
				cs2.position = part[0]
				body.add_child(cs2)
			continue
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = w[1]
		cs.shape = sh
		cs.position = w[0]
		body.add_child(cs)

	if ext != null:
		_build_porch(true)
		return
	_build_roofs()
	_build_openings_trim()
	_build_porch()


## Скат: прямоугольник [x0..x1] × [z0..z1] на плоскости top(z), толщиной t; снег сверху; вдоль нижнего края — сосульки.
func _roof_piece(x0: float, x1: float, z0: float, z1: float, pitch: float, top_fn: Callable, eave_z: float, eave_trim := true) -> void:
	var roof_m := Palette.m(&"plank")
	var snow_m := Palette.m(&"snow")
	var zc := (z0 + z1) * 0.5
	var run := absf(z1 - z0)
	var slope := deg_to_rad(pitch)
	var length := run / cos(slope)
	# Поворот вокруг X: при +угле дальний (+Z) край опускается. Скат «вниз к +Z» — плюс, «вверх к +Z» — минус.
	var goes_down: bool = float(top_fn.call(z1)) < float(top_fn.call(z0))
	var tilt := slope if goes_down else -slope
	var n := Vector3(0, cos(tilt), sin(tilt))   # нормаль ската вверх
	var slab := Geo.box_mesh(Vector3(x1 - x0, ROOF_T, length), roof_m)
	slab.position = Vector3((x0 + x1) * 0.5, top_fn.call(zc), zc) - n * (ROOF_T * 0.5)
	slab.rotation.x = tilt
	add_child(slab)
	# Снежная шапка: чуть уже ската, толще у конька не бывает — ровный пласт с мягким краем.
	var snow := Geo.box_mesh(Vector3(x1 - x0 - 0.06, 0.11, length - 0.02), snow_m)
	snow.position = Vector3((x0 + x1) * 0.5, top_fn.call(zc), zc) + n * 0.05
	snow.rotation.x = tilt
	add_child(snow)
	if not eave_trim:
		return
	# Лобовая доска по свесу
	var eave_y: float = top_fn.call(eave_z)
	var fascia := Geo.box_mesh(Vector3(x1 - x0, 0.2, 0.05), Palette.m(&"wood"))
	fascia.position = Vector3((x0 + x1) * 0.5, eave_y - 0.12, eave_z)
	add_child(fascia)
	var ice := Props.icicles(x1 - x0 - 0.3, int((x1 - x0) * 1.5))
	ice.position = Vector3((x0 + x1) * 0.5, eave_y - 0.22, eave_z)
	add_child(ice)


## Боковая ветровая доска вдоль ската (закрывает торец кровли) на линии x, от za до zb.
func _barge(x: float, za: float, zb: float, pitch: float, top_fn: Callable) -> void:
	var mid := (za + zb) * 0.5
	var goes_down: bool = float(top_fn.call(zb)) < float(top_fn.call(za))
	var slope := deg_to_rad(pitch)
	var b := Geo.box_mesh(Vector3(0.05, 0.24, absf(zb - za) / cos(slope) + 0.04), Palette.m(&"wood"))
	b.position = Vector3(x, float(top_fn.call(mid)) - 0.08, mid)
	b.rotation.x = slope if goes_down else -slope
	add_child(b)


func _build_roofs() -> void:
	var o := CabinBuilder.OFFSET
	var xw := -2.5 - o - EAVE_OVER        # западный свес
	var xe := 14.5 + o + EAVE_OVER        # восточный свес
	var wing0 := 3.5 - o - 0.35           # односкатная — над крылом x 3.5..11.5 (+свес)
	var wing1 := 11.5 + o + 0.35
	var zs := 6.6 + o + EAVE_OVER         # южный свес
	var zn := -o - EAVE_OVER              # северный свес основного корпуса (над жилой и тамбуром)
	var top := Callable(self, &"_roof_top")
	var shed := Callable(self, &"_shed_top")
	# Южный скат целиком
	_roof_piece(xw, xe, 3.3, zs, ROOF_PITCH, top, zs)
	# Северный скат: над жилой и над тамбуром — со свесом; над крылом — до линии z = 0, дальше односкатная.
	_roof_piece(xw, wing0, zn, 3.3, ROOF_PITCH, top, zn)
	_roof_piece(wing0, wing1, 0.0, 3.3, ROOF_PITCH, top, 0.0, false)
	_roof_piece(wing1, xe, zn, 3.3, ROOF_PITCH, top, zn)
	# Односкатная крыша крыла: над рубкой (до z = -2) и отдельно над кладовой (до z = -5.5), одна плоскость.
	var z_radio := -2.0 - o - 0.35
	var z_store := -5.5 - o - 0.35
	var x_store := 7.0 + o + 0.35
	_roof_piece(wing0, x_store, z_radio, 0.0, SHED_PITCH, shed, z_radio, false)
	_roof_piece(x_store, wing1, z_radio, 0.0, SHED_PITCH, shed, z_radio)
	_roof_piece(wing0, x_store, z_store, z_radio, SHED_PITCH, shed, z_store)
	_barge(wing0 + 0.03, z_store, 0.0, SHED_PITCH, shed)
	_barge(wing1 - 0.03, z_radio, 0.0, SHED_PITCH, shed)
	_barge(x_store - 0.03, z_store, z_radio, SHED_PITCH, shed)
	# Конёк: доска-«охлупень» по всей длине
	var ridge := Geo.box_mesh(Vector3(xe - xw + 0.1, 0.12, 0.34), Palette.m(&"wood"))
	ridge.position = Vector3((xw + xe) * 0.5, RIDGE_TOP + 0.03, 3.3)
	add_child(ridge)
	# Ветровые доски по фронтонам (закрывают торцы скатов)
	for x: float in [xw + 0.03, xe - 0.03]:
		_barge(x, 3.3, zs, ROOF_PITCH, top)
		_barge(x, zn, 3.3, ROOF_PITCH, top)


## Проёмы в срубе: откосы (доски от штукатурки до наружной грани бревна), подоконник-отлив,
## и крашеные наличники — выцветшая советская голубая краска.
func _build_openings_trim() -> void:
	var paint := Palette.m(&"trim_paint")
	var board := Palette.m(&"plank")
	# [центр проёма на линии стены, ширина, высота, наружная нормаль]
	for w: Array in [
		[Vector3(9.2, 1.45, -2.0), 1.2, 0.84, Vector3(0, 0, -1)],
		[Vector3(-2.5, 1.45, 3.3), 1.1, 0.84, Vector3(-1, 0, 0)],
		[Vector3(0.5, 1.5, 6.6), 1.0, 0.84, Vector3(0, 0, 1)],
		[Vector3(7.5, 1.6, 6.6), 0.8, 0.84, Vector3(0, 0, 1)],
	]:
		var c: Vector3 = w[0]
		var wd: float = w[1]
		var ht: float = w[2]
		var n: Vector3 = w[3]
		var along := Vector3(absf(n.z), 0, absf(n.x))      # вдоль стены
		var depth := LOG_FACE - 0.1
		var mid := c + n * (0.1 + depth * 0.5)
		# откосы: верх, низ, бока
		_box_oriented(mid + Vector3(0, ht * 0.5, 0), along * wd + Vector3(0, 0.04, 0) + n.abs() * depth, board)
		_box_oriented(mid - Vector3(0, ht * 0.5, 0), along * wd + Vector3(0, 0.04, 0) + n.abs() * depth, board)
		for s: float in [-1.0, 1.0]:
			_box_oriented(mid + along * (wd * 0.5) * s, along * 0.04 + Vector3(0, ht, 0) + n.abs() * depth, board)
		# отлив под окном, чуть наружу
		_box_oriented(c + n * (LOG_FACE + 0.05) - Vector3(0, ht * 0.5 + 0.03, 0), along * (wd + 0.2) + Vector3(0, 0.04, 0) + n.abs() * 0.16, board)
		# наличник: рамка по наружной грани
		var face := c + n * (LOG_FACE + 0.015)
		_box_oriented(face + Vector3(0, ht * 0.5 + 0.06, 0), along * (wd + 0.26) + Vector3(0, 0.12, 0) + n.abs() * 0.03, paint)
		_box_oriented(face - Vector3(0, ht * 0.5 + 0.05, 0), along * (wd + 0.2) + Vector3(0, 0.08, 0) + n.abs() * 0.03, paint)
		for s: float in [-1.0, 1.0]:
			_box_oriented(face + along * (wd * 0.5 + 0.05) * s, along * 0.1 + Vector3(0, ht + 0.1, 0) + n.abs() * 0.03, paint)
	# Входная дверь (восток): откосы и косяк по наружной грани сруба
	var dx := 14.5 + 0.1 + (LOG_FACE - 0.1) * 0.5
	Geo.block(self, Vector3(LOG_FACE - 0.1, 0.06, 1.08), Vector3(dx, 2.17, 3.1), board, false)
	Geo.block(self, Vector3(LOG_FACE - 0.1, 2.15, 0.05), Vector3(dx, 1.07, 2.565), board, false)
	Geo.block(self, Vector3(LOG_FACE - 0.1, 2.15, 0.05), Vector3(dx, 1.07, 3.635), board, false)
	var fx := 14.5 + LOG_FACE + 0.015
	Geo.block(self, Vector3(0.03, 0.12, 1.3), Vector3(fx, 2.24, 3.1), paint, false)
	Geo.block(self, Vector3(0.03, 2.2, 0.1), Vector3(fx, 1.1, 2.5), paint, false)
	Geo.block(self, Vector3(0.03, 2.2, 0.1), Vector3(fx, 1.1, 3.7), paint, false)


func _box_oriented(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := Geo.box_mesh(size, mat)
	mi.position = pos
	add_child(mi)


## Крыльцо у входной двери: настил, ступень, навес на столбах с подкосами, снег и сосульки.
func _build_porch(collision_only := false) -> void:
	var x0 := 14.5 + LOG_FACE
	if collision_only:
		# Вид крыльца — в house_ext.glb; здесь только настил, ступень и столбы для коллизии
		var body := StaticBody3D.new()
		body.collision_layer = Geo.LAYER_WORLD
		body.collision_mask = 0
		add_child(body)
		body.add_child(Geo.box_shape(Vector3(1.56, 0.16, 2.3), Vector3(x0 + 0.78, 0.01, 3.1)))
		body.add_child(Geo.box_shape(Vector3(0.4, 0.1, 1.7), Vector3(x0 + 1.75, -0.07, 3.1)))
		for z: float in [2.0, 4.2]:
			body.add_child(Geo.box_shape(Vector3(0.12, 2.5, 0.12), Vector3(x0 + 1.45, 1.3, z)))
		return
	Geo.block(self, Vector3(1.3, 0.16, 2.0), Vector3(x0 + 0.65, -0.02, 3.1), Palette.m(&"plank"), true)
	Geo.block(self, Vector3(0.45, 0.1, 1.8), Vector3(x0 + 1.52, -0.06, 3.1), Palette.m(&"plank"), true)
	for z: float in [2.2, 4.0]:
		Geo.cylinder(self, 0.05, 2.45, Vector3(x0 + 1.15, 1.18, z), Palette.m(&"wood"), true)
	Geo.block_rotated(self, Vector3(0.06, 0.06, 0.6), Vector3(x0 + 1.15, 2.22, 2.42), deg_to_rad(35.0), Palette.m(&"wood"))
	Geo.block_rotated(self, Vector3(0.06, 0.06, 0.6), Vector3(x0 + 1.15, 2.22, 3.78), deg_to_rad(-35.0), Palette.m(&"wood"))
	Geo.block(self, Vector3(1.4, 0.08, 0.08), Vector3(x0 + 0.65, 2.4, 2.2), Palette.m(&"wood"), false)
	Geo.block(self, Vector3(1.4, 0.08, 0.08), Vector3(x0 + 0.65, 2.4, 4.0), Palette.m(&"wood"), false)
	var porch_roof := Geo.box_mesh(Vector3(1.6, 0.06, 2.2), Palette.m(&"plank"))
	porch_roof.position = Vector3(x0 + 0.7, 2.52, 3.1)
	porch_roof.rotation.z = deg_to_rad(-9.0)
	add_child(porch_roof)
	var porch_snow := Geo.box_mesh(Vector3(1.55, 0.08, 2.14), Palette.m(&"snow"))
	porch_snow.position = Vector3(x0 + 0.7, 2.58, 3.1)
	porch_snow.rotation.z = deg_to_rad(-9.0)
	add_child(porch_snow)
	var porch_ice := Props.icicles(2.0, 8)
	porch_ice.position = Vector3(x0 + 1.47, 2.36, 3.1)
	porch_ice.rotation.y = deg_to_rad(90.0)
	add_child(porch_ice)


func _window(glass_pos: Vector3, size: Vector3, inward: Vector3, wname: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Player.LAYER_GLASS
	body.collision_mask = 0
	body.position = glass_pos
	add_child(body)
	body.add_child(Geo.box_mesh(size, Palette.glass()))
	body.add_child(Geo.box_shape(size))

	var along_x := size.x > size.z
	Geo.block(self, Vector3(maxf(size.x, 0.05), 0.04, maxf(size.z, 0.05)), glass_pos, Palette.m(&"dark"), false)
	Geo.block(self, Vector3(0.05, size.y, 0.05), glass_pos, Palette.m(&"dark"), false)
	var sill := Vector3(size.x + 0.1, 0.05, 0.3) if along_x else Vector3(0.3, 0.05, size.z + 0.1)
	Geo.block(self, sill, glass_pos + Vector3(0, -size.y / 2.0, 0), Palette.m(&"wood"), false)

	_window_frost(glass_pos, size, inward, along_x)

	var feet := glass_pos - inward * 1.64
	feet.y = 0.0
	window_spots.append({"name": wname, "glass": glass_pos, "feet": feet, "inward": inward})
	_window_glow(glass_pos, size, -inward)

	# Лунный свет через окно: проекция переплёта рамы на пол и наклонный объёмный луч
	var w_span := maxf(size.x, size.z)
	var floor_pos := glass_pos + inward * 2.2
	floor_pos.y = 0.055
	var proj_quad := QuadMesh.new()
	proj_quad.size = Vector2(w_span * 1.35, 1.85)
	var proj_mat := StandardMaterial3D.new()
	proj_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	proj_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	proj_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	proj_mat.albedo_color = Color(0.25, 0.42, 0.68, 0.0)
	proj_mat.albedo_texture = _make_window_cross_texture()
	proj_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var proj_mi := MeshInstance3D.new()
	proj_mi.mesh = proj_quad
	proj_mi.material_override = proj_mat
	proj_mi.position = floor_pos
	proj_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0) if along_x else Vector3(-90.0, 90.0, 0.0)
	proj_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proj_mi.visible = false
	add_child(proj_mi)

	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.radial_segments = 4
	shaft_mesh.rings = 1
	shaft_mesh.cap_top = false
	shaft_mesh.cap_bottom = false
	var shaft_len := glass_pos.distance_to(floor_pos)
	shaft_mesh.height = shaft_len
	shaft_mesh.top_radius = w_span * 0.42
	shaft_mesh.bottom_radius = w_span * 0.88
	var shaft_mat := Atmosphere.beam_material(Color(0.20, 0.36, 0.62, 0.0))

	var shaft_mi := MeshInstance3D.new()
	shaft_mi.mesh = shaft_mesh
	shaft_mi.material_override = shaft_mat
	shaft_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft_mi.position = (glass_pos + floor_pos) * 0.5
	var shaft_dir := (floor_pos - glass_pos).normalized()
	shaft_mi.basis = Basis(Quaternion(Vector3.DOWN, shaft_dir))
	shaft_mi.visible = false
	add_child(shaft_mi)

	_moon_windows.append({
		"proj": proj_mi,
		"mat_proj": proj_mat,
		"shaft": shaft_mi,
		"mat_shaft": shaft_mat,
		"wname": wname
	})

	if wname == "north":
		_frost_hand = Props.frost_handprint()
		_frost_hand.position = glass_pos - Vector3(0.08, 0.05, 0.02)
		_frost_hand.visible = Game.is_night() and Game.night >= 4
		add_child(_frost_hand)


## Морозный узор на стекле изнутри: иней ползёт от углов и краёв, середина чистая.
static var _frost_mat: ShaderMaterial
var _frost_cov := 0.25

func _window_frost(glass_pos: Vector3, size: Vector3, inward: Vector3, along_x: bool) -> void:
	if _frost_mat == null:
		# Иней растёт, когда дом остывает (Game.house_cold), — холод видно, а не только на полоске
		_frost_mat = ShaderMaterial.new()
		_frost_mat.shader = load("res://assets/shaders/frost.gdshader")
		_frost_mat.set_shader_parameter(&"frost_tex", _frost_texture())
		_frost_cov = 0.85 if Game.is_prologue() else 0.25
		_frost_mat.set_shader_parameter(&"coverage", _frost_cov)
	var q := QuadMesh.new()
	q.size = Vector2(size.x if along_x else size.z, size.y)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _frost_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var thick := minf(size.x, size.z)
	mi.position = glass_pos + inward * (thick * 0.5 + 0.006)
	if not along_x:
		mi.rotation.y = PI * 0.5
	add_child(mi)


static func _frost_texture() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 77
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.045
	n.fractal_octaves = 4
	var fern := FastNoiseLite.new()
	fern.seed = 5
	fern.noise_type = FastNoiseLite.TYPE_CELLULAR
	fern.frequency = 0.09
	fern.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var w := 128
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		for x in w:
			var u := float(x) / float(w - 1)
			var v := float(y) / float(w - 1)
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))     # 0 у края, 0.5 в центре
			var corner := minf(u, 1.0 - u) + minf(v, 1.0 - v)          # углы зарастают раньше
			# «Очередь» зарастания: у края — первым, к центру — последним, с рваной кромкой
			var order := clampf(edge * 1.9 - (0.5 - corner) * 0.35 + n.get_noise_2d(x, y) * 0.22 + 0.06, 0.0, 1.0)
			var vein := clampf(0.55 + fern.get_noise_2d(x, y) * 1.6, 0.0, 1.0)  # «папоротник» прожилками
			img.set_pixel(x, y, Color(order, vein, 0, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Окно светится снаружи тёплым и кладёт пятно света на снег — «тёплое убежище» видно из леса.
## Свечение — плоскость только наружу (изнутри её не видно); гаснет вместе со светом в доме.
func _window_glow(glass_pos: Vector3, size: Vector3, outward: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = glass_pos + outward * 0.9 + Vector3(0, -0.2, 0)
	light.omni_range = 6.0
	light.omni_attenuation = 1.6
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.58, 0.26)
	light.shadow_enabled = false
	add_child(light)
	register_lamp(light)
	var quad := QuadMesh.new()
	quad.size = Vector2(maxf(size.x, size.z) * 0.96, size.y * 0.94)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.62, 0.3, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	var glow := MeshInstance3D.new()
	glow.mesh = quad
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(glow)
	glow.position = glass_pos + outward * 0.03 - light.position
	glow.rotation.y = atan2(outward.x, outward.z)
	# Сцены «кто-то стоит в окне» гасят свечение: аддитивное стекло иначе засвечивает фигуру за ним
	if not window_spots.is_empty() and window_spots[-1]["glass"] == glass_pos:
		window_spots[-1]["glow"] = glow
	Atmosphere.add_window_shaft(light, glass_pos, size, outward)


static func _make_window_cross_texture() -> ImageTexture:
	if _window_cross_tex != null:
		return _window_cross_tex
	var w := 64
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		for x in w:
			var u := float(x) / float(w - 1)
			var v := float(y) / float(w - 1)
			var edge_x := minf(u, 1.0 - u)
			var edge_y := minf(v, 1.0 - v)
			var edge_fade := clampf(minf(edge_x, edge_y) / 0.12, 0.0, 1.0)
			var bar_x := absf(u - 0.5)
			var bar_y := absf(v - 0.45)
			var bar_cross := minf(clampf((bar_x - 0.05) / 0.045, 0.0, 1.0), clampf((bar_y - 0.05) / 0.045, 0.0, 1.0))
			var alpha := edge_fade * bar_cross
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	img.generate_mipmaps()
	_window_cross_tex = ImageTexture.create_from_image(img)
	return _window_cross_tex


func _build_living_quarters() -> void:
	# 1. Русская печь (x: -1.5, z: 1.0)
	var stove := Geo.interactable(self, Vector3(1.1, 1.4, 1.1), Vector3(-1.5, 0.65, 1.0), null, "", _on_stove_used)
	stove.prompt_provider = _stove_prompt
	var stove_mesh := Props.stove(ROOM_H)
	stove_mesh.position.y = -0.65
	stove.add_child(stove_mesh)
	if ResourceLoader.exists("res://assets/models/kedr/stove_brick.glb"):
		# Печь из Блендера: свечение — прямо в проёме топки (центр 0.5 м, грань z = 1.45)
		_fire_glow = Geo.block(self, Vector3(0.36, 0.22, 0.01), Vector3(-1.5, 0.5, 1.452), Palette.glow(&"amber"), false)
	else:
		_fire_glow = Geo.block(self, Vector3(0.4, 0.25, 0.02), Vector3(-1.5, 0.35, 1.58), Palette.glow(&"amber"), false)
	_fire = Geo.omni(self, Vector3(-1.5, 0.4, 1.2), 3.4, 0.65, Color(1.0, 0.5, 0.15))
	_build_stove_controls()
	_fire.shadow_enabled = Settings.quality >= 1
	_fire.shadow_bias = 0.15
	_fire.shadow_normal_bias = 2.0

	# Тепловое марево (конвективное преломление горячего воздуха над плитой печи)
	_stove_haze = _build_stove_haze(Vector3(-1.5, 1.25, 1.1))
	add_child(_stove_haze)

	# Звук горения пламени и уютного потрескивания дров в печи
	_stove_fire_player = AudioStreamPlayer3D.new()
	_stove_fire_player.stream = AudioDirector.cached_stream("res://assets/audio/fire_loop.ogg")
	_stove_fire_player.unit_size = 4.0
	_stove_fire_player.max_distance = 12.0
	_stove_fire_player.volume_db = -80.0
	_stove_fire_player.bus = &"SFX"
	_stove_fire_player.autoplay = true
	stove.add_child(_stove_fire_player)
	_stove_fire_player.play()

	_stove_crackle_player = AudioStreamPlayer3D.new()
	var crackle_stream := load("res://assets/sfx/cc0/stove_crackle_loop.ogg") as AudioStream
	if crackle_stream is AudioStreamOggVorbis:
		crackle_stream = crackle_stream.duplicate()
		(crackle_stream as AudioStreamOggVorbis).loop = true
	_stove_crackle_player.stream = crackle_stream
	_stove_crackle_player.unit_size = 3.8
	_stove_crackle_player.max_distance = 11.0
	_stove_crackle_player.volume_db = -80.0
	_stove_crackle_player.bus = &"SFX"
	_stove_crackle_player.autoplay = true
	stove.add_child(_stove_crackle_player)
	_stove_crackle_player.play()

	# Дровница у печи с запасом дров (0..3 полена)
	_woodbox_count = 2
	_woodbox_it = Geo.interactable(self, Vector3(0.75, 0.55, 0.5), Vector3(-0.65, 0.25, 1.1), null, "", _on_woodbox_used)
	_woodbox_it.prompt_provider = _woodbox_prompt
	_woodbox_it.name = "Woodbox"
	_update_woodbox_visual()

	# Оберег: Угощение Суседке (домовому) у подпечья
	_susedko_hearth = Creatures.make_susedko_hearth()
	_susedko_hearth.position = Vector3(-0.95, 0.04, 0.6)
	_susedko_hearth.rotation.y = deg_to_rad(-45.0)
	add_child(_susedko_hearth)

	var saucer_mesh := Geo.box_mesh(Vector3(0.18, 0.02, 0.18), Palette.m(&"wood"))
	saucer_mesh.position = Vector3(-0.95, 0.06, 0.6)
	saucer_mesh.visible = Game.spirit_treat
	add_child(saucer_mesh)

	var bread_mesh := Geo.box_mesh(Vector3(0.08, 0.04, 0.06), Palette.m(&"cloth"))
	bread_mesh.position = Vector3(-0.95, 0.09, 0.6)
	bread_mesh.visible = Game.spirit_treat
	add_child(bread_mesh)
	_treat_bread = bread_mesh

	var spirit_it := Geo.interactable(self, Vector3(0.35, 0.25, 0.35), Vector3(-0.95, 0.12, 0.6), null, "", func(_p: Player) -> void:
		if not Game.spirit_treat:
			Game.spirit_treat = true
			saucer_mesh.visible = true
			bread_mesh.visible = true
			_treat_set_min = Game.shift_minutes
			Game.hud.subtitle(Loc.t(&"sub.spirit_treat_set"), 3.5)
			Director.add_tension(-8.0, "угощение домовому")
	)
	spirit_it.prompt_provider = func() -> String:
		return "" if Game.spirit_treat else Loc.t(&"it.spirit_treat")

	# Пачка папирос «Беломорканал» на краю обеденного стола (висела в воздухе: подоконника там нет)
	var belomor_prop := Node3D.new()
	belomor_prop.position = Vector3(1.7, 0.762, 4.32)
	belomor_prop.rotation.y = 0.4
	Geo.block(belomor_prop, Vector3(0.08, 0.02, 0.12), Vector3.ZERO, Palette.m(&"paper"), false)
	Geo.block(belomor_prop, Vector3(0.082, 0.022, 0.04), Vector3(0.0, 0.0, -0.04), Palette.m(&"metal"), false)
	add_child(belomor_prop)
	Geo.interactable(self, Vector3(0.25, 0.2, 0.25), Vector3(1.7, 0.79, 4.32), null, Loc.t(&"it.belomor"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.belomor"), 4.0)
	)

	# Полочка на кованых кронштейнах — на ней «Спидола» (раньше висела на голой стене)
	Geo.block(self, Vector3(0.44, 0.025, 0.18), Vector3(0.8, 1.245, 0.19), Palette.m(&"wood"), false)
	for sx: float in [-0.16, 0.16]:
		var br := Geo.block(self, Vector3(0.02, 0.12, 0.14), Vector3(0.8 + sx, 1.175, 0.17), Palette.m(&"metal"), false)
		br.rotation.x = 0.35
	# Транзисторный приёмник «Спидола-232» на полке
	var spidola_prop := Node3D.new()
	spidola_prop.position = Vector3(0.8, 1.348, 0.2)
	Geo.block(spidola_prop, Vector3(0.28, 0.18, 0.08), Vector3.ZERO, Palette.m(&"wood"), false)
	Geo.block(spidola_prop, Vector3(0.24, 0.06, 0.082), Vector3(0.0, 0.04, 0.0), Palette.m(&"metal"), false)
	add_child(spidola_prop)
	Geo.interactable(self, Vector3(0.35, 0.3, 0.25), Vector3(0.8, 1.35, 0.15), null, Loc.t(&"it.spidola"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.spidola"), 4.0)
	)

	# Чайник на горячей печи
	_kettle = Props.kettle()
	_kettle.position = Vector3(-1.67, 1.35, 1.15)   # на левой конфорке: по центру плиты он уходил в трубу
	_kettle.scale = Vector3(0.85, 0.85, 0.85)
	add_child(_kettle)

	# Тонкий пар из носика чайника
	_kettle_steam = CPUParticles3D.new()
	_kettle_steam.name = "KettleSteam"
	_kettle_steam.position = Vector3(0.14, 0.16, 0.0)
	_kettle_steam.direction = Vector3(0.3, 1.0, 0.0)
	_kettle_steam.spread = 15.0
	_kettle_steam.initial_velocity_min = 0.15
	_kettle_steam.initial_velocity_max = 0.35
	_kettle_steam.scale_amount_min = 0.05
	_kettle_steam.scale_amount_max = 0.18
	_kettle_steam.amount = 10
	_kettle_steam.lifetime = 1.4
	var k_qm := QuadMesh.new()
	k_qm.size = Vector2(0.12, 0.12)
	_kettle_steam.mesh = k_qm
	var k_mat := StandardMaterial3D.new()
	k_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	k_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	k_mat.albedo_color = Color(0.95, 0.95, 0.95, 0.25)
	k_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_kettle_steam.material_override = k_mat
	_kettle_steam.emitting = Game.stove_wood > 0.0 or not Game.is_prologue()
	_kettle.add_child(_kettle_steam)

	# Интерактив — дочерний к чайнику: когда «чайник переедет на стол», переедет и он.
	var kettle_it := Geo.interactable(_kettle, Vector3(0.5, 0.5, 0.5), Vector3.ZERO, null, Loc.t(&"it.kettle"), _on_kettle_used)
	kettle_it.name = "StoveKettle"
	kettle_it.prompt_provider = func() -> String:
		if Game.player != null and Game.player.held == &"kettle":
			return Loc.t(&"it.kettle_return")
		if _kettle != null and not _kettle.visible:
			return ""
		return Loc.t(&"it.kettle")

	# Войлочные валенки у чугунной печки
	var valenki_prop := Props.valenki()
	valenki_prop.position = Vector3(-2.1, 0.05, 1.35)
	valenki_prop.rotation.y = deg_to_rad(25.0)
	add_child(valenki_prop)
	Geo.interactable(self, Vector3(0.4, 0.5, 0.4), Vector3(-2.1, 0.25, 1.35), null, Loc.t(&"it.valenki"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"it.valenki"), 3.5)
	)

	# 2. Железная кровать дежурного с панцирной сеткой
	var bed := Geo.interactable(self, Vector3(1.0, 0.5, 2.1), Vector3(-1.4, 0.225, 5.2), null, "", _on_bed_used)
	bed.prompt_provider = _bed_prompt
	var bed_mesh := Props.bed()
	bed_mesh.position.y = -0.225
	bed.add_child(bed_mesh)

	# Экспедиционный рундук у кровати дежурного
	_living_trunk = Props.expedition_trunk()
	_living_trunk.position = Vector3(-0.45, 0.05, 5.15)
	_living_trunk.rotation.y = deg_to_rad(18.0)
	add_child(_living_trunk)
	_update_living_trunk_visibility()

	# 3. Обеденный / чайный стол с латунным самоваром и фарфоровой посудой
	_collider(Vector3(1.4, 0.75, 1.0), Vector3(1.2, 0.375, 4.0))
	_place(Props.desk(), Vector3(1.2, 0.0, 4.0))

	var samovar := Props.samovar()
	samovar.position = Vector3(1.2, 0.75, 4.0)
	add_child(samovar)

	var teapot_living := Props.kettle()
	teapot_living.position = Vector3(1.5, 0.75, 4.15)
	teapot_living.scale = Vector3(0.7, 0.7, 0.7)
	add_child(teapot_living)

	# Стулья у стола
	var chair1 := _collider(Vector3(0.45, 0.45, 0.45), Vector3(1.2, 0.225, 3.2))
	chair1.add_child(Props.chair())
	var chair2 := _collider(Vector3(0.45, 0.45, 0.45), Vector3(1.2, 0.225, 4.8))
	chair2.add_child(Props.chair())

	# 4. Книжные полки / шкаф у восточной стены
	_collider(Vector3(0.4, 1.6, 1.2), Vector3(3.2, 0.8, 5.5))
	_place(Props.shelf(), Vector3(3.2, 0.0, 5.5)).rotation.y = PI   # задней стенкой к стене, полками в комнату

	# 5. Настенные часы «Янтарь» с маятником и мерным тиканьем
	var clock := Props.wall_clock()
	clock.position = Vector3(1.2, 1.85, 0.12)
	add_child(clock)
	_clock_pendulum = clock.find_child("Pendulum", true, false)
	_clock_player = AudioStreamPlayer3D.new()
	_clock_player.stream = AudioDirector.cached_stream("res://assets/audio/clock_tick.ogg")
	_clock_player.unit_size = 3.2
	_clock_player.max_distance = 10.0
	_clock_player.volume_db = -3.0
	_clock_player.bus = &"SFX"
	_clock_player.autoplay = true
	clock.add_child(_clock_player)
	_clock_player.play()

	Geo.interactable(self, Vector3(0.35, 0.55, 0.2), Vector3(1.2, 1.85, 0.12), null, Loc.t(&"it.clock"), func(_p: Player) -> void:
		_on_clock_interact()
	)

	# 5b. Фотография бригады метеорологов станции «Кедр-7» в деревянной рамке
	Models.spawn(self, "kaykit/pictureframe_large_A", Vector3(2.1, 1.80, 0.12), 0.0, 0.45, {"tint": Color(0.85, 0.78, 0.65)})
	Geo.interactable(self, Vector3(0.45, 0.45, 0.2), Vector3(2.1, 1.80, 0.12), null, Loc.t(&"it.crew_photo"), func(_p: Player) -> void:
		var photo_txt := Loc.t(&"sub.crew_photo_n1")
		if Game.is_night():
			if Game.night >= 5:
				photo_txt = Loc.t(&"sub.crew_photo_n5")
				Game.audio.play_2d("res://assets/audio/whisper.ogg", -6.0)
				Director.add_tension(10.0, "четвёртый на фото")
			elif Game.night >= 3:
				photo_txt = Loc.t(&"sub.crew_photo_n3")
				Director.add_tension(4.0, "лицо Семёнова на фото")
		Game.hud.subtitle(photo_txt, 4.5)
	)

	# 6. Освещение жилой комнаты
	var ceiling := Geo.omni(self, Vector3(0.5, 2.65, 3.3), 6.0, 1.05, Color(1.0, 0.74, 0.46))
	ceiling.omni_attenuation = 1.7   # свет лампы падает быстро: середина комнаты в тёплом пятне, углы тонут
	ceiling.shadow_enabled = false
	Geo.bulb(ceiling, &"bulb")
	register_lamp(ceiling)


func _build_stove_haze(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "StoveHeatHaze"
	root.position = at
	var q := QuadMesh.new()
	q.size = Vector2(0.85, 0.55)
	_stove_haze_mat = ShaderMaterial.new()
	_stove_haze_mat.shader = load("res://assets/shaders/heat_haze.gdshader")
	for rot_y in [0.0, PI * 0.5]:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = _stove_haze_mat
		mi.rotation.y = rot_y
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.visible = false
	return root


func _build_radio_room() -> void:
	# 1. Широкий операторский стол под северным окном на площадку
	_collider(Vector3(2.4, 0.75, 1.0), Vector3(9.2, 0.375, -1.3))
	_place(Props.desk(), Vector3(9.2, 0.0, -1.3))

	# Радиостанция Р-250 «Кит»
	var radio_set := Geo.interactable(self, Vector3(0.9, 0.45, 0.4), Vector3(9.2, 0.96, -1.5), null, Loc.t(&"it.radio"), _on_radio_used)
	radio_set.name = "RadioSet"
	radio_set.prompt_provider = func() -> String:
		if Game.is_day() and Game.aftermath != null and Game.aftermath.is_call_ringing():
			return Loc.t(&"it.answer_call")
		return Loc.t(&"it.radio")
	# Модель из Блендера (tools/blender/r250.py): запечённые цвет + AO, свой износ — без триплан-грязи
	if Models.spawn(radio_set, "kedr/r250", Vector3(0, -0.21, 0), 0.0, 0.42, {"grime": 0.0, "bright": 1.25, "sat": 0.85}) == null:
		radio_set.add_child(Props.radio())
	# Подсветка шкалы-барабана: тёплое пятно на шкале, будто лампочки за ней
	var scale_lamp := OmniLight3D.new()
	scale_lamp.light_color = Color(1.0, 0.68, 0.32)
	scale_lamp.light_energy = 0.35
	scale_lamp.omni_range = 0.32
	scale_lamp.shadow_enabled = false
	scale_lamp.position = Vector3(-0.17, 0.07, 0.3)
	radio_set.add_child(scale_lamp)
	register_lamp(scale_lamp)

	# Бланк заявки на снабжение (пайки → ящик с вертолёта)
	var form := Geo.interactable(self, Vector3(0.28, 0.05, 0.22), Vector3(8.8, 0.78, -1.0), null, Loc.t(&"it.supply_form"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"supply"))
	form.name = "SupplyForm"
	var paper := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(0.21, 0.004, 0.29)
	paper.mesh = pbox
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.86, 0.83, 0.74)
	paper.material_override = pmat
	paper.position = Vector3(0, -0.02, 0)
	paper.rotation.y = 0.2
	form.add_child(paper)

	# Журнал метеонаблюдений
	var journal := Geo.interactable(self, Vector3(0.3, 0.06, 0.36), Vector3(9.1, 0.78, -1.05), null, Loc.t(&"it.journal"), _on_journal_used)
	var book := Props.book()
	book.position.y = -0.03
	book.rotation.y = deg_to_rad(12.0)
	journal.add_child(book)

	# Магнитофон «Весна-306»
	_tape_deck = Geo.interactable(self, Vector3(0.38, 0.12, 0.26), Vector3(9.92, 0.81, -1.02), null, Loc.t(&"it.tape"), _on_tape_used)
	var deck_model := Props.tape_deck()
	deck_model.position.y = -0.06
	_tape_deck.add_child(deck_model)

	# Советский недельный барограф М-22 («Дыхание станции») под стеклянным колпаком
	var barograph_it := Geo.interactable(self, Vector3(0.38, 0.24, 0.24), Vector3(8.5, 0.87, -1.48), null, Loc.t(&"it.barograph"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"barograph")
	)
	barograph_it.name = "BarographM22"
	var baro_model := Props.barograph()
	baro_model.position.y = -0.12
	barograph_it.add_child(baro_model)
	# Крупный план (BarographUI) прячет модель и ставит на её место свой барабан: где стол и куда лицом
	baro_model.add_to_group(&"barograph_model")
	baro_model.set_meta(&"rig_base", Vector3(8.55, 0.75, -1.45))   # чуть правее: тумба «Слухача» не лезет в кадр
	baro_model.set_meta(&"rig_yaw", 0.0)

	# Грунтовый геофон и сейсмоприемник СВ-20 («Слухач») на отдельной виброизолированной тумбе
	_collider(Vector3(0.50, 0.75, 0.50), Vector3(7.70, 0.375, -1.35))
	var plinth := Props.instrument_plinth()
	plinth.position = Vector3(7.70, 0.0, -1.35)
	add_child(plinth)
	var sv20_it := Geo.interactable(self, Vector3(0.40, 0.28, 0.32), Vector3(7.70, 0.87, -1.35), null, "", func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"seismograph")
	)
	sv20_it.prompt_provider = func() -> String:
		return Loc.t(&"it.sv20_remove") if Game.sv20_active else Loc.t(&"it.sv20_listen")
	sv20_it.name = "SeismographSV20"
	var sv20_model := Props.seismograph_sv20()
	sv20_model.position.y = -0.12
	sv20_it.add_child(sv20_model)


	if not is_backdrop:
		var radio := Radio.new()
		radio.name = "Radio"
		radio.position = Vector3(9.2, 1.0, -1.4)
		add_child(radio)

	# Настольная лампа на гибкой ножке
	_place(Props.desk_lamp(), Vector3(8.22, 0.75, -1.6))
	register_lamp(Geo.omni(self, Vector3(8.35, 1.15, -1.3), 2.4, 0.7, Color(1.0, 0.82, 0.6)))

	# Мельхиоровый советский подстаканник с горячим чаем
	# Чай — один на двоих с чайником: общий «откат», и горячий он, только пока топится печь.
	var tea_it := Geo.interactable(self, Vector3(0.2, 0.25, 0.2), Vector3(8.52, 0.85, -0.98), null, Loc.t(&"it.podstakannik"), func(_p: Player) -> void:
		if Game.tea_cd > 0.0:
			Game.hud.subtitle(Loc.t(&"sub.kettle_recent"), 2.5)
			return
		if Game.stove_wood <= 0.0:
			Game.hud.subtitle(Loc.t(&"sub.tea_cold"), 2.5)
			return
		Game.tea_cd = 90.0
		Game.audio.play_2d("res://assets/audio/tea_sip.ogg", 0.0)
		Game.warmth = minf(Game.warmth + 12.0, 100.0)
		Game.tea_warmth_timer = 40.0
		Game.hud.subtitle(Loc.t(&"sub.tea_drunk"), 3.5)
		Director.add_tension(-3.0, "горячий чай")
	)

	# Вахтенный журнал метеонаблюдений ТМ-1 (на столе перед оператором)
	var journal_it := Geo.interactable(self, Vector3(0.42, 0.12, 0.36), Vector3(9.5, 0.77, -1.05), null, Loc.t(&"it.journal_tm1"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"journal")
	)
	var j_model := Props.journal_tm1()
	j_model.position.y = -0.02
	journal_it.add_child(j_model)

	# Фототелеграфный факс-терминал ИСЗ «Метеор-2» (на правом крыле стола)
	var fax_it := Geo.interactable(self, Vector3(0.48, 0.32, 0.40), Vector3(10.0, 0.88, -1.47), null, Loc.t(&"it.meteor_fax"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"meteor_fax")
	)
	var fax_model := Props.meteor_fax()
	fax_model.position.y = -0.12
	fax_it.add_child(fax_model)

	var pod := Props.podstakannik()
	pod.position.y = -0.10
	tea_it.add_child(pod)


	# Теневой силуэт в отражении стекла северного окна
	_window_shadow = Geo.box_mesh(Vector3(0.42, 1.75, 0.1), Palette.m(&"dark"))
	_window_shadow.position = Vector3(9.2, 1.4, -2.08)
	_window_shadow.visible = false
	add_child(_window_shadow)

	# 2. Кресло оператора
	var op_chair := _collider(Vector3(0.45, 0.45, 0.45), Vector3(9.2, 0.225, -0.6))
	op_chair.add_child(Props.chair())
	props["chair"] = {"node": op_chair, "changed": false, "apply": _turn_chair.bind(op_chair)}

	# 3. Тяжёлый стальной советский сейф ГО у восточной стены
	_collider(Vector3(0.65, 1.1, 0.65), Vector3(11.1, 0.55, -1.3))
	var safe := Props.safe()
	safe.position = Vector3(11.1, 0.0, -1.3)
	safe.rotation.y = deg_to_rad(-90.0)
	add_child(safe)

	var safe_it := Geo.interactable(self, Vector3(0.7, 1.1, 0.7), Vector3(11.1, 0.55, -1.3), null, "", _on_safe_interact)
	safe_it.name = "SafeGO"
	safe_it.prompt_provider = func() -> String:
		if Game.safe_opened:
			return Loc.t(&"it.safe_opened")
		if Game.safe_code_known:
			return Loc.t(&"it.safe_enter_code")
		return Loc.t(&"it.safe_locked")

	# 4. Шкафы с архивами метеожурналов вдоль западной стены
	_collider(Vector3(0.4, 1.6, 1.6), Vector3(3.8, 0.8, 0.0))
	_place(Props.shelf(), Vector3(3.8, 0.0, 0.0))
	Geo.block(self, Vector3(0.3, 0.25, 0.35), Vector3(3.8, 1.73, 0.2), Palette.m(&"metal"), false)

	# 5. Схема станции на стене (карта по клавише M)
	var scheme := Geo.interactable(self, Vector3(0.7, 0.5, 0.02), Vector3(3.7, 1.55, 1.0), Palette.m(&"paper"), Loc.t(&"it.scheme"), func(_p: Player) -> void: EventBus.ui_requested.emit(&"map"))
	scheme.name = "Scheme"
	scheme.rotation.y = deg_to_rad(90.0)

	# 6. Настенные часы над северным окном / столом
	_clock_label = Label3D.new()
	_clock_label.text = "00:00"
	_clock_label.font_size = 48
	_clock_label.pixel_size = 0.004
	_clock_label.modulate = Color(0.9, 0.85, 0.7)
	_clock_label.outline_size = 0
	_clock_label.shaded = true
	_clock_label.position = Vector3(9.2, 2.4, -1.98)
	add_child(_clock_label)
	Geo.block(self, Vector3(0.36, 0.16, 0.02), Vector3(9.2, 2.4, -1.99), Palette.m(&"dark"), false)
	props["clock"] = {"node": _clock_label, "changed": false, "apply": _stop_clock}

	# 7. Верхнее освещение радиорубки
	var rad_ceil := Geo.omni(self, Vector3(7.5, 2.65, 0.1), 6.0, 1.0, Color(1.0, 0.74, 0.46))
	rad_ceil.omni_attenuation = 1.7
	rad_ceil.shadow_enabled = false
	Geo.bulb(rad_ceil, &"bulb")
	register_lamp(rad_ceil)

	# 8. Уют и детализация радиорубки:
	# Тканая дорожка-половик от проёма к операторскому столу
	var carpet := Props.carpet(1.1, 3.2)
	carpet.position = Vector3(8.2, 0.055, 0.2)
	add_child(carpet)

	# Советский настенный радиорепродуктор «Рекорд» (черная тарелка) на перегородке с коридором
	var plate := Props.radio_speaker_plate()
	plate.position = Vector3(6.5, 1.85, 2.08)
	plate.rotation.y = deg_to_rad(180.0)
	add_child(plate)

	# Латунный барометр-анероид на стене у стола
	var baro := Props.barometer()
	baro.position = Vector3(10.8, 1.75, -1.88)
	add_child(baro)
	var baro_it := Geo.interactable(self, Vector3(0.35, 0.35, 0.15), Vector3(10.8, 1.75, -1.88), null, Loc.t(&"it.barometer"), func(_p: Player) -> void:
		var press := int(748.0 - (Game.weather.intensity if Game.weather != null else 0.0) * 22.0)
		Game.hud.subtitle(Loc.t(&"sub.barometer", [press]), 3.5)
	)
	baro_it.name = "AneroidBarometer"

	# Настольная керосиновая лампа «Летучая мышь» на операторском столе (аварийный свет без генератора)
	_kerosene_lamp_prop = Props.kerosene_lamp()
	_kerosene_lamp_prop.position = Vector3(8.28, 0.75, -1.0)
	add_child(_kerosene_lamp_prop)

	_kerosene_light = Geo.omni(self, Vector3(8.28, 1.0, -1.0), 4.2, 0.0, Color(1.0, 0.65, 0.25))
	_kerosene_light.shadow_enabled = false
	_kerosene_light.visible = false

	var lamp_it := Geo.interactable(self, Vector3(0.3, 0.45, 0.3), Vector3(8.28, 0.95, -1.0), null, "", _on_kerosene_lamp_used)
	lamp_it.name = "KeroseneLamp"
	lamp_it.prompt_provider = func() -> String:
		return Loc.t(&"it.kerosene_lamp_off") if _kerosene_lit else Loc.t(&"it.kerosene_lamp_on")

	# Протирка стекла северного окна от инея и наледи
	_wipe_it = Geo.interactable(self, Vector3(0.9, 0.6, 0.3), Vector3(9.2, 1.45, -1.95), null, "", func(_p: Player) -> void:
		if not _window_wiped:
			_window_wiped = true
			if is_instance_valid(_wipe_it):
				_wipe_it.collision_layer = 0
			Game.audio.play_2d("res://assets/audio/step_snow_1.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.window_wiped"), 3.5)
		else:
			Game.hud.subtitle(Loc.t(&"sub.window_wiped"), 2.0)
	)
	_wipe_it.name = "WindowWipe"
	_wipe_it.prompt_provider = func() -> String:
		return Loc.t(&"it.window_wipe") if not _window_wiped else ""

	_build_props()


func _on_safe_interact(_p: Player) -> void:
	if Game.safe_opened:
		Game.hud.subtitle(Loc.t(&"sub.safe_already_looted"), 3.0)
		return
	if not Game.safe_code_known:
		Game.hud.subtitle(Loc.t(&"sub.safe_code_needed"), 4.0)
		return
	Game.safe_opened = true
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 2.0)
	AudioDirector.play_raw("res://assets/audio/door.ogg", 0.0)
	Game.flares = minf(Game.flares + 2, 8)
	Game.warmth = minf(Game.warmth + 35.0, 100.0)
	Director.add_tension(-14.0, "открыт аварийный сейф ГО")
	Game.hud.subtitle(Loc.t(&"sub.safe_opened_rewards"), 5.5)


func _on_clock_interact() -> void:
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
	var txt := Loc.t(&"it.clock_n1")
	if Game.is_night():
		if Game.night >= 5:
			txt = Loc.t(&"it.clock_n5")
			Director.add_tension(6.0, "замершие ходики")
		elif Game.night >= 3:
			txt = Loc.t(&"it.clock_n3")
	Game.hud.subtitle(txt, 4.0)


## Предметы для «изменений в доме»: каждый знает, как выглядит после подмены.
func _build_props() -> void:
	# Эмалированная кружка на столе жилой комнаты → на полу у печи
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.04
	cm.height = 0.1
	cm.radial_segments = 8
	cup.mesh = cm
	cup.material_override = Palette.m(&"white")
	cup.position = Vector3(1.2, 0.8, 3.8)
	add_child(cup)
	props["cup"] = {"node": cup, "changed": false, "apply": _move_cup.bind(cup)}

	# Фото на стене жилой комнаты: старая советская фотография в деревянной рамке
	var photo := Node3D.new()
	photo.position = Vector3(0.5, 1.6, 0.12)
	add_child(photo)
	Geo.block(photo, Vector3(0.38, 0.48, 0.02), Vector3.ZERO, Palette.m(&"wood"), false)
	# Снимок: сепия, двое у ельника (рисуется один раз); третий — проступает поверх (паранойя)
	photo.add_child(_photo_quad(_photo_image(false), Vector2(0.32, 0.42), 0.011))
	var extra := _photo_quad(_photo_image(true), Vector2(0.32, 0.42), 0.013)
	photo.add_child(extra)
	extra.visible = false
	props["photo"] = {"node": photo, "changed": false, "apply": _show_node.bind(extra)}

	# Чайник на плите (тот же, что для чая) → сам перемещается на обеденный стол
	if _kettle != null:
		props["teapot"] = {"node": _kettle, "changed": false, "apply": _move_teapot}

	# Угольное ведро у печи → сдвигается в дверной проём коридора
	var bucket := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.14
	bm.bottom_radius = 0.11
	bm.height = 0.28
	bucket.mesh = bm
	bucket.material_override = Palette.m(&"metal")
	bucket.position = Vector3(-0.65, 0.19, 1.2)
	add_child(bucket)
	props["bucket"] = {"node": bucket, "changed": false, "apply": func() -> void:
		bucket.position = Vector3(3.5, 0.19, 3.1)
	}

	# Гаечный ключ: тихо оказывается на кровати дежурного
	var wrench := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.04, 0.015, 0.24)
	wrench.mesh = wm
	wrench.material_override = Palette.m(&"metal")
	wrench.position = Vector3(3.8, 0.95, 0.0)
	add_child(wrench)
	props["tools"] = {"node": wrench, "changed": false, "apply": func() -> void:
		wrench.position = Vector3(-1.4, 0.46, 5.2)
		wrench.rotation.y = deg_to_rad(30.0)
	}

	# Журнал: новая строчка твоим почерком
	props["journal"] = {"node": get_node("RadioSet"), "changed": false, "apply": _noop}


func _move_teapot() -> void:
	if _kettle != null:
		_kettle.position = Vector3(1.2, 0.77, 4.0)
		_kettle.rotation.y = deg_to_rad(45.0)


func _move_cup(cup: Node3D) -> void:
	cup.position = Vector3(-0.8, 0.095, 1.6)
	cup.rotation = Vector3(deg_to_rad(90.0), 0.0, deg_to_rad(30.0))


func _show_node(n: Node3D) -> void:
	n.visible = true


func _turn_chair(chair: Node3D) -> void:
	chair.position = Vector3(9.2, 0.225, -1.0)
	chair.rotation.y = deg_to_rad(180.0)


func _stop_clock() -> void:
	_clock_label.text = "03:00"


func _noop() -> void:
	pass


func _build_corridor() -> void:
	# 1. Тусклая качающаяся лампочка на длинном проводе (маятниковая анимация в _process)
	_swinging_bulb = Node3D.new()
	_swinging_bulb.position = Vector3(7.5, ROOM_H, 4.4)
	add_child(_swinging_bulb)
	Geo.cylinder(_swinging_bulb, 0.007, 0.58, Vector3(0.0, -0.29, 0.0), Palette.m(&"dark"), false)
	var socket := Geo.cylinder(_swinging_bulb, 0.022, 0.06, Vector3(0.0, -0.58, 0.0), Palette.m(&"metal"), false)
	var bulb_omni := Geo.omni(_swinging_bulb, Vector3(0.0, -0.64, 0.0), 7.5, 0.9, Color(1.0, 0.86, 0.68))
	bulb_omni.shadow_enabled = Settings.quality >= 2   # скользящие тени по коридору — с высокого пресета
	_bulb_omni = bulb_omni
	bulb_omni.shadow_bias = 0.12
	bulb_omni.shadow_normal_bias = 2.0
	Geo.bulb(bulb_omni, &"bulb", 0.065)
	register_lamp(bulb_omni)

	# 3. Вешалка с тёплыми ватниками на южной стене коридора
	Geo.block(self, Vector3(0.9, 0.1, 0.05), Vector3(10.2, 1.6, 6.45), Palette.m(&"wood"), false)
	Geo.block(self, Vector3(0.35, 0.85, 0.15), Vector3(10.0, 1.25, 6.4), Palette.m(&"cloth"), false)
	Geo.block(self, Vector3(0.35, 0.90, 0.15), Vector3(10.4, 1.22, 6.4), Palette.m(&"dark"), false)


func _build_storage() -> void:
	# Холодная аккумуляторная / кладовая: тёмный глухой чулан БЕЗ окон и БЕЗ электрического света
	# Стеллажи со свинцово-кислотными банками аккумуляторов
	_collider(Vector3(1.3, 1.1, 0.55), Vector3(3.9, 0.55, -3.8))
	var battery := Props.battery_rack()
	battery.position = Vector3(3.9, 0.0, -3.8)
	add_child(battery)

	# Стеллаж с запасами и метеоприборами вдоль восточной стены
	_collider(Vector3(0.5, 1.7, 1.5), Vector3(6.75, 0.85, -3.8))
	var shelves := Props.storage_shelves()
	shelves.position = Vector3(6.75, 0.0, -3.8)
	shelves.rotation.y = deg_to_rad(90.0)
	add_child(shelves)

	# Запасные радиолампы на полке (интерактивный осмотр)
	var tubes := Geo.interactable(self, Vector3(0.35, 0.35, 0.6), Vector3(6.65, 1.34, -3.8), null, Loc.t(&"it.storage_tubes"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.storage_tubes"), 4.0)
	)
	tubes.name = "StorageTubes"

	# Деревянные ящики в тёмном дальнем углу чулана
	# (модель ящика со стяжками вместо голых коробок; коллизия — прежними размерами)
	_collider(Vector3(0.7, 0.5, 0.6), Vector3(4.2, 0.25, -5.0))
	_collider(Vector3(0.55, 0.45, 0.5), Vector3(4.25, 0.72, -5.0))
	var c1 := Props.crate()
	c1.scale = Vector3(0.875, 0.833, 1.0)
	c1.position = Vector3(4.2, 0.0, -5.0)
	c1.rotation.y = deg_to_rad(8.0)
	add_child(c1)
	var c2 := Props.crate()
	c2.scale = Vector3(0.69, 0.75, 0.833)
	c2.position = Vector3(4.25, 0.5, -5.0)
	c2.rotation.y = deg_to_rad(-12.0)
	add_child(c2)

	# «Зенит-Е» Семёнова на ящике: плёнка, лампы-вспышки — проявка утром
	if not Game.has_item(&"zenit"):
		var cam_it := Geo.interactable(self, Vector3(0.3, 0.2, 0.3), Vector3(4.25, 1.04, -5.0), null, Loc.t(&"it.zenit"), func(_p: Player) -> void:
			Game.give_item(&"zenit")
			Game.audio.play_2d("res://assets/audio/clank.ogg", -10.0)
			Game.hud.subtitle(Loc.t(&"sub.zenit_found", [OS.get_keycode_string(Game.key_of(&"photo") as Key), Game.pad_name(&"photo"), Game.pad_name(&"photo_shoot")]), 6.0)
			var n := get_node_or_null("ZenitCam")
			if n != null:
				n.queue_free())
		cam_it.name = "ZenitCam"
		var body := Geo.block(cam_it, Vector3(0.15, 0.09, 0.07), Vector3(0, -0.05, 0), Palette.m(&"dark"), false)
		body.rotation.y = deg_to_rad(20.0)
		var top := Geo.block(cam_it, Vector3(0.05, 0.035, 0.05), Vector3(0, 0.01, 0), Palette.m(&"metal"), false)
		top.rotation.y = deg_to_rad(20.0)
		var lens := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.028
		lm.bottom_radius = 0.03
		lm.height = 0.06
		lens.mesh = lm
		lens.material_override = Palette.m(&"metal")
		lens.rotation = Vector3(deg_to_rad(90.0), deg_to_rad(20.0), 0)
		lens.position = Vector3(sin(deg_to_rad(20.0)) * 0.06, -0.05, cos(deg_to_rad(20.0)) * 0.06)
		cam_it.add_child(lens)

	# Бензиновая паяльная лампа на полке кладовой
	var torch := Props.blowtorch()
	torch.position = Vector3(6.65, 0.82, -3.4)
	torch.rotation.y = deg_to_rad(-90.0)
	add_child(torch)
	var torch_it: Interactable = null
	torch_it = Geo.interactable(self, Vector3(0.35, 0.35, 0.35), Vector3(6.65, 0.95, -3.4), null, Loc.t(&"it.blowtorch"), func(p: Player) -> void:
		if p != null:
			if p.held != &"":
				Game.hud.subtitle(Loc.t(&"sub.hands_full"), 2.0)
				return
			p.set_held(&"blowtorch")
			torch.visible = false
			if torch_it != null:
				torch_it.visible = false
				torch_it.collision_layer = 0
			Game.hud.subtitle(Loc.t(&"sub.got_blowtorch"), 4.0)
	)
	torch_it.name = "BlowtorchProp"

	# Стол фотолаборатории с увеличителем «Ленинград-4» и кюветами
	var dr_set := Props.darkroom_set()
	dr_set.position = Vector3(5.7, 0.0, -5.2)
	add_child(dr_set)
	_collider(Vector3(1.3, 1.2, 0.7), Vector3(5.7, 0.6, -5.2))
	var dr_it := Geo.interactable(self, Vector3(1.1, 0.9, 0.7), Vector3(5.7, 0.85, -5.2), null, Loc.t(&"it.darkroom"), func(_p: Player) -> void:
		_open_darkroom()
	)
	dr_it.name = "DarkroomTable"

	# Влажные тающие следы босых ног на дощатом полу кладовой
	_build_storage_footprints()


func _build_storage_footprints() -> void:
	Footprints.trail(self, &"wet", PackedVector3Array([Vector3(5.3, 0, -2.1), Vector3(4.8, 0, -3.6), Vector3(4.2, 0, -5.0)]), 0.05, 0.42)


func _build_vestibule() -> void:
	# Прихожая-тамбур (сени со снегозадержателем):
	# 1. Место для валенок и деревянных лопат от заносов (плотно прислонены к стене, стоят на полу)
	var valenki := Props.valenki()
	valenki.position = Vector3(13.0, 0.05, 1.8)
	add_child(valenki)

	var shovel_it := Geo.interactable(self, Vector3(0.5, 1.5, 0.4), Vector3(14.36, 0.75, 1.8), null, Loc.t(&"it.pick_shovel"), _on_vestibule_shovel_used)
	var shovel1 := Props.snow_shovel()
	shovel1.position = Vector3(0.0, -0.7, 0.0)
	shovel1.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(90.0), 0.0)
	shovel_it.add_child(shovel1)
	_vestibule_shovel = shovel_it

	var shovel2 := Props.snow_shovel()
	shovel2.position = Vector3(14.36, 0.05, 2.15)
	shovel2.rotation = Vector3(deg_to_rad(-4.0), deg_to_rad(90.0), 0.0)
	add_child(shovel2)

	# 2. Вешалка с тулупами и ушанками на восточной стене (та же модель, что в коридоре)
	var coats := Props._kedr_model("coat_hooks", {"bright": 1.15})
	if coats != null:
		add_child(coats)
		coats.position = Vector3(14.385, 0.82, 4.5)
		coats.rotation.y = -PI * 0.5

	# Охотничьи лыжи Семёнова у входа в сени
	var skis_it := Geo.interactable(self, Vector3(0.5, 1.8, 0.4), Vector3(13.6, 0.9, 1.65), null, "", _on_skis_interact)
	skis_it.prompt_provider = func() -> String:
		return Loc.t(&"it.skis_take_off") if Game.skis_equipped else Loc.t(&"it.skis_equip")
	var skis_model := Props.hunting_skis()
	skis_model.position = Vector3(0.0, -0.9, 0.0)
	skis_it.add_child(skis_model)

	# 3. Лавка для просушки обуви и полка для рукавиц
	_collider(Vector3(1.8, 0.42, 0.5), Vector3(12.6, 0.21, 5.8))
	var shoe_bench := Props.izba_bench()
	shoe_bench.position = Vector3(12.6, 0.0, 5.8)
	shoe_bench.scale = Vector3(1.29, 1.0, 1.6)
	add_child(shoe_bench)
	Geo.block(self, Vector3(1.6, 0.05, 0.35), Vector3(12.6, 1.4, 5.85), Palette.m(&"weathered"), false)

	# Весовой снегомер ВС-43 на стене сеней над лавкой
	var vs43_it := Geo.interactable(self, Vector3(0.4, 1.3, 0.3), Vector3(12.6, 1.35, 5.75), null, "", _on_vs43_interact)
	vs43_it.prompt_provider = func() -> String:
		return Loc.t(&"it.vs43_take") if not Game.has_item(&"vs43") else Loc.t(&"it.vs43")
	var vs43_model := Props.snow_tube_vs43()
	vs43_model.position = Vector3(0.0, -0.65, 0.0)
	vs43_it.add_child(vs43_model)

	_build_house_switch()
	# Лампа в тамбуре
	var l_vest := Geo.omni(self, Vector3(13.0, 2.65, 3.5), 4.5, 0.8, Color(1.0, 0.74, 0.46))
	l_vest.omni_attenuation = 1.7
	Geo.bulb(l_vest, &"bulb")
	register_lamp(l_vest)

	# Надутый ветром снег у порога входной двери
	_door_snow = Geo.box_mesh(Vector3(0.65, 0.005, 0.45), Palette.m(&"snow"))
	_door_snow.position = Vector3(14.1, 0.053, 3.1)
	_door_snow.visible = Game.is_night() and Game.night >= 3
	add_child(_door_snow)

	# --- Народные обереги обороны избы ---
	# 1. Соль на пороге
	var salt_mesh := Geo.box_mesh(Vector3(0.12, 0.015, 0.95), Palette.m(&"white"))
	salt_mesh.position = Vector3(14.42, 0.055, 3.1)
	salt_mesh.visible = Game.salt_on_threshold
	add_child(salt_mesh)

	var salt_it := Geo.interactable(self, Vector3(0.35, 0.25, 1.05), Vector3(14.42, 0.12, 3.1), null, "", func(_p: Player) -> void:
		Game.salt_on_threshold = not Game.salt_on_threshold
		salt_mesh.visible = Game.salt_on_threshold
		Game.hud.subtitle(Loc.t(&"sub.salt_spread") if Game.salt_on_threshold else Loc.t(&"sub.salt_cleaned"), 3.5)
	)
	salt_it.prompt_provider = func() -> String:
		return Loc.t(&"it.salt_clean") if Game.salt_on_threshold else Loc.t(&"it.salt_threshold")
	salt_it.collision_layer = Geo.LAYER_INTERACT

	# 2. Нож в притолоке дверного проёма
	var knife_model := Props.hunting_knife()
	knife_model.position = Vector3(11.5, 2.15, 3.1)
	knife_model.rotation.z = deg_to_rad(-90.0)
	knife_model.visible = Game.knife_in_lintel
	add_child(knife_model)

	var knife_it := Geo.interactable(self, Vector3(0.35, 0.4, 0.35), Vector3(11.5, 2.15, 3.1), null, "", func(_p: Player) -> void:
		Game.knife_in_lintel = not Game.knife_in_lintel
		knife_model.visible = Game.knife_in_lintel
		Game.hud.subtitle(Loc.t(&"sub.knife_placed") if Game.knife_in_lintel else Loc.t(&"sub.knife_removed"), 3.5)
	)
	knife_it.prompt_provider = func() -> String:
		return Loc.t(&"it.knife_remove") if Game.knife_in_lintel else Loc.t(&"it.knife_lintel")
	knife_it.collision_layer = Geo.LAYER_INTERACT

	# 3. Зеркало над полкой
	var mirror_frame := Geo.box_mesh(Vector3(0.04, 0.58, 0.44), Palette.m(&"wood"))
	mirror_frame.position = Vector3(12.0, 1.5, 1.55)
	add_child(mirror_frame)
	var mirror_glass := Geo.box_mesh(Vector3(0.01, 0.50, 0.36), Palette.m(&"glass"))
	mirror_glass.position = Vector3(12.02, 1.5, 1.55)
	add_child(mirror_glass)

	var mirror_cloth := Geo.box_mesh(Vector3(0.03, 0.60, 0.46), Palette.m(&"cloth"))
	mirror_cloth.position = Vector3(12.03, 1.5, 1.55)
	mirror_cloth.visible = Game.mirror_covered
	add_child(mirror_cloth)

	var mirror_it := Geo.interactable(self, Vector3(0.25, 0.65, 0.5), Vector3(12.0, 1.5, 1.55), null, "", func(_p: Player) -> void:
		Game.mirror_covered = not Game.mirror_covered
		mirror_cloth.visible = Game.mirror_covered
		Game.hud.subtitle(Loc.t(&"sub.mirror_covered") if Game.mirror_covered else Loc.t(&"sub.mirror_uncovered"), 3.5)
	)
	mirror_it.prompt_provider = func() -> String:
		return Loc.t(&"it.mirror_uncover") if Game.mirror_covered else Loc.t(&"it.mirror_cover")
	mirror_it.collision_layer = Geo.LAYER_INTERACT

	_build_corridor_footprints()
	if not is_backdrop:
		HouseDecor.build(self)   # карта района, календарь, график дежурств, ковёр, фото, вымпел, плакат, бельё, тулуп



## Подтаявшие следы босых ног в коридоре (после 04:00 или поздней ночью)
func _build_corridor_footprints() -> void:
	if not Game.is_night() or Game.night < 3:
		return
	var group := Footprints.trail(self, &"wet", PackedVector3Array([Vector3(13.6, 0, 3.1), Vector3(11.8, 0, 3.1),
		Vector3(10.8, 0, 3.2), Vector3(9.8, 0, 2.6), Vector3(9.3, 0, 1.4), Vector3(9.2, 0, -0.6)]), 0.05, 0.45)
	group.name = "ThawedFootprints"

	# Тонкая «наклейка» на полу: луч её видит, а игрок проходит сквозь (раньше коробка 0.4 м перегораживала проход).
	var it := Geo.interactable(self, Vector3(1.2, 0.04, 2.5), Vector3(11.0, 0.02, 3.1), null, Loc.t(&"it.thawed_footprints"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.thawed_footprints"), 5.0)
	)
	it.collision_layer = Geo.LAYER_INTERACT


func _build_front_door() -> void:
	# Порог дверного проёма: сплошной настил от внутреннего тамбура (14.35) до наружной грани сруба (14.89)
	Geo.block(self, Vector3(0.55, 0.08, 1.14), Vector3(14.62, 0.02, 3.1), Palette.m(&"plank"), false)
	# Боковые откосы (косяки двери), закрывающие пустоту между внутренней и наружной стеной:
	Geo.block(self, Vector3(0.48, 2.20, 0.12), Vector3(14.63, 1.10, 2.54), Palette.m(&"wood"), false)
	Geo.block(self, Vector3(0.48, 2.20, 0.12), Vector3(14.63, 1.10, 3.66), Palette.m(&"wood"), false)
	# Притолока и глухое перекрытие над проёмом до свеса крыши (от 2.05 до 2.80 м):
	Geo.block(self, Vector3(0.24, 0.75, 1.16), Vector3(14.44, 2.425, 3.1), Palette.m(&"plank"), false)
	Geo.block(self, Vector3(0.26, 0.75, 1.16), Vector3(14.68, 2.425, 3.1), Palette.m(&"wood"), false)
	_door_hinge = Node3D.new()
	_door_hinge.position = Vector3(14.5, 0.0, 2.6)
	add_child(_door_hinge)
	var door := Interactable.new()
	door.collision_layer = Geo.LAYER_WORLD
	door.position = Vector3(0.0, 1.0, 0.5)
	door.prompt_provider = func() -> String: return Loc.t(&"it.door_close") if door_open else Loc.t(&"it.door_open")
	door.add_child(Geo.box_shape(Vector3(0.24, 2.0, 1.0), Vector3(0.08, 0, 0)))
	# Дверь из Блендера (tools/blender/front_door.py): снаружи дерматин с гвоздями, внутри доски и засов
	var door_model := Props._kedr_model("front_door", {"center": false})
	if door_model != null:
		door_model.position = Vector3(0, -1.0, 0)
		door.add_child(door_model)
	else:
		door.add_child(Geo.box_mesh(Vector3(0.08, 2.0, 1.0), Palette.m(&"plank")))
		var handle := Geo.box_mesh(Vector3(0.16, 0.04, 0.12), Palette.m(&"metal"))
		handle.position = Vector3(0.0, 0.0, 0.38)
		door.add_child(handle)
	door.used.connect(_on_door_used)
	_door_hinge.add_child(door)

	if Game.is_prologue() and not Game.has_flag("prologue_arrived"):
		door_open = true
		_door_hinge.rotation.y = deg_to_rad(65.0)

	# Глубокие царапины от когтей на наружной стороне двери (появляются с 3-й ночи)
	_door_scratches = Props.claw_scratches()
	_door_scratches.position = Vector3(0.065 if door_model != null else 0.045, 0.15, 0.0)   # поверх обивки
	_door_scratches.rotation.y = deg_to_rad(90.0)
	_door_scratches.visible = Game.is_night() and Game.night >= 3
	door.add_child(_door_scratches)

	# Глазок
	_peephole = Interactable.new()
	_peephole.collision_layer = Geo.LAYER_INTERACT
	_peephole.position = Vector3(-0.06, 0.6, 0.0)
	_peephole.prompt = Loc.t(&"it.peephole")
	_peephole.add_child(Geo.box_mesh(Vector3(0.04, 0.07, 0.07), Palette.m(&"metal")))
	_peephole.add_child(Geo.box_shape(Vector3(0.06, 0.16, 0.16)))
	_peephole.used.connect(func(_p: Player) -> void:
		if Game.is_night():
			Hints.show(&"peephole")
		EventBus.ui_requested.emit(&"peephole"))
	door.add_child(_peephole)

	# Фонарь на подвесе под козырьком крыльца (качается на ветру)
	_porch_bulb = Node3D.new()
	_porch_bulb.position = DOOR_LAMP + Vector3(0.0, 0.28, 0.0)
	add_child(_porch_bulb)
	Geo.cylinder(_porch_bulb, 0.007, 0.28, Vector3(0.0, -0.14, 0.0), Palette.m(&"dark"), false)
	var porch := Geo.omni(_porch_bulb, Vector3(0.0, -0.28, 0.0), 9.5, 1.8, Color(1.0, 0.58, 0.26))
	Atmosphere.add_halo(porch, 1.3)
	Atmosphere.add_halo(porch, 4.0, Color(1.0, 0.68, 0.42, 0.13))
	# Точечный свет с тенями — шесть проходов всего двора за кадр: на «Ультра»; ниже двор тенит луна/солнце
	porch.shadow_enabled = Settings.quality >= 3 and not is_backdrop
	porch.shadow_bias = 0.14
	porch.shadow_normal_bias = 2.0
	Geo.bulb(porch, &"bulb", 0.07)
	register_lamp(porch)

	# Тёплая полоска света из-под закрытой входной двери на крыльцо
	var slit_mesh := QuadMesh.new()
	slit_mesh.size = Vector2(0.96, 0.22)
	_front_door_slit = MeshInstance3D.new()
	_front_door_slit.mesh = slit_mesh
	_front_door_slit.position = Vector3(14.65, 0.052, 3.1)
	_front_door_slit.rotation = Vector3(-PI * 0.5, 0.0, -PI * 0.5)
	_front_door_slit_mat = StandardMaterial3D.new()
	_front_door_slit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_front_door_slit_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_front_door_slit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_front_door_slit_mat.albedo_color = Color(1.0, 0.65, 0.25, 0.82)
	_front_door_slit_mat.albedo_texture = _make_door_slit_texture()
	_front_door_slit.material_override = _front_door_slit_mat
	add_child(_front_door_slit)


func _build_living_door() -> void:
	_living_door_hinge = Node3D.new()
	_living_door_hinge.position = Vector3(3.5, 0.0, 2.62)
	add_child(_living_door_hinge)

	var l_door := Interactable.new()
	l_door.collision_layer = Geo.LAYER_INTERACT
	l_door.position = Vector3(0.0, 1.0, 0.5)
	l_door.prompt_provider = func() -> String: return Loc.t(&"it.door_close") if living_door_open else Loc.t(&"it.door_open")
	l_door.add_child(Geo.box_shape(Vector3(0.08, 2.0, 1.0)))

	# Дверное полотно из сосновых досок с филёнками и латунной ручкой
	var door_mesh := Geo.box_mesh(Vector3(0.045, 1.96, 0.96), Palette.m(&"wood"))
	l_door.add_child(door_mesh)
	var p_top := Geo.box_mesh(Vector3(0.052, 0.72, 0.38), Palette.m(&"wood"))
	p_top.position = Vector3(0.0, 0.42, 0.0)
	l_door.add_child(p_top)
	var p_bot := Geo.box_mesh(Vector3(0.052, 0.62, 0.38), Palette.m(&"wood"))
	p_bot.position = Vector3(0.0, -0.42, 0.0)
	l_door.add_child(p_bot)
	var handle := Geo.box_mesh(Vector3(0.12, 0.035, 0.12), Palette.m(&"metal"))
	handle.position = Vector3(0.0, 0.0, 0.38)
	l_door.add_child(handle)

	l_door.used.connect(_on_living_door_used)
	_living_door_hinge.add_child(l_door)

	# Полоска тёплого света из-под двери в жилую на пол коридора
	var slit_mesh := QuadMesh.new()
	slit_mesh.size = Vector2(0.96, 0.26)
	_living_door_slit = MeshInstance3D.new()
	_living_door_slit.mesh = slit_mesh
	_living_door_slit.position = Vector3(3.64, 0.052, 3.12)
	_living_door_slit.rotation = Vector3(-PI * 0.5, 0.0, -PI * 0.5)
	_living_door_slit_mat = StandardMaterial3D.new()
	_living_door_slit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_living_door_slit_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_living_door_slit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_living_door_slit_mat.albedo_color = Color(1.0, 0.62, 0.22, 0.85)
	_living_door_slit_mat.albedo_texture = _make_door_slit_texture()
	_living_door_slit.material_override = _living_door_slit_mat
	add_child(_living_door_slit)


func _on_living_door_used(_p: Player) -> void:
	if _living_door_busy:
		return
	_living_door_busy = true
	living_door_open = not living_door_open
	Game.audio.play_3d(DOOR_SOUND, _living_door_hinge.global_position, -6.0)
	var target_y := deg_to_rad(-75.0) if living_door_open else 0.0
	var tw := create_tween()
	tw.tween_property(_living_door_hinge, "rotation:y", target_y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _living_door_busy = false)


static func _make_door_slit_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var vy := (float(y) / 31.0) * 2.0 - 1.0
		var side_fade := clampf((1.0 - absf(vy)) * 2.2, 0.0, 1.0)
		for x in 32:
			var ux := float(x) / 31.0
			var depth_fade := exp(-ux * 2.8)
			var a := side_fade * depth_fade
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## Отдельная дизельная будка на заднем дворе станции (перенесена за дом)
## Мостки по ломаной: доски поперёк хода (с лёгким разбросом длины и поворота), под ними две лаги,
## на стыках отрезков — доски веером, по краям кое-где наметён снег.
var _walk_pts: Array = []

## Стоит ли точка на мостках или крыльце — для гулких шагов по доскам.
func on_boardwalk(pos: Vector3) -> bool:
	if pos.x > 14.8 and pos.x < 16.7 and pos.z > 2.0 and pos.z < 4.2 and pos.y < 0.6:
		return true
	for i in range(_walk_pts.size() - 1):
		var a: Vector3 = _walk_pts[i]
		var b: Vector3 = _walk_pts[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(pos.x - a.x, pos.z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (ap - ab * t).length() < 0.62:
			return true
	return false


func _boardwalk(points: Array, width: float) -> void:
	_walk_pts.append_array(points)
	var k := MeshKit.new(77)
	k.mottle = 0.12
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var plank_col := Color(0.42, 0.32, 0.23)
	var beam_col := Color(0.24, 0.18, 0.13)
	var snow_col := Color(0.78, 0.84, 0.92)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a)
		dir.y = 0.0
		var seg := dir.length()
		dir /= seg
		var perp := Vector3(-dir.z, 0, dir.x)
		var yaw := atan2(dir.x, dir.z)
		for s: float in [-0.36, 0.36]:
			k.box((a + b) * 0.5 + perp * (width * s) + Vector3(0, 0.02, 0), Vector3(0.1, 0.08, seg + 0.1), beam_col, Basis(Vector3.UP, yaw))
		var t := 0.12
		while t < seg:
			var c := a + dir * t + Vector3(0, 0.075, 0)
			var basis := Basis(Vector3.UP, yaw + rng.randf_range(-0.04, 0.04))
			k.box(c + perp * rng.randf_range(-0.04, 0.04), Vector3(width + rng.randf_range(-0.06, 0.1), 0.04, 0.2), plank_col, basis)
			if rng.randf() < 0.22:
				var edge := perp * (width * 0.5 + 0.02) * (1.0 if rng.randf() < 0.5 else -1.0)
				k.box(c + edge + Vector3(0, 0.02, 0), Vector3(0.24, 0.08, 0.34), snow_col, basis)
			t += 0.235
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"prop_boardwalk", Color.WHITE, "tex_wood.png", 0.0)
	add_child(mi)


func _build_generator_shack() -> void:
	var shack_center := Vector3(14.5, 0.05, -13.5)

	# 1. Мостки от крыльца к дизельной: поперечные доски на двух лагах, плавно огибают угол дома,
	#    кончаются площадкой у двери будки. Один меш на всё.
	_boardwalk([Vector3(16.25, 0, 2.2), Vector3(16.35, 0, -1.6), Vector3(15.6, 0, -6.0), Vector3(14.6, 0, -10.2), Vector3(14.5, 0, -11.75)], 1.0)
	# Дощатый настил перед входом в дизельную и скошенный порожек
	Geo.block(self, Vector3(2.0, 0.08, 1.3), shack_center + Vector3(0.0, 0.01, 2.0), Palette.m(&"plank"), true)
	Geo.block(self, Vector3(1.3, 0.06, 0.28), shack_center + Vector3(0.0, 0.045, 1.36), Palette.m(&"plank"), true)

	# 2. Путеводный леер к дизельной строится централизованно в Yard._build_rope_lines()

	# 3. Фундамент и дощатый пол будки (x: 12.9..16.1, z: -14.9..-12.1)
	Geo.block(self, Vector3(3.2, 0.1, 2.8), shack_center, Palette.m(&"plank"), true)

	# 4. Будка: стены из вертикального тёса с перекрытием, угловые стойки и наличники голубой краской,
	#    односкатная крыша на север с вылетом, снежная шапка, сосульки, сугробы у стен. Визуал — два меша;
	#    столкновения — невидимые коробки.
	_build_shack_shell(shack_center)
	_collider(Vector3(3.2, 2.2, 0.12), shack_center + Vector3(0, 1.1, -1.34))
	_collider(Vector3(0.12, 2.2, 2.8), shack_center + Vector3(-1.54, 1.1, 0))
	_collider(Vector3(0.12, 2.2, 2.8), shack_center + Vector3(1.54, 1.1, 0))
	_collider(Vector3(1.0, 2.2, 0.12), shack_center + Vector3(-1.1, 1.1, 1.34))
	_collider(Vector3(1.0, 2.2, 0.12), shack_center + Vector3(1.1, 1.1, 1.34))

	# 5. Интерактивная дощатая дверь дизельной
	_shack_door_hinge = Node3D.new()
	_shack_door_hinge.position = shack_center + Vector3(-0.55, 0.0, 1.34)
	add_child(_shack_door_hinge)
	var s_door := Interactable.new()
	s_door.collision_layer = Geo.LAYER_WORLD
	s_door.position = Vector3(0.52, 0.95, 0.0)
	s_door.prompt_provider = func() -> String: return Loc.t(&"it.shack_door_close") if shack_door_open else Loc.t(&"it.shack_door_open")
	s_door.add_child(_shack_door_mesh())
	s_door.add_child(Geo.box_shape(Vector3(1.05, 1.9, 0.08)))
	s_door.used.connect(_on_shack_door_used)
	_shack_door_hinge.add_child(s_door)

	# 6. Крыша — в _build_shack_shell; здесь только её столкновение.
	var roof_col := StaticBody3D.new()
	roof_col.collision_layer = Geo.LAYER_WORLD
	roof_col.collision_mask = 0
	roof_col.position = shack_center + Vector3(0, _shack_top(0.0) + 0.05, 0.0)
	roof_col.rotation.x = -atan(SHACK_SLOPE)
	roof_col.add_child(Geo.box_shape(Vector3(3.6, 0.1, 3.5)))
	add_child(roof_col)

	# Дым от выхлопа генератора
	_gen_smoke = CPUParticles3D.new()
	_gen_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gen_smoke.amount = 16
	_gen_smoke.lifetime = 1.8
	_gen_smoke.direction = Vector3(0.2, 1.0, -0.1)
	_gen_smoke.spread = 15.0
	_gen_smoke.gravity = Vector3(0.5, 0.2, 0.0)
	_gen_smoke.initial_velocity_min = 0.8
	_gen_smoke.initial_velocity_max = 1.6
	var sm_mesh := QuadMesh.new()
	sm_mesh.size = Vector2(0.4, 0.4)
	var sm_mat := Player.puff_material(0.5)
	sm_mat.albedo_color = Color(0.22, 0.22, 0.25, 0.5)
	sm_mesh.material = sm_mat
	_gen_smoke.mesh = sm_mesh
	_gen_smoke.color_ramp = Player.puff_ramp()
	_gen_smoke.local_coords = false
	_gen_smoke.position = shack_center + Vector3(-0.5, 3.4, -0.6)
	add_child(_gen_smoke)

	# Дизель-генератор внутри будки
	var gen := Geo.interactable(self, Vector3(1.1, 0.85, 0.8), shack_center + Vector3(-0.3, 0.50, -0.2), null, "", _on_generator_used)
	var gen_mesh := Props.generator()
	gen_mesh.position.y = -0.40
	gen.add_child(gen_mesh)
	gen.prompt_provider = _generator_prompt
	gen.hold_sound = CLANK_SOUND
	gen.hold_check = func() -> bool:
		return (Game.gen_broken and Game.has_item(&"tools")) or (not Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0) or (Game.player != null and Game.player.held == &"canister")
	_generator = gen

	_gen_sputter_player = AudioStreamPlayer3D.new()
	_gen_sputter_player.stream = AudioDirector.cached_stream("res://assets/audio/generator_sputter.ogg")
	_gen_sputter_player.unit_size = 4.0
	_gen_sputter_player.max_distance = 20.0
	_gen_sputter_player.volume_db = 1.0
	_gen_sputter_player.bus = &"SFX"
	gen.add_child(_gen_sputter_player)

	# Постоянный 3D-гул работающего 4-тактного дизеля АБ-4
	_gen_engine_player = AudioStreamPlayer3D.new()
	var eng_s := load("res://assets/audio/engine_loop.ogg") as AudioStream
	if eng_s is AudioStreamOggVorbis:
		eng_s = eng_s.duplicate()
		(eng_s as AudioStreamOggVorbis).loop = true
	_gen_engine_player.stream = eng_s
	_gen_engine_player.unit_size = 4.5
	_gen_engine_player.max_distance = 45.0
	_gen_engine_player.volume_db = -80.0
	_gen_engine_player.bus = &"SFX"
	_gen_engine_player.autoplay = true
	gen.add_child(_gen_engine_player)
	_gen_engine_player.play()

	# Гул и вибрация пола в избе от работающего генератора (через мёрзлый грунт)
	_underfloor_hum_player = AudioStreamPlayer.new()
	var uf_s := load("res://assets/sfx/underfloor_hum.ogg") as AudioStream
	if uf_s is AudioStreamOggVorbis:
		uf_s = uf_s.duplicate()
		(uf_s as AudioStreamOggVorbis).loop = true
	_underfloor_hum_player.stream = uf_s
	_underfloor_hum_player.volume_db = -80.0
	_underfloor_hum_player.bus = &"Ambient"
	_underfloor_hum_player.autoplay = true
	add_child(_underfloor_hum_player)
	_underfloor_hum_player.play()

	# Бочка солярки рядом с генератором
	_barrel = Geo.interactable(self, Vector3(0.55, 0.9, 0.55), shack_center + Vector3(0.9, 0.50, -0.3), null, "", _on_barrel_used)
	var barrel_mesh := Props.barrel()
	barrel_mesh.position.y = -0.40
	_barrel.add_child(barrel_mesh)
	_barrel.prompt_provider = func() -> String: return Loc.t(&"it.barrel_burn") if Game.final_call else Loc.t(&"it.barrel")
	_barrel.hold_check = func() -> bool: return Game.final_call
	_barrel.hold_sound = "res://assets/audio/stove_add.ogg"

	# Масляные пятна на дощатом полу под картером двигателя и у бочки
	Geo.block(self, Vector3(0.9, 0.005, 0.7), shack_center + Vector3(-0.3, 0.108, -0.2), Palette.m(&"dark"), false)   # пятна чуть выше рамы дизеля
	Geo.block(self, Vector3(0.65, 0.005, 0.65), shack_center + Vector3(0.9, 0.108, -0.3), Palette.m(&"dark"), false)

	# Верстак / стеллаж в будке
	Geo.block(self, Vector3(0.4, 0.75, 1.1), shack_center + Vector3(1.25, 0.425, 0.4), Palette.m(&"wood"), true)
	# Маслёнка и гаечный ключ на верстаке
	Geo.cylinder(self, 0.045, 0.14, shack_center + Vector3(1.25, 0.88, 0.25), Palette.m(&"metal"), false)
	Geo.block(self, Vector3(0.04, 0.02, 0.22), shack_center + Vector3(1.25, 0.81, 0.55), Palette.m(&"metal"), false)

	# Сизая дымка выхлопа внутри будки
	var shack_haze := CPUParticles3D.new()
	shack_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shack_haze.amount = 12
	shack_haze.lifetime = 3.0
	shack_haze.direction = Vector3(0.0, 0.4, 0.0)
	shack_haze.spread = 45.0
	shack_haze.gravity = Vector3(0.0, 0.05, 0.0)
	shack_haze.initial_velocity_min = 0.1
	shack_haze.initial_velocity_max = 0.3
	var hz_mesh := QuadMesh.new()
	hz_mesh.size = Vector2(0.6, 0.6)
	var hz_mat := Player.puff_material(0.25)
	hz_mat.albedo_color = Color(0.18, 0.20, 0.22, 0.25)
	hz_mesh.material = hz_mat
	shack_haze.mesh = hz_mesh
	shack_haze.color_ramp = Player.puff_ramp()
	shack_haze.position = shack_center + Vector3(-0.3, 1.4, -0.2)
	add_child(shack_haze)

	# Защищённый плафон в будке генератора (тёплый свет, глубокие тени в углах)
	var l_shack := Geo.omni(self, shack_center + Vector3(0, 2.05, 0), 4.2, 0.75, Color(1.0, 0.72, 0.38))
	Atmosphere.add_halo(l_shack, 0.75)
	Geo.bulb(l_shack, &"bulb", 0.06)
	register_lamp(l_shack)

	# Мигающие щели света в дощатых стенах будки генератора при работающем дизеле
	_build_shack_light_slits(shack_center)


func _build_shack_light_slits(c: Vector3) -> void:
	var slits_def: Array = [
		[c + Vector3(1.18, 1.25, 1.41), Vector2(0.04, 1.35), Vector3.ZERO, 0.88],
		[c + Vector3(-1.61, 1.15, 0.35), Vector2(0.04, 1.40), Vector3(0.0, -PI * 0.5, 0.0), 0.92],
		[c + Vector3(-1.61, 1.35, -0.65), Vector2(0.035, 1.10), Vector3(0.0, -PI * 0.5, 0.0), 0.85],
		[c + Vector3(0.0, 0.052, 1.42), Vector2(0.92, 0.18), Vector3(-PI * 0.5, 0.0, 0.0), 0.78],
	]
	var slit_tex := _make_shack_slit_texture()
	for s_info: Array in slits_def:
		var pos: Vector3 = s_info[0]
		var sz: Vector2 = s_info[1]
		var rot: Vector3 = s_info[2]
		var b_a: float = s_info[3]

		var q := QuadMesh.new()
		q.size = sz
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.position = pos
		mi.rotation = rot

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.68, 0.28, b_a)
		mat.albedo_texture = slit_tex
		mi.material_override = mat
		add_child(mi)

		_shack_light_slits.append({
			"mesh": mi,
			"mat": mat,
			"base_a": b_a
		})


static func _make_shack_slit_texture() -> ImageTexture:
	var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var vy := (float(y) / 63.0) * 2.0 - 1.0
		var y_fade := clampf((1.0 - absf(vy)) * 3.0, 0.0, 1.0)
		for x in 16:
			var ux := (float(x) / 15.0) * 2.0 - 1.0
			var x_fade := clampf(1.0 - absf(ux), 0.0, 1.0)
			var a := x_fade * y_fade
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


const SHACK_SLOPE := 0.3 / 2.8    ## уклон крыши будки: спереди (юг) 2.4 м, сзади 2.1 м

## Верх стен будки в точке z (локально от центра будки): крыша падает на север.
static func _shack_top(z: float) -> float:
	return 2.1 + (z + 1.4) * SHACK_SLOPE


func _build_shack_shell(c: Vector3) -> void:
	# Новый облик (tools/blender/gen_shack.py); стекло и иней окошка — свои, движковые
	if Models.spawn(self, "kedr/gen_shack", Vector3(0, GEN_SHACK_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0}) != null:
		var gwin := c + Vector3(1.6 - 0.02, 1.45, -0.2)
		var g := Geo.box_mesh(Vector3(0.012, 0.5, 0.6), Palette.glass())
		g.position = gwin
		add_child(g)
		_window_frost(gwin, Vector3(0.012, 0.5, 0.6), Vector3(-1, 0, 0), false)
		return
	var k := MeshKit.new(31)
	k.mottle = 0.1
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var board := Color(0.33, 0.25, 0.18)
	var inner := Color(0.2, 0.15, 0.11)
	var trim: Color = (Palette.COLORS[&"trim_paint"] as Color).lightened(0.12)
	var roof_col := Color(0.16, 0.14, 0.13)
	var HX := 1.6
	var HZ := 1.4
	var T := 0.035
	# Стена: доски поперёк оси u, с зазором; низ на 0.05, верх — по скату. holes: [[u0, u1, y0, y1]].
	var wall := func(axis: int, u0: float, u1: float, face: float, out_sign: float, holes: Array) -> void:
		var u := u0
		while u < u1 - 0.02:
			var w := minf(rng.randf_range(0.17, 0.22), u1 - u)
			for h: Array in holes:      # края проёма — границы досок, чтобы доска не залезала в проём
				for e: float in [float(h[0]), float(h[1])]:
					if e > u + 0.01 and e < u + w:
						w = e - u
			var um := u + w * 0.5
			var top := _shack_top(face if axis == 0 else um) + 0.02
			var spans: Array = [[0.05, top]]
			for h: Array in holes:
				if um > float(h[0]) and um < float(h[1]):
					spans = [[0.05, float(h[2])], [float(h[3]), top]]
			for sp: Array in spans:
				var y0: float = sp[0]
				var y1: float = sp[1]
				if y1 - y0 < 0.05:
					continue
				var ctr := Vector3(um, (y0 + y1) * 0.5, face - out_sign * T * 0.5) if axis == 0 else Vector3(face - out_sign * T * 0.5, (y0 + y1) * 0.5, um)
				var sz := Vector3(w - 0.012, y1 - y0, T) if axis == 0 else Vector3(T, y1 - y0, w - 0.012)
				k.box(c + ctr, sz, board.darkened(rng.randf_range(0.0, 0.18)))
				# изнанка — сплошная тёмная обшивка, чтобы в щели не светило
				var ictr := ctr - (Vector3(0, 0, out_sign) if axis == 0 else Vector3(out_sign, 0, 0)) * (T + 0.012)
				var isz := Vector3(w + 0.002, y1 - y0, 0.02) if axis == 0 else Vector3(0.02, y1 - y0, w + 0.002)
				k.box(c + ictr, isz, inner)
			u += w
	var door := [-0.6, 0.6, -1.0, 2.0]
	var window := [-0.5, 0.1, 1.2, 1.7]
	wall.call(0, -HX, HX, HZ, 1.0, [door])
	wall.call(0, -HX, HX, -HZ, -1.0, [])
	wall.call(2, -HZ, HZ, -HX, -1.0, [])
	wall.call(2, -HZ, HZ, HX, 1.0, [window])
	# Угловые стойки и обвязка — голубая краска
	for sx: float in [-HX, HX]:
		for sz: float in [-HZ, HZ]:
			var hh := _shack_top(sz)
			k.box(c + Vector3(sx, hh * 0.5, sz), Vector3(0.1, hh, 0.1), trim)
	# Наличник двери
	for dx: float in [-0.64, 0.64]:
		k.box(c + Vector3(dx, 1.03, HZ + 0.015), Vector3(0.08, 2.0, 0.03), trim)
	k.box(c + Vector3(0, 2.06, HZ + 0.015), Vector3(1.36, 0.1, 0.03), trim)
	# Окошко на востоке: рама, перекрестье, подоконник
	var wz := (float(window[0]) + float(window[1])) * 0.5
	var wy := (float(window[2]) + float(window[3])) * 0.5
	for dz: float in [float(window[0]) - 0.03, float(window[1]) + 0.03]:
		k.box(c + Vector3(HX + 0.015, wy, dz), Vector3(0.03, 0.62, 0.06), trim)
	for dy: float in [float(window[2]) - 0.03, float(window[3]) + 0.03]:
		k.box(c + Vector3(HX + 0.015, dy, wz), Vector3(0.03, 0.06, 0.72), trim)
	k.box(c + Vector3(HX - 0.01, wy, wz), Vector3(0.02, 0.5, 0.03), trim)
	k.box(c + Vector3(HX + 0.06, float(window[2]) - 0.07, wz), Vector3(0.12, 0.03, 0.74), trim)
	var glass := Geo.box_mesh(Vector3(0.012, 0.5, 0.6), Palette.glass())
	glass.position = c + Vector3(HX - 0.02, wy, wz)
	add_child(glass)
	_window_frost(c + Vector3(HX - 0.02, wy, wz), Vector3(0.012, 0.5, 0.6), Vector3(-1, 0, 0), false)
	# Стропила изнутри
	var tilt := Basis(Vector3.RIGHT, -atan(SHACK_SLOPE))
	for rx: float in [-1.05, 0.0, 1.05]:
		k.box(c + Vector3(rx, _shack_top(0.0) - 0.05, 0.0), Vector3(0.07, 0.1, 2.8), inner, tilt)
	# Крыша: толь на досках, вылет 0.4 спереди, 0.35 сзади, 0.25 по бокам
	var z0 := -HZ - 0.35
	var z1 := HZ + 0.4
	var zm := (z0 + z1) * 0.5
	var run := (z1 - z0) / cos(atan(SHACK_SLOPE))
	var up := tilt * Vector3.UP
	var roof_c := Vector3(0, _shack_top(zm), zm) + up * 0.05
	k.box(c + roof_c, Vector3(HX * 2.0 + 0.5, 0.08, run), roof_col, tilt)
	# Ветровые доски и лобовая доска
	for sx: float in [-HX - 0.26, HX + 0.26]:
		k.box(c + Vector3(sx, _shack_top(zm) + 0.02, zm), Vector3(0.04, 0.17, run + 0.02), trim, tilt)
	k.box(c + Vector3(0, _shack_top(z1) + 0.02, z1 + 0.01), Vector3(HX * 2.0 + 0.56, 0.17, 0.04), trim)
	# Труба выхлопа с колпаком и хомутом
	var pipe := c + Vector3(-0.5, 0.0, -0.6)
	k.tube([pipe + Vector3(0, 1.9, 0), pipe + Vector3(0, 3.35, 0)], [0.05, 0.05], Color(0.22, 0.2, 0.19), 8)
	k.tube([pipe + Vector3(0, _shack_top(-0.6) + 0.06, 0), pipe + Vector3(0, _shack_top(-0.6) + 0.2, 0)], [0.1, 0.075], Color(0.15, 0.13, 0.12), 8)
	k.tube([pipe + Vector3(0, 3.4, 0), pipe + Vector3(0, 3.52, 0)], [0.13, 0.01], Color(0.18, 0.16, 0.15), 8)
	# Бочки с соляркой у восточной стены — красные, с обручами
	for b: Array in [[Vector3(2.05, 0, 0.75), 0.0], [Vector3(2.15, 0, 1.4), 0.4]]:
		var bp: Vector3 = c + (b[0] as Vector3)
		var col := Color(0.52, 0.09, 0.05).darkened(float(b[1]) * 0.3)
		k.tube([bp + Vector3(0, 0.0, 0), bp + Vector3(0, 0.88, 0)], [0.29, 0.29], col, 10)
		for hy: float in [0.22, 0.66]:
			k.tube([bp + Vector3(0, hy - 0.02, 0), bp + Vector3(0, hy + 0.02, 0)], [0.3, 0.3], col.darkened(0.4), 10)
	for b: Vector3 in [Vector3(2.05, 0.45, 0.75), Vector3(2.15, 0.45, 1.4)]:
		_collider(Vector3(0.56, 0.9, 0.56), c + b)
	var mi := MeshInstance3D.new()
	mi.name = "ShackShell"
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"prop_shack", Color.WHITE, "tex_wood.png", 0.0)
	add_child(mi)

	# Снег: шапка на крыше (не свисает ниже кромки), сугробы у стен, шапки на бочках, сосульки
	var sk := MeshKit.new(32)
	sk.mottle = 0.04
	var snow := Color(0.8, 0.86, 0.94)
	sk.box(c + roof_c + up * 0.09, Vector3(HX * 2.0 + 0.42, 0.1, run - 0.08), snow, tilt)
	sk.box(c + roof_c + up * 0.2 + Vector3(0.3, 0, -0.4), Vector3(2.2, 0.06, 1.6), snow, tilt)
	# Сугробы прижаты к стенам снаружи: край эллипсоида касается наружной доски и не лезет внутрь будки
	for d: Array in [[Vector3(-0.3, 0.0, -HZ - 0.53), Vector3(1.8, 0.42, 0.55)], [Vector3(-HX - 0.48, 0.0, -0.3), Vector3(0.5, 0.36, 1.3)],
			[Vector3(1.1, 0.0, -HZ - 0.38), Vector3(0.7, 0.3, 0.4)]]:
		sk.blob(c + (d[0] as Vector3), d[1], snow, 4, 9)
	for b: Vector3 in [Vector3(2.05, 0.9, 0.75), Vector3(2.15, 0.9, 1.4)]:
		sk.blob(c + b, Vector3(0.26, 0.06, 0.26), snow, 3, 8)
	var ice := Color(0.7, 0.82, 0.92)
	var x := -HX - 0.15
	while x < HX + 0.15:
		var base := c + Vector3(x, _shack_top(z0) + 0.0, z0 + 0.03)
		sk.spike(base, base + Vector3(0, -rng.randf_range(0.08, 0.32), 0), 0.025, ice)
		x += rng.randf_range(0.18, 0.45)
	var smi := MeshInstance3D.new()
	smi.name = "ShackSnow"
	smi.mesh = sk.commit()
	smi.material_override = Creatures._mat(&"prop_shack_snow", Color.WHITE, "tex_snow.png", 0.0)
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)

	# Табличка над дверью «ДЭС-8» и предупреждение на двери
	_sign(c + Vector3(0, 2.28, HZ + 0.03), Vector2(0.62, 0.2), "ДЭС-8", Color(0.88, 0.86, 0.8), Color(0.1, 0.1, 0.12), 34)


## Плоская табличка с надписью (лицом на +Z).
func _sign(pos: Vector3, size: Vector2, text: String, plate: Color, ink: Color, font := 30, parent: Node = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	(parent if parent != null else self).add_child(root)
	var k := MeshKit.new(3)
	k.box(Vector3.ZERO, Vector3(size.x, size.y, 0.015), plate)
	k.box(Vector3(0, -size.y * 0.5 + 0.02, 0.003), Vector3(size.x - 0.02, 0.025, 0.015), Color(0.55, 0.06, 0.04))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"prop_sign", Color.WHITE, "", 0.0)
	root.add_child(mi)
	var l := Label3D.new()
	l.text = text
	l.font_size = font
	l.pixel_size = 0.0045
	l.modulate = ink
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = Vector3(0, 0.012, 0.01)
	root.add_child(l)
	return root


## Дверь будки: пять досок, обвязка «Z», ручка-скоба; на двери — красное «НЕ ВЛЕЗАЙ — УБЬЁТ».
func _shack_door_mesh() -> Node3D:
	var root := Node3D.new()
	var k := MeshKit.new(9)
	k.mottle = 0.1
	# Стиль УГМС: доски выцветшей зелёной краской, обвязка тоже зелёная, но темнее (docs/СТИЛЬ_ПОСТРОЕК.md)
	var board := Color(0.27, 0.38, 0.29)
	var x := -0.525
	for i in 5:
		k.box(Vector3(x + 0.105, 0, 0), Vector3(0.2, 1.9, 0.045), board.darkened(0.06 * float(i % 3)))
		x += 0.21
	var rail := Color(0.20, 0.29, 0.22)
	for ry: float in [-0.6, 0.6]:
		k.box(Vector3(0, ry, 0.04), Vector3(0.98, 0.12, 0.035), rail)
	k.box(Vector3(0, 0, 0.04), Vector3(0.11, 1.32, 0.035), rail, Basis(Vector3.BACK, atan2(0.98, 1.2)))
	k.box(Vector3(0.4, 0.0, 0.08), Vector3(0.03, 0.2, 0.03), Color(0.1, 0.1, 0.1))
	k.box(Vector3(0.4, 0.09, 0.06), Vector3(0.03, 0.03, 0.05), Color(0.1, 0.1, 0.1))
	k.box(Vector3(0.4, -0.09, 0.06), Vector3(0.03, 0.03, 0.05), Color(0.1, 0.1, 0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = Creatures._mat(&"prop_shack", Color.WHITE, "tex_wood.png", 0.0)
	root.add_child(mi)
	_sign(Vector3(0, 0.3, 0.07), Vector2(0.4, 0.26), "НЕ ВЛЕЗАЙ\nУБЬЁТ", Color(0.9, 0.88, 0.82), Color(0.6, 0.05, 0.03), 22, root)
	return root


func set_shack_door_open(open: bool) -> void:
	if open == shack_door_open or _shack_door_busy or _shack_door_hinge == null:
		return
	_shack_door_busy = true
	shack_door_open = open
	Game.audio.play_3d(DOOR_SOUND, _shack_door_hinge.global_position + Vector3(0, 1, 0), -6.0)
	var tw := create_tween()
	tw.tween_property(_shack_door_hinge, "rotation:y", deg_to_rad(-115.0) if open else 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_shack_door_busy = false


func _on_shack_door_used(_p: Player) -> void:
	set_shack_door_open(not shack_door_open)


func set_door_open(open: bool) -> void:
	if open == door_open or _door_busy:
		return
	_door_busy = true
	if Game.psychosomatic != null and Game.psychosomatic.has_method(&"should_door_hesitate") and bool(Game.psychosomatic.call(&"should_door_hesitate")):
		Game.audio.play_3d(CLANK_SOUND, _door_hinge.global_position, -2.0)
		if Game.hud != null and randf() < 0.4:
			Game.hud.subtitle(Loc.t(&"sub.phobia_door_hesitate"), 3.0)
		await get_tree().create_timer(0.32, false).timeout
	door_open = open
	if open:
		EventBus.door_opened.emit()
	Game.audio.play_3d(DOOR_SOUND, _door_hinge.global_position + Vector3(0, 1, 0.5), -7.0)
	var tw := create_tween()
	tw.tween_property(_door_hinge, "rotation:y", deg_to_rad(105.0) if open else 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_door_busy = false
	if not open:
		var pt = get_tree().root.find_child("PrologueTrail", true, false)
		if pt != null:
			var pl = pt.find_child("PorchLog", true, false)
			if pl != null:
				pl.position = Vector3(16.95, 0.05, 2.75)
	if not open and Game.is_prologue() and not Game.has_flag("prologue_arrived") and not Game.has_flag("door_bolted_once"):
		Game.set_flag("door_bolted_once", true)
		Game.audio.play_3d(CLANK_SOUND, _door_hinge.global_position, 2.0)
		Game.hud.subtitle(Loc.t(&"sub.door_bolted"), 4.0)
		get_tree().create_timer(4.2, false).timeout.connect(func() -> void: Voice.say(&"th.bolt", 3.5))
		_trigger_roof_snow_thud()


func _trigger_roof_snow_thud() -> void:
	await get_tree().create_timer(3.5, false).timeout
	if not is_inside_tree(): return
	AudioDirector.play_raw("res://assets/audio/ice_hit.ogg", 2.0)
	if Game.player != null:
		Game.player.shake(0.04, 0.3)
	Game.hud.subtitle(Loc.t(&"sub.roof_snow_thud"), 4.5)


func _trigger_wind_door_burst() -> void:
	if door_open or _door_busy or _door_hinge == null:
		return
	Game.audio.play_3d("res://assets/audio/gust.ogg", _door_hinge.global_position, 3.0)
	set_door_open(true)
	if Game.player != null:
		Game.player.shake(0.06, 0.5)
	Game.hud.subtitle(Loc.t(&"sub.wind_door_slammed"), 4.0)
	Director.add_tension(6.0, "порыв ветра распахнул дверь")


# --- Взаимодействия ----------------------------------------------------------

func _on_door_used(_p: Player) -> void:
	set_door_open(not door_open)


func _on_vestibule_shovel_used(p: Player) -> void:
	if p.held != &"":
		Game.hud.subtitle(Loc.t(&"sub.hands_full"), 2.0)
		return
	p.set_held(&"shovel")
	if _vestibule_shovel != null:
		_vestibule_shovel.visible = false
		_vestibule_shovel.collision_layer = 0
	Game.audio.play_3d(CLANK_SOUND, Vector3(14.36, 0.75, 1.8), -2.0)
	Game.hud.subtitle(Loc.t(&"sub.shovel_taken"), 3.5)


func _on_skis_interact(p: Player) -> void:
	Game.skis_equipped = not Game.skis_equipped
	Game.audio.play_3d(CLANK_SOUND, p.global_position, -4.0)
	Game.hud.subtitle(Loc.t(&"sub.skis_equipped") if Game.skis_equipped else Loc.t(&"sub.skis_removed"), 3.5)


func _on_vs43_interact(p: Player) -> void:
	if Game.has_item(&"vs43"):
		Game.hud.subtitle(Loc.t(&"it.vs43"), 3.0)
		return
	Game.give_item(&"vs43")
	Game.audio.play_3d(CLANK_SOUND, p.global_position, -4.0)
	Game.hud.subtitle(Loc.t(&"sub.got_vs43"), 5.0)


func jiggle_door_handle() -> void:
	if door_open or _door_busy or _door_hinge == null:
		return
	var handle := Voice.sfx(&"door_handle")
	Game.audio.play_3d(handle if handle != "" else CLANK_SOUND, _door_hinge.global_position + Vector3(0, 1, 0.4), -2.0 if handle != "" else -6.0)
	var tw := create_tween()
	tw.tween_property(_door_hinge, "rotation:y", deg_to_rad(1.8), 0.12)
	tw.tween_property(_door_hinge, "rotation:y", deg_to_rad(0.0), 0.12)


func _flash_window_face() -> void:
	# Снаружи за северным окном радиорубки: фигура заглядывает в стекло
	# Двойник стоит вплотную к стеклу (Жердяй к окнам не подходит — его видно только издалека)
	var rig: Node3D = Creatures.make_silhouette()
	rig.look_at_from_position(Vector3(9.2, 0.0, -2.75), Vector3(9.2, 0.0, 1.0), Vector3.UP)   # вне дерева look_at не работает
	add_child(rig)
	Game.audio.play_3d("res://assets/audio/sub_drop.ogg", rig.position, 2.0 if Game.night >= 3 else 0.0)
	if Game.night >= 3:
		Game.audio.play_3d("res://assets/audio/ice_hit.ogg", Vector3(9.2, 1.45, -2.0), 0.0)   # костяшками по стеклу
	Game.hud.subtitle(Loc.t(&"sub.window_face"), 3.0)
	Director.add_tension(20.0 if Game.night >= 3 else 15.0, "лицо в окне")

	await get_tree().create_timer(1.2 if Game.night >= 3 else 0.35, false).timeout
	if is_instance_valid(rig):
		rig.queue_free()


func _on_radio_used(_p: Player) -> void:
	if Game.is_day() and Game.aftermath != null and Game.aftermath.is_call_ringing():
		Game.aftermath.answer_morning_call()
		return
	Game.radio.enter()


func _on_tape_used(_p: Player) -> void:
	EventBus.ui_requested.emit(&"tape")


func _on_journal_used(p: Player) -> void:
	var text := Loc.t(&"journal.rules")
	if prop_changed("journal"):
		text += "\n\n" + Loc.t(&"journal.extra")
	Game.hud.show_note(text)
	p.mode = Player.Mode.READING
	Game.complete_step(&"journal")
	if Game.is_prologue() and not Game.has_flag("prologue_tm1_signed"):
		Game.set_flag("prologue_tm1_signed", true)
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -8.0)
		Game.hud.subtitle(Loc.t(&"sub.tm1_log_signed"), 5.0)
		_trigger_prologue_distant_engine_hook()


func _trigger_prologue_distant_engine_hook() -> void:
	await get_tree().create_timer(4.5, false).timeout
	if not is_inside_tree() or not Game.is_prologue(): return
	AudioDirector.play_raw("res://assets/audio/engine_loop.ogg", -12.0)
	Game.hud.subtitle(Loc.t(&"sub.distant_engine"), 6.0)
	await get_tree().create_timer(6.5, false).timeout
	if not is_inside_tree(): return
	Game.hud.subtitle(Loc.t(&"sub.engine_warning_memory"), 5.5)


## Поддувало (чугунная дверца внизу печи) и вьюшка (задвижка в трубе) — топить «на долго» перед выходом.
func _build_stove_controls() -> void:
	var iron := Palette.m(&"metal")
	_damper_door = Node3D.new()
	_damper_door.position = Vector3(-1.5, 0.12, 1.465)
	add_child(_damper_door)
	var plate := Geo.block(_damper_door, Vector3(0.26, 0.12, 0.015), Vector3(0, 0.06, 0), iron, false)
	plate.name = "Plate"
	Geo.block(_damper_door, Vector3(0.04, 0.015, 0.03), Vector3(0.09, 0.07, 0.015), Palette.m(&"dark"), false)
	var damper := Geo.interactable(self, Vector3(0.4, 0.25, 0.25), Vector3(-1.5, 0.18, 1.5), null, "", func(_p: Player) -> void:
		Game.stove_damper = not Game.stove_damper
		_damper_door.rotation.x = -1.1 if not Game.stove_damper else 0.0
		Game.audio.play_3d(CLANK_SOUND, Vector3(-1.5, 0.2, 1.5), -6.0)
		Game.hud.subtitle(Loc.t(&"sub.damper_closed") if Game.stove_damper else Loc.t(&"sub.damper_opened"), 3.5))
	damper.prompt_provider = func() -> String:
		return Loc.t(&"it.damper_open") if Game.stove_damper else Loc.t(&"it.damper_close")
	_damper_door.rotation.x = -1.1
	# Вьюшка: задвижка в трубе над печью — ручка торчит из кладки
	# (лицо трубы — z = 1.0, x −1.71..−1.29: ручка торчит из кладки, задвинута — вьюшка закрыта)
	Geo.block(self, Vector3(0.14, 0.1, 0.01), Vector3(-1.4, 2.05, 1.005), iron, false)
	_flue_handle = Geo.block(self, Vector3(0.035, 0.035, 0.14), Vector3(-1.4, 2.05, 1.07), iron, false)
	var flue := Geo.interactable(self, Vector3(0.3, 0.25, 0.25), Vector3(-1.4, 2.05, 1.12), null, "", func(_p: Player) -> void:
		Game.stove_flue = not Game.stove_flue
		_flue_handle.position.z = 1.02 if Game.stove_flue else 1.07
		Game.audio.play_3d(CLANK_SOUND, Vector3(-1.4, 2.05, 1.1), -8.0)
		if not Game.stove_flue:
			Game.hud.subtitle(Loc.t(&"sub.flue_opened"), 3.0)
		elif Game.stove_wood > 0.0:
			Game.hud.subtitle(Loc.t(&"sub.flue_closed_fire"), 4.0, 2)
		else:
			Game.hud.subtitle(Loc.t(&"sub.flue_closed_cold"), 4.0))
	flue.prompt_provider = func() -> String:
		return Loc.t(&"it.flue_open") if Game.stove_flue else Loc.t(&"it.flue_close")


## Рубильник у входной двери: погасить свет в доме — дизель на холостом тянет втрое дольше.
func _build_house_switch() -> void:
	var at := Vector3(14.37, 1.45, 2.3)   # по другую сторону двери от вешалки
	Geo.block(self, Vector3(0.03, 0.26, 0.18), at, Palette.m(&"wood"), false)
	Geo.block(self, Vector3(0.05, 0.18, 0.12), at + Vector3(-0.02, 0, 0), _switch_mat(), false)
	_switch_lever = Geo.block(self, Vector3(0.12, 0.025, 0.025), at + Vector3(-0.08, 0.05, 0), Palette.m(&"metal"), false)
	var it := Geo.interactable(self, Vector3(0.25, 0.35, 0.3), at + Vector3(-0.08, 0, 0), null, "", func(_p: Player) -> void:
		Game.house_switch_off = not Game.house_switch_off
		_switch_lever.position.y = at.y + (-0.05 if Game.house_switch_off else 0.05)
		_apply_lamps()
		Game.audio.play_3d(CLANK_SOUND, at, -2.0)
		Game.hud.subtitle(Loc.t(&"sub.switch_off") if Game.house_switch_off else Loc.t(&"sub.switch_on"), 4.0))
	it.prompt_provider = func() -> String:
		return Loc.t(&"it.switch_on") if Game.house_switch_off else Loc.t(&"it.switch_off")


static func _switch_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.1, 0.07)
	m.roughness = 0.35
	return m


func _stove_prompt() -> String:
	if Game.player != null and Game.player.held == &"wood":
		return Loc.t(&"it.stove_add")
	if Game.chimney_iced and Game.stove_wood > 0.0:
		return Loc.t(&"it.stove_douse")
	return Loc.t(&"it.stove", [Game.stove_state()])


func _on_stove_used(p: Player) -> void:
	if Game.stove_wood > 0.0:
		Gear.refill_thermos()   # чай в термос — с горячей плиты
	# Забит дымоход — печь можно залить из чайника: угар прекратится, но дом начнёт остывать.
	if p.held != &"wood" and Game.chimney_iced and Game.stove_wood > 0.0:
		Game.stove_wood = 0.0
		Game.audio.play_3d("res://assets/audio/fire_loop.ogg", Vector3(-1.5, 0.65, 1.0), -14.0, 2.0, 0.8)
		Game.audio.play_3d(STOVE_SOUND, Vector3(-1.5, 0.65, 1.0), -4.0)
		Game.hud.subtitle(Loc.t(&"sub.stove_doused"), 3.5, 2)
		return
	if p.held != &"wood":
		return
	if Game.stove_wood > 80.0:
		Game.hud.subtitle(Loc.t(&"sub.stove_full"), 2.5)
		return
	p.set_held(&"")
	if Game.is_prologue() and Game.stove_wood <= 0.0:
		_light_prologue_stove()
		return
	Game.add_wood()
	Game.audio.play_3d(STOVE_SOUND, Vector3(-1.5, 0.65, 1.0), 0.0)
	Game.hud.subtitle(Loc.t(&"sub.stove_added"), 2.5)


func _light_prologue_stove() -> void:
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -6.0)
	Game.hud.subtitle(Loc.t(&"sub.match_strike"), 3.0)
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree(): return
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
	Game.stove_wood = 65.0
	Game.add_wood()
	Game.audio.play_3d(STOVE_SOUND, Vector3(-1.5, 0.65, 1.0), 0.0)
	Game.audio.play_3d("res://assets/audio/fire_loop.ogg", Vector3(-1.5, 0.65, 1.0), -2.0)
	Game.hud.subtitle(Loc.t(&"sub.stove_lit_prologue"), 5.0)
	Game.warmth = minf(Game.warmth + 30.0, 100.0)


func _woodbox_prompt() -> String:
	if Game.player != null and Game.player.held == &"wood":
		if _woodbox_count >= 3:
			return Loc.t(&"it.woodbox_full")
		return Loc.t(&"it.woodbox_add", [_woodbox_count])
	if _woodbox_count > 0:
		return Loc.t(&"it.woodbox_take", [_woodbox_count])
	return Loc.t(&"it.woodbox_empty")


func _on_woodbox_used(p: Player) -> void:
	if p.held == &"wood":
		if _woodbox_count >= 3:
			Game.hud.subtitle(Loc.t(&"it.woodbox_full"), 2.0)
			return
		_woodbox_count += 1
		p.set_held(&"")
		_update_woodbox_visual()
		Game.audio.play_3d(STOVE_SOUND, _woodbox_it.global_position, -2.0)
		Game.hud.subtitle(Loc.t(&"sub.woodbox_add"), 2.5)
	elif p.held == &"":
		if _woodbox_count <= 0:
			Game.hud.subtitle(Loc.t(&"it.woodbox_empty"), 2.0)
			return
		_woodbox_count -= 1
		p.set_held(&"wood")
		_update_woodbox_visual()
		Game.audio.play_3d(STOVE_SOUND, _woodbox_it.global_position, -2.0)
		Game.hud.subtitle(Loc.t(&"sub.woodbox_take"), 2.5)


func _update_woodbox_visual() -> void:
	if _woodbox_node != null and is_instance_valid(_woodbox_node):
		_woodbox_node.queue_free()
	_woodbox_node = Props.woodbox(_woodbox_count)
	_woodbox_node.position = Vector3(-0.65, 0.05, 1.1)
	_woodbox_node.rotation.y = deg_to_rad(15.0)
	add_child(_woodbox_node)


func _open_darkroom() -> void:
	if Game.hud == null:
		return
	var dr := DarkroomUI.new()
	Game.hud.open_modal(dr)
	await dr.closed
	Game.hud.close_modal()


func _on_kettle_used(p: Player) -> void:
	if p != null and p.held == &"kettle":
		p.set_held(&"")
		if _kettle != null:
			_kettle.visible = true
		Game.hud.subtitle(Loc.t(&"it.kettle_return"), 3.0)
		return
	if p != null and p.held != &"" and (Input.is_physical_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_SHIFT)):
		Game.hud.subtitle(Loc.t(&"sub.hands_full"), 2.0)
		return
	if p != null and p.held == &"" and (Input.is_physical_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_SHIFT)):
		p.set_held(&"kettle")
		p.kettle_heat_timer = 90.0
		if _kettle != null:
			_kettle.visible = false
		Game.hud.subtitle(Loc.t(&"sub.kettle_taken"), 4.0)
		return
	if _kettle != null and not _kettle.visible:
		return
	if prop_changed("teapot"):
		Game.hud.subtitle(Loc.t(&"sub.kettle_table"), 3.0)
		return
	if Game.stove_wood <= 0.0:
		Game.hud.subtitle(Loc.t(&"sub.teapot_cold"), 2.5)
		return
	if Game.tea_cd > 0.0:
		Game.hud.subtitle(Loc.t(&"sub.kettle_recent"), 2.5)
		return
	Game.tea_cd = 90.0
	Game.tea_warmth_timer = 40.0
	var tins := int(SaveGame.flags.get("tea_tins", 0))
	Game.audio.play_3d(Voice.sfx_or(&"kettle_whistle", STOVE_SOUND), Vector3(-1.5, 1.35, 1.0), -2.0)
	if tins > 0:
		# Чай со сгущёнкой из снабжения: греет сильнее и снимает усталость
		SaveGame.flags["tea_tins"] = tins - 1
		Game.warmth = minf(Game.warmth + 30.0, 100.0)
		Game.add_fatigue(-10.0)
		Game.hud.subtitle(Loc.t(&"sub.kettle_drink_sweet", [tins - 1]), 3.5)
	else:
		Game.warmth = minf(Game.warmth + 15.0, 100.0)
		Game.hud.subtitle(Loc.t(&"sub.kettle_drink"), 3.5)

	# При высокой усталости (> 55): в отражении чайника за плечом мелькнуло — обернёшься, а там
	# только мокрые следы босых ног, от двери к самой твоей спине.
	if Game.fatigue >= 55.0 and not Game.has_flag("polunoch_kettle_seen"):
		Game.set_flag("polunoch_kettle_seen", true)
		var behind := Vector3(-0.3, 0.0, 2.2)
		Game.audio.play_3d("res://assets/audio/whisper.ogg", behind + Vector3(0, 1.5, 0), -4.0)
		Game.audio.play_3d("res://assets/sfx/barefoot_wood_v2.ogg", behind, -6.0, 4.0)
		Game.hud.subtitle(Loc.t(&"sub.polunochnitsa_glimpse"), 4.0)
		Director.add_tension(12.0, "мелькнуло в отражении чайника")
		var trail := Footprints.trail(self, &"wet", PackedVector3Array([Vector3(3.3, 0, 3.2), Vector3(2.0, 0, 3.0), Vector3(0.6, 0, 2.6), behind]), 0.05, 0.42)
		Geo.free_after(trail, 90.0)


func _build_storm_beacon() -> void:
	_beacon_prop = Props.beacon_lantern()
	_beacon_prop.position = Vector3(12.5, RIDGE_TOP - 0.7, 3.3)
	add_child(_beacon_prop)
	_storm_beacon = Geo.omni(self, Vector3(12.5, RIDGE_TOP + 0.75, 3.3), 55.0, 1.9, Color(1.0, 0.72, 0.22))
	Atmosphere.add_halo(_storm_beacon, 2.4, Color(1.0, 0.66, 0.25, 0.5))
	_storm_beacon.shadow_enabled = false
	register_lamp(_storm_beacon)


func trigger_beacon_blackout(duration := 6.0) -> void:
	if _beacon_blackout_active:
		return
	_beacon_blackout_active = true
	if _storm_beacon != null:
		_storm_beacon.visible = false
	Game.audio.play_3d(CLANK_SOUND, Vector3(12.5, RIDGE_TOP + 0.75, 3.3), 0.0)
	Game.hud.subtitle(Loc.t(&"sub.beacon_blackout"), 4.0)
	await get_tree().create_timer(duration, false).timeout
	_beacon_blackout_active = false
	if _storm_beacon != null and outside_lit():
		_storm_beacon.visible = true
		Game.audio.play_3d("res://assets/audio/hum_loop.ogg", Vector3(12.5, RIDGE_TOP + 0.75, 3.3), -4.0)


func _trigger_generator_stall() -> void:
	if not Game.power_on or Game.gen_broken or Game.generator_fuel <= 0.0 or Game.is_prologue():
		return
	_gen_stalled = true
	_gen_warm = false
	_gen_pull_count = 0
	var gen_pos := _generator.global_position if _generator != null else Vector3(14.2, 0.45, -13.65)
	var stall := Voice.sfx(&"gen_stall")
	if stall != "":
		Game.audio.play_3d(stall, gen_pos, 2.0, 7.0)
	elif _gen_sputter_player != null:
		_gen_sputter_player.play()
	flicker(1.4)
	await get_tree().create_timer(1.2, false).timeout
	if _gen_stalled and Game.power_on:
		Game.set_power(false)
		Director.add_tension(12.0, "генератор заглох")
		Game.hud.subtitle(Loc.t(&"sub.gen_stalled"), 4.5, 2)


func _generator_prompt() -> String:
	if Game.player != null and Game.player.held == &"oil":
		return Loc.t(&"it.gen_oil")
	if Game.gen_broken:
		return Loc.t(&"it.gen_repair") if Game.has_item(&"tools") else Loc.t(&"it.gen_broken")
	if Game.player != null and Game.player.held == &"canister":
		return Loc.t(&"it.gen_fill")
	if not Game.power_on:
		if Game.generator_fuel <= 0.0:
			return Loc.t(&"it.gen_no_fuel")
		return Loc.t(&"it.gen_restart")
	var state := "%d%%" % int(Game.generator_fuel)
	return Loc.t(&"it.gen", [state])


func _on_generator_used(p: Player) -> void:
	var gen_pos := _generator.global_position if _generator != null else Vector3(14.2, 0.45, -13.65)
	if p.held == &"oil":
		p.set_held(&"")
		Game.audio.play_3d(CLANK_SOUND, gen_pos, -4.0)
		Game.hud.subtitle(Loc.t(&"sub.oil_done"), 3.0)
		if Game.tasks != null:
			Game.tasks.complete(&"oil")
		return
	if Game.gen_broken:
		if Game.has_item(&"tools"):
			Game.gen_broken = false
			Game.set_power(Game.generator_fuel > 0.0)
			Game.audio.play_3d(CLANK_SOUND, gen_pos, 2.0)
			Game.hud.subtitle(Loc.t(&"sub.gen_repaired"), 4.0)
		else:
			Game.hud.subtitle(Loc.t(&"sub.gen_need_tools"), 3.5)
		return
	if p.held == &"canister":
		if Game.generator_fuel > 85.0 and not Game.is_prologue():
			Game.hud.subtitle(Loc.t(&"sub.gen_full"), 3.0)
			return
		p.set_held(&"")
		Game.refuel()
		Game.audio.play_3d(CLANK_SOUND, gen_pos, 0.0)
		Game.hud.subtitle(Loc.t(&"sub.gen_filled"), 3.0)
		return
	if not Game.power_on and not Game.gen_broken:
		if Game.generator_fuel <= 0.0:
			Game.hud.subtitle(Loc.t(&"it.gen_no_fuel"), 3.0)
			return
		# Запуск генератора вручную (рывок троса стартера)
		_gen_pull_count += 1
		var needed := 2 if (Game.is_night() and not _gen_warm and not Game.is_prologue()) else 1
		if _gen_pull_count < needed:
			_gen_warm = true
			if _gen_sputter_player != null:
				_gen_sputter_player.play()
			Game.audio.play_3d(CLANK_SOUND, gen_pos, 2.0)
			p.shake(0.04, 0.35)
			Game.vibrate(0.45, 0.6, 0.35)
			Game.hud.subtitle(Loc.t(&"sub.gen_cord_pull"), 3.0)
			return
		_gen_pull_count = 0
		_gen_warm = true
		_gen_stalled = false
		_gen_stall_timer = Game.rng.randf_range(300.0, 460.0)
		var start := Voice.sfx(&"gen_start")
		if start != "":
			Game.audio.play_3d(start, gen_pos, 2.0, 6.0)
		else:
			Game.audio.play_3d(CLANK_SOUND, gen_pos, 1.0)
			if _gen_sputter_player != null:
				_gen_sputter_player.play()
		p.shake(0.05, 0.45)
		Game.vibrate(0.65, 0.85, 0.5)
		Game.set_power(true)
		Game.hud.subtitle(Loc.t(&"sub.gen_restarted"), 3.5)
		Director.add_tension(-10.0, "генератор запущен")


func _on_barrel_used(_p: Player) -> void:
	if Game.final_call:
		EventBus.ending_chosen.emit(&"burn")


func _bed_prompt() -> String:
	if Game.is_prologue():
		if not Game.has_flag("prologue_arrived"):
			if door_open:
				return Loc.t(&"sub.bed_door_open")
			return Loc.t(&"it.bed_sleep_arrival")
		return Loc.t(&"it.bed_rest") if Game.tutorial_done() else Loc.t(&"it.bed")
	if Game.is_day():
		return Loc.t(&"it.bed_rest") if Game.day_goal_done else Loc.t(&"it.bed")
	return Loc.t(&"it.bed_sleep") if _can_sleep() else Loc.t(&"it.bed")


func _can_sleep() -> bool:
	return Game.after_hour(5) and Game.cfg.get("finale", &"") == &""


var _bed_sleeping := false

func _sleep_to_night1() -> void:
	if _bed_sleeping:
		return
	_bed_sleeping = true
	if Game.player != null:
		Game.player.mode = Player.Mode.LOCKED
		if Game.player.held == &"trunk":
			Game.player.set_held(&"")
			Game.set_flag("trunk_delivered", true)
			Game.set_flag("trunk_unpacked", true)
			_update_living_trunk_visibility()
	Game.hud.set_prompt("")   # был вызов несуществующего show_modal_hint — сон обрывался, утро не наступало
	Game.audio.play_2d("res://assets/audio/breath_loop.ogg", -12.0, 1.5)
	# Плавное затемнение: станция затихает, потрескивают угли в печи
	await Game.hud.fade_in_screen("", 2.2)
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree(): return

	# Один короткий глухой стук снаружи в стену сруба... словно рукавицей
	AudioDirector.play_raw("res://assets/audio/door_knock.ogg", 2.0)
	Game.hud.subtitle(Loc.t(&"sub.bed_first_knock"), 3.5)
	await get_tree().create_timer(4.2, false).timeout
	if not is_inside_tree(): return

	# Утро: та же фаза пролога, но уже при свете — обучение. Спать снова — и ночь 1.
	Game.set_flag("prologue_arrived", true)
	Achievements.unlock(&"hitchhiker")
	SaveGame.write()
	_bed_sleeping = false
	var sess := get_tree().get_first_node_in_group(&"session")
	if sess != null:
		sess.emit_signal(&"finished", "retry")
	else:
		Game.end_shift()


func _on_bed_used(_p: Player) -> void:
	if Game.is_prologue():
		if not Game.has_flag("prologue_arrived"):
			if door_open:
				Game.hud.subtitle(Loc.t(&"sub.bed_door_open"), 3.5)
				return
			_sleep_to_night1()
			return
		if Game.tutorial_done():
			Game.end_shift()
		else:
			Game.hud.subtitle(Loc.t(&"sub.not_yet"), 3.0)
	elif Game.is_day():
		if Game.day_goal_done:
			Game.end_shift()
		else:
			Game.hud.subtitle(Loc.t(&"sub.not_yet"), 3.0)
	elif _can_sleep():
		Game.end_shift()
	else:
		Game.hud.subtitle(Loc.t(&"sub.too_early"), 3.0)


func _update_living_trunk_visibility() -> void:
	if _living_trunk != null:
		var has_delivered := Game.has_flag("trunk_delivered") or Game.has_flag("trunk_unpacked")
		var is_held_now := Game.player != null and Game.player.held == &"trunk"
		_living_trunk.visible = has_delivered and not is_held_now


# --- Хелперы -----------------------------------------------------------------

## Невидимое тело для столкновений — сам предмет рисует модель из Props.
func _collider(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	add_child(body)
	body.add_child(Geo.box_shape(size))
	return body


## Квадрат со снимком в рамке (лицом в комнату, +Z).
func _photo_quad(img: Image, size: Vector2, z: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.position.z = z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Старая фотография: белое поле с зубчатым краем, сепия, ельник на горизонте, двое в ватниках.
## third — только третий силуэт на прозрачном (поверх основного снимка).
static func _photo_image(third: bool) -> Image:
	var w := 128
	var h := 168
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	var figs: Array = [[46.0, 1.0], [80.0, 0.95]] if not third else [[104.0, 1.08]]
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			var border := x < 8 or x >= w - 8 or y < 8 or y >= h - 22
			if not third:
				if border:
					c = Color(0.86, 0.83, 0.74) if (x + y) % 5 != 0 or (x > 2 and x < w - 3 and y > 2 and y < h - 3) else Color(0, 0, 0, 0)
				else:
					var t := float(y) / h
					var sky := Color(0.72, 0.62, 0.46).lerp(Color(0.6, 0.5, 0.36), t)
					var tree_line := 70.0 + 10.0 * sin(x * 0.45) + 6.0 * sin(x * 1.3)
					c = sky if y < tree_line else Color(0.34, 0.27, 0.19)
					if y > 112:
						c = Color(0.66, 0.58, 0.45)   # снег под ногами
					c = c.darkened(rng.randf() * 0.06)
			if border and third:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			for f: Array in figs:
				var cx: float = f[0]
				var sc: float = f[1]
				var head := Vector2(x - cx, y - (60.0 / sc + 8.0)).length() < 7.0 * sc
				var body := y >= 66.0 and y < 128.0 and absf(x - cx) < (9.0 + (y - 66.0) * 0.12) * sc
				if head or body:
					c = Color(0.16, 0.12, 0.09, 1.0) if not third else Color(0.1, 0.08, 0.07, 1.0)
			if not border and not third:
				var vig := Vector2(float(x) / w - 0.5, float(y) / h - 0.45).length()
				c = c.darkened(clampf(vig - 0.25, 0.0, 0.4))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img


func _place(n: Node3D, pos: Vector3) -> Node3D:
	add_child(n)
	n.position = pos
	return n

func _csg(parent: Node, size: Vector3, pos: Vector3, mat: Material, subtract := false) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	if subtract:
		b.operation = CSGShape3D.OPERATION_SUBTRACTION
	else:
		b.material = mat
	parent.add_child(b)
	return b


# --- Занавески и текстиль ----------------------------------------------------

func _build_curtains() -> void:
	# 1. Северное окно радиорубки
	# Карниз шире окна на ~0,5 м и на 13–15 см от стены — шторы висят перед рамой, а не в проёме
	var c_north := Props.curtains(1.6, 0.95)
	c_north.position = Vector3(9.2, 1.415, -1.87)     # карниз над рамой (1,93), низ у подоконника
	add_child(c_north)
	_register_curtain_panels(c_north)

	# 2. Западное окно жилой комнаты
	var c_west := Props.curtains(1.5, 0.95)
	c_west.position = Vector3(-2.37, 1.415, 3.3)
	c_west.rotation.y = deg_to_rad(90.0)
	add_child(c_west)
	_register_curtain_panels(c_west)

	# 3. Южное окно жилой комнаты
	var c_south_l := Props.curtains(1.4, 0.95)
	c_south_l.position = Vector3(0.5, 1.415, 6.47)
	c_south_l.rotation.y = deg_to_rad(180.0)
	add_child(c_south_l)
	_register_curtain_panels(c_south_l)

	# 4. Южное окно коридора
	var c_south_c := Props.curtains(1.15, 0.7)
	c_south_c.position = Vector3(7.5, 1.49, 6.47)
	c_south_c.rotation.y = deg_to_rad(180.0)
	add_child(c_south_c)
	_register_curtain_panels(c_south_c)


func _register_curtain_panels(root: Node3D) -> void:
	for c in root.get_children():
		if c.name.begins_with("Panel"):
			_curtain_panels.append(c as Node3D)


# --- Чердак и лестница -------------------------------------------------------

func _build_attic() -> void:
	# Вид чердака — tools/blender/house_attic.py; коробки ниже тогда только коллизия
	var attic_model := Models.spawn(self, "kedr/house_int_attic", Vector3(0, HOUSE_ATTIC_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.7, "sat": 1.0}) != null
	var keep_int := _int_models
	_int_models = attic_model
	# Настил пола чердака (Y = 2.92) со сплошным покрытием от фронтона до фронтона:
	# Западное крыло пола (от стены X=-2.6 до люка X=5.45):
	_shell(Vector3(8.05, 0.1, 3.6), Vector3(1.425, 2.92, 3.3), Palette.m(&"plank"), true)
	# Восточное крыло пола (от люка X=6.55 до восточной стены X=14.6):
	_shell(Vector3(8.05, 0.1, 3.6), Vector3(10.575, 2.92, 3.3), Palette.m(&"plank"), true)
	# Участки пола к северу и к югу от лаза X=6.0, Z=4.2 (без дыр):
	_shell(Vector3(1.1, 0.1, 2.15), Vector3(6.0, 2.92, 2.575), Palette.m(&"plank"), true)
	_shell(Vector3(1.1, 0.1, 0.35), Vector3(6.0, 2.92, 4.925), Palette.m(&"plank"), true)

	# Стропильные балки и ригели под коньком крыши (шаг выбран так, чтобы не загораживать проход и люк на X=6.0):
	for bx in [0.6, 3.2, 8.8, 12.2]:
		_shell(Vector3(0.12, 0.12, 3.6), Vector3(bx, 4.15, 3.3), Palette.m(&"wood"), false)
		_shell(Vector3(0.12, 1.7, 0.12), Vector3(bx, 3.75, 3.3), Palette.m(&"wood"), false)

	# Ограждающие подстропильные стены (knee-walls) чердака: предотвращают выход игрока сквозь скаты крыши
	_shell(Vector3(17.2, 1.4, 0.2), Vector3(6.0, 3.6, 1.85), Palette.m(&"wood"), true)
	_shell(Vector3(17.2, 1.4, 0.2), Vector3(6.0, 3.6, 4.75), Palette.m(&"wood"), true)
	# Торцевые коллизии фронтонов чердака (запад и восток)
	# Только коллизия: прямоугольная доска торчала бы над скатами — сами фронтоны уже рублены из брёвен.
	for gx: float in [-2.6, 14.6]:
		var gb := StaticBody3D.new()
		gb.collision_layer = Geo.LAYER_WORLD
		gb.collision_mask = 0
		gb.position = Vector3(gx, 4.2, 3.3)
		gb.add_child(Geo.box_shape(Vector3(0.2, 2.6, 6.6)))
		add_child(gb)
	# Кирпичный ствол печной трубы, проходящий сквозь чердак к крыше
	_shell(Vector3(0.65, 1.8, 0.65), Vector3(-1.5, 3.8, 1.0), Palette.m(&"stove"), true)

	_int_models = keep_int
	# Слуховое окно на западном фронтоне (X = -2.65, Z = 3.3, Y = 3.8)
	if not attic_model:
		var dormer_frame := Geo.box_mesh(Vector3(0.04, 0.65, 0.65), Palette.m(&"wood"))
		dormer_frame.position = Vector3(-2.65, 3.8, 3.3)
		add_child(dormer_frame)
		var dormer_glass := Geo.box_mesh(Vector3(0.02, 0.55, 0.55), Palette.glass())
		dormer_glass.position = Vector3(-2.65, 3.8, 3.3)
		add_child(dormer_glass)

	# Приставная деревянная лестница в коридоре (от пола Y=0 до люка Y=2.9):
	var ladder := Props.ladder(2.85)
	ladder.position = Vector3(6.0, 0.0, 4.05)
	ladder.rotation.y = deg_to_rad(180.0)
	add_child(ladder)

	# Интерактив снизу (подняться):
	var climb_up := Geo.interactable(self, Vector3(0.8, 2.4, 0.8), Vector3(6.0, 1.4, 4.05), null, Loc.t(&"it.attic_ladder_up"), func(_p: Player) -> void:
		if Game.player != null:
			Game.player.global_position = Vector3(4.8, 3.05, 3.4)   # на настил рядом с люком, не в проём
			Game.audio.play_2d("res://assets/audio/clank.ogg", -4.0)
			Game.hud.subtitle(Loc.t(&"sub.attic_enter"), 4.0)
	)
	climb_up.name = "AtticClimbUp"
	climb_up.collision_layer = Geo.LAYER_INTERACT

	# Люк и интерактив сверху на чердаке (спуститься):
	var hatch_rim := Geo.box_mesh(Vector3(1.1, 0.08, 1.1), Palette.m(&"wood"))
	hatch_rim.position = Vector3(6.0, 2.96, 4.2)
	add_child(hatch_rim)

	var climb_down := Geo.interactable(self, Vector3(1.1, 0.8, 1.1), Vector3(6.0, 3.2, 4.2), null, Loc.t(&"it.attic_ladder_down"), func(_p: Player) -> void:
		if Game.player != null:
			Game.player.global_position = Vector3(6.0, 0.05, 3.5)
			Game.audio.play_2d("res://assets/audio/clank.ogg", -4.0)
	)
	climb_down.name = "AtticClimbDown"
	climb_down.collision_layer = Geo.LAYER_INTERACT

	# Чердачный хлам вдоль скатов (tools/blender/house_props.py attic_junk, координаты игры): газеты, чемоданы,
	# ковёр, бутыли, веники, лыжи, манекен под простынёй, люлька. Проход посередине свободен.
	if Models.spawn(self, "kedr/attic_junk", Vector3.ZERO, 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.4, "sat": 1.0}) != null:
		for e: Array in [[Vector3(0.7, 0.5, 0.45), Vector3(-1.6, 3.18, 5.2)], [Vector3(0.5, 1.3, 0.5), Vector3(13.6, 3.6, 4.9)],
				[Vector3(0.55, 0.45, 0.4), Vector3(7.4, 3.15, 5.6)], [Vector3(0.5, 0.45, 0.4), Vector3(0.2, 3.15, 1.0)]]:
			_collider(e[0], e[1])
	# Экспедиционный ящик со снаряжением на чердаке:
	_attic_chest = Geo.interactable(self, Vector3(0.9, 0.6, 0.7), Vector3(1.5, 3.22, 2.4), null, "", func(_p: Player) -> void:
		if not _attic_searched:
			_attic_searched = true
			Game.add_spare_flares(2)
			Game.audio.play_3d(CLANK_SOUND, Vector3(1.5, 3.22, 2.4), 0.0)
			Game.hud.subtitle(Loc.t(&"sub.attic_loot"), 5.0)
		else:
			Game.hud.subtitle(Loc.t(&"sub.chest_empty"), 2.5)
	)
	_attic_chest.prompt_provider = func() -> String:
		return Loc.t(&"sub.chest_empty") if _attic_searched else Loc.t(&"it.attic_chest")
	var crate_mesh := Props.crate()
	crate_mesh.position.y = -0.25
	_attic_chest.add_child(crate_mesh)

	# Снежная пыль в воздухе чердака
	var dust := CPUParticles3D.new()
	dust.amount = 25
	dust.lifetime = 4.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(5.0, 0.8, 1.8)
	dust.position = Vector3(5.5, 3.6, 3.3)
	dust.direction = Vector3(-0.2, -0.1, 0.0)
	dust.gravity = Vector3(0.0, -0.05, 0.0)
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.8, 0.85, 0.9, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = mat
	dust.mesh = qm
	add_child(dust)


# --- Керосиновая лампа -------------------------------------------------------

func _on_kerosene_lamp_used(_p: Player) -> void:
	_kerosene_lit = not _kerosene_lit
	if _kerosene_light != null:
		_kerosene_light.visible = _kerosene_lit
		_kerosene_light.light_energy = 1.1 if _kerosene_lit else 0.0
	Game.audio.play_3d(STOVE_SOUND, Vector3(8.0, 1.0, -1.25), -3.0)
	if _kerosene_lit:
		Game.hud.subtitle(Loc.t(&"sub.kerosene_lit"), 3.5)


# --- Суседко (Тень / домовой) ------------------------------------------------

func _tick_creak(delta: float) -> void:
	_creak_t -= delta
	if _creak_t > 0.0:
		return
	var storm_k := Game.weather.intensity if Game.weather != null else 0.0
	# В сильный ветер и буран брёвна и стропила дома стонут чаще от ветрового напора
	_creak_t = Game.rng.randf_range(25.0, 55.0) / (1.0 + storm_k * 0.8) if Game.is_night() else Game.rng.randf_range(70.0, 140.0)
	var snd := Voice.sfx(&"house_creak")
	if snd == "" or Game.player == null or not Game.is_home() or Director.hold:
		return
	var a := Game.rng.randf() * TAU
	var pos := Game.player.global_position + Vector3(cos(a), 0.0, sin(a)) * Game.rng.randf_range(2.0, 4.5)
	pos.y = Game.rng.randf_range(2.2, 3.2) # скрип в углах сруба, стропилах и потолочных балках
	var vol := -12.0 + storm_k * 2.0
	var p := Game.audio.play_3d(snd, pos, vol, 3.5)
	if p != null:
		p.pitch_scale = Game.rng.randf_range(0.92, 1.08)


func _process_susedko(delta: float) -> void:
	# Суседко в подпечье не показывается: без угощения скребётся в темноте под печью,
	# угощение к ночи съедено — на блюдце крошки и сажа (заметишь, когда вернёшься в комнату).
	if _susedko_hearth != null and is_instance_valid(_susedko_hearth):
		_susedko_hearth_timer -= delta
		if _susedko_hearth_timer <= 0.0:
			_susedko_hearth_timer = randf_range(30.0, 65.0)
			var hearth := _susedko_hearth.global_position
			if not Game.spirit_treat and Game.is_night():
				Game.audio.play_3d("res://assets/audio/tree_creak_v2.ogg", hearth, -18.0, 2.0)
			elif Game.spirit_treat and Game.is_night() and is_instance_valid(_treat_bread) and _treat_bread.visible 					and _treat_set_min >= 0.0 and Game.shift_minutes - _treat_set_min > 40.0 					and Game.player != null and not Game.player.is_looking_at(hearth, 70.0):
				_treat_bread.visible = false
				_treat_eaten_seen = false
				_spawn_damp_footprint(hearth + Vector3(0.35, 0.0, 0.25))
				if Game.zone == &"room":
					Game.audio.play_3d("res://assets/audio/step_wood_1.ogg", hearth, -16.0, 2.0)
		if not _treat_eaten_seen and Game.zone == &"room" and Game.player != null 				and Game.player.is_looking_at(_susedko_hearth.global_position, 30.0):
			_treat_eaten_seen = true
			Game.hud.subtitle(Loc.t(&"sub.treat_eaten"), 4.5)
			Director.add_tension(6.0, "угощение съедено")

	if not Game.is_night() or Game.night < 2:
		return
	if _susedko_peeking and is_instance_valid(_susedko_node):
		if Game.player != null:
			var s_pos := _susedko_node.global_position
			var looking := Game.player.is_looking_at(s_pos, 46.0)
			var flash_on := Game.player.flashlight_on() and Game.player.is_looking_at(s_pos, 65.0)
			if looking or flash_on:
				_susedko_retreat()
		return

	# Контакт в темноте при блэкауте
	if not Game.power_on and is_instance_valid(_susedko_node):
		if Game.player != null and Game.player.global_position.distance_to(_susedko_node.global_position) < 1.6:
			if not Game.player.flashlight_on():
				Game.add_cold(22.0)
				Game.player.shake(0.08, 0.5)
				Game.audio.play_3d("res://assets/audio/sub_drop.ogg", _susedko_node.global_position, 0.0)
				Game.hud.subtitle(Loc.t(&"sub.susedko_blackout"), 4.0)
				Director.add_tension(15.0, "ледяное прикосновение")
				_susedko_retreat()
				return

	_susedko_timer -= delta
	if _susedko_timer <= 0.0:
		_susedko_timer = randf_range(45.0, 90.0)
		_try_spawn_susedko()


func _try_spawn_susedko() -> void:
	if _susedko_peeking or Game.player == null:
		return
	var p_zone := Game.zone
	if p_zone != &"room" and p_zone != &"radio_room":
		return

	# Печь горит жарко — дух не приближается к жилой комнате
	var stove_hot := Game.stove_wood > 30.0

	var spawn_pos := Vector3.ZERO
	var look_dir := Vector3.ZERO
	if p_zone == &"room":
		if stove_hot:
			return # огонь отпугивает
		spawn_pos = Vector3(3.6, 0.0, 3.2) # в дверном проёме жилой комнаты
		look_dir = Vector3(-1, 0, 0)
	elif p_zone == &"radio_room":
		if randf() > 0.5:
			spawn_pos = Vector3(7.55, 0.0, 2.3) # проём коридора
			look_dir = Vector3(0, 0, -1)
		else:
			spawn_pos = Vector3(5.3, 0.0, -1.95) # проём холодной кладовой
			look_dir = Vector3(0, 0, 1)

	# Игрок не должен смотреть прямо на место спавна в момент появления
	if Game.player.is_looking_at(spawn_pos, 55.0):
		return

	# Суседко не показывается: в проёме шлёпают босые ноги и кто-то дышит. Обернёшься — мокрый след.
	_susedko_node = Node3D.new()
	_susedko_node.name = "SusedkoMark"
	_susedko_node.position = spawn_pos
	add_child(_susedko_node)
	_susedko_node.look_at(_susedko_node.global_position + look_dir, Vector3.UP)
	_susedko_peeking = true
	Game.audio.play_3d("res://assets/sfx/barefoot_wood%s.ogg" % ["", "_v2", "_v3", "_v4"].pick_random(), spawn_pos, -10.0, 4.0)
	Game.audio.play_3d("res://assets/audio/breath_loop.ogg", spawn_pos + Vector3(0, 0.9, 0), -18.0, 3.0, 2.5)

	# Если игрок не обернулся за 4.5 секунды — уходит тихо, а след остаётся: найдёшь потом
	var tree := get_tree()
	if tree != null:
		tree.create_timer(4.5, false).timeout.connect(func():
			if _susedko_peeking and is_instance_valid(_susedko_node):
				_spawn_damp_footprint(_susedko_node.global_position)
				_susedko_node.queue_free()
				_susedko_peeking = false
		)


func _susedko_retreat() -> void:
	if not is_instance_valid(_susedko_node):
		_susedko_peeking = false
		return
	_susedko_peeking = false
	var node := _susedko_node
	_susedko_node = null

	# Влажное тёмное пятно на полу, где стоял дух
	_spawn_damp_footprint(node.global_position)

	Game.audio.play_3d("res://assets/audio/tree_creak.ogg", node.global_position, -8.0, 8.0)
	Director.add_tension(8.0, "суседко скрылся")
	Game.hud.subtitle(Loc.t(&"sub.susedko_retreat"), 3.0)

	node.queue_free()


func _spawn_damp_footprint(pos: Vector3) -> void:
	var fp := Footprints.make(&"wet", Vector3(pos.x, 0.05, pos.z), Game.rng.randf() * TAU, Game.rng.randf() < 0.5)
	add_child(fp)
	Geo.free_after(fp, 30.0)

