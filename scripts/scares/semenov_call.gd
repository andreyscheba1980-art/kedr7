extends ScareEvent
## Обязательный бит ночи 2: в эфире голос Семёнова — на любой частоте, даже если рация не настроена.
## Если игрок далеко от рации, он слышит только неразборчивый голос из комнаты.

const NEAR_DIST := 9.0
const LINES := [
	[&"semenov.1", 3.0],
	[&"semenov.2", 4.0],
	[&"semenov.3", 3.6],
	[&"semenov.4", 3.6],
]


func can_stage() -> bool:
	return Game.radio != null and not Game.radio._busy and not Game.radio.is_voice_busy()


func _perform() -> void:
	var radio := Game.radio
	if radio == null:
		return
	radio.stop_transmission()
	radio.voice_override = true
	for line: Array in LINES:
		var text := Loc.t(line[0])
		var dur: float = line[1]
		var near := Game.player.global_position.distance_to(radio.global_position) < NEAR_DIST
		Game.hud.subtitle(Loc.t(&"semenov.near", [text]) if near else Loc.t(&"semenov.far"), dur)
		await wait(dur + 0.3)
	radio.voice_override = false
	Director.add_tension(15.0, "голос Семёнова")
