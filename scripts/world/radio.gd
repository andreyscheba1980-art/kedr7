class_name Radio
extends Node3D
## Радиостанция: настройка частоты, процедурные помехи, сигналы ночи, передача сводок, запись на плёнку.
## Помехи — зацикленный сэмпл шума, громкость которого ведёт сила сигнала. Раньше шум считался
## по сэмплу в GDScript (~22 тыс. вызовов в секунду) — это был самый дорогой кусок кадра.

const F_MIN := 3000.0
const F_MAX := 9000.0
const COARSE_RATE := 220.0
const FINE_FACTOR := 0.12
const WHEEL_STEP := 2.0
const LOCK_STRENGTH := 0.85
const LOCK_TIME := 1.5
const LINE_INTERVAL := 3.4
const STATIC_LOOP := "res://assets/audio/static_loop.ogg"
const IDLE_DB := -15.0
const ACTIVE_DB := -5.0
const ICED_FACTOR := 0.45
const RECORD_TIME := 5.0
const MAINLAND_VOICE := "res://assets/audio/voice_mainland.ogg"
const ZasAudioClass = preload("res://scripts/data/zas_audio.gd")

## Чья передача. Настоящая Большая Земля в конце связи называет пароль «Бирюса» (правило 2),
## ложная — молчит про пароль, путает его («Бирюза») или говорит верно, но в мёртвой тишине эфира.
enum Pass { NONE, REAL, REAL_END, FAKE, FAKE_WRONG, FAKE_CLEAN }
## На Большой Земле два оператора. Первый (сводки, наряды) — свой пароль mla_pass_*, второй (приказы,
## перекличка, утро) — ml_pass_*. Пароль всегда звучит голосом того, кто говорит; нет записи — только субтитр.
const OPERATOR_A := ["ml_prologue", "ml_ok_1", "ml_ok_2", "ml_last", "ml_silent", "ml_tasks", "ml_task_done"]

var freq := 6100.0
var fine_tune_khz := 0.0              ## ручка «ТОН» приёмника «Волна-К» (-5.0..+5.0 кГц)
var variometer_pos := 0.5             ## шаровой вариометр УСС трансивера «Ангара-РА» (0.0..1.0)
var variometer_resonance := 0.85      ## ток антенны / согласование сопротивления
var magic_eye_closure := 0.0          ## смыкание секторов лампы 6Е1П (0.0 = 90°, 1.0 = 3°)
var magic_eye_overload := false       ## аномальный захлёст в белый крест с коронным разрядом
var _tube_warmup := 0.0               ## прогрев ламп 6К4П (0.0..1.0 за 90 с)
var _grid_voltage := 220.0            ## напряжение сети от ДГА-24
var _time := 0.0
var _noise := FastNoiseLite.new()
var active := false
var muted := false                ## испуг может заглушить эфир целиком
var static_boost := 0.0           ## испуг может поднять помехи
var voice_override := false       ## голос слышен на любой частоте (бит с Семёновым)
var recording_t := -1.0           ## < 0 — не пишем
var morning_call_active := false  ## утренний сеанс связи с Большой Землей

func set_morning_call_active(v: bool) -> void:
	morning_call_active = v

var _signals: Array[StringName] = []
var _static: AudioStreamPlayer3D
var _tune: AudioStreamPlayer3D     ## шорох верньера, пока крутят ручку
var _tune_idle := 1.0
var _heterodyne: AudioStreamPlayer3D ## свист гетеродина при приближении к несущей
var tube_synth: VolnaTubeSynthesizer ## процедурный синтез ламп 6К4П («Волна-К»)
var _morse_t := 70.0               ## далёкая чужая морзянка между станциями
var _players: Dictionary = {}
var _static_amp := 0.3
var _base_db := IDLE_DB
var _lock_timer := 0.0
var _locked_id: StringName = &""
var _line_timer := 0.0
var _line_idx := 0
var _line_signal: StringName = &""
var _busy := false
var _active_voice_player: AudioStreamPlayer3D
var _freq_over: Dictionary = {}       ## id → частота для сигналов, назначенных на ночь (задания)
var _fake_voice := false              ## сейчас говорит «не Большая Земля»: эфир вокруг голоса мёртвый


## Воспроизвести голосовую радиопередачу с гарантией изоляции:
## 1. Предыдущий голос немедленно глушится.
## 2. Фоновые радиосигналы и шум эфира приглушаются на время речи.
## 3. Два голоса физически не могут звучать одновременно.
func play_transmission(stream_path: String, volume_offset_db := 0.0, pass_kind := Pass.NONE) -> AudioStreamPlayer3D:
	stop_transmission()
	voice_override = false
	_busy = true
	_fake_voice = pass_kind == Pass.FAKE or pass_kind == Pass.FAKE_WRONG or pass_kind == Pass.FAKE_CLEAN
	for id: StringName in _players:
		if is_instance_valid(_players[id]):
			_players[id].volume_db = -80.0
	var p := AudioStreamPlayer3D.new()
	var generic := stream_path.ends_with("voice_mainland.ogg") or stream_path.ends_with("voice_loop.ogg")
	var line := AudioDirector.cached_stream(stream_path)
	var line_len := 7.0 if generic or line == null else line.get_length()
	if generic or (Settings.voice_mode == "zas" and not _fake_voice and (stream_path.contains("ml_") or stream_path.contains("st_"))):
		line = ZasAudioClass.get_scramble_stream(line_len)
	p.stream = line
	var pass_vid := _pass_voice(pass_kind, stream_path.get_file().get_basename() in OPERATOR_A)
	if pass_vid != &"" and Voice.has(pass_vid) and not generic and line != null and Settings.voice_mode != "zas":
		p.stream = _with_tail(line, load(Voice.path(pass_vid)) as AudioStream)
	_show_pass(pass_kind, line_len)
	p.unit_size = 3.5
	p.max_distance = 18.0
	p.volume_db = volume_offset_db
	p.bus = &"Radio"
	add_child(p)
	_active_voice_player = p
	ZasAudioClass.play_relay_click(true, global_position)
	# Общий «голос в эфире» (заглушка, пока реплика не озвучена отдельно) длинный — 30 с.
	# Не держим им рацию: 7 с бормотания, затухание, и эфир снова свободен.
	if generic:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = 7.0
		t.autostart = true
		p.add_child(t)
		t.timeout.connect(func() -> void:
			var tw := p.create_tween()
			tw.tween_property(p, "volume_db", -60.0, 0.6)
			tw.tween_callback(p.stop)
			tw.tween_callback(func() -> void: p.finished.emit()))
	p.finished.connect(func() -> void:
		ZasAudioClass.play_relay_click(false, global_position)
		if _active_voice_player == p:
			_active_voice_player = null
			_busy = false
		p.queue_free()
	)
	p.play()
	return p


## Только пароль — отдельной короткой передачей (после длинного наряда, переклички).
func say_pass(kind: Pass, operator_a := false) -> void:
	var vid := _pass_voice(kind, operator_a)
	if Voice.has(vid) and not is_voice_busy():
		play_transmission(Voice.path(vid), 0.0)
	_show_pass(kind, 0.0)


static func _pass_voice(kind: Pass, operator_a := false) -> StringName:
	match kind:
		Pass.REAL:
			return &"mla_pass_1" if operator_a else &"ml_pass_1"
		Pass.REAL_END:
			return &"mla_pass_2" if operator_a else &"ml_pass_2"
		Pass.FAKE_WRONG:
			return &"mlf_pass"
		Pass.FAKE_CLEAN:
			return &"mlf_pass_ok"
	return &""


## Пароль в субтитрах — даже если реплика ещё не озвучена: правило должно работать и без голоса.
func _show_pass(kind: Pass, after: float) -> void:
	var key := &""
	match kind:
		Pass.REAL, Pass.FAKE_CLEAN:
			key = &"radio.pass_real"
		Pass.REAL_END:
			key = &"radio.pass_end"
		Pass.FAKE_WRONG:
			key = &"radio.pass_fake"
	if key == &"":
		return
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(after, 0.5) + 0.2
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		t.queue_free()
		if Game.hud != null and Game.is_home():
			Game.hud.subtitle(Loc.t(&"semenov.near", [Loc.t(key)]), 2.6))


static func _with_tail(line: AudioStream, tail: AudioStream) -> AudioStream:
	if tail == null:
		return line
	var gap := AudioStreamWAV.new()
	gap.format = AudioStreamWAV.FORMAT_16_BITS
	gap.mix_rate = 22050
	var d := PackedByteArray()
	d.resize(int(0.3 * 22050.0) * 2)
	gap.data = d
	var pl := AudioStreamPlaylist.new()
	pl.loop = false
	pl.fade_time = 0.0
	pl.stream_count = 3
	pl.set_list_stream(0, line)
	pl.set_list_stream(1, gap)
	pl.set_list_stream(2, tail)
	return pl


func stop_transmission() -> void:
	if _active_voice_player != null and is_instance_valid(_active_voice_player):
		_active_voice_player.stop()
		_active_voice_player.queue_free()
	_active_voice_player = null
	_busy = false


func is_voice_busy() -> bool:
	return _active_voice_player != null and is_instance_valid(_active_voice_player) and _active_voice_player.playing


var _belov_checkin_done := false


func _ready() -> void:
	Game.radio = self
	freq = Game.rng.randf_range(5600.0, 6500.0)
	for id: StringName in Game.cfg.get("signals", [&"mainland"]):
		if not _signals.has(id):
			_signals.append(id)
	if Game.is_night():
		for id in Signals.broadcast_for_night(Game.night):
			if not _signals.has(id):
				_signals.append(id)
	elif Game.is_day():
		for id in Signals.broadcast_for_day(Game.phase_index):
			if not _signals.has(id):
				_signals.append(id)

	_static = AudioStreamPlayer3D.new()
	_static.stream = AudioDirector.cached_stream(STATIC_LOOP)
	_static.unit_size = 3.0
	_static.max_distance = 18.0
	_static.bus = &"Radio"
	add_child(_static)
	_static.finished.connect(_static.play)
	_static.play()
	_static.seek(Game.rng.randf_range(0.0, 3.5))

	var tune_path := Voice.sfx(&"radio_tune")
	if tune_path != "":
		_tune = AudioStreamPlayer3D.new()
		_tune.stream = AudioDirector.cached_stream(tune_path)
		_tune.unit_size = 2.5
		_tune.max_distance = 12.0
		_tune.volume_db = -12.0
		_tune.bus = &"Radio"
		add_child(_tune)

	_heterodyne = AudioStreamPlayer3D.new()
	var het_s := load("res://assets/audio/carrier_loop.ogg") as AudioStream
	if het_s is AudioStreamOggVorbis:
		het_s = het_s.duplicate()
		(het_s as AudioStreamOggVorbis).loop = true
	_heterodyne.stream = het_s
	_heterodyne.unit_size = 2.5
	_heterodyne.max_distance = 14.0
	_heterodyne.volume_db = -80.0
	_heterodyne.bus = &"Radio"
	add_child(_heterodyne)
	_heterodyne.play()

	tube_synth = VolnaTubeSynthesizer.new()
	add_child(tube_synth)

	for id in _signals:
		var p := AudioStreamPlayer3D.new()
		p.name = "Signal_" + String(id)
		p.stream = NumbersVoice.stream_or_default(id)
		p.unit_size = 3.0
		p.max_distance = 18.0
		p.volume_db = -80.0
		p.bus = &"Radio"
		p.set_meta(&"src", "radio:" + String(id))
		add_child(p)
		p.finished.connect(_on_signal_finished.bind(p, id))
		p.play()
		_players[id] = p
	# Случайный эфир ночи (Efir): короткие передачи в своё окно времени
	if Game.is_night():
		for id in Efir.pool_for_night(Game.night):
			add_dynamic(id, float(Efir.pool_def(id)["freq"]))


## Сигналы, которые в эфире этой ночью (для рамки и приёмника на башне).
func signals_on_air() -> Array[StringName]:
	return _signals


## Сила сигнала на произвольной частоте (рамка, приёмник на башни): без слабых — только с башни.
func strength_at(id: StringName, f: float, tower := false) -> float:
	if not _signals.has(id) or not Efir.window_ok(id) or (Efir.is_weak(id) and not tower):
		return 0.0
	var s := Signals.get_def(id)
	var center: float = _freq_over.get(id, float(s["freq"]))
	var d := absf(f - center) / (float(s["width"]) * (1.6 if Gear.has(&"quartz_core") else 1.0))
	return smoothstep(0.0, 1.0, clampf(1.0 - d, 0.0, 1.0))


func _process(delta: float) -> void:
	_time += delta
	_tube_warmup = move_toward(_tube_warmup, 1.0, delta / 90.0)

	# 1. Вычисляем тепловой и вольтажный дрейф гетеродина «Волны-К»
	var target_vario := 0.72 if Game.antenna_iced else 0.48
	var vario_diff := absf(variometer_pos - target_vario)
	variometer_resonance = clampf(1.0 - vario_diff * 3.0, 0.0, 1.0)

	# Сеанс поверки связи с партией Белова (14:00 днём и 21:00 ночью = минута 60)
	if not _belov_checkin_done:
		var is_checkin_time := (Game.is_day() and Game.shift_minutes >= 0.5 and Game.shift_minutes <= 25.0) or (Game.is_night() and Game.shift_minutes >= 60.0 and Game.shift_minutes <= 85.0)
		if is_checkin_time:
			_belov_checkin_done = true
			if Game.is_home():
				var tone := Voice.sfx(&"radio_tone")
				if tone != "":
					Game.audio.play_3d(tone, global_position + Vector3.UP * 0.2, -6.0, 4.0)
				else:
					Game.audio.play_3d("res://assets/audio/beacon_loop.ogg", global_position + Vector3.UP * 0.2, -8.0, 4.0)
				Game.hud.subtitle(Loc.t(&"sub.belov_checkin"), 5.0)

	var voice_active := _busy or is_voice_busy()
	if active and not voice_active:
		var axis := Input.get_axis(&"move_left", &"move_right")
		if axis != 0.0 and recording_t < 0.0:
			var k := FINE_FACTOR if Input.is_action_pressed(&"fine_tune") else 1.0
			set_freq(freq + axis * COARSE_RATE * k * delta)

	var best_id: StringName = &""
	var best_s := 0.0
	_base_db = lerpf(_base_db, ACTIVE_DB if active else IDLE_DB, minf(delta * 4.0, 1.0))
	var base_db := _base_db
	for id in _signals:
		var st := strength_of(id)
		if voice_active:
			st = 0.0
		if st > best_s:
			best_s = st
			best_id = id
		var p: AudioStreamPlayer3D = _players[id]
		var vol := st
		if voice_override and not is_voice_busy():
			vol = 1.0 if id == &"semenov" else 0.0
		if muted or is_voice_busy() or (voice_active and not (voice_override and id == &"semenov" and not is_voice_busy())):
			vol = 0.0
		p.volume_db = linear_to_db(maxf(vol, 0.0001)) + base_db

	# Проверка близости Ырки к аппаратной (менее 32 м) для аномального захлёста 6Е1П
	var yrka_near_radio := false
	if Game.yrka != null and Game.yrka.enabled:
		var p_xz := Vector2(global_position.x, global_position.z)
		var y_dist := p_xz.distance_to(Game.yrka.virtual_pos)
		if y_dist < 32.0:
			yrka_near_radio = true
	magic_eye_closure = clampf(best_s, 0.0, 1.0)
	magic_eye_overload = (best_s > 0.82 and (best_id == &"semenov" or best_id == &"anomaly" or best_id == &"echo" or best_id == &"roof_echo" or String(best_id).contains("yrka"))) or yrka_near_radio

	var target_amp := lerpf(0.28, 0.03, best_s) + static_boost
	if Game.knife_in_lintel:
		target_amp += 0.42
	if Game.antenna_iced:
		target_amp += 0.1
	if is_voice_busy():
		target_amp = 0.0 if _fake_voice else 0.03
	elif voice_override:
		target_amp = 0.16
	elif voice_active:
		target_amp = 0.05
	if muted:
		target_amp = 0.0
	_static_amp = lerpf(_static_amp, target_amp, minf(delta * 5.0, 1.0))   # без резких скачков шума
	_static.volume_db = base_db + linear_to_db(maxf(_static_amp, 0.0001))

	if tube_synth != null:
		tube_synth.grid_voltage = _grid_voltage
		tube_synth.carrier_suppression = clampf(best_s, 0.0, 1.0)
		tube_synth.receiver_gain = 0.0 if muted else 0.55

	# Гетеродинный свист при приближении к несущей частоте (биения гетеродина Р-250)
	var het_target_db := -80.0
	var het_pitch := 1.0
	var eff_f := effective_reception_freq()
	if active and not voice_active and not muted:
		var min_d := 9999.0
		for id in _signals:
			if not Efir.window_ok(id):
				continue
			var s_def := Signals.get_def(id)
			var cf: float = _freq_over.get(id, float(s_def["freq"]))
			var df := absf(eff_f - cf)
			if df < min_d:
				min_d = df
		if min_d < 140.0 and min_d > 6.0:
			var prox := 1.0 - (min_d / 140.0)
			het_target_db = -24.0 + prox * 10.0
			het_pitch = clampf(0.4 + (min_d / 140.0) * 1.5, 0.35, 2.0)
	if _heterodyne != null:
		_heterodyne.volume_db = lerpf(_heterodyne.volume_db, het_target_db, minf(delta * 8.0, 1.0))
		_heterodyne.pitch_scale = lerpf(_heterodyne.pitch_scale, het_pitch, minf(delta * 12.0, 1.0))

	_tick_sfx(delta, voice_active)
	if active:
		if best_id != &"mainland" and best_s > 0.5:
			Efir.after3_tick(delta)   # после трёх в наушниках: эфир чужой, а вокруг ничего не слышно
		_update_lock(best_id, best_s, delta)
		_update_lines(best_id, best_s, delta)
		_update_recording(best_id, best_s, delta)
		Game.hud.update_radio(eff_f, best_s, _locked_id, record_prompt(), recording_progress(), fine_tune_khz, variometer_resonance, magic_eye_closure, magic_eye_overload)


# --- Управление --------------------------------------------------------------

func enter() -> void:
	active = true
	Game.player.mode = Player.Mode.RADIO
	Game.hud.show_radio(true)
	var sq := Voice.sfx(&"radio_squelch")
	if sq != "":
		Game.audio.play_3d(sq, global_position + Vector3.UP * 0.2, -8.0, 3.5)


func exit() -> void:
	active = false
	_lock_timer = 0.0
	recording_t = -1.0
	Game.player.mode = Player.Mode.WALK
	Game.hud.show_radio(false)
	var sq := Voice.sfx(&"radio_squelch")
	if sq != "":
		Game.audio.play_3d(sq, global_position + Vector3.UP * 0.2, -11.0, 3.5)


func effective_reception_freq() -> float:
	var thermal_drift: float = (1.0 - _tube_warmup) * 4.2
	var voltage_drift: float = (_grid_voltage - 220.0) * 0.08
	var ion_flutter: float = _noise.get_noise_1d(_time * 1.5) * 0.35 if _noise != null else 0.0
	return freq + fine_tune_khz - thermal_drift + voltage_drift + ion_flutter


func nudge(dir: int) -> void:
	nudge_scaled(dir, 1.0)


func nudge_scaled(dir: int, step_mult: float = 1.0) -> void:
	if recording_t < 0.0:
		set_freq(freq + WHEEL_STEP * dir * step_mult)


func fine_step(dir: float) -> void:
	fine_tune_khz = clampf(fine_tune_khz + dir * 0.25, -5.0, 5.0)
	if active:
		_tune_idle = 0.0


func cycle_variometer() -> void:
	variometer_pos = wrapf(variometer_pos + 0.08, 0.0, 1.0)
	Game.audio.play_3d("res://assets/audio/clank.ogg", global_position + Vector3.UP * 0.2, -6.0, 2.5)
	var pct := int(roundf(variometer_resonance * 100.0))
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"radio.variometer_status") + " [%d%%]" % pct, 2.5)


func set_freq(f: float) -> void:
	var nf := clampf(f, F_MIN, F_MAX)
	if active and absf(nf - freq) > 0.01:
		_tune_idle = 0.0
	freq = nf


func _tick_sfx(delta: float, voice_active: bool) -> void:
	if _tune != null:
		_tune_idle += delta
		var turning := _tune_idle < 0.25 and not muted
		if turning:
			_tune.volume_db = -10.0
			if not _tune.playing:
				_tune.play(Game.rng.randf_range(0.0, 1.5))
		elif _tune.playing:
			_tune.volume_db -= delta * 60.0
			if _tune.volume_db < -40.0:
				_tune.stop()
	# Изредка между станциями прорезается чужая далёкая морзянка — эфир живой.
	_morse_t -= delta
	if _morse_t <= 0.0:
		_morse_t = Game.rng.randf_range(60.0, 140.0)
		var m := Voice.sfx(&"radio_morse_far")
		if m != "" and active and not voice_active and not muted and _locked_id == &"":
			Game.audio.play_3d(m, global_position + Vector3.UP * 0.3, -16.0, 2.5)


## Сигнал, которого нет в расписании ночи: маяк или контрольная группа для задания.
func add_dynamic(id: StringName, f: float) -> void:
	if _signals.has(id):
		return
	_freq_over[id] = f
	_signals.append(id)
	var p := AudioStreamPlayer3D.new()
	p.name = "Signal_" + String(id)
	p.stream = NumbersVoice.stream_or_default(id)
	p.unit_size = 3.0
	p.max_distance = 18.0
	p.volume_db = -80.0
	p.bus = &"Radio"
	p.set_meta(&"src", "radio:" + String(id))
	add_child(p)
	p.finished.connect(_on_signal_finished.bind(p, id))
	p.play()
	_players[id] = p


func remove_dynamic(id: StringName) -> void:
	if not _freq_over.has(id):
		return
	_freq_over.erase(id)
	_signals.erase(id)
	var p: AudioStreamPlayer3D = _players.get(id)
	if p != null:
		p.queue_free()
	_players.erase(id)
	if _locked_id == id:
		_locked_id = &""


func strength_of(id: StringName) -> float:
	if not _signals.has(id):
		return 0.0
	if id != &"mainland" and (not Efir.window_ok(id) or Efir.is_weak(id)):
		return 0.0
	var s := Signals.get_def(id)
	var center: float = _freq_over.get(id, float(s["freq"]))
	var ef := effective_reception_freq()
	var d := absf(ef - center) / (float(s["width"]) * (1.6 if Gear.has(&"quartz_core") else 1.0))   # кварц: ловит шире
	var st := smoothstep(0.0, 1.0, clampf(1.0 - d, 0.0, 1.0))
	if id == &"mainland":
		st *= Consequences.mainland_k()   # ослабшая оттяжка мачты
	if id == &"mainland" and Game.antenna_iced:
		st *= ICED_FACTOR   # обледеневшая антенна почти не тянет Большую Землю
	return st


func locked_signal() -> StringName:
	return _locked_id


## Можно ли прямо сейчас начать запись захваченного сигнала.
func can_record() -> bool:
	if recording_t >= 0.0 or _locked_id == &"" or not Game.has_item(&"tape_recorder"):
		return false
	if not bool(Signals.get_def(_locked_id).get("recordable", false)):
		return false
	return not SaveGame.tapes.has(_locked_id)


## Подсказка о записи для панели рации.
func record_prompt() -> String:
	if recording_t >= 0.0:
		return Loc.t(&"radio.recording")
	if can_record():
		return Loc.t(&"radio.record_hint")
	if _locked_id != &"" and SaveGame.tapes.has(_locked_id):
		return Loc.t(&"radio.taped")
	return ""


func recording_progress() -> float:
	return clampf(recording_t / RECORD_TIME, 0.0, 1.0) if recording_t >= 0.0 else -1.0


func start_recording() -> void:
	if can_record():
		recording_t = 0.0


## Сводка по портативной «Карату» (снаряжение): из корпуса, без настройки частоты Р-250 в доме.
var _field := false


func field_transmit() -> void:
	_field = true
	transmit()
	_field = false


func transmit() -> void:
	if not _field and variometer_resonance < 0.65:
		Game.audio.play_3d("res://assets/audio/clank.ogg", global_position + Vector3.UP * 0.2, 2.0, 4.0)
		Game.hud.subtitle(Loc.t(&"radio.variometer_unmatched"), 4.0)
		return
	if Game.night == 7 and Game.final_call and not _field:
		_challenge_night7_crawler()
		return
	if Game.final_call and strength_of(&"mainland") >= 0.75 and not _busy:
		EventBus.ending_chosen.emit(&"answer")   # ночь 7: отвечаем на зов даже поверх голоса в эфире
		return
	if _busy or is_voice_busy() or voice_override:
		if is_voice_busy():
			Game.hud.subtitle(Loc.t(&"radio.wait_voice"), 1.5)
		return
	if not _field and Game.antenna_iced and absf(freq - float(Signals.get_def(&"mainland").get("freq", 6880.0))) < 20.0:
		Game.hud.subtitle(Loc.t(&"radio.iced"), 3.5)
		return
	if not _field and strength_of(&"mainland") < 0.75:
		Game.hud.subtitle(Loc.t(&"radio.wrong_freq"), 3.0)
		return
	if Game.final_call and not _field:
		EventBus.ending_chosen.emit(&"answer")   # ночь 7: ответить на зов
		return
	if not _field and Game.events != null and Game.events.orders != null and Game.events.orders.try_transmit():
		return
	if not _field and Game.tasks != null and Game.tasks.try_transmit():
		return
	var prologue := Game.is_prologue()
	if prologue and Game.tutorial.get(&"test_report", false):
		Game.hud.subtitle(Loc.t(&"radio.no_more"), 2.5)
		return
	if not prologue and (not Game.is_night() or Game.reports_sent >= Game.report_times().size()):
		Game.hud.subtitle(Loc.t(&"radio.no_more"), 2.5)
		return
	if not prologue and not Game.reports_closed:
		var due := float(Game.report_times()[Game.reports_sent])
		if Game.shift_minutes < due - 40.0:
			Game.hud.subtitle(Loc.t(&"radio.too_early", [Game.minutes_to_clock(int(due)), Game.minutes_to_clock(int(due - 40.0))]), 3.5)
			return
	if Net.needs_coop_report() and not prologue and not Game.reports_closed:
		# Кооп: приборы снимал напарник — цифры он диктует по рации, хост вписывает их в бланк.
		if not Game.coop_report_ok:
			exit()
			EventBus.ui_requested.emit(&"coop_report")
			return
	elif not prologue and not Game.has_readings() and not Game.reports_closed:
		Game.hud.subtitle(Loc.t(&"radio.no_readings"), 3.5)
		return
	if prologue and not Game.has_flag("prologue_arrived"):
		_run_prologue_radio_dialogue()
		return
	var check := Game.report_check()   # книжку сверяем до того, как замеры сброшены
	_busy = true
	EventBus.radio_transmitted.emit(freq)
	Game.coop_report_ok = false
	Game.clear_readings()
	Net.on_report_sent()
	Game.hud.subtitle(Loc.t(&"radio.report_out"), 3.5)
	await get_tree().create_timer(4.0, false).timeout
	var reply_id := &"ml_prologue"
	if not prologue:
		if Game.after_hour(3):
			reply_id = &"ml_wrong"
		elif Game.reports_sent + 1 >= Game.report_times().size():
			reply_id = &"ml_last"
		else:
			reply_id = &"ml_ok_1" if Game.rng.randf() < 0.5 or not Voice.has(&"ml_ok_2") else &"ml_ok_2"
	var reply_pass := Pass.FAKE if reply_id == &"ml_wrong" else Pass.REAL if reply_id == &"ml_prologue" else Pass.REAL_END
	var vp := play_transmission(Voice.or_fallback(reply_id, MAINLAND_VOICE), 2.0, reply_pass)
	var idx := -1
	if prologue:
		Game.hud.subtitle(Loc.t(&"sub.radio_arrival_done"), 6.0)
		Game.complete_step(&"test_report")
	else:
		if not Game.after_hour(3):
			idx = Game.reports_sent
			Game.reports_sent += 1
		if Game.after_hour(3):
			NightMemory.mark(&"after3_tx")
			# Правило Семёнова нарушено: после трёх отвечают «не они».
			Game.hud.subtitle(Loc.t(&"radio.reply_wrong"), 5.5)
			Director.add_tension(25.0, "ответ Большой Земли после трёх")
			Game.add_fatigue(8.0)
		else:
			var last := Game.reports_sent >= Game.report_times().size()
			Game.hud.subtitle(Loc.t(&"radio.reply_last") if last else Loc.t(&"radio.reply_ok"), 5.0)
	if check["verdict"] != &"ok" and check["verdict"] != &"none" and not Game.after_hour(3):
		_check_reply(check, 6.2 if prologue else 5.2)
	var cap := 3.0 + (vp.stream.get_length() if vp != null and is_instance_valid(vp) and vp.stream != null else 12.0)
	var t := 0.0
	while vp != null and is_instance_valid(vp) and vp.playing and t < cap:   # страховка от зависшего плеера
		await get_tree().process_frame
		if not get_tree().paused:
			t += get_process_delta_time()
	_busy = false
	if not prologue and idx >= 0:
		EventBus.report_sent.emit(idx)


## Свердловск сверяет температуру с соседними станциями: расхождение в книжке не проходит молча.
func _check_reply(check: Dictionary, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_inside_tree() or Game.hud == null:
		return
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -12.0)
	var names := func(groups: Array) -> String:
		var parts: PackedStringArray = []
		for g: StringName in groups:
			parts.append(Loc.t(StringName("radio.chk_" + String(g))))
		return ", ".join(parts)
	match check["verdict"]:
		&"fever":
			Game.hud.subtitle(Loc.t(&"coop.rep.fever"), 5.5)
			Director.add_tension(14.0, "сводка: +36,6 — это температура человека")
		&"remark":
			Game.hud.subtitle(Loc.t(&"radio.chk_remark", [names.call(check["remark"])]), 5.5)
			Director.add_tension(4.0, "сводка расходится с соседями")
		_:
			var bad: String = names.call(check["bad"])
			Game.hud.subtitle(Loc.t(&"radio.chk_bad", [bad.left(1).to_upper() + bad.substr(1)]), 6.0)
			Director.add_tension(10.0, "брак в сводке")
			Game.add_fatigue(3.0)
			SaveGame.flags["bad_reports"] = int(SaveGame.flags.get("bad_reports", 0)) + 1


func _challenge_night7_crawler() -> void:
	_busy = true
	Game.hud.subtitle(Loc.t(&"radio.n7_challenge"), 4.0)
	await get_tree().create_timer(3.8, false).timeout
	var is_mimic: bool = bool(SaveGame.flags.get("night7_crawler_is_mimic", true))
	if is_mimic:
		Game.audio.play_3d("res://assets/audio/radio_anomaly.ogg", global_position + Vector3.UP * 0.2, 0.0, 5.0)
		Game.hud.subtitle(Loc.t(&"radio.n7_reply_mimic"), 6.5)
		SaveGame.flags["night7_radio_mimic"] = true
	else:
		Game.audio.play_3d("res://assets/audio/voice_mainland.ogg", global_position + Vector3.UP * 0.2, 2.0, 5.0)
		Game.hud.subtitle(Loc.t(&"radio.n7_reply_real"), 5.5)
		SaveGame.flags["night7_radio_ok"] = true
	_busy = false


func _run_prologue_radio_dialogue() -> void:
	Game.coop_report_ok = false
	Game.clear_readings()
	Net.on_report_sent()
	# ВИКТОР: Кедр-7 вызывает Управление. Мальцев на месте. Прошу подтвердить приём.
	var d_v1 := Voice.say(&"radio.prologue_v1", 3.8)
	await get_tree().create_timer(d_v1 + 0.2, false).timeout
	if not is_inside_tree(): return

	# Два коротких щелчка реле
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -10.0)
	var vp1 := play_transmission(Voice.or_fallback(&"v_radio_prologue_hq1", MAINLAND_VOICE), 0.0, Pass.NONE)
	# УПРАВЛЕНИЕ: …Кедр-7, позывной принят. Мальцев, заступление подтверждаем.
	Game.hud.subtitle(Loc.t(&"radio.prologue_hq1"), 3.5)
	await get_tree().create_timer(3.8, false).timeout
	if not is_inside_tree(): return

	# ВИКТОР: Станция выморожена, печь растопил, генератор в работе. Жду указаний.
	var d_v2 := Voice.say(&"radio.prologue_v2", 3.5)
	await get_tree().create_timer(d_v2 + 0.2, false).timeout
	if not is_inside_tree(): return

	var vp2 := play_transmission(Voice.or_fallback(&"v_radio_prologue_hq2", MAINLAND_VOICE), 0.5, Pass.NONE)
	# УПРАВЛЕНИЕ: Сводки строго по расписанию: ноль-ноль, три, шесть. На перевале штормовое. Конец связи.
	Game.hud.subtitle(Loc.t(&"radio.prologue_hq2"), 4.0)
	await get_tree().create_timer(4.2, false).timeout
	if not is_inside_tree(): return

	# ВИКТОР: Вас понял. Конец связи.
	var d_v3 := Voice.say(&"radio.prologue_v3", 2.5)
	await get_tree().create_timer(d_v3 + 0.2, false).timeout
	if not is_inside_tree(): return

	stop_transmission()
	Game.audio.play_2d("res://assets/audio/static_loop.ogg", -6.0)
	AudioDirector.play_raw("res://assets/audio/clank.ogg", -8.0)
	# ВИКТОР: Радиомолчание. Надо расписаться в журнале смен.
	var d_v4 := Voice.say(&"radio.prologue_v4", 3.5)
	await get_tree().create_timer(d_v4 + 0.2, false).timeout
	if not is_inside_tree(): return

	_busy = false
	Game.complete_step(&"test_report")


func _on_signal_finished(p: AudioStreamPlayer3D, _id: StringName) -> void:
	if not is_instance_valid(p):
		return
	var pause_time := randf_range(8.0, 14.0)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = pause_time
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(func() -> void:
		t.queue_free()
		if is_inside_tree() and not _busy and not is_voice_busy() and not muted:
			p.play())



# --- Внутреннее --------------------------------------------------------------

func _update_lock(best_id: StringName, best_s: float, delta: float) -> void:
	if best_s >= LOCK_STRENGTH:
		_lock_timer += delta
		if _lock_timer >= LOCK_TIME and _locked_id != best_id:
			_locked_id = best_id
			EventBus.radio_locked.emit(best_id)
			var sq := Voice.sfx(&"radio_squelch")
			if sq != "":
				Game.audio.play_3d(sq, global_position, -6.0, 3.0)
			if best_id != &"mainland" and best_id != &"beacon" and best_id != &"control" and Game.add_intercept(best_id):
				Game.hud.subtitle(Loc.t(&"radio.intercept", [freq]), 3.0)
			if Efir.can_bearing(best_id) and best_id != &"mainland":
				Hints.show(&"efir_df")   # у рации — рамочная антенна: откуда передают
	else:
		_lock_timer = 0.0
		_locked_id = &""


func _update_recording(best_id: StringName, best_s: float, delta: float) -> void:
	if recording_t < 0.0:
		return
	if best_id != _locked_id or best_s < 0.7:
		recording_t = -1.0
		Game.hud.subtitle(Loc.t(&"radio.record_lost"), 2.5)
		return
	recording_t += delta
	if recording_t >= RECORD_TIME:
		recording_t = -1.0
		if Game.add_tape(_locked_id):
			Game.hud.subtitle(Loc.t(&"radio.recorded"), 3.0)


func _update_lines(best_id: StringName, best_s: float, delta: float) -> void:
	if best_s < 0.7 or _busy or voice_override:
		_line_signal = &""
		return
	if best_id != _line_signal:
		_line_signal = best_id
		_line_idx = 0
		_line_timer = 0.0
	_line_timer -= delta
	if _line_timer > 0.0:
		return
	if best_id == &"control" and Game.tasks != null:
		_line_timer = 12.0
		Game.hud.subtitle(Loc.t(&"sig.control.1", [Game.tasks.control_group, Game.tasks.control_group]), LINE_INTERVAL)
		return
	if best_id == &"code":
		var groups := Signals.code_groups(Settings.language)
		_line_timer = 14.0
		Game.hud.subtitle(Loc.t(&"sig.code.1") + "  " + " · ".join(groups), LINE_INTERVAL + 1.0)
		return
	if best_id == &"morse" or Efir.is_pool(best_id):
		# Морзе и цифровые группы — как слышны: расшифровка потом, по записи (журнал перехватов)
		var air := Efir.air_line(best_id)
		_line_timer = 13.0
		Game.hud.subtitle(air, maxf(LINE_INTERVAL + 1.5, air.length() / 18.0))
		return
	var lines: Array = Signals.get_def(best_id).get("lines", [])
	if lines.is_empty():
		return
	if _line_idx < lines.size():
		var text := Loc.t(lines[_line_idx])
		if best_id == &"numbers" and _line_idx == 1 and Game.anomalies != null and Game.anomalies.is_active(&"num_name"):
			text = Loc.t(&"sig.numbers.name")   # цифровая станция читает фамилию дежурного
		var dur := maxf(LINE_INTERVAL, text.length() / 16.0)   # длинные передачи успеваешь дочитать
		Game.hud.subtitle(text, dur)
		_line_idx += 1
		_line_timer = dur + 1.0
	else:
		_line_timer = 11.0
		_line_idx = 0

