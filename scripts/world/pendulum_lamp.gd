class_name PendulumLamp
extends Node3D
## Уличный плафон СПО-200 (Светильник Подвесной Открытый, 200 Вт, ГОСТ 8045-82).
## Раскачивается ветром по закону затухающего маятника (частота w0 ~ 2.4 рад/с).
## Отбрасывает динамические тени от забора, жердей и будки на белый снег.
## С Ночи 4: под конусом света появляется «бесхозная тень» без геометрического источника,
## которая ползёт с собственным запаздыванием и не подчиняется раскачиванию маятника.
## При прямом взгляде на лампу с дистанции < 14 м накапливает ослепление сетчатки
## (адаптация колбочек/палочек, ~4 с тёмной пелены при взгляде во тьму двора).

const FREQ := 2.4            ## собственная частота маятника
const DAMPING := 0.985        ## затухание за кадр при 60 fps
const MAX_SWAY := 0.38        ## макс. угол отклонения в радианах (~22 градуса)
const LIGHT_RANGE := 28.0
const LIGHT_ANGLE := 44.0
const LIGHT_ENERGY := 3.4
const BULB_COLOR := Color(1.0, 0.88, 0.70)

var sway_x := 0.0
var sway_z := 0.0
var vel_x := 0.0
var vel_z := 0.0

var _pivot: Node3D
var _spot: SpotLight3D
var _omni: OmniLight3D
var _bulb_mesh: MeshInstance3D
var _sourceless_shadow: MeshInstance3D
var _sourceless_mat: StandardMaterial3D
var _shadow_t := 0.0
var _gaze_timer := 0.0


func _ready() -> void:
	_build_fixture()
	_build_sourceless_shadow()


func _build_fixture() -> void:
	# 1. Точка подвеса на кронштейне (на высоте 5.2м)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, 5.2, 0.0)
	add_child(_pivot)

	var iron := Color(0.22, 0.23, 0.25)
	var white_enamel := Color(0.85, 0.86, 0.88)
	var porcelain := Color(0.92, 0.94, 0.90)
	var snow := Color(0.88, 0.92, 0.96)

	var k := MeshKit.new(48)
	k.mottle = 0.04

	# Подвесная трубка-штанга от шарнира вниз (длина 0.75м)
	k.tube([Vector3(0, 0, 0), Vector3(0, -0.65, 0)], [0.016], iron, 6)
	# Фарфоровый изолятор-оголовник СПО-200
	k.tube([Vector3(0, -0.65, 0), Vector3(0, -0.73, 0), Vector3(0, -0.78, 0)], [0.035, 0.055, 0.045], porcelain, 8, true, true)
	# Конусный эмалированный абажур СПО-200 (диаметр 0.44м, высота 0.18м)
	k.tube([Vector3(0, -0.78, 0), Vector3(0, -0.84, 0), Vector3(0, -0.92, 0)], [0.065, 0.14, 0.22], white_enamel, 12, false, false)
	# Шапка надутого инея и снега на верхней кромке плафона
	k.box(Vector3(0, -0.80, 0), Vector3(0.18, 0.04, 0.18), snow)

	var fixt_mi := MeshInstance3D.new()
	fixt_mi.mesh = k.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.83, 0.85)
	mat.roughness = 0.5
	fixt_mi.material_override = mat
	_pivot.add_child(fixt_mi)

	# 2. Матовая колба 200-ваттной лампы накаливания
	var bulb_sm := SphereMesh.new()
	bulb_sm.radius = 0.055
	bulb_sm.height = 0.11
	_bulb_mesh = MeshInstance3D.new()
	_bulb_mesh.mesh = bulb_sm
	_bulb_mesh.position = Vector3(0, -0.88, 0)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(1.0, 0.96, 0.82)
	_bulb_mesh.material_override = bulb_mat
	_pivot.add_child(_bulb_mesh)

	# 3. Направленный конус света SpotLight3D с честными тенями
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0, -0.90, 0)
	_spot.rotation.x = -PI * 0.5    # светит строго вниз
	_spot.spot_range = LIGHT_RANGE
	_spot.spot_angle = LIGHT_ANGLE
	_spot.spot_attenuation = 1.15
	_spot.light_energy = LIGHT_ENERGY
	_spot.light_color = BULB_COLOR
	_spot.shadow_enabled = true
	_spot.shadow_bias = 0.04
	_spot.shadow_normal_bias = 1.2
	_spot.distance_fade_enabled = true
	_spot.distance_fade_begin = 35.0
	_spot.distance_fade_length = 15.0
	_pivot.add_child(_spot)

	# 4. Локальный рассеянный свет вокруг лампы
	_omni = OmniLight3D.new()
	_omni.position = Vector3(0, -0.88, 0)
	_omni.omni_range = 3.6
	_omni.light_energy = 0.8
	_omni.light_color = BULB_COLOR
	_omni.shadow_enabled = false
	_pivot.add_child(_omni)


func _build_sourceless_shadow() -> void:
	# Бесхозная тень (появляется с Ночи 4 под пятном СПО-200)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.8, 1.8)
	_sourceless_shadow = MeshInstance3D.new()
	_sourceless_shadow.mesh = plane
	_sourceless_shadow.position = Vector3(0.5, 0.025, 0.8)
	_sourceless_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_sourceless_mat = StandardMaterial3D.new()
	_sourceless_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sourceless_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sourceless_mat.albedo_color = Color(0.01, 0.015, 0.02, 0.0)
	_sourceless_mat.albedo_texture = _make_shadow_texture()
	_sourceless_shadow.material_override = _sourceless_mat
	add_child(_sourceless_shadow)
	_sourceless_shadow.visible = false


static func _make_shadow_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var vy := (float(y) / 63.0) * 2.0 - 1.0
		for x in 64:
			var vx := (float(x) / 63.0) * 2.0 - 1.0
			var r := sqrt(vx * vx + vy * vy)
			var a := clampf((1.0 - smoothstep(0.15, 0.95, r)), 0.0, 1.0)
			# Неправильная, вытянутая форма тени с пальцевидными отростками
			var angle := atan2(vy, vx)
			var warp := sin(angle * 3.0) * 0.15 + cos(angle * 5.0) * 0.08
			a = clampf(a + warp * (1.0 - r), 0.0, 1.0) * 0.72
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	# 1. Питание лампы (зависит от генератора станции)
	var powered := Game.power_on and not Game.gen_broken and Game.generator_fuel > 0.0
	if _spot != null:
		_spot.visible = powered
	if _omni != null:
		_omni.visible = powered
	if _bulb_mesh != null:
		var bm := _bulb_mesh.material_override as StandardMaterial3D
		if bm != null:
			bm.albedo_color = Color(1.0, 0.96, 0.82) if powered else Color(0.25, 0.24, 0.22)

	if not powered:
		if _sourceless_shadow != null:
			_sourceless_shadow.visible = false
		return

	# 2. Физика маятника под действием ветра
	var wind_spd: float = Game.synoptic.wind_speed if Game.synoptic != null else 8.5
	var wind_deg: float = Game.synoptic.wind_azimuth_deg if Game.synoptic != null else 350.0
	var wind_dir := deg_to_rad(wind_deg)
	var w_intensity: float = Game.weather.intensity if Game.weather != null else 0.4
	var gust: float = 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.35 + w_intensity * 0.45

	# Вектор силы ветра
	var wind_fx := cos(wind_dir) * wind_spd * 0.008 * gust
	var wind_fz := sin(wind_dir) * wind_spd * 0.008 * gust

	# Гармонический маятник: d^2(theta)/dt^2 = -w0^2 * theta + F_wind
	vel_x = (vel_x - (FREQ * FREQ * sway_x - wind_fx) * delta) * pow(DAMPING, delta * 60.0)
	vel_z = (vel_z - (FREQ * FREQ * sway_z - wind_fz) * delta) * pow(DAMPING, delta * 60.0)

	sway_x = clampf(sway_x + vel_x * delta, -MAX_SWAY, MAX_SWAY)
	sway_z = clampf(sway_z + vel_z * delta, -MAX_SWAY, MAX_SWAY)

	if _pivot != null:
		_pivot.rotation.x = sway_z
		_pivot.rotation.z = -sway_x

	# 3. Бесхозная тень (Ночь 4+)
	_process_sourceless_shadow(delta)

	# 4. Ослепление сетчатки при взгляде на светильник
	_process_retinal_dazzle(delta)


func _process_sourceless_shadow(delta: float) -> void:
	if _sourceless_shadow == null or _sourceless_mat == null:
		return
	var is_night_4_plus := Game.is_night() and Game.night >= 4
	_sourceless_shadow.visible = is_night_4_plus
	if not is_night_4_plus:
		return

	_shadow_t += delta * 0.45
	# Тень не следует за маятником: она ползёт по круговой траектории с задержкой фазы
	var lag_x := sin(_shadow_t * 0.72) * 1.6 + cos(_shadow_t * 0.28) * 0.8
	var lag_z := cos(_shadow_t * 0.58) * 1.4 + sin(_shadow_t * 0.33) * 0.9
	_sourceless_shadow.position = Vector3(lag_x, 0.025, lag_z)
	_sourceless_shadow.rotation.y = _shadow_t * 0.25

	# Пульсация плотности тени (от 0.32 до 0.68)
	var density := 0.50 + sin(_shadow_t * 1.1) * 0.18
	_sourceless_mat.albedo_color.a = density


func _process_retinal_dazzle(delta: float) -> void:
	var p := Game.player
	if p == null or p.camera == null:
		return

	var cam := p.camera
	var bulb_pos := _pivot.global_position + Vector3(0, -0.88, 0)
	var cam_pos := cam.global_position
	var to_bulb := bulb_pos - cam_pos
	var dist := to_bulb.length()

	if dist > 14.0:
		_gaze_timer = maxf(_gaze_timer - delta * 2.0, 0.0)
		return

	var fwd := -cam.global_transform.basis.z.normalized()
	var dir_to_bulb := to_bulb.normalized()
	var dot := fwd.dot(dir_to_bulb)

	# Прямой взгляд в плафон (угол < 18 градусов)
	if dot > 0.95 and dist < 14.0:
		_gaze_timer += delta
		if _gaze_timer > 1.2:
			# Ослепление накапливается
			var dazzle_intensity := clampf((14.0 - dist) / 10.0, 0.3, 0.95)
			Game.retinal_dazzle = maxf(Game.retinal_dazzle, dazzle_intensity)
	else:
		_gaze_timer = maxf(_gaze_timer - delta * 1.5, 0.0)
