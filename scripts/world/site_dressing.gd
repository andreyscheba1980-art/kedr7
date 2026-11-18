class_name SiteDressing
extends RefCounted
## Обстановка дальних точек (лесосека, буровая, вышка): намёты у построек, пни и хлысты, следы
## полозьев, рабочий хлам, костровая бочка. Без неё точки — несколько коробок на пустом снегу.

static var _drift_mesh: Mesh
static var _track_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D
static var _soot_mat: StandardMaterial3D


static func _ground(c: Vector3, dx: float, dz: float) -> Vector3:
	var x := c.x + dx
	var z := c.z + dz
	return Vector3(x, Terrain.height(x, z), z)


static func _put(yard: Node3D, n: Node3D, c: Vector3, dx: float, dz: float, yaw_deg := 0.0) -> Node3D:
	n.position = _ground(c, dx, dz)
	n.rotation.y = deg_to_rad(yaw_deg)
	yard.add_child(n)
	return n


## Сугроб-намёт: сплюснутый эллипсоид, вытянутый по yaw.
static func drift(yard: Node3D, pos: Vector3, len: float, height: float, wid: float, yaw_deg := 0.0) -> void:
	if _drift_mesh == null:
		_drift_mesh = Props.snow_mound_mesh(0)
	var mi := MeshInstance3D.new()
	mi.mesh = _drift_mesh
	mi.material_override = Palette.m(&"drift")
	mi.position = pos + Vector3(0, -height * 0.45, 0)
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.scale = Vector3(len, height, wid)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	yard.add_child(mi)


## Плоское пятно (опилки, копоть, мазут) поверх снега.
static func patch(yard: Node3D, pos: Vector3, radius: float, kind: StringName) -> void:
	var mat: StandardMaterial3D
	if kind == &"dust":
		if _dust_mat == null:
			_dust_mat = _flat_mat(Color(0.34, 0.26, 0.17))
		mat = _dust_mat
	else:
		if _soot_mat == null:
			_soot_mat = _flat_mat(Color(0.07, 0.07, 0.08))
		mat = _soot_mat
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 9
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.03, 0)
	mi.scale = Vector3(1.0, 1.0, 0.7)
	mi.rotation.y = pos.x * 0.37
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	yard.add_child(mi)


static func _flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m


## Две колеи полозьев от точки a к b, чуть темнее снега: показывают, откуда приехали.
static func tracks(yard: Node3D, a: Vector3, b: Vector3) -> void:
	if _track_mat == null:
		_track_mat = _flat_mat(Color(0.30, 0.37, 0.46))
	var dir := b - a
	dir.y = 0.0
	var steps := maxi(2, int(dir.length() / 4.0))
	var side := Vector3(-dir.z, 0, dir.x).normalized() * 0.45
	for s in range(steps):
		var p0 := a + dir * (float(s) / steps)
		var p1 := a + dir * (float(s + 1) / steps)
		var mid := (p0 + p1) * 0.5
		mid.y = Terrain.height(mid.x, mid.z)
		for sgn: float in [-1.0, 1.0]:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.28, 0.02, p0.distance_to(p1) + 0.2)
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = _track_mat
			mi.position = mid + side * sgn + Vector3(0, 0.04, 0)
			mi.rotation.y = atan2(dir.x, dir.z)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			yard.add_child(mi)


static func _solid(yard: Node3D, pos: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	body.rotation.y = yaw
	body.add_child(Geo.box_shape(size))
	yard.add_child(body)


static func _fire_barrel(yard: Node3D, pos: Vector3) -> void:
	var b := Props.barrel()
	b.position = pos
	yard.add_child(b)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 1.0, 0)
	l.light_color = Color(1.0, 0.55, 0.22)
	l.light_energy = 1.3
	l.omni_range = 7.0
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 120.0
	l.distance_fade_length = 40.0
	yard.add_child(l)
	var glow := Geo.block(yard, Vector3(0.5, 0.05, 0.5), pos + Vector3(0, 0.92, 0), Palette.m(&"rust"), false)
	glow.name = "FireBarrelGlow"


## Пни по кольцу вокруг площадки: просека уходит в лес, а не обрывается стеной.
static func _clearing_ring(yard: Node3D, c: Vector3, r0: float, r1: float, stumps: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in stumps:
		var a := rng.randf() * TAU
		var r := rng.randf_range(r0, r1)
		var s := Props.stump(snappedf(rng.randf_range(0.26, 0.42), 0.04))
		_put(yard, s, c, cos(a) * r, sin(a) * r, rng.randf() * 360.0)
	# Пологие снежные бугры: площадка не должна быть идеальным столом
	for i in stumps:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(r0 - 4.0, r1 + 4.0)
		drift(yard, _ground(c, cos(a2) * r2, sin(a2) * r2), rng.randf_range(3.0, 6.0), rng.randf_range(0.4, 0.9), rng.randf_range(1.5, 3.0), rng.randf() * 180.0)


## Лесосека: лесопильня с пилой, штабели хлыстов, пни, костровая бочка, колеи волока, намёты.
static func camp(yard: Node3D, c: Vector3) -> void:
	# Лесопильня к западу от вагончиков: стан, опилки, рядом колода с топором
	var saw := _put(yard, Props.sawmill(), c, -3.5, 4.0, 12.0)
	_solid(yard, saw.position, Vector3(6.4, 1.2, 1.6), saw.rotation.y)
	patch(yard, _ground(c, -3.0, 5.6), 2.2, &"dust")
	patch(yard, _ground(c, -5.2, 3.2), 1.4, &"dust")
	_put(yard, Props.axe_stump(), c, -7.0, 5.6, 40.0)
	# Хлысты: два штабеля у стана и один у дороги
	for lp: Array in [[-13.5, 0.0, 80.0], [-13.0, -3.0, 95.0], [16.0, -6.0, 10.0]]:
		var p := _put(yard, Props.log_pile(5.4), c, lp[0], lp[1], lp[2])
		_solid(yard, p.position, Vector3(5.2, 1.2, 1.7), p.rotation.y)
	# Работа окончена внезапно: ящики, санки, бочка с огнём
	_put(yard, Props.stacked_crates(), c, -1.0, -3.5, 25.0)
	_put(yard, Props.surveyor_sledge(), c, 12.0, -3.0, -20.0)
	_fire_barrel(yard, _ground(c, 4.8, -1.8))
	patch(yard, _ground(c, 4.8, -1.8), 1.2, &"soot")
	# Колея волока от дороги, обрывается у штабеля
	tracks(yard, c + Vector3(34.0, 0, 3.0), c + Vector3(6.0, 0, 1.0))
	tracks(yard, c + Vector3(-16.0, 0, 3.0), c + Vector3(-34.0, 0, 6.0))
	# Намёты у вагончиков, поленниц и ГТ-Т
	drift(yard, _ground(c, 6.0, -10.0), 3.4, 1.0, 1.1, 15.0)
	drift(yard, _ground(c, 10.5, -8.0), 3.2, 0.9, 1.0, 23.0)
	drift(yard, _ground(c, -10.0, -7.5), 3.0, 0.9, 1.2, 50.0)
	for j in 3:
		drift(yard, _ground(c, -10.0 + j * 2.6, 9.4), 1.6, 0.6, 1.0, 90.0)
	drift(yard, _ground(c, -14.0, 0.0), 3.0, 0.8, 1.2, 80.0)
	_clearing_ring(yard, c, 13.0, 28.0, 14, 5101)
	# Вешки по краю площадки
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		_put(yard, Props.rope_post(true, Color(0.82, 0.5, 0.1)), c, cos(a) * 22.0, sin(a) * 22.0)


## Буровая: стеллаж труб, цистерна ГСМ, мазутные пятна, бочки россыпью, щиты от ветра, намёты.
static func drill(yard: Node3D, c: Vector3) -> void:
	_put(yard, Props.pipe_rack(4.5), c, 7.0, -1.0, 90.0)
	_solid(yard, _ground(c, 7.0, -1.0), Vector3(1.8, 1.0, 4.6), 0.0)
	_put(yard, Props.pipe_rack(3.8), c, 5.0, -7.5, 70.0)
	var tank := _put(yard, Props.fuel_tank(), c, -10.0, -3.0, 20.0)
	_solid(yard, tank.position, Vector3(3.4, 1.6, 1.5), tank.rotation.y)
	patch(yard, _ground(c, -8.0, -1.0), 2.2, &"soot")
	patch(yard, _ground(c, 2.5, 4.0), 1.6, &"soot")
	# Бочка опрокинута, мазут вытек
	var fallen := Props.barrel()
	fallen.position = _ground(c, -8.6, 3.2) + Vector3(0, 0.3, 0)
	fallen.rotation = Vector3(0, 0.6, deg_to_rad(90.0))
	yard.add_child(fallen)
	_put(yard, Props.barrel(), c, -5.4, 6.0)
	_fire_barrel(yard, _ground(c, -2.0, 7.5))
	_put(yard, Props.workbench(), c, 4.5, 5.5, 200.0)
	_put(yard, Props.snow_fence(4.0, 1.7), c, 12.0, 6.0, 80.0)
	_put(yard, Props.snow_fence(4.0, 1.7), c, 12.0, 10.5, 80.0)
	_put(yard, Props.snow_fence(4.0, 1.7), c, -13.0, 4.0, -70.0)
	tracks(yard, c + Vector3(-6.0, 0, 30.0), c + Vector3(-3.0, 0, 8.0))
	drift(yard, _ground(c, -4.5, -1.0), 2.4, 0.9, 1.4, 20.0)
	drift(yard, _ground(c, 8.5, 1.6), 2.6, 0.9, 1.0, 90.0)
	drift(yard, _ground(c, -10.0, -4.2), 2.6, 0.8, 1.0, 20.0)
	drift(yard, _ground(c, 12.5, 8.0), 3.0, 0.9, 1.0, 80.0)
	_clearing_ring(yard, c, 14.0, 24.0, 5, 5102)
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.9
		_put(yard, Props.rope_post(true, Color(0.9, 0.2, 0.12)), c, cos(a) * 19.0, sin(a) * 19.0)


## Старая вышка: щиты от ветра, ящики геодезистов, колышки, санки, намёты у КУНГа, колея.
static func tower(yard: Node3D, c: Vector3) -> void:
	_put(yard, Props.snow_fence(4.0, 1.7), c, -6.0, 9.0, 10.0)
	_put(yard, Props.snow_fence(4.0, 1.7), c, -1.5, 9.5, 5.0)
	_put(yard, Props.snow_fence(4.0, 1.7), c, 12.0, -2.5, 100.0)
	_put(yard, Props.surveyor_sledge(), c, -5.0, -6.0, 35.0)
	_put(yard, Props.stacked_crates(), c, 3.5, -7.5, -15.0)
	_put(yard, Props.barrel(), c, 6.0, -8.5)
	_put(yard, Props.barrel(), c, 6.8, -8.0)
	_fire_barrel(yard, _ground(c, 9.0, 8.5))
	patch(yard, _ground(c, 9.0, 8.5), 1.1, &"soot")
	for i in 4:
		_put(yard, Props.survey_stake(), c, -9.0 + i * 3.4, -11.0 + (i % 2) * 1.2, 0.0)
	tracks(yard, c + Vector3(-18.0, 0, 30.0), c + Vector3(7.0, 0, 5.0))
	drift(yard, _ground(c, 7.0, 3.0), 3.4, 1.0, 1.2, -70.0)
	drift(yard, _ground(c, -6.0, -5.0), 2.4, 0.8, 1.1, 35.0)
	drift(yard, _ground(c, 4.0, -7.0), 2.0, 0.8, 1.0, 20.0)
	_clearing_ring(yard, c, 14.0, 24.0, 6, 5103)
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.5
		_put(yard, Props.rope_post(true, Color(0.9, 0.9, 0.9)), c, cos(a) * 18.0, sin(a) * 18.0)


## Табличка на двух столбиках: жесть, чёрные буквы с обеих сторон.
static func sign_board(yard: Node3D, pos: Vector3, yaw_deg: float, key: StringName, plate_col := Color(0.78, 0.78, 0.74)) -> void:
	var root := Node3D.new()
	yard.add_child(root)
	root.position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	for sx: float in [-0.55, 0.55]:
		Geo.block(root, Vector3(0.07, 1.6, 0.07), Vector3(sx, 0.8, 0), Palette.m(&"dark"), false)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = plate_col
	Geo.block(root, Vector3(1.4, 0.55, 0.03), Vector3(0, 1.35, 0), mat, false)
	for back in [false, true]:
		var l := Label3D.new()
		l.text = Loc.t(key)
		l.font_size = 40
		l.pixel_size = 0.0042
		l.modulate = Color(0.1, 0.08, 0.08)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(0, 1.35, -0.02 if back else 0.02)
		if back:
			l.rotation.y = PI
		root.add_child(l)


## Ограда: столбики и два ряда проволоки по ломаной pts.
static func wire_fence(yard: Node3D, pts: Array, posts_every := 2.5) -> void:
	var k := MeshKit.new(77)
	var wire := Color(0.12, 0.12, 0.13)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / posts_every))
		for j in range(n + 1):
			var p := a.lerp(b, float(j) / n)
			p.y = Terrain.height(p.x, p.z)
			if j < n or i == pts.size() - 2:
				k.box(p + Vector3(0, 0.7, 0), Vector3(0.08, 1.4, 0.08), Color(0.24, 0.19, 0.14))
		for h: float in [0.6, 1.2]:
			var line: PackedVector3Array = []
			for j in range(n + 1):
				var p := a.lerp(b, float(j) / n)
				p.y = Terrain.height(p.x, p.z) + h
				line.append(p)
			k.tube(line, [0.01], wire, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	yard.add_child(mi)


## Контур квадрата со стороной 2*half; gap_side (0..3) — сторона без ограды (проход).
static func _square(c: Vector3, half: float, yaw: float, gap_side := -1) -> Array:
	var b := Basis(Vector3.UP, yaw)
	var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	var out: Array = []
	var start := (gap_side + 1) % 4 if gap_side >= 0 else 0
	for i in range(5 if gap_side < 0 else 4):
		out.append(c + b * (corners[(start + i) % 4] as Vector3))
	return out


## Изба: поленница с севера, нужник, санки и колода у сеней, намёты, пни.
static func izba(yard: Node3D, c: Vector3) -> void:
	_put(yard, Props.woodpile(4.0, 1.2), c, -1.0, -4.6, 0.0)
	_put(yard, Props.outhouse(), c, -7.5, 4.5, 200.0)
	_put(yard, Props.surveyor_sledge(), c, 7.5, 3.6, 70.0)
	_put(yard, Props.axe_stump(), c, 7.0, -2.6, 20.0)
	_put(yard, Props.barrel(), c, -5.4, -3.6)
	drift(yard, _ground(c, -5.6, 0.0), 3.2, 0.8, 1.0, 90.0)
	drift(yard, _ground(c, -0.6, -3.4), 3.6, 0.6, 0.9, 0.0)
	drift(yard, _ground(c, 0.4, 3.6), 3.0, 0.5, 0.9, 0.0)
	_clearing_ring(yard, c, 9.0, 18.0, 6, 5201)


## Ретранслятор: ограда из проволоки, будка трансформатора, ящики, табличка, намёты.
static func repeater(yard: Node3D, c: Vector3) -> void:
	wire_fence(yard, _square(c, 7.5, 0.0, 3))
	var tb := _put(yard, Props.transformer_booth(), c, 5.2, -4.6, -90.0)
	_solid(yard, tb.position, Vector3(1.4, 2.0, 1.2), tb.rotation.y)
	_put(yard, Props.stacked_crates(), c, 4.8, 4.6, 30.0)
	_put(yard, Props.barrel(), c, -5.6, -5.4)
	sign_board(yard, _ground(c, -8.6, 4.2), 90.0, &"sign.danger_hv", Color(0.85, 0.82, 0.70))
	drift(yard, _ground(c, -3.0, -3.2), 3.0, 0.7, 1.0, 0.0)
	drift(yard, _ground(c, 3.2, 2.4), 2.6, 0.6, 1.0, 90.0)
	_clearing_ring(yard, c, 10.0, 16.0, 4, 5202)


## Бункер: запретная зона — проволока, табличка, бетонные блоки, вентиляционный грибок, ржавая бочка.
static func bunker(yard: Node3D, c: Vector3) -> void:
	wire_fence(yard, _square(c, 6.5, deg_to_rad(10.0), 3))
	sign_board(yard, _ground(c, -7.4, 2.6), 100.0, &"sign.restricted", Color(0.82, 0.78, 0.66))
	for bl: Array in [[3.6, -3.4, 15.0], [4.6, -2.2, -10.0], [-3.8, -4.0, 40.0]]:
		var blk := Props.fbs_block()
		blk.position = _ground(c, bl[0], bl[1])
		blk.rotation.y = deg_to_rad(bl[2])
		yard.add_child(blk)
		_solid(yard, blk.position + Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 0.8), blk.rotation.y)
	var vent := _ground(c, 2.6, 3.4)
	Geo.cylinder(yard, 0.18, 1.3, vent + Vector3(0, 0.65, 0), Palette.m(&"metal"), true)
	Geo.cylinder(yard, 0.42, 0.12, vent + Vector3(0, 1.35, 0), Palette.m(&"metal"), false)
	Geo.cylinder(yard, 0.40, 0.08, vent + Vector3(0, 1.45, 0), Palette.m(&"snow"), false)
	var rb := Props.barrel()
	rb.position = _ground(c, -4.2, 3.6) + Vector3(0, 0.3, 0)
	rb.rotation = Vector3(0, 1.1, deg_to_rad(90.0))
	yard.add_child(rb)
	drift(yard, _ground(c, -1.8, -2.4), 3.0, 0.9, 1.2, 20.0)
	drift(yard, _ground(c, 1.6, 2.0), 2.4, 0.7, 1.0, 110.0)


## Зимник: вешки вдоль колеи, брошенные бочки и ящики у КУНГа, намёты.
static func zimnik(yard: Node3D, c: Vector3) -> void:
	for i in 5:
		var t := float(i)
		_put(yard, Props.winter_road_marker(), c, -4.0 - t * 7.0, -5.0 - t * 5.5, 35.0)
	_put(yard, Props.barrel(), c, 7.4, -0.6)
	_put(yard, Props.barrel(), c, 8.1, -0.1)
	_put(yard, Props.stacked_crates(), c, 1.6, -6.4, 15.0)
	drift(yard, _ground(c, 4.5, -1.6), 3.6, 0.9, 1.1, 15.0)
	drift(yard, _ground(c, -2.2, 0.8), 2.0, 0.6, 1.0, 90.0)
	_clearing_ring(yard, c, 9.0, 16.0, 5, 5203)


## Озеро: вешки на льду от сарая к проруби, намёты у сарая и на берегу.
static func lake(yard: Node3D, lake_c: Vector3, hole: Vector3, shack: Vector3) -> void:
	for i in 4:
		var post := Props.rope_post(true, Color(0.82, 0.14, 0.12))
		post.position = shack.lerp(hole, 0.2 + i * 0.2) + Vector3(1.4, 0, 0)
		yard.add_child(post)
	drift(yard, shack + Vector3(-4.6, 0, 0), 3.0, 0.8, 1.0, 90.0)
	drift(yard, shack + Vector3(4.6, 0, -1.0), 2.6, 0.7, 1.0, 90.0)
	drift(yard, lake_c + Vector3(-6.0, 0, -4.0), 4.0, 0.5, 1.6, 30.0)
	drift(yard, lake_c + Vector3(5.0, 0, 6.0), 3.6, 0.4, 1.4, -20.0)


## АМС: ограждение 6.4×6.4 с проходом, табличка с номером, ящик, намёты, пни.
static func ams(yard: Node3D, c: Vector3, yaw: float, id: StringName) -> void:
	wire_fence(yard, _square(c, 3.2, yaw, 2))
	var b := Basis(Vector3.UP, yaw)
	var sp := c + b * Vector3(-2.2, 0, 3.6)
	sp.y = Terrain.height(sp.x, sp.z)
	sign_board(yard, sp, rad_to_deg(yaw), StringName("sign." + String(id)), Color(0.80, 0.80, 0.74))
	var cr := Props.crate()
	cr.position = c + b * Vector3(-1.6, 0, -1.4)
	cr.position.y = Terrain.height(cr.position.x, cr.position.z)
	cr.rotation.y = yaw + 0.3
	yard.add_child(cr)
	for d: Array in [[-2.4, -2.6, 3.0], [2.6, -1.8, 2.4]]:
		var p := c + b * Vector3(d[0], 0, d[1])
		drift(yard, Vector3(p.x, Terrain.height(p.x, p.z), p.z), d[2], 0.6, 1.0, rad_to_deg(yaw))
	_clearing_ring(yard, c, 6.0, 11.0, 3, 5300 + absi(String(id).hash()) % 97)


## Приборная площадка у корпуса: осадкомер, гелиограф, почвенные термометры, колья, намёты у ограды.
## Только вид — показания снимают с будки и рейки (Yard).
static func meteo_plot_decor(yard: Node3D, c: Vector3, half: float) -> void:
	_put(yard, Props.precip_gauge(), c, 1.8, -1.8)
	_put(yard, Props.heliograph(), c, 0.2, -2.2)
	_put(yard, Props.soil_thermometers(), c, 2.9, 2.4, 10.0)
	for p: Array in [[3.6, 3.6], [-3.4, 3.7]]:
		_put(yard, Props.survey_stake(), c, p[0], p[1])
	drift(yard, _ground(c, 0.0, -half - 0.7), 3.6, 0.6, 1.1, 90.0)
	drift(yard, _ground(c, half + 0.6, 0.5), 2.4, 0.4, 0.9, 0.0)
