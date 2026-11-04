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


static func wall(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	Geo.block(parent, size, pos, m, true)


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

static func lobby(root: Node3D) -> Dictionary:
	var c := LOBBY
	var marble := mat(Color(0.55, 0.52, 0.48), 0.4)
	var paint := mat(Color(0.55, 0.5, 0.42))
	var floor_m := mat(Color(0.32, 0.22, 0.16), 0.5)
	Geo.block(root, Vector3(16, 0.2, 12), c + Vector3(0, -0.1, 0), floor_m, true)
	Geo.block(root, Vector3(16, 0.2, 12), c + Vector3(0, 4.6, 0), mat(Color(0.75, 0.73, 0.68)), true)
	wall(root, Vector3(16, 4.6, 0.3), c + Vector3(0, 2.3, -6), paint)
	wall(root, Vector3(16, 4.6, 0.3), c + Vector3(0, 2.3, 6), paint)
	wall(root, Vector3(0.3, 4.6, 12), c + Vector3(-8, 2.3, 0), paint)
	wall(root, Vector3(0.3, 4.6, 12), c + Vector3(8, 2.3, 0), paint)
	Geo.block(root, Vector3(16, 1.4, 0.05), c + Vector3(0, 0.7, -5.84), marble, false)
	# Ковровая дорожка от двери к лифту, вахта, бюст, лифт
	Geo.block(root, Vector3(1.6, 0.02, 11), c + Vector3(0, 0.01, 0), mat(Color(0.5, 0.1, 0.08)), false)
	Geo.block(root, Vector3(2.4, 1.1, 0.8), c + Vector3(-4.0, 0.55, -1.0), Palette.m(&"wood"), true)
	Geo.block(root, Vector3(2.5, 0.06, 0.9), c + Vector3(-4.0, 1.13, -1.0), mat(Color(0.25, 0.18, 0.12)), false)
	var lampv := Geo.omni(root, c + Vector3(-4.0, 2.2, -1.2), 5.0, 1.2, Color(1.0, 0.85, 0.6))
	lampv.shadow_enabled = false
	var guard := person(Color(0.22, 0.28, 0.2))
	guard.position = c + Vector3(-4.0, 0.0, -2.0)
	root.add_child(guard)
	Geo.block(root, Vector3(0.6, 1.2, 0.6), c + Vector3(5.0, 0.6, -4.8), marble, true)
	var bust := MeshInstance3D.new()
	var bsm := SphereMesh.new()
	bsm.radius = 0.28
	bsm.height = 0.62
	bust.mesh = bsm
	bust.material_override = mat(Color(0.3, 0.3, 0.32), 0.3)
	bust.position = c + Vector3(5.0, 1.55, -4.8)
	root.add_child(bust)
	label3d(root, "Ф. Э. ДЗЕРЖИНСКИЙ", c + Vector3(5.0, 1.0, -4.49), 0.0, 0.0025)
	Geo.block(root, Vector3(2.0, 2.6, 0.1), c + Vector3(0, 1.3, -5.8), mat(Color(0.45, 0.42, 0.36), 0.3), false)
	label3d(root, "▲▼", c + Vector3(1.4, 1.4, -5.72), 0.0, 0.004, Color(1.0, 0.7, 0.3))
	for k in 3:
		var l := Geo.omni(root, c + Vector3(-4.0 + k * 4.0, 4.1, 0), 9.0, 1.0, Color(1.0, 0.9, 0.75))
		l.shadow_enabled = false
	return {"spawn": c + Vector3(0, 0.05, 5.0), "guard": c + Vector3(-4.0, 1.0, -1.0), "lift": c + Vector3(0, 1.2, -5.5)}


## Коридор с кабинетами по сторонам. Возвращает точки интереса.
static func floor4(root: Node3D) -> Dictionary:
	var c := FLOOR4
	var green := mat(Color(0.3, 0.42, 0.34))
	var white := mat(Color(0.8, 0.78, 0.72))
	var parquet := mat(Color(0.38, 0.25, 0.15), 0.5)
	var x0 := -16.0
	var x1 := 16.0
	var span := x1 - x0
	var zn := c.z + CORR_HALF
	var zs := c.z - CORR_HALF
	# Пол и потолок всего этажа
	Geo.block(root, Vector3(span, 0.2, CORR_HALF * 2 + ROOM_D * 2 + 0.6), c + Vector3(0, -0.1, 0), parquet, true)
	Geo.block(root, Vector3(span, 0.2, CORR_HALF * 2 + ROOM_D * 2 + 0.6), c + Vector3(0, WALL_H + 0.1, 0), white, true)
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
		doors.sort()
		var cur := x0
		for dx: float in doors:
			_wall_seg(root, cur, dx - 0.6, z, green, white)
			# над дверью
			Geo.block(root, Vector3(1.2, WALL_H - 2.2, 0.2), Vector3(dx, 2.2 + (WALL_H - 2.2) * 0.5, z), white, true)
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
		Geo.block(root, Vector3(rx1 - rx0 - 0.3, 1.5, 0.05), Vector3((rx0 + rx1) * 0.5, 0.75, zout - side * 0.14), green, false)
		# Окно: за стеклом — дом напротив с горящими окнами; рама крестом, подоконник, батарея
		var wx := (rx0 + rx1) * 0.5
		var wz := zout - side * 0.15
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
		Geo.block(root, Vector3(1.7, 0.08, 0.08), Vector3(wx, 1.8, wz - side * 0.03), frame_m, false)
		Geo.block(root, Vector3(0.08, 1.55, 0.08), Vector3(wx, 1.8, wz - side * 0.03), frame_m, false)
		for fy: float in [1.04, 2.56]:
			Geo.block(root, Vector3(1.75, 0.08, 0.1), Vector3(wx, fy, wz - side * 0.03), frame_m, false)
		Geo.block(root, Vector3(1.9, 0.05, 0.3), Vector3(wx, 1.0, wz - side * 0.13), frame_m, false)
		for k in 8:
			Geo.block(root, Vector3(0.07, 0.55, 0.1), Vector3(wx - 0.5 + k * 0.14, 0.55, wz - side * 0.12), mat(Color(0.62, 0.6, 0.55)), false)
		var lamp := Geo.omni(root, Vector3((rx0 + rx1) * 0.5, WALL_H - 0.4, cz), 7.0, 1.1, Color(1.0, 0.9, 0.72))
		lamp.shadow_enabled = false
		Geo.block(root, Vector3(0.5, 0.06, 0.5), Vector3((rx0 + rx1) * 0.5, WALL_H - 0.03, cz), glow_mat(Color(1.0, 0.95, 0.8), 1.2), false)
		var dx := (rx0 + rx1) * 0.5
		label3d(root, String(id), Vector3(dx + 0.9, 1.75, zin - side * 0.12), 0.0 if side < 0 else PI, 0.004, Color(0.9, 0.82, 0.55))
		spots[id] = {"center": Vector3(dx, 0.0, cz), "door": Vector3(dx, 0.0, zin), "side": side, "x0": rx0, "x1": rx1, "zout": zout}
	# Свет в коридоре
	for k in 4:
		var l := Geo.omni(root, c + Vector3(x0 + 4.0 + k * 8.0, WALL_H - 0.3, 0), 7.0, 0.9, Color(1.0, 0.92, 0.78))
		l.shadow_enabled = false
		Geo.block(root, Vector3(0.9, 0.05, 0.25), c + Vector3(x0 + 4.0 + k * 8.0, WALL_H - 0.03, 0), glow_mat(Color(1.0, 0.96, 0.85), 1.2), false)
	spots["spawn"] = c + Vector3(x1 - 1.2, 0.05, 0)
	spots["lift"] = c + Vector3(x1 - 0.4, 1.2, 0)
	return spots


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
