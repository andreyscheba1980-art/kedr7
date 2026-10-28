extends ScareEvent
## Ложная тревога: свет мигает, гул пропадает, темнота... и ничего не происходит.
## Нужна, чтобы игрок не мог вычислить паттерн «мигание = скример».


func can_stage() -> bool:
	return Game.power_on and (Game.zone == &"room" or Game.zone == &"corridor")


func _perform() -> void:
	Game.audio.silence(true)
	Net.echo_lights(3.5)   # кооп: свет гаснет во всём доме — напарник видит тёмные окна
	await Game.level.flicker(1.4)
	Game.level.set_lit(false)
	await wait(Game.rng.randf_range(2.5, 4.0))
	Game.level.set_lit(true)   # питание проверяет lights_lit(); _lit не должен «залипать» в false
	Game.audio.silence(false)
	await wait(1.0)
