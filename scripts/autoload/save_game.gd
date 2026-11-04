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
	if FileAccess.file_exists(PATH):
		return true
	return try_migrate_legacy_saves()


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
		"version": 2,
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
	if not FileAccess.file_exists(PATH):
		try_migrate_legacy_saves()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return false
	var d: Dictionary = parsed
	_sanitize_data(d)
	var ph: Dictionary = d.get("phase", {})
	phase = {"kind": String(ph.get("kind", "day")), "index": int(ph.get("index", 0))}
	difficulty = String(d.get("difficulty", "story"))
	_fill(items, d.get("items", []))
	_fill(intercepts, d.get("intercepts", []))
	_fill(decoded, d.get("decoded", []))
	_fill(tapes, d.get("tapes", []))
	var fl: Variant = d.get("flags", {})
	flags = fl if fl is Dictionary else {}
	# Обновляем очищенное состояние обратно в файл
	write()
	return true


## Автоматический поиск и миграция сохранений из прошлых версий игры и портативных папок
func try_migrate_legacy_saves() -> bool:
	if FileAccess.file_exists(PATH):
		return true

	var candidates: Array[String] = []

	# 1. Портативные сохранения рядом с Kedr7.exe:
	var exe_dir := OS.get_executable_path().get_base_dir()
	if exe_dir != "":
		candidates.append(exe_dir.path_join("save.json"))
		candidates.append(exe_dir.path_join("user").path_join("save.json"))

	# 2. Соседние папки с версиями (если распаковали v1.40.0 рядом со старой v1.38/v1.39):
	var parent_dir := exe_dir.get_base_dir()
	if parent_dir != "" and DirAccess.dir_exists_absolute(parent_dir):
		var da := DirAccess.open(parent_dir)
		if da != null:
			da.list_dir_begin()
			var dname := da.get_next()
			while dname != "":
				if da.current_is_dir() and dname.begins_with("Kedr7") and dname != exe_dir.get_file():
					candidates.append(parent_dir.path_join(dname).path_join("save.json"))
					candidates.append(parent_dir.path_join(dname).path_join("user").path_join("save.json"))
				dname = da.get_next()

	# 3. Альтернативные имена папки app_userdata в AppData:
	var user_base := OS.get_user_data_dir().get_base_dir()
	if user_base != "" and DirAccess.dir_exists_absolute(user_base):
		for alt in ["Kedr7", "Kedr-7", "kedr7", "Kedr 7", "kedr-7"]:
			var alt_path := user_base.path_join(alt).path_join("save.json")
			if alt_path != PATH and not candidates.has(alt_path):
				candidates.append(alt_path)

	for cand in candidates:
		if FileAccess.file_exists(cand):
			var f := FileAccess.open(cand, FileAccess.READ)
			if f != null:
				var txt := f.get_as_text()
				var parsed: Variant = JSON.parse_string(txt)
				if parsed is Dictionary and (parsed as Dictionary).has("phase"):
					print("[SaveGame] Обнаружено сохранение от прошлой версии: ", cand)
					var bak := FileAccess.open("user://save_legacy_backup.json", FileAccess.WRITE)
					if bak != null:
						bak.store_string(txt)
					var out := FileAccess.open(PATH, FileAccess.WRITE)
					if out != null:
						out.store_string(txt)
						print("[SaveGame] Сохранение успешно перенесено в ", PATH)
						return true
	return false


## Санация данных сохранения: сброс опасных временных флагов, чтобы игрок не застревал
func _sanitize_data(d: Dictionary) -> void:
	var fl: Variant = d.get("flags", {})
	if fl is Dictionary:
		var fld := fl as Dictionary
		# Сбрасываем флаг езды на снегоходе (чтобы не застрять в режиме вождения без снегохода)
		fld["riding"] = false
		fld["in_cabin"] = false
		fld.erase("cp")
		fld.erase("temp_pos")
		# Если в прологе уже дошли до станции:
		if fld.get("prologue_arrived", false) and int(d.get("phase", {}).get("index", 0)) == 0:
			d["phase"] = {"kind": "night", "index": 1}

	var ph: Variant = d.get("phase", {})
	if ph is Dictionary:
		var phd := ph as Dictionary
		var kind := String(phd.get("kind", "day"))
		if kind != "day" and kind != "night":
			kind = "day"
		var idx := clampi(int(phd.get("index", 0)), 0, 4)
		d["phase"] = {"kind": kind, "index": idx}


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
