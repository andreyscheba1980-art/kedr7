# res://scripts/autoload/audio_mix.gd
extends Node

## Звуковые шины и эффект приглушения улицы изнутри избы (LowPass filter).
var _bus_idx := -1
var _lp: AudioEffectLowPassFilter = null

func _ready() -> void:
	_bus_idx = AudioServer.get_bus_index(&"Outdoor")
	if _bus_idx == -1:
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, &"Outdoor")
		AudioServer.set_bus_send(_bus_idx, &"Master")
	
	for i in range(AudioServer.get_bus_effect_count(_bus_idx)):
		var eff := AudioServer.get_bus_effect(_bus_idx, i)
		if eff is AudioEffectLowPassFilter:
			_lp = eff
			break
	if _lp == null:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 18000.0
		AudioServer.add_bus_effect(_bus_idx, _lp)

func set_indoor(amount: float) -> void:  # 1 = внутри, дверь закрыта
	if _lp != null:
		_lp.cutoff_hz = lerpf(18000.0, 700.0, clampf(amount, 0.0, 1.0))
