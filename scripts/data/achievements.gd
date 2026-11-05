class_name Achievements
extends RefCounted
## Достижения: хранятся отдельно от сохранения (user://achievements.cfg) — переживают «Новую игру».
## Получил — плашка в углу экрана. Список — в главном меню («Достижения»): неполученные — под замком,
## с намёком, но без разгадки.

const PATH := "user://achievements.cfg"
## id → [ключ названия, ключ описания/намёка]
const LIST := [
	&"hitchhiker", &"first_night", &"no_flash", &"reader", &"handy", &"tape",
	&"lair", &"lair_clean", &"satellite", &"turned", &"seven", &"case_closed",
]

static var _cfg: ConfigFile


static func _load() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_cfg.load(PATH)


static func has(id: StringName) -> bool:
	_load()
	return bool(_cfg.get_value("got", String(id), false))


static func unlock(id: StringName) -> void:
	if has(id) or SaveGame.memory_only:
		return
	_cfg.set_value("got", String(id), true)
	_cfg.set_value("when", String(id), Time.get_datetime_string_from_system(false, true))
	_cfg.save(PATH)
	print("[ach] ", id)
	if Game.hud != null and is_instance_valid(Game.hud):
		Game.hud.achievement_toast(Loc.t(StringName("ach.%s" % id)))


static func count() -> int:
	var n := 0
	for id: StringName in LIST:
		if has(id):
			n += 1
	return n
