class_name RadioTalks
extends Node
## Сеансы связи с выбором реплик (1.54). Раз за ночь вызывает Зоя (диспетчер, Свердловск) или Михалыч.
## Рация зовёт; подошёл к Р-250 — реплики субтитрами, потом выбор ответа ([1]/[2]/[3] или мышь, 14 с —
## иначе «промолчать»). Ответы копятся в SaveGame.flags:
##   talk_trust  — Михалыч тебе доверяет (на ночи 4 скажет контрольный вопрос про собаку);
##   talk_honest — докладывал Зое о странностях (ночь 5: борт; ночь 7: Зоя повторяет твои слова);
##   talk_quiet  — «всё штатно»;  talk_missed — не подошёл к рации.
##   mikh_question — знаешь вопрос «как звали собаку» (ночь 6, фары: двойника можно разоблачить).

const RADIO_POS := Vector3(9.2, 1.0, -1.4)
const STATIC := "res://assets/audio/radio_anomaly.ogg"
const CLICK := "res://assets/audio/ui_tick.ogg"
const ZasAudioClass = preload("res://scripts/data/zas_audio.gd")
const WAIT_REAL := 75.0          ## сколько секунд рация зовёт, пока не сдастся
const CHOICE_TIME := 14.0

## who, минута смены, условие (см. _cond), реплики, варианты [ключ, эффекты, ответ], ответ на молчание
## Пролог: Михалыч с дороги, пока Виктор устраивается на ночь (через 25 с дома). Первый выбор в игре.
const PROLOGUE_TALK := {"night": 0, "min": 0, "who": &"mikh", "lines": [&"t0.l1", &"t0.l2"],
	"choices": [[&"t0.c1", {"talk_trust": 1}, [&"t0.r1"]], [&"t0.c2", {"talk_trust": 1, "talk_honest": 1}, [&"t0.r2"]], [&"t0.c3", {"talk_quiet": 1}, [&"t0.r3"]]],
	"silent": [&"t0.rs"]}

const TALKS := [
	{"night": 1, "min": 168, "who": &"zoya", "lines": [&"t1.l1"],
		"choices": [[&"t1.c1", {"talk_honest": 1, "said_whistle": 1}, [&"t1.r1"]], [&"t1.c2", {"talk_quiet": 1}, [&"t1.r2"]], [&"t1.c3", {"talk_honest": 1}, [&"t1.r3"]]],
		"silent": [&"t1.rs"]},
	{"night": 2, "min": 196, "who": &"mikh", "lines": [&"t2.l1"],
		"choices": [[&"t2.c1", {"talk_trust": 1, "talk_honest": 1}, [&"t2.r1"]], [&"t2.c2", {"talk_quiet": 1}, [&"t2.r2"]], [&"t2.c3", {"talk_trust": 1}, [&"t2.r3"]]],
		"silent": [&"t2.rs"]},
	{"night": 3, "min": 176, "who": &"zoya", "lines": [&"t3.l1"],
		"choices": [[&"t3.c1", {"pw_confirmed": 1}, [&"t3.r1"]], [&"t3.c2", {"talk_honest": 1}, [&"t3.r2"]], [&"t3.c3", {"talk_honest": 1}, [&"t3.r3"]]],
		"silent": [&"t3.rs"]},
	{"night": 4, "min": 182, "who": &"mikh", "cond": "trust", "lines": [&"t4a.l1", &"t4a.l2"], "set": ["mikh_question"],
		"choices": [[&"t4a.c1", {"talk_trust": 1}, [&"t4a.r1"]], [&"t4a.c2", {"talk_trust": 1}, [&"t4a.r2"]]],
		"silent": [&"t4a.rs"]},
	{"night": 4, "min": 182, "who": &"mikh", "cond": "!trust", "lines": [&"t4b.l1"],
		"choices": [[&"t4b.c1", {"talk_trust": 1, "talk_honest": 1, "mikh_question": 1}, [&"t4b.r1"]], [&"t4b.c2", {"talk_quiet": 1}, [&"t4b.r2"]]],
		"silent": [&"t4b.rs"]},
	{"night": 5, "min": 196, "who": &"zoya", "lines": [&"t5.l1"], "lines_honest": [&"t5.l1h"],
		"choices": [[&"t5.c1", {"talk_honest": 1, "heli_asked": 1}, [&"t5.r1"]], [&"t5.c2", {"talk_quiet": 1}, [&"t5.r2"]]],
		"silent": [&"t5.rs"]},
	{"night": 6, "min": 190, "who": &"mikh", "lines": [&"t6.l1"],
		"choices": [[&"t6.c1", {"talk_trust": 1}, [&"t6.r1"]], [&"t6.c2", {"talk_trust": 1, "mikh_question": 1}, [&"t6.r2"]]],
		"silent": [&"t6.rs"]},
	{"night": 7, "min": 160, "who": &"zoya", "lines": [&"t7.l1q"], "lines_honest": [&"t7.l1h"],
		"choices": [[&"t7.c1", {}, [&"t7.r1"]], [&"t7.c2", {}, [&"t7.r2"]]],
		"silent": [&"t7.rs"]},
]

var _talk: Dictionary = {}
var _state := 0            ## 0 — ждём минуты, 1 — рация зовёт, 2 — разговор, 3 — всё
var _call_t := 0.0
var _ring_t := 0.0
var _goal_set := false


var _home_t := 0.0


func _ready() -> void:
	if Game.is_prologue() and not Game.has_flag("prologue_arrived") and Net.role == "" and not SaveGame.flags.get("talk_done_0", false):
		_talk = PROLOGUE_TALK
		_state = 0
		return
	if not Game.is_night() or Net.role != "":
		_state = 3
		return
	for t: Dictionary in TALKS:
		if int(t["night"]) == Game.night and _cond(String(t.get("cond", ""))):
			_talk = t
			break
	if _talk.is_empty() or SaveGame.flags.get("talk_done_%d" % Game.night, false):
		_state = 3
		return
	# С чекпоинта после минуты вызова — разговор уже был (или пропущен).
	if Game.resumed and Game.shift_minutes > float(_talk["min"]) + 20.0:
		_state = 3
		return
	EventBus.clock_minute.connect(_on_minute)


static func _cond(c: String) -> bool:
	match c:
		"trust":
			return flag("talk_trust") >= 1
		"!trust":
			return flag("talk_trust") < 1
	return true


static func flag(k: String) -> int:
	return int(SaveGame.flags.get(k, 0))


static func knows_question() -> bool:
	return flag("mikh_question") > 0


func _busy() -> bool:
	if Game.shift_over or Game.dead or Game.dying or Cutscene.active:
		return true
	if Game.events != null and Game.events._busy():
		return true
	return Game.radio != null and Game.radio.active


func _on_minute(m: int) -> void:
	if _state != 0 or m < int(_talk["min"]) or _busy():
		return
	_state = 1
	_call_t = WAIT_REAL
	_ring_t = 0.0
	if Game.story_goal == "":
		Game.story_goal = Loc.t(&"talk.goal")
		_goal_set = true
	Director.hold = true


func _process(delta: float) -> void:
	if _state == 0 and _talk.get("night", -1) == 0:
		# Пролог: через 25 с в доме — вызов (если не заняты кабиной, катсценой, радио)
		_home_t = _home_t + delta if Game.is_home() and not Game.has_flag("in_cabin") else 0.0
		if _home_t > 25.0 and not _busy():
			_state = 1
			_call_t = WAIT_REAL
			_ring_t = 0.0
			if Game.story_goal == "":
				Game.story_goal = Loc.t(&"talk.goal")
				_goal_set = true
		return
	if _state != 1:
		return
	if Game.shift_over or Game.dead:
		_finish(false)
		return
	_call_t -= delta
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = 9.0
		Game.audio.play_3d(STATIC, RADIO_POS, -4.0, 5.0, 2.5)
		var key := &"talk.call_zoya" if _talk["who"] == &"zoya" else &"talk.call_mikh"
		if Game.is_home():
			Game.hud.subtitle(Loc.t(key), 5.0, 2)
		elif Game.player.global_position.distance_to(RADIO_POS) < 30.0:
			Game.hud.subtitle(Loc.t(&"hal.radio_far"), 3.5)
	var pp := Game.player.global_position
	if Vector2(pp.x - RADIO_POS.x, pp.z - RADIO_POS.z).length() < 2.4 and Game.player.mode == Player.Mode.WALK and Game.hud.modal() == null:
		_state = 2
		_conversation()
	elif _call_t <= 0.0:
		SaveGame.flags["talk_missed"] = flag("talk_missed") + 1
		Game.hud.subtitle(Loc.t(&"talk.missed"), 4.0)
		_finish(false)


func _say(key: StringName) -> void:
	var text := Loc.t(key)
	var dur := clampf(text.length() * 0.065, 3.5, 8.5)
	Game.audio.play_3d(STATIC, RADIO_POS, -12.0, 4.0, 0.6)
	var vl := Voice.line(key, ["rt_"], RADIO_POS, 2.0)   # голос в эфире или шифр ЗАС
	if vl > 0.0:
		dur = vl + 0.3
	Game.hud.subtitle(text, dur, 2)
	await get_tree().create_timer(dur + 0.35, false).timeout
	ZasAudioClass.play_relay_click(false, RADIO_POS)


func _conversation() -> void:
	if _goal_set:
		Game.story_goal = ""
		_goal_set = false
	var lines: Array = _talk["lines"]
	if _talk.has("lines_honest") and flag("talk_honest") > flag("talk_quiet"):
		lines = _talk["lines_honest"]
	for k: StringName in lines:
		if Game.shift_over or Game.dead:
			_finish(false)
			return
		await _say(k)
	for f: String in _talk.get("set", []):
		SaveGame.flags[f] = 1
	var opts: Array = []
	for c: Array in _talk["choices"]:
		opts.append(Loc.t(c[0]))
	var pick: int = await TalkChoiceUI.ask(opts, CHOICE_TIME)
	var reply: Array = _talk["silent"]
	if pick >= 0:
		var ch: Array = _talk["choices"][pick]
		var eff: Dictionary = ch[1]
		for k: String in eff:
			SaveGame.flags[k] = flag(k) + int(eff[k])
		reply = ch[2]
		Game.hud.subtitle(Loc.t(&"talk.you", [opts[pick]]), 3.0, 2)
		var said := Voice.line(ch[0], ["v_"])
		await get_tree().create_timer(maxf(2.6, said + 0.3), false).timeout
	for k: StringName in reply:
		if Game.shift_over or Game.dead:
			break
		await _say(k)
	SessionLog.note("сеанс связи %s: выбор %d" % ["пролог" if _talk.get("night", -1) == 0 else "ночь %d" % Game.night, pick + 1])
	_finish(true)


func _finish(_talked: bool) -> void:
	_state = 3
	if _goal_set:
		Game.story_goal = ""
		_goal_set = false
	SaveGame.flags["talk_done_%d" % (0 if _talk.get("night", -1) == 0 else Game.night)] = true
	Director.hold = false
	set_process(false)
