class_name PlayerProfiler
extends Node
## Профилировщик игрока (Deep Phobia Engine):
## Анализирует скрытые поведенческие и психосоматические биометрики дежурного в реальном времени.
## Вычисляет 4-осевой вектор страхов Φ:
##   spatial_axis: -1.0 (Клаустрофобия) .. +1.0 (Агорафобия)
##   sensory_axis: -1.0 (Фонофобия / Акустическая) .. +1.0 (Скотофобия / Зрительная)
##   autonomy_axis: 0.0 .. 1.0 (Паранойя потери контроля: заклинившие замки, механизмы)
##   isolation_axis: 0.0 .. 1.0 (Ужас изоляции: зависимость от рации, компаньона)
## А также определяет доминирующий психотип (Затворник, Паникёр, Хладнокровный) для HunterBrain.

enum Archetype {
	BALANCED,   ## сбалансированный стиль
	TURTLER,    ## затворник: боится выходить из дома/КУНГа, закрывается на засов
	PANICKER,   ## паникёр: часто бегает без угрозы, резко крутит камерой, жжёт фонарь
	EXPLORER    ## хладнокровный: уверенно исследует дальние объекты тайги, экономит свет
}

var current_archetype: Archetype = Archetype.BALANCED
var panic_score: float = 0.0          ## 0.0 .. 100.0 (индекс паники)
var shelter_bias: float = 0.5         ## 0.0 (только тайга) .. 1.0 (только в укрытии)
var sprint_ratio: float = 0.0         ## доля бега от общего времени ходьбы

# 4-осевой непрерывный вектор фобий Φ
var spatial_axis: float = 0.0         ## -1.0 (Клаустрофобия) .. +1.0 (Агорафобия)
var sensory_axis: float = 0.0         ## -1.0 (Фонофобия) .. +1.0 (Скотофобия)
var autonomy_axis: float = 0.0        ## 0.0 .. 1.0 (Паранойя заклинивших замков / поломок)
var isolation_axis: float = 0.0       ## 0.0 .. 1.0 (Ужас изоляции / зависимость от эфира)

# Накопители общего времени
var _time_inside: float = 0.0
var _time_outside: float = 0.0
var _time_walking: float = 0.0
var _time_sprinting_calm: float = 0.0
var _camera_jerk_acc: float = 0.0
var _flashlight_toggles: int = 0
var _last_cam_rot: Vector3 = Vector3.ZERO
var _profiling_timer: float = 2.0

# Биометрические накопители фобий
var _was_confined: bool = false
var _confined_entry_time: float = 0.0
var _confined_rush_exits: int = 0
var _confined_dwell_total: float = 0.0

var _time_deep_taiga: float = 0.0
var _time_wall_hug: float = 0.0
var _agora_flee_events: int = 0
var _last_tension: float = 0.0

var _listen_stops: int = 0
var _freeze_reactions: int = 0
var _crank_obsessions: int = 0
var _dark_saccades: float = 0.0
var _time_in_dark: float = 0.0

var _door_interactions: int = 0
var _night_outside: float = 0.0      ## эта ночь: сколько был снаружи (выходы за показаниями)
var _noise_t: float = 0.0            ## окно реакции на шум: 0.6 с после звука
var _noise_speed: float = 0.0        ## скорость в момент звука
var _radio_dwell_time: float = 0.0
var _dog_carrying_time: float = 0.0


func _ready() -> void:
	Game.profiler = self
	_load_persistent_metrics()
	EventBus.noise_emitted.connect(_on_noise_emitted)
	EventBus.door_opened.connect(_on_door_opened)


func _load_persistent_metrics() -> void:
	var saved_arch := int(SaveGame.flags.get("profiler_arch", Archetype.BALANCED))
	current_archetype = clampi(saved_arch, 0, Archetype.EXPLORER) as Archetype
	if current_archetype == Archetype.TURTLER:
		current_archetype = Archetype.BALANCED   # «затворник» — только по этой ночи, не по прошлой
	panic_score = float(SaveGame.flags.get("profiler_panic", 0.0))
	shelter_bias = float(SaveGame.flags.get("profiler_shelter", 0.5))

	var phobia_dict: Variant = SaveGame.flags.get("phobia_profile", null)
	if phobia_dict is Dictionary:
		spatial_axis = clampf(float(phobia_dict.get("spatial", 0.0)), -1.0, 1.0)
		sensory_axis = clampf(float(phobia_dict.get("sensory", 0.0)), -1.0, 1.0)
		autonomy_axis = clampf(float(phobia_dict.get("autonomy", 0.0)), 0.0, 1.0)
		isolation_axis = clampf(float(phobia_dict.get("isolation", 0.0)), 0.0, 1.0)


func _on_noise_emitted(_pos: Vector3, _vol: float, _type: StringName) -> void:
	# Акустический рефлекс: шёл — и в ближайшие 0.6 с после звука замер (проверка в _process)
	if Game.player != null:
		_noise_t = 0.6
		_noise_speed = Game.player._prev_velocity_len


func _on_door_opened() -> void:
	_door_interactions += 1


func record_flashlight_toggle() -> void:
	_flashlight_toggles += 1
	panic_score = minf(panic_score + 1.2, 100.0)


func _process(delta: float) -> void:
	if Game.dead or Game.dying or Game.shift_over or Game.player == null:
		return

	var p := Game.player
	var inside := Game.is_home() or Game.is_indoors()
	var now_time := _time_inside + _time_outside

	if inside:
		_time_inside += delta
	else:
		_time_outside += delta
		if Game.is_night():
			_night_outside += delta

	# Замер бега вне открытой погони (признак неоправданной паники)
	var is_chasing := Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE
	var current_spd := Vector2(p.velocity.x, p.velocity.z).length()

	if p.is_sprinting():
		_time_walking += delta
		# Паника — бег, когда страшно, а угрозы нет. Бег к корпусу за показаниями к сроку сводки — не паника.
		if not is_chasing and not inside and Director.tension > 35.0:
			_time_sprinting_calm += delta
	elif current_spd > 0.5:
		_time_walking += delta

	# 1. Биометрика Клаустрофобии: тесные замкнутые помещения
	var is_confined := Game.is_confined_space()
	if is_confined:
		_confined_dwell_total += delta
		if not _was_confined:
			_was_confined = true
			_confined_entry_time = now_time
	else:
		if _was_confined:
			_was_confined = false
			var dwell := now_time - _confined_entry_time
			# Стремительный побег из тесноты (вбежал и через 1-7 секунд выбежал спринтом)
			if dwell < 7.5 and p.is_sprinting():
				_confined_rush_exits += 1

	# 2. Биометрика Агорафобии: открытая дальняя тайга vs прижимание к стенам
	if not inside:
		var dist_station := (p.global_position - Station.SPAWN).length()
		if dist_station > 35.0:
			_time_deep_taiga += delta
		elif dist_station < 12.0:
			_time_wall_hug += delta

		# Паническое бегство к стенам станции при росте напряжения
		if Director.tension > _last_tension + 5.0 and dist_station > 18.0 and p.is_sprinting():
			var to_station := (Station.SPAWN - p.global_position).normalized()
			var move_dir := Vector3(p.velocity.x, 0.0, p.velocity.z).normalized()
			if move_dir.dot(to_station) > 0.5:
				_agora_flee_events += 1
	_last_tension = Director.tension

	if _noise_t > 0.0:
		_noise_t -= delta
		if _noise_speed > 1.2 and current_spd < 0.3:
			_freeze_reactions += 1
			_noise_t = 0.0

	# 3. Биометрика Фонофобии: замирание на месте при шорохах (Audio Freeze Reflex)
	if p._prev_velocity_len > 1.8 and current_spd < 0.2:
		if Director.tension > 22.0 or is_confined:
			_listen_stops += 1

	# 4. Биометрика Скотофобии: судорожный завод фонаря и саккады в темноте
	if p.cranking and Game.flash_charge > 82.0:
		_crank_obsessions += 1

	if Game.is_dark():
		_time_in_dark += delta

	# Замер резкости вращения камеры (панический осмотр вокруг)
	if p.camera != null:
		var cam_rot := p.camera.global_rotation
		if _last_cam_rot != Vector3.ZERO:
			var dyaw := absf(wrapf(cam_rot.y - _last_cam_rot.y, -PI, PI))
			var dpitch := absf(cam_rot.x - _last_cam_rot.x)
			var ang_spd := (dyaw + dpitch) / maxf(delta, 0.001)
			if ang_spd > 8.5:
				_camera_jerk_acc += (ang_spd - 8.5) * delta * 0.4
			if Game.is_dark() and ang_spd > 5.5:
				_dark_saccades += delta * 0.5
		_last_cam_rot = cam_rot

	# 5. Биометрика Изоляции: привязка к рации и собаке
	if Game.zone == &"radio_room" and (p.global_position - Vector3(5.5, 0.0, 1.0)).length() < 3.2:
		_radio_dwell_time += delta
	if p.held == &"dog":
		_dog_carrying_time += delta

	# Остывание паники со временем
	_camera_jerk_acc = maxf(_camera_jerk_acc - delta * 0.15, 0.0)

	_profiling_timer -= delta
	if _profiling_timer <= 0.0:
		_profiling_timer = 4.0
		_recalculate_archetype()


func _recalculate_archetype() -> void:
	var total_time := _time_inside + _time_outside
	if total_time > 15.0:
		shelter_bias = _time_inside / total_time
	if _time_walking > 5.0:
		sprint_ratio = _time_sprinting_calm / _time_walking

	# Расчет индекса паники (0..100)
	var sprint_panic := sprint_ratio * 40.0
	var jerk_panic := minf(_camera_jerk_acc * 3.5, 40.0)
	var toggle_panic := minf(float(_flashlight_toggles) * 2.0, 20.0)
	panic_score = clampf(sprint_panic + jerk_panic + toggle_panic, 0.0, 100.0)

	# В прологе и в 1-ю ночь игрок знакомится со станцией и механикой (исследует сруб, фотолабораторию).
	# Преждевременное профилирование принимало любопытство за агорафобию/клаустрофобию.
	# Настоящий 4-осевой профиль страхов активируется со 2-й ночи, когда проявляется Сущность.
	if Game.is_prologue() or Game.night < 2:
		current_archetype = Archetype.BALANCED
		spatial_axis = 0.0
		sensory_axis = 0.0
		autonomy_axis = 0.0
		isolation_axis = 0.0
		return

	# Определение доминирующего психотипа
	# Затворник — не «много сидит дома» (ночь так и устроена: рация, печь), а пропустил сводку
	# и за ночь почти не выходил. Иначе осада включалась почти у каждого игрока.
	if Game.is_night() and Game.reports_missed() > 0 and _night_outside < 40.0:
		current_archetype = Archetype.TURTLER
	elif panic_score > 38.0:
		current_archetype = Archetype.PANICKER
	elif total_time > 60.0 and _time_outside > 40.0 and panic_score < 25.0:
		current_archetype = Archetype.EXPLORER
	else:
		current_archetype = Archetype.BALANCED

	# Расчет 4-осевого вектора страхов Φ
	# Ось пространства: -1.0 Клаустрофобия .. +1.0 Агорафобия
	var claustro_tendency := float(_confined_rush_exits) * 0.35 + (0.25 if _confined_dwell_total < 8.0 and _time_inside > 40.0 else 0.0)
	var agora_tendency := (_time_wall_hug / maxf(_time_outside, 1.0)) * 0.75 + float(_agora_flee_events) * 0.3 - (_time_deep_taiga / maxf(_time_outside, 1.0)) * 0.5
	spatial_axis = clampf(agora_tendency - claustro_tendency, -1.0, 1.0)

	# Ось чувств: -1.0 Фонофобия (звук) .. +1.0 Скотофобия (тьма/тени)
	var phono_tendency := float(_listen_stops) * 0.18 + float(_freeze_reactions) * 0.32
	var scoto_tendency := minf(float(_crank_obsessions) * 0.04, 0.5) + minf(_dark_saccades * 0.12, 0.5) + (float(_flashlight_toggles) * 0.04)
	sensory_axis = clampf(scoto_tendency - phono_tendency, -1.0, 1.0)

	# Ось контроля/замков (0.0 .. 1.0)
	autonomy_axis = clampf(float(_door_interactions) * 0.06, 0.0, 1.0)

	# Ось изоляции (0.0 .. 1.0)
	isolation_axis = clampf((_radio_dwell_time + _dog_carrying_time * 1.6) / maxf(total_time * 0.35, 1.0), 0.0, 1.0)

	# Сохраняем в состояние игры
	SaveGame.flags["profiler_arch"] = int(current_archetype)
	SaveGame.flags["profiler_panic"] = panic_score
	SaveGame.flags["profiler_shelter"] = shelter_bias
	SaveGame.flags["phobia_profile"] = {
		"spatial": spatial_axis,
		"sensory": sensory_axis,
		"autonomy": autonomy_axis,
		"isolation": isolation_axis
	}


func get_dominant_phobia() -> StringName:
	var abs_sp := absf(spatial_axis)
	var abs_se := absf(sensory_axis)
	if maxf(abs_sp, abs_se) < 0.22:
		return &"balanced"
	if abs_sp >= abs_se:
		return &"claustrophobia" if spatial_axis < 0.0 else &"agoraphobia"
	return &"phonophobia" if sensory_axis < 0.0 else &"scotophobia"


func archetype_name() -> String:
	match current_archetype:
		Archetype.TURTLER:
			return "Затворник"
		Archetype.PANICKER:
			return "Паникёр"
		Archetype.EXPLORER:
			return "Хладнокровный"
		_:
			return "Сбалансированный"
