extends ScareEvent
## Галлюцинация (усталость): три удара во входную дверь. Откроешь — снаружи никого и никаких следов.

const KNOCK := "res://assets/audio/door_knock.ogg"


func can_stage() -> bool:
	return Game.is_home() and not Game.level.door_open


func _perform() -> void:
	Game.audio.play_3d(KNOCK, Vector3(14.6, 1.3, 3.1), 2.0, 4.0)
	await wait(5.0)
