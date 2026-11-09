class_name FPHands
extends Node3D
## Руки от первого лица: рукав ватника и шерстяная варежка (всегда — и на улице, и в доме).
## Левая — с фонарём, пока он включён или крутим динамо. Правая появляется только при деле:
## несёт предмет, тянется к тому, с чем взаимодействуем, крутит динамо, стреляет ракетницей.
## Руки и предмет в руках рисуются поверх мира (шейдер ps1_viewmodel) — в стены не уходят.
## Прячутся вниз, за нижний край кадра — на любом соотношении сторон экрана.

const SLEEVE := Color(0.19, 0.21, 0.16)       # выцветший защитный ватник
const SEAM := Color(0.12, 0.13, 0.1)          # строчка стёжки
const CUFF := Color(0.15, 0.14, 0.13)         # вязаная манжета
const MITTEN := Color(0.3, 0.27, 0.24)        # серая шерстяная варежка
const MITTEN_PALM := Color(0.22, 0.18, 0.15)  # кожаная накладка на ладони
const TORCH := Color(0.16, 0.17, 0.16)
const SHADER := "res://assets/shaders/ps1_viewmodel.gdshader"
const GLOW := 0.8                             ## собственное свечение рук

const L_ON := Vector3(-0.17, -0.215, -0.43)
const L_OFF := Vector3(-0.17, -0.8, -0.32)
const R_OFF := Vector3(0.17, -0.82, -0.32)
const R_REACH := Vector3(0.1, -0.15, -0.55)

static var _shader: Shader
static var _mats: Dictionary = {}

var player: Player
var left: Node3D
var right: Node3D
var torch_lens: MeshInstance3D
var flare_gun: Node3D

var _reach_t := 0.0
var _flare_t := 0.0
var _crank_t := 0.0
var _left_pos := L_OFF
var _right_pos := R_OFF
var _right_rot := Vector3.ZERO
var _lens_on: ShaderMaterial
var _lens_off: ShaderMaterial
var _lever: Node3D
var _lag := Vector2.ZERO          ## отставание рук при повороте головы (инерция)
var _prev_look := Vector2.ZERO
var _frost := 0.0                 ## иней на варежке: на морозе белеет, в тепле оттаивает

var tablet_root: Node3D
var torch_root: Node3D
var flail := 0.0                  ## падение: руки машут сами (сцены от первого лица), 0..1 — сила
var climb := -1.0                 ## подъём по лестнице: фаза перехвата перекладин (≥0 — лезем)
var tablet_model: Node3D
var compass_needle: Node3D
var _tablet_up := false
var _tablet_pos := Vector3(-0.06, -0.65, -0.32)
var _compass_tap_wobble := 0.0


func _ready() -> void:
	left = _arm(-1.0)
	right = _arm(1.0)
	add_child(left)
	add_child(right)
	left.position = L_OFF
	right.position = R_OFF
	# Динамо-фонарик «Жучок» в левой: овальный корпус из тёмного карболита, хромированный ободок,
	# рычаг-«ручка» снизу — его жмут, чтобы зарядить (Q), и он ходит под пальцами.
	torch_root = Node3D.new()
	# Фонарь лежит на кулаке: корпус и ободок видно над варежкой, рычаг — под пальцами
	torch_root.position = Vector3(0.006, 0.058, -0.045)
	torch_root.rotation_degrees = Vector3(-4.0, 9.0, -6.0)
	left.add_child(torch_root)
	var chrome := Color(0.55, 0.56, 0.55)
	var zb := _glb_part("zhuchok", &"fp_zhuk_glb", 3)
	if zb != null:
		torch_root.add_child(zb)     # модель из Блендера (tools/blender/zhuchok.py)
	else:
		_build_zhuk_body(torch_root, chrome)
	# Рычаг на шарнире у носа: открыт ~16°, при зарядке прижимается к корпусу
	_lever = Node3D.new()
	_lever.position = Vector3(0, -0.03, -0.105)
	torch_root.add_child(_lever)
	var zl := _glb_part("zhuchok_lever", &"fp_zhuk_lever_glb", 3)
	if zl != null:
		_lever.add_child(zl)
	else:
		var lv := MeshKit.new(6)
		lv.mottle = 0.04
		lv.tube([Vector3(0, 0, 0), Vector3(0, -0.006, 0.05), Vector3(0, -0.004, 0.1)], [0.007, 0.008, 0.007], chrome.darkened(0.25), 6)
		lv.box(Vector3(0, -0.009, 0.06), Vector3(0.022, 0.006, 0.07), Color(0.12, 0.12, 0.12))     # накладка под пальцы
		_lever.add_child(_mesh(lv, &"fp_zhuk_lever", "tex_metal.png", 3))
	_lever.rotation.x = deg_to_rad(16.0)
	_build_lens(torch_root)
	_ready_rest()


## Запасной процедурный корпус «Жучка», если модели из Блендера нет.
func _build_zhuk_body(torch_root: Node3D, chrome: Color) -> void:
	var k := MeshKit.new(5)
	k.mottle = 0.05
	var body := Color(0.15, 0.17, 0.15)
	k.blob(Vector3(0, 0.0, -0.06), Vector3(0.03, 0.036, 0.062), body, 6, 10)                 # корпус-«жук»
	k.blob(Vector3(0, 0.03, -0.06), Vector3(0.012, 0.008, 0.04), body.lightened(0.08), 3, 6)  # рёбра на спинке
	k.tube([Vector3(0, 0.004, -0.112), Vector3(0, 0.004, -0.128)], [0.027, 0.029], chrome, 12)  # ободок
	k.tube([Vector3(0, -0.02, 0.0), Vector3(0, -0.012, 0.02), Vector3(0, 0.012, 0.02), Vector3(0, 0.022, 0.0)],
		[0.004, 0.004, 0.004, 0.004], Color(0.1, 0.09, 0.08), 4)                               # петля для шнурка
	torch_root.add_child(_mesh(k, &"fp_zhuk", "tex_metal.png", 3))


func _build_lens(torch_root: Node3D) -> void:
	torch_lens = MeshInstance3D.new()
	var lens := CylinderMesh.new()
	lens.top_radius = 0.025
	lens.bottom_radius = 0.025
	lens.height = 0.004
	lens.radial_segments = 12
	torch_lens.mesh = lens
	torch_lens.rotation.x = PI * 0.5
	torch_lens.position = Vector3(0, 0.004, -0.13)
	_lens_on = _lens_mat(true)
	_lens_off = _lens_mat(false)
	torch_lens.material_override = _lens_off
	_setup(torch_lens)
	torch_root.add_child(torch_lens)


func _ready_rest() -> void:
	flare_gun = _make_flare_gun()
	flare_gun.position = Vector3(0, -0.01, -0.05)
	right.add_child(flare_gun)

	# 3D Офицерский планшет с картой и светящимся компасом Адрианова
	tablet_root = Node3D.new()
	tablet_root.name = "TabletRoot"
	tablet_root.position = _tablet_pos
	add_child(tablet_root)
	tablet_model = Props.officer_tablet()
	tablet_model.scale = Vector3.ONE * 0.52
	tablet_model.rotation_degrees = Vector3(55.0, 180.0, 0.0)
	tablet_root.add_child(tablet_model)
	FPHands.to_view_layer(tablet_model)

	compass_needle = Node3D.new()
	compass_needle.name = "CompassNeedle"
	compass_needle.position = Vector3(0.026, 0.042, 0.022)
	tablet_model.add_child(compass_needle)
	var n_mesh := MeshInstance3D.new()
	var n_box := BoxMesh.new()
	n_box.size = Vector3(0.003, 0.002, 0.022)
	n_mesh.mesh = n_box
	var n_mat := StandardMaterial3D.new()
	n_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	n_mat.albedo_color = Color(0.95, 0.25, 0.2)
	n_mesh.material_override = n_mat
	compass_needle.add_child(n_mesh)

	if player == null:     # экземпляр для прогрева шейдеров: всё видно, включённая линза тоже
		var lit := torch_lens.duplicate() as MeshInstance3D
		lit.material_override = _lens_on
		lit.position.x = 0.08
		left.add_child(lit)
		left.position = Vector3(-0.15, 0, 0)
		right.position = Vector3(0.15, 0, 0)
	else:
		flare_gun.visible = false
		left.visible = false
		right.visible = false
		tablet_root.visible = false


func _process(delta: float) -> void:
	if player == null:
		return
	if flail > 0.0 or climb >= 0.0:
		_scripted()
		return
	var walking := player.mode == Player.Mode.WALK
	visible = walking
	if not walking:
		return
	var k := minf(delta * 9.0, 1.0)
	if Game.has_flag("riding") and Snowmobile.instance != null:
		_ride_hands(delta)
		return
	var bob := player.bob_phase()
	var walk_k := player.walk_amount()
	var sway := Vector3(sin(bob * 0.5) * 0.01, -absf(cos(bob * 0.5)) * 0.012, 0.0) * walk_k

	# Инерция: руки чуть отстают от поворота головы и догоняют — у них появляется вес
	var look := Vector2(player.rotation.y, player.head.rotation.x)
	var dl := look - _prev_look
	_prev_look = look
	if absf(dl.x) < 1.0:
		_lag = (_lag + Vector2(dl.x, -dl.y) * 0.35).limit_length(0.06)
	_lag = _lag.lerp(Vector2.ZERO, minf(delta * 7.0, 1.0))
	var lag3 := Vector3(_lag.x, _lag.y, 0.0)
	var breathe := Vector3(0.0, sin(Time.get_ticks_msec() * 0.0021) * 0.003, 0.0) * (1.0 - walk_k)

	# Иней на варежках: на улице в холод белеют, дома оттаивают
	var want_frost := clampf((60.0 - Game.warmth) / 40.0, 0.0, 1.0) if Game.is_outside() else 0.0
	_frost = move_toward(_frost, want_frost, delta * (0.04 if want_frost > _frost else 0.08))
	for key: StringName in [&"fp_mitten", &"fp_mitten_l", &"fp_mitten_r"]:
		if _mats.has(key):
			(_mats[key] as ShaderMaterial).set_shader_parameter(&"albedo", Color(1, 1, 1).lerp(Color(1.9, 2.0, 2.2), _frost))

	# Левая рука: если держим рундук или собаку (при выключенном фонаре) — левая варежка поддерживает предмет
	if (player.held == &"trunk" or (player.held == &"dog" and not player.flashlight_on())) and _flare_t <= 0.0:
		var gl: Array = [Vector3(-0.24, -0.05, 0.0), Vector3(0.0, -15.0, 40.0)] if player.held == &"trunk" else [Vector3(-0.18, -0.08, 0.0), Vector3(-10.0, -15.0, 50.0)]
		var xfl := player.held_root().transform * Transform3D(Basis.from_euler(gl[1] * (PI / 180.0)), gl[0])
		left.visible = true
		left.transform = left.transform.interpolate_with(xfl, minf(k * 1.4, 1.0))
		_left_pos = left.position
	else:
		# Левая рука: «Жучок»
		var torch_on := player.flashlight_on()
		torch_lens.material_override = _lens_on if torch_on else _lens_off
		var left_up := torch_on or player.cranking
		var pitch_x: float = player.head.rotation.x
		var down_k := clampf(-pitch_x / 1.0, 0.0, 1.0)
		var l_target := (L_ON + Vector3(-0.03, -0.16, 0.08) * down_k) if left_up else L_OFF
		_left_pos = _left_pos.lerp(l_target, k * 0.8)
		var squeeze := 0.0
		if player.cranking:
			_crank_t += delta * 11.0
			squeeze = absf(sin(_crank_t))
		_lever.rotation.x = deg_to_rad(lerpf(16.0, 1.0, squeeze))
		left.position = _left_pos + Vector3(-sway.x, sway.y, 0) + lag3 + breathe + Vector3(0, -0.006 * squeeze, 0)
		left.rotation_degrees = Vector3(2.0 + sway.y * 200.0 - down_k * 15.0, 3.0, -squeeze * 4.0)
		left.visible = left_up or _left_pos.distance_to(L_OFF) > 0.04

	# Правая: в предмете — едет с ним; иначе тянется, крутит динамо, стреляет или убрана вниз
	_reach_t = maxf(_reach_t - delta, 0.0)
	_flare_t = maxf(_flare_t - delta, 0.0)
	flare_gun.visible = _flare_t > 0.0
	if player.held != &"" and _flare_t <= 0.0:
		var g := _grip(player.held)
		var xf := player.held_root().transform * Transform3D(Basis.from_euler(g[1] * (PI / 180.0)), g[0])
		right.visible = true
		right.transform = right.transform.interpolate_with(xf, minf(k * 1.4, 1.0))
		_right_pos = right.position
		_right_rot = right.rotation_degrees
		return
	var target := R_OFF
	var rot := Vector3(4.0, -6.0, 0.0)
	var busy := true
	if _flare_t > 0.0:
		var kick := clampf((_flare_t - 0.95) / 0.25, 0.0, 1.0)
		target = Vector3(0.14, -0.15, -0.42) + Vector3(0, 0.04, 0.06) * kick
		rot = Vector3(4.0 + kick * 28.0, -4.0, 0.0)
	elif _reach_t > 0.0:
		var p := sin(clampf(_reach_t / 0.45, 0.0, 1.0) * PI)
		target = Vector3(0.14, -0.4, -0.45).lerp(R_REACH, p)
		rot = Vector3(4.0 - p * 6.0, -6.0, -20.0 * p)
	else:
		busy = false
	_right_pos = _right_pos.lerp(target, k)
	_right_rot = _right_rot.lerp(rot, k)
	right.position = _right_pos + sway + lag3 + breathe
	right.rotation_degrees = _right_rot
	right.visible = busy or _right_pos.distance_to(R_OFF) > 0.04

	# Планшет с картой: подъём к камере при [M] и слежение стрелки компаса за севером
	var tablet_target := Vector3(-0.04, -0.16, -0.36) if _tablet_up else Vector3(-0.06, -0.65, -0.32)
	_tablet_pos = _tablet_pos.lerp(tablet_target, minf(delta * 7.5, 1.0))
	if tablet_root != null:
		tablet_root.position = _tablet_pos + lag3 * 0.35 + breathe
		tablet_root.visible = _tablet_up or _tablet_pos.y > -0.60
		if compass_needle != null and player != null:
			var stuck: float = player.compass_stuck if "compass_stuck" in player else 0.0
			compass_needle.rotation.y = -player.global_rotation.y + player.compass_glitch + stuck + _compass_tap_wobble
	_compass_tap_wobble = move_toward(_compass_tap_wobble, 0.0, delta * 6.0)


## Сюжетные сцены от первого лица: падение (руки хватают воздух) и подъём по лестнице (перехват).
func _scripted() -> void:
	visible = true
	left.visible = true
	right.visible = true
	flare_gun.visible = false
	var t := Time.get_ticks_msec() * 0.001
	if climb >= 0.0:
		for k in 2:
			var arm := left if k == 0 else right
			var side := -1.0 if k == 0 else 1.0
			var ph := sin(climb * PI + k * PI)
			arm.position = Vector3(0.16 * side, -0.2 + maxf(ph, 0.0) * 0.26, -0.34 - maxf(ph, 0.0) * 0.06)
			arm.rotation_degrees = Vector3(-35.0 + maxf(ph, 0.0) * 40.0, -6.0 * side, 8.0 * side)
		return
	var f := flail
	left.position = Vector3(-0.24, -0.05, -0.4) + Vector3(sin(t * 13.0), cos(t * 10.7), sin(t * 7.1) * 0.5) * 0.1 * f
	left.rotation_degrees = Vector3(sin(t * 9.0) * 50.0, cos(t * 8.0) * 30.0, sin(t * 11.0) * 40.0) * f
	right.position = Vector3(0.24, -0.02, -0.42) + Vector3(cos(t * 12.3), sin(t * 9.9), cos(t * 6.6) * 0.5) * 0.1 * f
	right.rotation_degrees = Vector3(cos(t * 8.5) * 50.0, sin(t * 7.0) * 30.0, cos(t * 10.0) * 40.0) * f


## На «Буране»: обе варежки на руле. Руль поворачивается с поворотом, руки трясёт мотором.
func _ride_hands(delta: float) -> void:
	# Руль ниже кадра — руки держим в кадре, у нижнего края, как в гонках от первого лица.
	var sm := Snowmobile.instance
	var steer := sm.steer_amount
	var load := clampf(absf(sm.speed) / Snowmobile.MAX_SPEED, 0.0, 1.0)
	var buzz := (0.002 + load * 0.004) if sm.engine_on else 0.0
	var k := minf(delta * 12.0, 1.0)
	var pitch: float = player.head.rotation.x
	# Компенсируем наклон головы, чтобы варежки оставались на руле снегохода, а не взлетали в небо
	var pitch_offset := Vector3(0.0, -pitch * 0.42, pitch * 0.18)
	var pitch_rot := -rad_to_deg(pitch) * 0.65
	for side: float in [-1.0, 1.0]:
		var h := left if side < 0.0 else right
		h.visible = true
		# Поворот руля: одна рука уходит вперёд-вниз, другая — к себе и вверх
		var push := -steer * side
		var lp := Vector3(0.23 * side, -0.29 + push * 0.035, -0.46 - push * 0.05) + pitch_offset
		lp += Vector3(randf_range(-buzz, buzz), randf_range(-buzz, buzz), 0.0)
		h.position = h.position.lerp(lp, k)
		h.rotation_degrees = h.rotation_degrees.lerp(Vector3(-12.0 + pitch_rot, side * -10.0 + steer * 10.0, side * 28.0 + steer * 6.0), k)
	torch_lens.material_override = _lens_off
	_left_pos = left.position
	_right_pos = right.position
	if tablet_root != null:
		tablet_root.visible = false
	flare_gun.visible = false


## Рука тянется к предмету (нажали «взаимодействовать»).
func reach() -> void:
	_reach_t = 0.45


## Выстрел ракетницей: пистолет в правой, отдача.
func flare() -> void:
	_flare_t = 1.2


func toggle_tablet(force := -1) -> bool:
	if force == 0:
		_tablet_up = false
	elif force == 1:
		_tablet_up = true
	else:
		_tablet_up = not _tablet_up
	return _tablet_up


func is_tablet_up() -> bool:
	return _tablet_up


func tap_compass() -> void:
	_compass_tap_wobble = randf_range(0.25, 0.45) * (-1.0 if randf() > 0.5 else 1.0)


## Хват для переносимого предмета: позиция и поворот кисти в координатах держателя предмета.
static func _grip(item: StringName) -> Array:
	match item:
		&"canister":
			return [Vector3(0.0, 0.33, 0.0), Vector3(-25.0, 0.0, 90.0)]    # за верхнюю ручку, рука назад к плечу
		&"oil":
			return [Vector3(0.1, 0.11, 0.0), Vector3(0.0, 0.0, 0.0)]       # обхват сбоку
		&"shovel":
			return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)]         # за черенок ровно по центру хвата
		&"trunk":
			return [Vector3(0.24, -0.05, 0.0), Vector3(0.0, 15.0, -40.0)]  # хват за правую ручку рундука
		&"kettle":
			return [Vector3(0.0, 0.17, 0.0), Vector3(-10.0, 0.0, 90.0)]     # за верхнюю дужку чайника
		&"blowtorch":
			return [Vector3(0.0, 0.08, 0.10), Vector3(15.0, 0.0, 0.0)]      # за заднюю рукоять паяльной лампы
		&"dog":
			return [Vector3(0.18, -0.08, 0.0), Vector3(-10.0, 15.0, -50.0)] # поддержка собаки справа снизу
		_:
			return [Vector3(0.12, -0.03, 0.02), Vector3(0.0, 10.0, -70.0)]  # охапка снизу


func _arm(side: float) -> Node3D:
	var root := Node3D.new()
	# Модели из Блендера (tools/blender/fp_arms.py): стёганый рукав ватника и вязаная варежка
	var sd := "r" if side > 0 else "l"
	var sl := _glb_part("fp_sleeve_" + sd, StringName("fp_sleeve_" + sd), 1)
	var mt := _glb_part("fp_mitten_" + sd, StringName("fp_mitten_" + sd), 2)
	if sl != null and mt != null:
		for part: MeshInstance3D in [sl, mt]:
			(part.material_override as ShaderMaterial).set_shader_parameter(&"emission", 0.28)   # цвет уже запечён — не пересвечивать
		root.add_child(sl)
		root.add_child(mt)
		return root
	# Рукав: короткий (до середины предплечья — дальше он за кадром), гладкий, с лёгкой стёжкой валиками
	var k := MeshKit.new(11 if side > 0 else 12)
	k.mottle = 0.03
	var wrist := Vector3(0, 0, 0.05)
	var elbow := Vector3(0.03 * side, -0.2, 0.17)   # предплечье уходит круто вниз — за нижний край кадра, а не по диагонали через экран
	var pts: Array = []
	var radii: Array = []
	for i in 6:
		var t := float(i) / 5.0
		pts.append(wrist.lerp(elbow, t))
		radii.append(lerpf(0.047, 0.058, t) * (1.0 if i % 2 == 0 else 0.97))
	k.tube(pts, radii, SLEEVE, 10, true, false)
	# Вязаная манжета
	var dir := (elbow - wrist).normalized()
	k.tube([wrist + dir * 0.03, wrist - dir * 0.035], [0.046, 0.042], CUFF, 10)
	root.add_child(_mesh(k, &"fp_sleeve", "tex_cloth.png", 1))

	# Варежка: кулак-мешок, большой палец отдельно, кожаная накладка на ладони
	var m := MeshKit.new(21 if side > 0 else 22)
	m.mottle = 0.05
	m.blob(Vector3(0, 0, -0.06), Vector3(0.043, 0.05, 0.075), MITTEN, 5, 10)
	m.blob(Vector3(-0.03 * side, -0.004, -0.065), Vector3(0.016, 0.042, 0.06), MITTEN_PALM, 3, 8)
	m.tube([Vector3(-0.032 * side, 0.02, -0.03), Vector3(-0.045 * side, 0.035, -0.07), Vector3(-0.04 * side, 0.03, -0.1)],
		[0.019, 0.017, 0.012], MITTEN, 8)
	root.add_child(_mesh(m, &"fp_mitten", "tex_cloth.png", 2))
	return root


## Сигнальный пистолет: широкий ствол, рукоять, спуск. Тёмный металл, бакелитовая рукоять.
func _make_flare_gun() -> Node3D:
	var k := MeshKit.new(41)
	k.mottle = 0.05
	var metal := Color(0.22, 0.23, 0.23)
	var grip := Color(0.34, 0.19, 0.1)
	k.tube([Vector3(0, 0.05, -0.02), Vector3(0, 0.05, -0.2)], [0.022, 0.022], metal, 10)
	k.tube([Vector3(0, 0.05, -0.2), Vector3(0, 0.05, -0.215)], [0.026, 0.026], metal.lightened(0.15), 10)
	k.box(Vector3(0, 0.035, 0.0), Vector3(0.03, 0.04, 0.07), metal)
	k.box(Vector3(0, -0.02, 0.025), Vector3(0.028, 0.09, 0.04), grip, Basis(Vector3.RIGHT, deg_to_rad(-14.0)))
	k.box(Vector3(0, 0.005, -0.025), Vector3(0.006, 0.03, 0.006), metal)
	return _mesh(k, &"fp_flaregun", "tex_metal.png", 3)


func _mesh(k: MeshKit, key: StringName, tex: String, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = material(key, tex, priority)
	_setup(mi)
	return mi


## Деталь из Блендера (assets/models/kedr/<id>.glb, координаты уже в осях torch_root):
## меш + запечённая текстура (цвет × AO) под шейдер рук. Нет файла — null, строим по-старому.
func _glb_part(id: String, key: StringName, priority: int) -> MeshInstance3D:
	var path := "res://assets/models/kedr/%s.glb" % id
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	var src := _first_mesh(inst)
	if src == null:
		inst.free()
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	mi.transform = src.transform
	var tex: Texture2D = null
	var sm := src.get_active_material(0)
	if sm is BaseMaterial3D:
		tex = (sm as BaseMaterial3D).albedo_texture
	inst.free()
	var m := material(key, "", priority)
	if tex != null:
		m.set_shader_parameter(&"uv_tex", tex)
		m.set_shader_parameter(&"use_uv", 1.0)
		m.set_shader_parameter(&"uv_gain", 0.7)
	mi.material_override = m
	_setup(mi)
	return mi


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for ch in n.get_children():
		var r := _first_mesh(ch)
		if r != null:
			return r
	return null


## Материал «поверх мира». priority — порядок внутри рук: рукав < варежка < фонарь < линза.
static func material(key: StringName, tex: String, priority: int, src: ShaderMaterial = null) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load(SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.render_priority = priority
	m.set_shader_parameter(&"albedo", Color.WHITE)
	m.set_shader_parameter(&"emission", 0.05 if src != null else GLOW)
	var t: Texture2D = null
	if src != null:
		var ut = src.get_shader_parameter(&"uv_tex")
		if ut is Texture2D:
			m.set_shader_parameter(&"uv_tex", ut)
			m.set_shader_parameter(&"use_uv", 1.0)
		var st = src.get_shader_parameter(&"tex")
		var from_model := src.shader != null and src.shader.resource_path == Models.SHADER
		if st is Texture2D and not (ut is Texture2D):
			if from_model:
				# Модель из Блендера (Models): «tex» — запечённая UV-текстура (канистра)
				m.set_shader_parameter(&"uv_tex", st)
				m.set_shader_parameter(&"use_uv", 1.0)
			else:
				# Процедурный предмет (MeshKit): цвет — в вершинах, текстура — трипланаром. По UV его брать
				# нельзя: UV у таких мешей нет, и предмет в руках выходил белым (дрова, банка масла).
				m.set_shader_parameter(&"tex", st)
				m.set_shader_parameter(&"use_tex", 1.0)
		var a = src.get_shader_parameter(&"albedo")
		if a is Color:
			m.set_shader_parameter(&"albedo", a)
	elif tex != "":
		t = load("res://assets/textures/" + tex)
		if t != null:
			m.set_shader_parameter(&"tex", t)
			m.set_shader_parameter(&"use_tex", 1.0)
	_mats[key] = m
	return m


## Переносимый предмет — тоже поверх мира (рисуется перед руками, чтобы варежка была сверху).
static func to_view_layer(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var src: ShaderMaterial = mi.material_override as ShaderMaterial
		if src == null and mi.get_surface_override_material_count() > 0:
			src = mi.get_surface_override_material(0) as ShaderMaterial
		if src == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var act = mi.get_active_material(0)
			if act is ShaderMaterial:
				src = act as ShaderMaterial
			elif act is BaseMaterial3D:
				var bm := act as BaseMaterial3D
				src = ShaderMaterial.new()
				src.shader = load(SHADER) as Shader
				src.set_shader_parameter(&"albedo", bm.albedo_color)
				if bm.albedo_texture != null:
					src.set_shader_parameter(&"uv_tex", bm.albedo_texture)
					src.set_shader_parameter(&"use_uv", 1.0)
		mi.material_override = material(StringName("fp_item_%d" % mi.mesh.get_instance_id()), "", 0, src)
		_setup(mi)
	for ch in n.get_children():
		to_view_layer(ch)


## Стекло фонаря — тем же шейдером рук, с честной глубиной. Раньше линза рисовалась поверх всего
## (no_depth_test) и просвечивала сквозь варежку белым кружком в углу экрана.
static func _lens_mat(on: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.render_priority = 4
	m.set_shader_parameter(&"albedo", Color(1.0, 0.88, 0.62) if on else Color(0.3, 0.32, 0.3))
	m.set_shader_parameter(&"emission", 2.2 if on else 0.15)
	return m


static func _setup(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 0.5
