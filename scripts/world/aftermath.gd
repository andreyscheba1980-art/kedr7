class_name Aftermath
extends Node
## Процедурный движок утренних последствий ночи («Night Aftermath»).
## Каждое утро после ночи (дни 1–6) станция и двор получают процедурный отпечаток пережитого:
##   • Босые следы на снегу (от крыльца под дом или к колодцу);
##   • Случайный набор повреждений станции (выбитое окно, конденсат в генераторе, ослабшая оттяжка мачты,
##     наледь на дымоходе, замерзший ворон на ступенях, следы когтей на срубе, обрыв леера);
##   • Утренний радиосеанс связи с Большой Землей в 14:15 (прогноз на ночь + вопросы о ночных аномалиях).

const CRUNCH_SOUND := "res://assets/audio/step_snow_3.ogg"   # snow_crunch.ogg в игре нет — звук был немой
const CLANK_SOUND := "res://assets/audio/clank.ogg"
const WOOD_SOUND := "res://assets/audio/stove_add.ogg"
const BUZZER_SOUND := "res://assets/audio/buzzer_loop.ogg"

var day_index := 1
var active_chores: Array[StringName] = []
var repaired_chores: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _call_triggered := false
var _call_answered := false
var _call_ringing := false
var _ring_timer := 0.0
var _ring_player: AudioStreamPlayer3D = null

# Узлы последствий во дворе и доме
var _footprints_node: Node3D
var _crow_node: Node3D
var _window_repair_node: Node3D
var _rope_snap_node: Node3D


func _ready() -> void:
	if not Game.is_day() or Game.is_prologue():
		queue_free()
		return
	day_index = Game.phase_index
	_rng.seed = Game.run_seed + day_index * 317 + 89
	_generate_aftermath()


func _process(delta: float) -> void:
	if not Game.is_day() or Game.is_prologue():
		return
	_tick_morning_call(delta)


func _exit_tree() -> void:
	if Game.is_day() and not Game.is_prologue() and not active_chores.is_empty():
		Consequences.carry_unrepaired(active_chores, repaired_chores)


## Где тварь ждала на привычных тропах — круги босых следов и мысль при осмотре.
func _spawn_waited_tracks(yard: Node3D) -> void:
	for w: Array in Consequences.take_waited():
		var c := Vector3(float(w[0]), 0.0, float(w[1]))
		var ring := PackedVector3Array()
		for i in 9:
			var a := i * TAU / 8.0
			var q := c + Vector3(cos(a) * 2.2, 0, sin(a) * 2.2)
			q.y = Terrain.height(q.x, q.z) + 0.03
			ring.append(q)
		var node := Node3D.new()
		node.name = "WaitedTracks"
		yard.add_child(node)
		Footprints.trail(node, &"bare", ring, ring[0].y, 0.5)
		var cy := Terrain.height(c.x, c.z)
		var it := Geo.interactable(node, Vector3(3.0, 1.2, 3.0), Vector3(c.x, cy + 0.6, c.z), null, Loc.t(&"it.footprints"), func(_p: Player) -> void:
			Game.hud.subtitle(Loc.t(&"cons.waited"), 6.0)
			Director.add_tension(5.0, "следы на привычной тропе"))
		it.name = "WaitedTracksInteract"


func _generate_aftermath() -> void:
	var yard := Game.yard
	var station := Game.level
	if yard == null or station == null:
		return

	# 1. Босые следы на снегу от крыльца
	_spawn_footprints(yard)
	_spawn_waited_tracks(yard)

	# 2. Пул возможных повреждений станции на это утро
	var chore_pool: Array[StringName] = [
		&"window_broken",
		&"generator_condensate",
		&"mast_loose_cable",
		&"chimney_ice",
		&"frozen_crow",
		&"scratches_wall",
		&"safety_rope_snap",
	]
	chore_pool.shuffle()
	# Сначала — то, что вызвала эта ночь (осада → окно, диверсия → дизель, буран → мачта)
	for c in Consequences.caused_chores():
		chore_pool.erase(c)
		chore_pool.push_front(c)

	# Количество повреждений: 2-3 в зависимости от дня
	var count: int = 2 if day_index <= 2 else 3
	for i in range(mini(count, chore_pool.size())):
		var chore_id: StringName = chore_pool[i]
		active_chores.append(chore_id)
		_setup_chore(chore_id, station, yard)


func _spawn_footprints(yard: Yard) -> void:
	# Босые следы у порога генерируются, если ночью были стуки, осада или гости
	var had_night_visitor: bool = day_index in [2, 4, 6] or bool(SaveGame.flags.get("door_knocked", false)) or bool(SaveGame.flags.get("had_night_siege", false)) or _rng.randf() < 0.75
	if not had_night_visitor:
		return

	_footprints_node = Node3D.new()
	_footprints_node.name = "MorningFootprints"
	yard.add_child(_footprints_node)

	# Цепочка следов от ступеней крыльца вокруг окон дома и в чащу
	var trail_points := PackedVector3Array([
		Vector3(16.2, 0.04, 3.4),
		Vector3(16.5, 0.04, 2.2),
		Vector3(16.2, 0.04, 0.8),
		Vector3(15.2, 0.04, -0.6),
		Vector3(13.8, 0.04, -1.8),
		Vector3(12.2, 0.04, -2.4),
		Vector3(10.5, 0.04, -2.6),
		Vector3(8.0, 0.04, -5.0),
		Vector3(5.0, 0.04, -10.0),
	])
	Footprints.trail(_footprints_node, &"bare", trail_points, 0.04, 0.52)

	# Интерактивная зона осмотра следов
	var it := Geo.interactable(_footprints_node, Vector3(2.5, 1.2, 2.5), Vector3(16.2, 0.6, 2.5), null, Loc.t(&"it.footprints"), Callable())
	it.name = "FootprintsInteract"
	it.used.connect(func(p: Player) -> void:
		it.enabled = false
		_on_footprints_used(p)
	)


func _on_footprints_used(p: Player) -> void:
	Game.audio.play_3d("res://assets/sfx/snow_steps_walk.ogg", Vector3(16.2, 0.0, 2.5), 0.0)
	Game.hud.subtitle(Loc.t(&"sub.aftermath_footprints"), 6.0)
	Director.add_tension(6.0, "осмотр босых следов")


func _setup_chore(chore: StringName, station: Station, yard: Yard) -> void:
	match chore:
		&"window_broken":
			# Окно сеней выбито, сквозит
			var window_pos := Vector3(13.0, 1.45, 6.6)
			if _window_repair_node != null and is_instance_valid(_window_repair_node):
				_window_repair_node.queue_free()
			_window_repair_node = Node3D.new()
			_window_repair_node.name = "WindowRepair"
			station.add_child(_window_repair_node)

			var it: Interactable = null
			it = Geo.interactable(_window_repair_node, Vector3(1.2, 1.2, 0.6), window_pos, null, Loc.t(&"it.repair_window"), func(p: Player) -> void:
				_repair_window(p, window_pos, it)
			)
			it.hold_time = 2.0
			it.hold_sound = WOOD_SOUND

		&"generator_condensate":
			# Дизель-генератор: замерзший отстойник фильтра
			var gen_pos := Station.DOOR_LAMP + Vector3(0, -1.0, 3.5) # у сарая ГСМ
			var it: Interactable = null
			it = Geo.interactable(station, Vector3(1.0, 1.0, 1.0), Vector3(14.8, 0.8, 6.2), null, Loc.t(&"it.gen_drain"), func(p: Player) -> void:
				_repair_gen_drain(p, it)
			)
			it.hold_time = 2.5
			it.hold_sound = CLANK_SOUND

		&"mast_loose_cable":
			# Талреп оттяжки мачты ослаб
			var cable_pos := Yard.MAST + Vector3(-3.5, 0.8, 3.5)
			var it: Interactable = null
			it = Geo.interactable(yard, Vector3(1.2, 1.5, 1.2), cable_pos, null, Loc.t(&"it.tighten_guywire"), func(p: Player) -> void:
				_repair_guywire(p, cable_pos, it)
			)
			it.hold_time = 2.0
			it.hold_sound = CLANK_SOUND

		&"chimney_ice":
			# Наледь на печной трубе
			var chimney_pos := Vector3(0.5, 1.2, -0.6) # возле печи в комнате
			var it: Interactable = null
			it = Geo.interactable(station, Vector3(1.2, 1.2, 1.2), chimney_pos, null, Loc.t(&"it.clear_chimney"), func(p: Player) -> void:
				_repair_chimney(p, it)
			)
			it.hold_time = 2.0
			it.hold_sound = "res://assets/audio/ice_hit.ogg"

		&"frozen_crow":
			# Замерзший ворон на ступенях
			_crow_node = Props.frozen_crow()
			if _crow_node != null:
				_crow_node.position = Vector3(16.3, 0.12, 3.4)
				_crow_node.rotation.y = deg_to_rad(45.0)
				station.add_child(_crow_node)
				var it: Interactable = null
				it = Geo.interactable(_crow_node, Vector3(0.6, 0.5, 0.6), Vector3(16.3, 0.25, 3.4), null, Loc.t(&"it.frozen_crow"), func(_p: Player) -> void:
					if it != null:
						it.enabled = false
					Game.hud.subtitle(Loc.t(&"sub.aftermath_crow"), 6.0)
					Director.add_tension(4.0, "мертвый ворон")
				)

		&"scratches_wall":
			# Борозды на бревнах под окном
			var scratch_pos := Vector3(-2.6, 1.3, 3.3)
			var it: Interactable = null
			it = Geo.interactable(station, Vector3(0.8, 1.5, 1.5), scratch_pos, null, Loc.t(&"it.scratches_wall"), func(_p: Player) -> void:
				if it != null:
					it.enabled = false
				Game.hud.subtitle(Loc.t(&"sub.aftermath_scratches"), 6.0)
				Director.add_tension(5.0, "следы когтей на срубе")
			)

		&"safety_rope_snap":
			# Разорванный леер между домом и складом
			var snap_pos := Vector3(28.0, 0.4, 2.0)
			var it: Interactable = null
			it = Geo.interactable(yard, Vector3(1.8, 1.0, 1.8), snap_pos, null, Loc.t(&"it.splice_rope"), func(p: Player) -> void:
				_repair_rope(p, snap_pos, it)
			)
			it.hold_time = 3.0
			it.hold_sound = WOOD_SOUND


# --- Обработчики ремонта ---

func _repair_window(p: Player, pos: Vector3, it: Interactable = null) -> void:
	repaired_chores[&"window_broken"] = true
	if it != null and is_instance_valid(it):
		it.enabled = false
		it.queue_free()
	var plank := Props.broken_window_plank()
	if plank != null:
		plank.position = pos
		plank.rotation.y = deg_to_rad(90.0)
		if _window_repair_node != null and is_instance_valid(_window_repair_node):
			_window_repair_node.add_child(plank)
	Game.audio.play_3d(WOOD_SOUND, pos, 0.0)
	Game.hud.subtitle(Loc.t(&"sub.window_repaired"), 5.0)


func _repair_gen_drain(p: Player, it: Interactable = null) -> void:
	repaired_chores[&"generator_condensate"] = true
	if it != null and is_instance_valid(it):
		it.enabled = false
		it.queue_free()
	Game.audio.play_3d(CLANK_SOUND, p.global_position, 0.0)
	Game.hud.subtitle(Loc.t(&"sub.gen_drained"), 5.0)


func _repair_guywire(p: Player, pos: Vector3, it: Interactable = null) -> void:
	repaired_chores[&"mast_loose_cable"] = true
	if it != null and is_instance_valid(it):
		it.enabled = false
		it.queue_free()
	Game.audio.play_3d(CLANK_SOUND, pos, 0.0)
	Game.hud.subtitle(Loc.t(&"sub.guywire_tightened"), 5.0)


func _repair_chimney(p: Player, it: Interactable = null) -> void:
	repaired_chores[&"chimney_ice"] = true
	if it != null and is_instance_valid(it):
		it.enabled = false
		it.queue_free()
	Game.chimney_iced = false
	Game.audio.play_3d("res://assets/audio/ice_hit.ogg", p.global_position, 0.0)
	Game.hud.subtitle(Loc.t(&"sub.chimney_cleared"), 5.0)


func _repair_rope(p: Player, pos: Vector3, it: Interactable = null) -> void:
	repaired_chores[&"safety_rope_snap"] = true
	if it != null and is_instance_valid(it):
		it.enabled = false
		it.queue_free()
	Game.audio.play_3d(WOOD_SOUND, pos, 0.0)
	Game.hud.subtitle(Loc.t(&"sub.rope_spliced"), 5.0)


# --- 3. Утренний радиосеанс связи (14:15) ---

func _tick_morning_call(delta: float) -> void:
	if _call_answered or Game.shift_minutes < 15.0: # 14:15
		return

	if not _call_triggered:
		_call_triggered = true
		_call_ringing = true
		_ring_timer = 25.0
		Game.hud.subtitle(Loc.t(&"sub.radio_call_incoming"), 5.0)
		# Активируем кнопку ответа на Р-250
		if Game.radio != null:
			Game.radio.set_morning_call_active(true)
		# Запускаем звонок вызова радиостанции
		_ring_player = AudioStreamPlayer3D.new()
		_ring_player.stream = AudioDirector.cached_stream(BUZZER_SOUND)
		_ring_player.position = Station.DOOR_LAMP + Vector3(-5.7, 0, -4.5)
		_ring_player.bus = &"Radio"
		_ring_player.unit_size = 5.0
		_ring_player.max_distance = 25.0
		_ring_player.volume_db = -6.0
		add_child(_ring_player)
		_ring_player.play()

	if _call_ringing:
		_ring_timer -= delta
		if _ring_timer <= 0.0 and not _call_answered:
			_call_ringing = false
			if _ring_player != null and is_instance_valid(_ring_player):
				_ring_player.stop()
				_ring_player.queue_free()
				_ring_player = null
			if Game.radio != null:
				Game.radio.set_morning_call_active(false)


func answer_morning_call() -> void:
	if _call_answered:
		return
	_call_answered = true
	_call_ringing = false
	if _ring_player != null and is_instance_valid(_ring_player):
		_ring_player.stop()
		_ring_player.queue_free()
		_ring_player = null
	if Game.radio != null:
		Game.radio.set_morning_call_active(false)

	# Сценарий ответа Большой Земли на конкретный день
	var dispatch_text: String = Loc.t(StringName("dispatch.day_%d" % day_index))
	Game.hud.subtitle(dispatch_text, 8.5)
	var ml_voice := Voice.or_fallback(StringName("ml_morn_day%d" % day_index), "res://assets/audio/voice_mainland.ogg")
	Game.audio.play_2d(ml_voice, 0.0)
	Director.add_tension(5.0, "утренний сеанс связи")


func is_call_ringing() -> bool:
	return _call_ringing
