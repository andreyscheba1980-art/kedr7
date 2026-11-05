class_name Epilogue
extends Node
## Эпилог после любой концовки: Свердловск, утро. Играешь за майора Ковалёва, куратора объекта «Отзвук».
## «Волга» по проспекту → управление → лифт на 4-й → в кабинете 412 снять пальто и шапку →
## секретарь Зоя приносит дело дежурного (страницы разбора концовки) → этаж можно обойти:
## архив личных дел всех смен с 1961-го, отдел «Т» (досье на тварь, Навь, «Отзвук»), кабинет начальника →
## сдать дело в архив → в кабинете звонит телефон: «Новый сотрудник прибудет на Кедр-7…». Титры.
## Своё управление и свой HUD: не зависит от станции, двора и Game.player.

signal finished

const SNOW := "res://assets/audio/step_snow_1.ogg"
const WOOD := ["res://assets/audio/step_wood_1.ogg", "res://assets/audio/step_wood_2.ogg", "res://assets/audio/step_wood_3.ogg"]
const ENGINE := "res://assets/audio/engine_loop.ogg"
const RING := "res://assets/audio/buzzer_loop.ogg"
const PAGE := "res://assets/sfx/page_turn.wav"
const SPOT_LAYER := 1 << 19
const POST_SHADER := "res://assets/shaders/ps1_post.gdshader"

## Страницы дела (разбор концовки) — кладёт Session перед переходом.
static var pages: PackedStringArray = []
static var ending_id: StringName = &""

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _body: CharacterBody3D
var _car: Node3D
var _steer: Node3D
var _env: Environment
var _snow: CPUParticles3D
var _engine: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _ring: AudioStreamPlayer

var mode := &"drive"            ## drive | walk | doc | locked
var stage := &"drive"
var _speed := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _step_t := 0.0
var _hint_spot: Area3D
var _esc_armed := 0.0
var _flags := {}
var _f4: Dictionary
var _lobby: Dictionary
var _ring_t := -1.0
var _life: EpLife
var _cab: Dictionary
var _wing: Dictionary
var _lift_busy := false
var _lift_floor := 1

# HUD
var _hud: CanvasLayer
var _prompt: Label
var _sub: Label
var _sub_t := 0.0
var _goal: Label
var _fade: ColorRect
var _doc: Control
var _doc_text: Label
var _doc_page: Label
var _doc_pages: PackedStringArray = []
var _doc_i := 0
var _doc_done: Callable
var _docv: DocView


func _ready() -> void:
	name = "Epilogue"
	_build_view()
	_build_hud()
	_world = Node3D.new()
	_vp.add_child(_world)
	_build_env()
	EpBuild.city(_world)
	_lobby = EpBuild.lobby(_world)
	_f4 = EpBuild.floor4(_world)
	_cab = EpBuild.lift_cabin(_world)
	_wing = EpBuild.wing(_world)
	_dress_lobby()
	_dress_floor()
	_build_car()
	_life = EpLife.new()
	_life.setup(self)
	add_child(_life)
	_build_walker()
	_engine = _loop(ENGINE, -14.0)
	_wind = _loop("res://assets/audio/wind_loop.ogg", -20.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_fade.color.a = 1.0
	_set_goal(&"ep.goal.drive")
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.5)
	_say(&"ep.intro", 7.0)


# --- Сцена и HUD ---------------------------------------------------------------

func _build_view() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = Settings.render_shrink()
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = load(POST_SHADER)
	container.material = post
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.audio_listener_enable_3d = true
	_vp.msaa_3d = Settings.msaa()
	container.add_child(_vp)


func _build_env() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.07, 0.09, 0.16)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.35, 0.4, 0.55)
	_env.ambient_light_energy = 0.55
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.12, 0.14, 0.22)
	_env.fog_density = 0.018
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = Settings.quality >= 1   # ореол у ламп и окон
	_env.glow_intensity = 0.5
	_env.glow_hdr_threshold = 0.8
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.12
	_env.adjustment_saturation = 0.88
	we.environment = _env
	_world.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.5, 0.58, 0.8)
	moon.light_energy = 0.25
	moon.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	_world.add_child(moon)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 20
	add_child(_hud)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.6)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	_hud.add_child(dot)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_fade)
	_prompt = _label(20, Color(0.95, 0.92, 0.85))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = 30
	_prompt.offset_bottom = 60
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = _label(22, Color(0.95, 0.92, 0.85))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -560
	_sub.offset_right = 560
	_sub.offset_top = -190
	_sub.offset_bottom = -70
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal = _label(17, Color(0.85, 0.8, 0.6))
	_goal.position = Vector2(28, 24)
	# Читалка документов: лист бумаги по центру
	_doc = Control.new()
	_doc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_doc.visible = false
	_hud.add_child(_doc)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_doc.add_child(dim)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.PAPER
	sb.set_content_margin_all(36)
	paper.add_theme_stylebox_override(&"panel", sb)
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left = -430
	paper.offset_right = 430
	paper.offset_top = -320
	paper.offset_bottom = 320
	_doc.add_child(paper)
	var col := VBoxContainer.new()
	paper.add_child(col)
	_doc_text = Label.new()
	_doc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_doc_text.custom_minimum_size = Vector2(780, 520)
	_doc_text.add_theme_font_size_override(&"font_size", 18)
	_doc_text.add_theme_color_override(&"font_color", UiKit.INK)
	col.add_child(_doc_text)
	_doc_page = Label.new()
	_doc_page.add_theme_font_size_override(&"font_size", 14)
	_doc_page.add_theme_color_override(&"font_color", Color(UiKit.INK, 0.6))
	col.add_child(_doc_page)


func _label(sz: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", sz)
	l.add_theme_color_override(&"font_color", c)
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"shadow_offset_x", 2)
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	_hud.add_child(l)
	return l


func _say(key: StringName, dur := 5.0, args: Array = []) -> void:
	_sub.text = Loc.t(key, args) if not args.is_empty() else Loc.t(key)
	_sub_t = dur


func _set_goal(key: StringName) -> void:
	_goal.text = Loc.t(key)


func _loop(path: String, vol: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = AudioDirector.cached_stream(path)
	if a.stream is AudioStreamOggVorbis:
		(a.stream as AudioStreamOggVorbis).loop = true
	a.volume_db = vol
	add_child(a)
	a.play()
	return a


func _sfx(path: String, vol := 0.0, pitch := 1.0) -> void:
	var a := AudioStreamPlayer.new()
	a.stream = AudioDirector.cached_stream(path)
	a.volume_db = vol
	a.pitch_scale = pitch
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


func _blink(then: Callable, dur := 0.7) -> void:
	mode = &"locked"
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur * 0.5)
	tw.tween_callback(then)
	tw.tween_property(_fade, "color:a", 0.0, dur * 0.5)
	tw.tween_callback(func() -> void:
		if mode == &"locked":
			mode = &"walk")


# --- Машина и пешеход -------------------------------------------------------------

func _build_car() -> void:
	_car = EpBuild.volga(Color(0.1, 0.1, 0.11), true)
	_car.position = Vector3(2.5, 0.0, 6.0)
	_world.add_child(_car)
	_steer = EpBuild.volga_cabin(_car)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 140.0
	_cam.position = Vector3(-0.4, 1.32, 0.05)
	_car.add_child(_cam)
	_cam.current = true
	var hl := SpotLight3D.new()
	hl.light_color = Color(1.0, 0.92, 0.75)
	hl.light_energy = 3.0
	hl.spot_range = 40.0
	hl.spot_angle = 32.0
	hl.position = Vector3(0, 0.7, -2.4)
	hl.rotation.x = deg_to_rad(-6.0)
	_car.add_child(hl)
	_snow = CPUParticles3D.new()
	_snow.amount = 500
	_snow.lifetime = 4.0
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(14, 1, 14)
	_snow.direction = Vector3(0.2, -1, 0)
	_snow.initial_velocity_min = 1.2
	_snow.initial_velocity_max = 2.0
	_snow.gravity = Vector3.ZERO
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_color = Color(0.9, 0.92, 1.0)
	qm.material = sm
	_snow.mesh = qm
	_world.add_child(_snow)


func _build_walker() -> void:
	_body = CharacterBody3D.new()
	_body.collision_mask = Geo.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	_body.add_child(cs)
	_world.add_child(_body)
	_body.process_mode = Node.PROCESS_MODE_DISABLED


func _enter_walk(at: Vector3, yaw: float) -> void:
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	_body.global_position = at
	_yaw = yaw
	_pitch = 0.0
	_cam.reparent(_body, false)
	_cam.position = Vector3(0, 1.62, 0)
	_cam.rotation = Vector3.ZERO
	_body.rotation.y = _yaw
	mode = &"walk"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mode != &"doc":
		var sens := 0.0022 * Settings.mouse_sens
		var ys := -1.0 if Settings.invert_y else 1.0
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * ys, -1.3, 1.3)
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		if mode == &"doc":
			if _docv != null and is_instance_valid(_docv):
				_docv.handle_input(event)
			else:
				_close_doc()
		elif _esc_armed > 0.0:
			_finish()
		else:
			_esc_armed = 3.0
			_say(&"ep.skip", 3.0)
		return
	if mode == &"doc":
		if _docv != null and is_instance_valid(_docv):
			if not (event is InputEventMouseMotion):
				_docv.handle_input(event)
				if event.is_pressed() and not (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
					_sfx(PAGE, -10.0, randf_range(0.95, 1.05))
		return
	if event.is_action_pressed(&"interact"):
		_interact()


func _process(delta: float) -> void:
	_sub_t -= delta
	if _sub_t <= 0.0:
		_sub.text = ""
	_esc_armed = maxf(_esc_armed - delta, 0.0)
	if _snow != null and _cam != null:
		_snow.global_position = _cam.global_position + Vector3(0, 6, 0)
		_snow.visible = _cam.global_position.z < 100.0
	_env.fog_density = 0.018 if _cam.global_position.z < 100.0 else 0.002
	if _wind != null:
		_wind.volume_db = -20.0 if _cam.global_position.z < 100.0 else -60.0
	if mode == &"drive":
		_drive(delta)
	elif mode == &"walk":
		_walk(delta)
	_update_prompt()
	if _ring_t >= 0.0:
		_ring_t += delta
		if fmod(_ring_t, 3.0) < delta:
			_sfx(RING, -6.0, 1.35)


func _drive(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var throttle := -input.y
	var target := throttle * (14.0 if throttle > 0.0 else 5.0)
	_speed = move_toward(_speed, target, (5.0 if absf(target) > absf(_speed) else 8.0) * delta)
	var steer := -input.x * clampf(absf(_speed) / 6.0, 0.0, 1.0) * signf(_speed if _speed != 0.0 else 1.0)
	_car.rotation.y += steer * 0.9 * delta
	var fwd := -_car.global_transform.basis.z
	var p := _car.global_position + fwd * _speed * delta
	p.x = clampf(p.x, -EpBuild.ROAD_HALF + 1.1, EpBuild.PARK.position.x + EpBuild.PARK.size.x - 0.6)
	p.z = clampf(p.z, -EpBuild.STREET_LEN - 12.0, 10.0)
	# В кармане парковки можно только у управления
	if p.x > EpBuild.ROAD_HALF - 1.1 and not EpBuild.PARK.has_point(Vector2(p.x, p.z)):
		p.x = EpBuild.ROAD_HALF - 1.1
	_car.global_position = p
	_steer.rotation.y = -input.x * 1.2
	_cam.rotation = Vector3(_pitch, _yaw, 0)
	_yaw = clampf(_yaw, -1.6, 1.6)
	_engine.pitch_scale = 0.8 + absf(_speed) / 14.0 * 0.8
	_engine.volume_db = -14.0 + absf(_speed) * 0.4


func _walk(delta: float) -> void:
	_body.rotation.y = _yaw
	_cam.rotation.x = _pitch
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := (_body.global_transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	var spd := 2.6 if not Input.is_action_pressed(&"sprint") else 4.0
	_body.velocity.x = dir.x * spd
	_body.velocity.z = dir.z * spd
	_body.velocity.y = 0.0 if _body.is_on_floor() else _body.velocity.y - 9.8 * delta
	_body.move_and_slide()
	if input.length() > 0.1:
		_step_t -= delta * (1.4 if spd > 3.0 else 1.0)
		if _step_t <= 0.0:
			_step_t = 0.48
			var outdoor := _body.global_position.z < 100.0
			_sfx(SNOW if outdoor else WOOD[randi() % WOOD.size()], -10.0 if outdoor else -14.0, randf_range(0.9, 1.1))
	_check_lift_exit()
	# 412: вернулся после архива — звонок
	if stage == &"return" and _in_room(&"412"):
		stage = &"ring"
		_ring_t = 0.0
		_set_goal(&"ep.goal.phone")


func _in_room(id: StringName) -> bool:
	var s: Dictionary = _f4.get(id, {})
	if s.is_empty():
		return false
	var p := _body.global_position
	var side: float = s["side"]
	var z_in: float = EpBuild.FLOOR4.z + side * EpBuild.CORR_HALF
	return p.x > float(s["x0"]) and p.x < float(s["x1"]) and (p.z - z_in) * side > 0.3


# --- Точки взаимодействия -----------------------------------------------------------

func _spot(pos: Vector3, size: Vector3, prompt: Variant, use: Callable) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = SPOT_LAYER
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	a.position = pos
	a.set_meta(&"prompt", prompt)
	a.set_meta(&"use", use)
	_world.add_child(a)
	return a


func _look_spot() -> Area3D:
	if _cam == null:
		return null
	var space := _cam.get_world_3d().direct_space_state
	var from := _cam.global_position
	var to := from - _cam.global_transform.basis.z * 2.6
	var q := PhysicsRayQueryParameters3D.create(from, to, SPOT_LAYER)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := space.intersect_ray(q)
	return hit.get("collider") as Area3D if not hit.is_empty() else null


func _update_prompt() -> void:
	if mode == &"doc" or mode == &"locked":
		_prompt.text = ""
		return
	if mode == &"drive":
		if EpBuild.PARK.has_point(Vector2(_car.global_position.x, _car.global_position.z)) and absf(_speed) < 1.0:
			_prompt.text = Loc.t(&"ep.p.park")
		else:
			_prompt.text = ""
		return
	_hint_spot = _look_spot()
	if _hint_spot == null or not is_instance_valid(_hint_spot):
		_prompt.text = ""
		return
	var pr: Variant = _hint_spot.get_meta(&"prompt")
	var text := ""
	if pr is Callable:
		text = (pr as Callable).call()
	else:
		text = Loc.t(StringName(String(pr)))
	_prompt.text = ("[E] " + text) if text != "" else ""


func _interact() -> void:
	if mode == &"drive":
		if EpBuild.PARK.has_point(Vector2(_car.global_position.x, _car.global_position.z)) and absf(_speed) < 1.0:
			_park()
		return
	if mode != &"walk":
		return
	var s := _look_spot()
	if s != null and is_instance_valid(s):
		var use: Callable = s.get_meta(&"use")
		if use.is_valid():
			use.call()


func _park() -> void:
	_speed = 0.0
	_sfx("res://assets/audio/door.ogg", -6.0)
	var tw := create_tween()
	tw.tween_property(_engine, "volume_db", -60.0, 1.0)
	_blink(func() -> void:
		_engine.stop()
		var out := _car.global_position + _car.global_transform.basis.x * 1.7
		_enter_walk(Vector3(out.x, 0.45, out.z), deg_to_rad(-90.0))
		stage = &"street"
		_set_goal(&"ep.goal.enter"), 1.2)


# --- Документы ----------------------------------------------------------------------

func _open_doc(p: PackedStringArray, on_done := Callable(), folder := false) -> void:
	if p.is_empty():
		return
	_doc_pages = p
	_doc_i = 0
	_doc_done = on_done
	_sub.text = ""
	mode = &"doc"
	_sfx(PAGE, -6.0)
	if _docv != null and is_instance_valid(_docv):
		_docv.queue_free()
	if folder:
		_docv = DocView.folder(PackedStringArray([Loc.t(&"ep.folder_no"), Loc.t(&"ep.folder_obj"), Loc.t(&"ep.folder_who")]), p)
	else:
		_docv = DocView.sheet(p, true)
	_hud.add_child(_docv)
	_docv.closed.connect(_close_doc)


func _doc_from(prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(1, 12):
		var key := StringName("%s.%d" % [prefix, i])
		if not Loc.has_key(key):
			break
		out.append(Loc.t(key))
	return out


func _show_page() -> void:
	_doc_text.text = _doc_pages[_doc_i]
	_doc_page.text = Loc.t(&"ep.doc_nav", [_doc_i + 1, _doc_pages.size()])


func _doc_next() -> void:
	if _doc_i < _doc_pages.size() - 1:
		_doc_i += 1
		_sfx(PAGE, -8.0, randf_range(0.95, 1.05))
		_show_page()
	else:
		_close_doc()


func _close_doc() -> void:
	_doc.visible = false
	if _docv != null and is_instance_valid(_docv):
		_docv.queue_free()
	_docv = null
	mode = &"walk"
	var cb := _doc_done
	_doc_done = Callable()
	if cb.is_valid():
		cb.call()


# --- Наполнение и сценарий -------------------------------------------------------------

func _dress_lobby() -> void:
	# Крыльцо снаружи — войти
	_spot(EpBuild.KGB_DOOR + Vector3(-0.6, 1.2, 0), Vector3(1.0, 2.4, 2.6), "ep.p.door", func() -> void:
		_sfx("res://assets/audio/door.ogg", -4.0)
		_blink(func() -> void:
			_enter_walk(_lobby["spawn"], 0.0)
			stage = &"drive_done"
			_set_goal(&"ep.goal.pass")
			_say(&"ep.lobby", 5.0)))
	# Проходная: без удостоверения турникет не пустит
	_spot(_lobby["guard"], Vector3(2.4, 1.4, 1.0), func() -> String:
		return Loc.t(&"ep.p.guard") if not _flags.get("id_shown", false) else Loc.t(&"ep.p.talk", [Loc.t(&"ep.npc.post.name")]), func() -> void:
		if not _flags.get("id_shown", false):
			_flags["id_shown"] = true
			_say(&"ep.guard", 5.0)
			_sfx("res://assets/audio/clank.ogg", -8.0, 1.2)
			(_lobby["gate"] as StaticBody3D).collision_layer = 0
			var tw := create_tween()
			tw.tween_property(_lobby["pole"] as Node3D, "rotation:z", deg_to_rad(-80.0), 0.6)
			_set_goal(&"ep.goal.lift")
		else:
			_say(&"ep.npc.post.1", 5.0))
	# Лифт: двери в холле → кабина → кнопка «4» → едем (табло, гул, тряска) → двери → коридор 4-го
	_spot(_lobby["lift"], Vector3(2.2, 2.6, 1.0), "ep.p.lift_up", func() -> void:
		_sfx("res://assets/audio/door.ogg", -8.0, 1.4)
		_blink(func() -> void:
			_enter_walk(_cab["spawn"], PI)
			_lift_floor = 1
			(_cab["indicator"] as Label3D).text = "1"
			_set_doors(false, 0.0)
			_set_goal(&"ep.goal.button"), 0.8))
	_spot(_cab["panel"], Vector3(0.3, 0.7, 0.5), func() -> String:
		return "" if _lift_busy else Loc.t(&"ep.p.button4"), _ride_up)


func _dress_floor() -> void:
	_spot(_f4["lift"], Vector3(0.6, 2.4, 1.8), "ep.p.lift_down", func() -> void: _say(&"ep.lift_no", 3.5))
	# 412 — свой кабинет: стол, лампа, телефон, вешалка, сейф, портрет
	var r: Dictionary = _f4[&"412"]
	var c: Vector3 = r["center"]
	var side: float = r["side"]
	var desk := Props.desk()
	desk.position = c + Vector3(0, 0, side * 1.0)
	desk.rotation.y = PI if side > 0 else 0.0
	_world.add_child(desk)
	Geo.collider(_world, Vector3(2.1, 0.8, 0.85), desk.position + Vector3(0, 0.4, 0))
	var chair := Props.chair()
	chair.position = c + Vector3(0, 0, side * 1.9)
	chair.rotation.y = PI if side > 0 else 0.0
	_world.add_child(chair)
	var lamp := Props.desk_lamp()
	lamp.position = desk.position + Vector3(0.7, 0.76, 0)
	_world.add_child(lamp)
	var ph := EpBuild.phone()
	ph.position = desk.position + Vector3(-0.6, 0.76, 0)
	_world.add_child(ph)
	var safe := Props.safe()
	safe.position = Vector3(float(r["x1"]) - 0.6, 0, float(r["zout"]) - side * 0.5)
	_world.add_child(safe)
	var rack := EpBuild.coat_rack()
	var rack_pos := Vector3(float(r["x0"]) + 0.5, 0, c.z - side * 1.8)
	rack.position = rack_pos
	_world.add_child(rack)
	var coat_n := EpBuild.coat()
	coat_n.position = rack_pos
	coat_n.visible = false
	_world.add_child(coat_n)
	var hat_n := EpBuild.hat()
	hat_n.position = rack_pos
	hat_n.visible = false
	_world.add_child(hat_n)
	_spot(rack_pos + Vector3(0, 1.4, 0), Vector3(0.8, 1.2, 0.8), func() -> String:
		if not coat_n.visible:
			return Loc.t(&"ep.p.coat")
		if not hat_n.visible:
			return Loc.t(&"ep.p.hat")
		return "", func() -> void:
		if not coat_n.visible:
			coat_n.visible = true
			_sfx("res://assets/sfx/paper_pick.wav", -10.0, 0.6)
		elif not hat_n.visible:
			hat_n.visible = true
			_sfx("res://assets/sfx/paper_pick.wav", -10.0, 0.8)
			if stage == &"floor":
				stage = &"wait_zoya"
				get_tree().create_timer(3.0, false).timeout.connect(_zoya_comes))
	# Дело на столе — появляется, когда Зоя принесёт
	var folder := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.32, 0.03, 0.42)
	folder.mesh = fm
	folder.material_override = EpBuild.mat(Color(0.62, 0.52, 0.32))
	folder.position = desk.position + Vector3(0, 0.79, 0)
	folder.visible = false
	folder.name = "CaseFolder"
	_world.add_child(folder)
	_spot(folder.position, Vector3(0.6, 0.3, 0.6), func() -> String:
		return Loc.t(&"ep.p.case") if folder.visible else "", func() -> void:
		if not folder.visible:
			return
		_open_doc(_case_pages(), func() -> void:
			if stage == &"case":
				stage = &"archive"
				_set_goal(&"ep.goal.archive")
				_say(&"ep.after_case", 6.0), true))
	_spot(ph.position + Vector3(0, 0.1, 0), Vector3(0.4, 0.3, 0.4), func() -> String:
		return Loc.t(&"ep.p.phone") if stage == &"ring" else Loc.t(&"ep.p.phone_idle"), func() -> void:
		if stage == &"ring":
			_answer_phone()
		else:
			_say(&"ep.phone_idle", 3.0))
	_spot(safe.position + Vector3(0, 0.6, 0), Vector3(0.8, 1.2, 0.8), "ep.p.safe", func() -> void: _open_doc(_doc_from("ep.doc.safe")))
	# 414 — приёмная: стол Зои, машинка, журнал входящих
	var r2: Dictionary = _f4[&"414"]
	var d2 := Props.desk()
	d2.position = (r2["center"] as Vector3) + Vector3(0, 0, -0.6)
	_world.add_child(d2)
	Geo.collider(_world, Vector3(2.1, 0.8, 0.85), d2.position + Vector3(0, 0.4, 0))
	_spot(d2.position + Vector3(0, 0.9, 0), Vector3(1.6, 0.5, 0.8), "ep.p.incoming", func() -> void: _open_doc(_doc_from("ep.doc.incoming")))
	# 415 — отдел «Т»: доска с фото и нитками, стол с мансийскими записями, шкаф со справкой
	var r3: Dictionary = _f4[&"415"]
	var c3: Vector3 = r3["center"]
	# Доска с фото — на западной стене (не на окне)
	var bxw := float(r3["x0"]) + 0.14
	var board := Geo.block(_world, Vector3(0.05, 1.4, 2.4), Vector3(bxw, 1.6, c3.z), EpBuild.mat(Color(0.5, 0.38, 0.24)), false)
	board.name = "PhotoBoard"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 9:
		var ph2 := Geo.block(_world, Vector3(0.01, 0.18, 0.24), Vector3(bxw + 0.035, 1.2 + (k / 3) * 0.4, c3.z - 0.95 + (k % 3) * 0.95 + rng.randf_range(-0.1, 0.1)), EpBuild.mat(Color(0.82, 0.8, 0.74)), false)
		ph2.rotation.x = rng.randf_range(-0.12, 0.12)
	for k in 5:
		var th := Geo.block(_world, Vector3(0.005, 0.008, 1.0), Vector3(bxw + 0.045, 1.5 + sin(k) * 0.25, c3.z - 0.4 + k * 0.2), EpBuild.mat(Color(0.7, 0.08, 0.06)), false)
		th.rotation.x = k * 0.6 - 1.0
	_spot(Vector3(bxw + 0.4, 1.6, c3.z), Vector3(0.6, 1.4, 2.4), "ep.p.board", func() -> void: _open_doc(_doc_from("ep.doc.yrka")))
	var d3 := Props.desk()
	d3.position = c3 + Vector3(0.6, 0, -0.9)
	d3.rotation.y = PI * 0.5
	_world.add_child(d3)
	_spot(d3.position + Vector3(0, 0.9, 0), Vector3(0.9, 0.5, 1.8), "ep.p.mansi", func() -> void: _open_doc(_doc_from("ep.doc.nav")))
	var sh3 := Props.shelf()
	sh3.position = Vector3(float(r3["x1"]) - 0.4, 0, c3.z)
	sh3.rotation.y = -PI * 0.5
	_world.add_child(sh3)
	_spot(sh3.position + Vector3(0, 1.0, 0), Vector3(0.8, 1.8, 1.2), "ep.p.otzvuk", func() -> void: _open_doc(_doc_from("ep.doc.otzvuk")))
	# 418 — архив: стеллажи, стол с личными делами, полка «Кедр-7»
	var r4: Dictionary = _f4[&"418"]
	var c4: Vector3 = r4["center"]
	for k in 3:
		var st := Props.storage_shelves()
		st.position = Vector3(float(r4["x0"]) + 1.4 + k * 2.6, 0, float(r4["zout"]) + 0.6)
		_world.add_child(st)
		Geo.collider(_world, Vector3(1.6, 1.8, 0.5), st.position + Vector3(0, 0.9, 0))
	var d4 := Props.desk()
	d4.position = c4 + Vector3(0, 0, 0.6)
	_world.add_child(d4)
	Geo.collider(_world, Vector3(2.1, 0.8, 0.85), d4.position + Vector3(0, 0.4, 0))
	for k in 7:
		var f := Geo.block(_world, Vector3(0.3, 0.03 + k * 0.0, 0.4), d4.position + Vector3(-0.8 + (k % 4) * 0.5, 0.78 + (k / 4) * 0.03, -0.1 + (k / 4) * 0.12), EpBuild.mat(Color(0.6, 0.5, 0.3) * (0.9 + k * 0.02)), false)
		f.rotation.y = k * 0.2 - 0.6
	_spot(d4.position + Vector3(0, 0.9, 0), Vector3(2.0, 0.5, 0.9), "ep.p.staff", func() -> void: _open_doc(_doc_from("ep.doc.staff")))
	_spot(Vector3(float(r4["x0"]) + 4.0, 1.2, float(r4["zout"]) + 0.9), Vector3(1.6, 1.6, 0.8), func() -> String:
		return Loc.t(&"ep.p.shelve") if stage == &"archive" else Loc.t(&"ep.p.shelf"), func() -> void:
		if stage == &"archive":
			stage = &"return"
			folder.visible = false
			_sfx(PAGE, -6.0, 0.8)
			_say(&"ep.shelved", 5.0)
			_set_goal(&"ep.goal.return")
		else:
			_say(&"ep.shelf_look", 4.0))
	# 420 — начальник: стол, портрет, телеграмма и анкета кандидата
	var r5: Dictionary = _f4[&"420"]
	var c5: Vector3 = r5["center"]
	var d5 := Props.desk()
	d5.position = c5 + Vector3(0, 0, 1.0)
	d5.rotation.y = PI
	_world.add_child(d5)
	Geo.collider(_world, Vector3(2.1, 0.8, 0.85), d5.position + Vector3(0, 0.4, 0))
	Geo.block(_world, Vector3(0.6, 0.8, 0.04), Vector3(c5.x, 2.0, float(r5["zout"]) - 0.16), EpBuild.mat(Color(0.35, 0.28, 0.2)), false)
	_spot(d5.position + Vector3(-0.5, 0.9, 0), Vector3(0.9, 0.5, 0.8), "ep.p.telegram", func() -> void: _open_doc(_doc_from("ep.doc.telegram")))
	_spot(d5.position + Vector3(0.5, 0.9, 0), Vector3(0.9, 0.5, 0.8), "ep.p.candidate", func() -> void: _open_doc(_doc_from("ep.doc.candidate")))


func _set_doors(open: bool, dur := 0.8) -> void:
	var dl: Node3D = _cab["door_l"]
	var dr: Node3D = _cab["door_r"]
	var c := EpBuild.LIFT
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dl, "position:x", c.x - (0.82 if open else 0.28), maxf(dur, 0.01))
	tw.tween_property(dr, "position:x", c.x + (0.82 if open else 0.28), maxf(dur, 0.01))
	(dl as CollisionObject3D).collision_layer = 0 if open else Geo.LAYER_WORLD
	(dr as CollisionObject3D).collision_layer = 0 if open else Geo.LAYER_WORLD


func _ride_up() -> void:
	if _lift_busy or _lift_floor == 4:
		return
	_lift_busy = true
	_sfx("res://assets/sfx/paper_pick.wav", -10.0, 1.8)
	var hum := _loop("res://assets/audio/hum_loop.ogg", -12.0)
	hum.pitch_scale = 0.6
	for f in range(2, 5):
		await get_tree().create_timer(1.4, false).timeout
		(_cab["indicator"] as Label3D).text = str(f)
		_cam.position.y = 1.62 + 0.02
		await get_tree().create_timer(0.08, false).timeout
		_cam.position.y = 1.62
	if hum != null:
		hum.stop()
		hum.queue_free()
	_sfx("res://assets/audio/clank.ogg", -10.0, 1.5)
	_lift_floor = 4
	_set_doors(true)
	await get_tree().create_timer(0.9, false).timeout
	_lift_busy = false
	_set_goal(&"ep.goal.exit_lift")


func _check_lift_exit() -> void:
	if _lift_floor == 4 and stage == &"drive_done" and _body.global_position.z < EpBuild.LIFT.z - 1.1 and _body.global_position.z > EpBuild.LIFT.z - 4.0:
		stage = &"floor"
		_blink(func() -> void:
			_enter_walk(_f4["spawn"], deg_to_rad(90.0))
			_set_goal(&"ep.goal.undress")
			_say(&"ep.floor", 5.0), 0.5)


func _zoya_comes() -> void:
	var r: Dictionary = _f4[&"412"]
	var door: Vector3 = r["door"]
	var side: float = r["side"]
	_sfx("res://assets/sfx/knock_door.ogg", -4.0)
	var z: Node3D = _life._make({"style": &"clerk", "arm": &"folder"}) if _life != null else EpBuild.person(Color(0.32, 0.22, 0.28), Color(0.82, 0.66, 0.56), Color(0.45, 0.3, 0.18), true)
	z.position = door + Vector3(0.0, 0.0, side * 0.6)
	z.rotation.y = 0.0 if side > 0 else PI
	_world.add_child(z)
	_say(&"ep.zoya", 7.0)
	stage = &"case"
	_set_goal(&"ep.goal.case")
	(_world.find_child("CaseFolder", true, false) as Node3D).visible = true
	get_tree().create_timer(7.0, false).timeout.connect(func() -> void:
		z.queue_free()
		_sfx(WOOD[0], -14.0)
		if _life != null:
			_life.zoya_at_desk())


func _case_pages() -> PackedStringArray:
	var out: PackedStringArray = [Loc.t(&"ep.case_cover")]   # первый лист — сопроводительная
	for p in pages:
		out.append(p)
	if out.size() == 1:
		out.append(Loc.t(&"ep.case_empty"))
	return out


func _answer_phone() -> void:
	_ring_t = -1.0
	stage = &"call"
	mode = &"locked"
	_sfx("res://assets/sfx/paper_pick.wav", -8.0, 0.5)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 2.5)
	await tw.finished
	var hum := _loop("res://assets/audio/static_loop.ogg", -22.0)
	for i in range(1, 6):
		var key := StringName("ep.call.%d" % i)
		if not Loc.has_key(key):
			break
		_say(key, 6.0)
		await get_tree().create_timer(5.5, false).timeout
	hum.stop()
	_sub.text = ""
	await get_tree().create_timer(1.5, false).timeout
	_open_doc(PackedStringArray([Loc.t(&"ep.final"), Loc.t(&"credits")]), _finish)
	_docv.secret = false


func _finish() -> void:
	if stage == &"done":
		return
	stage = &"done"
	Achievements.unlock(&"case_closed")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit()
