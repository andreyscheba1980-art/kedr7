class_name Vehicle
extends Node3D
## Пролог: «Последний рейс». ГТ-Т Михалыча везёт Мальцева по зимнику — и садится в перемёт у начала
## просеки. Вдвоём откапывают гусеницы: Виктор лопатой, Михалыч из кабины рассказывает про Семёнова и
## ырку. Газует — лопается трак. «Дальше пешком»: Михалыч остаётся ночевать в тягаче с дизелем на холостых,
## Виктор уходит по вешкам. Гул за спиной тает, а потом дизель глохнет сам — и в тишине зовут по имени.
## (Ночью «Михалыч» зовёт с того самого поворота: «Застрял я, подсоби» — drv.night1.)
## Едет по настоящей дороге (Terrain.ROADS.zimnik) и по рельефу, а не по прямой между двумя точками.

const ENGINE := "res://assets/audio/engine_loop.ogg"
const CABIN_SEAT_LOCAL := Vector3(0.50, 0.42, -0.95)
const CABIN_DRIVER_LOCAL := Vector3(-0.52, 0.03, -0.95)
const DRIVE_TIME := 32.0          ## сколько едем по зимнику до высадки
const BACK_M := 220.0             ## откуда начинаем — метров дальше по дороге от места, где сядем
const STEP_M := 2.0

static var _instance: Vehicle
static var _talk_over := false         ## Михалыч договорил (последняя — «Меня до весны не жди»): можно начинать просеку

var _body: Node3D                 ## точка на дороге (позиция) — модель и кабина внутри
var _tracked: Node3D              ## модель ГТ-Т с поворотом и наклоном
var _exterior_mesh: Node3D
var _cabin_root: Node3D
var _wipers: Array[Node3D] = []
var _wiper_sfx_t := 0.0
var _speedo_needle: Node3D
var _tach_needle: Node3D
var _oil_needle: Node3D
var _water_needle: Node3D
var _amp_needle: Node3D
var _warn_mat: StandardMaterial3D
var _pendant: Node3D
var _pendant_vel := Vector2.ZERO
var _pendant_rot := Vector2.ZERO
var _ember_light: OmniLight3D
var _ember_mat: StandardMaterial3D
var _cab_smoke: CPUParticles3D
var _cab_breath: CPUParticles3D
var _cig_puff_t := 4.0
var _breath_t := 1.5
var _cab_wind: AudioStreamPlayer
var _cab_hum: AudioStreamPlayer
var _frost_tex: Array[GradientTexture2D] = []
var _bump_t := 3.0
var _jolt := 0.0
var _cab_snow: CPUParticles3D
var _driver_cabin: CreatureRig
var _engine: AudioStreamPlayer3D
var _cabin_radio: AudioStreamPlayer3D
var _exhaust: CPUParticles3D
var _hull_col: StaticBody3D
var _lever_l: Node3D
var _lever_r: Node3D
var _lever_pull := 0.0

var _road := PackedVector3Array()  ## точки зимника через 2 м: [0] — у станции, дальше — к краю карты
var _drop_i := 0
var _s := 0.0                      ## где тягач на дороге (индекс с дробью)
var _in_cabin := false
var _can_exit := false:
	set(v):
		_can_exit = v
		if _can_exit and _in_cabin and Game.hud != null:
			Game.hud.set_prompt(Loc.t(&"cab.exit"))
var _driving := false
var _leaving := false
var _reversing := false
var _yaw_set := false
var _engine_dead := false
var _beams: Array[Light3D] = []


# --- API для пролога и игрока ------------------------------------------------------

static func drop_pos() -> Vector3:
	return Terrain.pad_pos(&"drop")


static func get_cabin_seat_world() -> Vector3:
	if _instance != null and is_instance_valid(_instance) and _instance._tracked != null:
		return _instance._tracked.to_global(CABIN_SEAT_LOCAL)
	return drop_pos() + Vector3(0, 1.4, 0)


static func can_exit_cabin() -> bool:
	return _instance != null and is_instance_valid(_instance) and _instance._can_exit and _instance._in_cabin


static func request_exit() -> void:
	if can_exit_cabin():
		_instance._on_exit_cabin()


## Пока идёт холодный старт (сцена из седьмой ночи) — кабина ждёт и не тянет игрока на сиденье.
static var hold := false
var _talking := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _instance == self:
		_instance = null


# --- Постройка ---------------------------------------------------------------------

func _ready() -> void:
	_instance = self
	_talk_over = false
	if Game.has_flag("prologue_arrived") or Game.has_flag("left_cabin"):
		_talk_over = true
		Game.set_flag("dig_pending", false)   # загрузились после высадки — тягача уже нет, копать нечего
		queue_free()
		return
	Terrain.ensure()
	_road = Terrain.road_points(&"zimnik", STEP_M)
	var d := drop_pos()
	var best := 1e9
	for i in _road.size():
		var dd := Vector2(_road[i].x - d.x, _road[i].z - d.z).length()
		if dd < best:
			best = dd
			_drop_i = i
	_s = minf(_drop_i + BACK_M / STEP_M, _road.size() - 1)

	_body = Node3D.new()
	_body.name = "VehicleBody"
	add_child(_body)
	_tracked = Props.gtt_transporter()
	_body.add_child(_tracked)
	for ch in _tracked.get_children():
		if String(ch.name).begins_with("gtt_transporter"):
			_exterior_mesh = ch
			break
	_hull_col = StaticBody3D.new()
	_hull_col.collision_layer = 0          # пока игрок в кабине — корпус его не толкает
	_hull_col.position = Vector3(0, 1.0, 0)
	_hull_col.add_child(Geo.box_shape(Vector3(3.0, 2.0, 6.2)))
	_tracked.add_child(_hull_col)
	_build_lights()
	_build_exhaust()
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AudioDirector.cached_stream(ENGINE)
	_engine.unit_size = 14.0
	_engine.max_distance = 400.0
	_engine.volume_db = -12.0
	_engine.bus = &"SFX"
	_body.add_child(_engine)
	_engine.finished.connect(_engine.play)
	_engine.play()
	_place(_s, true)
	_build_cabin()
	_run_cabin()


func _build_lights() -> void:
	for side: float in [-1.0, 1.0]:
		var beam := SpotLight3D.new()
		beam.position = Vector3(side * 1.0, 1.05, -3.0)
		beam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		beam.spot_range = 55.0
		beam.spot_angle = 30.0
		beam.spot_attenuation = 1.1
		beam.light_energy = 3.6
		beam.light_color = Color(1.0, 0.92, 0.75)
		beam.shadow_enabled = side > 0.0 and Settings.quality >= 1
		_tracked.add_child(beam)
		_beams.append(beam)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.14
		cm.bottom_radius = 2.4
		cm.height = 14.0
		cm.radial_segments = 12
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		cone.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		cmat.albedo_color = Color(0.85, 0.90, 1.0, 0.032)
		cone.material_override = cmat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.position = Vector3(0.0, 0.0, -6.8)
		cone.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		beam.add_child(cone)
	var rear := Geo.omni(_tracked, Vector3(0.0, 1.4, 3.1), 4.0, 0.6, Color(1.0, 0.2, 0.15))
	rear.shadow_enabled = false


func _build_exhaust() -> void:
	_exhaust = CPUParticles3D.new()
	_exhaust.position = Vector3(0.85, 2.38, -0.1)
	_exhaust.direction = Vector3(-0.25, 0.85, 0.8)
	_exhaust.spread = 24.0
	_exhaust.initial_velocity_min = 0.6
	_exhaust.initial_velocity_max = 2.0
	_exhaust.scale_amount_min = 0.1
	_exhaust.scale_amount_max = 0.45
	_exhaust.amount = 16
	_exhaust.lifetime = 1.6
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.28)
	_exhaust.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.22, 0.2, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_exhaust.material_override = mat
	_tracked.add_child(_exhaust)


## Тягач в точке дороги s (индекс с дробью): по рельефу, носом по ходу, с тангажом по склону.
func _place(s: float, facing_station: bool) -> void:
	var i := clampi(floori(s), 0, _road.size() - 2)
	var f := s - i
	var p := _road[i].lerp(_road[i + 1], f)
	var dir := _road[i + 1] - _road[i]           # к краю карты
	if facing_station:
		dir = -dir
	dir.y = 0.0
	dir = dir.normalized()
	p.y = Terrain.height(p.x, p.z)
	_body.position = p
	var hf := Terrain.height(p.x + dir.x * 2.6, p.z + dir.z * 2.6)
	var hb := Terrain.height(p.x - dir.x * 2.6, p.z - dir.z * 2.6)
	var pitch := atan2(hf - hb, 5.2)
	_tracked.rotation = Vector3(pitch, atan2(-dir.x, -dir.z), _tracked.rotation.z)


# --- Кабина ------------------------------------------------------------------------

func _build_cabin() -> void:
	_in_cabin = true
	Game.set_flag("in_cabin", true)
	if Game.player != null and Game.player.head != null:
		Game.player.head.position.y = 0.90
	_engine.volume_db = -14.0
	if _exterior_mesh != null:
		_exterior_mesh.visible = false
	_cabin_root = Node3D.new()
	_cabin_root.name = "CabinInterior"
	_tracked.add_child(_cabin_root)
	var metal := Palette.m(&"metal")
	var dark := Palette.m(&"dark")
	var c := _cabin_root
	c.add_child(Props.gtt_cab())   # борта, тоннель, сиденья, торпеда, капот — одной моделью
	c.add_child(Props.gtt_cab_props())   # термос, кружка, вымпел, рация, ружьё, лопата за сиденьем
	var dial_glow := Geo.block(c, Vector3(0.12, 0.03, 0.005), Vector3(0.72, 0.67, -1.398), Palette.glow(&"amber"), false)   # шкала рации
	dial_glow.name = "RadioDial"
	# Окна двери и Михалыча — в инее
	_frost_glass(c, Vector3(0.02, 0.62, 0.86), Vector3(1.15, 1.22, -1.15), 0.0)           # окно двери
	_frost_glass(c, Vector3(0.02, 0.5, 0.7), Vector3(-1.16, 1.2, -1.25), 0.0)             # окно Михалыча
	# Торпеда и щиток приборов: шкалы светятся зелёным — в темноте кабины это единственный свет
	var dial_m := StandardMaterial3D.new()
	dial_m.albedo_color = Color(0.08, 0.14, 0.09)
	dial_m.emission_enabled = true
	dial_m.emission = Color(0.25, 0.85, 0.42)
	dial_m.emission_energy_multiplier = 0.22
	for d: Array in [[-0.40, 0.86, 0.06], [-0.56, 0.86, 0.05], [-0.26, 0.87, 0.035], [-0.26, 0.79, 0.035], [0.22, 0.86, 0.04]]:
		var g := Geo.cylinder(c, d[2], 0.02, Vector3(d[0], d[1], -1.535), dial_m, false)
		g.rotation.x = deg_to_rad(90.0 - 25.0)
	_speedo_needle = _make_needle(c, Vector3(-0.40, 0.86, -1.52), 0.038)
	_tach_needle = _make_needle(c, Vector3(-0.56, 0.86, -1.52), 0.032)
	_oil_needle = _make_needle(c, Vector3(-0.26, 0.87, -1.52), 0.024)
	_water_needle = _make_needle(c, Vector3(-0.26, 0.79, -1.52), 0.024)
	_amp_needle = _make_needle(c, Vector3(0.22, 0.86, -1.52), 0.026)
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.albedo_color = Color(0.25, 0.06, 0.04)
	_warn_mat.emission_enabled = true
	_warn_mat.emission = Color(1.0, 0.2, 0.08)
	_warn_mat.emission_energy_multiplier = 0.25
	var warn_lamp := Geo.cylinder(c, 0.008, 0.012, Vector3(-0.33, 0.88, -1.53), _warn_mat, false)
	warn_lamp.rotation.x = deg_to_rad(90.0 - 25.0)
	_build_pendant(c)
	for k in 4:
		Geo.cylinder(c, 0.005, 0.03, Vector3(-0.12 + k * 0.035, 0.83, -1.54), metal, false)
	var grab := Geo.cylinder(c, 0.014, 0.36, Vector3(0.50, 0.92, -1.55), metal, false)
	grab.rotation.z = deg_to_rad(90.0)
	var dial_light := Geo.omni(c, Vector3(-0.4, 0.92, -1.45), 1.1, 0.35, Color(0.3, 0.95, 0.5))   # зелень шкал
	dial_light.shadow_enabled = false
	var roof_lamp := Geo.omni(c, Vector3(0.0, 1.45, -1.0), 2.6, 0.34, Color(1.0, 0.78, 0.5))
	roof_lamp.shadow_enabled = false
	# Рычаги поворота — дрожат в такт дизелю
	_lever_l = Node3D.new()
	_lever_l.position = Vector3(-0.40, 0.58, -1.48)
	c.add_child(_lever_l)
	_lever_r = Node3D.new()
	_lever_r.position = Vector3(-0.62, 0.58, -1.48)
	c.add_child(_lever_r)
	for lv: Node3D in [_lever_l, _lever_r]:
		Geo.cylinder(lv, 0.018, 0.42, Vector3(0, 0.20, 0), metal, false)
		Geo.cylinder(lv, 0.026, 0.12, Vector3(0, 0.38, 0), dark, false)
	# Лобовое: две половины в рамке, края в инее; дворники; стойки
	for sx: float in [-0.55, 0.55]:
		var gl := _frost_glass(c, Vector3(1.0, 0.64, 0.02), Vector3(sx, 1.24, -1.86), 18.0)
		gl.name = "Windshield"
	# Дворники на осях у нижней кромки стекла — ходят, пока едем и метёт
	for sx: float in [-0.55, 0.55]:
		var piv := Node3D.new()
		piv.position = Vector3(sx + 0.3, 0.95, -1.8)
		piv.rotation.x = deg_to_rad(18.0)
		c.add_child(piv)
		var wp := Geo.block(piv, Vector3(0.012, 0.52, 0.012), Vector3(0, 0.26, 0), dark, false)
		Geo.block(piv, Vector3(0.02, 0.42, 0.018), Vector3(-0.01, 0.3, 0.012), Palette.m(&"dark"), false)
		wp.name = "Wiper"
		piv.rotation.z = deg_to_rad(62.0)
		_wipers.append(piv)
	# Снег летит в стекло в свете фар
	_cab_snow = CPUParticles3D.new()
	_cab_snow.amount = 90
	_cab_snow.lifetime = 0.7
	_cab_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_cab_snow.emission_box_extents = Vector3(1.2, 0.5, 0.2)
	_cab_snow.direction = Vector3(0, -0.1, 1)
	_cab_snow.spread = 12.0
	_cab_snow.initial_velocity_min = 3.0
	_cab_snow.initial_velocity_max = 4.5
	_cab_snow.gravity = Vector3.ZERO
	var sq := QuadMesh.new()
	sq.size = Vector2(0.018, 0.018)
	var smt := StandardMaterial3D.new()
	smt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smt.albedo_color = Color(0.85, 0.9, 1.0)
	sq.material = smt
	_cab_snow.mesh = sq
	_cab_snow.position = Vector3(0, 1.25, -3.6)
	c.add_child(_cab_snow)
	# Плафон под крышей: тёплый, слабый — чтобы кабина читалась
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 0.9
	lamp.omni_range = 2.6
	lamp.position = Vector3(0.0, 1.75, -0.6)
	c.add_child(lamp)
	# Михалыч за рычагами
	_driver_cabin = Creatures.make_human(&"driver", true)
	_driver_cabin.position = CABIN_DRIVER_LOCAL
	_driver_cabin.scale = Vector3.ONE * 0.88
	c.add_child(_driver_cabin)
	# Михалыч курит: папироса «Прима» привязана к кости головы — движется при поворотах к Виктору
	var cig_parent: Node3D = c
	var cig := CABIN_DRIVER_LOCAL + Vector3(0.05, 1.06, -0.14)
	if _driver_cabin.skel != null:
		var h_idx := _driver_cabin.skel.find_bone("head")
		if h_idx >= 0:
			var ba := BoneAttachment3D.new()
			ba.name = "HeadCigAttachment"
			ba.bone_name = "head"
			_driver_cabin.skel.add_child(ba)
			var holder := Node3D.new()
			holder.transform = _driver_cabin.skel.get_bone_global_rest(h_idx).affine_inverse()
			ba.add_child(holder)
			cig_parent = holder
			cig = Vector3(0.025, 1.638, -0.148)
	var paper_m := StandardMaterial3D.new()
	paper_m.albedo_color = Color(0.86, 0.84, 0.78)
	Geo.block(cig_parent, Vector3(0.0065, 0.0065, 0.038), cig + Vector3(0.0, 0.004, 0.024), paper_m, false)
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ember_mat.albedo_color = Color(1.0, 0.45, 0.12)
	var ember := Geo.block(cig_parent, Vector3(0.007, 0.007, 0.012), cig, _ember_mat, false)
	ember.name = "Cigarette"
	_ember_light = OmniLight3D.new()
	_ember_light.name = "EmberLight"
	_ember_light.light_color = Color(1.0, 0.48, 0.14)
	_ember_light.light_energy = 0.22
	_ember_light.omni_range = 0.65
	_ember_light.position = cig + Vector3(0.02, 0.01, -0.02)
	cig_parent.add_child(_ember_light)

	_cab_smoke = CPUParticles3D.new()
	_cab_smoke.amount = 14
	_cab_smoke.lifetime = 2.4
	_cab_smoke.direction = Vector3(0.25, 1, 0.15)
	_cab_smoke.spread = 14.0
	_cab_smoke.initial_velocity_min = 0.06
	_cab_smoke.initial_velocity_max = 0.14
	_cab_smoke.gravity = Vector3(0.04, 0.04, 0.02)
	_cab_smoke.scale_amount_min = 0.5
	_cab_smoke.scale_amount_max = 1.8
	var smq := QuadMesh.new()
	smq.size = Vector2(0.032, 0.032)
	var smm := StandardMaterial3D.new()
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smm.albedo_texture = Atmosphere.glare_texture()
	smm.albedo_color = Color(0.75, 0.75, 0.78, 0.14)
	smq.material = smm
	_cab_smoke.mesh = smq
	_cab_smoke.position = cig + Vector3(0, 0.015, 0)
	cig_parent.add_child(_cab_smoke)

	# Пар от дыхания Михалыча на морозе
	_cab_breath = CPUParticles3D.new()
	_cab_breath.amount = 8
	_cab_breath.lifetime = 1.4
	_cab_breath.emitting = false
	_cab_breath.one_shot = true
	_cab_breath.explosiveness = 0.6
	_cab_breath.direction = Vector3(0.0, 0.08, -1.0)
	_cab_breath.spread = 18.0
	_cab_breath.initial_velocity_min = 0.15
	_cab_breath.initial_velocity_max = 0.35
	_cab_breath.gravity = Vector3(0.01, 0.03, 0.0)
	_cab_breath.scale_amount_min = 0.4
	_cab_breath.scale_amount_max = 1.4
	var brm := QuadMesh.new()
	brm.size = Vector2(0.045, 0.045)
	var brmt := StandardMaterial3D.new()
	brmt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brmt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	brmt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	brmt.albedo_texture = Atmosphere.glare_texture()
	brmt.albedo_color = Color(0.9, 0.94, 1.0, 0.10)
	brm.material = brmt
	_cab_breath.mesh = brm
	_cab_breath.position = cig + Vector3(-0.025, 0.0, 0.03)
	cig_parent.add_child(_cab_breath)

	# Аудио атмосферы в кабине: гул стального корпуса и приглушённый вой метели
	_cab_hum = AudioStreamPlayer.new()
	_cab_hum.stream = AudioDirector.cached_stream("res://assets/audio/hum_loop.ogg")
	_cab_hum.volume_db = -24.0
	_cab_hum.bus = &"SFX"
	c.add_child(_cab_hum)
	_cab_hum.play()

	_cab_wind = AudioStreamPlayer.new()
	_cab_wind.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/wind_whistle_loop.ogg")
	_cab_wind.volume_db = -28.0
	_cab_wind.bus = &"SFX"
	c.add_child(_cab_wind)
	_cab_wind.play()

	# Вспышка спички в начале рейса — Михалыч прикуривает папиросу «Прима»
	var match_light := OmniLight3D.new()
	match_light.name = "MatchLight"
	match_light.light_color = Color(1.0, 0.58, 0.18)
	match_light.light_energy = 0.0
	match_light.omni_range = 1.8
	match_light.position = cig + Vector3(0.04, -0.02, -0.06)
	cig_parent.add_child(match_light)
	_animate_match_start(match_light)
	# Шорох рации и дверь
	_cabin_radio = AudioStreamPlayer3D.new()
	_cabin_radio.stream = AudioDirector.cached_stream("res://assets/audio/static_loop.ogg")
	_cabin_radio.unit_size = 2.0
	_cabin_radio.volume_db = -20.0
	_cabin_radio.bus = &"Radio"
	c.add_child(_cabin_radio)
	_cabin_radio.play()
	var door := Interactable.new()
	door.collision_layer = Geo.LAYER_INTERACT
	door.position = Vector3(1.05, 0.95, -1.05)
	door.add_child(Geo.box_shape(Vector3(0.5, 1.0, 0.8)))
	door.prompt_provider = func() -> String: return Loc.t(&"cab.exit") if _can_exit else ""
	door.used.connect(func(_p: Player) -> void: request_exit())
	c.add_child(door)


func _animate_match_start(ml: OmniLight3D) -> void:
	if not _in_cabin or not is_inside_tree():
		return
	await get_tree().create_timer(0.8, false).timeout
	if not is_instance_valid(ml) or not _in_cabin or not is_inside_tree():
		return
	AudioDirector.play_raw("res://assets/audio/clank_v4.ogg", -10.0)
	var tw := create_tween()
	tw.tween_property(ml, "light_energy", 1.8, 0.10)
	tw.tween_property(ml, "light_energy", 1.1, 0.08)
	tw.tween_property(ml, "light_energy", 1.6, 0.12)
	tw.tween_property(ml, "light_energy", 0.0, 1.6).set_delay(1.0)


func _make_needle(parent: Node3D, pos: Vector3, length: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.x = deg_to_rad(90.0 - 25.0)
	parent.add_child(n)
	Geo.cylinder(n, 0.0018, length, Vector3(0, length * 0.5, 0), Palette.glow(&"amber"), false)
	return n


func _build_pendant(parent: Node3D) -> void:
	_pendant = Node3D.new()
	_pendant.name = "CabinPendant"
	_pendant.position = Vector3(-0.20, 1.56, -1.78)
	parent.add_child(_pendant)
	var red_m := StandardMaterial3D.new()
	red_m.albedo_color = Color(0.74, 0.14, 0.08)
	var gold_m := StandardMaterial3D.new()
	gold_m.albedo_color = Color(0.88, 0.74, 0.22)
	Geo.cylinder(_pendant, 0.0015, 0.09, Vector3(0, -0.045, 0), Palette.glow(&"amber"), false)
	Geo.block(_pendant, Vector3(0.11, 0.13, 0.004), Vector3(0, -0.155, 0), red_m, false)
	Geo.block(_pendant, Vector3(0.035, 0.035, 0.006), Vector3(0, -0.145, 0), gold_m, false)
	Geo.block(_pendant, Vector3(0.11, 0.012, 0.006), Vector3(0, -0.225, 0), gold_m, false)


## Стекло с инеем по краям: прозрачная середина, белёсые углы (радиальный градиент).
## Кабина живёт: дворники ходят, пока едем; ухабы встряхивают кабину, качают вымпел и звякает кружка;
## встали — снег перестаёт лететь, иней ползёт по стеклу от краёв.
func _cabin_life(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for k in _wipers.size():
		var w := _wipers[k]
		if _driving:
			w.rotation.z = deg_to_rad(62.0) - (0.5 - 0.5 * cos(t * 2.6)) * deg_to_rad(100.0)
		else:
			w.rotation.z = lerp_angle(w.rotation.z, deg_to_rad(62.0), minf(delta * 2.0, 1.0))
	if _driving and _in_cabin:
		_wiper_sfx_t -= delta
		if _wiper_sfx_t <= 0.0:
			_wiper_sfx_t = 1.20
			var wp := Game.audio.play_2d("res://assets/audio/ice_hit.ogg", -28.0)
			if wp != null:
				wp.pitch_scale = randf_range(2.1, 2.5)
	if _speedo_needle != null:
		var target_angle := deg_to_rad(38.0 + sin(t * 14.0) * 4.5) if _driving else deg_to_rad(-45.0)
		_speedo_needle.rotation.z = lerp_angle(_speedo_needle.rotation.z, target_angle, minf(delta * 8.0, 1.0))
	if _tach_needle != null:
		var target_tach := deg_to_rad(22.0 + sin(t * 24.0) * 3.5) if _driving else deg_to_rad(-30.0 + sin(t * 12.0) * 2.0)
		_tach_needle.rotation.z = lerp_angle(_tach_needle.rotation.z, target_tach, minf(delta * 9.0, 1.0))
	if _oil_needle != null:
		var target_oil := deg_to_rad(15.0 + sin(t * 9.0) * 1.5)
		_oil_needle.rotation.z = lerp_angle(_oil_needle.rotation.z, target_oil, minf(delta * 5.0, 1.0))
	if _water_needle != null:
		var target_water := deg_to_rad(8.0 + sin(t * 4.0) * 0.8)
		_water_needle.rotation.z = lerp_angle(_water_needle.rotation.z, target_water, minf(delta * 3.0, 1.0))
	if _amp_needle != null:
		var target_amp := deg_to_rad(-10.0 + sin(t * 18.0) * 2.2) if _driving else deg_to_rad(-3.0)
		_amp_needle.rotation.z = lerp_angle(_amp_needle.rotation.z, target_amp, minf(delta * 7.0, 1.0))
	if _pendant != null:
		var target_pitch := -_jolt * 2.8 - (0.035 if _driving else 0.0)
		var target_roll := sin(t * 2.1) * (0.065 if _driving else 0.008) + _jolt * sin(t * 16.0) * 1.2
		_pendant_vel.x += (target_pitch - _pendant_rot.x) * 22.0 * delta
		_pendant_vel.y += (target_roll - _pendant_rot.y) * 22.0 * delta
		_pendant_vel *= exp(-3.8 * delta)
		_pendant_rot += _pendant_vel * delta
		_pendant.rotation = Vector3(_pendant_rot.x, 0.0, _pendant_rot.y)
	_cig_puff_t -= delta
	if _cig_puff_t <= 0.0:
		_cig_puff_t = randf_range(11.0, 17.0)
		if _driver_cabin != null and _driver_cabin.has_clip(&"sit_smoke") and not _talking:
			_driver_cabin.pose_override = &"sit_smoke"
			get_tree().create_timer(3.5, false).timeout.connect(func() -> void:
				if is_instance_valid(_driver_cabin) and _driver_cabin.pose_override == &"sit_smoke":
					_driver_cabin.pose_override = &""
			)
		if _ember_light != null:
			var tw_e := create_tween()
			tw_e.tween_property(_ember_light, "light_energy", 1.5, 0.6)
			tw_e.tween_property(_ember_light, "light_energy", 0.22, 1.2).set_delay(0.8)
		if _cab_smoke != null:
			_cab_smoke.restart()
	_breath_t -= delta
	if _breath_t <= 0.0:
		_breath_t = randf_range(3.2, 5.0)
		if _cab_breath != null:
			_cab_breath.restart()
	if _cab_snow != null:
		_cab_snow.emitting = _driving
	if _driving:
		_bump_t -= delta
		if _bump_t <= 0.0:
			_bump_t = randf_range(2.5, 6.0)
			_jolt = randf_range(0.025, 0.05)
			var ck := Game.audio.play_2d("res://assets/audio/clank.ogg", -18.0)
			if ck != null:
				ck.pitch_scale = randf_range(1.6, 2.2)
			if randf() < 0.55:
				var mug := Game.audio.play_2d("res://assets/audio/clank_v3.ogg", -24.0)
				if mug != null:
					mug.pitch_scale = randf_range(1.9, 2.4)
	_jolt = move_toward(_jolt, 0.0, delta * 0.12)
	Game.player.head.position.y += sin(t * 40.0) * _jolt
	if _cabin_root != null:
		_cabin_root.rotation.x = sin(t * 33.0) * _jolt * 0.15
	# Иней: встали — тянется от краёв к середине
	for tx in _frost_tex:
		var want := 0.82 if not _driving else 1.05
		tx.fill_to = tx.fill_to.lerp(Vector2(want, want), minf(delta * 0.02, 1.0))


func _frost_glass(parent: Node3D, size: Vector3, pos: Vector3, tilt_deg: float) -> MeshInstance3D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.36, 0.40, 0.46, 0.0))
	grad.set_color(1, Color(0.46, 0.50, 0.56, 0.9))
	grad.add_point(0.55, Color(0.38, 0.42, 0.48, 0.08))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	_frost_tex.append(tex)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(maxf(size.x, size.z), size.y)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	if size.x < size.z:
		mi.rotation.y = deg_to_rad(90.0)
	mi.rotation.x = deg_to_rad(tilt_deg)
	return mi


func _say(key: StringName, look_yaw: float, wait: float) -> bool:
	while hold or (Game.hud != null and Game.hud.is_screen_shown()):
		await get_tree().process_frame
	if _driver_cabin != null:
		_driver_cabin.head_look_target_yaw = deg_to_rad(look_yaw)
	var dur := Voice.say(key, wait)
	var txt := Loc.t(key)
	if _driver_cabin != null and (txt.begins_with("МИХАЛЫЧ") or txt.begins_with("MIKHALYCH")):
		_driver_cabin.talk = dur - 0.3
	await get_tree().create_timer(dur, false).timeout
	return _in_cabin and is_inside_tree()


## Полминуты в кабине: едем, скупой разговор, остановка у развилки, напутствие, «дальше пешком».
func _run_cabin() -> void:
	await get_tree().process_frame     # карточка загрузки и холодный старт включаются в этом же кадре
	await get_tree().process_frame
	while Game.hud != null and (Game.hud.is_screen_shown() or hold):
		await get_tree().process_frame
	_driving = true
	_talking = true
	AudioMix.set_indoor(0.85)
	await get_tree().create_timer(1.8, false).timeout

	# Михалыч курит, неторопливый северный разговор
	if not await _say(&"cab.1", -42.0, 3.0):
		_talking = false
		return
	await get_tree().create_timer(0.8, false).timeout

	if not await _say(&"cab.stove_hint", -38.0, 3.4):
		_talking = false
		return
	await get_tree().create_timer(1.0, false).timeout

	if not await _say(&"cab.diesel_hint", -40.0, 3.4):
		_talking = false
		return
	await get_tree().create_timer(1.2, false).timeout

	# Рация: шорох эфира, странный посторонний звук — Михалыч глушит ударом кулака
	if _cabin_radio != null and _in_cabin:
		_cabin_radio.volume_db = -8.0
		Game.audio.play_3d("res://assets/audio/radio_anomaly.ogg", _cabin_radio.global_position, -4.0, 3.0)
		await get_tree().create_timer(2.2, false).timeout
		if _driver_cabin != null:
			_driver_cabin.head_look_target_yaw = deg_to_rad(28.0)
		AudioDirector.play_raw("res://assets/audio/clank.ogg", 1.5)
		_cabin_radio.stop()
		var dial := _cabin_root.get_node_or_null("RadioDial") as Node3D
		if dial != null:
			dial.visible = false
		await get_tree().create_timer(1.2, false).timeout

	if not await _say(&"cab.prev_hint", 0.0, 3.2):
		_talking = false
		return

	# Едем до точки высадки
	while _driving and _in_cabin and _s > _drop_i + 0.1:
		await get_tree().process_frame

	_driving = false
	_talking = false

	# Мягкий тормоз тягача
	AudioDirector.play_raw("res://assets/audio/clank_v4.ogg", -4.0)
	create_tween().tween_property(_engine, "pitch_scale", 0.85, 0.8)
	await get_tree().create_timer(0.8, false).timeout

	# Напутствие перед высадкой
	if not await _say(&"cab.halt_hint", -44.0, 4.5):
		return
	await get_tree().create_timer(0.5, false).timeout

	if not await _say(&"cab.items_hint", -48.0, 3.6):
		return

	_can_exit = true
	_talk_over = true
	if Game.hud != null and _in_cabin:
		Game.hud.set_prompt(Loc.t(&"cab.exit"))


func _on_exit_cabin() -> void:
	if not _in_cabin:
		return
	_in_cabin = false
	_can_exit = false
	_driving = false
	_talk_over = true
	Game.set_flag("in_cabin", false)
	Game.set_flag("left_cabin", true)
	Game.set_flag("dig_pending", false)
	# Снаряжение: фонарь, планшет, термос, спички
	for f in ["has_trunk", "trunk_delivered", "has_fas4", "has_tablet"]:
		Game.set_flag(f, true)
	Game.complete_step(&"driver")

	AudioDirector.play_raw("res://assets/sfx/door_handle.ogg", 2.0)
	AudioDirector.play_raw("res://assets/audio/door.ogg", 2.5)
	AudioDirector.play_raw("res://assets/audio/gust.ogg", 2.0)

	if _cabin_radio != null:
		_cabin_radio.stop()
	if _cab_hum != null:
		_cab_hum.stop()
	if _cab_wind != null:
		_cab_wind.stop()
	if _cabin_root != null:
		_cabin_root.queue_free()
		_cabin_root = null
	_frost_tex.clear()
	_wipers.clear()
	_speedo_needle = null
	_tach_needle = null
	_oil_needle = null
	_water_needle = null
	_amp_needle = null
	_pendant = null
	_lever_l = null
	_lever_r = null
	_cab_snow = null
	_cabin_radio = null
	_cab_hum = null
	_cab_wind = null

	if is_instance_valid(_driver_cabin):
		_driver_cabin.reparent(_tracked, false)
		_driver_cabin.position = CABIN_DRIVER_LOCAL
		_driver_cabin.visible = true
		var cab_glow := Geo.omni(_tracked, Vector3(-0.35, 1.05, -1.25), 1.4, 0.35, Color(0.35, 0.9, 0.5))
		cab_glow.shadow_enabled = false

	if _exterior_mesh != null:
		_exterior_mesh.visible = true
	_hull_col.collision_layer = Geo.LAYER_WORLD

	# Удар мороза: срез внутреннего звука в 0
	AudioMix.set_indoor(0.0)

	var right := _tracked.global_basis.x
	right.y = 0.0
	var out := Terrain.at(_body.position + right.normalized() * 2.6)
	if Game.player != null:
		Game.player.velocity = Vector3.ZERO
		Game.player.global_position = out + Vector3(0, 0.05, 0)
		var to_station := -_tracked.global_basis.z
		Game.player.rotation.y = atan2(-to_station.x, -to_station.z) + deg_to_rad(25.0)
		Game.player.head.position.y = 1.58
		Game.player.set_flashlight(true)
		Game.player.shake(0.06, 0.45)
		Game.warmth = 85.0

	# Учебный просвет: первый луч маяка сквозь метель
	Storm.force_gap(4.5)

	if Game.hud != null:
		Game.hud.set_prompt("")
		Game.hud.subtitle(Loc.t(&"obj.prologue_walk"), 4.0)

	_reverse_away()


func _reverse_away() -> void:
	if _leaving:
		return
	_leaving = true
	_reversing = true
	await get_tree().create_timer(1.8, false).timeout
	if not is_inside_tree():
		return
	if _engine != null:
		create_tween().tween_property(_engine, "pitch_scale", 1.15, 1.0)
		create_tween().tween_property(_engine, "volume_db", -4.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_engine, "volume_db", -52.0, 16.0)
	var t := 0.0
	while t < 16.0 and is_inside_tree():
		var dt := get_process_delta_time()
		t += dt
		_s = minf(_s + (BACK_M / DRIVE_TIME / STEP_M) * 0.85 * dt, _road.size() - 1)
		_place(_s, true)
		await get_tree().process_frame
	if is_inside_tree():
		queue_free()


## Договорил ли Михалыч: до этого события просеки ждут, чтобы не перебить его реплики.
static func talk_over() -> bool:
	return _talk_over or _instance == null or not is_instance_valid(_instance)


## Дизель глохнет сам — гул за спиной обрывается, фары гаснут.
static func engine_die() -> void:
	if _instance == null or not is_instance_valid(_instance) or _instance._engine_dead:
		return
	var v := _instance
	v._engine_dead = true
	if v._engine != null:
		v.create_tween().tween_property(v._engine, "volume_db", -50.0, 1.5)


func _process(delta: float) -> void:
	if Game.player == null or _road.is_empty():
		return
	if _reversing:
		return
	if _driving:
		var remain := _s - _drop_i
		var v := clampf(remain / 1.5, 0.5, 1.0) * (BACK_M / DRIVE_TIME) / STEP_M
		if _talking and remain < 5.0:
			v *= 0.12
		_s = maxf(_s - v * delta, _drop_i)
		_place(_s, true)
		_tracked.rotation.z = sin(Time.get_ticks_msec() * 0.0022) * deg_to_rad(0.9)
		if _s <= _drop_i + 0.01:
			_driving = false
	if _in_cabin:
		if not hold:
			if not _yaw_set:
				_yaw_set = true
				Game.player.rotation.y = _tracked.global_rotation.y
			Game.player.global_position = _tracked.to_global(CABIN_SEAT_LOCAL)
			Game.player.velocity = Vector3.ZERO
		var vib := sin(Time.get_ticks_msec() * 0.035) * (0.005 if _driving else 0.002)
		Game.player.head.position.y = 0.90 + vib
		_cabin_life(delta)
		if _lever_l != null:
			_lever_l.rotation.x = sin(Time.get_ticks_msec() * 0.052) * 0.008 + _lever_pull
			_lever_r.rotation.x = sin(Time.get_ticks_msec() * 0.052 + 1.2) * 0.008 + _lever_pull
