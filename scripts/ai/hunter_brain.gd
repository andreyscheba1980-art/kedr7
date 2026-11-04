class_name HunterBrain
extends Node
## Адаптивный мозг хищника (Ырки):
## Выбирает глобальную стратегию охоты на основе профиля игрока (Осада, Истощение, Засада),
## запоминает приёмы дежурного (свет фонаря, ракеты) и руководит диверсиями на станции.

enum Tactic {
	STALK,      ## стандартная охота по леерам и следам
	SIEGE,      ## осада дома: саботаж генератора, удары по ставням, скрежет в окна
	ATTRITION,  ## игра на истощение: ложные шорохи, выжидание разрядки батареи
	AMBUSH      ## тихая засада: бесшумный подкрад без свиста, засада у выходов POI
}

const PlayerProfilerClass = preload("res://scripts/ai/player_profiler.gd")
const CLANK_SOUND := "res://assets/audio/clank_v2.ogg"
const KNOCK_SOUND := "res://assets/audio/knock_v2.ogg"
const ICE_SOUND := "res://assets/audio/ice_hit.ogg"
const SNOW_CRUNCH := "res://assets/audio/snow_crunch.ogg"

var current_tactic: Tactic = Tactic.STALK
var light_adaptation: int = 0         ## 0: слепнет; 1: закрывает лицо лапой; 2+: уклоняется зигзагом
var flare_repel_count: int = 0        ## сколько раз за эту ночь прогнали ракетой
var generator_sabotaged: bool = false
var siege_window_timer: float = 40.0
var sabotage_timer: float = 75.0
var phantom_sound_timer: float = 25.0
var ambush_poi_staged: bool = false


func _ready() -> void:
	Game.hunter_brain = self
	_load_memory()


func _load_memory() -> void:
	light_adaptation = int(SaveGame.flags.get("hunter_light_adapt", 0))
	flare_repel_count = 0
	generator_sabotaged = false


func _process(delta: float) -> void:
	if not Game.is_night() or Game.dead or Game.dying or Game.shift_over:
		return
	if Game.yrka == null or not Game.yrka.enabled:
		return

	_update_tactic()

	match current_tactic:
		Tactic.SIEGE:
			_process_siege(delta)
		Tactic.ATTRITION:
			_process_attrition(delta)
		Tactic.AMBUSH:
			_process_ambush(delta)
		Tactic.STALK:
			pass


func _update_tactic() -> void:
	if Game.profiler == null:
		return

	match Game.profiler.current_archetype:
		PlayerProfilerClass.Archetype.TURTLER:
			current_tactic = Tactic.SIEGE
		PlayerProfilerClass.Archetype.PANICKER:
			current_tactic = Tactic.ATTRITION
		PlayerProfilerClass.Archetype.EXPLORER:
			current_tactic = Tactic.AMBUSH
		_:
			current_tactic = Tactic.STALK


# --- Стратегия: Осада станции (против Затворника) ---------------------------

func _process_siege(delta: float) -> void:
	# Саботаж генератора, если игрок сидит в доме в тепле и со светом
	if not generator_sabotaged and Game.is_home() and Game.power_on and not Game.gen_broken:
		sabotage_timer -= delta
		if sabotage_timer <= 0.0:
			sabotage_timer = 120.0
			_sabotage_generator()

	# Стуки и скрежет по окнам дома
	if Game.is_home():
		siege_window_timer -= delta
		if siege_window_timer <= 0.0:
			siege_window_timer = Game.rng.randf_range(40.0, 75.0)
			_harass_window()


func _sabotage_generator() -> void:
	if Game.level == null or not Game.power_on:
		return
	generator_sabotaged = true
	SaveGame.flags["had_night_siege"] = true

	# Звук удара по железу в будке дизеля
	var gen_pos := Vector3(14.2, 0.45, -13.65)
	Game.audio.play_3d(CLANK_SOUND, gen_pos, 4.0, 14.0)

	if Game.level.has_method(&"_trigger_generator_stall"):
		Game.level.call(&"_trigger_generator_stall")
	else:
		Game.set_power(false)

	Director.add_tension(25.0, "диверсия на генераторе")
	Game.hud.subtitle(Loc.t(&"sub.gen_sabotaged"), 5.0, 2)


func _harass_window() -> void:
	if Game.level == null or Game.level.window_spots.is_empty():
		return
	var spot: Dictionary = Game.level.window_spots[Game.rng.randi() % Game.level.window_spots.size()]
	var glass_pos: Vector3 = spot.get("glass", Vector3(14.0, 1.2, 3.5))

	# Звук когтей по стеклу / удара по раме
	Game.audio.play_3d(KNOCK_SOUND, glass_pos, 3.0, 9.0)
	Game.audio.play_3d(ICE_SOUND, glass_pos + Vector3(0, 0.1, 0), 1.5, 7.0)
	if Game.player != null:
		Game.player.shake(0.02, 0.3)
	Director.add_tension(15.0, "скрежет в окно")
	Game.hud.subtitle(Loc.t(&"sub.window_claw"), 3.5)
	SaveGame.flags["had_night_siege"] = true


# --- Стратегия: Игра на истощение (против Паникёра) --------------------------

func _process_attrition(delta: float) -> void:
	phantom_sound_timer -= delta
	if phantom_sound_timer <= 0.0:
		phantom_sound_timer = Game.rng.randf_range(20.0, 45.0)
		_play_phantom_sound()

	# Если паникёр на улице выдохся или почти посадил фонарь — хищник форсирует атаку
	if Game.is_outside() and Game.player != null and Game.yrka != null:
		var low_battery := Game.flash_charge < 18.0
		var exhausted := Game.player.stamina < 15.0
		if (low_battery or exhausted) and Game.yrka.threat < YrkaThreat.PRESSURE_AT:
			Game.yrka.threat = minf(Game.yrka.threat + delta * 3.5, YrkaThreat.CHASE_AT - 2.0)


func _play_phantom_sound() -> void:
	if Game.player == null or not Game.is_outside():
		return
	var p_pos := Game.player.global_position
	var angle := Game.rng.randf_range(0.0, TAU)
	var dist := Game.rng.randf_range(16.0, 28.0)
	var snd_pos := p_pos + Vector3(cos(angle) * dist, 0.2, sin(angle) * dist)
	Game.audio.play_3d(SNOW_CRUNCH, snd_pos, 2.0, 8.0)
	Director.add_tension(6.0, "ложный шорох")


# --- Стратегия: Бесшумная засада (против Хладнокровного) ---------------------

func _process_ambush(_delta: float) -> void:
	if Game.player == null or Game.yrka == null:
		return

	# Проверяем, находится ли исследователь на дальнем объекте
	var is_at_poi := Game.zone in [&"mine", &"kung", &"dome", &"sg4", &"bunker", &"izba"]
	if is_at_poi and not ambush_poi_staged:
		ambush_poi_staged = true
		_stage_poi_ambush()


func _stage_poi_ambush() -> void:
	if Game.player == null or Game.yrka == null:
		return
	var p_pos := Game.player.global_position
	# Перемещаем виртуального агента ко входу в локацию
	Game.yrka.virtual_pos = Vector2(p_pos.x, p_pos.z) + Vector2(Game.rng.randf_range(-15.0, 15.0), Game.rng.randf_range(-15.0, 15.0))
	Game.yrka.threat = maxf(Game.yrka.threat, YrkaThreat.STALK_AT)
	Director.add_tension(15.0, "засада у выхода")


# --- Обучение и реакция на приёмы дежурного -----------------------------------

func record_light_repel() -> void:
	light_adaptation = clampi(light_adaptation + 1, 0, 3)
	SaveGame.flags["hunter_light_adapt"] = light_adaptation


func record_flare_fired(_flare_pos: Vector3) -> void:
	flare_repel_count += 1
	# Во второй раз за ночь тварь отступает гораздо ближе
	if flare_repel_count >= 2 and Game.yrka != null and Game.player != null:
		var p_xz := Vector2(Game.player.global_position.x, Game.player.global_position.z)
		# Засада на полпути к дому (координаты станции около (6.0, 3.5))
		var home_xz := Vector2(6.0, 3.5)
		var mid := (p_xz + home_xz) * 0.5
		Game.yrka.virtual_pos = mid + Vector2(Game.rng.randf_range(-8.0, 8.0), Game.rng.randf_range(-8.0, 8.0))
		Game.yrka._cooldown = 35.0  # вместо 90 секунд


func should_shield_eyes() -> bool:
	return light_adaptation >= 1


func should_dodge_beam() -> bool:
	return light_adaptation >= 2
