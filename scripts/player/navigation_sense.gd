# res://scripts/player/navigation_sense.gd
class_name NavigationSense
extends Node

## Чувство ориентирования и саспенс потерянности в метели.
## Заменяет искусственную привязку к леерам и натоптанным полосам.
## Опрашивает видимость маяка, слышимость дизеля и близость ориентиров.

var lost_time := 0.0

func report_landmark() -> void:
	lost_time = 0.0

func _process(dt: float) -> void:
	var player: Node = get_parent()
	if player == null or not Game.is_outside():
		lost_time = 0.0
		return

	_check_ambient_landmarks(player)

	lost_time += dt
	var k := clampf((lost_time - 8.0) / 20.0, 0.0, 1.0)
	if k > 0.0:
		# Усиливаем внимание Ырки в метели при потере ориентира
		Attention.add(2.0 * k * dt)
		if "whiteout_panic" in player:
			player.set("whiteout_panic", move_toward(float(player.get("whiteout_panic")), k, dt * 0.3))
	else:
		if "whiteout_panic" in player:
			player.set("whiteout_panic", move_toward(float(player.get("whiteout_panic")), 0.0, dt * 0.8))

func _check_ambient_landmarks(player: Node) -> void:
	if Game.yard == null:
		return

	var p3d := player as Node3D
	if p3d == null:
		return

	# 1. Крыльцо станции и жилой избы
	var porch_pos: Vector3 = Game.yard.DOOR_OUT
	if p3d.global_position.distance_to(porch_pos) < 10.0:
		report_landmark()
		return

	# 2. Дизельная (генераторный сарай) по дистанции и ветру
	var shed_pos: Vector3 = Game.yard.SHED
	var dist_to_shed := p3d.global_position.distance_to(shed_pos)
	if dist_to_shed < 28.0:
		var carry: float = Storm.wind_dir.dot((p3d.global_position - shed_pos).normalized())
		if carry > -0.4:
			report_landmark()
			return

	# 3. Метеорологическая площадка
	var plot_pos: Vector3 = Game.yard.PLOT
	if p3d.global_position.distance_to(plot_pos) < 12.0:
		report_landmark()
		return

	# 4. Штормовой янтарный маяк на мачте во время просвета
	if Storm.clarity > 0.5:
		var mast_top: Vector3 = Game.yard.MAST + Vector3(0.0, 16.0, 0.0)
		var cam = player.get("camera") as Camera3D
		if cam != null and cam.is_position_in_frustum(mast_top):
			report_landmark()
			return
