class_name PathAudit
extends RefCounted
## Что физически стоит на тропах: все тела мира, чьи формы пересекают коридор тропы (±HALF м).
## Плюс «висящие» и «утонувшие» объекты двора: низ меша выше/ниже земли под ним.

const HALF := 0.75


static func run(host: Node) -> void:
	var paths: Array = Game.yard.get(&"_all_paths")
	var space := Game.player.get_world_3d().direct_space_state
	var seen: Dictionary = {}
	var hits := 0
	for pi in range(paths.size()):
		var pts: PackedVector3Array = paths[pi]
		for k in range(pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var seg := b - a
			seg.y = 0.0
			var len := seg.length()
			# Ящик вдоль отрезка: ширина 2*HALF, высота 1.6 (уровень тела игрока), без 1 м у концов (там цели)
			if len < 2.5:
				continue
			var box := BoxShape3D.new()
			box.size = Vector3(HALF * 2.0, 1.4, len - 2.0)
			var mid := (a + b) * 0.5 + Vector3(0, 0.85, 0)
			var basis := Basis.looking_at(seg.normalized(), Vector3.UP)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = Transform3D(basis, mid)
			q.collision_mask = 1
			q.exclude = [Game.player.get_rid()]
			for hit: Dictionary in space.intersect_shape(q, 32):
				var c: Object = hit.get("collider")
				if not (c is Node3D) or seen.has(c):
					continue
				seen[c] = true
				hits += 1
				print("[path] тропа %d отрезок %d: %s" % [pi + 1, k + 1, describe(c as Node3D)])
	print("[path] тел на тропах: %d" % hits)
	_floaters(host)


static func describe(n: Node3D) -> String:
	var parts: PackedStringArray = []
	parts.append("%s(%s) @%s" % [n.name, n.get_class(), str(n.global_position.snapped(Vector3.ONE * 0.1))])
	var s: Script = n.get_script()
	if s != null:
		parts.append(s.resource_path.get_file())
	if n.has_meta(&"prompt") or "prompt" in n:
		var pr: Variant = n.get(&"prompt")
		if pr is String and pr != "":
			parts.append("«%s»" % pr)
	var p := n.get_parent()
	if p != null and not String(p.name).begins_with("@"):
		parts.append("в " + String(p.name))
	for ch in n.find_children("*", "MeshInstance3D", true, false):
		var mi := ch as MeshInstance3D
		if mi.mesh != null:
			var nm := mi.mesh.resource_name if mi.mesh.resource_name != "" else mi.mesh.get_class()
			parts.append("меш %s %s" % [nm, str(mi.get_aabb().size.snapped(Vector3.ONE * 0.1))])
			break
	for ch in n.get_children():
		if ch is CollisionShape3D and (ch as CollisionShape3D).shape != null:
			var sh := (ch as CollisionShape3D).shape
			var sz := ""
			if sh is BoxShape3D:
				sz = str((sh as BoxShape3D).size.snapped(Vector3.ONE * 0.1))
			elif sh is CylinderShape3D:
				sz = "r%.2f h%.1f" % [(sh as CylinderShape3D).radius, (sh as CylinderShape3D).height]
			elif sh is SphereShape3D:
				sz = "r%.2f" % (sh as SphereShape3D).radius
			parts.append("форма %s %s" % [sh.get_class(), sz])
			break
	return "  ".join(parts)


## Меши во дворе, у которых низ висит над тем, что под ними, или ушёл в землю глубоко.
static func _floaters(host: Node) -> void:
	var space := Game.player.get_world_3d().direct_space_state
	var n := 0
	for node: Node in Game.yard.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var bb := mi.global_transform * mi.get_aabb()
		if bb.size.x > 12.0 or bb.size.z > 12.0 or bb.size.y < 0.05:
			continue
		var bottom := bb.position.y
		if bottom < 0.04 or bottom > 1.2:
			continue
		var c := bb.get_center()
		# что под центром: луч вниз от низа меша
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, bottom - 0.01, c.z), Vector3(c.x, bottom - 3.0, c.z))
		var hit := space.intersect_ray(q)
		var ground_y := 0.0
		if not hit.is_empty():
			ground_y = (hit["position"] as Vector3).y
		var gap := bottom - ground_y
		if gap > 0.12:
			n += 1
			if n <= 40:
				var p := mi.get_parent()
				print("[float] висит %.2f м: %s (родитель %s) @%s размер %s" % [gap, mi.name, p.name if p else "-",
					str(c.snapped(Vector3.ONE * 0.1)), str(bb.size.snapped(Vector3.ONE * 0.1))])
	print("[float] висящих мешей: %d" % n)
