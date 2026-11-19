class_name Footprints
extends RefCounted
## Отпечатки на снегу и полу (gl_compatibility, без z-fighting и «синих картонок»).
##   &"snow"  — вдавленный след валенка (blend_mul затемняет реальный цвет снега);
##   &"bare"  — босая ступня (чужие следы в снегу);
##   &"paw"   — след лисы/зверя;
##   &"wet"   — мокрый след на полу дома (тёмный, с бликом).
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
	var lift := 0.014 if _is_snow_kind(kind) else 0.006
	mi.position = pos + Vector3(0, lift, 0)
	mi.rotation.y = yaw
	if left:
		mi.scale.x = -1.0
	return mi


## Цепочка следов вдоль ломаной: шаг ~0.48 м, левый-правый со сдвигом.
## Для уличных следов при y == 0.0 автоматически притягивается к Terrain.height(x, z).
static func trail(parent: Node, kind: StringName, route: PackedVector3Array, y := 0.0, stride := 0.48, side_off := 0.11) -> Node3D:
	var root := Node3D.new()
	root.name = "Footprints_%s" % kind
	parent.add_child(root)
	var left := false
	var use_terrain := _is_snow_kind(kind) and absf(y) < 0.001
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
			p.y = Terrain.height(p.x, p.z) if use_terrain else y
			root.add_child(make(kind, p, atan2(d.x, d.z), left))
			left = not left
			t += stride
	return root


static func _is_snow_kind(kind: StringName) -> bool:
	return kind == &"snow" or kind == &"bare" or kind == &"paw"


static func material(kind: StringName) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.render_priority = 2
	if _is_snow_kind(kind):
		# BLEND_MODE_MUL: белый фон текстуры невидим, тень вмятины умножается на реальный
		# освещённый снег (синий под луной, жёлтый под фонарём) — никаких «синих наклеек»!
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.disable_fog = true
		m.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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


## Рисунок следа: для снежных (MUL) белый фон и затемнение во вмятине; для мокрых — альфа-маска.
static func _texture(kind: StringName) -> ImageTexture:
	var snow_mul := _is_snow_kind(kind)
	var shape := kind if kind == &"bare" or kind == &"paw" else &"boot"
	var key := StringName("%s_%s" % [shape, "mul" if snow_mul else "alpha"])
	if _tex.has(key):
		return _tex[key]
	var w := 24
	var h := 50
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1) if snow_mul else Color(1, 1, 1, 0))
	var blobs: Array
	if shape == &"paw":     # лисий след: подушка и четыре пальца
		blobs = [[12.0, 33.0, 7.0, 8.0], [7.0, 17.0, 3.2, 4.2], [17.0, 17.0, 3.2, 4.2], [9.5, 8.0, 3.0, 4.0], [14.5, 8.0, 3.0, 4.0]]
	elif shape == &"bare":
		blobs = [[12.0, 41.0, 6.0, 7.5], [10.5, 29.0, 4.5, 7.5], [12.5, 17.0, 8.0, 6.5],
			[5.5, 7.0, 2.6, 3.0], [9.5, 5.0, 2.4, 2.7], [13.5, 5.2, 2.1, 2.4], [17.0, 6.8, 1.8, 2.1], [19.8, 9.4, 1.5, 1.8]]
	else:
		blobs = [[12.0, 14.0, 9.0, 12.0], [12.0, 30.0, 6.5, 6.0], [12.0, 41.0, 8.0, 7.5]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var depth_col := Color(0.46, 0.49, 0.54, 1.0) if shape == &"bare" else Color(0.54, 0.57, 0.62, 1.0)
	for py in h:
		for px in w:
			var a := 0.0
			for bl: Array in blobs:
				var dx := (float(px) - float(bl[0])) / float(bl[2])
				var dy := (float(py) - float(bl[1])) / float(bl[3])
				a = maxf(a, clampf(1.35 - (dx * dx + dy * dy) * 1.45, 0.0, 1.0))
			if a > 0.0:
				var grain := rng.randf_range(0.82, 1.0)
				if snow_mul:
					# Мягкий градиент тени внутри следа (в MUL белый = 100% прозрачно)
					var k := clampf(a * grain, 0.0, 1.0)
					img.set_pixel(px, py, Color(1, 1, 1, 1).lerp(depth_col, k))
				else:
					img.set_pixel(px, py, Color(1, 1, 1, minf(a, 1.0) * grain))
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex
