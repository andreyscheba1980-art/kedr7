extends ScareEvent
## Двойник в окне: стоит вплотную к стеклу и смотрит внутрь. Появляется, только пока игрок стоит к окну спиной.
## Ждёт, когда его заметят, даёт секунду на осознание и исчезает в «моргании».
## Если его так и не заметили — молча уходит (игрок узнает об этом только из лога директора).

const SEEN_ANGLE := 14.0
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
	if not Game.zone in [&"room", &"corridor", &"radio_room", &"vestibule"]:
		return false
	var p := Game.player
	var best_d := INF
	for spot: Dictionary in Game.level.window_spots:
		var glass: Vector3 = spot["glass"]
		var d := p.global_position.distance_to(glass)
		if d < 1.2 or d > 7.0:
			continue
		if p.facing_angle_to(glass) < 110.0:
			continue   # окно в поле зрения — появляться нельзя
		if d < best_d:
			best_d = d
			_spot = spot
	return not _spot.is_empty()


func _perform() -> void:
	var creature := Creatures.make_silhouette()
	Game.level.add_child(creature)
	var inward: Vector3 = _spot["inward"]
	var feet: Vector3 = (_spot["glass"] as Vector3) - inward * 0.45   # вплотную к стеклу
	feet.y = 0.0
	creature.global_position = feet
	creature.look_at(feet + inward, Vector3.UP)
	Net.echo_figure(&"silhouette", feet, creature.rotation.y, 12.0, true)   # кооп: с улицы видна его спина у окна
	# Холодный отсвет снега: без него тёмная фигура за стеклом сливается с ночью и пугать нечем.
	var rim := OmniLight3D.new()
	rim.omni_range = 2.6
	rim.light_energy = 1.8
	rim.light_color = Color(0.6, 0.7, 0.9)
	rim.shadow_enabled = false
	Game.level.add_child(rim)
	rim.global_position = (_spot["glass"] as Vector3) - inward * 0.35 + Vector3(0, 0.25, 0)
	creature.tree_exiting.connect(rim.queue_free)

	var head := creature.get_node("Head") as Node3D
	var seen := await wait_until_seen(head, SEEN_ANGLE, 30.0)
	if seen:
		Game.audio.play_2d(STINGER, -4.0)
		await wait(0.8)
		Game.hud.set_black(true)
		creature.queue_free()
		await wait(0.12)
		Game.hud.set_black(false)
	else:
		creature.queue_free()
	await wait(0.5)
