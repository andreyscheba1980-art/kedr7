class_name ArtTestTaiga
extends Node3D
## Эталонная сцена визуального стиля (Art Benchmark v5 — Кинематографичный хоррор):
##
## Точная художественная реализация по замечаниям:
## 1. Цветовой контраст: леденящий ночной индиго/бирюза снаружи vs тёмный сдержанный янтарь внутри.
## 2. Глубина тайги: многослойные чёрные силуэты елей со стилизованными гранёными снежными шапками
##    на фоне светящегося бирюзового горизонта и горной гряды.
## 3. Настоящее пламя свечей: толстые восковые свечи с видимыми горящими каплевидными огоньками и фитилями.
## 4. Сдержанная палитра: никаких ядовито-зелёных и синих пятен, выжигающего белого и оранжевого сока.
##    Заветренная тёмная сибирская сосна, матовый графит радио, приглушённый металл.
## 5. Честная геометрия досок: столешница из отдельных продольных плах без растяжения текстуры.
##
## Запуск: godot -- --arttest
## Управление: [WASD] полёт/ходьба, [Shift] бег, [F] фонарик, [Space/Ctrl] вверх/вниз, [Мышь] обзор, [ESC] выход.

const SHOTS := "user://shots/"

var _cam: Camera3D
var _spot: SpotLight3D
var _lamp_light: OmniLight3D
var _candle_light: OmniLight3D
var _bench_desk: Node3D
var _transistor_radio: Node3D
var _yrka_silhouette: Node3D
var _eyes: Node3D
var _snow_particles: CPUParticles3D
var _candle_flames: Array[MeshInstance3D] = []

var _free_cam := false
var _cam_yaw := deg_to_rad(0.0)
var _cam_pitch := deg_to_rad(-4.0)
var _flicker_t := 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	_setup_rendering_environment()
	_build_scene()
	_run_benchmark.call_deferred()


# --- 1. Освещение, палитра и постобработка -------------------------------------

func _setup_rendering_environment() -> void:
	var env := Environment.new()

	# Холодное ночное небо тайги: светящийся леденящий бирюзово-циановый горизонт
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.155, 0.235)

	# Рассеянный холодный лунный свет в тенях
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.12, 0.19)
	env.ambient_light_energy = 0.52

	# Холодный сине-бирюзовый туман тайги: разделяет планы и создаёт кинематографичный силуэт
	env.fog_enabled = true
	env.fog_light_color = Color(0.055, 0.145, 0.220)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.70
	env.fog_aerial_perspective = 0.40

	# Filmic тонемаппинг
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0

	# Снижение насыщенности на 35% для реалистичного давящего хоррора
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.65
	env.adjustment_contrast = 1.18

	# Мягкий блум
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Лунный свет: падает с юга/высоты под углом на север (-Z), освещая снег и лапы елей
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.58, 0.72, 0.92)
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-38.0, 32.0, 0.0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.04
	add_child(moon)


# --- 2. Построение сцены ------------------------------------------------------

func _build_scene() -> void:
	# Горная гряда и луна на горизонте
	_build_mountains_and_moon()

	# Заснеженный рельеф двора
	_build_snow_terrain()

	# Бревенчатая комната станции
	_build_room()

	# Стол из отдельных тёсаных плах, свечи с живым пламенем, ретро-радио, лампа
	_build_desk_setup()

	# Чёрные силуэты елей с гранёными снежными шапками в несколько планов
	_build_taiga_forest()

	# Уличный столб с тусклым фонарём
	_build_yard_lamp()

	# Зловещий силуэт в чаще с горящими глазами
	_build_forest_menace()

	# Падающий снег за окном
	_build_snow_particles()

	# Камера и фонарик игрока
	_setup_camera_and_flashlight()


# --- 3. Дальний план: Хребты Урала и Луна --------------------------------------

func _build_mountains_and_moon() -> void:
	# Лунный диск (серебристо-голубой круг на фоне ночного индиго)
	var moon_disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 2.4
	disc_mesh.bottom_radius = 2.4
	disc_mesh.height = 0.1
	disc_mesh.radial_segments = 24
	moon_disc.mesh = disc_mesh
	moon_disc.material_override = Palette.glow(&"white", true)
	moon_disc.position = Vector3(4.8, 8.2, -42.0)
	moon_disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(moon_disc)

	# Остроконечные тёмные скалистые пики на горизонте (контрастируют с бирюзой неба)
	var peaks: Array[Dictionary] = [
		{"pos": Vector3(-28.0, 0.0, -48.0), "w": 26.0, "h": 16.0},
		{"pos": Vector3(-14.0, 0.0, -50.0), "w": 28.0, "h": 19.0},
		{"pos": Vector3(-1.0,  0.0, -46.0), "w": 22.0, "h": 15.0},
		{"pos": Vector3(12.0,  0.0, -52.0), "w": 30.0, "h": 21.0},
		{"pos": Vector3(26.0,  0.0, -48.0), "w": 26.0, "h": 17.0},
	]

	var rock_mat := Palette.m(&"dark")
	var snow_mat := Palette.m(&"snow")

	for m in peaks:
		var p: Vector3 = m["pos"]
		var w: float = float(m["w"])
		var h: float = float(m["h"])

		var peak := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = w * 0.5
		cm.height = h
		cm.radial_segments = 5
		peak.mesh = cm
		peak.material_override = rock_mat
		peak.position = p + Vector3(0, h * 0.5, 0)
		add_child(peak)

		var snow_cap := MeshInstance3D.new()
		var scm := CylinderMesh.new()
		scm.top_radius = 0.0
		scm.bottom_radius = w * 0.28
		scm.height = h * 0.45
		scm.radial_segments = 5
		snow_cap.mesh = scm
		snow_cap.material_override = snow_mat
		snow_cap.position = p + Vector3(0, h * 0.77, 0)
		snow_cap.rotation.y = deg_to_rad(18.0)
		add_child(snow_cap)


# --- 4. Заснеженный рельеф двора ----------------------------------------------

func _build_snow_terrain() -> void:
	# Широкая заснеженная равнина с лёгким уклоном
	var snow_mesh := PlaneMesh.new()
	snow_mesh.size = Vector2(120.0, 120.0)
	var ground := MeshInstance3D.new()
	ground.mesh = snow_mesh
	ground.material_override = Palette.m(&"snow")
	ground.position = Vector3(0, -0.05, -35.0)
	add_child(ground)

	# Сугроб у завалинки под окном станции
	var drift_mat := Palette.m(&"drift")
	var drift := Geo.block(self, Vector3(5.2, 0.65, 1.8), Vector3(0.0, 0.22, -3.35), drift_mat, false)
	drift.rotation.x = deg_to_rad(8.0)

	# Боковые сугробы, обрамляющие двор
	var drift_l := Geo.block(self, Vector3(1.8, 0.55, 6.0), Vector3(-3.2, 0.18, -6.0), drift_mat, false)
	drift_l.rotation.y = deg_to_rad(12.0)
	var drift_r := Geo.block(self, Vector3(1.8, 0.55, 6.0), Vector3(3.4, 0.18, -6.0), drift_mat, false)
	drift_r.rotation.y = deg_to_rad(-10.0)

	# Цепочка следов босых ног, уходящая в темноту к лесу
	var trail_points := [
		Vector3(0.25, 0.01, -3.2),
		Vector3(0.35, 0.01, -4.3),
		Vector3(0.20, 0.01, -5.6),
		Vector3(0.42, 0.01, -7.0),
		Vector3(0.28, 0.01, -8.6),
		Vector3(0.50, 0.01, -10.4),
		Vector3(0.68, 0.01, -12.5),
		Vector3(0.95, 0.01, -14.8),
	]
	var dark_mat := Palette.m(&"dark")
	for i in range(trail_points.size()):
		var p: Vector3 = trail_points[i]
		var foot := Geo.block(self, Vector3(0.13, 0.02, 0.25), p, dark_mat, false)
		foot.rotation.y = deg_to_rad(-16.0 if i % 2 == 0 else 16.0)


# --- 5. Бревенчатая комната станции -------------------------------------------

func _build_room() -> void:
	var log_mat := Palette.m(&"log")
	var floor_mat := Palette.m(&"floor")
	var wood_mat := Palette.m(&"wood")

	# Пол из тёмных тёсаных досок
	Geo.block(self, Vector3(5.2, 0.2, 5.2), Vector3(0.0, -0.1, 0.0), floor_mat, true)

	# Северная стена с окном (окно z = -2.35)
	Geo.block(self, Vector3(1.65, 3.0, 0.32), Vector3(-1.675, 1.5, -2.35), log_mat, true)
	Geo.block(self, Vector3(1.65, 3.0, 0.32), Vector3(1.675, 1.5, -2.35), log_mat, true)
	Geo.block(self, Vector3(1.7, 0.85, 0.32), Vector3(0.0, 0.425, -2.35), log_mat, true)
	Geo.block(self, Vector3(1.7, 0.85, 0.32), Vector3(0.0, 2.575, -2.35), log_mat, true)

	# Западная бревенчатая стена
	Geo.block(self, Vector3(0.32, 3.0, 5.2), Vector3(-2.35, 1.5, 0.0), log_mat, true)

	# Потолок с тёмной матицей
	Geo.block(self, Vector3(5.2, 0.2, 5.2), Vector3(0.0, 3.1, 0.0), Palette.m(&"ceiling"), false)
	Geo.block(self, Vector3(0.28, 0.28, 5.2), Vector3(0.0, 2.95, 0.0), wood_mat, false)

	# Оконная рама
	_build_window_frame(Vector3(0.0, 1.5, -2.35), Vector2(1.66, 1.28))


func _build_window_frame(pos: Vector3, size: Vector2) -> void:
	var wood_mat := Palette.m(&"wood")
	var half_w := size.x * 0.5
	var half_h := size.y * 0.5

	# Деревянная коробка окна
	Geo.block(self, Vector3(size.x, 0.08, 0.18), pos + Vector3(0, half_h - 0.04, 0), wood_mat, false)
	Geo.block(self, Vector3(size.x, 0.08, 0.28), pos + Vector3(0, -half_h + 0.04, 0.05), wood_mat, false) # Подоконник
	Geo.block(self, Vector3(0.08, size.y, 0.18), pos + Vector3(-half_w + 0.04, 0, 0), wood_mat, false)
	Geo.block(self, Vector3(0.08, size.y, 0.18), pos + Vector3(half_w - 0.04, 0, 0), wood_mat, false)

	# Переплёт (Т-образный крест)
	Geo.block(self, Vector3(0.05, size.y - 0.16, 0.08), pos + Vector3(0, 0, 0), wood_mat, false)
	Geo.block(self, Vector3(size.x - 0.16, 0.05, 0.08), pos + Vector3(0, 0.14, 0), wood_mat, false)

	# Чистое стекло со сдержанным морозным оттенком
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.50, 0.70, 0.85, 0.08)
	glass_mat.roughness = 0.1
	glass_mat.metallic = 0.05

	var glass := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size - Vector2(0.12, 0.12)
	glass.mesh = qm
	glass.material_override = glass_mat
	glass.position = pos + Vector3(0, 0, 0.01)
	add_child(glass)


# --- 6. Рабочий стол, плахи, ретро-радио и свечи --------------------------------

func _build_desk_setup() -> void:
	# Создаём стол из 4 продольных массивных плах (без растяжения текстуры!)
	_bench_desk = Node3D.new()
	_bench_desk.position = Vector3(0.0, 0.0, -1.82)
	add_child(_bench_desk)

	var wood_mat := Palette.m(&"wood")
	var dark_mat := Palette.m(&"dark")
	var metal_mat := Palette.m(&"metal")

	# 4 отдельные деревянные плахи столешницы (2.1м в длину, 0.20м в ширину каждая)
	for i in range(4):
		var z_off := -0.315 + i * 0.210
		Geo.block(_bench_desk, Vector3(2.10, 0.048, 0.200), Vector3(0.0, 0.730, z_off), wood_mat, true)

	# Ножки и подстолье стола
	Geo.block(_bench_desk, Vector3(0.08, 0.70, 0.08), Vector3(-0.95, 0.35, -0.32), wood_mat, false)
	Geo.block(_bench_desk, Vector3(0.08, 0.70, 0.08), Vector3(-0.95, 0.35,  0.32), wood_mat, false)
	Geo.block(_bench_desk, Vector3(0.08, 0.70, 0.08), Vector3(-0.35, 0.35, -0.32), wood_mat, false)
	Geo.block(_bench_desk, Vector3(0.08, 0.70, 0.08), Vector3(-0.35, 0.35,  0.32), wood_mat, false)

	# Правая тумба с ящиками
	Geo.block(_bench_desk, Vector3(0.58, 0.70, 0.76), Vector3(0.70, 0.35, 0.0), wood_mat, false)
	for yi in range(3):
		var y := 0.16 + yi * 0.20
		Geo.block(_bench_desk, Vector3(0.52, 0.17, 0.015), Vector3(0.70, y, 0.385), wood_mat, false)
		Geo.block(_bench_desk, Vector3(0.12, 0.024, 0.025), Vector3(0.70, y, 0.395), metal_mat, false)

	# Настольная советская лампа в чернёном абажуре (без ядовитой зелени!)
	_build_industrial_lamp(Vector3(-0.55, 0.755, -1.75))

	# Журнал метеонаблюдений в тёмно-коричневой коже (без яркой синевы!)
	_build_journal(Vector3(-0.30, 0.755, -1.65), deg_to_rad(8.0))

	# Латунный подсвечник с живыми горящими свечами (между журналом и приёмником)
	_build_realistic_candelabra(Vector3(-0.06, 0.755, -1.72))

	# Ретро-приёмник с матовыми чернёными ручками и светящейся янтарной шкалой
	_transistor_radio = _build_matte_retro_radio()
	_transistor_radio.position = Vector3(0.20, 0.755, -1.72)
	_transistor_radio.rotation.y = deg_to_rad(-16.0)
	add_child(_transistor_radio)

	# Мельхиоровый подстаканник со стаканом горячего чая
	var tea := Props.podstakannik()
	tea.position = Vector3(0.65, 0.755, -1.68)
	add_child(tea)


## Настольная лампа в тёмном чугунно-графитовом исполнении
func _build_industrial_lamp(pos: Vector3) -> void:
	var lamp_root := Node3D.new()
	lamp_root.position = pos
	lamp_root.rotation.y = deg_to_rad(-20.0) # Повёрнута к центру стола
	add_child(lamp_root)

	var dark_metal := Palette.m(&"metal")
	var dark_mat := Palette.m(&"dark")

	# Основание
	Geo.cylinder(lamp_root, 0.075, 0.025, Vector3(0, 0.012, 0), dark_metal, false)
	# Изогнутая ножка
	Geo.cylinder(lamp_root, 0.010, 0.26, Vector3(0.02, 0.14, 0.02), dark_metal, false)
	Geo.cylinder(lamp_root, 0.010, 0.16, Vector3(0.06, 0.28, 0.08), dark_metal, false)

	# Абажур из чернёного металла (не отбрасывает глухую тень внутрь лампы)
	var shade := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.040
	cm.bottom_radius = 0.085
	cm.height = 0.12
	cm.radial_segments = 8
	shade.mesh = cm
	shade.material_override = dark_mat
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = Vector3(0.08, 0.32, 0.12)
	shade.rotation_degrees = Vector3(-35.0, 0.0, 15.0)
	lamp_root.add_child(shade)

	# Сдержанный тёплый янтарь лампы
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = pos + Vector3(0.08, 0.26, 0.12)
	_lamp_light.light_color = Color(0.94, 0.60, 0.26)
	_lamp_light.light_energy = 0.75
	_lamp_light.omni_range = 3.0
	_lamp_light.omni_attenuation = 1.35
	_lamp_light.shadow_enabled = true
	_lamp_light.shadow_bias = 0.08
	add_child(_lamp_light)


## Журнал дежурного в тёмно-коричневом суконном переплёте
func _build_journal(pos: Vector3, rot_y: float) -> void:
	var j := Node3D.new()
	j.position = pos
	j.rotation.y = rot_y
	add_child(j)

	var paper_mat := Palette.m(&"paper")
	var dark_mat := Palette.m(&"wood")
	var metal_mat := Palette.m(&"metal")

	# Страницы
	Geo.block(j, Vector3(0.24, 0.022, 0.32), Vector3(0, 0.011, 0), paper_mat, false)
	# Тёмно-коричневая кожаная обложка
	Geo.block(j, Vector3(0.25, 0.005, 0.33), Vector3(0, 0.024, 0), dark_mat, false)
	Geo.block(j, Vector3(0.012, 0.026, 0.33), Vector3(-0.125, 0.013, 0), dark_mat, false)
	# Графитовый карандаш рядом
	Geo.cylinder(j, 0.004, 0.18, Vector3(0.14, 0.005, 0.0), metal_mat, false)


## Латунный подсвечник: настоящие толстые восковые свечи с горящим каплевидным пламенем
func _build_realistic_candelabra(pos: Vector3) -> void:
	var cand := Node3D.new()
	cand.position = pos
	add_child(cand)

	var metal_mat := Palette.m(&"metal")
	var dark_mat := Palette.m(&"dark")
	var candle_mat := Palette.m(&"white")

	# Латунное основание и стойка подсвечника
	Geo.cylinder(cand, 0.050, 0.018, Vector3(0, 0.009, 0), metal_mat, false)
	Geo.cylinder(cand, 0.014, 0.140, Vector3(0, 0.080, 0), metal_mat, false)
	# Горизонтальная латунная планка
	Geo.block(cand, Vector3(0.20, 0.014, 0.014), Vector3(0, 0.145, 0), metal_mat, false)

	# Материал пламени: самосветящийся (unshaded), пробивающий туман
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.88, 0.50)
	flame_mat.disable_fog = true

	var candle_data := [
		{"x": -0.085, "h": 0.11},
		{"x":  0.0,   "h": 0.15},
		{"x":  0.085, "h": 0.11},
	]

	for cd in candle_data:
		var cx: float = float(cd["x"])
		var ch: float = float(cd["h"])
		var c_root := Vector3(cx, 0.150, 0.0)

		# Латунная чашечка под свечу
		Geo.cylinder(cand, 0.026, 0.012, c_root + Vector3(0, 0.006, 0), metal_mat, false)

		# Толстое тело восковой свечи
		Geo.cylinder(cand, 0.018, ch, c_root + Vector3(0, 0.012 + ch * 0.5, 0), candle_mat, false)

		# Чёрный фитиль на верхушке
		var wick_y := 0.012 + ch
		Geo.cylinder(cand, 0.002, 0.016, c_root + Vector3(0, wick_y + 0.008, 0), dark_mat, false)

		# Видимое каплевидное пламя свечи
		var flame := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.010
		sm.height = 0.032
		sm.radial_segments = 6
		sm.rings = 3
		flame.mesh = sm
		flame.material_override = flame_mat
		flame.position = pos + c_root + Vector3(0, wick_y + 0.024, 0)
		add_child(flame)
		_candle_flames.append(flame)

	# Живой тёплый свет пламени свечей
	_candle_light = OmniLight3D.new()
	_candle_light.position = pos + Vector3(0, 0.32, 0)
	_candle_light.light_color = Color(0.96, 0.56, 0.22)
	_candle_light.light_energy = 0.55
	_candle_light.omni_range = 2.4
	_candle_light.omni_attenuation = 1.35
	_candle_light.shadow_enabled = true
	_candle_light.shadow_bias = 0.08
	add_child(_candle_light)


## Ретро-приёмник с матовыми чернёными ручками и янтарной шкалой
func _build_matte_retro_radio() -> Node3D:
	var root := Node3D.new()
	var k := MeshKit.new(77)
	k.mottle = 0.02

	var body_col := Color(0.18, 0.20, 0.22)       # Тёмно-графитовый матовый корпус
	var panel_col := Color(0.12, 0.14, 0.16)      # Чернёная лицевая панель
	var dark_metal := Color(0.32, 0.34, 0.36)     # Тёмный матовый металл
	var knob_col := Color(0.14, 0.15, 0.16)       # Чернёные ручки верньеров (НЕ белые!)
	var dark_bay := Color(0.04, 0.05, 0.06)       # Окно шкалы
	var white_mark := Color(0.75, 0.75, 0.72)     # Сдержанные деления шкалы

	# Корпус приёмника
	k.box(Vector3(0, 0.13, 0), Vector3(0.20, 0.26, 0.08), body_col)
	k.box(Vector3(0, 0.13, 0.041), Vector3(0.185, 0.245, 0.003), panel_col)

	# Окно шкалы радиочастот
	k.box(Vector3(0, 0.195, 0.044), Vector3(0.16, 0.065, 0.003), dark_bay)
	for i in range(8):
		var x := -0.062 + i * 0.0175
		var tick_h := 0.035 if i % 2 == 0 else 0.02
		k.box(Vector3(x, 0.198, 0.046), Vector3(0.002, tick_h, 0.002), white_mark)

	# Матовые чернёные ручки настройки (не бликующие!)
	k.tube([Vector3(-0.045, 0.022, 0.042), Vector3(-0.045, 0.022, 0.056)], [0.016, 0.016], knob_col, 8)
	k.tube([Vector3(0.045, 0.022, 0.042), Vector3(0.045, 0.022, 0.056)], [0.016, 0.016], knob_col, 8)

	# Металлическая антенна
	k.tube([Vector3(0.075, 0.26, 0.0), Vector3(0.075, 0.58, 0.0)], [0.0035, 0.002], dark_metal, 6)

	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	var mat := Creatures._mat(&"retro_radio", Color.WHITE, "tex_metal.png", 0.0)
	mi.material_override = mat
	root.add_child(mi)

	# Тёмная круглая решётка динамика из палитры (гарантированно тёмный матовый круг)
	var grill := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.046
	gm.bottom_radius = 0.046
	gm.height = 0.004
	gm.radial_segments = 16
	grill.mesh = gm
	grill.material_override = Palette.m(&"dark")
	grill.position = Vector3(0, 0.085, 0.044)
	grill.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(grill)

	# Тёмный металлический ободок решётки
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.049
	rm.bottom_radius = 0.049
	rm.height = 0.002
	rm.radial_segments = 16
	rim.mesh = rm
	rim.material_override = Palette.m(&"metal")
	rim.position = Vector3(0, 0.085, 0.043)
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(rim)

	# Светящаяся янтарная риска частоты
	Geo.block(root, Vector3(0.003, 0.045, 0.004), Vector3(0.008, 0.195, 0.048), Palette.glow(&"amber"), false)

	return root


# --- 7. Чёрные силуэты елей со стилизованными снежными шапками -----------------

func _build_taiga_forest() -> void:
	# Располагаем деревья по планам глубины:
	# Ближний план: слева и справа от окна, обрамляют вид
	# Средний план: лесная кулиса
	# Задний план: стена леса на фоне светящегося бирюзового горизонта
	var tree_configs: Array[Dictionary] = [
		# Ближний план (обрамление окна слева и справа)
		{"pos": Vector3(-4.8, 0.0, -8.0),  "scale": 1.35, "rot": 0.4},
		{"pos": Vector3(4.8,  0.0, -8.0),  "scale": 1.35, "rot": 1.1},

		# Средний план (кулиса тайги, открывающая центральный коридор)
		{"pos": Vector3(-4.2, 0.0, -12.5), "scale": 1.55, "rot": 1.8},
		{"pos": Vector3(-6.8, 0.0, -15.0), "scale": 1.70, "rot": 2.2},
		{"pos": Vector3(4.2,  0.0, -12.5), "scale": 1.55, "rot": 0.6},
		{"pos": Vector3(6.8,  0.0, -15.0), "scale": 1.70, "rot": 2.1},
		{"pos": Vector3(-3.6, 0.0, -18.0), "scale": 1.65, "rot": 1.4},
		{"pos": Vector3(3.6,  0.0, -18.0), "scale": 1.65, "rot": 1.9},

		# Задняя стена леса (шпили сосен смыкаются за Ыркой на фоне бирюзового неба)
		{"pos": Vector3(-6.5, 0.0, -24.0), "scale": 2.05, "rot": 0.5},
		{"pos": Vector3(-3.0, 0.0, -24.5), "scale": 2.15, "rot": 1.7},
		{"pos": Vector3(0.0,  0.0, -26.0), "scale": 2.25, "rot": 2.9},
		{"pos": Vector3(3.0,  0.0, -24.5), "scale": 2.15, "rot": 0.4},
		{"pos": Vector3(6.5,  0.0, -24.0), "scale": 2.05, "rot": 1.6},
		{"pos": Vector3(-10.5, 0.0, -26.0), "scale": 2.10, "rot": 1.2},
		{"pos": Vector3(10.5,  0.0, -26.0), "scale": 2.00, "rot": 0.8},
	]

	for i in range(tree_configs.size()):
		var cfg: Dictionary = tree_configs[i]
		var spruce := _create_dark_silhouette_spruce(float(cfg["scale"]), i * 37 + 19)
		spruce.position = cfg["pos"]
		spruce.rotation.y = float(cfg["rot"])
		add_child(spruce)


## Стилизованная ель: мощный тёмный ствол, 4 яруса тёмной хвои и плотно подогнанные
## гранёные снежные шапки на верхней половине каждого яруса (без летающих осколков!)
func _create_dark_silhouette_spruce(scale_mult := 1.0, seed_val := 42) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Мощный тёмный ствол (виден у основания и между нижними ярусами)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14 * scale_mult
	trunk_mesh.bottom_radius = 0.28 * scale_mult
	trunk_mesh.height = 5.6 * scale_mult
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = Palette.m(&"bark")

	var trunk_inst := MeshInstance3D.new()
	trunk_inst.mesh = trunk_mesh
	trunk_inst.position.y = 2.8 * scale_mult
	root.add_child(trunk_inst)

	# 4 яруса хвои: каждый ярус состоит из тёмного объёма хвои внизу и снежного панциря сверху
	var tiers: Array[Dictionary] = [
		{"y": 0.40, "r_base": 2.30, "r_top": 0.65, "h": 2.00, "segs": 6, "snow_cov": 0.50},
		{"y": 1.80, "r_base": 1.90, "r_top": 0.50, "h": 1.90, "segs": 6, "snow_cov": 0.52},
		{"y": 3.10, "r_base": 1.45, "r_top": 0.35, "h": 1.75, "segs": 6, "snow_cov": 0.55},
		{"y": 4.30, "r_base": 0.95, "r_top": 0.01, "h": 1.65, "segs": 5, "snow_cov": 0.60},
	]

	var needle_mat := Palette.m(&"tree")
	var snow_mat := Palette.m(&"snow")

	for i in range(tiers.size()):
		var t: Dictionary = tiers[i]
		var y_pos: float = float(t["y"]) * scale_mult
		var r_b: float = float(t["r_base"]) * scale_mult
		var r_t: float = float(t["r_top"]) * scale_mult
		var h: float = float(t["h"]) * scale_mult
		var segs: int = int(t["segs"])
		var snow_cov: float = float(t["snow_cov"])
		var rot_offset: float = rng.randf_range(-0.35, 0.35)

		# 1. Тёмная хвоя: полный объём конуса/усечённого конуса
		var needle_mesh := CylinderMesh.new()
		needle_mesh.bottom_radius = r_b
		needle_mesh.top_radius = r_t
		needle_mesh.height = h
		needle_mesh.radial_segments = segs
		needle_mesh.material = needle_mat

		var needle_inst := MeshInstance3D.new()
		needle_inst.mesh = needle_mesh
		needle_inst.position.y = y_pos + (h * 0.5)
		needle_inst.rotation.y = rot_offset
		root.add_child(needle_inst)

		# 2. Гранёная снежная шапка: сидит на верхней половине того же конуса
		# КРИТИЧЕСКИ ВАЖНО: угол поворота СТРОГО СОВПАДАЕТ (rot_offset),
		# поэтому грани снега лежат ровно на хвое и не торчат летающими осколками!
		var snow_h := h * snow_cov
		var snow_r_bot := lerpf(r_b, r_t, 1.0 - snow_cov) * 1.02 # Чуть выступает над хвоей
		var snow_r_top := r_t * 1.01

		var snow_mesh := CylinderMesh.new()
		snow_mesh.bottom_radius = snow_r_bot
		snow_mesh.top_radius = snow_r_top
		snow_mesh.height = snow_h
		snow_mesh.radial_segments = segs
		snow_mesh.material = snow_mat

		var snow_inst := MeshInstance3D.new()
		snow_inst.mesh = snow_mesh
		snow_inst.position.y = y_pos + h - (snow_h * 0.5)
		snow_inst.rotation.y = rot_offset   # Строго тот же угол!
		root.add_child(snow_inst)

	return root


# --- 8. Уличный фонарный столб ------------------------------------------------

func _build_yard_lamp() -> void:
	var post_mat := Palette.m(&"wood")
	Geo.cylinder(self, 0.08, 4.2, Vector3(2.5, 2.1, -6.5), post_mat, false)
	Geo.block(self, Vector3(0.9, 0.08, 0.08), Vector3(2.2, 4.0, -6.5), post_mat, false)

	var yard_light := OmniLight3D.new()
	yard_light.position = Vector3(1.85, 3.8, -6.5)
	yard_light.light_color = Color(0.80, 0.86, 0.96)
	yard_light.light_energy = 0.90
	yard_light.omni_range = 8.5
	yard_light.omni_attenuation = 1.3
	yard_light.shadow_enabled = true
	yard_light.shadow_bias = 0.06
	add_child(yard_light)
	Geo.bulb(yard_light, &"bulb", 0.08)


# --- 9. Зловещий силуэт в чаще с горящими глазами ------------------------------

func _build_forest_menace() -> void:
	_yrka_silhouette = Node3D.new()
	_yrka_silhouette.position = Vector3(-0.35, 0.0, -13.5)
	add_child(_yrka_silhouette)

	var yrka_mesh := Creatures.make_yrka()
	_yrka_silhouette.add_child(yrka_mesh)
	_yrka_silhouette.rotation.y = deg_to_rad(175.0)

	_eyes = Node3D.new()
	_eyes.position = Vector3(-0.35, 1.45, -13.3)
	add_child(_eyes)

	for dx: float in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.022
		sm.height = 0.044
		eye.mesh = sm
		eye.material_override = Palette.glow(&"eyes", true)
		eye.position = Vector3(dx, 0.0, 0.0)
		_eyes.add_child(eye)


# --- 10. Атмосферные частицы снега --------------------------------------------

func _build_snow_particles() -> void:
	_snow_particles = CPUParticles3D.new()
	_snow_particles.amount = 450
	_snow_particles.lifetime = 4.5
	_snow_particles.preprocess = 2.5
	_snow_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow_particles.emission_box_extents = Vector3(16.0, 5.0, 16.0)
	_snow_particles.position = Vector3(0.0, 4.5, -9.0)
	_snow_particles.direction = Vector3(-0.5, -1.0, 0.2)
	_snow_particles.spread = 20.0
	_snow_particles.gravity = Vector3(-0.6, -2.2, 0.3)
	_snow_particles.initial_velocity_min = 1.0
	_snow_particles.initial_velocity_max = 2.2
	_snow_particles.scale_amount_min = 0.035
	_snow_particles.scale_amount_max = 0.075

	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.75)

	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(0.05, 0.05)
	p_mesh.material = p_mat
	_snow_particles.mesh = p_mesh
	add_child(_snow_particles)


# --- 11. Камера и фонарик игрока ----------------------------------------------

func _setup_camera_and_flashlight() -> void:
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.near = 0.05
	_cam.far = 160.0
	add_child(_cam)
	_cam.current = true

	_spot = SpotLight3D.new()
	_spot.light_color = Color(0.95, 0.92, 0.85)
	_spot.light_energy = 1.2
	_spot.spot_range = 22.0
	_spot.spot_angle = 24.0
	_spot.spot_attenuation = 1.4
	_spot.shadow_enabled = true
	_spot.shadow_bias = 0.08
	_spot.visible = false
	_cam.add_child(_spot)


# --- 12. Бенчмарк снимков и интерактивный режим -------------------------------

func _run_benchmark() -> void:
	# Кадр №1: Вид из тёплой янтарной комнаты в холодную бездну тайги за окном
	_cam.position = Vector3(0.04, 1.34, -0.75)
	_cam.look_at(Vector3(0.0, 1.40, -14.0), Vector3.UP)
	_cam_yaw = deg_to_rad(0.0)
	_cam_pitch = deg_to_rad(2.0)
	_set_flashlight(false)
	await _wait(0.8)
	await _capture("arttest_01_taiga_window")

	# Кадр №2: Уличная чаща перед окном (силуэты чёрных елей против бирюзового неба и тумана)
	_cam.position = Vector3(0.0, 1.25, -4.8)
	_cam.look_at(Vector3(0.0, 1.85, -16.0), Vector3.UP)
	_set_flashlight(false)
	await _wait(0.5)
	await _capture("arttest_02_taiga_treeline")

	# Кадр №3: Крупный план ретро-радио, досок стола и свечей
	# Мягкий заполняющий свет проявляет фактуру металла и шкалы без выжигания
	_cam.position = Vector3(0.06, 1.05, -1.35)
	_cam.look_at(Vector3(0.18, 0.94, -1.72), Vector3.UP)
	_spot.light_energy = 0.30
	_set_flashlight(true)
	await _wait(0.5)
	await _capture("arttest_03_retro_radio_close")
	_set_flashlight(false)
	_spot.light_energy = 1.2

	# Возвращаем камеру к окну
	_cam.position = Vector3(0.04, 1.34, -0.75)
	_cam.look_at(Vector3(0.0, 1.40, -14.0), Vector3.UP)
	_set_flashlight(false)

	print("[ArtTestTaiga] Все эталонные снимки успешно созданы в user://shots/arttest_*.png")
	var args := OS.get_cmdline_user_args()
	if args.has("--quit") or OS.get_cmdline_args().has("--quit"):
		get_tree().quit()
		return

	_enable_interactive_mode()


func _enable_interactive_mode() -> void:
	_free_cam = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var ui := CanvasLayer.new()
	var hud_lbl := Label.new()
	hud_lbl.text = " [WASD] Движение   [Shift] Бег   [Space/Ctrl] Вверх/Вниз   [F] Фонарик   [Мышь] Обзор   [ESC] Выход "
	hud_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_lbl.add_theme_font_size_override("font_size", 16)
	hud_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hud_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	hud_lbl.add_theme_constant_override("shadow_offset_x", 1)
	hud_lbl.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(hud_lbl)
	add_child(ui)


func _process(delta: float) -> void:
	_flicker_t += delta
	if _candle_light != null:
		var f := sin(_flicker_t * 13.7) * 0.05 + cos(_flicker_t * 24.3) * 0.03
		_candle_light.light_energy = 0.55 + f

	for i in range(_candle_flames.size()):
		var fl := _candle_flames[i]
		if fl != null:
			fl.scale.y = 1.0 + sin(_flicker_t * 18.0 + i * 2.0) * 0.15

	if _lamp_light != null:
		var fl := sin(_flicker_t * 6.5) * 0.02
		_lamp_light.light_energy = 0.70 + fl

	if not _free_cam or _cam == null:
		return

	var speed := 4.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed = 8.5

	var dir := Vector3.ZERO
	var fwd := -_cam.global_transform.basis.z
	var right := _cam.global_transform.basis.x

	fwd.y = 0.0
	fwd = fwd.normalized()
	right.y = 0.0
	right = right.normalized()

	if Input.is_key_pressed(KEY_W):
		dir += fwd
	if Input.is_key_pressed(KEY_S):
		dir -= fwd
	if Input.is_key_pressed(KEY_D):
		dir += right
	if Input.is_key_pressed(KEY_A):
		dir -= right

	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
		dir += Vector3.DOWN

	if dir != Vector3.ZERO:
		_cam.position += dir.normalized() * speed * delta


func _apply_cam_rot() -> void:
	if _cam != null:
		_cam.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _set_flashlight(on: bool) -> void:
	if _spot != null:
		_spot.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if not _free_cam:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= event.relative.x * 0.0028
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.0028, -1.45, 1.45)
		_apply_cam_rot()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_F:
			_set_flashlight(not _spot.visible)
		elif event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()

	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var vp := get_viewport()
		if vp != null:
			var tex := vp.get_texture()
			if tex != null:
				var img := tex.get_image()
				if img != null:
					var path := SHOTS + file_name + ".png"
					img.save_png(path)
					print("[ArtTestTaiga] Сохранён снимок: ", path)
	else:
		print("[ArtTestTaiga] Headless shot simulated: ", file_name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
