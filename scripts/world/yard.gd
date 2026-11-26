class_name Yard
extends Node3D
## Двор станции: лес, леера (верёвки на вешках) с табличками, метеоплощадка, мачта, сарай ГСМ,
## поленница и — со второго дня — заброшенная изба. Из дома ничего не видно: каждый выход — вылазка.
##
##   изба (-16,-30) ─── (25,-18) ── мачта (24,-50)
##                         |
##                         |       метеоплощадка (52,-24)
##                         |      /
##   дом ── развилка (16,2.5) ── (27,-3)
##     \         \
##   поленница    сарай ГСМ (40,28)

const FOREST_CELL := 30.0   ## сторона квадрата леса для отсечения
const DOOR_OUT := Vector3(16.8, 0.0, 3.5)   # в метре от ступеней крыльца (новая дверь x=14.3, z=3.5)
const JUNCTION := Vector3(20.0, 0.0, 3.5)
const FORK := Vector3(29.0, 0.0, -2.0)
const MAST_FORK := Vector3(25.0, 0.0, -18.0)
const METEO := Vector3(98.0, 0.0, -30.0)      ## аэрологический корпус с башней (MeteoCorpus), ~100 м от дома — ночью это вылазка
const METEO_HALF := 13.0
## Приборы — смещения от METEO (север — −Z). Будка и рейка — на огороженной приборной площадке у тропы,
## флюгер с анеморумбометром — на мачте на кровле корпуса, теодолит — в кабине башни, пост шаров — в ангаре.
const PLOT := Vector3(66.0, 0.0, -22.0)       ## приборная площадка 9×9 (ограда — corpus_yard.glb)
const M_GATE := Vector3(-36.5, 0.0, 8.0)      ## калитка площадки (запад)
const M_BOOTH := Vector3(-33.2, 0.0, 6.4)
const M_ROD := Vector3(-30.2, 0.0, 9.8)
const M_OLD := Vector3(-34.0, 0.0, 10.4)
const M_VANE := Vector3(-4.8, 3.8, -1.5)      ## мачта на кровле (над аппаратной)
const M_THEO := Vector3(-2.0, 9.75, -5.5)     ## кабина башни
const M_BALLOON := Vector3(28.0, 0.16, -6.0)  ## у ворот ангара, внутри
const CORPUS_PORCH := Vector3(88.4, 0.0, -27.25)
const MAST := Vector3(24.0, 0.0, -62.0)
const SHED := Vector3(48.0, 0.0, 34.0)
const SHED_MODEL_Y := -0.2       ## низ цоколя shed.glb
const IZBA_MODEL_Y := -0.01      ## низ нижних брёвен izba.glb
const LAKE_SHACK_MODEL_Y := -0.8  ## низ свай lake_shack.glb
const WOODPILE := Vector3(4.0, 0.0, 40.0)
const IZBA := Vector3(-16.0, 0.0, -30.0)
const HOUSE_CENTER := Vector3(6.1, 0.0, 3.6)
const REPEATER := Vector3(72.0, 0.0, -62.0)
const LAKE := Vector3(-42.0, 0.0, 38.0)
const LAKE_R := 14.0
const HOLE := Vector3(-38.0, 0.0, 34.0)       ## прорубь
const LAKE_SHACK := Vector3(-36.0, 0.0, 20.0)
const BUNKER := Vector3(58.0, 0.0, 12.0)       ## люк на поверхности
const BUNKER_ROOM := Vector3(58.0, -30.0, 12.0) ## бункер «Отзвук» глубоко под землёй (отдельная коробка)
const ZIMNIK := Vector3(-70.0, 0.0, -94.0)     ## зимник: дорога на Большую Землю (двор ровный — высота 0)
const POST_STEP := 5.0
const TRAIL_W := 1.4
const PORCH_SAFE_RADIUS := 5.5
const LEAN_YARD := true

const GLADES := [
	{"c": Vector3(10.0, 0.0, 4.0), "r": 12.5},    # жилой дворик (компактная поляна в кольце вековых елей)
	{"c": Vector3(66.0, 0.0, -22.0), "r": 15.0},  # метеополяна (= PLOT)
	{"c": Vector3(24.0, 0.0, -62.0), "r": 12.0},  # мачта
]
const ALLEY_HALF := 2.9     # узкая таёжная просека (~5.8 м) под сводом вековых елей
const WALL_W := 9.0         # плотная стена леса вокруг поляны и просек

static func _gnd(v: Vector3) -> Vector3:
	return Vector3(v.x, Terrain.height(v.x, v.z), v.z)

const HIT_SOUND := "res://assets/audio/ice_hit.ogg"
const CLANK_SOUND := "res://assets/audio/clank.ogg"
const WOOD_SOUND := "res://assets/audio/stove_add.ogg"
const DOOR_SOUND := "res://assets/audio/door.ogg"
const DayPOIsClass = preload("res://scripts/world/day_pois.gd")

## Полилинии лееров — по ним считаем, сошёл ли игрок с верёвки.
var paths: Array[PackedVector3Array] = []
var izba_open := false
var shed_doors_open := false
var _shed_door_left_hinge: Node3D
var _shed_door_right_hinge: Node3D
var _shed_doors_busy := false
var _shed_drift: Interactable
var _shed_padlock: Node3D
var _shed_padlock_it: Interactable
var _oil_can_it: Interactable
var izba_door_open := false
var _izba_door_hinge: Node3D
var _izba_door_busy := false
var open_sites: Dictionary = {}       ## repeater / lake / bunker / zimnik → открыто на схеме
var _site_paths: Dictionary = {}
var _all_paths: Array[PackedVector3Array] = []
var _ice_nodes: Array[Node3D] = []
var _vane_ice_node: Node3D
var _vane_it: Interactable
var _can_models: Array[Node3D] = []
var _cans_shown := -1
var _mast_light: OmniLight3D
var _mast_halos: Array = []   ## ореолы мачты: мигают вместе с огнём, днём их нет (на светлом небе — квадрат)
var _repeater_light: OmniLight3D
var _drift: Interactable
var _mast_lamp_out := false
var _mast_ground_active := false
var _mast_ground_sparks: CPUParticles3D
var _mast_ground_sound: AudioStreamPlayer3D
var _mast_shadow: MeshInstance3D
var _mast_shadow_mat: StandardMaterial3D
var _mast_beacon_mesh: MeshInstance3D
var _zimnik_cd := 0.0
var _t := 0.0
var _shed_tracks_done := false
var _fresh_tracks_active := false
var _mast_watcher_done := false
var _fever_reading_done := false
var _outdoor_stalker_timer := 110.0
var _outdoor_entity: Node3D = null
var _outdoor_entity_type := &""
var _outdoor_entity_life := 0.0
var _audio_scare_timer := 45.0
var _entity_noticed := false

# Ночные кошмары после 02:00 (Личина, отказ фонаря, глаза в чаще, шёпот)
var _mimic_timer := 70.0
var _mimic_node: Node3D = null
var _mimic_triggered := false

var _brownout_timer := 85.0
var _brownout_active := false
var _brownout_duration := 0.0

var _forest_eyes: Array[Node3D] = []
var _eyes_timer := 50.0
var _whisper_timer := 120.0
var _crow_timer := 110.0
var _outdoor_cd := 0.0
var _pilot_balloon_node: Node3D = null
var _pilot_balloon_light: OmniLight3D = null
const HUNTER_SPRUCE_POS := Vector3(22.0, 0.0, -28.0)
var _frozen_hunter_node: Node3D = null
var _hunter_aura_noticed := false
var _zherdyai_step_timer := 0.0
var _cleared_anchors: Dictionary = {}
var _diesel_zone_noticed := false
var _night6_tracks_spawned := false
var _night6_return_tracks_spawned := false
var _bare_tracks_root: Node3D = null
var _creak_t := 12.0
var _shed_tin_t := 7.0
var _snow_drop_cd := 0.0
var cellar_prop: Node3D = null
var chop_prop: Node3D = null
var doghouse_prop: Node3D = null
var stand_prop: Node3D = null
var _closed_trail_eyes: Node3D = null
var _dog_chain_clanked := false
var _dog_eyes_stare_t := 0.0
var _dog_eyes_fled := false
var _cellar_knocked := false
var _closed_trail_stare_t := 0.0
var _closed_trail_triggered := false
var _cellar_window_tracks_done := false
var _cellar_window_tracks_root: Node3D = null
var _booth_ambush_done := false
static var _trail_mat: ShaderMaterial = null


func _ready() -> void:
	Game.yard = self
	izba_open = Game.has_flag("izba")
	var izba_path := PackedVector3Array([MAST_FORK, Vector3(10, 0, -25), Vector3(-2, 0, -28), IZBA + Vector3(3.6, 0, 0)])
	paths.append(PackedVector3Array([DOOR_OUT, JUNCTION]))
	paths.append(PackedVector3Array([JUNCTION, FORK, Vector3(40, 0, -14), Vector3(50, 0, -24), Vector3(58, 0, -28.5), Vector3(72, 0, -29.5), Vector3(84, 0, -27.6), CORPUS_PORCH]))
	paths.append(PackedVector3Array([Vector3(58, 0, -28.5), Vector3(57.5, 0, -22.0), PLOT + Vector3(-5.6, 0, 0)]))   # к калитке приборной площадки
	paths.append(PackedVector3Array([FORK, MAST_FORK, Vector3(24, 0, -36), Vector3(24, 0, -50), MAST + Vector3(0, 0, 4.0)]))
	paths.append(PackedVector3Array([JUNCTION, Vector3(26, 0, 12), Vector3(36, 0, 24), SHED + Vector3(-4.9, 0, 0)]))   # последний столбик — у порога снаружи, не в сарае
	paths.append(PackedVector3Array([DOOR_OUT, Vector3(16.0, 0, 14.0), Vector3(10.0, 0, 28.0), WOODPILE + Vector3(0.6, 0, -2.0)]))   # к южному боку поленницы, мимо столба и козел
	var helipad_path := PackedVector3Array([JUNCTION, Vector3(32, 0, 4.5), HELIPAD + Vector3(-5.0, 0, 0)])
	paths.append(helipad_path)
	# Короткая тропа от мостков ДЭС-8 к леднику и тупиковая закрытая просека в тайгу
	var cellar_path := PackedVector3Array([Vector3(15.6, 0, -6.0), Vector3(10.5, 0, -8.2), Vector3(6.4, 0, -8.8)])
	var closed_taiga_path := PackedVector3Array([Vector3(15.8, 0, 10.8), Vector3(11.0, 0, 11.4), Vector3(4.0, 0, 11.2), Vector3(-1.8, 0, 10.6), Vector3(-6.8, 0, 8.2), Vector3(-14.5, 0, 7.2)])
	paths.append(cellar_path)
	paths.append(closed_taiga_path)
	_all_paths = paths.duplicate()
	_all_paths.append(izba_path)
	if izba_open:
		paths.append(izba_path)
	_site_paths = {
		# В обход ограды метеоплощадки (раньше тропа шла наискось сквозь столбы и приборы)
		"repeater": PackedVector3Array([Vector3(50, 0, -24), Vector3(52.2, 0, -37.8), Vector3(58, 0, -40), Vector3(66, 0, -52), REPEATER + Vector3(-3.0, 0, 3.0)]),
		# Леер ведёт к трапу у входа (юг), а не в глухую восточную стену, как раньше
		"lake": PackedVector3Array([Vector3(10.0, 0, 28.0), Vector3(-10, 0, 34),   # развилка на тропе к дровам: раньше шла сквозь поленницу и колоду
			Vector3(-24, 0, 26), LAKE_SHACK + Vector3(1.2, 0, 7.2)]),
		"bunker": PackedVector3Array([Vector3(36, 0, 24), Vector3(46, 0, 18), BUNKER + Vector3(-1.6, 0, 0)]),
		# От двери избы — сначала наружу и вдоль стены, а не наискось сквозь её угол
		"zimnik": PackedVector3Array([IZBA + Vector3(3.6, 0, 0), IZBA + Vector3(6.6, 0, 0), IZBA + Vector3(6.6, 0, -5.0), Vector3(-14, 0, -40), Vector3(-30, 0, -58), Vector3(-48, 0, -74), ZIMNIK]),
	}
	for site: String in _site_paths:
		_all_paths.append(_site_paths[site])
		open_sites[site] = Game.has_flag(site)
		if open_sites[site]:
			paths.append(_site_paths[site])
	if Game.is_prologue():
		var p_trail := PrologueTrail.route()
		_all_paths.append(p_trail)
		paths.append(p_trail)

	_build_ground()
	_build_wall_drifts()
	_build_forest_haze()
	# Натоптанные снежные тропы между объектами станции (чистый открытый двор без визуального мусора)
	for p in paths:
		_build_trail(p)
	_build_meteo()
	_build_mast()
	_build_shed()
	_build_snow_drop_triggers()
	_restore_placed_pickups()
	FarSites.build(self)
	Supply.place_crate(self)
	Supply.hook()
	NumbersCache.hook()
	NumbersCache.build(self)   # схрон, к которому ведёт сбивка в цифрах
	add_child(MapEvents.new())
	add_child(FieldJobs.new())
	add_child(SourceSite.new())
	add_child(EfirSites.new())
	add_child(StationLore.new())
	add_child(DayPOIsClass.new())
	Dog.ensure(self)
	_build_woodpile()
	_build_izba()
	_build_repeater()
	_build_lake()
	_build_bunker()
	_build_zimnik()
	_build_deadfall()
	if not LEAN_YARD:
		_build_silhouette_stumps()
	SiteDressing.izba(self, IZBA)
	SiteDressing.repeater(self, REPEATER)
	SiteDressing.bunker(self, BUNKER)
	SiteDressing.zimnik(self, Vector3(ZIMNIK.x, Terrain.height(ZIMNIK.x, ZIMNIK.z), ZIMNIK.z))
	SiteDressing.lake(self, LAKE, HOLE, LAKE_SHACK)
	_build_forest()
	_build_bounds()
	_build_backyard_features()
	_build_utility_grid()
	if not LEAN_YARD:
		_build_snow_fences()
		_build_fuel_drum_field()
		_build_expedition_cart()
	else:
		_build_lean_fuel_drums()
	_build_signpost(JUNCTION + Vector3(0.8, 0.0, 1.2))
	_build_notice_board(Vector3(19.3, 0.0, -0.4))
	_build_doghouse(Vector3(21.4, 0.0, 9.4))
	_build_frozen_clothesline(Vector3(-1.2, 0.0, 8.6))
	_build_near_woodchop(Vector3(11.8, 0.0, 9.4))
	_build_closed_trail(Vector3(-6.8, 0.0, 8.2))
	_build_old_fence()
	_build_taiga_landmarks()
	_build_snow_survey_route()
	_build_helipad()
	_build_frozen_hunter()
	_build_station_road_dressing()
	_build_yard_clutter()
	if (Game.is_day() and Game.phase_index == 1) or (Game.is_night() and Game.night >= 2):
		_build_footprints()
	EventBus.antenna_iced_changed.connect(_on_antenna_iced)
	_on_antenna_iced(Game.antenna_iced)
	EventBus.anemo_iced_changed.connect(_on_anemo_iced)
	_on_anemo_iced(Game.anemo_iced)


func _update_cans() -> void:
	if _cans_shown == Game.canisters_left:
		return
	_cans_shown = Game.canisters_left
	for i in range(_can_models.size()):
		_can_models[i].visible = i < Game.canisters_left


func _build_lean_fuel_drums() -> void:
	# 3 бочки у стены дизельной: две стоят, одна на боку с наледью
	var base := _gnd(SHED + Vector3(-3.5, 0.0, -1.8))
	var b1 := Props.barrel()
	b1.position = base
	add_child(b1)
	var b2 := Props.frozen_barrel()
	b2.position = base + Vector3(0.85, 0.0, 0.1)
	b2.position.y = Terrain.height(b2.position.x, b2.position.z)
	add_child(b2)
	var b3 := Props.barrel()
	b3.position = base + Vector3(0.4, 0.42, 0.85)
	b3.position.y = Terrain.height(b3.position.x, b3.position.z) + 0.42
	b3.rotation.z = deg_to_rad(90.0)
	add_child(b3)


func _build_signpost(pos: Vector3) -> void:
	var gy := Terrain.height(pos.x, pos.z)
	var root := Node3D.new()
	root.position = Vector3(pos.x, gy, pos.z)
	add_child(root)

	var post_h := 2.2
	var post_mesh := Geo.box_mesh(Vector3(0.14, post_h, 0.14), Palette.m(&"wood"))
	post_mesh.position = Vector3(0.0, post_h * 0.5, 0.0)
	root.add_child(post_mesh)

	var roof_l := Geo.box_mesh(Vector3(0.24, 0.03, 0.16), Palette.m(&"plank"))
	roof_l.position = Vector3(-0.06, post_h + 0.05, 0.0)
	roof_l.rotation.z = deg_to_rad(28.0)
	root.add_child(roof_l)
	var roof_r := Geo.box_mesh(Vector3(0.24, 0.03, 0.16), Palette.m(&"plank"))
	roof_r.position = Vector3(0.06, post_h + 0.05, 0.0)
	roof_r.rotation.z = deg_to_rad(-28.0)
	root.add_child(roof_r)
	var snow_cap := Geo.box_mesh(Vector3(0.26, 0.06, 0.18), Palette.m(&"snow"))
	snow_cap.position = Vector3(0.0, post_h + 0.1, 0.0)
	root.add_child(snow_cap)

	var to_meteo := (PLOT - pos).normalized()
	var yaw_meteo := atan2(to_meteo.x, to_meteo.z)
	var arrow_meteo := _build_arrow_board(0.65, 0.14, Palette.m(&"weathered"), Palette.m(&"trim_paint"))
	arrow_meteo.position = Vector3(0.0, 1.85, 0.0)
	arrow_meteo.rotation.y = yaw_meteo
	root.add_child(arrow_meteo)

	var to_shed := (SHED - pos).normalized()
	var yaw_shed := atan2(to_shed.x, to_shed.z)
	var arrow_shed := _build_arrow_board(0.60, 0.13, Palette.m(&"weathered"), Palette.m(&"weathered"))
	arrow_shed.position = Vector3(0.0, 1.55, 0.0)
	arrow_shed.rotation.y = yaw_shed
	root.add_child(arrow_shed)

	var to_taiga := (ZIMNIK - pos).normalized()
	var yaw_taiga := atan2(to_taiga.x, to_taiga.z)
	var arrow_taiga := _build_arrow_board(0.55, 0.12, Palette.m(&"wood"), Palette.m(&"red"))
	arrow_taiga.position = Vector3(0.0, 1.25, 0.0)
	arrow_taiga.rotation.y = yaw_taiga
	arrow_taiga.rotation.z = deg_to_rad(-6.0)
	root.add_child(arrow_taiga)

	var skirt := Geo.box_mesh(Vector3(0.55, 0.28, 0.55), Palette.m(&"drift"))
	skirt.position = Vector3(0.0, 0.12, 0.0)
	root.add_child(skirt)

	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = Vector3(0.0, post_h * 0.5, 0.0)
	body.add_child(Geo.box_shape(Vector3(0.2, post_h, 0.2)))
	root.add_child(body)

	var it := Interactable.new()
	it.collision_layer = Geo.LAYER_WORLD
	it.position = Vector3(0.0, 1.4, 0.0)
	it.prompt_provider = func() -> String: return Loc.t(&"sign.post_name")
	it.add_child(Geo.box_shape(Vector3(0.8, 1.8, 0.8)))
	it.used.connect(func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sign.post_read"), 5.0)
		Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -6.0)
	)
	root.add_child(it)


func _build_arrow_board(length: float, height: float, wood_mat: Material, accent_mat: Material) -> Node3D:
	var n := Node3D.new()
	var plank_l := length * 0.75
	var plank := Geo.box_mesh(Vector3(0.04, height, plank_l), wood_mat)
	plank.position = Vector3(0.0, 0.0, plank_l * 0.5)
	n.add_child(plank)

	var tip := Geo.box_mesh(Vector3(0.045, height * 0.8, length * 0.25), accent_mat)
	tip.position = Vector3(0.0, 0.0, plank_l + length * 0.12)
	n.add_child(tip)

	var snow := Geo.box_mesh(Vector3(0.05, 0.025, length * 0.95), Palette.m(&"snow"))
	snow.position = Vector3(0.0, height * 0.5 + 0.012, length * 0.5)
	n.add_child(snow)
	return n


func _build_old_fence() -> void:
	var fence_rng := RandomNumberGenerator.new()
	fence_rng.seed = 88
	var root := Node3D.new()
	root.name = "OldYardFence"
	add_child(root)

	var points: Array[Vector3] = []
	for z in range(6, -12, -2):
		points.append(Vector3(-4.5, 0.0, float(z)))
	for x in range(-3, 14, 2):
		points.append(Vector3(float(x), 0.0, -11.2))

	for i in range(points.size()):
		var pt := points[i]
		var gy := Terrain.height(pt.x, pt.z)
		var post_pos := Vector3(pt.x, gy, pt.z)

		var post := Node3D.new()
		post.position = post_pos
		post.rotation.y = fence_rng.randf_range(-0.1, 0.1)
		post.rotation.z = deg_to_rad(fence_rng.randf_range(-8.0, 8.0))
		post.rotation.x = deg_to_rad(fence_rng.randf_range(-6.0, 6.0))
		root.add_child(post)

		var ph := fence_rng.randf_range(1.0, 1.25)
		var pm := Geo.box_mesh(Vector3(0.1, ph, 0.1), Palette.m(&"wood"))
		pm.position = Vector3(0.0, ph * 0.5, 0.0)
		post.add_child(pm)

		var sc := Geo.box_mesh(Vector3(0.14, 0.05, 0.14), Palette.m(&"snow"))
		sc.position = Vector3(0.0, ph + 0.02, 0.0)
		post.add_child(sc)

		var d := Geo.box_mesh(Vector3(0.65, 0.35, 0.65), Palette.m(&"drift"))
		d.position = Vector3(0.0, 0.15, 0.0)
		post.add_child(d)

		# На угловом столбе у кромки леса — зарубка на уровне глаз
		if i == 6:
			var notch := Geo.box_mesh(Vector3(0.12, 0.04, 0.04), Palette.m(&"log_end"))
			notch.position = Vector3(0.0, 0.85, 0.05)
			post.add_child(notch)
			var n_it := Interactable.new()
			n_it.collision_layer = Geo.LAYER_WORLD
			n_it.position = Vector3(0.0, 0.85, 0.0)
			n_it.prompt_provider = func() -> String: return Loc.t(&"it.pine_notch")
			n_it.add_child(Geo.box_shape(Vector3(0.6, 0.8, 0.6)))
			n_it.used.connect(func(_p: Player) -> void:
				Game.hud.subtitle(Loc.t(&"sub.pine_notch"), 4.5)
				Game.audio.play_2d("res://assets/audio/ice_hit.ogg", -6.0)
			)
			post.add_child(n_it)

		if i + 1 < points.size() and i != 6:
			var next_pt := points[i + 1]
			var next_gy := Terrain.height(next_pt.x, next_pt.z)
			var p2 := Vector3(next_pt.x, next_gy, next_pt.z)
			var dist := post_pos.distance_to(p2)
			if dist < 3.2:
				var mid := (post_pos + p2) * 0.5
				var dir := (p2 - post_pos).normalized()
				var yaw := atan2(dir.x, dir.z)

				var rails := [0.35, 0.75]
				for ry in rails:
					if ry > 0.7 and fence_rng.randf() < 0.25:
						continue
					var rail := Geo.box_mesh(Vector3(0.04, 0.08, dist * 0.98), Palette.m(&"weathered"))
					rail.position = mid + Vector3(0.0, ry, 0.0)
					rail.rotation.y = yaw
					root.add_child(rail)

				var pickets := fence_rng.randi_range(1, 3)
				for k in pickets:
					if fence_rng.randf() < 0.2:
						continue
					var frac := float(k + 1) / float(pickets + 1)
					var p_mid := post_pos.lerp(p2, frac)
					var picket := Geo.box_mesh(Vector3(0.03, 0.85, 0.1), Palette.m(&"weathered"))
					picket.position = p_mid + Vector3(0.0, 0.45, 0.0)
					picket.rotation.y = yaw
					picket.rotation.z = deg_to_rad(fence_rng.randf_range(-12.0, 12.0))
					root.add_child(picket)


func _build_notice_board(pos: Vector3) -> void:
	var gy := Terrain.height(pos.x, pos.z)
	stand_prop = Props.outpost_stand()
	stand_prop.position = Vector3(pos.x, gy, pos.z)
	stand_prop.rotation.y = deg_to_rad(14.0)
	add_child(stand_prop)

	var sb := StaticBody3D.new()
	sb.collision_layer = Geo.LAYER_WORLD
	sb.collision_mask = 0
	sb.position = Vector3(0.0, 1.1, 0.0)
	sb.add_child(Geo.box_shape(Vector3(1.55, 2.2, 0.35)))
	stand_prop.add_child(sb)

	var it := Interactable.new()
	it.collision_layer = Geo.LAYER_WORLD
	it.position = Vector3(0.0, 1.38, 0.22)
	it.prompt_provider = func() -> String: return Loc.t(&"it.notice_board")
	it.add_child(Geo.box_shape(Vector3(1.45, 1.2, 0.8)))
	it.used.connect(func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.notice_board"), 5.0)
		Game.audio.play_2d("res://assets/audio/ui_tick.ogg", -4.0)
	)
	stand_prop.add_child(it)


func _build_doghouse(pos: Vector3) -> void:
	var gy := Terrain.height(pos.x, pos.z)
	doghouse_prop = Props.abandoned_doghouse()
	doghouse_prop.position = Vector3(pos.x, gy, pos.z)
	doghouse_prop.rotation.y = deg_to_rad(-140.0)
	add_child(doghouse_prop)

	var sb := StaticBody3D.new()
	sb.collision_layer = Geo.LAYER_WORLD
	sb.collision_mask = 0
	sb.position = Vector3(0.0, 0.48, 0.0)
	sb.add_child(Geo.box_shape(Vector3(1.0, 0.96, 1.2)))
	doghouse_prop.add_child(sb)

	var it := Interactable.new()
	it.collision_layer = Geo.LAYER_WORLD
	it.position = Vector3(0.0, 0.5, 0.55)
	it.prompt_provider = func() -> String: return Loc.t(&"it.doghouse")
	it.add_child(Geo.box_shape(Vector3(1.1, 1.0, 1.1)))
	it.used.connect(func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.doghouse"), 4.5)
		Game.audio.play_2d("res://assets/audio/clank.ogg", -8.0)
	)
	doghouse_prop.add_child(it)


func _build_near_woodchop(pos: Vector3) -> void:
	var gy := Terrain.height(pos.x, pos.z)
	chop_prop = Props.chopping_block()
	chop_prop.position = Vector3(pos.x, gy, pos.z)
	chop_prop.rotation.y = deg_to_rad(-25.0)
	add_child(chop_prop)

	var sb := StaticBody3D.new()
	sb.collision_layer = Geo.LAYER_WORLD
	sb.collision_mask = 0
	sb.position = Vector3(0.0, 0.35, 0.0)
	sb.add_child(Geo.box_shape(Vector3(0.8, 0.72, 0.8)))
	chop_prop.add_child(sb)

	var it := Geo.interactable(chop_prop, Vector3(0.95, 1.15, 0.95), Vector3(0.0, 0.55, 0.0), null, Loc.t(&"it.axe_stump"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.axe_stump"), 4.0)
	)
	it.name = "NearAxeStump"


func _build_closed_trail(pos: Vector3) -> void:
	var gy := Terrain.height(pos.x, pos.z)
	var gate := Props.closed_trail_gate()
	gate.position = Vector3(pos.x, gy, pos.z)
	gate.rotation.y = deg_to_rad(82.0)
	add_child(gate)

	var sb := StaticBody3D.new()
	sb.collision_layer = Geo.LAYER_WORLD
	sb.collision_mask = 0
	sb.position = Vector3(0.0, 0.8, 0.0)
	sb.add_child(Geo.box_shape(Vector3(2.8, 1.6, 0.28)))
	gate.add_child(sb)

	var it := Geo.interactable(gate, Vector3(2.6, 1.5, 0.8), Vector3(0.0, 0.9, 0.2), null, Loc.t(&"it.closed_trail"), func(_p: Player) -> void:
		if Game.radio_orders != null and Game.radio_orders.active() and Game.radio_orders.is_fake():
			Game.radio_orders.trigger_vane_ambush()
		else:
			Game.hud.subtitle(Loc.t(&"sub.closed_trail"), 4.5)
	)
	it.name = "ClosedTrailGateIt"

	# Пара холодных глаз в глубине закрытой просеки (вспыхивает один раз за ночь, если долго светить в темноту)
	_closed_trail_eyes = Node3D.new()
	_closed_trail_eyes.name = "ClosedTrailWatcherEyes"
	var ey := Terrain.height(-14.5, 7.2)
	_closed_trail_eyes.position = Vector3(-14.5, ey + 1.62, 7.2)
	_closed_trail_eyes.rotation.y = deg_to_rad(82.0)
	_closed_trail_eyes.visible = false
	var glow_sh := load("res://assets/shaders/soft_glow.gdshader") as Shader
	var qm := QuadMesh.new()
	qm.size = Vector2(0.085, 0.085)
	for sx in [-0.055, 0.055]:
		var emi := MeshInstance3D.new()
		emi.mesh = qm
		emi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if glow_sh != null:
			var sm := ShaderMaterial.new()
			sm.shader = glow_sh
			sm.set_shader_parameter(&"tint", Color(0.86, 0.94, 0.78))
			sm.set_shader_parameter(&"intensity", 1.15)
			sm.set_shader_parameter(&"sharp", 3.0)
			emi.material_override = sm
		else:
			emi.material_override = Palette.glow(&"eyes", true)
		emi.position = Vector3(sx, 0.0, 0.0)
		_closed_trail_eyes.add_child(emi)
	add_child(_closed_trail_eyes)


func _build_frozen_clothesline(pos: Vector3) -> void:
	var gy := Terrain.height(pos.x, pos.z)
	var root := Node3D.new()
	root.position = Vector3(pos.x, gy, pos.z)
	add_child(root)

	var p1 := Geo.box_mesh(Vector3(0.09, 1.9, 0.09), Palette.m(&"wood"))
	p1.position = Vector3(-1.8, 0.95, 0.0)
	p1.rotation.z = deg_to_rad(4.0)
	root.add_child(p1)
	var p2 := Geo.box_mesh(Vector3(0.09, 1.9, 0.09), Palette.m(&"wood"))
	p2.position = Vector3(1.8, 0.95, 0.0)
	p2.rotation.z = deg_to_rad(-5.0)
	root.add_child(p2)

	var rope := Geo.box_mesh(Vector3(3.6, 0.02, 0.02), Palette.m(&"dark"))
	rope.position = Vector3(0.0, 1.68, 0.0)
	root.add_child(rope)

	var coat_body := Geo.box_mesh(Vector3(0.55, 0.72, 0.16), Palette.m(&"dark"))
	coat_body.position = Vector3(0.0, 1.25, 0.0)
	coat_body.rotation.x = deg_to_rad(6.0)
	root.add_child(coat_body)

	var sleeve_l := Geo.box_mesh(Vector3(0.38, 0.16, 0.14), Palette.m(&"dark"))
	sleeve_l.position = Vector3(-0.42, 1.48, 0.0)
	sleeve_l.rotation.z = deg_to_rad(28.0)
	root.add_child(sleeve_l)
	var sleeve_r := Geo.box_mesh(Vector3(0.38, 0.16, 0.14), Palette.m(&"dark"))
	sleeve_r.position = Vector3(0.42, 1.48, 0.0)
	sleeve_r.rotation.z = deg_to_rad(-28.0)
	root.add_child(sleeve_r)

	var snow_shoulders := Geo.box_mesh(Vector3(0.58, 0.04, 0.18), Palette.m(&"snow"))
	snow_shoulders.position = Vector3(0.0, 1.62, 0.0)
	root.add_child(snow_shoulders)

	for cx in [-0.18, 0.18]:
		var pin := Geo.box_mesh(Vector3(0.03, 0.08, 0.03), Palette.m(&"wood"))
		pin.position = Vector3(cx, 1.72, 0.0)
		root.add_child(pin)

	var it := Interactable.new()
	it.collision_layer = Geo.LAYER_WORLD
	it.position = Vector3(0.0, 1.3, 0.0)
	it.prompt_provider = func() -> String: return Loc.t(&"it.frozen_clothes")
	it.add_child(Geo.box_shape(Vector3(1.2, 1.4, 0.8)))
	it.used.connect(func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.frozen_clothes"), 5.0)
		Game.audio.play_2d("res://assets/audio/clank_v2.ogg", -10.0)
	)
	root.add_child(it)


func _process(delta: float) -> void:
	_update_cans()
	_t += delta
	var mast_e := 0.0 if _mast_lamp_out else (1.3 if fmod(_t, 1.6) < 1.0 else 0.0)
	if _mast_light != null and _mast_light.light_energy != mast_e:
		_mast_light.light_energy = mast_e
		var halo_on := mast_e > 0.0 and not Game.is_daylight()
		for h in _mast_halos:
			if h != null:
				h.visible = halo_on
	if _mast_beacon_mesh != null and _mast_beacon_mesh.material_override != null:
		var b_mat := _mast_beacon_mesh.material_override as StandardMaterial3D
		if _mast_lamp_out or Game.is_daylight():
			_mast_beacon_mesh.visible = false
		else:
			var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
			var vis := Storm.clarity * Storm.clarity * pulse
			b_mat.albedo_color.a = vis
			_mast_beacon_mesh.visible = vis > 0.02
	if _repeater_light != null:
		var rep_e := 1.0 if fmod(_t + 0.7, 2.2) < 0.4 else 0.0
		if _repeater_light.light_energy != rep_e:
			_repeater_light.light_energy = rep_e
	# Лунная тень от антенной мачты на снегу
	if _mast_shadow != null and _mast_shadow_mat != null:
		var is_night := not Game.is_daylight()
		_mast_shadow.visible = is_night
		if is_night:
			var w_int: float = Game.weather.intensity if Game.weather != null else 0.0
			var moon_vis := clampf(1.0 - w_int * 0.7, 0.12, 1.0)
			var sway_drift := sin(_t * 0.32) * 0.025 + cos(_t * 0.68) * 0.012
			_mast_shadow.rotation.y = deg_to_rad(45.0) + sway_drift
			_mast_shadow_mat.albedo_color.a = 0.44 * moon_vis
	_check_zimnik(delta)
	if _fresh_tracks_active and Game.player != null:
		var p_pos := Game.player.global_position
		if p_pos.distance_to(Vector3(30.0, 0.0, 20.0)) < 7.0:
			_fresh_tracks_active = false
			Game.hud.subtitle(Loc.t(&"sub.fresh_tracks"), 4.5)
			Game.add_fatigue(4.0)
			Director.add_tension(12.0, "свежие следы у сарая")
			Game.audio.play_3d("res://assets/audio/gust.ogg", Vector3(25.0, 1.0, 18.0), -4.0)
	# Аура присутствия у вековой ели замёрзшего охотника
	if Game.player != null and not _hunter_aura_noticed:
		if Game.player.global_position.distance_to(HUNTER_SPRUCE_POS) < 8.5:
			_hunter_aura_noticed = true
			Game.hud.subtitle(Loc.t(&"sub.hunter_aura"), 4.0, 0)
			Director.add_tension(5.0, "аура замёрзшего охотника")

	# Зона дизельной (5–20м): глухая вибрация ДГА-24 и запах солярки
	if Game.player != null and not _diesel_zone_noticed:
		var p_pos := Game.player.global_position
		if p_pos.distance_to(Vector3(18.0, 0.0, -4.0)) < 7.5 and Game.power_on:
			_diesel_zone_noticed = true
			Game.hud.subtitle(Loc.t(&"sub.diesel_zone"), 4.5)

	# Живые босые следы от ледника к окну аппаратной (Ночи 2–5) + Ночь 6 от будки, заметаемые метелью на глазах
	_process_cellar_window_tracks(delta)
	_process_night6_bare_tracks(delta)

	# Уличные кошмары: появление сущностей и пугающая атмосфера в тайге
	_process_outdoor_horror(delta)
	_process_yard_suspense(delta)
	_process_forest_sounds(delta)
	_process_snow_survey_stalking(delta)
	_process_mi8_helipad(delta)

	if _pilot_balloon_node != null and is_instance_valid(_pilot_balloon_node):
		_pilot_balloon_node.position += Vector3(0.32 * delta, 0.72 * delta, -0.22 * delta)
		# Свет фонарика гаснет с высотой: над двором он только первые ~40 с
		if _pilot_balloon_light != null and is_instance_valid(_pilot_balloon_light):
			_pilot_balloon_light.light_energy = 1.6 * clampf(1.0 - (_pilot_balloon_node.position.y - 12.0) / 22.0, 0.0, 1.0)
		if _pilot_balloon_node.position.y > 65.0:
			Game.balloon_launched = false
			_pilot_balloon_node.queue_free()
			_pilot_balloon_node = null
			_pilot_balloon_light = null


## Реактивный ночной саспенс двора без скримеров: вакуум ветра, звон цепи, гаснущие от фонаря глаза и стук из ледника.
func _process_yard_suspense(delta: float) -> void:
	if not Game.is_night() or Game.player == null or not Game.is_outside():
		return
	var p := Game.player
	var p_pos := p.global_position
	var anom := Game.anomalies

	# 1. Будка с натянутой цепью: при приближении — вакуум метели и тихий звон; луч фонаря спугивает глаза внутри
	if anom != null and anom.is_active(&"dog_chain") and doghouse_prop != null and is_instance_valid(doghouse_prop):
		var dp := doghouse_prop.global_position
		var d_dog := p_pos.distance_to(dp)
		if not _dog_chain_clanked and d_dog < 9.5:
			_dog_chain_clanked = true
			if Game.audio != null:
				Game.audio.trigger_vacuum(3.5)
				Game.audio.play_3d("res://assets/audio/clank_v3.ogg", dp + Vector3(0, 0.25, 0), -10.0, 8.0)
		var eyes := doghouse_prop.get_node_or_null("InsideEyes") as Node3D
		if eyes != null and eyes.visible and not _dog_eyes_fled and d_dog < 12.0 and p.flashlight_on() and p.is_looking_at(dp + Vector3(0, 0.3, 0), 18.0):
			_dog_eyes_stare_t += delta
			if _dog_eyes_stare_t >= 0.55:
				_dog_eyes_fled = true
				eyes.visible = false
				if Game.audio != null:
					Game.audio.play_3d("res://assets/audio/knock_v4.ogg", dp + Vector3(0, 0.3, 0), -12.0, 6.0)
				Director.add_tension(7.0, "глаза в будке")

	# 2. Запертый ледник с паром: глухой двойной стук из-под крышки при приближении
	if anom != null and anom.is_active(&"cellar_steam") and cellar_prop != null and is_instance_valid(cellar_prop):
		var cp := cellar_prop.global_position
		if not _cellar_knocked and p_pos.distance_to(cp) < 5.8:
			_cellar_knocked = true
			if Game.audio != null:
				Game.audio.trigger_vacuum(2.6)
				Game.audio.play_3d("res://assets/audio/knock_v2.ogg", cp + Vector3(0, 0.35, 0), -10.0, 6.0)
			var t := get_tree().create_timer(0.45, false)
			t.timeout.connect(func() -> void:
				if is_instance_valid(self) and Game.audio != null:
					Game.audio.play_3d("res://assets/audio/knock_v2.ogg", cp + Vector3(0, 0.35, 0), -11.0, 6.0)
			)

	# 3. Закрытая тропа в тайгу: если светить за шлагбаум > 2.5 с, в глубине просеки на миг вспыхивают глаза
	if not _closed_trail_triggered and _closed_trail_eyes != null and is_instance_valid(_closed_trail_eyes):
		var gate_pos := Vector3(-6.8, 0.0, 8.2)
		if p_pos.distance_to(gate_pos) < 8.5 and p.flashlight_on() and p.is_looking_at(_closed_trail_eyes.global_position, 22.0):
			_closed_trail_stare_t += delta
			if _closed_trail_stare_t >= 2.5:
				_closed_trail_triggered = true
				_closed_trail_eyes.visible = true
				if Game.audio != null:
					Game.audio.trigger_vacuum(2.4)
				var hide_t := get_tree().create_timer(1.25, false)
				hide_t.timeout.connect(func() -> void:
					if is_instance_valid(_closed_trail_eyes):
						_closed_trail_eyes.visible = false
					if is_instance_valid(self) and Game.audio != null:
						Game.audio.play_3d("res://assets/audio/tree_creak_v2.ogg", Vector3(-14.5, 2.0, 7.2), -8.0, 12.0)
				)
		else:
			_closed_trail_stare_t = maxf(_closed_trail_stare_t - delta * 0.5, 0.0)


# --- API ---------------------------------------------------------------------

## Шар-пилот ещё низко и близко — его огонёк прикрывает игрока (Ырка сдаёт назад).
func balloon_covers(pos: Vector3) -> bool:
	if _pilot_balloon_node == null or not is_instance_valid(_pilot_balloon_node):
		return false
	var bp := _pilot_balloon_node.global_position
	return bp.y < 34.0 and Vector2(bp.x - pos.x, bp.z - pos.z).length() < 35.0


func zone_at(pos: Vector3) -> StringName:
	var lz := StationLore.zone_at(pos)   # подпол, тоннель, кабинет Голубева
	if lz != &"":
		return lz
	if MineHorizon.zone_has(pos):
		return &"mine"
	if pos.y < -10.0:
		return &"bunker"
	if (pos.x >= -41.5 and pos.x <= -31.0) and (pos.z >= 16.0 and pos.z <= 29.5):
		return &"lake_shack"
	var d_lake := (pos.x - LAKE.x) * (pos.x - LAKE.x) + (pos.z - LAKE.z) * (pos.z - LAKE.z)
	if d_lake < (LAKE_R + 1.0) * (LAKE_R + 1.0):
		return &"lake"
	var d_rep := (pos.x - REPEATER.x) * (pos.x - REPEATER.x) + (pos.z - REPEATER.z) * (pos.z - REPEATER.z)
	if d_rep < 49.0:
		return &"repeater"
	if (pos.x >= SHED.x - 4.0 and pos.x <= SHED.x + 8.0) and absf(pos.z - SHED.z) < 3.8:
		return &"shed"
	if (pos.x >= IZBA.x - 4.2 and pos.x <= IZBA.x + 5.6) and absf(pos.z - IZBA.z) < 3.5:
		return &"izba"
	var cz := MeteoCorpus.zone_at(pos)
	if cz != &"":
		return cz
	if _flat_dist(pos, PLOT) < 6.5 or _near_corpus(pos, 3.0):
		return &"meteo"
	var d_mast := (pos.x - MAST.x) * (pos.x - MAST.x) + (pos.z - MAST.z) * (pos.z - MAST.z)
	if d_mast < 49.0:
		return &"mast"
	return &"yard"



static var _bunker_mats: Dictionary = {}


## Материал аппаратуры бункера (кэш по цвету): шкалы, бобины, стёкла — не «тёмная палитра».
static func _bunker_mat(c: Color, glass := false) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), glass]
	if _bunker_mats.has(key):
		return _bunker_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.15 if glass else 0.6
	if glass:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bunker_mats[key] = m
	return m


## Расстояние по горизонтали до ближайшего леера.
func distance_to_path(pos: Vector3) -> float:
	return _dist_to(paths, pos)


## Безопасный свет: у фонаря над дверью (если есть питание).
func is_porch_lit(pos: Vector3) -> bool:
	return Game.power_on and _flat_dist(pos, Station.DOOR_LAMP) < PORCH_SAFE_RADIUS


## Точки для бумажной схемы станции.
func map_sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"pos": HOUSE_CENTER, "label": &"map.house", "size": Vector2(34, 18)},
		{"pos": WOODPILE, "label": &"map.wood", "size": Vector2(10, 6)},
		{"pos": METEO + Vector3(1.0, 0, -0.5), "label": &"map.meteo", "size": Vector2(18, 22)},
		{"pos": MAST, "label": &"map.mast", "size": Vector2(8, 8)},
		{"pos": SHED, "label": &"map.shed", "size": Vector2(18, 14)},
	]
	if izba_open:
		out.append({"pos": IZBA, "label": &"map.izba", "size": Vector2(16, 12)})
	if open_sites.get("repeater", false):
		out.append({"pos": REPEATER, "label": &"map.repeater", "size": Vector2(10, 10)})
	if open_sites.get("lake", false):
		out.append({"pos": LAKE, "label": &"map.lake", "size": Vector2(44, 34)})
	if open_sites.get("bunker", false):
		out.append({"pos": BUNKER, "label": &"map.bunker", "size": Vector2(6, 6)})
	if open_sites.get("zimnik", false):
		out.append({"pos": ZIMNIK, "label": &"map.zimnik", "size": Vector2(6, 6)})
	if FarSites.known():
		for site: StringName in FarSites.SITES:
			out.append({"pos": Terrain.pad_pos(site), "label": StringName("map.site_" + String(site)), "size": Vector2(10, 10), "far": true,
				"job": FieldJobs.job_site(String(site))})
		out.append_array(FieldJobs.map_sites())
		if SourceSite.found():
			out.append({"pos": Terrain.pad_pos(&"source"), "label": &"map.source", "size": Vector2(9, 9), "far": true})
	return out


## record_key: "placed_cans" — вынесены из сарая (вычитаются из его запаса), "site_cans" — лежат на дальних точках.
func spawn_pickup(item: StringName, pos: Vector3, record := true, record_key := "placed_cans") -> void:
	var size := Vector3(0.85, 0.45, 0.52) if item == &"trunk" else (Vector3(0.35, 0.45, 0.2) if item == &"canister" else Vector3(0.25, 0.35, 0.18) if item == &"oil" else Vector3(0.5, 0.85, 0.35) if item == &"shovel" else Vector3(0.35, 0.35, 0.35) if (item == &"kettle" or item == &"blowtorch") else Vector3(0.5, 0.28, 0.35))
	var it := Geo.interactable(self, size, Vector3(pos.x, pos.y + size.y / 2.0, pos.z), null, Loc.t(StringName("it.pick_" + String(item))), Callable())
	var model: Node3D = null
	if item == &"trunk":
		model = Props.expedition_trunk()
		model.position.y = -size.y * 0.5
		if Game.is_home() or _flat_dist(pos, HOUSE_CENTER) < 8.0:
			Game.set_flag("trunk_delivered", true)
			Game.hud.subtitle(Loc.t(&"sub.trunk_delivered"), 4.5)
			if not Game.has_flag("trunk_unpacked"):
				it.prompt = Loc.t(&"it.open_trunk")
	elif item == &"canister":
		model = Props.canister(false)
		model.position.y = -size.y * 0.5
		if record:
			var list: Array = (SaveGame.flags.get(record_key, []) as Array).duplicate()
			list.append([pos.x, pos.y, pos.z])
			SaveGame.flags[record_key] = list
			SaveGame.write()
	elif item == &"oil":
		model = Props.oil_can(false)
		model.position.y = -size.y * 0.5
	elif item == &"shovel":
		model = Props.snow_shovel()
		model.position.y = -size.y * 0.5
		model.rotation.x = deg_to_rad(85.0)
	elif item == &"kettle":
		model = Props.kettle()
		model.position.y = -size.y * 0.5
	elif item == &"blowtorch":
		model = Props.blowtorch()
		model.position.y = -size.y * 0.5
	else:
		model = Props.firewood_bundle(false)
		model.position.y = -size.y * 0.5
	if model != null:
		it.add_child(model)
	it.used.connect(_on_pickup.bind(it, item))


func _restore_placed_pickups() -> void:
	_migrate_site_cans()
	for key: String in ["placed_cans", "site_cans"]:
		var placed: Variant = SaveGame.flags.get(key, [])
		if placed is Array:
			for entry: Variant in placed:
				if entry is Array and (entry as Array).size() >= 3:
					var arr: Array = entry as Array
					var pos := Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
					spawn_pickup(&"canister", pos, false)


## Сохранения 1.16–1.17: канистры дальних точек попали в общий список и съедали запас сарая.
## Всё, что дальше 60 м от дома, переносим в отдельный список.
func _migrate_site_cans() -> void:
	if SaveGame.flags.has("site_cans") or not Game.has_flag("site_cans_seeded"):
		return
	var keep: Array = []
	var far: Array = []
	for entry: Variant in (SaveGame.flags.get("placed_cans", []) as Array):
		if entry is Array and (entry as Array).size() >= 3:
			var arr: Array = entry as Array
			if _flat_dist(Vector3(float(arr[0]), 0.0, float(arr[2])), HOUSE_CENTER) > 60.0:
				far.append(arr)
			else:
				keep.append(arr)
	SaveGame.flags["placed_cans"] = keep
	SaveGame.flags["site_cans"] = far


func _on_pickup(p: Player, it: Interactable, item: StringName) -> void:
	if item == &"trunk" and (Game.is_home() or _flat_dist(it.global_position, HOUSE_CENTER) < 8.0) and not Game.has_flag("trunk_unpacked"):
		Game.set_flag("trunk_unpacked", true)
		Game.audio.play_3d("res://assets/audio/clank.ogg", it.global_position, 1.0)
		Game.audio.play_3d("res://assets/audio/door.ogg", it.global_position, -4.0)
		Game.hud.subtitle(Loc.t(&"sub.trunk_unpacked"), 5.0)
		it.prompt = Loc.t(&"it.take_trunk")
		return
	if p.held != &"":
		Game.hud.subtitle(Loc.t(&"sub.hands_full"), 2.0)
		return
	if item == &"canister":
		# Ближайшая запись из любого списка (вынесенные из сарая или с дальних точек)
		var best_key := ""
		var best_idx := -1
		var best_dist := 999.0
		for key: String in ["placed_cans", "site_cans"]:
			var lst: Array = SaveGame.flags.get(key, []) as Array
			for i in range(lst.size()):
				var c_arr: Array = lst[i]
				var dist := it.global_position.distance_to(Vector3(float(c_arr[0]), float(c_arr[1]), float(c_arr[2])))
				if dist < best_dist:
					best_dist = dist
					best_idx = i
					best_key = key
		if best_idx >= 0:
			var list: Array = (SaveGame.flags.get(best_key, []) as Array).duplicate()
			list.remove_at(best_idx)
			SaveGame.flags[best_key] = list
			SaveGame.write()
	p.set_held(item)
	it.queue_free()


# --- Земля, леера, таблички --------------------------------------------------

## Атмосферная дымка теперь полностью обрабатывается глобальным Environment.fog без
## артефактных невидимых цилиндров, которые игрок мог пересечь и увидеть белые срезы.
func _build_forest_haze() -> void:
	pass


## Сугробы, наметённые к стенам дома: ветер с запада и севера кладёт снег вдоль сруба.
## Только меши (без коллизии), низкие — окна, лестница у трубы и крыльцо остаются свободными.
func _build_wall_drifts() -> void:
	var face := Station.LOG_FACE + 0.25
	var runs := [
		# [от, до, нормаль наружу, высота]
		[Vector3(-2.5 - face, 0, 0.2), Vector3(-2.5 - face, 0, 6.4), Vector3(-1, 0, 0), 0.55],   # запад жилой
		[Vector3(-2.3, 0, -face), Vector3(3.3, 0, -face), Vector3(0, 0, -1), 0.45],                # север жилой
		[Vector3(3.7, 0, -5.5 - face - 0.35), Vector3(6.8, 0, -5.5 - face - 0.35), Vector3(0, 0, -1), 0.45],       # север кладовой
		[Vector3(7.2, 0, -2.0 - face), Vector3(11.3, 0, -2.0 - face), Vector3(0, 0, -1), 0.42],     # север рубки
		[Vector3(-2.3, 0, 6.6 + face), Vector3(11.0, 0, 6.6 + face), Vector3(0, 0, 1), 0.28],       # юг — меньше, подветренный
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var blob := Props.snow_mound_mesh(0)
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var nrm: Vector3 = r[2]
		var h: float = r[3]
		var n := maxi(3, int(a.distance_to(b) / 0.75))   # часто и внахлёст — сплошной намёт, а не ряд «камней»
		for i in range(n + 1):
			var along := absf(nrm.x) < 0.5
			var len := rng.randf_range(1.4, 2.2)
			var wid := rng.randf_range(0.8, 1.15)
			# Сдвигаем сугробы строго наружу от стены с запасом на их ширину — исключает затекание геометрии внутрь избы
			var p := a.lerp(b, float(i) / n) + nrm * (wid * 0.5 + rng.randf_range(0.12, 0.25))
			var cur_h := h
			# Не заваливаем окна станции снаружи огромными шапками сугробов:
			# Западное окно жилой (z: 2.5..4.2): занижаем намёт под нижний срез рамы
			if absf(nrm.x) > 0.5 and p.z >= 2.4 and p.z <= 4.2:
				cur_h = 0.16
			# Южные окна жилой и коридора (x: -0.2..1.2 и 6.8..8.2)
			if absf(nrm.z) > 0.5 and ((p.x >= -0.2 and p.x <= 1.2) or (p.x >= 6.8 and p.x <= 8.2)):
				cur_h = 0.14
			var mi := MeshInstance3D.new()
			mi.mesh = blob
			mi.material_override = Palette.m(&"drift")
			mi.layers = Station.LAYER_OUT
			mi.position = p + Vector3(0, -cur_h * 0.25, 0)
			mi.scale = Vector3(len if along else wid, cur_h * rng.randf_range(0.75, 1.0), wid if along else len)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


func _build_ground() -> void:
	# Земля всей карты (1 км): двор ровный, дальше сопки, зимники и площадки (Terrain).
	# Сетка 4 м — один огромный квад «плыл» бы под камерой из-за PS1-снапа вершин.
	Terrain.build(self, 150.0 if Game.is_daylight() else 95.0)
	Landscape.build(self)   # хребет на горизонте, лёд ручья, мосток, останцы
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drift := Props.snow_mound_mesh(2)
	for i in range(36):
		var p := HOUSE_CENTER + Vector3(rng.randf_range(-65, 85), 0, rng.randf_range(-75, 65))
		# Исключаем дом станции со всеми комнатами (включая жилую комн., радиорубку, сени) с запасом на радиус сугроба
		if p.x >= -7.5 and p.x <= 22.0 and p.z >= -10.5 and p.z <= 11.5:
			continue
		# Исключаем дизельную «ДЭС-8» и мостки
		if p.x >= 10.0 and p.x <= 19.5 and p.z >= -18.5 and p.z <= -8.5:
			continue
		# Исключаем сарай ГСМ
		if p.x >= 40.0 and p.x <= 60.0 and p.z >= 26.0 and p.z <= 42.0:
			continue
		if _dist_to(_all_paths, p) < 2.0 or _flat_dist(p, IZBA) < 6.0 or _flat_dist(p, WOODPILE) < 6.0:
			continue
		if _flat_dist(p, LAKE) < LAKE_R + 2.5 or _flat_dist(p, REPEATER) < 6.0 or _flat_dist(p, BUNKER) < 3.5 or _near_corpus(p, 6.0):
			continue
		if _flat_dist(p, HELIPAD) < 10.0 or _flat_dist(p, HUNTER_SPRUCE_POS) < 4.0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = drift
		mi.material_override = Palette.m(&"drift")
		mi.position = Vector3(p.x, Terrain.height(p.x, p.z) - 0.12, p.z)
		mi.scale = Vector3(rng.randf_range(3.0, 7.0), rng.randf_range(0.2, 0.5), rng.randf_range(1.0, 2.0))
		var w_dir := Vector3(0.9, 0.0, 0.4).normalized()
		mi.rotation.y = atan2(-w_dir.z, w_dir.x) + rng.randf_range(-0.25, 0.25)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 50.0
		mi.visibility_range_end_margin = 8.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)


## Трос идёт вдоль обочины, в метре от оси тропы, а не по её середине.
func _offset_line(line: PackedVector3Array, off: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(line.size()):
		var nrm := Vector3.ZERO
		if i > 0:
			var d := (line[i] - line[i - 1]).normalized()
			nrm += Vector3(d.z, 0, -d.x)
		if i + 1 < line.size():
			var d2 := (line[i + 1] - line[i]).normalized()
			nrm += Vector3(d2.z, 0, -d2.x)
		nrm = nrm.normalized() if nrm.length_squared() > 0.0001 else Vector3.ZERO
		out.append(line[i] + nrm * off)
	return out


## Бесшовная натоптанная тропа: единая лента по рельефу Terrain.height с blend_mul и view-space bias (без z-fighting).
func _build_trail(line: PackedVector3Array) -> void:
	if line.size() < 2:
		return
	if _trail_mat == null:
		_trail_mat = ShaderMaterial.new()
		_trail_mat.shader = load("res://assets/shaders/trodden_path.gdshader") as Shader
		_trail_mat.render_priority = 1
	var day_trail := Game.is_daylight()
	_trail_mat.set_shader_parameter(&"rut_tint", Color(0.56, 0.62, 0.70) if day_trail else Color(0.16, 0.22, 0.30))
	_trail_mat.set_shader_parameter(&"strength", 0.56 if day_trail else 0.42)

	# Сэмплируем полилинию с шагом ~1.8 м, чтобы лента точно повторяла рельеф без провалов и стыков
	var pts: Array[Vector3] = []
	var dists: Array[float] = []
	var total := 0.0
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		if seg < 0.05:
			continue
		var steps := maxi(1, int(ceilf(seg / 1.8)))
		var start_k := 0 if pts.is_empty() else 1
		for k in range(start_k, steps + 1):
			var frac := float(k) / float(steps)
			var p := a.lerp(b, frac)
			p.y = Terrain.height(p.x, p.z) + 0.012
			pts.append(p)
			dists.append(total + seg * frac)
		total += seg
	if pts.size() < 2:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := TRAIL_W * 0.55
	var left_v: Array[Vector3] = []
	var right_v: Array[Vector3] = []
	var alphas: Array[float] = []

	for i in range(pts.size()):
		var fwd := Vector3.ZERO
		if i > 0:
			fwd += (pts[i] - pts[i - 1])
		if i + 1 < pts.size():
			fwd += (pts[i + 1] - pts[i])
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		var pl := pts[i] - side * half_w
		var pr := pts[i] + side * half_w
		pl.y = Terrain.height(pl.x, pl.z) + 0.012
		pr.y = Terrain.height(pr.x, pr.z) + 0.012
		left_v.append(pl)
		right_v.append(pr)
		var end_fade := minf(clampf(dists[i] / 0.85, 0.0, 1.0), clampf((total - dists[i]) / 0.85, 0.0, 1.0))
		alphas.append(end_fade)

	for i in range(pts.size() - 1):
		var v0 := left_v[i]
		var v1 := right_v[i]
		var v2 := left_v[i + 1]
		var v3 := right_v[i + 1]
		var a0 := Color(1.0, 1.0, 1.0, alphas[i])
		var a1 := Color(1.0, 1.0, 1.0, alphas[i + 1])
		var u0 := dists[i]
		var u1 := dists[i + 1]
		# Треугольник 1
		st.set_normal(Vector3.UP); st.set_color(a0); st.set_uv(Vector2(0.0, u0)); st.add_vertex(v0)
		st.set_normal(Vector3.UP); st.set_color(a1); st.set_uv(Vector2(0.0, u1)); st.add_vertex(v2)
		st.set_normal(Vector3.UP); st.set_color(a0); st.set_uv(Vector2(1.0, u0)); st.add_vertex(v1)
		# Треугольник 2
		st.set_normal(Vector3.UP); st.set_color(a0); st.set_uv(Vector2(1.0, u0)); st.add_vertex(v1)
		st.set_normal(Vector3.UP); st.set_color(a1); st.set_uv(Vector2(0.0, u1)); st.add_vertex(v2)
		st.set_normal(Vector3.UP); st.set_color(a1); st.set_uv(Vector2(1.0, u1)); st.add_vertex(v3)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _trail_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Цвет маршрута: на станциях леера метили флажками — красный к метео, синий к мачте и т. д.
## Форма флажка — вторая подсказка для тех, кто путает цвета: 0 вымпел, 1 прямоугольник, 2 «ласточкин хвост»,
## 3 два вымпела, 4 прямоугольник с белой полосой.
## Тот же цвет — на схеме [M] с легендой. Общий ствол от крыльца до развилки — без флажков.
const ROUTES := [
	{"to": CORPUS_PORCH, "shape": 0, "label": &"map.meteo", "color": Color(0.82, 0.14, 0.12)},
	{"to": MAST, "shape": 1, "label": &"map.mast", "color": Color(0.16, 0.32, 0.82)},
	{"to": SHED, "shape": 2, "label": &"map.shed", "color": Color(0.92, 0.76, 0.1)},
	{"to": WOODPILE, "shape": 3, "label": &"map.wood", "color": Color(0.16, 0.56, 0.22)},
	{"to": HELIPAD, "shape": 4, "label": &"map.helipad", "color": Color(0.96, 0.46, 0.08)},
	{"to": IZBA, "shape": 0, "label": &"map.izba", "color": Color(0.06, 0.06, 0.06)},
	{"to": REPEATER, "shape": 2, "label": &"map.repeater", "color": Color(0.52, 0.22, 0.66)},
	{"to": LAKE_SHACK, "shape": 3, "label": &"map.lake", "color": Color(0.22, 0.72, 0.82)},
	{"to": BUNKER, "shape": 1, "label": &"map.bunker", "color": Color(0.42, 0.26, 0.12)},
	{"to": ZIMNIK, "shape": 0, "label": &"map.zimnik", "color": Color(0.93, 0.93, 0.9)},
	{"to": Vector3(16.8, 0.0, 3.5), "shape": 4, "label": &"hud.station", "color": Color(0.95, 0.32, 0.16)},
]


## Маршрут, к которому ведёт тропа (по её концу), или пустой словарь для общего ствола.
func route_of(line: PackedVector3Array) -> Dictionary:
	if line.is_empty():
		return {}
	var end := line[line.size() - 1]
	for r: Dictionary in ROUTES:
		if _flat_dist(end, r["to"]) < 9.0:
			return r
	return {}


func _near_fork(p: Vector3) -> bool:
	for f: Vector3 in [JUNCTION, FORK, MAST_FORK]:
		if _flat_dist(p, f) < 3.2:
			return true
	return false


static func rod_pos() -> Vector3:
	var p := METEO + M_ROD
	return Vector3(p.x, Terrain.height(p.x, p.z), p.z)


# --- Аэрологический корпус и приборная площадка ---------------------------------------------

## Корпус, ангар, навес, мачта и ограда площадки — модели (tools/blender/corpus*.py) и MeteoCorpus;
## здесь — приборы, их замеры и наряды.
func _build_meteo() -> void:
	add_child(MeteoCorpus.new())
	# Табличка площадки — на ограде (corpus_yard.glb); вторая, отдельная, стояла с ней впритык

	# Действующая советская психрометрическая будка Селянинова
	var booth_pos := _gnd(METEO + M_BOOTH)
	var booth_prop: MeteoBoothScreen = Props.meteo_screen() as MeteoBoothScreen
	booth_prop.position = booth_pos
	booth_prop.name = "BoothModel"
	add_child(booth_prop)
	if Game.air_temp().x <= -30.0 and not Game.has_flag("booth_unfrozen"):
		booth_prop.is_frozen = true

	# Крупный кадр термометров (ThermometerUI): шкалу читаешь сам и вписываешь в книжку КМ-1.
	var booth_it := Geo.interactable(self, Vector3(0.75, 0.65, 0.65), booth_pos + Vector3(0.0, 1.55, 0.1), null, "", func(_p: Player) -> void:
		_interact_meteo_booth(booth_prop, booth_pos))
	booth_it.collision_layer = Geo.LAYER_INTERACT
	booth_it.prompt_provider = func() -> String:
		if booth_prop != null and is_instance_valid(booth_prop) and booth_prop.is_frozen and not booth_prop.is_open:
			return Loc.t(&"it.booth_frozen")
		return Loc.t(&"it.booth_done") if Game.readings.get(&"temp", false) else Loc.t(&"it.booth")
	booth_it.name = "BoothThermo"
	# Задание «откопать будку»: сугроб закрывает термометры, пока не разгребёшь лопатой.
	_drift = Geo.interactable(self, Vector3(1.3, 1.75, 1.2), booth_pos + Vector3(0, 0.95, 0), null, "", _on_drift_dug)
	# Округлый естественный перемет вокруг будки вместо серого монолитного ящика
	var d_blob := Props.snow_mound_mesh(1)
	for part: Array in [
		[Vector3(0.0, -0.2, 0.0), Vector3(1.15, 1.05, 1.15)],
		[Vector3(-0.25, -0.45, 0.35), Vector3(1.0, 0.75, 1.2)],
		[Vector3(0.3, -0.5, -0.25), Vector3(0.9, 0.7, 0.95)],
		[Vector3(0.0, 0.35, 0.0), Vector3(0.75, 0.55, 0.75)]
	]:
		var dm := MeshInstance3D.new()
		dm.mesh = d_blob
		dm.material_override = Palette.m(&"drift")
		dm.position = part[0]
		dm.scale = part[1]
		_drift.add_child(dm)
	_drift.prompt_provider = func() -> String:
		if Game.player != null and Game.player.held == &"shovel":
			return Loc.t(&"it.drift")
		return Loc.t(&"it.snowdrift_need_shovel")
	_drift.hold_check = func() -> bool:
		return Game.player != null and Game.player.held == &"shovel"
	_drift.hold_time = 3.0
	_drift.hold_sound = "res://assets/audio/step_snow_1.ogg"
	_drift.visible = false
	_drift.collision_layer = 0

	# Старая заброшенная будка 1961 года (осмотр с пугающей надписью)
	var old_screen := Props.old_meteo_screen()
	var old_pos := _gnd(METEO + M_OLD)
	old_screen.position = old_pos
	add_child(old_screen)
	var old_it := Geo.interactable(self, Vector3(0.9, 1.4, 0.9), old_pos + Vector3(0, 1.2, 0), null, Loc.t(&"it.old_meteo"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.old_meteo"), 5.0)
	)
	old_it.collision_layer = Geo.LAYER_INTERACT
	old_it.name = "OldMeteoScreen"

	# Советская снегомерная рейка М-103
	var rod := rod_pos()
	SnowStakeUI.build_stake(self, rod)   # снег на рейке — ровно на сегодняшней высоте
	# Крупный кадр рейки (SnowStakeUI): высоту снега читаешь сам — и в книжку КМ-1
	var stake_it := Geo.interactable(self, Vector3(0.7, 2.2, 0.7), rod + Vector3(0, 1.1, 0), null, "", func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"snow_stake"))
	stake_it.collision_layer = Geo.LAYER_INTERACT
	stake_it.prompt_provider = func() -> String:
		return Loc.t(&"it.stake_done") if Game.readings.get(&"snow", false) else Loc.t(&"it.stake")
	stake_it.name = "SnowStake"
	SiteDressing.meteo_plot_decor(self, PLOT, 4.5)

	# Анеморумбометр и флюгер — на мачте на кровле корпуса: обледенел — лезть на крышу и сбивать лёд.
	# Показание ветра снимают внутри, с пульта в аппаратной (датчик на крыше, стрелка — на пульте).
	var vane_ice_node := Props.anemo_ice()
	vane_ice_node.position = METEO + M_VANE + Vector3(0, 3.9, 0)
	vane_ice_node.name = "VaneIce"
	vane_ice_node.visible = Game.anemo_iced
	add_child(vane_ice_node)
	var vane_it := Geo.interactable(self, Vector3(0.9, 1.6, 0.9), METEO + M_VANE + Vector3(0, 0.8, 0), null, "", func(_p: Player) -> void:
		if Game.anemo_iced:
			Game.set_anemo_iced(false)
			vane_ice_node.visible = false
			Game.audio.play_3d(HIT_SOUND, METEO + M_VANE + Vector3(0, 3.9, 0), -3.0)
			Game.hud.subtitle(Loc.t(&"sub.anemo_cleared"), 3.5)
		else:
			Game.hud.subtitle(Loc.t(&"sub.anemo_clean"), 3.0)
	)
	vane_it.hold_time = 1.6
	vane_it.hold_sound = HIT_SOUND
	vane_it.hold_check = func() -> bool: return Game.anemo_iced
	vane_it.prompt_provider = func() -> String:
		return Loc.t(&"it.vane_ice") if Game.anemo_iced else Loc.t(&"it.vane_roof")
	vane_it.collision_layer = Geo.LAYER_INTERACT
	_vane_it = vane_it
	_vane_ice_node = vane_ice_node

	# Пульт анеморумбометра в аппаратной: показание ветра (лёд на датчике — стрелка мертва)
	# Крупный кадр шкал (WindPanelUI): стрелки считываешь сам — и в журнал.
	var pult := Geo.interactable(self, Vector3(1.4, 0.6, 0.5), MeteoCorpus.PULT_POS + Vector3(0, 1.0, 0.1), null, "", func(_p: Player) -> void:
		if MeteoCorpus.instance == null or not MeteoCorpus.instance.powered:
			Game.hud.subtitle(Loc.t(&"sub.pult_dark"), 3.0)
			return
		if Game.anemo_iced:
			Game.hud.subtitle(Loc.t(&"sub.pult_iced"), 3.5)
			return
		EventBus.ui_requested.emit(&"wind_panel"))
	pult.prompt_provider = func() -> String:
		if MeteoCorpus.instance == null or not MeteoCorpus.instance.powered:
			return Loc.t(&"it.pult_dark")
		return Loc.t(&"it.pult_done") if Game.readings.get(&"wind", false) else Loc.t(&"it.pult")
	pult.name = "WindPult"

	# Оптический теодолит АШТ в кабине башни — сопровождать шар-пилот
	var theodolite_pos := METEO + M_THEO
	var theodolite_prop := Props.theodolite()
	theodolite_prop.position = theodolite_pos
	add_child(theodolite_prop)
	var theodolite_it := Geo.interactable(self, Vector3(0.8, 1.6, 0.8), theodolite_pos + Vector3(0, 0.8, 0), null, Loc.t(&"it.theodolite"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"theodolite")
	)
	theodolite_it.name = "TheodolitePT"

	# Пусковой пост шаров-пилотов — в ангаре у ворот (наполнить и выпустить через открытые ворота)
	var balloon_stand_pos := METEO + M_BALLOON
	var stand_prop := Props.balloon_stand()
	stand_prop.position = balloon_stand_pos
	add_child(stand_prop)
	var balloon_stand_it := Geo.interactable(self, Vector3(0.9, 1.5, 0.9), balloon_stand_pos + Vector3(0, 0.75, 0), null, Loc.t(&"it.balloon_stand"), func(_p: Player) -> void:
		if MeteoCorpus.instance != null and not MeteoCorpus.instance.gates_open():
			Game.hud.subtitle(Loc.t(&"sub.balloon_gates"), 3.5)
			return
		_launch_pilot_balloon(balloon_stand_pos + Vector3(1.6, 0, 0))
	)
	balloon_stand_it.name = "BalloonStand"


## Около корпуса и его хозяйства (деревья и сугробы — не сюда).
func _near_corpus(p: Vector3, margin: float) -> bool:
	return (p.x > 88.0 - margin and p.x < 106.0 + margin and p.z > -40.0 - margin and p.z < -19.0 + margin) \
		or (p.x > 115.0 - margin and p.x < 129.0 + margin and p.z > -41.0 - margin and p.z < -27.0 + margin) \
		or _flat_dist(p, Vector3(112.0, 0, -13.0)) < 10.0 + margin * 0.3 \
		or _flat_dist(p, PLOT) < 6.5 + margin * 0.5


func _launch_pilot_balloon(pos: Vector3) -> void:
	if _pilot_balloon_node != null and is_instance_valid(_pilot_balloon_node):
		Game.hud.subtitle(Loc.t(&"sub.balloon_launched"), 3.5)
		return
	if Game.balloons_left <= 0:
		Game.hud.subtitle(Loc.t(&"sub.balloon_empty"), 3.5)
		return
	Game.balloons_left -= 1
	Game.balloon_launched = true
	_pilot_balloon_node = Props.pilot_balloon()
	_pilot_balloon_node.position = pos + Vector3(0, 0.8, 0)
	add_child(_pilot_balloon_node)
	var bl := _pilot_balloon_node.find_children("*", "OmniLight3D", true, false)
	_pilot_balloon_light = bl[0] as OmniLight3D if not bl.is_empty() else null
	AudioDirector.play_raw("res://assets/audio/flare.ogg", -4.0)
	Game.hud.subtitle(Loc.t(&"sub.balloon_launched_n", [Game.balloons_left]), 4.0)
	Director.add_tension(5.0, "запуск шара-пилота в метель")



func _reading_point(size: Vector3, pos: Vector3, mat: Material, key: StringName) -> void:
	var it := Geo.interactable(self, size, pos, mat, "", _on_reading.bind(key))
	it.hold_time = 1.6
	it.prompt_provider = _reading_prompt.bind(key)
	it.hold_check = _reading_open.bind(key)


func _reading_prompt(key: StringName) -> String:
	var name := Loc.t(StringName("instr." + String(key)))
	if Game.readings.get(key, false):
		return Loc.t(&"it.reading_done", [name])
	return Loc.t(&"it.reading", [name])


func _reading_open(key: StringName) -> bool:
	return not Game.readings.get(key, false)


## С 4-й ночи один раз сухой термометр в будке показывает +36,6 — температуру человека.
func claim_fever() -> bool:
	if Game.is_night() and Game.night >= 4 and not _fever_reading_done:
		_fever_reading_done = true
		return true
	return false


func _on_reading(_p: Player, key: StringName) -> void:
	if not Game.take_reading(key):
		return
	var text := ""
	match key:
		&"temp":
			var t_val: int = int(roundf(Game.synoptic.temp_dry)) if Game.synoptic != null else -Game.rng.randi_range(27, 36)
			text = Loc.t(&"read.temp", [t_val])
		&"wind":
			var w_val: int = int(roundf(Game.synoptic.wind_speed)) if Game.synoptic != null else Game.rng.randi_range(6, 10)
			var g_val: int = int(roundf(Game.synoptic.wind_gusts)) if Game.synoptic != null else Game.rng.randi_range(12, 18)
			text = Loc.t(&"read.wind", [w_val, g_val])
			if Game.anomalies != null and Game.anomalies.is_active(&"anemo_calm"):
				# Чашки анемометра живут своей жизнью: в штиль крутятся, в метель стоят.
				var storm := Game.weather != null and Game.weather.intensity > 0.45
				text = Loc.t(&"read.wind", [0, 0] if storm else [27, 34]) + " " + Loc.t(&"read.anemo_odd_storm" if storm else &"read.anemo_odd_calm")
		&"snow":
			var s_val: int = int(Game.synoptic.snow_depth_cm) if Game.synoptic != null else Game.rng.randi_range(84, 112)
			text = Loc.t(&"read.snow", [s_val])
	var left := Game.READING_KEYS.size() - Game.readings_count()
	var tail := Loc.t(&"read.all") if left == 0 else Loc.t(&"read.left", [left])
	if Net.active() and Net.role == "client":
		tail = Loc.t(&"coop.read_tell")   # сводку передаёт тот, кто в доме: цифры — ему по рации
	Game.hud.subtitle(text + " " + tail, 4.0)


# --- Мачта -------------------------------------------------------------------

func _build_mast() -> void:
	var metal := Palette.m(&"metal")
	# Бетонный фундаментный постамент с фасками
	Geo.block(self, Vector3(3.4, 0.45, 3.4), MAST + Vector3(0, 0.225, 0), Palette.m(&"concrete"))
	# Металлическая ажурная ферменная мачта 16м
	var mast_prop := Props.radio_mast(16.0)
	mast_prop.position = MAST + Vector3(0, 0.65, 0)
	add_child(mast_prop)
	var top := MAST + Vector3(0, 16.0, 0)
	for k in range(3):
		# 30° + k·120°: ни один якорь не стоит на тропе к мачте (с юга, по x = 24) — раньше блок 40×30 см
		# лежал прямо на тропе в 9 м от мачты, и игрок в него упирался.
		var a := deg_to_rad(30.0 + k * 120.0)
		var anchor := MAST + Vector3(cos(a) * 9.0, 0.2, sin(a) * 9.0)
		var wire := Geo.box_mesh(Vector3(0.025, 0.025, top.distance_to(anchor)), Palette.m(&"dark"))
		add_child(wire)
		wire.position = (top + anchor) / 2.0
		wire.look_at(anchor, Vector3.UP)
		var anc := Props.guy_anchor()
		anc.position = anchor - Vector3(0, 0.2, 0)
		anc.rotation.y = a
		add_child(anc)
		Geo.collider(self, Vector3(0.5, 0.35, 0.5), anchor - Vector3(0, 0.03, 0))
		# Талреп натяжения оттяжки
		Geo.cylinder(self, 0.035, 0.35, anchor + (top - anchor).normalized() * 0.8, metal, false)
		var ice := Props.guy_wire_ice(2.4)
		add_child(ice)
		ice.position = anchor.lerp(top, 0.12)
		ice.look_at(top, Vector3.UP)
		_ice_nodes.append(ice)

		var anc_it := Geo.interactable(self, Vector3(1.2, 1.4, 1.2), anchor + Vector3(0, 0.6, 0), null, "", func(_p: Player) -> void:
			_strike_guy_wire(anchor, ice, k)
		)
		anc_it.name = "GuyWireAnchor_%d" % k
		anc_it.prompt_provider = func() -> String:
			if Game.antenna_iced:
				var p := Game.player
				if p != null and (p.held == &"crowbar" or p.held == &"tools" or p.held == &"shovel"):
					return Loc.t(&"it.guy_wire_ice")
				return Loc.p("Оттяжка мачты: обледенела и гудит (нужен инструмент)", "Guy wire: iced and singing (tool needed)")
			return Loc.p("Талреп оттяжки: натянут", "Guy turnbuckle: tensioned")
	var base_ice := Props.mast_ice_base()
	base_ice.position = MAST + Vector3(0, 0.65, 0)
	add_child(base_ice)
	_ice_nodes.append(base_ice)

	# Лунная дорожка/тень от ажурной мачты на снегу (длинный шпиль, ползущий по насту)
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(0.48, 25.0)
	_mast_shadow = MeshInstance3D.new()
	_mast_shadow.mesh = shadow_mesh
	var shadow_dir := Vector3(sin(deg_to_rad(45.0)), 0.0, cos(deg_to_rad(45.0)))
	_mast_shadow.position = MAST + shadow_dir * 12.5 + Vector3(0.0, 0.038, 0.0)
	_mast_shadow.rotation = Vector3(-PI * 0.5, deg_to_rad(45.0), 0.0)
	_mast_shadow_mat = StandardMaterial3D.new()
	_mast_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mast_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mast_shadow_mat.albedo_color = Color(0.015, 0.03, 0.06, 0.44)
	_mast_shadow_mat.albedo_texture = _make_mast_shadow_texture()
	_mast_shadow.material_override = _mast_shadow_mat
	add_child(_mast_shadow)

	# Трансформаторный ящик у основания мачты с табличкой «НЕ ВЛЕЗАЙ — УБЬЕТ!»
	var tb := Props.transformer_booth()
	tb.position = MAST + Vector3(1.05, 0.45, -0.6)
	add_child(tb)
	var tb_it := Geo.interactable(self, Vector3(1.1, 1.6, 0.8), MAST + Vector3(1.05, 1.2, -0.6), null, Loc.t(&"it.transformer"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.transformer"), 4.0)
	)
	tb_it.name = "TransformerBooth"

	var it := Geo.interactable(self, Vector3(0.7, 1.6, 0.7), MAST + Vector3(0, 1.0, 0), null, "", _on_mast_used)
	it.hold_time = 4.0
	it.hold_sound = HIT_SOUND
	it.hold_check = func() -> bool: return Game.antenna_iced
	it.prompt_provider = func() -> String: return Loc.t(&"it.mast_ice") if Game.antenna_iced else Loc.t(&"it.mast")

	var panel := Geo.interactable(self, Vector3(0.45, 0.55, 0.18), MAST + Vector3(1.1, 1.2, 1.1), Palette.m(&"canister"), "", _on_mast_panel)
	panel.hold_time = 5.0
	panel.hold_sound = CLANK_SOUND
	panel.hold_check = func() -> bool: return _mast_lamp_out
	panel.prompt_provider = func() -> String: return Loc.t(&"it.mast_panel") if _mast_lamp_out else Loc.t(&"it.mast_panel_ok")
	Geo.block(self, Vector3(0.05, 1.2, 0.05), MAST + Vector3(1.1, 0.6, 1.1), Palette.m(&"dark"), false)

	# Рубильник заземления мачты (для геомагнитной бури) на стальной стойке
	Geo.block(self, Vector3(0.12, 0.9, 0.12), MAST + Vector3(-1.1, 0.45, -0.6), Palette.m(&"metal"), true)
	Models.spawn(self, "factory/lever-double", MAST + Vector3(-1.1, 0.9, -0.6), 90.0, 0.45)
	var ground_it := Geo.interactable(self, Vector3(0.5, 0.6, 0.3), MAST + Vector3(-1.1, 0.9, -0.6), null, "", _on_mast_ground_used)
	ground_it.hold_time = 3.0
	ground_it.hold_sound = CLANK_SOUND
	ground_it.hold_check = func() -> bool: return _mast_ground_active
	ground_it.prompt_provider = func() -> String: return Loc.t(&"it.mast_ground") if _mast_ground_active else ""

	# Искры Огней Эльма на ферме мачты
	_mast_ground_sparks = CPUParticles3D.new()
	_mast_ground_sparks.amount = 35
	_mast_ground_sparks.lifetime = 0.8
	_mast_ground_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_mast_ground_sparks.emission_box_extents = Vector3(1.2, 8.0, 1.2)
	_mast_ground_sparks.position = MAST + Vector3(0, 8.0, 0)
	_mast_ground_sparks.direction = Vector3(0, 1, 0)
	_mast_ground_sparks.spread = 180.0
	_mast_ground_sparks.gravity = Vector3(0, -2.0, 0)
	_mast_ground_sparks.initial_velocity_min = 0.5
	_mast_ground_sparks.initial_velocity_max = 2.0
	_mast_ground_sparks.color = Color(0.55, 0.65, 1.0, 0.9)
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	var sp_mat := StandardMaterial3D.new()
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mat.albedo_color = Color(0.6, 0.75, 1.0)
	sm.material = sp_mat
	_mast_ground_sparks.mesh = sm
	_mast_ground_sparks.emitting = false
	add_child(_mast_ground_sparks)

	_mast_ground_sound = AudioStreamPlayer3D.new()
	_mast_ground_sound.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/elec_buzz_loop.ogg")
	_mast_ground_sound.position = MAST + Vector3(0, 3.0, 0)
	_mast_ground_sound.unit_size = 14.0
	_mast_ground_sound.max_distance = 40.0
	_mast_ground_sound.volume_db = 3.0
	_mast_ground_sound.bus = &"SFX"
	add_child(_mast_ground_sound)

	# Огонь — в колпаке на макушке (мачта стоит на постаменте 0.65 м, колпак на 16 м над ним)
	_mast_light = Geo.omni(self, MAST + Vector3(0, 16.83, 0), 5.0, 1.3, Color(1.0, 0.1, 0.05))
	_mast_halos = [
		Atmosphere.add_halo(_mast_light, 2.6, Color(1.0, 0.12, 0.08, 0.7)),   # красный огонь мачты — виден из любой точки двора
		Atmosphere.add_halo(_mast_light, 7.0, Color(1.0, 0.16, 0.1, 0.22)),    # и розовое пятно ледяного тумана вокруг
	]
	Geo.bulb(_mast_light, &"red", 0.14)
	Game.level.register_lamp(_mast_light)

	# Штормовой янтарный маяк (навигационный ориентир в метели)
	var beacon_quad := QuadMesh.new()
	beacon_quad.size = Vector2(14.0, 14.0)
	_mast_beacon_mesh = MeshInstance3D.new()
	_mast_beacon_mesh.mesh = beacon_quad
	_mast_beacon_mesh.position = MAST + Vector3(0, 16.83, 0)
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	b_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	b_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	b_mat.disable_fog = true
	b_mat.albedo_texture = _beacon_texture()
	b_mat.albedo_color = Color(1.0, 0.60, 0.15, 0.0)
	_mast_beacon_mesh.material_override = b_mat
	add_child(_mast_beacon_mesh)


static var _beacon_tex: ImageTexture
static func _beacon_texture() -> ImageTexture:
	if _beacon_tex != null:
		return _beacon_tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := (exp(-d * d * 28.0) + exp(-d * d * 5.0) * 0.35) * (1.0 - smoothstep(0.75, 1.0, d))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_beacon_tex = ImageTexture.create_from_image(img)
	return _beacon_tex


static func _make_mast_shadow_texture() -> ImageTexture:
	var img := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var v := float(y) / 127.0
		var tip_fade := 1.0 - smoothstep(0.82, 1.0, v)
		var is_crossbar := (y % 14 < 3)
		for x in 32:
			var u := (float(x) / 31.0) * 2.0 - 1.0
			var edge := clampf((1.0 - absf(u)) * 1.6, 0.0, 1.0)
			var dens := 0.9 if is_crossbar else (0.65 if absf(u) > 0.45 else 0.28)
			var a := edge * dens * tip_fade
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _on_mast_used(_p: Player) -> void:
	if not Game.antenna_iced:
		Game.hud.subtitle(Loc.p("Мачта «Унжа-1» (25 м): оттяжки натянуты, заградительный огонь ЗОМ чист от льда.", "Mast 'Unzha-1' (25m): guy wires tensioned, ZOM obstacle light clear of ice."), 3.5)
		return
	_climb_unzha_mast()


func _climb_unzha_mast() -> void:
	var p := Game.player
	if p == null:
		return
	Game.audio.play_3d("res://assets/audio/clank.ogg", MAST + Vector3(0, 2.0, 0), -2.0)
	Game.hud.subtitle(Loc.p("Пристегнул карабин пояса ПМ-1 к скобтрапу мачты «Унжа-1» (25 м). Подъём...", "Snapped PM-1 safety belt carabiner to the Unzha-1 mast ladder (25m). Climbing..."), 3.5)
	p.shake(0.05, 0.4)

	# Таймеры и контрольные точки на 8м, 16м, 24м
	get_tree().create_timer(1.8, false).timeout.connect(func() -> void:
		if p != null:
			p.shake(0.08, 0.5)
			Game.audio.play_3d("res://assets/sfx/wind_gust.ogg", MAST + Vector3(0, 12.0, 0), 2.0)
			Game.hud.subtitle(Loc.p("Высота 16 м: порыв ветра 28 м/с! Мачта гудит и вибрирует с амплитудой 35 см...", "Height 16m: 28 m/s wind gust! The mast hums and sways with 35cm amplitude..."), 3.5)
	)

	get_tree().create_timer(4.0, false).timeout.connect(func() -> void:
		Game.set_antenna_iced(false)
		Game.audio.play_3d(HIT_SOUND, MAST + Vector3(0, 16.0, 0), 2.0)
		if p != null:
			p.shake(0.04, 0.4)
		Game.hud.subtitle(Loc.p("Оголовье 25 м: ключом на 21 сколол ледяной панцирь с плафона ЗОМ! Рубиновый маяк горит.", "Top 25m: chipped rime ice off ZOM beacon with 21mm wrench! Ruby beacon ignited."), 4.5)
		_check_routine_scare_mast()
	)


func _on_mast_ground_used(_p: Player) -> void:
	if not _mast_ground_active:
		return
	_set_mast_ground_hazard(false)
	if Game.tasks != null:
		Game.tasks.complete(&"mast_ground")
	Game.hud.subtitle(Loc.t(&"sub.mast_ground_done"), 4.0)
	Director.add_tension(-10.0, "рубильник заземления включен")
	_check_routine_scare_mast()


func _strike_guy_wire(anchor: Vector3, ice_node: Node3D, k: int) -> void:
	if not Game.antenna_iced:
		Game.hud.subtitle(Loc.p("Талреп натянут, струна оттяжки звенит чистым металлическим тоном.", "Turnbuckle is tensioned, the wire rings with a clean metallic tone."), 3.5)
		return
	var p := Game.player
	var has_tool: bool = p != null and (p.held == &"crowbar" or p.held == &"tools" or p.held == &"shovel")
	if not has_tool:
		Game.hud.subtitle(Loc.p("Оттяжка вибрирует от ледяного панциря. Нужен лом или топорик, чтобы сколоть наледь.", "The guy wire vibrates under an ice casing. Need a crowbar or hatchet to chip the ice off."), 4.0)
		return

	# Удар по оттяжке
	Game.audio.play_3d(HIT_SOUND, anchor + Vector3(0, 1.2, 0), 2.5)
	Game.audio.play_3d(CLANK_SOUND, anchor + Vector3(0, 0.5, 0), 0.0)
	_spawn_wire_ice_particles(anchor + Vector3(0, 1.0, 0))

	if p != null:
		p.shake(0.06, 0.35)
		p.crank_flash(-8.0) # мигание нити накаливания ФАС-4 от механического удара
		Game.add_fatigue(2.5)

	if is_instance_valid(ice_node):
		ice_node.visible = false
	_cleared_anchors[k] = true

	if _cleared_anchors.size() >= 3:
		Game.set_antenna_iced(false)
		Game.hud.subtitle(Loc.t(&"sub.guy_wire_done"), 5.0)
		Director.add_tension(-15.0, "оттяжки мачты очищены от наледи")
	else:
		Game.hud.subtitle(Loc.t(&"sub.guy_wire_hit") + " (%d/3)" % _cleared_anchors.size(), 4.0)


func _spawn_wire_ice_particles(pos: Vector3) -> void:
	var sp := CPUParticles3D.new()
	sp.amount = 25
	sp.lifetime = 0.9
	sp.one_shot = true
	sp.explosiveness = 0.95
	sp.position = pos
	sp.direction = Vector3(0, -1, 0)
	sp.spread = 55.0
	sp.gravity = Vector3(0, -9.8, 0)
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 4.5
	var sm := BoxMesh.new()
	sm.size = Vector3(0.035, 0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.92, 0.98, 0.8)
	mat.roughness = 0.2
	sm.material = mat
	sp.mesh = sm
	add_child(sp)
	sp.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(sp.queue_free)


func _on_antenna_iced(iced: bool) -> void:
	if not iced:
		_cleared_anchors.clear()
	for n in _ice_nodes:
		n.visible = iced


func _on_anemo_iced(iced: bool) -> void:
	if is_instance_valid(_vane_ice_node):
		_vane_ice_node.visible = iced
	if is_instance_valid(_vane_it):
		_vane_it.hold_sound = HIT_SOUND if iced else ""


# --- Сарай ГСМ (2 отсека: тёплая мастерская и тёмный склад с «Бураном») --------

## Габарит сарая ГСМ с запасом (ангар 11.2×6.6 м тянется на восток от SHED) — без деревьев и кустов.
func _in_shed_box(p: Vector3) -> bool:
	return p.x > SHED.x - 6.0 and p.x < SHED.x + 10.5 and p.z > SHED.z - 5.5 and p.z < SHED.z + 5.5


## Коробка оболочки постройки: при готовой модели — только коллизия (или ничего), иначе прежний блок.
func _blk(model: bool, size: Vector3, pos: Vector3, mat: Material, collide := true) -> void:
	if not model:
		Geo.block(self, size, pos, mat, collide)
		return
	if not collide:
		return
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.add_child(Geo.box_shape(size))
	add_child(body)


func _build_shed() -> void:
	var mat := Palette.m(&"plank")
	var logm := Palette.m(&"log")
	var wall_h := 3.5
	var total_len := 11.2
	var shed_w := 6.6
	var shed_center := SHED + Vector3(2.0, 0, 0) # охватывает x: -3.6 .. +7.6 от SHED
	# Новый облик (tools/blender/shed.py): коробки оболочки ниже — только коллизия, вид даёт модель
	var model := Models.spawn(self, "kedr/shed", Vector3(0, SHED_MODEL_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0}) != null

	# Фундамент под всем ангаром, заглублённый в грунт до -0.9м
	_blk(model, Vector3(total_len + 0.4, 0.8, shed_w + 0.4), shed_center + Vector3(0, -0.5, 0), Palette.m(&"dark"), true)
	# Сплошной дощатый пол ангара (поднят над грунтом и фундаментом, без CSG-артефактов)
	_blk(model, Vector3(total_len, 0.18, shed_w), shed_center + Vector3(0, -0.09, 0), Palette.m(&"wood"), true)
	# Потолок
	_blk(model, Vector3(total_len, 0.15, shed_w), shed_center + Vector3(0, wall_h + 0.07, 0), mat, false)

	# Наружные бревенчатые стены ангара:
	# Северная глухая стена
	_blk(model, Vector3(total_len, wall_h, 0.24), shed_center + Vector3(0, wall_h / 2.0, -shed_w / 2.0), logm, true)
	# Южная глухая стена
	_blk(model, Vector3(total_len, wall_h, 0.24), shed_center + Vector3(0, wall_h / 2.0, shed_w / 2.0), logm, true)
	# Восточная глухая задняя стена
	_blk(model, Vector3(0.24, wall_h, shed_w), shed_center + Vector3(total_len / 2.0, wall_h / 2.0, 0), logm, true)

	# Западная фасадная стена с широкими воротами (проём шириной 2.2м, высотой 2.7м):
	_blk(model, Vector3(0.24, wall_h, 2.2), shed_center + Vector3(-total_len / 2.0, wall_h / 2.0, -2.2), logm, true)
	_blk(model, Vector3(0.24, wall_h, 2.2), shed_center + Vector3(-total_len / 2.0, wall_h / 2.0, 2.2), logm, true)
	_blk(model, Vector3(0.24, wall_h - 2.7, 2.2), shed_center + Vector3(-total_len / 2.0, 2.7 + (wall_h - 2.7) / 2.0, 0), logm, true)
	# Косяки и притолока проёма
	_blk(model, Vector3(0.08, 2.7, 0.08), shed_center + Vector3(-total_len / 2.0, 1.35, -1.1), Palette.m(&"plank"), false)
	_blk(model, Vector3(0.08, 2.7, 0.08), shed_center + Vector3(-total_len / 2.0, 1.35, 1.1), Palette.m(&"plank"), false)
	_blk(model, Vector3(0.08, 0.08, 2.28), shed_center + Vector3(-total_len / 2.0, 2.7, 0), Palette.m(&"plank"), false)

	# Двустворчатые дощатые ворота сарая на кованых петлях
	_shed_door_left_hinge = Node3D.new()
	_shed_door_left_hinge.position = shed_center + Vector3(-total_len / 2.0, 0.0, -1.08)
	add_child(_shed_door_left_hinge)

	var s_left := Interactable.new()
	s_left.collision_layer = Geo.LAYER_WORLD
	s_left.position = Vector3(0.0, 1.3, 0.54)
	s_left.prompt_provider = func() -> String: return Loc.t(&"it.shed_door_close") if shed_doors_open else Loc.t(&"it.shed_door_open")
	s_left.add_child(Geo.box_mesh(Vector3(0.08, 2.6, 1.08), Palette.m(&"plank")))
	s_left.add_child(Geo.box_shape(Vector3(0.08, 2.6, 1.08)))
	s_left.used.connect(_on_shed_doors_used)
	_shed_door_left_hinge.add_child(s_left)

	_shed_door_right_hinge = Node3D.new()
	_shed_door_right_hinge.position = shed_center + Vector3(-total_len / 2.0, 0.0, 1.08)
	add_child(_shed_door_right_hinge)

	var s_right := Interactable.new()
	s_right.collision_layer = Geo.LAYER_WORLD
	s_right.position = Vector3(0.0, 1.3, -0.54)
	s_right.prompt_provider = func() -> String: return Loc.t(&"it.shed_door_close") if shed_doors_open else Loc.t(&"it.shed_door_open")
	s_right.add_child(Geo.box_mesh(Vector3(0.08, 2.6, 1.08), Palette.m(&"plank")))
	s_right.add_child(Geo.box_shape(Vector3(0.08, 2.6, 1.08)))
	s_right.used.connect(_on_shed_doors_used)
	_shed_door_right_hinge.add_child(s_right)

	# Обледеневший замок на воротах склада ГСМ
	var padlock_needed: bool = not Game.is_prologue() and (Game.night >= 1 or (Game.synoptic != null and Game.synoptic.temp_dry <= -26.0)) and not Game.has_flag("shed_padlock_thawed")
	if padlock_needed:
		var pad_pos := shed_center + Vector3(-total_len / 2.0 - 0.08, 1.25, 0.0)
		_shed_padlock = Props.frozen_padlock()
		_shed_padlock.position = pad_pos
		add_child(_shed_padlock)
		_shed_padlock_it = Geo.interactable(self, Vector3(0.5, 0.5, 0.5), pad_pos, null, Loc.t(&"it.frozen_padlock"), _on_shed_padlock_used)

	# Тяжёлая железная цепь на воротах склада ГСМ со скрипом и постукиванием
	var chain := Props.shed_chain()
	chain.position = shed_center + Vector3(-total_len / 2.0 - 0.04, 0.0, 0.0)
	add_child(chain)

	var chain_it := Geo.interactable(self, Vector3(0.9, 1.2, 0.9), chain.position + Vector3(0, 1.2, 0), null, Loc.t(&"it.shed_chain"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.shed_chain"), 4.5)
	)
	chain_it.name = "ShedChainInteractable"

	var chain_audio := AudioStreamPlayer3D.new()
	chain_audio.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/door_rattle.ogg") if ResourceLoader.exists("res://assets/sfx/cc0/door_rattle.ogg") else AudioDirector.cached_stream("res://assets/audio/clank.ogg")
	chain_audio.position = chain.position + Vector3(0, 1.2, 0)
	chain_audio.volume_db = -18.0
	chain_audio.unit_size = 5.0
	chain_audio.max_distance = 18.0
	chain_audio.bus = &"SFX"
	add_child(chain_audio)

	# Занос/сугроб перед входом в сарай (начиная со второй ночи/дня)
	var shed_drift_pos := shed_center + Vector3(-total_len / 2.0 - 0.7, 0.0, 0.0)
	var drift_cleared: bool = bool(SaveGame.flags.get("shed_drift_cleared_n" + str(Game.night), false))
	var drift_needed: bool = (Game.night >= 2 or not Game.is_prologue()) and not drift_cleared
	_shed_drift = Geo.interactable(self, Vector3(1.4, 1.35, 2.3), shed_drift_pos + Vector3(0, 0.65, 0), null, "", _on_shed_drift_dug)
	# Намёт у ворот — округлый сугроб с языком, а не куб
	var d_blob := Props.snow_mound_mesh(0)
	for part: Array in [[Vector3(0.05, -0.65, 0.0), Vector3(0.95, 1.3, 1.45)], [Vector3(-0.55, -0.65, 0.5), Vector3(0.9, 0.75, 1.0)],
			[Vector3(0.3, -0.65, -0.75), Vector3(0.7, 0.95, 0.8)]]:
		var dm := MeshInstance3D.new()
		dm.mesh = d_blob
		dm.material_override = Palette.m(&"drift")
		dm.position = part[0]
		dm.scale = part[1]
		_shed_drift.add_child(dm)
	_shed_drift.prompt_provider = func() -> String:
		if Game.player != null and Game.player.held == &"shovel":
			return Loc.t(&"it.snowdrift")
		return Loc.t(&"it.snowdrift_need_shovel")
	_shed_drift.hold_check = func() -> bool:
		return Game.player != null and Game.player.held == &"shovel"
	_shed_drift.hold_time = 3.5
	_shed_drift.hold_sound = "res://assets/audio/step_snow_2.ogg"
	_shed_drift.visible = drift_needed
	_shed_drift.collision_layer = Geo.LAYER_WORLD if drift_needed else 0

	# Внутренняя решётчатая бревенчатая перегородка мастерской (проём по центру шириной 2.2м)
	_blk(model, Vector3(0.18, wall_h, 2.2), SHED + Vector3(-0.6, wall_h / 2.0, -2.2), mat, true)
	_blk(model, Vector3(0.18, wall_h, 2.2), SHED + Vector3(-0.6, wall_h / 2.0, 2.2), mat, true)
	_blk(model, Vector3(0.18, wall_h - 2.6, 2.2), SHED + Vector3(-0.6, 2.6 + (wall_h - 2.6) / 2.0, 0), mat, true)

	# Старый вид фронтонов, ферм и кровли — только без модели
	if not model:
		# Фронтоны под коньком крыши с запада и востока (треугольные призмы, не пробивающие кровлю)
		for end_x in [-total_len / 2.0, total_len / 2.0]:
			var g_pm := PrismMesh.new()
			g_pm.size = Vector3(shed_w - 0.2, 1.55, 0.16)
			var gable := MeshInstance3D.new()
			gable.mesh = g_pm
			gable.material_override = mat
			gable.position = shed_center + Vector3(end_x, wall_h + 1.55 / 2.0, 0)
			gable.rotation.y = deg_to_rad(90.0)
			add_child(gable)

		# Высокие открытые стропила и балки под двускатной крышей ангара
		for i in range(5):
			var tx := -3.2 + i * 2.6
			var b_pos := SHED + Vector3(tx, wall_h, 0)
			# Поперечная затяжка (балка)
			_blk(model, Vector3(0.14, 0.14, shed_w - 0.2), b_pos, Palette.m(&"dark"), false)
			# Вертикальная стойка (бабка) к коньку
			_blk(model, Vector3(0.12, 1.6, 0.12), b_pos + Vector3(0, 0.8, 0), Palette.m(&"dark"), false)
			# Наклонные подкосы стропил
			for side in [-1.0, 1.0]:
				var strut := Geo.block_rotated(self, Vector3(0.1, 0.1, 3.4), b_pos + Vector3(0, 0.7, side * 1.6), deg_to_rad(26.0 * side), Palette.m(&"dark"))

		# Двускатная крыша склада-ангара со снегом и сосульками
		for side in [-1.0, 1.0]:
			var roof_slab := Geo.box_mesh(Vector3(total_len + 0.6, 0.14, shed_w * 0.58), mat)
			roof_slab.position = shed_center + Vector3(0, wall_h + 0.85, side * (shed_w * 0.27))
			roof_slab.rotation.x = deg_to_rad(26.0 * side)
			add_child(roof_slab)
			var roof_snow := Geo.box_mesh(Vector3(total_len + 0.55, 0.1, shed_w * 0.56), Palette.m(&"snow"))
			roof_snow.position = shed_center + Vector3(0, wall_h + 0.95, side * (shed_w * 0.27))
			roof_snow.rotation.x = deg_to_rad(26.0 * side)
			add_child(roof_snow)

		var shed_ice := Props.icicles(total_len, 20)
		shed_ice.position = shed_center + Vector3(0, wall_h + 0.2, -shed_w / 2.0 - 0.1)
		add_child(shed_ice)

	# --- 1. Передний отсек: мастерская ГСМ ---
	# Слесарный верстак с тисками под канистры
	var bench_body := StaticBody3D.new()
	bench_body.collision_layer = Geo.LAYER_WORLD
	bench_body.collision_mask = 0
	bench_body.position = SHED + Vector3(-2.2, 0.0, -2.1)
	bench_body.rotation.y = deg_to_rad(90.0)
	bench_body.add_child(Props.workbench())
	bench_body.add_child(Geo.box_shape(Vector3(2.2, 0.9, 0.75), Vector3(0, 0.45, 0)))
	add_child(bench_body)

	# Канистры на верстаке — ровно столько, сколько их реально осталось (до 6 в ряд).
	# Если канистры уже вынесены во двор, в складе остаётся остаток от общего запаса
	_migrate_site_cans()
	var placed_count: int = (SaveGame.flags.get("placed_cans", []) as Array).size()
	if placed_count > 0 and Game.canisters_left > 0:
		Game.canisters_left = maxi(0, Game.canisters_left - placed_count)

	var cans := Geo.interactable(self, Vector3(0.7, 0.45, 1.95), SHED + Vector3(-2.2, 1.05, -2.1), null, "", _on_canisters_used)
	cans.prompt_provider = func() -> String: return Loc.t(&"it.cans_none") if Game.canisters_left <= 0 else Loc.t(&"it.cans", [Game.canisters_left])
	for i in range(6):
		var c_prop := Props.canister(false)
		c_prop.position = Vector3(0.0, -0.1, -0.8 + i * 0.32)
		cans.add_child(c_prop)
		_can_models.append(c_prop)
	_update_cans()

	# Ящик с вещами Семёнова — день 1
	if not Game.has_item(&"tape_recorder") and Game.is_day() and Game.phase_index >= 1:
		var crate := Geo.interactable(self, Vector3(0.8, 0.5, 0.55), SHED + Vector3(-2.2, 0.25, 2.0), null, Loc.t(&"it.crate"), Callable())
		var crate_model := Props.semenov_crate()
		crate_model.position.y = -0.25
		crate.add_child(crate_model)
		crate.used.connect(_on_crate_used.bind(crate))

	# Масло для генератора — банка МС-20
	var oil := Geo.interactable(self, Vector3(0.25, 0.35, 0.18), SHED + Vector3(-1.8, 0.17, 2.4), null, "", _on_oil_taken)
	_oil_can_it = oil
	var oil_model := Props.oil_can(false)
	oil_model.position.y = -0.17
	oil.add_child(oil_model)
	oil.prompt_provider = func() -> String:
		return Loc.t(&"it.oil") if Game.tasks != null and Game.tasks.is_active(&"oil") else Loc.t(&"it.oil_idle")

	# Инструменты Семёнова — с пятой ночи
	if Game.progress() >= 9 and not Game.has_item(&"tools"):
		var box := Geo.interactable(self, Vector3(0.6, 0.3, 0.35), SHED + Vector3(-1.2, 0.15, -2.2), null, Loc.t(&"it.tools"), Callable())
		var box_model := Props.tools_box()
		box_model.position.y = -0.15
		box.add_child(box_model)
		box.used.connect(func(_p: Player) -> void:
			Game.give_item(&"tools")
			Game.audio.play_3d(CLANK_SOUND, box.global_position, -2.0)
			Game.hud.subtitle(Loc.t(&"sub.got_tools"), 4.0)
			box.queue_free())

	# Топливный фильтр-отстойник и кран продувки (при загустении солярки на морозе)
	# Вертикальная топливная труба от пола к крану
	Geo.cylinder(self, 0.04, 0.8, SHED + Vector3(-0.6, 0.4, -2.1), Palette.m(&"dark"), false)
	# Крепление к стене сарая
	Geo.block(self, Vector3(0.08, 0.08, 0.35), SHED + Vector3(-0.6, 0.8, -2.25), Palette.m(&"dark"), false)
	# Маховик вентиля
	var valve_wheel := Geo.cylinder(self, 0.11, 0.035, SHED + Vector3(-0.6, 0.8, -1.9), Palette.m(&"rust"), false)
	valve_wheel.rotation.x = deg_to_rad(90.0)

	var fuel_valve := Geo.interactable(self, Vector3(0.5, 0.6, 0.35), SHED + Vector3(-0.6, 0.8, -2.1), Palette.m(&"metal"), "", func(_p: Player) -> void:
		if Game.fuel_sputter:
			Game.set_fuel_sputter(false)
			Game.audio.play_3d(CLANK_SOUND, SHED + Vector3(-0.6, 0.8, -2.1), 0.0)
			Game.hud.subtitle(Loc.t(&"sub.fuel_restored"), 4.0)
	)
	fuel_valve.hold_time = 2.5
	fuel_valve.hold_sound = CLANK_SOUND
	fuel_valve.hold_check = func() -> bool: return Game.fuel_sputter
	fuel_valve.prompt_provider = func() -> String:
		return Loc.t(&"it.fuel_bleed") if Game.fuel_sputter else Loc.t(&"it.fuel_valve")

	# Тусклая лампа на длинном шнуре
	var l := Geo.omni(self, SHED + Vector3(-1.5, 2.6, 0), 6.5, 0.65, Color(1.0, 0.85, 0.6))
	Geo.bulb(l, &"bulb")
	Game.level.register_lamp(l)

	# --- 2. Центральный отсек: лабиринт из бочек и высокие стеллажи ---
	# Высокие ряды промышленных стеллажей вдоль стен
	var sh1 := Props.storage_shelves()
	sh1.position = SHED + Vector3(0.8, 0.0, -2.5)
	add_child(sh1)
	var sh2 := Props.storage_shelves()
	sh2.position = SHED + Vector3(3.2, 0.0, -2.5)
	add_child(sh2)
	var sh3 := Props.storage_shelves()
	sh3.position = SHED + Vector3(0.8, 0.0, 2.5)
	add_child(sh3)
	var sh4 := Props.storage_shelves()
	sh4.position = SHED + Vector3(3.2, 0.0, 2.5)
	add_child(sh4)

	# Лабиринт из 200-литровых дизельных бочек
	var barrel_coords: Array[Vector3] = [
		Vector3(0.2, 0.0, -1.2), Vector3(0.2, 0.0, -0.3), Vector3(0.2, 0.0, 1.4),
		Vector3(1.3, 0.0, 0.5), Vector3(1.3, 0.0, -1.5), Vector3(1.3, 0.88, 0.5),
		Vector3(2.4, 0.0, -0.6), Vector3(2.4, 0.0, 1.2), Vector3(2.4, 0.0, 2.1),
		Vector3(3.6, 0.0, -1.3), Vector3(3.6, 0.0, 0.2), Vector3(3.6, 0.88, -1.3),
		Vector3(4.5, 0.0, 1.4), Vector3(4.5, 0.0, -0.8)
	]
	for bp in barrel_coords:
		var b := Props.barrel()
		b.position = SHED + bp
		add_child(b)

	# --- 3. «Буран» Семёнова теперь рабочий и стоит под чехлом у гаража (Snowmobile) ---
	# Рабочий «Буран» Семёнова — под чехлом у ворот гаража
	add_child(Snowmobile.new())

	# Подвесная цепная таль со стропила над снегоходом
	var hoist := Props.chain_hoist()
	hoist.position = SHED + Vector3(5.8, wall_h - 0.9, 0)
	add_child(hoist)

	# Захламление угла: штабели деревянных полярных ящиков с запчастями
	var crates_body1 := StaticBody3D.new()
	crates_body1.collision_layer = Geo.LAYER_WORLD
	crates_body1.collision_mask = 0
	crates_body1.position = SHED + Vector3(6.8, 0.0, -2.0)
	crates_body1.add_child(Props.stacked_crates())
	crates_body1.add_child(Geo.box_shape(Vector3(0.95, 0.95, 0.8), Vector3(0, 0.47, 0)))
	add_child(crates_body1)

	var crates_body2 := StaticBody3D.new()
	crates_body2.collision_layer = Geo.LAYER_WORLD
	crates_body2.collision_mask = 0
	crates_body2.position = SHED + Vector3(6.8, 0.0, 2.0)
	crates_body2.rotation.y = deg_to_rad(180.0)
	crates_body2.add_child(Props.stacked_crates())
	crates_body2.add_child(Geo.box_shape(Vector3(0.95, 0.95, 0.8), Vector3(0, 0.47, 0)))
	add_child(crates_body2)



func _on_crate_used(p: Player, crate: Interactable) -> void:
	Game.give_item(&"tape_recorder")
	Game.day_goal_done = true
	Game.audio.play_3d(CLANK_SOUND, crate.global_position, -4.0)
	crate.queue_free()
	Game.hud.subtitle(Loc.t(&"sub.got_tape"), 6.0)
	# Под магнитофоном — тетрадь пеленгов Семёнова: первая линия на схеме (хребет «Отзвук», день 1)
	await get_tree().create_timer(6.5, false).timeout
	Game.hud.show_note(Loc.t(&"note.sem_bearings"))
	p.mode = Player.Mode.READING
	_bearing_after_note("zimnik")


func _on_oil_taken(p: Player) -> void:
	if Game.tasks == null or not Game.tasks.is_active(&"oil"):
		return
	if p.held != &"":
		Game.hud.subtitle(Loc.t(&"sub.hands_full"), 2.0)
		return
	p.set_held(&"oil")
	if _oil_can_it != null:
		_oil_can_it.visible = false
		_oil_can_it.collision_layer = 0
	Game.audio.play_3d(CLANK_SOUND, SHED + Vector3(-0.4, 0.4, 1.3), -6.0)
	_check_routine_scare_shed()


## Реквизит заданий (NightTasks): включить/убрать.
func set_task_prop(id: StringName, on: bool) -> void:
	match id:
		&"meteo_dig":
			_drift.visible = on
			_drift.collision_layer = Geo.LAYER_WORLD if on else 0
		&"mast_lamp":
			_mast_lamp_out = on
		&"mast_ground":
			_set_mast_ground_hazard(on)


func _set_mast_ground_hazard(on: bool) -> void:
	_mast_ground_active = on
	if _mast_ground_sparks != null:
		_mast_ground_sparks.emitting = on
	if _mast_ground_sound != null:
		if on:
			_mast_ground_sound.play()
		else:
			_mast_ground_sound.stop()


func set_shed_doors_open(open: bool) -> void:
	if open == shed_doors_open or _shed_doors_busy or _shed_door_left_hinge == null:
		return
	_shed_doors_busy = true
	shed_doors_open = open
	Game.audio.play_3d(DOOR_SOUND, _shed_door_left_hinge.global_position + Vector3(0, 1.2, 1.0), -4.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_shed_door_left_hinge, "rotation:y", deg_to_rad(-88.0) if open else 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_shed_door_right_hinge, "rotation:y", deg_to_rad(88.0) if open else 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_shed_doors_busy = false


func _on_shed_doors_used(p: Player) -> void:
	if not Game.is_prologue() and (Game.night >= 1 or (Game.synoptic != null and Game.synoptic.temp_dry <= -26.0)) and not Game.has_flag("shed_padlock_thawed"):
		_on_shed_padlock_used(p)
		return
	set_shed_doors_open(not shed_doors_open)


func _on_shed_padlock_used(p: Player) -> void:
	if Game.has_flag("shed_padlock_thawed"):
		return
	if p != null and p.held == &"kettle":
		if p.kettle_heat_timer > 0.0:
			Game.set_flag("shed_padlock_thawed", true)
			Game.audio.play_3d(CLANK_SOUND, _shed_padlock.global_position if _shed_padlock != null else global_position, 0.0)
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"sub.padlock_thawed_kettle"), 4.0)
			Director.add_tension(-5.0, "замок отогрет чайником")
			if _shed_padlock != null:
				var tw := create_tween()
				tw.tween_property(_shed_padlock, "position:y", _shed_padlock.position.y - 1.2, 0.4)
				await tw.finished
				_shed_padlock.visible = false
			if _shed_padlock_it != null:
				_shed_padlock_it.collision_layer = 0
		else:
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"sub.kettle_cold_now"), 3.0)
		return
	elif p != null and p.held == &"blowtorch":
		Game.set_flag("shed_padlock_thawed", true)
		Game.audio.play_3d("res://assets/audio/flare.ogg", _shed_padlock.global_position if _shed_padlock != null else global_position, 2.0)
		Game.audio.play_3d(CLANK_SOUND, _shed_padlock.global_position if _shed_padlock != null else global_position, 0.0)
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"sub.padlock_thawed_torch"), 4.0)
		Director.add_tension(-5.0, "замок отогрет паяльной лампой")
		if _shed_padlock != null:
			var tw := create_tween()
			tw.tween_property(_shed_padlock, "position:y", _shed_padlock.position.y - 1.2, 0.4)
			await tw.finished
			_shed_padlock.visible = false
		if _shed_padlock_it != null:
			_shed_padlock_it.collision_layer = 0
		return

	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.padlock_frozen"), 4.0)



func _on_shed_drift_dug(_p: Player) -> void:
	SaveGame.flags["shed_drift_cleared_n" + str(Game.night)] = true
	SaveGame.write()
	if _shed_drift != null:
		var tw := create_tween()
		tw.tween_property(_shed_drift, "scale:y", 0.05, 0.45)
		await tw.finished
		_shed_drift.visible = false
		_shed_drift.collision_layer = 0
	Game.audio.play_3d("res://assets/audio/snow_fall.ogg", SHED + Vector3(2.0 - 5.6, 0.5, 0), 0.0)
	Game.hud.subtitle(Loc.t(&"sub.shed_drift_cleared"), 3.5)
	Director.add_tension(-6.0, "сугроб у сарая расчищен")


func set_izba_door_open(open: bool) -> void:
	if open == izba_door_open or _izba_door_busy or _izba_door_hinge == null:
		return
	_izba_door_busy = true
	izba_door_open = open
	Game.audio.play_3d(DOOR_SOUND, _izba_door_hinge.global_position + Vector3(0, 1.0, 0), -5.0)
	var tw := create_tween()
	tw.tween_property(_izba_door_hinge, "rotation:y", deg_to_rad(105.0) if open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_izba_door_busy = false


func _on_izba_door_used(_p: Player) -> void:
	set_izba_door_open(not izba_door_open)


func _on_drift_dug(_p: Player) -> void:
	if Game.tasks != null:
		Game.tasks.complete(&"meteo_dig")
	set_task_prop(&"meteo_dig", false)
	Game.hud.subtitle(Loc.t(&"sub.drift_done"), 3.0)


func _interact_meteo_booth(booth_prop: MeteoBoothScreen, booth_pos: Vector3) -> void:
	if booth_prop == null or not is_instance_valid(booth_prop):
		EventBus.ui_requested.emit(&"thermometer")
		return

	if not booth_prop.is_open:
		if booth_prop.is_frozen:
			var held: StringName = Game.player.held if Game.player != null else &""
			if held == &"crowbar" or held == &"axe" or held == &"shovel":
				Game.audio.play_3d("res://assets/audio/ice_hit.ogg", booth_pos, 0.0, 8.0, 1.2)
				Game.hud.subtitle(Loc.t(&"sub.booth_hit"), 4.0)
				Director.add_tension(6.0, "стук по будке Селянинова")
				booth_prop.is_frozen = false
				Game.set_flag("booth_unfrozen", true)
			elif held == &"knife" or held == &"matches":
				Game.audio.play_3d("res://assets/sfx/door_handle.ogg", booth_pos, 0.0, 6.0, 1.4)
				Game.hud.subtitle(Loc.t(&"sub.booth_knife"), 4.0)
				booth_prop.is_frozen = false
				Game.set_flag("booth_unfrozen", true)
			else:
				Game.audio.play_3d("res://assets/sfx/breath_close.ogg", booth_pos, 0.0, 6.0, 1.0)
				Game.hud.subtitle(Loc.t(&"sub.booth_breathe"), 4.0)
				booth_prop.is_frozen = false
				Game.set_flag("booth_unfrozen", true)
				Game.set_flag("booth_breath_frost", true)

		booth_prop.open_doors(true)
		Game.audio.play_3d("res://assets/sfx/door_handle.ogg", booth_pos, -2.0)
		Game.audio.play_3d("res://assets/sfx/house_creak.ogg", booth_pos, -6.0)

		# ЖЁСТКИЙ СКРИМЕР #3: на Ночи 3+ один раз за смену внутри психрометрической будки +36.6°C и взгляд в упор!
		if Game.is_night() and Game.night >= 3 and not _booth_ambush_done and not Director.in_calm_window() and Director.tension >= 45.0:
			_booth_ambush_done = true
			_execute_meteo_booth_ambush(booth_pos)
			return

		if Game.synoptic != null and Game.synoptic.wind_speed > 11.0:
			get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
				if is_instance_valid(self):
					Game.audio.play_3d("res://assets/audio/door_knock.ogg", booth_pos, 0.0, 8.0, 1.2)
					Game.hud.subtitle(Loc.t(&"sub.booth_wind_gust"), 4.0))

		get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			EventBus.ui_requested.emit(&"thermometer"))
	else:
		EventBus.ui_requested.emit(&"thermometer")


func _execute_meteo_booth_ambush(booth_pos: Vector3) -> void:
	var p := Game.player
	if p == null:
		return
	if Game.anomalies != null:
		Game.anomalies.occur(&"therm_366")
	# Тёплое облако пара из открытой будки при -40°C
	if OS.get_name() != "headless":
		var fx := CPUParticles3D.new()
		fx.amount = 18
		fx.lifetime = 1.8
		fx.one_shot = true
		fx.explosiveness = 0.85
		fx.direction = (p.global_position - booth_pos).normalized()
		fx.spread = 32.0
		fx.initial_velocity_min = 0.8
		fx.initial_velocity_max = 1.9
		fx.scale_amount_min = 0.35
		fx.scale_amount_max = 0.95
		fx.color_ramp = Player.puff_ramp()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.55, 0.55)
		qm.material = Player.puff_material(0.42)
		fx.mesh = qm
		fx.position = booth_pos + Vector3(0, 1.45, 0)
		add_child(fx)
		fx.emitting = true
		Geo.free_after(fx, 2.4)
	# Лицо/глаза прямо в проёме будки в 12 FPS + выбивает фонарь «Жучок»!
	var rig: Node3D = Creatures.make_yrka()
	add_child(rig)
	var base_p := booth_pos + Vector3(0, 0.15, 0)
	rig.global_position = base_p
	rig.look_at(Vector3(p.global_position.x, base_p.y, p.global_position.z), Vector3.UP)
	if rig.has_method(&"set_eye_glow"):
		rig.call(&"set_eye_glow", 3.6)
	Game.audio.play_2d("res://assets/audio/growl.ogg", 3.0)
	Game.audio.play_2d("res://assets/audio/shriek.ogg", 2.0)
	if Game.hud != null and Game.hud.has_method(&"trigger_jumpscare_flash"):
		Game.hud.trigger_jumpscare_flash(0.92, 0.34)
	var dir_p := (p.global_position - base_p)
	dir_p.y = 0.0
	dir_p = dir_p.normalized() if dir_p.length_squared() > 0.01 else Vector3.FORWARD
	for i in range(4):
		if not is_instance_valid(rig):
			break
		rig.global_position = base_p + dir_p * (0.22 * float(i + 1))
		rig.rotation.z = deg_to_rad(15.0 if i % 2 == 0 else -15.0)
		await get_tree().create_timer(0.083, false).timeout
	if is_instance_valid(rig):
		rig.queue_free()
	# От ужаса и удара гаснет «Жучок» — заставляет в панике крутить динамо на метеоплощадке!
	if p.flashlight_on():
		p.toggle_flashlight()
	Game.flash_charge = maxf(Game.flash_charge - 14.0, 6.0)
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.booth_ambush"), 5.0, 2)
	Director.force_relax(55.0, 34.0, "засада +36.6 в психрометрической будке")


func _on_mast_panel(_p: Player) -> void:
	if not _mast_lamp_out:
		return
	_mast_lamp_out = false
	if Game.tasks != null:
		Game.tasks.complete(&"mast_lamp")
	Game.hud.subtitle(Loc.t(&"sub.mast_lamp_done"), 3.0)
	_check_routine_scare_mast()


func _on_canisters_used(p: Player) -> void:
	if Game.canisters_left <= 0:
		return
	if Troubles.blocks(&"canisters_gel"):
		Game.hud.subtitle(Loc.t(&"tr.block.canisters_gel"), 3.5)
		return
	if p.held != &"":
		Game.hud.subtitle(Loc.t(&"sub.hands_full"), 2.0)
		return
	Game.canisters_left -= 1
	p.set_held(&"canister")
	Game.audio.play_3d(CLANK_SOUND, SHED + Vector3(-0.4, 1.3, -1.6), 0.0)
	Game.hud.subtitle(Loc.t(&"sub.canister"), 3.0)
	_check_routine_scare_shed()


func _check_routine_scare_shed() -> void:
	if not Game.is_night() or Game.night < 2 or _shed_tracks_done:
		return
	if randf() < 0.5:
		_shed_tracks_done = true
		_fresh_tracks_active = true
		var pts: Array[Vector3] = [
			Vector3(38.0, 0.0, 36.0),
			Vector3(37.0, 0.0, 29.0),
			Vector3(32.0, 0.0, 22.0),
			Vector3(25.0, 0.0, 16.0),
			Vector3(20.0, 0.0, 12.0)
		]
		spawn_trail(pts)


func _check_routine_scare_mast() -> void:
	if not Game.is_night() or Game.night < 3 or _mast_watcher_done:
		return
	if randf() < 0.45:
		_mast_watcher_done = true
		_spawn_mast_watcher()


func _spawn_mast_watcher() -> void:
	var watcher_pos := Vector3(14.0, 0.0, -62.0)
	var rig := Creatures.make_silhouette()
	rig.look_at_from_position(watcher_pos, MAST, Vector3.UP)
	add_child(rig)
	Game.audio.play_3d("res://assets/audio/whisper.ogg", watcher_pos, -4.0)

	var elapsed := 0.0
	while elapsed < 2.5:
		await get_tree().create_timer(0.1, false).timeout
		elapsed += 0.1
		if not is_instance_valid(rig):
			return
		if Game.player != null and Game.player.is_looking_at(watcher_pos, 25.0) and Game.player.flashlight_on():
			break

	if is_instance_valid(rig):
		var tw := create_tween()
		tw.tween_property(rig, "scale", Vector3(0.01, 1.8, 0.01), 0.35)
		await tw.finished
		if is_instance_valid(rig):
			rig.queue_free()

	if Game.player != null and Game.player.global_position.distance_to(MAST) < 16.0:
		Game.hud.subtitle(Loc.t(&"sub.distant_watcher"), 4.0)
		Director.add_tension(15.0, "силуэт у мачты")
		Game.add_fatigue(4.0)


# --- Поленница и лесопильный навес -------------------------------------------

func _build_woodpile() -> void:
	var it := Geo.interactable(self, Vector3(2.4, 0.9, 1.2), WOODPILE + Vector3(0, 0.45, 0), null, "", _on_woodpile_used)
	it.hold_time = 1.4
	it.hold_sound = HIT_SOUND
	# Навес с поленницей — модель (tools/blender/yard_props.py): стойки из брёвен, кровля из досок со снегом,
	# колотые чурбаки со светлыми торцами, щепа. Коллизии — стойки и сама поленница.
	var shed_model := Props._kedr_model("woodshed", {"bright": 1.1})
	if shed_model != null:
		shed_model.position = WOODPILE
		add_child(shed_model)
	else:
		var pile := Props.woodpile(2.4, 0.85)
		add_child(pile)
		pile.position = WOODPILE
	var col := StaticBody3D.new()
	col.collision_layer = Geo.LAYER_WORLD
	col.position = WOODPILE
	add_child(col)
	col.add_child(Geo.box_shape(Vector3(2.7, 1.0, 0.65), Vector3(0, 0.5, -0.15)))
	for sx: float in [-1.5, 1.5]:
		for sz: float in [-0.75, 0.75]:
			col.add_child(Geo.box_shape(Vector3(0.16, 2.3, 0.16), Vector3(sx, 1.15, sz)))
	it.prompt_provider = func() -> String:
		if Game.player != null and Game.player.held != &"":
			return Loc.t(&"it.wood_full")
		return Loc.t(&"it.wood")

	# Колода для колки дров с расколотым чурбаком и застрявшим колуном
	var stump := Props.axe_stump()
	stump.position = WOODPILE + Vector3(-2.2, 0.0, 0.4)
	add_child(stump)
	var stump_it := Geo.interactable(self, Vector3(0.7, 1.0, 0.7), WOODPILE + Vector3(-2.2, 0.5, 0.4), null, Loc.t(&"it.axe_stump"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.axe_stump"), 4.0)
	)
	stump_it.name = "AxeStump"

	# Дощатые козлы для распиловки брёвен с двуручной пилой «Дружба-2»
	var saw := Props.sawhorse()
	saw.position = WOODPILE + Vector3(2.4, 0.0, 0.3)
	saw.rotation.y = deg_to_rad(-15.0)
	add_child(saw)
	var saw_it := Geo.interactable(self, Vector3(1.8, 1.1, 0.9), WOODPILE + Vector3(2.4, 0.6, 0.3), null, Loc.t(&"it.sawhorse"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.sawhorse"), 4.5)
	)
	saw_it.name = "Sawhorse"

	# Хлысты, ждущие пилы, у козел
	var log_mat := Palette.m(&"log")
	Geo.cylinder(self, 0.14, 3.0, WOODPILE + Vector3(-1.2, 0.14, 2.3), log_mat, true).rotation.y = deg_to_rad(30.0)
	Geo.cylinder(self, 0.13, 2.5, WOODPILE + Vector3(1.0, 0.13, 2.6), log_mat, true).rotation.y = deg_to_rad(-22.0)


func _on_woodpile_used(p: Player) -> void:
	if p.held != &"":
		return
	if Troubles.blocks(&"woodpile_buried"):
		Game.hud.subtitle(Loc.t(&"tr.block.woodpile_buried"), 3.5)
		return
	p.set_held(&"wood")
	Game.audio.play_3d(WOOD_SOUND, WOODPILE + Vector3(0, 0.5, 0), -2.0)


## Бурелом и поваленные стволы на кромке тайги (не захламляют рабочий двор станции)
func _build_deadfall() -> void:
	var bark := Palette.m(&"bark")
	var snow := Palette.m(&"snow")
	var deadfalls := [
		{"pos": Vector3(-14.0, 0.3, -16.0), "len": 6.5, "r": 0.22, "rot": deg_to_rad(25.0)},
		{"pos": Vector3(14.0, 0.3, -42.0), "len": 7.0, "r": 0.24, "rot": deg_to_rad(-40.0)},
		{"pos": Vector3(56.0, 0.3, 26.0), "len": 7.5, "r": 0.25, "rot": deg_to_rad(50.0)},
	]
	for df in deadfalls:
		var trunk := Geo.cylinder(self, df["r"], df["len"], df["pos"], bark, true)
		trunk.rotation.x = PI / 2.0
		trunk.rotation.z = df["rot"]
		var sc := Geo.block(self, Vector3(df["len"] * 0.9, 0.12, df["r"] * 1.8), df["pos"] + Vector3(0, df["r"] + 0.05, 0), snow)
		sc.rotation.y = -df["rot"]


## Обманчивые силуэты в чаще (парейдолия — пни, похожие на людей в тумане на опушке)
func _build_silhouette_stumps() -> void:
	var spots: Array[Vector3] = [
		Vector3(12.0, 0.0, 42.0),
		Vector3(52.0, 0.0, 6.0),
		Vector3(44.0, 0.0, -38.0),
		Vector3(8.0, 0.0, -44.0),
		Vector3(-14.0, 0.0, 20.0),
		Vector3(-8.0, 0.0, -22.0),
	]
	for sp in spots:
		var st := Props.silhouette_stump()
		st.position = sp
		st.rotation.y = Game.rng.randf() * TAU
		add_child(st)
		var it := Geo.interactable(self, Vector3(0.8, 1.8, 0.8), sp + Vector3(0, 0.9, 0), null, Loc.t(&"it.silhouette_stump"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.silhouette_stump"), 4.0)
		)
		it.name = "SilhouetteStump"


# --- Изба --------------------------------------------------------------------

## Заброшенная изба в лесу. Стоит всегда (поляна), но леер и табличка — только со дня 2.
func _build_izba() -> void:
	var logm := Palette.m(&"log")
	var plankm := Palette.m(&"plank")
	var darkm := Palette.m(&"dark")
	var woodm := Palette.m(&"wood")
	# Новый облик (tools/blender/izba.py): сруб, кровля, сени — модель; коробки ниже — коллизия
	var model := Models.spawn(self, "kedr/izba", Vector3(0, IZBA_MODEL_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0}) != null

	# === 1. Тёмный прируб-сени (вход, капканы, ветки, дрова) ===
	var seni_center := IZBA + Vector3(3.8, 0.0, 0.0)
	var seni_w := 3.2
	var seni_d := 3.4
	var seni_h := 2.4

	# Фундамент и пол сеней
	_blk(model, Vector3(seni_w + 0.3, 0.6, seni_d + 0.3), seni_center + Vector3(0, -0.3, 0), darkm, true)
	_blk(model, Vector3(seni_w, 0.12, seni_d), seni_center + Vector3(0, -0.06, 0), woodm, true)
	# Бревенчатые стены прируба
	_blk(model, Vector3(seni_w, seni_h, 0.18), seni_center + Vector3(0, seni_h / 2.0, -seni_d / 2.0), logm, true) # север
	_blk(model, Vector3(seni_w, seni_h, 0.18), seni_center + Vector3(0, seni_h / 2.0, seni_d / 2.0), logm, true)  # юг
	# Восточная стена с входом (высота проёма 2.15 м для свободного прохода игрока)
	_blk(model, Vector3(0.18, seni_h, 1.1), seni_center + Vector3(seni_w / 2.0, seni_h / 2.0, -1.15), logm, true)
	_blk(model, Vector3(0.18, 0.25, 1.2), seni_center + Vector3(seni_w / 2.0, 2.275, 0.0), logm, true) # притолока над входом
	_blk(model, Vector3(0.18, seni_h, 1.1), seni_center + Vector3(seni_w / 2.0, seni_h / 2.0, 1.15), logm, true)

	# Дощатая дверь избы на кованых жиковинах
	_izba_door_hinge = Node3D.new()
	_izba_door_hinge.position = seni_center + Vector3(seni_w / 2.0, 0.0, -0.58)
	add_child(_izba_door_hinge)

	var izba_door := Interactable.new()
	izba_door.collision_layer = Geo.LAYER_WORLD
	izba_door.position = Vector3(0.0, 1.05, 0.58)
	izba_door.prompt_provider = func() -> String: return Loc.t(&"it.izba_door_close") if izba_door_open else Loc.t(&"it.izba_door_open")
	izba_door.add_child(Geo.box_mesh(Vector3(0.08, 2.1, 1.16), Palette.m(&"plank")))
	izba_door.add_child(Geo.box_shape(Vector3(0.08, 2.1, 1.16)))
	var i_handle := Geo.box_mesh(Vector3(0.06, 0.16, 0.06), Palette.m(&"dark"))
	i_handle.position = Vector3(0.0, 0.0, 0.44)
	izba_door.add_child(i_handle)
	izba_door.used.connect(_on_izba_door_used)
	_izba_door_hinge.add_child(izba_door)
	# Односкатная крыша прируба (старый вид — без модели)
	if not model:
		var seni_roof := Geo.box_mesh(Vector3(seni_w + 0.5, 0.12, seni_d + 0.4), plankm)
		seni_roof.position = seni_center + Vector3(-0.05, seni_h + 0.12, 0)
		seni_roof.rotation.z = deg_to_rad(6.5)
		add_child(seni_roof)
		var seni_snow := Geo.box_mesh(Vector3(seni_w + 0.45, 0.1, seni_d + 0.35), Palette.m(&"snow"))
		seni_snow.position = seni_center + Vector3(-0.05, seni_h + 0.20, 0)
		seni_snow.rotation.z = deg_to_rad(6.5)
		add_child(seni_snow)

	# Завал сухими ветками и хвоей на полу сеней
	for k in range(5):
		var branch := Geo.cylinder(self, 0.02, 0.9, seni_center + Vector3(0.4 - k * 0.2, 0.03, -0.6 + k * 0.3), darkm, false)
		branch.rotation = Vector3(0.05 * k, 0.6 * k, 1.4)
	# Поленница колотых дров в углу сеней
	var seni_wood := Props.firewood_bundle(false)
	seni_wood.position = seni_center + Vector3(-0.8, 0.0, 1.1)
	seni_wood.rotation.y = deg_to_rad(40.0)
	add_child(seni_wood)
	# Старые ржавые капканы на стенах сеней
	var trap1 := Props.bear_trap()
	trap1.position = seni_center + Vector3(0.2, 1.35, -seni_d / 2.0 + 0.1)
	trap1.rotation.x = deg_to_rad(90.0)
	add_child(trap1)
	var trap2 := Props.bear_trap()
	trap2.position = seni_center + Vector3(0.2, 1.35, seni_d / 2.0 - 0.1)
	trap2.rotation.x = deg_to_rad(-90.0)
	add_child(trap2)

	# === 2. Основная изба (русская печь, стол из плах, красный угол) ===
	var cabin_center := IZBA + Vector3(-0.65, 0.0, 0.0)
	var cabin_w := 6.3
	var cabin_d := 6.0
	var cabin_h := 2.8

	# Фундамент и дощатый пол
	_blk(model, Vector3(cabin_w + 0.4, 0.6, cabin_d + 0.4), cabin_center + Vector3(0, -0.3, 0), darkm, true)
	_blk(model, Vector3(cabin_w, 0.15, cabin_d), cabin_center + Vector3(0, -0.07, 0), woodm, true)

	# Наружные стены основного сруба
	# Северная глухая стена:
	_blk(model, Vector3(cabin_w, cabin_h, 0.2), cabin_center + Vector3(0, cabin_h / 2.0, -cabin_d / 2.0), logm, true)
	# Южная стена с заколоченным окном:
	_blk(model, Vector3(2.4, cabin_h, 0.2), cabin_center + Vector3(-1.95, cabin_h / 2.0, cabin_d / 2.0), logm, true)
	_blk(model, Vector3(1.1, 1.0, 0.2), cabin_center + Vector3(0.0, 0.5, cabin_d / 2.0), logm, true) # под окном
	_blk(model, Vector3(1.1, 0.8, 0.2), cabin_center + Vector3(0.0, 2.4, cabin_d / 2.0), logm, true) # над окном
	_blk(model, Vector3(2.8, cabin_h, 0.2), cabin_center + Vector3(1.75, cabin_h / 2.0, cabin_d / 2.0), logm, true)
	# Западная наружная стена:
	_blk(model, Vector3(0.2, cabin_h, cabin_d), cabin_center + Vector3(-cabin_w / 2.0, cabin_h / 2.0, 0), logm, true)
	# Восточная стена между избой и сенями:
	_blk(model, Vector3(0.2, cabin_h, 1.4), cabin_center + Vector3(cabin_w / 2.0, cabin_h / 2.0, -2.3), logm, true)
	_blk(model, Vector3(0.2, cabin_h, 1.4), cabin_center + Vector3(cabin_w / 2.0, cabin_h / 2.0, 2.3), logm, true)
	_blk(model, Vector3(0.2, 0.8, 1.2), cabin_center + Vector3(cabin_w / 2.0, 2.4, 0.0), logm, true) # над проемом

	# Перегородка, отгораживающая задний чулан/погреб за печью (x: от печи до западной стены):
	Geo.block(self, Vector3(2.4, cabin_h, 0.15), cabin_center + Vector3(-1.95, cabin_h / 2.0, -0.6), woodm, true)

	if not model:
		# Угловые перерубы брёвен (направлены строго наружу здания, без проникновения внутрь)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var cl := Props.corner_logs(cabin_h + 0.2, 0.09, sx, sz)
				cl.position = cabin_center + Vector3(sx * (cabin_w / 2.0 + 0.05), 0.0, sz * (cabin_d / 2.0 + 0.05))
				add_child(cl)

		# Фронтоны под коньком крыши избы с запада и востока (треугольные призмы под двускатной кровлей 28°)
		for sx: float in [-1.0, 1.0]:
			var g_pm := PrismMesh.new()
			g_pm.size = Vector3(cabin_d, 1.55, 0.15)
			var gable := MeshInstance3D.new()
			gable.mesh = g_pm
			gable.material_override = logm
			gable.position = cabin_center + Vector3(sx * (cabin_w / 2.0), cabin_h + 1.55 / 2.0, 0)
			gable.rotation.y = deg_to_rad(90.0)
			add_child(gable)

		# Двускатная крыша избы с плахами и толстым снегом
		for side in [-1.0, 1.0]:
			var slab := Geo.box_mesh(Vector3(cabin_w + 0.6, 0.15, cabin_d * 0.58), plankm)
			slab.position = cabin_center + Vector3(0, cabin_h + 0.85, side * (cabin_d * 0.26))
			slab.rotation.x = deg_to_rad(28.0 * side)
			add_child(slab)
			var snow_slab := Geo.box_mesh(Vector3(cabin_w + 0.55, 0.12, cabin_d * 0.56), Palette.m(&"snow"))
			snow_slab.position = cabin_center + Vector3(0, cabin_h + 0.95, side * (cabin_d * 0.26))
			snow_slab.rotation.x = deg_to_rad(28.0 * side)
			add_child(snow_slab)

		var izba_ice := Props.icicles(cabin_w, 16)
		izba_ice.position = cabin_center + Vector3(0, cabin_h + 0.2, cabin_d / 2.0 + 0.08)
		add_child(izba_ice)

	# Заколоченное южное окно
	var boarded := Props.boarded_window(Vector2(0.9, 1.0))
	boarded.position = cabin_center + Vector3(0.0, 1.5, cabin_d / 2.0 + 0.08)
	add_child(boarded)

	# Массивная русская печь с закопчённым устьем
	var stove_body := StaticBody3D.new()
	stove_body.collision_layer = Geo.LAYER_WORLD
	stove_body.position = cabin_center + Vector3(-0.8, 0.0, -1.6)
	# Изба внутри — модель (yard_props.py izba_interior): печь устьем к входу, нары, полка, шкурки, утварь
	var interior := Models.spawn(self, "kedr/izba_interior", cabin_center, 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.15, "sat": 1.0})
	if interior == null:
		stove_body.add_child(Props.russian_stove())
	else:
		var nary := StaticBody3D.new()
		nary.collision_layer = Geo.LAYER_WORLD
		nary.position = cabin_center + Vector3(1.6, 0.28, -2.5)
		nary.add_child(Geo.box_shape(Vector3(2.4, 0.56, 0.85)))
		add_child(nary)
	stove_body.add_child(Geo.box_shape(Vector3(1.3, 1.4, 1.4), Vector3(0, 0.7, 0)))
	add_child(stove_body)

	# Стол из плах и широкая лавка
	var table_col := Geo.box_shape(Vector3(1.5, 0.75, 0.85))
	var table_body := StaticBody3D.new()
	table_body.collision_layer = Geo.LAYER_WORLD
	table_body.position = cabin_center + Vector3(1.2, 0.0, 1.1)
	table_body.add_child(Props.izba_table())
	table_body.add_child(table_col)
	table_col.position.y = 0.375
	add_child(table_body)

	var bench := Props.izba_bench()
	bench.position = cabin_center + Vector3(1.2, 0.0, 0.45)
	add_child(bench)

	# Красный угол: божница со складнем, перекошенной божницей и потемневшим рушником
	var icon := Props.icon_corner()
	icon.position = cabin_center + Vector3(-2.9, 1.85, 2.7)
	icon.rotation.y = deg_to_rad(45.0)
	icon.rotation.z = deg_to_rad(12.0) # зловеще перекошена
	add_child(icon)

	# === 3. Тёмный чулан / провал в погреб (задний закуток за печью) ===
	var nook_center := cabin_center + Vector3(-1.95, 0.0, -1.8)

	# Зияющий провал в подпол (выломанные доски, черная глубина)
	var cellar := Props.cellar_hole()
	cellar.position = nook_center + Vector3(0.3, 0.0, 0.2)
	add_child(cellar)
	var cellar_it := Geo.interactable(self, Vector3(1.2, 0.6, 1.2), nook_center + Vector3(0.3, 0.3, 0.2), null, Loc.t(&"it.cellar_hole"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.cellar_hole"), 4.5)
	)
	cellar_it.name = "CellarHole"

	# Грубая лавка у стены в темноте чулана
	var nook_bench := Props.izba_bench()
	nook_bench.position = nook_center + Vector3(-0.6, 0.0, -0.7)
	add_child(nook_bench)

	# Замёрзший хозяин избы: сидит на лавке в тёмном чулане у чёрной ямы подпола
	var corpse := Creatures.make_corpse()
	add_child(corpse)
	corpse.position = nook_center + Vector3(-0.6, 0.0, -0.6)
	corpse.rotation.y = PI

	# Записка и шифросемафорная книга на столе
	var note := Geo.interactable(self, Vector3(0.3, 0.02, 0.22), cabin_center + Vector3(1.4, 0.77, 1.0), Palette.m(&"paper"), Loc.t(&"it.izba_note"), _on_izba_note)
	note.name = "IzbaNote"

	if izba_open and not Game.has_item(&"codebook"):
		var book := Geo.interactable(self, Vector3(0.22, 0.05, 0.3), cabin_center + Vector3(0.9, 0.78, 1.2), Palette.m(&"red"), Loc.t(&"it.codebook"), Callable())
		book.used.connect(_on_codebook_taken.bind(book))



func _on_izba_note(p: Player) -> void:
	Game.hud.show_note(Loc.t(&"note.izba"))
	p.mode = Player.Mode.READING


func _on_codebook_taken(_p: Player, book: Interactable) -> void:
	Game.give_item(&"codebook")
	Game.day_goal_done = true
	book.queue_free()
	Game.hud.subtitle(Loc.t(&"sub.got_codebook"), 6.0)


# --- Ретранслятор на сопке (день 3) -------------------------------------------

## Решётчатая вышка на каменистой проплешине. Тарелка на верхушке смотрит не в небо — вниз.
func _build_repeater() -> void:
	var metal := Palette.m(&"metal")
	var base := REPEATER
	Geo.block(self, Vector3(4.0, 0.8, 4.0), base + Vector3(0, -0.1, 0), Palette.m(&"concrete"))
	var h := 13.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var bottom := base + Vector3(sx * 1.3, 0.3, sz * 1.3)
			var top := base + Vector3(sx * 0.35, h, sz * 0.35)
			var leg := Geo.box_mesh(Vector3(0.09, 0.09, bottom.distance_to(top)), metal)
			add_child(leg)
			leg.position = (bottom + top) / 2.0
			leg.look_at(top, Vector3.FORWARD if absf((top - bottom).normalized().y) > 0.99 else Vector3.UP)
	for k in range(1, 7):
		var y := k * 1.9
		var w := lerpf(2.6, 0.7, y / h)
		for i in range(4):
			var a := Vector3(w * 0.5, y, w * 0.5).rotated(Vector3.UP, i * PI * 0.5)
			var b := Vector3(w * 0.5, y, w * 0.5).rotated(Vector3.UP, (i + 1) * PI * 0.5)
			var bar := Geo.box_mesh(Vector3(0.05, 0.05, a.distance_to(b)), metal)
			add_child(bar)
			bar.position = base + (a + b) / 2.0
			bar.look_at(base + b, Vector3.UP)
	# Тарелка вниз: диск, наклонённый к земле.
	var dish := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1
	cm.bottom_radius = 0.3
	cm.height = 0.4
	cm.radial_segments = 10
	dish.mesh = cm
	dish.material_override = Palette.m(&"white")
	add_child(dish)
	dish.position = base + Vector3(0.9, h - 1.0, 0)
	dish.rotation_degrees = Vector3(0, 0, 150)
	_repeater_light = Geo.omni(self, base + Vector3(0, h + 0.4, 0), 6.0, 1.0, Color(1.0, 0.1, 0.05))
	Geo.bulb(_repeater_light, &"red", 0.12)
	# Камни сопки.
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in range(14):
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.5, 7.5)
		var sz := Vector3(rng.randf_range(0.6, 1.8), rng.randf_range(0.3, 1.1), rng.randf_range(0.6, 1.6))
		var rock := Props.boulder(i)
		rock.position = base + Vector3(cos(a) * r, sz.y * 0.3, sin(a) * r)
		rock.scale = sz
		rock.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		add_child(rock)
		if r > 5.0:
			Geo.collider(self, sz * 0.8, rock.position)
	var cab := Geo.interactable(self, Vector3(0.9, 1.6, 0.6), base + Vector3(-1.2, 1.1, 1.75), Palette.m(&"canister"), "", _on_cabinet_used)
	cab.prompt_provider = func() -> String:
		return Loc.t(&"it.cabinet") if not Game.has_item(&"flare_gun") else Loc.t(&"it.cabinet_empty")


func _on_cabinet_used(p: Player) -> void:
	if Game.has_item(&"flare_gun"):
		return
	Game.give_item(&"flare_gun")
	if Game.is_day():
		Game.day_goal_done = true
	Game.audio.play_3d(CLANK_SOUND, REPEATER + Vector3(-1.2, 1.2, 1.7), -2.0)
	Game.hud.show_note(Loc.t(&"note.repeater"))
	p.mode = Player.Mode.READING
	_bearing_after_note("repeater")
	Game.hud.subtitle(Loc.t(&"sub.got_flare"), 7.0)


# --- Озеро и прорубь (день 4), лодочный навес с лыжами (день 6) ---------------

func _build_lake() -> void:
	var ice := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = LAKE_R
	cm.bottom_radius = LAKE_R
	cm.height = 0.04
	cm.radial_segments = 24
	cm.rings = 1
	ice.mesh = cm
	ice.material_override = Palette.m(&"lake")
	ice.position = LAKE + Vector3(0, 0.02, 0)
	add_child(ice)

	# Торосы и ледяные нагромождения вдоль берега озера
	var hummock_angles := [0.4, 1.2, 2.1, 3.4, 4.3, 5.2]
	for ha: float in hummock_angles:
		var h_pos := LAKE + Vector3(cos(ha) * (LAKE_R - 1.2), 0.0, sin(ha) * (LAKE_R - 1.2))
		for k in range(3):
			var shard := Props.ice_slab(k)
			shard.scale = Vector3(1.2 + k * 0.3, 0.35 + k * 0.15, 0.6)
			shard.position = h_pos + Vector3((k - 1) * 0.4, 0.15 + k * 0.1, (k - 1) * 0.3)
			add_child(shard)
			shard.rotation = Vector3(0.35 - k * 0.2, ha + k * 0.5, 0.25)

	# Прорубь: чёрная вода, вокруг — вывороченные льдины, верёвка уходит в воду
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.75
	hm.bottom_radius = 0.75
	hm.height = 0.02
	hm.radial_segments = 24
	hole.mesh = hm
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.03, 0.06, 0.07)
	water.roughness = 0.04
	water.metallic_specular = 1.0   # фонарь бликует на чёрной воде
	hole.material_override = water
	hole.position = HOLE + Vector3(0, 0.045, 0)
	add_child(hole)
	# Шуга у кромки: серое кольцо мокрого льда
	var slush := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.95
	tm.rings = 20
	tm.ring_segments = 6
	slush.mesh = tm
	var slush_m := StandardMaterial3D.new()
	slush_m.albedo_color = Color(0.5, 0.58, 0.64)
	slush_m.roughness = 0.2
	slush.material_override = slush_m
	slush.position = HOLE + Vector3(0, 0.05, 0)
	slush.scale = Vector3(1.0, 0.25, 1.0)
	add_child(slush)
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 34
	for i in range(9):
		var a := i * TAU / 9.0 + lrng.randf_range(-0.2, 0.2)
		var r := lrng.randf_range(1.0, 1.5)
		var chunk := Props.ice_slab(i)
		chunk.scale = Vector3(lrng.randf_range(0.3, 0.7), lrng.randf_range(0.06, 0.16), lrng.randf_range(0.2, 0.45))
		chunk.position = HOLE + Vector3(cos(a) * r, 0.06, sin(a) * r)
		add_child(chunk)
		chunk.rotation = Vector3(lrng.randf_range(-0.35, 0.35), a + lrng.randf_range(-0.5, 0.5), lrng.randf_range(-0.3, 0.3))
	# Старые лунки — затянуло льдом; ледобур воткнут в снег; рыбацкий ящик-сиденье
	for e: Array in [[Vector3(2.6, 0.03, -1.4), 0.12], [Vector3(-2.2, 0.03, -2.0), 0.1]]:
		var old := MeshInstance3D.new()
		var om := CylinderMesh.new()
		om.top_radius = e[1]
		om.bottom_radius = e[1]
		om.height = 0.02
		om.radial_segments = 14
		old.mesh = om
		old.material_override = slush_m
		old.position = HOLE + e[0]
		add_child(old)
	var drill := Node3D.new()
	drill.position = HOLE + Vector3(2.4, 0.0, -1.1)
	drill.rotation = Vector3(0.15, 0.6, -0.12)
	add_child(drill)
	Geo.block(drill, Vector3(0.035, 1.25, 0.035), Vector3(0, 0.5, 0), Palette.m(&"metal"), false)
	Geo.block(drill, Vector3(0.5, 0.03, 0.03), Vector3(0, 1.1, 0), Palette.m(&"metal"), false)
	Geo.block(drill, Vector3(0.03, 0.03, 0.18), Vector3(0.24, 1.1, 0.08), Palette.m(&"wood"), false)
	var box_seat := Props.fishing_box()
	box_seat.position = HOLE + Vector3(-1.1, 0.0, -1.0)
	box_seat.rotation.y = 0.5
	add_child(box_seat)
	Geo.collider(self, Vector3(0.42, 0.32, 0.28), HOLE + Vector3(-1.1, 0.16, -1.0))
	# Вешка-жерлица у проруби со смоленой бечевкой, уходящей в воду
	var ice_rig := Props.ice_hole_rig()
	ice_rig.position = HOLE + Vector3(1.3, 0.0, 0.2)
	add_child(ice_rig)

	# Замёрзшая меховая шапка-ушанка Семёнова в снегу
	var ushanka_prop := Props.ushanka()
	ushanka_prop.position = HOLE + Vector3(-1.6, 0.02, 0.9)
	ushanka_prop.rotation.y = deg_to_rad(40.0)
	add_child(ushanka_prop)

	var it := Geo.interactable(self, Vector3(1.4, 0.4, 1.4), HOLE + Vector3(0, 0.2, 0), null, "", _on_hole_used)
	it.hold_time = 3.0
	it.hold_check = func() -> bool: return not Game.has_item(&"bunker_key") and Game.progress() >= 8
	it.prompt_provider = func() -> String:
		if Game.has_item(&"bunker_key") or Game.progress() < 8:
			return Loc.t(&"it.hole")
		return Loc.t(&"it.hole_pull")

	# --- Лодочный сарай на сваях над ледяной гладью ---
	var shack_center := LAKE_SHACK
	var deck_w := 9.0
	var deck_d := 6.5
	var deck_h := 0.45
	# Новый облик (tools/blender/lake_shack.py): сваи, помост, стены, кровля — модель; ниже — коллизия
	var model := Models.spawn(self, "kedr/lake_shack", Vector3(0, LAKE_SHACK_MODEL_Y, 0), 0.0, -1.0, {"center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0}) != null

	if not model:
		# Массивные деревянные сваи, уходящие сквозь лёд вглубь до -1.2м
		for sx in [-4.0, -2.0, 0.0, 2.0, 4.0]:
			for sz in [-2.8, 0.0, 2.8]:
				var pile := Geo.cylinder(self, 0.08, 1.7, shack_center + Vector3(sx, -0.35, sz), Palette.m(&"dark"), true)
				# Ледяные наросты на сваях у кромки льда
				Geo.cylinder(self, 0.13, 0.25, shack_center + Vector3(sx, 0.1, sz), Palette.m(&"ice"), false)

	# Дощатый помост-мостки прямо над ледяной гладью
	_blk(model, Vector3(deck_w, 0.15, deck_d), shack_center + Vector3(0, deck_h - 0.075, 0), Palette.m(&"plank"), true)

	# Сходни / мостки к проруби над озером
	var ramp := Props.pier_walkway(4.8)
	ramp.position = shack_center + Vector3(0, deck_h - 0.12, 5.0)
	add_child(ramp)
	var ramp_col := StaticBody3D.new()
	ramp_col.collision_layer = Geo.LAYER_WORLD
	ramp_col.position = shack_center + Vector3(0, deck_h - 0.12, 5.0)
	ramp_col.add_child(Geo.box_shape(Vector3(1.6, 0.15, 4.8), Vector3(0, 0.08, 0)))
	add_child(ramp_col)

	# Каркасный лодочный сарай на помосте (размер 7.5x5.2, высота 3.2)
	var b_h := 2.8
	var s_h := 2.4
	if model:
		for part: Array in [[Vector3(7.5, b_h, 0.15), Vector3(0, deck_h + b_h / 2.0, -2.5)], [Vector3(0.15, b_h, 5.15), Vector3(-3.7, deck_h + b_h / 2.0, 0)],
				[Vector3(0.15, b_h, 5.15), Vector3(3.7, deck_h + b_h / 2.0, 0)], [Vector3(2.2, s_h, 0.15), Vector3(-2.6, deck_h + s_h / 2.0, 2.5)],
				[Vector3(2.2, s_h, 0.15), Vector3(2.6, deck_h + s_h / 2.0, 2.5)], [Vector3(7.5, b_h - s_h, 0.15), Vector3(0, deck_h + (s_h + b_h) / 2.0, 2.5)]]:
			_blk(true, part[0], shack_center + (part[1] as Vector3), null, true)
	else:
		var shell := CSGCombiner3D.new()
		shell.use_collision = true
		shell.collision_layer = Geo.LAYER_WORLD
		add_child(shell)

		_csg(shell, Vector3(7.5, b_h, 0.15), shack_center + Vector3(0, deck_h + b_h / 2.0, -2.5), Palette.m(&"weathered")) # север
		_csg(shell, Vector3(0.15, b_h, 5.15), shack_center + Vector3(-3.7, deck_h + b_h / 2.0, 0), Palette.m(&"weathered")) # запад
		_csg(shell, Vector3(0.15, b_h, 5.15), shack_center + Vector3(3.7, deck_h + b_h / 2.0, 0), Palette.m(&"weathered"))  # восток
		# Южная сторона полуоткрытая: проём для лодок к мосткам
		_csg(shell, Vector3(2.2, s_h, 0.15), shack_center + Vector3(-2.6, deck_h + s_h / 2.0, 2.5), Palette.m(&"weathered"))
		_csg(shell, Vector3(2.2, s_h, 0.15), shack_center + Vector3(2.6, deck_h + s_h / 2.0, 2.5), Palette.m(&"weathered"))
		_csg(shell, Vector3(7.5, b_h - s_h, 0.15), shack_center + Vector3(0, deck_h + (s_h + b_h) / 2.0, 2.5), Palette.m(&"weathered"))

	if not model:
		# Двускатная крыша: скаты лежат на стенах, фронтоны закрыты досками, конёк вдоль сарая
		var rise := 1.0
		var half := 2.58
		var over := 0.4
		var ang := atan2(rise, half)
		var slope_len := sqrt(half * half + rise * rise) + over
		var top_y := deck_h + b_h + rise
		for side: float in [-1.0, 1.0]:
			var dir := Vector3(0.0, -sin(ang), side * cos(ang))
			var nrm := Vector3(0.0, cos(ang), side * sin(ang))
			var mid := shack_center + Vector3(0.0, top_y, 0.0) + dir * (slope_len / 2.0)
			var panel := Geo.box_mesh(Vector3(8.2, 0.12, slope_len), Palette.m(&"wood"))
			panel.position = mid + nrm * 0.07
			panel.rotation.x = side * ang
			add_child(panel)
			var snow := Geo.box_mesh(Vector3(8.0, 0.1, slope_len - 0.1), Palette.m(&"snow"))
			snow.position = mid + nrm * 0.17
			snow.rotation.x = side * ang
			add_child(snow)
		# Конёк — тёсаный брус
		Geo.block(self, Vector3(8.3, 0.12, 0.16), shack_center + Vector3(0, top_y + 0.17, 0), Palette.m(&"wood"), false)
		for gx: float in [-3.7, 3.7]:
			add_child(_gable_mesh(shack_center + Vector3(gx, deck_h + b_h, 0.0), half, rise, Palette.m(&"weathered")))
		# Затяжки-балки под стропилами (на них подвешен дощаник)
		for bx: float in [-1.4, 1.6]:
			Geo.block(self, Vector3(0.14, 0.14, 5.0), shack_center + Vector3(bx, deck_h + b_h - 0.07, 0), Palette.m(&"wood"), false)
		Geo.block(self, Vector3(0.12, rise - 0.05, 0.12), shack_center + Vector3(0.1, deck_h + b_h + rise / 2.0, 0), Palette.m(&"wood"), false)

		var shack_ice := Props.icicles(8.0, 18)
		shack_ice.position = shack_center + Vector3(0, deck_h + b_h - over * sin(ang) + 0.02, half + over * cos(ang) - 0.05)
		add_child(shack_ice)

	# Нависающие парусиновые брезенты в проёме (модель из Блендера, иначе — плоские куски)
	for k in range(2):
		var tarp := Props._kedr_model("lake_tarp", {"bright": 1.1})
		if tarp != null:
			tarp.position = shack_center + Vector3(-0.8 + k * 1.6, deck_h + 0.78, 2.4)
			tarp.rotation = Vector3(deg_to_rad(4.0 - k * 3.0), deg_to_rad(-5.0 + k * 10.0), 0.0)
			add_child(tarp)
		else:
			var tarp_b := Geo.box_mesh(Vector3(1.3, 2.0, 0.03), Palette.m(&"cloth"))
			tarp_b.position = shack_center + Vector3(-0.8 + k * 1.6, deck_h + 1.8, 2.45)
			tarp_b.rotation.x = deg_to_rad(8.0 - k * 4.0)
			add_child(tarp_b)

	# Дощаник вверх дном под стропилами, на верёвочных подвесах
	var boat := Props._kedr_model("lake_boat", {"bright": 1.2})
	if boat != null:
		boat.position = shack_center + Vector3(0.2, deck_h + 2.6, -0.1)
		boat.rotation = Vector3(0.0, PI / 2.0, PI)
		add_child(boat)
	else:
		for rib_idx in range(6):
			var rib := Geo.box_mesh(Vector3(0.08, 0.6, 1.4), Palette.m(&"dark"))
			rib.position = shack_center + Vector3(-2.0 + rib_idx * 0.8, deck_h + 2.4, 0.0)
			add_child(rib)
	for hx: float in [-1.4, 1.6]:
		for hz: float in [-0.5, 0.3]:
			Geo.cylinder(self, 0.015, 0.22, shack_center + Vector3(hx, deck_h + 2.66, hz), Palette.m(&"rope"), false)

	# Сушилки для сетей на помосте
	var nets := Props.frozen_nets()
	nets.position = shack_center + Vector3(2.5, deck_h, -1.2)
	add_child(nets)
	var nets2 := Props.frozen_nets()
	nets2.position = shack_center + Vector3(2.5, deck_h, 1.2)
	add_child(nets2)
	var nets_it := Geo.interactable(self, Vector3(2.6, 1.6, 1.5), shack_center + Vector3(2.5, deck_h + 0.8, 0.0), null, Loc.t(&"it.frozen_nets"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.frozen_nets"), 4.0)
	)
	nets_it.name = "FrozenNets"

	# Рыбацкий верстак с ледобуром, тисками и инструментами
	var wb_body := StaticBody3D.new()
	wb_body.collision_layer = Geo.LAYER_WORLD
	wb_body.position = shack_center + Vector3(-2.2, deck_h, -1.4)
	wb_body.add_child(Props.lake_workbench())
	wb_body.add_child(Geo.box_shape(Vector3(1.6, 0.75, 0.65), Vector3(0, 0.375, 0)))
	add_child(wb_body)

	# Коробка с сигнальными ракетами на верстаке (награда за вылазку на озеро)
	var flare_model := Props._kedr_model("lake_flares", {"bright": 1.15})
	var flare_box := Geo.interactable(self, Vector3(0.35, 0.2, 0.25), shack_center + Vector3(-2.6, deck_h + 0.85, -1.35), Palette.m(&"canister") if flare_model == null else null, "", func(_p: Player) -> void:
		if Game.has_flag("lake_flares_taken"):
			return
		Game.set_flag("lake_flares_taken", true)
		Game.add_spare_flares(2)
		Game.audio.play_2d("res://assets/audio/clank.ogg", 1.0)
		Game.hud.subtitle(Loc.t(&"sub.lake_flares"), 4.5)
		Director.add_tension(-10.0, "найдены ракеты в сарае")
	)
	flare_box.prompt_provider = func() -> String:
		return "" if Game.has_flag("lake_flares_taken") else Loc.t(&"it.lake_flares")
	if flare_model != null:
		flare_model.position = Vector3(0.0, -0.1, 0.0)
		flare_model.rotation.y = deg_to_rad(6.0)
		flare_box.add_child(flare_model)

	# Широкие таёжные лыжи охотника
	var skis_model := Props._kedr_model("lake_skis", {"bright": 1.2})
	var skis := Geo.interactable(self, Vector3(0.3, 1.9, 0.12), shack_center + Vector3(-3.4, deck_h + 0.95, 0.9), Palette.m(&"red") if skis_model == null else null, "", _on_skis_used)
	if skis_model != null:
		skis_model.name = "SkisModel"
		skis_model.position = Vector3(-0.08, -0.95, 0.0)
		skis_model.rotation = Vector3(0.0, -PI / 2.0, deg_to_rad(-5.0))
		skis.add_child(skis_model)
		_skis_model = skis_model
		skis_model.visible = not Game.has_item(&"skis")
	skis.prompt_provider = func() -> String:
		if Game.has_item(&"skis"):
			return Loc.t(&"it.skis_none")
		return Loc.t(&"it.skis") if Game.progress() >= 12 else Loc.t(&"it.skis_later")

	# Керосиновый подвесной фонарь «Летучая мышь»
	var lamp := Geo.omni(self, shack_center + Vector3(-1.2, deck_h + 2.0, 1.3), 7.5, 1.0, Color(1.0, 0.68, 0.35))
	Geo.cylinder(self, 0.01, 0.9, shack_center + Vector3(-1.2, deck_h + 2.55, 1.3), Palette.m(&"rope"), false)

	# Вёсла от дощаника у северной стены
	var oars := Props._kedr_model("lake_oars", {"bright": 1.2})
	if oars != null:
		oars.position = shack_center + Vector3(3.2, deck_h, -2.3)
		oars.rotation.y = deg_to_rad(8.0)
		add_child(oars)
	Geo.bulb(lamp, &"amber", 0.08)


func _on_hole_used(_p: Player) -> void:
	if Game.has_item(&"bunker_key") or Game.progress() < 8:
		return
	Game.give_item(&"bunker_key")
	if Game.is_day():
		Game.day_goal_done = true
	Game.audio.play_3d(CLANK_SOUND, HOLE, -4.0)
	Game.hud.subtitle(Loc.t(&"sub.got_key"), 8.0)
	Director.add_tension(10.0, "прорубь")
	# В том же мешке — бобина: Семёнов записал удар 03:10 здесь, на льду. Распадок проступит при чистке.
	if Game.add_tape(&"rec0310"):
		await get_tree().create_timer(8.5, false).timeout
		Game.hud.subtitle(Loc.t(&"sub.got_rec0310"), 7.0)


var _skis_model: Node3D


func _on_skis_used(_p: Player) -> void:
	if Game.has_item(&"skis") or Game.progress() < 12:
		if not Game.has_item(&"skis"):
			Game.hud.subtitle(Loc.t(&"sub.skis_later"), 4.0)
		return
	Game.give_item(&"skis")
	if is_instance_valid(_skis_model):
		_skis_model.visible = false
	if Game.is_day():
		Game.day_goal_done = true
	Game.hud.subtitle(Loc.t(&"sub.got_skis"), 7.0)


func _build_bunker() -> void:
	var c := Palette.m(&"concrete")
	# 1. Наземное оголовочное укрепление: железобетонный капонир с отдушиной
	var portal_body := StaticBody3D.new()
	portal_body.collision_layer = Geo.LAYER_WORLD
	portal_body.position = BUNKER
	portal_body.add_child(Props.bunker_caponier_portal())
	portal_body.add_child(Geo.box_shape(Vector3(3.5, 1.4, 3.5), Vector3(0, 0.7, 0)))
	add_child(portal_body)

	var hatch := Geo.interactable(self, Vector3(1.4, 0.5, 1.4), BUNKER + Vector3(0, 1.35, 0), null, "", _on_hatch_used)
	hatch.prompt_provider = func() -> String:
		return Loc.t(&"it.hatch") if Game.has_item(&"bunker_key") else Loc.t(&"it.hatch_locked")

	# 2. Подземный бункер связи ГО «Отзвук» (глубина -30м):
	var r := BUNKER_ROOM
	var hall_w := 12.0
	var hall_d := 8.0
	var hall_h := 3.2
	var hall_c := r + Vector3(8.0, 0, 0)

	# 2.1 Цельная запечённая 3D-модель аппаратного зала (tools/blender/bunker_interior.py)
	Models.spawn(self, "kedr/bunker_interior", r, 0.0, -1.0, {"keep": true, "center": false, "bright": 1.25, "sat": 0.95})

	# 2.2 Физические коллизии бункера (пол, стены, потолок, стойки и пульт)
	var bunk_body := StaticBody3D.new()
	bunk_body.collision_layer = Geo.LAYER_WORLD
	bunk_body.collision_mask = 0
	# Полы
	bunk_body.add_child(Geo.box_shape(Vector3(3.4, 0.3, 5.4), r + Vector3(-6.0, -0.15, 0))) # тамбур
	bunk_body.add_child(Geo.box_shape(Vector3(6.8, 0.3, 2.4), r + Vector3(-1.25, -0.15, 0))) # коридор
	bunk_body.add_child(Geo.box_shape(Vector3(hall_w + 0.4, 0.3, hall_d + 0.4), hall_c + Vector3(0, -0.15, 0))) # зал
	# Стены тамбура
	bunk_body.add_child(Geo.box_shape(Vector3(3.4, 3.0, 0.3), r + Vector3(-6.0, 1.5, -2.6)))
	bunk_body.add_child(Geo.box_shape(Vector3(3.4, 3.0, 0.3), r + Vector3(-6.0, 1.5, 2.6)))
	bunk_body.add_child(Geo.box_shape(Vector3(0.3, 3.0, 5.4), r + Vector3(-7.6, 1.5, 0)))
	bunk_body.add_child(Geo.box_shape(Vector3(0.3, 3.0, 2.0), r + Vector3(-4.5, 1.5, -1.7)))
	bunk_body.add_child(Geo.box_shape(Vector3(0.3, 3.0, 2.0), r + Vector3(-4.5, 1.5, 1.7)))
	# Стены коридора
	bunk_body.add_child(Geo.box_shape(Vector3(6.8, 2.5, 0.3), r + Vector3(-1.25, 1.2, -1.2)))
	bunk_body.add_child(Geo.box_shape(Vector3(6.8, 2.5, 0.3), r + Vector3(-1.25, 1.2, 1.2)))
	# Стены зала
	bunk_body.add_child(Geo.box_shape(Vector3(hall_w + 0.4, hall_h, 0.3), hall_c + Vector3(0, hall_h / 2.0, -hall_d / 2.0)))
	bunk_body.add_child(Geo.box_shape(Vector3(hall_w + 0.4, hall_h, 0.3), hall_c + Vector3(0, hall_h / 2.0, hall_d / 2.0)))
	bunk_body.add_child(Geo.box_shape(Vector3(0.3, hall_h, hall_d + 0.4), hall_c + Vector3(hall_w / 2.0, hall_h / 2.0, 0)))
	bunk_body.add_child(Geo.box_shape(Vector3(0.3, hall_h, 3.4), r + Vector3(2.0, hall_h / 2.0, -2.6)))
	bunk_body.add_child(Geo.box_shape(Vector3(0.3, hall_h, 3.4), r + Vector3(2.0, hall_h / 2.0, 2.6)))
	# Коллизии стоек аппаратуры и пульта связи
	bunk_body.add_child(Geo.box_shape(Vector3(7.6, 2.4, 0.75), hall_c + Vector3(-1.5, 1.2, -2.4)))
	bunk_body.add_child(Geo.box_shape(Vector3(7.6, 2.4, 0.75), hall_c + Vector3(-1.5, 1.2, 2.4)))
	bunk_body.add_child(Geo.box_shape(Vector3(1.1, 0.8, 3.2), hall_c + Vector3(4.2, 0.4, 0.0)))
	add_child(bunk_body)

	# 2.3 Интерактивные объекты и декор
	var ladder := Geo.interactable(self, Vector3(0.5, 2.8, 0.4), r + Vector3(-6.8, 1.4, 0), null, Loc.t(&"it.ladder"), _on_ladder_used)
	ladder.name = "Ladder"

	var blast_door := Props.bunker_blast_door()
	blast_door.position = r + Vector3(-4.5, 0.0, 0.0)
	add_child(blast_door)
	var door_it := Geo.interactable(self, Vector3(0.6, 2.1, 1.3), r + Vector3(-4.5, 1.05, 0), null, Loc.t(&"it.blast_door"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"it.blast_door"), 3.5)
	)
	door_it.name = "BlastDoor"
	door_it.collision_layer = Geo.LAYER_INTERACT

	# Аварийное красное освещение в коридоре
	for k in range(2):
		var lamp_pos := r + Vector3(-3.2 + k * 3.4, 2.2, 0)
		var red_lamp := Geo.omni(self, lamp_pos, 4.0, 0.8, Color(1.0, 0.15, 0.1))
		Geo.bulb(red_lamp, &"red", 0.06)

	# Семёнов: сидит у пульта в наушниках
	var body := Creatures.make_corpse()
	add_child(body)
	body.position = hall_c + Vector3(3.8, 0.0, 0.6)
	body.rotation.y = deg_to_rad(-90.0)
	Geo.block(self, Vector3(0.28, 0.06, 0.12), hall_c + Vector3(3.86, 1.07, 0.58), Palette.m(&"dark"), false)

	# Документы и список дежурных на столе
	var doc := Geo.interactable(self, Vector3(0.35, 0.03, 0.25), hall_c + Vector3(4.5, 0.82, 0.3), Palette.m(&"paper"), Loc.t(&"it.bunker_doc"), _on_bunker_doc)
	doc.name = "BunkerDoc"

	var roll := Geo.interactable(self, Vector3(0.7, 0.9, 0.02), hall_c + Vector3(5.7, 1.6, 0.0), Palette.m(&"paper"), Loc.t(&"it.bunker_list"), _on_bunker_list)
	roll.name = "BunkerList"
	roll.rotation.y = deg_to_rad(-90.0)

	# Магнитная бобина «Спецсвязь-17» на столе аппаратуры
	var tape_it: Interactable = null
	tape_it = Geo.interactable(self, Vector3(0.28, 0.08, 0.28), hall_c + Vector3(4.3, 0.82, -0.4), Palette.m(&"dark"), Loc.t(&"it.tape_bunker"), func(_p: Player) -> void:
		if not Game.has_item(&"tape_bunker"):
			Game.give_item(&"tape_bunker")
			Game.add_tape(&"tape_bunker")
			AudioDirector.play_raw("res://assets/audio/clank.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.tape_bunker_found"), 5.0)
			SaveGame.write()
			if tape_it != null:
				tape_it.queue_free()
	)
	tape_it.name = "BunkerTapeSpecComms"

	# Капель воды в тамбуре бункера
	var drip := AudioStreamPlayer3D.new()
	drip.stream = AudioDirector.cached_stream("res://assets/sfx/cc0/drip_1.ogg")
	drip.position = hall_c + Vector3(-6.0, 2.2, 0)
	drip.unit_size = 4.0
	drip.max_distance = 18.0
	drip.volume_db = -10.0
	drip.bus = &"SFX"
	drip.autoplay = true
	add_child(drip)

	# Освещение аппаратного зала: тусклое люминесцентное зелёно-болотное
	var lamp := Geo.omni(self, hall_c + Vector3(0, 2.7, 0), 10.0, 0.65, Color(0.7, 1.0, 0.75))
	Geo.bulb(lamp, &"bulb")
	Geo.omni(self, hall_c + Vector3(4.0, 1.2, 0.0), 4.5, 0.5, Color(1.0, 0.7, 0.3))


func _on_hatch_used(p: Player) -> void:
	if not Game.has_item(&"bunker_key"):
		Game.hud.subtitle(Loc.t(&"sub.hatch_locked"), 3.0)
		return
	Game.audio.play_3d(CLANK_SOUND, BUNKER + Vector3(0, 0.8, 0), 0.0)
	await Game.hud.blink(0.5)
	p.global_position = BUNKER_ROOM + Vector3(-5.5, 0.05, 0)
	p.rotation.y = deg_to_rad(-90.0)
	if not Game.has_flag("bunker_seen"):
		Game.set_flag("bunker_seen", true)
		Game.hud.subtitle(Loc.t(&"sub.bunker_in"), 7.0)



func _on_ladder_used(p: Player) -> void:
	Game.audio.play_3d(CLANK_SOUND, BUNKER + Vector3(0, 0.8, 0), 0.0)
	await Game.hud.blink(0.5)
	p.global_position = BUNKER + Vector3(-1.9, 0.05, 0)
	p.rotation.y = deg_to_rad(90.0)


func _on_bunker_doc(p: Player) -> void:
	Game.hud.show_note(Loc.t(&"note.bunker"))
	p.mode = Player.Mode.READING
	Game.set_flag("truth", true)
	if Game.is_day() and Game.phase_index == 5:
		Game.day_goal_done = true
	_bearing_after_note("bunker")


## След Семёнова даёт пеленг на 03:10: азимут в его записке (ретранслятор), кабель из бункера.
## Пишем, когда записку закрыли — иначе подпись спрячется под листом.
func _bearing_after_note(site: String) -> void:
	if FieldJobs.has_bearing(site):
		return
	while Game.hud != null and Game.hud.is_note_open():
		await get_tree().create_timer(0.3, false).timeout
	await get_tree().create_timer(0.6, false).timeout
	FieldJobs.record_bearing(site)
	SaveGame.write()


func _on_bunker_list(p: Player) -> void:
	Game.hud.show_note(Loc.t(&"note.bunker_list"))
	p.mode = Player.Mode.READING


# --- Зимник (концовка «уйти на лыжах») -----------------------------------------

func _build_zimnik() -> void:
	# Ставим всё по рельефу: раньше высота была зашита (7.8), и шлагбаум, КУНГ и тропа висели в воздухе
	var root := ZIMNIK
	root.y = Terrain.height(root.x, root.z)
	Geo.block(self, Vector3(0.12, 2.6, 0.12), root + Vector3(-2.2, 1.3, 0), Palette.m(&"dark"), false)
	Geo.block(self, Vector3(0.12, 1.1, 0.12), root + Vector3(2.2, 0.55, 0), Palette.m(&"dark"), false)
	var bar := Geo.block(self, Vector3(4.4, 0.1, 0.1), root + Vector3(0, 1.05, 0), Palette.m(&"red"), false)
	bar.rotation.z = 0.05
	var sign_root := Node3D.new()
	add_child(sign_root)
	sign_root.position = root + Vector3(-2.2, 0, 0)
	sign_root.look_at(sign_root.position + Vector3(0.6, 0, 0.8), Vector3.UP)
	Geo.block(sign_root, Vector3(1.3, 0.5, 0.03), Vector3(0, 2.25, 0), Palette.m(&"white"), false)
	for back in [false, true]:
		var l := Label3D.new()
		l.text = Loc.t(&"sign.zimnik_end")
		l.font_size = 36
		l.pixel_size = 0.005
		l.modulate = Color(0.12, 0.1, 0.1)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(0, 2.25, 0.02 if back else -0.02)
		if not back:
			l.rotation.y = PI
		sign_root.add_child(l)

	# Заброшенный строительно-дорожный КУНГ на полозьях (вахтовка)
	var kung := Props.kung_trailer()
	kung.position = root + Vector3(4.5, 0.0, -3.2)
	kung.position.y = Terrain.height(kung.position.x, kung.position.z)
	kung.rotation.y = deg_to_rad(15.0)
	add_child(kung)
	# Кузов КУНГа вытянут по X модели — коробка взаимодействия тоже
	var kung_it := Geo.interactable(self, Vector3(5.4, 2.2, 2.6), kung.position + Vector3(0, 1.1, 0), null, Loc.t(&"it.kung_cabin"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.kung_cabin"), 4.5)
	)
	kung_it.rotation.y = kung.rotation.y
	kung_it.name = "KungTrailer"


func _check_zimnik(delta: float) -> void:
	_zimnik_cd -= delta
	if Game.player == null or not is_inside_tree() or not Game.player.is_inside_tree() or _zimnik_cd > 0.0 or not open_sites.get("zimnik", false):
		return
	if _flat_dist(Game.player.global_position, ZIMNIK) > 4.0:
		return
	_zimnik_cd = 6.0
	EventBus.zimnik_reached.emit()


# --- Случайные находки ночи (NightEvents) -------------------------------------

## Цепочка босых следов по точкам.
func spawn_trail(points: Array) -> void:
	var mat := Palette.m(&"dark")
	var step := 0.85
	var k := 0
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		var d := (b - a).normalized()
		var side := d.cross(Vector3.UP).normalized()
		for j in range(n):
			var p := a.lerp(b, float(j) / n) + side * (0.17 if k % 2 == 0 else -0.17)
			var fp := Geo.box_mesh(Vector3(0.13, 0.01, 0.36), mat)
			fp.position = Vector3(p.x, 0.012, p.z)
			fp.rotation.y = atan2(d.x, d.z)
			add_child(fp)
			k += 1


## Рукавица Семёнова на крыльце.
func spawn_porch_item() -> void:
	var kit := MeshKit.new(41)
	kit.mottle = 0.1
	kit.blob(Vector3(0, 0.05, 0), Vector3(0.07, 0.045, 0.11), Color(0.25, 0.2, 0.15), 3, 6)
	kit.blob(Vector3(0.06, 0.04, 0.03), Vector3(0.025, 0.025, 0.04), Color(0.25, 0.2, 0.15), 3, 5)
	kit.box(Vector3(0, 0.04, -0.12), Vector3(0.1, 0.06, 0.05), Color(0.6, 0.6, 0.62))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.material_override = Creatures._mat(&"mitten", Color.WHITE, "tex_cloth.png", 0.0)
	add_child(mi)
	mi.position = Vector3(15.3, 0.06, 2.6)   # на настиле крыльца, снаружи
	mi.rotation.y = 0.7


# --- Следы вокруг дома (день 1) ----------------------------------------------

## Цепочка следов вокруг дома к северному окну. Человечьи — но босые, и шаг слишком длинный.
func _build_footprints() -> void:
	# Босые следы из леса на юго-востоке — вдоль южной стены, вокруг жилой, за кладовую — под окно рубки.
	var route := PackedVector3Array([Vector3(22, 0, 13), Vector3(15.8, 0, 8.4), Vector3(6.0, 0, 8.4),
		Vector3(-4.3, 0, 7.6), Vector3(-4.4, 0, -1.7), Vector3(1.9, 0, -2.0), Vector3(2.0, 0, -7.4),
		Vector3(8.4, 0, -7.4), Vector3(9.0, 0, -3.8), Vector3(9.2, 0, -2.9)])
	Footprints.trail(self, &"bare", route, 0.0, 0.5)
	if Game.is_night():
		var outhouse_tracks := PackedVector3Array([
			Vector3(14.0, 0, 32.0), Vector3(15.0, 0, 25.0), Vector3(16.0, 0, 20.5),
			Vector3(17.2, 0, 19.5), Vector3(19.0, 0, 22.0), Vector3(23.0, 0, 28.0)
		])
		Footprints.trail(self, &"bare", outhouse_tracks, 0.0, 0.5)
	# Лиса прошла от опушки вдоль двора, обнюхала поленницу и ушла обратно в лес — цепочка «в строчку».
	var fox := PackedVector3Array([Vector3(-14, 0, 22), Vector3(-6, 0, 18), Vector3(2, 0, 16.5), Vector3(5, 0, 21),
		Vector3(3.5, 0, 30), Vector3(-2, 0, 36), Vector3(-9, 0, 41)])
	Footprints.trail(self, &"paw", fox, 0.0, 0.3, 0.035)


# --- Лес ---------------------------------------------------------------------

func _forest_mask(p: Vector3) -> float:   # -1 = дефолт (шум), 0 = пусто, 1 = стена
	var d_path := _dist_to(_all_paths, p)
	if d_path < ALLEY_HALF:
		return 0.0
	for g: Dictionary in GLADES:
		var d := _flat_dist(p, g["c"])
		if d < g["r"]: return 0.0
		if d < g["r"] + WALL_W: return 1.0
	if d_path < ALLEY_HALF + WALL_W:
		return 1.0
	return -1.0


func _vec_to_path(lines: Array[PackedVector3Array], pos: Vector3) -> Vector3:
	var px := pos.x
	var pz := pos.z
	var best_sq := INF
	var best_v := Vector3.ZERO
	for line in lines:
		var n := line.size()
		for i in range(n - 1):
			var a := line[i]
			var b := line[i + 1]
			var abx := b.x - a.x
			var abz := b.z - a.z
			var apx := px - a.x
			var apz := pz - a.z
			var len_sq := abx * abx + abz * abz
			var t := 0.0 if len_sq <= 0.0 else clampf((apx * abx + apz * abz) / len_sq, 0.0, 1.0)
			var qx := a.x + t * abx
			var qz := a.z + t * abz
			var dx := qx - px
			var dz := qz - pz
			var d_sq := dx * dx + dz * dz
			if d_sq < best_sq:
				best_sq = d_sq
				best_v = Vector3(dx, 0.0, dz)
	return best_v.normalized() if best_sq > 0.0001 else Vector3.ZERO


func _process_forest_sounds(delta: float) -> void:
	_creak_t -= delta
	if _creak_t <= 0.0 and Game.player != null and Game.is_outside():
		var g: float = Storm.intensity
		_creak_t = randf_range(10.0, 26.0) / maxf(g, 0.3)
		var a := randf() * TAU
		var pos := Game.player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(14.0, 28.0)
		Game.audio.play_3d("res://assets/audio/tree_creak.ogg", pos + Vector3(0, 2.5, 0), -8.0 + g * 4.0, 10.0)

	# Хлопанье оторванного листа жести на крыше сарая при ветре
	_shed_tin_t -= delta
	if _shed_tin_t <= 0.0 and Game.player != null and Game.is_outside():
		var storm_w: float = Storm.intensity
		_shed_tin_t = randf_range(8.0, 19.0) / maxf(storm_w, 0.35)
		var tin_pos := SHED + Vector3(-2.0, 3.2, 0.0)
		var tin_snd: String = "res://assets/audio/clank_v%d.ogg" % randi_range(2, 4)
		Game.audio.play_3d(tin_snd, tin_pos, -6.0 + storm_w * 3.0, 14.0)

	if _snow_drop_cd > 0.0:
		_snow_drop_cd -= delta


func _snow_drop(at: Vector3) -> void:
	Game.audio.play_3d("res://assets/audio/snow_fall.ogg", at, -2.0, 12.0)
	if Game.player != null:
		Game.player.shake(0.03, 0.25)
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = 30
	burst.lifetime = 0.9
	burst.explosiveness = 0.8
	burst.direction = Vector3(0, -1, 0)
	burst.spread = 25.0
	burst.initial_velocity_min = 0.5
	burst.initial_velocity_max = 1.8
	burst.gravity = Vector3(0, -6.0, 0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.4
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.5
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	burst.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.8)
	burst.material_override = m
	burst.position = at
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _build_snow_drop_triggers() -> void:
	var trigger_pts: Array[Vector3] = [
		Vector3(12.0, 0.0, -2.0),
		Vector3(26.0, 0.0, -8.0),
		Vector3(28.0, 0.0, -22.0),
		Vector3(24.0, 0.0, -42.0),
		Vector3(45.0, 0.0, -18.0),
		Vector3(30.0, 0.0, 18.0),
	]
	for tp in trigger_pts:
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = Player.LAYER_PLAYER
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 2.5
		cs.shape = sh
		area.add_child(cs)
		var h := Terrain.height(tp.x, tp.z)
		area.position = Vector3(tp.x, h + 1.0, tp.z)
		add_child(area)
		var drop_pos := Vector3(tp.x, h + 3.2, tp.z)
		area.body_entered.connect(func(body: Node3D) -> void:
			if body == Game.player and _snow_drop_cd <= 0.0:
				_snow_drop_cd = 45.0
				if randf() < 0.35:
					_snow_drop(drop_pos)
		)


func _build_forest() -> void:
	SpruceNear.clear_registry()
	# Фиксированный сид: лес одинаковый в каждом прохождении (рандом — только у директора).
	# Композиция: у дома — редкие группы и открытый двор; дальше — куртины с просветами и полянами;
	# за 55 м — плотная тёмная стена. На краях куртин и у полян — сухостой и молодняк, рядом — бурелом.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var groves := FastNoiseLite.new()
	groves.seed = 17
	groves.frequency = 0.035
	groves.fractal_octaves = 2
	var glades := FastNoiseLite.new()
	glades.seed = 23
	glades.frequency = 0.07
	var transforms: Array[Transform3D] = []
	var kinds: Array[int] = []       ## -1 — по жребию, 2 — молодняк, 3 — сухостой
	var bodies := StaticBody3D.new()
	bodies.collision_layer = Geo.LAYER_WORLD
	add_child(bodies)
	var center := Vector3(25.0, 0.0, -8.0)
	var occupied := {}
	var edge_points: Array[Vector3] = []
	var attempts := 0
	var tree_count := int(860 * Settings.detail())   # пресет графики: низкое — реже лес
	while transforms.size() < tree_count and attempts < 40000:
		attempts += 1
		var p := center + Vector3(rng.randf_range(-95, 95), 0.0, rng.randf_range(-95, 95))
		var d_house := _flat_dist(p, HOUSE_CENTER)
		var m := _forest_mask(p)
		if m == 0.0:
			continue
		var d_path := _dist_to(_all_paths, p)
		if d_house < 13.0 or d_path < ALLEY_HALF:
			continue
		if _near_corpus(p, 7.0) or _in_shed_box(p) or _flat_dist(p, MAST) < 11.5 or _flat_dist(p, IZBA) < 8.5 or (p.x >= -22.0 and p.x <= -10.0 and p.z >= -36.0 and p.z <= -24.0) or _flat_dist(p, WOODPILE) < 7.5:
			continue
		if _flat_dist(p, Vector3(14.5, 0.0, -13.5)) < 7.5 or (p.x > 11.0 and p.x < 18.0 and p.z > -16.0 and p.z < 4.0):
			continue
		if _flat_dist(p, LAKE) < LAKE_R + 4.0 or _flat_dist(p, LAKE_SHACK) < 6.0 or _flat_dist(p, REPEATER) < 9.0 or _flat_dist(p, BUNKER) < 6.0 or _flat_dist(p, HELIPAD) < 9.5 or _flat_dist(p, Vector3(17.2, 0.0, 19.5)) < 4.5:
			continue

		var dens: float
		if m >= 0.0:
			dens = m
		else:
			var g := groves.get_noise_2d(p.x, p.z)
			dens = smoothstep(-0.25, 0.3, g)                 # куртины и промежутки между ними
			if d_house < 26.0:
				dens = maxf(dens, 0.88)                      # плотное кольцо вековых елей вокруг кордона
			if glades.get_noise_2d(p.x, p.z) > 0.42:
				dens *= 0.12                                 # поляны
			if d_house > 55.0:
				dens = maxf(dens, 0.9)                       # дальняя стена
		if rng.randf() > dens:
			continue
		var cell := Vector2i(floori(p.x / 1.9), floori(p.z / 1.9))
		if occupied.has(cell):
			continue
		occupied[cell] = true
		var s := rng.randf_range(1.15, 1.85) if d_house < 28.0 else (rng.randf_range(0.85, 1.65) if d_house < 55.0 else rng.randf_range(1.15, 1.95))
		var alley_tilt := Basis()
		if d_path < 7.0:
			var to_path := _vec_to_path(_all_paths, p)
			if to_path.length_squared() > 0.01:
				var axis := Vector3.UP.cross(to_path).normalized()
				alley_tilt = Basis(axis, deg_to_rad(rng.randf_range(6.0, 10.0)))
		var b := alley_tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		transforms.append(Transform3D(b, p))
		var edge := dens < 0.6 and d_house < 55.0
		var kind := -1
		if edge:
			var r := rng.randf()
			kind = 3 if r < 0.22 else 2 if r < 0.45 else -1
			if rng.randf() < 0.12:
				edge_points.append(p)
		kinds.append(kind)
		if d_house < 55.0 or _dist_to(_all_paths, p) < 10.0:
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.3 * s
			sh.height = 3.0
			cs.shape = sh
			cs.position = p + Vector3(0, 1.5, 0)
			bodies.add_child(cs)
	_build_windfall(edge_points, rng)

	# Гранёные заснеженные ели (SpruceMesh): четыре вида — густая, стройная, молодая, сухостой.
	# Один меш на дерево, один MultiMesh на вид.
	var by_variant: Array = [[], [], [], []]
	var vr := RandomNumberGenerator.new()
	vr.seed = 11
	for ti in transforms.size():
		var t := transforms[ti]
		var roll := vr.randf()
		var v := 0 if roll < 0.52 else 1 if roll < 0.84 else 2 if roll < 0.95 else 3
		if kinds[ti] >= 0:
			v = kinds[ti]
		# Лёгкий наклон под тяжестью снега — лес не по линейке.
		var axis := Vector3(vr.randf_range(-1, 1), 0, vr.randf_range(-1, 1)).normalized()
		var tilt := Basis(axis, deg_to_rad(vr.randf_range(0.0, 3.5)))
		(by_variant[v] as Array).append(Transform3D(tilt * t.basis, t.origin))
	# Лес режем на квадраты FOREST_CELL: один MultiMesh на весь двор рисовался целиком в любую сторону
	# (120 тыс. треугольников даже в комнате). Квадраты за спиной и за туманом теперь отсекаются.
	var far := 150.0 if Game.is_daylight() else 95.0    # дальше туман всё равно съедает ели на 96 %
	for v in range(4):
		var cells: Dictionary = {}
		for t: Transform3D in by_variant[v]:
			var ck := Vector2i(floori(t.origin.x / FOREST_CELL), floori(t.origin.z / FOREST_CELL))
			if not cells.has(ck):
				cells[ck] = []
			(cells[ck] as Array).append(t)
		for ck in cells:
			var list: Array = cells[ck]
			var cc := Vector3((ck.x + 0.5) * FOREST_CELL, 0.0, (ck.y + 0.5) * FOREST_CELL)
			# Гранёные ели (ближе NEAR_RANGE шейдер их прячет — там ели-карточки SpruceNear)
			for t: Transform3D in list:
				SpruceNear.register(v, t)
			for lod in 1:
				var lm: ArrayMesh = SpruceMesh.lod_far(v, SpruceMesh.NEAR_RANGE)
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = lm
				mm.instance_count = list.size()
				for i in range(list.size()):
					var t: Transform3D = list[i]
					mm.set_instance_transform(i, Transform3D(t.basis, t.origin - cc))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.position = cc
				mmi.visibility_range_end = far
				mmi.visibility_range_end_margin = 6.0
				mmi.layers = Station.LAYER_OUT   # лес — только «снаружи»: лампы в доме не рисуют его в свои тени
				add_child(mmi)
	# Дальняя тайга до краёв карты и зимники к дальним точкам
	Terrain.build_forest(self, far, Vector3(25.0, 0.0, -8.0), 97.0)
	add_child(SpruceNear.new())
	Terrain.build_roads(self)


## Бурелом на краях куртин: поваленные стволы, выворотни-пни, кругляк — лес не «газон с ёлками».
func _build_windfall(points: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var n := 0
	for p in points:
		if n >= int(34 * Settings.detail()) + 6:
			break
		if _dist_to(_all_paths, p) < 3.5 or _flat_dist(p, HOUSE_CENTER) < 16.0:
			continue
		if _flat_dist(p, Vector3(14.5, 0.0, -13.5)) < 7.5 or (p.x > 11.0 and p.x < 18.0 and p.z > -16.0 and p.z < 4.0):
			continue
		if _near_corpus(p, 7.0) or _in_shed_box(p) or _flat_dist(p, MAST) < 11.5 or _flat_dist(p, IZBA) < 7.0 or _flat_dist(p, WOODPILE) < 7.5:
			continue
		if _flat_dist(p, LAKE) < LAKE_R + 4.0 or _flat_dist(p, LAKE_SHACK) < 6.0 or _flat_dist(p, REPEATER) < 9.0 or _flat_dist(p, BUNKER) < 6.0:
			continue
		var off := Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
		var target_pos := p + off
		if _dist_to(_all_paths, target_pos) < 3.5 or _flat_dist(target_pos, PLOT) < 7.5:
			continue
		var roll := rng.randf()
		if roll < 0.55:
			Models.spawn(self, "nature/log_large", p + off - Vector3(0, 0.08, 0), rng.randf() * 360.0, rng.randf_range(0.4, 0.6),
				{"collide": true, "tint": Color(0.7, 0.66, 0.62), "tilt": Vector3(0, 0, rng.randf_range(-6, 6))})
		elif roll < 0.85:
			Models.spawn(self, "nature/stump_oldTall" if rng.randf() < 0.5 else "nature/stump_old", p + off, rng.randf() * 360.0,
				rng.randf_range(0.45, 0.95), {"collide": true, "tint": Color(0.7, 0.66, 0.62)})
		else:
			Models.spawn(self, "nature/log_stack", p + off, rng.randf() * 360.0, 0.4, {"collide": true, "tint": Color(0.7, 0.66, 0.62)})
		n += 1


func _cone(top: float, bottom: float, height: float, mat_key: StringName, radial_segs := 6) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = radial_segs
	cm.rings = 1
	cm.material = Palette.m(mat_key)
	return cm


func _tree_layer(transforms: Array[Transform3D], mesh: Mesh, y_offset: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var t := transforms[i]
		var lift := t.basis * Vector3(0, y_offset, 0)
		mm.set_instance_transform(i, Transform3D(t.basis, t.origin + lift))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _build_bounds() -> void:
	# Край карты: хребты (Terrain) и невидимая стена за ними — за пределы километра не уйти.
	var c := Vector3(Terrain.CENTER.x, 40.0, Terrain.CENTER.y)
	var r := Terrain.HALF - 10.0
	for d: Vector3 in [Vector3(0, 0, -r), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(r, 0, 0)]:
		var size := Vector3(4.0, 160.0, 2.0 * r + 8.0) if d.z == 0.0 else Vector3(2.0 * r + 8.0, 160.0, 4.0)
		var body := StaticBody3D.new()
		body.position = c + d
		add_child(body)
		body.add_child(Geo.box_shape(size))


# --- Хелперы -----------------------------------------------------------------

func _dist_to(lines: Array[PackedVector3Array], pos: Vector3) -> float:
	var px := pos.x
	var pz := pos.z
	var best_sq := INF
	for line in lines:
		var n := line.size()
		for i in range(n - 1):
			var a := line[i]
			var b := line[i + 1]
			var abx := b.x - a.x
			var abz := b.z - a.z
			var apx := px - a.x
			var apz := pz - a.z
			var len_sq := abx * abx + abz * abz
			var t := 0.0 if len_sq <= 0.0 else clampf((apx * abx + apz * abz) / len_sq, 0.0, 1.0)
			var qx := a.x + t * abx
			var qz := a.z + t * abz
			var dx := px - qx
			var dz := pz - qz
			var d_sq := dx * dx + dz * dz
			if d_sq < best_sq:
				best_sq = d_sq
	return sqrt(best_sq)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return sqrt(dx * dx + dz * dz)


## Треугольный фронтон (плоскость YZ) под двускатной крышей: основание — верх стены.
func _gable_mesh(base: Vector3, half: float, rise: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, -half), Vector3(0, 0, half), Vector3(0, rise, 0)]
	for w: Array in [[0, 1, 2], [0, 2, 1]]:
		var n := Vector3(1, 0, 0) if w[1] == 1 else Vector3(-1, 0, 0)
		for k: int in w:
			st.set_normal(n)
			st.set_uv(Vector2(pts[k].z, pts[k].y))
			st.add_vertex(pts[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = base
	return mi


func _csg(parent: Node, size: Vector3, pos: Vector3, mat: Material, subtract := false) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	if subtract:
		b.operation = CSGShape3D.OPERATION_SUBTRACTION
		b.material = mat if mat != null else Palette.m(&"plank")
	else:
		b.material = mat
	parent.add_child(b)
	return b


func _process_night6_bare_tracks(delta: float) -> void:
	if not Game.is_night() or Game.night != 6:
		return
	var booth_pos := METEO + M_BOOTH
	# До 02:00: следы босых ног ведут от будки во тьму тайги
	if not _night6_tracks_spawned:
		_night6_tracks_spawned = true
		_bare_tracks_root = Node3D.new()
		_bare_tracks_root.name = "Night6BareTracks"
		add_child(_bare_tracks_root)
		var out_route := PackedVector3Array([
			booth_pos + Vector3(0, 0, 0.5),
			booth_pos + Vector3(6.0, 0, 8.0),
			booth_pos + Vector3(14.0, 0, 18.0),
			booth_pos + Vector3(25.0, 0, 32.0)
		])
		Footprints.trail(_bare_tracks_root, &"bare", out_route, 0.02, 0.52)

	# После 02:00: следы возвращаются, но шаг втрое длиннее (1.55 м)!
	if Game.after_hour(2) and not _night6_return_tracks_spawned:
		_night6_return_tracks_spawned = true
		var return_route := PackedVector3Array([
			booth_pos + Vector3(25.0, 0, 32.0),
			booth_pos + Vector3(14.0, 0, 18.0),
			booth_pos + Vector3(6.0, 0, 8.0),
			booth_pos + Vector3(0, 0, 0.5),
			DOOR_OUT
		])
		Footprints.trail(_bare_tracks_root, &"bare", return_route, 0.02, 1.55)
		if Game.player != null and Game.player.global_position.distance_to(booth_pos) < 14.0:
			Game.hud.subtitle(Loc.t(&"sub.night6_bare_tracks"), 5.5)
			Director.add_tension(15.0, "босые следы с шагом 1.5 метра")

	# Заметание следов ветром и метелью прямо на глазах
	var wind_rate: float = 1.0 + (Game.weather.intensity * 1.8 if Game.weather != null else 0.0)
	if _bare_tracks_root != null and is_instance_valid(_bare_tracks_root):
		for ch in _bare_tracks_root.get_children():
			for fp in ch.get_children():
				if not (fp is Node3D):
					continue
				var life: float = fp.get_meta("life", 95.0) - delta * wind_rate
				fp.set_meta("life", life)
				if life < 28.0:
					(fp as Node3D).scale *= clampf(1.0 - delta * 0.45 * wind_rate, 0.85, 0.995)
				if life <= 0.0:
					fp.queue_free()


## Живые босые следы от ледника прямо к окну радиорубки (Ночи 2–5): пока игрок идёт вдоль них с «Жучком», метель стирает их на глазах.
func _process_cellar_window_tracks(delta: float) -> void:
	if not Game.is_night() or Game.night < 2 or Game.night > 5:
		return
	var win_pos := Vector3(9.2, 0.0, -2.0)
	var cellar_pos := cellar_prop.global_position if (cellar_prop != null and is_instance_valid(cellar_prop)) else Vector3(4.8, 0.0, -9.0)
	if not _cellar_window_tracks_done and not Game.is_indoors() and Game.player != null and (Game.after_hour(2) or Director.tension >= 38.0):
		_cellar_window_tracks_done = true
		_cellar_window_tracks_root = Node3D.new()
		_cellar_window_tracks_root.name = "CellarWindowBareTracks"
		add_child(_cellar_window_tracks_root)
		var route := PackedVector3Array([
			Vector3(cellar_pos.x, 0.0, cellar_pos.z + 1.1),
			Vector3(6.2, 0.0, -6.5),
			Vector3(7.9, 0.0, -4.1),
			Vector3(win_pos.x, 0.0, win_pos.z - 0.35),
		])
		Footprints.trail(_cellar_window_tracks_root, &"bare", route, 0.0, 0.48)
		# Помечаем время жизни по порядку следов: ранние у ледника заметает быстрее, свежие у окна держатся чуть дольше
		var idx := 0
		for ch in _cellar_window_tracks_root.get_children():
			for fp in ch.get_children():
				if fp is Node3D:
					fp.set_meta("life", 42.0 + float(idx) * 2.2)
					idx += 1
		if Game.player.global_position.distance_to(win_pos) < 26.0 or Game.player.global_position.distance_to(cellar_pos) < 24.0:
			Game.audio.play_3d("res://assets/audio/ice_hit.ogg", Vector3(9.2, 1.45, -2.0), -3.0, 12.0)
			if Game.hud != null:
				Game.hud.subtitle(Loc.t(&"sub.cellar_window_tracks"), 5.5, 1)
			Director.add_tension(12.0, "босые следы от ледника к окну")

	if _cellar_window_tracks_root != null and is_instance_valid(_cellar_window_tracks_root):
		var wind_rate: float = 1.0 + (Game.weather.intensity * 2.1 if Game.weather != null else 0.3)
		var any_left := false
		for ch in _cellar_window_tracks_root.get_children():
			for fp in ch.get_children():
				if not (fp is Node3D):
					continue
				any_left = true
				var life: float = fp.get_meta("life", 55.0) - delta * wind_rate
				fp.set_meta("life", life)
				if life < 22.0:
					(fp as Node3D).scale *= clampf(1.0 - delta * 0.55 * wind_rate, 0.82, 0.995)
				if life <= 0.0:
					fp.queue_free()
		if not any_left:
			_cellar_window_tracks_root.queue_free()
			_cellar_window_tracks_root = null


# --- Уличные кошмары и сущности ----------------------------------------------

func _process_outdoor_horror(delta: float) -> void:
	if not Game.is_night() or Game.is_indoors() or Game.player == null or Game.dead or Game.dying or Game.shift_over:
		if _outdoor_entity != null and is_instance_valid(_outdoor_entity):
			_clear_outdoor_entity()
		if _mimic_node != null and is_instance_valid(_mimic_node):
			_mimic_node.queue_free()
			_mimic_node = null
		_clear_forest_eyes()
		if _brownout_active:
			_end_brownout()
		return

	var is_late: bool = Game.after_hour(2) or Game.night >= 4

	# Активные сущности ОБЯЗАНЫ обновляться и заканчивать свой жизненный цикл,
	# даже если Директор перешёл в RELAX/PLAYING/hold или активировался Ырка.
	# Иначе Полуночница, Личина или шаги зависнут на сцене со своими звуками навсегда.
	var active := (_mimic_node != null and is_instance_valid(_mimic_node)) \
		or (_outdoor_entity != null and is_instance_valid(_outdoor_entity)) \
		or _brownout_active
	if active:
		if _mimic_node != null and is_instance_valid(_mimic_node):
			_process_mimic(delta, is_late)
		if _brownout_active:
			_process_brownout(delta, is_late)
		if _outdoor_entity != null and is_instance_valid(_outdoor_entity):
			_process_stalkers(delta, is_late)

	# Уличные страхи подчиняются ритму директора: в передышке, во время сценарных событий
	# и когда Ырка уже зовёт/давит — новые кошмары не начинаются, чтобы не перебивать главное.
	var yrka_busy := Game.yrka != null and Game.yrka.stage >= YrkaThreat.Stage.CALLING and Game.yrka.stage != YrkaThreat.Stage.RETREAT
	if Director.hold or Director.phase == Director.Phase.RELAX or Director.phase == Director.Phase.PLAYING or yrka_busy:
		return

	# Тишина — тоже страх. Уличные события тикают вдвое медленнее, а после любого заметного
	# (с субтитром или напряжением) — общая пауза 50–90 с: не больше одного «события» за раз.
	var tension_before := Director.tension
	_outdoor_cd -= delta
	var d := delta * 0.5
	if _outdoor_cd <= 0.0 and not active:
		# 1. Личина (Mimic / Обмирало) — зловещая неподвижная фигура с разворотом головы и скримером
		_process_mimic(d, is_late)
		# 2. Внезапный отказ фонаря со спринтом шагов в темноте
		_process_brownout(d, is_late)
		# 3. Красные горящие глаза в чаще леса
		_process_forest_eyes(d, is_late)
		# 4. Шёпоты в метели
		_process_whispers(d, is_late)
		# 5. Крупные сущности (Жердяй, Полуночница, Тень)
		_process_stalkers(d, is_late)
		# 7. Внезапный крик ворона из заснеженной кроны
		_crow_timer -= d
		if _crow_timer <= 0.0:
			_crow_timer = Game.rng.randf_range(120.0, 240.0)
			_trigger_crow_startle()
		if Director.tension > tension_before + 0.5:
			_outdoor_cd = Game.rng.randf_range(50.0, 90.0)

	# 6. Звуки глухой тайги (без субтитров) — фон, редкий
	_audio_scare_timer -= d
	if _audio_scare_timer <= 0.0:
		_audio_scare_timer = Game.rng.randf_range(25.0, 50.0) if is_late else Game.rng.randf_range(45.0, 90.0)
		_trigger_ambient_outdoor_audio()


func _trigger_crow_startle() -> void:
	if Game.player == null or not Game.is_outside() or not Game.is_night():
		return
	var p := Game.player
	var fwd := -p.global_transform.basis.z
	var crow_pos := p.global_position + fwd * 4.5 + Vector3(Game.rng.randf_range(-2.0, 2.0), 3.2, 0.0)
	Game.audio.play_3d("res://assets/audio/raven.ogg", crow_pos, 4.0, 10.0)
	Game.audio.play_3d("res://assets/audio/snow_fall.ogg", crow_pos, 1.0, 8.0)
	p.shake(0.04, 0.25)
	Game.hud.subtitle(Loc.t(&"sub.crow_startle"), 3.5, 0)
	Director.add_tension(9.0, "ворон сорвался с ветки")


# --- Личина (Mimic) ----------------------------------------------------------

func _process_mimic(delta: float, is_late: bool) -> void:
	if _mimic_node != null and is_instance_valid(_mimic_node):
		var p := Game.player
		if p == null:
			return
		var dist := p.global_position.distance_to(_mimic_node.global_position)
		var looking := p.is_looking_at(_mimic_node.global_position + Vector3(0, 1.4, 0), 20.0)
		var flash_on := p.flashlight_on()

		if not _mimic_triggered:
			# Подошёл ближе 9 метров или светит фонарём ближе 17 метров
			if dist < 9.0 or (looking and flash_on and dist < 17.0):
				_trigger_mimic_jumpscare()
				return
		if dist > 45.0:
			if _mimic_node != null and is_instance_valid(_mimic_node):
				_mimic_node.queue_free()
				_mimic_node = null
			_mimic_timer = Game.rng.randf_range(30.0, 60.0)
		return

	_mimic_timer -= delta
	if _mimic_timer <= 0.0:
		_mimic_timer = Game.rng.randf_range(50.0, 95.0) if is_late else Game.rng.randf_range(90.0, 160.0)
		_try_spawn_mimic()


func _try_spawn_mimic() -> void:
	var p := Game.player
	if p == null or not Game.is_outside() or _outdoor_entity != null:
		return
	if Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE:
		return

	var forward := -p.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var side := p.global_transform.basis.x
	side.y = 0.0
	side = side.normalized()

	var spawn_pos := p.global_position + forward * Game.rng.randf_range(16.0, 22.0) + side * Game.rng.randf_range(-4.0, 4.0)
	spawn_pos.y = 0.0

	if zone_at(spawn_pos) != &"yard":
		return

	var rig := Creatures.make_silhouette()   # личина — двойник: стоит спиной, а голова повернётся к тебе
	add_child(rig)
	rig.global_position = spawn_pos

	# Стоит спиной к игроку
	var face_pos := spawn_pos + forward
	face_pos.y = 0.0
	rig.look_at(face_pos, Vector3.UP)

	_mimic_node = rig
	_mimic_triggered = false


func _trigger_mimic_jumpscare() -> void:
	if _mimic_triggered or _mimic_node == null or not is_instance_valid(_mimic_node):
		return
	_mimic_triggered = true

	var p := Game.player
	var mimic := _mimic_node
	var m_pos := mimic.global_position

	# Резкий поворот головы на 180 градусов с треском костей
	if mimic is CreatureRig:
		(mimic as CreatureRig).set_rest(&"Head", Vector3(0.0, PI, 0.0))
		(mimic as CreatureRig).twitch = 0.0

	Game.audio.play_3d("res://assets/audio/ice_hit.ogg", m_pos + Vector3(0, 1.5, 0), -2.0)
	Game.audio.play_3d("res://assets/audio/shriek.ogg", m_pos + Vector3(0, 1.5, 0), 4.0)
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 1.0)
	Game.hud.subtitle(Loc.t(&"sub.mimic_turn"), 3.0, 0)

	Director.add_tension(25.0, "личина повернула голову")
	Game.add_fatigue(5.0)

	# Скример-рывок в сторону игрока
	var p_pos := p.global_position if p != null else m_pos
	var lunge_dir := (p_pos - m_pos).normalized()
	lunge_dir.y = 0.0
	var target := m_pos + lunge_dir * minf(m_pos.distance_to(p_pos) - 1.0, 4.5)

	# Тряска камеры игрока
	if p != null and p.camera != null:
		var tw_cam := create_tween()
		tw_cam.tween_property(p.camera, "rotation:z", 0.07, 0.08)
		tw_cam.tween_property(p.camera, "rotation:z", -0.06, 0.08)
		tw_cam.tween_property(p.camera, "rotation:z", 0.0, 0.1)

	var tw := create_tween()
	tw.tween_property(mimic, "global_position", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	if is_instance_valid(mimic):
		Game.audio.play_3d("res://assets/audio/gust.ogg", mimic.global_position, 1.0)
		mimic.queue_free()
	_mimic_node = null
	_mimic_timer = Game.rng.randf_range(35.0, 65.0)


# --- Отказ фонаря (Brownout) -------------------------------------------------

func _process_brownout(delta: float, is_late: bool) -> void:
	var p := Game.player
	if p == null or not Game.is_outside():
		if _brownout_active:
			_end_brownout()
		return

	if _brownout_active:
		_brownout_duration -= delta
		if _brownout_duration <= 0.0:
			_end_brownout()
		return

	if not p.flashlight_on():
		return

	_brownout_timer -= delta
	if _brownout_timer <= 0.0:
		_brownout_timer = Game.rng.randf_range(60.0, 110.0) if is_late else Game.rng.randf_range(110.0, 190.0)
		_trigger_brownout()


func _trigger_brownout() -> void:
	var p := Game.player
	if p == null or not p.flashlight_on():
		return

	_brownout_active = true
	_brownout_duration = 2.8

	# Треск и мерцание фонаря
	Game.audio.play_2d("res://assets/audio/crank_loop.ogg", -4.0, 2.4)
	var fl := p.flashlight

	var tw := create_tween()
	tw.tween_property(fl, "light_energy", 0.3, 0.08)
	tw.tween_property(fl, "light_energy", 2.2, 0.07)
	tw.tween_property(fl, "light_energy", 0.1, 0.09)
	tw.tween_property(fl, "light_energy", 0.0, 0.05)
	await tw.finished

	if not _brownout_active or p == null:
		return

	fl.visible = false
	Game.hud.subtitle(Loc.t(&"sub.flash_flicker"), 2.6)
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", -2.0)
	Game.audio.play_2d("res://assets/audio/heart_loop.ogg", -4.0, 7.0)
	Director.add_tension(18.0, "отказ фонарика в буране")

	# Шаги бегут прямо на игрока в темноте
	var behind := -p.global_transform.basis.z.normalized()
	behind.y = 0.0
	var step_start := p.global_position + behind * 14.0
	var step_end := p.global_position + behind * 2.2

	var step_node := Node3D.new()
	add_child(step_node)
	step_node.global_position = step_start

	var step_tw := create_tween()
	step_tw.tween_property(step_node, "global_position", step_end, 1.8)

	var run := Voice.sfx(&"snow_steps_run")
	if run != "":
		Game.audio.play_3d(run, step_start.lerp(step_end, 0.4), 4.0, 8.0)
		await get_tree().create_timer(1.8, false).timeout
	else:
		for i in range(5):
			await get_tree().create_timer(0.32, false).timeout
			if not is_instance_valid(step_node):
				break
			# Тяжёлые шаги по насту — но не «шаги Ырки»: тот звук — только сигнал Ырки (стадия STALKING).
			Game.audio.play_3d("res://assets/audio/step_snow_%d.ogg" % (1 + i % 3), step_node.global_position, 5.0, 8.0)

	if is_instance_valid(step_node):
		step_node.queue_free()

	_end_brownout()


func _end_brownout() -> void:
	if not _brownout_active:
		return
	_brownout_active = false
	var p := Game.player
	if p != null and p.flashlight != null:
		p.flashlight.visible = Game.flash_charge > 0.5   # севший фонарь «чудом» не загорается
		p.flashlight.light_energy = 2.6
		Game.audio.play_2d("res://assets/audio/clank.ogg", -6.0)
		Game.audio.play_3d("res://assets/audio/gust.ogg", p.global_position, 0.0)


# --- Глаза в чаще (Forest Eyes) ----------------------------------------------

func _process_forest_eyes(delta: float, is_late: bool) -> void:
	var p := Game.player
	if p == null or not Game.is_outside():
		_clear_forest_eyes()
		return

	# Освобождённые узлы нельзя класть в типизированный массив (Godot ругается каждый кадр) — просто отфильтровываем.
	var alive: Array[Node3D] = []
	for i in range(_forest_eyes.size()):
		var e: Variant = _forest_eyes[i]
		if is_instance_valid(e):
			alive.append(e)
	_forest_eyes = alive
	var to_remove: Array[Node3D] = []
	var fading: Array[Node3D] = []
	for eye in _forest_eyes:
		var dist := p.global_position.distance_to(eye.global_position)
		var looking := p.is_looking_at(eye.global_position, 16.0)
		if looking and p.flashlight_on() and dist < 32.0:
			Game.audio.play_3d("res://assets/audio/tree_creak.ogg", eye.global_position, 1.5, 12.0)
			Director.add_tension(6.0, "глаза в чаще")
			Game.hud.subtitle(Loc.t(&"sub.eyes_taiga"), 2.5, 0)
			var tw := create_tween()
			tw.tween_property(eye, "position:x", eye.position.x + 1.2, 0.2)
			tw.tween_property(eye, "scale", Vector3.ZERO, 0.15)
			tw.tween_callback(eye.queue_free)   # гасим после анимации, а не до неё
			fading.append(eye)
		elif dist > 45.0:
			to_remove.append(eye)

	for f in fading:
		_forest_eyes.erase(f)
	for r in to_remove:
		_forest_eyes.erase(r)
		if is_instance_valid(r):
			r.queue_free()

	_eyes_timer -= delta
	if _eyes_timer <= 0.0:
		_eyes_timer = Game.rng.randf_range(25.0, 50.0) if is_late else Game.rng.randf_range(50.0, 95.0)
		if _forest_eyes.size() < 2:   # не больше двух пар: глаза — редкость, а не гирлянда
			_try_spawn_forest_eyes()


func _try_spawn_forest_eyes() -> void:
	if _forest_eyes.size() >= 4:
		return
	var p := Game.player
	if p == null:
		return

	var angle := Game.rng.randf() * TAU
	var dist := Game.rng.randf_range(18.0, 30.0)
	var pos := p.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
	pos.y = Game.rng.randf_range(1.6, 2.4)

	var eye_root := Node3D.new()
	add_child(eye_root)
	eye_root.global_position = pos
	var eye_mat := Palette.glow(&"red")
	var sm := SphereMesh.new()
	sm.radius = 0.032
	sm.height = 0.064

	for side: float in [-0.06, 0.06]:
		var m := MeshInstance3D.new()
		m.mesh = sm
		m.material_override = eye_mat
		m.position = Vector3(side, 0, 0)
		eye_root.add_child(m)

	eye_root.look_at(p.global_position + Vector3(0, 1.6, 0), Vector3.UP)
	Geo.free_after(eye_root, 14.0)   # не заметил — моргнули и пропали
	_forest_eyes.append(eye_root)


func _clear_forest_eyes() -> void:
	for eye in _forest_eyes:
		if is_instance_valid(eye):
			eye.queue_free()
	_forest_eyes.clear()


# --- Шёпот в метели ----------------------------------------------------------

func _process_whispers(delta: float, is_late: bool) -> void:
	# На 1-й ночи тайга молчит — даём игроку спокойно освоиться с базой и приборами без посторонних шёпотов
	if Game.night == 1:
		return
	_whisper_timer -= delta
	if _whisper_timer <= 0.0:
		_whisper_timer = Game.rng.randf_range(110.0, 190.0) if is_late else Game.rng.randf_range(180.0, 280.0)
		var p := Game.player
		if p == null or not Game.is_outside():
			return
		# Шёпот тайги — доносится из глубины леса сквозь буран (30-50 м, не прямо у уха)
		var angle := Game.rng.randf() * TAU
		var pos := p.global_position + Vector3(cos(angle), 0, sin(angle)) * Game.rng.randf_range(30.0, 50.0)
		Game.audio.play_3d("res://assets/audio/whisper.ogg", pos + Vector3(0, 1.8, 0), -6.0, 4.0)
		Game.hud.subtitle(Loc.t(&"sub.whisper_taiga"), 3.2, 0)
		Director.add_tension(8.0, "шёпот в метели")


# --- Сталкеры (Жердяй, Полуночница, Тень) -----------------------------------

func _process_stalkers(delta: float, is_late: bool) -> void:
	if _outdoor_entity != null and is_instance_valid(_outdoor_entity):
		_outdoor_entity_life -= delta
		var p := Game.player
		var dist := p.global_position.distance_to(_outdoor_entity.global_position)
		var looking := p.is_looking_at(_outdoor_entity.global_position + Vector3(0, 1.6, 0), 22.0)

		if not _entity_noticed and looking:
			_entity_noticed = true
			if _outdoor_entity_type == &"zherdyai":
				Game.hud.subtitle(Loc.t(&"sub.zherdyai_close"), 3.5, 0)
				Game.audio.play_3d("res://assets/audio/sub_drop.ogg", _outdoor_entity.global_position + Vector3(0, 2.0, 0), 2.0)
				Director.add_tension(18.0, "жердяй между деревьями")
				Game.add_fatigue(4.0)
			elif _outdoor_entity_type == &"shadow":
				Game.hud.subtitle(Loc.t(&"sub.shadow_watching"), 3.0, 0)
				Director.add_tension(10.0, "силуэт в темноте")

		if _outdoor_entity_type == &"zherdyai":
			# Передвижение только тогда, когда игрок НЕ смотрит (шаги в слепой зоне)
			if not looking:
				_zherdyai_step_timer -= delta
				if _zherdyai_step_timer <= 0.0:
					_zherdyai_step_timer = Game.rng.randf_range(1.8, 3.2)
					if dist > 10.5:
						var dir_to_p := (p.global_position - _outdoor_entity.global_position).normalized()
						dir_to_p.y = 0.0
						_outdoor_entity.global_position += dir_to_p * 2.5
						var look_target := p.global_position
						look_target.y = _outdoor_entity.global_position.y
						_outdoor_entity.look_at(look_target, Vector3.UP)
						Game.audio.play_3d("res://assets/audio/tree_creak.ogg", _outdoor_entity.global_position, -8.0)
			if (looking and p.flashlight_on()) or dist < 8.5 or _outdoor_entity_life <= 0.0:
				_dismiss_zherdyai()
				return
		elif _outdoor_entity_type == &"shadow":
			# Тень тоже подходит, только пока на неё не смотрят: отвернулся — она на пару шагов ближе,
			# и под ней хрустит наст. Обернёшься — стоит, как стояла.
			if not looking:
				_zherdyai_step_timer -= delta
				if _zherdyai_step_timer <= 0.0:
					_zherdyai_step_timer = Game.rng.randf_range(1.4, 2.6)
					if dist > 9.0:
						var dir_s := (p.global_position - _outdoor_entity.global_position)
						dir_s.y = 0.0
						_outdoor_entity.global_position += dir_s.normalized() * 1.4
						var lt := p.global_position
						lt.y = _outdoor_entity.global_position.y
						_outdoor_entity.look_at(lt, Vector3.UP)
						Game.audio.play_3d("res://assets/sfx/cc0/step_crust_%d.ogg" % Game.rng.randi_range(1, 3), _outdoor_entity.global_position, -6.0)
			if (looking and dist < 14.0) or dist < 8.0 or _outdoor_entity_life <= 0.0:
				_clear_outdoor_entity()
				return
		return

	_outdoor_stalker_timer -= delta
	if _outdoor_stalker_timer <= 0.0:
		_outdoor_stalker_timer = Game.rng.randf_range(80.0, 140.0) if is_late else Game.rng.randf_range(130.0, 210.0)
		_try_spawn_outdoor_entity()


func _try_spawn_outdoor_entity() -> void:
	var p := Game.player
	if p == null or not Game.is_outside():
		return
	if Game.yrka != null and Game.yrka.stage == YrkaThreat.Stage.CHASE:
		return
	if Director.in_calm_window():
		return

	var p_pos := p.global_position
	var cam_fwd := -p.camera.global_basis.z if p.camera != null else -p.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized() if cam_fwd.length_squared() > 0.01 else Vector3.FORWARD

	# Периферийный Жердяй: сначала пробуем поставить точно на краю поля зрения (28–48° между верхушками елей)
	if Game.rng.randf() < 0.65:
		var side := -1.0 if Game.rng.randf() < 0.5 else 1.0
		var ang := deg_to_rad(side * Game.rng.randf_range(28.0, 48.0))
		var periph_dir := cam_fwd.rotated(Vector3.UP, ang)
		var periph_pt := p_pos + periph_dir * Game.rng.randf_range(24.0, 38.0)
		periph_pt.y = Terrain.height(periph_pt.x, periph_pt.z)
		if Game.level != null and not Game.level.is_pos_inside_house(periph_pt):
			_spawn_outdoor_entity(&"zherdyai", periph_pt)
			return

	var spawn_candidates: Array[Dictionary] = [
		{"type": &"zherdyai", "pos": Vector3(45.0, 0.0, -28.0), "min_night": 1}, # опушка за метео
		{"type": &"zherdyai", "pos": Vector3(26.0, 0.0, -38.0), "min_night": 1}, # деревья у мачты
		{"type": &"zherdyai", "pos": Vector3(44.0, 0.0, 22.0),  "min_night": 2}, # за сараем ГСМ
		{"type": &"zherdyai", "pos": Vector3(8.0, 0.0, -18.0),  "min_night": 2}, # у старой тропы к избе
		{"type": &"shadow",   "pos": Vector3(20.0, 0.0, 8.0),   "min_night": 1}, # развилка
		{"type": &"shadow",   "pos": Vector3(34.0, 0.0, -12.0), "min_night": 1}, # метеоплощадка
	]
	spawn_candidates.shuffle()
	for cand: Dictionary in spawn_candidates:
		if Game.night < int(cand["min_night"]):
			continue
		var pt: Vector3 = cand["pos"]
		var dist := p_pos.distance_to(pt)
		# Жердяй не подходит: его видно только издалека, между стволами
		var near := 22.0 if cand["type"] == &"zherdyai" else 10.0
		var far := 70.0 if cand["type"] == &"zherdyai" else 35.0
		if dist >= near and dist <= far:
			_spawn_outdoor_entity(cand["type"], pt)
			break


func _spawn_outdoor_entity(type: StringName, pt: Vector3) -> void:
	_clear_outdoor_entity()
	_entity_noticed = false
	var p := Game.player
	var rig: CreatureRig = null
	if type == &"zherdyai":
		rig = Creatures.make_zherdyai(0.0 if Game.rng.randf() < 0.6 else 45.0)
		_outdoor_entity_life = 16.0
	elif type == &"shadow":
		rig = Creatures.make_silhouette()
		_outdoor_entity_life = 12.0

	if rig != null:
		add_child(rig)
		rig.global_position = pt
		if p != null:
			var look_target := p.global_position
			look_target.y = 0.0
			rig.look_at(look_target, Vector3.UP)
		_outdoor_entity = rig
		_outdoor_entity_type = type


var _zherdyai_dismissing := false


## Периферийный Жердяй в 12 FPS: при повороте взгляда не скользит плавно, а делает рваные step-motion шаги за ствол ели.
func _dismiss_zherdyai() -> void:
	if _zherdyai_dismissing or _outdoor_entity == null or not is_instance_valid(_outdoor_entity):
		return
	_zherdyai_dismissing = true
	var ent := _outdoor_entity
	var start_pos := ent.global_position
	Game.audio.play_3d("res://assets/audio/tree_creak.ogg", start_pos, 2.0, 18.0)
	var side_dir := ent.global_basis.x * (1.0 if Game.rng.randf() < 0.5 else -1.0)
	var retreat_vec := side_dir * 3.8 + ent.global_basis.z * 5.2
	# 9 рваных кадров по 0.083 с (= 12 FPS uncanny valley)
	for step_i in range(9):
		if not is_instance_valid(ent):
			break
		var k := float(step_i + 1) / 9.0
		var next_p := start_pos + retreat_vec * (k * k)
		next_p.y = Terrain.height(next_p.x, next_p.z)
		ent.global_position = next_p
		ent.rotation.z = deg_to_rad(14.0 if step_i % 2 == 0 else -11.0)
		await get_tree().create_timer(0.083, false).timeout
	_zherdyai_dismissing = false
	_clear_outdoor_entity()


func _clear_outdoor_entity() -> void:
	if _outdoor_entity != null and is_instance_valid(_outdoor_entity):
		_outdoor_entity.queue_free()
	_outdoor_entity = null
	_outdoor_entity_type = &""
	_outdoor_entity_life = 0.0
	_entity_noticed = false


func _trigger_ambient_outdoor_audio() -> void:
	var p := Game.player
	if p == null or not Game.is_outside():
		return
	var roll := Game.rng.randi_range(0, 4)
	match roll:
		0:
			var angle := Game.rng.randf() * TAU
			var pos := p.global_position + Vector3(cos(angle), 0, sin(angle)) * Game.rng.randf_range(40.0, 65.0)
			Game.audio.play_3d("res://assets/audio/wolf_howl.ogg", pos, 2.0, 25.0)
			Director.add_tension(5.0, "вой волков")
		1:
			var angle := Game.rng.randf() * TAU
			var pos := p.global_position + Vector3(cos(angle), 0, sin(angle)) * Game.rng.randf_range(15.0, 30.0)
			Game.audio.play_3d("res://assets/audio/tree_creak.ogg", pos, 1.5, 10.0)
		2:
			# Далёкий глухой стон сосен в метели (вместо навязчивого дыхания прямо в ухо)
			var angle := Game.rng.randf() * TAU
			var pos := p.global_position + Vector3(cos(angle), 0, sin(angle)) * Game.rng.randf_range(25.0, 45.0)
			var creak := Voice.sfx_or(&"tree_creak", "res://assets/audio/tree_creak.ogg")
			Game.audio.play_3d(creak, pos, 0.0, 8.0)
			Director.add_tension(4.0, "скрип в чаще")
		3:
			# Шаги вдалеке на снегу
			var side := p.global_basis.x.normalized() * (1.0 if Game.rng.randf() < 0.5 else -1.0)
			var pos := p.global_position + side * Game.rng.randf_range(14.0, 24.0)
			Game.audio.play_snow_steps(pos, Game.rng.randi_range(3, 5), -2.0, 6.0, 0.9, p.global_basis.z)
			Director.add_tension(6.0, "шаги на снегу")
		4:
			# Рык вдалеке в глухой чаще (на расстоянии 35-55 м, а не в метре от игрока)
			var angle := Game.rng.randf() * TAU
			var pos := p.global_position + Vector3(cos(angle), 0, sin(angle)) * Game.rng.randf_range(35.0, 55.0)
			Game.audio.play_3d("res://assets/audio/growl.ogg", pos, -4.0, 5.0)
			Director.add_tension(8.0, "рык из сугробов")


func _build_backyard_features() -> void:
	# 1. Таёжный ледник-погреб с вытяжкой и замком (сдвинут от стены кладовой к новой тропе; пар включается только аномалией cellar_steam)
	var cellar_pos := Vector3(4.8, Terrain.height(4.8, -9.0), -9.0)
	cellar_prop = Props.ice_cellar()
	cellar_prop.position = cellar_pos
	cellar_prop.rotation.y = deg_to_rad(36.0)
	add_child(cellar_prop)

	var cellar_col := Geo.collider(self, Vector3(1.65, 0.75, 1.9), cellar_pos + Vector3(0, 0.38, 0))
	cellar_col.rotation.y = deg_to_rad(36.0)

	var cellar_it := Geo.interactable(self, Vector3(1.8, 1.1, 2.0), cellar_pos + Vector3(0, 0.55, 0), null, "", func(_p: Player) -> void:
		if not SaveGame.flags.get("cellar_searched", false):
			SaveGame.flags["cellar_searched"] = true
			Game.add_spare_flares(1)
			Game.audio.play_3d(CLANK_SOUND, cellar_pos + Vector3(0, 0.4, 0), 0.0)
			Game.hud.subtitle(Loc.t(&"sub.cellar_open"), 5.0)
		else:
			Game.hud.subtitle(Loc.t(&"sub.cellar_empty"), 2.5)
	)
	cellar_it.prompt_provider = func() -> String:
		return Loc.t(&"sub.cellar_empty") if SaveGame.flags.get("cellar_searched", false) else Loc.t(&"it.cellar")
	cellar_it.name = "CellarHatch"

	# 2. Следы босых ног и когтей под северным окном радиорубки (X=9.2, Z=-2.7)
	var track_pts: Array[Vector3] = [
		Vector3(9.05, 0.01, -2.6),
		Vector3(9.35, 0.01, -2.6),
		Vector3(8.95, 0.01, -3.2),
		Vector3(9.45, 0.01, -3.2),
		Vector3(9.1, 0.01, -4.0),
		Vector3(9.3, 0.01, -4.0)
	]
	for i in track_pts.size():      # настоящие отпечатки босых ступней носками к окну (были чёрные плашки)
		var tp: Vector3 = track_pts[i]
		add_child(Footprints.make(&"bare", Vector3(tp.x, 0.0, tp.z), 0.0, i % 2 == 0))

	var tracks_it := Geo.interactable(self, Vector3(1.5, 0.8, 1.5), Vector3(9.2, 0.4, -2.7), null, Loc.t(&"it.window_tracks"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.window_tracks"), 4.5)
		Director.add_tension(8.0, "следы под окном")
	)
	tracks_it.collision_layer = Geo.LAYER_INTERACT   # зона «осмотреть» на тропе — не стена: [E] видит, игрок проходит
	tracks_it.name = "WindowTracks"
	tracks_it.collision_layer = Geo.LAYER_INTERACT

	# 3. Наружная деревянная лестница на западном бревенчатом фасаде жилой комнаты (приставлена к глухой стене на Z=4.85, не закрывая окно)
	var west_ladder := Props.ladder(3.8)
	west_ladder.position = Vector3(-2.68, 0.0, 4.85)
	west_ladder.rotation.y = deg_to_rad(90.0)
	add_child(west_ladder)


# --- Опоры ЛЭП и воздушная линия электропередач (Grid) -------------------------

func _build_utility_grid() -> void:
	# Координаты опор ЛЭП (Трасса: Дизельная -> Развилка -> Дом, с ответвлением на Мачту)
	var pole_shed_pos := Vector3(43.0, 0.0, 27.0)
	var pole_trail_pos := Vector3(31.0, 0.0, 16.0)
	var pole_junc_pos := Vector3(19.0, 0.0, 7.5)
	var house_entry_pos := Vector3(14.2, 3.6, 4.2)
	var shed_exit_pos := SHED + Vector3(-2.8, 3.4, 0.0)

	var pole_mast_1 := Vector3(22.0, 0.0, -8.0)
	var pole_mast_2 := Vector3(24.5, 0.0, -32.0)
	var mast_entry_pos := MAST + Vector3(1.0, 2.4, -0.6)

	# Траверса каждой опоры стоит поперёк линии: направление берём по соседним точкам трассы
	var poles := {
		"shed": [pole_shed_pos, pole_trail_pos - shed_exit_pos],
		"trail": [pole_trail_pos, pole_junc_pos - pole_shed_pos],
		"junc": [pole_junc_pos, house_entry_pos - pole_trail_pos],
		"mast1": [pole_mast_1, pole_mast_2 - pole_junc_pos],
		"mast2": [pole_mast_2, mast_entry_pos - pole_mast_1],
	}
	var wires := {}
	for id: String in poles:
		var pp: Vector3 = poles[id][0]
		var d: Vector3 = poles[id][1]
		d.y = 0.0
		var perp := Vector3(-d.z, 0.0, d.x).normalized()
		var yaw := atan2(-perp.z, perp.x)
		var pole := Props.utility_pole(5.4)
		pole.position = pp
		pole.rotation.y = yaw
		pole.rotation.x = deg_to_rad(sin(pp.x * 0.7 + pp.z * 1.3) * 4.5)
		pole.rotation.z = deg_to_rad(cos(pp.x * 1.1 - pp.z * 0.9) * 4.0)
		add_child(pole)
		var pts := Props.pole_wire_points(5.4)
		var basis := Basis(Vector3.UP, yaw)
		wires[id] = [pole.position + basis * pts[0], pole.position + basis * pts[1]]

	# Провисающие парные провода: от изолятора к изолятору, у зданий — к вводным изоляторам
	_build_catenary_wire(_entry_pair(shed_exit_pos, pole_shed_pos), wires["shed"], 0.35)
	_build_catenary_wire(wires["shed"], wires["trail"], 0.55)
	_build_catenary_wire(wires["trail"], wires["junc"], 0.55)
	_build_catenary_wire(wires["junc"], _entry_pair(house_entry_pos, pole_junc_pos), 0.35)
	# Ответвление на радиомачту
	_build_catenary_wire(wires["junc"], wires["mast1"], 0.60)
	_build_catenary_wire(wires["mast1"], wires["mast2"], 0.65)
	_build_catenary_wire(wires["mast2"], _entry_pair(mast_entry_pos, pole_mast_2), 0.45)

	# Звук гудения проводов на ветру на центральной опоре
	var wind_sound := AudioStreamPlayer3D.new()
	wind_sound.stream = AudioDirector.cached_stream("res://assets/audio/tree_creak.ogg")
	wind_sound.position = pole_trail_pos + Vector3(0, 3.5, 0)
	wind_sound.unit_size = 6.0
	wind_sound.max_distance = 18.0
	wind_sound.volume_db = -14.0
	wind_sound.bus = &"SFX"
	add_child(wind_sound)


## Две точки ввода у стены/мачты: рядом друг с другом, поперёк направления на опору.
func _entry_pair(entry: Vector3, from_pole: Vector3) -> Array:
	var d := entry - from_pole
	d.y = 0.0
	var side := Vector3(-d.z, 0.0, d.x).normalized() * 0.3
	return [entry - side, entry + side]


func _build_catenary_wire(a: Array, b: Array, sag: float) -> void:
	var k := MeshKit.new(12)
	var wire_col := Color(0.10, 0.10, 0.11)
	var count := 10
	# Крест-накрест не тянем: берём пару с меньшей суммарной длиной
	var straight: float = (a[0] as Vector3).distance_to(b[0]) + (a[1] as Vector3).distance_to(b[1])
	var crossed: float = (a[0] as Vector3).distance_to(b[1]) + (a[1] as Vector3).distance_to(b[0])
	var pairs: Array = [[a[0], b[0]], [a[1], b[1]]] if straight <= crossed else [[a[0], b[1]], [a[1], b[0]]]
	for pr: Array in pairs:
		var p1: Vector3 = pr[0]
		var p2: Vector3 = pr[1]
		var sag_actual := sag * clampf(p1.distance_to(p2) / 14.0, 0.4, 1.4)
		var pts: PackedVector3Array = []
		for i in range(count):
			var t := float(i) / float(count - 1)
			pts.append(p1.lerp(p2, t) - Vector3(0, sag_actual * 4.0 * t * (1.0 - t), 0))
		k.tube(pts, [0.016], wire_col, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wire_col
	mat.roughness = 0.8
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Снегозадерживающие щиты (Snowbreak Fences) --------------------------------

func _build_snow_fences() -> void:
	# Ряд 1: Вдоль открытого продуваемого поля севернее тропы к метеоплощадке (не блокирует тропу и леер)
	var row1_pts: Array[Vector3] = [
		Vector3(34.0, 0.0, -20.0),
		Vector3(36.4, 0.0, -21.7),
		Vector3(38.8, 0.0, -23.4)
	]
	var yaw1 := deg_to_rad(-35.0)
	for i in range(row1_pts.size()):
		var p: Vector3 = row1_pts[i]
		var fence := Props.snow_fence(2.6, 1.7)
		fence.position = p
		fence.rotation.y = yaw1
		add_child(fence)

	var it1 := Geo.interactable(self, Vector3(2.2, 1.6, 2.2), Vector3(36.4, 0.8, -21.7), null, Loc.t(&"it.snow_fence"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.snow_fence"), 4.5)
	)
	it1.name = "SnowFenceMeteo"

	# Ряд 2: Вдоль северо-западной границы поляны у сарая ГСМ (в стороне от тропы)
	var row2_pts: Array[Vector3] = [
		Vector3(42.0, 0.0, 16.0),
		Vector3(44.3, 0.0, 18.0)
	]
	var yaw2 := deg_to_rad(40.0)
	for p in row2_pts:
		var fence := Props.snow_fence(2.6, 1.7)
		fence.position = p
		fence.rotation.y = yaw2
		add_child(fence)


# --- Бочковое поле ГСМ (Fuel Drum Field) --------------------------------------

func _build_fuel_drum_field() -> void:
	var base_pos := SHED + Vector3(0.5, 0.0, -4.8)

	# 1. Деревянный настил / поддоны под бочки
	Geo.block(self, Vector3(3.2, 0.10, 2.4), base_pos + Vector3(1.1, 0.05, 0.8), Palette.m(&"wood"), false)

	# 2. Ряды стоящих 200-литровых бочек с соляркой
	var upright_coords: Array[Vector3] = [
		Vector3(0.0, 0.1, 0.0),
		Vector3(0.75, 0.1, 0.0),
		Vector3(1.50, 0.1, 0.0),
		Vector3(2.25, 0.1, 0.0),
		Vector3(0.35, 0.1, 0.75),
		Vector3(1.10, 0.1, 0.75),
		Vector3(1.85, 0.1, 0.75),
		Vector3(0.0, 0.1, 1.50),
		Vector3(0.75, 0.1, 1.50),
		Vector3(1.50, 0.1, 1.50)
	]
	for off in upright_coords:
		var b_pos := base_pos + off
		var is_open := (off.x > 1.4 and off.z > 1.0)
		var model_id := "survival/barrel-open" if is_open else "survival/barrel"
		Models.spawn(self, model_id, b_pos, Game.rng.randf_range(-15.0, 15.0), 0.95, {
			"collide": true,
			"tint": Color(0.55, 0.28, 0.22) if Game.rng.randf() < 0.6 else Color(0.28, 0.35, 0.42)
		})

	# 3. Поваленные пустые бочки на боку
	var fallen_coords: Array[Vector3] = [
		Vector3(-0.8, 0.1, 0.5),
		Vector3(2.5, 0.1, 0.9)
	]
	for off in fallen_coords:
		var f_pos := base_pos + off
		Models.spawn(self, "survival/barrel", f_pos, Game.rng.randf_range(30.0, 60.0), 0.95, {
			"collide": true,
			"tilt": Vector3(85.0, 0, 0),
			"tint": Color(0.35, 0.32, 0.30)
		})

	# 4. Деревянный ящик с ЗИПом и запасные доски
	Models.spawn(self, "survival/box-large", base_pos + Vector3(2.6, 0.0, -0.4), 12.0, 0.65, {"collide": true})
	Models.spawn(self, "survival/resource-planks", base_pos + Vector3(-0.6, 0.0, 1.8), -20.0, 0.40, {"collide": true})

	# 5. Интерактивная точка осмотра бочкового поля
	var drum_it := Geo.interactable(self, Vector3(2.5, 1.2, 2.5), base_pos + Vector3(1.1, 0.6, 0.8), null, Loc.t(&"it.fuel_barrels"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.fuel_barrels"), 4.5)
	)
	drum_it.name = "FuelDrumField"


# --- Заброшенные сани экспедиции (Expedition Sledge) --------------------------

func _build_expedition_cart() -> void:
	var cart_pos := Vector3(8.0, 0.0, 21.0)

	var sledge := Props.surveyor_sledge()
	sledge.position = cart_pos
	sledge.rotation.y = deg_to_rad(28.0)
	add_child(sledge)

	var cart_it := Geo.interactable(self, Vector3(2.4, 1.4, 3.2), cart_pos + Vector3(0.0, 0.7, 0.0), null, Loc.t(&"it.expedition_cart"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.expedition_cart"), 5.0)
	)
	cart_it.name = "ExpeditionCart"


# --- Природные ориентиры тайги (Boulders, Stumps, Logs) -----------------------

func _build_taiga_landmarks() -> void:
	# 1. Заснеженный валун на открытом снежном гребне между домом и мачтой (вдали от построек и троп)
	var rock1_pos := Vector3(29.5, 0.0, -27.0)   # был (27, -26): коллизия 4×5 м задевала тропу к мачте
	Models.spawn(self, "nature/rock_largeA", rock1_pos, 42.0, 1.35, {
		"collide": true,
		"tint": Color(0.48, 0.52, 0.55)
	})
	Models.spawn(self, "nature/rock_smallA", rock1_pos + Vector3(1.2, 0.0, 0.8), -30.0, 0.55)

	# 2. Каменная гряда у восточной кромки тайги
	var rock2_pos := Vector3(52.0, 0.0, 1.0)   # был (45, 8) — прямо на вертодроме, вертолёт садился в камень
	Models.spawn(self, "nature/rock_largeC", rock2_pos, 110.0, 1.35, {
		"collide": true,
		"tint": Color(0.50, 0.50, 0.52)
	})
	Models.spawn(self, "nature/rock_smallC", rock2_pos + Vector3(-0.9, 0.0, 0.6), 15.0, 0.6)

	# 3. Поваленный ствол сосны в глубоком лесу за поленницей
	var log1_pos := Vector3(-6.0, 0.0, 41.0)   # был (-8, 36) — поперёк тропы к озеру
	Models.spawn(self, "nature/log_large", log1_pos, -45.0, 0.85, {
		"collide": true,
		"tint": Color(0.45, 0.40, 0.35)
	})

	# 4. Могучий замшелый пень на опушке у метеоплощадки
	var stump_pos := Vector3(47.0, 0.0, -16.0)
	Models.spawn(self, "nature/stump_oldTall", stump_pos, 65.0, 1.45, {
		"collide": true,
		"tint": Color(0.42, 0.36, 0.30)
	})
	Models.spawn(self, "nature/rock_smallA", stump_pos + Vector3(1.1, 0.0, -0.7), -10.0, 0.5)


func _build_frozen_hunter() -> void:
	# Вековая ель на опушке между домом и мачтой
	var spruce: Node3D = Props.spruce(11.5)
	spruce.position = HUNTER_SPRUCE_POS
	add_child(spruce)

	# Выбор позы по дням (0: День 1-2, 1: День 3, 2: День 4, 3: Ночь 4/День 5/пропал)
	var pose := 0
	if Game.phase_index in [4, 5]:
		pose = 1
	elif Game.phase_index in [6, 7]:
		pose = 2
	elif Game.phase_index >= 8:
		pose = 3

	var hunter := Creatures.make_frozen_hunter(pose)
	hunter.position = HUNTER_SPRUCE_POS + Vector3(0.1, 0.0, 0.6)
	hunter.rotation.y = deg_to_rad(15.0)
	add_child(hunter)
	_frozen_hunter_node = hunter

	if pose < 3:
		# Тело охотника
		var h_it := Geo.interactable(self, Vector3(1.1, 1.3, 1.1), HUNTER_SPRUCE_POS + Vector3(0.1, 0.6, 0.6), null, Loc.t(&"it.frozen_hunter"), func(_p: Player) -> void:
			var sub_key := &"sub.hunter_pose_0"
			if pose == 1:
				sub_key = &"sub.hunter_pose_1"
			elif pose == 2:
				sub_key = &"sub.hunter_pose_2"
			Game.hud.subtitle(Loc.t(sub_key), 4.5)
			Director.add_tension(6.0, "осмотр замёрзшего охотника")
		)
		h_it.name = "FrozenHunterBody"

		# Записка на бересте в кармане тулупа
		var note_it := Geo.interactable(self, Vector3(0.4, 0.4, 0.4), HUNTER_SPRUCE_POS + Vector3(-0.25, 0.75, 0.7), Palette.m(&"paper"), Loc.t(&"it.hunter_note"), func(p: Player) -> void:
			Game.hud.show_note(Loc.t(&"note.hunter"))
			p.mode = Player.Mode.READING
			Director.add_tension(4.0, "берестяная записка охотника")
		)
		note_it.name = "HunterNote"

		# Компас Адрианова в кармане/на поясе
		if not Game.has_flag("hunter_compass_taken"):
			var comp_it: Interactable = null
			comp_it = Geo.interactable(self, Vector3(0.35, 0.35, 0.35), HUNTER_SPRUCE_POS + Vector3(0.32, 0.55, 0.65), Palette.m(&"metal"), Loc.t(&"it.hunter_compass"), func(_p: Player) -> void:
				if Game.has_flag("hunter_compass_taken"):
					return
				Game.set_flag("hunter_compass_taken", true)
				Game.hud.subtitle(Loc.t(&"sub.hunter_compass"), 4.0)
				Game.audio.play_3d(CLANK_SOUND, HUNTER_SPRUCE_POS, 0.0)
				if is_instance_valid(comp_it):
					comp_it.queue_free()
			)
			comp_it.name = "HunterCompass"
	else:
		# Пустое место со следами и палками
		var tr_it := Geo.interactable(self, Vector3(1.4, 0.6, 1.4), HUNTER_SPRUCE_POS + Vector3(0.1, 0.3, 0.8), null, Loc.t(&"it.hunter_tracks"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.hunter_pose_3"), 5.0)
			Director.add_tension(14.0, "следы пропавшего охотника")
		)
		tr_it.collision_layer = Geo.LAYER_INTERACT   # зона «осмотреть» на тропе — не стена: [E] видит, игрок проходит
		tr_it.name = "HunterTracks"


# --- Снегомерный маршрут и вылазки по тайге Семёнова ---------------------------

var _stalk_timer := 14.0


func _build_snow_survey_route() -> void:
	# Точка 1 (День 2): Северный склон сопки (триангуляционный знак + жестянка + веха №1)
	var p1 := Vector3(14.0, 0.0, -70.0)
	var tower := Props.triangulation_tower()
	tower.position = p1
	add_child(tower)

	var stake1 := Props.survey_stake()
	stake1.position = p1 + Vector3(-2.2, 0.0, 1.4)
	add_child(stake1)

	var it_stake1 := Geo.interactable(self, Vector3(0.9, 2.2, 0.9), p1 + Vector3(-2.2, 1.1, 1.4), null, "", func(_p: Player) -> void:
		_on_survey_stake_used(1, p1 + Vector3(-2.2, 1.0, 1.4))
	)
	it_stake1.prompt_provider = func() -> String:
		return Loc.t(&"it.survey_stake_done") if Game.has_flag("survey_stake_1") else Loc.t(&"it.survey_stake")

	var _tin_it := Geo.interactable(self, Vector3(0.6, 0.6, 0.6), p1 + Vector3(2.0, 1.45, 0.6), null, Loc.t(&"it.tin_box"), func(_p: Player) -> void:
		if Game.has_flag("tin_box_taken"):
			return
		Game.set_flag("tin_box_taken", true)
		Game.add_spare_flares(2)
		Game.hud.subtitle(Loc.t(&"sub.tin_box_loot"), 6.0)
		Game.audio.play_3d(CLANK_SOUND, p1 + Vector3(2.0, 1.45, 0.6), -2.0)
		Director.add_tension(8.0, "жестянка с ракетами")
	)

	# Точка 2 (День 3): Северо-восток у кедрача (охотничий лабаз на сваях + когти + веха №2)
	var p2 := Vector3(56.0, 0.0, -52.0)
	var shed := Props.storage_cache_shed()
	shed.position = p2
	add_child(shed)

	var stake2 := Props.survey_stake()
	stake2.position = p2 + Vector3(-2.4, 0.0, 1.8)
	add_child(stake2)

	var it_stake2 := Geo.interactable(self, Vector3(0.9, 2.2, 0.9), p2 + Vector3(-2.4, 1.1, 1.8), null, "", func(_p: Player) -> void:
		_on_survey_stake_used(2, p2 + Vector3(-2.4, 1.0, 1.8))
	)
	it_stake2.prompt_provider = func() -> String:
		return Loc.t(&"it.survey_stake_done") if Game.has_flag("survey_stake_2") else Loc.t(&"it.survey_stake")

	var _labaz_it := Geo.interactable(self, Vector3(0.9, 1.8, 0.9), p2 + Vector3(1.0, 2.6, -0.75), null, Loc.t(&"it.labaz_scratch"), func(_p: Player) -> void:
		if Game.has_flag("labaz_scratch_inspected"):
			return
		Game.set_flag("labaz_scratch_inspected", true)
		Game.hud.subtitle(Loc.t(&"sub.labaz_loot"), 6.5)
		Director.add_tension(15.0, "следы когтей на лабазе")
	)

	# Точка 3 (День 4): Северо-западный распадок (полуземлянка геодезистов + зольник буржуйки + веха №3)
	var p3 := Vector3(-55.0, 0.0, -58.0)
	var dugout := Props.hunter_dugout()
	dugout.position = p3
	add_child(dugout)

	var stake3 := Props.survey_stake()
	stake3.position = p3 + Vector3(2.5, 0.0, 1.6)
	add_child(stake3)

	var it_stake3 := Geo.interactable(self, Vector3(0.9, 2.2, 0.9), p3 + Vector3(2.5, 1.1, 1.6), null, "", func(_p: Player) -> void:
		_on_survey_stake_used(3, p3 + Vector3(2.5, 1.0, 1.6))
	)
	it_stake3.prompt_provider = func() -> String:
		return Loc.t(&"it.survey_stake_done") if Game.has_flag("survey_stake_3") else Loc.t(&"it.survey_stake")

	var _dugout_it := Geo.interactable(self, Vector3(0.8, 0.8, 0.8), p3 + Vector3(0.4, 0.4, 0.1), null, Loc.t(&"it.dugout_stove"), func(_p: Player) -> void:
		if Game.has_flag("dugout_stove_inspected"):
			return
		Game.set_flag("dugout_stove_inspected", true)
		Game.hud.subtitle(Loc.t(&"sub.dugout_loot"), 7.0)
		Director.add_tension(18.0, "документы Отзвук")
	)


func _on_survey_stake_used(stake_idx: int, stake_pos: Vector3) -> void:
	if not Game.has_item(&"vs43"):
		Game.hud.subtitle(Loc.t(&"sub.need_vs43"), 4.0)
		return
	var flag := "survey_stake_%d" % stake_idx
	if Game.has_flag(flag):
		Game.hud.subtitle(Loc.t(&"it.survey_stake_done"), 3.0)
		return
	Game.set_flag(flag, true)
	if FieldJobs.survey_done():
		FieldJobs.on_survey_done(stake_pos)
	Game.audio.play_3d(CLANK_SOUND, stake_pos, -2.0)
	Game.audio.play_3d("res://assets/audio/snow_fall.ogg", stake_pos, -4.0)
	var sub_key := StringName("sub.snow_measured_%d" % stake_idx)
	Game.hud.subtitle(Loc.t(sub_key), 6.0)
	Director.add_tension(10.0, "замер вехи снегомером")


func _process_snow_survey_stalking(delta: float) -> void:
	if not Game.is_day() or Game.player == null:
		return
	# После 16:15 (минута 135) опускаются синие полярные сумерки
	if Game.shift_minutes >= 135.0:
		var p_pos := Game.player.global_position
		# Если игрок в тайге на маршруте (> 38м от станции)
		if p_pos.distance_to(Vector3.ZERO) > 38.0:
			_stalk_timer -= delta
			if _stalk_timer <= 0.0:
				_stalk_timer = randf_range(16.0, 26.0)
				var behind := p_pos + Game.player.global_transform.basis.z * randf_range(11.0, 16.0)
				Game.audio.play_3d("res://assets/audio/step_snow_1.ogg", behind, -2.0, 5.0)
				Game.audio.play_3d("res://assets/audio/tree_creak.ogg", behind + Vector3(2.0, 0, 0), -6.0, 4.0)
				Game.hud.subtitle(Loc.t(&"sub.stalking_steps"), 3.0)
				Director.add_tension(15.0, "преследование по лыжне")


const HELIPAD := Vector3(44.0, 0.0, 6.0)

var _helipad_drift: Interactable
var _heli_node: Node3D
var _heli_audio: AudioStreamPlayer3D
var _heli_crate_it: Interactable
var _heli_evac_it: Interactable
var _heli_searchlight: SpotLight3D
var _heli_dust: CPUParticles3D
var _mi8_crash_fx_done := false
var _mi8_crash_timer := -1.0
var _mi8_supply_flyby_done := false


func _build_helipad() -> void:
	# 1. Четыре угловые вешки границ посадочной площадки
	var corners := [
		HELIPAD + Vector3(-5.0, 0, -5.0),
		HELIPAD + Vector3(5.0, 0, -5.0),
		HELIPAD + Vector3(-5.0, 0, 5.0),
		HELIPAD + Vector3(5.0, 0, 5.0)
	]
	for c_pos in corners:
		var st := Props.survey_stake()
		st.position = c_pos
		add_child(st)

	# 1б. Обвязка площадки — модель (yard_props.py helipad_kit): колдун, шины, фонари, бочки с помпой
	if Models.spawn(self, "kedr/helipad_kit", HELIPAD, 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.1, "sat": 1.0}) != null:
		var hp_col := StaticBody3D.new()
		hp_col.collision_layer = Geo.LAYER_WORLD
		hp_col.position = HELIPAD
		add_child(hp_col)
		hp_col.add_child(Geo.box_shape(Vector3(1.7, 1.0, 1.2), Vector3(-7.2, 0.5, 4.0)))
		hp_col.add_child(Geo.box_shape(Vector3(0.2, 6.0, 0.2), Vector3(6.8, 3.0, -6.8)))

	# 2. Деревянный посадочный крест 8х8 метров
	var cross_a := Geo.box_mesh(Vector3(8.0, 0.04, 1.2), Palette.m(&"wood"))
	cross_a.position = HELIPAD + Vector3(0, 0.02, 0)
	add_child(cross_a)
	var cross_b := Geo.box_mesh(Vector3(1.2, 0.04, 8.0), Palette.m(&"wood"))
	cross_b.position = HELIPAD + Vector3(0, 0.02, 0)
	add_child(cross_b)
	cross_a.visible = Game.helipad_cleared
	cross_b.visible = Game.helipad_cleared

	# 3. Сугроб над крестом вертодрома (только пока не расчищено)
	if not Game.helipad_cleared:
		var mound := Props.snow_mound_mesh(2)
		var drift_mesh := MeshInstance3D.new()
		drift_mesh.mesh = mound
		drift_mesh.material_override = Palette.m(&"drift")
		drift_mesh.position = HELIPAD + Vector3(0, 0.04, 0)
		drift_mesh.scale = Vector3(3.6, 0.42, 3.4)
		add_child(drift_mesh)
		for e: Array in [[Vector3(0.35, 0.55, -0.2), Vector3(0.45, 0.6, 0.35)], [Vector3(-0.3, 0.5, 0.3), Vector3(0.4, 0.55, 0.3)], [Vector3(0.05, 0.62, 0.05), Vector3(0.3, 0.5, 0.45)]]:
			var lump := MeshInstance3D.new()
			lump.mesh = mound
			lump.material_override = Palette.m(&"drift")
			lump.position = e[0]
			lump.scale = e[1]
			drift_mesh.add_child(lump)

		var drift_it := Geo.interactable(self, Vector3(6.4, 0.7, 6.0), HELIPAD + Vector3(0, 0.35, 0), null, "", func(_p: Player) -> void:
			Game.helipad_cleared = true
			drift_mesh.visible = false
			cross_a.visible = true
			cross_b.visible = true
			Game.hud.subtitle(Loc.t(&"sub.helipad_ready"), 4.0)
			Game.audio.play_3d("res://assets/audio/snow_fall.ogg", HELIPAD, 0.0)
			_helipad_drift.collision_layer = 0
			_build_helipad_heli()
		)
		drift_it.prompt_provider = func() -> String:
			return "" if Game.helipad_cleared else Loc.t(&"task.helipad_prep")
		_helipad_drift = drift_it

	# 4. Посадочные жаровни (по углам периметра площадки, не загромождают тропу подхода)
	var pot_offsets: Array[Vector3] = [
		Vector3(-6.2, 0.0, -6.2),
		Vector3(6.2, 0.0, -6.2),
		Vector3(-6.2, 0.0, 6.2),
		Vector3(6.2, 0.0, 6.2)
	]
	var saved_pots_all := bool(SaveGame.flags.get("helipad_pots_all_lit", false))
	var saved_pots_cnt := int(SaveGame.flags.get("helipad_firepots_lit_count", 0))
	for p_idx in range(4):
		var pot_pos := HELIPAD + pot_offsets[p_idx]
		var pot := Props.helipad_firepot()
		pot.position = pot_pos
		add_child(pot)

		var pot_light := OmniLight3D.new()
		pot_light.position = pot_pos + Vector3(0, 0.45, 0)
		pot_light.light_color = Color(1.0, 0.62, 0.22)
		pot_light.light_energy = 3.5 if (saved_pots_all or p_idx < saved_pots_cnt) else 0.0
		pot_light.omni_range = 14.0
		pot_light.shadow_enabled = false
		add_child(pot_light)

		var it_pot := Geo.interactable(self, Vector3(1.2, 0.8, 1.2), pot_pos + Vector3(0, 0.35, 0), null, "", func(_p: Player) -> void:
			if pot_light.light_energy > 0.1:
				return
			pot_light.light_energy = 3.5
			var cur_lit := int(SaveGame.flags.get("helipad_firepots_lit_count", 0)) + 1
			SaveGame.flags["helipad_firepots_lit_count"] = mini(cur_lit, 4)
			AudioDirector.play_raw("res://assets/audio/stove_add.ogg", 0.0)
			Game.audio.play_3d("res://assets/audio/stove_add.ogg", pot_pos, 0.0, 15.0)
			if cur_lit >= 4:
				SaveGame.flags["helipad_pots_all_lit"] = true
				Game.hud.subtitle(Loc.t(&"it.helipad_pots_lit"), 4.5)
			SaveGame.write()
		)
		it_pot.prompt_provider = func() -> String:
			if pot_light.light_energy > 0.1:
				return ""
			var cur := int(SaveGame.flags.get("helipad_firepots_lit_count", 0)) + 1
			return Loc.t(&"it.helipad_firepot", [mini(cur, 4)])
		it_pot.name = "FirePot_%d" % p_idx

	# 5. Патрон сигнальный ночной/дневной ПСНД (магниевый красный огонь 20 000 свечей)
	var psnd := Props.psnd_flare()
	var psnd_pos := HELIPAD + Vector3(-5.2, 0.35, -4.8)
	psnd.position = psnd_pos
	add_child(psnd)

	var psnd_lit_saved := bool(SaveGame.flags.get("psnd_flare_lit", false))
	var psnd_light := OmniLight3D.new()
	psnd_light.position = psnd_pos + Vector3(0, 0.5, 0)
	psnd_light.light_color = Color(1.0, 0.12, 0.12)
	psnd_light.light_energy = 16.0 if psnd_lit_saved else 0.0
	psnd_light.omni_range = 28.0
	psnd_light.shadow_enabled = false
	add_child(psnd_light)

	var it_psnd := Geo.interactable(self, Vector3(0.8, 0.8, 0.8), psnd_pos, null, "", func(_p: Player) -> void:
		if psnd_light.light_energy > 0.1:
			return
		psnd_light.light_energy = 16.0
		SaveGame.flags["psnd_flare_lit"] = true
		AudioDirector.play_raw("res://assets/audio/flare.ogg", 4.0)
		Game.audio.play_3d("res://assets/audio/flare.ogg", psnd_pos, 4.0, 35.0)
		Game.hud.subtitle(Loc.t(&"sub.psnd_flare_blinding"), 5.5)
		Game.hud.flash_red(0.4, 0.6)
		SaveGame.write()
	)
	it_psnd.prompt_provider = func() -> String:
		return "" if psnd_light.light_energy > 0.1 else Loc.t(&"it.psnd_flare_use")
	it_psnd.name = "PSNDFlare"

	# 6. Измеритель ВНГО ИВО-1М и щит видимости М-37
	var ivo := Props.ivo1m_cloudmeter()
	ivo.position = PLOT + Vector3(5.5, 0.0, 3.2)
	add_child(ivo)
	var it_ivo := Geo.interactable(self, Vector3(1.0, 1.4, 1.0), PLOT + Vector3(5.5, 0.7, 3.2), null, "", func(_p: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", 0.0)
		Game.hud.subtitle(Loc.t(&"it.ivo1m_inspect", ["180 м"]), 4.5)
	)
	it_ivo.prompt_provider = func() -> String: return Loc.t(&"it.ivo1m_inspect", ["180 м"])
	it_ivo.name = "IVO1M_Meter"

	var m37 := Props.m37_visibility_shield()
	var m37_pos := PLOT + Vector3(-6.0, 0.0, 34.0)
	m37.position = m37_pos
	add_child(m37)
	var it_m37 := Geo.interactable(self, Vector3(1.8, 2.2, 1.2), m37_pos + Vector3(0.0, 1.1, 0.0), null, "", func(_p: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", 0.0)
		Game.hud.subtitle(Loc.t(&"it.m37_inspect", ["800 м"]), 4.5)
	)
	it_m37.prompt_provider = func() -> String: return Loc.t(&"it.m37_inspect", ["800 м"])
	it_m37.name = "M37_Shield"

	_build_helipad_heli()


func _build_helipad_heli() -> void:
	# Ночи 1–4: вертолётная логика неактивна
	if Game.night < 5:
		return
	# Ночи 5–6: пролётный сброс снабжения без припаркованного вертолёта на земле
	if Game.night in [5, 6]:
		if Game.helipad_cleared and not Game.has_flag("supply_drop_collected") and _heli_crate_it == null:
			var crate_root := Node3D.new()
			crate_root.name = "SupplyCrate_Parachute"
			crate_root.position = HELIPAD
			add_child(crate_root)
			var crate_model := Props.supply_crate()
			crate_model.position = Vector3(2.6, 0.0, 1.2)
			crate_root.add_child(crate_model)
			_heli_crate_it = Geo.interactable(crate_root, Vector3(1.2, 1.0, 1.2), Vector3(2.6, 0.5, 1.2), null, Loc.t(&"it.heli_crate"), func(_p: Player) -> void:
				Game.flares += 4
				Game.canisters_left += 1
				Game.set_flag("supply_drop_collected", true)
				Game.vibrate(0.4, 0.2, 0.25)
				Game.hud.subtitle(Loc.t(&"sub.heli_keeper"), 5.0)
				crate_root.queue_free()
				_heli_crate_it = null
			)
		return
	# Ночь 7: меш Ми-8Т спавнится ТОЛЬКО когда mi8_state переходит в HOVER_LANDING / LANDED_WAITING
	if Game.night >= 7 and (Game.mi8_state == Game.Mi8State.HOVER_LANDING or Game.mi8_state == Game.Mi8State.LANDED_WAITING):
		_spawn_night7_mi8_actor()


func _spawn_night7_mi8_actor() -> void:
	if _heli_node != null and is_instance_valid(_heli_node):
		return
	_heli_node = Node3D.new()
	_heli_node.name = "HeliNode"
	_heli_node.position = HELIPAD + (Vector3(0, 14.0, 0) if Game.mi8_state == Game.Mi8State.HOVER_LANDING else Vector3.ZERO)
	add_child(_heli_node)

	var heli_mesh := Props.mi8_helicopter()
	_heli_node.add_child(heli_mesh)

	_heli_searchlight = SpotLight3D.new()
	_heli_searchlight.name = "SearchlightSpot"
	_heli_searchlight.position = Vector3(0.0, 1.8, -3.5)
	_heli_searchlight.light_color = Color(1.0, 0.96, 0.82)
	_heli_searchlight.light_energy = 12.0
	_heli_searchlight.spot_range = 42.0
	_heli_searchlight.spot_angle = 32.0
	_heli_node.add_child(_heli_searchlight)
	_heli_searchlight.look_at(HELIPAD + Vector3(0, 0.2, -12.0), Vector3.UP)

	_heli_dust = CPUParticles3D.new()
	_heli_dust.name = "RotorDustGPUParticles"
	_heli_dust.amount = 28
	_heli_dust.lifetime = 1.4
	_heli_dust.direction = Vector3(0, 0.2, 1.0)
	_heli_dust.spread = 180.0
	_heli_dust.initial_velocity_min = 4.0
	_heli_dust.initial_velocity_max = 9.0
	var dm := QuadMesh.new()
	dm.size = Vector2(0.8, 0.8)
	dm.material = Player.puff_material(0.35)
	_heli_dust.mesh = dm
	_heli_dust.position = Vector3(0, 0.4, 0)
	_heli_node.add_child(_heli_dust)

	_heli_audio = AudioStreamPlayer3D.new()
	_heli_audio.stream = AudioDirector.cached_stream("res://assets/audio/engine_loop.ogg")
	_heli_audio.unit_size = 7.0
	_heli_audio.max_distance = 85.0
	_heli_audio.volume_db = -2.0
	_heli_audio.pitch_scale = 1.12
	_heli_audio.bus = &"SFX"
	_heli_audio.autoplay = true
	_heli_node.add_child(_heli_audio)

	_heli_evac_it = Geo.interactable(_heli_node, Vector3(2.5, 2.0, 2.5), Vector3(-1.8, 0.8, 0.0), null, "", func(_p: Player) -> void:
		if Game.mi8_state != Game.Mi8State.LANDED_WAITING:
			Game.hud.subtitle(Loc.t(&"it.mi8_board_locked"), 2.5)
			return
		EventBus.ending_chosen.emit(&"mi8_escape")
	)
	_heli_evac_it.prompt_provider = func() -> String:
		return Loc.t(&"it.mi8_board") if Game.mi8_state == Game.Mi8State.LANDED_WAITING else Loc.t(&"it.mi8_board_locked")
	_heli_evac_it.name = "Mi8EvacRamp"


func schedule_mi8_crash() -> void:
	_mi8_crash_timer = 10.0
	_mi8_crash_fx_done = false


func _process_mi8_helipad(delta: float) -> void:
	if Game.night in [5, 6] and Game.helipad_cleared and not _mi8_supply_flyby_done and Game.is_outside() and not Game.has_flag("supply_drop_collected"):
		_mi8_supply_flyby_done = true
		Game.audio.play_3d("res://assets/audio/engine_loop.ogg", HELIPAD + Vector3(0, 28.0, 0), -6.0, 90.0)
	if Game.night < 7:
		return

	match Game.mi8_state:
		Game.Mi8State.APPROACHING:
			Game.mi8_state_timer -= delta
			if Game.mi8_state_timer <= 0.0:
				Game.mi8_state = Game.Mi8State.HOVER_LANDING
				Game.mi8_state_timer = 8.0
				_spawn_night7_mi8_actor()
		Game.Mi8State.HOVER_LANDING:
			_spawn_night7_mi8_actor()
			Game.mi8_state_timer -= delta
			if _heli_node != null and is_instance_valid(_heli_node):
				var frac := clampf(1.0 - (Game.mi8_state_timer / 8.0), 0.0, 1.0)
				_heli_node.position = HELIPAD + Vector3(0, lerpf(14.0, 0.0, smoothstep(0.0, 1.0, frac)), 0)
			if Game.mi8_state_timer <= 0.0:
				Game.mi8_state = Game.Mi8State.LANDED_WAITING
				Game.mi8_state_timer = 180.0
				if _heli_node != null and is_instance_valid(_heli_node):
					_heli_node.position = HELIPAD
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"sub.mi8_landed"), 7.0)
		Game.Mi8State.LANDED_WAITING:
			Game.mi8_state_timer -= delta
			if Game.mi8_state_timer <= 0.0:
				Game.mi8_state = Game.Mi8State.DEPARTED
				if _heli_node != null and is_instance_valid(_heli_node):
					var tw := _heli_node.create_tween()
					tw.tween_property(_heli_node, "position", HELIPAD + Vector3(0, 42.0, 50.0), 6.0)
					tw.tween_callback(_heli_node.queue_free)
				if Game.hud != null:
					Game.hud.subtitle(Loc.t(&"sub.mi8_departed"), 6.5)
		Game.Mi8State.CRASHED:
			if not _mi8_crash_fx_done and _mi8_crash_timer > 0.0:
				_mi8_crash_timer -= delta
				if _mi8_crash_timer <= 0.0:
					_play_mi8_crash_fx()


func _play_mi8_crash_fx() -> void:
	_mi8_crash_fx_done = true
	var crash_pos := HELIPAD + Vector3(0.0, 4.0, -58.0)
	Game.audio.play_2d("res://assets/audio/flare.ogg", 5.0)
	Game.audio.play_2d("res://assets/audio/clank.ogg", 4.0)
	Game.audio.play_3d("res://assets/audio/generator_sputter.ogg", crash_pos, 4.0, 110.0)
	if Game.player != null:
		Game.player.shake(0.18, 1.8)
	if Game.hud != null:
		Game.hud.flash_red(0.6, 0.8)
		Game.hud.subtitle(Loc.t(&"radio.mi8_crash_comms"), 8.0, 2)
	var fire_glow := OmniLight3D.new()
	fire_glow.position = crash_pos + Vector3(0, 5.0, 0)
	fire_glow.light_color = Color(1.0, 0.28, 0.05)
	fire_glow.light_energy = 14.0
	fire_glow.omni_range = 75.0
	fire_glow.shadow_enabled = false
	add_child(fire_glow)
	Director.add_tension(35.0, "крушение Ми-8 за северным гребнем")


# --- Обустройство дороги от дома к метеокорпусу (Station Road Dressing) -------

func _build_station_road_dressing() -> void:
	# 1. Дощатые настилы / трапы (Plank Walkways) только у входных крылец зданий:
	var trail_segments: Array[Array] = [
		[Vector3(15.2, 0.0, 3.5), Vector3(17.2, 0.0, 3.5)],          # Крыльцо жилого дома
		[Vector3(84.5, 0.0, -27.6), CORPUS_PORCH],                   # Вход на крыльцо метеокорпуса
		[Vector3(37.5, 0.0, 24.5), SHED + Vector3(-4.9, 0.0, 0.0)],  # Трап у сарая
	]
	for seg: Array in trail_segments:
		var p0: Vector3 = seg[0]
		var p1: Vector3 = seg[1]
		Station.register_boardwalk_segment(p0, p1)
		var d := p1 - p0
		d.y = 0.0
		var len := d.length()
		if len < 0.5:
			continue
		var mid := (p0 + p1) * 0.5
		mid.y = Terrain.height(mid.x, mid.z) + 0.02
		var walkway := Props.plank_walkway(len)
		walkway.position = mid
		walkway.rotation.y = atan2(d.x, d.z)
		add_child(walkway)

	if not LEAN_YARD:
		# Штабель 200-литровых бочек «Арктика» (ГОСТ 305-82) на 28-м метре маршрута
		var drum_stack := Props.arktika_drum_stack()
		var ds_pos := Vector3(38.0, Terrain.height(38.0, -11.0), -11.0)
		drum_stack.position = ds_pos
		drum_stack.rotation.y = deg_to_rad(-22.0)
		add_child(drum_stack)
		var drum_it := Geo.interactable(self, Vector3(2.6, 2.0, 2.0), ds_pos + Vector3(0, 1.0, 0), null, Loc.t(&"it.arktika_barrels"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.arktika_barrels"), 5.0)
		)
		drum_it.name = "ArktikaBarrelsRoute"

		var drum_wind := AudioStreamPlayer3D.new()
		var dw_stream := load("res://assets/sfx/cc0/wire_gust_loop.ogg") as AudioStream
		if dw_stream is AudioStreamOggVorbis:
			dw_stream = dw_stream.duplicate()
			(dw_stream as AudioStreamOggVorbis).loop = true
		drum_wind.stream = dw_stream
		drum_wind.volume_db = -30.0
		drum_wind.unit_size = 4.0
		drum_wind.max_distance = 14.0
		drum_wind.bus = &"Weather"
		drum_wind.position = ds_pos + Vector3(1.3, 0.8, 0)
		add_child(drum_wind)
		drum_wind.play()

	# Уличный светильник СПО-200 на столбе на 56-м метре (маятник света над тропой к будке)
	var spo_pos := Vector3(56.0, Terrain.height(56.0, -26.0), -26.0)
	var spo_pole := Props.spo200_pole(5.4)
	spo_pole.position = spo_pos
	spo_pole.rotation.y = deg_to_rad(-45.0)
	add_child(spo_pole)

	# Поющий провод ЛЭП на ветру
	var wire_sing := AudioStreamPlayer3D.new()
	var ws_stream := load("res://assets/sfx/cc0/wire_gust_loop.ogg") as AudioStream
	if ws_stream is AudioStreamOggVorbis:
		ws_stream = ws_stream.duplicate()
		(ws_stream as AudioStreamOggVorbis).loop = true
	wire_sing.stream = ws_stream
	wire_sing.volume_db = -28.0
	wire_sing.unit_size = 4.5
	wire_sing.max_distance = 18.0
	wire_sing.bus = &"Weather"
	wire_sing.position = Vector3(56.0, 4.5, -18.0)
	add_child(wire_sing)
	wire_sing.play()

	# 2. Воздушная линия ЛЭП к метеокорпусу
	var pole_m1_pos := Vector3(36.0, 0.0, -9.0)
	var pole_m2_pos := Vector3(56.0, 0.0, -18.0)
	var pole_m3_pos := Vector3(76.0, 0.0, -24.0)
	var corpus_entry_pos := Vector3(87.0, 3.8, -25.5)
	var pole_trail_pos := Vector3(31.0, 0.0, 16.0)

	var meteo_poles := {
		"mp1": [pole_m1_pos, pole_m2_pos - pole_trail_pos],
		"mp2": [pole_m2_pos, pole_m3_pos - pole_m1_pos],
		"mp3": [pole_m3_pos, corpus_entry_pos - pole_m2_pos],
	}
	var m_wires := {}
	for id: String in meteo_poles:
		var pp: Vector3 = meteo_poles[id][0]
		pp.y = Terrain.height(pp.x, pp.z)
		var d: Vector3 = meteo_poles[id][1]
		d.y = 0.0
		var perp := Vector3(-d.z, 0.0, d.x).normalized()
		var yaw := atan2(-perp.z, perp.x)
		var pole := Props.utility_pole(5.4)
		pole.position = pp
		pole.rotation.y = yaw
		pole.rotation.x = deg_to_rad(sin(pp.x * 0.7 + pp.z * 1.3) * 4.5)
		pole.rotation.z = deg_to_rad(cos(pp.x * 1.1 - pp.z * 0.9) * 4.0)
		add_child(pole)
		var pts := Props.pole_wire_points(5.4)
		var basis := Basis(Vector3.UP, yaw)
		m_wires[id] = [pole.position + basis * pts[0], pole.position + basis * pts[1]]

	var trail_pts := Props.pole_wire_points(5.4)
	var trail_pole_wires := [pole_trail_pos + trail_pts[0], pole_trail_pos + trail_pts[1]]
	_build_catenary_wire(trail_pole_wires, m_wires["mp1"], 0.55)
	_build_catenary_wire(m_wires["mp1"], m_wires["mp2"], 0.60)
	_build_catenary_wire(m_wires["mp2"], m_wires["mp3"], 0.60)
	_build_catenary_wire(m_wires["mp3"], _entry_pair(corpus_entry_pos, pole_m3_pos), 0.40)

	if not LEAN_YARD:
		# 3. Наземная теплотрасса на лежнях (убрана с тропы в складскую зону за сараем)
		var pipe1 := Props.pipe_rack(4.8)
		pipe1.position = Vector3(44.0, Terrain.height(44.0, 38.0), 38.0)
		pipe1.rotation.y = deg_to_rad(-48.0)
		add_child(pipe1)

		var pipe2 := Props.pipe_rack(4.8)
		pipe2.position = Vector3(48.0, Terrain.height(48.0, 39.0), 39.0)
		pipe2.rotation.y = deg_to_rad(-45.0)
		add_child(pipe2)

	# Гусеничный трактор ТДТ-55 (на обочине, занесенный снегом)
	var tractor := Props.crawler_tractor_tdt55()
	if LEAN_YARD:
		var t_pos := Vector3(32.0, 0.0, -13.0)
		var t := Vector3(t_pos.x, Terrain.height(t_pos.x, t_pos.z) - 0.18, t_pos.z)
		tractor.position = t
		tractor.rotation.y = deg_to_rad(24.0)
		add_child(tractor)
		var t_col := Geo.collider(self, Vector3(2.4, 2.2, 4.4), t + Vector3(0, 1.1, 0))
		t_col.rotation.y = deg_to_rad(24.0)
		var t_yaw := 24.0
		SiteDressing.drift(self, t + Vector3(-1.7, 0.1, 0.0), 4.5, 0.8, 1.6, t_yaw)
		SiteDressing.drift(self, t + Vector3(1.7, 0.1, 0.0), 4.5, 0.8, 1.6, t_yaw)
		SiteDressing.drift(self, t + Vector3(0.0, 0.05, 2.2), 3.0, 0.5, 1.2, t_yaw)
	else:
		var tractor_pos := Vector3(44.0, Terrain.height(44.0, 30.0), 30.0)
		tractor.position = tractor_pos
		tractor.rotation.y = deg_to_rad(24.0)
		add_child(tractor)
		var t_col := Geo.collider(self, Vector3(2.4, 2.2, 4.4), tractor_pos + Vector3(0, 1.1, 0))
		t_col.rotation.y = deg_to_rad(24.0)

		var tractor_it := Geo.interactable(self, Vector3(3.2, 2.2, 4.8), tractor_pos + Vector3(0, 1.2, 0), null, Loc.t(&"it.crawler_tractor"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.crawler_tractor"), 5.0)
		)
		tractor_it.name = "TractorTDT55"

		# Колея от гусениц тягача к зимнику
		SiteDressing.tracks(self, tractor_pos + Vector3(0, 0, 2.5), Vector3(14.0, 0.0, 14.0))
		SiteDressing.tracks(self, Vector3(14.0, 0.0, 14.0), Vector3(-10.0, 0.0, 34.0))

	if not LEAN_YARD:
		# 6. Волокуши геодезистов (Surveyor Sledge) на северной опушке
		var sledge_pos := Vector3(48.0, Terrain.height(48.0, -32.0), -32.0)
		var sledge := Props.surveyor_sledge()
		sledge.position = sledge_pos
		sledge.rotation.y = deg_to_rad(32.0)
		add_child(sledge)
		var sl_col := Geo.collider(self, Vector3(1.6, 1.2, 2.8), sledge_pos + Vector3(0, 0.6, 0))
		sl_col.rotation.y = deg_to_rad(32.0)
		var sledge_it := Geo.interactable(self, Vector3(2.2, 1.6, 3.2), sledge_pos + Vector3(0, 0.8, 0), null, Loc.t(&"it.surveyor_sledge_road"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.surveyor_sledge_road"), 5.0)
		)
		sledge_it.name = "SurveyorSledgeRoad"

		# 7. Снегозадерживающие щиты (Snow Fences) вдоль дальнего северного поля
		var road_fences: Array[Vector3] = [
			Vector3(44.0, 0.0, -34.0),
			Vector3(48.0, 0.0, -35.0),
			Vector3(52.0, 0.0, -36.0),
			Vector3(64.0, 0.0, -36.0),
			Vector3(68.0, 0.0, -36.0),
			Vector3(72.0, 0.0, -36.0),
		]
		for rfp in road_fences:
			var fence := Props.snow_fence(3.2, 1.8)
			fence.position = Vector3(rfp.x, Terrain.height(rfp.x, rfp.z), rfp.z)
			fence.rotation.y = deg_to_rad(-35.0 if rfp.x < 55.0 else -10.0)
			add_child(fence)
			SiteDressing.drift(self, fence.position + Vector3(0.3, 0, -0.5), 3.4, 0.65, 1.1, fence.rotation_degrees.y)

		# 9. Штабель бочек с полярной соляркой «Арктика» возле опоры mp2
		var depot_pos := Vector3(61.5, Terrain.height(61.5, -25.5), -25.5)
		for bi in 4:
			var b: Node3D = Props.frozen_barrel() if bi % 2 == 1 else Props.barrel()
			var boff := Vector3((bi % 2) * 0.75 - 0.35, 0.0, (bi / 2) * 0.75 - 0.35)
			var bp := depot_pos + boff
			bp.y = Terrain.height(bp.x, bp.z)
			b.position = bp
			b.rotation.y = deg_to_rad(bi * 45.0)
			add_child(b)
		var depot_col := Geo.collider(self, Vector3(2.0, 1.4, 2.0), depot_pos + Vector3(0, 0.7, 0))
		var depot_it := Geo.interactable(self, Vector3(2.4, 1.6, 2.4), depot_pos + Vector3(0, 0.8, 0), null, Loc.t(&"it.fuel_depot_road"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.fuel_depot_road"), 5.0)
		)
		depot_it.name = "FuelDepotRoad"

		# Деревянный ящик снабжения у бочек
		var cr := Props.crate()
		var cr_pos := depot_pos + Vector3(1.2, 0.0, 0.2)
		cr_pos.y = Terrain.height(cr_pos.x, cr_pos.z)
		cr.position = cr_pos
		cr.rotation.y = deg_to_rad(18.0)
		add_child(cr)

		# 10. Лопата и ступени у входа в метеокорпус (Corpus Porch)
		var porch_shovel := Props.snow_shovel()
		var ps_pos := CORPUS_PORCH + Vector3(-1.4, 0.0, 1.2)
		ps_pos.y = Terrain.height(ps_pos.x, ps_pos.z)
		porch_shovel.position = ps_pos
		porch_shovel.rotation.x = deg_to_rad(14.0)
		porch_shovel.rotation.y = deg_to_rad(-65.0)
		add_child(porch_shovel)
		var psh_it := Geo.interactable(self, Vector3(1.4, 1.6, 1.4), ps_pos + Vector3(0, 0.7, 0), null, Loc.t(&"it.shovel_corpus"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.shovel_corpus"), 4.5)
		)
		psh_it.name = "CorpusPorchShovel"


# --- Дополнительное обустройство двора станции (Yard Clutter) ----------------

func _build_yard_clutter() -> void:
	# 1. Станционная уборная (Outhouse) в стороне от тропы к дровянику
	var outhouse_pos := Vector3(17.0, Terrain.height(17.0, 19.5), 19.5)
	var outhouse_prop := Props.outhouse()
	outhouse_prop.position = outhouse_pos
	outhouse_prop.rotation.y = deg_to_rad(-85.0)
	add_child(outhouse_prop)
	var o_col := Geo.collider(self, Vector3(1.3, 2.4, 1.3), outhouse_pos + Vector3(0, 1.2, 0))
	o_col.rotation.y = deg_to_rad(-85.0)

	# Мостки от тропы к двери уборной (от x=14.0 у тропы до порога x=16.4)
	var outhouse_walk := Props.plank_walkway(2.4)
	outhouse_walk.position = Vector3(15.2, Terrain.height(15.2, 19.5) + 0.02, 19.5)
	outhouse_walk.rotation.y = deg_to_rad(90.0)
	add_child(outhouse_walk)
	Station.register_boardwalk_segment(Vector3(14.0, 0.0, 19.5), Vector3(16.4, 0.0, 19.5))

	# Лопата у стены уборной
	var shovel := Props.snow_shovel()
	shovel.position = outhouse_pos + Vector3(0.7, 0.0, 0.5)
	shovel.rotation.x = deg_to_rad(12.0)
	add_child(shovel)

	var outhouse_it := Geo.interactable(self, Vector3(1.8, 2.2, 1.8), outhouse_pos + Vector3(0.5, 1.1, 0), null, Loc.t(&"it.outhouse"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.outhouse"), 5.0)
	)
	outhouse_it.name = "StationOuthouse"

	if not LEAN_YARD:
		# 2. Лежачая цистерна ГСМ (Fuel Tank) возле сарая дизельной
		var tank_pos := Vector3(41.0, Terrain.height(41.0, 26.5), 26.5)
		var tank := Props.fuel_tank()
		tank.position = tank_pos
		tank.rotation.y = deg_to_rad(35.0)
		add_child(tank)
		var tk_col := Geo.collider(self, Vector3(3.6, 1.8, 1.6), tank_pos + Vector3(0, 0.9, 0))
		tk_col.rotation.y = deg_to_rad(35.0)
		SiteDressing.patch(self, tank_pos + Vector3(0.5, 0, 0), 2.2, &"soot")

		var tank_it := Geo.interactable(self, Vector3(3.8, 2.0, 2.2), tank_pos + Vector3(0, 1.0, 0), null, Loc.t(&"it.fuel_cistern"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.fuel_cistern"), 5.0)
		)
		tank_it.name = "FuelCistern"

		# 3. Снегоход «Буран» с грузовыми нартами на стоянке у сарая дизельной
		var buran_pos := Vector3(38.0, Terrain.height(38.0, 24.0), 24.0)
		var buran := Props.soviet_snowmobile()
		buran.position = buran_pos
		buran.rotation.y = deg_to_rad(-45.0)
		add_child(buran)

		var buran_sledge := Props.siberian_sledge()
		buran_sledge.position = buran_pos + Vector3(-0.6, 0.0, -2.6)
		buran_sledge.rotation.y = deg_to_rad(-45.0)
		add_child(buran_sledge)

		# Ящики с припасами на нартах
		var crate1 := Props.crate()
		crate1.position = buran_pos + Vector3(-0.6, 0.35, -2.4)
		crate1.rotation.y = deg_to_rad(10.0)
		add_child(crate1)

		var buran_it := Geo.interactable(self, Vector3(2.6, 1.4, 4.8), buran_pos + Vector3(-0.3, 0.7, -1.2), null, Loc.t(&"it.buran_sledge"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"sub.buran_sledge"), 5.0)
		)
		buran_it.name = "BuranSnowmobile"

		# 4. Распилочный и дровокольный двор возле поленницы
		var logs_pos := Vector3(8.0, Terrain.height(8.0, 42.0), 42.0)
		var logs := Props.log_pile(5.0)
		logs.position = logs_pos
		logs.rotation.y = deg_to_rad(15.0)
		add_child(logs)

		var stump_pos := Vector3(6.0, Terrain.height(6.0, 37.5), 37.5)
		var stump := Props.axe_stump()
		stump.position = stump_pos
		stump.rotation.y = deg_to_rad(-30.0)
		add_child(stump)
		SiteDressing.patch(self, stump_pos, 1.9, &"dust")

		var kindling_pos := Vector3(3.2, Terrain.height(3.2, 38.0), 38.0)
		var kindling := Props.woodbox(3)
		kindling.position = kindling_pos
		add_child(kindling)





