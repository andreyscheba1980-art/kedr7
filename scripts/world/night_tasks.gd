class_name NightTasks
extends Node
## Задания Большой Земли между сводками: после сводки на 00:00 приходит наряд на одно дело
## (откопать будку, заменить огонь мачты, долить масло, взять пеленг, принять контрольную группу).
## Срок — до 02:55. Выполнил — меньше усталости; провалил — станцию «отмечают», напряжение растёт.

const VOICE := "res://assets/audio/voice_mainland.ogg"
const RADIO_POS := Vector3(3.15, 1.0, 0.4)
const ISSUE_FALLBACK_MIN := 300       ## 01:00 — если сводку на 00:00 так и не передали
const DEADLINE_MIN := 415             ## 02:55
const BEACON_HOLD := 5.0
const CONTROL_HOLD := 3.0

## Какие дела бывают в какую ночь. В первую — одно, обучающее.
const POOL := {
	1: [&"meteo_dig"],
	2: [&"beacon", &"oil", &"meteo_dig", &"balloon"],
	3: [&"beacon", &"mast_lamp", &"callsign", &"barograph_check"],
	4: [&"mast_ground", &"beacon", &"oil", &"balloon"],
	5: [&"mast_ground", &"callsign", &"mast_lamp", &"barograph_check"],
}
const POOL_LATE: Array[StringName] = [&"beacon", &"mast_lamp", &"callsign", &"oil", &"meteo_dig", &"mast_ground", &"balloon", &"barograph_check"]

var active: Array[StringName] = []    ## выданы и не закрыты
var done: Array[StringName] = []
var beacon_range := Vector2i.ZERO
var control_freq := 0
var control_group := ""
var control_heard := false

var _issued := false
var _closed := false
var _lock_t := 0.0


func _ready() -> void:
	Game.tasks = self
	EventBus.report_sent.connect(_on_report_sent)
	EventBus.clock_minute.connect(_on_minute)
	if Game.resumed and Game.reports_sent >= 1 and Game.shift_minutes < DEADLINE_MIN:
		_issue_later()


func _issue_later() -> void:
	await get_tree().create_timer(8.0, false).timeout
	_issue()


func is_active(id: StringName) -> bool:
	return active.has(id)


func _process(delta: float) -> void:
	if active.is_empty() or Game.radio == null:
		return
	# Пеленг и контрольная группа — за рацией: держать сигнал захваченным.
	var locked := Game.radio.locked_signal() if Game.radio.active else &""
	if locked == &"beacon" and is_active(&"beacon"):
		_lock_t += delta
		if _lock_t >= BEACON_HOLD:
			complete(&"beacon")
	elif locked == &"control" and is_active(&"callsign") and not control_heard:
		_lock_t += delta
		if _lock_t >= CONTROL_HOLD:
			control_heard = true
			Game.hud.subtitle(Loc.t(&"task.control_heard", [control_group]), 5.0)
	else:
		_lock_t = 0.0


# --- Выдача и срок -----------------------------------------------------------

func _on_report_sent(index: int) -> void:
	if index == 0 and not _issued:
		# Большая Земля уже закончила ответ по сводке; даём небольшую паузу в эфире
		await get_tree().create_timer(3.0, false).timeout
		_issue()


func _on_minute(m: int) -> void:
	if not _issued and m >= ISSUE_FALLBACK_MIN and Game.reports_sent == 0:
		_issue()
	if _issued and not _closed and m >= DEADLINE_MIN:
		_close()


func _issue() -> void:
	if _issued or Game.shift_over or Game.dead:
		return
	while Game.radio != null and (Game.radio._busy or Game.radio.is_voice_busy()):
		await get_tree().create_timer(1.0, false).timeout
		if _issued or Game.shift_over or Game.dead:
			return
	_issued = true
	var pool: Array = (POOL.get(Game.night, POOL_LATE) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + 77
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	# На 1-й ночи — 1 задание для знакомства, дальше — по 2 разноплановых дела на смену.
	var count := 1 if Game.night <= 1 else 2
	for i in range(mini(count, pool.size())):
		active.append(pool[i] as StringName)
	beacon_range.x = rng.randi_range(36, 82) * 100
	beacon_range.y = beacon_range.x + 400
	control_freq = rng.randi_range(31, 88) * 100 + 50
	for _try in range(20):
		if Signals.is_free(float(control_freq)):
			break
		control_freq = rng.randi_range(31, 88) * 100 + 50
	# Цифры — только те, что есть в озвучке станции (пока нет «девяти», группа без неё).
	var digits := NumbersVoice.digit_pool()
	if digits.size() < 4:
		digits = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var nz := digits.filter(func(d: int) -> bool: return d != 0)
	control_group = "%d-%d-%d-%d" % [nz[rng.randi() % nz.size()], digits[rng.randi() % digits.size()],
		digits[rng.randi() % digits.size()], nz[rng.randi() % nz.size()]]
	if is_active(&"beacon"):
		var bf := rng.randf_range(beacon_range.x + 30.0, beacon_range.y - 30.0)
		for _try in range(20):
			if Signals.is_free(bf) and absf(bf - control_freq) > 60.0:
				break
			bf = rng.randf_range(beacon_range.x + 30.0, beacon_range.y - 30.0)
		Game.radio.add_dynamic(&"beacon", bf)
	if is_active(&"callsign"):
		Game.radio.add_dynamic(&"control", float(control_freq))
	for id in active:
		_apply(id, true)
	_announce()


func _announce() -> void:
	# Радиопередача наряда — один вызов, без наслоения голоса на самого себя
	if Game.radio != null:
		Game.radio.play_transmission(Voice.or_fallback(&"ml_tasks", VOICE), 0.0)
	else:
		Game.audio.play_3d(VOICE, RADIO_POS, 0.0, 4.0)
	for id in active:
		var line := _give_text(id)
		Game.hud.subtitle(Loc.t(&"semenov.near", [line]) if Game.is_home() else Loc.t(&"hal.radio_far"), 6.5)
		await get_tree().create_timer(7.0, false).timeout
	if Game.radio != null:
		Game.radio.say_pass(Radio.Pass.REAL, true)   # наряд читает первый оператор


func _close() -> void:
	_closed = true
	if active.is_empty():
		return
	if Game.radio != null:
		Game.radio.play_transmission(VOICE, 0.0, Radio.Pass.REAL_END)
	else:
		Game.audio.play_3d(VOICE, RADIO_POS, 0.0, 4.0)
	Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"task.fail")]) if Game.is_home() else Loc.t(&"hal.radio_far"), 5.0)
	Director.add_tension(12.0, "задания не выполнены")
	Game.add_fatigue(6.0)
	for id in active.duplicate():
		_apply(id, false)
	active.clear()


func complete(id: StringName) -> void:
	if not is_active(id):
		return
	active.erase(id)
	done.append(id)
	_lock_t = 0.0
	_apply(id, false)
	SaveGame.flags["tasks_done"] = int(SaveGame.flags.get("tasks_done", 0)) + 1
	Game.add_fatigue(-6.0)
	Director.add_tension(-8.0, "задание выполнено")
	await get_tree().create_timer(1.5, false).timeout
	if Game.radio != null:
		Game.radio.play_transmission(Voice.or_fallback(&"ml_task_done", VOICE), -2.0, Radio.Pass.REAL_END)
	else:
		Game.audio.play_3d(VOICE, RADIO_POS, -2.0, 4.0)
	Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"task.done")]) if Game.is_home() or Game.radio.active else Loc.t(&"task.done_far"), 4.0)



## За рацией на 6880: если группа принята — передаём её, а не сводку.
func try_transmit() -> bool:
	if is_active(&"callsign") and control_heard:
		Game.hud.subtitle(Loc.t(&"task.control_sent", [control_group]), 3.5)
		complete(&"callsign")
		return true
	return false


# --- Подсказки ---------------------------------------------------------------

func objective() -> String:
	if active.is_empty():
		return ""
	var id := active[0]
	match id:
		&"beacon":
			return Loc.t(&"task.beacon.obj", [beacon_range.x, beacon_range.y])
		&"callsign":
			return Loc.t(&"task.callsign.obj2", [control_group]) if control_heard else Loc.t(&"task.callsign.obj", [control_freq])
		_:
			return Loc.t(StringName("task.%s.obj" % id))


func lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for id in done:
		out.append("[x] " + _short(id))
	for id in active:
		out.append("[ ] " + _short(id))
	return out


func _short(id: StringName) -> String:
	match id:
		&"beacon":
			return Loc.t(&"task.beacon.obj", [beacon_range.x, beacon_range.y])
		&"callsign":
			return Loc.t(&"task.callsign.obj", [control_freq])
	return Loc.t(StringName("task.%s.obj" % id))


func _give_text(id: StringName) -> String:
	match id:
		&"beacon":
			return Loc.t(&"task.beacon.give", [beacon_range.x, beacon_range.y])
		&"callsign":
			return Loc.t(&"task.callsign.give", [control_freq])
	return Loc.t(StringName("task.%s.give" % id))


## Мир под задание: сугроб на будке, погасший огонь мачты, канистра масла в сарае.
func _apply(id: StringName, on: bool) -> void:
	if Game.yard != null:
		Game.yard.set_task_prop(id, on)
	if not on and Game.radio != null:
		if id == &"beacon":
			Game.radio.remove_dynamic(&"beacon")
		elif id == &"callsign":
			Game.radio.remove_dynamic(&"control")
