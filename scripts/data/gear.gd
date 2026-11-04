class_name Gear
extends RefCounted
## Снаряжение с дальних точек и тайников: каждая вещь меняет игру, а не только ставит флажок.
## Список — для блокнота [Tab] (строка «Снаряжение»), эффекты — у систем, которые их спрашивают.

## id предмета → ключ строки с названием и пользой (gear.<id>)
const ITEMS: Array[StringName] = [&"thermos", &"snowshoes", &"spirit_stove", &"spark_plug", &"mansi_amulet",
	&"quartz_core", &"belt_variator", &"sheepskin_coat", &"lamp_kuzbass", &"field_radio", &"film_infra", &"birch_map"]


static func has(id: StringName) -> bool:
	return Game.has_item(id) or Game.has_flag("has_" + String(id))


static func owned() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ITEMS:
		if has(id):
			out.append(id)
	return out


static func tasks_line() -> String:
	var names: PackedStringArray = []
	for id in owned():
		names.append(Loc.t(StringName("gear." + String(id))))
	if names.is_empty():
		return ""
	return Loc.t(&"tasks.gear", [", ".join(names)])


## Выдать вещь с находки: подпись «что это и зачем» один раз.
static func grant(id: StringName) -> void:
	if has(id):
		return
	Game.give_item(id)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(StringName("gear_found." + String(id))), 6.0)
	SaveGame.write()


# --- Термос: на морозе сам выручает раз за выход (заливается дома у печки) ---------------

## Заливаешь у горячей печи (дома или в корпусе) — тепло дома питает вылазку.
static func thermos_ready() -> bool:
	return has(&"thermos") and SaveGame.flags.get("thermos_full", true)


static func refill_thermos() -> void:
	if has(&"thermos") and not SaveGame.flags.get("thermos_full", true):
		SaveGame.flags["thermos_full"] = true
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"sub.thermos_refill"), 3.0)


static func use_thermos() -> void:
	SaveGame.flags["thermos_full"] = false
	Game.warmth = minf(Game.warmth + 35.0, 100.0)
	Game.add_fatigue(-6.0)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.thermos_sip"), 4.0)
	Game.audio.play_2d("res://assets/audio/clank.ogg", -14.0)


# --- Амулет манси: раз за ночь сбивает погоню ----------------------------------------------

static func amulet_ready() -> bool:
	return has(&"mansi_amulet") and Game.is_night() and SaveGame.flags.get("amulet_night", -1) != Game.night


static func use_amulet() -> void:
	SaveGame.flags["amulet_night"] = Game.night
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.amulet_cracked"), 5.0, 2)
	Game.audio.play_2d("res://assets/audio/ice_hit.ogg", -4.0)
	Director.add_tension(-20.0, "оберег манси")
