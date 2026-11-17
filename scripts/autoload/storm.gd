# res://scripts/autoload/storm.gd
extends Node

## Метель и просветы (Phase 2 core).
## Единый источник правды для видимости, просветов и направления ветра.
signal clarity_changed(value: float)

var wind_dir := Vector3(0.9, 0.0, 0.4).normalized()  # на ночь фиксирован, игрок его выучит
var intensity := 0.8   # 0..1, растёт к середине ночи
var clarity := 0.0     # 0 = белая стена, 1 = просвет

var _gap_timer := 5.0
var _gap_left := 0.0

func force_gap(duration: float) -> void:
	_gap_left = maxf(_gap_left, duration)
	_gap_timer = maxf(_gap_timer, duration + 6.0)

func _process(delta: float) -> void:
	_gap_timer -= delta
	if _gap_timer <= 0.0:
		_gap_left = randf_range(1.0, 2.2) * (1.3 - intensity)
		_gap_timer = randf_range(4.0, 8.0) / maxf(intensity, 0.3)
	var target := 0.0
	if _gap_left > 0.0:
		_gap_left -= delta
		target = 1.0
	# просвет раскрывается быстро, закрывается медленнее
	clarity = move_toward(clarity, target, delta * (3.0 if target > clarity else 0.7))
	clarity_changed.emit(clarity)
