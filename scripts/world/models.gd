class_name Models
extends RefCounted
## Готовые CC0-модели (Kenney Survival / Furniture, KayKit Furniture Bits) — реквизит и мелочи.
## spawn() ставит модель низом на точку, подгоняет масштаб по нужной высоте (паки сделаны в разных
## масштабах), перекрашивает материалы нашим шейдером (приглушённо, с грязью) и по желанию даёт
## коробку столкновения. Сцены, материалы и габариты кэшируются — повторные модели почти бесплатны.

const ROOT := "res://assets/models/"
const SHADER := "res://assets/shaders/ps1_model.gdshader"

static var _scenes: Dictionary = {}
static var _bounds: Dictionary = {}
static var _mats: Dictionary = {}
static var _grime: Dictionary = {}
static var _shader: Shader


## id — путь внутри assets/models без расширения ("survival/barrel").
## height — высота в метрах (≤0 — масштаб scale). opts:
##   scale: float — явный масштаб; tint: Color; collide: bool; shadow: bool; grime: float (0..1);
##   bright: float — яркость (снег светлее, 0.5 — по умолчанию); sat: float — насыщенность (0.6; запечённым — 1.0);
##   tilt: Vector3 — доп. поворот в градусах (x, z) для «упавших» вещей; center: bool (по умолчанию true).
static func spawn(parent: Node, id: String, pos: Vector3, yaw_deg := 0.0, height := -1.0, opts := {}) -> Node3D:
	var ps := _scene(id)
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	var bb := _bounds_of(id, inst)
	var s: float = opts.get("scale", 1.0)
	if height > 0.0 and bb.size.y > 0.001:
		s = height / bb.size.y
	var root := Node3D.new()
	root.name = id.get_file()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	if opts.has("tilt"):
		var t: Vector3 = opts["tilt"]
		root.rotation_degrees.x = t.x
		root.rotation_degrees.z = t.z
	inst.scale = Vector3.ONE * s
	var ctr := bb.get_center()
	var off := Vector3(ctr.x, bb.position.y, ctr.z) if opts.get("center", true) else Vector3(0, bb.position.y, 0)
	inst.position = -off * s
	root.add_child(inst)
	_restyle(inst, opts)
	if opts.get("collide", false):
		var body := StaticBody3D.new()
		body.collision_layer = Geo.LAYER_WORLD
		body.collision_mask = 0
		var sz := bb.size * s
		body.add_child(Geo.box_shape(sz, Vector3(0, sz.y * 0.5, 0)))
		root.add_child(body)
	parent.add_child(root)
	return root


## Габариты модели в метрах при заданной высоте — для раскладки.
static func size_of(id: String, height := -1.0) -> Vector3:
	var ps := _scene(id)
	if ps == null:
		return Vector3.ZERO
	var inst := ps.instantiate() as Node3D
	var bb := _bounds_of(id, inst)
	inst.free()
	return bb.size * (height / bb.size.y if height > 0.0 else 1.0)


static func _scene(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var ps: PackedScene = null
	for ext: String in [".glb", ".gltf"]:
		var path: String = ROOT + id + ext
		if FileAccess.file_exists(path + ".import") and ResourceLoader.exists(path):
			ps = load(path) as PackedScene
			if ps != null:
				break
		if FileAccess.file_exists(path):
			var gltf := GLTFDocument.new()
			var state := GLTFState.new()
			if gltf.append_from_file(path, state) == OK:
				var node := gltf.generate_scene(state)
				if node != null:
					ps = PackedScene.new()
					if ps.pack(node) == OK:
						node.free()
						break
					node.free()
					ps = null
	if ps == null:
		push_warning("Models: нет модели %s" % id)
	_scenes[id] = ps
	return ps


static func _bounds_of(id: String, inst: Node3D) -> AABB:
	if _bounds.has(id):
		return _bounds[id]
	var bb := AABB()
	var first := true
	for mi in _meshes(inst):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != inst:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	_bounds[id] = bb
	return bb


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			out.append(c)
		for ch in c.get_children():
			stack.append(ch)
	return out


static func _restyle(inst: Node3D, opts: Dictionary) -> void:
	var tint: Color = opts.get("tint", Color.WHITE)
	var grime: float = opts.get("grime", 0.7)
	var bright: float = opts.get("bright", 0.5)
	var shadow: bool = opts.get("shadow", true)
	for mi in _meshes(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var src := mi.get_active_material(si)
			mi.set_surface_override_material(si, _convert(src, tint, grime, bright, opts.get("sat", 0.6)))


static func _convert(src: Material, tint: Color, grime: float, bright := 0.5, sat := 0.6) -> ShaderMaterial:
	var key := "%d|%s|%.2f|%.2f|%.2f" % [src.get_instance_id() if src != null else 0, tint.to_html(), grime, bright, sat]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load(SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader
	var col := Color.WHITE
	var tex: Texture2D = null
	var name := ""
	if src is BaseMaterial3D:
		var bm := src as BaseMaterial3D
		col = bm.albedo_color
		tex = bm.albedo_texture
		name = bm.resource_name.to_lower()
	m.set_shader_parameter(&"albedo", Color(col.r * tint.r, col.g * tint.g, col.b * tint.b, 1.0))
	if tex != null:
		m.set_shader_parameter(&"tex", tex)
		m.set_shader_parameter(&"use_tex", 1.0)
	# Грязь по типу материала: дерево — волокна, металл — ржавчина, остальное — бетонная пыль
	var g := "tex_concrete.png"
	if "wood" in name or "plank" in name or "brown" in name:
		g = "tex_wood.png"
	elif "metal" in name or "iron" in name or "steel" in name or "grey" in name or "dark" in name:
		g = "tex_rust.png"
	elif "fabric" in name or "cloth" in name or "pillow" in name or "carpet" in name:
		g = "tex_cloth.png"
	if not _grime.has(g):
		_grime[g] = load("res://assets/textures/" + g)
	m.set_shader_parameter(&"grime", _grime[g])
	m.set_shader_parameter(&"use_grime", grime)
	m.set_shader_parameter(&"value", bright)
	m.set_shader_parameter(&"saturation", sat)
	_mats[key] = m
	return m
