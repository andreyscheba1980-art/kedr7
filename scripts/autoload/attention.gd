# res://scripts/autoload/attention.gd
extends Node

## «Внимание» Ырки (Phase 3 core).
## Шкала внимания (0..100) и уровни тревоги (tiers 0..3).
signal tier_changed(tier: int)

const TIERS := [20.0, 45.0, 75.0]
var value := 0.0
var tier := 0

func reset() -> void:
	value = 0.0
	tier = 0
	tier_changed.emit(0)

func add(a: float) -> void:
	var prev := value
	value = clampf(value + a, 0.0, 100.0)
	var delta_v := value - prev
	if delta_v > 0.5 and Director != null and not Director.in_calm_window():
		Director.add_tension(delta_v * 0.35, "внимание тайги")

func _process(dt: float) -> void:
	value = maxf(0.0, value - 1.5 * dt)  # тайга «забывает» со временем
	var t := 0
	for th in TIERS:
		if value >= th:
			t += 1
	if t != tier:
		var old_tier := tier
		tier = t
		tier_changed.emit(t)
		if t > old_tier and t >= 2 and Director != null and not Director.in_calm_window():
			Director.add_tension(float(t) * 3.0, "тревога тайги")
