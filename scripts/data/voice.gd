class_name Voice
extends RefCounted
## Озвучка и дополнительные звуки, сгенерированные отдельно (docs/ОЗВУЧКА_и_ЗВУКИ.md).
## Обработанные файлы лежат в res://assets/voice/<id>.ogg и res://assets/sfx/<id>.ogg
## (готовит tools/process_voice.py). Если файла нет — вызывающий код работает по-старому:
## субтитр без голоса или прежний звук. Поэтому озвучку можно докладывать постепенно.

const VOICE_DIR := "res://assets/voice/"
const SFX_DIR := "res://assets/sfx/"

static var _cache: Dictionary = {}


static func path(id: StringName) -> String:
	return _find(VOICE_DIR, id)


static func sfx(id: StringName) -> String:
	return _find(SFX_DIR, id)


static func has(id: StringName) -> bool:
	return path(id) != ""


static func _find(dir: String, id: StringName) -> String:
	var key := dir + String(id)
	if _cache.has(key):
		return _cache[key]
	var p := key + ".ogg"
	var found := p if ResourceLoader.exists(p) else ""
	_cache[key] = found
	return found


## Путь к озвучке реплики или запасной звук (общий «голос в эфире»), если реплика ещё не записана.
static func or_fallback(id: StringName, fallback: String) -> String:
	var p := path(id)
	return p if p != "" else fallback


static func sfx_or(id: StringName, fallback: String) -> String:
	var p := sfx(id)
	return p if p != "" else fallback


## Реплика с голосом: субтитр + файл v_<ключ> (точки → подчёркивания), если он уже записан.
## Возвращает, сколько ждать до следующей реплики (не меньше wait и не меньше длины записи).
static func say(key: StringName, wait: float, priority := 1, args: Array = []) -> float:
	var vid := StringName("v_" + String(key).replace(".", "_"))
	var dur := wait
	var p := path(vid)
	if p != "" and Game.audio != null:
		var pl := Game.audio.play_2d(p, 0.0)
		if pl != null and pl.stream != null:
			dur = maxf(wait, pl.stream.get_length() + 0.4)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(key, args), dur - 0.2, priority)
	return dur
