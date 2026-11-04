class_name StaticBatch
extends Node3D
## Склейка неподвижной геометрии. Двор и дом собраны из сотен отдельных блоков (Geo.block, MeshKit),
## и каждый — свой вызов отрисовки: 1600–2200 за кадр, на слабых видеокартах это и есть лаг.
## Здесь одинаковые по материалу меши в клетке CELL×CELL склеиваются в один. Исходники остаются
## в сцене (их тела, ссылки и сигналы живы), но не рисуются: layers = 0. Если код потом прячет,
## показывает или удаляет исходник, клетка тихо пересобирается.
##
## Не трогаем: всё под узлами со скриптом (предметы, существа, двери-интерактивы), под светом
## (лампочки гаснут вместе с лампой), всё, на что код держит ссылку (петли дверей, сугробы,
## занавески — их двигают), прозрачное и текстурированное в координатах модели.

const CELL := 12.0

var _cells: Dictionary = {}      ## ключ → {mi, src: Array, mat, layers, shadow}
var _dirty: Dictionary = {}
var _flush_queued := false
static var _arrays_cache: Dictionary = {}   ## id меша → массивы поверхностей (у примитивов генерация дорогая)


static func build(root: Node3D) -> StaticBatch:
	_arrays_cache.clear()
	var sb := StaticBatch.new()
	sb.name = "StaticBatch"
	sb.top_level = true
	root.add_child(sb)
	sb.global_transform = Transform3D.IDENTITY
	var t0 := Time.get_ticks_msec()
	var n := sb._collect(root)
	if OS.is_debug_build():
		print("[batch] склеено %d мешей в %d клеток за %d мс" % [n, sb._cells.size(), Time.get_ticks_msec() - t0])
	return sb


func _collect(root: Node3D) -> int:
	var pinned := _pinned_nodes(root)
	var containers := {root: true}
	if Game.yard != null:
		containers[Game.yard] = true
	var merged := 0
	var reasons: Dictionary = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var why := _eligible(mi, root, containers, pinned)
		if why != "":
			reasons[why] = int(reasons.get(why, 0)) + 1
			continue
		var mat := mi.get_active_material(0)
		var cell := "%d,%d" % [floori(mi.global_position.x / CELL), floori(mi.global_position.z / CELL)]
		# В доме клетка — комната, а не квадрат 12 м: тогда заслонки в срубе отсекают целые комнаты,
		# чьих окон не видно (склейка на весь дом всегда «торчала» в каком-нибудь окне)
		if root.has_method(&"is_pos_inside_house") and root.call(&"is_pos_inside_house", mi.global_position):
			cell = "room:" + String(root.call(&"zone_at", mi.global_position))
		var key := "%d|%d|%d|%s" % [mat.get_instance_id(), mi.layers, mi.cast_shadow, cell]
		if not _cells.has(key):
			_cells[key] = {"mi": null, "src": [], "mat": mat, "layers": mi.layers, "shadow": mi.cast_shadow}
		(_cells[key]["src"] as Array).append(mi)
		mi.set_meta(&"batch_layers", mi.layers)
		mi.layers = 0                       # исходник больше не рисуется — рисует склейка
		mi.visibility_changed.connect(_mark.bind(key))
		mi.tree_exiting.connect(_mark.bind(key))
		merged += 1
	for key in _cells:
		_rebuild(key)
	if OS.is_debug_build():
		var ra: Array = []
		for k in reasons:
			ra.append([reasons[k], k])
		ra.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for i in range(mini(14, ra.size())):
			print("[batch-skip] %4d  %s" % [ra[i][0], ra[i][1]])
	return merged


## Узлы, на которые скрипты держат ссылки: их (и всё под ними) код может двигать или менять.
func _pinned_nodes(root: Node) -> Dictionary:
	var out: Dictionary = {}
	var holders: Array[Node] = [Game]
	for n: Node in root.find_children("*", "", true, false):
		if n.get_script() != null:
			holders.append(n)
	if root.get_script() != null:
		holders.append(root)
	for h in holders:
		for prop: Dictionary in h.get_property_list():
			if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			_pin_value(h.get(prop["name"]), out, 0)
	return out


func _pin_value(v: Variant, out: Dictionary, depth: int) -> void:
	if depth > 2:
		return
	if typeof(v) == TYPE_OBJECT and not is_instance_valid(v):
		return
	if v is Node:
		if is_instance_valid(v):
			out[v] = true
	elif v is Array:
		for e in v:
			_pin_value(e, out, depth + 1)
	elif v is Dictionary:
		for e in (v as Dictionary).values():
			_pin_value(e, out, depth + 1)


func _eligible(mi: MeshInstance3D, root: Node, containers: Dictionary, pinned: Dictionary) -> String:
	if mi.mesh == null or mi.get_script() != null or not mi.is_visible_in_tree() or mi.layers == 0:
		return "hidden/script"
	if mi.mesh.get_surface_count() != 1 or (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0) or mi.skeleton != NodePath(""):
		return "surfaces"
	if mi.transparency > 0.0 or mi.visibility_range_end > 0.0 or pinned.has(mi):
		return "pinned/range"
	var lname := String(mi.name).to_lower()
	for bad in ["door", "hinge", "curtain", "lamp", "bulb", "flag", "glow", "flame", "fire", "beam"]:
		if lname.contains(bad):
			return "name:" + bad
	var mat := mi.get_active_material(0)
	if mat == null or not _opaque(mat):
		return "material:" + (mat.resource_name if mat != null and mat.resource_name != "" else (str(mat.get_class()) if mat != null else "null"))
	var p := mi.get_parent()
	while p != null and p != root:
		if containers.has(p):
			p = p.get_parent()
			continue
		if pinned.has(p):
			return "parent pinned"
		if p.get_script() != null:
			var sname: String = (p.get_script() as Script).resource_path.get_file()
			if sname in ["station_lore.gd", "corpus_dressing.gd", "site_dressing.gd", "life_dressing.gd", "day_pois.gd"]:
				p = p.get_parent()
				continue
			return "parent script:" + sname
		if p is Light3D or p is RigidBody3D or p is AnimatableBody3D or p is CharacterBody3D or p is VehicleBody3D or not (p is Node3D):
			return "parent " + p.get_class()
		var pn := String(p.name).to_lower()
		for bad in ["door", "hinge", "curtain", "lamp", "bulb", "flag"]:
			if pn.contains(bad):
				return "parent name:" + bad
		p = p.get_parent()
	return "" if p == root else "outside"


## Непрозрачный и не привязанный к координатам модели материал.
func _opaque(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		return not bm.uv1_triplanar or bm.uv1_world_triplanar   # трипланар в координатах модели «поедет»
	if mat is ShaderMaterial:
		var sh := (mat as ShaderMaterial).shader
		if sh == null:
			return false
		var code := sh.code
		if code.contains("ALPHA") or code.contains("blend_add") or code.contains("blend_mul") or code.contains("depth_draw_never"):
			return false
		# ps1_creature текстурирует в координатах модели: после склейки текстура «поедет».
		var ut: Variant = (mat as ShaderMaterial).get_shader_parameter(&"use_tex")
		if code.contains("opos") and ut != null and float(ut) > 0.5:
			return false
		if code.contains("NODE_POSITION") or code.contains("MODEL_MATRIX[3]"):
			return false
		return true
	return false


func _mark(key: String) -> void:
	_dirty[key] = true
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	for key in _dirty:
		_rebuild(key)
	_dirty.clear()


func _rebuild(key: String) -> void:
	var cell: Dictionary = _cells[key]
	var src: Array = cell["src"]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var alive: Array = []
	for m in src:
		if not is_instance_valid(m):
			continue
		alive.append(m)
		var mi := m as MeshInstance3D
		if not mi.is_inside_tree() or not mi.is_visible_in_tree():
			continue
		var arr := _arrays(mi.mesh)
		var xf := mi.global_transform
		var nb := xf.basis.inverse().transposed()
		var base := verts.size()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: Variant = arr[Mesh.ARRAY_NORMAL]
		var cc: Variant = arr[Mesh.ARRAY_COLOR]
		var uu: Variant = arr[Mesh.ARRAY_TEX_UV]
		for i in range(v.size()):
			verts.append(xf * v[i])
			norms.append((nb * (nn as PackedVector3Array)[i]).normalized() if nn != null else Vector3.UP)
			cols.append((cc as PackedColorArray)[i] if cc != null else Color.WHITE)
			uvs.append((uu as PackedVector2Array)[i] if uu != null else Vector2.ZERO)
		var ii: Variant = arr[Mesh.ARRAY_INDEX]
		var tri := PackedInt32Array()
		if ii != null and (ii as PackedInt32Array).size() > 0:
			tri = ii
		else:
			tri.resize(v.size())
			for i in range(v.size()):
				tri[i] = i
		var mirror := xf.basis.determinant() < 0.0   # зеркальный масштаб: разворачиваем обход
		for t in range(0, tri.size() - 2, 3):
			idx.append(base + tri[t])
			if mirror:
				idx.append(base + tri[t + 2])
				idx.append(base + tri[t + 1])
			else:
				idx.append(base + tri[t + 1])
				idx.append(base + tri[t + 2])
	cell["src"] = alive
	var old: MeshInstance3D = cell["mi"]
	if verts.is_empty():
		if old != null:
			old.queue_free()
			cell["mi"] = null
		return
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var mi2 := old if old != null else MeshInstance3D.new()
	mi2.mesh = am
	mi2.material_override = cell["mat"]
	mi2.layers = int(cell["layers"])
	mi2.cast_shadow = cell["shadow"]
	if old == null:
		add_child(mi2)
		cell["mi"] = mi2


static func _arrays(mesh: Mesh) -> Array:
	var id := mesh.get_instance_id()
	if not _arrays_cache.has(id):
		_arrays_cache[id] = mesh.surface_get_arrays(0)
	return _arrays_cache[id]
