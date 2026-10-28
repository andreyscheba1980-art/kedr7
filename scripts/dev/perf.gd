class_name Perf
extends RefCounted
## Метки времени загрузки (только в отладочной сборке): где тормозит запуск фазы.

static var _last := 0


static func mark(label: String) -> void:
	if not OS.is_debug_build():
		return
	var now := Time.get_ticks_msec()
	print("[time] %6d ms (+%5d) %s" % [now, now - _last, label])
	_last = now
