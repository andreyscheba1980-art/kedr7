extends ScareEvent
## Галлюцинация (усталость): силуэт на краю зрения — в углу комнаты или в сенях.
## Стоит, пока на него не посмотришь прямо; посмотрел — его там и не было.

const EDGE_MIN := 40.0
const EDGE_MAX := 62.0

var _spot := Vector3.ZERO


func can_stage() -> bool:
	if not Game.is_home():
		return false
	var candidates: Array[Vector3] = [Vector3(0.6, 0, 0.5), Vector3(5.6, 0, 0.5), Vector3(5.6, 0, 2.3), Vector3(9.6, 0, 0.6), Vector3(7.0, 0, 4.4), Vector3(13.0, 0, 5.8), Vector3(5.2, 0, -4.6), Vector3(-2.0, 0, 6.1)]
	for c in candidates:
		var head := c + Vector3(0, 1.7, 0)
		var ang := Game.player.facing_angle_to(head)
		if ang > EDGE_MIN and ang < EDGE_MAX and Game.player.global_position.distance_to(c) > 2.0 \
				and Game.player.has_line_of_sight(head):
			_spot = c
			return true
	return false


func _perform() -> void:
	var fig := Creatures.make_silhouette()
	Game.level.add_child(fig)
	fig.global_position = _spot
	var look_at_target := Game.player.global_position
	look_at_target.y = 0.0
	fig.look_at(look_at_target, Vector3.UP)
	var head := fig.get_node("Head") as Node3D
	var t := 0.0
	while t < 6.0:
		if Game.player.is_looking_at(head.global_position, 18.0):
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	fig.queue_free()
	await wait(0.5)
