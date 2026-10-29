class_name StationLore
extends Node3D
## Лор станции в мире: книги и бумаги (Books, BookUI), мелкие тайники, подпол Брагина под сундуком
## в жилой, замурованный кабинет Голубева (пристройка к восточной стене корпуса без окон, вход —
## через заколоченное окно архива) и кабельный тоннель из-под пола архива к бункеру «Отзвук».
## Подземелья и кабинет — отдельные коробки; переходы — люками и проёмами с затемнением.

const FL := MeteoCorpus.FL
const CAB := MeteoCorpus.CAB
const CELLAR := Vector3(0.0, -15.0, 3.0)
const TRUNK := Vector3(2.85, 0.0, 0.45)          ## сундук Брагина стоит на люке — в северо-восточном углу комнаты
const WALLED := Vector3(100.35, FL, -26.7)       ## центр пола кабинета Голубева
const ARCHIVE_WIN := Vector3(98.5, FL, -27.2)    ## заколоченное окно архива (изнутри)
const TUN_Y := -30.0
const TUN_X := 96.5                              ## ствол тоннеля под корпусом (на юг)
const TUN_Z := 12.0                              ## колено к бункеру (на запад)
const TUN_N := -27.5
const TUN_W := 72.4                              ## торец у восточной стены зала «Отзвука»
const HATCH_ARCHIVE := Vector3(97.2, FL, -28.75)
const SAFE_CODE := "2207"                        ## день рождения Нади (дневник Голубева)

var _trunk: Interactable
var _hatch: Interactable
var _lamps: Array[OmniLight3D] = []
var _step_acc := 0.0
var _last_pos := Vector3.INF
var _echo_steps := 0
var _echo_t := 0.0
var _bang_done := false
var _cellar_t := -1.0
var _t := 0.0


func _ready() -> void:
	_place_books()
	_build_trunk_and_cellar()
	_build_small_caches()
	_build_walled_room()
	_build_tunnel()


## Где игрок: подпол, тоннель, кабинет Голубева (Yard.zone_at спрашивает раньше остального).
static func zone_at(p: Vector3) -> StringName:
	if p.y < -10.0 and p.y > -20.0 and absf(p.x - CELLAR.x) < 2.2 and absf(p.z - CELLAR.z) < 2.2:
		return &"cellar"
	if p.y < -25.0:
		if (p.x > TUN_X - 1.2 and p.x < TUN_X + 1.2 and p.z > TUN_N - 0.2 and p.z < TUN_Z + 1.2) \
				or (p.z > TUN_Z - 1.2 and p.z < TUN_Z + 1.2 and p.x > TUN_W - 0.2 and p.x < TUN_X + 1.2):
			return &"tunnel"
	if p.y > 0.2 and p.y < 3.5 and p.x > 99.0 and p.x < 101.7 and p.z > -28.4 and p.z < -25.0:
		return &"walled"
	return &""


# --- Общее -------------------------------------------------------------------------------

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, collide := true) -> Node3D:
	return Geo.block(self, size, pos, mat, collide)


func _text(text: String, pos: Vector3, yaw: float, size := 0.006, col := Color(0.88, 0.88, 0.84, 0.85)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiStyle.hand_font()
	l.font_size = 96
	l.pixel_size = size
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	add_child(l)
	return l


## Переход: затемнение, игрок — в точку, лицом по yaw.
static func go(to: Vector3, yaw: float, sfx := "res://assets/audio/clank.ogg") -> void:
	var p := Game.player
	if p == null:
		return
	Game.audio.play_2d(sfx, -8.0)
	await Game.hud.blink(0.45)
	p.global_position = to
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO


## Тайник: держишь E — открывается, потом виден документ.
func _cache(size: Vector3, pos: Vector3, flag: String, prompt_key: StringName, hold: float, on_open: Callable) -> Interactable:
	var it := Geo.interactable(self, size, pos, null, "", Callable())
	it.hold_time = hold
	it.hold_sound = "res://assets/sfx/scratch_wall.ogg"
	it.prompt_provider = func() -> String: return Loc.t(prompt_key)
	it.used.connect(func(_p: Player) -> void:
		Game.set_flag(flag, true)
		Game.audio.play_3d("res://assets/audio/clank.ogg", pos, -6.0)
		on_open.call()
		it.queue_free())
	if Game.has_flag(flag):
		on_open.call()
		it.queue_free()
	return it


# --- Книги на виду ---------------------------------------------------------------------

func _place_books() -> void:
	BookUI.place(self, &"permyakov", Vector3(1.0, 0.76, 3.85), 12.0)            # стол в жилой
	BookUI.place(self, &"gazeta", Vector3(-1.25, 0.47, 5.6), -20.0)             # на кровати
	BookUI.place(self, &"nastavlenie", Vector3(94.3, FL + 0.78, -30.0), 80.0)   # стол с барографом
	BookUI.place(self, &"vahta", Vector3(91.45, FL + 0.78, -24.4), 5.0)         # стол в кабинете наблюдателя
	BookUI.place(self, &"krossvord", Vector3(95.2, CAB + 0.79, -37.95), 30.0)   # стол в кабине башни


# --- Подпол Брагина -----------------------------------------------------------------------

func _build_trunk_and_cellar() -> void:
	var wood := _mat(Color(0.24, 0.16, 0.1))
	var iron := Palette.m(&"metal")
	# Люк (виден, когда сундук сдвинут): доски, кольцо, гвозди-двухсотки
	var hatch_vis := Node3D.new()
	hatch_vis.position = TRUNK
	add_child(hatch_vis)
	var hb := Geo.box_mesh(Vector3(0.9, 0.025, 0.75), _mat(Color(0.19, 0.13, 0.08)))
	hb.position.y = 0.012
	hatch_vis.add_child(hb)
	for k in 4:
		var seam := Geo.box_mesh(Vector3(0.9, 0.03, 0.012), Palette.m(&"dark"))
		seam.position = Vector3(0, 0.014, -0.28 + k * 0.19)
		hatch_vis.add_child(seam)
	var ring := Geo.box_mesh(Vector3(0.12, 0.03, 0.03), iron)
	ring.position = Vector3(0.25, 0.03, 0)
	hatch_vis.add_child(ring)
	_hatch = Geo.interactable(self, Vector3(0.9, 0.2, 0.75), TRUNK + Vector3(0, 0.1, 0), null, "", _on_cellar_hatch)
	_hatch.prompt_provider = func() -> String:
		return Loc.t(&"it.bcellar_night") if Game.is_night() else Loc.t(&"it.bcellar")
	_hatch.collision_layer = 0
	# Сундук на люке
	_trunk = Geo.interactable(self, Vector3(0.95, 0.55, 0.55), TRUNK + Vector3(0, 0.275, 0), null, "", Callable())
	var chest := Props._kedr_model("bragin_chest", {"bright": 1.15})
	if chest != null:
		chest.position.y = -0.275
		_trunk.add_child(chest)
	_trunk.hold_time = 2.2
	_trunk.hold_sound = "res://assets/sfx/scratch_wall.ogg"
	# Сдвинуть можно, только когда знаешь, что под ним (записка Семёнова за фото); в прологе — просто сундук
	_trunk.prompt_provider = func() -> String: return Loc.t(&"it.trunk") if _trunk_known() else ""
	_trunk.used.connect(func(_p: Player) -> void:
		if _trunk_known():
			_move_trunk(true))
	if Game.has_flag("trunk_moved"):
		_move_trunk(false)

	# Сам подпол — коробка под землёй
	var earth := _mat(Color(0.2, 0.15, 0.11))
	var c := CELLAR
	_box(Vector3(3.6, 0.3, 3.6), c + Vector3(0, -0.15, 0), earth)
	_box(Vector3(3.6, 0.3, 3.6), c + Vector3(0, 2.25, 0), earth)
	for s: int in [-1, 1]:
		_box(Vector3(0.3, 2.4, 3.6), c + Vector3(s * 1.65, 1.05, 0), earth)
		_box(Vector3(3.6, 2.4, 0.3), c + Vector3(0, 1.05, s * 1.65), earth)
	# Лесенка в три ступеньки к люку
	for k in 3:
		_box(Vector3(0.8, 0.05, 0.25), c + Vector3(0.0, 0.5 + k * 0.55, -1.3 + k * 0.05), wood, false)
	for s: int in [-1, 1]:
		_box(Vector3(0.06, 2.2, 0.06), c + Vector3(s * 0.42, 1.1, -1.35), wood, false)
	var up := Geo.interactable(self, Vector3(0.9, 2.0, 0.4), c + Vector3(0, 1.0, -1.3), null, "", func(_p: Player) -> void:
		go(TRUNK + Vector3(0, 0.05, 0.75), PI))
	up.prompt_provider = func() -> String: return Loc.t(&"it.bcellar_up")
	# Полки с банками у восточной стены
	var jar := _mat(Color(0.32, 0.38, 0.16))
	jar.roughness = 0.2
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	for row in 3:
		var y := 0.35 + row * 0.55
		_box(Vector3(0.35, 0.04, 2.6), c + Vector3(1.3, y, 0.2), wood, false)
		for k in 7:
			if rng.randf() < 0.25:
				continue
			Geo.cylinder(self, 0.06, rng.randf_range(0.16, 0.24), c + Vector3(1.3, y + 0.12, -0.9 + k * 0.34), jar, false)
	BookUI.place(self, &"bragin", c + Vector3(1.28, 1.47, 1.1), 80.0)
	# Пол изнутри исцарапан, на стене — выскобленное
	_text(Loc.t(&"lore.cellar_wall"), c + Vector3(-1.48, 1.3, 0.2), PI * 0.5, 0.004, Color(0.55, 0.45, 0.36, 0.9))
	for k in 6:
		var scr := Geo.box_mesh(Vector3(0.012, 0.6, 0.012), Palette.m(&"dark"))
		scr.position = c + Vector3(-0.3 + k * 0.08, 2.08, -0.9)
		scr.rotation.z = 0.15 * (k - 3)
		scr.rotation.x = PI * 0.5
		add_child(scr)


func _trunk_known() -> bool:
	return not Game.is_prologue() and Books.is_read(&"semenov_photo")


func _move_trunk(animate: bool) -> void:
	Game.set_flag("trunk_moved", true)
	var to := TRUNK + Vector3(-0.15, 0.275, 0.85)
	if animate:
		var tw := create_tween()
		tw.tween_property(_trunk, "position", to, 0.8).set_trans(Tween.TRANS_SINE)
		Game.hud.subtitle(Loc.t(&"sub.trunk_moved"), 4.0)
	else:
		_trunk.position = to
	_trunk.hold_time = 0.0
	_trunk.prompt_provider = func() -> String: return ""
	_hatch.collision_layer = Geo.LAYER_INTERACT


func _on_cellar_hatch(_p: Player) -> void:
	go(CELLAR + Vector3(0, 0.05, -0.6), PI, "res://assets/sfx/door_handle.ogg")
	_cellar_t = 0.0
	if not Game.has_flag("cellar_seen"):
		Game.set_flag("cellar_seen", true)
		Game.hud.subtitle(Loc.t(&"sub.cellar_in"), 5.0)


# --- Мелкие тайники -----------------------------------------------------------------------

func _build_small_caches() -> void:
	# Радиорубка: пустая панель у перегородки коридора — записка Семёнова и фото
	var panel_pos := Vector3(5.0, 1.15, 2.07)
	var panel := _box(Vector3(0.55, 0.65, 0.03), panel_pos, _mat(Color(0.32, 0.36, 0.3)), false)
	_cache(Vector3(0.6, 0.7, 0.2), panel_pos, "cache_panel", &"it.cache_panel", 1.2, func() -> void:
		panel.position = Vector3(5.2, 0.02, 1.7)
		panel.rotation = Vector3(PI * 0.5, 0.3, 0)
		_box(Vector3(0.5, 0.6, 0.05), panel_pos + Vector3(0, 0, 0.04), Palette.m(&"dark"), false)
		BookUI.place(self, &"semenov_photo", panel_pos + Vector3(0, -0.28, 0.0), 0.0))
	# Кладовая: отходит плинтус — неотправленное письмо Тамары
	var plinth := Vector3(5.3, 0.06, -5.48)
	_box(Vector3(0.9, 0.1, 0.03), plinth, _mat(Color(0.2, 0.16, 0.12)), false)
	_cache(Vector3(0.9, 0.25, 0.25), plinth, "cache_plinth", &"it.cache_plinth", 1.5, func() -> void:
		BookUI.place(self, &"pismo", Vector3(5.3, 0.0, -5.2), 25.0))
	# Чердак: коробка из-под посылки за трубой — письма Ерёминой
	var box_pos := Vector3(11.4, Station.HOUSE_ATTIC_Y + 0.04, 3.3)
	var crate := Props.crate()
	crate.position = box_pos
	crate.scale = Vector3.ONE * 0.6
	add_child(crate)
	_cache(Vector3(0.7, 0.6, 0.7), box_pos + Vector3(0, 0.3, 0), "cache_attic", &"it.cache_attic", 0.8, func() -> void:
		BookUI.place(self, &"eremina", box_pos + Vector3(0.0, 0.52, 0.0), -15.0))
	# Корпус, кабинет наблюдателя: двойное дно ящика стола — приказ в/ч 03110
	_cache(Vector3(0.6, 0.22, 0.4), Vector3(91.0, FL + 0.55, -24.0), "cache_drawer", &"it.cache_drawer", 2.0, func() -> void:
		BookUI.place(self, &"order", Vector3(90.7, FL + 0.78, -23.95), -8.0))


# --- Кабинет Голубева (1979) ---------------------------------------------------------------

func _build_walled_room() -> void:
	var plaster := _mat(Color(0.7, 0.69, 0.64))
	var inner := _mat(Color(0.62, 0.66, 0.68))
	var x0 := 99.0
	var x1 := 101.9
	var z0 := -28.6
	var z1 := -24.8
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	# Снаружи: глухой объём без окон, кирпичный цоколь, плоская кровля под снегом
	_box(Vector3(x1 - x0, FL, z1 - z0), Vector3(cx, FL * 0.5, cz), _mat(Color(0.45, 0.43, 0.4)))
	_box(Vector3(0.3, 3.0, z1 - z0), Vector3(x1 - 0.15, FL + 1.5, cz), plaster)
	_box(Vector3(x1 - x0, 3.0, 0.3), Vector3(cx, FL + 1.5, z0 + 0.15), plaster)
	_box(Vector3(x1 - x0, 3.0, 0.3), Vector3(cx, FL + 1.5, z1 - 0.15), plaster)
	_box(Vector3(x1 - x0 + 0.1, 0.25, z1 - z0 + 0.1), Vector3(cx, FL + 3.12, cz), _mat(Color(0.3, 0.3, 0.3)))
	_box(Vector3(x1 - x0, 0.12, z1 - z0), Vector3(cx, FL + 3.3, cz), Palette.m(&"snow"), false)
	# Внутри: побелка под инеем
	for s: Array in [[Vector3(0.02, 2.9, z1 - z0 - 0.6), Vector3(x1 - 0.31, FL + 1.45, cz)],
			[Vector3(x1 - x0 - 0.6, 2.9, 0.02), Vector3(cx, FL + 1.45, z0 + 0.31)],
			[Vector3(x1 - x0 - 0.6, 2.9, 0.02), Vector3(cx, FL + 1.45, z1 - 0.31)]]:
		_box(s[0], s[1], inner, false)
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.82, 0.9, 0.97, 0.45)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.roughness = 0.3
	var rng := RandomNumberGenerator.new()
	rng.seed = 1979
	for k in 70:
		var on_x := rng.randf() < 0.4
		var p := Vector3(x1 - 0.33, FL + rng.randf_range(0.2, 2.8), rng.randf_range(z0 + 0.4, z1 - 0.4)) if on_x \
			else Vector3(rng.randf_range(x0 + 0.2, x1 - 0.4), FL + rng.randf_range(0.2, 2.8), z0 + 0.33 if rng.randf() < 0.5 else z1 - 0.33)
		var a := rng.randf_range(0.05, 0.22)
		var b := rng.randf_range(0.05, 0.22)
		_box(Vector3(0.015, a, b) if on_x else Vector3(a, b, 0.015), p, ice, false)
	for k in 14:   # сосульки с потолка
		var ic := Geo.box_mesh(Vector3(0.025, rng.randf_range(0.08, 0.3), 0.025), Palette.m(&"ice"))
		ic.position = Vector3(rng.randf_range(x0 + 0.2, x1 - 0.4), FL + 2.85, rng.randf_range(z0 + 0.4, z1 - 0.4))
		add_child(ic)
	# Стол, стул с ватником, стакан чая во льду, календарь, сейф
	var desk := Props.desk()
	desk.position = Vector3(101.15, FL, -27.3)
	desk.rotation.y = -PI * 0.5
	add_child(desk)
	var chair := Props.chair()
	chair.position = Vector3(100.5, FL, -27.3)
	chair.rotation.y = PI * 0.5
	add_child(chair)
	_box(Vector3(0.42, 0.55, 0.12), Vector3(100.36, FL + 0.75, -27.3), _mat(Color(0.18, 0.21, 0.15)), false)   # ватник на спинке
	var warm := Geo.interactable(self, Vector3(0.5, 0.6, 0.5), Vector3(100.5, FL + 0.4, -27.3), null, "", func(_p: Player) -> void:
		Game.hud.subtitle(Loc.t(&"sub.walled_chair"), 4.5)
		Game.audio.play_2d("res://assets/audio/whisper.ogg", -10.0)
		Director.add_tension(8.0, "тёплый стул Голубева"))
	warm.prompt_provider = func() -> String: return Loc.t(&"it.walled_chair")
	var glass := Geo.box_mesh(Vector3(0.07, 0.11, 0.07), _mat(Color(0.55, 0.32, 0.12)))
	glass.position = Vector3(101.25, FL + 0.81, -26.85)
	add_child(glass)
	_box(Vector3(0.02, 0.5, 0.36), Vector3(x1 - 0.32, FL + 1.65, -27.3), Palette.m(&"paper"), false)
	_text(Loc.t(&"lore.calendar"), Vector3(x1 - 0.335, FL + 1.78, -27.3), -PI * 0.5, 0.0016, Color(0.15, 0.13, 0.12))
	_text("8", Vector3(x1 - 0.335, FL + 1.55, -27.3), -PI * 0.5, 0.0032, Color(0.6, 0.08, 0.06))
	BookUI.place(self, &"golubev", Vector3(101.1, FL + 0.76, -27.55), 95.0)
	var safe := Props.safe()
	safe.position = Vector3(99.45, FL, -28.05)
	add_child(safe)
	var safe_it := Geo.interactable(self, Vector3(0.6, 0.9, 0.6), Vector3(99.45, FL + 0.45, -28.05), null, "", func(_p: Player) -> void:
		if Game.has_flag("safe_open"):
			BookUI.pending_id = &"report"
			EventBus.ui_requested.emit(&"book")
			return
		SafeUI.code = SAFE_CODE
		SafeUI.on_open = _on_safe_open
		EventBus.ui_requested.emit(&"safe"))
	safe_it.prompt_provider = func() -> String:
		return Loc.t(&"it.gsafe_open") if Game.has_flag("safe_open") else Loc.t(&"it.gsafe_locked")

	# Вход — заколоченное окно архива; изнутри — обратно
	var gap := _box(Vector3(0.04, 1.15, 1.05), Vector3(98.57, FL + 1.45, -27.2), Palette.m(&"dark"), false)
	gap.visible = Game.has_flag("walled_open")
	var win := Geo.interactable(self, Vector3(0.3, 1.3, 1.2), ARCHIVE_WIN + Vector3(-0.05, 1.45, 0), null, "", func(_p: Player) -> void:
		if not Game.has_flag("walled_open"):
			Game.set_flag("walled_open", true)
			gap.visible = true
			for k in 3:
				_box(Vector3(0.04, 0.12, 1.1), Vector3(98.2 - k * 0.12, FL + 0.06 + k * 0.03, -27.6 + k * 0.25), _mat(Color(0.3, 0.24, 0.17)), false)
		go(Vector3(99.6, FL + 0.05, -27.0), -PI * 0.5, "res://assets/sfx/scratch_wall.ogg")
		_on_walled_enter())
	win.hold_time = 3.5
	win.hold_sound = "res://assets/sfx/scratch_wall.ogg"
	win.prompt_provider = func() -> String:
		win.hold_time = 0.0 if Game.has_flag("walled_open") else 3.5
		return Loc.t(&"it.walled_go") if Game.has_flag("walled_open") else Loc.t(&"it.walled_boards")
	var back := Geo.interactable(self, Vector3(0.3, 1.3, 1.2), Vector3(99.2, FL + 1.45, -27.2), null, "", func(_p: Player) -> void:
		go(ARCHIVE_WIN + Vector3(-0.8, 0.05, 0), PI * 0.5, "res://assets/sfx/scratch_wall.ogg"))
	back.prompt_provider = func() -> String: return Loc.t(&"it.walled_back")


func _on_walled_enter() -> void:
	if Game.has_flag("walled_seen"):
		return
	Game.set_flag("walled_seen", true)
	await get_tree().create_timer(1.2, false).timeout
	Game.hud.subtitle(Loc.t(&"sub.walled_in"), 6.0)
	await get_tree().create_timer(6.5, false).timeout
	if Game.zone == &"walled":
		Game.audio.play_3d("res://assets/audio/whisper.ogg", ARCHIVE_WIN + Vector3(-1.5, 1.5, 0), 0.0, 6.0)
		Game.hud.subtitle(Loc.t(&"sub.walled_voice"), 4.0)
		Director.add_tension(14.0, "Надин голос из архива")


func _on_safe_open() -> void:
	Game.set_flag("safe_open", true)
	SaveGame.write()
	Game.audio.play_2d("res://assets/audio/clank.ogg", -2.0)
	BookUI.place(self, &"report", Vector3(99.45, FL + 0.95, -28.05), 10.0)


# --- Тоннель к «Отзвуку» -------------------------------------------------------------------

func _build_tunnel() -> void:
	var conc := Palette.m(&"concrete")
	var y := TUN_Y
	var h := 2.4
	var a_len := TUN_Z + 1.1 - TUN_N
	var a_cz := (TUN_N + TUN_Z + 1.1) * 0.5
	var b_len := TUN_X + 1.1 - TUN_W
	var b_cx := (TUN_W + TUN_X + 1.1) * 0.5
	# Ствол A (на юг) и колено B (на запад)
	_box(Vector3(2.5, 0.3, a_len + 0.3), Vector3(TUN_X, y - 0.15, a_cz), conc)
	_box(Vector3(2.5, 0.3, a_len + 0.3), Vector3(TUN_X, y + h + 0.15, a_cz), conc)
	_box(Vector3(0.3, h, TUN_Z - 1.1 - TUN_N), Vector3(TUN_X - 1.25, y + h * 0.5, (TUN_N + TUN_Z - 1.1) * 0.5), conc)
	_box(Vector3(0.3, h, a_len + 0.3), Vector3(TUN_X + 1.25, y + h * 0.5, a_cz), conc)
	_box(Vector3(2.5, h, 0.3), Vector3(TUN_X, y + h * 0.5, TUN_N - 0.15), conc)
	_box(Vector3(b_len, 0.3, 2.5), Vector3(b_cx, y - 0.15, TUN_Z), conc)
	_box(Vector3(b_len, 0.3, 2.5), Vector3(b_cx, y + h + 0.15, TUN_Z), conc)
	_box(Vector3(b_len + 0.3, h, 0.3), Vector3(b_cx, y + h * 0.5, TUN_Z + 1.25), conc)
	_box(Vector3(TUN_X - 1.1 - TUN_W, h, 0.3), Vector3((TUN_W + TUN_X - 1.1) * 0.5, y + h * 0.5, TUN_Z - 1.25), conc)
	_box(Vector3(0.3, h, 2.5), Vector3(TUN_W - 0.15, y + h * 0.5, TUN_Z), conc)
	# Кабельные полки вдоль стены (оцинковка на кронштейнах) с толстыми кабелями в резине, мёртвые светильники, лужи
	_cable_run(Vector3(TUN_X + 1.05, y, TUN_N + 0.4), Vector3(TUN_X + 1.05, y, TUN_Z + 1.0), Vector3(-1, 0, 0))
	_cable_run(Vector3(TUN_X + 1.0, y, TUN_Z - 1.05), Vector3(TUN_W + 0.3, y, TUN_Z - 1.05), Vector3(0, 0, 1))
	var water := _mat(Color(0.16, 0.18, 0.19, 0.85))
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.04
	water.metallic_specular = 1.0
	var lamp_pts: Array[Vector3] = []
	var z := TUN_N + 3.0
	while z < TUN_Z - 1.0:
		lamp_pts.append(Vector3(TUN_X, y + h - 0.12, z))
		z += 6.5
	var x := TUN_X - 4.0
	while x > TUN_W + 1.0:
		lamp_pts.append(Vector3(x, y + h - 0.12, TUN_Z))
		x -= 6.5
	for i in lamp_pts.size():
		# Светильник «НСП» в решётке: корпус, колпак, проволочная сетка
		_box(Vector3(0.22, 0.06, 0.22), lamp_pts[i] + Vector3(0, 0.07, 0), _mat(Color(0.3, 0.32, 0.3)), false)
		var cap := Geo.cylinder(self, 0.1, 0.14, lamp_pts[i] - Vector3(0, 0.02, 0), _mat(Color(0.7, 0.72, 0.66, 0.85)), false)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for a in 4:
			var wire := Geo.box_mesh(Vector3(0.012, 0.16, 0.012), Palette.m(&"metal"))
			wire.position = lamp_pts[i] + Vector3(cos(a * PI * 0.5) * 0.11, -0.02, sin(a * PI * 0.5) * 0.11)
			add_child(wire)
		if i == 2 or i == 7:   # горят две лампы из всех — и те моргают
			var l := Geo.omni(self, lamp_pts[i] - Vector3(0, 0.2, 0), 6.0, 0.55, Color(1.0, 0.82, 0.55))
			l.shadow_enabled = false
			_lamps.append(l)
		if i % 3 == 1:
			_puddle(Vector3(lamp_pts[i].x + 0.2, y + 0.004, lamp_pts[i].z - 0.3), water, i)
	# Надписи мелом
	_text(Loc.t(&"lore.chalk_1"), Vector3(TUN_X - 1.09, y + 1.4, TUN_N + 12.0), PI * 0.5)
	_text(Loc.t(&"lore.chalk_2"), Vector3(TUN_X, y + 1.3, TUN_Z + 1.09), PI, 0.0045)
	_text(Loc.t(&"lore.chalk_3"), Vector3(TUN_X - 16.0, y + 1.5, TUN_Z - 1.09), 0.0, 0.007, Color(0.85, 0.82, 0.78, 0.9))
	# Ниша с подписками: стенки и задник из того же бетона, только темнее (сырость), полка, рамка из уголка
	var damp := _mat(Color(0.26, 0.26, 0.24))
	_box(Vector3(0.02, 0.6, 0.7), Vector3(TUN_X + 1.19, y + 1.2, -4.0), damp, false)
	for s2: float in [-0.35, 0.35]:
		_box(Vector3(0.14, 0.6, 0.02), Vector3(TUN_X + 1.12, y + 1.2, -4.0 + s2), damp, false)
	_box(Vector3(0.14, 0.02, 0.7), Vector3(TUN_X + 1.12, y + 1.5, -4.0), damp, false)
	_box(Vector3(0.3, 0.04, 0.6), Vector3(TUN_X + 1.0, y + 0.92, -4.0), _mat(Color(0.3, 0.3, 0.28)), false)
	for e: Array in [[Vector3(0.03, 0.66, 0.03), Vector3(0, 0, -0.37)], [Vector3(0.03, 0.66, 0.03), Vector3(0, 0, 0.37)], [Vector3(0.03, 0.03, 0.77), Vector3(0, 0.32, 0)]]:
		_box(e[0], Vector3(TUN_X + 1.06, y + 1.2, -4.0) + e[1], Palette.m(&"metal"), false)
	BookUI.place(self, &"personnel", Vector3(TUN_X + 0.98, y + 0.94, -4.0), 90.0)

	# Вход: половицы у северной стены архива ходят → люк
	for k in 5:
		var scr := Geo.box_mesh(Vector3(0.5, 0.004, 0.01), Palette.m(&"dark"))
		scr.position = HATCH_ARCHIVE + Vector3(0.0, 0.004, -0.2 + k * 0.1)
		scr.rotation.y = 0.25 * (k - 2)
		add_child(scr)
	var hatch_vis := _box(Vector3(0.8, 0.02, 0.7), HATCH_ARCHIVE + Vector3(0, 0.01, 0), _mat(Color(0.12, 0.1, 0.08)), false)
	hatch_vis.visible = Game.has_flag("tunnel_open")
	var hatch := Geo.interactable(self, Vector3(0.8, 0.25, 0.7), HATCH_ARCHIVE + Vector3(0, 0.12, 0), null, "", func(_p: Player) -> void:
		if not Game.has_flag("tunnel_open"):
			Game.set_flag("tunnel_open", true)
			hatch_vis.visible = true
			Game.audio.play_3d("res://assets/sfx/scratch_wall.ogg", HATCH_ARCHIVE, -2.0)
			Game.hud.subtitle(Loc.t(&"sub.tunnel_found"), 5.0)
			return
		go(Vector3(TUN_X, y + 0.05, TUN_N + 1.0), PI)
		if not Game.has_flag("tunnel_seen"):
			Game.set_flag("tunnel_seen", true)
			Game.hud.subtitle(Loc.t(&"sub.tunnel_in"), 6.0))
	hatch.hold_time = 0.0 if Game.has_flag("tunnel_open") else 2.5
	hatch.hold_sound = "res://assets/sfx/scratch_wall.ogg"
	hatch.prompt_provider = func() -> String:
		hatch.hold_time = 0.0 if Game.has_flag("tunnel_open") else 2.5
		return Loc.t(&"it.tunnel_down") if Game.has_flag("tunnel_open") else Loc.t(&"it.tunnel_boards")
	# Скобы наверх у северного торца: П-образные, ножками в бетон; ржавые потёки под ними
	for k in 6:
		var sy := y + 0.35 + k * 0.38
		_box(Vector3(0.44, 0.035, 0.035), Vector3(TUN_X, sy, TUN_N + 0.16), Palette.m(&"metal"), false)
		for sx: float in [-0.21, 0.21]:
			_box(Vector3(0.035, 0.035, 0.17), Vector3(TUN_X + sx, sy, TUN_N + 0.08), Palette.m(&"metal"), false)
		_box(Vector3(0.05, 0.25, 0.005), Vector3(TUN_X + 0.21, sy - 0.14, TUN_N + 0.003), _mat(Color(0.32, 0.17, 0.09, 0.7)), false)
	var up := Geo.interactable(self, Vector3(0.7, 2.2, 0.4), Vector3(TUN_X, y + 1.1, TUN_N + 0.25), null, "", func(_p: Player) -> void:
		go(HATCH_ARCHIVE + Vector3(0, 0.05, 0.7), PI))
	up.prompt_provider = func() -> String: return Loc.t(&"it.tunnel_up")
	# Торцы: гермодверь в зал «Отзвука» и обратно
	_box(Vector3(0.08, 2.0, 1.1), Vector3(TUN_W + 0.04, y + 1.0, TUN_Z), _mat(Color(0.22, 0.26, 0.22)), false)
	var door := Geo.interactable(self, Vector3(0.4, 2.0, 1.2), Vector3(TUN_W + 0.3, y + 1.0, TUN_Z), null, "", func(_p: Player) -> void:
		go(Vector3(70.8, y + 0.05, TUN_Z), PI * 0.5, "res://assets/sfx/door_handle.ogg"))
	door.prompt_provider = func() -> String: return Loc.t(&"it.tunnel_door")
	_box(Vector3(0.06, 2.0, 1.1), Vector3(71.82, y + 1.0, TUN_Z), _mat(Color(0.22, 0.26, 0.22)), false)
	var door_b := Geo.interactable(self, Vector3(0.4, 2.0, 1.2), Vector3(71.55, y + 1.0, TUN_Z), null, "", func(_p: Player) -> void:
		go(Vector3(TUN_W + 1.0, y + 0.05, TUN_Z), -PI * 0.5, "res://assets/sfx/door_handle.ogg"))
	door_b.prompt_provider = func() -> String: return Loc.t(&"it.tunnel_door_back")


## Кабельная полка вдоль стены от a до b: кронштейны каждые 1.5 м, лоток, три кабеля в резине (не чисто-чёрные).
## inward — от стены в тоннель.
func _cable_run(a: Vector3, b: Vector3, inward: Vector3) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var yaw := atan2(dir.x, dir.z)
	var mid := (a + b) * 0.5
	var steel := Palette.m(&"metal")
	var rubber := _mat(Color(0.13, 0.13, 0.12))
	rubber.roughness = 0.6
	var n := int(length / 1.5)
	for k in n + 1:
		var p := a.lerp(b, float(k) / maxf(n, 1))
		for hy: float in [1.55, 1.85]:
			var br := Geo.box_mesh(Vector3(0.03, 0.03, 0.22), steel)
			br.position = p + Vector3(0, hy, 0) + inward * 0.06
			br.rotation.y = atan2(inward.x, inward.z)
			add_child(br)
	for hy: float in [1.57, 1.87]:
		var tray := Geo.box_mesh(Vector3(0.2, 0.012, length), steel)
		tray.position = mid + Vector3(0, hy, 0) + inward * 0.1
		tray.rotation.y = yaw
		add_child(tray)
		for c in 3:
			var cab := Geo.box_mesh(Vector3(0.045, 0.045, length), rubber)
			cab.position = mid + Vector3(0, hy + 0.03, 0) + inward * (0.04 + c * 0.055)
			cab.rotation.y = yaw
			add_child(cab)


## Лужа: неровное пятно из нескольких перекрывающихся овалов, мокрый блеск под фонарём.
func _puddle(at: Vector3, water: Material, seed_n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n * 13 + 5
	for k in 3:
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(0.25, 0.45)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.004
		cm.radial_segments = 14
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = water
		mi.position = at + Vector3(rng.randf_range(-0.35, 0.35), 0.001 * k, rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3(rng.randf_range(0.8, 1.6), 1.0, rng.randf_range(0.6, 1.1))
		mi.rotation.y = rng.randf_range(0, PI)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


# --- Живое: шаги за стеной, стук снизу, моргание ----------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for i in _lamps.size():
		var f := 0.55 if fmod(_t * (1.3 + i), 3.7) > 0.25 else randf_range(0.0, 0.2)
		_lamps[i].light_energy = f
	_tick_tunnel(delta)
	_tick_cellar(delta)


## В тоннеле за стеной кто-то идёт в ногу с тобой. Остановишься — сделает ещё два шага.
func _tick_tunnel(delta: float) -> void:
	if Game.zone != &"tunnel" or Game.player == null:
		_last_pos = Vector3.INF
		return
	var p := Game.player.global_position
	if _last_pos != Vector3.INF:
		_step_acc += Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	var in_a := p.z < TUN_Z - 1.0
	var side := Vector3(1.9, 0.6, 1.2) if in_a else Vector3(-1.2, 0.6, -1.9)
	if _step_acc > 0.7:
		_step_acc = 0.0
		_echo_steps = 2
		_echo_t = 0.22
	_echo_t -= delta
	if _echo_steps > 0 and _echo_t <= 0.0:
		_echo_steps -= 1
		_echo_t = 0.55
		Game.audio.play_3d("res://assets/sfx/barefoot_wood%s.ogg" % ["", "_v2", "_v3", "_v4"].pick_random(), p + side, -10.0, 6.0)
	if not _bang_done and not in_a:
		_bang_done = true
		Game.audio.play_3d("res://assets/audio/door_knock.ogg", p + Vector3(0, 1.2, -1.6), 4.0, 8.0)
		Game.player.shake(0.06, 0.4)
		Game.hud.subtitle(Loc.t(&"sub.tunnel_bang"), 4.0)
		Director.add_tension(15.0, "удар в стену тоннеля")


## В подполе ночью снизу стучат, а потом кто-то встаёт на ступеньку за спиной.
func _tick_cellar(delta: float) -> void:
	if _cellar_t < 0.0:
		return
	if Game.zone != &"cellar":
		_cellar_t = -1.0
		return
	_cellar_t += delta
	if not Game.is_night():
		return
	if _cellar_t > 3.0 and _cellar_t - delta <= 3.0:
		Game.audio.play_3d("res://assets/audio/knock.ogg", CELLAR + Vector3(0, -0.8, 0), 4.0, 8.0)
		Game.hud.subtitle(Loc.t(&"sub.cellar_knock"), 4.0)
		Director.add_tension(12.0, "стук снизу в подполе")
	if _cellar_t > 14.0 and _cellar_t - delta <= 14.0:
		Game.audio.play_3d("res://assets/audio/house_creak.ogg", CELLAR + Vector3(0, 1.0, -1.3), 2.0, 6.0)
		Game.hud.subtitle(Loc.t(&"sub.cellar_step"), 3.5)
		Director.add_tension(10.0, "ступенька в подполе")
