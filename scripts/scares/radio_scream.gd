extends ScareEvent
## Аука в эфире. Помехи нарастают, голос зовёт обернуться, пауза тишины — и визг с лицом на весь экран.
## Единственный по-настоящему громкий скример ночи. Срабатывает только за рацией.

const SCREAM := "res://assets/audio/scream.ogg"


func can_stage() -> bool:
	return Game.activity == &"radio" and Game.radio.active


func _perform() -> void:
	var radio := Game.radio
	var tw := create_tween()
	tw.tween_property(radio, "static_boost", 0.45, 1.8)
	await tw.finished
	Game.hud.subtitle(Loc.t(&"auka.1"), 1.4)
	await wait(1.6)
	Game.hud.subtitle(Loc.t(&"auka.2"), 1.2)
	await wait(1.4)

	# Тишина перед ударом: глушим эфир и гул.
	radio.muted = true
	Game.audio.silence(true)
	await wait(0.7)

	Game.audio.play_2d(SCREAM, 0.0)
	Net.echo_radio(SCREAM, -10.0)   # кооп: визг прорвался и в рацию напарника
	Game.player.shake(0.06, 0.6)
	await Game.hud.flash_face(0.55)

	radio.static_boost = 0.0
	await wait(1.6)
	radio.muted = false
	Game.audio.silence(false)
