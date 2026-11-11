extends Node
## Глобальное состояние текущей фазы (ночь или день): часы, хозяйство станции, выживание, задачи,
## контекст игрока и ссылки на ключевые узлы. Долгосрочное (предметы, кассеты, флаги) живёт в SaveGame.

const NIGHT_BASE_HOUR := 20
const DAY_BASE_HOUR := 14
const PROLOGUE_BASE_HOUR := 21
const NIGHT_END_MIN := 600.0                ## 06:00
const READING_KEYS: Array[StringName] = [&"temp", &"wind", &"snow", &"baro"]
const FUEL_DRAIN_PER_SEC := 100.0 / 1500.0  ## ~25 мин на баке при полной нагрузке
const STOVE_BURN_PER_SEC := 100.0 / 1200.0  ## ~20 мин горения (с поддувалом до 50 мин)
const WOOD_PER_ARMFUL := 50.0
## Жар кладки: пока горит, печь копит тепло, прогорела — отдаёт ~10 мин
## (вдвое дольше при закрытой вьюшке). Дом после прогорания остывает плавно.
const HEAT_CHARGE_PER_SEC := 100.0 / 150.0
const HEAT_DECAY_PER_SEC := 100.0 / 600.0
const DAMPER_BURN_K := 0.4             ## прикрытое поддувало: дрова тлеют в 2.5 раза дольше
const DAMPER_WARM_K := 0.6             ## …и греют слабее
const IDLE_FUEL_K := 0.35              ## рубильник выключен: дизель на холостом
const WARMTH_LOSS_OUTSIDE := 0.6
const WARMTH_GAIN_STOVE := 3.0
const TUTORIAL_STEPS: Array[StringName] = [&"driver", &"readings", &"test_report", &"refuel", &"wood", &"buran", &"journal"]

const Synoptic = preload("res://scripts/data/synoptic.gd")

var phase_kind := &"night"          ## &"night" | &"day"
var phase_index := 1
var cfg: Dictionary = {}
var base_hour := NIGHT_BASE_HOUR
var minute_rate := 0.45
## До последней сводки ночные часы идут медленнее: площадка и корпус в ~100 м, на две вылазки за
## 22:00–02:00 при обычном темпе не хватало (до 00:00 было ~4.5 мин). Хозяйство (дизель, печь)
## тратится по тем же часам — на игровой час расход прежний.
const REPORT_CLOCK_K := 0.6

var night: int = 1
var shift_minutes := 0.0
var clock_running := false
var shift_over := false
var dead := false
var dying := false               ## идёт сцена смерти — повторно не запускать
var run_seed: int = 0
var forced_seed: int = 0
var coop_ghost := false             ## кооп: мы погибли, но остаёмся в эфире — часы ночи идут дальше
var coop_report_ok := false         ## кооп: бланк сводки с цифрами напарника заполнен верно — можно передавать
var house_cold := 0.0              ## 0 — дом натоплен, 1 — выстыл (иней на окнах, пар изо рта в комнате)           ## кооп: зерно ночи от хоста (0 — своё случайное)
var rng := RandomNumberGenerator.new()

var player: Player
var level: Station
var yard: Yard
var hud: Hud
var audio: AudioDirector
var radio: Radio
var weather: Weather
var yrka: YrkaThreat
var events: NightEvents
var tasks: NightTasks
var forest_voice: ForestVoice
var anomalies: Anomalies
var zenit: Zenit
var aftermath: Node
var profiler: Node
var hunter_brain: Node
var psychosomatic: Node

var zone: StringName = &"room"
var activity: StringName = &"idle"

var generator_fuel := 70.0
var power_on := true
var canisters_left := 3
var stove_wood := 60.0
var stove_heat := 0.0                   ## жар кладки, 0..100
var stove_damper := false               ## поддувало прикрыто
var stove_flue := false                 ## вьюшка закрыта (с огнём — угар; без огня — жар держится дольше)
var house_switch_off := false           ## рубильник у двери: свет в доме погашен, дизель на холостом
var pzs35_on := false                   ## прожектор ПЗС-35 на крыше (12 А)
var zaboy_unsealed := false             ## сорвана свинцовая пломба аварийного рубильника «Директива Забой»
var zaboy_active := false               ## контур «Забой» замкнут (ток ДГА-24 на заземление мачты)
var warmth := 100.0
var memory_goal := ""           ## цель во флешбэке Семёнова (смена уже кончилась — обычных целей нет)
var story_goal := ""            ## сюжетная цель (вылазка в шахту и т. п.) — поверх обычных
var flash_charge := 100.0
var fatigue := 0.0                  ## скрытая усталость: ложные звуки и галлюцинации
var synoptic: Synoptic
var readings: Dictionary = {}
## Книжка КМ-1: что дежурный сам вписал с прибора и что прибор показывал на самом деле в тот миг.
## {&"temp_dry": {"v": -27.4, "t": -27.2}, ...}. Сводка по рации сверяется по ней.
var notebook: Dictionary = {}
var reports_sent := 0
var antenna_iced := false
var ice_at_min := 0
var tutorial: Dictionary = {}       ## пролог: шаг → выполнен
var day_goal_done := false
var gen_broken := false             ## ночь 5: генератор сломался — нужны инструменты
var reports_silent := 0             ## сколько сводок прозвучало «молчанием» (опоздание > 45 мин)
var reports_closed := false         ## после 03:00 несданные сводки сорваны
var _silence_marked: Dictionary = {}
var flares := 0                     ## ракеты к ракетнице на эту ночь
var final_call := false             ## ночь 7: зов начался, выбор открыт
var resumed := false                ## ночь начата с чекпоинта (после сводки 00:00)
var _dusk_warned := false
var _evening_said := false
var chimney_iced := false
var fuel_sputter := false
var anemo_iced := false
var co_poisoning := 0.0
var tea_warmth_timer := 0.0
var mem_now: Dictionary = {}        ## что игрок натворил этой ночью (NightMemory)
var tea_cd := 0.0                   ## чай (чайник и подстаканник) — не чаще раза в полторы минуты
var finger_temp := 36.6              ## температура кожи пальцев (+36.6°C до +14.0°C)
var firm_hands_timer := 0.0          ## эффект «Твёрдая рука» (5 мин) после согревания о гранёный стакан
var tea_brick_chipped := false       ## отколот ли кусок прессованного грузинского плиточного чая №36
var tea_brewed := false              ## заварен ли чай кипятком в 14-гранном стакане с подстаканником
var padlock_shack_frozen := true     ## замёрз ли чугунный замок ЧЗ-1 у дизельной
var padlock_thaw_t := 0.0            ## таймер оттайки замка спичкой или кипятком (окно 6 с)
var barograph_wound := 100.0        ## завод барабана барографа М-22 (%)
var baro_tapped := false            ## постучали ли по корпусу М-22 (устранение застоя трения)
var balloon_launched := false       ## запущен ли шар-пилот
var balloons_left := 2              ## шаров на смену: баллон водорода не бесконечный
var balloon_task_done := false      ## завершено ли зондирование теодолитом
var safe_code_known: bool:
	get: return SaveGame.flags.get("safe_code_known", false)
	set(v):
		SaveGame.flags["safe_code_known"] = v
		SaveGame.write()
var safe_opened: bool:
	get: return SaveGame.flags.get("safe_opened", false)
	set(v):
		SaveGame.flags["safe_opened"] = v
		SaveGame.write()
var countersign_known: bool:
	get: return SaveGame.flags.get("countersign_known", false)
	set(v):
		SaveGame.flags["countersign_known"] = v
		SaveGame.write()
var skis_equipped := false          ## надеты ли охотничьи лыжи Семёнова (+40% скорость по снегу)
var leer_attached := false          ## защёлкнут ли карабин на натяжном леере (иммунитет к Белой Тьме)
var sv20_active := false            ## надеты ли наушники ТА-56М от геофона СВ-20 («Слухач»)
var paradox_photo_seen := false     ## проявлен ли снимок-парадокс в фотолаборатории
var sv20_rumble_player: AudioStreamPlayer

var salt_on_threshold: bool:
	get: return SaveGame.flags.get("salt_on_threshold", false)
	set(v):
		SaveGame.flags["salt_on_threshold"] = v
		SaveGame.write()
var knife_in_lintel: bool:
	get: return SaveGame.flags.get("knife_in_lintel", false)
	set(v):
		SaveGame.flags["knife_in_lintel"] = v
		SaveGame.write()
var mirror_covered: bool:
	get: return SaveGame.flags.get("mirror_covered", false)
	set(v):
		SaveGame.flags["mirror_covered"] = v
		SaveGame.write()
var spirit_treat: bool:
	get: return SaveGame.flags.get("spirit_treat", false)
	set(v):
		SaveGame.flags["spirit_treat"] = v
		SaveGame.write()
var helipad_cleared: bool:
	get: return SaveGame.flags.get("helipad_cleared", false)
	set(v):
		SaveGame.flags["helipad_cleared"] = v
		SaveGame.write()



func set_sv20(on: bool) -> void:
	sv20_active = on
	if on:
		readings[&"sv20"] = true
	if AudioServer.get_bus_effect_count(0) > 2:
		var lp := AudioServer.get_bus_effect(0, 2) as AudioEffectLowPassFilter
		if lp != null:
			lp.cutoff_hz = 220.0 if sv20_active else 20000.0
	if sv20_active:
		if sv20_rumble_player == null:
			sv20_rumble_player = AudioStreamPlayer.new()
			sv20_rumble_player.stream = AudioDirector.cached_stream("res://assets/audio/sub_drop.ogg")
			sv20_rumble_player.bus = &"SFX"
			sv20_rumble_player.volume_db = -8.0
			add_child(sv20_rumble_player)
		sv20_rumble_player.play()
	else:
		if sv20_rumble_player != null and sv20_rumble_player.playing:
			sv20_rumble_player.stop()


func get_seismic_status() -> Dictionary:
	var res := {
		"amplitude": 0.2,
		"vector": "calm",
		"text": Loc.t(&"sv20.calm"),
		"warning": false,
		"alert": false
	}
	# Сигнал 03:10: удар снизу, по которому снимают пеленг на источник.
	if Signal0310.ringing():
		res.amplitude = 9.6
		res.vector = "source"
		res.text = Loc.t(&"sv20.source", [Signal0310.bearing_deg()])
		res.warning = true
		res.alert = true
		return res
	# «Замечания дежурного»: Слухач слышит шаги по полу дома — а ты стоишь.
	if anomalies != null and anomalies.is_active(&"sv20_house"):
		res.amplitude = 3.1
		res.vector = "house"
		res.text = Loc.t(&"sv20.house")
		res.warning = true
		return res
	if (night == 4 or night == 5) and shift_minutes >= 120.0 and shift_minutes <= 240.0:
		res.amplitude = 5.4
		res.vector = "otzvuk"
		res.text = Loc.t(&"sv20.otzvuk")
		res.warning = true
		return res
	if yrka != null and is_instance_valid(yrka) and yrka.enabled:
		if yrka.stage == YrkaThreat.Stage.CHASE or yrka.threat >= 70.0:
			res.amplitude = 8.5
			res.vector = "underground"
			res.text = Loc.t(&"sv20.underground")
			res.alert = true
			res.warning = true
			return res
		elif yrka.threat >= 35.0:
			var to_yrka := yrka.virtual_pos - Vector2(8.0, 0.0)
			var dist := to_yrka.length()
			res.amplitude = clampf(lerpf(6.5, 1.8, dist / 80.0), 1.2, 6.8)
			var ang := rad_to_deg(atan2(to_yrka.x, -to_yrka.y))
			if ang < 0.0:
				ang += 360.0
			if ang >= 337.5 or ang < 22.5:
				res.vector = "north"
				res.text = Loc.t(&"sv20.north")
			elif ang >= 22.5 and ang < 67.5:
				res.vector = "northeast"
				res.text = Loc.p("СЕВЕРО-ВОСТОК · СИГНАЛ ПРИБЛИЖЕНИЯ", "NORTHEAST · APPROACH SIGNAL")
			elif ang >= 67.5 and ang < 112.5:
				res.vector = "east"
				res.text = Loc.p("ВОСТОК · СИГНАЛ ПРИБЛИЖЕНИЯ", "EAST · APPROACH SIGNAL")
			elif ang >= 112.5 and ang < 157.5:
				res.vector = "southeast"
				res.text = Loc.p("ЮГО-ВОСТОК · СИГНАЛ ПРИБЛИЖЕНИЯ", "SOUTHEAST · APPROACH SIGNAL")
			elif ang >= 157.5 and ang < 202.5:
				res.vector = "south"
				res.text = Loc.t(&"sv20.south")
			elif ang >= 202.5 and ang < 247.5:
				res.vector = "southwest"
				res.text = Loc.p("ЮГО-ЗАПАД · СИГНАЛ ПРИБЛИЖЕНИЯ", "SOUTHWEST · APPROACH SIGNAL")
			elif ang >= 247.5 and ang < 292.5:
				res.vector = "west"
				res.text = Loc.p("ЗАПАД · СИГНАЛ ПРИБЛИЖЕНИЯ", "WEST · APPROACH SIGNAL")
			else:
				res.vector = "northwest"
				res.text = Loc.t(&"sv20.northwest")
			res.warning = true
			return res
	if Director != null and Director.tension > 40.0:
		res.amplitude = lerpf(1.2, 4.0, Director.tension / 100.0)
		res.vector = "northwest"
		res.text = Loc.t(&"sv20.northwest")
		res.warning = Director.tension > 60.0
		return res
	return res


func _ready() -> void:
	_setup_input()
	_snapshot_pad_defaults()
	apply_keybinds()
	apply_padbinds()


## Подготовка фазы. Вызывается Session перед сборкой уровня.
func setup_phase(kind: StringName, index: int) -> void:
	phase_kind = kind
	phase_index = index
	skis_equipped = false
	leer_attached = false
	paradox_photo_seen = false
	set_sv20(false)

	run_seed = forced_seed if forced_seed != 0 else randi()   # в коопе оба игрока строят одну и ту же ночь
	rng.seed = run_seed
	synoptic = Synoptic.generate_for_phase(kind, index, run_seed)
	# Прогноз должен быть навыком, а не лотереей: днём приборы показывают предвестников фронта,
	# который придёт следующей ночью, — и ночью приходит именно он.
	if kind == &"day":
		SaveGame.flags["front_next"] = [index + 1, String(synoptic.front_type)]
	else:
		var fn: Variant = SaveGame.flags.get("front_next")
		if fn is Array and (fn as Array).size() == 2 and int(fn[0]) == index and String(fn[1]) != String(synoptic.front_type):
			synoptic = Synoptic.generate_for_phase(kind, index, run_seed, StringName(String(fn[1])))
	print("[Game] %s %d, seed = %d (фронт: %s, P=%.1f)" % [kind, index, run_seed, synoptic.front_type, synoptic.pressure])
	clock_running = false
	shift_over = false
	dead = false
	dying = false
	zone = &"room"
	activity = &"idle"
	readings.clear()
	notebook.clear()
	coop_report_ok = false
	reports_sent = 0
	reports_silent = 0
	reports_closed = false
	_silence_marked = {}
	antenna_iced = false
	warmth = 100.0
	flash_charge = 100.0
	power_on = true
	tutorial.clear()
	day_goal_done = false
	gen_broken = false
	final_call = false
	resumed = false
	_dusk_warned = false
	_evening_said = false
	chimney_iced = false
	fuel_sputter = false
	anemo_iced = false
	co_poisoning = 0.0
	barograph_wound = 100.0
	house_cold = 0.85 if is_prologue() else 0.0
	balloon_launched = false
	balloons_left = 1 if SaveGame.difficulty == "hard" else 2
	balloon_task_done = false
	tea_warmth_timer = 0.0
	finger_temp = 36.6
	firm_hands_timer = 0.0
	tea_brick_chipped = false
	tea_brewed = false
	padlock_shack_frozen = true
	padlock_thaw_t = 0.0
	flares = (4 if is_story() else 2 if SaveGame.difficulty == "hard" else 3) if SaveGame.items.has(&"flare_gun") else 0
	if kind == &"night":
		cfg = Phases.night(index)
		night = index
		base_hour = NIGHT_BASE_HOUR
		shift_minutes = float(cfg["start_min"])
		minute_rate = float(cfg["min_per_sec"])
		generator_fuel = float(cfg["gen_start"])
		stove_wood = float(cfg["stove_start"])
		_reset_stove_aux()
		canisters_left = int(cfg["canisters"]) + (1 if is_story() else -1 if is_hard() else 0)
		ice_at_min = rng.randi_range(290, 350) if bool(cfg["antenna_ice"]) else -1
		fatigue = float(SaveGame.flags.get("fatigue", 10.0))
		mem_now = {}
		SaveGame.flags["spirit_treat"] = false   # угощение домовому — на одну ночь: к утру блюдце пустое
		_apply_checkpoint(index)
		_apply_forecast_effects(index)
	else:
		cfg = Phases.day(index)
		night = index
		base_hour = PROLOGUE_BASE_HOUR if (is_prologue() and not has_flag("prologue_arrived")) else (8 if is_prologue() else DAY_BASE_HOUR)
		shift_minutes = 0.0 if (is_prologue() and not has_flag("prologue_arrived")) else (30.0 if is_prologue() else float(cfg["start_min"]))
		minute_rate = float(cfg["min_per_sec"])
		generator_fuel = 90.0
		stove_wood = 0.0 if (is_prologue() and not has_flag("prologue_arrived")) else 80.0
		_reset_stove_aux()
		canisters_left = 3
		ice_at_min = -1
		fatigue = 0.0


## Начало фазы: кладка прогрета по тому, сколько в печи, поддувало и вьюшка открыты, рубильник включён.
func _reset_stove_aux() -> void:
	stove_heat = clampf(stove_wood, 0.0, 100.0) * 0.8
	stove_damper = false
	stove_flue = false
	house_switch_off = false
	pzs35_on = false
	zaboy_unsealed = false
	zaboy_active = false


## Сколько печь сейчас греет дом: 1 — топится вовсю, дальше — по жару кладки.
func house_heat_k() -> float:
	if stove_wood > 0.0:
		return DAMPER_WARM_K if stove_damper else 1.0
	return stove_heat / 100.0


## Чекпоинт ночи: состояние сразу после сводки на 00:00. Смерть позже — рестарт отсюда.
func save_checkpoint() -> void:
	SaveGame.flags["cp"] = {
		"night": night, "minute": shift_minutes, "fuel": generator_fuel, "stove": stove_wood,
		"cans": canisters_left, "reports": reports_sent, "fatigue": fatigue, "flares": flares,
		"power": power_on, "warmth": maxf(warmth, 60.0), "gen_broken": gen_broken,
		"antenna": antenna_iced, "chimney": chimney_iced, "anemo": anemo_iced, "sputter": fuel_sputter,
		"ice_at": ice_at_min, "mem": mem_now.duplicate(),
	}
	SaveGame.write()


func _apply_checkpoint(index: int) -> void:
	var cp: Variant = SaveGame.flags.get("cp")
	if not cp is Dictionary or int((cp as Dictionary).get("night", -1)) != index:
		return
	var d: Dictionary = cp
	shift_minutes = float(d["minute"])
	generator_fuel = maxf(float(d["fuel"]), 25.0)
	stove_wood = maxf(float(d["stove"]), 30.0)
	_reset_stove_aux()
	canisters_left = int(d["cans"])
	reports_sent = int(d["reports"])
	fatigue = float(d["fatigue"])
	flares = int(d.get("flares", flares))
	warmth = float(d.get("warmth", 100.0))
	gen_broken = bool(d.get("gen_broken", false))
	power_on = bool(d.get("power", true)) and not gen_broken and generator_fuel > 0.0
	antenna_iced = bool(d.get("antenna", false))
	chimney_iced = bool(d.get("chimney", false))
	anemo_iced = bool(d.get("anemo", false))
	fuel_sputter = bool(d.get("sputter", false))
	ice_at_min = int(d.get("ice_at", ice_at_min))
	var mem: Variant = d.get("mem", {})
	mem_now = (mem as Dictionary).duplicate() if mem is Dictionary else {}
	resumed = true


func _apply_forecast_effects(index: int) -> void:
	var chosen: Variant = SaveGame.flags.get("forecast_choice")
	if chosen == null or not chosen is String:
		return
	# Только вчерашний прогноз: не подписал КН-01 днём — ни бонуса, ни штрафа от старой бумаги.
	if int(SaveGame.flags.get("forecast_day", -99)) != index - 1:
		return
	var actual := String(synoptic.front_type) if synoptic != null else "blizzard"
	if synoptic == null:
		if index == 3 or index == 5 or index == 6:
			actual = "storm"
		elif index == 4 or index == 7:
			actual = "fog"

	var is_correct: bool = (chosen == actual)
	if is_correct:
		stove_wood = minf(stove_wood + 20.0, 100.0)
		generator_fuel = minf(generator_fuel + 15.0, 100.0)
		if synoptic != null and synoptic.front_type == &"storm":
			chimney_iced = false
	else:
		if chosen == "fog" and actual == "storm":
			fuel_sputter = true
			chimney_iced = true
		elif actual == "anomaly":
			add_fatigue(6.0)

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 4.5
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		t.queue_free()
		if hud != null and not dead:
			hud.subtitle(Loc.t(&"forecast.correct") if is_correct else Loc.t(&"forecast.wrong"), 5.0)
	)


## Барограф пишет и предупреждает, только пока заведён и есть чернила.
func barograph_live() -> bool:
	return barograph_wound > 0.0


func is_night() -> bool:
	return phase_kind == &"night"


func is_day() -> bool:
	return phase_kind == &"day"


## Вечер — последние полчаса дня перед сумерками (с 17:00): подготовка станции к ночи.
func is_evening() -> bool:
	return is_day() and not is_prologue() and shift_minutes >= float(cfg.get("end_min", 210.0)) - 30.0


func forecast_filed() -> bool:
	return int(SaveGame.flags.get("forecast_day", -1)) == phase_index


## К ночи готовы: прогноз подписан и стоит хоть один оберег.
func evening_ready() -> bool:
	return forecast_filed() and Rituals.any_set()


func is_prologue() -> bool:
	return is_day() and phase_index == 0


func is_prologue_trail() -> bool:
	return is_prologue() and not has_flag("prologue_arrived")


## Истинный дневной свет на улице (днём, но НЕ во время ночной высадки в прологе).
func is_daylight() -> bool:
	return is_day() and not is_prologue_trail()


## Порядковый номер фазы: пролог 0, ночь 1 — 1, день 1 — 2, ночь 2 — 3, ... ночь 7 — 13.
func progress() -> int:
	return phase_index * 2 - 1 if is_night() else phase_index * 2


func is_story() -> bool:
	return SaveGame.difficulty == "story"



func is_hard() -> bool:
	return SaveGame.difficulty == "hard"


## Множитель для угроз (Ырка, холод): история — мягче, хард — жёстче.
func threat_mult() -> float:
	return 0.5 if is_story() else 1.3 if is_hard() else 1.0


func start_shift() -> void:
	clock_running = true


func _process(delta: float) -> void:
	if not clock_running or shift_over or (dead and not coop_ghost):
		return
	var prev_min := int(shift_minutes)
	var ck := clock_k()
	shift_minutes += delta * minute_rate * ck
	if dead:
		# Погибший в коопе только ждёт рассвета вместе с напарником: хозяйство и холод уже не его.
		if is_night() and shift_minutes >= NIGHT_END_MIN and cfg.get("finale", &"") == &"":
			end_shift()
		return
	if int(shift_minutes) != prev_min:
		EventBus.clock_minute.emit(int(shift_minutes))
		if ice_at_min > 0 and not antenna_iced and int(shift_minutes) == ice_at_min:
			set_antenna_iced(true)
	if is_night() and not is_prologue():
		_tick_reports()
		if not NightMemory.tonight(&"out_after3") and after_hour(3) and is_outside() and not final_call:
			NightMemory.mark(&"out_after3")
	_tick_generator(delta * ck)
	_tick_heat(delta * ck)
	_tick_fatigue(delta)
	if is_night() and shift_minutes >= NIGHT_END_MIN and cfg.get("finale", &"") == &"":
		end_shift()
	elif is_day():
		var end_m := float(cfg.get("end_min", 180.0))
		var dusk_m := float(cfg.get("dusk_end_min", 240.0))
		if end_m > 0.0:
			if not is_prologue() and shift_minutes >= end_m - 30.0 and not _evening_said:
				_evening_said = true
				if hud != null and not evening_ready():
					hud.subtitle(Loc.t(&"sub.evening"), 5.0)
			# Предупреждение о надвигающихся сумерках ближе к 17:00
			if shift_minutes >= end_m - 10.0 and not _dusk_warned:
				_dusk_warned = true
				if hud != null:
					hud.subtitle(Loc.t(&"sub.dusk_warning") if day_goal_done else Loc.t(&"sub.dusk_goal"), 5.0)

			if not day_goal_done and shift_minutes >= end_m - 0.5:
				# Если главное дело дня ещё не найдено, время замирает у порога темноты,
				# чтобы день ни в коем случае не оборвался внезапно без находки.
				shift_minutes = end_m - 0.5
			elif day_goal_done:
				# Дело сделано: игрок возвращается на станцию и ложится на кровать.
				# Если игрок вернулся в дом и наступили сумерки (>= dusk_m), он засыпает:
				if shift_minutes >= dusk_m:
					if is_home():
						end_shift()
					else:
						# Вне дома в темноте холод нарастает, давая время добежать до порога:
						warmth = maxf(warmth - delta * 1.6, 0.0)
						if warmth <= 0.0 and not dying:
							_freeze_to_death()


## Темп ночных часов: до времени последней сводки — медленнее (см. REPORT_CLOCK_K).
func clock_k() -> float:
	if not is_night() or is_prologue():
		return 1.0
	var times: Array = report_times()
	if times.is_empty() or shift_minutes >= float(times[times.size() - 1]):
		return 1.0
	return REPORT_CLOCK_K


# --- Хозяйство ---------------------------------------------------------------

func _tick_generator(delta: float) -> void:
	if not power_on:
		return
	var load_k := IDLE_FUEL_K if house_switch_off else 1.0   # свет в доме погашен — дизель на холостом
	generator_fuel = maxf(generator_fuel - FUEL_DRAIN_PER_SEC * (1.8 if fuel_sputter else 1.0) * load_k * delta, 0.0)   # густая солярка — дизель жрёт больше
	if generator_fuel <= 0.0:
		set_power(false)


func refuel() -> void:
	generator_fuel = 100.0
	if not gen_broken:
		set_power(true)
	complete_step(&"refuel")


func set_power(on: bool) -> void:
	if power_on == on:
		return
	power_on = on
	EventBus.power_changed.emit(on)


func add_wood() -> void:
	stove_wood = minf(stove_wood + WOOD_PER_ARMFUL, 100.0)
	complete_step(&"wood")
	EventBus.stove_fed.emit()


func set_antenna_iced(iced: bool) -> void:
	if antenna_iced == iced:
		return
	antenna_iced = iced
	EventBus.antenna_iced_changed.emit(iced)


func set_anemo_iced(iced: bool) -> void:
	if anemo_iced == iced:
		return
	anemo_iced = iced
	EventBus.anemo_iced_changed.emit(iced)


func set_chimney_iced(iced: bool) -> void:
	if chimney_iced == iced:
		return
	chimney_iced = iced
	EventBus.chimney_iced_changed.emit(iced)


func set_fuel_sputter(sputter: bool) -> void:
	if fuel_sputter == sputter:
		return
	fuel_sputter = sputter
	EventBus.fuel_sputter_changed.emit(sputter)


func take_reading(key: StringName) -> bool:
	if readings.get(key, false):
		return false
	readings[key] = true
	if has_readings():
		complete_step(&"readings")
	return true


func readings_count() -> int:
	var n := 0
	for k in READING_KEYS:
		if readings.get(k, false):
			n += 1
	return n


func has_readings() -> bool:
	return readings_count() == READING_KEYS.size()


func clear_readings() -> void:
	readings.clear()
	notebook.clear()
	baro_tapped = false


## Термометры в будке сейчас: x — сухой, y — смоченный. Ночь к утру выстывает (~0,3 °C в час),
## в метель воздух перемешан и чуть теплее.
func air_temp() -> Vector2:
	var dry := synoptic.temp_dry if synoptic != null else -28.0
	var wet := synoptic.temp_wet if synoptic != null else -30.0
	var drift := -0.3 * shift_minutes / 60.0 if is_night() else 0.0
	if weather != null:
		drift += weather.intensity * 0.8
	if is_night() and night >= 7:
		# Ночь барометрического дна: аномальное падение температуры до -48..-54°C
		drift -= 18.0 * clampf(shift_minutes / 360.0, 0.0, 1.0)
	return Vector2(dry + drift, wet + drift)


## Давление на ленте барографа, мм рт. ст.; h — часы от начала смены (отрицательные — лента до смены).
## Ход по тенденции фронта плюс медленная «волна» — у каждой фазы своя.
func pressure_at(h: float) -> float:
	var p0 := synoptic.pressure if synoptic != null else 746.0
	var rate := synoptic.pressure_rate if synoptic != null else -0.4
	var ph := float(phase_index) * 1.7
	var base_p := p0 + rate * h + sin(h * 0.9 + ph) * 0.6 + sin(h * 2.3 + ph * 2.0) * 0.25
	if is_night() and night >= 7:
		# Ночь барометрического дна: обвал давления ниже 700 мм рт. ст. к кульминации ночи
		var progress := clampf(h / 7.0, 0.0, 1.0)
		base_p = lerpf(738.0, 688.0, progress) + sin(h * 3.5) * 0.4
	return base_p


func write_reading(key: StringName, value: float, truth: float) -> void:
	notebook[key] = {"v": value, "t": truth}


## Допуски книжки: [до — принято, до — замечание], дальше — брак. Румб — в шагах по 22,5°.
const READ_TOL := {&"temp_dry": [0.5, 1.5], &"temp_wet": [0.5, 1.5], &"wind_speed": [1.5, 3.0],
	&"wind_gust": [2.5, 5.0], &"wind_dir": [1.0, 2.0], &"snow": [2.0, 5.0], &"baro": [0.8, 2.0], &"baro_tend": [0.6, 1.5]}
const READ_GROUP := {&"temp_dry": &"temp", &"temp_wet": &"temp", &"wind_speed": &"wind", &"wind_gust": &"wind",
	&"wind_dir": &"wind", &"snow": &"snow", &"baro": &"baro", &"baro_tend": &"baro"}


## Сверка книжки с приборами перед передачей: {"verdict": &"ok" | &"remark" | &"bad" | &"fever" | &"none",
## "remark": [приборы], "bad": [приборы]}. &"fever" — вписали +36,6; &"none" — книжки нет
## (замер снят не руками: автотест, кооп).
func report_check() -> Dictionary:
	var out := {"verdict": &"none", "remark": [], "bad": []}
	if notebook.is_empty():
		return out
	out["verdict"] = &"ok"
	for k: StringName in notebook:
		var e: Dictionary = notebook[k]
		var v := float(e["v"])
		if (k == &"temp_dry" or k == &"temp_wet") and v >= 35.0 and v <= 38.0:
			out["verdict"] = &"fever"
			return out
		if has_flag("tm4_mercury_violation") and (k == &"temp_dry" or k == &"temp_wet"):
			if not out["bad"].has(&"temp"):
				out["bad"].append(&"temp")
		var err := absf(v - float(e["t"]))
		if k == &"wind_dir":
			err = minf(err, 16.0 - err)
		var tol: Array = READ_TOL.get(k, [0.5, 1.5])
		var g: StringName = READ_GROUP.get(k, k)
		if err > float(tol[1]):
			if not out["bad"].has(g):
				out["bad"].append(g)
		elif err > float(tol[0]) and not out["remark"].has(g):
			out["remark"].append(g)
	for g in out["bad"]:
		out["remark"].erase(g)
	if not out["bad"].is_empty():
		out["verdict"] = &"bad"
	elif not out["remark"].is_empty():
		out["verdict"] = &"remark"
	return out


func report_verdict() -> StringName:
	return report_check()["verdict"]


## Сколько сводок этой ночи пропущено (прошёл срок + 45 мин, а не передана).
func reports_missed() -> int:
	return _silence_marked.size()


func report_times() -> Array:
	return cfg.get("reports", [])


## Правило 1 и записка Семёнова: станция не должна молчать. Опоздание на 45 минут — эфир
## спрашивает, почему молчим, и тишина притягивает (порог Ырки до конца ночи выше).
## После 03:00 несданные сводки сорваны: передавать их уже нельзя (правило 2).
func _tick_reports() -> void:
	var times := report_times()
	for i in range(times.size()):
		if i >= reports_sent and shift_minutes > float(times[i]) + 45.0 and not _silence_marked.has(i):
			_silence_marked[i] = true
			reports_silent += 1
			Director.add_tension(20.0, "станция молчит")
			add_fatigue(6.0)
			if radio != null and Voice.has(&"ml_silent") and is_home():
				radio.play_transmission(Voice.path(&"ml_silent"), 0.0, Radio.Pass.REAL)
			elif audio != null:
				audio.play_2d("res://assets/audio/static_loop.ogg", -12.0, 3.0).seek(8.5)
			if hud != null:
				hud.subtitle(Loc.t(&"radio.why_silent"), 5.0)
	if not reports_closed and after_hour(3) and reports_sent < times.size():
		reports_closed = true
		if hud != null:
			hud.subtitle(Loc.t(&"radio.reports_closed"), 5.0)


# --- Предметы и находки (переживают фазу через SaveGame) ---------------------

func has_item(id: StringName) -> bool:
	return SaveGame.items.has(id)


## Запасные ракеты (найденные в леднике, на чердаке, на озере) — хранятся между ночами
## и тратятся после ночного пайка.
func spare_flares() -> int:
	return int(SaveGame.flags.get("spare_flares", 0))


func add_spare_flares(n: int) -> void:
	SaveGame.flags["spare_flares"] = spare_flares() + n


func flares_total() -> int:
	return flares + spare_flares()


func use_flare() -> bool:
	if flares > 0:
		flares -= 1
		return true
	if spare_flares() > 0:
		SaveGame.flags["spare_flares"] = spare_flares() - 1
		return true
	return false


func give_item(id: StringName) -> void:
	if not SaveGame.items.has(id):
		SaveGame.items.append(id)


func has_flag(id: String) -> bool:
	return bool(SaveGame.flags.get(id, false))


func set_flag(id: String, value: Variant = true) -> void:
	SaveGame.flags[id] = value


func add_intercept(id: StringName) -> bool:
	if SaveGame.intercepts.has(id):
		return false
	SaveGame.intercepts.append(id)
	return true


func add_tape(id: StringName) -> bool:
	if SaveGame.tapes.has(id):
		return false
	SaveGame.tapes.append(id)
	return true


func mark_decoded(id: StringName) -> bool:
	if SaveGame.decoded.has(id):
		return false
	SaveGame.decoded.append(id)
	return true


# --- Пролог ------------------------------------------------------------------

func complete_step(step: StringName) -> void:
	if not is_prologue() or tutorial.get(step, false):
		return
	tutorial[step] = true
	if hud != null:
		hud.subtitle(Loc.t(&"tut.done"), 2.0)


func tutorial_done() -> bool:
	for s in TUTORIAL_STEPS:
		if s == &"driver":
			continue
		if not tutorial.get(s, false):
			return false
	return true


# --- Тепло и усталость -------------------------------------------------------

func _tick_heat(delta: float) -> void:
	if stove_wood > 0.0:
		var burn_k := Consequences.stove_burn_k()   # выбитое окно — печь выстывает быстрее
		if salt_on_threshold:
			burn_k *= 1.35
		if spirit_treat:
			burn_k *= 0.85
		if stove_damper:
			burn_k *= DAMPER_BURN_K
		if stove_flue:
			burn_k *= 0.3   # без тяги дрова почти не горят — тлеют и дымят
		stove_wood = maxf(stove_wood - STOVE_BURN_PER_SEC * burn_k * delta, 0.0)
		stove_heat = minf(stove_heat + HEAT_CHARGE_PER_SEC * (0.6 if stove_damper else 1.0) * delta, 100.0)
	else:
		stove_heat = maxf(stove_heat - HEAT_DECAY_PER_SEC * (0.5 if stove_flue else 1.0) * delta, 0.0)
	var hk := house_heat_k()

	var storm := weather.intensity if weather != null else 0.0
	var cold := threat_mult() * (0.5 if is_day() else 1.0)
	match zone:
		&"room":
			warmth += (WARMTH_GAIN_STOVE * hk if hk > 0.05 else -0.15) * delta
		&"radio_room":
			# Радиорубка греется той же печью через стену — медленнее жилой комнаты.
			warmth += (1.4 * hk if hk > 0.05 else -0.2) * delta
		&"corridor":
			warmth += (1.0 * hk if hk > 0.05 else -0.2) * delta
		&"vestibule":
			warmth += (0.4 * hk if hk > 0.05 else -0.3) * delta
		&"storage", &"attic":
			warmth += (-0.25) * delta
		&"bunker":
			warmth += 0.2 * delta   # под землёй тепло от аппаратуры
		&"cellar":
			warmth += 0.3 * delta   # земля в подполе Брагина тёплая — и это неправильно
		&"tunnel", &"mine":
			warmth -= 0.05 * delta
		&"walled":
			warmth -= 0.35 * delta   # кабинет Голубева выстужен до инея
		&"corpus":
			# Корпус кирпичный: без буржуйки остываешь медленно, растоплена — греет как дом
			var lit := MeteoCorpus.instance != null and MeteoCorpus.instance.stove_lit
			warmth += (1.6 if lit else -0.12) * delta
		&"shed", &"izba", &"gen_shack", &"lake_shack", &"corpus_gen", &"hangar":
			if Gear.has(&"spirit_stove"):
				warmth = minf(warmth + 0.6 * delta, 100.0)   # спиртовка: в холодном укрытии отогреваешься
			else:
				warmth -= WARMTH_LOSS_OUTSIDE * 0.5 * cold * delta
		_:
			# Тулуп из снабжения — на четверть медленнее; овчинный тулуп геолога с лесосеки — ещё на 35%
			var coat := 0.75 if has_flag("upg_tulup") else 1.0
			if has_item(&"sheepskin_coat") or has_flag("has_sheepskin_coat"):
				coat *= 0.65
			if Dog.is_near_player():
				coat *= 0.85     # Найда жмётся к ногам — теплее
			var ridge_wind := 1.45 if (player != null and player.global_position.y > 70.0) else 1.0
			warmth -= WARMTH_LOSS_OUTSIDE * (1.0 + storm * 1.2) * cold * coat * ridge_wind * delta
			Consequences.note_cold(warmth)
			if warmth < 28.0 and Gear.thermos_ready():
				Gear.use_thermos()

	var door_open: bool = level != null and level.get(&"door_open") == true
	if door_open:
		var chill_draft := (0.7 + storm * 1.5) * delta
		match zone:
			&"vestibule":
				warmth -= chill_draft * 2.2
			&"corridor":
				warmth -= chill_draft * 1.4
			&"room", &"radio_room":
				warmth -= chill_draft * 0.8
		if stove_wood > 0.0:
			stove_wood = maxf(stove_wood - STOVE_BURN_PER_SEC * 0.5 * delta, 0.0)

	if tea_cd > 0.0:
		tea_cd -= delta
	# Горячий чай временно согревает и держит температуру
	if tea_warmth_timer > 0.0:
		tea_warmth_timer -= delta
		warmth = minf(warmth + 0.8 * delta, 100.0)

	if firm_hands_timer > 0.0:
		firm_hands_timer -= delta
	if padlock_thaw_t > 0.0:
		padlock_thaw_t -= delta

	# Моторика пальцев рук (-43°C):
	if is_outside():
		var storm_wind: float = weather.intensity if weather != null else 0.0
		var subzero: float = absf(minf(air_temp().x, -10.0)) - 10.0
		var cool_rate: float = subzero * 0.009 + (0.06 if storm_wind > 0.5 else 0.0)
		if not has_item(&"mittens"):
			cool_rate *= 1.8
		finger_temp = maxf(finger_temp - cool_rate * delta, 14.0)
	elif zone == &"room" or zone == &"radio_room":
		var room_warmth := 0.45 if stove_wood > 0.0 else 0.15
		finger_temp = minf(finger_temp + room_warmth * delta, 33.5)
	else:
		finger_temp = move_toward(finger_temp, 28.0, delta * 0.1)

	# Забитый дымоход при горящей печи: угар копится в тёплых комнатах (не на чердаке и не в кладовой).
	# ~80 с до смерти — хватает, чтобы понять по кашлю и выйти чистить трубу или залить печь.
	var smoky := zone == &"room" or zone == &"radio_room" or zone == &"corridor" or zone == &"vestibule"
	if (chimney_iced or stove_flue) and stove_wood > 0.0 and smoky:   # забитая труба или вьюшка закрыта при огне
		co_poisoning = clampf(co_poisoning + 0.012 * delta, 0.0, 1.0)
		if co_poisoning > 0.2 and rng.randf() < delta * (0.15 + co_poisoning * 0.5):
			audio.play_2d("res://assets/audio/cough.ogg", 1.0)
			if player != null:
				player.shake(0.02 + co_poisoning * 0.03, 0.3)
		if co_poisoning >= 1.0 and not dying and not dead:
			dying = true
			clock_running = false
			if player != null:
				await player.death_freeze()
			die(&"co_smoke")
			return
	else:
		co_poisoning = maxf(co_poisoning - 0.15 * delta, 0.0)

	if is_prologue():
		warmth = clampf(warmth, 5.0, 100.0)
	else:
		warmth = clampf(warmth, 0.0, 100.0)
		if warmth <= 0.0 and not dying:
			_freeze_to_death()


func _tick_fatigue(delta: float) -> void:
	if not is_night():
		return
	var rate := 0.03
	if is_dark():
		rate += 0.06
	if warmth < 40.0:
		rate += 0.04
	fatigue = clampf(fatigue + rate * delta, 0.0, 100.0)


## Сквозняк и прочий холод «в доме» (открытая дверь). Снаружи холод считает _tick_heat сам.
func add_cold(amount: float) -> void:
	if is_home():
		warmth = clampf(warmth - amount, 0.0, 100.0)


func add_fatigue(amount: float) -> void:
	fatigue = clampf(fatigue + amount, 0.0, 100.0)


func stove_state() -> String:
	if stove_wood <= 0.0:
		return Loc.t(&"stove.embers") if stove_heat > 15.0 else Loc.t(&"stove.out")
	if stove_wood < 25.0:
		return Loc.t(&"stove.low")
	return Loc.t(&"stove.burning")


# --- Контекст игрока ---------------------------------------------------------

func set_zone(z: StringName) -> void:
	if z == zone:
		return
	zone = z
	EventBus.zone_changed.emit(z)
	if is_home() and player != null and player.held == &"trunk" and not has_flag("trunk_delivered"):
		set_flag("trunk_delivered", true)
		if hud != null:
			hud.subtitle(Loc.t(&"sub.trunk_delivered"), 4.5)


func set_activity(a: StringName) -> void:
	if a == activity:
		return
	activity = a
	EventBus.activity_changed.emit(a)


func is_home() -> bool:
	return zone == &"room" or zone == &"radio_room" or zone == &"corridor" or zone == &"vestibule" or zone == &"storage" or zone == &"attic"


## Под крышей (дом, сарай, изба, рыбацкий домик, бункер): снега и тумана нет, Ырка не войдёт.
func is_indoors() -> bool:
	return is_home() or zone == &"shed" or zone == &"izba" or zone == &"bunker" or zone == &"lake_shack" or zone == &"gen_shack" \
		or zone == &"corpus" or zone == &"corpus_gen" or zone == &"hangar" or zone == &"cellar" or zone == &"tunnel" or zone == &"walled" or zone == &"mine"



func is_outside() -> bool:
	return not is_indoors()


func is_confined_space() -> bool:
	return zone in [&"storage", &"vestibule", &"attic", &"cellar", &"tunnel", &"mine", &"gen_shack", &"lake_shack", &"shed", &"walled"]


func is_dark() -> bool:
	if zone == &"cellar" or zone == &"tunnel" or zone == &"walled":
		return true   # свет — только свой фонарь (в тоннеле две лампы на всю длину, и те моргают)
	if is_day():
		return (zone == &"shed" and not power_on) or zone == &"storage"
	if is_home():
		if zone == &"storage":
			return true
		# Керосинка — аварийный свет в радиорубке: без генератора там не темно.
		if zone == &"radio_room" and level != null and level.kerosene_on():
			return false
		return level == null or not level.lights_lit()
	if zone == &"gen_shack" or zone == &"lake_shack" or zone == &"izba":
		return false   # там свои лампы/фонари
	if zone == &"corpus" or zone == &"corpus_gen" or zone == &"hangar":
		return MeteoCorpus.instance == null or not MeteoCorpus.instance.powered
	if zone == &"shed":
		return not power_on
	if zone == &"bunker":
		return false
	return true


# --- Время и задачи ----------------------------------------------------------

## true, если на часах уже наступил указанный час (например, 3 → 03:00). Только для ночи.
func after_hour(hour: int) -> bool:
	if not is_night():
		return false
	var minutes := ((hour + 24 - base_hour) % 24) * 60
	return shift_minutes >= minutes


func minutes_to_clock(shift_min: int) -> String:
	var total := (base_hour * 60 + shift_min) % 1440
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


func clock_text() -> String:
	return minutes_to_clock(int(shift_minutes))


## Самая срочная задача — одна строка в углу экрана.
func objective_text() -> String:
	if memory_goal != "":
		return memory_goal
	if shift_over or dead:
		return ""
	if is_prologue():
		return story_goal if story_goal != "" else _tutorial_objective()
	if warmth < 30.0:
		return Loc.t(&"obj.cold")
	if story_goal != "":
		return story_goal
	if is_day():
		return _day_objective()
	if final_call:
		return Loc.t(&"obj.choice") + (Loc.t(&"obj.choice_src") if has_flag("source_found") else "")
	if chimney_iced and stove_wood > 0.0:
		return Loc.t(&"obj.chimney")
	if is_night() and is_home() and level != null and level.get("door_open") == true:
		return Loc.t(&"obj.door_open")
	if gen_broken:
		return Loc.t(&"obj.gen_broken") if not has_item(&"tools") else Loc.t(&"obj.gen_repair")
	if fuel_sputter:
		return Loc.t(&"obj.fuel_sputter")
	if not power_on:
		return Loc.t(&"obj.gen_dead")
	if generator_fuel < 20.0:
		return Loc.t(&"obj.gen_low")
	if stove_wood < 15.0:
		return Loc.t(&"obj.stove_low")
	if events != null and events.orders != null and events.orders.objective() != "":
		return events.orders.objective()
	var times := report_times()
	# Между сводками — задание Большой Земли, если до следующей сводки ещё есть время.
	if tasks != null and tasks.objective() != "" and (reports_sent >= times.size() or float(times[reports_sent]) - shift_minutes > 30.0):
		return tasks.objective()
	if reports_sent < times.size() and not reports_closed:
		var t := minutes_to_clock(int(times[reports_sent]))
		var late := Loc.t(&"obj.late") if shift_minutes > float(times[reports_sent]) else ""
		if not has_readings():
			if anemo_iced and not readings.get(&"wind", false):
				return Loc.t(&"obj.anemo")
			return Loc.t(&"obj.readings", [t, readings_count(), late])
		if antenna_iced:
			return Loc.t(&"obj.ice")
		return Loc.t(&"obj.transmit", [t, late])
	if cfg.get("finale", &"") == &"choice":
		return Loc.t(&"obj.wait_call")
	if cfg.get("finale", &"") != &"":
		return Loc.t(&"obj.wait_morning")
	return Loc.t(&"obj.sleep")


func _tutorial_objective() -> String:
	if not has_flag("prologue_arrived"):
		if has_flag("in_cabin"):
			return Loc.t(&"obj.cabin_ride")
		if has_flag("dig_pending"):
			return Loc.t(&"obj.dig")
		if not is_home():
			return Loc.t(&"obj.reach_station")
		return Loc.t(&"obj.sleep_arrival")
	for s in TUTORIAL_STEPS:
		if s == &"driver":
			continue
		if not tutorial.get(s, false):
			if s == &"readings":
				return Loc.t(&"tut.readings", [readings_count()])
			return Loc.t(StringName("tut." + String(s)))
	return Loc.t(&"tut.rest")


func _far_sites_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if not FarSites.known() or is_prologue():
		return lines
	lines.append("")
	if Dog.is_home():
		lines.append(("[x] " if Dog.fed_this_phase() else "[ ] ") + Loc.t(&"dog.task_feed"))
	return lines


func _day_objective() -> String:
	if not day_goal_done:
		return Loc.t(StringName("day%d.goal" % phase_index))
	if is_evening() and not evening_ready():
		return Loc.t(&"obj.evening")
	var fj := FieldJobs.objective()
	if fj != "":
		return fj
	return Loc.t(&"day.rest")


## Только аварии — для обычной и сложной сложности (без подсказок по рутине).
func alarm_text() -> String:
	if not is_night() or is_prologue():
		return ""
	if co_poisoning > 0.15 or (chimney_iced and stove_wood > 0.0):
		return Loc.t(&"obj.chimney")
	if gen_broken:
		return Loc.t(&"obj.gen_broken") if not has_item(&"tools") else Loc.t(&"obj.gen_repair")
	if fuel_sputter:
		return Loc.t(&"obj.fuel_sputter")
	if not power_on:
		return Loc.t(&"obj.gen_dead")
	if level != null and level.get("door_open") == true and is_home():
		return Loc.t(&"obj.door_open")
	if anemo_iced:
		return Loc.t(&"obj.anemo")
	if antenna_iced:
		return Loc.t(&"obj.ice")
	return ""


## Полный список обязанностей (Tab).
func tasks_text() -> String:
	var lines: PackedStringArray = [Loc.t(&"tasks.title"), ""]
	if is_prologue():
		if not has_flag("prologue_arrived"):
			var t1 := "[x]" if is_home() else "[ ]"
			lines.append("%s %s" % [t1, Loc.t(&"obj.reach_station")])
			lines.append("[ ] %s" % Loc.t(&"obj.sleep_arrival"))
		else:
			for s in TUTORIAL_STEPS:
				if s == &"driver":
					continue
				var mark := "[x]" if tutorial.get(s, false) else "[ ]"
				var line := Loc.t(&"tut.readings", [readings_count()]) if s == &"readings" else Loc.t(StringName("tut." + String(s)))
				lines.append("%s %s" % [mark, line])
	elif is_day():
		lines.append(("[x] " if day_goal_done else "[ ] ") + Loc.t(StringName("day%d.goal" % phase_index)))
		lines.append_array(_far_sites_lines())
		lines.append_array(FieldJobs.task_lines())
		if not is_prologue():
			lines.append("")
			lines.append(Loc.t(&"tasks.evening"))
			lines.append(("  [x] " if forecast_filed() else "  [ ] ") + Loc.t(&"tasks.ev_forecast"))
			lines.append(("  [x] " if Rituals.any_set() else "  [ ] ") + Loc.t(&"tasks.ev_wards"))
	else:
		if final_call:
			lines.append(Loc.t(&"obj.choice"))
			lines.append("")
		# Аварии этой ночи — отдельным списком, чтобы было видно, что и где чинить.
		var alarms: PackedStringArray = []
		if gen_broken:
			alarms.append(Loc.t(&"obj.gen_broken") if not has_item(&"tools") else Loc.t(&"obj.gen_repair"))
		if chimney_iced:
			alarms.append(Loc.t(&"obj.chimney"))
		if fuel_sputter:
			alarms.append(Loc.t(&"obj.fuel_sputter"))
		if anemo_iced:
			alarms.append(Loc.t(&"obj.anemo"))
		if level != null and level.get("door_open") == true:
			alarms.append(Loc.t(&"obj.door_open"))
		if antenna_iced:
			alarms.append(Loc.t(&"obj.ice"))
		if not alarms.is_empty():
			lines.append(Loc.t(&"tasks.alarms"))
			for a_line in alarms:
				lines.append("  ! " + a_line)
			lines.append("")
		var times := report_times()
		for i in range(times.size()):
			var mark := "[x]" if i < reports_sent else ("[—]" if reports_closed else "[ ]")
			lines.append(Loc.t(&"tasks.report", [mark, minutes_to_clock(int(times[i]))]))
		lines.append(Loc.t(&"tasks.readings", [", ".join(_readings_list())]))
		lines.append_array(_far_sites_lines())
		lines.append_array(FieldJobs.task_lines())
		if events != null and events.orders != null and events.orders.objective() != "":
			lines.append("  ? " + events.orders.objective())
		if tasks != null and not tasks.lines().is_empty():
			lines.append("")
			lines.append(Loc.t(&"tasks.orders"))
			lines.append_array(tasks.lines())
	lines.append("")
	lines.append(Loc.t(&"tasks.gen", [int(generator_fuel), "" if power_on else Loc.t(&"tasks.gen_dead")]))
	lines.append(Loc.t(&"tasks.cans", [canisters_left]))
	lines.append(Loc.t(&"tasks.stove", [stove_state()]))
	if has_item(&"flare_gun"):
		lines.append(Loc.t(&"tasks.flares", [flares_total()]))
	if is_night():
		lines.append(Loc.t(&"tasks.ice") if antenna_iced else Loc.t(&"tasks.antenna_ok"))
	lines.append("")
	var gear_line := Gear.tasks_line()
	if gear_line != "":
		lines.append(gear_line)
	lines.append(Loc.t(&"tasks.intercepts", [SaveGame.intercepts.size(), SaveGame.tapes.size()]))
	lines.append(Loc.t(&"tasks.icp_hint"))
	lines.append("")
	lines.append(Loc.t(&"tasks.close"))
	return "\n".join(lines)


func _readings_list() -> PackedStringArray:
	var out: PackedStringArray = []
	for k in READING_KEYS:
		out.append(("[x] " if readings.get(k, false) else "[ ] ") + Loc.t(StringName("reading." + String(k))))
	return out


## Секретная концовка: прочитана правда в бункере и очищено хотя бы три плёнки.
func secret_ready() -> bool:
	var cleaned := 0
	for d in SaveGame.decoded:
		if String(d).ends_with("_clean"):
			cleaned += 1
	# Или эфир: найдено, что сводку о тебе передают из дома, а голос Семёнова идёт из бункера
	return (cleaned >= 3 and has_flag("truth")) or (Efir.has_find(&"alone") and Efir.has_find(&"bunker"))


func end_shift() -> void:
	if shift_over or (dead and not coop_ghost):
		return
	shift_over = true
	clock_running = false
	# Правило 9: лёг, как только смог (раньше 06:00), — усталость к следующей ночи уходит лучше.
	SaveGame.flags["fatigue"] = fatigue * (0.25 if is_night() and shift_minutes < NIGHT_END_MIN - 5.0 else 0.4)
	if is_night():
		NightMemory.close_night()
	EventBus.shift_ended.emit()


## Холод: сначала сцена падения, потом экран смерти. Часы встают сразу — второй раз не умрёшь.
func _freeze_to_death() -> void:
	if dying or dead:
		return
	dying = true
	clock_running = false
	if player != null:
		await player.death_freeze()
	die(&"cold")


func die(reason: StringName) -> void:
	if dead or shift_over:
		return
	dead = true
	clock_running = false
	EventBus.player_died.emit(reason)


var is_gamepad := false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if not is_gamepad:
			is_gamepad = true
			EventBus.input_device_changed.emit(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3:
		if not is_gamepad:
			is_gamepad = true
			EventBus.input_device_changed.emit(true)
	elif event is InputEventKey or (event is InputEventMouseButton and (event as InputEventMouseButton).is_pressed()):
		if is_gamepad:
			is_gamepad = false
			EventBus.input_device_changed.emit(false)


## Вибрация контроллера (Haptic Feedback / Rumble)
func vibrate(weak := 0.4, strong := 0.4, duration := 0.2, device := 0) -> void:
	if Settings != null and not Settings.rumble:
		return
	Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


func stop_vibration(device := 0) -> void:
	Input.stop_joy_vibration(device)


# --- Ввод (раскладка задаётся кодом) -----------------------------------------

func _setup_input() -> void:
	# 1. Клавиатура и мышь
	_bind(&"move_forward", [KEY_W, KEY_UP])
	_bind(&"move_back", [KEY_S, KEY_DOWN])
	_bind(&"move_left", [KEY_A, KEY_LEFT])
	_bind(&"move_right", [KEY_D, KEY_RIGHT])
	_bind(&"interact", [KEY_E])
	_bind(&"flashlight", [KEY_F])
	_bind(&"wipe_face", [KEY_F])
	_bind(&"crank", [KEY_Q])
	_bind(&"drop", [KEY_G])
	_bind(&"tasks", [KEY_TAB])
	_bind(&"map", [KEY_M])
	_bind(&"codebook", [KEY_B])
	_bind(&"transmit", [KEY_R])
	_bind(&"record", [KEY_T])
	_bind(&"fine_tune", [KEY_SHIFT])
	_bind(&"sprint", [KEY_SHIFT])
	_bind(&"hold_breath", [KEY_SPACE])
	_bind(&"pause", [KEY_ESCAPE])
	_bind(&"flare", [KEY_V])
	_bind(&"coop_talk", [KEY_C])        # рация коопа «Две вахты» (держать)
	_bind(&"coop_phrase", [KEY_X])      # готовые фразы в рацию (для тех, кто без микрофона)
	_bind(&"intercepts", [KEY_J])
	_bind(&"photo", [KEY_Z])            # «Зенит-Е»: держать — видоискатель, отпустить — кадр
	_bind(&"whistle", [KEY_H])          # свист Найде: коротко — «ко мне / сидеть», держать — «домой»
	_bind(&"debug_overlay", [KEY_F3])
	_bind(&"debug_boost", [KEY_F4])
	_bind(&"debug_yrka", [KEY_F2])
	_bind(&"debug_skip", [KEY_F6])

	# 2. Геймпад / Контроллер (Xbox, PlayStation DualSense/DualShock, Switch Pro, Steam Deck)
	# Левый стик — перемещение дежурного
	_bind_joy_axis(&"move_left", JoyAxis.JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_axis(&"move_right", JoyAxis.JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_axis(&"move_forward", JoyAxis.JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_axis(&"move_back", JoyAxis.JOY_AXIS_LEFT_Y, 1.0)

	# Правый стик — обзор камерой
	_bind_joy_axis(&"look_left", JoyAxis.JOY_AXIS_RIGHT_X, -1.0)
	_bind_joy_axis(&"look_right", JoyAxis.JOY_AXIS_RIGHT_X, 1.0)
	_bind_joy_axis(&"look_up", JoyAxis.JOY_AXIS_RIGHT_Y, -1.0)
	_bind_joy_axis(&"look_down", JoyAxis.JOY_AXIS_RIGHT_Y, 1.0)

	# Кнопки действий (Лицевые кнопки A, B, X, Y)
	_bind_joy_btn(&"interact", JoyButton.JOY_BUTTON_A)       # A / Cross: взаимодействие, осмотр
	_bind_joy_btn(&"drop", JoyButton.JOY_BUTTON_B)           # B / Circle: бросить предмет, назад
	_bind_joy_btn(&"crank", JoyButton.JOY_BUTTON_X)          # X / Square: динамо-машина, завод барографа
	_bind_joy_btn(&"record", JoyButton.JOY_BUTTON_X)         # X на рации: запись перехвата
	_bind_joy_btn(&"flashlight", JoyButton.JOY_BUTTON_Y)     # Y / Triangle: фонарик

	# Бамперы и стики (Плечевые кнопки)
	_bind_joy_btn(&"sprint", JoyButton.JOY_BUTTON_LEFT_SHOULDER) # LB: спринт
	_bind_joy_btn(&"sprint", JoyButton.JOY_BUTTON_LEFT_STICK)    # L3: спринт при нажатии стика
	_bind_joy_btn(&"hold_breath", JoyButton.JOY_BUTTON_RIGHT_SHOULDER) # RB: задержка дыхания
	_bind_joy_btn(&"coop_talk", JoyButton.JOY_BUTTON_RIGHT_STICK)      # R3: рация коопа
	_bind_joy_btn(&"fine_tune", JoyButton.JOY_BUTTON_LEFT_SHOULDER)    # LB: точная настройка рации

	# Триггеры
	_bind_joy_axis(&"flare", JoyAxis.JOY_AXIS_TRIGGER_RIGHT, 1.0) # RT: выстрел ракетницы
	# «Зенит-Е» как прицел в шутере: LT — видоискатель, RT при поднятом аппарате — затвор (ракетница молчит)
	_bind_joy_axis(&"photo", JoyAxis.JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind_joy_axis(&"photo_shoot", JoyAxis.JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(&"photo_shoot", lmb)            # клавиатура: держать Z, кадр — ЛКМ
	# Кооп: Back открывает фразы (блокнот остаётся на D-pad ↑), выбор — D-pad и X/Y
	_bind_joy_btn(&"coop_phrase", JoyButton.JOY_BUTTON_BACK)
	_bind_joy_btn(&"transmit", JoyButton.JOY_BUTTON_RIGHT_SHOULDER) # RB / A на рации: передача
	_bind_joy_btn(&"transmit", JoyButton.JOY_BUTTON_A)

	# Меню и системные кнопки
	_bind_joy_btn(&"pause", JoyButton.JOY_BUTTON_START)      # Start / Options / Menu: пауза

	# Крестовина (D-Pad) — быстрый доступ к документам станции
	_bind_joy_btn(&"tasks", JoyButton.JOY_BUTTON_DPAD_UP)         # D-Pad Вверх: блокнот заданий
	_bind_joy_btn(&"tasks", JoyButton.JOY_BUTTON_BACK)       # Back / View / Share / Touchpad: блокнот (в коопе — фразы)
	_bind_joy_btn(&"map", JoyButton.JOY_BUTTON_DPAD_LEFT)         # D-Pad Влево: карта станции
	_bind_joy_btn(&"codebook", JoyButton.JOY_BUTTON_DPAD_DOWN)    # D-Pad Вниз: шифроблокнот
	_bind_joy_btn(&"intercepts", JoyButton.JOY_BUTTON_DPAD_RIGHT) # D-Pad Вправо: журнал перехватов

	# UI Навигация в меню (D-Pad + Левый стик + A/B кнопки)
	_bind_joy_btn(&"ui_up", JoyButton.JOY_BUTTON_DPAD_UP)
	_bind_joy_btn(&"ui_down", JoyButton.JOY_BUTTON_DPAD_DOWN)
	_bind_joy_btn(&"ui_left", JoyButton.JOY_BUTTON_DPAD_LEFT)
	_bind_joy_btn(&"ui_right", JoyButton.JOY_BUTTON_DPAD_RIGHT)

	_bind_joy_axis(&"ui_left", JoyAxis.JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_axis(&"ui_right", JoyAxis.JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_axis(&"ui_up", JoyAxis.JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_axis(&"ui_down", JoyAxis.JOY_AXIS_LEFT_Y, 1.0)

	_bind_joy_btn(&"ui_accept", JoyButton.JOY_BUTTON_A)
	_bind_joy_btn(&"ui_cancel", JoyButton.JOY_BUTTON_B)

	# Клавиатурная UI-навигация
	_bind(&"ui_up", [KEY_UP, KEY_W])
	_bind(&"ui_down", [KEY_DOWN, KEY_S])
	_bind(&"ui_left", [KEY_LEFT, KEY_A])
	_bind(&"ui_right", [KEY_RIGHT, KEY_D])
	_bind(&"ui_accept", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	_bind(&"ui_cancel", [KEY_ESCAPE, KEY_BACKSPACE])


## Действия, которые игрок может переназначить (Настройки → Клавиши). Стрелки для ходьбы остаются всегда.
const REBINDABLE: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"interact",
	&"flashlight", &"crank", &"sprint", &"hold_breath", &"drop", &"tasks", &"map", &"codebook", &"intercepts",
	&"transmit", &"record", &"flare", &"coop_talk", &"coop_phrase", &"photo", &"whistle"]
const _ARROWS := {&"move_forward": KEY_UP, &"move_back": KEY_DOWN, &"move_left": KEY_LEFT, &"move_right": KEY_RIGHT}


## Клавиша действия на клавиатуре (первая), для подписей и экрана переназначения.
func key_of(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return int((ev as InputEventKey).physical_keycode)
	return 0


## Переназначить клавишу (code 0 — вернуть по умолчанию). Сохраняется в настройках.
func rebind(action: StringName, code: int) -> void:
	if code == 0:
		Settings.keybinds.erase(String(action))
	else:
		Settings.keybinds[String(action)] = code
	Settings.save()
	if code == 0:
		# Сброс: снимаем клавиатурные события и ставим заводские заново
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		_setup_default_key(action)
	else:
		_set_key(action, code)


# --- Геймпад: переназначение (Настройки → Геймпад) ----------------------------------
## Что можно переназначить на геймпаде. Стики (ходьба, обзор) и Start (пауза) — на месте.
const PAD_REBINDABLE: Array[StringName] = [&"interact", &"drop", &"crank", &"flashlight", &"sprint", &"hold_breath",
	&"flare", &"photo", &"photo_shoot", &"coop_talk", &"coop_phrase", &"tasks", &"map", &"codebook", &"intercepts"]
## Действия «в другом режиме» на той же кнопке: переназначил основное — переезжают и они
## (запись на рации идёт за динамо-машиной, точная настройка — за бегом, передача — за дыханием).
const PAD_LINKED := {&"crank": [&"record"], &"sprint": [&"fine_tune"], &"hold_breath": [&"transmit"]}
## Пары, которым одна кнопка — норма: RT стреляет ракетой, а с поднятым «Зенитом» — затвором.
const PAD_SHARED := [[&"flare", &"photo_shoot"]]
const _PAD_BTN_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→"}
var _pad_defaults: Dictionary = {}


func _snapshot_pad_defaults() -> void:
	for a: StringName in PAD_REBINDABLE + [&"record", &"fine_tune", &"transmit"]:
		var evs: Array = []
		if InputMap.has_action(a):
			for ev in InputMap.action_get_events(a):
				if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
					evs.append(ev.duplicate())
		_pad_defaults[a] = evs


static func _pad_ev_to_data(ev: InputEvent) -> Array:
	if ev is InputEventJoypadButton:
		return [0, int((ev as InputEventJoypadButton).button_index), 1.0]
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		return [1, int(m.axis), 1.0 if m.axis_value >= 0.0 else -1.0]
	return []


static func _pad_data_to_ev(d: Array) -> InputEvent:
	if d.size() < 3:
		return null
	if int(d[0]) == 0:
		var b := InputEventJoypadButton.new()
		b.button_index = int(d[1]) as JoyButton
		return b
	var m := InputEventJoypadMotion.new()
	m.axis = int(d[1]) as JoyAxis
	m.axis_value = float(d[2])
	return m


static func _pad_same(a: Array, b: Array) -> bool:
	return a.size() == 3 and b.size() == 3 and int(a[0]) == int(b[0]) and int(a[1]) == int(b[1]) and (int(a[0]) == 0 or signf(a[2]) == signf(b[2]))


## Основная кнопка геймпада у действия: [тип, индекс, знак] или [].
func pad_of(action: StringName) -> Array:
	if not InputMap.has_action(action):
		return []
	for ev in InputMap.action_get_events(action):
		var d := _pad_ev_to_data(ev)
		if not d.is_empty():
			return d
	return []


func pad_name(action: StringName) -> String:
	return pad_label(pad_of(action))


static func pad_label(d: Array) -> String:
	if d.is_empty():
		return "—"
	if int(d[0]) == 0:
		return _PAD_BTN_NAMES.get(int(d[1]), "Btn %d" % int(d[1]))
	match int(d[1]):
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Axis %d%s" % [int(d[1]), "+" if float(d[2]) > 0.0 else "−"]


func _pad_erase(action: StringName, only: Array = []) -> void:
	for ev in InputMap.action_get_events(action):
		var d := _pad_ev_to_data(ev)
		if d.is_empty():
			continue
		if only.is_empty() or _pad_same(d, only):
			InputMap.action_erase_event(action, ev)


func _pad_set(action: StringName, d: Array) -> void:
	var old := pad_of(action)
	_pad_erase(action)
	var ev := _pad_data_to_ev(d)
	if ev != null:
		InputMap.action_add_event(action, ev)
	for linked: StringName in PAD_LINKED.get(action, []):
		if not old.is_empty():
			_pad_erase(linked, old)
		if ev != null:
			InputMap.action_add_event(linked, ev.duplicate())


static func _pad_shared(a: StringName, b: StringName) -> bool:
	for pair: Array in PAD_SHARED:
		if pair.has(a) and pair.has(b):
			return true
	return false


## Переназначить кнопку геймпада (d пустой — вернуть заводскую). Та же кнопка у другого действия — меняем местами.
func rebind_pad(action: StringName, d: Array) -> void:
	if d.is_empty():
		Settings.padbinds.erase(String(action))
		_pad_erase(action)
		for ev in _pad_defaults.get(action, []):
			InputMap.action_add_event(action, (ev as InputEvent).duplicate())
		for linked: StringName in PAD_LINKED.get(action, []):
			_pad_erase(linked)
			for ev in _pad_defaults.get(linked, []):
				InputMap.action_add_event(linked, (ev as InputEvent).duplicate())
		Settings.save()
		return
	var old := pad_of(action)
	for other: StringName in PAD_REBINDABLE:
		if other != action and not _pad_shared(action, other) and _pad_same(pad_of(other), d):
			_pad_set(other, old)
			if old.is_empty():
				Settings.padbinds.erase(String(other))
			else:
				Settings.padbinds[String(other)] = old
	_pad_set(action, d)
	Settings.padbinds[String(action)] = d
	Settings.save()


func apply_padbinds() -> void:
	for a: String in Settings.padbinds:
		var d: Variant = Settings.padbinds[a]
		if PAD_REBINDABLE.has(StringName(a)) and d is Array and (d as Array).size() == 3:
			_pad_set(StringName(a), d)


func apply_keybinds() -> void:
	for a: String in Settings.keybinds:
		if REBINDABLE.has(StringName(a)):
			_set_key(StringName(a), int(Settings.keybinds[a]))


func _set_key(action: StringName, code: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var keys: Array = [code]
	if _ARROWS.has(action) and code != int(_ARROWS[action]):
		keys.append(int(_ARROWS[action]))
	_bind(action, keys)


func _setup_default_key(action: StringName) -> void:
	var defaults := {&"move_forward": [KEY_W, KEY_UP], &"move_back": [KEY_S, KEY_DOWN], &"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT], &"interact": [KEY_E], &"flashlight": [KEY_F], &"crank": [KEY_Q], &"drop": [KEY_G],
		&"tasks": [KEY_TAB], &"map": [KEY_M], &"codebook": [KEY_B], &"transmit": [KEY_R], &"record": [KEY_T],
		&"sprint": [KEY_SHIFT], &"hold_breath": [KEY_SPACE], &"flare": [KEY_V], &"intercepts": [KEY_J], &"coop_talk": [KEY_C], &"coop_phrase": [KEY_X], &"photo": [KEY_Z], &"whistle": [KEY_H]}
	_bind(action, defaults.get(action, []))


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)


func _bind_joy_btn(action: StringName, btn: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)


func _bind_joy_axis(action: StringName, axis: JoyAxis, val: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = val
	InputMap.action_add_event(action, ev)


func finger_stage() -> int:
	if firm_hands_timer > 0.0 or finger_temp >= 31.5:
		return 1 # Норма (+32..+36.6°C)
	elif finger_temp >= 21.5:
		return 2 # Озноб / Деревянные пальцы (+22..+31°C)
	return 3 # Окоченение (+14..+21°C)


func chip_tea_brick() -> bool:
	if tea_brick_chipped:
		return false
	tea_brick_chipped = true
	audio.play_2d("res://assets/audio/clank.ogg", -4.0)
	if hud != null:
		hud.subtitle(Loc.t(&"sub.tea_chipped"), 3.5)
	return true


func brew_tea_in_glass() -> bool:
	if not tea_brick_chipped or tea_brewed:
		return false
	if stove_wood <= 0.0:
		if hud != null:
			hud.subtitle(Loc.t(&"sub.tea_kettle_not_boiling"), 3.0)
		return false
	tea_brewed = true
	audio.play_2d("res://assets/audio/tea_sip.ogg", -2.0)
	if hud != null:
		hud.subtitle(Loc.t(&"sub.tea_poured"), 3.5)
	return true


func warm_hands_with_glass() -> void:
	finger_temp = 36.6
	firm_hands_timer = 300.0 # 5 минут «Твёрдая рука»
	tea_warmth_timer = 90.0
	warmth = minf(warmth + 35.0, 100.0)
	Director.add_tension(-4.0, "отогрев рук о стакан чая")
	audio.play_2d("res://assets/audio/tea_sip.ogg", 0.0)
	if hud != null:
		hud.subtitle(Loc.t(&"sub.tea_firm_hands"), 4.5)


func thaw_padlock_with_match() -> bool:
	if not padlock_shack_frozen:
		return false
	padlock_thaw_t = 6.0
	audio.play_2d("res://assets/audio/flare_shot.ogg", -6.0)
	if hud != null:
		hud.subtitle(Loc.t(&"sub.padlock_thawed_match"), 3.5)
	return true


func thaw_padlock_with_kettle() -> bool:
	if not padlock_shack_frozen:
		return false
	if stove_wood <= 0.0:
		if hud != null:
			hud.subtitle(Loc.t(&"sub.kettle_not_hot"), 3.0)
		return false
	padlock_thaw_t = 6.0
	audio.play_2d("res://assets/audio/tea_sip.ogg", -2.0)
	if hud != null:
		hud.subtitle(Loc.t(&"sub.padlock_thawed_water"), 3.5)
	return true


func try_unlock_padlock() -> bool:
	if not padlock_shack_frozen:
		return true
	if padlock_thaw_t > 0.0:
		padlock_shack_frozen = false
		audio.play_2d("res://assets/sfx/door_handle.ogg", -3.0)
		if hud != null:
			hud.subtitle(Loc.t(&"sub.padlock_opened"), 3.0)
		return true
	audio.play_2d("res://assets/audio/clank.ogg", 0.0)
	if hud != null:
		hud.subtitle(Loc.t(&"sub.padlock_frozen_jam"), 3.5)
	return false
