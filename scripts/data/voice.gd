class_name Voice
extends RefCounted
## Озвучка и дополнительные звуки, сгенерированные отдельно (docs/ОЗВУЧКА_и_ЗВУКИ.md).
## Обработанные файлы лежат в res://assets/voice/<id>.ogg и res://assets/sfx/<id>.ogg
## (готовит tools/process_voice.py). Если файла нет — вызывающий код работает по-старому:
## субтитр без голоса или прежний звук. Поэтому озвучку можно докладывать постепенно.

const VOICE_DIR := "res://assets/voice/"
const SFX_DIR := "res://assets/sfx/"
const ZasAudioClass = preload("res://scripts/data/zas_audio.gd")

static var _cache: Dictionary = {}


static func path(_id: StringName) -> String:
	return ""


static func sfx(id: StringName) -> String:
	return _find(SFX_DIR, id)


static func has(_id: StringName) -> bool:
	return false


static func _find(dir: String, id: StringName) -> String:
	var key := dir + String(id)
	if _cache.has(key):
		return _cache[key]
	var p := key + ".ogg"
	var found := p if ResourceLoader.exists(p) else ""
	_cache[key] = found
	return found


## Запасной звук (общий «голос в эфире» / шум), если файла нет.
static func or_fallback(_id: StringName, fallback: String) -> String:
	return fallback


static func sfx_or(id: StringName, fallback: String) -> String:
	var p := sfx(id)
	return p if p != "" else fallback


## Радиопереговоры и сюжетные сигналы: радиошум / ЗАС шифр и вычисление времени чтения.
static func line(key: StringName, prefixes: Array, pos := Vector3.INF, vol := 0.0) -> float:
	if Game.audio == null:
		return 0.0
	var is_radio := false
	for pre: String in prefixes:
		if pre in ["rt_", "ml_", "st_", "num_"]:
			is_radio = true
			break
	var text := Loc.t(key)
	var dur := clampf(float(text.length()) * 0.055, 2.2, 6.0)
	if is_radio:
		ZasAudioClass.play_relay_click(true, pos)
		ZasAudioClass.play_telemetry(dur, pos, vol)
	return dur


## Реплика персонажа: кинематографичный субтитр без синтетической озвучки + расчёт времени чтения.
static func say(key: StringName, wait: float, priority := 1, args: Array = [], pos := Vector3.INF) -> float:
	var text := Loc.t(key, args)
	var read_dur := clampf(float(text.length()) * 0.055, 2.0, 5.0)
	var dur := maxf(wait, read_dur)
	var is_radio := String(key).begins_with("rt.") or String(key).begins_with("sig.")
	if is_radio and Game.audio != null:
		ZasAudioClass.play_relay_click(true, pos)
		ZasAudioClass.play_telemetry(dur, pos, -4.0 if pos != Vector3.INF else -6.0)
	if Game.hud != null:
		Game.hud.subtitle(text, dur - 0.2, priority)
	return dur

