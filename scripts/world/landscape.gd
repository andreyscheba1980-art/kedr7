class_name Landscape
extends RefCounted
## Крупный рельеф и «красивые места» за двором:
##   • хребет на горизонте — два кольца гор (900 и 1300 м) со снежными пиками; туман их не съедает,
##     они сами растворяются в дымке по плотности тумана (в метель пропадают совсем);
##   • ручей подо льдом по дну распадка, бревенчатый мосток на насыпи дороги к буровой;
##   • каменные останцы-курумники на гребнях сопок;
##   • старая ЛЭП вдоль зимника: столбы уходят в туман, провода провисают.

const SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;
uniform vec4 haze : source_color = vec4(0.58, 0.61, 0.68, 1.0);
uniform float haze_k = 0.6;       // сколько дымки на этом кольце
uniform float fade = 0.0;         // 1 — гор не видно (метель)
uniform float lit = 1.0;          // день 1, ночь — темнее
varying float v_h;
varying float v_snow;
void vertex() { v_h = UV.y; v_snow = UV.x; }
void fragment() {
	vec3 rock = vec3(0.20, 0.22, 0.26) * lit;
	vec3 snow = vec3(0.80, 0.84, 0.90) * mix(0.25, 1.0, lit);
	vec3 c = mix(rock, snow, smoothstep(0.45, 0.62, v_snow));
	float k = clamp(haze_k + (1.0 - v_h) * 0.25, 0.0, 1.0);   // у подножия дымка гуще
	c = mix(c, haze.rgb, k);
	ALBEDO = mix(c, haze.rgb, fade);
}
"""

static var _mats: Array[ShaderMaterial] = []
static var _rings: Array[MeshInstance3D] = []


static func build(parent: Node3D) -> void:
	_mats.clear()
	_rings.clear()
	_mountains(parent, 900.0, 115.0, 0.7, 11)
	_mountains(parent, 1300.0, 210.0, 0.8, 23)
	_rivers(parent)
	_outcrops(parent)
	_power_line(parent)
	var upd := _Updater.new()
	upd.name = "LandscapeHaze"
	parent.add_child(upd)


## Кольцо гор вокруг центра карты: гребень по шуму, снег выше середины склонов и по гребням.
static func _mountains(parent: Node3D, radius: float, peak: float, haze_k: float, seed_v: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 1.6
	n.fractal_octaves = 4
	var segs := 360
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3.ZERO   # кольцо строится вокруг нуля; узел ездит за камерой (камера видит лишь 85 м)
	var rows := [0.0, 0.35, 0.7, 1.0]     # доля высоты гребня: подножие → вершина
	var ring: Array = []
	for i in segs + 1:
		var a := TAU * i / segs
		var h := (n.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0) * 0.5 + 0.5)
		h = pow(h, 1.6) * peak + peak * 0.18
		var col: Array = []
		for k in rows.size():
			var f: float = rows[k]
			# Склоны чуть ступенчатые: верхние ряды ближе к центру (гора, а не стена)
			var r := radius   # отвесная «декорация»: дальше неё камера всё равно не видит
			var y := -30.0 + f * (h + 30.0)
			col.append([c + Vector3(cos(a) * r, y, sin(a) * r), f, f * clampf(h / peak + 0.25, 0.0, 1.2)])
		ring.append(col)
	for i in segs:
		for k in rows.size() - 1:
			var p00: Array = ring[i][k]
			var p10: Array = ring[i + 1][k]
			var p01: Array = ring[i][k + 1]
			var p11: Array = ring[i + 1][k + 1]
			for v: Array in [p00, p10, p11, p00, p11, p01]:
				st.set_uv(Vector2(v[2], v[1]))
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.name = "Mountains_%d" % int(radius)
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"haze_k", haze_k)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2000.0
	mi.custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 800, 4000))
	mi.set_meta(&"sky_scale", (83.4 if radius < 1000.0 else 84.4) / radius)
	parent.add_child(mi)
	_mats.append(m)
	_rings.append(mi)


## Лёд ручья по дну оврага и мосток там, где через распадок идёт дорога.
static func _rivers(parent: Node3D) -> void:
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.50, 0.62, 0.72)
	ice.roughness = 0.25
	ice.metallic_specular = 0.8
	for rv: Dictionary in Terrain.RAVINES:
		if not rv["river"]:
			continue
		var pts: Array = rv["pts"]
		var dense: Array[Vector2] = []
		for k in range(pts.size() - 1):
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var steps := maxi(int(a.distance_to(b) / 3.0), 1)
			for s in steps:
				dense.append(a.lerp(b, float(s) / steps))
		dense.append(pts[pts.size() - 1])
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev: Array = []
		for k in dense.size():
			var p := dense[k]
			var d := dense[mini(k + 1, dense.size() - 1)] - dense[maxi(k - 1, 0)]
			var side := Vector2(-d.y, d.x).normalized() * (2.2 + sin(k * 0.37) * 0.8)
			var y := minf(Terrain.height(p.x, p.y), minf(Terrain.height(p.x + side.x, p.y + side.y), Terrain.height(p.x - side.x, p.y - side.y))) + 0.12
			var l := Vector3(p.x - side.x, y, p.y - side.y)
			var r := Vector3(p.x + side.x, y, p.y + side.y)
			if not prev.is_empty():
				for v: Vector3 in [prev[0], prev[1], r, prev[0], r, l]:
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			prev = [l, r]
			# Наледи и вмёрзшие камни по кромке
			if k % 9 == 4:
				var rock := Props.boulder(k)
				var off := side * (1.1 if k % 2 == 0 else -1.1)
				rock.position = Vector3(p.x + off.x, y - 0.1, p.y + off.y)
				rock.scale = Vector3(0.9, 0.5, 0.7) * (0.8 + (k % 5) * 0.15)
				parent.add_child(rock)
		var mi := MeshInstance3D.new()
		mi.name = "FrozenStream"
		mi.mesh = st.commit()
		mi.material_override = ice
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		_bridges(parent, rv)


## Где дорога пересекает распадок — насыпь с бревенчатым настилом и перилами из жердей.
static func _bridges(parent: Node3D, rv: Dictionary) -> void:
	var log_m := Palette.m(&"log")
	for road: StringName in Terrain.ROADS:
		var pts := Terrain.road_points(road, 2.0)
		var hit := -1
		var best := 1e9
		for k in pts.size():
			var d := Terrain.ravine_dist(rv, Vector2(pts[k].x, pts[k].z))
			if d < best:
				best = d
				hit = k
		if best > 3.0 or hit < 2 or hit > pts.size() - 3:
			continue
		var a := pts[hit - 2]
		var b := pts[hit + 2]
		var dir := (b - a)
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var root := Node3D.new()
		root.name = "LogBridge"
		parent.add_child(root)
		for s in range(-5, 6):
			var p := Terrain.at(pts[hit] + dir * (s * 1.2))
			for sx: float in [-1.0, 1.0]:
				var post := Geo.cylinder(root, 0.07, 1.1, p + side * sx * (Terrain.ROAD_HALF + 0.2) + Vector3(0, 0.55, 0), log_m, false)
				post.rotation.z = sx * 0.04
		for sx: float in [-1.0, 1.0]:
			var p0 := Terrain.at(pts[hit] - dir * 6.0) + side * sx * (Terrain.ROAD_HALF + 0.2) + Vector3(0, 1.0, 0)
			var p1 := Terrain.at(pts[hit] + dir * 6.0) + side * sx * (Terrain.ROAD_HALF + 0.2) + Vector3(0, 1.0, 0)
			var rail := Geo.cylinder(root, 0.055, p0.distance_to(p1), (p0 + p1) * 0.5, log_m, false)
			rail.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP)
			rail.rotate_object_local(Vector3.RIGHT, PI * 0.5)


## Каменные останцы на гребнях сопок: глыбы кучками, по 3–6, где рельеф выше соседей.
static func _outcrops(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 900:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(Terrain.FLAT_R + 70.0, 470.0)
		var x := Terrain.CENTER.x + cos(a) * r
		var z := Terrain.CENTER.y + sin(a) * r
		if Terrain.height(x, z) < 26.0 or not Terrain.is_clear(x, z):
			continue
		placed += 1
		var n := rng.randi_range(3, 6)
		for i in n:
			var off := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
			var p := Terrain.at(Vector3(x, 0, z) + off)
			var rock := Props.boulder(rng.randi())
			var sc := rng.randf_range(1.4, 3.6)
			rock.scale = Vector3(sc * rng.randf_range(0.8, 1.3), sc * rng.randf_range(0.6, 1.2), sc * rng.randf_range(0.8, 1.3))
			rock.position = p + Vector3(0, sc * 0.2, 0)
			rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
			parent.add_child(rock)
			if i == 0:
				Geo.collider(parent, rock.scale * 0.7, rock.position)


## Старая ЛЭП вдоль зимника: столб через 45 м, два провода с провисом. Уходит в туман — к Большой Земле.
static func _power_line(parent: Node3D) -> void:
	var pts := Terrain.road_points(&"zimnik", 3.0)
	var wire_m := Palette.m(&"dark")
	var acc := 45.0
	var prev_tops: Array = []
	var k0 := 0
	for k in range(1, pts.size()):
		acc += pts[k].distance_to(pts[k - 1])
		if acc < 45.0:
			continue
		acc = 0.0
		var dir := pts[mini(k + 1, pts.size() - 1)] - pts[k - 1]
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var base := Terrain.at(pts[k] + side * (Terrain.ROAD_HALF + 4.5))
		var pole := Props.utility_pole(6.2)
		pole.position = base
		pole.rotation.y = atan2(dir.x, dir.z)
		# Некоторые столбы покосились — ЛЭП давно не обслуживают
		if k0 % 4 == 3:
			pole.rotation.z = 0.08
		k0 += 1
		parent.add_child(pole)
		var tops: Array = []
		for w in Props.pole_wire_points(6.2):
			tops.append(pole.transform * w)
		if not prev_tops.is_empty():
			for wi in mini(tops.size(), prev_tops.size()):
				_sag_wire(parent, prev_tops[wi], tops[wi], wire_m)
		prev_tops = tops


static func _sag_wire(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	var n := 6
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * 1.2, 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * 1.2, 0)
		var seg := Geo.box_mesh(Vector3(0.02, 0.02, p0.distance_to(p1)), m)
		parent.add_child(seg)
		seg.position = (p0 + p1) * 0.5
		seg.look_at(p1, Vector3.UP)


## Дымка на горах — по туману окружения каждый кадр (день/ночь, метель).
class _Updater extends Node:
	var _we: WorldEnvironment

	func _process(_delta: float) -> void:
		var vp := get_viewport()
		if vp == null:
			return
		var cam := vp.get_camera_3d()
		if cam != null:
			# Горы — как небо: всегда на горизонте, в 80 м от глаза, в уменьшенном масштабе
			for r in Landscape._rings:
				if is_instance_valid(r):
					var k: float = r.get_meta(&"sky_scale")
					r.global_position = cam.global_position
					r.scale = Vector3.ONE * k
		if _we == null or not is_instance_valid(_we):
			var found := get_tree().root.find_children("*", "WorldEnvironment", true, false)
			if found.is_empty():
				return
			_we = found[0]
		var env := _we.environment
		if env == null:
			return
		var fade := clampf((env.fog_density - 0.03) / 0.08, 0.0, 1.0)
		if Game.is_indoors():
			fade = 1.0
		var lit := 1.0 if Game.is_daylight() else 0.35
		for m in Landscape._mats:
			m.set_shader_parameter(&"haze", env.fog_light_color)
			m.set_shader_parameter(&"fade", fade)
			m.set_shader_parameter(&"lit", lit)
