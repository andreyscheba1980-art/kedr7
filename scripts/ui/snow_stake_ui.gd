class_name SnowStakeUI
extends Control
## Снегомерная рейка М-103 на площадке. Рейка в мире (build_stake) — настоящая: вбита в грунт, снег
## стоит на ней ровно на высоте покрова, деления через сантиметр, цифры через десять. Крупный план
## (Closeup3D) подводит камеру к рейке; колёсико / W S — вдоль рейки. Вокруг наметает гребни и ямы —
## читать у самой рейки. Ночью — в пятне фонаря; налипший снег стираешь рукавицей (ЛКМ по рейке).

signal closed

const H_TOTAL := 250.0                 ## длина рейки, см (снизу — в грунте, под снегом)
const CM_PER_NOTCH := 2.0
const PEN_SFX := "res://assets/audio/clank.ogg"
const FACE_W := 0.06

var _truth := 100.0
var _book: KMBook
var _hint: Label
var _done := false
var _close: Closeup3D
var _frost: Closeup3D.Frost
var _wipe := false
var _mouse := Vector2.ZERO
var _wipe_t := 0.0


## Высота снега сегодня (см).
static func depth() -> float:
	return float(Game.synoptic.snow_depth_cm) if Game.synoptic != null else 100.0


## Рейка в мире: снег — уровень земли (y = 0), над ним торчит (H_TOTAL − depth) см с делениями.
static func build_stake(parent: Node3D, at: Vector3) -> Node3D:
	var d := depth()
	var vis := (H_TOTAL - d) / 100.0
	var root := Node3D.new()
	root.name = "SnowStakeModel"
	root.position = at
	parent.add_child(root)
	var post := Geo.box_mesh(Vector3(FACE_W, vis, 0.035), StandardMaterial3D.new())
	(post.material_override as StandardMaterial3D).albedo_color = Color(0.9, 0.9, 0.88)
	post.position.y = vis * 0.5
	root.add_child(post)
	var tex := Closeup3D.canvas_tex(root, Vector2i(96, int(vis * 100.0 * 10.0)), func(c: Control) -> void: _draw_face(c, d))
	var q := QuadMesh.new()
	q.size = Vector2(FACE_W, vis)
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = q
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = tex
	fm.roughness = 1.0
	fm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	face.material_override = fm
	face.position = Vector3(0, vis * 0.5, 0.0178)
	root.add_child(face)
	# Сугробы вокруг: гребни и ямки в стороне, у самой рейки — ровно
	var snow := Palette.m(&"snow")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d) * 7 + Game.phase_index
	for k in 7:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.28, 0.7)
		var m := SphereMesh.new()
		m.radius = rng.randf_range(0.14, 0.3)
		m.height = m.radius * rng.randf_range(0.5, 0.9)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = snow
		mi.position = Vector3(sin(ang) * r, -m.height * 0.2, cos(ang) * r)
		root.add_child(mi)
	return root


## Лицо рейки: красно-белые полосы по 10 см, деления через 1 см, цифры через 10 (от уровня снега вверх).
static func _draw_face(c: Control, from_cm: float) -> void:
	var w := c.size.x
	var h := c.size.y
	var ppcm := h / (H_TOTAL - from_cm)
	var ink := Color(0.08, 0.08, 0.1)
	var pf := UiStyle.plate_font()
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.93, 0.93, 0.9))
	var y_of := func(cm: float) -> float: return h - (cm - from_cm) * ppcm
	for dec in range(int(floor(from_cm / 10.0)), int(H_TOTAL / 10.0)):
		if dec % 2 == 1:
			var y0: float = y_of.call(dec * 10.0 + 10.0)
			c.draw_rect(Rect2(w - 30, y0, 30, 10.0 * ppcm), Color(0.72, 0.1, 0.08))
	for cm in range(int(ceil(from_cm)), int(H_TOTAL) + 1):
		var y: float = y_of.call(cm)
		var len := 12.0
		var width := 1.6
		if cm % 10 == 0:
			len = 36.0
			width = 3.0
		elif cm % 5 == 0:
			len = 22.0
			width = 2.2
		c.draw_line(Vector2(0, y), Vector2(len, y), ink, width)
		if cm % 10 == 0:
			c.draw_string(pf, Vector2(8, y - 4), str(cm), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_truth = depth()
	ThermometerUI.title_plate(self, Loc.t(&"snow.title"))
	var stake := Yard.METEO + Yard.M_ROD
	var face_z := stake.z + 0.0178
	var start := randf_range(0.05, 0.35)
	var eye := Vector3(stake.x + 0.12, start, face_z + 0.42)
	_close = Closeup3D.new()
	Game.level.add_child(_close)
	_close.setup(eye, Vector3(stake.x + 0.12, start, stake.z), 36.0, Vector3.UP, 0.08 - start, (H_TOTAL - _truth) / 100.0 - 0.1 - start, 0.0)
	var vis := (H_TOTAL - _truth) / 100.0
	_frost = Closeup3D.Frost.new(Vector2(FACE_W + 0.01, vis), InstrumentView.frost_for_weather(Game.air_temp().x) * 0.8, Vector2i(10, 160))
	_frost.position = Vector3(stake.x, vis * 0.5, face_z + 0.004)
	Game.level.add_child(_frost)

	_book = KMBook.new()
	HeldPaper.notebook(self, _book)   # книжка КМ-1 — в правой руке
	_book.setup([{"label": Loc.t(&"snow.row"), "cells": [&"digit", &"digit", &"digit"], "unit": Loc.t(&"snow.cm")}])
	if Game.notebook.has(&"snow"):
		_book.set_value(0, float(Game.notebook[&"snow"]["v"]))
	ThermometerUI.add_buttons(self, Game.notebook.has(&"snow"), _write, func() -> void: closed.emit())
	_hint = ThermometerUI.hint_label(self)


func _exit_tree() -> void:
	if _close != null and is_instance_valid(_close):
		_close.queue_free()
	if _frost != null and is_instance_valid(_frost):
		_frost.queue_free()


func _process(delta: float) -> void:
	var dy := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var ry := -Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(ry) > 0.2:
		dy += ry
	if absf(dy) > 0.01:
		_close.scroll(dy * 0.3 * delta)
	if _wipe or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
		var lp: Variant = Closeup3D.hit_plane(_close.ray(get_global_transform_with_canvas() * _mouse), _frost)
		if lp != null and _frost.wipe(lp, delta):
			_wipe_t -= delta
			if _wipe_t <= 0.0:
				_wipe_t = 0.32
				Game.audio.play_2d(InstrumentView.WIPE_SFX, -20.0, 0.25)
	_hint.text = Loc.t(&"snow.hint") if _close.can_see() else Loc.t(&"thermo.hint_dark")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse = mb.position
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_close.scroll(CM_PER_NOTCH / 100.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_close.scroll(-CM_PER_NOTCH / 100.0)
			MOUSE_BUTTON_LEFT:
				_wipe = mb.pressed


func _write() -> void:
	if _done:
		return
	_done = true
	var v := _book.value(0)
	Game.write_reading(&"snow", v, _truth)
	Game.take_reading(&"snow")
	Game.audio.play_2d(PEN_SFX, -12.0)
	Game.hud.subtitle(Loc.t(&"snow.written", [int(v)]) + " " + ThermometerUI.tail(), 5.0)
	closed.emit()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if event.is_action_pressed(&"flashlight") and Game.player != null:
		Game.player.toggle_flashlight()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)
