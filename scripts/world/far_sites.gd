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
	# Канистры раскладываются один раз; дальше их держит общий список placed_cans.
	if not Game.has_flag("site_cans_seeded") and yard.has_method("spawn_pickup"):
		Game.set_flag("site_cans_seeded", true)
		for site: StringName in SITES:
			var c := Terrain.pad_pos(site)
			for k in int(CANS[site]):
				var p := c + Vector3(-4.0 + k * 1.1, 0.0, 6.5)
				p.y = Terrain.height(p.x, p.z)
				yard.call("spawn_pickup", &"canister", p, true, "site_cans")


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
	_model(yard, "gtt_transporter", c + Vector3(-8.0, 0.0, -6.0), 140.0)
	for i in 2:
		var k := Props.kung_trailer()
		k.position = c + Vector3(6.0 + i * 4.0, 0.0, -8.0 + i * 2.0)
		k.position.y = Terrain.height(k.position.x, k.position.z)
		k.rotation.y = deg_to_rad(15.0 + i * 8.0)
		yard.add_child(k)
		_solid(yard, k.position + Vector3(0, 1.3, 0), Vector3(5.4, 2.6, 2.7), k.rotation.y)   # кузов вытянут по X модели
	# Штабеля брёвен
	for j in 3:
		var w := Props.woodpile(6.0, 1.6)
		w.position = c + Vector3(-10.0 + j * 2.6, 0.0, 8.0)
		w.position.y = Terrain.height(w.position.x, w.position.z)
		w.rotation.y = deg_to_rad(90.0)
		yard.add_child(w)
	var saw := Props.sawhorse()
	saw.position = c + Vector3(2.0, Terrain.height(c.x + 2.0, c.z + 3.0) - c.y, 3.0)
	yard.add_child(saw)
	_note(yard, &"camp", c + Vector3(3.5, Terrain.height(c.x + 3.5, c.z - 4.0) - c.y, -4.0))
	_light(yard, c + Vector3(6.0, 3.0, -5.5), Color(1.0, 0.75, 0.45))
	SiteDressing.camp(yard, c)


static func _drill(yard: Node3D, c: Vector3) -> void:
	_model(yard, "drill_rig", c, -30.0)
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


static func _zimnik_sign(yard: Node3D) -> void:
	var c := Terrain.pad_pos(&"drop") + Vector3(-6.0, 0.0, -9.0)
	c.y = Terrain.height(c.x, c.z)
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
