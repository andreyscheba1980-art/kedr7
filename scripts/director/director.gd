extends Node
## Директор напряжения (по мотивам AI Director из Left 4 Dead).
##
## Копит tension в зависимости от контекста игрока, ловит пик, выбирает испуг из пула ночи
## взвешенным рандомом и после испуга даёт передышку. Обязательные биты ставятся в своё
## окно времени: директор ищет удачный момент, а к концу окна форсирует.

enum Phase { BUILD, PEAK, PLAYING, RELAX }

const POOL_DIR := "res://data/scares/"
const MAX_LOG := 14
const CHECK_INTERVAL := 0.5

# Настройки ночи приходят из Phases.NIGHTS через start(cfg).
var base_rate := 0.6            ## прирост tension в секунду при множителе 1.0
var peak_threshold := 55.0
var max_hard_per_night := 2
var fake_after_sec := 25.0      ## сколько ждать на пике без кандидатов, прежде чем подкинуть ложную тревогу

var enabled := false
var hold := false:              ## сценарное событие ночи идёт — испуги не ставим
	set(v):
		if v != hold:
			_log("сценарное событие: " + ("началось, режиссёр ждёт" if v else "кончилось"))
		hold = v
var tension := 0.0
var phase := Phase.BUILD
var cooldown_left := 0.0
var scares_played := 0
var log_lines: PackedStringArray = []

var _pool: Array[ScareDef] = []
var _uses: Dictionary = {}          ## id -> сколько раз сработал
var _last_type := -1
var _last_creature: StringName = &""
var _hard_count := 0
var _peak_time := 0.0
var _check_timer := 0.0
var debt := 0                       ## пропущенных «замечаний» прошлой ночи: 3+ — дом беспокойнее
## Мелкие «фоновые» пугалки других систем (шорохи, шёпот, силуэты, глаза в кронах, ложные шаги)
## идут через request_ambient: не чаще раза в AMBIENT_GAP, не больше AMBIENT_PER_NIGHT за ночь, только
## пока напряжение набирается — и сами до пика его не дотягивают. Иначе ночь висела на 100 %.
const AMBIENT_GAP := 40.0
const AMBIENT_PER_NIGHT := 14
var _ambient_left := AMBIENT_PER_NIGHT
var _ambient_wait := 20.0


func _ready() -> void:
	_load_pool()
	EventBus.radio_locked.connect(_on_radio_locked)


func start(cfg: Dictionary = {}) -> void:
	reset()
	base_rate = float(cfg.get("base_rate", 0.6))
	peak_threshold = float(cfg.get("peak", 55.0))
	max_hard_per_night = int(cfg.get("max_hard", 2))
	debt = int(SaveGame.flags.get("anom_debt", 0)) if Game.night >= 3 else 0
	if debt >= 3:
		base_rate *= 1.15
	enabled = true
	_log("ночь %d, seed %d" % [Game.night, Game.run_seed])


## Директор — автозагрузка и переживает перезапуск сцены, поэтому сбрасываем всё вручную.
func reset() -> void:
	enabled = false
	hold = false
	tension = 0.0
	phase = Phase.BUILD
	cooldown_left = 0.0
	scares_played = 0
	log_lines = PackedStringArray()
	_uses = {}
	_last_type = -1
	_last_creature = &""
	_hard_count = 0
	_peak_time = 0.0
	_check_timer = 0.0
	_ambient_left = AMBIENT_PER_NIGHT
	_ambient_wait = 20.0


func stop() -> void:
	enabled = false


## Нарастание по ночам: одни и те же события давят слабее в начале недели и в полную силу к концу.
## Замер «обычного игрока» (v1.13): уже на 2-й ночи напряжение упиралось в 100 к 02:00 и висело —
## сердце стучало полночи. Теперь ночь 1 — 55 %, 2 — 70 %, 3 — 85 %, с 4-й — 100 %.
const NIGHT_K := [0.55, 0.55, 0.7, 0.85, 1.0, 1.0, 1.05, 1.1]


func add_tension(amount: float, reason: String) -> void:
	if amount > 0.0 and Game.is_night():
		amount *= NIGHT_K[clampi(Game.night, 0, NIGHT_K.size() - 1)]
	tension = clampf(tension + amount, 0.0, 100.0)
	_log("%+.0f напряжения: %s" % [amount, reason])


func make_context() -> ScareContext:
	var c := ScareContext.new()
	c.zone = Game.zone
	c.activity = Game.activity
	c.dark = Game.is_dark()
	c.flashlight = Game.player != null and Game.player.flashlight_on()
	c.tension = tension
	c.minute = int(Game.shift_minutes)
	c.night = Game.night
	c.fatigue = Game.fatigue
	return c


func phase_name() -> String:
	return Phase.keys()[phase]


## Можно ли сейчас мелкую пугалку. true — разрешено, бюджет списан, напряжение добавлено (не выше пика).
func request_ambient(amount: float, reason: String) -> bool:
	if not enabled or hold or Game.shift_over or phase != Phase.BUILD or _ambient_left <= 0 or _ambient_wait > 0.0:
		return false
	if Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE:
		return false
	_ambient_left -= 1
	_ambient_wait = AMBIENT_GAP * randf_range(0.8, 1.4)
	var room := maxf(peak_threshold - 4.0 - tension, 0.0)
	add_tension(minf(amount, room), "фон: " + reason)
	return true


## Крупное событие другой системы (осада, диверсия) вместо испуга из пула: только на пике,
## после него — передышка, как у обычного испуга.
func take_peak(reason: String, release := 40.0, rest := 60.0) -> bool:
	if not enabled or hold or phase != Phase.PEAK:
		return false
	if Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE:
		return false
	scares_played += 1
	tension = maxf(tension - release, 0.0)
	cooldown_left = rest
	_peak_time = 0.0
	phase = Phase.RELAX
	_log("▶ %s (событие охотника), передышка %.0f с" % [reason, rest])
	return true


# --- Цикл --------------------------------------------------------------------

func _process(delta: float) -> void:
	_ambient_wait = maxf(_ambient_wait - delta, 0.0)
	if not enabled or hold or Game.shift_over or Game.dead or Game.dying or Game.player == null:
		return
	# Пока Ырка гонится, директор молчит: два испуга одновременно гасят друг друга.
	if Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE:
		return
	if phase == Phase.PLAYING:
		return

	var rate := _compute_rate()
	match phase:
		Phase.BUILD:
			tension = minf(tension + rate * delta, 100.0)
			if tension >= peak_threshold:
				phase = Phase.PEAK
				_peak_time = 0.0
				_log("пик: ищу момент")
		Phase.PEAK:
			tension = minf(tension + rate * 0.5 * delta, 100.0)
			_peak_time += delta
			if _peak_time >= fake_after_sec + 10.0:
				# Если во дворе/на улице нет кандидатов для испуга или ложной тревоги,
				# даём естественную передышку, чтобы напряжение и музыка не висели вечно на 100%.
				tension = maxf(tension - 45.0, 15.0)
				cooldown_left = 35.0
				_peak_time = 0.0
				phase = Phase.RELAX
				_log("пик без кандидатов: естественная разрядка")
		Phase.RELAX:
			tension = minf(tension + rate * 0.25 * delta, 100.0)
			cooldown_left -= delta
			if cooldown_left <= 0.0:
				phase = Phase.BUILD
				_log("передышка окончена")

	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	var ctx := make_context()
	if _try_beats(ctx):
		return
	if phase == Phase.PEAK:
		# Пик сначала предлагаем охотнику (осада дома): если он берёт момент — испуг из пула не ставим
		if Game.hunter_brain != null and bool(Game.hunter_brain.call(&"offer_peak")):
			return
		_try_pool(ctx)


func _compute_rate() -> float:
	var m := 1.0
	if Game.is_dark():
		m *= 1.4 if Game.night == 1 else 1.8
	if Game.is_outside():
		m *= 1.2 if Game.night == 1 else 1.5
	if Game.activity == &"radio":
		m *= 1.3
	if Game.after_hour(3):
		m *= 1.3
	return base_rate * m


# --- Выбор испуга ------------------------------------------------------------

func _try_beats(ctx: ScareContext) -> bool:
	for def in _pool:
		if not def.is_beat or not def.fits_night(Game.night) or _uses.has(def.id):
			continue
		if ctx.minute < def.beat_from_min:
			continue
		var overdue := ctx.minute >= def.beat_to_min
		# В окне ждём удачного контекста и конца передышки; к концу окна — форсируем.
		if overdue or (phase != Phase.RELAX and def.matches(ctx)):
			if _trigger(def, ctx, overdue):
				return true
	return false


func _try_pool(ctx: ScareContext) -> void:
	var candidates: Array[ScareDef] = []
	var weights := PackedFloat32Array()
	for def in _pool:
		if def.is_beat or def.type == ScareDef.Type.FAKE or not _available(def):
			continue
		if def.type == ScareDef.Type.HARD and _hard_count >= max_hard_per_night:
			continue
		if tension < def.min_tension or not def.matches(ctx):
			continue
		var w := def.weight
		if debt >= 3 and def.id == &"house_guest":
			w *= 2.5
		if def.type == _last_type:
			w *= 0.3
		if def.creature != &"none" and def.creature == _last_creature:
			w *= 0.4
		candidates.append(def)
		weights.append(w)

	# Пробуем в порядке взвешенного рандома: если постановка сейчас невозможна — следующий.
	while not candidates.is_empty():
		var i := Game.rng.rand_weighted(weights)
		if _trigger(candidates[i], ctx, false):
			return
		candidates.remove_at(i)
		weights.remove_at(i)

	if _peak_time >= fake_after_sec:
		_try_fake(ctx)


func _try_fake(ctx: ScareContext) -> void:
	for def in _pool:
		if def.type == ScareDef.Type.FAKE and _available(def) and def.fits_night(Game.night) and def.matches(ctx):
			if _trigger(def, ctx, false):
				return


func _available(def: ScareDef) -> bool:
	if not def.fits_night(Game.night):
		return false
	var extra := 1 if debt >= 3 and def.id in [&"house_guest", &"house_change"] else 0
	if def.max_per_run > 0 and int(_uses.get(def.id, 0)) >= def.max_per_run + extra:
		return false
	return true


func _trigger(def: ScareDef, ctx: ScareContext, forced: bool) -> bool:
	if def.event_script == null:
		push_error("ScareDef %s: нет event_script" % def.id)
		return false
	var ev := def.event_script.new() as ScareEvent
	if ev == null:
		push_error("ScareDef %s: event_script не наследует ScareEvent" % def.id)
		return false
	ev.def = def
	ev.ctx = ctx
	Game.level.add_child(ev)
	if not ev.can_stage():
		ev.queue_free()
		return false

	phase = Phase.PLAYING
	_uses[def.id] = int(_uses.get(def.id, 0)) + 1
	if def.type == ScareDef.Type.HARD:
		_hard_count += 1
		Game.add_fatigue(5.0)
	scares_played += 1
	_log("▶ %s [%s]%s  t=%.0f  %s" % [def.id, ScareDef.type_name(def.type), " ФОРС" if forced else "", tension, ctx.describe()])
	EventBus.scare_started.emit(def.id)
	ev.finished.connect(_on_scare_finished.bind(def), CONNECT_ONE_SHOT)
	ev.run()
	return true


func _on_scare_finished(def: ScareDef) -> void:
	_last_type = def.type
	_last_creature = def.creature
	tension = maxf(tension - def.tension_release, 0.0)
	cooldown_left = def.cooldown_sec
	_peak_time = 0.0
	phase = Phase.RELAX
	_log("■ %s, передышка %.0f с" % [def.id, def.cooldown_sec])
	EventBus.scare_finished.emit(def.id)


func _on_radio_locked(signal_id: StringName) -> void:
	if signal_id in [&"mainland", &"beacon", &"control"]:
		return   # рабочие частоты — не страшно
	add_tension(12.0, "пойман сигнал %s" % signal_id)


# --- Загрузка и лог ----------------------------------------------------------

func _load_pool() -> void:
	var dir := DirAccess.open(POOL_DIR)
	if dir == null:
		push_error("Director: нет папки %s" % POOL_DIR)
		return
	for file: String in dir.get_files():
		# В экспортированной сборке файлы могут называться *.tres.remap
		var path := POOL_DIR + file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var res := load(path) as ScareDef
		if res != null:
			_pool.append(res)
	_log("пул: %d испугов" % _pool.size())


func _log(msg: String) -> void:
	var line := "[%s] %s" % [Game.clock_text(), msg]
	log_lines.append(line)
	if log_lines.size() > MAX_LOG:
		log_lines.remove_at(0)
	print("[Director] ", line)
