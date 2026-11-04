class_name Supply
extends RefCounted
## Снабжение со Свердловска. За работу начисляются «пайки» (сводки, найденный метеозонд, разведка точек),
## на них по бланку заявки у рации заказываешь вещи. Вертолёт сбрасывает ящик на вертодром к утру.

## id → [цена в пайках, ключ названия, ключ описания]
const ITEMS := {
	&"dog_food": [2, &"sup.i_dog_food", &"sup.d_dog_food"],
	&"film": [1, &"sup.i_film", &"sup.d_film"],
	&"flares": [2, &"sup.i_flares", &"sup.d_flares"],
	&"fuel": [1, &"sup.i_fuel", &"sup.d_fuel"],
	&"plug": [1, &"sup.i_plug", &"sup.d_plug"],
	&"tea": [1, &"sup.i_tea", &"sup.d_tea"],
	# Снаряжение — один раз и насовсем
	&"headlight": [4, &"sup.i_headlight", &"sup.d_headlight"],
	&"flashlight": [3, &"sup.i_flashlight", &"sup.d_flashlight"],
	&"tulup": [4, &"sup.i_tulup", &"sup.d_tulup"],
}
const ORDER := [&"dog_food", &"film", &"flares", &"fuel", &"plug", &"tea", &"headlight", &"flashlight", &"tulup"]
const GEAR: Array[StringName] = [&"headlight", &"flashlight", &"tulup"]


static func has_gear(id: StringName) -> bool:
	return Game.has_flag("upg_" + String(id))
const START_RATIONS := 3


static func rations() -> int:
	return int(SaveGame.flags.get("rations", START_RATIONS))


static func add(n: int, reason: StringName) -> void:
	SaveGame.flags["rations"] = rations() + n
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sup.earned", [n, Loc.t(reason), rations()]), 4.0)


static func pending() -> Array:
	return (SaveGame.flags.get("supply_pending", []) as Array).duplicate()


static func can_order(id: StringName) -> bool:
	if GEAR.has(id) and (has_gear(id) or pending().has(String(id)) or (SaveGame.flags.get("supply_crate", []) as Array).has(String(id))):
		return false
	return ITEMS.has(id) and rations() >= int(ITEMS[id][0])


static func order(id: StringName) -> bool:
	if not can_order(id):
		return false
	SaveGame.flags["rations"] = rations() - int(ITEMS[id][0])
	var p := pending()
	p.append(String(id))
	SaveGame.flags["supply_pending"] = p
	SaveGame.write()
	return true


## Вызывается при построении двора: если есть заказ и сейчас день — на вертодроме ждёт ящик.
## Ящик прилетает «ночью», т.е. появляется в первую же дневную фазу после заказа.
static func place_crate(yard: Node3D) -> void:
	var crate_items: Array = (SaveGame.flags.get("supply_crate", []) as Array)
	if Game.is_day() and not pending().is_empty():
		crate_items = crate_items + pending()
		SaveGame.flags["supply_crate"] = crate_items
		SaveGame.flags["supply_pending"] = []
		SaveGame.flags["supply_fresh"] = true
	if crate_items.is_empty():
		return
	var pos := Vector3(44.0, 0.0, 6.0) + Vector3(1.5, 0.0, -1.5)
	var drifted := false
	if SaveGame.flags.get("supply_fresh", false):
		SaveGame.flags.erase("supply_crate_pos")
		# Сброс на парашюте: чем сильнее ветер на высоте, тем вероятнее купол снесёт мимо площадки
		var aloft := Game.synoptic.wind_aloft_speed if Game.synoptic != null else 18.0
		var rng := RandomNumberGenerator.new()
		rng.seed = Game.run_seed + Game.phase_index * 53
		if rng.randf() < clampf((aloft - 12.0) / 20.0, 0.2, 0.85):
			var az := deg_to_rad((Game.synoptic.wind_azimuth_deg if Game.synoptic != null else rng.randf() * 360.0) + 180.0 + rng.randf_range(-25.0, 25.0))
			var dist := clampf(50.0 + aloft * 3.0, 60.0, 160.0) * rng.randf_range(0.8, 1.15)
			var p := pos + Vector3(sin(az), 0.0, -cos(az)) * dist
			SaveGame.flags["supply_crate_pos"] = [p.x, p.z, rad_to_deg(az), dist]
	var cp: Variant = SaveGame.flags.get("supply_crate_pos")
	if cp is Array:
		pos = Vector3(float(cp[0]), 0.0, float(cp[1]))
		drifted = true
	if Terrain.ready():
		pos.y = Terrain.height(pos.x, pos.z)
	var root := Node3D.new()
	root.name = "SupplyCrate"
	yard.add_child(root)
	root.position = pos
	var crate := Props.stacked_crates()
	crate.scale = Vector3.ONE * 0.7
	root.add_child(crate)
	var chute := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.0, 2.2)
	chute.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.75, 0.3, 0.12)
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	chute.material_override = cm
	chute.position = Vector3(-2.0, 0.04, 0.6)
	chute.rotation = Vector3(0.05, 0.3, -0.08)
	root.add_child(chute)
	var it := Geo.interactable(root, Vector3(1.2, 1.0, 1.0), Vector3(0, 0.5, 0), null, Loc.t(&"sup.crate_prompt"), Callable())
	it.used.connect(func(p: Player) -> void:
		open_crate(p, root.global_position)
		root.queue_free())
	if drifted:
		# Радиомаяк на грузе: пищит, мигает красным — ищи по звуку
		var beep := AudioStreamPlayer3D.new()
		beep.stream = AudioDirector.cached_stream("res://assets/audio/morse_loop.ogg")
		beep.volume_db = -6.0
		beep.unit_size = 10.0
		beep.max_distance = 110.0
		beep.position = Vector3(0, 0.8, 0)
		root.add_child(beep)
		beep.play()
		var strobe := Geo.omni(root, Vector3(0, 1.4, 0), 6.0, 1.2, Color(1.0, 0.15, 0.1))
		var tw := root.create_tween().set_loops()
		tw.tween_property(strobe, "light_energy", 0.0, 0.05).set_delay(0.9)
		tw.tween_property(strobe, "light_energy", 1.2, 0.05)
		it.used.connect(func(_p: Player) -> void: SaveGame.flags.erase("supply_crate_pos"))
	if SaveGame.flags.get("supply_fresh", false) and Game.hud != null:
		SaveGame.flags["supply_fresh"] = false
		if drifted:
			var az_deg := float((cp as Array)[2])
			var sector := int(round(fposmod(az_deg, 360.0) / 45.0)) % 8
			Game.hud.subtitle(Loc.t(&"sup.crate_drifted", [Loc.t(StringName("dir8.%d" % sector)), int(round(float((cp as Array)[3]) / 10.0)) * 10]), 8.0)
		else:
			Game.hud.subtitle(Loc.t(&"sup.crate_arrived"), 5.0)


static func open_crate(p: Player, at: Vector3) -> void:
	var items: Array = SaveGame.flags.get("supply_crate", [])
	SaveGame.flags["supply_crate"] = []
	var got: PackedStringArray = []
	for s: String in items:
		var id := StringName(s)
		match id:
			&"dog_food":
				SaveGame.flags["dog_food"] = int(SaveGame.flags.get("dog_food", 0)) + 6
			&"film":
				SaveGame.flags["spare_film"] = int(SaveGame.flags.get("spare_film", 0)) + 1
			&"flares":
				Game.add_spare_flares(3)
			&"fuel":
				if Game.yard != null:
					Game.yard.spawn_pickup(&"canister", at + Vector3(1.2, 0.0, 0.6), true)
			&"plug":
				SaveGame.flags["buran_plug"] = true
			&"tea":
				SaveGame.flags["tea_tins"] = int(SaveGame.flags.get("tea_tins", 0)) + 3
			&"headlight", &"flashlight", &"tulup":
				Game.set_flag("upg_" + String(id), true)
				if id == &"headlight" and Snowmobile.instance != null:
					Snowmobile.instance.apply_upgrades()
		if ITEMS.has(id):
			got.append(Loc.t(ITEMS[id][1]))
	Game.audio.play_3d("res://assets/audio/clank.ogg", at, 0.0)
	SaveGame.write()
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sup.crate_opened", [", ".join(got)]), 6.0)


## Начисления за работу (подключается один раз на сессию).
static func hook() -> void:
	if not EventBus.report_sent.is_connected(_on_report):
		EventBus.report_sent.connect(_on_report)


static func _on_report(_index: int) -> void:
	if Game.is_prologue():
		return
	add(1, &"sup.r_report")
