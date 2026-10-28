class_name Rituals
extends RefCounted
## Обереги дома: соль на пороге, нож в притолоке, простыня на зеркале (угощение домовому видно и так —
## Суседко у подпечья перестаёт подглядывать). Оберег, который ночью сработал, оставляет след —
## утром о нём строка на карточке рассвета. Так игрок узнаёт, что оберег работает, и может
## поставить завету, который этому учил, пометку «Истина».

const IDS: Array[StringName] = [&"mirror", &"knife", &"salt"]


## Оберег только что отвёл испуг. Запоминаем один раз за ночь.
static func worked(id: StringName) -> void:
	if not Game.is_night():
		return
	var key := "rit_" + String(id)
	if int(SaveGame.flags.get(key, -1)) == Game.night:
		return
	SaveGame.flags[key] = Game.night
	if OS.is_debug_build():
		print("[rit] оберег сработал: ", id)


static func worked_tonight(id: StringName) -> bool:
	return int(SaveGame.flags.get("rit_" + String(id), -1)) == Game.night


## Строки для утренней карточки: следы сработавших этой ночью оберегов.
static func morning_lines() -> String:
	var out: PackedStringArray = []
	for id in IDS:
		if worked_tonight(id):
			out.append(Loc.t(StringName("rit.trace_" + String(id))))
	return "\n".join(out)


## Поставлен хоть один оберег (для вечерней подготовки).
static func any_set() -> bool:
	return Game.salt_on_threshold or Game.knife_in_lintel or Game.mirror_covered or Game.spirit_treat
