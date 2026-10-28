extends ScareEvent
## Паранойя: что-то в доме тихо меняется, пока игрок не смотрит. Никакого звука — заметит потом сам.


func can_stage() -> bool:
	return Game.level != null and Game.zone != &"room"


func _perform() -> void:
	Game.level.change_random_prop()
	await wait(0.2)
