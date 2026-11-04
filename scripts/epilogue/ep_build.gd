class_name EpBuild
extends RefCounted
## Геометрия эпилога «Свердловск, 1983»: проспект в зимних утренних сумерках, панельки с окнами,
## натриевые фонари, «Волга» ГАЗ-24, здание управления. Холл и 4-й этаж — отдельно, вдали
## (в них попадаешь через двери/лифт с затемнением). Всё — из коробок MeshKit и простых материалов
## в общей палитре игры, без внешних моделей.

const STREET_LEN := 270.0
const ROAD_HALF := 7.0
const KGB_DOOR := Vector3(13.6, 0.0, -262.0)        ## крыльцо управления (со стороны проспекта)
const PARK := Rect2(7.5, -270.0, 4.0, 16.0)         ## куда поставить машину (x, z, w, h)
const LOBBY := Vector3(0.0, 0.0, 500.0)
const FLOOR4 := Vector3(0.0, 0.0, 600.0)
const CORR_HALF := 1.4                                ## полуширина коридора
const ROOM_D := 5.0                                   ## глубина кабинета
const WALL_H := 3.2
const LIFT := Vector3(0.0, 0.0, 700.0)               ## кабина лифта (отдельно; двери ведут в холл и на 4-й)
const WING_X := 11.0                                  ## южное крыло отходит от коридора здесь
const WING_LEN := 13.0
const WING_HALF := 1.1

## Кабинеты 4-го этажа: номер → [x0, x1, сторона (+1 — север, −1 — юг)]
const ROOMS := {
	&"412": [-14.0, -8.0, 1.0],
	&"414": [-14.0, -8.0, -1.0],
	&"415": [-6.0, 0.0, 1.0],
	&"418": [-2.0, 6.0, -1.0],
	&"420": [4.0, 12.0, 1.0],
}


static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func glow_mat(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Стена с плинтусом и карнизом (у высоких стен): ровные коробки выглядели макетом.
static func wall(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	Geo.block(parent, size, pos, m, true)
	if size.y < 2.0:
		return
	var along_x := size.x >= size.z
	var thick := Vector3(0, 0, 0.035) if along_x else Vector3(0.035, 0, 0)
	var base := Vector3(size.x, 0.13, size.z) + thick
	Geo.block(parent, base, pos + Vector3(0, -size.y * 0.5 + 0.065, 0), _baseboard_mat(), false)
	Geo.block(parent, Vector3(size.x, 0.07, size.z) + thick * 1.3, pos + Vector3(0, size.y * 0.5 - 0.035, 0), _cornice_mat(), false)


static var _bb_mat: StandardMaterial3D
static var _cn_mat: StandardMaterial3D


static func _baseboard_mat() -> StandardMaterial3D:
	if _bb_mat == null:
		_bb_mat = mat(Color(0.26, 0.17, 0.11), 0.5)
	return _bb_mat


static func _cornice_mat() -> StandardMaterial3D:
	if _cn_mat == null:
		_cn_mat = mat(Color(0.86, 0.84, 0.78), 0.8)
	return _cn_mat


const SURF_SHADER := """
shader_type spatial;
// Фактуры эпилога в мировых координатах: 0 — крашеная стена, 1 — паркет «ёлочкой», 2 — мрамор,
// 3 — деревянные панели, 4 — плитка шашкой, 5 — побелённый потолок.
uniform int mode = 0;
uniform vec3 col_a : source_color = vec3(0.8);
uniform vec3 col_b : source_color = vec3(0.6);
uniform float scale = 1.0;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return n2(p) * 0.5 + n2(p * 2.1) * 0.25 + n2(p * 4.3) * 0.125; }
void fragment() {
	vec2 uv = abs(wn.y) > 0.5 ? wp.xz : (abs(wn.x) > 0.5 ? wp.zy : wp.xy);
	uv *= scale;
	vec3 c = col_a;
	float rough = 0.85;
	if (mode == 0) {
		c = col_a * (0.93 + 0.1 * fbm(uv * 3.0)) * (0.97 + 0.03 * sin(uv.x * 9.0 + fbm(uv) * 3.0));
	} else if (mode == 1) {
		vec2 q = uv * vec2(4.0, 4.0);
		float row = floor(q.y);
		float dir = mod(row, 2.0);
		vec2 r = vec2(q.x + q.y * (dir > 0.5 ? 1.0 : -1.0), q.y);
		float plank = floor(r.x * 0.5);
		float seam = step(0.96, fract(r.x * 0.5)) + step(0.95, fract(q.y));
		float t = h(vec2(plank, row));
		c = mix(col_a, col_b, t * 0.7) * (0.9 + 0.12 * n2(vec2(r.x * 0.5, q.y * 18.0)));
		c *= 1.0 - clamp(seam, 0.0, 1.0) * 0.45;
		rough = 0.45;
	} else if (mode == 2) {
		float v = abs(sin(uv.x * 3.0 + fbm(uv * 1.2) * 5.0 + uv.y * 1.1));
		float vein = (1.0 - smoothstep(0.0, 0.035, v)) * 0.55 + (1.0 - smoothstep(0.0, 0.012, abs(sin(uv.y * 5.0 + fbm(uv * 2.0) * 4.0)))) * 0.25;
		c = mix(col_a * (0.94 + 0.08 * fbm(uv * 4.0)), col_b, vein);
		rough = 0.25;
	} else if (mode == 3) {
		float board = floor(uv.x * 5.0);
		float seam = step(0.95, fract(uv.x * 5.0));
		c = mix(col_a, col_b, h(vec2(board, 1.0)) * 0.5) * (0.88 + 0.15 * n2(vec2(uv.x * 40.0, uv.y * 3.0)));
		c *= 1.0 - seam * 0.5;
		rough = 0.5;
	} else if (mode == 4) {
		vec2 q = uv * 2.5;
		float k = mod(floor(q.x) + floor(q.y), 2.0);
		float grout = step(0.95, fract(q.x)) + step(0.95, fract(q.y));
		c = mix(col_a, col_b, k) * (0.95 + 0.07 * n2(q * 3.0));
		c = mix(c, vec3(0.35), clamp(grout, 0.0, 1.0) * 0.6);
		rough = 0.3;
	} else {
		c = col_a * (0.95 + 0.06 * fbm(uv * 2.0));
	}
	ALBEDO = c;
	ROUGHNESS = rough;
}
"""
static var _surf_shader: Shader


static func surf(mode: int, a: Color, b := Color(0.5, 0.5, 0.5), sc := 1.0) -> ShaderMaterial:
	if _surf_shader == null:
		_surf_shader = Shader.new()
		_surf_shader.code = SURF_SHADER
	var m := ShaderMaterial.new()
	m.shader = _surf_shader
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"col_a", a)
	m.set_shader_parameter(&"col_b", b)
	m.set_shader_parameter(&"scale", sc)
	return m


## Дверное полотно, обитое дерматином (ромбы гвоздей), в раме; приоткрыто внутрь кабинета.
static func door_leaf(root: Node3D, center: Vector3, along_x: bool, into: float, open_deg := 78.0) -> void:
	var frame := mat(Color(0.3, 0.2, 0.12), 0.5)
	var leaf_m := mat(Color(0.32, 0.12, 0.1), 0.7)
	var stud := mat(Color(0.8, 0.65, 0.3), 0.25)
	var w := 1.1
	var hgt := 2.15
	# рама: две стойки и притолока
	for sx: float in [-1.0, 1.0]:
		var off := Vector3(sx * (w * 0.5 + 0.04), 0, 0) if along_x else Vector3(0, 0, sx * (w * 0.5 + 0.04))
		Geo.block(root, Vector3(0.08, hgt + 0.08, 0.26) if along_x else Vector3(0.26, hgt + 0.08, 0.08), center + off + Vector3(0, (hgt + 0.08) * 0.5, 0), frame, false)
	Geo.block(root, Vector3(w + 0.16, 0.08, 0.26) if along_x else Vector3(0.26, 0.08, w + 0.16), center + Vector3(0, hgt + 0.04, 0), frame, false)
	var hinge := center + (Vector3(-w * 0.5, 0, 0) if along_x else Vector3(0, 0, -w * 0.5))
	var pivot := Node3D.new()
	pivot.position = hinge
	root.add_child(pivot)
	var base_yaw := 0.0 if along_x else -PI * 0.5
	pivot.rotation.y = base_yaw - into * deg_to_rad(open_deg)
	Geo.block(pivot, Vector3(w, hgt, 0.05), Vector3(w * 0.5, hgt * 0.5, 0), leaf_m, false)
	for r in 6:
		for c in 3:
			Geo.block(pivot, Vector3(0.018, 0.018, 0.06), Vector3(0.22 + c * 0.33, 0.35 + r * 0.32, 0), stud, false)
	Geo.block(pivot, Vector3(0.12, 0.03, 0.09), Vector3(w - 0.1, 1.0, 0), stud, false)


static func label3d(parent: Node3D, text: String, pos: Vector3, yaw: float, px := 0.004, col := Color(0.9, 0.86, 0.75)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = 48
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation.y = yaw
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l


# --- Улица ---------------------------------------------------------------------

static func city(root: Node3D) -> void:
	var asphalt := mat(Color(0.20, 0.21, 0.24))
	var snow := Palette.m(&"snow")
	var curb := mat(Color(0.45, 0.45, 0.46))
	# Проезжая часть с накатом, тротуары, сугробы вдоль бордюра
	Geo.block(root, Vector3(ROAD_HALF * 2.0, 0.1, STREET_LEN + 40), Vector3(0, -0.05, -STREET_LEN * 0.5), asphalt, true)
	for sx: float in [-1.0, 1.0]:
		Geo.block(root, Vector3(9.0, 0.24, STREET_LEN + 40), Vector3(sx * (ROAD_HALF + 4.5), 0.07, -STREET_LEN * 0.5), snow, true)
		Geo.block(root, Vector3(0.25, 0.22, STREET_LEN + 40), Vector3(sx * (ROAD_HALF + 0.1), 0.06, -STREET_LEN * 0.5), curb, false)
		for i in 18:
			var d := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 8
			sm.rings = 4
			d.mesh = sm
			d.material_override = Palette.m(&"drift")
			d.position = Vector3(sx * (ROAD_HALF + 0.6), 0.0, -8.0 - i * 14.5 + sin(i * 2.1) * 3.0)
			d.scale = Vector3(0.9, 0.45, 2.6 + (i % 3))
			root.add_child(d)
	# Колея и разметка, присыпанная снегом
	for sx: float in [-2.8, 2.8]:
		Geo.block(root, Vector3(0.9, 0.012, STREET_LEN + 40), Vector3(sx, 0.006, -STREET_LEN * 0.5), mat(Color(0.14, 0.15, 0.17)), false)
	# Бортовые барьеры по концам — дальше не уехать
	Geo.collider(root, Vector3(ROAD_HALF * 2.0 + 20.0, 4.0, 1.0), Vector3(0, 2.0, 16.0))
	Geo.collider(root, Vector3(ROAD_HALF * 2.0 + 20.0, 4.0, 1.0), Vector3(0, 2.0, -STREET_LEN - 16.0))
	# Фонари: натриевый оранжевый, через 28 м попеременно
	var pole_m := mat(Color(0.25, 0.26, 0.27))
	var lamp_m := glow_mat(Color(1.0, 0.62, 0.28), 2.5)
	for i in 10:
		var sx := 1.0 if i % 2 == 0 else -1.0
		var z := -6.0 - i * 28.0
		var base := Vector3(sx * (ROAD_HALF + 1.2), 0.0, z)
		Geo.cylinder(root, 0.09, 8.0, base + Vector3(0, 4.0, 0), pole_m, true)
		Geo.block(root, Vector3(2.2, 0.1, 0.12), base + Vector3(-sx * 1.0, 8.0, 0), pole_m, false)
		Geo.block(root, Vector3(0.5, 0.12, 0.3), base + Vector3(-sx * 2.0, 7.92, 0), lamp_m, false)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 1.6
		l.omni_range = 18.0
		l.omni_attenuation = 1.2
		l.position = base + Vector3(-sx * 2.0, 7.4, 0)
		l.shadow_enabled = false
		root.add_child(l)
	# Троллейбусные провода над осью
	var wire_m := mat(Color(0.05, 0.05, 0.05))
	for sx: float in [-0.6, 0.6]:
		Geo.block(root, Vector3(0.03, 0.03, STREET_LEN + 30), Vector3(sx, 6.9, -STREET_LEN * 0.5), wire_m, false)
	# Панельки по обе стороны (окна — процедурный шейдер), просветы между ними
	var rng := RandomNumberGenerator.new()
	rng.seed = 1983
	for sx: float in [-1.0, 1.0]:
		var z := 4.0
		while z > -STREET_LEN + 40.0:
			var w := rng.randf_range(22.0, 36.0)
			var floors := rng.randi_range(5, 12)
			if sx > 0.0 and z - w < -225.0:
				break   # справа в конце — управление
			_panel_house(root, Vector3(sx * (ROAD_HALF + 12.0 + 6.0), 0, z - w * 0.5), Vector3(12.0, floors * 3.0, w), rng.randi(), sx)
			z -= w + rng.randf_range(6.0, 14.0)
	_kgb_building(root)
	# Остановка, лозунг, припаркованные машины, ёлочки у управления
	_bus_stop(root, Vector3(-(ROAD_HALF + 3.0), 0, -120.0))
	label3d(root, "РЕШЕНИЯ XXVI СЪЕЗДА КПСС — В ЖИЗНЬ!", Vector3(-(ROAD_HALF + 11.8), 13.0, -70.0), PI * 0.5, 0.012, Color(0.85, 0.18, 0.12))
	for p: Array in [[Vector3(-(ROAD_HALF - 1.4), 0, -40.0), 0.0, Color(0.55, 0.52, 0.42)], [Vector3(-(ROAD_HALF - 1.4), 0, -150.0), 0.0, Color(0.2, 0.3, 0.45)],
			[Vector3(ROAD_HALF - 1.4, 0, -90.0), PI, Color(0.45, 0.12, 0.1)], [Vector3(9.5, 0, -248.0), PI, Color(0.08, 0.08, 0.09)]]:
		var car := volga(p[2], false)
		car.position = p[0]
		car.rotation.y = p[1]
		root.add_child(car)
		Geo.collider(root, Vector3(1.9, 1.5, 4.9), p[0] + Vector3(0, 0.75, 0))


## Панельный дом: короб, крыша, окна (часть горит жёлтым — утро, люди встают на смену).
static func _panel_house(root: Node3D, c: Vector3, size: Vector3, seed_v: int, side: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = c + Vector3(0, size.y * 0.5, 0)
	mi.material_override = _window_mat(seed_v, size)
	root.add_child(mi)
	Geo.collider(root, size, mi.position)
	Geo.block(root, Vector3(size.x + 0.3, 0.3, size.z + 0.3), c + Vector3(0, size.y + 0.15, 0), Palette.m(&"snow"), false)
	# Козырьки подъездов со стороны улицы
	for k in int(size.z / 12.0):
		var z := c.z - size.z * 0.5 + 6.0 + k * 12.0
		Geo.block(root, Vector3(1.4, 0.12, 2.2), Vector3(c.x - side * (size.x * 0.5 + 0.7), 2.6, z), mat(Color(0.35, 0.35, 0.36)), false)
		var bulb := Geo.omni(root, Vector3(c.x - side * (size.x * 0.5 + 0.5), 2.4, z), 4.0, 0.8, Color(1.0, 0.85, 0.6))
		bulb.shadow_enabled = false


const WINDOW_SHADER := """
shader_type spatial;
uniform vec3 wall_col = vec3(0.42, 0.42, 0.43);
uniform vec2 grid = vec2(8.0, 9.0);
uniform float seed = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	vec2 uv = UV * grid;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.3, f.y) * step(f.y, 0.78);
	float lit = step(0.72, h(cell));
	vec3 glass = mix(vec3(0.05, 0.06, 0.09), vec3(1.0, 0.78, 0.42), lit);
	ALBEDO = mix(wall_col * (0.9 + 0.1 * h(cell + 3.0)), glass, win);
	EMISSION = glass * win * lit * 1.4;
	ROUGHNESS = 0.9;
}
"""


static func _window_mat(seed_v: int, size: Vector3) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = WINDOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"seed", float(seed_v % 1000) * 0.37)
	# BoxMesh: UV развёртка по 3×2 граням — сетка окон примерно по этажам
	m.set_shader_parameter(&"grid", Vector2(maxf(size.z / 3.2, 2.0) * 3.0, size.y / 3.0 * 2.0))
	return m


static func _bus_stop(root: Node3D, at: Vector3) -> void:
	var m := mat(Color(0.3, 0.42, 0.5))
	Geo.block(root, Vector3(1.6, 0.1, 4.0), at + Vector3(0, 2.4, 0), m, false)
	Geo.block(root, Vector3(0.1, 2.4, 4.0), at + Vector3(-0.8, 1.2, 0), m, false)
	Geo.block(root, Vector3(0.5, 0.45, 3.2), at + Vector3(-0.4, 0.45, 0), Palette.m(&"wood"), true)
	label3d(root, "Ост. «Площадь 1905 года»", at + Vector3(0.82, 2.0, 0), PI * 0.5, 0.004)


## Здание управления: восемь этажей, гранитный цоколь, пилястры, крыльцо с козырьком, табличка.
static func _kgb_building(root: Node3D) -> void:
	var c := Vector3(KGB_DOOR.x + 12.0, 0, KGB_DOOR.z)
	var size := Vector3(24.0, 26.0, 44.0)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	body.mesh = bm
	body.position = c + Vector3(0, size.y * 0.5, 0)
	var wm := _window_mat(83, size)
	wm.set_shader_parameter(&"wall_col", Vector3(0.48, 0.40, 0.36))
	body.material_override = wm
	root.add_child(body)
	Geo.collider(root, size, body.position)
	var granite := mat(Color(0.18, 0.16, 0.16), 0.6)
	Geo.block(root, Vector3(0.6, 3.0, size.z + 0.6), Vector3(KGB_DOOR.x + 0.2, 1.5, c.z), granite, false)
	for k in 9:
		Geo.block(root, Vector3(0.5, size.y - 3.0, 0.8), Vector3(KGB_DOOR.x - 0.05, 3.0 + (size.y - 3.0) * 0.5, c.z - 20.0 + k * 5.0), mat(Color(0.52, 0.44, 0.4)), false)
	# Крыльцо: ступени, козырёк, двери, табличка
	for s in 3:
		Geo.block(root, Vector3(1.0 - s * 0.3, 0.16, 6.0 - s * 0.6), Vector3(KGB_DOOR.x - 1.2 + s * 0.3, 0.08 + s * 0.16, KGB_DOOR.z), granite, true)
	Geo.block(root, Vector3(2.4, 0.25, 6.4), Vector3(KGB_DOOR.x - 1.0, 3.6, KGB_DOOR.z), granite, false)
	Geo.block(root, Vector3(0.12, 2.6, 2.6), Vector3(KGB_DOOR.x - 0.1, 1.6, KGB_DOOR.z), mat(Color(0.28, 0.18, 0.1)), false)
	var lamp := Geo.omni(root, KGB_DOOR + Vector3(-1.4, 3.2, 0), 7.0, 1.4, Color(1.0, 0.86, 0.65))
	lamp.shadow_enabled = false
	label3d(root, "УПРАВЛЕНИЕ КГБ СССР\nпо Свердловской области", KGB_DOOR + Vector3(-0.17, 2.4, 2.0), -PI * 0.5, 0.0035, Color(0.85, 0.75, 0.45))
	# Ёлочки у фасада
	for k in 6:
		var sp := Props.faceted_spruce(0.45, 40 + k)
		sp.position = Vector3(KGB_DOOR.x - 2.2, 0.0, c.z - 18.0 + k * 7.0 + (3.5 if k >= 3 else 0.0))
		root.add_child(sp)
	# Разметка парковки — снегом не до конца замело
	for k in 5:
		Geo.block(root, Vector3(3.6, 0.012, 0.1), Vector3(PARK.position.x + 2.0, 0.012, PARK.position.y + k * 4.0), mat(Color(0.7, 0.7, 0.68)), false)


## «Волга» ГАЗ-24: кузов, кабина со стойками, решётка, фары, колёса. Начало — центр по земле, нос к −Z.
static func volga(col: Color, interior: bool) -> Node3D:
	var k := MeshKit.new(240 + int(col.r * 100))
	k.mottle = 0.03
	var chrome := Color(0.7, 0.72, 0.74)
	var glass := Color(0.12, 0.15, 0.19)
	var tyre := Color(0.06, 0.06, 0.06)
	k.box(Vector3(0, 0.62, 0), Vector3(1.8, 0.55, 4.7), col)                       # кузов
	k.box(Vector3(0, 0.62, -2.36), Vector3(1.7, 0.4, 0.04), chrome)                # решётка
	k.box(Vector3(0, 0.38, -2.4), Vector3(1.82, 0.14, 0.1), chrome)                # бампер
	k.box(Vector3(0, 0.38, 2.4), Vector3(1.82, 0.14, 0.1), chrome)
	if not interior:
		k.box(Vector3(0, 1.12, 0.25), Vector3(1.62, 0.48, 2.3), col)               # кабина
		k.box(Vector3(0, 1.12, -0.92), Vector3(1.5, 0.42, 0.04), glass, Basis(Vector3.RIGHT, deg_to_rad(-30.0)))
		k.box(Vector3(0, 1.12, 1.42), Vector3(1.5, 0.4, 0.04), glass, Basis(Vector3.RIGHT, deg_to_rad(25.0)))
		for sx: float in [-0.815, 0.815]:
			k.box(Vector3(sx, 1.13, 0.25), Vector3(0.02, 0.36, 2.0), glass)
		k.box(Vector3(0, 1.38, 0.25), Vector3(1.6, 0.06, 2.2), Color(0.86, 0.9, 0.95))   # снег на крыше
	for sx: float in [-0.88, 0.88]:
		for sz: float in [-1.45, 1.45]:
			k.tube([Vector3(sx - 0.1, 0.33, sz), Vector3(sx + 0.1, 0.33, sz)], [0.33, 0.33], tyre, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.5
	mi.material_override = m
	var root := Node3D.new()
	root.name = "Volga"
	root.add_child(mi)
	for sx: float in [-0.6, 0.6]:
		var hl := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.1
		hm.bottom_radius = 0.1
		hm.height = 0.04
		hl.mesh = hm
		hl.rotation.x = PI * 0.5
		hl.position = Vector3(sx, 0.66, -2.37)
		hl.material_override = glow_mat(Color(1.0, 0.92, 0.7), 1.5) if interior else mat(Color(0.8, 0.8, 0.75))
		root.add_child(hl)
	return root


## Торпеда и руль изнутри (вид водителя). Начало — как у volga().
static func volga_cabin(root: Node3D) -> Node3D:
	var steer := Node3D.new()
	steer.position = Vector3(-0.4, 1.0, -0.42)
	steer.rotation.x = deg_to_rad(-60.0)
	root.add_child(steer)
	var k := MeshKit.new(77)
	var black := Color(0.08, 0.08, 0.08)
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := TAU * (i + 1) / 12.0
		k.tube([Vector3(cos(a0) * 0.19, 0, sin(a0) * 0.19), Vector3(cos(a1) * 0.19, 0, sin(a1) * 0.19)], [0.017], black, 5)
	k.tube([Vector3(-0.19, 0, 0), Vector3(0.19, 0, 0)], [0.012], black, 4)
	var wmi := MeshInstance3D.new()
	wmi.mesh = k.commit()
	var wm := StandardMaterial3D.new()
	wm.vertex_color_use_as_albedo = true
	wmi.material_override = wm
	steer.add_child(wmi)
	var dash := mat(Color(0.12, 0.1, 0.09))
	Geo.block(root, Vector3(1.7, 0.22, 0.5), Vector3(0, 0.95, -0.75), dash, false)
	Geo.block(root, Vector3(1.7, 0.05, 0.05), Vector3(0, 1.52, -0.9), mat(Color(0.3, 0.3, 0.32)), false)
	for sx: float in [-0.83, 0.83]:
		var post := Geo.block(root, Vector3(0.07, 0.6, 0.07), Vector3(sx, 1.3, -0.95), mat(Color(0.3, 0.3, 0.32)), false)
		post.rotation.x = deg_to_rad(-30.0)
	Geo.block(root, Vector3(1.7, 0.05, 2.0), Vector3(0, 1.58, 0.2), mat(Color(0.5, 0.48, 0.44)), false)
	var gauge := Geo.cylinder(root, 0.07, 0.02, Vector3(-0.4, 1.07, -0.56), glow_mat(Color(0.5, 0.85, 0.55), 0.6), false)
	gauge.rotation.x = deg_to_rad(65.0)
	return steer


# --- Простые люди (вахтёр, секретарь) -----------------------------------------

static func person(coat: Color, skin := Color(0.78, 0.62, 0.52), hair := Color(0.2, 0.15, 0.12), skirt := false) -> Node3D:
	var k := MeshKit.new(int(coat.g * 1000) + 5)
	k.mottle = 0.04
	if skirt:
		k.tube([Vector3(0, 0.0, 0), Vector3(0, 0.55, 0)], [0.07, 0.07], Color(0.22, 0.2, 0.2), 6)
		k.tube([Vector3(0, 0.45, 0), Vector3(0, 0.95, 0)], [0.27, 0.2], coat * 0.8, 8)
	else:
		for sx: float in [-0.1, 0.1]:
			k.tube([Vector3(sx, 0.0, 0), Vector3(sx, 0.85, 0)], [0.075, 0.08], Color(0.15, 0.15, 0.17), 6)
	k.tube([Vector3(0, 0.85, 0), Vector3(0, 1.45, 0)], [0.21, 0.23], coat, 8)
	for sx: float in [-0.27, 0.27]:
		k.tube([Vector3(sx, 1.42, 0), Vector3(sx * 1.05, 0.95, 0.04)], [0.06, 0.05], coat, 6)
	k.tube([Vector3(0, 1.45, 0), Vector3(0, 1.55, 0)], [0.07, 0.07], skin, 6)
	k.blob(Vector3(0, 1.67, 0), Vector3(0.11, 0.13, 0.12), skin, 4, 8)
	k.blob(Vector3(0, 1.73, 0.02), Vector3(0.12, 0.09, 0.12), hair, 3, 8)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	var root := Node3D.new()
	root.add_child(mi)
	return root


# --- Холл и 4-й этаж ------------------------------------------------------------

## Вестибюль управления: тамбур с двойными дверями → проходная (турникет, будка постового, бюро пропусков) →
## мраморный зал с колоннами (Дзержинский в нише, знамя «щит и меч», мемориальная доска) → по сторонам дежурная
## часть за стеклом и гардероб → в глубине лифтовой холл (два лифта, лестница) и приёмная граждан.
static func lobby(root: Node3D) -> Dictionary:
	var c := LOBBY
	var marble := surf(2, Color(0.74, 0.72, 0.68), Color(0.5, 0.48, 0.46), 1.0)
	var marble_dk := surf(2, Color(0.34, 0.24, 0.21), Color(0.22, 0.15, 0.13), 1.0)
	var paint := surf(0, Color(0.78, 0.72, 0.6))
	var tile := surf(4, Color(0.6, 0.58, 0.54), Color(0.36, 0.32, 0.3))
	var ceil := surf(5, Color(0.88, 0.86, 0.8))
	var H := 5.2
	# Пол и потолок: зал (x −12…12, z 494…508), тамбур (z 508…512), лифтовой холл и приёмная (z 487…494)
	Geo.block(root, Vector3(24, 0.2, 25), c + Vector3(0, -0.1, -0.5), tile, true)
	Geo.block(root, Vector3(24, 0.2, 25), c + Vector3(0, H + 0.1, -0.5), ceil, true)
	# Наружный контур
	wall(root, Vector3(24, H, 0.3), c + Vector3(0, H * 0.5, 12.0), paint)
	wall(root, Vector3(0.3, H, 25), c + Vector3(-12, H * 0.5, -0.5), paint)
	wall(root, Vector3(0.3, H, 25), c + Vector3(12, H * 0.5, -0.5), paint)
	wall(root, Vector3(24, H, 0.3), c + Vector3(0, H * 0.5, -13.0), paint)
	# Тамбур: боковые стенки и внутренняя стена с проёмом 2.4 м, двойные двери нараспашку
	for sx: float in [-1.0, 1.0]:
		wall(root, Vector3(0.25, H, 4.0), c + Vector3(sx * 3.0, H * 0.5, 10.0), paint)
		wall(root, Vector3(10.3, H, 0.3), c + Vector3(sx * 6.75, H * 0.5, 8.0), marble)
		var leaf := Geo.block(root, Vector3(1.15, 2.5, 0.06), c + Vector3(sx * 1.55, 1.25, 7.5), mat(Color(0.3, 0.2, 0.12), 0.4), false)
		leaf.rotation.y = sx * deg_to_rad(80.0)
	Geo.block(root, Vector3(3.3, H - 2.6, 0.3), c + Vector3(0, 2.6 + (H - 2.6) * 0.5, 8.0), marble, true)   # над дверями тамбура
	# Мраморный цоколь по залу, колонны
	for sx: float in [-1.0, 1.0]:
		Geo.block(root, Vector3(0.05, 1.6, 13.6), c + Vector3(sx * 11.82, 0.8, 1.0), marble_dk, false)
	for p: Vector3 in [Vector3(-4.5, 0, 4.5), Vector3(4.5, 0, 4.5), Vector3(-4.5, 0, -1.5), Vector3(4.5, 0, -1.5)]:
		var col := Geo.cylinder(root, 0.38, H, c + p + Vector3(0, H * 0.5, 0), marble, true)
		col.name = "Column"
		Geo.block(root, Vector3(0.95, 0.3, 0.95), c + p + Vector3(0, 0.15, 0), marble_dk, false)
		Geo.block(root, Vector3(0.95, 0.3, 0.95), c + p + Vector3(0, H - 0.15, 0), marble_dk, false)
	# Проходная: турникет по оси, будка постового слева (стекло), шлагбаум-вертушка
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.7, 0.75, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	Geo.block(root, Vector3(2.4, 1.05, 1.6), c + Vector3(-1.9, 0.52, 5.6), surf(3, Color(0.42, 0.28, 0.17), Color(0.3, 0.2, 0.12)), true)
	Geo.block(root, Vector3(2.4, 1.2, 0.03), c + Vector3(-1.9, 1.65, 4.82), glass, false)
	Geo.block(root, Vector3(0.03, 1.2, 1.6), c + Vector3(-0.72, 1.65, 5.6), glass, false)
	Geo.block(root, Vector3(2.5, 0.06, 1.7), c + Vector3(-1.9, 2.28, 5.6), mat(Color(0.3, 0.2, 0.12)), false)
	Geo.block(root, Vector3(0.5, 1.0, 0.5), c + Vector3(0.9, 0.5, 5.6), mat(Color(0.5, 0.5, 0.52), 0.3), true)
	var pole := Geo.block(root, Vector3(1.0, 0.05, 0.05), c + Vector3(0.1, 0.95, 5.6), mat(Color(0.75, 0.15, 0.1), 0.4), false)
	pole.name = "TurnPole"
	var gate := StaticBody3D.new()
	gate.collision_layer = Geo.LAYER_WORLD
	gate.position = c + Vector3(0.1, 1.0, 5.6)
	gate.add_child(Geo.box_shape(Vector3(1.2, 2.0, 0.2)))
	root.add_child(gate)
	# Ограждение проходной от стены до стены (проход только через турникет)
	Geo.block(root, Vector3(8.0, 1.0, 0.08), c + Vector3(5.2, 0.5, 5.6), mat(Color(0.3, 0.2, 0.12), 0.5), true)
	Geo.block(root, Vector3(8.0, 1.0, 0.08), c + Vector3(-7.1, 0.5, 5.6), mat(Color(0.3, 0.2, 0.12), 0.5), true)
	# Северная стена зала: ниша с бюстом, знамя, мемориальная доска, цветы
	Geo.block(root, Vector3(3.0, 3.4, 0.3), c + Vector3(0, 1.7, -5.6), marble_dk, false)
	var bust := MeshInstance3D.new()
	var bsm := SphereMesh.new()
	bsm.radius = 0.3
	bsm.height = 0.7
	bust.mesh = bsm
	bust.material_override = mat(Color(0.3, 0.3, 0.32), 0.25)
	bust.position = c + Vector3(0, 2.25, -5.35)
	root.add_child(bust)
	Geo.block(root, Vector3(0.7, 0.35, 0.4), c + Vector3(0, 1.85, -5.35), mat(Color(0.25, 0.25, 0.27), 0.3), false)
	Geo.block(root, Vector3(0.9, 1.6, 0.6), c + Vector3(0, 0.8, -5.2), marble, true)
	label3d(root, "Ф. Э. ДЗЕРЖИНСКИЙ\n1877 — 1926", c + Vector3(0, 1.25, -4.89), 0.0, 0.003, Color(0.85, 0.72, 0.4))
	for k in 6:
		Geo.cylinder(root, 0.012, 0.45, c + Vector3(-0.3 + k * 0.12, 1.8, -4.98), mat(Color(0.15, 0.35, 0.12)), false)
		Geo.block(root, Vector3(0.06, 0.05, 0.06), c + Vector3(-0.3 + k * 0.12, 2.04, -4.98), mat(Color(0.8, 0.08, 0.06)), false)
	var banner := Geo.block(root, Vector3(4.2, 1.6, 0.04), c + Vector3(0, 4.1, -5.73), mat(Color(0.62, 0.06, 0.05)), false)
	banner.name = "Banner"
	Geo.block(root, Vector3(0.7, 0.85, 0.02), c + Vector3(0, 4.15, -5.7), mat(Color(0.82, 0.66, 0.28), 0.3), false)   # щит
	Geo.block(root, Vector3(0.06, 1.0, 0.025), c + Vector3(0, 4.15, -5.69), mat(Color(0.75, 0.75, 0.78), 0.2), false)   # меч
	label3d(root, "СЛАВА  ЧЕКИСТАМ", c + Vector3(0, 3.5, -5.68), 0.0, 0.006, Color(0.95, 0.85, 0.5))
	for sx: float in [-1.0, 1.0]:
		var plq := Geo.block(root, Vector3(1.4, 0.9, 0.05), c + Vector3(sx * 3.2, 1.8, -5.82), marble_dk, false)
		plq.name = "Plaque"
	label3d(root, "Чекистам,\nпогибшим при исполнении\nслужебного долга", c + Vector3(-3.2, 1.85, -5.78), 0.0, 0.0028, Color(0.85, 0.72, 0.4))
	label3d(root, "Вечная память", c + Vector3(3.2, 1.85, -5.78), 0.0, 0.0035, Color(0.85, 0.72, 0.4))
	# Проёмы в глубину: к лифтам (восток) и в приёмную (запад); стена между ними
	wall(root, Vector3(3.8, H, 0.3), c + Vector3(-9.9, H * 0.5, -6.0), paint)
	wall(root, Vector3(11.0, H, 0.3), c + Vector3(-1.1, H * 0.5, -6.0), paint)
	wall(root, Vector3(3.0, H, 0.3), c + Vector3(10.5, H * 0.5, -6.0), paint)
	Geo.block(root, Vector3(1.4, H - 2.6, 0.3), c + Vector3(-7.3, 2.6 + (H - 2.6) * 0.5, -6.0), paint, true)
	Geo.block(root, Vector3(4.6, H - 2.6, 0.3), c + Vector3(6.7, 2.6 + (H - 2.6) * 0.5, -6.0), paint, true)
	# Дежурная часть: стеклянная перегородка вдоль западной стены (x −12…−7, z −3…4)
	Geo.block(root, Vector3(0.04, 2.6, 7.0), c + Vector3(-7.0, 1.3, 0.5), glass, false)
	Geo.collider(root, Vector3(0.1, 2.6, 7.0), c + Vector3(-7.0, 1.3, 0.5))
	Geo.block(root, Vector3(0.08, 0.1, 7.0), c + Vector3(-7.0, 2.65, 0.5), mat(Color(0.3, 0.2, 0.12)), false)
	Geo.block(root, Vector3(0.08, 1.0, 7.0), c + Vector3(-7.0, 0.5, 0.5), surf(3, Color(0.42, 0.28, 0.17), Color(0.3, 0.2, 0.12)), false)
	label3d(root, "ДЕЖУРНАЯ ЧАСТЬ", c + Vector3(-6.97, 2.9, 0.5), PI * 0.5, 0.004, Color(0.9, 0.8, 0.5))
	# Лифтовой холл (x 4…12, z −13…−6): два лифта, лестница с перилами, ограждение «ремонт»
	wall(root, Vector3(0.3, H, 7.0), c + Vector3(4.0, H * 0.5, -9.5), paint)
	for lx: float in [6.5, 9.8]:
		Geo.block(root, Vector3(1.6, 2.5, 0.08), c + Vector3(lx, 1.25, -12.82), mat(Color(0.5, 0.48, 0.44), 0.25), false)
		Geo.block(root, Vector3(0.04, 2.5, 0.09), c + Vector3(lx, 1.25, -12.8), mat(Color(0.2, 0.2, 0.2)), false)
		label3d(root, "▲", c + Vector3(lx, 2.75, -12.78), 0.0, 0.004, Color(1.0, 0.6, 0.25))
	Geo.block(root, Vector3(0.12, 0.3, 0.06), c + Vector3(8.15, 1.3, -12.8), mat(Color(0.8, 0.65, 0.3), 0.3), false)   # кнопка вызова
	for k in 10:
		Geo.block(root, Vector3(1.6, 0.18, 0.3), c + Vector3(10.9, 0.09 + k * 0.18, -6.6 - k * 0.3), marble, true)
	Geo.block(root, Vector3(0.05, 0.05, 3.3), c + Vector3(10.05, 1.9, -8.0), mat(Color(0.3, 0.2, 0.12), 0.4), false).rotation.x = deg_to_rad(31.0)
	Geo.block(root, Vector3(1.4, 0.04, 0.04), c + Vector3(10.9, 0.9, -6.3), mat(Color(0.8, 0.1, 0.08)), false)
	label3d(root, "Проход закрыт", c + Vector3(10.9, 1.05, -6.28), 0.0, 0.0025, Color(0.95, 0.9, 0.8))
	# Приёмная граждан (x −12…−4, z −13…−6): скамьи, окошко приёма, плакат
	wall(root, Vector3(0.3, H, 7.0), c + Vector3(-4.0, H * 0.5, -9.5), paint)
	Geo.block(root, Vector3(1.2, 0.5, 0.05), c + Vector3(-8.0, 1.4, -12.83), glass, false)
	Geo.block(root, Vector3(1.4, 0.7, 0.06), c + Vector3(-8.0, 1.4, -12.86), mat(Color(0.3, 0.2, 0.12)), false)
	label3d(root, "ПРИЁМ ЗАЯВЛЕНИЙ\nОТ ГРАЖДАН", c + Vector3(-8.0, 2.0, -12.8), 0.0, 0.0028, Color(0.2, 0.15, 0.12))
	# Свет: люстры в зале, плафоны в тамбуре и холлах
	for p: Vector3 in [Vector3(0, H - 0.6, 1.5), Vector3(-6.0, H - 0.6, 1.5), Vector3(6.0, H - 0.6, 1.5)]:
		var l := Geo.omni(root, c + p, 11.0, 1.15, Color(1.0, 0.86, 0.62))
		l.shadow_enabled = false
		Geo.cylinder(root, 0.02, 0.6, c + p + Vector3(0, 0.3, 0), mat(Color(0.7, 0.55, 0.25), 0.3), false)
		for k in 6:
			var a := TAU * k / 6.0
			Geo.block(root, Vector3(0.12, 0.16, 0.12), c + p + Vector3(cos(a) * 0.35, -0.05, sin(a) * 0.35), glow_mat(Color(1.0, 0.88, 0.6), 1.6), false)
		Geo.cylinder(root, 0.38, 0.04, c + p, mat(Color(0.7, 0.55, 0.25), 0.3), false)
	for p: Vector3 in [Vector3(0, H - 0.4, 10.0), Vector3(8.0, H - 0.4, -9.5), Vector3(-8.0, H - 0.4, -9.5)]:
		var l2 := Geo.omni(root, c + p, 7.0, 0.95, Color(1.0, 0.9, 0.72))
		l2.shadow_enabled = false
		Geo.block(root, Vector3(0.6, 0.05, 0.6), c + p + Vector3(0, 0.35, 0), glow_mat(Color(1.0, 0.95, 0.8), 1.2), false)
	return {"spawn": c + Vector3(0, 0.05, 11.0), "guard": c + Vector3(-1.9, 1.3, 5.0), "lift": c + Vector3(8.15, 1.2, -12.4),
		"gate": gate, "pole": pole, "duty": c + Vector3(-9.5, 0, 0.5), "cloak": c + Vector3(9.0, 0, 2.0), "reception": c + Vector3(-8.0, 0, -9.5)}


## Коридор с кабинетами по сторонам. Возвращает точки интереса.
static func floor4(root: Node3D) -> Dictionary:
	var c := FLOOR4
	var green := surf(0, Color(0.3, 0.42, 0.34))
	var white := surf(0, Color(0.8, 0.78, 0.72))
	var parquet := surf(1, Color(0.42, 0.27, 0.15), Color(0.3, 0.18, 0.1))
	var x0 := -16.0
	var x1 := 16.0
	var span := x1 - x0
	var zn := c.z + CORR_HALF
	var zs := c.z - CORR_HALF
	# Пол и потолок всего этажа
	Geo.block(root, Vector3(span, 0.2, CORR_HALF * 2 + ROOM_D * 2 + 0.6), c + Vector3(0, -0.1, 0), parquet, true)
	Geo.block(root, Vector3(span, 0.2, CORR_HALF * 2 + ROOM_D * 2 + 0.6), c + Vector3(0, WALL_H + 0.1, 0), surf(5, Color(0.86, 0.85, 0.8)), true)
	Geo.block(root, Vector3(span, 0.02, 1.2), c + Vector3(0, 0.01, 0), mat(Color(0.45, 0.1, 0.08)), false)   # дорожка
	# Торцы коридора: окно на западе, лифт на востоке
	wall(root, Vector3(0.3, WALL_H, CORR_HALF * 2), c + Vector3(x0, WALL_H * 0.5, 0), white)
	wall(root, Vector3(0.3, WALL_H, CORR_HALF * 2), c + Vector3(x1, WALL_H * 0.5, 0), white)
	Geo.block(root, Vector3(0.05, 1.4, 1.4), c + Vector3(x0 + 0.17, 1.7, 0), glow_mat(Color(0.12, 0.16, 0.28), 0.6), false)
	Geo.block(root, Vector3(0.1, 2.4, 1.6), c + Vector3(x1 - 0.17, 1.2, 0), mat(Color(0.45, 0.42, 0.36), 0.3), false)
	label3d(root, "4", c + Vector3(x1 - 0.22, 2.7, 0), -PI * 0.5, 0.006, Color(1.0, 0.7, 0.3))
	# Стены коридора с проёмами в кабинеты; панели — зелёная краска до 1.5 м
	for side: float in [1.0, -1.0]:
		var z := c.z + side * CORR_HALF
		var doors: Array = []
		for id: StringName in ROOMS:
			var r: Array = ROOMS[id]
			if float(r[2]) == side:
				doors.append((float(r[0]) + float(r[1])) * 0.5)
		if side < 0.0:
			doors.append(WING_X)   # проход в южное крыло
		doors.sort()
		var cur := x0
		for dx: float in doors:
			_wall_seg(root, cur, dx - 0.6, z, green, white)
			# над дверью; дверь в кабинет — дерматин, приоткрыта внутрь
			Geo.block(root, Vector3(1.2, WALL_H - 2.2, 0.2), Vector3(dx, 2.2 + (WALL_H - 2.2) * 0.5, z), white, true)
			if not (side < 0.0 and is_equal_approx(dx, WING_X)):
				door_leaf(root, Vector3(dx, 0, z + side * 0.02), true, side)
			cur = dx + 0.6
		_wall_seg(root, cur, x1, z, green, white)
	# Кабинеты: стены, окна наружу, свет, табличка у двери
	var spots := {}
	for id: StringName in ROOMS:
		var r: Array = ROOMS[id]
		var rx0: float = r[0]
		var rx1: float = r[1]
		var side: float = r[2]
		var zin := c.z + side * CORR_HALF
		var zout := zin + side * ROOM_D
		var cz := (zin + zout) * 0.5
		wall(root, Vector3(rx1 - rx0, WALL_H, 0.25), Vector3((rx0 + rx1) * 0.5, WALL_H * 0.5, zout), white)
		wall(root, Vector3(0.2, WALL_H, ROOM_D), Vector3(rx0, WALL_H * 0.5, cz), white)
		wall(root, Vector3(0.2, WALL_H, ROOM_D), Vector3(rx1, WALL_H * 0.5, cz), white)
		Geo.block(root, Vector3(rx1 - rx0 - 0.3, 1.0, 0.05), Vector3((rx0 + rx1) * 0.5, 0.5, zout - side * 0.14), green, false)   # под подоконник — окно не перекрывает
		# Окно: за стеклом — дом напротив с горящими окнами; рама крестом, подоконник, батарея
		var wx := (rx0 + rx1) * 0.5
		var wz := zout - side * 0.13   # стекло — в проёме, за рамой
		var view := MeshInstance3D.new()
		var vq := QuadMesh.new()
		vq.size = Vector2(1.6, 1.5)
		view.mesh = vq
		var vm := _window_mat(int(wx * 7.0) + 11, Vector3(1, 6, 6))
		vm.set_shader_parameter(&"wall_col", Vector3(0.1, 0.12, 0.2))
		vm.set_shader_parameter(&"grid", Vector2(4.0, 3.5))
		view.material_override = vm
		view.position = Vector3(wx, 1.8, wz)
		view.rotation.y = PI if side > 0 else 0.0
		view.name = "Window"
		root.add_child(view)
		var frame_m := mat(Color(0.82, 0.8, 0.74))
		Geo.block(root, Vector3(1.7, 0.08, 0.08), Vector3(wx, 1.8, wz - side * 0.05), frame_m, false)
		Geo.block(root, Vector3(0.08, 1.55, 0.08), Vector3(wx, 1.8, wz - side * 0.05), frame_m, false)
		for fy: float in [1.04, 2.56]:
			Geo.block(root, Vector3(1.75, 0.08, 0.1), Vector3(wx, fy, wz - side * 0.05), frame_m, false)
		Geo.block(root, Vector3(1.9, 0.05, 0.3), Vector3(wx, 1.02, wz - side * 0.15), frame_m, false)
		for k in 8:
			Geo.block(root, Vector3(0.07, 0.55, 0.1), Vector3(wx - 0.5 + k * 0.14, 0.55, wz - side * 0.2), mat(Color(0.62, 0.6, 0.55)), false)
		var lamp := Geo.omni(root, Vector3((rx0 + rx1) * 0.5, WALL_H - 0.4, cz), 7.0, 1.1, Color(1.0, 0.9, 0.72))
		lamp.shadow_enabled = false
		Geo.block(root, Vector3(0.5, 0.06, 0.5), Vector3((rx0 + rx1) * 0.5, WALL_H - 0.03, cz), glow_mat(Color(1.0, 0.95, 0.8), 1.2), false)
		var dx := (rx0 + rx1) * 0.5
		Geo.block(root, Vector3(0.24, 0.12, 0.01), Vector3(dx + 0.9, 1.75, zin - side * 0.11), mat(Color(0.12, 0.1, 0.08)), false)   # табличка
		label3d(root, String(id), Vector3(dx + 0.9, 1.75, zin - side * 0.12), 0.0 if side < 0 else PI, 0.0016, Color(0.9, 0.82, 0.55))
		spots[id] = {"center": Vector3(dx, 0.0, cz), "door": Vector3(dx, 0.0, zin), "side": side, "x0": rx0, "x1": rx1, "zout": zout}
	# Свет в коридоре
	for k in 4:
		var l := Geo.omni(root, c + Vector3(x0 + 4.0 + k * 8.0, WALL_H - 0.3, 0), 7.0, 0.9, Color(1.0, 0.92, 0.78))
		l.shadow_enabled = false
		Geo.block(root, Vector3(0.9, 0.05, 0.25), c + Vector3(x0 + 4.0 + k * 8.0, WALL_H - 0.03, 0), glow_mat(Color(1.0, 0.96, 0.85), 1.2), false)
	spots["spawn"] = c + Vector3(x1 - 1.2, 0.05, 0)
	spots["lift"] = c + Vector3(x1 - 0.4, 1.2, 0)
	return spots


## Кабина лифта: полированные стены, раздвижные створки, панель с кнопками и табло.
static func lift_cabin(root: Node3D) -> Dictionary:
	var c := LIFT
	var wood := surf(3, Color(0.48, 0.33, 0.2), Color(0.36, 0.24, 0.14), 1.0)
	var steel := mat(Color(0.55, 0.56, 0.58), 0.25)
	Geo.block(root, Vector3(2.0, 0.1, 2.0), c + Vector3(0, -0.05, 0), surf(4, Color(0.3, 0.26, 0.22), Color(0.2, 0.17, 0.14)), true)
	Geo.block(root, Vector3(2.0, 0.1, 2.0), c + Vector3(0, 2.45, 0), mat(Color(0.7, 0.68, 0.62)), true)
	wall(root, Vector3(2.0, 2.4, 0.1), c + Vector3(0, 1.2, 1.0), wood)
	wall(root, Vector3(0.1, 2.4, 2.0), c + Vector3(-1.0, 1.2, 0), wood)
	wall(root, Vector3(0.1, 2.4, 2.0), c + Vector3(1.0, 1.2, 0), wood)
	Geo.block(root, Vector3(1.9, 0.04, 0.04), c + Vector3(0, 0.95, 0.94), steel, false)   # поручень
	# Передняя стенка с проёмом и две створки
	wall(root, Vector3(0.45, 2.4, 0.1), c + Vector3(-0.78, 1.2, -1.0), steel)
	wall(root, Vector3(0.45, 2.4, 0.1), c + Vector3(0.78, 1.2, -1.0), steel)
	var dl := Geo.block(root, Vector3(0.55, 2.2, 0.05), c + Vector3(-0.28, 1.1, -0.97), steel, true)
	var dr := Geo.block(root, Vector3(0.55, 2.2, 0.05), c + Vector3(0.28, 1.1, -0.97), steel, true)
	# Панель: латунные кнопки 1–8, табло этажа
	Geo.block(root, Vector3(0.05, 0.6, 0.22), c + Vector3(0.94, 1.3, -0.6), mat(Color(0.2, 0.18, 0.15)), false)
	for k in 8:
		Geo.cylinder(root, 0.018, 0.02, c + Vector3(0.91, 1.08 + (k / 2) * 0.12, -0.66 + (k % 2) * 0.1), mat(Color(0.8, 0.65, 0.3), 0.2), false).rotation.z = PI * 0.5
	var ind := label3d(root, "1", c + Vector3(0, 2.25, -0.94), 0.0, 0.006, Color(1.0, 0.55, 0.2))
	var lamp := Geo.omni(root, c + Vector3(0, 2.2, 0), 3.5, 1.1, Color(1.0, 0.9, 0.7))
	lamp.shadow_enabled = false
	Geo.block(root, Vector3(0.6, 0.04, 0.6), c + Vector3(0, 2.39, 0), glow_mat(Color(1.0, 0.95, 0.8), 1.2), false)
	return {"door_l": dl, "door_r": dr, "indicator": ind, "panel": c + Vector3(0.9, 1.3, -0.6), "spawn": c + Vector3(0, 0.05, 0.4), "out": c + Vector3(0, 1.0, -1.4)}


## Южное крыло: коридор от главного, кабинеты 422 (радиоконтроль), 424 (красный уголок), в торце — спецхран.
static func wing(root: Node3D) -> Dictionary:
	var green := surf(0, Color(0.3, 0.42, 0.34))
	var white := surf(0, Color(0.8, 0.78, 0.72))
	var parquet := surf(1, Color(0.42, 0.27, 0.15), Color(0.3, 0.18, 0.1))
	var z0 := FLOOR4.z - CORR_HALF
	var z1 := z0 - WING_LEN
	var x := WING_X
	Geo.block(root, Vector3(9.0, 0.2, WING_LEN + 0.4), Vector3(x + 2.4, -0.1, (z0 + z1) * 0.5), parquet, true)
	Geo.block(root, Vector3(9.0, 0.2, WING_LEN + 0.4), Vector3(x + 2.4, WALL_H + 0.1, (z0 + z1) * 0.5), white, true)
	Geo.block(root, Vector3(1.0, 0.02, WING_LEN), Vector3(x, 0.01, (z0 + z1) * 0.5), mat(Color(0.45, 0.1, 0.08)), false)
	# Западная стена крыла — глухая; восточная — с двумя дверями
	_wall_z(root, x - WING_HALF, z1, z0, [], green, white)
	var doors := [z0 - 3.2, z0 - 8.6]
	_wall_z(root, x + WING_HALF, z1, z0, doors, green, white)
	# Торец: дверь спецхрана (запертая), обитая железом
	wall(root, Vector3(WING_HALF * 2 + 0.2, WALL_H, 0.25), Vector3(x, WALL_H * 0.5, z1), white)
	var sdoor := Geo.block(root, Vector3(1.0, 2.1, 0.06), Vector3(x, 1.05, z1 + 0.15), mat(Color(0.28, 0.3, 0.3), 0.3), false)
	sdoor.name = "SpecDoor"
	for k in 5:
		Geo.block(root, Vector3(1.02, 0.03, 0.07), Vector3(x, 0.3 + k * 0.4, z1 + 0.16), mat(Color(0.2, 0.2, 0.2)), false)
	label3d(root, "СПЕЦХРАН\nПосторонним вход воспрещён", Vector3(x, 2.35, z1 + 0.2), 0.0, 0.0022, Color(0.85, 0.2, 0.15))
	var spots := {"spec": Vector3(x, 1.2, z1 + 0.4)}
	# Кабинеты к востоку
	var ids := [&"422", &"424"]
	for i in 2:
		var dz: float = doors[i]
		var rz0 := dz - 2.4
		var rz1 := dz + 2.4
		var rx0 := x + WING_HALF
		var rx1 := rx0 + 5.0
		wall(root, Vector3(0.25, WALL_H, rz1 - rz0), Vector3(rx1, WALL_H * 0.5, (rz0 + rz1) * 0.5), white)
		wall(root, Vector3(rx1 - rx0, WALL_H, 0.2), Vector3((rx0 + rx1) * 0.5, WALL_H * 0.5, rz0), white)
		wall(root, Vector3(rx1 - rx0, WALL_H, 0.2), Vector3((rx0 + rx1) * 0.5, WALL_H * 0.5, rz1), white)
		Geo.block(root, Vector3(0.05, 1.5, rz1 - rz0 - 0.3), Vector3(rx1 - 0.14, 0.75, (rz0 + rz1) * 0.5), green, false)
		var l := Geo.omni(root, Vector3((rx0 + rx1) * 0.5, WALL_H - 0.4, dz), 7.0, 1.0, Color(1.0, 0.9, 0.72))
		l.shadow_enabled = false
		Geo.block(root, Vector3(0.5, 0.06, 0.5), Vector3((rx0 + rx1) * 0.5, WALL_H - 0.03, dz), glow_mat(Color(1.0, 0.95, 0.8), 1.2), false)
		Geo.block(root, Vector3(0.01, 0.12, 0.24), Vector3(x + WING_HALF + 0.11, 1.75, dz - 0.9), mat(Color(0.12, 0.1, 0.08)), false)
		label3d(root, String(ids[i]), Vector3(x + WING_HALF + 0.12, 1.75, dz - 0.9), -PI * 0.5, 0.0016, Color(0.9, 0.82, 0.55))
		spots[ids[i]] = {"center": Vector3((rx0 + rx1) * 0.5, 0, dz), "door": Vector3(x + WING_HALF, 0, dz), "x0": rx0, "x1": rx1, "z0": rz0, "z1": rz1}
	for k in 2:
		var cl := Geo.omni(root, Vector3(x, WALL_H - 0.3, z0 - 3.0 - k * 6.0), 6.0, 0.85, Color(1.0, 0.92, 0.78))
		cl.shadow_enabled = false
		Geo.block(root, Vector3(0.25, 0.05, 0.9), Vector3(x, WALL_H - 0.03, z0 - 3.0 - k * 6.0), glow_mat(Color(1.0, 0.96, 0.85), 1.2), false)
	return spots


static func _wall_z(root: Node3D, x: float, z1: float, z0: float, doors: Array, green: Material, white: Material) -> void:
	var cur := z1
	var ds := doors.duplicate()
	ds.sort()
	for dz: float in ds:
		_seg_z(root, x, cur, dz - 0.6, green, white)
		Geo.block(root, Vector3(0.2, WALL_H - 2.2, 1.2), Vector3(x, 2.2 + (WALL_H - 2.2) * 0.5, dz), white, true)
		door_leaf(root, Vector3(x + 0.02, 0, dz), false, 1.0)
		cur = dz + 0.6
	_seg_z(root, x, cur, z0, green, white)


static func _seg_z(root: Node3D, x: float, a: float, b: float, green: Material, white: Material) -> void:
	if b - a < 0.05:
		return
	wall(root, Vector3(0.2, WALL_H, b - a), Vector3(x, WALL_H * 0.5, (a + b) * 0.5), white)
	for sx: float in [-0.11, 0.11]:
		Geo.block(root, Vector3(0.02, 1.5, b - a), Vector3(x + sx, 0.75, (a + b) * 0.5), green, false)


static func _wall_seg(root: Node3D, a: float, b: float, z: float, green: Material, white: Material) -> void:
	if b - a < 0.05:
		return
	wall(root, Vector3(b - a, WALL_H, 0.2), Vector3((a + b) * 0.5, WALL_H * 0.5, z), white)
	for sz: float in [-0.11, 0.11]:
		Geo.block(root, Vector3(b - a, 1.5, 0.02), Vector3((a + b) * 0.5, 0.75, z + sz), green, false)


## Телефон с диском: корпус, трубка на рычагах, витой шнур. Начало — низ по центру.
static func phone() -> Node3D:
	var k := MeshKit.new(91)
	var body := Color(0.12, 0.12, 0.13)
	k.box(Vector3(0, 0.05, 0), Vector3(0.22, 0.1, 0.24), body)
	k.box(Vector3(0, 0.11, 0.02), Vector3(0.18, 0.04, 0.16), body)
	k.tube([Vector3(0, 0.1, -0.06), Vector3(0, 0.12, -0.08)], [0.055], Color(0.75, 0.74, 0.7), 12)
	k.tube([Vector3(-0.1, 0.15, 0.04), Vector3(0.1, 0.15, 0.04)], [0.025], body, 6)
	k.blob(Vector3(-0.11, 0.15, 0.04), Vector3(0.035, 0.03, 0.045), body, 3, 6)
	k.blob(Vector3(0.11, 0.15, 0.04), Vector3(0.035, 0.03, 0.045), body, 3, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.35
	mi.material_override = m
	return mi


## Вешалка-стойка: штанга, крючки, ножки. Начало — низ.
static func coat_rack() -> Node3D:
	var root := Node3D.new()
	var w := Palette.m(&"wood")
	Geo.cylinder(root, 0.03, 1.8, Vector3(0, 0.9, 0), w, false)
	for i in 4:
		var a := i * TAU / 4.0
		var hook := Geo.cylinder(root, 0.012, 0.22, Vector3(cos(a) * 0.08, 1.72, sin(a) * 0.08), w, false)
		hook.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)
		var foot := Geo.cylinder(root, 0.02, 0.36, Vector3(cos(a) * 0.14, 0.06, sin(a) * 0.14), w, false)
		foot.rotation = Vector3(sin(a) * 1.3, 0, -cos(a) * 1.3)
	return root


## Пальто или шапка на крючке (появляются, когда повесил).
static func coat() -> Node3D:
	var k := MeshKit.new(55)
	var c := Color(0.16, 0.15, 0.14)
	k.tube([Vector3(0, 1.66, 0.1), Vector3(0, 0.75, 0.16)], [0.12, 0.26], c, 8)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	return mi


static func hat() -> Node3D:
	var k := MeshKit.new(56)
	k.blob(Vector3(0, 1.84, 0), Vector3(0.13, 0.09, 0.13), Color(0.3, 0.24, 0.18), 4, 8)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	return mi
