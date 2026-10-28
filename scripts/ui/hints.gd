class_name Hints
extends Node
## Подсказки по ходу игры: каждая — один раз за прохождение, в нужный момент, только про выживание.
## Не учебник в начале ночи, а короткая записка дежурного ровно тогда, когда она нужна:
## шаги за спиной → дыхание; дрожит барограф → под свет; у шара → сколько он прикрывает; стук → глазок;
## днём в рубке → прогноз; вторая ночь → слухач. Показ — карточкой под задачей, ~8 с, по очереди.

const CHECK := 0.5

static var _inst: Hints
var _queue: Array[StringName] = []
var _t := 0.0
var _busy_until := 0.0


func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


## Показать подсказку id, если её ещё не было в этом прохождении.
static func show(id: StringName) -> void:
	if _inst == null or seen(id) or _inst._queue.has(id):
		return
	_inst._queue.append(id)


static func seen(id: StringName) -> bool:
	return bool(SaveGame.flags.get("hint_" + String(id), false))


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = CHECK
	_watch()
	var now := Time.get_ticks_msec() / 1000.0
	if _queue.is_empty() or now < _busy_until or Game.hud == null or Game.hud.modal() != null:
		return
	var id: StringName = _queue.pop_front()
	if seen(id):
		return
	SaveGame.flags["hint_" + String(id)] = true
	if OS.is_debug_build():
		print("[hint] ", id)
	Game.hud.hint(Loc.t(StringName("hint." + String(id))))
	_busy_until = now + 9.5


## Условия, которые проще проверять опросом, чем вешать сигналы по всему коду.
func _watch() -> void:
	var p := Game.player
	if p == null or Game.dead or Game.shift_over:
		return
	if Game.is_night():
		if Game.yrka != null and Game.yrka.enabled and Game.is_outside() and Game.yrka.stage != YrkaThreat.Stage.CALM:
			show(&"breath")
		if Game.night >= 2 and Game.zone == &"radio_room":
			show(&"seismo")
		if Game.night >= 2 and Game.zone == &"vestibule":
			show(&"obereg")
		if Game.is_outside() and p.global_position.distance_to(Yard.METEO + Yard.M_BALLOON) < 7.0:
			show(&"balloon")
	elif Game.is_day() and not Game.is_prologue() and Game.zone == &"radio_room":
		show(&"forecast")
