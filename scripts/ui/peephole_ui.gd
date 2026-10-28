class_name PeepholeUI
extends Control
## Глазок во входной двери: камера снаружи, круглая рамка. Кто стучит — видно, но не всё сразу.

signal closed

const STINGER := "res://assets/audio/sub_drop.ogg"

var _cam: Camera3D
var _prev: Camera3D
var _t := 0.0
var _stung := false
var _ring: TextureRect
var _shadow_mesh: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_prev = Game.player.camera
	_cam = Camera3D.new()
	_cam.fov = 105.0
	_cam.near = 0.05
	Game.level.add_child(_cam)
	_cam.global_position = Vector3(14.56, 1.60, 3.1)
	_cam.look_at(Vector3(17.2, 1.55, 3.1), Vector3.UP)
	_cam.current = true
	if Game.events != null and Game.events.knocking:
		Game.events.peep_pose()
	elif Game.is_night() and Game.night in [3, 4]:
		_shadow_mesh = Geo.box_mesh(Vector3(0.55, 0.01, 1.7), Palette.m(&"dark"))
		_shadow_mesh.position = Vector3(15.6, 0.05, 3.1)
		_shadow_mesh.rotation.y = deg_to_rad(15.0)
		Game.level.add_child(_shadow_mesh)
		Game.audio.play_2d("res://assets/audio/whisper.ogg", -8.0)
		Director.add_tension(6.0, "тень под дверью в глазке")
	_ring = TextureRect.new()
	_ring.texture = _ring_texture()
	_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring.stretch_mode = TextureRect.STRETCH_SCALE
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Game.hud == null or not Game.hud.cinematic:   # в сцене холодного старта подсказок нет
		var hint := UiKit.label(Loc.t(&"peep.hint"), 15, HORIZONTAL_ALIGNMENT_CENTER)
		hint.modulate = Color(1, 1, 1, 0.6)
		UiKit.place(self, hint, 0.5, 1, 0.5, 1, -300, -55, 300, -25)

	if Game.events != null and Game.events.knocking:
		var p_key := &"peep.interrogate_countersign" if Game.countersign_known else &"peep.interrogate"
		_interrogate_label = UiKit.label(Loc.t(p_key), 15, HORIZONTAL_ALIGNMENT_CENTER)
		_interrogate_label.modulate = Color(1.0, 0.85, 0.45, 0.95)
		UiKit.place(self, _interrogate_label, 0.5, 1, 0.5, 1, -480, -85, 480, -55)


func _process(delta: float) -> void:
	_t += delta
	# Лёгкое дыхание камеры — смотришь, прижавшись к двери.
	_cam.h_offset = sin(_t * 1.3) * 0.004
	_cam.v_offset = sin(_t * 0.9) * 0.004
	if not _stung and _t > 2.0 and Game.events != null and Game.events.knocking:
		_stung = true
		# Двойник рывком прижимается лицом к глазку: в линзе — его глаз в упор, не моргает
		_press_face(Game.events.obmiralo)

		Game.audio.play_2d(STINGER, 2.0)
		Game.player.shake(0.06, 0.4)
		Game.hud.subtitle(Loc.t(&"sub.peephole_stare"), 3.5)
		Director.add_tension(18.0, "белый глаз в глазке")

		# И в этот же миг: шёпот Семёнова из запертой спальни ЗА спиной
		var tree := get_tree()
		if tree != null:
			tree.create_timer(1.8).timeout.connect(func():
				if Game.audio != null and is_instance_valid(Game.audio):
					Game.audio.play_3d("res://assets/audio/whisper.ogg", Vector3(10.6, 1.4, 4.6), 2.5, 8.0)
				if Game.hud != null and is_instance_valid(Game.hud):
					Game.hud.subtitle(Loc.t(&"sub.semenov_inside"), 4.5)
			)


var _interrogating := false
var _interrogate_label: Label


func _ask(choice: int) -> void:
	_interrogating = true
	if is_instance_valid(_interrogate_label):
		_interrogate_label.visible = false
	match choice:
		1:
			Game.hud.subtitle(Loc.t(&"sub.peep_ask_who"), 2.2)
			await get_tree().create_timer(1.4, false).timeout
			if not is_inside_tree(): return
			Game.audio.play_2d("res://assets/audio/whisper.ogg", -2.0)
			Game.hud.subtitle(Loc.t(&"sub.peep_ans_mimic"), 3.8)
			Director.add_tension(8.0, "допрос: имитация")
		2:
			Game.hud.subtitle(Loc.t(&"sub.peep_ask_pass"), 2.2)
			await get_tree().create_timer(1.4, false).timeout
			if not is_inside_tree(): return
			Game.audio.play_2d("res://assets/sfx/door_handle.ogg", 1.0)
			Game.hud.subtitle(Loc.t(&"sub.peep_ans_breath"), 3.8)
			Director.add_tension(10.0, "допрос: дыхание в щель")
		3:
			Game.hud.subtitle(Loc.t(&"sub.peep_ask_away"), 2.0)
			await get_tree().create_timer(1.0, false).timeout
			if not is_inside_tree(): return
			Game.audio.play_2d("res://assets/audio/door_knock.ogg", 4.0)
			Game.player.shake(0.08, 0.45)
			Director.add_tension(14.0, "удар в дверь на окрик")
		4:
			Game.hud.subtitle(Loc.t(&"sub.peep_countersign"), 2.2)
			await get_tree().create_timer(1.2, false).timeout
			if not is_inside_tree(): return
			AudioDirector.play_raw("res://assets/audio/step_snow_1.ogg", 0.0)
			AudioDirector.play_raw("res://assets/sfx/scratch_wall.ogg", -4.0)
			Game.hud.subtitle(Loc.t(&"sub.peep_countersign_ans"), 4.0)
			if Game.events != null and Game.events.has_method(&"repel_knock_with_countersign"):
				Game.events.repel_knock_with_countersign()
	await get_tree().create_timer(3.0, false).timeout
	_interrogating = false
	if is_inside_tree() and is_instance_valid(_interrogate_label) and Game.events != null and Game.events.knocking:
		_interrogate_label.visible = true


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"drop"):
		closed.emit()
		return
	if _interrogating or Game.events == null or not Game.events.knocking:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_1 or k == KEY_KP_1:
			_ask(1)
		elif k == KEY_2 or k == KEY_KP_2:
			_ask(2)
		elif k == KEY_3 or k == KEY_KP_3:
			_ask(3)
		elif (k == KEY_4 or k == KEY_KP_4) and Game.countersign_known:
			_ask(4)
	elif event is InputEventJoypadButton and event.is_pressed():
		var btn := (event as InputEventJoypadButton).button_index
		if btn == JOY_BUTTON_DPAD_UP or btn == JOY_BUTTON_X:
			_ask(1)
		elif btn == JOY_BUTTON_DPAD_RIGHT or btn == JOY_BUTTON_Y:
			_ask(2)
		elif btn == JOY_BUTTON_DPAD_DOWN:
			_ask(3)
		elif (btn == JOY_BUTTON_DPAD_LEFT or btn == JOY_BUTTON_RIGHT_SHOULDER) and Game.countersign_known:
			_ask(4)


func _exit_tree() -> void:
	if is_instance_valid(_prev):
		_prev.current = true
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_shadow_mesh):
		_shadow_mesh.queue_free()


## Лицо двойника вплотную к линзе: его правый глаз — прямо в глазок, в 13 см от камеры.
## Высота глаза у каждого лица своя (шея растёт по ночам) — берём её с кости головы.
## Слабый тёплый свет из прихожей сквозь линзу ложится на лицо — иначе в упор одна чернота.
func _press_face(rig: CreatureRig) -> void:
	if not is_instance_valid(rig):
		return
	rig.pose_override = &"still"
	rig.twitch = 0.0
	rig.global_position = Vector3(15.6, 0.0, 3.1)
	rig.look_at(Vector3(14.0, 0.0, 3.1), Vector3.UP)
	await get_tree().process_frame
	if not is_instance_valid(rig) or not is_instance_valid(_cam):
		return
	# «Head/Rest» — кадр покоя, приклеенный к кости головы: точка глаза из модели едет вместе с наклоном головы
	var rest := rig.get_node_or_null("Head/Rest") as Node3D
	var eye_local := Vector3(0.033, float(rig.get_meta(&"eye_h", 1.6)), -0.135)
	var eye := rest.global_transform * eye_local if rest != null else rig.global_transform * eye_local
	var want := _cam.global_position + Vector3(0.09, 0.0, 0.0)
	rig.global_position += want - eye
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.6)
	lamp.light_energy = 0.22
	lamp.omni_range = 0.5
	lamp.shadow_enabled = false
	Game.level.add_child(lamp)
	lamp.global_position = _cam.global_position + Vector3(0.03, 0.04, 0.0)
	_shadow_mesh = lamp


## Чёрная рамка с круглым окошком и мутным краем линзы.
static func _ring_texture() -> ImageTexture:
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(w * 0.5, h * 0.5)
	for y in range(h):
		for x in range(w):
			var d := Vector2(x, y).distance_to(c) / (h * 0.46)
			var a := clampf((d - 0.82) / 0.18, 0.0, 1.0)
			var tint := clampf((d - 0.55) / 0.45, 0.0, 1.0) * 0.35
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, maxf(a, tint)))
	return ImageTexture.create_from_image(img)
