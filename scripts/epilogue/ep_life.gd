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
var _people: Array[CreatureRig] = []    ## скелетные люди: смотрят на подошедшего, отдают честь
var _look_t := 0.0
var _ring_room_t := 40.0
var _keys_t := 0.0
var _room_snd: Array[Vector3] = []   ## центры кабинетов — откуда звонят и стучат
var _keys: AudioStreamPlayer3D


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
	_wing(w)
	_atmos(w)
	_behind_walls(w)


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


## Стиль модели по описанию: платье — секретарь, фуражка — постовой, длинное пальто — прохожий, иначе — офицер.
## Какая модель (tools/blender/ep_people.py): по одежде, волосам и номеру — десять разных людей.
static func style_of(o: Dictionary) -> StringName:
	if o.has("ep"):
		return o["ep"]
	var sd: int = o.get("seed", 0)
	var st: StringName = o.get("style", &"")
	var hair: Color = o.get("hair", Color(0.2, 0.15, 0.1))
	var grey := hair.r > 0.45 and absf(hair.r - hair.b) < 0.12
	var coat: Color = o.get("coat", Color(0.2, 0.2, 0.2))
	if coat.v > 0.7:
		return &"ep_lab"
	if st == &"guard" or o.get("hat", &"") == &"cap":
		return &"ep_uniform" if grey else &"ep_guard"
	if o.get("skirt", false) or st == &"clerk":
		if o.get("long", false):
			return &"ep_civil2"
		return &"ep_clerk2" if grey or o.get("glasses", false) or sd % 3 == 0 else &"ep_clerk1"
	if st == &"civil" or o.get("long", false):
		return &"ep_civil1"
	if o.get("glasses", false):
		return &"ep_officer2"
	return ([&"ep_officer1", &"ep_officer3", &"ep_uniform", &"ep_officer2", &"ep_officer1"] as Array)[sd % 5]


## Скелетный человек (tools/blender/human_rig.py) с позой и оттенком; null — если модели нет.
func rig_person(o: Dictionary) -> CreatureRig:
	var sit: bool = o.get("sit", false)
	var rig := Creatures.make_human(style_of(o), sit)
	if rig == null or rig.anim == null:
		if rig != null:
			rig.free()
		return null
	rig.twitch = 0.0
	# Живые люди: плавно, с переходами между клипами, и стоят не столбом
	rig.stepped_mode = false
	rig.blend_time = 0.35
	rig.idle_alts = [&"idle_shift", &"look_around", &"idle_watch", &"idle_shift"]
	if o.get("glasses", false) or style_of(o) in [&"ep_officer2", &"ep_clerk2", &"ep_lab"]:
		rig.idle_alts.append(&"idle_glasses")
	rig.clip_walk = &"walk_folder" if o.get("arm", &"") == &"folder" else &"walk"
	match o.get("arm", &""):
		&"type":
			rig.pose_override = &"type"
		&"smoke":
			rig.pose_override = &"smoke"
	rig.set_meta(&"base_pose", rig.pose_override)
	rig.set_meta(&"ep_style", style_of(o))
	_people.append(rig)
	# Чуть разная яркость: одинаковые модели не должны выглядеть близнецами
	var sd: int = o.get("seed", 0)
	var tint := Color.WHITE * (0.9 + float((sd * 37) % 13) * 0.012)
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as ShaderMaterial
		if m != null:
			m.set_shader_parameter(&"albedo", tint)
	return rig


func _make(o: Dictionary) -> Node3D:
	var r := rig_person(o)
	if r != null:
		if o.get("sit", false):
			var holder := Node3D.new()
			holder.name = "Person"
			holder.add_child(r)
			r.position = Vector3(0, -0.47, 0.08)   # таз — на сиденье стула
			holder.set_meta(&"rig", r)
			return holder
		r.set_meta(&"rig", r)
		return r
	return figure(o)


func _add_person(w: Node3D, o: Dictionary, pos: Vector3, yaw: float, talk_key: StringName = &"") -> Node3D:
	var p := _make(o)
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
			if p.has_meta(&"rig"):
				(p.get_meta(&"rig") as CreatureRig).talk = 4.5   # отвечает — с жестами
			ep._say(StringName("%s.%d" % [talk_key, idx + 1]), 5.5))
		a.name = "Talk_" + String(talk_key).replace(".", "_")
	if not p.has_meta(&"rig"):
		_bobbers.append({"node": p, "base": p.position, "amp": 0.006, "f": _rng.randf_range(0.18, 0.3), "ph": _rng.randf() * TAU, "breath": true})
	return p


func _walker(w: Node3D, o: Dictionary, pts: Array, spd := 1.1) -> void:
	o["ghost"] = true
	var p := _make(o) if not o.get("vehicle", false) else figure(o)
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


## Люди замечают подошедшего: поворачивают голову, машинистка поднимает глаза от машинки,
## постовой при первой встрече отдаёт честь. Раз в 0.1 с — людей несколько десятков.
func _react(delta: float) -> void:
	_look_t -= delta
	if _look_t > 0.0 or ep._cam == null:
		return
	_look_t = 0.1
	var eye := ep._cam.global_position
	for r in _people:
		if not is_instance_valid(r) or not r.is_visible_in_tree():
			continue
		var head := r.global_position + Vector3(0, 1.6 if not r.seated else 1.15, 0)
		var d := eye.distance_to(head)
		var near := d < 4.5 and r.gait < 0.12
		if near:
			var loc := r.global_basis.inverse() * (eye - head)
			var yaw := atan2(-loc.x, -loc.z)
			near = absf(yaw) < 1.9
			r.head_look_target_yaw = clampf(yaw, -1.0, 1.0) if near else 0.0
			r.head_look_target_pitch = clampf(atan2(loc.y, Vector2(loc.x, loc.z).length()), -0.3, 0.35) if near else 0.0
		else:
			r.head_look_target_yaw = 0.0
			r.head_look_target_pitch = 0.0
		var base: StringName = r.get_meta(&"base_pose", &"")
		if base == &"type":
			r.pose_override = &"sit_look" if near and d < 2.4 else &"type"
		if r.get_meta(&"ep_style", &"") == &"ep_guard" and not r.seated and near and d < 3.2 and not r.has_meta(&"saluted"):
			r.set_meta(&"saluted", true)
			r.pose_override = &"salute"
			get_tree().create_timer(2.2, false).timeout.connect(func() -> void:
				if is_instance_valid(r):
					r.pose_override = base)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_react(delta)
	_tick_walls(delta)
	for wk: Dictionary in _walkers:
		var n: Node3D = wk["node"]
		if not is_instance_valid(n):
			continue
		var rig: CreatureRig = n.get_meta(&"rig") if n.has_meta(&"rig") else null
		if float(wk["wait"]) > 0.0:
			wk["wait"] = float(wk["wait"]) - delta
			if rig != null:
				rig.gait = 0.0
			continue
		if rig != null:
			rig.gait = 0.3
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
		if rig == null:
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
		var tint := Color(0.7, 0.7, 0.72).lerp(coats[i % coats.size()] * 2.5, 0.35)
		_walker(w, {"style": &"civil" if i % 3 != 2 else &"clerk", "tint": tint, "coat": coats[i % coats.size()], "long": true, "seed": i}, [Vector3(x, 0.19, z0), Vector3(x, 0.19, z0 - 40.0)], 1.0)
	# Очередь на остановке
	for i in 3:
		_add_person(w, {"style": &"civil", "tint": Color(0.85 + i * 0.08, 0.9, 0.95 - i * 0.05), "seed": 30 + i}, Vector3(-(EpBuild.ROAD_HALF + 2.0), 0.19, -116.0 - i * 1.1), PI * 0.5)
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
	tb.position.y = 0.0


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
	var lb: Dictionary = ep._lobby
	# Проходная: постовой в будке за стеклом, второй у турникета
	var bch := Props.chair()
	bch.position = c + Vector3(-1.9, 0, 6.1)
	bch.rotation.y = PI
	w.add_child(bch)
	_add_person(w, {"style": &"guard", "sit": true, "seed": 2}, c + Vector3(-1.9, 0.05, 6.1), PI, &"ep.npc.post")
	_add_person(w, {"style": &"guard", "seed": 4}, c + Vector3(1.7, 0, 6.3), PI + 0.3)
	# Дежурная часть за стеклом: стол с телефонами, дежурный, карта города, рация, сейф
	var duty: Vector3 = lb["duty"]
	Geo.block(w, Vector3(1.0, 0.06, 2.4), duty + Vector3(1.0, 0.76, 0), Palette.m(&"wood"), true)
	for k in 3:
		var ph := EpBuild.phone()
		ph.position = duty + Vector3(1.1, 0.79, -0.8 + k * 0.5)
		ph.rotation.y = PI * 0.5
		w.add_child(ph)
		(ph as MeshInstance3D).material_override = EpBuild.mat([Color(0.12, 0.12, 0.13), Color(0.75, 0.72, 0.65), Color(0.55, 0.1, 0.08)][k], 0.35)
	var dch := Props.chair()
	dch.position = duty + Vector3(0.2, 0, 0)
	dch.rotation.y = -PI * 0.5
	w.add_child(dch)
	_add_person(w, {"style": &"officer", "sit": true, "seed": 6, "tint": Color(0.65, 0.68, 0.62)}, duty + Vector3(0.2, 0.05, 0), -PI * 0.5, &"ep.npc.duty")
	var cmap := Geo.block(w, Vector3(0.03, 1.6, 2.4), duty + Vector3(-2.3, 1.9, 0), EpBuild.mat(Color(0.8, 0.8, 0.7)), false)
	cmap.name = "CityMap"
	EpBuild.label3d(w, "г. СВЕРДЛОВСК\nсхема районов", duty + Vector3(-2.27, 2.55, 0), PI * 0.5, 0.0035, Color(0.2, 0.15, 0.12))
	for k in 7:
		Geo.block(w, Vector3(0.01, 0.04, 0.04), duty + Vector3(-2.27, 1.4 + (k % 3) * 0.35, -0.9 + k * 0.28), EpBuild.mat(Color(0.8, 0.1, 0.08)), false)
	var rad := Props.radio()
	rad.position = duty + Vector3(-1.9, 0, 2.2)
	w.add_child(rad)
	var sf := Props.safe()
	sf.position = duty + Vector3(-1.9, 0, -2.4)
	w.add_child(sf)
	var buzz := AudioStreamPlayer3D.new()
	buzz.stream = AudioDirector.cached_stream("res://assets/audio/static_loop.ogg")
	buzz.volume_db = -22.0
	buzz.max_distance = 9.0
	buzz.position = duty + Vector3(-1.9, 1.0, 2.2)
	w.add_child(buzz)
	buzz.play()
	buzz.finished.connect(buzz.play)
	# Гардероб у восточной стены: стойка, вешалки, гардеробщица
	var ck: Vector3 = lb["cloak"]
	Geo.block(w, Vector3(0.6, 1.05, 4.0), ck + Vector3(0, 0.52, 0), EpBuild.surf(3, Color(0.42, 0.28, 0.17), Color(0.3, 0.2, 0.12)), true)
	Geo.block(w, Vector3(0.1, 1.9, 4.2), ck + Vector3(2.6, 1.6, 0), EpBuild.mat(Color(0.3, 0.22, 0.14)), false)
	var coats := [Color(0.15, 0.14, 0.13), Color(0.28, 0.22, 0.16), Color(0.2, 0.22, 0.28), Color(0.12, 0.12, 0.12)]
	for i in 9:
		var coat := EpBuild.coat()
		coat.position = ck + Vector3(2.3, -0.15, -1.8 + i * 0.42)
		coat.scale = Vector3(0.9, 0.95, 0.9)
		w.add_child(coat)
		(coat as MeshInstance3D).material_override = EpBuild.mat(coats[i % coats.size()])
		if i % 2 == 0:
			var hat := EpBuild.hat()
			hat.position = ck + Vector3(2.3, -0.1, -1.8 + i * 0.42)
			w.add_child(hat)
	_add_person(w, {"style": &"clerk", "tint": Color(0.7, 0.72, 0.85), "seed": 3}, ck + Vector3(1.0, 0, 0.0), -PI * 0.5, &"ep.npc.cloak")
	EpBuild.label3d(w, "ГАРДЕРОБ", ck + Vector3(2.55, 2.8, 0), -PI * 0.5, 0.004, Color(0.9, 0.8, 0.5))
	# Приёмная граждан: скамьи, ждущие — отец пропавшего охотника и женщина в платке
	var rc: Vector3 = lb["reception"]
	for k in 2:
		Geo.block(w, Vector3(2.4, 0.06, 0.45), rc + Vector3(0, 0.45, 1.4 - k * 2.0), Palette.m(&"wood"), true)
		Geo.block(w, Vector3(2.4, 0.5, 0.05), rc + Vector3(0, 0.72, 1.6 - k * 2.0), Palette.m(&"wood"), false)
	_add_person(w, {"style": &"civil", "sit": true, "seed": 5, "tint": Color(0.8, 0.72, 0.65)}, rc + Vector3(-0.5, 0.05, 1.4), PI, &"ep.npc.visitor")
	_add_person(w, {"style": &"clerk", "sit": true, "seed": 7, "tint": Color(0.55, 0.5, 0.45)}, rc + Vector3(0.6, 0.05, -0.6), PI, &"ep.npc.woman")
	var pst := Geo.block(w, Vector3(0.8, 1.1, 0.02), rc + Vector3(-3.7, 1.6, 0), EpBuild.mat(Color(0.85, 0.78, 0.6)), false)
	pst.rotation.y = PI * 0.5
	EpBuild.label3d(w, "ГРАЖДАНЕ!\nБудьте бдительны.\nО подозрительном\nсообщайте\nдежурному.", rc + Vector3(-3.68, 1.6, 0), PI * 0.5, 0.0026, Color(0.55, 0.08, 0.06))
	# Лифтовой холл: двое ждут лифт
	_add_person(w, {"style": &"officer", "arm": &"folder", "seed": 8}, c + Vector3(7.0, 0, -11.2), PI * 0.05, &"ep.npc.liftman")
	_add_person(w, {"style": &"clerk", "seed": 9, "tint": Color(0.75, 0.68, 0.62)}, c + Vector3(9.3, 0, -11.4), -PI * 0.1)
	# Движение: уборщица со шваброй по залу, конвой с задержанным от лифтов к дежурке, офицеры
	_walker(w, {"style": &"clerk", "tint": Color(0.45, 0.5, 0.62), "seed": 10}, [c + Vector3(-5.0, 0, 3.0), c + Vector3(3.0, 0, 3.0), c + Vector3(3.0, 0, 1.6), c + Vector3(-5.0, 0, 1.6)], 0.35)
	_walker(w, {"style": &"guard", "seed": 11}, [c + Vector3(6.0, 0, -9.0), c + Vector3(3.0, 0, -3.0), c + Vector3(-5.8, 0, -1.0), c + Vector3(3.0, 0, -3.0)], 0.9)
	_walker(w, {"style": &"civil", "seed": 12, "tint": Color(0.6, 0.6, 0.62)}, [c + Vector3(6.8, 0, -9.4), c + Vector3(3.8, 0, -3.4), c + Vector3(-5.2, 0, -1.4), c + Vector3(3.8, 0, -3.4)], 0.9)
	_walker(w, {"style": &"officer", "arm": &"folder", "seed": 13}, [c + Vector3(2.0, 0, 4.4), c + Vector3(7.0, 0, -10.0)], 1.1)
	# Газеты, часы, кадка с пальмой у колонн
	Geo.block(w, Vector3(0.9, 1.2, 0.3), c + Vector3(-11.6, 0.6, 5.0), Palette.m(&"wood"), true)
	EpBuild.label3d(w, "ПРАВДА  ·  ИЗВЕСТИЯ  ·  УРАЛЬСКИЙ РАБОЧИЙ", c + Vector3(-11.43, 1.25, 5.0), PI * 0.5, 0.0022, Color(0.2, 0.15, 0.15))
	var clk := Props.wall_clock()
	clk.position = c + Vector3(0, 3.0, 7.82)
	clk.rotation.y = PI
	w.add_child(clk)
	for p: Vector3 in [Vector3(-5.2, 0, 4.5), Vector3(5.2, 0, 4.5)]:
		_ficus(w, c + p)
	# Гул: шаги и стук машинок вдалеке
	var amb := AudioStreamPlayer3D.new()
	amb.stream = AudioDirector.cached_stream("res://assets/audio/hum_loop.ogg")
	amb.volume_db = -26.0
	amb.max_distance = 30.0
	amb.position = c + Vector3(0, 3, 0)
	w.add_child(amb)
	amb.play()
	amb.finished.connect(amb.play)


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
	_add_person(w, {"tint": Color(1.2, 1.2, 1.16), "coat": Color(0.85, 0.85, 0.82), "glasses": true, "arm": &"folder", "hair": Color(0.5, 0.5, 0.5), "seed": 22}, c3 + Vector3(0.8, 0, 0.4), PI * 0.8, &"ep.npc.lab")
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
	_add_person(w, {"style": &"guard", "tint": Color(0.75, 0.78, 0.72), "coat": Color(0.22, 0.28, 0.2), "arm": &"smoke", "hair": Color(0.55, 0.55, 0.55), "seed": 24}, Vector3(c5.x + 1.6, 0, float(r5["zout"]) - 0.8), 0.0 if float(r5["side"]) < 0 else PI, &"ep.npc.vetrov")
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


## Южное крыло: радиоконтроль (операторы в наушниках, запись 4170), красный уголок (телевизор, шахматы), спецхран.
func _wing(w: Node3D) -> void:
	var wg: Dictionary = ep._wing
	var r1: Dictionary = wg[&"422"]
	var c1: Vector3 = r1["center"]
	# Стойки приёмников вдоль дальней стены, два оператора за столом
	for k in 3:
		var rk := Props.radio()
		rk.position = Vector3(float(r1["x1"]) - 0.5, 0, c1.z - 1.4 + k * 1.4)
		rk.rotation.y = -PI * 0.5
		w.add_child(rk)
	Geo.block(w, Vector3(0.8, 0.06, 3.4), Vector3(float(r1["x1"]) - 1.6, 0.74, c1.z), Palette.m(&"wood"), true)
	for k in 2:
		var chp := Props.chair()
		chp.position = Vector3(float(r1["x1"]) - 2.3, 0, c1.z - 0.8 + k * 1.6)
		chp.rotation.y = PI * 0.5
		w.add_child(chp)
		_add_person(w, {"style": &"officer", "sit": true, "seed": 40 + k}, Vector3(float(r1["x1"]) - 2.3, 0.05, c1.z - 0.8 + k * 1.6), -PI * 0.5, &"ep.npc.radio%d" % (k + 1))
		Geo.block(w, Vector3(0.22, 0.06, 0.06), Vector3(float(r1["x1"]) - 2.3, 1.62, c1.z - 0.8 + k * 1.6), EpBuild.mat(Color(0.1, 0.1, 0.1)), false)   # наушники
	_tape_recorder(w, Vector3(float(r1["x1"]) - 1.6, 0.77, c1.z + 1.2))
	var lbl := EpBuild.label3d(w, "4170 кГц — «КЕДР-7» — 03:10", Vector3(float(r1["x1"]) - 0.13, 2.3, c1.z), -PI * 0.5, 0.0025, Color(0.2, 0.18, 0.15))
	lbl.name = "IntLabel"
	# 424 — красный уголок: телевизор с «Временем», шахматы, бюст, вымпелы
	var r2: Dictionary = wg[&"424"]
	var c2: Vector3 = r2["center"]
	Geo.block(w, Vector3(0.6, 0.55, 0.5), Vector3(float(r2["x1"]) - 0.5, 0.95, c2.z), EpBuild.mat(Color(0.3, 0.2, 0.12)), true)
	var scr := Geo.block(w, Vector3(0.02, 0.36, 0.44), Vector3(float(r2["x1"]) - 0.76, 0.98, c2.z), EpBuild.glow_mat(Color(0.55, 0.65, 0.8), 1.2), false)
	scr.name = "TV"
	var tvl := Geo.omni(w, Vector3(float(r2["x1"]) - 1.2, 1.0, c2.z), 3.0, 0.6, Color(0.6, 0.7, 1.0))
	tvl.shadow_enabled = false
	Geo.block(w, Vector3(0.6, 0.7, 0.5), Vector3(float(r2["x1"]) - 0.5, 0.35, c2.z), Palette.m(&"wood"), true)
	Geo.block(w, Vector3(0.7, 0.05, 0.7), Vector3(c2.x - 0.5, 0.7, c2.z + 1.2), Palette.m(&"wood"), true)
	for k in 64:
		Geo.block(w, Vector3(0.07, 0.005, 0.07), Vector3(c2.x - 0.5 - 0.245 + (k % 8) * 0.07, 0.728, c2.z + 1.2 - 0.245 + (k / 8) * 0.07), EpBuild.mat(Color(0.85, 0.8, 0.65) if (k + k / 8) % 2 == 0 else Color(0.25, 0.18, 0.12)), false)
	for k in 10:
		Geo.cylinder(w, 0.012, 0.035, Vector3(c2.x - 0.5 - 0.2 + (k % 5) * 0.1, 0.75, c2.z + 1.2 - 0.2 + (k / 5) * 0.4), EpBuild.mat(Color(0.9, 0.88, 0.8) if k < 5 else Color(0.1, 0.08, 0.07)), false)
	for k in 2:
		var cc := Props.chair()
		cc.position = Vector3(c2.x - 0.5, 0, c2.z + 1.2 + (0.65 if k == 0 else -0.65))
		cc.rotation.y = 0.0 if k == 0 else PI
		w.add_child(cc)
		_add_person(w, {"style": &"officer", "sit": true, "tint": Color(0.75 + k * 0.1, 0.72, 0.7), "seed": 50 + k}, cc.position + Vector3(0, 0.05, 0), cc.rotation.y + PI, &"ep.npc.chess%d" % (k + 1))
	_portrait(w, Vector3(c2.x + 1.0, 2.0, float(r2["z1"]) - 0.12), 1.0)
	_flag(w, Vector3(float(r2["x0"]) + 0.6, 0, float(r2["z1"]) - 0.5))
	# Спецхран — заперт; из-за двери стучат
	ep._spot(wg["spec"], Vector3(1.2, 2.0, 0.6), "ep.p.spec", func() -> void:
		ep._sfx("res://assets/audio/knock_v3.ogg", -6.0)
		ep._say(&"ep.spec", 6.0))


# --- Воздух и износ: без них всё как макет ---------------------------------------------

static var _grime_tex: GradientTexture2D


static func _grime_mat(alpha := 0.35) -> StandardMaterial3D:
	if _grime_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.08, 0.06, 0.05, 1.0))
		g.set_color(1, Color(0.08, 0.06, 0.05, 0.0))
		_grime_tex = GradientTexture2D.new()
		_grime_tex.gradient = g
		_grime_tex.fill_from = Vector2(0.5, 1.0)
		_grime_tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _grime_tex
	m.albedo_color = Color(1, 1, 1, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Полоса грязи над плинтусом: снизу темно, кверху сходит на нет.
func _grime_strip(w: Node3D, a: Vector3, b: Vector3, normal: Vector3, h := 0.7, alpha := 0.5) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(a.distance_to(b), h)
	q.mesh = qm
	q.material_override = _grime_mat(alpha)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(q)
	q.global_position = (a + b) * 0.5 + Vector3(0, 0.13 + h * 0.5, 0) + normal * 0.012
	q.look_at(q.global_position + normal, Vector3.UP)
	q.rotate_object_local(Vector3.UP, PI)


func _dust(w: Node3D, center: Vector3, ext: Vector3, n := 50) -> void:
	var d := CPUParticles3D.new()
	d.amount = n
	d.lifetime = 9.0
	d.preprocess = 9.0
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = ext
	d.direction = Vector3(0.2, 0.3, 0.1)
	d.spread = 180.0
	d.initial_velocity_min = 0.01
	d.initial_velocity_max = 0.05
	d.gravity = Vector3(0, -0.003, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.95, 0.85, 0.45)
	q.material = m
	d.mesh = q
	d.position = center
	w.add_child(d)


func _haze(w: Node3D, center: Vector3, size: Vector2, alpha := 0.06) -> void:
	for k in 3:
		var q := MeshInstance3D.new()
		var qm := PlaneMesh.new()
		qm.size = size * (1.0 - k * 0.15)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.75, 0.74, 0.72, alpha)
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = center + Vector3(0, -k * 0.18, 0)
		w.add_child(q)


func _atmos(w: Node3D) -> void:
	var c := EpBuild.FLOOR4
	var zn := c.z + EpBuild.CORR_HALF
	var zs := c.z - EpBuild.CORR_HALF
	# Коридор: грязь над плинтусами, затёртые места у дверей, пыль, дымка у курилки, мигающая лампа
	_grime_strip(w, Vector3(-16, 0, zn - 0.1), Vector3(16, 0, zn - 0.1), Vector3(0, 0, -1))
	_grime_strip(w, Vector3(-16, 0, zs + 0.1), Vector3(16, 0, zs + 0.1), Vector3(0, 0, 1))
	for id: StringName in EpBuild.ROOMS:
		var r: Array = EpBuild.ROOMS[id]
		var dx := (float(r[0]) + float(r[1])) * 0.5
		var side: float = r[2]
		var z := c.z + side * (EpBuild.CORR_HALF - 0.11)
		# захватанное место у ручки и косяка
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.35, 0.9)
		q.mesh = qm
		q.material_override = _grime_mat(0.18)
		w.add_child(q)
		q.global_position = Vector3(dx + 0.75, 1.0, z)
		q.rotation.y = 0.0 if side < 0 else PI
		# комната: грязь у стен, пыль в свете, дымка под потолком
		var zin := c.z + side * EpBuild.CORR_HALF
		var zout := zin + side * EpBuild.ROOM_D
		_grime_strip(w, Vector3(float(r[0]) + 0.12, 0, zout - side * 0.15), Vector3(float(r[1]) - 0.12, 0, zout - side * 0.15), Vector3(0, 0, -side), 0.4, 0.25)
		_dust(w, Vector3(dx, 1.7, (zin + zout) * 0.5), Vector3(2.4, 1.0, 2.0), 40)
		if id in [&"412", &"420", &"415"]:
			_haze(w, Vector3(dx, EpBuild.WALL_H - 0.25, (zin + zout) * 0.5), Vector2(float(r[1]) - float(r[0]) - 0.4, EpBuild.ROOM_D - 0.4), 0.05)
		# холодный свет из окна против тёплой лампы
		var win := SpotLight3D.new()
		win.light_color = Color(0.55, 0.65, 0.95)
		win.light_energy = 0.9
		win.spot_range = 6.0
		win.spot_angle = 50.0
		win.shadow_enabled = false
		w.add_child(win)
		win.global_position = Vector3(dx, 2.3, zout - side * 0.3)
		win.look_at(Vector3(dx, 0.0, zout - side * 3.0), Vector3.UP)
		# потёртости паркета у стола и двери — тёмные пятна
		for k in 2:
			var sc := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.9, 0.6)
			sc.mesh = pm
			sc.material_override = _grime_mat(0.12)
			w.add_child(sc)
			sc.global_position = Vector3(dx + (k - 0.5) * 1.2, 0.008, zin + side * (0.9 + k * 1.6))
	_dust(w, c + Vector3(0, 1.8, 0), Vector3(15.0, 1.0, 1.2), 140)
	_haze(w, c + Vector3(-13.5, EpBuild.WALL_H - 0.3, 0), Vector2(5.0, 2.6), 0.08)
	# одна лампа в коридоре мигает (как дроссель у ЛДС)
	for n in w.get_children():
		if n is OmniLight3D and (n as OmniLight3D).global_position.distance_to(c + Vector3(-4.0, EpBuild.WALL_H - 0.3, 0)) < 0.5:
			var l := n as OmniLight3D
			var tw := l.create_tween().set_loops()
			tw.tween_property(l, "light_energy", 0.25, 0.05).set_delay(2.6)
			tw.tween_property(l, "light_energy", 0.9, 0.04)
			tw.tween_property(l, "light_energy", 0.35, 0.05)
			tw.tween_property(l, "light_energy", 0.9, 0.06)
			var hum := AudioStreamPlayer3D.new()
			hum.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/elec_buzz_loop.ogg")
			hum.volume_db = -22.0
			hum.max_distance = 7.0
			hum.position = l.position
			w.add_child(hum)
			hum.play()
			hum.finished.connect(hum.play)
			break
	# Вестибюль: пыль в свете люстр, грязь у входа (снег с сапог)
	var lb := EpBuild.LOBBY
	_dust(w, lb + Vector3(0, 2.5, 1.0), Vector3(10.0, 2.0, 6.0), 160)
	for k in 6:
		var pud := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.5, 0.35)
		pud.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.25, 0.28, 0.3, 0.35)
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pmat.roughness = 0.05
		pmat.metallic_specular = 1.0
		pud.material_override = pmat
		w.add_child(pud)
		pud.global_position = lb + Vector3(randf_range(-1.2, 1.2), 0.006, 10.5 - k * 1.1)
		pud.rotation.y = randf() * TAU


# --- За стенами: жизнь управления, которую не видно -------------------------------------

## Глухие голоса за дверями, машинка в соседнем кабинете, где-то звонит телефон; за окнами 4-го этажа
## идёт снег; на подоконнике остывает чай в подстаканнике.
func _behind_walls(w: Node3D) -> void:
	var c := EpBuild.FLOOR4
	for id: StringName in EpBuild.ROOMS:
		var r: Array = EpBuild.ROOMS[id]
		var dx := (float(r[0]) + float(r[1])) * 0.5
		var side: float = r[2]
		var zin := c.z + side * EpBuild.CORR_HALF
		var zout := zin + side * EpBuild.ROOM_D
		_room_snd.append(Vector3(dx, 1.4, (zin + zout) * 0.5))
		# Снег за стеклом: тонкий слой между рамой и стеклом — снаружи метёт
		var sn := CPUParticles3D.new()
		sn.amount = 36
		sn.lifetime = 4.0
		sn.preprocess = 4.0
		sn.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sn.emission_box_extents = Vector3(0.8, 0.1, 0.01)
		sn.direction = Vector3(0.4, -1, 0)
		sn.spread = 20.0
		sn.initial_velocity_min = 0.25
		sn.initial_velocity_max = 0.5
		sn.gravity = Vector3(0.05, -0.1, 0)
		var q := QuadMesh.new()
		q.size = Vector2(0.012, 0.012)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(0.85, 0.88, 0.95)
		q.material = m
		sn.mesh = q
		w.add_child(sn)
		sn.global_position = Vector3(dx, 2.55, zout - side * 0.16)
		# Чай на подоконнике — в 412 и 420, пар вьётся
		if id in [&"412", &"420"]:
			var tea := Props.podstakannik()
			if tea != null:
				w.add_child(tea)
				tea.global_position = Vector3(dx + 0.55, 1.02, zout - side * 0.3)
				var st := _smoke(w, tea.global_position + Vector3(0, 0.13, 0))
				st.amount = 8
				st.initial_velocity_max = 0.1
				(st.mesh.material as StandardMaterial3D).albedo_color = Color(0.9, 0.9, 0.92, 0.12)
				var em := w.get_child(w.get_child_count() - 1)
				if em.name == "Ember":
					em.queue_free()
		# Голоса за дверью — глухо, срез верхов
		if id in [&"414", &"418"]:
			var v := AudioStreamPlayer3D.new()
			v.stream = AudioDirector.cached_stream("res://assets/audio/voice_loop.ogg")
			v.volume_db = -20.0
			v.pitch_scale = 0.86 if id == &"414" else 0.95
			v.max_distance = 10.0
			v.unit_size = 2.0
			v.attenuation_filter_cutoff_hz = 900.0
			v.attenuation_filter_db = -30.0
			w.add_child(v)
			v.global_position = Vector3(dx, 1.5, (zin + zout) * 0.5)
			v.play()
			v.finished.connect(v.play)
	# Машинка за стеной 415 — очередями, с паузами на перевод каретки
	_keys = AudioStreamPlayer3D.new()
	_keys.stream = AudioDirector.cached_stream(TYPE_SND)
	_keys.volume_db = -22.0
	_keys.max_distance = 12.0
	_keys.attenuation_filter_cutoff_hz = 1500.0
	w.add_child(_keys)
	var r5: Array = EpBuild.ROOMS[&"415"]
	_keys.global_position = Vector3((float(r5[0]) + float(r5[1])) * 0.5, 1.0, c.z + EpBuild.CORR_HALF + EpBuild.ROOM_D * 0.6)


func _tick_walls(delta: float) -> void:
	if _keys == null or ep._cam == null:
		return
	_keys_t -= delta
	if _keys_t <= 0.0:
		_keys_t = _rng.randf_range(0.1, 0.24) if _rng.randf() > 0.05 else _rng.randf_range(1.2, 3.0)
		if ep._cam.global_position.distance_to(_keys.global_position) < 14.0:
			_keys.pitch_scale = _rng.randf_range(2.1, 2.7)
			_keys.play()
	_ring_room_t -= delta
	if _ring_room_t <= 0.0 and not _room_snd.is_empty():
		_ring_room_t = _rng.randf_range(35.0, 80.0)
		if ep.stage in [&"ring", &"call", &"done"]:
			return   # звонят уже нам
		var at: Vector3 = _room_snd[_rng.randi() % _room_snd.size()]
		if ep._cam.global_position.distance_to(at) > 18.0:
			return
		var ph := AudioStreamPlayer3D.new()
		ph.stream = AudioDirector.cached_stream("res://assets/audio/buzzer_loop.ogg")
		ph.pitch_scale = 1.35
		ph.volume_db = -14.0
		ph.max_distance = 16.0
		ph.attenuation_filter_cutoff_hz = 2500.0
		ep._world.add_child(ph)
		ph.global_position = at
		ph.play()
		get_tree().create_timer(_rng.randf_range(2.5, 5.0), false).timeout.connect(ph.queue_free)


## Зоя садится печатать, когда принесла дело.
func zoya_at_desk() -> void:
	if _typist != null:
		_typist.visible = true
