class_name SourceSite
extends Node3D
## Капище-источник в распадке за лесосечным зимником. Сюда сходятся пеленги АМС (FieldJobs):
## каждую ночь в 03:10 отсюда бьёт сигнал, который пишут все самописцы округи.
## Кольцо чуров, мёртвая лиственница с вещами пропавших, советский ящик «ОТЗВУК-2» (в/ч 03110),
## кабели уходят в мерзлоту. Днём ящик тёплый и гудит; ночью — диктует цифры.
## Тетрадь Семёнова у ящика открывает точку на схеме. В 7-ю ночь, после зова, — оборвать провода:
## концовка «Источник».

const HUM := "res://assets/sfx/underfloor_hum.ogg"
const NUMBERS := "res://assets/audio/numbers_loop.ogg"
const CUT_HOLD := 8.0

static var instance: SourceSite

var center: Vector3
var _box: Node3D
var _lamp: OmniLight3D
var _numbers: AudioStreamPlayer3D
var _t := 0.0


func _ready() -> void:
	instance = self
	name = "SourceSite"
	center = Terrain.pad_pos(&"source")
	_build()


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func found() -> bool:
	return Game.has_flag("source_found")


func _model(id: String, pos: Vector3, yaw: float, collide := true) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	root.rotation.y = yaw
	Models.spawn(root, "kedr/" + id, Vector3.ZERO, 0.0, -1.0, {"grime": 0.0, "bright": 1.1, "sat": 0.9, "collide": collide})
	return root


func _build() -> void:
	# Мёртвая лиственница в центре
	_model("dead_larch", center, 0.4)
	# Кольцо из семи чуров лицом внутрь (один повален)
	for k in 7:
		var a := k * TAU / 7.0 + 0.2
		var p := center + Vector3(cos(a), 0, sin(a)) * 6.5
		var to := center - p
		var yaw := atan2(to.x, to.z)
		var post := _model("chur_post", p, yaw)
		if k == 4:
			post.rotation = Vector3(deg_to_rad(-78.0), yaw, 0.0)
			post.position.y += 0.2
	# Ящик «ОТЗВУК-2» у корней, лицом к просеке
	var bp := center + Vector3(1.6, 0, -1.4)
	var road_dir := Vector3(-95, 0, 60) - bp
	_box = _model("otzvuk_box", bp, atan2(road_dir.x, road_dir.z))
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.2, 0.1)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 4.0
	_lamp.position = Vector3(0, 0.5, 0.35)
	_box.add_child(_lamp)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = AudioDirector.cached_stream(HUM)
	hum.volume_db = -6.0
	hum.unit_size = 3.0
	hum.max_distance = 30.0
	hum.bus = &"SFX"
	hum.autoplay = true
	_box.add_child(hum)
	hum.finished.connect(hum.play)
	_numbers = AudioStreamPlayer3D.new()
	_numbers.stream = AudioDirector.cached_stream(NUMBERS)
	_numbers.volume_db = -4.0
	_numbers.unit_size = 4.0
	_numbers.max_distance = 45.0
	_numbers.bus = &"SFX"
	_box.add_child(_numbers)
	_numbers.finished.connect(_numbers.play)

	var it := Geo.interactable(self, Vector3(0.9, 0.8, 0.6), _box.global_position + Vector3(0, 0.4, 0), null, "", Callable())
	it.name = "OtzvukBox"
	it.hold_sound = "res://assets/audio/whisper.ogg"
	it.prompt_provider = func() -> String:
		if _can_cut():
			it.hold_time = CUT_HOLD
			return Loc.t(&"src.it_cut")
		it.hold_time = 0.0
		return Loc.t(&"src.it_box")
	it.hold_check = func() -> bool: return _can_cut()
	it.used.connect(_on_box_used)

	# Тетрадь Семёнова — на крышке ящика, придавлена камнем
	var note := Geo.interactable(self, Vector3(0.35, 0.2, 0.3), _box.global_position + Vector3(0, 0.8, 0), Palette.m(&"paper"), "", Callable())
	note.name = "SemenovNotebook"
	note.prompt_provider = func() -> String: return Loc.t(&"src.it_note")
	note.used.connect(func(_p: Player) -> void:
		Game.hud.show_note(Loc.t(&"src.note"))
		if not found():
			Game.set_flag("source_found", true)
			Director.add_tension(14.0, "капище")
			Game.audio.play_3d("res://assets/audio/whisper.ogg", center + Vector3(0, 2, 0), -4.0)
			SaveGame.write()
	)
	(note.get_child(0) as Node3D).scale = Vector3(1.0, 0.15, 1.0)


func _can_cut() -> bool:
	return Game.is_night() and Game.night >= 7 and Game.final_call


func _on_box_used(_p: Player) -> void:
	if _can_cut():
		Game.audio.play_3d("res://assets/audio/shriek.ogg", center + Vector3(0, 3, 0), 2.0, 12.0)
		EventBus.ending_chosen.emit(&"source")
		return
	if Game.is_night():
		Game.hud.subtitle(Loc.t(&"src.box_night"), 5.0)
		Director.add_tension(8.0, "ящик на капище ночью")
	else:
		Game.hud.subtitle(Loc.t(&"src.box_day"), 5.0)


func _process(delta: float) -> void:
	_t += delta
	if Game.player == null:
		return
	var night := Game.is_night()
	# Ночью ящик диктует цифры и мигает лампой
	var d := Game.player.global_position.distance_to(center)
	if night and d < 60.0:
		if not _numbers.playing:
			_numbers.play()
		_lamp.light_energy = 1.4 if fmod(_t, 1.3) < 0.25 else 0.0
	else:
		if _numbers.playing:
			_numbers.stop()
		_lamp.light_energy = 0.4 if fmod(_t, 4.0) < 0.15 else 0.0
	# Первая встреча с местом — мысль
	if d < 16.0 and not Game.has_flag("source_seen"):
		Game.set_flag("source_seen", true)
		Game.hud.subtitle(Loc.t(&"src.first"), 5.0)
		Director.add_tension(10.0, "капище — первый раз")
