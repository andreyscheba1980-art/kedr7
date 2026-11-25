class_name RadioOrders
extends Node
## Приказы по рации: настоящие от Большой Земли и ложные «от неё». Игрок решает на слух, кому верить.
## Улики ложной: нет пароля «Бирюса» (ночь 3), пароль не тот — «Бирюза» (ночи 5–6),
## пароль верный, но вокруг голоса мёртвый эфир и слова повторяются, как запись (ночь 7).
## Настоящий приказ не выполнил — Большая Земля утром это припомнит; ложный выполнил — тебя нашли.
## Расписание — в Phases: "orders": [[минута, вид], ...].

const VOICE := "res://assets/audio/voice_mainland.ogg"
const WHISPER := "res://assets/audio/whisper.ogg"
const DOOR_POS := Vector3(14.55, 1.3, 3.1)
const RADIO_POS := Vector3(9.2, 1.0, -1.4)

## вид → [голос, субтитр, пароль, окно (мин), что надо сделать, ложный?]
const KINDS := {
	&"real_report": [&"ml_ord_report", &"ord.report", Radio.Pass.REAL, 60, &"report", false],
	&"real_check": [&"ml_ord_check", &"ord.check", Radio.Pass.REAL, 120, &"mast", false],
	&"fake_report": [&"mlf_report", &"ordf.report", Radio.Pass.FAKE, 40, &"report", true],
	&"fake_report_wrong": [&"mlf_report", &"ordf.report", Radio.Pass.FAKE_WRONG, 40, &"report", true],
	&"fake_report_clean": [&"mlf_report", &"ordf.report", Radio.Pass.FAKE_CLEAN, 40, &"report", true],
	&"fake_door_wrong": [&"mlf_door", &"ordf.door", Radio.Pass.FAKE_WRONG, 30, &"door", true],
	&"fake_vane_trap": [&"mlf_report", &"ordf.vane_trap", Radio.Pass.FAKE_WRONG, 50, &"vane_trap", true],
}

const CLOSED_TRAIL_TRAP := Vector3(-6.8, 0.0, 8.2)   ## калитка закрытой просеки в тайгу (западнее избы)

var _queue: Array = []          ## [[минута, вид], ...]
var _kind: StringName = &""     ## активный приказ
var _until := 0
var _busy := false


func _ready() -> void:
	for o: Array in Game.cfg.get("orders", []):
		if not Game.resumed or int(o[0]) > int(Game.shift_minutes):
			_queue.append(o)
	EventBus.clock_minute.connect(_on_minute)
	EventBus.zone_changed.connect(_on_zone)
	EventBus.door_opened.connect(_on_door)


func active() -> bool:
	return _kind != &""


func is_fake() -> bool:
	return active() and bool(KINDS[_kind][5])


## Строка для списка тревог в HUD. Нейтрально: игра не подсказывает, кто говорит.
func objective() -> String:
	if not active():
		return ""
	match StringName(KINDS[_kind][4]):
		&"report":
			return Loc.t(&"ord.obj.report", [Game.minutes_to_clock(_until)])
		&"mast":
			return Loc.t(&"ord.obj.check", [Game.minutes_to_clock(_until)])
		&"door":
			return Loc.t(&"ord.obj.door")
		&"vane_trap":
			return Loc.t(&"ord.obj.vane_trap", [Game.minutes_to_clock(_until)])
	return ""


func _process(_delta: float) -> void:
	if not active() or _busy or Game.dead or Game.shift_over or Game.player == null:
		return
	if StringName(KINDS[_kind][4]) != &"vane_trap":
		return
	if not Game.is_outside():
		return
	var p_xz := Vector2(Game.player.global_position.x, Game.player.global_position.z)
	# Срабатывает только у самой закрытой тропы в тайгу — чтобы не наказывать игрока за визит на основной метеокорпус
	if p_xz.distance_to(Vector2(CLOSED_TRAIL_TRAP.x, CLOSED_TRAIL_TRAP.z)) < 4.2:
		trigger_vane_ambush()


func trigger_vane_ambush() -> void:
	if _busy or not active() or StringName(KINDS[_kind][4]) != &"vane_trap":
		return
	_kind = &""
	_busy = true
	NightMemory.mark(&"obeyed_fake")
	if Game.audio != null:
		Game.audio.trigger_vacuum(2.6)
		Game.audio.play_2d("res://assets/audio/radio_anomaly.ogg", 1.5)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"ordf.vane_ambush"), 4.5, 2)
	await get_tree().create_timer(1.1, false).timeout
	_busy = false
	if Game.dead or Game.shift_over or not Game.is_outside():
		return
	_gave_away()
	if Game.yrka != null and Game.yrka.enabled:
		Game.yrka.lure_strike()


func _on_minute(m: int) -> void:
	if Game.dead or Game.shift_over or not Game.is_night():
		return
	if active():
		if m > _until:
			_expire()
		return
	if _queue.is_empty() or m < int(_queue[0][0]):
		return
	if m > int(_queue[0][0]) + 90:
		_queue.pop_front()        # так и не застали дома — приказ «ушёл в пустоту»
		return
	var ev := Game.events
	if ev == null or ev._busy() or Game.radio == null or not Game.is_home() or Game.final_call:
		return
	var o: Array = _queue.pop_front()
	_issue(StringName(o[1]))


func _issue(kind: StringName) -> void:
	var d: Array = KINDS[kind]
	_kind = kind
	_until = int(Game.shift_minutes) + int(d[3])
	Game.radio.play_transmission(Voice.or_fallback(d[0], VOICE), 2.0, d[2])
	Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(d[1])]), 6.0)
	if bool(d[5]):
		NightMemory.mark(&"heard_fake")
	Director.add_tension(6.0, "приказ по рации")


## Передача сводки: если приказ о сводке активен — это ответ на него. Вызывается из Radio.transmit.
## true — передача обработана здесь.
func try_transmit() -> bool:
	if not active() or StringName(KINDS[_kind][4]) != &"report" or _busy:
		return false
	if _regular_report_ok():
		# Обычная сводка по расписанию закрывает и настоящий приказ; ложный просто остаётся без ответа.
		if not is_fake():
			NightMemory.mark(&"real_done")
		_kind = &""
		return false
	_answer_report()
	return true


func _regular_report_ok() -> bool:
	var times := Game.report_times()
	if Game.reports_closed or Game.reports_sent >= times.size() or not Game.has_readings():
		return false
	return Game.shift_minutes >= float(times[Game.reports_sent]) - 40.0


func _answer_report() -> void:
	var fake := is_fake()
	_kind = &""
	_busy = true
	Game.radio._busy = true
	Game.hud.subtitle(Loc.t(&"radio.report_out"), 3.5)
	await get_tree().create_timer(4.0, false).timeout
	Game.radio._busy = false
	if fake:
		NightMemory.mark(&"obeyed_fake")
		if Game.after_hour(3):
			NightMemory.mark(&"after3_tx")
		Game.radio.play_transmission(Voice.or_fallback(&"ml_wrong", VOICE), 2.0, Radio.Pass.FAKE)
		Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"ordf.report_obeyed")]), 5.5)
		_gave_away()
	else:
		NightMemory.mark(&"real_done")
		Game.radio.play_transmission(Voice.or_fallback(&"ml_ord_ok", Voice.or_fallback(&"ml_task_done", VOICE)), 0.0, Radio.Pass.REAL_END)
		Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"ord.report_ok")]), 5.0)
		Director.add_tension(-6.0, "внеочередная принята")
	_busy = false


func _on_zone(z: StringName) -> void:
	if z == &"mast" and active() and StringName(KINDS[_kind][4]) == &"mast" and not is_fake():
		_kind = &""
		NightMemory.mark(&"real_done")
		Game.hud.subtitle(Loc.t(&"ord.check_done"), 4.0)


func _on_door() -> void:
	if not active() or StringName(KINDS[_kind][4]) != &"door" or Game.player == null:
		return
	if Game.player.global_position.distance_to(DOOR_POS) > 3.5:
		return                    # дверь распахнуло ветром — это не ответ на приказ
	_kind = &""
	NightMemory.mark(&"obeyed_fake")
	Director.hold = true
	Game.audio.trigger_vacuum(2.0)
	await get_tree().create_timer(1.2, false).timeout
	Game.hud.subtitle(Loc.t(&"ordf.door_opened"), 5.5, 2)
	await get_tree().create_timer(4.5, false).timeout
	Game.audio.play_2d(WHISPER, -4.0)
	Game.hud.subtitle(Loc.t(&"ordf.door_thanks"), 3.5, 2)
	Director.hold = false
	_gave_away()


## Станция выдала себя: до конца ночи порог Ырки выше (как от сорванной сводки), усталость и страх.
func _gave_away() -> void:
	Game.reports_silent += 1
	Director.add_tension(25.0, "выполнил ложный приказ")
	Game.add_fatigue(8.0)
	if Game.yrka != null and Game.yrka.enabled and Game.is_outside():
		Game.yrka.force_chase()


func _expire() -> void:
	var fake := is_fake()
	_kind = &""
	if fake:
		# Не поддался — эфир шепчет вслед. Наказания нет: это и есть правильный ответ.
		if Game.is_home() and Game.radio != null and not Game.radio.is_voice_busy():
			Game.radio.play_transmission(VOICE, -4.0, Radio.Pass.FAKE)
			Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(&"ordf.waited")]), 4.5)
	else:
		NightMemory.mark(&"ignored_real")
		Director.add_tension(6.0, "настоящий приказ не выполнен")
