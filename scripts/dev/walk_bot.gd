class_name WalkBot
extends RefCounted
## Проходимость: бот идёт по всем тропам двора, мосткам и комнатам дома обычным шагом игрока
## (через Input, как живой человек). Если за 2.5 с он продвинулся к цели меньше чем на 0.35 м —
## это «застрял»: пишем точку и что рядом, перескакиваем на 1.5 м вперёд и идём дальше.

const STUCK_T := 2.5
const STUCK_D := 0.35


static func routes() -> Array:
	var out: Array = []
	# Дом: комната → коридор → рубка → кладовая → сени → крыльцо (точки из туров автотеста)
	out.append(["дом", PackedVector3Array([Vector3(0.5, 0.05, 3.0), Vector3(2.9, 0.05, 3.2), Vector3(5.1, 0.05, 3.2),
		Vector3(8.0, 0.05, 3.6), Vector3(8.0, 0.05, 0.5), Vector3(8.0, 0.05, 3.6), Vector3(5.1, 0.05, 3.2),
		Vector3(4.6, 0.05, -1.5), Vector3(5.1, 0.05, 3.2), Vector3(10.8, 0.05, 4.2), Vector3(13.6, 0.05, 3.6),
		Vector3(15.0, 0.05, 3.5), Vector3(16.8, 0.05, 3.5)])])
	out.append(["мостки к дизельной", PackedVector3Array([Vector3(16.8, 0.05, 3.5), Vector3(16.6, 0.05, 0.0),
		Vector3(16.4, 0.05, -6.0), Vector3(16.0, 0.05, -11.0), Vector3(14.9, 0.05, -12.2)])])
	if Game.yard != null:
		var paths: Array = Game.yard.get(&"_all_paths")
		var i := 0
		for p: PackedVector3Array in paths:
			i += 1
			out.append(["тропа %d" % i, p])
		out.append(["вертодром", PackedVector3Array([Yard.JUNCTION, Yard.HELIPAD])])
	return out


static func run(host: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var from := 0
	var last := 999
	if args.has("wfrom"):
		from = int(args[args.find("wfrom") + 1])
	if args.has("wto"):
		last = int(args[args.find("wto") + 1])
	var p: Player = Game.player
	Engine.time_scale = 3.0
	var total_stuck := 0
	var report: PackedStringArray = []
	var all := routes()
	for ri in range(all.size()):
		if ri < from or ri > last:
			continue
		var r: Array = all[ri]
		var name: String = r[0]
		var pts: PackedVector3Array = r[1]
		if pts.size() < 2:
			continue
		p.velocity = Vector3.ZERO
		p.global_position = pts[0] + Vector3(0, 0.15, 0)
		await host.get_tree().physics_frame
		var walked := 0.0
		var stuck_here := 0
		for k in range(1, pts.size()):
			var target := pts[k]
			var tries := 0
			var stuck_k := 0
			while tries < 400 and stuck_k < 3:
				tries += 1
				var to := target - p.global_position
				to.y = 0.0
				if to.length() < 0.6:
					break
				p.rotation.y = atan2(-to.x, -to.z)
				var before := p.global_position
				var t := 0.0
				Input.action_press(&"move_forward")
				while t < STUCK_T and (target - p.global_position).length() > 0.6:
					await host.get_tree().physics_frame
					t += host.get_physics_process_delta_time()
					to = target - p.global_position
					to.y = 0.0
					p.rotation.y = atan2(-to.x, -to.z)
				Input.action_release(&"move_forward")
				var moved := Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length()
				walked += moved
				if moved < STUCK_D and (target - p.global_position).length() > 0.6:
					stuck_here += 1
					stuck_k += 1
					total_stuck += 1
					var at := p.global_position
					print("[walk] ЗАСТРЯЛ [%s] у (%.1f, %.1f, %.1f) → цель (%.1f, %.1f)  рядом: %s" % [name, at.x, at.y, at.z,
						target.x, target.z, _near(host, at)])
					var dir := (target - at)
					dir.y = 0.0
					p.global_position = at + dir.normalized() * minf(1.5, dir.length()) + Vector3(0, 0.3, 0)
					await host.get_tree().physics_frame
			if p.global_position.y < -2.0:
				report.append("ПРОВАЛИЛСЯ [%s] у %s" % [name, str(p.global_position)])
				break
		print("[walk] %-22s пройдено %.0f м, застреваний %d" % [name, walked, stuck_here])
	Engine.time_scale = 1.0
	for line in report:
		print("[walk] ", line)
	print("[walk] итого застреваний: %d" % total_stuck)


## Что за тела рядом с точкой застревания (до 1.2 м).
static func _near(host: Node, at: Vector3) -> String:
	var space := Game.player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	q.shape = sh
	q.transform = Transform3D(Basis(), at + Vector3(0, 0.6, 0))
	q.exclude = [Game.player.get_rid()]
	var names: PackedStringArray = []
	for hit: Dictionary in space.intersect_shape(q, 6):
		var c: Object = hit.get("collider")
		if c is Node3D and String((c as Node).name).begins_with("@StaticBody3D@3766"):
			continue   # земля
		if c is Node3D:
			names.append(PathAudit.describe(c as Node3D))
			continue
		if c is Node:
			var n := c as Node
			var label := "%s(%s)" % [n.name, n.get_class()]
			var par := n.get_parent()
			if par != null:
				label += "<" + String(par.name)
			var s: Script = n.get_script()
			if s != null:
				label += " " + s.resource_path.get_file()
			if c is Node3D:
				label += " @" + str((c as Node3D).global_position.snapped(Vector3.ONE * 0.1))
			names.append(label)
	return ", ".join(names) if not names.is_empty() else "—"
