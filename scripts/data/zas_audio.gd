class_name ZasAudio
extends RefCounted
## Система засекречивающей аппаратуры связи ЗАС «Эльбрус» / Т-217 (СССР, 1980-е).
## Формирует аналоговую спектральную инверсию (скремблирование), пилот-тоны полярной радиосети,
## механические щелчки реле РП-4 и шумовые хвосты размыкания тангенты (squelch burst).

const MIX_RATE := 22050
const RELAY_SFX := "res://assets/audio/ui_tick.ogg"
const SQUELCH_SFX := "res://assets/audio/radio_anomaly.ogg"

static var _cached_streams: Dictionary = {}


## Синтезирует или возвращает из кэша зашифрованный аналоговый радиопоток заданной длины.
static func get_scramble_stream(duration: float, seed_salt: int = 0) -> AudioStreamWAV:
	var rounded_dur := clampf(snappedf(duration, 0.4), 1.6, 12.0)
	var cache_key := int(rounded_dur * 10.0) ^ (seed_salt & 0x0F)
	if _cached_streams.has(cache_key):
		return _cached_streams[cache_key]

	var total_samples := int(rounded_dur * float(MIX_RATE))
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 19830521 + cache_key

	# Параметры слогов (псевдо-речь со спектральной инверсией)
	var syllable_len := int(0.13 * MIX_RATE)
	var gap_len := int(0.04 * MIX_RATE)
	var cycle := syllable_len + gap_len

	var pilot_len := int(0.12 * MIX_RATE)
	var tail_len := int(0.08 * MIX_RATE)
	var body_start := pilot_len
	var body_end := total_samples - tail_len

	var f1 := 720.0
	var f2 := 1650.0
	var f3 := 2450.0
	var target_f1 := f1
	var target_f2 := f2

	for i in range(total_samples):
		var t := float(i) / float(MIX_RATE)
		var s := 0.0

		if i < pilot_len:
			# Вводный пилот-тон 1200 Гц с нарастанием и спадом
			var env := sin((float(i) / float(pilot_len)) * PI)
			s = sin(t * 1200.0 * TAU) * 0.45 * env
			s += sin(t * 600.0 * TAU) * 0.15 * env
		elif i >= body_end:
			# Шумовой хвост сброса тангенты (squelch tail)
			var tail_p := float(i - body_end) / float(tail_len)
			var env := exp(-tail_p * 4.5)
			s = (rng.randf() * 2.0 - 1.0) * 0.35 * env
		else:
			# Тело передачи: псевдо-слоги с частотной инверсией
			var body_i := i - body_start
			var phase := body_i % cycle
			if phase < syllable_len:
				if phase == 0:
					target_f1 = rng.randf_range(580.0, 920.0)
					target_f2 = rng.randf_range(1350.0, 2150.0)
				f1 = lerpf(f1, target_f1, 0.05)
				f2 = lerpf(f2, target_f2, 0.05)

				var syl_t := float(phase) / float(syllable_len)
				var env := sin(syl_t * PI)

				# Спектральная инверсия: несущая поднесущая 3300 Гц модулируется формантами
				var wave1 := sin(t * f1 * TAU)
				var wave2 := sin(t * f2 * TAU)
				var ring := cos(t * 260.0 * TAU) # кольцевая модуляция аналогового скремблера
				var noise := (rng.randf() * 2.0 - 1.0) * 0.16

				# Инвертированное «кваканье» с насыщением
				var raw := (wave1 * 0.45 + wave2 * 0.35 + wave1 * ring * 0.3 + noise) * env
				s = tanh(raw * 1.8) * 0.52
			else:
				# Короткая пауза между слогами: коротковолновый шум эфира
				s = (rng.randf() * 2.0 - 1.0) * 0.035 + sin(t * 50.0 * TAU) * 0.02

		# Преобразование в 16-бит PCM
		var val := clampi(int(clampf(s, -1.0, 1.0) * 32760.0), -32767, 32767)
		bytes.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes

	_cached_streams[cache_key] = wav
	return wav


## Воспроизводит зашифрованную телеметрию ЗАС в 2D или 3D.
static func play_telemetry(duration: float, pos := Vector3.INF, vol_db := 0.0) -> Node:
	if Game.audio == null:
		return null
	var stream := get_scramble_stream(duration)
	var bus_name := &"Radio" if AudioServer.get_bus_index(&"Radio") >= 0 else &"Master"

	if pos == Vector3.INF:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = vol_db
		p.bus = bus_name
		Game.audio.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		return p
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = vol_db
		p3.unit_size = 4.0
		p3.max_distance = 20.0
		p3.bus = bus_name
		p3.global_position = pos
		Game.audio.add_child(p3)
		p3.play()
		p3.finished.connect(p3.queue_free)
		return p3


## Щелчок электромеханического реле включения/выключения рации.
static func play_relay_click(is_start := true, pos := Vector3.INF) -> void:
	if Game.audio == null:
		return
	var vol := -4.0 if is_start else -7.0
	var pitch := 0.82 if is_start else 1.25
	if pos == Vector3.INF:
		var p := Game.audio.play_2d(RELAY_SFX, vol)
		if p != null:
			p.pitch_scale = pitch
	else:
		var p3 := Game.audio.play_3d(RELAY_SFX, pos, vol, 3.0)
		if p3 != null:
			p3.pitch_scale = pitch
