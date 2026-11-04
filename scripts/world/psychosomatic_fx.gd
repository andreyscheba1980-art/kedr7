class_name PsychosomaticFX
extends Node
## PsychosomaticFX — Модуль психосоматических искажений восприятия (Deep Phobia Engine).
## Реализует тонкий, глубокий психологический хоррор на основе динамического вектора страхов игрока:
##   1. Клаустрофобия: динамическое сжатие FOV (туннельное зрение), акустический вакуум с усилением
##      собственного сердцебиения, удушающий расход выносливости (+35%), залипание дверного засова.
##   2. Агорафобия: сгущение белой мглы, инфразвуковой рокот (дрон) под открытым небом, кошмарное
##      замедление шага в глубокой целине, фланговые шорохи в 40 метрах на краю метели.
##   3. Фонофобия: асинхронный 6-й шаг за спиной с сокращенным порогом, слуховая парейдолия
##      (шёпоты ветра на грани слуха), акустический шок при резких ударах.
##   4. Скотофобия: периферийные силуэты в углах зрения, растворяющиеся при прямом взгляде,
##      древесные отблески глаз в кронах тайги, паранойя темноты.

const CLANK_SOUND := "res://assets/audio/clank.ogg"
const SNOW_CRUNCH := "res://assets/audio/step_snow_3.ogg"   # snow_crunch.ogg в игре нет — звук был немой
const WHISPER_SOUND := "res://assets/audio/whisper.ogg"

var _active_shadow: Node3D = null
var _shadow_lifetime: float = 0.0
var _shadow_timer: float = 35.0

var _active_eyeshine: Node3D = null
var _eyeshine_lifetime: float = 0.0
var _eyeshine_timer: float = 40.0

var _agora_step_timer: float = 35.0
var _whisper_timer: float = 45.0

var _claustro_subtitle_shown: bool = false
var _agora_subtitle_shown: bool = false


func _ready() -> void:
	Game.psychosomatic = self


func _process(delta: float) -> void:
	if Game.dead or Game.dying or Game.player == null or not is_inside_tree():
		_cleanup_all()
		return

	var profiler: PlayerProfiler = Game.profiler as PlayerProfiler
	if profiler == null:
		_reset_player_modifiers(delta)
		return

	var p := Game.player

	# =========================================================================
	# 1. КЛАУСТРОФОБИЯ: Сжатие пространства и удушье
	# =========================================================================
	if profiler.spatial_axis < -0.15 and Game.is_confined_space():
		var claustro_k := clampf(-profiler.spatial_axis, 0.0, 1.0) * clampf(Director.tension / 45.0 + 0.45, 0.45, 1.0)
		# Динамическое туннельное зрение: FOV сжимается на -10..-13 градусов
		# Сужение обзора и лишний расход сил убраны: игрок принимал их за лаги и баги, а не за страх.
		# Тесноту передаёт звук — сердце громче мира.
		_reset_player_modifiers(delta)

		# Акустический вакуум: внутреннее сердцебиение громче внешнего мира
		if Game.audio != null and is_instance_valid(Game.audio._heart):
			var heart_target_db := lerpf(-22.0, -8.0, claustro_k)
			Game.audio._heart.volume_db = maxf(Game.audio._heart.volume_db, heart_target_db)

		# Редкий нарративный намёк на спазм дыхания
		if claustro_k > 0.65 and not _claustro_subtitle_shown and Game.hud != null and randf() < delta * 0.04:
			_claustro_subtitle_shown = true
			Game.hud.subtitle(Loc.t(&"sub.phobia_claustro"), 3.5)
	else:
		p.fov_offset = lerpf(p.fov_offset, 0.0, minf(delta * 3.5, 1.0))
		p.stamina_drain_mult = lerpf(p.stamina_drain_mult, 1.0, minf(delta * 3.5, 1.0))
		if not Game.is_confined_space():
			_claustro_subtitle_shown = false

	# =========================================================================
	# 2. АГОРАФОБИЯ: Ужас открытой белой бездны тайги
	# =========================================================================
	if profiler.spatial_axis > 0.15 and Game.is_outside() and Game.is_night():
		var dist_station := (p.global_position - Station.SPAWN).length()
		if dist_station > 32.0:
			var agora_k := clampf(profiler.spatial_axis, 0.0, 1.0) * clampf((dist_station - 32.0) / 35.0, 0.0, 1.0)

			# Инфразвуковой низкий рокот (дрон) в голове под открытым небом
			if Game.audio != null and is_instance_valid(Game.audio._drone):
				var drone_db := lerpf(-80.0, -26.0, agora_k)
				Game.audio._drone.volume_db = maxf(Game.audio._drone.volume_db, drone_db)

			# Кошмарный вязкий снег (nightmare snow drag): легкое замедление шага
			p.speed_mult = lerpf(p.speed_mult, 1.0, minf(delta * 3.5, 1.0))   # скрытое замедление убрано: в поле игрок и так спешит к сроку сводки

			# Фланговые шаги в 35-45 метрах на краю бурана
			_agora_step_timer -= delta
			if _agora_step_timer <= 0.0:
				_agora_step_timer = randf_range(30.0, 60.0)
				_trigger_flanking_snow_step(p)

			if agora_k > 0.65 and not _agora_subtitle_shown and Game.hud != null and randf() < delta * 0.03:
				_agora_subtitle_shown = true
				Game.hud.subtitle(Loc.t(&"sub.phobia_agora"), 4.0)
		else:
			p.speed_mult = lerpf(p.speed_mult, 1.0, minf(delta * 3.5, 1.0))
	else:
		p.speed_mult = lerpf(p.speed_mult, 1.0, minf(delta * 3.5, 1.0))
		if not Game.is_outside():
			_agora_subtitle_shown = false

	# =========================================================================
	# 3. ФОНОФОБИЯ: Слуховая парейдолия и обострённый слух
	# =========================================================================
	if profiler.sensory_axis < -0.15:
		var phono_k := clampf(-profiler.sensory_axis, 0.0, 1.0)
		_whisper_timer -= delta
		if _whisper_timer <= 0.0:
			_whisper_timer = randf_range(40.0, 80.0)
			if Game.is_outside() and Game.is_night() and Director.tension > 18.0:
				_trigger_whisper_pareidolia(p, phono_k)

	# =========================================================================
	# 4. СКОТОФОБИЯ: Периферийные тени и отблески глаз в кронах
	# =========================================================================
	if profiler.sensory_axis > 0.15 and Game.is_night():
		var scoto_k := clampf(profiler.sensory_axis, 0.0, 1.0)

		# Периферийные тени (боковое зрение)
		_shadow_timer -= delta
		if _shadow_timer <= 0.0 and _active_shadow == null and Game.is_dark():
			_shadow_timer = randf_range(40.0, 80.0)
			_try_spawn_peripheral_shadow(p, scoto_k)

		# Отблески глаз в кронах елей
		_eyeshine_timer -= delta
		if _eyeshine_timer <= 0.0 and _active_eyeshine == null and Game.is_outside():
			_eyeshine_timer = randf_range(35.0, 70.0)
			_try_spawn_canopy_eyeshine(p)

	# Обновление активных визуальных иллюзий
	if _active_shadow != null and is_instance_valid(_active_shadow):
		_process_peripheral_shadow(delta, p)
	if _active_eyeshine != null and is_instance_valid(_active_eyeshine):
		_process_canopy_eyeshine(delta, p)


func _reset_player_modifiers(delta: float) -> void:
	if Game.player != null:
		Game.player.fov_offset = lerpf(Game.player.fov_offset, 0.0, minf(delta * 4.0, 1.0))
		Game.player.stamina_drain_mult = lerpf(Game.player.stamina_drain_mult, 1.0, minf(delta * 4.0, 1.0))
		Game.player.speed_mult = lerpf(Game.player.speed_mult, 1.0, minf(delta * 4.0, 1.0))


func _cleanup_all() -> void:
	if _active_shadow != null and is_instance_valid(_active_shadow):
		_active_shadow.queue_free()
		_active_shadow = null
	if _active_eyeshine != null and is_instance_valid(_active_eyeshine):
		_active_eyeshine.queue_free()
		_active_eyeshine = null


# --- Интерфейс для внешних систем --------------------------------------------

## Запрос от Player: порог шагов на снегу для фонофобии (чем выше фобия, тем чаще 6-й шаг)
func get_extra_step_threshold() -> float:
	var profiler: PlayerProfiler = Game.profiler as PlayerProfiler
	if profiler == null or profiler.sensory_axis >= -0.15:
		return 2.2
	var phono_k := clampf(-profiler.sensory_axis, 0.0, 1.0)
	return lerpf(2.2, 0.85, phono_k)


## Запрос от Player: параметры задержки и дистанции 6-го шага
func get_delayed_step_params() -> Vector2:
	var profiler: PlayerProfiler = Game.profiler as PlayerProfiler
	if profiler == null or profiler.sensory_axis >= -0.15:
		return Vector2(0.42, 2.2)
	var phono_k := clampf(-profiler.sensory_axis, 0.0, 1.0)
	var delay := lerpf(0.42, 0.34, phono_k)
	var dist := lerpf(2.2, 1.35, phono_k)
	return Vector2(delay, dist)


## Запрос от Station: должен ли засов двери заклинить на долю секунды
func should_door_hesitate() -> bool:
	var profiler: PlayerProfiler = Game.profiler as PlayerProfiler
	if profiler == null or not Game.is_night():
		return false
	# Клаустрофобы или игроки с паранойей потери контроля сталкиваются с сопротивлением засова
	var trigger_k := maxf(profiler.autonomy_axis, -profiler.spatial_axis)
	if trigger_k > 0.35 and Director.tension > 15.0:
		return randf() < 0.15   # раз из семи-восьми: иначе засов казался сломанным
	return false


# --- Реализация галлюцинаций и иллюзий -----------------------------------------

func _trigger_flanking_snow_step(p: Player) -> void:
	var side_sign := 1.0 if randf() < 0.5 else -1.0
	var flank := p.global_transform.basis.x * side_sign * randf_range(30.0, 42.0)
	var forward := p.global_transform.basis.z * randf_range(-12.0, 12.0)
	var snd_pos := p.global_position + flank + forward + Vector3(0, 0.2, 0)
	if not Director.request_ambient(5.0, "шаги на периферии метели"):
		return
	Game.audio.play_3d(SNOW_CRUNCH, snd_pos, -3.0, 12.0)


func _trigger_whisper_pareidolia(p: Player, intensity: float) -> void:
	var side_dir := p.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0) * randf_range(6.0, 12.0)
	var pos := p.global_position + side_dir + p.global_transform.basis.z * randf_range(4.0, 10.0) + Vector3(0, 1.5, 0)
	if not Director.request_ambient(6.0, "шёпот ветра"):
		return
	var vol := lerpf(-22.0, -14.0, intensity)
	var wp := Game.audio.play_3d(WHISPER_SOUND, pos, vol, 8.0)
	if wp != null:
		wp.pitch_scale = randf_range(0.88, 1.06)


func _try_spawn_peripheral_shadow(p: Player, _intensity: float) -> void:
	if Game.level == null:
		return

	# Выбираем точку в периферийном угле зрения (50° .. 70° сбоку)
	var angle_deg := randf_range(52.0, 72.0) * (1.0 if randf() < 0.5 else -1.0)
	var forward := -p.camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var spawn_dir := forward.rotated(Vector3.UP, deg_to_rad(angle_deg))
	var dist := randf_range(4.5, 8.0)
	var target_pos := p.global_position + spawn_dir * dist

	# Проверка прямой видимости из головы
	var q := PhysicsRayQueryParameters3D.create(p.head.global_position, target_pos + Vector3(0, 1.5, 0), Geo.LAYER_WORLD, [p.get_rid()])
	var space := p.get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return
	# Место свободно на весь рост (раньше силуэт мог встать в шкаф или нары)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = cap
	sq.transform = Transform3D(Basis(), target_pos + Vector3(0, 0.95, 0))
	sq.collision_mask = Geo.LAYER_WORLD | Geo.LAYER_INTERACT
	if not space.intersect_shape(sq, 1).is_empty():
		return
	if not Director.request_ambient(7.0, "силуэт на периферии"):
		return

	var fig := Creatures.make_silhouette()
	if fig == null:
		return

	Game.level.add_child(fig)
	fig.global_position = target_pos
	var look_target := p.global_position
	look_target.y = target_pos.y
	fig.look_at(look_target, Vector3.UP)

	_active_shadow = fig
	_shadow_lifetime = 5.0


func _process_peripheral_shadow(delta: float, p: Player) -> void:
	_shadow_lifetime -= delta
	var head_pos := _active_shadow.global_position + Vector3(0, 1.6, 0)

	# Если игрок повернулся и посмотрел прямо на силуэт — тень мгновенно рассеивается!
	if p.is_looking_at(head_pos, 32.0) or _shadow_lifetime <= 0.0:
		if p.is_looking_at(head_pos, 32.0):
			Game.audio.play_3d("res://assets/sfx/cc0/branch_snow_drop_1.ogg", head_pos, -16.0, 5.0)
		_active_shadow.queue_free()
		_active_shadow = null


func _try_spawn_canopy_eyeshine(p: Player) -> void:
	if Game.level == null:
		return

	# Ищем направление в глубь тайги
	# Глаза — в 12–20 м, чуть в стороне от взгляда, светящиеся «катафоты» в пиксель-два
	# (шарики 2.5 см в 22–36 м при пиксельном рендере были невидимы)
	var fwd := -p.camera.global_transform.basis.z
	fwd.y = 0.0
	var dir := fwd.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-35.0, 35.0)))
	var dist := randf_range(12.0, 20.0)
	var height := randf_range(3.0, 5.0)
	var eye_center := p.global_position + dir * dist + Vector3(0, height, 0)
	if not Director.request_ambient(8.0, "блеск глаз в кроне елей"):
		return

	var node := Node3D.new()
	node.name = "CanopyEyeshine"

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	for side in [-1, 1]:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.09, 0.06)
		mi.mesh = qm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(side * 0.11, 0, 0)
		node.add_child(mi)

	Game.level.add_child(node)
	node.global_position = eye_center
	var p_eye := p.head.global_position
	node.look_at(p_eye, Vector3.UP)

	_active_eyeshine = node
	_eyeshine_lifetime = 7.0


func _process_canopy_eyeshine(delta: float, p: Player) -> void:
	_eyeshine_lifetime -= delta
	var eye_pos := _active_eyeshine.global_position

	# Если фонарь включен и направлен прямо на глаза в кроне — существо моргает и растворяется в ветвях
	var direct_look := p.is_looking_at(eye_pos, 16.0) and p.flashlight_on()
	if direct_look or _eyeshine_lifetime <= 0.0:
		_active_eyeshine.queue_free()
		_active_eyeshine = null
