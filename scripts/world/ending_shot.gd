class_name EndingShot
extends Node
## Кадр на движке перед текстом концовки (15–25 с): камера по точкам в уже готовом мире.
##   answer  — «Голос станции»: дом гаснет окно за окном, в конце — пустая миска Найды;
##   burn    — «Тишина в эфире»: станция в огне, гаснет огонь мачты;
##   leave   — «Зимник»: уходишь по дороге, сзади мигает мачта; здоровая Найда идёт рядом;
##   source  — «Источник»: огни АМС и точек гаснут по всей карте; Найда лает на ящик;
##   silence — «Плата»: маятник встаёт, стрелка замирает на 05:59;
##   echo    — «Отзвук»: камера наезжает на рацию, шкала светится сама.

var _cam: Camera3D
var _fade: ColorRect
var _layer: CanvasLayer
var _extra: Array[Node] = []


func run(id: StringName) -> void:
	if Game.level == null:
		return
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_cam.far = 500.0
	Game.level.add_child(_cam)
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	var hud_was := Game.hud != null and Game.hud.visible
	if Game.hud != null:
		Game.hud.visible = false
	if Game.player != null:
		Game.player.flashlight.visible = false
	_cam.current = true
	match id:
		&"answer":
			await _answer()
		&"burn":
			await _burn()
		&"leave":
			await _leave()
		&"source":
			await _source()
		&"silence":
			await _silence()
		&"echo":
			await _echo()
		&"taiga":
			await _taiga()
	await _coda(id)
	await _fade_to(1.0, 1.2)
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_cam.current = false
	if Game.player != null:
		Game.player.camera.current = true
	_cam.queue_free()
	if Game.hud != null:
		Game.hud.visible = hud_was


# --- Помощники -----------------------------------------------------------------------

func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, dur)
	await tw.finished


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


## Проезд: позиция и взгляд плавно из A в B; on_tick(k) — для синхронных эффектов.
func _dolly(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, dur: float, on_tick := Callable()) -> void:
	var t := 0.0
	while t < dur:
		var k := smoothstep(0.0, 1.0, t / dur)
		_cam.global_position = p0.lerp(p1, k)
		var look := l0.lerp(l1, k)
		if not _cam.global_position.is_equal_approx(look):
			_cam.look_at(look, Vector3.UP)
		if on_tick.is_valid():
			on_tick.call(t / dur)
		await get_tree().process_frame
		t += get_process_delta_time()


func _ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, Terrain.height(x, z) + up, z)


## Лунная подсветка у камеры: ночью 7 иначе в кадре одна чернота.
func _moon(energy := 0.7, rng := 32.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.64, 0.9)
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 0.6
	l.shadow_enabled = false
	_cam.add_child(l)
	l.position = Vector3(0, 2.0, -6.0)


## Светящаяся точка, видная сквозь туман с любого расстояния (огни АМС в «Источнике»).
func _beacon(pos: Vector3, col: Color, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	m.albedo_color = col
	m.no_depth_test = true
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.level.add_child(mi)
	mi.global_position = pos
	_extra.append(mi)
	return mi


func _caption(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 34)
	l.add_theme_color_override(&"font_color", Color(0.92, 0.88, 0.8))
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 90.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_layer.add_child(l)


func _mast_light() -> OmniLight3D:
	if Game.yard == null:
		return null
	return Game.yard.get("_mast_light") as OmniLight3D


func _dog_ok() -> bool:
	return Dog.is_home() and Dog.health() >= 60.0


func _light(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	Game.level.add_child(l)
	l.global_position = pos
	_extra.append(l)
	return l


## Кода (1.55): что стало с теми, с кем ты говорил по рации. Михалыч приехал утром и не стучал;
## борт прошёл над перевалом; двойник с чужой собакой. Только если это было в прохождении.
func _coda(id: StringName) -> void:
	var trust := RadioTalks.flag("talk_trust")
	var heli := RadioTalks.flag("heli_asked") > 0
	var dbl := RadioTalks.flag("double_exposed") > 0
	if trust < 2 and not heli and not dbl:
		return
	await _fade_to(1.0, 1.0)
	for c in _layer.get_children():
		if c is Label:
			c.queue_free()
	var porch := Vector3(15.8, 0.0, 3.1)
	var cam0 := _ground(27.0, 13.0, 2.0)
	var cam1 := _ground(23.5, 10.5, 1.7)
	_moon(0.9, 40.0)
	var lines: PackedStringArray = []
	if trust >= 2 and id != &"leave":
		var m := Creatures.make_human(&"driver")
		if m != null:
			Game.level.add_child(m)
			_extra.append(m)
			m.global_position = _ground(17.4, 3.4)
			m.look_at(Vector3(14.5, m.global_position.y, 3.1), Vector3.UP)
		lines.append(Loc.t(&"coda.mikh"))
	if heli:
		var b := _beacon(_ground(-60.0, -80.0, 60.0), Color(1.0, 0.2, 0.15, 0.9), 1.2)
		_extra.append(b)
		Game.audio.play_2d("res://assets/audio/engine_loop.ogg", -14.0, 9.0)
		lines.append(Loc.t(&"coda.heli"))
	if dbl:
		lines.append(Loc.t(&"coda.double"))
	_cam.global_position = cam0
	_cam.look_at(porch + Vector3(0, 1.2, 0), Vector3.UP)
	await _fade_to(0.0, 1.4)
	var i := 0
	var beacon: MeshInstance3D = _extra[-1] as MeshInstance3D if heli and _extra[-1] is MeshInstance3D else null
	for ln in lines:
		for c in _layer.get_children():
			if c is Label:
				c.queue_free()
		_caption(ln)
		var t := 0.0
		while t < 5.0:
			var k := (float(i) * 5.0 + t) / (5.0 * lines.size())
			_cam.global_position = cam0.lerp(cam1, smoothstep(0.0, 1.0, k))
			_cam.look_at(porch + Vector3(0, 1.2, 0), Vector3.UP)
			if beacon != null and is_instance_valid(beacon):
				beacon.global_position += Vector3(9.0, 0.0, 6.0) * get_process_delta_time()
				beacon.visible = fmod(t, 1.0) < 0.5
			await get_tree().process_frame
			t += get_process_delta_time()
		i += 1


# --- Концовки ------------------------------------------------------------------------

func _answer() -> void:
	var p0 := Vector3(26.0, 1.7, 17.0)
	var p1 := Vector3(19.0, 1.6, 11.0)
	var look := Vector3(6.0, 1.6, 3.0)
	# Свет из окон снаружи: окна гаснут по одному, последней — лампа над крыльцом
	var glows: Array[OmniLight3D] = []
	for gp: Vector3 in [Vector3(0.5, 1.5, 7.3), Vector3(4.5, 1.5, 7.3), Vector3(9.0, 1.5, 7.3), Vector3(13.6, 2.6, 3.2)]:
		glows.append(_light(gp, Color(1.0, 0.75, 0.45), 1.6, 4.5))
	_moon(0.35, 40.0)
	var off := [0]
	_fade_to(0.0, 1.5)
	await _dolly(p0, p1, look, look, 12.0, func(k: float) -> void:
		var n := int(clampf((k - 0.3) / 0.12, 0.0, float(glows.size())))
		while off[0] < n:
			glows[off[0]].light_energy = 0.0
			Game.audio.play_2d("res://assets/audio/clank.ogg", -16.0)
			off[0] += 1
			if off[0] == glows.size():
				Game.set_power(false)
	)
	await _wait(1.5)
	# Миска у печки: собаку кормить больше некому
	if Dog.is_home():
		await _fade_to(1.0, 0.8)
		var bowl := Dog.BOWL_POS
		_cam.global_position = Vector3(bowl.x + 0.7, 0.9, bowl.z + 1.1)
		_cam.look_at(bowl + Vector3(0, 0.05, 0), Vector3.UP)
		_light(bowl + Vector3(0.4, 0.8, 0.6), Color(0.6, 0.66, 0.9), 2.4, 3.0)
		await _fade_to(0.0, 1.0)
		await _wait(3.5)


func _burn() -> void:
	var fires: Array[OmniLight3D] = []
	for p: Vector3 in [Vector3(1.0, 1.4, 3.0), Vector3(6.0, 1.4, 2.0), Vector3(9.5, 1.4, 0.0), Vector3(4.0, 3.4, 2.5)]:
		fires.append(_light(p, Color(1.0, 0.45, 0.12), 3.0, 9.0))
	Game.audio.play_2d("res://assets/audio/fire_loop.ogg", -2.0)
	_fade_to(0.0, 1.5)
	var look := Vector3(5.0, 2.0, 2.0)
	await _dolly(Vector3(27.0, 1.7, 15.0), Vector3(22.0, 2.4, 12.0), look, look, 9.0, func(_k: float) -> void:
		for f in fires:
			f.light_energy = 2.4 + randf() * 2.4
	)
	# Мачта: огонь мигает и гаснет — эфир замолкает
	var ml := _mast_light()
	var top := Yard.MAST + Vector3(0, 16.8, 0)
	await _dolly(Vector3(30.0, 1.7, -20.0), Vector3(29.0, 1.7, -24.0), top, top, 6.0, func(k: float) -> void:
		for f in fires:
			f.light_energy = 2.0 + randf() * 2.0
		if ml != null:
			ml.light_energy = 0.0 if k > 0.6 else (1.3 if fmod(k * 10.0, 1.0) < 0.6 else 0.2)
	)
	await _wait(1.5)


func _leave() -> void:
	var ml := _mast_light()
	var top := Yard.MAST + Vector3(0, 16.8, 0)
	var a := _ground(-63.0, -89.5, 1.5)   # по колее зимника (Terrain.ROADS.zimnik)
	var b := _ground(-84.0, -112.0, 1.5)
	var horizon := Yard.MAST + Vector3(0, 4.0, 0)   # взгляд почти горизонтально: в кадре и дорога, и огонь мачты
	var dog_node: Node3D = null
	var dog_anim: AnimationPlayer = null
	if _dog_ok():
		var mm := Dog.make_model()
		if not mm.is_empty():
			dog_node = mm[0]
			dog_anim = mm[1]
			Game.level.add_child(dog_node)
			_extra.append(dog_node)
			if dog_anim != null and dog_anim.has_animation(&"walk"):
				dog_anim.play(&"walk")
	var dir := (b - a)
	dir.y = 0.0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	_moon(0.9, 30.0)
	var mb := _beacon(top, Color(1.0, 0.15, 0.08, 0.9), 2.2)
	_fade_to(0.0, 2.0)
	await _dolly(a, b, horizon, horizon, 18.0, func(k: float) -> void:
		var on := fmod(k * 14.0, 1.0) < 0.5
		mb.visible = on
		if ml != null:
			ml.light_energy = 1.4 if on else 0.15
		if dog_node != null:
			# Найда трусит рядом, чуть впереди камеры по взгляду (то есть позади по ходу)
			var c := _cam.global_position
			var dp := c - dir * 3.4 + side * 0.8
			dp.y = Terrain.height(dp.x, dp.z)
			dog_node.global_position = dp
			dog_node.rotation.y = atan2(dir.x, dir.z)
	)
	await _wait(1.0)


func _source() -> void:
	if _dog_ok():
		Game.audio.play_2d(Voice.sfx_or(&"dog_bark", "res://assets/audio/whisper.ogg"), -2.0)
	var spots: Array[Vector3] = []
	for pad: StringName in [&"ams1", &"ams2", &"ams3", &"ams4", &"tower", &"camp", &"drill"]:
		spots.append(Terrain.pad_pos(pad) + Vector3(0, 6.0, 0))
	spots.append(Yard.REPEATER + Vector3(0, 12.0, 0))
	spots.append(Yard.MAST + Vector3(0, 16.8, 0))
	var beacons: Array[MeshInstance3D] = []
	for s in spots:
		beacons.append(_beacon(s, Color(1.0, 0.16, 0.08, 0.95), 7.0))
	var ml := _mast_light()
	_moon(1.2, 120.0)
	var p0 := Vector3(20.0, 70.0, 150.0)
	var p1 := Vector3(20.0, 85.0, 110.0)
	var look := Vector3(20.0, 0.0, -60.0)
	_fade_to(0.0, 1.5)
	var off := [0]
	await _dolly(p0, p1, look, look, 14.0, func(k: float) -> void:
		var n := int(k * float(beacons.size() + 2))
		while off[0] < mini(n, beacons.size()):
			beacons[off[0]].visible = false
			Game.audio.play_2d("res://assets/audio/clank.ogg", -14.0)
			off[0] += 1
		if ml != null and off[0] >= beacons.size():
			ml.light_energy = 0.0
	)
	await _wait(2.0)


## «Тайга»: идолы в лунном свете; камера отходит — от святилища в ельник уходят две цепочки следов,
## человечьи и собачьи, а навстречу им из темноты — третья, босая. Огонь мачты за спиной гаснет.
func _taiga() -> void:
	var c: Vector3 = DayPOIs.POI_TARGETS[&"poi_shrine"]["pos"]
	c.y = Terrain.height(c.x, c.z)
	_moon(1.8, 60.0)
	# Лампадка-плошка у ног идолов: тёплое пятно в синей ночи
	var lamp := Geo.omni(Game.level, c + Vector3(0.6, 0.5, 0.9), 7.0, 2.2, Color(1.0, 0.62, 0.3))
	_extra.append(lamp)
	var moon_hi := Geo.omni(Game.level, c + Vector3(3.0, 7.0, 4.0), 22.0, 1.6, Color(0.55, 0.64, 0.9))
	_extra.append(moon_hi)
	var route := PackedVector3Array()
	for i in 12:
		var q := c + Vector3(-1.5 - i * 2.2, 0, -0.6 - i * 1.4 + sin(i * 0.8) * 0.6)
		q.y = Terrain.height(q.x, q.z) + 0.03
		route.append(q)
	var tracks := Node3D.new()
	Game.level.add_child(tracks)
	_extra.append(tracks)
	Footprints.trail(tracks, &"snow", route, route[0].y, 0.55)
	var dog_route := PackedVector3Array()
	for q in route:
		dog_route.append(q + Vector3(0.0, 0, 0.9))
	Footprints.trail(tracks, &"paw", dog_route, route[0].y, 0.34, 0.04)
	_fade_to(0.0, 2.0)
	var dir := (Vector3(6.0, 0.0, 3.0) - c)   # со стороны станции — там тропа, а не ельник
	dir.y = 0.0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	await _dolly(c + dir * 2.2 + side * 0.5 + Vector3(0, 1.4, 0), c + dir * 3.0 + side * 0.7 + Vector3(0, 1.9, 0), c + Vector3(0, 1.0, 0), c + Vector3(0, 1.0, 0), 7.0)
	await _dolly(c + dir * 3.0 + side * 0.7 + Vector3(0, 1.9, 0), c + dir * 3.4 + Vector3(0, 5.5, 0), c + Vector3(0, 1.0, 0), route[route.size() - 1] + Vector3(0, 0.5, 0), 9.0)
	_caption(Loc.t(&"end.taiga.cap"))
	await _wait(4.0)


func _silence() -> void:
	var st: Node = Game.level
	var clock := Vector3(1.2, 1.85, 0.12)
	_light(clock + Vector3(0.0, 0.3, 1.2), Color(0.95, 0.85, 0.7), 0.8, 3.5)
	_fade_to(0.0, 1.5)
	var p0 := Vector3(1.2, 1.7, 2.4)
	var p1 := Vector3(1.2, 1.8, 1.1)
	var stopped := [false]
	await _dolly(p0, p1, clock, clock, 9.0, func(k: float) -> void:
		if k > 0.6 and not stopped[0]:
			stopped[0] = true
			if st != null:
				st.set("_clock_pendulum", null)
				var pl := st.get("_clock_player") as AudioStreamPlayer3D
				if pl != null:
					pl.stop()
			_caption("05:59")
	)
	await _wait(3.0)


func _echo() -> void:
	var radio := Vector3(8.6, 0.95, -1.2)
	_light(radio + Vector3(0, 0.4, 0.6), Color(1.0, 0.72, 0.35), 1.0, 2.5)
	_fade_to(0.0, 1.5)
	await _dolly(Vector3(7.2, 1.5, 1.6), Vector3(8.3, 1.15, -0.2), radio, radio, 12.0)
	await _wait(1.0)
