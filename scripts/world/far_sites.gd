class_name FarSites
extends RefCounted
## Дальние точки большой карты (на «Буране»): старая метеовышка, лесосека, буровая.
## На каждой — записка (разведка засчитывается при прочтении) и канистры бензина.
## Пешком далеко и ночью страшно: на карте точки появляются, когда расчехлён «Буран».

const SITES: Array[StringName] = [&"tower", &"camp", &"drill"]
const CANS := {&"tower": 1, &"camp": 2, &"drill": 1}


static func visited(site: StringName) -> bool:
	return Game.has_flag("site_" + String(site))


static func known() -> bool:
	return Game.has_flag("buran_uncovered")


static func visited_count() -> int:
	var n := 0
	for s in SITES:
		if visited(s):
			n += 1
	return n


static func build(yard: Node3D) -> void:
	_tower(yard, Terrain.pad_pos(&"tower"))
	_camp(yard, Terrain.pad_pos(&"camp"))
	_drill(yard, Terrain.pad_pos(&"drill"))
	_zimnik_sign(yard)
	_spawn_road_markers(yard)
	# Канистры раскладываются один раз; дальше их держит общий список placed_cans.
	if not Game.has_flag("site_cans_seeded") and yard.has_method("spawn_pickup"):
		Game.set_flag("site_cans_seeded", true)
		for site: StringName in SITES:
			var c := Terrain.pad_pos(site)
			for k in int(CANS[site]):
				var p := c + Vector3(-4.0 + k * 1.1, 0.0, 6.5)
				p.y = Terrain.height(p.x, p.z)
				yard.call("spawn_pickup", &"canister", p, true, "site_cans")


static func _spawn_road_markers(yard: Node3D) -> void:
	var roads: Array[StringName] = [&"zimnik", &"tower", &"camp", &"drill"]
	for r_id: StringName in roads:
		var pts := Terrain.road_points(r_id, 38.0)
		for k in range(1, pts.size() - 1):
			var a := pts[k]
			var b := pts[k + 1]
			var fwd := (b - a).normalized()
			if fwd.length_squared() < 0.01:
				continue
			var side := Vector3(-fwd.z, 0, fwd.x).normalized()
			var side_dist := 2.5 * (-1.0 if (k % 2 == 0) else 1.0)
			var pos := a + side * side_dist
			pos.y = Terrain.height(pos.x, pos.z)
			var marker := Props.winter_road_marker()
			if marker != null:
				marker.position = pos
				marker.rotation.y = atan2(fwd.x, fwd.z)
				yard.add_child(marker)


static func _model(parent: Node3D, id: String, pos: Vector3, yaw := 0.0, collide := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var n := Models.spawn(root, "kedr/" + id, pos, yaw, -1.0, {"grime": 0.0, "bright": 1.1, "sat": 0.9, "collide": collide})
	return n


static func _note(parent: Node3D, site: StringName, pos: Vector3) -> void:
	var board := Geo.interactable(parent, Vector3(0.5, 0.6, 0.3), pos + Vector3(0, 0.9, 0), Palette.m(&"canister"), Loc.t(&"it.site_note"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(StringName("site.%s.note" % String(site))))
		if not visited(site):
			Game.set_flag("site_" + String(site), true)
			Supply.add(1, &"sup.r_site")
			Game.audio.play_3d("res://assets/audio/clank.ogg", pos, -8.0)
			FieldJobs.on_site_scouted(String(site), pos)
			SaveGame.write()
	)
	board.name = "SiteNote_" + String(site)
	var post := Geo.block(parent, Vector3(0.08, 1.2, 0.08), pos + Vector3(0, 0.6, -0.2), Palette.m(&"canister"), false)
	post.name = "SiteNotePost"


static func _tower(yard: Node3D, c: Vector3) -> void:
	_model(yard, "old_meteo_tower", c, 20.0)
	var k := Props.kung_trailer()
	k.position = c + Vector3(7.0, 0.0, 3.0)
	k.position.y = Terrain.height(k.position.x, k.position.z)
	k.rotation.y = deg_to_rad(-70.0)
	yard.add_child(k)
	_solid(yard, k.position + Vector3(0, 1.3, 0), Vector3(5.4, 2.6, 2.7), k.rotation.y)   # кузов вытянут по X модели
	for i in 3:
		var b := Props.barrel()
		b.position = c + Vector3(-5.0 + i * 0.7, 0.0, -3.5 + (i % 2) * 0.6)
		b.position.y = Terrain.height(b.position.x, b.position.z)
		yard.add_child(b)
	_note(yard, &"tower", c + Vector3(4.0, Terrain.height(c.x + 4.0, c.z + 5.0) - c.y, 5.0))
	_light(yard, c + Vector3(7.0, 3.2, 1.0), Color(1.0, 0.7, 0.4))
	SiteDressing.tower(yard, c)


static func _camp(yard: Node3D, c: Vector3) -> void:
	_model(yard, "gtt_transporter", c + Vector3(-11.0, 0.0, -9.0), 135.0)
	# Первый вагончик-КУНГ: жилой, открываемый, с тулупом геолога внутри и тёплой лампой у порога
	var k_pos0 := c + Vector3(3.8, 0.0, -10.5)
	k_pos0.y = Terrain.height(k_pos0.x, k_pos0.z)
	var k0 := Props.kung_trailer()
	k0.position = k_pos0
	k0.rotation.y = deg_to_rad(10.0)
	yard.add_child(k0)
	_enterable_kung(yard, k_pos0, k0.rotation.y)

	# Второй КУНГ: сдвинут в сторону и чуть под углом — не перекрывает двери, не мешает въезду со стороны зимника
	var k_pos1 := c + Vector3(12.2, 0.0, -8.2)
	k_pos1.y = Terrain.height(k_pos1.x, k_pos1.z)
	var k1 := Props.kung_trailer()
	k1.position = k_pos1
	k1.rotation.y = deg_to_rad(32.0)
	yard.add_child(k1)
	_solid(yard, k_pos1 + Vector3(0, 1.3, 0), Vector3(5.4, 2.6, 2.7), k1.rotation.y)

	# Уголок Найды прямо у крыльца жилого КУНГа: деревянный настил, телогрейка-подстилка, пустая жестянка, кость и следы
	_build_dog_shelter(yard, c + Vector3(1.8, 0.0, -7.2), k_pos0)

	# Штабеля брёвен вынесены западнее и севернее — центральная площадка и въезд с востока (x +10..+28) полностью свободны для «Бурана»
	for j in 3:
		var w := Props.woodpile(6.0, 1.6)
		w.position = c + Vector3(-13.5 + j * 2.6, 0.0, 9.5)
		w.position.y = Terrain.height(w.position.x, w.position.z)
		w.rotation.y = deg_to_rad(90.0)
		yard.add_child(w)
	var saw := Props.sawhorse()
	saw.position = c + Vector3(-6.0, Terrain.height(c.x - 6.0, c.z + 5.5) - c.y, 5.5)
	yard.add_child(saw)
	_note(yard, &"camp", c + Vector3(0.4, Terrain.height(c.x + 0.4, c.z - 5.2) - c.y, -5.2))
	_light(yard, c + Vector3(2.2, 3.0, -7.8), Color(1.0, 0.75, 0.45))
	SiteDressing.camp(yard, c)


static func _build_dog_shelter(yard: Node3D, bed_pos: Vector3, kung_pos: Vector3) -> void:
	var by := Terrain.height(bed_pos.x, bed_pos.z)
	var root := Node3D.new()
	root.name = "CampDogShelter"
	root.position = Vector3(bed_pos.x, by, bed_pos.z)
	root.rotation.y = 0.4
	yard.add_child(root)
	# Дощатый поддон + старая скрученная телогрейка-подстилка
	var wood_mat := Palette.m(&"wood")
	var pad := Geo.block(root, Vector3(1.05, 0.032, 0.88), Vector3(0, 0.016, 0), wood_mat, false)
	pad.name = "ShelterPallet"
	var rag_mat := StandardMaterial3D.new()
	rag_mat.albedo_color = Color(0.22, 0.26, 0.20)
	rag_mat.roughness = 0.96
	Geo.block(root, Vector3(0.84, 0.025, 0.68), Vector3(0.02, 0.038, 0.02), rag_mat, false)
	# Перевёрнутая пустая жестяная банка (миска) и обгрызенная кость рядом
	var tin_mat := StandardMaterial3D.new()
	tin_mat.albedo_color = Color(0.56, 0.56, 0.58)
	tin_mat.metallic = 0.55
	tin_mat.roughness = 0.45
	Geo.cylinder(root, 0.09, 0.055, Vector3(-0.42, 0.028, 0.34), tin_mat, false)
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.72, 0.68, 0.58)
	bone_mat.roughness = 0.85
	var bone := Geo.cylinder(root, 0.018, 0.16, Vector3(0.38, 0.022, 0.35), bone_mat, false)
	bone.rotation = Vector3(deg_to_rad(90.0), 0.55, 0.0)
	# Обрывок верёвки от полоза КУНГа к лежанке
	var rope_pts := PackedVector3Array([Vector3(bed_pos.x + 0.5, by + 0.03, bed_pos.z - 0.5), Vector3(kung_pos.x - 1.2, by + 0.08, kung_pos.z + 1.0)])
	Footprints.trail(yard, &"paw", rope_pts, by, 0.35, 0.04)
	# Тёплый оранжевый ореол у порога КУНГа + следы щенка к костровой бочке
	var prints := PackedVector3Array([
		bed_pos + Vector3(0.1, 0, 0.5),
		bed_pos + Vector3(0.8, 0, 1.3),
		bed_pos + Vector3(1.6, 0, 1.7),
		bed_pos + Vector3(2.4, 0, 1.2),
	])
	Footprints.trail(yard, &"paw", prints, by, 0.32, 0.04)


static func _enterable_kung(yard: Node3D, pos: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	# Коллизии стен, пола и потолка вагончика (кузов 5.0 x 2.4 x 2.5)
	var col_root := StaticBody3D.new()
	col_root.collision_layer = Geo.LAYER_WORLD
	col_root.collision_mask = 0
	col_root.position = pos
	col_root.rotation.y = yaw
	# Пол и крыша
	col_root.add_child(Geo.box_shape(Vector3(5.0, 0.3, 2.5), Vector3(0, 0.15, 0)))
	col_root.add_child(Geo.box_shape(Vector3(5.0, 0.3, 2.5), Vector3(0, 2.7, 0)))
	# Длинные боковые стены
	col_root.add_child(Geo.box_shape(Vector3(5.0, 2.4, 0.25), Vector3(0, 1.4, -1.2)))
	col_root.add_child(Geo.box_shape(Vector3(5.0, 2.4, 0.25), Vector3(0, 1.4, 1.2)))
	# Глухой задний торец (+X)
	col_root.add_child(Geo.box_shape(Vector3(0.25, 2.4, 2.5), Vector3(2.45, 1.4, 0)))
	# Передний торец (−X) по бокам от двери (дверь на Z=0.35)
	col_root.add_child(Geo.box_shape(Vector3(0.25, 2.4, 0.8), Vector3(-2.45, 1.4, -0.7)))
	col_root.add_child(Geo.box_shape(Vector3(0.25, 2.4, 0.8), Vector3(-2.45, 1.4, 1.0)))
	col_root.add_child(Geo.box_shape(Vector3(0.25, 0.6, 1.1), Vector3(-2.45, 2.3, 0.35)))
	yard.add_child(col_root)

	# Дверь в торце КУНГа
	var door_local := Vector3(-2.55, 1.25, 0.35)
	var door_pivot := Node3D.new()
	door_pivot.position = pos + b * door_local
	door_pivot.rotation.y = yaw
	yard.add_child(door_pivot)

	var door_mesh := Geo.block(door_pivot, Vector3(0.06, 1.9, 0.82), Vector3(0, 0, 0.41), Palette.m(&"wood"), false)
	door_mesh.name = "KungDoorMesh"

	var door_open_state := [false]
	var interior_lamp: OmniLight3D = null

	var lamp_local := Vector3(0.0, 2.2, 0.0)
	interior_lamp = OmniLight3D.new()
	interior_lamp.position = pos + b * lamp_local
	interior_lamp.light_color = Color(1.0, 0.72, 0.42)
	interior_lamp.light_energy = 1.3
	interior_lamp.omni_range = 6.5
	interior_lamp.visible = true
	yard.add_child(interior_lamp)

	var door_it := Geo.interactable(yard, Vector3(0.8, 1.9, 0.9), door_pivot.position + Vector3(0, 0.2, 0), null, Loc.t(&"it.camp_kung_door"), func(_p: Player) -> void:
		door_open_state[0] = not door_open_state[0]
		AudioDirector.play_raw("res://assets/audio/door.ogg", -4.0)
		var target_ang := deg_to_rad(-85.0) if door_open_state[0] else 0.0
		var tw := door_pivot.create_tween()
		tw.tween_property(door_pivot, "rotation:y", yaw + target_ang, 0.4).set_trans(Tween.TRANS_CUBIC)
	)
	door_it.name = "CampKungDoor"

	# Внутри КУНГа: овчинный тулуп геолога на вешалке
	var coat_pos := pos + b * Vector3(0.6, 1.45, 1.1)
	var coat_it: Interactable = null
	coat_it = Geo.interactable(yard, Vector3(0.6, 1.0, 0.5), coat_pos, Palette.m(&"cloth"), Loc.t(&"it.poi_coat_pickup"), func(_p: Player) -> void:
		if not Game.has_item(&"sheepskin_coat"):
			Game.give_item(&"sheepskin_coat")
			Game.set_flag("has_sheepskin_coat", true)
			AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.coat_found"), 5.5)
			SaveGame.write()
			if coat_it != null:
				coat_it.queue_free()
	)
	coat_it.name = "GeologistCoat"

	# Столик с запиской бригады
	var note_pos := pos + b * Vector3(1.2, 0.85, -0.6)
	var note_it := Geo.interactable(yard, Vector3(0.4, 0.3, 0.4), note_pos, Palette.m(&"paper"), Loc.t(&"it.site_note"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.camp_brigade"))
	)
	note_it.name = "CampBrigadeNote"

	# Канистра бензина на полу
	if yard.has_method("spawn_pickup"):
		var p_can := pos + b * Vector3(-1.0, 0.35, -0.7)
		yard.call("spawn_pickup", &"canister", p_can, true, "site_cans")


static func _drill(yard: Node3D, c: Vector3) -> void:
	_model(yard, "drill_rig", c, -30.0)
	_drill_balok(yard, c, deg_to_rad(-30.0))
	for i in 4:
		var b := Props.barrel()
		b.position = c + Vector3(-7.0 + (i % 2) * 0.7, 0.0, 4.0 + (i / 2) * 0.7)
		b.position.y = Terrain.height(b.position.x, b.position.z)
		yard.add_child(b)
	var cr := Props.stacked_crates()
	cr.position = c + Vector3(-6.0, Terrain.height(c.x - 6.0, c.z - 4.0) - c.y, -4.0)
	yard.add_child(cr)
	_note(yard, &"drill", c + Vector3(-4.0, Terrain.height(c.x - 4.0, c.z + 7.0) - c.y, 7.0))
	_light(yard, c + Vector3(0.0, 17.0, 0.0), Color(1.0, 0.2, 0.15), 0.8, 18.0)
	SiteDressing.drill(yard, c)


static func _drill_balok(yard: Node3D, c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	# Балок находится сбоку от буровой вышки: local (4.34, 0.0, -0.6)
	var balok_center := c + b * Vector3(4.34, 1.25, -0.6)
	var window_pos := c + b * Vector3(4.34, 1.8, 2.0)
	var door_pos := c + b * Vector3(4.34, 1.25, -0.6)

	# Теплый свет в окне бытовки буровиков
	var win_light := OmniLight3D.new()
	win_light.position = window_pos
	win_light.light_color = Color(1.0, 0.68, 0.35)
	win_light.light_energy = 1.1
	win_light.omni_range = 7.0
	yard.add_child(win_light)

	# Открываемая дверь бытовки
	var door_open := [false]
	var door_it := Geo.interactable(yard, Vector3(0.9, 1.8, 0.9), door_pos, null, Loc.t(&"it.drill_balok_door"), func(_p: Player) -> void:
		door_open[0] = not door_open[0]
		AudioDirector.play_raw("res://assets/audio/door.ogg", -4.0)
	)
	door_it.name = "DrillBalokDoor"

	# Ящик бурмастера (аккумуляторы + бензин)
	var box_pos := c + b * Vector3(5.1, 1.1, 0.2)
	var box_it := Geo.interactable(yard, Vector3(0.6, 0.5, 0.6), box_pos, Palette.m(&"metal"), Loc.t(&"it.drill_toolbox"), func(_p: Player) -> void:
		if not Game.has_flag("drill_toolbox_looted"):
			Game.set_flag("drill_toolbox_looted", true)
			Game.flash_charge = 100.0
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.drill_battery_found"), 5.0)
			if yard.has_method("spawn_pickup"):
				var can_pos := box_pos + Vector3(0, 0.4, 0)
				yard.call("spawn_pickup", &"canister", can_pos, true, "site_cans")
			SaveGame.write()
		else:
			Game.hud.subtitle(Loc.t(&"sub.drill_fuel_found"), 3.0)
	)
	box_it.name = "DrillToolbox"

	# Дневник бурового мастера Потапова
	var log_pos := c + b * Vector3(5.1, 1.1, 1.0)
	var log_it := Geo.interactable(yard, Vector3(0.4, 0.2, 0.4), log_pos, Palette.m(&"paper"), Loc.t(&"it.site_note"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.drill_potapov"))
	)
	log_it.name = "DrillPotapovLog"


static func _zimnik_sign(yard: Node3D) -> void:
	var c := Terrain.pad_pos(&"drop") + Vector3(-6.0, 0.0, -9.0)
	c.y = Terrain.height(c.x, c.z)
	var sign_model := Models.spawn(yard, "kedr/zimnik_sign", c, 0.0, -1.0, {"collide": true, "bright": 1.1, "sat": 0.95})
	if sign_model == null:
		var wood := Palette.m(&"canister")
		Geo.block(yard, Vector3(0.12, 2.4, 0.12), c + Vector3(-0.8, 1.2, 0), wood, true)
		Geo.block(yard, Vector3(0.12, 2.4, 0.12), c + Vector3(0.8, 1.2, 0), wood, true)
		var plate := Geo.block(yard, Vector3(2.2, 0.7, 0.05), c + Vector3(0, 2.0, 0), Palette.m(&"snow"), false)
		var lbl := Label3D.new()
		lbl.text = Loc.t(&"site.zimnik_sign")
		lbl.font_size = 64
		lbl.pixel_size = 0.0035
		lbl.modulate = Color(0.1, 0.1, 0.1)
		lbl.outline_size = 0
		lbl.position = Vector3(0, 0, 0.035)
		plate.add_child(lbl)


static func _solid(yard: Node3D, pos: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	body.add_child(Geo.box_shape(size))
	yard.add_child(body)


## Маячок: тусклая лампа видна издалека, по ней точку находят ночью.
static func _light(yard: Node3D, pos: Vector3, col: Color, energy := 1.2, rng := 9.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 420.0
	l.distance_fade_length = 60.0
	yard.add_child(l)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	bulb.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	bulb.material_override = m
	bulb.position = pos
	yard.add_child(bulb)
