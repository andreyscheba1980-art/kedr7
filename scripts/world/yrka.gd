class_name YrkaThreat
extends Node
## Ырка — угроза снаружи. Не часть пула директора: это отдельная система с честными правилами.
##
## threat растёт, пока игрок снаружи, и быстрее — в темноте, вне леера, в метель, без питания.
## Стадии предупреждают заранее: свист в лесу → шаги за спиной → зов знакомым голосом → погоня.
## Правила (они же в журнале Семёнова):
##   • зовут сзади — НЕ оборачивайся и не стой: иди к свету/двери. Обернулся — он в упор;
##   • не беги, пока он не бежит за тобой: бег на зове — сразу погоня;
##   • в упор или в погоне спасает огонь: луч фонаря прямо в морду (жжёт заряд) или ракета;
##   • крыша (дом, сарай) и свет над крыльцом — безопасно.
## Ночи с yrka_max < 4 учат правилам без смерти: обернулся — морда в упор, крик, и он исчезает.

enum Stage { CALM, STALKING, CALLING, PRESSURE, CONTACT, CHASE, RETREAT }

const WHISTLE_AT := 20.0
const STALK_AT := 35.0
const CALL_AT := 50.0
const GLIMPSE_AT := 60.0
const PRESSURE_AT := 74.0
const CHASE_AT := 92.0
const CHASE_SPEED := 3.4
const CATCH_DIST := 1.2
const BEAM_DEG := 12.0
const BEAM_RANGE := 16.0
const BEAM_TIME := 0.85
const BEAM_DRAIN := 14.0

const WHISTLE := "res://assets/audio/whistle.ogg"
const STEPS := "res://assets/audio/yrka_steps.ogg"
const GROWL := "res://assets/audio/growl.ogg"
const RUN_LOOP := "res://assets/audio/yrka_run_loop.ogg"
const SHRIEK := "res://assets/audio/shriek.ogg"
const SCREAM := "res://assets/audio/scream.ogg"

const VOICES: Array[String] = [
	"res://assets/audio/yrka_voice_1.ogg",
	"res://assets/audio/yrka_voice_2.ogg",
	"res://assets/audio/yrka_voice_3.ogg",
	"res://assets/audio/yrka_voice_4.ogg"
]
const VOICE_SUBS: Array[StringName] = [&"yrka.voice.1", &"yrka.voice.2", &"yrka.voice.3", &"yrka.voice.4"]
const STILL_LIMIT := 6.0       ## сколько можно стоять на зове, прежде чем он подойдёт вплотную

var enabled := false
var threat := 0.0
var stage := Stage.CALM
var rate := 0.0              ## для оверлея отладки

var _creature: Node3D
var _glimpse_t := 0.0
var _glimpse_cd := 0.0
var _whistled := false
var _last_breath_t := -100.0
var _steps_heard := 0          ## шагов за спиной за эту вылазку (сбрасывается дома)
var _stalk_t := 3.0
var _cooldown := 0.0
var _beam_t := 0.0
var _chase_t := 0.0
var _run_player: AudioStreamPlayer3D
var _door_open_t := 0.0
var _whistle_cd := 0.0
var _struck_this_night := false
var _pre_chase_warned := false
var _voice_timer := 7.0
var _contact_timer := 0.0
var _still_close_t := 0.0
var _still_steps_cd := 0.0
var _last_voice_pos: Vector3 = Vector3.ZERO
var _pull_timer := 0.0
var _contact_lesson := false

## Уровень 1: «Невидимый агент» (Математика в памяти)
var virtual_pos := Vector2(35.0, -75.0)   ## координаты твари в тайге
var _target_noise_pos := Vector2.ZERO
var _has_noise_target := false
var _patrol_idx := 0
var _roam_timer := 0.0

const WAYPOINTS: Array[Vector2] = [
	Vector2(35.0, -75.0),  # Юго-восточная сопка
	Vector2(48.0, -35.0),  # Восточный лабаз
	Vector2(28.0, -26.0),  # Опора ЛЭП и бурелом
	Vector2(-35.0, -45.0), # Западный распадок
	Vector2(-42.0, 20.0),  # Берег озера
	Vector2(12.0, 38.0),   # Северная опушка
	Vector2(36.0, 10.0),   # Метеоплощадка
]


## Ракета: прогоняет Ырку при контакте или погоне, давая 90-120 сек передышки.
func _on_flare(_pos: Vector3) -> void:
	if (stage == Stage.CHASE or stage == Stage.CONTACT) and _creature != null:
		_end_chase("repelled")
		stage = Stage.RETREAT
		_cooldown = 90.0
	else:
		_clear_glimpse()
		threat = minf(threat, 10.0)
		_cooldown = 60.0
	# Отбрасываем виртуального агента далеко в чащу
	if Game.player != null:
		var p_xz := Vector2(Game.player.global_position.x, Game.player.global_position.z)
		virtual_pos = p_xz + (virtual_pos - p_xz).normalized() * 70.0
	Director.add_tension(-15.0, "ракета")


## Реакция на события шума из EventBus (с учётом направления ветра из Synoptic)
func _on_noise_emitted(pos: Vector3, volume: float, _type: StringName) -> void:
	if not enabled or stage == Stage.CHASE or stage == Stage.RETREAT:
		return
	var p2 := Vector2(pos.x, pos.z)
	var to_noise := p2 - virtual_pos
	var dist := to_noise.length()

	# Ветер несёт звук: если ветер дует от игрока к Ырке, слышимость возрастает
	var wind_mult := 1.0
	if Game.synoptic != null and to_noise.length_squared() > 0.01:
		var w_rad := deg_to_rad(Game.synoptic.wind_azimuth_deg)
		var wind_dir := Vector2(-sin(w_rad), -cos(w_rad))
		var dot := wind_dir.dot(to_noise.normalized())
		wind_mult = clampf(1.0 + dot * 0.85, 0.35, 2.2)

	var hearing_limit := 70.0 * volume * wind_mult
	if dist <= hearing_limit:
		_target_noise_pos = p2
		_has_noise_target = true
		notice_sound(pos, volume)


## Звуковая реакция Ырки: кашель, крик, шум микрофона, падение предметов
func notice_sound(pos: Vector3, intensity: float = 1.0) -> void:
	if not enabled or stage == Stage.CHASE or stage == Stage.RETREAT:
		return
	threat = minf(threat + 16.0 * intensity, 100.0)
	_whistle_cd = maxf(_whistle_cd - 15.0, 0.0)
	Director.add_tension(10.0 * intensity, "Ырка среагировал на звук")
	if threat >= CALL_AT and stage != Stage.CONTACT and stage != Stage.CHASE:
		var growl_pos := _point_around(Game.rng.randf_range(-45.0, 45.0), Game.rng.randf_range(12.0, 20.0))
		Game.audio.play_3d(GROWL, growl_pos, 2.5, 9.0)


func _ready() -> void:
	Game.yrka = self
	EventBus.flare_fired.connect(_on_flare)
	EventBus.noise_emitted.connect(_on_noise_emitted)
	call_deferred(&"_ensure_creature")
	_init_for_night()


func _init_for_night() -> void:
	# Ночь 1: ознакомительная, игрок осваивает быт станции без уличного хищника
	if Game.night <= 1:
		enabled = false
		return
	enabled = true
	var seed_idx: int = int(abs(int(Game.run_seed) ^ 0x3a)) % WAYPOINTS.size()
	virtual_pos = WAYPOINTS[seed_idx]


func stage_name() -> String:
	if stage == Stage.CHASE:
		return "ПОГОНЯ"
	if stage == Stage.CONTACT:
		return "ВЗГЛЯД В УПОР"
	if stage == Stage.PRESSURE:
		return "НАВАЖДЕНИЕ"
	if stage == Stage.CALLING:
		return "ЗОВ"
	if stage == Stage.RETREAT:
		return "отступает"
	if threat >= STALK_AT:
		return "шаги"
	if threat >= WHISTLE_AT:
		return "свист"
	return "тихо"


## Отладка (F2): сразу погоня.
func force_chase() -> void:
	if Game.is_outside() and stage != Stage.CHASE:
		threat = CHASE_AT
		_start_chase()


## «Голос из леса» увёл с леера: на смертельных ночах — погоня, на учебных — морда в упор.
func lure_strike() -> void:
	if not enabled or stage == Stage.CHASE or stage == Stage.CONTACT or not Game.is_outside() or Game.player == null:
		return
	if int(Game.cfg.get("yrka_max", 4)) >= 4:
		threat = CHASE_AT
		_start_chase()
	else:
		threat = maxf(threat, CALL_AT)
		_start_contact()


## Ырка входит в дом через открытую дверь (ночи 6–7).
func force_house_chase() -> void:
	if stage == Stage.CHASE or not enabled:
		return
	_clear_glimpse()
	stage = Stage.CHASE
	_chase_t = 0.0
	_beam_t = 0.0
	_spawn_chaser(Vector3(15.8, 0.0, 3.5))
	Game.hud.subtitle(Loc.t(&"sub.yrka_door"), 3.0)


func _process(delta: float) -> void:
	if not enabled or Game.dead or Game.dying or Game.shift_over or Game.player == null:
		return
	if stage == Stage.CHASE:
		_update_chase(delta)
		return
	if stage == Stage.CONTACT:
		_update_contact(delta)
		return

	if _cooldown > 0.0:
		_cooldown -= delta
		if stage == Stage.RETREAT and _cooldown <= 0.0:
			stage = Stage.CALM

	if _whistle_cd > 0.0:
		_whistle_cd -= delta

	rate = _compute_rate()
	if rate > 0.0:
		rate *= Game.threat_mult()
	if _cooldown > 0.0:
		rate = minf(rate, 0.0)
	var max_stage := int(Game.cfg.get("yrka_max", 4))
	# Потолок угрозы по ночи: на «учебных» ночах зов и погоня физически недостижимы.
	var cap := CHASE_AT if max_stage >= 4 else PRESSURE_AT - 2.0 if max_stage == 3 else CALL_AT - 4.0 if max_stage == 2 else WHISTLE_AT + 10.0
	threat = clampf(threat + rate * delta, minf(_floor(), cap), cap)

	if threat < WHISTLE_AT - 10.0:
		_whistled = false

	# Предупреждающий рык перед началом погони (на пороге 82%)
	if threat >= 82.0 and not _pre_chase_warned and max_stage >= 4:
		_pre_chase_warned = true
		var pos := _point_around(180.0, 10.0)
		Game.audio.play_3d(GROWL, pos, 3.0, 8.0)
		Game.hud.subtitle(Loc.t(&"sub.yrka_stalk"), 2.5)
		Director.add_tension(12.0, "рык за спиной")
	elif threat < 70.0:
		_pre_chase_warned = false

	# Ночи 6–7: открытая дверь — приглашение. Постоит открытой — он войдёт.
	if bool(Game.cfg.get("yrka_house", false)) and Game.is_home() and Game.level.door_open:
		_door_open_t += delta
		if _door_open_t > (40.0 if Game.is_story() else 25.0):
			_door_open_t = 0.0
			force_house_chase()
			return
	else:
		_door_open_t = 0.0

	if not Game.is_outside():
		_steps_heard = 0
		_clear_glimpse()
		_still_close_t = 0.0
		_pull_timer = 0.0
		if stage != Stage.RETREAT:
			stage = Stage.CALM
		return

	# Переходы между стадиями страха вне погони
	if stage != Stage.RETREAT:
		if threat >= PRESSURE_AT and max_stage >= 3:
			stage = Stage.PRESSURE
		elif threat >= CALL_AT and max_stage >= 2:
			stage = Stage.CALLING
		elif threat >= STALK_AT:
			stage = Stage.STALKING
		else:
			stage = Stage.CALM

	if threat >= WHISTLE_AT and not _whistled and _whistle_cd <= 0.0:
		_whistled = true
		_play_whistle()

	if threat >= STALK_AT and max_stage >= 2:
		_stalk_t -= delta
		if _stalk_t <= 0.0:
			_stalk_t = Game.rng.randf_range(2.0, 4.5) if Game.after_hour(2) else Game.rng.randf_range(4.0, 7.0)
			_play_steps_behind()

	if max_stage >= 3:
		_update_glimpse(delta)

	if stage == Stage.CALLING or stage == Stage.PRESSURE:
		_update_voice_and_drift(delta)

	if threat >= CHASE_AT and max_stage >= 4:
		_start_chase()

	_update_virtual_movement(delta)
	_update_flashlight_eyeshine()


func _update_virtual_movement(delta: float) -> void:
	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_roam_timer = 1.0
		var target := _target_noise_pos if _has_noise_target else WAYPOINTS[_patrol_idx]
		var to_target := target - virtual_pos
		if to_target.length() < 7.0:
			if _has_noise_target:
				_has_noise_target = false
			else:
				_patrol_idx = (_patrol_idx + 1) % WAYPOINTS.size()
		else:
			var speed := 3.2 if _has_noise_target else 1.6
			virtual_pos += to_target.normalized() * speed
			# Ночная эскалация радиуса
			var min_r := 18.0 if Game.night >= 4 else (38.0 if Game.night == 3 else 68.0)
			if virtual_pos.length() < min_r:
				virtual_pos = virtual_pos.normalized() * min_r


func _update_flashlight_eyeshine() -> void:
	if _creature == null or not _creature.visible or Game.player == null:
		return
	var rig := _creature as CreatureRig
	if rig == null:
		return
	var p := Game.player
	if not p.flashlight_on() or Game.flash_charge <= 0.0:
		rig.set_eye_glow(0.0)
		return
	var head := _creature.get_node_or_null("Head") as Node3D
	var head_pos := head.global_position if head != null else _creature.global_position + Vector3(0, 1.4, 0)
	var to_mob := (head_pos - p.camera.global_position).normalized()
	var beam := -p.camera.global_basis.z
	var dot := maxf(beam.dot(to_mob), 0.0)
	var k := pow(dot, 18.0)
	rig.set_eye_glow(k * 2.8)


func _update_voice_and_drift(delta: float) -> void:
	var p := Game.player
	if p == null:
		return

	var lethal := int(Game.cfg.get("yrka_max", 4)) >= 4
	# Правило паники: бег на зове — он срывается следом (на учебных ночах — только визг и шаги).
	if p.is_sprinting():
		Game.audio.play_3d(SHRIEK, p.global_position + Vector3(0, 1.5, 0), 4.0, 10.0)
		Game.hud.subtitle(Loc.t(&"yrka.dont_run"), 2.0, 2)
		if lethal:
			_start_chase()
		else:
			_start_contact()   # учебная ночь: морда в упор и урок, а не «награда» за бег
		return

	# Правило оцепенения: стоять долго нельзя — он подходит вплотную. Работа руками (держать E)
	# не в счёт: снимать показания и сбивать лёд можно спокойно, шаги лишь приближаются.
	var move_spd := p.velocity.length()
	if move_spd < 0.25 and Game.activity != &"working":
		# Схема и прочие окна — тоже «стоишь», но время идёт медленнее: правило 5 не должно убивать по правилу 7.
		_still_close_t += delta * (0.4 if Game.hud != null and Game.hud.modal() != null else 1.0)
		_still_steps_cd -= delta
		if _still_close_t >= STILL_LIMIT * 0.45 and _still_steps_cd <= 0.0:
			_still_steps_cd = 1.5
			_play_steps_behind()
		if _still_close_t >= STILL_LIMIT:
			_still_close_t = 0.0
			_start_contact()
			return
	else:
		_still_close_t = maxf(_still_close_t - delta * 0.8, 0.0)

	# Таймер шёпота
	_voice_timer -= delta
	if _voice_timer <= 0.0:
		_voice_timer = Game.rng.randf_range(5.5, 8.5) if stage == Stage.PRESSURE else Game.rng.randf_range(8.0, 13.0)
		var v_idx := Game.rng.randi_range(0, VOICES.size() - 1)
		var v_path := VOICES[v_idx]
		# Озвученные варианты: тот же текст голосом мамы, Семёнова или твоим собственным.
		var alts: Array[String] = [v_path]
		for who in ["mom", "sem"]:
			var ap := Voice.path(StringName("yrka_%s_%d" % [who, v_idx + 1]))
			if ap != "":
				alts.append(ap)
		if Voice.has(&"yrka_vic_1") and Game.night >= 5:
			alts.append(Voice.path(&"yrka_vic_1"))
		v_path = alts[Game.rng.randi_range(0, alts.size() - 1)]
		var v_sub: StringName = VOICE_SUBS[v_idx]
		var angle_deg := 180.0 + Game.rng.randf_range(-25.0, 25.0)
		var dist := Game.rng.randf_range(2.8, 4.8) if stage == Stage.PRESSURE else Game.rng.randf_range(4.5, 7.5)
		_last_voice_pos = _point_around(angle_deg, dist)
		_pull_timer = 3.6

		# Вакуумная тишина: перед шёпотом метель смолкает
		Game.audio.trigger_vacuum(3.2)
		Game.audio.play_3d(v_path, _last_voice_pos + Vector3(0, 1.4, 0), 3.2, 7.0)
		Game.hud.subtitle(Loc.t(v_sub), 2.8)
		Director.add_tension(10.0, "шёпот за спиной")

	# Магнитное наваждение: голова медленно тянется назад к шёпоту
	if _pull_timer > 0.0:
		_pull_timer -= delta
		var to_voice := (_last_voice_pos - p.global_position)
		to_voice.y = 0.0
		if to_voice.length_squared() > 0.1:
			var target_yaw := atan2(-to_voice.x, -to_voice.z)
			var strength := 0.55 if stage == Stage.CALLING else 1.25
			if Game.activity != &"working":   # руки заняты делом (держишь E) — наваждение не сбивает прицел
				p.apply_yaw_drift(target_yaw, strength, delta)

		# Правило «Не оборачивайся»: посмотрел назад прямо на голос — контакт лицом к лицу!
		var cam_fwd := -p.camera.global_basis.z
		cam_fwd.y = 0.0
		if cam_fwd.length_squared() > 0.01:
			var dot := cam_fwd.normalized().dot(to_voice.normalized())
			if dot > 0.65:
				_pull_timer = 0.0
				NightMemory.mark(&"turned")
				_start_contact()


func _start_contact() -> void:
	_clear_glimpse()
	stage = Stage.CONTACT
	_contact_timer = 1.45
	_pull_timer = 0.0
	_still_close_t = 0.0

	var p := Game.player
	var fwd := -p.camera.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()

	var face_pos := p.global_position + fwd * 1.55
	_ensure_creature()
	_creature.visible = true
	_creature.global_position = face_pos
	_creature.set_process(true)
	var rig := _creature as CreatureRig
	if rig != null:
		rig.gait = 0.0
		rig.pose_override = &"lunge" if rig.has_clip(&"lunge") else &""
	_face_player(_creature)

	Game.audio.play_3d(SHRIEK, face_pos + Vector3(0, 1.4, 0), 5.0, 8.0)
	p.shake(0.08, 0.6)
	Director.add_tension(35.0, "Ырка: взгляд в упор!")
	_beam_t = 0.0
	# Учебные ночи: морда в упор, крик — и пропал. Урок «не оборачивайся» без смерти.
	if int(Game.cfg.get("yrka_max", 4)) < 4:
		_contact_timer = 0.9
		_contact_lesson = true
		Game.hud.subtitle(Loc.t(&"yrka.lesson"), 3.0, 2)
		return
	_contact_lesson = false
	# Вспышка ужаса: фонарь гаснет. Спасает только реакция — включить (F) и держать в морду, или ракета.
	if p.flashlight_on():
		p.toggle_flashlight()
	_contact_timer = 1.9
	var has_flare := Game.has_item(&"flare_gun") and Game.flares_total() > 0
	Game.hud.subtitle(Loc.t(&"yrka.contact_flare") if has_flare else Loc.t(&"yrka.contact_light"), 2.5, 2)


func _update_contact(delta: float) -> void:
	var p := Game.player
	if p == null:
		return

	if Game.is_indoors() or (Game.yard != null and Game.yard.is_porch_lit(p.global_position)):
		_end_chase("escaped")
		Game.hud.subtitle(Loc.t(&"yrka.roof_saved"), 2.0)
		return

	_contact_timer -= delta
	var fwd := -p.camera.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.01:
		fwd = fwd.normalized()
		_creature.global_position = p.global_position + fwd * 1.5
	_face_player(_creature)

	if _contact_lesson:
		if _contact_timer <= 0.0:
			_contact_lesson = false
			_end_chase("escaped")
			threat = 15.0
			_cooldown = 40.0
		return

	# В упор спасает огонь: ракета (см. _on_flare) или луч фонаря прямо в морду — держать, пока корчится.
	if p.flashlight_on() and Game.flash_charge > 3.0:
		_beam_t += delta
		_contact_timer += delta * 0.8      # свет его держит
		Game.flash_charge = maxf(Game.flash_charge - BEAM_DRAIN * 1.5 * delta, 0.0)
		_creature.position += Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.04, 0.04))
		var rig := _creature as CreatureRig
		var shield: bool = bool(Game.hunter_brain.call(&"should_shield_eyes")) if Game.hunter_brain != null else false
		if shield and rig != null:
			rig.set_rest(&"ArmL", Vector3(deg_to_rad(-85.0), deg_to_rad(35.0), deg_to_rad(45.0)))
		var threshold := BEAM_TIME * (2.4 if shield else 1.6)
		if _beam_t >= threshold:
			_end_chase("repelled")
			return

	if _contact_timer <= 0.0:
		_catch()


func _compute_rate() -> float:
	var p := Game.player
	if Game.is_indoors():
		return -3.5
	if Game.yard != null and Game.yard.is_porch_lit(p.global_position):
		return -4.0

	# Стелс: задержка дыхания без движения скрывает пар изо рта и сбивает тварь со следа
	if p.holding_breath:
		if p.velocity.length() < 1.8:
			return -3.2
		else:
			return -0.8

	var r := 0.75        # базовая скорость накопления угрозы
	if not p.flashlight_on():
		r += 1.6           # без фонаря в темноте опаснее

	# Шар-пилот освещает двор сверху: открытый огонь фонарика в небе подавляет Ырку
	if Game.balloon_launched and Game.yard != null and Game.yard.balloon_covers(p.global_position):
		r -= 2.6
	# Расстояние до ближайшего отапливаемого / освещенного объекта станции
	var p_pos := p.global_position
	var d_house := p_pos.distance_to(Station.DOOR_LAMP)
	var d_shed := p_pos.distance_to(Yard.SHED)
	var d_meteo := p_pos.distance_to(Yard.METEO)
	var d_mast := p_pos.distance_to(Yard.MAST)
	var d_wood := p_pos.distance_to(Yard.WOODPILE)
	var min_fac := minf(minf(d_house, minf(d_shed, d_wood)), minf(d_meteo, d_mast))
	# Открытые днём точки (изба, рыбацкий домик, ретранслятор, люк) — тоже «свои» места.
	if Game.yard != null:
		if Game.yard.izba_open:
			min_fac = minf(min_fac, p_pos.distance_to(Yard.IZBA))
		for site: String in Game.yard.open_sites:
			if Game.yard.open_sites[site]:
				var sp: Vector3 = {"repeater": Yard.REPEATER, "lake": Yard.LAKE_SHACK, "bunker": Yard.BUNKER, "zimnik": Yard.ZIMNIK}.get(site, Yard.SHED)
				min_fac = minf(min_fac, p_pos.distance_to(sp))
	if Game.final_call:
		min_fac = 0.0   # ночь 7, зов: уход по зимнику — осознанный выбор, а не штраф за дальность
	if min_fac > 20.0:
		r += minf((min_fac - 20.0) * 0.07, 1.4)
	r += Game.weather.intensity * 0.7
	if not Game.power_on:
		r += 0.5
	if p.cranking:
		r += 0.3          # жучок привлекает
	if p.is_sprinting() and threat >= WHISTLE_AT:
		r += 1.0          # правило 6: свист — не беги, бег он слышит
	# Если игрок держится за леер (спасательный трос), угроза растёт медленнее
	if Game.yard != null:
		var dist_to_rope := Game.yard.distance_to_path(p_pos)
		if dist_to_rope < 2.5:
			r *= 0.65
		elif dist_to_rope > 6.0:
			r += 1.25     # сошёл с леера в темноту и сугробы
	if Game.after_hour(2):
		r *= 1.25          # сбалансировано, чтобы успевать делать ночные дела
	if Game.after_hour(3):
		r *= 1.18
	if r > 0.0:
		r *= Consequences.boldness()     # запущенная станция: чем больше неисправно, тем она смелее
	return r


## Ночь становится опаснее, но оставляет игроку шансы на вылазки.
func _floor() -> float:
	# Молчащая станция притягивает: каждая пропущенная в срок сводка поднимает порог (правило 1).
	var silent := 8.0 * Game.reports_silent
	if Game.after_hour(3):
		return 28.0 + silent      # после 3:00 — шаги и шепоты, но не мгновенный спавн погони
	if Game.after_hour(2):
		return 18.0 + silent      # после 2:00 — умеренный порог
	if Game.after_hour(1):
		return 12.0 + silent
	return silent


# --- Предупреждения ----------------------------------------------------------

## Таймер отдыха после отпугивания (HunterBrain: после второй ракеты тварь отходит ненадолго).
func set_cooldown(sec: float) -> void:
	_cooldown = sec


func _play_whistle() -> void:
	if Game.is_home() or Game.is_indoors() or Game.player == null:
		return
	if _whistle_cd > 0.0:
		return
	if Game.hunter_brain != null and bool(Game.hunter_brain.call(&"is_silent_now")):   # идёт засада у выхода
		return
	_whistle_cd = Game.rng.randf_range(35.0, 60.0)
	# Свист исходит из реального направления невидимого агента в тайге
	var p_pos := Game.player.global_position
	var to_virt := Vector3(virtual_pos.x, p_pos.y, virtual_pos.y) - p_pos
	to_virt.y = 0.0
	var w_dir := to_virt.normalized() if to_virt.length_squared() > 0.1 else Vector3.FORWARD
	var w_dist := clampf(to_virt.length(), 24.0, 45.0)
	var pos := p_pos + w_dir * w_dist + Vector3(0, 2.0, 0)
	Game.audio.play_3d(WHISTLE, pos, 2.2, 10.0)
	Director.add_tension(8.0, "свист в лесу")


func _play_steps_behind() -> void:
	var pos := _point_around(180.0 + Game.rng.randf_range(-30.0, 30.0), Game.rng.randf_range(4.0, 7.5))
	# Два-три тяжёлых хруста. Старый yrka_steps.ogg (длинное шипение) на повторе звучал как шёпот «спи… спи…».
	var to_p := Game.player.global_position - pos
	to_p.y = 0.0
	Game.audio.play_snow_steps(pos, Game.rng.randi_range(2, 3), 1.0, 5.0, 0.78, to_p.normalized())
	# Дыхание за спиной — редко и низко.
	var now := Time.get_ticks_msec() / 1000.0
	if Game.rng.randf() < 0.3 and now - _last_breath_t > 14.0:
		_last_breath_t = now
		var b := Game.audio.play_3d("res://assets/audio/breath_loop.ogg", pos + Vector3(0, 1.4, 0), -4.0, 3.0)
		if b != null:
			b.pitch_scale = 0.78
	# Первые шаги пугают, сотые — уже фон: +5, а дальше +2, пока игрок не уйдёт в дом.
	Director.add_tension(5.0 if _steps_heard < 2 else 2.0, "шаги за спиной")
	_steps_heard += 1


func _ensure_creature() -> void:
	if _creature != null and is_instance_valid(_creature):
		return
	if Game.level == null:
		return
	_creature = Creatures.make_yrka()
	_creature.visible = false
	_creature.position = Vector3(0, -100, 0)
	_creature.set_process(false)
	Game.level.add_child(_creature)

	_run_player = AudioStreamPlayer3D.new()
	_run_player.stream = AudioDirector.cached_stream(RUN_LOOP)
	_run_player.unit_size = 5.0
	_run_player.volume_db = 2.0
	_run_player.position = Vector3(0, 0.3, 0)
	_creature.add_child(_run_player)
	_run_player.finished.connect(_run_player.play)


func _update_glimpse(delta: float) -> void:
	_glimpse_cd -= delta
	if _creature != null and _creature.visible:
		_glimpse_t -= delta
		var eyes := _creature.get_node("Head") as Node3D
		# Посмотрел прямо или прошло время — исчезает, как будто и не было.
		if _glimpse_t <= 0.0 or Game.player.is_looking_at(eyes.global_position, 9.0):
			_clear_glimpse()
		return
	if threat >= GLIMPSE_AT and _glimpse_cd <= 0.0:
		_glimpse_cd = Game.rng.randf_range(4.5, 9.0) if Game.after_hour(2) else Game.rng.randf_range(8.0, 14.0)
		var side := 1.0 if Game.rng.randf() > 0.5 else -1.0
		var pos := _point_around(side * Game.rng.randf_range(25.0, 45.0), Game.rng.randf_range(11.0, 18.0))
		_ensure_creature()
		_creature.visible = true
		_creature.global_position = pos
		_creature.set_process(true)
		var rig := _creature as CreatureRig
		if rig != null:
			rig.gait = 0.0
			rig.pose_override = &"peek" if Game.rng.randf() < 0.55 else &"sniff"
		_face_player(_creature)
		_glimpse_t = 3.2
		Director.add_tension(8.0, "глаза в лесу")


func _clear_glimpse() -> void:
	if _creature != null and is_instance_valid(_creature) and stage != Stage.CHASE:
		_creature.visible = false
		_creature.position = Vector3(0, -100, 0)
		_creature.set_process(false)


# --- Погоня ------------------------------------------------------------------

func _start_chase() -> void:
	# Оберег манси: раз за ночь трескается — и тварь отступает, не начав погоню
	if Gear.amulet_ready():
		Gear.use_amulet()
		_clear_glimpse()
		threat = maxf(STALK_AT - 6.0, 0.0)
		set_cooldown(70.0)
		return
	_clear_glimpse()
	stage = Stage.CHASE
	_chase_t = 0.0
	_beam_t = 0.0
	var pos := _point_around(180.0 + Game.rng.randf_range(-25.0, 25.0), 15.0)
	if Game.level.zone_at(pos) != &"yard":
		pos = _point_around(90.0, 15.0)   # не спавнимся в доме или сарае
	_spawn_chaser(pos)


func _spawn_chaser(pos: Vector3) -> void:
	_ensure_creature()
	_creature.visible = true
	_creature.global_position = pos
	_creature.set_process(true)
	var rig := _creature as CreatureRig
	if rig != null:
		rig.gait = 1.0
		rig.gait_speed = 13.0
		rig.pose_override = &""
	_face_player(_creature)
	Game.audio.play_3d(GROWL, pos + Vector3(0, 1.2, 0), 6.0, 6.0)
	if _run_player != null and not _run_player.playing:
		_run_player.play()
	Game.player.shake(0.03, 0.4)
	Game.add_fatigue(10.0)
	Director.add_tension(30.0, "Ырка: погоня")


func _update_chase(delta: float) -> void:
	var p := Game.player
	_chase_t += delta
	var to := p.global_position - _creature.global_position
	to.y = 0.0
	var dist := to.length()

	var c := _creature.global_position
	var inside_ok := bool(Game.cfg.get("yrka_house", false)) and Game.is_home() and Game.zone != &"attic" and (Game.level.door_open or _in_house(c))   # на чердак по лестнице не полезет
	if not inside_ok and (Game.is_indoors() or (Game.yard != null and Game.yard.is_porch_lit(p.global_position))):
		_end_chase("escaped")
		return

	# Луч фонаря в лицо: останавливается, а если держать — отступает.
	var chest := (_creature.get_node("Chest") as Node3D).global_position
	var beamed := p.flashlight_on() and Game.flash_charge > 3.0 and dist < BEAM_RANGE \
		and p.is_looking_at(chest, BEAM_DEG) and p.has_line_of_sight(chest)
	if beamed:
		_beam_t += delta
		Game.flash_charge = maxf(Game.flash_charge - BEAM_DRAIN * delta, 0.0)
		_creature.position += Vector3(randf_range(-0.01, 0.01), 0.0, randf_range(-0.01, 0.01))  # дрожит
		var rig := _creature as CreatureRig
		if rig != null and rig.has_clip(&"freeze"):
			rig.pose_override = &"freeze"     # застыл на полушаге, голова набок к свету — дрожат только пальцы
		var shield: bool = bool(Game.hunter_brain.call(&"should_shield_eyes")) if Game.hunter_brain != null else false
		var dodge: bool = bool(Game.hunter_brain.call(&"should_dodge_beam")) if Game.hunter_brain != null else false
		if shield and rig != null:
			rig.set_rest(&"ArmL", Vector3(deg_to_rad(-85.0), deg_to_rad(35.0), deg_to_rad(45.0)))
		if dodge and p.camera != null:
			var side := -p.camera.global_basis.x
			_creature.global_position += side * (sin(Time.get_ticks_msec() * 0.007) * 2.2 * delta)
		var threshold := BEAM_TIME * (1.8 if shield else 1.0)
		if _beam_t >= threshold:
			_end_chase("repelled")
		return
	_beam_t = maxf(_beam_t - delta * 0.5, 0.0)
	# Издалека — на четырёх, низко над снегом; вблизи — рывок; между — сгорбленный бег
	var crig := _creature as CreatureRig
	if crig != null:
		if crig.pose_override == &"freeze":
			crig.pose_override = &""
		if crig.has_clip(&"crawl"):
			crig.clip_run = &"crawl" if dist > 10.0 else (&"dash" if dist < 5.0 and crig.has_clip(&"dash") else &"run")

	var top := CHASE_SPEED * (0.85 if Game.is_story() else 1.12 if Game.is_hard() else 1.0)
	var speed := lerpf(2.2, top, clampf(_chase_t / 2.5, 0.0, 1.0))

	# Если дежурный замер — Ырка настораживается и притормаживает шаг, прислушиваясь к темноте
	var p_spd := p.velocity.length()
	if p_spd < 0.25 and dist > 3.0:
		speed *= 0.45

	var goal := _route(c, p.global_position) if inside_ok else p.global_position
	var step := goal - c
	step.y = 0.0
	var sl := step.length()
	if sl > 0.01:
		_creature.global_position += step / sl * minf(speed * delta, sl)
		if not inside_ok or not _in_house(_creature.global_position):
			_creature.global_position.y = Terrain.height(_creature.global_position.x, _creature.global_position.z)
	_face_player(_creature)
	_update_flashlight_eyeshine()
	if dist < CATCH_DIST:
		_catch()


func _end_chase(how: String) -> void:
	if how == "repelled":
		if Game.hunter_brain != null:
			Game.hunter_brain.call(&"record_light_repel")
		Game.audio.play_3d(SHRIEK, _creature.global_position + Vector3(0, 1.3, 0), 4.0, 8.0)
		threat = 20.0
		_cooldown = 45.0
		Director.add_tension(-20.0, "Ырка отступил от света")
	else:
		threat = 25.0
		_cooldown = 40.0
	if _run_player != null and _run_player.playing:
		_run_player.stop()
	if _creature != null and is_instance_valid(_creature):
		var rig := _creature as CreatureRig
		if rig != null:
			rig.set_eye_glow(0.0)
			rig.clip_run = &"run"
			if rig.pose_override == &"freeze":
				rig.pose_override = &""
		_creature.visible = false
		_creature.position = Vector3(0, -100, 0)
		_creature.set_process(false)
	# Отбрасываем виртуального агента далеко в глубь леса
	if Game.player != null:
		var p_xz := Vector2(Game.player.global_position.x, Game.player.global_position.z)
		virtual_pos = p_xz + (virtual_pos - p_xz).normalized() * 65.0
	stage = Stage.CALM
	_whistled = true
	_glimpse_cd = 16.0
	_pull_timer = 0.0
	_still_close_t = 0.0


func _catch() -> void:
	# Если у дежурного ещё есть тепло и силы, первый удар Ырки ранит и даёт шанс добежать до двери
	if not _struck_this_night and Game.warmth > 35.0:
		_struck_this_night = true
		Game.audio.play_2d("res://assets/audio/gore_hit.ogg", 3.0)
		Game.audio.play_2d("res://assets/audio/shriek.ogg", 1.0)
		Game.player.shake(0.06, 0.6)
		Game.warmth = maxf(Game.warmth - 35.0, 15.0)
		Game.add_fatigue(25.0)
		Director.add_tension(35.0, "удар Ырки")
		Game.hud.subtitle(Loc.t(&"sub.yrka_slash"), 3.5)
		var push := (Game.player.global_position - _creature.global_position).normalized()
		push.y = 0.0
		Game.player.velocity += push * 10.0
		_end_chase("repelled")
		_cooldown = 22.0
		return

	stage = Stage.CALM
	enabled = false
	if _run_player != null:
		_run_player.stop()
	Game.audio.play_2d(SCREAM, 0.0)
	Game.clock_running = false
	var at_home := Game.is_home()
	await Game.player.death_fall(_creature)
	Game.die(&"yrka_house" if at_home else &"yrka")


func _in_house(pos: Vector3) -> bool:
	if Game.level is Station:
		return (Game.level as Station).is_pos_inside_house(pos)
	return pos.x > -2.2 and pos.x < 14.4 and pos.z > -5.6 and pos.z < 6.9


## Путь по дому — через дверные проёмы, а не сквозь стены.
## Граф комнат: улица — тамбур — коридор — {жилая, рубка — кладовая}.
const _HOUSE_LINKS := {
	&"yard": [[&"vestibule", Vector3(14.5, 0, 3.1), Vector3(-1, 0, 0)]],
	&"vestibule": [[&"yard", Vector3(14.5, 0, 3.1), Vector3(1, 0, 0)], [&"corridor", Vector3(11.5, 0, 3.15), Vector3(-1, 0, 0)]],
	&"corridor": [[&"vestibule", Vector3(11.5, 0, 3.15), Vector3(1, 0, 0)], [&"room", Vector3(3.5, 0, 3.15), Vector3(-1, 0, 0)],
		[&"radio_room", Vector3(7.55, 0, 2.2), Vector3(0, 0, -1)]],
	&"room": [[&"corridor", Vector3(3.5, 0, 3.15), Vector3(1, 0, 0)]],
	&"radio_room": [[&"corridor", Vector3(7.55, 0, 2.2), Vector3(0, 0, 1)], [&"storage", Vector3(5.3, 0, -2.0), Vector3(0, 0, -1)]],
	&"storage": [[&"radio_room", Vector3(5.3, 0, -2.0), Vector3(0, 0, 1)]],
}


func _house_zone(pos: Vector3) -> StringName:
	if not _in_house(pos):
		return &"yard"
	var z: StringName = Game.level.zone_at(pos) if Game.level.has_method(&"zone_at") else &"room"
	return z if _HOUSE_LINKS.has(z) else &"room"


func _route(c: Vector3, target: Vector3) -> Vector3:
	var cz := _house_zone(c)
	var tz := _house_zone(target)
	if cz == tz:
		return target
	# BFS по графу комнат: первая дверь на пути.
	var prev := {cz: &""}
	var queue: Array[StringName] = [cz]
	while not queue.is_empty():
		var z: StringName = queue.pop_front()
		if z == tz:
			break
		for link: Array in _HOUSE_LINKS.get(z, []):
			if not prev.has(link[0]):
				prev[link[0]] = z
				queue.append(link[0])
	if not prev.has(tz):
		return target
	var step_z := tz
	while prev[step_z] != cz:
		step_z = prev[step_z]
	for link: Array in _HOUSE_LINKS[cz]:
		if link[0] == step_z:
			var door: Vector3 = link[1]
			var n: Vector3 = link[2]          # из текущей комнаты — в следующую
			var approach := door - n * 0.7
			var lateral := (c - door) - n * (c - door).dot(n)
			# Сначала встать напротив проёма, потом — шагнуть сквозь него.
			if lateral.length() > 0.25 and (c - door).dot(n) < -0.3:
				return approach
			return door + n * 0.9
	return target


# --- Хелперы -----------------------------------------------------------------

## Точка на земле: angle_deg — от направления взгляда (0 — впереди, 180 — сзади), dist — метры.
func _point_around(angle_deg: float, dist: float) -> Vector3:
	var fwd := -Game.player.camera.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized().rotated(Vector3.UP, deg_to_rad(angle_deg))
	var pos := Game.player.global_position + fwd * dist
	pos.y = Terrain.height(pos.x, pos.z)   # на сопках — на склоне, а не под снегом
	return pos


func _face_player(n: Node3D) -> void:
	var target := Game.player.global_position
	target.y = n.global_position.y
	if target.distance_squared_to(n.global_position) > 0.01:
		n.look_at(target, Vector3.UP)
