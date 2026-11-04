class_name EpLife
extends Node
## Жизнь эпилога: люди (ходят, курят, печатают, ждут), транспорт на проспекте и мелочи по кабинетам.
## Люди — гранёные фигуры MeshKit в одной палитре с игрой; у части — реплика по [E].
## Анимация простая и дешёвая: проход по точкам с покачиванием, дым сигареты, руки над машинкой.

const TYPE_SND := "res://assets/audio/clank.ogg"

var ep: Epilogue
var _walkers: Array[Dictionary] = []     ## {"node", "pts", "i", "spd", "t"}
var _bobbers: Array[Dictionary] = []     ## {"node", "base", "amp", "f", "ph"}
var _spinners: Array[Node3D] = []
var _typist: Node3D
var _type_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(e: Epilogue) -> void:
	ep = e
	_rng.seed = 1983


func _ready() -> void:
	name = "EpLife"
	var w := ep._world
	_street(w)
	_lobby(w)
	_corridor(w)
	_rooms(w)


# --- Люди ------------------------------------------------------------------------------

## Фигура: пальто/китель/платье, голова, причёска; по желанию — шапка, очки, папка, сигарета.
static func figure(o: Dictionary) -> Node3D:
	var coat: Color = o.get("coat", Color(0.2, 0.2, 0.22))
	var skin: Color = o.get("skin", Color(0.78, 0.62, 0.52))
	var hair: Color = o.get("hair", Color(0.2, 0.15, 0.12))
	var k := MeshKit.new(int(coat.r * 997 + coat.b * 313) + int(o.get("seed", 0)))
	k.mottle = 0.04
	var sit: bool = o.get("sit", false)
	var hy := 0.0 if not sit else -0.42
	if o.get("skirt", false):
		k.tube([Vector3(-0.08, 0, 0), Vector3(-0.08, 0.5, 0)], [0.05, 0.06], Color(0.55, 0.45, 0.4), 6)
		k.tube([Vector3(0.08, 0, 0), Vector3(0.08, 0.5, 0)], [0.05, 0.06], Color(0.55, 0.45, 0.4), 6)
		k.tube([Vector3(0, 0.42 + hy, 0), Vector3(0, 0.95 + hy, 0)], [0.26, 0.19], o.get("skirt_col", coat * 0.8), 8)
	elif sit:
		for sx: float in [-0.1, 0.1]:
			k.tube([Vector3(sx, 0.0, 0.42), Vector3(sx, 0.45, 0.42), Vector3(sx, 0.45, 0.0)], [0.07, 0.08, 0.08], Color(0.15, 0.15, 0.17), 6)
	else:
		for sx: float in [-0.1, 0.1]:
			k.tube([Vector3(sx, 0.0, 0), Vector3(sx, 0.85, 0)], [0.075, 0.08], o.get("trousers", Color(0.15, 0.15, 0.17)), 6)
			k.box(Vector3(sx, 0.04, -0.05), Vector3(0.11, 0.08, 0.26), Color(0.07, 0.07, 0.07))
	var long_coat: bool = o.get("long", false)
	k.tube([Vector3(0, (0.45 if long_coat else 0.85) + hy, 0), Vector3(0, 1.45 + hy, 0)], [0.25 if long_coat else 0.21, 0.23], coat, 8)
	k.box(Vector3(0, 1.4 + hy, -0.15), Vector3(0.12, 0.14, 0.04), o.get("shirt", Color(0.85, 0.85, 0.82)))   # воротник/рубашка
	var arm: StringName = o.get("arm", &"down")
	for sx: float in [-0.27, 0.27]:
		var hand: Vector3
		match arm:
			&"type":
				hand = Vector3(sx * 0.6, 0.95 + hy, -0.42)
			&"smoke":
				hand = Vector3(sx * 0.4, 1.55 + hy, -0.18) if sx > 0 else Vector3(sx * 1.05, 0.95 + hy, 0.04)
			&"folder":
				hand = Vector3(sx * 0.6, 1.1 + hy, -0.25) if sx < 0 else Vector3(sx * 1.05, 0.95 + hy, 0.04)
			_:
				hand = Vector3(sx * 1.05, 0.95 + hy, 0.04)
		k.tube([Vector3(sx, 1.42 + hy, 0), hand], [0.06, 0.05], coat, 6)
		k.blob(hand, Vector3(0.04, 0.05, 0.04), skin, 3, 6)
	k.tube([Vector3(0, 1.45 + hy, 0), Vector3(0, 1.55 + hy, 0)], [0.07, 0.07], skin, 6)
	k.blob(Vector3(0, 1.67 + hy, 0), Vector3(0.11, 0.13, 0.12), skin, 4, 8)
	k.blob(Vector3(0, 1.74 + hy, 0.02), Vector3(0.12, 0.08, 0.12), hair, 3, 8)
	if o.get("bun", false):
		k.blob(Vector3(0, 1.76 + hy, 0.12), Vector3(0.06, 0.06, 0.06), hair, 3, 6)
	match o.get("hat", &""):
		&"ushanka":
			k.blob(Vector3(0, 1.8 + hy, 0), Vector3(0.15, 0.1, 0.15), Color(0.28, 0.22, 0.17), 4, 8)
			for sx: float in [-0.13, 0.13]:
				k.box(Vector3(sx, 1.68 + hy, 0), Vector3(0.04, 0.12, 0.1), Color(0.28, 0.22, 0.17))
		&"cap":
			k.tube([Vector3(0, 1.78 + hy, 0), Vector3(0, 1.84 + hy, 0)], [0.13, 0.14], Color(0.22, 0.28, 0.2), 10)
			k.box(Vector3(0, 1.79 + hy, -0.14), Vector3(0.16, 0.02, 0.08), Color(0.1, 0.1, 0.1))
			k.box(Vector3(0, 1.82 + hy, -0.135), Vector3(0.04, 0.04, 0.01), Color(0.8, 0.15, 0.1))
		&"pirozhok":
			k.box(Vector3(0, 1.82 + hy, 0), Vector3(0.24, 0.1, 0.16), Color(0.18, 0.16, 0.15))
	if o.get("glasses", false):
		k.box(Vector3(0, 1.68 + hy, -0.115), Vector3(0.17, 0.035, 0.01), Color(0.08, 0.08, 0.08))
	if arm == &"folder":
		k.box(Vector3(-0.16, 1.1 + hy, -0.3), Vector3(0.24, 0.32, 0.03), Color(0.62, 0.52, 0.32), Basis(Vector3.RIGHT, -0.4))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	mi.material_override = m
	var root := Node3D.new()
	root.name = "Person"
	root.add_child(mi)
	return root


func _add_person(w: Node3D, o: Dictionary, pos: Vector3, yaw: float, talk_key: StringName = &"") -> Node3D:
	var p := figure(o)
	p.position = pos
	p.rotation.y = yaw
	w.add_child(p)
	if not o.get("ghost", false):
		Geo.collider(w, Vector3(0.5, 1.7, 0.5), pos + Vector3(0, 0.85, 0))
	if talk_key != &"":
		var name_key := StringName(String(talk_key) + ".name")
		var a := ep._spot(pos + Vector3(0, 1.3 if not o.get("sit", false) else 0.9, 0), Vector3(0.7, 1.0, 0.7), func() -> String: return Loc.t(&"ep.p.talk", [Loc.t(name_key)]), func() -> void:
			var n := 1
			while Loc.has_key(StringName("%s.%d" % [talk_key, n])):
				n += 1
			var idx: int = p.get_meta(&"talk_i", 0) % maxi(n - 1, 1)
			p.set_meta(&"talk_i", idx + 1)
			ep._say(StringName("%s.%d" % [talk_key, idx + 1]), 5.5))
		a.name = "Talk_" + String(talk_key).replace(".", "_")
	_bobbers.append({"node": p, "base": p.position, "amp": 0.006, "f": _rng.randf_range(0.18, 0.3), "ph": _rng.randf() * TAU, "breath": true})
	return p


func _walker(w: Node3D, o: Dictionary, pts: Array, spd := 1.1) -> void:
	o["ghost"] = true
	var p := figure(o)
	p.position = pts[0]
	w.add_child(p)
	_walkers.append({"node": p, "pts": pts, "i": 1, "spd": spd * _rng.randf_range(0.85, 1.15), "t": _rng.randf() * 10.0, "wait": 0.0})


func _smoke(w: Node3D, at: Vector3) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.amount = 14
	s.lifetime = 3.0
	s.direction = Vector3(0.1, 1, 0)
	s.spread = 12.0
	s.initial_velocity_min = 0.12
	s.initial_velocity_max = 0.25
	s.gravity = Vector3(0.03, 0.05, 0)
	s.scale_amount_min = 0.6
	s.scale_amount_max = 2.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_color = Color(0.75, 0.75, 0.78, 0.25)
	qm.material = sm
	s.mesh = qm
	s.position = at
	w.add_child(s)
	var ember := Geo.block(w, Vector3(0.012, 0.012, 0.012), at, EpBuild.glow_mat(Color(1.0, 0.4, 0.1), 3.0), false)
	ember.name = "Ember"
	return s


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for wk: Dictionary in _walkers:
		var n: Node3D = wk["node"]
		if not is_instance_valid(n):
			continue
		if float(wk["wait"]) > 0.0:
			wk["wait"] = float(wk["wait"]) - delta
			continue
		var pts: Array = wk["pts"]
		var target: Vector3 = pts[wk["i"]]
		var to := target - n.position
		to.y = 0.0
		var step := float(wk["spd"]) * delta
		if to.length() <= step:
			n.position = Vector3(target.x, n.position.y, target.z)
			wk["i"] = (int(wk["i"]) + 1) % pts.size()
			wk["wait"] = _rng.randf_range(0.5, 3.0) if _rng.randf() < 0.4 else 0.0
		else:
			n.position += to.normalized() * step
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), minf(delta * 6.0, 1.0))
		wk["t"] = float(wk["t"]) + delta
		n.position.y = target.y + absf(sin(float(wk["t"]) * float(wk["spd"]) * 5.5)) * 0.025
	for b: Dictionary in _bobbers:
		var n: Node3D = b["node"]
		if is_instance_valid(n):
			n.position = (b["base"] as Vector3) + Vector3(0, sin(t * TAU * float(b["f"]) + float(b["ph"])) * float(b["amp"]), 0)
	for s in _spinners:
		if is_instance_valid(s):
			s.rotate_object_local(Vector3.FORWARD, delta * 2.2)
	if _typist != null and is_instance_valid(_typist):
		_type_t -= delta
		if _type_t <= 0.0:
			_type_t = _rng.randf_range(0.09, 0.22) if _rng.randf() > 0.06 else 1.4
			if ep._cam != null and ep._cam.global_position.distance_to(_typist.global_position) < 9.0:
				ep._sfx(TYPE_SND, -26.0, _rng.randf_range(2.2, 2.8))


# --- Улица -----------------------------------------------------------------------------

func _street(w: Node3D) -> void:
	var coats := [Color(0.18, 0.16, 0.15), Color(0.3, 0.22, 0.16), Color(0.22, 0.24, 0.3), Color(0.35, 0.32, 0.28), Color(0.4, 0.18, 0.15)]
	for i in 10:
		var sx := 1.0 if i % 2 == 0 else -1.0
		var x := sx * (EpBuild.ROAD_HALF + 2.5 + _rng.randf_range(0.0, 2.5))
		var z0 := -10.0 - i * 24.0
		var hat: StringName = [&"ushanka", &"pirozhok", &"", &"ushanka"][i % 4]
		_walker(w, {"coat": coats[i % coats.size()], "long": true, "hat": hat, "skirt": i % 3 == 2, "seed": i}, [Vector3(x, 0.19, z0), Vector3(x, 0.19, z0 - 40.0)], 1.0)
	# Очередь на остановке
	for i in 3:
		_add_person(w, {"coat": coats[(i + 2) % coats.size()], "long": true, "hat": &"ushanka", "seed": 30 + i}, Vector3(-(EpBuild.ROAD_HALF + 2.0), 0.19, -116.0 - i * 1.1), PI * 0.5)
	# Киоск «Союзпечать»
	var kz := -60.0
	var kx := EpBuild.ROAD_HALF + 4.5
	Geo.block(w, Vector3(2.0, 2.2, 1.6), Vector3(kx, 1.1, kz), EpBuild.mat(Color(0.3, 0.45, 0.55)), true)
	Geo.block(w, Vector3(0.05, 0.9, 1.3), Vector3(kx - 1.01, 1.3, kz), EpBuild.glow_mat(Color(0.95, 0.85, 0.6), 0.8), false)
	Geo.block(w, Vector3(2.2, 0.12, 1.8), Vector3(kx, 2.26, kz), Palette.m(&"snow"), false)
	EpBuild.label3d(w, "СОЮЗПЕЧАТЬ", Vector3(kx - 1.03, 2.0, kz), -PI * 0.5, 0.004, Color(0.95, 0.9, 0.8))
	# Троллейбус: едет по проспекту навстречу, салон светится
	var tb := _trolleybus()
	tb.position = Vector3(-3.0, 0, -260.0)
	w.add_child(tb)
	_walkers.append({"node": tb, "pts": [Vector3(-3.0, 0, -260.0), Vector3(-3.0, 0, 14.0)], "i": 1, "spd": 7.0, "t": 0.0, "wait": 0.0})


func _trolleybus() -> Node3D:
	var root := Node3D.new()
	var body := Color(0.75, 0.7, 0.45)
	Geo.block(root, Vector3(2.5, 2.6, 11.0), Vector3(0, 1.6, 0), EpBuild.mat(body), false)
	Geo.block(root, Vector3(2.52, 0.9, 10.0), Vector3(0, 2.1, 0.2), EpBuild.glow_mat(Color(0.95, 0.85, 0.55), 0.9), false)
	Geo.block(root, Vector3(2.55, 0.15, 11.0), Vector3(0, 1.0, 0), EpBuild.mat(Color(0.6, 0.15, 0.1)), false)
	Geo.block(root, Vector3(2.4, 0.1, 10.8), Vector3(0, 2.95, 0), Palette.m(&"snow"), false)
	for sx: float in [-0.4, 0.4]:
		var bar := Geo.block(root, Vector3(0.05, 0.05, 5.0), Vector3(sx, 4.6, 2.0), EpBuild.mat(Color(0.1, 0.1, 0.1)), false)
		bar.rotation.x = deg_to_rad(-18.0)
	for sx: float in [-0.8, 0.8]:
		var hl := Geo.omni(root, Vector3(sx, 0.8, -5.6), 10.0, 1.4, Color(1.0, 0.9, 0.7))
		hl.shadow_enabled = false
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-3.5, 3.5]:
			var whl := Geo.cylinder(root, 0.5, 0.35, Vector3(sx * 1.1, 0.5, sz), EpBuild.mat(Color(0.06, 0.06, 0.06)), false)
			whl.rotation.z = PI * 0.5
	EpBuild.label3d(root, "7", Vector3(0, 2.75, -5.52), PI, 0.006, Color(0.1, 0.1, 0.1))
	return root


# --- Холл -------------------------------------------------------------------------------

func _lobby(w: Node3D) -> void:
	var c := EpBuild.LOBBY
	# Гардероб: стойка, крючки с пальто и шапками, гардеробщица
	Geo.block(w, Vector3(0.6, 1.05, 4.0), c + Vector3(6.0, 0.52, 1.5), Palette.m(&"wood"), true)
	Geo.block(w, Vector3(0.1, 1.9, 4.2), c + Vector3(7.7, 1.6, 1.5), EpBuild.mat(Color(0.3, 0.22, 0.14)), false)
	var coats := [Color(0.15, 0.14, 0.13), Color(0.28, 0.22, 0.16), Color(0.2, 0.22, 0.28), Color(0.12, 0.12, 0.12)]
	for i in 9:
		var hz := c.z - 0.3 + i * 0.42
		var coat := EpBuild.coat()
		coat.position = Vector3(c.x + 7.35, c.y - 0.15, hz)
		coat.scale = Vector3(0.9, 0.95, 0.9)
		w.add_child(coat)
		(coat as MeshInstance3D).material_override = EpBuild.mat(coats[i % coats.size()])
		if i % 2 == 0:
			var hat := EpBuild.hat()
			hat.position = Vector3(c.x + 7.35, c.y - 0.1, hz)
			w.add_child(hat)
	_add_person(w, {"coat": Color(0.4, 0.38, 0.5), "skirt": true, "hair": Color(0.6, 0.58, 0.55), "bun": true, "glasses": true, "seed": 3}, c + Vector3(6.7, 0, 1.5), -PI * 0.5, &"ep.npc.cloak")
	# Второй постовой у лифта и посетитель на стуле
	_add_person(w, {"coat": Color(0.22, 0.28, 0.2), "hat": &"cap", "seed": 4}, c + Vector3(1.8, 0, -5.0), 0.0, &"ep.npc.post")
	var chair := Props.chair()
	chair.position = c + Vector3(-6.5, 0, 3.0)
	chair.rotation.y = -PI * 0.5
	w.add_child(chair)
	_add_person(w, {"coat": Color(0.3, 0.24, 0.18), "long": true, "sit": true, "hat": &"ushanka", "seed": 5}, c + Vector3(-6.5, 0.05, 3.0), -PI * 0.5, &"ep.npc.visitor")
	# Стойка с газетами
	Geo.block(w, Vector3(0.9, 1.2, 0.3), c + Vector3(-7.6, 0.6, -2.5), Palette.m(&"wood"), true)
	for i in 3:
		var np := Geo.block(w, Vector3(0.25, 0.35, 0.01), c + Vector3(-7.44, 0.75 + i * 0.12, -2.8 + i * 0.3), EpBuild.mat(Color(0.82, 0.8, 0.72)), false)
		np.rotation.y = PI * 0.5
	EpBuild.label3d(w, "ПРАВДА", c + Vector3(-7.43, 1.02, -2.2), PI * 0.5, 0.0022, Color(0.2, 0.15, 0.15))
	# Часы и доска объявлений
	var clk := Props.wall_clock()
	clk.position = c + Vector3(-3.0, 3.2, -5.8)
	w.add_child(clk)


# --- Коридор 4-го этажа ------------------------------------------------------------------

func _corridor(w: Node3D) -> void:
	var c := EpBuild.FLOOR4
	var zn := c.z + EpBuild.CORR_HALF
	var zs := c.z - EpBuild.CORR_HALF
	# Ходят по коридору: с папками, в кителях
	_walker(w, {"coat": Color(0.24, 0.26, 0.3), "arm": &"folder", "glasses": true, "seed": 11}, [c + Vector3(-13.5, 0, 0.4), c + Vector3(13.0, 0, 0.4)], 1.0)
	_walker(w, {"coat": Color(0.22, 0.28, 0.2), "seed": 12}, [c + Vector3(10.0, 0, -0.5), c + Vector3(-12.0, 0, -0.5)], 0.9)
	_walker(w, {"coat": Color(0.45, 0.3, 0.32), "skirt": true, "bun": true, "arm": &"folder", "hair": Color(0.35, 0.22, 0.12), "seed": 13}, [c + Vector3(-1.0, 0, 0.2), c + Vector3(8.0, 0, 0.2), c + Vector3(2.0, 0, -0.3)], 1.1)
	# Курилка у окна в западном торце: двое, дым
	_add_person(w, {"coat": Color(0.25, 0.25, 0.27), "arm": &"smoke", "seed": 14}, c + Vector3(-15.0, 0, 0.7), -PI * 0.6, &"ep.npc.smoker1")
	_add_person(w, {"coat": Color(0.3, 0.27, 0.22), "arm": &"smoke", "glasses": true, "seed": 15}, c + Vector3(-15.1, 0, -0.75), -PI * 0.35, &"ep.npc.smoker2")
	_smoke(w, c + Vector3(-15.12, 1.56, 0.5))
	_smoke(w, c + Vector3(-15.15, 1.56, -0.95))
	var urn := Geo.cylinder(w, 0.15, 0.7, c + Vector3(-15.5, 0.35, 0.0), EpBuild.mat(Color(0.3, 0.3, 0.32), 0.4), true)
	urn.name = "Urn"
	# Скамья у кабинета начальника: ждут вызова
	var r420: Array = EpBuild.ROOMS[&"420"]
	var bx := float(r420[0]) - 1.6
	Geo.block(w, Vector3(1.6, 0.06, 0.4), Vector3(bx, 0.45, zn - 0.25), Palette.m(&"wood"), true)
	for sx: float in [-0.7, 0.7]:
		Geo.block(w, Vector3(0.06, 0.45, 0.35), Vector3(bx + sx, 0.22, zn - 0.25), EpBuild.mat(Color(0.2, 0.2, 0.2)), false)
	_add_person(w, {"coat": Color(0.2, 0.2, 0.22), "sit": true, "arm": &"folder", "seed": 16}, Vector3(bx - 0.4, 0.05, zn - 0.3), PI, &"ep.npc.waiting")
	# Стены: доска почёта, плакат, пожарный шкаф, часы, фикусы, батареи
	var board := Geo.block(w, Vector3(2.4, 1.2, 0.04), Vector3(-5.0, 1.75, zs + 0.13), EpBuild.mat(Color(0.55, 0.12, 0.1)), false)
	board.name = "HonorBoard"
	EpBuild.label3d(w, "ДОСКА ПОЧЁТА", Vector3(-5.0, 2.2, zs + 0.16), 0.0, 0.004, Color(0.95, 0.8, 0.4))
	for k in 8:
		Geo.block(w, Vector3(0.22, 0.28, 0.01), Vector3(-5.8 + (k % 4) * 0.53, 1.75 - (k / 4) * 0.4, zs + 0.16), EpBuild.mat(Color(0.75, 0.72, 0.65)), false)
	var poster := Geo.block(w, Vector3(0.7, 1.0, 0.02), Vector3(-6.0, 1.7, zn - 0.12), EpBuild.mat(Color(0.82, 0.75, 0.55)), false)
	poster.name = "Poster"
	EpBuild.label3d(w, "НЕ БОЛТАЙ!\n\nболтун —\nнаходка\nдля шпиона", Vector3(-6.0, 1.7, zn - 0.14), PI, 0.0028, Color(0.55, 0.08, 0.06))
	Geo.block(w, Vector3(0.6, 0.8, 0.18), Vector3(14.0, 1.2, zn - 0.2), EpBuild.mat(Color(0.65, 0.1, 0.07)), true)
	EpBuild.label3d(w, "ПК", Vector3(14.0, 1.35, zn - 0.3), PI, 0.005, Color(0.95, 0.95, 0.9))
	var clk := Props.wall_clock()
	clk.position = Vector3(-7.8, 2.6, zs + 0.15)
	w.add_child(clk)
	for p: Vector3 in [Vector3(-8.0, 0, zs + 0.35), Vector3(9.0, 0, zs + 0.35), Vector3(-15.4, 0, zn - 0.35)]:
		_ficus(w, p)
	for rx: float in [-14.0, -7.8, -2.2, 5.5, 9.5, 13.5]:   # между дверями 414 (−11) и 418 (2)
		_radiator(w, Vector3(rx, 0.45, zs + 0.15), 0.0)
	_add_person(w, {"coat": Color(0.22, 0.28, 0.2), "hat": &"cap", "seed": 17}, c + Vector3(15.3, 0, -1.0), PI * 0.5)


func _ficus(w: Node3D, at: Vector3) -> void:
	var k := MeshKit.new(int(at.x * 10.0) + 600)
	k.mottle = 0.12
	k.tube([Vector3(0, 0, 0), Vector3(0, 0.38, 0)], [0.16, 0.2], Color(0.5, 0.28, 0.18), 8)
	k.tube([Vector3(0, 0.38, 0), Vector3(0, 1.2, 0)], [0.02, 0.015], Color(0.3, 0.22, 0.12), 4)
	for i in 14:
		var a := i * 2.4
		var h := 0.6 + (i % 5) * 0.13
		var p := Vector3(cos(a) * 0.18, h, sin(a) * 0.18)
		k.blob(p, Vector3(0.09, 0.025, 0.05), Color(0.12, 0.3, 0.12), 2, 6, Basis(Vector3.UP, a))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.position = at
	w.add_child(mi)


func _radiator(w: Node3D, at: Vector3, yaw: float) -> void:
	for i in 9:
		var fin := Geo.block(w, Vector3(0.07, 0.55, 0.1), at + Vector3(-0.5 + i * 0.125, 0, 0).rotated(Vector3.UP, yaw), EpBuild.mat(Color(0.62, 0.6, 0.55)), false)
		fin.rotation.y = yaw


# --- Кабинеты --------------------------------------------------------------------------------

func _rooms(w: Node3D) -> void:
	var f4: Dictionary = ep._f4
	# 412 — свой: портрет, флаг, книжный шкаф, графин, пепельница с дымком, карта области, шторы
	var r: Dictionary = f4[&"412"]
	var side: float = r["side"]
	var zout: float = r["zout"]
	var cx := (float(r["x0"]) + float(r["x1"])) * 0.5
	_portrait(w, Vector3(cx + 1.6, 2.1, zout - side * 0.15), side)
	_flag(w, Vector3(float(r["x1"]) - 0.4, 0, zout - side * 0.5))
	var bs := Props.shelf()
	bs.position = Vector3(float(r["x0"]) + 0.35, 0, (r["center"] as Vector3).z + side * 0.4)
	bs.rotation.y = PI * 0.5
	w.add_child(bs)
	var desk_c: Vector3 = (r["center"] as Vector3) + Vector3(0, 0, side * 1.0)
	_carafe(w, desk_c + Vector3(0.35, 0.76, side * -0.2))
	var ash := Geo.cylinder(w, 0.06, 0.025, desk_c + Vector3(-0.25, 0.78, side * -0.2), EpBuild.mat(Color(0.35, 0.5, 0.55), 0.2), false)
	ash.name = "Ashtray"
	_smoke(w, desk_c + Vector3(-0.22, 0.81, side * -0.2))
	var map := Geo.block(w, Vector3(0.04, 1.0, 1.4), Vector3(float(r["x1"]) - 0.13, 1.7, (r["center"] as Vector3).z - side * 0.6), EpBuild.mat(Color(0.75, 0.78, 0.68)), false)
	map.name = "RegionMap"
	EpBuild.label3d(w, "СВЕРДЛОВСКАЯ ОБЛ.\n· Ивдель\n· Ушма\n× «Кедр-7»", Vector3(float(r["x1"]) - 0.16, 1.75, (r["center"] as Vector3).z - side * 0.6), -PI * 0.5, 0.0024, Color(0.2, 0.18, 0.15))
	_curtains(w, cx, zout, side)
	# 414 — приёмная: Зоя печатает (после того как принесла дело), машинка, шкаф, чайник
	var r2: Dictionary = f4[&"414"]
	var d2: Vector3 = (r2["center"] as Vector3) + Vector3(0, 0, -0.6)
	_typewriter(w, d2 + Vector3(0, 0.76, 0))
	_typist = _add_person(w, {"coat": Color(0.32, 0.22, 0.28), "skin": Color(0.82, 0.66, 0.56), "hair": Color(0.45, 0.3, 0.18), "skirt": true, "bun": true, "sit": true, "arm": &"type", "seed": 21}, d2 + Vector3(0, 0.05, -0.75), 0.0, &"ep.npc.zoya")
	_typist.visible = false
	var fc := Props.storage_shelves()
	fc.position = Vector3(float(r2["x0"]) + 0.5, 0, (r2["center"] as Vector3).z)
	fc.rotation.y = PI * 0.5
	w.add_child(fc)
	_ficus(w, Vector3(float(r2["x1"]) - 0.5, 0, float(r2["zout"]) + 0.5))
	_curtains(w, (float(r2["x0"]) + float(r2["x1"])) * 0.5, float(r2["zout"]), float(r2["side"]))
	# 415 — отдел «Т»: лаборант с лупой, сохнущие плёнки, магнитофон с бобинами
	var r3: Dictionary = f4[&"415"]
	var c3: Vector3 = r3["center"]
	_add_person(w, {"coat": Color(0.85, 0.85, 0.82), "glasses": true, "arm": &"folder", "hair": Color(0.5, 0.5, 0.5), "seed": 22}, c3 + Vector3(0.8, 0, 0.4), PI * 0.8, &"ep.npc.lab")
	for k in 6:
		Geo.block(w, Vector3(0.035, 0.6, 0.002), Vector3(c3.x - 1.4 + k * 0.18, 2.5, float(r3["zout"]) - 1.2), EpBuild.mat(Color(0.12, 0.08, 0.06)), false)
	Geo.block(w, Vector3(1.5, 0.01, 0.01), Vector3(c3.x - 0.95, 2.82, float(r3["zout"]) - 1.2), EpBuild.mat(Color(0.7, 0.7, 0.68)), false)
	_tape_recorder(w, c3 + Vector3(-1.2, 0.76, 0.2))
	# 418 — архив: архивариус за стойкой, картотека, стремянка
	var r4: Dictionary = f4[&"418"]
	var c4: Vector3 = r4["center"]
	# Стойка выдачи — сбоку от двери, вдоль западной стены (проход свободен)
	Geo.block(w, Vector3(0.5, 1.0, 2.2), Vector3(float(r4["x0"]) + 1.3, 0.5, c4.z + 0.4), Palette.m(&"wood"), true)
	_add_person(w, {"coat": Color(0.3, 0.3, 0.36), "skirt": true, "hair": Color(0.7, 0.7, 0.68), "bun": true, "glasses": true, "seed": 23}, Vector3(float(r4["x0"]) + 0.6, 0, c4.z + 0.4), PI * 0.5, &"ep.npc.archivist")
	for k in 2:
		var cat := Geo.block(w, Vector3(0.9, 1.3, 0.45), Vector3(float(r4["x1"]) - 0.5, 0.65, c4.z + 0.6 - k * 1.1), EpBuild.mat(Color(0.4, 0.3, 0.2)), true)
		cat.name = "Catalog"
		for d in 12:
			Geo.block(w, Vector3(0.02, 0.08, 0.12), Vector3(float(r4["x1"]) - 0.96, 0.2 + (d / 3) * 0.3, c4.z + 0.45 - k * 1.1 + (d % 3) * 0.14), EpBuild.mat(Color(0.75, 0.65, 0.4)), false)
	var lad := Props.ladder(2.4)
	lad.position = Vector3(float(r4["x0"]) + 3.0, 0, float(r4["zout"]) + 1.0)
	lad.rotation.x = deg_to_rad(-12.0)
	w.add_child(lad)
	# 420 — начальник: полковник у окна, курит; портрет, флаг, длинный стол заседаний
	var r5: Dictionary = f4[&"420"]
	var c5: Vector3 = r5["center"]
	_add_person(w, {"coat": Color(0.22, 0.28, 0.2), "arm": &"smoke", "hair": Color(0.55, 0.55, 0.55), "seed": 24}, Vector3(c5.x + 1.6, 0, float(r5["zout"]) - 0.8), 0.0 if float(r5["side"]) < 0 else PI, &"ep.npc.vetrov")
	_smoke(w, Vector3(c5.x + 1.7, 1.56, float(r5["zout"]) - 1.0))
	_portrait(w, Vector3(c5.x - 1.6, 2.1, float(r5["zout"]) - float(r5["side"]) * 0.15), float(r5["side"]))
	_flag(w, Vector3(float(r5["x0"]) + 0.5, 0, float(r5["zout"]) - float(r5["side"]) * 0.5))
	Geo.block(w, Vector3(0.9, 0.06, 2.4), Vector3(c5.x, 0.74, c5.z - float(r5["side"]) * 0.5), Palette.m(&"wood"), true)
	for k in 4:
		var ch := Props.chair()
		ch.position = Vector3(c5.x + (0.75 if k % 2 == 0 else -0.75), 0, c5.z - float(r5["side"]) * (0.0 + (k / 2) * 1.0))
		ch.rotation.y = PI * 0.5 if k % 2 == 0 else -PI * 0.5
		w.add_child(ch)
	_curtains(w, c5.x, float(r5["zout"]), float(r5["side"]))


func _portrait(w: Node3D, at: Vector3, side: float) -> void:
	var yaw := PI if side > 0 else 0.0
	var fr := Geo.block(w, Vector3(0.6, 0.78, 0.04), at, EpBuild.mat(Color(0.55, 0.42, 0.18), 0.4), false)
	fr.rotation.y = yaw
	var cv := Geo.block(w, Vector3(0.5, 0.68, 0.01), at - Vector3(0, 0, side * 0.025), EpBuild.mat(Color(0.25, 0.22, 0.2)), false)
	cv.rotation.y = yaw
	# Силуэт в мундире — без лица, тёмный холст
	var bust := Geo.block(w, Vector3(0.32, 0.22, 0.005), at + Vector3(0, -0.2, -side * 0.032), EpBuild.mat(Color(0.15, 0.15, 0.17)), false)
	bust.rotation.y = yaw
	var head := Geo.block(w, Vector3(0.13, 0.17, 0.005), at + Vector3(0, 0.03, -side * 0.032), EpBuild.mat(Color(0.5, 0.42, 0.36)), false)
	head.rotation.y = yaw


func _flag(w: Node3D, at: Vector3) -> void:
	Geo.cylinder(w, 0.02, 2.2, at + Vector3(0, 1.1, 0), EpBuild.mat(Color(0.75, 0.6, 0.25), 0.3), false)
	Geo.cylinder(w, 0.18, 0.05, at + Vector3(0, 0.02, 0), EpBuild.mat(Color(0.2, 0.15, 0.1)), false)
	var cloth := Geo.block(w, Vector3(0.02, 0.9, 0.55), at + Vector3(0, 1.75, 0.28), EpBuild.mat(Color(0.62, 0.06, 0.05)), false)
	cloth.rotation.x = 0.25
	Geo.block(w, Vector3(0.05, 0.05, 0.05), at + Vector3(0, 2.23, 0), EpBuild.mat(Color(0.85, 0.7, 0.3), 0.3), false)


func _carafe(w: Node3D, at: Vector3) -> void:
	var gl := StandardMaterial3D.new()
	gl.albedo_color = Color(0.7, 0.8, 0.85, 0.45)
	gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.roughness = 0.1
	Geo.cylinder(w, 0.06, 0.22, at + Vector3(0, 0.11, 0), gl, false)
	Geo.cylinder(w, 0.02, 0.08, at + Vector3(0, 0.26, 0), gl, false)
	Geo.cylinder(w, 0.03, 0.09, at + Vector3(0.12, 0.045, 0.02), gl, false)
	Geo.block(w, Vector3(0.24, 0.01, 0.18), at + Vector3(0.05, 0.003, 0), EpBuild.mat(Color(0.7, 0.68, 0.6)), false)


func _curtains(w: Node3D, cx: float, zout: float, side: float) -> void:
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			Geo.block(w, Vector3(0.12, 1.9, 0.03), Vector3(cx + sx * (0.95 + k * 0.1), 1.75, zout - side * (0.22 + (k % 2) * 0.03)), EpBuild.mat(Color(0.55, 0.42, 0.28)), false)
	Geo.block(w, Vector3(2.4, 0.04, 0.04), Vector3(cx, 2.72, zout - side * 0.22), EpBuild.mat(Color(0.6, 0.55, 0.4)), false)


func _typewriter(w: Node3D, at: Vector3) -> void:
	var k := MeshKit.new(77)
	var body := Color(0.2, 0.22, 0.2)
	k.box(Vector3(0, 0.05, 0), Vector3(0.42, 0.1, 0.32), body)
	k.box(Vector3(0, 0.12, 0.1), Vector3(0.46, 0.06, 0.08), body)
	k.tube([Vector3(-0.24, 0.15, 0.1), Vector3(0.24, 0.15, 0.1)], [0.03], Color(0.08, 0.08, 0.08), 8)
	k.box(Vector3(0, 0.25, 0.12), Vector3(0.3, 0.2, 0.004), Color(0.92, 0.9, 0.85), Basis(Vector3.RIGHT, -0.25))
	for r in 4:
		for c in 10:
			k.box(Vector3(-0.17 + c * 0.038, 0.105 + r * 0.008, -0.12 + r * 0.035), Vector3(0.02, 0.01, 0.02), Color(0.85, 0.85, 0.8))
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.position = at
	mi.rotation.y = PI
	w.add_child(mi)


func _tape_recorder(w: Node3D, at: Vector3) -> void:
	Geo.block(w, Vector3(0.5, 0.14, 0.4), at + Vector3(0, 0.07, 0), EpBuild.mat(Color(0.35, 0.32, 0.3)), false)
	for sx: float in [-0.12, 0.12]:
		var reel := Node3D.new()
		reel.position = at + Vector3(sx, 0.16, -0.02)
		reel.rotation.x = -PI * 0.5
		w.add_child(reel)
		var disc := Geo.cylinder(reel, 0.09, 0.012, Vector3.ZERO, EpBuild.mat(Color(0.6, 0.6, 0.62), 0.3), false)
		disc.rotation.x = PI * 0.5
		for i in 3:
			var spoke := Geo.block(reel, Vector3(0.015, 0.16, 0.014), Vector3.ZERO, EpBuild.mat(Color(0.2, 0.2, 0.2)), false)
			spoke.rotation.z = i * PI / 3.0
		_spinners.append(reel)
	var a := AudioStreamPlayer3D.new()
	a.stream = AudioDirector.cached_stream("res://assets/audio/whisper.ogg")
	a.volume_db = -14.0
	a.unit_size = 1.5
	a.max_distance = 6.0
	a.position = at
	w.add_child(a)
	a.play()
	a.finished.connect(a.play)


## Зоя садится печатать, когда принесла дело.
func zoya_at_desk() -> void:
	if _typist != null:
		_typist.visible = true
