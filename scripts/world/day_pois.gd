class_name DayPOIs
extends Node3D
## Вторичные точки интереса в тайге (10 POI), дневной «тихий лавкрафтовский ужас»,
## оптический эффект гало (ложные солнца) и поддержка фотосъемки на «Зенит-Е».

const POI_TARGETS := {
	&"poi_snowmobile": {"pos": Vector3(-35.0, 0.0, -15.0), "radius": 7.0},
	&"poi_trap": {"pos": Vector3(18.0, 0.0, 52.0), "radius": 5.0},
	&"poi_tent": {"pos": Vector3(-52.0, 0.0, 12.0), "radius": 7.0},
	&"poi_shrine": {"pos": Vector3(-4.0, 0.0, -68.0), "radius": 6.0},
	&"poi_finger": {"pos": Vector3(86.0, 0.0, 16.0), "radius": 11.0},
	&"poi_tower": {"pos": Vector3(46.0, 0.0, -48.0), "radius": 8.0},
	&"poi_shaft": {"pos": Vector3(30.0, 0.0, -78.0), "radius": 7.0},
	&"poi_beacon": {"pos": Vector3(-65.0, 0.0, -40.0), "radius": 6.0},
	&"poi_sledge": {"pos": Vector3(-25.0, 0.0, 65.0), "radius": 6.0},
	&"poi_seismo": {"pos": Vector3(60.0, 0.0, -85.0), "radius": 6.0},
	&"poi_ice_mine": {"pos": Vector3(145.0, 0.0, -140.0), "radius": 9.0},
	&"poi_trelevochnik": {"pos": Vector3(-150.0, 0.0, 45.0), "radius": 8.0},
	&"poi_radar_dome": {"pos": Vector3(-140.0, 0.0, -135.0), "radius": 10.0},
	&"poi_deep_borehole": {"pos": Vector3(55.0, 0.0, 195.0), "radius": 8.0},
	&"poi_mi4": {"pos": Vector3(-165.0, 0.0, -175.0), "radius": 12.0},
}

var _yard: Yard
var _pareidolia_timer := 35.0
var _active_silhouette: Node3D = null
var _silhouette_lifetime := 0.0
var _shaft_hum_player: AudioStreamPlayer3D
var _finger_hum_player: AudioStreamPlayer3D
var _mine_hum_player: AudioStreamPlayer3D
var _tractor_radio_player: AudioStreamPlayer3D
var _radar_whisper_player: AudioStreamPlayer3D
var _borehole_drone_player: AudioStreamPlayer3D
var _tower_wind_player: AudioStreamPlayer3D
var _shrine_whisper_player: AudioStreamPlayer3D
var _mi4_wind_player: AudioStreamPlayer3D
var _solar_halo: Node3D = null
var _tower_model: Node3D = null
var _tower_pos := Vector3.ZERO


func _ready() -> void:
	_yard = get_parent() as Yard
	_build_all_pois()
	if Game.is_day():
		_build_solar_halo()
	_setup_audio_emitters()


func _exit_tree() -> void:
	if _active_silhouette != null and is_instance_valid(_active_silhouette):
		_active_silhouette.queue_free()
	_active_silhouette = null


func _process(delta: float) -> void:
	_tick_finger_magnetic_anomaly(delta)
	_tick_anomalous_pois(delta)
	if Game.is_day() and Game.is_outside():
		_tick_peripheral_pareidolia(delta)
	# Качка внешней рабочей пирамиды вышки 812 от ветра
	if _tower_model != null and Game.player != null:
		var pp := Game.player.global_position
		if pp.y > _tower_pos.y + 18.0 and Vector2(pp.x - _tower_pos.x, pp.z - _tower_pos.z).length() < 4.0:
			var w_k: float = 1.0 + (Game.weather.intensity * 2.0 if Game.weather != null else 0.5)
			if not Game.has_flag("tower_ice_cleared"):
				w_k *= 1.6
			var sway := sin(Time.get_ticks_msec() * 0.0022) * 0.015 * w_k
			_tower_model.rotation.z = sway
			if randf() < delta * 0.25:
				AudioDirector.play_raw("res://assets/sfx/cc0/log_frost_crack_v2.ogg", -12.0)


# --- 1. Построение 14 точек интереса (POI) ---

func _build_all_pois() -> void:
	_build_snowmobile(POI_TARGETS[&"poi_snowmobile"]["pos"])
	_build_trap(POI_TARGETS[&"poi_trap"]["pos"])
	_build_tent(POI_TARGETS[&"poi_tent"]["pos"])
	_build_shrine(POI_TARGETS[&"poi_shrine"]["pos"])
	_build_finger(POI_TARGETS[&"poi_finger"]["pos"])
	_build_tower(POI_TARGETS[&"poi_tower"]["pos"])
	_build_shaft(POI_TARGETS[&"poi_shaft"]["pos"])
	_build_beacon(POI_TARGETS[&"poi_beacon"]["pos"])
	_build_sledge(POI_TARGETS[&"poi_sledge"]["pos"])
	_build_seismo(POI_TARGETS[&"poi_seismo"]["pos"])
	_build_ice_mine(POI_TARGETS[&"poi_ice_mine"]["pos"])
	_build_trelevochnik(POI_TARGETS[&"poi_trelevochnik"]["pos"])
	_build_radar_dome(POI_TARGETS[&"poi_radar_dome"]["pos"])
	_build_deep_borehole(POI_TARGETS[&"poi_deep_borehole"]["pos"])
	_build_mi4_crash(POI_TARGETS[&"poi_mi4"]["pos"])
	_build_labaz()


func _place_ground_y(pos: Vector3) -> Vector3:
	var res := pos
	res.y = Terrain.height(pos.x, pos.z)
	return res


func _solid(pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	body.add_child(Geo.box_shape(size))
	add_child(body)


# 1. Заброшенный снегоход «Буран» Семёнова в овраге
func _build_snowmobile(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.soviet_snowmobile()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(35.0)
		model.rotation.z = deg_to_rad(-8.0) # завалился в наст
		add_child(model)

	_solid(p + Vector3(0, 0.6, 0), Vector3(2.6, 1.2, 1.2), deg_to_rad(35.0))

	# Капот (двигатель / свеча зажигания)
	var hood_it := Geo.interactable(self, Vector3(1.1, 0.9, 1.1), p + Vector3(-0.6, 0.6, -0.4), null, Loc.t(&"it.poi_buran_engine"), func(_pl: Player) -> void:
		if not Game.has_flag("buran_plug_looted"):
			Game.set_flag("buran_plug_looted", true)
			Game.give_item(&"spark_plug")
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.buran_plug_found"), 4.5)
		else:
			Game.hud.subtitle(Loc.t(&"sub.buran_engine_empty"), 2.5)
	)
	hood_it.name = "BuranEngine"

	# Кофр (записка Семёнова и сгущёнка)
	var trunk_it := Geo.interactable(self, Vector3(0.9, 0.8, 0.9), p + Vector3(0.7, 0.6, 0.5), null, Loc.t(&"it.poi_buran_trunk"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.buran_semenov"))
		if not Game.has_flag("buran_milk_looted"):
			Game.set_flag("buran_milk_looted", true)
			Game.warmth = minf(Game.warmth + 30.0, 100.0)
			Game.hud.subtitle(Loc.t(&"sub.buran_milk_eaten"), 4.5)
	)
	trunk_it.name = "BuranTrunk"


# 2. Охотничий капкан №5 с клочьями ватника Ырки
func _build_trap(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.hunting_trap()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-20.0)
		add_child(model)

	var trap_it := Geo.interactable(self, Vector3(1.2, 0.6, 1.2), p + Vector3(0, 0.3, 0), null, Loc.t(&"it.poi_trap"), func(_pl: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
		Game.hud.subtitle(Loc.t(&"sub.poi_trap_clamped"), 5.0)
		Director.add_tension(4.0, "охотничий капкан с ватой")
		if not Gear.has(&"snowshoes"):   # снегоступы охотника — на сучке у капкана
			Gear.grant.call_deferred(&"snowshoes")
	)
	trap_it.name = "HuntingTrap"


# 3. Слепая экспедиционная палатка 1974 г.
func _build_tent(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.expedition_tent()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(15.0)
		add_child(model)

	_solid(p + Vector3(0, 1.0, 0), Vector3(3.2, 1.8, 2.4), deg_to_rad(15.0))

	# Планшет экспедиции с полевым дневником
	var case_it := Geo.interactable(self, Vector3(0.9, 0.6, 0.9), p + Vector3(0.4, 0.4, -0.6), null, Loc.t(&"it.poi_tent_case"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.tent_geologists"))
		if not Gear.has(&"thermos"):   # в планшете — термос в войлочном чехле
			Gear.grant(&"thermos")
	)
	case_it.name = "TentFieldCase"

	# Жестяной ящик с сигнальными ракетами
	var ammo_it := Geo.interactable(self, Vector3(0.8, 0.6, 0.8), p + Vector3(-0.6, 0.3, 0.5), null, Loc.t(&"it.poi_tent_ammo"), func(_pl: Player) -> void:
		if not Game.has_flag("tent_flares_looted"):
			Game.set_flag("tent_flares_looted", true)
			Game.flares = minf(Game.flares + 2, 8)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.tent_flares_found"), 4.0)
		else:
			Game.hud.subtitle(Loc.t(&"sub.tent_ammo_empty"), 2.0)
	)
	ammo_it.name = "TentAmmoBox"


# 4. Мансийское святилище (кормушка духов с тамгами)
func _build_shrine(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.mansi_shrine()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-65.0)
		add_child(model)

	_solid(p + Vector3(0, 0.8, 0), Vector3(1.6, 1.5, 1.2), deg_to_rad(-65.0))

	# Идолы смотрят туда, куда зовут: после двух подношений — на шаманский лабаз за Чёрным логом
	if model != null and Game.has_flag("labaz_revealed"):
		var to_lab := LABAZ - p
		model.rotation.y = atan2(to_lab.x, to_lab.z)
	var shrine_it := Geo.interactable(self, Vector3(1.4, 1.2, 1.4), p + Vector3(0, 0.8, 0), null, "", _on_shrine)
	shrine_it.prompt_provider = func() -> String:
		if taiga_ready():
			return Loc.t(&"it.shrine_taiga")
		if not Game.has_flag("shrine_amulet_taken"):
			return Loc.t(&"it.poi_shrine")
		if _offered_today():
			return Loc.t(&"it.shrine_look")
		return Loc.t(&"it.shrine_offer") if Supply.rations() > 0 else Loc.t(&"it.shrine_no_offer")
	shrine_it.name = "MansiShrine"

	# Радиоприёмник «Спидола», обмотанный жилами
	var spidola := Props.mansi_radio_spidola()
	if spidola != null:
		spidola.position = p + Vector3(-0.55, 0.72, -0.2)
		spidola.rotation.y = deg_to_rad(25.0)
		add_child(spidola)

	var radio_it := Geo.interactable(self, Vector3(0.7, 0.6, 0.7), p + Vector3(-0.55, 0.75, -0.2), null, Loc.t(&"it.poi_shrine_radio"), func(_pl: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/whisper.ogg", 0.0)
		Game.hud.subtitle(Loc.t(&"sub.shrine_radio_chant"), 6.0)
		Director.add_tension(8.0, "радио Спидола у идолов")
	)
	radio_it.name = "ShrineRadioSpidola"


const LABAZ := Vector3(-200.0, 0.0, -40.0)   ## шаманский лабаз на сваях — в лесу за Чёрным логом


func _offered_today() -> bool:
	return (SaveGame.flags.get("shrine_offers", []) as Array).has(Game.phase_kind + str(Game.phase_index))


## Ночь 7, после зова: нашёл лабаз и трижды приносил дары — последнее подношение — ты сам (концовка «Тайга»).
static func taiga_ready() -> bool:
	return Game.night == 7 and Game.is_night() and Game.final_call and Game.has_flag("labaz_found") \
		and (SaveGame.flags.get("shrine_offers", []) as Array).size() >= 3


func _on_shrine(_pl: Player) -> void:
	if taiga_ready():
		var ne := get_tree().root.find_children("*", "NightEvents", true, false)
		if not ne.is_empty():
			ne[0].call(&"_on_ending_chosen", &"taiga")
			return
	if not Game.has_flag("shrine_amulet_taken"):
		Game.set_flag("shrine_amulet_taken", true)
		Game.give_item(&"mansi_amulet")
		Director.add_tension(-12.0, "мансийский оберег")
		Game.hud.subtitle(Loc.t(&"sub.shrine_amulet_taken"), 5.5)
		return
	if _offered_today() or Supply.rations() <= 0:
		var key := &"sub.shrine_points" if Game.has_flag("labaz_revealed") and not Game.has_flag("labaz_found") else &"sub.shrine_prayed"
		Game.hud.subtitle(Loc.t(key), 5.0)
		return
	# Подношение: паёк духам. Не сразу — духи отвечают к следующему приходу
	SaveGame.flags["rations"] = Supply.rations() - 1
	var offers: Array = (SaveGame.flags.get("shrine_offers", []) as Array).duplicate()
	offers.append(Game.phase_kind + str(Game.phase_index))
	SaveGame.flags["shrine_offers"] = offers
	Game.audio.play_3d("res://assets/audio/whisper.ogg", POI_TARGETS[&"poi_shrine"]["pos"] + Vector3(0, 1.0, 0), -8.0, 6.0)
	Director.add_tension(-6.0, "подношение духам")
	if offers.size() >= 2 and not Game.has_flag("labaz_revealed"):
		Game.set_flag("labaz_revealed", true)
		Game.hud.subtitle(Loc.t(&"sub.shrine_answer"), 7.0)
	else:
		Game.hud.subtitle(Loc.t(&"sub.shrine_offered"), 5.0)
	SaveGame.write()


## Шаманский лабаз: срубик на четырёх сваях, лестница-бревно с зарубками, ленты и бубенцы.
## Внутри — берестяная карта (Gear.birch_map): на схеме видно, где тварь ждёт на тропах.
func _build_labaz() -> void:
	var p := _place_ground_y(LABAZ)
	var root := Node3D.new()
	root.name = "ShamanLabaz"
	root.position = p
	root.rotation.y = deg_to_rad(20.0)
	add_child(root)
	var log_m := Palette.m(&"log")
	var wood := Palette.m(&"wood")
	var snow := Palette.m(&"snow")
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-0.7, 0.7]:
			Geo.cylinder(root, 0.13, 2.4, Vector3(sx, 1.2, sz), log_m, false)
	for i in 5:
		Geo.block(root, Vector3(2.0, 0.18, 0.18), Vector3(0, 2.5 + i * 0.19, -0.75), log_m, false)
		Geo.block(root, Vector3(2.0, 0.18, 0.18), Vector3(0, 2.5 + i * 0.19, 0.75), log_m, false)
		Geo.block(root, Vector3(0.18, 0.18, 1.5), Vector3(-0.95, 2.5 + i * 0.19, 0), log_m, false)
		Geo.block(root, Vector3(0.18, 0.18, 1.5), Vector3(0.95, 2.5 + i * 0.19, 0), log_m, false)
	for sx: float in [-1.0, 1.0]:
		var slope := Geo.block(root, Vector3(1.2, 0.06, 1.9), Vector3(sx * 0.5, 3.62, 0), wood, false)
		slope.rotation.z = sx * -0.5
		var cap := Geo.block(root, Vector3(1.2, 0.12, 1.95), Vector3(sx * 0.52, 3.72, 0), snow, false)
		cap.rotation.z = sx * -0.5
	var ladder := Geo.cylinder(root, 0.12, 3.0, Vector3(0, 1.25, 1.35), log_m, false)
	ladder.rotation.x = deg_to_rad(-25.0)
	# Ленты и бубенцы на свае
	var rag := Palette.m(&"red")
	for k in 4:
		var r := Geo.block(root, Vector3(0.04, 0.5, 0.06), Vector3(0.82, 1.6 - k * 0.12, 0.72 + k * 0.03), rag if k % 2 == 0 else Palette.m(&"white"), false)
		r.rotation.z = 0.15 * k
	_solid(p + Vector3(0, 1.4, 0), Vector3(2.0, 2.8, 1.8), deg_to_rad(20.0))
	var it := Geo.interactable(self, Vector3(1.4, 1.6, 1.4), p + Vector3(0, 1.2, 1.2).rotated(Vector3.UP, deg_to_rad(20.0)), null, "", func(_pl: Player) -> void:
		if Game.has_flag("labaz_found"):
			Game.hud.subtitle(Loc.t(&"sub.labaz_empty"), 3.5)
			return
		Game.set_flag("labaz_found", true)
		Gear.grant(&"birch_map")
		Director.add_tension(10.0, "шаманский лабаз")
		Game.audio.play_3d("res://assets/audio/whisper.ogg", p + Vector3(0, 2.5, 0), -2.0, 8.0))
	it.name = "ShamanLabazIt"
	it.prompt_provider = func() -> String:
		return Loc.t(&"it.labaz_empty") if Game.has_flag("labaz_found") else Loc.t(&"it.labaz")


# 5. «Чёртов Палец» (базальтовый останец с репером ГУГК СССР)
func _build_finger(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.chertov_finger()
	if model != null:
		model.position = p
		add_child(model)

	_solid(p + Vector3(0, 3.5, 0), Vector3(3.8, 7.0, 3.8))

	var marker_it := Geo.interactable(self, Vector3(1.6, 1.6, 1.6), p + Vector3(0, 1.4, 1.8), null, Loc.t(&"it.poi_finger"), func(_pl: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.poi_finger_marker"), 5.0)
		Director.add_tension(5.0, "осмотр Чёртова Пальца")
	)
	marker_it.name = "ChertovFingerMarker"


# 6. 24-метровая деревянная триангуляционная вышка геодезистов («Сигнал ГГС Высота 812»)
func _build_tower(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	_tower_pos = p
	var model := Props.geodetic_signal_tower()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(40.0)
		add_child(model)
		_tower_model = model

	# Опоры у основания
	_solid(p + Vector3(0, 2.0, 0), Vector3(3.6, 4.0, 3.6), deg_to_rad(40.0))

	# Верхняя смотровая площадка на высоте 19.8 м
	_solid(p + Vector3(0, 19.7, 0), Vector3(3.4, 0.2, 3.4))
	_solid(p + Vector3(1.65, 20.4, 0), Vector3(0.15, 1.2, 3.4))
	_solid(p + Vector3(-1.65, 20.4, 0), Vector3(0.15, 1.2, 3.4))
	_solid(p + Vector3(0, 20.4, 1.65), Vector3(3.4, 1.2, 0.15))
	_solid(p + Vector3(0, 20.4, -1.65), Vector3(3.4, 1.2, 0.15))

	# Лестница наверх (подъём на смотровую площадку 24м)
	var ladder_up := Geo.interactable(self, Vector3(1.2, 2.0, 1.2), p + Vector3(0, 1.0, 3.2), null, Loc.t(&"it.poi_tower_ladder"), func(pl: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -1.0)
		if pl != null:
			pl.global_position = p + Vector3(0, 20.2, 0)
			pl.velocity = Vector3.ZERO
		Game.hud.subtitle(Loc.t(&"sub.tower_climbed"), 5.5)
		Director.add_tension(7.0, "подъём на вышку 24м")
	)
	ladder_up.name = "TowerLadderUp"

	# Лестница вниз (спуск со смотровой площадки)
	var ladder_down := Geo.interactable(self, Vector3(1.2, 1.8, 1.2), p + Vector3(0, 20.5, 1.1), null, Loc.t(&"it.poi_tower_ladder_down"), func(pl: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -1.0)
		if pl != null:
			pl.global_position = p + Vector3(0, 0.2, 3.4)
			pl.velocity = Vector3.ZERO
		Game.hud.subtitle(Loc.t(&"sub.tower_descended"), 3.0)
	)
	ladder_down.name = "TowerLadderDown"

	# Визирный решетчатый барабан — срубить наледь топором
	var drum_ice_it := Geo.interactable(self, Vector3(1.6, 2.2, 1.6), p + Vector3(0, 21.6, 0), null, "", func(_pl: Player) -> void:
		if not Game.has_flag("tower_ice_cleared"):
			Game.set_flag("tower_ice_cleared", true)
			AudioDirector.play_raw("res://assets/audio/ice_hit.ogg", 2.0)
			AudioDirector.play_raw("res://assets/sfx/cc0/log_frost_crack_v2.ogg", 0.0)
			if _tower_model != null:
				var ice_node := _tower_model.find_child("DrumRimeIce", true, false)
				if ice_node != null:
					ice_node.visible = false
			Game.hud.subtitle(Loc.t(&"sub.tower_ice_cleared"), 5.0)
			Director.add_tension(8.0, "сбита наледь с визирного барабана")
		else:
			Game.hud.subtitle(Loc.t(&"sub.tower_ice_already_cleared"), 2.5)
	)
	drum_ice_it.prompt_provider = func() -> String:
		return Loc.t(&"it.tower_ice_cleared_done") if Game.has_flag("tower_ice_cleared") else Loc.t(&"it.tower_chop_ice")
	drum_ice_it.name = "TowerDrumIceChop"

	# Ящик геодезистов с сигнальными ракетами и спиртовкой
	var ammo_it := Geo.interactable(self, Vector3(1.0, 0.8, 1.0), p + Vector3(1.6, 0.4, 1.2), null, Loc.t(&"it.poi_tower"), func(_pl: Player) -> void:
		if not Game.has_flag("tower_flares_looted"):
			Game.set_flag("tower_flares_looted", true)
			Game.flares = minf(Game.flares + 2, 8)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.tower_flares_found"), 4.5)
			if not Gear.has(&"spirit_stove"):   # в ящике геодезистов — спиртовка с флягой
				Gear.grant.call_deferred(&"spirit_stove")
		else:
			Game.hud.subtitle(Loc.t(&"sub.tower_flares_empty"), 2.0)
	)
	ammo_it.name = "TriangulationTowerAmmo"


# 7. Заброшенный геологоразведочный шурф №7
func _build_shaft(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.geology_shaft()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-10.0)
		add_child(model)

	_solid(p + Vector3(0, 0.8, 0), Vector3(3.0, 1.6, 3.0), deg_to_rad(-10.0))

	var shaft_it := Geo.interactable(self, Vector3(2.2, 1.4, 2.2), p + Vector3(0, 0.9, 0), null, Loc.t(&"it.poi_shaft"), func(_pl: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.poi_shaft_void"), 5.0)
		Director.add_tension(6.0, "провал шурфа №7")
	)
	shaft_it.name = "GeologyShaftVoid"


# 8. Аварийный парашютный маяк Р-855 «Комар»
func _build_beacon(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.beacon_komar()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(55.0)
		add_child(model)

	var beacon_it := Geo.interactable(self, Vector3(1.2, 1.6, 1.2), p + Vector3(0, 1.2, 0), null, Loc.t(&"it.poi_beacon"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.komar_beacon"))
	)
	beacon_it.name = "BeaconKomar"


# 9. Занесенные снегом охотничьи нарты
func _build_sledge(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.siberian_sledge()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-30.0)
		add_child(model)

	_solid(p + Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 1.1), deg_to_rad(-30.0))

	var sledge_it := Geo.interactable(self, Vector3(1.2, 0.8, 1.2), p + Vector3(0, 0.4, 0), null, Loc.t(&"it.poi_sledge"), func(_pl: Player) -> void:
		if not Game.has_flag("sledge_berries_taken"):
			Game.set_flag("sledge_berries_taken", true)
			Game.warmth = minf(Game.warmth + 20.0, 100.0)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
			Game.hud.subtitle(Loc.t(&"sub.sledge_berries_taken"), 4.0)
		else:
			Game.hud.subtitle(Loc.t(&"sub.sledge_empty"), 2.0)
	)
	sledge_it.name = "SiberianSledge"


# 10. Сейсмопост №12 с маятником ВЭГИК
func _build_seismo(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.seismo_post()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(20.0)
		add_child(model)

	_solid(p + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.8), deg_to_rad(20.0))

	var seismo_it := Geo.interactable(self, Vector3(1.4, 1.2, 1.4), p + Vector3(0, 0.7, 0), null, Loc.t(&"it.poi_seismo"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.seismo_post_trace"))
	)
	seismo_it.name = "SeismoPost12"


# 11. Заброшенная ледяная штольня («Шурф Времени» / Горизонт-40)
func _build_ice_mine(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.mine_portal()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(45.0)
		add_child(model)

	_solid(p + Vector3(0, 1.8, 0), Vector3(3.6, 3.2, 3.6), deg_to_rad(45.0))
	# Скрытый горизонт под устьем: вход — заваленный ходок слева (знаешь о нём с кассеты Дубова)
	var mh := MineHorizon.new()
	mh.setup(p)
	add_child(mh)

	# Вагонетка в забое: инфракрасная пленка «Свема И-840»
	var cart_it := Geo.interactable(self, Vector3(1.4, 0.9, 1.4), p + Vector3(0.9, 0.5, 0.8), null, Loc.t(&"it.poi_mine_cart"), func(_pl: Player) -> void:
		if not Game.has_item(&"film_infra"):
			Game.give_item(&"film_infra")
			Game.set_flag("has_film_infra", true)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.mine_film_found"), 5.5)
			SaveGame.write()
		else:
			Game.hud.subtitle(Loc.t(&"sub.mine_cart_empty"), 2.5)
	)
	cart_it.name = "IceMineCart"

	# Доска у входа: журнал проходки Горизонта-40
	var board_it := Geo.interactable(self, Vector3(0.6, 1.2, 0.4), p + Vector3(-1.4, 1.3, 0.2), null, Loc.t(&"it.poi_mine_board"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.ice_mine_log"))
	)
	board_it.name = "IceMineLogBoard"

	# Сейсмический геофонный пост СВ-30 в скальном монолите
	var geo_box := Props.seismic_geophone_box()
	if geo_box != null:
		geo_box.position = p + Vector3(2.1, 0.35, 1.7)
		geo_box.rotation.y = deg_to_rad(30.0)
		add_child(geo_box)

	var geo_it := Geo.interactable(self, Vector3(0.9, 0.8, 0.9), p + Vector3(2.1, 0.45, 1.7), null, Loc.t(&"it.poi_geophone"), func(_pl: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/sub_drop.ogg", 1.0)
		Game.audio.play_2d("res://assets/audio/drone_loop.ogg", -2.0)
		if Game.player != null:
			Game.player.shake(0.05, 0.8)
		Game.hud.subtitle(Loc.t(&"sub.geophone_pulse"), 6.5)
		Game.hud.show_note(Loc.t(&"note.adit4_geology"))
		Director.add_tension(10.0, "сейсмо-геофон штольни №4")
	)
	geo_it.hold_time = 2.0
	geo_it.name = "AditGeophoneBox"


# 12. Вмерзший трелёвочник ТДТ-55 в Чёртовой пади
func _build_trelevochnik(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.crawler_tractor_tdt55()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-55.0)
		model.rotation.z = deg_to_rad(6.0) # завалился в овраг
		add_child(model)

	_solid(p + Vector3(0, 1.2, 0), Vector3(2.4, 2.2, 4.4), deg_to_rad(-55.0))

	# Дверь кабины трелёвочника
	var cab_door_open := [false]
	var door_it := Geo.interactable(self, Vector3(0.9, 1.4, 0.9), p + Vector3(-0.9, 1.8, -0.4), null, Loc.t(&"it.poi_tractor_door"), func(_pl: Player) -> void:
		cab_door_open[0] = not cab_door_open[0]
		AudioDirector.play_raw("res://assets/audio/door.ogg", -4.0)
	)
	door_it.name = "TractorCabDoor"

	# Ящик ЗИП за сиденьем: ремень вариатора для «Бурана»
	var tool_it := Geo.interactable(self, Vector3(0.8, 0.6, 0.8), p + Vector3(0.2, 1.4, -1.0), null, Loc.t(&"it.poi_tractor_tools"), func(_pl: Player) -> void:
		if not Game.has_item(&"belt_variator"):
			Game.give_item(&"belt_variator")
			Game.set_flag("buran_belt", true)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.tractor_belt_found"), 5.5)
			SaveGame.write()
		else:
			Game.hud.subtitle(Loc.t(&"sub.tractor_tools_empty"), 2.0)
	)
	tool_it.name = "TractorToolbox"

	# Слив дизельного топлива из бака (+25% топлива «Бурана»)
	var fuel_it := Geo.interactable(self, Vector3(0.9, 0.7, 0.9), p + Vector3(0.8, 0.9, 0.6), null, Loc.t(&"it.poi_tractor_fuel"), func(_pl: Player) -> void:
		if not Game.has_flag("tractor_fuel_looted"):
			Game.set_flag("tractor_fuel_looted", true)
			if Snowmobile.instance != null:
				Snowmobile.instance.fuel = minf(Snowmobile.instance.fuel + 25.0, 100.0)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.tractor_fuel_taken"), 4.5)
			SaveGame.write()
		else:
			Game.hud.subtitle(Loc.t(&"sub.tractor_fuel_empty"), 2.5)
	)
	fuel_it.name = "TractorFuelTank"

	# Путевой лист на приборном щитке
	var waybill_it := Geo.interactable(self, Vector3(0.5, 0.4, 0.5), p + Vector3(0.0, 1.9, -0.2), null, Loc.t(&"it.site_note"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.tractor_waybill"))
	)
	waybill_it.name = "TractorWaybill"


# 13. Белый Шар РЛС на вершине сопки («Купол ПВО»)
func _build_radar_dome(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.radar_dome()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(110.0)
		add_child(model)

	_solid(p + Vector3(0, 0.6, 0), Vector3(9.0, 1.2, 9.0))
	_solid(p + Vector3(0, 2.5, 0), Vector3(8.4, 3.8, 8.4))

	# Стойка радиоразведки: магнитная пленка «Полевой дневник Дубова»
	var rack_it := Geo.interactable(self, Vector3(1.2, 1.6, 0.9), p + Vector3(-1.8, 1.8, -1.8), null, Loc.t(&"it.poi_radar_rack"), func(_pl: Player) -> void:
		if not Game.has_item(&"tape_field"):
			Game.give_item(&"tape_field")
			Game.add_tape(&"tape_field")
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.radar_tape_found"), 5.5)
			SaveGame.write()
		else:
			Game.hud.subtitle(Loc.t(&"sub.radar_rack_empty"), 2.5)
	)
	rack_it.name = "RadarSigintRack"

	# Акт консервации на посту дежурного
	var act_it := Geo.interactable(self, Vector3(0.5, 0.3, 0.5), p + Vector3(1.6, 1.7, -1.9), null, Loc.t(&"it.site_note"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.radar_decommission"))
	)
	act_it.name = "RadarDecommissionAct"


# 14. Сверхглубокая скважина СГ-4 («Голос Бездны»)
func _build_deep_borehole(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.borehole_sg4()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-15.0)
		add_child(model)

	_solid(p + Vector3(0, 0.8, 0), Vector3(2.8, 1.6, 2.8), deg_to_rad(-15.0))

	# Акустическая труба скважины: прослушивание глубин
	var pipe_it := Geo.interactable(self, Vector3(1.0, 1.2, 1.0), p + Vector3(0.25, 1.8, 0), null, Loc.t(&"it.poi_borehole_listen"), func(_pl: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/sub_drop.ogg", 0.0)
		Game.audio.play_2d("res://assets/audio/drone_loop.ogg", -4.0)
		Game.hud.subtitle(Loc.t(&"sub.borehole_voices"), 6.0)
		Director.add_tension(12.0, "прослушивание скважины СГ-4")
		if Game.player != null:
			Game.player.shake(0.04, 0.6)
	)
	pipe_it.name = "BoreholeAcousticPipe"

	# Ящик с керном горных пород: плавленный кварц
	var core_it := Geo.interactable(self, Vector3(1.0, 0.6, 1.0), p + Vector3(-1.3, 0.5, -0.8), null, Loc.t(&"it.poi_borehole_case"), func(_pl: Player) -> void:
		if not Game.has_item(&"quartz_core"):
			Game.give_item(&"quartz_core")
			Game.set_flag("has_quartz_core", true)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.borehole_core_found"), 5.0)
			SaveGame.write()
		else:
			Game.hud.subtitle(Loc.t(&"sub.borehole_case_empty"), 2.0)
	)
	core_it.name = "BoreholeCoreCase"

	# Сводка бурения опорной скважины
	var report_it := Geo.interactable(self, Vector3(0.5, 0.3, 0.5), p + Vector3(-1.3, 0.7, 0.2), null, Loc.t(&"it.site_note"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.borehole_sg4"))
	)
	report_it.name = "BoreholeReport"


# 15. Место крушения вертолёта Ми-4 (СССР-31415)
func _build_mi4_crash(base_pos: Vector3) -> void:
	var p := _place_ground_y(base_pos)
	var model := Props.soviet_mi4_helicopter()
	if model != null:
		model.position = p
		model.rotation.y = deg_to_rad(-45.0)
		model.rotation.z = deg_to_rad(10.0) # завалился на левый борт в сугроб
		add_child(model)

	# Коллизия корпуса и разломленной хвостовой балки
	_solid(p + Vector3(0, 1.3, 0.3), Vector3(2.6, 2.5, 7.2), deg_to_rad(-45.0))
	_solid(p + Vector3(-1.8, 1.2, -3.2), Vector3(1.4, 1.6, 4.4), deg_to_rad(-17.0))

	# Кабина пилотов: бортовой журнал борта 31415
	var cockpit_it := Geo.interactable(self, Vector3(1.8, 1.8, 1.8), p + Vector3(2.2, 1.5, 2.2), null, Loc.t(&"it.poi_mi4_cockpit"), func(_pl: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.mi4_log"))
		Director.add_tension(8.0, "бортовой журнал Ми-4")
	)
	cockpit_it.name = "Mi4CockpitIt"

	# Аккумуляторный отсек / моторама: авиационный кабель и медные клеммы
	var batt_it := Geo.interactable(self, Vector3(1.2, 1.0, 1.2), p + Vector3(-0.9, 0.8, -0.6), null, Loc.t(&"it.poi_mi4_battery"), func(_pl: Player) -> void:
		if not Game.has_flag("mi4_battery_looted"):
			Game.set_flag("mi4_battery_looted", true)
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.mi4_battery_taken"), 4.5)
			Director.add_tension(5.0, "авиационный аккумулятор Ми-4")
		else:
			Game.hud.subtitle(Loc.t(&"sub.mi4_battery_empty"), 2.0)
	)
	batt_it.name = "Mi4BatteryIt"


# --- 2. Звуковые эмбиент-источники POI ---

func _setup_audio_emitters() -> void:
	# Низкочастотный подземный гул из шурфа №7
	_shaft_hum_player = AudioStreamPlayer3D.new()
	_shaft_hum_player.stream = AudioDirector.cached_stream("res://assets/audio/hum_loop.ogg")
	_shaft_hum_player.position = _place_ground_y(POI_TARGETS[&"poi_shaft"]["pos"])
	_shaft_hum_player.unit_size = 4.0
	_shaft_hum_player.max_distance = 25.0
	_shaft_hum_player.volume_db = -10.0
	_shaft_hum_player.bus = &"SFX"
	add_child(_shaft_hum_player)
	_shaft_hum_player.play()

	# Магнитный/вибрационный призвук возле Чёртова Пальца
	_finger_hum_player = AudioStreamPlayer3D.new()
	_finger_hum_player.stream = AudioDirector.cached_stream("res://assets/audio/sub_drop.ogg")
	_finger_hum_player.position = _place_ground_y(POI_TARGETS[&"poi_finger"]["pos"])
	_finger_hum_player.unit_size = 5.0
	_finger_hum_player.max_distance = 30.0
	_finger_hum_player.volume_db = -18.0
	_finger_hum_player.bus = &"SFX"
	add_child(_finger_hum_player)

	# Гудящий низкий дрон временной аномалии ледяной штольни
	_mine_hum_player = AudioStreamPlayer3D.new()
	_mine_hum_player.stream = AudioDirector.cached_stream("res://assets/audio/hum_loop.ogg")
	_mine_hum_player.pitch_scale = 0.68
	_mine_hum_player.position = _place_ground_y(POI_TARGETS[&"poi_ice_mine"]["pos"])
	_mine_hum_player.unit_size = 4.5
	_mine_hum_player.max_distance = 28.0
	_mine_hum_player.volume_db = -9.0
	_mine_hum_player.bus = &"SFX"
	add_child(_mine_hum_player)
	_mine_hum_player.play()

	# Тихое радио в кабине вмерзшего трелёвочника
	_tractor_radio_player = AudioStreamPlayer3D.new()
	_tractor_radio_player.stream = AudioDirector.cached_stream("res://assets/audio/voice_mainland.ogg")
	_tractor_radio_player.pitch_scale = 0.85
	_tractor_radio_player.position = _place_ground_y(POI_TARGETS[&"poi_trelevochnik"]["pos"]) + Vector3(0, 1.8, 0)
	_tractor_radio_player.unit_size = 3.2
	_tractor_radio_player.max_distance = 18.0
	_tractor_radio_player.volume_db = -13.0
	_tractor_radio_player.bus = &"SFX"
	add_child(_tractor_radio_player)
	_tractor_radio_player.play()

	# Акустический шепот внутри купола РЛС
	_radar_whisper_player = AudioStreamPlayer3D.new()
	_radar_whisper_player.stream = AudioDirector.cached_stream("res://assets/sfx/whisper_many.ogg")
	_radar_whisper_player.position = _place_ground_y(POI_TARGETS[&"poi_radar_dome"]["pos"]) + Vector3(0, 2.0, 0)
	_radar_whisper_player.unit_size = 4.0
	_radar_whisper_player.max_distance = 22.0
	_radar_whisper_player.volume_db = -16.0
	_radar_whisper_player.bus = &"SFX"
	add_child(_radar_whisper_player)
	_radar_whisper_player.play()

	# Глубокий 7-километровый гул из устья скважины СГ-4
	_borehole_drone_player = AudioStreamPlayer3D.new()
	_borehole_drone_player.stream = AudioDirector.cached_stream("res://assets/audio/drone_loop.ogg")
	_borehole_drone_player.pitch_scale = 0.55
	_borehole_drone_player.position = _place_ground_y(POI_TARGETS[&"poi_deep_borehole"]["pos"]) + Vector3(0, 1.5, 0)
	_borehole_drone_player.unit_size = 5.5
	_borehole_drone_player.max_distance = 32.0
	_borehole_drone_player.volume_db = -8.0
	_borehole_drone_player.bus = &"SFX"
	add_child(_borehole_drone_player)
	_borehole_drone_player.play()

	# Ветер в металлических вантах триангуляционной вышки 24м
	_tower_wind_player = AudioStreamPlayer3D.new()
	_tower_wind_player.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/wind_whistle_loop.ogg")
	_tower_wind_player.position = _place_ground_y(POI_TARGETS[&"poi_tower"]["pos"]) + Vector3(0, 19.8, 0)
	_tower_wind_player.unit_size = 5.0
	_tower_wind_player.max_distance = 35.0
	_tower_wind_player.volume_db = -8.0
	_tower_wind_player.bus = &"SFX"
	add_child(_tower_wind_player)
	_tower_wind_player.play()

	# Шёпот и потрескивание у мансийского радио-тотема
	_shrine_whisper_player = AudioStreamPlayer3D.new()
	_shrine_whisper_player.stream = AudioDirector.cached_stream("res://assets/audio/whisper.ogg")
	_shrine_whisper_player.position = _place_ground_y(POI_TARGETS[&"poi_shrine"]["pos"]) + Vector3(0, 1.0, 0)
	_shrine_whisper_player.unit_size = 3.2
	_shrine_whisper_player.max_distance = 18.0
	_shrine_whisper_player.volume_db = -14.0
	_shrine_whisper_player.bus = &"SFX"
	add_child(_shrine_whisper_player)
	_shrine_whisper_player.play()

	# Свист ветра в разломанном фюзеляже вертолёта Ми-4
	_mi4_wind_player = AudioStreamPlayer3D.new()
	_mi4_wind_player.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/wind_whistle_loop.ogg")
	_mi4_wind_player.pitch_scale = 0.72
	_mi4_wind_player.position = _place_ground_y(POI_TARGETS[&"poi_mi4"]["pos"]) + Vector3(0, 1.8, 0)
	_mi4_wind_player.unit_size = 4.8
	_mi4_wind_player.max_distance = 30.0
	_mi4_wind_player.volume_db = -10.0
	_mi4_wind_player.bus = &"SFX"
	add_child(_mi4_wind_player)
	_mi4_wind_player.play()


# --- 3. Аномалии POI: сбой компаса, временная деформация и акустика ---

func _tick_finger_magnetic_anomaly(delta: float) -> void:
	if Game.player == null:
		return
	var finger_pos: Vector3 = POI_TARGETS[&"poi_finger"]["pos"]
	var d := Game.player.global_position.distance_to(finger_pos)
	if d < 28.0:
		var factor := 1.0 - (d / 28.0)
		var tick := Time.get_ticks_msec() * 0.006
		var jitter := (sin(tick * 1.5) * 2.2 + cos(tick * 2.3) * 1.4) * factor
		Game.player.compass_glitch = lerpf(Game.player.compass_glitch, jitter, delta * 5.0)
		if randf() < delta * 0.15 and not _finger_hum_player.playing:
			_finger_hum_player.play()


func _tick_anomalous_pois(delta: float) -> void:
	if Game.player == null:
		return
	var pl_pos := Game.player.global_position

	# Ледяная штольня («Шурф Времени»): временное мерцание компаса и сжатие звука
	var mine_pos: Vector3 = POI_TARGETS[&"poi_ice_mine"]["pos"]
	var d_mine := pl_pos.distance_to(mine_pos)
	if d_mine < 22.0:
		var factor := 1.0 - (d_mine / 22.0)
		var tick := Time.get_ticks_msec() * 0.009
		var mine_jitter := (cos(tick * 2.8) * 3.1) * factor
		Game.player.compass_glitch = lerpf(Game.player.compass_glitch, mine_jitter, delta * 6.0)

	# Купол РЛС: шепот концентрируется в акустическом фокусе центра купола
	if _radar_whisper_player != null:
		var radar_pos: Vector3 = POI_TARGETS[&"poi_radar_dome"]["pos"]
		var d_radar := pl_pos.distance_to(radar_pos)
		if d_radar < 8.0:
			var focus_factor := 1.0 - (d_radar / 8.0)
			_radar_whisper_player.volume_db = lerpf(-16.0, -6.0, focus_factor)
		else:
			_radar_whisper_player.volume_db = -16.0


# --- 4. Оптический эффект гало (паргелий / ложные солнца) ---

func _build_solar_halo() -> void:
	_solar_halo = Node3D.new()
	_solar_halo.name = "SolarHalo"
	add_child(_solar_halo)

	# Солнце зимой светит с азимута 40°, наклон 25°
	var sun_dir := Vector3(-0.68, 0.42, -0.60).normalized()
	var halo_center := sun_dir * 180.0
	_solar_halo.position = halo_center

	# Два ложных солнца (паргелии) на удалении 22 градуса слева и справа
	for offset_angle in [-22.0, 22.0]:
		var parhelion := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(16.0, 16.0)
		parhelion.mesh = qm

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.94, 0.82, 0.28)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		parhelion.material_override = mat

		var side_vec := sun_dir.cross(Vector3.UP).normalized()
		parhelion.position = side_vec * (sin(deg_to_rad(offset_angle)) * 65.0)
		_solar_halo.add_child(parhelion)


# --- 5. Дневной «тихий лавкрафтовский ужас»: парейдолия теней ---

func _tick_peripheral_pareidolia(delta: float) -> void:
	var p := Game.player
	if p == null:
		return

	if _active_silhouette != null and is_instance_valid(_active_silhouette):
		_silhouette_lifetime += delta
		var head_pos := _active_silhouette.global_position + Vector3(0, 1.7, 0)
		# Если игрок повернул взгляд прямо на силуэт — он растворяется
		if p.is_looking_at(head_pos, 22.0) or _silhouette_lifetime > 1.4:
			_active_silhouette.queue_free()
			_active_silhouette = null
			_pareidolia_timer = randf_range(45.0, 95.0)
		return

	_pareidolia_timer -= delta
	if _pareidolia_timer <= 0.0:
		_attempt_spawn_pareidolia()


func _attempt_spawn_pareidolia() -> void:
	var p := Game.player
	if p == null or not Game.is_outside():
		_pareidolia_timer = 20.0
		return

	var cam := p.camera
	if cam == null:
		return

	# Выбираем позицию на периферии зрения: 45°-65° от направления взгляда, 14-22 метра среди деревьев
	var side_sign := 1.0 if randf() < 0.5 else -1.0
	var ang := randf_range(48.0, 62.0) * side_sign
	var dist := randf_range(14.0, 22.0)
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		return
	fwd = fwd.normalized()

	var dir := fwd.rotated(Vector3.UP, deg_to_rad(ang))
	var spot := p.global_position + dir * dist
	spot = _place_ground_y(spot)

	# Спавним силуэт
	_active_silhouette = Creatures.make_silhouette()
	add_child(_active_silhouette)
	_active_silhouette.global_position = spot
	_active_silhouette.look_at(Vector3(p.global_position.x, spot.y, p.global_position.z), Vector3.UP)
	_silhouette_lifetime = 0.0


# --- 6. Запрос для фотосъемки на «Зенит-Е» ---

static func check_poi_in_frame(cam: Camera3D) -> StringName:
	if cam == null:
		return &""
	for id: StringName in POI_TARGETS:
		var target_info: Dictionary = POI_TARGETS[id]
		var pos: Vector3 = target_info["pos"]
		var to := pos - cam.global_position
		var dist := to.length()
		if dist > 38.0 or dist < 1.0:
			continue
		var angle_deg := rad_to_deg((-cam.global_basis.z).angle_to(to / dist))
		if angle_deg < 24.0:
			return id
	return &""
