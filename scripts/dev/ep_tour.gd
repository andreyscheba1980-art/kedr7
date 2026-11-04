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
	if OS.get_cmdline_user_args().has("--epfps"):
		for v: Array in [["street", Vector3(2.5, 0, 6.0)], ["lobby", EpBuild.LOBBY + Vector3(0, 0.05, 4.0)], ["corridor", EpBuild.FLOOR4 + Vector3(10, 0.05, 0)]]:
			if v[0] != "street":
				ep._enter_walk(v[1], 0.0)
			await _wait(3.0)
			var f0 := Engine.get_frames_drawn()
			var t0 := Time.get_ticks_msec()
			await _wait(3.0)
			print("[epfps] %s: %.0f draw=%d" % [v[0], float(Engine.get_frames_drawn() - f0) / (float(Time.get_ticks_msec() - t0) / 1000.0), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--ovl"):
		for c: Vector3 in [EpBuild.FLOOR4, EpBuild.LOBBY, EpBuild.LIFT]:
			print("[ovl] === зона ", c)
			OverlapAudit.run(ep._world, c, 30.0, 60)
		print("[ovl] === улица")
		OverlapAudit.run(ep._world, Vector3(0, 0, -130), 160.0, 30)
		get_tree().quit()
		return
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
	ep._yaw = 0.0
	await _wait(0.3)
	await _shot("lobby_tambour")
	_use(ep, ep._lobby["guard"])
	ep._body.global_position = EpBuild.LOBBY + Vector3(0.5, 0.05, 4.0)
	ep._yaw = 0.0
	await _wait(0.5)
	await _shot("lobby_hall")
	ep._yaw = PI * 0.5
	await _wait(0.3)
	await _shot("lobby_duty")
	ep._yaw = -PI * 0.5
	await _wait(0.3)
	await _shot("lobby_cloak")
	_use(ep, ep._world.find_child("Talk_ep_npc_cloak", true, false).global_position)
	ep._body.global_position = EpBuild.LOBBY + Vector3(7.5, 0.05, -7.0)
	ep._yaw = 0.0
	await _wait(0.4)
	await _shot("lobby_lifts")
	ep._body.global_position = EpBuild.LOBBY + Vector3(-6.0, 0.05, -7.0)
	ep._yaw = 0.3
	await _wait(0.4)
	await _shot("lobby_reception")
	_use(ep, ep._lobby["lift"])
	await _wait(1.2)
	ep._yaw = 0.0
	await _shot("lift_cabin")
	ep._ride_up()
	await _wait(5.5)
	print("[ep] лифт: этаж=%d табло=%s" % [ep._lift_floor, (ep._cab["indicator"] as Label3D).text])
	await _shot("lift_open")
	ep._body.global_position = EpBuild.LIFT + Vector3(0, 0.05, -1.6)
	await _wait(1.5)
	await _shot("floor4")
	var wg: Dictionary = ep._wing
	ep._body.global_position = Vector3(EpBuild.WING_X, 0.05, EpBuild.FLOOR4.z - 2.5)
	ep._yaw = 0.0
	await _wait(0.5)
	await _shot("wing")
	ep._body.global_position = (wg[&"422"]["door"] as Vector3) + Vector3(-0.6, 0.05, 0)
	ep._yaw = -PI * 0.5
	await _wait(0.5)
	await _shot("room422")
	ep._body.global_position = (wg[&"424"]["door"] as Vector3) + Vector3(-0.6, 0.05, 0)
	await _wait(0.5)
	await _shot("room424")
	ep._body.global_position = EpBuild.FLOOR4 + Vector3(-9.0, 0.05, 0)
	ep._yaw = PI * 0.5
	await _wait(0.5)
	await _shot("corridor_west")
	ep._yaw = -PI * 0.5
	await _wait(0.5)
	await _shot("corridor_east")
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
	await _shot("case_cover")
	ep._docv.advance()
	await _wait(0.6)
	await _shot("case_spread")
	ep._docv.advance()
	await _wait(0.4)
	await _shot("case_spread2")
	while ep._docv != null and is_instance_valid(ep._docv) and ep.mode == &"doc":
		ep._docv.advance()
		await get_tree().process_frame
	print("[ep] после дела: этап=%s" % ep.stage)
	var r2: Dictionary = ep._f4[&"414"]
	ep._body.global_position = (r2["door"] as Vector3) + Vector3(0.8, 0.05, -1.2)
	ep._yaw = 0.3
	await _wait(0.5)
	await _shot("room414")
	_use(ep, ep._world.find_child("Talk_ep_npc_zoya", true, false).global_position)
	for room: StringName in [&"415", &"418", &"420"]:
		var rr: Dictionary = ep._f4[room]
		ep._body.global_position = (rr["door"] as Vector3) + Vector3(0, 0.05, float(rr["side"]) * 1.2)
		ep._yaw = 0.0 if float(rr["side"]) < 0 else PI
		await _wait(0.4)
		await _shot("room" + String(room))
	var r4: Dictionary = ep._f4[&"418"]
	_use(ep, ep._world.find_child("PhotoBoard", true, false).global_position)
	await _wait(0.3)
	await _wait(0.4)
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
