class_name VolnaTubeSynthesizer
extends AudioStreamPlayer3D
## Процедурный синтезатор лампового тракта 6К4П приёмника «Волна-К».
## Генерирует:
## 1. Розовый катодный/дробовой шум (алгоритм Келлетта) + прострелы анодного резистора (popcorn noise).
## 2. Фон накала (50 Гц) и пульсации выпрямителя 5Ц4С (100 Гц), зависящие от напряжения сети ДГА-24.
## 3. Микрофонный эффект витой сетки 6К4П (~1185 Гц) от шагов игрока, ударов по столу и хлопков дверей.
## 4. Падающие дисперсионные ионосферные свисты (Whistlers 3000 -> 300 Гц).

@export_range(0.0, 1.0) var receiver_gain: float = 0.55      # Ручка «УСИЛЕНИЕ ВЧ/НЧ»
@export_range(0.0, 1.0) var carrier_suppression: float = 0.0 # Подавление шума АРУ при точной настройке на станцию
@export var grid_voltage: float = 220.0                     # Напряжение сети от ДГА-24

var _playback: AudioStreamGeneratorPlayback
var _phase_50hz: float = 0.0
var _phase_100hz: float = 0.0
var _phase_microphonic: float = 0.0
var _microphonic_amp: float = 0.0 # Амплитуда звона сетки 6К4П от внешних сотрясений

# Переменные фильтрации розового шума (алгоритм Пола Келлетта)
var _b0: float = 0.0
var _b1: float = 0.0
var _b2: float = 0.0

# Переменные ионосферного свиста (Whistler)
var _whistler_freq: float = 0.0
var _whistler_phase: float = 0.0
var _whistler_amp: float = 0.0


func _ready() -> void:
	name = "VolnaTubeSynthesizer"
	bus = &"Radio"
	max_distance = 6.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	stream = gen
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_fill_tube_buffer()
	# Случайная генерация ионосферного свиста раз в 15–30 секунд
	if _whistler_amp <= 0.001 and randf() < delta * 0.04:
		_whistler_freq = randf_range(2600.0, 3400.0)
		_whistler_amp = randf_range(0.08, 0.18)


## Вызывается при шагах игрока, ударе по столу, закручивании крышки барографа или броске дров в печь
func trigger_tube_microphonics(impact_force: float = 1.0) -> void:
	_microphonic_amp = clampf(_microphonic_amp + impact_force * 0.35, 0.0, 0.6)


func _fill_tube_buffer() -> void:
	if _playback == null or stream == null:
		return
	var mix_rate: float = (stream as AudioStreamGenerator).mix_rate
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	# Чем ниже напряжение дизеля, тем сильнее гудит кенотрон 5Ц4С (100 Гц)
	var hum_intensity: float = clampf((225.0 - grid_voltage) / 40.0, 0.03, 0.35)
	var agc_ducking: float = 1.0 - (carrier_suppression * 0.75)

	for i in range(frames_available):
		# 1. Дробовой и тепловой шум катода 6К4П (Аппроксимация розового шума)
		var white: float = randf_range(-1.0, 1.0)
		_b0 = 0.99765 * _b0 + white * 0.0990460
		_b1 = 0.96300 * _b1 + white * 0.2965164
		_b2 = 0.57000 * _b2 + white * 1.0526913
		var tube_hiss: float = (_b0 + _b1 + _b2 + white * 0.1848) * 0.06 * agc_ducking

		# Случайные «прострелы» окисленного анодного резистора (Popcorn noise)
		if randf() < 0.0004:
			tube_hiss += randf_range(-0.45, 0.45)

		# 2. Сетевой фон накала (50 Гц) и пульсации анодного питания (100 Гц)
		_phase_50hz = fmod(_phase_50hz + 50.0 / mix_rate, 1.0)
		_phase_100hz = fmod(_phase_100hz + 100.0 / mix_rate, 1.0)
		var power_hum: float = (sin(_phase_50hz * TAU) * 0.6 + sin(_phase_100hz * TAU) * 0.4) * hum_intensity * 0.15

		# 3. Микрофонный звон сетки лампы 6К4П (~1185 Гц с экспоненциальным затуханием)
		var microphonic_ring: float = 0.0
		if _microphonic_amp > 0.0005:
			_phase_microphonic = fmod(_phase_microphonic + 1185.0 / mix_rate, 1.0)
			microphonic_ring = sin(_phase_microphonic * TAU) * _microphonic_amp
			_microphonic_amp *= 0.9997 # Плавное затухание стеклянной колбы

		# 4. Падающий ионосферный свист (Whistler)
		var whistler_sig: float = 0.0
		if _whistler_amp > 0.001:
			_whistler_phase = fmod(_whistler_phase + _whistler_freq / mix_rate, 1.0)
			whistler_sig = sin(_whistler_phase * TAU) * _whistler_amp * agc_ducking
			_whistler_freq = maxf(280.0, _whistler_freq * 0.99985) # Дисперсионное падение тона
			_whistler_amp *= 0.99992

		var final_sample: float = (tube_hiss + power_hum + microphonic_ring + whistler_sig) * receiver_gain
		final_sample = clampf(final_sample, -0.95, 0.95)
		_playback.push_frame(Vector2(final_sample, final_sample))
