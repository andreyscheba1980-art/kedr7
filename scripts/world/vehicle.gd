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
const CABIN_DRIVER_LOCAL := Vector3(-0.52, 0.10, -0.95)
const DRIVE_TIME := 34.0          ## сколько едем по зимнику до перемёта (начало разговора в кабине)
const BACK_M := 130.0             ## откуда начинаем — метров дальше по дороге от места, где сядем
const DIG_SPOTS := [Vector3(-1.45, 0.0, -2.4), Vector3(1.45, 0.0, -2.4)]   ## перемёт у передних катков (оси тягача)
const STEP_M := 2.0

static var _instance: Vehicle
static var _talk_over := false         ## Михалыч договорил (последняя — «Меня до весны не жди»): можно начинать просеку

var _body: Node3D                 ## точка на дороге (позиция) — модель и кабина внутри
var _tracked: Node3D              ## модель ГТ-Т с поворотом и наклоном
var _exterior_mesh: Node3D
var _cabin_root: Node3D
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
var _can_exit := false
var _driving := false
var _leaving := false
var _yaw_set := false
var _dug := 0                      ## сколько гусениц откопано
var _dig_nodes: Array[Node3D] = []
var _talk_done := false
var _gave_up := false
var _engine_dead := false
var _beams: Array[Light3D] = []
var _alone_said := false
var _leash_hinted := false
const LEASH_M := 30.0      ## пока Михалыч не договорил, дальше от тягача не уйти: иначе вся просека — молча


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
	for k in 4:
		Geo.cylinder(c, 0.005, 0.03, Vector3(-0.12 + k * 0.035, 0.83, -1.54), metal, false)
	var grab := Geo.cylinder(c, 0.014, 0.36, Vector3(0.50, 0.92, -1.55), metal, false)
	grab.rotation.z = deg_to_rad(90.0)
	var dial_light := Geo.omni(c, Vector3(-0.4, 0.92, -1.45), 1.2, 0.35, Color(0.3, 0.95, 0.5))
	dial_light.shadow_enabled = false
	var roof_lamp := Geo.omni(c, Vector3(0.0, 1.5, -1.0), 2.4, 0.18, Color(1.0, 0.8, 0.55))
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
	for sx: float in [-0.55, 0.55]:
		var wp := Geo.block(c, Vector3(0.012, 0.5, 0.012), Vector3(sx + 0.12, 1.05, -1.82), dark, false)
		wp.rotation = Vector3(deg_to_rad(18.0), 0.0, deg_to_rad(-62.0))
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
	_driver_cabin.scale = Vector3.ONE * 0.82
	c.add_child(_driver_cabin)
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


## Стекло с инеем по краям: прозрачная середина, белёсые углы (радиальный градиент).
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


## Полминуты в кабине: едем, три реплики, тормоз, «дальше пешком».
func _run_cabin() -> void:
	await get_tree().process_frame     # карточка загрузки и холодный старт включаются в этом же кадре
	await get_tree().process_frame
	while Game.hud != null and (Game.hud.is_screen_shown() or hold):
		await get_tree().process_frame
	_driving = true
	_talking = true
	await get_tree().create_timer(2.0, false).timeout
	# Разговор в кабине: кто ты, зачем сюда, что было с Семёновым, байки про ырку — и уговор про три гудка.
	# [ключ, куда смотрит Михалыч (°), минимум секунд]. Реплики Виктора — Михалыч смотрит на дорогу.
	var lines: Array = [
		[&"cab.1", -42.0, 3.0], [&"cab.2", -12.0, 2.4], [&"cab.3", -36.0, 3.2], [&"cab.4", -10.0, 2.6],
		[&"cab.5", -36.0, 2.8], [&"cab.6", -12.0, 2.2], [&"cab.7", -40.0, 3.4],
		[&"th.cab", -8.0, 3.6],
	]
	for ln: Array in lines:
		if not await _say(ln[0], ln[1], ln[2]):
			_talking = false
			return
		await get_tree().create_timer(0.35, false).timeout
	_talking = false
	while _driving and _in_cabin:
		await get_tree().process_frame
	# Перемёт: тягач зарывается носом, его ведёт вбок, дизель воет — гусеницы буксуют в снегу
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 2.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_lever_pull", deg_to_rad(-24.0), 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_tracked, "rotation:z", deg_to_rad(5.5), 0.5).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_tracked, "position:y", -0.35, 0.5)
	if Game.player != null:
		Game.player.shake(0.12, 0.7)
	create_tween().tween_property(_engine, "pitch_scale", 1.45, 0.6)
	_spray(1.6)
	await get_tree().create_timer(1.6, false).timeout
	create_tween().tween_property(_engine, "pitch_scale", 0.8, 1.0)
	create_tween().tween_property(self, "_lever_pull", 0.0, 0.8)
	await get_tree().create_timer(0.8, false).timeout
	_can_exit = true
	if not await _say(&"cab.stuck", -48.0, 3.6):
		return
	if Game.hud != null and _in_cabin:
		Game.hud.set_prompt(Loc.t(&"cab.exit"))


func _on_exit_cabin() -> void:
	if not _in_cabin:
		return
	_in_cabin = false
	_can_exit = false
	_driving = false
	Game.set_flag("in_cabin", false)
	Game.set_flag("left_cabin", true)
	# Снаряжение уже на станции (завезли с прошлым бортом): фонарь и планшет — при себе
	for f in ["has_trunk", "trunk_delivered", "has_fas4", "has_tablet"]:
		Game.set_flag(f, true)
	Game.complete_step(&"driver")
	AudioDirector.play_raw("res://assets/audio/door.ogg", 2.0)
	if _cabin_radio != null:
		_cabin_radio.stop()
	_cabin_root.visible = false
	if _exterior_mesh != null:
		_exterior_mesh.visible = true
	_hull_col.collision_layer = Geo.LAYER_WORLD
	_engine.volume_db = -2.0
	_engine.pitch_scale = 0.85
	var right := _tracked.global_basis.x
	right.y = 0.0
	var out := Terrain.at(_body.position + right.normalized() * 2.6 + Vector3(0, 0, 0))
	if Game.player != null:
		Game.player.velocity = Vector3.ZERO
		Game.player.global_position = out + Vector3(0, 0.05, 0)
		var to_station := -_tracked.global_basis.z
		Game.player.rotation.y = atan2(-to_station.x, -to_station.z) + deg_to_rad(25.0)
		Game.player.head.position.y = 1.58
		Game.player.set_flashlight(true)
		Game.player.shake(0.04, 0.3)
	if Game.hud != null:
		Game.hud.set_prompt("")
	_engine.volume_db = -6.0
	Game.set_flag("dig_pending", true)
	_build_dig_spots()
	_talk_while_digging()


## Перемёт под передними катками: два сугроба, их надо откопать лопатой (удерживать [E]).
func _build_dig_spots() -> void:
	var mound := SphereMesh.new()
	mound.radius = 1.0
	mound.height = 2.0
	mound.radial_segments = 18
	mound.rings = 8
	for i in DIG_SPOTS.size():
		var local: Vector3 = DIG_SPOTS[i]
		var at := _tracked.to_global(local)
		at.y = Terrain.height(at.x, at.z)
		var m := MeshInstance3D.new()
		m.mesh = mound
		m.material_override = Palette.m(&"drift")
		m.scale = Vector3(0.9, 0.55, 1.4)
		m.position = at + Vector3(0, 0.1, 0)
		m.rotation.y = _tracked.global_rotation.y
		add_child(m)
		_dig_nodes.append(m)
		var it := Geo.interactable(self, Vector3(1.6, 1.0, 2.0), at + Vector3(0, 0.45, 0), null, "", Callable())
		it.hold_time = 2.8
		it.hold_sound = "res://assets/audio/step_snow_3.ogg"
		it.prompt_provider = func() -> String: return Loc.t(&"cab.dig") if m.visible else ""
		it.used.connect(func(_p: Player) -> void:
			if not m.visible:
				return
			m.visible = false
			it.collision_layer = 0
			_dug += 1
			Game.audio.play_3d(SFX_SNOW_FALL, at + Vector3(0, 0.5, 0), -2.0, 5.0)
			if Game.player != null:
				Game.player.shake(0.03, 0.25)
			_maybe_try())


const SFX_SNOW_FALL := "res://assets/audio/snow_fall.ogg"


## Пока Виктор копает — Михалыч из кабины: про Свердловск, про Семёнова, про ырку и три гудка.
func _talk_while_digging() -> void:
	await get_tree().create_timer(1.5, false).timeout
	for ln: Array in [[&"cab.dig_hint", 3.4], [&"cab.11", 5.0], [&"cab.12", 5.0], [&"cab.13", 3.4], [&"cab.14", 2.6],
			[&"cab.15", 6.0], [&"cab.16", 2.0], [&"cab.17", 7.5], [&"cab.18", 6.5]]:
		if not is_inside_tree():
			return
		await get_tree().create_timer(Voice.say(ln[0], ln[1]), false).timeout
		await get_tree().create_timer(0.4, false).timeout
	_talk_done = true
	_maybe_try()


## Откопано и договорили (или Виктор ушёл, не докопав) — газует. Трак лопается: дальше пешком.
func _maybe_try() -> void:
	if _leaving or not _talk_done:
		return
	Game.set_flag("dig_pending", false)
	if _gave_up:
		_leaving = true
		_finish_talk(false)    # ушёл, не докопав: газовать некому помогать — Михалыч кричит остальное вслед
		return
	if _dug < DIG_SPOTS.size():
		return
	_leaving = true
	await get_tree().create_timer(Voice.say(&"cab.try", 2.6), false).timeout
	_exhaust.amount = 40
	_exhaust.initial_velocity_max = 5.0
	create_tween().tween_property(_engine, "pitch_scale", 1.6, 0.8)
	_spray(2.4)
	var tw := create_tween()
	for k in 4:
		tw.tween_property(_tracked, "rotation:z", deg_to_rad(3.5 if k % 2 == 0 else 6.5), 0.3)
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree():
		return
	AudioDirector.play_raw("res://assets/audio/clank.ogg", 4.0)
	Game.audio.play_3d("res://assets/sfx/gen_stall.ogg", _body.global_position + Vector3(0, 1, 0), -4.0, 12.0)
	if Game.player != null:
		Game.player.shake(0.06, 0.4)
	create_tween().tween_property(_engine, "pitch_scale", 0.78, 1.4)
	_exhaust.amount = 16
	_exhaust.initial_velocity_max = 2.0
	await get_tree().create_timer(1.4, false).timeout
	_finish_talk(true)


func _finish_talk(tried: bool) -> void:
	var lines: Array = [[&"cab.8", 3.4], [&"cab.10", 6.5], [&"cab.stay", 4.6], [&"driver.farewell_3b", 3.5]]
	if tried:
		lines.push_front([&"cab.track", 3.2])
	for ln: Array in lines:
		if not is_inside_tree():
			return
		await get_tree().create_timer(Voice.say(ln[0], ln[1]), false).timeout
		await get_tree().create_timer(0.3, false).timeout
	_talk_over = true


## Договорил ли Михалыч: до этого события просеки ждут, чтобы не перебить его реплики.
static func talk_over() -> bool:
	return _talk_over or _instance == null or not is_instance_valid(_instance)


## Снег из-под гусениц — веером в стороны.
func _spray(dur: float) -> void:
	for side: float in [-1.0, 1.0]:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.amount = 60
		p.lifetime = 1.2
		p.explosiveness = 0.1
		p.direction = Vector3(side, 0.7, 0.6)
		p.spread = 30.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -7.0, 0)
		p.scale_amount_min = 0.4
		p.scale_amount_max = 1.2
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.16)
		p.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.9, 0.93, 1.0, 0.8)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		p.material_override = m
		p.position = Vector3(side * 1.3, 0.4, -1.4)
		_tracked.add_child(p)
		p.emitting = true
		get_tree().create_timer(dur + 1.4, false).timeout.connect(p.queue_free)


## Дизель глохнет сам — гул за спиной обрывается, фары гаснут (событие просеки).
static func engine_die() -> void:
	if _instance == null or not is_instance_valid(_instance) or _instance._engine_dead:
		return
	var v := _instance
	v._engine_dead = true
	Game.audio.play_3d("res://assets/sfx/gen_stall.ogg", v._body.global_position + Vector3(0, 1, 0), 2.0, 40.0)
	v.create_tween().tween_property(v._engine, "pitch_scale", 0.3, 1.0)
	await v.get_tree().create_timer(1.0, false).timeout
	if not is_instance_valid(v):
		return
	v._engine.stop()
	v._exhaust.emitting = false
	for b in v._beams:
		b.visible = false


## Мягкий поводок: игрок, ушедший раньше, чем Михалыч договорил, упирается в 30 м от тягача. Без него
## быстрый игрок доходил до дома под разговор — и события просеки (ждущие конца разговора) пропадали.
func _leash() -> void:
	var c := _body.global_position
	var off := Game.player.global_position - c
	off.y = 0.0
	if off.length() <= LEASH_M:
		return
	var out := off.normalized()
	var p := c + out * LEASH_M
	Game.player.global_position = Vector3(p.x, Game.player.global_position.y, p.z)
	var vo := Game.player.velocity.dot(out)
	if vo > 0.0:
		Game.player.velocity -= out * vo
	if not _leash_hinted:
		_leash_hinted = true
		Game.hud.hint(Loc.t(&"cab.wait_hint"), 6.0)


func _process(delta: float) -> void:
	if Game.player == null or _road.is_empty():
		return
	if not _in_cabin and Game.has_flag("left_cabin") and _body != null:
		var far := Game.player.global_position.distance_to(_body.global_position)
		if not _leaving and _dug < DIG_SPOTS.size() and far > 26.0 and not _gave_up:
			_gave_up = true       # ушёл, не докопав: договорят вслед, без попытки газовать
			_maybe_try()
		if not _talk_over and not _leaving:
			_leash()
		if far > 26.0 and _talk_over and not _alone_said:
			_alone_said = true
			var pt := get_tree().root.find_child("PrologueTrail", true, false)
			if pt != null and pt.has_method(&"on_vehicle_left"):
				pt.on_vehicle_left()
		if not _engine_dead and _engine != null:
			_engine.volume_db = lerpf(-6.0, -30.0, clampf((far - 10.0) / 120.0, 0.0, 1.0))
	if _driving:
		# Подъезд к высадке: плавно тормозим к концу
		var remain := _s - _drop_i
		var v := clampf(remain / 1.5, 0.5, 1.0) * (BACK_M / DRIVE_TIME) / STEP_M   # в перемёт — с ходу
		if _talking and remain < 5.0:
			v *= 0.12          # разговор не закончен — у высадки ползём, а не встаём молча
		_s = maxf(_s - v * delta, _drop_i)
		_place(_s, true)
		_tracked.rotation.z = sin(Time.get_ticks_msec() * 0.0022) * deg_to_rad(0.9)
		if _s <= _drop_i + 0.01:
			_driving = false
	if _in_cabin and not hold:
		if not _yaw_set:
			_yaw_set = true
			Game.player.rotation.y = _tracked.global_rotation.y   # смотрим вперёд, по ходу тягача
		Game.player.global_position = _tracked.to_global(CABIN_SEAT_LOCAL)
		Game.player.velocity = Vector3.ZERO
		var vib := sin(Time.get_ticks_msec() * 0.035) * (0.005 if _driving else 0.002)
		Game.player.head.position.y = 0.90 + vib
		if _lever_l != null:
			_lever_l.rotation.x = sin(Time.get_ticks_msec() * 0.052) * 0.008 + _lever_pull
			_lever_r.rotation.x = sin(Time.get_ticks_msec() * 0.052 + 1.2) * 0.008 + _lever_pull
