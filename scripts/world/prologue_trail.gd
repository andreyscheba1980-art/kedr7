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
var _station_light: OmniLight3D
var _station_phase := 0
var _station_t := 0.0
var _silhouette: Node3D
var _sled_read := false
var _wall_t := 0.0
var _deep_warned := false
var _prop_said_ms := -100000
var _lost_t := 0.0


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
	_build_stakes()
	_build_station_light()
	_build_porch_log()


func _process(delta: float) -> void:
	if not Game.is_prologue() or Game.has_flag("prologue_arrived") or Game.player == null:
		return
	if Game.has_flag("in_cabin"):
		return
	var pp := Game.player.global_position
	_update_progress(pp)
	_events(pp)
	_process_station_light(delta)
	_process_fail_safe(pp, delta)
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

	# Одиночная глубинная аномалия на середине пути:
	# вакуум тишины на 3 секунды, единственный запаздывающий шаг в снегу за спиной
	if _progress > length_m() * 0.45 and _once(&"vacuum_step"):
		_event_vacuum_step()

	if Vector2(pp.x - Yard.MAST_FORK.x, pp.z - Yard.MAST_FORK.z).length() < 10.0 and _once(&"station"):
		_station_phase = 1
		_think_later(&"th.station", 1.0)

	if Vector2(pp.x - 16.8, pp.z - 3.5).length() < 4.0 and _once(&"porch"):
		Game.audio.play_3d(SFX_DOOR, Vector3(15.0, 1.2, 3.5), -4.0)
		_think_later(&"th.door", 1.4)


## Одиночная глубинная аномалия тропы:
## Штиль — вой ветра мгновенно затихает до звона в ушах.
## Секунда тишины — и за спиной один чёткий хруст наста, опоздавший на шаг.
func _event_vacuum_step() -> void:
	AudioDirector.play_raw("res://assets/audio/sub_drop.ogg", -4.0)
	AudioMix.set_indoor(1.0)
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree() or Game.player == null:
		AudioMix.set_indoor(0.0)
		return
	var behind := Game.player.global_position - Game.player.global_basis.z.normalized() * 5.0
	behind.y = Terrain.height(behind.x, behind.z)
	Game.audio.play_snow_steps(behind, 1, -2.0, 8.0, 0.8)
	if Game.player != null:
		Game.player.shake(0.02, 0.2)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"th.trail_delayed_step"), 4.0)
	Attention.add(3.0)
	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree():
		return
	AudioDirector.play_raw("res://assets/audio/gust.ogg", -2.0)
	AudioMix.set_indoor(0.0)


func _distance_to_route(pp: Vector3) -> float:
	var best := 1e9
	for p in _route:
		var d := Vector2(p.x - pp.x, p.z - pp.z).length_squared()
		if d < best:
			best = d
	return sqrt(best)


## Мягкая страховка: если игрок заплутал в буране далеко от вешек,
## даём кратковременный просвет (маяк на мачте), чтобы он нашёл дорогу.
func _process_fail_safe(pp: Vector3, delta: float) -> void:
	var dist := _distance_to_route(pp)
	if dist > 14.0:
		_lost_t += delta
		if _lost_t > 14.0:
			_lost_t = 0.0
			Storm.force_gap(4.0)
	else:
		_lost_t = maxf(_lost_t - delta * 2.0, 0.0)


## Вещи на обочине (LifeDressing.TRAIL_PROPS): у каждой — свой звук и короткая мысль (без озвучки).
func _trail_props(pp: Vector3) -> void:
	if Time.get_ticks_msec() - _prop_said_ms < 5000:
		return      # две вещи подряд — мысли по очереди, не внахлёст
	for i in LifeDressing.TRAIL_PROPS.size():
		var id: String = LifeDressing.TRAIL_PROPS[i][0]
		var pos: Vector3 = LifeDressing.trail_prop(i)[0]
		var d := Vector2(pp.x - pos.x, pp.z - pos.z).length()
		var at: float = LifeDressing.TRAIL_PROPS[i][1]
		if at < 0.0:
			at += length_m()
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


## Деревянные вешки с выцветшими красными лоскутами каждые 14 м вдоль тропы
func _build_stakes() -> void:
	var total := length_m()
	var s := 14.0
	var idx := 0
	while s < total - 12.0:
		var pd: Array = point_at(s)
		var p: Vector3 = pd[0]
		var d: Vector3 = pd[1]
		var side := Vector3(-d.z, 0, d.x) * (1.3 if idx % 2 == 0 else -1.3)
		var at := Terrain.at(p + side)
		var pole := Geo.cylinder(self, 0.035, 1.8, at + Vector3(0, 0.9, 0), Palette.m(&"bark"), false)
		pole.name = "TrailStake_%d" % idx
		pole.rotation.z = deg_to_rad(randf_range(-3.0, 3.0))
		pole.rotation.x = deg_to_rad(randf_range(-3.0, 3.0))
		var rag := Geo.box_mesh(Vector3(0.18, 0.28, 0.02), Palette.m(&"roof"))
		rag.position = at + Vector3(side.x * 0.08, 1.62, side.z * 0.08)
		rag.rotation = Vector3(deg_to_rad(15.0), atan2(d.x, d.z) + deg_to_rad(20.0), deg_to_rad(10.0))
		add_child(rag)
		s += 14.0
		idx += 1


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


## Брошенный на тропе груз (старый API игрока: в этом прологе рундука в руках нет).
func spawn_trunk_pickup(_pos: Vector3) -> Node3D:
	return null
