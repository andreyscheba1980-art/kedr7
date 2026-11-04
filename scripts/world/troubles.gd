class_name Troubles
extends Node
## Утренние «бытовые» беды — проблема → инструмент, а не скрипт. Каждое утро (дни 1–6) из пула
## выпадают 1–2 случайные, с перекосом по погоде (мороз — мёрзнет техника, снегопад — заносит):
##   • «Буран» не заводится: масло загустело — отогреть картер паяльной лампой;
##   • солярка в канистрах — кисель: отогреть паяльной лампой, иначе канистру не взять;
##   • поленницу завалило: откопать лопатой, иначе без дров;
##   • изморозь на антенне: обстучать оттяжки черенком лопаты, иначе ночью Большую Землю хуже слышно;
##   • лиса разорила ящик с пайками у крыльца: паёк пропал — иди по лисьим следам, найдёшь пакет;
##   • шатун (с 3-го утра): ночью ломился в сарай, распорол мешок — днём бродит у одной из дальних точек.
##     Подойдёшь — рёв из ельника; не отошёл за 8 с — удар лапой. Ракета отгоняет.
## Инструменты в доме: паяльная лампа — в кладовой, лопата — в сенях, чайник — на печи.
## Кипяток из чайника заменяет паяльную лампу (но остывает на морозе — неси бегом).

const POOL: Array[StringName] = [&"buran_cold", &"canisters_gel", &"woodpile_buried", &"antenna_rime", &"fox_raid", &"bear"]
const TORCH_SOUND := "res://assets/audio/stove_add.ogg"
const SHOVEL_SOUND := "res://assets/audio/step_snow_2.ogg"
const CLANK := "res://assets/audio/clank.ogg"
const PORCH := Vector3(16.2, 0.0, 3.4)

static var instance: Troubles

var active: Array[StringName] = []
var _fixed := {}
var _nodes := {}
var _rng := RandomNumberGenerator.new()
var _bear := {}


## Мешает ли сейчас беда (неисправлено и выпала этим утром).
static func blocks(id: StringName) -> bool:
	return instance != null and is_instance_valid(instance) and id in instance.active and not instance._fixed.get(id, false)


static func fixed_today(id: StringName) -> bool:
	return instance != null and instance._fixed.get(id, false)


func _ready() -> void:
	name = "Troubles"
	if not Game.is_day() or Game.is_prologue():
		queue_free()
		return
	instance = self
	_rng.seed = Game.run_seed + Game.phase_index * 911 + 7
	_roll()
	# Двор строится вместе с сессией — ставим точки, когда он уже есть
	_build.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


func _exit_tree() -> void:
	# Не обстучал антенну — ночью тот же штраф, что и ослабшая оттяжка
	if Game.is_day() and blocks(&"antenna_rime"):
		var d: Dictionary = SaveGame.flags.get("damage", {})
		d[&"mast_loose_cable"] = true
		SaveGame.flags["damage"] = d


func _roll() -> void:
	var weights := {}
	var t := Game.synoptic.temp_dry if Game.synoptic != null else -25.0
	for id in POOL:
		weights[id] = 1.0
	weights[&"bear"] = 0.0 if Game.phase_index < 3 else 0.6
	if t <= -30.0:
		weights[&"buran_cold"] = 2.5
		weights[&"canisters_gel"] = 2.2
		weights[&"antenna_rime"] = 1.6
	if bool(SaveGame.flags.get("night_storm", false)):
		weights[&"woodpile_buried"] = 2.5
		weights[&"antenna_rime"] = 2.0
	var count := 1 if Game.phase_index <= 1 else 2
	if Game.phase_index >= 4 and _rng.randf() < 0.4:
		count = 3
	var saved: Dictionary = SaveGame.flags.get("troubles_fixed", {})
	if int(saved.get("day", -1)) == Game.phase_index:
		_fixed = (saved.get("ids", {}) as Dictionary).duplicate()
	for i in count:
		var total := 0.0
		for id: StringName in weights:
			total += float(weights[id])
		if total <= 0.0:
			break
		var r := _rng.randf() * total
		for id: StringName in weights:
			r -= float(weights[id])
			if r <= 0.0:
				active.append(id)
				weights.erase(id)
				break
	print("[troubles] утро %d: %s" % [Game.phase_index, active])


func _save_fixed() -> void:
	SaveGame.flags["troubles_fixed"] = {"day": Game.phase_index, "ids": _fixed.duplicate()}


func _build() -> void:
	if Game.yard == null:
		return
	var lines: PackedStringArray = []
	var guest := NightGuest.morning()   # что осталось от ночного гостя
	if guest != "":
		lines.append(guest)
	for id in active:
		if _fixed.get(id, false):
			continue
		match id:
			&"buran_cold":
				_build_buran()
			&"canisters_gel":
				_build_canisters()
			&"woodpile_buried":
				_build_woodpile()
			&"antenna_rime":
				_build_antenna()
			&"fox_raid":
				_build_fox()
			&"bear":
				_build_bear()
		lines.append(Loc.t(StringName("tr.morning." + String(id))))
	if not lines.is_empty() and Game.hud != null:
		get_tree().create_timer(9.0, false).timeout.connect(func() -> void:
			if Game.hud != null:
				Game.hud.subtitle("  ".join(lines), 7.0))


## Точка беды: подсказка, какой нужен инструмент; удержание E — только с ним в руках.
func _spot(id: StringName, parent: Node3D, size: Vector3, at: Vector3, tools: Array, hold: float, sound: String) -> Interactable:
	var it := Geo.interactable(parent, size, at, null, "", func(p: Player) -> void: _fix(id, p))
	it.name = "Trouble_" + String(id)
	it.prompt_provider = func() -> String:
		if _has_tool(tools):
			return Loc.t(StringName("tr.do." + String(id)))
		return Loc.t(StringName("tr.need." + String(id)))
	it.hold_check = func() -> bool: return _has_tool(tools)
	it.hold_time = hold * Consequences.hands_k()
	it.hold_sound = sound
	_nodes[id] = it
	return it


func _has_tool(tools: Array) -> bool:
	var p := Game.player
	if p == null:
		return false
	for t: StringName in tools:
		if p.held == t:
			if t == &"kettle":
				return p.kettle_heat_timer > 0.0   # остывший чайник ничего не отогреет
			return true
	return false


func _fix(id: StringName, p: Player) -> void:
	if _fixed.get(id, false):
		return
	# Изморозь обстукиваешь в ритм — не просто держишь кнопку
	if id == &"antenna_rime" and not bool(get_meta(&"rime_ok", false)):
		if not _has_tool(_tools_for(id)):
			Game.hud.subtitle(Loc.t(&"tr.need.antenna_rime"), 3.0)
			return
		RepairUI.open(&"rhythm", &"rep.t.rime", func() -> void:
			set_meta(&"rime_ok", true)
			_fix(id, p), 4)
		return
	if id != &"fox_raid" and not _has_tool(_tools_for(id)):
		Game.hud.subtitle(Loc.t(StringName("tr.need." + String(id))), 3.0)
		return
	_fixed[id] = true
	_save_fixed()
	if p.held == &"kettle":
		p.kettle_heat_timer = 0.0   # кипяток вылит
	var it: Interactable = _nodes.get(id)
	if it != null and is_instance_valid(it):
		it.queue_free()
	var deco: Node3D = _nodes.get(StringName(String(id) + "_deco"))
	if deco != null and is_instance_valid(deco):
		deco.queue_free()
	Game.hud.subtitle(Loc.t(StringName("tr.done." + String(id))), 4.5)
	Game.audio.play_3d(CLANK, p.global_position, -6.0)
	Game.add_fatigue(3.0)
	if Game.tasks != null and Game.tasks.has_method("refresh"):
		Game.tasks.refresh()


func _tools_for(id: StringName) -> Array:
	match id:
		&"buran_cold", &"canisters_gel":
			return [&"blowtorch", &"kettle"]
		&"woodpile_buried", &"antenna_rime":
			return [&"shovel"]
	return []


# --- Точки ---------------------------------------------------------------------

func _build_buran() -> void:
	var sm := Snowmobile.instance
	if sm == null:
		return
	# Иней на капоте — видно, что машина простыла
	var frost := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.02, 0.9)
	frost.mesh = bm
	frost.material_override = Palette.m(&"snow")
	frost.position = Vector3(0, 0.92, -0.6)
	sm.add_child(frost)
	_nodes[&"buran_cold_deco"] = frost
	_spot(&"buran_cold", sm, Vector3(1.2, 1.0, 1.4), Vector3(0, 0.6, -0.6), [&"blowtorch", &"kettle"], 4.0, TORCH_SOUND)


func _build_canisters() -> void:
	var at := Yard.SHED + Vector3(-0.4, 1.0, -1.6)
	_spot(&"canisters_gel", Game.yard, Vector3(0.9, 0.9, 0.9), at + Vector3(0.6, 0, 0.6), [&"blowtorch", &"kettle"], 4.0, TORCH_SOUND)


func _build_woodpile() -> void:
	var at := Yard.WOODPILE
	var root := Node3D.new()
	root.name = "WoodpileDrift"
	Game.yard.add_child(root)
	root.position = Vector3(at.x, Terrain.height(at.x, at.z), at.z)
	var blob := Props.snow_mound_mesh(2)
	for part: Array in [[Vector3(0, 0.2, 0.9), Vector3(2.4, 0.9, 0.9)], [Vector3(-1.2, 0.1, 0.5), Vector3(1.0, 0.7, 1.1)], [Vector3(1.3, 0.1, 0.6), Vector3(1.1, 0.8, 0.9)]]:
		var m := MeshInstance3D.new()
		m.mesh = blob
		m.material_override = Palette.m(&"drift")
		m.position = part[0]
		m.scale = part[1]
		root.add_child(m)
	_nodes[&"woodpile_buried_deco"] = root
	_spot(&"woodpile_buried", Game.yard, Vector3(3.0, 1.4, 1.6), root.position + Vector3(0, 0.7, 1.2), [&"shovel"], 4.5, SHOVEL_SOUND)


func _build_antenna() -> void:
	var at := Yard.MAST + Vector3(1.2, 0.0, 1.2)
	at.y = Terrain.height(at.x, at.z)
	var it := _spot(&"antenna_rime", Game.yard, Vector3(1.6, 1.8, 1.6), at + Vector3(0, 0.9, 0), [&"shovel"], 3.5, "res://assets/audio/ice_hit.ogg")
	it.hold_time = 0.0   # не удержание — ритм (RepairUI)
	it.hold_check = Callable()


func _build_fox() -> void:
	# Паёк уже пропал — ящик у крыльца разрыт
	if not _fixed.has(&"fox_taken"):
		_fixed[&"fox_taken"] = true
		SaveGame.flags["rations"] = maxi(Supply.rations() - 1, 0)
		_save_fixed()
	var a := _rng.randf_range(-0.9, 0.9) + PI * 0.5
	var dist := _rng.randf_range(38.0, 62.0)
	var route := PackedVector3Array()
	var cur := PORCH + Vector3(1.2, 0, 0.6)
	var dir := Vector3(cos(a), 0, sin(a))
	var steps := int(dist / 6.0)
	for i in steps + 1:
		var wob := Vector3(-dir.z, 0, dir.x) * sin(i * 1.3) * 2.2
		var q := cur + dir * (i * 6.0) + wob
		q.y = Terrain.height(q.x, q.z) + 0.03
		route.append(q)
	var node := Node3D.new()
	node.name = "FoxTrail"
	Game.yard.add_child(node)
	Footprints.trail(node, &"paw", route, route[0].y, 0.34, 0.04)
	_nodes[&"fox_raid_deco"] = node
	var end := route[route.size() - 1]
	var pack := Props.supply_crate()
	pack.scale = Vector3.ONE * 0.35
	pack.position = end
	pack.rotation = Vector3(0.3, _rng.randf() * TAU, 0.2)
	node.add_child(pack)
	var it := Geo.interactable(node, Vector3(1.0, 0.8, 1.0), end + Vector3(0, 0.4, 0), null, Loc.t(&"tr.do.fox_raid"), func(p: Player) -> void:
		_fix(&"fox_raid", p)
		Supply.add(1, &"tr.r_fox"))
	it.name = "Trouble_fox_raid"
	_nodes[&"fox_raid"] = it
	# Разрытый ящик у крыльца: осмотр — подсказка, куда смотреть
	var box_it := Geo.interactable(node, Vector3(0.8, 0.8, 0.8), PORCH + Vector3(1.2, 0.4, 0.6), null, Loc.t(&"tr.look.fox_raid"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"tr.hint.fox_raid"), 5.0))
	box_it.name = "FoxBox"


# --- Шатун ---------------------------------------------------------------------

func _build_bear() -> void:
	if not _fixed.has(&"bear_taken"):
		_fixed[&"bear_taken"] = true
		SaveGame.flags["rations"] = maxi(Supply.rations() - 1, 0)
		_save_fixed()
	# Следы вокруг сарая — широкие, косолапые, с когтями
	var route := PackedVector3Array()
	for i in 14:
		var a := i * 0.45
		var q := Yard.SHED + Vector3(cos(a) * (6.5 + i * 0.6), 0, sin(a) * (5.0 + i * 0.5))
		q.y = Terrain.height(q.x, q.z) + 0.03
		route.append(q)
	var node := Node3D.new()
	node.name = "BearTracks"
	Game.yard.add_child(node)
	Footprints.trail(node, &"paw", route, route[0].y, 0.9, 0.22)
	var look := Geo.interactable(node, Vector3(1.6, 1.0, 1.6), route[3] + Vector3(0, 0.5, 0), null, Loc.t(&"tr.look.bear"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"tr.hint.bear"), 6.0))
	look.name = "BearTracksLook"
	# Где бродит днём: одна из дальних точек
	var far: Array = []
	for id: StringName in DayPOIs.POI_TARGETS:
		var pp: Vector3 = DayPOIs.POI_TARGETS[id]["pos"]
		if Vector2(pp.x - 8.0, pp.z - 2.0).length() > 55.0:
			far.append(pp)
	if not far.is_empty():
		_bear = {"pos": far[_rng.randi() % far.size()], "state": &"wait", "t": 0.0}


func _process(delta: float) -> void:
	if _bear.is_empty() or Game.player == null:
		return
	var pp := Game.player.global_position
	var bp: Vector3 = _bear["pos"]
	var d := Vector2(pp.x - bp.x, pp.z - bp.z).length()
	match _bear["state"]:
		&"wait":
			if d < 28.0:
				_bear["state"] = &"roar"
				_bear["t"] = 8.0
				var at := bp + Vector3(0, 1.5, 0)
				at.y = Terrain.height(bp.x, bp.z) + 1.5
				Game.audio.play_3d("res://assets/audio/growl_v4.ogg", at, 8.0, 30.0, 0.0)
				Game.player.shake(0.06, 1.2)
				Game.hud.subtitle(Loc.t(&"bear.roar"), 6.0)
				Director.add_tension(18.0, "шатун в ельнике")
		&"roar":
			_bear["t"] = float(_bear["t"]) - delta
			if not get_tree().root.find_children("*", "Flare", true, false).is_empty():
				_bear_end(&"bear.flare")
			elif d > 26.0:
				_bear_end(&"bear.gone")
			elif float(_bear["t"]) <= 0.0:
				if d < 16.0:
					Game.hud.flash_red(0.9, 0.8)
					Game.player.shake(0.16, 0.8)
					Game.add_fatigue(30.0)
					Game.warmth = maxf(Game.warmth - 6.0, 0.0)
					Director.add_tension(25.0, "удар шатуна")
					_bear_end(&"bear.swipe")
				else:
					_bear_end(&"bear.gone")


func _bear_end(key: StringName) -> void:
	_bear["state"] = &"done"
	_fixed[&"bear"] = true
	_save_fixed()
	Game.hud.subtitle(Loc.t(key), 6.0)
