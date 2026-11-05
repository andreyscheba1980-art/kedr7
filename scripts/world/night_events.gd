class_name NightEvents
extends Node
## Сценарные события ночей: Обмирало стучит в дверь (глазок, голоса знакомых), ложный приказ
## «Большой Земли», поломка генератора, Полуночница, дверь настежь, последний зов ночи 7 и выбор концовки.
## Расписание — в Phases.NIGHTS (ключи knocks, false_order, gen_break, paralysis, door_blow, finale).

const KNOCK := "res://assets/audio/door_knock.ogg"
const STINGER := "res://assets/audio/sub_drop.ogg"
const SCREAM := "res://assets/audio/scream.ogg"
const VOICE := "res://assets/audio/voice_mainland.ogg"
const GUST := "res://assets/audio/gust.ogg"
const HEART := "res://assets/audio/heart_loop.ogg"
const WHISPER := "res://assets/audio/whisper.ogg"
const DOOR_POS := Vector3(14.55, 1.3, 3.1)
const PORCH := Vector3(15.8, 0.0, 3.1)
const RADIO_POS := Vector3(9.2, 1.0, -1.4)
const FINAL_CALL_MIN := 420           ## 03:00
const N3_KNOCK_MIN := 540             ## 05:00

var knocking := false
var obmiralo: CreatureRig             ## двойник у крыльца, пока стучит (имя осталось от прежнего гостя)
var paralysis := false

var _cfg: Dictionary
var _knocks: Array = []
var _opened := false
var _order_state := 0                 ## 0 — нет, 1 — приказ отдан, 2 — сработал/прошёл
var _order_min := 0
var _done: Dictionary = {}
var _ending := false
var _presses := 0
var _call_t := 0.0
var _call_i := 0
var _echo_heard := false
var _random: Array = []               ## [[минута, id], ...] — случайные события этой ночи
var _discover: Array = []             ## [{pos|zone, text}] — что игрок найдёт сам
var orders: RadioOrders               ## приказы по рации: настоящие и ложные

const DOOR_MEM_VOICE := {"obeyed_fake": &"door_mem_obey", "after3_tx": &"door_mem_answer", "turned": &"door_mem_turn", "out_after3": &"door_mem_out"}
const RANDOM_POOL: Array[StringName] = [&"trail", &"leak", &"old_call", &"porch", &"wolves", &"stove_out"]
const WOLF := "res://assets/audio/wolf_howl.ogg"


func _ready() -> void:
	Game.events = self
	_cfg = Game.cfg
	_knocks = (_cfg.get("knocks", []) as Array).duplicate()
	if _cfg.get("finale", &"") == &"door_knock":
		_knocks.append(N3_KNOCK_MIN)
	# С чекпоинта: всё, что по расписанию было раньше, уже случилось.
	if Game.resumed:
		var now := int(Game.shift_minutes)
		_knocks = _knocks.filter(func(m: Variant) -> bool: return int(m) > now)
		for key in ["false_order", "gen_break", "paralysis", "door_blow", "radio_ghost", "roof_steps", "roll_call", "underfloor", "lights"]:
			if _cfg.has(key) and int(_cfg[key]) <= now:
				_done[key] = true
	orders = RadioOrders.new()
	add_child(orders)
	add_child(RadioTalks.new())          # сеансы связи с выбором реплик (Зоя, Михалыч)
	Net.remote_ending.connect(_on_remote_ending)
	if Game.is_day() and not Game.is_prologue():
		_morning_call()
	_roll_random()
	_roll_accidents()
	EventBus.clock_minute.connect(_on_minute)
	EventBus.door_opened.connect(_on_door_opened)
	EventBus.zone_changed.connect(_on_zone)
	EventBus.ending_chosen.connect(_on_ending_chosen)
	EventBus.radio_locked.connect(_on_radio_locked)
	EventBus.zimnik_reached.connect(_on_zimnik)


var _discover_cd := 0.0


func _process(delta: float) -> void:
	_check_discover(delta)
	_tick_footprints(delta)
	if not Game.final_call or _ending or Game.dead or Game.dying:
		return
	# Последний зов: рация зовёт по имени снова и снова.
	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = 24.0
		_call_i += 1
		var line := Loc.t(StringName("call.%d" % (1 + _call_i % 4)))
		var call_voice := Voice.or_fallback(StringName("call_%d" % (1 + _call_i % 4)), VOICE)
		# Каждый третий зов — про то, как ты провёл эти ночи.
		if _call_i % 3 == 2:
			var mem := _call_memory()
			if not mem.is_empty():
				line = Loc.t(mem[1])
				call_voice = Voice.or_fallback(mem[0], VOICE)
		if Game.radio != null:
			Game.radio.play_transmission(call_voice, 2.0)
		else:
			Game.audio.play_3d(VOICE, RADIO_POS, 2.0, 4.0)
		if Game.is_home():
			Game.hud.subtitle(Loc.t(&"semenov.near", [line]), 5.0)
		elif Game.player.global_position.distance_to(DOOR_POS) < 25.0:
			Game.hud.subtitle(Loc.t(&"hal.radio_far"), 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if paralysis and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"move_forward") \
			or (event is InputEventMouseButton and event.is_pressed())):
		_presses += 1


func _busy() -> bool:
	# Забитый дымоход при горящей печи — авария, которую чинят только снаружи: стук сейчас был бы ловушкой без выхода.
	if Game.chimney_iced and Game.stove_wood > 0.0:
		return true
	return knocking or paralysis or _ending or Game.dead or Game.dying or Game.shift_over \
		or Director.phase == Director.Phase.PLAYING or (Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE) \
		or (Game.radio != null and (Game.radio._busy or Game.radio.is_voice_busy()))


# --- Расписание --------------------------------------------------------------

func _on_minute(m: int) -> void:
	if _ending or Game.dead or Game.shift_over or not Game.is_night():
		return
	var final_knock: bool = _cfg.get("finale", &"") == &"door_knock"
	# Страховка ночи 3: если гость так и не постучал (дверь была открыта, игрок занят) — утро всё равно наступит.
	if final_knock and m >= 598 and not knocking and not _done.get("n3_morning", false):
		_done["n3_morning"] = true
		_knocks.clear()
		Game.end_shift()
		return
	# Стук: ждём, пока игрок дома (снаружи он бы встретил гостя лицом к лицу).
	# Дверь распахнута — гость не стучит в открытую: ждёт, пока закроют (правило 8 должно иметь смысл).
	if not _knocks.is_empty() and m >= int(_knocks[0]) and not _busy() and not Game.level.door_open:
		var is_final: bool = final_knock and int(_knocks[0]) == N3_KNOCK_MIN
		if Game.is_home():
			_knocks.pop_front()
			_knock_sequence(is_final)
		elif is_final and m >= 590:
			_knocks.pop_front()
			Game.end_shift()               # так и не вернулся в дом — утро наступает без гостя
		elif not is_final and m > int(_knocks[0]) + 80:
			_knocks.pop_front()
	if not _random.is_empty() and m >= int(_random[0][0]) and not _busy():
		var ev: Array = _random.pop_front()
		_random_event(ev[1])
	_once(m, "false_order", _false_order, func() -> bool: return not _busy())
	_once(m, "gen_break", _gen_break, func() -> bool: return not _busy())
	_once(m, "paralysis", _paralysis, func() -> bool:
		return not _busy() and Game.zone == &"room" and Game.player.mode == Player.Mode.WALK)
	_once(m, "radio_ghost", _radio_ghost, func() -> bool: return not _busy())
	_once(m, "roof_steps", _roof_steps, func() -> bool: return not _busy() and Game.is_home())
	_once(m, "roll_call", _roll_call, func() -> bool: return not _busy() and Game.is_home())
	_once(m, "underfloor", _underfloor, func() -> bool: return not _busy() and Game.is_home() and Game.zone != &"vestibule")
	_once(m, "lights", _lights, func() -> bool: return not _busy())
	_once(m, "door_blow", _door_blow, func() -> bool:
		return not _busy() and Game.is_home() and not Game.level.door_open)
	if _order_state == 1 and m >= _order_min + 25:
		_order_state = 2
		if Game.radio != null:
			Game.radio.play_transmission(VOICE, 0.0, Radio.Pass.FAKE)
		else:
			Game.audio.play_3d(VOICE, RADIO_POS, 0.0, 4.0)
		Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"order.3")]) if Game.is_home() else Loc.t(&"hal.radio_far"), 5.0)
		Game.add_fatigue(6.0)
	_run_accidents(m)

	if _cfg.get("finale", &"") == &"choice":
		if m >= FINAL_CALL_MIN and not Game.final_call:
			_start_final_call()
		if m >= 600 and not _ending:
			_on_ending_chosen(&"silence")


# --- Ночные аварии и тревоги -------------------------------------------------
## Каждую ночь — своя небольшая выборка, а не всё подряд в одни и те же минуты.
## «Работа» (анемометр, мачта, дымоход, солярка) — одна за ночь;
## «атмосфера» (маяк, зов из метели, удар в окно) — 2 из 3. Окна времени подобраны так,
## чтобы авария имела смысл: лёд на мачте и анемометре — до сводки 02:00, а не после.

var _accidents: Array = []            ## [[минута, id, конец окна], ...]

const ACCIDENT_WORK := {
	&"anemo": [250, 330, 2],
	&"mast_ice": [250, 335, 2],
	&"chimney": [270, 500, 3],
	&"fuel_sputter": [260, 520, 3],
}
const ACCIDENT_ATMO := {
	&"beacon_blackout": [300, 540, 2],
	&"blizzard_voice": [300, 540, 2],
	&"window_thud": [380, 540, 2],
}


func _roll_accidents() -> void:
	if not Game.is_night() or Game.night < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 919
	var work: Array = []
	for id: StringName in ACCIDENT_WORK:
		var w: Array = ACCIDENT_WORK[id]
		if Game.night < int(w[2]):
			continue
		if id == &"mast_ice" and bool(_cfg.get("antenna_ice", false)):
			continue          # в эту ночь мачта и так обледенеет по расписанию Game
		work.append(id)
	_shuffle(work, rng)
	var n_work := 1        # одна авария за ночь — плюс один наряд Большой Земли (NightTasks)
	var taken: Array[int] = []
	for id: StringName in work:
		if taken.size() >= n_work:
			break
		var w: Array = ACCIDENT_WORK[id]
		for attempt in range(8):
			var at := rng.randi_range(int(w[0]), int(w[1]) - 20)
			var ok := true
			for t in taken:
				if absi(t - at) < 30:
					ok = false
			if ok:
				taken.append(at)
				_accidents.append([at, id, int(w[1]) + 40])
				break
	var atmo: Array = ACCIDENT_ATMO.keys()
	_shuffle(atmo, rng)
	for i in range(2):
		var w: Array = ACCIDENT_ATMO[atmo[i]]
		_accidents.append([rng.randi_range(int(w[0]), int(w[1])), atmo[i], int(w[1]) + 30])
	var now := int(Game.shift_minutes)
	_accidents = _accidents.filter(func(e: Array) -> bool: return int(e[0]) > now)
	_accidents.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _run_accidents(m: int) -> void:
	# Тревога о нехватке солярки — не авария, а напоминание, если запас и правда мал.
	if m >= 380 and not _done.get("fuel_alert_late", false) and not _busy():
		_done["fuel_alert_late"] = true
		_trigger_late_fuel_alert()
	if _accidents.is_empty() or m < int(_accidents[0][0]):
		return
	var e: Array = _accidents[0]
	if m > int(e[2]):
		_accidents.pop_front()         # окно прошло — не судьба
		return
	if _busy() or (_order_state == 1 and m - _order_min < 15):
		return                         # подождём: не перебиваем стук, приказ, паралич
	match e[1]:
		&"chimney":
			if Game.stove_wood <= 0.0:
				return                 # печь не горит — дымить нечему, попробуем позже
			_trigger_chimney_iced()
		&"anemo":
			_trigger_anemo_iced()
		&"mast_ice":
			if Game.antenna_iced or Game.final_call or Game.reports_sent >= Game.report_times().size():
				_accidents.pop_front()
				return
			_trigger_late_mast_emergency()
		&"fuel_sputter":
			if not Game.power_on or Game.gen_broken:
				return
			_trigger_fuel_sputter()
		&"beacon_blackout":
			_trigger_beacon_blackout()
		&"blizzard_voice":
			_trigger_blizzard_voice()
		&"window_thud":
			_trigger_window_thud()
	_accidents.pop_front()


func _trigger_late_fuel_alert() -> void:
	if Game.generator_fuel < 35.0 and Game.canisters_left > 0:
		if Game.is_home():
			Game.audio.play_3d("res://assets/audio/buzzer_loop.ogg", Vector3(9.6, 1.1, -1.4), -2.0, 6.0)   # сигнализация на пульте рубки
			Game.hud.subtitle(Loc.t(&"sub.shed_fuel_needed"), 5.0)
		Director.add_tension(8.0, "нехватка топлива")


func _trigger_anemo_iced() -> void:
	Game.set_anemo_iced(true)
	Game.audio.play_3d("res://assets/audio/ice_hit.ogg", Vector3(55.8, 1.8, -34.0), 1.0, 15.0)   # флюгер на метеоплощадке
	Game.hud.subtitle(Loc.t(&"sub.anemo_iced"), 5.5, 2)
	Director.add_tension(12.0, "обледенение анемометра")


func _trigger_chimney_iced() -> void:
	if Game.stove_wood > 0.0:
		Game.set_chimney_iced(true)
		Game.audio.play_3d("res://assets/audio/gust.ogg", Vector3(-1.5, 2.0, 1.0), 3.0, 10.0)
		Game.audio.play_2d("res://assets/audio/cough.ogg", 0.0)
		Game.hud.subtitle(Loc.t(&"sub.chimney_iced"), 5.5, 2)
		Director.add_tension(16.0, "забило дымоход печи")


func _trigger_fuel_sputter() -> void:
	if Game.power_on and not Game.gen_broken:
		Game.set_fuel_sputter(true)
		Game.hud.subtitle(Loc.t(&"sub.fuel_sputter"), 6.0, 2)
		Director.add_tension(16.0, "загустение солярки в ГСМ")


func _trigger_late_mast_emergency() -> void:
	Game.set_antenna_iced(true)
	Game.audio.play_2d("res://assets/audio/static_loop.ogg", -8.0, 3.0).seek(8.5)   # сразу шумная часть, 3 с
	Game.hud.subtitle(Loc.t(&"sub.mast_emergency"), 5.0, 2)
	Director.add_tension(12.0, "авария на мачте в буране")


func _trigger_blizzard_voice() -> void:
	var p_pos := Game.player.global_position if Game.player != null else Vector3.ZERO
	var src := p_pos + Vector3(-14.0, 1.5, 18.0)
	Game.audio.play_3d(WHISPER, src, 3.0, 14.0)
	Game.hud.subtitle(Loc.t(&"sub.voice_blizzard"), 5.5)
	Director.add_tension(12.0, "зов из метели")


func _trigger_window_thud() -> void:
	var win_pos := Vector3(9.2, 1.45, -2.0)
	Game.audio.play_3d("res://assets/audio/ice_hit.ogg", win_pos, 0.0, 12.0)
	if Game.is_home():
		Game.hud.subtitle(Loc.t(&"sub.window_thud"), 3.5)
		if Game.player != null:
			Game.player.shake(0.03, 0.25)
	Director.add_tension(10.0, "удар в окно")


func _trigger_beacon_blackout() -> void:
	if Game.level != null and Game.level.has_method(&"trigger_beacon_blackout"):
		Game.level.trigger_beacon_blackout(6.0)
	Director.add_tension(14.0, "отказ штормового маяка")


## Событие с расписанием: срабатывает один раз, когда пришло время и позволяют условия.
func _once(m: int, key: String, action: Callable, ready: Callable) -> void:
	if not _cfg.has(key) or _done.has(key):
		return
	var at := int(_cfg[key])
	if m < at:
		return
	if m > at + 120:
		_done[key] = true
		return
	if bool(ready.call()):
		_done[key] = true
		action.call()


# --- Случайные события ночи --------------------------------------------------

func _roll_random() -> void:
	if not Game.is_night():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 313
	var pool: Array = [&"trail", &"wolves"] if Game.night == 1 else RANDOM_POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var count := 1 if Game.night == 1 else 2
	var now := int(Game.shift_minutes)
	for i in range(count):
		var at := rng.randi_range(150, 520)
		if at > now + 5:
			_random.append([at, pool[i]])
	_random.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))


func _random_event(id: StringName) -> void:
	match id:
		&"trail":
			# Босые следы из леса к новой поленнице и дальше — к северному окну дома.
			Game.yard.spawn_trail([Vector3(-12.0, 0, 46.0), Vector3(4.0, 0, 40.0), Vector3(10.0, 0, 26.0), Vector3(14.0, 0, 12.0), Vector3(19.5, 0, 6.0), Vector3(19.5, 0, -3.0), Vector3(12.0, 0, -3.2), Vector3(9.2, 0, -2.6)])   # вокруг дома, не сквозь стены
			_discover.append({"pos": Vector3(4.0, 0, 40.0), "r": 5.0, "text": &"rnd.trail"})
		&"leak":
			if Game.canisters_left > 1:
				Game.canisters_left -= 1
				_discover.append({"zone": &"shed", "text": &"rnd.leak"})
		&"old_call":
			var f := float(Game.rng.randi_range(310, 880)) * 10.0
			for _try in range(20):
				if Signals.is_free(f):
					break
				f = float(Game.rng.randi_range(310, 880)) * 10.0
			if Game.radio != null:
				Game.radio.add_dynamic(&"old_call", f)
			if Game.is_home():
				Game.hud.subtitle(Loc.t(&"rnd.old_call"), 4.0)
			get_tree().create_timer(60.0, false).timeout.connect(func() -> void:
				if Game.radio != null and is_instance_valid(Game.radio):
					Game.radio.remove_dynamic(&"old_call")
			)
		&"porch":
			Game.yard.spawn_porch_item()
			_discover.append({"pos": Vector3(15.5, 0, 3.0), "r": 2.2, "text": &"rnd.porch", "outside": true})
		&"wolves":
			for i in range(3):
				var a := Game.rng.randf() * TAU
				Game.audio.play_3d(WOLF, Game.player.global_position + Vector3(cos(a), 0.1, sin(a)) * Game.rng.randf_range(18.0, 30.0), 2.0, 9.0)
				await _wait(Game.rng.randf_range(0.8, 2.0))
			if Game.yrka != null:
				Game.yrka.threat = minf(Game.yrka.threat + 20.0, 90.0)
			Director.add_tension(12.0, "волки рядом")
		&"stove_out":
			if Game.stove_wood > 5.0:
				Game.stove_wood = 0.0
				if Game.is_home():
					Game.hud.subtitle(Loc.t(&"rnd.stove_out"), 4.5)
				Director.add_tension(8.0, "печь погасла")


func _check_discover(delta: float) -> void:
	if _discover.is_empty() or Game.player == null:
		return
	_discover_cd -= delta
	if _discover_cd > 0.0:
		return
	_discover_cd = 0.25
	var p := Game.player.global_position
	var is_out := Game.is_outside()
	var i := _discover.size() - 1
	while i >= 0:
		var d: Dictionary = _discover[i]
		var hit := false
		if d.has("zone"):
			hit = Game.zone == d["zone"]
		else:
			var target_pos: Vector3 = d["pos"]
			var r: float = float(d["r"])
			hit = Vector2(p.x - target_pos.x, p.z - target_pos.z).length_squared() < (r * r)
			if d.get("outside", false) and not is_out:
				hit = false
		if hit:
			_discover.remove_at(i)
			Game.hud.subtitle(Loc.t(d["text"]), 5.0)
			Director.add_tension(6.0, "находка")
			Game.add_fatigue(3.0)
		i -= 1


# --- Двойник у двери: стучит, говорит голосами, в глазке — каждую ночь чуть не так ----

func _knock_sequence(is_final: bool) -> void:
	knocking = true
	_opened = false
	Director.hold = true
	Game.audio.silence(true)
	obmiralo = Creatures.make_silhouette()
	Game.level.add_child(obmiralo)
	obmiralo.global_position = PORCH
	obmiralo.look_at(Vector3(14.55, 0.0, 3.1), Vector3.UP)
	var n := Game.night
	var lines: Array[StringName] = []
	if is_final:
		lines = [&"fin.knock1", &"fin.knock2", &"fin.knock3", &"fin.knock4", &"fin.knock5"]
	else:
		for i in range(1, 5):
			lines.append(StringName("knock%d.%d" % [n, i]))
		# Голос за дверью помнит прошлые ночи — один раз за ночь, перед последней репликой.
		var worst := NightMemory.worst()
		if worst != &"" and not _done.get("door_mem", false):
			_done["door_mem"] = true
			lines.insert(3, StringName("door.mem." + String(worst)))
		# Соль на пороге: гость не может встать на крыльцо — две реплики, и уходит.
		if Game.salt_on_threshold:
			lines = lines.slice(0, 2)
			Rituals.worked(&"salt")
	for i in range(lines.size()):
		if _opened or Game.dead or Game.dying:
			return
		# Реплика с голосом (если записан): «knock4.2» → door_4_2, «fin.knock3» → door_fin_3.
		var key := String(lines[i])
		var vid := StringName(("door_fin_" + key.right(1)) if key.begins_with("fin.") else ("door_" + key.replace("knock", "").replace(".", "_")))
		if key.begins_with("door.mem."):
			vid = DOOR_MEM_VOICE.get(key.trim_prefix("door.mem."), &"")
		if Voice.has(vid):
			_obm_pose(&"lean", 4.5)          # приник к двери и говорит в щель
			await _wait(0.3)
			Game.audio.say(vid, PORCH + Vector3(0, 1.6, 0), 3.0, 4.0)
		else:
			# Оффбит-ритм в 3 удара: стук ... стук-стук (клип knock бьёт в те же доли)
			_obm_pose(&"knock", 2.1)
			await _wait(0.33)
			Game.audio.play_3d(KNOCK, DOOR_POS, 4.0, 3.8)
			await _wait(0.42)
			Game.audio.play_3d(KNOCK, DOOR_POS, 3.8, 4.2)
			await _wait(0.18)
			Game.audio.play_3d(KNOCK, DOOR_POS, 4.2, 3.9)
		Game.hud.subtitle(Loc.t(lines[i]), 5.0)
		if not is_final and Game.salt_on_threshold and i == lines.size() - 1:
			await _wait(4.0)
			Game.hud.subtitle(Loc.t(&"sub.salt_knock"), 4.0)
		if is_final and i == 2 and SaveGame.decoded.has(&"code"):
			await _wait(3.0)
			Game.hud.subtitle(Loc.t(&"fin.decoded_thought"), 4.0)
			await _wait(4.0)
		else:
			await _wait(7.0)
	if _opened or Game.dead or Game.dying:
		return
	await _wait(3.0)
	if _opened or Game.dead or Game.dying:
		return
	if is_instance_valid(obmiralo):
		obmiralo.queue_free()
	obmiralo = null
	Game.audio.play_2d(WHISPER, -4.0)
	Game.hud.subtitle(Loc.t(&"fin.whisper") if is_final else Loc.t(&"knock.leave"), 4.5)
	Game.audio.silence(false)
	Director.hold = false
	Director.add_tension(-20.0, "стук прекратился")
	Game.add_fatigue(5.0)
	knocking = false
	if is_final:
		await _wait(5.0)
		Game.hud.subtitle(Loc.t(&"end.stayed"), 6.0)
		await _wait(4.0)
		Game.end_shift()


## «Зенит-Е»: вспышка в щель двери — подражатель отшатывается, как от верного отзыва.
func repel_knock_with_flash() -> void:
	repel_knock_with_countersign(&"sub.obmiralo_flash")


## Изгнание имитатора верным отзывом из дневника Семёнова
func repel_knock_with_countersign(sub_key := &"sub.obmiralo_counter_success") -> void:
	if not knocking or _opened:
		return
	knocking = false
	if is_instance_valid(obmiralo):
		obmiralo.queue_free()
	obmiralo = null
	# Скрежет когтей о косяк двери и удаляющиеся тяжёлые шаги в метель
	Game.audio.play_3d("res://assets/audio/ice_hit.ogg", DOOR_POS, 2.0, 3.0)
	Game.audio.play_3d("res://assets/audio/gust.ogg", DOOR_POS + Vector3(2.5, 0, 0), -2.0)
	Game.audio.play_2d(WHISPER, -4.0)
	Game.hud.subtitle(Loc.t(sub_key), 4.5)
	Game.audio.silence(false)
	Director.hold = false
	Director.add_tension(-25.0, "отзыв отогнал гостя от двери")


func _on_door_opened() -> void:
	if not knocking or _opened:
		return
	_opened = true
	Game.dying = true
	Game.clock_running = false
	Game.player.mode = Player.Mode.LOCKED
	await _wait(0.5)
	Game.audio.play_2d(SCREAM, 2.0)
	if is_instance_valid(obmiralo):
		obmiralo.twitch = 3.0
		await Game.player.death_fall(obmiralo, -35.0, 1.6)
	Game.die(&"obmiralo")


## Скелетный гость: на время стука/реплики — клип, потом снова стоит (idle/still).
func _obm_pose(clip: StringName, dur: float) -> void:
	if not is_instance_valid(obmiralo) or not obmiralo.has_clip(clip):
		return
	var o := obmiralo
	o.pose_override = clip
	await _wait(dur)
	if is_instance_valid(o) and o.pose_override == clip:
		o.pose_override = &""


## Поза гостя для глазка — каждую ночь что-то не так.
func peep_pose() -> void:
	if not is_instance_valid(obmiralo):
		return
	var head := obmiralo.pivot(&"Head")
	match Game.night:
		4:
			obmiralo.global_position = PORCH
		5:
			obmiralo.global_position = Vector3(14.85, 0.0, 3.1)   # вплотную к двери
		6:
			obmiralo.global_position = PORCH + Vector3(0.1, 0.0, 0.1)
			if head != null:
				obmiralo.set_rest(&"Head", Vector3(0.0, 0.0, deg_to_rad(80.0)))   # голова лежит на плече
		_:
			obmiralo.global_position = PORCH
	obmiralo.look_at(Vector3(14.55, obmiralo.global_position.y, 3.1), Vector3.UP)


# --- Ложный приказ (ночь 4) --------------------------------------------------

func _false_order() -> void:
	_order_state = 1
	NightMemory.mark(&"heard_fake")
	_order_min = int(Game.shift_minutes)
	var v1 := Voice.or_fallback(&"ml_order_1", VOICE)
	if Game.radio != null:
		Game.radio.play_transmission(v1, 2.0, Radio.Pass.FAKE)
	else:
		Game.audio.play_3d(v1, RADIO_POS, 2.0, 4.0)
	if Game.is_home():
		Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"order.1")]), 5.5)
		await _wait(6.0)
		if Voice.has(&"ml_order_2") and Game.radio != null:
			Game.radio.play_transmission(Voice.path(&"ml_order_2"), 2.0, Radio.Pass.FAKE)
		Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"order.2")]), 5.5)
	else:
		Game.hud.subtitle(Loc.t(&"hal.radio_far"), 4.0)


func _on_zone(z: StringName) -> void:
	if _order_state == 1 and z == &"mast":
		# Законный повод быть у мачты (наряд на щиток, обледенение антенны) ловушку не включает.
		if Game.antenna_iced or (Game.tasks != null and Game.tasks.is_active(&"mast_lamp")):
			return
		_order_state = 2
		NightMemory.mark(&"obeyed_fake")
		Game.hud.subtitle(Loc.t(&"order.trap"), 4.0)
		await _wait(2.5)
		if Game.yrka != null and not Game.dead:
			Game.yrka.enabled = true
			Game.yrka.force_chase()


# --- Фирменные сцены ночей 1–2 -----------------------------------------------

## Ночь 1, 01:00: рация в рубке сама уходит со своей частоты — треск, и голос Семёнова.
func _radio_ghost() -> void:
	Director.hold = true
	Game.audio.trigger_vacuum(2.5)
	Game.audio.play_3d("res://assets/audio/static_loop.ogg", RADIO_POS, 2.0, 6.0, 1.6)
	await _wait(1.4)
	var lines := [&"sig.semenov.1", &"sig.semenov.2", &"sig.semenov.3"]
	var vpath := Voice.path(&"sem_log_1")
	# Голос идёт «через рацию» (как передача), но не дольше 8 с — потом эфир снова свободен.
	if Game.radio != null:
		Game.radio.play_transmission(vpath if vpath != "" else "res://assets/audio/voice_loop.ogg", 0.0)
	get_tree().create_timer(8.0 if vpath == "" else 30.0, false).timeout.connect(func() -> void:
		if Game.radio != null and is_instance_valid(Game.radio) and Game.radio.is_voice_busy():
			Game.radio.stop_transmission())
	for k in lines:
		if Game.is_home():
			Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(k)]), 2.6, 2)
		await _wait(2.6)
	if not Game.is_home():
		Game.hud.subtitle(Loc.t(&"hal.radio_far"), 3.0)
	Game.audio.play_3d("res://assets/audio/static_loop.ogg", RADIO_POS, 0.0, 6.0, 0.8)
	Director.add_tension(14.0, "рация сама поймала Семёнова")
	Director.hold = false


## Ночь 2, 01:30: по крыше над головой медленно проходит кто-то тяжёлый — от печи к тамбуру.
## Потом с карниза у окна сползает снег. И тишина.
func _roof_steps() -> void:
	Director.hold = true
	Game.audio.trigger_vacuum(4.0)
	var p_pos := Game.player.global_position
	var from := Vector3(-1.5, 4.3, 3.3)
	var to := Vector3(13.5, 4.3, 3.3)
	if p_pos.x > 6.0:
		var tmp := from
		from = to
		to = tmp
	Game.hud.subtitle(Loc.t(&"sub.roof_steps"), 4.0, 2)
	for i in range(9):
		var k := float(i) / 8.0
		var pos := from.lerp(to, k)
		var snd := ""   # sfx roof_steps (гул с редкими щелчками) не похож на шаги — только доски
		if snd != "":
			Game.audio.play_3d(snd, pos, 4.0, 8.0)
			break
		Game.audio.play_3d("res://assets/audio/step_wood_%d.ogg" % (1 + i % 7), pos, -2.0, 7.0)
		if i == 4:
			Game.level.flicker(0.25)
		await _wait(0.85 + Game.rng.randf() * 0.2)
	await _wait(1.2)
	Game.audio.play_3d("res://assets/audio/snow_fall.ogg", Vector3(9.2, 2.6, -2.2), 3.0, 6.0)
	Director.add_tension(16.0, "шаги по крыше")
	Game.add_fatigue(3.0)
	Director.hold = false


# --- Фирменные сцены ночей 3–6 -----------------------------------------------

## Строка эфира: голос (если записан) — дождаться конца; нет голоса — субтитр и пауза.
func _radio_line(vid: StringName, sub_key: StringName, fallback_sec: float, pass_kind := Radio.Pass.NONE) -> void:
	Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(sub_key)]), maxf(fallback_sec, 3.0), 2)
	if Game.radio != null and Voice.has(vid):
		var p := Game.radio.play_transmission(Voice.path(vid), 2.0, pass_kind)
		# Страховка: ждём не дольше длины записи + 3 с — иначе зависший плеер держал бы режиссёра часами.
		var cap := 3.0 + (p.stream.get_length() if p != null and is_instance_valid(p) and p.stream != null else fallback_sec)
		var t := 0.0
		while p != null and is_instance_valid(p) and p.playing and t < cap:
			await get_tree().process_frame
			if not get_tree().paused:
				t += get_process_delta_time()
		await _wait(0.4)
	else:
		if Game.radio != null:
			Game.radio._show_pass(pass_kind, fallback_sec)
		Game.audio.play_3d("res://assets/audio/static_loop.ogg", RADIO_POS, -4.0, 5.0, 0.5)
		await _wait(fallback_sec + (2.8 if pass_kind != Radio.Pass.NONE else 0.0))


## Ночь 3, 01:30 — перекличка. Большая Земля опрашивает станции; на «Кедр-семь?» отвечают раньше тебя.
func _roll_call() -> void:
	Director.hold = true
	Game.audio.play_3d("res://assets/audio/static_loop.ogg", RADIO_POS, 0.0, 5.0, 1.0)
	await _wait(1.2)
	await _radio_line(&"ml_roll_1", &"roll.1", 3.0)
	await _radio_line(&"st_sosna_roll", &"roll.sosna", 2.2)
	await _radio_line(&"ml_roll_2", &"roll.2", 3.5)
	await _wait(2.5)                      # Берёза-пять молчит. Совсем.
	await _radio_line(&"ml_roll_3", &"roll.3", 2.0)
	await _wait(0.6)
	Game.audio.trigger_vacuum(2.5)
	await _radio_line(&"st_kedr7_roll", &"roll.kedr", 3.5)
	await _wait(2.0)
	await _radio_line(&"ml_roll_4", &"roll.4", 5.0, Radio.Pass.REAL)
	Director.add_tension(18.0, "перекличка: за тебя ответили")
	Game.add_fatigue(3.0)
	Director.hold = false


## Ночь 4 — пока ты на улице, через избу проходят босые мокрые следы: от двери к рации и к твоей кровати.
const FOOTPRINT_PATH := [Vector3(14.2, 0, 3.05), Vector3(11.5, 0, 3.15), Vector3(7.9, 0, 3.05), Vector3(7.55, 0, 2.0),
	Vector3(8.4, 0, -0.4), Vector3(7.55, 0, 2.0), Vector3(6.6, 0, 3.2), Vector3(3.5, 0, 3.15), Vector3(0.6, 0, 3.9), Vector3(-0.5, 0, 4.7)]
var _out_t := 0.0
var _prints: Node3D
var _prints_seen := false


func _tick_footprints(delta: float) -> void:
	if not _cfg.has("footprints") or _done.get("footprints", false) or not Game.is_night():
		if _prints != null and _prints_seen:
			_fade_prints(delta)
		return
	if int(Game.shift_minutes) < int(_cfg["footprints"]) or Game.player == null:
		return
	if _prints == null:
		var far := Game.player.global_position.distance_to(DOOR_POS) > 9.0
		_out_t = _out_t + delta if Game.is_outside() and far else 0.0
		if _out_t > 20.0:
			_place_prints()
		return
	if Game.is_home() and not _prints_seen:
		_prints_seen = true
		_done["footprints"] = true
		Game.hud.subtitle(Loc.t(&"scene.footprints"), 5.5, 2)
		var steps := Voice.sfx(&"barefoot_wood")
		if steps != "":
			Game.audio.play_3d(steps, Vector3(0.6, 0.3, 4.2), 0.0, 3.0)
		Director.add_tension(16.0, "босые следы в доме")
		Game.add_fatigue(3.0)


func _place_prints() -> void:
	_prints = Node3D.new()
	_prints.name = "Footprints"
	Game.level.add_child(_prints)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _foot_texture()
	mat.albedo_color = Color(0.025, 0.02, 0.015, 0.92)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.16, 0.34)
	var space := Game.level.get_world_3d().direct_space_state
	var left := true
	for i in range(FOOTPRINT_PATH.size() - 1):
		var a: Vector3 = FOOTPRINT_PATH[i]
		var b: Vector3 = FOOTPRINT_PATH[i + 1]
		var dir := (b - a)
		var seg := dir.length()
		if seg < 0.05:
			continue
		dir /= seg
		var side := Vector3(-dir.z, 0, dir.x)
		var t := 0.0
		while t < seg:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_prints.add_child(mi)
			var pos := a + dir * t + side * (0.1 if left else -0.1)
			pos.y = _floor_y(space, pos) + 0.008
			mi.position = pos
			mi.rotation.y = atan2(dir.x, dir.z) + Game.rng.randf_range(-0.12, 0.12)
			if not left:
				mi.scale.x = -1.0
			left = not left
			t += 0.52


## Высота пола под точкой (лучом вниз); пол избы — на 0.05.
func _floor_y(space: PhysicsDirectSpaceState3D, pos: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.35, 0), pos - Vector3(0, 0.5, 0))
	q.exclude = [Game.player.get_rid()] if Game.player != null else []
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else 0.05


var _print_fade := 1.0


## Следы высыхают за пару минут.
func _fade_prints(delta: float) -> void:
	_print_fade -= delta / 150.0
	if _print_fade <= 0.0:
		_prints.queue_free()
		_prints = null
		return
	var mi := _prints.get_child(0) as MeshInstance3D if _prints.get_child_count() > 0 else null
	if mi != null and mi.material_override is StandardMaterial3D:
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.75 * _print_fade


static var _foot_tex: ImageTexture


## Отпечаток босой ступни: пятка, свод, подушечка и пять пальцев.
static func _foot_texture() -> ImageTexture:
	if _foot_tex != null:
		return _foot_tex
	var w := 16
	var h := 34
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var blobs := [[8.0, 28.0, 4.2, 5.0], [7.0, 20.0, 3.0, 5.0], [8.5, 12.0, 5.5, 4.5],
		[3.5, 5.0, 1.8, 2.0], [6.5, 3.5, 1.6, 1.8], [9.3, 3.6, 1.4, 1.6], [11.8, 4.6, 1.2, 1.4], [13.6, 6.4, 1.0, 1.2]]
	for y in h:
		for x in w:
			var a := 0.0
			for bl: Array in blobs:
				var dx := (float(x) - float(bl[0])) / float(bl[2])
				var dy := (float(y) - float(bl[1])) / float(bl[3])
				a = maxf(a, clampf(1.6 - (dx * dx + dy * dy) * 1.6, 0.0, 1.0))
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, minf(a, 1.0) * (0.75 + randf() * 0.25)))
	_foot_tex = ImageTexture.create_from_image(img)
	return _foot_tex


## Ночь 5, 03:05 — под полом гудит, снизу стучат «три — пауза — три», потом глухо — твоя сводка.
func _underfloor() -> void:
	Director.hold = true
	Game.audio.trigger_vacuum(3.0)
	var under := Game.player.global_position * Vector3(1, 0, 1) + Vector3(0, -0.6, 0)
	var hum := Voice.sfx(&"underfloor_hum")
	Game.audio.play_3d(hum if hum != "" else STINGER, under, 4.0, 6.0)
	Game.hud.subtitle(Loc.t(&"scene.underfloor"), 4.5, 2)
	for i in range(6):
		Game.player.shake(0.012, 0.6)
		if i == 2:
			Game.level.flicker(0.4)
		await _wait(0.7)
	var knock := Voice.sfx(&"knock_floor")
	Game.hud.subtitle(Loc.t(&"scene.underfloor_knock"), 4.0, 2)
	if knock != "":
		Game.audio.play_3d(knock, under, 4.0, 4.0)
		await _wait(3.5)
	else:
		for k in range(7):
			if k == 3:
				await _wait(0.9)
				continue
			Game.audio.play_3d("res://assets/audio/knock.ogg", under, 2.0, 3.0)
			await _wait(0.45)
	await _wait(1.5)
	Game.hud.subtitle(Loc.t(&"scene.underfloor_voice"), 5.5, 2)
	var said := Game.audio.say(&"low_kedr7", under, 0.0, 3.0)
	await _wait(maxf(said, 5.5) + 0.8)
	Game.hud.subtitle(Loc.t(&"scene.underfloor_after"), 4.0, 2)
	Director.add_tension(20.0, "гул под полом")
	Game.add_fatigue(4.0)
	Director.hold = false


## Ночь 6, 02:40 — у старой дороги фары и сигнал вездехода, Михалыч зовёт на помощь. Ночью он не ездит.
const LIGHTS_POS := Vector3(36.0, 0.0, 24.0)   ## у старой дороги к ГСМ — оттуда в прологе пришёл вездеход
var _lights_node: Node3D


func _lights() -> void:
	Director.hold = true
	_lights_node = Node3D.new()
	Game.level.add_child(_lights_node)
	_lights_node.global_position = LIGHTS_POS
	_lights_node.look_at(Vector3(15.8, 0.0, 3.1), Vector3.UP)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.92, 0.7)
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	# Ореол фар в метели — видно издалека, даже когда сами лампы — точки.
	var glare_mat := ShaderMaterial.new()       # круглый ореол (тот же шейдер, что у ламп), не квадрат
	glare_mat.shader = load("res://assets/shaders/halo.gdshader") as Shader
	glare_mat.set_shader_parameter(&"col", Color(1.0, 0.9, 0.7, 0.9))
	var glare := QuadMesh.new()
	glare.size = Vector2(3.2, 3.2)
	for x: float in [-0.75, 0.75]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = sphere
		lamp.material_override = mat
		lamp.position = Vector3(x, 1.1, -0.2)
		_lights_node.add_child(lamp)
		var halo := MeshInstance3D.new()
		halo.mesh = glare
		halo.material_override = glare_mat
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = Vector3(x, 1.1, -0.4)
		_lights_node.add_child(halo)
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 1.1, -0.3)
		spot.spot_range = 40.0
		spot.spot_angle = 22.0
		spot.light_energy = 3.0
		spot.light_color = Color(1.0, 0.9, 0.7)
		_lights_node.add_child(spot)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.3, -1.0)
	glow.omni_range = 9.0
	glow.light_energy = 1.4
	glow.light_color = Color(1.0, 0.9, 0.7)
	_lights_node.add_child(glow)
	var engine := Voice.sfx(&"engine_far")
	var engine_p: AudioStreamPlayer3D = null
	if engine != "":
		engine_p = Game.audio.play_3d(engine, LIGHTS_POS + Vector3(0, 1, 0), 2.0, 14.0)
	var horn := Voice.sfx(&"horn_far")
	if horn != "":
		Game.audio.play_3d(horn, LIGHTS_POS + Vector3(0, 1, 0), 6.0, 20.0)
	Game.hud.subtitle(Loc.t(&"scene.lights"), 5.0, 2)
	await _wait(4.0)
	# Михалыч дал контрольный вопрос (сеанс ночи 4/6) — можно проверить, кто зовёт из метели.
	var asked := false
	if RadioTalks.knows_question() and not Game.dead and not _ending:
		asked = true
		var first := Game.audio.say(&"drv_night_1", LIGHTS_POS + Vector3(0, 1.6, 0), 8.0, 16.0)
		Game.hud.subtitle(Loc.t(&"drv.night1"), maxf(first, 4.0), 2)
		await _wait(maxf(first, 3.0))
		var pick: int = await TalkChoiceUI.ask([Loc.t(&"talk.ask_dog")], 10.0)
		if pick == 0 and not Game.dead:
			Game.hud.subtitle(Loc.t(&"talk.you", [Loc.t(&"talk.ask_dog")]), 3.0, 2)
			await _wait(3.2)
			Game.hud.subtitle(Loc.t(&"talk.dog_wrong"), 3.5, 2)
			await _wait(4.0)
			Game.hud.subtitle(Loc.t(&"talk.dog_after"), 5.0, 2)
			await _wait(4.5)
			if is_instance_valid(engine_p):
				engine_p.queue_free()
			if is_instance_valid(_lights_node):
				_lights_node.queue_free()
			_lights_node = null
			Game.audio.play_3d(SCREAM, LIGHTS_POS + Vector3(0, 1, 0), -6.0, 20.0)
			Game.hud.subtitle(Loc.t(&"talk.dog_gone"), 4.5, 2)
			SaveGame.flags["double_exposed"] = 1
			Achievements.unlock(&"pirat")
			Director.add_tension(-12.0, "двойник разоблачён")
			Director.hold = false
			return
	var lines := [[&"drv_night_1", &"drv.night1"], [&"drv_night_2", &"drv.night2"], [&"drv_night_3", &"drv.night3"]]
	if asked:
		lines.pop_front()            # первую реплику уже сказал до вопроса
	var near := false
	for l: Array in lines:
		if Game.dead or _ending:
			break
		var said := Game.audio.say(l[0], LIGHTS_POS + Vector3(0, 1.6, 0), 8.0, 16.0)
		Game.hud.subtitle(Loc.t(l[1]), maxf(said, 4.0), 2)
		var t := 0.0
		while t < maxf(said, 4.0) + 3.5:
			if Game.player.global_position.distance_to(LIGHTS_POS) < 13.0:
				near = true
				break
			await get_tree().process_frame
			t += get_process_delta_time()
		if near:
			break
	if is_instance_valid(engine_p):
		engine_p.queue_free()
	if is_instance_valid(_lights_node):
		_lights_node.queue_free()
	_lights_node = null
	if near:
		NightMemory.mark(&"obeyed_fake")
		Game.audio.play_2d(STINGER, -2.0)
		Game.hud.subtitle(Loc.t(&"scene.lights_near"), 4.0, 2)
		Director.hold = false
		await _wait(1.5)
		if Game.yrka != null and not Game.dead:
			Game.yrka.enabled = true
			Game.yrka.force_chase()
	else:
		Game.hud.subtitle(Loc.t(&"scene.lights_gone"), 4.5, 2)
		Director.hold = false
	Director.add_tension(18.0, "фары у зимника")


static var _glare_tex: ImageTexture


static func _glare_texture() -> ImageTexture:
	if _glare_tex != null:
		return _glare_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glare_tex = ImageTexture.create_from_image(img)
	return _glare_tex


## Ночь 7: зов знает, как ты провёл эти ночи. [голос, субтитр] или [].
func _call_memory() -> Array:
	if NightMemory.ever(&"after3_tx"):
		return [&"call_mem_answer", &"call.mem.after3_tx"]
	if NightMemory.ever(&"obeyed_fake"):
		return [&"call_mem_obey", &"call.mem.obeyed_fake"]
	if not NightMemory.ever(&"turned") and not NightMemory.ever(&"out_after3"):
		return [&"call_mem_good", &"call.mem.good"]
	return []


## Утро после ночи: Большая Земля вспоминает, как прошла смена. День 6 — Земля молчит, говорит «не она».
func _morning_call() -> void:
	await _wait(9.0)
	var t := 0.0
	while t < 120.0:
		if Game.radio != null and Game.is_home() and not Game.radio.is_voice_busy() and not Game.radio._busy:
			break
		await _wait(1.0)
		t += 1.0
	if Game.radio == null or not Game.is_home() or Game.shift_over:
		return
	if Game.phase_index >= 6:
		Game.radio.play_transmission(Voice.or_fallback(&"mlf_good", VOICE), 0.0, Radio.Pass.FAKE)
		Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"morn.fake_good")]), 6.0)
		return
	var line := NightMemory.morning_line()
	if line.is_empty():
		return
	Game.radio.play_transmission(Voice.or_fallback(line[0], VOICE), 0.0, Radio.Pass.REAL_END)
	Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(line[1])]), 6.5)


# --- Генератор ломается (ночь 5) ---------------------------------------------

func _gen_break() -> void:
	Game.gen_broken = true
	Game.set_power(false)
	Game.audio.play_3d("res://assets/audio/clank.ogg", Vector3(16.9, 0.8, -0.75), 4.0, 6.0)   # дизельная будка
	Game.hud.subtitle(Loc.t(&"sub.gen_broke"), 6.0, 2)
	Director.add_tension(20.0, "генератор сломался")


# --- Дверь настежь (ночь 6) --------------------------------------------------

func _door_blow() -> void:
	Game.audio.play_3d(GUST, DOOR_POS, 6.0, 6.0)
	Game.level.set_door_open(true)
	Game.hud.subtitle(Loc.t(&"sub.door_blown"), 5.0, 2)
	Director.add_tension(25.0, "дверь распахнуло")


# --- Полуночница -------------------------------------------------------------

func _paralysis() -> void:
	paralysis = true
	Director.hold = true
	_presses = 0
	var p := Game.player
	if Game.radio != null and Game.radio.active:
		Game.radio.exit()
	p.mode = Player.Mode.LOCKED
	Game.hud.subtitle(Loc.t(&"par.1"), 3.5)
	await Game.hud.fade_in_screen("", 2.0)
	p.set_physics_process(false)
	var old_head_y := p.head.position.y
	# Кровать в жилой комнате: (-1.4, 0.225, 5.2), изголовье — к южной стене (+Z).
	p.global_position = Vector3(-1.4, 0.45, 5.75)
	p.rotation.y = 0.0
	p.head.position.y = 0.2
	p.head.rotation.x = deg_to_rad(38.0)
	p.camera.rotation.z = deg_to_rad(8.0)
	# В комнате никого не видно — только тень на стене растёт, половицы скрипят ближе, дыхание над ухом.
	# Тень отбрасывает невидимый двойник от тусклого ночника у изголовья.
	var hag := Creatures.make_silhouette()
	hag.twitch = 1.2
	Game.level.add_child(hag)
	for mi: MeshInstance3D in hag.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# Верхний свет гаснет (во сне так и бывает), остаётся керосинка у изголовья — низко, тень встаёт на стену во весь рост
	var was_lit: bool = Game.level.get(&"_lit") == true
	if Game.level.has_method(&"set_lit"):
		Game.level.call(&"set_lit", false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.62, 0.32)
	lamp.light_energy = 2.6
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 0.8
	lamp.shadow_enabled = true
	Game.level.add_child(lamp)
	lamp.global_position = Vector3(-0.9, 0.3, 6.3)
	hag.tree_exiting.connect(func() -> void:
		lamp.queue_free()
		if was_lit and Game.level != null and Game.level.has_method(&"set_lit"):
			Game.level.call(&"set_lit", true))
	var from := Vector3(-1.4, 0.0, 3.2)
	var to := Vector3(-0.55, 0.0, 5.25)
	hag.global_position = from
	hag.look_at(Vector3(-1.4, 0.0, 5.9), Vector3.UP)
	var heart := Game.audio.play_2d(HEART, -2.0, 30.0)
	var breath := Game.audio.play_3d("res://assets/audio/breath_loop.ogg", from + Vector3(0, 1.5, 0), -14.0, 4.0, 30.0)
	var step_at := 0.0
	await Game.hud.fade_out_screen(1.2)
	var need := 12 if Game.is_story() else 16 if Game.is_hard() else 14
	var limit := 14.0 if Game.is_story() else 9.0 if Game.is_hard() else 11.0
	if Game.knife_in_lintel:   # нож в косяке: морок входит в комнату ослабшим — проснуться легче
		Rituals.worked(&"knife")
		need -= 5
		limit += 3.0
	var t := 0.0
	while t < limit and _presses < need and not Game.dead:
		var k := t / limit
		hag.global_position = from.lerp(to, k)
		hag.look_at(p.camera.global_position * Vector3(1, 0, 1), Vector3.UP)
		hag.rotate_object_local(Vector3.RIGHT, deg_to_rad(-40.0 * k))   # склоняется над кроватью
		if t >= step_at:   # половица под каждым шагом, всё ближе и реже
			step_at = t + lerpf(1.1, 2.2, k)
			Game.audio.play_3d("res://assets/sfx/barefoot_wood%s.ogg" % ["", "_v2", "_v3", "_v4"].pick_random(), hag.global_position, lerpf(-8.0, 0.0, k), 6.0)
		if is_instance_valid(breath):
			breath.global_position = hag.global_position + Vector3(0, 1.5 - 0.5 * k, 0)
			breath.volume_db = lerpf(-14.0, -2.0, k)
		Game.hud.subtitle(Loc.t(&"par.2", [_presses, need]), 0.3)
		if randf() < 0.02:
			Game.audio.play_2d(WHISPER, -6.0)
		p.shake(0.004 + k * 0.01, 0.1)
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(heart):
		heart.queue_free()
	if is_instance_valid(breath):
		breath.queue_free()
	var woke := _presses >= need or Game.is_story()
	if not woke:
		Game.audio.play_2d(SCREAM, 2.0)
		await Game.hud.flash_face(0.6)
		Game.hud.set_black(true)
		hag.queue_free()
		paralysis = false
		Game.die(&"noon")
		return
	Game.audio.play_2d(STINGER, -4.0)
	await Game.hud.fade_in_screen("", 0.4)
	hag.queue_free()
	p.global_position = Vector3(-0.4, 0.05, 4.6)
	p.head.position.y = old_head_y
	p.head.rotation.x = 0.0
	p.camera.rotation.z = 0.0
	p.rotation.y = deg_to_rad(-90.0)
	p.set_physics_process(true)
	Game.shift_minutes += 25.0
	Game.add_fatigue(12.0 if _presses < need else 4.0)
	await _wait(1.0)
	await Game.hud.fade_out_screen(1.5)
	Game.hud.subtitle(Loc.t(&"par.woke") if _presses >= need else Loc.t(&"par.story"), 5.0)
	p.mode = Player.Mode.WALK
	paralysis = false
	Director.hold = false


# --- Ночь 7: зов и выбор -----------------------------------------------------

func _start_final_call() -> void:
	Game.final_call = true
	_call_t = 2.0
	Director.add_tension(40.0, "последний зов")
	Game.hud.subtitle(Loc.t(&"call.start"), 7.0)


func _on_radio_locked(id: StringName) -> void:
	if id != &"echo" or _echo_heard or _ending:
		return
	_echo_heard = true
	await _wait(9.0)
	if _ending or Game.dead or Game.radio == null or Game.radio.locked_signal() != &"echo":
		_echo_heard = false
		return
	if Game.secret_ready():
		_on_ending_chosen(&"echo")
	else:
		Game.hud.subtitle(Loc.t(&"echo.not_yet"), 5.0)


func _on_zimnik() -> void:
	if _ending:
		return
	if Game.night == 7 and Game.is_night():
		if not Game.final_call:
			Game.hud.subtitle(Loc.t(&"sub.zimnik_wait"), 4.5)
		elif Game.has_item(&"skis"):
			_on_ending_chosen(&"leave")
		else:
			Game.hud.subtitle(Loc.t(&"sub.zimnik_no_skis"), 4.0)
	else:
		Game.hud.subtitle(Loc.t(&"sub.zimnik_far"), 4.0)


func _on_ending_chosen(id: StringName) -> void:
	if _ending or Game.dead:
		return
	_ending = true
	Director.hold = true
	Net.share_ending(id)   # кооп: выбор одного — концовка для обоих
	get_parent().call(&"play_ending", id)


## Кооп: концовку выбрал напарник — она играет и у нас (даже если мы уже в эфире).
func _on_remote_ending(id: StringName) -> void:
	if _ending:
		return
	_ending = true
	Director.hold = true
	get_parent().call(&"play_ending", id)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout
