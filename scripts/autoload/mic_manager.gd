class_name MicManager
extends Node
## Менеджер аудиовхода (микрофона):
## Захватывает звук с микрофона в реальном времени через AudioEffectCapture.
## Не выводит звук обратно в динамики (изолированная немая шина).
## Вычисляет пиковую амплитуду (VU-метр) и реагирует на крик, вздох, кашель игрока:
##   • Сбивает задержку дыхания при испуге / реальном вздохе
##   • Привлекает Ырку снаружи и провоцирует удары в окна/дверь избы
##   • Модулирует стрелку передатчика рации при живой речи дежурного

signal noise_spike(level: float)
signal voice_activity(level: float)
signal frames_captured(buffer: PackedVector2Array)

const BUS_NAME := "MicInputBus"

var current_level := 0.0       ## Сглаженный уровень для VU-метра (0.0 .. 1.0)
var raw_level := 0.0           ## Мгновенный уровень
var is_speaking := false
var trigger_cooldown := 0.0

var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _initialized := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Микрофон не трогаем, пока игрок сам его не включил: иначе Windows сразу показывает
	# «микрофон используется», а шум комнаты злит Ырку у тех, кто об этом не просил.
	if Settings.mic_enabled:
		_setup_mic_bus()


func _setup_mic_bus() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return

	# Восстанавливаем выбранное устройство записи
	if Settings.mic_device != "" and Settings.mic_device != "Default":
		var devs := AudioServer.get_input_device_list()
		if devs.has(Settings.mic_device):
			AudioServer.input_device = Settings.mic_device

	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx < 0:
		bus_idx = AudioServer.get_bus_count()
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, BUS_NAME)

	# Изолируем шину от Master: направляем в Master, но полностью глушим
	AudioServer.set_bus_send(bus_idx, "Master")
	AudioServer.set_bus_mute(bus_idx, true)
	AudioServer.set_bus_volume_db(bus_idx, -80.0)

	# Создаем или находим эффект захвата
	_capture = null
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var eff := AudioServer.get_bus_effect(bus_idx, i)
		if eff is AudioEffectCapture:
			_capture = eff
			break

	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.2
		AudioServer.add_bus_effect(bus_idx, _capture, 0)

	# Запускаем проигрыватель микрофона
	if _mic_player == null:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = BUS_NAME
		_mic_player.autoplay = true
		add_child(_mic_player)
	if not _mic_player.playing:
		_mic_player.play()
	_initialized = true


func switch_device(device_name: String) -> void:
	AudioServer.input_device = device_name
	Settings.mic_device = device_name
	Settings.save()
	if _mic_player != null and is_instance_valid(_mic_player):
		_mic_player.stop()
		_mic_player.play()


func _ensure_mic_running() -> void:
	if not _initialized or _capture == null:
		_setup_mic_bus()
	elif _mic_player != null and not _mic_player.playing:
		_mic_player.play()


func _process(delta: float) -> void:
	if trigger_cooldown > 0.0:
		trigger_cooldown -= delta

	if not Settings.mic_enabled:
		current_level = 0.0
		raw_level = 0.0
		is_speaking = false
		if _mic_player != null and _mic_player.playing:
			_mic_player.stop()      # выключили в настройках — запись сразу прекращается
		return

	if not _initialized or _capture == null or _mic_player == null or not _mic_player.playing:
		_ensure_mic_running()
		if not _initialized or _capture == null:
			current_level = 0.0
			return

	var frames := _capture.get_frames_available()
	if frames > 0:
		var buffer := _capture.get_buffer(frames)
		frames_captured.emit(buffer)   # рация коопа берёт те же кадры — второй раз буфер не читаем
		var peak := 0.0
		for i in range(buffer.size()):
			var s := buffer[i]
			var amp := maxf(absf(s.x), absf(s.y))
			if amp > peak:
				peak = amp
		# Применяем усиление:
		# Микрофоны ПК без аппаратного усиления дают пик 0.015..0.05 при обычной речи.
		# Базовый множитель 6.5 преобразует это в диапазон 0.10..0.35 при чувствительности 1.0.
		var boosted := peak * 6.5 * Settings.mic_sensitivity
		raw_level = clampf(boosted, 0.0, 1.0)
	else:
		# Плавный спад мгновенного уровня при ожидании следующего фрейма
		raw_level = maxf(raw_level - delta * 5.0, 0.0)

	# Сглаживание уровня для VU-индикатора (быстрый подъем, плавный спад как у стрелочного прибора)
	if raw_level > current_level:
		current_level = lerpf(current_level, raw_level, minf(delta * 24.0, 1.0))
	else:
		current_level = lerpf(current_level, raw_level, minf(delta * 5.5, 1.0))

	var threshold: float = Settings.mic_threshold
	if current_level >= threshold:
		if not is_speaking:
			is_speaking = true
		voice_activity.emit(current_level)

		if trigger_cooldown <= 0.0:
			trigger_cooldown = 1.35
			noise_spike.emit(current_level)
			_trigger_gameplay_reaction(current_level)
	elif current_level < threshold * 0.70:
		is_speaking = false


func _trigger_gameplay_reaction(level: float) -> void:
	if Game == null or Game.player == null or Game.dead or Game.dying or Game.shift_over:
		return
	# В коопе мир слышит только то, что сказано в рацию: болтовня в Discord Ырку не зовёт,
	# а вот передача с улицы — зовёт.
	if Net.role != "" and not Net.talking:
		return

	var p := Game.player
	# 1. Если дежурный задерживал дыхание (прятался) — крик/вздох выдаёт его!
	if p.holding_breath:
		p.holding_breath = false
		p.breath_stamina = 0.0
		p._on_breath_released()
		Game.hud.subtitle(Loc.t(&"sub.mic_gasp"), 2.5, 2)
		p.shake(0.04, 0.3)
		Director.add_tension(15.0, "срыв дыхания в микрофон")

	# 2. Если на улице — звук мгновенно привлекает Ырку
	if Game.is_outside():
		if Game.yrka != null and is_instance_valid(Game.yrka) and Game.yrka.enabled:
			Game.yrka.notice_sound(p.global_position, level)
			Game.hud.subtitle(Loc.t(&"sub.mic_alert"), 2.0)
		EventBus.noise_emitted.emit(p.global_position, level * 2.0, &"mic")
		if Game.audio != null and Game.audio.has_method(&"record_player_noise"):
			Game.audio.record_player_noise(p.global_position)

	# 3. Если внутри избы ночью — тварь за окном или на крыше слышит шум
	elif Game.is_indoors() and Game.is_night():
		if Director != null and (Director.tension > 30.0 or Game.after_hour(1)):
			Director.add_tension(10.0 * level, "шум в микрофон в избе")
			# Сотрясение или стук снаружи
			var knock_snd := "res://assets/audio/knock_v2.ogg"
			var pos := p.global_position + Vector3(Game.rng.randf_range(-2.5, 2.5), 0.5, Game.rng.randf_range(-2.5, 2.5))
			Game.audio.play_3d(knock_snd, pos, 2.5, 10.0)
			p.shake(0.02, 0.2)
			Game.hud.subtitle(Loc.t(&"sub.mic_alert"), 2.0)
