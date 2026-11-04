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
var _rope_nodes: Array[Node3D] = []
var _sign_nodes: Array[Node3D] = []
var _crow_timer := 110.0
var _outdoor_cd := 0.0
var _pilot_balloon_node: Node3D = null
const HUNTER_SPRUCE_POS := Vector3(22.0, 0.0, -28.0)
var _frozen_hunter_node: Node3D = null
var _hunter_aura_noticed := false
var _zherdyai_step_timer := 0.0


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
	# Леер (натянутый трос со столбами и флажками) — спасение дежурного в буран
	# Трос натянут вдоль каждой открытой тропы — карта, бонус «у троса» и сам трос совпадают.
	for p in paths:
		_build_trail(p)
		_build_rope_line(p, route_of(p))
	# Щиты-указатели горели в метель, как вывески. Дорогу теперь читают по цвету флажков на леере
	# и по схеме [M]; маленькие таблички остались только в сюжетном режиме — он и так ведёт за руку.
	if Game.is_story():
		_build_signs()
	_build_meteo()
	_build_mast()
	_build_shed()
	_restore_placed_pickups()
	FarSites.build(self)
	Supply.place_crate(self)
	Supply.hook()
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
	_build_snow_fences()
	_build_fuel_drum_field()
	_build_expedition_cart()
	_build_taiga_landmarks()
	_build_snow_survey_route()
	_build_helipad()
	_build_frozen_hunter()
	if Game.is_day() and Game.phase_index == 1:

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
	# Уличные кошмары: появление сущностей и пугающая атмосфера в тайге
	_process_outdoor_horror(delta)
	_process_snow_survey_stalking(delta)

	if _pilot_balloon_node != null and is_instance_valid(_pilot_balloon_node):
		_pilot_balloon_node.position += Vector3(0.32 * delta, 0.72 * delta, -0.22 * delta)
		# Свет фонарика гаснет с высотой: над двором он только первые ~40 с
		var bl := _pilot_balloon_node.find_children("*", "OmniLight3D", true, false)
		if not bl.is_empty():
			(bl[0] as OmniLight3D).light_energy = 1.6 * clampf(1.0 - (_pilot_balloon_node.position.y - 12.0) / 22.0, 0.0, 1.0)
		if _pilot_balloon_node.position.y > 65.0:
			Game.balloon_launched = false
			_pilot_balloon_node.queue_free()
			_pilot_balloon_node = null


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
	var size := Vector3(0.85, 0.45, 0.52) if item == &"trunk" else (Vector3(0.35, 0.45, 0.2) if item == &"canister" else Vector3(0.25, 0.35, 0.18) if item == &"oil" else Vector3(0.5, 0.85, 0.35) if item == &"shovel" else Vector3(0.5, 0.28, 0.35))
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

## Слои морозной дымки между рядами елей: три открытых цилиндра вокруг станции (assets/shaders/forest_haze.gdshader).
## Ночью — лунное молоко, днём — серая мгла. Лес перестаёт быть плоской тёмной стеной и уходит вдаль.
func _build_forest_haze() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/forest_haze.gdshader")
	mat.set_shader_parameter(&"haze_col", Color(0.62, 0.65, 0.7) if Game.is_daylight() else Color(0.11, 0.18, 0.24))
	mat.set_shader_parameter(&"strength", 0.22 if Game.is_daylight() else 0.32)
	for r: float in [48.0, 70.0, 95.0]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 9.0
		cyl.radial_segments = 48
		cyl.rings = 1
		cyl.cap_top = false
		cyl.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(20.0, 4.5, -5.0)
		mi.extra_cull_margin = 10.0
		add_child(mi)


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
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 10
	blob.rings = 5
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var nrm: Vector3 = r[2]
		var h: float = r[3]
		var n := maxi(3, int(a.distance_to(b) / 0.75))   # часто и внахлёст — сплошной намёт, а не ряд «камней»
		for i in range(n + 1):
			var p := a.lerp(b, float(i) / n) + nrm * rng.randf_range(0.0, 0.2)
			var mi := MeshInstance3D.new()
			mi.mesh = blob
			mi.material_override = Palette.m(&"drift")
			mi.layers = Station.LAYER_OUT
			mi.position = p + Vector3(0, -h * 0.25, 0)
			var along := absf(nrm.x) < 0.5
			var len := rng.randf_range(1.4, 2.2)
			var wid := rng.randf_range(0.8, 1.15)
			mi.scale = Vector3(len if along else wid, h * rng.randf_range(0.75, 1.0), wid if along else len)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


func _build_ground() -> void:
	# Земля всей карты (1 км): двор ровный, дальше сопки, зимники и площадки (Terrain).
	# Сетка 4 м — один огромный квад «плыл» бы под камерой из-за PS1-снапа вершин.
	Terrain.build(self, 150.0 if Game.is_daylight() else 95.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drift := SphereMesh.new()
	drift.radius = 1.0
	drift.height = 2.0
	drift.radial_segments = 16    # 8×4 давали гранёные «мятые» сугробы
	drift.rings = 8
	for i in range(140):
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
		mi.position = p
		mi.scale = Vector3(rng.randf_range(1.4, 4.5), rng.randf_range(0.2, 0.55), rng.randf_range(1.2, 3.2))
		mi.rotation.y = rng.randf() * TAU
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


## Натоптанная тропа: полосы утоптанного снега вдоль путей (текстура в координатах полосы).
func _build_trail(line: PackedVector3Array) -> void:
	var mat := Creatures._mat(&"trail", Palette.COLORS[&"snow"] * (1.6 / 1.5), "tex_trail.png", 0.0)
	mat.set_shader_parameter(&"tex_scale", TRAIL_W)
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.1:
			continue
		var pm := PlaneMesh.new()
		pm.size = Vector2(TRAIL_W, seg_len + TRAIL_W * 0.6)   # с нахлёстом на стыках
		pm.subdivide_depth = maxi(1, int(seg_len / 2.0))
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = (a + b) * 0.5 + Vector3(0, 0.008 + 0.001 * (i % 3), 0)
		var dir := (b - a).normalized()
		var yaw := atan2(dir.x, dir.z)
		var pitch := -asin(clampf(dir.y, -1.0, 1.0))
		mi.rotation = Vector3(pitch, yaw, 0.0)
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


func _build_rope_line(line: PackedVector3Array, route: Dictionary = {}) -> void:
	var flag_col: Color = route.get("color", Color(0, 0, 0, 0))
	var flag_shape: int = route.get("shape", 0)
	line = _offset_line(line, 1.0)
	var posts: Array[Vector3] = []
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / POST_STEP))
		for k in range(n):
			posts.append(Terrain.at(a.lerp(b, float(k) / n)))   # вешка — на снегу, и на склоне тоже
	posts.append(Terrain.at(line[line.size() - 1]))

	# Вешки ставили на глаз: каждая чуть кренится и разной высоты; трос провисает между ними дугой.
	# На развилках трос разорван — несколько лееров не перекрещиваются сеткой.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(line[0].x * 31.0 + line[0].z * 17.0)) + posts.size()
	var tops: Array[Vector3] = []
	for i in range(posts.size()):
		var p := posts[i]
		var post := Props.rope_post(i % 2 == 0 and flag_col.a > 0.0, flag_col, flag_shape)
		post.position = p
		var sy := rng.randf_range(0.92, 1.06)
		post.scale = Vector3(1.0, sy, 1.0)
		post.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-PI, PI), rng.randf_range(-0.05, 0.05))
		add_child(post)
		_rope_nodes.append(post)
		var it_post := Interactable.new()
		it_post.collision_layer = Geo.LAYER_INTERACT
		it_post.position = Vector3(0, 0.9, 0)
		it_post.add_child(Geo.box_shape(Vector3(0.55, 1.3, 0.55)))
		it_post.prompt_provider = func() -> String:
			return Loc.t(&"it.leer_detach") if Game.leer_attached else Loc.t(&"it.leer_attach")
		it_post.used.connect(_on_leer_post_used)
		post.add_child(it_post)
		tops.append(post.transform * Vector3(0, 1.05, 0))
		if i > 0 and not _near_fork((posts[i - 1] + p) * 0.5):
			_rope_span(tops[i - 1], tops[i])


## Трос между вешками: провисает параболой (4 куска), провис — от длины пролёта.
func _rope_span(a: Vector3, b: Vector3) -> void:
	var sag := 0.05 + a.distance_to(b) * 0.018
	var n := 4
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var cur := a.lerp(b, t) + Vector3(0, -4.0 * sag * t * (1.0 - t), 0)
		var seg_len := prev.distance_to(cur)
		var dir := (cur - prev).normalized()
		var seg := Geo.box_mesh(Vector3(0.022, 0.022, seg_len + 0.01), Palette.m(&"rope"))
		seg.position = (prev + cur) * 0.5
		seg.rotation = Vector3(-asin(clampf(dir.y, -1.0, 1.0)), atan2(dir.x, dir.z), 0.0)
		add_child(seg)
		_rope_nodes.append(seg)
		prev = cur


## Развилка: здесь сходятся несколько лееров — трос не тянем, чтобы не было сетки из верёвок.
func _near_fork(p: Vector3) -> bool:
	for f: Vector3 in [JUNCTION, FORK, MAST_FORK]:
		if _flat_dist(p, f) < 3.2:
			return true
	return false


func _on_leer_post_used(_p: Player) -> void:
	if Consequences.rope_broken() and not Game.leer_attached:
		Game.hud.subtitle(Loc.t(&"cons.rope_attach"), 3.5)   # леер оборван — днём не срастил
		return
	Game.leer_attached = not Game.leer_attached
	var lp := Game.audio.play_2d("res://assets/audio/clank.ogg", -6.0)
	if lp != null:
		lp.pitch_scale = 1.85 if Game.leer_attached else 1.15
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"sub.leer_attached") if Game.leer_attached else Loc.t(&"sub.leer_detached"), 3.5)



## Таблички на развилках: стоят на самой ветке, лицом к развилке. Видны только в свете.
func _build_signs() -> void:
	_sign(JUNCTION, FORK, &"sign.meteo_mast")
	_sign(JUNCTION, Vector3(26, 0, 12), &"sign.shed")
	_sign(JUNCTION, Vector3(32, 0, 4.5), &"sign.helipad")
	_sign(DOOR_OUT, Vector3(16, 0, 14), &"sign.wood")
	_sign(FORK, Vector3(40, 0, -14), &"sign.meteo")
	_sign(FORK, MAST_FORK, &"sign.mast")
	if izba_open:
		_sign(MAST_FORK, Vector3(10, 0, -25), &"sign.izba")
	if open_sites.get("repeater", false):
		_sign(Vector3(50, 0, -24), Vector3(58, 0, -40), &"sign.repeater")
	if open_sites.get("lake", false):
		_sign(Vector3(10.0, 0, 28.0), Vector3(-10, 0, 34), &"sign.lake")
	if open_sites.get("bunker", false):
		_sign(Vector3(36, 0, 24), Vector3(46, 0, 18), &"sign.bunker")
	if open_sites.get("zimnik", false):
		_sign(IZBA + Vector3(3.6, 0, 0), Vector3(-14, 0, -40), &"sign.zimnik")


func _sign(at: Vector3, toward: Vector3, key: StringName) -> void:
	var dir := (toward - at)
	dir.y = 0.0
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var text := Loc.t(key)
	# Доска по длине надписи, столбы — по краям, чтобы не перечёркивали текст.
	# Ширина — по настоящей ширине строк в шрифте (раньше считали по числу букв, и широкие
	# «Ш», «Щ», «Д» со скобками вылезали за край: «ВЕРТОДРОМ (ПЛОЩАДКА)» без скобки)
	var font: Font = ThemeDB.fallback_font
	var longest := 0.0
	for line in text.split("\n"):
		longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x * 0.0055)
	var lines := text.split("\n").size()
	var w := maxf(0.6, longest + 0.3)
	var h := 0.2 + lines * 0.2
	# Табличка — на обочине (со стороны, противоположной тросу), а не поперёк тропы.
	var pos := at + dir * 1.8 + side * (TRAIL_W * 0.5 + 0.15 + w * 0.5)
	var root := Node3D.new()
	add_child(root)
	_sign_nodes.append(root)
	root.position = pos
	root.look_at(pos - dir, Vector3.UP)        # лицом к развилке
	root.scale = Vector3.ONE * 0.6             # маленькая обветренная табличка, а не вывеска
	for sx: float in [-w / 2.0 + 0.04, w / 2.0 - 0.04]:
		Geo.block(root, Vector3(0.06, 1.55 + h / 2.0, 0.06), Vector3(sx, (1.55 + h / 2.0) / 2.0, 0.045), Palette.m(&"weathered"), false)
	Geo.block(root, Vector3(w, h, 0.03), Vector3(0, 1.55, 0), Palette.m(&"white"), false)
	for back in [false, true]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 40
		l.pixel_size = 0.0055
		l.line_spacing = -6.0
		l.modulate = Color(0.12, 0.1, 0.1)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false   # иначе текст просвечивает зеркально с обратной стороны
		l.position = Vector3(0, 1.55, 0.02 if back else -0.02)
		if not back:
			l.rotation.y = PI
		root.add_child(l)


# --- Аэрологический корпус и приборная площадка ---------------------------------------------

## Корпус, ангар, навес, мачта и ограда площадки — модели (tools/blender/corpus*.py) и MeteoCorpus;
## здесь — приборы, их замеры и наряды.
func _build_meteo() -> void:
	add_child(MeteoCorpus.new())
	# Табличка площадки — на ограде (corpus_yard.glb); вторая, отдельная, стояла с ней впритык

	# Действующая советская психрометрическая будка Селянинова
	var booth_pos := METEO + M_BOOTH
	var booth_prop := Props.meteo_screen()
	booth_prop.position = booth_pos
	booth_prop.name = "BoothModel"
	add_child(booth_prop)
	# Крупный кадр термометров (ThermometerUI): шкалу читаешь сам и вписываешь в книжку КМ-1.
	var booth_it := Geo.interactable(self, Vector3(0.65, 0.55, 0.55), booth_pos + Vector3(0.0, 1.55, 0.0), null, "", func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"thermometer"))
	booth_it.prompt_provider = func() -> String:
		return Loc.t(&"it.booth_done") if Game.readings.get(&"temp", false) else Loc.t(&"it.booth")
	booth_it.name = "BoothThermo"
	# Задание «откопать будку»: сугроб закрывает термометры, пока не разгребёшь лопатой.
	_drift = Geo.interactable(self, Vector3(1.3, 1.75, 1.2), booth_pos + Vector3(0, 0.95, 0), null, "", _on_drift_dug)
	# Округлый естественный перемет вокруг будки вместо серого монолитного ящика
	var d_blob := SphereMesh.new()
	d_blob.radius = 0.95
	d_blob.height = 1.9
	d_blob.radial_segments = 14
	d_blob.rings = 6
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
	old_screen.position = METEO + M_OLD
	add_child(old_screen)
	var old_it := Geo.interactable(self, Vector3(0.9, 1.4, 0.9), METEO + M_OLD + Vector3(0, 1.2, 0), null, Loc.t(&"it.old_meteo"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.old_meteo"), 5.0)
	)
	old_it.name = "OldMeteoScreen"

	# Советская снегомерная рейка М-103
	SnowStakeUI.build_stake(self, METEO + M_ROD)   # снег на рейке — ровно на сегодняшней высоте
	# Крупный кадр рейки (SnowStakeUI): высоту снега читаешь сам — и в книжку КМ-1
	var stake_it := Geo.interactable(self, Vector3(0.25, 2.0, 0.25), METEO + M_ROD + Vector3(0, 1.0, 0), null, "", func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"snow_stake"))
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
		return
	Game.set_antenna_iced(false)
	Game.hud.subtitle(Loc.t(&"sub.ice_done"), 3.5)
	_check_routine_scare_mast()


func _on_mast_ground_used(_p: Player) -> void:
	if not _mast_ground_active:
		return
	_set_mast_ground_hazard(false)
	if Game.tasks != null:
		Game.tasks.complete(&"mast_ground")
	Game.hud.subtitle(Loc.t(&"sub.mast_ground_done"), 4.0)
	Director.add_tension(-10.0, "рубильник заземления включен")
	_check_routine_scare_mast()


func _on_antenna_iced(iced: bool) -> void:
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

	# Занос/сугроб перед входом в сарай (начиная со второй ночи/дня)
	var shed_drift_pos := shed_center + Vector3(-total_len / 2.0 - 0.7, 0.0, 0.0)
	var drift_cleared: bool = bool(SaveGame.flags.get("shed_drift_cleared_n" + str(Game.night), false))
	var drift_needed: bool = (Game.night >= 2 or not Game.is_prologue()) and not drift_cleared
	_shed_drift = Geo.interactable(self, Vector3(1.4, 1.35, 2.3), shed_drift_pos + Vector3(0, 0.65, 0), null, "", _on_shed_drift_dug)
	# Намёт у ворот — округлый сугроб с языком, а не куб
	var d_blob := SphereMesh.new()
	d_blob.radius = 1.0
	d_blob.height = 2.0
	d_blob.radial_segments = 12
	d_blob.rings = 6
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
	# Лиса прошла от опушки вдоль двора, обнюхала поленницу и ушла обратно в лес — цепочка «в строчку».
	var fox := PackedVector3Array([Vector3(-14, 0, 22), Vector3(-6, 0, 18), Vector3(2, 0, 16.5), Vector3(5, 0, 21),
		Vector3(3.5, 0, 30), Vector3(-2, 0, 36), Vector3(-9, 0, 41)])
	Footprints.trail(self, &"paw", fox, 0.0, 0.3, 0.035)


# --- Лес ---------------------------------------------------------------------

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
	while transforms.size() < tree_count and attempts < 30000:
		attempts += 1
		var p := center + Vector3(rng.randf_range(-95, 95), 0.0, rng.randf_range(-95, 95))
		var d_house := _flat_dist(p, HOUSE_CENTER)
		if d_house < 13.0 or _dist_to(_all_paths, p) < 3.0:
			continue
		if _near_corpus(p, 7.0) or _in_shed_box(p) or _flat_dist(p, MAST) < 11.5 or _flat_dist(p, IZBA) < 8.5 or (p.x >= -22.0 and p.x <= -10.0 and p.z >= -36.0 and p.z <= -24.0) or _flat_dist(p, WOODPILE) < 7.5:
			continue
		if _flat_dist(p, Vector3(14.5, 0.0, -13.5)) < 7.5 or (p.x > 11.0 and p.x < 18.0 and p.z > -16.0 and p.z < 4.0):
			continue
		if _flat_dist(p, LAKE) < LAKE_R + 4.0 or _flat_dist(p, LAKE_SHACK) < 6.0 or _flat_dist(p, REPEATER) < 9.0 or _flat_dist(p, BUNKER) < 6.0 or _flat_dist(p, HELIPAD) < 9.5:
			continue
		var g := groves.get_noise_2d(p.x, p.z)
		var dens := smoothstep(-0.25, 0.3, g)                 # куртины и промежутки между ними
		if d_house < 24.0:
			dens *= 0.4                                       # двор открытый: деревья группками
		if glades.get_noise_2d(p.x, p.z) > 0.42:
			dens *= 0.12                                      # поляны
		if d_house > 55.0:
			dens = maxf(dens, 0.9)                            # дальняя стена
		if rng.randf() > dens:
			continue
		var cell := Vector2i(floori(p.x / 1.9), floori(p.z / 1.9))
		if occupied.has(cell):
			continue
		occupied[cell] = true
		var s := rng.randf_range(0.75, 1.6) if d_house < 55.0 else rng.randf_range(1.1, 1.9)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		transforms.append(Transform3D(b, p))
		var edge := dens < 0.6 and d_house < 55.0
		var kind := -1
		if edge:
			var r := rng.randf()
			kind = 3 if r < 0.22 else 2 if r < 0.45 else -1
			if rng.randf() < 0.12:
				edge_points.append(p)
		kinds.append(kind)
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

	var p_pos := p.global_position
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
		var near := 25.0 if cand["type"] == &"zherdyai" else 10.0
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


func _dismiss_zherdyai() -> void:
	if _outdoor_entity == null or not is_instance_valid(_outdoor_entity):
		return
	var pos := _outdoor_entity.global_position
	Game.audio.play_3d("res://assets/audio/tree_creak.ogg", pos, 1.5)
	var tw := create_tween()
	var back := _outdoor_entity.global_basis.z * 6.0
	tw.tween_property(_outdoor_entity, "global_position", pos + back, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
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
	# 1. Люк ледника в сугробе за северной стеной холодной кладовой (X=5.25, Z=-7.2)
	var cellar := Props.cellar_hatch()
	cellar.position = Vector3(5.25, 0.0, -7.2)
	add_child(cellar)

	var cellar_it := Geo.interactable(self, Vector3(1.6, 1.0, 1.8), Vector3(5.25, 0.5, -7.2), null, "", func(_p: Player) -> void:
		if not SaveGame.flags.get("cellar_searched", false):
			SaveGame.flags["cellar_searched"] = true
			Game.add_spare_flares(1)
			Game.audio.play_3d(CLANK_SOUND, Vector3(5.25, 0.4, -7.2), 0.0)
			Game.hud.subtitle(Loc.t(&"sub.cellar_open"), 5.5)
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

	# 3. Сугроб над крестом вертодрома — пологий намёт, как остальные сугробы двора (была коробка с углами)
	if Game.helipad_cleared:
		_build_helipad_heli()
		return
	var mound := SphereMesh.new()
	mound.radius = 1.0
	mound.height = 2.0
	mound.radial_segments = 28
	mound.rings = 10
	var drift_mesh := MeshInstance3D.new()
	drift_mesh.mesh = mound
	drift_mesh.material_override = Palette.m(&"drift")
	drift_mesh.position = HELIPAD + Vector3(0, -0.12, 0)
	drift_mesh.scale = Vector3(3.6, 0.42, 3.4)
	add_child(drift_mesh)
	# Намёт неровный: пара перемётов сверху — в осях сугроба (гаснут вместе с ним)
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
		Game.hud.subtitle(Loc.t(&"sub.helipad_ready"), 4.0)
		Game.audio.play_3d("res://assets/audio/snow_fall.ogg", HELIPAD, 0.0)
		# Расчищенный сугроб больше не стена: невидимая коробка 6×6 м закрывала вертолёт и его ящик
		_helipad_drift.collision_layer = 0
	)
	drift_it.prompt_provider = func() -> String:
		return "" if Game.helipad_cleared else Loc.t(&"task.helipad_prep")
	_helipad_drift = drift_it
	_build_helipad_heli()


func _build_helipad_heli() -> void:
	# 4. Появление вертолёта Ми-8 снабжения и эвакуации (Ночь 5 или День 5)
	if Game.night >= 5 and Game.helipad_cleared:
		_heli_node = Node3D.new()
		_heli_node.position = HELIPAD
		add_child(_heli_node)

		var heli_mesh := Props.mi8_helicopter()
		_heli_node.add_child(heli_mesh)

		_heli_audio = AudioStreamPlayer3D.new()
		_heli_audio.stream = AudioDirector.cached_stream("res://assets/audio/engine_loop.ogg")
		_heli_audio.unit_size = 6.0
		_heli_audio.max_distance = 60.0
		_heli_audio.volume_db = -4.0
		_heli_audio.bus = &"SFX"
		_heli_audio.autoplay = true
		_heli_node.add_child(_heli_audio)

		# Сброшенный ящик снабжения
		var crate_model := Props.supply_crate()
		crate_model.position = Vector3(2.6, 0, 1.2)
		_heli_node.add_child(crate_model)

		_heli_crate_it = Geo.interactable(_heli_node, Vector3(1.2, 1.0, 1.2), Vector3(2.6, 0.5, 1.2), null, Loc.t(&"it.heli_crate"), func(_p: Player) -> void:
			Game.flares += 4
			Game.canisters_left += 1
			Game.vibrate(0.4, 0.2, 0.25)
			Game.hud.subtitle(Loc.t(&"sub.heli_keeper"), 5.0)
			_heli_crate_it.queue_free()
		)





