class_name OverlapAudit
extends RefCounted
## Поиск наложений «текстура на текстуру»: тонкая плоскость (панель, стекло, табличка, ковёр) лежит почти
## в той же плоскости, что грань другой геометрии, и перекрывает её площадью — мерцание (z-fighting)
## или одно закрывает другое. Только для отладки: печатает пары, худшие — первыми.

const THIN := 0.08        ## тоньше — «плоскость»
const GAP := 0.012        ## ближе к грани — кандидат на мерцание/перекрытие
const MIN_AREA := 0.02    ## м², меньше — не заметно


static func run(root: Node, center := Vector3.ZERO, radius := 1e9, limit := 40) -> Array:
	var items: Array = []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or g.layers == 0 or g is CPUParticles3D or g is GPUParticles3D or g is Label3D:
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		if bb.size.length() > 40.0 or bb.get_center().distance_to(center) > radius:
			continue
		var b := g.global_transform.basis
		var aligned := absf(absf(b.x.normalized().dot(Vector3.RIGHT)) - 1.0) < 0.02 or absf(absf(b.x.normalized().dot(Vector3.BACK)) - 1.0) < 0.02
		if not aligned:
			continue   # повёрнутые произвольно — AABB врёт, пропускаем
		items.append([g, bb])
	# Сетка 2 м — проверяем соседей
	var grid := {}
	for i in items.size():
		var bb: AABB = items[i][1]
		var key := Vector3i(floori(bb.get_center().x / 2.0), floori(bb.get_center().y / 2.0), floori(bb.get_center().z / 2.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	var out: Array = []
	for i in items.size():
		var a: AABB = items[i][1]
		var ax := _thin_axis(a)
		if ax < 0:
			continue
		var ca := a.get_center()
		var key := Vector3i(floori(ca.x / 2.0), floori(ca.y / 2.0), floori(ca.z / 2.0))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for j: int in grid.get(key + Vector3i(dx, dy, dz), []):
						if j == i:
							continue
						var b: AABB = items[j][1]
						var plane := ca[ax]
						var d := minf(absf(plane - b.position[ax]), absf(plane - b.end[ax]))
						if _thin_axis(b) == ax:
							d = absf(plane - b.get_center()[ax])
						# мерцание — почти в одной плоскости; перекрытие — тонкое поверх тонкого (до 3 см)
						var both_thin := _thin_axis(b) == ax
						if not (d < 0.004 or (both_thin and d < 0.03)):
							continue
						var o1 := (ax + 1) % 3
						var o2 := (ax + 2) % 3
						var w1 := minf(a.end[o1], b.end[o1]) - maxf(a.position[o1], b.position[o1])
						var w2 := minf(a.end[o2], b.end[o2]) - maxf(a.position[o2], b.position[o2])
						if w1 <= 0.0 or w2 <= 0.0 or w1 * w2 < MIN_AREA:
							continue
						if _same_mat(items[i][0], items[j][0]):
							continue   # один материал впритык — шва не видно
						out.append([w1 * w2, d, items[i][0], items[j][0], ca])
	out.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var seen := {}
	var res: Array = []
	for e: Array in out:
		var k := str(mini((e[2] as Node).get_instance_id(), (e[3] as Node).get_instance_id())) + "_" + str(maxi((e[2] as Node).get_instance_id(), (e[3] as Node).get_instance_id()))
		if seen.has(k):
			continue
		seen[k] = true
		res.append(e)
		print("[ovl] S=%.2f d=%.3f at=%s  %s  ×  %s" % [e[0], e[1], (e[4] as Vector3).snapped(Vector3.ONE * 0.01), _desc(e[2]), _desc(e[3])])
		if res.size() >= limit:
			break
	print("[ovl] всего пар: %d (показано %d)" % [seen.size(), res.size()])
	return res


static func _thin_axis(bb: AABB) -> int:
	var s := bb.size
	if s.x < THIN and s.y > THIN * 2 and s.z > THIN * 2:
		return 0
	if s.y < THIN and s.x > THIN * 2 and s.z > THIN * 2:
		return 1
	if s.z < THIN and s.x > THIN * 2 and s.y > THIN * 2:
		return 2
	return -1


static func _mat_of(g: GeometryInstance3D) -> Material:
	if g.material_override != null:
		return g.material_override
	var mi := g as MeshInstance3D
	if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		return mi.mesh.surface_get_material(0)
	return null


static func _same_mat(a: GeometryInstance3D, b: GeometryInstance3D) -> bool:
	var ma := _mat_of(a)
	var mb := _mat_of(b)
	if ma == null or mb == null:
		return false
	if ma == mb:
		return true
	var sa := ma as StandardMaterial3D
	var sb := mb as StandardMaterial3D
	return sa != null and sb != null and sa.albedo_color.is_equal_approx(sb.albedo_color) and sa.albedo_texture == sb.albedo_texture


static func _desc(g: GeometryInstance3D) -> String:
	var m := _mat_of(g)
	var col := ""
	if m is StandardMaterial3D:
		col = str((m as StandardMaterial3D).albedo_color.to_html(false))
	var mesh_s := ""
	var mi := g as MeshInstance3D
	if mi != null and mi.mesh is BoxMesh:
		mesh_s = "Box" + str((mi.mesh as BoxMesh).size.snapped(Vector3.ONE * 0.01))
	elif mi != null and mi.mesh != null:
		mesh_s = mi.mesh.get_class()
	return "%s/%s %s #%s" % [g.get_parent().name, g.name, mesh_s, col]
