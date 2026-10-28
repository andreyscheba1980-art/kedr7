extends ScareEvent
## Стук в стену за спиной игрока. Иногда — второй раз, ближе.

const KNOCK := "res://assets/audio/knock.ogg"


func can_stage() -> bool:
	return Game.zone in [&"room", &"corridor", &"radio_room", &"storage", &"vestibule"]


func _perform() -> void:
	var p := Game.player
	var back := p.camera.global_basis.z   # +Z камеры = за спиной
	back.y = 0.0
	back = back.normalized()
	var at := p.global_position + back * 1.6 + Vector3.UP * 1.3
	Game.audio.play_3d(KNOCK, at, 2.0)
	Net.echo_sound(KNOCK, at, 2.0)   # кооп: стук по стене слышно во всём доме — и снаружи у стены
	await wait(2.8)
	if Game.rng.randf() < 0.5:
		Game.audio.play_3d(KNOCK, p.global_position + back * 0.8 + Vector3.UP * 1.3, 6.0, 1.5)
		Net.echo_sound(KNOCK, p.global_position + back * 0.8 + Vector3.UP * 1.3, 6.0, 1.5)
		await wait(2.2)
	elif Voice.sfx(&"scratch_wall") != "" and Game.rng.randf() < 0.6:
		# Вместо второго стука — медленный скрежет по той же стене.
		Game.audio.play_3d(Voice.sfx(&"scratch_wall"), p.global_position + back * 1.4 + Vector3.UP * 1.0, 0.0, 2.0)
		await wait(3.0)
