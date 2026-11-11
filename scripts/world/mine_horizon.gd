class_name MineHorizon
extends Node3D
## Скрытый горизонт штольни «Горизонт-40» под POI 11 (модель tools/blender/mine_horizon.py).
## Вход — заваленный ходок в устье: о нём знаешь только с кассеты Дубова (скрытый слой плёнки).
## Разобрал завал — спуск по лестнице на 40 м. Внизу: штрек с крепью, рассечка к камере взрывников
## (схрон: ракетница и ракеты), западный тупик с вагонеткой, лаз через завал в забой — последняя
## стоянка Семёнова (записка, ушанка, зарубки — счёт ночей). Темно: светит только фонарь.

const ROOT := Vector3(145.0, -40.0, -140.0)          ## пол околоствольного двора
const ENTRY := Vector3(-2.3, 0.0, 1.7)               ## завал у устья — от центра POI 11
const DRIP := ["res://assets/sfx/cc0/drip_1.ogg", "res://assets/sfx/cc0/drip_3.ogg", "res://assets/sfx/cc0/drip_5.ogg"]
const COL := preload("res://scripts/data/mine_col.gd")

static var instance: MineHorizon

var _surface: Vector3
var _drip_t := 3.0
var _creak_t := 9.0
var _scared := {}
var _co2_timer := 0.0
var _rustle_t := 0.0
var _valenki_active := false
var _valenki_event_done := false
var _valenki_stand_timer := 0.0
var _valenki_node: Node3D = null
var _lbvk_flame_light: OmniLight3D = null


static func known() -> bool:
	return Game.has_flag("mine_adit_known")


static func is_open() -> bool:
	return Game.has_flag("mine_adit_open")


static func zone_has(pos: Vector3) -> bool:
	return pos.y < -20.0 and pos.y > -60.0 and absf(pos.x - ROOT.x) < 30.0 and absf(pos.z - (ROOT.z - 20.0)) < 32.0


func setup(surface_center: Vector3) -> void:
	_surface = surface_center


func _ready() -> void:
	instance = self
	name = "MineHorizon"
	if Models.spawn(self, "kedr/mine_horizon", ROOT, 0.0, -1.0, {"keep": true, "center": false, "grime": 0.0, "bright": 1.0, "sat": 1.0}) == null:
		push_warning("MineHorizon: нет модели kedr/mine_horizon")
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for b: Array in COL.BOXES:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(b[3], b[4], b[5])
		cs.shape = bs
		cs.position = ROOT + Vector3(b[0], b[1], b[2])
		body.add_child(cs)
	_build_entry()
	_build_inside()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		instance = null


# --- Вход в устье ------------------------------------------------------------------------

func _build_entry() -> void:
	var at := _surface + ENTRY
	at.y = Terrain.height(at.x, at.z) if Terrain.ready() else at.y

	# Бетонный оголовник с архивной надписью «МГ СССР • ГРП-14 • 1959 г.»
	var portal_header := Node3D.new()
	portal_header.position = at + Vector3(0.0, 2.45, 0.0)
	add_child(portal_header)
	Geo.block(portal_header, Vector3(2.6, 0.45, 0.4), Vector3.ZERO, Palette.m(&"concrete"), true)
	var lbl := Label3D.new()
	lbl.text = "МГ СССР • ГРП-14 • 1959 г."
	lbl.font_size = 36
	lbl.pixel_size = 0.0032
	lbl.modulate = Color(0.18, 0.16, 0.14)
	lbl.position = Vector3(0.0, 0.0, 0.21)
	portal_header.add_child(lbl)

	# Груда смёрзшихся камней и брёвен у левой стойки портала
	var rubble := Node3D.new()
	rubble.position = at
	add_child(rubble)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	for i in 9:
		var r := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 7
		sm.rings = 4
		r.mesh = sm
		r.material_override = Palette.m(&"concrete")
		r.scale = Vector3(rng.randf_range(0.25, 0.5), rng.randf_range(0.2, 0.4), rng.randf_range(0.25, 0.5))
		r.position = Vector3(rng.randf_range(-0.6, 0.6), r.scale.y * 0.6, rng.randf_range(-0.4, 0.4))
		r.name = "RubbleStone"
		rubble.add_child(r)
	var it := Geo.interactable(self, Vector3(1.6, 1.4, 1.2), at + Vector3(0, 0.7, 0), null, "", _on_entry)
	it.name = "MineAditEntry"
	it.prompt_provider = func() -> String:
		if is_open():
			return Loc.t(&"it.mine_descend")
		return Loc.t(&"it.mine_rubble_known") if known() else Loc.t(&"it.mine_rubble")
	it.hold_check = func() -> bool: return known() and not is_open()
	it.hold_time = 4.0
	it.hold_sound = "res://assets/audio/clank.ogg"
	# Разобранный завал прячем — открытый ходок
	if is_open():
		rubble.visible = false
	set_meta(&"rubble", rubble)


func _on_entry(p: Player) -> void:
	if not known():
		Game.hud.subtitle(Loc.t(&"sub.mine_rubble"), 4.0)
		return
	if not is_open():
		Game.set_flag("mine_adit_open", true)
		var rb: Node3D = get_meta(&"rubble")
		if rb != null:
			rb.visible = false
		Game.audio.play_3d("res://assets/audio/clank.ogg", p.global_position, 0.0)
		Game.hud.subtitle(Loc.t(&"sub.mine_opened"), 5.0)
		Director.add_tension(8.0, "ходок Горизонта-40 открыт")
		SaveGame.write()
		return
	await Game.hud.blink(0.6)
	p.global_position = ROOT + Vector3(0.0, 0.05, 0.6)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	if not Game.has_flag("mine_seen"):
		Game.set_flag("mine_seen", true)
		Game.hud.subtitle(Loc.t(&"sub.mine_in"), 7.0)


# --- Внутри ------------------------------------------------------------------------------

func _build_inside() -> void:
	var up := Geo.interactable(self, Vector3(0.8, 2.4, 0.4), ROOT + Vector3(0.0, 1.3, 1.7), null, Loc.t(&"it.mine_climb"), func(p: Player) -> void:
		if MineStory.is_active():   # сюжетная вылазка: выход — катсценой
			MineStory.instance.climb(p)
			return
		await Game.hud.blink(0.6)
		var out := _surface + ENTRY + Vector3(1.4, 0, -1.0)
		out.y = Terrain.height(out.x, out.z) + 0.05
		p.global_position = out
		p.velocity = Vector3.ZERO)
	up.name = "MineLadder"
	var cache := Geo.interactable(self, Vector3(1.4, 1.1, 1.5), ROOT + Vector3(19.0, 0.55, -15.8), null, "", _on_cache)
	cache.name = "MineCache"
	cache.prompt_provider = func() -> String:
		return Loc.t(&"it.mine_cache_empty") if Game.has_flag("mine_cache_taken") else Loc.t(&"it.mine_cache")
	var note := Geo.interactable(self, Vector3(0.6, 0.4, 0.6), ROOT + Vector3(0.9, 0.2, -42.4), null, Loc.t(&"it.mine_note"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.mine_semenov"))
		if not Game.has_flag("mine_note_read"):
			Game.set_flag("mine_note_read", true)
			Director.add_tension(12.0, "записка Семёнова в забое")
			SaveGame.write())
	note.name = "MineSemenovNote"
	# Лаз через завал в забой: на коленях, приседа в игре нет — переползаешь действием
	for side: Array in [[Vector3(0.0, 0.6, -35.7), Vector3(0.0, 0.05, -39.2), 180.0], [Vector3(0.0, 0.6, -38.9), Vector3(0.0, 0.05, -35.3), 0.0]]:
		var to: Vector3 = side[1]
		var yaw: float = side[2]
		var crawl := Geo.interactable(self, Vector3(1.0, 1.0, 0.6), ROOT + side[0], null, Loc.t(&"it.mine_crawl"), func(p: Player) -> void:
			Game.audio.play_3d("res://assets/sfx/cc0/step_crust_3.ogg", p.global_position, -4.0)
			await Game.hud.blink(0.9)
			p.global_position = ROOT + to
			p.rotation.y = deg_to_rad(yaw)
			p.velocity = Vector3.ZERO)
		crawl.name = "MineCrawl"
	var marks := Geo.interactable(self, Vector3(0.3, 0.8, 0.5), ROOT + Vector3(-1.85, 1.15, -40.0), null, Loc.t(&"it.mine_marks"), func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.mine_marks"), 6.0))
	marks.name = "MineMarks"
	# Узкоколейка (колея 600 мм, рельсы Р-18) по центру основного штрека от ствола до завала
	var rail_mat := Palette.m(&"metal_dark")
	var wood_mat := Palette.m(&"wood")
	Geo.block(self, Vector3(0.06, 0.07, 36.0), ROOT + Vector3(-0.3, 0.035, -18.0), rail_mat, false)
	Geo.block(self, Vector3(0.06, 0.07, 36.0), ROOT + Vector3(0.3, 0.035, -18.0), rail_mat, false)
	for k in range(30):
		var z_tie := -1.0 - float(k) * 1.2
		Geo.block(self, Vector3(0.95, 0.05, 0.16), ROOT + Vector3(0.0, 0.02, z_tie), wood_mat, false)

	# Водоотливная канавка с замерзшей охристой рудничной водой
	Geo.block(self, Vector3(0.35, 0.02, 36.0), ROOT + Vector3(0.9, 0.01, -18.0), Palette.m(&"lead"), false)

	# Сублимационные шестигранные кристаллы льда (гоже) в первых 15 метрах штольни
	var ice_mat := Palette.m(&"ice")
	for ice_i in range(8):
		var iz := -1.5 - float(ice_i) * 1.8
		var side_x := -1.1 if ice_i % 2 == 0 else 1.1
		var plate := Geo.block(self, Vector3(0.4, 0.35, 0.04), ROOT + Vector3(side_x, 2.1, iz), ice_mat, false)
		plate.rotation.z = deg_to_rad(15.0 if ice_i % 2 == 0 else -15.0)

	# Кернохранилище в боковой рассечке (рамы с ящиками)
	var rack := Props.core_storage_rack()
	rack.position = ROOT + Vector3(16.5, 0.0, -15.5)
	rack.rotation.y = deg_to_rad(90.0)
	add_child(rack)

	# Аутентичный советский керновый ящик экспедиции Дубова (1979 г.)
	var cb79 := Props.corebox_1979()
	cb79.position = ROOT + Vector3(16.5, 0.85, -14.2)
	cb79.rotation.y = deg_to_rad(90.0)
	add_child(cb79)

	var it_rack := Geo.interactable(self, Vector3(1.4, 1.2, 1.4), ROOT + Vector3(16.5, 0.7, -15.5), null, Loc.t(&"it.adit_core_rack"), func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"note.adit_core_anomaly"))
		Director.add_tension(10.0, "осмотр аномального керна в штольне")
		SaveGame.write())
	it_rack.name = "AditCoreRack"

	# Шахтный оптический интерферометр ШИ-11 на верстаке у ствола
	var shi11 := Props.shi11_interferometer()
	shi11.position = ROOT + Vector3(1.2, 0.75, -5.5)
	add_child(shi11)
	var it_shi := Geo.interactable(self, Vector3(0.6, 0.5, 0.6), ROOT + Vector3(1.2, 0.75, -5.5), null, Loc.t(&"it.shi11_interferometer"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"interferometer")
	)
	it_shi.name = "MineSHI11"

	# Радиометр СРП-68-01 с зондом БДГ-1 около кернохранилища
	var srp := Props.srp68_radiometer()
	srp.position = ROOT + Vector3(15.2, 0.65, -15.2)
	add_child(srp)
	var it_srp := Geo.interactable(self, Vector3(0.6, 0.5, 0.6), ROOT + Vector3(15.2, 0.65, -15.2), null, Loc.t(&"it.srp68_inspect"), func(_p: Player) -> void:
		AudioDirector.play_raw("res://assets/audio/clank.ogg", -4.0)
		AudioDirector.play_raw("res://assets/audio/radio_anomaly.ogg", 0.0)
		Game.hud.subtitle(Loc.t(&"srp68.reading_spike"), 5.5)
		Director.add_tension(12.0, "зашкал радиометра СРП-68-01")
	)
	it_srp.name = "MineSRP68"

	# Сейсмоприёмник СВ-20, вбитый штырём в скалу основного штрека
	var sv20 := Props.sv20_geophone()
	sv20.position = ROOT + Vector3(-1.1, 0.35, -20.0)
	add_child(sv20)
	var it_sv := Geo.interactable(self, Vector3(0.5, 0.5, 0.5), ROOT + Vector3(-1.1, 0.35, -20.0), null, Loc.t(&"it.sv20_listen"), func(_p: Player) -> void:
		EventBus.ui_requested.emit(&"seismograph")
	)
	it_sv.name = "MineSV20"

	# Забой: вмёрзший перфоратор ПР-30К, ящик аммонита, бензиновая лампа ЛБВК и светильник СГГ-3
	var drill := Props.pr30k_stoper_drill()
	drill.position = ROOT + Vector3(0.0, 0.0, -43.0)
	add_child(drill)

	var lbvk := Props.lbvk_safety_lamp()
	lbvk.position = ROOT + Vector3(0.65, 0.35, -42.8)
	add_child(lbvk)
	_lbvk_flame_light = lbvk.find_child("FlameLight", true, false) as OmniLight3D

	var sgg3 := Props.sgg3_headlamp()
	sgg3.position = ROOT + Vector3(-0.65, 0.1, -42.5)
	add_child(sgg3)

	# Опрокинутая вагонетка УВО-0.6 в западном тупике с кусками магнетита
	var car := Props.mine_cart_uvo06()
	if car != null:
		car.position = ROOT + Vector3(-7.2, 0.45, -26.0)
		car.rotation.z = deg_to_rad(75.0)
		add_child(car)
		for m_i in range(6):
			var mop := Geo.block(self, Vector3(0.2, 0.18, 0.22), ROOT + Vector3(-6.8 + float(m_i) * 0.25, 0.08, -26.0 + (float(m_i % 3) - 1.0) * 0.25), Palette.m(&"metal_dark"), false)
			mop.rotation.y = float(m_i) * 0.7

	# Старые шахтёрские фонари ФАС на стойках крепи: тусклые, тёплые, где-то мигают, один разбит.
	var spots := [Vector3(0.85, 1.6, -4.0), Vector3(-0.85, 1.6, -13.0), Vector3(0.85, 1.6, -21.0), Vector3(-0.85, 1.6, -30.0), Vector3(15.0, 1.6, -15.8), Vector3(-6.0, 1.6, -26.3)]
	for k in spots.size():
		var at: Vector3 = ROOT + spots[k]
		var lamp := Props.fas4_lantern()
		if lamp != null:
			lamp.position = at - Vector3(0, 0.25, 0)
			lamp.scale = Vector3.ONE * 0.8
			add_child(lamp)
		if k == 3:
			continue   # разбит — темнота у тупика
		var l := Geo.omni(self, at, 8.0, 1.6, Color(1.0, 0.72, 0.42))
		l.shadow_enabled = false
		if k % 2 == 1:
			var tw := l.create_tween().set_loops()
			tw.tween_property(l, "light_energy", 0.3, 0.06).set_delay(randf_range(1.5, 4.0))
			tw.tween_property(l, "light_energy", 1.6, 0.08)


func _on_cache(_p: Player) -> void:
	if Game.has_flag("mine_cache_taken"):
		Game.hud.subtitle(Loc.t(&"it.mine_cache_empty"), 2.5)
		return
	Game.set_flag("mine_cache_taken", true)
	Game.audio.play_3d("res://assets/audio/clank.ogg", ROOT + Vector3(19.0, 0.6, -15.8), -2.0)
	if not Game.has_item(&"flare_gun"):
		Game.give_item(&"flare_gun")
		Game.add_spare_flares(3)
		Game.hud.subtitle(Loc.t(&"sub.mine_cache_gun"), 6.0)
	else:
		Game.add_spare_flares(3)
		Game.hud.subtitle(Loc.t(&"sub.mine_cache_flares"), 5.0)
	if not Gear.has(&"lamp_kuzbass"):   # «Кузбасс» здесь же, если с маяка его ещё не взял
		Gear.grant.call_deferred(&"lamp_kuzbass")
	SaveGame.write()


func _process(delta: float) -> void:
	if Game.player == null or not zone_has(Game.player.global_position):
		if Game.player != null and not is_nan(Game.player.yaw_limit_base):
			Game.player.yaw_limit_base = NAN
		return
	var pp := Game.player.global_position
	var local := pp - ROOT

	# 1. Ночь 3: Просадка потолка до 1.45м, шарканье брезента рюкзака и гипоксия от CO2
	var in_deep_adit := local.z < -15.0
	if Game.night >= 3 and in_deep_adit:
		Game.player.target_head_y = 1.15
		Game.player.speed_mult = 0.5
		if Game.player.velocity.length() > 0.4:
			_rustle_t -= delta
			if _rustle_t <= 0.0:
				_rustle_t = randf_range(1.8, 3.5)
				Game.audio.play_3d("res://assets/sfx/cc0/coat_rustle.ogg", pp + Vector3(0, 0.3, 0), -4.0, 6.0)

		# Накопление «мертвого воздуха» (CO2)
		_co2_timer += delta
		var co2_factor := clampf(1.0 - (_co2_timer / 90.0), 0.08, 1.0)
		if _lbvk_flame_light != null:
			if local.z < -39.0 or Game.yrka_nearby:
				# Аномалия «Отзвук» / Ырка: неестественное фиолетово-зелёное пламя
				_lbvk_flame_light.light_color = Color(0.45, 0.15, 0.92)
				_lbvk_flame_light.light_energy = 1.6 + 0.3 * sin(_co2_timer * 8.0)
			else:
				_lbvk_flame_light.light_energy = 1.2 * co2_factor
				_lbvk_flame_light.light_color = Color(1.0, 0.8 * co2_factor, 0.4 + (1.0 - co2_factor) * 0.45)
		if _co2_timer >= 60.0 and not Game.has_flag("adit_dead_air_warned"):
			Game.set_flag("adit_dead_air_warned", true)
			Game.hud.subtitle(Loc.t(&"sub.adit_dead_air"), 5.0)
		if _co2_timer >= 90.0:
			Game.player.whiteout_panic = clampf(Game.player.whiteout_panic + delta * 0.12, 0.0, 0.75)
	else:
		if not (local.z < -35.2 and local.z > -39.2):
			Game.player.target_head_y = 1.58
			Game.player.speed_mult = 1.0
		_co2_timer = maxf(_co2_timer - delta * 2.5, 0.0)
		if _lbvk_flame_light != null:
			if Game.yrka_nearby:
				_lbvk_flame_light.light_color = Color(0.45, 0.15, 0.92)
				_lbvk_flame_light.light_energy = 1.5
			else:
				_lbvk_flame_light.light_energy = 1.2
				_lbvk_flame_light.light_color = Color(1.0, 0.8, 0.4)

	# 2. Ночь 5: Лаз через завал (ограничение поворота ±28°, осыпание породы при шуме, валенки на выходе)
	var in_crawl := (local.z < -35.2 and local.z > -39.2 and absf(local.x) < 1.2)
	if in_crawl:
		Game.player.target_head_y = 0.55
		Game.player.yaw_limit_base = deg_to_rad(180.0 if local.z > -37.2 else 0.0)
		Game.player.yaw_limit_half_angle = deg_to_rad(28.0)
		# Осыпание породы от динамо-фонарика
		if Game.player.cranking:
			if randf() < delta * 1.5:
				Game.audio.play_3d("res://assets/sfx/cc0/log_frost_crack_v2.ogg", pp + Vector3(0.3, 0.2, 0), -6.0, 5.0)

		# Обратный путь: валенки перекрывают выход из лаза
		if Game.night >= 5 and Game.has_flag("mine_note_read") and not _valenki_event_done:
			if local.z > -37.5 and not _valenki_active:
				_valenki_active = true
				_valenki_node = Props.valenki()
				_valenki_node.position = ROOT + Vector3(0.0, 0.0, -35.0)
				_valenki_node.rotation.y = deg_to_rad(180.0)
				add_child(_valenki_node)
				Game.audio.play_3d("res://assets/audio/knock_v3.ogg", _valenki_node.position, 1.0, 10.0)
				Game.hud.subtitle(Loc.t(&"sub.adit_valenki_blocked"), 5.0)
				Director.add_tension(15.0, "валенки перекрыли лаз")

			if _valenki_active:
				var breath_held: bool = Game.player.holding_breath
				var light_off: bool = not Game.player.flashlight.visible
				if breath_held and light_off:
					_valenki_stand_timer += delta
					if _valenki_stand_timer >= 8.0:
						_valenki_event_done = true
						_valenki_active = false
						if _valenki_node != null:
							_valenki_node.queue_free()
							_valenki_node = null
						Game.audio.play_3d("res://assets/sfx/cc0/step_crust_3.ogg", ROOT + Vector3(0, 0.2, -31.0), 0.0, 12.0)
						Game.hud.subtitle(Loc.t(&"sub.adit_valenki_left"), 4.5)
				else:
					_valenki_stand_timer = maxf(_valenki_stand_timer - delta * 0.5, 0.0)
	else:
		if not in_deep_adit:
			Game.player.yaw_limit_base = NAN

	# Капли и треск крепей
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = randf_range(1.5, 4.0)
		var at := pp + Vector3(randf_range(-6, 6), 2.2, randf_range(-6, 6))
		Game.audio.play_3d(DRIP[randi() % DRIP.size()], at, -6.0, 10.0)
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(10.0, 22.0)
		Game.audio.play_3d("res://assets/sfx/cc0/log_frost_crack_v2.ogg", pp + Vector3(randf_range(-8, 8), 2.0, randf_range(-8, 8)), -8.0, 14.0)

	# Тупик с вагонеткой: стук
	if local.x < -5.0 and local.z < -24.0 and local.z > -28.0 and not _scared.has(&"knock"):
		_scared[&"knock"] = true
		for k in 3:
			get_tree().create_timer(0.6 + k * 0.7, false).timeout.connect(func() -> void:
				Game.audio.play_3d("res://assets/audio/knock_v3.ogg", ROOT + Vector3(-10.5, 1.0, -26.0), 2.0, 14.0))
		Director.add_tension(10.0, "стук в тупике штольни")
	# Забой: шёпот
	if local.z < -40.0 and not _scared.has(&"whisper"):
		_scared[&"whisper"] = true
		Game.audio.play_3d("res://assets/audio/whisper.ogg", ROOT + Vector3(0.0, 1.0, -37.0), -2.0, 8.0)
		Game.hud.subtitle(Loc.t(&"pro.call_name"), 3.0)
		Director.add_tension(10.0, "шёпот в забое")
