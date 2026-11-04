class_name SpruceNear
extends Node3D
## Ближние ели-карточки (SpruceMesh.near): по одному MultiMesh на вид, в них — только ели в радиусе REACH
## от камеры. Пересобираются, когда камера ушла на 6 м. Дальние ели — гранёные MultiMesh-ы двора и тайги:
## их шейдер сам прячет ели ближе NEAR_RANGE, а карточный — дальше. Так вблизи — лапы, вдали — дёшево,
## и вершины лап считаются только у трёх-пяти сотен елей вокруг игрока, а не у всего леса.

const CELL := 16.0
const REACH := SpruceMesh.NEAR_RANGE + 12.0
const MOVE := 6.0
const MAX_PER_VARIANT := 1500   ## страховка: обрезанная ель вблизи оставила бы дыру

static var _grid: Dictionary = {}     ## Vector2i → [PackedFloat32Array × 3 вида] — готовые 12 чисел на ель

var _mmi: Array[MultiMeshInstance3D] = []
var _last := Vector3(1e9, 0.0, 1e9)


static func clear_registry() -> void:
	_grid.clear()


## Ель в реестр: сразу в формате буфера MultiMesh (3×4 по строкам), чтобы пересборка была одним
## append_array на клетку, а не тысячей вызовов set_instance_transform.
static func register(variant: int, t: Transform3D) -> void:
	if variant < 0 or variant > 2:
		return
	var ck := Vector2i(floori(t.origin.x / CELL), floori(t.origin.z / CELL))
	if not _grid.has(ck):
		_grid[ck] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var b := t.basis
	var f := PackedFloat32Array([b.x.x, b.y.x, b.z.x, t.origin.x, b.x.y, b.y.y, b.z.y, t.origin.y, b.x.z, b.y.z, b.z.z, t.origin.z])
	var arr: Array = _grid[ck]
	var pa: PackedFloat32Array = arr[variant]
	pa.append_array(f)
	arr[variant] = pa          # PackedArray — по значению: записываем обратно


func _ready() -> void:
	name = "SpruceNear"
	for v in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = SpruceMesh.lod_near(v, SpruceMesh.NEAR_RANGE)
		mm.instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		_mmi.append(mi)
	Settings.changed.connect(_apply_quality)
	_apply_quality()


## Пресет графики сменили на ходу (или автоподстройка снизила): карточки включаются/выключаются,
## а гранёные ели перестают/начинают прятаться вблизи — без дыр в лесу.
func _apply_quality() -> void:
	var on := SpruceMesh.cards_enabled()
	visible = on
	set_process(on)
	SpruceMesh.set_near_cut(on)
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.quality >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in _mmi:
		mi.cast_shadow = shadow
	if on:
		_last = Vector3(1e9, 0.0, 1e9)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	if Vector2(p.x - _last.x, p.z - _last.z).length() < MOVE:
		return
	_last = p
	_rebuild(p)


func _rebuild(p: Vector3) -> void:
	var bufs := [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	# Клетку берём целиком, если её центр ближе REACH + MOVE + полудиагональ: ели в NEAR_RANGE от камеры
	# гарантированно попадут, пока она не уйдёт на MOVE.
	var lim := REACH + MOVE + CELL * 0.71
	var r := ceili(lim / CELL)
	var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var ck := c + Vector2i(dx, dz)
			var cell: Variant = _grid.get(ck)
			if cell == null:
				continue
			var cc := Vector2((ck.x + 0.5) * CELL, (ck.y + 0.5) * CELL)
			if cc.distance_to(Vector2(p.x, p.z)) > lim:
				continue
			for v in 3:
				var b: PackedFloat32Array = bufs[v]
				b.append_array((cell as Array)[v])
				bufs[v] = b
	for v in 3:
		var b: PackedFloat32Array = bufs[v]
		var n := mini(b.size() / 12, MAX_PER_VARIANT)
		if b.size() > n * 12:
			b.resize(n * 12)
		var mm := _mmi[v].multimesh
		mm.instance_count = n
		if n > 0:
			mm.buffer = b
