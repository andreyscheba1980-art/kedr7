extends Node
## Сохранение прогресса между фазами (пролог → ночь 1 → день 1 → ...). Одна ячейка, user://save.json.
## Сохраняем в начале каждой фазы: смерть ночью откатывает к началу этой же ночи.

const PATH := "user://save.json"

## Фаза: {"kind": "day"|"night", "index": int}. День 0 — пролог.
var phase := {"kind": "day", "index": 0}
var difficulty := "story"      ## "story" | "hard"
var items: Array[StringName] = []
var intercepts: Array[StringName] = []
var decoded: Array[StringName] = []
var tapes: Array[StringName] = []
var flags: Dictionary = {}
var memory_only := false         ## кооп: состояние живёт только в памяти, файл сохранения не пишется


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func new_game(diff: String) -> void:
	difficulty = diff
	phase = {"kind": "day", "index": 0}
	items.clear()
	intercepts.clear()
	decoded.clear()
	tapes.clear()
	flags = {}
	write()


func write() -> void:
	if memory_only:
		return   # кооп-ночь не трогает сохранение одиночной кампании
	var data := {
		"version": 1,
		"phase": phase,
		"difficulty": difficulty,
		"items": _to_strings(items),
		"intercepts": _to_strings(intercepts),
		"decoded": _to_strings(decoded),
		"tapes": _to_strings(tapes),
		"flags": flags,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: не удалось записать %s" % PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	if Game != null and is_instance_valid(Game) and Game.hud != null and is_instance_valid(Game.hud):
		Game.hud.show_save_toast()


func read() -> bool:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return false
	var d: Dictionary = parsed
	var ph: Dictionary = d.get("phase", {})
	phase = {"kind": String(ph.get("kind", "day")), "index": int(ph.get("index", 0))}
	difficulty = String(d.get("difficulty", "story"))
	_fill(items, d.get("items", []))
	_fill(intercepts, d.get("intercepts", []))
	_fill(decoded, d.get("decoded", []))
	_fill(tapes, d.get("tapes", []))
	var fl: Variant = d.get("flags", {})
	flags = fl if fl is Dictionary else {}
	return true


## Следующая фаза после текущей: день N → ночь N+1, ночь N → день N.
func advance() -> void:
	if phase["kind"] == "day":
		phase = {"kind": "night", "index": int(phase["index"]) + 1}
	else:
		phase = {"kind": "day", "index": int(phase["index"])}


func _to_strings(arr: Array[StringName]) -> Array:
	var out := []
	for s in arr:
		out.append(String(s))
	return out


func _fill(target: Array[StringName], src: Variant) -> void:
	target.clear()
	if src is Array:
		for s: Variant in src:
			target.append(StringName(str(s)))
