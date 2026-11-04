class_name Ambience
extends Node
## Живой звук станции (CC0-записи из assets/sfx/cc0, нарезка — tools/make.py):
##   • ветер слоями: вой метели и гул проводов снаружи, глухой ветер в стенах — внутри;
##   • точечные петли: треск печи, жужжание лампочек, гул аппаратуры и дизеля, скрип анемометра,
##     хлопанье флажков леера, гудение мачты, свист в щели входной двери;
##   • редкие события: вой в трубе, дребезг стёкол, щелчки сруба на морозе, скрип половиц, капель,
##     треск деревьев в лесу, снег с лап, далёкий самолёт и непонятный гул, вороны днём.
## Между событиями — настоящие паузы: тишина тоже звук (как в Voices of the Void).

const D := "res://assets/sfx/cc0/"

var _st: Station
var _blizzard: AudioStreamPlayer
var _gusts: AudioStreamPlayer
var _indoor: AudioStreamPlayer
var _spots: Array = []          ## [AudioStreamPlayer3D, Callable условие, громкость дБ, зависит от ветра]
var _event_t := 25.0
var _plane_t := 240.0
var _drone_t := 400.0
var _streams: Dictionary = {}


func setup(st: Station) -> void:
	_st = st


func _ready() -> void:
	# Короткая петля бурана со свистом убрана: её «поющий» свист на повторе слышался как шёпот «спи… спи…».
	_blizzard = _loop2d("wind_indoor_loop_b", &"Weather")
	_gusts = _loop2d("wire_gust_loop", &"Weather")
	_indoor = _loop2d("wind_indoor_loop", &"Ambient")
	# Точечные петли
	for p: Vector3 in [Vector3(0.5, 2.5, 3.3), Vector3(7.5, 2.5, 0.1), Vector3(7.5, 2.5, 4.4), Vector3(13.0, 2.5, 3.5)]:
		_spot("bulb_buzz_loop", p, 1.2, 5.0, -24.0, func() -> bool: return _st != null and _st.lights_lit())
	_spot("radio_hum_loop", Vector3(9.2, 1.0, -1.4), 1.6, 7.0, -20.0, func() -> bool: return Game.power_on)
	_spot("elec_buzz_loop", Vector3(14.5, 1.2, -13.6), 2.2, 12.0, -22.0, func() -> bool: return Game.power_on and not Game.gen_broken)
	_spot("wind_whistle_loop", Vector3(14.55, 1.4, 3.1), 2.0, 8.0, -18.0, func() -> bool: return _storm() > 0.25)
	_spot("anemometer_squeak_loop", Yard.METEO + Yard.M_VANE + Vector3(0, 2.6, 0), 3.0, 28.0, -17.0, func() -> bool: return true)
	_spot("pole_hum_loop", Yard.MAST + Vector3(0, 6.0, 0), 5.0, 35.0, -15.0, func() -> bool: return true)
	for p: Vector3 in [Vector3(16.9, 1.1, 0.2), Vector3(16.5, 1.1, -6.5)]:
		_spot("flag_flap_loop", p, 2.0, 14.0, -19.0, func() -> bool: return _storm() > 0.1 or Game.is_night())


func _process(delta: float) -> void:
	if Game.player == null:
		return
	var inside := Game.is_indoors()
	var storm := _storm()
	var hush := _hushed()
	var k := minf(delta * 2.0, 1.0)
	# Ветер слоями. Шина Weather сама глушит верха в доме — здесь только балансировка громкости.
	var bz := (-22.0 + storm * 5.0) if inside else lerpf(-30.0, -14.0, storm)
	var gs := -44.0 if inside else (-28.0 if Game.is_night() else -32.0) + storm * 5.0
	var ind := lerpf(-34.0, -16.0, storm) if inside else -80.0
	if hush:
		bz = -80.0
		gs = -80.0
		ind = -80.0
	_blizzard.volume_db = lerpf(_blizzard.volume_db, bz, k)
	_gusts.volume_db = lerpf(_gusts.volume_db, gs, k)
	_indoor.volume_db = lerpf(_indoor.volume_db, ind, k)
	_blizzard.pitch_scale = 0.9 + storm * 0.2
	# Точечные петли: звучат, пока выполнено условие; молчащие — выключены (не грузят микшер)
	for s: Array in _spots:
		var p: AudioStreamPlayer3D = s[0]
		var on: bool = (s[1] as Callable).call() and not hush
		var target: float = s[2] if on else -80.0
		if s[3]:      # флажки и анемометр — от ветра
			target += storm * 6.0 - 3.0
			p.pitch_scale = 0.85 + storm * 0.35
		p.volume_db = lerpf(p.volume_db, target, k)
		if p.volume_db < -70.0 and p.playing:
			p.stop()
		elif p.volume_db >= -70.0 and not p.playing:
			p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))
		elif on and not p.playing:
			p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))
	if hush:
		return
	_event_t -= delta * (1.0 + storm * 0.8)
	if _event_t <= 0.0:
		_event_t = randf_range(16.0, 42.0)
		_event(inside, storm)
	_plane_t -= delta
	if _plane_t <= 0.0:
		_plane_t = randf_range(420.0, 900.0)
		var pl := play_far("plane_far" if randf() < 0.6 else "plane_far_2", 260.0, -14.0 if not inside else -24.0)
		if pl != null:
			pl.unit_size = 80.0
	_drone_t -= delta
	if _drone_t <= 0.0:
		_drone_t = randf_range(500.0, 1100.0)
		if Game.is_night():
			play_far("drone_far", 120.0, -8.0 if not inside else -16.0)


## Одно событие из пула — по месту (дом/улица), времени суток и погоде.
func _event(inside: bool, storm: float) -> void:
	var pool: Array = []
	if inside and Game.is_home():
		pool.append(["floor_creak", 2.0])
		pool.append(["drip", 1.2])
		if Game.is_night():
			pool.append(["log_frost_crack", 1.8])
		if storm > 0.2:
			pool.append(["chimney_howl", 1.0 + storm * 2.0])
		if storm > 0.3:
			pool.append(["window_rattle", 1.0 + storm * 2.0])
		if storm > 0.5:
			pool.append(["door_rattle", 0.8])
	elif not inside:
		pool.append(["branch_snow_drop", 1.5])
		if Game.is_night():
			pool.append(["tree_frost_crack", 2.0])
		else:
			pool.append(["crow_caw", 2.2])
			pool.append(["tree_frost_crack", 1.8])
	else:
		pool.append(["log_frost_crack", 1.0])
	if pool.is_empty():
		return
	var total := 0.0
	for e: Array in pool:
		total += float(e[1])
	var pick := randf() * total
	var id: String = pool[0][0]
	for e: Array in pool:
		pick -= float(e[1])
		if pick <= 0.0:
			id = e[0]
			break
	var pp := Game.player.global_position
	match id:
		"floor_creak":
			_one(_variant("floor_creak", 2), _house_point(), -12.0, 3.0)
		"drip":
			var dp := Vector3(11.9, 0.9, 6.3)
			for i in randi_range(2, 5):
				get_tree().create_timer(float(i) * randf_range(0.9, 1.6), false).timeout.connect(func() -> void: _one(_variant("drip", 5), dp, -16.0, 1.5))
		"log_frost_crack":
			_one(_variant("log_frost_crack", 5), _house_point() + Vector3(0, 1.2, 0), -12.0, 4.0)
		"chimney_howl":
			_one(_variant("chimney_howl", 3), Vector3(-1.5, 2.3, 1.0), -11.0, 5.0)
		"window_rattle":
			var w: Dictionary = _st.window_spots.pick_random() if _st != null and not _st.window_spots.is_empty() else {"glass": pp}
			_one(_variant("window_rattle", 4), w["glass"], -11.0, 3.0)
		"door_rattle":
			_one(_variant("door_rattle", 3), Vector3(14.55, 1.3, 3.1), -11.0, 3.0)
		"branch_snow_drop":
			var bp := pp + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(9.0, 16.0)
			_one(_variant("branch_snow_drop", 3), bp + Vector3(0, 3.0, 0), -8.0, 5.0)
			if Game.audio != null:
				Game.audio.call(&"_snow_puff", bp)
		"tree_frost_crack":
			play_far("tree_frost_crack", randf_range(25.0, 55.0), -2.0)
		"crow_caw":
			play_far("crow_caw_%d" % randi_range(1, 5), randf_range(18.0, 40.0), -4.0)


## Звук далеко от игрока в случайном направлении.
func play_far(id: String, dist: float, vol: float) -> AudioStreamPlayer3D:
	if Game.player == null:
		return null
	var pos := Game.player.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * dist + Vector3(0, 4.0, 0)
	return _one(D + id + ".ogg", pos, vol, maxf(dist * 0.4, 4.0))


func _one(path: String, pos: Vector3, vol: float, unit: float) -> AudioStreamPlayer3D:
	if Game.audio == null:
		return null
	var p: AudioStreamPlayer3D = Game.audio.play_3d(path, pos, vol, unit)
	if p != null:
		p.pitch_scale = randf_range(0.93, 1.07)
		if p.stream != null and p.stream.get_length() > 20.0:
			p.set_meta(&"long_ok", true)   # самолёт, дальний гул — длинные, но конечные
	return p


func _variant(base: String, n: int) -> String:
	var idx := randi_range(1, n)
	var path_num := D + "%s_%d.ogg" % [base, idx]
	if ResourceLoader.exists(path_num):
		return path_num
	var path_v := D + ("%s.ogg" % base if idx == 1 else "%s_v%d.ogg" % [base, idx])
	if ResourceLoader.exists(path_v):
		return path_v
	return D + "%s.ogg" % base


## Случайная точка в доме — откуда «скрипнуло».
func _house_point() -> Vector3:
	var pts := [Vector3(0.5, 0.1, 3.0), Vector3(-1.5, 0.1, 5.0), Vector3(7.5, 0.1, 0.0), Vector3(6.0, 0.1, 4.5),
		Vector3(5.2, 0.1, -3.8), Vector3(13.0, 0.1, 4.0), Vector3(5.0, 3.1, 3.3)]
	return pts.pick_random()


func _storm() -> float:
	return Game.weather.intensity if Game.weather != null else 0.0


## Испуги просят тишины — вместе с ними замолкаем и мы.
func _hushed() -> bool:
	if Game.audio == null:
		return false
	return bool(Game.audio.get(&"_silenced")) or float(Game.audio.get(&"_vacuum_timer")) > 0.0


func _loop2d(id: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _loop_stream(id)
	p.set_meta(&"src", id)
	p.volume_db = -80.0
	p.bus = bus
	add_child(p)
	p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))
	return p


func _spot(id: String, pos: Vector3, unit: float, max_d: float, vol: float, cond: Callable) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _loop_stream(id)
	p.set_meta(&"src", id)
	p.unit_size = unit
	p.max_distance = max_d
	p.volume_db = -80.0
	p.bus = &"SFX"
	p.position = pos
	add_child(p)
	_spots.append([p, cond, vol, id == "flag_flap_loop" or id == "anemometer_squeak_loop"])


func _loop_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var s := load(D + id + ".ogg") as AudioStream
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		(s as AudioStreamOggVorbis).loop = true
	_streams[id] = s
	return s
