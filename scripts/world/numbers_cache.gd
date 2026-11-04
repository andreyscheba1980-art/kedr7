class_name NumbersCache
extends RefCounted
## Цифровая станция ведёт к схрону. Ночью (со 2-й) держишь 5310 кГц — сквозь цифры проступает сбивка
## другим голосом: «…мачта… три-один-ноль… сто сорок…». Азимут от мачты и шаги. На схеме [M] —
## карандашный луч от мачты и круг поиска. На месте — каменная пирамидка с вешкой, под камнями
## армейский ящик: ракеты, пайки и записка Семёнова — это он читал цифры для сменщика.

const AZIMUTH := 310.0
const DIST := 140.0
const HEAR_TIME := 6.0

static var _armed := false


static func pos() -> Vector3:
	var a := deg_to_rad(AZIMUTH)
	var p := Yard.MAST + Vector3(sin(a), 0.0, -cos(a)) * DIST
	return Vector3(p.x, 0.0, p.z)


static func known() -> bool:
	return Game.has_flag("numcache_known")


static func found() -> bool:
	return Game.has_flag("numcache_found")


static func hook() -> void:
	if not EventBus.radio_locked.is_connected(_on_locked):
		EventBus.radio_locked.connect(_on_locked)


static func _on_locked(id: StringName) -> void:
	if id != &"numbers" or known() or _armed or not Game.is_night() or Game.night < 2 or Game.is_prologue():
		return
	_armed = true
	await Game.get_tree().create_timer(HEAR_TIME, false).timeout
	_armed = false
	if Game.radio == null or Game.radio.locked_signal() != &"numbers" or known():
		return
	Game.set_flag("numcache_known", true)
	Game.hud.subtitle(Loc.t(&"numc.heard"), 7.0)
	Game.get_tree().create_timer(7.5, false).timeout.connect(func() -> void:
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"numc.think"), 6.0))
	Director.add_tension(5.0, "сбивка в цифрах")
	SaveGame.write()


## Пирамидка из камней с вешкой и красной тряпкой; под ней ящик. Ставится всегда (найти можно и случайно).
static func build(parent: Node3D) -> void:
	var c := pos()
	c.y = Terrain.height(c.x, c.z)
	var root := Node3D.new()
	root.name = "NumbersCache"
	root.position = c
	parent.add_child(root)
	for i in 7:
		var rock := Props.boulder(i + 3)
		var a := i * TAU / 6.0
		var r := 0.0 if i == 6 else 0.55
		rock.position = Vector3(cos(a) * r, 0.25 if i < 6 else 0.7, sin(a) * r)
		rock.scale = Vector3(0.7, 0.5, 0.6) if i < 6 else Vector3(0.5, 0.4, 0.5)
		root.add_child(rock)
	var pole := Geo.cylinder(root, 0.03, 2.2, Vector3(0.2, 1.1, 0.1), Palette.m(&"wood"), false)
	pole.rotation.z = 0.08
	var rag := Geo.block(root, Vector3(0.02, 0.22, 0.34), Vector3(0.24, 2.05, 0.28), Palette.m(&"red"), false)
	rag.rotation.y = 0.4
	Geo.collider(parent, Vector3(1.6, 0.9, 1.6), c + Vector3(0, 0.45, 0))
	var it := Geo.interactable(parent, Vector3(1.6, 1.2, 1.6), c + Vector3(0, 0.6, 0), null, "", func(_p: Player) -> void:
		if found():
			Game.hud.subtitle(Loc.t(&"numc.empty"), 3.0)
			return
		Game.set_flag("numcache_found", true)
		Game.add_spare_flares(3)
		Supply.add(2, &"numc.r")
		Game.audio.play_3d("res://assets/audio/clank.ogg", c, 0.0)
		Game.hud.show_note(Loc.t(&"numc.note"))
		Director.add_tension(-8.0, "схрон Семёнова")
		SaveGame.write())
	it.name = "NumbersCacheIt"
	it.prompt_provider = func() -> String:
		return Loc.t(&"numc.it_empty") if found() else Loc.t(&"numc.it")
