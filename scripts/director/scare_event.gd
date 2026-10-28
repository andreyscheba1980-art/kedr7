class_name ScareEvent
extends Node
## База постановки испуга. Наследник переопределяет can_stage() и _perform().
## Директор добавляет событие на уровень, проверяет can_stage() и запускает run().

signal finished

var def: ScareDef
var ctx: ScareContext
var _done := false


## Можно ли поставить испуг прямо сейчас (геометрия, куда смотрит игрок и т.п.).
func can_stage() -> bool:
	return true


func run() -> void:
	await _perform()
	_finish()


## Сама постановка. Корутина: ждёт таймеры, взгляд игрока и т.д.
func _perform() -> void:
	await get_tree().process_frame


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


## Ждёт, пока игрок посмотрит на точку (с прямой видимостью). true — увидел, false — таймаут.
func wait_until_seen(target: Node3D, max_deg: float, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if not is_instance_valid(target):
			return false
		var p := target.global_position
		if Game.player.is_looking_at(p, max_deg) and Game.player.has_line_of_sight(p):
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false
