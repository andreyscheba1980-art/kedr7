class_name EfirSites
extends Node3D
## Эфир в мире (Efir): рамочная антенна у рации в доме, приёмник с рамкой в кабине башни корпуса,
## и сами передатчики на своих точках — то, что лежит в квадрате, где сошлись пеленги.
## Пока сигнал в эфире, у передатчика слышно несущую и мигает лампочка: в квадрате ищешь по звуку.

const NOTE_SFX := "res://assets/audio/whisper.ogg"
## Ключевая находка → снаряжение в схроне рядом
const FIND_GEAR := {&"beacon": &"lamp_kuzbass", &"repeater": &"field_radio"}

## Где стоит находка — на земле, чуть в стороне от центра (у построек — внутри или у входа)
var _spots: Array[Dictionary] = []      ## [{"id": сигнал, "node": Node3D, "audio": AudioStreamPlayer3D, "lamp": OmniLight3D}]
var _t := 0.0


func _ready() -> void:
	_build_house_loop()
	_build_tower_receiver()
	var done := {}
	for id: StringName in Efir.KEY:
		var k: Dictionary = Efir.KEY[id]
		if k.get("far", false) or not k.has("find") or done.has(k["find"]):
			continue
		done[k["find"]] = true
		if _relevant(StringName(k["find"])):
			_build_find(id, k["pos"], StringName(k["find"]), false)
	var last := Game.night if Game.is_night() else clampi(Game.phase_index, 0, 6)   # день N — после ночи N
	for n in range(1, last + 1):
		for id in Efir.pool_for_night(n):
			if not Game.has_flag("pf_" + String(id)):
				_build_find(id, Efir.pool_def(id)["pos"], &"", true)


## Ящик стоит на месте с той ночи, когда его сигнал впервые вышел в эфир (или уже пойман, или найден).
static func _relevant(find: StringName) -> bool:
	if Efir.has_find(find):
		return true
	for id: StringName in Efir.KEY:
		if Efir.KEY[id].get("find", &"") != find:
			continue
		if SaveGame.intercepts.has(id) or (Game.is_night() and (Game.cfg.get("signals", []) as Array).has(id)):
			return true
	return false


static func _ground(p: Vector3) -> Vector3:
	if p.y != 0.0:
		return p
	var inside := Vector2(p.x, p.z).length() < 16.0 or p.distance_to(Yard.IZBA) < 4.0
	if inside or not Terrain.ready():
		return p
	return Vector3(p.x, Terrain.height(p.x, p.z), p.z)


# --- Рамки ------------------------------------------------------------------------------

func _build_house_loop() -> void:
	var at := Vector3(11.0, 0.0, -0.45)   # у восточной стены рубки, южнее сейфа
	var metal := Palette.m(&"metal")
	Geo.cylinder(self, 0.16, 0.04, at + Vector3(0, 0.02, 0), Palette.m(&"dark"), false)
	Geo.block(self, Vector3(0.04, 1.1, 0.04), at + Vector3(0, 0.57, 0), metal, false)
	_loop_frame(at + Vector3(0, 1.38, 0), 0.5, metal)
	Geo.cylinder(self, 0.13, 0.02, at + Vector3(0, 1.1, 0), Palette.m(&"paper"), false)   # лимб
	var it := Geo.interactable(self, Vector3(0.6, 1.5, 0.5), at + Vector3(0, 0.9, 0), null, "", func(_p: Player) -> void:
		DirectionFinderUI.next_point = &"house"
		EventBus.ui_requested.emit(&"direction_finder"))
	it.prompt_provider = func() -> String: return Loc.t(&"it.df_house")
	it.name = "LoopAntenna"


func _build_tower_receiver() -> void:
	var at := Vector3(95.35, MeteoCorpus.CAB + 0.78, -37.12)   # на столе у западной стены кабины (проход к балкону свободен)
	Geo.block(self, Vector3(0.5, 0.26, 0.3), at + Vector3(0, 0.13, 0), Palette.m(&"canister"), false)
	Geo.block(self, Vector3(0.44, 0.1, 0.02), at + Vector3(0, 0.16, 0.155), Palette.m(&"paper"), false)
	_loop_frame(Vector3(96.75, MeteoCorpus.CAB + 3.3, -36.75), 0.7, Palette.m(&"metal"))   # рамка на крыше кабины
	var it := Geo.interactable(self, Vector3(0.55, 0.35, 0.4), at + Vector3(0, 0.15, 0), null, "", func(_p: Player) -> void:
		if MeteoCorpus.instance == null or not MeteoCorpus.instance.powered:
			Game.hud.subtitle(Loc.t(&"df.tower_dark"), 3.0)
			return
		DirectionFinderUI.next_point = &"tower"
		EventBus.ui_requested.emit(&"direction_finder"))
	it.prompt_provider = func() -> String:
		if MeteoCorpus.instance == null or not MeteoCorpus.instance.powered:
			return Loc.t(&"it.pult_dark")
		return Loc.t(&"it.df_tower")
	it.name = "TowerReceiver"


## Ромб рамки: четыре планки по краям квадрата, повёрнутого на 45°.
func _loop_frame(center: Vector3, side: float, mat: Material) -> void:
	var f := Node3D.new()
	f.position = center
	f.rotation.z = PI * 0.25
	add_child(f)
	for e: Array in [[Vector3(0, side * 0.5, 0), Vector3(side, 0.03, 0.03)], [Vector3(0, -side * 0.5, 0), Vector3(side, 0.03, 0.03)],
			[Vector3(side * 0.5, 0, 0), Vector3(0.03, side, 0.03)], [Vector3(-side * 0.5, 0, 0), Vector3(0.03, side, 0.03)]]:
		var m := Geo.box_mesh(e[1], mat)
		m.position = e[0]
		f.add_child(m)


# --- Передатчики ------------------------------------------------------------------------

func _build_find(id: StringName, pos: Vector3, find: StringName, pool: bool) -> void:
	var p := _ground(pos)
	var root := Node3D.new()
	root.position = p
	add_child(root)
	# Ящик-станция защитного цвета, антенна-штырь, лампа-«жучок»
	var box := Geo.box_mesh(Vector3(0.46, 0.3, 0.3), Palette.m(&"canister"))
	box.position = Vector3(0, 0.15, 0)
	box.rotation.y = randf() * TAU
	root.add_child(box)
	var whip := Geo.box_mesh(Vector3(0.015, 1.4, 0.015), Palette.m(&"metal"))
	whip.position = Vector3(0.16, 0.95, 0.05)
	whip.rotation.z = 0.12
	root.add_child(whip)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 0.36, 0)
	lamp.light_color = Color(1.0, 0.25, 0.15)
	lamp.omni_range = 1.4
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	root.add_child(lamp)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = NumbersVoice.stream_or_default(id)
	audio.unit_size = 4.0
	audio.max_distance = 36.0
	audio.volume_db = -80.0
	audio.bus = &"SFX"
	root.add_child(audio)
	audio.finished.connect(audio.play)
	var it := Geo.interactable(root, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), null, "", func(_p: Player) -> void:
		_on_find(id, find, pool))
	it.prompt_provider = func() -> String: return Loc.t(&"it.efir_find")
	it.name = "EfirFind_" + String(id)
	_spots.append({"id": id, "node": root, "audio": audio, "lamp": lamp, "find": find, "pool": pool})


func _on_find(id: StringName, find: StringName, pool: bool) -> void:
	if pool:
		var d := Efir.pool_def(id)
		var lang := "en" if Settings.language == "en" else "ru"
		var msg: String = (Efir.POOL[int(d["msg"])] as Dictionary)[lang]
		Game.hud.show_note(Loc.t(StringName("efir.pool_note.%d" % int(d["msg"]))) + "\n\n" + Loc.t(&"efir.pool_tag", [int(d["freq"])]))
		if not Game.has_flag("pf_" + String(id)):
			Game.set_flag("pf_" + String(id), true)
			_pool_bonus()
			SaveGame.flags["pool_found"] = Efir.pool_found() + 1
			Game.add_intercept(id)
			SaveGame.write()
			Director.add_tension(6.0, "находка в квадрате: " + msg.left(24))
		return
	Game.hud.show_note(Loc.t(StringName("efir.find." + String(find))))
	# Схрон рядом с передатчиком: за ключевые находки — снаряжение (загадка на приборах окупается)
	if FIND_GEAR.has(find):
		Gear.grant.call_deferred(FIND_GEAR[find])
	if Efir.mark_find(find):
		Game.audio.play_2d(NOTE_SFX, -8.0)
		Director.add_tension(10.0, "ключевая находка: " + String(find))
		Game.hud.toast(Loc.t(&"efir.find_toast", [Efir.find_count(), Efir.FINDS.size()]), 4.0)


## Случайная находка по эфиру — расходник: батарея «Сатурн» (фонарь до полного) или ракета.
func _pool_bonus() -> void:
	if Game.has_item(&"flare_gun") and randf() < 0.5:
		Game.add_spare_flares(1)
		Game.hud.toast(Loc.t(&"efir.bonus_flare"), 3.5)
	else:
		Game.flash_charge = 100.0
		Game.hud.toast(Loc.t(&"efir.bonus_battery"), 3.5)


func _process(delta: float) -> void:
	_t += delta
	var on_air: Array[StringName] = []
	if Game.radio != null:
		on_air = Game.radio.signals_on_air()
	for s: Dictionary in _spots:
		var id: StringName = s["id"]
		var live := false
		if on_air.has(id) and Efir.window_ok(id):
			live = true
		elif not s["pool"]:
			# у одной находки бывает несколько сигналов (цифры и «Отзвук» — один ящик)
			for other: StringName in Efir.KEY:
				if Efir.KEY[other].get("find", &"") == s["find"] and on_air.has(other) and Efir.window_ok(other):
					live = true
					break
		var audio: AudioStreamPlayer3D = s["audio"]
		var near: bool = Game.player != null and (s["node"] as Node3D).global_position.distance_to(Game.player.global_position) < 40.0
		if live and near:
			if not audio.playing:
				audio.play()
			audio.volume_db = -4.0
		elif audio.playing:
			audio.stop()
		(s["lamp"] as OmniLight3D).light_energy = (0.9 if fmod(_t, 1.2) < 0.15 else 0.0) if live else 0.0
