class_name AudioDirector
extends Node
## Фоновая звуковая среда: гул трансформатора, ветер, низкий дрон и сердцебиение на пике напряжения.
## Гул «проседает» с ростом напряжения и пропадает при отключении питания или по команде испуга —
## игрок со временем начинает бояться самой тишины.

const HUM := "res://assets/audio/hum_loop.ogg"
const WIND := "res://assets/audio/wind_loop.ogg"
const DRONE := "res://assets/audio/drone_loop.ogg"
const HEART := "res://assets/audio/heart_loop.ogg"
const MUSIC_DAY := "res://assets/audio/music_day.ogg"
const MUSIC_NIGHT := "res://assets/audio/music_night.ogg"
const MUSIC_TENSION := "res://assets/audio/music_tension.ogg"

const DAWN_CHIME := "res://assets/audio/dawn_chime.ogg"

var _hum: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _music_day: AudioStreamPlayer
var _music_night: AudioStreamPlayer
var _music_tension: AudioStreamPlayer
var _ending_music := false
var _silenced := false
var _vacuum_timer := 0.0
var _life_t := 12.0
var _roof_steps_played_tonight := false
var _mirage_timer := 0.0
var _mirage_noise_recorded := false
var _mirage_last_pos := Vector3.ZERO
static var _stream_cache: Dictionary = {}

## Живой лес: редкие звуки вдалеке. Ночью — волки, филин; днём — вороны. Скрип елей, треск мороза и снег — всегда.
const LIFE_NIGHT := [["res://assets/audio/wolf_howl.ogg", 1.0, 70.0], ["res://assets/audio/owl.ogg", 1.5, 40.0],
	["res://assets/audio/tree_creak.ogg", 2.2, 18.0], ["res://assets/audio/snow_fall.ogg", 2.0, 9.0],
	["res://assets/sfx/cc0/tree_frost_crack.ogg", 1.8, 32.0]]
const LIFE_DAY := [["res://assets/audio/raven.ogg", 2.0, 45.0], ["res://assets/audio/tree_creak.ogg", 1.8, 18.0],
	["res://assets/audio/snow_fall.ogg", 2.0, 9.0], ["res://assets/sfx/cc0/branch_snow_drop_1.ogg", 1.5, 14.0]]


func _ready() -> void:
	Game.audio = self
	_preload_all_sounds()
	_hum = _loop(HUM)
	_wind = _loop(WIND)
	_wind.bus = &"Weather"
	_drone = _loop(DRONE)
	_heart = _loop(HEART)
	_heart.bus = &"SFX"

	_music_day = _loop(MUSIC_DAY)
	_music_night = _loop(MUSIC_NIGHT)
	_music_tension = _loop(MUSIC_TENSION)
	_music_day.bus = &"Music"
	_music_night.bus = &"Music"
	_music_tension.bus = &"Music"
	_music_day.volume_db = -80.0
	_music_night.volume_db = -80.0
	_music_tension.volume_db = -80.0
	for mp: AudioStreamPlayer in [_music_day, _music_night, _music_tension]:
		mp.stop()


func _preload_all_sounds() -> void:
	var dir := DirAccess.open("res://assets/audio")
	if dir != null:
		for file: String in dir.get_files():
			var clean := file.trim_suffix(".remap").trim_suffix(".import")
			if clean.ends_with(".ogg") or clean.ends_with(".ogg"):
				cached_stream("res://assets/audio/" + clean)


static func cached_stream(path: String) -> AudioStream:
	if not _stream_cache.has(path):
		_stream_cache[path] = _build_stream(path)
	return _stream_cache.get(path)


## Одноразовые звуки с вариантами (clank.ogg + clank_v2.ogg, _v3, …) собираются в рандомизатор:
## каждый раз другой дубль и чуть другая высота — стук, лязг и свист не повторяются слово в слово.
## Сгенерированные отдельно звуки (sfx_src → assets/sfx) подмешиваются к штатным как ещё дубли.
const SFX_ALIASES := {
	"door_knock": "knock_door", "knock": "knock_wall", "raven": "raven", "wolf_howl": "wolf_far",
	"gust": "wind_gust", "whisper": "whisper_many",
}


const ZasAudioClass = preload("res://scripts/data/zas_audio.gd")


static func _build_stream(path: String) -> AudioStream:
	if path.ends_with("voice_mainland.ogg") or path.ends_with("voice_loop.ogg"):
		var scramble := ZasAudioClass.get_scramble_stream(3.5, false)
		if scramble != null:
			return scramble
	var s := load(path) as AudioStream
	if s == null or path.contains("_v"):
		return s
	var base := path.trim_suffix(".ogg")
	var variants: Array[AudioStream] = [s]
	if path.contains("_loop") and not path.ends_with("breath_loop.ogg"):
		return s
	for i in range(2, 9):
		var vp := "%s_v%d.ogg" % [base, i]
		if not ResourceLoader.exists(vp):
			break
		var vs := load(vp) as AudioStream
		if vs != null:
			variants.append(vs)
	var alias: String = SFX_ALIASES.get(path.get_file().get_basename(), "")
	if alias != "":
		for i in range(1, 9):
			var ap := "res://assets/sfx/%s.ogg" % alias if i == 1 else "res://assets/sfx/%s_v%d.ogg" % [alias, i]
			if not ResourceLoader.exists(ap):
				break
			var as_ := load(ap) as AudioStream
			if as_ != null:
				variants.append(as_)
	if variants.size() == 1:
		return s
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	r.random_pitch = 1.05
	r.random_volume_offset_db = 1.5
	for i in range(variants.size()):
		r.add_stream(i, variants[i])
	return r


static func play_raw(path: String, vol_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if Game.audio != null:
		var p := Game.audio.play_2d(path, vol_db)
		if p != null and not is_equal_approx(pitch, 1.0):
			p.pitch_scale = pitch
		return p
	return null


func get_stream(path: String) -> AudioStream:
	return cached_stream(path)


## Звук через стены: если между ухом и источником стена — звук уходит на шину SFXMuffled (низы, тише).
## В проём двери видно источник — звук чистый. Так рация из рубки, печь и стук глуше из соседней комнаты.
const MUFFLED_BUS := &"SFXMuffled"
var _occl_t := 0.0
var _occl_scanned := false


func _ensure_muffled_bus() -> void:
	if AudioServer.get_bus_index(MUFFLED_BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, MUFFLED_BUS)
	AudioServer.set_bus_send(idx, &"SFX")
	AudioServer.set_bus_volume_db(idx, -5.0)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 650.0
	AudioServer.add_bus_effect(idx, lp, 0)


func _occlude_one(p: AudioStreamPlayer3D) -> void:
	if Game.player == null or Game.player.camera == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	if p.bus != &"SFX" and p.bus != MUFFLED_BUS:
		return   # рация, погода, музыка — свои шины, не трогаем
	var ear := Game.player.camera.global_position
	var src := p.global_position
	if ear.distance_squared_to(src) > 900.0:
		return
	var q := PhysicsRayQueryParameters3D.create(ear, src, Geo.LAYER_WORLD, [Game.player.get_rid()])
	var hit := Game.player.get_world_3d().direct_space_state.intersect_ray(q)
	# стена — это попадание заметно раньше источника (не сам предмет, на котором висит звук)
	var blocked := not hit.is_empty() and (hit["position"] as Vector3).distance_to(src) > 0.6
	p.bus = MUFFLED_BUS if blocked else &"SFX"


func _update_occlusion(delta: float) -> void:
	_occl_t -= delta
	if _occl_t > 0.0 or Game.level == null:
		return
	_occl_t = 0.3
	_ensure_muffled_bus()
	if not _occl_scanned:
		# Один раз — постоянные источники уровня (печь, лампы, рация), созданные до нас
		_occl_scanned = true
		for n: Node in Game.level.find_children("*", "AudioStreamPlayer3D", true, false):
			n.add_to_group(&"occludable")
	for n: Node in get_tree().get_nodes_in_group(&"occludable"):
		var p := n as AudioStreamPlayer3D
		if p != null and p.playing:
			_occlude_one(p)


func _process(delta: float) -> void:
	_check_leaks(delta)
	_update_occlusion(delta)
	if _vacuum_timer > 0.0:
		_vacuum_timer -= delta

	var t := Director.tension / 100.0
	var inside := Game.is_indoors()
	var storm := Game.weather.intensity if Game.weather != null else 0.0

	var hum_target := -18.0 if Game.is_home() else -38.0
	if _silenced or not Game.power_on:
		hum_target = -80.0
	_hum.volume_db = lerpf(_hum.volume_db, hum_target, minf(delta * 4.0, 1.0))
	_hum.pitch_scale = lerpf(_hum.pitch_scale, 1.0 - t * 0.07, minf(delta, 1.0))

	# Звуковая окклюзия метели (Low-Pass Filter на шине Weather):
	# На улице — звонкий, ледяной свист бурана (20 кГц).
	# В доме при закрытой двери — глухой, низкий гул в стенах и трубе (360 Гц).
	var w_bus := AudioServer.get_bus_index(&"Weather")
	if w_bus >= 0 and AudioServer.get_bus_effect_count(w_bus) > 0:
		var lp := AudioServer.get_bus_effect(w_bus, 0) as AudioEffectLowPassFilter
		if lp != null:
			var target_cutoff := 20000.0
			if inside:
				var door_open: bool = Game.level != null and Game.level.has_method(&"is_door_open") and bool(Game.level.call(&"is_door_open"))
				target_cutoff = 2200.0 if door_open else 360.0
			lp.cutoff_hz = lerpf(lp.cutoff_hz, target_cutoff, minf(delta * 5.0, 1.0))

	var door_open_now: bool = inside and Game.level != null and Game.level.has_method(&"is_door_open") and bool(Game.level.call(&"is_door_open"))
	# Мастеринг громкости бурана:
	# Снаружи: от -16.0 дБ (тихий полярный бриз) до -8.0 дБ (лютый ураганный буран) — не перегружает шину и оставляет запас для шагов.
	# Внутри: -25.0 дБ при закрытой двери (глухой низкий рокот в стенах); при открытии двери врывается снежный вихрь (-15 дБ).
	var wind_base := (-25.0 + storm * 3.5 + (10.0 if door_open_now else 0.0)) if inside else (-16.0 + storm * 8.0)
	var wind_target := wind_base + t * 1.5
	if _silenced or _vacuum_timer > 0.0:
		wind_target = -75.0   # зловещая тишина перед атакой или скримером
	_wind.volume_db = lerpf(_wind.volume_db, wind_target, minf(delta * 3.0, 1.0))
	_wind.pitch_scale = lerpf(_wind.pitch_scale, 0.95 + storm * 0.25 + sin(Time.get_ticks_msec() * 0.0004) * 0.04, minf(delta, 1.0))

	# Дрон: низкий психоакустический гул в голове.
	# На улице отключён (там царит только естественный буран и тайга).
	# В доме плавно проявляется только при сильном страхе (напряжение > 65%).
	var drone_target := -80.0
	if Game.is_night() and Game.is_home() and t > 0.65:
		drone_target = lerpf(-36.0, -16.0, (t - 0.65) / 0.35)
		if _silenced:
			drone_target = -8.0   # зловещая тишина перед атакой
	_drone.volume_db = lerpf(_drone.volume_db, drone_target, minf(delta * 1.5, 1.0))

	# Музыка в доме: тихая, приятная и тёплая (-25 дБ, уют в избе у печи).
	# На улице музыка полностью замолкает (-80 дБ) — снаружи остаётся только метель.
	# Тревожная музыка нагнетания полностью отключена (_music_tension = -80 дБ).
	# Музыка в игре — только в меню и концовках. В доме и на улице — живые звуки станции.
	var house_music_target := -80.0

	var night_target := house_music_target if Game.is_night() else -80.0
	var day_target := house_music_target if not Game.is_night() else -80.0

	if not _ending_music:
		_music_night.volume_db = lerpf(_music_night.volume_db, night_target, minf(delta * 2.0, 1.0))
		_music_day.volume_db = lerpf(_music_day.volume_db, day_target, minf(delta * 2.0, 1.0))
	_music_tension.volume_db = -80.0

	# Сердце: с 55 напряжения, во время погони и на морозе.
	var chase := Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE
	var heart := clampf((t - 0.55) / 0.45, 0.0, 1.0)
	if chase:
		heart = 1.0
	_heart.volume_db = lerpf(_heart.volume_db, linear_to_db(maxf(heart, 0.0001)) - 2.0, minf(delta * 2.0, 1.0))
	_heart.pitch_scale = 1.0 + heart * 0.35
	_update_life(delta)
	_process_mirage(delta)

	# Шаги по крыше станции (01:30 - 04:00 при нахождении дома)
	# Ночь 2 — своя большая сцена с шагами по крыше (NightEvents), здесь её не дублируем.
	if Game.is_night() and Game.night >= 3 and Game.is_indoors() and not _roof_steps_played_tonight:
		if Game.shift_minutes >= 330 and Game.shift_minutes <= 480 and Director.tension < 40.0:
			_roof_steps_played_tonight = true
			play_roof_steps()


## Акустический мираж тайги: эхо действий игрока из глухого леса
func record_player_noise(pos: Vector3) -> void:
	if not _mirage_noise_recorded and Game.is_outside() and Game.is_night():
		_mirage_noise_recorded = true
		_mirage_timer = randf_range(25.0, 45.0)
		_mirage_last_pos = pos


func _process_mirage(delta: float) -> void:
	if not _mirage_noise_recorded:
		return
	_mirage_timer -= delta
	if _mirage_timer <= 0.0:
		_mirage_noise_recorded = false
		if Game.is_outside() and Game.is_night() and not _silenced and Game.player != null:
			var to_woods: Vector3 = (Game.player.global_position - Station.SPAWN).normalized()
			if to_woods.length_squared() < 0.1:
				to_woods = Vector3(0, 0, -1)
			var echo_pos: Vector3 = Game.player.global_position + to_woods * randf_range(35.0, 50.0) + Vector3(0, 2.0, 0)
			var snd: String = "res://assets/sfx/cc0/log_frost_crack.ogg" if randf() < 0.5 else "res://assets/sfx/cc0/branch_snow_drop_1.ogg"
			var p := play_3d(snd, echo_pos, -2.0, 16.0)
			if p != null:
				p.pitch_scale = randf_range(0.85, 0.95)
			if randf() < 0.65:
				Game.hud.subtitle(Loc.t(&"sub.taiga_mirage"), 3.5)
			Director.add_tension(6.0, "акустический мираж тайги")


func _update_life(delta: float) -> void:
	_life_t -= delta
	if _life_t > 0.0 or Game.player == null or Game.level == null:
		return
	_life_t = randf_range(14.0, 32.0)
	if _silenced or Game.zone == &"bunker":
		return
	var pool: Array = LIFE_NIGHT if Game.is_night() else LIFE_DAY
	var total := 0.0
	for e: Array in pool:
		total += float(e[1])
	var pick := randf() * total
	var entry: Array = pool[0]
	for e: Array in pool:
		pick -= float(e[1])
		if pick <= 0.0:
			entry = e
			break
	var dist: float = entry[2] * randf_range(0.7, 1.3)
	var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	var pos := Game.player.global_position + dir * dist + Vector3(0, 2.0, 0)
	var vol := -4.0 if Game.is_outside() else -13.0
	play_3d(String(entry[0]), pos, vol, maxf(dist * 0.35, 3.0))
	if (String(entry[0]).ends_with("snow_fall.ogg") or String(entry[0]).contains("branch_snow_drop")) and Game.is_outside():
		_snow_puff(pos - Vector3(0, 2.0, 0))
	if String(entry[0]).ends_with("wolf_howl.ogg"):
		Director.add_tension(4.0, "волки")


## Снег, сорвавшийся с ветки, — облачко хлопьев там, откуда звук.
func _snow_puff(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.one_shot = true
	p.amount = 60
	p.lifetime = 1.6
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.8, 0.3, 0.8)
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, -3.0, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.6, 0.62, 0.68)
	qm.material = mat
	p.mesh = qm
	Game.level.add_child(p)
	p.global_position = pos + Vector3(0, 3.5, 0)
	p.emitting = true
	Geo.free_after(p, 2.5)


## Тишина перед ударом. Испуги включают и выключают её сами.
func silence(on: bool) -> void:
	_silenced = on


## Обрыв звука перед ударом: на 1.2–1.5с фоновые звуки резко затыкаются.
func vacuum_scare(duration := 1.3) -> void:
	silence(true)
	await get_tree().create_timer(duration, false).timeout
	silence(false)


## Вакуум / затишье ветра перед атакой или скримером (сведение ветра в ноль на 3-5 с).
func trigger_vacuum(duration := 3.5) -> void:
	_vacuum_timer = maxf(_vacuum_timer, duration)


## Спасительный утренний радио-сигнал в 06:00: 6 сигналов точного времени и позывные гимна.
func play_dawn_chime() -> void:
	play_2d(DAWN_CHIME, 3.0)


func play_roof_steps() -> void:
	var pts := [
		Vector3(8.0, 2.7, 2.5),
		Vector3(5.5, 2.7, 2.8),
		Vector3(3.2, 2.7, 3.4),
		Vector3(1.2, 2.7, 4.2)
	]
	for p in pts:
		# тяжёлые шаги по доскам над головой (раньше тут играл ровный тон «скрипа»)
		var s := play_3d("res://assets/sfx/cc0/step_plank_%d.ogg" % randi_range(1, 8), p, -4.0, 8.0)
		if s != null:
			s.pitch_scale = 0.72
		await get_tree().create_timer(randf_range(0.8, 1.1), false).timeout
	_snow_puff(Vector3(0.5, 1.0, 4.8))
	play_3d("res://assets/audio/snow_fall.ogg", Vector3(0.5, 2.2, 4.8), 2.0)
	if not Game.is_indoors():
		return                            # успел выйти — «над головой» уже не про него
	Game.hud.subtitle(Loc.t(&"sub.roof_steps"), 4.0)
	Director.add_tension(14.0, "шаги на крыше")
	Game.add_fatigue(4.0)


## Реплика персонажа с голосом, если он записан (Voice). Возвращает длительность; 0 — голоса нет,
## тогда реплика идёт одними субтитрами, как раньше.
func say(id: StringName, pos: Vector3, volume_db := 0.0, unit_size := 4.0) -> float:
	var vp := Voice.path(id)
	if vp == "":
		return 0.0
	var p := play_3d(vp, pos, volume_db, unit_size)
	return p.stream.get_length() if p != null and p.stream != null else 0.0


# --- Журнал звуков (F9) -------------------------------------------------------
# Игрок слышит странный звук → жмёт F9 → рядом с игрой появляется sound_log.txt: что играет прямо
# сейчас (с громкостью у ушей) и последние разовые звуки. По нему находим источник, не угадывая.

var _recent: Array = []   ## [время, путь, где]


# --- Сторож утечек ------------------------------------------------------------
# Разовый звук, который играет дольше LEAK_S, — почти наверняка зацикленный файл без остановки
# (как помехи с мачты). Пишем в лог «[audio-leak]» (автотест это ловит) и глушим.
const LEAK_S := 25.0
var _oneshots: Array = []   ## [плеер, путь, время старта]
var _leak_t := 0.0
var _clock := 0.0   ## игровое время: на паузе не идёт, ложных «утечек» нет


func _track(p: Node, path: String) -> void:
	p.set_meta(&"src", path.get_file())
	# Длинный, но не зацикленный файл (речь, самолёт) имеет право доиграть.
	var limit := LEAK_S
	var st: AudioStream = p.get(&"stream")
	if st is AudioStreamOggVorbis and not (st as AudioStreamOggVorbis).loop:
		limit = maxf(LEAK_S, st.get_length() + 3.0)
	_oneshots.append([p, path, _clock, limit])


func _check_leaks(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.01)   # звук играет в реальном времени, а не в ускоренном
	_leak_t -= delta
	if _leak_t > 0.0:
		return
	_leak_t = 2.0
	var now := _clock
	var keep: Array = []
	for e: Array in _oneshots:
		if not is_instance_valid(e[0]):   # уже доиграл и освобождён
			continue
		var p: Node = e[0]
		if now - float(e[2]) > float(e[3]) and not p.has_meta(&"long_ok"):
			push_warning("[audio-leak] %s играет %.0f с" % [e[1], now - float(e[2])])
			print("[audio-leak] ", e[1])
			if p is AudioStreamPlayer:
				_fade_and_free_2d(p as AudioStreamPlayer)
			elif p is AudioStreamPlayer3D:
				_fade_and_free(p as AudioStreamPlayer3D)
			continue
		keep.append(e)
	_oneshots = keep


func _note(path: String, where: String) -> void:
	_recent.append([Time.get_ticks_msec() / 1000.0, path.get_file(), where])
	if _recent.size() > 40:
		_recent.pop_front()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9:
		bug_report()


static func _stream_name(s: AudioStream) -> String:
	if s == null:
		return "?"
	if s is AudioStreamRandomizer:
		var r := s as AudioStreamRandomizer
		var names: PackedStringArray = []
		for i in range(r.streams_count):
			var sub := r.get_stream(i)
			names.append(sub.resource_path.get_file() if sub != null else "?")
		return "{" + ", ".join(names) + "}"
	return s.resource_path.get_file() if s.resource_path != "" else s.get_class()


func _sound_text() -> String:
	var now := Time.get_ticks_msec() / 1000.0
	var lis: Vector3 = Game.player.camera.global_position if Game.player != null else Vector3.ZERO
	var rows: Array = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var db := -999.0
		var stream: AudioStream = null
		var bus := &""
		var where := "2d"
		if n is AudioStreamPlayer and (n as AudioStreamPlayer).playing:
			var a := n as AudioStreamPlayer
			db = a.volume_db
			stream = a.stream
			bus = a.bus
		elif n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).playing:
			var a3 := n as AudioStreamPlayer3D
			var d := a3.global_position.distance_to(lis)
			if a3.max_distance > 0.0 and d > a3.max_distance:
				continue
			db = a3.volume_db - 20.0 * log(maxf(d / maxf(a3.unit_size, 0.01), 1.0)) / log(10.0)
			stream = a3.stream
			bus = a3.bus
			where = "%.0f м, %s" % [d, str(n.get_parent().name)]
		else:
			continue
		var bi := AudioServer.get_bus_index(bus)
		if bi >= 0:
			db += AudioServer.get_bus_volume_db(bi)
		if db < -50.0:
			continue
		var sname := String(n.get_meta(&"src")) if n.has_meta(&"src") else _stream_name(stream)
		rows.append([db, "%6.1f дБ  %-8s %s  (%s)" % [db, bus, sname, where]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lines: PackedStringArray = ["=== Кедр-7 %s, ночь %d, %s, зона %s, игрок %s ===" % [
		ProjectSettings.get_setting("application/config/version", "?"), Game.night, Game.clock_text(),
		Game.zone, str(lis.snapped(Vector3.ONE * 0.1))]]
	lines.append("Играет сейчас (громкость у ушей):")
	for r: Array in rows:
		lines.append("  " + r[1])
	lines.append("Разовые звуки за последние 40 с:")
	for e: Array in _recent:
		if now - float(e[0]) <= 40.0:
			lines.append("  %5.1f с назад  %s  (%s)" % [now - float(e[0]), e[1], e[2]])
	return "\n".join(lines) + "\n\n"


static func _out_dir() -> String:
	var dir := OS.get_executable_path().get_base_dir() if not OS.has_feature("editor") else ProjectSettings.globalize_path("user://")
	if OS.is_debug_build():   # автотест и редактор — в профиль, не рядом с бинарником Godot
		dir = ProjectSettings.globalize_path("user://")
	return dir


## F9 — отчёт о баге: папка reports/<время>/ рядом с игрой: скриншот, состояние мира, звуки, хвост лога.
## Игрок жмёт сразу, как увидел/услышал странное, и присылает папку целиком.
func bug_report() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var dir := _out_dir().path_join("reports").path_join(stamp)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		dir = ProjectSettings.globalize_path("user://reports").path_join(stamp)
		DirAccess.make_dir_recursive_absolute(dir)
	if img != null:
		img.save_jpg(dir.path_join("screen.jpg"), 0.85)
	var p := Game.player
	var info: PackedStringArray = [
		"Кедр-7 %s  (%s)" % [ProjectSettings.get_setting("application/config/version", "?"), Time.get_datetime_string_from_system()],
		"Фаза: %s %d, время %s, ночь %d, зона %s" % [Game.phase_kind, Game.phase_index, Game.clock_text(), Game.night, Game.zone],
		"Игрок: %s, поворот %.0f°, взгляд %s" % [str(p.global_position.snapped(Vector3.ONE * 0.01)), rad_to_deg(p.rotation.y),
			str((-p.camera.global_basis.z).snapped(Vector3.ONE * 0.01))] if p != null else "Игрок: нет",
		"Фонарь: %s, режим %s" % [p.flashlight_on(), p.mode] if p != null else "",
		"Напряжение %.0f, усталость %.0f, буран %.2f" % [Director.tension, Game.fatigue, Game.weather.intensity if Game.weather != null else 0.0],
		"Ырка: угроза %.0f, стадия %s" % [Game.yrka.threat, Game.yrka.stage_name()] if Game.yrka != null else "Ырка: нет",
		"Свет %s, дров %.0f, FPS %d, %s, %s" % [Game.power_on, Game.stove_wood, Engine.get_frames_per_second(),
			RenderingServer.get_video_adapter_name(), OS.get_name()],
	]
	_write(dir.path_join("info.txt"), "\n".join(info) + "\n")
	_write(dir.path_join("sounds.txt"), _sound_text())
	var log_path := ProjectSettings.globalize_path("user://logs/godot.log")
	if FileAccess.file_exists(log_path):
		var lines := FileAccess.get_file_as_string(log_path).split("\n")
		_write(dir.path_join("log_tail.txt"), "\n".join(lines.slice(maxi(lines.size() - 120, 0))))
	if SessionLog.instance != null and SessionLog.instance._path != "" and FileAccess.file_exists(SessionLog.instance._path):
		SessionLog.note("F9-отчёт: " + stamp)
		_write(dir.path_join("session.txt"), FileAccess.get_file_as_string(SessionLog.instance._path))
	print("[report] ", dir)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.report_saved") + dir, 6.0)


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func dump_sound_log() -> void:
	var text := _sound_text()
	print(text)
	var dir := _out_dir()
	var fpath := dir.path_join("sound_log.txt")
	var f := FileAccess.open(fpath, FileAccess.READ_WRITE) if FileAccess.file_exists(fpath) else FileAccess.open(fpath, FileAccess.WRITE)
	if f == null:   # рядом с exe писать нельзя — пишем в профиль
		fpath = ProjectSettings.globalize_path("user://sound_log.txt")
		f = FileAccess.open(fpath, FileAccess.READ_WRITE) if FileAccess.file_exists(fpath) else FileAccess.open(fpath, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_string(text)
		f.close()
	if Game.hud != null:
		Game.hud.subtitle("Звуки записаны: " + fpath, 4.0)


## Чужие шаги по снегу: короткая серия отдельных хрустов, а не один длинный файл.
## Сгенерированные нейросетью «шаги» (yrka_steps, snow_steps_walk) тянулись шипением в 1,5 с,
## и на повторе каждые 2–7 с слышались как шёпот «спи… спи…». Отдельный хруст за хрустом читается как шаги.
const CRUNCH: Array[String] = ["res://assets/sfx/cc0/step_crust_1.ogg", "res://assets/sfx/cc0/step_crust_2.ogg",
	"res://assets/sfx/cc0/step_crust_3.ogg", "res://assets/audio/step_snow_2.ogg", "res://assets/audio/step_snow_5.ogg",
	"res://assets/audio/step_snow_7.ogg"]

func play_snow_steps(pos: Vector3, count := 2, volume_db := 0.0, unit_size := 4.0, pitch := 0.82, dir := Vector3.ZERO) -> void:
	for i in range(count):
		var p := play_3d(CRUNCH.pick_random(), pos + dir * (0.6 * i), volume_db, unit_size)
		if p != null:
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
		if i < count - 1:
			await get_tree().create_timer(randf_range(0.55, 0.75), false).timeout


func play_2d(path: String, volume_db := 0.0, max_duration := 0.0) -> AudioStreamPlayer:
	_note(path, "2d")
	var p := AudioStreamPlayer.new()
	p.stream = get_stream(path)
	p.volume_db = volume_db
	p.bus = &"SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	_track(p, path)
	# Петля, запущенная как разовый звук, сама не кончается: помехи с мачты, треск фонаря и сердце
	# после отказа фонаря играли до конца ночи (помехи — с резким громким всплеском раз в 20 с).
	if max_duration > 0.0 or path.contains("_loop."):
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = max_duration if max_duration > 0.0 else 4.0
		t.autostart = true
		p.add_child(t)
		t.timeout.connect(_fade_and_free_2d.bind(p))
	return p


static func _fade_and_free_2d(p: AudioStreamPlayer) -> void:
	if p == null or not is_instance_valid(p):
		return
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -80.0, 1.2)
	tw.tween_callback(p.queue_free)


func play_3d(path: String, pos: Vector3, volume_db := 0.0, unit_size := 2.0, max_duration := 0.0) -> AudioStreamPlayer3D:
	if Game.player != null:
		_note(path, "%.0f м" % pos.distance_to(Game.player.global_position))
	if (path.ends_with("voice_mainland.ogg") or path.ends_with("voice_loop.ogg")) and Game.radio != null and is_instance_valid(Game.radio):
		return Game.radio.play_transmission(path, volume_db)
	# Свист чудовища в тайге полностью блокируется и глушится стенами дома
	if path.ends_with("whistle.ogg") and (Game.is_home() or Game.is_indoors()):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(path)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.bus = &"SFX"
	Game.level.add_child(p)
	p.global_position = pos
	p.add_to_group(&"occludable")
	_occlude_one(p)
	p.finished.connect(p.queue_free)
	p.play()
	_track(p, path)
	# Защита от бесконечного зацикливания луп-файлов (например, breath_loop.ogg, lullaby_loop.ogg),
	# если они вызваны как одноразовый 3D-звук без ручного управления
	if max_duration > 0.0 or path.contains("_loop."):
		var dur := max_duration if max_duration > 0.0 else 4.0
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = dur
		t.autostart = true
		p.add_child(t)
		t.timeout.connect(_fade_and_free.bind(p))
	return p


## Музыка звучит только в меню и в концовке: тихо входит под страницы эпилога.
func play_ending_music() -> void:
	_ending_music = true
	var mp := _music_night
	mp.volume_db = -36.0
	if not mp.playing:
		mp.play()
	create_tween().tween_property(mp, "volume_db", -9.0, 6.0)


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = get_stream(path)
	p.volume_db = -40.0
	p.bus = &"Ambient"
	add_child(p)
	p.finished.connect(p.play)
	p.play()
	return p


static func _fade_and_free(p: AudioStreamPlayer3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	var tw := p.create_tween()
	if tw != null:
		tw.tween_property(p, "volume_db", -80.0, 1.2)
		tw.tween_callback(p.queue_free)
	else:
		p.queue_free()
