class_name Geo
extends RefCounted
## Хелперы блочной геометрии. Всё временное: потом меняем на модели, сохраняя позиции.

const LAYER_WORLD := 1
## Только для луча взаимодействия: игрок сквозь такие тела проходит (следы на полу, надписи).
const LAYER_INTERACT := 8


static func box_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi


## Блок. collide=false — только визуал, без тела.
static func block(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := box_mesh(size, mat)
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	body.add_child(mi)
	body.add_child(box_shape(size))
	return body


## Только тело-коробка без меша — под модель, у которой своя форма.
static func collider(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	body.add_child(box_shape(size))
	return body


## Блок, повёрнутый вокруг Y (для верёвок лееров и косых досок).
static func block_rotated(parent: Node, size: Vector3, pos: Vector3, yaw: float, mat: Material) -> MeshInstance3D:
	var mi := box_mesh(size, mat)
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func box_shape(size: Vector3, offset := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	return cs


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.position = pos
	parent.add_child(body)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	body.add_child(cs)
	return body


static func interactable(parent: Node, size: Vector3, pos: Vector3, mat: Material, prompt: String, on_use: Callable) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt
	it.position = pos
	it.collision_layer = LAYER_WORLD
	parent.add_child(it)
	if mat != null:
		it.add_child(box_mesh(size, mat))
	it.add_child(box_shape(size))
	if on_use.is_valid():
		it.used.connect(on_use)
	return it


static func omni(parent: Node, pos: Vector3, light_range: float, energy: float, color: Color) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = light_range
	l.light_energy = energy
	l.light_color = color
	parent.add_child(l)
	return l


## Маленькая светящаяся лампочка — дочерний узел света, гаснет вместе с ним.
static func bulb(light: Node3D, glow_key: StringName, radius := 0.05) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	mi.mesh = sm
	mi.material_override = Palette.glow(glow_key)
	light.add_child(mi)


## Удалить узел через sec секунд. Таймер живёт внутри самого узла: если узел исчез раньше
## (смена фазы, рестарт), таймер исчезает вместе с ним — никаких лямбд с «мёртвыми» захватами.
static func free_after(node: Node, sec: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = sec
	t.autostart = true
	node.add_child(t)
	t.timeout.connect(node.queue_free)
