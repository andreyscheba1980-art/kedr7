extends ScareEvent
## «Гость в доме»: игрок во дворе, оборачивается к станции — а в освещённом окне его комнаты кто-то стоит.
## Пока смотришь — стоит. Моргнул свет — пусто. Когда вернёшься в дом, там никого.

const SEEN_ANGLE := 6.0
const STINGER := "res://assets/audio/sub_drop.ogg"

var _spot: Dictionary


## Оберег проверяем последним: «сработал» он, только если испуг иначе состоялся бы (Rituals — след утром).
func can_stage() -> bool:
	if not _can_stage_raw():
		return false
	if Game.mirror_covered:
		Rituals.worked(&"mirror")
		return false
	return true


func _can_stage_raw() -> bool:
	if Game.zone != &"yard" or not Game.level.lights_lit():
		return false
	var p := Game.player
	var house := Vector3(6.1, 1.4, 2.0)
	var d := p.global_position.distance_to(house)
	if d < 14.0 or d > 45.0:
		return false
	if p.facing_angle_to(house) < 100.0:
		return false   # дом в поле зрения — ставить нельзя
	# Окно, которое смотрит в сторону игрока.
	for spot: Dictionary in Game.level.window_spots:
		var glass: Vector3 = spot["glass"]
		var outward: Vector3 = -(spot["inward"] as Vector3)
		var to_player := (p.global_position - glass)
		to_player.y = 0.0
		if outward.dot(to_player.normalized()) > 0.35:
			_spot = spot
			return true
	return false


func _perform() -> void:
	var figure := Creatures.make_silhouette()
	Game.level.add_child(figure)
	var glass: Vector3 = _spot["glass"]
	var inward: Vector3 = _spot["inward"]
	var feet := glass + inward * 0.9
	feet.y = 0.0
	figure.global_position = feet
	figure.look_at(feet - inward, Vector3.UP)   # лицом к окну, на игрока
	var glow := _spot.get("glow") as Node3D
	if glow != null:
		glow.visible = false   # без свечения стекла фигура видна силуэтом на фоне комнаты

	var head := figure.get_node("Head") as Node3D
	# Ждём взгляда со двора. Если игрок вернулся в дом раньше — фигуры там уже нет.
	var seen := false
	var t := 0.0
	while t < 40.0 and not Game.is_indoors():
		if Game.player.is_looking_at(head.global_position, SEEN_ANGLE) and Game.player.has_line_of_sight(head.global_position):
			seen = true
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	if seen:
		Game.audio.play_2d(STINGER, -8.0)
		await wait(2.0)
		await Game.level.flicker(0.4)
	figure.queue_free()
	if glow != null:
		glow.visible = true
	await wait(0.5)
