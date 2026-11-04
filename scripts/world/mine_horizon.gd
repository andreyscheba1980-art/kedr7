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
		return
	var pp := Game.player.global_position
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = randf_range(1.5, 4.0)
		var at := pp + Vector3(randf_range(-6, 6), 2.2, randf_range(-6, 6))
		Game.audio.play_3d(DRIP[randi() % DRIP.size()], at, -6.0, 10.0)
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(10.0, 22.0)
		Game.audio.play_3d("res://assets/sfx/cc0/log_frost_crack_v2.ogg", pp + Vector3(randf_range(-8, 8), 2.0, randf_range(-8, 8)), -8.0, 14.0)
	var local := pp - ROOT
	# Тупик с вагонеткой: из-за завала стучат — три раза, как Михалыч сигналит
	if local.x < -5.0 and local.z < -24.0 and local.z > -28.0 and not _scared.has(&"knock"):
		_scared[&"knock"] = true
		for k in 3:
			get_tree().create_timer(0.6 + k * 0.7, false).timeout.connect(func() -> void:
				Game.audio.play_3d("res://assets/audio/knock_v3.ogg", ROOT + Vector3(-10.5, 1.0, -26.0), 2.0, 14.0))
		Director.add_tension(10.0, "стук в тупике штольни")
	# Забой: шёпот за спиной, со стороны лаза
	if local.z < -40.0 and not _scared.has(&"whisper"):
		_scared[&"whisper"] = true
		Game.audio.play_3d("res://assets/audio/whisper.ogg", ROOT + Vector3(0.0, 1.0, -37.0), -2.0, 8.0)
		Game.hud.subtitle(Loc.t(&"pro.call_name"), 3.0)
		Director.add_tension(10.0, "шёпот в забое")
