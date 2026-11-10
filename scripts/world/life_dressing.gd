class_name LifeDressing
extends Node3D
## Жилой вид станции и окрестностей (модели из Блендера, tools/blender/kedr_set2.py):
##   в доме — полки с банками, вешалка с ватником и ушанкой, книги и мелочи на столах;
##   во дворе — бельё, замёрзшее колом на верёвке, заячьи следы и лыжня в лес (днём);
##   на просеке пролога — поклонный крест с рушником, жестянки на верёвке, лабаз на сваях,
##   лосиный череп на шесте. Звуки у них — в PrologueTrail.
## Настенные вещи ставятся лучом до ближайшей стены, чтобы не висеть в воздухе и не тонуть в брёвнах.

## [модель, метров от высадки, смещение вбок от оси дороги (+ вправо по ходу), поворот лицом к дороге]
const TRAIL_PROPS := [
	["trail_cross", 16.0, 4.2],
	["can_line", 36.0, -4.4],
	["skull_stake", 96.0, 4.0],
	["labaz", -62.0, -8.0],       ## отрицательное — от конца маршрута (на подходе к станции)
]


func _ready() -> void:
	name = "LifeDressing"
	_trail()
	_yard()
	# Стены и мебель дома должны попасть в физику, прежде чем мерить до них лучом
	await get_tree().physics_frame
	await get_tree().physics_frame
	_interiors()


static func trail_prop(i: int) -> Array:
	var e: Array = TRAIL_PROPS[i]
	var s: float = e[1]
	if s < 0.0:
		s = PrologueTrail.length_m() + s
	var pd: Array = PrologueTrail.point_at(s)
	var p: Vector3 = pd[0]
	var dir: Vector3 = pd[1]
	var right := Vector3(-dir.z, 0, dir.x)
	var q := p + right * float(e[2])
	q.y = Terrain.height(q.x, q.z)
	# Лицом (+Z модели) к дороге
	var to := p - q
	return [q, atan2(to.x, to.z)]


func _put(id: String, pos: Vector3, yaw: float, opts := {}) -> Node3D:
	var n := Props._kedr_model(id, opts if not opts.is_empty() else {"bright": 1.15})
	if n == null:
		return null
	add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	return n


# --- Просека ------------------------------------------------------------------------

func _trail() -> void:
	_trail_small()
	for i in TRAIL_PROPS.size():
		var pr := trail_prop(i)
		var n := _put(TRAIL_PROPS[i][0], pr[0], pr[1])
		if n != null:
			n.name = "Trail_" + String(TRAIL_PROPS[i][0])
		if TRAIL_PROPS[i][0] == "labaz" or TRAIL_PROPS[i][0] == "trail_cross":
			var body := StaticBody3D.new()
			body.collision_layer = Geo.LAYER_WORLD
			body.collision_mask = 0
			add_child(body)
			body.global_position = pr[0]
			body.rotation.y = pr[1]
			var sz := Vector3(2.0, 3.6, 2.0) if TRAIL_PROPS[i][0] == "labaz" else Vector3(0.3, 2.4, 0.3)
			body.add_child(Geo.box_shape(sz, Vector3(0, sz.y / 2.0, 0)))


## Мелочи вдоль просеки пролога: [что, метров от высадки, вбок (+ вправо), поворот]. Без звука и мыслей —
## просто живая обочина: столбик, бочка, палки, варежка, бревно, пень с топором, указатель, ворона.
const TRAIL_SMALL := [
	["km", 6.0, 3.3, 0.0],
	["marker", 12.0, -3.2, 0.0],
	["barrel", 20.0, -3.8, 30.0],
	["stake", 28.0, 3.5, 10.0],
	["marker", 38.0, 3.4, 0.0],
	["sledge", 46.0, -4.6, -15.0],
	["poles", 52.0, 3.4, 0.0],
	["crate", 58.0, -3.6, 25.0],
	["marker", 64.0, 3.3, 0.0],
	["mitten", 70.0, -3.1, 0.0],
	["log", 82.0, 4.6, 70.0],
	["barrel", 90.0, -3.9, 45.0],
	["marker", 96.0, -3.3, 0.0],
	["stake", 102.0, 3.5, -10.0],
	["bucket", 108.0, -3.5, 0.0],
	["marker", 116.0, 3.3, 0.0],
	["axe", 122.0, 4.2, 0.0],
	["log", 130.0, -4.5, -60.0],
	["marker", 138.0, -3.2, 0.0],
	["crate", 144.0, 3.8, 15.0],
	["barrel", 152.0, -3.6, 20.0],
	["marker", 160.0, 3.3, 0.0],
	["sign", -40.0, 3.2, 0.0],
	["crow", -22.0, -2.9, 40.0],
	["marker", -12.0, -3.1, 0.0],
]


func _trail_small() -> void:
	for e: Array in TRAIL_SMALL:
		var s: float = e[1]
		if s < 0.0:
			s = PrologueTrail.length_m() + s
		var pd: Array = PrologueTrail.point_at(s)
		var p: Vector3 = pd[0]
		var dir: Vector3 = pd[1]
		var right := Vector3(-dir.z, 0, dir.x)
		var q := p + right * float(e[2])
		q.y = Terrain.height(q.x, q.z)
		var face := atan2(p.x - q.x, p.z - q.z) + deg_to_rad(float(e[3]))
		var n: Node3D = null
		match String(e[0]):
			"km": n = Props.km_post()
			"marker": n = Props.winter_road_marker()
			"stake": n = Props.survey_stake()
			"crate": n = Props.crate()
			"sledge": n = Props.surveyor_sledge()
			"barrel": n = Props.frozen_barrel()
			"poles": n = Props.ski_poles()
			"mitten": n = Props.mitten_stake()
			"axe": n = Props.axe_stump()
			"sign": n = Props.arrow_sign(Loc.t(&"trail.sign"))
			"crow": n = Props.frozen_crow()
			"log":
				n = Models.spawn(self, "nature/log_large", q, rad_to_deg(face), 0.55, {"collide": true, "tint": Color(0.75, 0.72, 0.7)})
				if n != null:
					var cap := MeshInstance3D.new()
					cap.mesh = Props.snow_mound_mesh(1)
					cap.material_override = Palette.m(&"drift")
					cap.scale = Vector3(1.6, 0.14, 0.32)
					cap.position = q + Vector3(0, 0.42, 0)
					cap.rotation.y = face + PI * 0.5
					add_child(cap)
				continue
			"bucket":
				n = Models.spawn(self, "survival/bucket", q, rad_to_deg(face), 0.32, {"tilt": Vector3(80, 0, 0)})
				continue
		if n == null:
			continue
		add_child(n)
		n.global_position = q
		n.rotation.y = face

	# Колея гусениц тягача и нарт по зимнику
	var s_trk := 4.0
	var prev_pt := (PrologueTrail.point_at(s_trk)[0] as Vector3)
	while s_trk < PrologueTrail.length_m() - 10.0:
		s_trk += 8.0
		var next_pt: Vector3 = PrologueTrail.point_at(s_trk)[0]
		SiteDressing.tracks(self, prev_pt, next_pt)
		prev_pt = next_pt

	# Линия деревянных столбов связи/ЛЭП вдоль зимника пролога
	var pole_dists := [14.0, 48.0, 84.0, 120.0, 156.0]
	var pole_wires: Array[Array] = []
	for pdist: float in pole_dists:
		if pdist >= PrologueTrail.length_m() - 12.0:
			continue
		var pd: Array = PrologueTrail.point_at(pdist)
		var p: Vector3 = pd[0]
		var dir: Vector3 = pd[1]
		var right := Vector3(-dir.z, 0, dir.x)
		var q := p + right * 4.6
		q.y = Terrain.height(q.x, q.z)
		var yaw := atan2(-dir.z, dir.x)
		var pole := Props.utility_pole(5.2)
		pole.position = q
		pole.rotation.y = yaw
		add_child(pole)
		var pts := Props.pole_wire_points(5.2)
		var basis := Basis(Vector3.UP, yaw)
		pole_wires.append([q + basis * pts[0], q + basis * pts[1]])
	for i in range(pole_wires.size() - 1):
		_build_catenary_wire(pole_wires[i], pole_wires[i + 1], 0.6)

	# Намёты по обочинам и подрост — обочина не ровная, как стол
	var rng := RandomNumberGenerator.new()
	rng.seed = 2140
	var s2 := 5.0
	while s2 < PrologueTrail.length_m() - 8.0:
		var pd: Array = PrologueTrail.point_at(s2)
		var p: Vector3 = pd[0]
		var dir: Vector3 = pd[1]
		var right := Vector3(-dir.z, 0, dir.x)
		for side: float in [-1.0, 1.0]:
			var q := p + right * side * rng.randf_range(3.6, 4.8)
			q.y = Terrain.height(q.x, q.z)
			var m := MeshInstance3D.new()
			m.mesh = Props.snow_mound_mesh(rng.randi())
			m.material_override = Palette.m(&"drift")
			m.scale = Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.25, 0.5), rng.randf_range(1.4, 2.6))
			m.position = q
			m.rotation.y = atan2(dir.x, dir.z) + rng.randf_range(-0.3, 0.3)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
			if rng.randf() < 0.35:
				var sap := Props.faceted_spruce(rng.randf_range(0.18, 0.32), rng.randi() % 50)
				sap.position = q + right * side * 0.8
				add_child(sap)
		s2 += rng.randf_range(9.0, 14.0)


func _build_catenary_wire(a: Array, b: Array, sag: float) -> void:
	var k := MeshKit.new(10)
	var col := Color(0.12, 0.12, 0.14)
	for pr in [[a[0], b[0]], [a[1], b[1]]]:
		var p1: Vector3 = pr[0]
		var p2: Vector3 = pr[1]
		var pts: PackedVector3Array = []
		for step in 8:
			var t := float(step) / 7.0
			pts.append(p1.lerp(p2, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
		k.tube(pts, [0.014], col, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	add_child(mi)


# --- Двор ------------------------------------------------------------------------------

func _yard() -> void:
	# Бельё на верёвке за домом, с южной стороны — колом от мороза
	var line := _put("laundry_line", Vector3(1.8, 0.0, 11.2), 0.06)
	if line != null:
		for sx: float in [-2.6, 2.6]:
			var body := StaticBody3D.new()
			body.collision_layer = Geo.LAYER_WORLD
			body.collision_mask = 0
			line.add_child(body)
			body.position = Vector3(sx, 1.0, 0)
			body.add_child(Geo.box_shape(Vector3(0.14, 2.0, 0.14)))
	if not Game.is_daylight():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d" % [Game.phase_kind, Game.phase_index])
	# Заячьи следы: «тройки» поперёк двора — из леса в лес
	for k in 3:
		var a := rng.randf() * TAU
		var c := Vector3(18, 0, 6) + Vector3(cos(a), 0, sin(a)) * rng.randf_range(26.0, 40.0)
		var dir := Vector3(-sin(a), 0, cos(a)).rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		_hare_tracks(c - dir * 18.0, dir, 36.0, rng)
	# Лыжня Семёнова: два ровных желобка от дровника в лес
	_ski_track(PackedVector3Array([Vector3(6, 0, 36), Vector3(-4, 0, 48), Vector3(-10, 0, 62), Vector3(-6, 0, 80)]))


func _hare_tracks(start: Vector3, dir: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "HareTracks"
	add_child(root)
	var side := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(dir.x, dir.z)
	var s := 0.0
	while s < length:
		var base := start + dir * s + side * sin(s * 0.15) * 1.5
		# Задние длинные — впереди и рядом, передние — одна за другой позади
		for pr: Array in [[side * 0.09 + dir * 0.35, true], [-side * 0.09 + dir * 0.35, false], [dir * 0.05, true], [-dir * 0.12, false]]:
			var p: Vector3 = base + pr[0]
			p.y = Terrain.height(p.x, p.z)
			var m := Footprints.make(&"paw", Vector3.ZERO, yaw, pr[1])
			root.add_child(m)
			m.global_position = p + Vector3(0, 0.01, 0)
		s += rng.randf_range(1.1, 1.6)


func _ski_track(route: PackedVector3Array) -> void:
	var m := Footprints.material(&"snow")
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var d := b - a
		var len := d.length()
		var dir := d / len
		var side := Vector3(-dir.z, 0, dir.x)
		for sx: float in [-0.09, 0.09]:
			var seg := 0.0
			while seg < len:
				var q := MeshInstance3D.new()
				var pm := PlaneMesh.new()
				pm.size = Vector2(0.07, 2.05)
				q.mesh = pm
				q.material_override = m
				add_child(q)
				var p := a + dir * (seg + 1.0) + side * sx
				p.y = Terrain.height(p.x, p.z) + 0.012
				q.global_position = p
				q.rotation.y = atan2(dir.x, dir.z)
				seg += 2.0


# --- Дом --------------------------------------------------------------------------------

## Вещь на стену: луч от точки в комнате в сторону стены; задник модели — к стене, низ — на высоте y.
func _on_wall(id: String, from: Vector3, dir: Vector3, y: float, opts := {}) -> Node3D:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 5.0, Geo.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		print("[life] нет стены для ", id, " от ", from)
		return null
	var n: Vector3 = hit["normal"]
	n.y = 0.0
	n = n.normalized()
	var p: Vector3 = hit["position"] + n * 0.015
	p.y = y
	if OS.is_debug_build():
		print("[life] ", id, " → ", p, " (", (hit["collider"] as Node).name, ")")
	var o := {"bright": 1.15, "center": false}
	o.merge(opts, true)
	return _put(id, p, atan2(n.x, n.z), o)


## Вещь на стол: если в точке что-то уже стоит выше столешницы — сдвигаемся вдоль стола.
func _on_table(id: String, pos: Vector3, yaw: float, step := Vector3(0.25, 0, 0)) -> Node3D:
	var space := get_world_3d().direct_space_state
	for k in 4:
		var p := pos + step * k
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p + Vector3(0, -0.3, 0), Geo.LAYER_WORLD | Geo.LAYER_INTERACT)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(float(hit["position"].y) - pos.y) < 0.08:
			return _put(id, p, yaw)
	print("[life] стол занят для ", id, " у ", pos)
	return null


func _interiors() -> void:
	# Жилая комната: полка с банками на западной стене между печью и кроватью
	_on_wall("shelf_jars", Vector3(-1.0, 1.3, 4.8), Vector3.LEFT, 0.68)
	# Чайный стол: мелочи и книги по краям (в центре — самовар и чайник)
	_on_table("table_clutter", Vector3(0.5, 0.75, 3.85), 0.3, Vector3(-0.1, 0, 0))
	_on_table("books", Vector3(1.95, 0.75, 3.75), -0.25, Vector3(0.05, 0, 0.1))
	# Коридор: вешалка с ватником и ушанкой на южной стене
	_on_wall("coat_hooks", Vector3(6.2, 1.4, 4.4), Vector3.BACK, 0.82)
	# Кладовая: ещё полка с запасами — на западной стене
	_on_wall("shelf_jars", Vector3(5.8, 1.3, -4.0), Vector3.FORWARD, 0.5)
