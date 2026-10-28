class_name ModelPreview
extends Node3D
## Разработка: `godot -- --preview` — выставляет существ в ряд под светом и сохраняет снимки
## спереди, сбоку и в «игровом» освещении фонарём в user://shots/preview_*.png. В игре не используется.

const SHOTS := "user://shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	floor_mi.material_override = Palette.m(&"snow")
	add_child(floor_mi)

	var items: Array[Node3D] = [
		Creatures.make_yrka(), Creatures.make_zherdyai(0.0), Creatures.make_human(&"driver"),
		Creatures.make_silhouette(), Creatures.make_corpse(),
	]
	for i in range(items.size()):
		add_child(items[i])
		items[i].position = Vector3(-5.0 + i * 2.0, 0, 0)
	_run.call_deferred(items)


func _run(items: Array[Node3D]) -> void:
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	await _wait(0.5)
	cam.position = Vector3(0, 1.6, -7.5)
	cam.look_at(Vector3(0, 1.1, 0))
	await _shot("row_front")
	cam.position = Vector3(-9.0, 1.6, -2.0)
	cam.look_at(Vector3(-2.0, 1.1, 0))
	await _shot("row_side")
	# Крупно: каждый — спереди-сбоку.
	var names := ["yrka", "zherdyai", "driver", "hunter", "shadow", "corpse"]
	for i in range(items.size()):
		var p := items[i].position
		var h := 2.4 if i == 1 else (0.6 if i == 5 else 1.3)
		cam.position = p + Vector3(1.0, h + 0.1, -1.7)
		cam.look_at(p + Vector3(0, h, 0))
		await _shot("close_" + names[i])
	# Ырка в темноте под фонарём — как его увидит игрок.
	env_dark()
	var spot := SpotLight3D.new()
	spot.light_energy = 2.6
	spot.spot_range = 20.0
	spot.spot_angle = 24.0
	add_child(spot)
	cam.position = items[0].position + Vector3(0.0, 1.55, -4.0)
	cam.look_at(items[0].position + Vector3(0, 1.1, 0))
	spot.global_transform = cam.global_transform
	await _shot("yrka_flashlight")
	get_tree().quit()


func env_dark() -> void:
	for c in get_children():
		if c is WorldEnvironment:
			var e: Environment = (c as WorldEnvironment).environment
			e.background_color = Color(0.01, 0.012, 0.02)
			e.ambient_light_energy = 0.15
			e.ambient_light_color = Color(0.1, 0.11, 0.15)
		elif c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = 0.03


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOTS + "preview_" + n + ".png")
	print("[preview] ", n)
