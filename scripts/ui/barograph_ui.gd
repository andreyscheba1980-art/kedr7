class_name BarographUI
extends Control
## Советский суточный барограф М-22 («Дыхание станции»): лента на барабане и книжка КМ-1.
## Перо пишет давление по часам смены. Дежурный сам читает, где перо сейчас, и насколько
## давление изменилось за три часа (барическая тенденция) — и вписывает оба числа.
## Крупный план в 3D: модель прибора прячется, на её месте — барабан с живой лентой под стеклянным колпаком,
## рычаг с пером касается ленты там, где «сейчас». Лента рисуется во вьюпорт и натянута на дугу барабана.
## Мышь над лентой кладёт линейку — по ней удобно вести к шкале. Пружину барабана заводят ключом
## (раз за ночь): кончится завод — перо встанет, и прочитать «сейчас» будет нельзя.
## На ленте видно и то, чего в воздухе не было: зубец baro_tooth, удар сигнала 03:10.

signal closed

const CLANK_SFX := "res://assets/audio/clank.ogg"
const SCRATCH_SFX := "res://assets/audio/clock_tick.ogg"
const PEN_SFX := "res://assets/audio/clank.ogg"
const HOURS_BACK := 12.0
const HOURS_AHEAD := 2.0
const MM_HALF := 13.0                   ## от центра ленты вверх/вниз, мм рт. ст.
const SIGNAL_H := 430.0 / 60.0          ## 03:10 ночи — в часах смены
const DRUM_R := 0.06
const DRUM_H := 0.11
const ARC := 2.0                        ## сколько барабана (рад) занимает видимая лента
const CHART_PX := Vector2i(1100, 720)

var _chart: Control
var _book: KMBook
var _hint: Label
var _status: Label
var _scratch_player: AudioStreamPlayer
var _listening := 0.0
var _now_h := 0.0
var _hour0 := 20.0
var _center_p := 746.0
var _truth := 746.0
var _truth_tend := 0.0
var _dead_band := 1.4                   ## мёртвый ход (застой стрелки из-за трения пера о ленту, мм рт. ст.)
var _tapped := false
var _tap_step_time := -1.0
var _ruler_y := -1.0
var _done := false
var _cu: Closeup3D
var _rig: Node3D
var _vp: SubViewport
var _drum_c := Vector3.ZERO             ## центр барабана в осях рига
var _arm: Node3D
var _arm_pivot := Vector3.ZERO
var _hidden: Node3D
var _tape_mat: StandardMaterial3D
var _light := 1.0
var _mouse := Vector2(-1, -1)
var _tape_tex: ImageTexture            ## лента: вьюпорт перепекается в обычную текстуру (вьюпорт напрямую на дуге — белый)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_now_h = Game.shift_minutes / 60.0
	_hour0 = float(Game.base_hour)
	_truth = Game.pressure_at(_now_h)
	_truth_tend = _truth - Game.pressure_at(_now_h - 3.0)
	# Лента стоит так, чтобы и «сейчас», и «три часа назад» были на ней
	_center_p = roundf(_truth - _truth_tend * 0.5 + randf_range(-2.0, 2.0))
	if Game.baro_tapped:
		_dead_band = 0.0
		_tapped = true

	ThermometerUI.title_plate(self, Loc.t(&"barograph.title"))
	_build_rig()

	_status = UiStyle.hint()
	_status.add_theme_color_override("font_color", Color(0.92, 0.62, 0.45, 0.9))
	UiKit.place(self, _status, 0.5, 0.5, 0.5, 0.5, -500, 202, 100, 226)
	var wind_btn := UiStyle.text_button(Loc.t(&"barograph.wind_key"), _wind_mechanism)
	UiKit.place(self, wind_btn, 0.5, 0.5, 0.5, 0.5, -500, 230, -290, 266)
	var tap_btn := UiStyle.text_button(Loc.t(&"barograph.tap_case"), _tap_case)
	UiKit.place(self, tap_btn, 0.5, 0.5, 0.5, 0.5, -280, 230, -70, 266)
	var listen_btn := UiStyle.text_button(Loc.t(&"barograph.listen_pen"), _listen_pen)
	UiKit.place(self, listen_btn, 0.5, 0.5, 0.5, 0.5, -60, 230, 110, 266)

	_book = KMBook.new()
	HeldPaper.notebook(self, _book)   # книжка КМ-1 — в правой руке
	_book.setup([
		{"label": Loc.t(&"barograph.row_p"), "cells": [&"digit", &"digit", &"digit", &"digit"], "dot": 3, "unit": Loc.t(&"barograph.mm")},
		{"label": Loc.t(&"barograph.row_tend"), "cells": [&"sign", &"digit", &"digit"], "dot": 2, "unit": Loc.t(&"barograph.mm")},
	])
	if Game.notebook.has(&"baro"):
		_book.set_value(0, float(Game.notebook[&"baro"]["v"]))
		_book.set_value(1, float(Game.notebook[&"baro_tend"]["v"]))
	ThermometerUI.add_buttons(self, Game.notebook.has(&"baro"), _write, _close)
	_hint = ThermometerUI.hint_label(self)
	_hint.text = Loc.t(&"barograph.hint")

	_scratch_player = AudioStreamPlayer.new()
	_scratch_player.stream = AudioDirector.cached_stream(SCRATCH_SFX)
	_scratch_player.volume_db = -12.0
	_scratch_player.pitch_scale = 1.3
	add_child(_scratch_player)
	_update_status()


func _process(delta: float) -> void:
	if _listening > 0.0:
		_listening -= delta
		if _listening <= 0.0:
			_scratch_player.stop()
			_update_status()
	var dx := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(rx) > 0.2:
		dx += rx
	if absf(dx) > 0.01:
		_cu.scroll(dx * 0.08 * delta)
	_ruler_y = _ruler_at(_mouse)
	_place_arm()

	# Свет на ленте считаем сами: освещённая лента пересвечивалась до белого (как шкала термометра)
	var see := _cu.can_see() or _room_lit()
	_light = lerpf(_light, (0.95 if _room_lit() or Game.is_daylight() else 0.8) if see else 0.03, clampf(delta * 8.0, 0.0, 1.0))
	_tape_mat.albedo_color = Color(_light, _light, _light * 0.96)
	_hint.text = Loc.t(&"barograph.hint") if see else Loc.t(&"thermo.hint_dark")
	_chart.queue_redraw()


func _exit_tree() -> void:
	if _hidden != null and is_instance_valid(_hidden):
		_hidden.visible = true
	for n: Node in [_cu, _rig]:
		if n != null and is_instance_valid(n):
			n.queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = (event as InputEventMouse).position
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cu.scroll(0.012)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cu.scroll(-0.012)


# --- Прибор в 3D ---------------------------------------------------------------------------

## Ближайшая к игроку модель барографа (дом — рубка, корпус — стол у перегородки).
func _find_model() -> Node3D:
	var best: Node3D = null
	var bd := INF
	var at := Game.player.global_position if Game.player != null else Vector3.ZERO
	for n in get_tree().get_nodes_in_group(&"barograph_model"):
		var m := n as Node3D
		var d := at.distance_to(m.get_meta(&"rig_base", m.global_position))
		if d < bd:
			bd = d
			best = m
	return best


func _room_lit() -> bool:
	if _rig == null:
		return false
	if Game.level != null and Game.level.is_pos_inside_house(_rig.global_position):
		return Game.level.lights_lit()
	return MeteoCorpus.instance != null and MeteoCorpus.instance.powered


func _build_rig() -> void:
	var base := Vector3(8.55, 0.75, -1.45)
	var yaw := 0.0
	_hidden = _find_model()
	if _hidden != null:
		base = _hidden.get_meta(&"rig_base", base)
		yaw = _hidden.get_meta(&"rig_yaw", 0.0)
		_hidden.visible = false
	_rig = Node3D.new()
	Game.level.add_child(_rig)
	_rig.global_position = base
	_rig.rotation.y = yaw
	var wood := _m(Color(0.27, 0.16, 0.09), 0.55)
	var brass := _m(Color(0.66, 0.53, 0.27), 0.35)
	var steel := _m(Color(0.42, 0.43, 0.44), 0.4)
	# Основание, плита
	_box(Vector3(0.34, 0.05, 0.24), Vector3(0, 0.025, 0), wood)
	_box(Vector3(0.32, 0.006, 0.22), Vector3(0, 0.053, 0), steel)
	# Барабан: внутри — светлый цилиндр, спереди — лента; латунные фланцы, ось с ключом завода
	_drum_c = Vector3(-0.055, 0.058 + DRUM_H * 0.5 + 0.004, 0.01)
	_cyl(DRUM_R - 0.002, DRUM_H, _drum_c, _m(Color(0.86, 0.84, 0.77), 0.9))
	_cyl(DRUM_R + 0.004, 0.006, _drum_c + Vector3(0, DRUM_H * 0.5 + 0.003, 0), brass)
	_cyl(DRUM_R + 0.004, 0.006, _drum_c - Vector3(0, DRUM_H * 0.5 + 0.003, 0), brass)
	_cyl(0.006, 0.03, _drum_c + Vector3(0, DRUM_H * 0.5 + 0.02, 0), steel)
	_box(Vector3(0.03, 0.006, 0.006), _drum_c + Vector3(0, DRUM_H * 0.5 + 0.035, 0), steel)
	# Лента — вьюпорт, где рисует _draw_chart
	_vp = SubViewport.new()
	_vp.size = CHART_PX
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rig.add_child(_vp)
	_chart = Control.new()
	_chart.size = Vector2(CHART_PX)
	_chart.draw.connect(_draw_chart)
	_vp.add_child(_chart)
	var arc := MeshInstance3D.new()
	arc.mesh = _arc_mesh()
	var cm := StandardMaterial3D.new()
	_tape_tex = ImageTexture.create_from_image(Image.create(CHART_PX.x, CHART_PX.y, false, Image.FORMAT_RGBA8))
	_bake_loop()
	cm.albedo_texture = _tape_tex
	cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tape_mat = cm
	arc.material_override = cm
	arc.position = _drum_c
	_rig.add_child(arc)
	# Чувствительный элемент: столбик анероидных коробок и тяга к рычагу
	for j in 8:
		_cyl(0.042, 0.009, Vector3(0.085, 0.064 + j * 0.0125, -0.03), brass)
	_box(Vector3(0.004, 0.06, 0.004), Vector3(0.085, 0.19, -0.03), steel)
	# Рычаг пера: ось на стойке справа, перо — к ленте
	_box(Vector3(0.012, 0.16, 0.012), Vector3(0.12, 0.13, 0.06), steel)
	_arm_pivot = Vector3(0.12, 0.13, 0.06)
	_arm = Node3D.new()
	_rig.add_child(_arm)
	var rod := Geo.box_mesh(Vector3(0.0025, 0.0025, 1.0), _m(Color(0.12, 0.12, 0.13), 0.4))
	rod.name = "Rod"
	_arm.add_child(rod)
	var nib := Geo.box_mesh(Vector3(0.006, 0.01, 0.006), _m(Color(0.32, 0.1, 0.45), 0.3))
	nib.name = "Nib"
	_arm.add_child(nib)
	# Колпак: стекло в латунной рамке
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.82, 0.9, 0.95, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_box(Vector3(0.33, 0.2, 0.23), Vector3(0, 0.156, 0), glass)
	for e: Array in [[Vector3(0.33, 0.006, 0.006), Vector3(0, 0.256, 0.115)], [Vector3(0.33, 0.006, 0.006), Vector3(0, 0.256, -0.115)],
			[Vector3(0.006, 0.006, 0.23), Vector3(0.165, 0.256, 0)], [Vector3(0.006, 0.006, 0.23), Vector3(-0.165, 0.256, 0)],
			[Vector3(0.006, 0.2, 0.006), Vector3(0.165, 0.156, 0.115)], [Vector3(0.006, 0.2, 0.006), Vector3(-0.165, 0.156, 0.115)]]:
		_box(e[0], e[1], brass)
	# Камера: лента — левее центра (справа книжка в руке); вдоль барабана — колёсиком / A D
	var fwd := _rig.global_basis.z
	var right := _rig.global_basis.x
	var target := _rig.to_global(_drum_c + Vector3(0, 0, DRUM_R))
	var eye := target + fwd * 0.27 + right * 0.055 + Vector3(0, 0.01, 0)
	_cu = Closeup3D.new()
	Game.level.add_child(_cu)
	_cu.setup(eye, eye - fwd, 30.0, right, -0.04, 0.04, 0.0)


## Лента перепекается ~8 раз в секунду — картинку вьюпорта можно читать только после отрисовки кадра.
func _bake_loop() -> void:
	while is_inside_tree():
		await RenderingServer.frame_post_draw
		if not is_inside_tree() or _vp == null:
			return
		if Engine.get_process_frames() % 8 != 0:
			continue
		var img := _vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			_tape_tex.set_image(img)


func _m(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := Geo.box_mesh(size, mat)
	mi.position = pos
	_rig.add_child(mi)


func _cyl(r: float, h: float, pos: Vector3, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 32
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	_rig.add_child(mi)


## Дуга ленты: ARC радиан барабана лицом на +Z; u — по времени (слева направо), v — сверху вниз.
func _arc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	var r := DRUM_R + 0.0012
	for i in n:
		var a0 := -ARC * 0.5 + ARC * i / n
		var a1 := -ARC * 0.5 + ARC * (i + 1) / n
		var p00 := Vector3(sin(a0) * r, -DRUM_H * 0.5, cos(a0) * r)
		var p01 := Vector3(sin(a0) * r, DRUM_H * 0.5, cos(a0) * r)
		var p10 := Vector3(sin(a1) * r, -DRUM_H * 0.5, cos(a1) * r)
		var p11 := Vector3(sin(a1) * r, DRUM_H * 0.5, cos(a1) * r)
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		for v: Array in [[p00, u0, 1.0], [p01, u0, 0.0], [p11, u1, 0.0], [p00, u0, 1.0], [p11, u1, 0.0], [p10, u1, 1.0]]:
			var pp: Vector3 = v[0]
			st.set_normal(Vector3(pp.x, 0, pp.z).normalized())
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(pp)
	return st.commit()


## Точка ленты (пиксели вьюпорта) → точка в осях рига.
func _chart_to_local(px: Vector2) -> Vector3:
	var a := (px.x / CHART_PX.x - 0.5) * ARC
	var y := (0.5 - px.y / CHART_PX.y) * DRUM_H
	return _drum_c + Vector3(sin(a) * (DRUM_R + 0.002), y, cos(a) * (DRUM_R + 0.002))


## Мышь → луч → цилиндр барабана → строка ленты (пиксели) или −1.
func _ruler_at(screen: Vector2) -> float:
	if screen.x < 0.0 or _cu == null:
		return -1.0
	var r: Array = _cu.ray(get_global_transform_with_canvas() * screen)
	var inv := _rig.global_transform.affine_inverse()
	var o: Vector3 = inv * (r[0] as Vector3) - _drum_c
	var d: Vector3 = inv.basis * (r[1] as Vector3)
	var a := d.x * d.x + d.z * d.z
	var b := 2.0 * (o.x * d.x + o.z * d.z)
	var c := o.x * o.x + o.z * o.z - DRUM_R * DRUM_R
	var disc := b * b - 4.0 * a * c
	if a < 0.000001 or disc < 0.0:
		return -1.0
	var hit := o + d * ((-b - sqrt(disc)) / (2.0 * a))
	if absf(hit.y) > DRUM_H * 0.5 or absf(atan2(hit.x, hit.z)) > ARC * 0.5:
		return -1.0
	return (0.5 - hit.y / DRUM_H) * CHART_PX.y


## Рычаг: от оси на стойке — к точке пера на ленте.
func _place_arm() -> void:
	var end_h := _now_h if Game.barograph_live() else _now_h - 1.0
	var tip := _chart_to_local(Vector2(_x(end_h), clampf(_y(_pen(end_h)), 10.0, CHART_PX.y - 32.0)))
	if Game.barograph_live():
		tip.y += sin(Time.get_ticks_msec() * 0.02) * 0.00015   # перо чуть дрожит
	var pivot := _arm_pivot + Vector3(0, tip.y - _arm_pivot.y, 0) * 0.15
	var d := tip - pivot
	_arm.position = pivot + d * 0.5
	_arm.basis = Basis.looking_at(d.normalized(), Vector3.UP)
	(_arm.get_node(^"Rod") as Node3D).scale = Vector3(1, 1, d.length())
	(_arm.get_node(^"Nib") as Node3D).position = Vector3(0, 0, -d.length() * 0.5)


func _update_status() -> void:
	if Game.night == 7 and Game.final_call:
		var is_mimic: bool = bool(SaveGame.flags.get("night7_crawler_is_mimic", true))
		_status.text = Loc.t(&"barograph.status_n7_mimic" if is_mimic else &"barograph.status_n7_real")
		return
	if _listening > 0.0:
		_status.text = Loc.t(&"barograph.listening_text")
	elif not Game.barograph_live():
		_status.text = Loc.t(&"barograph.stopped")
	elif not _tapped:
		_status.text = Loc.t(&"barograph.stuck_friction")
	elif Game.anomalies != null and Game.anomalies.is_active(&"baro_tooth"):
		_status.text = Loc.t(&"barograph.tooth")
	else:
		_status.text = Loc.t(&"barograph.wound_status", [int(Game.barograph_wound)])


func _tap_case() -> void:
	if _tapped:
		AudioDirector.play_raw(CLANK_SFX, -4.0, 1.9)
		Game.hud.subtitle(Loc.t(&"barograph.tap_already"), 2.0)
		return
	_tapped = true
	_dead_band = 0.0
	_tap_step_time = _now_h
	Game.baro_tapped = true
	AudioDirector.play_raw(CLANK_SFX, -2.0, 1.8)
	get_tree().create_timer(0.08, false).timeout.connect(func() -> void:
		AudioDirector.play_raw(CLANK_SFX, -4.0, 2.1)
	)
	Game.vibrate(0.25, 0.15, 0.15)
	if Game.player != null and Game.player.camera != null:
		Game.player.shake(0.015, 0.2)
	if Game.night == 7 and Game.final_call:
		SaveGame.flags["night7_barograph_checked"] = true
		var is_mimic: bool = bool(SaveGame.flags.get("night7_crawler_is_mimic", true))
		if is_mimic:
			_truth = 690.0
			_center_p = 695.0
			Game.hud.subtitle(Loc.t(&"barograph.n7_mimic"), 6.5)
		else:
			_truth = 718.0
			_center_p = 718.0
			Game.hud.subtitle(Loc.t(&"barograph.n7_real"), 6.5)
	else:
		Game.hud.subtitle(Loc.t(&"barograph.tap_done"), 3.5)
	_update_status()
	_chart.queue_redraw()


func _wind_mechanism() -> void:
	Game.barograph_wound = 100.0
	for i in 3:
		get_tree().create_timer(i * 0.12, false).timeout.connect(func() -> void:
			AudioDirector.play_raw("res://assets/audio/ui_tick.ogg", -4.0 + i)
		)
	AudioDirector.play_raw(CLANK_SFX, -3.0)
	Game.vibrate(0.35, 0.2, 0.2)
	Game.hud.subtitle(Loc.t(&"barograph.wound_done"), 2.5)
	Director.add_tension(-4.0, "завод барабана барографа")
	if Game.tasks != null and Game.tasks.is_active(&"barograph_check"):
		Game.tasks.complete(&"barograph_check")
	_update_status()


func _listen_pen() -> void:
	_listening = 5.0
	_scratch_player.play()
	Director.add_tension(4.0, "барограф: подслушан скрип пера")
	_update_status()


# --- Лента ------------------------------------------------------------------------------

func _x(h: float) -> float:
	var w := _chart.size.x - 70.0
	return 56.0 + (h - (_now_h - HOURS_BACK)) / (HOURS_BACK + HOURS_AHEAD) * w


func _y(p: float) -> float:
	var hgt := _chart.size.y - 50.0
	return 18.0 + (MM_HALF - (p - _center_p)) / (MM_HALF * 2.0) * hgt


## Что пишет перо в час h: давление плюс то, чего в воздухе не было.
func _pen(h: float) -> float:
	if Game.night == 7 and Game.final_call:
		var is_mimic: bool = bool(SaveGame.flags.get("night7_crawler_is_mimic", true))
		if is_mimic:
			return 690.0
		else:
			return 718.0 + sin(h * 340.0) * 0.28   # механическая микровибрация 11-тонного дизеля
	var p := Game.pressure_at(h)
	if not _tapped:
		p += _dead_band
	elif _tap_step_time > 0.0 and h < _tap_step_time - 0.01:
		p += 1.4
	if Game.is_night() and h >= SIGNAL_H and h < SIGNAL_H + 0.06:
		p = _center_p + MM_HALF * 1.4                           # удар 03:10 — до края ленты
	if Game.anomalies != null and Game.anomalies.is_active(&"baro_tooth"):
		var th := _now_h - 0.7                                  # зуб: −9 мм за четверть часа, и назад
		if h > th and h < th + 0.5:
			p -= 9.0 * sin(PI * (h - th) / 0.5)
	return p


func _draw_chart() -> void:
	var w := _chart.size
	var font := UiStyle.plate_font()
	var grid := Color(0.55, 0.42, 0.55, 0.45)
	var grid_b := Color(0.45, 0.3, 0.45, 0.75)
	var ink_l := Color(0.32, 0.2, 0.32)
	# Бумага ленты; изгиб и тень даёт сам барабан
	_chart.draw_rect(Rect2(Vector2.ZERO, w), Color(0.93, 0.91, 0.84))
	UiStyle.vgrad(_chart, Rect2(0, 0, w.x, 18), Color(0.55, 0.5, 0.4, 0.25), Color(0, 0, 0, 0))
	# Давление: линия через 1 мм, жирная и подпись — через 5
	for mm in range(int(_center_p - MM_HALF) - 1, int(_center_p + MM_HALF) + 2):
		var y := _y(mm)
		if y < 8.0 or y > w.y - 30.0:
			continue
		var bold := mm % 5 == 0
		_chart.draw_line(Vector2(50, y), Vector2(w.x - 10, y), grid_b if bold else grid, 3.0 if bold else 1.6)
		if bold:
			_chart.draw_string(font, Vector2(6, y + 9), str(mm), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink_l)
	# Время: дуги часов (как на ленте барабана), подписи через 3 часа
	for k in range(int(floor(_now_h - HOURS_BACK)), int(ceil(_now_h + HOURS_AHEAD)) + 1):
		var x := _x(k)
		if x < 50.0 or x > w.x - 10.0:
			continue
		var hour := posmod(int(_hour0) + k, 24)
		var bold := hour % 3 == 0
		_chart.draw_line(Vector2(x, 10), Vector2(x, w.y - 40), grid_b if bold else grid, 2.6 if bold else 1.4)
		if bold:
			_chart.draw_string(font, Vector2(x - 18, w.y - 8), "%02d" % hour, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink_l)
			# Цифры давления — и у каждой трёхчасовой линии: читать у пера, не уводя глаз на край барабана
			for mm in range(int(ceil((_center_p - MM_HALF) / 5.0)) * 5, int(_center_p + MM_HALF) + 1, 5):
				var my := _y(mm)
				if my > 30.0 and my < w.y - 50.0:
					_chart.draw_string(font, Vector2(x + 5, my - 5), str(mm), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ink_l, 0.75))
	# Перо: фиолетовые чернила до «сейчас» (или до остановки пружины)
	var end_h := _now_h if Game.barograph_live() else _now_h - 1.0
	var pts := PackedVector2Array()
	var h := _now_h - HOURS_BACK - 0.2
	while h <= end_h:
		pts.append(Vector2(_x(h), clampf(_y(_pen(h)), 10.0, w.y - 32.0)))
		h += 0.05
	pts.append(Vector2(_x(end_h), clampf(_y(_pen(end_h)), 10.0, w.y - 32.0)))
	if pts.size() > 1:
		_chart.draw_polyline(pts, Color(0.42, 0.12, 0.55, 0.95), 5.0, true)
	var tip := pts[pts.size() - 1]
	if Game.barograph_live():
		_chart.draw_circle(tip, 5.0, Color(0.28, 0.08, 0.38))   # капля чернил под пером (само перо — на рычаге)
	# Линейка у мыши
	if _ruler_y >= 0.0:
		_chart.draw_line(Vector2(50, _ruler_y), Vector2(w.x - 10, _ruler_y), Color(0.15, 0.35, 0.75, 0.8), 3.0)
	var ax := Loc.t(&"barograph.mm_axis")
	var aw := font.get_string_size(ax, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_chart.draw_rect(Rect2(w.x - aw - 22, 8, aw + 10, 26), Color(0.93, 0.91, 0.84))
	_chart.draw_string(font, Vector2(w.x - aw - 17, 28), ax, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink_l)


# --- Запись -----------------------------------------------------------------------------

func _write() -> void:
	if _done:
		return
	if not Game.barograph_live():
		Game.hud.subtitle(Loc.t(&"barograph.stopped"), 3.0)
		return
	_done = true
	var p := _book.value(0)
	var t := _book.value(1)
	Game.write_reading(&"baro", p, _truth)
	Game.write_reading(&"baro_tend", t, _truth_tend)
	Game.take_reading(&"baro")
	Game.audio.play_2d(PEN_SFX, -12.0)
	Game.hud.subtitle(Loc.t(&"barograph.written", [ThermometerUI.fmt(p, 1).trim_prefix("+"), ThermometerUI.fmt(t, 1)]) + " " + ThermometerUI.tail(), 5.0)
	_close()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		_close()
		return
	if event.is_action_pressed(&"crank"):
		_wind_mechanism()
		return
	if (event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y):
		_write()
		return
	_book.handle_key(event)


func _close() -> void:
	if _scratch_player.playing:
		_scratch_player.stop()
	closed.emit()
