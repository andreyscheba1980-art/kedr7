class_name Footprints
extends RefCounted
## Отпечатки: плоские наклейки с рисунком следа вместо тёмных коробок.
##   &"snow"  — вдавленный след валенка в снегу (синеватая тень, не чёрный);
##   &"bare"  — босая ступня (чужие следы в снегу);
##   &"wet"   — мокрый след на полу (тёмный, с бликом).
## Все один-два меша на тип: PlaneMesh общий, материалы общие.

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
static var _mesh: Dictionary = {}

const SIZES := {&"snow": Vector2(0.15, 0.32), &"bare": Vector2(0.13, 0.27), &"wet": Vector2(0.13, 0.3), &"paw": Vector2(0.075, 0.085)}


## Один отпечаток. pos — точка на поверхности (y — высота поверхности), yaw — направление шага.
static func make(kind: StringName, pos: Vector3, yaw: float, left: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _plane(kind)
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.006, 0)
	mi.rotation.y = yaw
	if left:
		mi.scale.x = -1.0
	return mi


## Цепочка следов вдоль ломаной: шаг ~0.48 м, левый-правый со сдвигом.
static func trail(parent: Node, kind: StringName, route: PackedVector3Array, y := 0.0, stride := 0.48, side_off := 0.11) -> Node3D:
	var root := Node3D.new()
	root.name = "Footprints_%s" % kind
	parent.add_child(root)
	var left := false
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var d := b - a
		d.y = 0.0
		var seg := d.length()
		if seg < 0.01:
			continue
		d /= seg
		var side := Vector3(-d.z, 0, d.x)
		var t := 0.0
		while t < seg:
			var p := a + d * t + side * (side_off if left else -side_off)
			p.y = y
			root.add_child(make(kind, p, atan2(d.x, d.z), left))
			left = not left
			t += stride
	return root


static func material(kind: StringName) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		&"snow", &"bare":
			m.albedo_color = Color(0.22, 0.28, 0.42, 0.75)    # тень во вмятине: синее и темнее снега, но не дыра
			m.roughness = 1.0
		_:
			m.albedo_color = Color(0.07, 0.06, 0.05, 0.8)
			m.roughness = 0.15
			m.metallic_specular = 0.8
	_mats[kind] = m
	return m


static func _plane(kind: StringName) -> PlaneMesh:
	if _mesh.has(kind):
		return _mesh[kind]
	var pm := PlaneMesh.new()
	pm.size = SIZES.get(kind, Vector2(0.14, 0.3))
	_mesh[kind] = pm
	return pm


## Рисунок следа: валенок — овал носка и пятка с перемычкой; босая ступня — пятка, свод, подушечка и пальцы.
static func _texture(kind: StringName) -> ImageTexture:
	var key := kind if kind == &"bare" or kind == &"paw" else &"boot"
	if _tex.has(key):
		return _tex[key]
	var w := 24
	var h := 50
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var blobs: Array
	if key == &"paw":     # лисий след: подушка и четыре пальца
		blobs = [[12.0, 33.0, 7.0, 8.0], [7.0, 17.0, 3.2, 4.2], [17.0, 17.0, 3.2, 4.2], [9.5, 8.0, 3.0, 4.0], [14.5, 8.0, 3.0, 4.0]]
	elif key == &"bare":
		blobs = [[12.0, 41.0, 6.0, 7.5], [10.5, 29.0, 4.5, 7.5], [12.5, 17.0, 8.0, 6.5],
			[5.5, 7.0, 2.6, 3.0], [9.5, 5.0, 2.4, 2.7], [13.5, 5.2, 2.1, 2.4], [17.0, 6.8, 1.8, 2.1], [19.8, 9.4, 1.5, 1.8]]
	else:
		blobs = [[12.0, 14.0, 9.0, 12.0], [12.0, 30.0, 6.5, 6.0], [12.0, 41.0, 8.0, 7.5]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var a := 0.0
			for bl: Array in blobs:
				var dx := (float(x) - float(bl[0])) / float(bl[2])
				var dy := (float(y) - float(bl[1])) / float(bl[3])
				a = maxf(a, clampf(1.5 - (dx * dx + dy * dy) * 1.5, 0.0, 1.0))
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, minf(a, 1.0) * rng.randf_range(0.75, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex
