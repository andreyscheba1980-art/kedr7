# res://scripts/autoload/audio_mix.gd
extends Node

## 3 акустические зоны (Изба / Сени / Двор): динамический LowPass на шине Weather + лёгкий Reverb на Ambient.
## За закрытой дверью буран глухо давит низами (~360 Гц), в сенях — промежуточный тамбур (~1150 Гц),
## а в момент открытия двери ветер мгновенно бьёт полным спектром (18000 Гц).
var _bus_idx := -1
var _amb_idx := -1
var _lp: AudioEffectLowPassFilter = null
var _reverb: AudioEffectReverb = null
var _target_cutoff := 18000.0
var _target_wet := 0.0
var _target_room := 0.25

## Совместимость со ссылками вида `AudioMix.filter` в station.gd
var filter: AudioEffectLowPassFilter:
	get:
		_ensure_buses()
		return _lp


func _ensure_buses() -> void:
	if _lp != null and _reverb != null:
		return
	_bus_idx = AudioServer.get_bus_index(&"Weather")
	if _bus_idx == -1:
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, &"Weather")
		AudioServer.set_bus_send(_bus_idx, &"Master")

	for i in range(AudioServer.get_bus_effect_count(_bus_idx)):
		var eff := AudioServer.get_bus_effect(_bus_idx, i)
		if eff is AudioEffectLowPassFilter:
			_lp = eff
			break
	if _lp == null:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 18000.0
		_lp.resonance = 0.55
		AudioServer.add_bus_effect(_bus_idx, _lp, 0)

	# Лёгкая реверберация ставится на шину Ambient (а не на SFX, чтобы 2D-клики и голос оставались сухими и чёткими)
	_amb_idx = AudioServer.get_bus_index(&"Ambient")
	if _amb_idx == -1:
		AudioServer.add_bus()
		_amb_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_amb_idx, &"Ambient")
		AudioServer.set_bus_send(_amb_idx, &"Master")
	for i in range(AudioServer.get_bus_effect_count(_amb_idx)):
		var eff := AudioServer.get_bus_effect(_amb_idx, i)
		if eff is AudioEffectReverb:
			_reverb = eff
			break
	if _reverb == null:
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.28
		_reverb.damping = 0.72
		_reverb.wet = 0.0
		_reverb.dry = 1.0
		AudioServer.add_bus_effect(_amb_idx, _reverb)


func _ready() -> void:
	call_deferred(&"_ensure_buses")


func _process(delta: float) -> void:
	if _lp == null or _reverb == null:
		_ensure_buses()
	if _lp != null:
		# При открытии двери (рост частоты) — почти мгновенный удар ветра; при закрытии — быстрое приглушение.
		var spd := 22.0 if _target_cutoff > _lp.cutoff_hz else 9.0
		_lp.cutoff_hz = lerpf(_lp.cutoff_hz, _target_cutoff, minf(delta * spd, 1.0))
	if _reverb != null:
		_reverb.wet = lerpf(_reverb.wet, _target_wet, minf(delta * 5.0, 1.0))
		_reverb.room_size = lerpf(_reverb.room_size, _target_room, minf(delta * 4.0, 1.0))


func set_indoor(amount: float) -> void:  # 1 = внутри избы, 0 = двор / открытая дверь
	_ensure_buses()
	var k := clampf(amount, 0.0, 1.0)
	_target_cutoff = lerpf(18000.0, 360.0, k)
	_target_wet = lerpf(0.02, 0.14, k)
	_target_room = lerpf(0.15, 0.30, k)
	if _lp != null and k <= 0.01:
		_lp.cutoff_hz = 18000.0


## Явная установка одной из 3 акустических зон: Изба / Сени / Двор.
func set_zone_acoustics(zone: StringName, door_open: bool) -> void:
	_ensure_buses()
	if zone in [&"bunker", &"gen_shack", &"mine", &"tunnel", &"walled", &"cellar"]:
		_target_cutoff = 520.0
		_target_wet = 0.26
		_target_room = 0.54
	elif door_open or zone in [&"yard", &"meteo", &"mast", &"shed", &"woodpile", &"forest", &"lake", &"zimnik"]:
		_target_cutoff = 18000.0
		_target_wet = 0.02
		_target_room = 0.15
		if door_open and _lp != null:
			_lp.cutoff_hz = maxf(_lp.cutoff_hz, 12000.0)   # мгновенный «удар» ветра при распахивании двери
	elif zone == &"vestibule":
		_target_cutoff = 1150.0
		_target_wet = 0.20
		_target_room = 0.44   # гулкий холодный тамбур
	else:
		# Изба / радиорубка / коридор / кладовая / чердак: глухие 360 Гц + тёплый деревянный отклик
		_target_cutoff = 360.0
		_target_wet = 0.13
		_target_room = 0.28
