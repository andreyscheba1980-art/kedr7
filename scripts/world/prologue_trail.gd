class_name PrologueTrail
extends Node3D
## Пролог: от застрявшего ГТ-Т до крыльца станции — узкая просека в тайге, ~210 м, минуты две.
## События идут плотно, одно за другим: дизель за спиной глохнет и в тишине зовут по имени; в стороне
## между елей стоит человек — посветишь, его нет; кто-то перебегает просеку прямо перед тобой.
## Ели стеной с двух сторон (Terrain сажает их вплотную к дороге), леер по обочине, дальше 15–20 м
## ничего не видно. События — не надписи, а то, что видно и слышно:
##   треск ствола и снег с еловой лапы; брошенные нарты Семёнова с запиской; кто-то перебегает
##   просеку впереди в луче фонаря; свист в лесу; свет в окне избы, гаснущий при подходе;
##   свежие босые следы поперёк тропы; шаги позади, которые замирают вместе с тобой;
##   огонёк станции сквозь деревья мигает; дверь станции приоткрыта, подпёрта поленом.

const TRAIL_SPEED := 2.0          ## шаг с рюкзаком по снегу (обычный WALK_SPEED = 2.3)
const SFX_RAVEN := "res://assets/audio/raven.ogg"
const SFX_CREAK := "res://assets/audio/tree_creak.ogg"
const SFX_WHISTLE := "res://assets/audio/whistle.ogg"
const SFX_GUST := "res://assets/audio/gust.ogg"
const SFX_DOOR := "res://assets/audio/door.ogg"
const SFX_SNOW := "res://assets/audio/snow_fall.ogg"
const SFX_KNOCK := "res://assets/audio/knock.ogg"

## Опорные точки после зимника: мимо избы к развилке у мачты и к крыльцу.
const TAIL: Array[Vector3] = [Vector3(-48, 0, -74), Vector3(-30, 0, -58), Vector3(-14, 0, -40), Vector3(-9.4, 0, -35),
	Vector3(-2, 0, -28), Vector3(10, 0, -25), Vector3(25, 0, -18), Vector3(29, 0, -2), Vector3(20, 0, 3.5), Vector3(16.8, 0, 3.5)]

static var _route := PackedVector3Array()
static var _dist := PackedFloat32Array()     ## пройдено от высадки до точки i

var _progress := 0.0                          ## сколько метров пройдено (по ближайшей точке маршрута)
var _done: Dictionary = {}
var _vehicle_left := false
var _izba_light: OmniLight3D
var _izba_glow: MeshInstance3D
var _station_light: OmniLight3D
var _station_phase := 0
var _station_t := 0.0
var _silhouette: Node3D
var _runner: CreatureRig
var _follower := false
var _follower_t := 0.0
var _sled_read := false
var _wall_t := 0.0
var _deep_warned := false
var _figure: Node3D
var _figure_seen := 0.0
var _prop_said_ms := -100000


## Маршрут пролога: от высадки по зимнику к станции, точки через ~4 м с отметками рельефа.
static func route() -> PackedVector3Array:
	if not _route.is_empty():
		return _route
	Terrain.ensure()
	var road := Terrain.road_points(&"zimnik", 4.0)        # [0] — у избы, дальше — к краю
	var drop := Terrain.pad_pos(&"drop")
	var di := 0
	var best := 1e9
	for i in road.size():
		var d := Vector2(road[i].x - drop.x, road[i].z - drop.z).length()
		if d < best:
			best = d
			di = i
	for i in range(di, -1, -1):
		_route.append(road[i])
	var prev := _route[_route.size() - 1]
	for p in TAIL:
		var n := maxi(1, ceili(prev.distance_to(p) / 4.0))
		for k in range(1, n + 1):
			_route.append(Terrain.at(prev.lerp(p, float(k) / n)))
		prev = p
	_dist.resize(_route.size())
	_dist[0] = 0.0
	for i in range(1, _route.size()):
		_dist[i] = _dist[i - 1] + _route[i].distance_to(_route[i - 1])
	return _route


static func length_m() -> float:
	route()
	return _dist[_dist.size() - 1]


## Точка маршрута на расстоянии s метров от высадки и направление пути там.
static func point_at(s: float) -> Array:
	route()
	for i in range(1, _route.size()):
		if _dist[i] >= s:
			var f := (s - _dist[i - 1]) / maxf(_dist[i] - _dist[i - 1], 0.01)
			var dir := _route[i] - _route[i - 1]
			dir.y = 0.0
			return [_route[i - 1].lerp(_route[i], f), dir.normalized()]
	var n := _route.size()
	return [_route[n - 1], (_route[n - 1] - _route[n - 2]).normalized()]


func _ready() -> void:
	if not Game.is_prologue() or Game.has_flag("prologue_arrived"):
		queue_free()
		return
	route()
	print("[prologue] маршрут %.0f м, %.0f с шагом" % [length_m(), length_m() / TRAIL_SPEED])
	_build_sled()
	_build_izba_light()
	_build_station_light()
	_build_porch_log()
	_build_bare_tracks()
	_build_figure()


func _process(delta: float) -> void:
	if not Game.is_prologue() or Game.has_flag("prologue_arrived") or Game.player == null:
		return
	if Game.has_flag("in_cabin"):
		return
	var pp := Game.player.global_position
	_update_progress(pp)
	_events(pp)
	_process_follower(pp, delta)
	_process_station_light(delta)
	_process_boundary(pp, delta)


func _update_progress(pp: Vector3) -> void:
	var best := 1e9
	var bi := 0
	for i in _route.size():
		var d := Vector2(_route[i].x - pp.x, _route[i].z - pp.z).length_squared()
		if d < best:
			best = d
			bi = i
	_progress = maxf(_progress, _dist[bi])


func _once(id: StringName) -> bool:
	if _done.has(id):
		return false
	_done[id] = true
	return true


func _events(pp: Vector3) -> void:
	if not Vehicle.talk_over():
		return      # Михалыч ещё говорит — лес ждёт, чтобы его реплики не перебило
	_trail_props(pp)
	# Первое — в первые секунды: игрок должен сразу понять, что лес не пустой
	if _progress > 10.0 and _once(&"crack"):
		_event_crack()
	if _progress > 40.0 and _once(&"engine_dies"):
		_event_engine_dies()
	if _progress > 64.0 and _once(&"call"):
		_event_call(pp)
	_process_figure(pp)
	if _progress > 108.0 and _looking_ahead() and _once(&"runner"):
		_event_runner()
	elif _progress > 128.0 and _once(&"runner"):
		_event_runner()
	if Vector2(pp.x - Yard.ZIMNIK.x, pp.z - Yard.ZIMNIK.z).length() < 16.0 and _once(&"kung"):
		Game.audio.play_3d(SFX_KNOCK, Yard.ZIMNIK + Vector3(4.5, 1.2, -3.2), 2.0, 6.0)   # дверь вахтовки хлопает на ветру
	var d_izba := Vector2(pp.x - Yard.IZBA.x, pp.z - Yard.IZBA.z).length()
	if d_izba < 38.0 and _once(&"izba_on"):
		_izba_set(1.0)
	if d_izba < 16.0 and _done.has(&"izba_on") and _once(&"izba_off"):
		_izba_set(0.0)
		Game.audio.play_3d(SFX_GUST, Yard.IZBA + Vector3(0, 2, 0), -6.0)
		_think_later(&"th.izba", 1.2)
	if _progress > length_m() - 70.0 and _once(&"follower"):
		_follower = true
		_follower_t = 0.6
		_think_later(&"th.follower", 7.0)
	if Vector2(pp.x - Yard.MAST_FORK.x, pp.z - Yard.MAST_FORK.z).length() < 10.0 and _once(&"station"):
		_station_phase = 1
		_think_later(&"th.station", 1.0)
	if Vector2(pp.x - Yard.FORK.x, pp.z - Yard.FORK.z).length() < 6.0 and _once(&"window"):
		_event_window()
	if Vector2(pp.x - 16.8, pp.z - 3.5).length() < 4.0 and _once(&"porch"):
		Game.audio.play_3d(SFX_DOOR, Vector3(15.0, 1.2, 3.5), -4.0)
		_think_later(&"th.door", 1.4)
	if _done.has(&"porch") and Game.is_home() and _once(&"own_voice"):
		_event_own_voice()


## Вещи на обочине (LifeDressing.TRAIL_PROPS): у каждой — свой звук и короткая мысль (без озвучки).
func _trail_props(pp: Vector3) -> void:
	if Time.get_ticks_msec() - _prop_said_ms < 5000:
		return      # две вещи подряд (прошёл обе, пока Михалыч договаривал) — мысли по очереди, не внахлёст
	for i in LifeDressing.TRAIL_PROPS.size():
		var id: String = LifeDressing.TRAIL_PROPS[i][0]
		var pos: Vector3 = LifeDressing.trail_prop(i)[0]
		var d := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		var at: float = LifeDressing.TRAIL_PROPS[i][1]
		if at < 0.0:
			at += length_m()
		# Прошёл мимо, пока Михалыч договаривал (события ждали) — вещь всё равно «замечена», если ещё близко
		var passed := _progress >= at and d < 24.0
		if (d > 11.0 and not passed) or not _once(StringName("prop_" + id)):
			continue
		match id:
			"trail_cross":
				Game.audio.play_3d(SFX_GUST, pos + Vector3(0, 2, 0), -8.0)
			"can_line":
				Game.audio.play_3d("res://assets/audio/clank_v4.ogg", pos + Vector3(-1.5, 1.0, 0), -6.0, 4.0)
				_clank_later(pos + Vector3(1.5, 1.0, 0), 0.7)
			"skull_stake":
				Game.audio.play_3d(SFX_RAVEN, pos + Vector3(0, 7, 0), -2.0, 10.0)
			"labaz":
				Game.audio.play_3d("res://assets/audio/tree_creak_v3.ogg", pos + Vector3(0, 2.5, 0), -2.0, 6.0)
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(StringName("th.prop_" + id)), 4.5)
		_prop_said_ms = Time.get_ticks_msec()
		return


func _clank_later(pos: Vector3, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	Game.audio.play_3d("res://assets/audio/clank_v3.ogg", pos, -8.0, 4.0)


func _looking_ahead() -> bool:
	var pd: Array = point_at(_progress + 10.0)
	var dir: Vector3 = pd[1]
	var fwd := -Game.player.camera.global_basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(dir) > 0.75


# --- События -------------------------------------------------------------------------

## Мороз рвёт ствол, с ели рядом с просекой срывается пласт снега.
func _event_crack() -> void:
	var pd: Array = point_at(_progress + 9.0)
	var p: Vector3 = pd[0]
	var dir: Vector3 = pd[1]
	var side := Vector3(-dir.z, 0, dir.x) * 5.5
	var tree_pos := Terrain.at(p + side)
	Game.audio.play_3d(SFX_RAVEN, tree_pos + Vector3(-6, 8, -4), -6.0, 10.0)
	await get_tree().create_timer(1.6, false).timeout
	Game.audio.play_3d(SFX_CREAK, tree_pos + Vector3(0, 3, 0), 2.0, 8.0)
	await get_tree().create_timer(0.5, false).timeout
	if not is_inside_tree():
		return
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 70
	burst.lifetime = 2.2
	burst.explosiveness = 0.75
	burst.direction = Vector3(-side.x, -0.4, -side.z).normalized()
	burst.spread = 35.0
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -6.5, 0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 1.2
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.4
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.18)
	burst.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.8)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	burst.material_override = m
	add_child(burst)
	burst.global_position = tree_pos + Vector3(0, 4.5, 0)
	burst.emitting = true
	Game.audio.play_3d(SFX_SNOW, tree_pos + Vector3(0, 2, 0), 0.0, 6.0)
	get_tree().create_timer(4.0, false).timeout.connect(burst.queue_free)
	await get_tree().create_timer(1.6, false).timeout
	_think(&"th.crack")


## Дизель Михалыча за спиной глохнет сам. Тишина — и из темноты сзади, оттуда, где тягач, шёпот: «Ви-тя».
func _event_engine_dies() -> void:
	Vehicle.engine_die()
	await get_tree().create_timer(3.2, false).timeout
	if not is_inside_tree() or Game.player == null:
		return
	var back := Game.player.global_position + Game.player.global_basis.z.normalized() * 10.0 + Vector3(0, 1.4, 0)
	Game.audio.play_3d("res://assets/audio/whisper.ogg", back, -2.0, 10.0)
	Game.hud.subtitle(Loc.t(&"pro.call_name"), 3.0)
	Director.add_tension(10.0, "пролог: тягач заглох, зовут по имени")
	_think_later(&"th.engine", 3.2)


## Свист из чащи слева, два раза; на второй — уже ближе и чуть позади. Зовут по имени, если остановиться.
func _event_call(pp: Vector3) -> void:
	var pt: Array = point_at(_progress + 6.0)
	var fwd: Vector3 = pt[1]
	var left := Vector3(fwd.z, 0, -fwd.x)
	Game.audio.play_3d(SFX_WHISTLE, pp + left * 28.0 + fwd * 10.0 + Vector3(0, 2, 0), -4.0, 16.0)
	await get_tree().create_timer(4.5, false).timeout
	if not is_inside_tree() or Game.player == null:
		return
	var p := Game.player.global_position
	Game.audio.play_3d(SFX_WHISTLE, p + left * 16.0 - fwd * 4.0 + Vector3(0, 1.6, 0), -1.0, 14.0)
	_think(&"th.call")
	await get_tree().create_timer(3.0, false).timeout
	if is_inside_tree() and Game.player != null and Game.player.velocity.length() < 0.3:
		Game.audio.play_3d("res://assets/audio/whisper.ogg", Game.player.global_position + left * 9.0, -6.0, 8.0)
		Game.hud.subtitle(Loc.t(&"pro.call_name"), 3.0)


## Дом пуст, а рация в рубке говорит его голосом то, что он ещё не передавал.
func _event_own_voice() -> void:
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree() or Game.radio == null:
		return
	Game.radio.play_transmission(Voice.or_fallback(&"v_radio_prologue_v1", "res://assets/audio/voice_mainland.ogg"), -2.0, Radio.Pass.FAKE)
	Game.hud.subtitle(Loc.t(&"pro.own_voice"), 5.5)
	Director.add_tension(8.0, "рация говорит голосом Виктора")
	await get_tree().create_timer(5.6, false).timeout
	if not is_inside_tree() or Game.radio == null:
		return
	Game.radio.stop_transmission()
	Game.audio.play_2d("res://assets/audio/static_loop.ogg", -8.0, 1.2)
	_think(&"th.own_voice")


## Впереди, в луче, кто-то перебегает просеку слева направо — близко, слышно дыхание. Быстро, пригнувшись.
func _event_runner() -> void:
	var pd: Array = point_at(_progress + 14.0)
	var p: Vector3 = pd[0]
	var dir: Vector3 = pd[1]
	var side := Vector3(-dir.z, 0, dir.x)
	var from := Terrain.at(p - side * 8.0)
	var to := Terrain.at(p + side * 8.0)
	Game.audio.play_3d("res://assets/sfx/breath_close.ogg", p + Vector3(0, 1.5, 0), 0.0, 10.0)
	Game.audio.play_3d("res://assets/sfx/snow_steps_run.ogg", p, -2.0, 12.0)
	if Game.player != null:
		Game.player.shake(0.03, 0.4)
	_runner = Creatures.make_silhouette()
	add_child(_runner)
	_runner.global_position = from
	_runner.gait = 1.0
	_runner.gait_speed = 14.0
	_runner.look_at(Vector3(to.x, from.y, to.z), Vector3.UP)
	var t := 0.0
	while t < 1.3 and is_inside_tree():
		t += get_process_delta_time()
		var q := from.lerp(to, t / 1.3)
		q.y = Terrain.height(q.x, q.z)
		_runner.global_position = q
		await get_tree().process_frame
	if is_instance_valid(_runner):
		_runner.queue_free()
	Game.audio.play_snow_steps(to, 2, -4.0, 6.0, 0.9)
	await get_tree().create_timer(0.8, false).timeout
	_think(&"th.runner")
	await get_tree().create_timer(1.6, false).timeout
	if is_inside_tree() and Game.player != null:
		var back := Game.player.global_position - dir * 35.0 + side * 18.0
		Game.audio.play_3d(SFX_WHISTLE, back + Vector3(0, 3, 0), -8.0, 14.0)


## Окно станции: в свете на миг — силуэт человека, и пусто.
func _event_window() -> void:
	if _silhouette == null:
		return
	_silhouette.visible = true
	await get_tree().create_timer(0.7, false).timeout
	if is_instance_valid(_silhouette):
		_silhouette.visible = false


## Шаги позади: только пока идёшь. Остановился — и они стоят.
func _process_follower(pp: Vector3, delta: float) -> void:
	if not _follower:
		return
	if Vector2(pp.x - 16.8, pp.z - 3.5).length() < 9.0:
		_follower = false
		return
	if Game.player.velocity.length() > 0.4:
		_follower_t -= delta
		if _follower_t <= 0.0:
			_follower_t = randf_range(0.62, 0.8)
			var behind := pp + Game.player.global_basis.z.normalized() * randf_range(6.0, 7.5)
			Game.audio.play_snow_steps(Terrain.at(behind), 1, -3.0, 5.0, 0.74)
	else:
		_follower_t = 0.9   # замер — и сзади тишина; пошёл — шаги не сразу


func _process_station_light(delta: float) -> void:
	if _station_light == null or _station_phase == 0:
		return
	_station_t += delta
	match _station_phase:
		1:
			_station_light.light_energy = 1.2
			if _station_t > 2.4:
				_station_phase = 2
				_station_t = 0.0
		2:
			_station_light.light_energy = 0.0
			if _station_t > 1.4:
				_station_phase = 3
		3:
			_station_light.light_energy = 1.0


## Ушёл далеко от леера: снег по пояс, тянет обратно, холод.
func _process_boundary(pp: Vector3, delta: float) -> void:
	var near: Vector3 = _route[0]
	var best := 1e9
	for p in _route:
		var d := Vector2(p.x - pp.x, p.z - pp.z).length_squared()
		if d < best:
			best = d
			near = p
	var dist := sqrt(best)
	Game.set_flag("in_deep_snow", dist > 4.5)
	if dist > 4.5 and not _deep_warned:
		_deep_warned = true
		Game.hud.subtitle(Loc.t(&"sub.deep_snow_warning"), 3.5)
	if dist > 22.0:
		var to := near - pp
		to.y = 0.0
		Game.player.velocity += to.normalized() * delta * 4.0
		Game.warmth = maxf(Game.warmth - delta * 1.2, 5.0)
		_wall_t -= delta
		if _wall_t <= 0.0:
			_wall_t = 6.0
			Game.hud.subtitle(Loc.t(&"sub.blizzard_wall"), 3.5)


func on_vehicle_left() -> void:
	_vehicle_left = true
	await get_tree().create_timer(6.0, false).timeout
	if is_inside_tree():
		Game.hud.subtitle(Loc.t(&"trail.alone"), 4.5)
	_think_later(&"th.alone", 5.0)


## Мысли Виктора — озвученные реплики «про себя» (v_th_*), субтитр в скобках.
func _think(key: StringName) -> void:
	if Game.hud != null and is_inside_tree():
		Voice.say(key, 3.5)


func _think_later(key: StringName, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if is_inside_tree():
		_think(key)


# --- Постройка -----------------------------------------------------------------------

## Нарты Семёнова у обочины — перевёрнуты, рядом рюкзак. Записка — под ремнём.
func _build_sled() -> void:
	var pd: Array = point_at(70.0)
	var p: Vector3 = pd[0]
	var dir: Vector3 = pd[1]
	var pos := Terrain.at(p + Vector3(-dir.z, 0, dir.x) * 3.4)
	var sled := Props.sled_semenov()
	sled.position = pos
	sled.rotation = Vector3(0, atan2(dir.x, dir.z) + 0.5, deg_to_rad(12.0))
	add_child(sled)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.88, 0.72)
	glow.light_energy = 0.35
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	glow.position = pos + Vector3(0, 0.8, 0)
	add_child(glow)
	var it := Geo.interactable(self, Vector3(1.4, 1.2, 1.6), pos + Vector3(0, 0.5, 0), null, Loc.t(&"trail.sled_interact"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"trail.sled_note"))
		Game.player.mode = Player.Mode.READING
		if not _sled_read:
			_sled_read = true
			Game.complete_step(&"sled_note")
			_after_note())
	it.name = "SemyonovSled"


func _after_note() -> void:
	while is_inside_tree() and Game.hud != null and Game.hud.is_note_open():
		await get_tree().process_frame
	_think_later(&"th.sled", 0.6)
	await get_tree().create_timer(5.0, false).timeout
	if is_inside_tree() and Game.player != null:
		var behind := Game.player.global_position + Game.player.global_basis.z * 30.0
		Game.audio.play_3d(SFX_GUST, behind + Vector3(0, 3, 0), -2.0, 12.0)


## Человек между елей сбоку от просеки: стоит неподвижно на краю луча. Посветишь прямо — его нет,
## только снег осыпается с лапы и в стороне хрустят шаги. Не посмотрел — исчезает, когда проходишь мимо.
func _build_figure() -> void:
	var pd: Array = point_at(86.0)
	var p: Vector3 = pd[0]
	var dir: Vector3 = pd[1]
	var side := Vector3(dir.z, 0, -dir.x)
	_figure = Creatures.make_silhouette()
	add_child(_figure)
	_figure.global_position = Terrain.at(p + side * 9.0 + dir * 6.0)
	_figure.look_at(Vector3(p.x, _figure.global_position.y, p.z), Vector3.UP)
	_figure.visible = false


func _process_figure(pp: Vector3) -> void:
	if _figure == null or not is_instance_valid(_figure):
		return
	if not _figure.visible:
		if _progress > 72.0 and not _done.has(&"figure"):
			_figure.visible = true
		return
	var fp := _figure.global_position
	var d := Vector2(pp.x - fp.x, pp.z - fp.z).length()
	var lit := Game.player.flashlight != null and Game.player.flashlight.visible
	if lit and d < 30.0 and Game.player.is_looking_at(fp + Vector3(0, 1.4, 0), 9.0):
		_figure_seen += get_process_delta_time()
	if _figure_seen > 0.35 or _progress > 100.0:
		_done[&"figure"] = true
		_figure.queue_free()
		_figure = null
		if _figure_seen > 0.35:
			Game.audio.play_3d(SFX_SNOW, fp + Vector3(0, 2.5, 0), -2.0, 8.0)
			Game.audio.play_snow_steps(fp + Vector3(3, 0, -2), 3, -4.0, 8.0, 0.5)
			Director.add_tension(8.0, "пролог: человек между елей")
			_think_later(&"th.figure", 0.8)


## Свет в окне избы: зажигается издалека, гаснет, когда подходишь.
func _build_izba_light() -> void:
	_izba_light = OmniLight3D.new()
	_izba_light.light_color = Color(1.0, 0.68, 0.3)
	_izba_light.light_energy = 0.0
	_izba_light.omni_range = 7.0
	_izba_light.shadow_enabled = false
	add_child(_izba_light)
	_izba_light.global_position = Yard.IZBA + Vector3(-0.65, 1.5, 3.8)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1.0, 0.62, 0.26, 0.0)
	_izba_glow = Geo.box_mesh(Vector3(0.8, 0.9, 0.02), gm)
	add_child(_izba_glow)
	_izba_glow.global_position = Yard.IZBA + Vector3(-0.65, 1.5, 3.03)


func _izba_set(v: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_izba_light, "light_energy", 1.4 * v, 0.6 if v > 0.0 else 0.25)
	var m := _izba_glow.material_override as StandardMaterial3D
	tw.tween_property(m, "albedo_color:a", 0.95 * v, 0.6 if v > 0.0 else 0.25)


func _build_station_light() -> void:
	_station_light = OmniLight3D.new()
	_station_light.light_energy = 0.0
	_station_light.light_color = Color(1.0, 0.86, 0.6)
	_station_light.omni_range = 14.0
	_station_light.shadow_enabled = false
	_station_light.position = Vector3(14.0, 2.2, 3.5)
	add_child(_station_light)
	_silhouette = Node3D.new()
	_silhouette.position = Vector3(13.6, 1.55, 1.2)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.03, 0.03, 0.04)
	var head := Geo.box_mesh(Vector3(0.2, 0.24, 0.2), sm)
	head.position = Vector3(0, 0.42, 0)
	_silhouette.add_child(head)
	_silhouette.add_child(Geo.box_mesh(Vector3(0.46, 0.6, 0.22), sm))
	_silhouette.visible = false
	add_child(_silhouette)


func _build_porch_log() -> void:
	var lg := Geo.cylinder(self, 0.08, 0.55, Vector3(16.5, 0.05, 3.5), Palette.m(&"bark"), false)
	lg.name = "PorchLog"
	lg.rotation = Vector3(0, deg_to_rad(25.0), deg_to_rad(85.0))


## Свежие босые следы поперёк тропы — из леса в лес, между избой и мачтой.
func _build_bare_tracks() -> void:
	var a := Vector3(4, 0, -34)
	var b := Vector3(-2, 0, -17)
	Footprints.trail(self, &"bare", PackedVector3Array([a, Vector3(2, 0, -26.5), b]), 0.0, 0.66)


## Брошенный на тропе груз (старый API игрока: в этом прологе рундука в руках нет).
func spawn_trunk_pickup(_pos: Vector3) -> Node3D:
	return null
