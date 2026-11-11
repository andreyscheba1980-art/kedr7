class_name SpeechChatter
extends RefCounted
## Процедурная псевдоречь / характерный речевой бубнёж (Speech Blips) для персонажей «Кедр-7».
## Заменяет синтетическую ИИ-озвучку на тактильные кинематографичные аудио-блипы (как в Signalis,
## Undertale, Celeste, Return of the Obra Dinn), синхронизированные с раскрытием субтитров.

const MIX_RATE := 22050

enum Speaker {
	MIKHALYCH,
	RADIO,
	VIKTOR,
	SEMENOV,
	GENERIC,
}

static var _blip_banks: Dictionary = {}
static var _squelch_start: AudioStreamWAV
static var _squelch_end: AudioStreamWAV
static var _player_pool: Array = []


static func init_banks() -> void:
	if not _blip_banks.is_empty():
		return
	_blip_banks[Speaker.MIKHALYCH] = _build_mikhalych_bank()
	_blip_banks[Speaker.RADIO] = _build_radio_bank()
	_blip_banks[Speaker.VIKTOR] = _build_viktor_bank()
	_blip_banks[Speaker.SEMENOV] = _build_semenov_bank()
	_blip_banks[Speaker.GENERIC] = _build_generic_bank()
	_squelch_start = _build_squelch(true)
	_squelch_end = _build_squelch(false)


## Определение спикера по тексту субтитра или ключу локализации
static func detect_speaker(text: String, key: StringName = &"") -> Speaker:
	var k := String(key).to_lower()
	if k.begins_with("cab.") or k.begins_with("driver.") or k.begins_with("hk."):
		return Speaker.MIKHALYCH
	if k.begins_with("rt.") or k.begins_with("sig.") or k.begins_with("mla.") or k.begins_with("ml."):
		return Speaker.RADIO
	if k.begins_with("fin.") or k.begins_with("mst.") or k.contains("whisper"):
		return Speaker.SEMENOV
	if k.begins_with("th."):
		return Speaker.VIKTOR

	var low := text.to_lower().strip_edges()
	if low.begins_with("михалыч:") or low.contains("михалыч"):
		return Speaker.MIKHALYCH
	if low.contains("рация:") or low.contains("диспетчер:") or low.contains("штаб:") or low.contains("большая земля:") or low.contains("зас ") or low.contains("кгц"):
		return Speaker.RADIO
	if low.contains("голос за дверью:") or low.contains("шёпот:") or low.contains("шепот:") or low.contains("семёнов:") or low.contains("семенов:") or low.contains("нечто:"):
		return Speaker.SEMENOV
	if text.begins_with("(") or text.begins_with("（"):
		return Speaker.VIKTOR
	return Speaker.GENERIC


## Запуск речевого бубнежа синхронно с машинописью субтитра
static func play_line_chatter(hud_node: Node, speaker: Speaker, text: String, type_dur: float, token: int) -> void:
	init_banks()
	if hud_node == null or not hud_node.is_inside_tree() or type_dur <= 0.05:
		return
	var total_chars := text.length()
	if total_chars <= 3 or OS.get_name() == "headless":
		return

	# Для радио — мгновенный щелчок включения тангенты (relay click)
	if speaker == Speaker.RADIO and _squelch_start != null:
		_play_stream(hud_node, _squelch_start, -13.0)

	var bank: Array = _blip_banks.get(speaker, _blip_banks[Speaker.GENERIC])
	if bank.is_empty():
		return

	# Привязка к гласным буквам для имитации речевых слогов (вместо пулемётного писка)
	const VOWELS := "аеёиоуыэюяaeiouyАЕЁИОУЫЭЮЯAEIOUY"
	var trigger_indices: Array[int] = []
	for idx in range(total_chars):
		var ch := text[idx]
		if VOWELS.contains(ch):
			if trigger_indices.is_empty() or idx - trigger_indices.back() >= 2:
				trigger_indices.append(idx)

	# Если гласных мало (числовые шифрограммы, координаты) — равномерный шаг
	if trigger_indices.size() < 2:
		var step := 3
		for idx in range(0, total_chars, step):
			trigger_indices.append(idx)

	var sound_idx := 0
	for char_pos in trigger_indices:
		var delay := (float(char_pos) / float(total_chars)) * type_dur
		var stream: AudioStreamWAV = bank[sound_idx % bank.size()]
		sound_idx += 1

		var vol := -12.0
		if speaker == Speaker.VIKTOR:
			vol = -23.0
		elif speaker == Speaker.MIKHALYCH:
			vol = -9.0
		elif speaker == Speaker.RADIO:
			vol = -10.0
		elif speaker == Speaker.SEMENOV:
			vol = -14.0

		var tw := hud_node.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if hud_node != null and hud_node.is_inside_tree() and hud_node.get("_sub_token") == token:
				_play_stream(hud_node, stream, vol, randf_range(0.96, 1.04))
		)

	# Для радио — характерный шумовой сброс тангенты (squelch tail) в конце реплики
	if speaker == Speaker.RADIO and _squelch_end != null:
		var end_tw := hud_node.create_tween()
		end_tw.tween_interval(type_dur + 0.05)
		end_tw.tween_callback(func() -> void:
			if hud_node != null and hud_node.is_inside_tree() and hud_node.get("_sub_token") == token:
				_play_stream(hud_node, _squelch_end, -15.0)
		)


static func _play_stream(parent: Node, stream: AudioStream, vol_db: float, pitch := 1.0) -> void:
	if stream == null or parent == null or not parent.is_inside_tree():
		return
	var player: AudioStreamPlayer = null
	var i := _player_pool.size() - 1
	while i >= 0:
		var p = _player_pool[i]
		if not is_instance_valid(p) or not (p is AudioStreamPlayer) or not p.is_inside_tree():
			_player_pool.remove_at(i)
		elif not p.playing:
			player = p as AudioStreamPlayer
		i -= 1
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		parent.add_child(player)
		_player_pool.append(player)
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = pitch
	player.play()


# --- Синтез голосовых банков (16-bit PCM AudioStreamWAV) -----------------------------

static func _build_mikhalych_bank() -> Array:
	var out: Array = []
	var freqs := [122.0, 134.0, 146.0, 128.0, 152.0, 138.0]
	var dur := 0.068
	var count := int(dur * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19830814
	for f in freqs:
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			var t := float(i) / float(MIX_RATE)
			var env := sin(clampf(t / dur, 0.0, 1.0) * PI)
			# Низкий гортанный формант с гармониками
			var s := sin(t * f * TAU) * 0.52 + sin(t * f * 2.0 * TAU) * 0.32 + sin(t * f * 3.0 * TAU) * 0.16
			s += (rng.randf() * 2.0 - 1.0) * 0.06
			s = tanh(s * 1.7) * 0.72 * env
			var val := clampi(int(s * 32760.0), -32767, 32767)
			bytes.encode_s16(i * 2, val)
		out.append(_make_wav(bytes))
	return out


static func _build_radio_bank() -> Array:
	var out: Array = []
	var freqs := [780.0, 1150.0, 1550.0, 920.0, 1380.0, 1050.0]
	var dur := 0.055
	var count := int(dur * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19830310
	for f in freqs:
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			var t := float(i) / float(MIX_RATE)
			var env := sin(clampf(t / dur, 0.0, 1.0) * PI)
			# Полосовой радио-сигнал с кольцевой модуляцией и шумом
			var wave := sin(t * f * TAU) * 0.60 + sin(t * (f * 1.45) * TAU) * 0.25
			var noise := (rng.randf() * 2.0 - 1.0) * 0.18
			var ring := 0.75 + 0.25 * cos(t * 310.0 * TAU)
			var s := tanh((wave + noise) * ring * 2.2) * 0.65 * env
			var val := clampi(int(s * 32760.0), -32767, 32767)
			bytes.encode_s16(i * 2, val)
		out.append(_make_wav(bytes))
	return out


static func _build_viktor_bank() -> Array:
	var out: Array = []
	var freqs := [220.0, 250.0, 235.0, 270.0]
	var dur := 0.038
	var count := int(dur * MIX_RATE)
	for f in freqs:
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			var t := float(i) / float(MIX_RATE)
			var env := pow(sin(clampf(t / dur, 0.0, 1.0) * PI), 1.6)
			var s := sin(t * f * TAU) * 0.45 * env
			var val := clampi(int(s * 32760.0), -32767, 32767)
			bytes.encode_s16(i * 2, val)
		out.append(_make_wav(bytes))
	return out


static func _build_semenov_bank() -> Array:
	var out: Array = []
	var freqs := [2200.0, 2700.0, 3100.0, 2400.0]
	var dur := 0.075
	var count := int(dur * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19831102
	for f in freqs:
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			var t := float(i) / float(MIX_RATE)
			var env := sin(clampf(t / dur, 0.0, 1.0) * PI)
			# Шелестящий шёпот с плавающими высокими частотами
			var noise := (rng.randf() * 2.0 - 1.0) * sin(t * f * TAU) * 0.42
			var breath := sin(t * 340.0 * TAU) * 0.15
			var s := (noise + breath) * env * 0.60
			var val := clampi(int(s * 32760.0), -32767, 32767)
			bytes.encode_s16(i * 2, val)
		out.append(_make_wav(bytes))
	return out


static func _build_generic_bank() -> Array:
	var out: Array = []
	var freqs := [170.0, 195.0, 185.0, 210.0]
	var dur := 0.052
	var count := int(dur * MIX_RATE)
	for f in freqs:
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			var t := float(i) / float(MIX_RATE)
			var env := sin(clampf(t / dur, 0.0, 1.0) * PI)
			var s := sin(t * f * TAU) * 0.55 * env
			var val := clampi(int(s * 32760.0), -32767, 32767)
			bytes.encode_s16(i * 2, val)
		out.append(_make_wav(bytes))
	return out


static func _build_squelch(is_start: bool) -> AudioStreamWAV:
	var dur := 0.022 if is_start else 0.075
	var count := int(dur * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19830601 if is_start else 19830602
	for i in count:
		var t := float(i) / float(MIX_RATE)
		var s := 0.0
		if is_start:
			# Резкий металлический клик реле (1800 Гц)
			var env := exp(-t * 220.0)
			s = (sin(t * 1800.0 * TAU) * 0.7 + (rng.randf() * 2.0 - 1.0) * 0.3) * env
		else:
			# Шумовой пшик размыкания тангенты (squelch burst)
			var env := exp(-t * 45.0)
			s = (rng.randf() * 2.0 - 1.0) * 0.55 * env
		var val := clampi(int(s * 32760.0), -32767, 32767)
		bytes.encode_s16(i * 2, val)
	return _make_wav(bytes)


static func _make_wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
