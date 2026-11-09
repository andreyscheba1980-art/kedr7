class_name CausalMimicry
extends Node
## Система каузальной акустической мимикрии Сущности.
## В отличие от случайных скримеров, Сущность вслушивается в действия дежурного
## и с задержкой в 2.5-6 секунд повторяет физические звуки станции
## (дверь, дрова, радио, шаги за спиной на снегу), порождая глубинную паранойю слежки.

var _door_mimic_t := -1.0
var _wood_mimic_t := -1.0
var _radio_mimic_t := -1.0
var _footstep_cooldown := 25.0
var _moving_snow_time := 0.0


func _ready() -> void:
	EventBus.door_opened.connect(_on_door_action)
	EventBus.door_closed.connect(_on_door_action)
	EventBus.stove_fed.connect(_on_stove_action)
	EventBus.radio_transmitted.connect(_on_radio_action)


func _on_door_action() -> void:
	if not Game.is_night() or Game.night < 2 or Director.tension < 30.0:
		return
	if _door_mimic_t < 0.0 and randf() < 0.65:
		_door_mimic_t = randf_range(3.2, 5.8)


func _on_stove_action() -> void:
	if not Game.is_night() or Game.night < 2 or Director.tension < 32.0:
		return
	if _wood_mimic_t < 0.0 and randf() < 0.60:
		_wood_mimic_t = randf_range(3.8, 6.5)


func _on_radio_action(_f: float) -> void:
	if not Game.is_night() or Game.night < 3 or Director.tension < 35.0:
		return
	if _radio_mimic_t < 0.0 and randf() < 0.70:
		_radio_mimic_t = randf_range(2.0, 4.0)


func _process(delta: float) -> void:
	if Game.player == null or not Game.is_night():
		return

	# 1. Отголосок хлопка двери в глубине двора / у сараев
	if _door_mimic_t > 0.0:
		_door_mimic_t -= delta
		if _door_mimic_t <= 0.0:
			_door_mimic_t = -1.0
			_play_door_mimic()

	# 2. Отголосок стука поленьев с чердака или подпола
	if _wood_mimic_t > 0.0:
		_wood_mimic_t -= delta
		if _wood_mimic_t <= 0.0:
			_wood_mimic_t = -1.0
			_play_wood_mimic()

	# 3. Эхо передачи / искаженный вздох в динамике рации
	if _radio_mimic_t > 0.0:
		_radio_mimic_t -= delta
		if _radio_mimic_t <= 0.0:
			_radio_mimic_t = -1.0
			_play_radio_mimic()

	# 4. Запоздалые шаги за спиной на снегу (звуковая мимикрия шагов)
	_tick_footstep_mimicry(delta)


func _play_door_mimic() -> void:
	var yard_door_pos := Vector3(14.0, 1.2, -18.0) # дизельная будка или сарай
	Game.audio.play_3d("res://assets/audio/door.ogg", yard_door_pos, -14.0, 18.0)
	Director.add_tension(4.0, "каузальное эхо двери")
	if randf() < 0.45 and Game.hud != null and Game.is_outside():
		Game.hud.subtitle(Loc.t(&"sub.mimicry_door"), 4.0)


func _play_wood_mimic() -> void:
	var attic_pos := Vector3(0.0, 3.5, 2.0)
	Game.audio.play_3d("res://assets/audio/clank.ogg", attic_pos, -12.0, 12.0)
	Director.add_tension(5.0, "каузальное эхо дров на чердаке")


func _play_radio_mimic() -> void:
	if Game.radio != null:
		Game.audio.play_2d("res://assets/audio/whisper.ogg", -15.0)
		Director.add_tension(6.0, "радио-мимикрия в эфире")


func _tick_footstep_mimicry(delta: float) -> void:
	_footstep_cooldown = maxf(_footstep_cooldown - delta, 0.0)
	if not Game.is_outside() or Director.tension < 48.0 or _footstep_cooldown > 0.0:
		_moving_snow_time = 0.0
		return

	var p := Game.player
	var cur_vel := Vector2(p.velocity.x, p.velocity.z).length()
	if cur_vel > 1.2:
		_moving_snow_time += delta
	elif _moving_snow_time > 3.5 and cur_vel < 0.2:
		# Игрок только что резко остановился после долгой ходьбы в метели
		_moving_snow_time = 0.0
		_footstep_cooldown = randf_range(45.0, 90.0)
		_trigger_delayed_steps(p.global_position, p.transform.basis)


func _trigger_delayed_steps(pl_pos: Vector3, pl_basis: Basis) -> void:
	var behind_pos := pl_pos - pl_basis.z * 3.4
	behind_pos.y = Terrain.height(behind_pos.x, behind_pos.z) + 0.1
	await get_tree().create_timer(0.45, false).timeout
	Game.audio.play_3d("res://assets/audio/step_snow_4.ogg", behind_pos, -2.0, 10.0)
	Director.add_tension(6.0, "чужой шаг за спиной")
	if randf() < 0.4 and Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.mimicry_footsteps"), 3.5)
