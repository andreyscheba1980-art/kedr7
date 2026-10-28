class_name NightMemory
extends RefCounted
## Что игрок делал ночами — чтобы мир это помнил: Большая Земля утром, голос за дверью, зов ночи 7.
## Текущая ночь копится в Game.mem_now (и уходит в чекпоинт), по концу смены переносится в сохранение:
##   flags["mem_last"]  — итог прошлой ночи (для утренней связи),
##   flags["mem_total"] — счётчики за всю игру.
## Ключи:
##   after3_tx    — передавал в эфир после трёх (правило 2)
##   out_after3   — ходил по двору после трёх
##   turned       — обернулся на зов Ырки
##   heard_fake   — слышал ложный приказ
##   obeyed_fake  — выполнил ложный приказ
##   ignored_real — не выполнил настоящий приказ Большой Земли
##   real_done    — выполнил настоящий приказ
##   missed       — сорвал сводку

const KEYS := [&"after3_tx", &"out_after3", &"turned", &"heard_fake", &"obeyed_fake", &"ignored_real", &"real_done", &"missed"]


static func mark(key: StringName, n := 1) -> void:
	Game.mem_now[String(key)] = int(Game.mem_now.get(String(key), 0)) + n


static func tonight(key: StringName) -> bool:
	return int(Game.mem_now.get(String(key), 0)) > 0


## Было ли такое хоть раз — в прошлые ночи или сегодня.
static func ever(key: StringName) -> bool:
	return count(key) > 0


static func count(key: StringName) -> int:
	var total: Dictionary = SaveGame.flags.get("mem_total", {})
	return int(total.get(String(key), 0)) + int(Game.mem_now.get(String(key), 0))


static func last_night() -> Dictionary:
	var d: Variant = SaveGame.flags.get("mem_last", {})
	return d if d is Dictionary else {}


## Конец ночной смены: итог ночи — в сохранение.
static func close_night() -> void:
	var times := Game.report_times()
	if Game.reports_sent < times.size() or Game.reports_silent > 0:
		mark(&"missed")
	var total: Dictionary = SaveGame.flags.get("mem_total", {})
	for k: String in Game.mem_now:
		total[k] = int(total.get(k, 0)) + int(Game.mem_now[k])
	SaveGame.flags["mem_total"] = total
	var last := Game.mem_now.duplicate()
	last["night"] = Game.night
	SaveGame.flags["mem_last"] = last
	Game.mem_now = {}


## Самый «громкий» поступок для голоса за дверью / зова: ключ реплики или &"".
static func worst() -> StringName:
	for k: StringName in [&"obeyed_fake", &"after3_tx", &"turned", &"out_after3"]:
		if ever(k):
			return k
	return &""


## Утренняя связь: что Большая Земля скажет о прошлой ночи. [голос, субтитр]
static func morning_line() -> Array:
	var last := last_night()
	if last.is_empty():
		return []
	if int(last.get("after3_tx", 0)) > 0:
		return [&"ml_morn_after3", &"morn.after3"]
	if int(last.get("heard_fake", 0)) > 0:
		return [&"ml_morn_order", &"morn.order"]
	if int(last.get("ignored_real", 0)) > 0:
		return [&"ml_morn_ignored", &"morn.ignored"]
	if int(last.get("missed", 0)) > 0:
		return [&"ml_morn_missed", &"morn.missed"]
	return [&"ml_morn_ok", &"morn.ok"]
