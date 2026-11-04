class_name Session
extends Node
## Одна фаза игры (пролог, день или ночь): мир, игрок, интерфейс, ввод, сценарий фазы и её финал.
## Мир рендерится в SubViewport в 1/N разрешения (настройка «Пиксельность») с PS1-постобработкой, HUD — в полном.
## Наружу отдаёт только finished(result): "advance" | "retry" | "menu" | "demo_end".

signal finished(result: String)

const POST_SHADER := "res://assets/shaders/ps1_post.gdshader"
const KNOCK := "res://assets/audio/door_knock.ogg"
const SCREAM := "res://assets/audio/scream.ogg"
const SeismographUIScript = preload("res://scripts/ui/seismograph_ui.gd")
const JournalTM1UIScript = preload("res://scripts/ui/journal_tm1_ui.gd")
const MeteorFaxUIScript = preload("res://scripts/ui/meteor_fax_ui.gd")
const AftermathClass = preload("res://scripts/world/aftermath.gd")
const PlayerProfilerClass = preload("res://scripts/ai/player_profiler.gd")
const HunterBrainClass = preload("res://scripts/ai/hunter_brain.gd")
const PsychosomaticFXClass = preload("res://scripts/world/psychosomatic_fx.gd")

var _player: Player
var _vp: SubViewport
var _container: SubViewportContainer
var _pause: PauseMenu
var _wait_click := ""               ## непусто — ждём клика, чтобы отдать этот результат
var _ending := false


func _ready() -> void:
	add_to_group(&"session")
	add_child(Hud.new())
	add_child(AudioDirector.new())

	var container := SubViewportContainer.new()
	_container = container
	container.stretch = true
	container.stretch_shrink = Settings.render_shrink()
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = load(POST_SHADER)
	container.material = post
	add_child(container)
	move_child(container, 0)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vp = SubViewport.new()
	_vp.audio_listener_enable_3d = true
	_vp.msaa_3d = Settings.msaa()        # чистые грани низкополигональных елей и брёвен (по пресету)
	_vp.positional_shadow_atlas_size = [1024, 2048, 4096][clampi(Settings.quality, 0, 2)]
	_vp.use_occlusion_culling = true      # заслонки в срубе (Station._build_occluders): не рисуем то, что за стенами
	container.add_child(_vp)
	_vp.add_child(Station.new())
	_player = Player.new()
	if Game.is_prologue() and not Game.has_flag("prologue_arrived") and not Game.has_flag("left_cabin"):
		_player.position = Vehicle.get_cabin_seat_world()
		_player.rotation.y = deg_to_rad(225.0)
	elif Game.is_prologue() and not Game.has_flag("prologue_arrived"):
		_player.position = PrologueTrail.route()[0] + Vector3(0, 0.1, 0)   # продолжаем с начала просеки
	else:
		_player.position = Station.SPAWN
	_vp.add_child(_player)
	if Game.is_prologue() and not Game.has_flag("prologue_arrived") and not Game.has_flag("left_cabin"):
		_player.head.position.y = 0.90
	Net.on_session_ready()
	_vp.add_child(Atmosphere.new())
	add_child(PlayerProfilerClass.new())
	add_child(HunterBrainClass.new())
	add_child(PsychosomaticFXClass.new())
	add_child(YrkaThreat.new())
	add_child(NightEvents.new())
	if Game.is_night() and not Game.is_prologue():
		add_child(Signal0310.new())
	add_child(ForestVoice.new())
	add_child(Zenit.new())
	if Game.is_night():
		add_child(Anomalies.new())
	add_child(Hints.new())
	if Game.is_prologue():
		add_child(TutorialGuide.new())   # пролог: карточки по центру и огонёк над целью
	if Game.is_night():
		add_child(NightTasks.new())
		add_child(NightGuest.new())   # стук в дверь: человек или оно
		add_child(Wildlife.new())     # волки: не всё, что ходит ночью, — тварь
		if not Game.is_prologue():
			Consequences.apply_night()   # что не починил днём — ночью платишь
	else:
		Game.tasks = null
		if not Game.is_prologue():
			Consequences.apply_day()     # обморожение с прошлой ночи
			var aft := AftermathClass.new()
			add_child(aft)
			Game.aftermath = aft
			add_child(Troubles.new())   # бытовые беды утра: проблема → инструмент

	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.player_died.connect(_on_player_died)
	EventBus.ui_requested.connect(_open_ui)
	EventBus.report_sent.connect(_on_report_sent)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_begin()


func _apply_settings() -> void:
	if _container != null and _container.stretch_shrink != Settings.render_shrink():
		_container.stretch_shrink = Settings.render_shrink()
	if _player != null and _player.camera != null:
		_player.camera.fov = Settings.fov
	if _vp != null:
		_vp.msaa_3d = Settings.msaa()
		_vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_vp.scaling_3d_scale = clampf(Settings.render_scale, 0.5, 1.0)
	if _player != null and _player.flashlight != null:
		_player.flashlight.shadow_enabled = Settings.quality >= 1
	if Game.level != null and Game.level.has_method(&"apply_quality"):
		Game.level.call(&"apply_quality")


## Один раз, на первой смене: если кадров мало — снижаем качество, потом разрешение рендера.
## Игрок с ноутбуком не должен сам искать, почему «лагает».
func _auto_tune() -> void:
	if Settings.auto_tuned or (OS.is_debug_build() and not OS.get_cmdline_user_args().has("autotune")):
		return
	await get_tree().create_timer(6.0, false).timeout
	for step in range(3):
		var fps := await _avg_fps(6.0)
		if fps >= 48.0 or not is_inside_tree():
			break
		if Settings.quality > 0:
			Settings.quality -= 1
		elif Settings.render_scale > 0.71:
			Settings.render_scale = 0.85 if Settings.render_scale > 0.9 else 0.7
		else:
			break
		Settings.apply()
		if Game.hud != null:
			Game.hud.subtitle(Loc.t(&"set.auto_tuned"), 4.0)
	Settings.auto_tuned = true
	Settings.save()


func _avg_fps(sec: float) -> float:
	var frames := 0
	var t := 0.0
	while t < sec and is_inside_tree():
		await get_tree().process_frame
		frames += 1
		t += get_process_delta_time()
	return frames / maxf(t, 0.001)


# --- Начало фазы -------------------------------------------------------------

func _begin() -> void:
	Perf.mark("session begin")
	if _needs_cold_open():
		Vehicle.hold = true              # кабина ждёт, пока не кончится сцена из седьмой ночи
	var title := ""
	if Game.is_prologue():
		title = Loc.t(&"card.prologue_morning") if Game.has_flag("prologue_arrived") else Loc.t(&"card.prologue")
	elif Game.is_day():
		title = Loc.t(&"card.day", [Game.phase_index, Loc.t(StringName("diary.%d" % Game.phase_index))])
	else:
		title = Loc.t(&"card.night", [Game.night, Game.clock_text()])
		if Game.resumed:
			title += "\n\n" + Loc.t(&"card.resumed")
	Game.hud.show_screen(title)
	_player.mode = Player.Mode.LOCKED
	# Сначала показать карточку (мир не рисуем), потом прогреть шейдеры частями — окно не «висит».
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await get_tree().process_frame
	await get_tree().process_frame
	await _prewarm_assets(title)
	if Game.level != null and Settings.batching:
		StaticBatch.build(Game.level)   # склейка неподвижной геометрии: в разы меньше вызовов отрисовки
	for i in range(3):
		await get_tree().process_frame
		Perf.mark("first frame %d" % i)
	if _needs_cold_open():
		await _cold_open(title)
	_ensure_player_safe_spawn()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.mode = Player.Mode.WALK
	Game.start_shift()
	_auto_tune()
	if Game.is_night():
		Director.start(Game.cfg)
		Game.yrka.enabled = int(Game.cfg["yrka_max"]) > 0
	Net.on_session_begun()
	await Game.hud.fade_out_screen(1.5)
	if Game.is_prologue():
		if Game.has_flag("prologue_arrived"):
			Voice.say(&"th.morning", 3.5)
			get_tree().create_timer(4.0, false).timeout.connect(func() -> void: Game.hud.subtitle(Loc.t(&"tut.morning_start"), 6.0))
		elif Game.has_flag("left_cabin"):
			Game.hud.subtitle(Loc.t(&"pro.start"), 5.0)
	elif Game.is_day():
		Game.hud.subtitle(Loc.t(StringName("day%d.start" % Game.phase_index)), 6.0)
	elif Loc.has_key(StringName("n%d.start" % Game.night)):
		Game.hud.subtitle(Loc.t(StringName("n%d.start" % Game.night)), 7.0)


func _ensure_player_safe_spawn() -> void:
	if _player == null:
		return
	var p := _player.global_position
	var terrain_h := Terrain.height(p.x, p.z)
	# 1. Если координаты некорректны, ниже рельефа или за пределами локации:
	if not p.is_finite() or p.y < terrain_h - 1.2 or p.length() > 650.0:
		_player.global_position = Station.SPAWN
		return
	# 2. Если игрок не сидит в кабине пролога, проверяем пересечение с коллизиями твердых тел:
	if not (Game.is_prologue() and not Game.has_flag("prologue_arrived") and not Game.has_flag("left_cabin")):
		var w := _player.get_world_3d()
		if w == null or w.direct_space_state == null:
			return
		var space := w.direct_space_state
		var q := PhysicsPointQueryParameters3D.new()
		q.position = _player.global_position + Vector3(0, 0.9, 0)
		q.collision_mask = Geo.LAYER_WORLD
		q.exclude = [_player.get_rid()]
		var hits := space.intersect_point(q, 1)
		if not hits.is_empty():
			# Игрок внутри твердого тела (новая стена или шкаф) -> безопасный перенос в дом
			print("[Session] Обнаружено застревание при спавне. Безопасный перенос в дом: ", Station.SPAWN)
			_player.global_position = Station.SPAWN


# --- Холодный старт -----------------------------------------------------------------
# Сорок секунд из последних ночей: тамбур, стук, голос Михалыча за дверью; в глазке — он сам, в отсвете
# снега, не моргает. «Это не Михалыч». «Ну открой» — и рывком лицом в линзу. Дверь бьётся о засов,
# фонарь гаснет, шёпот за спиной — обрыв. «За семь дней до этого» — и кабина ГТ-Т.
# Один раз за прохождение (флаг cold_open_seen), на продолжении пролога не показывается.

const COLD_POS := Vector3(12.25, 0.05, 3.1)
const COLD_DOOR := Vector3(14.5, 1.3, 3.1)
const WHISPER := "res://assets/audio/whisper.ogg"
const CLANK := "res://assets/audio/clank.ogg"


func _needs_cold_open() -> bool:
	if OS.get_cmdline_user_args().has("--no_cold_open"):
		return false
	return Game.is_prologue() and not Game.has_flag("prologue_arrived") and not Game.has_flag("left_cabin") \
		and not Game.has_flag("cold_open_seen")


func _think(key: StringName, wait: float) -> void:
	var d := Voice.say(key, wait)
	await get_tree().create_timer(d, false).timeout


func _cold_open(title: String) -> void:
	Game.set_flag("cold_open_seen", true)
	Vehicle.hold = true
	Game.hud.cinematic = true
	var p := _player
	var st := Game.level as Station
	var hinge: Node3D = st.get(&"_door_hinge") if st != null else null
	var hinge_rot := hinge.rotation.y if hinge != null else 0.0
	if hinge != null:
		hinge.rotation.y = 0.0           # в ту ночь дверь заперта
	var was_lit: bool = st.get(&"_lit") if st != null else true
	if st != null:
		st.set_lit(false)                # генератор встал: только фонарь
	p.mode = Player.Mode.LOCKED
	p.global_position = COLD_POS
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(-90.0)
	p.head.position.y = 1.58
	p.head.rotation.x = deg_to_rad(-3.0)
	p.set_flashlight(true)
	Game.hud.show_screen("")
	await get_tree().create_timer(0.8, false).timeout
	await Game.hud.fade_out_screen(2.2)
	await get_tree().create_timer(1.2, false).timeout
	# Стук: три удара, пауза
	for i in 3:
		Game.audio.play_3d(KNOCK, COLD_DOOR, 4.0, 4.0)
		await get_tree().create_timer(0.42, false).timeout
	await get_tree().create_timer(1.0, false).timeout
	await _think(&"th.cold_1", 3.0)
	var d := Game.audio.say(&"door_4_2", COLD_DOOR, 3.0, 4.0)
	Game.hud.subtitle(Loc.t(&"knock4.2"), maxf(d, 4.5))
	await get_tree().create_timer(maxf(d, 4.5) + 0.6, false).timeout
	# К глазку: на крыльце, в холодном отсвете снега, стоит Михалыч. Не моргает и не дышит паром.
	var guest := Creatures.make_double(&"mikhalych")
	Game.level.add_child(guest)
	guest.global_position = Vector3(15.6, 0.0, 3.1)
	guest.look_at(Vector3(14.0, 0.0, 3.1), Vector3.UP)
	guest.pose_override = &"still"
	var snow_light := OmniLight3D.new()
	snow_light.light_color = Color(0.62, 0.72, 0.92)
	snow_light.light_energy = 1.3
	snow_light.omni_range = 4.0
	Game.level.add_child(snow_light)
	snow_light.global_position = Vector3(16.4, 2.0, 2.4)
	var step := create_tween()
	step.tween_property(p, "global_position", Vector3(13.95, 0.05, 3.1), 0.9).set_trans(Tween.TRANS_SINE)
	await step.finished
	var peep := PeepholeUI.new()
	Game.hud.open_modal(peep)
	await get_tree().create_timer(2.4, false).timeout
	await _think(&"th.cold_2", 3.5)
	# «Ну открой. Ну открой.» — и рывком лицом в глазок
	d = Game.audio.say(&"door_4_4", COLD_DOOR, 4.0, 4.0)
	Game.hud.subtitle(Loc.t(&"knock4.4"), maxf(d, 5.0))
	await get_tree().create_timer(1.3, false).timeout
	snow_light.light_energy = 0.35   # в упор лицо — почти в темноте, только отсвет из прихожей
	peep.call(&"_press_face", guest)
	Game.audio.play_2d("res://assets/audio/sub_drop.ogg", 2.0)
	p.shake(0.06, 0.4)
	await get_tree().create_timer(2.2, false).timeout
	Game.hud.close_modal()
	guest.queue_free()
	snow_light.queue_free()
	# Отпрянул от двери — а она бьётся о засов, ручка ходит, фонарь начинает моргать
	p.global_position = COLD_POS
	var t := 0.0
	var dur := maxf(d - 3.5, 3.0)
	var next_bang := 0.6
	while t < dur:
		var dt := get_process_delta_time()
		t += dt
		next_bang -= dt
		if hinge != null:
			hinge.rotation.y = sin(t * 38.0) * deg_to_rad(0.9) * clampf(t / dur, 0.2, 1.0)
		if next_bang <= 0.0:
			next_bang = randf_range(0.5, 0.9)
			Game.audio.play_3d(CLANK, COLD_DOOR, -2.0, 4.0)
			p.shake(0.02, 0.2)
		if t > dur * 0.5:
			p.flashlight.visible = randf() > 0.25 * (t / dur)
		await get_tree().process_frame
	if hinge != null:
		hinge.rotation.y = 0.0
	# Тишина и темнота. Шёпот за спиной. Обернуться — и обрыв.
	p.set_flashlight(false)
	Game.audio.silence(true)
	await get_tree().create_timer(1.8, false).timeout
	Game.audio.play_2d(WHISPER, 2.0)
	Game.hud.subtitle(Loc.t(&"cold.whisper"), 2.0)
	await get_tree().create_timer(0.9, false).timeout
	var tw := create_tween()
	tw.tween_property(p, "rotation:y", p.rotation.y + deg_to_rad(150.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Game.audio.play_2d(SCREAM, -2.0)
	await Game.hud.flash_face(0.14)
	Game.hud.show_screen("")
	Game.audio.silence(false)
	await get_tree().create_timer(2.2, false).timeout
	Game.hud.show_screen(Loc.t(&"cold.before"))
	# Назад в кабину, дверь станции — как была (приоткрыта, подпёрта поленом)
	if hinge != null:
		hinge.rotation.y = hinge_rot
	if st != null:
		st.set_lit(was_lit)
	p.global_position = Vehicle.get_cabin_seat_world()
	p.rotation.y = deg_to_rad(225.0)
	p.head.position.y = 0.90
	p.head.rotation.x = 0.0
	p.set_flashlight(false)
	await get_tree().create_timer(3.2, false).timeout
	Game.hud.show_screen(title)
	Game.hud.cinematic = false
	Vehicle.hold = false
	await get_tree().create_timer(2.5, false).timeout


func _prewarm_assets(title: String) -> void:
	# Прогрев шейдеров под карточкой загрузки. Шейдер компилируется, когда объект впервые ДОРИСОВАН,
	# поэтому мир открываем порциями (каждый кадр компилирует немного), а существ, предметы, руки,
	# снег, ракету и фонарь ставим прямо перед камерой. Иначе — чёрный «зависший» экран на старте,
	# фриз при первой встрече с Ыркой, выходе на улицу или включении фонаря.
	var hidden: Array[Node3D] = []
	var roots: Array[Node] = [Game.level]
	if Game.yard != null:
		roots.append(Game.yard)
	for r in roots:
		for ch in r.get_children():
			if ch is Node3D and ch != Game.yard and (ch as Node3D).visible and not (ch is Light3D) and not (ch is Camera3D):
				(ch as Node3D).visible = false
				hidden.append(ch)
	var rig := Node3D.new()
	rig.name = "Prewarm"
	_vp.add_child(rig)
	var cam := _player.camera
	var fwd := -cam.global_basis.z
	var base := cam.global_position + fwd * 2.5
	var side := cam.global_basis.x
	var models := Node3D.new()
	Models.spawn(models, "survival/barrel", Vector3.ZERO, 0.0, 0.4)     # шейдер готовых моделей
	var snow := Player.make_snow(64, Vector3(0.6, 0.3, 0.6), 0.0, 1.0)   # освещаемый снег
	var items: Array[Node3D] = [Creatures.make_yrka(), Creatures.make_zherdyai(0.0), Creatures.make_silhouette(),
		Props.canister(true), Props.canister(false),
		Props.oil_can(true), Props.oil_can(false), Props.firewood_bundle(true), Props.firewood_bundle(false),
		models, FPHands.new(), snow, Atmosphere.prewarm_node()]
	for i in items.size():
		items[i].visible = false
		rig.add_child(items[i])
		items[i].global_position = base + side * (float(i) - items.size() / 2.0) * 0.36 - Vector3(0, 0.9, 0)
	# Свет: точечный с тенью (ракета), без тени (лампы) и фонарь игрока — разные варианты шейдеров.
	var omni := OmniLight3D.new()
	omni.shadow_enabled = true
	omni.omni_range = 6.0
	rig.add_child(omni)
	omni.global_position = base + Vector3(0, 1.0, 0)
	var omni2 := OmniLight3D.new()
	omni2.omni_range = 4.0
	rig.add_child(omni2)
	omni2.global_position = base + Vector3(1.0, 0.5, 0)
	var was_on := _player.flashlight.visible
	_player.flashlight.visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var steps := 12 + items.size()
	var done := 0
	var batch := maxi(1, ceili(float(hidden.size()) / 12.0))
	var i := 0
	while i < hidden.size():
		for j in range(i, mini(i + batch, hidden.size())):
			if is_instance_valid(hidden[j]):
				hidden[j].visible = true
		i += batch
		done += 1
		Game.hud.show_screen(title + "\n\n" + Loc.t(&"card.preparing") % int(100.0 * done / steps))
		await get_tree().process_frame
	for it in items:
		it.visible = true
		done += 1
		Game.hud.show_screen(title + "\n\n" + Loc.t(&"card.preparing") % mini(int(100.0 * done / steps), 100))
		await get_tree().process_frame
	for n in hidden:     # страховка: что бы ни случилось по пути, мир должен быть виден целиком
		if is_instance_valid(n):
			n.visible = true
	for k in range(3):
		await get_tree().process_frame
	_player.flashlight.visible = was_on
	Game.hud.show_screen(title)
	rig.queue_free()


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _wait_click != "":
		if event is InputEventMouseButton and event.is_pressed() or event.is_action_pressed(&"interact"):
			var r := _wait_click
			_wait_click = ""
			finished.emit(r)
		return
	if _ending and event is InputEventMouseButton and event.is_pressed():
		_page_clicked = true
		return
	if _ending or get_tree().paused:
		return

	var has_note: bool = (Game.hud != null and Game.hud.is_note_open())
	if has_note:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"drop") or event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and event.is_pressed()):
			get_viewport().set_input_as_handled()
			Game.hud.hide_note()
			return

	var has_tasks_panel: bool = (Game.hud != null and Game.hud._tasks_panel != null and Game.hud._tasks_panel.visible)

	if event.is_action_pressed(&"tasks") and has_tasks_panel:
		get_viewport().set_input_as_handled()
		Game.hud.toggle_tasks()
		return

	if event.is_action_pressed(&"pause") or (event.is_action_pressed(&"ui_cancel") and (Game.hud.modal() != null or has_tasks_panel or _player.mode == Player.Mode.READING or _player.mode == Player.Mode.RADIO)):
		get_viewport().set_input_as_handled()
		if Game.hud.modal() != null:
			_close_ui()
		elif has_tasks_panel:
			Game.hud.toggle_tasks()
		elif _player.mode == Player.Mode.READING:
			Game.hud.hide_note()
			_player.mode = Player.Mode.WALK
		elif _player.mode == Player.Mode.RADIO:
			Game.radio.exit()
		elif _player.mode == Player.Mode.WALK:
			_open_pause()
		return

	var m := Game.hud.modal()
	if m != null:
		m.call(&"handle_input", event)
		return

	if OS.is_debug_build():   # отладочные клавиши — только из редактора, не в релизе
		if event.is_action_pressed(&"debug_overlay"):
			Game.hud.toggle_debug()
			return
		if event.is_action_pressed(&"debug_boost"):
			Director.add_tension(30.0, "F4")
			return
		if event.is_action_pressed(&"debug_yrka"):
			Game.yrka.force_chase()
			return
		if event.is_action_pressed(&"debug_skip"):
			Game.end_shift()
			return

	if _player.mode == Player.Mode.WALK:
		if event.is_action_pressed(&"map"):
			_open_ui(&"map")
			return
		if event.is_action_pressed(&"intercepts"):
			_open_ui(&"intercepts")
			return
		if event.is_action_pressed(&"codebook") and Game.has_item(&"codebook"):
			_open_ui(&"codebook")
			return

	if event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_player.handle_input(event)


func _open_ui(id: StringName) -> void:
	var ui: Control
	match id:
		&"map":
			ui = MapView.new()
		&"codebook":
			ui = CodebookUI.new()
		&"tape":
			ui = TapeDeckUI.new()
		&"peephole":
			ui = PeepholeUI.new()
		&"intercepts":
			ui = InterceptsUI.new()
		&"barograph":
			ui = BarographUI.new()
		&"wind_panel":
			ui = WindPanelUI.new()
		&"thermometer":
			ui = ThermometerUI.new()
		&"snow_stake":
			ui = SnowStakeUI.new()
		&"direction_finder":
			ui = DirectionFinderUI.new()
		&"morse":
			ui = MorseUI.new()
		&"safe":
			ui = SafeUI.new()
		&"book":
			ui = HeldPaper.journal(BookUI.new(), Vector2i(1080, 630))   # книга — в руках
		&"theodolite":
			ui = TheodoliteUI.new()
		&"forecast", &"report", &"journal":
			ui = HeldPaper.journal(JournalTM1UIScript.new(), Vector2i(1080, 630))   # журнал — в руках
		&"meteor_fax":
			ui = MeteorFaxUIScript.new()
		&"coop_report":
			ui = CoopReportUI.new()
		&"seismograph":
			ui = SeismographUIScript.new()
		&"supply":
			ui = SupplyUI.new()
		&"repair":
			ui = RepairUI.new()
		_:
			return


	_player.mode = Player.Mode.UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.hud.open_modal(ui)
	ui.connect(&"closed", _close_ui)


func _close_ui() -> void:
	Game.hud.close_modal()
	if not _ending and not Game.dead:
		_player.mode = Player.Mode.WALK
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_pause() -> void:
	if _pause != null or _ending or not is_inside_tree():
		return
	_pause = PauseMenu.new()
	add_child(_pause)
	if not _pause.is_inside_tree():
		# Сессия как раз собирает детей (загрузка, переход фазы) — меню не встало. Без меню паузу не
		# ставим: иначе мир замирает и снять его нечем (свернул окно → картинка встала навсегда).
		_pause.free()
		_pause = null
		return
	get_tree().paused = Net.role == ""   # в коопе мир не встаёт: у напарника ночь идёт дальше
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause.resume_requested.connect(_close_pause)
	_pause.menu_requested.connect(func() -> void:
		_close_pause()
		finished.emit("menu"))


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Финалы фаз --------------------------------------------------------------

func _lock_player() -> void:
	if Game.radio != null and Game.radio.active:
		Game.radio.exit()
	Game.hud.close_modal()
	_player.mode = Player.Mode.LOCKED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_shift_ended() -> void:
	Director.stop()
	Game.yrka.enabled = false
	_lock_player()
	_ending = true
	if Game.is_night() and Game.audio != null:
		Game.audio.play_dawn_chime()
	if Game.is_night() and Game.zenit != null and Game.zenit.has_prints():
		# Проявка под красным фонарём — до утренней карточки, пока «дело» ещё не ушло.
		Game.zenit.bank_evidence()
		var dr := DarkroomUI.new()
		Game.hud.open_modal(dr)
		await dr.closed
		Game.hud.close_modal()
	var text := Loc.t(&"card.morning") if Game.is_night() else (Loc.t(&"card.prologue_night1") if Game.is_prologue() else Loc.t(&"card.dusk"))
	if Game.anomalies != null:
		var t := Game.anomalies.tally()
		if t != "":
			text += "\n\n" + t
	if Game.is_night():
		var rt := Rituals.morning_lines()
		if rt != "":
			text += "\n\n" + rt
	await Game.hud.fade_in_screen(text, 2.0)
	await get_tree().create_timer(3.5, false).timeout
	finished.emit("advance")


func _on_player_died(reason: StringName) -> void:
	Director.stop()
	Game.yrka.enabled = false
	_lock_player()
	Game.hud.flash_red(0.8, 2.5)
	if Net.can_ghost():
		# Кооп: напарник жив — мы остаёмся «в эфире» и смотрим его ночь до рассвета.
		Net.enter_ghost()
		await get_tree().create_timer(1.2, false).timeout
		await Game.hud.fade_in_screen("%s\n\n%s\n\n%s" % [
			Loc.t(StringName("death." + String(reason))), Game.clock_text(), Loc.t(&"coop.ghost_card")], 1.5)
		await get_tree().create_timer(5.0, false).timeout
		await Game.hud.fade_out_screen(1.5)
		return
	_ending = true
	await get_tree().create_timer(1.2, false).timeout
	if Net.role != "" and Net.active():
		# Погибли оба — ночь потеряна, хост начнёт её заново. Клик — выйти из кооп-вахты в меню.
		await Game.hud.fade_in_screen("%s\n\n%s\n\n%s" % [
			Loc.t(StringName("death." + String(reason))), Game.clock_text(), Loc.t(&"coop.night_lost")], 1.5)
		Net.night_lost()
		_wait_click = "menu"
		return
	await Game.hud.fade_in_screen("%s\n\n%s\n\n%s" % [
		Loc.t(StringName("death." + String(reason))), Game.clock_text(), Loc.t(&"death.retry") if Game.is_night() else Loc.t(&"death.retry_day")], 1.5)
	_wait_click = "menu" if Net.role != "" else "retry"


func _on_report_sent(index: int) -> void:
	if index == 0 and Game.is_night() and not Game.dead:
		Game.save_checkpoint()
		Game.hud.toast(Loc.t(&"hud.saved"))


# --- Концовки ----------------------------------------------------------------

const ENDINGS: Array[StringName] = [&"answer", &"burn", &"leave", &"silence", &"echo", &"source", &"taiga"]
const FIRE := "res://assets/audio/fire_loop.ogg"
## Какая находка эфира дописывает страницу к какому финалу
const ENDING_FIND := {&"answer": &"alone", &"burn": &"bunker", &"leave": &"roll", &"silence": &"hole",
	&"source": &"otzvuk", &"echo": &"beacon"}

var _page_clicked := false


## Ночь 7: выбор сделан (или утро не наступило). Страницы текста, титры — и в меню.
func play_ending(id: StringName) -> void:
	Director.stop()
	Game.yrka.enabled = false
	Game.clock_running = false
	_lock_player()
	_ending = true
	match id:
		&"burn":
			Game.audio.play_2d(FIRE, 4.0)
			for i in range(6):
				Game.hud.flash_red(0.7, 0.5)
				_player.shake(0.05, 0.4)
				await get_tree().create_timer(0.45, false).timeout
		&"answer":
			# Ты передаёшь сводку — и в наушниках «принято» отвечает твой собственный голос.
			Game.hud.subtitle(Loc.t(&"end.answer.0"), 3.5)
			await get_tree().create_timer(3.5, false).timeout
			var copy := Voice.path(&"st_self_copy")
			Game.audio.play_2d(copy if copy != "" else "res://assets/audio/voice_mainland.ogg", 0.0)
			Game.hud.subtitle(Loc.t(&"end.answer.copy"), 3.5)
			await get_tree().create_timer(3.5, false).timeout
		&"echo":
			# В эфире — запись твоей первой смены, год назад. Голос твой.
			Game.hud.subtitle(Loc.t(&"end.echo.0"), 5.0)
			var echo_wait := 5.5
			var laz := Voice.path(&"st_lazarev")
			if laz != "":
				var lp := Game.audio.play_2d(laz, -2.0)
				if lp != null and lp.stream != null:
					echo_wait = maxf(echo_wait, lp.stream.get_length() + 0.8)
			await get_tree().create_timer(echo_wait, false).timeout
		&"leave":
			Game.audio.play_2d(SCREAM, -18.0)
		&"source":
			# Провода рвутся — и все самописцы округи, все рации разом замолкают
			Game.audio.play_2d("res://assets/audio/radio_anomaly.ogg", 0.0)
			for i in range(4):
				Game.hud.flash_red(0.5, 0.35)
				_player.shake(0.08, 0.5)
				await get_tree().create_timer(0.6, false).timeout
	# Кадр на движке: что стало со станцией (EndingShot), и только потом — текст
	var shot := EndingShot.new()
	add_child(shot)
	await shot.run(id)
	shot.queue_free()
	Game.audio.silence(true)
	Game.audio.play_ending_music()
	SaveGame.flags["ending_" + String(id)] = true
	SaveGame.write()
	# Одиночная игра: разбор концовки — уже в эпилоге, листами дела на столе у майора в Свердловске
	if Net.role == "":
		Epilogue.pages = ending_pages(id)
		Epilogue.ending_id = id
		Game.audio.silence(true)
		finished.emit("epilogue")
		return
	for i in range(1, 4):
		var key := StringName("end.%s.%d" % [id, i])
		if not Loc.has_key(key):
			break
		await _page(Loc.t(key))
	# Эфир: если нашёл то, что связано с этим финалом, — ещё одна страница (Efir)
	var link: StringName = ENDING_FIND.get(id, &"")
	if link != &"" and Efir.has_find(link):
		await _page(Loc.t(StringName("efir.end." + String(id))))
	var evidence := int(SaveGame.flags.get("evidence", 0))
	if evidence >= 3:
		await _page(Loc.t(&"end.evidence", [evidence]))   # плёнки «Зенита» ушли в Свердловск
	await _page(_case_file(id))
	var found := 0
	for e in ENDINGS:
		if SaveGame.flags.get("ending_" + String(e), false):
			found += 1
	await _page("%s\n\n%s" % [Loc.t(StringName("end.%s.title" % id)), Loc.t(&"end.found", [found, ENDINGS.size()])])
	await _page(Loc.t(&"credits"))
	finished.emit("demo_end")


## Лист «Дело №83-М»: личный итог семи ночей из того, что игра запомнила.
## Те же листы, что показывались после концовки, — для папки дела в эпилоге.
func ending_pages(id: StringName) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(1, 4):
		var key := StringName("end.%s.%d" % [id, i])
		if not Loc.has_key(key):
			break
		out.append(Loc.t(key))
	var link: StringName = ENDING_FIND.get(id, &"")
	if link != &"" and Efir.has_find(link):
		out.append(Loc.t(StringName("efir.end." + String(id))))
	var evidence := int(SaveGame.flags.get("evidence", 0))
	if evidence >= 3:
		out.append(Loc.t(&"end.evidence", [evidence]))
	out.append(_case_file(id))
	var found := 0
	for e in ENDINGS:
		if SaveGame.flags.get("ending_" + String(e), false):
			found += 1
	out.append("%s

%s" % [Loc.t(StringName("end.%s.title" % id)), Loc.t(&"end.found", [found, ENDINGS.size()])])
	return out


func _case_file(id: StringName) -> String:
	var lines := PackedStringArray([Loc.t(&"case.head"), ""])
	var missed := NightMemory.count(&"missed")
	lines.append(Loc.t(&"case.missed", [missed]) if missed > 0 else Loc.t(&"case.missed_none"))
	var real := NightMemory.count(&"real_done")
	var fake := NightMemory.count(&"obeyed_fake")
	if real + fake > 0:
		lines.append(Loc.t(&"case.orders", [real, fake]))
	var tx := NightMemory.count(&"after3_tx")
	if tx > 0:
		lines.append(Loc.t(&"case.after3", [tx]))
	var turned := NightMemory.count(&"turned")
	if turned > 0:
		lines.append(Loc.t(&"case.turned", [turned]))
	var notes := int(SaveGame.flags.get("anom_notes_total", 0))
	if notes > 0:
		lines.append(Loc.t(&"case.notes", [notes, int(SaveGame.flags.get("anom_ok_total", 0))]))
	var ev := int(SaveGame.flags.get("evidence", 0))
	if ev > 0:
		lines.append(Loc.t(&"case.photos", [ev]))
	lines.append(Loc.t(&"case.bearings", [FieldJobs.bearing_count()]))
	lines.append(Loc.t(&"case.books", [Books.read_count(), Books.ORDER.size()]))
	# Эфир: что нашёл по пеленгам и что прочитал
	var decoded := 0
	for d in SaveGame.decoded:
		if String(d).ends_with("_dec"):
			decoded += 1
	lines.append(Loc.t(&"case.efir", [Efir.df_ids().size(), Efir.find_count(), Efir.FINDS.size(), decoded, Efir.pool_found()]))
	for k in Efir.FINDS:
		if Efir.has_find(k):
			lines.append(Loc.t(StringName("case.find." + String(k))))
	if Dog.is_home():
		lines.append(Loc.t(&"case.dog_ok") if Dog.health() >= 60.0 else Loc.t(&"case.dog_weak"))
	elif SaveGame.flags.get("dog_found", false):
		lines.append(Loc.t(&"case.dog_lost"))
	lines.append("")
	lines.append(Loc.t(StringName("case.verdict." + String(id))))
	return "\n".join(lines)


func _page(text: String) -> void:
	await Game.hud.fade_in_screen(text + "\n\n" + Loc.t(&"end.next"), 1.2)
	_page_clicked = false
	var t := 0.0
	while not _page_clicked:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 2.5 and (OS.get_cmdline_user_args().has("--autotest") or OS.get_cmdline_user_args().has("--stage")):
			break
		if t > 0.6 and Input.is_action_just_pressed(&"interact"):
			_page_clicked = true


## Alt+Tab / свернул окно — ночь встаёт на паузу (в коопе нет: у напарника она идёт).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if Net.role == "" and _pause == null and not _ending and not get_tree().paused and not Game.dead \
				and Game.player != null and Game.player.mode != Player.Mode.LOCKED and not OS.get_cmdline_user_args().has("--tour") \
				and not OS.get_cmdline_user_args().has("--prologue_b"):
			_open_pause.call_deferred()   # фокус уходит и посреди загрузки, когда add_child() нельзя


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
