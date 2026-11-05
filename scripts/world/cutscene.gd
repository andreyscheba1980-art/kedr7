class_name Cutscene
extends Node
## Катсцена на движке: своя камера по точкам, кинорамка (чёрные полосы), затемнения, субтитры, звук, тряска.
## Управление на время сцены отключено, мир живёт дальше. Шаги — словари:
##   {"cam": [pos, look]}                      — поставить камеру
##   {"move": [pos, look], "t": сек}           — плавный проезд от текущего положения
##   {"follow": Node3D, "off": Vector3, "t"}    — камера держит узел в кадре
##   {"fade": 0..1, "t": сек}                  — затемнение
##   {"say": ключ, "t": сек}                   — субтитр (Loc)
##   {"sfx": путь, "at": Vector3?, "vol": дБ}  — звук (3D, если задана точка)
##   {"shake": сила, "t": сек}                 — тряска камеры
##   {"call": Callable}                        — действие в мире
##   {"wait": сек}
## await Cutscene.play(steps) — ждать конца; камера и управление вернутся игроку.

static var active := false

var _cam: Camera3D
var _layer: CanvasLayer
var _top: ColorRect
var _bot: ColorRect
var _fade: ColorRect
var _shake := 0.0
var _shake_t := 0.0
var _base := Transform3D.IDENTITY


static func play(steps: Array) -> void:
	var c := Cutscene.new()
	Game.level.add_child(c)
	await c._run(steps)
	c.queue_free()


func _run(steps: Array) -> void:
	active = true
	var p := Game.player
	var mode_was := p.mode if p != null else 0
	if p != null:
		p.mode = Player.Mode.LOCKED
		p.velocity = Vector3.ZERO
	_layer = CanvasLayer.new()
	_layer.layer = 80
	add_child(_layer)
	_top = _bar(true)
	_bot = _bar(false)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.near = 0.05
	_cam.far = 120.0
	Game.level.add_child(_cam)
	if p != null and p.camera != null:
		_cam.global_transform = p.camera.global_transform
	_base = _cam.global_transform
	_cam.current = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_top, "offset_bottom", 22.0, 0.5)
	tw.tween_property(_bot, "offset_top", -22.0, 0.5)
	for st: Dictionary in steps:
		await _step(st)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_top, "offset_bottom", 0.0, 0.4)
	tw2.tween_property(_bot, "offset_top", 0.0, 0.4)
	await tw2.finished
	_cam.current = false
	if p != null and is_instance_valid(p) and p.camera != null:
		p.camera.current = true
		if p.mode == Player.Mode.LOCKED:
			p.mode = mode_was if mode_was != Player.Mode.LOCKED else Player.Mode.WALK
	_cam.queue_free()
	active = false


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		r.offset_bottom = 0.0
	else:
		r.offset_top = 0.0
	return r


func _step(st: Dictionary) -> void:
	if st.has("cam"):
		var a: Array = st["cam"]
		_place(a[0], a[1])
	if st.has("move"):
		var a: Array = st["move"]
		await _move(a[0], a[1], float(st.get("t", 2.0)))
		return
	if st.has("follow"):
		var n: Node3D = st["follow"]
		var off: Vector3 = st.get("off", Vector3(0, 1.5, 3.0))
		var t := 0.0
		var dur := float(st.get("t", 2.0))
		while t < dur and is_instance_valid(n):
			_place(n.global_position + off, n.global_position + Vector3(0, 1.0, 0))
			await get_tree().process_frame
			t += get_process_delta_time()
		return
	if st.has("fade"):
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", float(st["fade"]), float(st.get("t", 0.6)))
		if not st.get("async", false):
			await tw.finished
		return
	if st.has("say"):
		Game.hud.subtitle(Loc.t(StringName(st["say"])), float(st.get("t", 4.0)))
		if st.get("hold", false):
			await get_tree().create_timer(float(st.get("t", 4.0)), false).timeout
		return
	if st.has("sfx"):
		if st.has("at"):
			Game.audio.play_3d(String(st["sfx"]), st["at"], float(st.get("vol", 0.0)), float(st.get("unit", 10.0)))
		else:
			Game.audio.play_2d(String(st["sfx"]), float(st.get("vol", 0.0)))
		return
	if st.has("shake"):
		_shake = float(st["shake"]) * Settings.camera_shake
		_shake_t = float(st.get("t", 0.6))
		return
	if st.has("call"):
		var cb: Callable = st["call"]
		var r: Variant = cb.call()
		if r is Signal:
			await r
		return
	if st.has("wait"):
		await get_tree().create_timer(float(st["wait"]), false).timeout


func _place(pos: Vector3, look: Vector3) -> void:
	_cam.global_position = pos
	if not pos.is_equal_approx(look):
		_cam.look_at(look, Vector3.UP)
	_base = _cam.global_transform


func _move(pos: Vector3, look: Vector3, dur: float) -> void:
	var p0 := _base.origin
	var l0 := p0 - _base.basis.z * 4.0
	var t := 0.0
	while t < dur:
		var k := smoothstep(0.0, 1.0, t / dur)
		_place(p0.lerp(pos, k), l0.lerp(look, k))
		await get_tree().process_frame
		t += get_process_delta_time()
	_place(pos, look)


func _process(delta: float) -> void:
	if _cam == null or _shake_t <= 0.0:
		return
	_shake_t -= delta
	_cam.global_transform = _base
	_cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.05
	if _shake_t <= 0.0:
		_cam.global_transform = _base
