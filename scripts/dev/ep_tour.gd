extends Node
## Автопрогон эпилога со снимками (main.gd --epilogue --eptour): езда, парковка, холл, этаж, дело, архив, звонок.

const SHOTS := "user://shots/"
var _n := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	_run.call_deferred()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	get_tree().root.get_texture().get_image().save_png(SHOTS + "ep%02d_%s.png" % [_n, name])
	print("[ep] shot ", name)


func _use(ep: Epilogue, pos: Vector3) -> void:
	# Ближайшая точка взаимодействия к pos — как будто посмотрел и нажал E
	var best: Area3D = null
	var bd := 1e9
	for a in ep._world.get_children():
		if a is Area3D and a.has_meta(&"use"):
			var d := (a as Area3D).global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = a
	if best != null:
		print("[ep] use ", best.get_meta(&"prompt") if not (best.get_meta(&"prompt") is Callable) else (best.get_meta(&"prompt") as Callable).call(), " d=", snappedf(bd, 0.1))
		(best.get_meta(&"use") as Callable).call()


func _run() -> void:
	await _wait(3.0)
	var ep: Epilogue = get_tree().root.find_children("*", "Epilogue", true, false)[0]
	await _shot("start_car")
	# Едем: газ 6 с
	Input.action_press(&"move_forward")
	await _wait(6.0)
	Input.action_release(&"move_forward")
	await _shot("driving")
	print("[ep] машина z=%.0f скорость=%.1f" % [ep._car.global_position.z, ep._speed])
	ep._car.global_position = Vector3(9.5, 0, -262.0)
	ep._speed = 0.0
	ep._car.rotation.y = 0.0
	ep._yaw = -0.9
	await _wait(0.5)
	await _shot("parked_view")
	ep._park()
	await _wait(1.6)
	print("[ep] пешком: режим=%s поз=%s" % [ep.mode, ep._body.global_position.snapped(Vector3.ONE * 0.1)])
	await _shot("street_walk")
	_use(ep, EpBuild.KGB_DOOR + Vector3(-0.6, 1.2, 0))
	await _wait(1.2)
	ep._yaw = PI
	await _shot("lobby")
	_use(ep, ep._lobby["lift"])
	await _wait(2.0)
	await _shot("floor4")
	var r: Dictionary = ep._f4[&"412"]
	ep._body.global_position = (r["center"] as Vector3) + Vector3(1.5, 0.05, -1.0)
	ep._yaw = PI * 0.75
	await _wait(0.4)
	await _shot("office412")
	for k in 2:
		_use(ep, Vector3(float(r["x0"]) + 0.5, 1.4, (r["center"] as Vector3).z - 1.8))
		await _wait(0.3)
	await _wait(3.5)
	await _shot("zoya")
	_use(ep, ep._world.find_child("CaseFolder", true, false).global_position)
	await _wait(0.4)
	await _shot("case_doc")
	for k in ep._doc_pages.size():
		ep._doc_next()
	print("[ep] после дела: этап=%s" % ep.stage)
	for room: StringName in [&"415", &"418", &"420"]:
		var rr: Dictionary = ep._f4[room]
		ep._body.global_position = (rr["door"] as Vector3) + Vector3(0, 0.05, float(rr["side"]) * 1.2)
		ep._yaw = 0.0 if float(rr["side"]) < 0 else PI
		await _wait(0.4)
		await _shot("room" + String(room))
	var r4: Dictionary = ep._f4[&"418"]
	_use(ep, ep._world.find_child("PhotoBoard", true, false).global_position)
	await _wait(0.3)
	await _shot("doc_yrka")
	ep._close_doc()
	_use(ep, Vector3(float(r4["x0"]) + 4.0, 1.2, float(r4["zout"]) + 0.9))
	print("[ep] после архива: этап=%s" % ep.stage)
	ep._body.global_position = (r["center"] as Vector3) + Vector3(0, 0.05, 0)
	await _wait(1.0)
	print("[ep] в 412: этап=%s звонок=%s" % [ep.stage, ep._ring_t >= 0.0])
	ep._answer_phone()
	await _wait(14.0)
	await _shot("call")
	await _wait(18.0)
	await _shot("final")
	print("[ep] конец: этап=%s" % ep.stage)
	get_tree().quit()
