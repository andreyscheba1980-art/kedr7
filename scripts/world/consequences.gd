class_name Consequences
extends RefCounted
## Связка «ночь → утро → ночь».
##   • Утренние поломки (Aftermath) — по тому, что было ночью: осада — окно, диверсия — дизель, буран — мачта.
##   • Не починил днём — следующей ночью платишь: окно выстуживает дом, конденсат душит дизель,
##     ослабшая оттяжка глушит Большую Землю, наледь в трубе, оборванный леер не держит карабин.
##   • Обморожение: ночью тепло падало ниже 15 — днём пальцы не гнутся (удержание E и динамо медленнее).
##   • Память маршрутов: тварь учит, где ты ходишь ночью, и ждёт там; утром у тех мест — круги следов.
## Состояние — SaveGame.flags: "damage" {поломка: true}, "frostbite", "route_heat", "route_waited".

const ROUTE_CELL := 8.0
const ROUTE_DECAY := 0.7          ## за ночь привычка «остывает» — смени тропу, и через ночь-две она отстанет
const ROUTE_MIN_HOUSE := 18.0     ## у самого дома не ждёт — там свет и дверь


# --- Поломки ---------------------------------------------------------------------------

## Порядок утренних поломок: сначала те, что вызвала эта ночь.
static func caused_chores() -> Array[StringName]:
	var out: Array[StringName] = []
	if SaveGame.flags.get("had_night_siege", false):
		out.append(&"window_broken")
	if SaveGame.flags.get("gen_sabotaged_night", false):
		out.append(&"generator_condensate")
	if SaveGame.flags.get("night_storm", false):
		out.append(&"mast_loose_cable")
	return out


## Вечером (конец дня): что не починено — переходит на ночь.
static func carry_unrepaired(active: Array[StringName], repaired: Dictionary) -> void:
	var dmg := {}
	for c in active:
		if not repaired.get(c, false) and c in [&"window_broken", &"generator_condensate", &"mast_loose_cable", &"chimney_ice", &"safety_rope_snap"]:
			dmg[c] = true
	SaveGame.flags["damage"] = dmg


static func damaged(id: StringName) -> bool:
	var d: Variant = SaveGame.flags.get("damage", {})
	return d is Dictionary and (d as Dictionary).get(id, false)


## Начало ночи: включить последствия и сказать о них одной строкой.
static func apply_night() -> void:
	SaveGame.flags["had_night_siege"] = false
	SaveGame.flags["gen_sabotaged_night"] = false
	SaveGame.flags["night_storm"] = false
	var lines: PackedStringArray = []
	if damaged(&"chimney_ice"):
		Game.chimney_iced = true
		lines.append(Loc.t(&"cons.chimney"))
	if damaged(&"generator_condensate"):
		Game.fuel_sputter = true
		lines.append(Loc.t(&"cons.gen"))
	if damaged(&"window_broken"):
		lines.append(Loc.t(&"cons.window"))
	if damaged(&"mast_loose_cable"):
		lines.append(Loc.t(&"cons.mast"))
	if damaged(&"safety_rope_snap"):
		lines.append(Loc.t(&"cons.rope"))
	if not lines.is_empty() and Game.hud != null:
		Game.hud.subtitle.call_deferred("\n".join(lines), 8.0)


## Окно выбито — печь выстывает быстрее (тепло уходит в щель)
static func stove_burn_k() -> float:
	return 1.25 if Game.is_night() and damaged(&"window_broken") else 1.0


## Оттяжка мачты ослабла — Большая Земля слышна хуже
static func mainland_k() -> float:
	return 0.8 if Game.is_night() and damaged(&"mast_loose_cable") else 1.0


static func rope_broken() -> bool:
	return Game.is_night() and damaged(&"safety_rope_snap")


# --- Обморожение -----------------------------------------------------------------------

static func note_cold(warmth: float) -> void:
	if Game.is_night() and warmth < 15.0:
		SaveGame.flags["frostbite_pending"] = true


## Начало дня: обморожение с прошлой ночи — на этот день.
static func apply_day() -> void:
	if SaveGame.flags.get("frostbite_pending", false):
		SaveGame.flags["frostbite_pending"] = false
		SaveGame.flags["frostbite"] = Game.phase_index
		if Game.hud != null:
			Game.hud.subtitle.call_deferred(Loc.t(&"cons.frostbite"), 7.0)


static func frostbitten() -> bool:
	return Game.is_day() and int(SaveGame.flags.get("frostbite", -1)) == Game.phase_index


## Множитель скорости работы руками (удержание E, динамо)
static func hands_k() -> float:
	return 0.7 if frostbitten() else 1.0


# --- Память маршрутов ------------------------------------------------------------------

static func _heat() -> Dictionary:
	var h: Variant = SaveGame.flags.get("route_heat", {})
	if not (h is Dictionary):
		h = {}
		SaveGame.flags["route_heat"] = h
	return h


static func cell_of(p: Vector3) -> String:
	return "%d_%d" % [floori(p.x / ROUTE_CELL), floori(p.z / ROUTE_CELL)]


static func cell_center(key: String) -> Vector3:
	var parts := key.split("_")
	return Vector3((float(parts[0]) + 0.5) * ROUTE_CELL, 0.0, (float(parts[1]) + 0.5) * ROUTE_CELL)


static func record_step(p: Vector3) -> void:
	if Vector2(p.x - 6.0, p.z - 3.5).length() < ROUTE_MIN_HOUSE:
		return
	var h := _heat()
	var k := cell_of(p)
	h[k] = float(h.get(k, 0.0)) + 1.0


## Начало ночи: привычки остывают; две самые хоженые клетки — где тварь будет ждать.
static func ambush_cells() -> Array[String]:
	var h := _heat()
	for k: String in h.keys():
		h[k] = float(h[k]) * ROUTE_DECAY
		if float(h[k]) < 0.5:
			h.erase(k)
	var keys: Array = h.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(h[a]) > float(h[b]))
	var out: Array[String] = []
	for k: String in keys:
		if float(h[k]) >= 6.0:      # не случайный проход, а привычка (≈ две ночи подряд)
			out.append(k)
		if out.size() >= 2:
			break
	return out


## Где тварь будет ждать — без «остывания» (для берестяной карты на схеме).
static func risky_cells() -> Array[String]:
	if Game.is_night() and Game.hunter_brain != null and "_route_cells" in Game.hunter_brain:
		var rc: Array = Game.hunter_brain.get("_route_cells")
		var o: Array[String] = []
		for c in rc:
			o.append(String(c))
		return o
	var h := _heat()
	var keys: Array = h.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(h[a]) > float(h[b]))
	var out: Array[String] = []
	for k: String in keys:
		if float(h[k]) * ROUTE_DECAY >= 6.0:
			out.append(k)
		if out.size() >= 2:
			break
	return out


static func note_waited(p: Vector3) -> void:
	var w: Variant = SaveGame.flags.get("route_waited", [])
	if not (w is Array):
		w = []
	(w as Array).append([p.x, p.z])
	SaveGame.flags["route_waited"] = w


## Утро: где тварь ждала — список точек (и очистка)
static func take_waited() -> Array:
	var w: Variant = SaveGame.flags.get("route_waited", [])
	SaveGame.flags["route_waited"] = []
	return w if w is Array else []
