class_name HunterBrain
extends Node
## Адаптивный мозг хищника (Ырки):
## выбирает тактику по профилю игрока (Осада, Истощение, Засада), запоминает приёмы дежурного
## (свет фонаря, ракеты) и устраивает диверсии на станции.
## Все события идут через бюджет Режиссёра: мелкие — Director.request_ambient, крупные — Director.take_peak.
## Иначе ночь висела на пике, а пугает как раз контраст тишины и удара.

enum Tactic {
	STALK,      ## стандартная охота по леерам и следам
	SIEGE,      ## осада дома: диверсия на генераторе, скрежет в окна
	ATTRITION,  ## игра на истощение: ложные шорохи, выжидание разрядки батареи
	AMBUSH      ## тихая засада у выхода с дальней точки
}

const PlayerProfilerClass = preload("res://scripts/ai/player_profiler.gd")
const CLANK_SOUND := "res://assets/audio/clank_v2.ogg"
const KNOCK_SOUND := "res://assets/audio/knock_v2.ogg"
const ICE_SOUND := "res://assets/audio/ice_hit.ogg"
const SNOW_CRUNCH := "res://assets/audio/step_snow_3.ogg"   # snow_crunch.ogg в игре нет — звук был немой
const GEN_POS := Vector3(14.2, 0.45, -13.65)
const HOME_XZ := Vector2(6.0, 3.5)
const SABOTAGE_WARN := 25.0        ## сколько секунд слышно возню у ДЭС, прежде чем сорвут ремень
const AMBUSH_SILENT := 70.0        ## сколько молчит засада (без свиста) — дальше снова как обычно

var current_tactic: Tactic = Tactic.STALK
var light_adaptation: int = 0      ## за эту ночь: 0 — слепнет; 1 — закрывает лицо лапой; 2+ — уходит из луча
var flare_repel_count: int = 0     ## сколько раз за эту ночь прогнали ракетой
var generator_sabotaged: bool = false   ## раз за ночь: сорвали или спугнули
var _warn_t := -1.0                ## идёт предупреждение у ДЭС
var _ambush_done: Dictionary = {}  ## точка → уже была засада этой ночью
var _silent_t := 0.0
var _check_t := 2.0
var _route_cells: Array[String] = []    ## клетки привычных троп этой ночи — там тварь ждёт
var _route_used: Dictionary = {}
var _step_t := 2.0


func _ready() -> void:
	Game.hunter_brain = self
	# Привыкание к свету — только в пределах ночи: игра учит «свет отгоняет», и с новой ночью
	# правило снова работает. Кампанию тварь не «запоминает» молча.
	light_adaptation = 0
	flare_repel_count = 0
	generator_sabotaged = false
	if Game.is_night() and not Game.is_prologue():
		_route_cells = Consequences.ambush_cells()


func _process(delta: float) -> void:
	_silent_t = maxf(_silent_t - delta, 0.0)
	if not Game.is_night() or Game.dead or Game.dying or Game.shift_over:
		return
	if Game.yrka == null or not Game.yrka.enabled:
		return
	if _warn_t >= 0.0:
		_tick_sabotage_warning(delta)
	_track_routes(delta)
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 1.0
	_update_tactic()
	match current_tactic:
		Tactic.SIEGE:
			_process_siege()
		Tactic.ATTRITION:
			_process_attrition()
		Tactic.AMBUSH:
			_process_ambush()
	_check_far_point_ambush()


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


## Засада молчит (без предупреждающего свиста) только пока она идёт, не всю ночь.
## Тварь учит привычные тропы: каждые 2 с на улице — шаг в «теплокарту»; на привычной клетке —
## засада (раз за ночь на клетку), если напряжение уже набрано. Утром там круги следов.
func _track_routes(delta: float) -> void:
	if Game.player == null or not Game.is_outside():
		return
	if Game.weather != null and Game.weather.blizzard:
		SaveGame.flags["night_storm"] = true
	_step_t -= delta
	if _step_t > 0.0:
		return
	_step_t = 2.0
	var pp := Game.player.global_position
	Consequences.record_step(pp)
	var cell := Consequences.cell_of(pp)
	if cell in _route_cells and not _route_used.has(cell) and Director.tension > 25.0 and Game.yrka.stage < YrkaThreat.Stage.CONTACT:
		_route_used[cell] = true
		var fwd := Vector2(Game.player.velocity.x, Game.player.velocity.z)
		if fwd.length() < 0.3:
			fwd = Vector2(-Game.player.global_basis.z.x, -Game.player.global_basis.z.z)
		Game.yrka.virtual_pos = Vector2(pp.x, pp.z) + fwd.normalized() * 18.0
		Game.yrka.threat = maxf(Game.yrka.threat, YrkaThreat.STALK_AT)
		_silent_t = 40.0
		Consequences.note_waited(Consequences.cell_center(cell))
		Director.add_tension(6.0, "ждала на привычной тропе")


func is_silent_now() -> bool:
	return _silent_t > 0.0


# --- Осада (против Затворника: пропустил сводку и не выходит) -------------------

func _process_siege() -> void:
	if not Game.is_home():
		return
	# Скрежет в окно — мелкая пугалка, через бюджет
	if Game.level != null and not Game.level.window_spots.is_empty() and Game.rng.randf() < 0.08:
		if Director.request_ambient(8.0, "скрежет в окно"):
			_harass_window()


## Режиссёр на пике спрашивает: возьмёт ли охотник этот момент. Диверсия на генераторе — раз за ночь,
## со 2-й ночи, затворнику дома; сначала 25 с слышно возню у ДЭС — успеешь выйти, спугнёшь.
func offer_peak() -> bool:
	if current_tactic != Tactic.SIEGE or generator_sabotaged or _warn_t >= 0.0 or Game.night < 2:
		return false
	if not Game.is_home() or not Game.power_on or Game.gen_broken:
		return false
	if not Director.take_peak("возня у ДЭС", 20.0, SABOTAGE_WARN + 50.0):
		return false
	_warn_t = SABOTAGE_WARN
	Game.audio.play_3d(SNOW_CRUNCH, GEN_POS + Vector3(-1.5, 0, 1.2), 2.0, 16.0)
	Game.audio.play_3d(CLANK_SOUND, GEN_POS, -2.0, 16.0)
	Game.hud.subtitle(Loc.t(&"sub.gen_shack_steps"), 4.5, 2)
	return true


func _tick_sabotage_warning(delta: float) -> void:
	_warn_t -= delta
	# Вышел во двор, пока возятся у ДЭС, — спугнул: шаги уходят в лес, ремень цел
	if Game.is_outside():
		_warn_t = -1.0
		generator_sabotaged = true
		Game.audio.play_3d(SNOW_CRUNCH, GEN_POS + Vector3(-6.0, 0, -4.0), 0.0, 20.0)
		Game.hud.subtitle(Loc.t(&"sub.gen_shack_fled"), 4.0)
		Director.add_tension(-15.0, "спугнул у ДЭС")
		return
	if _warn_t > 0.0:
		if fmod(_warn_t, 6.0) < 1.0 and Game.rng.randf() < 0.3:
			Game.audio.play_3d(KNOCK_SOUND, GEN_POS, -6.0, 14.0)
		return
	_warn_t = -1.0
	_sabotage_generator()


func _sabotage_generator() -> void:
	if Game.level == null or not Game.power_on:
		return
	generator_sabotaged = true
	SaveGame.flags["had_night_siege"] = true
	Game.audio.play_3d(CLANK_SOUND, GEN_POS, 4.0, 14.0)
	if Game.level.has_method(&"_trigger_generator_stall"):
		Game.level.call(&"_trigger_generator_stall")
	else:
		Game.set_power(false)
	SaveGame.flags["gen_sabotaged_night"] = true
	Director.add_tension(12.0, "диверсия на генераторе")
	Game.hud.subtitle(Loc.t(&"sub.gen_sabotaged"), 5.0, 2)


func _harass_window() -> void:
	var spot: Dictionary = Game.level.window_spots[Game.rng.randi() % Game.level.window_spots.size()]
	var glass_pos: Vector3 = spot.get("glass", Vector3(14.0, 1.2, 3.5))
	Game.audio.play_3d(KNOCK_SOUND, glass_pos, 3.0, 9.0)
	Game.audio.play_3d(ICE_SOUND, glass_pos + Vector3(0, 0.1, 0), 1.5, 7.0)
	if Game.player != null:
		Game.player.shake(0.02, 0.3)
	Game.hud.subtitle(Loc.t(&"sub.window_claw"), 3.5)
	SaveGame.flags["had_night_siege"] = true


# --- Истощение (против Паникёра) ------------------------------------------------

func _process_attrition() -> void:
	if Game.player == null or not Game.is_outside():
		return
	if Game.rng.randf() < 0.1 and Director.request_ambient(5.0, "ложный шорох"):
		var a := Game.rng.randf_range(0.0, TAU)
		var d := Game.rng.randf_range(16.0, 28.0)
		Game.audio.play_3d(SNOW_CRUNCH, Game.player.global_position + Vector3(cos(a) * d, 0.2, sin(a) * d), 2.0, 8.0)
	# Выдохся или почти посадил фонарь на улице — тварь подбирается ближе (но не сразу в погоню)
	var low_battery := Game.flash_charge < 18.0
	var exhausted := Game.player.stamina < 15.0
	if (low_battery or exhausted) and Game.yrka.threat < YrkaThreat.PRESSURE_AT:
		Game.yrka.threat = minf(Game.yrka.threat + 3.5, YrkaThreat.PRESSURE_AT)


# --- Засада у выхода с дальней точки (против Хладнокровного) -------------------

func _process_ambush() -> void:
	pass   # сама засада — в _check_far_point_ambush: для исследователя она злее и тише


func _far_points() -> Dictionary:
	var pts := {}
	for k: StringName in DayPOIs.POI_TARGETS:
		var e: Dictionary = DayPOIs.POI_TARGETS[k]
		pts[k] = [e["pos"], float(e["radius"]) + 6.0]
	for site: StringName in [&"tower", &"camp", &"drill"]:
		pts[site] = [Terrain.pad_pos(site), 18.0]
	return pts


func _check_far_point_ambush() -> void:
	if Game.player == null or Game.yrka == null or not Game.is_outside() and not Game.is_indoors():
		return
	var pp := Game.player.global_position
	var pts := _far_points()
	for k: StringName in pts:
		if _ambush_done.has(k):
			continue
		var c: Vector3 = pts[k][0]
		if Vector2(pp.x - c.x, pp.z - c.z).length() > float(pts[k][1]):
			continue
		_ambush_done[k] = true
		# Засада для исследователя — всегда; для остальных — реже
		if current_tactic != Tactic.AMBUSH and Game.rng.randf() > 0.35:
			return
		# Тварь встаёт на обратном пути: между точкой и станцией, в 25–30 м от точки
		var to_home := (HOME_XZ - Vector2(c.x, c.z)).normalized()
		Game.yrka.virtual_pos = Vector2(c.x, c.z) + to_home * Game.rng.randf_range(25.0, 30.0)
		Game.yrka.threat = maxf(Game.yrka.threat, YrkaThreat.STALK_AT)
		if current_tactic == Tactic.AMBUSH:
			_silent_t = AMBUSH_SILENT
		Director.add_tension(6.0, "засада на обратном пути")
		return


# --- Обучение и реакция на приёмы дежурного -----------------------------------

func record_light_repel() -> void:
	light_adaptation = clampi(light_adaptation + 1, 0, 3)
	if light_adaptation == 1:
		Game.hud.subtitle(Loc.t(&"sub.yrka_shields"), 4.5)
	elif light_adaptation == 2:
		Game.hud.subtitle(Loc.t(&"sub.yrka_dodges"), 4.5)


func record_flare_fired(_flare_pos: Vector3) -> void:
	flare_repel_count += 1
	# Во второй раз за ночь тварь отступает недалеко и ждёт на полпути к дому
	if flare_repel_count >= 2 and Game.yrka != null and Game.player != null:
		var p_xz := Vector2(Game.player.global_position.x, Game.player.global_position.z)
		var mid := (p_xz + HOME_XZ) * 0.5
		Game.yrka.virtual_pos = mid + Vector2(Game.rng.randf_range(-8.0, 8.0), Game.rng.randf_range(-8.0, 8.0))
		Game.yrka.set_cooldown(35.0)


func should_shield_eyes() -> bool:
	return light_adaptation >= 1


func should_dodge_beam() -> bool:
	return light_adaptation >= 2
