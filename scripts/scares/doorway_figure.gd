extends ScareEvent
## Двойник стоит в проёме двери в сени — руки по швам, лицом к тебе.
## Появляется за спиной; когда игрок оборачивается — свет моргает, и его уже нет.

const SEEN_ANGLE := 18.0
const STINGER := "res://assets/audio/sub_drop.ogg"


## Оберег проверяем последним: «сработал» он, только если испуг иначе состоялся бы (Rituals — след утром).
func can_stage() -> bool:
	if not _can_stage_raw():
		return false
	if Game.knife_in_lintel:
		Rituals.worked(&"knife")
		return false
	return true


func _can_stage_raw() -> bool:
	if Game.zone != &"room":
		return false
	var look: Vector3 = Game.level.door_spot["look"]
	var p := Game.player
	return p.global_position.distance_to(look) > 2.2 and p.facing_angle_to(look) > 110.0


func _perform() -> void:
	var creature := Creatures.make_silhouette()
	Game.level.add_child(creature)
	var feet: Vector3 = Game.level.door_spot["feet"]
	var inward: Vector3 = Game.level.door_spot["inward"]
	creature.global_position = feet
	creature.look_at(feet + inward, Vector3.UP)
	Net.echo_figure(&"silhouette", feet, creature.rotation.y, 9.0)   # кооп: в проёме он стоит для обоих

	var chest := creature.get_node("Chest") as Node3D
	var seen := await wait_until_seen(chest, SEEN_ANGLE, 22.0)
	if seen:
		await wait(0.55)
		Game.audio.play_2d(STINGER, -2.0)
		await Game.level.flicker(0.35)
		Game.hud.set_black(true)
		creature.queue_free()
		await wait(0.15)
		Game.hud.set_black(false)
	else:
		creature.queue_free()
	await wait(0.5)
