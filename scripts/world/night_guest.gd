class_name NightGuest
extends Node
## «Гость у двери» (ночи 2–6, не каждую): стук, голос — «пусти погреться». Кто там — человек или оно?
## Проверить можно, не открывая:
##   • окно сеней — у человека изо рта пар, он переминается; у него пара нет, стоит не шелохнувшись;
##   • спросить через дверь — человек отвечает по делу (откуда, как звать), оно повторяет твои же слова;
##   • Найда — на человека виляет и скулит у двери, на него рычит и пятится.
## Открыл человеку — сидит у печи до света, утром оставляет гостинец (пайки, ракеты, патроны, слух о Семёнове).
## Открыл ему — удар холода в сени, дом выстуживает, напряжение под потолок, окно сеней выбито к утру.
## Не открыл человеку — утром следы уходят в лес, а по рации: охотника с Ушмы так и не нашли.
## Через 100 с без ответа гость уходит.

const DOOR := Vector3(14.6, 1.3, 3.1)
const ASK_AT := Vector3(14.1, 1.3, 3.1)
const PEEK_AT := Vector3(13.0, 1.45, 6.2)
const KNOCK := "res://assets/audio/door_knock.ogg"
const WAIT := 100.0

static var instance: NightGuest

var real := true
var state := &"idle"          ## idle → knocking → resolved
var _t := 0.0
var _left := 0.0
var _knock_t := 0.0
var _asked := 0
var _nodes: Array[Node] = []
var _rng := RandomNumberGenerator.new()


static func roll_tonight() -> bool:
	return Game.is_night() and not Game.is_prologue() and Game.night >= 2


func _ready() -> void:
	name = "NightGuest"
	if not roll_tonight():
		queue_free()
		return
	instance = self
	_rng.seed = Game.run_seed + Game.night * 131 + 5
	if _rng.randf() > 0.55 or SaveGame.flags.get("guest_night", -1) == Game.night:
		queue_free()
		return
	# Чем дальше, тем чаще под дверью не человек
	real = _rng.randf() < (0.7 if Game.night <= 3 else 0.4)
	_t = _rng.randf_range(150.0, 420.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


func _process(delta: float) -> void:
	match state:
		&"idle":
			_t -= delta
			if _t > 0.0 or not Game.is_home() or Game.level == null or Game.level.door_open:
				return
			if Director.take_peak("гость у двери", 25.0, 90.0) or _t < -240.0:
				_start()
		&"knocking":
			_left -= delta
			_knock_t -= delta
			if _knock_t <= 0.0:
				_knock_t = _rng.randf_range(14.0, 22.0)
				_knock()
			if Game.level != null and Game.level.door_open:
				_opened()
			elif _left <= 0.0:
				_gone()


func _start() -> void:
	state = &"knocking"
	SaveGame.flags["guest_night"] = Game.night
	SaveGame.flags["door_knocked"] = true
	_left = WAIT
	_knock_t = 0.0
	var st := Game.level
	var ask := Geo.interactable(st, Vector3(0.6, 1.4, 0.8), ASK_AT, null, Loc.t(&"guest.it_ask"), func(_p: Player) -> void: _ask())
	ask.name = "GuestAsk"
	var peek := Geo.interactable(st, Vector3(0.9, 0.9, 0.5), PEEK_AT, null, Loc.t(&"guest.it_peek"), func(_p: Player) -> void: _peek())
	peek.name = "GuestPeek"
	_nodes = [ask, peek]
	Game.hud.subtitle(Loc.t(&"guest.call_real" if real else &"guest.call_mimic"), 6.0)
	if Dog.instance != null and Dog.is_near_player():
		Dog.instance.call(&"_play", &"growl" if not real else &"bark", 0.1)


func _knock() -> void:
	Game.audio.play_3d(KNOCK, DOOR, 2.0 if real else -1.0, 5.0)


func _ask() -> void:
	if state != &"knocking":
		return
	_asked += 1
	var key: StringName
	if real:
		key = StringName("guest.ans_real_%d" % mini(_asked, 3))
	else:
		key = StringName("guest.ans_mimic_%d" % mini(_asked, 3))
	Game.hud.subtitle(Loc.t(key), 6.0)
	if not real:
		Director.add_tension(6.0, "голос за дверью повторяет")


func _peek() -> void:
	if state != &"knocking":
		return
	Game.hud.subtitle(Loc.t(&"guest.peek_real" if real else &"guest.peek_mimic"), 6.0)
	if not real:
		Director.add_tension(8.0, "у двери стоит, пара нет")
	if Dog.instance != null and Dog.is_near_player():
		get_tree().create_timer(2.5, false).timeout.connect(func() -> void:
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"guest.dog_real" if real else &"guest.dog_mimic"), 4.0))


func _clear() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _opened() -> void:
	state = &"resolved"
	_clear()
	if real:
		SaveGame.flags["guest_result"] = "real_in"
		Game.hud.subtitle(Loc.t(&"guest.in_real"), 7.0)
		Director.add_tension(-18.0, "живой человек в доме")
		Game.warmth = minf(Game.warmth + 10.0, 100.0)
		# Сидит у печи до света
		var g := Creatures.make_human(&"hunter", true)
		g.name = "GuestHunter"
		g.position = Vector3(0.4, 0.0, 3.0)
		g.rotation.y = deg_to_rad(150.0)
		g.scale = Vector3.ONE * 0.9
		Game.level.add_child(g)
		_nodes.append(g)
	else:
		SaveGame.flags["guest_result"] = "mimic_in"
		await Game.hud.blink(0.35)
		Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 2.0)
		Game.hud.subtitle(Loc.t(&"guest.in_mimic"), 7.0)
		Game.warmth = maxf(Game.warmth - 30.0, 0.0)
		Director.add_tension(35.0, "открыл ему дверь")
		SaveGame.flags["had_night_siege"] = true   # утром — выбитое окно сеней (Aftermath)
	SaveGame.write()


func _gone() -> void:
	state = &"resolved"
	_clear()
	SaveGame.flags["guest_result"] = "real_out" if real else "mimic_out"
	Game.audio.play_3d("res://assets/sfx/snow_steps_walk.ogg", DOOR + Vector3(2.0, -1.2, 0), -4.0, 8.0)
	Game.hud.subtitle(Loc.t(&"guest.gone_real" if real else &"guest.gone_mimic"), 6.0)
	SaveGame.write()


## Утро: что осталось от ночного гостя (вызывается из Troubles при построении утра).
static func morning() -> String:
	var r: String = SaveGame.flags.get("guest_result", "")
	if r == "":
		return ""
	SaveGame.flags.erase("guest_result")
	match r:
		"real_in":
			var rng := RandomNumberGenerator.new()
			rng.seed = Game.run_seed + Game.phase_index * 17
			var gift := rng.randi_range(0, 2)
			if gift == 0:
				Supply.add(2, &"guest.r_gift")
			elif gift == 1:
				Game.add_spare_flares(2)
			else:
				SaveGame.flags["tea_tins"] = int(SaveGame.flags.get("tea_tins", 0)) + 2
			return Loc.t(StringName("guest.morning_gift_%d" % gift))
		"real_out":
			Director.add_tension(6.0, "не пустил человека")
			return Loc.t(&"guest.morning_real_out")
		"mimic_in":
			return Loc.t(&"guest.morning_mimic_in")
		"mimic_out":
			return Loc.t(&"guest.morning_mimic_out")
	return ""
