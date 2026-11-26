class_name CabinAcousticSim
extends Node3D
## Физико-акустическая симуляция жилого сруба в мороз -43°C.
## Управляет 5 физическими эмиттерами (AudioStreamPlayer3D):
## 1. Чугунная печь и дымоход (тепловые щелчки чугуна dT/dt, опрокидывание тяги перед Ыркой, дребезг конфорки).
## 2. Двойные оконные рамы (дребезг 2-мм стекла на 74 Гц за 1.5 с до порыва ветра; писк когтя при затишье).
## 3. Потолочные балки и чердак (инфразвуковой гул талрепов АШ-4 на стропилах ~ V^2, ледяная крупа, звон ввода).
## 4. Замочная скважина и щель сеней (резонатор Гельмгольца 420-880 Гц со свистом сквозняка; мёртвый обрыв при приближении).
## 5. Венцы из лиственницы (криогенный разрыв волокон брёвен < +5°C; признак обхода сруба — 3 удара по кругу).

const STOVE_POS := Vector3(-1.5, 1.2, 1.0)
const LIVING_WINDOW_POS := Vector3(8.5, 1.5, 3.8)
const RADIO_WINDOW_POS := Vector3(9.2, 1.5, -2.1)
const ATTIC_BEAMS_POS := Vector3(8.0, 2.7, 0.5)
const DOOR_KEYHOLE_POS := Vector3(14.55, 1.2, 3.1)
const CORNERS := [
	Vector3(0.5, 1.0, -2.2),
	Vector3(14.2, 1.0, -2.2),
	Vector3(14.2, 1.0, 4.2),
	Vector3(0.5, 1.0, 4.2)
]

var _stove_audio: AudioStreamPlayer3D
var _window_audio: AudioStreamPlayer3D
var _attic_audio: AudioStreamPlayer3D
var _keyhole_audio: AudioStreamPlayer3D
var _corner_audio: AudioStreamPlayer3D

var _prev_stove_heat := 0.0
var _stove_click_timer := 0.0
var _draft_howl_timer := 0.0
var _window_rattle_timer := 0.0
var _frost_crack_timer := 110.0
var _corner_circle_idx := 0
var _circling_active := false
var _gust_incoming_timer := 0.0


func _ready() -> void:
	name = "CabinAcousticSim"
	_prev_stove_heat = Game.stove_heat

	# 1. Чугунная печь и дымоход
	_stove_audio = AudioStreamPlayer3D.new()
	_stove_audio.position = STOVE_POS
	_stove_audio.max_distance = 18.0
	_stove_audio.bus = &"SFX"
	add_child(_stove_audio)

	# 2. Оконные переплёты
	_window_audio = AudioStreamPlayer3D.new()
	_window_audio.position = LIVING_WINDOW_POS
	_window_audio.max_distance = 15.0
	_window_audio.bus = &"SFX"
	add_child(_window_audio)

	# 3. Потолочные балки и чердак
	_attic_audio = AudioStreamPlayer3D.new()
	_attic_audio.position = ATTIC_BEAMS_POS
	_attic_audio.max_distance = 24.0
	_attic_audio.bus = &"SFX"
	add_child(_attic_audio)

	# 4. Замочная скважина (щель сеней)
	_keyhole_audio = AudioStreamPlayer3D.new()
	_keyhole_audio.position = DOOR_KEYHOLE_POS
	_keyhole_audio.max_distance = 12.0
	_keyhole_audio.bus = &"SFX"
	add_child(_keyhole_audio)

	# 5. Углы сруба
	_corner_audio = AudioStreamPlayer3D.new()
	_corner_audio.max_distance = 25.0
	_corner_audio.bus = &"SFX"
	add_child(_corner_audio)


func _process(delta: float) -> void:
	if not is_inside_tree() or Game.level == null:
		return
	var inside := Game.is_indoors()
	if not inside:
		# Снаружи и в лесу не крутим потолочный/дверной гул и не шлём звуки сруба в уши
		if _attic_audio != null and _attic_audio.playing:
			_attic_audio.stop()
		if _keyhole_audio != null and _keyhole_audio.playing:
			_keyhole_audio.stop()
		if _window_audio != null and _window_audio.playing:
			_window_audio.stop()
		return
	var yrka_near: bool = Game.yrka != null and is_instance_valid(Game.yrka) and \
		Game.yrka.stage in [YrkaThreat.Stage.STALKING, YrkaThreat.Stage.CALLING, YrkaThreat.Stage.PRESSURE, YrkaThreat.Stage.CHASE]

	_tick_stove_cooling(delta, yrka_near)
	_tick_window_rattle(delta, yrka_near)
	_tick_attic_talreps(delta, yrka_near)
	_tick_keyhole_whistle(delta, yrka_near)
	_tick_log_corners(delta, yrka_near)


## 1. Чугунная печь: щелчки сжимающегося чугуна и опрокидывание тяги
func _tick_stove_cooling(delta: float, yrka_near: bool) -> void:
	var cur_heat := Game.stove_heat
	var d_heat := cur_heat - _prev_stove_heat
	_prev_stove_heat = cur_heat

	# Дрова прогорели, печь остывает: сухие металлические щелчки (тик... дзынь)
	if d_heat < -0.001 and Game.stove_wood <= 0.0:
		_stove_click_timer -= delta
		if _stove_click_timer <= 0.0:
			var delta_abs := maxf(absf(d_heat), 0.02)
			_stove_click_timer = clampf(12.0 / (delta_abs * 100.0), 4.5, 18.0)
			var cp := Game.audio.play_3d("res://assets/audio/clank.ogg", STOVE_POS, -16.0, 2.0)
			if cp != null:
				cp.pitch_scale = randf_range(1.6, 2.2)

	# За 20 секунд до атаки Ырки опрокидывание тяги: булькающий вой и дребезг конфорки
	if yrka_near:
		_draft_howl_timer -= delta
		if _draft_howl_timer <= 0.0:
			_draft_howl_timer = randf_range(16.0, 28.0)
			_stove_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/chimney_howl.ogg")
			_stove_audio.volume_db = -6.0
			_stove_audio.pitch_scale = randf_range(0.75, 0.95)
			_stove_audio.play()
			# Мелкий звон чугунной конфорки
			get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
				if is_instance_valid(self) and Game.is_indoors():
					var cp2 := Game.audio.play_3d("res://assets/audio/clank_v2.ogg", STOVE_POS, -14.0, 2.0)
					if cp2 != null:
						cp2.pitch_scale = 2.2
			)


## 2. Оконные переплёты: предвестие порыва ветра и когти Ырки
func _tick_window_rattle(delta: float, yrka_near: bool) -> void:
	var wind_int: float = Game.weather.intensity if Game.weather != null else 0.4
	if wind_int < 0.35 and not yrka_near:
		return
	_gust_incoming_timer -= delta
	if _gust_incoming_timer <= 0.0:
		_gust_incoming_timer = randf_range(24.0, 42.0) / maxf(wind_int, 0.35)
		# За 1.5 секунды до удара порыва ветра: тихое дребезжание переплёта только при сильном ветре
		if not yrka_near:
			_window_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/flag_flap_loop.ogg")
			_window_audio.volume_db = -18.0
			_window_audio.pitch_scale = 1.05
			_window_audio.play()
			get_tree().create_timer(1.3, false).timeout.connect(func() -> void:
				if is_instance_valid(self):
					_window_audio.stop()
					if Game.is_indoors():
						var gp := Game.audio.play_3d("res://assets/audio/gust.ogg", LIVING_WINDOW_POS, -10.0, 4.0)
						if gp != null:
							gp.pitch_scale = randf_range(0.9, 1.1)
			)
		else:
			# Если за окном Ырка — поток перекрыт телом, стекло не дрожит, раздаётся сухой писк нажима ногтя
			_window_audio.stop()
			_window_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/claw_scrape_1.wav")
			_window_audio.volume_db = -6.0
			_window_audio.pitch_scale = randf_range(1.2, 1.45)
			_window_audio.play()


## 3. Потолочные балки и чердак: талрепы АШ-4 на стропилах
func _tick_attic_talreps(delta: float, yrka_near: bool) -> void:
	var wind_int: float = Game.weather.intensity if Game.weather != null else 0.0
	# В слабый ветер и тихую погоду чердак не гудит навязчивым низкочастотным лупом
	if wind_int < 0.30 and not yrka_near:
		if _attic_audio.playing:
			_attic_audio.stop()
		return
	var wind_speed: float = wind_int * 25.0 + 5.0
	var v_sq := pow(clampf(wind_speed / 20.0, 0.2, 2.5), 2.0)

	# Низкочастотный инфразвуковой гул растяжек, прикрученных к стропилам (только в пургу)
	var target_db := linear_to_db(clampf(v_sq * 0.10, 0.01, 0.6)) - 14.0
	if not _attic_audio.playing:
		_attic_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/pole_hum_loop.ogg")
		_attic_audio.volume_db = target_db
		_attic_audio.pitch_scale = randf_range(0.75, 0.85)
		_attic_audio.play()
	else:
		_attic_audio.volume_db = lerpf(_attic_audio.volume_db, target_db, delta * 2.0)

	# Если Ырка наверху — резкий металлический звон дернутого кабеля (3D у стропил)
	if yrka_near and randf() < delta * 0.03:
		var cp := Game.audio.play_3d("res://assets/audio/clank_v4.ogg", ATTIC_BEAMS_POS, -4.0, 4.0)
		if cp != null:
			cp.pitch_scale = 1.6


## 4. Замочная скважина сеней: резонатор Гельмгольца и зловещий обрыв
func _tick_keyhole_whistle(delta: float, yrka_near: bool) -> void:
	var wind_int: float = Game.weather.intensity if Game.weather != null else 0.0
	var player_near_door: bool = Game.player != null and Game.player.global_position.distance_to(DOOR_KEYHOLE_POS) < 4.5
	var yrka_at_door: bool = yrka_near and Game.yrka != null and is_instance_valid(Game.yrka) and \
		Game.yrka.creature_pos.distance_to(DOOR_KEYHOLE_POS) < 3.5

	# В тихую погоду и когда Ырка у двери — никаких постоянных свистов (и не крутим монстр-свист whistle.ogg в сенях)
	if yrka_at_door or wind_int < 0.35 or not player_near_door:
		if _keyhole_audio.playing:
			_keyhole_audio.stop()
		return

	if not _keyhole_audio.playing:
		_keyhole_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/wind_whistle_loop.ogg")
		_keyhole_audio.volume_db = -24.0
		_keyhole_audio.pitch_scale = randf_range(0.92, 1.12)
		_keyhole_audio.play()


## 5. Венцы сруба: криогенный треск волокон древесины
func _tick_log_corners(delta: float, yrka_near: bool) -> void:
	_frost_crack_timer -= delta
	if _frost_crack_timer <= 0.0:
		_frost_crack_timer = randf_range(80.0, 140.0)
		if yrka_near and randf() < 0.5:
			# Хоррор-триггер: три «морозных выстрела» подряд по часовой стрелке вокруг комнаты
			_trigger_circling_cracks()
		else:
			# Обычный криогенный треск промерзающего угла
			var corner: Vector3 = CORNERS.pick_random()
			_corner_audio.position = corner
			_corner_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/log_frost_crack.ogg")
			_corner_audio.volume_db = -2.0
			_corner_audio.pitch_scale = randf_range(0.85, 1.15)
			_corner_audio.play()


func _trigger_circling_cracks() -> void:
	for i in range(3):
		var delay := 0.8 + i * 1.3
		var c_idx := (i) % CORNERS.size()
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				var p: Vector3 = CORNERS[c_idx]
				Game.audio.play_3d("res://assets/sfx/cc0/log_frost_crack_v2.ogg", p, 1.0, 18.0)
		)
