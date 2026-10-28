extends ScareEvent
## Галлюцинация (усталость): рация сама зовёт «Кедр-7, ответьте». Подходишь — только шум.

const VOICE := "res://assets/audio/voice_mainland.ogg"


func can_stage() -> bool:
	return false


func _perform() -> void:
	var p := Game.audio.play_3d(VOICE, Game.radio.global_position, 2.0, 3.0)
	p.bus = &"Radio"
	var near := Game.player.global_position.distance_to(Game.radio.global_position) < 10.0
	Game.hud.subtitle(Loc.t(&"hal.radio_call") if near else Loc.t(&"hal.radio_far"), 3.5)
	await wait(4.0)
